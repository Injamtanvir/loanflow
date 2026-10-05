prepare_snapshot <- function(raw) {
  assert_columns(raw$applications, APP_COLUMNS, "Applications")
  assert_columns(raw$events, EVENT_COLUMNS, "Status history")
  as_of <- parse_utc(raw$metadata$as_of)
  if (length(as_of) != 1L || is.na(as_of) || blank(raw$metadata$snapshot_id)) stop("Invalid snapshot metadata")
  if (!isTRUE(raw$metadata$synthetic)) stop("This educational build accepts explicitly synthetic snapshots only")
  a <- as.data.frame(raw$applications[, APP_COLUMNS], stringsAsFactors = FALSE)
  e <- as.data.frame(raw$events[, EVENT_COLUMNS], stringsAsFactors = FALSE)
  a[] <- lapply(a, as.character); e[] <- lapply(e, as.character)
  a$.row <- seq_len(nrow(a)); e$.row <- seq_len(nrow(e))
  issues <- data.frame(entity = character(), source_row = integer(), record_id = character(),
                       application_id = character(), check = character(), action = character(), stringsAsFactors = FALSE)
  add <- function(frame, mask, entity, check, action = "quarantine") {
    mask[is.na(mask)] <- TRUE
    if (!any(mask)) return(invisible(NULL))
    id <- if (entity == "application") frame$application_id else frame$event_id
    issues <<- rbind(issues, data.frame(entity = entity, source_row = frame$.row[mask], record_id = id[mask],
                                      application_id = frame$application_id[mask], check = check, action = action,
                                      stringsAsFactors = FALSE))
  }
  # Exact duplicate rows are harmless after deterministic collapse. Conflicting keys are not.
  duplicate_a <- duplicated(a[, APP_COLUMNS])
  add(a, duplicate_a, "application", "duplicate_application_exact", "deduplicate")
  a <- a[!duplicate_a, ]
  conflict_a <- duplicated(a$application_id) | duplicated(a$application_id, fromLast = TRUE)
  add(a, conflict_a, "application", "duplicate_application_conflict")
  missing_a <- Reduce(`|`, lapply(a[, APP_COLUMNS], blank))
  add(a, missing_a, "application", "missing_required_field")
  a$submitted_time <- parse_utc(a$submitted_at)
  invalid_a <- is.na(a$submitted_time) | a$submitted_time > as_of
  add(a, invalid_a, "application", "invalid_submission_timestamp")
  a$amount <- suppressWarnings(as.numeric(a$requested_amount_bdt))
  invalid_amount <- is.na(a$amount) | !is.finite(a$amount) | a$amount <= 0
  add(a, invalid_amount, "application", "invalid_requested_amount")
  good_a <- !(conflict_a | missing_a | invalid_a | invalid_amount)
  good_a[is.na(good_a)] <- FALSE
  a <- a[good_a, ]
  if (nrow(a) == 0L) stop("No valid applications remain in this snapshot")

  duplicate_e <- duplicated(e[, EVENT_COLUMNS])
  add(e, duplicate_e, "event", "duplicate_event_exact", "deduplicate")
  e <- e[!duplicate_e, ]
  conflict_e <- duplicated(e$event_id) | duplicated(e$event_id, fromLast = TRUE)
  add(e, conflict_e, "event", "duplicate_event_id_conflict")
  bad_apps <- unique(e$application_id[conflict_e])
  e <- e[!conflict_e, ]
  # The same visit re-sent with another ID must not increase counts or duration.
  natural_columns <- c("application_id", "stage", "department", "entered_at", "exited_at")
  duplicate_natural <- duplicated(e[, natural_columns])
  add(e, duplicate_natural, "event", "duplicate_event_natural_key", "deduplicate")
  e <- e[!duplicate_natural, ]
  missing_e <- Reduce(`|`, lapply(e[, setdiff(EVENT_COLUMNS, "exited_at")], blank))
  add(e, missing_e, "event", "missing_required_field")
  orphan <- !e$application_id %in% a$application_id
  add(e, orphan, "event", "orphan_or_quarantined_application")
  e$entered_time <- parse_utc(e$entered_at)
  e$exited_time <- parse_utc(e$exited_at)
  e$recorded_time <- parse_utc(e$recorded_at)
  entered_bad <- is.na(e$entered_time) | e$entered_time > as_of
  exit_bad <- !blank(e$exited_at) & (is.na(e$exited_time) | e$exited_time < e$entered_time | e$exited_time > as_of)
  recorded_bad <- is.na(e$recorded_time) | e$recorded_time < e$entered_time | e$recorded_time > as_of |
    (!is.na(e$exited_time) & e$recorded_time < e$exited_time)
  before_application <- e$entered_time < a$submitted_time[match(e$application_id, a$application_id)]
  before_application[is.na(before_application)] <- FALSE
  time_bad <- entered_bad | exit_bad | recorded_bad | before_application
  time_bad[is.na(time_bad)] <- TRUE
  add(e, time_bad, "event", "invalid_event_timestamp")
  stage_bad <- !e$stage %in% names(STAGE_DEPARTMENT) | is.na(STAGE_DEPARTMENT[e$stage]) |
    e$department != unname(STAGE_DEPARTMENT[e$stage])
  stage_bad[is.na(stage_bad)] <- TRUE
  add(e, stage_bad, "event", "invalid_stage_department")
  row_bad <- missing_e | orphan | time_bad | stage_bad
  bad_apps <- unique(c(bad_apps, e$application_id[row_bad]))
  e <- e[!row_bad, ]
  # Validate the full ordered timeline. A bad visit invalidates inference about current status.
  event_groups <- split(seq_len(nrow(e)), e$application_id)
  for (id in names(event_groups)) {
    ix <- event_groups[[id]]
    ix <- ix[order(e$entered_time[ix], e$event_id[ix])]
    h <- e[ix, ]; count <- nrow(h)
    invalid <- anyDuplicated(h$entered_time) > 0L
    if (count > 1L) {
      previous <- seq_len(count - 1L)
      invalid <- invalid || any(is.na(h$exited_time[previous])) ||
        any(h$stage[previous] %in% TERMINAL_STAGES) ||
        any(h$exited_time[previous] > h$entered_time[previous + 1L], na.rm = TRUE)
    }
    if (!tail(h$stage, 1) %in% TERMINAL_STAGES && !is.na(tail(h$exited_time, 1))) invalid <- TRUE
    if (invalid) {
      add(e, e$application_id == id, "event", "invalid_event_sequence", "quarantine_application_history")
      bad_apps <- unique(c(bad_apps, id))
    }
  }
  missing_history <- !a$application_id %in% e$application_id
  add(a, missing_history, "application", "missing_valid_status_history", "mark_data_issue")
  bad_apps <- unique(c(bad_apps, a$application_id[missing_history]))
  reliable_events <- e[!e$application_id %in% bad_apps, ]
  # Count all raw rows removed from KPI event history, including duplicate copies.
  reconciliation <- data.frame(
    measure = c("raw_application_rows", "raw_unique_application_ids", "valid_application_rows",
                "raw_event_rows", "reliable_event_rows", "applications_with_unreliable_history"),
    value = c(nrow(raw$applications), dplyr::n_distinct(raw$applications$application_id), nrow(a),
              nrow(raw$events), nrow(reliable_events), sum(a$application_id %in% bad_apps))
  )
  list(applications = a, events = reliable_events, issues = issues,
       unreliable_ids = intersect(a$application_id, bad_apps), as_of = as_of,
       metadata = raw$metadata, reconciliation = reconciliation)
}

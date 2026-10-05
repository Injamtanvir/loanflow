generate_demo <- function(n = 5000L, seed = 42L, dirty = TRUE) {
  stopifnot(n >= 100L)
  set.seed(seed)
  as_of <- parse_utc("2026-10-01T00:00:00Z")
  start <- parse_utc("2026-07-01T00:00:00Z")
  submitted <- start + sample.int(as.integer(difftime(as_of, start, units = "secs")) - 1L, n)
  applications <- data.frame(
    application_id = sprintf("LF%06d", seq_len(n)),
    branch = sample(c("Dhaka Central", "Chattogram", "Sylhet", "Rajshahi", "Khulna", "Rangpur"), n, TRUE),
    product = sample(c("Working capital", "Equipment finance", "SME term loan"), n, TRUE, c(.5, .2, .3)),
    submitted_at = utc_string(submitted),
    requested_amount_bdt = as.character(round(exp(rnorm(n, log(1500000), .7)), -3)),
    stringsAsFactors = FALSE
  )
  histories <- vector("list", n)
  for (i in seq_len(n)) {
    stages <- c("Received", "Documents", "Credit review", "Final review")
    # Some applications return to Compliance; metrics sum visits at app-department grain.
    if (runif(1) < .12) stages <- c("Received", "Documents", "Credit review", "Documents", "Credit review", "Final review")
    cursor <- submitted[i]
    rows <- list()
    for (stage in stages) {
      mean_hours <- c("Received" = 10, "Documents" = 60, "Credit review" = 110, "Final review" = 24)[stage]
      duration <- max(600, round(rexp(1, 1 / (mean_hours * 3600))))
      # Extra backlog is visible as open pending work, not negative/unfinished turnaround.
      if (runif(1) < .045) duration <- duration + 45 * 86400
      exit <- cursor + duration
      open <- exit > as_of
      rows[[length(rows) + 1L]] <- data.frame(
        application_id = applications$application_id[i], stage = stage,
        department = unname(STAGE_DEPARTMENT[stage]), entered_at = utc_string(cursor),
        exited_at = if (open) "" else utc_string(exit),
        recorded_at = utc_string(if (open) cursor else exit), stringsAsFactors = FALSE
      )
      if (open) break
      cursor <- exit
    }
    if (tail(rows, 1)[[1]]$exited_at != "") {
      stage <- sample(TERMINAL_STAGES, 1, prob = c(.72, .22, .06))
      rows[[length(rows) + 1L]] <- data.frame(
        application_id = applications$application_id[i], stage = stage, department = "Closed",
        entered_at = utc_string(cursor), exited_at = "", recorded_at = utc_string(cursor),
        stringsAsFactors = FALSE
      )
    }
    histories[[i]] <- dplyr::bind_rows(rows)
  }
  events <- dplyr::bind_rows(histories)
  events$event_id <- sprintf("EV%07d", seq_len(nrow(events)))
  events <- events[, EVENT_COLUMNS]
  if (dirty) {
    applications$branch[1:4] <- ""
    applications$product[5:7] <- ""
    applications$submitted_at[8] <- "2026-02-30T00:00:00Z"
    applications$submitted_at[9] <- ""
    applications$submitted_at[10] <- "2026-12-01T00:00:00Z"
    applications$requested_amount_bdt[11] <- "-100"
    applications <- rbind(applications, applications[12:14, ]) # Exact duplicates, recoverable.
    conflict <- applications[15, ]; conflict$product <- "Equipment finance (conflict)"
    applications <- rbind(applications, conflict) # Conflicting ID, quarantine both records.
    events <- rbind(events, events[20:27, ]) # Eight duplicate event rows.
    copy <- events[30, ]; copy$event_id <- "EV_DUPLICATE_NATURAL_KEY"
    events <- rbind(events, copy)
    event_for <- function(i) which(events$application_id == sprintf("LF%06d", i))[1]
    events$entered_at[event_for(30)] <- "invalid-time"
    events$exited_at[event_for(31)] <- "2019-01-01T00:00:00Z"
    events$department[event_for(32)] <- ""
    events$recorded_at[event_for(33)] <- "2027-01-01T00:00:00Z"
    orphan <- events[40, ]; orphan$event_id <- "EV_ORPHAN"; orphan$application_id <- "UNKNOWN"
    events <- rbind(events, orphan)
    # A conflicting event ID: neither version is trusted.
    conflict <- events[event_for(34), ]; conflict$department <- "Wrong department"
    events <- rbind(events, conflict)
  }
  list(applications = applications, events = events,
       metadata = list(snapshot_id = sprintf("demo-%s-%s-%s", n, seed, if (dirty) "quality" else "clean"),
                       as_of = utc_string(as_of), seed = seed, synthetic = TRUE))
}

write_demo <- function(raw, directory) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  write.csv(raw$applications, file.path(directory, "applications.csv"), row.names = FALSE, na = "")
  write.csv(raw$events, file.path(directory, "status_history.csv"), row.names = FALSE, na = "")
  jsonlite::write_json(raw$metadata, file.path(directory, "metadata.json"), auto_unbox = TRUE, pretty = TRUE)
}

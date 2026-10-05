application_snapshot <- function(prepared) {
  events <- prepared$events
  # Do not join the application table directly to history and then count rows.
  latest <- events |>
    dplyr::arrange(.data$application_id, dplyr::desc(.data$entered_time), dplyr::desc(.data$event_id)) |>
    dplyr::group_by(.data$application_id) |>
    dplyr::slice_head(n = 1L) |>
    dplyr::ungroup() |>
    dplyr::transmute(application_id = .data$application_id, current_stage = .data$stage,
                     current_department = .data$department, stage_entered_at = .data$entered_time)
  applications <- prepared$applications |>
    dplyr::transmute(application_id = .data$application_id, branch = .data$branch, product = .data$product,
                     submitted_at = .data$submitted_time, requested_amount_bdt = .data$amount)
  result <- dplyr::left_join(applications, latest, by = "application_id", relationship = "one-to-one")
  result$current_stage[is.na(result$current_stage)] <- "Data issue"
  result$current_department[is.na(result$current_department)] <- "Unassigned"
  result$submitted_date <- as.Date(result$submitted_at, tz = DISPLAY_TZ)
  result$is_pending <- !result$current_stage %in% c(TERMINAL_STAGES, "Data issue")
  result$is_completed <- result$current_stage %in% TERMINAL_STAGES
  result$pending_age_days <- ifelse(result$is_pending, as.numeric(difftime(prepared$as_of, result$stage_entered_at, units = "days")), NA_real_)
  result$total_pending_age_days <- ifelse(result$is_pending, as.numeric(difftime(prepared$as_of, result$submitted_at, units = "days")), NA_real_)
  result$turnaround_days <- ifelse(result$is_completed, as.numeric(difftime(result$stage_entered_at, result$submitted_at, units = "days")), NA_real_)
  stopifnot(nrow(result) == nrow(applications), !anyDuplicated(result$application_id))
  result
}

filter_applications <- function(apps, branch = "__all__", product = "__all__", dates = NULL, stage = "__all__") {
  if (!is.null(branch) && branch != "__all__") apps <- apps[apps$branch == branch, ]
  if (!is.null(product) && product != "__all__") apps <- apps[apps$product == product, ]
  if (!is.null(stage) && stage != "__all__") apps <- apps[apps$current_stage == stage, ]
  if (!is.null(dates)) {
    if (length(dates) != 2L || anyNA(as.Date(dates)) || dates[1] > dates[2]) return(apps[FALSE, ])
    apps <- apps[apps$submitted_date >= as.Date(dates[1]) & apps$submitted_date <= as.Date(dates[2]), ]
  }
  apps
}

summary_kpis <- function(apps) {
  list(applications = nrow(apps), pending = sum(apps$is_pending), completed = sum(apps$is_completed),
       data_issues = sum(apps$current_stage == "Data issue"),
       median_pending_days = safe_median(apps$pending_age_days),
       median_turnaround_days = safe_median(apps$turnaround_days))
}

department_kpis <- function(apps, events) {
  history <- events[events$application_id %in% apps$application_id & events$department %in% DEPARTMENTS, ]
  history$visit_hours <- as.numeric(difftime(history$exited_time, history$entered_time, units = "hours"))
  visits <- history |>
    dplyr::group_by(.data$application_id, .data$department) |>
    dplyr::summarise(hours = sum(.data$visit_hours, na.rm = TRUE), has_open = any(is.na(.data$exited_time)), .groups = "drop") |>
    dplyr::filter(!.data$has_open)
  completed <- visits |>
    dplyr::group_by(.data$department) |>
    dplyr::summarise(completed_applications = dplyr::n(), median_turnaround_hours = safe_median(.data$hours), .groups = "drop")
  pending <- apps |>
    dplyr::filter(.data$is_pending) |>
    dplyr::group_by(department = .data$current_department) |>
    dplyr::summarise(pending_applications = dplyr::n(), median_pending_days = safe_median(.data$pending_age_days),
                     p90_pending_days = safe_quantile(.data$pending_age_days, .9), .groups = "drop")
  result <- data.frame(department = DEPARTMENTS) |>
    dplyr::left_join(completed, by = "department", relationship = "one-to-one") |>
    dplyr::left_join(pending, by = "department", relationship = "one-to-one")
  result$completed_applications[is.na(result$completed_applications)] <- 0L
  result$pending_applications[is.na(result$pending_applications)] <- 0L
  result
}

fanout_fixture <- function() {
  a <- data.frame(application_id = sprintf("BUG%04d", seq_len(1000)))
  h <- data.frame(application_id = a$application_id, event_id = sprintf("E%04d", seq_len(1000)),
                  status_at = as.POSIXct("2026-09-01", tz = "UTC"), stage = "Credit review")
  old <- h[seq_len(180), ]; old$event_id <- paste0(old$event_id, "_old")
  old$status_at <- old$status_at - 86400; old$stage <- "Documents"
  history <- rbind(h, old)
  naive <- dplyr::left_join(a, history, by = "application_id", relationship = "one-to-many")
  latest <- history |>
    dplyr::arrange(.data$application_id, dplyr::desc(.data$status_at), dplyr::desc(.data$event_id)) |>
    dplyr::distinct(.data$application_id, .keep_all = TRUE)
  fixed <- dplyr::left_join(a, latest, by = "application_id", relationship = "one-to-one")
  list(applications = a, history = history, naive = naive, fixed = fixed,
       reconciliation = data.frame(metric = c("True applications", "Naive joined rows", "Corrected rows", "Corrected unique IDs", "Inflation percent"),
                                    value = c(nrow(a), nrow(naive), nrow(fixed), dplyr::n_distinct(fixed$application_id),
                                              (nrow(naive) / nrow(a) - 1) * 100)))
}

csv_safe <- function(frame) {
  for (col in names(frame)) {
    if (inherits(frame[[col]], "POSIXt")) frame[[col]] <- utc_string(frame[[col]])
    if (is.character(frame[[col]])) {
      risky <- !is.na(frame[[col]]) & grepl("^[[:space:]]*[=+@-]", frame[[col]])
      frame[[col]][risky] <- paste0("'", frame[[col]][risky])
    }
  }
  frame
}

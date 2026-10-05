DISPLAY_TZ <- "Asia/Dhaka"
STAGE_DEPARTMENT <- c(
  "Received" = "Operations", "Documents" = "Compliance",
  "Credit review" = "Credit", "Final review" = "Committee",
  "Approved" = "Closed", "Rejected" = "Closed", "Withdrawn" = "Closed"
)
TERMINAL_STAGES <- c("Approved", "Rejected", "Withdrawn")
DEPARTMENTS <- c("Operations", "Compliance", "Credit", "Committee")
APP_COLUMNS <- c("application_id", "branch", "product", "submitted_at", "requested_amount_bdt")
EVENT_COLUMNS <- c("event_id", "application_id", "stage", "department", "entered_at", "exited_at", "recorded_at")

parse_utc <- function(x) {
  # Strict wire format prevents ambiguous locale/day-month interpretation.
  x <- as.character(x)
  shape <- !is.na(x) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", x)
  result <- suppressWarnings(as.POSIXct(strptime(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")))
  canonical <- format(result, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  result[!shape | is.na(canonical) | canonical != x] <- as.POSIXct(NA, tz = "UTC")
  result
}
utc_string <- function(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
local_string <- function(x) {
  if (is.null(x) || length(x) == 0L || is.na(x)) return("Never")
  format(x, "%d %b %Y, %H:%M:%S %Z", tz = DISPLAY_TZ)
}
blank <- function(x) is.na(x) | trimws(as.character(x)) == ""
safe_median <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else median(x, na.rm = TRUE)
safe_quantile <- function(x, p) if (!length(x) || all(is.na(x))) NA_real_ else unname(quantile(x, p, na.rm = TRUE))
assert_columns <- function(x, columns, label) {
  missing <- setdiff(columns, names(x))
  if (length(missing)) stop(label, " schema missing: ", paste(missing, collapse = ", "))
}

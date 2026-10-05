PROJECT_ROOT <- normalizePath(file.path("..", ".."))
for (file in c("config", "generate", "quality", "metrics", "source", "plots", "ui", "server")) source(file.path(PROJECT_ROOT, "R", paste0(file, ".R")), local = FALSE)

small_raw <- generate_demo(n = 120L, seed = 123L, dirty = FALSE)
small_prepared <- prepare_snapshot(small_raw)
small_view <- application_snapshot(small_prepared)

manual_fixture <- function() {
  applications <- data.frame(application_id = c("A", "B", "C"), branch = c("Dhaka", "Dhaka", "Sylhet"),
    product = c("Working capital", "Equipment", "Working capital"),
    submitted_at = c("2026-09-01T00:00:00Z", "2026-09-02T00:00:00Z", "2026-09-03T00:00:00Z"),
    requested_amount_bdt = "100000", stringsAsFactors = FALSE)
  events <- data.frame(
    event_id = paste0("E", 1:7), application_id = c("A", "A", "A", "A", "A", "B", "C"),
    stage = c("Received", "Documents", "Credit review", "Documents", "Approved", "Received", "Received"),
    department = c("Operations", "Compliance", "Credit", "Compliance", "Closed", "Operations", "Operations"),
    entered_at = c("2026-09-01T00:00:00Z", "2026-09-02T00:00:00Z", "2026-09-03T00:00:00Z", "2026-09-04T00:00:00Z", "2026-09-06T00:00:00Z", "2026-09-02T00:00:00Z", "2026-09-03T00:00:00Z"),
    exited_at = c("2026-09-02T00:00:00Z", "2026-09-03T00:00:00Z", "2026-09-04T00:00:00Z", "2026-09-06T00:00:00Z", "", "", ""), stringsAsFactors = FALSE)
  events$recorded_at <- ifelse(events$exited_at == "", events$entered_at, events$exited_at)
  list(applications = applications, events = events,
       metadata = list(snapshot_id = "manual", as_of = "2026-09-10T00:00:00Z", synthetic = TRUE))
}

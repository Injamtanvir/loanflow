source("scripts/runtime.R")
loanflow_check_r()
loanflow_use_library()
for (file in c("config", "quality", "metrics", "source", "plots")) source(file.path("R", paste0(file, ".R")))
args <- commandArgs(trailingOnly = TRUE)
destination <- if (length(args)) args[1] else "outputs/reference"
if (dir.exists(destination) && length(list.files(destination))) stop("Choose an empty output folder")
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
raw <- read_csv_snapshot()
prepared <- prepare_snapshot(raw)
apps <- application_snapshot(prepared)
kpis <- summary_kpis(apps)
department <- department_kpis(apps, prepared$events)
fanout <- fanout_fixture()
write.csv(csv_safe(apps), file.path(destination, "application_snapshot.csv"), row.names = FALSE, na = "")
write.csv(department, file.path(destination, "department_kpis.csv"), row.names = FALSE, na = "")
write.csv(prepared$issues, file.path(destination, "quality_issues.csv"), row.names = FALSE, na = "")
write.csv(prepared$reconciliation, file.path(destination, "reconciliation.csv"), row.names = FALSE)
write.csv(fanout$reconciliation, file.path(destination, "fanout_reconciliation.csv"), row.names = FALSE)
jsonlite::write_json(list(metadata = raw$metadata, kpis = kpis), file.path(destination, "summary.json"), pretty = TRUE, auto_unbox = TRUE, na = "null")
ggplot2::ggsave(file.path(destination, "application_volume.png"), volume_plot(apps), width = 11, height = 3.5, dpi = 150)
ggplot2::ggsave(file.path(destination, "department_turnaround.png"), department_plot(department), width = 9, height = 3.5, dpi = 150)
capture.output(sessionInfo(), file = file.path(destination, "session_info.txt"))
report <- c("# LoanFlow — measured demo results", "",
  sprintf("Synthetic source snapshot: `%s`. Source as-of: %s.", raw$metadata$snapshot_id, local_string(prepared$as_of)), "",
  sprintf("- Raw application rows: %s. Valid unique applications: %s.", nrow(raw$applications), kpis$applications),
  sprintf("- Pending: %s. Completed: %s. Unreliable history: %s.", kpis$pending, kpis$completed, kpis$data_issues),
  sprintf("- Median current-department pending age: %.2f elapsed days.", kpis$median_pending_days),
  sprintf("- Median submission-to-closure turnaround: %.2f elapsed days.", kpis$median_turnaround_days), "",
  "## Controlled join-fanout demonstration", "",
  "1,000 unique applications + 1,180 historical status rows → 1,180 naive joined rows.",
  "Inflation = (1,180 − 1,000) / 1,000 = 18%. Latest-status reduction restores 1,000 rows and 1,000 unique IDs.",
  "This is a separate deliberately constructed fixture, not a production incident or the size of the main demo history.", "",
  "## Definitions and exclusions", "",
  "Counts use application grain. Completed department visits are summed per application and department before taking medians.",
  "Open app-department pairs are excluded from completed department turnaround. All durations are calendar time.",
  "Applications with ambiguous/invalid history remain in volume as Data issue and are excluded from duration and queue KPIs.",
  "Data-quality issue counts can overlap; see the row-level issue log and reconciliation separately.", "",
  "The dashboard's last-successful-refresh time is the actual session load time. It does not change the frozen source as-of date.",
  "No real applicant records, lending outcomes, authentication or production deployment are claimed.")
writeLines(report, file.path(destination, "REPORT.md"))
files <- sort(list.files(destination, full.names = TRUE))
manifest <- list(source_snapshot_sha256 = snapshot_hash(raw),
                 output_sha256 = setNames(lapply(files, digest::digest, algo = "sha256", file = TRUE), basename(files)))
jsonlite::write_json(manifest, file.path(destination, "manifest.json"), auto_unbox = TRUE, pretty = TRUE)
cat(paste(report[1:9], collapse = "\n"), "\nReport folder:", destination, "\n")

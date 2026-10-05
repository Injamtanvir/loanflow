test_that("controlled fanout is exactly 18 percent and correction restores the required grain", {
  fixture <- fanout_fixture()
  expect_equal(nrow(fixture$naive), 1180L)
  expect_equal(nrow(fixture$fixed), 1000L)
  expect_equal(dplyr::n_distinct(fixture$fixed$application_id), 1000L)
  expect_equal(tail(fixture$reconciliation$value, 1), 18, tolerance = 1e-10)
  expect_true(all(fixture$fixed$stage == "Credit review"))
})

test_that("known application and department durations have correct denominators", {
  p <- prepare_snapshot(manual_fixture()); a <- application_snapshot(p)
  k <- summary_kpis(a); d <- department_kpis(a, p$events)
  expect_equal(k$applications, 3L)
  expect_equal(k$pending, 2L)
  expect_equal(k$completed, 1L)
  expect_equal(k$median_pending_days, 7.5)
  expect_equal(k$median_turnaround_days, 5)
  # A visits Compliance for 24h and 48h: sum first, then median = 72, not 36.
  expect_equal(d$median_turnaround_hours[d$department == "Compliance"], 72)
  expect_equal(d$completed_applications[d$department == "Compliance"], 1L)
  expect_equal(d$pending_applications[d$department == "Operations"], 2L)
})

test_that("filters are combined and dates are inclusive in Dhaka", {
  a <- application_snapshot(prepare_snapshot(manual_fixture()))
  f <- filter_applications(a, "Dhaka", "Working capital", as.Date(c("2026-09-01", "2026-09-01")), "Approved")
  expect_identical(f$application_id, "A")
  expect_equal(nrow(filter_applications(a, branch = "missing")), 0L)
  expect_equal(nrow(filter_applications(a, dates = as.Date(c("2026-10-01", "2026-09-01")))), 0L)
  expect_equal(as.Date(parse_utc("2026-09-01T20:00:00Z"), tz = DISPLAY_TZ), as.Date("2026-09-02"))
})

test_that("empty cohorts return zero counts and undefined medians rather than zero durations", {
  a <- small_view[FALSE, ]; k <- summary_kpis(a); d <- department_kpis(a, small_prepared$events)
  expect_equal(k$applications, 0L); expect_equal(k$pending, 0L)
  expect_true(is.na(k$median_pending_days)); expect_true(is.na(k$median_turnaround_days))
  expect_true(all(d$completed_applications == 0L)); expect_true(all(is.na(d$median_turnaround_hours)))
})

test_that("all application histories reduce to exactly one view row and partition totals", {
  expect_equal(nrow(small_view), 120L)
  expect_false(anyDuplicated(small_view$application_id) > 0L)
  k <- summary_kpis(small_view)
  expect_equal(k$applications, k$pending + k$completed + k$data_issues)
  expect_true(all(small_view$pending_age_days >= 0, na.rm = TRUE))
})

test_that("export text neutralizes spreadsheet formulas", {
  result <- csv_safe(data.frame(x = c("=1+1", " @SUM(1)", "normal")))
  expect_equal(result$x, c("'=1+1", "' @SUM(1)", "normal"))
})

test_that("department plot handles cohorts with no completed visits", {
  a <- application_snapshot(prepare_snapshot(manual_fixture()))
  pending_only <- a[a$application_id == "B", ]
  d <- department_kpis(pending_only, prepare_snapshot(manual_fixture())$events)
  expect_true(all(is.na(d$median_turnaround_hours)))
  expect_no_error(ggplot2::ggplot_build(department_plot(d)))
})

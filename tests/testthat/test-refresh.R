test_that("failed refresh retains data and last successful time", {
  t1 <- parse_utc("2026-10-02T00:00:00Z"); t2 <- t1 + 300
  s <- refresh_snapshot(new_refresh_state(), function() manual_fixture(), t1)
  expect_null(s$error); expect_equal(s$last_success, t1)
  failed <- refresh_snapshot(s, function() stop("a simulated outage"), t2)
  expect_identical(failed$data, s$data)
  expect_equal(failed$last_success, t1); expect_equal(failed$last_attempt, t2)
  expect_match(failed$error, "Refresh failed")
  recovered <- refresh_snapshot(failed, function() manual_fixture(), t2 + 300)
  expect_null(recovered$error); expect_equal(recovered$last_success, t2 + 300)
})

test_that("first-load failure has no fabricated refresh timestamp", {
  state <- refresh_snapshot(new_refresh_state(), function() stop("outage"))
  expect_null(state$data); expect_null(state$last_success)
})

test_that("Shiny filters and manual refresh use the same application cohort", {
  count <- 0L
  loader <- function() { count <<- count + 1L; manual_fixture() }
  shiny::testServer(make_server(loader, function() parse_utc("2026-10-02T00:00:00Z")), {
    session$setInputs(branch = "__all__", product = "__all__", stage = "__all__",
                      dates = as.Date(c("2026-09-01", "2026-09-10")), refresh = 0, auto_refresh = 0)
    expect_equal(kpis()$applications, 3L)
    session$setInputs(branch = "Dhaka", product = "Working capital", stage = "Approved")
    expect_equal(filtered()$application_id, "A")
    expect_equal(kpis()$median_turnaround_days, 5)
    before <- count
    session$setInputs(refresh = 1)
    expect_gt(count, before)
    expect_equal(filtered()$application_id, "A")
  })
})

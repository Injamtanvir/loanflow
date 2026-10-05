test_that("invalid time formats and impossible dates are rejected", {
  expect_true(all(is.na(parse_utc(c("2026-02-30T00:00:00Z", "2026-09-01", "not-a-time", NA)))))
  expect_false(is.na(parse_utc("2026-09-01T00:00:00Z")))
})

test_that("dirty fixture exposes missing fields duplicates and invalid timestamps", {
  raw <- generate_demo(120L, dirty = TRUE); p <- prepare_snapshot(raw)
  expect_true(all(c("missing_required_field", "duplicate_event_exact", "duplicate_event_natural_key",
                    "invalid_event_timestamp", "duplicate_application_conflict") %in% p$issues$check))
  expect_true(nrow(p$applications) < 120L)
  a <- application_snapshot(p)
  expect_true(all(a$current_stage[a$application_id %in% p$unreliable_ids] == "Data issue"))
})

test_that("exact and natural duplicate events do not change KPIs", {
  raw <- manual_fixture()
  expected <- application_snapshot(prepare_snapshot(raw))
  duplicate <- raw$events[2, ]; duplicate$event_id <- "OTHER-ID"
  raw$events <- rbind(raw$events, raw$events[1, ], duplicate)
  p <- prepare_snapshot(raw)
  expect_equal(application_snapshot(p), expected)
  expect_equal(nrow(p$events), 7L)
})

test_that("invalid or overlapping timelines never silently fall back to an earlier stage", {
  raw <- manual_fixture(); raw$events$exited_at[2] <- "2026-09-05T00:00:00Z"
  raw$events$recorded_at[2] <- "2026-09-05T00:00:00Z"
  p <- prepare_snapshot(raw); a <- application_snapshot(p)
  expect_equal(a$current_stage[a$application_id == "A"], "Data issue")
  expect_false("A" %in% p$events$application_id)
  raw <- manual_fixture(); raw$events$entered_at[5] <- "broken"
  p <- prepare_snapshot(raw); a <- application_snapshot(p)
  expect_equal(a$current_stage[a$application_id == "A"], "Data issue")
})

test_that("conflicting event IDs quarantine both versions and the application's history", {
  raw <- manual_fixture(); bad <- raw$events[2, ]; bad$stage <- "Credit review"
  raw$events <- rbind(raw$events, bad)
  p <- prepare_snapshot(raw)
  expect_equal(sum(p$issues$check == "duplicate_event_id_conflict"), 2L)
  expect_true("A" %in% p$unreliable_ids)
})

test_that("a required missing column fails the snapshot rather than showing partial KPIs", {
  raw <- manual_fixture(); raw$applications$branch <- NULL
  expect_error(prepare_snapshot(raw), "schema missing")
})

test_that("generator is reproducible", {
  expect_identical(generate_demo(100L, 2L, FALSE), generate_demo(100L, 2L, FALSE))
})

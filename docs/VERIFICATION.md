# Verification record

Validation completed across 2026-10-03 and 2026-10-04 in temporary Linux environments.

## Executed checks

- Generated 5,000 logical synthetic applications and their status histories with seed 42, including deliberate quality defects.
- Ran the full original R test suite with live PostgreSQL: all 17 original test cases passed. The database integration test verified idempotent upload, content hashes, dirty-row preservation, application-view equality and rejection of conflicting snapshot content.
- Uploaded and reloaded the complete demo through PostgreSQL. Its content hash and derived application view matched CSV mode exactly.
- Executed `sql/fanout_demo.sql`: 1,000 true applications, 1,180 naive joined rows, 1,000 corrected rows, 1,000 corrected unique IDs, 18% inflation.
- Added a regression test for department charts when a cohort has no completed department visits. The final suite has 18 test cases: the final 17 non-database cases passed; the already-verified database case was skipped in the replacement runtime, which had no PostgreSQL installation. Database code was unchanged.
- Tested the real Shiny interface in Chromium: date selection, branch/product/stage combinations, all tabs, CSV download, reset, manual refresh timestamp, desktop layout and 390-pixel mobile width.
- An August-only date filter returned exactly 1,676 applications. The combined August + Dhaka Central + Working capital + Approved filter returned 89 applications. The downloaded CSV matched all 89 expected application IDs exactly.
- Final browser checks reported no JavaScript or Shiny output errors and no document-wide horizontal overflow at mobile width.

The first environment's distribution-packaged JavaScript assets produced a date-picker error. Final browser validation used the official locked Shiny 1.8.0 and jquerylib 0.1.4 packages. `scripts/setup.R` restores CRAN packages through `renv.lock`, rather than those distribution-patched assets.

## Measured demo results

| Measure | Result |
|---|---:|
| Raw application rows | 5,004 |
| Logical generated applications | 5,000 |
| Valid unique applications | 4,988 |
| Pending applications | 974 |
| Completed applications | 4,009 |
| Applications with unreliable history | 5 |
| Median current-department pending age | 6.85 elapsed days |
| Median submission-to-closure turnaround | 8.04 elapsed days |

The valid population reconciles: 974 + 4,009 + 5 = 4,988. The independent 18% fixture is not the main dataset's raw-history multiplication rate.

## Runtime and limits

R 4.3.3, Shiny 1.8.0, dplyr 1.1.4, ggplot2 3.4.4 and DT 0.31 were used. Live database checks used PostgreSQL 16.15 and RPostgres 1.4.10. Exact dependency versions are recorded in `renv.lock`; the original report session is in `examples/reference/session_info.txt`.

The supplied Docker Compose service targets PostgreSQL 17, but Docker startup was not executed here. The GitHub Actions workflow has not run on GitHub because this project has not been pushed to a repository. macOS instructions are provided, but no physical Mac was used for validation. A complete cold dependency restore on macOS remains a device-side check.

The package contains measured report tables, a data-quality issue log, ggplot figures, desktop/mobile screenshots and `browser-verification.json`. Source data is synthetic and frozen at 2026-10-01 00:00 UTC. Actual refresh times in screenshots reflect the test sessions, not newer source data.


## Setup repair, 2026-10-05 (v1.0.1)

The supplied Mac log showed Homebrew R 4.6.1 compiling the R 4.3.3 lockfile. The installer now requires exactly R 4.3.3; all application/script entrypoints check it. The project library is separated by R version and platform, and the Mac launcher selects an explicit compatible executable. No dashboard calculations or source data were changed.

Verification for this repair:
- Base-R bootstrap regression checks passed under extracted Ubuntu R 4.3.3.
- The full setup entrypoint rejected a simulated R 4.6.1 before creating a package library.
- All 23 R source/test/profile files parsed successfully.
- Bash syntax check passed; launcher subprocess checks verified version selection, invalid-version rejection, project working directory and arguments containing spaces.
- Full dependency restore, dashboard and PostgreSQL tests were not rerun for this bootstrap-only patch. Original application verification above remains historical evidence. Native macOS 27 installation has not been tested here.

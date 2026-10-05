# Explaining LoanFlow

## Short project explanation

“LoanFlow is an independent R Shiny operations dashboard over synthetic SME applications. I used dplyr to build an application-grain view and ggplot2 for intake and department turnaround charts. The dashboard filters by branch, product, application date and current stage. It runs from bundled CSV data or PostgreSQL and exposes data-quality issues and last-successful-refresh information.”

Only present implementation work as your own to the extent you performed and understand it. This package is a starting point to run, study, test and extend.

## What was the 18% bug?

It is an invented, executable test case: 1,000 application records joined to 1,180 historical status records. A naive `nrow()` on the joined table reports 1,180, overstating volume by `(1180 - 1000) / 1000 = 18%`. The corrected pipeline selects one latest valid status per application before a constrained one-to-one join. It reconciles both row count and unique application IDs.

This was not a real production incident. Do not claim a real organization's reporting was inflated. The main demo contains full histories and is distinct from the controlled 18% fixture.

## Why is COUNT(DISTINCT) not the entire fix?

It can repair a displayed application count, but duplicated application amounts would still overstate sums, and repeated observations can distort averages. Fix the join grain first, then use unique-ID counts as reconciliation checks. Historical-duration analysis has its own explicit application/department grain.

## What does pending age mean?

Time since entry to the application's current department, at the source snapshot cutoff. It is different from total time since submission, which is available in the export. The cutoff does not change just because the dashboard reloads.

## Why sum department visits first?

Rework may send an application to the same department twice. If one application spends 24 and 48 hours there, it has 72 hours of departmental work, not two independent applications with a median of 36 hours. Open application/department pairs are excluded from completed-turnaround metrics.

## How do you handle bad timestamps or status histories?

I log the affected raw rows and quarantine invalid application records. For a valid application with an invalid event timeline, I retain it in volume as Data issue and exclude it from queue and duration KPIs. Dropping only the bad event could make a previous stage look current when it is not.

## What happens during a database outage?

A candidate refresh is published only after reading and validation succeed. If it fails, the existing snapshot and last successful refresh timestamp remain unchanged, and an error banner appears. On an initial-load failure, no success timestamp is fabricated.

## Portfolio wording

- Built an R Shiny/dplyr/ggplot2 dashboard over synthetic SME applications with PostgreSQL ingestion, branch/product/date/stage filters and documented department KPIs.
- Reproduced and corrected an invented join-fanout case that inflated counts by 18%; reduced history to application grain and reconciled row counts with unique IDs.
- Added missing-field, duplicate-event and invalid-timestamp checks, plus failure-safe refresh behavior and an explicit KPI dictionary.

Useful next exercises: add a business-hours calendar with tests, compare branch case mix, build proper authentication for an authorized test environment, or add a versioned ingestion job. Treat these as new work rather than claiming they are already implemented.

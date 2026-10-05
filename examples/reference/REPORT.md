# LoanFlow — measured demo results

Synthetic source snapshot: `demo-5000-42-quality`. Source as-of: 01 Oct 2026, 06:00:00 +06.

- Raw application rows: 5004. Valid unique applications: 4988.
- Pending: 974. Completed: 4009. Unreliable history: 5.
- Median current-department pending age: 6.85 elapsed days.
- Median submission-to-closure turnaround: 8.04 elapsed days.

## Controlled join-fanout demonstration

1,000 unique applications + 1,180 historical status rows → 1,180 naive joined rows.
Inflation = (1,180 − 1,000) / 1,000 = 18%. Latest-status reduction restores 1,000 rows and 1,000 unique IDs.
This is a separate deliberately constructed fixture, not a production incident or the size of the main demo history.

## Definitions and exclusions

Counts use application grain. Completed department visits are summed per application and department before taking medians.
Open app-department pairs are excluded from completed department turnaround. All durations are calendar time.
Applications with ambiguous/invalid history remain in volume as Data issue and are excluded from duration and queue KPIs.
Data-quality issue counts can overlap; see the row-level issue log and reconciliation separately.

The dashboard's last-successful-refresh time is the actual session load time. It does not change the frozen source as-of date.
No real applicant records, lending outcomes, authentication or production deployment are claimed.

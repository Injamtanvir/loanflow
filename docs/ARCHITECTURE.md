# Architecture and operational behavior

CSV and PostgreSQL adapters return the same three-part snapshot: applications, status history, and metadata. They do not calculate KPIs. `prepare_snapshot()` validates the schema, raw rows, relationships and complete event sequences. It produces valid application rows, reliable event histories, an issue log and reconciliation totals.

`application_snapshot()` orders reliable history and reduces it to one latest event per application **before** joining. The dplyr join explicitly enforces one-to-one cardinality. The result is asserted to match the application table's row count and uniqueness. Amounts and application-level denominators therefore cannot multiply with historical visits.

The Shiny server stores one prepared snapshot in a session-local reactive value. Sidebar filters derive an application cohort. Both the cards and charts derive from that cohort. Department metrics operate on only its application IDs, aggregate visits to application/department totals, then aggregate those totals to departments. The view and exports use the same calculations.

## Refresh semantics

Refresh fully reads and prepares a candidate snapshot before replacing the active state. A failed source connection, missing required column, invalid metadata or absence of any valid applications leaves the previous data and successful timestamp untouched. The latest attempt time and a visible error banner are updated. Recoverable dirty rows result in a successful load with quality issues, not a failed refresh.

The success timestamp is per-session and in memory. It is not shared across users or persisted across app restarts. The source cutoff is an independent value used for pending ages. The frozen demo therefore remains a frozen demo after refresh; only its retrieval time changes. Auto-refresh is off by default and can be set to 60 or 300 seconds.

Each successful refresh updates filter choices, keeping selections that still exist. A selection that no longer exists returns to All. The existing application-date range is preserved unless reset. Empty filtered cohorts show zero volume and unavailable medians, not invented zero-day turnaround.

## Database design

PostgreSQL stores immutable, content-hashed raw snapshots. Both raw tables are scoped by snapshot ID and raw-row ID. Business-key duplicates are deliberately allowed there so diagnostic checks can see them. Upload uses an insert-first transaction and a locked snapshot row; a second identical upload is idempotent, while the same ID with different content is rejected.

The database adapter reads a selected snapshot in a read-only, repeatable-read transaction. Metadata and both data tables therefore share one database view. Connections are opened and closed per refresh, with a short connect timeout and a server statement timeout. Query values are bound parameters; credentials come from `.Renviron`, never from browser inputs. The UI shows a generic error on failed refresh instead of connection details.

CSV sources are read-only in normal dashboard use. For custom CSV updates, write a new complete directory and point `LOANFLOW_DATA_DIR` to it before restarting. Do not overwrite CSV files while another session is refreshing: the file adapter is not a transactional storage engine. The supplied generator refuses nonempty destinations.

## Testing strategy

Small fixtures with analytically known answers verify elapsed-time calculations, rework sums, filter intersections, timestamp validation, duplicates and empty cohorts. A dedicated fixture proves exactly 18% fanout and verifies corrected counts and statuses. Shiny `testServer()` exercises the server's reactive filter and refresh paths. A separate test simulates failure and recovery to protect the last-success semantics.

The PostgreSQL integration test uploads dirty data twice, confirms row counts and hashes, compares derived application views to the in-memory source, and rejects a conflicting overwrite. A GitHub Actions workflow runs R checks against a PostgreSQL service. Execution status is documented separately in `VERIFICATION.md`.

This project is intentionally an educational local application. Authentication, authorization, real-data governance, user concurrency/load testing, business calendars and production deployment are future work, not implemented claims.

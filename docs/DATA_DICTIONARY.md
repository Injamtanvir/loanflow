# LoanFlow data dictionary and KPI contract

## Source tables

All records are synthetic. The wire timestamp format is strictly `YYYY-MM-DDTHH:MM:SSZ`. Invalid dates, invalid formats and future observation times are rejected. The dashboard displays timestamps in Asia/Dhaka. CSV exports retain UTC wire timestamps.

| Application field | Grain/type | Required | Meaning |
|---|---|---|---|
| application_id | Application / text | Yes | Logical unique application key; duplicates may occur in raw landing data |
| branch | Application / text | Yes | Servicing branch label at submission |
| product | Application / text | Yes | Requested product label |
| submitted_at | Application / UTC timestamp text | Yes | Time the application entered the institution |
| requested_amount_bdt | Application / positive numeric text | Yes | Requested principal; not approved/disbursed amount |

| Event field | Grain/type | Required | Meaning |
|---|---|---|---|
| event_id | Status visit / text | Yes | Source event key |
| application_id | Status visit / text | Yes | Link to the owning valid application |
| stage | Status visit / category | Yes | Received, Documents, Credit review, Final review, Approved, Rejected, Withdrawn |
| department | Status visit / category | Yes | Operations, Compliance, Credit, Committee, or Closed, matching stage |
| entered_at | Status visit / UTC timestamp text | Yes | Entry into this stage/department |
| exited_at | Status visit / nullable timestamp text | No | Exit time; blank for an active visit or terminal marker |
| recorded_at | Status visit / UTC timestamp text | Yes | Availability time for this snapshot's complete event record; at/after entry and any known exit |

| Metadata | Meaning |
|---|---|
| snapshot_id | Immutable identifier for a particular raw dataset |
| as_of | Observation cutoff; every trusted application/event timestamp must be at or before it |
| synthetic | Must be true in this educational application |
| seed | Generator seed, when supplied |

PostgreSQL adds `snapshot_id` and `raw_row_id` to both landing tables. Their composite key identifies raw rows, **not** logical applications/events. Text timestamps intentionally retain malformed source values so quality checks can report them. `snapshots.uploaded_at` is ingestion time, not source freshness or session refresh time.

## Stage-to-department mapping

| Stage | Department | Terminal? |
|---|---|---|
| Received | Operations | No |
| Documents | Compliance | No |
| Credit review | Credit | No |
| Final review | Committee | No |
| Approved | Closed | Yes |
| Rejected | Closed | Yes |
| Withdrawn | Closed | Yes |

The generator includes returns from Credit to Compliance. The validator allows non-overlapping rework but forbids events after a terminal marker. A terminal marker uses its entry time as closure time. It is excluded from department processing durations.

## KPI definitions

| KPI | Formula and denominator | Empty result |
|---|---|---|
| Application volume | Count unique valid application IDs matching all four filters, including Data issue records | 0 |
| Pending applications | Reliable latest stage is non-terminal | 0 |
| Completed applications | Latest reliable stage is Approved, Rejected or Withdrawn | 0 |
| Median pending age | Median `(as_of − current stage entered_at) / 86400` over pending applications | NA, displayed as dash |
| Total pending age | `(as_of − submitted_at) / 86400`, pending applications only; exported at row level | NA |
| Median overall turnaround | Median `(terminal entered_at − submitted_at) / 86400` over completed applications | NA, dash |
| Department pending count | Current pending applications in that department | 0 |
| Department median/p90 pending age | Median/90th percentile of current-stage pending ages in the department; R's default type-7 percentile | NA |
| Department completed-app count | Number of application/department pairs with observed visits, all closed; terminal markers excluded | 0 |
| Department median turnaround | Sum closed visit hours per application/department; take median across the completed pairs | NA |
| Last successful refresh | Wall-clock time of the most recent successful source read, validation and view publication in this browser session | Never |
| Source as-of | Cutoff from source metadata; used for all pending ages | No data |

Example: an application spends 24 hours and then 48 hours in Compliance. Its department duration is **72 hours**. Counting the visits independently would give an incorrect 36-hour median for this single application. If it is still in an open Compliance visit, the pair is excluded from completed Compliance turnaround.

An application can contribute to multiple departments' completed counts. Summing those counts does not give total application volume. Pending department counts do sum to the pending card. Application volume partitions into completed + pending + Data issue.

The department measure describes completed **observed** departmental work by the cutoff. It does not guarantee the application will never return to that department later. It is not a causal measure of employee performance; case mix and unfinished work can affect comparisons.

## Filters and data scope

All filters combine using AND. Branch/product use exact labels; stage means **current** stage. Date range filters the submission cohort using Asia/Dhaka calendar dates, inclusive. Historical department work is restricted to these application IDs, not to events whose event dates are within the submission-date range.

Data quality and the fanout fixture are intentionally independent of dashboard filters and are labeled accordingly. The application CSV export follows the four sidebar filters. The table's separate text search/sort does not redefine the exported cohort.

## Quality policies

1. Missing required application fields, bad/future submission times and nonpositive/nonfinite amounts quarantine the application row.
2. Identical application rows collapse to the first raw occurrence. Conflicting versions of one application ID quarantine **all** versions.
3. Identical event rows collapse. Different IDs with the same `(application_id, stage, department, entered_at, exited_at)` collapse to the first raw occurrence, with an issue recorded. This natural key describes one visit, regardless of retransmission time.
4. Conflicting payloads for one event ID quarantine both versions and mark the owning application's entire history unreliable.
5. Events must reference a valid application; stage and department must match the mapping.
6. Entry must be on/after submission and on/before as-of. A known exit cannot precede entry or follow as-of. Recorded time must be on/after entry and any known exit, and on/before as-of.
7. Timelines cannot have tied entries, overlapping visits, open visits before another visit, or visits after terminal closure. A final non-terminal event must be open.
8. Any non-duplicate invalid event for a valid application makes its full history unreliable. Missing history also produces Data issue. Such applications remain in valid volume but contribute to neither pending nor completed KPIs.

Clean timestamps may contain gaps between closed visits. Those gaps count in overall elapsed turnaround but not in a specific department's visit time. The model does not infer holidays, office hours or department ownership during such gaps.

The issue log is one row per triggered rule and affected raw source row. It can contain multiple entries for one row. `reconciliation.csv` independently reports raw application rows, unique raw IDs, valid application rows, raw event rows, retained reliable event rows and applications with unreliable history.

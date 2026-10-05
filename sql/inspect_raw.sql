-- These queries inspect raw ingestion grain, NOT validated operational KPIs.
SELECT snapshot_id, as_of, uploaded_at FROM loanflow.snapshots ORDER BY as_of DESC;

SELECT snapshot_id, count(*) AS raw_rows, count(DISTINCT application_id) AS unique_ids
FROM loanflow.raw_applications GROUP BY snapshot_id;

SELECT snapshot_id, application_id, count(*) AS raw_copies
FROM loanflow.raw_applications GROUP BY snapshot_id, application_id HAVING count(*) > 1;

SELECT snapshot_id, event_id, count(*) AS raw_copies
FROM loanflow.raw_status_history GROUP BY snapshot_id, event_id HAVING count(*) > 1;

SELECT snapshot_id, raw_row_id, application_id
FROM loanflow.raw_applications
WHERE NULLIF(trim(branch), '') IS NULL OR NULLIF(trim(product), '') IS NULL
   OR NULLIF(trim(submitted_at), '') IS NULL;

-- Raw timestamps are text on purpose: malformed values must survive ingestion so
-- R can validate and report them. Do not cast dirty timestamps without validation.

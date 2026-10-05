-- Self-contained invented regression fixture. It does not mutate your database.
WITH applications AS (
  SELECT generate_series(1, 1000) AS application_id
), status_history AS (
  SELECT application_id, application_id AS event_id,
         TIMESTAMPTZ '2026-09-01 00:00:00+00' AS entered_at, 'Credit review' AS stage
  FROM applications
  UNION ALL
  SELECT application_id, application_id + 1000 AS event_id,
         TIMESTAMPTZ '2026-08-31 00:00:00+00', 'Documents'
  FROM applications WHERE application_id <= 180
), ranked AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY application_id ORDER BY entered_at DESC, event_id DESC
  ) AS rank
  FROM status_history
), naive AS (
  SELECT a.application_id FROM applications a LEFT JOIN status_history h USING (application_id)
), corrected AS (
  SELECT a.application_id, h.stage FROM applications a
  LEFT JOIN ranked h ON a.application_id = h.application_id AND h.rank = 1
)
SELECT (SELECT count(*) FROM applications) AS true_applications,
       (SELECT count(*) FROM naive) AS naive_rows,
       (SELECT count(*) FROM corrected) AS corrected_rows,
       (SELECT count(DISTINCT application_id) FROM corrected) AS corrected_unique_ids,
       round(100.0 * ((SELECT count(*) FROM naive) - (SELECT count(*) FROM applications)) /
         (SELECT count(*) FROM applications), 2) AS inflation_percent;

CREATE SCHEMA IF NOT EXISTS loanflow;
CREATE TABLE IF NOT EXISTS loanflow.snapshots (
  snapshot_id text PRIMARY KEY,
  as_of timestamptz NOT NULL,
  synthetic boolean NOT NULL CHECK (synthetic),
  content_sha256 text NOT NULL,
  metadata_json text NOT NULL,
  uploaded_at timestamptz NOT NULL DEFAULT now()
);
-- Raw landing tables deliberately preserve dirty fields and duplicate business keys.
-- raw_row_id, not application_id/event_id, is the raw-table grain.
CREATE TABLE IF NOT EXISTS loanflow.raw_applications (
  snapshot_id text NOT NULL REFERENCES loanflow.snapshots(snapshot_id),
  raw_row_id integer NOT NULL,
  application_id text, branch text, product text, submitted_at text, requested_amount_bdt text,
  PRIMARY KEY (snapshot_id, raw_row_id)
);
CREATE TABLE IF NOT EXISTS loanflow.raw_status_history (
  snapshot_id text NOT NULL REFERENCES loanflow.snapshots(snapshot_id),
  raw_row_id integer NOT NULL,
  event_id text, application_id text, stage text, department text,
  entered_at text, exited_at text, recorded_at text,
  PRIMARY KEY (snapshot_id, raw_row_id)
);
CREATE INDEX IF NOT EXISTS loanflow_app_id_idx ON loanflow.raw_applications(snapshot_id, application_id);
CREATE INDEX IF NOT EXISTS loanflow_event_app_idx ON loanflow.raw_status_history(snapshot_id, application_id);

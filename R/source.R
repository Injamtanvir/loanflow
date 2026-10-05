read_csv_snapshot <- function(directory = Sys.getenv("LOANFLOW_DATA_DIR", "data/demo")) {
  read_text <- function(name) read.csv(file.path(directory, name), colClasses = "character", na.strings = "",
                                      check.names = FALSE, stringsAsFactors = FALSE)
  list(applications = read_text("applications.csv"), events = read_text("status_history.csv"),
       metadata = jsonlite::read_json(file.path(directory, "metadata.json"), simplifyVector = TRUE))
}

connect_postgres <- function() {
  DBI::dbConnect(RPostgres::Postgres(),
    host = Sys.getenv("PGHOST", "127.0.0.1"), port = as.integer(Sys.getenv("PGPORT", "5434")),
    dbname = Sys.getenv("PGDATABASE", "loanflow"), user = Sys.getenv("PGUSER", "loanflow"),
    password = Sys.getenv("PGPASSWORD", "local_demo_only"),
    sslmode = Sys.getenv("PGSSLMODE", "prefer"), connect_timeout = 5,
    options = "-c statement_timeout=15000", timezone = "UTC")
}

init_database <- function(con, schema_file = "sql/schema.sql") {
  sql <- paste(readLines(schema_file, warn = FALSE), collapse = "\n")
  statements <- strsplit(sql, ";", fixed = TRUE)[[1]]
  DBI::dbWithTransaction(con, {
    for (statement in statements[nzchar(trimws(statements))]) DBI::dbExecute(con, statement)
  })
  invisible(TRUE)
}

snapshot_hash <- function(raw) {
  # Hash the exact raw strings, normalizing blank fields consistently with CSV loading.
  normalize <- function(x, columns) {
    x <- as.data.frame(x[, columns], stringsAsFactors = FALSE)
    x[] <- lapply(x, function(v) { v <- as.character(v); v[is.na(v)] <- ""; v })
    x
  }
  canonical <- list(applications = normalize(raw$applications, APP_COLUMNS), events = normalize(raw$events, EVENT_COLUMNS), metadata = raw$metadata)
  digest::digest(jsonlite::toJSON(canonical, auto_unbox = TRUE, na = "null"), algo = "sha256", serialize = FALSE)
}

upload_snapshot <- function(raw, con, schema_file = "sql/schema.sql") {
  # Schema and metadata must be readable; quality failures remain in the raw landing tables.
  assert_columns(raw$applications, APP_COLUMNS, "Applications")
  assert_columns(raw$events, EVENT_COLUMNS, "Events")
  stopifnot(isTRUE(raw$metadata$synthetic), !is.na(parse_utc(raw$metadata$as_of)))
  init_database(con, schema_file)
  hash <- snapshot_hash(raw)
  id <- raw$metadata$snapshot_id
  if (length(id) != 1L || blank(id)) stop("Invalid snapshot ID")
  DBI::dbWithTransaction(con, {
    # Insert-first makes concurrent uploads safe. Conflicting content is never overwritten.
    DBI::dbExecute(con, paste(
      "INSERT INTO loanflow.snapshots(snapshot_id, as_of, synthetic, content_sha256, metadata_json)",
      "VALUES ($1, $2::timestamptz, TRUE, $3, $4) ON CONFLICT DO NOTHING"),
      params = list(id, raw$metadata$as_of, hash, jsonlite::toJSON(raw$metadata, auto_unbox = TRUE)))
    stored <- DBI::dbGetQuery(con, "SELECT content_sha256 FROM loanflow.snapshots WHERE snapshot_id = $1 FOR UPDATE", params = list(id))
    if (stored$content_sha256[1] != hash) stop("Snapshot ID already exists with different content; use a new snapshot ID")
    count <- DBI::dbGetQuery(con, "SELECT count(*) AS n FROM loanflow.raw_applications WHERE snapshot_id=$1", params = list(id))$n[1]
    if (count == 0L) {
      a <- raw$applications[, APP_COLUMNS]; a[] <- lapply(a, as.character)
      a <- data.frame(snapshot_id = id, raw_row_id = seq_len(nrow(a)), a, check.names = FALSE)
      e <- raw$events[, EVENT_COLUMNS]; e[] <- lapply(e, as.character)
      e <- data.frame(snapshot_id = id, raw_row_id = seq_len(nrow(e)), e, check.names = FALSE)
      DBI::dbAppendTable(con, DBI::Id(schema = "loanflow", table = "raw_applications"), a)
      DBI::dbAppendTable(con, DBI::Id(schema = "loanflow", table = "raw_status_history"), e)
    }
  })
  invisible(id)
}

read_postgres_snapshot <- function(con, snapshot_id = Sys.getenv("LOANFLOW_SNAPSHOT_ID", "")) {
  # Metadata, applications and events must come from one consistent database snapshot.
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
    if (!nzchar(snapshot_id)) {
      row <- DBI::dbGetQuery(con, "SELECT snapshot_id FROM loanflow.snapshots ORDER BY as_of DESC, uploaded_at DESC, snapshot_id DESC LIMIT 1")
      if (!nrow(row)) stop("No uploaded snapshots")
      snapshot_id <- row$snapshot_id[1]
    }
    meta <- DBI::dbGetQuery(con, "SELECT metadata_json FROM loanflow.snapshots WHERE snapshot_id=$1", params = list(snapshot_id))
    if (!nrow(meta)) stop("Snapshot ID not found")
    a <- DBI::dbGetQuery(con, "SELECT application_id, branch, product, submitted_at, requested_amount_bdt FROM loanflow.raw_applications WHERE snapshot_id=$1 ORDER BY raw_row_id", params = list(snapshot_id))
    e <- DBI::dbGetQuery(con, "SELECT event_id, application_id, stage, department, entered_at, exited_at, recorded_at FROM loanflow.raw_status_history WHERE snapshot_id=$1 ORDER BY raw_row_id", params = list(snapshot_id))
    list(applications = a, events = e, metadata = jsonlite::fromJSON(meta$metadata_json[1]))
  })
}

load_snapshot <- function() {
  mode <- Sys.getenv("LOANFLOW_SOURCE", "csv")
  if (mode == "csv") return(read_csv_snapshot())
  if (mode != "postgres") stop("LOANFLOW_SOURCE must be csv or postgres")
  con <- connect_postgres()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  read_postgres_snapshot(con)
}

new_refresh_state <- function() list(data = NULL, last_success = NULL, last_attempt = NULL, error = NULL)

refresh_snapshot <- function(previous, loader = load_snapshot, now = Sys.time()) {
  previous$last_attempt <- now
  tryCatch({
    prepared <- prepare_snapshot(loader())
    prepared$view <- application_snapshot(prepared)
    list(data = prepared, last_success = now, last_attempt = now, error = NULL)
  }, error = function(e) {
    # Do not expose database host/user/connection strings to browser sessions.
    previous$error <- "Refresh failed. Previous successful data is retained. Check the source files, schema or database connection."
    previous
  })
}

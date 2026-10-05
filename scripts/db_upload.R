source("scripts/runtime.R")
loanflow_check_r()
loanflow_use_library()
source("R/config.R"); source("R/source.R")
if (file.exists(".Renviron")) readRenviron(".Renviron")
args <- commandArgs(trailingOnly = TRUE)
directory <- if (length(args)) args[1] else "data/demo"
con <- connect_postgres()
tryCatch({
  id <- upload_snapshot(read_csv_snapshot(directory), con)
  cat("Uploaded snapshot:", id, "\nRepeated identical uploads are safe.\n")
}, finally = DBI::dbDisconnect(con))

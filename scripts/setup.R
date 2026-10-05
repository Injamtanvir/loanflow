# Network-aware setup for the locked R 4.3.3 environment.
loanflow_download_method <- function(os = Sys.info()[["sysname"]], curl = Sys.which("curl")) {
  # The CLI and R's built-in libcurl can resolve DNS differently on macOS.
  if (identical(os, "Darwin") && nzchar(curl)) "curl" else "libcurl"
}

loanflow_probe_cran <- function(repo) {
  old <- options(timeout = 20)
  on.exit(options(old), add = TRUE)
  # Bootstrap from the source index: an old macOS binary index may be absent.
  available <- available.packages(repos = c(CRAN = repo), type = "source",
                                  method = getOption("download.file.method", "libcurl"))
  "renv" %in% rownames(available)
}

loanflow_select_cran <- function(repositories, probe = loanflow_probe_cran) {
  for (repo in unique(repositories[nzchar(repositories)])) {
    if (!grepl("^https://", repo)) stop("LOANFLOW_CRAN must be an HTTPS CRAN mirror.", call. = FALSE)
    repo <- sub("/+$", "", repo)
    message("Checking CRAN source index: ", repo)
    reachable <- tryCatch(probe(repo), error = function(e) {
      message("Repository check failed: ", conditionMessage(e)); FALSE
    })
    if (isTRUE(reachable)) return(repo)
  }
  stop(paste0("No usable CRAN source index containing renv could be read.\n",
    "This can be a network, proxy, certificate, mirror or package-index issue.\n",
    "No dependency restore was attempted. Read docs/MAC_SETUP_FIX.md (CRAN access).\n",
    "Send the warnings above plus the output of:\n",
    "curl -I --connect-timeout 15 https://cran.rstudio.com/src/contrib/PACKAGES.gz"), call. = FALSE)
}

loanflow_setup <- function() {
  if (!file.exists("DESCRIPTION")) stop("Run this script from the loanflow project folder")
  source("scripts/runtime.R")
  loanflow_check_r()
  method <- loanflow_download_method()
  options(download.file.method = method)
  # renv uses its own downloader; configure it to use the same working curl.
  Sys.setenv(RENV_DOWNLOAD_METHOD = method)
  if (identical(method, "curl")) Sys.setenv(RENV_CURL_EXECUTABLE = Sys.which("curl"))
  options(timeout = max(300, getOption("timeout", 60)))
  message("Download method: ", method)
  override <- Sys.getenv("LOANFLOW_CRAN", "")
  # An explicit override is authoritative; otherwise try independent mirrors.
  repositories <- if (nzchar(override)) override else c(
    "https://cloud.r-project.org", "https://cran.rstudio.com", "https://cran.r-project.org")
  repo <- loanflow_select_cran(repositories)
  options(repos = c(CRAN = repo))
  message("Using CRAN mirror: ", repo)
  project_library <- loanflow_use_library(create = TRUE)
  if (!requireNamespace("renv", quietly = TRUE)) {
    install.packages("renv", lib = project_library, repos = c(CRAN = repo), type = "source")
  }
  if (!requireNamespace("renv", quietly = TRUE)) {
    stop("renv installation did not complete. Fix the first download/build error above, then rerun setup.", call. = FALSE)
  }
  # Pass the mirror explicitly: otherwise restore uses the URL in renv.lock.
  renv::restore(project = ".", library = normalizePath(project_library),
    lockfile = "renv.lock", repos = c(CRAN = repo), prompt = FALSE)
  cat("Setup complete. Run: bash scripts/r.sh run.R\n")
}

loanflow_setup()

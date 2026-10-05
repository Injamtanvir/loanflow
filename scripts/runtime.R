# Base-R-only bootstrap: safe to run before any packages have been installed.
loanflow_check_r <- function(version = getRversion()) {
  if (as.character(version) != "4.3.3") {
    stop(paste0("LoanFlow's renv.lock requires R 4.3.3; this process is using R ",
                version, ".\nInstall R 4.3.3, then use bash scripts/r.sh scripts/setup.R.\n",
                "See docs/MAC_SETUP_FIX.md. No packages have been installed by this command."),
         call. = FALSE)
  }
  invisible(TRUE)
}

loanflow_library <- function(root = ".", version = getRversion(), platform = R.version$platform) {
  file.path(root, ".Rlibrary", paste0("R-", version, "-", platform))
}

loanflow_use_library <- function(create = FALSE) {
  path <- loanflow_library()
  if (create) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  # Never use the old unversioned .Rlibrary after a failed R 4.6 installation.
  if (dir.exists(path)) .libPaths(c(normalizePath(path), .libPaths()))
  invisible(path)
}

# Dependency-free regression checks. Run from project root with Rscript --vanilla.
source("scripts/runtime.R")
stopifnot(isTRUE(loanflow_check_r(package_version("4.3.3"))))
for (version in c("4.2.3", "4.3.2", "4.4.0", "4.5.3", "4.6.1")) {
  failure <- tryCatch(loanflow_check_r(package_version(version)), error = identity)
  stopifnot(inherits(failure, "error"), grepl("R 4.3.3", conditionMessage(failure)))
}
stopifnot(loanflow_library(version = "4.3.3", platform = "arm64") !=
          loanflow_library(version = "4.6.1", platform = "arm64"))
stopifnot(loanflow_library(version = "4.3.3", platform = "arm64") !=
          loanflow_library(version = "4.3.3", platform = "x86_64"))
cat("Bootstrap regression checks passed.\n")

# macOS setup recovery: R 4.6.1 versus the R 4.3.3 lockfile

## What failed

The supplied log runs Homebrew R **4.6.1** and restores package versions recorded under **R 4.3.3**. Several archived packages use R C/C++ interfaces that are not available in the newer headers. Examples include `SETLENGTH`, `ATTRIB`, `Rf_findVarInFrame3`, and `R_ext/PrtUtil.h`. These are compilation failures, not dashboard or PostgreSQL connection errors. The later Shiny startup failure follows from the incomplete dependency installation.

The original setup accepted “R 4.3 or later” and the README recommended the latest Homebrew R. That combination was incorrect for this fixed dependency set.

## Recover on your Mac

1. Stop any old setup process. Download the repaired project ZIP into a **new folder** rather than merging it over your working copy. Keep your existing data and `.Renviron` there until the demo runs.
2. Install CRAN R **4.3.3** using the package for your architecture:
   - Apple Silicon: https://cran.r-project.org/bin/macosx/big-sur-arm64/base/R-4.3.3-arm64.pkg
   - Intel: https://cran.r-project.org/bin/macosx/big-sur-x86_64/base/R-4.3.3-x86_64.pkg
   Open the downloaded package and complete the installer. Your log's `/opt/homebrew` path suggests an Apple Silicon installation; use `uname -m` to check (`arm64` means Apple Silicon, `x86_64` means Intel or a Rosetta terminal).
3. In Terminal, change into the **new** extracted `loanflow` folder and run:

```bash
bash scripts/r.sh --version
bash scripts/r.sh scripts/setup.R
bash scripts/r.sh run.R
```

The launcher prints the selected R executable and R 4.3.3. Open http://127.0.0.1:3838 once Shiny prints `Listening on ...`. Use Control+C to stop.

Do not uninstall Homebrew R or delete global package libraries. The launcher uses the CRAN framework's Rscript explicitly; a plain `Rscript` command can still resolve to Homebrew R 4.6.1. The patched project stores packages in a version- and platform-specific subfolder of `.Rlibrary`, so it does not reuse packages left by the failed installation. Nothing needs to be deleted.

If R is installed in a custom location, supply its exact executable path:

```bash
LOANFLOW_RSCRIPT="/absolute/path/to/R-4.3.3/bin/Rscript" bash scripts/r.sh scripts/setup.R
LOANFLOW_RSCRIPT="/absolute/path/to/R-4.3.3/bin/Rscript" bash scripts/r.sh run.R
```

The override is checked and will not silently run an incompatible version.

## Only if another error appears

- **Compiler missing:** run `xcode-select --install`, complete installation, then retry setup.
- **`pg_config` or libpq missing:** follow the `brew install libpq pkg-config` commands in README.md. The RPostgres driver is installed with the locked environment even when the demo source is CSV; a running PostgreSQL server is not required for CSV mode.
- **Fortran compiler missing:** archived numerical dependencies may require the toolchain matching CRAN R 4.3.3. See https://mac.r-project.org/tools/ and select the tools for that R release, not a guessed compiler flag.
- **Shiny still missing:** setup must finish successfully first. Send the first package's full compilation error and the output of `bash scripts/r.sh --version`.

## Scope and verification

This repair retains the existing lockfile and its tested R 4.3.3 runtime. It does **not** claim compatibility with R 4.6. Upgrading to R 4.6 would require refreshing and revalidating the complete dependency set.

The launcher checks the runtime before dispatch; setup also validates it before installing anything. The app, reports, generators, upload and test entrypoints perform the same check. The new base-R bootstrap test checks accepted/rejected versions and library separation. Existing dashboard business logic and data are unchanged.

This environment cannot execute a native macOS installer. Successful installation on macOS 27 has not been independently confirmed; if the installer or a source build reports a new failure, preserve that output for diagnosis.

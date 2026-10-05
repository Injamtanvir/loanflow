#!/usr/bin/env bash
# Use this project's tested R without changing or uninstalling Homebrew R.
set -euo pipefail
cd "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

compatible() {
  [[ -x "$1" ]] && [[ "$("$1" --vanilla -e 'cat(as.character(getRversion()))' 2>/dev/null)" == "4.3.3" ]]
}

selected=""
if [[ -n "${LOANFLOW_RSCRIPT:-}" ]]; then
  if compatible "$LOANFLOW_RSCRIPT"; then
    selected="$LOANFLOW_RSCRIPT"
  else
    echo "LOANFLOW_RSCRIPT must point to an executable Rscript for R 4.3.3." >&2
    exit 1
  fi
else
  # CRAN framework locations, including architecture-specific versions.
  for candidate in \
    /Library/Frameworks/R.framework/Versions/4.3-arm64/Resources/bin/Rscript \
    /Library/Frameworks/R.framework/Versions/4.3-x86_64/Resources/bin/Rscript \
    /Library/Frameworks/R.framework/Versions/4.3/Resources/bin/Rscript \
    /Library/Frameworks/R.framework/Resources/bin/Rscript \
    "$(command -v Rscript || true)"; do
    if compatible "$candidate"; then selected="$candidate"; break; fi
  done
fi

if [[ -z "$selected" ]]; then
  echo "R 4.3.3 was not found. Install the CRAN R 4.3.3 package for your Mac." >&2
  echo "See docs/MAC_SETUP_FIX.md. Homebrew R 4.6 is incompatible with this lockfile." >&2
  exit 1
fi
echo "LoanFlow: using $selected (R 4.3.3)" >&2
exec "$selected" "$@"

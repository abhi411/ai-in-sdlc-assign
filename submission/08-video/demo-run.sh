#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TARGET="$ROOT/backend/src/InvoiceApp.Domain/Invoice.cs"
BACKUP="$(mktemp "${TMPDIR:-/tmp}/Invoice.cs.XXXXXX")"
cp "$TARGET" "$BACKUP"

cleanup() {
  if [[ -f "$BACKUP" ]]; then
    cp "$BACKUP" "$TARGET"
    rm -f "$BACKUP"
  fi
}

trap cleanup EXIT INT TERM

print_banner() {
  printf '\n========================================\n'
  printf '%s\n' "$1"
  printf '========================================\n\n'
}

print_banner "Segment 1: git branch"
git branch --show-current

print_banner "Segment 2: architecture test (pass)"
dotnet test backend/InvoiceApp.sln --filter "FullyQualifiedName~ArchitectureTests"

print_banner "Segment 3: sabotage and run the architecture test (expected failure)"
python3 - "$TARGET" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text()
needle = "namespace InvoiceApp.Domain;\n\n"
insert = "namespace InvoiceApp.Domain;\n\nprivate static readonly System.Net.Http.HttpClient Sneaky = new();\n"
if "Sneaky" not in text:
    updated = text.replace(needle, insert, 1)
    path.write_text(updated)
PY
if dotnet test backend/InvoiceApp.sln --filter "FullyQualifiedName~ArchitectureTests"; then
  echo "Unexpectedly passed the sabotaged architecture check; reverting immediately."
else
  echo "Expected failure captured: the sabotage broke the domain file as intended."
fi

print_banner "Segment 4: revert the sabotage"
cp "$BACKUP" "$TARGET"

print_banner "Segment 5: race test"
dotnet test backend/InvoiceApp.sln --filter "FullyQualifiedName~ApprovalConcurrencyTests"

print_banner "Segment 6: eval summary"
sed -n '1,80p' submission/05-evals/results.md

print_banner "Segment 7: captured metrics"
printf '\n--- live git metrics ---\n'
cat submission/07-measurement/evidence/capture_git_metrics_output.txt
printf '\n--- scenario CI metrics ---\n'
cat submission/07-measurement/evidence/ci-metrics-output.txt

printf '\nDemo run complete; sabotage has been reverted.\n'

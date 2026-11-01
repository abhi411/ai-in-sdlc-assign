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

print_banner "Architecture test (pass)"
dotnet test backend/InvoiceApp.sln --filter "FullyQualifiedName~ArchitectureTests"

print_banner "Sabotage and run the architecture test (expected failure)"
python3 - "$TARGET" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text()
needle = "public class Invoice\n{\n"
insert = "public class Invoice\n{\n    private static readonly System.Net.Http.HttpClient Sneaky = new();\n"
if "Sneaky" not in text:
    updated = text.replace(needle, insert, 1)
    path.write_text(updated)
PY
if dotnet test backend/InvoiceApp.sln --filter "FullyQualifiedName~ArchitectureTests"; then
  echo "Unexpectedly passed the sabotaged architecture check; reverting immediately."
else
  echo "Expected failure captured: the sabotage broke the domain file as intended."
fi

print_banner "Revert the sabotage"
cp "$BACKUP" "$TARGET"

printf '\nDemo run complete; sabotage has been reverted.\n'

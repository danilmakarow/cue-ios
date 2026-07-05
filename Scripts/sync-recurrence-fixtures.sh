#!/usr/bin/env bash
# Refreshes the vendored recurrence parity corpus from the backend oracle.
# The backend jest spec (recurrence-parity-fixtures.spec.ts) is the source of truth;
# regenerate it there first, then run this to vendor the copy the iOS parity suite replays.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$here/../cue-api/docs/fixtures/recurrence-parity.json"
dst="$here/cueTests/Fixtures/recurrence-parity.json"
if [[ ! -f "$src" ]]; then
  echo "error: backend fixture not found at $src" >&2
  echo "run: (cd ../cue-api && GENERATE_FIXTURES=1 pnpm jest recurrence-parity-fixtures)" >&2
  exit 1
fi
cp "$src" "$dst"
echo "vendored $(wc -l < "$dst" | tr -d ' ') lines → $dst"

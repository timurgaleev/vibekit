#!/bin/bash
# Run all test_*.sh in this directory. Exit non-zero if any suite fails.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rc=0
for t in "$HERE"/test_*.sh; do
  [[ -e "$t" ]] || continue
  echo "== $(basename "$t") =="
  bash "$t" || rc=1
done

[[ "$rc" -eq 0 ]] && echo "ALL SUITES PASS" || echo "SOME SUITES FAILED"
exit "$rc"

#!/usr/bin/env bash
set -euo pipefail

# wait-for-pr.sh — Block until all PR checks complete.
#
# Usage: wait-for-pr.sh <PR_NUMBER> [MAX_ATTEMPTS] [INTERVAL_SECS]
#
# Polls `gh pr checks` in a tight shell loop so the calling agent
# pays zero tokens while waiting. Exits when no checks are
# pending/queued/in_progress, or on timeout.
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed (agent should inspect)
#   2 — timed out waiting

PR="${1:?Usage: wait-for-pr.sh <PR_NUMBER> [MAX_ATTEMPTS] [INTERVAL_SECS]}"
MAX="${2:-40}"       # 40 × 30s = 20 min default
INTERVAL="${3:-30}"

for i in $(seq 1 "$MAX"); do
  output=$(gh pr checks "$PR" 2>&1) || true
  pending=$(echo "$output" | grep -ciE "pending|queued|in_progress" || true)

  if [ "$pending" -eq 0 ]; then
    echo "--- All checks settled after $i poll(s) ---"
    echo "$output"
    failures=$(echo "$output" | grep -ci "fail" || true)
    if [ "$failures" -gt 0 ]; then
      echo "RESULT: ${failures} check(s) failed"
      exit 1
    else
      echo "RESULT: all checks passed"
      exit 0
    fi
  fi

  echo "Poll $i/$MAX: $pending check(s) still pending — sleeping ${INTERVAL}s..."
  sleep "$INTERVAL"
done

echo "--- Timed out after $MAX polls ($((MAX * INTERVAL))s) ---"
gh pr checks "$PR" 2>&1 || true
echo "RESULT: timeout"
exit 2

#!/usr/bin/env bash
# One-time GitHub login for agent-browser so the native-upload path can mint
# user-attachments URLs (screenshot / GIF / video). Opens a headed browser; you log in
# (passkey / 2FA / SSO) in it; the session is saved to a file and reused across runs
# until it expires. Re-run whenever the native path reports "not logged in".
#
# Passkey/SSO can't be scripted (WebAuthn is hardware-bound; Okta is interactive), so
# this is deliberately a one-time human step — not full automation.
set -euo pipefail

command -v agent-browser >/dev/null || {
  echo "agent-browser not on PATH — install it first (pnpm add -g agent-browser)." >&2
  exit 1
}

STATE="${PR_EVIDENCE_GH_STATE:-$HOME/.agent-browser/pr-evidence-github.state.json}"
SESSION="pr-evidence-github-login"
mkdir -p "$(dirname "$STATE")"

login_of() {
  agent-browser --session "$SESSION" eval \
    'document.querySelector("meta[name=\"user-login\"]") && document.querySelector("meta[name=\"user-login\"]").content' \
    2>/dev/null | tail -1 | tr -d '"'
}

echo "Opening a headed browser to github.com/login — finish the login there." >&2
agent-browser --session "$SESSION" --headed open "https://github.com/login" >/dev/null 2>&1 || true

login=""
for _ in $(seq 1 30); do            # ~5 min
  login="$(login_of)"
  [ -n "$login" ] && [ "$login" != "null" ] && break
  sleep 10
done

if [ -z "$login" ] || [ "$login" = "null" ]; then
  agent-browser --session "$SESSION" close >/dev/null 2>&1 || true
  echo "Still not logged in — re-run and finish the login in the window." >&2
  exit 1
fi

agent-browser --session "$SESSION" state save "$STATE" >/dev/null
agent-browser --session "$SESSION" close >/dev/null 2>&1 || true
echo "Saved GitHub session for '$login' → $STATE" >&2

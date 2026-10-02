#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Stamp PR
# @raycast.mode compact
# @raycast.packageName GitHub
# @raycast.icon 🪵

set -euo pipefail
# Raycast does not load the shell profile; gh comes from nix (or Homebrew on non-nix Macs).
export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"
# shellcheck disable=SC1091
source "$(dirname "$0")/_lib/pr-url.sh"
pr="$(normalize_pr_url "$(pbpaste)")"
gh pr review "$pr" --approve
echo "Stamped $pr"

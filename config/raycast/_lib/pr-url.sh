# shellcheck shell=bash
# Normalizes any PR-ish URL (github.com, Devin Review, bare owner/repo#N) to a github.com PR URL.
normalize_pr_url() {
  local input owner repo num
  input="$(printf '%s' "$1" | tr -d '[:space:]')"
  if [[ "$input" =~ ([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/pull/([0-9]+) ]]; then
    owner="${BASH_REMATCH[1]}"; repo="${BASH_REMATCH[2]}"; num="${BASH_REMATCH[3]}"
  elif [[ "$input" =~ ^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)#([0-9]+)$ ]]; then
    owner="${BASH_REMATCH[1]}"; repo="${BASH_REMATCH[2]}"; num="${BASH_REMATCH[3]}"
  else
    echo "Could not find owner/repo/pull/<number> in: $1" >&2
    return 1
  fi
  echo "https://github.com/$owner/$repo/pull/$num"
}

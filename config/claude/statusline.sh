#!/usr/bin/env bash
# Claude Code statusLine — robbyrussell-inspired with context usage bar

# $'...' syntax so bash interprets escapes at assignment time
CYAN=$'\033[0;36m'
BOLD_BLUE=$'\033[1;34m'
RED=$'\033[0;31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
DIM=$'\033[2m'
RESET=$'\033[0m'

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir_name=$(basename "$cwd")
model=$(echo "$input" | jq -r '.model.display_name // empty')

branch=""
if command -v git &>/dev/null && [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || true)
fi

# Context bar
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

ctx=""
if [ -n "$PCT" ]; then
  PCT_INT=$(printf '%.0f' "$PCT")
  BAR_WIDTH=10
  FILLED=$((PCT_INT * BAR_WIDTH / 100))
  EMPTY=$((BAR_WIDTH - FILLED))

  if [ "$PCT_INT" -ge 90 ]; then BAR_COLOR="$RED"
  elif [ "$PCT_INT" -ge 70 ]; then BAR_COLOR="$YELLOW"
  else BAR_COLOR="$GREEN"; fi

  printf -v FILL_S "%${FILLED}s" ""
  printf -v PAD_S "%${EMPTY}s" ""
  BAR="${FILL_S// /█}${PAD_S// /░}"

  ctx=" ${BAR_COLOR}${BAR}${RESET} ${PCT_INT}%"
fi

# Cost
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
cost_str=""
if [ -n "$COST" ]; then
  cost_str=" ${DIM}$(printf '$%.2f' "$COST")${RESET}"
fi

# Output
printf '%b' "${CYAN}${dir_name}${RESET}"
[ -n "$branch" ] && printf '%b' " ${BOLD_BLUE}git:(${RED}${branch}${BOLD_BLUE})${RESET}"
printf '%b' " ${DIM}${model}${RESET}"
[ -n "$ctx" ] && printf '%b' "$ctx"
[ -n "$cost_str" ] && printf '%b' "$cost_str"
printf '\n'

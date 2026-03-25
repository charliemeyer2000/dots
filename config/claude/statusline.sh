#!/usr/bin/env bash
# Claude Code statusLine — robbyrussell-inspired with context window usage
#
# Configuration via ~/.claude/statusline.conf:
#   autocompact=true   (default — 22.5% reserved for AC buffer)
#   autocompact=false  (when you disable autocompact via /config)
#   token_detail=true  (show exact tokens like 64,000 — default)
#   token_detail=false (show abbreviated like 64.0k)
#   show_delta=true    (show token delta like [+2,500] — default)
#   show_delta=false   (disable delta display)

CYAN='\033[0;36m'
BOLD_BLUE='\033[1;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir_name=$(basename "$cwd")
model_id=$(echo "$input" | jq -r '.model.id // empty')

# Git branch
branch=""
if command -v git &>/dev/null && [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || true)
fi

# Model shortname
if [[ "$model_id" =~ opus ]]; then
  model="Opus"
elif [[ "$model_id" =~ sonnet ]]; then
  model="Sonnet"
elif [[ "$model_id" =~ haiku ]]; then
  model="Haiku"
else
  model="Claude"
fi

# Read config
autocompact_enabled=true
token_detail_enabled=true
show_delta_enabled=true

if [[ ! -f ~/.claude/statusline.conf ]]; then
  mkdir -p ~/.claude
  cat > ~/.claude/statusline.conf << 'EOF'
autocompact=true
token_detail=true
show_delta=true
EOF
fi

if [[ -f ~/.claude/statusline.conf ]]; then
  # shellcheck source=/dev/null
  source ~/.claude/statusline.conf
  [[ "${autocompact:-}" == "false" ]] && autocompact_enabled=false
  [[ "${token_detail:-}" == "false" ]] && token_detail_enabled=false
  [[ "${show_delta:-}" == "false" ]] && show_delta_enabled=false
fi

# Context window calculation
context_info=""
ac_info=""
delta_info=""
total_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
current_usage=$(echo "$input" | jq '.context_window.current_usage')

if [[ "$total_size" -gt 0 && "$current_usage" != "null" ]]; then
  input_tokens=$(echo "$current_usage" | jq -r '.input_tokens // 0')
  cache_creation=$(echo "$current_usage" | jq -r '.cache_creation_input_tokens // 0')
  cache_read=$(echo "$current_usage" | jq -r '.cache_read_input_tokens // 0')

  used_tokens=$((input_tokens + cache_creation + cache_read))
  free_tokens=$((total_size - used_tokens))

  # Autocompact buffer info
  if [[ "$autocompact_enabled" == "true" ]]; then
    autocompact_buffer=$((total_size * 225 / 1000))
    buffer_k=$(awk "BEGIN {printf \"%.0f\", $autocompact_buffer / 1000}")
    ac_info=" ${DIM}[AC:${buffer_k}k]${RESET}"
  else
    ac_info=" ${DIM}[AC:off]${RESET}"
  fi

  [[ "$free_tokens" -lt 0 ]] && free_tokens=0

  free_pct=$(awk "BEGIN {printf \"%.1f\", ($free_tokens * 100.0 / $total_size)}")
  free_pct_int=${free_pct%.*}

  # Format token count
  if [[ "$token_detail_enabled" == "true" ]]; then
    free_display=$(awk -v n="$free_tokens" 'BEGIN { printf "%\047d", n }')
  else
    free_display=$(awk "BEGIN {printf \"%.1fk\", $free_tokens / 1000}")
  fi

  # Color by free percentage
  if [[ "$free_pct_int" -gt 50 ]]; then
    ctx_color="$GREEN"
  elif [[ "$free_pct_int" -gt 25 ]]; then
    ctx_color="$YELLOW"
  else
    ctx_color="$RED"
  fi

  context_info=" ${ctx_color}${free_display} free (${free_pct}%)${RESET}"

  # Token delta
  if [[ "$show_delta_enabled" == "true" ]]; then
    state_file=~/.claude/statusline.state
    has_prev=false
    prev_tokens=0
    if [[ -f "$state_file" ]]; then
      has_prev=true
      prev_tokens=$(tail -1 "$state_file" 2>/dev/null | cut -d',' -f2)
      prev_tokens=${prev_tokens:-0}
    fi
    delta=$((used_tokens - prev_tokens))
    if [[ "$has_prev" == "true" && "$delta" -gt 0 ]]; then
      if [[ "$token_detail_enabled" == "true" ]]; then
        delta_display=$(awk -v n="$delta" 'BEGIN { printf "%\047d", n }')
      else
        delta_display=$(awk "BEGIN {printf \"%.1fk\", $delta / 1000}")
      fi
      delta_info=" ${DIM}[+${delta_display}]${RESET}"
    fi
    echo "$(date +%s),$used_tokens" >> "$state_file"
  fi
fi

# Output: dir git:(branch) | [Model] XXk free (XX%) [+delta] [AC]
printf "${CYAN}%s${RESET}" "$dir_name"

if [ -n "$branch" ]; then
  printf " ${BOLD_BLUE}git:(${RED}%s${BOLD_BLUE})${RESET}" "$branch"
fi

printf " ${DIM}[%s]${RESET}" "$model"

if [ -n "$context_info" ]; then
  printf " |%s%s%s" "$context_info" "$delta_info" "$ac_info"
fi

printf '\n'

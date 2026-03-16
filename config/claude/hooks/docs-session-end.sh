#!/usr/bin/env bash
# SessionEnd hook — spawns a background claude -p to review session changes
# and update documentation if warranted. Sync part runs <1s, heavy work is detached.

set -euo pipefail

# Prevent infinite loop: background claude -p triggers its own SessionEnd
LOCKFILE="/tmp/claude-docs-hook.lock"
if [ -f "$LOCKFILE" ]; then
  # Stale lock check: remove if older than 10 minutes
  if [[ "$(uname)" == "Darwin" ]]; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCKFILE") ))
  else
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCKFILE") ))
  fi
  [ "$lock_age" -lt 600 ] && exit 0
  rm -f "$LOCKFILE"
fi

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path')
CWD=$(echo "$INPUT" | jq -r '.cwd')

cd "$CWD" || exit 0

command -v claude &>/dev/null || exit 0
command -v jq &>/dev/null || exit 0
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$GIT_ROOT"

# Transcript creation time = session start
if [[ "$(uname)" == "Darwin" ]]; then
  SESSION_START=$(stat -f %B "$TRANSCRIPT" 2>/dev/null || echo "0")
else
  SESSION_START=$(stat -c %W "$TRANSCRIPT" 2>/dev/null || stat -c %Y "$TRANSCRIPT" 2>/dev/null || echo "0")
fi

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
SESSION_COMMITS=$(git log --after="@$SESSION_START" --format="%h %s" 2>/dev/null || echo "")
UNSTAGED_STAT=$(git diff --stat 2>/dev/null || echo "")
STAGED_STAT=$(git diff --cached --stat 2>/dev/null || echo "")
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | head -20 || echo "")
UNPUSHED=$(git log '@{upstream}..HEAD' --oneline 2>/dev/null || echo "")

if [ -n "$SESSION_COMMITS" ]; then
  FIRST_COMMIT=$(git log --after="@$SESSION_START" --format="%H" --reverse 2>/dev/null | head -1)
  if [ -n "$FIRST_COMMIT" ]; then
    SESSION_DIFF_STAT=$(git diff "${FIRST_COMMIT}^"..HEAD --stat 2>/dev/null || echo "")
    SESSION_DIFF=$(git diff "${FIRST_COMMIT}^"..HEAD 2>/dev/null | head -500 || echo "")
  else
    SESSION_DIFF_STAT=""
    SESSION_DIFF=""
  fi
  WIP_DIFF=$(git diff --stat 2>/dev/null || echo "")
  WIP_DIFF_FULL=$(git diff 2>/dev/null | head -200 || echo "")
  if [ -n "$WIP_DIFF" ]; then
    SESSION_DIFF_STAT="${SESSION_DIFF_STAT}
--- uncommitted ---
${WIP_DIFF}"
    SESSION_DIFF="${SESSION_DIFF}
--- uncommitted ---
${WIP_DIFF_FULL}"
  fi
else
  SESSION_DIFF_STAT="${UNSTAGED_STAT}${STAGED_STAT}"
  SESSION_DIFF=$(git diff 2>/dev/null | head -500 || echo "")
  STAGED_DIFF=$(git diff --cached 2>/dev/null | head -200 || echo "")
  if [ -n "$STAGED_DIFF" ]; then
    SESSION_DIFF="${SESSION_DIFF}
--- staged ---
${STAGED_DIFF}"
  fi
fi

TOTAL_CHANGES="${SESSION_COMMITS}${UNSTAGED_STAT}${STAGED_STAT}"
if [ -z "$TOTAL_CHANGES" ]; then
  exit 0
fi

DIFF_LINE_COUNT=$(echo "$SESSION_DIFF" | wc -l | tr -d ' ')
if [ "$DIFF_LINE_COUNT" -lt 10 ]; then
  exit 0
fi

DOC_FILES=$(find . -maxdepth 4 \( \
  -name "README.md" -o \
  -name "AGENTS.md" -o \
  -name "CLAUDE.md" -o \
  -name "MEMORY.md" -o \
  -name "CHANGELOG.md" -o \
  -name "CONTRIBUTING.md" \
\) -not -path "./.git/*" -not -path "*/node_modules/*" -not -path "*/skills/*" 2>/dev/null | sort)

DOCS_DIR_FILES=$(find . -maxdepth 3 -path "*/docs/*.md" -not -path "./.git/*" -not -path "*/node_modules/*" 2>/dev/null | head -20 || echo "")

ALL_DOCS="${DOC_FILES}"
if [ -n "$DOCS_DIR_FILES" ]; then
  ALL_DOCS="${ALL_DOCS}
${DOCS_DIR_FILES}"
fi

if [ -z "$ALL_DOCS" ]; then
  exit 0
fi

PROJECT_INSTRUCTIONS="No project-specific instructions. Use your best judgment."
if [ -f ".claude/docs-update.json" ]; then
  PROJECT_INSTRUCTIONS=$(jq -r '.instructions // "No project-specific instructions."' .claude/docs-update.json)
fi

SESSION_TYPE="unknown"
COMMIT_COUNT=$(echo "$SESSION_COMMITS" | grep -c . 2>/dev/null || echo "0")

if [ "$COMMIT_COUNT" -eq 0 ] && [ -z "$UNSTAGED_STAT" ] && [ -z "$STAGED_STAT" ]; then
  exit 0 # chat only
elif [ "$COMMIT_COUNT" -eq 0 ]; then
  SESSION_TYPE="uncommitted work (changes left in working tree)"
elif [ "$COMMIT_COUNT" -eq 1 ] && [ -z "$UNPUSHED" ]; then
  SESSION_TYPE="single commit, already pushed"
elif [ "$COMMIT_COUNT" -eq 1 ] && [ -n "$UNPUSHED" ]; then
  SESSION_TYPE="single commit, not yet pushed"
elif [ "$COMMIT_COUNT" -gt 1 ] && [ -z "$UNPUSHED" ]; then
  SESSION_TYPE="multiple commits ($COMMIT_COUNT), all pushed"
elif [ "$COMMIT_COUNT" -gt 1 ] && [ -n "$UNPUSHED" ]; then
  SESSION_TYPE="multiple commits ($COMMIT_COUNT), some unpushed"
fi

PR_INFO=""
if command -v gh &>/dev/null; then
  PR_INFO=$(gh pr list --author @me --state all --limit 3 --json number,title,state,createdAt 2>/dev/null | jq -r '.[] | "\(.state): #\(.number) \(.title)"' 2>/dev/null || echo "")
fi

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/docs-update-$(date +%Y%m%d-%H%M%S).log"

PROMPT_FILE=$(mktemp /tmp/claude-docs-prompt.XXXXXX)
cat > "$PROMPT_FILE" << PROMPT_EOF
You are a documentation maintenance agent. A coding session just ended and you need to determine if any documentation files need updating based on what changed.

## CRITICAL RULES
- Do NOT make changes unless the code changes genuinely require it
- Do NOT touch documentation for: typo fixes, formatting, dependency bumps, minor refactors, internal-only changes
- DO update documentation for: new features, changed APIs/commands, architectural changes, new modules/files users need to know about, changed workflows, removed functionality
- If the changes don't affect anything documented, do NOTHING
- When you do update, make MINIMAL targeted edits — match the existing style and voice exactly
- Do NOT reorganize, expand, rewrite, or "improve" documentation beyond what the changes require
- Do NOT add new sections unless a genuinely new concept was introduced
- False negatives (missing a needed update) are far better than false positives (unnecessary edits)
- NEVER update CLAUDE.md if it is a symlink — update the target file instead

## SESSION SUMMARY
Session type: ${SESSION_TYPE}
Branch: ${CURRENT_BRANCH}

### Commits this session
${SESSION_COMMITS:-"(none — changes are uncommitted)"}

### Push state
${UNPUSHED:-"(everything pushed or no upstream tracking)"}

### Current working tree
Staged: ${STAGED_STAT:-"(clean)"}
Unstaged: ${UNSTAGED_STAT:-"(clean)"}
Untracked: ${UNTRACKED:-"(none)"}

### Recent PRs
${PR_INFO:-"(none detected)"}

### Files changed (stat)
${SESSION_DIFF_STAT:-"(no changes)"}

### Diff content (may be truncated)
${SESSION_DIFF:-"(no diff)"}

## DOCUMENTATION FILES FOUND
${ALL_DOCS}

## PROJECT-SPECIFIC INSTRUCTIONS
${PROJECT_INSTRUCTIONS}

## YOUR TASK
1. Read the documentation files listed above
2. Compare their content against the session's changes
3. Determine if any documented information is now stale, incomplete, or missing
4. If YES: make minimal, surgical edits to ONLY the affected sections
5. If NO: output a brief explanation of why no updates are needed, then stop

Think carefully before making any changes. Most sessions will NOT require documentation updates.
PROMPT_EOF

notify() {
  local title="$1"
  local subtitle="$2"
  local message="$3"

  if [[ "$(uname)" == "Darwin" ]]; then
    osascript -e "display notification \"${message}\" with title \"${title}\" subtitle \"${subtitle}\"" 2>/dev/null
  elif command -v notify-send &>/dev/null; then
    notify-send "${title}: ${subtitle}" "${message}" 2>/dev/null
  fi
}

touch "$LOCKFILE"

(
  cd "$GIT_ROOT"
  nohup claude -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions > "$LOG_FILE" 2>&1
  rm -f "$PROMPT_FILE" "$LOCKFILE"

  CHANGED_DOCS=$(git diff --name-only 2>/dev/null | grep -E '\.(md|txt)$' || echo "")
  REPO_NAME=$(basename "$GIT_ROOT")

  if [ -n "$CHANGED_DOCS" ]; then
    FILE_LIST=$(echo "$CHANGED_DOCS" | tr '\n' ', ' | sed 's/,$//')
    notify "Docs updated" "$REPO_NAME" "Updated: ${FILE_LIST}"
  else
    notify "Docs check complete" "$REPO_NAME" "No documentation changes needed."
  fi
) &
disown

exit 0

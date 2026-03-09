# dots task runner

default:
  just --list

# format all nix files
fmt:
  nix fmt

# run all flake checks
check:
  nix flake check

# rebuild current machine
switch:
  nix flake check && sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .#darwin-personal

# rebuild and show diff
switch-dry:
  /run/current-system/sw/bin/darwin-rebuild build --flake .#darwin-personal

# enter dev shell
dev:
  nix develop

# enter ROS2 dev shell
ros2:
  nix develop .#ros2

# === Skill Management ===

# add a skill (e.g., just skill-add cursor/plugins deslop)
skill-add owner_repo skill_name:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "📦 Fetching {{skill_name}} from {{owner_repo}}..."

  # Create temp dir
  TEMP_DIR=$(mktemp -d)
  trap "rm -rf $TEMP_DIR" EXIT

  # Clone the repo and find the skill
  git clone --depth 1 --quiet "https://github.com/{{owner_repo}}.git" "$TEMP_DIR/repo" 2>/dev/null || {
    echo "❌ Failed to clone repository {{owner_repo}}"
    exit 1
  }

  # Look for skill in various locations (including nested directories)
  SKILL_PATH=""
  SKILL_PATH=$(find "$TEMP_DIR/repo" -type d -name "{{skill_name}}" | while read dir; do
    if [ -f "$dir/SKILL.md" ]; then
      echo "$dir"
      break
    fi
  done)

  # If not found, try direct paths as fallback
  if [ -z "$SKILL_PATH" ]; then
    for path in \
      "$TEMP_DIR/repo/skills/{{skill_name}}" \
      "$TEMP_DIR/repo/{{skill_name}}"; do
      if [ -f "$path/SKILL.md" ]; then
        SKILL_PATH="$path"
        break
      fi
    done
  fi

  if [ -z "$SKILL_PATH" ]; then
    echo "❌ Skill '{{skill_name}}' not found in {{owner_repo}}"
    echo "Try 'just skill-search {{owner_repo}}' to list available skills"
    exit 1
  fi

  # Create skill directory in nix config
  SKILL_DIR="config/claude/skills/{{skill_name}}"
  mkdir -p "$SKILL_DIR"

  # Copy all skill files
  cp -r "$SKILL_PATH"/* "$SKILL_DIR/"

  echo "✅ Added {{skill_name}} to nix config"
  echo "Run 'just switch' to activate"

# search for skills in a repo
skill-search owner_repo:
  @echo "🔍 Searching for skills in {{owner_repo}}..."
  @git clone --depth 1 --quiet "https://github.com/{{owner_repo}}.git" /tmp/skill-search 2>/dev/null && \
    find /tmp/skill-search -name "SKILL.md" -type f 2>/dev/null | \
    sed 's|.*/\([^/]*/\)SKILL.md|\1|' | sed 's|/$||' | sort -u | \
    sed 's/^/  - /' && \
    rm -rf /tmp/skill-search || echo "❌ Failed to search {{owner_repo}}"

# list installed skills
skill-list:
  @echo "📚 Installed skills:"
  @ls -1 config/claude/skills/ 2>/dev/null | sed 's/^/  - /' || echo "  No skills installed"

# remove a skill
skill-remove skill_name:
  #!/usr/bin/env bash
  if [ -d "config/claude/skills/{{skill_name}}" ]; then
    rm -rf "config/claude/skills/{{skill_name}}"
    echo "🗑️  Removed {{skill_name}}"
    echo "Run 'just switch' to apply changes"
  else
    echo "❌ Skill {{skill_name}} not found"
    exit 1
  fi

# browse skills online
skill-browse:
  open "https://skills.sh"

# install a skill and rebuild immediately
skill-install owner_repo skill_name: (skill-add owner_repo skill_name) switch
  @echo "✨ {{skill_name}} installed and activated!"

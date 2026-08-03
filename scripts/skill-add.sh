#!/usr/bin/env bash
set -euo pipefail

owner_repo=$1
skill_name=$2

TEMP_DIR=$(mktemp -d)
trap 'rm -rf $TEMP_DIR' EXIT

git clone --depth 1 --quiet "https://github.com/${owner_repo}.git" "$TEMP_DIR/repo" 2>/dev/null || {
    echo "Failed to clone repository ${owner_repo}"
    exit 1
}

# Read the canonical `name:` from a SKILL.md's YAML frontmatter (strips quotes).
skill_md_name() {
    sed -n 's/^name:[[:space:]]*//p' "$1" | head -1 | tr -d '\042\047'
}

# Resolve the skill by its canonical frontmatter name (what skills.sh shows),
# falling back to the on-disk folder name. These differ in some repos — e.g.
# vercel-labs/agent-skills: folder `react-best-practices`, name `vercel-react-best-practices`.
SKILL_PATH=""
while IFS= read -r md; do
    dir=$(dirname "$md")
    if [ "$(skill_md_name "$md")" = "$skill_name" ] || [ "$(basename "$dir")" = "$skill_name" ]; then
        SKILL_PATH="$dir"
        break
    fi
done < <(find "$TEMP_DIR/repo" -name "SKILL.md" -type f)

if [ -z "$SKILL_PATH" ]; then
    echo "Skill '${skill_name}' not found in ${owner_repo}"
    echo "Try 'just skill-search ${owner_repo}' to list available skills"
    exit 1
fi

# Install under the canonical name so the folder matches what the agent registers
# and what skills.sh lists (keeps skill-list / skill-remove consistent).
canonical=$(skill_md_name "$SKILL_PATH/SKILL.md")
canonical=${canonical:-$skill_name}

SKILL_DIR="config/agents/skills/${canonical}"
mkdir -p "$SKILL_DIR"
# Copy dot-prefixed entries too — a plain `/*` glob skips them, which silently
# dropped files skills ship and reference (e.g. upstream `.claude-plugin/`).
# Excluded at copy time rather than deleted afterwards, so an interrupted run
# can't leave a nested clone inside this repo:
#   .git/.github          a skill living at its repo root drags its own clone along
#   .gitignore/.gitattributes  upstream's rules would start governing this repo,
#                              and an ignore file can quietly keep vendored files
#                              out of version control
tar -cf - -C "$SKILL_PATH" \
    --exclude='./.git' \
    --exclude='./.github' \
    --exclude='./.gitignore' \
    --exclude='./.gitattributes' \
    . | tar -xf - -C "$SKILL_DIR"

echo "Added ${canonical} to nix config"
echo "Run 'just switch <config>' to activate (e.g., just switch darwin-personal)"

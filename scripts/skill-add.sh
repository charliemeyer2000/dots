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

SKILL_PATH=$(find "$TEMP_DIR/repo" -type d -name "${skill_name}" | while read -r dir; do
    if [ -f "$dir/SKILL.md" ]; then
        echo "$dir"
        break
    fi
done)

if [ -z "$SKILL_PATH" ]; then
    for path in \
        "$TEMP_DIR/repo/skills/${skill_name}" \
        "$TEMP_DIR/repo/${skill_name}"; do
        if [ -f "$path/SKILL.md" ]; then
            SKILL_PATH="$path"
            break
        fi
    done
fi

if [ -z "$SKILL_PATH" ]; then
    echo "Skill '${skill_name}' not found in ${owner_repo}"
    echo "Try 'just skill-search ${owner_repo}' to list available skills"
    exit 1
fi

SKILL_DIR="config/claude/skills/${skill_name}"
mkdir -p "$SKILL_DIR"
cp -r "$SKILL_PATH"/* "$SKILL_DIR/"

echo "Added ${skill_name} to nix config"
echo "Run 'just switch' to activate"
#!/usr/bin/env bash
set -euo pipefail

owner_repo=$1

TEMP_DIR=$(mktemp -d)
trap 'rm -rf $TEMP_DIR' EXIT

git clone --depth 1 --quiet "https://github.com/${owner_repo}.git" "$TEMP_DIR/repo" 2>/dev/null || {
    echo "Failed to search ${owner_repo}"
    exit 1
}

# List skills by their canonical frontmatter `name:` (what skills.sh shows and
# what `skill-add` expects), falling back to the folder name when unset.
find "$TEMP_DIR/repo" -name "SKILL.md" -type f 2>/dev/null | while IFS= read -r md; do
    name=$(sed -n 's/^name:[[:space:]]*//p' "$md" | head -1 | tr -d '\042\047')
    echo "${name:-$(basename "$(dirname "$md")")}"
done | sort -u | sed 's/^/  - /'
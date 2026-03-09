#!/usr/bin/env bash
set -euo pipefail

owner_repo=$1

TEMP_DIR=$(mktemp -d)
trap 'rm -rf $TEMP_DIR' EXIT

git clone --depth 1 --quiet "https://github.com/${owner_repo}.git" "$TEMP_DIR/repo" 2>/dev/null || {
    echo "Failed to search ${owner_repo}"
    exit 1
}

find "$TEMP_DIR/repo" -name "SKILL.md" -type f 2>/dev/null | \
    sed 's|.*/\([^/]*/\)SKILL.md|\1|' | sed 's|/$||' | sort -u | \
    sed 's/^/  - /'
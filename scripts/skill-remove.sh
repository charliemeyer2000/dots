#!/usr/bin/env bash
set -euo pipefail

skill_name=$1

if [ -d "config/claude/skills/${skill_name}" ]; then
    rm -rf "config/claude/skills/${skill_name}"
    echo "Removed ${skill_name}"
    echo "Run 'just switch' to apply changes"
else
    echo "Skill ${skill_name} not found"
    exit 1
fi
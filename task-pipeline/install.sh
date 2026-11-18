#!/usr/bin/env bash
# Installs the /rewrite, /prepare, /instruct, /start and /orchestrate skills
# into your personal skills folder (~/.claude/skills). Re-run after changing
# anything in skills/ or lib/. A folder this script didn't create is never
# replaced.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
mark=".installed-by-task-pipeline"

mkdir -p "$dest"
for dir in "$here"/skills/*/; do
  name="$(basename "$dir")"
  target="$dest/$name"
  if [ -e "$target" ] && [ ! -e "$target/$mark" ]; then
    echo "skipped /$name: $target already exists and wasn't installed by this script" >&2
    continue
  fi
  rm -rf "$target"
  mkdir -p "$target/scripts"
  cp "$dir/SKILL.md" "$target/SKILL.md"
  # -L copies what a link points to, such as the shared lib/task.sh.
  for file in "${dir%/}"/scripts/*; do
    [ -e "$file" ] || continue
    cp -L "$file" "$target/scripts/"
    chmod +x "$target/scripts/$(basename "$file")"
  done
  touch "$target/$mark"
  echo "installed /$name -> $target"
done

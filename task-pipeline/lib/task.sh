#!/usr/bin/env bash
# Shared helper for the /rewrite, /prepare, /instruct and /start skills.
#
# Usage: task.sh <project-dir> [file ...]
#
# Prints where the task files are, then the contents of each requested file
# from the current task folder. The skills run it through !`...` injection,
# where a failing command aborts the skill, so it always exits 0.
#
# Each task has a folder <project>/.tasks/<YYYYMMDD-HHMMSS>-<slug>/
# holding spec.md, brief.md and instructions.md. The newest folder is the
# current task unless the first line of its spec.md is "Status: done"
# (or "Status: abandoned"). The folder isn't under .claude/ because Claude
# Code treats everything there as sensitive and asks before every write.

project="${1:-}"
[ -n "$project" ] || project="$PWD"
[ "$#" -gt 0 ] && shift
tasks="$project/.tasks"

# Keep task files out of git without editing the repository's .gitignore.
if git -C "$project" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exclude="$(git -C "$project" rev-parse --git-path info/exclude 2>/dev/null)"
  case "$exclude" in
    /*) ;;
    ?*) exclude="$project/$exclude" ;;
  esac
  if [ -n "$exclude" ] && ! grep -qxF '**/.tasks/' "$exclude" 2>/dev/null; then
    mkdir -p "$(dirname "$exclude")" 2>/dev/null &&
      printf '%s\n' '**/.tasks/' >>"$exclude" 2>/dev/null
  fi
fi

current=""
finished=""
newest=1
if [ -d "$tasks" ]; then
  # Folder names start with a timestamp and a glob lists them in name order,
  # so walking the list backwards visits the newest task first.
  dirs=("$tasks"/*/)
  i=${#dirs[@]}
  while [ "$i" -gt 0 ]; do
    i=$((i - 1))
    dir="${dirs[$i]%/}"
    name="${dir##*/}"
    spec="$tasks/$name/spec.md"
    [ -f "$spec" ] || continue
    if head -n 1 "$spec" | grep -qiE '^status:[[:space:]]*(done|abandoned)'; then
      finished="$name"
      break
    fi
    [ "$newest" = 1 ] && current="$name"
    newest=0
  done
fi

# Command names depend on how the skills were installed. install.sh leaves a
# marker file in each skill folder, and the commands are /prepare and so on.
# As a plugin, they're /<plugin name>:prepare.
skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
if [ -e "$skill_dir/.installed-by-task-pipeline" ]; then
  prefix="/"
else
  plugin="$(sed -n 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$skill_dir/../../.claude-plugin/plugin.json" 2>/dev/null | head -n 1)"
  prefix="/${plugin:-task}:"
fi

echo "Folder for a new task: $tasks/$(date +%Y%m%d-%H%M%S)-<slug>/"
if [ -n "$current" ]; then
  echo "Current task: $tasks/$current/"
  printf 'Files written so far:'
  for f in spec.md brief.md instructions.md; do
    [ -f "$tasks/$current/$f" ] && printf ' %s' "$f"
  done
  echo
else
  echo "Current task: none"
fi
[ -n "$finished" ] && echo "Last finished task: $tasks/$finished/"
echo "Commands: <rewrite command> is ${prefix}rewrite, <prepare command> is ${prefix}prepare, <instruct command> is ${prefix}instruct, <start command> is ${prefix}start"

if [ -n "$current" ]; then
  for f in "$@"; do
    if [ -f "$tasks/$current/$f" ]; then
      printf '\n----- %s -----\n' "$f"
      cat "$tasks/$current/$f"
    fi
  done
fi
exit 0

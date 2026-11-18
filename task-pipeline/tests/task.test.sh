#!/usr/bin/env bash
# Tests for lib/task.sh. Run from anywhere: bash task-pipeline/tests/task.test.sh
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

# pass_if NAME COMMAND...: runs COMMAND and reports NAME as ok or FAIL.
pass_if() {
  name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    failures=$((failures + 1))
  fi
}

# has TEXT PATTERN: TEXT contains PATTERN as a fixed string.
has() { printf '%s\n' "$1" | grep -qF -- "$2"; }
lacks() { ! has "$1" "$2"; }

run() { bash "$root/lib/task.sh" "$@"; }

# A project path with a space in it, to catch quoting bugs.
project="$work/my project"
tasks="$project/.tasks"
mkdir -p "$project"
git -C "$project" init -q

out="$(run "$project" spec.md)"
pass_if "no tasks: no current task" has "$out" "Current task: none"
pass_if "no tasks: new task folder is under .tasks" has "$out" "Folder for a new task: $tasks/"

run "$project" >/dev/null
pass_if "git exclude line is written once" [ "$(grep -cxF '**/.tasks/' "$project/.git/info/exclude")" = 1 ]
pass_if "git ignores task files" git -C "$project" check-ignore -q .tasks/x

mkdir -p "$tasks/20260101-000000-old" "$tasks/20260102-000000-phase-0"
printf 'Status: done\n' >"$tasks/20260101-000000-old/spec.md"
printf 'Status: open\n\n## Spec\nstatus: done\n' >"$tasks/20260102-000000-phase-0/spec.md"
printf '# Brief\n' >"$tasks/20260102-000000-phase-0/brief.md"
out="$(run "$project" spec.md instructions.md)"
pass_if "newest open task is current" has "$out" "Current task: $tasks/20260102-000000-phase-0/"
pass_if "only the first line of spec.md sets the status" lacks "$out" "Current task: none"
pass_if "lists the files written so far" has "$out" "Files written so far: spec.md brief.md"
pass_if "shows the last finished task" has "$out" "Last finished task: $tasks/20260101-000000-old/"
pass_if "prints a requested file" has "$out" "----- spec.md -----"
pass_if "skips a requested file not written yet" lacks "$out" "----- instructions.md -----"

mkdir -p "$tasks/20260103-000000-dropped"
printf 'Status: abandoned\n' >"$tasks/20260103-000000-dropped/spec.md"
out="$(run "$project")"
pass_if "newest task abandoned: no current task" has "$out" "Current task: none"
pass_if "abandoned task counts as finished" has "$out" "Last finished task: $tasks/20260103-000000-dropped/"

out="$(cd "$project" && run "")"
pass_if "empty project argument uses the current folder" has "$out" "Folder for a new task: $tasks/"

plain="$work/not a repo"
mkdir -p "$plain"
pass_if "works outside git" run "$plain"
pass_if "doesn't create a git repo" [ ! -e "$plain/.git" ]
pass_if "exits 0 when the project folder is missing" run "$work/missing"

out="$(bash "$root/skills/prepare/scripts/task.sh" "$project")"
pass_if "plugin layout: commands have the plugin prefix" \
  has "$out" "Commands: /task:rewrite, /task:prepare, /task:instruct, /task:start"

personal="$work/skills/prepare"
mkdir -p "$personal/scripts"
cp "$root/lib/task.sh" "$personal/scripts/task.sh"
touch "$personal/.installed-by-task-pipeline"
out="$(bash "$personal/scripts/task.sh" "$project")"
pass_if "install.sh layout: commands have no prefix" \
  has "$out" "Commands: /rewrite, /prepare, /instruct, /start"

if [ "$failures" -eq 0 ]; then
  echo "all tests passed"
else
  echo "$failures test(s) failed"
  exit 1
fi

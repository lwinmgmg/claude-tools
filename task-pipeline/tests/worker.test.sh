#!/usr/bin/env bash
# Tests for skills/orchestrate/scripts/worker.sh. A fake `claude` stands in for
# the real one, so nothing here calls a model.
# Run from anywhere: bash task-pipeline/tests/worker.test.sh
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
worker="$root/skills/orchestrate/scripts/worker.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

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
fails() { ! "$@"; }

# feed INPUT ARGS...: runs worker.sh ARGS with INPUT on stdin.
feed() {
  local input="$1"
  shift
  printf '%s\n' "$input" | bash "$worker" "$@"
}

# The fake claude reports the arguments, model settings and folder it got.
mkdir -p "$work/bin"
cat >"$work/bin/claude" <<'FAKE'
#!/usr/bin/env bash
python3 -I - "$@" <<'PY'
import json, os, sys
env = os.environ
reply = "args: %s\nhaiku=%s sonnet=%s opus=%s effort=%s\ncwd=%s" % (
    " | ".join(sys.argv[1:]),
    env.get("ANTHROPIC_DEFAULT_HAIKU_MODEL", ""),
    env.get("ANTHROPIC_DEFAULT_SONNET_MODEL", ""),
    env.get("ANTHROPIC_DEFAULT_OPUS_MODEL", ""),
    env.get("CLAUDE_CODE_EFFORT_LEVEL", ""),
    os.getcwd(),
)
print(json.dumps([
    {"type": "system", "subtype": "init"},
    {"type": "result", "subtype": "success", "is_error": False,
     "total_cost_usd": 0.0123, "permission_denials": [],
     "modelUsage": {env.get("ANTHROPIC_DEFAULT_SONNET_MODEL", "?"): {}},
     "result": reply},
]))
PY
FAKE
chmod +x "$work/bin/claude"
export PATH="$work/bin:$PATH"

# status
plain="$work/not a repo"
mkdir -p "$plain"
out="$(bash "$worker" status "$plain")"
pass_if "status outside git says so" has "$out" "Not a git repository"
pass_if "status outside git exits 0" bash "$worker" status "$plain"

# A project path with a space in it, to catch quoting bugs.
project="$work/my project"
mkdir -p "$project"
git -C "$project" init -q -b master
git -C "$project" commit -q --allow-empty -m "Initial commit"
real="$(cd "$project" && pwd -P)"

out="$(bash "$worker" status "$project")"
pass_if "status shows the project" has "$out" "Project: $real"
pass_if "status shows the branch" has "$out" "Current branch: master"
pass_if "status shows a clean tree" has "$out" "Uncommitted changes: none"
pass_if "status shows no worktrees" has "$out" "  none"
pass_if "status shows plugin command names" \
  has "$out" "<prepare command> is /task:prepare"

touch "$project/draft.txt"
out="$(bash "$worker" status "$project")"
pass_if "status counts uncommitted changes" has "$out" "Uncommitted changes: 1"
rm "$project/draft.txt"

# new
wt="$(bash "$worker" new "$project" a-test)"
pass_if "new prints the worktree path" [ "$wt" = "$real/.claude/worktrees/a-test" ]
pass_if "new creates the worktree" [ -d "$wt" ]
pass_if "new creates the branch" git -C "$project" show-ref --verify --quiet refs/heads/a-test
pass_if "new keeps worktrees out of git status" [ -z "$(git -C "$project" status --porcelain)" ]
exclude="$project/.git/info/exclude"
pass_if "new writes each exclude line once" \
  [ "$(grep -cxF -e '**/.tasks/' -e '.claude/worktrees/' "$exclude")" = 2 ]
pass_if "new refuses an existing name" fails bash "$worker" new "$project" a-test
pass_if "new refuses a bad name" fails bash "$worker" new "$project" "Bad Name"

out="$(bash "$worker" status "$project")"
pass_if "status lists worker worktrees" has "$out" ".claude/worktrees/a-test (branch a-test)"

# run
out="$(feed "/task:prepare it's a test" run "$wt" sonnet high)"
pass_if "run points every alias at the chosen model" \
  has "$out" "haiku=claude-sonnet-5-5 sonnet=claude-sonnet-5-5 opus=claude-sonnet-5-5"
pass_if "run sets the effort" has "$out" "effort=high"
pass_if "run uses auto permissions" has "$out" "--permission-mode | auto"
pass_if "run passes the prompt from stdin" has "$out" "-p | /task:prepare it's a test"
pass_if "run works in the worktree" has "$out" "cwd=$wt"
pass_if "run summarizes model and cost" \
  has "$out" "Finished. Model: claude-sonnet-5-5, effort high. Cost: \$0.0123."
pass_if "run keeps the full output" ls "$wt"/.tasks/.runs/*-sonnet-high.json
out="$(feed /task:start run "$wt" claude-opus-5-5 max)"
pass_if "run accepts full model IDs" has "$out" "opus=claude-opus-5-5"
pass_if "run refuses a bad effort" fails feed hi run "$wt" sonnet huge
pass_if "run refuses a bad model" fails feed hi run "$wt" gpt high
pass_if "run refuses an empty prompt" fails feed "" run "$wt" sonnet high

ledger="$project/.tasks/runs.tsv"
pass_if "run records each run in the main checkout" [ "$(wc -l <"$ledger" | tr -d ' ')" = 2 ]
pass_if "run records the piece, command, model, effort and cost" \
  grep -qF "$(printf 'a-test\t/task:prepare\tsonnet\thigh\t0.0123\tfinished')" "$ledger"
pass_if "the run records stay out of git status" [ -z "$(git -C "$project" status --porcelain)" ]
out="$(bash "$worker" costs "$project" a-test)"
pass_if "costs totals a piece's runs" has "$out" "2 runs, total \$0.0246"
out="$(bash "$worker" costs "$project" nobody)"
pass_if "costs filters by piece" has "$out" "0 runs, total \$0.0000"

# finish
echo hello >"$wt/hello.txt"
git -C "$wt" add hello.txt
git -C "$wt" commit -q -m "Add hello"
pass_if "finish refuses commits that haven't landed" fails bash "$worker" finish "$project" a-test
pass_if "finish leaves an unlanded worktree alone" [ -d "$wt" ]

git -C "$project" merge -q --ff-only a-test
mkdir -p "$wt/.tasks/20260101-000000-done-task" "$wt/.tasks/20260102-000000-open-task"
printf 'Status: done\n' >"$wt/.tasks/20260101-000000-done-task/spec.md"
printf 'Status: open\n' >"$wt/.tasks/20260102-000000-open-task/spec.md"
pass_if "finish succeeds after landing" bash "$worker" finish "$project" a-test
pass_if "finish keeps finished task records" [ -f "$project/.tasks/20260101-000000-done-task/spec.md" ]
pass_if "finish skips open tasks" [ ! -e "$project/.tasks/20260102-000000-open-task" ]
pass_if "finish removes the worktree" [ ! -e "$wt" ]
pass_if "finish deletes the branch" fails git -C "$project" show-ref --verify --quiet refs/heads/a-test
out="$(bash "$worker" costs "$project")"
pass_if "costs survive removing the worktree" has "$out" "2 runs, total \$0.0246"

wt="$(bash "$worker" new "$project" c-test)"
touch "$wt/build-output.pyc"
out="$(bash "$worker" finish "$project" c-test 2>&1)"
pass_if "finish refuses untracked files" [ -d "$wt" ]
pass_if "finish names the files in the way" has "$out" "build-output.pyc"
rm "$wt/build-output.pyc"
pass_if "finish works once they're gone" bash "$worker" finish "$project" c-test

wt="$(bash "$worker" new "$project" b-test)"
echo bye >"$wt/bye.txt"
git -C "$wt" add bye.txt
git -C "$wt" commit -q -m "Add bye"
touch "$project/unrelated.txt"
git -C "$project" add unrelated.txt
git -C "$project" commit -q -m "Unrelated change"
git -C "$project" cherry-pick b-test >/dev/null
pass_if "finish counts cherry-picked commits as landed" bash "$worker" finish "$project" b-test

if [ "$failures" -eq 0 ]; then
  echo "all tests passed"
else
  echo "$failures test(s) failed"
  exit 1
fi

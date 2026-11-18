#!/usr/bin/env bash
# Helper for /orchestrate. Each piece of work gets its own git worktree, and
# each step runs there as a headless `claude -p` session.
#
#   worker.sh status <project>
#       What the orchestrator starts from: the repository, its branch,
#       uncommitted changes, existing worker worktrees and the command names.
#       Always exits 0, because it runs while the skill loads.
#
#   worker.sh new <project> <name>
#       Creates <project>/.claude/worktrees/<name> on a new branch <name>,
#       starting from the current commit, and prints its path.
#
#   worker.sh run <worktree> <model> <effort>     (the prompt on stdin)
#       Runs the prompt in the worktree and prints a short summary. model is
#       haiku, sonnet, opus, fable or a full model ID; effort is low, medium,
#       high, xhigh or max. The /task: commands set their own model and
#       effort, so every model alias is pointed at the chosen model and
#       CLAUDE_CODE_EFFORT_LEVEL overrides the command's effort. Permissions
#       use auto mode, because nobody can answer a prompt in a headless run.
#       The full output is kept in <worktree>/.tasks/.runs/, and one line per
#       run goes to the main checkout's .tasks/runs.tsv, so costs survive
#       removing the worktree.
#
#   worker.sh costs <project> [name ...]
#       Lists the recorded runs, only those of the named pieces if any are
#       given, with their models, efforts and costs, and the total.
#
#   worker.sh finish <project> <name>
#       After a piece has landed: copies its finished task folders into
#       <project>/.tasks/, then removes the worktree and its branch. Refuses
#       while the branch has commits that aren't on the current branch.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
  echo "worker.sh: $*" >&2
  exit 2
}

repo_root() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null
}

# The main checkout that a worktree belongs to.
main_checkout() {
  local common
  common="$(cd "$1" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd)" || return 1
  case "$common" in
    */.git) printf '%s\n' "${common%/.git}" ;;
    *) repo_root "$1" ;;
  esac
}

# Keeps task files and worker worktrees out of `git status`. The exclude file
# is shared by every worktree of the repository.
ensure_excluded() {
  local root="$1" file line
  file="$(git -C "$root" rev-parse --git-path info/exclude 2>/dev/null)" || return 0
  case "$file" in /*) ;; *) file="$root/$file" ;; esac
  mkdir -p "$(dirname "$file")" || return 0
  for line in '**/.tasks/' '.claude/worktrees/'; do
    grep -qxF "$line" "$file" 2>/dev/null || printf '%s\n' "$line" >>"$file"
  done
}

cmd_status() {
  local project="${1:-$PWD}" root branch changes remote line path="" found=0
  if ! root="$(repo_root "$project")"; then
    echo "Not a git repository: $project"
    echo "/orchestrate needs one, because every piece runs in its own git worktree."
    exit 0
  fi
  branch="$(git -C "$root" symbolic-ref --short -q HEAD || echo "detached HEAD")"
  changes="$(git -C "$root" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  remote="$(git -C "$root" remote get-url origin 2>/dev/null || echo none)"
  echo "Project: $root"
  echo "Current branch: $branch (finished pieces land here)"
  echo "Remote: $remote"
  if [ "$changes" -gt 0 ]; then
    echo "Uncommitted changes: $changes (worktrees start from the last commit, so they won't see them)"
  else
    echo "Uncommitted changes: none"
  fi
  echo "Worker worktrees:"
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) path="${line#worktree }" ;;
      "branch refs/heads/"*)
        case "$path" in
          "$root"/.claude/worktrees/*)
            echo "  ${path#"$root"/} (branch ${line#branch refs/heads/})"
            found=1
            ;;
        esac
        ;;
    esac
  done < <(git -C "$root" worktree list --porcelain 2>/dev/null)
  [ "$found" = 1 ] || echo "  none"
  bash "$here/task.sh" "$root" | grep '^Commands:'
  exit 0
}

cmd_new() {
  [ "$#" -eq 2 ] || die "usage: worker.sh new <project> <name>"
  local root name="$2" path
  root="$(repo_root "$1")" || die "not a git repository: $1"
  case "$name" in
    '' | .* | *[!a-z0-9._-]*)
      die "use lowercase letters, digits, dots, dashes or underscores for the name: $name"
      ;;
  esac
  path="$root/.claude/worktrees/$name"
  [ ! -e "$path" ] || die "already exists: $path"
  if git -C "$root" show-ref --verify --quiet "refs/heads/$name"; then
    die "branch already exists: $name"
  fi
  ensure_excluded "$root"
  git -C "$root" worktree add -q -b "$name" "$path" HEAD || die "git worktree add failed"
  echo "$path"
}

# summarize LOG EXIT-CODE LEDGER NAME COMMAND MODEL EFFORT: prints a short
# summary of a run and adds a line for it to LEDGER.
summarize() {
  local log="$1" code="$2"
  if ! command -v python3 >/dev/null 2>&1; then
    echo "Exit code $code. python3 isn't installed, so there's no summary. The full result is in $log"
    return
  fi
  python3 -I - "$@" <<'PY'
import datetime, json, sys

log, code, ledger, name, command, model, effort = sys.argv[1:8]

def record(cost, status):
    try:
        when = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(ledger, "a") as fh:
            fh.write("\t".join([when, name, command, model, effort, f"{cost:.4f}", status]) + "\n")
    except OSError as exc:
        print(f"Couldn't record the run in {ledger}: {exc}")

try:
    with open(log) as fh:
        data = json.load(fh)
except Exception as exc:
    record(0, "no result")
    print(f"No result (exit code {code}): {exc}. Errors, if any, are in {log}.err")
    sys.exit()
events = data if isinstance(data, list) else [data]
result = next((e for e in reversed(events) if e.get("type") == "result"), None)
if result is None:
    record(0, "no result")
    print(f"No result (exit code {code}). See {log}")
    sys.exit()
ok = result.get("subtype") == "success" and not result.get("is_error")
models = ", ".join(sorted((result.get("modelUsage") or {}).keys())) or "unknown"
cost = result.get("total_cost_usd") or 0
record(cost, "finished" if ok else f"failed ({result.get('subtype')})")
status = "Finished" if ok else f"Failed ({result.get('subtype')})"
print(f"{status}. Model: {models}, effort {effort}. Cost: ${cost:.4f}.")
for denial in (result.get("permission_denials") or [])[:10]:
    detail = json.dumps(denial.get("tool_input"), ensure_ascii=False)[:200]
    print(f"Denied {denial.get('tool_name')}: {detail}")
print(f"Log: {log}")
print("--- Reply ---")
lines = (result.get("result") or "").strip().splitlines()
print("\n".join(lines[:80]))
if len(lines) > 80:
    print(f"[{len(lines) - 80} more lines in the log]")
PY
}

cmd_run() {
  [ "$#" -eq 3 ] || die "usage: worker.sh run <worktree> <model> <effort>, with the prompt on stdin"
  local worktree="$1" model="$2" effort="$3" id prompt logdir log code main command
  [ -d "$worktree" ] || die "no such worktree: $worktree"
  main="$(main_checkout "$worktree")" || die "not inside a git repository: $worktree"
  case "$model" in
    haiku) id=claude-haiku-5-5 ;;
    sonnet) id=claude-sonnet-5-5 ;;
    opus) id=claude-opus-5-5 ;;
    fable) id=claude-fable-5-2 ;;
    claude-*) id="$model" ;;
    *) die "model must be haiku, sonnet, opus, fable or a full model ID: $model" ;;
  esac
  case "$effort" in
    low | medium | high | xhigh | max) ;;
    *) die "effort must be low, medium, high, xhigh or max: $effort" ;;
  esac
  prompt="$(cat)"
  [ -n "${prompt//[[:space:]]/}" ] || die "no prompt on stdin"
  logdir="$worktree/.tasks/.runs"
  mkdir -p "$logdir" || die "can't create $logdir"
  log="$logdir/$(date +%Y%m%d-%H%M%S)-$$-$model-$effort.json"
  (
    cd "$worktree" &&
      ANTHROPIC_DEFAULT_HAIKU_MODEL="$id" \
        ANTHROPIC_DEFAULT_SONNET_MODEL="$id" \
        ANTHROPIC_DEFAULT_OPUS_MODEL="$id" \
        CLAUDE_CODE_EFFORT_LEVEL="$effort" \
        claude -p "$prompt" --model "$id" --permission-mode auto \
        --output-format json </dev/null >"$log" 2>"$log.err"
  )
  code=$?
  command="$(printf '%s\n' "$prompt" | awk 'NF { print $1; exit }')"
  case "$command" in /*) ;; *) command="(prompt)" ;; esac
  mkdir -p "$main/.tasks"
  summarize "$log" "$code" "$main/.tasks/runs.tsv" "$(basename "$worktree")" \
    "$command" "$model" "$effort"
  return "$code"
}

cmd_costs() {
  [ "$#" -ge 1 ] || die "usage: worker.sh costs <project> [name ...]"
  local root ledger
  root="$(repo_root "$1")" || die "not a git repository: $1"
  shift
  ledger="$root/.tasks/runs.tsv"
  if [ ! -f "$ledger" ]; then
    echo "No runs recorded yet."
    return 0
  fi
  awk -F '\t' -v names="$*" '
    BEGIN { wanted = split(names, list, " "); for (i = 1; i <= wanted; i++) keep[list[i]] = 1 }
    wanted == 0 || ($2 in keep) {
      printf "%s  %-16s %-16s %-7s %-6s $%s  %s\n", $1, $2, $3, $4, $5, $6, $7
      total += $6
      runs++
    }
    END { printf "%d runs, total $%.4f\n", runs, total }
  ' "$ledger"
}

cmd_finish() {
  [ "$#" -eq 2 ] || die "usage: worker.sh finish <project> <name>"
  local root name="$2" path branch current spec dir task
  root="$(repo_root "$1")" || die "not a git repository: $1"
  path="$root/.claude/worktrees/$name"
  [ -d "$path" ] || die "no such worktree: $path"
  branch="$(git -C "$path" symbolic-ref --short -q HEAD)" || die "$path isn't on a branch"
  current="$(git -C "$root" symbolic-ref --short -q HEAD || echo HEAD)"
  # `git cherry` marks with + each commit whose change isn't on HEAD yet, so
  # cherry-picked commits count as landed.
  if git -C "$root" cherry HEAD "$branch" | grep -q '^+'; then
    echo "Not removed: $branch has commits that aren't on $current yet." >&2
    exit 1
  fi
  for spec in "$path"/.tasks/*/spec.md; do
    [ -f "$spec" ] || continue
    head -n 1 "$spec" | grep -qiE '^status:[[:space:]]*done' || continue
    dir="$(dirname "$spec")"
    task="$(basename "$dir")"
    if [ -e "$root/.tasks/$task" ]; then
      echo "Task record already kept: $root/.tasks/$task"
    elif mkdir -p "$root/.tasks" && cp -R "$dir" "$root/.tasks/$task"; then
      echo "Kept task record: $root/.tasks/$task"
    fi
  done
  if ! git -C "$root" worktree remove "$path" 2>/dev/null; then
    echo "Not removed: $path has changes or files git doesn't track. Commit them, add them to .gitignore or delete them, then run finish again:" >&2
    git -C "$path" status --short | head -n 10 >&2
    exit 1
  fi
  if ! git -C "$root" branch -D "$branch" >/dev/null; then
    echo "Removed $path, but couldn't delete branch $branch." >&2
    exit 1
  fi
  echo "Removed worktree $path and branch $branch."
}

cmd="${1:-}"
[ "$#" -gt 0 ] && shift
case "$cmd" in
  status) cmd_status "$@" ;;
  new) cmd_new "$@" ;;
  run) cmd_run "$@" ;;
  finish) cmd_finish "$@" ;;
  costs) cmd_costs "$@" ;;
  *) die "usage: worker.sh status|new|run|finish|costs …  (see the comment at the top)" ;;
esac

---
name: orchestrate
description: Split a request into pieces and run each one in its own git worktree through the task pipeline, as background sessions whose model and effort you choose every time. Then check and land the results.
argument-hint: "<request, such as Phase 3 from docs/plans/phase-03.md>"
disable-model-invocation: true
allowed-tools:
  - Bash(bash ${CLAUDE_SKILL_DIR}/scripts/worker.sh *)
---

# Orchestrate: split the work, run it in worktrees, land it

You are the orchestrator. Your tokens are the most expensive in this setup: you plan, start, check and land the work, and the sessions you start do the work itself. Keep your own messages short.

## State

!`bash ${CLAUDE_SKILL_DIR}/scripts/worker.sh status "${CLAUDE_PROJECT_DIR}"`

## The request

$ARGUMENTS

Replace each placeholder such as `<prepare command>` with the command the Commands line in the state gives for it. `worker` below means `bash ${CLAUDE_SKILL_DIR}/scripts/worker.sh`, whose header comment explains each subcommand. Write that full command every time, never through a shell variable: the user's shell may be zsh, which doesn't split variables into words, and permission rules match the command as written. Keep your own shell in the main checkout: use `git -C <worktree>`, and run anything else in a worktree inside a subshell, such as `(cd <worktree> && <check>)`. If the state says this isn't a git repository, say that /orchestrate needs one and stop.

## Routes

Each piece takes one route:

- **Pipeline**: three sessions in the piece's worktree, one after another: `<prepare command> <brief>`, then `<instruct command>`, then `<start command>`. For work that needs design or touches several files.
- **One session**: `<start command> <brief>` does the whole piece. For small, clear pieces.
- **Yourself**: no session. For a question, a few commands or one small edit, which you make here and commit.

The request can set a piece's route (`pipeline:`, `one session:`) or ask for the user's review (`review me:` means the user approves that piece's instructions.md before `<start command>` runs).

## Ask before every session

Never start a session without asking the user for its model and effort, and that includes re-runs. Ask with AskUserQuestion: one question per session, headed with the piece and step (such as "A prepare"), with the sessions that start together in one call, at most 4 questions per call. Give four options written as "Model · effort", the recommended one first and marked "(Recommended)":

| Step | Recommended | Other options |
|---|---|---|
| `<prepare command>` | Haiku · medium | Sonnet · medium, Sonnet · high, Opus · high |
| `<instruct command>` | Opus · high | Opus · medium, Sonnet · high, Sonnet · medium |
| `<start command>` | Sonnet · high | Sonnet · medium, Opus · high, Opus · medium |

Recommend differently when the piece calls for it, such as Opus · high for a subtle one-session piece, or what the request named for that piece. The user can type anything else in Other, such as "Opus · max". Pass the answer to `worker run` as the model (haiku, sonnet, opus or fable) and the effort (low, medium, high, xhigh or max).

## Steps

1. **Understand it cheaply.** Read only what you need to split the work: the docs and plan sections the request points to, and `git log --oneline -15`. Don't explore the code. If the state shows uncommitted changes, say that sessions start from the last commit and ask whether to go on. If a decision belongs to the user (product, licences, a doc change that needs agreement), ask before starting anything.
2. **Split it and confirm.** Split the work into pieces that shouldn't touch the same files; a piece that needs another's result waits for it. Ask one AskUserQuestion, "Run this plan?", with the plan in the first option's preview: one line per piece (letter, short title, route), then what waits for what. Options: "Run as proposed (Recommended)" and "Change routes", which then asks each piece's route. If the user types a change in Other, split again and ask again.
3. **Start.** For each piece that isn't yours, make a worktree with `worker new <project> <name>`, using a short lowercase name such as `a-word-wrap`. Ask the model and effort for every session that starts now, then start each one in the background (run_in_background), with the prompt on stdin:

   ```
   bash ${CLAUDE_SKILL_DIR}/scripts/worker.sh run <worktree> <model> <effort> <<'PROMPT'
   <prepare command> <brief>
   PROMPT
   ```

   Pipeline pieces start with `<prepare command> <brief>`, one-session pieces with `<start command> <brief>`. The brief covers:
   - the task, and the files or area it covers
   - the doc and plan sections to read first
   - what done looks like, including the checks that must pass
   - files other pieces are editing, and that edits to them stay small
   - "Commit your work on this branch when done, and never push or touch other branches. Don't mark progress in the plan or other source documents; the orchestrator does that. If something needs the user's decision, such as a licence, a docs change or a product question, stop and report it instead of deciding."

   Each run ends with a summary: the model and effort it used, its cost, any denied actions and its reply. Read it when you're told the run has ended; don't poll. `worker costs <project>` lists every recorded run, even after its worktree is gone.
4. **Check the split.** When the prepare runs have ended, read the Files and Open questions sections of each `<worktree>/.tasks/*/brief.md`. If two pieces touch the same files, hold the later one until the first has landed, then fast-forward its branch (`git -C <worktree> merge --ff-only <current branch>`) and ask and run `<prepare command>` there again. Answer the open questions you can, and bring the user's to the user.
5. **Plan.** Ask, then run `<instruct command> <your answers, if any>` for each pipeline piece. When a run ends, read its instructions.md and check that:
   - each step's files stay inside the piece
   - the Done when list matches what was agreed
   - no step makes a decision that belongs to the user
   - pieces that share a file or interface agree on it

   If something's wrong, ask and run `<instruct command> <correction>`. For a `review me:` piece, show the user the instructions and wait for their approval.
6. **Implement.** Ask, then run `<start command> Leave the source document alone; the orchestrator updates it. Commit on this branch when done.` If a run stops with a question, answer it or bring it to the user, then ask and run `<start command> <answer>`; it carries on from the steps not yet ticked.
7. **Check before landing.** A report isn't proof. For pipeline pieces, spec.md must say `Status: done`, with every step in instructions.md ticked. Read `git -C <worktree> log --oneline` and the diff, compare them with the instructions or the brief, and run the checks from the brief's Build and test section.
8. **Land** each piece on the current branch: `git merge --ff-only <branch>` when possible, otherwise cherry-pick its commits, and resolve conflicts yourself. If there's a remote, `git fetch` first and compare. After landing, run the checks again on the combined result. Then:
   - tick the finished items in the source document once, in its own style, and commit that
   - run `worker finish <project> <name>` for each landed piece. It keeps finished task folders in the project's `.tasks/`, then removes the worktree and branch, and it refuses while the branch has commits that haven't landed.

   Push only when the user says so.
9. **Report briefly:** what landed, what was checked and what wasn't, what each session cost (`worker costs <project> <names>`, with the total), what's still running, and the one decision you need, if any.

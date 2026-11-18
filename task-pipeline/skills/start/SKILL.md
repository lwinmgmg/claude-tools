---
name: start
description: Implement the current task by following its instructions.md. With no task open, does the text as a small task. Runs on Sonnet.
argument-hint: "[steps to run or changes, or a small task]"
disable-model-invocation: true
model: sonnet
effort: high
allowed-tools:
  - Bash(bash ${CLAUDE_SKILL_DIR}/scripts/task.sh *)
  - Edit(.tasks/**)
---

# Start: implement the instructions

## Task state

!`bash ${CLAUDE_SKILL_DIR}/scripts/task.sh "${CLAUDE_PROJECT_DIR}" spec.md instructions.md`

## The user's text

$ARGUMENTS

Replace each placeholder such as `<prepare command>` with the command the Commands line in the task state gives for it.

## What to do

- **Current task with instructions.md**: run the steps not yet ticked, in order. The user's text can limit or change the run, for example `steps 1-3` or `skip step 4`.
- **Current task without instructions.md**: reply `Run <instruct command> first.` and stop, unless the user's text says to go ahead anyway.
- **No current task**: treat the user's text as a small, self-contained task and do it directly. If there's no text, say there's nothing to start.

## While implementing

- Follow the instructions; don't redesign. Read the files each step names, and avoid broad exploration.
- After each step, run its check, then tick the step in instructions.md: `### [ ] 1.` becomes `### [x] 1.`.
- Keep command output short: run the narrowest test that covers the step, and trim long output (for example `2>&1 | tail -n 40`).
- If a "Stop and ask if" condition happens, stop and report what you found and what you suggest.

## When every step is ticked and the Done-when list holds

1. Change the first line of spec.md to `Status: done`.
2. If spec.md's `Source:` names a document, such as `plan.md, Phase 0`, decide whether that document tracks progress (checkboxes, status lines, "done" markers). If it does, mark the finished items in the same style. If it doesn't, leave it unchanged.
3. Report the files changed, the checks you ran and their results, anything left over, and whether you updated the source document.

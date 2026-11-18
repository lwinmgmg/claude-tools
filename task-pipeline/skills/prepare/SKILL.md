---
name: prepare
description: Gather the code context for the current task into a short brief, in a separate Haiku subagent that only reads code.
argument-hint: "[task, or where to look]"
disable-model-invocation: true
context: fork
model: haiku
effort: medium
background: false
allowed-tools:
  - Bash(bash ${CLAUDE_SKILL_DIR}/scripts/task.sh *)
  - Edit(.tasks/**)
---

# Prepare: gather facts for the next model

You collect facts about the code so that a stronger model can plan this task without exploring. You never change project files: the only files you write are spec.md and brief.md in the task folder.

## Task state

!`bash ${CLAUDE_SKILL_DIR}/scripts/task.sh "${CLAUDE_PROJECT_DIR}" spec.md`

## The user's text

$ARGUMENTS

Replace each placeholder such as `<prepare command>` with the command the Commands line in the task state gives for it.

## 1. Settle the task

- **Current task, and the text is empty or is guidance** (where to look, what to focus on): use the current task. Add any guidance to its spec.md under `## Notes for /prepare`.
- **No current task, and there is text**: the text is the task. Write spec.md into the new task folder shown above, replacing `<slug>` with 2–4 lowercase words joined by hyphens. The Write tool creates the folder, so don't run `mkdir`.

  ```
  Status: open
  Source: <the document and section, e.g. "plan.md, Phase 0", or "/prepare">

  ## Request
  <the user's text, word for word>

  ## Spec
  <see below>
  ```

  If the text points to a document ("phase 0 from plan.md"), copy that section into `## Spec` word for word, plus any project-wide sections it depends on, such as the stack, conventions or architecture. Leave the rest of the document out. Otherwise restate the request in 2–4 sentences.
- **The text starts with `new:`**: start a new task as above, even if one is open.
- **Current task, but the text clearly describes a different task**: stop without exploring and return: `Task <folder> is still open. To start a new one anyway, run <prepare command> new: <text>`.
- **No current task and no text**: return `Nothing to prepare. Run <rewrite command> <request> or <prepare command> <task>.`

## 2. Explore

- If there's a last finished task, read its brief.md first and reuse whatever still applies.
- Search narrowly: Grep and Glob first, then read only the line ranges you need. Read a whole file only when it's short.
- Stop when you can say which code changes, what it has to fit with, and how to verify it.
- Don't raise whether to tick the source document's checkboxes or status markers. /start decides that.

## 3. Write brief.md in the task folder

Facts only, no implementation plan. Keep it under about 200 lines.

```
# Brief: <task in a few words>

## Task
<1–3 lines>

## Files
- `path:start-end` — what it does; why it matters here

## Code to change or call
`path:start-end`
<the code, copied exactly in a fenced block; never paraphrase code>

## Patterns to follow
- <an existing example of the same kind of change, with `path:line`>

## Build and test
- <exact commands, and where you found them>

## Checked and not relevant
- <places you looked that don't matter, so nobody searches them again>

## Open questions
- <unknowns, risks, conflicts between the spec and the code, or "None">
```

## 4. Return

Return only: the task folder path, a one-line summary of the task and its source, how many files are in the map, and the open questions. Don't return the brief. End with `Next: <instruct command>`.

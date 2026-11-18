---
name: instruct
description: Turn the current task's spec and brief into step-by-step instructions that a cheaper model can follow. Runs on Opus.
argument-hint: "[constraints or preferences]"
disable-model-invocation: true
model: opus
effort: high
allowed-tools:
  - Bash(bash ${CLAUDE_SKILL_DIR}/scripts/task.sh *)
  - Edit(.tasks/**)
---

# Instruct: decide how to make the change

Write instructions.md for the current task: a plan concrete enough that a less capable model can implement it without making design decisions. The design decisions happen here, so think them through.

## Task state

!`bash ${CLAUDE_SKILL_DIR}/scripts/task.sh "${CLAUDE_PROJECT_DIR}" spec.md brief.md instructions.md`

## The user's text

$ARGUMENTS

A placeholder such as `<prepare command>` stands for that command's full name from the Commands line in the task state, such as /task:prepare. Always write the full name in replies.

## Rules

- No current task, or no brief.md yet: reply `Run <prepare command> first.` and stop.
- If instructions.md already exists, revise it with the user's text instead of starting over, and keep the ticks on steps already done.
- Work from the brief. Read code only to settle a specific doubt, and then only the lines you need.
- Put the user's text under Constraints so later steps see it.
- Write code sketches only for the tricky parts. The implementer writes the code; writing all of it here would cost the expensive model's price again.
- Keep each step small enough to have its own check.
- Don't plan or forbid updates to the source document's progress markers, such as ticking plan.md checkboxes. /start decides that when the task is done.

## Format of instructions.md

```
# Instructions: <task in a few words>

## Approach
<3–6 lines: the design you chose and why>

## Constraints
- <from the user's text and the spec>

## Steps

### [ ] 1. <title>
- Files: `path:lines`
- Change: <exactly what to do>
- Sketch: <code, only where the change is tricky>
- Check: <a command to run, or "done when …">

### [ ] 2. <title>
…

## Stop and ask if
- the code doesn't match the brief or these steps
- a check fails twice
- a change is needed outside the files listed
- <risks specific to this task>

## Done when
- <acceptance criteria from the spec>
```

## Reply

Only the Approach and the step titles, then:
`Review <path to instructions.md>, then run <start command> (or <start command> steps 1-3).`

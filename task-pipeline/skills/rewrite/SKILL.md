---
name: rewrite
description: Restate a request so you can confirm it was understood, and save it as the task spec. Runs on Haiku.
argument-hint: "[request, or a correction to the last restatement]"
disable-model-invocation: true
model: haiku
effort: low
allowed-tools:
  - Bash(bash ${CLAUDE_SKILL_DIR}/scripts/task.sh *)
  - Edit(.tasks/**)
---

# Rewrite: confirm the request was understood

Your only job is to check that the request was understood. Don't read project code, plan, or implement.

## Task state

!`bash ${CLAUDE_SKILL_DIR}/scripts/task.sh "${CLAUDE_PROJECT_DIR}" spec.md`

## The user's text

$ARGUMENTS

A placeholder such as `<prepare command>` stands for that command's full name from the Commands line in the task state, such as /task:prepare. Always write the full name in replies.

## Steps

1. If the user's text is empty, ask what they want and stop.
2. Pick the spec to write:
   - **Revise the current task's spec.md** when the current task has no brief.md yet and the text corrects or adds to it ("no, I meant…", "also…").
   - **Otherwise start a new task**: create spec.md in the new task folder shown above, replacing `<slug>` with 2–4 lowercase words joined by hyphens. The Write tool creates the folder, so don't run `mkdir`.
3. Write spec.md in this exact shape:

   ```
   Status: open
   Source: /rewrite

   ## Request
   <the user's text, word for word; when revising, keep the earlier text and add the new text below it>

   ## Understanding
   <2–4 sentences: the goal, and what will be visibly different when it's done>

   ## Scope
   - In: <…>
   - Out: <…>

   ## Assumptions
   - <each thing you filled in that the user didn't say, or "None">

   ## Questions
   - <only real ambiguities that change the result, or "None">
   ```

4. Reply with only the Understanding, Assumptions and Questions, then this line:
   `Looks right? Run <prepare command>. Something off? Run <rewrite command> <correction>.`

Never invent specifics the user didn't give, such as file names, libraries or numbers. Put them under Questions.

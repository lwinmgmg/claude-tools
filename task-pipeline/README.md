# Task pipeline skills for Claude Code

Four personal skills that split a coding task across models, so the expensive model only does the part that needs judgment.

| Command | Runs on | What it does | Writes |
|---|---|---|---|
| `/rewrite <request>` | Haiku | Restates your request so you can confirm it was understood | `spec.md` |
| `/prepare [text]` | Haiku, in a separate subagent | Finds and reads the relevant code, and records facts only | `spec.md` for a new task, `brief.md` |
| `/instruct [text]` | Opus | Chooses the design and writes small steps, each with a check | `instructions.md` |
| `/start [text]` | Sonnet | Follows the steps, ticks them off, and marks the task done | code changes |

Each command sets its own model, so you never switch with `/model`. All four are user-only: their descriptions aren't loaded into Claude's context, so they cost nothing in sessions where you don't use them.

## Typical runs

From a plan you already have:

```
/prepare Start the implementation for phase 0 from plan.md
/instruct
/start
```

From a rough idea:

```
/rewrite add rate limiting to the login endpoint
/prepare
/instruct no new dependencies
/start steps 1-3
/start
```

`/rewrite` is optional. Use it when you want to check the request was understood before any code is read.

## The optional text

The text adds to what the previous step wrote; it doesn't replace it. When no task is in progress, the text is the task.

| Command | Without text | With text |
|---|---|---|
| `/prepare` | Explores for the current spec | Where to look; or the task itself when none is open. Start it with `new:` to force a new task |
| `/instruct` | Plans from the brief | Constraints, such as `no new dependencies`. Re-running it revises the existing instructions |
| `/start` | Runs every step not yet ticked | Limits or changes the run, such as `steps 1-3`; or a small task when none is open |

## Task files

Each task gets a folder in the project, `.tasks/<timestamp>-<slug>/`, with `spec.md`, `brief.md` and `instructions.md`. The commands work on the newest task until `/start` sets its first line to `Status: done`. To drop a task, change that line to `Status: abandoned`.

The folder is added to `.git/info/exclude`, so it stays out of commits without changing `.gitignore`. It isn't under `.claude/`, because Claude Code treats everything there as sensitive and asks before every write.

When a task came from a document such as `plan.md`, `/start` decides at the end whether to update it: if the document tracks progress, for example with checkboxes, it marks the finished items the same way.

## Tips

- Everything lives in the task files, so you can run `/clear` before `/instruct` or `/start` to begin with the smallest context.
- For a fix after a task is done, use `/start <what to fix>`. It runs on Sonnet; a plain message would go to your session model and send it the whole conversation.

## Install on this machine

```
./install.sh
```

This copies the skills into `~/.claude/skills`. Re-run it after editing anything in `skills/` or `lib/`. It never replaces a skill folder it didn't create.

## Use in cloud sessions

Cloud sessions don't read `~/.claude/skills` from your machine. Uploading the skills on claude.ai doesn't work either, because claude.ai rejects the `model` and `context` fields these skills depend on. Instead, your cloud environment's setup script installs them on the cloud VM:

1. Run `./build-cloud-setup.sh`. It writes `dist/cloud-setup.sh`.
2. At [claude.ai/code](https://claude.ai/code), open the settings of one of your own environments, not an organization-shared one. Select **Setup script**, choose `dist/cloud-setup.sh`, and save. If the environment already has a setup script, paste the generated lines at the end of it instead.
3. Start a new cloud session and type `/` to check that the four commands appear.

Rebuild and re-add the script after changing the skills. Changing the script also rebuilds the environment's cache.

## Files

| Path | What it is |
|---|---|
| `skills/<name>/SKILL.md` | The four skills |
| `lib/task.sh` | Finds the current task and prints its files into each skill when it starts. Copied into each skill's `scripts/` folder on install |
| `install.sh` | Installs into `~/.claude/skills` |
| `build-cloud-setup.sh` | Builds `dist/cloud-setup.sh` for cloud environments |

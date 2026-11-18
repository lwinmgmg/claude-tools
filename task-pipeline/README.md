# Task pipeline

Four skills that split a coding task across models, so the expensive model only does the part that needs judgment.

| Command | Runs on | What it does | Writes |
|---|---|---|---|
| `/task:rewrite <request>` | Haiku | Restates your request so you can confirm it was understood | `spec.md` |
| `/task:prepare [text]` | Haiku, in a separate subagent | Finds and reads the relevant code, and records facts only | `spec.md` for a new task, `brief.md` |
| `/task:instruct [text]` | Opus | Chooses the design and writes small steps, each with a check | `instructions.md` |
| `/task:start [text]` | Sonnet | Follows the steps, ticks them off, and marks the task done | code changes |

Each command sets its own model, so you never switch with `/model`. All four are user-only: their descriptions aren't loaded into Claude's context, so they cost nothing in sessions where you don't use them.

These are the plugin's command names. Installed with `install.sh` instead, the commands have no prefix: `/rewrite`, `/prepare`, `/instruct` and `/start`.

## Install

As a plugin, with no clone. In Claude Code 2.1.275 or later:

```
/plugin install task --marketplace lwinmgmg/claude-tools
```

In earlier versions, add the marketplace first:

```
/plugin marketplace add lwinmgmg/claude-tools
/plugin install task@claude-tools
```

To get updates, run `/plugin marketplace update claude-tools`, or turn on auto-update for the marketplace under **Marketplaces** in `/plugin`.

For the short names instead, clone the repository and run:

```
./task-pipeline/install.sh
```

This copies the skills into `~/.claude/skills`. Run it again to update, or after editing anything in `skills/` or `lib/`. It never replaces a skill folder it didn't create.

Use one or the other on a machine. With both, every command appears twice.

## Typical runs

From a plan you already have:

```
/task:prepare Start the implementation for phase 0 from plan.md
/task:instruct
/task:start
```

From a rough idea:

```
/task:rewrite add rate limiting to the login endpoint
/task:prepare
/task:instruct no new dependencies
/task:start steps 1-3
/task:start
```

`/task:rewrite` is optional. Use it when you want to check the request was understood before any code is read.

## The optional text

The text adds to what the previous step wrote; it doesn't replace it. When no task is in progress, the text is the task.

| Command | Without text | With text |
|---|---|---|
| `/task:prepare` | Explores for the current spec | Where to look; or the task itself when none is open. Start it with `new:` to force a new task |
| `/task:instruct` | Plans from the brief | Constraints, such as `no new dependencies`. Running it again revises the existing instructions |
| `/task:start` | Runs every step not yet ticked | Limits or changes the run, such as `steps 1-3`; or a small task when none is open |

## Task files

Each task gets a folder in the project, `.tasks/<timestamp>-<slug>/`, with `spec.md`, `brief.md` and `instructions.md`. The commands work on the newest task until `/task:start` sets its first line to `Status: done`. To drop a task, change that line to `Status: abandoned`.

The folder is added to `.git/info/exclude`, so it stays out of commits without changing `.gitignore`. It isn't under `.claude/`, because Claude Code treats everything there as sensitive and asks before every write.

When a task came from a document such as `plan.md`, `/task:start` decides at the end whether to update it: if the document tracks progress, for example with checkboxes, it marks the finished items the same way.

## Tips

- Everything lives in the task files, so you can run `/clear` before `/task:instruct` or `/task:start` to begin with the smallest context.
- For a fix after a task is done, use `/task:start <what to fix>`. It runs on Sonnet; a plain message would go to your session model and send it the whole conversation.

## Use in cloud sessions

Cloud sessions don't load your plugins or `~/.claude/skills`. Uploading the skills to claude.ai doesn't work either, because claude.ai rejects the `model` and `context` fields these skills depend on. Instead, your cloud environment's setup script installs them on the cloud VM, where they run with the short names:

1. At [claude.ai/code](https://claude.ai/code), open the settings of one of your own environments, not an organization-shared one, and select **Setup script**.
2. Add the lines from [`cloud-setup.sh`](cloud-setup.sh). They clone this repository and run `install.sh`, and they never fail the setup, so a failed install doesn't stop the session starting.
3. Start a new cloud session and type `/` to check that `/rewrite`, `/prepare`, `/instruct` and `/start` appear.

The environment caches what its setup script installs, so cloud sessions pick up a new version when that cache rebuilds, about once a week, or when you change the script.

## Files

| Path | What it is |
|---|---|
| `.claude-plugin/plugin.json` | The plugin's name and description |
| `skills/<name>/SKILL.md` | The four skills |
| `lib/task.sh` | Finds the current task and prints its files into each skill when it starts |
| `skills/<name>/scripts/task.sh` | Links to `lib/task.sh`, so each skill can run it inside the plugin. `install.sh` copies the real file instead |
| `install.sh` | Installs the skills into `~/.claude/skills` with the short names |
| `cloud-setup.sh` | The lines to add to a cloud environment's setup script |
| `tests/task.test.sh` | Tests for `lib/task.sh`. CI runs them on every push |

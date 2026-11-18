# claude-tools

[![check](https://github.com/lwinmgmg/claude-tools/actions/workflows/check.yml/badge.svg)](https://github.com/lwinmgmg/claude-tools/actions/workflows/check.yml)

Tools for getting more out of Claude Code while spending fewer tokens. This repository is a Claude Code plugin marketplace, and each tool has its own folder and README.

## Tools

| Tool | Plugin | What it does |
|---|---|---|
| [task-pipeline](task-pipeline/) | `task` | Four skills that split a coding task across models: Haiku gathers the context (`/task:prepare`), Opus writes the steps (`/task:instruct`), and Sonnet implements them (`/task:start`). An optional `/task:rewrite` first checks that your request was understood. |

## Install

In Claude Code 2.1.275 or later, no clone needed:

```
/plugin install task --marketplace lwinmgmg/claude-tools
```

In earlier versions, add the marketplace first:

```
/plugin marketplace add lwinmgmg/claude-tools
/plugin install task@claude-tools
```

To get updates, run `/plugin marketplace update claude-tools`, or turn on auto-update for the marketplace under **Marketplaces** in `/plugin`.

[task-pipeline/README.md](task-pipeline/README.md) covers how to use it, how to install it with shorter command names, and cloud sessions.

## Requirements

- Claude Code. Tested with version 2.1.327.
- bash and git, on macOS or Linux.

## Adding a tool

Give each tool its own folder at the root of the repository, with a README.md. List it in `.claude-plugin/marketplace.json`, add its checks to `.github/workflows/check.yml`, and add a row to the table above.

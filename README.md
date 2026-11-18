# claude-tools

Tools for getting more out of Claude Code while spending fewer tokens. Each tool has its own folder and README.

## Tools

| Tool | What it does |
|---|---|
| [task-pipeline](task-pipeline/) | Four skills that split a coding task across models: Haiku gathers the context (`/prepare`), Opus writes the steps (`/instruct`), and Sonnet implements them (`/start`). An optional `/rewrite` first checks that your request was understood. |

## Get started

```
git clone https://github.com/lwinmgmg/claude-tools.git
cd claude-tools
./task-pipeline/install.sh
```

Then, in any project:

```
/prepare Start the implementation for phase 0 from plan.md
/instruct
/start
```

[task-pipeline/README.md](task-pipeline/README.md) has the full guide, including how to use the skills in cloud sessions.

## Requirements

- Claude Code. Tested with version 2.1.327.
- bash and git, on macOS or Linux.

## Adding a tool

Give each tool its own folder at the root of the repository, with a README.md, and add a row to the table above.

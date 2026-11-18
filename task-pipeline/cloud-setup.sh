#!/bin/bash
# Setup script for a Claude Code cloud environment. It installs the
# task-pipeline skills into ~/.claude/skills on the cloud VM, where they run as
# /rewrite, /prepare, /instruct and /start.
#
# Add these lines to your environment's Setup script at claude.ai/code. A setup
# script must exit 0, so a failed install doesn't stop the session starting.
rm -rf /tmp/claude-tools
git clone --quiet --depth 1 https://github.com/lwinmgmg/claude-tools.git /tmp/claude-tools &&
  bash /tmp/claude-tools/task-pipeline/install.sh || true

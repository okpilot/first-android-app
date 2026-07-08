#!/usr/bin/env bash
# Activate this repo's git hooks. Run once per clone (core.hooksPath is a local
# git setting, not committed). Hooks themselves live in .githooks/ (tracked).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
chmod +x .githooks/* 2>/dev/null || true
git config core.hooksPath .githooks
echo "✓ git hooks active (core.hooksPath=.githooks): pre-commit, commit-msg, pre-push"

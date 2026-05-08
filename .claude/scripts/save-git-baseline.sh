#!/usr/bin/env bash
# Called by Stop hook — saves current git diff as baseline for next request's delta tracking

STATE_DIR="/tmp/claude-sl-${USER:-anon}"
mkdir -p "$STATE_DIR" 2>/dev/null

git rev-parse --is-inside-work-tree &>/dev/null || exit 0

git diff --numstat 2>/dev/null | grep -v '^-' > "$STATE_DIR/baseline.numstat" || true

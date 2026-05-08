#!/bin/bash
set +e
export PATH="$HOME/.npm-global/bin:$PATH"

echo "== check registry =="
npm config get registry
echo "== install sequential-thinking =="
npm install -g --no-audit --no-fund --loglevel=error --prefer-online \
  @modelcontextprotocol/server-sequential-thinking 2>&1 | tail -10

echo "== install exa-mcp-server =="
npm install -g --no-audit --no-fund --loglevel=error --prefer-online \
  exa-mcp-server 2>&1 | tail -10

echo "== verify =="
ls -la ~/.npm-global/bin/ | grep -E 'exa|sequential|claude'

echo "== claude version =="
~/.npm-global/bin/claude --version 2>&1

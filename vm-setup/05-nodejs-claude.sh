#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [5/7] Node.js + Claude Code + MCP servers"

if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d. -f1 | tr -d v)" -lt 20 ]; then
  echo "  -> install Node.js LTS via NodeSource"
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1
  sudo apt-get install -y -qq nodejs
fi

echo "  -> Node version: $(node -v)"
echo "  -> npm version: $(npm -v)"

# Set up npm global without sudo for ubuntu user
mkdir -p ~/.npm-global
npm config set prefix "$HOME/.npm-global"
if ! grep -q "npm-global/bin" ~/.bashrc; then
  echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/.npm-global/bin:$PATH"

echo "  -> install @anthropic-ai/claude-code"
npm install -g @anthropic-ai/claude-code

echo "  -> Claude version: $(claude --version 2>&1 | head -1)"

echo "  -> install MCP server packages globally"
npm install -g \
  @modelcontextprotocol/server-fetch \
  @modelcontextprotocol/server-sequential-thinking \
  exa-mcp-server || true

echo "  -> install useful CLI tools"
npm install -g pnpm yarn typescript ts-node || true

echo ""
echo "==> [5/7] DONE"
echo ""
echo "============================================="
echo "  ⚠ ИНТЕРАКТИВ АЛХАМ — ГАРАА УД ХИЙХ ШААРДЛАГАТАЙ"
echo "============================================="
echo ""
echo "  1) Claude OAuth login:"
echo "     SSH-ээр ороод:  ssh -i .\\id_ed25519 ubuntu@vnc.egulcloud.com"
echo "     Энд:           claude"
echo "     URL гарна → laptop/phone-ийн browser дээр нээгээд login"
echo "     Auth code paste → ~/.claude/credentials.json үүсгэгдэнэ"
echo ""
echo "  2) MCP server-үүд нэмэх:"
echo "     # Sequential thinking (no API key)"
echo "     claude mcp add sequential-thinking --scope user -- npx -y @modelcontextprotocol/server-sequential-thinking"
echo ""
echo "     # Fetch (no API key)"
echo "     claude mcp add fetch --scope user -- npx -y @modelcontextprotocol/server-fetch"
echo ""
echo "     # Exa search (need API key from exa.ai)"
echo "     export EXA_API_KEY=your_key_here"
echo "     claude mcp add exa --scope user --env EXA_API_KEY=\$EXA_API_KEY -- npx -y exa-mcp-server"
echo ""
echo "  3) Шалгах:"
echo "     claude mcp list"

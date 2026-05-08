#!/bin/bash
set -euo pipefail

echo "==> finalize: fix PATH + final summary"

# Remove any malformed PATH lines from previous attempt
sed -i '/Users.bumab/d' ~/.bashrc
sed -i '/^export PATH=.*Users/d' ~/.bashrc

# Make sure .npm-global and .local/bin are in PATH
if ! grep -q 'npm-global/bin' ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'

# Olympiad workstation PATH
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
EOF
fi

# Source it for current shell verification
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

echo "  -> PATH lines in .bashrc:"
grep -n 'PATH' ~/.bashrc

echo ""
echo "============================================"
echo "  PRE-FLIGHT VERIFICATION"
echo "============================================"

echo "[code-server]"
systemctl is-active code-server@ubuntu
echo "  https://code.egulcloud.com password (NOTE):"
grep '^password:' ~/.config/code-server/config.yaml

echo ""
echo "[KasmVNC]"
systemctl is-active kasmvnc.service
echo "  https://vnc.egulcloud.com password (NOTE):"
cat ~/.vnc/password.txt

echo ""
echo "[Caddy]"
systemctl is-active caddy

echo ""
echo "[Claude Code]"
~/.npm-global/bin/claude --version 2>&1 | head -1
ls ~/.config/claude 2>/dev/null && echo "  (logged in)" || echo "  (NOT logged in yet — run 'claude' interactively)"

echo ""
echo "[MCP packages installed]"
ls ~/.npm-global/bin/ | grep -E 'exa|sequential|fetch' || echo "  none"

echo ""
echo "[Python tools]"
~/.local/bin/netmiko-show --version 2>&1 | head -1 || python3 -c "import netmiko; print('netmiko', netmiko.__version__)"
python3 -c "import ciscoconfparse2; print('ciscoconfparse2', ciscoconfparse2.__version__)"

echo ""
echo "[Ports listening]"
ss -lnt | grep -E ':(22|80|443|8080|6901)\b'

echo ""
echo "============================================"
echo "  HTTPS tests"
echo "============================================"
echo "code.egulcloud.com:"
curl -sI https://code.egulcloud.com 2>&1 | head -3
echo "vnc.egulcloud.com:"
curl -sI https://vnc.egulcloud.com 2>&1 | head -3

echo ""
echo "============================================"
echo "  REMAINING (interactive — гараар):"
echo "============================================"
cat <<'TODO'

  1. Claude OAuth login:
     ssh -i ./id_ed25519 ubuntu@vnc.egulcloud.com
     export PATH=$HOME/.npm-global/bin:$PATH
     claude
     # → URL гарна, browser-аас login, code paste

  2. MCP servers add:
     claude mcp add sequential-thinking --scope user -- npx -y @modelcontextprotocol/server-sequential-thinking
     # Exa: API key экспортлоод
     export EXA_API_KEY=...
     claude mcp add exa --scope user --env EXA_API_KEY=$EXA_API_KEY -- npx -y exa-mcp-server
     claude mcp list

  3. Repo clone:
     gh auth login    # browser flow
     cd ~
     git clone <network_olymp URL>
     git clone https://github.com/bum035/net.git

  4. (Optional) Code-server-д extension суулгах:
     - Cisco IOS Syntax Highlighting (Lakuapik.cisco-ios)
     - GitLens

TODO

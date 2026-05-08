#!/bin/bash
set -euo pipefail

echo "==> [3/7] code-server"

if ! command -v code-server >/dev/null 2>&1; then
  echo "  -> install code-server (official script)"
  curl -fsSL https://code-server.dev/install.sh | sh
else
  echo "  -> code-server already installed: $(code-server --version | head -1)"
fi

echo "  -> generate strong password"
PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 28)

mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 127.0.0.1:8080
auth: password
password: ${PASSWORD}
cert: false
EOF
chmod 600 ~/.config/code-server/config.yaml

echo "  -> enable + start code-server@ubuntu service"
sudo systemctl enable code-server@ubuntu
sudo systemctl restart code-server@ubuntu
sleep 4

echo "  -> service status"
sudo systemctl status code-server@ubuntu --no-pager | head -10 || true

echo "  -> port 8080 listening?"
ss -lnt | grep :8080 || echo "  WARN: nothing on 8080 yet"

echo "  -> local probe"
curl -sI http://127.0.0.1:8080 | head -3 || true

echo ""
echo "==> [3/7] DONE"
echo "============================================="
echo "  code-server password (SAVE THIS):"
echo "  ${PASSWORD}"
echo "============================================="
echo "  URL: https://code.egulcloud.com"
echo "  Saved to: ~/.config/code-server/config.yaml"

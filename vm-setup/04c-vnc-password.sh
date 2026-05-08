#!/bin/bash
set -euo pipefail

echo "==> [4c] KasmVNC password (via pipe)"

# Kill any running session
/usr/bin/kasmvncserver -kill :1 2>/dev/null || true
pkill -u ubuntu Xvnc 2>/dev/null || true
sleep 1

VNC_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)

# Set password via pipe (the documented method)
echo -e "${VNC_PASS}\n${VNC_PASS}\n" | kasmvncpasswd -u ubuntu -wo

# Verify it was created
if [ -f ~/.kasmpasswd ]; then
  echo "  -> ~/.kasmpasswd OK ($(wc -c < ~/.kasmpasswd) bytes)"
  ls -la ~/.kasmpasswd
else
  echo "  -> ERROR: ~/.kasmpasswd missing"
  exit 1
fi

# Save plaintext for user retrieval
echo "${VNC_PASS}" > ~/.vnc/password.txt
chmod 600 ~/.vnc/password.txt

# (Re)start service
sudo systemctl daemon-reload
sudo systemctl restart kasmvnc.service
sleep 6

echo "  -> service status"
sudo systemctl status kasmvnc.service --no-pager | head -15 || true

echo "  -> port 6901"
ss -lnt | grep :6901 || echo "  not listening"

echo "  -> probe"
curl -sI http://127.0.0.1:6901 2>&1 | head -5 || true

echo ""
echo "============================================="
echo "  KasmVNC password (SAVE THIS):"
echo "  ${VNC_PASS}"
echo "============================================="
echo "  URL: https://vnc.egulcloud.com"
echo "  Username: ubuntu"
echo "  Password: (above) — also at ~/.vnc/password.txt"

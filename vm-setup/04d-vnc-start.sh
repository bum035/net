#!/bin/bash
set -euo pipefail

echo "==> [4d] Restart KasmVNC with corrected config"

# Kill any leftovers
sudo systemctl stop kasmvnc.service 2>/dev/null || true
pkill -9 -u ubuntu Xvnc 2>/dev/null || true
pkill -9 -u ubuntu kasmvncserver 2>/dev/null || true
sleep 2

# Deploy corrected kasmvnc.yaml
cp ~/kasmvnc.yaml ~/.vnc/kasmvnc.yaml

# Validate config
echo "  -> validate config (manual run)"
/usr/bin/kasmvncserver :1 -depth 24 -geometry 1920x1080 2>&1 | head -20 &
sleep 5

echo "  -> ports"
ss -lnt | grep -E ':(59|69)' || echo "  none"
echo "  -> processes"
ps aux | grep -E 'Xvnc|kasmvnc' | grep -v grep | head -10

echo "  -> kill manual run"
/usr/bin/kasmvncserver -kill :1 2>&1 | head -3
pkill -u ubuntu Xvnc 2>/dev/null || true
sleep 2

echo "  -> restart systemd service"
sudo systemctl daemon-reload
sudo systemctl restart kasmvnc.service
sleep 6

echo "  -> service status"
sudo systemctl status kasmvnc.service --no-pager | head -15

echo "  -> ports"
ss -lnt | grep -E ':(59|69)' || echo "  WARN: no VNC ports"

echo "  -> probe local"
curl -sI http://127.0.0.1:6901 | head -3 || true

echo "  -> probe via Caddy"
curl -sI https://vnc.egulcloud.com | head -3 || true

#!/bin/bash
set -euo pipefail

echo "==> [4b] Finish KasmVNC: password + systemd"

# Disable any display manager
sudo systemctl disable lightdm 2>/dev/null || true
sudo systemctl disable gdm3   2>/dev/null || true
sudo systemctl mask    lightdm 2>/dev/null || true

mkdir -p ~/.vnc

echo "  -> kill any running vnc"
/usr/bin/kasmvncserver -kill :1 2>/dev/null || true
pkill -u ubuntu Xvnc 2>/dev/null || true
sleep 1

echo "  -> set VNC password (via expect)"
VNC_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)
export VNC_PASS

# Use expect to drive the interactive password prompt.
expect <<'EXPECT_EOF'
log_user 1
set timeout 30
set vnc_pass $env(VNC_PASS)
spawn kasmvncpasswd -u ubuntu -wo
expect {
  -re "(?i)password" { send "$vnc_pass\r"; exp_continue }
  -re "(?i)verify"   { send "$vnc_pass\r"; exp_continue }
  -re "(?i)confirm"  { send "$vnc_pass\r"; exp_continue }
  -re "(?i)retype"   { send "$vnc_pass\r"; exp_continue }
  eof
}
EXPECT_EOF

echo "${VNC_PASS}" > ~/.vnc/password.txt
chmod 600 ~/.vnc/password.txt

echo "  -> verify password file"
ls -la ~/.kasmpasswd 2>/dev/null || ls -la ~/.vnc/passwd 2>/dev/null || echo "  WARN: no kasmpasswd file"

echo "  -> create system kasmvnc.service"
sudo tee /etc/systemd/system/kasmvnc.service >/dev/null <<'UNIT'
[Unit]
Description=KasmVNC Server (XFCE for ubuntu)
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=ubuntu
Group=ubuntu
PAMName=login
WorkingDirectory=/home/ubuntu
Environment=HOME=/home/ubuntu
Environment=USER=ubuntu
Environment=LANG=en_US.UTF-8
ExecStart=/usr/bin/kasmvncserver -depth 24 -geometry 1920x1080 :1
ExecStop=/usr/bin/kasmvncserver -kill :1
PIDFile=/home/ubuntu/.vnc/ubuntu:1.pid
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

echo "  -> enable + start"
sudo systemctl daemon-reload
sudo systemctl enable kasmvnc.service
sudo systemctl restart kasmvnc.service
sleep 6

echo "  -> service status"
sudo systemctl status kasmvnc.service --no-pager | head -20 || true

echo "  -> port 6901 listening?"
ss -lnt | grep :6901 || echo "  WARN: 6901 not listening"

echo "  -> local probe"
curl -sI http://127.0.0.1:6901 2>&1 | head -5 || true

echo "  -> last 20 log lines"
sudo journalctl -u kasmvnc.service --no-pager -n 20 || true

echo ""
echo "==> [4b] DONE"
echo "============================================="
echo "  KasmVNC password (SAVE THIS):"
echo "  ${VNC_PASS}"
echo "============================================="
echo "  URL: https://vnc.egulcloud.com"
echo "  Username: ubuntu"
echo "  Password file: ~/.vnc/password.txt"

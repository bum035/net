#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [4/7] XFCE desktop + KasmVNC"

echo "  -> install XFCE + Firefox + expect (no display manager)"
sudo apt-get install -y -qq --no-install-recommends \
  xfce4 xfce4-goodies xfce4-terminal \
  dbus-x11 \
  fonts-noto fonts-noto-color-emoji \
  expect xclip xsel

sudo apt-get install -y -qq firefox

# Disable any display manager that may have been pulled in
sudo systemctl disable lightdm 2>/dev/null || true
sudo systemctl disable gdm3   2>/dev/null || true
sudo systemctl mask    lightdm 2>/dev/null || true

echo "  -> install KasmVNC ${KASM_VERSION:=1.3.3}"
KASM_DEB="kasmvncserver_jammy_${KASM_VERSION}_amd64.deb"
if ! command -v kasmvncserver >/dev/null 2>&1; then
  cd /tmp
  curl -fsSL -o "${KASM_DEB}" \
    "https://github.com/kasmtech/KasmVNC/releases/download/v${KASM_VERSION}/${KASM_DEB}"
  sudo apt-get install -y -qq "./${KASM_DEB}"
  rm -f "${KASM_DEB}"
else
  echo "  -> KasmVNC already installed"
fi

# Allow ubuntu to read SSL bits if any
sudo usermod -aG ssl-cert ubuntu || true

echo "  -> deploy ~/.vnc/{xstartup, kasmvnc.yaml}"
mkdir -p ~/.vnc
cp ~/xstartup       ~/.vnc/xstartup
cp ~/kasmvnc.yaml   ~/.vnc/kasmvnc.yaml
chmod +x ~/.vnc/xstartup

echo "  -> set VNC password (via expect)"
VNC_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)
export VNC_PASS

# kasmvncpasswd is interactive; use expect
expect <<EXPECT_EOF
log_user 0
set timeout 30
spawn kasmvncpasswd -u ubuntu -wo
expect {
  "*assword:" { send "$env(VNC_PASS)\r"; exp_continue }
  "*erify:"   { send "$env(VNC_PASS)\r"; exp_continue }
  "*:"        { send "$env(VNC_PASS)\r"; exp_continue }
  eof
}
EXPECT_EOF

# Save password locally for user to look up
echo "${VNC_PASS}" > ~/.vnc/password.txt
chmod 600 ~/.vnc/password.txt

echo "  -> system kasmvnc.service"
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

# Stop any running kasmvnc started during password set
/usr/bin/kasmvncserver -kill :1 2>/dev/null || true
sleep 1

echo "  -> enable + start kasmvnc.service"
sudo systemctl daemon-reload
sudo systemctl enable kasmvnc.service
sudo systemctl restart kasmvnc.service
sleep 5

echo "  -> service status"
sudo systemctl status kasmvnc.service --no-pager | head -15 || true

echo "  -> port 6901 listening?"
ss -lnt | grep :6901 || echo "  WARN: 6901 not listening yet"

echo "  -> local probe"
curl -sI http://127.0.0.1:6901 | head -3 || true

echo ""
echo "==> [4/7] DONE"
echo "============================================="
echo "  KasmVNC password (SAVE THIS):"
echo "  ${VNC_PASS}"
echo "============================================="
echo "  URL: https://vnc.egulcloud.com"
echo "  Username: ubuntu"
echo "  Password file: ~/.vnc/password.txt (chmod 600)"

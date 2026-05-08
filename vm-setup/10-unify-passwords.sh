#!/bin/bash
set -euo pipefail

PASS="Bumbayar_8084"

echo "==> [10] Unify all passwords to Bumbayar_8084 (user=ubuntu)"

echo "  -> 1) SSH password (ubuntu user)"
echo "ubuntu:${PASS}" | sudo chpasswd
echo "${PASS}" > ~/.ssh-password.txt
chmod 600 ~/.ssh-password.txt

echo "  -> 2) code-server password (~/.config/code-server/config.yaml)"
# Replace password line; rest of YAML unchanged
sed -i "s|^password:.*|password: ${PASS}|" ~/.config/code-server/config.yaml
chmod 600 ~/.config/code-server/config.yaml
sudo systemctl restart code-server@ubuntu
sleep 3
systemctl is-active code-server@ubuntu

echo "  -> 3) KasmVNC password (~/.kasmpasswd via pipe)"
# Stop service so password file isn't held open
sudo systemctl stop kasmvnc.service 2>/dev/null || true
pkill -9 -u ubuntu Xvnc 2>/dev/null || true
sleep 2

# Set new password (kasmvncpasswd documented stdin pipe)
echo -e "${PASS}\n${PASS}\n" | kasmvncpasswd -u ubuntu -wo

echo "${PASS}" > ~/.vnc/password.txt
chmod 600 ~/.vnc/password.txt

# Cleanup any X locks (avoids "X server already running")
sudo rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 ~/.vnc/*.pid

# Restart KasmVNC
sudo systemctl start kasmvnc.service
sleep 6
systemctl is-active kasmvnc.service

echo ""
echo "============================================="
echo "  Бүх хэрэгсэлд:"
echo "    Username: ubuntu"
echo "    Password: ${PASS}"
echo "============================================="
echo ""
echo "  Verify:"
echo "  • SSH:        ssh ubuntu@vnc.egulcloud.com"
echo "  • code-server: https://code.egulcloud.com"
echo "  • KasmVNC:    https://vnc.egulcloud.com"
echo ""
echo "  Saved files (chmod 600):"
echo "    ~/.ssh-password.txt"
echo "    ~/.config/code-server/config.yaml"
echo "    ~/.vnc/password.txt"
echo "    ~/.kasmpasswd       (bcrypt hash)"

echo ""
echo "  -> sshd password auth still effective:"
sudo sshd -T 2>/dev/null | grep -E '^(passwordauthentication|pubkeyauth)\b'

echo ""
echo "  -> Verifications:"
echo "  code-server config:"
grep '^password:' ~/.config/code-server/config.yaml
echo "  KasmVNC service:"
sudo systemctl status kasmvnc.service --no-pager | head -5
echo "  Ports:"
ss -lnt | grep -E ':(22|80|443|6901|8080)\b'

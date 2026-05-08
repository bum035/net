#!/bin/bash
set -euo pipefail

echo "==> [9] Enable SSH password auth + set ubuntu password"

# Generate password using openssl + bash substitution (no pipes -> no SIGPIPE)
RAW=$(openssl rand -base64 32)
# Strip ambiguous + URL chars
CLEAN="${RAW//[\/+=O0Il1]/}"
PASS="${CLEAN:0:16}"

echo "  -> set ubuntu password"
echo "ubuntu:${PASS}" | sudo chpasswd

# Save (chmod 600)
echo "${PASS}" > ~/.ssh-password.txt
chmod 600 ~/.ssh-password.txt

echo "  -> backup current sshd_config"
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%s)

echo "  -> existing sshd_config.d files"
sudo ls -la /etc/ssh/sshd_config.d/ || true

echo "  -> existing relevant settings"
sudo grep -EH '^[#\s]*(PasswordAuthentication|KbdInteractive|ChallengeResponse|UsePAM)' \
  /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true

# Drop a single override (Ubuntu's default 50-cloud-init.conf disables password auth)
echo "  -> deploy /etc/ssh/sshd_config.d/99-password.conf"
sudo tee /etc/ssh/sshd_config.d/99-password.conf >/dev/null <<'CONF'
# Olympiad backup access — password auth enabled (overrides 50-cloud-init.conf)
PasswordAuthentication yes
KbdInteractiveAuthentication yes
PubkeyAuthentication yes
PermitRootLogin prohibit-password
UsePAM yes
CONF

echo "  -> validate sshd config"
sudo sshd -t

echo "  -> restart sshd (existing SSH session persists)"
sudo systemctl restart ssh
sleep 2
sudo systemctl is-active ssh

echo "  -> effective settings"
sudo sshd -T 2>/dev/null | grep -E '^(passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication)\b'

echo ""
echo "============================================="
echo "  SSH password (SAVE THIS):"
echo "  Username: ubuntu"
echo "  Password: ${PASS}"
echo "============================================="
echo "  Saved at: ~/.ssh-password.txt"
echo ""
echo "  Тест:"
echo "    ssh ubuntu@vnc.egulcloud.com"

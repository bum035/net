#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/7] System base setup"

echo "  -> apt update + upgrade"
sudo apt-get update -qq
sudo apt-get upgrade -y -qq \
  -o Dpkg::Options::=--force-confdef \
  -o Dpkg::Options::=--force-confold

echo "  -> install essentials"
sudo apt-get install -y -qq \
  tmux git curl wget vim htop ncdu tree jq unzip zip rsync \
  ufw fail2ban \
  build-essential pkg-config \
  python3-pip python3-venv \
  ipcalc netcat-openbsd dnsutils nmap traceroute mtr-tiny iputils-ping \
  ca-certificates apt-transport-https software-properties-common \
  gnupg lsb-release

echo "  -> UFW firewall"
sudo ufw default deny incoming >/dev/null
sudo ufw default allow outgoing >/dev/null
sudo ufw allow 22/tcp comment 'SSH' >/dev/null
sudo ufw allow 80/tcp comment 'HTTP (Caddy)' >/dev/null
sudo ufw allow 443/tcp comment 'HTTPS (Caddy)' >/dev/null
sudo ufw --force enable >/dev/null
echo "  UFW status:"
sudo ufw status numbered

echo "  -> fail2ban enable"
sudo systemctl enable --now fail2ban
sudo systemctl is-active fail2ban

echo "  -> timezone Asia/Ulaanbaatar"
sudo timedatectl set-timezone Asia/Ulaanbaatar
date

echo "==> [1/7] DONE"

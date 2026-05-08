#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [2/7] Caddy + HTTPS"

if ! command -v caddy >/dev/null 2>&1; then
  echo "  -> add Caddy repo"
  sudo curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null

  sudo apt-get update -qq
  sudo apt-get install -y -qq caddy
else
  echo "  -> Caddy already installed: $(caddy version)"
fi

echo "  -> deploy Caddyfile"
sudo cp ~/Caddyfile /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile

echo "  -> reload Caddy"
sudo systemctl enable caddy
sudo systemctl restart caddy
sleep 3
sudo systemctl status caddy --no-pager | head -20

echo "==> [2/7] DONE"
echo "  Caddy will obtain Let's Encrypt cert in background."
echo "  Check progress: sudo journalctl -u caddy -f"

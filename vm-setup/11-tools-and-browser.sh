#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [11] GUI apps + extra CLI tools"

echo "  -> 1) Google Chrome (deb, no snap)"
if ! command -v google-chrome >/dev/null 2>&1; then
  cd /tmp
  curl -fsSL -o chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt-get install -y -qq ./chrome.deb
  rm -f chrome.deb
fi
echo "    Chrome: $(google-chrome --version 2>&1 | head -1)"

echo "  -> 2) Firefox (Mozilla PPA, deb — snap-аас зайлсхийсэн)"
if ! command -v firefox >/dev/null 2>&1 || dpkg -l firefox 2>/dev/null | grep -q '1snap'; then
  # Remove snap-transitional Firefox if present
  sudo apt-get remove -y -qq firefox 2>/dev/null || true
  # Add Mozilla PPA
  sudo add-apt-repository -y ppa:mozillateam/ppa
  # Pin Mozilla PPA so it's preferred over the snap transition package
  sudo tee /etc/apt/preferences.d/mozilla-firefox >/dev/null <<'PIN'
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
PIN
  sudo apt-get update -qq
  sudo apt-get install -y -qq firefox
fi
echo "    Firefox: $(firefox --version 2>&1 | head -1)"

echo "  -> 3) Wireshark + tcpdump (non-root capture allowed)"
echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
sudo apt-get install -y -qq wireshark tshark tcpdump
sudo usermod -aG wireshark ubuntu || true
echo "    Wireshark: $(wireshark --version 2>&1 | head -1)"

echo "  -> 4) PDF viewers (evince + okular-mini)"
sudo apt-get install -y -qq evince poppler-utils

echo "  -> 5) meld (visual diff)"
sudo apt-get install -y -qq meld

echo "  -> 6) LibreOffice (calc + writer + impress)"
sudo apt-get install -y -qq --no-install-recommends \
  libreoffice-calc libreoffice-writer libreoffice-impress libreoffice-gtk3 \
  libreoffice-l10n-en-us hunspell-en-us

echo "  -> 7) PuTTY (familiar SSH/telnet GUI)"
sudo apt-get install -y -qq putty putty-tools

echo "  -> 8) Network tools (iperf3, net-tools, mtr-tiny, lsof, hping3)"
sudo apt-get install -y -qq iperf3 net-tools lsof hping3 socat \
  iputils-tracepath traceroute arp-scan

echo "  -> 9) CLI productivity (fzf, tldr, ranger, ncdu, btop, neovim, zsh)"
sudo apt-get install -y -qq fzf tldr ranger ncdu neovim zsh
# btop (modern htop) — packaged in 22.04 universe? Check
sudo apt-get install -y -qq btop || echo "    btop not in repos, skip"
tldr --update 2>/dev/null || true

echo "  -> 10) mosh (mobile shell — survives connection drops)"
sudo apt-get install -y -qq mosh

echo "  -> 11) image viewers + screenshot"
sudo apt-get install -y -qq feh eog gimp xfce4-screenshooter flameshot

echo "  -> 12) archive tools (7z, rar)"
sudo apt-get install -y -qq p7zip-full p7zip-rar unrar

echo "  -> 13) graphviz + drawio (network diagrams)"
sudo apt-get install -y -qq graphviz xdot

echo "  -> 14) git tools (gitg GUI, tig)"
sudo apt-get install -y -qq gitg tig

echo "  -> 15) text/format tools (jq, yq already; xmlstarlet, csvkit, miller)"
sudo apt-get install -y -qq xmlstarlet
pip3 install --user --quiet csvkit miller-py 2>/dev/null || true

echo ""
echo "==> [11] DONE"
echo ""
echo "Шалгах:"
which google-chrome firefox wireshark evince meld libreoffice putty iperf3 mosh
echo ""
echo "Disk usage:"
df -h / | tail -1

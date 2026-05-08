#!/bin/bash
set -euo pipefail

echo "==> [7/7] Clone repos + final wiring"

cd ~

echo "  -> set up git config (skip if you've configured globally)"
if ! git config --global user.email >/dev/null; then
  git config --global user.email "bumabuma035@gmail.com"
  git config --global user.name "Bumbayar"
  git config --global init.defaultBranch main
fi

# Note: actual repo URLs depend on user's GitHub. We'll use placeholders.
# User must run this section interactively or after setting GitHub auth.

echo ""
echo "  ⚠ Repo clone-ыг гараар хийнэ үү — auth шаардлагатай:"
echo ""
echo "    cd ~"
echo "    # Hint: Use 'gh auth login' first, then:"
echo "    git clone https://github.com/<USER>/network_olymp.git"
echo "    git clone https://github.com/bum035/net.git net"
echo ""
echo "  Эсвэл SSH key-ээр (~/.ssh/id_ed25519 түлхүүрийг GitHub-руу нэмсэн бол):"
echo "    git clone git@github.com:<USER>/network_olymp.git"
echo "    git clone git@github.com:bum035/net.git net"
echo ""

echo "  -> install GitHub CLI for easier auth"
if ! command -v gh >/dev/null 2>&1; then
  type -p curl >/dev/null
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq gh
fi

echo "  -> gh version: $(gh --version | head -1)"

echo ""
echo "==> [7/7] DONE"
echo ""
echo "============================================="
echo "ПРЕ-FLIGHT CHECK"
echo "============================================="
echo ""
echo "  https://code.egulcloud.com → code-server (login: ~/.config/code-server/config.yaml)"
echo "  https://vnc.egulcloud.com  → KasmVNC web (login: ubuntu / ~/.vnc/password.txt)"
echo "  ssh -i ./id_ed25519 ubuntu@vnc.egulcloud.com → tmux/CLI"
echo ""
echo "Saved at: ~/.config/code-server/config.yaml, ~/.vnc/password.txt"

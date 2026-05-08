#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [6/7] tmux config + network/Cisco tools"

echo "  -> deploy ~/.tmux.conf"
cp ~/tmux.conf ~/.tmux.conf

echo "  -> Python: netmiko, ciscoconfparse, paramiko, ttp, napalm"
pip3 install --user --quiet \
  netmiko \
  ciscoconfparse2 \
  paramiko \
  ttp \
  napalm \
  pyshark \
  rich \
  bcrypt \
  jinja2

echo "  -> install jq, yq, ripgrep, fd, bat, htop"
sudo apt-get install -y -qq ripgrep fd-find bat tree

# Install yq (binary)
if ! command -v yq >/dev/null 2>&1; then
  sudo curl -fsSL -o /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
  sudo chmod +x /usr/local/bin/yq
fi

echo "  -> create persistent tmux session bootstrap"
cat > ~/start-olymp-session.sh <<'BOOT'
#!/bin/bash
# Re-attach if exists, else create
if tmux has-session -t olymp 2>/dev/null; then
  tmux attach -t olymp
else
  tmux new -d -s olymp -n claude  -c "$HOME/olymp-day"
  tmux new-window -t olymp -n shell -c "$HOME/olymp-day"
  tmux new-window -t olymp -n monitor 'htop'
  tmux select-window -t olymp:claude
  tmux attach -t olymp
fi
BOOT
chmod +x ~/start-olymp-session.sh

echo "  -> create ~/olymp-day workspace"
mkdir -p ~/olymp-day/{lab-01-ospf,lab-02-bgp,lab-03-vpc,lab-04-vpn,lab-05-libre,scratch}
cat > ~/olymp-day/CLAUDE.md <<'CLAUDE'
# Олимпиадын ажлын орчин (2026-05-09)

Та сүлжээний олимпиадад тусалдаг туслах. Бэлэн байх:
- Cisco IOS, IOS-XE, IOS-XR, NX-OS config-уудыг ойлгох
- BGP, OSPF, vPC, GRE+IPSec, SNMP, LibreNMS troubleshooting
- Output товч — config block + 1-2 өгүүлбэрийн тайлбар

## Лабын folder-ууд

- `lab-01-ospf/` — OSPF Multi-area + VRF FinDep + Redistribution (17%)
- `lab-02-bgp/` — BGP Full Stack: iBGP RR + eBGP + TE (20%)
- `lab-03-vpc/` — NX-OS vPC + MCLAG (10%)
- `lab-04-vpn/` — GRE + IPSec VPN IKEv2 (9%)
- `lab-05-libre/` — LibreNMS + SNMPv2 + Pre-broken Troubleshoot (45%)

## Reference материал

- `~/network_olymp/04_eve_ng_material/labs/topologies/lab-NN.pdf` — лаб бүрийн дэлгэрэнгүй
- `~/network_olymp/2024_eve-ng_task_doing/` — 2024 round 2 reference
- `~/net/secureCRT/VanDyke/Config/` — SecureCRT button bar, snippets, sessions

## Workflow

SecureCRT-аас config-ыг clipboard-аар авах → энд paste → Claude-аас засвар хүсэх → засварсан config-ыг буцаагаад SecureCRT-руу.

CLAUDE

echo "==> [6/7] DONE"
echo ""
echo "  Workspace: ~/olymp-day/"
echo "  tmux start: ~/start-olymp-session.sh"

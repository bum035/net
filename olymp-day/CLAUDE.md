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

- `../reference/` — AI prompt templates + offline cheatsheet (бэлдэж буй)
- `../reference/lab-NN.pdf` — лаб бүрийн дэлгэрэнгүй (placeholder, олимпиадын өмнө хуулна)
- `../reference/2024_round2/` болон `../reference/2025_round2/` — өмнөх жилийн config (placeholder)
- `../secureCRT/VanDyke/Config/` — SecureCRT button bar, snippets, sessions
- `../scripts/start-olymp-session.sh` — tmux bootstrap (`bash ~/net/scripts/start-olymp-session.sh`)

## Workflow

SecureCRT-аас config-ыг clipboard-аар авах → энд paste → Claude-аас засвар хүсэх → засварсан config-ыг буцаагаад SecureCRT-руу.


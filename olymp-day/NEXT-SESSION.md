# Next Claude session — pickup notes (2026-05-09)

> Session timeline:
> - 11:00–11:35 — config татах (corp-dsw01/02, Fusion-rtr01/02, wan-rtr01/02, dc-esw01, corp-esw01/02, CorpSW-3)
> - 12:00–12:30 — даалгаврын текст fetch (`http://36.50.7.44:3000/tasks`), config diagnose, **TASKS.md + FINDINGS.md** үүсгэв.
>
> **Дараагийн session:** TASKS.md-н priority order-оор fix хийж push, verify.

## Шуурхай файл (read-first)

| # | Файл | Зориулалт |
|---|---|---|
| 1 | [`lab2025/TASKS.md`](lab2025/TASKS.md) | 19 даалгаврын бүрэн skeleton (config block, шалгуур) |
| 2 | [`lab2025/FINDINGS.md`](lab2025/FINDINGS.md) | Running-config-аас олсон bugs + priority order |
| 3 | [`CLAUDE.md`](CLAUDE.md) | Сэдвийн context + AI guardrails |
| 4 | [`lab2025/lab-summary.md`](lab2025/lab-summary.md) | Топологи, IP plan |

## EVE-NG нэвтрэх

```
Web UI:   http://36.50.7.52:40117/
Login:    admin / i@m}Q}!*%NV    (file: olymp-day/lab2025/olympiad.conf)
Lab:      /lab2025.unl
```

⚠ **40117 портоор л холбогдоно** — console (32769-32788) firewalled. HTML5 Guacamole-аар л.
⚠ **API-аас бичих оролдлого ХИЙХГҮЙ** — lab lock конфликт.

## Daалгаврын төлөв (live tracking)

| # | Task | Owner | Pts | Type | Status |
|---|---|---|---|---|---|
| 1 | iBGP | Ulsaa | 3 | Trbl | ⏳ Diagnosed (wan-rtr01 Lo2 OSPF advertise) |
| 2 | BGP-1 | Ulsaa | 2 | Impl | ⏳ Skeleton ready |
| 3 | BGP-2 | Ulsaa | 3 | Impl | ⏳ Skeleton ready |
| 4 | BGP-3 | Ulsaa | 4 | Impl | ⏳ Skeleton ready |
| 5 | VRRP | Altai | 2 | Impl | ⏳ Diagnosed (track+decrement) |
| 6 | OSPF-1 | Altai | 2 | Trbl | ⏳ TBD per VRF cover |
| 7 | OSPF-2 | Altai | 3 | Impl | ⏳ Diagnosed (passive default) |
| 8 | OSPF-3 | Altai | 2 | Impl | ⏳ Diagnosed (ospfv3 add) |
| 9 | OSPF-4 | Altai | 2 | Impl | ⏳ Diagnosed (originate always) |
| 10 | OSPF-5 | Altai | 3 | Trbl | ⏳ TBD VRF default redist |
| 11 | NAT | Altai | 2 | Trbl | ⏳ Diagnosed (vrf nat rule) |
| 12 | IPsec | Altai | 4 | Impl | ⏳ Br1GW config required |
| 13 | NTP | Byambaa | 2 | Svc | ⏳ Skeleton ready |
| 14 | HSRP | Byambaa | 2 | Svc | ⏳ Diagnosed (Lo5 shutdown) |
| 15 | TCLSH | Byambaa | 2 | DevOps | ⏳ Skeleton ready |
| 16 | OSPF-6 | Byambaa | 2 | Trbl | ⏳ **md5 key typo found** (l vs I) |
| 17 | TFTP-1 | Byambaa | 2 | Svc | ⏳ copy tftp |
| 18 | TFTP-2 | Byambaa | 2 | Impl | ⏳ EEM applet |
| 19 | STP | Byambaa | 2 | Trbl | ⏳ **Diagnosed (guard root)** |

## Хийх ажил — recommended order

1. **Pre-checks (5 мин):**
   - `show ip ospf neighbor` бүх router дээр (Fusion, wan, corp-dsw)
   - `show ip bgp summary` wan-rtr01/02
   - `show standby brief` corp-dsw01/02
2. **Quick wins (15 мин, 6 pts):**
   - **STP** (corp-esw02 Eth0/1 `no spanning-tree guard root`) — 1 line.
   - **OSPF-6** (vlan1020 md5 key унификаци) — 2 line.
   - **OSPF-2** (Fusion-rtr01 passive-default) — 3 line.
3. **Routing шийдэлтэй (45 мин, 13 pts):**
   - **iBGP** → wan-rtr01 Lo2 advertise.
   - **OSPF-3** → corp-dsw02 ospfv3 нэмэх.
   - **OSPF-4** → wan ospfv3 default originate always.
   - **OSPF-5** → VRF default route.
   - **OSPF-1** → VRF network coverage.
4. **Service / DevOps (30 мин, 8 pts):**
   - **NTP**, **HSRP**, **TCLSH**, **TFTP-1/2**.
5. **VRRP** (10 мин, 2 pts) — track + decrement.
6. **NAT** (15 мин, 2 pts) — VRF-aware.
7. **BGP advanced** (45 мин, 9 pts):
   - **BGP-1** announce.
   - **BGP-2** ISP-A primary.
   - **BGP-3** community.
8. **IPsec** (30 мин, 4 pts) — Br1GW + GW-1 IKEv2 + transform + tunnel.

## Useful command (Claude-д)

```bash
# Бүх config-уудыг hostname харах
cd /home/ubuntu/net/olymp-day/config
for f in *.cfg; do echo "==== $f ===="; grep -m1 "^hostname" "$f"; done

# Md5 key typo шалгах
grep -rn "message-digest-key" /home/ubuntu/net/olymp-day/config/

# OSPF passive-interface харах
grep -rn -A1 "router ospf" /home/ubuntu/net/olymp-day/config/

# VRRP / HSRP track шалгах
grep -rnE "(vrrp|standby).*(track|priority)" /home/ubuntu/net/olymp-day/config/

# Diff CorpGW-1 vs CorpGW-2 (зөв байр шилжүүлсэн)
diff /home/ubuntu/net/olymp-day/config/CorpGW-1.cfg /home/ubuntu/net/olymp-day/config/CorpGW-2.cfg
```

## Анхаар: AI hallucination

- IOS syntax — deprecated keyword (`ip cef enable`, `frame-relay map`) AI-аас гарч магад. Олимпиадын legacy IOSv 15.x.
- AI VRF-aware NAT-ыг буруу гаргадаг — `ip nat inside source list ACL pool POOL **match-in-vrf**` (IOS-XE) vs `... vrf FinDep` (IOS) — таних.
- IKEv2 vs IKEv1 — олимпиад "site-to-site VPN" гэвэл аль 2 нь зөв; шалгуурын тэмдэглэлийг анхаарал гаргаж уншина.

## Хост нэр map (даалгавар vs config)

| Даалгаварт | Configs | EVE label |
|---|---|---|
| CorpGW router 1 / 2 | corp-dsw01 / corp-dsw02 | CorpGW-1 / CorpGW-2 |
| Fusion router #1 / #2 | Fusion-rtr01 / Fusion-rtr02 | Fusion_Router-1 / -2 |
| Wan router #1 / #2 | wan-rtr01 / wan-rtr02 | GW-1 / GW-2 |
| Corp-esw01..03 | corp-esw01, corp-esw02, CorpSW-3 | CorpSW-1/2/3 |
| Br1GW (BranchGW) | (config татагдаагүй) | Br1GW |

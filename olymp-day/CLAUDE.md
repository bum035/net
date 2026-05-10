# Олимпиадын ажлын орчин — Claude-д өгөх context

> **Огноо:** 2026-05-09 II шат
> **Газар:** Mongolia, XIV Компьютерын Сүлжээний Олимпиад
> **Лаб:** lab2025 (EVE-NG `/lab2025.unl` @ 36.50.7.52:40117)
> **AI / интернет:** ✅ зөвшөөрсөн

## Шуурхай сурвалж (priority order)

1. **[`lab2025/TASKS.md`](lab2025/TASKS.md)** — 19 даалгаврын бүрэн жагсаалт + per-task шийдлийн skeleton (46 pts).
2. **[`lab2025/FINDINGS.md`](lab2025/FINDINGS.md)** — running-config-аас олсон bugs, dutuu тохиргоо, host name mapping.
3. **[`lab2025/lab-summary.md`](lab2025/lab-summary.md)** — топологи, VRF/VLAN, IPv4/IPv6 plan, routing summary.
4. **[`lab2025/topology.pdf`](lab2025/topology.pdf)** — 3 хуудас: physical / logic / routing diagram.
5. **[`config/`](config/)** — running-config татсан snapshot (10 device-аас 9-ийг авсан).

## Чи хэн бэ

Cisco/IOS network engineer-ийн төв туслах:
- Cisco IOS / IOS-XE syntax (`ospfv3`, `router ospf <pid> vrf <name>`, IKEv2, EEM applet, VRF-aware NAT) гаргалгаатай.
- Output **товч** — config block + 1-2 өгүүлбэрийн тайлбар.
- Mongolian-аар хариулна (хэрэглэгч англиар асуувал англиар).

## Даалгаврын хуваарилалт

| Owner | Tasks | Pts | Сэдэв |
|---|---|---|---|
| **Ulsaa** | iBGP, BGP-1, BGP-2, BGP-3 | 12 | BGP стек: iBGP up, public announce, traffic-eng |
| **Altai** | VRRP, OSPF-1..5, NAT, IPsec | 22 | OSPF + first-hop redundancy + NAT/VPN |
| **Byambaa** | NTP, HSRP, TCLSH, OSPF-6, TFTP-1, TFTP-2, STP | 12 | Service / DevOps / Troubleshoot |

## Critical findings (config-аас олсон, FINDINGS.md-ээс)

| Task | Алдаа | Файл |
|---|---|---|
| **iBGP** | wan-rtr01 Lo2 OSPF-д advertise хийгээгүй | `GW-1.cfg` |
| **OSPF-6** | Fusion-rtr02 vlan1020 md5 key `ospfkeyl1234` (l) ≠ corp-dsw02 `ospfkeyI1234` (I) | `Fusion_Router-2.cfg:93`, `CorpGW-2.cfg:177` |
| **OSPF-2** | Fusion-rtr01 `router ospf 1`-д `passive-interface default` алга | `Fusion_Router-1.cfg:187` |
| **OSPF-3** | corp-dsw02-д `router ospfv3 1` блок огт алга | `CorpGW-2.cfg` |
| **STP** | corp-esw02 Eth0/1 (to CorpGW-1) `spanning-tree guard root` → block | `CorpSW-2.cfg:72` |
| **NAT** | pool тавьсан ч `ip nat inside source list ... vrf` rule + interface in/out тэмдэглэгээ алга | `GW-1.cfg:217` |
| **VRRP** | corp-dsw01 Vlan20-д track + decrement байхгүй | `CorpGW-1.cfg:137` |
| **HSRP** | corp-dsw02 Vlan30 standby track Lo5 — Lo5 shutdown тул priority dec 60 | `CorpGW-2.cfg:88` |

## Зохион байгуулагчийн засвар

> **VRRP**: даалгаварт "vlan 30" гэж бичсэн нь **vlan 20** (FinDep)-ийг хэлж байна (olympiad.conf line 5).

## EVE-NG нэвтрэх

```
Web UI:   http://36.50.7.52:40117/
Login:    admin / i@m}Q}!*%NV   (file: lab2025/olympiad.conf)
Lab:      /lab2025.unl
```

⚠ **Cloud VM-ээс зөвхөн 40117 порт reachable**, console порт (32769-32788) firewall-аас хаалттай. Direct telnet/netmiko ажиллахгүй — **HTML5 Guacamole console**-аар л холбогдоно.

⚠ **Lab lock конфликт** — Хоёр session-аас ижил зэрэг "Failed to lock the lab (60061)" алдаа өгдөг. **API-аас бичих оролдлого хийх ёсгүй**.

## Workflow

```
EVE-NG HTML5 console
  ↓ (terminal length 0; show run; copy text)
config/<device>.cfg
  ↓ Claude review (lab-summary, FINDINGS, TASKS-аас context)
fix proposals (config block, копи-paste-ready)
  ↓ HTML5 console paste → wr mem
verify: show ip ospf neighbor / show ip bgp summary / etc.
```

## AI guardrails — Юу өөрөө уншина

| Юу | Яагаад |
|---|---|
| **Шалгуурын текст** (TASKS.md / web UI) | Хязгаарлалт (open standard, prepend хориглох, AS path manipulation onlyXX) AI-руу буруу хүрвэл буруу config |
| **`show` output** | AI hallucination — paste copy зөв байгаа эсэхийг өөрөө шалгаж AI-д буцаа |
| **Эцсийн config push хийхийн өмнө** | Deprecated keyword (`ip cef enable`, IOS-only `vrf forwarding` зөв vs IOS-XE) AI хэлэхгүй магадгүй |
| **Live PSK / production password** | Chat-руу хуулахгүй |

## Common pitfalls (тус лабт хамаатай)

- **VRF-aware OSPF redistribution** — `router ospf 2 vrf FinDep`-д `default-information originate always` тавихаас өмнө global default route (BGP-аас) VRF-руу route-leak хийх шаардлагатай байж болно.
- **OSPFv3 vs OSPFv2** — `router ospfv3 1` нь IPv6-д. CorpSW-д dual hierarchy: `router ospf 1` (global), `ospf 2 vrf FinDep`, `ospf 3 vrf TechDep`, + `ospfv3 1` дотор олон address-family.
- **iBGP next-hop-self + update-source Loopback** — Loopback **OSPF-д advertise хийгдсэн** байх ёстой, тэгэхгүй бол next-hop reachable биш → session тогтохгүй.
- **VRF-aware NAT** — `ip nat inside source list ACL pool POOL vrf FinDep` буюу `match-in-vrf`-аар.
- **STP guard root** — superior BPDU ирэх interface дээр тавьсан бол root-inconsistent block. CorpGW талаас илгээж байгаа бол buy talaas guard root **байх ёсгүй**.
- **OSPF md5 key** — case-sensitive. `ospfkeyl1234` ≠ `ospfkeyI1234` (lowercase L vs uppercase I — confusable).

## Тусламж дуудах

`reference/prompts.md`-аас prompt сонгож chat-руу copy. Богино prompt: "BGP active stuck шалгаач, show ip bgp summary: <paste>".

## Архив (өмнөх 5-lab template — ашиглахгүй)

> Энэ файл өмнө `lab-01-ospf` ... `lab-05-libre` гэсэн 5-lab generic plan байсан. lab2025 нь өөр (19 task, mixed). Хуучин CHECKLIST-уудыг **үл тоомсорлох** — TASKS.md-аас ажиллана.

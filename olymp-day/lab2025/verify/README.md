# Verify — 19 task-ийг хурдан шалгах

> **Workflow (3 алхам, нэг device-д ~30 сек):**
> 1. `cmds/<device>.txt`-ийг бүхэлд нь copy → router console-руу paste
> 2. Console-аас бүх output-ыг select-all + copy
> 3. `output/<device>.txt`-руу paste → save
> 4. Claude-д "verify" гэж хэлэхэд бүх файлыг уншиж `CHECKLIST.md` task бүрд PASS/FAIL гаргана

## Device → Task матриц (priority order)

| Device | Tasks | Tasks count | Critical fixes (FINDINGS-аас) |
|---|---|---|---|
| **wan-rtr01** (GW-1) | iBGP, BGP-1, BGP-2, BGP-3, OSPF-4, NAT, IPsec, TCLSH | 8 | Lo2 OSPF advertise, NAT inside/outside, IKEv2 |
| **wan-rtr02** (GW-2) | iBGP, BGP-1, BGP-3, OSPF-4 | 4 | community + route-map |
| **Fusion-rtr01** | OSPF-2, NTP master | 2 | passive-interface default |
| **Fusion-rtr02** | OSPF-2, OSPF-6, NTP client | 3 | md5 key (l vs I) |
| **corp-dsw01** (CorpGW-1) | VRRP, OSPF-1, OSPF-5 | 3 | track + decrement Vlan20 |
| **corp-dsw02** (CorpGW-2) | OSPF-1, OSPF-3, OSPF-5, OSPF-6, HSRP | 5 | router ospfv3, Lo5 unshut |
| **corp-esw01** | TFTP-2 | 1 | EEM applet |
| **corp-esw02** | STP, TFTP-2 | 2 | no spanning-tree guard root |
| **CorpSW-3** | TFTP-1 | 1 | copy tftp |
| **Br1GW** | IPsec mirror | 1 | tunnel destination 202.43.65.2 |

**Нийт: 19 уникум task, 10 device.**

## Файл байршил

```
verify/
├── README.md          ← энэ файл
├── CHECKLIST.md       ← per-task PASS criteria (claude уншина)
├── cmds/              ← router-руу paste-LUU
│   ├── wan-rtr01.txt
│   ├── wan-rtr02.txt
│   └── ...
└── output/            ← router-аас paste-AAR (хоосон, чи бичнэ)
    ├── wan-rtr01.txt
    └── ...
```

## Хурдан run

```bash
# 1) cmds-аас copy
cat ~/net/olymp-day/lab2025/verify/cmds/wan-rtr01.txt
# (terminal-аас select-all + copy → router console-руу paste)

# 2) router output-ыг output/-руу paste:
code ~/net/olymp-day/lab2025/verify/output/wan-rtr01.txt
# (paste + Ctrl+S)

# 3) Claude-руу:
# "verify wan-rtr01"  →  cmds/CHECKLIST.md-ийн дагуу шалгаж буцаана
# эсвэл: "verify all"  →  бүх output файлыг уншиж 19 task-д PASS/FAIL
```

## Тэмдэглэл

- **Бүх cmd block эхэндээ `terminal length 0`** — pagination байхгүй, output бүхэлдээ хэвлэгдэнэ.
- Output-ыг paste хийхдээ ANSI color escape байгаа бол асуудалгүй — claude-д уншигдана.
- Hostname mismatch: EVE label vs actual hostname (CorpGW-1 = corp-dsw01 г.м.). cmd file-ууд **EVE label**-ийг ашигласан байна.
- Зарим show command IOS version-аас хамаараад байхгүй байж магадгүй (e.g. `show vrrp brief` IOS 15.x-д ажиллаж байгаа бол OK; IOS-XE-д өөр).

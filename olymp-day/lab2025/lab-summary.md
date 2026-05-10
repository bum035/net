# Lab2025 — Олимпиадын даалгаврын summary

> Эх сурвалж: `topology.pdf` (3 хуудас) + `IPv4 address plan.xlsx` + `IPv6 address plan.xlsx`

## Топологи

```
[Corp Users]  [Branch Users]
     │              │
  CorpSW-1/2/3   Br1GW (VRF Globally)
     │             │
  CorpGW-1/2 ──┐   │ IPSec
     │   VRRP/HSRP │
     ▼            ▼
   Fusion-Router-1/2 ── DC-Switch
     │
     ▼
   GW-1/2 (BGP AS 17000) ── eBGP ── ISP-A (AS 18000)
                             └─eBGP─ ISP-B (AS 19000)
                             └────── ISP-A↔ISP-B
                             └────── vIOS/CSR (Mngt)
```

## VRF + VLAN

| Layer | VLAN | Зориулалт | VRF |
|---|---|---|---|
| User | 10 | Corp Mngt | Globally |
| User | 20 | Financial Dept | FinDep |
| User | 30 | Technology Dept | TechDep |
| Trunk(CorpSW↔CorpGW) | 1010 | FinDep transit | Globally |
| Trunk(CorpSW↔CorpGW) | 1020 | FinDep | FinDep |
| Trunk(CorpSW↔CorpGW) | 1030 | TechDep | TechDep |
| CorpGW↔Fusion | 110 | uplink | Globally |
| CorpGW↔Fusion | 120 | NetMgmt | Globally |
| DC-SW | 100 | Internal Zone | Globally |
| DC-SW | 110 | External Zone | Globally |
| DC-SW | 120 | Network Mgmt | Globally |
| Fusion↔GW | 300 | core | Globally |
| Fusion↔GW | 310 | Mgmt | Mngt |
| Br1GW | 1 | Branch | Globally |

## Routing план

| Domain | Protocol | Area/AS | Router-ID |
|---|---|---|---|
| Corp (CorpGW-1/-2) | OSPF | area 10 | Lo2 (Globally), Lo3 (FinDep), Lo4 (TechDep) |
| Backbone (Fusion-1/-2, GW-1/-2) | OSPF | area 0 | Lo2 |
| GW-1↔GW-2 | iBGP | AS 17000 | source Lo2, P2P |
| GW-1↔ISP-A | eBGP | AS 17000 ↔ 18000 | — |
| GW-2↔ISP-B | eBGP | AS 17000 ↔ 19000 | — |
| ISP-A↔ISP-B | eBGP | AS 18000 ↔ 19000 | — |
| Br1GW | Static | — | Lo1 = 10.1.8.1 |
| CorpGW-1↔CorpGW-2 | VRRP/HSRP | — | (User VLANs) |

> ⚠ **ISP-A, ISP-B-д тохиргоо хийхгүй**, гэхдээ peer-ийн config-ыг лав мэдэх хэрэгтэй.

## IPv4 address plan (нэгтгэл)

### User subnets
| VLAN | VRF | Subnet | Gateway | Note |
|---|---|---|---|---|
| 20 (FinDep) | FinDep | 10.1.1.0/24 | 10.1.1.254 | Used |
| 30 (TechDep) | TechDep | 10.1.2.0/24 | 10.1.2.254 | Used |
| — | — | 10.1.3.0/24 | — | Available |
| — | — | 10.1.4.0/22 | — | Available |

### Network device management (Loopback 1, VLAN 10)
| Device | Mgmt IP | Loopback | VRF |
|---|---|---|---|
| CorpSW-1 | 10.1.16.4 | Vlan 10 | Globally |
| CorpSW-2 | 10.1.16.5 | Vlan 10 | Globally |
| CorpSW-3 | 10.1.16.6 | Vlan 10 | Globally |
| CorpGW-1 | 10.1.16.3 | Vlan 10 | Globally |
| CorpGW-2 | 10.1.16.2 | Vlan 10 | Globally |
| Fusion-1 | 10.1.17.3 | Loopback 1 | Globally |
| Fusion-2 | 10.1.17.6 | Loopback 1 | Globally |
| GW-1 | 10.1.17.4 | Loopback 1 | Mngt |
| GW-2 | 10.1.17.5 | Loopback 1 | Mngt |
| Br1GW | 10.1.8.1 | Loopback 1 | Globally |

### Loopback (Router-ID, Lo2-Lo4)
| Device | IP | Loopback | VRF |
|---|---|---|---|
| CorpGW-1 | 10.1.18.1 | Lo2 | Globally |
| CorpGW-1 | 10.1.18.2 | Lo3 | FinDep |
| CorpGW-1 | 10.1.18.3 | Lo4 | TechDep |
| CorpGW-2 | 10.1.18.4 | Lo2 | Globally |
| CorpGW-2 | 10.1.18.5 | Lo3 | FinDep |
| CorpGW-2 | 10.1.18.6 | Lo4 | TechDep |

### ISP & Interconnect
| Block | Subnet | Зориулалт | VRF |
|---|---|---|---|
| ISP-A | 202.43.65.0/30 | HQ (GW-1↔ISP-A) | Globally |
| ISP-A | 202.43.65.4/30 | Branch (Br1GW↔ISP-A) | Globally |
| ISP-B | 103.88.34.0/30 | HQ (GW-2↔ISP-B) | Globally |
| ISP-B | 103.88.34.4/30 | ISP-A↔ISP-B | Globally |

## IPv6 address plan

| Block | Зориулалт |
|---|---|
| 2001:db8::/32 | Internal global |
| 2001:db8:abcd:0012::/64 | Vlan 20 (FinDep) |
| 2001:db8:abcd:0013::/64 | Vlan 30 (TechDep) |
| 2001:db8:abcd:0014::/64 | DC Internal Zone (PortChan 1.100) |
| 2001:db8:abcd:0015::/64 | DC External Zone (PortChan 1.110) |
| 2001:db8:abcd:0016::/64 | DC NetMgmt (PortChan 1.120) |
| 2001:db8:abcd:0017::/64 | Loopback IPs (/128 ranges) |
| 2001:db8:abcd:0018::/64 | P2P interconnects |
| 2001:db9::/32 | ISP-A external |
| 2001:d29::/32 | ISP-B external |

### IPv6 Loopback (Router-IDs)
| Device | IPv6 | Lo | VRF |
|---|---|---|---|
| CorpGW-1 | 2001:db8:abcd:17::1/128 | Lo2 | Globally |
| CorpGW-1 | 2001:db8:abcd:17::2/128 | Lo3 | FinDep |
| CorpGW-1 | 2001:db8:abcd:17::3/128 | Lo4 | TechDep |
| CorpGW-2 | 2001:db8:abcd:17::4/128 | Lo2 | Globally |
| CorpGW-2 | 2001:db8:abcd:17::5/128 | Lo3 | FinDep |
| CorpGW-2 | 2001:db8:abcd:17::6/128 | Lo4 | TechDep |
| ZoneFW | 2001:db8:abcd:17::7/128 | Lo2 | Globally |
| GW-1 | 2001:db8:abcd:17::8/128 | Lo2 | Globally |
| GW-1 | 2001:db8:abcd:17::9/128 | Lo3 | Mngt |
| GW-2 | 2001:db8:abcd:17::10/128 | Lo2 | Globally |
| GW-2 | 2001:db8:abcd:17::11/128 | Lo3 | Mngt |

## Console map (Guacamole HTML5)

Token: `0C3177802A644223584EAB673AC5E009063628190A919456065600ADE2A82AB4`
URL pattern: `http://36.50.7.52:40117/html5/#/client/<base64>?token=<token>`

| # | Device | EVE port | b64 (id\\0c\\0mysql) |
|---|---|---|---|
| 1 | GW-1 | 32776 | MzI3NzYAYwBteXNxbA== |
| 2 | GW-2 | 32777 | MzI3NzcAYwBteXNxbA== |
| 3 | (GW-2 dup) | 32777 | MzI3NzcAYwBteXNxbA== |
| 4 | Fusion-Router-2 | 32774 | MzI3NzQAYwBteXNxbA== |
| 5 | Fusion-Router-1 | 32773 | MzI3NzMAYwBteXNxbA== |
| 6 | CorpGW-2 | 32772 | MzI3NzIAYwBteXNxbA== |
| 7 | CorpSW-3 | 32786 | MzI3ODYAYwBteXNxbA== |
| 8 | CorpSW-2 | 32770 | MzI3NzAAYwBteXNxbA== |
| 9 | CorpGW-1 | 32771 | MzI3NzEAYwBteXNxbA== |
| 10 | CorpSW-1 | 32769 | MzI3NjkAYwBteXNxbA== |

> Note: nodes_link.sh-д DC-Switch (32775), CSR (32778), ISP-A (32781), ISP-B (32782), Br1GW (32783) **байхгүй** — оролцогчийн config хийх хязгаарт оршихгүй.

## Юу хийх вэ — task breakdown

| Алхам | Үргэлжлэх | Зөвлөмж |
|---|---|---|
| 1. Бүх node-ийн running-config татах | 5-10 мин | HTML5 console (тус бүр open → terminal length 0 → show run → copy) ЭСВЭЛ SSH reverse tunnel 30 сек |
| 2. Daалгаврын текстийн (PDF доторх требование) дагуу config skeleton зурах | — | Фикс — Lo1, Lo2 mgmt IP, OSPF area, BGP AS, VRF |
| 3. IPSec Branch(Br1GW)↔HQ туннель | — | `tunnel protection ipsec profile`, IKEv2 |
| 4. VRRP/HSRP CorpGW-1↔CorpGW-2 | — | VLAN 10/20/30/110/120 + sub-vlans 1010/1020/1030 |
| 5. iBGP/eBGP бүхэн convergence шалгах | — | `show ip bgp summary`, `show ip ospf neighbor` |
| 6. Зурвасын монитор LibreNMS-руу нэмэх | — | SNMPv2 community, ACL allow |

## Олимпиад дараагийн алхам

Энэ summary-г Claude Code chat-руу дамжуулж "lab-01-ospf folder-руу config skeleton үүсгэ" гэж хэлбэл backbone OSPF area 0/10, VRF FinDep/TechDep multi-instance гэх мэт template гарна.

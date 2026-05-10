# Olymp lab2025 — Config Audit

> **Огноо:** 2026-05-09 ~12:30 (session 2)
> **Source configs:** `olymp-day/config/*.cfg` (10 файл, EVE-NG node нэрээр)
> **Plan source:** `olymp-day/lab2025/lab-summary.md` + `IPv4 address plan.xlsx` + `IPv6 address plan.xlsx` + `topology.pdf`
> **Method:** offline review — running-config-ийг IPv4/IPv6 plan, VLAN map, routing planтай харьцуулав

## TL;DR — Засах urgency

| P | Тоо | Жишээ |
|---|-----|------|
| **P0 — convergence-blocker** | 5 | OSPF MD5 typo, GW-1 Lo2 OSPF-д байхгүй, Fusion VRF-зөрчил, External Zone OSPF-д байхгүй, CorpSW-3 буруу VLAN |
| **P1 — task-points эрсдэл** | 8 | DC зон Fusion-1-д байхгүй, IPSec/Br1GW тохиргоо хийгдээгүй, SNMP/LibreNMS байхгүй, OSPFv3 router-id зөрчил |
| **P2 — гоо/баримт** | 6 | Hostname mismatch, lldp/cdp inconsistency, ip http server-ийн boy үлдсэн |

**Хамгийн чухал засах ёстой 5 зүйл (≤30 минут):**
1. OSPF MD5 key typo (`ospfkeyI1234` ↔ `ospfkeyl1234`) — Vlan 1020 transit OSPF adjacency fail
2. GW-1 `router ospf 1`-д Loopback2 (10.1.18.8) сүлжээ нэмэх — иначе iBGP TCP fail
3. Fusion-1/2 sub-int 1020/1030 VRF-д оруулах ESРВЭЛ Corp-side VRF-ыг хасах — VRF discontinuity
4. CorpSW-3 VLAN 40-ийг устгаж VLAN 10 SVI 10.1.16.6/27 default-gw 10.1.16.1 руу засах
5. Fusion-1 OSPF v4-д DC zone (10.1.12/13/14) сүлжээ нэмэх + Fusion-2 10.1.13.0/24-ийг нэмэх

---

## P0 — Convergence-blocking bugs

### 1. OSPF MD5 key typo — Vlan 1020 (FinDep transit)
**Symptom:** `show ip ospf neighbor` → CorpGW-2 ↔ Fusion-rtr02 хэзээ ч FULL болохгүй (EXSTART/INIT-д наалдана)

```
config/CorpGW-2.cfg:177 → md5 ospfkeyI1234   (capital I)
config/Fusion_Router-2.cfg:93 → md5 ospfkeyl1234   (lowercase l)
```

**Fix:** Хоёр талд нэг түлхүүр болгох. Сонголт:
```
! On Fusion_Router-2 (хувиргах нь хялбар талыг)
interface GigabitEthernet0/0.1020
 ip ospf message-digest-key 1 md5 ospfkeyI1234
```
Эсвэл хоёр талыг шинэчилж `md5 OSPFkey1234` гэх гарч ирэхгүй тэмдэгт ашиглах.

> **Note:** OSPF authentication одоохондоо зөвхөн нэг линк дээр байна. Бүх transit-д тогтвортой бөгөөд authentication ашигла гэвэл бүх sub-int дээр, эсвэл `area 10 authentication message-digest`-ийг router-level дээр.

---

### 2. GW-1 Loopback2 OSPF-д байхгүй → iBGP fail
**Symptom:** `show ip bgp summary` дээр `10.1.18.10` (GW-2) Active/Idle. `ping 10.1.18.10` GW-1-аас ажиллахгүй.

`config/GW-1.cfg` `router ospf 1`:
```
router ospf 1
 router-id 10.1.18.8
 passive-interface default
 no passive-interface GigabitEthernet0/0.300
 no passive-interface GigabitEthernet0/1.300
 network 10.1.19.20 0.0.0.1 area 0
 network 10.1.19.28 0.0.0.1 area 0
 default-information originate
```
**Lo2 (10.1.18.8) сүлжээ алга.** GW-2-той iBGP-ийн `update-source Loopback2` нь давтавч TCP-аа тогтоохын тулд GW-2 → GW-1 Lo2 дамжих маршруттай байх ёстой → OSPF дотор зарлагдах ёстой.

**Fix:**
```
router ospf 1
 network 10.1.18.8 0.0.0.0 area 0
```

> **Compare:** GW-2 нь `network 10.1.18.10 0.0.0.0 area 0` зөв байгаа.

---

### 3. Fusion ↔ CorpGW VRF discontinuity (FinDep / TechDep transit)
**Symptom:** `show ip route vrf FinDep` Fusion-rtr01 дээр алга (VRF тэр router дээр огт байхгүй). FinDep/TechDep сүлжээ Fusion-аар дамжаж WAN-руу гарч чадахгүй.

| Sub-int | CorpGW-1 / CorpGW-2 | Fusion-rtr01 / Fusion-rtr02 |
|---|---|---|
| Vlan 1020 (FinDep transit) | `vrf forwarding FinDep` ✓ | **VRF алга — global RIB-д** ✗ |
| Vlan 1030 (TechDep transit) | `vrf forwarding TechDep` ✓ | **VRF алга — global RIB-д** ✗ |
| Vlan 310 (Mgmt transit Fusion↔GW) | n/a | **`vrf forwarding mgmt` алга** Fusion-1.310, Fusion-2.310 — GW-1/2 талд `vrf forwarding mgmt` бий |

**Fix (recommended)** — Fusion-rtr01/-rtr02 дээр VRF үүсгэж sub-int-уудыг VRF-д оруулна:
```
vrf definition FinDep
 address-family ipv4
 exit-address-family
 address-family ipv6
 exit-address-family
!
vrf definition TechDep
 ...
!
vrf definition mgmt
 ...
!
interface GigabitEthernet0/0.1020
 vrf forwarding FinDep
 ip address 10.1.19.11 255.255.255.254
!
interface GigabitEthernet0/0.1030
 vrf forwarding TechDep
 ip address 10.1.19.13 255.255.255.254
!
interface GigabitEthernet0/2.310
 vrf forwarding mgmt
 ...
!
router ospf 4 vrf FinDep
 router-id 10.1.18.7
 network 10.1.19.10 0.0.0.1 area 10
!
router ospf 5 vrf TechDep
 router-id 10.1.18.7
 network 10.1.19.12 0.0.0.1 area 10
!
router ospf 2 vrf mgmt
 router-id 10.1.18.7
 network 10.1.19.22 0.0.0.1 area 0
 ...
```

> **Note:** Энэ хувилбар нь plan-той бүрэн нийцэх (VRF FinDep, TechDep, Mngt тус бүрд тус тусын router-id, тус тусын OSPF process). VRF route-leak engine хэрэгтэй болохгүй.

---

### 4. CorpSW-3 буруу VLAN + буруу subnet + буруу default-route
**Symptom:** Plan-аар CorpSW-3 mgmt = **10.1.16.6 / Vlan 10**. Бодит config:
```
interface Vlan40
 ip address 10.1.16.134 255.255.255.224     ← /27 = 10.1.16.128/27 = "Available" subnet
ip route 0.0.0.0 0.0.0.0 10.1.16.129          ← default-gw байхгүй subnet-д
! ip default-gateway алга
```
+ trunk port-ууд VLAN 40-ийг allow хийж байна (CorpGW-1/2 trunk-д VLAN 40 байхгүй → drop).
+ VLAN 40 нь plan-аар `Branch Network` (Br1GW) — CorpSW-3-д **тэр огт хэрэггүй**.

**Fix (full clean-up):**
```
no interface Vlan40
no ip route 0.0.0.0 0.0.0.0 10.1.16.129
!
interface Vlan10
 ip address 10.1.16.6 255.255.255.224
!
ip default-gateway 10.1.16.1
!
interface Ethernet0/0
 description to_CorpGW-1
 switchport trunk allowed vlan 10,20,30
!
interface Ethernet0/1
 description to_CorpGW-2
 switchport trunk allowed vlan 10,20,30
```

---

### 5. DC External Zone (10.1.13.0/24) OSPF-д бараг байхгүй; Fusion-1 нь бүхэл DC-г OSPF v4-д үүсгээгүй
**Symptom:** Fusion-1 дээр `router ospf 1` нь DC sub-int (.100/.110/.120)-ийн сүлжээг network statement-аар зарласан байх ёстой. Бодит:

| Subnet | Fusion-rtr01 OSPF v4 | Fusion-rtr02 OSPF v4 |
|---|---|---|
| 10.1.12.0/24 (Internal) | ✗ алга | ✓ |
| 10.1.13.0/24 (External) | ✗ алга | ✗ алга |
| 10.1.14.0/24 (Mgmt-zone) | ✗ алга | ✓ |

Үр дүн: 10.1.13.0/24 (External Zone) хаа ч OSPF-д ороогүй → WAN талаас reach хийгдэхгүй.
Fusion-1 dc sub-int IPv4 LSA-ыг гаргахгүй — backup path алга.

**Fix Fusion-rtr01:**
```
router ospf 1
 network 10.1.12.0 0.0.0.255 area 0
 network 10.1.13.0 0.0.0.255 area 0
 network 10.1.14.0 0.0.0.255 area 0
```

**Fix Fusion-rtr02:**
```
router ospf 1
 network 10.1.13.0 0.0.0.255 area 0
```

> **Note:** Fusion-1-ийн `network 133.34.13.0 0.0.0.127 area 0` бол DC public block — plan-той тохирно (DC public 133.34.13.0/25). OK.

---

## P1 — Task-point бий хадаах асуудлууд

### 6. GW-2 router ospfv3 1 — `router-id` алга байж магадгүй
GW-1: `router ospfv3 1 / router-id 10.1.18.8` ✓
GW-2: `router ospfv3 1` block нь айзгүй, дотор тал нь хоосон. GW-2 Loopback2 дээр `ospfv3 1 ipv6 area 0` бий тул router-id auto-elect (highest IPv4 IP). Гэвч eXplicit байх нь зөв.

```
! On GW-2
router ospfv3 1
 router-id 10.1.18.10
 address-family ipv6 unicast
  passive-interface default
  no passive-interface GigabitEthernet0/0.300
  no passive-interface GigabitEthernet0/1.300
 exit-address-family
```

GW-1-ийн `router ospfv3 1` дээр **`address-family ipv6 unicast`** хэсэг алга → IPv6 routing fail магадтай.

---

### 7. GW-1 Loopback2 IPv6 (2001:DB8:ABCD:17::8/128) OSPFv3-д ороогүй
GW-2 Lo2: `ospfv3 1 ipv6 area 0` ✓
GW-1 Lo2: байхгүй

**Fix:**
```
interface Loopback2
 ipv6 address 2001:DB8:ABCD:17::8/128
 ospfv3 1 ipv6 area 0
```

---

### 8. Br1GW config тогтоогдоогүй, IPSec бүтэц алга
- `config/Br1GW.cfg` файл алга (10 device of 14 collected)
- Бүх 10 device дээр **crypto / isakmp / ikev2 / tunnel алга**
- Plan task #3: "IPSec Branch(Br1GW)↔HQ туннель"

**ToDo:**
- Br1GW console-руу нэвтэрч `show run` татаж `config/Br1GW.cfg`-руу хадгал
- IKEv2 + IPSec profile + tunnel interface бичих (template: `reference/cheatsheet/ipsec.md`)
- HQ тал (магадгүй GW-1 эсвэл Fusion-rtr01) дээр peer config

---

### 9. SNMPv2 / LibreNMS бүрэн алга
Бүх 10 config дээр `snmp-server` мөр **0** удаа гарна.
Plan task #6: "Зурвасын монитор LibreNMS-руу нэмэх — SNMPv2 community, ACL allow"

**Fix template (per device):**
```
snmp-server community OlympRO RO 99
snmp-server location Olymp-Lab2025
snmp-server contact admin@olympiad.local
snmp-server enable traps
!
access-list 99 permit 10.1.16.32 0.0.0.31    ! DC mgmt subnet
access-list 99 permit 10.1.16.0  0.0.0.31    ! Corp mgmt subnet
```

---

### 10. CorpGW Vlan 10 — VRRP/HSRP IPv6 алга
Vlan10 (Corp mgmt VLAN) v4 only:
- CorpGW-1: `vrrp 10 ip 10.1.16.1 priority 110` (master)
- CorpGW-2: `vrrp 10 ip 10.1.16.1` (default 100, slave)
- **IPv6 standby байхгүй Vlan10 дээр**

Plan-д Corp mgmt v6 заавал гэж хэлээгүй ч "VRRP/HSRP" task ерөнхий байгаа бол v6-ыг бас тохирох нь зөв. (Vlan20/30 дээр v6 standby идэвхтэй.)

---

### 11. CorpGW Vlan20/30 — VRRP/HSRP master тэгш бус хуваарилалт
| VLAN | v4 master (VRRP) | v6 master (HSRP) |
|---|---|---|
| 20 (FinDep) | CorpGW-1 (priority 110) | CorpGW-2 (priority 150) |
| 30 (TechDep) | CorpGW-2 (priority 110) | CorpGW-2 (priority 150) |

Хэрэв энэ нь load-balance гэж хийсэн бол OK. Гэвч:
- **CorpGW-1 Vlan30 standby preempt алга** (CorpGW-2 standby 30 preempt бий).
- **CorpGW-1 Vlan20 vrrp 20 priority 110, preempt-ийн default true** (VRRP-д default preempt).
- VLAN 20 v4 master = CorpGW-1, VLAN 30 v4 master = CorpGW-2 → traffic split хийсэн санаа байж магадгүй. **Шалгуурын дагуу зорилго нь юу гэж байгааг лав уншаарай**.

---

### 12. Fusion-1 `ip route 10.16.15.0 255.255.255.0 10.1.19.35` — суспициоз
Plan-д 10.16.15.0/24 байхгүй. Magate `10.1.15.0/24` гэж бичих ёстой байгаа typo (10.1.15.0/24 = "Available" зорилгот subnet).
10.1.19.35 нь Mgmt-rtr-руу заана. **Manual review хэрэгтэй** — Mgmt-rtr ямар сүлжээг агуулж байгааг үзээд subnet-ийн зөвийг шалга.

---

### 13. DC-Switch — мэргэжлийн mgmt SVI алга
Plan: `Data Center Network Management 10.1.16.32/27 — VLAN 10`. 
DC-Switch одоогийн config нь L2-only. Хэрэв DC-Switch удирдах хэрэгтэй бол:
```
interface Vlan10
 ip address 10.1.16.34 255.255.255.224
!
ip default-gateway 10.1.16.33   ! Fusion HSRP virtual эсвэл peer
```
Гэвч plan-д DC-Switch-ийн mgmt IP бичигдээгүй (зөвхөн "Zone Firewall" гэсэн). **Хэрэглэгчийн PDF-ийг өөрөө шалгах**.

---

## P2 — Гоо / consistency

### 14. Hostname configured-vs-filename mismatch
Файлын нэр нь EVE-NG node нэрээр (CorpSW-1 etc.) хадгалагдсан, гэвч actual `hostname` өөр:

| File | Configured hostname |
|---|---|
| CorpSW-1.cfg | corp-esw01 |
| CorpSW-2.cfg | corp-esw02 |
| CorpSW-3.cfg | CorpSW-3 ✓ |
| CorpGW-1.cfg | corp-dsw01 |
| CorpGW-2.cfg | corp-dsw02 |
| DC-Switch.cfg | dc-esw01 |
| Fusion_Router-1.cfg | Fusion-rtr01 |
| Fusion_Router-2.cfg | Fusion-rtr02 |
| GW-1.cfg | wan-rtr01 |
| GW-2.cfg | wan-rtr02 |

→ **Шалгуурын текст** "device name as it appears in EVE-NG" гэвэл бүгдийг EVE-NG нэртэй зөв болго. Эсвэл хариуд consistency хадгалаад одоогийнх нь үлдээж болно.

---

### 15. CorpSW-3 `ip domain-name olympiad.num` (бусад: `olympiad.local`)
```
no ip domain-name olympiad.num
ip domain-name olympiad.local
```

---

### 16. CorpGW-1 `lldp run` идэвхтэй; CorpGW-2 алга — peer-discovery асимметри
```
! On CorpGW-2
lldp run
```

---

### 17. CorpSW-1 `ip ssh time-out 60 / version 2` бий, CorpSW-3 алга
```
! On CorpSW-3
ip ssh time-out 60
ip ssh version 2
```

---

### 18. `ip http server` олон device-д идэвхтэй (DC-Switch гэх мэт)
Хэрэв шалгуур security baseline шаардлаа бол:
```
no ip http server
no ip http secure-server
```

---

### 19. `service compress-config` нь CorpSW-3 + CorpGW-1/2 дээр идэвхтэй (бусад дээр алга)
Gо energie шалгуур бус. Үлдээж болно. Зөвхөн consistency-ийн төлөө нэгтгэвэл сайн.

---

## Per-device summary

| Device | Configured-hostname | P0 | P1 | P2 | Гол алдаа |
|---|---|---|---|---|---|
| **CorpSW-1** | corp-esw01 | 0 | 0 | 1 | hostname mismatch |
| **CorpSW-2** | corp-esw02 | 0 | 0 | 1 | hostname mismatch + `spanning-tree guard root` only on Eth0/1 |
| **CorpSW-3** | CorpSW-3 | **1** | 0 | 2 | VLAN 40 буруу, mgmt буруу, default-gw алга, domain typo |
| **CorpGW-1** | corp-dsw01 | 0 | 1 | 1 | Vlan10 v6 алга, Vlan30 preempt алга |
| **CorpGW-2** | corp-dsw02 | **1** | 1 | 1 | OSPF MD5 typo, lldp алга |
| **DC-Switch** | dc-esw01 | 0 | 1 | 1 | mgmt SVI алга, trunk Fusion-2-руу VLAN 69 байхгүй (ам талд хэрэггүй магад) |
| **Fusion-rtr01** | Fusion-rtr01 | **2** | 1 | 0 | VRF алга (FinDep/TechDep/mgmt), DC v4 OSPF алга, suspicious static |
| **Fusion-rtr02** | Fusion-rtr02 | **2** | 0 | 0 | VRF алга, OSPF MD5 typo, External Zone OSPF алга |
| **GW-1** | wan-rtr01 | **1** | 2 | 0 | Lo2 OSPF-д алга, Lo2 v6 OSPFv3-д алга, ospfv3 IPv6 AF алга |
| **GW-2** | wan-rtr02 | 0 | 1 | 0 | ospfv3 router-id explicit set хэрэгтэй |

> **Цуглуулагдаагүй:** `Br1GW.cfg`, `CSR.cfg`, `ISP-A.cfg`, `ISP-B.cfg`. ISP-уудыг тохиргоо хийхгүй (plan-аар), CSR/Br1GW-ийг дараагийн алхамд цуглуул.

---

## Засах дарааллын санал (~1.5 цаг)

```
ШАТ 1 (15 мин) — convergence-blockers
[1] OSPF MD5 typo → Fusion-rtr02 Gi0/0.1020 түлхүүр шинэчил
[2] GW-1 router ospf 1 → network 10.1.18.8 0.0.0.0 area 0 нэм
[3] CorpSW-3 → VLAN 40 хас, VLAN 10 SVI 10.1.16.6/27 + ip default-gateway 10.1.16.1

ШАТ 2 (30 мин) — VRF + DC routing
[4] Fusion-rtr01 + Fusion-rtr02-д vrf definition FinDep / TechDep / mgmt үүсгэх
[5] sub-int 1020/1030/310 нэр бүрд vrf forwarding нэмэх (4 sub-int per Fusion)
[6] router ospf 4 vrf FinDep, router ospf 5 vrf TechDep, router ospf 2 vrf mgmt үүсгэх
[7] Fusion-rtr01 router ospf 1-д DC zones (10.1.12/13/14) network нэмэх
[8] Fusion-rtr02 router ospf 1-д 10.1.13.0/24 network нэмэх

ШАТ 3 (20 мин) — IPv6 + GW
[9] GW-1 Lo2-ийг ospfv3 1 ipv6 area 0 нэм
[10] GW-1 + GW-2 router ospfv3 1-д address-family ipv6 unicast block + router-id explicit
[11] CorpGW Vlan10-д IPv6 + standby 10 ipv6 (хэрэв заавал бол)

ШАТ 4 (30 мин) — Lab-specific tasks
[12] Br1GW console-руу нэвтэрж config татах + IPSec/IKEv2 тохиргоо
[13] HQ talах (GW-1 эсвэл Fusion-rtr01) IPSec peer
[14] Бүх router/switch-д snmp-server community OlympRO RO + ACL ne
[15] LibreNMS UI-д device бүрийг нэм (verify polling)

ШАТ 5 (15 мин) — Verify
[16] show ip ospf neighbor бүх device дээр → бүгд FULL/BDR/DR
[17] show ip bgp summary GW-1/GW-2 → iBGP Established
[18] show standby brief CorpGW-1/-2 → master/slave тэгш
[19] ping 10.1.18.10 from GW-1 (iBGP next-hop)
[20] traceroute from FinDep user (10.1.1.10) to ISP-A (202.43.65.1)
```

---

## Verify command quick reference

```bash
# Adjacency
show ip ospf neighbor
show ip ospf 2 vrf FinDep neighbor
show ipv6 ospf neighbor
show ip bgp summary
show bgp ipv6 unicast summary
show standby brief
show vrrp brief

# Reachability
ping vrf FinDep 10.1.18.5 source 10.1.18.2     ! CorpGW-1 → CorpGW-2 Lo3 in FinDep
ping 10.1.18.10 source 10.1.18.8                  ! GW-1 → GW-2 iBGP source
traceroute 202.43.65.1                            ! ISP-A reach

# OSPF auth debug (хэрэв md5 mismatch үлдвэл)
debug ip ospf adj
show ip ospf interface Gi0/0.1020 | include auth

# BGP next-hop
show ip route 10.1.18.10
show ip cef 10.1.18.10
```

---

## Reference материал

- [`lab2025/lab-summary.md`](lab2025/lab-summary.md) — task breakdown, IPv4/IPv6 plan нэгтгэл
- [`../reference/cheatsheet/ospf.md`](../reference/cheatsheet/ospf.md) — multi-area + VRF
- [`../reference/cheatsheet/bgp.md`](../reference/cheatsheet/bgp.md) — iBGP RR, eBGP
- [`../reference/cheatsheet/ipsec.md`](../reference/cheatsheet/ipsec.md) — IKEv2 + GRE+IPSec
- `config_orig_backup/` — энэ audit-ийн өмнөх snapshot (rollback target)

---

# === VERIFICATION LOG (Session 2 · pass 2) ===

## ✅ Баталгаажсан P0 findings

### #1 OSPF MD5 typo — hex evidence
```
CorpGW-2.cfg:177  → ospfkey I 1234   (0x49 = capital 'I')
Fusion_Router-2.cfg:93 → ospfkey l 1234   (0x6c = lowercase 'l')
```
Хоёр стрингын байт-уудын зөрүү 1 (0x49 ↔ 0x6c). Vlan 1020 (FinDep transit) дээрх OSPF adjacency mathematically мөн цаашид босохгүй.

### #2 GW-1 Loopback2 OSPF v4-д алга — баталгаажсан
```
GW-1 router ospf 1 networks:  10.1.19.20/31, 10.1.19.28/31
                              ─── Lo2 (10.1.18.8) АЛГА ───
GW-2 router ospf 1 networks:  10.1.18.10/0 ✓, 10.1.19.24/31, 10.1.19.28/31
```

### #3 Fusion VRF discontinuity — баталгаажсан
```
$ grep "vrf definition" Fusion_Router-{1,2}.cfg
(no matches)
```
Хоёр Fusion дээр VRF definition огт байхгүй. Тэгэхээр sub-int 1020/1030/310 нь global RIB-д үлдэнэ. CorpGW тал дээр VRF FinDep/TechDep/mgmt бий тул L3 ban-VRF mismatch.

### #4 CorpSW-3 буруу VLAN — баталгаажсан
```
hostname CorpSW-3                              ! ✓
ip domain-name olympiad.num                    ! ✗ should be olympiad.local
trunk allowed vlan 10,20,30,40                 ! ✗ VLAN 40 = Branch (per IPv4 plan)
interface Vlan40 / ip 10.1.16.134 255.255.255.224  ! ✗ 10.1.16.128/27 = "Available" subnet
ip route 0.0.0.0 0.0.0.0 10.1.16.129           ! ✗ no such gateway exists
! ip default-gateway алга                      ! ✗ CorpSW-1/2-д бий
```

### #5 DC zones OSPF v4 — баталгаажсан
| Subnet | Fusion-1 | Fusion-2 |
|---|---|---|
| 10.1.12.0/24 (Internal) | ✗ | ✓ |
| 10.1.13.0/24 (External) | ✗ | ✗ |
| 10.1.14.0/24 (Mgmt-zone) | ✗ | ✓ |

External Zone (10.1.13.0/24) хаа ч advertise хийгдэхгүй → backbone unreachable.

---

## 🆕 Verification-аар нэмэлт олдсон ШИНЭ findings

### NEW P0 (#6) — GW-1 Loopback2 IPv6 ospfv3-д ороогүй → IPv6 iBGP TCP fail
```
! GW-1 Lo2:
interface Loopback2
 ip address 10.1.18.8 255.255.255.255
 ipv6 address 2001:DB8:ABCD:17::8/128
                                              ← ospfv3 1 ipv6 area 0 АЛГА
!
! GW-2 Lo2:
interface Loopback2
 ip address 10.1.18.10 255.255.255.255
 ipv6 address 2001:DB8:ABCD:17::10/128
 ospfv3 1 ipv6 area 0                         ← бий
```
Үр дүн: GW-2 → GW-1 Lo2 v6 (2001:DB8:ABCD:17::8) reach хийхгүй → IPv6 iBGP TCP босохгүй. **IPv4 iBGP fail-тэй яг ижил problem**, IPv6 талд P0 (#2-той хослуулна).

**Fix:**
```
! On GW-1
interface Loopback2
 ospfv3 1 ipv6 area 0
```

### NEW P1 (#20) — Fusion-1 `redistribute static subnets` нь typo-static-ыг OSPF-д цацна
```
ip route 10.16.15.0 255.255.255.0 10.1.19.35       ← typo? '10.16.15.0' (10.16!) нь plan-д огт байхгүй
!
router ospf 1
 redistribute static subnets                       ← typo'd /24 LSA Type-5 болж area 0-д цацна
```
Магадгүй intended `10.1.15.0/24` (plan: "Available" зорилгот subnet) ⇒ typo. Эсвэл бүхнийг устга:
```
no ip route 10.16.15.0 255.255.255.0 10.1.19.35
no router ospf 1
 no redistribute static subnets
```

### NEW P1 (#21) — CorpGW-1, CorpGW-2 loopback-уудад IPv6 алга (per IPv6 plan)
IPv6 plan заасан loopback v6 IP-уудыг config-уудад бараг хэрэгжээгүй:

| Device | Loopback | IPv6 plan | Configured |
|---|---|---|---|
| CorpGW-1 | Lo2 | 2001:db8:abcd:17::1/128 | **алга** |
| CorpGW-1 | Lo3 (FinDep) | 2001:db8:abcd:17::2/128 | **алга** |
| CorpGW-1 | Lo4 (TechDep) | 2001:db8:abcd:17::3/128 | **алга** |
| CorpGW-2 | Lo2 | 2001:db8:abcd:17::4/128 | **алга** |
| CorpGW-2 | Lo3 (FinDep) | 2001:db8:abcd:17::5/128 | **алга** |
| CorpGW-2 | Lo4 (TechDep) | 2001:db8:abcd:17::6/128 | **алга** |
| GW-1 | Lo2 | 2001:db8:abcd:17::8/128 | ✓ |
| GW-1 | Lo3 (Mngt) | 2001:db8:abcd:17::9/128 | **алга** |
| GW-2 | Lo2 | 2001:db8:abcd:17::10/128 | ✓ |
| GW-2 | Lo3 (Mngt) | 2001:db8:abcd:17::11/128 | **алга** |

**Fix template per CorpGW:**
```
interface Loopback2
 ipv6 address 2001:DB8:ABCD:17::1/128
 ospfv3 1 ipv6 area 10
!
interface Loopback3
 ipv6 address 2001:DB8:ABCD:17::2/128
 ! ospfv3 vrf-aware?
```

> **Анхаар:** Plan-д "Loopback Interface IPs / 2001:db8:abcd:0017::/64" гэсэн нэг /64 байна, гэхдээ Sheet "LoopBack interface" дээр device тус бүрд ::1, ::2, ::3 ... allocated. Зөв subnet-ийг өөрөө тулгаарай — би IPv6 plan-аас pickup хийсэн утгыг л харьцуулсан.

### NEW P2 (#22) — DC-Switch security baseline
```
ip http server                  ! ✗ dipper if scored
ip http secure-server
no aaa new-model                ! AAA totally disabled
! No SNMP
! No banner motd / login customization
! No console exec-timeout / vty exec-timeout (default 10 min)
```

### NEW P2 (#23) — CorpGW Loopback5 placeholder
- CorpGW-1 Lo5: `no ip address` (no shutdown)
- CorpGW-2 Lo5: `no ip address` + `shutdown` + `track 1 interface Loopback5 line-protocol`

CorpGW-2-ийн `track 1` нь `standby 30 track 1 decrement 60`-ыг trigger хийхэд ашигладаг (Lo5 шутдсан = always down = TechDep gateway-ыг always yield хий гэж дохио). Энэ нь intentional дизайн ч магадгүй буруу — plan/PDF-аас хариуг тодруулах. Магадгүй plan-д "VRRP track" хийнэ гэж байсан бол ил болгох.

---

## ❌ Verification-аар хасагдсан concerns

### Concern: GW-2 BGP IPv6 ISP-B neighbor `2001:D29:0:10::2` нь typo (D29 vs DB9?)
**ХАСАГДСАН** — IPv6 plan тодорхой:
```
ISP-1 (2001:db9::/32) → 2001:db9:0:0010::2/127  (ISP-A) → matches GW-1 ✓
ISP-2 (2001:d29::/32) → 2001:d29:0:0010::2/127  (ISP-B) → matches GW-2 ✓
```
Plan-аар D29 нь intentional 2-р ISP-ын prefix. Zero issue.

### Concern: GW-1 ospfv3 `address-family ipv6 unicast` block алга
**ХАСАГДСАН** — pass 2-д verify хийсэн нь GW-1 actually HAS the AF block:
```
router ospfv3 1
 router-id 10.1.18.8
 !
 address-family ipv6 unicast
  passive-interface default
  no passive-interface GigabitEthernet0/0.300
  no passive-interface GigabitEthernet0/1.300
 exit-address-family
```
Зөвхөн **GW-2 router-id** нь алга (P1 #6 хэвээр).

### Concern: DC-Switch trunk to fusion-rtr02 missing VLAN 69 нь bug
**ХАСАГДСАН** — Fusion-rtr02 нь `Gi0/3.69` sub-int огт байхгүй (Mgmt-rtr peer тал зөвхөн Fusion-1). Тэгэхээр DC-SW trunk to fusion-2 дээр VLAN 69 шаардлагагүй. **Зөв design**.

---

## 🔢 Updated counts

| P | Pass 1 | Verification дараа | Δ |
|---|--------|-------------------|---|
| P0 | 5 | **6** | +1 (GW-1 Lo2 v6) |
| P1 | 8 | **10** | +2 (Fusion-1 typo redistribute, Loopback v6 missing) |
| P2 | 6 | **8** | +2 (DC-SW security, CorpGW Lo5 design) |

---

## Засах дараалал — шинэчилсэн (~2 цаг)

```
ШАТ 1 (15 мин) — convergence-blockers (P0)
[1] OSPF MD5 typo — Fusion-rtr02 Gi0/0.1020 → ospfkeyI1234
[2] GW-1 router ospf 1 → network 10.1.18.8 0.0.0.0 area 0
[3] GW-1 Loopback2 → ospfv3 1 ipv6 area 0       ← NEW
[4] CorpSW-3 → wipe VLAN 40, set VLAN 10 SVI 10.1.16.6/27 + ip default-gateway 10.1.16.1
[5] Fusion-rtr01 router ospf 1 → networks 10.1.12/13/14 add
[6] Fusion-rtr02 router ospf 1 → network 10.1.13.0 add

ШАТ 2 (40 мин) — VRF + IPv6 loopback (P1)
[7] Fusion-rtr01 + Fusion-rtr02-д vrf definition FinDep / TechDep / mgmt + sub-int vrf forwarding + per-VRF OSPF process
[8] CorpGW-1 + CorpGW-2 Lo2/3/4 → ipv6 address per plan
[9] GW-1 + GW-2 Lo3 → ipv6 address per plan
[10] GW-2 router ospfv3 1 → router-id 10.1.18.10
[11] Fusion-1 ip route 10.16.15.0 → typo шалгаад зас эсвэл бичигдсэнийг устга

ШАТ 3 (30 мин) — Lab-specific (P1)
[12] Br1GW console-руу нэвтэр + show run + IPSec/IKEv2
[13] HQ тал IPSec peer
[14] SNMPv2 community + ACL бүх router/switch-д

ШАТ 4 (15 мин) — Verify
[15] show ip ospf neighbor — бүгд FULL
[16] show ip ospf 2 vrf FinDep neighbor; show ip ospf 3 vrf TechDep neighbor
[17] show ipv6 ospf neighbor; show bgp ipv6 unicast summary
[18] show ip bgp summary GW-1/GW-2 → iBGP Established
[19] show standby brief CorpGW-1/-2
[20] traceroute from FinDep user 10.1.1.10 → 202.43.65.1 (ISP-A)
[21] traceroute from TechDep user 10.1.2.10 → 103.88.34.1 (ISP-B)
```

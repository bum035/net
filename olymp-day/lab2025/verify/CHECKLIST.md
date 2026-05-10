# Verify CHECKLIST — 19 task-ийн PASS criteria

> Claude-д унших signal. Output файл бүрд `output/<device>.txt`-аас доорх pattern-уудыг хайна. Бүх pattern олдвол **PASS**, ядаж нэг алга бол **FAIL**.

---

## Ulsaa — BGP стек (12 pts)

### [ ] iBGP — 3 pts (wan-rtr01, wan-rtr02)

**output/wan-rtr01.txt-аас:**
- `show ip ospf interface brief` → **Loopback2** мөр байна (P2P, area 0)
- `show ip route` → wan-rtr02 Lo2 (10.1.18.10/32) **O** ospf route-аар
- `show ip bgp summary` → wan-rtr02 (10.1.18.10) State **Established**, Up time > 0
- `show bgp ipv6 unicast summary` → 2001:DB8:ABCD:17::10 **Established**

**output/wan-rtr02.txt-аас:**
- `show ip bgp summary` → wan-rtr01 (10.1.18.8) **Established**
- `show bgp ipv6 unicast summary` → 2001:DB8:ABCD:17::8 **Established**

❌ FAIL шинж: State `Active` / `Idle` / `Connect` — session тогтоогүй.

---

### [ ] BGP-1 — 2 pts (wan-rtr01, wan-rtr02)

**output/wan-rtr01.txt:**
- `show ip bgp` → `133.34.12.0/25` болон `133.34.12.128/25` mark `*>`
- `show bgp ipv6 unicast` → `2001:DB8::/32` (эсвэл өөр /32) `*>`
- `show running-config | section bgp` → `network 133.34.12.0 mask 255.255.255.128`, `network 133.34.12.128 mask 255.255.255.128`

❌ FAIL: зөвхөн /24 announce, эсвэл network statement байхгүй.

---

### [ ] BGP-2 — 3 pts (wan-rtr01)

**output/wan-rtr01.txt:**
- `show running-config | section route-map` → ISP-A-IN (эсвэл ижил утгатай) `set local-preference 200`
- `show ip bgp` → ISP-A neighbor-аас ирсэн route LocPrf **200** (ISP-B-аас 100 эсвэл prepend-тай)
- ESV `show ip route` → default route (0.0.0.0/0) **next-hop ISP-A** (wan-rtr01-аар)

❌ FAIL: route-map алга, эсвэл LocPrf бүгд default 100.

---

### [ ] BGP-3 — 4 pts (wan-rtr01, wan-rtr02)

**output/wan-rtr02.txt:**
- `show running-config | include bgp-community` → `ip bgp-community new-format`
- `show running-config | section community` → `community-list <name> permit <ASN>:<val>` (e.g. `19000:100`)
- `show running-config | section route-map` → IPv6 route-map матч community → set local-preference 200
- `show bgp ipv6 unicast` → community-той prefix LocPrf **200** (preferred via wan-rtr02)

❌ FAIL: community-list байхгүй, эсвэл community match хийдэг route-map алга.

---

## Altai — OSPF + VRRP + NAT + IPSec (22 pts)

### [ ] VRRP — 2 pts (corp-dsw01)

**output/corp-dsw01.txt:**
- `show vrrp brief` → Vlan20 group **20**, Master, priority **110**
- `show running-config | section track` → `track 10 interface Vlan1020 line-protocol` (эсвэл өөр interface)
- `show running-config interface Vlan20` → `vrrp 20 track 10 decrement 30` (эсвэл ижил утгатай)

**Optional (uplink down симуляц):** `shut Vlan1020` дараа `show vrrp brief` → priority **80**, State Backup → corp-dsw02 active.

❌ FAIL: track байхгүй, эсвэл vrrp track config алга.

---

### [ ] OSPF-1 — 2 pts (corp-dsw01, corp-dsw02)

**output/corp-dsw01.txt:**
- `show ip ospf neighbor vrf FinDep` → ядаж 1 neighbor **FULL**
- `show ip ospf neighbor vrf TechDep` → ядаж 1 neighbor **FULL**

**output/corp-dsw02.txt:**
- ижил VRF-уудад FULL neighbor.

❌ FAIL: VRF blank, эсвэл neighbor INIT/EXSTART-д наалдсан.

---

### [ ] OSPF-2 — 3 pts (Fusion-rtr01, Fusion-rtr02)

**output/Fusion-rtr01.txt:**
- `show running-config | section router ospf 1` → **`passive-interface default`** мөр **байна**
- `no passive-interface <iface>` мөр ядаж 1 (neighbor-той interface дээр)
- `show ip ospf neighbor` → FULL neighbor байгаа

**output/Fusion-rtr02.txt:** ижил.

❌ FAIL: `passive-interface default` алга → neighbor цөөрөх ёсгүй боловч задгай.

---

### [ ] OSPF-3 — 2 pts (corp-dsw02)

**output/corp-dsw02.txt:**
- `show running-config | section router ospfv3` → block байна (Router-ID, address-family ipv6 unicast — global + vrf FinDep + vrf TechDep)
- `show ipv6 ospf interface brief` → Vlan-нууд listed
- `show ipv6 ospf neighbor` → ядаж 1 FULL

❌ FAIL: ospfv3 section хоосон.

---

### [ ] OSPF-4 — 2 pts (wan-rtr01, wan-rtr02)

**output/wan-rtr01.txt + output/wan-rtr02.txt:**
- `show running-config | section ospfv3` → `default-information originate always` (IPv6 AF-д)
- `show ipv6 route ::/0` → ::/0 entry (locally originated, OE1/OE2)

❌ FAIL: `always` keyword байхгүй, эсвэл BGP default алга үед ::/0 алга.

---

### [ ] OSPF-5 — 3 pts (corp-dsw01, corp-dsw02)

**output/corp-dsw01.txt + output/corp-dsw02.txt:**
- `show ip route vrf FinDep 0.0.0.0` → default route байна (O*E2 эсвэл S*)
- `show ip route vrf TechDep 0.0.0.0` → default route байна

❌ FAIL: VRF дотор `Gateway of last resort is not set`.

---

### [ ] NAT — 2 pts (wan-rtr01)

**output/wan-rtr01.txt:**
- `show running-config | section ip nat` → `ip nat inside source list NAT_ACL pool 1 vrf FinDep overload`, `... vrf TechDep overload`
- `show running-config | section access-list` → `NAT_ACL` permit 10.1.1.0/24 + 10.1.2.0/24
- `show ip nat statistics` → `Outside interfaces:` GigE0/2 (ISP), `Inside interfaces:` 0/0.300 эсвэл бусад
- `show ip nat translations` → ядаж 1 entry (FinDep host → public)

❌ FAIL: pool бий, гэхдээ `ip nat inside source` rule байхгүй.

---

### [ ] IPsec — 4 pts (wan-rtr01 + Br1GW)

**output/wan-rtr01.txt:**
- `show crypto ikev2 sa` → state **READY**, peer Br1GW IP
- `show crypto ipsec sa` → encaps/decaps counter өсөж байна (хоёул > 0)
- `show interface Tunnel0` → up/up
- `show ip route 10.1.8.0` → reachable via Tunnel0

**output/Br1GW.txt:**
- ижил `show crypto ikev2 sa` READY, `show crypto ipsec sa` encaps/decaps > 0

❌ FAIL: ikev2 sa empty, эсвэл encaps=0/decaps=0.

---

## Byambaa — Service / DevOps / Trbl (12 pts)

### [ ] NTP — 2 pts (Fusion-rtr01 master, Fusion-rtr02 client)

**output/Fusion-rtr01.txt:**
- `show ntp status` → Clock is **synchronized**, stratum **3**
- `show ntp associations` → ядаж 1 server (EVE host эсвэл upstream)
- `show clock` → ULAT timezone (offset +08)

**output/Fusion-rtr02.txt:**
- `show ntp status` → synchronized, server 10.1.17.3 (Fusion-rtr01 Lo1)
- `show clock` → ULAT, ижил цаг

❌ FAIL: `unsynchronized` эсвэл timezone UTC.

---

### [ ] HSRP — 2 pts (corp-dsw02)

**output/corp-dsw02.txt:**
- `show standby Vlan30` → State **Active**, priority **150** (хэрэв Lo5 unshut эсвэл track removed бол)
- `show running-config interface Loopback5` → **`no shutdown`** (active байх) ЭСВЭЛ
- `show running-config interface Vlan30` → `standby 30 track 1 decrement 60` мөр **алга** (track removed)

❌ FAIL: State Standby/Init, priority 90.

---

### [ ] TCLSH — 2 pts (wan-rtr01)

**output/wan-rtr01.txt:**
- `dir flash: | include statuscheck` → `statuscheck` файл байна (size > 0)
- `more flash:statuscheck` → tcl script (`puts [exec ...]` мөрүүд)

❌ FAIL: file байхгүй, эсвэл хоосон.

---

### [ ] OSPF-6 — 2 pts (Fusion-rtr02)

**output/Fusion-rtr02.txt:**
- `show running-config interface GigabitEthernet0/0.1020` → `ip ospf message-digest-key 1 md5 <KEY>` (KEY нь corp-dsw02-той ижил)
- `show ip ospf neighbor` → vlan1020 талаас corp-dsw02 (10.1.18.4) **FULL**

**output/corp-dsw02.txt:**
- `show running-config interface Vlan1020` → ижил md5 key

**Хоёр key string ижил байх ёстой** — `ospfkeyl1234` ≠ `ospfkeyI1234`.

❌ FAIL: neighbor EXSTART/EXCHANGE-д наалдсан.

---

### [ ] TFTP-1 — 2 pts (CorpSW-3)

**output/CorpSW-3.txt:**
- `show running-config` → port-config (vlan, interface description) байна — pristine boot гэж биш
- `show vlan brief` → corp-esw03-confg-аас сэргээсэн VLAN-ууд (data, voice, mgmt)
- `show ip interface brief` → SVI Vlan10 IP **10.1.16.6** (mgmt)

❌ FAIL: blank/factory config.

---

### [ ] TFTP-2 — 2 pts (corp-esw01, corp-esw02)

**output/corp-esw01.txt + output/corp-esw02.txt:**
- `show running-config | section event manager` → `event manager applet TFTP_BACKUP` (эсвэл ижил утгатай нэр)
- `event timer cron ... "*/10 * * * *"`
- `action ... copy running-config tftp://...`
- `show event manager policy registered` → applet ил

❌ FAIL: section хоосон, эсвэл cron schedule биш.

---

### [ ] STP — 2 pts (corp-esw02)

**output/corp-esw02.txt:**
- `show running-config interface Ethernet0/1` → `spanning-tree guard root` мөр **алга** (хасагдсан)
- `show spanning-tree interface Ethernet0/1` → State **FWD** (Forwarding) бүх VLAN-д
- `show spanning-tree | include block|root` → Eth0/1 block-д орохгүй

❌ FAIL: `BLK*` (root-inconsistent block) хэвээр байна.

---

## Шалгасны дараа

```bash
# Master overview-г update хийх
ls ~/net/olymp-day/lab2025/verify/output/   # бүх .txt бөглөгдсөн эсэхийг шалга
# Дутуу ажиглагдвал тухайн device-д буцаж paste run

# Claude-д хариу:
# "verify all"  →  CHECKLIST бүхэлд нь scan хийж 19 task-д PASS/FAIL/BLOCKED return
```

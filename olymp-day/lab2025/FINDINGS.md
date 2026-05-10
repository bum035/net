# lab2025 — Config-level diagnosis (snapshot 2026-05-09 11:30)

> Сурвалж: `olymp-day/config/*.cfg` (CorpSW-1/2/3, CorpGW-1/2 = corp-dsw01/02, Fusion_Router-1/2 = Fusion-rtr01/02, GW-1/2 = wan-rtr01/02, DC-Switch = dc-esw01).
> Br1GW config татагдаагүй.

## Бодит хост нэр (EVE label → hostname)

| EVE label | Actual | Loopback Lo2 (RID) | BGP AS | OSPF area |
|---|---|---|---|---|
| CorpGW-1 | corp-dsw01 | 10.1.18.1 | — | 10 |
| CorpGW-2 | corp-dsw02 | 10.1.18.4 | — | 10 |
| Fusion_Router-1 | Fusion-rtr01 | 10.1.18.7 | — | 0 + 10 ABR |
| Fusion_Router-2 | Fusion-rtr02 | 10.1.18.12 | — | 0 + 10 ABR |
| GW-1 | wan-rtr01 | 10.1.18.8 | 17000 | 0 |
| GW-2 | wan-rtr02 | 10.1.18.10 | 17000 | 0 |
| DC-Switch | dc-esw01 | — (L2 only) | — | — |
| CorpSW-1 | corp-esw01 | — | — | — |
| CorpSW-2 | corp-esw02 | — | — | — |
| CorpSW-3 | CorpSW-3 | — | — | — |

## Tasks vs config — alga / алдаа table

| Task | Алдаа / дутуу | Файл / line |
|---|---|---|
| **iBGP** | wan-rtr01 Loopback2 нь OSPFv2 / OSPFv3-д advertise хийгдээгүй | `GW-1.cfg` int Lo2 (no `ospfv3`) + `router ospf 1` (no `network 10.1.18.8`) |
| **BGP-1** | `network <public>/25` болон `network 2001:DB8::/32` aлга | `GW-1.cfg` `router bgp 17000 address-family ipv4/ipv6` |
| **BGP-2** | route-map IN/OUT байхгүй, local-pref/AS-prepend алга | `GW-1.cfg`, `GW-2.cfg` |
| **BGP-3** | `ip bgp-community new-format`, `community-list`, `route-map` алга | `GW-2.cfg` |
| **VRRP** | corp-dsw01-д `track <id> interface ... line-protocol` + `vrrp 20 track ... decrement` алга | `CorpGW-1.cfg` Vlan20 (line 137) |
| **OSPF-1** | corp-dsw01/02 VRF FinDep/TechDep ospf-д Vlan20/30 SVI subnet-уудыг шалгах | `CorpGW-1.cfg` line 216-232, `CorpGW-2.cfg` line 195-211 |
| **OSPF-2** | Fusion-rtr01 `router ospf 1`-д `passive-interface default` **байхгүй** | `Fusion_Router-1.cfg` line 187-198 |
| **OSPF-3** | corp-dsw02-д `router ospfv3 1` блок **бүхэлд нь алга** | `CorpGW-2.cfg` (line ~195-ы хооронд алга) |
| **OSPF-4** | wan-rtr01/02 ospfv3-д `default-information originate always` алга | `GW-1.cfg` line 160-167, `GW-2.cfg` line 158-164 |
| **OSPF-5** | corp-dsw01/02 VRF FinDep ospf 2-д `default-information originate` алга | `CorpGW-1.cfg` line 216-, `CorpGW-2.cfg` line 195- |
| **NAT** | `ip nat pool 1` тавьсан ч `ip nat inside source list` rule + `ip nat inside/outside` interface alга | `GW-1.cfg` line 217 (pool only) |
| **IPsec** | crypto isakmp / ikev2 / transform / tunnel **бүхэлд нь алга** | `GW-1.cfg` (Br1GW config татагдаагүй) |
| **NTP** | Fusion-rtr01-д `clock timezone`, `ntp source`, `ntp master`, `ntp server` бүгд алга | `Fusion_Router-1.cfg` |
| **HSRP** | corp-dsw02 Vlan30 standby 30 track 1 (Loopback5 line-protocol) — Lo5 shutdown → priority dec 60 → corp-dsw01 active. Шилжүүлэхэд Lo5 unshut эсвэл track unbind | `CorpGW-2.cfg` line 88, line 152-163 |
| **TCLSH** | Скрипт байхгүй | `GW-1.cfg` |
| **OSPF-6** | **CRITICAL TYPO**: Fusion-rtr02 vlan1020 md5 key `ospfkeyl1234` (small l) ↔ corp-dsw02 vlan1020 `ospfkeyI1234` (capital I) | `Fusion_Router-2.cfg:93` ↔ `CorpGW-2.cfg:177` |
| **TFTP-1** | CorpSW-3 нь шинэ төхөөрөмж — running-config дотор юу ч алга | `CorpSW-3.cfg` |
| **TFTP-2** | corp-esw01/02-д `event manager applet` алга | `CorpSW-1.cfg`, `CorpSW-2.cfg` |
| **STP** | corp-esw02 Eth0/1 (to corp-dsw01) дээр `spanning-tree guard root` (line 72) → root inconsistent | `CorpSW-2.cfg:72` |

## Тэргэж буй чухал зөрөө (additional issues, дараа Olymp дараа нь засах)

1. **CorpSW-3 hostname** — IOS-сар `CorpSW-3` гэж нэрлэгдсэн ч даалгавар бичигт `corp-esw03` гэдэг. TFTP backup file `corp-esw03-confg` нэртэйг хэрэглэхэд хост нэр зөрөх нь нөлөөгүй.
2. **dc-esw01** — VLAN database (`vlan 69,100,110,120`) тодорхойлогдсон уу? show config-д vlan list харагдсангүй. SVI алга — pure L2 trunk.
3. **CorpGW-1 (corp-dsw01) Vlan30** — `standby 30 preempt` тавьсан, гэхдээ priority default 100. corp-dsw02 standby 30 priority 150 + preempt + track 1 dec 60 → Lo5 down тул effective 90. `100>90` тул corp-dsw01 active. **HSRP task-н хүрээнд CorpGW-1-ийг Vlan30 active байгаа нь "default" төлөв; CorpGW-2-руу шилжүүлэх нь даалгавар.**
4. **Fusion-rtr01 GigabitEthernet0/3.69** — VLAN 69 mgmt subinterface (10.1.19.34/31) — `ip route 10.16.15.0 255.255.255.0 10.1.19.35` static (Management router-руу).
5. **wan-rtr01 OSPFv2** — Lo2 (10.1.18.8) advertise хийгдээгүй (зөвхөн Lo3 mgmt /32 + Lo1 mgmt /32). `router ospf 2 vrf mgmt`-д Lo3 (10.1.18.9), Lo1 (10.1.17.4) advertise хийсэн ✓.
6. **BGP next-hop-self** — wan-rtr01 болон wan-rtr02 хоёул `neighbor 10.1.18.x next-hop-self` тавьсан ✓ — iBGP next-hop reachability шийдвэрлэгдсэн (Lo2 OSPF advertise болсон үед).
7. **MD5 typo cross-check** — corp-dsw02-д vlan1020-д л байгаа. Бусад interface (vlan1010, 1021, 1030, 1031)-д auth алга → ASYM (нэг талд auth, нөгөө талд нь алга) → adjacency бас тогтохгүй байж болно. Олимп шалгуурыг хэрхэн уншихаас шалтгаалж нэг талд бүгд устгах эсвэл хоёр талд бүгд тавих.

## Үйлдэл (priority order суулжсан)

1. **STP** (corp-esw02 Eth0/1) — `no spanning-tree guard root` (1 line, instant fix).
2. **OSPF-6** (Fusion-rtr02 / corp-dsw02 vlan1020 md5 key) — нэг талыг засах.
3. **iBGP** (wan-rtr01 Lo2 OSPF advertise) — Ulsaa, бусад BGP task-уудын суурь.
4. **OSPF-2** (Fusion-rtr01 passive default) — нэр учрын талаас зөв.
5. **OSPF-3** (corp-dsw02-д ospfv3 нэмэх) — bulk paste config.
6. **NAT** — VRF-aware NAT 4-5 line.
7. **OSPF-4 / OSPF-5** — default originate.
8. **VRRP** — track + decrement.
9. **OSPF-1** — VRF дотор network coverage.
10. **HSRP** — Lo5 unshut эсвэл track unbind.
11. **NTP** — 4 line.
12. **BGP-1/2/3** — community + route-map.
13. **IPsec** — IKEv2 7-9 line + Br1GW mirror.
14. **TFTP-1** — copy tftp.
15. **TFTP-2** — EEM applet.
16. **TCLSH** — tclsh script.

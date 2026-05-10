# lab2025 — Олимпиадын даалгаврууд (20 task / 46 pts)

> Эх сурвалж: http://36.50.7.44:3000/tasks (snapshot 2026-05-09 04:03)
> Нийт: 20 task, 46 pts. 3 оролцогчид (Ulsaa / Altai / Byambaa) хуваагдсан.
> Topology + IPv4/IPv6 plan: `lab-summary.md`, `topology.pdf`, `IPv4 address plan.xlsx`, `IPv6 address plan.xlsx`.

> ⚠ **Зохион байгуулагчийн засвар** (olympiad.conf): VRRP даалгавар дээр "vlan 30" гэж бичсэн нь **vlan 20**-г хэлж байна (FinDep).

## Хост нэрийн зураг (EVE node ↔ actual hostname)

| EVE label | Actual hostname | Тайлбар |
|---|---|---|
| CorpGW-1 | **corp-dsw01** | Corp distribution switch (L3) — CorpGW дотор |
| CorpGW-2 | **corp-dsw02** | |
| Fusion_Router-1 | **Fusion-rtr01** | |
| Fusion_Router-2 | **Fusion-rtr02** | |
| GW-1 | **wan-rtr01** | "WAN router 1" — даалгавар бичигт |
| GW-2 | **wan-rtr02** | "WAN router 2" |
| CorpSW-1 | **corp-esw01** | edge switch (IOL) |
| CorpSW-2 | **corp-esw02** | |
| CorpSW-3 | **CorpSW-3** | (нэр өөрчлөгдөөгүй) — task TFTP-1 corp-esw03 нэрийг ашигладаг |
| DC-Switch | **dc-esw01** | |
| Br1GW | (config татагдаагүй) | салбарын router |

> Даалгавар бичигт "CorpGW-1/2", "wan-rtr01/02", "Fusion router#1/#2", "corp-esw01..03" нэрс холилдсон тул хоёр баганаар таних.

---

## Owner: Ulsaa — BGP стек (12 pts)

### iBGP — Troubleshooting — 3 pts
> CorpGW router 1 2 хоорондын ibgp session down байгааг засна уу (ipv4, ipv6)

**⚠ Тэмдэглэл:** "CorpGW router 1 2" — нэрэлсэн ч **CorpGW (corp-dsw01/02)-д BGP байхгүй**. Routing plan-д iBGP зөвхөн **GW-1 ↔ GW-2 (wan-rtr01/02)** AS 17000 хоорондох. Даалгавар нэрс холилдсон бол wan-rtr-уудын iBGP-г барина.

**Хяналтын цэг (config-level diagnosis):**
- ✅ wan-rtr02-ийн `interface Loopback2` дээр `ospfv3 1 ipv6 area 0` тавьсан, `router ospf 1` сүлжээнд `network 10.1.18.10 0.0.0.0 area 0` оруулсан.
- ❌ **wan-rtr01-ийн `Loopback2` (10.1.18.8 / 2001:DB8:ABCD:17::8)** нь:
  - OSPFv2-д **announce хийгдээгүй** (`router ospf 1` дотор `network 10.1.18.8 0.0.0.0 area 0` алга)
  - OSPFv3-д **`ospfv3 1 ipv6 area 0` interface-д тавиагүй**
- → wan-rtr02 нь wan-rtr01-ийн Lo2-руу хүрэх замгүй → iBGP IPv4 + IPv6 хоёул `update-source Loopback2` тогтохгүй.

**Шийдэл (wan-rtr01):**
```
interface Loopback2
 ospfv3 1 ipv6 area 0
!
router ospf 1
 network 10.1.18.8 0.0.0.0 area 0
```

### BGP-1 — Implementation — 2 pts
> public ipv4 сүлжээг 2 sub сүлжээ болгон ISP-руу зарлаж интернэтд холбогдоно уу!, ipv6 сүлжээг /32-оор ISP-руу зарлаж интернэтд холбогдоно уу!

- IPv4 public block: NAT pool `133.34.12.0/24` (wan-rtr01 `ip nat pool 1`-аас тооцов). 2 sub → /25-уудаар хуваана: `133.34.12.0/25` + `133.34.12.128/25`.
- IPv6 /32: `2001:DB8::/32` (Internal global) — гэхдээ ISP-руу зарлахад public IPv6 block байх ёстой. (`2001:DB9::/32` — ISP-A external. Уг нь GW-1-ийн өөрийн public range.)
- Конфиг:
  ```
  router bgp 17000
   address-family ipv4
    network 133.34.12.0 mask 255.255.255.128
    network 133.34.12.128 mask 255.255.255.128
   address-family ipv6
    network 2001:DB8::/32
  ```
- ISP-руу зарлах өмнө `ip prefix-list` буюу `ip route Null0`-аар originate хийж болно.

### BGP-2 — Implementation — 3 pts
> CorpGW router 1 нь интернэтийн үндсэн гарц байх ба BGP route-үүдийн хувьд бүгд ISP-A аар гарах тул тохиргоог хийнэ үү

> ⚠ Даалгавар "CorpGW router 1" гэж нэрлэсэн ч ISP-руу холбогддог нь **GW-1 (wan-rtr01)**. ISP-A AS 18000 нь wan-rtr01-аар.

Шийдэл сонголт:
- **Inbound (ISP-аас ирэх):** wan-rtr01 дээр `route-map ISP-A-IN` доторх `set local-preference 200` (default 100). iBGP-р GW-2-руу гарвал бага local-pref → primary GW-1 болно.
- **Outbound (ISP-руу гарах):** AS-PATH prepend GW-2 талд (ISP-B), эсвэл GW-1 талд `set as-path prepend 17000` биш — харин GW-2 талд prepend нэмж GW-1-ээр илүү таталцсан болгоно.
- Эсвэл GW-2 талд `route-map OUT_TO_ISP_B` дээр `set local-preference 50` буюу AS-PATH prepend.
- Best practice: local-pref + MED + AS-PATH ашиглана.

### BGP-3 — Implementation — 4 pts
> ISP-ээс ирж буй BGP community-тай IPv6 сүлжээнүүг GW2-оор гаргах ба community-г new format-аар нь барьж авна. Бусад бүх сүлжээг GW1-ээр явуулна

- `ip bgp-community new-format` — globally enable
- `ip community-list standard ISP-COMM permit <asn>:<value>` (jшээ `19000:100`)
- `route-map FROM_ISP_B_IPv6 permit 10`
  - `match community ISP-COMM`
  - `set local-preference 200` (GW-2-аар preferred)
- IPv6 хувьд `ipv6 community-list` ашиглана.
- BGP-2 (GW-1 primary)-тай тэнцвэртэй болгох — community-тай ipv6-ийн хувьд **зөвхөн** GW-2 талыг сонгоно.

---

## Owner: Altai — OSPF + VRRP + NAT + IPSec (22 pts)

### VRRP — Implementation — 2 pts
> CorpGW-1 router ийн uplink унасан тохиолдолд **санхүүгийн албаны** сүлжээний active гарцны төхөөрөмж нь CorpGW-2 болох ёстой

⚠ Зохион байгуулагч: "vlan 30 гэж буруу бичсэн, **vlan 20** шүү". → FinDep (vlan 20).

**Одоогийн төлөв (corp-dsw01 / corp-dsw02):**
- corp-dsw01 (CorpGW-1) Vlan20: `vrrp 20 ip 10.1.1.254`, `vrrp 20 priority 110` ⇒ active.
- corp-dsw02 (CorpGW-2) Vlan20: `vrrp 20 ip 10.1.1.254` (default priority 100) ⇒ standby.
- Track interface object **байхгүй** → uplink (Vlan1010 эсвэл Vlan1020) унаход priority decrement байхгүй.

**Шийдэл (corp-dsw01 дээр):**
```
track 10 interface Vlan1020 line-protocol      ! FinDep uplink
!
interface Vlan20
 vrrp 20 track 10 decrement 30                 ! 110 - 30 = 80 < 100 → switchover
```
(нөгөө Vlan1010, Vlan1011-ыг ч мөн object track хийж болно)

### OSPF-1 — Troubleshooting — 2 pts
> Техникийн болон санхүүгийн албаны гарцны төхөөрөмжөөс харгалзах хаягуудыг dynamic routing протокоор зарлах, дутуу тохиргоог гүйцээх

corp-dsw01 / corp-dsw02 дээр:
- `router ospf 2 vrf FinDep` болон `router ospf 3 vrf TechDep`-д Loopback Lo3 (FinDep), Lo4 (TechDep) болон Vlan20/Vlan30 SVI-нд network statement-үүд бүрэн уу шалгах.
- corp-dsw02 дээр Vlan20 / Vlan30 (10.1.1.0/24, 10.1.2.0/24) **OSPF-д байхгүй** байх магадлалтай — `network 10.1.1.0 0.0.0.255 area 10`-ыг VRF FinDep ospf-д нэмэх.
- IPv6 (ospfv3) хувьд address-family vrf FinDep / TechDep дээр network coverage шалга.

### OSPF-2 — Implementation — 3 pts
> Fusion Router дээр dynamic routing protocol-ийн default тохиргоо нь интерфэйсүүд дээр neighbor relationship үүсгэхийг хориглох мөн зөвхөн шаардлагатай интерфэйсүүд дээр уг тохиргоог идэвхгүй болгож, routing neighbor үүсгэхээр тохируулна.

- Fusion-rtr01 `router ospf 1` дээр **`passive-interface default` алга** — нэмэх.
- Дараа нь `no passive-interface GigabitEthernet0/X.YYY` ашиглан зөвхөн neighbor-тэй interface-ийг идэвхжүүлэх.
- IPv6 (ospfv3 1) — аль хэдийн `passive-interface default` тавьсан ✓.

### OSPF-3 — Implementation — 2 pts
> CorpGW-2 router дээр ipv6 dynamic routing protocol ийн тохиргоог хийж гүйцэтгэх

corp-dsw02 (CorpGW-2)-д **`router ospfv3 1` блок огт байхгүй**. corp-dsw01-аас яг адил байдлаар нэмэх:
```
router ospfv3 1
 router-id 10.1.18.4
 address-family ipv6 unicast
  passive-interface default
  no passive-interface Vlan1010
  no passive-interface Vlan1011
 exit-address-family
 address-family ipv6 unicast vrf FinDep
  passive-interface default
  no passive-interface Vlan1020
  no passive-interface Vlan1021
 exit-address-family
 address-family ipv6 unicast vrf TechDep
  passive-interface default
  no passive-interface Vlan1030
  no passive-interface Vlan1031
 exit-address-family
```
+ Vlan20/Vlan30 SVI-д `ospfv3 1 ipv6 area 10` нэмэх (хэрвээ дутуу бол).

### OSPF-4 — Implementation — 2 pts
> IPv6 сүлжээний хувьд WAN router ээс BGP-гийн default route ээс үл харгалзан дотоод сүлжээнд байнгын default route зарлах тохиргоог хийж гүйцэтгэ

wan-rtr01 + wan-rtr02 `router ospfv3 1` дотор:
```
router ospfv3 1
 address-family ipv6 unicast
  default-information originate always
 exit-address-family
```
`always` keyword — BGP default route байхгүй ч OSPFv3-аас ::/0 announce хийнэ.

### OSPF-5 — Troubleshooting — 3 pts
> Finance department болон Technology department -ийн default route суралцахгүй байгаа асуудлыг шийдвэрлэнэ үү?

- corp-dsw01 / corp-dsw02 дээр `router ospf 2 vrf FinDep`, `router ospf 3 vrf TechDep` нь default route originate хийдэггүй.
- Эх үүсвэр: дотоод default route нь Fusion-rtr01-д `router ospf 1` `default-information originate` ✓ — гэхдээ энэ нь global routing table-д. VRF FinDep / TechDep сүлжээний доторх OSPF process нь уг default-ыг **redistribute** хийх хэрэгтэй.
- Шийдэл: CorpGW (corp-dsw01/02) дээр VRF-ийн iface FinDep-д `default-information originate always` тавих, эсвэл VRF route-leak-аар default-ыг шилжүүлж дараа нь redistribute хийх.

### NAT — Troubleshooting — 2 pts
> Байгууллагын дотоод сүлжээнээс(FinDep, TechDep) интернэт холбогдохгүй байгаа асуудлыг шийднэ үү?

wan-rtr01-д `ip nat pool 1 133.34.12.100 133.34.12.254 ...` зарласан — гэхдээ:
- ❌ `ip nat inside source list <ACL> pool 1` rule **байхгүй**
- ❌ `interface ... ip nat inside` / `ip nat outside` **аль ч interface дээр алга**
- ❌ FinDep/TechDep VRF дотроос NAT хийх — VRF-aware NAT шаардлагатай (`ip nat inside source list ACL pool POOL vrf FinDep`)

**Шийдэл (wan-rtr01):**
```
ip access-list extended NAT_ACL
 permit ip 10.1.1.0 0.0.0.255 any        ! FinDep
 permit ip 10.1.2.0 0.0.0.255 any        ! TechDep
!
ip nat inside source list NAT_ACL pool 1 vrf FinDep overload
ip nat inside source list NAT_ACL pool 1 vrf TechDep overload
!
interface GigabitEthernet0/2
 ip nat outside
!
interface GigabitEthernet0/0.300
 ip nat inside
```
(VRF-aware NAT-ын хувьд тус бүр-аас route leak шаардлагатай байж болно. Лабын шалгуурын дагуу `ip vrf forwarding`-ийг өөрчлөхгүйгээр `ip nat ... vrf` түлхүүрийг ашиглах.)

### IPsec — Implementation — 4 pts
> Байгууллагын дотоод сүлжээ болон салбарын дотоод сүлжээг холбосон site to site VPN тохиргоог BrachGW болон GW-1 router дээр хийж гүйцэтгэнэ үү?

wan-rtr01-д ACL 101 нь өмнөх IPSec шалгуурыг харуулна:
```
access-list 101 permit ip 10.1.1.0 0.0.0.255 10.1.8.0 0.0.0.255    ! FinDep ↔ Branch
access-list 101 permit ip 10.1.2.0 0.0.0.255 10.1.8.0 0.0.0.255    ! TechDep ↔ Branch
```

**Шийдэл — IKEv2 (preferred) эсвэл IKEv1:**
```
crypto ikev2 keyring KR
 peer BR1GW
  address <Br1GW public ip>
  pre-shared-key local <PSK>
  pre-shared-key remote <PSK>
!
crypto ikev2 profile PROF
 match identity remote address <Br1GW public ip>
 authentication remote pre-share
 authentication local pre-share
 keyring local KR
!
crypto ipsec transform-set TS esp-aes esp-sha-hmac
 mode tunnel
!
crypto ipsec profile IPSEC_PROF
 set transform-set TS
 set ikev2-profile PROF
!
interface Tunnel0
 ip address 192.168.255.1 255.255.255.252
 tunnel source GigabitEthernet0/2
 tunnel destination <Br1GW public ip>
 tunnel mode ipsec ipv4
 tunnel protection ipsec profile IPSEC_PROF
!
ip route 10.1.8.0 255.255.255.0 Tunnel0
```
Br1GW талд тэр чигийн mirror config (VRF Globally).

---

## Owner: Byambaa — Service / DevOps / Troubleshoot (12 pts)

### NTP — Service — 2 pts
> Fusion router#1 дээр NTP Master тохиргоо хийнэ үү, Fusion router#2-ын цагийн тохиргоогоо fusion router#1-ээс авна. Fusion router#1 цагаа EVE-NG системийн хаягаасаа sync хийдэг байхаар тохируулна. Цагийн бүсийг ULAT 8 байхаар заана. Source interface-ийг төхөөрөмжийн management interface-ээр хийх хэрэгтэйг санаарай.

**Fusion-rtr01:**
```
clock timezone ULAT 8
ntp source Loopback1                      ! mgmt loopback (10.1.17.3)
ntp server <EVE-NG host IP>               ! e.g. 36.50.7.52 — local mgmt subnet via VRF mgmt
ntp master 3
```
> Анхаар: Loopback1 нь Fusion дээр VRF биш (10.1.17.3 global). Хэрэв даалгавар "management interface"-ийг VRF mgmt interface гэж ойлгож байгаа бол Lo3 (vrf mgmt)-ийг ашиглана. Configs-аас Fusion-rtr01-д VRF mgmt тодорхойлогдоогүй — wan-rtr-д л байгаа.

**Fusion-rtr02:**
```
clock timezone ULAT 8
ntp source Loopback1                      ! 10.1.17.6
ntp server 10.1.17.3                      ! Fusion-rtr01 Lo1
```

### HSRP — Service — 2 pts
> CorpGW#2 дээр Vlan 30-ийн HSRP Master төлөвийг шилжүүлэх тохиргоог хийнэ үү.

corp-dsw02 одоогийн Vlan30:
```
standby version 2
standby 30 priority 150
standby 30 preempt
standby 30 track 1 decrement 60
```
- Track object 1 нь `interface Loopback5 line-protocol`. Loopback5 → `shutdown`. ⇒ `standby 30 priority` нь 150-60=90 болно. corp-dsw01 Vlan30 standby priority default 100 → corp-dsw01 active.
- Шилжүүлэхэд: Loopback5 unshut (→track up→priority 150) эсвэл track ашиглахгүй болгох. Эсвэл `standby 30 priority 200` тавих.

**Шийдэл:**
```
interface Loopback5
 no shutdown
```
эсвэл:
```
interface Vlan30
 no standby 30 track 1 decrement 60
```

### TCLSH — DevOps — 2 pts
> Fusion router болон Wan router-ийн OSPF BGP Status-уудыг шалгадаг TCLSH script-ийг хөгжүүл. Script-ыг wan router#1 дээр statuscheck нэртэй file үүсгэн хадгална.

wan-rtr01 (`tclsh`):
```tcl
tclsh
puts [ exec "show ip ospf neighbor" ]
puts [ exec "show ipv6 ospf neighbor" ]
puts [ exec "show ip bgp summary" ]
puts [ exec "show bgp ipv6 unicast summary" ]
tclquit
```

`statuscheck` гэсэн нэртэйгээр flash-д хадгална:
```
wan-rtr01# tclsh
(tcl)# puts [open "flash:statuscheck" w+] ...
```
Эсвэл config-аас:
```
file prompt quiet
copy running-config flash:statuscheck
```
Зорилго: **`flash:statuscheck`-д tcl скрипт хадгалаад `tclsh flash:statuscheck`-аар ажиллуулах**.

### OSPF-6 — Troubleshooting — 2 pts
> Fusion router#2 дээр өгсөн OSPF Log дээрээс асуудлыг илрүүлж Neighbor full болохгүй байгаа асуудлыг шийдвэрлэж засварла

**Олсон бөглөл:**
- Fusion-rtr02 `interface GigabitEthernet0/0.1020` (vlan1020 → CorpGW-2 FinDep):
  ```
  ip ospf authentication message-digest
  ip ospf message-digest-key 1 md5 ospfkeyl1234        ! "l" жижиг үсэг
  ```
- corp-dsw02 `interface Vlan1020`:
  ```
  ip ospf authentication message-digest
  ip ospf message-digest-key 1 md5 ospfkeyI1234        ! "I" том үсэг
  ```
- Md5 key зөрсөн → OSPF authentication fail → neighbor нэгдэхгүй (EXCHANGE/LOADING-д наалдана).

**Шийдэл:** хоёр талд нэг ижил key string ашиглах. Жишээ:
```
interface ...
 no ip ospf message-digest-key 1
 ip ospf message-digest-key 1 md5 ospfkey12345
```

### TFTP-1 — Service — 2 pts
> Corp-esw#3 ийн дээр hardware гэмтсэний улмаас төхөөрөмж эвдэрсэн тул сүлжээний инженер шинээр төхөөрөмж суурилуулсан. Хуучин төхөөрөмжийн тохиргоо TFPT Server дээр хадгалагдаж байгаа тул backup тохиргоог switch-рүү татаж авч үйлчиллэгээг сэргээ. corp-esw03-confg

CorpSW-3 (corp-esw03) дээр:
```
copy tftp://<TFTP-IP>/corp-esw03-confg startup-config
reload
```
Эсвэл running-руу шууд:
```
copy tftp://<TFTP-IP>/corp-esw03-confg running-config
write memory
```

### TFTP-2 — Implementation — 2 pts
> Corp-esw01 тохиргоогоо backup хийдэг тохиргоо байхгүй, Corp-esw02 дээр гарсан асуудал дахин үүсэхээс сэргийлж төхөөрөмжүүдийн running-config ийг TFTP Server-лүү 10 минут тутамд automate-аар хадгалдаг шийдлийг олж хэрэгжүүл. TFTP Server дээр тохиргоог хадгалахдаа Hostname-time форматаар хадгална.

**EEM applet (corp-esw01 + corp-esw02 дээр):**
```
event manager applet TFTP_BACKUP
 event timer cron name backup_10m cron-entry "*/10 * * * *"
 action 1.0 cli command "enable"
 action 1.1 cli command "show clock | format flash:time.fmt"
 action 1.2 cli command "copy running-config tftp://<TFTP-IP>/$(hostname)-$(time)"
 action 1.3 syslog msg "Config backed up to TFTP"
```

**Илүү найдвартай:**
```
event manager environment TFTP_HOST <ip>
event manager applet BACKUP
 event timer cron cron-entry "*/10 * * * *"
 action 1.0 cli command "enable"
 action 1.1 cli command "term len 0"
 action 1.2 cli command "copy running-config tftp://$TFTP_HOST/$_event_pub_time-`hostname`"
```
> Filename форматын талаар олимпиадын шалгуурыг яг таг уншиж сонгох. `Hostname-time` нэгдсэн tokens.

### STP — Troubleshooting — 2 pts
> corp-esw02 ийн Uplink нь CorpGW-1 рүү холбогдсон холболт бүх vlan spanning-tree block төлөвт орсон асуудлыг засварла.

**Олсон шалтгаан:**
- corp-esw02 `interface Ethernet0/1` (description `to_corp-dsw01` = CorpGW-1) → `spanning-tree guard root`.
- CorpGW-1 (corp-dsw01) priority бага байх ёстой root bridge → corp-esw02 талаас `guard root` нь "BPDU-аас илүү superior priority" харсан → port → **root-inconsistent (block)**.

**Шийдэл:**
```
interface Ethernet0/1
 no spanning-tree guard root
```
Эсвэл CorpGW-1-ийг root bridge гэж зөвшөөрч, corp-esw02-ийн priority-г өсгөнө.

---

## Bird's-eye summary

| # | Task | Owner | Type | Pts | Touch device(s) |
|---|---|---|---|---|---|
| 1 | iBGP | Ulsaa | Trbl | 3 | wan-rtr01 (Lo2 OSPF advertise) |
| 2 | BGP-1 | Ulsaa | Impl | 2 | wan-rtr01, wan-rtr02 (network statements) |
| 3 | BGP-2 | Ulsaa | Impl | 3 | wan-rtr01 (route-map IN: local-pref) |
| 4 | BGP-3 | Ulsaa | Impl | 4 | wan-rtr01/02 (community-list, route-map IPv6) |
| 5 | VRRP | Altai | Impl | 2 | corp-dsw01 (track + VRRP track) |
| 6 | OSPF-1 | Altai | Trbl | 2 | corp-dsw01/02 (FinDep/TechDep network) |
| 7 | OSPF-2 | Altai | Impl | 3 | Fusion-rtr01/02 (passive-default) |
| 8 | OSPF-3 | Altai | Impl | 2 | corp-dsw02 (router ospfv3 нэмэх) |
| 9 | OSPF-4 | Altai | Impl | 2 | wan-rtr01/02 (ospfv3 default originate always) |
| 10 | OSPF-5 | Altai | Trbl | 3 | corp-dsw01/02 VRF-уудад default-info |
| 11 | NAT | Altai | Trbl | 2 | wan-rtr01 (ip nat inside source vrf) |
| 12 | IPsec | Altai | Impl | 4 | wan-rtr01 + Br1GW (IKEv2) |
| 13 | NTP | Byambaa | Svc | 2 | Fusion-rtr01 master, -02 client |
| 14 | HSRP | Byambaa | Svc | 2 | corp-dsw02 Vlan30 priority |
| 15 | TCLSH | Byambaa | DevOps | 2 | wan-rtr01 statuscheck file |
| 16 | OSPF-6 | Byambaa | Trbl | 2 | Fusion-rtr02 vlan1020 md5 key (typo: l vs I) |
| 17 | TFTP-1 | Byambaa | Svc | 2 | CorpSW-3 (copy tftp:..) |
| 18 | TFTP-2 | Byambaa | Impl | 2 | corp-esw01/02 EEM applet |
| 19 | STP | Byambaa | Trbl | 2 | corp-esw02 Eth0/1 guard root |

**Нийт: 46 pts.** Mix: 9× Implementation (24 pts), 7× Troubleshooting (16 pts), 3× Service (6 pts), 1× DevOps (2 pts hidden in Byambaa).

> Лабын шалгуурын `pts` тохирвол total ≠ 46 байж болзошгүй — UI snapshot үед 19 task ил харагдсан, 20-р task scroll доор оршиж байж болно. Дахин шалга.

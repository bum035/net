# OSPF Cheatsheet

> IOS / IOS-XE / NX-OS — олимпиадын дунд интернет тасрахад fallback

## Area types

| Type | Хэдэн LSA | Default route auto | Use case |
|---|---|---|---|
| Normal area 0 (backbone) | 1, 2, 3, 4, 5 | Үгүй | Backbone |
| Standard area | 1, 2, 3, 4, 5 | Үгүй | Internal area |
| Stub | 1, 2, 3, 4 (no 5) | Үгүй (manual) | No external route |
| Totally stub | 1, 2 (no 3, 4, 5) | **Тийм** (auto) | Бүх external + inter-area block |
| NSSA | 1, 2, 3, 4, 7 | Үгүй (manual) | ASBR байгаа stub |
| Totally NSSA | 1, 2, 7 | **Тийм** (auto) | Stub + redistribute зөвшөөрсөн |

```cisco
area 10 stub                              ! standard stub
area 10 stub no-summary                    ! totally stubby (default route auto)
area 10 nssa                               ! NSSA
area 10 nssa no-summary                    ! totally NSSA
area 10 nssa default-information-originate ! NSSA + advertise default
```

## Process & router-id

```cisco
router ospf 1
 router-id 1.1.1.1                ! заавал loopback IP
 log-adjacency-changes detail
 auto-cost reference-bandwidth 100000   ! 100Gbps reference (default 100Mbps)
 passive-interface default
 no passive-interface GigabitEthernet0/0
!
! Network statement vs interface-mode
network 10.0.0.0 0.0.0.255 area 0   ! IOS classic
!
interface Loopback0                  ! IOS-XE recommended
 ip ospf 1 area 0
```

## VRF-aware OSPF

```cisco
ip vrf FinDep
 rd 65000:1
!
interface Gi0/1
 ip vrf forwarding FinDep    ! IP address-аас өмнө!
 ip address 10.10.1.1 255.255.255.0
 ip ospf 2 area 10
!
router ospf 2 vrf FinDep
 router-id 2.2.2.2
 redistribute bgp 65000 vrf FinDep subnets
```

⚠ **Pitfall:** `ip vrf forwarding`-ийг IP-аас өмнө тавиагүй бол IP арилна. Бичээд дахин нэм.

## Redistribute

```cisco
router ospf 1
 redistribute connected subnets metric 100 metric-type 2
 redistribute static subnets metric 50  metric-type 1
 redistribute bgp 65000 subnets metric 200
!
! Filter (route-map ашиглах)
redistribute connected route-map FILTER-CONN subnets
!
route-map FILTER-CONN permit 10
 match ip address prefix-list ALLOW
ip prefix-list ALLOW seq 10 permit 192.168.0.0/16 le 24
```

| Keyword | Тайлбар |
|---|---|
| `subnets` | /32 host, /30 link route-уудыг redistribute хийнэ. **Заавал нэм.** |
| `metric-type 1` (E1) | Internal cost + external cost (transitive) |
| `metric-type 2` (E2) | Зөвхөн external cost (default) |

## Authentication

```cisco
! Plain
interface Gi0/0
 ip ospf authentication
 ip ospf authentication-key olymp123
!
! MD5
interface Gi0/0
 ip ospf message-digest-key 1 md5 olymp123
 ip ospf authentication message-digest
!
! Per-area (бүх interface area-д орох)
router ospf 1
 area 0 authentication              ! plain
 area 0 authentication message-digest  ! MD5
```

## OSPFv3 (IPv6)

```cisco
ipv6 unicast-routing
!
ipv6 router ospf 1
 router-id 1.1.1.1
!
interface Gi0/0
 ipv6 enable
 ipv6 ospf 1 area 0
```

## Verify

```cisco
show ip ospf neighbor                   ! adjacency state
show ip ospf neighbor detail            ! priority, dead time, retransmit
show ip ospf interface brief
show ip ospf interface Gi0/0            ! cost, hello, dead, auth
show ip ospf database                   ! бүх LSA
show ip ospf database router 1.1.1.1    ! type-1 LSA
show ip ospf database summary           ! type-3 ABR LSA
show ip ospf database external          ! type-5
show ip route ospf
show ip protocols                       ! redistribute info
```

## Adjacency states

```
Down → Init → 2-Way → ExStart → Exchange → Loading → Full
```

| Stuck-аас | Шалтгаан |
|---|---|
| Init | Hello received, neighbor биш — DR election? subnet mask mismatch |
| 2-Way | Адил interface дээр multicast received, гэхдээ DR/BDR байх ёсгүй |
| ExStart | MTU mismatch (`debug ip ospf adj`) |
| Exchange | LSA mismatch — area type mismatch (e.g. one stub, one normal) |
| Loading | LSA timeout — overload condition |

## Common pitfalls

- `network` statement-ийг wildcard mask-аар (НЕ subnet mask)
- Hello/dead timer mismatch → adjacency-аас гарч ирнэ
- Area type mismatch (бүгд stub эсвэл бүгд normal байх ёстой)
- Authentication mismatch
- Passive-interface дээр neighbor establish болохгүй
- MTU mismatch → ExStart stuck (`ip ospf mtu-ignore` workaround)

# Lab-02 — BGP Full Stack: iBGP RR + eBGP + TE

> **Жин:** 20% (~55 минут)
> **Платформ:** Cisco IOS / IOS-XE
> **Гол сэдэв:** iBGP route reflector, eBGP peering, BGP TE (local-pref / MED / AS-path / community)

## Чухал items

- **AS дугаар** (one or two ASes)
- **iBGP топологи** — RR + clients, эсвэл full mesh
- **eBGP peer** — direct connected vs multihop (loopback peering)
- **TE attribute** — local-preference, MED, AS-path prepend, community
- **Route filter** — prefix-list, route-map (in/out)
- **IPv4 vs IPv6** family
- **Authentication** — `password` (MD5)
- **Хязгаарлалт** — "AS path prepend хориглох", "community ашиглах ёстой"

## Config skeleton

### iBGP RR (RR1)

```cisco
router bgp 65001
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 no bgp default ipv4-unicast
 ! ── neighbor definitions
 neighbor RR-CLIENTS peer-group
 neighbor RR-CLIENTS remote-as 65001
 neighbor RR-CLIENTS update-source Loopback0
 neighbor RR-CLIENTS password olymp
 neighbor 2.2.2.2 peer-group RR-CLIENTS
 neighbor 3.3.3.3 peer-group RR-CLIENTS
 !
 address-family ipv4 unicast
  neighbor RR-CLIENTS activate
  neighbor RR-CLIENTS route-reflector-client
  neighbor RR-CLIENTS next-hop-self
 exit-address-family
 !
 address-family ipv6 unicast
  neighbor RR-CLIENTS activate
  neighbor RR-CLIENTS route-reflector-client
 exit-address-family
```

### eBGP w/ TE (R-edge)

```cisco
router bgp 65001
 neighbor 192.0.2.1 remote-as 65002
 neighbor 192.0.2.1 description PEER-AS65002
 neighbor 192.0.2.1 ebgp-multihop 2          ! loopback peering бол
 neighbor 192.0.2.1 update-source Loopback0
 !
 address-family ipv4
  neighbor 192.0.2.1 activate
  neighbor 192.0.2.1 send-community
  neighbor 192.0.2.1 route-map IN-PEER in
  neighbor 192.0.2.1 route-map OUT-PEER out
 exit-address-family
!
! ── TE: prefer egress via 192.0.2.1 ──
ip prefix-list LOCAL-NETS seq 10 permit 10.0.0.0/16 le 24
!
route-map IN-PEER permit 10
 match ip address prefix-list LOCAL-NETS
 set local-preference 200
!
route-map OUT-PEER permit 10
 set community 65001:100 additive
 set as-path prepend 65001 65001     ! хэрэв зөвшөөрөгдсөн бол
```

## Verify commands

```cisco
show ip bgp summary
show ip bgp neighbors 2.2.2.2 | i state|password|update-source|reflector
show ip bgp                                    ! бүх prefix
show ip bgp 10.0.0.0/24                        ! тодорхой prefix
show ip bgp regexp _65002_                     ! AS65002-аар явсан
show ip bgp community 65001:100
show ip route bgp
```

## Common pitfalls

| Pitfall | Шийдэл |
|---|---|
| BGP neighbor "Active" наалдсан | TCP 179-руу хүрэхгүй. `update-source loopback0` тохирсон уу? `ebgp-multihop` хэрэг бол multihop тоо? Password match? |
| iBGP next-hop unreach | RR client-руу `next-hop-self` тавиагүй. RR дээр `neighbor X next-hop-self` нэм |
| RR client-руу route reflect болохгүй | `route-reflector-client` нь **RR-аас** (server) идэвхжинэ, client-аас биш |
| AS-path prepend хориглосон → MED/community ашиглах | `set local-preference` (inbound), `set metric` (outbound MED), community-ийн filter on far peer |
| IPv6 prefix-аар advertise хийхгүй | `address-family ipv6 unicast` дотор `network` командаа дахин нэмэх + `activate` |
| eBGP loopback peering link drop-д survive болохгүй | OSPF-ээр loopback reachable байж IGP мэдэгдэх ёстой |

## AI prompt

```
BGP TE: AS65001 → AS65002 traffic-ыг peer X-ээр гаргах. AS-path prepend
хориглосон. Local-pref + community ашиглана.

show ip bgp summary:
<paste>

show run | sec router bgp:
<paste>

show ip bgp 10.0.0.0/24:
<paste>

Засварыг өг. route-map ашиглаж local-pref 200 + community
65001:100 ашиглах. Пир дамжуулагч side-аас inbound филтрлэх.
```

## Push back

```bash
python3 ~/net/scripts/olymp-run.py --mode push --push-cfg <file> --slow
```

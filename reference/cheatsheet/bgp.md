# BGP Cheatsheet

> IOS / IOS-XE / NX-OS — eBGP, iBGP, RR, TE attribute

## Neighbor states

```
Idle → Connect → Active → OpenSent → OpenConfirm → Established
```

| State stuck | Шалтгаан |
|---|---|
| Idle (admin) | `neighbor X shutdown` идэвхтэй |
| Active | TCP 179 хүрэхгүй — IP unreach, ACL block, password mismatch |
| OpenSent | AS number, BGP version mismatch, hold-time |
| OpenConfirm | TCP OK ч KEEPALIVE late |

## iBGP / eBGP basic

```cisco
router bgp 65001
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 no bgp default ipv4-unicast       ! сайн дадал — manual activate
!
 ! ── eBGP direct ──
 neighbor 192.0.2.1 remote-as 65002
 neighbor 192.0.2.1 description PEER-AS65002
 neighbor 192.0.2.1 password olymp
!
 ! ── eBGP loopback (multihop) ──
 neighbor 2.2.2.2 remote-as 65002
 neighbor 2.2.2.2 ebgp-multihop 2
 neighbor 2.2.2.2 update-source Loopback0
!
 ! ── iBGP ──
 neighbor 3.3.3.3 remote-as 65001
 neighbor 3.3.3.3 update-source Loopback0
!
 address-family ipv4 unicast
  neighbor 192.0.2.1 activate
  neighbor 2.2.2.2   activate
  neighbor 3.3.3.3   activate
  neighbor 3.3.3.3   next-hop-self
  network 10.0.0.0 mask 255.255.0.0
 exit-address-family
```

## Route reflector (iBGP scaling)

```cisco
! ── RR side ──
router bgp 65001
 neighbor RR-CLIENTS peer-group
 neighbor RR-CLIENTS remote-as 65001
 neighbor RR-CLIENTS update-source Loopback0
 neighbor 2.2.2.2 peer-group RR-CLIENTS
 neighbor 3.3.3.3 peer-group RR-CLIENTS
!
 address-family ipv4 unicast
  neighbor RR-CLIENTS activate
  neighbor RR-CLIENTS route-reflector-client    ! зөвхөн RR-аас
  neighbor RR-CLIENTS next-hop-self
 exit-address-family
```

⚠ **Pitfall:** `route-reflector-client` нь RR-аас (server) idэвхжинэ. Client side-аас тавьвал ажиллахгүй.

## Address families

```cisco
router bgp 65001
 address-family ipv4 unicast
  network ...
 exit-address-family
!
 address-family ipv6 unicast
  network 2001:db8::/32
 exit-address-family
!
 address-family vpnv4
  neighbor X activate
  neighbor X send-community both
 exit-address-family
!
 address-family ipv4 vrf CUST-A
  redistribute connected
 exit-address-family
```

## Path attributes (TE — preference дараалал)

| # | Attribute | Higher/Lower | Scope |
|---|---|---|---|
| 1 | Weight | Higher wins | **Local only** (Cisco proprietary) |
| 2 | Local-preference | Higher wins | iBGP (within AS) |
| 3 | Locally originated | Network/aggregate first | Local |
| 4 | AS-path length | **Shorter** wins | All |
| 5 | Origin | IGP < EGP < Incomplete | All |
| 6 | MED | **Lower** wins | Inter-AS (advise neighbor) |
| 7 | eBGP > iBGP | Prefer eBGP | All |
| 8 | IGP metric to next-hop | Lower wins | Local |
| 9 | Older eBGP route | Stability | Local |
| 10 | Lower router-id | Tiebreak | All |

## Route-map TE

```cisco
! ── Inbound: prefer this peer for traffic ──
ip prefix-list LOCAL-NETS seq 10 permit 10.0.0.0/16 le 24
!
route-map IN-PEER-A permit 10
 match ip address prefix-list LOCAL-NETS
 set local-preference 200          ! higher = prefer
!
! ── Outbound: advertise with prepend / community ──
route-map OUT-PEER-B permit 10
 set as-path prepend 65001 65001 65001  ! make us less attractive
 set community 65001:100 additive
!
router bgp 65001
 address-family ipv4
  neighbor 192.0.2.1 route-map IN-PEER-A in
  neighbor 192.0.2.1 route-map OUT-PEER-B out
  neighbor 192.0.2.1 send-community
```

## Communities

```cisco
ip community-list 1 permit 65001:100
!
route-map FILTER-COMM permit 10
 match community 1
 set local-preference 50
!
! Specific values
no-export       ! зөвхөн iBGP-руу advertise
no-advertise    ! огт advertise хийхгүй
local-AS        ! confederation-аас гарахгүй
```

## Authentication

```cisco
neighbor 192.0.2.1 password olymp123    ! TCP MD5
```

## Verify

```cisco
show ip bgp summary                          ! бүх neighbor + state
show ip bgp neighbors 2.2.2.2                ! detail
show ip bgp neighbors 2.2.2.2 advertised     ! явсан route
show ip bgp neighbors 2.2.2.2 received       ! ирсэн route (soft-recon)
show ip bgp                                   ! BGP RIB
show ip bgp 10.0.0.0/24                       ! тодорхой prefix path
show ip bgp regexp _65002_                    ! AS65002-аар явсан
show ip bgp community 65001:100
show ip route bgp
clear ip bgp 192.0.2.1 soft in                ! soft reset (no flap)
```

## NX-OS ялгаа

```cisco
feature bgp
!
router bgp 65001
 router-id 1.1.1.1
 address-family ipv4 unicast
  network 10.0.0.0/16
 neighbor 192.0.2.1
  remote-as 65002
  address-family ipv4 unicast
   send-community
   route-map IN in
```

⚠ NX-OS дотор `address-family` нь **neighbor дотор** буухгүй вэ хэрэглэх.

## Common pitfalls

- iBGP next-hop unreach → RR дээр `next-hop-self` идэвхжүүлэх
- eBGP loopback peering → `ebgp-multihop N` + IGP-аас loopback reach
- AS-path prepend хориглосон → community + local-pref ашиглах
- Route filter direction (in vs out) — `out` нь **advertise хийсний өмнө**
- `send-community` бичээгүй бол community attribute alga
- `network` statement subnet mask нь яг IGP-той тохирох ёстой

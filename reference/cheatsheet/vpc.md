# vPC Cheatsheet (NX-OS)

> Cisco Nexus 9000-K — virtual Port-Channel + MCLAG

## Топологи

```
       +--------+ peer-link (Po1) +--------+
       | N9K-1  |================>| N9K-2  |
       +---+----+                 +---+----+
           | Po10 (vPC 10)            | Po10 (vPC 10)
           +--------+   Host   +------+
                    +----------+
                       LACP active
```

## Pre-requisite

```cisco
feature vpc
feature lacp
feature interface-vlan
!
spanning-tree mode rapid-pvst       ! эсвэл mst
```

## peer-keepalive (mgmt0 / management VRF)

```cisco
vrf context management
 ip route 0.0.0.0/0 10.99.99.254
!
interface mgmt0
 vrf member management
 ip address 10.99.99.1/24            ! N9K-2: 10.99.99.2
```

⚠ Peer-keepalive нь UDP/3200 — peer-link-аар БИШ, тусдаа path-аар явах ёстой.

## vPC domain

```cisco
vpc domain 100
 peer-switch                         ! adverse impact-аас сэргийлэх
 peer-keepalive destination 10.99.99.2 source 10.99.99.1 vrf management
 peer-gateway                        ! HSRP / VRRP MAC peer-аас accept
 ip arp synchronize
 auto-recovery                       ! peer-link тасарвал primary болж recover
 delay restore 150                   ! peer reload-ын дараа convergence wait
 role priority 10                    ! N9K-1: 10 (primary), N9K-2: 20
```

## peer-link (Po1)

```cisco
interface Ethernet1/47-48
 switchport
 switchport mode trunk
 switchport trunk allowed vlan 1-4094
 channel-group 1 mode active
 no shutdown
!
interface port-channel1
 switchport
 switchport mode trunk
 switchport trunk allowed vlan 1-4094
 spanning-tree port type network
 vpc peer-link
```

⚠ `vpc peer-link` нь **зөвхөн port-channel** дээр. Eth port дээр зөвшөөрөгдөхгүй.

## vPC member port-channel (host-руу)

```cisco
interface port-channel10
 switchport
 switchport mode trunk
 switchport trunk allowed vlan 10,20
 spanning-tree port type edge trunk
 vpc 10                              ! vPC ID — N9K-1, N9K-2 хоёулаа адил
!
interface Ethernet1/1
 switchport
 channel-group 10 mode active
 no shutdown
```

## Consistency parameters

| Type-1 (vPC suspend бол mismatch) | Type-2 (warning only) |
|---|---|
| STP mode (rapid-pvst vs mst) | Description |
| Peer-link STP mode (network port) | LACP rate (fast/slow) |
| MTU on vlan SVI | Trunk allowed vlan list (хэсэгчилсэн match OK) |
| Allowed VLAN list (per port-channel) | Spanning-tree priority |
| Native VLAN | |
| Voice VLAN | |

```cisco
show vpc consistency-parameters global       ! type-1 mismatch шалгах
show vpc consistency-parameters interface po10
```

## SVI / HSRP

```cisco
interface Vlan10
 no shutdown
 ip address 10.0.10.2/24
 hsrp 10
  priority 110                       ! N9K-1: 110, N9K-2: 100
  preempt
  ip 10.0.10.1
```

⚠ vPC + HSRP нь "active-active" болж ажилладаг (peer-gateway feature). Тус бүр пакетаа forward хийх боломжтой.

## Verify

```cisco
show vpc                                  ! ерөнхий
show vpc role                             ! primary / secondary
show vpc consistency-parameters global
show vpc consistency-parameters vpc 10
show vpc peer-keepalive
show port-channel summary
show spanning-tree summary | i ROOT|Edge
show running-config vpc
show feature | i vpc|lacp                 ! enable эсэх
```

## "show vpc" output

```
Legend:
                (*) - local vPC is down, forwarding via vPC peer-link

vPC domain id                     : 100
Peer status                       : peer adjacency formed ok
vPC keep-alive status             : peer is alive
Configuration consistency status  : success
Per-vlan consistency status       : success
Type-2 consistency status         : success
vPC role                          : primary
Number of vPCs configured         : 1
Peer Gateway                      : Enabled
Dual-active excluded VLANs        : -
Graceful Consistency Check        : Enabled
Auto-recovery status              : Enabled, timer is off.(timeout = 240s)
```

## Failure scenarios

| Шинж тэмдэг | Шалтгаан + засвар |
|---|---|
| `peer-keepalive: peer is not alive` | mgmt0 IP wrong, gateway бaйхгүй, `ping vrf management <peer>` |
| `peer-link: down` | LACP timeout, member port shutdown, MTU mismatch |
| `consistency: failed` | Type-1 attribute mismatch — `show vpc consistency-parameters global` уншиж нийцүүлэх |
| vPC member port `suspended` | LACP biш или vlan list mismatch |
| Both peers think themselves primary | Peer-keepalive down + peer-link up = **dual-active** — `peer-gateway exclude-vlan` болон `auto-recovery` шийдэл |

## Common pitfalls

- mgmt0 нь management VRF дээр л байх ёстой
- `peer-gateway` тавихгүй бол HSRP MAC хооронд траффик алдагдана
- vPC ID нь хоёр switch дээр **ижил** утгатай
- Member port-channel-ийн lacp mode хоёр switch дээр active байх ёстой (active+active)
- Reload-ын дараа convergence удаагдвал `delay restore` нэмэх
- `peer-switch` хийгээгүй бол vPC peer-аас learning bridge protocol asymmetric

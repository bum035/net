# lab2025 — Verify checklist

> Push дараа device бүр дээр ажиллуулах show command-уудыг task-р нь нэгтгэв.

## Pre-checks (бүх fix-ийн өмнө)

```
! Аль ч router дээр:
show ip ospf neighbor
show ipv6 ospf neighbor
show ip bgp summary
show bgp ipv6 unicast summary
show standby brief
show vrrp brief
show track brief
```

## Per-task verify

### Task 1 — iBGP (wan-rtr01)
```
wan-rtr01# show ip route 10.1.18.8                  ! Connected эсвэл OSPF
wan-rtr01# show ipv6 route 2001:DB8:ABCD:17::8/128
wan-rtr02# show ip route 10.1.18.8                  ! O 10.1.18.8/32 (OSPFv2-аас)
wan-rtr02# show ipv6 route 2001:DB8:ABCD:17::8      ! OE2 эсвэл OI
wan-rtr01# show ip bgp summary | inc 10.1.18.10     ! State Established
wan-rtr01# show bgp ipv6 unicast summary | inc 17:: ! Established
```

### Task 2 — BGP-1 (wan-rtr01 announce)
```
show ip route 133.34.12.0/25                         ! S 250 / Null0
show ip bgp 133.34.12.0/25                           ! Local origin "i"
show bgp ipv6 unicast 2001:DB8::/32
show ip bgp neighbors 202.43.65.1 advertised-routes  ! 133.34.12.0/25 + 133.34.12.128/25
```

### Task 3 — BGP-2 (ISP-A primary)
```
wan-rtr01# show ip bgp 0.0.0.0                       ! local-pref 200 (ISP-A)
wan-rtr02# show ip bgp 0.0.0.0                       ! local-pref 100 default → wan-rtr01-аас preferred
wan-rtr01# show ip bgp neighbors 202.43.65.1 routes | inc 200
wan-rtr02# show ip bgp neighbors 103.88.34.1 advertised-routes  ! AS-path prepend
```

### Task 4 — BGP-3 (community-based IPv6 → GW-2)
```
wan-rtr02# show bgp ipv6 unicast community <COMMUNITY_VAL>
wan-rtr02# show route-map ISP_B_v6_IN
wan-rtr02# show bgp ipv6 unicast neighbors 2001:D29:0:10::2 received-routes | inc community
```

### Task 5 — VRRP (corp-dsw01)
```
corp-dsw01# show track 10                            ! Up
corp-dsw01# show vrrp brief                          ! Vlan20 Master 110
! Test:
corp-dsw01# config t
corp-dsw01(config)# interface Vlan1020
corp-dsw01(config-if)# shutdown
corp-dsw02# show vrrp brief                          ! Vlan20 Master (failover)
corp-dsw01(config-if)# no shutdown                   ! revert
```

### Task 6 — OSPF-1 (FinDep/TechDep VRF coverage)
```
corp-dsw01# show ip route vrf FinDep | inc 10.1.1.0
corp-dsw01# show ip route vrf TechDep | inc 10.1.2.0
corp-dsw02# show ip route vrf FinDep | inc 10.1.1.0
corp-dsw02# show ip route vrf TechDep | inc 10.1.2.0
Fusion-rtr01# show ip route vrf FinDep | inc 10.1.1.0  ! VRF leak бол
```

### Task 7 — OSPF-2 (Fusion-rtr01 passive default)
```
Fusion-rtr01# show ip ospf interface | inc Hello|Passive
Fusion-rtr01# show ip ospf neighbor                    ! өмнөх neighbor-ууд хадгалагдсан
```

### Task 8 — OSPF-3 (corp-dsw02 ospfv3 нэмэгдсэн)
```
corp-dsw02# show running-config | sec router ospfv3
corp-dsw02# show ipv6 ospf neighbor
corp-dsw02# show ipv6 ospf interface | inc Vlan
```

### Task 9 — OSPF-4 (IPv6 default originate always)
```
wan-rtr01# show ipv6 ospf database | inc Type-7|External
wan-rtr01# show ipv6 ospf | inc external
Fusion-rtr01# show ipv6 route ::/0                   ! OE2 wan-rtr01-аас
corp-dsw01# show ipv6 route ::/0
```

### Task 10 — OSPF-5 (VRF default originate)
```
corp-dsw01# show ip route vrf FinDep | inc 0\.0\.0\.0  ! O*E2 0.0.0.0/0
corp-dsw01# show ip route vrf TechDep | inc 0\.0\.0\.0
corp-dsw02# show ip route vrf FinDep | inc 0\.0\.0\.0
```

### Task 11 — NAT (wan-rtr01)
```
wan-rtr01# show ip nat translations
wan-rtr01# show ip nat statistics
! Test:
PC-FinDep$ ping 8.8.8.8
wan-rtr01# show ip nat translations | inc 10.1.1
```

### Task 12 — IPsec
```
wan-rtr01# show crypto ikev2 sa                       ! READY
wan-rtr01# show crypto ipsec sa | inc pkts
wan-rtr01# show interface Tunnel100                   ! up/up
! End-to-end:
PC-FinDep$ ping 10.1.8.10                              ! Branch host
wan-rtr01# show crypto ipsec sa | inc encrypt|decrypt  ! pkts өсөх ёстой
```

### Task 13 — NTP
```
Fusion-rtr01# show ntp status                          ! master 3 эсвэл sync to <EVE_NTP_IP>
Fusion-rtr01# show ntp associations
Fusion-rtr02# show ntp status                          ! sync to 10.1.17.3
Fusion-rtr02# show clock                               ! +08 ULAT
```

### Task 14 — HSRP (corp-dsw02 Vlan30)
```
corp-dsw02# show standby Vlan30 brief                  ! State Active priority 150
corp-dsw02# show track 1                               ! Loopback5 Up
corp-dsw01# show standby Vlan30 brief                  ! Standby
```

### Task 15 — TCLSH
```
wan-rtr01# more flash:statuscheck                      ! tcl source code
wan-rtr01# tclsh flash:statuscheck                     ! бүх show command-ийн output
wan-rtr01# dir flash: | inc statuscheck
```

### Task 16 — OSPF-6 (md5 key унификаци)
```
Fusion-rtr02# show ip ospf interface GigabitEthernet0/0.1020 | inc Auth|Key
Fusion-rtr02# show ip ospf neighbor | inc 10.1.19.16   ! corp-dsw02 FULL
corp-dsw02# show ip ospf interface Vlan1020 | inc Auth
```

### Task 17 — TFTP-1 (CorpSW-3)
```
CorpSW-3# show running | inc hostname                  ! corp-esw03
CorpSW-3# show vlan brief
CorpSW-3# show ip interface brief | exclude unassigned
```

### Task 18 — TFTP-2 (corp-esw01/02)
```
corp-esw01# show event manager policy registered
corp-esw01# event manager run TFTP_BACKUP
corp-esw01# show event manager history events
! TFTP server-руу гарч очсон файлууд: <hostname>-<unix-ts>
```

### Task 19 — STP (corp-esw02)
```
corp-esw02# show spanning-tree interface Ethernet0/1
corp-esw02# show spanning-tree blockedports            ! Eth0/1 байх ЁСГҮЙ
corp-esw02# show spanning-tree                          ! root bridge corp-dsw01
```

## Final integration tests

```
! End-to-end: FinDep PC → Internet
PC-FinDep$ ping 8.8.8.8
PC-FinDep$ traceroute 8.8.8.8                          ! GW-1 (ISP-A) primary path

! Failover test: GW-1 хайр унавал GW-2-аар
wan-rtr01# config t
wan-rtr01(config)# interface GigabitEthernet0/2
wan-rtr01(config-if)# shutdown
PC-FinDep$ ping 8.8.8.8                                ! GW-2-аар явах ёстой
wan-rtr01(config-if)# no shutdown

! BGP community test (GW-2-аар)
PC$ ping <community-tagged-ipv6-prefix>                 ! source GW-2-аар явах
```

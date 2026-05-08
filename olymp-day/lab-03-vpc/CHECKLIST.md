# Lab-03 — NX-OS vPC + MCLAG

> **Жин:** 10% (~25 минут)
> **Платформ:** Cisco NX-OS (Nexus 9000-K series)
> **Гол сэдэв:** vPC domain, peer-link, peer-keepalive, vPC port-channel

## Чухал items

- **vPC domain ID** (1-1000)
- **peer-link** — хоёр N9K хооронд port-channel (ихэвчлэн Po1)
- **peer-keepalive** — management VRF дээр udp/3200
- **vPC ID** — host-руу зориулсан port-channel-уудын дугаар
- **Consistency parameters** — type-1 (vlan, MTU) ялгахгүй, type-2 (description, etc.) ялгаж болно

## Config skeleton (хоёр N9K хоёулаа)

### N9K-1

```cisco
feature vpc
feature lacp
feature interface-vlan
!
vlan 10,20,99
!
! ── peer-keepalive interface (mgmt0) ──
vrf context management
 ip route 0.0.0.0/0 10.99.99.254
!
interface mgmt0
 vrf member management
 ip address 10.99.99.1/24
!
! ── vPC domain ──
vpc domain 100
 peer-switch
 peer-keepalive destination 10.99.99.2 source 10.99.99.1 vrf management
 peer-gateway
 ip arp synchronize
 auto-recovery
!
! ── peer-link (Po1) ──
interface port-channel1
 switchport
 switchport mode trunk
 switchport trunk allowed vlan 1-4094
 spanning-tree port type network
 vpc peer-link
!
interface Ethernet1/47-48
 switchport
 switchport mode trunk
 switchport trunk allowed vlan 1-4094
 channel-group 1 mode active
 no shutdown
!
! ── vPC member port-channel (host-руу) ──
interface port-channel10
 switchport
 switchport mode trunk
 switchport trunk allowed vlan 10,20
 vpc 10
!
interface Ethernet1/1
 switchport
 channel-group 10 mode active
 no shutdown
```

### N9K-2

```cisco
! ── ижил, гэхдээ ──
vpc domain 100
 peer-keepalive destination 10.99.99.1 source 10.99.99.2 vrf management
 ! ── role priority (бага утга = primary) ──
 role priority 10            ! N9K-1: 20 болгож secondary болгоно
```

## Verify commands

```cisco
show vpc                                      ! ерөнхий статус
show vpc role
show vpc consistency-parameters global        ! type-1 mismatch шалгах
show vpc consistency-parameters interface po10
show vpc peer-keepalive
show port-channel summary
show spanning-tree summary | i ROOT|Edge
```

## Common pitfalls

| Pitfall | Шийдэл |
|---|---|
| peer-keepalive down | mgmt0 IP, gateway, VRF member management шалга. `ping vrf management 10.99.99.2` |
| peer-link нь access port дээр | `vpc peer-link` зөвхөн port-channel дээр л байх ёстой. Trunk mode заавал |
| Type-1 mismatch | `show vpc consistency-parameters global` — vlan list, MTU, STP mode яг адил |
| vPC member port suspended | Hosting side LACP active байх ёстой; vlan allowed list match |
| Peer-gateway hairpin issue | `peer-gateway exclude-vlan` тохиолдол бүр |
| Role priority adил → election failure | Хоёр switch-д ялгаатай priority оруулах |

## AI prompt

```
NX-OS vPC peer-link нь up, peer-keepalive нь down. vPC domain 100.

show vpc:
<paste>

show vpc consistency-parameters global:
<paste>

show running-config | sec vpc:
<paste>

show ip route vrf management:
<paste>

Шалтгаан + засварыг өг. mgmt0 IP, peer-keepalive vrf, gateway,
type-1 mismatch-ийг хян.
```

## Push back

```bash
python3 ~/net/scripts/olymp-run.py --mode push --push-cfg <file> --slow
```

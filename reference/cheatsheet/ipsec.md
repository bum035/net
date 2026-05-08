# IPSec / GRE Cheatsheet

> IOS / IOS-XE — Site-to-site VPN, GRE+IPSec protection

## IKE Phase 1 (control plane)

| | IKEv1 | IKEv2 |
|---|---|---|
| Negotiation | 6 эсвэл 3 (aggressive) packet | 4 packet |
| Auth | PSK / RSA / digital sig | PSK / RSA / EAP |
| NAT-T | UDP 4500 | UDP 4500 |
| Re-keying | Бий | Илүү цэвэр |
| Mode | Main / Aggressive | One mode |
| Cisco-аас preferred | Legacy | Шинэ deployment-д |

## IKEv2 (recommended)

```cisco
! ── Proposal (encryption + integrity + DH) ──
crypto ikev2 proposal IKE-PROP
 encryption aes-cbc-256 aes-cbc-128
 integrity sha256 sha1
 group 14 5 2
!
! ── Policy ──
crypto ikev2 policy IKE-POL
 proposal IKE-PROP
!
! ── Keyring (PSK) ──
crypto ikev2 keyring KR-OLYMP
 peer SPOKE2
  address 203.0.113.2
  pre-shared-key olymp123
!
! ── Profile ──
crypto ikev2 profile IKE-PROF
 match identity remote address 203.0.113.2 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local KR-OLYMP
!
! ── Transform-set + IPSec profile ──
crypto ipsec transform-set TS-OLYMP esp-aes 256 esp-sha256-hmac
 mode transport                        ! GRE-IPSec бол transport, plain IPSec бол tunnel
!
crypto ipsec profile IPSEC-PROF
 set transform-set TS-OLYMP
 set ikev2-profile IKE-PROF
```

## IKEv1 (legacy IOS, олимпиадад түгээмэл)

```cisco
! ── Phase 1 ──
crypto isakmp policy 10
 encr 3des                          ! эсвэл aes
 hash md5                           ! эсвэл sha
 authentication pre-share
 group 2                            ! 1024-bit DH (group 5 = 1536, group 14 = 2048)
 lifetime 86400
!
crypto isakmp key olymp123 address 203.0.113.2
!
! ── Phase 2 ──
crypto ipsec transform-set TS-OLYMP esp-3des esp-md5-hmac
 mode tunnel                        ! plain IPSec
!
crypto ipsec profile IPSEC-PROF
 set transform-set TS-OLYMP
```

## Crypto map (legacy site-to-site, no GRE)

```cisco
! ACL — encrypt хийх traffic-ыг тодорхойлох
ip access-list extended VPN-TRAFFIC
 permit ip 192.168.1.0 0.0.0.255 192.168.2.0 0.0.0.255
!
crypto map CMAP 10 ipsec-isakmp
 set peer 203.0.113.2
 set transform-set TS-OLYMP
 match address VPN-TRAFFIC
!
interface Gi0/0                     ! WAN interface
 crypto map CMAP
```

## GRE + IPSec (preferred)

```cisco
! ── Tunnel ──
interface Tunnel0
 ip address 10.255.0.1 255.255.255.252
 tunnel source 198.51.100.1
 tunnel destination 203.0.113.2
 tunnel protection ipsec profile IPSEC-PROF
!
! ── Routing — internal LAN-уудыг tunnel-аар ──
ip route 192.168.2.0 255.255.255.0 10.255.0.2
!
! Эсвэл OSPF-ийг tunnel-аар ажиллуулах
router ospf 1
 network 10.255.0.0 0.0.0.3 area 0
```

⚠ GRE-IPSec бол `mode transport` нь best practice — header overhead ↓, native NAT-Т friendly.

## Encryption / Hash суур

| Encryption | Сила | Notes |
|---|---|---|
| DES, 3DES | Сул, deprecated | Legacy IOS |
| AES-128 | Сайн | Default нэлээд |
| AES-192 | Сайн | |
| AES-256 | Хүчтэй | Recommended |

| Hash | Эфф |
|---|---|
| MD5 | Сул |
| SHA / SHA1 | Хуучирсан |
| SHA-256 | Recommended |
| SHA-384/512 | Хүчтэй |

| DH group | Bits |
|---|---|
| 1 | 768 (deprecated) |
| 2 | 1024 |
| 5 | 1536 |
| 14 | 2048 (recommended) |
| 19 | ECP-256 |
| 20 | ECP-384 |

## Verify — IKEv1

```cisco
show crypto isakmp sa                ! Phase 1
show crypto isakmp sa detail
show crypto ipsec sa                 ! Phase 2
show crypto ipsec sa peer 203.0.113.2
show crypto map
debug crypto isakmp                  ! зөвхөн troubleshoot
debug crypto ipsec
```

## Verify — IKEv2

```cisco
show crypto ikev2 sa
show crypto ikev2 sa detail
show crypto ikev2 session
show crypto ipsec sa
show crypto ikev2 stats
debug crypto ikev2
```

## SA states (IKEv1)

```
Phase 1: MM_NO_STATE → MM_SA_SETUP → MM_KEY_EXCH → MM_KEY_AUTH → QM_IDLE
Phase 2: SA up → encrypt/decrypt counter ↑
```

## Common pitfalls

| Pitfall | Шийдэл |
|---|---|
| Phase 1 stuck MM_NO_STATE | UDP 500 block, peer IP unreach |
| Phase 1 stuck MM_KEY_AUTH | PSK mismatch — `pre-shared-key` яг адил байх ёстой |
| Phase 1 OK, Phase 2 fail | Transform-set mismatch (encryption/hash/mode) |
| Tunnel up, encrypt = 0 | `crypto map` interface дээр attached биш, эсвэл `tunnel protection ipsec profile` алга |
| IKEv2 SA empty, NAT-аар ард | `nat-keepalive` 20 idэвхжүүлэх, NAT-T (UDP 4500) flow check |
| `mode tunnel` vs `mode transport` | GRE+IPSec бол **transport**, plain IPSec (no GRE) бол **tunnel** |
| Lifetime mismatch warning | Two side-аас лайфтайм өөр — sa expire үед мэдрэгдэнэ |

## NAT-T (NAT traversal)

```cisco
! Auto-detected на ihbэр Cisco. Manually:
crypto isakmp nat-keepalive 20
```

NAT-T detect → UDP 4500-аар encapsulate (UDP 500 биш). Idle keepalive 20 секунд.

## DPD (Dead Peer Detection)

```cisco
crypto isakmp keepalive 30 5         ! 30s interval, 5s retry
```

## AI prompt

```
GRE+IPSec IKEv2 between R1 (198.51.100.1) and R2 (203.0.113.2).
Tunnel up but encrypt counter 0.

show crypto ikev2 sa detail:
<paste>

show crypto ipsec sa peer 203.0.113.2:
<paste>

show interface tunnel0:
<paste>

Шалтгаан + засварыг өг. SA state, transform-set match, tunnel protection
attached, ACL block-ыг хян.
```

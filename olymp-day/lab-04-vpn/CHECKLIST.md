# Lab-04 — GRE + IPSec VPN IKEv2

> **Жин:** 9% (~25 минут)
> **Платформ:** Cisco IOS / IOS-XE
> **Гол сэдэв:** GRE tunnel + IPSec protection (IKEv2)

## Чухал items

- **Site IP** — Hub WAN IP, Spoke WAN IP
- **Tunnel IP** — overlay subnet (e.g. 10.255.0.0/30)
- **PSK** — pre-shared key текст
- **IKEv2 vs IKEv1** — даалгаврын текстээс шалгах. IKEv1 бол `crypto isakmp policy`
- **Encryption / Hash / DH group** — AES-256/SHA-256/group 14 default
- **Transform-set mode** — `mode tunnel` (default GRE-IPSec ёсоор) vs `mode transport` (GRE үргэлж overhead багатай тул хэрэглэдэг)
- **Static / dynamic peer** — Hub нь "any spoke" хүлээн авах эсэх

## Config skeleton — IKEv2

### Hub (R1, WAN 198.51.100.1)

```cisco
! ── IKEv2 keyring (PSK) ──
crypto ikev2 keyring KR-OLYMP
 peer SPOKE2
  address 203.0.113.2
  pre-shared-key olymp123
!
! ── IKEv2 profile ──
crypto ikev2 profile IKE-PROF
 match identity remote address 203.0.113.2 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local KR-OLYMP
!
! ── IPSec proposals ──
crypto ipsec transform-set TS-OLYMP esp-aes 256 esp-sha-hmac
 mode transport         ! GRE-IPSec recommended
!
crypto ipsec profile IPSEC-PROF
 set transform-set TS-OLYMP
 set ikev2-profile IKE-PROF
!
! ── GRE tunnel ──
interface Tunnel0
 ip address 10.255.0.1 255.255.255.252
 tunnel source 198.51.100.1
 tunnel destination 203.0.113.2
 tunnel protection ipsec profile IPSEC-PROF
!
! ── Routing — internal LAN-уудыг tunnel-аар ──
ip route 192.168.2.0 255.255.255.0 10.255.0.2
```

### Spoke (R2, WAN 203.0.113.2)

```cisco
! ── ижил keyring/profile/transform/ipsec-profile, гэхдээ peer R1 ──
crypto ikev2 keyring KR-OLYMP
 peer HUB
  address 198.51.100.1
  pre-shared-key olymp123
!
crypto ikev2 profile IKE-PROF
 match identity remote address 198.51.100.1 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local KR-OLYMP
!
interface Tunnel0
 ip address 10.255.0.2 255.255.255.252
 tunnel source 203.0.113.2
 tunnel destination 198.51.100.1
 tunnel protection ipsec profile IPSEC-PROF
!
ip route 192.168.1.0 255.255.255.0 10.255.0.1
```

## IKEv1 fallback (legacy IOS)

```cisco
crypto isakmp policy 10
 encr 3des
 hash md5
 authentication pre-share
 group 2
crypto isakmp key olymp123 address 203.0.113.2
!
crypto ipsec transform-set TS-OLYMP esp-3des esp-md5-hmac
 mode transport
crypto ipsec profile IPSEC-PROF
 set transform-set TS-OLYMP
!
interface Tunnel0
 tunnel source <wan>
 tunnel destination <peer>
 tunnel protection ipsec profile IPSEC-PROF
```

## Verify commands

```cisco
show crypto ikev2 sa detail                  ! SA up эсэх
show crypto ipsec sa
show crypto ipsec transform-set
show interface tunnel0                        ! GRE up
show interface tunnel0 stats
ping 10.255.0.2 source 10.255.0.1            ! tunnel reach
```

## Common pitfalls

| Pitfall | Шийдэл |
|---|---|
| Tunnel up ч encrypt тоолуур 0 | IPSec profile attached not on tunnel. `tunnel protection ipsec profile X` тavlсан эсэхийг шалга |
| IKEv2 SA empty | PSK match эсэх, `match identity remote` хоёр талд яг адил, NAT-T (UDP 4500) port |
| Мөн "QM_IDLE" but ping fail | Routing — `ip route` tunnel-аар явахгүй. tracert хийж шалга |
| Crypto map vs tunnel protection хослуулсан | Зөвхөн **нэг** ашиглана. GRE-IPSec бол `tunnel protection ipsec profile` |
| Mode tunnel vs mode transport | GRE-аар бол **transport** ашиглах нь best practice (header double encapsulation хэмнэнэ) |

## AI prompt

```
GRE+IPSec IKEv2 between R1 (198.51.100.1) and R2 (203.0.113.2).
Tunnel up but ping fails.

show crypto ikev2 sa detail:
<paste>

show crypto ipsec sa peer 203.0.113.2:
<paste>

show interface tunnel0:
<paste>

show ip route 192.168.2.0:
<paste>

Шалтгаан + засварыг өг. SA state, encrypt/decrypt counter,
tunnel protection profile attached, route via tunnel-ийг хян.
```

## Push back

```bash
python3 ~/net/scripts/olymp-run.py --mode push --push-cfg <file> --slow
```

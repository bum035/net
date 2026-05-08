# Lab-01 — OSPF Multi-area + VRF FinDep + Redistribution

> **Жин:** 17% (~45 минут)
> **Платформ:** Cisco IOS / IOS-XE
> **Гол сэдэв:** OSPFv2 multi-area, VRF-aware OSPF, route redistribution

## Quick start

```bash
# 1. Шууд backup (lab эхэлсний дараа)
python3 ~/net/scripts/olymp-run.py --mode backup --no-confirm

# 2. SecureCRT-аас R1, R2, R3, R4-руу tab-аар нэвтрэх
#    (Sessions tree → pod1/R1, pod1/R2 ...)
```

## Чухал items (даалгаврын текстээс хайх)

- **Area дугаар** (e.g. area 0, area 10, area 20)
- **Area type** — stub / totally stubby / NSSA / totally NSSA
- **VRF нэр** (FinDep, гэх мэт) — interface-ууд тэр VRF-д хамаарна
- **Redistribute эх** — connected, static, BGP, RIP
- **Metric type** — E1 (transitive) vs E2 (default — 외부 cost дотор inсreз болохгүй)
- **OSPF process ID** — OSPFv3 + IPv6 байх эсэх

## Config skeleton (R1 жишээ)

```cisco
! ── VRF үүсгэх ──
ip vrf FinDep
 rd 65000:1
 route-target export 65000:1
 route-target import 65000:1
!
! ── Interface VRF assign ──
interface GigabitEthernet0/1
 ip vrf forwarding FinDep
 ip address 10.10.1.1 255.255.255.0
 ip ospf 2 area 10
 no shutdown
!
! ── Global OSPF (area 0) ──
router ospf 1
 router-id 1.1.1.1
 network 10.0.0.0 0.0.0.255 area 0
 redistribute connected subnets
!
! ── VRF-aware OSPF (FinDep) ──
router ospf 2 vrf FinDep
 router-id 2.2.2.2
 area 10 stub no-summary    ! totally stubby бол
 redistribute bgp 65000 vrf FinDep subnets
 network 10.10.1.0 0.0.0.255 area 10
```

## Verify commands

```cisco
show ip ospf neighbor
show ip ospf neighbor vrf FinDep
show ip ospf interface brief
show ip route ospf
show ip route vrf FinDep ospf
show ip ospf database     | i area
show ip ospf process | i Id|Area
```

## Common pitfalls

| Pitfall | Шийдэл |
|---|---|
| `redistribute connected` хийсэн ч /32 host route орохгүй | `redistribute connected subnets` (subnets keyword чухал) |
| Area stub бол ASBR-аар орох route хязгаарлалт | `area X stub no-summary` гэвэл totally stubby (default route only) |
| VRF дотор OSPF neighbor up болохгүй | Interface дээр `ip vrf forwarding` бүр **OSPF-аас өмнө** идэвхжих ёстой. IP address дахин тавиж шинэчил |
| Multi-area ABR LSA type mismatch | `show ip ospf border-routers` шалгана; ABR нь area 0 + бусад area-д zaaдag |
| Cost-аас үл хамаарч E2 redistribute root cost үлдэнэ | `metric-type 1` тавьвал transit cost нэмнэ |

## AI prompt — copy/paste

```
OSPF multi-area + VRF FinDep redistribute. Show output:

show ip ospf neighbor:
<paste>

show ip ospf neighbor vrf FinDep:
<paste>

show ip route ospf:
<paste>

show run | sec router ospf:
<paste>

Шалтгаан + засварыг өг. ABR LSA type, stub/NSSA flag, redistribute
keyword (subnets, metric-type), VRF leak-ийг хян.
```

## Push back

```bash
python3 ~/net/scripts/olymp-run.py --mode push \
    --push-cfg backup-<ts>/R1_<ts>.cfg --slow
```

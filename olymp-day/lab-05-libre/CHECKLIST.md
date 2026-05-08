# Lab-05 — LibreNMS + SNMPv2 + Pre-broken Troubleshoot

> **Жин:** 45% (~110 минут) ⚠ ХАМГИЙН ЧУХАЛ ЛАБ
> **Платформ:** LibreNMS web + Cisco IOS/NX-OS device-ууд (pre-broken state)
> **Гол сэдэв:** SNMPv2 setup, LibreNMS device add, pre-broken troubleshoot (3-5 device-руу 10+ алдаа суулгасан)

## Стратеги

Энэ лаб **45% жинтэй** — өөр бүх лабууд дундлаад л 55%. Эхэлж энийг хийнэ үү эсвэл сүүлд үлдэхгүй байх.

```
Алхам 1 — preflight + lab-аас даалгаврын текст уншин
Алхам 2 — топологи мэдэх (dot/svg-аар)
Алхам 3 — device бүрд SSH/console-аар нэвтэрч "show running" хадгалах
Алхам 4 — Diff-аар "ажиллах" device vs broken device-ийг харьцуулах
Алхам 5 — нэг нэгээр алдааг засна
```

## Чухал items

- **NMS server IP** — LibreNMS web access
- **SNMP community** (RO/RW) — даалгаврын текстэд бичсэн
- **NMS-аас device-руу хүрэх ACL** — заримдаа block хийсэн (троубл)
- **Алдаа төрөл** — interface shutdown, OSPF authentication, ACL deny SNMP, wrong route, MTU mismatch, BGP password, SNMP version (v1 vs v2c vs v3)

## Pre-broken types — өмнө таарсан 10+

| # | Шинж тэмдэг | Шалгах |
|---|---|---|
| 1 | Interface admin-down | `show ip int brief` → status `administratively down` |
| 2 | Wrong subnet mask | `show ip int brief` IP, /24 vs /30 ялгаа |
| 3 | OSPF area mismatch | `show ip ospf neighbor` хоосон, `show ip ospf int` area дугаар |
| 4 | OSPF auth mismatch | `show ip ospf int` `Authentication` section |
| 5 | BGP password mismatch | `show ip bgp summary` "Active", `show ip bgp neighbors X | i password` |
| 6 | ACL deny SNMP | `show access-list` → SNMP UDP 161 deny эсэх. NMS IP allow эсэх |
| 7 | Wrong SNMP community | `show snmp community` |
| 8 | SNMP host configured wrong | `show run | sec snmp` → `snmp-server host <NMS-IP> version <ver> <community>` |
| 9 | MTU mismatch | `show int | i MTU` — OSPF/BGP-руу нөлөөлдөг |
| 10 | Default route missing | `show ip route 0.0.0.0` |
| 11 | NTP wrong server | `show ntp associations` |
| 12 | VRF leak missing | `show ip route vrf X` route-target import/export |

## Config skeleton — SNMPv2 device side

```cisco
! ── ACL — NMS IP-руу SNMP зөвшөөр ──
ip access-list standard SNMP-NMS
 permit host 10.99.99.10
 deny any log
!
! ── community + view ──
snmp-server view ALL-VIEW iso included
snmp-server community OlympRO RO ALL-VIEW SNMP-NMS
snmp-server community OlympRW RW ALL-VIEW SNMP-NMS
!
! ── Trap host ──
snmp-server host 10.99.99.10 version 2c OlympRO
snmp-server enable traps snmp authentication linkdown linkup coldstart
snmp-server enable traps bgp
snmp-server enable traps ospf
!
! ── Location / contact ──
snmp-server location "Olympiad-2026 R1"
snmp-server contact "olympiad@school.mn"
```

## NX-OS SNMP

```cisco
feature snmp-server
snmp-server community OlympRO group network-operator
snmp-server host 10.99.99.10 traps version 2c OlympRO
snmp-server enable traps
```

## Verify commands

```bash
# LibreNMS API эсвэл shell
ssh nms@<libre-ip>
sudo -u librenms /opt/librenms/poller.php -h <hostname>     # poller debug
sudo -u librenms /opt/librenms/snmp-scan.py -t 10.99.99.0/24
```

```cisco
show snmp                                      ! community, host, contact
show snmp host
show snmp community
show snmp pending                              ! trap queue
debug snmp packets                             ! зөвхөн troubleshoot үед
```

```bash
# NMS-аас device рууд snmpwalk
snmpwalk -v2c -c OlympRO 10.0.0.1 sysDescr.0
snmpbulkwalk -v2c -c OlympRO 10.0.0.1 ifTable
```

## LibreNMS device add troubleshoot

| Шинж тэмдэг | Шийдэл |
|---|---|
| "Could not connect, check community" | snmpwalk-аар тест → ACL deny эсвэл community wrong |
| Add OK ч "Polled 0 metrics" | `snmp-server view` нь зөвхөн 1 OID-ээр зориулсан байж магадгүй. `iso included` нэм |
| Trap ирэхгүй | `snmp-server host` configured эсэх + Cisco-н `snmp-server enable traps` flag тус бүрд идэвхжсэн эсэх |
| BGP/OSPF state poll-руу гарахгүй | LibreNMS-д MIB-ийг enable хийх. Modules → bgp/ospf checkboxes |

## AI prompt

```
LibreNMS дотор device-уудыг add хийсэн. R1 polled OK, R2-R3 "could not
connect". Pre-broken state.

show snmp on R2:
<paste>

show snmp on R3:
<paste>

show access-list on R2 R3:
<paste>

snmpwalk -v2c -c <community> <r2-ip> sysDescr.0:
<paste>

ACL, community, view, host config-уудыг харьцуул. Алдааг нэгэн нэгээр
тогтоо. Засваруудыг priority дарааллаар жагса.
```

## Workflow tip

```bash
# 1. Бүгдээс backup ав (broken state хадгалах)
python3 ~/net/scripts/olymp-run.py --mode backup --no-confirm

# 2. Backup folder-руу очно
cd ~/net/olymp-day/lab-05-libre/backup-*

# 3. Diff: ажиллах device vs broken
diff R1_*.cfg R2_*.cfg | less

# 4. Засаад push
python3 ~/net/scripts/olymp-run.py --mode push --push-cfg R2_<ts>.cfg --slow
```

## Push back

```bash
python3 ~/net/scripts/olymp-run.py --mode push --push-cfg <file> --slow
```

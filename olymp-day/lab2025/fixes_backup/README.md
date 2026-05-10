# lab2025 — Per-device paste-ready fix файлууд

> **Push арга**: HTML5 Guacamole console (telnet порт firewalled). EVE-NG: `http://36.50.7.52:40117/` → admin / `i@m}Q}!*%NV` → `lab2025.unl` → device дээр right-click → Console.

## Push order (priority — pts/min ratio)

| Step | File | Device | Tasks | Pts |
|---|---|---|---|---|
| 1 | `corp-esw02.txt` | CorpSW-2 | STP + TFTP-2 | 4 |
| 2 | `Fusion-rtr02.txt` | Fusion_Router-2 | OSPF-6 + NTP client | 4 |
| 3 | `Fusion-rtr01.txt` | Fusion_Router-1 | OSPF-2 + NTP master | 5 |
| 4 | `wan-rtr01.txt` | GW-1 | iBGP + BGP-1/2 + NAT + OSPF-4 + TCLSH + IPsec | 16 |
| 5 | `wan-rtr02.txt` | GW-2 | OSPF-4 + BGP-2 prepend + BGP-3 | 7 |
| 6 | `corp-dsw02.txt` | CorpGW-2 | OSPF-3 + OSPF-1 + OSPF-5 + HSRP | 9 |
| 7 | `corp-dsw01.txt` | CorpGW-1 | VRRP + OSPF-1 + OSPF-5 | 7 |
| 8 | `corp-esw01.txt` | CorpSW-1 | TFTP-2 | (shared 2) |
| 9 | `CorpSW-3.txt` | CorpSW-3 | TFTP-1 | 2 |
| 10 | `Br1GW.txt` | Br1GW | IPsec mirror | (shared 4) |

**Total**: 46 pts (зорилго — full)

## Hostname mapping

| EVE label | hostname | Console port |
|---|---|---|
| CorpGW-1 | corp-dsw01 | 32771 |
| CorpGW-2 | corp-dsw02 | 32772 |
| Fusion_Router-1 | Fusion-rtr01 | 32773 |
| Fusion_Router-2 | Fusion-rtr02 | 32774 |
| GW-1 | wan-rtr01 | 32776 |
| GW-2 | wan-rtr02 | 32777 |
| CorpSW-1 | corp-esw01 | 32769 |
| CorpSW-2 | corp-esw02 | 32770 |
| CorpSW-3 | CorpSW-3 | 32786 |
| Br1GW | (no config snapshot) | 32783 |

## Paste workflow

```
# Console-руу нэвтэрсний дараа:
terminal length 0
terminal width 0
enable
# (password энэ лаб дээр enable байхгүй, эсвэл cisco)
conf t
... <paste block> ...
end
wr mem

# Verify:
... <show command-уудыг README/verify.md-аас> ...
```

## ⚠ Тогтоорсон placeholder-ууд

Эдгээрийг **бодит лаб утгаар солих**:

| Placeholder | Үүрэг | Олох газар |
|---|---|---|
| `<TFTP_IP>` | TFTP server IP | TFTP сервер юунд байгаа — task UI эсвэл DC subnet 10.1.12.x |
| `<EVE_NTP_IP>` | EVE-NG host IP NTP-д | `36.50.7.52` (cloud) — гэхдээ Fusion-rtr01-аас reachable байх ёстой. Хэрэв lab-internal mgmt IP байгаа бол түүнийг ашигла |
| `<BR1GW_PUB_IP>` | Br1GW public IP IPsec-д | Br1GW-ийн ISP-A/B-руу гарч буй public IP |
| `<IPSEC_PSK>` | IKEv2 pre-shared key | Олимп-н оноосон, өөрсдөө сонгох (хэрэв шалгуурт `Cisco@2026` гэх мэт жишээ ороогүй бол) |
| `<COMMUNITY_VAL>` | BGP-3 community value | Task-ийн community жишээ (e.g. `19000:100`) |

## Verify reference

`verify.md` файлд бүх show command-ийн checklist байгаа.

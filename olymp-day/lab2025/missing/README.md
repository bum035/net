# lab2025/missing/ — дутуу тохиргоонуудын аудит

**Аудит огноо:** 2026-05-09
**Эх:** `lab2025/fixes/*.txt` (9 device fix, 19 task)

## TL;DR

19 task бүгд coverage-тай. Гэхдээ **5 placeholder** болон **Br1GW dynamic IP-ийн logic** нь дутуу. Доорх файлуудыг paste хийхийн өмнө ашиглана:

| # | Файл | Юу засна | Урьдах нэр |
|---|---|---|---|
| 1 | [`01-wan-rtr01-ipsec-fill.txt`](01-wan-rtr01-ipsec-fill.txt) | `<BR1GW_PUB_IP>`, `<IPSEC_PSK>` solih + dynamic peer | wan-rtr01 |
| 2 | [`02-wan-rtr02-bgp3-community.txt`](02-wan-rtr02-bgp3-community.txt) | `<COMMUNITY_VAL>` solih | wan-rtr02 |
| 3 | [`03-CorpSW-3-tftp-fill.txt`](03-CorpSW-3-tftp-fill.txt) | `<TFTP_IP>` solih | CorpSW-3 |
| 4 | [`04-Fusion-rtr01-ntp-fill.txt`](04-Fusion-rtr01-ntp-fill.txt) | `<EVE_NTP_IP>` solih | Fusion-rtr01 |
| 5 | [`05-snmp-librenms-bonus.txt`](05-snmp-librenms-bonus.txt) | LibreNMS SNMP (lab-summary mention, task биш) | бүх router |

## Placeholder full list

| Placeholder | File(s) | Юу зориулсан | Бодит утга олох газар |
|---|---|---|---|
| `<BR1GW_PUB_IP>` | wan-rtr01.txt (4 газар) | IPsec peer Br1GW-руу | Br1GW нь ISP-аас DHCP авдаг → **dynamic** → wildcard match хэрэг |
| `<IPSEC_PSK>` | wan-rtr01.txt (3 газар) | IKEv2 PSK | `OlympLab2026` (Br1GW.txt-д үүний хариу утга) |
| `<COMMUNITY_VAL>` | wan-rtr02.txt:45 | BGP-3 community filter | Шалгуурын текстээс олох (e.g. `19000:100`) |
| `<TFTP_IP>` | CorpSW-3.txt (3 газар) | TFTP server IP | DC subnet 10.1.12.x эсвэл task UI |
| `<EVE_NTP_IP>` | Fusion-rtr01.txt (2 газар) | NTP upstream | EVE host `36.50.7.52` (cloud), эсвэл internal mgmt IP |

## Тэмдэглэл

- `Br1GW.txt`-ийн PSK нь хатуу `OlympLab2026` гэж бичсэн. wan-rtr01-ийн `<IPSEC_PSK>`-ийг **энэ утгаар** солих ёстой.
- `Br1GW.txt`-ийн tunnel destination нь `202.43.65.2` (GW-1 public IP) хатуу — энэ side OK.
- wan-rtr01-ийн tunnel destination Br1GW-руу = Br1GW нь ISP-DHCP → **`address 0.0.0.0`** wildcard матч хэрэг (доорх `01-wan-rtr01-ipsec-fill.txt`-д бичсэн).
- LibreNMS-ийн SNMP нь TASKS.md-ийн 19 даалгаварт **байхгүй** — зөвхөн lab-summary дээр дурдсан → bonus.

## Paste workflow

```
cd /home/ubuntu/net/olymp-day/lab2025/missing
# Бодит лаб утгыг шалгасны дараа доорх файлуудыг console-руу paste:
# 1. wan-rtr01 console (32776) ←  01-wan-rtr01-ipsec-fill.txt
# 2. wan-rtr02 console (32777) ←  02-wan-rtr02-bgp3-community.txt
# 3. CorpSW-3 console (32786)  ←  03-CorpSW-3-tftp-fill.txt
# 4. Fusion-rtr01 console (32773) ← 04-Fusion-rtr01-ntp-fill.txt
```

# Олимпиадын ажлын орчин — Claude-д өгөх context

> **Огноо:** 2026-05-09 II шат
> **Газар:** Mongolia, XIV Компьютерын Сүлжээний Олимпиад, оюутны ангилал
> **Зорилго:** Энэ folder доторх лаб бүрд config бичих, debug хийх, шалгах
> **AI / интернет:** ✅ зөвшөөрсөн — Claude, claude.ai, ChatGPT, Cisco docs бүгд

## Чи хэн бэ

Cisco/NX-OS network engineer-ийн төв туслах.
- Cisco IOS, IOS-XE, IOS-XR, NX-OS бүгдийн config syntax-ийг гаргалгаатай
- BGP, OSPF, vPC, GRE+IPSec, SNMP, LibreNMS troubleshoot-ийг хийдэг
- Output **товч** — config block + 1-2 өгүүлбэрийн тайлбар. Урт essay биш
- Mongolian-аар хариулна (хэрэглэгч англиар асуувал англиар)

## Цагийн хуваарь (~4 цаг 30 мин)

| Lab | Сэдэв | % | Цаг |
|---|---|---|---|
| lab-01-ospf | OSPF Multi-area + VRF FinDep + Redistribution | 17% | ~45 мин |
| lab-02-bgp  | BGP Full Stack: iBGP RR + eBGP + TE | 20% | ~55 мин |
| lab-03-vpc  | NX-OS vPC + MCLAG | 10% | ~25 мин |
| lab-04-vpn  | GRE + IPSec VPN IKEv2 | 9% | ~25 мин |
| lab-05-libre| **LibreNMS + SNMPv2 + Pre-broken Troubleshoot** | **45%** | **~110 мин** |

⚠ **Lab-05 нь хамгийн чухал** — pre-broken topology troubleshoot. Заавал бэлдэх.

## Workflow

```
SecureCRT (console) ──► OlympBackup/<host>_<ts>.cfg
                              │
                              ▼
        VS Code ──► Claude Code panel ──► fix
                              │
                              ▼
        SecureCRT PUSH ──► router (line-by-line, LINE_DELAY_MS=50)
```

Эсвэл шууд terminal-аас:
```bash
python3 ~/net/scripts/olymp-run.py --mode backup --no-confirm
# fix локалд .cfg засах
python3 ~/net/scripts/olymp-run.py --mode push --push-cfg <file>
```

## Лаб тус бүрийн folder

Лаб бүрд `CHECKLIST.md` бэлэн. Эхлэхдээ тэр файлыг unaad config skeleton, verify command, AI prompt template-ыг авна.

- [`lab-01-ospf/CHECKLIST.md`](lab-01-ospf/CHECKLIST.md)
- [`lab-02-bgp/CHECKLIST.md`](lab-02-bgp/CHECKLIST.md)
- [`lab-03-vpc/CHECKLIST.md`](lab-03-vpc/CHECKLIST.md)
- [`lab-04-vpn/CHECKLIST.md`](lab-04-vpn/CHECKLIST.md)
- [`lab-05-libre/CHECKLIST.md`](lab-05-libre/CHECKLIST.md)

## Reference материал

- [`../reference/prompts.md`](../reference/prompts.md) — AI prompt template (BGP stuck, vPC mismatch, syntax convert)
- `../reference/cheatsheet/` — offline OSPF/BGP/vPC/IPSec syntax (interview tасрахад fallback)
- `../reference/2024_round2/`, `2025_round2/` — өмнөх жилийн config жишээ
- `../reference/lab-NN.pdf` — лабын даалгавар (олимпиадын өмнө хуулсан)
- `../secureCRT/VanDyke/Config/` — SecureCRT button bar, snippets

## AI guardrails — Юуг өөрөө уншина

| Юу | Яагаад өөрөө |
|---|---|
| **Шалгуурын текст** | Хязгаарлалт (open standard, prepend хориглох, AS path manipulation onlyXX) AI-руу буруу хүрвэл буруу config гарна |
| **`show` output** | AI hallucination — буруу line-ийг "key" гэх. Чи өөрөө уншиж зурвасууд боломжтой бол paste |
| **Эцсийн config push хийхийн өмнө** | Deprecated keyword (`ip cef enable`, IOS-only `vrf forwarding` vs IOS-XE `vrf forwarding`) AI хэлэхгүй магадгүй |
| **Live PSK / production password** | Chat-руу хуулахгүй — privacy + олимпиад дараа сэжиг үлдэхгүй |

## Common pitfalls (өмнө таарсан)

- **VRF + OSPF redistribution** — `redistribute connected subnets` хийхгүй бол /32 host route ороход алдаа
- **iBGP RR client дотор** — `route-reflector-client` нь RR-н зүгээс activate хийнэ, client-аас биш
- **vPC peer-keepalive** — management VRF + жинхэнэ gateway байх ёстой; peer-link-аар явахгүй
- **GRE + IPSec** — `tunnel protection ipsec profile` нь tunnel interface дээр (NOT crypto map)
- **LibreNMS device add fail** — SNMPv2 community `RO`, ACL allow MS-IP, `snmp-server view` зөв байх

## Тусламж дуудах

`reference/prompts.md`-аас prompt сонгож chat-руу copy. Эсвэл богино "BGP active stuck шалгаач, show ip bgp summary: <paste>".

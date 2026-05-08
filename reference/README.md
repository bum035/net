# reference/ — олимпиадын өдрийн оffline backup

Энэ folder нь интернет тасрах эсвэл AI ачааллах боломжгүй болсон үед
ашиглах **офлайн** мэдлэг.

## Бүтэц (одоогоор бэлдэж буй)

| Файл / folder | Үүрэг | Status |
|---|---|---|
| `prompts.md` | Claude / AI prompt template ✓ | bэлэн |
| `lab-NN.pdf` | EVE-NG лаб тус бүрийн топологи + даалгавар | placeholder — олимпиадын лаб эхлэхийн өмнө хуулах |
| `2024_round2/` | 2024 II шатны config + topology | placeholder — өмнөх жилийн ажлаас хуулах |
| `2025_round2/` | 2025 II шатны config + topology | placeholder — өмнөх жилийн ажлаас хуулах |
| `cheatsheet/` | OSPF/BGP/vPC/IPSec syntax cheatsheet | placeholder — Cisco config guide-аас clip хийх |

## Хуулах эх сурвалж

`D:\vs_code_zenbook\network_olymp\` (Windows zenbook):

```
04_eve_ng_material/labs/topologies/lab-*.pdf  →  reference/lab-NN.pdf
2024_eve-ng_task_doing/                       →  reference/2024_round2/
2025_eve-ng_task_doing/                       →  reference/2025_round2/
```

## Олимпиадын өмнөх 30 минут

1. Wifi unplug → `claude` ажиллах эсэхийг шалгах (offline fail хүлээгдэж байна)
2. `prompts.md`-аас 2-3 prompt-ыг чанга унших — AI-гүйгээр хийх workflow дасах
3. `lab-NN.pdf`-уудыг VS Code дээр нээгээд топологи харах
4. `2024_round2/` дотор бэлэн config-уудыг шалгаад өөрийн pod-руу
   хувилахад зориулсан skeleton гаргах

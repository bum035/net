# docs/ — Хувилбарын архив

Энэ folder нь олимпиадын toolkit-ийн **frozen snapshot**-уудыг хадгална. Live (одоогийн) файлууд нь repo root болон `scripts/` дотор үлдсэн — энэ folder нь зөвхөн архив (compare хийх, өмнөх arrangement-руу буцах боломжтой).

---

## v1 — Single-mode era (2026-05-08)

**Концепци:** Нэг workflow, нэг командад бүгд (backup + topology + archive).

| Файл | Хэмжээ | Тайлбар |
|---|---|---|
| `v1/CLAUDE.md` | 36K | Бүхэл workflow reference (Linux + Windows) |
| `v1/OFFLINE_README.md` | 12K | Windows offline bootstrap (Python 3.12 default) |
| `v1/TROUBLESHOOTING.md` | 16K | 30+ алдаа → шийдэл + 6-тier manual fallback |
| `v1/olymp-run.py` | 24K | Single-mode orchestrator (full workflow only) |
| `v1/netmiko_backup.py` | 12K | Multi-cred fallback batch backup |
| `v1/netmiko_push.py` | 8K | Single-device push w/ auth fallback |
| `v1/diagnose-eve.py` | 20K | EVE pre-flight + per-node probe |

Хэрэглээ:
```bash
python3 docs/v1/olymp-run.py    # ердийн full backup
```

---

## v2 — Multi-mode + SecureCRT integration (2026-05-09)

**Концепци:** `--mode` flag-ээр 10 өөр workflow (backup, push-all, scrt, diagnose, gerly...). SecureCRT session-уудыг автоматаар үүсгэх + live config-руу deploy хийх. Sub-command орчестратор.

| Файл | Хэмжээ | Тайлбар |
|---|---|---|
| `v2/OLYMPIAD-RUNBOOK.md` | 16K | **(шинэ)** Бүх workflow-ийн reference |
| `v2/CLAUDE.md` | 36K | Multi-mode-той update хийгдсэн workflow |
| `v2/OFFLINE_README.md` | 12K | Windows offline (4 Python хувилбар bundle) |
| `v2/TROUBLESHOOTING.md` | 16K | (v1-той ижил, өөрчилөгдөөгүй) |
| `v2/olymp-run.py` | 36K | Multi-mode dispatch (full/setup/diagnose/backup/push/push-all/scrt/topology/archive/list-labs) |
| `v2/olymp-scrt.py` | 12K | **(шинэ)** SecureCRT session генератор |
| `v2/netmiko_backup.py` | 12K | (v1-той ижил logic) |
| `v2/netmiko_push.py` | 8K | (v1-той ижил logic) |
| `v2/diagnose-eve.py` | 20K | UTF-8 stdout/stderr separation, `--port`/`--tenant`/`--node-user` flag нэмсэн |

Хэрэглээ:
```bash
python3 scripts/olymp-run.py                   # full (default)
python3 scripts/olymp-run.py --mode backup     # backup only
python3 scripts/olymp-run.py --mode scrt --deploy
python3 scripts/olymp-run.py --mode push-all --yes
```

---

## Live файлууд (repo root + scripts/)

Эдгээр нь үргэлж хамгийн сүүлийн (одоо v2) хувилбар:

```
~/net/
├── CLAUDE.md                       # === docs/v2/CLAUDE.md
├── OLYMPIAD-RUNBOOK.md             # === docs/v2/OLYMPIAD-RUNBOOK.md
├── usb-offline/
│   ├── OFFLINE_README.md           # === docs/v2/OFFLINE_README.md
│   └── TROUBLESHOOTING.md          # === docs/v2/TROUBLESHOOTING.md
└── scripts/
    ├── olymp-run.py                # === docs/v2/olymp-run.py
    ├── olymp-scrt.py               # === docs/v2/olymp-scrt.py
    ├── netmiko_backup.py           # === docs/v2/netmiko_backup.py
    ├── netmiko_push.py             # === docs/v2/netmiko_push.py
    └── diagnose-eve.py             # === docs/v2/diagnose-eve.py
```

`docs/v2/` нь *git tag*-тэй адил frozen snapshot. Live файлууд цаашид өөрчлөгдсөн ч энэ snapshot хэвээр үлдэнэ.

---

## v1-руу буцах хэрхэн

Хэрэв v2-ийн multi-mode маргалзвал v1-ийг шууд ашиглаж болно:

```bash
# Сонголт A: docs/v1/-аас шууд ажиллуулах
python3 docs/v1/olymp-run.py

# Сонголт B: live файлуудыг v1-руу overwrite (анхаар: v2 алдагдана)
cp docs/v1/olymp-run.py scripts/olymp-run.py

# Сонголт C: git checkout тодорхой commit
git checkout b2cf942 -- scripts/olymp-run.py    # v1-ийн анхны commit
```

---

## Цаашид v3, v4 нэмэх

Дараагийн том өөрчлөлт хийсэн үед:

```bash
mkdir -p docs/v3
cp scripts/olymp-run.py docs/v3/
cp CLAUDE.md docs/v3/
# ...
# Дараа нь docs/README.md дээр v3 хэсгийг нэмэх
```

Live файлуудыг үргэлж хамгийн сүүлийн version-аар update хийнэ. `docs/v<N>/` нь зөвхөн архив.

---

## Compare хоёр version-ыг

```bash
# Олон файлыг харьцуулах
diff -r docs/v1/ docs/v2/

# Тодорхой файлыг
diff docs/v1/olymp-run.py docs/v2/olymp-run.py | head -50

# Эсвэл git-ээр (хэрэв commit history-аас сонирхвол)
git log --oneline scripts/olymp-run.py
git diff b2cf942..772ddee -- scripts/olymp-run.py
```

---

## Хувилбарын дугаар тогтоох (Тэмдэглэл)

Энэхүү repo-д **semantic version нэмлэгүй** — зөвхөн "v1, v2, v3..." гэсэн ahead/behind дараалал. Файлуудын `git log` нь жинхэнэ үнэн түүхийг хадгалдаг.

`v1` боломж/хязгаарлалт:
- ✅ Single command (`olymp-run.py`) бүгдийг хийдэг
- ✅ Interactive setup + conf хадгал
- ✅ Lab auto-detect, inventory, backup, topology, archive
- ❌ Push functionality алга
- ❌ SecureCRT integration алга
- ❌ Mode flag алга (зөвхөн full mode)

`v2` нэмэлтүүд:
- ✅ `--mode` flag (10 сонголт)
- ✅ Single + batch push (`push`, `push-all`)
- ✅ SecureCRT auto-generation + deploy (`scrt --deploy`)
- ✅ Diagnose mode (delegate to diagnose-eve.py)
- ✅ list-labs mode
- ✅ stdout/stderr separation (clean inventory.yml piping)
- ✅ Auto Python detection (find PyOlymp 3.12 if user has 3.14)

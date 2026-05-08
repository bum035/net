# Олимпиадын өдрийн RUNBOOK

> **Эх:** 2026-05-09 II шатны лабын автоматжуулсан workflow
> **Үндсэн tool:** `scripts/olymp-run.py` — нэг команд бүх алхмыг хийнэ
> **Өмнөх version-ууд:** [CLAUDE.md](CLAUDE.md), [usb-offline/OFFLINE_README.md](usb-offline/OFFLINE_README.md), [usb-offline/TROUBLESHOOTING.md](usb-offline/TROUBLESHOOTING.md) хэвээр үлдсэн

---

## 1. ⚡ Quick start (3 командыг л санаж байх)

```powershell
# (a) Цэвэр шинэ Windows бэлдэх (interneтгүй ч ажиллана)
cd %USERPROFILE%\net\usb-offline
.\setup-windows-offline.ps1

# (b) Бүх workflow эхлэх (эхний удаа prompt асууна)
python ..\scripts\olymp-run.py

# (c) SecureCRT session-уудыг live SecureCRT-руу deploy
python ..\scripts\olymp-run.py --mode scrt --deploy
```

---

## 2. `olymp-run.py` Mode Reference

| Mode | Юу хийдэг | Жишээ |
|---|---|---|
| **`full`** (default) | login → lab detect → inventory → backup → topology → archive | `olymp-run.py` |
| `setup` | Зөвхөн interactive prompt → conf хадгал | `olymp-run.py --mode setup --reconfigure` |
| `diagnose` | EVE pre-flight (TCP, login, lab list, per-node probe) | `olymp-run.py --mode diagnose` |
| `backup` | Inventory + backup (topology болон archive алгасах) | `olymp-run.py --mode backup --no-confirm` |
| `push` | Нэг `.cfg`-ийг харгалзах device-руу буцаах | `olymp-run.py --mode push --push-cfg path.cfg` |
| `push-all` | Сүүлчийн backup-ийг бүхэлд нь буцаах | `olymp-run.py --mode push-all --yes` |
| `scrt` | SecureCRT session `.ini` бүх device-д үүсгэх | `olymp-run.py --mode scrt --deploy` |
| `topology` | Зөвхөн graphviz dot/svg/png | `olymp-run.py --mode topology` |
| `archive` | Зөвхөн tar.gz | `olymp-run.py --mode archive` |
| `list-labs` | EVE-NG root-д буй бүх лабыг харуулах | `olymp-run.py --mode list-labs` |

### Глобал flag-ууд

| Flag | Үүрэг |
|---|---|
| `--reconfigure` | Conf-ыг ignore хийж дахин асуух |
| `--config <path>` | Тусдаа conf файл (default: `~/net/olymp.conf`) |
| `--lab "/path.unl"` | Active биш лабтай ажиллах |
| `--no-confirm` | "Press Enter" prompt алгасах |
| `--slow` | Timeout ихэсгэх (vIOS slowly boot үед) |
| `--raw-on-fail` | Backup алдаатай үед transcript .txt үүсгэх |
| `--yes`/`-y` | Push mode-уудад per-device confirm алгасах |
| `--deploy` | SCRT mode дээр live SecureCRT folder-руу хуулах |
| `--dry-run` | Backup-гүйгээр inventory + topology л үүсгэх |

---

## 3. Common workflow-ууд

### A. Эхлэлийн setup (олимпиадын өглөө)

```powershell
cd %USERPROFILE%\net

# 1) Interactive setup — IP/port/user/password/per-node creds асуух
python scripts\olymp-run.py --reconfigure

# 2) (`olymp.conf` save-ийн дараа автоматаар үргэлжилж):
#    EVE-руу login → active lab detect → inventory.yml + backup +
#    topology.svg/png + tar.gz үүсгэнэ

# 3) SecureCRT session-уудыг үүсгэх + live config-руу хуулах
python scripts\olymp-run.py --mode scrt --deploy
```

### B. Тогтмол backup (5-15 минут тутамд)

```powershell
# PowerShell — 5 минут тутамд автомат backup
while ($true) {
    python scripts\olymp-run.py --mode backup --no-confirm
    Start-Sleep -Seconds 300
}
```

```cmd
:: cmd.exe — нөгөө сонголт
for /l %i in (1,1,100) do (
    python scripts\olymp-run.py --mode backup --no-confirm
    timeout /t 300 /nobreak
)
```

### C. Config rollback (буруу config push хийсэн үед)

```powershell
# 1) Сүүлчийн good backup-аас бүх device-руу буцаах
python scripts\olymp-run.py --mode push-all --yes

# 2) Эсвэл тодорхой backup folder-аас
python scripts\olymp-run.py --mode push-all `
    --push-dir olymp-day\lab-XX\backup-2026-05-09_10-00 --yes

# 3) Эсвэл тодорхой нэг файлыг тодорхой device-руу
python scripts\olymp-run.py --mode push `
    --push-cfg olymp-day\lab-XX\backup-2026-05-09_10-00\R1_2026-05-09_10-00.cfg
```

### D. Олимпиадын явцад config debug

```powershell
# 1) Тодорхой device-руу нэвтрэх (SecureCRT GUI)
#    -> SecureCRT-ийн Sessions tree дээр <lab-name>/R1 click

# 2) inventory.yml-аас зөв порт олох
type olymp-day\lab-XX\inventory.yml

# 3) Шууд terminal-аас (no SecureCRT)
%USERPROFILE%\PyOlymp\Python312\python.exe scripts\netmiko_push.py `
    config-snippet.cfg --host 10.X.Y.Z --port 32769 --slow

# 4) Backup compare хийх (өмнөх vs одоогийн)
fc olymp-day\lab-XX\backup-2026-05-09_10-00\R1_*.cfg `
   olymp-day\lab-XX\backup-2026-05-09_11-00\R1_*.cfg
```

### E. Олон лабтай ажиллах

```powershell
# 1) Бүх лабын жагсаалт авах
python scripts\olymp-run.py --mode list-labs

# 2) Тодорхой лабтай ажиллах (active байгаагаас өөр)
python scripts\olymp-run.py --lab "/lab-02-bgp-full.unl"

# 3) Олон лабын backup нэг ажиллуулалтаар
foreach ($lab in @("/lab-01-ospf.unl","/lab-02-bgp.unl","/lab-04-vpn.unl")) {
    python scripts\olymp-run.py --mode backup --no-confirm --lab $lab
}
```

---

## 4. SecureCRT integration

### Setup
```powershell
python scripts\olymp-run.py --mode scrt --deploy
```

### Юу болдог
1. `inventory.yml` уншина (өмнө `--mode backup`-аар үүсгэсэн байх ёстой)
2. Device бүрд `pod-template/R1.ini`-ийг патчилна:
   - `S:"Hostname"=<EVE_IP>`
   - `D:"[Telnet] Port"=<8-hex>` (port 32769 → `00008001`)
   - `S:"Protocol Name"=Telnet`
3. **Хадгалах:**
   - `olymp-day/<lab>/secureCRT/R1.ini`, `R2.ini`, ...
4. **`--deploy` flag нэмбэл live SecureCRT folder-руу copy хийнэ:**
   - Windows: `%APPDATA%\VanDyke\Config\Sessions\<lab-name>\`
   - Linux: `~/.vandyke/SecureCRT/Config/Sessions/<lab-name>/`
5. SecureCRT-ийн Connection Manager-ыг **F4** эсвэл restart → шинэ session-ууд гарна

### Manual `olymp-scrt.py` (orchestrator-гүйгээр)
```powershell
# inventory.yml-аас
python scripts\olymp-scrt.py `
    --inventory olymp-day\lab-XX\inventory.yml `
    --output olymp-day\lab-XX\secureCRT --deploy

# Эсвэл шууд EVE API-аас
python scripts\olymp-scrt.py `
    --eve-host 10.X.Y.Z --eve-port 80 `
    --eve-user admin --eve-password Pass `
    --lab "/path/to.unl" `
    --output olymp-day\lab-XX\secureCRT --deploy
```

---

## 5. Файл бүтэц

```
~/net/                                  # Repo root (на Windows: %USERPROFILE%\net)
├── olymp.conf                          # Saved EVE/cred settings
├── CLAUDE.md                           # Бүтэн workflow reference (өмнөх)
├── OLYMPIAD-RUNBOOK.md                 # Энэ файл — олимпиадын өдрийн guide
│
├── scripts/
│   ├── olymp-run.py                    # Main orchestrator (mode dispatch)
│   ├── olymp-scrt.py                   # SecureCRT session generator
│   ├── netmiko_backup.py               # Batch backup (multi-cred fallback)
│   ├── netmiko_push.py                 # Single push (auth fallback + slow)
│   ├── diagnose-eve.py                 # EVE pre-flight checks
│   ├── setup-linux.sh                  # Linux bootstrap
│   ├── setup-windows.ps1               # Windows online bootstrap
│   ├── make-usb-bundle.sh              # USB .zip builder
│   └── eve_telnet.sh                   # Quick telnet helper (Linux)
│
├── usb-offline/                        # Цэвэр Windows offline bootstrap (~200MB)
│   ├── setup-windows-offline.ps1
│   ├── py-olymp.cmd                    # Wrapper for bundled Python
│   ├── OFFLINE_README.md               # Windows offline runbook
│   ├── TROUBLESHOOTING.md              # 30+ алдаа → шийдэл + manual fallback
│   ├── python-full/                    # 4 Python installer (3.10/3.11/3.12/3.13)
│   ├── python-embed/                   # 4 embed Python zip (no-admin)
│   ├── graphviz/                       # Graphviz portable
│   └── wheels[-py3XX]/                 # netmiko + 18 deps wheels
│
├── secureCRT/                          # Pre-bundled SecureCRT config payload
│   └── VanDyke/Config/Sessions/pod-template/   # Used by olymp-scrt.py as base
│
└── olymp-day/                          # Олимпиадын өдрийн workspace
    ├── <lab-name>/
    │   ├── inventory.yml                       # Auto-generated
    │   ├── topology.{dot,svg,png}              # Auto-generated
    │   ├── secureCRT/                          # SecureCRT .ini per device
    │   │   ├── R1.ini
    │   │   └── ...
    │   └── backup-<timestamp>/                 # 5+ minute snapshots
    │       └── <device>_<timestamp>.cfg
    └── <lab-name>-<timestamp>.tar.gz           # tar.gz snapshot
```

---

## 6. Олимпиадын өдрийн checklist

### Машин дээр (өглөө 1 цаг)
- [ ] Net repo-ыг `%USERPROFILE%\net`-руу clone/copy
- [ ] `cd net\usb-offline; .\setup-windows-offline.ps1` → ✅ All checks passed
- [ ] PowerShell-ыг хааж шинээр нээгээд `python --version` шалгах
- [ ] `python scripts\olymp-run.py --mode diagnose` → EVE-руу login + lab жагсаалт
- [ ] `python scripts\olymp-run.py --reconfigure` → IP/port/user/pass enter, conf save
- [ ] Эхний backup амжилттай, `inventory.yml` + `topology.png` + .cfg файлууд гарсан

### SecureCRT-тай ажиллах
- [ ] `python scripts\olymp-run.py --mode scrt --deploy`
- [ ] SecureCRT нээж F4 (Connection Manager refresh)
- [ ] Sessions tree-д `<lab-name>/R1, R2, ...` гарч буйг шалгах
- [ ] Нэг session-руу click → telnet нээгдэж prompt гарах ёстой

### Олимпиадын явцад
- [ ] PowerShell-н нэг tab-д 5-минутын backup loop ажиллуулах
- [ ] Конфиг засаж push-олонгоо боломжтой бол `wr mem` хийх
- [ ] Хагас цаг тутамд `--mode archive` хийж backup snapshot

### Дараа (хэрэв проблем гарвал)
- [ ] [TROUBLESHOOTING.md](usb-offline/TROUBLESHOOTING.md)-аас шинж тэмдэг хайх
- [ ] Шаардлагатай бол `--mode push-all --yes` rollback
- [ ] Эцсийн manual fallback: SecureCRT GUI / PuTTY / cmd telnet / browser HTML5

---

## 7. Troubleshooting summary

Дэлгэрэнгүй: **[usb-offline/TROUBLESHOOTING.md](usb-offline/TROUBLESHOOTING.md)** (30+ алдаа)

Хамгийн нийтлэг:

| Шинж тэмдэг | Хурдан шийдэл |
|---|---|
| `python: command not found` | PowerShell-ыг хааж шинээр нээ. Эсвэл `%USERPROFILE%\PyOlymp\Python312\python.exe`-ыг шууд дуудах |
| `ModuleNotFoundError: netmiko` | `python` нь 3.14 (no wheels). `usb-offline\py-olymp.cmd` wrapper ашигла |
| `UnicodeEncodeError` (cp1252) | (зассан) — git pull хийх |
| `EVE login failed: HTTP 500 Slim Application Error` | Tenant буруу эсвэл EVE буруу версион. `--reconfigure`-аар IP/user/pass дахин шалга |
| EVE login failed (creds) | `--mode diagnose` нь admin/eve, admin/admin, admin/unl, root/eve auto-try |
| Backup folder хоосон | `--raw-on-fail --slow` нэмж дахин ажиллуул, transcript .txt-аас алдаа хар |
| Telnet "Press RETURN" hang | `--slow` flag |
| Push `% Invalid input` | `--mode push --slow` ба per-line delay |

---

## 8. Recap — олимпиадын өдрийн ёс

### AI ашиглах
- ✅ Claude Code, claude.ai, ChatGPT — **зөвшөөрсөн**
- ✅ Internet хайлт, Cisco docs — зөвшөөрсөн
- ⚠️ AI буруу config гаргаж магадгүй — `show running-config` дээр өөрөө шалгах

### AI ашиглахгүй (өөрөө хийх)
- 🔴 Олимпиадын даалгаврыг **уншиж парс** хийх (топологи, шаардлагатай feature)
- 🔴 `show ip ospf neighbor` гарсан output-ыг **уншиж AI-руу буцааж** өгөх
- 🔴 Open standard эсвэл prepend хязгаарлалтыг AI-руу зөв тайлбарлах

### Backup-ийн зорилго
- Олимпиадын явцад **5 минут тутамд** snapshot үлдээх
- Хэрэв буруу команд орлоо → өмнөх snapshot-аас `--mode push-all`-аар буцаах
- Гарын авлагын дараа эцсийн снапшот → tar.gz архивыг submit-руу авч явах

---

## Хувилбарын түүх

| Дугаар | Файл | Огноо | Тайлбар |
|---|---|---|---|
| v1 | `CLAUDE.md` | 2026-05-08 хүртэл | Анхны workflow reference (Linux + Windows тус тус) |
| v1 | `usb-offline/OFFLINE_README.md` | 2026-05-08 | Windows offline bootstrap (Python 3.12, simple) |
| v1 | `usb-offline/TROUBLESHOOTING.md` | 2026-05-08 | Алдааны хүснэгт + manual fallback |
| **v2** | **`OLYMPIAD-RUNBOOK.md`** | **2026-05-09** | **Энэ файл — orchestrator multi-mode + SCRT integration** |

Git-ийн өмнөх commit-ууд бүх хувилбарыг хадгалсан: `git log --oneline scripts/olymp-run.py`

# Олимпиадын өдөр — Windows offline bootstrap

**Зорилго:** Цэвэр шинэ Windows 10/11 машинд интернетгүйгээр Python, netmiko, Graphviz-ийг
USB-аас нэг хүрэх click-ээр суулгаж, EVE-NG-руу холбогдож config татах/push хийх.

> 🟢 **Internet хэрэггүй**, гэвч **EVE-NG нь LAN дотор reachable** байх ёстой.

---

## 0. Юу багтсан

```
usb-offline/
├── setup-windows-offline.ps1     ← гол bootstrap (PowerShell, -Diagnose support)
├── OFFLINE_README.md             ← энэ файл (workflow runbook)
├── TROUBLESHOOTING.md            ← алдааны хүснэгт + manual fallback
├── python-full/
│   └── python-3.12.7-amd64.exe   (26MB, full installer — InstallAllUsers=0)
├── python-embed/
│   └── python-3.12.7-embed-amd64.zip  (11MB, no-admin fallback)
├── graphviz/
│   └── windows_10_cmake_Release_Graphviz-12.2.1-win64.zip  (9MB, dot.exe + dll-үүд)
├── wheels/                       ← Python 3.12 wheels (default)
│   ├── netmiko-4.6.0-py3-none-any.whl
│   ├── pyyaml-6.0.3-cp312-cp312-win_amd64.whl
│   ├── cryptography-48.0.0-cp311-abi3-win_amd64.whl  (abi3 — 3.11+ хүлээн авна)
│   ├── (... 21 dep wheels ...)
│   └── get-pip.py
├── wheels-py310/                 ← Fallback: existing Python 3.10 байвал
├── wheels-py311/                 ← Fallback: 3.11 байвал
└── wheels-py313/                 ← Fallback: 3.13 байвал
```

Нийт **~95 MB**.

---

## 1. USB-руу хуулах (өнөө орой, интернет байгаа үед)

```bash
# Linux дээр (хэрэв энэ репо clone-той бол)
cp -r ~/net /media/usb/                          # бүхэл репо
# Эсвэл tar:
tar -czf /media/usb/net-2026-05-08.tar.gz -C ~ net
```

`net/usb-offline/` нь репо дотор аль хэдийн орсон.

> 💡 Зөвхөн `usb-offline/`-г л USB-руу хуулсан ч setup ажиллана, гэвч дараагийн алхамд
> бүх `net/` репог хэрэглэх тул бүтнээр хуулсан нь дээр.

---

## 2. Олимпиадын өглөө — Windows-д суулгах

### Алхам A: USB зөв холбогдсон эсэхийг шалгах

USB drive-ыг (хэрвээ `D:`) өглөөд:
```powershell
ls D:\net\usb-offline
```
`setup-windows-offline.ps1` болон 4 subfolder харагдах ёстой.

### Алхам B: PowerShell нээгээд bootstrap-ыг ажиллуулах

```powershell
# PowerShell-ийг хэрэглэгчийн эрхээр (admin биш ч болно)
cd D:\net\usb-offline
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# 1) Эхлээд diagnose mode (зөвхөн төлвийг шалгана, install хийхгүй)
.\setup-windows-offline.ps1 -Diagnose

# 2) Бодит install
.\setup-windows-offline.ps1

# Сонголтот flag-ууд:
#   -ForceEmbed        full installer-аас зайлсхийж, embed Python-руу шилжих
#   -SkipPython        Python install алгасах (PATH дотор аль хэдийн байгаа гэж үзэх)
#   -InstallRoot D:\PyOlymp   диск дүүрсэн бол өөр drive-руу
```

Юу болно (5-7 сек):
1. ✅ Python 3.12 шалгана. Байгаа бол алгасна. Үгүй бол:
   - **Admin байх боломжтой** → `python-3.12.7-amd64.exe /quiet InstallAllUsers=0` →
     `%USERPROFILE%\PyOlymp\Python312\` дотор current-user install
   - **Admin биш** → `python-3.12.7-embed-amd64.zip`-ийг
     `%USERPROFILE%\PyOlymp\python-portable\`-руу задална, `_pth` засна,
     `get-pip.py`-аар pip bootstrap хийнэ
2. ✅ `pip install --no-index --find-links wheels netmiko pyyaml` (offline)
3. ✅ Graphviz portable-ыг `%USERPROFILE%\PyOlymp\graphviz\` руу унзана
4. ✅ Session-ийн PATH дээр Python + Graphviz нэмнэ + User PATH-д persist хийнэ
5. ✅ Smoke test: `import netmiko`, `dot -V`, `curl --version`, `tar --version`

Хүлээгдэх output-ийн төгсгөлд:
```
[ OK ] Python netmiko: netmiko 4.6.0
[ OK ] Graphviz: dot - graphviz version 12.2.1
[ OK ] curl: curl 8.x.x ...
[ OK ] tar: bsdtar 3.x.x ...
[ OK ] Бүх шалгуур passed. Олимпиадын toolkit бэлэн.
```

### Алхам C: net репог permanent байршилд хуулах

```powershell
Copy-Item -Recurse D:\net $env:USERPROFILE\net
cd $env:USERPROFILE\net
```

---

## 3. EVE-NG-руу холбогдох (өглөө, лаб эхлэхэд)

### 3.1 EVE-NG IP олох

Шалгуурын баг хэлсэн / browser bookmark-аас:
```powershell
$EVE = "http://10.X.Y.Z"
ping (([Uri]$EVE).Host) -n 2     # reach шалгах
```

### 3.2 Login + лаб жагсаалт авах

```powershell
$EVE = "http://10.X.Y.Z"
curl.exe -sk -c eve.cookie -X POST "$EVE/api/auth/login" `
  -H "Content-Type: application/json" `
  -d "{\`"username\`":\`"admin\`",\`"password\`":\`"eve\`",\`"html5\`":\`"-1\`"}"

# Лаб жагсаалт
curl.exe -sk -b eve.cookie "$EVE/api/folders/" | python -m json.tool
```

### 3.3 Идэвхтэй лабын node + порт авах

```powershell
$LAB = "lab-04-gre-ipsec-vpn.unl"   # бодит лаб нэрийг нэгээс орлуул

# Лаб онгойлгож node асаах
curl.exe -sk -b eve.cookie "$EVE/api/labs/$LAB/nodes/start"

# 60 секунд хүлээгээд node жагсаалт
Start-Sleep -Seconds 60
curl.exe -sk -b eve.cookie "$EVE/api/labs/$LAB/nodes" | python -m json.tool
```

JSON-аас `name`, `url` (telnet://EVE_IP:32769) ялгаж inventory.yml бичнэ.

### 3.4 inventory.yml бичих

`%USERPROFILE%\net\olymp-day\lab-XX\inventory.yml`:
```yaml
backup_dir: ~/net/olymp-day/lab-XX/backup-2026-05-09_HH-MM

devices:
  - name: R1
    host: 10.X.Y.Z
    port: 32769
    device_type: cisco_ios_telnet
  - name: R2
    host: 10.X.Y.Z
    port: 32770
    device_type: cisco_ios_telnet
  # ... бусад device-ууд
```

### 3.5 Backup татах

```powershell
cd $env:USERPROFILE\net
python scripts\netmiko_backup.py olymp-day\lab-XX\inventory.yml
```

Output:
```
[OK] R1: ...\backup-2026-05-09_HH-MM\R1_2026-05-09_HH-MM.cfg
[OK] R2: ...
```

### 3.6 Push (config засаж буцаах)

`olymp-day\lab-XX\push\R1.cfg` бичнэ (засвар), дараа нь:
```powershell
python scripts\netmiko_push.py olymp-day\lab-XX\push\R1.cfg `
  --host 10.X.Y.Z --port 32769 --type cisco_ios_telnet
```

### 3.7 Топологи зурах

```powershell
dot.exe -Tpng olymp-day\lab-XX\topology.dot -o olymp-day\lab-XX\topology.png
dot.exe -Tsvg olymp-day\lab-XX\topology.dot -o olymp-day\lab-XX\topology.svg
```

### 3.8 Архив

```powershell
$ts = Get-Date -Format "yyyy-MM-dd_HH-mm"
tar.exe -czf "olymp-day\lab-XX-snapshot-$ts.tar.gz" olymp-day\lab-XX
```

---

### 3.0 EVE-NG pre-flight (заавал хийнэ — лабтай ажил эхлэхээс өмнө)

```powershell
cd $env:USERPROFILE\net
python scripts\diagnose-eve.py --host 10.X.Y.Z --check-nodes --emit-inventory > olymp-day\lab-XX\inventory.yml
```

Энэ нэг командаар:
- ✅ EVE-NG TCP reachable эсэхийг шалгана
- ✅ admin/eve credentials шалгана (буруу бол common alternates [admin/admin, admin/unl, root/eve] оролдоно)
- ✅ Лаб жагсаалт + active lab-ыг харуулна
- ✅ Бүх node-ийн TCP + login-ийг шалгана (хоосон/cisco/admin зэрэг 6 cred-ийг auto-rotate)
- ✅ inventory.yml файлыг автоматаар үүсгэнэ

**Алдааны бүх шинж тэмдэг → `TROUBLESHOOTING.md`-д бий.**

## 4. Алдаа гарвал

| Шинж тэмдэг | Шалтгаан | Шийдэл |
|---|---|---|
| `setup-windows-offline.ps1: cannot be loaded ... not digitally signed` | Execution policy | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force` дахин |
| `python: command not found` (setup-ын дараа) | PATH session-д persist хийгдээгүй | PowerShell-ийг **хаагаад дахин нээ**, эсвэл setup-ыг дахин ажиллуул |
| `[FAIL] pip bootstrap амжилтгүй` (embed Python) | `_pth` засагдаагүй | `%USERPROFILE%\PyOlymp\python-portable\python312._pth` нээж `import site` мөрийн `#`-ыг арилга, `Lib\site-packages` мөр нэм |
| `pip install ... ERROR: No matching distribution` | Wheels тохирохгүй (Python 3.13 эсвэл өөр архитектур) | wheels/ дотор зөв `cp312-win_amd64` файл байгаа эсэхийг шалгана |
| `curl: (6) Could not resolve host` | DNS-аар нэр тогтоохгүй | EVE IP-г шууд ашигла, `ping <ip>` шалгах |
| `Login failed: <ip>` (netmiko) | `line con 0`/`line vty` дээр login key-тай | inventory.yml дотор `username:`, `password:` талбар нэм |
| `dot: not found` | `%USERPROFILE%\PyOlymp\graphviz\bin\` PATH-д алга | PowerShell дахин нээ |
| EVE-NG API 412 unauthorized | Cookie 90 минут expire | Step 3.2-г дахин ажиллуул (re-login) |
| `{"code":404}` open lab | Лабын path буруу | `/api/folders/` -аас бодит path-ийг хар |

---

## 5. Manual fallback (PowerShell ажиллахгүй бол)

### A. Python full installer admin-аар
```powershell
D:\net\usb-offline\python-full\python-3.12.7-amd64.exe
# GUI-аас "Install for All Users" + "Add to PATH" → Install
```

### B. pip wheel install
```powershell
cd D:\net\usb-offline\wheels
python -m pip install --no-index --find-links . netmiko pyyaml
```

### C. Graphviz unzip
```powershell
Expand-Archive -Path D:\net\usb-offline\graphviz\*.zip -DestinationPath C:\graphviz
$env:PATH += ";C:\graphviz\Graphviz-12.2.1-win64\bin"
```

### D. EVE-NG curl/python манual
3-р хэсгийн PowerShell командуудыг шууд copy-paste хийнэ.

---

## 6. Олимпиадын дараа цэвэрлэх (сонголт)

```powershell
Remove-Item -Recurse -Force $env:USERPROFILE\PyOlymp
# User PATH-аас Python + Graphviz хасах GUI: Settings → Environment Variables
```

---

## 7. Бэлэн байдлын checklist (өнөө орой)

- [ ] `usb-offline/` бүтэн USB-руу хуулсан
- [ ] `net/` репо USB-руу хуулсан
- [ ] **EVE-NG IP-ийг тэмдэглэсэн** (LAN-аас өглөө шалгана)
- [ ] **EVE admin/eve credentials** баталгаажсан
- [ ] PowerShell нь bypass execution policy-той (test on test machine)
- [ ] `reference/` PDF / 2024-2025 round2 config жишээ USB-д
- [ ] `cisco_highlights.jsonc` VS Code settings-д paste хийх template

> 🔑 **AI fallback алга** — Claude Code internet-гүй ажиллахгүй. `reference/`-д тулгуурла.

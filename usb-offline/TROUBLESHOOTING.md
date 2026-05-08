# TROUBLESHOOTING — алдааны хүснэгт + manual fallback

> Энэ файл нь олимпиадын өдрийн (2026-05-09) Windows машин дээр **юу нэг муу болоход** тохирох гарын авлага. Шинж тэмдгийг олоод → шалтгаан → шийдэл/manual workaround.

---

## A. Setup phase (Python, pip, Graphviz install)

### A1. `setup-windows-offline.ps1: cannot be loaded ... not digitally signed`
- **Шалтгаан:** PowerShell ExecutionPolicy = Restricted/AllSigned
- **Шийдэл:**
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
  .\setup-windows-offline.ps1
  ```

### A2. `Access is denied` Python install үед
- **Шалтгаан:** Антивирус .exe-г блок, UAC deny, эсвэл group policy
- **Шийдэл (1-р оролдох):** `-ForceEmbed` параметрээр embed Python-руу шилжих:
  ```powershell
  .\setup-windows-offline.ps1 -ForceEmbed
  ```
- **Шийдэл (2-р):** Defender exception нэмэх (admin шаардана):
  ```powershell
  Add-MpPreference -ExclusionPath "$PWD\python-full"
  Add-MpPreference -ExclusionPath "$env:USERPROFILE\PyOlymp"
  ```
- **Шийдэл (manual):** `python-3.12.7-amd64.exe`-г 2 удаа дарж GUI installer ашиглаж "Install for current user only", "Add to PATH" шалгана.

### A3. `pip install ... ERROR: Could not find a version that satisfies the requirement`
- **Шалтгаан:** Wheels файл Python хувилбартай таарахгүй (cp312 wheel + python 3.10 → fail)
- **Шийдэл:** `setup-windows-offline.ps1` нь auto-detect хийж зөв wheels-folder сонгоно. Гар:
  ```powershell
  python --version            # 3.10? 3.11? 3.12? 3.13?
  # Дараа нь:
  python -m pip install --no-index --find-links D:\net\usb-offline\wheels-py311 netmiko pyyaml
  #                                              ↑ хувилбарт тохируул
  ```

### A4. Setup амжилттай бөгөөд `python` гэж бичсэн ч "command not found"
- **Шалтгаан:** PATH session-д хадгалагдсан, гэхдээ шинэ PowerShell нээсэн
- **Шийдэл:** PowerShell-ыг **бүрэн хааж** дахин нээ. Эсвэл:
  ```powershell
  $env:PATH = "$env:USERPROFILE\PyOlymp\Python312;$env:USERPROFILE\PyOlymp\graphviz\bin;" + $env:PATH
  ```
- **Persistent шалгах:**
  ```powershell
  [Environment]::GetEnvironmentVariable('Path','User')
  ```

### A5. Embed Python: `ModuleNotFoundError: No module named 'netmiko'`
- **Шалтгаан:** `_pth` файл засагдаагүй → `site-packages` импорт идэвхгүй
- **Шийдэл:** `%USERPROFILE%\PyOlymp\python-portable\python312._pth`-ыг Notepad-аар нээ:
  ```
  python312.zip
  .
  import site            ← `#`-ыг арилга
  Lib\site-packages      ← энэ мөрийг нэм
  ```

### A6. `Expand-Archive: ... archive is corrupt`
- **Шалтгаан:** USB-аас copy хийхэд алдаа, эсвэл бундл хагас татагдсан
- **Шийдэл:** USB-аас файлуудын SHA256 шалгах:
  ```powershell
  Get-FileHash D:\net\usb-offline\python-full\python-3.12.7-amd64.exe
  # Хүлээгдэх: ...3.12.7-Windows-amd64.exe-ийн github release-аас checksum
  ```
- **Manual:** `7-Zip` / WinRAR ашиглаж .zip-ийг гар дэлэн задал.

### A7. `Disk full` (200MB+ хүртэл хэрэгтэй)
- **Шалтгаан:** %USERPROFILE% drive дээр зай хүрэхгүй
- **Шийдэл:** `-InstallRoot` параметрээр өөр диск-руу:
  ```powershell
  .\setup-windows-offline.ps1 -InstallRoot D:\PyOlymp
  ```

---

## B. EVE-NG connectivity

### B1. EVE IP олдохгүй
- **Шалтгаан:** Олимпиадын баг IP хэлээгүй, эсвэл DHCP
- **Олох арга 1 — browser bookmark / hist:**
  ```
  Edge/Chrome address bar → "10.2"-аар эхэлдэг URL хайх
  ```
- **Олох арга 2 — network scan (admin):**
  ```powershell
  $myIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' })[0].IPAddress
  $subnet = $myIp -replace '\.\d+$',''
  1..254 | ForEach-Object -ThrottleLimit 50 -Parallel {
      if (Test-NetConnection "$using:subnet.$_" -Port 80 -InformationLevel Quiet) {
          Write-Host "$using:subnet.$_:80 open"
      }
  }
  ```
- **Олох арга 3 — диагноз ажиллуулж test:**
  ```powershell
  python scripts\diagnose-eve.py --host 10.2.0.163 -Diagnose 2>&1
  ```

### B2. `HTTP 412 unauthorized` (cookie expired)
- **Шалтгаан:** EVE-NG cookie 90 минут хүчинтэй
- **Шийдэл:** Re-login:
  ```powershell
  curl.exe -sk -c eve.cookie -X POST "$EVE/api/auth/login" `
    -H "Content-Type: application/json" `
    -d '{"username":"admin","password":"eve","html5":"-1"}'
  ```

### B3. EVE-NG default `admin/eve` ажиллахгүй
- **Шалтгаан:** Олимпиадын баг өөрчилсөн магадгүй
- **Шийдэл:** Common-default-уудыг оролдох:
  | user | password |
  |---|---|
  | admin | eve |
  | admin | unl |
  | admin | admin |
  | admin | Admin@123 |
  | root | eve |
- `diagnose-eve.py` нь auto-fallback хийдэг.

### B4. EVE-NG зөвхөн HTTPS дээр
- **Шийдэл:**
  ```powershell
  curl.exe -sk ...   # -k = insecure (self-signed cert OK)
  python scripts\diagnose-eve.py --host https://10.X.Y.Z
  ```

### B5. `404 Lab does not exist`
- **Шалтгаан:** Лаб folder дотор оршдог, root-д биш
- **Шийдэл:**
  ```powershell
  curl.exe -sk -b eve.cookie "$EVE/api/folders/" | python -m json.tool
  # data.folders дотор лабын folder-ыг хайна
  curl.exe -sk -b eve.cookie "$EVE/api/folders/MyFolder/"
  ```

### B6. Лаб running боловч node-ууд status=0/stopped
- **Шалтгаан:** Лаб онгойлгосон гэвч node-уудыг асаагаагүй
- **Шийдэл:**
  ```powershell
  curl.exe -sk -b eve.cookie "$EVE/api/labs/<lab>.unl/nodes/start"
  Start-Sleep 60                 # vIOS boot ~60s
  ```

---

## C. Node authentication

### C1. `Login failed: <ip>` (netmiko)
- **Шалтгаан:** Console line-д username/password байна
- **Шийдэл (auto):** `netmiko_backup.py` нь default 6 cred-ийг автомат оролдоно
- **Шийдэл (manual):** inventory.yml-д тодорхой cred оруул:
  ```yaml
  devices:
    - name: R1
      host: 10.X
      port: 32769
      username: cisco
      password: cisco
      secret: cisco
  ```

### C2. `% Authentication failed` (enable mode)
- **Шалтгаан:** Enable secret өөр password
- **Шийдэл:** `secret` талбарыг тусдаа оноо:
  ```yaml
  - name: R1
    username: cisco
    password: cisco_user_pw
    secret: cisco_enable_pw
  ```

### C3. Telnet холбогдсон гэвч "Press RETURN to get started" → hang
- **Шалтгаан:** Console banner төлөвт зогссон, netmiko Enter явуулаагүй
- **Шийдэл:** `--slow` флагаар banner_timeout 30s-руу:
  ```powershell
  python scripts\netmiko_backup.py inv.yml --slow
  ```
- **Manual:** SecureCRT-аар нээгээд гар Enter-ээр "press RETURN"-ыг өнгөрөөнө.

### C4. Router нь "Would you like to enter the initial configuration dialog?" асууж байна
- **Шалтгаан:** Шинэ vIOS, startup-config байхгүй
- **Шийдэл (manual):** SecureCRT-аар `no` гэж явуулна. Дараа нь:
  ```
  enable
  configure terminal
  no service config
  end
  write memory
  ```
- Дахиад backup ажиллахад config бэлэн.

### C5. Console-д `Translating "..." domain server (255.255.255.255)` 1+ минут хүлээж байна
- **Шалтгаан:** `no ip domain-lookup` тохируулаагүй, ASCII typo-г DNS-аар lookup хийж байна
- **Шийдэл:** `Ctrl+Shift+6` дарж interrupt → `no ip domain-lookup` гар бичих

### C6. SSH-д `cisco_ios` device_type холбогдохгүй
- **Шалтгаан:** Telnet л идэвхтэй (default vIOS)
- **Шийдэл:** Telnet ашиглах (`cisco_ios_telnet`) — vIOS default-аар SSH идэвхгүй
- **Эсвэл SSH идэвхжүүлэх (manual SecureCRT-аар):**
  ```
  conf t
  hostname R1
  ip domain-name lab.local
  crypto key generate rsa modulus 2048
  username admin password 0 cisco
  line vty 0 4
   transport input ssh
   login local
  end
  ```

---

## D. Backup/push issues

### D1. Backup file дотор `--More--` гарч байна
- **Шалтгаан:** `terminal length 0` явагдаагүй (banner caught it)
- **Шийдэл:** `netmiko_backup.py` нь pre-cmd-ээр явуулдаг. `--slow` нэмэх:
  ```powershell
  python scripts\netmiko_backup.py inv.yml --slow
  ```

### D2. Push `% Invalid input detected` зарим line-д
- **Шалтгаан:** Sub-mode эсвэл sequence буруу
- **Шийдэл:** `--delay-per-line 0.5` гар бичсэн адил push:
  ```powershell
  python scripts\netmiko_push.py R1.cfg --host 10.X --port 32769 --delay-per-line 0.5
  ```
- **Эсвэл:** `--dry-run` flag-аар command line жагсаалтыг хар → SecureCRT-руу гар paste

### D3. Push дунд `Connection lost / Session timeout`
- **Шалтгаан:** Reload command орчигдсон, link flap, эсвэл буруу IP-руу гарсан
- **Шийдэл:** Сэргэх нь:
  - 30 секунд хүлээ → дахиад telnet → бэлэн байгаа эсэхийг шалгах
  - Хэрэв running-config rollback хэрэгтэй бол өмнөх backup-аас:
    ```powershell
    python scripts\netmiko_push.py backup\R1_old.cfg --host 10.X --port 32769
    ```

### D4. `wr mem` команд hang
- **Шалтгаан:** NVRAM full / flash IO slow
- **Шийдэл:** `--no-save` flag → дараа гараар:
  ```
  R1# copy running-config startup-config
  Destination filename [startup-config]?    [Enter]
  ```

---

## E. Манual fallback — script бүтэлгүйтсэн үед

### E1. SecureCRT-аар олон node-аас config татах
1. SecureCRT нээ → Sessions tree-аас `pod-template/R1`...`R3` хэлхээ
2. Бүх tab сонгоод **Send Commands to All Sessions** ON
3. Toolbar дээр `BACKUP` товч (Linux дээр Python re-target хэрэгтэй)
4. Эсвэл Manual:
   - `Script → Run...` → `~/net/secureCRT/VanDyke/Config/Scripts/backup_configs.py` (Linux)
   - Windows бол `Scripts/backup_configs.vbs`
5. Гарах байршил: `%USERPROFILE%\OlympBackup\` (default)

### E2. SecureCRT-гүйгээр PuTTY/cmd-аар manual telnet
```cmd
REM Windows cmd.exe
telnet 10.2.0.163 32769
REM Дотор:
terminal length 0
show running-config
```
Гарч буй текстийг сонгоод `Ctrl+C` (cmd-ийн mark mode), Notepad-руу paste, `R1.cfg`-аар хадгал.

> 💡 **PowerShell-ийн built-in telnet**: Windows-д default-аар suussan биш. Optional Features-ээс enable хэрэгтэй (admin):
> ```powershell
> Enable-WindowsOptionalFeature -Online -FeatureName "TelnetClient"
> ```
> **Эсвэл PuTTY portable** (`putty.exe`-ийг USB-руу) — host=10.2.0.163, port=32769, type=Telnet → "Logging" → All session output → file сонго → автомат хадгалагдана.

### E3. Browser-аас EVE-NG HTML5 console
EVE-NG WebUI:
1. Лаб онгойлгох → node-руу right-click → **Console**
2. HTML5 telnet шинэ tab-д нээгдэнэ
3. `terminal length 0` → `show running-config`
4. Browser-аас All select (Ctrl+A) → Copy → Notepad-руу paste

### E4. EVE-NG-аас зөвхөн node-ийн **startup-config**-ыг скачать (config экспорт)
```powershell
$EVE = "http://10.X"
# Login, дараа нь:
curl.exe -sk -b eve.cookie -X PUT "$EVE/api/labs/<lab>.unl/nodes/<id>/config/save"
# config зөвхөн EVE backend-д хадгалагдсан startup-config (running биш)
curl.exe -sk -b eve.cookie "$EVE/api/labs/<lab>.unl/nodes/<id>/config" -o R1_startup.txt
```
> ⚠️ Энэ нь **startup-config** л татна, running-аас өөр байж магадгүй. `wr mem`-гүй өөрчлөлт орохгүй.

### E5. Notepad++ macros-аар олон config зэрэг засах
1. Notepad++ нээ
2. Бүх .cfg файл нээ (Ctrl+O олонг)
3. Macro → "Find in all opened" / "Replace in all"
4. SecureCRT-аар буцаах: `File → Save All` → дараа SecureCRT chat → `pc_ip.spsl` шиг paste

### E6. Хамгийн сүүлчийн fallback — гар бичих
- Олимпиадын даалгаврын config-ийг **гар бичих**, paste хийх. SecureCRT chat window нь олон line paste-ыг зохицуулна.
- `cisco_highlights.jsonc` VS Code дотор бичсэн config-ийг өнгөтэй харуулна → typo олоход тус болно.

---

## F. Common Cisco cheat sheet (offline reference)

### Privilege escalation
```
enable                       # user → priv exec
configure terminal           # priv → config
end / exit                   # config → priv
disable                      # priv → user
```

### Save / show / verify
```
show running-config
show ip interface brief
show ip route
show ip ospf neighbor
show ip bgp summary
show etherchannel summary
show vlan brief
show interfaces trunk
write memory                 # save running → startup
copy running-config tftp:    # external backup
```

### Reset config (last resort — DANGEROUS)
```
write erase
reload                       # confirm with `n` to NOT save running first
```

### vIOS-ийн common quirks
- `crypto key generate rsa` shell-руу буцахгүй гэж байгаа бол `Ctrl+Shift+6` дараад буцах
- `do show ...` — config mode-оос show команд явуулах
- `show run | sec interface` — section-аар filter

---

## G. Олимпиадын өдрийн нэг удаагийн checklist

- [ ] USB-аас net/ folder-ыг C:\Users\<me>\net руу хуулсан
- [ ] `setup-windows-offline.ps1 -Diagnose` амжилттай ажилласан
- [ ] `python scripts\diagnose-eve.py --host <EVE_IP> --check-nodes` бүх node OK
- [ ] inventory.yml бичсэн (auto-emit-ээс эсвэл гар бичсэн)
- [ ] `python scripts\netmiko_backup.py olymp-day\lab-XX\inventory.yml` амжилт
- [ ] OlympBackup folder-д .cfg файлууд хадгалагдсан
- [ ] Топологи зураг үүссэн (`dot -Tpng topology.dot`)
- [ ] SecureCRT нь pod sessions харуулж байна (fallback ready)
- [ ] PuTTY portable USB-д бэлэн байна (E2 fallback)
- [ ] reference/ PDF + 2024/2025 round2 жишээ config унших боломжтой

---

## H. Хурдан reset (бүх зүйл буруу болсон үед)

```powershell
# Бүх install-ыг устгаж, бүтнээр дахин эхлэх
Remove-Item -Recurse -Force $env:USERPROFILE\PyOlymp -ErrorAction SilentlyContinue
[Environment]::SetEnvironmentVariable('Path',
  ([Environment]::GetEnvironmentVariable('Path','User') -replace 'PyOlymp[^;]*;?',''),
  'User')

# Дараа нь дахиад:
.\setup-windows-offline.ps1
```

---

## I. Хэн хариулах вэ (онцгой алдаа)

| Алдаа | Хариуцах |
|---|---|
| Олимпиадын баг сэрээгүй EVE-NG IP | Шалгуурын баг |
| EVE-NG нэвтрэх эрх | Шалгуурын баг |
| Network connectivity (LAN flap) | IT support |
| Pod-ийн node-ийн device pwd | Шалгуурын баг |
| Лабын даалгаврын content (config төлөвлөгөө) | **AI/reference/прев. жилийн жишээ** (өөрөө) |

> 🔑 Олимпиадын дүрмээр AI болон internet **зөвшөөрсөн** — Claude Code сесси-р offline-аас ч interactive AI ажиллахгүй гэх мэт нөхцөлд CLAUDE.md болон reference/ дотор алхам алхмаар бичсэн ёсоор биеэ даан config бичнэ.

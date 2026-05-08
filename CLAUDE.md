# net/ — Олимпиадын өдрийн toolkit

**Тусдаа git repo** (origin: `https://github.com/bum035/net.git`, branch `main`). Олимпиад болон лаб дээр **GitHub clone (эсвэл USB)-аар зөөдөг config + reference toolkit**. Олимпиадын компьютерт SecureCRT, PuTTY, VS Code аль хэдийн суусан байгаа — энэ folder зөвхөн **тохиргоо, snippet, reference**-г агуулна.

**Зорилго**: 2026-05-09 II шатны лаб дээр SecureCRT/VS Code/Claude Code-ийг хамгийн бага алхамаар бэлэн болгох.

> 🟢 **Олимпиадын дүрэм**: AI болон интернет **ЗӨВШӨӨРСӨН**. Claude Code, claude.ai, ChatGPT, Google, Cisco/NX-OS docs бүгд ашиглах боломжтой. Доорх workflow-д Claude Code-ыг гол edit tool гэж тооцсон.

## Setup workflow (олимпиадын машин дээр)

### Алхам 1 — Repo татах

**A. GitHub clone (preferred):**
```powershell
cd $env:USERPROFILE
git clone https://github.com/bum035/net.git
code .\net
```

Git суугаагүй бол Git-for-Windows portable татах эсвэл `.zip` download:
```
https://github.com/bum035/net/archive/refs/heads/main.zip
```

**B. USB fallback (интернет байхгүй бол):** `net/` folder-ыг USB рүү copy (~5 MB, .git-гүйгээр).

### Алхам 2 — SecureCRT config

`secureCRT/VanDyke/Config/` доторхыг `%APPDATA%\VanDyke\Config\` рүү хуулна (хуучин contents-ыг урьдчилан backup хийнэ). Эсвэл junction (preferred — repo-руу зааж өгнө, шинэчлэлт автоматаар орно):
```powershell
Move-Item "$env:APPDATA\VanDyke\Config" "$env:APPDATA\VanDyke\Config.bak" -ErrorAction SilentlyContinue
New-Item -ItemType Junction -Path "$env:APPDATA\VanDyke\Config" -Target "$env:USERPROFILE\net\secureCRT\VanDyke\Config"
```

### Алхам 3 — VS Code highlighting + Claude Code

1. VS Code extensions суулгах:
   ```powershell
   code --install-extension fabiospampinato.vscode-highlight
   code --install-extension Anthropic.claude-code   # Claude Code VS Code extension
   ```
2. `cisco_highlights.jsonc`-ыг VS Code → `Ctrl+Shift+P` → "Preferences: Open User Settings (JSON)" → root-к `highlight.regexes` object-ыг paste.
3. **Claude Code login**:
   - `Ctrl+Esc` → Claude Code panel → Sign in
   - Эсвэл terminal-аас: `npx @anthropic-ai/claude-code` → browser auth
   - **Backup**: claude.ai веб interface (login session нөөц)

### Алхам 4 — EVE-NG telnet handler (optional)

Хэрэв EVE-NG web UI-аас "Connect" товчоор ажиллахыг хүсвэл: `EVE-NG/win10_64bit_sCRT.reg` дээр double-click → merge. Бусад `.reg` нь VNC/Wireshark-д зориулагдсан, апп нь суугаагүй бол хэрэггүй.

### Алхам 5 — SecureCRT restart

Бүгдийг хэрэгжүүлсний дараа SecureCRT-г бүрэн хааж нээнэ (Global.ini-ийг зөв унших).

## AI / Claude Code workflow (олимпиадын өдөр)

> 🟢 AI болон интернет зөвшөөрөгдсөн. Claude Code-ыг гол edit tool болгож ашиглана.

### Үндсэн цикл

```
EVE-NG WebUI → SecureCRT (console)
              ↓ Button Bar: BACKUP
    %USERPROFILE%\OlympBackup\R1_<ts>.cfg
              ↓ VS Code workspace
    Claude Code chat: "Энэ config-д X алдаа байна. засаарай"
              ↓ Edit applied to .cfg
    SecureCRT → Button Bar: PUSH (push_config.vbs)
              ↓
    Router-руу line-by-line paste (LINE_DELAY_MS=50)
```

### Useful Claude prompt template-үүд

`reference/prompts.md` (хэрэв нэмбэл):

| Зорилго | Prompt template |
|---|---|
| Алдааг олох | "Энэ Cisco config-д ____ ажиллахгүй байна. show output: <paste>. Шалтгаан болон засварыг өг" |
| Syntax conversion | "Энэ IOS config-ыг NX-OS syntax руу хөрвүүл, feature командуудыг бүгд багтаа" |
| Generate config | "AS 17000 iBGP RR-ээс client RR1-руу IPv4 + IPv6 family activate хийдэг config бичиж өг" |
| Verify | "Энэ vPC peer-link config зөв үү? `vpc peer-link` нь port-channel дээр л байх ёстой" |
| Troubleshoot logic | "BGP neighbor 'Active' state-д наалджээ. Шалгах команд + хэрэв `update-source` алгассан бол хэрхэн засах вэ?" |
| Olympiad task parse | "Энэ даалгавар: <paste>. Топологи болон тавьсан шаардлагыг нэгтгэн config skeleton гарга" |

### AI ашиглахгүй хэсэг (өөрөө хийх ёстой)

- **Хариу шалгах** — AI буруу config гаргаж магадгүй (вершин syntax, deprecated keyword). `show run` дээр өөрөө хяна.
- **Шалгуурын логик** — олимпиадын даалгаврыг **өөрөө уншиж**, хязгаарлалтыг (open standard, prepend ашиглахгүй г.м.) AI-руу зөв тайлбарлах ёстой.
- **Debugging** — AI шалтгааныг хэлж чадавч `show ip ospf neighbor`-ийн output-ыг **өөрөө уншиж** AI-руу буцаах ёстой.

### Backup plan — интернет тасрах

Хэрэв АН нь wifi/wired interrupt вэл:

1. `net/reference/lab-NN.pdf` (offline cheat sheet) → 5 лабын syntax + topology тус бүрд
2. `net/reference/2024_round2/` болон `net/reference/2025_round2/` → бэлэн жишээ config
3. `.spsl` snippet-үүд (`pc_ip`, `nat_pat`, `ipsec_gre`, `show`)
4. SecureCRT Button Bar (DHCP, OSPF, BGP, ACL, NAT категориуд)

**Шалгах:** Олимпиадын өмнөх өдөр (өнөөдөр) wifi-ыг unplug хийгээд бүх workflow ажиллаж буйг шалгах.

## Layout

| Path | Үүрэг |
|---|---|
| `secureCRT/VanDyke/Config/` | **SecureCRT config payload** — Sessions, Commands, Keywords, Scripts, ButtonBar, Global.ini. **`%APPDATA%\VanDyke\Config\`-руу хуулагдах ёстой** |
| `EVE-NG/` | EVE-NG protocol handlers — `.reg` (telnet/vnc/wireshark URL handler) + `.bat` wrappers. Зөвхөн EVE-NG web UI-ийн "Connect" workflow-д хэрэгтэй |
| `OlympBackup/` | `backup_configs.vbs`-ийн өмнөх run-ийн жишээ (test data) — олимпиадын дараа цэвэрлэж болно |
| `cisco_highlights.jsonc` | VS Code Highlight extension regex (`.cfg`-д өнгө) — SecureCRT-н "Cisco Words - DkBg" port |
| `*.spsl` | SecureCRT chat-paste snippet (`pc_ip`, `show`, `nat_pat`, `ipsec_gre`) |
| `button bar.sh` | Button bar товчны жагсаалтын текст reference |
| `reference/` | Offline cheat sheet, lab PDF, өмнөх жилийн config-ууд, AI prompt template (АН тасрах эсвэл хурдан хайх боломж) |
| `.gitignore` | `*.exe`, license artifacts, pre-installed binary folder-уудыг ignore |

## SecureCRT config — `VanDyke/Config/`

`%APPDATA%\VanDyke\Config\`-той ижил структуртэй. Хуулах эсвэл junction-аар link хийх (USB drop-in workflow дээр харна уу).

### Critical файлууд

| Файл | Юу хийдэг |
|---|---|
| `Sessions/Default.ini` | SSH2 template. Font: **Cascadia Code 12** / narrow Lucida Console |
| `Sessions/pod-template/` | **Бэлэн стуб session-ууд** — `R1`, `R2`, `R3`, `SW1`, `SW2`, `SW3` (Telnet, Default-аас бусад settings inherited). Pod-ийн IP мэдсэний дараа right-click → **Clone Session** хийж `pod1/R1` руу хувилаад Hostname/Port-ыг оруулна |
| `Commands/<topic>/__Commands__.ini` | Button Bar команд (dhcp/etherch/interface/nat/routing/show). `\\r` = Enter. `SEND_TO_ALL_SESSIONS` нь "Send Commands to All Sessions" toggle идэвхтэй tab бүрд илгээнэ |
| `Keywords/Cisco Words - DkBg.ini` | SecureCRT терминалын **үг-түвшний** highlighting. `cisco_highlights.jsonc`-той нийцтэй байх ёстой — нэг үг хоёр дээр хоёр өөр өнгөтэй байвал төөрнө |
| `Scripts/backup_configs.vbs` | Бүх tab-аас `show running-config` татаж `%USERPROFILE%\OlympBackup\<hostname>_<timestamp>.cfg`. `%OLYMP_BACKUP_DIR%` орчны хувьсагч тавьсан бол түүнийг ашиглана (admin permission-гүй машин дээр C:\-руу бичих ёсгүй) |
| `Scripts/push_config.vbs` | `.cfg` файлыг идэвхтэй session-руу мөр-мөрөөр push (`LINE_DELAY_MS=50`). File picker default — backup-той ижил зам |
| `ButtonBarV5.ini` | Toolbar товчуудын тодорхойлолт (`button bar.sh` нь reference хувилбар) |
| `Global.ini` | Global preferences. Font, color, keymap дотроос гарна — patch хийхэд **SecureCRT хаасан байх ёстой**, нээлттэй үед өөрөө дарж бичнэ |
| `SCRTMenuToolbarV3.ini` | Menu/toolbar layout |

## VS Code Cisco highlighting

`cisco_highlights.jsonc` нь `fabiospampinato.vscode-highlight` extension-д зориулагдсан.

1. Extension суулгана (`code --install-extension fabiospampinato.vscode-highlight`).
2. JSON object-ийг **User `settings.json`**-д paste — root-key нь аль хэдийн `highlight.regexes` гэж бичигдсэн.
3. `.cfg` файлд "cisco" language ID онооно:
   ```json
   "files.associations": { "*.cfg": "cisco" }
   ```
   `language-cisco` extension суулгасан бол automatic. `filterLanguageRegex: "cisco"` нь зөвхөн "cisco" language-тай файлд highlight идэвхжүүлнэ — бусад файлд noise болохгүй.

`OlympBackup/R1_*.cfg`-г нээгээд тэст хийнэ. IP, interface, hostname, dangerous (`reload`, `erase`), routing protocol бүгд гэрэлтэх ёстой.

### SecureCRT keyword-той synchronization

SecureCRT-ийн `Keywords/Cisco Words - DkBg.ini`-д үг нэмэх үед `cisco_highlights.jsonc`-д **ижил үгийг ижил өнгөөр** бичнэ. Хоёр газарт зөрвөл VS Code дотор болон SecureCRT терминал дээрх ижил config өөр өнгөтэй харагдаж эргэлзээ үүснэ.

## .spsl quick-paste snippet-үүд

SecureCRT chat window дээр right-click → **Send → Paste**. Эсвэл `View → Chat Window` нээгээд text paste → **Send Chat to All**. Файл бүр `#section` comment header-тай.

| Файл | Контент |
|---|---|
| `pc_ip.spsl` | VPCS-д IP оноох (`ip 192.168.1.10/24 192.168.1.1` + `save`) |
| `show.spsl` | `show etherchannel summary` |
| `nat_pat.spsl` | Static NAT, dynamic NAT, PAT reference |
| `ipsec_gre.spsl` | GRE+IPsec router-1/router-2 бүрэн config (3DES/MD5/group2 — олимпиадын legacy IOS-д тохирсон) |

> **Анхаар**: `.spsl` доторх IP, AS number бол **жишээ**. Pod-ийн actual addressing-той тааруулж засах ёстой.

## EVE-NG client integration (`EVE-NG/`)

`EVE-NG/` бол **EVE-NG Web UI-аас "Connect" товч дарахад SecureCRT/PuTTY-г local launch** хийх workflow-ын registry handler-ууд. Зөвхөн web UI-аас шууд асаах хэрэгтэй үед merge хийх — SecureCRT-аас Sessions tree-р холбогдоход хэрэггүй.

| Файл | Үүрэг |
|---|---|
| `win10_64bit_sCRT.reg` | `telnet://` URL handler → SecureCRT |
| `win10_64bit_putty.reg` | `telnet://` → PuTTY (fallback) |
| `win7_64bit_ultravnc.reg` + `ultravnc_wrapper.bat` | `vnc://` → UltraVNC (UltraVNC суусан үед) |
| `win7_64bit_wireshark.reg` + `wireshark_wrapper.bat` | `wireshark://` → Wireshark capture (Wireshark суусан үед) |

`.reg`-ийг merge хийхээсээ өмнө SecureCRT-ийн **актуал суусан зам** (`C:\Program Files\VanDyke Software\SecureCRT\SecureCRT.exe`) олимпиадын машин дээрхтэй таарч буй эсэхийг текст editor-аар нээж шалгана.

## Олимпиадын өдрийн checklist

### Repo & Tools
- [ ] `git clone https://github.com/bum035/net.git` амжилттай (эсвэл USB fallback)
- [ ] VS Code workspace-аар `net/` нээгдсэн
- [ ] SecureCRT суулгасан + лиценз идэвхжүүлсэн
- [ ] Config folder-ыг repo-руу зааж өгсөн (Options эсвэл junction)
- [ ] `%USERPROFILE%\OlympBackup\` фолдер үүссэн, write permission-той (эсвэл `%OLYMP_BACKUP_DIR%` тавьсан бол тэр зам)
- [ ] `backup_configs.vbs`-ийг button bar-аас дарж 1-2 минутаар тэст — output файл бий болж байгаа эсэх
- [ ] VS Code-д `fabiospampinato.vscode-highlight` идэвхтэй, `OlympBackup/R1_*.cfg` дээр өнгө гарч буйг шалгасан
- [ ] EVE-NG-Win-Client-Pack суулгасан, `.reg`-ийг merge хийсэн
- [ ] Pod-ийн IP мэдсэний дараа `Sessions/`-д бүртгэх (`pod1/R1`, `pod1/SW1` гэх folder-аар)
- [ ] Button Bar нь зөв group-ыг харуулж буй эсэх (Default дээр `clean_ALL`, `BACKUP`, `PUSH` товчтой)

### AI / Internet
- [ ] Wifi/wired интернет ажиллаж байгаа (speedtest эсвэл `ping 8.8.8.8`)
- [ ] **Claude Code VS Code extension** суулгасан (`Anthropic.claude-code`) болон login хийсэн
- [ ] **Claude Code CLI fallback** (`npx @anthropic-ai/claude-code`) — терминалаас ажиллахыг шалгасан
- [ ] **claude.ai веб login** — browser bookmark, ам нэвтэрсэн (нөөц)
- [ ] **chat.openai.com fallback** — нэвтэрсэн (хоёр дахь нөөц)
- [ ] `reference/lab-NN.pdf`, `reference/2024_round2/`, `reference/2025_round2/` нь offline backup-аар бэлэн
- [ ] AI prompt template (`reference/prompts.md`) уншиж сэргээсэн

## Don'ts

- **Live PSK / production credential** энэ repo-д commit хийхгүй — origin public. `untitled.key` болон `sonfig extracted.*`-г үзэхэд урьдчилан scrub.
- `.vbs` script-ийг өөрчлөхгүй — `BACKUP_DIR` нь `%OLYMP_BACKUP_DIR%` (хэрэв тавьсан бол) → `%USERPROFILE%\OlympBackup\` (default) зам шийдвэрлэдэг. Олимпиадын машин өөр зам шаардвал env var-аар л дарж бич.
- `OlympBackup/`-д үлдсэн May-7/8 test файлуудыг устгахгүй — реал run-ийн жишээ.
- `Global.ini` / `SCRTMenuToolbarV3.ini`-ийг **SecureCRT нээлттэй үед** засахгүй — нэрээ дарж бичнэ.

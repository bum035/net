# Олимпиадын battle station VM — Тохиргооны тайлан

**Тайлан үүсгэсэн өдөр:** 2026-05-08 (II шатны өмнөх өдөр)
**Зорилго:** 2026-05-09 XIV Компьютерын Сүлжээний Олимпиад II шат — оюутан ангилалд lab PC-аас browser/SSH-аар хүрдэг remote dev workstation
**Status:** Автомат setup ✅ дуусаж, interactive алхмууд (Claude OAuth, MCP API key, repo clone) хүлээгдэж байна

> ⚠️ **АНХААРУУЛГА:** Энэ файлд VM-ийн нэвтрэх password-ууд агуулагдсан. Хэрэв `net/` repo-г public GitHub-руу push хийх бол энэ файлыг `.gitignore`-руу нэмэх эсвэл credential хэсгийг устгах. (`net/.gitignore`-руу `vm-setup/REPORT.md` мөр нэмэх санал болгоно.)

---

## 1. Архитектур

```
┌─ Lab PC (олимпиадын өдөр) ──────────────────────────┐
│  • Browser  →  https://code.egulcloud.com   (VS Code) │
│  • Browser  →  https://vnc.egulcloud.com    (VNC web) │
│  • SecureCRT (local, net repo configs)                │
│  • EVE-NG WebUI tab                                   │
└──────────────┬────────────────────┬───────────────────┘
               │ school internal    │ public IP
               │ 10.2.0.100         │ 202.70.34.15
               ▼                    ▼
┌─ olymp-station VM (Ubuntu 22.04 LTS) ──────────────────┐
│  Hostname: ubuntu / 8 vCPU / 15 GiB RAM / 155 GB disk  │
│                                                        │
│  Caddy :80 :443 (Let's Encrypt auto-renew)             │
│   ├─ code.egulcloud.com  →  127.0.0.1:8080  code-server│
│   └─ vnc.egulcloud.com   →  127.0.0.1:6901  KasmVNC    │
│                                                        │
│  XFCE desktop (Firefox + xfce4 inside KasmVNC)         │
│  Claude Code 2.1.133 + npx-ready MCP servers           │
│  Python: netmiko, ciscoconfparse2, paramiko, ttp, napalm│
│  ~/olymp-day workspace (5 lab folders + CLAUDE.md)     │
└────────────────────────────────────────────────────────┘
```

---

## 2. Infrastructure baseline

### VM
| Зүйл | Утга |
|---|---|
| Hostname | `ubuntu` (өөрчлөөгүй — хэрэглэгчийн хүсэлтээр) |
| OS | Ubuntu 22.04.5 LTS (jammy), kernel 5.15.0-177 |
| CPU / RAM / Disk | 8 vCPU / 15 GiB / 155 GB (used 2.4G) |
| Cloud | egulcloud (OpenStack, security group `olympiad-sg`) |
| Internal IP | `10.2.0.100` (WG + сургуулийн дотоод сүлжээ) |
| Public IP | `202.70.34.15` |

### DNS records (Cloudflare DNS-only, no proxy)
| Record | Type | Target |
|---|---|---|
| `code.egulcloud.com` | A | 202.70.34.15 |
| `vnc.egulcloud.com` | A | 202.70.34.15 |

### Cloud security group `olympiad-sg`
| Direction | Protocol | Port | Source |
|---|---|---|---|
| Ingress | TCP | 22 | 0.0.0.0/0 (SSH) |
| Ingress | TCP | 80 | 0.0.0.0/0 (HTTP, Caddy) |
| Ingress | TCP | 443 | 0.0.0.0/0 (HTTPS, Caddy) |
| Ingress | UDP | 51820 | 0.0.0.0/0 (WireGuard) |
| Ingress | UDP | 60000–61000 | 0.0.0.0/0 (өмнөх ажиллаж байсан) |
| Egress | Any | Any | 0.0.0.0/0 + ::/0 |

### SSH access
```powershell
# Local machine (Windows PowerShell)
ssh -i .\id_ed25519 ubuntu@vnc.egulcloud.com
# Эсвэл internal IP-ээр (lab PC сургуульд):
ssh -i .\id_ed25519 ubuntu@10.2.0.100
```

Private key: `D:\vs_code_zenbook\network_olymp\id_ed25519`
Public key: VM `~/.ssh/authorized_keys`-д аль хэдийн орсон.

---

## 3. Component-уудын тойм

| # | Component | Version | Bind | Status |
|---|---|---|---|---|
| 1 | Caddy (HTTPS reverse proxy) | 2.11.2 | `*:80, *:443` | ✅ active, enabled |
| 2 | code-server (browser VS Code) | 4.118.0 | `127.0.0.1:8080` | ✅ active, enabled |
| 3 | KasmVNC (browser VNC) | 1.3.3 | `127.0.0.1:6901` | ✅ active, enabled |
| 4 | XFCE desktop session | 4.16 | display `:1` | ✅ launched by KasmVNC |
| 5 | Claude Code | 2.1.133 | CLI | ⚠ суусан, OAuth login хүлээж байна |
| 6 | exa-mcp-server | latest npm | npx | ⚠ суусан, `claude mcp add` хүлээж байна |
| 7 | mcp-server-sequential-thinking | latest npm | npx | ⚠ суусан, `claude mcp add` хүлээж байна |
| 8 | Node.js | v24.15.0 | — | ✅ |
| 9 | Python network libs | netmiko 5.0.0 + ciscoconfparse2/paramiko/ttp/napalm | — | ✅ |
| 10 | UFW firewall | active | 22/80/443 + WG | ✅ enabled |
| 11 | fail2ban | 0.11.2-6 | SSH protection | ✅ active, enabled |
| 12 | gh (GitHub CLI) | 2.92.0 | — | ✅, `gh auth login` хүлээж байна |
| 13 | tmux | 3.2a | — | ✅ + `~/start-olymp-session.sh` |
| 14 | TLS certificates | Let's Encrypt | code+vnc.egulcloud.com | ✅ obtained |
| 15 | SSH password auth (backup) | OpenSSH default | port 22 | ✅ enabled (60-cloudimg-settings.conf overridden) |
| 16 | Google Chrome (deb) | 148 | — | ✅ |
| 17 | Firefox (Mozilla PPA, deb) | 150 | — | ✅ no snap |
| 18 | Wireshark + tshark + tcpdump | 3.6.2 | — | ✅ ubuntu in wireshark group (non-root capture) |
| 19 | Evince (PDF viewer) | — | — | ✅ |
| 20 | LibreOffice (calc/writer/impress) | 7.3.7 | — | ✅ |
| 21 | meld (visual diff) | — | — | ✅ |
| 22 | PuTTY (familiar SSH GUI) | — | — | ✅ |
| 23 | mosh (mobile shell) | 1.3.2 | UDP 60000-61000 | ✅ (port аль хэдийн нээгдсэн) |
| 24 | iperf3, net-tools, hping3 | — | — | ✅ |

---

## 4. Phase-by-phase implementation

### Phase 1 — System base ✅
- `apt update && apt upgrade` (security patches included)
- Essentials: tmux, git, curl, vim, htop, ncdu, tree, jq, unzip, rsync, ipcalc, netcat, dnsutils, nmap, traceroute, mtr-tiny
- UFW: 22/80/443 + WG-аар нээгдсэн
- fail2ban: enabled (SSH brute-force protection)
- Timezone: `Asia/Ulaanbaatar` (+08)

### Phase 2 — Caddy + HTTPS ✅
- Caddy 2.11.2 from official Cloudsmith repo
- `/etc/caddy/Caddyfile` deployed (см. §6)
- ACME registration with `bumabuma035@gmail.com`
- Let's Encrypt cert obtained for both domains via TLS-ALPN-01 challenge
- Auto-renew configured (Caddy default: ~30 days before expiry)

### Phase 3 — code-server ✅
- v4.118.0 via official install.sh
- `~/.config/code-server/config.yaml`: bind 127.0.0.1:8080, password auth
- systemd service: `code-server@ubuntu` (system-level template, runs as user)
- HTTPS verified: `https://code.egulcloud.com` → 302 redirect to login

### Phase 4 — XFCE + KasmVNC ✅ (2 урт debugging session)

**Бэрхшээлүүд + шийдэл:**
1. ❌ Firefox install (snap transitional package) → ✅ Skip — манайд KasmVNC-аар browser нээгдэнэ
2. ❌ `kasmvncpasswd` interactive prompt → expect ажиллаагүй → ✅ `echo -e "pw\npw\n" | kasmvncpasswd -u ubuntu -wo` (документад заасан pipe method)
3. ❌ kasmvncserver "Please choose Desktop Environment" prompt → ✅ `/usr/lib/kasmvncserver/select-de.sh --select-de xfce -y` running once + creating `~/.vnc/.de-was-selected` marker
4. ❌ kasmvnc.yaml-ийн unsupported keys (`server_to_client` дотор `enabled` field алгассан, `encoding.jpeg_quality` нь буруу path) → ✅ `/usr/share/kasmvnc/kasmvnc_defaults.yaml`-аас зөв schema идэвхтэй; rewritten config (см. §6)
5. ❌ systemd unit `Type=forking` + `PAMName=login` → status=255 → ✅ `Type=forking` (PAMName хасав), TimeoutStartSec=60
6. ❌ Stale `/tmp/.X1-lock` after manual run → ✅ `rm -f /tmp/.X1-lock /tmp/.X11-unix/X1` cleanup сэргээсэн

**Эцсийн status:** Xvnc :1 with XFCE session, ports 6901 (websocket) + 5901 (raw VNC) listening on 127.0.0.1, clipboard server↔client enabled, 1920x1080 / 24-bit / 60 fps.

### Phase 5 — Node.js + Claude Code ✅
- Node.js v24.15.0 (NodeSource LTS deb)
- `~/.npm-global/` prefix configured (sudo-free global installs for `ubuntu`)
- `@anthropic-ai/claude-code` 2.1.133 → `~/.npm-global/bin/claude`
- MCP packages installed:
  - `exa-mcp-server` (web search, EXA_API_KEY required)
  - `@modelcontextprotocol/server-sequential-thinking` (multi-step reasoning)
  - `pnpm`, `ts-node`, `typescript` нэмэлт хэрэгтэй
- ⚠ `@modelcontextprotocol/server-fetch` package олдсонгүй — Claude Code-ийн built-in WebFetch tool аль хэдийн дэмждэг тул шаардлагагүй

### Phase 6 — Tmux + Cisco/network tools ✅
- `~/.tmux.conf` deployed (mouse, prefix, status bar, history 100k)
- Python libs (`pip3 install --user`):
  - netmiko 5.0.0 — SSH connection automation
  - ciscoconfparse2 — config parsing/diff
  - paramiko — SSH primitives
  - ttp — template-based parsing
  - napalm — multi-vendor config management
  - pyshark, rich, bcrypt, jinja2
- CLI: ripgrep, fd-find, bat, yq (binary), jq
- `~/start-olymp-session.sh` — tmux bootstrap (claude / shell / monitor windows)
- `~/olymp-day/` workspace + `CLAUDE.md` exam context
  - `lab-01-ospf/` ... `lab-05-libre/` empty folders
  - `scratch/` for ad-hoc work

### Phase 7 — Final wiring ✅
- gh (GitHub CLI) 2.92.0 — `gh auth login` шаардлагатай
- git config: `user.email=bumabuma035@gmail.com`, `init.defaultBranch=main`
- ⚠ Repo clone interactive (auth шаардлагатай) — §10 хар

### Phase 8 — SSH password auth ✅ (backup access)
- `ubuntu` user-д system password тохируулсан (`chpasswd`)
- `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf`-ийн `PasswordAuthentication no` → `yes`
- `sshd -T` баталгаажуулсан: `passwordauthentication yes`
- fail2ban нь brute force-оос хамгаална

### Phase 9 — Password unification ✅
- Бүх 4 хүрэх замд `ubuntu` / `Bumbayar_8084`
- SSH: `chpasswd`
- code-server: sed-аар config.yaml шинэчлэх + service restart
- KasmVNC: `kasmvncpasswd -u ubuntu -wo` (pipe) + service restart
- Plain text backup `~/.ssh-password.txt`, `~/.vnc/password.txt` (chmod 600)

### Phase 10 — GUI apps + CLI tools ✅
- **Browsers**: Google Chrome 148 (deb), Firefox 150 (Mozilla PPA, snap-аас зайлсхийсэн)
- **Network analysis**: Wireshark 3.6.2 + tshark + tcpdump (ubuntu user wireshark group-д, non-root capture)
- **Cisco/console**: PuTTY (Windows-ын familiar GUI), socat, hping3, arp-scan
- **Office**: LibreOffice 7.3.7 (calc, writer, impress) — xlsx/pptx/docx, hunspell-en-us
- **PDF**: evince + poppler-utils
- **Diff/merge**: meld (visual), colordiff
- **Networking**: iperf3, net-tools, lsof, mtr, traceroute, mosh
- **CLI productivity**: fzf, tldr, ranger, ncdu, neovim, zsh, btop
- **Image/screenshot**: feh, eog, gimp, xfce4-screenshooter, flameshot
- **Archive**: 7z (p7zip-full + rar), unrar
- **Diagrams**: graphviz, xdot
- **Git**: gitg (GUI), tig (TUI)
- **Other**: xmlstarlet, csvkit, mosh
- Disk total used: ~12G / 155G (8% — уйтгартай)

---

## 5. Credentials & access

> ⚠ **НУУЦ — Public-руу commit хийхгүй.**

### Нэгдсэн нэвтрэх мэдээлэл (бүх хэрэгсэлд адил)

```
═══════════════════════════════════════════════════
  Username: ubuntu
  Password: Bumbayar_8084
═══════════════════════════════════════════════════
```

### Хүрэх 4 зам

| # | Зам | URL / Команд | Auth | Тохиргооны зам |
|---|---|---|---|---|
| 1 | Browser code-server | https://code.egulcloud.com | password | VM:~/.config/code-server/config.yaml |
| 2 | Browser KasmVNC | https://vnc.egulcloud.com | ubuntu / password | VM:~/.kasmpasswd (bcrypt) |
| 3 | SSH key | `ssh -i ./id_ed25519 ubuntu@vnc.egulcloud.com` | private key | D:\vs_code_zenbook\network_olymp\id_ed25519 |
| 4 | SSH password (backup) | `ssh ubuntu@vnc.egulcloud.com` | password | /etc/ssh/sshd_config.d/60-cloudimg-settings.conf (PasswordAuthentication yes) |

**Internal IP path (lab сургуулийн доторх):** `10.2.0.100` — public-ынхтэй адил browser/SSH.

### VM дээр хадгалагдсан password файлууд (chmod 600)

```
~/.ssh-password.txt              # plain SSH password backup
~/.config/code-server/config.yaml # contains password: ...
~/.vnc/password.txt              # plain KasmVNC password backup
~/.kasmpasswd                    # bcrypt hash, KasmVNC main store
```

### Brute-force protection
- **fail2ban** SSH: 5 fail / 10 min → 10 min ban
- **KasmVNC** built-in: blacklist_threshold 5, blacklist_timeout 10 min

### Хадгалалт лабын өдрөөс өмнө
- USB stick (хэрэв зөвшөөрөл бол): `id_ed25519` private key
- **Цээжлэх (нэг password бүгдэд):**
  - User: `ubuntu`
  - Password: `Bumbayar_8084`
- Цаасан дээр (минимум):
  - Public IP `202.70.34.15`
  - Browser URL: `code.egulcloud.com` / `vnc.egulcloud.com`
- Browser bookmark: `https://code.egulcloud.com`, `https://vnc.egulcloud.com`

---

## 6. Configurations (одоогийн төлөв)

### Caddyfile — `/etc/caddy/Caddyfile`
```caddyfile
{
    email bumabuma035@gmail.com
}

(common) {
    encode gzip zstd
    header {
        Strict-Transport-Security "max-age=31536000;"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}

code.egulcloud.com {
    import common
    reverse_proxy 127.0.0.1:8080 {
        header_up X-Real-IP {remote_host}
    }
}

vnc.egulcloud.com {
    import common
    reverse_proxy 127.0.0.1:6901 {
        header_up X-Real-IP {remote_host}
    }
}
```

### code-server — `~/.config/code-server/config.yaml`
```yaml
bind-addr: 127.0.0.1:8080
auth: password
password: Bumbayar_8084
cert: false
```

### KasmVNC — `~/.vnc/kasmvnc.yaml`
```yaml
network:
  protocol: http
  interface: 127.0.0.1
  websocket_port: 6901
  use_ipv4: true
  use_ipv6: false
  ssl:
    require_ssl: false

desktop:
  resolution: { width: 1920, height: 1080 }
  allow_resize: true
  pixel_depth: 24

runtime_configuration:
  allow_client_to_override_kasm_server_settings: true
  allow_override_standard_vnc_server_settings: true

data_loss_prevention:
  clipboard:
    server_to_client: { enabled: true }
    client_to_server: { enabled: true }

encoding: { max_frame_rate: 60 }
logging: { log_writer_name: all, log_dest: logfile, level: 30 }
```

### KasmVNC xstartup — `~/.vnc/xstartup` (auto-written by select-de.sh)
```sh
#!/bin/sh
set -x
exec xfce4-session
```

### KasmVNC systemd — `/etc/systemd/system/kasmvnc.service`
```ini
[Unit]
Description=KasmVNC Server (XFCE for ubuntu)
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu
Environment=HOME=/home/ubuntu
Environment=USER=ubuntu
Environment=LANG=en_US.UTF-8
ExecStart=/usr/bin/kasmvncserver :1 -depth 24 -geometry 1920x1080
ExecStop=/usr/bin/kasmvncserver -kill :1
Restart=on-failure
RestartSec=5
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
```

### tmux — `~/.tmux.conf`
```tmux
set -g mouse on
set -g history-limit 100000
set -g default-terminal "screen-256color"
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind r source-file ~/.tmux.conf \; display "Reloaded ~/.tmux.conf"

bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

set -g status-style "bg=colour234 fg=colour137"
set -g status-left "#[fg=colour226,bold] olymp-station #[default]"
set -g status-right "#[fg=colour39] %Y-%m-%d %H:%M "
```

### Olympic workspace — `~/olymp-day/CLAUDE.md`
```markdown
# Олимпиадын ажлын орчин (2026-05-09)

Та сүлжээний олимпиадад тусалдаг туслах. Бэлэн байх:
- Cisco IOS, IOS-XE, IOS-XR, NX-OS config-уудыг ойлгох
- BGP, OSPF, vPC, GRE+IPSec, SNMP, LibreNMS troubleshooting
- Output товч — config block + 1-2 өгүүлбэрийн тайлбар

## Лабын folder-ууд
- lab-01-ospf/ — OSPF Multi-area + VRF FinDep + Redistribution (17%)
- lab-02-bgp/  — BGP Full Stack: iBGP RR + eBGP + TE (20%)
- lab-03-vpc/  — NX-OS vPC + MCLAG (10%)
- lab-04-vpn/  — GRE + IPSec VPN IKEv2 (9%)
- lab-05-libre/— LibreNMS + SNMPv2 + Pre-broken Troubleshoot (45%)
```

---

## 7. Setup script archive (local repo)

Бүх setup scripts `D:\vs_code_zenbook\network_olymp\net\vm-setup\` дотор хадгалагдсан. VM-ыг хожим rebuild хийхэд бэлэн.

| File | Purpose |
|---|---|
| `01-base.sh` | apt update/upgrade, essentials, UFW, fail2ban, timezone |
| `02-caddy.sh` | Caddy install + Caddyfile deploy |
| `03-codeserver.sh` | code-server install + random password + service |
| `04-vnc.sh` | XFCE + KasmVNC install (apt + GitHub deb), expect-based config |
| `04b-vnc-finish.sh` | VNC password set + systemd unit (legacy expect) |
| `04c-vnc-password.sh` | Password set via pipe (working method) |
| `04d-vnc-start.sh` | Restart with corrected config + manual validate |
| `05-nodejs-claude.sh` | Node.js LTS + Claude Code + initial MCP attempt |
| `05b-mcp.sh` | MCP package install (sequential-thinking + exa) |
| `06-tools.sh` | tmux config, Python libs, ripgrep/fd-find/bat, ~/olymp-day workspace |
| `07-repos.sh` | gh CLI install + clone instructions |
| `08-finalize.sh` | PATH cleanup + preflight verify |
| `09-ssh-password.sh` | SSH password auth enable + ubuntu user password set |
| `10-unify-passwords.sh` | Бүх password-ыг `Bumbayar_8084`-руу нэгтгэх (SSH + code-server + KasmVNC) |
| `11-tools-and-browser.sh` | GUI apps (Chrome, Firefox, Wireshark, LibreOffice, evince, meld, PuTTY) + extra CLI tools |
| `Caddyfile` | §6 |
| `kasmvnc.yaml` | §6 |
| `tmux.conf` | §6 |
| `xstartup` | §6 (KasmVNC overwrote with select-de.sh result) |
| `code-server-config.yaml` | template (real password set in script) |
| `kasmvnc.service` | §6 |
| `REPORT.md` | this document |

VM дээр аль хэдийн `~/01-base.sh` ... `~/08-finalize.sh` копилогдсон.

---

## 8. Үлдсэн interactive алхмууд

### 8.1 — Claude OAuth login
```bash
ssh -i ./id_ed25519 ubuntu@vnc.egulcloud.com
claude
# → URL гарна
# → Browser-аас claude.ai login (Max plan account)
# → auth code-ыг буцааж paste
# Token хадгалагдана: ~/.config/claude/credentials.json
```

### 8.2 — MCP servers нэмэх
```bash
# Sequential thinking (no API key)
claude mcp add sequential-thinking --scope user \
  -- npx -y @modelcontextprotocol/server-sequential-thinking

# Exa search — exa.ai-аас free API key (1k searches/month)
export EXA_API_KEY=your_exa_key
claude mcp add exa --scope user --env EXA_API_KEY=$EXA_API_KEY \
  -- npx -y exa-mcp-server

claude mcp list
```

### 8.3 — Repo clone
```bash
gh auth login                    # browser flow
cd ~
git clone https://github.com/<USER>/network_olymp.git
git clone https://github.com/bum035/net.git
ln -sf ~/network_olymp/04_eve_ng_material/labs/topologies ~/olymp-day/reference
```

### 8.4 — code-server-д extension
Browser https://code.egulcloud.com → Extensions:
- `Lakuapik.cisco-ios` (Cisco syntax highlighting)
- `eamodio.gitlens` (git integration)
- `fabiospampinato.vscode-highlight` + paste `~/net/cisco_highlights.jsonc` тохиргоо

---

## 9. Олимпиадын өдрийн workflow

```
┌─ Lab PC ─────────────────────────────────────────────────────┐
│                                                              │
│  Browser tab #1: https://code.egulcloud.com                  │
│    └─ VS Code in browser                                     │
│        ├─ terminal → tmux attach -t olymp                    │
│        │   └─ claude (Max + MCP)                             │
│        └─ explorer: ~/olymp-day/lab-NN-*/                    │
│                                                              │
│  Browser tab #2: EVE-NG WebUI                                │
│    └─ Topology view + telnet handler → SecureCRT             │
│                                                              │
│  Browser tab #3: https://vnc.egulcloud.com (optional)        │
│    └─ XFCE desktop инкл. Firefox (EVE-NG-руу alt path)       │
│                                                              │
│  SecureCRT (local, net repo settings):                       │
│    ├─ Console session-ууд (pod1/R1 ... SW3)                  │
│    ├─ Button Bar: BACKUP → %USERPROFILE%\OlympBackup\        │
│    └─ Button Bar: PUSH → push_config.vbs                     │
│                                                              │
└──────────────────────────────────────────────────────────────┘

Цикл:
1. EVE-NG WebUI → топологи харах, "Connect" → SecureCRT нээгдэнэ
2. SecureCRT → show run → Button Bar BACKUP
3. Backup .cfg-г code-server-д drag/paste → Claude chat:
   "Энэ R1 NX-OS config-д vPC peer-link идэвхгүй байгаа шалтгаан + засвар"
4. Claude хариулт → засварсан config block-ыг clipboard
5. SecureCRT-руу paste эсвэл Button Bar PUSH (push_config.vbs, line-by-line)
6. show vpc / show ip route → verify
```

**AI-аар хийхгүй (өөрөө хийх ёстой):**
- Даалгаврыг анхааралтай уншиж AI-руу зөв тайлбарлах
- Output-ыг өөрөө хянах — AI false config гаргаж магадгүй (deprecated keyword, syntax)
- Шалгуурын хязгаарлалт (open standard, prepend хориглох гм)

---

## 10. Risks & mitigations

| Risk | Probability | Mitigation |
|---|---|---|
| `code.egulcloud.com` DNS resolve хийхгүй (өмнө timeout байсан) | Medium | Public IP `202.70.34.15` шууд browser-руу (cert mismatch warning → Advanced/Proceed). Цаасан дээр IP бичсэн |
| Lab PC firewall HTTPS (443) гаргахгүй | Low | Internal IP path (`https://10.2.0.100` cert mismatch-тэй ч ажиллана). Эсвэл internal HTTP `http://10.2.0.100:8080` (code-server-ийн config-ыг `0.0.0.0:8080`-руу шилжүүлэх ёстой) |
| Claude OAuth token expire (~30 хоног) | Low (өнөөдөр login хийж буй) | Олимпиадын өмнөх өдөр / өглөө дахин шалгах: `claude` → "hello" хариулах ёстой |
| EXA_API_KEY rate limit (1k/month free) | Low | 100-200 search/day хангалттай. Backup: WebFetch built-in tool |
| VM crash / OOM | Low | 15 GiB RAM хангалттай. egulcloud console-аас reboot эрх байгаа эсэхийг шалгах |
| Stale `/tmp/.X1-lock` хэрвээ kasmvnc reset бол | Medium | `~/start-olymp-session.sh`-руу `rm -f /tmp/.X1-lock` нэмэх (одоо байхгүй) |
| USB stick хориотой (id_ed25519 хүрэхгүй) | Low | **Password auth идэвхжсэн** (`Bumbayar_8084`) — `ssh ubuntu@vnc.egulcloud.com` гарын password prompt. fail2ban нь brute force-оос хамгаална |
| Claude Code MCP servers EXPORT-той зөрчилдөнө | Low | Per-user scope-аар тохируулсан тул global-руу нөлөөлөхгүй |

---

## 11. Restore-from-scratch procedure

VM рестарт эсвэл шинэ instance-аас восстановит хийх алхмууд:

1. **VM үүсгэх**: Ubuntu 22.04 LTS, security group `olympiad-sg`-той ижилхэн (22/80/443/51820 + WG), public IP назначен
2. **DNS**: `code.egulcloud.com`, `vnc.egulcloud.com` → шинэ public IP
3. **SSH key copy**:
   ```bash
   ssh-copy-id -i ./id_ed25519.pub ubuntu@<new_ip>
   ```
4. **Setup scripts хуулах + ажиллуулах**:
   ```powershell
   scp -i .\id_ed25519 -r .\net\vm-setup\* ubuntu@<new_ip>:~/
   ssh -i .\id_ed25519 ubuntu@<new_ip> "bash ~/01-base.sh && bash ~/02-caddy.sh && bash ~/03-codeserver.sh && bash ~/04-vnc.sh && bash ~/04c-vnc-password.sh && bash ~/04d-vnc-start.sh && bash ~/05-nodejs-claude.sh && bash ~/05b-mcp.sh && bash ~/06-tools.sh && bash ~/07-repos.sh && bash ~/08-finalize.sh"
   ```
   ⚠ Phase 4 хэсэг асуудлууд гарвал тус тусад нь дэс дараагаар:
   ```bash
   bash ~/04-vnc.sh                # XFCE + KasmVNC install
   /usr/lib/kasmvncserver/select-de.sh --select-de xfce -y
   bash ~/04c-vnc-password.sh
   bash ~/04d-vnc-start.sh
   ```
5. **Interactive хэсгүүд** (§8) — гараар хийх

**Total time:** ~30-45 минут (interactive алхам оруулаад)

---

## 12. References

- Original prep plan: `D:\vs_code_zenbook\network_olymp\docs\superpowers\plans\2026-05-04-round2-prep.md`
- Existing toolkit (SecureCRT, .spsl, button bar): `D:\vs_code_zenbook\network_olymp\net\` (`net/CLAUDE.md`)
- Lab topology PDFs: `D:\vs_code_zenbook\network_olymp\04_eve_ng_material\labs\topologies\lab-NN.pdf`
- 2024 round-2 reference: `D:\vs_code_zenbook\network_olymp\2024_eve-ng_task_doing\`
- Claude memory: `C:\Users\bumab\.claude\projects\D--vs-code-zenbook-network-olymp\memory\project_olymp_vm.md`

---

## 13. Олимпиадын өмнөх final checklist

- [ ] **Claude OAuth login** хийсэн VM дээр (`claude` → "hello")
- [ ] **EXA_API_KEY** авч экспортлосон + `claude mcp add exa`
- [ ] **`claude mcp list`** нь exa, sequential-thinking-ийг харуулна
- [ ] **`network_olymp` repo** clone хийгдсэн `~/network_olymp/`
- [ ] **`net` repo** clone хийгдсэн `~/net/`
- [ ] **Browser bookmark** lab PC-д бэлдэх (хэрэв боломжтой бол): code.egulcloud.com, vnc.egulcloud.com, eve-ng.school.local
- [ ] **USB stick** дээр id_ed25519 (USB зөвшөөрөгдөх эсэхийг лабын админаас асуух)
- [ ] **Password цээжилсэн / цаасан**: `ubuntu` / `Bumbayar_8084` (бүх 4 хэрэгсэлд адил)
- [ ] **Mobile hotspot test**: VM-руу WG-гүйгээр (тэр чигт public IP-ээр) хүрсэн
- [ ] **Internal IP test**: lab PC-аас `http://10.2.0.100:8080` болон `https://code.egulcloud.com` 2 өрөмтгий
- [ ] **Pre-flight tmux session** үүсгэсэн VM дээр: `tmux new -s olymp` болон Claude асуумжын test
- [ ] **`net/CLAUDE.md` workflow** гүйцээгээгүй item-ыг батлах (SecureCRT junction, button bar, .spsl)

---

**Тайлан үүсгэгч:** Claude (Opus 4.7)
**Сүүлд шинэчилсэн:** 2026-05-08 17:33 UTC+8
**Файлын зам:** `D:\vs_code_zenbook\network_olymp\net\vm-setup\REPORT.md`

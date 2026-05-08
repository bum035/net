# VM Pending — interactive алхмууд

> Энэ файл нь `vm-setup/REPORT.md`-аас гадуурх **manual / interactive** алхмууд. Олимпиадын өдрийн өмнө дуусгах ёстой.

**Status (2026-05-09):**
- ✅ sequential-thinking MCP — registered + Connected
- ✅ exa-search MCP — registered + Connected (EXA_API_KEY stored in `~/.claude.json`)
- ⏳ gh CLI auth — interactive OAuth required
- ✅ Repo clone — `/home/ubuntu/net/` already cloned (we're in it)

## 1. exa-mcp-server (web search MCP) ✅ ХИЙГДСЭН

API key `~/.claude.json`-д хадгалагдсан (`projects → /home/ubuntu/net → mcpServers → exa-search → env → EXA_API_KEY`).

```bash
# Шинэ machine дээр reinstall хийх бол:
claude mcp add exa-search -e EXA_API_KEY="<key>" -- npx -y exa-mcp-server

# Verify
claude mcp list | grep exa-search    # ✓ Connected
```

⚠ **`~/.claude.json` нь EXA API key-ийг plain text-ээр агуулна.** Repo-руу commit хийхгүй (системийн config бөгөөд гадуур).

## 2. gh CLI auth

```bash
gh auth login
# → GitHub.com
# → HTTPS
# → Y (Authenticate Git)
# → Login with a web browser
# → device code-ыг copy → browser-аас https://github.com/login/device
gh auth status      # OK болсон эсэх
```

Олимпиадын дунд PR хийх юмгүй тул заавал биш. Repo-ыг pull хийхэд token хэрэггүй (public repo).

## 3. Олимпиадын өмнөх 30 минутад дуусгах

- [ ] `bash ~/net/scripts/preflight.sh` — FAIL=0
- [ ] Reference материал хуулах (Windows zenbook → `~/net/reference/`)
- [ ] `python3 ~/net/scripts/olymp-run.py --mode setup` — olymp.conf үүсгэх
- [ ] `python3 ~/net/scripts/olymp-run.py --mode diagnose` — EVE-NG reach OK
- [ ] `python3 ~/net/scripts/olymp-run.py --mode scrt --deploy` — SecureCRT session-уудыг lab-руу зориулсан гене
- [ ] `bash ~/net/scripts/auto-backup.sh 600 --once` — 1 удаа run, OK гаргах
- [ ] tmux session bootstrap: `bash ~/net/scripts/start-olymp-session.sh`

## 4. Олимпиадын дараа cleanup

- [ ] `vm-setup/REPORT.md`-аас password block remove (хэрэв repo public хэвээр)
- [ ] `OlympBackup/` — олимпиадын өдрийн config-уудыг archive болгож хэлэх
- [ ] Auto-backup loop stop (`Ctrl+C` tmux pane)
- [ ] `olymp-day/lab-*/backup-*/` — final config дээр шалгуур үнэлгээний хариу

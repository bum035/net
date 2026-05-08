# Олимпиадын өдрийн Failover Plan

> Хэрэв ийм юм болвол → эний оронд тэнийг хэрэглэ. **Пайн хийх биш — Plan B-г сансан.**

## 0. Эхэлж preflight

```bash
bash ~/net/scripts/preflight.sh
```

PASS=N, WARN=N, FAIL=0 байх ёстой. FAIL гарвал доорх scenario-ноос аль нь юм олж шийдэх.

---

## 1. Internet тасрав

**Шинж тэмдэг:** `ping 8.8.8.8` fail, claude.ai-руу browser хүрэхгүй.

**Шийдэл:**
1. **AI offline mode:** `reference/cheatsheet/` дотор OSPF/BGP/vPC/IPSec одноо-pager бэлэн (хэрэв бэлдсэн бол)
2. **Reference configs:** `reference/2024_round2/`, `2025_round2/` — өмнөх жилийн жишээ
3. **Local LLM байхгүй** — урьдчилан гэртээ суулгах боломжгүй (олимпиадын дүрмээр зөвшөөрөгдсөн ч практикт лаб PC-д байх боломж бага)
4. **Cisco docs offline** — байхгүй. Зөвхөн санах ой + reference/

**Урьдчилан сэргийлэх:** Reference материалуудыг олимпиадын өмнөх 30 минутад заавал хуулах. Скриптүүдийг тест:
```bash
ls -la ~/net/reference/cheatsheet/  # хоосон бол интернет тасарвал бэрхэлд орно
```

---

## 2. claude.ai login expire / Anthropic OAuth amжилтгүй

**Шинж тэмдэг:** `claude` CLI run-да "session expired", web-ээр login-руу redirect.

**Шийдэл (priority дарааллаар):**
1. **VS Code Claude Code extension** (`Anthropic.claude-code`) — өөр session, заримдаа CLI down ч ажилладаг
2. **claude.ai веб шууд** — Browser Preview tab эсвэл Firefox/Chrome
3. **chat.openai.com** — backup AI provider
4. **Google Gemini** (gemini.google.com) — Google account-аар нэвтрэх

**Урьдчилан:** олимпиадын өмнөх өдөр **бүх 4 service-д login** хийнэ. Browser bookmark.

---

## 3. EVE-NG host олдохгүй

**Шинж тэмдэг:** preflight EVE TCP fail. olymp-run.py "connection refused".

**Шийдэл:**
1. **IP солигдсон:** диагнос script:
   ```bash
   python3 ~/net/scripts/diagnose-eve.py --host <new-ip>
   ```
   Хэрэв OK бол `olymp-run.py --reconfigure`-аар conf шинэчил.
2. **EVE down** — лабын админд хэлээд reset хүс. Олимпиадын ажилтан үүрэгтэй.
3. **Network LAN тасарсан** — `ip route`, `ip addr` шалгах. DHCP renew (`sudo dhclient -r && sudo dhclient`).

---

## 4. SecureCRT эвдэрсэн / config алга

**Шинж тэмдэг:** SecureCRT нээгдэхгүй, эсвэл Sessions tree хоосон.

**Шийдэл:**
1. **Symlink эвдэрсэн** — preflight WARN/FAIL гарна. Засах:
   ```bash
   cd ~/.vandyke/SecureCRT/Config
   ln -sfn ~/net/secureCRT/VanDyke/Config/Sessions Sessions
   ```
2. **Лиценз expired** — backup license олж тавих. (eval mode-руу шилжихэд cap=30 минут).
3. **SecureCRT хаасан state** — `pkill SecureCRT && SecureCRT &`

**Backup tool — netmiko terminal-аас:**
```bash
~/net/scripts/eve_telnet.sh 32769          # эсвэл R1 нэрээр
~/net/scripts/netmiko_backup.py inv.yml --slow
```

---

## 5. VM (egulcloud.com) хүрэхгүй

**Шинж тэмдэг:** browser code.egulcloud.com / vnc.egulcloud.com 502 / timeout.

**Шийдэл:**
1. **Local лаб PC дээрх toolkit өөрөө бүрэн ажиллана** — VM зөвхөн "second brain". Repo, scripts, SecureCRT бүгд local.
2. **SSH backup:** `ssh ubuntu@vnc.egulcloud.com` → restart Caddy / KasmVNC / code-server:
   ```bash
   sudo systemctl restart caddy code-server@ubuntu kasmvnc
   ```
3. **Public IP IP бэлэн:** `202.70.34.15` — DNS resolve fail-вэл шууд hosts entry:
   ```
   202.70.34.15 code.egulcloud.com vnc.egulcloud.com
   ```
4. **VM completely down** — заавалd шаардлагагүй. Local Claude Code CLI + claude.ai веб ажиллана.

**Дүгнэлт:** **VM нь optional convenience.** Олимпиад үндсэн рутиныг local SecureCRT + Claude Code-аар хийх зориулалттай.

---

## 6. Олимпиадын дунд "одоо би юу хийх вэ"

```bash
# Алхам 1 — preflight (10 секунд)
bash ~/net/scripts/preflight.sh --quiet

# Алхам 2 — баталгаа (10 секунд)
python3 ~/net/scripts/olymp-run.py --mode diagnose

# Алхам 3 — backup loop эхлүүлнэ (background tmux pane-д)
tmux new-window -n backup 'bash ~/net/scripts/auto-backup.sh 600'

# Алхам 4 — олимпиадын лабын task PDF-ийг олж тавь
ls ~/net/reference/lab-*.pdf
```

---

## 7. Эцсийн ажиллагаатай config-ыг алдсан

**Шинж тэмдэг:** буруу `push` хийсэн, R1 reload, бүгд устгасан.

**Шийдэл:**
```bash
# Сүүлчийн backup-аас бүгдийг буцаах
python3 ~/net/scripts/olymp-run.py --mode push-all --yes

# Тодорхой нэг device буцаах
python3 ~/net/scripts/olymp-run.py --mode push \
    --push-cfg olymp-day/lab-XX/backup-2026-05-09_HH-MM/R1_*.cfg

# auto-backup ажиллаж байсан бол ~10 минутын өмнөх state хадгалагдсан
ls ~/net/olymp-day/lab-*/backup-*/
```

`auto-backup.sh` (10 мин interval) ажиллаж байсан бол энэ scenario бараг шийдэгдсэн — сүүлчийн ажил саянд хадгалагдсан.

---

## Туршихад зориулсан жагсаалт (өнөөдөр / yдэш)

- [ ] `bash ~/net/scripts/preflight.sh` — FAIL=0
- [ ] `claude --version` — installed, login OK
- [ ] `claude mcp list` — context7, playwright, sequential-thinking бүгд Connected
- [ ] claude.ai веб login (backup)
- [ ] chat.openai.com login (backup)
- [ ] `~/net/scripts/auto-backup.sh 60 --once` — 1 удаа run, OK гарах
- [ ] `ls ~/net/reference/lab-*.pdf` — лабын даалгавар бэлэн (өнөөдрийн өглөө хуулах)
- [ ] `xdg-open telnet://127.0.0.1:32769` — SecureCRT нээгдэх
- [ ] olymp.conf анхны run хийсэн (`python3 ~/net/scripts/olymp-run.py --mode setup`)

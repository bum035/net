#!/usr/bin/env bash
# preflight.sh — олимпиадын өдрийн нэг командт smoke-test
#
# Шалгана:
#   - SecureCRT symlink эрүүл (Sessions, ButtonBar, Commands, Keywords, Scripts)
#   - SecureCRT лиценз жинхэнэ файл (symlink биш)
#   - OlympBackup folder write permission
#   - Telnet handler → securecrt-telnet.desktop (Linux)
#   - Internet + GitHub reachable
#   - Claude CLI installed + login state
#   - python3 + netmiko + pyyaml import
#   - graphviz dot binary
#   - olymp-run.py --help, diagnose-eve.py --help
#   - olymp.conf байгаа эсэх (анхны run шаардлагатай юу)
#   - reference/ материал бэлэн эсэх
#   - EVE-NG TCP reach (хэрэв olymp.conf-аас host олдвол)
#
# Хэрэглэх:
#   bash ~/net/scripts/preflight.sh
#   bash ~/net/scripts/preflight.sh --quiet      # зөвхөн FAIL мөрийг харуулна
#   bash ~/net/scripts/preflight.sh --eve-host 10.2.0.163  # EVE host force
#
# Exit code: pass=0, ямар нэгэн FAIL=1, зөвхөн WARN=0

set -u
QUIET=0
EVE_HOST_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    --eve-host) EVE_HOST_OVERRIDE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

PASS=0
FAIL=0
WARN=0
RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; CYAN=$'\e[36m'; RESET=$'\e[0m'

ok()   { PASS=$((PASS+1));   [[ $QUIET -eq 0 ]] && printf '%b[ OK ]%b %s\n'   "$GREEN" "$RESET" "$1"; }
fail() { FAIL=$((FAIL+1));   printf '%b[FAIL]%b %s\n'                          "$RED"   "$RESET" "$1"; }
warn() { WARN=$((WARN+1));   [[ $QUIET -eq 0 ]] && printf '%b[WARN]%b %s\n'   "$YELLOW" "$RESET" "$1"; }
section() { [[ $QUIET -eq 0 ]] && printf '\n%b== %s ==%b\n' "$CYAN" "$1" "$RESET"; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ------------------------------------------------------------- SecureCRT
section "SecureCRT config"
SCRT_CONF="$HOME/.vandyke/SecureCRT/Config"
if [[ -d "$SCRT_CONF" ]]; then
  ok "SecureCRT config dir: $SCRT_CONF"
  for sub in Sessions Commands Keywords Scripts; do
    if [[ -L "$SCRT_CONF/$sub" ]]; then
      target="$(readlink -f "$SCRT_CONF/$sub")"
      if [[ "$target" == "$REPO/secureCRT/VanDyke/Config/$sub" ]]; then
        ok "symlink $sub -> repo"
      else
        warn "symlink $sub -> $target (репог зааж байгаа эсэхийг шалга)"
      fi
    elif [[ -d "$SCRT_CONF/$sub" ]]; then
      warn "$sub нь жинхэнэ folder (symlink биш) — repo шинэчлэлт автоматаар орохгүй"
    else
      fail "$sub байхгүй ($SCRT_CONF/$sub)"
    fi
  done
  for f in Global.ini ButtonBarV5.ini SCRTMenuToolbarV3.ini; do
    if [[ -L "$SCRT_CONF/$f" ]]; then
      ok "symlink $f -> repo"
    elif [[ -f "$SCRT_CONF/$f" ]]; then
      warn "$f нь жинхэнэ файл — repo-г follow хийхгүй"
    else
      fail "$f байхгүй"
    fi
  done
  if [[ -f "$SCRT_CONF/SecureCRT_eval.lic" ]]; then
    if [[ -L "$SCRT_CONF/SecureCRT_eval.lic" ]]; then
      fail "license symlink болсон байна — жинхэнэ файл байх ёстой"
    else
      ok "лиценз жинхэнэ файл"
    fi
  else
    warn "SecureCRT_eval.lic олдсонгүй (eval mode эсвэл лиценз тохируулагдаагүй)"
  fi
else
  warn "SecureCRT суугаагүй эсвэл Config үүсгээгүй ($SCRT_CONF)"
fi

# ------------------------------------------------------------- OlympBackup
section "OlympBackup folder"
BKDIR="${OLYMP_BACKUP_DIR:-$HOME/OlympBackup}"
if [[ -d "$BKDIR" ]]; then
  if touch "$BKDIR/.preflight_test" 2>/dev/null; then
    rm -f "$BKDIR/.preflight_test"
    ok "$BKDIR write OK"
  else
    fail "$BKDIR write permission байхгүй"
  fi
else
  warn "$BKDIR байхгүй — mkdir хийх хэрэгтэй (mkdir -p $BKDIR)"
fi

# ------------------------------------------------------------- Telnet handler (Linux)
if [[ "$(uname)" == "Linux" ]]; then
  section "Telnet handler (xdg-mime)"
  if command -v xdg-mime >/dev/null 2>&1; then
    handler="$(xdg-mime query default x-scheme-handler/telnet 2>/dev/null || true)"
    if [[ "$handler" == "securecrt-telnet.desktop" ]]; then
      ok "telnet:// → securecrt-telnet.desktop"
    elif [[ -n "$handler" ]]; then
      warn "telnet:// → $handler (SecureCRT-руу шилжүүлэхийг хүсвэл README-г үз)"
    else
      warn "telnet handler бүртгэгдээгүй"
    fi
  else
    warn "xdg-mime суугаагүй"
  fi
fi

# ------------------------------------------------------------- Network
section "Network reachability"
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
  ok "internet (8.8.8.8) reachable"
else
  warn "internet байхгүй — offline mode-руу шилжих"
fi
if ping -c 1 -W 2 github.com >/dev/null 2>&1; then
  ok "github.com reachable"
else
  warn "github.com олдохгүй (DNS эсвэл internet)"
fi

# ------------------------------------------------------------- Claude CLI
section "Claude CLI"
if command -v claude >/dev/null 2>&1; then
  ver="$(claude --version 2>&1 | head -1)"
  ok "claude installed: $ver"
  if claude mcp list 2>&1 | grep -q "Connected"; then
    ok "claude MCP servers connected"
  else
    warn "claude MCP serverүүд status шалгах (claude mcp list)"
  fi
else
  warn "claude CLI байхгүй (npm install -g @anthropic-ai/claude-code)"
fi

# ------------------------------------------------------------- Python deps
section "Python + netmiko"
if command -v python3 >/dev/null 2>&1; then
  pyver="$(python3 -V 2>&1)"
  ok "python3: $pyver"
  if python3 -c "import netmiko" 2>/dev/null; then
    ok "netmiko import OK"
  else
    fail "netmiko суугаагүй (pip3 install --user netmiko pyyaml)"
  fi
  if python3 -c "import yaml" 2>/dev/null; then
    ok "pyyaml import OK"
  else
    fail "pyyaml суугаагүй"
  fi
else
  fail "python3 PATH дээр байхгүй"
fi

# ------------------------------------------------------------- Graphviz
section "Graphviz"
if command -v dot >/dev/null 2>&1; then
  ok "$(dot -V 2>&1 | head -1)"
else
  warn "dot binary байхгүй — topology svg/png үүсгэж чадахгүй"
fi

# ------------------------------------------------------------- Repo scripts
section "Repo scripts"
for sc in olymp-run.py diagnose-eve.py netmiko_backup.py netmiko_push.py; do
  if [[ -f "$REPO/scripts/$sc" ]]; then
    ok "scripts/$sc"
  else
    fail "scripts/$sc байхгүй"
  fi
done

# ------------------------------------------------------------- olymp.conf
section "olymp.conf state"
CONF="$REPO/olymp.conf"
if [[ -f "$CONF" ]]; then
  ok "olymp.conf saved"
  if [[ -z "$EVE_HOST_OVERRIDE" ]]; then
    EVE_HOST="$(grep -E '^\s*host:' "$CONF" | head -1 | awk '{print $2}' | tr -d '\"')"
    EVE_PORT="$(grep -E '^\s*port:' "$CONF" | head -1 | awk '{print $2}')"
  fi
else
  warn "olymp.conf байхгүй — анх удаа python3 scripts/olymp-run.py --mode setup ажиллуул"
fi
[[ -n "$EVE_HOST_OVERRIDE" ]] && EVE_HOST="$EVE_HOST_OVERRIDE"
EVE_PORT="${EVE_PORT:-80}"

# ------------------------------------------------------------- EVE TCP probe
if [[ -n "${EVE_HOST:-}" ]]; then
  section "EVE-NG reach"
  if timeout 3 bash -c "</dev/tcp/$EVE_HOST/$EVE_PORT" 2>/dev/null; then
    ok "EVE TCP $EVE_HOST:$EVE_PORT OK"
  else
    warn "EVE TCP $EVE_HOST:$EVE_PORT олдохгүй (лаб эхлэхээс өмнө хэвийн)"
  fi
fi

# ------------------------------------------------------------- Reference
section "Reference материал"
REF="$REPO/reference"
if [[ -f "$REF/prompts.md" ]]; then ok "reference/prompts.md"; else fail "prompts.md алга"; fi
[[ -d "$REF/2024_round2" ]] && ok "reference/2024_round2/" || warn "2024_round2/ хоосон (Windows zenbook-аас хуул)"
[[ -d "$REF/2025_round2" ]] && ok "reference/2025_round2/" || warn "2025_round2/ хоосон"
[[ -d "$REF/cheatsheet" ]]  && ok "reference/cheatsheet/"  || warn "cheatsheet/ алга — offline fallback хязгаартай"
ls "$REF"/lab-*.pdf >/dev/null 2>&1 && ok "lab-NN.pdf бэлэн" || warn "lab-NN.pdf олдсонгүй"

# ------------------------------------------------------------- Summary
echo
printf 'Result: %bPASS=%d%b  %bWARN=%d%b  %bFAIL=%d%b\n' \
  "$GREEN" "$PASS" "$RESET" "$YELLOW" "$WARN" "$RESET" "$RED" "$FAIL" "$RESET"

[[ $FAIL -gt 0 ]] && exit 1 || exit 0

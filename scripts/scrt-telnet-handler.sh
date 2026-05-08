#!/usr/bin/env bash
# scrt-telnet-handler.sh — telnet:// URL-ийг SecureCRT-руу redirect
#
# EVE-NG WebUI-аас "Connect" дарахад xdg-open энэ скриптийг дуудна.
# URL: telnet://10.2.0.163:32769  ->  SecureCRT /T /TELNET 10.2.0.163 32769
#
# Setup: securecrt-telnet.desktop файл нь үүнийг handler болгож бүртгэдэг.
# Test: xdg-open telnet://127.0.0.1:32769

set -euo pipefail

URL="${1:-}"
if [ -z "$URL" ]; then
    notify-send "SecureCRT telnet handler" "URL дамжуулагдаагүй" 2>/dev/null || true
    exit 1
fi

# "telnet://" prefix-ийг хасна
HP="${URL#telnet://}"
HP="${HP%/}"        # trailing slash
HP="${HP%%\?*}"     # query string

# user@ хэсэг (EVE-NG ховор хэрэглэдэг гэхдээ хамгаалалт)
if [[ "$HP" == *"@"* ]]; then
    HP="${HP#*@}"
fi

if [[ "$HP" == *:* ]]; then
    HOST="${HP%:*}"
    PORT="${HP##*:}"
else
    HOST="$HP"
    PORT=23
fi

# Лог (debug)
LOG="${HOME}/.cache/scrt-telnet.log"
mkdir -p "$(dirname "$LOG")"
echo "[$(date '+%F %T')] URL=$URL  HOST=$HOST  PORT=$PORT" >> "$LOG"

# Qt6 chrome-ыг GTK theme (Arc-Dark)-аар bind хийхдээ — SecureCRT-ийг dark болгоно
export QT_QPA_PLATFORMTHEME=gtk3
export GTK_THEME=Arc-Dark

# SecureCRT шинэ tab дотор telnet
exec SecureCRT /T /TELNET "$HOST" "$PORT"

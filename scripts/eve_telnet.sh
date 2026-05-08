#!/usr/bin/env bash
# eve_telnet.sh — EVE-NG node-руу хурдан telnet холбох wrapper
#
# Usage:
#   ./eve_telnet.sh 32769            # localhost:32769 руу
#   ./eve_telnet.sh R1               # ~/.eve_pods.conf-аас "R1" нэрийг хайна
#   ./eve_telnet.sh 192.168.10.5 23  # remote host:port
#
# ~/.eve_pods.conf формат (нэр space port):
#   R1 32769
#   R2 32770
#   SW1 32772
#
# Tip: VS Code Terminal-аас direct ажиллуулна. SecureCRT хэрэгтэйгүй.

set -euo pipefail

CONF="${EVE_PODS_CONF:-$HOME/.eve_pods.conf}"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <port|name|host> [port]" >&2
    exit 1
fi

if [ $# -eq 2 ]; then
    HOST="$1"
    PORT="$2"
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    HOST="127.0.0.1"
    PORT="$1"
else
    if [ ! -f "$CONF" ]; then
        echo "Conf file байхгүй: $CONF" >&2
        echo "Жишээ: echo 'R1 32769' >> $CONF" >&2
        exit 1
    fi
    LINE=$(grep -E "^$1[[:space:]]" "$CONF" || true)
    if [ -z "$LINE" ]; then
        echo "'$1' нэртэй node $CONF-д байхгүй" >&2
        exit 1
    fi
    HOST="127.0.0.1"
    PORT=$(echo "$LINE" | awk '{print $2}')
fi

echo ">>> telnet $HOST $PORT (Ctrl+] then 'quit' to exit)"
exec telnet "$HOST" "$PORT"

#!/usr/bin/env bash
# auto-backup.sh — олимпиадын явцад тогтмол интервалаар backup ажиллуулна.
#
# RUNBOOK-д "5-15 минут тутамд backup" гэж заасан. Энийг гар ажиллуулахаас
# илүү автомат болгосон. tmux-д нэг pane-д ажиллуулаад мартчих.
#
# Хэрэглэх:
#   bash ~/net/scripts/auto-backup.sh                  # 600s (10 мин) default
#   bash ~/net/scripts/auto-backup.sh 300               # 5 мин тутам
#   INTERVAL=180 bash ~/net/scripts/auto-backup.sh      # env-ээр
#   bash ~/net/scripts/auto-backup.sh 600 --once        # 1 удаа run
#
# Лог: ~/OlympBackup/auto-backup.log (timestamp бүрд success/fail rows)
# Stop: Ctrl+C эсвэл tmux pane хаах
#
# olymp-run.py --mode backup нь:
#  - olymp.conf-аас EVE host унших
#  - active лабыг auto-detect
#  - inventory.yml + .cfg файлуудыг ~/net/olymp-day/<lab>/backup-<ts>/-д бичих
#  - амжилтгүй device-ийг raw transcript болгож үлдээх (--raw-on-fail-той хамт)

set -u
INTERVAL="${1:-${INTERVAL:-600}}"
ONCE=0
shift 2>/dev/null || true
for a in "$@"; do
  case "$a" in
    --once) ONCE=1 ;;
    *) ;;
  esac
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="${OLYMP_BACKUP_DIR:-$HOME/OlympBackup}/auto-backup.log"
mkdir -p "$(dirname "$LOG")"

GREEN=$'\e[32m'; RED=$'\e[31m'; CYAN=$'\e[36m'; RESET=$'\e[0m'

trap 'echo; echo "[$(date +%H:%M:%S)] auto-backup stopped (Ctrl+C)"; exit 0' INT TERM

echo "${CYAN}auto-backup started — interval=${INTERVAL}s log=$LOG${RESET}"
echo "${CYAN}Stop: Ctrl+C${RESET}"
echo

run_one() {
  local ts; ts="$(date +%Y-%m-%d_%H:%M:%S)"
  echo -n "[$ts] backup running ... "
  if python3 "$REPO/scripts/olymp-run.py" --mode backup --no-confirm --raw-on-fail \
       >>"$LOG" 2>&1; then
    echo "${GREEN}OK${RESET}"
    echo "[$ts] OK" >>"$LOG"
  else
    echo "${RED}FAIL${RESET} (see $LOG)"
    echo "[$ts] FAIL exit=$?" >>"$LOG"
  fi
}

if [[ $ONCE -eq 1 ]]; then
  run_one
  exit 0
fi

while true; do
  run_one
  sleep "$INTERVAL"
done

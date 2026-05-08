#!/usr/bin/env bash
# Enhanced Claude Code statusline
# ccstatusline handles: model, effort, context, usage, env info, git basics
# This script adds: per-request and per-session change deltas

set -uo pipefail

STATE_DIR="/tmp/claude-sl-${USER:-anon}"
mkdir -p "$STATE_DIR" 2>/dev/null

# ─── Base statusline (ccstatusline) ───
npx -y ccstatusline@latest 2>/dev/null || true

# ─── Git delta tracking (skip if not in a git repo) ───
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

CURRENT_NUMSTAT=$(git diff --numstat 2>/dev/null | grep -v '^-' || true)

BASELINE="$STATE_DIR/baseline.numstat"
SESSION="$STATE_DIR/session.numstat"

[ ! -f "$SESSION" ] && printf '%s' "$CURRENT_NUMSTAT" > "$SESSION"
[ ! -f "$BASELINE" ] && printf '%s' "$CURRENT_NUMSTAT" > "$BASELINE"

# ─── Delta calculator ───
calc_delta() {
    local bf="$1"
    printf '%s\n' "$CURRENT_NUMSTAT" | awk -v bf="$bf" '
    BEGIN {
        while ((getline line < bf) > 0) {
            n = split(line, p, "\t")
            if (n >= 3) { ba[p[3]] = p[1]; bd[p[3]] = p[2] }
        }
        close(bf)
        files = 0; add = 0; del = 0
    }
    NF >= 3 {
        f = $3
        if (f in ba) {
            da = $1 - ba[f]; dd = $2 - bd[f]
            if (da != 0 || dd != 0) { files++; add += da; del += dd }
            delete ba[f]
        } else {
            files++; add += $1; del += $2
        }
    }
    END {
        for (f in ba) { files++; add -= ba[f]; del -= bd[f] }
        printf "%d\t%d\t%d", files, add, del
    }'
}

IFS=$'\t' read -r REQ_F REQ_A REQ_D <<< "$(calc_delta "$BASELINE")"
IFS=$'\t' read -r SES_F SES_A SES_D <<< "$(calc_delta "$SESSION")"

# ─── Git extras ───
STASH_N=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
UNTRACK=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
STAGED_N=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
AB=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null || echo "0	0")
AHEAD=$(echo "$AB" | cut -f1)
BEHIND=$(echo "$AB" | cut -f2)
LAST_CMT=$(git log -1 --format='%h %s' 2>/dev/null | cut -c1-40)

# ─── ANSI Colors ───
RST='\033[0m'
DIM='\033[2m'
GREEN='\033[32m'
RED='\033[31m'
CYAN='\033[36m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
BLUE='\033[34m'
WHITE='\033[97m'
BGREEN='\033[1;32m'
BRED='\033[1;31m'
BCYAN='\033[1;36m'
BMAGENTA='\033[1;35m'
BBLUE='\033[1;34m'
BYELLOW='\033[1;33m'
SEP="${DIM}│${RST}"

# ─── Build delta line ───
LINE="  ${BCYAN}Req${RST} ${WHITE}${REQ_F}f${RST}"
[ "${REQ_A:-0}" -gt 0 ] 2>/dev/null && LINE+=" ${BGREEN}+${REQ_A}${RST}" || LINE+=" ${DIM}+${REQ_A}${RST}"
[ "${REQ_D:-0}" -gt 0 ] 2>/dev/null && LINE+=" ${BRED}-${REQ_D}${RST}" || LINE+=" ${DIM}-${REQ_D}${RST}"

LINE+=" ${SEP} ${BMAGENTA}Ses${RST} ${WHITE}${SES_F}f${RST}"
[ "${SES_A:-0}" -gt 0 ] 2>/dev/null && LINE+=" ${BGREEN}+${SES_A}${RST}" || LINE+=" ${DIM}+${SES_A}${RST}"
[ "${SES_D:-0}" -gt 0 ] 2>/dev/null && LINE+=" ${BRED}-${SES_D}${RST}" || LINE+=" ${DIM}-${SES_D}${RST}"

[ "${STAGED_N:-0}" -gt 0 ] 2>/dev/null && LINE+=" ${SEP} ${BGREEN}Stg ${STAGED_N}${RST}"
[ "${STASH_N:-0}" -gt 0 ] 2>/dev/null && LINE+=" ${SEP} ${BYELLOW}Sth ${STASH_N}${RST}"
[ "${UNTRACK:-0}" -gt 0 ] 2>/dev/null && LINE+=" ${SEP} ${YELLOW}Unt ${UNTRACK}${RST}"
[ "${AHEAD:-0}" -gt 0 ] 2>/dev/null && LINE+=" ${SEP} ${BBLUE}↑${AHEAD}${RST}"
[ "${BEHIND:-0}" -gt 0 ] 2>/dev/null && LINE+=" ${SEP} ${BRED}↓${BEHIND}${RST}"
[ -n "${LAST_CMT:-}" ] && LINE+=" ${SEP} ${DIM}${LAST_CMT}${RST}"

echo -e "$LINE"

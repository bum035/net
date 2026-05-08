#!/usr/bin/env bash
# ============================================================
#  Olympiad VM bootstrap — Linux (Ubuntu)
#  ----------------------------------------------------------
#  Idempotent one-shot setup для олимпиадын станц.
#  Дуудлага:
#      bash ~/net/scripts/setup-linux.sh
#  Эсвэл:
#      ~/net/scripts/setup-linux.sh --no-extensions
#
#  Хийдэг зүйл:
#    1) Repo present шалгана
#    2) Шаардлагатай tool-уудыг шалгана/суулгана (apt + pip)
#    3) ~/.vandyke/SecureCRT/Config-руу subdir + per-file symlink
#    4) ~/OlympBackup үүсгэнэ + ENV var ~/.bashrc-д тавина
#    5) VS Code extension-уудыг суулгана (--no-extensions-аар алгасч болно)
#    6) Telnet handler desktop entry бүртгэнэ (xdg-mime)
#    7) Scripts execute permission баталгаажуулна
#
#  Бүх алхам "OK" / "SKIP" / "FAIL" гэж report хийнэ.
# ============================================================

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$HOME/net}"
SCRT_REPO="$REPO_ROOT/secureCRT/VanDyke/Config"
SCRT_DEST="$HOME/.vandyke/SecureCRT/Config"
OLYMP_BACKUP_DIR_DEFAULT="$HOME/OlympBackup"

INSTALL_EXTENSIONS=1
for arg in "$@"; do
    case "$arg" in
        --no-extensions) INSTALL_EXTENSIONS=0 ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
    esac
done

# ----- helpers -----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()    { printf "${GREEN}[ OK ]${NC} %s\n" "$*"; }
skip()  { printf "${YELLOW}[SKIP]${NC} %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${NC} %s\n" "$*"; }
step()  { printf "\n${GREEN}=== %s ===${NC}\n" "$*"; }

# ----- 1) Repo presence -----
step "1/7 Repo presence"
if [ ! -d "$REPO_ROOT/.git" ]; then
    fail "$REPO_ROOT нь git repo биш. Эхлээд clone хий: git clone https://github.com/bum035/net.git ~/net"
    exit 1
fi
ok "Repo: $REPO_ROOT"
ok "Branch: $(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"

# ----- 2) Required CLI tools -----
step "2/7 CLI prerequisites"
need_apt=()
for cmd in git tmux xdg-mime python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        need_apt+=("$cmd")
    fi
done
if [ "${#need_apt[@]}" -gt 0 ]; then
    fail "Дутуу tool: ${need_apt[*]} — sudo apt install ${need_apt[*]}"
    exit 1
fi
ok "git, tmux, xdg-mime, python3 бүгд бэлэн"

# Python deps (netmiko + pyyaml)
if python3 -c 'import netmiko, yaml' 2>/dev/null; then
    ok "netmiko + pyyaml суусан"
else
    skip "netmiko/pyyaml дутуу — суулгая"
    pip3 install --user --quiet netmiko pyyaml || fail "pip3 install бүтэлгүйтсэн (manually шалга)"
fi

# SecureCRT binary
if command -v SecureCRT >/dev/null 2>&1; then
    ok "SecureCRT: $(command -v SecureCRT)"
else
    skip "SecureCRT суугаагүй (олимпиадын машинд аль хэдийн суусан байх ёстой)"
fi

# Claude Code CLI
if command -v claude >/dev/null 2>&1; then
    ok "Claude Code CLI: $(command -v claude)"
else
    skip "Claude Code CLI байхгүй — npm i -g @anthropic-ai/claude-code"
fi

# ----- 3) SecureCRT symlinks -----
step "3/7 SecureCRT config symlinks"
mkdir -p "$SCRT_DEST"

# License + SSH2.ini-г олимпиадын машинаас Config.bak-д хадгалсан бол сэргээх
if [ -d "$HOME/.vandyke/SecureCRT/Config.bak" ]; then
    for f in SecureCRT_eval.lic SSH2.ini; do
        if [ ! -e "$SCRT_DEST/$f" ] && [ -f "$HOME/.vandyke/SecureCRT/Config.bak/$f" ]; then
            cp "$HOME/.vandyke/SecureCRT/Config.bak/$f" "$SCRT_DEST/$f"
            ok "Сэргээсэн: $f"
        fi
    done
fi

# subdir symlinks
for d in Sessions Commands Keywords Scripts KnownHosts Snapshots; do
    src="$SCRT_REPO/$d"
    dst="$SCRT_DEST/$d"
    [ -d "$src" ] || { skip "Repo subdir дутуу: $d"; continue; }
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        ok "symlink (хэвээр): $d"
    else
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            mv "$dst" "${dst}.predeploy.bak"
            skip "Хуучин $d → $d.predeploy.bak"
        fi
        ln -sfn "$src" "$dst"
        ok "symlink үүсгэв: $d"
    fi
done

# per-file symlinks
for f in Global.ini ButtonBarV5.ini SCRTMenuToolbarV3.ini; do
    src="$SCRT_REPO/$f"
    dst="$SCRT_DEST/$f"
    [ -f "$src" ] || { skip "Repo file дутуу: $f"; continue; }
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        ok "symlink (хэвээр): $f"
    else
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            mv "$dst" "${dst}.predeploy.bak"
            skip "Хуучин $f → $f.predeploy.bak"
        fi
        ln -sfn "$src" "$dst"
        ok "symlink үүсгэв: $f"
    fi
done

# License-г symlink-аас сэргийлэх
if [ -L "$SCRT_DEST/SecureCRT_eval.lic" ]; then
    rm "$SCRT_DEST/SecureCRT_eval.lic"
    fail "License-ийг symlink болгож болохгүй — устгасан. Олимпиадын машинаас актуал license хуул"
fi

# ----- 4) OlympBackup -----
step "4/7 OlympBackup directory + ENV"
mkdir -p "$OLYMP_BACKUP_DIR_DEFAULT"
chmod 750 "$OLYMP_BACKUP_DIR_DEFAULT"
ok "$OLYMP_BACKUP_DIR_DEFAULT бэлэн"

if grep -q '^export OLYMP_BACKUP_DIR=' "$HOME/.bashrc" 2>/dev/null; then
    ok "OLYMP_BACKUP_DIR ~/.bashrc-д бий"
else
    {
        echo ''
        echo '# Olympiad config backup (added by setup-linux.sh)'
        echo 'export OLYMP_BACKUP_DIR="$HOME/OlympBackup"'
    } >> "$HOME/.bashrc"
    ok "OLYMP_BACKUP_DIR ~/.bashrc-д нэмэгдсэн (source ~/.bashrc хий)"
fi

# ----- 5) VS Code extensions -----
step "5/7 VS Code extensions"
if [ "$INSTALL_EXTENSIONS" -eq 0 ]; then
    skip "--no-extensions флаг идэвхтэй"
elif ! command -v code >/dev/null 2>&1; then
    skip "code CLI байхгүй (VS Code суулгасны дараа дахин ажиллуул)"
else
    declare -a wanted=(
        "fabiospampinato.vscode-highlight"
        "auchenberg.vscode-browser-preview"
        "anthropic.claude-code"
    )
    installed=$(code --list-extensions 2>/dev/null || true)
    for ext in "${wanted[@]}"; do
        if echo "$installed" | grep -qi "^${ext}$"; then
            ok "extension: $ext"
        else
            if code --install-extension "$ext" --force >/dev/null 2>&1; then
                ok "extension суулгав: $ext"
            else
                fail "extension суулгаж чадсангүй: $ext"
            fi
        fi
    done
fi

# ----- 6) Telnet handler -----
step "6/7 Telnet:// handler → SecureCRT"
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"
SRC_DESKTOP="$REPO_ROOT/secureCRT/securecrt-telnet.desktop"
DST_DESKTOP="$DESKTOP_DIR/securecrt-telnet.desktop"

if [ -f "$SRC_DESKTOP" ]; then
    cp -u "$SRC_DESKTOP" "$DST_DESKTOP"
    chmod +x "$REPO_ROOT/scripts/scrt-telnet-handler.sh" 2>/dev/null || true
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
    xdg-mime default securecrt-telnet.desktop x-scheme-handler/telnet
    current=$(xdg-mime query default x-scheme-handler/telnet 2>/dev/null || echo none)
    if [ "$current" = "securecrt-telnet.desktop" ]; then
        ok "telnet:// → SecureCRT (xdg-mime бүртгэгдсэн)"
    else
        fail "telnet:// handler буруу: $current"
    fi
else
    skip "securecrt-telnet.desktop олдсонгүй"
fi

# ----- 7) Script permissions -----
step "7/7 Script execute permissions"
chmod +x "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/scripts/*.py 2>/dev/null || true
ok "scripts/ executable"

# ----- Summary -----
step "Тогтоомжийн checklist"
cat <<EOF

Дараагийн алхам — нэг бүрчлэн шалгана:

  1. SecureCRT-г дахин нээж Sessions tree дээр pod-template/R1..SW3 гарч байгаа эсэх
  2. Button Bar дээр BACKUP / PUSH / clean_ALL товч харагдаж буй эсэхийг шалга
  3. xdg-open telnet://127.0.0.1:32769  → SecureCRT шинэ tab нээх ёстой
  4. OlympBackup тэст: SecureCRT GUI → Script → Run → Scripts/backup_configs.py
  5. VS Code: ~/net/OlympBackup/<file>.cfg нээгээд өнгө гарч буйг шалга
  6. Claude Code CLI: \`claude\` гэж дуудаж sign-in шалга

source ~/.bashrc  # OLYMP_BACKUP_DIR-ыг идэвхжүүл
EOF

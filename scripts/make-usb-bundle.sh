#!/usr/bin/env bash
# ============================================================
#  USB fallback bundle builder
#  ----------------------------------------------------------
#  GitHub clone хийх боломжгүй үед олимпиадын машин руу зөөх .zip.
#
#  Дуудлага:
#      bash ~/net/scripts/make-usb-bundle.sh                # default → ~/net-usb-<date>.zip
#      bash ~/net/scripts/make-usb-bundle.sh ~/Desktop      # тусгай folder-руу
#
#  Бэлдэх:
#    - net/ folder бүтэн (.git хасна — clone-ын оронд zip-аас унзах)
#    - vm-setup/REPORT.md, OlympBackup/*.cfg, *.log secret-уудыг хасна
#    - SHA256 болон хэмжээ хэвлэнэ — олимпиадын өдөр шалгахад тус болно
# ============================================================

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$HOME/net}"
OUT_DIR="${1:-$HOME}"
DATE_TAG="$(date +%Y-%m-%d_%H%M)"
ZIP_PATH="$OUT_DIR/net-usb-$DATE_TAG.zip"
WORK_DIR="$(mktemp -d -t net-bundle.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

if [ ! -d "$REPO_ROOT/.git" ]; then
    echo "FAIL: $REPO_ROOT нь git repo биш" >&2
    exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
    echo "FAIL: 'zip' tool алга — sudo apt install zip" >&2
    exit 1
fi

echo "=== Bundling $REPO_ROOT → $ZIP_PATH ==="

# git archive + extra runtime files (gitignored байж болох reference, etc.)
STAGE="$WORK_DIR/net"
mkdir -p "$STAGE"

# 1) Git-tracked content (clean, no .git, no untracked junk)
git -C "$REPO_ROOT" archive --format=tar HEAD | tar -x -C "$STAGE"
echo "  [+] git-tracked файл copied"

# 2) Reference материал (PDF, prior round configs) — committed бол энд орсон.
#    Untracked PDF/config-ыг гар утгаар bundle-руу хуулна.
EXTRA_REFERENCE=(
    "$REPO_ROOT/reference/"*.pdf
    "$REPO_ROOT/reference/2024_round2"
    "$REPO_ROOT/reference/2025_round2"
)
for path in "${EXTRA_REFERENCE[@]}"; do
    if [ -e "$path" ] && [ ! -e "$STAGE/${path#$REPO_ROOT/}" ]; then
        rel="${path#$REPO_ROOT/}"
        mkdir -p "$STAGE/$(dirname "$rel")"
        cp -r "$path" "$STAGE/$rel"
        echo "  [+] reference/${rel}"
    fi
done

# 3) Чухал sanitization — PSK, license, ssh key орхиод болохгүй
DANGER=(
    "$STAGE/id_ed25519"
    "$STAGE/id_ed25519.pub"
    "$STAGE/vm-setup/REPORT.md"
)
for f in "${DANGER[@]}"; do
    if [ -e "$f" ]; then
        rm -f "$f"
        echo "  [-] removed sensitive: ${f#$STAGE/}"
    fi
done

# 4) OlympBackup .cfg-уудыг bundle-аас хасна (live config-ийг public-руу нэмэхгүй)
find "$STAGE/OlympBackup" -maxdepth 2 -type f \( -name '*.cfg' -o -name '*.log' \) -delete 2>/dev/null || true

# 5) BUNDLE_INFO.txt — олимпиадын машинд unzip хийсний дараа readme
cat > "$STAGE/BUNDLE_INFO.txt" <<EOF
USB fallback bundle — net/ olympiad toolkit
Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')
Source HEAD: $(git -C "$REPO_ROOT" rev-parse --short HEAD)
Branch: $(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)

Хэрэглэх (Linux):
    unzip net-usb-*.zip -d ~/
    bash ~/net/scripts/setup-linux.sh

Хэрэглэх (Windows):
    Expand-Archive net-usb-*.zip -DestinationPath \$env:USERPROFILE
    pwsh \$env:USERPROFILE\\net\\scripts\\setup-windows.ps1

Сэрэмжлүүлэг:
    .git/-гүй (zip ашиглавал git pull боломжгүй)
    Олимпиадын дараа эх serial repo-аар clone хийх ёстой
EOF

# 6) Build the zip
mkdir -p "$OUT_DIR"
( cd "$WORK_DIR" && zip -qrX "$ZIP_PATH" net )

# 7) Stats
SIZE_HUMAN="$(du -h "$ZIP_PATH" | awk '{print $1}')"
SHA256="$(sha256sum "$ZIP_PATH" | awk '{print $1}')"

echo
echo "=== Bundle ready ==="
printf "Path:   %s\n" "$ZIP_PATH"
printf "Size:   %s\n" "$SIZE_HUMAN"
printf "SHA256: %s\n" "$SHA256"
printf "HEAD:   %s\n" "$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
echo
echo "USB-руу copy → олимпиадын машинд unzip → setup-{linux,windows}-руу шилжинэ."

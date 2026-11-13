#!/usr/bin/env bash
set -Eeuo pipefail

REPO="https://github.com/hassinz27/keramat-tomato.git"
APP="/opt/keramat-vpn"
XRAY_CONFIG="/usr/local/etc/xray/config.json"

die() {
    echo "[KERAMAT][ERROR] $*" >&2
    exit 1
}

[[ $EUID -eq 0 ]] || die "Jalankan sebagai root."
[[ -f /etc/os-release ]] || die "OS tidak dikenal."
[[ ! -e "$APP" ]] || die "$APP sudah wujud. Installer ini untuk pemasangan baharu sahaja."

. /etc/os-release
case "$ID" in
    debian|ubuntu) ;;
    *) die "OS belum disokong: $ID" ;;
esac

command -v apt-get >/dev/null || die "apt-get tidak dijumpai."

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git python3 ca-certificates curl

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 "$REPO" "$TMP/repo"

SRC="$TMP/repo"

for f in main.sh lib/common.sh modules/vless.sh modules/routing.sh; do
    [[ -f "$SRC/$f" ]] || die "Fail wajib tiada: $f"
done

while IFS= read -r -d '' f; do
    bash -n "$f" || die "Sintaks shell gagal: $f"
done < <(find "$SRC" -type f -name '*.sh' -print0)

install -d -m 0755 "$APP/lib" "$APP/modules" "$APP/docs"
install -m 0755 "$SRC/main.sh" "$APP/main.sh"
cp -a "$SRC/lib/." "$APP/lib/"
cp -a "$SRC/modules/." "$APP/modules/"

if [[ -d "$SRC/docs" ]]; then
    cp -a "$SRC/docs/." "$APP/docs/"
fi

find "$APP" -type f -name '*.sh' -exec chmod 0755 {} +

install -d -m 0755 /etc/vless
touch /etc/vless/.vless.db
chmod 600 /etc/vless/.vless.db

if [[ -e /usr/local/bin/keramat && ! -L /usr/local/bin/keramat ]]; then
    echo "[WARNING] /usr/local/bin/keramat ialah fail sedia ada; symlink tidak diganti."
else
    ln -sfn "$APP/main.sh" /usr/local/bin/keramat
fi

echo
echo "===== KERAMAT FILE INSTALLATION COMPLETE ====="
echo "Application : $APP"
echo "Command     : keramat"
echo "OS          : $PRETTY_NAME"

if command -v xray >/dev/null 2>&1 && [[ -s "$XRAY_CONFIG" ]]; then
    if xray run -test -config "$XRAY_CONFIG"; then
        echo "[OK] Xray config lulus ujian."
    else
        echo "[WARNING] Xray config gagal ujian. Semak sebelum guna panel."
    fi
else
    echo "[WARNING] Xray/config belum tersedia. Panel belum sedia untuk urus akaun."
fi

if [[ ! -s /etc/xray/domain ]]; then
    echo "[WARNING] /etc/xray/domain belum disediakan."
fi

if [[ ! -f "$APP/lib/routing.py" ]]; then
    echo "[NOTICE] Helper routing.py belum ada dalam repository; Routing Manager belum lengkap."
fi

echo
echo "Installer tidak memasang Xray/HAProxy, tidak mengubah port,"
echo "tidak memasang sijil TLS dan tidak restart sebarang service."
echo "Sediakan komponen tersebut sebelum menggunakan fungsi berkaitan."

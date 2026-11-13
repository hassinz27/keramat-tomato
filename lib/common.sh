#!/usr/bin/env bash

BASE="/opt/keramat-vpn"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
VLESS_DB="/etc/vless/.vless.db"
DOMAIN_FILE="/etc/xray/domain"

log() {
    echo "[KERAMAT] $*"
}

die() {
    echo "[KERAMAT][ERROR] $*" >&2
    exit 1
}

require_root() {
    [[ $EUID -eq 0 ]] || die "Sila jalankan sebagai root."
}

get_domain() {
    if [[ -s "$DOMAIN_FILE" ]]; then
        cat "$DOMAIN_FILE"
    else
        hostname -f 2>/dev/null || hostname
    fi
}

ensure_dirs() {
    mkdir -p /etc/vless
    touch "$VLESS_DB"
}

backup_xray() {
    mkdir -p "$BASE/backup"
    cp -a "$XRAY_CONFIG" \
        "$BASE/backup/config.json.$(date +%Y%m%d-%H%M%S)"
}

xray_test() {
    xray run -test -config "$XRAY_CONFIG"
}

restart_xray_safe() {
    xray_test || die "Config Xray gagal test. Restart dibatalkan."
    systemctl restart xray
    sleep 1
    systemctl is-active --quiet xray || die "Xray gagal aktif selepas restart."
}

valid_username() {
    [[ "$1" =~ ^[A-Za-z0-9_.-]{1,32}$ ]]
}

valid_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/opt/keramat-vpn"
source "$BASE/lib/common.sh"
source "$BASE/modules/vless.sh"
source "$BASE/modules/routing.sh"

require_root
ensure_dirs

while true; do
    clear
    echo "=============================================="
    echo "              KERAMAT VPN"
    echo "=============================================="
    echo
    echo " Xray : $(systemctl is-active xray 2>/dev/null || true)"
    echo " Domain: $(get_domain)"
    echo
    echo " 1. VLESS"
    echo " 2. System Status"
    echo " 3. Backup Xray"
    echo " 4. Routing Manager"
    echo " 0. Exit"
    echo
    read -rp "PILIHAN: " opt

    case "$opt" in
        1)
            menu_vless
            ;;
        2)
            clear
            echo "===== SYSTEM STATUS ====="
            systemctl --no-pager --full status xray | sed -n '1,12p'
            echo
            xray run -test -config "$XRAY_CONFIG"
            read -rp "Enter..."
            ;;
        3)
            backup_xray
            echo "Backup dibuat."
            read -rp "Enter..."
            ;;
        4)
            menu_routing
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Pilihan tidak sah."
            sleep 1
            ;;
    esac
done

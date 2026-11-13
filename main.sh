#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/opt/keramat-vpn"
source "$BASE/lib/common.sh"
source "$BASE/modules/vless.sh"
source "$BASE/modules/routing.sh"

require_root
ensure_dirs


restart_all_vpn_menu() {
    local -a services=()
    local svc confirm

    echo "===== VALIDATE VPN SERVICES ====="

    command -v xray >/dev/null 2>&1 || {
        echo "[ERROR] Xray tidak dijumpai."
        return 1
    }

    systemctl cat xray.service >/dev/null 2>&1 || {
        echo "[ERROR] xray.service tidak dijumpai."
        return 1
    }

    if ! xray_test; then
        echo "[ERROR] Config Xray tidak sah. Restart dibatalkan."
        return 1
    fi

    services+=(xray)
    echo "[OK] Xray configuration."

    if systemctl cat haproxy.service >/dev/null 2>&1; then
        command -v haproxy >/dev/null 2>&1 || {
            echo "[ERROR] HAProxy service wujud tetapi binary tiada."
            return 1
        }

        [[ -s /etc/haproxy/haproxy.cfg ]] || {
            echo "[ERROR] HAProxy config tiada."
            return 1
        }

        if ! haproxy -c -f /etc/haproxy/haproxy.cfg; then
            echo "[ERROR] Config HAProxy tidak sah. Restart dibatalkan."
            return 1
        fi

        services+=(haproxy)
        echo "[OK] HAProxy configuration."
    else
        echo "[NOTICE] HAProxy tidak dipasang. Dilangkau."
    fi

    echo
    echo "Service yang akan direstart: ${services[*]}"
    echo "Sambungan pengguna VPN mungkin terputus seketika."
    read -rp "Teruskan? [y/N]: " confirm

    [[ "$confirm" =~ ^[Yy]$ ]] || {
        echo "Restart dibatalkan."
        return 0
    }

    for svc in "${services[@]}"; do
        echo
        echo "Restarting $svc..."

        if ! systemctl restart "$svc"; then
            echo "[ERROR] Restart $svc gagal."
            systemctl --no-pager --full status "$svc" | sed -n '1,18p' || true
            return 1
        fi

        sleep 2

        if ! systemctl is-active --quiet "$svc"; then
            echo "[ERROR] $svc tidak aktif."
            systemctl --no-pager --full status "$svc" | sed -n '1,18p' || true
            return 1
        fi

        echo "[OK] $svc aktif."
    done

    echo
    echo "SEMUA VPN SERVICE BERJAYA DIRESTART."
}


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
    echo " 5. Restart All VPN Services"
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
        5)
            clear
            echo "===== RESTART ALL VPN SERVICES ====="
            restart_all_vpn_menu || true
            read -rp "Enter..."
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

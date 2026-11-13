#!/usr/bin/env bash

routing_cli() {
    python3 "$BASE/lib/routing.py" "$@"
}

routing_run() {
    if routing_cli "$@"; then
        return 0
    else
        echo
        echo "[KERAMAT] Arahan gagal. Semak mesej di atas."
        return 0
    fi
}

routing_pause() {
    echo
    read -rp "Tekan Enter untuk kembali..." _
}

routing_choose_outbound() {
    echo
    echo "Outbound yang tersedia:"
    routing_run outbounds
    echo
    read -rp "Masukkan outbound tag: " ROUTE_TARGET
    [[ -n "$ROUTE_TARGET" ]] || {
        echo "Tag tidak boleh kosong."
        return 1
    }
}

routing_delete_rule_prompt() {
    routing_run rules
    echo
    read -rp "Nombor rule pending yang hendak dipadam: " idx
    [[ "$idx" =~ ^[0-9]+$ ]] || { echo "Nombor tidak sah."; return 1; }
    routing_run delete-rule "$idx"
}

routing_direct_manager() {
    while true; do
        clear
        echo "=========================================="
        echo "          KERAMAT - DIRECT MANAGER"
        echo "=========================================="
        echo "1. Add Domain to DIRECT"
        echo "2. Add IP/CIDR to DIRECT"
        echo "3. View DIRECT Rules"
        echo "4. Delete Routing Rule"
        echo "0. Back"
        echo
        read -rp "Pilihan: " opt
        case "$opt" in
            1)
                read -rp "Domain (contoh: example.com): " value
                routing_run add-rule domain "$value" direct
                routing_pause
                ;;
            2)
                read -rp "IP/CIDR (contoh: 10.0.0.0/8): " value
                routing_run add-rule ip "$value" direct
                routing_pause
                ;;
            3)
                routing_run rules --tag direct
                routing_pause
                ;;
            4)
                routing_delete_rule_prompt
                routing_pause
                ;;
            0) return ;;
            *) echo "Pilihan tidak sah."; sleep 1 ;;
        esac
    done
}

routing_block_manager() {
    while true; do
        clear
        echo "=========================================="
        echo "           KERAMAT - BLOCK MANAGER"
        echo "=========================================="
        echo "1. Block Domain"
        echo "2. Block IP/CIDR"
        echo "3. Block Port"
        echo "4. View BLOCK Rules"
        echo "5. Delete Routing Rule"
        echo "0. Back"
        echo
        read -rp "Pilihan: " opt
        case "$opt" in
            1)
                read -rp "Domain untuk disekat: " value
                routing_run add-rule domain "$value" block
                routing_pause
                ;;
            2)
                read -rp "IP/CIDR untuk disekat: " value
                routing_run add-rule ip "$value" block
                routing_pause
                ;;
            3)
                read -rp "Port (contoh: 6881,1000-2000): " value
                routing_run add-rule port "$value" block
                routing_pause
                ;;
            4)
                routing_run rules --tag block
                routing_pause
                ;;
            5)
                routing_delete_rule_prompt
                routing_pause
                ;;
            0) return ;;
            *) echo "Pilihan tidak sah."; sleep 1 ;;
        esac
    done
}

routing_domain_manager() {
    while true; do
        clear
        echo "=========================================="
        echo "           KERAMAT - DOMAIN MANAGER"
        echo "=========================================="
        echo "1. Route Domain to Outbound"
        echo "2. View Domain Rules"
        echo "3. Delete Routing Rule"
        echo "0. Back"
        echo
        read -rp "Pilihan: " opt
        case "$opt" in
            1)
                read -rp "Domain / geosite (contoh: domain:google.com): " value
                if routing_choose_outbound; then
                    routing_run add-rule domain "$value" "$ROUTE_TARGET"
                fi
                routing_pause
                ;;
            2)
                routing_run rules
                routing_pause
                ;;
            3)
                routing_delete_rule_prompt
                routing_pause
                ;;
            0) return ;;
            *) echo "Pilihan tidak sah."; sleep 1 ;;
        esac
    done
}

routing_outbound_manager() {
    while true; do
        clear
        echo "=========================================="
        echo "          KERAMAT - OUTBOUND MANAGER"
        echo "=========================================="
        routing_run outbounds
        echo
        echo "1. Add SOCKS5 Outbound"
        echo "2. Delete Outbound"
        echo "0. Back"
        echo
        read -rp "Pilihan: " opt
        case "$opt" in
            1)
                read -rp "Outbound tag (contoh: socks-sg): " tag
                read -rp "Server address/domain: " host
                read -rp "Server port: " port
                read -rp "Username (kosong jika tiada auth): " username
                password=""
                if [[ -n "$username" ]]; then
                    read -rsp "Password: " password
                    echo
                fi
                ROUTE_SOCKS_USERNAME="$username" ROUTE_SOCKS_PASSWORD="$password" routing_run add-socks "$tag" "$host" "$port"
                unset password username
                routing_pause
                ;;
            2)
                read -rp "Outbound tag yang hendak dipadam: " tag
                routing_run delete-outbound "$tag"
                routing_pause
                ;;
            0) return ;;
            *) echo "Pilihan tidak sah."; sleep 1 ;;
        esac
    done
}

routing_port_manager() {
    while true; do
        clear
        echo "=========================================="
        echo "            KERAMAT - PORT MANAGER"
        echo "=========================================="
        echo "1. Route Port to Outbound"
        echo "2. View Routing Rules"
        echo "3. Delete Routing Rule"
        echo "0. Back"
        echo
        read -rp "Pilihan: " opt
        case "$opt" in
            1)
                read -rp "Port/range (contoh: 80,443,1000-2000): " value
                if routing_choose_outbound; then
                    routing_run add-rule port "$value" "$ROUTE_TARGET"
                fi
                routing_pause
                ;;
            2)
                routing_run rules
                routing_pause
                ;;
            3)
                routing_delete_rule_prompt
                routing_pause
                ;;
            0) return ;;
            *) echo "Pilihan tidak sah."; sleep 1 ;;
        esac
    done
}

routing_mode_manager() {
    clear
    echo "=========================================="
    echo "            KERAMAT - ROUTING MODE"
    echo "=========================================="
    echo "1. Custom (guna rules yang ditetapkan)"
    echo "2. Global Direct (semua trafik terus)"
    echo "3. Global Block (sekat semua trafik)"
    echo "0. Back"
    echo
    read -rp "Pilih mode: " mode
    case "$mode" in
        1) routing_run mode custom ;;
        2) routing_run mode direct ;;
        3)
            echo
            echo "AMARAN: Global Block akan menyekat semua trafik keluar melalui Xray."
            read -rp "Taip BLOCK untuk sahkan: " confirm
            [[ "$confirm" == "BLOCK" ]] && routing_run mode block || echo "Dibatalkan."
            ;;
        0) return ;;
        *) echo "Pilihan tidak sah." ;;
    esac
    routing_pause
}

menu_routing() {
    while true; do
        clear
        echo "=========================================="
        echo "             ROUTING MANAGER"
        echo "=========================================="
        echo
        routing_run status
        echo
        echo "[01] Routing Mode"
        echo "[02] Direct Manager"
        echo "[03] Block Manager"
        echo "[04] Domain Manager"
        echo "[05] Outbound Manager"
        echo "[06] Port Manager"
        echo "[07] View Pending Routing Rules"
        echo "[08] Test Configuration"
        echo "[09] Apply Changes"
        echo "[10] Reset Routing to Default"
        echo "[11] Back to System VPS"
        echo
        echo "[ x] Exit"
        echo
        read -rp "Pilih menu [01-11 atau x]: " opt
        case "$opt" in
            1|01) routing_mode_manager ;;
            2|02) routing_direct_manager ;;
            3|03) routing_block_manager ;;
            4|04) routing_domain_manager ;;
            5|05) routing_outbound_manager ;;
            6|06) routing_port_manager ;;
            7|07) routing_run rules; routing_pause ;;
            8|08) routing_run test; routing_pause ;;
            9|09)
                echo "Perubahan pending akan diuji dan Xray akan direstart jika lulus."
                read -rp "Teruskan Apply? [y/N]: " confirm
                [[ "$confirm" =~ ^[Yy]$ ]] && routing_run apply || echo "Apply dibatalkan."
                routing_pause
                ;;
            10)
                echo "Reset akan kosongkan routing rules pending; outbound dikekalkan."
                read -rp "Teruskan Reset? [y/N]: " confirm
                [[ "$confirm" =~ ^[Yy]$ ]] && routing_run reset || echo "Reset dibatalkan."
                routing_pause
                ;;
            11|0) return ;;
            x|X) return ;;
            *) echo "Pilihan tidak sah."; sleep 1 ;;
        esac
    done
}

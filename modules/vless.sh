#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/opt/keramat-vpn"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
VLESS_DB="/etc/vless/.vless.db"
DOMAIN_FILE="/etc/xray/domain"

source "$BASE/lib/common.sh"

ensure_dirs

db_find() {
    awk -v u="$1" '
        $1=="###" && $2==u {
            print
            found=1
            exit
        }
        END {
            if (!found) exit 1
        }
    ' "$VLESS_DB"
}

db_delete() {
    local user="$1"
    awk -v u="$user" '$1!="###" || $2!=u' "$VLESS_DB" > "$VLESS_DB.tmp"
    mv "$VLESS_DB.tmp" "$VLESS_DB"
}

db_add() {
    local user="$1" exp="$2" uuid="$3" quota="$4" iplimit="$5"
    db_delete "$user"
    printf '### %s %s %s %s %s\n' \
        "$user" "$exp" "$uuid" "$quota" "$iplimit" >> "$VLESS_DB"
}

xray_add_client() {
    local uuid="$1"

    python3 - "$XRAY_CONFIG" "$uuid" <<'PY2'
import json
import os
import sys

path, uuid = sys.argv[1], sys.argv[2]

with open(path) as f:
    cfg = json.load(f)

count = 0

for inbound in cfg.get("inbounds", []):
    if inbound.get("protocol") != "vless":
        continue

    settings = inbound.setdefault("settings", {})
    clients = settings.setdefault("clients", [])

    if not any(c.get("id") == uuid for c in clients):
        clients.append({"id": uuid})

    count += 1

if count == 0:
    raise SystemExit("Tiada VLESS inbound dalam config Xray.")

tmp = path + ".tmp"

with open(tmp, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

os.replace(tmp, path)

print(f"UUID ditambah/diselaraskan ke {count} VLESS inbound.")
PY2
}

xray_remove_client() {
    local uuid="$1"

    python3 - "$XRAY_CONFIG" "$uuid" <<'PY2'
import json
import os
import sys

path, uuid = sys.argv[1], sys.argv[2]

with open(path) as f:
    cfg = json.load(f)

removed = 0
vless_count = 0

for inbound in cfg.get("inbounds", []):
    if inbound.get("protocol") != "vless":
        continue

    vless_count += 1

    settings = inbound.setdefault("settings", {})
    clients = settings.setdefault("clients", [])

    old_len = len(clients)
    clients[:] = [c for c in clients if c.get("id") != uuid]
    removed += old_len - len(clients)

if vless_count == 0:
    raise SystemExit("Tiada VLESS inbound dalam config Xray.")

if removed == 0:
    raise SystemExit("UUID tidak dijumpai dalam mana-mana VLESS inbound.")

tmp = path + ".tmp"

with open(tmp, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

os.replace(tmp, path)

print(f"UUID dipadam daripada {removed} VLESS client entry.")
PY2
}

list_vless() {
    local domain selected record marker user exp uuid quota iplimit
    local found_count quota_text ip_text

    domain="$(get_domain)"

    echo
    echo "=============================================================="
    echo "                    VLESS MEMBER LIST"
    echo "=============================================================="

    if ! awk '$1=="###" {found=1} END {exit !found}' "$VLESS_DB"; then
        echo "Tiada akaun VLESS."
        return 0
    fi

    printf '%-16s %-12s %-8s %-8s\n' \
        "USERNAME" "EXPIRY" "QUOTA" "IP LIMIT"
    echo "--------------------------------------------------------------"

    awk '$1=="###" {
        q=($5==0 ? "UNLIMITED" : $5 " GB")
        ip=($6==0 ? "UNLIMITED" : $6)
        printf "%-16s %-12s %-8s %-8s\n",$2,$3,q,ip
    }' "$VLESS_DB"

    echo
    read -rp "Username untuk paparkan semua link (Enter=Back): " selected

    [[ -n "$selected" ]] || return 0

    if ! record="$(db_find "$selected")"; then
        echo "Username tidak dijumpai."
        return 1
    fi

    read -r marker user exp uuid quota iplimit <<< "$record"

    quota_text="$quota GB"
    ip_text="$iplimit"

    [[ "$quota" == "0" ]] && quota_text="UNLIMITED"
    [[ "$iplimit" == "0" ]] && ip_text="UNLIMITED"

    found_count="$(python3 - "$XRAY_CONFIG" "$uuid" <<'PY2'
import json
import sys

with open(sys.argv[1]) as f:
    cfg = json.load(f)

uuid = sys.argv[2]
vless = [
    i for i in cfg.get("inbounds", [])
    if i.get("protocol") == "vless"
]

matches = sum(
    any(c.get("id") == uuid
        for c in i.get("settings", {}).get("clients", []))
    for i in vless
)

print(f"{matches}/{len(vless)}")
PY2
)"

    echo
    echo "=============================================================="
    echo "                    VLESS ACCOUNT INFO"
    echo "=============================================================="
    echo "Username : $user"
    echo "UUID     : $uuid"
    echo "Expiry   : $exp"
    echo "Quota    : $quota_text"
    echo "IP Limit : $ip_text"
    echo "Xray Sync: $found_count inbound"

    if [[ "$found_count" != "6/6" ]]; then
        echo
        echo "WARNING: UUID belum diselaraskan ke semua 6 inbound."
        echo "Sila semak akaun sebelum menggunakan link."
        return 1
    fi

    echo
    echo "==================== CONNECTION LINKS ======================="

    echo
    echo "[1] VLESS TCP NON-TLS :443"
    echo "vless://${uuid}@${domain}:443?encryption=none&security=none&type=tcp#${user}-TCP"

    echo
    echo "[2] VLESS WS NON-TLS :80"
    echo "vless://${uuid}@${domain}:80?encryption=none&security=none&type=ws&host=${domain}&path=%2Fvless#${user}-WS-NonTLS"

    echo
    echo "[3] VLESS WS TLS :8443"
    echo "vless://${uuid}@${domain}:8443?encryption=none&security=tls&sni=${domain}&type=ws&path=%2Fvless#${user}-WS-TLS"

    echo
    echo "[4] VLESS gRPC TLS :8443"
    echo "vless://${uuid}@${domain}:8443?encryption=none&security=tls&sni=${domain}&type=grpc&serviceName=vless-grpc&alpn=h2#${user}-gRPC"

    echo
    echo "[5] VLESS HTTPUpgrade TLS :8443"
    echo "vless://${uuid}@${domain}:8443?encryption=none&security=tls&sni=${domain}&type=httpupgrade&path=%2Fvless-hu#${user}-HTTPUpgrade"

    echo
    echo "[6] VLESS XHTTP TLS :8443"
    echo "vless://${uuid}@${domain}:8443?encryption=none&security=tls&sni=${domain}&type=xhttp&path=%2Fvless-xhttp&mode=auto#${user}-XHTTP"

    echo
    echo "=============================================================="
}

add_vless() {
    local user uuid exp quota iplimit domain days
    local stamp backup_cfg backup_db
    local tcp_link ws_nontls_link ws_link grpc_link hu_link xhttp_link

    read -rp "Username       : " user
    valid_username "$user" || {
        echo "Username tidak sah."
        return 1
    }

    if db_find "$user" >/dev/null; then
        echo "Username sudah wujud."
        return 1
    fi

    read -rp "Quota GB (0=unlimited) : " quota
    valid_number "$quota" || return 1

    read -rp "Limit IP (0=unlimited) : " iplimit
    valid_number "$iplimit" || return 1

    read -rp "Expired days            : " days
    valid_number "$days" || return 1
    (( days > 0 )) || return 1

    # Pastikan kesemua transport yang diperlukan tersedia.
    python3 - "$XRAY_CONFIG" <<'PY2'
import json
import sys

expected = {
    443: "tcp",
    10000: "tcp",
    10001: "ws",
    10005: "grpc",
    10009: "httpupgrade",
    10010: "xhttp"
}

with open(sys.argv[1]) as f:
    cfg = json.load(f)

found = {}

for inbound in cfg.get("inbounds", []):
    if inbound.get("protocol") == "vless":
        port = inbound.get("port")
        network = inbound.get("streamSettings", {}).get("network", "tcp")
        found[port] = network

missing = {
    port: network
    for port, network in expected.items()
    if found.get(port) != network
}

if missing:
    print("Transport VLESS belum lengkap:", missing)
    raise SystemExit(1)

print("Semua 6 VLESS inbound tersedia.")
PY2

    if [[ $? -ne 0 ]]; then
        echo "Create dibatalkan. Config Xray tidak lengkap."
        return 1
    fi

    uuid="$(cat /proc/sys/kernel/random/uuid)"
    exp="$(date -d "+${days} days" +%Y-%m-%d)"
    domain="$(get_domain)"

    stamp="$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BASE/backup"

    backup_cfg="$BASE/backup/config.json.pre-add-$stamp"
    backup_db="$BASE/backup/vless.db.pre-add-$stamp"

    cp -a "$XRAY_CONFIG" "$backup_cfg"
    cp -a "$VLESS_DB" "$backup_db"

    # Tambah UUID kepada semua VLESS inbound.
    if ! xray_add_client "$uuid"; then
        cp -a "$backup_cfg" "$XRAY_CONFIG"
        cp -a "$backup_db" "$VLESS_DB"
        echo "Gagal menambah UUID. Perubahan dipulihkan."
        return 1
    fi

    db_add "$user" "$exp" "$uuid" "$quota" "$iplimit"

    # Uji konfigurasi sebelum restart.
    if ! xray_test; then
        cp -a "$backup_cfg" "$XRAY_CONFIG"
        cp -a "$backup_db" "$VLESS_DB"
        echo "Xray test gagal. Perubahan dipulihkan."
        return 1
    fi

    if ! systemctl restart xray; then
        cp -a "$backup_cfg" "$XRAY_CONFIG"
        cp -a "$backup_db" "$VLESS_DB"
        systemctl restart xray || true
        echo "Restart gagal. Config asal dipulihkan."
        return 1
    fi

    sleep 2

    if ! systemctl is-active --quiet xray; then
        cp -a "$backup_cfg" "$XRAY_CONFIG"
        cp -a "$backup_db" "$VLESS_DB"
        systemctl restart xray || true
        echo "Xray tidak aktif. Config asal dipulihkan."
        return 1
    fi

    # Jana lima profil menggunakan UUID yang sama.
    tcp_link="vless://${uuid}@${domain}:443?encryption=none&security=none&type=tcp#${user}-TCP"

    ws_nontls_link="vless://${uuid}@${domain}:80?encryption=none&security=none&type=ws&host=${domain}&path=%2Fvless#${user}-WS-NonTLS"

    ws_link="vless://${uuid}@${domain}:8443?encryption=none&security=tls&sni=${domain}&type=ws&path=%2Fvless#${user}-WS"

    grpc_link="vless://${uuid}@${domain}:8443?encryption=none&security=tls&sni=${domain}&type=grpc&serviceName=vless-grpc&alpn=h2#${user}-gRPC"

    hu_link="vless://${uuid}@${domain}:8443?encryption=none&security=tls&sni=${domain}&type=httpupgrade&path=%2Fvless-hu#${user}-HTTPUpgrade"

    xhttp_link="vless://${uuid}@${domain}:8443?encryption=none&security=tls&sni=${domain}&type=xhttp&path=%2Fvless-xhttp&mode=auto#${user}-XHTTP"

    echo
    echo "=========================================="
    echo "          VLESS ACCOUNT CREATED"
    echo "=========================================="
    echo "Username : $user"
    echo "UUID     : $uuid"
    echo "Expiry   : $exp"
    echo "Quota    : ${quota} GB"
    echo "IP Limit : $iplimit"
    echo
    echo "========== VLESS TCP :443 ==============="
    echo "$tcp_link"
    echo
    echo "========== VLESS WS NON-TLS :80 ========="
    echo "$ws_nontls_link"
    echo
    echo "========== VLESS WS TLS :8443 ==========="
    echo "$ws_link"
    echo
    echo "========== VLESS gRPC TLS :8443 ========="
    echo "$grpc_link"
    echo
    echo "========== VLESS HTTPUpgrade ============"
    echo "$hu_link"
    echo
    echo "========== VLESS XHTTP TLS =============="
    echo "$xhttp_link"
    echo
    echo "=========================================="
}

delete_vless() {
    local user record uuid

    list_vless
    read -rp "Username yang hendak dipadam: " user

    record="$(db_find "$user")"

    [[ -n "$record" ]] || {
        echo "User tidak dijumpai."
        return 1
    }

    uuid="$(awk '{print $4}' <<< "$record")"

    backup_xray
    xray_remove_client "$uuid"
    db_delete "$user"

    if ! xray_test; then
        echo "Config gagal test. Restore backup."
        cp -a "$(ls -1t "$BASE"/backup/config.json.* | head -1)" "$XRAY_CONFIG"
        return 1
    fi

    systemctl restart xray

    rm -f "/etc/vless/$user"
    rm -f "/etc/kyt/limit/vless/ip/$user"

    echo "VLESS $user berjaya dipadam."
}

renew_vless() {
    local user record oldexp newexp days uuid quota iplimit

    list_vless
    read -rp "Username: " user

    record="$(db_find "$user")"
    [[ -n "$record" ]] || {
        echo "User tidak dijumpai."
        return 1
    }

    oldexp="$(awk '{print $3}' <<< "$record")"
    uuid="$(awk '{print $4}' <<< "$record")"
    quota="$(awk '{print $5}' <<< "$record")"
    iplimit="$(awk '{print $6}' <<< "$record")"

    read -rp "Tambah berapa hari: " days
    valid_number "$days" || return 1

    newexp="$(date -d "$oldexp + $days days" +%Y-%m-%d)"

    db_add "$user" "$newexp" "$uuid" "$quota" "$iplimit"

    echo
    echo "Renew berjaya."
    echo "Username : $user"
    echo "Expiry   : $newexp"
}

menu_vless() {
    while true; do
        clear
        echo "=========================================="
        echo "        KERAMAT VPN - VLESS"
        echo "=========================================="
        echo "1. Add VLESS"
        echo "2. List Member / Show Links"
        echo "3. Delete VLESS"
        echo "4. Renew VLESS"
        echo "0. Back"
        echo

        read -rp "Pilihan: " opt

        case "$opt" in
            1) add_vless; read -rp "Enter..." ;;
            2) list_vless; read -rp "Enter..." ;;
            3) delete_vless; read -rp "Enter..." ;;
            4) renew_vless; read -rp "Enter..." ;;
            0) return ;;
            *) echo "Pilihan tidak sah."; sleep 1 ;;
        esac
    done
}

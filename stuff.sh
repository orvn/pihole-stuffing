#!/usr/bin/env bash
#
# Pihole route customization script
#

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

# Config
PIHOLE_IP="192.168.0.200"

# Consts
WWW_USER="www-data"
PIHOLE_BIN="$(which pihole)"
UNBLOCK_SCRIPT="/var/www/html/unblock.sh"
PIHOLE_SUDOERS="/etc/sudoers.d/pihole_www"
PIHOLE_CUSTOM_LIST="/etc/pihole/custom.list"
LIGHTTPD_EXTERNAL_CONF="/etc/lighttpd/external.conf"

if [[ "$(id -u)" != "0" ]]; then
   echo "This script must be run as root. Try running with sudo." >&2
   exit 1
fi

add_dns_record() {
    local domain="$1"
    local ip="$2"
    if ! grep -q "$ip $domain" "$PIHOLE_CUSTOM_LIST" 2>/dev/null; then
        echo "$ip $domain" >> "$PIHOLE_CUSTOM_LIST"
    fi
}

create_unblock_sh() {
    cat > "$UNBLOCK_SCRIPT" <<EOF
#!/usr/bin/env bash
sudo pihole disable 5m
EOF
    chmod +x "$UNBLOCK_SCRIPT"
}

modify_lighttpd_conf() {
    if [[ -f "$LIGHTTPD_EXTERNAL_CONF" && ! -f "$LIGHTTPD_EXTERNAL_CONF.backup" ]]; then
        cp "$LIGHTTPD_EXTERNAL_CONF" "$LIGHTTPD_EXTERNAL_CONF.backup"
    fi

    sed -i '/^\$HTTP\["host"\] == "unblock.ads"/,/^}/d' "$LIGHTTPD_EXTERNAL_CONF" 2>/dev/null || true

    cat >> "$LIGHTTPD_EXTERNAL_CONF" <<EOF

\$HTTP["host"] == "unblock.ads" {
    server.document-root = "/var/www/html"
    cgi.assign = ( ".sh" => "/bin/bash" )
    url.rewrite-once = ( "^/\$" => "/unblock.sh" )
}
EOF
}

modify_sudoers() {
    if [[ ! -f "$PIHOLE_SUDOERS" ]]; then
        echo "$WWW_USER ALL=NOPASSWD: $PIHOLE_BIN disable" > "$PIHOLE_SUDOERS"
    fi
}

restart_services() {
    pihole restartdns
    service lighttpd restart
}

main() {
    add_dns_record "unblock.ads" "$PIHOLE_IP"
    create_unblock_sh
    modify_lighttpd_conf
    modify_sudoers
    restart_services
}

main "$@"

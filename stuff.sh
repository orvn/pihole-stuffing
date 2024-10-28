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

# Must be root
if [[ "$(id -u)" != "0" ]]; then
   echo "This script must be run as root. Try running with sudo." >&2
   exit 1
fi

# Help flag
if [[ "${1-}" =~ ^-*h(elp)?$ ]]; then
    echo 'Usage: ./configure_pihole.sh

This script configures Pi-hole to add "unblock.ads" and "block.ads" endpoints.

'
    exit
fi

cd "$(dirname "$0")"

add_dns_record() {
    local domain="$1"
    local ip="$2"
    if grep -q "$ip $domain" "$PIHOLE_CUSTOM_LIST" 2>/dev/null; then
        echo "DNS record for $domain already exists."
    else
        echo "$ip $domain" >> "$PIHOLE_CUSTOM_LIST"
        echo "Added DNS record: $ip $domain"
    fi
}

create_unblock_sh() {
    cat > "$UNBLOCK_SCRIPT" <<EOF
#!/usr/bin/env bash
echo "Content-type: text/html"
echo ""
echo "<html><body><code>Ad blocking disabled for 5 minutes.</code></body></html>"
sudo pihole disable 5m
EOF
    chmod +x "$UNBLOCK_SCRIPT"
    echo "Created unblock script at $UNBLOCK_SCRIPT"
}


modify_lighttpd_conf() {
    # Backup existing external.conf
    if [[ -f "$LIGHTTPD_EXTERNAL_CONF" && ! -f "$LIGHTTPD_EXTERNAL_CONF.backup" ]]; then
        cp "$LIGHTTPD_EXTERNAL_CONF" "$LIGHTTPD_EXTERNAL_CONF.backup"
        echo "Backup of external.conf created at $LIGHTTPD_EXTERNAL_CONF.backup"
    fi

    # Avoid duplicates
    sed -i '/^\$HTTP\["host"\] == "unblock.ads"/,/^}/d' "$LIGHTTPD_EXTERNAL_CONF" 2>/dev/null || true
    sed -i '/^\$HTTP\["host"\] == "block.ads"/,/^}/d' "$LIGHTTPD_EXTERNAL_CONF" 2>/dev/null || true

    # Append new configurations
    cat >> "$LIGHTTPD_EXTERNAL_CONF" <<EOF

\$HTTP["host"] == "unblock.ads" {
    server.document-root = "/var/www/html"
    cgi.assign = ( ".sh" => "/bin/bash" )
    url.rewrite-once = ( "^/\$" => "/unblock.sh" )
}

\$HTTP["host"] == "block.ads" {
    server.document-root = "/var/www/html/admin"
    accesslog.filename = "/var/log/lighttpd/block.ads.access.log"
}
EOF
    echo "Modified $LIGHTTPD_EXTERNAL_CONF with configurations for 'unblock.ads' and 'block.ads'"
}

modify_sudoers() {
    if [[ ! -f "$PIHOLE_SUDOERS" ]]; then
        echo "$WWW_USER ALL=NOPASSWD: $PIHOLE_BIN disable" > "$PIHOLE_SUDOERS"
        echo "Created sudoers file for $WWW_USER at $PIHOLE_SUDOERS"
    else
        echo "Sudoers file for $WWW_USER already exists at $PIHOLE_SUDOERS"
    fi
}

restart_services() {
    pihole restartdns
    echo "Restarted Pi-hole DNS"
    service lighttpd restart
    echo "Restarted Lighttpd"
}

main() {
    add_dns_record "unblock.ads" "$PIHOLE_IP"
    add_dns_record "block.ads" "$PIHOLE_IP"

    create_unblock_sh
    modify_lighttpd_conf
    modify_sudoers
    restart_services

    echo "Pi-hole configuration completed successfully."
}

main "$@"

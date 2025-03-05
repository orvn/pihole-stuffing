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
UNBLOCK_DOMAIN="unblock.ads"
BLOCK_DOMAIN="block.ads"

# Consts
WWW_USER="www-data"
PIHOLE_BIN="$(which pihole)"
UNBLOCK_SCRIPT="/var/www/html/unblock.sh"
PIHOLE_SUDOERS="/etc/sudoers.d/pihole_www"
DNSMASQ_CONF="/etc/dnsmasq.d/95-custom-dns.conf"
LIGHTTPD_EXTERNAL_CONF="/etc/lighttpd/external.conf"

# PIHOLE_IP="192.168.0.200" ## Option to hardcode the Pihole IP
PIHOLE_IP="$(hostname -I | awk '{print $1}')"
PIHOLE_IP="$(echo "$PIHOLE_IP" | xargs)"

## Get Pihole IP
IP_PATTERN='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
validate_ip() {
    local ip="$1"
    local stat=1

    if [[ "$ip" =~ $IP_PATTERN ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet >= 0 && octet <= 255 )); then
                stat=0
            else
                stat=1
                break
            fi
        done
    fi
    return $stat
}

if validate_ip "$PIHOLE_IP"; then
    echo "Using Pihole IP address: $PIHOLE_IP"
else
    echo "Could not automatically detect a valid Pihole IP address."
    while true; do
        read -p "Please enter the Pihole IP address: " PIHOLE_IP
        PIHOLE_IP="$(echo "$PIHOLE_IP" | xargs)" # Whitespace
        if validate_ip "$PIHOLE_IP"; then
            echo "Using Pihole IP address: $PIHOLE_IP"
            break
        else
            echo "Invalid IP address format. Please try again."
        fi
    done
fi

# Must be root
if [[ "$(id -u)" != "0" ]]; then
   echo "This script must be run as root. Try running with sudo." >&2
   exit 1
fi

# Help flag
if [[ "${1-}" =~ ^-*h(elp)?$ ]]; then
    echo 'Usage: ./configure_pihole.sh

This script configures Pihole to add "unblock.ads" and "block.ads" endpoints.

'
    exit
fi

cd "$(dirname "$0")"

add_dns_record() {
    local domain="$1"
    local ip="$2"

    # Use dnsmasq for proper Pi-hole resolution
    touch "$DNSMASQ_CONF"

    if grep -q "address=/$domain/" "$DNSMASQ_CONF" 2>/dev/null; then
        echo "DNS record for $domain already exists."
    else
        echo "address=/$domain/$ip" >> "$DNSMASQ_CONF"
        echo "Added DNS record: $domain -> $ip"
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
    sed -i "/^\$HTTP\[\\"host\"\] == \"$UNBLOCK_DOMAIN\"/,/^}/d" "$LIGHTTPD_EXTERNAL_CONF" 2>/dev/null || true
    sed -i "/^\$HTTP\[\\"host\"\] == \"$BLOCK_DOMAIN\"/,/^}/d" "$LIGHTTPD_EXTERNAL_CONF" 2>/dev/null || true

    # Append new configurations
    cat >> "$LIGHTTPD_EXTERNAL_CONF" <<EOF

\$HTTP["host"] == "$UNBLOCK_DOMAIN" {
    server.document-root = "/var/www/html"
    cgi.assign = ( ".sh" => "/bin/bash" )
    url.rewrite-once = ( "^/\$" => "/unblock.sh" )
}

\$HTTP["host"] == "$BLOCK_DOMAIN" {
    server.document-root = "/var/www/html/admin"
    accesslog.filename = "/var/log/lighttpd/${BLOCK_DOMAIN}.access.log"
}
EOF
    echo "Modified $LIGHTTPD_EXTERNAL_CONF with configurations for '$UNBLOCK_DOMAIN' and '$BLOCK_DOMAIN'"
}

modify_sudoers() {
    if ! grep -q "$WWW_USER ALL=NOPASSWD: $PIHOLE_BIN disable" "$PIHOLE_SUDOERS" 2>/dev/null; then
        echo "$WWW_USER ALL=NOPASSWD: $PIHOLE_BIN disable" >> "$PIHOLE_SUDOERS"
        echo "Created sudoers file for $WWW_USER at $PIHOLE_SUDOERS"
    else
        echo "Sudoers file for $WWW_USER already exists at $PIHOLE_SUDOERS"
    fi
}

restart_services() {
    pihole restartdns
    echo "Restarted Pihole DNS"
    systemctl restart lighttpd
    echo "Restarted Lighttpd"
}

main() {
    add_dns_record "$UNBLOCK_DOMAIN" "$PIHOLE_IP"
    add_dns_record "$BLOCK_DOMAIN" "$PIHOLE_IP"

    create_unblock_sh
    modify_lighttpd_conf
    modify_sudoers
    restart_services

    echo "Pihole configuration completed successfully."
}

main "$@"

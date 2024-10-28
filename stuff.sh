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

if [[ "$(id -u)" != "0" ]]; then
   echo "This script must be run as root. Try running with sudo." >&2
   exit 1
fi

add_dns_record() {
    if ! grep -q "192.168.0.200 unblock.ads" "/etc/pihole/custom.list" 2>/dev/null; then
        echo "192.168.0.200 unblock.ads" >> "/etc/pihole/custom.list"
    fi
}

create_unblock_sh() {
    cat > "/var/www/html/unblock.sh" <<EOF
#!/usr/bin/env bash
sudo pihole disable 5m
EOF
    chmod +x "/var/www/html/unblock.sh"
}

modify_lighttpd_conf() {
    if [[ -f "/etc/lighttpd/external.conf" && ! -f "/etc/lighttpd/external.conf.backup" ]]; then
        cp "/etc/lighttpd/external.conf" "/etc/lighttpd/external.conf.backup"
    fi

    sed -i '/^\$HTTP\["host"\] == "unblock.ads"/,/^}/d' "/etc/lighttpd/external.conf" 2>/dev/null || true

    cat >> "/etc/lighttpd/external.conf" <<EOF

\$HTTP["host"] == "unblock.ads" {
    server.document-root = "/var/www/html"
    cgi.assign = ( ".sh" => "/bin/bash" )
    url.rewrite-once = ( "^/\$" => "/unblock.sh" )
}
EOF
}

modify_sudoers() {
    if [[ ! -f "/etc/sudoers.d/pihole_www" ]]; then
        echo "www-data ALL=NOPASSWD: $(which pihole) disable" > "/etc/sudoers.d/pihole_www"
    fi
}

restart_services() {
    pihole restartdns
    service lighttpd restart
}

main() {
    add_dns_record
    create_unblock_sh
    modify_lighttpd_conf
    modify_sudoers
    restart_services
}

main "$@"

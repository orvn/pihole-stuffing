#!/usr/bin/env bash

if [[ "$(id -u)" != "0" ]]; then
   echo "This script must be run as root. Try running with sudo." >&2
   exit 1
fi

# DNS record
grep -q "192.168.0.200 unblock.ads" "/etc/pihole/custom.list" 2>/dev/null || echo "192.168.0.200 unblock.ads" >> "/etc/pihole/custom.list"

# Create an unblock.sh script
cat > "/var/www/html/unblock.sh" <<EOF
#!/usr/bin/env bash
sudo pihole disable 5m
EOF
chmod +x "/var/www/html/unblock.sh"

# Backup and modify /etc/lighttpd/external.conf
cp "/etc/lighttpd/external.conf" "/etc/lighttpd/external.conf.backup" 2>/dev/null || true

sed -i '/^\$HTTP\["host"\] == "unblock.ads"/,/^}/d' "/etc/lighttpd/external.conf" 2>/dev/null || true

cat >> "/etc/lighttpd/external.conf" <<EOF

\$HTTP["host"] == "unblock.ads" {
    server.document-root = "/var/www/html"
    cgi.assign = ( ".sh" => "/bin/bash" )
    url.rewrite-once = ( "^/\$" => "/unblock.sh" )
}
EOF

# Set up sudo permissions for the www-data user to disable Pi-hole
echo "www-data ALL=NOPASSWD: $(which pihole) disable" > "/etc/sudoers.d/pihole_www"

# Restart services
pihole restartdns
service lighttpd restart

echo "Pihole configuration completed successfully."

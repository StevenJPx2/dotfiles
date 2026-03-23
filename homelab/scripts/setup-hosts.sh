#!/bin/bash
# Add homelab domains to /etc/hosts
# Run with: sudo ./scripts/setup-hosts.sh

HOSTS_ENTRIES="
# Homelab local domains
192.168.0.142 ha.home.local
192.168.0.142 pihole.home.local
192.168.0.142 portainer.home.local
192.168.0.142 uptime.home.local
192.168.0.142 home.home.local
# End Homelab
"

# Check if entries already exist
if grep -q "# Homelab local domains" /etc/hosts; then
    echo "Homelab entries already exist in /etc/hosts"
    echo "To update, first remove the existing entries manually"
    exit 0
fi

# Add entries
echo "$HOSTS_ENTRIES" >> /etc/hosts

echo "Added homelab domains to /etc/hosts"
echo ""
echo "You can now access:"
echo "  http://ha.home.local"
echo "  http://pihole.home.local/admin"
echo "  https://portainer.home.local"
echo "  http://uptime.home.local"
echo "  http://home.home.local"

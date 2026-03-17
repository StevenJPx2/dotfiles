# homelab/nixos/pihole.nix
#
# Network-wide DNS ad blocking via Pi-hole.
# Uses the native NixOS module (services.pihole-ftl).
#
# After deployment:
#   - Web UI at https://dns.<fqdn> (via Caddy) or http://<NUC_IP>:8053
#   - Point your router's DNS to the NUC's IP for network-wide blocking
#   - Or configure individual devices to use the NUC as DNS server
#
# Note: systemd-resolved is disabled in homelab.nix to avoid port 53 conflicts.
#
{ config, pkgs, lib, ... }:

{
  services.pihole-ftl = {
    enable = true;

    settings = {
      # Upstream DNS servers (Quad9 + Cloudflare)
      dns.upstreams = [
        "9.9.9.9"
        "1.1.1.1"
        "2620:fe::fe"           # Quad9 IPv6
        "2606:4700:4700::1111"  # Cloudflare IPv6
      ];

      # Local DNS entries (optional — add your LAN devices)
      # dns.hosts = [
      #   "192.168.1.100 nuc.local"
      #   "192.168.1.50  homeassistant.local"
      # ];
    };

    # Blocklists
    lists = [
      {
        url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
        type = "block";
        enabled = true;
        description = "StevenBlack unified hosts";
      }
      {
        url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt";
        type = "block";
        enabled = true;
        description = "Hagezi Pro blocklist";
      }
    ];
  };

  # Pi-hole web interface
  services.pihole-web = {
    enable = true;
    ports = [ "8053" ];
  };
}

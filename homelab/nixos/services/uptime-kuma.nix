# homelab/nixos/uptime-kuma.nix
#
# Service health monitoring and uptime tracking.
#
# After deployment:
#   - Access at https://status.<fqdn> (via Caddy)
#   - Create your admin account on first login
#   - Add monitors for each service (HA, Immich, Pi-hole, etc.)
#   - Configure notifications (email, Telegram, Discord, etc.)
#
{ config, pkgs, lib, ... }:

{
  services.uptime-kuma = {
    enable = true;
    settings = {
      PORT = "3001";
      HOST = "0.0.0.0";
    };
  };
}

# homelab/nixos/super-productivity.nix
#
# Time tracking and task management — runs as a Docker container
# since there's no native NixOS module for the web/server version.
#
# After deployment:
#   - Access at https://tasks.<fqdn> (via Caddy)
#   - Data persists in /var/lib/super-productivity
#
{ config, pkgs, lib, ... }:

{
  virtualisation.oci-containers.containers.super-productivity = {
    image = "johannesjo/super-productivity:latest";
    ports = [ "8020:80" ];
    volumes = [
      "/var/lib/super-productivity:/app/data"
    ];
    environment = {
      TZ = "America/New_York";  # Change to your timezone
    };
    extraOptions = [
      "--restart=unless-stopped"
      "--label=com.centurylinklabs.watchtower.enable=true"
    ];
  };

  # Ensure data directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/super-productivity 0755 root root -"
  ];
}

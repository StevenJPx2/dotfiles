# homelab/nixos/watchtower.nix
#
# Monitors Docker containers for image updates and auto-updates them.
# Currently monitors: Super Productivity.
#
# Watchtower only manages Docker/OCI containers — NixOS native services
# are updated via nixos-rebuild switch (which pulls from nixpkgs).
#
{ config, pkgs, lib, ... }:

{
  virtualisation.oci-containers.containers.watchtower = {
    image = "containrrr/watchtower:latest";
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock"
    ];
    environment = {
      TZ = "America/New_York";  # Change to your timezone

      # Check for updates daily at 4 AM
      WATCHTOWER_SCHEDULE = "0 0 4 * * *";

      # Auto-update (change to "true" for auto-update with cleanup)
      WATCHTOWER_CLEANUP = "true";

      # Only update containers with the watchtower label
      WATCHTOWER_LABEL_ENABLE = "true";

      # Notification (optional — uncomment and configure)
      # WATCHTOWER_NOTIFICATIONS = "shoutrrr";
      # WATCHTOWER_NOTIFICATION_URL = "discord://token@channel";
    };
    extraOptions = [
      "--restart=unless-stopped"
    ];
  };
}

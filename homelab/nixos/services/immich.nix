# homelab/nixos/immich.nix
#
# Photo and video management with machine learning.
# The NixOS module automatically manages PostgreSQL, Redis, and the ML service.
#
# After deployment:
#   - Access at https://photos.<fqdn> (via Caddy)
#   - Create your admin account on first login
#   - Configure external libraries in the web UI if needed
#   - Mobile app: point to https://photos.<fqdn>
#
{ config, pkgs, lib, ... }:

{
  services.immich = {
    enable = true;
    port = 2283;
    host = "0.0.0.0";
    openFirewall = true;

    # Where photos/videos are stored on disk.
    # Change this if you have a dedicated drive for media.
    mediaLocation = "/var/lib/immich/media";

    # Hardware-accelerated video transcoding.
    # null = all GPU devices; or specify e.g. [ "/dev/dri/renderD128" ]
    # Set to empty list [] to disable.
    accelerationDevices = null;
  };

  # GPU access for hardware transcoding (Intel QuickSync on NUC)
  users.users.immich.extraGroups = [ "video" "render" ];
  hardware.graphics.enable = true;

  # Uncomment for Intel NUCs with integrated graphics:
  # hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];
}

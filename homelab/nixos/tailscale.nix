# homelab/nixos/tailscale.nix
#
# Tailscale VPN configuration with automatic authentication.
# Uses a pre-authentication key for hands-free joining of the tailnet.
#
# Setup:
#   1. Generate auth key at: https://login.tailscale.com/admin/settings/keys
#      - Reusable: Yes (for reinstalls)
#      - Ephemeral: No
#      - Expiry: 90+ days
#   2. Save key to /etc/tailscale/authkey on the NUC
#   3. chmod 600 /etc/tailscale/authkey
#
# The key will be read from the file on first boot and the machine
# will automatically join your tailnet.
#
{ config, pkgs, lib, ... }:

{
  services.tailscale = {
    enable = true;
    
    # Don't use Tailscale for HTTPS certs — we're using Cloudflare
    # permitCertUid is not needed when using external ACME
    
    # Pre-authentication key for automatic login
    # Read from file (more secure than inline in config)
    authKeyFile = "/etc/tailscale/authkey";
    
    # Enable Tailscale SSH (allows SSH over Tailscale)
    extraUpFlags = [
      "--ssh"
    ];
    
    # Set the tailnet login server (default is tailscale.com)
    # Uncomment if using Headscale or custom control plane:
    # loginServer = "https://controlplane.tailscale.com";
  };

  # Ensure authkey file can be created
  systemd.tmpfiles.rules = [
    "d /etc/tailscale 0755 root root -"
  ];

  # Open firewall for Tailscale
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}

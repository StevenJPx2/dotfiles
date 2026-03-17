# homelab/nixos/homelab.nix
#
# Main homelab module — import this from your NUC's configuration.nix:
#
#   imports = [ /home/<user>/homelab/nixos/homelab.nix ];
#
# Before deploying, update the values below to match your setup:
#   - domain:       your custom domain (e.g., "home.stevenjohn.co")
#   - userName:     your NixOS user on the NUC
#   - lanInterface: your NUC's physical network interface (check `ip link`)
#
{ config, pkgs, lib, ... }:

let
  # ── Customize these for your setup ──────────────────────────────────
  domain       = "home.stevenjohn.co";  # Your custom domain
  userName     = "steven";              # Your NixOS username
  lanInterface = "eno1";                # Physical NIC on the NUC (check with: ip link)
in
{
  imports = [
    ./tailscale.nix              # VPN with auto-auth
    ./services/caddy.nix         # Reverse proxy
    ./services/home-assistant.nix # HAOS VM setup
    ./services/immich.nix        # Photo management
    ./services/pihole.nix        # DNS ad blocking
    ./services/uptime-kuma.nix   # Service monitoring
    ./services/homepage.nix      # Dashboard
    ./services/super-productivity.nix # OCI container
    ./services/watchtower.nix    # Container updates
  ];

  # ── Pass shared config to all modules via _module.args ──────────────
  _module.args = {
    inherit domain userName lanInterface;
  };

  # ── Docker (for OCI containers: Super Productivity, Watchtower) ────
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  users.users.${userName}.extraGroups = [ "docker" "incus-admin" ];

  # ── Incus (for Home Assistant OS VM) ────────────────────────────────
  virtualisation.incus.enable = true;
  networking.nftables.enable = true;

  # ── Host bridge networking ──────────────────────────────────────────
  # Bridges the physical NIC so Incus VMs get real LAN IPs via DHCP.
  networking.useDHCP = false;
  systemd.network.enable = true;
  systemd.network = {
    netdevs."10-br0" = {
      netdevConfig = {
        Name = "br0";
        Kind = "bridge";
      };
    };
    networks."20-physical" = {
      matchConfig.Name = lanInterface;
      networkConfig.Bridge = "br0";
    };
    networks."30-br0" = {
      matchConfig.Name = "br0";
      networkConfig.DHCP = "ipv4";
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # ── Firewall ────────────────────────────────────────────────────────
  networking.firewall = {
    trustedInterfaces = [ "br0" "tailscale0" ];
    # Tailscale port is handled by tailscale.nix
    allowedUDPPorts = [
      53                               # Pi-hole DNS
    ];
    allowedTCPPorts = [
      53    # Pi-hole DNS
      80    # Caddy HTTP (redirect)
      443   # Caddy HTTPS
      2283  # Immich
      3000  # Homepage
      3001  # Uptime Kuma
      8020  # Super Productivity
      8053  # Pi-hole web UI
    ];
  };

  # ── Disable systemd-resolved (conflicts with Pi-hole on port 53) ───
  services.resolved.enable = false;
}

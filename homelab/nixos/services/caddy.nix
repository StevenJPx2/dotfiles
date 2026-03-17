# homelab/nixos/caddy.nix
#
# Reverse proxy with Let's Encrypt HTTPS certificates.
# Uses Cloudflare DNS challenge for ACME (no open ports required).
#
{ config, pkgs, lib, domain, ... }:

let
  # Read Caddy plugin hash from secrets file
  # If the file doesn't exist or contains placeholder, use a dummy hash
  # that will fail on first build and show the correct hash in error message
  caddyHashFile = /home/steven/homelab/secrets/caddy-hash;
  caddyHash = if builtins.pathExists caddyHashFile then
    let content = builtins.readFile caddyHashFile;
    in if lib.hasPrefix "sha256-" content 
       then lib.removeSuffix "\n" content 
       else "sha256-PLACEHOLDER_REPLACE_AFTER_FIRST_BUILD"
  else
    "sha256-PLACEHOLDER_REPLACE_AFTER_FIRST_BUILD";
in
{
  services.caddy = {
    enable = true;

    # Caddy with Cloudflare DNS plugin for ACME DNS challenge
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare" ];
      hash = caddyHash;
    };

    # Global: use Cloudflare DNS challenge for all certs
    globalConfig = ''
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    '';

    virtualHosts = {
      # ── Homepage Dashboard ────────────────────────────────────────────
      "${domain}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString config.services.homepage-dashboard.listenPort}
        '';
      };

      # ── Home Assistant (Incus VM — gets its own LAN IP via DHCP) ────
      # Update the IP once HAOS is running and has a DHCP lease.
      "ha.${domain}" = {
        extraConfig = ''
          reverse_proxy http://HAOS_VM_IP:8123 {
            header_up Host {upstream_hostport}
          }
        '';
      };

      # ── Immich ────────────────────────────────────────────────────────
      "photos.${domain}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString config.services.immich.port} {
            header_up X-Real-IP {http.request.remote}
          }
        '';
      };

      # ── Pi-hole ───────────────────────────────────────────────────────
      "dns.${domain}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:8053
        '';
      };

      # ── Uptime Kuma ───────────────────────────────────────────────────
      "status.${domain}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:3001
        '';
      };

      # ── Super Productivity ────────────────────────────────────────────
      "tasks.${domain}" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:8020
        '';
      };
    };
  };

  # Load Cloudflare API token for ACME DNS challenge
  systemd.services.caddy.serviceConfig.EnvironmentFile = "/etc/caddy-env";
}

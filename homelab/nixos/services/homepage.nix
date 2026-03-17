# homelab/nixos/homepage.nix
#
# Dashboard showing all homelab services at a glance.
#
# After deployment:
#   - Access at https://<domain> (root domain via Caddy)
#   - API keys for widgets are loaded from /etc/homepage-secrets
#   - Create that file on the NUC with:
#       HOMEPAGE_VAR_HA_TOKEN=<your_ha_long_lived_access_token>
#       HOMEPAGE_VAR_IMMICH_KEY=<your_immich_api_key>
#
{ config, pkgs, lib, domain, ... }:

{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 3000;
    openFirewall = true;

    # Required: whitelist the hostnames you'll access the dashboard from
    allowedHosts = "${domain},localhost:3000,127.0.0.1:3000";

    # ── Settings ──────────────────────────────────────────────────────
    settings = {
      title = "Homelab";
      theme = "dark";
      color = "slate";
      headerStyle = "clean";
      layout = {
        "Home Automation" = {
          style = "row";
          columns = 2;
        };
        "Services" = {
          style = "row";
          columns = 3;
        };
        "Infrastructure" = {
          style = "row";
          columns = 3;
        };
      };
    };

    # ── Widgets (top bar) ─────────────────────────────────────────────
    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
      {
        datetime = {
          text_size = "xl";
          format = {
            dateStyle = "long";
            timeStyle = "short";
            hour12 = true;
          };
        };
      }
    ];

    # ── Services ──────────────────────────────────────────────────────
    services = [
      {
        "Home Automation" = [
          {
            "Home Assistant" = {
              icon = "home-assistant";
              href = "https://ha.${domain}";
              description = "Home automation & smart devices";
              widget = {
                type = "homeassistant";
                url = "http://HAOS_VM_IP:8123";
                key = "{{HOMEPAGE_VAR_HA_TOKEN}}";
              };
            };
          }
        ];
      }
      {
        "Services" = [
          {
            "Immich" = {
              icon = "immich";
              href = "https://photos.${domain}";
              description = "Photo & video management";
              widget = {
                type = "immich";
                url = "http://127.0.0.1:2283";
                key = "{{HOMEPAGE_VAR_IMMICH_KEY}}";
              };
            };
          }
          {
            "Super Productivity" = {
              icon = "super-productivity";
              href = "https://tasks.${domain}";
              description = "Time tracking & task management";
            };
          }
          {
            "Pi-hole" = {
              icon = "pi-hole";
              href = "https://dns.${domain}";
              description = "DNS ad blocking";
              widget = {
                type = "pihole";
                url = "http://127.0.0.1:8053";
              };
            };
          }
        ];
      }
      {
        "Infrastructure" = [
          {
            "Uptime Kuma" = {
              icon = "uptime-kuma";
              href = "https://status.${domain}";
              description = "Service health monitoring";
              widget = {
                type = "uptimekuma";
                url = "http://127.0.0.1:3001";
                slug = "homelab";
              };
            };
          }
          {
            "Tailscale" = {
              icon = "tailscale";
              href = "https://login.tailscale.com/admin/machines";
              description = "Mesh VPN";
            };
          }
        ];
      }
    ];

    # ── Bookmarks ─────────────────────────────────────────────────────
    bookmarks = [
      {
        "Resources" = [
          {
            "NixOS Wiki" = [{
              abbr = "NX";
              href = "https://wiki.nixos.org/";
            }];
          }
          {
            "Home Assistant Docs" = [{
              abbr = "HA";
              href = "https://www.home-assistant.io/docs/";
            }];
          }
          {
            "Immich Docs" = [{
              abbr = "IM";
              href = "https://immich.app/docs/overview/introduction";
            }];
          }
        ];
      }
    ];

    # ── Docker integration (for Super Productivity / Watchtower stats) ─
    docker = {};

    # ── Secrets via environment file ──────────────────────────────────
    environmentFile = "/etc/homepage-secrets";
  };

  # Grant Homepage access to Docker socket for container stats
  systemd.services.homepage-dashboard.serviceConfig.SupplementaryGroups = [ "docker" ];
}

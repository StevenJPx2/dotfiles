# NUC Homelab — Automated NixOS Infrastructure

A fully declarative, automated NixOS homelab setup for Intel NUC.

## 🎯 Goal: Zero-Touch Provisioning

From bare metal to running services in ~15 minutes with minimal manual steps.

## 📁 Structure

```
homelab/
├── nixos/                 # NixOS configurations
│   ├── installer/         # Custom NixOS installer ISO
│   │   ├── flake.nix
│   │   ├── configuration.nix
│   │   └── disko.nix
│   ├── services/          # All service modules
│   │   ├── caddy.nix
│   │   ├── home-assistant.nix
│   │   ├── immich.nix
│   │   ├── pihole.nix
│   │   ├── uptime-kuma.nix
│   │   ├── homepage.nix
│   │   ├── super-productivity.nix
│   │   └── watchtower.nix
│   ├── homelab.nix        # Main entrypoint
│   └── tailscale.nix      # VPN configuration
├── scripts/               # All shell scripts
│   ├── init.sh           # Prerequisites wizard
│   ├── deploy.sh         # Deploy configs
│   ├── setup.sh          # Post-install dispatcher
│   ├── lib/              # Shared libraries
│   │   ├── common.sh     # Logging, SSH, utilities
│   │   ├── config.sh     # Configuration values
│   │   └── cli.sh        # CLI framework
│   └── cmd/              # Modular commands
│       ├── setup-tailscale.sh
│       ├── setup-dns.sh
│       ├── setup-haos.sh
│       └── status.sh
├── secrets/               # Gitignored secrets
├── flake.nix              # Top-level Nix flake
├── README.md              # This file
└── SETUP.md               # Detailed setup guide
```

## 🚀 Quick Start

### Step 1: Prerequisites (Automated!)

```bash
just init
```

This interactive wizard will:
1. Check or generate SSH keys
2. Collect Tailscale auth key
3. Collect Cloudflare API token
4. Update installer configuration
5. Validate everything

### Step 2: Build & Flash Installer

```bash
just nuc-build-iso
just nuc-flash-iso disk4  # Use your USB device
```

### Step 3: Install to NUC

```bash
just nuc-install 192.168.1.50
```

### Step 4: Post-Setup (Run on NUC)

```bash
ssh steven@nuc
sudo -i
export CF_API_TOKEN=$(cat /home/steven/homelab/secrets/cloudflare-token)
export TAILSCALE_AUTHKEY=$(cat /home/steven/homelab/secrets/tailscale-authkey)
./scripts/setup.sh
```

### Step 5: Deploy

```bash
just deploy
```

## 🌐 Access Your Services

| Service | URL |
|---------|-----|
| Dashboard | https://home.stevenjohn.co |
| Home Assistant | https://ha.home.stevenjohn.co |
| Photos (Immich) | https://photos.home.stevenjohn.co |
| DNS (Pi-hole) | https://dns.home.stevenjohn.co |
| Monitoring | https://status.home.stevenjohn.co |
| Tasks | https://tasks.home.stevenjohn.co |

All services are **Tailscale-only** (not on public internet) but use real HTTPS certs from Let's Encrypt.

## 🔄 Day-to-Day Operations

```bash
just deploy              # Push config changes
just deploy-dry          # Preview changes
just deploy-test         # Test without persisting
just nuc-status          # Check all services
just nuc-diff            # Show config diff
just nuc-help            # Quick reference
```

## 🎛️ Just Commands Reference

| Command | Description | When to Use |
|---------|-------------|-------------|
| `just init` | Interactive prerequisites setup | First time only |
| `just init-check` | Validate prerequisites | Check if ready |
| `just doctor` | Check system health | Anytime |
| `just nuc-build-iso` | Build installer ISO | Before installation |
| `just nuc-flash-iso <device>` | Flash ISO to USB | Before installation |
| `just nuc-install <ip>` | Install NixOS to NUC | During installation |
| `just nuc-setup` | Run post-install setup | After NUC boots |
| `just deploy` | Deploy config changes | Day-to-day |
| `just deploy-dry` | Preview changes | Before deploying |
| `just deploy-test` | Test deployment | Debugging |
| `just nuc-status` | Check services | Monitoring |
| `just nuc-diff` | Show config changes | Review changes |
| `just nuc-help` | Show this reference | Anytime |

## 🏗️ Architecture

### Shell Scripts Organization

**scripts/lib/** — Shared libraries (no code duplication):
- `common.sh`: Logging, SSH utilities, secrets management
- `config.sh`: Domain, URLs, ports, service lists
- `cli.sh`: CLI framework (flags, prompts, help)

**scripts/cmd/** — Modular commands:
- Each command is a focused, single-purpose script
- Can run individually: `./scripts/cmd/setup-dns.sh`
- Source libraries for shared functionality

**scripts/** — Main scripts:
- `init.sh`: Prerequisites setup (interactive)
- `deploy.sh`: Deploy configs to NUC
- `setup.sh`: Dispatcher to cmd/ directory

### Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  YOUR MAC                                                        │
│  ├─ just init                                                   │
│  ├─ just nuc-build-iso                                          │
│  └─ just nuc-install ────────→ nixos-anywhere                   │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ SSH
┌─────────────────────────────────────────────────────────────────┐
│  NUC (NixOS)                                                     │
│  ├─ Services:                                                    │
│  │   ├─ Caddy (reverse proxy, Cloudflare DNS)                 │
│  │   ├─ Immich, Pi-hole, Homepage (native)                      │
│  │   ├─ Super Productivity, Watchtower (Docker)                 │
│  │   └─ HAOS VM (Incus)                                          │
│  └─ Setup via: ./scripts/setup.sh                               │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ HTTPS
┌─────────────────────────────────────────────────────────────────┐
│  Cloudflare DNS                                                  │
│  └─ home.stevenjohn.co → Tailscale IP                          │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Tech Stack

| Component | Technology |
|-----------|------------|
| **OS** | NixOS 24.11 |
| **Install** | nixos-anywhere + disko |
| **VPN** | Tailscale (auto-auth) |
| **Proxy** | Caddy + Let's Encrypt (Cloudflare DNS) |
| **Scripts** | Modular bash with shared libraries |
| **VM** | Incus (HAOS) |
| **Containers** | Docker |
| **Config** | Nix expressions |

## 🧩 Modular Commands

Run individual setup steps (useful for debugging):

```bash
# On the NUC:
./scripts/cmd/setup-tailscale.sh  # Just Tailscale
./scripts/cmd/setup-dns.sh          # Just DNS
./scripts/cmd/setup-haos.sh         # Just HAOS
./scripts/cmd/status.sh              # Check status
```

Or use the dispatcher:
```bash
./scripts/setup.sh all         # All steps
./scripts/setup.sh tailscale   # Tailscale only
./scripts/setup.sh dns         # DNS only
./scripts/setup.sh haos        # HAOS only
```

## 📝 Customization

Edit `nixos/homelab.nix` to change:
- Domain: `home.stevenjohn.co`
- Username: `steven`
- Network interface: `eno1`

All services are modular — disable any by removing from the imports list.

## 🐛 Troubleshooting

**Quick help:**
```bash
just nuc-help
```

**Common issues:**

- **Can't SSH to installer**: `nmap -p 22 192.168.1.0/24` or check router DHCP
- **nixos-anywhere fails**: Test `ssh root@<IP>`, use `--debug` flag
- **DNS not working**: Check `tailscale ip -4`, verify `flarectl zone list`
- **HAOS won't start**: Check `incus list`, try `incus console haos --type=vga`
- **Caddy HTTPS errors**: Check `/etc/caddy-env`, verify `journalctl -u caddy`

See [SETUP.md](SETUP.md) for detailed troubleshooting.

## 🆘 Recovery / Reinstall

If the NUC is borked:

```bash
just nuc-install <IP>
ssh steven@nuc
sudo /home/steven/homelab/scripts/setup.sh
```

All your data is preserved:
- **Immich photos**: `/var/lib/immich/media`
- **Super Productivity**: `/var/lib/super-productivity`
- **HAOS VM**: In Incus storage

## 📚 Documentation

- [SETUP.md](SETUP.md) — Complete step-by-step installation guide
- This README — Architecture overview and quick reference
- Inline comments in all scripts
- `just nuc-help` — Quick command reference

## 📖 References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
- [disko](https://github.com/nix-community/disko)
- [Tailscale Auth Keys](https://tailscale.com/kb/1085/auth-keys)

## 🤝 Contributing

This is a personal homelab config, but feel free to fork and adapt!

The modular structure makes it easy to:
- Add new services to `nixos/`
- Add new setup commands to `scripts/cmd/`
- Extend shared libraries in `scripts/lib/`

## 📝 License

MIT — Do what you want, no warranty.

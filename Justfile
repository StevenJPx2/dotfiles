set positional-arguments

# ── Homelab / NUC ─────────────────────────────────────────────────────────

# Run initial setup (SSH keys, tokens, configuration)
init:
  cd homelab && scripts/init.sh

# Check prerequisites without running setup
init-check:
  cd homelab && scripts/init.sh "-""-"check

# Check system health and prerequisites
doctor:
  homelab/scripts/doctor.sh

# Build custom NixOS installer ISO
nuc-build-iso:
  cd homelab && nix build '.#iso'
  @echo "ISO built at: homelab/result/iso/nixos-*.iso"
  @echo "Flash to USB with: just nuc-flash-iso /dev/diskX"

# Flash the built ISO to a USB drive (WARNING: destroys data on USB!)
nuc-flash-iso device:
  @echo "Flashing ISO to {{device}}..."
  diskutil unmountDisk {{device}} || true
  sudo dd if=homelab/result/iso/nixos-*.iso of=/dev/r{{device#/dev/}} bs=4m status=progress
  @echo "Done! Eject with: diskutil eject {{device}}"

# Install NixOS to the NUC using nixos-anywhere
nuc-install target-host:
  cd homelab && nix run ".#install" "-""-" "$1"

# Run post-installation setup on the NUC via SSH
nuc-setup *args:
  homelab/scripts/nuc-setup.sh "$@"

# Run individual setup steps on NUC (useful for debugging)
nuc-setup-tailscale:
  @echo "Run on NUC: ./homelab/scripts/cmd/setup-tailscale.sh"

nuc-setup-dns:
  @echo "Run on NUC: ./homelab/scripts/cmd/setup-dns.sh"

nuc-setup-haos:
  @echo "Run on NUC: ./homelab/scripts/cmd/setup-haos.sh"

# Deploy configuration changes to running NUC
deploy *args:
  homelab/scripts/deploy.sh "$@"

# Preview what would be deployed
deploy-dry:
  homelab/scripts/deploy.sh "-""-"dry-run

# Test deployment (nixos-rebuild test, doesn't update bootloader)
deploy-test:
  homelab/scripts/deploy.sh "-""-"test

# Check service status on NUC
nuc-status:
  homelab/scripts/cmd/status.sh

# Show configuration diff before applying
nuc-diff:
  homelab/scripts/deploy.sh "-""-"diff

# Nix development shell with all tools
nuc-shell:
  cd homelab && nix develop

# Quick start guide for new users
nuc-help:
  @echo "NUC Homelab Quick Start:"
  @echo ""
  @echo "1. Prerequisites:       just doctor"
  @echo "2. Setup:              just init"
  @echo "3. Build ISO:          just nuc-build-iso"
  @echo "4. Flash USB:          just nuc-flash-iso /dev/diskX"
  @echo "5. Install:            just nuc-install <IP>"
  @echo "6. Post-setup:         just nuc-setup"
  @echo "7. Deploy:             just deploy"
  @echo ""
  @echo "Full docs: homelab/SETUP.md and homelab/README.md"

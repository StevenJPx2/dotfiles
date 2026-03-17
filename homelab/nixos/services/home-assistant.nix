# homelab/nixos/services/home-assistant.nix
#
# Home Assistant OS (HAOS) VM via Incus
#
# Quick Start (Automated):
#   Run: ./scripts/cmd/setup-haos.sh
#   Or:  ./scripts/setup.sh haos
#   Or:  just nuc-setup-haos
#
# This will automatically:
#   - Download HAOS image (v14.2 or latest)
#   - Create Incus VM (2 CPU, 4GB RAM, 64GB disk)
#   - Import disk image
#   - Start the VM
#   - Display the VM IP for Caddy config
#
# After setup, note the VM IP and update:
#   - nixos/services/caddy.nix: Replace HAOS_VM_IP in reverse_proxy
#   - nixos/services/homepage.nix: Update widget URL
#   Then run: just deploy
#
# USB Passthrough for Zigbee/Z-Wave sticks:
#   incus config device add haos zigbee usb vendorid=10c4 productid=ea60
#
# Manual Fallback (if automation fails):
#   1. Download: wget https://github.com/home-assistant/operating-system/releases/download/14.2/haos_ova-14.2.qcow2.xz
#   2. Extract: xz -d haos_ova-14.2.qcow2.xz
#   3. Create VM: incus init haos --empty --vm -c limits.cpu=2 -c limits.memory=4GiB -c security.secureboot=false
#   4. Import: qemu-img convert -f qcow2 -O raw haos_ova-14.2.qcow2 /var/lib/incus/storage-pools/default/virtual-machines/haos/root.img
#   5. Start: incus start haos
#   6. Get IP: incus list
#
# Useful Commands:
#   incus list              # Show VM status and IP
#   incus stop haos         # Graceful shutdown
#   incus console haos --type=vga  # Access VM console
#   incus delete haos       # Remove VM (destructive!)
#
{ config, pkgs, lib, lanInterface, ... }:

{
  # ── Incus preseed configuration ─────────────────────────────────────
  # Declaratively configures Incus with a bridged network and storage pool.
  # This runs once on initialization — changes here won't affect an
  # already-initialized Incus install (use `incus` CLI for modifications).
  virtualisation.incus.preseed = {
    networks = [
      {
        name = "br0";
        type = "bridge";
        config = {
          "bridge.driver" = "native";
          # No NAT — VMs get IPs from your router's DHCP
          "ipv4.address" = "none";
          "ipv4.nat" = "false";
          "ipv6.address" = "none";
          "ipv6.nat" = "false";
        };
      }
    ];

    storage_pools = [
      {
        name = "default";
        driver = "dir";
        config = {
          source = "/var/lib/incus/storage-pools/default";
        };
      }
    ];

    profiles = [
      {
        name = "default";
        devices = {
          eth0 = {
            name = "eth0";
            network = "br0";
            type = "nic";
          };
          root = {
            path = "/";
            pool = "default";
            size = "64GiB";
            type = "disk";
          };
        };
      }
    ];
  };
}

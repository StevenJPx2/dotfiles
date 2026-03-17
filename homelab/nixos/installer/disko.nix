# homelab/installer/disko.nix
#
# Declarative disk partitioning for the NUC.
# This defines the disk layout that disko will create.
#
# Layout:
#   - GPT partition table
#   - Partition 1: 512MB EFI System Partition (ESP) — FAT32, boot flag
#   - Partition 2: 8GB Linux swap
#   - Partition 3: Remainder — ext4, mounted at /
#
# IMPORTANT: This will DESTROY all data on the target disk.
# By default targets /dev/nvme0n1 (typical for NUCs with NVMe SSDs).
# Change `device` below if your NUC uses a different disk.
#
{ config, lib, pkgs, ... }:

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";  # Change if your disk is different
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition (ESP)
            ESP = {
              type = "EF00";  # EFI System partition type
              size = "512M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            # Swap partition
            swap = {
              size = "8G";
              content = {
                type = "swap";
                randomEncryption = true;  # Encrypt swap for security
              };
            };

            # Root partition (remainder of disk)
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}

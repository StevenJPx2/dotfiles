# homelab/installer/configuration.nix
#
# Configuration for the custom NixOS installer ISO.
# This is a minimal system designed to:
# 1. Boot quickly
# 2. Auto-enable SSH with your public key
# 3. Include disko for partitioning
# 4. Provide necessary tools for installation
#
{ config, pkgs, lib, ... }:

{
  imports = [
    ./disko.nix
  ];

  # ── System ─────────────────────────────────────────────────────────
  system.stateVersion = "24.11";

  # ── Boot ─────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ── Networking ─────────────────────────────────────────────────────
  networking = {
    hostName = "nuc-installer";
    useDHCP = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];  # SSH
    };
  };

  # ── SSH Access ────────────────────────────────────────────────────
  # CRITICAL: Replace this with your actual SSH public key
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHChkj8fKw2dvMhYo8C2gK6bUGxQbITP8dJlHBc5M3oQ steven@macbook"
    ];
  };

  # Also create a non-root user with sudo
  users.users.steven = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHChkj8fKw2dvMhYo8C2gK6bUGxQbITP8dJlHBc5M3oQ steven@macbook"
    ];
  };

  # Passwordless sudo for installer (convenient for automation)
  security.sudo.wheelNeedsPassword = false;

  # ── Services ───────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      # Disable password auth, keys only
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      # Keep connections alive
      ClientAliveInterval = 60;
      ClientAliveCountMax = 3;
    };
  };

  # ── Packages ─────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # Core tools
    git
    vim
    nano
    htop
    
    # Disk management
    parted
    gptfdisk
    smartmontools
    
    # Network tools
    curl
    wget
    iproute2
    bind  # for dig/nslookup
    nmap
    
    # System tools
    jq
    yq
    
    # Disko is included via the module, but let's add the CLI too
    disko
  ];

  # ── Documentation ────────────────────────────────────────────────
  # Show a message on login
  services.getty.helpLine = ''
    
    ╔════════════════════════════════════════════════════════════════╗
    ║  NixOS Homelab Installer                                       ║
    ║                                                                ║
    ║  SSH is enabled. Connect with:                               ║
    ║    ssh root@<IP> or ssh steven@<IP>                          ║
    ║                                                                ║
    ║  From your Mac, run:                                           ║
    ║    just nuc-install --target-host <IP>                        ║
    ║                                                                ║
    ║  Check IP with: ip addr                                        ║
    ╚════════════════════════════════════════════════════════════════╝
    
  '';
}

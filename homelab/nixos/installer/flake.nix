# homelab/installer/flake.nix
#
# Nix flake for building a custom NixOS installer ISO.
# This ISO auto-enables SSH with your public key for instant remote access.
#
# Build the ISO:
#   nix build .#iso
#
# The ISO will be at: result/iso/nixos-*.iso
#
{
  description = "Custom NixOS installer ISO for NUC homelab";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, disko, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # Custom installer ISO
      packages.${system}.iso = nixos-generators.nixosGenerate {
        inherit system;
        format = "install-iso";
        modules = [
          disko.nixosModules.disko
          ./configuration.nix
          ({ config, ... }: {
            # ISO specific settings
            isoImage.squashfsCompression = "zstd -Xcompression-level 3";
            
            # Enable SSH in the ISO
            services.openssh = {
              enable = true;
              settings.PermitRootLogin = "prohibit-password";
            };

            # Auto-login as root on console (convenient for debugging)
            services.getty.autologinUser = "root";
          })
        ];
      };

      # Dev shell with tools
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.nixos-anywhere
          pkgs.flarectl
          pkgs.jq
        ];
      };
    };
}

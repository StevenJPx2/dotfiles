# homelab/flake.nix
#
# Top-level flake for the homelab project.
# Provides:
#   - Custom installer ISO build
#   - NixOS system configuration for the NUC
#   - Development shell with tools
#   - Apps for automation (nixos-anywhere wrapper)
#
{
  description = "NUC Homelab — Automated NixOS setup with services";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    
    # For building custom ISO
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # For disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # For remote installation (optional, usually installed via nix-shell)
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, disko, nixos-anywhere, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      
      # Helper to create NixOS system with our config
      mkNucSystem = { extraModules ? [] }: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          ./nixos/homelab.nix
        ] ++ extraModules;
      };
    in
    {
      # Custom installer ISO (from installer/ subdirectory)
      packages.${system} = {
        iso = nixos-generators.nixosGenerate {
          inherit system;
          format = "install-iso";
          modules = [
            disko.nixosModules.disko
            ./installer/configuration.nix
            ({ config, ... }: {
              isoImage.squashfsCompression = "zstd -Xcompression-level 3";
            })
          ];
        };
        
        # The full NUC system (for building closure)
        nuc-system = (mkNucSystem {}).config.system.build.toplevel;
      };

      # NixOS configurations
      nixosConfigurations = {
        nuc = mkNucSystem {};
      };

      # Development shell with automation tools
      devShells.${system}.default = pkgs.mkShell {
        name = "homelab-dev";
        buildInputs = [
          # Installation tools
          nixos-anywhere.packages.${system}.nixos-anywhere
          pkgs.nixos-rebuild
          
          # Cloudflare DNS
          pkgs.flarectl
          
          # Utilities
          pkgs.jq
          pkgs.curl
          pkgs.nmap
        ];
        
        shellHook = ''
          echo "Homelab development environment"
          echo ""
          echo "Available commands:"
          echo "  nixos-anywhere    - Remote NixOS installation"
          echo "  flarectl          - Cloudflare CLI"
          echo "  jq                - JSON processor"
          echo ""
          echo "Just commands:"
          echo "  just nuc-build-iso    - Build installer ISO"
          echo "  just nuc-install      - Install to NUC"
          echo "  just nuc-setup        - Run post-install setup"
          echo "  just deploy           - Deploy config changes"
          echo ""
        '';
      };

      # Apps for running via "nix run"
      apps.${system} = {
        # Build ISO
        build-iso = {
          type = "app";
          program = "${self.packages.${system}.iso}/iso/nixos.iso";
        };
        
        # Install to remote host
        install = {
          type = "app";
          program = toString (pkgs.writeShellScript "nuc-install" ''
            if [ $# -eq 0 ]; then
              echo "Usage: nix run .#install -- <target-host>"
              echo "Example: nix run .#install -- 192.168.1.50"
              exit 1
            fi
            
            TARGET="$1"
            FLAKE="${self}#nuc"
            
            echo "Installing NixOS to $TARGET..."
            echo "Using flake: $FLAKE"
            echo ""
            
            ${nixos-anywhere.packages.${system}.nixos-anywhere}/bin/nixos-anywhere \
              --flake "$FLAKE" \
              --target-host "root@$TARGET"
          '');
        };
      };
    };
}

{
  description = "Workstation configuration (Nix delivers, layer owners stay)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      mkHome = host:
        let facts = import ./nix/hosts/${host}/facts.nix;
        in home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit facts man;
            xremap = pkgs.callPackage ./nix/pkgs/xremap.nix { };
          };
          modules = [ ./nix/hosts/${host}/home.nix ];
        };

      # Man pages from docs/ with lowdown from nixpkgs.
      man = pkgs.callPackage ./nix/pkgs/man.nix { };

      # System file tree of the host; `ws system diff|check` compares it.
      mkSystem = host: pkgs.callPackage ./system {
        facts = import ./nix/hosts/${host}/facts.nix;
      };
    in {
      homeConfigurations."king@mbp16" = mkHome "mbp16";

      checks.${system} = {
        home-mbp16 = (mkHome "mbp16").activationPackage;
        system-mbp16 = mkSystem "mbp16";
        inherit man;
      };

      # Tools `ws` runs, pinned by flake.lock.
      packages.${system} = {
        home-manager = home-manager.packages.${system}.home-manager;
        nvd = pkgs.nvd;
        xremap = pkgs.callPackage ./nix/pkgs/xremap.nix { };
        system-mbp16 = mkSystem "mbp16";
        man = man;
      };
    };
}

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
        let facts = import ./hosts/${host}/facts.nix;
        in home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit facts; };
          modules = [ ./hosts/${host}/home.nix ];
        };
    in {
      homeConfigurations."king@mbp16" = mkHome "mbp16";

      checks.${system}.home-mbp16 =
        (mkHome "mbp16").activationPackage;

      # Tools `ws` runs, pinned by flake.lock.
      packages.${system} = {
        home-manager = home-manager.packages.${system}.home-manager;
        nvd = pkgs.nvd;
      };
    };
}

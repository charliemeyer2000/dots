{inputs, ...}: let
  hmModule = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "bak";
    home-manager.users.charlie = import ../home;
  };

  # nix-homebrew configuration for automatic Homebrew installation
  homebrewModule = {
    nix-homebrew = {
      enable = true;
      enableRosetta = true;
      user = "charlie";
      autoMigrate = true;
    };
  };

  # Overlays applied to all hosts
  overlayModule = {
    nixpkgs.overlays = [
      inputs.claude-code-overlay.overlays.default
      inputs.uvacompute.overlays.default
      inputs.rv.overlays.default
    ];
  };
in {
  flake = {
    darwinConfigurations.darwin-personal = inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {inherit inputs;};
      modules = [
        ../hosts/darwin-personal
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
        hmModule
        homebrewModule
        overlayModule
      ];
    };

    nixosConfigurations.linux = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        ../hosts/linux
        inputs.home-manager.nixosModules.home-manager
        hmModule
        overlayModule
      ];
    };

    nixosConfigurations.linux-hpc = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        ../hosts/linux-hpc
        inputs.home-manager.nixosModules.home-manager
        hmModule
        overlayModule
      ];
    };
  };
}

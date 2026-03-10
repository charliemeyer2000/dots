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
      ];
    };

    darwinConfigurations.darwin-minimal = inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {inherit inputs;};
      modules = [
        ../hosts/darwin-minimal
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
        hmModule
        homebrewModule
      ];
    };

    nixosConfigurations.linux-ec2 = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        ../hosts/linux-ec2
        inputs.home-manager.nixosModules.home-manager
        hmModule
      ];
    };

    nixosConfigurations.linux-hpc = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        ../hosts/linux-hpc
        inputs.home-manager.nixosModules.home-manager
        hmModule
      ];
    };
  };
}

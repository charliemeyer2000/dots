{inputs, ...}: let
  hmModule = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "bak";
    home-manager.users.charlie = import ../home;
  };
in {
  flake = {
    darwinConfigurations.darwin-personal = inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ../hosts/darwin-personal
        inputs.home-manager.darwinModules.home-manager
        hmModule
      ];
    };

    darwinConfigurations.darwin-minimal = inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ../hosts/darwin-minimal
        inputs.home-manager.darwinModules.home-manager
        hmModule
      ];
    };

    nixosConfigurations.linux-ec2 = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ../hosts/linux-ec2
        inputs.home-manager.nixosModules.home-manager
        hmModule
      ];
    };

    nixosConfigurations.linux-hpc = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ../hosts/linux-hpc
        inputs.home-manager.nixosModules.home-manager
        hmModule
      ];
    };
  };
}

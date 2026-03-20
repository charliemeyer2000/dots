{inputs, ...}: let
  hmModule = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "bak";
    home-manager.users.charlie = import ../home;
  };

  homebrewModule = {
    nix-homebrew = {
      enable = true;
      enableRosetta = true;
      user = "charlie";
      autoMigrate = true;
    };
  };

  overlays = [
    inputs.claude-code-overlay.overlays.default
    inputs.uvacompute.overlays.default
    inputs.rv.overlays.default
  ];

  pkgsLinux = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
    inherit overlays;
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
        {nixpkgs.overlays = overlays;}
      ];
    };

    homeConfigurations.workstation = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsLinux;
      modules = [
        ../hosts/workstation
      ];
    };
  };
}

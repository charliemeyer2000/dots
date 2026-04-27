{inputs, ...}: let
  hmModule = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "bak";
    home-manager.users.charlie = {
      imports = [
        (import ../home)
        (import ../home/hammerspoon.nix)
        inputs.vimessage.homeManagerModules.default
      ];
    };
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
    inputs.devin-cli-overlay.overlays.default
    inputs.sf-cli-overlay.overlays.default
    inputs.voiceink-overlay.overlays.default
    inputs.uvacompute.overlays.default
    inputs.rv.overlays.default
  ];

  pkgsLinux = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
    inherit overlays;
  };

  # Build a nix-darwin system from a host module under ../hosts/<name>.
  # All darwin hosts share the same wiring (home-manager, nix-homebrew, overlays);
  # per-host divergence belongs in ../hosts/<name>/default.nix.
  mkDarwin = name:
    inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {inherit inputs;};
      modules = [
        ../hosts/_darwin-common.nix
        ../hosts/${name}
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
        hmModule
        homebrewModule
        {nixpkgs.overlays = overlays;}
      ];
    };

  darwinHosts = [
    "darwin-personal"
    "darwin-agent"
    "darwin-cog"
  ];
in {
  flake = {
    darwinConfigurations =
      inputs.nixpkgs.lib.genAttrs darwinHosts mkDarwin;

    homeConfigurations.workstation = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsLinux;
      modules = [
        ../hosts/workstation
      ];
    };
  };
}

{inputs, ...}: let
  # Which nixpkgs / nix-darwin / home-manager release a platform builds from — see flake.nix
  # (`*-intel`) for why x86_64-darwin is pinned to 26.05.
  toolchainFor = system:
    if system == "x86_64-darwin"
    then {
      nix-darwin = inputs.nix-darwin-intel;
      home-manager = inputs.home-manager-intel;
    }
    else {
      inherit (inputs) nix-darwin home-manager;
    };

  hmModule = user: {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "bak";
    home-manager.users.${user} = {
      imports = [
        (import ../home)
        (import ../home/hammerspoon.nix)
        inputs.vimessage.homeManagerModules.default
      ];
    };
  };

  homebrewModule = user: {pkgs, ...}: {
    nix-homebrew = {
      inherit user;
      enable = true;
      # Rosetta is an Apple Silicon feature; nix-homebrew asserts on Intel if asked for it.
      enableRosetta = pkgs.stdenv.hostPlatform.isAarch64;
      autoMigrate = true;
    };
  };

  cliOverlay = import ../overlays/cli-from-flake.nix;

  overlays = [
    inputs.claude-code-overlay.overlays.default
    (cliOverlay inputs.devin-cli-overlay "devin-cli")
    (cliOverlay inputs.sf-cli-overlay "sf-cli")
    inputs.uvacompute.overlays.default
    inputs.rv.overlays.default
    (import ../overlays/bun.nix)
  ];

  pkgsLinux = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
    overlays = overlays ++ [inputs.llm-agents.overlays.shared-nixpkgs];
  };

  # Build a nix-darwin system from a host module under ../hosts/<name> for the given platform and
  # macOS account. All darwin hosts share the same wiring (home-manager, nix-homebrew, overlays);
  # per-host divergence belongs in ../hosts/<name>/default.nix. Modules read the account back via
  # `config.system.primaryUser` — never hard-code `charlie`.
  mkDarwin = name: {
    system,
    user ? "charlie",
  }: let
    toolchain = toolchainFor system;
  in
    toolchain.nix-darwin.lib.darwinSystem {
      specialArgs = {inherit inputs;};
      modules = [
        ../hosts/_darwin-common.nix
        ../hosts/${name}
        toolchain.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
        (hmModule user)
        (homebrewModule user)
        {
          nixpkgs.hostPlatform = system;
          nixpkgs.overlays = overlays;
          system.primaryUser = user;
          users.users.${user} = {
            name = user;
            home = "/Users/${user}";
          };
        }
      ];
    };

  darwinHosts = {
    darwin-personal.system = "aarch64-darwin";
    darwin-agent.system = "aarch64-darwin";
    darwin-cog.system = "aarch64-darwin";
    darwin-bot = {
      system = "x86_64-darwin"; # the always-on Intel MacBook
      user = "charliebot"; # its own macOS account, created at first boot
    };
  };
in {
  flake = {
    darwinConfigurations =
      inputs.nixpkgs.lib.mapAttrs mkDarwin darwinHosts;

    homeConfigurations.workstation = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsLinux;
      modules = [
        ../hosts/workstation
      ];
    };

    homeConfigurations.devin-cloud = inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsLinux;
      modules = [
        ../hosts/devin-cloud
      ];
    };
  };
}

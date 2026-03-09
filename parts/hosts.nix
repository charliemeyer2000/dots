{inputs, ...}: {
  flake = {
    darwinConfigurations.darwin-personal = inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ../hosts/darwin-personal
        inputs.home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.charlie = import ../home;
        }
      ];
    };
  };
}

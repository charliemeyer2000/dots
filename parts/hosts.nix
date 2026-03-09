{inputs, ...}: {
  flake = {
    darwinConfigurations.darwin-personal = inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ../hosts/darwin-personal
      ];
    };
  };
}

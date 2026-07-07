{...}: {
  imports = [
    ../modules/base.nix
    ../modules/darwin.nix
    ../modules/apps.nix
    ../modules/secrets.nix
    ../modules/tart.nix
  ];

  # Pre-pull common Tart VM images on all darwin hosts
  dots.tart.images = [
    "ghcr.io/cirruslabs/macos-sequoia-base:latest"
    "ghcr.io/cirruslabs/macos-tahoe-base:latest"
  ];

  system.primaryUser = "charlie";
  users.users.charlie = {
    name = "charlie";
    home = "/Users/charlie";
  };

  nix.enable = false;
  system.stateVersion = 6;
}

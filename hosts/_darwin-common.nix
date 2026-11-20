{...}: {
  imports = [
    ../modules/base.nix
    ../modules/darwin.nix
    ../modules/apps.nix
    ../modules/secrets.nix
  ];

  system.primaryUser = "charlie";
  users.users.charlie = {
    name = "charlie";
    home = "/Users/charlie";
  };

  nix.enable = false;
  system.stateVersion = 6;
}

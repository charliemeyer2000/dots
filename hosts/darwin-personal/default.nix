{
  imports = [
    ../../modules/base.nix
    ../../modules/darwin.nix
    ../../modules/apps.nix
  ];

  # nix-darwin needs to know the primary user
  system.primaryUser = "charlie";
  users.users.charlie = {
    name = "charlie";
    home = "/Users/charlie";
  };

  # Determinate Systems installer manages Nix, not nix-darwin
  nix.enable = false;

  # Set the hostname used by nix-darwin
  networking.hostName = "charlies-MacBook-Pro-2";

  # Required by nix-darwin
  system.stateVersion = 6;
}

{
  imports = [
    ../../modules/base.nix
  ];

  # nix-darwin needs to know the primary user
  users.users.charlie = {
    name = "charlie";
    home = "/Users/charlie";
  };

  # Set the hostname used by nix-darwin
  networking.hostName = "charlies-MacBook-Pro-2";

  # Required by nix-darwin
  system.stateVersion = 6;
}

{...}: {
  imports = [
    ../../modules/base.nix
    ../../modules/darwin.nix
    ../../modules/apps.nix
    ../../modules/secrets.nix
  ];

  system.primaryUser = "charlie";
  users.users.charlie = {
    name = "charlie";
    home = "/Users/charlie";
  };

  nix.enable = false; # Determinate Systems manages the daemon
  networking.hostName = "charlies-MacBook-Pro-2";
  system.stateVersion = 6;
}

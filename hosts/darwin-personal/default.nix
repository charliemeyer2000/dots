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

  nix.enable = false;
  networking.hostName = "charlies-MacBook-Pro-2";
  networking.computerName = "Charlie's MacBook Pro";
  networking.localHostName = "charlies-MacBook-Pro-2";
  system.stateVersion = 6;
}

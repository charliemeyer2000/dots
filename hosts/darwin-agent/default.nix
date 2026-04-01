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
  networking.hostName = "charlie-m1pro";
  networking.computerName = "Charlie's M1 Pro";
  networking.localHostName = "charlie-m1pro";
  system.stateVersion = 6;
}

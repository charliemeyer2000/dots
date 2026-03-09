{
  imports = [
    ../../modules/base.nix
    ../../modules/darwin.nix
    ../../modules/secrets.nix
  ];

  system.primaryUser = "charlie";
  users.users.charlie = {
    name = "charlie";
    home = "/Users/charlie";
  };

  nix.enable = false;
  networking.hostName = "darwin-minimal";
  system.stateVersion = 6;
}

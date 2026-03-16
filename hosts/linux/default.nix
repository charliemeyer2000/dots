{
  imports = [
    ../../modules/base.nix
    ../../modules/secrets.nix
  ];

  # Stub hardware config — replace per-machine on deploy
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };
  boot.loader.grub.device = "/dev/sda";

  users.users.charlie = {
    isNormalUser = true;
    home = "/home/charlie";
    extraGroups = ["wheel" "docker"];
  };

  networking.hostName = "linux";
  system.stateVersion = "24.11";
}

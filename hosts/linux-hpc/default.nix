{
  imports = [
    ../../modules/base.nix
  ];

  # Stub hardware config — replaced per-machine on deploy
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };
  boot.loader.grub.device = "/dev/sda";

  users.users.charlie = {
    isNormalUser = true;
    home = "/home/charlie";
  };

  networking.hostName = "linux-hpc";
  system.stateVersion = "24.11";
}

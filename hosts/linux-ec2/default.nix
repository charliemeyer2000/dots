{
  imports = [
    ../../modules/base.nix
    ../../modules/secrets.nix
  ];

  # Stub hardware config — replaced per-machine on deploy
  fileSystems."/" = {
    device = "/dev/xvda1";
    fsType = "ext4";
  };
  boot.loader.grub.device = "/dev/xvda";

  users.users.charlie = {
    isNormalUser = true;
    home = "/home/charlie";
    extraGroups = ["wheel" "docker"];
  };

  networking.hostName = "linux-ec2";
  system.stateVersion = "24.11";
}

{
  pkgs,
  lib,
  ...
}: let
  sharedPackages = import ../../modules/packages.nix {inherit pkgs lib;};
in {
  imports = [
    ../../home
    ../../modules/hm-secrets.nix
  ];

  home = {
    username = "charlie";
    homeDirectory = "/home/charlie";

    packages =
      sharedPackages
      ++ (with pkgs; [
        # GPU monitoring (drivers + CUDA toolkit managed by Ubuntu)
        nvtopPackages.nvidia
        btop
      ]);
  };

  nixpkgs.config.allowUnfree = true;
}

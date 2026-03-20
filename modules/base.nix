{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = import ./packages.nix {inherit pkgs lib;};
  nixpkgs.config.allowUnfree = true;
}

{pkgs, ...}: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # TODO: remove doCheck override once upstream direnv tests pass in nixpkgs.
    package = pkgs.direnv.overrideAttrs (_: {doCheck = false;});
  };
}

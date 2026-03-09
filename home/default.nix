{pkgs, ...}: {
  imports = [
    ./git.nix
    ./zsh.nix
    ./direnv.nix
  ];

  home.stateVersion = "24.11";
  programs.home-manager.enable = true;
}

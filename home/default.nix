{pkgs, ...}: {
  imports = [
    ./git.nix
    ./zsh.nix
    ./direnv.nix
    ./ssh.nix
    ./fonts.nix
    ./ghostty.nix
    ./claude.nix
  ];

  home.stateVersion = "24.11";
  programs.home-manager.enable = true;
}

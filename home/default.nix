{...}: {
  imports = [
    ./git.nix
    ./zsh.nix
    ./direnv.nix
    ./ssh.nix
    ./fonts.nix
    ./ghostty.nix
    ./agents.nix
  ];

  home.stateVersion = "24.11";
  programs.home-manager.enable = true;
}

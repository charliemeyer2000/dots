{pkgs, ...}: let
  inherit (pkgs.stdenv) isDarwin;
  # Path to 1Password SSH agent socket, relative to $HOME / ~.
  # Single source of truth for both ssh_config (IdentityAgent) and shell (SSH_AUTH_SOCK).
  onePasswordAgentSocket =
    if isDarwin
    then "Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else ".1password/agent.sock";
in {
  imports = [
    ./git.nix
    ./zsh.nix
    ./direnv.nix
    ./ssh.nix
    ./fonts.nix
    ./ghostty.nix
    ./agents.nix
  ];

  _module.args = {inherit onePasswordAgentSocket;};

  home.stateVersion = "24.11";
  programs.home-manager.enable = true;
}

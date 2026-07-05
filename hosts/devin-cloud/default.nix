{
  pkgs,
  lib,
  ...
}: let
  sharedPackages = import ../../modules/packages.nix {inherit pkgs lib;};
in {
  # Ephemeral Devin cloud-agent VM. Standalone home-manager (like `workstation`),
  # but only the headless, non-1Password slice: it imports the safe home modules
  # directly instead of ../../home so it can skip git.nix (1Password commit
  # signing + gh credential helper — would break Devin's git proxy), ssh.nix
  # (1Password agent socket), and the GUI modules (ghostty/fonts/hammerspoon).
  # Secrets are Devin-managed env vars, so hm-secrets.nix is omitted too.
  imports = [
    ../../home/zsh.nix
    ../../home/direnv.nix
    ../../home/agents.nix
  ];

  # zsh.nix consumes this for SSH_AUTH_SOCK; there is no 1Password agent on a
  # cloud VM, so the socket simply won't exist (ssh falls back to no agent,
  # which is fine for Tailscale SSH).
  _module.args.onePasswordAgentSocket = ".1password/agent.sock";

  home = {
    username = "ubuntu";
    homeDirectory = "/home/ubuntu";
    stateVersion = "24.11";
    packages = sharedPackages;
  };

  programs.home-manager.enable = true;

  dots.agents.instructions.host =
    builtins.readFile ../../config/agents/hosts/devin-cloud.md;

  nixpkgs.config.allowUnfree = true;
}

{
  pkgs,
  lib,
  ...
}: let
  sharedPackages = import ../../modules/packages.nix {inherit pkgs lib;};
in {
  # Headless, non-1Password slice for ephemeral Devin cloud VMs: import the safe
  # home modules directly instead of ../../home, skipping git.nix (breaks Devin's
  # git proxy), ssh.nix, the GUI modules, and hm-secrets.nix (Devin-managed env vars).
  imports = [
    ../../home/zsh.nix
    ../../home/direnv.nix
    ../../home/agents.nix
  ];

  # zsh.nix reads this for SSH_AUTH_SOCK; the socket is absent on the VM, so ssh
  # falls back to no agent.
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

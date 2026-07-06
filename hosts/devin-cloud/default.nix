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
    # sharedPackages already provides tailscale + _1password-cli; these helpers
    # wrap them for the two access paths the org blueprint used to inline as
    # heredocs (tailnet join; on-demand 1P SSH key into ssh-agent).
    packages =
      sharedPackages
      ++ [
        (pkgs.writeShellScriptBin "devin-tailscale-up" (builtins.readFile ./bin/devin-tailscale-up))
        (pkgs.writeShellScriptBin "devin-op-ssh" (builtins.readFile ./bin/devin-op-ssh))
      ];
  };

  programs.home-manager.enable = true;

  dots.agents.instructions.host =
    builtins.readFile ../../config/agents/hosts/devin-cloud.md;

  nixpkgs.config.allowUnfree = true;
}

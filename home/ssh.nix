{
  pkgs,
  onePasswordAgentSocket,
  ...
}: let
  inherit (pkgs.stdenv) isDarwin;
in {
  # The 1Password SSH agent only offers keys from the built-in Personal/Private
  # vaults unless this config exists — our SSH key lives in the personal
  # account's Developer vault. Once this file exists, ONLY the vaults listed
  # here are offered, so add new entries if keys move again.
  # https://developer.1password.com/docs/ssh/agent/config/
  home.file.".config/1Password/ssh/agent.toml".text = ''
    [[ssh-keys]]
    vault = "Developer"
    account = "my.1password.com"
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes =
      if isDarwin
      then ["/Users/charlie/.colima/ssh_config"]
      else [];
    settings = {
      workstation = {
        HostName = "100.97.247.28";
        User = "charlie";
      };
      uva-hpc = {
        HostName = "login.hpc.virginia.edu";
        User = "abs6bd";
        IdentityFile = "~/.ssh/id_ed25519";
        ControlMaster = "auto";
        ControlPath = "~/.ssh/sockets/uva-hpc-%r@%h-%p";
        ControlPersist = "30m";
        ServerAliveInterval = 60;
      };
      do-droplet = {
        HostName = "24.199.85.26";
        User = "root";
      };
      "*" = {
        ForwardAgent = false;
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        SetEnv = {
          TERM = "xterm-256color";
        };
        IdentityAgent = "\"~/${onePasswordAgentSocket}\"";
        AddKeysToAgent = "yes";
      };
    };
  };
}

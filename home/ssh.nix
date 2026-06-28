{
  pkgs,
  onePasswordAgentSocket,
  ...
}: let
  inherit (pkgs.stdenv) isDarwin;
in {
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

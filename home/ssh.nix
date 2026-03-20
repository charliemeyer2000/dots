{pkgs, ...}: let
  inherit (pkgs.stdenv) isDarwin;
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes =
      if isDarwin
      then ["/Users/charlie/.colima/ssh_config"]
      else [];
    matchBlocks = {
      workstation = {
        hostname = "100.97.247.28";
        user = "charlie";
      };
      uva-hpc = {
        hostname = "login.hpc.virginia.edu";
        user = "abs6bd";
        extraOptions = {
          ControlMaster = "auto";
          ControlPath = "~/.ssh/sockets/uva-hpc-%r@%h-%p";
          ControlPersist = "30m";
          ServerAliveInterval = "60";
        };
        identityFile = "~/.ssh/id_ed25519";
      };
      jetson-nano = {
        hostname = "100.95.16.119";
        user = "charlie";
      };
      do-droplet = {
        hostname = "24.199.85.26";
        user = "root";
      };
      "*" = {
        forwardAgent = false;
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        setEnv = {
          TERM = "xterm-256color";
        };
        extraOptions = {
          IdentityAgent =
            if isDarwin
            then "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\""
            else "\"~/.1password/agent.sock\"";
          AddKeysToAgent = "yes";
        };
      };
    };
  };
}

{...}: {
  programs.ssh = {
    enable = true;
    includes = ["/Users/charlie/.colima/ssh_config"];
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
        setEnv = {
          TERM = "xterm-256color";
        };
        extraOptions = {
          IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
          AddKeysToAgent = "yes";
        };
      };
    };
  };
}

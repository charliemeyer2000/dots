{...}: {
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Charlie Meyer";
        email = "charlie@charliemeyer.xyz";
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKATWx0Ji3b96HH3rBEol2cEnNqTlZBUvOjV0McaUm1q";
      };
      gpg.format = "ssh";
      gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      commit.gpgsign = true;
      init.defaultBranch = "main";
      pull.rebase = true;
      credential."https://github.com".helper = "!/run/current-system/sw/bin/gh auth git-credential";
      credential."https://gist.github.com".helper = "!/run/current-system/sw/bin/gh auth git-credential";
    };
    ignores = [".DS_Store" ".env.local" "*.log" ".claude/settings.local.json"];
  };
}

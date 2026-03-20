{pkgs, ...}: let
  inherit (pkgs.stdenv) isDarwin;
  opSshSign =
    if isDarwin
    then "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
    else "/opt/1Password/op-ssh-sign";
  ghCredHelper =
    if isDarwin
    then "!/run/current-system/sw/bin/gh auth git-credential"
    else "!gh auth git-credential";
in {
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Charlie Meyer";
        email = "charlie@charliemeyer.xyz";
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKATWx0Ji3b96HH3rBEol2cEnNqTlZBUvOjV0McaUm1q";
      };
      gpg.format = "ssh";
      gpg.ssh.program = opSshSign;
      commit.gpgsign = true;
      init.defaultBranch = "main";
      pull.rebase = true;
      credential."https://github.com".helper = ghCredHelper;
      credential."https://gist.github.com".helper = ghCredHelper;
    };
    ignores = [".DS_Store" ".env.local" "*.log" ".claude/settings.local.json" ".agents/local/"];
  };
}

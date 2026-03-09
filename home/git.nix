{...}: {
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Charlie Meyer";
        email = "charlie@charliemeyer.xyz";
        signingkey = "~/.ssh/id_ed25519.pub";
      };
      gpg.format = "ssh";
      commit.gpgsign = true;
      init.defaultBranch = "main";
      pull.rebase = true;
      credential."https://github.com".helper = "!/opt/homebrew/bin/gh auth git-credential";
      credential."https://gist.github.com".helper = "!/opt/homebrew/bin/gh auth git-credential";
    };
    ignores = [".DS_Store" ".env.local" "*.log" ".claude/settings.local.json"];
  };
}

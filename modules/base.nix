{pkgs, ...}: {
  # Core packages installed on every host
  environment.systemPackages = with pkgs; [
    git
    ripgrep
    fd
    fzf
    jq
    curl
    wget
    htop
    tree
    just
    direnv
    starship
    zoxide
    gh
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}

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
    gh
  ];

  # Enable flakes
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}

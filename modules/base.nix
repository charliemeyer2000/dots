{pkgs, ...}: {
  # Core packages installed on every host
  environment.systemPackages = with pkgs; [
    # Shell tools
    git
    ripgrep
    fd
    fzf
    jq
    curl
    wget
    htop
    tree
    tmux
    bat
    just
    direnv
    starship
    zoxide
    gh
    gum
    nmap
    socat

    # Dev tools
    cmake
    graphviz
    pandoc
    typst
    pre-commit
    ruff
    cppcheck

    # Language runtimes & package managers
    go
    rustup
    lua
    pnpm
    uv
    _1password-cli

    # Cloud & infra
    awscli2
    kubectl
    kubernetes-helm
    kind
    colima
    docker-client
    docker-buildx
    docker-compose
    cloudflared
    tailscale
    redis
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}

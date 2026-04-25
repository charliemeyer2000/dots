{
  pkgs,
  lib,
}:
with pkgs;
  [
    git
    git-lfs
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
    # TODO: remove doCheck override once upstream direnv tests pass in nixpkgs.
    (direnv.overrideAttrs (_: {doCheck = false;}))
    zoxide
    gh
    gum
    nmap
    socat

    # Dev
    cmake
    graphviz
    pandoc
    typst
    pre-commit
    ruff
    cppcheck

    # Runtimes
    go
    rustup
    lua
    nodejs_22
    pnpm
    bun
    uv
    claude-code
    devin-cli
    sf-cli
    uvacompute
    rv
    _1password-cli

    # Infra
    awscli2
    kubectl
    kubernetes-helm
    kind
    docker-client
    docker-buildx
    docker-compose
    cloudflared
    tailscale
    redis
    postgresql
    ollama
  ]
  ++ lib.optionals pkgs.stdenv.isDarwin [
    colima
    voiceink
  ]

{
  description = "charliemeyer2000/dots — declarative dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Automatically install and manage Homebrew on macOS
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Claude Code — hourly-updated overlay with official Anthropic binaries
    claude-code-overlay = {
      url = "github:ryoppippi/claude-code-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        inputs.pre-commit-hooks.flakeModule
        ./parts/formatter.nix
        ./parts/checks.nix
        ./parts/devshell.nix
        ./parts/hosts.nix
      ];
    };
}

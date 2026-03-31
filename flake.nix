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
      url = "github:charliemeyer2000/nix-claude-code";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Devin CLI — pre-built binaries
    devin-cli-overlay = {
      url = "github:charliemeyer2000/devin-cli-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # UVACompute CLI
    uvacompute = {
      url = "https://uvacompute.com/nix/flake.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # rv CLI — GPU computing on Rivanna
    rv = {
      url = "github:charliemeyer2000/rivanna.dev";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # vimessage — vim hotkeys for Messages.app
    vimessage.url = "github:charliemeyer2000/vimessage";
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

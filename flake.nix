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

    # Intel Macs (darwin-bot): nixpkgs-unstable 26.11 dropped x86_64-darwin, so that host builds
    # from the last release that has it (security fixes until the end of 2026). nix-darwin and
    # home-manager refuse a nixpkgs from another release, hence the matched trio.
    nixpkgs-intel.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin-intel = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-intel";
    };
    home-manager-intel = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-intel";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Automatically install and manage Homebrew on macOS
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Claude Code — auto-updated nix package with official Anthropic binaries
    claude-code-overlay = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Devin CLI — pre-built binaries
    devin-cli-overlay = {
      url = "github:charliemeyer2000/devin-cli-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SF Compute CLI — pre-built binaries
    sf-cli-overlay = {
      url = "github:charliemeyer2000/sf-cli-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # agent-browser CLI (Linux only; darwin uses the Homebrew formula)
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
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
        "x86_64-darwin"
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

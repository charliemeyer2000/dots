# Build a pre-built-binary CLI (devin-cli, sf-cli) from its overlay flake's package.nix against
# *our* nixpkgs. The upstream `overlays.default` return `self.packages.${system}.<cli>`, which
# instantiates the overlay flake's own nixpkgs input — nixpkgs-unstable, which no longer
# evaluates on x86_64-darwin (darwin-bot is pinned to 26.05, see flake.nix). `final.callPackage`
# uses whatever nixpkgs the host actually builds from.
#
# Mirrors the upstream "latest of versions/*.json" selection.
flake: attr: final: _prev: let
  inherit (final) lib;
  versions = map (lib.removeSuffix ".json") (builtins.attrNames (builtins.readDir "${flake}/versions"));
  latest = builtins.head (builtins.sort (a: b: builtins.compareVersions a b > 0) versions);
in {
  ${attr} = final.callPackage "${flake}/package.nix" {
    sourcesFile = "${flake}/versions/${latest}.json";
  };
}

# Pin bun ahead of nixpkgs. Repos that pin `.bun-version` 1.4.x write lockfiles
# an older bun cannot parse: `bun install` then warns `UnknownLockfileVersion`,
# ignores bun.lock and rewrites the whole file. Drop this overlay once
# nixpkgs-unstable ships bun >= 1.4.0.
#
# To bump: change `version`, then refresh each hash with
#   nix store prefetch-file --json https://github.com/oven-sh/bun/releases/download/bun-v<version>/<asset>
_final: prev: {
  bun = prev.bun.overrideAttrs (finalAttrs: prevAttrs: let
    asset = name:
      prev.fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/${name}";
        hash = finalAttrs.passthru.hashes.${name};
      };
  in {
    version = "1.4.0";
    # nixpkgs' bun already derives `src` from `passthru.sources`; restating it
    # here keeps `overrideAttrs` from warning that `version` moved without `src`.
    src = finalAttrs.passthru.sources.${prev.stdenvNoCC.hostPlatform.system};
    passthru =
      prevAttrs.passthru
      // {
        hashes = {
          "bun-darwin-aarch64.zip" = "sha256-xmnpf2Fk4cluBwF0jbmN+ndJKQjL2DlMdVcTSnNd44E=";
          "bun-linux-aarch64.zip" = "sha256-SxozLuhhmD65O8/m93D/+U4+MbLDiL2uo8jtNeWO7Q4=";
          "bun-linux-x64-baseline.zip" = "sha256-GE+0WV8NQBohfPfHjBvEMLqDMU2reouUgFurv3+nCX8=";
        };
        # nixpkgs' bun reads `src` from here, so the new version flows through.
        sources = {
          "aarch64-darwin" = asset "bun-darwin-aarch64.zip";
          "aarch64-linux" = asset "bun-linux-aarch64.zip";
          "x86_64-linux" = asset "bun-linux-x64-baseline.zip";
        };
      };
  });
}

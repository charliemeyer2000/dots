# `imsg` built for macOS 13 (Ventura) from charliemeyer2000/imsg (branch `ventura`), a fork of
# openclaw/imsg whose only change is the deployment target: upstream declares macOS 14+ and the
# Homebrew formula refuses older macOS, but the code has explicit macOS 13 paths. darwin-bot — an
# Intel MacBook whose last supported macOS is Ventura — installs this instead of `steipete/tap/imsg`.
#
# The release zip is the fork's ad-hoc-signed universal build (`release-ventura.yml`); nothing is
# compiled here. Mirrors the formula's layout: everything in libexec (the CLI expects its resource
# bundles and bridge helper beside the executable) and a shell exec script in bin.
#
# To bump: push a `v<upstream>-ventura.<n>` tag on the fork (release-ventura.yml publishes the zip), then
#   nix store prefetch-file --json https://github.com/charliemeyer2000/imsg/releases/download/<tag>/imsg-macos.zip
_final: prev: {
  imsg-ventura = prev.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "imsg-ventura";
    version = "0.15.10-ventura.1";
    src = prev.fetchurl {
      url = "https://github.com/charliemeyer2000/imsg/releases/download/v${finalAttrs.version}/imsg-macos.zip";
      hash = "sha256-ysaZVoS9R/bMriHyI3LqQD4m1mEU3pciXUCgFtp8u+s=";
    };
    nativeBuildInputs = [prev.unzip];
    sourceRoot = ".";
    # Ad-hoc signed with entitlements; stripping or rewriting load commands would break the signature.
    dontFixup = true;
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/libexec $out/bin
      cp -R imsg imsg-bridge-helper.dylib *.bundle $out/libexec/
      cat > $out/bin/imsg <<SH
      #!/bin/sh
      exec "$out/libexec/imsg" "\$@"
      SH
      chmod +x $out/bin/imsg
      runHook postInstall
    '';
    meta = {
      description = "iMessage/SMS CLI (openclaw/imsg) built for macOS 13+";
      homepage = "https://github.com/charliemeyer2000/imsg/tree/ventura";
      platforms = ["x86_64-darwin" "aarch64-darwin"];
      mainProgram = "imsg";
    };
  });
}

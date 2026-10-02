{
  lib,
  pkgs,
  ...
}: {
  # Raycast Script Commands (macOS only). Source of truth is config/raycast/;
  # files without a @raycast header (e.g. _lib/) are ignored by Raycast.
  # One-time: Raycast → Settings → Script Commands → Add Script Directory → ~/.config/raycast-scripts
  config = lib.mkIf pkgs.stdenv.isDarwin {
    home.file.".config/raycast-scripts" = {
      source = ../config/raycast;
      recursive = true;
    };
  };
}

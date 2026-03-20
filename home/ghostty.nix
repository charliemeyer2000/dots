{pkgs, ...}: let
  font = "Berkeley Mono"; # paid font, fallback: JetBrainsMono Nerd Font
  inherit (pkgs.stdenv) isDarwin;
  mod =
    if isDarwin
    then "cmd"
    else "ctrl+shift";
  modAlt =
    if isDarwin
    then "cmd+opt"
    else "ctrl+alt";
in {
  home.file.".config/ghostty/config".text = ''
    font-family = ${font}
    font-family-bold = ${font}
    font-family-italic = ${font}
    font-family-bold-italic = ${font}

    # Gruvbox Material theme (custom)
    palette = 0=#282828
    palette = 1=#ea6962
    palette = 2=#a9b665
    palette = 3=#d8a657
    palette = 4=#7daea3
    palette = 5=#d3869b
    palette = 6=#89b482
    palette = 7=#d4be98
    palette = 8=#5a524c
    palette = 9=#e78a4e
    palette = 10=#a9b665
    palette = 11=#d8a657
    palette = 12=#7daea3
    palette = 13=#d3869b
    palette = 14=#89b482
    palette = 15=#ddc7a1

    background = #282828
    foreground = #d4be98
    cursor-color = #ddc7a1
    cursor-text = #282828
    selection-background = #504945
    selection-foreground = #ebdbb2

    keybind = ${modAlt}+\=new_split:right
    keybind = ${modAlt}+-=new_split:down

    keybind = ${mod}+h=goto_split:left
    keybind = ${mod}+j=goto_split:down
    keybind = ${mod}+k=goto_split:up
    keybind = ${mod}+l=goto_split:right

    keybind = ${modAlt}+h=resize_split:left,10
    keybind = ${modAlt}+j=resize_split:down,10
    keybind = ${modAlt}+k=resize_split:up,10
    keybind = ${modAlt}+l=resize_split:right,10

    keybind = ${modAlt}+=equalize_splits
    keybind = ${modAlt}+enter=toggle_split_zoom
    keybind = ${mod}+w=close_surface
  '';
}

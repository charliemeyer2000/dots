{...}: let
  font = "Berkeley Mono"; # paid font, fallback: JetBrainsMono Nerd Font
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

    # Shift+Enter passes through naturally when not bound

    keybind = cmd+opt+\=new_split:right
    keybind = cmd+opt+-=new_split:down

    keybind = cmd+h=goto_split:left
    keybind = cmd+j=goto_split:down
    keybind = cmd+k=goto_split:up
    keybind = cmd+l=goto_split:right

    keybind = cmd+opt+h=resize_split:left,10
    keybind = cmd+opt+j=resize_split:down,10
    keybind = cmd+opt+k=resize_split:up,10
    keybind = cmd+opt+l=resize_split:right,10

    keybind = cmd+opt+=equalize_splits
    keybind = cmd+opt+enter=toggle_split_zoom
    keybind = cmd+w=close_surface
  '';
}

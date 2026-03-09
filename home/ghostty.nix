{...}: let
  font = "Berkeley Mono"; # paid font, fallback: JetBrainsMono Nerd Font
in {
  home.file.".config/ghostty/config".text = ''
    font-family = ${font}
    font-family-bold = ${font}
    font-family-italic = ${font}
    font-family-bold-italic = ${font}

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

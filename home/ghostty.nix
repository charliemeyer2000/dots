{...}: let
  # Berkeley Mono is preferred but requires manual install (paid font).
  # JetBrainsMono Nerd Font is the nix-managed fallback.
  # Change this if you don't have Berkeley Mono installed.
  font = "Berkeley Mono";
in {
  home.file.".config/ghostty/config".text = ''
    font-family = ${font}
    font-family-bold = ${font}
    font-family-italic = ${font}
    font-family-bold-italic = ${font}

    # Creating splits
    keybind = cmd+opt+\=new_split:right
    keybind = cmd+opt+-=new_split:down

    # Navigating splits (vim-style hjkl)
    keybind = cmd+h=goto_split:left
    keybind = cmd+j=goto_split:down
    keybind = cmd+k=goto_split:up
    keybind = cmd+l=goto_split:right

    # Resizing splits
    keybind = cmd+opt+h=resize_split:left,10
    keybind = cmd+opt+j=resize_split:down,10
    keybind = cmd+opt+k=resize_split:up,10
    keybind = cmd+opt+l=resize_split:right,10

    # Equalize all splits
    keybind = cmd+opt+=equalize_splits

    # Zoom current split (toggle)
    keybind = cmd+opt+enter=toggle_split_zoom

    # Close current split
    keybind = cmd+w=close_surface
  '';
}

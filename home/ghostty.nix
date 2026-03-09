{...}: {
  home.file.".config/ghostty/config".text = ''
    font-family = Berkeley Mono
    font-family-bold = Berkeley Mono
    font-family-italic = Berkeley Mono
    font-family-bold-italic = Berkeley Mono

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

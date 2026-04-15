{...}: {
  homebrew.masApps = {
    "Keynote" = 361285480;
    "Klack" = 6446206067;
    "Xcode" = 497799835;
  };

  homebrew.casks = [
    # Core
    "1password"
    "ghostty"
    "google-chrome"
    "raycast"

    # Dev
    "claude"
    "ngrok"
    "db-browser-for-sqlite"
    "cursor"
    "docker-desktop"
    "figma"
    "foxglove"
    "quarto"
    "sublime-text"
    "yaak"

    # Communication
    "discord"
    "signal"
    "slack"
    "whatsapp"
    "zoom"

    # Productivity
    "chatgpt"
    "granola"
    "linear-linear"
    "memo"
    "notion"
    # voiceink — managed via voiceink-overlay (nix, not brew)
    "zotero"

    # Utilities
    "hammerspoon"
    "mullvad-vpn"
    "atomic-wallet"
    "balenaetcher"
    "cleanshot"
    "logi-options+"
    # "ollama-app" # using CLI-only ollama from packages.nix
    "raspberry-pi-imager"
    "stats"
    "hiddenbar"
  ];
}

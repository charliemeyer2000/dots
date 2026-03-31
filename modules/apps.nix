{...}: {
  homebrew.masApps = {
    "Keynote" = 409183694;
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
    "wispr-flow"

    # Utilities
    "hammerspoon"
    "mullvad-vpn"
    "atomic-wallet"
    "balenaetcher"
    "cleanshot"
    "logi-options+"
    "ollama-app"
    "raspberry-pi-imager"
    "stats"
  ];
}

{...}: {
  # System defaults
  system.defaults = {
    dock.autohide = true;
    dock.show-recents = false;
    NSGlobalDomain.KeyRepeat = 2;
    NSGlobalDomain.InitialKeyRepeat = 15;
    NSGlobalDomain.ApplePressAndHoldEnabled = false;
    screencapture.location = "~/Desktop/screenshots";
  };

  # TouchID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Tailscale
  services.tailscale.enable = true;

  # Homebrew (managed by nix-darwin)
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };
    taps = [
      "hashicorp/tap"
      "derailed/k9s"
      "stripe/stripe-cli"
      "withgraphite/tap"
      "ekristen/tap"
      "steipete/tap"
    ];
    brews = [
      # Tap-only tools
      "hashicorp/tap/terraform"
      "derailed/k9s/k9s"
      "stripe/stripe-cli/stripe"
      "withgraphite/tap/graphite"
      "ekristen/tap/aws-nuke"
      "steipete/tap/gifgrep"
      "steipete/tap/imsg"
      "steipete/tap/mcporter"
      "steipete/tap/oracle"
      "steipete/tap/peekaboo"
      "steipete/tap/remindctl"
      "steipete/tap/summarize"

      # C++ / robotics dev libs
      "asio"
      "assimp"
      "bison"
      "boost-python3"
      "bullet"
      "console_bridge"
      "cunit"
      "libpq"
      "opencv"
      "pcre"
      "poco"
      "poppler"
      "pyqt@5"
      "rapidjson"
      "sip"
      "spdlog"

      # Hardware / embedded
      "open-ocd"
      "stlink"
      "qemu"

      # macOS dev tools
      "swiftformat"
      "swiftlint"
      "xcodegen"

      # CLI tools (brew-only or easier via brew)
      "gogcli"
      "groff"
      "kube-ps1"
      "mcap"
      "netcat"
      "sshpass"
      "worktrunk"
    ];
  };
}

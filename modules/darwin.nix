{...}: {
  system.defaults = {
    dock.autohide = true;
    dock.show-recents = false;
    NSGlobalDomain.KeyRepeat = 2;
    NSGlobalDomain.InitialKeyRepeat = 15;
    NSGlobalDomain.ApplePressAndHoldEnabled = false;
    screencapture.location = "~/Desktop/screenshots";
  };

  security.pam.services.sudo_local.touchIdAuth = true;
  services.tailscale.enable = true;

  homebrew = {
    enable = true; # Nix manages Homebrew - auto-installs on fresh machine
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

      # ROS2 dependencies
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

      # Embedded tools
      "open-ocd"
      "stlink"
      "qemu"

      # Swift tools
      "swiftformat"
      "swiftlint"
      "xcodegen"

      # Other utilities
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

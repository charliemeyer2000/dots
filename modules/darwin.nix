{...}: {
  # ── Xcode CLT (silent install if missing) ───────────────────────────
  # Uses pkgutil (not xcode-select -p, which points to nix SDK on nix-darwin).
  # The touch trick makes softwareupdate list CLT even if it normally wouldn't.
  # Tested on macOS Sequoia/Tahoe — grep parses "Label: Command Line Tools..." format.
  system.activationScripts.preActivation.text = ''
    if ! /usr/sbin/pkgutil --pkg-info=com.apple.pkg.CLTools_Executables &>/dev/null; then
      echo "Installing Xcode Command Line Tools (this may take a few minutes)..."
      /usr/bin/touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
      CLT_LABEL=$(/usr/sbin/softwareupdate -l 2>&1 | /usr/bin/grep -o "Label: Command Line Tools.*" | /usr/bin/sed 's/Label: //' | /usr/bin/tail -1)
      if [ -n "$CLT_LABEL" ]; then
        /usr/sbin/softwareupdate -i "$CLT_LABEL"
        echo "  -> Xcode CLT installed"
      else
        echo "  -> Xcode CLT not found in softwareupdate catalog"
        echo "  -> Falling back to GUI installer..."
        /usr/bin/xcode-select --install 2>/dev/null || true
        echo "  -> Complete the GUI prompt, then re-run: just switch darwin-personal"
      fi
      /bin/rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    fi
  '';

  # ── Dock ────────────────────────────────────────────────────────────
  system.defaults.dock = {
    autohide = true;
    show-recents = false;
    tilesize = 61;
    minimize-to-application = true;
    mineffect = "scale";
    mru-spaces = false; # don't rearrange spaces based on recent use
    show-process-indicators = true;
    launchanim = false;
    wvous-br-corner = 14; # bottom-right hot corner: Quick Note
  };

  # ── Finder ──────────────────────────────────────────────────────────
  system.defaults.finder = {
    FXPreferredViewStyle = "Nlsv"; # list view
    FXDefaultSearchScope = "SCcf"; # search current folder
    AppleShowAllExtensions = true;
    ShowPathbar = true;
    ShowStatusBar = true;
    _FXSortFoldersFirst = true;
    _FXShowPosixPathInTitle = true;
    FXEnableExtensionChangeWarning = false;
    FXRemoveOldTrashItems = true; # empty trash after 30 days
    QuitMenuItem = true; # allow Cmd+Q
    ShowExternalHardDrivesOnDesktop = true;
    ShowHardDrivesOnDesktop = false;
    ShowRemovableMediaOnDesktop = true;
  };

  # ── Global preferences ─────────────────────────────────────────────
  system.defaults.NSGlobalDomain = {
    # Keyboard
    KeyRepeat = 2;
    InitialKeyRepeat = 15;
    ApplePressAndHoldEnabled = false;

    # Disable auto-correct suite
    NSAutomaticCapitalizationEnabled = false;
    NSAutomaticSpellingCorrectionEnabled = false;
    NSAutomaticDashSubstitutionEnabled = false;
    NSAutomaticQuoteSubstitutionEnabled = false;
    NSAutomaticPeriodSubstitutionEnabled = false;
    NSAutomaticInlinePredictionEnabled = false;

    # Expand save/print dialogs by default
    NSNavPanelExpandedStateForSaveMode = true;
    NSNavPanelExpandedStateForSaveMode2 = true;
    PMPrintingExpandedStateForPrint = true;
    PMPrintingExpandedStateForPrint2 = true;

    # Save to disk by default, not iCloud
    NSDocumentSaveNewDocumentsToCloud = false;

    # Show file extensions everywhere
    AppleShowAllExtensions = true;

    # Faster window resize
    NSWindowResizeTime = 0.001;

    # Spring-loading directories
    "com.apple.springing.enabled" = true;
    "com.apple.springing.delay" = 0.5;
  };

  # ── Screenshot ──────────────────────────────────────────────────────
  system.defaults.screencapture = {
    location = "~/Desktop/screenshots";
    type = "png";
    disable-shadow = true;
  };

  # ── Screensaver ─────────────────────────────────────────────────────
  system.defaults.screensaver = {
    askForPassword = true;
    askForPasswordDelay = 0;
  };

  # ── Menu bar clock ──────────────────────────────────────────────────
  system.defaults.menuExtraClock = {
    ShowAMPM = true;
    ShowDate = 0;
    ShowDayOfWeek = true;
  };

  # ── Control Center ──────────────────────────────────────────────────
  system.defaults.controlcenter = {
    BatteryShowPercentage = true;
  };

  # ── Login window ────────────────────────────────────────────────────
  system.defaults.loginwindow = {
    GuestEnabled = false;
  };

  # ── Window Manager ──────────────────────────────────────────────────
  system.defaults.WindowManager = {
    EnableStandardClickToShowDesktop = false; # don't hide windows clicking desktop
  };

  # ── Software Update ─────────────────────────────────────────────────
  system.defaults.SoftwareUpdate = {
    AutomaticallyInstallMacOSUpdates = false;
  };

  # ── Launch Services ─────────────────────────────────────────────────
  system.defaults.LaunchServices = {
    LSQuarantine = false; # disable "downloaded from internet" quarantine
  };

  # ── Keyboard ────────────────────────────────────────────────────────
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # ── Startup ─────────────────────────────────────────────────────────
  system.startup.chime = false;

  # ── Power ───────────────────────────────────────────────────────────
  power.sleep = {
    display = "never";
    computer = "never";
  };

  # ── Security ────────────────────────────────────────────────────────
  security.pam.services.sudo_local.touchIdAuth = true;

  # ── Login items (open at login) ──────────────────────────────────────
  launchd.user.agents = {
    open-chrome = {
      serviceConfig = {
        Program = "/usr/bin/open";
        ProgramArguments = ["/usr/bin/open" "-a" "Google Chrome"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
    open-raycast = {
      serviceConfig = {
        Program = "/usr/bin/open";
        ProgramArguments = ["/usr/bin/open" "-a" "Raycast"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
    open-stats = {
      serviceConfig = {
        Program = "/usr/bin/open";
        ProgramArguments = ["/usr/bin/open" "-a" "Stats"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
    open-claude = {
      serviceConfig = {
        Program = "/usr/bin/open";
        ProgramArguments = ["/usr/bin/open" "-a" "Claude"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
    open-ghostty = {
      serviceConfig = {
        Program = "/usr/bin/open";
        ProgramArguments = ["/usr/bin/open" "-a" "Ghostty"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
    open-cleanshot = {
      serviceConfig = {
        Program = "/usr/bin/open";
        ProgramArguments = ["/usr/bin/open" "-a" "CleanShot X"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
    open-granola = {
      serviceConfig = {
        Program = "/usr/bin/open";
        ProgramArguments = ["/usr/bin/open" "-a" "Granola"];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
  };

  # ── Services ────────────────────────────────────────────────────────
  services.tailscale.enable = true;

  # ── Homebrew ────────────────────────────────────────────────────────
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };
    taps = [
      "cirruslabs/cli"
      "hashicorp/tap"
      "derailed/k9s"
      "stripe/stripe-cli"
      "withgraphite/tap"
      "ekristen/tap"
      "steipete/tap"
    ];
    brews = [
      "cirruslabs/cli/tart"
      "mas"
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

      # Embedded tools
      "open-ocd"
      "stlink"
      "qemu"

      # Swift tools
      "swiftformat"
      "swiftlint"
      "xcodegen"

      # ROS2 Jazzy build deps
      "asio"
      "assimp"
      "bison"
      "bullet"
      "console_bridge"
      "cunit"
      "eigen"
      "log4cxx"
      "opencv"
      "openssl"
      "orocos-kdl"
      "pcre"
      "poco"
      "pyqt@5"
      "qt@5"
      "sip"
      "spdlog"
      "tinyxml2"

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

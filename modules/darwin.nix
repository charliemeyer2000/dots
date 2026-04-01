{
  lib,
  config,
  ...
}: let
  user = config.system.primaryUser;
  loginApps = [
    "Google Chrome"
    "Raycast"
    "Stats"
    "Claude"
    "Ghostty"
    "CleanShot X"
    "Granola"
    "Hammerspoon"
  ];
in {
  # ── Pre-activation: TCC, Homebrew dirs, Xcode CLT ─────────────────
  system.activationScripts.preActivation.text = ''
    # Grant TCC permissions programmatically (requires SIP disabled)
    TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"
    grant_tcc() {
      local service="$1" bundle="$2" app_path="$3"
      if [ ! -f "$TCC_DB" ] || [ ! -d "$app_path" ]; then return; fi
      CSREQ_TMP=$(/usr/bin/mktemp /tmp/tcc_csreq.XXXXXX)
      /usr/bin/codesign -dr - "$app_path" 2>&1 | /usr/bin/sed 's/^designated => //' | /usr/bin/csreq -r- -b "$CSREQ_TMP" 2>/dev/null || true
      if [ -s "$CSREQ_TMP" ]; then
        CSREQ_HEX=$(/usr/bin/xxd -p "$CSREQ_TMP" | /usr/bin/tr -d '\n')
        /usr/bin/sqlite3 "$TCC_DB" "DELETE FROM access WHERE client = '$bundle' AND service = '$service';" 2>/dev/null || true
        /usr/bin/sqlite3 "$TCC_DB" "INSERT INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, boot_uuid) VALUES ('$service', '$bundle', 0, 2, 3, 1, X'$CSREQ_HEX', 'UNUSED', 0, 'UNUSED');" 2>/dev/null && \
          echo "  -> $(basename "$app_path") $service granted" || \
          echo "  -> TCC grant failed for $(basename "$app_path") (SIP may be enabled)"
      fi
      /bin/rm -f "$CSREQ_TMP"
    }

    # Accessibility
    grant_tcc kTCCServiceAccessibility org.hammerspoon.Hammerspoon "/Applications/Hammerspoon.app"
    grant_tcc kTCCServiceAccessibility com.anthropic.claudefordesktop "/Applications/Claude.app"
    grant_tcc kTCCServiceAccessibility com.raycast.macos "/Applications/Raycast.app"
    grant_tcc kTCCServiceAccessibility eu.exelban.Stats "/Applications/Stats.app"
    grant_tcc kTCCServiceAccessibility com.electron.wispr-flow "/Applications/Wispr Flow.app"
    grant_tcc kTCCServiceAccessibility com.hnc.Discord "/Applications/Discord.app"
    grant_tcc kTCCServiceAccessibility us.zoom.xos "/Applications/zoom.us.app"
    grant_tcc kTCCServiceAccessibility com.logitech.Logi-Options "/Applications/Logi Options.app"
    grant_tcc kTCCServiceAccessibility com.logi.cp-dev-mgr "/Library/Application Support/Logitech.localized/LogiOptionsPlus/logioptionsplus_agent.app"
    grant_tcc kTCCServiceAccessibility com.henrikruscon.Klack "/Applications/Klack.app"
    grant_tcc kTCCServiceAccessibility com.mitchellh.ghostty "/Applications/Ghostty.app"

    # Input monitoring
    grant_tcc kTCCServiceListenEvent com.logi.cp-dev-mgr "/Library/Application Support/Logitech.localized/LogiOptionsPlus/logioptionsplus_agent.app"
    grant_tcc kTCCServiceListenEvent com.logitech.manager.daemon "/Applications/Logi Options.app/Contents/Support/LogiMgrDaemon.app"
    grant_tcc kTCCServiceListenEvent com.logitech.Logi-Options "/Applications/Logi Options.app"
    grant_tcc kTCCServiceListenEvent com.hnc.Discord "/Applications/Discord.app"
    grant_tcc kTCCServiceListenEvent pl.maketheweb.cleanshotx "/Applications/CleanShot X.app"
    grant_tcc kTCCServicePostEvent com.henrikruscon.Klack "/Applications/Klack.app"

    # Screen capture
    grant_tcc kTCCServiceScreenCapture pl.maketheweb.cleanshotx "/Applications/CleanShot X.app"
    grant_tcc kTCCServiceScreenCapture com.anthropic.claudefordesktop "/Applications/Claude.app"
    grant_tcc kTCCServiceScreenCapture com.mitchellh.ghostty "/Applications/Ghostty.app"
    grant_tcc kTCCServiceScreenCapture com.google.Chrome "/Applications/Google Chrome.app"
    grant_tcc kTCCServiceScreenCapture com.hnc.Discord "/Applications/Discord.app"
    grant_tcc kTCCServiceScreenCapture com.tinyspeck.slackmacgap "/Applications/Slack.app"
    grant_tcc kTCCServiceScreenCapture us.zoom.xos "/Applications/zoom.us.app"

    # Full disk access
    grant_tcc kTCCServiceSystemPolicyAllFiles com.mitchellh.ghostty "/Applications/Ghostty.app"

    # User-level TCC permissions (microphone, bluetooth, audio capture)
    USER_TCC_DB="/Users/${user}/Library/Application Support/com.apple.TCC/TCC.db"
    grant_user_tcc() {
      local service="$1" bundle="$2" app_path="$3" indirect_obj="''${4:-UNUSED}"
      if [ ! -f "$USER_TCC_DB" ] || [ ! -d "$app_path" ]; then return; fi
      CSREQ_TMP=$(/usr/bin/mktemp /tmp/tcc_csreq.XXXXXX)
      /usr/bin/codesign -dr - "$app_path" 2>&1 | /usr/bin/sed 's/^designated => //' | /usr/bin/csreq -r- -b "$CSREQ_TMP" 2>/dev/null || true
      if [ -s "$CSREQ_TMP" ]; then
        CSREQ_HEX=$(/usr/bin/xxd -p "$CSREQ_TMP" | /usr/bin/tr -d '\n')
        sudo -u ${user} /usr/bin/sqlite3 "$USER_TCC_DB" "DELETE FROM access WHERE client = '$bundle' AND service = '$service';" 2>/dev/null || true
        sudo -u ${user} /usr/bin/sqlite3 "$USER_TCC_DB" "INSERT INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, boot_uuid) VALUES ('$service', '$bundle', 0, 2, 3, 1, X'$CSREQ_HEX', '$indirect_obj', 0, 'UNUSED');" 2>/dev/null && \
          echo "  -> $(basename "$app_path") $service granted (user)" || \
          echo "  -> User TCC grant failed for $(basename "$app_path")"
      fi
      /bin/rm -f "$CSREQ_TMP"
    }

    # Microphone
    grant_user_tcc kTCCServiceMicrophone com.electron.wispr-flow "/Applications/Wispr Flow.app"
    grant_user_tcc kTCCServiceMicrophone com.granola.app "/Applications/Granola.app"
    grant_user_tcc kTCCServiceMicrophone com.google.Chrome "/Applications/Google Chrome.app"
    grant_user_tcc kTCCServiceMicrophone com.hnc.Discord "/Applications/Discord.app"
    grant_user_tcc kTCCServiceMicrophone com.tinyspeck.slackmacgap "/Applications/Slack.app"
    grant_user_tcc kTCCServiceMicrophone us.zoom.xos "/Applications/zoom.us.app"
    grant_user_tcc kTCCServiceMicrophone org.whispersystems.signal-desktop "/Applications/Signal.app"
    grant_user_tcc kTCCServiceMicrophone pl.maketheweb.cleanshotx "/Applications/CleanShot X.app"
    grant_user_tcc kTCCServiceMicrophone com.todesktop.230313mzl4w4u92 "/Applications/Cursor.app"

    # Camera
    grant_user_tcc kTCCServiceCamera com.google.Chrome "/Applications/Google Chrome.app"
    grant_user_tcc kTCCServiceCamera com.hnc.Discord "/Applications/Discord.app"
    grant_user_tcc kTCCServiceCamera com.tinyspeck.slackmacgap "/Applications/Slack.app"
    grant_user_tcc kTCCServiceCamera us.zoom.xos "/Applications/zoom.us.app"
    grant_user_tcc kTCCServiceCamera org.whispersystems.signal-desktop "/Applications/Signal.app"

    # Audio capture
    grant_user_tcc kTCCServiceAudioCapture com.granola.app "/Applications/Granola.app"

    # Bluetooth
    grant_user_tcc kTCCServiceBluetoothAlways com.logi.cp-dev-mgr "/Library/Application Support/Logitech.localized/LogiOptionsPlus/logioptionsplus_agent.app"
    grant_user_tcc kTCCServiceBluetoothAlways eu.exelban.Stats "/Applications/Stats.app"
    grant_user_tcc kTCCServiceBluetoothAlways com.google.Chrome "/Applications/Google Chrome.app"
    grant_user_tcc kTCCServiceBluetoothAlways com.mitchellh.ghostty "/Applications/Ghostty.app"
    grant_user_tcc kTCCServiceBluetoothAlways com.openai.atlas "/Applications/ChatGPT Atlas.app"
    grant_user_tcc kTCCServiceBluetoothAlways us.zoom.xos "/Applications/zoom.us.app"

    # Automation (Apple Events)
    grant_user_tcc kTCCServiceAppleEvents com.mitchellh.ghostty "/Applications/Ghostty.app" com.apple.MobileSMS

    # File/folder access
    grant_user_tcc kTCCServiceSystemPolicyDownloadsFolder com.mitchellh.ghostty "/Applications/Ghostty.app"
    grant_user_tcc kTCCServiceSystemPolicyDocumentsFolder com.logi.cp-dev-mgr "/Library/Application Support/Logitech.localized/LogiOptionsPlus/logioptionsplus_agent.app"
    grant_user_tcc kTCCServiceSystemPolicyRemovableVolumes io.balena.etcher "/Applications/balenaEtcher.app"
    grant_user_tcc kTCCServiceSystemPolicyDocumentsFolder com.raspberrypi.rpi-imager "/Applications/Raspberry Pi Imager.app"
    grant_user_tcc kTCCServiceSystemPolicyRemovableVolumes com.raspberrypi.rpi-imager "/Applications/Raspberry Pi Imager.app"

    # Fix Homebrew prefix directories that may have wrong ownership
    # NOTE: $USER is root during activation (runs via sudo), so we use the configured primaryUser
    /bin/mkdir -p /opt/homebrew/var/log /opt/homebrew/var/run
    /usr/sbin/chown -R ${user}:admin /opt/homebrew/var/log /opt/homebrew/var/run

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
    minimize-to-application = false;
    mineffect = "genie";
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

  # ── Global keyboard shortcuts ──────────────────────────────────
  system.defaults.CustomUserPreferences.NSGlobalDomain = {
    NSUserKeyEquivalents = {
      Zoom = "~`";
    };
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
    AirDrop = false;
    Display = false;
    FocusModes = false;
    NowPlaying = false;
    Sound = false;
    Bluetooth = false;
  };

  # ── Menu bar: Stats ────────────────────────────────────────────────
  system.defaults.CustomUserPreferences."eu.exelban.Stats" = {
    CPU_state = true;
    CPU_widget = "mini";
    RAM_state = true;
    RAM_widget = "mini";
    GPU_state = true;
    GPU_widget = "mini";
    Battery_state = true;
    Battery_widget = "battery";
    Network_state = false;
    Disk_state = false;
    Sensors_state = false;
    Bluetooth_state = false;
    Clock_state = false;
    dockIcon = 0;
    telemetry = 0;
  };

  # ── Menu bar: Hammerspoon ─────────────────────────────────────────
  system.defaults.CustomUserPreferences."org.hammerspoon.Hammerspoon" = {
    MJShowMenuIconKey = false;
  };

  # ── Menu bar: hide Zoom icon ─────────────────────────────────────
  system.defaults.CustomUserPreferences."ZoomChat" = {
    ZoomShowIconInMenuBar = false;
  };

  # ── Menu bar: hide Siri & Spotlight, restart Stats ─────────────────
  system.activationScripts.postActivation.text = ''
    sudo -u ${user} defaults write com.apple.Siri StatusMenuVisible -bool false
    sudo -u ${user} defaults write com.apple.Spotlight "NSStatusItem Visible Item-0" -bool false
    killall Stats 2>/dev/null && sudo -u ${user} open -a Stats || true
    killall SystemUIServer ControlCenter 2>/dev/null || true
    pmset -a standby 0 autopoweroff 0 hibernatemode 0 disablesleep 1
  '';

  # ── Privacy: disable Apple ad tracking ───────────────────────────────
  system.defaults.CustomUserPreferences."com.apple.AdLib" = {
    allowApplePersonalizedAdvertising = false;
    allowIdentifierForAdvertising = false;
    forceLimitAdTracking = true;
    personalizedAdsMigrated = false;
  };

  # ── Prevent .DS_Store on network/USB volumes ───────────────────────
  system.defaults.CustomUserPreferences."com.apple.desktopservices" = {
    DSDontWriteNetworkStores = true;
    DSDontWriteUSBStores = true;
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
    harddisk = "never";
    allowSleepByPowerButton = false;
  };
  power.restartAfterFreeze = true;

  # ── Security ────────────────────────────────────────────────────────
  security.pam.services.sudo_local.touchIdAuth = true;

  # ── Login items (open at login) ──────────────────────────────────────
  launchd.user.agents = builtins.listToAttrs (map (app: {
      name = "open-${lib.strings.toLower (builtins.replaceStrings [" "] ["-"] app)}";
      value.serviceConfig = {
        Program = "/usr/bin/open";
        ProgramArguments = ["/usr/bin/open" "-a" app];
        RunAtLoad = true;
        KeepAlive = false;
      };
    })
    loginApps);

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

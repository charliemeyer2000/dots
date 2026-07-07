{
  lib,
  config,
  ...
}: let
  cfg = config.dots.tart;
  user = config.system.primaryUser;
in {
  options.dots.tart = {
    images = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["ghcr.io/cirruslabs/macos-sequoia-base:latest"];
      description = ''
        OCI VM images to pre-pull on rebuild. Each image is cloned with a
        local name derived from the image path (e.g. macos-sequoia-base)
        if not already present.
      '';
    };

    headlessKeychain = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Create and unlock a login keychain on activation. Required for
        headless machines running macOS 15+ where Virtualization.Framework
        refuses to start VMs without an unlocked login.keychain.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.images != []) {
      system.activationScripts.tartPullImages.text = let
        pullScript = lib.concatMapStringsSep "\n" (image: let
          # Derive local VM name from image: ghcr.io/cirruslabs/macos-sequoia-base:latest → macos-sequoia-base
          localName = builtins.head (lib.splitString ":" (lib.last (lib.splitString "/" image)));
        in ''
          if ! sudo -u ${user} /opt/homebrew/bin/tart list 2>/dev/null | grep -q "^${localName} "; then
            echo "  -> Pre-pulling Tart image: ${image} as ${localName}"
            sudo -u ${user} /opt/homebrew/bin/tart clone "${image}" "${localName}" || \
              echo "  -> Failed to pull ${image} (network may be unavailable)"
          else
            echo "  -> Tart image already present: ${localName}"
          fi
        '') cfg.images;
      in ''
        echo "Ensuring Tart VM images are available..."
        ${pullScript}
      '';
    })

    (lib.mkIf cfg.headlessKeychain {
      # Unlock login keychain on activation — required for Virtualization.Framework
      # on macOS 15+ headless machines (no GUI login session).
      system.activationScripts.tartHeadlessKeychain.text = ''
        echo "Ensuring login keychain is available for Tart (headless)..."
        KEYCHAIN_PATH="/Users/${user}/Library/Keychains/login.keychain-db"
        if [ ! -f "$KEYCHAIN_PATH" ]; then
          echo "  -> Creating login keychain..."
          sudo -u ${user} security create-keychain -p "" login.keychain
        fi
        sudo -u ${user} security unlock-keychain -p "" login.keychain 2>/dev/null || \
          echo "  -> Could not unlock login keychain (may need manual login)"
        sudo -u ${user} security login-keychain -s login.keychain
        echo "  -> login.keychain ready"
      '';

      # launchd agent to keep keychain unlocked across reboots
      launchd.user.agents.tart-keychain-unlock = {
        serviceConfig = {
          Label = "com.charliemeyer.tart-keychain-unlock";
          Program = "/usr/bin/security";
          ProgramArguments = ["/usr/bin/security" "unlock-keychain" "-p" "" "login.keychain"];
          RunAtLoad = true;
          KeepAlive = false;
        };
      };
    })
  ];
}

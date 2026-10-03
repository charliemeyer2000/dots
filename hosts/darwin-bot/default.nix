{pkgs, ...}: {
  # Mac mini — Charlie's Bot on iMessage (life-infra services/imessage-bot), always on.
  # A dedicated machine with a dedicated Apple Account, so the bot runs as `charlie`; the only
  # thing it must never see is ANTHROPIC_API_KEY (Claude Max login via Keychain instead).
  # Shared darwin config lives in ../_darwin-common.nix.
  networking.hostName = "charlie-mini";
  networking.computerName = "Charlie's Bot";
  networking.localHostName = "charlie-mini";

  dots.tart.headlessKeychain = true;
  # A LaunchAgent (and Messages.app, which imsg drives) only exists inside a logged-in session, so
  # an unattended reboot must log `charlie` straight back in. This sets the loginwindow preference;
  # macOS honours it only after the one-time System Settings → Users & Groups → Automatic login
  # toggle has written /etc/kcpassword (needs FileVault *off*) — day-one runbook step 1.
  system.defaults.loginwindow.autoLoginUser = "charlie";
  # imsg converts voice notes (CAF → m4a) for the model with ffmpeg; imsg itself is in darwin.nix's brews.
  environment.systemPackages = [pkgs.ffmpeg];
  dots.tailscale.tag = "tag:agent";
  dots.tailscale.clientRef = "op://Developer/Tailscale/oauth-client-secret-agent";

  # Headless box: see and drive it over the tailnet — Screen Sharing (`open vnc://charlie-mini`
  # from a Mac, any VNC client from the phone) and SSH. Both are only reachable through Tailscale
  # (policy.hujson grants tag:agent to Charlie's devices), and a HDMI dummy plug keeps the GPU
  # rendering at a usable resolution with no monitor attached.
  system.activationScripts.postActivation.text = ''
    /bin/launchctl enable system/com.apple.screensharing 2>/dev/null || true
    /bin/launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
    /usr/sbin/systemsetup -setremotelogin on >/dev/null 2>&1 || true
    /usr/bin/pmset -a sleep 0 displaysleep 10 disksleep 0 autorestart 1 >/dev/null 2>&1 || true
  '';

  home-manager.users.charlie.dots.agents.claude.autoMemoryDirectory = "~/all/life/agents/memory";
  home-manager.users.charlie.dots.agents.instructions.host =
    builtins.readFile ../../config/agents/hosts/darwin-bot.md;
  home-manager.users.charlie.dots.agents.mcp.catalog =
    (import ../../home/mcp-servers.nix)
    // (import ../../home/mcp-servers-personal.nix);

  dots.onePassword.extraEnv = {
    LIFE_MCP_API_KEY = "op://Developer/Life MCP/darwin-bot";
    # Charlie's own handles, comma-separated: the only senders answered and the only recipients.
    IMSG_ALLOWED_RECIPIENTS = "op://Developer/iMessage Bot/recipients";
  };

  # The bot: one process = `imsg rpc` child + inbound Claude Agent SDK loop + outbound MCP on the
  # tailnet (8765). Sources ~/.env.local for the two keys above and drops ANTHROPIC_API_KEY so the
  # SDK's `claude` uses the Max login. Exits when imsg dies; KeepAlive brings it back.
  launchd.user.agents.imessage-bot = {
    serviceConfig = {
      Label = "com.charliemeyer.imessage-bot";
      ProgramArguments = [
        "/bin/zsh"
        "-c"
        ''
          set -a; source "$HOME/.env.local"; set +a
          unset ANTHROPIC_API_KEY
          export IMSG_HOST="$(tailscale ip -4)" IMSG_PORT=8765
          export BOT_CWD="$HOME/all/life" BOT_PROFILE="$HOME/all/life/agents/bot"
          export BOT_TRANSCRIPTS="$HOME/all/life/agents/comms/imessage/transcripts"
          export BOT_MODEL=claude-opus-5-5 BOT_EFFORT=max
          exec uv run --directory "$HOME/all/life-infra" imessage-bot
        ''
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      StandardOutPath = "/Users/charlie/Library/Logs/imessage-bot.log";
      StandardErrorPath = "/Users/charlie/Library/Logs/imessage-bot.log";
      # Nix (uv, tailscale) + Homebrew (imsg); launchd's default PATH has neither.
      EnvironmentVariables.PATH = "/etc/profiles/per-user/charlie/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
    };
  };
}

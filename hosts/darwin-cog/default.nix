{...}: {
  # Cognition work MacBook.
  # Shared darwin config lives in ../_darwin-common.nix.
  networking.hostName = "charlie-cog-laptop";
  networking.computerName = "Charlie's Cognition Laptop";
  networking.localHostName = "charlie-cog-laptop";

  # zoom/1password/figma/notion: IT-managed (Iru, formerly Kandji, via .pkg).
  # mullvad-vpn/atomic-wallet/ngrok: personal or IT-unfriendly tooling — keep
  # off the work machine.
  dots.homebrew.excludeCasks = ["zoom" "1password" "figma" "notion" "mullvad-vpn" "atomic-wallet" "ngrok"];

  # Personal-tailnet Tailscale stays off the work machine too (no tailscaled
  # daemon or app; secrets.nix skips the OAuth auth).
  dots.tailscale.client = null;

  # Work machine — don't inject personal API keys into ~/.env.local
  # (`op read` secrets on demand).
  dots.onePassword.injectEnv = false;

  # Keep Gatekeeper's download quarantine on the work machine
  # (the fleet default in darwin.nix disables it for convenience).
  system.defaults.LaunchServices.LSQuarantine = true;

  home-manager.users.charlie.dots.agents.instructions.host =
    builtins.readFile ../../config/agents/hosts/darwin-cog.md;

  # work-only MCP servers
  home-manager.users.charlie.dots.agents.mcp.catalog =
    (import ../../home/mcp-servers.nix)
    // {
      metabase = {
        type = "http";
        url = "https://metabase.devin.info/api/metabase-mcp";
      };
      notion = {
        type = "http";
        url = "https://mcp.notion.com/mcp";
      };
      slack = {
        type = "http";
        url = "https://mcp.slack.com/mcp";
      };
    };
}

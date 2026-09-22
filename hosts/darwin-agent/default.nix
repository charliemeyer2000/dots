{...}: {
  # M1 Pro MacBook Pro — always-on agent host.
  # Shared darwin config lives in ../_darwin-common.nix.
  networking.hostName = "charlie-m1pro";
  networking.computerName = "Charlie's M1 Pro";
  networking.localHostName = "charlie-m1pro";

  # Headless: unlock login keychain on boot so Virtualization.Framework works
  # without a GUI login session (required macOS 15+).
  dots.tart.headlessKeychain = true;

  # Obsidian: the shared life vault (synced via Remotely Save), see the `life` skill.
  dots.homebrew.extraCasks = ["obsidian"];
  home-manager.users.charlie.dots.agents.claude.autoMemoryDirectory = "~/all/life/agents/memory";

  home-manager.users.charlie.dots.agents.instructions.host =
    builtins.readFile ../../config/agents/hosts/darwin-agent.md;

  # personal-project MCP servers; this Mac's own Executor API key for `life`
  home-manager.users.charlie.dots.agents.mcp.catalog =
    (import ../../home/mcp-servers.nix)
    // (import ../../home/mcp-servers-personal.nix);
  dots.onePassword.extraEnv.LIFE_MCP_API_KEY = "op://Developer/Life MCP/darwin-agent";
}

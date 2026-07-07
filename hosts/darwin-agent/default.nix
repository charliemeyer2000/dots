{...}: {
  # M1 Pro MacBook Pro — always-on agent host.
  # Shared darwin config lives in ../_darwin-common.nix.
  networking.hostName = "charlie-m1pro";
  networking.computerName = "Charlie's M1 Pro";
  networking.localHostName = "charlie-m1pro";

  # Headless: unlock login keychain on boot so Virtualization.Framework works
  # without a GUI login session (required macOS 15+).
  dots.tart.headlessKeychain = true;

  home-manager.users.charlie.dots.agents.instructions.host =
    builtins.readFile ../../config/agents/hosts/darwin-agent.md;

  # personal-project MCP servers
  home-manager.users.charlie.dots.agents.mcp.catalog =
    (import ../../home/mcp-servers.nix)
    // (import ../../home/mcp-servers-personal.nix);
}

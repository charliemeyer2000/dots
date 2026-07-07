{...}: {
  # M4 Pro MacBook Pro — daily driver.
  # Shared darwin config lives in ../_darwin-common.nix.
  networking.hostName = "charlie-m4pro";
  networking.computerName = "Charlie's M4 Pro";
  networking.localHostName = "charlie-m4pro";

  # Dolphin emulator for offline SSBM mods (20XX, UnclePunch Training Mode).
  # Slippi Launcher itself is a one-off install (self-updating, no cask exists).
  dots.homebrew.extraCasks = ["dolphin"];

  home-manager.users.charlie.dots.agents.instructions.host =
    builtins.readFile ../../config/agents/hosts/darwin-personal.md;

  # personal-project MCP servers
  home-manager.users.charlie.dots.agents.mcp.catalog =
    (import ../../home/mcp-servers.nix)
    // (import ../../home/mcp-servers-personal.nix);
}

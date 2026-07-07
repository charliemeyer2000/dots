{...}: {
  # Cognition work MacBook.
  # Shared darwin config lives in ../_darwin-common.nix.
  networking.hostName = "charlie-cog-laptop";
  networking.computerName = "Charlie's Cognition Laptop";
  networking.localHostName = "charlie-cog-laptop";

  # IT-managed apps
  dots.homebrew.excludeCasks = ["zoom"];

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
    };
}

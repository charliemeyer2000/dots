{
  config,
  pkgs,
  lib,
  ...
}: let
  homeDir = config.home.homeDirectory;
  jq = "${pkgs.jq}/bin/jq";
  jsonFormat = pkgs.formats.json {};

  # ── MCP servers (single source of truth) ─────────────────────
  # Shared across all coding CLIs. Add new servers here.
  sharedMcpServers = {
    chrome-devtools = {
      command = "npx";
      args = ["chrome-devtools-mcp@latest" "--channel" "stable"];
    };
  };

  # Devin-only servers (agent-specific integrations)
  devinExtraMcpServers = {
    datadog = {
      transport = "http";
      url = "https://mcp.us3.datadoghq.com/api/unstable/mcp-server/mcp";
    };
  };

  # ── Generated configs ────────────────────────────────────────
  devinConfig = {
    read_config_from = {
      claude = true;
      cursor = false;
      windsurf = false;
    };
    agent.model = "claude-opus-4-8-max";
    mcpServers = sharedMcpServers // devinExtraMcpServers;
  };

  sharedMcpJson = builtins.toJSON sharedMcpServers;
in {
  home.file.".agents/AGENTS.md".source = ../config/agents/AGENTS.md;
  home.file.".agents/skills" = {
    source = ../config/agents/skills;
    recursive = true;
  };

  # ── Claude Code ──────────────────────────────────────────────
  home.file.".claude/settings.json".source = ../config/claude/settings.json;

  home.file.".claude/statusline.sh" = {
    source = ../config/claude/statusline.sh;
    executable = true;
  };

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDir}/.agents/AGENTS.md";
  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDir}/.agents/skills";

  # ~/.claude.json is mutable (runtime state like numStartups, tipsHistory, etc.),
  # so we merge sharedMcpServers in rather than overwriting the whole file.
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter ["writeBoundary"] ''
    CLAUDE_JSON="${homeDir}/.claude.json"
    if [ -f "$CLAUDE_JSON" ]; then
      ${jq} --argjson servers '${sharedMcpJson}' \
        '.mcpServers = (.mcpServers // {}) * $servers' \
        "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
      echo "  -> Merged MCP servers into ~/.claude.json"
    else
      echo '{"mcpServers":${sharedMcpJson}}' | ${jq} . > "$CLAUDE_JSON"
      echo "  -> Created ~/.claude.json with MCP servers"
    fi
  '';

  # ── Devin CLI ────────────────────────────────────────────────
  home.file.".config/devin/config.json" = {
    source = jsonFormat.generate "devin-config.json" devinConfig;
    force = true;
  };
  home.file.".config/devin/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDir}/.agents/skills";
}

{
  config,
  pkgs,
  lib,
  ...
}: let
  homeDir = config.home.homeDirectory;
  jq = "${pkgs.jq}/bin/jq";
  cfg = config.dots.agents.mcp;

  # Catalog entries use Claude's dialect as-is; Devin calls the transport key `transport`.
  toDevin = _: srv:
    if srv ? type
    then (builtins.removeAttrs srv ["type"]) // {transport = srv.type;}
    else srv;

  select = sel:
    if sel == null
    then cfg.catalog
    else lib.getAttrs sel cfg.catalog;

  claudeMcpJson = builtins.toJSON (select cfg.claude);
  devinConfigJson = builtins.toJSON {
    agent.model = "claude-opus-4-8-max";
    read_config_from = {
      claude = true;
      cursor = false;
      windsurf = false;
    };
    mcpServers = lib.mapAttrs toDevin (select cfg.devin);
  };
in {
  options.dots.agents.mcp = {
    catalog = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = import ./mcp-servers.nix;
      description = "Agent-neutral MCP server catalog shared across coding agents; extend per host for machine-specific servers.";
    };
    claude = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = ["exa" "chrome-devtools"];
      description = "Catalog servers enabled for Claude Code (null = all, [] = none).";
    };
    devin = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = ["exa" "datadog"];
      description = "Catalog servers enabled for the Devin CLI (null = all, [] = none).";
    };
  };

  config = {
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

    # ~/.claude.json holds mutable runtime state, so merge managed servers in
    # rather than overwriting; `+` keeps catalog servers authoritative while
    # preserving any added out-of-band (e.g. `claude mcp add`).
    home.activation.claudeMcpServers = lib.hm.dag.entryAfter ["writeBoundary"] ''
      CLAUDE_JSON="${homeDir}/.claude.json"
      if [ -f "$CLAUDE_JSON" ]; then
        ${jq} --argjson servers '${claudeMcpJson}' \
          '.mcpServers = ((.mcpServers // {}) + $servers)' \
          "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
      else
        echo '{"mcpServers":${claudeMcpJson}}' | ${jq} . > "$CLAUDE_JSON"
      fi
    '';

    # ── Devin CLI ────────────────────────────────────────────────
    # Devin rewrites config.json at runtime, so merge instead of symlinking —
    # a forced symlink gets clobbered and the managed servers dropped.
    home.activation.devinConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      DEVIN_JSON="${homeDir}/.config/devin/config.json"
      mkdir -p "$(dirname "$DEVIN_JSON")"
      if [ -f "$DEVIN_JSON" ]; then
        ${jq} --argjson cfg '${devinConfigJson}' '
          .agent = ((.agent // {}) * $cfg.agent)
          | .read_config_from = ((.read_config_from // {}) * $cfg.read_config_from)
          | .mcpServers = ((.mcpServers // {}) + $cfg.mcpServers)
        ' "$DEVIN_JSON" > "$DEVIN_JSON.tmp" && mv "$DEVIN_JSON.tmp" "$DEVIN_JSON"
      else
        echo '${devinConfigJson}' | ${jq} . > "$DEVIN_JSON"
      fi
    '';

    home.file.".config/devin/skills".source =
      config.lib.file.mkOutOfStoreSymlink "${homeDir}/.agents/skills";
  };
}

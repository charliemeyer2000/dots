{
  config,
  pkgs,
  lib,
  ...
}: let
  homeDir = config.home.homeDirectory;
  jq = "${pkgs.jq}/bin/jq";
  cfg = config.dots.agents.mcp;
  instr = config.dots.agents.instructions;

  inherit (pkgs.stdenv) isDarwin;

  # Devin Desktop bundles its own (often older) "Devin Local" agent which, by
  # default, shares ~/.local/share/devin/cli/sessions.db with the standalone
  # CLI. Two different builds writing one WAL database corrupts it ("database
  # disk image is malformed"), so point Desktop's bundled agent at its own XDG
  # data dir. The terminal CLI keeps the default store, so its history is
  # untouched; the two simply no longer share one sessions.db.
  desktopAgentEnv = {
    "devin-cli".XDG_DATA_HOME = "${homeDir}/.local/share/devin-desktop";
  };
  desktopAgentEnvJson = builtins.toJSON desktopAgentEnv;
  desktopSettingsJson = builtins.toJSON {"devin.acp.agentEnv" = desktopAgentEnv;};

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
    agent.model = "claude-5-fable-max";
    read_config_from = {
      claude = true;
      cursor = false;
      windsurf = false;
    };
    mcpServers = lib.mapAttrs toDevin (select cfg.devin);
  };
in {
  options.dots.agents = {
    mcp = {
      catalog = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
        default = import ./mcp-servers.nix;
        description = "Agent-neutral MCP server catalog shared across coding agents; extend per host for machine-specific servers.";
      };
      claude = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        example = ["exa" "linear"];
        description = "Catalog servers enabled for Claude Code (null = all, [] = none).";
      };
      devin = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        example = ["exa" "datadog"];
        description = "Catalog servers enabled for the Devin CLI (null = all, [] = none).";
      };
    };

    # Shared base + per-host add-on, concatenated into ~/.agents/AGENTS.md
    # (which Claude reads via the CLAUDE.md symlink and Devin via read_config_from).
    instructions = {
      base = lib.mkOption {
        type = lib.types.lines;
        default = builtins.readFile ../config/agents/AGENTS.md;
        description = "Shared, host-agnostic agent instructions (base of ~/.agents/AGENTS.md).";
      };
      host = lib.mkOption {
        type = lib.types.lines;
        default = "";
        example = lib.literalExpression "builtins.readFile ../../config/agents/hosts/darwin-personal.md";
        description = "Host-specific agent instructions appended to the shared base.";
      };
    };
  };

  config = {
    home.file.".agents/AGENTS.md".text =
      instr.base + lib.optionalString (instr.host != "") ("\n" + instr.host);
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
    # preserving any added out-of-band (e.g. `claude mcp add`). Merge is additive:
    # removing a catalog server needs a one-time manual prune of the live JSON.
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

    # ── Devin Desktop (macOS only) ───────────────────────────────
    # Isolate Desktop's bundled "Devin Local" agent onto its own data dir so it
    # stops sharing — and corrupting — the standalone CLI's sessions.db. Desktop
    # rewrites User/settings.json at runtime, so merge instead of symlinking.
    home.activation.devinDesktopIsolation = lib.mkIf isDarwin (lib.hm.dag.entryAfter ["writeBoundary"] ''
      SETTINGS="${homeDir}/Library/Application Support/devin/User/settings.json"
      if [ -f "$SETTINGS" ]; then
        ${jq} --argjson v '${desktopAgentEnvJson}' \
          '.["devin.acp.agentEnv"] = ((.["devin.acp.agentEnv"] // {}) + $v)' \
          "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
      else
        mkdir -p "$(dirname "$SETTINGS")"
        echo '${desktopSettingsJson}' | ${jq} . > "$SETTINGS"
      fi
    '');
  };
}

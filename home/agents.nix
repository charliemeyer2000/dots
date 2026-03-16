{config, ...}: {
  # Canonical agent config at ~/.agents/ (agent-agnostic)
  home.file.".agents/AGENTS.md".source = ../config/agents/AGENTS.md;
  home.file.".agents/skills" = {
    source = ../config/agents/skills;
    recursive = true;
  };

  # Claude-specific settings
  home.file.".claude/settings.json".source = ../config/claude/settings.json;

  # Claude hooks
  home.file.".claude/hooks/docs-session-end.sh" = {
    source = ../config/claude/hooks/docs-session-end.sh;
    executable = true;
  };

  # Symlink Claude paths → agent paths
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/AGENTS.md";
  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
}

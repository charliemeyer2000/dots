{config, ...}: {
  home.file.".agents/AGENTS.md".source = ../config/agents/AGENTS.md;
  home.file.".agents/skills" = {
    source = ../config/agents/skills;
    recursive = true;
  };

  home.file.".claude/settings.json".source = ../config/claude/settings.json;

  home.file.".claude/hooks/docs-session-end.sh" = {
    source = ../config/claude/hooks/docs-session-end.sh;
    executable = true;
  };

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/AGENTS.md";
  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
}

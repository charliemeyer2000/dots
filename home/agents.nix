{config, ...}: {
  home.file.".agents/AGENTS.md".source = ../config/agents/AGENTS.md;
  home.file.".agents/skills" = {
    source = ../config/agents/skills;
    recursive = true;
  };

  # Claude Code
  home.file.".claude/settings.json".source = ../config/claude/settings.json;

  home.file.".claude/statusline.sh" = {
    source = ../config/claude/statusline.sh;
    executable = true;
  };

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/AGENTS.md";
  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";

  # Devin CLI
  home.file.".config/devin/config.json" = {
    source = ../config/devin/config.json;
    force = true;
  };
  home.file.".config/devin/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
}

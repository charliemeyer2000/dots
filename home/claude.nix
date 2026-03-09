{...}: {
  home.file.".claude/settings.json".source = ../config/claude/settings.json;
  home.file.".claude/CLAUDE.md".source = ../config/claude/CLAUDE.md;
  home.file.".claude/skills" = {
    source = ../config/claude/skills;
    recursive = true;
  };
}

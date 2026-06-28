{...}: {
  # M4 Pro MacBook Pro — daily driver.
  # Shared darwin config lives in ../_darwin-common.nix.
  networking.hostName = "charlie-m4pro";
  networking.computerName = "Charlie's M4 Pro";
  networking.localHostName = "charlie-m4pro";

  home-manager.users.charlie.dots.agents.instructions.host =
    builtins.readFile ../../config/agents/hosts/darwin-personal.md;
}

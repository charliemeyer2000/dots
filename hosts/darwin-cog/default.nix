{...}: {
  # Cognition work MacBook.
  # Shared darwin config lives in ../_darwin-common.nix.
  networking.hostName = "charlie-cog-laptop";
  networking.computerName = "Charlie's Cognition Laptop";
  networking.localHostName = "charlie-cog-laptop";

  # IT-managed apps — keep brew bundle from fighting the IT-installed copy.
  dots.homebrew.excludeCasks = ["zoom"];

  home-manager.users.charlie.dots.agents.instructions.host =
    builtins.readFile ../../config/agents/hosts/darwin-cog.md;
}

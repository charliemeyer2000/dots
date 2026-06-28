## This machine: darwin-cog

- **Cognition work MacBook.** Rebuild: `just switch darwin-cog`.
- Zoom is IT-managed (excluded from Homebrew via `dots.homebrew.excludeCasks`) — don't try to install or manage it through nix, and some tooling here is managed by IT outside nix; prefer leaving IT-managed apps alone rather than fighting them with `brew`/`nix`.
- For secrets, we have 1password via cli and/or aws (look in ~/.aws/config for profiles). 

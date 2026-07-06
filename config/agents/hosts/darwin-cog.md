## This machine: darwin-cog

- **Cognition work MacBook.** Rebuild: `just switch darwin-cog`.
- Zoom is IT-managed (excluded from Homebrew via `dots.homebrew.excludeCasks`) — don't try to install or manage it through nix, and some tooling here is managed by IT outside nix; prefer leaving IT-managed apps alone rather than fighting them with `brew`/`nix`.
- For secrets, we have 1password via cli and/or aws (look in ~/.aws/config for profiles). Secrets are injected via 1Password `op inject` at activation.
- macOS: `sudo` prompts for TouchID. Commits are signed with the 1Password SSH key (`commit.gpgsign = true`); if signing hangs non-interactively, use `git -c commit.gpgsign=false commit`.

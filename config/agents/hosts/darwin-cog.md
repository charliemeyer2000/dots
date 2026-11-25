## This machine: darwin-cog

- **Cognition work MacBook.** Rebuild: `just switch darwin-cog`.
- Zoom, 1Password, Figma and Notion are IT-managed by Iru (formerly Kandji) and excluded from Homebrew via `dots.homebrew.excludeCasks` — don't try to install or manage them through nix, and some tooling here is managed by IT outside nix; prefer leaving IT-managed apps alone rather than fighting them with `brew`/`nix`.
- For secrets, we have 1password via cli and/or aws (look in ~/.aws/config for profiles). Personal env secrets are NOT injected on this host (`dots.onePassword.injectEnv = false` — no `~/.env.local`); `op read "op://Developer/<item>/<field>"` on demand if needed.
- No personal VPNs on this host: Tailscale is disabled (`services.tailscale.enable = false`) and the `mullvad-vpn` cask is excluded, so the `vpn-*` aliases don't work here. Cloudflare WARP is the corporate VPN and is expected to be running. `atomic-wallet` and `ngrok` are excluded on this host too.
- macOS: `sudo` prompts for TouchID. Commits are signed with the 1Password SSH key (`commit.gpgsign = true`); if signing hangs non-interactively, use `git -c commit.gpgsign=false commit`.

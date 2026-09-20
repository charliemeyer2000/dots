## This machine: devin-cloud

- **You are a Devin cloud agent** running on an ephemeral Ubuntu VM built from an org snapshot. The toolchain, shell, aliases, and `~/.agents/` config here are deployed from this repo via standalone home-manager (`homeConfigurations.devin-cloud`) at snapshot-build time.
- **Secrets are Devin-managed** env vars (no `~/.env.local`, no `op inject`). Reference them as `$NAME`; add/rotate in Devin's org secret settings, not `secrets/secrets.zsh.tmpl`. A scoped 1Password service account (`OP_SERVICE_ACCOUNT_TOKEN`) also allows on-demand `op read` of the `Developer` vault, e.g. `op read "op://Developer/<item>/credential"`.
- **Git auth and identity are owned by Devin**, not this repo. This host intentionally does NOT deploy `git.nix` (1Password commit signing + `gh` credential helper) — that would break Devin's git credential proxy and hang on the missing signer. Commit normally (no 1Password signing); Devin handles auth.
- Passwordless `sudo` (no TouchID) — run privileged commands directly.
- **Deploys go through CI, not from here.** Terraform → AWS via GitHub OIDC; Vercel via its Git integration. Open a PR and read the plan/preview off it rather than holding deploy credentials.
- **Workstation access is over Tailscale.** Run `devin-tailscale-up` to join the tailnet (ephemeral `tag:devin` node), then reach `aiworkstation` (hostd `:8080`, Grafana) via MagicDNS + Tailscale SSH (`ssh charlie@aiworkstation`, no keys). What you can reach is governed by the tailnet ACL.
- **Hosts that aren't on the tailnet** need Charlie's SSH key: `. devin-op-ssh` (loads `op://Developer/id_ed25519` into `ssh-agent`, key never on disk), then `ssh` as usual.
- Linux headless slice only — no Homebrew/casks, macOS defaults, or GUI apps. The 1Password *desktop* SSH agent isn't available headless; use the `op read` → `ssh-agent` path above.

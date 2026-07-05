## This machine: devin-cloud

- **You are a Devin cloud agent** running on an ephemeral Ubuntu VM built from an org snapshot. The toolchain, shell, aliases, and `~/.agents/` config here are deployed from this repo via standalone home-manager (`homeConfigurations.devin-cloud`) at snapshot-build time.
- **Secrets are Devin-managed**, injected as environment variables into every session — there is no `~/.env.local` and no 1Password on this box. Reference secrets as `$NAME`; add/rotate them in Devin's org secret settings, not `secrets/secrets.zsh.tmpl`.
- **Git auth and identity are owned by Devin**, not this repo. This host intentionally does NOT deploy `git.nix` (1Password commit signing + `gh` credential helper) — that would break Devin's git credential proxy and hang on the missing signer. Commit normally; Devin handles auth.
- **Deploys go through CI, not from here.** Terraform → AWS via GitHub OIDC; Vercel via its Git integration. Open a PR and read the plan/preview off it rather than holding deploy credentials.
- **Machine access is over Tailscale.** Run `devin-tailscale-up` to join the tailnet (ephemeral `tag:devin` node), then reach `workstation`/`do-droplet` via MagicDNS + Tailscale SSH (no keys). What you can reach is governed by the tailnet ACL.
- This host takes only the Linux, headless slice of the config — no Homebrew/casks, macOS defaults, GUI apps (ghostty/fonts), or 1Password SSH agent.

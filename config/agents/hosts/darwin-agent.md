## This machine: darwin-agent

- **M1 Pro MacBook Pro — always-on agent host.** Rebuild: `just switch darwin-agent`.
- This box is expected to stay up and run unattended/background agent work. Prefer durable, resumable workflows; avoid actions that need interactive babysitting or block on a prompt.
- Don't assume a human is watching — leave clear logs/state behind and fail loudly rather than silently waiting.
- macOS: `sudo` prompts for TouchID. Secrets are injected via 1Password `op inject` at activation. Commits are signed with the 1Password SSH key (`commit.gpgsign = true`); if signing hangs non-interactively, use `git -c commit.gpgsign=false commit`.
- Reachable hosts (see `~/.ssh/config`):
    - `workstation` — personal 5090 GPU box (32 CPU), over Tailscale. SSH in for GPU / training work.
    - `do-droplet` — DigitalOcean box (public IP).
- Like the other laptops, offload heavy GPU experiments to `workstation`.

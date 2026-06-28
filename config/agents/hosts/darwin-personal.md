## This machine: darwin-personal

- **M4 Pro MacBook Pro — your daily driver.** Rebuild: `just switch darwin-personal` (or `rebuild darwin-personal`).
- Personal 1Password account; the full personal secrets set is available here.
- Reachable hosts (see `~/.ssh/config`):
    - `workstation` — personal 5090 GPU box (32 CPU), over Tailscale. SSH in for GPU / training work.
    - `do-droplet` — DigitalOcean box (public IP).
- This is a laptop: offload heavy or long-running GPU experiments to `workstation`.

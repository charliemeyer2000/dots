## This machine: workstation

- **You ARE the Linux workstation — 5090 GPU, 32 CPU.** Rebuild: `just switch workstation` (standalone home-manager, *not* nix-darwin).
- No Homebrew/casks and no macOS defaults here. System-level concerns (GPU drivers, CUDA, k3s, networking) are Ubuntu-managed — don't try to manage them through nix.
- This is the box the laptops SSH *into* for GPU work, so run training/experiments **locally** here rather than offloading. Don't SSH into `workstation` — that's this machine.
- Secrets are injected via `home.activation` (standalone HM) rather than system activation scripts.
- Reachable hosts (see `~/.ssh/config`): `do-droplet` (public IP).

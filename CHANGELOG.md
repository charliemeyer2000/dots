# Changelog

## 2026-03-08 — Initial Setup

- Initialized flake-parts architecture with alejandra, deadnix, statix, shellcheck pre-commit hooks
- Added nix-darwin config for `darwin-personal` with home-manager integration
- Migrated git, zsh, direnv, ssh, fonts, and claude configs to home-manager
- Migrated ~50 brew packages to nix, keeping only tap-dependent ones in homebrew (terraform, k9s, stripe, graphite, qemu)
- Added darwin system defaults (dock, key repeat, TouchID sudo, Tailscale)
- Added homebrew cask management for GUI apps (ghostty, raycast, slack, notion, etc.)
- Added 1Password secrets injection via `op inject` activation scripts
- Added host configs for darwin-minimal, linux-ec2, linux-hpc
- Added CI workflows (flake check + darwin build) and bootstrap script
- Set homebrew `cleanup = "none"` — switch to `"zap"` once cask list is confirmed complete

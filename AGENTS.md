# dots - Charlie's Nix Configuration

Personal nix-darwin + home-manager configuration for macOS and Linux machines.

## Architecture

- **Nix flakes** with **flake-parts** for modular, reproducible builds
- **nix-darwin** for macOS system configuration
- **home-manager** for user-level dotfiles, programs, and file management
- **nix-homebrew** for declarative Homebrew/cask management on macOS
- **1Password CLI** for secrets injection at activation time (never committed)
- **Determinate Systems** manages the Nix daemon — all macOS hosts set `nix.enable = false`

## Repository Structure

```
dots/
├── flake.nix             # Flake entry point (inputs + flake-parts imports)
├── justfile              # Task runner commands
├── statix.toml           # Nix linter config (disables repeated_keys, empty_pattern)
├── AGENTS.md             # Project instructions (open standard)
├── CLAUDE.md → AGENTS.md # Symlink for Claude Code compatibility
├── config/
│   ├── agents/
│   │   ├── AGENTS.md     # Global agent instructions (deployed to ~/.agents/)
│   │   └── skills/       # Agent skills (wandb-monitor, skill-creator, etc.)
│   └── claude/
│       └── settings.json # Claude Code-specific settings (model, plugins)
├── home/                 # Home-manager modules
│   ├── default.nix       # Entry point — imports all modules below
│   ├── zsh.nix           # Shell: aliases, PATH, env vars, oh-my-zsh
│   ├── git.nix           # Git: 1Password SSH signing, gh credential helper
│   ├── ssh.nix           # SSH: hosts, 1Password agent, ControlMaster
│   ├── ghostty.nix       # Ghostty terminal: fonts, gruvbox theme, splits
│   ├── agents.nix        # Deploys config/agents/ → ~/.agents/, symlinks ~/.claude/
│   ├── fonts.nix         # Nerd fonts (JetBrainsMono, FiraCode)
│   └── direnv.nix        # direnv + nix-direnv for per-project shells
├── hosts/                # Machine-specific configurations
│   ├── darwin-personal/  # Full Mac: base + darwin + apps + secrets
│   ├── darwin-minimal/   # Lean Mac: base + darwin + secrets (no GUI casks)
│   ├── linux-ec2/        # EC2: base + secrets
│   └── linux-hpc/        # HPC: base only (no secrets on shared nodes)
├── modules/              # System-level modules
│   ├── base.nix          # Packages for all machines
│   ├── darwin.nix        # macOS defaults, TouchID sudo, Tailscale, Homebrew taps/brews
│   ├── apps.nix          # Homebrew casks (GUI apps, darwin-personal only)
│   └── secrets.nix       # 1Password op inject logic (macOS + Linux)
├── parts/                # Flake-parts modules
│   ├── hosts.nix         # Machine definitions + home-manager/nix-homebrew wiring
│   ├── formatter.nix     # alejandra (nix formatter)
│   ├── checks.nix        # Pre-commit hooks (alejandra, deadnix, statix, shellcheck)
│   └── devshell.nix      # Dev shell: alejandra, deadnix, statix, nil, just
├── scripts/              # Skill management scripts (skill-add.sh, skill-search.sh, etc.)
└── secrets/
    └── secrets.zsh.tmpl  # 1Password template → ~/.env.local
```

## Flake Inputs

| Input | Source | Purpose |
|-------|--------|---------|
| nixpkgs | nixpkgs-unstable | Rolling release packages |
| flake-parts | hercules-ci/flake-parts | Modular flake organization |
| nix-darwin | LnL7/nix-darwin | macOS system configuration |
| home-manager | nix-community/home-manager | User-level dotfiles |
| pre-commit-hooks | cachix/pre-commit-hooks.nix | Git hook framework |
| nix-homebrew | zhaofengli-wip/nix-homebrew | Declarative Homebrew on macOS |

All inputs follow the root nixpkgs for consistency.

## Key Concepts

### Dynamic Dots Directory
`just switch <config>` writes the repo path to `~/.config/dots/location`. On shell startup, zsh reads this into `$DOTS_DIR` (falls back to `~/all/dots`). All aliases and commands reference `$DOTS_DIR`.

### Secrets Management
- Template: `secrets/secrets.zsh.tmpl` references 1Password items via `{{ op://vault/item/field }}`
- On `just switch`, `op inject` fills the template → `~/.env.local` (mode 600)
- zsh sources `~/.env.local` on startup
- Exported keys: `GITHUB_TOKEN`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `HF_TOKEN`, `WANDB_API_KEY`
- Supports both 1Password service account token (CI) and desktop app (interactive)
- linux-hpc has no secrets module (shared nodes)

### Agent Configuration
Agent config is managed in a tool-agnostic way:
- Source of truth: `config/agents/` (AGENTS.md + skills/)
- Claude-specific settings: `config/claude/settings.json`
- Deployed to `~/.agents/` via home-manager (agents.nix)
- `~/.claude/CLAUDE.md` → `~/.agents/AGENTS.md` (symlink)
- `~/.claude/skills` → `~/.agents/skills` (symlink)
- Any AGENTS.md-compatible coding agent can read from `~/.agents/`
- Commands: `skill-add`, `skill-search`, `skill-list`, `skill-remove`
- Portable across all machines

### Host Composition

```
darwin-personal  = base + darwin + apps + secrets  (full setup)
darwin-minimal   = base + darwin + secrets         (no GUI casks)
linux-ec2        = base + secrets                  (cloud instance)
linux-hpc        = base                            (minimal, no secrets)
```

## Common Commands

Justfile commands:
- `just switch <config>` — Rebuild and apply (e.g., `just switch darwin-personal`)
- `just switch-dry <config>` — Preview build without applying
- `just check` — Run flake checks and linters
- `just fmt` — Format all nix files with alejandra
- `just dev` — Enter dev shell with nix tooling

Shell aliases (available after rebuild):
- `rebuild <config>` — Shorthand for `just switch`
- `dots` — cd to dots directory
- `cc` — `claude --dangerously-skip-permissions`
- `k` / `tf` — kubectl / terraform
- `killport <port>` — Kill process on a port
- `skill-add`, `skill-search`, `skill-list`, `skill-remove` — Skill management

Blocked aliases (enforce correct tooling):
- `npm` → error, use `pnpm`
- `pip` / `pip3` → error, use `uv`

## Packages & Language Runtimes (base.nix)

Installed on all machines:

- **CLI tools**: git, ripgrep, fd, fzf, jq, curl, wget, htop, bat, tmux, tree, zoxide, gh, gum, nmap, socat
- **Dev tools**: cmake, graphviz, pandoc, typst, pre-commit, ruff, cppcheck, just, direnv
- **Languages**: go, rustup, lua, nodejs_22, pnpm, bun, uv
- **AI**: claude-code
- **Infra**: awscli2, kubectl, kubernetes-helm, kind, colima, docker-client, docker-buildx, docker-compose, cloudflared, tailscale, redis
- **Secrets**: _1password-cli

Language management:
- **Node.js**: nix (nodejs_22) + pnpm
- **Python**: uv only (no system python3 — python comes as uv dependency)
- **Go**: nix
- **Rust**: rustup via nix
- **Lua**: nix

## macOS Configuration (darwin.nix)

- Dock: autohide, no recents
- Keyboard: fast repeat (KeyRepeat=2, InitialKeyRepeat=15), no press-and-hold
- Screenshots: saved to `~/Desktop/screenshots`
- TouchID for sudo
- Tailscale service enabled
- Homebrew taps: hashicorp, k9s, stripe, graphite, ekristen, steipete

## SSH Hosts (ssh.nix)

| Host | Address | User | Notes |
|------|---------|------|-------|
| workstation | 100.97.247.28 | charlie | Tailscale, personal 5090 workstation |
| jetson-nano | 100.95.16.119 | charlie | Tailscale, Jetson Orin Nano |
| uva-hpc | login.hpc.virginia.edu | abs6bd | ControlMaster multiplexing |
| do-droplet | 24.199.85.26 | root | DigitalOcean |

All SSH uses 1Password agent (`IdentityAgent` → 1Password socket).

## Testing & CI

- Pre-commit hooks: alejandra, deadnix, statix, shellcheck (only work inside `nix develop`)
- CI: GitHub Actions on push to main and all PRs
  - `nix flake check` + `nix fmt -- --check .`
  - Uses Determinate Systems nix-installer and magic-nix-cache

## Development Workflow

1. Edit nix files in the appropriate module
2. `just check` to lint
3. `just switch <config>` to apply (or `rebuild <config>`)
4. New machine: clone repo → `just switch <config>` → sign into 1Password

## Manual Setup Required

- 1Password: `op signin`
- Tailscale: `tailscale up`
- SSH keys: import to 1Password
- Mac App Store apps (Xcode, Keynote)
- Berkeley Mono font (paid, manual install to ~/Library/Fonts/)
- Apps without casks: Ollama, Klack, VESC Tool, UniFi, Logitech Options+

## Troubleshooting

### Nested Claude Code Sessions
`CLAUDECODE` is unset in zshrc. Open a new terminal if you see the nested session error.

### Secrets Not Loading
1. Sign into 1Password: `op signin`
2. Rebuild: `just switch <config>`
3. Verify `~/.env.local` exists and is sourced

### Pre-commit Hooks Failing
Hooks only work inside `nix develop`. Outside that context they may hang or fail to find binaries.

## Contributing

1. Follow existing patterns in the appropriate module
2. `just check` before committing
3. Conventional commits (feat:, fix:, chore:, docs:)
4. Secrets in 1Password templates only — never commit actual values

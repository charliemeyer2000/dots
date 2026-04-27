# dots - Charlie's Nix Configuration

Personal nix-darwin + home-manager configuration for macOS and Linux machines. Uses nix-darwin for macOS system config and standalone home-manager for Linux workstations (no NixOS).

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
│   ├── claude/
│   │   ├── settings.json # Claude Code-specific settings (model, plugins)
│   │   └── statusline.sh # Claude Code statusline script
│   └── devin/
│       └── config.json   # Devin CLI config (reads from claude, shares skills)
├── home/                 # Home-manager modules
│   ├── default.nix       # Entry point — imports all modules below
│   ├── zsh.nix           # Shell: aliases, PATH, env vars, oh-my-zsh
│   ├── git.nix           # Git: 1Password SSH signing, gh credential helper
│   ├── ssh.nix           # SSH: hosts, 1Password agent, ControlMaster
│   ├── ghostty.nix       # Ghostty terminal: fonts, gruvbox theme, splits
│   ├── agents.nix        # Deploys config/agents/ → ~/.agents/, symlinks ~/.claude/ + ~/.config/devin/
│   ├── fonts.nix         # Nerd fonts (JetBrainsMono, FiraCode)
│   ├── direnv.nix        # direnv + nix-direnv for per-project shells
│   └── hammerspoon.nix   # Hammerspoon window management (macOS)
├── hosts/                # Machine-specific configurations
│   ├── _darwin-common.nix # Shared base for all darwin hosts (imports + user + nix.enable + stateVersion)
│   ├── darwin-personal/  # M4 Pro MacBook Pro: only host-unique networking attrs
│   ├── darwin-agent/     # M1 Pro MacBook Pro (always-on agent): only host-unique attrs
│   ├── darwin-cog/       # Cognition work MacBook: excludes IT-managed casks (zoom)
│   └── workstation/      # Linux workstation: standalone home-manager + secrets
├── modules/              # System-level modules
│   ├── packages.nix      # Shared package list (used by base.nix and workstation)
│   ├── base.nix          # System packages (wraps packages.nix for nix-darwin)
│   ├── darwin.nix        # macOS defaults, TouchID sudo, Tailscale, Homebrew taps/brews
│   ├── apps.nix          # Shared base list of Homebrew casks + dots.homebrew.{excludeCasks,extraCasks} options
│   ├── secrets.nix       # 1Password op inject + Tailscale OAuth auth (nix-darwin)
│   └── hm-secrets.nix    # 1Password op inject via home.activation (standalone HM)
├── parts/                # Flake-parts modules
│   ├── hosts.nix         # mkDarwin helper + darwinHosts list + workstation HM config
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
| claude-code-overlay | sadjow/claude-code-nix | Nix overlay for Claude Code CLI (official Anthropic binaries) |
| devin-cli-overlay | charliemeyer2000/devin-cli-overlay | Nix overlay for Devin CLI |
| uvacompute | uvacompute.com/nix/flake.tar.gz | UVACompute CLI |
| rv | charliemeyer2000/rivanna.dev | rv CLI — GPU job submission on Rivanna/Afton HPC |
| vimessage | charliemeyer2000/vimessage | Vim hotkeys for Messages.app (home-manager module) |

All inputs follow the root nixpkgs for consistency.

## Key Concepts

### Dynamic Dots Directory
`just switch <config>` writes the repo path to `~/.config/dots/location`. On shell startup, zsh reads this into `$DOTS_DIR` (falls back to `~/all/dots`). All aliases and commands reference `$DOTS_DIR`.

### Secrets Management
- Template: `secrets/secrets.zsh.tmpl` references 1Password items via `{{ op://vault/item/field }}`
- On rebuild (`just switch`), `op inject` fills the template → `~/.env.local` (mode 600)
- zsh sources `~/.env.local` on startup
- Exported keys: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `HF_TOKEN`, `WANDB_API_KEY`, `AXIOM_API_KEY`, `TAILSCALE_OAUTH_CLIENT_SECRET`, `MULLVAD_ACCOUNT_NUMBER`, `DOCKER_PAT`, `EXA_API_KEY`, `OPENROUTER_API_KEY`, `ALPACA_PAPER_KEY_ID`, `ALPACA_PAPER_SECRET_KEY`
- `GITHUB_TOKEN` is intentionally NOT auto-exported. `gh` falls back to its OAuth keyring (works with orgs that ban classic PATs). For ad-hoc use, the `gh-pat` zsh function fetches the PAT from 1Password on demand: `GITHUB_TOKEN=$(gh-pat) some-tool`.
- Supports both 1Password service account token (CI) and desktop app (interactive)
- Workstation uses `home.activation` instead of `system.activationScripts` (standalone HM)
- Multi-account: `dots.onePassword.account` (default `"my.1password.com"`) is passed as `op --account <value>` in the desktop-app path so vault lookups disambiguate when both personal and work 1Password accounts are signed in. Service-account auth ignores it (the token already identifies the account). Override per-host if a machine should resolve secrets against a different account.

### Python via uv
- No system python3 in base.nix — uv manages all Python versions
- `uv run` / `uv sync` auto-download the required Python for a project
- For ad-hoc use: `uv python install 3.13` then `uv run python script.py`
- On macOS, `python3` may exist from Homebrew transitive dependencies — do not rely on it

### Tailscale Authentication
- Tailscale authenticates automatically on `just switch` via OAuth client credentials
- OAuth client secret (never expires) stored in 1Password, injected at activation time
- Devices authenticate with `tag:shared` (required for OAuth-based auth)
- `tailscale up` is idempotent — re-auths if node key expired, no-op if current
- No manual `tailscale up` needed on new machines (just sign into 1Password first)

### Mullvad VPN
- Two Mullvad integrations: Tailscale exit nodes (primary) and standalone Mullvad VPN app (fallback)
- Tailscale + Mullvad exit nodes route traffic through Mullvad servers natively — no separate app needed
- Standalone Mullvad VPN conflicts with Tailscale on macOS (aggressive firewall rules drop Tailscale traffic)
- Mullvad is **not** auto-configured during rebuild — use shell aliases for manual control
- Shell aliases: `vpn-on`, `vpn-off`, `vpn-status`, `vpn-us`, `vpn-uk`, `vpn-eu` (macOS only)
- Cloudflare WARP (installed as a cask) also runs a system-level tunnel — only run one VPN at a time (WARP, Mullvad, or Tailscale exit node) to avoid routing conflicts

### Agent Configuration
Agent config is managed in a tool-agnostic way:
- Source of truth: `config/agents/` (AGENTS.md + skills/)
- Claude-specific settings: `config/claude/settings.json`
- Devin-specific settings: `config/devin/config.json` (reads rules from claude config)
- Deployed to `~/.agents/` via home-manager (agents.nix)
- `~/.claude/CLAUDE.md` → `~/.agents/AGENTS.md` (symlink)
- `~/.claude/skills` → `~/.agents/skills` (symlink)
- `~/.config/devin/config.json` ← `config/devin/config.json` (copied)
- `~/.config/devin/skills` → `~/.agents/skills` (symlink)
- Any AGENTS.md-compatible coding agent can read from `~/.agents/`
- Commands: `skill-add`, `skill-search`, `skill-list`, `skill-remove`, `skill-browse`, `skill-install`
- Portable across all machines

### Host Composition

All darwin hosts share the same base — defined once in `hosts/_darwin-common.nix` (imports `base + darwin + apps + secrets`, sets `primaryUser`, `users.users.charlie`, `nix.enable = false`, `stateVersion`) and wired in via the `mkDarwin` helper in `parts/hosts.nix`. Each host's own `default.nix` only declares what's *different* (hostname, optional `dots.homebrew.*` overrides).

```
_darwin-common.nix = base + darwin + apps + secrets        (shared imports + defaults)

darwin-personal  = _darwin-common.nix + hostname           (nix-darwin, M4 Pro MacBook Pro)
darwin-agent     = _darwin-common.nix + hostname           (nix-darwin, M1 Pro MacBook Pro, always-on)
darwin-cog       = _darwin-common.nix + hostname + excludeCasks=["zoom"]  (Cognition work MacBook, IT manages Zoom)
workstation      = home + packages + hm-secrets            (standalone home-manager, Ubuntu 24.04)
```

Adding a new darwin host is a 2-step diff: create `hosts/<name>/default.nix` with at minimum `networking.hostName`, then append `"<name>"` to the `darwinHosts` list in `parts/hosts.nix`.

The workstation host uses standalone home-manager (not NixOS) to manage dotfiles and CLI packages on Ubuntu. System-level concerns (GPU drivers, k3s, networking) remain Ubuntu-managed.

## Common Commands

Justfile commands:
- `just switch <config>` — Rebuild and apply (auto-detects darwin-rebuild vs home-manager)
- `just switch-dry <config>` — Preview build without applying
- `just check` — Run flake checks and linters
- `just fmt` — Format all nix files with alejandra
- `just dev` — Enter dev shell with nix tooling
- `just skill-add <repo> <skill>` — Add a skill from a GitHub repo
- `just skill-search <repo>` — Search for skills in a GitHub repo
- `just skill-list` — List installed skills
- `just skill-remove <skill>` — Remove a skill
- `just skill-browse` — Open skills.sh in browser
- `just skill-install <repo> <skill> <config>` — Add a skill and rebuild

Shell aliases (available after rebuild):
- `rebuild <config>` — Shorthand for `just switch`
- `dots` — cd to dots directory
- `cc` — `claude --dangerously-skip-permissions`
- `dv` — `devin --permission-mode bypass`
- `k` / `tf` — kubectl / terraform
- `killport <port>` — Kill process on a port
- `gh-pat` — Print GitHub PAT from 1Password (e.g. `GITHUB_TOKEN=$(gh-pat) some-tool`)
- `skill-add`, `skill-search`, `skill-list`, `skill-remove` — Skill management
- `skill-install`, `skill-browse`, `skills` — Install skills, browse skills.sh, list installed
- `surf <path>` — Open Windsurf at the given path (macOS only)
- `vpn-on` / `vpn-off` / `vpn-status` — Mullvad VPN manual control (macOS only)
- `vpn-us` / `vpn-uk` / `vpn-eu` — Connect Mullvad to specific regions (macOS only)

Blocked aliases (enforce correct tooling):
- `npm` → error, use `pnpm`
- `pip` / `pip3` → error, use `uv`

## Packages & Language Runtimes (packages.nix)

Shared across all machines (via `modules/packages.nix`):

- **CLI tools**: git, git-lfs, ripgrep, fd, fzf, jq, curl, wget, htop, bat, tmux, tree, zoxide, gh, gum, nmap, socat
- **Dev tools**: cmake, graphviz, pandoc, typst, pre-commit, ruff, cppcheck, just, direnv
- **Languages**: go, rustup, lua, nodejs_22, pnpm, bun, uv
- **AI/HPC**: claude-code (via claude-code-overlay), devin-cli (via devin-cli-overlay), uvacompute, rv (UVA Rivanna job submission CLI)
- **Infra**: awscli2, kubectl, kubernetes-helm, kind, docker-client, docker-buildx, docker-compose, cloudflared, tailscale, redis, postgresql, ollama, colima (macOS only)
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
- Homebrew taps: cirruslabs/cli, hashicorp, k9s, stripe, graphite, ekristen, steipete

### Per-Host Homebrew Casks

`modules/apps.nix` defines a shared base list of GUI casks plus two per-host options under `dots.homebrew`:

- `excludeCasks` — strings to drop from the base list (e.g. apps managed externally by IT). Applied last, so excludes always win.
- `extraCasks` — strings to add on top of the base list (e.g. work-only tooling).

Resolved as: `homebrew.casks = subtractLists excludeCasks (baseCasks ++ extraCasks)`.

Example (`hosts/darwin-cog/default.nix`):

```nix
dots.homebrew.excludeCasks = ["zoom"];
```

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
  - `check` job (ubuntu): `nix flake check` + `nix fmt -- --check .`
  - `build-darwin` job (macos): `nix build .#darwinConfigurations.darwin-personal.system` (only personal is built in CI; agent and cog share the same modules so they're covered transitively by `nix flake check`)
  - Uses Determinate Systems nix-installer and magic-nix-cache
  - Concurrency: stale PR runs cancelled automatically
- Dependabot: weekly auto-bumps for GitHub Actions versions

## Development Workflow

1. Edit nix files in the appropriate module
2. `just check` to lint
3. `just switch <config>` to apply — or `rebuild <config>`

## New Machine Bootstrap

### macOS (nix-darwin)

Requires two passes — first installs packages (including 1Password CLI), second injects secrets.

1. Install Nix: `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
2. Clone: `git clone https://github.com/charliemeyer2000/dots ~/all/dots && cd ~/all/dots`
3. First build: `sudo nix run nix-darwin -- switch --flake .#darwin-personal` (secrets fail gracefully)
4. Sign into 1Password desktop app, then `op signin`
5. Second build: `just switch darwin-personal` (secrets + Tailscale auth succeed)
6. **Log out and back in (or reboot)** — required on a fresh machine. macOS caches `NSGlobalDomain` prefs per-session, so keyboard repeat (`KeyRepeat`/`InitialKeyRepeat`), press-and-hold, scroll direction, and other global UI defaults won't take effect in the current session even though `defaults read -g KeyRepeat` shows the new value. Dock and Finder defaults *do* apply immediately because nix-darwin restarts those processes; everything reading from `NSGlobalDomain` needs a logout.

### Linux Workstation (standalone home-manager)

1. Install Nix: `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
2. Install 1Password GUI app (for SSH agent): add 1Password apt repo, `apt install 1password`
3. Clone: `git clone https://github.com/charliemeyer2000/dots ~/all/dots && cd ~/all/dots`
4. First run: `nix run home-manager -- switch --flake .#workstation -b bak` (secrets fail gracefully)
5. Sign into 1Password desktop app, then `op signin`
6. Second run: `just switch workstation` (secrets + Tailscale auth succeed)

## Manual Setup Required

Things that can't be nix-managed or don't transfer between machines. Grouped by category.

### Fresh macOS — one-time setup

Required once per new Mac for everything to work end-to-end:

- **Sign into the Mac App Store** — required to install Xcode, Keynote, and Klack manually (the `mas` brew-bundle integration is broken with `mas 6.0.1`, so `homebrew.masApps` is disabled in `apps.nix`).
- **Xcode Command Line Tools** — `modules/darwin.nix` activation script auto-installs these on first `darwin-rebuild`. If it fails (e.g. softwareupdate label drift), run `sudo xcode-select --install` manually.
- **Accept the Xcode license** — `sudo xcodebuild -license accept`. Required before any `xcodebuild` use (including some Homebrew formulas that build from source). Re-run after installing the full Xcode app.
- **Install full Xcode** *(only if doing iOS/macOS dev)* — install from the App Store, then re-run `sudo xcodebuild -license accept`.
- **Raycast hotkeys** — Raycast's cloud sync handles preferences/extensions, but the **global launch hotkey is per-machine** and must be re-bound manually under Raycast → Settings → General → Hotkey.
- **Log out / reboot** — see step 6 of the macOS bootstrap above; required for `NSGlobalDomain` defaults (keyboard repeat, press-and-hold, etc.) to take effect.

### App sign-ins (cloud-synced)

These apps have built-in sync — just sign in and configs follow:

- **1Password** — desktop app + CLI (`op signin`)
- **Raycast** — Settings → Accounts (then re-bind hotkeys manually, see above)
- **Cursor / Windsurf** — sign in to sync settings + extensions
- **Chrome** — sign in to sync extensions/bookmarks
- **Slack, Discord, Signal, WhatsApp** — sign in to each (Signal needs phone link)

### Hardware / external assets

- **SSH keys** — import to 1Password
- **UniFi iOS app on Mac** — `mas` can't install iOS-only apps; get from the macOS App Store manually
- **VESC Tool** — direct download from vesc-project.com (not in nixpkgs or homebrew)
- **Berkeley Mono font** (paid, not in nix) — manual install to `~/Library/Fonts/`

## Troubleshooting

### Nested Claude Code Sessions
`CLAUDECODE` is unset in zshrc. Open a new terminal if you see the nested session error.

### Secrets Not Loading
1. Sign into 1Password: `op signin`
2. Rebuild: `just switch <config>`
3. Verify `~/.env.local` exists and is sourced

### Brew Bundle Failures
`brew bundle` may report failure due to transient cask download errors (e.g. ngrok, claude). Successfully installed packages are unaffected. Re-run `just switch` to retry failed casks.

### Pre-commit Hooks Failing
Hooks only work inside `nix develop`. Outside that context they may hang or fail to find binaries.

## Contributing

1. Follow existing patterns in the appropriate module
2. `just check` before committing
3. Conventional commits (feat:, fix:, chore:, docs:)
4. Secrets in 1Password templates only — never commit actual values

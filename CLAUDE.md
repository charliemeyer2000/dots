# dots - Charlie's Nix Configuration

This is Charlie's personal nix-darwin + home-manager configuration for macOS and Linux machines.

## Architecture

- **Nix flakes** for reproducible builds and dependency management
- **nix-darwin** for macOS system configuration
- **home-manager** for user-level dotfiles and applications
- **1Password CLI** for secrets management (injected at activation time, never committed)

## Repository Structure

```
dots/
├── config/           # Static configuration files
│   ├── claude/       # Claude Code settings and skills
│   └── ...
├── home/             # Home-manager modules
│   ├── default.nix   # Entry point that imports all modules
│   ├── zsh.nix       # Shell config, aliases, PATH management
│   ├── git.nix       # Git config with 1Password SSH signing
│   ├── ghostty.nix   # Terminal emulator config
│   └── ...
├── hosts/            # Machine-specific configurations
│   ├── darwin-personal/   # Personal Mac
│   ├── darwin-minimal/    # Work Mac or minimal setup
│   ├── linux-ec2/         # AWS EC2 instances
│   └── linux-hpc/         # HPC cluster nodes
├── modules/          # System modules
│   ├── base.nix      # Core packages for all machines
│   ├── darwin.nix    # macOS-specific settings
│   ├── apps.nix      # GUI apps via Homebrew casks
│   ├── secrets.nix   # 1Password injection logic
│   └── ros2.nix      # ROS2 development environment
├── parts/            # Flake-parts modules
├── scripts/          # Helper scripts
│   ├── skill-*.sh    # Skill management scripts
│   └── ros2-*.sh     # ROS2 setup scripts
├── secrets/          # 1Password templates (safe to commit)
├── flake.nix         # Flake entry point
├── justfile          # Task runner commands
└── statix.toml       # Nix linter config
```

## Key Concepts

### Dynamic Dots Directory
The dots directory location is stored in `~/.config/dots/location` when running `just switch`. This allows the configuration to work regardless of where the repo is cloned. All aliases and commands use `$DOTS_DIR` which reads this file on shell startup.

### Secrets Management
Secrets are managed via 1Password CLI (`op`):
- Templates in `secrets/` reference 1Password items
- On `just switch`, secrets are injected to `~/.env.local` if signed in
- The `.env.local` file is sourced in zsh for environment variables
- Never commit actual secrets - only templates

### Skills Management
Claude Code skills are managed declaratively:
- Stored in `config/claude/skills/`
- Deployed to `~/.claude/skills/` via home-manager
- Commands: `skill-add`, `skill-search`, `skill-list`, `skill-remove`
- Skills are portable across all machines

## Common Commands

All commands are in the `justfile`:

- `just switch` - Rebuild and apply configuration (stores dots location)
- `just check` - Run flake checks and linters
- `just fmt` - Format all nix files
- `just dev` - Enter development shell
- `just ros2` - Enter ROS2 development shell

Aliases available after rebuild:
- `rebuild` - Shorthand for `just switch`
- `dots` - cd to dots directory
- `cc` - Claude Code without permissions prompt
- `skill-*` - Skill management commands

## Development Workflow

1. **Making changes**: Edit nix files in appropriate module
2. **Check syntax**: `just check` runs linters
3. **Apply changes**: `just switch` or `rebuild`
4. **New machine**: Clone repo, run `just switch`, sign into 1Password

## Machine Configurations

- **darwin-personal**: Full setup with GUI apps, dev tools, secrets
- **darwin-minimal**: Core tools and secrets, no GUI apps
- **linux-ec2**: Linux cloud instances with secrets
- **linux-hpc**: Shared HPC nodes without secrets

## Important Files

### home/zsh.nix
Shell configuration with:
- Aliases for common commands
- PATH management
- CLAUDECODE unset (prevents nested sessions)
- Dynamic DOTS_DIR loading

### modules/secrets.nix
1Password integration that:
- Checks for service account token or desktop app
- Injects secrets on activation if authenticated
- Handles both macOS and Linux paths

### modules/base.nix
Core packages installed everywhere:
- Development tools (git, ripgrep, fd, etc.)
- Language runtimes (Go, Rust, Python, Node.js)
- Cloud tools (AWS CLI, Terraform, kubectl)

### modules/darwin.nix
macOS-specific configuration:
- System defaults (dock, keyboard, screenshots)
- TouchID for sudo
- Tailscale service
- Homebrew packages and taps

## Language/Tool Management

- **Node.js**: Managed by nix (nodejs_22)
- **Python**: System python3 + uv for project management
- **Go**: Installed via nix
- **Rust**: rustup managed by nix
- **ROS2**: Built from source in `~/ros2_jazzy/`

## Testing & CI

- Pre-commit hooks via `pre-commit-hooks.nix`
- Formatters: alejandra (nix), shellcheck (bash)
- Linters: deadnix (unused code), statix (antipatterns)
- CI runs on every push via GitHub Actions

## Manual Setup Required

Some things can't be automated:
- 1Password: Sign in with `op signin`
- Tailscale: Authenticate with `tailscale up`
- SSH keys: Import to 1Password
- Mac App Store apps: Install manually
- ROS2: Requires SIP disabled on macOS

## Troubleshooting

### Nested Claude Code Sessions
If you see "Claude Code cannot be launched inside another Claude Code session":
- The fix is already applied - `CLAUDECODE` is unset in zshrc
- Open a new terminal to apply

### Secrets Not Loading
- Ensure 1Password is signed in: `op signin`
- Run `just switch` to re-inject secrets
- Check `~/.env.local` exists and is sourced

### Skill Commands Not Found
- Run `rebuild` to apply latest aliases
- Skills require dots directory to be set correctly

## Contributing

When making changes:
1. Follow existing patterns in the appropriate module
2. Run `just check` before committing
3. Use conventional commits (feat:, fix:, chore:)
4. Keep secrets in 1Password templates only
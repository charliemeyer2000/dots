# dots

my personal nix-darwin + home-manager configuration for macOS and Linux machines.

## bootstrap

### macOS

```bash
# 1. install nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. clone this repo (xcode git works, or: nix shell nixpkgs#git)
git clone https://github.com/charliemeyer2000/dots ~/all/dots
cd ~/all/dots

# 3. first build — bootstraps nix-darwin, homebrew, all packages and apps
#    secrets will fail gracefully (1Password not signed in yet)
sudo nix run nix-darwin -- switch --flake .#darwin-personal

# 4. sign into 1Password (desktop app), then the CLI:
op signin

# 5. sign into Mac App Store (for Xcode, Keynote, Klack via mas)

# 6. second build — secrets, tailscale auth, and App Store apps
just switch darwin-personal
```

### linux workstation

```bash
# 1. install nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. install 1Password GUI app (for SSH agent)
# add 1Password apt repo, then: sudo apt install 1password

# 3. clone this repo
git clone https://github.com/charliemeyer2000/dots ~/all/dots
cd ~/all/dots

# 4. first build — secrets will fail gracefully (1Password not signed in yet)
nix run home-manager -- switch --flake .#workstation -b bak

# 5. sign into 1Password (desktop app), then the CLI:
op signin

# 6. second build — secrets + tailscale auth
just switch workstation
```

after bootstrap, open a new terminal. all aliases, secrets, and dotfiles are active.

## commands

```bash
just switch <config>         # rebuild and apply (auto-detects darwin vs home-manager)
just switch-dry <config>     # preview build without applying
just check                   # run flake checks + linters
just fmt                     # format all nix files
just dev                     # enter dev shell
```

aliases (available after rebuild):

```bash
rebuild <config>  # shorthand for just switch
dots              # cd to dots directory
cc                # claude --dangerously-skip-permissions
dv                # devin --permission-mode bypass
k                 # kubectl
tf                # terraform
killport <port>   # kill process on port
vpn-on / vpn-off  # mullvad manual control (macOS)
```

`npm`, `pip`, and `pip3` are aliased to errors — use `pnpm` and `uv` instead.

## agent configuration

agent config uses the [AGENTS.md](https://agents-md.org) open standard — source of truth is `config/agents/`, deployed to `~/.agents/` via `home/agents.nix`:

- `config/agents/AGENTS.md` → `~/.agents/AGENTS.md` (global instructions)
- `config/agents/skills/` → `~/.agents/skills/`
- `config/claude/settings.json` → `~/.claude/settings.json`
- `config/devin/config.json` → `~/.config/devin/config.json`

tool-specific dirs symlink into `~/.agents/`:
- `~/.claude/CLAUDE.md` → `~/.agents/AGENTS.md`
- `~/.claude/skills` → `~/.agents/skills`
- `~/.config/devin/skills` → `~/.agents/skills`

### skills

skills are vendored in `config/agents/skills/` and deployed to `~/.agents/skills/` via home-manager.

```bash
skill-add <owner/repo> <skill>    # download skill from github repo
skill-search <owner/repo>         # list available skills in a repo
skill-list                        # list installed skills (alias: skills)
skill-remove <skill>              # remove a skill
skill-install <repo> <skill> <config>  # add + rebuild in one step
skill-browse                      # open skills.sh in browser
```

after adding/removing a skill, run `just switch <config>` to deploy (or use `skill-install` to do it in one step).

## machine configurations

| config | host | type | notes |
|---|---|---|---|
| `darwin-personal` | M4 Pro MacBook Pro | nix-darwin | daily driver, full GUI apps |
| `darwin-agent` | M1 Pro MacBook Pro | nix-darwin | always-on agent, never sleeps |
| `workstation` | Ubuntu, RTX 5090 | standalone home-manager | dotfiles + CLI only (no NixOS) |

## ssh hosts

configured in `home/ssh.nix`, using 1Password SSH agent:

- `workstation` — personal workstation (5090), via Tailscale
- `jetson-nano` — Jetson Orin Nano, via Tailscale
- `uva-hpc` — UVA HPC cluster (multiplexed)
- `do-droplet` — DigitalOcean droplet

## manual stuff

some things can't be nix-managed. install/configure by hand:

- **iOS apps on Mac (mas can't install):** UniFi
- **direct download:** VESC Tool (vesc-project.com)
- **app-internal config:** Raycast, Cursor, Chrome, 1Password (all have built-in sync — just sign in)
- **Berkeley Mono font** (paid, not in nix):
  ```bash
  gh repo clone (hidden)/fonts /tmp/fonts
  cp /tmp/fonts/**/*.{otf,ttf} ~/Library/Fonts/
  rm -rf /tmp/fonts
  ```

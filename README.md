# dots

my personal nix-darwin + home-manager configuration for macOS and Linux machines.

## new mac setup

Bootstrap requires two passes — the first installs everything (including 1Password CLI), the second injects secrets.

```bash
# 1. install nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. clone this repo (xcode git works, or: nix shell nixpkgs#git)
git clone https://github.com/charliemeyer2000/dots ~/all/dots
cd ~/all/dots

# 3. first build — bootstraps nix-darwin, homebrew, all packages and apps
#    secrets will fail gracefully (1Password not signed in yet)
nix run nix-darwin -- switch --flake .#darwin-personal

# 4. sign into 1Password (desktop app), then the CLI:
op signin

# 5. sign into Mac App Store (for Xcode, Keynote, Klack via mas)

# 6. second build — secrets, tailscale auth, and App Store apps
just switch darwin-personal
```

After step 5, open a new terminal. All aliases, secrets, and dotfiles are active.

## commands

```bash
just switch <config>     # rebuild and apply (e.g., just switch darwin-personal)
just switch-dry <config> # build without applying
just check               # run flake checks + linters
just fmt                 # format all nix files
just dev                 # enter dev shell
```

aliases (available after rebuild):

```bash
rebuild <config>  # shorthand for just switch
dots              # cd to dots directory
cc                # claude --dangerously-skip-permissions
k                 # kubectl
tf                # terraform
killport <port>   # kill process on port
```

`npm`, `pip`, and `pip3` are aliased to errors — use `pnpm` and `uv` instead.

## agent configuration

agent config is tool-agnostic, using the [AGENTS.md](https://agents-md.org) open standard:

- `config/agents/AGENTS.md` → `~/.agents/AGENTS.md` (global instructions)
- `config/agents/skills/` → `~/.agents/skills/` (agent skills)
- `config/claude/settings.json` → `~/.claude/settings.json` (claude-specific)
- `config/claude/hooks/` → `~/.claude/hooks/` (claude code hooks, deployed executable)

claude code reads from `~/.claude/`, which symlinks into `~/.agents/`:
- `~/.claude/CLAUDE.md` → `~/.agents/AGENTS.md`
- `~/.claude/skills` → `~/.agents/skills`

deployed via home-manager (`home/agents.nix`). any AGENTS.md-compatible coding agent can read from `~/.agents/` directly.

a `SessionEnd` hook spawns a background `claude -p` on session exit to review changes and update docs if needed. per-project config via `.claude/docs-update.json`. logs at `~/.claude/logs/`.

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

| config | os | gui apps | secrets | notes |
|---|---|---|---|---|
| `darwin-personal` | macOS | yes (`apps.nix`) | yes | full setup |
| `linux` | Linux | no | yes | general linux |
| `linux-hpc` | Linux | no | no | shared HPC nodes |

## ssh hosts

configured in `home/ssh.nix`, using 1Password SSH agent:

- `workstation` — personal workstation (5090), via Tailscale
- `jetson-nano` — Jetson Orin Nano, via Tailscale
- `uva-hpc` — UVA HPC cluster (multiplexed)
- `do-droplet` — DigitalOcean droplet

## manual stuff

some things can't be nix-managed. install/configure by hand:

**iOS apps on Mac (mas can't install):** UniFi

**direct download:** VESC Tool (vesc-project.com)

**app-internal config:** Raycast (built-in sync), Cursor (GitHub sync), Chrome (Google sync), 1Password (sign in)

**fonts:** nix handles JetBrainsMono + FiraCode nerd fonts (`home/fonts.nix`). for Berkeley Mono (paid):
```bash
gh repo clone (hidden)/fonts /tmp/fonts
cp /tmp/fonts/**/*.{otf,ttf} ~/Library/Fonts/
rm -rf /tmp/fonts
```

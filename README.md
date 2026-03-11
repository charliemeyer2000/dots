# dots

nix-darwin + home-manager configuration for macOS and Linux machines.

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

## claude code

`claude-code` is nix-managed (via nixpkgs). the `claude` binary comes from the nix store, not a global npm install.

settings and CLAUDE.md are deployed via home-manager (`home/claude.nix`):
- `config/claude/settings.json` -> `~/.claude/settings.json`
- `config/claude/CLAUDE.md` -> `~/.claude/CLAUDE.md`
- `config/claude/skills/` -> `~/.claude/skills/`

### skills

skills are vendored in `config/claude/skills/` and deployed to `~/.claude/skills/` via home-manager.

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
| `darwin-minimal` | macOS | no | yes | core tools only |
| `linux-ec2` | Linux | no | yes | AWS EC2 instances |
| `linux-hpc` | Linux | no | no | shared HPC nodes |

## ssh hosts

configured in `home/ssh.nix`, using 1Password SSH agent:

- `workstation` — personal workstation (5090), via Tailscale
- `jetson-nano` — Jetson Orin Nano, via Tailscale
- `uva-hpc` — UVA HPC cluster (multiplexed)
- `do-droplet` — DigitalOcean droplet

## manual stuff

some things can't be nix-managed. install/configure by hand:

**mac app store:** Xcode, Keynote

**no brew cask:** Ollama, Klack, VESC Tool, UniFi, Logitech Options+, Cisco Secure Client

**app-internal config:** Raycast (built-in sync), Cursor (GitHub sync), Chrome (Google sync), 1Password (sign in)

**fonts:** nix handles JetBrainsMono + FiraCode nerd fonts (`home/fonts.nix`). for Berkeley Mono (paid):
```bash
gh repo clone (hidden)/fonts /tmp/fonts
cp /tmp/fonts/**/*.{otf,ttf} ~/Library/Fonts/
rm -rf /tmp/fonts
```

**kext stuff:** hardware drivers / VPN clients with kernel extensions — install manually.

## after bootstrap

1. `op signin`
2. `just switch <config>` (injects secrets)
3. `gh auth login`
4. `tailscale up`
5. import SSH keys to 1Password if new machine

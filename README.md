# dots

my nix configuration

## easy commands

setup: `darwin-rebuild switch --flake .#[host]`
    - hosts: `[darwin-minimal, darwin-personal, linux-ec2, linux-hpc]`

other commands are in `justfile`

## claude code skills

skills are vendored in `config/claude/skills/` and deployed to `~/.claude/skills/` via home-manager.

**add a new skill:**

```bash
# option 1: use the skills cli, then vendor into nix
npx skills add owner/repo -g       # installs to ~/.agents/skills/
cp -r ~/.agents/skills/my-skill config/claude/skills/
just switch                         # deploys via nix

# option 2: manually create one
mkdir config/claude/skills/my-skill
# write config/claude/skills/my-skill/SKILL.md
just switch
```

**project-level skills** still work normally — `npx skills add owner/repo` (without `-g`) creates symlinks in your project's `.claude/skills/` pointing to `~/.agents/skills/`. this doesn't conflict with nix.

**updating skills:** re-run `npx skills update`, then re-copy from `~/.agents/skills/` into `config/claude/skills/`.

## manual setup

nix is fantastic for setting up literally everything, except for:
- I have ros2 installed. on a mac, you have to [disable SIP](https://developer.apple.com/documentation/security/disabling-and-enabling-system-integrity-protection). 
# dots

my nix configuration

## easy commands

rebuild

other commands are in `justfile`

## claude code skills

skills are vendored in `config/claude/skills/` and deployed to `~/.claude/skills/` via home-manager.

**add a new skill:**

```bash
# option 1: use the skills cli, then vendor into nix
npx skills add owner/repo -g
cp -r ~/.agents/skills/my-skill config/claude/skills/
just switch

# option 2: manually create one
mkdir config/claude/skills/my-skill
just switch
```

**project-level skills** still work normally — `npx skills add owner/repo` (without `-g`) creates symlinks in your project's `.claude/skills/` pointing to `~/.agents/skills/`. this doesn't conflict with nix.

**updating skills:** re-run `npx skills update`, then re-copy from `~/.agents/skills/` into `config/claude/skills/`.

## manual stuff

some things (specifically for mac) can't be nix-managed. install/configure by hand if you want:

**mac app store:** Xcode, Keynote

**no brew cask:** Ollama, Klack, VESC Tool, UniFi, Logitech Options+, Cisco Secure Client

**app-internal config:** Raycast (use built-in sync), Cursor (GitHub sync), Chrome (Google sync), 1Password (sign in)

**fonts:** nix handles JetBrainsMono + FiraCode nerd fonts. for Berkeley Mono (paid):
```bash
gh repo clone (hidden)/fonts /tmp/fonts
cp /tmp/fonts/**/*.{otf,ttf} ~/Library/Fonts/
rm -rf /tmp/fonts
```

**ROS2:** can't nix-manage on macOS/Apple Silicon. built from source at `~/ros2_jazzy/`, requires [SIP disabled](https://developer.apple.com/documentation/security/disabling-and-enabling-system-integrity-protection).

**kext stuff:** hardware drivers / VPN clients with kernel extensions — install manually.

## after bootstrap

1. `op signin`
2. `just switch` (injects secrets)
3. `gh auth login`
4. `tailscale up`
5. import SSH keys to 1Password if new machine
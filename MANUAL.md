# Manual Setup

Things that can't be managed by Nix. Install these by hand and document them here.

## Mac App Store Apps

Install manually from the Mac App Store:
- Xcode (for command line tools and iOS development)
- Keynote

## Apps Without Brew Casks

These must be installed manually (no homebrew cask available):
- **Ollama** — download from ollama.com
- **Klack** — mechanical keyboard sounds
- **VESC Tool** — VESC motor controller config
- **UniFi** — Ubiquiti network management
- **Logitech Options+** — Logitech peripheral config
- **Cisco Secure Client** — VPN (usually managed by IT)

## App-Internal Configs

These store settings internally and can't be declaratively managed:
- **Raycast** — extensions, keybindings, snippets (use Raycast's built-in sync)
- **Cursor** — settings sync via GitHub account
- **Chrome** — profile/extensions via Google account sync
- **1Password** — sign in via account credentials

## Fonts

**Berkeley Mono** (used by Ghostty) must be installed manually — it's a paid font and can't be committed to a public repo. Copy the OTF/TTF files to `~/Library/Fonts/`.

## ROS2

Cannot be nix-managed on macOS/Apple Silicon (nix-ros-overlay only supports Linux). Built from source via colcon at `~/ros2_jazzy/`. Requires SIP disabled.

```bash
# Build from source: https://docs.ros.org/en/jazzy/Installation/Alternatives/macOS-Development-Setup.html
# Source the workspace: source ~/ros2_jazzy/install/setup.zsh
```

## Kext-Based Installs

Hardware drivers or VPN clients that require kernel extensions must be installed manually.

## After Bootstrap Checklist

1. Sign into 1Password: `op signin`
2. Run `just switch` to inject secrets
3. Sign into GitHub CLI: `gh auth login`
4. Sign into Tailscale: `tailscale up`
5. Import SSH keys to 1Password (if new machine)
6. Set up Ghostty config (managed via dots, should just work)

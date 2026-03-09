#!/usr/bin/env bash
set -euo pipefail

# bootstrap.sh — one-command setup for new machines
# Usage: curl -fsSL <raw-url> | bash
#   or:  git clone ... && cd dots && ./bootstrap.sh

DOTS_DIR="${DOTS_DIR:-$HOME/all/dots}"
FLAKE_HOST="${1:-}"

echo "=== dots bootstrap ==="

# 1. Install Nix (Determinate Systems installer)
if ! command -v nix &>/dev/null; then
  echo "Installing Nix..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# 2. Clone dots if not already present
if [ ! -d "$DOTS_DIR" ]; then
  echo "Cloning dots repo..."
  mkdir -p "$(dirname "$DOTS_DIR")"
  git clone https://github.com/charliemeyer2000/dots.git "$DOTS_DIR"
fi
cd "$DOTS_DIR"

# 3. Detect host config if not specified
if [ -z "$FLAKE_HOST" ]; then
  case "$(uname -s)" in
    Darwin)
      FLAKE_HOST="darwin-personal"
      ;;
    Linux)
      if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
        FLAKE_HOST="linux-ec2"
      else
        FLAKE_HOST="linux-hpc"
      fi
      ;;
    *)
      echo "Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac
  echo "Detected host: $FLAKE_HOST"
fi

# 4. Build and switch
echo "Building configuration for $FLAKE_HOST..."
case "$(uname -s)" in
  Darwin)
    nix run nix-darwin -- switch --flake "$DOTS_DIR#$FLAKE_HOST"
    ;;
  Linux)
    sudo nixos-rebuild switch --flake "$DOTS_DIR#$FLAKE_HOST"
    ;;
esac

# 5. Oh My Zsh + custom plugins
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
  echo "Installing zsh-autosuggestions plugin..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
fi
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
  echo "Installing zsh-syntax-highlighting plugin..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
fi

# 6. NVM (Node version manager)
if [ ! -d "$HOME/.nvm" ]; then
  echo "Installing NVM..."
  PROFILE=/dev/null bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh)"
fi

# 7. Claude Code CLI
if ! command -v claude &>/dev/null; then
  echo "Installing Claude Code CLI..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

# 8. Secrets / 1Password setup
if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  echo "Service account token detected — saving for activation scripts..."
  mkdir -p "$HOME/.config/op"
  echo "$OP_SERVICE_ACCOUNT_TOKEN" > "$HOME/.config/op/service-account-token"
  chmod 600 "$HOME/.config/op/service-account-token"
  echo "Secrets were injected during activation."
elif command -v op &>/dev/null; then
  echo "1Password CLI found — secrets were injected during activation (if signed in)."
else
  echo "No 1Password available. Run 'just switch' after setting up 1Password to inject secrets."
fi

echo "=== bootstrap complete ==="

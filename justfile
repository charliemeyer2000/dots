# dots task runner

default:
  just --list

# format all nix files
fmt:
  nix fmt

# run all flake checks
check:
  nix flake check

# rebuild machine with specified configuration (auto-detects darwin vs home-manager)
switch config='':
  #!/usr/bin/env bash
  if [[ -z "{{config}}" ]]; then
    echo "Error: Configuration name required"
    echo ""
    echo "Available configurations:"
    echo "  - darwin-personal   # Full macOS setup with GUI apps"
    echo "  - workstation       # Linux workstation (standalone home-manager)"
    echo ""
    echo "Usage: just switch <config>"
    echo "Example: just switch darwin-personal"
    exit 1
  fi
  mkdir -p ~/.config/dots
  pwd > ~/.config/dots/location
  nix flake update claude-code-overlay rv uvacompute
  if [[ "$(uname)" == "Darwin" ]]; then
    nix flake check
    sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .#{{config}} || {
      echo "Retrying darwin-rebuild (likely transient brew download failure)..." >&2
      sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .#{{config}}
    }
  else
    home-manager switch --flake .#{{config}} -b bak
  fi

# preview build without applying
switch-dry config='':
  #!/usr/bin/env bash
  if [[ -z "{{config}}" ]]; then
    echo "Error: Configuration name required"
    echo "Usage: just switch-dry <config>"
    exit 1
  fi
  if [[ "$(uname)" == "Darwin" ]]; then
    /run/current-system/sw/bin/darwin-rebuild build --flake .#{{config}}
  else
    home-manager build --flake .#{{config}}
  fi

# enter dev shell
dev:
  nix develop

# === Skill Management ===

# add a skill (e.g., just skill-add 'cursor/plugins' deslop)
skill-add repo skill:
  @./scripts/skill-add.sh {{repo}} {{skill}}

# search for skills in a repo (e.g., just skill-search 'cursor/plugins')
skill-search repo:
  @./scripts/skill-search.sh {{repo}}

# list installed skills
skill-list:
  @ls -1 config/agents/skills/ 2>/dev/null | sed 's/^/  - /' || echo "No skills installed"

# remove a skill
skill-remove skill:
  @./scripts/skill-remove.sh {{skill}}

# browse skills online
skill-browse:
  @open "https://skills.sh"

# install a skill and rebuild immediately (requires config)
skill-install repo skill config: (skill-add repo skill) (switch config)

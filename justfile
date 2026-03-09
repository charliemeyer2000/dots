# dots task runner

default:
  just --list

# format all nix files
fmt:
  nix fmt

# run all flake checks
check:
  nix flake check

# rebuild machine with specified configuration
switch config='':
  #!/usr/bin/env bash
  if [[ -z "{{config}}" ]]; then
    echo "Error: Configuration name required"
    echo ""
    echo "Available configurations:"
    echo "  - darwin-personal   # Full macOS setup with GUI apps"
    echo "  - darwin-minimal    # Minimal macOS setup without GUI apps"
    echo "  - linux-ec2         # AWS EC2 Linux instances"
    echo "  - linux-hpc         # HPC cluster nodes"
    echo ""
    echo "Usage: just switch <config>"
    echo "Example: just switch darwin-personal"
    exit 1
  fi
  mkdir -p ~/.config/dots
  pwd > ~/.config/dots/location
  nix flake check && sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .#{{config}}

# rebuild and show diff
switch-dry config='':
  #!/usr/bin/env bash
  if [[ -z "{{config}}" ]]; then
    echo "Error: Configuration name required"
    echo ""
    echo "Available configurations:"
    echo "  - darwin-personal   # Full macOS setup with GUI apps"
    echo "  - darwin-minimal    # Minimal macOS setup without GUI apps"
    echo "  - linux-ec2         # AWS EC2 Linux instances"
    echo "  - linux-hpc         # HPC cluster nodes"
    echo ""
    echo "Usage: just switch-dry <config>"
    echo "Example: just switch-dry darwin-personal"
    exit 1
  fi
  /run/current-system/sw/bin/darwin-rebuild build --flake .#{{config}}

# enter dev shell
dev:
  nix develop

# enter ROS2 dev shell
ros2:
  nix develop .#ros2

# === Skill Management ===

# add a skill (e.g., just skill-add 'cursor/plugins' deslop)
skill-add repo skill:
  @./scripts/skill-add.sh {{repo}} {{skill}}

# search for skills in a repo (e.g., just skill-search 'cursor/plugins')
skill-search repo:
  @./scripts/skill-search.sh {{repo}}

# list installed skills
skill-list:
  @ls -1 config/claude/skills/ 2>/dev/null | sed 's/^/  - /' || echo "No skills installed"

# remove a skill
skill-remove skill:
  @./scripts/skill-remove.sh {{skill}}

# browse skills online
skill-browse:
  @open "https://skills.sh"

# install a skill and rebuild immediately (requires config)
skill-install repo skill config: (skill-add repo skill) (switch config)

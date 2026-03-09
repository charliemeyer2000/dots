# dots task runner

default:
  just --list

# format all nix files
fmt:
  nix fmt

# run all flake checks
check:
  nix flake check

# rebuild current machine
switch:
  @mkdir -p ~/.config/dots
  @pwd > ~/.config/dots/location
  nix flake check && sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .#darwin-personal

# rebuild and show diff
switch-dry:
  /run/current-system/sw/bin/darwin-rebuild build --flake .#darwin-personal

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

# install a skill and rebuild immediately
skill-install repo skill: (skill-add repo skill) switch

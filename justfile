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

# add a skill (e.g., just skill-add cursor/plugins deslop)
skill-add owner_repo skill_name:
  @./scripts/skill-add.sh {{owner_repo}} {{skill_name}}

# search for skills in a repo
skill-search owner_repo:
  @./scripts/skill-search.sh {{owner_repo}}

# list installed skills
skill-list:
  @ls -1 config/claude/skills/ 2>/dev/null | sed 's/^/  - /' || echo "No skills installed"

# remove a skill
skill-remove skill_name:
  @./scripts/skill-remove.sh {{skill_name}}

# browse skills online
skill-browse:
  @open "https://skills.sh"

# install a skill and rebuild immediately
skill-install owner_repo skill_name: (skill-add owner_repo skill_name) switch

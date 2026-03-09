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

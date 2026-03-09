# dots

my nix configuration

## easy commands

setup: `darwin-rebuild switch --flake .#[host]`
    - hosts: `[darwin-minimal, darwin-personal, linux-ec2, linux-hpc]`

other commands are in `justfile`

## manual setup

nix is fantastic for setting up literally everything, except for: 
- I have ros2 installed. on a mac, you have to [disable SIP](https://developer.apple.com/documentation/security/disabling-and-enabling-system-integrity-protection). 
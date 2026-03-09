{pkgs, ...}: {
  # System defaults
  system.defaults = {
    dock.autohide = true;
    dock.show-recents = false;
    NSGlobalDomain.KeyRepeat = 2;
    NSGlobalDomain.InitialKeyRepeat = 15;
    NSGlobalDomain.ApplePressAndHoldEnabled = false;
    screencapture.location = "~/Desktop/screenshots";
  };

  # TouchID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Tailscale
  services.tailscale.enable = true;

  # Homebrew (managed by nix-darwin)
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "none"; # switch to "zap" once cask list is complete
    };
    taps = [
      "hashicorp/tap"
      "derailed/k9s"
      "stripe/stripe-cli"
      "withgraphite/tap"
    ];
    brews = [
      "hashicorp/tap/terraform"
      "derailed/k9s/k9s"
      "stripe/stripe-cli/stripe"
      "withgraphite/tap/graphite"
      "qemu" # needed for colima/docker on arm64
    ];
  };
}

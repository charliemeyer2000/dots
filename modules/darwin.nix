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
  };
}

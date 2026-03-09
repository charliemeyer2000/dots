{pkgs, ...}: {
  # 1Password CLI is in base.nix; this module handles secrets injection
  system.activationScripts.postActivation.text = ''
    # Only inject secrets if op session is active
    if ${pkgs._1password-cli}/bin/op whoami &>/dev/null; then
      echo "Injecting secrets via 1Password..."
      ${pkgs._1password-cli}/bin/op inject -i /Users/charlie/all/dots/secrets/secrets.zsh.tmpl -o /Users/charlie/.env.local
      ${pkgs._1password-cli}/bin/op inject -i /Users/charlie/all/dots/secrets/aws.tmpl -o /Users/charlie/.aws/credentials
      chown charlie:staff /Users/charlie/.env.local /Users/charlie/.aws/credentials
      chmod 600 /Users/charlie/.env.local /Users/charlie/.aws/credentials
    else
      echo "1Password not signed in, skipping secrets injection."
    fi
  '';
}

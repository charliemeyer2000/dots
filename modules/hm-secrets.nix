{
  pkgs,
  config,
  lib,
  ...
}: let
  homeDir = config.home.homeDirectory;
  dotsDir = "${homeDir}/all/dots";
  op = "${pkgs._1password-cli}/bin/op";
  tailscale = "${pkgs.tailscale}/bin/tailscale";
in {
  home.activation.injectSecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -f ${homeDir}/.config/op/service-account-token ]; then
      OP_SERVICE_ACCOUNT_TOKEN="$(cat ${homeDir}/.config/op/service-account-token)"
      export OP_SERVICE_ACCOUNT_TOKEN
      echo "Using 1Password service account..."
    fi

    echo "Injecting secrets via 1Password..."
    if ${op} inject -f -i ${dotsDir}/secrets/secrets.zsh.tmpl -o ${homeDir}/.env.local; then
      chmod 600 ${homeDir}/.env.local
      echo "  -> ~/.env.local injected"
    else
      echo "1Password not signed in or inject failed, skipping secrets."
    fi

    if [ -f ${homeDir}/.env.local ]; then
      . ${homeDir}/.env.local

      if [ -n "$TAILSCALE_OAUTH_CLIENT_SECRET" ]; then
        if ${tailscale} status &>/dev/null; then
          echo "  -> Tailscale already connected, skipping auth"
        elif sudo -n ${tailscale} up --auth-key="''${TAILSCALE_OAUTH_CLIENT_SECRET}?ephemeral=false&preauthorized=true" --advertise-tags=tag:shared 2>/dev/null; then
          echo "  -> Tailscale authenticated"
        else
          echo "  -> Tailscale auth skipped (already connected or sudo requires password)"
        fi
      fi
    fi
  '';
}

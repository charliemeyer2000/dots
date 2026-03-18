{pkgs, ...}: let
  homeDir =
    if pkgs.stdenv.isDarwin
    then "/Users/charlie"
    else "/home/charlie";
  group =
    if pkgs.stdenv.isDarwin
    then "staff"
    else "charlie";
  dotsDir = "${homeDir}/all/dots";
  op = "${pkgs._1password-cli}/bin/op";
  tailscale = "${pkgs.tailscale}/bin/tailscale";
  asCharlie = "sudo -u charlie HOME=${homeDir}";
  script = ''
    if [ -f ${homeDir}/.config/op/service-account-token ]; then
      OP_SERVICE_ACCOUNT_TOKEN="$(cat ${homeDir}/.config/op/service-account-token)"
      export OP_SERVICE_ACCOUNT_TOKEN
      OP_CMD="${op}"
      echo "Using 1Password service account..."
    else
      OP_CMD="${asCharlie} ${op}"
      echo "Using 1Password desktop app integration..."
    fi

    echo "Injecting secrets via 1Password..."
    if $OP_CMD inject -f -i ${dotsDir}/secrets/secrets.zsh.tmpl -o ${homeDir}/.env.local; then
      chown charlie:${group} ${homeDir}/.env.local
      chmod 600 ${homeDir}/.env.local
      echo "  -> ~/.env.local injected"
    else
      echo "1Password not signed in or inject failed, skipping secrets."
    fi

    # Source injected secrets for Tailscale and Mullvad setup
    if [ -f ${homeDir}/.env.local ]; then
      # shellcheck source=/dev/null
      . ${homeDir}/.env.local

      # Authenticate Tailscale via OAuth (idempotent — re-auths if needed, no-op if current)
      if [ -n "$TAILSCALE_OAUTH_CLIENT_SECRET" ]; then
        echo "Authenticating Tailscale..."
        if ${tailscale} up --auth-key="''${TAILSCALE_OAUTH_CLIENT_SECRET}?ephemeral=false&preauthorized=true" --advertise-tags=tag:shared 2>/dev/null; then
          echo "  -> Tailscale authenticated"
        else
          echo "  -> Tailscale auth failed (tailscaled may not be running yet)"
        fi
      fi

      # Mullvad VPN: login, auto-connect, always-on (no lockdown — coexists with Tailscale)
      MULLVAD_BIN="/Applications/Mullvad VPN.app/Contents/Resources/mullvad"
      if [ -x "$MULLVAD_BIN" ] && [ -n "$MULLVAD_ACCOUNT_NUMBER" ]; then
        echo "Configuring Mullvad VPN..."
        ${asCharlie} "$MULLVAD_BIN" account login "$MULLVAD_ACCOUNT_NUMBER" 2>/dev/null
        ${asCharlie} "$MULLVAD_BIN" auto-connect set on 2>/dev/null
        ${asCharlie} "$MULLVAD_BIN" lockdown-mode set off 2>/dev/null
        ${asCharlie} "$MULLVAD_BIN" lan set allow 2>/dev/null
        ${asCharlie} "$MULLVAD_BIN" relay set location us 2>/dev/null
        ${asCharlie} "$MULLVAD_BIN" dns set default 2>/dev/null
        ${asCharlie} "$MULLVAD_BIN" connect 2>/dev/null
        echo "  -> Mullvad VPN configured (auto-connect, US relay, LAN allowed)"
      fi
    fi
  '';
in {
  system.activationScripts =
    if pkgs.stdenv.isDarwin
    then {postActivation.text = script;}
    else {secrets.text = script;};
}

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

    # Authenticate Tailscale via OAuth (idempotent — re-auths if needed, no-op if current)
    TS_SECRET=$($OP_CMD read "op://Personal/Dev Secrets/tailscale-oauth-client-secret" 2>/dev/null)
    if [ -n "$TS_SECRET" ]; then
      echo "Authenticating Tailscale..."
      if ${tailscale} up --auth-key="''${TS_SECRET}?ephemeral=false&preauthorized=true" --advertise-tags=tag:shared 2>/dev/null; then
        echo "  -> Tailscale authenticated"
      else
        echo "  -> Tailscale auth failed (tailscaled may not be running yet)"
      fi
    fi
  '';
in {
  system.activationScripts =
    if pkgs.stdenv.isDarwin
    then {postActivation.text = script;}
    else {secrets.text = script;};
}

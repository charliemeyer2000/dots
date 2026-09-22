{
  pkgs,
  lib,
  config,
  ...
}: let
  homeDir = "/Users/charlie";
  dotsDir = "${homeDir}/all/dots";
  op = "${pkgs._1password-cli}/bin/op";
  tailscale = "${pkgs.tailscale}/bin/tailscale";
  # OAuth client scoped to `auth_keys` + tag:personal only; read straight from
  # 1Password at activation so it never lands in ~/.env.local.
  tailscaleClientRef = "op://Developer/Tailscale/oauth-client-secret-personal";
  asCharlie = "sudo -u charlie HOME=${homeDir}";
  cfg = config.dots.onePassword;

  extraEnvExports = lib.concatStrings (lib.mapAttrsToList (name: ref: ''
      if VALUE="$($OP_CMD read "${ref}" 2>/dev/null)"; then
        echo "export ${name}=\"$VALUE\"" >> ${homeDir}/.env.local
      else
        echo "  -> ${ref} unreadable, ${name} not exported"
      fi
    '')
    cfg.extraEnv);
in {
  options.dots.onePassword = {
    account = lib.mkOption {
      type = lib.types.str;
      default = "my.1password.com";
      example = "my.1password.com";
      description = ''
        Sign-in address of the 1Password account that holds the secrets referenced
        in `secrets/secrets.zsh.tmpl`. Passed as `op --account <value>` in the
        desktop-app (interactive) path so vault lookups disambiguate when multiple
        accounts are signed in (e.g. personal + work). The service-account path
        ignores this — the token already identifies its account.
      '';
    };
    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {LIFE_MCP_API_KEY = "op://Developer/Life MCP/darwin-personal";};
      description = ''
        Host-specific exports appended to `~/.env.local` after the shared template
        is injected: env var name → `op://` reference, each `op read` at activation.
        For secrets that differ per machine (one API key per client), which the
        shared `secrets.zsh.tmpl` can't express without breaking hosts that lack them.
      '';
    };
  };

  config.system.activationScripts.postActivation.text = ''
    if [ -f ${homeDir}/.config/op/service-account-token ]; then
      OP_SERVICE_ACCOUNT_TOKEN="$(cat ${homeDir}/.config/op/service-account-token)"
      export OP_SERVICE_ACCOUNT_TOKEN
      OP_CMD="${op}"
      echo "Using 1Password service account..."
    else
      OP_CMD="${asCharlie} ${op} --account ${cfg.account}"
      echo "Using 1Password desktop app integration (account: ${cfg.account})..."
    fi

    echo "Injecting secrets via 1Password..."
    if $OP_CMD inject -f -i ${dotsDir}/secrets/secrets.zsh.tmpl -o ${homeDir}/.env.local; then
      ${extraEnvExports}
      chown charlie:staff ${homeDir}/.env.local
      chmod 600 ${homeDir}/.env.local
      echo "  -> ~/.env.local injected"
    else
      echo "1Password not signed in or inject failed, skipping secrets."
    fi

    # Authenticate Tailscale via OAuth (idempotent — re-auths if needed, no-op if current)
    if TS_CLIENT_SECRET="$($OP_CMD read "${tailscaleClientRef}" 2>/dev/null)"; then
      echo "Authenticating Tailscale..."
      if ${tailscale} up --reset --auth-key="''${TS_CLIENT_SECRET}?ephemeral=false&preauthorized=true" --advertise-tags=tag:personal 2>/dev/null; then
        echo "  -> Tailscale authenticated"
      else
        echo "  -> Tailscale auth failed (tailscaled may not be running yet)"
      fi
      unset TS_CLIENT_SECRET
    fi
  '';
}

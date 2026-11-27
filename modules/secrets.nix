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
  jq = "${pkgs.jq}/bin/jq";
  # OAuth client scoped to `auth_keys` + tag:personal only; read straight from
  # 1Password at activation so it never lands in ~/.env.local.
  tailscaleClientRef = "op://Developer/Tailscale/oauth-client-secret-personal";
  asCharlie = "sudo -u charlie HOME=${homeDir}";
  cfg = config.dots.onePassword;
  tsClient = config.dots.tailscale.client;
  # Everything below exists to run $OP_CMD consumers; when a host enables none
  # of them (darwin-cog), emit nothing — an unused OP_CMD trips shellcheck
  # SC2034, which fails nix-darwin's activation-script check.
  needsOp = cfg.injectEnv || tsClient != null;

  extraEnvExports = lib.concatStrings (lib.mapAttrsToList (name: ref: ''
      if VALUE="$($OP_CMD read "${ref}" 2>/dev/null)"; then
        printf 'export %s=%q\n' ${name} "$VALUE" >> ${homeDir}/.env.local
      else
        echo "  -> ${ref} unreadable, ${name} not exported"
      fi
    '')
    cfg.extraEnv);
in {
  options.dots.tailscale.client = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum ["daemon" "app"]);
    default = "daemon";
    example = "app";
    description = ''
      How this Mac joins the personal tailnet: `"daemon"` runs nix-darwin's
      open-source tailscaled (starts at boot, no login session needed), `"app"`
      installs the standalone Tailscale.app (`tailscale-app` cask), and `null`
      keeps the Mac off the tailnet (darwin-cog). A single option so a Mac can't
      run both clients, which enrolls it on the tailnet twice.
    '';
  };

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
    injectEnv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to inject `secrets/secrets.zsh.tmpl` (plus `extraEnv`) into
        `~/.env.local` at activation. Disable on hosts that shouldn't carry
        personal secrets in the shell env (e.g. work machines) — Tailscale
        auth below is unaffected.
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

  config.services.tailscale.enable = tsClient == "daemon";
  config.dots.homebrew.extraCasks = lib.optional (tsClient == "app") "tailscale-app";

  config.system.activationScripts.postActivation.text = lib.optionalString needsOp ''
    if [ -f ${homeDir}/.config/op/service-account-token ]; then
      OP_SERVICE_ACCOUNT_TOKEN="$(cat ${homeDir}/.config/op/service-account-token)"
      export OP_SERVICE_ACCOUNT_TOKEN
      OP_CMD="${op}"
      echo "Using 1Password service account..."
    else
      OP_CMD="${asCharlie} ${op} --account ${cfg.account}"
      echo "Using 1Password desktop app integration (account: ${cfg.account})..."
    fi

    ${lib.optionalString cfg.injectEnv ''
      echo "Injecting secrets via 1Password..."
      if $OP_CMD inject -f -i ${dotsDir}/secrets/secrets.zsh.tmpl -o ${homeDir}/.env.local; then
        ${extraEnvExports}
        chown charlie:staff ${homeDir}/.env.local
        chmod 600 ${homeDir}/.env.local
        echo "  -> ~/.env.local injected"
      else
        echo "1Password not signed in or inject failed, skipping secrets."
      fi
    ''}

    # Log in to Tailscale via OAuth only when logged out (fresh install, expired
    # key): --reset also resets every other setting (exit node, ...), so running
    # it on every rebuild would wipe them. Skipped when tsClient = null (darwin-cog).
    ${lib.optionalString (tsClient != null) ''
      TS_STATUS="$(${tailscale} status --json 2>/dev/null || true)"
      case "$(${jq} -r '.BackendState // empty' <<<"$TS_STATUS")" in
        NeedsLogin | NoState)
          if TS_CLIENT_SECRET="$($OP_CMD read "${tailscaleClientRef}" 2>/dev/null)"; then
            echo "Authenticating Tailscale..."
            if ${tailscale} up --reset --auth-key="''${TS_CLIENT_SECRET}?ephemeral=false&preauthorized=true" --advertise-tags=tag:personal; then
              echo "  -> Tailscale authenticated"
            else
              echo "  -> Tailscale auth failed (error above)"
            fi
            unset TS_CLIENT_SECRET
          fi
          ;;
        "") echo "  -> Tailscale not reachable (app not running yet?), skipping auth" ;;
        *) echo "  -> Tailscale already logged in, skipping auth" ;;
      esac
    ''}
  '';
}

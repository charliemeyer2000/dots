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
  jq = "${pkgs.jq}/bin/jq";
  # OAuth client scoped to `auth_keys` + tag:workstation only; read straight from
  # 1Password at activation so it never lands in ~/.env.local.
  tailscaleClientRef = "op://Developer/Tailscale/oauth-client-secret-workstation";
  tailscaleTag = "tag:workstation";
  # The node's complete non-default Tailscale settings: `tailscale up --reset`
  # applies exactly these, so a leftover setting (an exit node, ...) can't make
  # the login refuse to run. --operator lets it run without sudo.
  tailscaleUpFlags = [
    "--advertise-tags=${tailscaleTag}"
    "--ssh"
    "--operator=${config.home.username}"
  ];
  cfg = config.dots.onePassword;
in {
  options.dots.onePassword.account = lib.mkOption {
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

  config.home.activation.injectSecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -f ${homeDir}/.config/op/service-account-token ]; then
      OP_SERVICE_ACCOUNT_TOKEN="$(cat ${homeDir}/.config/op/service-account-token)"
      export OP_SERVICE_ACCOUNT_TOKEN
      OP_CMD="${op}"
      echo "Using 1Password service account..."
    else
      OP_CMD="${op} --account ${cfg.account}"
      echo "Using 1Password desktop app integration (account: ${cfg.account})..."
    fi

    echo "Injecting secrets via 1Password..."
    if $OP_CMD inject -f -i ${dotsDir}/secrets/secrets.zsh.tmpl -o ${homeDir}/.env.local; then
      chmod 600 ${homeDir}/.env.local
      echo "  -> ~/.env.local injected"
    else
      echo "1Password not signed in or inject failed, skipping secrets."
    fi

    # Log in only when logged out (fresh install, expired key); a logged-in node is left alone.
    TS_STATUS="$(${tailscale} status --json 2>/dev/null || true)"
    case "$(${jq} -r '.BackendState // empty' <<<"$TS_STATUS")" in
      NeedsLogin | NoState)
        if TS_CLIENT_SECRET="$($OP_CMD read "${tailscaleClientRef}" 2>/dev/null)"; then
          echo "Authenticating Tailscale..."
          if ${tailscale} up --reset --auth-key="''${TS_CLIENT_SECRET}?ephemeral=false&preauthorized=true" ${lib.escapeShellArgs tailscaleUpFlags}; then
            echo "  -> Tailscale authenticated"
          else
            echo "  -> Tailscale auth failed (error above)"
          fi
          unset TS_CLIENT_SECRET
        else
          echo "  -> ${tailscaleClientRef} unreadable, skipping Tailscale auth"
        fi
        ;;
      "") echo "  -> tailscaled not reachable, skipping Tailscale auth" ;;
      *)
        echo "  -> Tailscale already logged in, skipping auth"
        ${jq} -e '(.Self.Tags // []) | any(. == "${tailscaleTag}")' <<<"$TS_STATUS" >/dev/null ||
          echo "  !! Tailscale node lacks ${tailscaleTag}; SSH from tagged laptops is refused (AGENTS.md > Troubleshooting)"
        ;;
    esac
  '';
}

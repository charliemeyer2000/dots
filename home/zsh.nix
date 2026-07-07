{
  pkgs,
  onePasswordAgentSocket,
  ...
}: let
  inherit (pkgs.stdenv) isDarwin;
in {
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = ["git" "aws" "kubectl"];
    };

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreAllDups = true;
      expireDuplicatesFirst = true;
      extended = true;
    };

    shellAliases =
      {
        rebuild = "echo 'Usage: rebuild <config>' && echo 'Example: rebuild darwin-personal' && echo '' && cd $DOTS_DIR && just switch";
        dots = "cd $DOTS_DIR";
        k = "kubectl";
        tf = "terraform";
        claude = "ANTHROPIC_API_KEY= command claude";
        cc = "ANTHROPIC_API_KEY= command claude --dangerously-skip-permissions";
        dv = "devin --permission-mode bypass";
        killport = "f() { lsof -ti :$1 | xargs kill -9; }; f";
        npm = "echo 'use pnpm unless you absolutely must use npm' >&2; command npm";
        pip = "echo 'use uv instead' && false";
        pip3 = "echo 'use uv instead' && false";

        skill-add = "cd $DOTS_DIR && just skill-add";
        skill-search = "cd $DOTS_DIR && just skill-search";
        skill-list = "cd $DOTS_DIR && just skill-list";
        skill-remove = "cd $DOTS_DIR && just skill-remove";
        skill-install = "echo 'Usage: skill-install <repo> <skill> <config>' && echo 'Example: skill-install cursor/plugins deslop darwin-personal' && false";
        skills = "cd $DOTS_DIR && just skill-list";
      }
      // (
        if isDarwin
        then {
          # "windsurf" cask was renamed to "devin-desktop" (Cognition rebranded Windsurf → Devin Desktop)
          surf = "devin-desktop";
          dde = "devin-desktop"; # open Devin Desktop at a path, e.g. `dde .` (the `code .` equivalent)
          # coreutils installs GNU tools with a `g` prefix on macOS; expose GNU timeout as `timeout` (no native BSD equivalent)
          timeout = "gtimeout";
          vpn-on = "mullvad connect";
          vpn-off = "mullvad disconnect";
          vpn-status = "mullvad status && echo '---' && mullvad relay get";
          vpn-us = "mullvad relay set location us && mullvad connect";
          vpn-uk = "mullvad relay set location gb && mullvad connect";
          vpn-eu = "mullvad relay set location de && mullvad connect";

          # Tart VM management
          vm = "tart";
          vm-list = "tart list";
          vm-run = "tart run";
          vm-stop = "tart stop";
          vm-ip = "tart ip";
          vm-clone = "tart clone";
        }
        else {}
      );

    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
    };

    initContent = ''
      unsetopt correct_all
      unsetopt correct

      if [ -f "$HOME/.config/dots/location" ]; then
        export DOTS_DIR=$(cat "$HOME/.config/dots/location")
      else
        export DOTS_DIR="$HOME/all/dots"
      fi

      [ -f ~/.env.local ] && source ~/.env.local

      # GitHub PAT is intentionally NOT auto-exported (gh falls back to OAuth
      # keyring, which works for orgs that block classic PATs). Fetch on demand:
      #   GITHUB_TOKEN=$(gh-pat) some-tool        # one-shot
      #   export GITHUB_TOKEN=$(gh-pat)           # current shell only
      gh-pat() {
        op read "op://Personal/Dev Secrets/github-token"
      }

      # List running devin agent processes with the binary each is running.
      # The shared sessions.db corrupts when two different devin builds write it
      # at once (e.g. a stale `dv` session left open across a nix overlay bump),
      # so this makes version mismatches easy to spot: `devin-ps`.
      devin-ps() {
        local p bin
        for p in $(pgrep -x devin 2>/dev/null); do
          bin=$(lsof -p "$p" 2>/dev/null | awk '$4=="txt"{print $NF}' | grep -m1 -i devin)
          printf '%-7s %s\n' "$p" "''${bin:-?}"
        done
      }

      ${
        if isDarwin
        then ''
          export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.local/bin:$PATH"
        ''
        else ''
          export PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"
        ''
      }

      export SSH_AUTH_SOCK="$HOME/${onePasswordAgentSocket}"

      unset CLAUDECODE

      eval "$(zoxide init zsh)"

      ${
        if isDarwin
        then ''
          export PNPM_HOME="$HOME/Library/pnpm"
        ''
        else ''
          export PNPM_HOME="$HOME/.local/share/pnpm"
        ''
      }
      case ":$PATH:" in
        *":$PNPM_HOME:"*) ;;
        *) export PATH="$PNPM_HOME:$PATH" ;;
      esac

      if command -v go &>/dev/null; then
        export PATH="$PATH:$(go env GOPATH)/bin"
      fi

      export PATH="''${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
      ${
        if isDarwin
        then ''
          export PATH="/usr/local/texlive/2025/bin/universal-darwin:$PATH"
        ''
        else ""
      }

      if command -v kubectl &>/dev/null; then source <(kubectl completion zsh); fi
      autoload -U +X bashcompinit && bashcompinit
      if command -v terraform &>/dev/null; then complete -o nospace -C terraform terraform; fi

      ${
        if isDarwin
        then ''
          export OPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl@3

          # SSH into a Tart VM by name (prompts for password; default: admin)
          vm-ssh() {
            local vm="''${1:?usage: vm-ssh <vm-name>}"
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$(tart ip "$vm")"
          }
        ''
        else ""
      }

      [ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ] && source "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"
      [ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ] && source "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"

      if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi

      # Fix Shift+Return in Ghostty terminal
      bindkey '^[[27;2;13~' self-insert
    '';
  };
}

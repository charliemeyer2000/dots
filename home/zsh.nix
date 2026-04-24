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
        npm = "echo 'use pnpm instead' && false";
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
          vpn-on = "mullvad connect";
          vpn-off = "mullvad disconnect";
          vpn-status = "mullvad status && echo '---' && mullvad relay get";
          vpn-us = "mullvad relay set location us && mullvad connect";
          vpn-uk = "mullvad relay set location gb && mullvad connect";
          vpn-eu = "mullvad relay set location de && mullvad connect";
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

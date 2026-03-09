{...}: {
  programs.zsh = {
    enable = true;
    autosuggestion.enable = false; # OMZ plugins handle these
    syntaxHighlighting.enable = false;

    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      custom = "$HOME/.oh-my-zsh/custom";
      plugins = ["git" "aws" "kubectl" "zsh-autosuggestions" "zsh-syntax-highlighting"];
    };

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreAllDups = true;
      expireDuplicatesFirst = true;
      extended = true;
    };

    shellAliases = {
      rebuild = "just switch";
      dots = "cd ~/all/dots";
      k = "kubectl";
      tf = "terraform";
      cc = "claude --dangerously-skip-permissions";
      killport = "f() { lsof -ti :$1 | xargs kill -9; }; f";
      npm = "echo 'use pnpm instead' && false";
      pip = "echo 'use uv instead' && false";
      pip3 = "echo 'use uv instead' && false";
    };

    initContent = ''
      unsetopt correct_all
      unsetopt correct

      [ -f ~/.env.local ] && source ~/.env.local

      export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.local/bin:$PATH"

      # Fix Claude Code environment inheritance issue
      # When launching new terminal windows from within Claude Code,
      # they inherit CLAUDECODE=1 which prevents running cc/claude
      unset CLAUDECODE

      eval "$(zoxide init zsh)"


      export PNPM_HOME="$HOME/Library/pnpm"
      case ":$PATH:" in
        *":$PNPM_HOME:"*) ;;
        *) export PATH="$PNPM_HOME:$PATH" ;;
      esac

      if command -v go &>/dev/null; then
        export PATH="$PATH:$(go env GOPATH)/bin"
      fi

      export PATH="''${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
      export PATH="/usr/local/texlive/2025/bin/universal-darwin:$PATH"

      if command -v kubectl &>/dev/null; then source <(kubectl completion zsh); fi
      autoload -U +X bashcompinit && bashcompinit
      if command -v terraform &>/dev/null; then complete -o nospace -C terraform terraform; fi

      export OPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl@3

      [ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ] && source "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"
      [ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ] && source "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"

      if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi

      # Fix Shift+Return in Ghostty terminal
      bindkey '^[[27;2;13~' self-insert
    '';
  };
}

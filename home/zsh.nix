{...}: {
  programs.zsh = {
    enable = true;
    # Disable home-manager's built-in versions — OMZ plugins handle these
    autosuggestion.enable = false;
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
      # Disable command auto-correction
      unsetopt correct_all
      unsetopt correct

      # Load secrets injected by op
      [ -f ~/.env.local ] && source ~/.env.local

      # Nix system packages + user-local binaries
      export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.local/bin:$PATH"

      # zoxide (cd replacement)
      eval "$(zoxide init zsh)"

      # NVM
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

      # bun completions
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

      # pnpm global bin
      export PNPM_HOME="$HOME/Library/pnpm"
      case ":$PATH:" in
        *":$PNPM_HOME:"*) ;;
        *) export PATH="$PNPM_HOME:$PATH" ;;
      esac

      # Go binaries
      if command -v go &>/dev/null; then
        export PATH="$PATH:$(go env GOPATH)/bin"
      fi

      # krew (kubectl plugins)
      export PATH="''${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

      # TexLive
      export PATH="/usr/local/texlive/2025/bin/universal-darwin:$PATH"

      # kubectl completions
      if command -v kubectl &>/dev/null; then source <(kubectl completion zsh); fi

      # terraform completions
      autoload -U +X bashcompinit && bashcompinit
      if command -v terraform &>/dev/null; then complete -o nospace -C terraform terraform; fi

      # ROS2 jazzy
      export OPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl@3

      # Google Cloud SDK
      [ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ] && source "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"
      [ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ] && source "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"

      # graphite
      if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
    '';
  };
}

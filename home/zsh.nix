{pkgs, ...}: {
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      rebuild = "just switch";
      dots = "cd ~/all/dots";
      k = "kubectl";
      tf = "terraform";
      cc = "claude --dangerously-skip-permissions";
      killport = "f() { lsof -ti :$1 | xargs kill -9; }; f";
    };

    initContent = ''
      # Disable command auto-correction
      unsetopt correct_all
      unsetopt correct

      # Load secrets injected by op
      [ -f ~/.env.local ] && source ~/.env.local

      # Starship prompt
      eval "$(starship init zsh)"

      # zoxide (cd replacement)
      eval "$(zoxide init zsh)"

      # NVM (until we migrate to nix-managed node)
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

      # bun
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"

      # pnpm
      export PNPM_HOME="/Users/charlie/Library/pnpm"
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

{
  # Wrap alejandra so bare `nix fmt` (no path args) formats the tree instead of
  # reading stdin (which errors "unexpected end of file"). `just fmt` calls `nix fmt`.
  perSystem = {pkgs, ...}: {
    formatter = pkgs.writeShellApplication {
      name = "fmt";
      runtimeInputs = [pkgs.alejandra];
      text = ''
        if [ "$#" -eq 0 ]; then
          alejandra .
        else
          alejandra "$@"
        fi
      '';
    };
  };
}

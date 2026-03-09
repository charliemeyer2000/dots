{
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        alejandra
        deadnix
        statix
        nil
        just
      ];
      shellHook = ''
        ${config.pre-commit.installationScript}
      '';
    };
  };
}

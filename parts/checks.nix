{
  perSystem = {
    pre-commit = {
      settings.hooks = {
        alejandra.enable = true;
        deadnix.enable = true;
        statix.enable = true;
        check-json.enable = true;
        shellcheck = {
          enable = true;
          excludes = ["\\.envrc$"];
        };
      };
    };
  };
}

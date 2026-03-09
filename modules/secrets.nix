{
  pkgs,
  config,
  lib,
  ...
}: let
  homeDir =
    if pkgs.stdenv.isDarwin
    then "/Users/charlie"
    else "/home/charlie";
  group =
    if pkgs.stdenv.isDarwin
    then "staff"
    else "charlie";
  dotsDir = "${homeDir}/all/dots";
  op = "${pkgs._1password-cli}/bin/op";
  asCharlie = "sudo -u charlie HOME=${homeDir}";
  script = ''
    if ${asCharlie} ${op} read "op://Personal/GitHub/token" &>/dev/null; then
      echo "Injecting secrets via 1Password..."
      ${asCharlie} ${op} inject -i ${dotsDir}/secrets/secrets.zsh.tmpl -o ${homeDir}/.env.local && \
        chmod 600 ${homeDir}/.env.local && \
        echo "  -> ~/.env.local injected" || \
        echo "  -> ~/.env.local failed (check template references)"

      # Only inject AWS if the template items exist
      if ${asCharlie} ${op} inject -i ${dotsDir}/secrets/aws.tmpl 2>/dev/null | head -c1 | grep -q .; then
        mkdir -p ${homeDir}/.aws
        ${asCharlie} ${op} inject -i ${dotsDir}/secrets/aws.tmpl -o ${homeDir}/.aws/credentials
        chmod 600 ${homeDir}/.aws/credentials
        echo "  -> ~/.aws/credentials injected"
      else
        echo "  -> ~/.aws/credentials skipped (AWS items not in 1Password yet)"
      fi
    else
      echo "1Password not signed in, skipping secrets injection."
    fi
  '';
in {
  # nix-darwin uses postActivation, NixOS uses a named activation script
  system.activationScripts =
    if pkgs.stdenv.isDarwin
    then {postActivation.text = script;}
    else {secrets.text = script;};
}

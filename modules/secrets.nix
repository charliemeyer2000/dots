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
  script = ''
    if ${pkgs._1password-cli}/bin/op whoami &>/dev/null; then
      echo "Injecting secrets via 1Password..."
      ${pkgs._1password-cli}/bin/op inject -i ${dotsDir}/secrets/secrets.zsh.tmpl -o ${homeDir}/.env.local
      mkdir -p ${homeDir}/.aws
      ${pkgs._1password-cli}/bin/op inject -i ${dotsDir}/secrets/aws.tmpl -o ${homeDir}/.aws/credentials
      chown charlie:${group} ${homeDir}/.env.local ${homeDir}/.aws/credentials
      chmod 600 ${homeDir}/.env.local ${homeDir}/.aws/credentials
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

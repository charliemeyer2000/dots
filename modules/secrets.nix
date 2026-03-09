{pkgs, ...}: let
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
  # On macOS, activation runs as root so we sudo back to charlie for desktop app integration.
  # On Linux with a service account token, op runs directly (no desktop app needed).
  asCharlie = "sudo -u charlie HOME=${homeDir}";
  script = ''
    # Support headless machines via OP_SERVICE_ACCOUNT_TOKEN.
    # If the token file exists, export it so op cli uses it directly (no desktop app needed).
    if [ -f ${homeDir}/.config/op/service-account-token ]; then
      OP_SERVICE_ACCOUNT_TOKEN="$(cat ${homeDir}/.config/op/service-account-token)"
      export OP_SERVICE_ACCOUNT_TOKEN
      OP_CMD="${op}"
      echo "Using 1Password service account..."
    else
      OP_CMD="${asCharlie} ${op}"
      echo "Using 1Password desktop app integration..."
    fi

    echo "Injecting secrets via 1Password..."
    if $OP_CMD inject -f -i ${dotsDir}/secrets/secrets.zsh.tmpl -o ${homeDir}/.env.local; then
      chown charlie:${group} ${homeDir}/.env.local
      chmod 600 ${homeDir}/.env.local
      echo "  -> ~/.env.local injected"
    else
      echo "1Password not signed in or inject failed, skipping secrets."
    fi
  '';
in {
  # nix-darwin uses postActivation, NixOS uses a named activation script
  system.activationScripts =
    if pkgs.stdenv.isDarwin
    then {postActivation.text = script;}
    else {secrets.text = script;};
}

{...}: {
  # M1 Pro MacBook Pro — always-on agent host.
  # Shared darwin config lives in ../_darwin-common.nix.
  networking.hostName = "charlie-m1pro";
  networking.computerName = "Charlie's M1 Pro";
  networking.localHostName = "charlie-m1pro";
}

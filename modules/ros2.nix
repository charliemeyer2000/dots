{
  config,
  lib,
  pkgs,
  ...
}: let
  pythonWithRos2 = pkgs.python312.withPackages (ps:
    with ps; [
      pip
      setuptools
      wheel
      numpy
      lxml
      pyyaml
      pyparsing
      cryptography
      psutil
      matplotlib
    ]);
in {
  environment.systemPackages = with pkgs;
    [
      cmake
      ninja
      colcon
      pkg-config
      openssl
      eigen
      tinyxml-2
      asio
      yaml-cpp
      console-bridge
      spdlog
      gtest
      poco
      cppcheck
      curl
      libxml2
      zlib
      bzip2
      lz4
      git
      pythonWithRos2

    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      libiconv
    ];

  environment.variables =
    {
      ROS2_WS = "$HOME/ros2_jazzy";
      OPENSSL_ROOT_DIR = "${pkgs.openssl.dev}";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      DISABLE_SIP_WARNING = "1";
    };

  programs.zsh.interactiveShellInit = lib.mkIf config.programs.zsh.enable ''
    alias ros2-activate="source $HOME/ros2_jazzy/install/setup.zsh 2>/dev/null || echo 'ROS2 not built yet. Run ros2-init first.'"
  '';
}

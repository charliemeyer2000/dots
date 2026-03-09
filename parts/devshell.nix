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

    devShells.ros2 = let
      python = pkgs.python312;
      ros2Ws = "$HOME/ros2_jazzy";
      venv = "${ros2Ws}/.venv";
    in
      pkgs.mkShell {
        packages = with pkgs;
          [
            cmake
            python
            openssl
            eigen
            graphviz
            opencv
            tinyxml-2
            spdlog
            freetype
            pkg-config
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.apple-sdk_15
          ];

        env = {
          OPENSSL_ROOT_DIR = "${pkgs.openssl.dev}";
        };

        shellHook = ''
          export ROS2_WS="${ros2Ws}"

          # bootstrap venv with ROS2 python tooling if needed
          if [ ! -d "${venv}" ]; then
            echo "Creating ROS2 venv..."
            ${python}/bin/python -m venv "${venv}"
            "${venv}/bin/pip" install -q colcon-common-extensions vcstool catkin_pkg empy lark lxml \
              netifaces numpy rosdistro setuptools pytest-mock
          fi
          source "${venv}/bin/activate"

          if [ -f "${ros2Ws}/install/setup.zsh" ]; then
            source "${ros2Ws}/install/setup.zsh"
            echo "ROS2 Jazzy loaded from ${ros2Ws}"
          else
            echo "ROS2 dev shell ready. No build found yet."
            echo "  fetch:  mkdir -p ${ros2Ws}/src && cd ${ros2Ws} && vcs import --input https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos src"
            echo "  build:  cd ${ros2Ws} && colcon build --symlink-install --packages-skip-by-dep python_qt_binding"
          fi
        '';
      };
  };
}

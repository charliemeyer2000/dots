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
            # Build tools
            cmake
            ninja
            colcon
            pkg-config

            # Python and packages
            python
            python.pkgs.pip
            python.pkgs.setuptools
            python.pkgs.wheel

            # Core dependencies
            openssl
            eigen
            tinyxml-2
            asio
            yaml-cpp
            console-bridge

            # Logging and testing
            spdlog
            gtest

            # Additional ROS2 deps
            poco
            cppcheck

            # Networking
            curl
            libxml2

            # Compression
            zlib
            bzip2
            lz4

            # CLI tools
            git
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.libiconv
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.libGL
            pkgs.libGLU
            pkgs.xorg.libX11
            pkgs.xorg.libXext
            pkgs.xorg.libXrandr
            # Linux-specific tools
            pkgs.qt5.qtbase
            pkgs.graphviz
            pkgs.opencv
            pkgs.freetype
          ];

        env =
          {
            OPENSSL_ROOT_DIR = "${pkgs.openssl.dev}";
            CMAKE_PREFIX_PATH = "${pkgs.qt5.qtbase}";
          }
          // pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
            # macOS specific env vars
            MACOSX_DEPLOYMENT_TARGET = "11.0";
            # Disable System Integrity Protection warnings
            DISABLE_SIP_WARNING = "1";
          };

        shellHook = ''
          export ROS2_WS="${ros2Ws}"

          # Set up Python environment
          export PYTHONPATH="${python}/lib/python3.12/site-packages:$PYTHONPATH"

          # macOS specific setup
          ${pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
            # Ensure we use the right SDK
            export SDKROOT="$(xcrun --show-sdk-path)"
            export CPATH="$SDKROOT/usr/include"
            export LIBRARY_PATH="$SDKROOT/usr/lib"

            # Qt5 on macOS
            export QT_PLUGIN_PATH="${pkgs.qt5.qtbase}/lib/qt-5.15/plugins"
          ''}

          # Linux specific setup
          ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
            # Set up display for GUI tools
            export QT_QPA_PLATFORM_PLUGIN_PATH="${pkgs.qt5.qtbase}/lib/qt-5.15/plugins/platforms"
          ''}

          # Bootstrap venv with ROS2 python tooling if needed
          if [ ! -d "${venv}" ]; then
            echo "Creating ROS2 venv..."
            ${python}/bin/python -m venv "${venv}"
            source "${venv}/bin/activate"
            pip install --upgrade pip setuptools wheel
            pip install -q \
              colcon-common-extensions \
              vcstool \
              rosdep \
              rosdistro \
              rosinstall \
              rosinstall-generator \
              wstool \
              catkin_pkg \
              empy \
              lark \
              lxml \
              netifaces \
              numpy \
              pyparsing \
              pyyaml \
              setuptools \
              pytest \
              pytest-mock \
              flake8 \
              pep8 \
              pydocstyle \
              pyflakes \
              pytest-cov \
              pytest-runner \
              cryptography \
              ifcfg \
              matplotlib \
              psutil \
              pycryptodome \
              pydot
          else
            source "${venv}/bin/activate"
          fi

          # Check if ROS2 is built and source it
          if [ -f "${ros2Ws}/install/setup.bash" ]; then
            source "${ros2Ws}/install/setup.bash"
            echo "ROS2 Jazzy loaded from ${ros2Ws}"
          else
            echo "ROS2 dev shell ready. No build found yet."
            echo ""
            echo "To set up ROS2 Jazzy from source:"
            echo "  1. Fetch sources:"
            echo "     mkdir -p ${ros2Ws}/src"
            echo "     cd ${ros2Ws}"
            echo "     vcs import --input https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos src"
            echo ""
            echo "  2. Install additional dependencies (optional):"
            echo "     rosdep install --from-paths src --ignore-src -y --skip-keys \"fastcdr rti-connext-dds-6.0.1 urdfdom_headers\""
            echo ""
            echo "  3. Build ROS2:"
            echo "     colcon build --symlink-install --cmake-args -DBUILD_TESTING=OFF"
            echo ""
            echo "  Note: On macOS, you may need to skip Qt-dependent packages:"
            echo "     colcon build --symlink-install --packages-skip-by-dep python_qt_binding --cmake-args -DBUILD_TESTING=OFF"
          fi
        '';
      };
  };
}

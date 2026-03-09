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
      # Note: Some ROS2-specific packages like colcon-common-extensions
      # need to be installed via pip in a venv since they're not in nixpkgs
    ]);
in {
  environment.systemPackages = with pkgs;
    [
      # Build tools
      cmake
      ninja
      colcon
      pkg-config

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

      # CLI tools for ROS2
      git

      # Python with ROS2 packages
      pythonWithRos2

      # ROS2 helper scripts
      (pkgs.writeScriptBin "ros2-init" ''
        #!${pkgs.bash}/bin/bash
        set -e

        ROS2_WS="''${ROS2_WS:-$HOME/ros2_jazzy}"
        VENV="$ROS2_WS/.venv"

        echo "🤖 Initializing ROS2 environment at $ROS2_WS"

        # Create workspace
        mkdir -p "$ROS2_WS/src"

        # Set up Python virtual environment if it doesn't exist
        if [ ! -d "$VENV" ]; then
          echo "Creating Python virtual environment..."
          ${pkgs.python312}/bin/python -m venv "$VENV"
          source "$VENV/bin/activate"
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
            netifaces \
            pytest \
            pytest-mock \
            flake8 \
            pydocstyle \
            pytest-cov \
            ifcfg \
            pydot
          echo "✓ Python environment ready"
        else
          source "$VENV/bin/activate"
        fi

        # Fetch ROS2 sources if not present
        if [ ! -f "$ROS2_WS/.ros2.repos" ]; then
          echo "Fetching ROS2 Jazzy sources..."
          cd "$ROS2_WS"
          vcs import --input https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos src
          touch "$ROS2_WS/.ros2.repos"
          echo "✓ Sources fetched"
        fi

        echo ""
        echo "ROS2 environment initialized!"
        echo "To build ROS2, run:"
        echo "  cd $ROS2_WS"
        echo "  source .venv/bin/activate"
        if [[ "$OSTYPE" == "darwin"* ]]; then
          echo "  colcon build --symlink-install --packages-skip-by-dep python_qt_binding --cmake-args -DBUILD_TESTING=OFF"
        else
          echo "  colcon build --symlink-install --cmake-args -DBUILD_TESTING=OFF"
        fi
      '')

      (pkgs.writeScriptBin "ros2-shell" ''
        #!${pkgs.bash}/bin/bash
        ROS2_WS="''${ROS2_WS:-$HOME/ros2_jazzy}"

        if [ -f "$ROS2_WS/.venv/bin/activate" ]; then
          source "$ROS2_WS/.venv/bin/activate"
        fi

        if [ -f "$ROS2_WS/install/setup.bash" ]; then
          source "$ROS2_WS/install/setup.bash"
          echo "✓ ROS2 environment loaded from $ROS2_WS"
        else
          echo "⚠️  ROS2 not built yet. Run 'ros2-init' first."
        fi

        exec $SHELL
      '')
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      libiconv
    ];

  # ROS2 environment variables
  environment.variables =
    {
      ROS2_WS = "$HOME/ros2_jazzy";
      OPENSSL_ROOT_DIR = "${pkgs.openssl.dev}";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      DISABLE_SIP_WARNING = "1";
    };

  # Add ROS2 activation to shell init
  programs.zsh.interactiveShellInit = lib.mkIf config.programs.zsh.enable ''
    alias ros2-activate="source $HOME/ros2_jazzy/install/setup.zsh 2>/dev/null || echo 'ROS2 not built yet. Run ros2-init first.'"
  '';
}

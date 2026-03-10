{
  lib,
  pkgs,
  ...
}: let
  # Python environment for ROS2
  python312Env = pkgs.python312.withPackages (ps:
    with ps; [
      setuptools
      wheel
      numpy
      empy
      lark
      pyyaml
      pillow
      netifaces
      pycryptodome
      defusedxml
      pydot
      pyparsing
    ]);

  # Build dependencies
  ros2BuildDeps = with pkgs;
    [
      cmake
      ninja
      pkg-config
      openssl.dev
      eigen
      tinyxml-2
      asio
      yaml-cpp
      console-bridge
      spdlog
      fmt
      gtest
      poco
      curl
      libxml2
      zlib
      bzip2
      lz4
    ]
    ++ lib.optional stdenv.isDarwin libiconv;

  # ROS2 build script
  buildRos2Script = pkgs.writeScriptBin "ros2-ensure-built" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ROS2_HOME="$HOME/.ros2/jazzy"
    ROS2_WS="$HOME/.ros2/jazzy_ws"

    # Check if ROS2 is already built
    if [ -f "$ROS2_HOME/setup.bash" ] && [ -f "$ROS2_HOME/bin/ros2" ]; then
      echo "ROS2 Jazzy is already built at $ROS2_HOME"
      exit 0
    fi

    echo "Building ROS2 Jazzy from source..."

    # Create workspace
    mkdir -p "$ROS2_WS/src"
    cd "$ROS2_WS"

    # Set up Python virtual environment with correct Python version
    if [ ! -d ".venv" ]; then
      ${pkgs.uv}/bin/uv venv --python ${python312Env}/bin/python3.12
    fi
    source .venv/bin/activate

    # Install Python tools
    ${pkgs.uv}/bin/uv pip install --quiet \
      'setuptools<70' \
      vcstool \
      colcon-common-extensions \
      empy \
      lark \
      catkin-pkg \
      rosdep \
      numpy

    # Fetch ROS2 sources if not already present
    if [ ! -f ".repos_fetched" ]; then
      echo "Fetching ROS2 sources..."
      vcs import --input https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos src
      touch .repos_fetched
    fi

    # Set up build environment
    export CMAKE_PREFIX_PATH="${lib.concatStringsSep ":" (map (pkg: "${pkg}") ros2BuildDeps)}"
    export PKG_CONFIG_PATH="${lib.concatStringsSep ":" (map (pkg: "${pkg}/lib/pkgconfig") (builtins.filter (pkg: pkg ? lib) ros2BuildDeps))}"

    # Individual package paths for CMake
    export OPENSSL_ROOT_DIR="${pkgs.openssl.dev}"
    export TinyXML2_DIR="${pkgs.tinyxml-2}"
    export YAML_CPP_DIR="${pkgs.yaml-cpp}"
    export console_bridge_DIR="${pkgs.console-bridge}"
    export spdlog_DIR="${pkgs.spdlog}"
    export fmt_DIR="${pkgs.fmt}"

    # Build ROS2
    echo "Building ROS2 packages (this will take 30-60 minutes on first run)..."
    colcon build \
      --install-base "$ROS2_HOME" \
      --merge-install \
      --packages-skip rosidl_generator_rs \
      --packages-skip-by-dep python_qt_binding \
      --cmake-args \
        -DBUILD_TESTING=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DPython3_EXECUTABLE="$VIRTUAL_ENV/bin/python" \
      --parallel-workers 4 \
      --event-handlers console_cohesion+ \
      --continue-on-error

    echo "ROS2 build complete!"
    echo "Built $(ls $ROS2_HOME/share/ | wc -l) packages"
  '';
in {
  # Install build dependencies
  environment.systemPackages =
    ros2BuildDeps
    ++ [
      python312Env
      buildRos2Script
      pkgs.colcon
      pkgs.vcstool
      pkgs.uv
    ];

  # Set up environment
  environment.variables = {
    ROS_DISTRO = "jazzy";
    ROS_VERSION = "2";
    ROS_PYTHON_VERSION = "3";
  };

  # Source ROS2 setup in shell
  programs.zsh.interactiveShellInit = ''
    # Source ROS2 setup if available
    if [ -f "$HOME/.ros2/jazzy/setup.zsh" ]; then
      source "$HOME/.ros2/jazzy/setup.zsh" 2>/dev/null || true
    elif [ -f "$HOME/.ros2/jazzy/setup.bash" ]; then
      source "$HOME/.ros2/jazzy/setup.bash" 2>/dev/null || true
    fi
  '';

  # Activation script to ensure ROS2 is built
  system.activationScripts.ros2.text = ''
    echo "Ensuring ROS2 is built..."
    # Run in background to not block activation
    (
      ${buildRos2Script}/bin/ros2-ensure-built &>/tmp/ros2-build.log &
    ) || true
    echo "ROS2 build started in background. Check /tmp/ros2-build.log for progress."
  '';
}

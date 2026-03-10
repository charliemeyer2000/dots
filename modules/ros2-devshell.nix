# ROS2 Development Shell Module
# Provides a nix-managed environment for building and running ROS2
# This doesn't build ROS2 itself but provides all dependencies and tooling
{
  config,
  lib,
  pkgs,
  ...
}: {
  # ROS2 build dependencies and development tools
  environment.systemPackages = with pkgs;
    [
      # Build tools
      cmake
      ninja
      colcon
      pkg-config
      uv # Python package manager

      # Core dependencies
      openssl
      eigen
      tinyxml-2
      asio
      yaml-cpp
      console-bridge
      spdlog
      fmt
      gtest
      poco

      # System libraries
      curl
      libxml2
      zlib
      bzip2
      lz4
      zstd # For zstd_vendor
      sqlite # For sqlite3_vendor
      libyaml # For libyaml_vendor
      orocos-kdl # For orocos_kdl_vendor
      assimp # For rviz_assimp_vendor
      ogre # For rviz_ogre_vendor
      # mcap not available in nix - vendor will build from source

      # Python 3.12 explicitly (3.13+ removed pkg_resources)
      python312
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      libiconv
    ];

  # ROS2 environment variables
  environment.variables =
    {
      ROS_DISTRO = "jazzy";
      ROS_VERSION = "2";
      # Point to where ROS2 will be built/installed
      ROS2_INSTALL_PATH = "$HOME/.ros2/jazzy";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      DISABLE_SIP_WARNING = "1";
    };

  # Shell initialization
  programs.zsh.interactiveShellInit = lib.mkIf config.programs.zsh.enable ''
    # Function to build ROS2 from source
    function ros2-build-from-source() {
      local ROS2_WS="$HOME/.ros2/jazzy_ws"

      echo "🤖 Building ROS2 Jazzy from source..."
      echo "This will take 30-60 minutes on first build."

      # Create workspace
      mkdir -p "$ROS2_WS/src"
      cd "$ROS2_WS"

      # Create Python virtual environment with correct Python version
      if [ ! -d ".venv" ]; then
        echo "Creating Python 3.12 virtual environment..."
        ${pkgs.uv}/bin/uv venv --python ${pkgs.python312}/bin/python3.12
      fi
      source .venv/bin/activate

      # Install Python tools with compatible versions
      echo "Installing ROS2 Python tools..."
      ${pkgs.uv}/bin/uv pip install -q \
        'setuptools<70' \
        vcstool \
        empy \
        lark \
        catkin-pkg \
        rosdep \
        rosdistro \
        numpy

      # Install colcon separately to avoid entrypoint issues
      ${pkgs.uv}/bin/uv pip install -q colcon-common-extensions || true

      # Fetch sources if not already present
      if [ ! -f ".repos_fetched" ]; then
        echo "Fetching ROS2 sources (this takes 5-10 minutes)..."
        vcs import --input https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos src
        touch .repos_fetched
      fi

      # Build - Set up all Nix paths for CMake discovery
      echo "Setting up Nix package paths for CMake..."

      # Copy custom Find modules to make nix packages discoverable
      echo "Installing custom CMake Find modules..."
      mkdir -p ~/.ros2/cmake
      if [ -d "$HOME/all/dots/config/cmake" ]; then
        cp -r $HOME/all/dots/config/cmake/*.cmake ~/.ros2/cmake/
      fi

      # Critical: Set CMAKE_PREFIX_PATH so CMake's find_package works
      export CMAKE_PREFIX_PATH="${lib.concatStringsSep ":" [
      "${pkgs.openssl.dev}"
      "${pkgs.tinyxml-2}"
      "${pkgs.eigen}"
      "${pkgs.yaml-cpp}"
      "${pkgs.console-bridge}"
      "${pkgs.spdlog}"
      "${pkgs.fmt}"
      "${pkgs.curl.dev}"
      "${pkgs.libxml2.dev}"
      "${pkgs.zlib.dev}"
      "${pkgs.bzip2.dev}"
      "${pkgs.lz4.dev}"
      "${pkgs.poco.dev}"
      "${pkgs.zstd.dev}"
      "${pkgs.sqlite.dev}"
      "${pkgs.libyaml}"
      "${pkgs.orocos-kdl}"
      "${pkgs.assimp}"
      "${pkgs.ogre}"
    ]}"

      # Set PKG_CONFIG_PATH for packages that use pkg-config
      export PKG_CONFIG_PATH="${lib.concatStringsSep ":" [
      "${pkgs.openssl.dev}/lib/pkgconfig"
      "${pkgs.tinyxml-2}/lib/pkgconfig"
      "${pkgs.curl.dev}/lib/pkgconfig"
      "${pkgs.libxml2.dev}/lib/pkgconfig"
      "${pkgs.zlib.dev}/lib/pkgconfig"
      "${pkgs.yaml-cpp}/lib/pkgconfig"
      "${pkgs.console-bridge}/lib/pkgconfig"
    ]}"

      # Set individual package variables that some CMake scripts expect
      export OPENSSL_ROOT_DIR="${pkgs.openssl.dev}"
      export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
      export OPENSSL_LIBRARIES="${pkgs.openssl.out}/lib"

      # TinyXML2 paths
      export TinyXML2_DIR="${pkgs.tinyxml-2}"
      export tinyxml2_DIR="${pkgs.tinyxml-2}"  # Some packages look for lowercase
      export TINYXML2_INCLUDE_DIR="${pkgs.tinyxml-2}/include"
      export TINYXML2_LIBRARY="${pkgs.tinyxml-2}/lib/libtinyxml2${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}"

      # Other commonly needed paths
      export EIGEN3_ROOT_DIR="${pkgs.eigen}"
      export YAML_CPP_DIR="${pkgs.yaml-cpp}"
      export CURL_DIR="${pkgs.curl.dev}"
      export LibXml2_DIR="${pkgs.libxml2.dev}"
      export ZLIB_ROOT="${pkgs.zlib.dev}"
      export BZip2_DIR="${pkgs.bzip2.dev}"
      export LZ4_DIR="${pkgs.lz4.dev}"
      export ZSTD_DIR="${pkgs.zstd.dev}"
      export SQLITE3_DIR="${pkgs.sqlite.dev}"
      export LIBYAML_DIR="${pkgs.libyaml}"
      export orocos_kdl_DIR="${pkgs.orocos-kdl}"
      export assimp_DIR="${pkgs.assimp}"
      export OGRE_DIR="${pkgs.ogre}"

      # Vendor packages look for these specific environment variables
      export lz4_DIR="${pkgs.lz4.dev}"
      export zstd_DIR="${pkgs.zstd.dev}"
      export sqlite3_DIR="${pkgs.sqlite.dev}"
      export yaml_DIR="${pkgs.libyaml}"
      export Ogre_DIR="${pkgs.ogre}"  # Some packages look for capital O

      # Build ROS2 - skip Qt packages and Rust generator on macOS
      # Let vendor packages build if they can't find system libraries
      colcon build \
        --install-base "$HOME/.ros2/jazzy" \
        --merge-install \
        --packages-skip-by-dep python_qt_binding \
        --packages-skip qt_gui_cpp rqt_gui_cpp rosidl_generator_rs \
        --cmake-args \
          -DBUILD_TESTING=OFF \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH" \
          -DCMAKE_MODULE_PATH="$HOME/.ros2/cmake" \
          -DPKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
        --continue-on-error

      echo "✅ ROS2 built to $HOME/.ros2/jazzy"
    }

    # Source ROS2 if it's installed
    if [ -f "$HOME/.ros2/jazzy/setup.zsh" ]; then
      source "$HOME/.ros2/jazzy/setup.zsh"

      # Convenience aliases
      alias ros2-check="ros2 doctor --report"
      alias ros2-topics="ros2 topic list"
      alias ros2-nodes="ros2 node list"
    elif [ -f "$HOME/ros2_jazzy/install/setup.zsh" ]; then
      # Fall back to existing installation if present
      source "$HOME/ros2_jazzy/install/setup.zsh"

      alias ros2-check="ros2 doctor --report"
      alias ros2-topics="ros2 topic list"
      alias ros2-nodes="ros2 node list"
    else
      echo "ROS2 not found. Run 'ros2-build-from-source' to build it."
    fi
  '';
}

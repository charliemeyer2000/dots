# Simple ROS2 module that sources existing build
{pkgs, ...}: {
  # Install build dependencies
  environment.systemPackages = with pkgs;
    [
      # Build tools
      cmake
      ninja
      colcon
      vcstool
      pkg-config
      uv

      # Python
      python312

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
      curl
      libxml2
      zlib
      bzip2
      lz4
    ]
    ++ pkgs.lib.optional pkgs.stdenv.isDarwin pkgs.libiconv;

  # Set up environment
  environment.variables = {
    ROS_DISTRO = "jazzy";
    ROS_VERSION = "2";
    ROS_PYTHON_VERSION = "3";
  };

  # Source ROS2 if it exists
  programs.zsh.interactiveShellInit = ''
    # Source ROS2 if available
    if [ -f "$HOME/.ros2/jazzy/setup.zsh" ]; then
      source "$HOME/.ros2/jazzy/setup.zsh" 2>/dev/null || true
    elif [ -f "$HOME/.ros2/jazzy/setup.bash" ]; then
      source "$HOME/.ros2/jazzy/setup.bash" 2>/dev/null || true
    fi

    # Add convenient alias
    alias ros2-source='source ~/.ros2/jazzy/setup.zsh'
  '';

  programs.bash.interactiveShellInit = ''
    # Source ROS2 if available
    if [ -f "$HOME/.ros2/jazzy/setup.bash" ]; then
      source "$HOME/.ros2/jazzy/setup.bash" 2>/dev/null || true
    fi

    # Add convenient alias
    alias ros2-source='source ~/.ros2/jazzy/setup.bash'
  '';
}

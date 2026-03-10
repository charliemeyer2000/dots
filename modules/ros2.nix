{pkgs, ...}: let
  # Import our custom ROS2 derivation
  ros2-jazzy = pkgs.callPackage ../pkgs/ros2-jazzy-full.nix {};
in {
  # Install ROS2 system-wide
  environment.systemPackages = [ros2-jazzy];

  # Set up environment variables
  environment.variables = {
    ROS_DISTRO = "jazzy";
    ROS_VERSION = "2";
    ROS_PYTHON_VERSION = "3";
  };

  # Shell setup for interactive use
  programs.zsh.interactiveShellInit = ''
    # Source ROS2 setup if available
    if [ -f "${ros2-jazzy}/setup.sh" ]; then
      source "${ros2-jazzy}/setup.sh"
    fi
  '';

  programs.bash.interactiveShellInit = ''
    # Source ROS2 setup if available
    if [ -f "${ros2-jazzy}/setup.sh" ]; then
      source "${ros2-jazzy}/setup.sh"
    fi
  '';
}

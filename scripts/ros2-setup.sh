#!/usr/bin/env bash
set -euo pipefail

ROS2_WS="${ROS2_WS:-$HOME/ros2_jazzy}"
ROS_DISTRO="jazzy"

echo "🤖 ROS2 $ROS_DISTRO Setup Script"
echo "Workspace: $ROS2_WS"
echo

# Create workspace directory
mkdir -p "$ROS2_WS/src"
cd "$ROS2_WS"

# Fetch ROS2 sources
if [ ! -f "$ROS2_WS/.ros2.repos" ]; then
    echo "📦 Fetching ROS2 $ROS_DISTRO sources..."
    vcs import --input "https://raw.githubusercontent.com/ros2/ros2/$ROS_DISTRO/ros2.repos" src
    touch "$ROS2_WS/.ros2.repos"
else
    echo "✓ Sources already fetched. Run 'vcs pull src' to update."
fi

# macOS specific build configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Detected macOS - configuring build..."

    # Skip packages that have issues on macOS
    SKIP_PACKAGES="--packages-skip-by-dep python_qt_binding"

    # Additional CMake args for macOS
    CMAKE_ARGS="-DBUILD_TESTING=OFF -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0"

    if [ -z "${DISABLE_SIP_WARNING:-}" ]; then
        echo
        echo "⚠️  Warning: System Integrity Protection (SIP) can cause issues."
        echo "   If you encounter 'System Integrity Protection' errors during build,"
        echo "   you may need to disable SIP (at your own risk)."
        echo
    fi
else
    # Linux build configuration
    SKIP_PACKAGES=""
    CMAKE_ARGS="-DBUILD_TESTING=OFF"
fi

# Build ROS2
echo "🔨 Building ROS2 (this may take 30-60 minutes on first build)..."
echo "   Command: colcon build --symlink-install $SKIP_PACKAGES --cmake-args $CMAKE_ARGS"
echo

read -p "Continue with build? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # shellcheck disable=SC2086
    if colcon build --symlink-install $SKIP_PACKAGES --cmake-args $CMAKE_ARGS; then
        echo
        echo "✅ ROS2 $ROS_DISTRO built successfully!"
        echo
        echo "To use ROS2 in a new shell:"
        echo "  nix develop .#ros2"
        echo
        echo "The environment will automatically source:"
        echo "  $ROS2_WS/install/setup.bash"
    else
        echo "❌ Build failed. Check the output above for errors."
        exit 1
    fi
else
    echo "Build cancelled."
    echo
    echo "To build manually, run:"
    echo "  cd $ROS2_WS"
    echo "  colcon build --symlink-install $SKIP_PACKAGES --cmake-args $CMAKE_ARGS"
fi
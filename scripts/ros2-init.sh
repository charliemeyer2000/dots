#!/usr/bin/env bash
set -e

ROS2_WS="${ROS2_WS:-$HOME/ros2_jazzy}"
VENV="$ROS2_WS/.venv"

echo "Initializing ROS2 environment at $ROS2_WS"

mkdir -p "$ROS2_WS/src"

if [ ! -d "$VENV" ]; then
  echo "Creating Python virtual environment..."
  python3 -m venv "$VENV"
  # shellcheck source=/dev/null
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
  echo "Python environment ready"
else
  # shellcheck source=/dev/null
  source "$VENV/bin/activate"
fi

if [ ! -f "$ROS2_WS/.ros2.repos" ]; then
  echo "Fetching ROS2 Jazzy sources..."
  cd "$ROS2_WS"
  vcs import --input https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos src
  touch "$ROS2_WS/.ros2.repos"
  echo "Sources fetched"
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
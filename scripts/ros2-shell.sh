#!/usr/bin/env bash
ROS2_WS="${ROS2_WS:-$HOME/ros2_jazzy}"

if [ -f "$ROS2_WS/.venv/bin/activate" ]; then
  source "$ROS2_WS/.venv/bin/activate"
fi

if [ -f "$ROS2_WS/install/setup.bash" ]; then
  source "$ROS2_WS/install/setup.bash"
  echo "ROS2 environment loaded from $ROS2_WS"
else
  echo "ROS2 not built yet. Run 'ros2-init' first."
fi

exec $SHELL
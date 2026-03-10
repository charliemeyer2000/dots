# ROS2 Jazzy Build from Source - Issues and Solutions

## Critical: Nix Package Discovery Fix

**The Root Issue**: CMake cannot find Nix packages because they're in `/nix/store/hash-package/` paths.

**The Solution**: Properly set CMAKE_PREFIX_PATH and PKG_CONFIG_PATH, plus individual package variables:
```bash
export CMAKE_PREFIX_PATH="/nix/store/openssl:/nix/store/tinyxml2:..."
export PKG_CONFIG_PATH="/nix/store/openssl/lib/pkgconfig:..."
export OPENSSL_ROOT_DIR="/nix/store/openssl"
# etc for each package
```

Without this, builds fall back to Homebrew (bad!) or fail completely.

## Key Issues Encountered and Fixed

### 1. Python Version Compatibility
**Issue**: Python 3.13 removed `pkg_resources` which vcstool depends on.
**Solution**: Use Python 3.12 explicitly:
```bash
uv venv --python python3.12
```

### 2. Setuptools Version
**Issue**: setuptools 82+ removed `pkg_resources` module
**Solution**: Downgrade to setuptools < 70:
```bash
uv pip install 'setuptools<70'
```

### 3. NumPy Headers for Python Extensions
**Issue**: Python extensions fail to build due to missing NumPy headers
**Solution**: Install NumPy in the virtual environment:
```bash
uv pip install numpy
```

### 4. Rust Generator Causes builtin_interfaces Failure
**Issue**: rosidl_generator_rs fails with "TransientParseError when expanding 'rmw.rs.em'"
**Solution**: Skip the Rust generator entirely:
```bash
--packages-skip rosidl_generator_rs
```

### 5. Vendor Package CMake Policy Issues
**Issue**: yaml_cpp_vendor, liblz4_vendor, zstd_vendor fail with CMake minimum version issues
**Solution**: Skip these vendor packages and use system versions or let other packages handle dependencies:
```bash
--packages-skip yaml_cpp_vendor liblz4_vendor zstd_vendor sqlite3_vendor libcurl_vendor
```

### 6. Qt Dependencies on macOS
**Issue**: Qt packages require Qt6 which isn't available in our Nix environment
**Solution**: Skip all Qt-related packages:
```bash
--packages-skip-by-dep python_qt_binding
--packages-skip qt_gui_cpp rqt_gui_cpp
```

### 7. Colcon Build Arguments
**Issue**: Incorrect argument order for colcon
**Solution**: Put package skip flags before cmake args:
```bash
colcon build \
  --install-base "$HOME/.ros2/jazzy" \
  --merge-install \
  --packages-skip-by-dep python_qt_binding \
  --packages-skip qt_gui_cpp rqt_gui_cpp rosidl_generator_rs \
  --packages-skip yaml_cpp_vendor liblz4_vendor zstd_vendor \
  --cmake-args -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release \
  --continue-on-error
```

### 8. Build Dependencies via Nix
All system dependencies are managed through nix:
- cmake, ninja, colcon, pkg-config
- openssl, eigen, tinyxml-2, asio, yaml-cpp
- console-bridge, spdlog, fmt, gtest, poco
- curl, libxml2, zlib, bzip2, lz4
- libiconv (macOS)
- Python 3.12 (for avoiding pkg_resources issues)

## Complete Build Process

1. **Setup workspace**:
```bash
mkdir -p ~/.ros2/jazzy_ws/src
cd ~/.ros2/jazzy_ws
```

2. **Create Python environment with correct version**:
```bash
uv venv --python python3.12
source .venv/bin/activate
```

3. **Install Python tools with compatible versions**:
```bash
uv pip install 'setuptools<70' vcstool colcon-common-extensions empy lark catkin-pkg rosdep
```

4. **Fetch ROS2 sources** (takes 5-10 minutes):
```bash
vcs import --input https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos src
```

5. **Build ROS2** (takes 30-60 minutes):
```bash
export OPENSSL_ROOT_DIR="${openssl.dev}"  # From nix
colcon build \
  --install-base "$HOME/.ros2/jazzy" \
  --merge-install \
  --packages-skip-by-dep python_qt_binding \
  --packages-skip qt_gui_cpp rqt_gui_cpp \
  --cmake-args -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release
```

## Environment Setup
After build, source the setup script:
```bash
source ~/.ros2/jazzy/setup.zsh
```

## Notes for Future Agents
- Always use Python 3.12, not 3.13+
- Always use setuptools < 70
- Always create a virtual environment for Python tools
- The build takes significant time and resources
- macOS requires skipping Qt-related packages
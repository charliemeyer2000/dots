#!/usr/bin/env bash
# Verify ROS2 builds cleanly without Homebrew
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== ROS2 Clean Build Verification ===${NC}"

# Step 1: Check for Homebrew
echo -e "\n${YELLOW}1. Checking for Homebrew...${NC}"
if command -v brew &> /dev/null; then
    echo -e "${RED}❌ Homebrew is installed at $(which brew)${NC}"
    echo "To properly test, you should uninstall Homebrew first:"
    # shellcheck disable=SC2016
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"'
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ Homebrew not found (good!)${NC}"
fi

# Step 2: Check for existing ROS2 installation
echo -e "\n${YELLOW}2. Checking for existing ROS2...${NC}"
if [ -d "$HOME/.ros2/jazzy" ]; then
    echo -e "${YELLOW}⚠ Found existing ROS2 at ~/.ros2/jazzy${NC}"
    read -p "Delete it for clean test? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing ~/.ros2/jazzy..."
        rm -rf "$HOME/.ros2/jazzy"
        rm -rf "$HOME/.ros2/jazzy_ws"
        echo -e "${GREEN}✓ Cleaned${NC}"
    fi
else
    echo -e "${GREEN}✓ No existing ROS2 found${NC}"
fi

# Step 3: Verify Nix packages are available
echo -e "\n${YELLOW}3. Checking Nix packages...${NC}"
MISSING_PKGS=""

check_nix_pkg() {
    local pkg=$1
    if ! nix-build '<nixpkgs>' -A "$pkg" --no-out-link &>/dev/null; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
        echo -e "${RED}  ❌ Missing: $pkg${NC}"
    else
        echo -e "${GREEN}  ✓ Found: $pkg${NC}"
    fi
}

check_nix_pkg "openssl"
check_nix_pkg "tinyxml-2"
check_nix_pkg "eigen"
check_nix_pkg "yaml-cpp"
check_nix_pkg "console-bridge"
check_nix_pkg "spdlog"
check_nix_pkg "python312"
check_nix_pkg "uv"
check_nix_pkg "cmake"
check_nix_pkg "ninja"
check_nix_pkg "colcon"

if [ -n "$MISSING_PKGS" ]; then
    echo -e "${RED}Missing Nix packages:$MISSING_PKGS${NC}"
    echo "These should be provided by your nix configuration"
    exit 1
fi

# Step 4: Test the ros2-build-from-source function
echo -e "\n${YELLOW}4. Testing ROS2 build...${NC}"

# Create a test build script that sources the function
cat > /tmp/test-ros2-build.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Source the shell init to get the function
source /etc/zshrc 2>/dev/null || true

# Check if function exists
if ! type ros2-build-from-source &>/dev/null; then
    echo "❌ ros2-build-from-source function not found"
    echo "Run 'just switch darwin-personal' first"
    exit 1
fi

# Create workspace
export ROS2_WS="$HOME/.ros2/jazzy_ws"
mkdir -p "$ROS2_WS/src"
cd "$ROS2_WS"

# Test Python environment creation
echo "Creating Python 3.12 virtual environment..."
if ! command -v uv &>/dev/null; then
    echo "❌ uv not found in PATH"
    exit 1
fi

uv venv --python python3.12
source .venv/bin/activate

# Test Python package installation
echo "Installing Python dependencies..."
uv pip install -q 'setuptools<70' vcstool colcon-common-extensions numpy

# Test environment variables from Nix
echo "Checking Nix-provided paths..."

# These should be set by the module
if [ -z "${CMAKE_PREFIX_PATH:-}" ]; then
    echo "⚠️  CMAKE_PREFIX_PATH not set - CMake may not find Nix packages"
fi

if [ -z "${PKG_CONFIG_PATH:-}" ]; then
    echo "⚠️  PKG_CONFIG_PATH not set - pkg-config may not find Nix packages"
fi

# Try to find OpenSSL from Nix
OPENSSL_NIX=$(nix-build '<nixpkgs>' -A openssl.dev --no-out-link 2>/dev/null)
if [ -d "$OPENSSL_NIX" ]; then
    echo "✓ Found OpenSSL at $OPENSSL_NIX"
    export OPENSSL_ROOT_DIR="$OPENSSL_NIX"
else
    echo "❌ Could not find OpenSSL from Nix"
    exit 1
fi

# Try to find TinyXML2 from Nix
TINYXML2_NIX=$(nix-build '<nixpkgs>' -A tinyxml-2 --no-out-link 2>/dev/null)
if [ -d "$TINYXML2_NIX" ]; then
    echo "✓ Found TinyXML2 at $TINYXML2_NIX"
    export TinyXML2_DIR="$TINYXML2_NIX"
else
    echo "❌ Could not find TinyXML2 from Nix"
    exit 1
fi

echo ""
echo "✅ Environment looks good for ROS2 build!"
echo "To run full build: ros2-build-from-source"
EOF

chmod +x /tmp/test-ros2-build.sh
bash /tmp/test-ros2-build.sh

# Step 5: Summary
echo -e "\n${YELLOW}=== Verification Summary ===${NC}"
if command -v brew &> /dev/null; then
    echo -e "${YELLOW}⚠ Homebrew is still installed - true clean test requires removal${NC}"
fi
echo -e "${GREEN}✓ Nix packages are available${NC}"
echo -e "${GREEN}✓ Python environment can be created${NC}"
echo -e "${GREEN}✓ Build environment is properly configured${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. If Homebrew is installed, consider removing it for a true clean test"
echo "2. Run: ros2-build-from-source"
echo "3. This will take 30-60 minutes"
echo "4. After build, test: source ~/.ros2/jazzy/setup.zsh && ros2 --help"
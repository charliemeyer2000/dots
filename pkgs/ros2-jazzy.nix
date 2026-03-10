{
  lib,
  stdenv,
  fetchFromGitHub,
  python312,
  cmake,
  ninja,
  pkg-config,
  openssl,
  eigen,
  tinyxml-2,
  asio,
  yaml-cpp,
  console-bridge,
  spdlog,
  fmt,
  gtest,
  poco,
  curl,
  libxml2,
  zlib,
  bzip2,
  lz4,
  libiconv,
  makeWrapper,
  cacert,
  git,
}: let
  # Python packages needed for build
  pythonPackages = python312.pkgs;

  # Custom vcstool that works
  vcstool = pythonPackages.buildPythonPackage rec {
    pname = "vcstool";
    version = "0.3.0";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-4oSqPcXRNVdIWhPdFVKMW64zXrqCQ1kJbOiU7oqQQPY=";
    };

    propagatedBuildInputs = with pythonPackages; [
      pyyaml
      setuptools
    ];
  };

  # Custom colcon packages
  colcon-core = pythonPackages.buildPythonPackage rec {
    pname = "colcon-core";
    version = "0.17.1";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-Vb5+IHcAo8s5lBjnquHRoX+tRLJcE/6IF3saGWxyPPU=";
    };

    propagatedBuildInputs = with pythonPackages; [
      empy
      pytest
      pytest-timeout
      pytest-repeat
      setuptools
      distlib
    ];
  };

  colcon-common-extensions = pythonPackages.buildPythonPackage rec {
    pname = "colcon-common-extensions";
    version = "0.3.0";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-NxoRlYBGh4PJA3gKHnFOQgfQC9LqwZvtXZhJ0vhkBBM=";
    };

    propagatedBuildInputs = with pythonPackages; [
      colcon-core
      setuptools
    ];
  };

  # Python environment for building
  pythonEnv = python312.withPackages (ps:
    [
      vcstool
      colcon-core
      colcon-common-extensions
    ]
    ++ (with ps; [
      setuptools
      wheel
      numpy
      empy
      lark
      catkin-pkg
      pyyaml
      pillow
      netifaces
      pycryptodome
      defusedxml
      pydot
      pyparsing
      pytest
      flake8
      pep257
      mypy
    ]));

  # Pre-fetched ROS2 sources as fixed-output derivation
  ros2Sources = stdenv.mkDerivation {
    pname = "ros2-jazzy-sources";
    version = "jazzy";

    nativeBuildInputs = [git vcstool cacert];

    # Dummy source
    src = fetchFromGitHub {
      owner = "ros2";
      repo = "ros2";
      rev = "jazzy";
      sha256 = "046pnxry16ssv9f0qz144dl0wrdcz2nhfv8xilh218hwa92kslm5";
    };

    buildPhase = ''
      export HOME=$TMPDIR
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt

      mkdir -p $out/src
      cd $out

      # Fetch all ROS2 repositories
      ${vcstool}/bin/vcs import --shallow --input https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos src || true

      # Remove .git directories to save space
      find $out -type d -name .git -exec rm -rf {} + || true
    '';

    installPhase = ''
      # Already in $out
      echo "Sources fetched to $out/src"
    '';

    outputHashMode = "recursive";
    outputHash = lib.fakeHash;
  };
in
  stdenv.mkDerivation rec {
    pname = "ros2-jazzy";
    version = "jazzy-2024.03";

    # Use pre-fetched sources
    src = ros2Sources;

    nativeBuildInputs = [
      cmake
      ninja
      pkg-config
      pythonEnv
      makeWrapper
    ];

    buildInputs =
      [
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

    # Configure phase
    configurePhase = ''
      export HOME=$TMPDIR
      export PYTHONPATH=${pythonEnv}/${python312.sitePackages}:$PYTHONPATH

      # Copy sources to build directory
      cp -r $src/src .

      # Set up paths for CMake to find Nix packages
      export CMAKE_PREFIX_PATH="${lib.concatStringsSep ":" [
        "${openssl.dev}"
        "${eigen}/share/eigen3/cmake"
        "${tinyxml-2}"
        "${yaml-cpp}"
        "${console-bridge}"
        "${spdlog}"
        "${fmt}"
        "${gtest}"
        "${poco}"
        "${curl}"
      ]}"

      export PKG_CONFIG_PATH="${lib.concatStringsSep ":" [
        "${openssl.dev}/lib/pkgconfig"
        "${tinyxml-2}/lib/pkgconfig"
        "${yaml-cpp}/lib/pkgconfig"
        "${curl}/lib/pkgconfig"
      ]}"

      # Set individual package variables
      export OPENSSL_ROOT_DIR="${openssl.dev}"
      export TinyXML2_DIR="${tinyxml-2}"
      export Eigen3_DIR="${eigen}/share/eigen3/cmake"
      export console_bridge_DIR="${console-bridge}"
    '';

    # Build phase using colcon
    buildPhase = ''
      runHook preBuild

      echo "Building ROS2 with colcon..."

      # Build with colcon
      ${pythonEnv}/bin/colcon build \
        --install-base $out \
        --merge-install \
        --packages-skip rosidl_generator_rs \
        --packages-skip-by-dep python_qt_binding \
        --packages-skip qt_gui_cpp rqt_gui_cpp \
        --cmake-args \
          -DBUILD_TESTING=OFF \
          -DCMAKE_BUILD_TYPE=Release \
          -DPython3_EXECUTABLE=${pythonEnv}/bin/python \
          -DPython3_INCLUDE_DIR=${python312}/include/python${python312.pythonVersion} \
          -DPython3_LIBRARY=${python312}/lib/libpython${python312.pythonVersion}.dylib \
        --parallel-workers $NIX_BUILD_CORES

      runHook postBuild
    '';

    # Install phase - wrap binaries and create setup scripts
    installPhase = ''
      runHook preInstall

      # Wrap Python scripts and binaries
      for f in $out/bin/*; do
        if [[ -f "$f" && -x "$f" ]]; then
          wrapProgram "$f" \
            --prefix PATH : ${lib.makeBinPath [pythonEnv]} \
            --prefix PYTHONPATH : "$out/lib/python${python312.pythonVersion}/site-packages:${pythonEnv}/${python312.sitePackages}" \
            --set ROS_DISTRO jazzy \
            --set ROS_VERSION 2 \
            --set ROS_PYTHON_VERSION 3 \
            --set AMENT_PREFIX_PATH "$out"
        fi
      done

      # Create environment setup script
      cat > $out/setup.sh << EOF
      export ROS_DISTRO=jazzy
      export ROS_VERSION=2
      export ROS_PYTHON_VERSION=3
      export ROS_PACKAGE_PATH="$out/share"
      export AMENT_PREFIX_PATH="$out:\$AMENT_PREFIX_PATH"
      export CMAKE_PREFIX_PATH="$out:\$CMAKE_PREFIX_PATH"
      export PATH="$out/bin:\$PATH"
      export PYTHONPATH="$out/lib/python${python312.pythonVersion}/site-packages:\$PYTHONPATH"
      export LD_LIBRARY_PATH="$out/lib:\$LD_LIBRARY_PATH"
      EOF

      # Create a simple test to verify installation
      cat > $out/bin/ros2-test << EOF
      #!${stdenv.shell}
      echo "Testing ROS2 installation..."
      $out/bin/ros2 --version
      EOF
      chmod +x $out/bin/ros2-test

      runHook postInstall
    '';

    meta = with lib; {
      description = "Robot Operating System 2 (ROS2) Jazzy";
      homepage = "https://docs.ros.org/en/jazzy/";
      license = licenses.asl20;
      platforms = platforms.unix;
      maintainers = [];
    };
  }

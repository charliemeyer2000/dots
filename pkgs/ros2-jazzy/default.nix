{
  lib,
  stdenv,
  fetchFromGitHub,
  python312,
  cmake,
  ninja,
  colcon,
  vcstool,
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
}: let
  pythonEnv = python312.withPackages (ps:
    with ps; [
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
      colcon-core
      colcon-common-extensions
    ]);

  # ROS2 repos file
  ros2ReposUrl = "https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos";
in
  stdenv.mkDerivation rec {
    pname = "ros2-jazzy";
    version = "jazzy";

    src = fetchFromGitHub {
      owner = "ros2";
      repo = "ros2";
      rev = "jazzy";
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      fetchSubmodules = false;
    };

    nativeBuildInputs = [
      cmake
      ninja
      colcon
      vcstool
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

    # Fetch all ROS2 sources
    preBuild = ''
      export HOME=$TMPDIR
      mkdir -p src
      ${vcstool}/bin/vcs import --input ${ros2ReposUrl} src < /dev/null || true

      # Set up Python environment
      export PYTHONPATH=${pythonEnv}/${python312.sitePackages}:$PYTHONPATH
    '';

    # Build with colcon
    buildPhase = ''
      runHook preBuild

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
      ]}"

      export PKG_CONFIG_PATH="${lib.concatStringsSep ":" [
        "${openssl.dev}/lib/pkgconfig"
        "${tinyxml-2}/lib/pkgconfig"
        "${yaml-cpp}/lib/pkgconfig"
      ]}"

      # Build ROS2 (skip problematic packages)
      ${colcon}/bin/colcon build \
        --install-base $out \
        --merge-install \
        --packages-skip rosidl_generator_rs \
        --packages-skip-by-dep python_qt_binding \
        --cmake-args \
          -DBUILD_TESTING=OFF \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=$out \
          -DPython3_EXECUTABLE=${pythonEnv}/bin/python \
        --parallel-workers $NIX_BUILD_CORES \
        --event-handlers console_direct-

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # Colcon already installed to $out, just need to wrap binaries
      for f in $out/bin/*; do
        if [[ -x "$f" && ! -d "$f" ]]; then
          wrapProgram $f \
            --prefix PATH : ${lib.makeBinPath [pythonEnv]} \
            --prefix PYTHONPATH : "$out/lib/python${python312.pythonVersion}/site-packages" \
            --set-default ROS_DISTRO jazzy \
            --set-default ROS_VERSION 2 \
            --set-default ROS_PYTHON_VERSION 3
        fi
      done

      # Create setup script for sourcing
      mkdir -p $out/etc/profile.d
      cat > $out/etc/profile.d/ros2.sh << 'EOF'
      export ROS_DISTRO=jazzy
      export ROS_VERSION=2
      export ROS_PYTHON_VERSION=3
      export PATH="$out/bin:$PATH"
      export PYTHONPATH="$out/lib/python${python312.pythonVersion}/site-packages:$PYTHONPATH"
      export CMAKE_PREFIX_PATH="$out:$CMAKE_PREFIX_PATH"
      export AMENT_PREFIX_PATH="$out:$AMENT_PREFIX_PATH"
      EOF

      runHook postInstall
    '';

    meta = with lib; {
      description = "ROS 2 Jazzy - Robot Operating System";
      homepage = "https://www.ros.org/";
      license = licenses.asl20;
      maintainers = [];
      platforms = platforms.unix;
    };
  }

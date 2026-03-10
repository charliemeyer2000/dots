# Colcon build tools for ROS2
{
  python3Packages,
  fetchPypi,
}: let
  colcon-core = python3Packages.buildPythonPackage rec {
    pname = "colcon-core";
    version = "0.18.3";
    pyproject = true;

    src = fetchPypi {
      pname = "colcon_core";
      inherit version;
      hash = "sha256-gQJfcro3a0H7NjKxyF/ooXaA0UODYy5xfPfq2wzMpAI=";
    };

    build-system = with python3Packages; [
      setuptools
    ];

    propagatedBuildInputs = with python3Packages; [
      coloredlogs
      distlib
      empy
      packaging
      pytest
      pytest-cov
      pytest-repeat
      pytest-rerunfailures
      setuptools
    ];

    doCheck = false;
  };

  colcon-common-extensions = python3Packages.buildPythonPackage rec {
    pname = "colcon-common-extensions";
    version = "0.3.0";
    pyproject = true;

    src = fetchPypi {
      pname = "colcon_common_extensions";
      inherit version;
      hash = "sha256-3lcJEXgwXjLjqj1Vfr9GuKMPk3sYQN7HCqxVQhbqKpw=";
    };

    build-system = with python3Packages; [
      setuptools
    ];

    propagatedBuildInputs = [
      colcon-core
      colcon-cmake
      colcon-python-setup-py
      colcon-ros
    ];

    doCheck = false;
  };

  colcon-cmake = python3Packages.buildPythonPackage rec {
    pname = "colcon-cmake";
    version = "0.2.28";
    pyproject = true;

    src = fetchPypi {
      pname = "colcon_cmake";
      inherit version;
      hash = "sha256-FeqNIu+uQGmVo8tCN3kEg9Ny4WyB4wYMhNhud7TI1Qw=";
    };

    build-system = with python3Packages; [
      setuptools
    ];

    propagatedBuildInputs = [
      colcon-core
    ];

    doCheck = false;
  };

  colcon-python-setup-py = python3Packages.buildPythonPackage rec {
    pname = "colcon-python-setup-py";
    version = "0.2.8";
    pyproject = true;

    src = fetchPypi {
      pname = "colcon_python_setup_py";
      inherit version;
      hash = "sha256-xJqrVQIj4czSUPvmQimeHxyJLnmftCTkIUvuE0vMJpU=";
    };

    build-system = with python3Packages; [
      setuptools
    ];

    propagatedBuildInputs = [
      colcon-core
      python3Packages.setuptools
    ];

    doCheck = false;
  };

  colcon-ros = python3Packages.buildPythonPackage rec {
    pname = "colcon-ros";
    version = "0.5.0";
    pyproject = true;

    src = fetchPypi {
      pname = "colcon_ros";
      inherit version;
      hash = "sha256-mebC6qdXf/NO3gnK0VRAn8nCCO9q6z8LkrHYDoJx+xo=";
    };

    build-system = with python3Packages; [
      setuptools
    ];

    propagatedBuildInputs =
      [
        colcon-cmake
        colcon-core
        colcon-python-setup-py
      ]
      ++ (with python3Packages; [
        catkin-pkg
      ]);

    doCheck = false;
  };
in {
  inherit
    colcon-core
    colcon-common-extensions
    colcon-cmake
    colcon-python-setup-py
    colcon-ros
    ;
}

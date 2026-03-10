# Find orocos_kdl package - bridge for nix orocos-kdl
find_path(orocos_kdl_INCLUDE_DIR NAMES kdl/kdl.hpp PATH_SUFFIXES kdl)
find_library(orocos_kdl_LIBRARY NAMES orocos-kdl)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(orocos_kdl DEFAULT_MSG orocos_kdl_LIBRARY orocos_kdl_INCLUDE_DIR)

if(orocos_kdl_FOUND)
  set(orocos_kdl_INCLUDE_DIRS ${orocos_kdl_INCLUDE_DIR})
  set(orocos_kdl_LIBRARIES ${orocos_kdl_LIBRARY})
  if(NOT TARGET orocos-kdl)
    add_library(orocos-kdl UNKNOWN IMPORTED)
    set_target_properties(orocos-kdl PROPERTIES
      IMPORTED_LOCATION "${orocos_kdl_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${orocos_kdl_INCLUDE_DIR}"
    )
  endif()
endif()
# Find yaml package - bridge for nix libyaml
find_path(yaml_INCLUDE_DIR NAMES yaml.h)
find_library(yaml_LIBRARY NAMES yaml)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(yaml DEFAULT_MSG yaml_LIBRARY yaml_INCLUDE_DIR)

if(yaml_FOUND)
  set(yaml_INCLUDE_DIRS ${yaml_INCLUDE_DIR})
  set(yaml_LIBRARIES ${yaml_LIBRARY})
  if(NOT TARGET yaml::yaml)
    add_library(yaml::yaml UNKNOWN IMPORTED)
    set_target_properties(yaml::yaml PROPERTIES
      IMPORTED_LOCATION "${yaml_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${yaml_INCLUDE_DIR}"
    )
  endif()
endif()
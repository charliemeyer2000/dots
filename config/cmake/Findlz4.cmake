# Find lz4 package - bridge for nix liblz4
find_path(lz4_INCLUDE_DIR NAMES lz4.h)
find_library(lz4_LIBRARY NAMES lz4)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(lz4 DEFAULT_MSG lz4_LIBRARY lz4_INCLUDE_DIR)

if(lz4_FOUND)
  set(lz4_INCLUDE_DIRS ${lz4_INCLUDE_DIR})
  set(lz4_LIBRARIES ${lz4_LIBRARY})
  if(NOT TARGET lz4::lz4)
    add_library(lz4::lz4 UNKNOWN IMPORTED)
    set_target_properties(lz4::lz4 PROPERTIES
      IMPORTED_LOCATION "${lz4_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${lz4_INCLUDE_DIR}"
    )
  endif()
endif()
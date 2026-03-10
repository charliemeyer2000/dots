# Find zstd package - bridge for nix zstd
find_path(zstd_INCLUDE_DIR NAMES zstd.h)
find_library(zstd_LIBRARY NAMES zstd)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(zstd DEFAULT_MSG zstd_LIBRARY zstd_INCLUDE_DIR)

if(zstd_FOUND)
  set(zstd_INCLUDE_DIRS ${zstd_INCLUDE_DIR})
  set(zstd_LIBRARIES ${zstd_LIBRARY})
  if(NOT TARGET zstd::zstd)
    add_library(zstd::zstd UNKNOWN IMPORTED)
    set_target_properties(zstd::zstd PROPERTIES
      IMPORTED_LOCATION "${zstd_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${zstd_INCLUDE_DIR}"
    )
  endif()
endif()
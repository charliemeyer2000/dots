# Find assimp package - bridge for nix assimp
find_path(assimp_INCLUDE_DIR NAMES assimp/Importer.hpp)
find_library(assimp_LIBRARY NAMES assimp)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(assimp DEFAULT_MSG assimp_LIBRARY assimp_INCLUDE_DIR)

if(assimp_FOUND)
  set(assimp_INCLUDE_DIRS ${assimp_INCLUDE_DIR})
  set(assimp_LIBRARIES ${assimp_LIBRARY})
  if(NOT TARGET assimp::assimp)
    add_library(assimp::assimp UNKNOWN IMPORTED)
    set_target_properties(assimp::assimp PROPERTIES
      IMPORTED_LOCATION "${assimp_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${assimp_INCLUDE_DIR}"
    )
  endif()
endif()
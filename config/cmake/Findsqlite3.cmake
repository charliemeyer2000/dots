# Find sqlite3 package - bridge for nix sqlite
find_path(sqlite3_INCLUDE_DIR NAMES sqlite3.h)
find_library(sqlite3_LIBRARY NAMES sqlite3)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(sqlite3 DEFAULT_MSG sqlite3_LIBRARY sqlite3_INCLUDE_DIR)

if(sqlite3_FOUND)
  set(sqlite3_INCLUDE_DIRS ${sqlite3_INCLUDE_DIR})
  set(sqlite3_LIBRARIES ${sqlite3_LIBRARY})
  if(NOT TARGET sqlite3::sqlite3)
    add_library(sqlite3::sqlite3 UNKNOWN IMPORTED)
    set_target_properties(sqlite3::sqlite3 PROPERTIES
      IMPORTED_LOCATION "${sqlite3_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${sqlite3_INCLUDE_DIR}"
    )
  endif()
endif()
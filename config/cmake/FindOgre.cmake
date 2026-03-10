# Find Ogre package - bridge for nix ogre
find_path(OGRE_INCLUDE_DIR NAMES OGRE/Ogre.h PATH_SUFFIXES OGRE)
find_library(OGRE_LIBRARY NAMES OgreMain)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Ogre DEFAULT_MSG OGRE_LIBRARY OGRE_INCLUDE_DIR)

if(Ogre_FOUND OR OGRE_FOUND)
  set(OGRE_INCLUDE_DIRS ${OGRE_INCLUDE_DIR})
  set(OGRE_LIBRARIES ${OGRE_LIBRARY})
  set(Ogre_INCLUDE_DIRS ${OGRE_INCLUDE_DIR})
  set(Ogre_LIBRARIES ${OGRE_LIBRARY})
  if(NOT TARGET Ogre::Ogre)
    add_library(Ogre::Ogre UNKNOWN IMPORTED)
    set_target_properties(Ogre::Ogre PROPERTIES
      IMPORTED_LOCATION "${OGRE_LIBRARY}"
      INTERFACE_INCLUDE_DIRECTORIES "${OGRE_INCLUDE_DIR}"
    )
  endif()
endif()
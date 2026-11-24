# Injected with -DCMAKE_PROJECT_INCLUDE=<this file> by mayhem/build.sh (no upstream file edited).
# CMake includes it after every project() call; on the first (top-level) one it defers
# fuzz_targets.cmake to the end of the top-level CMakeLists, when libolive-editor, olivecore
# and OLIVE_INCLUDE_DIRS/OLIVE_LIBRARIES/OLIVE_DEFINITIONS all exist.
get_property(_olive_fuzz_done GLOBAL PROPERTY OLIVE_FUZZ_DEFERRED)
if(NOT _olive_fuzz_done)
  set_property(GLOBAL PROPERTY OLIVE_FUZZ_DEFERRED ON)
  # EVAL bakes the paths in now (a deferred call expands its arguments only when it runs).
  cmake_language(EVAL CODE
    "cmake_language(DEFER DIRECTORY [[${CMAKE_SOURCE_DIR}]] CALL include [[${CMAKE_CURRENT_LIST_DIR}/fuzz_targets.cmake]])")
endif()

# FFI plugin on Linux: build the sqlite-vec sources via CMake.
cmake_minimum_required(VERSION 3.10)
project(bulter_sqlite_vec LANGUAGES C)

add_library(bulter_sqlite_vec SHARED
  "../src/sqlite-vec.c"
)

target_include_directories(bulter_sqlite_vec PUBLIC "../src")
target_compile_definitions(bulter_sqlite_vec PUBLIC DART_SHARED_LIB)

set_target_properties(bulter_sqlite_vec PROPERTIES
  OUTPUT_NAME "bulter_sqlite_vec"
)

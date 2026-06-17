cmake_minimum_required(VERSION 3.10)
project(bulter_sqlite_vec_library VERSION 0.0.1 LANGUAGES C)

# Build sqlite-vec as a shared library that exports sqlite3_vec_init.
# Headers (sqlite-vec.h, sqlite3ext.h, sqlite3.h) are vendored in this same dir.
add_library(bulter_sqlite_vec SHARED
  "sqlite-vec.c"
)

set_target_properties(bulter_sqlite_vec PROPERTIES
  PUBLIC_HEADER sqlite-vec.h
  OUTPUT_NAME "bulter_sqlite_vec"
)

target_compile_definitions(bulter_sqlite_vec PUBLIC DART_SHARED_LIB)

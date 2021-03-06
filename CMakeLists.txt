PROJECT(binaryen C CXX)
CMAKE_MINIMUM_REQUIRED(VERSION 2.8.7)

IF(NOT CMAKE_BUILD_TYPE)
  MESSAGE(STATUS "No build type selected, default to Release")
  SET(CMAKE_BUILD_TYPE "Release")
ENDIF()

OPTION(BUILD_STATIC_LIB "Build as a static library" OFF)

# Support functionality.

FUNCTION(ADD_COMPILE_FLAG value)
  MESSAGE(STATUS "Building with ${value}")
  FOREACH(variable CMAKE_C_FLAGS CMAKE_CXX_FLAGS)
    SET(${variable} "${${variable}} ${value}" PARENT_SCOPE)
  ENDFOREACH(variable)
ENDFUNCTION()

FUNCTION(ADD_DEBUG_COMPILE_FLAG value)
  IF("${CMAKE_BUILD_TYPE}" MATCHES "Debug")
    MESSAGE(STATUS "Building with ${value}")
  ENDIF()
  FOREACH(variable CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_DEBUG)
    SET(${variable} "${${variable}} ${value}" PARENT_SCOPE)
  ENDFOREACH(variable)
ENDFUNCTION()

FUNCTION(ADD_NONDEBUG_COMPILE_FLAG value)
  IF(NOT "${CMAKE_BUILD_TYPE}" MATCHES "Debug")
    MESSAGE(STATUS "Building with ${value}")
  ENDIF()
  FOREACH(variable CMAKE_C_FLAGS_RELEASE CMAKE_CXX_FLAGS_RELEASE CMAKE_C_FLAGS_RELWITHDEBINFO CMAKE_CXX_FLAGS_RELWITHDEBINFO CMAKE_C_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_MINSIZEREL)
    SET(${variable} "${${variable}} ${value}" PARENT_SCOPE)
  ENDFOREACH(variable)
ENDFUNCTION()

FUNCTION(ADD_LINK_FLAG value)
  MESSAGE(STATUS "Linking with ${value}")
  FOREACH(variable CMAKE_EXE_LINKER_FLAGS)
    SET(${variable} "${${variable}} ${value}" PARENT_SCOPE)
  ENDFOREACH(variable)
ENDFUNCTION()

# Compiler setup.

INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR}/src)

# Force output to bin/ and lib/. This is to suppress CMake multigenerator output paths and avoid bin/Debug, bin/Release/ and so on, which is CMake default.
FOREACH(SUFFIX "_DEBUG" "_RELEASE" "_RELWITHDEBINFO" "_MINSIZEREL" "")
  SET(CMAKE_RUNTIME_OUTPUT_DIRECTORY${SUFFIX} "${PROJECT_BINARY_DIR}/bin")
  SET(CMAKE_LIBRARY_OUTPUT_DIRECTORY${SUFFIX} "${PROJECT_BINARY_DIR}/lib")
  SET(CMAKE_ARCHIVE_OUTPUT_DIRECTORY${SUFFIX} "${PROJECT_BINARY_DIR}/lib")
ENDFOREACH()

SET(all_passes passes)

IF(MSVC)
  IF(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "19.0") # VS2013 and older explicitly need /arch:sse2 set, VS2015 no longer has that option, but always enabled. 
    ADD_COMPILE_FLAG("/arch:sse2")
  ENDIF()
  ADD_COMPILE_FLAG("/wd4146") # Ignore warning "warning C4146: unary minus operator applied to unsigned type, result still unsigned", this pattern is used somewhat commonly in the code.
  ADD_COMPILE_FLAG("/WX-")
  ADD_DEBUG_COMPILE_FLAG("/O0")
  ADD_NONDEBUG_COMPILE_FLAG("/O2")
  ADD_COMPILE_FLAG("-D_CRT_SECURE_NO_WARNINGS")
  ADD_COMPILE_FLAG("-D_SCL_SECURE_NO_WARNINGS")
ELSE()
  SET(THREADS_PREFER_PTHREAD_FLAG ON)
  SET(CMAKE_THREAD_PREFER_PTHREAD ON)
  FIND_PACKAGE(Threads REQUIRED)
  ADD_COMPILE_FLAG("-std=c++11")
  ADD_COMPILE_FLAG("-msse2")
  ADD_COMPILE_FLAG("-mfpmath=sse")
  ADD_COMPILE_FLAG("-Wall")
  ADD_COMPILE_FLAG("-Werror")
  ADD_COMPILE_FLAG("-Wextra")
  ADD_COMPILE_FLAG("-Wno-unused-parameter")
  ADD_COMPILE_FLAG("-fno-omit-frame-pointer")
  IF(WIN32)
    ADD_COMPILE_FLAG("-D_GNU_SOURCE")
  ELSE()
    ADD_COMPILE_FLAG("-fPIC")
  ENDIF()
  ADD_DEBUG_COMPILE_FLAG("-O0")
  ADD_DEBUG_COMPILE_FLAG("-g3")
  ADD_NONDEBUG_COMPILE_FLAG("-O2")
  ADD_NONDEBUG_COMPILE_FLAG("-UNDEBUG") # Keep asserts.
ENDIF()

# clang doesn't print colored diagnostics when invoked from Ninja
IF (UNIX AND
    CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND
    CMAKE_GENERATOR STREQUAL "Ninja")
  ADD_COMPILE_FLAG("-fcolor-diagnostics")
ENDIF()

# Static libraries
ADD_SUBDIRECTORY(src/asmjs)
ADD_SUBDIRECTORY(src/emscripten-optimizer)
ADD_SUBDIRECTORY(src/passes)
ADD_SUBDIRECTORY(src/support)

# Sources.


SET(binaryen_SOURCES
  src/binaryen-c.cpp
  src/cfg/Relooper.cpp
  src/wasm.cpp
)
IF(BUILD_STATIC_LIB)
  ADD_LIBRARY(binaryen STATIC ${binaryen_SOURCES})    
ELSE()
  ADD_LIBRARY(binaryen SHARED ${binaryen_SOURCES})
ENDIF()
TARGET_LINK_LIBRARIES(binaryen asmjs ${all_passes} support)

SET(wasm-shell_SOURCES
  src/tools/wasm-shell.cpp
  src/wasm.cpp
)
ADD_EXECUTABLE(wasm-shell
               ${wasm-shell_SOURCES})
TARGET_LINK_LIBRARIES(wasm-shell asmjs emscripten-optimizer ${all_passes} support)
SET_PROPERTY(TARGET wasm-shell PROPERTY CXX_STANDARD 11)
SET_PROPERTY(TARGET wasm-shell PROPERTY CXX_STANDARD_REQUIRED ON)
INSTALL(TARGETS wasm-shell DESTINATION bin)

SET(wasm-opt_SOURCES
  src/tools/wasm-opt.cpp
  src/wasm.cpp
)
ADD_EXECUTABLE(wasm-opt
               ${wasm-opt_SOURCES})
TARGET_LINK_LIBRARIES(wasm-opt asmjs emscripten-optimizer ${all_passes} support)
SET_PROPERTY(TARGET wasm-opt PROPERTY CXX_STANDARD 11)
SET_PROPERTY(TARGET wasm-opt PROPERTY CXX_STANDARD_REQUIRED ON)
INSTALL(TARGETS wasm-opt DESTINATION bin)

SET(asm2wasm_SOURCES
  src/tools/asm2wasm.cpp
  src/wasm-emscripten.cpp
  src/wasm.cpp
)
ADD_EXECUTABLE(asm2wasm
               ${asm2wasm_SOURCES})
TARGET_LINK_LIBRARIES(asm2wasm asmjs emscripten-optimizer ${all_passes} support)
SET_PROPERTY(TARGET asm2wasm PROPERTY CXX_STANDARD 11)
SET_PROPERTY(TARGET asm2wasm PROPERTY CXX_STANDARD_REQUIRED ON)
INSTALL(TARGETS asm2wasm DESTINATION bin)

SET(s2wasm_SOURCES
  src/tools/s2wasm.cpp
  src/wasm-emscripten.cpp
  src/wasm-linker.cpp
  src/wasm.cpp
)
ADD_EXECUTABLE(s2wasm
               ${s2wasm_SOURCES})
TARGET_LINK_LIBRARIES(s2wasm asmjs passes support)
SET_PROPERTY(TARGET s2wasm PROPERTY CXX_STANDARD 11)
SET_PROPERTY(TARGET s2wasm PROPERTY CXX_STANDARD_REQUIRED ON)
INSTALL(TARGETS s2wasm DESTINATION bin)

SET(wasm_as_SOURCES
  src/tools/wasm-as.cpp
  src/wasm.cpp
)
ADD_EXECUTABLE(wasm-as
               ${wasm_as_SOURCES})
TARGET_LINK_LIBRARIES(wasm-as asmjs passes support)
SET_PROPERTY(TARGET wasm-as PROPERTY CXX_STANDARD 11)
SET_PROPERTY(TARGET wasm-as PROPERTY CXX_STANDARD_REQUIRED ON)
INSTALL(TARGETS wasm-as DESTINATION bin)

SET(wasm_dis_SOURCES
  src/tools/wasm-dis.cpp
  src/wasm.cpp
)
ADD_EXECUTABLE(wasm-dis
               ${wasm_dis_SOURCES})
TARGET_LINK_LIBRARIES(wasm-dis passes support asmjs)
SET_PROPERTY(TARGET wasm-dis PROPERTY CXX_STANDARD 11)
SET_PROPERTY(TARGET wasm-dis PROPERTY CXX_STANDARD_REQUIRED ON)
INSTALL(TARGETS wasm-dis DESTINATION bin)

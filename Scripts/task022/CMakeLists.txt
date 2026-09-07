# Task 022: braiding on the stand. The engine is Jolt Physics, pinned by tag.
#
#     cmake -S Scripts/task022 -B .build/task022-build -G Ninja \
#           -DCMAKE_BUILD_TYPE=Release
#     cmake --build .build/task022-build
#
# The build lives under .build/ because .build/ is outside git. Nothing here is
# part of the Kumihimo app target.
cmake_minimum_required(VERSION 3.24)
project(braid_on_stand CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)

# The version is pinned. Record it in docs/tasks/022-braid-on-the-stand.md when
# it changes; a physics answer that depends on the engine's version is a result
# about the engine, not about braiding.
set(JOLT_TAG "v5.6.0")
set(JOLT_COMMIT "e77f175595e64cb44218cc9d9d56fc365ad0e36a")

set(DOUBLE_PRECISION OFF CACHE BOOL "" FORCE)
set(GENERATE_DEBUG_SYMBOLS OFF CACHE BOOL "" FORCE)
set(CROSS_PLATFORM_DETERMINISTIC ON CACHE BOOL "" FORCE)
set(INTERPROCEDURAL_OPTIMIZATION OFF CACHE BOOL "" FORCE)
set(ENABLE_ALL_WARNINGS OFF CACHE BOOL "" FORCE)
# No renderer, no profiler, no GPU backend: this harness only needs the solver.
# Jolt 5.6 builds a Metal compute backend by default and its .mm files do not
# compile with plain /usr/bin/c++, so it is off here.
set(JPH_USE_MTL OFF CACHE BOOL "" FORCE)
set(JPH_USE_VK OFF CACHE BOOL "" FORCE)
set(JPH_USE_DX12 OFF CACHE BOOL "" FORCE)
set(DEBUG_RENDERER_IN_DEBUG_AND_RELEASE OFF CACHE BOOL "" FORCE)
set(PROFILER_IN_DEBUG_AND_RELEASE OFF CACHE BOOL "" FORCE)
set(TARGET_UNIT_TESTS OFF CACHE BOOL "" FORCE)
set(TARGET_HELLO_WORLD OFF CACHE BOOL "" FORCE)
set(TARGET_PERFORMANCE_TEST OFF CACHE BOOL "" FORCE)
set(TARGET_SAMPLES OFF CACHE BOOL "" FORCE)
set(TARGET_VIEWER OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    JoltPhysics
    GIT_REPOSITORY https://github.com/jrouwe/JoltPhysics.git
    GIT_TAG ${JOLT_COMMIT}
    SOURCE_SUBDIR Build
)
FetchContent_MakeAvailable(JoltPhysics)

# The core (braid_sim) knows the stand, the threads and the hands. It has no
# command line, no files and no globals, so that Task 022-4 can call it from
# Swift through C++ interop without carrying the harness with it.
add_library(braid_sim STATIC braid_sim.cpp)
target_include_directories(braid_sim PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(braid_sim PUBLIC Jolt)

add_executable(braid_on_stand main.cpp)
target_link_libraries(braid_on_stand PRIVATE braid_sim)

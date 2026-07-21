cmake_minimum_required(VERSION 3.21)
project(slint_counter_cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)
FetchContent_Declare(
    Slint
    GIT_REPOSITORY https://github.com/slint-ui/slint.git
    # `release/1` auto-upgrades to the latest Slint >= 1.0.0 and < 2.0.0
    GIT_TAG release/1
    SOURCE_SUBDIR api/cpp
)
FetchContent_MakeAvailable(Slint)

add_executable(slint_counter_cpp src/main.cpp)

# Compiles ui/app.slint ahead-of-time into a generated app.h header
# (same AOT compiler as the Rust build.rs / slint! macro paths — see
# ../../../docs/CASE-STUDY.md section 1.2 for how this mechanism works).
slint_target_sources(slint_counter_cpp ui/app.slint)

target_link_libraries(slint_counter_cpp PRIVATE Slint::Slint)

# On Windows, copy the Slint DLL next to the built binary so it's found at runtime.
if (WIN32)
    add_custom_command(TARGET slint_counter_cpp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_RUNTIME_DLLS:slint_counter_cpp> $<TARGET_FILE_DIR:slint_counter_cpp>
        COMMAND_EXPAND_LISTS
    )
endif()

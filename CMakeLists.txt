cmake_minimum_required(VERSION 4.3)
project(fireplace LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_OBJCXX_STANDARD 26)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_EXTENSIONS OFF)

find_library(APPKIT_FRAMEWORK AppKit REQUIRED)

add_executable(fireplace main.cpp scene.cpp fire.cpp window.mm)
target_compile_options(fireplace PRIVATE $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>)
target_link_libraries(fireplace PRIVATE "${APPKIT_FRAMEWORK}")

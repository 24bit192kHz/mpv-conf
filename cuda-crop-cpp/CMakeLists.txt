cmake_minimum_required(VERSION 3.20)

project(cuda_crop_cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(nlohmann_json REQUIRED)

add_executable(cuda-crop-cpp src/main.cpp)
target_link_libraries(cuda-crop-cpp PRIVATE nlohmann_json::nlohmann_json)
target_compile_options(cuda-crop-cpp PRIVATE -Wall -Wextra -Wpedantic)

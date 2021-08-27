cmake_minimum_required(VERSION 3.12)

project(Lab3D VERSION 0.9)

file(GLOB SOURCES "src/*")
file(GLOB UNITS "units/*")
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/units)
add_definitions(-DNOMINMAX)
add_definitions(-DM_PI=3.1415926535)
add_definitions("-DM_PI_2=(3.1415926535/2.0)")

add_executable(Lab3D WIN32 ${SOURCES} ${UNITS})

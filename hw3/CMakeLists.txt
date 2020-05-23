cmake_minimum_required(VERSION 3.5)
project(LABIOS_STORE)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS "-g -pg -fno-omit-frame-pointer")
include_directories(include)

#####The disk to put temporary data on
set(RES_DIR ${CMAKE_SOURCE_DIR}/test/results)

#####The basic shell scripts
set(SCRIPTS ${CMAKE_SOURCE_DIR}/scripts)

######TEST FILES
add_executable(mydiskbenchmark src/MyDiskBenchmark.c)
target_link_libraries(mydiskbenchmark -lpthread)

#####RUN TESTS
add_custom_target(test-small COMMAND bash ${SCRIPTS}/test.sh 0 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(test-all COMMAND bash ${SCRIPTS}/test.sh 1 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(parse-all COMMAND bash ${SCRIPTS}/test.sh 2 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(reset COMMAND bash ${SCRIPTS}/test.sh 3 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

cmake_minimum_required(VERSION 3.5)
project(LABIOS_STORE)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS "-g -pg -fno-omit-frame-pointer -O3 -ffast-math")
include_directories(include)

#####The disk to put temporary data on
set(RES_DIR ${CMAKE_SOURCE_DIR}/test/results)

#####The basic shell scripts
set(SCRIPTS ${CMAKE_SOURCE_DIR}/scripts)

######TEST FILES
add_executable(mysort src/mysort.c src/cache.c src/worker.c src/io.c src/misc.c src/task.c)
target_link_libraries(mysort -lpthread)

#####RUN TESTS
add_custom_target(structure COMMAND bash ${SCRIPTS}/test.sh 0 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(thread-tests COMMAND bash  ${SCRIPTS}/test.sh 1 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(test1 COMMAND bash ${SCRIPTS}/test.sh 2 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(test2 COMMAND bash ${SCRIPTS}/test.sh 3 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(test3 COMMAND bash ${SCRIPTS}/test.sh 4 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(test4 COMMAND bash ${SCRIPTS}/test.sh 5 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(test-all COMMAND bash ${SCRIPTS}/test.sh 6 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(parse-all COMMAND bash ${SCRIPTS}/test.sh 7 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(reset COMMAND bash ${SCRIPTS}/test.sh 8 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(validate COMMAND bash ${SCRIPTS}/test.sh 9 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(gensort COMMAND bash ${SCRIPTS}/test.sh 10 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

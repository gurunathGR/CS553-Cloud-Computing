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
add_executable(MySort src/MySort.c src/cache.c src/worker.c src/io.c src/misc.c src/task.c)
target_link_libraries(MySort -lpthread)

#####RUN TESTS
add_custom_target(mysort-test COMMAND bash ${SCRIPTS}/test.sh 1 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(linsort-test COMMAND bash ${SCRIPTS}/test.sh 2 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(hadoop-test COMMAND bash ${SCRIPTS}/test.sh 3 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test COMMAND bash ${SCRIPTS}/test.sh 4 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(hadoop-test-1G-4S COMMAND bash ${SCRIPTS}/test.sh 8 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test-1G-4S COMMAND bash ${SCRIPTS}/test.sh 9 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(hadoop-test-4G-4S COMMAND bash ${SCRIPTS}/test.sh 12 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test-4G-4S COMMAND bash ${SCRIPTS}/test.sh 13 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(hadoop-test-16G-4S COMMAND bash ${SCRIPTS}/test.sh 16 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test-16G-4S COMMAND bash ${SCRIPTS}/test.sh 17 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(hadoop-test-32G-4S COMMAND bash ${SCRIPTS}/test.sh 20 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test-32G-4S COMMAND bash ${SCRIPTS}/test.sh 21 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(mysort-test-1G-1L COMMAND bash ${SCRIPTS}/test.sh 24 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(linsort-test-1G-1L COMMAND bash ${SCRIPTS}/test.sh 25 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(hadoop-test-1G-1L COMMAND bash ${SCRIPTS}/test.sh 26 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test-1G-1L COMMAND bash ${SCRIPTS}/test.sh 27 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(mysort-test-4G-1L COMMAND bash ${SCRIPTS}/test.sh 28 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(linsort-test-4G-1L COMMAND bash ${SCRIPTS}/test.sh 29 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(hadoop-test-4G-1L COMMAND bash ${SCRIPTS}/test.sh 30 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test-4G-1L COMMAND bash ${SCRIPTS}/test.sh 31 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(mysort-test-16G-1L COMMAND bash ${SCRIPTS}/test.sh 32 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(linsort-test-16G-1L COMMAND bash ${SCRIPTS}/test.sh 33 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(hadoop-test-16G-1L COMMAND bash ${SCRIPTS}/test.sh 34 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test-16G-1L COMMAND bash ${SCRIPTS}/test.sh 35 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(mysort-test-32G-1L COMMAND bash ${SCRIPTS}/test.sh 36 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(linsort-test-32G-1L COMMAND bash ${SCRIPTS}/test.sh 37 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(hadoop-test-32G-1L COMMAND bash ${SCRIPTS}/test.sh 38 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test-32G-1L COMMAND bash ${SCRIPTS}/test.sh 39 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(mysort-test-1G-1S COMMAND bash ${SCRIPTS}/test.sh 40 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(linsort-test-1G-1S COMMAND bash ${SCRIPTS}/test.sh 41 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(hadoop-test-1G-1S COMMAND bash ${SCRIPTS}/test.sh 42 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test-1G-1S COMMAND bash ${SCRIPTS}/test.sh 43 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(mysort-test-4G-1S COMMAND bash ${SCRIPTS}/test.sh 44 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(linsort-test-4G-1S COMMAND bash ${SCRIPTS}/test.sh 45 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(hadoop-test-4G-1S COMMAND bash ${SCRIPTS}/test.sh 46 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test-4G-1S COMMAND bash ${SCRIPTS}/test.sh 47 CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(mysort-test-16G-1S COMMAND bash ${SCRIPTS}/test.sh 48 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(linsort-test-16G-1S COMMAND bash ${SCRIPTS}/test.sh 49 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(hadoop-test-16G-1S COMMAND bash ${SCRIPTS}/test.sh 50 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(spark-test-16G-1S COMMAND bash ${SCRIPTS}/test.sh 51 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(gen-1G COMMAND bash ${SCRIPTS}/test.sh 600 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(gen-4G COMMAND bash ${SCRIPTS}/test.sh 601 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(gen-16G COMMAND bash ${SCRIPTS}/test.sh 602 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(gen-24G COMMAND bash ${SCRIPTS}/test.sh 603 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(gen-28G COMMAND bash ${SCRIPTS}/test.sh 604 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(gen-32G COMMAND bash ${SCRIPTS}/test.sh 605 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(structure COMMAND bash ${SCRIPTS}/test.sh 0 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(parse-all COMMAND bash ${SCRIPTS}/test.sh 500 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(reset COMMAND bash ${SCRIPTS}/test.sh 501 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(gensort COMMAND bash ${SCRIPTS}/test.sh 502 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(HadoopSort COMMAND bash ${SCRIPTS}/test.sh 503 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})
add_custom_target(SparkSort COMMAND bash ${SCRIPTS}/test.sh 504 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

add_custom_target(monitor COMMAND bash ${SCRIPTS}/test.sh 505 ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR})

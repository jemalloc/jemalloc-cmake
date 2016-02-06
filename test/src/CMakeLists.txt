# Build bench and tests
include_directories(${PROJECT_SOURCE_DIR}/test/include)

# C4018 signed/unsigned mismatch in timer
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /wd4018")

add_definitions(-DJEMALLOC_STRESS_TEST -DJEMALLOC_STRESS_TESTLIB)

set(TESTLIBSRC
    btalloc.c
    btalloc_0.c
    btalloc_1.c
    math.c
    mq.c
    mtx.c
    SFMT.c
    test.c
    thd.c
    timer.c
)

add_library(${LIBJEMALLOCTESTLIB} ${TESTLIBSRC})


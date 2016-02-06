# Build bench and tests
include_directories(${PROJECT_SOURCE_DIR}/test/include)
add_definitions(-DJEMALLOC_STRESS_TEST)

set(STRESS
    microbench.c
)

set(EXES ${STRESS})

foreach(sourcefile ${EXES})
    string(REPLACE ".c" "" exename ${sourcefile})
    add_executable(${exename} ${sourcefile})
    target_link_libraries(${exename} ${LIBJEMALLOCLIB} ${LIBJEMALLOCTESTLIB})
endforeach(sourcefile ${EXES})

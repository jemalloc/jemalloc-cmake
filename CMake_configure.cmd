REM Configure Jemalloc build with options
CMake -G "Visual Studio 12 Win64" -Ddisable-fill=1 -Ddisable-stats=1 -Ddisable-cache-oblivious=1 ..
# This make file supports Windows build of Jemalloc
#
# Prerequisites:
#     You must have Visual Studio 2013 Update 4 installed or Visual Studio 2015 Update 1.
#      Start the Developer Command Prompt window that is a part of Visual Studio installation.
#      This will provide you with the accessible toolchain commands.
#      You must have a path git.exe in your %PATH%.
#
# 1. Create a build directory
# 2. Run cmake to generate project files for Windows
#        sample command: cmake -G "Visual Studio 12 Win64"  ..
#        OR for VS Studio 15 cmake -G "Visual Studio 14 Win64"  ..
#
# 3. Then build the project in debug mode (you may want to add /m[:<N>] flag to run msbuild in <N> parallel threads
#                                          or simply /m ot use all avail cores)
#        msbuild jemalloc.sln
#
# 4. And release mode (/m[:<N>] is also supported)
#        msbuild jemalloc.sln /p:Configuration=Release
#

# Currently this file only enables building on Windows and not Cygwin or MSYS
cmake_minimum_required (VERSION 3.4 FATAL_ERROR)

# Set policy based on the CMake version
cmake_policy(VERSION 3.4.3)

set (PACKAGE_NAME "jemalloc")
project (${PACKAGE_NAME} C)

include (CheckTypeSize)
include (CheckIncludeFiles)

include(${CMAKE_CURRENT_SOURCE_DIR}/Utilities.cmake)

##################################################################
# Versioning from GIT
# Defaults
set (jemalloc_version "0.0.0-0-g0000000000000000000000000000000000000000")
set (jemalloc_version_major 0)
set (jemalloc_version_minor 0)
set (jemalloc_version_bugfix 0)
set (jemalloc_version_nrev 0)
set (jemalloc_version_gid "0")

set(install_suffix "")

find_package(Git)
GetAndParseVersion()

# default is on
set(JEMALLOC_PRIVATE_NAMESPACE je_)
set(JEMALLOC_PREFIX je_)
set(je_ je_)
set(JEMALLOC_PREFIX_JET jet_)
set(JEMALLOC_CPREFIX JE_)

# For internal header expansion
set(private_namespace ${JEMALLOC_PRIVATE_NAMESPACE})

if(with-jemalloc-prefix)
  set(JEMALLOC_PREFIX ${with_jemalloc_prefix})
  set(je_ ${with_jemalloc_prefix})
endif()

if(with-private-namespace)
  set(JEMALLOC_PRIVATE_NAMESPACE ${with_private_namespace})
endif()

if(with-mangling)
# We are expecting entries separated by a comma
# with individual entries split by a ':' as in n:m
# Convert that into a CMake list of ':' separated pairs
  string(REPLACE "," ";" MANGLING_MAP  ${with-mangling})
endif()

# If defined, use munmap() to unmap freed chunks, rather than storing them for
# later reuse.  This is disabled by default on Linux because common sequences
# of mmap()/munmap() calls will cause virtual memory map holes.
# TODO: Check what this means on Windows
set(JEMALLOC_MUNMAP 0)

if(disable-munmap)
  set(JEMALLOC_MUNMAP 0)
endif()

# Disabling dss allocation because sbrk is deprecated
set(JEMALLOC_DSS 0)

# Support the junk/zero filling option by default.
set (JEMALLOC_FILL 1)

# Disable support for junk/zero filling, quarantine, and redzones
if(disable-fill)
  set (JEMALLOC_FILL 0)
endif()

# Enable thread-specific caching by default.
set(JEMALLOC_TCACHE 1)

if(disable-tcache)
  set(JEMALLOC_TCACHE 0)
endif()

# Enable stats by default
set(JEMALLOC_STATS 1)

# Disable statistics calculation/reporting
if(disable-stats)
  set(JEMALLOC_STATS 0)
endif()

# Do not support the xmalloc option by default.
set(JEMALLOC_XMALLOC 0)

if(enable-xmalloc)
  set(JEMALLOC_XMALLOC 1)
endif()

# Support cache-oblivious allocation alignment by default.
# If defined, explicitly attempt to more uniformly distribute large allocation
# pointer alignments across all cache indices.
set(JEMALLOC_CACHE_OBLIVIOUS 1)

if(disable-cache-oblivious)
  set(JEMALLOC_CACHE_OBLIVIOUS 0)
endif()

# Windows does not have it
set(JEMALLOC_UTRACE 0)

# Base 2 log of minimum tiny size class to support
set(LG_TINY_MIN 3)
if(with-lg-tiny-min)
  set(LG_TINY_MIN ${with-lg-tiny-min})
endif()

# Base 2 log of minimum allocation alignment
set(LG_QUANTA 3 4)
if(with-lg-quantum)
  set(LG_QUANTA ${with-lg-quantum})
  set(LG_QUANTUM ${with-lg-quantum})
endif()

# Base 2 log of system page size
# Assume default is 4096
set(SYSTEM_PAGE_SIZE 4096)
lg(${SYSTEM_PAGE_SIZE} "LG_PAGE")
if(with-lg-page)
  set(LG_PAGE ${with-lg-page})
endif()

## TODO Figure out system page size
#if(${LG_PAGE} STREQUAL "detect")
  
#endif()

# Base 2 logs of system page sizes to support
set (LG_PAGE_SIZES ${LG_PAGE})
if(with-lg-page-sizes)
  set(LG_PAGE_SIZES ${with-lg-page-sizes})
endif()

# Base 2 log of size classes per doubling
set (LG_SIZE_CLASS_GROUP 2)
if(with_lg_size_class_group)
  set (LG_SIZE_CLASS_GROUP ${with_lg_size_class_group})
endif()


# Driven by command line options originally
# JEMALLOC_OVERRIDE_MEMALIGN
# JEMALLOC_OVERRIDE_VALLOC
set (JEMALLOC_OVERRIDE_MEMALIGN 0)
set (JEMALLOC_OVERRIDE_VALLOC 0)
set (JEMALLOC_USABLE_SIZE_CONST const)

###################################################
# Undefined
# #undef JEMALLOC_HAVE_ATTR
# Below is everything under HAVE_ATTR
# #undef JEMALLOC_HAVE_ATTR_ALLOC_SIZE
# #undef JEMALLOC_HAVE_ATTR_FORMAT_GNU_PRINTF
# #undef JEMALLOC_FORMAT_PRINTF
# #undef JEMALLOC_USE_CXX_THROW
#

set (CPU_SPINWAIT "YieldProcessor()")

# MSVC 13 does not have it but perhaps
# might have later
if(HAVE_STDATOMIC_H)
  set(JEMALLOC_C11ATOMICS 1)
else()
set(JEMALLOC_C11ATOMICS 0)
endif()

# Relevant for FreeBSD only
set(JEMALLOC_ATOMIC9 0)
# Only for iOS
set(JEMALLOC_OSATOMIC 0)
set(JEMALLOC_OSSPIN 0)

# Only for GNU
set(JE_FORCE_SYNC_COMPARE_AND_SWAP_4 0)
set(JE_FORCE_SYNC_COMPARE_AND_SWAP_8 0)
set(JEMALLOC_HAVE_BUILTIN_CLZ 0)
set(JEMALLOC_HAVE_MADVISE 0)
set(JEMALLOC_HAVE_ISSETUGID 0)
set(JEMALLOC_HAVE_SECURE_GETENV 0)
set(JEMALLOC_MALLOC_THREAD_CLEANUP 0)
set(JEMALLOC_THREADED_INIT 0)
set(JEMALLOC_MUTEX_INIT_CB 0)
set(JEMALLOC_TLS_MODEL 0)
set(JEMALLOC_CODE_COVERAGE 0)
set(JEMALLOC_PROF 0)
set(JEMALLOC_PROF_LIBUNWIND 0)
set(JEMALLOC_PROF_LIBGCC 0)
set(JEMALLOC_PROF_GCC 0)
set(JEMALLOC_INTERNAL_FFSL 0)
set(JEMALLOC_INTERNAL_FFS 0)

#If defined, adjacent virtual memory mappings with identical attributes
# automatically coalesce, and they fragment when changes are made to subranges.
# This is the normal order of things for mmap()/munmap(), but on Windows
# VirtualAlloc()/VirtualFree() operations must be precisely matched, i.e.
# mappings do *not* coalesce/fragment.
set(JEMALLOC_MAPS_COALESCE 0)

# Separate clause for _WIN32 does the right thing
set(JEMALLOC_TLS 0)
set (JEMALLOC_HAS_RESTRICT 1)

CHECK_INCLUDE_FILES (alloca.h JEMALLOC_HAS_ALLOCA_H)
CHECK_INCLUDE_FILES (inttypes.h HAVE_INTTYPES_H)
CHECK_INCLUDE_FILES (stdatomic.h HAVE_STDATOMIC_H)

#CHECK_INCLUDE_FILES (malloc.h HAVE_MALLOC_H)
#CHECK_INCLUDE_FILES (sys/types.h HAVE_SYS_TYPES_H)
#CHECK_INCLUDE_FILES (sys/stat.h HAVE_SYS_STAT_H)
# CHECK_INCLUDE_FILES (stdlib.h HAVE_STDLIB_H)
# CHECK_INCLUDE_FILES (string.h HAVE_STRING_H)
# CHECK_INCLUDE_FILES (memory.h HAVE_MEMORY_H)
# CHECK_INCLUDE_FILES (strings.h HAVE_STRINGS_H)
# CHECK_INCLUDE_FILES (stdint.h HAVE_STDINT_H)
# CHECK_INCLUDE_FILES (unitstd.h HAVE_UNISTD_H)

UtilCheckTypeSize(void* SIZEOF_VOID_P)
if(SIZEOF_VOID_P)
  lg(${SIZEOF_VOID_P} "LG_SIZEOF_PTR")
endif()  

UtilCheckTypeSize(int SIZEOF_INT)
if(SIZEOF_INT)
  lg(${SIZEOF_INT} "LG_SIZEOF_INT")
endif()

UtilCheckTypeSize(long SIZEOF_LONG)
if(SIZEOF_LONG)
  lg(${SIZEOF_LONG} "LG_SIZEOF_LONG")
endif()

UtilCheckTypeSize(intmax_t SIZEOF_INTMAX_T)
if(SIZEOF_INTMAX_T)
  lg(${SIZEOF_INTMAX_T} "LG_SIZEOF_INTMAX_T")
endif()

###########################################################################
# Generate configured public headers for concatenation
# Public Headers in for configuring
set(PUBLIC_SYM
  malloc_conf
  malloc_message
  malloc
  calloc
  posix_memalign
  aligned_alloc
  realloc
  free
  mallocx
  rallocx
  xallocx
  sallocx
  dallocx
  sdallocx
  nallocx
  mallctl
  mallctlnametomib
  mallctlbymib
  malloc_stats_print
  malloc_usable_size
)

set(PUBLIC_SYM_FILE "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/public_symbols.txt")
GeneratePublicSymbolsList("${PUBLIC_SYM}" "${MANGLING_MAP}" ${JEMALLOC_PREFIX}  "${PUBLIC_SYM_FILE}")

foreach(public_in jemalloc_defs.h jemalloc_protos.h jemalloc_typedefs.h)
  ConfigureFile("${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/${public_in}.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/${public_in}" True)
endforeach(public_in)  

# Cmake chokes on a #define with a line continuation in jemalloc_macros.h.in
ConfigureFile("${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_macros.h.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_macros.h" False)

set(JEMALLOC_RENAME "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_rename.h")
GenerateJemallocRename("${PUBLIC_SYM_FILE}" ${JEMALLOC_RENAME})

set(JEMALLOC_MANGLE "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_mangle.h")
GenerateJemallocMangle("${PUBLIC_SYM_FILE}" ${JEMALLOC_PREFIX} ${JEMALLOC_MANGLE})

# Needed for tests
set(JEMALLOC_MANGLE_JET "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_mangle_jet.h")
GenerateJemallocMangle("${PUBLIC_SYM_FILE}" ${JEMALLOC_PREFIX_JET} ${JEMALLOC_MANGLE_JET})

# Generate main public header
set(JEMALLOC_HDR "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc.h")

set(JEMALLOC_HDR_LIST
   jemalloc_defs.h
   jemalloc_rename.h
   jemalloc_macros.h
   jemalloc_protos.h
   jemalloc_typedefs.h
   jemalloc_mangle.h
)

CreateJemallocHeader("${JEMALLOC_HDR_LIST}" "${JEMALLOC_HDR}")

##############################################################################################
## Internal headers generation
set(PUBLIC_NAMESPACE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/public_namespace.h")
PublicNamespace(${PUBLIC_SYM_FILE} "${PUBLIC_NAMESPACE_FILE}")

set(PUBLIC_UNNAMESPACE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/public_unnamespace.h")
PublicUnnamespace(${PUBLIC_SYM_FILE} "${PUBLIC_UNNAMESPACE_FILE}")

# This file comes with repo
set(PRIVATE_SYM_FILE "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/private_symbols.txt")

set(PRIVATE_NAMESPACE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/private_namespace.h")
PrivateNamespace("${PRIVATE_SYM_FILE}" "${PRIVATE_NAMESPACE_FILE}")

set(PRIVATE_UNNAMESPACE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/private_unnamespace.h")
PrivateUnnamespace("${PRIVATE_SYM_FILE}" "${PRIVATE_UNNAMESPACE_FILE}")

# Configure internal
# Chokes on line continuation so we only do @@ replacement which is required
ConfigureFile("${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/jemalloc_internal.h.in"
  "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/jemalloc_internal.h"  False)

ConfigureFile("${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/jemalloc_internal_defs.h.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/jemalloc_internal_defs.h" True)

# Test related
ConfigureFile("${CMAKE_CURRENT_SOURCE_DIR}/test/include/test/jemalloc_test_defs.h.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/test/include/test/jemalloc_test_defs.h" True)

# Line continuations are a problem for configuring defines but not required here
ConfigureFile("${CMAKE_CURRENT_SOURCE_DIR}/test/include/test/jemalloc_test.h.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/test/include/test/jemalloc_test.h" False)

set(SIZE_CLASSES_HDR "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/size_classes.h")
SizeClasses("${LG_QUANTA}" ${LG_TINY_MIN} "${LG_PAGE_SIZES}" "${LG_SIZE_CLASS_GROUP}"
 ${SIZE_CLASSES_HDR})

set(LIBJEMALLOCLIB jemalloc${CMAKE_STATIC_LIBRARY_SUFFIX})

# Add to defines
set(JEMALLOC_CC_SILENCE 0)

# May want to replace  /d2Zi+ to /Zo
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /FC /d2Zi+ /Zi /FS /nologo /W3 /WX /GS /Zc:wchar_t /Zc:forScope /errorReport:queue")
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -DJEMALLOC_DEBUG /Od /RTC1 /Gm /MTd" )
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} /Oxt /Zp8 /Gm- /Gy /MT")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /DEBUG")

add_definitions(-D_MBCS)

include_directories(${PROJECT_SOURCE_DIR}/include)
include_directories(${PROJECT_SOURCE_DIR}/include/msvc_compat)

if(NOT HAVE_INTTYPES_H)
  include_directories(${PROJECT_SOURCE_DIR}/include/msvc_compat/C99)
endif()

set(install_suffix "")

set(SOURCES
  src/arena.c
  src/atomic.c
  src/base.c
  src/bitmap.c
  src/chunk.c
  src/chunk_dss.c
  src/chunk_mmap.c
  src/ckh.c
  src/ctl.c
  src/extent.c
  src/hash.c
  src/huge.c
  src/jemalloc.c
  src/mb.c
  src/mutex.c
  src/pages.c
  src/prof.c
  src/quarantine.c
  src/rtree.c
  src/stats.c
  src/tcache.c
  src/tsd.c
  src/util.c
  src/valgrind.c
  src/zone.c
)

add_library(${LIBJEMALLOCLIB} ${SOURCES})
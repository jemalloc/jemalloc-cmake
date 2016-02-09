# This make file supports Windows build of Jemalloc
#
# Prerequisites:
#     You must have Visual Studio 2013 Update 4 installed or Visual Studio 2015 Update 1.
#      Start the Developer Command Prompt window that is a part of Visual Studio installation.
#      This will provide you with the accessible toolchain commands.
#      You must have a path git.exe in your %PATH%.
#
# 1. Create a build directory
#
# 2. Run cmake to generate project files for Windows
#        sample command: cmake -G "Visual Studio 12 Win64"  ..
#        OR for VS Studio 15 cmake -G "Visual Studio 14 Win64"  [optional switches described below] ..
#
# 3. Then build the project in debug mode (you may want to add /m[:<N>] flag to run msbuild in <N> parallel threads
#                                          or simply /m ot use all avail cores)
#        msbuild jemalloc.sln
#
# 4. And release mode (/m[:<N>] is also supported)
#        msbuild jemalloc.sln /p:Configuration=Release
#
# The following config switches that mimic the original autoconf behavior are supported
# use -D to define
# 
#  disable-munmap=1 disables unmapping for later reuse (default - enabled)
#  with-mangling=k:v,k:v... comma separated list of key:value pairs overrides specific function mangling
#  with-jemalloc-prefix=<prefix> override default je_ prefix
#  without-export=1 - disable export of public APIs
#  with-private-namespace=<additional_prefix>
#  with-install-suffix=<suffix> added to public headers and the library
#  disable-cc-silence=1 disable compiler silencing code
#  enable-debug=1 Enable debugging code
#  enable-ivsalloc=1 Validate pub API pointers
#  disable-stats=1 Disable stats calculation (on by default)
#  disable-tcache=1 Disable thread-specific caching (on by default)
#  disable-fill=1 disabling filling memory with junk on by default
#  enable-xmalloc=1 support xmalloc option
#  disable-cache-oblivious=1 Disable uniform distribution of large allocations
#  with-lg-tiny-min=<lg2 value> override default value of 3 of lg2 minimum tiny clas size
#  with-lg-quantum=<lg2 of the min allocation alignment>
#  with-lg-page=<lg2 of the page size> override system page size
#  with-lg-page-sizes=<comma separated list of lg2 pages sizes> Base 2 logs of system page sizes to support
#  with_lg_size_class_group=<Base 2 log of size classes per doubling> default 2
#  NOT SUPPORTED enable-lazy-lock
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

find_package(Git)
GetAndParseVersion()

# We do not support exec_prefix until we find it is necessary

CHECK_INCLUDE_FILES (alloca.h JEMALLOC_HAS_ALLOCA_H)

# whether malloc_usable_size definition can use const argument
CHECK_INCLUDE_FILES (malloc.h HAVE_MALLOC_H)
if(HAVE_MALLOC_H)
    set(JEMALLOC_USABLE_SIZE_CONST const)
endif()    

CHECK_INCLUDE_FILES (inttypes.h HAVE_INTTYPES_H)
CHECK_INCLUDE_FILES (stdatomic.h JEMALLOC_C11ATOMICS)
CHECK_INCLUDE_FILES (sys/time.h HAVE_SYSTIME_H)

UtilCheckTypeSize(void* SIZEOF_VOID_P)
if(SIZEOF_VOID_P)
  lg(${SIZEOF_VOID_P} "LG_SIZEOF_PTR")
  if((NOT ${LG_SIZEOF_PTR} EQUAL 3) AND
     (NOT ${LG_SIZEOF_PTR} EQUAL 2))
    message(FATAL_ERROR "Unsupported pointer size :${LG_SIZEOF_PTR}")
  endif()
endif()

UtilCheckTypeSize(int SIZEOF_INT)
if(SIZEOF_INT)
  lg(${SIZEOF_INT} "LG_SIZEOF_INT")
  if((NOT ${LG_SIZEOF_INT} EQUAL 3) AND
     (NOT ${LG_SIZEOF_INT} EQUAL 2))
    message(FATAL_ERROR "Unsupported int size :${LG_SIZEOF_INT}")
  endif()
endif()

UtilCheckTypeSize(long SIZEOF_LONG)
if(SIZEOF_LONG)
  lg(${SIZEOF_LONG} "LG_SIZEOF_LONG")
  if((NOT ${LG_SIZEOF_LONG} EQUAL 3) AND
     (NOT ${LG_SIZEOF_LONG} EQUAL 2))
    message(FATAL_ERROR "Unsupported long size :${LG_SIZEOF_LONG}")
  endif()
endif()

UtilCheckTypeSize(intmax_t SIZEOF_INTMAX_T)
if(SIZEOF_INTMAX_T)
  lg(${SIZEOF_INTMAX_T} "LG_SIZEOF_INTMAX_T")
  if((NOT ${LG_SIZEOF_INTMAX_T} EQUAL 4) AND
     (NOT ${LG_SIZEOF_INTMAX_T} EQUAL 3) AND
     (NOT ${LG_SIZEOF_INTMAX_T} EQUAL 2))
    message(FATAL_ERROR "Unsupported long size :${LG_SIZEOF_INTMAX_T}")
  endif()
endif()

set (CPU_SPINWAIT "YieldProcessor()")

# Not clear if we need this
set(so "dll")
set(importlib "lib")

# If defined, use munmap() to unmap freed chunks, rather than storing them for
# later reuse.  This is disabled by default on Linux because common sequences
# of mmap()/munmap() calls will cause virtual memory map holes.
# But it is enabled by default on Windows
set(JEMALLOC_MUNMAP 1)

if(disable-munmap)
  set(JEMALLOC_MUNMAP 0)
endif()

# If defined, adjacent virtual memory mappings with identical attributes
# automatically coalesce, and they fragment when changes are made to subranges.
# This is the normal order of things for mmap()/munmap(), but on Windows
# VirtualAlloc()/VirtualFree() operations must be precisely matched, i.e.
# mappings do *not* coalesce/fragment.
set(JEMALLOC_MAPS_COALESCE 0)

###################################################
# Undefined
# #undef JEMALLOC_HAVE_ATTR
set(JEMALLOC_HAVE_ATTR 0)
# Below is everything under HAVE_ATTR
# #undef JEMALLOC_HAVE_ATTR_ALLOC_SIZE
# #undef JEMALLOC_HAVE_ATTR_FORMAT_GNU_PRINTF
# #undef JEMALLOC_FORMAT_PRINTF
# #undef JEMALLOC_USE_CXX_THROW
#

set (JEMALLOC_OVERRIDE_MEMALIGN 0)
set (JEMALLOC_OVERRIDE_VALLOC 0)

if(with-mangling)
# We are expecting entries separated by a comma
# with individual entries split by a ':' as in n:m
# Convert that into a CMake list of ':' separated pairs
  string(REPLACE "," ";" MANGLING_MAP  ${with-mangling})
endif()

set(JEMALLOC_PREFIX je_)

if(with-jemalloc-prefix)
  set(JEMALLOC_PREFIX ${with_jemalloc_prefix})
endif()

# Uppercase copy of the JEMALLOC_PREFIX
# Need  quotes so the preprocessor concats two strings
string(TOUPPER \"${JEMALLOC_PREFIX}\" JEMALLOC_CPREFIX)

# Disable exporting jemalloc public APIs
# We need to define the var to whitespace string
# as empty strings will not be defined in CMake
set(without-export 1)
if(without-export)
    set(JEMALLOC_EXPORT " ")
endif()

# Prefix to prepend to all library-private APIs
# default is on
set(JEMALLOC_PRIVATE_NAMESPACE je_)
if(with-private-namespace)
    set(JEMALLOC_PRIVATE_NAMESPACE "${with_private_namespace}je_")
endif()

set(private_namespace ${JEMALLOC_PRIVATE_NAMESPACE})

if(with-install-suffix)
    set(INSTALL_SUFFIX ${with-install-suffix})
    set(install_suffix ${with-install-suffix})
endif()

# Substitute @je_@ in jemalloc_protos.h.in, primarily to make generation of
# jemalloc_protos_jet.h easy.
set(je_ je_)

# Do not silence irrelevant compiler warnings
set(JEMALLOC_CC_SILENCE 1)
if(disable-cc-silence)
    set(JEMALLOC_CC_SILENCE 0)
endif()

# Build debugging code (implies --enable-ivsalloc)
if(enable-debug)
    set(JEMALLOC_DEBUG 1)
    set(JEMALLOC_IVSALLOC 1)
endif()

# Validate pointers passed through the public API
if(enable-ivsalloc)
    set(JEMALLOC_IVSALLOC 1)
endif()

# Enable stats by default
set(JEMALLOC_STATS 1)
# Disable statistics calculation/reporting
if(disable-stats)
  set(JEMALLOC_STATS 0)
endif()

# Enable thread-specific caching by default.
set(JEMALLOC_TCACHE 1)
if(disable-tcache)
  set(JEMALLOC_TCACHE 0)
endif()

set(JEMALLOC_PREFIX_JET jet_)

# Disabling dss allocation because sbrk is deprecated
set(JEMALLOC_DSS 0)

# Support the junk/zero filling option by default.
set (JEMALLOC_FILL 1)
# Disable support for junk/zero filling, quarantine, and redzones
if(disable-fill)
  set (JEMALLOC_FILL 0)
endif()

# Windows does not have it
set(JEMALLOC_UTRACE 0)
set(JEMALLOC_VALGRIND 0)

# Support xmalloc option
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

# ffsl and ffs are defined in msvc_compat/strings.h
set(JEMALLOC_INTERNAL_FFSL ffsl)
set(JEMALLOC_INTERNAL_FFS ffs)

# Base 2 log of minimum tiny size class to support
set(LG_TINY_MIN 3)
if(with-lg-tiny-min)
  set(LG_TINY_MIN ${with-lg-tiny-min})
endif()

# Base 2 log of minimum allocation alignment
set(LG_QUANTA 3 4)
if(with-lg-quantum)
  # Convert to a CMake list
  string(REPLACE "," ";" LG_QUANTA  ${with-lg-quantum})
  set(LG_QUANTA ${with-lg-quantum})
  set(LG_QUANTUM ${LG_QUANTA})
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
  string(REPLACE "," ";" LG_PAGE_SIZES  ${with-lg-page-sizes})
endif()

# Base 2 log of size classes per doubling
set (LG_SIZE_CLASS_GROUP 2)
if(with_lg_size_class_group)
  set (LG_SIZE_CLASS_GROUP ${with_lg_size_class_group})
endif()

# secure_getenv
set(JEMALLOC_HAVE_SECURE_GETENV 0)

set(JEMALLOC_HAVE_ISSETUGID 0)
set(JEMALLOC_MALLOC_THREAD_CLEANUP 0)

set(JEMALLOC_MUTEX_INIT_CB 0)

# No lazy lock since there is a way in Windows
# to bootstrap for sure
set(JEMALLOC_LAZY_LOCK 0)

# Separate clause for _WIN32 does the right thing
# So TLS is enabled for Windows
set(JEMALLOC_TLS 0)

# Relevant for FreeBSD only
set(JEMALLOC_ATOMIC9 0)
# Only for iOS
set(JEMALLOC_OSATOMIC 0)
set(JEMALLOC_OSSPIN 0)
set(JEMALLOC_ZONE 0)

# Only for GNU
set(JE_FORCE_SYNC_COMPARE_AND_SWAP_4 0)
set(JE_FORCE_SYNC_COMPARE_AND_SWAP_8 0)
set(JEMALLOC_HAVE_BUILTIN_CLZ 0)
set(JEMALLOC_HAVE_MADVISE 0)
set(JEMALLOC_THREADED_INIT 0)

set(JEMALLOC_TLS_MODEL 0)
set(JEMALLOC_CODE_COVERAGE 0)
set(JEMALLOC_PROF 0)
set(JEMALLOC_PROF_LIBUNWIND 0)
set(JEMALLOC_PROF_LIBGCC 0)
set(JEMALLOC_PROF_GCC 0)

set (JEMALLOC_HAS_RESTRICT 1)

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
set(JEMALLOC_HDR "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc${install_suffix}.h")

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
 "${SIZE_CLASSES_HDR}")

 # To generate protos_jet
set(je_ jet_)

# replace prefix only
ConfigureFile("${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_protos.h.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_protos_jet.h" True)

# revert
set(je__ je_)

set(LIBJEMALLOCLIB jemalloc${install_suffix})

# Add to defines


# May want to replace  /d2Zi+ to /Zo
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /FC /d2Zi+ /Zi /FS /nologo /W3 /WX /GS /Zc:wchar_t /Zc:forScope /errorReport:queue")

# Separate line for warnings suppression mostly due to the fact we have ints 32 bits
# - C4267 due to the fact we have ints 32 bits
# - C4244 simular typedef unsigned szind_t
# - C4146 alignment calculation applies negation to a unsigned type
# - C4334 - result of 32-bit shift implicitly converted to 64 bits
# - C4090 - some modifiable parameters are passed with a const qualifier
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /wd4267 /wd4244 /wd4146 /wd4334 /wd4090")

set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -DJEMALLOC_DEBUG /Od /RTC1 /Gm /MTd" )
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} /Oxt /Zp8 /Gm- /Gy /MT")

# Make sure that PDBs are always generated
# This somehow produces a warning.
# set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /DEBUG")

# add_definitions(-D_MBCS -DDLLEXPORT)

include_directories(${PROJECT_SOURCE_DIR}/include)
include_directories(${PROJECT_SOURCE_DIR}/include/msvc_compat)

if(NOT HAVE_INTTYPES_H)
  include_directories(${PROJECT_SOURCE_DIR}/include/msvc_compat/C99)
endif()

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
  # src/valgrind.c # Valgrind integration only
  # src/zone.c # Darwin only file
)

add_library(${LIBJEMALLOCLIB} ${SOURCES})

set(LIBJEMALLOCTESTLIB jemalloctestlibrary)
#add_subdirectory(test/src)
#add_subdirectory(test/stress)


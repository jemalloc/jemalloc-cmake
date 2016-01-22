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
cmake_minimum_required (VERSION 2.8.12 FATAL_ERROR)

# Set policy based on the CMake version
cmake_policy(VERSION 3.2.3)

set (PACKAGE_NAME "jemalloc")
project (${PACKAGE_NAME} C)

include(${CMAKE_CURRENT_SOURCE_DIR}/Utilities.cmake)
include (CheckTypeSize)

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

# @je_@ prefix driven by a command line
# default is on
set(JEMALLOC_PRIVATE_NAMESPACE je_)
set(JEMALLOC_PREFIX je_)
set(JEMALLOC_PREFIX_JET jet_)

if(DEFINED with_jemalloc_prefix)
  set(JEMALLOC_PREFIX ${with_jemalloc_prefix})
endif()

if(DEFINED with_private_namespace)
  set(JEMALLOC_PRIVATE_NAMESPACE ${with_private_namespace})
endif()

if(DEFINED with-mangling)
# We are expecting entries separated by a comma
# with individual entries split by a ':' as in n:m
# Convert that into a CMake list of ':' separated pairs
  string(REPLACE "," ";" MANGLING_MAP  ${with-mangling})
endif()

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
set(LG_PAGE 12)
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
set (JEMALLOC_USABLE_SIZE_CONST 1)

###################################################
# Undefined
# #undef JEMALLOC_HAVE_ATTR
# Below is everything under HAVE_ATTR
# #undef JEMALLOC_HAVE_ATTR_ALLOC_SIZE
# #undef JEMALLOC_HAVE_ATTR_FORMAT_GNU_PRINTF
# #undef JEMALLOC_FORMAT_PRINTF
# #undef JEMALLOC_USE_CXX_THROW
#
# separate clause for MSVC
# #undef JEMALLOC_C11ATOMICS

CHECK_TYPE_SIZE(void* SIZEOF_VOID_P LANGUAGE C)
#CHECK_TYPE_SIZE("long"  LONG_SIZE BUILTIN_TYPES_ONLY LANGUAGE C)

if(SIZEOF_VOID_P)
  message (STATUS "Void* size is ${SIZEOF_VOID_P}")
  if(${SIZEOF_VOID_P} EQUAL 8)
    set (LG_SIZEOF_PTR 3)
  else()
    set (LG_SIZEOF_PTR 2)
  endif()
else()
  message(FATAL_ERROR "Can not determine void* size")
endif()


###########################################################################
# Generate configured public headers for concatenation
# Public Headers in for configuring
foreach(public_in jemalloc_defs.h jemalloc_protos.h jemalloc_typedefs.h)
  ConfigureFile(${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/${public_in}.in
    ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/${public_in} True)
endforeach(public_in)  

# Cmake chokes on a #define with a line continuation in jemalloc_macros.h.in
ConfigureFile(${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_macros.h.in
    ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_macros.h False)

set(PUBLIC_SYM_FILE ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/public_symbols.txt)
GeneratePublicSymbolsList("${PUBLIC_SYM}" "${MANGLING_MAP}" ${JEMALLOC_PREFIX}  ${PUBLIC_SYM_FILE})

set(JEMALLOC_RENAME ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_rename.h)
GenerateJemallocRename(${PUBLIC_SYM_FILE} ${JEMALLOC_RENAME})

set(JEMALLOC_MANGLE ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_mangle.h)
GenerateJemallocMangle(${PUBLIC_SYM_FILE} ${JEMALLOC_PREFIX} ${JEMALLOC_MANGLE})

# Needed for tests
set(JEMALLOC_MANGLE_JET ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_mangle_jet.h)
GenerateJemallocMangle(${PUBLIC_SYM_FILE} ${JEMALLOC_PREFIX_JET} ${JEMALLOC_MANGLE_JET})

# Generate main public header
set(JEMALLOC_HDR ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc.h)

set(JEMALLOC_HDR_LIST
   jemalloc_defs.h
   jemalloc_rename.h
   jemalloc_macros.h
   jemalloc_protos.h
   jemalloc_typedefs.h
   jemalloc_mangle.h
)

CreateJemallocHeader("${JEMALLOC_HDR_LIST}" ${JEMALLOC_HDR})

##############################################################################################
## Internal headers generation
set(PUBLIC_NAMESPACE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/public_namespace.h)
PublicNamespace(${PUBLIC_SYM_FILE} ${PUBLIC_NAMESPACE_FILE})

set(PUBLIC_UNNAMESPACE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/public_unnamespace.h)
PublicUnnamespace(${PUBLIC_SYM_FILE} ${PUBLIC_UNNAMESPACE_FILE})

# This file comes with repo
set(PRIVATE_SYM_FILE ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/private_symbols.txt)

set(PRIVATE_NAMESPACE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/private_namespace.h)
PrivateNamespace(${PRIVATE_SYM_FILE} ${PRIVATE_NAMESPACE_FILE})

set(PRIVATE_UNNAMESPACE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/private_unnamespace.h)
PrivateUnnamespace(${PRIVATE_SYM_FILE} ${PRIVATE_UNNAMESPACE_FILE})
   
include_directories(${PROJECT_SOURCE_DIR}/include)

set(LIBJEMALLOCLIB jemalloc${CMAKE_STATIC_LIBRARY_SUFFIX})
   
set(cfghdrs_internal_in
    include/jemalloc/internal/jemalloc_internal.h
    include/jemalloc/internal/jemalloc_internal_defs.h
    )
  
# set (cfghdrs_out
     # include/jemalloc/jemalloc_defs.h
     # include/jemalloc/jemalloc.h
     # include/jemalloc/internal/private_namespace.h
     # include/jemalloc/internal/private_unnamespace.h
     # include/jemalloc/internal/public_symbols.txt
     # include/jemalloc/internal/public_namespace.h
     # include/jemalloc/internal/public_unnamespace.h
     ###### include/jemalloc/internal/size_classes.h
     ###### include/jemalloc/internal/jemalloc_internal_defs.h
     # include/jemalloc/jemalloc_protos_jet.h
     # include/jemalloc/jemalloc_rename.h
     # include/jemalloc/jemalloc_mangle.h
     # include/jemalloc/jemalloc_mangle_jet.h
     ##### test/include/test/jemalloc_test_defs.h
     # )


# if(OS_WIN)
  # if (MSVC)
    # message (STATUS "Building with Microsoft VS")
    # set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /FC /d2Zi+ /Zi /nologo /W3 /WX /EHsc /GS /fp:precise /Zc:wchar_t /Zc:forScope /Gd /TP /errorReport:queue")
    # set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /Od /RTC1 /Gm /MDd")
    # set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /O2 /Oi /Gm- /Gy /MD")
    # set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /DEBUG")
    # add_definitions(-DWIN32 -DOS_WIN -D_MBCS -DWIN64)
    # set(install_suffix "")
  # else()
    # message (FATAL_ERROR "Need to specify settings for your compiler")
  # endif()
# else()
  # message (FATAL_ERROR "Do not know how to build on your system!")
# endif()

# set (C_HDRS
     # include/jemalloc/jemalloc${install_suffix}.h
    # )

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
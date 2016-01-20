# This make file supports Windows build
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

set (PACKAGE_NAME "jemalloc")
project (${PACKAGE_NAME} C)

include (CheckTypeSize)

# Versioning from GIT, defaults
set (jemalloc_version "0.0.0-0-g0000000000000000000000000000000000000000")
set (jemalloc_version_major 0)
set (jemalloc_version_minor 0)
set (jemalloc_version_bugfix 0)
set (jemalloc_version_nrev 0)
set (jemalloc_version_gid "0")

find_package(Git)

if (GIT_FOUND AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")
    execute_process(COMMAND $ENV{COMSPEC} /C 
      ${GIT_EXECUTABLE} -C ${CMAKE_CURRENT_SOURCE_DIR} describe --long --abbrev=40 HEAD OUTPUT_VARIABLE jemalloc_version)
    
    # Figure out version components    
    string (REPLACE "\n" "" jemalloc_version  ${jemalloc_version})
    message(STATUS "Version is ${jemalloc_version}")

    # replace in this order to get a valid cmake list
    string (REPLACE "-g" "-" T_VERSION ${jemalloc_version})
    string (REPLACE "-" "." T_VERSION  ${T_VERSION})
    string (REPLACE "." ";" T_VERSION  ${T_VERSION})
    message(STATUS "T_VERSION is ${T_VERSION}")
    
    list(LENGTH T_VERSION L_LEN)
    message(STATUS "T_VERSION len is ${L_LEN}")
    
    if(${L_LEN} GREATER 0)
      list(GET T_VERSION 0 jemalloc_version_major)
      message(STATUS "Major: ${jemalloc_version_major}")
    endif()

    if(${L_LEN} GREATER 1)
      list(GET T_VERSION 1 jemalloc_version_minor)
      message(STATUS "Minor: ${jemalloc_version_minor}")
    endif()

    if(${L_LEN} GREATER 2)
      list(GET T_VERSION 2 jemalloc_version_bugfix)
      message(STATUS "jemalloc_version_bugfix: ${jemalloc_version_bugfix}")
    endif()

    if(${L_LEN} GREATER 3)
      list(GET T_VERSION 3 jemalloc_version_nrev)
      message(STATUS "jemalloc_version_nrev: ${jemalloc_version_nrev}")
    endif()

    if(${L_LEN} GREATER 4)
      list(GET T_VERSION 4 jemalloc_version_gid)
      message(STATUS "jemalloc_version_gid: ${jemalloc_version_gid}")
    endif()
endif()

# @je_@ prefix driven by a command line
# default is on
set(JEMALLOC_PRIVATE_NAMESPACE je_)
set(JEMALLOC_PREFIX je_)

if(DEFINED WITH_JEPREFIX)
  set(JEMALLOC_PRIVATE_NAMESPACE ${WITH_JEPREFIX})
  set(JEMALLOC_PREFIX ${WITH_JEPREFIX})
endif()

# Driven by command line options
# JEMALLOC_OVERRIDE_MEMALIGN
# JEMALLOC_OVERRIDE_VALLOC
set (JEMALLOC_OVERRIDE_MEMALIGN 0)
set (JEMALLOC_OVERRIDE_VALLOC 0)
set (JEMALLOC_USABLE_SIZE_CONST 0)

# separate clause for MSVC
# #undef JEMALLOC_C11ATOMICS

if(DEFINED OVERRIDEMEMALIGN)
  set(JEMALLOC_OVERRIDE_MEMALIGN ${OVERRIDEMEMALIGN})
endif()

if(DEFINED OVERRIDEVALLOC)
  set(JEMALLOC_OVERRIDE_VALLOC ${OVERRIDEVALLOC})
endif()

# #undef JEMALLOC_HAVE_ATTR
# Below is everything under HAVE_ATTR
# #undef JEMALLOC_HAVE_ATTR_ALLOC_SIZE
# #undef JEMALLOC_HAVE_ATTR_FORMAT_GNU_PRINTF
# #undef JEMALLOC_FORMAT_PRINTF
# #undef JEMALLOC_USE_CXX_THROW

CHECK_TYPE_SIZE("void*" VOID_PTR_SIZE LANGUAGE C)
#CHECK_TYPE_SIZE("long"  LONG_SIZE BUILTIN_TYPES_ONLY LANGUAGE C)

if(HAVE_VOID_PTR_SIZE)
  if(${VOID_PTR_SIZE} EQUAL 8)
    set (LG_SIZEOF_PTR 3)
  else()
    set (LG_SIZEOF_PTR 2)
  endif()
  message (STATUS "Void* size is ${VOID_PTR_SIZE}")
else()
 # 64-bit generator fails with MSVC
 set (LG_SIZEOF_PTR 3)
endif()

# A function that configures a file and outputs
# end result
function (ConfigureFile file_path output_path ExpandDefine)

if(EXISTS ${file_path})
  if(NOT ${ExpandDefine})
    # Will expand only @@ macros
    configure_file(${file_path} ${output_path} @ONLY NEWLINE_STYLE WIN32) 
  else()
    # Need to Grep for ^#undef VAR lines and replace it with
    # ^#cmakedefine VAR
    file(REMOVE ${file_path}.cmake)
    file(STRINGS ${file_path} INPUT_STRINGS)
    
    foreach(line ${INPUT_STRINGS})
      if(${line} MATCHES "^#undef[ \t]*[^ \t]*")
        string(REGEX REPLACE "^#undef[ \t]*([^ \t]*)" "\\1" extracted_define ${line})      
        if(${extracted_define})
          file(APPEND ${file_path}.cmake "#define ${extracted_define} ${${extracted_define}}\n")
        else()
          file(APPEND ${file_path}.cmake "/* #undef ${extracted_define} */\n\n")
        endif()
      else()
        file(APPEND ${file_path}.cmake "${line}\n")
      endif()
    endforeach(line)
    configure_file(${file_path}.cmake ${output_path} @ONLY NEWLINE_STYLE WIN32)
  endif()
else()
  message(FATAL_ERROR "${file_path} not found")
endif()

endfunction(ConfigureFile)

# Public Headers in for processing
foreach(public_in jemalloc_defs.h jemalloc_protos.h jemalloc_typedefs.h)
  ConfigureFile(${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/${public_in}.in
    ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/${public_in} True)
endforeach(public_in)  

# Cmake chokes on a #define with a line continuation
ConfigureFile(${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_macros.h.in
    ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_macros.h False)
    
# Public symbols
set(PUB_SYM ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/internal/public_symbols.txt)
set(JEMALLOC_RENAME ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc_rename.h)
file(WRITE ${JEMALLOC_RENAME}
  "/*\n * Name mangling for public symbols is controlled by --with-mangling and\n * --with-jemalloc-prefix.  With default settings the je_" "prefix is stripped by\n * these macro definitions.\n */\n#ifndef JEMALLOC_NO_RENAME\n\n"
)
file(STRINGS ${file_path} INPUT_STRINGS)
foreach(line ${INPUT_STRINGS})
  
endforeach(line)
file(APPEND ${JEMALLOC_RENAME}
  "#endif\n"
)

# Generate jemalloc.h public header per jemalloc.sh
set(JEMALLOC_HDR ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/jemalloc.h)
# Header
file(WRITE ${JEMALLOC_HDR}
  "#ifndef JEMALLOC_H_\n#define	JEMALLOC_H_\n#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n"
)

#jemalloc_defs.h jemalloc_rename.h jemalloc_macros.h \
#           jemalloc_protos.h jemalloc_typedefs.h jemalloc_mangle.h

# Footer
file(APPEND ${JEMALLOC_HDR}
"#ifdef __cplusplus\n}\n#endif\n#endif /* JEMALLOC_H_ */\n"
)
   
# if (POLICY CMP0042)
  # cmake_policy (SET CMP0042 NEW)
# endif ()

# set (DEST_DIR ${PROJECT_BINARY_DIR})
# set (BIN_DIR ${PROJECT_BINARY_DIR})

# message("DEST_DIR: ${DEST_DIR}");

# set (LIB_DIR ${DEST_DIR}/Lib)
# set (DATA_DIR ${DEST_DIR}/Data)
# set (MAN_DIR ${DEST_DIR}/Man)

# include_directories(${PROJECT_SOURCE_DIR}/include)
# include_directories(${DEST_DIR}/include)

# set(LIBJEMALLOCLIB ${CMAKE_STATIC_LIBRARY_PREFIX}jemalloc${CMAKE_STATIC_LIBRARY_SUFFIX})

   
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
     # include/jemalloc/internal/size_classes.h
     # include/jemalloc/internal/jemalloc_internal_defs.h
     # include/jemalloc/jemalloc_protos_jet.h
     # include/jemalloc/jemalloc_rename.h
     # include/jemalloc/jemalloc_mangle.h
     # include/jemalloc/jemalloc_mangle_jet.h
     # test/include/test/jemalloc_test_defs.h
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

# set(SOURCES
  # src/arena.c
  # src/atomic.c
  # src/base.c
  # src/bitmap.c
  # src/chunk.c
  # src/chunk_dss.c
  # src/chunk_mmap.c
  # src/ckh.c
  # src/ctl.c
  # src/extent.c
  # src/hash.c
  # src/huge.c
  # src/jemalloc.c
  # src/mb.c
  # src/mutex.c
  # src/pages.c
  # src/prof.c
  # src/quarantine.c
  # src/rtree.c
  # src/stats.c
  # src/tcache.c
  # src/tsd.c
  # src/util.c
  # src/valgrind.c
  # src/zone.c
# )

# add_library(${LIBJEMALLOCLIB} ${SOURCES})
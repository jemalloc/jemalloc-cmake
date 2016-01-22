# Utilities.cmake
# Supporting functions to build Jemalloc


###################################################
# SizeClasses
# Based on size_classes.sh
# lg_qarr - quanta
# lg_tmin - The range of tiny size classes is [2^lg_tmin..2^(lg_q-1)].
# lg_parr - list of page sizes
# lg_g - Size class group size (number of size classes for each size doubling).
function (SizeClasses lg_qarr lg_tmin lg_parr lg_g)

# The following limits are chosen such that they cover all supported platforms.

# Pointer sizes.
set(lg_zarr 2 3)

# Maximum lookup size.
set(lg_kmax 12)

endfunction (SizeClasses)

########################################################################
# Power of two
function (pow2 e RESULT_NAME)
  set(pow2_result 1)
  while ( ${e} GREATER 0 )
    math(EXPR pow2_result ${pow2_result} + ${pow2_result})
    math(EXPR e ${e} - 1)
  endwhile(${e} GREATER 0 )
  set(${RESULT_NAME} ${pow2_result} PARENT_SCOPE)
endfunction(pow2)

#########################################################################
# Logarithm base 2
function (lg x RESULT_NAME)
  set(lg_result 0)
  while ( ${x} GREATER 1 )
    math(EXPR lg_result ${lg_result} + 1)
    math(EXPR x ${x} / 2)
  endwhile ( ${x} GREATER 1 )
  set(${RESULT_NAME} ${lg_result} PARENT_SCOPE)
endfunction(lg)

#############################################
# Generate public symbols list
function (GeneratePublicSymbolsList public_sym_list mangling_map symbol_prefix output_file)

file(REMOVE ${output_file})

# First remove from public symbols those that appear in the mangling map
if(mangling_map)
  foreach(map_entry ${mangling_map})
    # Extract the symbol
    string(REGEX REPLACE "([^ \t]*):[^ \t]*" "\\1" sym ${map_entry})
    list(REMOVE_ITEM  public_sym_list ${sym})
    file(APPEND ${output_file} "${map_entry}\n")
  endforeach(map_entry)
endif()  

foreach(pub_sym ${public_sym_list})
  file(APPEND ${output_file} "${pub_sym}:${symbol_prefix}${pub_sym}\n")
endforeach(pub_sym)

endfunction(GeneratePublicSymbolsList)

#####################################################################
# Decorate symbols with a prefix
#
# This is per jemalloc_mangle.sh script.
#
# IMHO, the script has a bug that is currently reflected here
# If the public symbol as alternatively named in a mangling map it is not
# reflected here. Instead, all symbols are #defined using the passed symbol_prefix
function (GenerateJemallocMangle public_sym_list symbol_prefix output_file)

# Header
file(WRITE ${output_file}
"/*\n * By default application code must explicitly refer to mangled symbol names,\n"
" * so that it is possible to use jemalloc in conjunction with another allocator\n"
" * in the same application.  Define JEMALLOC_MANGLE in order to cause automatic\n"
" * name mangling that matches the API prefixing that happened as a result of\n"
" * --with-mangling and/or --with-jemalloc-prefix configuration settings.\n"
" */\n"
"#ifdef JEMALLOC_MANGLE\n"
"#  ifndef JEMALLOC_NO_DEMANGLE\n"
"#    define JEMALLOC_NO_DEMANGLE\n"
"#  endif\n"
)

file(STRINGS ${public_sym_list} INPUT_STRINGS)

foreach(line ${INPUT_STRINGS})
  string(REGEX REPLACE "([^ \t]*):[^ \t]*" "#  define \\1 ${symbol_prefix}\\1" output ${line})      
  file(APPEND ${output_file} "${output}\n")
endforeach(line)

file(APPEND ${output_file}
"#endif\n\n"
"/*\n"
" * The ${symbol_prefix}* macros can be used as stable alternative names for the\n"
" * public jemalloc API if JEMALLOC_NO_DEMANGLE is defined.  This is primarily\n"
" * meant for use in jemalloc itself, but it can be used by application code to\n"
" * provide isolation from the name mangling specified via --with-mangling\n"
" * and/or --with-jemalloc-prefix.\n"
" */\n"
"#ifndef JEMALLOC_NO_DEMANGLE\n"
)

foreach(line ${INPUT_STRINGS})
  string(REGEX REPLACE "([^ \t]*):[^ \t]*" "#  undef ${symbol_prefix}\\1" output ${line})      
  file(APPEND ${output_file} "${output}\n")
endforeach(line)

# Footer
file(APPEND ${output_file} "#endif\n")

endfunction (GenerateJemallocMangle)

########################################################################
# Generate jemalloc_rename.h per jemalloc_rename.sh
function (GenerateJemallocRename public_sym_list_file file_path)
# Header
file(WRITE ${file_path}
  "/*\n * Name mangling for public symbols is controlled by --with-mangling and\n"
  " * --with-jemalloc-prefix.  With" "default settings the je_" "prefix is stripped by\n"
  " * these macro definitions.\n"
  " */\n#ifndef JEMALLOC_NO_RENAME\n\n"
)

file(STRINGS ${public_sym_list_file} INPUT_STRINGS)
foreach(line ${INPUT_STRINGS})
  string(REGEX REPLACE "([^ \t]*):([^ \t]*)" "#define je_\\1 \\2" output ${line})
  file(APPEND ${file_path} "${output}\n")
endforeach(line)

# Footer
file(APPEND ${file_path}
  "#endif\n"
)
endfunction (GenerateJemallocRename)

###############################################################
# Create a jemalloc.h header by concatenating the following headers
# Mimic processing from jemalloc.sh
function (CreateJemallocHeader header_list output_file)
# File Header
file(WRITE ${output_file}
  "#pragma once\n\n"
  "#ifndef JEMALLOC_H_\n"
  "#define	JEMALLOC_H_\n"
  "#ifdef __cplusplus\n"
  "extern \"C\" {\n"
  "#endif\n\n"
)

foreach(pub_hdr ${header_list})
  file(STRINGS ${CMAKE_CURRENT_SOURCE_DIR}/include/jemalloc/${pub_hdr} HDR_CONT)
  foreach(line ${HDR_CONT})
    string(REGEX REPLACE "^#define " "#define\t" line ${line})      
    string(REGEX REPLACE " $" "" line ${line})
    file(APPEND ${output_file} "${line}\n")
  endforeach(line)
endforeach(pub_hdr)

# Footer
file(APPEND ${output_file}
  "#ifdef __cplusplus\n"
  "}\n"
  "#endif\n"
  "#endif /* JEMALLOC_H_ */\n"
)
endfunction(CreateJemallocHeader)

############################################################################
# Redefines public symbols prefxied with je_ via a macro
# Based on public_namespace.sh which echoes the result to a stdout
function(PublicNamespace public_sym_list_file output_file)

file(STRINGS ${public_sym_list_file} INPUT_STRINGS)
foreach(line ${INPUT_STRINGS})
  string(REGEX REPLACE "([^ \t]*):[^ \t]*" "#define	je_\\1 JEMALLOC_N(\\1)" output ${line})
  file(APPEND ${output_file} "${output}\n")
endforeach(line)
  
endfunction(PublicNamespace)

############################################################################
# #undefs public je_prefixed symbols
# Based on public_unnamespace.sh which echoes the result to a stdout
function(PublicUnnamespace public_sym_list_file output_file)

file(STRINGS ${public_sym_list_file} INPUT_STRINGS)
foreach(line ${INPUT_STRINGS})
  string(REGEX REPLACE "([^ \t]*):[^ \t]*" "#undef	je_\\1" output ${line})
  file(APPEND ${output_file} "${output}\n")
endforeach(line)

endfunction(PublicUnnamespace)


####################################################################
# Redefines a private symbol via a macro
# Based on private_namespace.sh
function(PrivateNamespace private_sym_list_file output_file)

file(STRINGS ${private_sym_list_file} INPUT_STRINGS)
foreach(line ${INPUT_STRINGS})
  file(APPEND ${output_file} "#define	${line} JEMALLOC_N(${line}\n")
endforeach(line)

endfunction(PrivateNamespace)

####################################################################
# Redefines a private symbol via a macro
# Based on private_namespace.sh
function(PrivateUnnamespace private_sym_list_file output_file)

file(STRINGS ${private_sym_list_file} INPUT_STRINGS)
foreach(line ${INPUT_STRINGS})
  file(APPEND ${output_file} "#undef ${line}\n")
endforeach(line)

endfunction(PrivateUnnamespace)


############################################################################
# A function that configures a file_path and outputs
# end result into output_path
# ExpandDefine True/False if we want to process the file and expand
# lines that start with #undef DEFINE into what is defined in CMAKE
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

############################################################################################
## Run Git and parse the output to populate version settings above
function (GetAndParseVersion)

if (GIT_FOUND AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")
    execute_process(COMMAND $ENV{COMSPEC} /C 
      ${GIT_EXECUTABLE} -C ${CMAKE_CURRENT_SOURCE_DIR} describe --long --abbrev=40 HEAD OUTPUT_VARIABLE jemalloc_version)
    
    # Figure out version components    
    string (REPLACE "\n" "" jemalloc_version  ${jemalloc_version})
    set(jemalloc_version ${jemalloc_version} PARENT_SCOPE)
    message(STATUS "Version is ${jemalloc_version}")

    # replace in this order to get a valid cmake list
    string (REPLACE "-g" "-" T_VERSION ${jemalloc_version})
    string (REPLACE "-" "." T_VERSION  ${T_VERSION})
    string (REPLACE "." ";" T_VERSION  ${T_VERSION})

    list(LENGTH T_VERSION L_LEN)

    if(${L_LEN} GREATER 0)
      list(GET T_VERSION 0 jemalloc_version_major)
      set(jemalloc_version_major ${jemalloc_version_major} PARENT_SCOPE)
      message(STATUS "jemalloc_version_major: ${jemalloc_version_major}")
    endif()

    if(${L_LEN} GREATER 1)
      list(GET T_VERSION 1 jemalloc_version_minor)
      set(jemalloc_version_minor ${jemalloc_version_minor} PARENT_SCOPE)
      message(STATUS "jemalloc_version_minor: ${jemalloc_version_minor}")
    endif()

    if(${L_LEN} GREATER 2)
      list(GET T_VERSION 2 jemalloc_version_bugfix)
      set(jemalloc_version_bugfix ${jemalloc_version_bugfix} PARENT_SCOPE)
      message(STATUS "jemalloc_version_bugfix: ${jemalloc_version_bugfix}")
    endif()

    if(${L_LEN} GREATER 3)
      list(GET T_VERSION 3 jemalloc_version_nrev)
      set(jemalloc_version_nrev ${jemalloc_version_nrev} PARENT_SCOPE)
      message(STATUS "jemalloc_version_nrev: ${jemalloc_version_nrev}")
    endif()

    if(${L_LEN} GREATER 4)
      list(GET T_VERSION 4 jemalloc_version_gid)
      set(jemalloc_version_gid ${jemalloc_version_gid} PARENT_SCOPE)
      message(STATUS "jemalloc_version_gid: ${jemalloc_version_gid}")
    endif()
endif()

endfunction (GetAndParseVersion)

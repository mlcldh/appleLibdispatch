
include(CMakeParseArguments)

function(add_swift_target target)
  set(options LIBRARY;SHARED;STATIC)
  set(single_value_options MODULE_NAME;MODULE_LINK_NAME;MODULE_PATH;MODULE_CACHE_PATH;OUTPUT;TARGET)
  set(multiple_value_options CFLAGS;DEPENDS;LINK_FLAGS;RESOURCES;SOURCES;SWIFT_FLAGS)

  cmake_parse_arguments(AST "${options}" "${single_value_options}" "${multiple_value_options}" ${ARGN})

  set(compile_flags ${CMAKE_SWIFT_FLAGS})
  set(link_flags ${CMAKE_SWIFT_LINK_FLAGS})

  if(AST_TARGET)
    list(APPEND compile_flags -target;${AST_TARGET})
    list(APPEND link_flags -target;${AST_TARGET})
  endif()
  if(AST_MODULE_NAME)
    list(APPEND compile_flags -module-name;${AST_MODULE_NAME})
  else()
    list(APPEND compile_flags -module-name;${target})
  endif()
  if(AST_MODULE_LINK_NAME)
    list(APPEND compile_flags -module-link-name;${AST_MODULE_LINK_NAME})
  endif()
  if(AST_MODULE_CACHE_PATH)
    list(APPEND compile_flags -module-cache-path;${AST_MODULE_CACHE_PATH})
  endif()
  if(CMAKE_BUILD_TYPE MATCHES Debug OR CMAKE_BUILD_TYPE MATCHES RelWithDebInfo)
    list(APPEND compile_flags -g)
  endif()
  if(AST_SWIFT_FLAGS)
    foreach(flag ${AST_SWIFT_FLAGS})
      list(APPEND compile_flags ${flag})
    endforeach()
  endif()
  if(AST_CFLAGS)
    foreach(flag ${AST_CFLAGS})
      list(APPEND compile_flags -Xcc;${flag})
    endforeach()
  endif()
  if(AST_LINK_FLAGS)
    foreach(flag ${AST_LINK_FLAGS})
      list(APPEND link_flags ${flag})
    endforeach()
  endif()
  if(AST_LIBRARY)
    if(AST_STATIC AND AST_SHARED)
      message(SEND_ERROR "add_swift_target asked to create library as STATIC and SHARED")
    elseif(AST_STATIC OR NOT BUILD_SHARED_LIBS)
      set(library_kind STATIC)
    elseif(AST_SHARED OR BUILD_SHARED_LIBS)
      set(library_kind SHARED)
    endif()
  else()
    if(AST_STATIC OR AST_SHARED)
      message(SEND_ERROR "add_swift_target asked to create executable as STATIC or SHARED")
    endif()
  endif()
  if(NOT AST_OUTPUT)
    if(AST_LIBRARY)
      if(AST_SHARED OR BUILD_SHARED_LIBS)
        set(AST_OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${target}.dir/${CMAKE_SHARED_LIBRARY_PREFIX}${target}${CMAKE_SHARED_LIBRARY_SUFFIX})
      else()
        set(AST_OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${target}.dir/${CMAKE_STATIC_LIBRARY_PREFIX}${target}${CMAKE_STATIC_LIBRARY_SUFFIX})
      endif()
    else()
      set(AST_OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${target}.dir/${target}${CMAKE_EXECUTABLE_SUFFIX})
    endif()
  endif()
  if(CMAKE_SYSTEM_NAME STREQUAL Windows)
    if(AST_SHARED OR BUILD_SHARED_LIBS)
      set(IMPORT_LIBRARY ${CMAKE_CURRENT_BINARY_DIR}/${target}.dir/${CMAKE_IMPORT_LIBRARY_PREFIX}${target}${CMAKE_IMPORT_LIBRARY_SUFFIX})
    endif()
  endif()

  set(sources)
  foreach(source ${AST_SOURCES})
    get_filename_component(location ${source} PATH)
    if(IS_ABSOLUTE ${location})
      list(APPEND sources ${source})
    else()
      list(APPEND sources ${CMAKE_CURRENT_SOURCE_DIR}/${source})
    endif()
  endforeach()

  set(objs)
  set(mods)
  set(docs)
  set(i 0)
  foreach(source ${sources})
    get_filename_component(name ${source} NAME)

    set(obj ${CMAKE_CURRENT_BINARY_DIR}/${target}.dir/${name}${CMAKE_C_OUTPUT_EXTENSION})
    set(mod ${CMAKE_CURRENT_BINARY_DIR}/${target}.dir/${name}.swiftmodule)
    set(doc ${CMAKE_CURRENT_BINARY_DIR}/${target}.dir/${name}.swiftdoc)

    set(all_sources ${sources})
    list(INSERT all_sources ${i} -primary-file)

    add_custom_command(OUTPUT
                         ${obj}
                         ${mod}
                         ${doc}
                       DEPENDS
                         ${source}
                         ${AST_DEPENDS}
                       COMMAND
                         ${CMAKE_SWIFT_COMPILER} -frontend ${compile_flags} -emit-module-path ${mod} -emit-module-doc-path ${doc} -o ${obj} -c ${all_sources})

    list(APPEND objs ${obj})
    list(APPEND mods ${mod})
    list(APPEND docs ${doc})

    math(EXPR i "${i}+1")
  endforeach()

  if(AST_LIBRARY)
    get_filename_component(module_directory ${AST_MODULE_PATH} DIRECTORY)

    set(module ${AST_MODULE_PATH})
    set(documentation ${module_directory}/${AST_MODULE_NAME}.swiftdoc)

    add_custom_command(OUTPUT
                         ${module}
                         ${documentation}
                       DEPENDS
                         ${mods}
                         ${docs}
                         ${AST_DEPENDS}
                       COMMAND
                         ${CMAKE_SWIFT_COMPILER} -frontend ${compile_flags} -sil-merge-partial-modules -emit-module ${mods} -o ${module} -emit-module-doc-path ${documentation})
  endif()

  if(AST_LIBRARY)
    if(CMAKE_SYSTEM_NAME STREQUAL Windows OR CMAKE_SYSTEM_NAME STREQUAL Darwin)
      set(emit_library -emit-library)
    else()
      set(emit_library -emit-library -Xlinker -soname -Xlinker ${CMAKE_SHARED_LIBRARY_PREFIX}${target}${CMAKE_SHARED_LIBRARY_SUFFIX})
    endif()
  endif()
  if(NOT AST_LIBRARY OR library_kind STREQUAL SHARED)
    add_custom_command(OUTPUT
                         ${AST_OUTPUT}
                       DEPENDS
                         ${objs}
                         ${AST_DEPENDS}
                       COMMAND
                         ${CMAKE_SWIFT_COMPILER} ${emit_library} ${link_flags} -o ${AST_OUTPUT} ${objs})
    add_custom_target(${target}
                      ALL
                      DEPENDS
                         ${AST_OUTPUT}
                         ${module}
                         ${documentation})
  else()
    add_library(${target}-static STATIC ${objs})
    add_dependencies(${target}-static ${AST_DEPENDS})
    get_filename_component(ast_output_bn ${AST_OUTPUT} NAME)
    if(NOT CMAKE_STATIC_LIBRARY_PREFIX STREQUAL "")
      string(REGEX REPLACE "^${CMAKE_STATIC_LIBRARY_PREFIX}" "" ast_output_bn ${ast_output_bn})
    endif()
    if(NOT CMAKE_STATIC_LIBRARY_SUFFIX STREQUAL "")
      string(REGEX REPLACE "${CMAKE_STATIC_LIBRARY_SUFFIX}$" "" ast_output_bn ${ast_output_bn})
    endif()
    get_filename_component(ast_output_dn ${AST_OUTPUT} DIRECTORY)
    set_target_properties(${target}-static
                          PROPERTIES
                            LINKER_LANGUAGE C
                            ARCHIVE_OUTPUT_DIRECTORY ${ast_output_dn}
                            OUTPUT_DIRECTORY ${ast_output_dn}
                            OUTPUT_NAME ${ast_output_bn})
    add_custom_target(${target}
                      ALL
                      DEPENDS
                         ${target}-static
                         ${module}
                         ${documentation})
  endif()

  if(AST_RESOURCES)
    add_custom_command(TARGET
                         ${target}
                       POST_BUILD
                       COMMAND
                         ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/${target}
                       COMMAND
                         ${CMAKE_COMMAND} -E copy ${AST_OUTPUT} ${CMAKE_CURRENT_BINARY_DIR}/${target}
                       COMMAND
                         ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/${target}/Resources
                       COMMAND
                         ${CMAKE_COMMAND} -E copy ${AST_RESOURCES} ${CMAKE_CURRENT_BINARY_DIR}/${target}/Resources)
  else()
    add_custom_command(TARGET
                         ${target}
                       POST_BUILD
                       COMMAND
                         ${CMAKE_COMMAND} -E copy ${AST_OUTPUT} ${CMAKE_CURRENT_BINARY_DIR})
    if(CMAKE_SYSTEM_NAME STREQUAL Windows)
      if(AST_SHARED OR BUILD_SHARED_LIBS)
        add_custom_command(TARGET
                             ${target}
                           POST_BUILD
                           COMMAND
                             ${CMAKE_COMMAND} -E copy ${IMPORT_LIBRARY} ${CMAKE_CURRENT_BINARY_DIR})
      endif()
    endif()
  endif()
endfunction()

function(add_swift_library library)
  add_swift_target(${library} LIBRARY ${ARGN})
endfunction()

function(add_swift_executable executable)
  add_swift_target(${executable} ${ARGN})
endfunction()

# Returns the current achitecture name in a variable
#
# Usage:
#   get_swift_host_arch(result_var_name)
#
# If the current architecture is supported by Swift, sets ${result_var_name}
# with the sanitized host architecture name derived from CMAKE_SYSTEM_PROCESSOR.
function(get_swift_host_arch result_var_name)
  if("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "x86_64")
    set("${result_var_name}" "x86_64" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "aarch64")
    set("${result_var_name}" "aarch64" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "ppc64")
    set("${result_var_name}" "powerpc64" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "ppc64le")
    set("${result_var_name}" "powerpc64le" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "s390x")
    set("${result_var_name}" "s390x" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "armv6l")
    set("${result_var_name}" "armv6" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "armv7-a")
    set("${result_var_name}" "armv7" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "armv7l")
    set("${result_var_name}" "armv7" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "AMD64")
    set("${result_var_name}" "x86_64" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "IA64")
    set("${result_var_name}" "itanium" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "x86")
    set("${result_var_name}" "i686" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "i686")
    set("${result_var_name}" "i686" PARENT_SCOPE)
  else()
    message(FATAL_ERROR "Unrecognized architecture on host system: ${CMAKE_SYSTEM_PROCESSOR}")
  endif()
endfunction()

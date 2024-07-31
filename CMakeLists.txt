# cmake arguments
# CMAKE_BUILD_TYPE:			Compilation target (Debug or Release defaults to Debug)
#
# godot-cpp cmake arguments
# GODOT_ARCH:					Target architecture (x86_32, x86_64, arm32, arm64, rv64, wasm32, universal)
# GODOT_GDEXTENSION_DIR:		Path to the directory containing GDExtension interface header and API JSON file
# GODOT_CPP_SYSTEM_HEADERS		Mark the header files as SYSTEM. This may be useful to suppress warnings in projects including this one.
# GODOT_CPP_WARNING_AS_ERROR	Treat any warnings as errors
# GODOT_CUSTOM_API_FILE:		Path to a custom GDExtension API JSON file (takes precedence over `gdextension_dir`)
# FLOAT_PRECISION:				Floating-point precision level ("single", "double")
#
# Android cmake arguments
# CMAKE_TOOLCHAIN_FILE:		The path to the android cmake toolchain ($ANDROID_NDK/build/cmake/android.toolchain.cmake)
# ANDROID_NDK:				The path to the android ndk root folder
# ANDROID_TOOLCHAIN_NAME:	The android toolchain (arm-linux-androideabi-4.9 or aarch64-linux-android-4.9 or x86-4.9 or x86_64-4.9)
# ANDROID_PLATFORM:			The android platform version (android-23)
# More info here: https://godot.readthedocs.io/en/latest/development/compiling/compiling_for_android.html
#
# Examples
#
# Builds a debug version:
# cmake .
# cmake --build .
#
# Builds a release version with clang
# CC=/usr/bin/clang CXX=/usr/bin/clang++ cmake -DCMAKE_BUILD_TYPE=Release -G "Unix Makefiles" .
# cmake --build .
#
# Builds an android armeabi-v7a debug version:
# cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake -DANDROID_NDK=$ANDROID_NDK \
#		-DANDROID_TOOLCHAIN_NAME=arm-linux-androideabi-4.9 -DANDROID_PLATFORM=android-23 -DCMAKE_BUILD_TYPE=Debug .
# cmake --build .
#
# Protip
# Generate the buildfiles in a sub directory to not clutter the root directory with build files:
# mkdir build && cd build && cmake -G "Unix Makefiles" .. && cmake --build .
#
# Todo
# Test build for Windows, Mac and mingw.
#
# Notes:
# Every godot API change, reconfigure the file


cmake_minimum_required(VERSION 3.20)
project(godot-cpp LANGUAGES CXX)

#
#	Include our custom cmake modules
#
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/")


option(GENERATE_TEMPLATE_GET_NODE "Generate a template version of the Node class's get_node." ON)
option(GODOT_CPP_SYSTEM_HEADERS "Expose headers as SYSTEM." ON)
option(GODOT_CPP_WARNING_AS_ERROR "Treat warnings as errors" OFF)


#
#	Detect host architecture
#
include(DetectHostArchitecture)


#
#	Set Godot Arch and Godot Platform
#
include(SetGodotArch)


#
#	Set Default build type to Debug
#
if("${CMAKE_BUILD_TYPE}" STREQUAL "")
	set(CMAKE_BUILD_TYPE Debug)
endif()


#
#	Input from user for GDExtension interface header and the API JSON file
#
set(GODOT_GDEXTENSION_DIR "gdextension" CACHE STRING "Directory for Godot's GDExtension")
set(GODOT_CUSTOM_API_FILE "" CACHE STRING "")

set(GODOT_GDEXTENSION_API_FILE "${GODOT_GDEXTENSION_DIR}/extension_api.json")
if (NOT "${GODOT_CUSTOM_API_FILE}" STREQUAL "")  # User-defined override.
	set(GODOT_GDEXTENSION_API_FILE "${GODOT_CUSTOM_API_FILE}")
endif()


#
#	Defines REAL_T_IS_DOUBLE if FLOAT_PRECISION equlas double
#
set(FLOAT_PRECISION "single" CACHE STRING "Defines float precision type, if set to double, REAL_T_IS_DOUBLE is defined")
if ("${FLOAT_PRECISION}" STREQUAL "double")
	add_definitions(-DREAL_T_IS_DOUBLE)
endif()


#
#	Set Godot compile flags
#
set(GODOT_COMPILE_FLAGS)


# If compiling with MSVC
if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
	set(GODOT_COMPILE_FLAGS "/utf-8") # /GF /MP

	if(CMAKE_BUILD_TYPE MATCHES Debug)
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /MDd") # /Od /RTC1 /Zi
	else()
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /MD /O2") # /Oy /GL /Gy
		STRING(REGEX REPLACE "/RTC(su|[1su])" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
		string(REPLACE "/RTC1" "" CMAKE_CXX_FLAGS_DEBUG ${CMAKE_CXX_FLAGS_DEBUG})
	endif(CMAKE_BUILD_TYPE MATCHES Debug)

	add_definitions(-DNOMINMAX)
else()  # GCC/Clang
	if(CMAKE_BUILD_TYPE MATCHES Debug) 
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -fno-omit-frame-pointer -O0 -g")
	else()
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -O3")
	endif(CMAKE_BUILD_TYPE MATCHES Debug)
endif()


#
#	Disable exception handling. Godot doesn't use exceptions anywhere, and this
#	saves around 20% of binary size and very significant build time (GH-80513).
#
include(DisableExceptions)


#
#	Generate source from the bindings file
#
find_package(Python3 3.4 REQUIRED) # pathlib should be present
if(GENERATE_TEMPLATE_GET_NODE)
	set(GENERATE_BINDING_PARAMETERS "True")
else()
	set(GENERATE_BINDING_PARAMETERS "False")
endif()

execute_process(COMMAND 
	"${Python3_EXECUTABLE}" "-c" "import binding_generator; binding_generator.print_file_list(\"${GODOT_GDEXTENSION_API_FILE}\", \"${CMAKE_CURRENT_BINARY_DIR}\", headers=True, sources=True)"
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	OUTPUT_VARIABLE GENERATED_FILES_LIST
	OUTPUT_STRIP_TRAILING_WHITESPACE
)


#
#	Bits are passed to binding_generator.generate_bindings because this determines the sizes of types in the generated bindings.
#	We do not need to pass the full GODOT_ARCH, because we require that types be the same size between, for example, x86_64, arm64, and rv64.
#
if(NOT DEFINED BITS)
	set(BITS 32)
	if(CMAKE_SIZEOF_VOID_P EQUAL 8)
		set(BITS 64)
	endif(CMAKE_SIZEOF_VOID_P EQUAL 8)
endif()

add_custom_command(OUTPUT ${GENERATED_FILES_LIST}
		COMMAND "${Python3_EXECUTABLE}" "-c" "import binding_generator; binding_generator.generate_bindings(\"${GODOT_GDEXTENSION_API_FILE}\", \"${GENERATE_BINDING_PARAMETERS}\", \"${BITS}\", \"${FLOAT_PRECISION}\", \"${CMAKE_CURRENT_BINARY_DIR}\")"
		VERBATIM
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		MAIN_DEPENDENCY ${GODOT_GDEXTENSION_API_FILE}
		DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/binding_generator.py
		COMMENT "Generating bindings"
)


#
#	Set Sources
#
set(SOURCES 
	"src/godot.cpp" "src/classes/editor_plugin_registration.cpp" "src/classes/low_level.cpp" "src/classes/wrapped.cpp"
	"src/core/class_db.cpp" "src/core/error_macros.cpp" "src/core/memory.cpp" "src/core/method_bind.cpp" "src/core/object.cpp"
	"src/variant/aabb.cpp" "src/variant/basis.cpp" "src/variant/callable_custom.cpp" "src/variant/callable_method_pointer.cpp" "src/variant/char_string.cpp"
	"src/variant/color.cpp" "src/variant/packed_arrays.cpp" "src/variant/plane.cpp" "src/variant/projection.cpp" "src/variant/quaternion.cpp" "src/variant/rect2.cpp"
	"src/variant/rect2i.cpp" "src/variant/transform2d.cpp" "src/variant/transform3d.cpp" "src/variant/variant.cpp" "src/variant/vector2.cpp" "src/variant/vector2i.cpp"
	"src/variant/vector3.cpp" "src/variant/vector4.cpp" "src/variant/vector4i.cpp")
set(HEADERS 
	"include/godot_cpp/godot.hpp" "include/godot_cpp/classes/editor_plugin_registration.hpp" "include/godot_cpp/classes/ref.hpp" "include/godot_cpp/classes/wrapped.hpp"
	"include/godot_cpp/core/binder_common.hpp" "include/godot_cpp/core/builtin_ptrcall.hpp" "include/godot_cpp/core/class_db.hpp" 
	"include/godot_cpp/core/defs.hpp" "include/godot_cpp/core/engine_ptrcall.hpp" "include/godot_cpp/core/error_macros.hpp" 
	"include/godot_cpp/core/math.hpp" "include/godot_cpp/core/memory.hpp" "include/godot_cpp/core/method_bind.hpp" 
	"include/godot_cpp/core/method_ptrcall.hpp" "include/godot_cpp/core/mutex_lock.hpp" "include/godot_cpp/core/object.hpp" 
	"include/godot_cpp/core/object_id.hpp" "include/godot_cpp/core/property_info.hpp" "include/godot_cpp/core/type_info.hpp"
	"include/godot_cpp/variant/aabb.hpp" "include/godot_cpp/variant/array_helpers.hpp" "include/godot_cpp/variant/basis.hpp" 
	"include/godot_cpp/variant/callable_custom.hpp" "include/godot_cpp/variant/callable_method_pointer.hpp" "include/godot_cpp/variant/char_string.hpp" 
	"include/godot_cpp/variant/char_utils.hpp" "include/godot_cpp/variant/color.hpp" "include/godot_cpp/variant/color_names.inc.hpp" 
	"include/godot_cpp/variant/plane.hpp" "include/godot_cpp/variant/projection.hpp" "include/godot_cpp/variant/quaternion.hpp" 
	"include/godot_cpp/variant/rect2.hpp" "include/godot_cpp/variant/rect2i.hpp" "include/godot_cpp/variant/transform2d.hpp" 
	"include/godot_cpp/variant/transform3d.hpp" "include/godot_cpp/variant/typed_array.hpp" "include/godot_cpp/variant/variant.hpp" 
	"include/godot_cpp/variant/vector2.hpp" "include/godot_cpp/variant/vector2i.hpp" "include/godot_cpp/variant/vector3.hpp" 
	"include/godot_cpp/variant/vector3i.hpp" "include/godot_cpp/variant/vector4.hpp" "include/godot_cpp/variant/vector4i.hpp")


#
#	Define our godot-cpp library project
#
add_library(${PROJECT_NAME} 
	STATIC
		${SOURCES}
		${HEADERS}
		${GENERATED_FILES_LIST}
)
add_library(godot::cpp ALIAS ${PROJECT_NAME})


#
#	Include GodotCompilerWarnings
#
include(GodotCompilerWarnings)


#
#	Set compile features
#
target_compile_features(${PROJECT_NAME}
	PRIVATE
		cxx_std_17
)


#
#	Set compile definitions when in debug build
#
if(CMAKE_BUILD_TYPE MATCHES Debug)
	target_compile_definitions(${PROJECT_NAME} PUBLIC
		DEBUG_ENABLED
		DEBUG_METHODS_ENABLED
	)
endif()


#
#	Compiler-specific options
#
# For MSVC
if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
	target_compile_definitions(${PROJECT_NAME} PUBLIC
		TYPED_METHOD_BIND
	)
else()
	if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
		target_link_options(${PROJECT_NAME} PRIVATE
			-static-libgcc
		)
	endif()
	
	# Both Clang and GCC
	target_link_options(${PROJECT_NAME} PRIVATE
		-static-libstdc++
		-Wl,-R,'$ORIGIN'
	)
endif()


#
#	Optionally mark headers as SYSTEM
#
set(GODOT_CPP_SYSTEM_HEADERS_ATTRIBUTE "")
if (GODOT_CPP_SYSTEM_HEADERS)
	set(GODOT_CPP_SYSTEM_HEADERS_ATTRIBUTE SYSTEM)
endif ()


#
#	Set include directories
#
target_include_directories(${PROJECT_NAME} ${GODOT_CPP_SYSTEM_HEADERS_ATTRIBUTE} PUBLIC
	include
	${CMAKE_CURRENT_BINARY_DIR}/gen/include
	${GODOT_GDEXTENSION_DIR}
)


#
#	Add the compile flags
#
set_property(TARGET ${PROJECT_NAME} APPEND_STRING PROPERTY COMPILE_FLAGS ${GODOT_COMPILE_FLAGS})


#
#	Create the correct output name (godot.os.build_type.system_bits)
#
string(TOLOWER "${CMAKE_BUILD_TYPE}" BUILD_TYPE)
set(OUTPUT_NAME "godot-cpp.${GODOT_PLATFORM}.${BUILD_TYPE}.${GODOT_ARCH}")


#
#	Set target properties
#
set_target_properties(${PROJECT_NAME}
	PROPERTIES
		CXX_EXTENSIONS OFF
		POSITION_INDEPENDENT_CODE ON
		ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin"
		LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin"
		RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin"
		OUTPUT_NAME "${OUTPUT_NAME}"
)

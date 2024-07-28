cmake_minimum_required(VERSION 3.20)
project(godot-cpp-test LANGUAGES CXX)


#
#	Set GodotCPPProjectPath and GDExtensionDir to one path above this one
#
cmake_path(SET GodotCPPProjectPath NORMALIZE "../")
cmake_path(ABSOLUTE_PATH GodotCPPProjectPath NORMALIZE)
cmake_path(SET GODOT_GDEXTENSION_DIR NORMALIZE "../gdextension")
cmake_path(ABSOLUTE_PATH GODOT_GDEXTENSION_DIR NORMALIZE)

#
#	Include godot-cpp's custom cmake modules
#
cmake_path(SET MODULES_PATH NORMALIZE "../cmake")
cmake_path(ABSOLUTE_PATH MODULES_PATH NORMALIZE)
list(APPEND CMAKE_MODULE_PATH ${MODULES_PATH})


#
#	Detect host architecture
#
include(DetectHostArchitecture)


#
#	Set Godot architecture and Platform variables
#
include(SetGodotArch)


#
#	Include directories and godot-cpp CMake Project
#
#include_directories(${GodotCPPProjectPath})
#add_subdirectory(${GodotCPPProjectPath})
#include(${GodotCPPProjectPath}CMakeLists.txt)


# Aragubas: These checks need to go right after including godot-cpp's CMakeLists.txt
if (NOT DEFINED GODOT_ARCH)
	message(FATAL_ERROR "Expected GODOT_ARCH to be defined by godot-cpp's CMakeLists.txt")
endif ()
if (NOT DEFINED GODOT_PLATFORM)
	message(FATAL_ERROR "Expected GODOT_PLATFORM to be defined by godot-cpp's CMakeLists.txt")
endif ()


#
#	Change the output directory to the bin directory
#
set(BUILD_PATH ${CMAKE_SOURCE_DIR}/bin)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${BUILD_PATH}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${BUILD_PATH}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${BUILD_PATH}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG "${BUILD_PATH}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE "${BUILD_PATH}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG "${BUILD_PATH}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE "${BUILD_PATH}")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_DEBUG "${BUILD_PATH}")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE "${BUILD_PATH}")


#
#	Set Default build type to Debug
#
if("${CMAKE_BUILD_TYPE}" STREQUAL "")
	set(CMAKE_BUILD_TYPE Debug)
endif()


#
#	Set the c++ standard to c++17
#
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(GODOT_COMPILE_FLAGS "")
set(GODOT_LINKER_FLAGS "")


#
#	Set godot compile flags
#
# If compiling under MSVC
if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /WX") # /GF /MP
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /DTYPED_METHOD_BIND")

	if(CMAKE_BUILD_TYPE MATCHES Debug)
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /MDd") # /Od /RTC1 /Zi
	else()
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /MD /O2") # /Oy /GL /Gy
		STRING(REGEX REPLACE "/RTC(su|[1su])" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
		string(REPLACE "/RTC1" "" CMAKE_CXX_FLAGS_DEBUG ${CMAKE_CXX_FLAGS_DEBUG})
	endif(CMAKE_BUILD_TYPE MATCHES Debug)

	# Disable conversion warning, truncation, unreferenced var, signed mismatch
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /wd4244 /wd4305 /wd4101 /wd4018 /wd4267")

	add_definitions(-DNOMINMAX)

	# Uncomment for warning level 4
	#if(CMAKE_CXX_FLAGS MATCHES "/W[0-4]")
	#	string(REGEX REPLACE "/W[0-4]" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
	#endif()

else()
	if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
		set(GODOT_LINKER_FLAGS "-static-libgcc -static-libstdc++ -Wl,-R,'$ORIGIN'")
	else()
		set(GODOT_LINKER_FLAGS "-Wl,-rpath,'$ORIGIN'")
	endif()

	set(GODOT_COMPILE_FLAGS "-fPIC -g -Wwrite-strings")

	if(CMAKE_BUILD_TYPE MATCHES Debug)
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -fno-omit-frame-pointer -O0")
	else()
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -O3")
	endif(CMAKE_BUILD_TYPE MATCHES Debug)
endif()


#
#	Disable exception handling. Godot doesn't use exceptions anywhere, and this
#	saves around 20% of binary size and very significant build time (GH-80513).
#
option(GODOT_DISABLE_EXCEPTIONS ON "Force disabling exception handling code")
if (GODOT_DISABLE_EXCEPTIONS)
	if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -D_HAS_EXCEPTIONS=0")
	else()
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -fno-exceptions")
	endif()
else()
	if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /EHsc")
	endif()
endif()


#
#	Set Sources
#
set(SOURCES "src/example.cpp" "src/register_types.cpp")
set(HEADERS "src/example.h" "src/register_types.h" "src/tests.h")


#
#	Define project
#
add_library(${PROJECT_NAME} SHARED ${SOURCES} ${HEADERS})


#
#	Include GodotCompileWarnings
#
include(GodotCompilerWarnings)


#
#	Set include directories
#
target_include_directories(${PROJECT_NAME} SYSTEM
	PRIVATE
		${GodotCPPProjectPath}include
		${GodotCPPProjectPath}cmake_build/gen/include
		${GODOT_GDEXTENSION_DIR}
)


#
#	Create the correct name (godot.os.build_type.godot_arch)
#	Synchronized with godot-cpp's CMakeLists.txt
#
if(CMAKE_BUILD_TYPE MATCHES Debug)
	set(GODOT_CPP_BUILD_TYPE Debug)
else()
	set(GODOT_CPP_BUILD_TYPE Release)
endif()
string(TOLOWER ${GODOT_CPP_BUILD_TYPE} BUILD_TYPE)


#
#	Link with godot-cpp object file
#
if(CMAKE_VERSION VERSION_GREATER "3.13")
	target_link_directories(${PROJECT_NAME}
		PRIVATE
		${GodotCPPProjectPath}cmake_build/bin
	)

	target_link_libraries(${PROJECT_NAME}
		godot-cpp.${GODOT_PLATFORM}.${BUILD_TYPE}$<$<NOT:$<PLATFORM_ID:Android>>:.${GODOT_ARCH}>
	)
else()
	target_link_libraries(${PROJECT_NAME}
			${GodotCPPProjectPath}bin/libgodot-cpp.${GODOT_PLATFORM}.${BUILD_TYPE}$<$<NOT:$<PLATFORM_ID:Android>>:.${GODOT_ARCH}>.a
	)
endif()


#
#	Add the compile flags
#
set_property(TARGET ${PROJECT_NAME} APPEND_STRING PROPERTY COMPILE_FLAGS ${GODOT_COMPILE_FLAGS})
set_property(TARGET ${PROJECT_NAME} APPEND_STRING PROPERTY LINK_FLAGS ${GODOT_LINKER_FLAGS})

set_property(TARGET ${PROJECT_NAME} PROPERTY OUTPUT_NAME "gdexample")

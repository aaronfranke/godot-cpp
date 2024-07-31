#
#	Disable exception handling. Godot doesn't use exceptions anywhere, and this
#	saves around 20% of binary size and very significant build time (GH-80513).
#
option(GODOT_DISABLE_EXCEPTIONS ON "Force disabling exception handling code")
if (GODOT_DISABLE_EXCEPTIONS)
	# if building with MSVC
	if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -D_HAS_EXCEPTIONS=0")
	else()
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -fno-exceptions")
	endif()
else()
	# If build with MSVC
	if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /EHsc")
	endif()
endif()

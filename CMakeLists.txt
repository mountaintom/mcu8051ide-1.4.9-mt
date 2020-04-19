PROJECT(mcu8051ide "NONE")
SET(mcu8051ide_version 1.4.9)

#
# INITIALIZE
#

CMAKE_MINIMUM_REQUIRED(VERSION 2.6)
SET(CMAKE_BUILD_TYPE None)
SET(CMAKE_COLOR_MAKEFILE ON)
SET(CMAKE_VERBOSE_MAKEFILE ON)
SET(CMAKE_INCLUDE_CURRENT_DIR TRUE)

# target directory (for data files)
SET(target_installation_directory share/mcu8051ide)

#
# PREPARATION
#

# create launcher
FILE(WRITE mcu8051ide
	"#!/bin/sh\n"
	"exec tclsh ${CMAKE_INSTALL_PREFIX}/${target_installation_directory}/lib/main.tcl \"$@\" || \\\n"
	"\tprintf \"Unable to execute, TCL interpreter is not reachable.\n\" > /dev/stderr"
)

#
# INSTALLATION
#

# Install icons
FOREACH(subdir mcu flag other 16x16 22x22 32x32)
	FILE(GLOB_RECURSE icons icons/${subdir}/*.png)
	INSTALL(FILES ${icons} DESTINATION ${target_installation_directory}/icons/${subdir})
ENDFOREACH(subdir)

# Install source code files
FOREACH(subdir . bottompanel compiler configdialogues dialogues editor leftpanel lib pale rightpanel simulator simulator/engine utilities)
	FILE(GLOB lib lib/${subdir}/*.tcl)
	INSTALL(FILES ${lib} DESTINATION ${target_installation_directory}/lib/${subdir})
ENDFOREACH(subdir)

# Install contents of directory hwplugins
FILE(GLOB file hwplugins/*)
INSTALL(FILES ${file} DESTINATION ${target_installation_directory}/hwplugins)

# Install documentation files
FOREACH(subdir handbook)
	FOREACH(ext pdf)
		FILE(GLOB doc doc/${subdir}/*.${ext})
		INSTALL(FILES ${doc} DESTINATION ${target_installation_directory}/doc/${subdir})
	ENDFOREACH(ext)
ENDFOREACH(subdir)

# Install manual page(s)
FILE(GLOB man doc/man/*)
INSTALL(FILES ${man} DESTINATION share/man/man1)

# Install demonstration project files
FILE(GLOB demo demo/*)
INSTALL(FILES ${demo} DESTINATION ${target_installation_directory}/demo)

# Install data files
FILE(GLOB data data/*)
INSTALL(FILES ${data} DESTINATION ${target_installation_directory}/data)

# Install translation files
FILE(GLOB translations translations/*)
INSTALL(FILES ${translations} DESTINATION ${target_installation_directory}/translations)

# Install .desktop spec and application icon
INSTALL(FILES mcu8051ide.png DESTINATION share/pixmaps/)
INSTALL(FILES mcu8051ide.desktop DESTINATION share/applications/)
INSTALL(FILES mcu8051ide.appdata.xml DESTINATION share/appdata/)
INSTALL(FILES application-x-mcu8051ide.xml DESTINATION share/mime/packages/)

# Install launcher
INSTALL(
	FILES mcu8051ide
	DESTINATION bin
	PERMISSIONS
		WORLD_EXECUTE WORLD_READ
		OWNER_WRITE OWNER_READ OWNER_EXECUTE
		GROUP_EXECUTE GROUP_READ
)

# Install misc. files
INSTALL(
	FILES ChangeLog LICENSE
	DESTINATION ${target_installation_directory}
)

#!/bin/sh
# the next line restarts using wish \
exec tclsh "$0" "$@"

# Part of MCU 8051 IDE ( http://http://www.moravia-microsystems.com/mcu8051ide )

############################################################################
#    Copyright (C) 2007, 2008, 2009, 2010, 2011, 2012 by Martin Ošmera     #
#    martin.osmera@gmail.com                                               #
#                                                                          #
#    Copyright (C) 2014 by Moravia Microsystems, s.r.o.                    #
#    martin.osmera@moravia-microsystems.com                                #
#                                                                          #
#    This program is free software; you can redistribute it and#or modify  #
#    it under the terms of the GNU General Public License as published by  #
#    the Free Software Foundation; either version 2 of the License, or     #
#    (at your option) any later version.                                   #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program; if not, write to the                         #
#    Free Software Foundation, Inc.,                                       #
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################

# >>> File inclusion guard
if { ! [ info exists _MAIN_TCL ] } {
set _MAIN_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# Initilizator of the program
# --------------------------------------------------------------------------

# GENERAL CONSTANTS
# -----------------------------
set DEBUG		0				;# Turn on debugging
encoding system {utf-8}					;# System encoding
set LIB_DIRNAME	[file normalize [file dirname $argv0]]	;# Path to directory where the *.tcl file are located
set INSTALLATION_DIR [file normalize "$LIB_DIRNAME/.."]	;# Path to the main executable (this file)
set ROOT_DIRNAME [file normalize "$LIB_DIRNAME/.."]	;# On Linux it's the same as INSTALLATION_DIR but it's different on Windows
set VERSION		"1.4.9"				;# Version of this IDE
set SHORTNAME		"MCU8051IDE"			;# Program short name (without white space)
set APPNAME		"MCU 8051 IDE v$VERSION"	;# Full program name
set MIN_TCL_VER		"8.5"				;# Minimum required Tcl version
set APPLICATION_LOADED	0				;# True if program is loaded
set TRANSLATION_LOADED	0				;# Bool: Translation loaded
set MICROSOFT_WINDOWS	0				;# Bool: Windows OS running on the host computer
set CONFIG_DIR		{}				;# Directory containing configuration files

# Check for correct Tcl version
if {[package vcompare $::tcl_version $::MIN_TCL_VER] < 0} {
	puts stderr "ERROR: This program requires Tcl version $::MIN_TCL_VER or higher but you have Tcl $::tcl_version ."
	puts stderr "       Please install Tcl $::MIN_TCL_VER in order to run this program"

	exit 1
}

# Make sure that there is "ttk::spinbox" even when Tk version is lower than 8.5.9
namespace eval ttk {
	proc spinbox {args} {
		eval "set result \[::spinbox $args\]"
		return $result
	}
}

## Tcl packages used by this software
 # Format: {
 # 	{pkg_name	pkg_verison}
 # 	...
 # }
set LIBRARIES_TO_LOAD {
	{BWidget	1.8}
	{Itcl		3.4}
	{md5		2.0}
	{Tk		8.5}
	{img::png	1.3}
	{tdom		0.8}
	{Tclx		8.0}
	{Signal		1.4}
	{Tcl		8.2}
}

set OPTIONAL_LIBRARIES {
	Signal
	Tclx
}

## Bool:
 #     1 == Normal GUI operation
 #     0 == Program GUI suppressed
set ::GUI_AVAILABLE 1

## Bool:
 #     1 == library TclX is available
 #     0 == library TclX is NOT available
 #
 # TclX is used here only to handle signals (e.g. SIGINT), so the IDE can run
 # without it, that's the reason for this variable. If TCLX_AVAILABLE is 0 then
 # we are not able to handle signals, but everything else works normally.
set ::TCLX_AVAILABLE 1

## Bool:
 #     1 == library Signal is available
 #     0 == library Signal is NOT available
set ::SIGNAL_AVAILABLE 1

## Determinate the host OS
set ::MICROSOFT_WINDOWS 0
if {[string first {Windows} ${tcl_platform(os)}] != -1} {
	# Note:
	#   Microsoft Windows is NOT a POSIX system, and because of that, we need
	#   to do some workarounds here in order to make the IDE functional.
	set ::MICROSOFT_WINDOWS 1

	set LIB_DIRNAME_SPECIFIC_FOR_MS_WINDOWS "<AIPCS:LIB_DIRNAME_SPECIFIC_FOR_MS_WINDOWS>" ;# <-- The auto. inst. pkg. creation script will fill this in
	set AUTO_PATH_FOR_MS_WINDOWS "<AIPCS:AUTO_PATH_FOR_MS_WINDOWS>" ;# <-- The auto. inst. pkg. creation script will fill this in
	set INSTALLATION_DIR $LIB_DIRNAME
	set LIB_DIRNAME $LIB_DIRNAME_SPECIFIC_FOR_MS_WINDOWS
	set ROOT_DIRNAME [regsub {\/\w+\/?$} $LIB_DIRNAME {}]

	foreach dir $AUTO_PATH_FOR_MS_WINDOWS {
		lappend ::auto_path "${::ROOT_DIRNAME}/${dir}"
	}
	set env(ITCL_LIBRARY) "${::ROOT_DIRNAME}/libraries/itcl"
}

# Set directory containing configuration files according to the host OS
if {!$::MICROSOFT_WINDOWS} {
	set CONFIG_DIR [file join ${::env(HOME)} .[string tolower ${::SHORTNAME}]]
} else {
	set CONFIG_DIR [file join ${::env(USERPROFILE)} ".[string tolower ${::SHORTNAME}]"]
}

# Handle CLI options
# -----------------------------
proc mc args {return [eval "format $args"]}
source "${::LIB_DIRNAME}/cli.tcl"

# SHOW WARNING MESSAGE
# -----------------------------

if {!$::CLI_OPTION(quiet)} {
	if {$::CLI_OPTION(nocolor)} {
		puts "IMPORTANT INFORMATION:"
		puts "\tThis program is distributed in the hope that it will be useful, but with ABSOLUTELY NO WARRANTY !"
		puts "\tThis is free software, so you are free to change and redistribute it."
		puts "\tLicense: GNU General Public License version 2 or later"
		puts "\tPlease report bugs at http://mcu8051ide.sf.net"
		puts "Authors:"
		puts "\tMartin Osmera <martin.osmera@moravia-microsystems.com>"
	} else {
		puts "IMPORTANT INFORMATION :"
		puts "\tThis program is distributed in the hope that it will be useful, but with \033\[31;1mABSOLUTELY NO WARRANTY !\033\[m"
		puts "\tThis is free software, so you are free to change and redistribute it."
		puts "\tLicense: GNU General Public License version 2 or later"
		puts "\tPlease report bugs at \033\[34;1mhttp://mcu8051ide.sf.net\033\[m"
		puts "Authors:"
		puts "\tMartin Osmera \033\[33;1m<martin.osmera@moravia-microsystems.com>\033\[m"
	}
}

## This function should be called when some Tcl library fail to load
 # @parm String library - Name of failed library
 # @return void
proc libraryLoadFailed {library} {

	# Itcl workarond for Debian
	if {$library == {Itcl}} {
		if {[package vcompare $::tcl_version "8.6"] >= 0} {
			if {![catch {package require Itcl}]} {
				return
			}
		}

		set library_version "3.4"
		set libname "libitcl"

		set ::env(ITCL_LIBRARY) ${::LIB_DIRNAME}

		puts stderr "\nERROR: Unable to load Itcl library compatible with this version of Tcl/Tk!"
		puts stderr "Trying to workaround ..."

		if {[lsearch {Linux} ${::tcl_platform(os)}] == -1} {
			puts stderr "FATAL ERROR: Unsupported operating system. ${::tcl_platform(os)}"
			puts stderr "You can contact authors of the project at <martin.osmera@gmail.com> if you want to get you OS supported."
			exit 1
		}

		if {[lsearch {x86_64 i386 i486 i586 i686 x86} ${::tcl_platform(machine)}] == -1} {
			puts stderr "FATAL ERROR: Unsupported system architecture. ${::tcl_platform(machine)}"
			puts stderr "You can contact authors of the project at <martin.osmera@gmail.com> if you want to get you OS supported."
			exit 1
		}

		puts stderr "Loading library $library for ${::tcl_platform(os)} on ${::tcl_platform(machine)} ... (filename: ${libname}${library_version}.so.${::tcl_platform(os)}.${::tcl_platform(machine)})"
		if {[catch {load "${::LIB_DIRNAME}/${libname}${library_version}.so.${::tcl_platform(os)}.${::tcl_platform(machine)}" Itcl} error_info]} {
			puts stderr "FAILED !"
			puts stderr "Reason: ${error_info}"
			puts "\nPlease try to run mcu8051ide with --check-libraries to see what's wrong."

			exit 1
		} else {
			puts stderr "WORKAROUND SUCCESSFUL ... \n(But don't be much happy about this, it is still serious failure. And please don't forget to comply to developers of your Linux distribution. Missing library is: ${library} version ${library_version})"
			return
		}

	# Tclx workarond for Debian (1/2)
	} elseif {$library == {Tclx}} {
		set ::TCLX_AVAILABLE 0
		puts stderr "\nERROR: Unable to load library Tclx, MCU 805 1IDE functionality might be limited."
		return

	# Tclx workarond for Debian (2/2)
	} elseif { $library == {Signal} } {
		set ::SIGNAL_AVAILABLE 0
		if {!$::TCLX_AVAILABLE} {
			puts stderr "\nERROR: Unable to load library Signal, MCU 805 1IDE functionality might be limited."
		}
		return
	}

	# Print error message
	if {$::CLI_OPTION(nocolor)} {
		puts stderr "\n\nERROR: Unable to load library $library"
	} else {
		puts stderr "\n\n\033\[31mERROR:\033\[m Unable to load library \033\[32m$library\033\[m"
	}

	# Print tip
	puts "\nTip: try to run mcu8051ide with --check-libraries to see what's wrong."

	# Terminate the program
	exit 1
}

# PRE-INITIALIZATION
# -----------------------------
# Load Tk ToolKit
set T [lindex [time {
	if {[catch {package require img::png 1.3} e]} {
		libraryLoadFailed "img::png"
	}
	if {[catch {package require Tk $::MIN_TCL_VER} errinfo]} {
		puts stderr "Unable to initialize Tk\n$errinfo"
	}
}] 0]
# Hide main window
wm withdraw .
update

# Determinate default Fixed font
set ::DEFAULT_FIXED_FONT {Courier}
if {!$::MICROSOFT_WINDOWS} {
	if {[lsearch -ascii -exact [font families] {DejaVu Sans Mono}] != -1} {
		set ::DEFAULT_FIXED_FONT {DejaVu Sans Mono}
	}
}

# Set default background color
set ::COMMON_BG_COLOR [. cget -bg]

# ------------------------------------------------------------------------------
# Microsoft Windows OS specific code
# ------------------------------------------------------------------------------
if {$::MICROSOFT_WINDOWS} {
	# Print windows related warning
	puts ""
	puts "        THE IDE WAS ORIGINALY WRITTEN FOR POSIX, SO IT IS POSSIBLE THAT SOME"
	puts "        FUNCTIONALITY WILL BE LIMITED ON MS WINDOWS DUE TO ABSENCE OF CERTAIN"
	puts "        POSIX FUNCTIONALITY!"
	puts ""
}
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Make key shortcuts independent on Caps Lock.
# ------------------------------------------------------------------------------
rename bind original_command_bind
proc mcu8051ide_bind args {
	set widget [lindex $args 0]
	set event_str [lindex $args 1]
	set command [lindex $args 2]

	if {[llength $args] > 3} {
		error "Too many arguments to bind command."
	} elseif {[llength $args] == 2} {
		return [original_command_bind $widget $event_str]
	}

	# MS Windows doesn't recognize ISO and XFree86 codes
	if {$::MICROSOFT_WINDOWS} {
		if {
			[string first {ISO} $event_str] != -1	||
			[string first {XF86} $event_str] != -1
		} then {
			return
		}
	}

	if {
		[string index $event_str end-2] == {-}
			&&
		[string is alpha [string index $event_str end-1]]
			&&
		[string index $event_str end] == {>}
	} then {
		set letter [string index $event_str end-1]
		set event_str [string range $event_str 1 end-2]
		if {[string is upper $letter]} {
			set event_str "Shift-${event_str}"
		}

		original_command_bind $widget "<${event_str}[string toupper $letter]>" $command
		original_command_bind $widget "<${event_str}[string tolower $letter]>" $command
	} else {
		original_command_bind $widget $event_str $command
	}
}
rename mcu8051ide_bind bind
# ------------------------------------------------------------------------------

# Load base config file
# -----------------------------

# Initialize variable containing the font size factor
set font_size_factor 1.0

# Load i18n library
# (It must be loaded here because ::msgcat::mclocale must be available when
# base config file is being loaded)
incr T [lindex [time {
	if {[catch {package require msgcat 1.3.4}]} {
		libraryLoadFailed "msgcat"
	} else {
		namespace import -force ::msgcat::mc
		namespace import -force ::msgcat::mcset
		namespace import -force ::msgcat::*
	}
}] 0]
# Check if the file exits
if {![file exists ${::CONFIG_DIR}]} {
	file mkdir ${::CONFIG_DIR}
	puts "\nCreating program configuration files in directory: \"[file normalize ${::CONFIG_DIR}]\""
	if {!$::MICROSOFT_WINDOWS} {
		puts "Welcome in this IDE, [file tail [file normalize ~]] !"
	} else {
		catch {	;# Make the configuration directory in Microsoft Windows hidden
			file attributes $::CONFIG_DIR -hidden 1
		}
		puts "Welcome in this IDE, ${::env(USERNAME)} !"
	}
}
## Open and read the file
if {[catch {
	set conf_file [open "${::CONFIG_DIR}/base.conf" r]
 # File doesn't exits -> create it with default configuration
}]} then {
	# Default settings
	set detected_lang [string tolower [lindex [split [::msgcat::mclocale] {_}] 0]]
	if {{} != [lindex [split [::msgcat::mclocale] {_}] 1]} {
		append detected_lang {_} [string toupper [lindex [split [::msgcat::mclocale] {_}] 1]]
	}
	array set GLOBAL_CONFIG [list			\
		splash		1			\
		tips		1			\
		language	$detected_lang		\
		background	{Default}		\
		wstyle		{clam}			\
	]

	# Create the file
	if {[catch {
		set conf_file [open "${::CONFIG_DIR}/base.conf" w]
		puts -nonewline $conf_file [list	\
			$GLOBAL_CONFIG(splash)		\
			$GLOBAL_CONFIG(tips)		\
			$GLOBAL_CONFIG(language)	\
			${::font_size_factor}		\
			$GLOBAL_CONFIG(background)	\
			$GLOBAL_CONFIG(wstyle)		\
		]
		close $conf_file
	}]} then {
		puts stderr "Unable to create base configuration file"
	}
 # File exits -> read configuration from it
} else {
	# Read file contents
	set data [read $conf_file]
	close $conf_file

	# Set configuration according to the file contents
	set GLOBAL_CONFIG(splash)	[lindex $data 0]
	set GLOBAL_CONFIG(tips)		[lindex $data 1]
	set GLOBAL_CONFIG(language)	[lindex $data 2]
	set ::font_size_factor		[lindex $data 3]
	set GLOBAL_CONFIG(background)	[lindex $data 4]
	set GLOBAL_CONFIG(wstyle)	[lindex $data 5]

	## Validate read values
	if {![regexp {^1\.\d+$} $::font_size_factor] || $::font_size_factor < 1.0 || $::font_size_factor >= 2.0} {
		set ::font_size_factor 1.0
	}
	if {![string is boolean -strict ${::GLOBAL_CONFIG(splash)}]} {
		set GLOBAL_CONFIG(splash) 1
	}
	if {![string is boolean -strict ${::GLOBAL_CONFIG(tips)}]} {
		set GLOBAL_CONFIG(tips) 1
	}
	# This feature is not supported on MS Windows due to BWidget
	if {!$::MICROSOFT_WINDOWS} {
		switch -- ${::GLOBAL_CONFIG(background)} {
			{Default}	{set ::COMMON_BG_COLOR {#eeeeee}}
			{Windows}	{set ::COMMON_BG_COLOR {#ece9d9}}
			{Tk}		{}
			{Light}		{set ::COMMON_BG_COLOR {#f8f8f8}}
			{Dark}		{set ::COMMON_BG_COLOR {#cccccc}}
			default		{
				set ::GLOBAL_CONFIG(background) {Default}
				set ::COMMON_BG_COLOR {#eeeeee}
			}
		}
	}
	if {[lsearch -ascii -exact [ttk::style theme names] ${::GLOBAL_CONFIG(wstyle)}] == -1} {
		set ::GLOBAL_CONFIG(wstyle) {clam}
	}
	 # Check if the cpecified translation is valid
	set tmp [list]
	catch {	;# For Microsoft Windows it has to be enclosed by catch
		set tmp [glob -nocomplain -types f -tails			\
			-directory "${::INSTALLATION_DIR}/translations" *.msg	\
		]
	}
	set translations {en}
	foreach translation $tmp {
		lappend translations [file rootname $translation]
	}

	if {[lsearch $translations ${GLOBAL_CONFIG(language)}] == -1} {
		set GLOBAL_CONFIG(language) {en}
	}
}


# Load translation
# -----------------------------

# Load list of language names
set ::LANGUAGE_CODES [list]
namespace eval ::configDialogues::global {
	if {[catch {
		set file [open "${::INSTALLATION_DIR}/translations/languages.txt" r]
		set languages [read $file]
		close $file

		regsub -all -line {\s*#.*$} $languages {} languages
		set ::LANGUAGE_CODES $languages
		lindex $languages 0
	} e]} {
		puts stderr "Error while loading list of laguages: $e"
	}
}

# Load language specific translation file
if {!${::CLI_OPTION(notranslation)} && ${GLOBAL_CONFIG(language)} != {en}} {
	if {[catch {
		::msgcat::mclocale ${GLOBAL_CONFIG(language)}
		incr T [lindex [time {
			source "${::INSTALLATION_DIR}/translations/${GLOBAL_CONFIG(language)}.msg"
		}] 0]

	} result]} then {
		puts stderr "Unable to load translation"
		puts stderr "\tFile: '${::INSTALLATION_DIR}/translations/${GLOBAL_CONFIG(language)}.msg'"

	} else {
		set ::TRANSLATION_LOADED 1
	}
}

# CREATE SPLASH SCREEN
# -----------------------------
if {!$::CLI_OPTION(nosplash) && ${::GLOBAL_CONFIG(splash)}} {

	# Workaround for multiple monitors
	toplevel .splash_aux
	wm attributes .splash_aux -fullscreen 1
	update
	set sw [winfo width .splash_aux]
	set sh [winfo height .splash_aux]
	destroy .splash_aux
	update

	# Crete toplevel  window
	toplevel .splash -class {Splash creen} -bg ${::COMMON_BG_COLOR}

	# Show image of splash creen
	place [label .splash.bg	\
		-bg {#FFFFFF}	\
		-image [	\
			image create photo -format png	\
				-file "${::ROOT_DIRNAME}/icons/other/splash.png"	\
			]	\
	] -x 0 -y 0 -width 400 -height 199

	# Show status bar
	place [label .splash.status		\
		-bg {#FFFFFF} -fg {#0000FF}	\
		-text [mc "Initializing %s" $APPNAME]	\
	] -x 200 -y 180 -anchor center

	# Set window parameters
	wm geometry .splash "=400x199+[expr {$sw / 2 - 200}]+[expr {$sh / 2 - 100}]"
	wm overrideredirect .splash 1
	wm attributes .splash -alpha 0.8

	# Click on splash creen destroys it
	bind .splash <1> {wm withdraw .splash}

	# Done ..
	update
}


# BASIC FUNCTIONS
# -----------------------------

## Print content of $T in mili seconds ($T must contain value in [us])
 # @return void
proc time_in_msec {} {
	global T	;# Time in microseconds

	# Determinate number of miliseconds
	set msec [lindex $T 0]
	set msec [expr {$msec / 1000}]

	# print the message
	if {!$::CLI_OPTION(quiet)} {
		if {$::CLI_OPTION(nocolor)} {
			puts "... $msec ms"
		} else {
			puts "... \033\[33m$msec ms\033\[m"
		}
	}
}

## Print some initialization message (splash screen and CLI)
 # @parm String message - text of the message
 # @return void
proc showInitMessage {message} {

	# Change content of splash screen status bar
	if {!${::CLI_OPTION(nosplash)} && ${::GLOBAL_CONFIG(splash)}} {
		if {[winfo exists .splash.status]} {
			.splash.status configure -text [string trim $message]
			update
		}
	}

	# Print message to console output
	if {!${::CLI_OPTION(quiet)}} {
		if {${::CLI_OPTION(nocolor)}} {
			puts -nonewline $message
		} else {
			puts -nonewline "\033\[37m$message\033\[m"
		}

		puts -nonewline [string repeat { } [expr {38 - [string length $message]}]]
		flush stdout
	}
}

## Set status bar tip for some widget
 # Usage:
 #	setStatusTip -widget $some_widget -text "some text"
 #
 # @return void
proc setStatusTip args {

	# Local variables
	set widgetIsSet	0		;# True if widget is set
	set textIsSet	0		;# True if text is set
	set argsLength	[llength $args]	;# Number of arguments
	set widget	{}		;# ID of widget specified by argument '-widget'
	set helpText	{}		;# Help text specified by argument '-text'

	# Iterate over given arguments and evaluate them
	for {set i 0} {$i < $argsLength} {incr i} {
		# Currently parsed argument
		set arg [lindex $args $i]
		# Decide what $arg means
		switch -- $arg {
			-widget {	;# ID of the widget

				# check if that widget wasn't already specified
				if {$widgetIsSet} {
					error "Widget has been already specified"
				}

				# Check if widget's ID follow the arument
				incr i
				if {$i >= $argsLength} {
					error "Expected widget name after -widget option"
				}

				# Set ID of the widget
				set widget [lindex $args $i]
				if {![winfo exists $widget]} {
					error "The specified widget does not exist"
				}

				# Widget is now set
				set widgetIsSet 1
			}

			-text {		;# The help text

				# Check if help text follow the argument
				incr i
				if {$i >= $argsLength} {
					error "Expected text after -text option"
				}

				# Set the help text
				set helpText [lindex $args $i]

				# Help text is now set
				set textIsSet 1
			}

			default {	;# Unrecognized opton -> invoke ERROR
				error "Invalid argument '$arg', possible options are -widget and -text"
			}
		}
	}

	# Ckeck if both aruments are properly specified
	if {!$widgetIsSet || !$textIsSet} {
		error "You must specify text and widget"
	}

	# Create binding
	bind $widget <Enter> "Sbar -freeze {$helpText}"
	bind $widget <Leave> "Sbar {}"
}



# INITIALIZATION
# -----------------------------

# Show "first line message"
if {!$CLI_OPTION(quiet)} {
	if {$CLI_OPTION(nocolor)} {
		puts [mc "\nInitializing MCU 8051 IDE %s" $VERSION]
	} else {
		puts [mc "\nInitializing \033\[1mMCU 8051 IDE \033\[32m%s\033\[m" $VERSION]
	}
}

## Load libraries
showInitMessage [mc "\tLoading libraries"]
incr T [lindex [time {
	# Iterate over list of libraries and lod each of them
	foreach library $::LIBRARIES_TO_LOAD {
		# Loading successful
		if {[catch {package require [lindex $library 0] [lindex $library 1]}]} {
			libraryLoadFailed [lindex $library 0]
		# Loading failed
		} else {
			if {!$::CLI_OPTION(nosplash)} update
		}
	}

	if {$::MICROSOFT_WINDOWS} { ;# Load dde - Dynamic Data Exchange on Microsoft Windows
		package require dde
	}

	# Import NS for managing OOP in Tcl
	namespace import -force ::itcl::*
}] 0]

# Look for some external programs
foreach program {
		urxvt	vim	emacs	kwrite	gedit	nano	dav
		le	sdcc	indent	doxygen	asl	asem	doxywizard
		as31	sdcc-sdcc	gvim	hunspell	d52
		make
	} \
{
		if {[auto_execok $program] == {}} {
			set ::PROGRAM_AVAILABLE($program) 0
		} else {
			set ::PROGRAM_AVAILABLE($program) 1
		}
}
time_in_msec	;# Print time info

## Load program sources
showInitMessage [mc "\tLoading program sources"]
set T [time {
	source "${::LIB_DIRNAME}/lib/modern_notebook.tcl"	;# NoteBook widget with a modern look (modern in 2011)
	source "${::LIB_DIRNAME}/lib/FSnotifications.tcl"	;# Filesystem watcher
	source "${::LIB_DIRNAME}/lib/innerwindow.tcl"		;# Tool for creating inner windows
	source "${::LIB_DIRNAME}/dialogues/errorhandler.tcl"	;# Background error handler
	source "${::LIB_DIRNAME}/dialogues/my_tk_messageBox.tcl";# A replacement for tk_messageBox
	source "${::LIB_DIRNAME}/lib/settings.tcl"		;# Settings management
	source "${::LIB_DIRNAME}/project.tcl"			;# Project management
	source "${::LIB_DIRNAME}/dialogues/fsd.tcl"		;# File selection dialog
	source "${::LIB_DIRNAME}/X.tcl"				;# GUI <==> Implementation Interface
	source "${::LIB_DIRNAME}/configdialogues/configdialogues.tcl";# Configuration dialogues
	source "${::LIB_DIRNAME}/editor/editor.tcl"		;# Source code editor
	source "${::LIB_DIRNAME}/lib/Math.tcl"			;# Special mathematical operations
	source "${::LIB_DIRNAME}/compiler/compiler.tcl"		;# 8051 Assemly language compiler
	source "${::LIB_DIRNAME}/dialogues/tips.tcl"		;# Tips on start-up
	source "${::LIB_DIRNAME}/lib/hexeditor.tcl"		;# Hexadecimal editor
	source "${::LIB_DIRNAME}/utilities/hexeditdlg.tcl"	;# Hexadecimal editor dialog
	source "${::LIB_DIRNAME}/environment.tcl"		;# Main window "trappings" (menu and such)
	source "${::LIB_DIRNAME}/rightpanel/rightpanel.tcl"	;# Right panel
	source "${::LIB_DIRNAME}/leftpanel/filelist.tcl"	;# Left and middle panel
	source "${::LIB_DIRNAME}/simulator/simulator.tcl"	;# MCU Simulator
	source "${::LIB_DIRNAME}/bottompanel/bottomnotebook.tcl";# Bottom panel
	source "${::LIB_DIRNAME}/maintab.tcl"			;# Central widget
	source "${::LIB_DIRNAME}/lib/ihextools.tcl"		;# Tools for manipulating Intel 8 HEX
	source "${::LIB_DIRNAME}/utilities/symbol_viewer.tcl"	;# Assembly symbols viewer
	source "${::LIB_DIRNAME}/utilities/eightsegment.tcl"	;# 8-Segment LED display editor
	source "${::LIB_DIRNAME}/utilities/asciichart.tcl"	;# ASCII chart
	source "${::LIB_DIRNAME}/utilities/table_of_instructions.tcl";# 8051 Instruction Table
	source "${::LIB_DIRNAME}/utilities/notes.tcl"		;# Scribble notepad
	source "${::LIB_DIRNAME}/utilities/baseconverter.tcl"	;# Base converter
	source "${::LIB_DIRNAME}/utilities/speccalc.tcl"	;# Special calculator for x51 MCU's
	source "${::LIB_DIRNAME}/utilities/rs232debugger.tcl"	;# UART/RS232 applications debugger
}]
time_in_msec	;# Print time info

# CHECK FOR VALIDITY OF THE MCU DATABASE
if {${::X::available_processors} == {}} {
	destroy .splash
	bell
	tk_messageBox		\
		-icon error	\
		-type ok	\
		-title [mc "FATAL ERROR"]	\
		-message [mc "MCUs database file is corrupted,\nthis program cannot run without it.\nPlease reinstall MCU 8051 IDE."]
	exit 1
}

# Load global configuration
loadApplicationConfiguration

# Start spell checker process and wait until it is started
::Editor::restart_spellchecker_process
::Editor::adjust_spell_checker_config_button

# Initialize GUI environment
mainmenu_redraw		;# Main menu
iconbar_redraw		;# Main toolbar
shortcuts_reevaluate	;# Key shortcuts

## Remove splash screen
if {[winfo exists .splash]} {
	destroy .splash
}
if {$CLI_OPTION(minimalized)} {
	wm state . iconic
} else {
	wm deiconify .
}

# Configure signal handling
if {$::TCLX_AVAILABLE || $::SIGNAL_AVAILABLE} {
	proc signal_handler {signal_name} {
		global cntrlc_flag
		puts stderr [mc "\nExiting on signal %s" $signal_name]
		catch {
			::X::__exit 1 1
		}
		puts stderr [mc "\nERROR: Unable to exit the program correctly -- TERMINATING NOW!" $signal_name]
		exit 1
	}

	if {$::TCLX_AVAILABLE} {
		signal trap SIGINT	{signal_handler SIGINT}
		signal trap SIGTERM	{signal_handler SIGTERM}
	} else {
		signal add SIGINT	{signal_handler SIGINT}
		signal add SIGTERM	{signal_handler SIGTERM}
	}
}


# ---------------------------------------------------------
# Ugly job ... dirty workarounds and such things ... :(
# ---------------------------------------------------------

catch {
	NoteBook .foo
	proc NoteBook::_getoption {path page option} {
		if {$option == {-background}} {
			return ${::COMMON_BG_COLOR}
		}

		catch {
			set value [Widget::cget $path.f$page $option]
			if {![string length $value]} {
				set value [Widget::cget $path $option]
			}

			return $value
		}
	}
	destroy .foo
}

# ---------------------------------------------------------

## Open the last session
# Print message
showInitMessage [mc "\tOpening last session"]
flush stdout
# Evaluate new geometry of the main window
update
evaluate_new_window_geometry
if {![winfo viewable .mainMenu]} {
	wm geometry . $::CONFIG(WINDOW_GEOMETRY)
	update
}
# Open projects of last session
set T [time {
	foreach project_file $::CONFIG(OPENED_PROJECTS) {
		if {![Project::open_project_file $project_file]} {
			tk_messageBox			\
				-title [mc "File not found"]	\
				-icon warning		\
				-type ok		\
				-message [mc "Unable to open project file:\n\"%s\"" $project_file]
		}
	}
}]

# Reopen base converters
foreach cfg $::CONFIG(BASE_CONVERTERS) {
	if {[catch {
		set obj [::X::__base_converter]
		::X::$obj set_config $cfg
	}]} then {
		puts stderr {}
		puts stderr $::errorInfo
	}
}

time_in_msec	;# Print time info

# Without this "help windows" won't work properly on MS Windows
if {$::MICROSOFT_WINDOWS} {
	if {[wm state .] == {zoomed}} {
		set ::LATS_KNOWN_WM_STATE_IS_ZOOMED 1
	} else {
		set ::LATS_KNOWN_WM_STATE_IS_ZOOMED 0
	}
}
# Create binding for panes management
bind . <Configure> {
	X::redraw_panes

	# Without this "help windows" won't work properly on MS Windows
	if {$::MICROSOFT_WINDOWS} {
		if {[wm state .] == {zoomed}} {
			set now_zoomed 1
		} else {
			set now_zoomed 0
		}

		if {!${::LATS_KNOWN_WM_STATE_IS_ZOOMED} && $now_zoomed} {
			after idle {
				update
				regsub {[\+\-].*$} [wm geometry .] {+0+0} geometry
				wm geometry . $geometry
			}
		}
		set ::LATS_KNOWN_WM_STATE_IS_ZOOMED $now_zoomed
	}
}
# Print final message
if {!$CLI_OPTION(quiet)} {
	puts [mc "%s is now operational\n" $APPNAME]
}

# Program is now operational
set ::Compiler::in_IDE 1
set APPLICATION_LOADED 1
set X::critical_procedure_in_progress 0
update
X::redraw_panes
update
foreach project ${::X::openedProjects} {
	$project bottomNB_redraw_pane
	$project filelist_adjust_size_of_tabbar
	$project ensure_that_both_editors_are_properly_initialized
}
# Focus on the active editor
if {${::X::actualProject} != {}} {
	update
	focus [${::X::actualProject} editor_procedure {} cget -editor]
	focus [${::X::actualProject} editor_procedure {} Configure {}]
	focus [${::X::actualProject} editor_procedure {} highlight_visible_area {}]
}

# Correct strange behavior concerning restoration of the last window size and position
if {$::MICROSOFT_WINDOWS} {
	update
	wm geometry . $::CONFIG(WINDOW_GEOMETRY)
}

# Initialize file change notifications mechanism
FSnotifications::init

# >>> File inclusion guard
}
# <<< File inclusion guard

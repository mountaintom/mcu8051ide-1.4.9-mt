#!/bin/sh
# the next line restarts using wish \
exec tclsh "$0" "$@"

# Part of MCU 8051 IDE ( http://http://www.moravia-microsystems.com/mcu8051ide )

############################################################################
#    Copyright (C) 2011 by Martin Ošmera                                   #
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
if { ! [ info exists _RECEIVE_AND_PRINT_TCL ] } {
set _RECEIVE_AND_PRINT_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Send input read the send command to stdout
#
# USAGE:
# set pid [exec -- tclsh receive_and_print.tcl [tk appname] final_cmd | some_command ?args? &]
#	* pid		- Process identifier of $some_command
#	* args		- Arguments for $some_command
#	* final_cmd	- Command in local Tcl program to execute once when the script exits
#
# Once the receive_and_print (RAP) is started you can invoke ``print_line'' command available in it
# to print any string to stdout. The command takes any number of arguments and prints them all into
# the standard output.
# --------------------------------------------------------------------------

# Initialize
encoding system {utf-8}
package require Tk
wm withdraw .
wm command . "$argv0 $argv"
wm client . [info hostname]

# Parse agruments
set source_app	[lindex $argv 0]
set final_cmd	[lindex $argv 1]
unset argv

## Determinate the host OS
set ::MICROSOFT_WINDOWS 0
if {[string first {Windows} ${tcl_platform(os)}] != -1} {
	# Note:
	#   Microsoft Windows is NOT a POSIX system and because of that we need
	#   to do some workarounds here in order to make the IDE functional there.
	set ::MICROSOFT_WINDOWS 1
}

# Load dde - Dynamic Data Exchange on Microsoft Windows
if {$::MICROSOFT_WINDOWS} {
	package require dde
}

## Perform secure send command
 # Secure means that it will not crash or something like that in case of any errors.
 # But instead it will pop-up an error message to the user (Tk dialog).
 # @parm List args - Arguments for the send command
 # @return void
proc secure_send args {
	if {[catch {
		eval "send $args"
	} result]} then {
		puts stderr "Unknown IO Error :: $result"
		return 1

	} else {
		return 1
	}
}

proc print_line {args} {
	puts $args
}

if {!${::MICROSOFT_WINDOWS}} {
	secure_send $source_app $final_cmd "{[tk appname]}"
} else {
	dde eval $source_app $final_cmd "{[tk appname]}"
}

# >>> File inclusion guard
}
# <<< File inclusion guard

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
if { ! [ info exists _EXTERNAL_COMMAND_TCL ] } {
set _EXTERNAL_COMMAND_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Send input read from strandard input to certain Tk application via
# send command
#
# USAGE:
# set pid [exec -- some_command ?args? |& tclsh external_command.tcl [tk appname] final_cmd line_cmd &]
#	* pid		- Process indentifier of $some_command
#	* some_command	- Command which output should be couth
#	* args		- Arguments for $some_command
#	* final_cmd	- Command in local Tcl program to execute once when $some_command finish
#	* line_cmd	- Command in local Tcl program to execute everytime when $some_command outputs one line
# --------------------------------------------------------------------------

# Initialize
encoding system {utf-8}
package require Tk
wm withdraw .
wm command . "$argv0 $argv"
wm client . [info hostname]

# Parse agruments
set target_app	[lindex $argv 0]
set final_cmd	[lindex $argv 1]
set line_cmd	[lindex $argv 2]
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
 # But instead it will popup an error message to the user (Tk dialog).
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

## Read standard input
 # All output will be sended at once
if {$line_cmd == {}} {
	set result {}
	while {![eof stdin]} {
		append result [gets stdin] "\n"
	}

	if {!${::MICROSOFT_WINDOWS}} {
		secure_send $target_app $final_cmd "{" [regsub -all {[\{\}]} $result {\\&}] "}"
	} else {
		dde eval $target_app $final_cmd "{ [regsub -all {[\{\}]} $result {\\&}] }"
	}

 # Output will be sended line by line as executed command generates it
} else {
	while {![eof stdin]} {
		if {!${::MICROSOFT_WINDOWS}} {
			secure_send $target_app $line_cmd "{" [regsub -all {[\{\}]} [gets stdin] {\\&}] "}"
		} else {
			dde eval $target_app $line_cmd "{ [regsub -all {[\{\}]} [gets stdin] {\\&}] }"
		}
	}

	if {!${::MICROSOFT_WINDOWS}} {
		secure_send $target_app $final_cmd
	} else {
		dde eval $target_app $final_cmd
	}
}

exit 0

# >>> File inclusion guard
}
# <<< File inclusion guard

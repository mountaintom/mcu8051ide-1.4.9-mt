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

# --------------------------------------------------------------------------
# DESCRIPTION
# Execute custom command
# USAGE:
# set pid [exec -- tclsh custom_command.tcl [tk appname] $custom_command_NUM($cmd_num) &]
# --------------------------------------------------------------------------

# Initialize
encoding system {utf-8}
package require Tk
wm withdraw .
wm command . "$argv0 $argv"
wm client . [info hostname]

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

# Load command from standard input
set cmd {}
while {![eof stdin]} {
	append cmd [gets stdin] "\n"
}

# Execute loaded command
if {[catch {exec bash << $cmd} result] && ![string equal $::errorCode NONE]} {
	secure_send [lindex $argv 0] ::X::custom_cmd_error  [lindex $argv 1] "{" [regsub -all {[\{\}]} $result {\\&}] "}"
} else {
	secure_send [lindex $argv 0] ::X::custom_cmd_finish [lindex $argv 1] "{" [regsub -all {[\{\}]} $result {\\&}] "}"
}

exit 0

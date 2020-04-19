#!/usr/bin/tclsh
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
if { ! [ info exists _CONFIGDIALOGUES_TCL ] } {
set _CONFIGDIALOGUES_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements various configuration dialogues
#
# Currently implemented:
#	- Editor configuration
#	- Compiler configuration
#	- Right panel configuration
#	- Main toolbar configuration
#	- Custom commands configuration
#	- Shortcuts configuration
#	- Global configuration
#	- Simulator configuration
#	- Terminal configuration
# --------------------------------------------------------------------------

namespace eval configDialogues {
	# Load all available configuration dialogues into one common namespace
	source "${::LIB_DIRNAME}/configdialogues/editor_config.tcl"		;# Editor configuration dialog
	source "${::LIB_DIRNAME}/configdialogues/compiler_config.tcl"		;# Compiler configuration dialog
	source "${::LIB_DIRNAME}/configdialogues/rightpanel_config.tcl"		;# Right panel configuration dialog
	source "${::LIB_DIRNAME}/configdialogues/toolbar_config.tcl"		;# Main toolbar configuration dialog
	source "${::LIB_DIRNAME}/configdialogues/custom_commands_config.tcl"	;# Custom commands configuration dialog
	source "${::LIB_DIRNAME}/configdialogues/shortcuts_config.tcl"		;# Shortcuts configuration dialog
	source "${::LIB_DIRNAME}/configdialogues/global_config.tcl"		;# Global configuration dialog
	source "${::LIB_DIRNAME}/configdialogues/simulator_config.tcl"		;# Simulator configuration dialog
	source "${::LIB_DIRNAME}/configdialogues/terminal_config.tcl"		;# Terminal configuration dialog
}

# >>> File inclusion guard
}
# <<< File inclusion guard

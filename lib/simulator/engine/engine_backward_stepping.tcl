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
if { ! [ info exists _ENGINE_BACKWARD_STEPPING_TCL ] } {
set _ENGINE_BACKWARD_STEPPING_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Part of simulator engine functionality.
#
# --------------------------------------------------------------------------
# BACKWARD STEPPING RELATED PROCEDURES
# --------------------------------------------------------------------------

## Save current value of the given register for purpose of stepback operation
 # This function does not check for address validity !
 # @parm Char mem	- Memory type (one of {I E X S P})
 # @parm Int addr	- Register address
 # @return void
private method stepback_reg_change {mem addr} {
	if {!$stepback_ena} {return}
	if {[lsearch $stepback_local_regs $addr] != -1} {
		return
	}
	lappend stepback_local_regs $addr

	switch -- $mem {
		{I} {set val $ram($addr)	}
		{E} {set val $eram($addr)	}
		{X} {set val $xram($addr)	}
		{S} {set val $sfr($addr)	}
		{P} {set val $eeprom($addr)	}
	}
	lappend stepback_local [list $mem $addr $val]
}

## Save local stepback stack to global stepback stack
 # This function should be called after each instrucion
 # @return void
private method stepback_save_norm {} {
	if {!$stepback_ena} {return}
	lappend stepback_normal $stepback_local
	set stepback_local_regs {}
	set stepback_local {}
}

## Save special engine configuration variables for purpose of stepback operation
 # This function should be called before each instrucion
 # @return void
private method stepback_save_spec {} {
	if {!$stepback_ena} {return}
	incr stepback_length
	set discard [expr {$stepback_length - ${::Simulator::reverse_run_steps}}]
	if {$discard > 0} {
		incr stepback_length -$discard
		set stepback_spec	[lreplace $stepback_spec 0 0]
		set stepback_normal	[lreplace $stepback_normal 0 0]
	}

	lappend stepback_spec [simulator_get_special]
}

## Set the last list element in stepback to current time
 # @return void
private method stepback_save_spec_time {} {
	lset stepback_spec {end end} $time
}

## Set "subprog" value for stepback function.
 # This is important for list of subprograms and stack monitor
 # @parm Int action -
 #	6 - Instruction POP peformed
 #	5 - Instruction PUSH performed
 #	4 - Return from subprogram
 #	3 - Return from interrupt routine
 #	2 - Invocaton of subprogram
 #	1 - Invocaton of interrupt
 #	0 - Nothing mentioned above
 # @return void
private method stepback_save_spec_subprog {action} {
	lset stepback_spec {end 0} $action
}

## Discard stack for stepback functions
 # @return void
public method stepback_discard_stack {} {
	set stepback_local_regs	{}
	set stepback_normal	{}
	set stepback_spec	{}
	set stepback_local	{}
	set stepback_length	0
}

## Get stepback stack length
 # @return Int - stack length
public method simulator_get_SBS_len {} {
	if {${::Simulator::reverse_run_steps}} {
		return $stepback_length
	} else {
		return 0
	}
}

## Set stepback stack length
 # @parm Int value - stack length
 # @return void
public method simulator_set_SBS_len {value} {
	set stepback_length $value
}

# >>> File inclusion guard
}
# <<< File inclusion guard

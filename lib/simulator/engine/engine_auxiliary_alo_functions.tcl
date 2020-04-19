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
if { ! [ info exists _ENGINE_AUXILIARY_ALO_FUNCTIONS_TCL ] } {
set _ENGINE_AUXILIARY_ALO_FUNCTIONS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Part of simulator engine functionality.
#
# --------------------------------------------------------------------------
# AUXILIARY ALO FUNCTIONS
# --------------------------------------------------------------------------

## Generate random octet
 # @return Int - random value in range 0..255
private method undefined_octet {} {
	switch -- ${::Simulator::undefined_value} {
		0 {	;# Return 0
			return 0
		}
		1 {	;# Return 255
			return 255
		}
		2 {	;# Return random value
			set result [expr {int(rand() * 256)}]
			if {$result == 256} {set result 255}
		}
	}
	return $result
}

## Add value to accumulator and affect PSW flags
 # @parm Int val   - value to add
 # @parm Int carry - addtional value to add (ment for the Carry flag)
 # @return void
private method alo_add {val {carry 0}} {

	# Adjust stepback stack
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}

	# Local variables
	set A_h [expr {($sfr(224) & 240) >> 4}]	;# High-order nibble of Acc
	set A_l [expr {$sfr(224) & 15}]		;# Low-order  nibble of Acc
	set val_h [expr {($val & 0x1f0) >> 4}]	;# High-order nibble of val
	set val_l [expr {$val & 15}]		;# Low-order  nibble of val

	# Compute low-order nibble of result
	set result [expr {$val_l + $A_l + $carry}]

	# Flag AC
	if {$result > 15} {
		incr val_h
		incr result -16
		setBit $symbol(AC) 1
	} else {
		setBit $symbol(AC) 0
	}

	# Compute high-order nibble of result
	incr result [expr {($val_h + $A_h) << 4}]

	# Flag C
	if {$result > 255} {
		incr result -256
		setBit $symbol(C) 1
	} else {
		setBit $symbol(C) 0
	}

	# Flag OV
	if {($val < 128) && ($sfr(224) < 128) && ($result > 127)} {
		setBit $symbol(OV) 1
	} elseif {($val > 127) && ($sfr(224) > 127) && ($result < 128)} {
		setBit $symbol(OV) 1
	} else {
		setBit $symbol(OV) 0
	}

	# Set Acc
	set sfr(224) $result
	evaluate_sfr 224
}

## Add value to accumulator with carry and affect PSW flags
 # @parm Int val - value to add
 # @return void
private method alo_addc {val} {
	alo_add $val [getBit $symbol(C)]
}

## Subtract tegister from ACC with borrow and affect PSW flags
 # @parm Int val - value to subtract
 # @return void
private method alo_subb {val} {

	# Adjust stepback stack
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 224
	}

	# Flag PSW.C
	set carry 0
	if {[getBit $symbol(C)]} {
		set carry 1
	}

	# Local variables
	set A_h [expr {($sfr(224) & 240) >> 4}]	;# High-order nibble of Acc
	set A_l [expr {$sfr(224) & 15}]		;# Low-order  nibble of Acc
	set val_h [expr {($val & 0x1f0) >> 4}]	;# High-order nibble of val
	set val_l [expr {$val & 15}]		;# Low-order  nibble of val

	# Compute low-order nibble of result
	set result_l [expr {$A_l - $val_l - $carry}]

	# Flag AC
	if {$result_l < 0} {
		incr result_l 16
		incr val_h
		setBit $symbol(AC) 1
	} else {
		setBit $symbol(AC) 0
	}

	# Compute high-order nibble of result
	set result_h [expr {$A_h - $val_h}]

	# Flag C
	if {$result_h < 0} {
		incr result_h 16
		setBit $symbol(C) 1
	} else {
		setBit $symbol(C) 0
	}

	# Compute high-order nibble of result
	set result [expr {($result_h << 4) + $result_l}]

	# Flag OV
	if {($val > 127) && ($sfr(224) < 128) && ($result > 127)} {
		setBit $symbol(OV) 1
	} elseif {($val < 128) && ($sfr(224) > 127) && ($result < 128)} {
		setBit $symbol(OV) 1
	} else {
		setBit $symbol(OV) 0
	}

	# Set Acc
	set sfr(224) $result
}

# >>> File inclusion guard
}
# <<< File inclusion guard

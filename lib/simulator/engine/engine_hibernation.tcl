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
if { ! [ info exists _ENGINE_HIBERNATION_TCL ] } {
set _ENGINE_HIBERNATION_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Part of simulator engine functionality.
#
# --------------------------------------------------------------------------
# HIBERNATION RELATED PROCEDURES
# --------------------------------------------------------------------------

## Get special engine configuration list (for stepback and hibernation)
 # @return List - Special configuration list
public method simulator_get_special {} {
	set result 0
	lappend result								\
		$ports_previous_state	$pc			$bank		\
		$interrupts_in_progress	$interrupt_on_next	$skip_interrupt	\
		$timer_0_running	$timer_1_running	$overall_time	\
		$overall_instructions	$inter_in_p_flags	$timer1_overflow

	if {$feature_available(t2)} {
		lappend result $timer_2_running $timer2_overflow
	}
	if {$feature_available(wtd)} {
		lappend result $watchdog_value $wdtrst_prev_val
	}
	if {$feature_available(wdtcon)} {
		lappend result $wdt_prescaler_val $controllers_conf(WatchDogPrescaler)
	}
	if {$feature_available(pwm)} {
		lappend result $pwm_running $pwm_OCR
	}
	if {$eeprom_size} {
		lappend result		\
			$eeprom_WR_time	\
			$eeprom_WR	\
			$eeprom_prev	\
			$eeprom_WR_ofs	\
			$controllers_conf(RDYBSY)	\
			$controllers_conf(WRTINH)

		for {set i 0} {$i < 32} {incr i} {
			lappend result $eeprom_WR_buff($i)
		}
	}
	if {$feature_available(hddptr)} {
		lappend result $hidden_DPTR0 $hidden_DPTR1
	}
	if {$feature_available(acomparator)} {
		lappend result $anlcmp_running $anlcmp_output $anlcpm_db_timer
	}
	if {$feature_available(uart)} {
		lappend result			\
			$uart_clock_prescaler	\
			$uart_RX_clock		\
			$uart_TX_clock		\
			$uart_RX_in_progress	\
			$uart_TX_in_progress	\
			$uart_RX_shift_reg	\
			$uart_TX_shift_reg
	}

	lappend result $time
	return $result
}

## Set special engine configuration list (for stepback and hibernation)
 # @parm List list - list to set
 # @return void
public method simulator_set_special {list} {
	set i 1
	foreach var {
		ports_previous_state	pc			bank
		interrupts_in_progress	interrupt_on_next	skip_interrupt
		timer_0_running		timer_1_running		overall_time
		overall_instructions	inter_in_p_flags	timer1_overflow
	} {
		set $var [lindex $list $i]
		incr i
	}

	if {$feature_available(t2)} {
		set timer_2_running	[lindex $list $i]
		incr i
		set timer2_overflow	[lindex $list $i]
		incr i
	}
	if {$feature_available(wtd)} {
		set watchdog_value	[lindex $list $i]
		incr i
		set wdtrst_prev_val	[lindex $list $i]
		incr i
	}
	if {$feature_available(wdtcon)} {
		set wdt_prescaler_val	[lindex $list $i]
		incr i
		set controllers_conf(WatchDogPrescaler)	[lindex $list $i]
		incr i
	}
	if {$feature_available(pwm)} {
		set pwm_running		[lindex $list $i]
		incr i
		set pwm_OCR		[lindex $list $i]
		incr i
	}
	if {$eeprom_size} {
		set eeprom_WR_time	[lindex $list $i]
		incr i
		set eeprom_WR		[lindex $list $i]
		incr i
		set eeprom_prev		[lindex $list $i]
		incr i
		set eeprom_WR_ofs	[lindex $list $i]
		incr i
		set controllers_conf(RDYBSY)	[lindex $list $i]	;# Read only bit
		incr i
		set controllers_conf(WRTINH)	[lindex $list $i]	;# Read only bit
		incr i

		for {set j 0} {$j < 32} {incr j; incr i} {
			set eeprom_WR_buff($j)	[lindex $list $i]
		}
	}
	if {$feature_available(hddptr)} {
		set hidden_DPTR0	[lindex $list $i]
		incr i
		set hidden_DPTR1	[lindex $list $i]
		incr i
	}
	if {$feature_available(acomparator)} {
		set anlcmp_running	[lindex $list $i]
		incr i
		set anlcmp_output	[lindex $list $i]
		incr i
		set anlcpm_db_timer	[lindex $list $i]
		incr i
	}
	if {$feature_available(uart)} {
		set uart_clock_prescaler [lindex $list $i]
		incr i
		set uart_RX_clock	[lindex $list $i]
		incr i
		set uart_TX_clock	[lindex $list $i]
		incr i
		set uart_RX_in_progress	[lindex $list $i]
		incr i
		set uart_TX_in_progress	[lindex $list $i]
		incr i
		set uart_RX_shift_reg	[lindex $list $i]
		incr i
		set uart_TX_shift_reg	[lindex $list $i]
		incr i
	}

	set time [lindex $list $i]
}

## Get special engine configuration list from stepback stack
 # @parm Int i - Depth
 # @return List - Config list
public method simulator_hib_get_SB_spec {i} {
	return [lindex $stepback_spec $i]
}

## Get stepback stack for ordinary registes
 # @parm Int i - Depth
 # @return List - Part of stepback stack
public method simulator_hib_get_SB_norm {i} {
	return [lindex $stepback_normal $i]
}

## Append special engine configuration list onto stepback stack
 # @parm List list - Config list
 # @return void
public method simulator_hib_append_SB_spec {list} {
	lappend stepback_spec $list
}

## Append special engine configuration list onto stepback stack
 # @parm List list - List of registers and their values
 # @return void
public method simulator_hib_append_SB_norm {list} {
	lappend stepback_normal $list
}

# >>> File inclusion guard
}
# <<< File inclusion guard

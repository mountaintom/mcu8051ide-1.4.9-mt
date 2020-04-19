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
if { ! [ info exists _ENGINE_CONTROL_TCL ] } {
set _ENGINE_CONTROL_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Part of simulator engine functionality.
#
# --------------------------------------------------------------------------
# CONTROL PROCEDURES
# --------------------------------------------------------------------------


## Force return from subprogram or interrupt handler
 # @parm Bool intr__sub - 1 == Interrupt; 0 == subprogram
 # @retunr void
public method simulator_return_from_SP {intr__sub} {
	if {$intr__sub} {
		simulator_cancel_interrupt [lindex $inter_in_p_flags end]
	} else {
		ins_ret
		$this move_simulator_line $Line($pc)
	}
}

## Resize external data memory
 # Warning: This functon is unsafe
 # @parm Int new_size - New memory size
 # @return void
public method simulator_resize_xdata_memory {new_size} {
	# Shrink memory
	if {$xram_size > $new_size} {
		if {!$new_size} {
			array unset xram
		}

	# Expand memory
	} elseif {$xram_size < $new_size} {
		for {set i $xram_size} {$i < $new_size} {incr i} {
			set xram($i) 0
		}
	}

	set xram_size $new_size
}

## Resize program memory
 # Warning: This functon is unsafe
 # @parm Int new_size - New memory size
 # @return void
public method simulator_resize_code_memory {new_size} {
	set new_size [expr {int($new_size)}]

	# Shrink memory
	if {$code_size > $new_size} {
		if {!$new_size} {
			array unset code
		}

	# Expand memory
	} elseif {$code_size < $new_size} {
		for {set i $code_size} {$i < $new_size} {incr i} {
			set code($i) 0
		}
	}

	set code_size $new_size
}

## Get list of decimal address of implemented SFR
 # @return List - Implemented special function registers
public method simulator_get_available_sfr {} {
	return $available_sfr
}

## Determinate whether the specified SFR is available on the target MCU or not
 # @parm Int sfr_addr - Address of SFR register
 # @return Bool - 1 == available; 0 == Not available
public method simulator_is_sfr_available {sfr_addr} {
	if {[lsearch -ascii -exact $available_sfr $sfr_addr] == -1} {
		return 0
	} else {
		return 1
	}
}

## Reset counter of overall program time
 # @return void
public method simulator_clear_overall_time {} {
	set overall_time 0
	set overall_instructions 0
}

## Reset vitrual processor
 # @parm String mode - Reset mode:
 #		'-' == no change	(IRAM, ERAM and XRAM)
 #		'0' == all zeroes	(IRAM, ERAM and XRAM)
 #		'1' == all ones		(IRAM, ERAM and XRAM)
 #		'r' == random values	(IRAM, ERAM and XRAM)
 # @return void
public method master_reset {mode} {
	set break	1	;# Terminate running program
	set pc		0	;# Reset program counter
	set bank	0	;# Reset active register bank

	# Reset controllers configurations
	set controllers_conf(WatchDogTimer)	0	;# Stop Watchdog Timer
	set controllers_conf(SM0)		0	;# UART mode bit 0
	set controllers_conf(FE)		0	;# UART frame error flag bit
	if {$eeprom_size} {
		simulator_cancel_write_to_eeprom
		catch {
			$this sim_GUI_bit_set_clear 1 EECON RDYBSY
		}
	}

	# Reset engine configurations
	set DPL			{DP0L}	;# Select DTPR0
	set DPH			{DP0H}	;# Select DTPR0
	set hidden_DPTR0	{0 0}	;# Value of DPTR0 (if dual DPTR is hidden)
	set hidden_DPTR1	{0 0}	;# Value of DPTR1 (if dual DPTR is hidden)
	set idle_mode		0	;# Normal mode (not IDLE)
	set timer_0_running	0	;# Bool: Timer/Counter 0 engaged
	set timer_1_running	0	;# Bool: Timer/Counter 1 engaged
	set timer_2_running	0	;# Bool: Timer/Counter 2 engaged
	set pwm_running		0	;# Bool: PWM controller engaged (uses Timer/Counter 0 & 1)
	set wdt_prescaler_val	0	;# Int: Value of Watchdog prescaler
	set watchdog_value	0	;# Int: Value of watchdog timer
	set eeprom_WR		0	;# Bool: Data EEPROM write cycle in progress
	if {$::GUI_AVAILABLE} {
		simulator_Sbar {} 0 $this		;# Clear simulator status bar
	}
	set interrupt_on_next		0	;# Bool: Engage interrupt routine on the next instruction cycle
	set interrupts_in_progress	{}	;# Priority flags of interrupts which are in progress
	set inter_in_p_flags		{}	;# Interrupt flags of interrupts which are in progress

	switch -- $mode {
		- {	;# no changes
		}
		0 {	;# all zeroes
			for {set i 0} {$i < $iram_size} {incr i} {
				set ram($i) 0
			}
			for {set i 0} {$i < $eram_size} {incr i} {
				set eram($i) 0
			}
			update
			for {set i 0} {$i < $xram_size} {incr i} {
				set xram($i) 0
			}
		}
		1 {	;# all ones
			for {set i 0} {$i < $iram_size} {incr i} {
				set ram($i) 255
			}
			for {set i 0} {$i < $eram_size} {incr i} {
				set eram($i) 255
			}
			update
			for {set i 0} {$i < $xram_size} {incr i} {
				set xram($i) 255
			}
		}
		r {	;# random values
			for {set i 0} {$i < $iram_size} {incr i} {
				set ram($i) [expr {int(rand() * 256)}]
			}
			for {set i 0} {$i < $eram_size} {incr i} {
				set eram($i) [expr {int(rand() * 256)}]
			}
			update
			for {set i 0} {$i < $xram_size} {incr i} {
				set xram($i) [expr {int(rand() * 256)}]
			}
		}
	}

	# Make backup copy of all SFR for purpose of stepback function
	foreach addr [array names sfr] {
		stepback_reg_change S $addr
	}

	# Set port states
	set ports_previous_state {255 255 255 255 255}

	# Set SFR to defaults
	foreach reg $reset_reg_values {
		set sfr($symbol([lindex $reg 0])) [lindex $reg 1]
	}
	foreach item $reset_reg_values_1 {
		set reg [lindex $item 0]
		switch -- $reg {
			{T2CON}		{if {!$feature_available(t2)}		{continue}}
			{RCAP2L}	{if {!$feature_available(t2)}		{continue}}
			{RCAP2H}	{if {!$feature_available(t2)}		{continue}}
			{TL2}		{if {!$feature_available(t2)}		{continue}}
			{TH2}		{if {!$feature_available(t2)}		{continue}}
			{T2MOD}		{if {!$feature_available(t2mod)}	{continue}}
			{AUXR}		{if {!$feature_available(auxr)}		{continue}}
			{SCON}		{if {!$feature_available(uart)}		{continue}}
			{P0}		{if {!$feature_available(p0)}		{continue}}
			{P1}		{if {!$feature_available(p1)}		{continue}}
			{P2}		{if {!$feature_available(p2)}		{continue}}
			{P3}		{if {!$feature_available(p3)}		{continue}}
			{P4}		{if {!$feature_available(p4)}		{continue}}
			{ACSR}		{if {!$feature_available(acomparator)}	{continue}}
			{SADEN}		{if {!$feature_available(euart)}	{continue}}
			{SADDR}		{if {!$feature_available(euart)}	{continue}}
			{IPH}		{if {!$feature_available(iph)}		{continue}}
			{WDTCON}	{if {!$feature_available(wdtcon)}	{continue}}
			{EECON}		{if {!$eeprom_size}			{continue}}
			{SPCR}		{if {!$feature_available(spi)}		{continue}}
			{SPSR}		{if {!$feature_available(spi)}		{continue}}
			{DP1H}		{
				if {!$feature_available(ddp) || $feature_available(hddptr)} {
					continue
				}
			}
			{DP1L}		{
				if {!$feature_available(ddp) || $feature_available(hddptr)} {
					continue
				}
			}
			{CLKREG}	{
				if {!$feature_available(clkreg) && !$feature_available(ckcon)} {
					continue
				}
			}
			{AUXR1}		{
				if {!$feature_available(ddp) || $feature_available(wdtcon)} {
					continue
				}
			}

			default		{continue}
		}
		set sfr($symbol($reg)) [lindex $item 1]
	}

	# Restore bits which are not affected by reset
	if {$feature_available(pof) && $controllers_conf(POF)} {
		set sfr($symbol(PCON)) [expr {$sfr($symbol(PCON)) | 16}]
	}
	if {$feature_available(x2reset) && $controllers_conf(X2)} {
		set sfr($symbol(CLKREG)) [expr {$sfr($symbol(CLKREG)) | 1}]
	}

	# Reevaluate internal configuration flags
	set sync_ena 0
	foreach addr [array names sfr] {
		evaluate_sfr $addr
	}

	# Reset program run statistics
	for {set i 0} {$i < 10} {incr i} {
		set run_statistics($i) 0
	}

	# Synchronize with special GUI controls
	if {$::GUI_AVAILABLE} {
		$this simulator_GUI_cancel_write_to_eeprom	;# Abort data EEPROM write cycle
		$this interrupt_monitor_reset			;# Reset interrupt monitor
		$this subprograms_clear				;# Clear list subprograms
		$this stopwatch_refresh				;# Stopwatch
		$this stack_monitor_reset			;# clear stack monitor
	}

	# Reset PALE (Peripheral Astraction Layer Engine)
	$this pale_reset
	for {set i 0} {$i < 5} {incr i} {
		set j 0
		foreach bit [split $feature_available(port$i) {}] {
			if {$bit == 0} {
				$this pale_SLSF [list $i $j] 6
			}
			incr j
		}
	}

	# Allow engagement
	set break 0
}

## Step program back
 # @return Bool - false if no more backward steps can be done
public method stepback {} {
	if {!${::Simulator::reverse_run_steps} || !$stepback_length} {
		return 0
	}
	set sync_ena 1
	incr stepback_length -1

	set lst [lindex $stepback_normal $stepback_length]
	set max [llength $lst]
	incr max -1

	for {set i $max} {$i >= 0} {incr i -1} {
		set item	[lindex $lst $i]
		set addr	[lindex $item 1]
		set val		[lindex $item 2]

		switch -- [lindex $item 0] {
			{I} {
				set ram($addr) $val
				$this Simulator_sync_reg $addr
			}
			{E} {
				set eram($addr) $val
				$this Simulator_XDATA_sync $addr
			}
			{P} {
				set eeprom($addr) $val
				::X::sync_eeprom_mem_window [format %X $addr] 0 $this
			}
			{X} {
				set xram($addr) $val
				$this Simulator_XDATA_sync $addr
			}
			{S} {
				set sfr($addr) $val
				evaluate_sfr $addr
			}
		}
	}

	set overall_instructions_org $overall_instructions
	set overall_time_org $overall_time
	simulator_set_special [lindex $stepback_spec $stepback_length]

	set opcode [getCode $pc]
	if {[lsearch ${::CompilerConsts::defined_OPCODE} $opcode] == -1} {
		incr run_statistics(4) -1
	} else {
		incr run_statistics(4) -[lindex $::CompilerConsts::Opcode($opcode) 2]
	}

	incr run_statistics(0) [expr {int(($overall_time - $overall_time_org) * (12000000.0 / $clock_kHz))}]
	incr run_statistics(1) [expr {int($overall_time - $overall_time_org) * 12}]
	incr run_statistics(2) [expr {int($overall_instructions - $overall_instructions_org)}]
	incr run_statistics(3) -1

	switch -- [lindex $stepback_spec [list $stepback_length 0]] {
		6 { ;# Instruction POP peformed
			$this stack_monitor_push $sfr(129) $ram($sfr(129))
			$this stack_monitor_set_last_values_as 0 1
		}
		5 { ;# Instruction PUSH peformed
			$this stack_monitor_pop
		}
		4 { ;# Invocaton of subprogram
			incr run_statistics(7) -1
			$this subprograms_call 3 [expr {($ram([expr {$sfr(129) - 1}]) << 8) + $ram($sfr(129))}] -1

			$this stack_monitor_push [expr {$sfr(129) - 1}] $ram([expr {$sfr(129) - 1}])
			$this stack_monitor_push $sfr(129) $ram($sfr(129))
			$this stack_monitor_set_last_values_as 1 2
		}
		3 { ;# Invocaton from interrupt routine
			incr run_statistics(8) -1
			$this subprograms_call 2 [expr {($ram([expr {$sfr(129) - 1}]) << 8) + $ram($sfr(129))}] -1

			$this stack_monitor_push [expr {$sfr(129) - 1}] $ram([expr {$sfr(129) - 1}])
			$this stack_monitor_push $sfr(129) $ram($sfr(129))
			$this stack_monitor_set_last_values_as 2 2
		}
		2 { ;# Return from subprogram
			incr run_statistics(6) -1
			$this subprograms_return 0

			$this stack_monitor_pop
			$this stack_monitor_pop
		}
		1 { ;# Return from an interrupt
			incr run_statistics(5) -1
			$this subprograms_return 1

			$this stack_monitor_pop
			$this stack_monitor_pop
		}
	}
	if {$::GUI_AVAILABLE} {
		if {[llength $interrupts_in_progress]} {
			simulator_Sbar [mc "Interrupt at vector 0x%s  " [format %X [intr2vector [lindex $interrupts_in_progress end]]]] 1 $this
		} else {
			simulator_Sbar {} 0 $this
		}

		$this graph_stepback [expr {int(($overall_time_org - $overall_time) * 2)}]
		$this interrupt_monitor_reevaluate
		$this stopwatch_refresh
	}
	if {$eeprom_size} {
		for {set i 0} {$i < 32} {incr i} {
			::X::sync_eeprom_write_buffer $i $this
		}
		::X::eeprom_write_buffer_set_offset $eeprom_WR_ofs $this
	}

	if {$eeprom_WR} {
		eeprom_controller [expr {int(($overall_time_org - $overall_time) * (-2))}]
	} else {
		if {$::GUI_AVAILABLE} {
			foreach reg $eeprom_prev {
				::X::sync_eeprom_clear_bg_hg [lindex $reg 0] $this
			}
			$this simulator_GUI_cancel_write_to_eeprom
		}
	}

	$this Simulator_sync_PC_etc

	set stepback_spec	[lreplace $stepback_spec end end]
	set stepback_normal	[lreplace $stepback_normal end end]

	$this Simulator_GUI_sync S 224
	if {!$stepback_length} {
		return 0
	} else {
		return 1
	}
}

## Engage mode "Step"
 # @return Int - line in source code
public method step {} {
	set address_error 0

	# Valid OP code
	if {[check_address_validity C $pc]} {return {}}
	if {$code($pc) != {}} {
		set sync_ena 1		;# Enable synchronization
		instruction_cycle	;# Execute instruction

		# Synchronize
		$this Simulator_GUI_sync S 208
		# Return line number
		update
		return $Line($pc)

	# Invalid OP code
	} else {
		bell
		$this sim_txt_output [mc "No instruction found at 0x%s" [NumSystem::dec2hex $pc]]
		incr_pc 1
		return {}
	}
}

## Engage/Disengage mode "Step over"
 # @return Int - line in source code
public method sim_stepover {} {
	set address_error 0

	# Disengage
	if {$simulation_in_progress} {
		set break 1
		set simulation_in_progress 0
		set stepover_in_progress 0

	# Engage
	} else {
		# Local variables
		set current_line		0 ;# Current line in source code
		set stepover_in_progress	1 ;# Bool: "Step over" mode flag
		set simulation_in_progress	1 ;# Bool: Simulator engaged
		set ::X::critical_procedure_in_progress 0

		# Valid OP code
		set tmp_pc 0
		if {[check_address_validity C $pc]} {
			set simulation_in_progress 0
			set stepover_in_progress 0
			return {}
		}
		if {$code($pc) != {}} {
			set sync_ena 1	;# Enable synchronization

			while {1} {
				# Conditionaly abort simulation
				if {$break} {
					set break 0
					set ::X::critical_procedure_in_progress 0
					set simulation_in_progress 0
					set stepover_in_progress 0
					break
				}

				# Abort simulation on invalid OP code
				if {[check_address_validity C $pc]} {
					set simulation_in_progress 0
					set stepover_in_progress 0
					break
				}
				if {$code($pc) == {}} {
					incr_pc 1
					bell
					$this sim_txt_output [mc "No instruction found at 0x%s" [NumSystem::dec2hex $pc]]
					set simulation_in_progress 0
					set stepover_in_progress 0
					break
				}

				# Execute instruction
				set current_line [lindex $Line($pc) 0]
				instruction_cycle
				if {[lindex $Line($pc) 0] != {} && [lindex $Line($pc) 0] != $current_line} {
					break
				}

				# Synchronize and update GUI
				$this Simulator_sync_PC_etc
				update
			}

			if {$break} {
				set break 0
				set ::X::critical_procedure_in_progress 0
			}

			# Reset flags
			set simulation_in_progress	0 ;# Simulator engaged
			set stepover_in_progress	0 ;# Mode "Step over" engaged

			# Return line
			return $Line($pc)

		# No OP code
		} else {
			incr_pc 1
			bell
			$this sim_txt_output [mc "No instruction found at 0x%s" [NumSystem::dec2hex $pc]]
			set simulation_in_progress 0
			set stepover_in_progress 0
			return {}
		}
	}
}

## Engage/Disengage mode "Run"
 # @return Int - line in source code
public method sim_run {} {
	set address_error 0

	# Local variables
	set last_line [lindex $Line($pc) 0]	;# Line of the last instruction (line in source code)

	# Disengage
	if {$simulation_in_progress} {
		set break			1 ;# Terminate running program
		set simulation_in_progress	0 ;# Bool: Simulator engaged
		set run_in_progress		0 ;# Bool: "Run" mode flag

	# Engage
	} else {
		set sync_ena	0		;# Disabled synchronizations

		# Local variables
		set run_in_progress		1 ;# Bool: "Run" mode flag
		set simulation_in_progress	1 ;# Bool: Simulator engaged
		set idx				0 ;# Instruction index (GUI is updated after each 1000)
		set ::X::critical_procedure_in_progress 0
		set time_ms [clock milliseconds] ;# Int: High res. system timer, used here for regular GUI updates

		# Infinitely execute program instructions until break
		while {1} {
			incr idx
			# Conditionaly abort simulation
			if {$break} {
				set simulation_in_progress 0
				set run_in_progress 0
				set break 0
				set ::X::critical_procedure_in_progress 0
				break
			}

			# Empty OP code -> abort simulation
			if {[check_address_validity C $pc]} {
				set simulation_in_progress 0
				set run_in_progress 0
				break
			}
			if {$code($pc) == {}} {
				set simulation_in_progress 0
				set run_in_progress 0
				bell
				$this sim_txt_output [mc "No instruction found at 0x%s" [NumSystem::dec2hex $pc]]
				break
			}

			# Execute instruction
			instruction_cycle

			if {$::GUI_AVAILABLE} {
				if {([clock milliseconds] - $time_ms) > $GUI_UPDATE_INT} {
					set idx 0
					$this Simulator_sync_PC_etc
					update
					set time_ms [clock milliseconds]
				}
			} else {
				# Stop after 1000 instructions
				if {$idx >= 1000} {
					set idx 0
					set break 1
				}
			}

			# Handle breakpoints
			if {[lindex $Line($pc) 0] != {}} {
				set last_line [lindex $Line($pc) 0]
				if {[lsearch $breakpoints([lindex $Line($pc) 1]) [lindex $last_line 0]] != -1} {
					incr run_statistics(9)
					if {$::CONFIG(BREAKPOINTS_ALLOWED)} {
						set simulation_in_progress 0
						set run_in_progress 0
						Sbar [mc "Breakpoint reached at 0x%s" [NumSystem::dec2hex $pc]]
						break
					}
				}
			}
		}

		if {$break} {
			set break 0
			set ::X::critical_procedure_in_progress 0
		}

		# Return last line (line in source code)
		return $Line($pc)
	}
}

## Engage/Disengage mode "Animation"
 # @return Int - line in source code
public method sim_animate {} {
	set address_error 0

	# Disengage
	if {$simulation_in_progress} {
		set break			1 ;# Terminate running program
		set simulation_in_progress	0 ;# Bool: Simulator engaged
		set animation_in_progress	0 ;# Bool: "Animation" mode flag

	# Engage
	} else {
		set animation_in_progress	1 ;# Bool: "Animation" mode flag
		set simulation_in_progress	1 ;# Bool: Simulator engaged
		set ::X::critical_procedure_in_progress 0

		# Infinitely execute program instructions until break
		while {1} {
			# Conditionaly abort simulation
			if {$break} {
				set simulation_in_progress 0
				set animation_in_progress 0
				set break 0
				set ::X::critical_procedure_in_progress 0
				break
			}

			# Perform program step
			set lineNum [step]

			if {$lineNum == {}} {
				set simulation_in_progress 0
				set animation_in_progress 0
				break
			}

			# Move simulator line in the editor
			$this move_simulator_line $lineNum
			$this Simulator_sync_PC_etc

			# Handle breakpoints
			if {[string length [lindex $lineNum 0]] && [string length [lindex $lineNum 1]]} {
				if {[lsearch $breakpoints([lindex $lineNum 1]) [lindex $lineNum 0]] != -1} {
					incr run_statistics(9)
					if {$::CONFIG(BREAKPOINTS_ALLOWED)} {
						set simulation_in_progress 0
						set animation_in_progress 0
						Sbar [mc "Breakpoint reached at 0x%s" [NumSystem::dec2hex $pc]]
						break
					}
				}
			}

			# Update GUI
			update
		}

		if {$break} {
			set break 0
			set ::X::critical_procedure_in_progress 0
		}
	}
}

## Return true if the engine is engaged
 # @return Bool - engaged flag
public method sim_is_busy {} {
	return $simulation_in_progress
}

## Return true if the engine is in mode "Step over"
 # @return Bool - "Step over" flag
public method sim_stepover_in_progress {} {
	return $stepover_in_progress
}

## Return true if the engine is in mode "Run"
 # @return Bool - "Run" flag
public method sim_run_in_progress {} {
	return $run_in_progress
}

## Return true if the engine is in mode "Animation"
 # @return Bool - "Animation" flag
public method sim_anim_in_progress {} {
	return $animation_in_progress
}

## Disengage simulator (Power off the MCU)
 # @return void
public method Simulator_shutdown {} {
	# Clear content of IDATA memory
	for {set i 0} {$i < $iram_size} {incr i} {
		set ram($i) 0
	}

	# Cancel EEPROM write process
	if {$eeprom_WR} {
		simulator_cancel_write_to_eeprom
	}

	# Discard stepback stack
	stepback_discard_stack

	set break 1
}

## Engage simulator  (Power on the MCU)
 # @return void
public method Simulator_initiate {} {
	set sync_ena 1
	master_reset -
	simulator_system_power_on

	# Reset watchdog
	set watchdog_value	0
	set wdt_prescaler_val	0

	set break 0
}

# >>> File inclusion guard
}
# <<< File inclusion guard

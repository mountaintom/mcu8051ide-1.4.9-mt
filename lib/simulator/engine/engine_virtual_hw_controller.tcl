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
if { ! [ info exists _ENGINE_VIRTUAL_HW_CONTROLLER_TCL ] } {
set _ENGINE_VIRTUAL_HW_CONTROLLER_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Part of simulator engine functionality.
#
# --------------------------------------------------------------------------
# VIRTUAL HW CONTROLLER PROCEDURES
# --------------------------------------------------------------------------


## Perform one instruction cycle
 # @return void
private method instruction_cycle {} {
	set rmw_instruction 0
	set stepback_ena 1

	stepback_save_spec

	# Execute instruction
	if {${::DEBUG}} {
		$code($pc)
	} else {
		if {[catch {
			$code($pc)
		} result]} then {
			if {!${::Simulator::ignore_invalid_ins}} {
				$this simulator_invalid_instruction $pc $Line($pc)
				internal_shutdown
				incr_pc 1
			}
			# OP code 165d is invalid on 8051
			if {$code($pc) != 165} {
				puts stderr ${::errorInfo}
			}
		}
	}

	# Adjust simulator action history
	stepback_save_spec_time

	# Increment program time
	set wtd_rst_flag [increment_program_time $time]

	# Interrupts control
	if {$controllers_conf(EA)} {
		# Determinate minimum interrupt priority
		set min_priority -1
		foreach int $interrupts_in_progress {
			set p [interrupt_priority $int]
			if {$p > $min_priority} {
				set min_priority $p
			}
		}

		# Iterate over list of interrupt priorities
		foreach IntName $controllers_conf(IP) {

			# Skip requests with insufficient priority
			if {[interrupt_priority $IntName] <= $min_priority} {
				continue
			}

			# Test iterrupt flag
			set vector__flag [isInterruptActive $IntName]
			# Handle the interrupt
			if {$vector__flag != 0} {
				interrupt_handler $IntName [lindex $vector__flag 0] [lindex $vector__flag 1] 0
				break
			}
		}
	}

	# Send port states to PALE (Peripheral Abstraction Layer Engine)
	set max $time
	if {!$controllers_conf(X2)} {
		set max [expr {$max * 2}]
	}
	for {set i 1} {$i < $max} {incr i} {
		$this pale_simulation_cycle $ports_previous_state
	}
	set rmw_instruction 1
	set ports_previous_state [list]
	for {set i 0; set addr 128} {$i < 5} {incr i; incr addr 16} {
		if {$feature_available(p$i)} {
			lappend ports_previous_state $sfr($addr)
		} else {
			lappend ports_previous_state 0
		}
	}
	$this pale_simulation_cycle $ports_previous_state

	# Analog comparator controller
	if {[$this pale_is_enabled]} {
		if {$controllers_conf(CEN)} {
			anlcmp_controller
		} else {
			set anlcmp_running 0
			$this pale_SLSF $PIN(ANL0) 0
			$this pale_SLSF $PIN(ANL1) 0
		}
	}

	# UART controller
	if {$feature_available(uart)} {
		if {($uart_RX_in_progress || $uart_TX_in_progress) && ${::Simulator::reverse_run_steps}} {
			stepback_reg_change S $symbol(SBUFR)
			stepback_reg_change S $symbol(SBUFT)
			stepback_reg_change S $symbol(SCON)
		}
		uart_controller $time
	}

	# Handle exteranal interrupts
	foreach int_src {0 1} {
		set intx	1	;# State of pin INTx
		set ext_int	0	;# Local external interrupt flag

		# Anylize port state
		for {set i -$time} {$i < 0} {incr i} {
			# Determinate value of input pin INTX
			set intx [$this pale_RRPPV $PIN(INT${int_src}) $i]

			# Detect falling edge on INTx
			if {$controllers_conf(IT${int_src})} {
				set intx_prev $controllers_conf(INT${int_src})
				set controllers_conf(INT${int_src}) $intx

				if {$intx_prev && !$intx} {
					set ext_int 1
				}

			# Just copy inverted value from INTx to IEx
			} else {
				set ext_int [expr {!$intx}]
			}
		}

		# Invoke external interrupt
		if {
			( $controllers_conf(IT${int_src}) && $ext_int )
				||
			( !$controllers_conf(IT${int_src}) && ($controllers_conf(IE${int_src}) != $ext_int) )
		} then {
			setBit $symbol(IE${int_src}) $ext_int
		}
	}

	## Timers control
	 # Timers 0 and 1 are engaged by PWM
	if {$controllers_conf(PWMEN)} {
		if {!$pwm_running} {
			set pwm_running 1
			$this pale_SLSF $PIN(T1) 3
		} else {
			# Make backup for affected SFR
			if {${::Simulator::reverse_run_steps}} {
				stepback_reg_change S $symbol(TL0)
				stepback_reg_change S $symbol(TH0)
				stepback_reg_change S $symbol(TL1)
			}

			# Timer 0 is forced into mode 2 (8-bit autoreload)
			# TL1 is incremented after each T0 overflow
			incr sfr($symbol(TL0)) $time
			while {1} {
				if {$sfr($symbol(TL0)) > 255} {
					set sfr($symbol(TL0)) [expr {$sfr($symbol(TL0)) - 256 + $sfr($symbol(TH0))}]
					# Increment TL1
					incr sfr($symbol(TL1))

					# TL1 overflow -> High PWM pulse
					if {$sfr($symbol(TL1)) > 255} {
						set sfr($symbol(TL1)) 0		;# Clear TL1
						set pwm_OCR $sfr($symbol(TH1))	;# Load OCR
						pale_WPBBL $PIN(T2) 1 -$sfr($symbol(TL0))
					}

					# OCR and TL1 are equal -> Low PWM pulse
					if {$pwm_OCR == $sfr($symbol(TL1))} {
						set time_back [expr {256 - $sfr($symbol(TL0))}]
						if {$time_back >= 0} {
							$this pale_WPBBL $PIN(T1) 0
						} else {
							$this pale_WPBBL $PIN(T1) $time_back
						}
					}
				} else {
					break
				}
			}

			# Synchronize affected SFR
			if {$sync_ena} {
				$this Simulator_GUI_sync S $symbol(TL0)
				$this Simulator_GUI_sync S $symbol(TH0)
				$this Simulator_GUI_sync S $symbol(TL1)
			}
		}

	 # Timers 0 and 1 are free
	} else {
		# Shutdown PWM controller
		if {$pwm_running} {
			set pwm_running 0
			$this pale_SLSF $PIN(T1) 0
		}

		# Make backup for TCON register
		if {($controllers_conf(TR0) || $controllers_conf(TR1)) && ${::Simulator::reverse_run_steps}} {
			stepback_reg_change S $symbol(TCON)
		}

		# Increment timer 0
		if {$controllers_conf(TR0)} {
			if {${::Simulator::reverse_run_steps}} {
				stepback_reg_change S $symbol(TL0)
				stepback_reg_change S $symbol(TH0)
			}
			timer_controller_01 0
			if {$sync_ena} {
				$this Simulator_GUI_sync S $symbol(TL0)
				$this Simulator_GUI_sync S $symbol(TH0)
			}
		# Shutdown timer 0
		} else {
			set timer_0_running 0
		}

		# Increment timer 1
		if {$controllers_conf(TR1)} {
			if {${::Simulator::reverse_run_steps}} {
				stepback_reg_change S $symbol(TL1)
				stepback_reg_change S $symbol(TH1)
				if {$controllers_conf(T0_MOD) == 3} {
					stepback_reg_change S $symbol(TH0)
				}
			}
			timer_controller_01 1
			if {$sync_ena} {
				$this Simulator_GUI_sync S $symbol(TL1)
				$this Simulator_GUI_sync S $symbol(TH1)
				if {$controllers_conf(T0_MOD) == 3} {
					$this Simulator_GUI_sync S $symbol(TH0)
				}
			}
		# Shutdown timer 1
		} else {
			set timer_1_running 0
		}

		# Keep timer 1 running while timer 0 is in mode 3
		if {$controllers_conf(T0_MOD) == 3} {
			if {${::Simulator::reverse_run_steps}} {
				stepback_reg_change S $symbol(TL1)
				stepback_reg_change S $symbol(TH1)
			}
			special_timer1_controller_T0_MOD_3
			if {$sync_ena} {
				$this Simulator_GUI_sync S $symbol(TL1)
				$this Simulator_GUI_sync S $symbol(TH1)
			}
		}
	}

	# Increment timer 2
	if {$feature_available(t2)} {
		if {$controllers_conf(TR2)} {
			if {${::Simulator::reverse_run_steps}} {
				stepback_reg_change S $symbol(TL2)
				stepback_reg_change S $symbol(TH2)
				stepback_reg_change S $symbol(RCAP2L)
				stepback_reg_change S $symbol(RCAP2H)
				stepback_reg_change S $symbol(T2CON)
			}
			timer_controller_2
			if {$sync_ena} {
				$this Simulator_GUI_sync S $symbol(TL2)
				$this Simulator_GUI_sync S $symbol(TH2)
				$this Simulator_GUI_sync S $symbol(RCAP2L)
				$this Simulator_GUI_sync S $symbol(RCAP2H)
			}
		# Shutdown timer 2
		} else {
			set timer_2_running 0
		}
	}

	# Manage interrupt monitor
	if {$::GUI_AVAILABLE} {
		$this interrupt_monitor_intr_flags [simulator_get_active_intr_flags]
	}

	# Adjust stopwatch timer
	incr run_statistics(3)
	if {$::GUI_AVAILABLE} {
		$this stopwatch_refresh
	}

	# Manage stack for stepback stack
	stepback_save_norm
	set stepback_ena 0

	# Manage PALE
	$this pale_finish_simulation_cycle
}

## Analog comparator controller
 # It's safe to call this function even if there is no analog comparator implemented on the MCU
 # @return void
private method anlcmp_controller {} {
	set sample 0

	# Start analog comparator
	if {!$anlcmp_running} {
		$this pale_SLSF $PIN(ANL0) 4
		$this pale_SLSF $PIN(ANL1) 4

		set anlcmp_running 1
		return
	}

	## Sample inputs
	 # Debounce mode
	if {[lsearch {2 3 6} $controllers_conf(AC_MOD)] != -1} {
		incr anlcpm_db_timer $timer1_overflow
		if {$anlcpm_db_timer >= 2} {
			incr anlcpm_db_timer -$anlcpm_db_timer
			set sample 1
		}
	 # Normal mode (sample every S4)
	} else {
		set sample 1
	}
	 # Sample port pins ANL0 and ANL1
	if {!$sample} {
		return
	}
	set anlcmp_output_prev $anlcmp_output
	set anlcmp_output [expr {([$this pale_RRPPV $PIN(ANL0)] - [$this pale_RRPPV $PIN(ANL1)]) > 0 ? 1 : 0}]

	# Conditionaly ionvoke analog comparator interrupt
	switch -- $controllers_conf(AC_MOD) {
		0 {	;# Negative (Low) level
			if {!$anlcmp_output} {
				write_sfr $symbol(ACSR) [expr {$sfr($symbol(ACSR)) | 0x10}]
			}
		}
		1 {	;# Positive edge
			if {!$anlcmp_output_prev && $anlcmp_output} {
				write_sfr $symbol(ACSR) [expr {$sfr($symbol(ACSR)) | 0x10}]
			}
		}
		2 {	;# Toggle with debounce
			if {$anlcmp_output_prev != $anlcmp_output} {
				write_sfr $symbol(ACSR) [expr {$sfr($symbol(ACSR)) | 0x10}]
			}
		}
		3 {	;# Positive edge with debounce
			if {!$anlcmp_output_prev && $anlcmp_output} {
				write_sfr $symbol(ACSR) [expr {$sfr($symbol(ACSR)) | 0x10}]
			}
		}
		4 {	;# Negative edge
			if {$anlcmp_output_prev && !$anlcmp_output} {
				write_sfr $symbol(ACSR) [expr {$sfr($symbol(ACSR)) | 0x10}]
			}
		}
		5 {	;# Toggle
			if {$anlcmp_output_prev != $anlcmp_output} {
				write_sfr $symbol(ACSR) [expr {$sfr($symbol(ACSR)) | 0x10}]
			}
		}
		6 {	;# Negative edge with debounce
			if {$anlcmp_output_prev && !$anlcmp_output} {
				write_sfr $symbol(ACSR) [expr {$sfr($symbol(ACSR)) | 0x10}]
			}
		}
		7 {	;# Positive (High) level
			if {$anlcmp_output} {
				write_sfr $symbol(ACSR) [expr {$sfr($symbol(ACSR)) | 0x10}]
			}
		}
	}
}

## Timer controller for timer 2
 # @retrun void
private method timer_controller_2 {} {
	set timer2_overflow	0
	set increment		0

	## Determinate counter increment
	 # Counter 16-bit
	if {$controllers_conf(CT2)} {
		# Detect 1-to-0 transition on external input
		for {set i -$time} {$i < 0} {incr i} {
			set counter_input_prev $controllers_conf(T2)
			set controllers_conf(T2) [$this pale_RRPPV $PIN(T2) $i]

			if {$counter_input_prev && !$controllers_conf(T2)} {
				incr increment
			}
		}

	 # Timer 16-bit
	} else {
		set increment $time
	}

	# Programmable Clock-output
	if {$controllers_conf(T2OE)} {
		for {set i [expr {-$time + 1}]} {$i <= 0} {incr i} {
			$this pale_WPBBL $PIN(T2) $controllers_conf(T2) $i
		}

		# 16-bit timer
		if {$timer_2_running && !$controllers_conf(CT2)} {
			set increment [expr {$time * 6}]
		} else {
			set increment 0
		}
		if {[increment_timer2 $increment 1]} {
			while {1} {
				set sfr($symbol(TH2)) $sfr($symbol(RCAP2H))
				if {![increment_timer2 $sfr($symbol(RCAP2L)) 1]} {
					break
				}
				incr timer2_overflow
			}

			# Detect transition on external input
			set controllers_conf(T2) [expr {!$controllers_conf(T2)}]
		}

		# External interrupt
		for {set i -$time} {$i < 0} {incr i} {
			# Detect 1-to-0 transition on external input
			set t2ex_prev $controllers_conf(T2EX)
			set controllers_conf(T2EX) [$this pale_RRPPV $PIN(T2EX) $i]

			# Invoke external interrupt
			if {$t2ex_prev && !$controllers_conf(T2EX) && $controllers_conf(EXEN2)} {
				setBit $symbol(EXF2) 1
			}
		}

	# Baud Rate Generator
	} elseif {$controllers_conf(RCLK) || $controllers_conf(TCLK)} {
		if {$controllers_conf(CT2)} {
			set increment [expr {$increment * 6}]
		}
		if {[increment_timer2 $increment 1]} {
			while {1} {
				set sfr($symbol(TH2)) $sfr($symbol(RCAP2H))
				if {![increment_timer2 $sfr($symbol(RCAP2L)) 1]} {
					break
				}
				incr timer2_overflow
			}
		}

		# External interrupt
		for {set i -$time} {$i < 0} {incr i} {
			# Detect 1-to-0 transition on external input
			set t2ex_prev $controllers_conf(T2EX)
			set controllers_conf(T2EX) [$this pale_RRPPV $PIN(T2EX) $i]

			# Invoke external interrupt
			if {$t2ex_prev && !$controllers_conf(T2EX) && $controllers_conf(EXEN2)} {
				setBit $symbol(EXF2) 1
			}
		}

	# 16-bit Capture
	} elseif {$controllers_conf(CPRL2) && $timer_2_running} {
		set capture_flag 0

		# Increment timer registers
		if {[increment_timer2 $increment 1]} {
			setBit $symbol(TF2) 1
		}

		# Detect 1-to-0 transition on external input
		for {set i -$time} {$i < 0} {incr i} {
			set t2ex_prev $controllers_conf(T2EX)
			set controllers_conf(T2EX) [$this pale_RRPPV $PIN(T2EX) $i]

			# Capture TL2 and TH2 to RCAP2L and RCAP2H
			if {$t2ex_prev && !$controllers_conf(T2EX) && $controllers_conf(EXEN2)} {
				setBit $symbol(EXF2) 1

				set sfr($symbol(RCAP2L)) $sfr($symbol(TL2))
				set sfr($symbol(RCAP2H)) $sfr($symbol(TH2))

			}
		}

	# 16-bit Auto-reload (DCEN == 1)
	} elseif {$controllers_conf(DCEN) && $timer_2_running} {
		set updown [$this pale_RRPPV $PIN(T2EX)]
		set result [increment_timer2 $increment $updown]

		# Overflow
		if {$result == 1} {
			while {1} {
				set sfr($symbol(TH2)) $sfr($symbol(RCAP2H))
				if {![increment_timer2 $sfr($symbol(RCAP2L)) $updown]} {
					break
				}
			}

			setBit $symbol(TF2) 1
			setBit $symbol(EXF2) [expr {![getBit $symbol(EXF2)]}]
		}

		# Underflow
		if {!$updown || $result == -1} {
			while {1} {
				set cur_val [expr {$sfr($symbol(TL2)) + ($sfr($symbol(TH2)) << 8)}]
				set min_val [expr {$sfr($symbol(RCAP2L)) + ($sfr($symbol(RCAP2H)) << 8)}]

				set diff [expr {$min_val - $cur_val}]

				if {$diff > 0} {
					incr diff -1
					set sfr($symbol(TL2)) 255
					set sfr($symbol(TH2)) 255

					increment_timer2 $diff 0
					set result -1

				} else {
					break
				}
			}
		}

		if {$result == -1} {
			setBit $symbol(TF2) 1
			setBit $symbol(EXF2) [expr {![getBit $symbol(EXF2)]}]
		}

	# 16-bit Auto-reload (DCEN == 0)
	} elseif {$timer_2_running} {
		if {[increment_timer2 $increment 1]} {
			while {1} {
				set sfr($symbol(TH2)) $sfr($symbol(RCAP2H))
				if {![increment_timer2 $sfr($symbol(RCAP2L)) 1]} {
					break
				}
			}
			setBit $symbol(TF2) 1
			setBit $symbol(EXF2) [expr {![getBit $symbol(EXF2)]}]
		}
	}

	# Start the timer if it is not already started
	if {!$timer_2_running} {
		set timer_2_running 1
		return
	}
}

## Increment timer 2
 # @parm Int increment_by	- value to increment by
 # @parm Bool updown		- 1 == count up; 0 == count down
 # @retrun Int - 1 == Owerflow; -1 == Underflow; 0 == normal
private method increment_timer2 {increment_by updown} {
	if {$updown} {
		incr sfr($symbol(TL2)) $increment_by
	} else {
		incr sfr($symbol(TL2)) -$increment_by
	}

	# Low-order byte overflow
	if {$sfr($symbol(TL2)) > 255} {
		incr sfr($symbol(TH2))
		incr sfr($symbol(TL2)) -256
		if {$sfr($symbol(TH2)) > 255} {
			set sfr($symbol(TH2)) 0
			return 1
		}
	# Low-order byte underflow
	} elseif {$sfr($symbol(TL2)) < 0} {
		incr sfr($symbol(TH2)) -1
		incr sfr($symbol(TL2)) 256
		if {$sfr($symbol(TH2)) < 0} {
			set sfr($symbol(TH2)) 255
			return -1
		}
	}

	# Normal operation
	return 0

}

## Order UART to initialize transmission cycle
 # @return void
private method uart_start_transmission {} {
	# Begin transmission with two instruction cycles delay
	set uart_TX_in_progress -1

	# Initialize internall transmission buffer (shift register)
	switch $controllers_conf(UART_M) {
		0 {
			set uart_TX_shift_reg [expr {$sfr($symbol(SBUFT)) + 0x100}]
		}
		1 {
			set uart_TX_shift_reg [expr {($sfr($symbol(SBUFT)) << 1) + 0x600}]
		}
		2 {
			set uart_TX_shift_reg [expr {($sfr($symbol(SBUFT)) << 1) + 0xC00 + ([getBit $symbol(TB8)] << 9)}]
		}
		3 {
			set uart_TX_shift_reg [expr {($sfr($symbol(SBUFT)) << 1) + 0xC00 + ([getBit $symbol(TB8)] << 9)}]
		}
	}

	# Set line special funtion to data transmission
	if {$controllers_conf(UART_M) == 0} {
		$this pale_SLSF $PIN(TXD) 2
		$this pale_SLSF $PIN(RXD) 1
	} else {
		$this pale_SLSF $PIN(TXD) 1
	}
}

## UART (Universal Asynchronous Receiver Transmitter) controller
 # @parm Int num - Number of machine cycles performed by last set of instructions
 # @return void
private method uart_controller {num} {
	set send_tx_shift_clock_sequence 0

	# Manage UART clock prescaler
	if {$uart_RX_in_progress || $uart_TX_in_progress} {
		if {$controllers_conf(UART_M) == 1 || $controllers_conf(UART_M) == 3} {
			incr uart_clock_prescaler $timer1_overflow
		} elseif {$controllers_conf(UART_M) == 2} {
			incr uart_clock_prescaler $num
		}
	}

	# ----------------------------------------------------------------------
	# RECEPTION PROCEDURE
	# ----------------------------------------------------------------------

	# Reception is already in progress
	if {$uart_RX_in_progress} {
		# Make backup for SBUF-R
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change S $symbol(SBUFR)
		}

		# Mode 0
		if {!$controllers_conf(UART_M)} {
			set send_tx_shift_clock_sequence $num
			for {set i -$num} {$i <= 0} {incr i} {
				set uart_RX_shift_reg [expr {$uart_RX_shift_reg << 1}]
				incr uart_RX_shift_reg [$this pale_RRPPV $PIN(RXD) $i]

				if {!($uart_RX_shift_reg & 0x100)} {
					# Stop reception
					set uart_RX_in_progress 0
					$this pale_SLSF $PIN(RXD) 0
					$this pale_SLSF $PIN(TXD) 0

					# Set RI and SBUF
					setBit $symbol(RI) 1
					set sfr($symbol(SBUFR)) [expr {$uart_RX_shift_reg & 0x0FF}]

					break
				}
			}
		# Mode 1, 2 or 3
		} else {
			## Select RX clock source
			if {$controllers_conf(UART_M) == 2} {
				if {$controllers_conf(SMOD)} {
					incr uart_RX_clock [expr {$uart_clock_prescaler / 2}]
				} else {
					incr uart_RX_clock [expr {$uart_clock_prescaler / 4}]
				}
			} else {
				# Timer 2 overflow
				if {$controllers_conf(RCLK)} {
					incr uart_RX_clock $timer2_overflow
				# Timer 1 overflow
				} else {
					if {$controllers_conf(SMOD)} {
						incr uart_RX_clock $timer1_overflow
					} else {
						incr uart_RX_clock [expr {$uart_clock_prescaler / 2}]
					}
				}
			}

			# Prescaler overflew -> Commence 1b reception
			if {$uart_RX_clock >= 16} {
				incr uart_RX_clock -16
				set uart_RX_shift_reg [expr {$uart_RX_shift_reg << 1}]
				incr uart_RX_shift_reg [$this pale_RRPPV $PIN(RXD)]

				# Mode 1
				if {$controllers_conf(UART_M) == 1} {
					if {!($uart_RX_shift_reg & 0x200)} {
						# Stop reception
						set uart_RX_in_progress 0
						$this pale_SLSF $PIN(RXD) 0

						# Set RI and SBUF
						setBit $symbol(RB8) [expr {$uart_RX_shift_reg & 1}]
						set sfr($symbol(SBUFR)) [expr {($uart_RX_shift_reg & 0x1FE) >> 1}]

						if {
							(!$controllers_conf(RI) &&
								(!$controllers_conf(SM2) || ($uart_RX_shift_reg & 1))
							)
						} then {
							setBit $symbol(RI) 1
						# Frame error
						} else {
							$this simulator_uart_invalid_stop_bit $pc $Line($pc)
							internal_shutdown
						}

						# Frame error detection
						if {$feature_available(smod0) && !($uart_RX_shift_reg & 1)} {
							set controllers_conf(FE) 1
							if {$sync_ena} {
								$this Simulator_GUI_sync S $symbol(SCON)
							}
						}
					}
				# Mode 2 or 3
				} elseif {!($uart_RX_shift_reg & 0x400)} {
					# Stop reception
					set uart_RX_in_progress 0
					$this pale_SLSF $PIN(RXD) 0

					# Set RI and SBUF
					setBit $symbol(RB8) [expr {$uart_RX_shift_reg & 2}]
					set sfr($symbol(SBUFR)) [expr {($uart_RX_shift_reg & 0x3FC) >> 2}]
					if {$controllers_conf(SM2)} {
						if {$feature_available(euart)} {
							# Check for broadcast address
							if {$sfr($symbol(SBUFR)) == ($sfr($symbol(SADEN)) | $sfr($symbol(SADDR)))} {
								setBit $symbol(RI) $controllers_conf(RB8)
							# Check for the given address
							} elseif {($sfr($symbol(SBUFR)) & $sfr($symbol(SADEN))) == ($sfr($symbol(SADDR)) & $sfr($symbol(SADEN)))} {
								setBit $symbol(RI) $controllers_conf(RB8)
							}
						} else {
							setBit $symbol(RI) $controllers_conf(RB8)
						}
					} else {
						setBit $symbol(RI) 1
					}

					# Frame error
					if {$feature_available(smod0) && !($uart_RX_shift_reg & 1)} {
						set controllers_conf(FE) 1
						if {$sync_ena} {
							$this Simulator_GUI_sync S $symbol(SCON)
						}
					}
				}
			}
		}

		# Synchronize SBUF-R
		if {$sync_ena} {
			$this Simulator_GUI_sync S $symbol(SBUFR)
		}

	# Reception may begin now ...
	} else {
		# Mode 0 - REN starts reception
		if {!$controllers_conf(UART_M)} {
			if {$controllers_conf(REN) && !$controllers_conf(RI)} {
				set uart_RX_in_progress 1
				$this pale_SLSF $PIN(TXD) 2
				$this pale_SLSF $PIN(RXD) 1

				set uart_RX_shift_reg 0x1FE
			}
		# Mode 1, 2, 3 - Start bit starts reception
		} else {
			if {![$this pale_RRPPV $PIN(RXD)]} {
				set uart_RX_clock 0
				set uart_RX_in_progress 1
				$this pale_SLSF $PIN(RXD) 1

				set uart_RX_shift_reg 0x3FE
			}
		}
	}

	# ----------------------------------------------------------------------
	# TRASMISSION PROCEDURE
	# ----------------------------------------------------------------------

	# Trasmission just began, but with one machine cycle delay
	if {$uart_TX_in_progress == -2} {
		set uart_TX_in_progress 1
		incr num -1

	# Begin transmission on next instruction
	} elseif {$uart_TX_in_progress == -1} {
		set uart_TX_in_progress -2

	# Transmission
	} elseif {$uart_TX_in_progress == 1} {
		# Make bakup for SBUF-T
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change S $symbol(SBUFT)
		}

		# Mode 0
		if {!$controllers_conf(UART_M)} {
			set start_pos [expr {$num * (-2)}]

			for {set i $start_pos} {$i < 0} {} {
				incr i
				set bit_to_send [expr {$uart_TX_shift_reg & 1}]
				if {!$controllers_conf(X2)} {
					$this pale_WPBBL $PIN(RXD) $bit_to_send $i
					$this pale_WPBBL $PIN(TXD) 0 $i
					incr i
					$this pale_WPBBL $PIN(RXD) $bit_to_send $i
					$this pale_WPBBL $PIN(TXD) 1 $i
				} else {
					incr i
					$this pale_WPBBL $PIN(TXD) {|} [expr {int($i / 2)}]
					$this pale_WPBBL $PIN(RXD) $bit_to_send [expr {int($i / 2)}]
				}

				set uart_TX_shift_reg [expr {$uart_TX_shift_reg >> 1}]
				set sfr($symbol(SBUFT)) $uart_TX_shift_reg

				if {!($uart_TX_shift_reg & 0x1FE)} {

					# Stop transmission
					set uart_TX_in_progress 0
					$this pale_SLSF $PIN(RXD) 0
					$this pale_SLSF $PIN(TXD) 0

					# Set TI
					setBit $symbol(TI) 1

					break
				}
			}
		# Mode 1, 2, 3
		} else {

			## Select TX clock source
			if {$controllers_conf(UART_M) == 2} {
				if {$controllers_conf(SMOD)} {
					incr uart_TX_clock [expr {$uart_clock_prescaler / 2}]
				} else {
					incr uart_TX_clock [expr {$uart_clock_prescaler / 4}]
				}
			} else {
				# Timer 2 overflow
				if {$controllers_conf(TCLK)} {
					incr uart_TX_clock $timer2_overflow
				# Timer 1 overflow
				} else {
					if {$controllers_conf(SMOD)} {
						incr uart_TX_clock $timer1_overflow
					} else {
						incr uart_TX_clock [expr {$uart_clock_prescaler / 2}]
					}
				}
			}

			# Prescaler overflew -> Commence 1b transmission
			if {$uart_TX_clock >= 16} {
				incr uart_TX_clock -16

				$this pale_WPBBL $PIN(TXD) [expr {$uart_TX_shift_reg & 1}]
				set uart_TX_shift_reg [expr {$uart_TX_shift_reg >> 1}]
				set sfr($symbol(SBUFT)) $uart_TX_shift_reg

				if {!($uart_TX_shift_reg & 0x7FE)} {
					# Stop transmission
					set uart_TX_in_progress 0
					$this pale_SLSF $PIN(TXD) 0

					# Set TI
					setBit $symbol(TI) 1
				}
			}
		}

		# Synchronize SBUF-T
		if {$sync_ena} {
			$this Simulator_GUI_sync S $symbol(SBUFT)
		}
	}

	# Again manage UART clock prescaler
	if {$uart_clock_prescaler && $controllers_conf(UART_M)} {
		if {$controllers_conf(SMOD)} {
			set uart_clock_prescaler [expr {$uart_clock_prescaler % 2}]
		} else {
			set uart_clock_prescaler [expr {$uart_clock_prescaler % 4}]
		}
	}
}

## Timer 1 controller which operate while timer 0 is engaged in mode 3
 # @return void
private method special_timer1_controller_T0_MOD_3 {} {
	set timer1_overflow 0

	set TL1 $symbol(TL1)
	set TH1 $symbol(TH1)

	# Timer 1 mode
	switch -- $controllers_conf(T1_MOD) {
		0 {	;# Mode 0 - 13 bit counter
			incr sfr($TL1) $time
			if {$sfr($TL1) > 31} {
				incr sfr($TH1)
				incr sfr($TL1) -32
				if {$sfr($TH1) > 255} {
					set sfr($TH1) 0
					set timer1_overflow 1
				}
			}
		}
		1 {	;# Mode 1 - 16 bit counter
			incr sfr($TL1) $time
			if {$sfr($TL1) > 255} {
				incr sfr($TH1)
				incr sfr($TL1) -256
				if {$sfr($TH1) > 255} {
					set sfr($TH1) 0
					set timer1_overflow 1
				}
			}
		}
		2 {	;# Mode 2 - 8 bit auto-reload counter
			incr sfr($TL1) $time
			while {1} {
				if {$sfr($TL1) > 255} {
					set sfr($TL1) [expr {$sfr($TL1) - 256 + $sfr($TH1)}]
					incr timer1_overflow
				} else {
					break
				}
			}
		}
		3 {	;# Timer halted
		}
	}
}

## Timers controller for timers 0 and 1
 # -- should be called after each instruction cycle
 # @parm Int timer_num - Number of timer to hadnle ('0' or '1')
 # @return void
private method timer_controller_01 {timer_num} {
	set timer1_overflow	0
	set increment		0

	# Start the timer if it is not already started
	if {$timer_num == 1} {
		if {!$timer_1_running} {
			set timer_1_running 1
			return
		}
	} else {
		if {!$timer_0_running} {
			set timer_0_running 1
			return
		}
	}

	# Determinate counter increment
	if {$controllers_conf(CT${timer_num})} {
		# Detect 1-to-0 transition on external input
		for {set i -$time} {$i < 0} {incr i} {
			set counter_input_prev $controllers_conf(T${timer_num})
			set controllers_conf(T${timer_num}) [$this pale_RRPPV $PIN(T${timer_num}) $i]

			if {$counter_input_prev && !$controllers_conf(T${timer_num})} {
				incr increment
			}
		}

		# Trigered counter
		if {$controllers_conf(GATE${timer_num})} {
			# Read Intx and allow increment only if INTx is 1
			if {![$this pale_RRPPV $PIN(INT${timer_num})]} {
				set increment 0
			}
		}
	} else {
		set increment $time

		# Trigered timer
		if {$controllers_conf(GATE${timer_num})} {
			# Read Intx and allow increment only if INTx is 1
			if {![$this pale_RRPPV $PIN(INT${timer_num})]} {
				set increment 0
			}
		}
	}

	# Inrement timer 0 in mode 3 (Dual timer/counter)
	if {$controllers_conf(T0_MOD) == 3} {
		# Increment TH0
		if {$timer_num == 1} {
			incr sfr($symbol(TH0)) $time
			if {$sfr($symbol(TH0)) > 255} {
				set sfr($symbol(TH0)) [expr {$sfr($symbol(TH0)) - 256}]
				setBit $symbol(TF1) 1
			}
		# Increment TL0
		} else {
			incr sfr($symbol(TL0)) $increment
			if {$sfr($symbol(TL0)) > 255} {
				set sfr($symbol(TL0)) [expr {$sfr($symbol(TL0)) - 256}]
				setBit $symbol(TF0) 1
			}
		}

		return
	}

	# Determinate TLx and THx addresses
	set TL_addr $symbol(TL${timer_num})
	set TH_addr $symbol(TH${timer_num})

	# Increment the timer in mode 0, 1 or 2
	switch -- $controllers_conf(T${timer_num}_MOD) {
		0 {	;# Mode 0 - 13 bit counter

			set TL_upper_3_bits [expr {$sfr($TL_addr) & 0xE0}]
			set sfr($TL_addr) [expr {$sfr($TL_addr) & 0x1F}]

			incr sfr($TL_addr) $increment
			if {$sfr($TL_addr) > 31} {
				incr sfr($TH_addr)
				incr sfr($TL_addr) -32
				if {$sfr($TH_addr) > 255} {
					set sfr($TH_addr) 0
					setBit $symbol(TF${timer_num}) 1
					if {$timer_num} {
						set timer1_overflow 1
					}
				}
			}
			set sfr($TL_addr) [expr {$sfr($TL_addr) | $TL_upper_3_bits}]
		}
		1 {	;# Mode 1 - 16 bit counter
			incr sfr($TL_addr) $increment
			if {$sfr($TL_addr) > 255} {
				incr sfr($TH_addr)
				incr sfr($TL_addr) -256
				if {$sfr($TH_addr) > 255} {
					set sfr($TH_addr) 0
					setBit $symbol(TF${timer_num}) 1
					if {$timer_num} {
						set timer1_overflow 1
					}
				}
			}
		}
		2 {	;# Mode 2 - 8 bit auto-reload counter
			incr sfr($TL_addr) $increment
			while {1} {
				if {$sfr($TL_addr) > 255} {
					set sfr($TL_addr) [expr {$sfr($TL_addr) - 256 + $sfr($TH_addr)}]
					setBit $symbol(TF${timer_num}) 1
					if {$timer_num} {
						incr timer1_overflow
					}
				} else {
					break
				}
			}
		}
		3 {	;# Timer halted (timer 1)
		}
	}
}

## Data EEPROM controller
 # @parm Int num - Number of clock cycles preformed divided by 6
 # @return void
private method eeprom_controller {num} {
	if {!$eeprom_size || !$eeprom_WR} {return}

	# Conditionaly abort write cycle
	if {!$controllers_conf(WRTINH) || !$controllers_conf(EEMWE)} {
		if {!${::Simulator::ignore_EEPROM_WR_abort}} {
			$this simulator_EEPROM_WR_abort $pc $Line($pc)
			internal_shutdown
		}

		# Fill incomplete bytes with random values
		set eeprom_prev_new [list]
		foreach reg $eeprom_prev {
			lappend eeprom_prev_new [lindex $reg 0] [undefined_octet]
		}
		set eeprom_prev $eeprom_prev_new

		simulator_cancel_write_to_eeprom
		return
	}

	set eeprom_WR_time_org [expr {int($eeprom_WR_time)}]
	set eeprom_WR_time [expr {$eeprom_WR_time + $num * (300.0 / $clock_kHz)}]

	# Write cycle complete
	if {$eeprom_WR_time > 100.0} {
		simulator_finalize_write_to_eeprom

	# Write still in progress
	} elseif {$eeprom_WR_time_org != int($eeprom_WR_time)} {
		$this simulator_WTE_prg_set [expr {int($eeprom_WR_time)}]
	}

}

## Watchdog controller
 # @return Bool - true == MCU reseted; false == all in normal
private method watchdog_controller {} {

	# Watchdog timer software controll
	if {!$controllers_conf(HWDT)} {

		# Reset
		if {$controllers_conf(WSWRST)} {
			set watchdog_value -$time
			set controllers_conf(WSWRST) 0
			if {${::Simulator::reverse_run_steps}} {
				stepback_reg_change S 167
			}
			set sfr(167) [expr {$sfr(167) - 2}]
			if {$sync_ena} {
				$this Simulator_GUI_sync S 167
			}
		}

		# Enable / Disable
		if {$controllers_conf(WDTEN) && !$controllers_conf(WatchDogTimer)} {
			incr watchdog_value -$time
			set controllers_conf(WatchDogTimer) 1
		}

	# Hardware control -- WDTEN is read-only (1 == running; 0 == stopped)
	} elseif {$controllers_conf(WatchDogTimer) != $controllers_conf(WDTEN)} {
		set controllers_conf(WDTEN) $controllers_conf(WatchDogTimer)
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change S 167
		}
		if {$controllers_conf(WDTEN)} {
			set sfr(167) [expr {$sfr(167) | 1}]
		} else {
			set sfr(167) [expr {$sfr(167) - 1}]
		}
		if {$sync_ena} {
			$this Simulator_GUI_sync S 167
		}
	}

	# Check if watchdog is enabled
	if {!$controllers_conf(WatchDogTimer)} {
		return 0
	}

	# Increment watchdog prescaler first
	set increment 0
	if {$controllers_conf(WatchDogPrescaler)} {
		incr wdt_prescaler_val $time
		while {1} {
			if {$wdt_prescaler_val >= $controllers_conf(WatchDogPrescaler)} {
				incr wdt_prescaler_val -$controllers_conf(WatchDogPrescaler)
				incr increment
			} else {
				break
			}
		}
	} else {
		set increment $time
	}

	# Increment watchdog time
	if {!$increment} {return 0}
	incr watchdog_value $increment
	if {$watchdog_value < 8192} {
		return 0
	}

	# Handle watchdog overflow
	incr watchdog_value -8192
	incr time -$watchdog_value
	incr time 8
	set watchdog_value 0
	master_reset -
	$this Simulator_sync_PC_etc

	# Shutdown simulator and inform user about the situation
	if {!${::Simulator::ignore_watchdog_reset}} {
		internal_shutdown
		$this simulator_watchdog_reset $pc $Line($pc)
	}

	return 1
}

## Resolve interrupt priority
 # @parm String flag - Interrupt name
 # @return Int - 0..3
private method interrupt_priority {IntName} {
	return [lindex $controllers_conf(IP_level)		\
		[lsearch $controllers_conf(IP) $IntName]	\
	]
}

## Translate interrupt name to interrupt vector
 # @parm String IntName		- Interrupt name (one of {PX0 PT0 PX1 PT1 PS PT2 PC})
 # @return Int - Interrupt vector
public method intr2vector {intname} {
	switch -- $intname {
		{PX0}	{return 3}
		{PT0}	{return 11}
		{PX1}	{return 19}
		{PT1}	{return 27}
		{PS}	{return 35}
		{PT2}	{return 43}
		{PC}	{return 51}
	}
}

## Interrupt controller -- handles interrupt requests
 # @parm String IntName		- Interrupt name (one of {PX0 PT0 PX1 PT1 PS PT2 PC})
 # @parm Int vector		- Interrupt vector (eg. '27' (T1 on 0x1B))
 # @parm String flag_bit	- Name of interrupt flag
 # @parm Bool immediately	- Invoked by user
 # @return Bool - 0 == interrupt denied; 1 == interrupt accepted
private method interrupt_handler {IntName vector flag_bit immediately} {

	if {!$immediately} {
		# Set interrupt_on_next if the time is too low
		if {$time == 1 && !$interrupt_on_next} {
			set interrupt_on_next 1
			return 0
		}

		# If the last instruction was RETI or any access to the IE, IP or IPH registers -> SKIP
		if {$skip_interrupt} {
			set skip_interrupt 0
			return 0
		}
	}

	# Adjust program run statistics
	incr run_statistics(5)

	# Set interrupt related variables
	set interrupt_on_next		0		;# Bool: Invoke interrupt on the next instruction
	lappend interrupts_in_progress	$IntName	;# List: Priority flags of interrupts which are in progress
	lappend inter_in_p_flags	$flag_bit	;# List: Interrupt flags of interrupts which are in progress

	# Adjust status bar
	if {$::GUI_AVAILABLE} {
		simulator_Sbar [mc "Interrupt  PC: 0x%s; line: %s; vector 0x%s  " [format %X $pc] [lindex $Line($pc) 0] [format %X $vector]] 1 $this
	}
	$this pale_interrupt $vector

	# Invoke LCALL to interrupt vector
	incr time 2
	if {!$immediately} {
		stepback_save_spec_subprog 1
	}
	uart_controller 2
	if {[increment_program_time 2]} {return}
	stack_push [expr {$pc & 255}]
	stack_push [expr {($pc & 65280) >> 8}]
	$this subprograms_call 2 $pc $vector
	$this stack_monitor_set_last_values_as 2 2
	incr run_statistics(3)

	# Unset interrupt flag
	switch -- $IntName {
		{PX0}	{	;# External 0
			if {$controllers_conf(IT0)} {
				setBit $symbol(IE0) 0
			}
		}
		{PT0}	{	;# Timer 0
			setBit $symbol(TF0) 0
		}
		{PX1}	{	;# External 1
			if {$controllers_conf(IT1)} {
				setBit $symbol(IE1) 0
			}
		}
		{PT1}	{	;# Timer 1
			setBit $symbol(TF1) 0
		}
		{PT2}	{	;# Timer 2
		}
		{PS}	{	;# UART
		}
		{PC}	{	;# Analog comparator
		}
	}

	# Report interrupt to interrupt monitor
	set flag {}
	switch $IntName {
		{PX0}	{set flag IE0}
		{PT0}	{set flag TF0}
		{PX1}	{set flag IE1}
		{PT1}	{set flag TF1}
		{PT2}	{
			foreach flag {TF2 EXF2} {
				if {$controllers_conf($flag)} {break}
			}
		}
		{PS}	{
			foreach flag {SPIF TI RI} {
				if {$controllers_conf($flag)} {break}
			}
		}
		{PC}	{set flag CF}
	}
	if {!$immediately} {
		$this interrupt_monitor_intr $flag
	}

	# Done ...
	set pc $vector
	return 1
}

## Test if the given interrupt is active (routine engaged)
 # @parm String IntName - Interrupt name
 # @return List - Interrupt vector or 0 in there is no interrupt active & Flag bit
private method isInterruptActive {IntName} {
	switch -- $IntName {
		{PX0}	{	;# External 0
			if {!$controllers_conf(EX0)}	{return 0}
			if {$controllers_conf(IE0)}	{return {3 IE0}}
		}
		{PT0}	{	;# Timer 0
			if {!$controllers_conf(ET0)}	{return 0}
			if {$controllers_conf(TF0)}	{return {11 TF0}}
		}
		{PX1}	{	;# External 1
			if {!$controllers_conf(EX1)}	{return 0}
			if {$controllers_conf(IE1)}	{return {19 IE1}}
		}
		{PT1}	{	;# Timer 1
			if {!$controllers_conf(ET1)}	{return 0}
			if {$controllers_conf(TF1)}	{return {27 TF1}}
		}
		{PS}	{	;# UART & SPI
			if {!$controllers_conf(ES)}	{return 0}
			if {$feature_available(uart)} {
				if {$controllers_conf(TI)} {
					return {35 TI}
				} elseif {$controllers_conf(RI)} {
					return {35 RI}
				}
			}
			if {$feature_available(spi) && $controllers_conf(SPIE) && $controllers_conf(SPIF)} {
				return {35 SPIE}
			}
		}
		{PT2}	{	;# Timer 2
			if {!$controllers_conf(ET2)}	{return 0}
			if {$controllers_conf(TF2)} {
				return {43 TF2}
			} elseif {
				$controllers_conf(EXF2) && $timer_2_running && (
					$controllers_conf(T2OE) || $controllers_conf(RCLK) ||
					$controllers_conf(TCLK) || $controllers_conf(CPRL2)
				)
			} then {
				return {43 EXF2}
			} else {
				return 0
			}
		}
		{PC}	{	;# Analog comparator
			if {!$controllers_conf(EC)}	{return 0}
			if {$controllers_conf(CF)}	{return {51 CF}}
		}
	}
	return 0
}

# >>> File inclusion guard
}
# <<< File inclusion guard

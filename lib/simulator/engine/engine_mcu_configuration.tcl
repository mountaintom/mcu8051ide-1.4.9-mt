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
if { ! [ info exists _ENGINE_MCU_CONFIGURATION_TCL ] } {
set _ENGINE_MCU_CONFIGURATION_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Part of simulator engine functionality.
#
# --------------------------------------------------------------------------
# MCU CONFIGURATION RELATED PROCEDURES
# --------------------------------------------------------------------------


## Increment program overall time
 # This function also manages watchdog and data EEPROM
 # @parm Int num - Number of instruction cycles
 # @return Bool - 1 == device reseted; 0 == normal
private method increment_program_time {num} {
	# Increment counter of instruction cycles
	incr overall_instructions $num
	incr run_statistics(2) $num

	# Increment overall time
	if {$controllers_conf(X2)} {
		set num [expr {$num / 2.0}]
	}
	set overall_time [expr {$overall_time + $num}]
	incr run_statistics(1) [expr {int($num * 12)}]
	if {$clock_kHz != 0 && $clock_kHz != {}} {
		incr run_statistics(0) [expr {int($num * (12000000.0 / $clock_kHz))}]
	}

	eeprom_controller $num
	return [watchdog_controller]
}

## Adjust configuration according to new value of the given bit
 # @parm Int addr - Bit address
 # @return void
private method evaluate_bit {addr} {
	if {$addr < 128} {
		if {$sync_ena} {
			$this Simulator_sync_reg [getRegOfBit $addr]
		}
	} else {
		evaluate_sfr [getRegOfBit $addr]
	}
}

## Evaluate list of interrupt priorities according to values of IP and IPH
 # @return void
private method evaluate_interrupt_priorities {} {
	# Determinate value of Interrupt Priority High register
	if {$feature_available(iph)} {
		set iph $sfr(183)
	} else {
		set iph 0
	}

	# Lists of priority flags
	set ip_0 {}
	set ip_1 {}
	set ip_2 {}
	set ip_3 {}

	# Lists of priority levels
	set pl_0 {}
	set pl_1 {}
	set pl_2 {}
	set pl_3 {}
	set ip 0

	# Determinate list of priority flags and priority levels in decremental order
	foreach key {PX0 PT0 PX1 PT1 PS PT2 PC} mask {1 2 4 8 16 32 64} {
		set ip 0
		if {[expr {$sfr(184) & $mask}]} {
			incr ip
		}
		if {[expr {$iph & $mask}]} {
			incr ip 2
		}
		switch -- $ip {
			0 {lappend ip_0 $key}
			1 {lappend ip_1 $key}
			2 {lappend ip_2 $key}
			3 {lappend ip_3 $key}
		}
		lappend pl_${ip} $ip
	}
	set controllers_conf(IP)	[concat $ip_3 $ip_2 $ip_1 $ip_0]
	set controllers_conf(IP_level)	[concat $pl_3 $pl_2 $pl_1 $pl_0]

	# Determinate list of interrupts flags and priority levels in decremental order
	set interrupt_pri_flg {}
	set interrupt_pri_num {}
	foreach flag $controllers_conf(IP) ip $controllers_conf(IP_level) {
		switch -- $flag {
			PS {
				if {$feature_available(uart)} {
					lappend interrupt_pri_flg RI TI
					lappend interrupt_pri_num $ip $ip
				}
				if {$feature_available(spi)} {
					lappend interrupt_pri_flg SPIF
					lappend interrupt_pri_num $ip
				}
			}
			PT2 {
				if {!$feature_available(t2)} {continue}
				lappend interrupt_pri_flg EXF2 TF2
				lappend interrupt_pri_num $ip $ip
			}
			PX0 {
				lappend interrupt_pri_flg IE0
				lappend interrupt_pri_num $ip
			}
			PT0 {
				lappend interrupt_pri_flg TF0
				lappend interrupt_pri_num $ip
			}
			PX1 {
				lappend interrupt_pri_flg IE1
				lappend interrupt_pri_num $ip
			}
			PT1 {
				lappend interrupt_pri_flg TF1
				lappend interrupt_pri_num $ip
			}
			PC {
				if {!$feature_available(acomparator)} {continue}
				lappend interrupt_pri_flg CF
				lappend interrupt_pri_num $ip
			}
		}
	}

	# Adjust interrup monitor
	if {$::GUI_AVAILABLE} {
		$this interrupt_monitor_intr_prior $interrupt_pri_flg
	}
}

## Adjust configuration according to new value of the given SFR
 # @parm Int addr	- Register address
 # @parm Bool sync=1	- Synchronize this SFR with external interface
 # @return void
private method evaluate_sfr {addr {sync 1}} {
	switch -- $addr {
		135	{	;# PCON		0x87
			set SMOD0_prev $controllers_conf(SMOD0)

			write_conf 135 {SMOD1 SMOD0 PWMEN POF GF1 GF0 PD IDL}

			if {$SMOD0_prev != $controllers_conf(SMOD0)} {
				$this simulator_gui_SMOD0_changed
			}
		}
		168	{	;# IE		0xA8
			write_conf 168 {EA EC ET2 ES ET1 EX1 ET0 EX0}

			# Inform interrupt monitor
			if {$::GUI_AVAILABLE} {
				$this interrupt_monitor_intr_ena_dis
			}
		}
		184	{	;# IP		0xB8
			evaluate_interrupt_priorities
		}
		152	{	;# SCON		0x98
			write_conf 152 {- SM1 SM2 REN TB8 RB8 TI RI}

			# Determinate SM0 and FE
			if {$controllers_conf(SMOD0)} {
				set controllers_conf(FE) [expr {($sfr(152) & 0x80) ? 1 : 0}]
			} else {
				set controllers_conf(SM0) [expr {($sfr(152) & 0x80) ? 1 : 0}]
			}

			# Determinate UART operating mode
			set UART_M_prev $controllers_conf(UART_M)
			set controllers_conf(UART_M) [expr {$controllers_conf(SM0) * 2 + $controllers_conf(SM1)}]
			if {$timer_0_running && $UART_M_prev != $controllers_conf(UART_M)} {
				$this simulator_invalid_uart_mode_change $pc $Line($pc)
				internal_shutdown
			}

			# Inform interrupt monitor
			if {$::GUI_AVAILABLE} {
				$this interrupt_monitor_intr_flags [simulator_get_active_intr_flags]
			}
		}
		136	{	;# TCON		0x88
			write_conf 136 {TF1 TR1 TF0 TR0 IE1 IT1 IE0 IT0}

			# Inform interrupt monitor
			if {$::GUI_AVAILABLE} {
				$this interrupt_monitor_intr_flags [simulator_get_active_intr_flags]
			}
		}
		137	{	;# TMOD		0x89
			write_conf 137 {GATE1 CT1 M11 M01 GATE0 CT0 M10 M00}

			set T0_MOD_prev $controllers_conf(T0_MOD)
			set T1_MOD_prev $controllers_conf(T1_MOD)

			set controllers_conf(T0_MOD) [expr {$controllers_conf(M10) * 2 + $controllers_conf(M00)}]
			set controllers_conf(T1_MOD) [expr {$controllers_conf(M11) * 2 + $controllers_conf(M01)}]

			# Manual: It is important to stop timer/counter before changing modes
			if {$timer_0_running && $T0_MOD_prev != $controllers_conf(T0_MOD)} {
				$this simulator_invalid_timer_mode_change 0 $pc $Line($pc)
				internal_shutdown
			}
			if {$timer_1_running && $T1_MOD_prev != $controllers_conf(T1_MOD)} {
				$this simulator_invalid_timer_mode_change 1 $pc $Line($pc)
				internal_shutdown
			}
		}
		208	{	;# PSW		0xD0
			set bank [expr {($sfr(208) & 24) >> 3}]
		}
		224	{	;# A		0xE0
			set count 0
			set mask 1
			for {set i 0} {$i < 8} {incr i} {
				if {$sfr(224) & $mask} {
					incr count
				}
				set mask [expr {$mask << 1}]
			}

			if {$count % 2} {
				setBit $symbol(P) 1
			} else {
				setBit $symbol(P) 0
			}
		}

		162	{	;# AUXR1	0xA2
			set DPS_org $controllers_conf(DPS)
			write_conf 162 {- - - - - - - DPS}

			# Switch visible dual DPTR
			if {!$feature_available(hddptr)} {
				if {$controllers_conf(DPS)} {
					set DPL {DP1L}
					set DPH {DP1H}
				} else {
					set DPL {DP0L}
					set DPH {DP0H}
				}

			# Switch hidden dual DPTR
			} elseif {$DPS_org != $controllers_conf(DPS)} {
				if {$DPS_org} {
					set hidden_DPTR1 [list $sfr($symbol(DP0L)) $sfr($symbol(DP0H))]
				} else {
					set hidden_DPTR0 [list $sfr($symbol(DP0L)) $sfr($symbol(DP0H))]
				}
				if {$controllers_conf(DPS)} {
					set sfr($symbol(DP0L)) [lindex $hidden_DPTR1 0]
					set sfr($symbol(DP0H)) [lindex $hidden_DPTR1 1]
				} else {
					set sfr($symbol(DP0L)) [lindex $hidden_DPTR0 0]
					set sfr($symbol(DP0H)) [lindex $hidden_DPTR0 1]
				}
				if {$sync_ena} {
					$this Simulator_GUI_sync S $symbol(DP0L)
					$this Simulator_GUI_sync S $symbol(DP0H)
				}
				if {${::Simulator::reverse_run_steps}} {
					stepback_reg_change S $symbol(DP0L)
					stepback_reg_change S $symbol(DP0H)
				}
			}
		}
		142	{	;# AUXR		0x8E
			if {$feature_available(wdtcon)} {
				if {$feature_available(intelpe)} {
					write_conf 142 {- - - - - - IPE DISALE}
				} else {
					write_conf 142 {- - - - - - EXTRAM DISALE}
				}
			} else {
				write_conf 142 {- - - WDIDLE DISRTO - EXTRAM DISALE}
			}
		}
		166	{	;# WDTRST	0xA6
			if {$controllers_conf(HWDT)} {
				if {$sfr(166) == 225 && $wdtrst_prev_val == 30} {
					set controllers_conf(WatchDogTimer) 1
					set watchdog_value -$time

					if {$feature_available(wdtcon)} {
						set controllers_conf(WDTEN) 1
						set sfr(167) [expr {$sfr(167) | 1}]
						if {${::Simulator::reverse_run_steps}} {
							stepback_reg_change S 167
						}
						if {$sync_ena} {
							$this Simulator_GUI_sync S 167
						}
					}
				}
				set wdtrst_prev_val $sfr(166)
			}
		}
		200	{	;# T2CON	0xC8
			write_conf 200 {TF2 EXF2 RCLK TCLK EXEN2 TR2 CT2 CPRL2}

			# Inform interrupt monitor
			if {$::GUI_AVAILABLE} {
				$this interrupt_monitor_intr_flags [simulator_get_active_intr_flags]
			}
		}
		201	{	;# T2MOD	0xC9
			write_conf 201 {- - - - - - T2OE DCEN}
		}
		143	{	;# CLKREG/CKCON	0x8F
			write_conf 143 {- - - - - - PWDEX X2}
		}
		151	{	;# ACSR		0x97
			write_conf 151 {- - - CF CEN CM2 CM1 CM0}

			set controllers_conf(AC_MOD) [expr {
				$controllers_conf(CM0) * 1 +
				$controllers_conf(CM1) * 2 +
				$controllers_conf(CM2) * 4
			}]

			# Inform interrupt monitor
			if {$::GUI_AVAILABLE} {
				$this interrupt_monitor_intr_flags [simulator_get_active_intr_flags]
			}
		}
		183	{	;# IPH		0xB7
			evaluate_interrupt_priorities
		}
		213	{	;# SPCR		0xD5
			write_conf 213 {SPIE SPE DORD MSTR CPOL CPHA SPR1 SPR0}
		}
		170	{	;# SPSR		0xAA
			write_conf 170 {SPIF WCOL LDEN - - - DISSO ENH}

			# Inform interrupt monitor
			if {$::GUI_AVAILABLE} {
				$this interrupt_monitor_intr_flags [simulator_get_active_intr_flags]
			}
		}
		167	{	;# WDTCON/WDTPRG 0xA7
			if {$feature_available(wdtprg)} {
				write_conf 167 {- - - - - PS2 PS1 PS0}
			} else {
				write_conf 167 {PS2 PS1 PS0 WDIDLE DISRTO HWDT WSWRST WDTEN}
			}
			set controllers_conf(WatchDogPrescaler) 0
			if {$controllers_conf(PS2)} {
				incr controllers_conf(WatchDogPrescaler) 4
			}
			if {$controllers_conf(PS1)} {
				incr controllers_conf(WatchDogPrescaler) 2
			}
			if {$controllers_conf(PS0)} {
				incr controllers_conf(WatchDogPrescaler) 1
			}
			set controllers_conf(WatchDogPrescaler)		\
				[expr {int(pow(2,$controllers_conf(WatchDogPrescaler)))}]
		}
		150	{	;# EECON	0x96
			set bit_RDYBSY $controllers_conf(RDYBSY)
			set bit_WRTINH $controllers_conf(WRTINH)

			write_conf 150 {- - EELD EEMWE EEMEN DPS RDYBSY WRTINH}

			# Bits RDYBSY and WRTINH are READ-ONLY
			if {
				$controllers_conf(RDYBSY) != $bit_RDYBSY
					||
				$controllers_conf(WRTINH) != $bit_WRTINH
			} then {
				set sfr(150) [expr {(($sfr(150) & 0xFC) | $bit_RDYBSY * 2) | $bit_WRTINH}]
			}
			set controllers_conf(RDYBSY) $bit_RDYBSY
			set controllers_conf(WRTINH) $bit_WRTINH

			if {$controllers_conf(DPS)} {
				set DPL {DP1L}
				set DPH {DP1H}
			} else {
				set DPL {DP0L}
				set DPH {DP0H}
			}
		}
		default {	;# Nothing to do ...
		}
	}

	# Synchronize with an external interface
	if {$sync_ena && $sync != {0}} {
		$this Simulator_GUI_sync S $addr
	}
}

## Modify configuration
 # @parm Int addr	- Source register
 # @parm List key_list	- List of keys for array controllers_conf
 # @return void
private method write_conf {addr key_list} {
	set mask 256
	foreach key $key_list {

		set mask [expr {$mask >> 1}]
		if {$key == {-}} {continue}

		if {[expr {$sfr($addr) & $mask}] == 0} {
			set controllers_conf($key) 0
		} else {
			set controllers_conf($key) 1
		}
	}
}

## Increment program counter
 # @parm Int val - Value to increment by
 # @return void
private method incr_pc {val} {
	set pc [incr_16b $pc $val]
}

## Increment 16 bit value
 # @parm Int val	- Value to increment
 # @parm Int byVal	- Value to increment by
 # @return Int - 16 bit result
private method incr_16b {val byVal} {
	incr val $byVal
	if {$val > 65535} {
		incr val -65536
	} elseif {$val < 0} {
		incr val 65536
	}
	return $val
}

## Increment 8 bit value
 # @parm Char type	- D == Direct addressing; I == Indirect addressing
 # @parm Int addr	- Register to increment
 # @parm Int val	- Value to increment by
 # @return Bool - 0 == successful; 1 == failed
private method incr_8b {type addr val} {
	if {[check_address_validity $type $addr]} {return 1}

	# Indirect addressing
	if {$type == {I} || $addr < 128} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $addr
		}

		incr ram($addr) $val
		if {$ram($addr) > 255} {
			incr ram($addr) -256
		} elseif {$ram($addr) < 0} {
			incr ram($addr) 256
		}
		if {$sync_ena} {
			$this Simulator_sync_reg $addr
		}

	# Direct addressing
	} else {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change S $addr
		}

		incr sfr($addr) $val
		set val [read_sfr $addr]
		if {$val > 255} {
			incr sfr($addr) -256
		} elseif {$val < 0} {
			incr sfr($addr) 256
		}
		if {$sync_ena} {
			$this Simulator_GUI_sync S $addr
		}
	}
	return 0
}

## Pop value from stack
 # @return Int - result
private method stack_pop {} {
	if {[check_address_validity I $sfr(129)]} {
		set result [undefined_octet]
	} else {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $sfr(129)
		}
		set result $ram($sfr(129))	;# 129d == 0x81 == SP
	}
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 129
	}
	incr sfr(129) -1
	if {$sfr(129) < 0} {
		set sfr(129) 255
		if {!${::Simulator::ignore_stack_underflow}} {
			$this simulator_stack_warning under $pc [lindex $Line($pc) 0]
			internal_shutdown
		}
	}

	evaluate_sfr 129
	$this stack_monitor_pop

	return $result
}

## Push value onto stack
 # @parm Int - Value to push onto stack
 # @return void
public method stack_push {val} {
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 129
	}
	incr sfr(129)			;# 129d == 0x81 == SP
	if {$sfr(129) > 255} {
		set sfr(129) 0
		if {!${::Simulator::ignore_stack_overflow}} {
			$this simulator_stack_warning over $pc [lindex $Line($pc) 0]
			internal_shutdown
		}
	}
	if {[check_address_validity I $sfr(129)]} {
		return
	} else {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change I $sfr(129)
		}
		set ram($sfr(129)) $val
		if {$sync_ena} {
			$this Simulator_sync_reg $sfr(129)
		}
	}

	evaluate_sfr 129
	$this stack_monitor_push $sfr(129) $val
}

# >>> File inclusion guard
}
# <<< File inclusion guard

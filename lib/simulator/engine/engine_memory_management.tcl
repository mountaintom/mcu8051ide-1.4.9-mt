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
if { ! [ info exists _ENGINE_MEMORY_MANAGEMENT_TCL ] } {
set _ENGINE_MEMORY_MANAGEMENT_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Part of simulator engine functionality.
#
# --------------------------------------------------------------------------
# MEMORY MANAGEMENT RELATED PROCEDURES
# --------------------------------------------------------------------------

## Get value of the next operand
 # @return Int - OP code
private method getNextOperand {} {
	incr_pc 1
	incr run_statistics(4)
	if {[check_address_validity C $pc]} {
		set result [undefined_octet]

		bell
		$this sim_txt_output [mc "Incomplete instruction (undefined operand/value missing in memory) at 0x%s" [NumSystem::dec2hex $pc]]
		return [undefined_octet]
	} else {
		if {$code($pc) == {}} {
			$this sim_txt_output [mc "Incomplete instruction (undefined operand/value missing in memory) at 0x%s. Using 0FFh as operand !" [NumSystem::dec2hex $pc]]
			return 255
		} else {
			return $code($pc)
		}
	}
}

## Get value of the last operand
 # @return Int - OP code
private method getLastOperand {} {
	incr_pc 1
	incr run_statistics(4)
	if {[check_address_validity C $pc]} {
		bell
		$this sim_txt_output [mc "Incomplete instruction (undefined operand/value missing in memory) at 0x%s" [NumSystem::dec2hex $pc]]
		set result [undefined_octet]
	} else {
		if {$code($pc) == {}} {
			$this sim_txt_output [mc "Incomplete instruction (undefined operand/value missing in memory) at 0x%s. Using 0FFh as operand !" [NumSystem::dec2hex $pc]]
			set result 255
		} else {
			set result $code($pc)
		}
	}

	incr_pc 1
	return $result
}

## Get address of Rx register of current bank
 # @parm int idx - number of register [0;7]
 # @return int - address (decimal)
private method R {idx} {
	incr idx [expr {$bank * 8}]
	return $idx
}

## Set bit at address $addr to value of $value
 # @parm int addr	- bit address (decimal)
 # @parm bool value	- bit value
 # @return bool - 1: bit value changed; 0: nothing happened
public method setBit {addr value} {

	set regAddr [getRegOfBit $addr]
	set bitNumber [expr {$addr % 8}]

	if {${::Simulator::reverse_run_steps}} {
		if {$regAddr < 128} {
			stepback_reg_change I $regAddr
		} else {
			stepback_reg_change S $regAddr
		}
	}

	switch -- $bitNumber {
		7 {set mask 128}
		6 {set mask 64}
		5 {set mask 32}
		4 {set mask 16}
		3 {set mask 8}
		2 {set mask 4}
		1 {set mask 2}
		0 {set mask 1}
	}

	if {$regAddr < 0x80} {
		if {([expr {$ram($regAddr) & $mask}] > 0) && !$value} {
			set ram($regAddr) [expr {$ram($regAddr) ^ $mask}]
		} elseif {([expr {$ram($regAddr) & $mask}] == 0) && $value} {
			set ram($regAddr) [expr {$ram($regAddr) ^ $mask}]
		}
	} else {
		set sfr_val [read_sfr $regAddr]
		if {([expr {$sfr_val & $mask}] > 0) && !$value} {
			write_sfr $regAddr [expr {$sfr_val ^ $mask}]
		} elseif {([expr {$sfr_val & $mask}] == 0) && $value} {
			write_sfr $regAddr [expr {$sfr_val ^ $mask}]
		}
	}

	if {$regAddr > 127} {
		evaluate_sfr $regAddr
	} else {
		if {$sync_ena} {
			$this Simulator_sync_reg $regAddr
		}
	}
}

## Get bit value by bit address
 # @parm int addr - bit address (decimal)
 # @return bool
public method getBit {addr} {
	set regAddr [getRegOfBit $addr]
	set bitNumber [expr {$addr % 8}]

	return [getBitByReg $regAddr $bitNumber]
}

## Get bit value by register address and bit number
 # @attribite int regAddr	- register address (decimal)
 # @attrinte int bitNumber	- bit number (eg. 5)
 # @return bool
public method getBitByReg {regAddr bitNumber} {
	switch -- $bitNumber {
		7 {set mask 128}
		6 {set mask 64}
		5 {set mask 32}
		4 {set mask 16}
		3 {set mask 8}
		2 {set mask 4}
		1 {set mask 2}
		0 {set mask 1}
	}

	if {$regAddr < 0x80} {
		if {[expr {$ram($regAddr) & $mask}] == 0} {
			return 0
		} else {
			return 1
		}
	} else {
		if {[lsearch -ascii -exact $PORT_LATCHES $regAddr] != -1} {
			set byte [read_sfr $regAddr]
		} else {
			set byte $sfr($regAddr)
		}

		if {[expr {$byte & $mask}] == 0} {
			return 0
		} else {
			return 1
		}
	}
}

## Get address of register containing bit specified by argument
 # @parm int addr - bit address (decimal)
 # @return int - register address
public method getRegOfBit {addr} {
	set reg [expr {$addr / 8}]

	if {$addr > 127} {
		set reg [expr {$reg * 8}]
	} else {
		incr reg 32
	}

	return $reg
}

## Get current register bank
 # Thank you Kostya V. Ivanov !
 # @return Int - Bank (0..3)
public method getBank {} {
	return $bank
}

## Check if the specified address at the given location is implemented in this MCU
 # If check fail, this procedure will invoke error message and stop simulator
 # @parm Char location	- Memory type
 #	D == IDATA direct addressing
 #	I == IDATA indirect addressing (or operations on stack)
 #	X == XDATA
 #	B == Bit area
 #	C == CODE
 # @parm Int address	- Memory address (0..65536)
 # @return Bool - result (false == memory implemented; true == invalid access)
private method check_address_validity {location address} {
	if {$address_error} {return 1}

	if {[simulator_address_range $location $address]} {
		return 0
	}

	switch -- $location {
		{D} {	;# IDATA direct addressing
			if {${::Simulator::ignore_invalid_IDATA}} {
				return 1
			}
		}
		{I} {	;# IDATA indirect addressing (or operations with stack)
			if {${::Simulator::ignore_invalid_IDATA}} {
				return 1
			}
		}
		{X} {	;# XDATA
			if {${::Simulator::ignore_invalid_XDATA}} {
				return 1
			}
		}
		{B} {	;# Bit area
			if {${::Simulator::ignore_invalid_BIT}} {
				return 1
			}
		}
		{C} {	;# CODE
			if {${::Simulator::ignore_invalid_CODE}} {
				return 1
			}
		}
	}

	internal_shutdown
	if {$::GUI_AVAILABLE} {
		$this invalid_addressing_dialog $location $address
	}
	set address_error 1
	return 1
}

## Check if the specified address at the given location is implemented in this MCU
 # @parm Char location	- Memory type
 #	D == IDATA direct addressing or SFR
 #	S == SFR only
 #	I == IDATA indirect addressing (or operations on stack)
 #	B == Bit area
 #	J == Special Function Bits only
 #	X == XDATA
 #	C == CODE
 #	E == ERAM
 #	P == Data EEPROM
 # @parm Int address	- Memory address (0..65536)
 # @return Bool - result (true == memory implemented; false == invalid access)
public method simulator_address_range {location address} {
	switch -- $location {
		{D} {	;# IDATA direct addressing or SFR
			if {$address < 128 && $address < $iram_size} {
				return 1
			}
			if {[lsearch $available_sfr $address] != -1} {
				return 1
			}
		}
		{S} {	;# SFR only
			if {[lsearch $available_sfr $address] != -1} {
				return 1
			}
		}
		{I} {	;# IDATA indirect addressing (or operations with stack)
			if {$address < $iram_size} {
				return 1
			}
		}
		{B} {	;# Bit area
			if {[lsearch $restricted_bits $address] != -1} {
				return 0
			}
			set reg_addr [getRegOfBit $address]
			if {$reg_addr < 128 && $reg_addr < $iram_size} {
				return 1
			}
			if {[lsearch $available_sfr $reg_addr] != -1} {
				return 1
			}
		}
		{J} {	;# Special Function Bits only
			if {[lsearch $restricted_bits $address] != -1} {
				return 0
			}
			if {[lsearch $available_sfr [getRegOfBit $address]] != -1} {
				return 1
			}
		}
		{X} {	;# XDATA
			if {$address < $xram_size} {
				return 1
			}
		}
		{C} {	;# CODE
			if {$address < $code_size} {
				return 1
			}
		}
		{P} {	;# Data EEPROM
			if {$address < $eeprom_size} {
				return 1
			}
		}
		{E} {	;# ERAM
			if {$address < $eram_size} {
				return 1
			}
		}
	}
	return 0
}

## Write value to SFR
 # - It does not check address validity !
 # - Purpose is to write zero to unimplemented bits and handle special funtions
 #   triggered by write to specific SFR
 # @parm Int addr	- Target address (128..255)
 # @parm Int value	- New value (0.255)
 # @return void
private method write_sfr {addr value} {
	# Write to SBUF -- Set SBUF-T and begin UART transmission
	if {$addr == $symbol(SBUFR)} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change S $symbol(SBUFT)
		}
		set sfr($symbol(SBUFT)) $value

		uart_start_transmission

		return
	}

	# Make backup for register value
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S $addr
	}

	# Interrupts configuration related SFR -- skip next interrupt
	if {$addr == $symbol(IP) || $addr == $symbol(IE) || $addr == $symbol(IPH)} {
		set skip_interrupt 1
	} else {
		set skip_interrupt 0
	}

	# Write specified value into the SFR
	if {[lsearch $incomplete_regs $addr] == -1} {
		set sfr($addr) $value
	} else {
		set sfr($addr) [expr {$value & $incomplete_regs_mask($addr)}]
	}
}

## Read value from SFR
 # This function does not check for valid register address !
 # - Unimplemented bits are set to random values
 # @parm Int addr - Source address (128..255)
 # @return Int - Register value
private method read_sfr {addr} {
	# Port latch
	set port_number [lsearch -ascii -exact $PORT_LATCHES $addr]
	if {!$rmw_instruction && $port_number != -1 && [$this pale_is_enabled]} {
		set result [$this pale_RRPV $port_number]

	# Write only register
	} elseif {[lsearch $write_only_regs $addr] != -1} {
		if {!${::Simulator::ignore_read_from_wr_only}} {
			$this simulator_reading_wr_only $addr $pc [lindex $Line($pc) 0]
			internal_shutdown
		}
		return [undefined_octet]

	# Fully implemeneted register
	} elseif {[lsearch $incomplete_regs $addr] == -1} {
		return $sfr($addr)

	# Partialy implemented register
	} else {
		return [expr {
			($incomplete_regs_mask($addr) & $sfr($addr))
				+
			(($incomplete_regs_mask($addr) ^ 0x0FF) & [undefined_octet])
		}]
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

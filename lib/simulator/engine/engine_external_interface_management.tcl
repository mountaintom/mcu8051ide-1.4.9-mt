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
if { ! [ info exists _ENGINE_EXTERNAL_INTERFACE_MANAGEMENT_TCL ] } {
set _ENGINE_EXTERNAL_INTERFACE_MANAGEMENT_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Part of simulator engine functionality.
#
# --------------------------------------------------------------------------
# EXTERNAL INTERFACE MANAGEMENT PROCEDURES
# --------------------------------------------------------------------------

## Get value of bit X2 in CLKREG/CKCON if available
 # @return Bool - X2 value (if unavailable then 0)
public method get_X2 {} {
	return $controllers_conf(X2)
}

## Get value of bit SMOD0 in PCON if available
 # @return Bool - SMOD0 value (if unavailable then 0)
public method get_SMOD0 {} {
	return $controllers_conf(SMOD0)
}

## Set value of bit FE in SCON if available
 # @param Bool value - New value for SCON.FE (or SCON.SM0 if FE is not available)
 # @return void
public method sim_engine_set_FE {value} {
	if {$feature_available(smod0)} {
		set controllers_conf(FE) $value
	} else {
		sim_engine_set_SM0 $value
	}
}

## Set value of bit SM0 in SCON
 # @param Bool value - New value for PCON.SM0
 # @return void
public method sim_engine_set_SM0 {value} {
	set controllers_conf(SM0) $value
}

## Get value of bit FE in SCON if available
 # @return Bool - FE value (if unavailable then {})
public method sim_engine_get_FE {} {
	if {!$feature_available(smod0)} {
		return {}
	} else {
		return $controllers_conf(FE)
	}
}

## Get value of bit SM0 in SCON
 # @return Bool - SM0 value
public method sim_engine_get_SM0 {} {
	return $controllers_conf(SM0)
}

## Get program run statistics
 # @parm Int idx = {} - Index to the array ``run_statistics'', empty string means entire array
 # @return List/Int - Array run_statistics converted to list or Int
public method get_run_statistics {{idx {}}} {
	if {$idx == {}} {
		return [array get run_statistics]
	} else {
		return $run_statistics($idx)
	}
}

## Retrieve filename from list of files from which this program has been compiled
 # @return String - Resulting relative filename or {}
public method simulator_get_filename {filenumber} {
	return [lindex $list_of_filenames $filenumber]
}

## Get list of files defined in debug file
 # @return List - List of files
public method simulator_get_list_of_filenames {} {
	return $list_of_filenames
}

## Retrieve file number from list of files from which this program has been compiled
 # @return Int - Resulting file number or -1
public method simulator_get_filenumber {filename} {
	return [lsearch -exact -ascii $list_of_filenames $filename]
}

## Get maximum valid interrupt priority level
 # @return Int - 0..3
public method simulator_get_max_intr_priority {} {
	if {$feature_available(iph)} {
		return 3
	} else {
		return 1
	}
}

## Get current interrupt priority for certain interrupt
 # @parm String flag - Interrupt flag (e.g. TF2)
 # @return Int - 0..3
public method simulator_get_interrupt_priority {flag} {
	return [lindex $interrupt_pri_num [lsearch $interrupt_pri_flg $flag]]
}

## Invoke certain interrupt (from user interface)
 # @parm String flag - Interrupt flag (e.g. CF)
 # @return void
public method simulator_invoke_interrupt {flag} {
	if {[lsearch $inter_in_p_flags $flag] != -1} {
		return
	}

	switch -- $flag {
		{IE0}	{set name PX0}
		{TF0}	{set name PT0}
		{IE1}	{set name PX1}
		{TF1}	{set name PT1}
		{TF2}	{set name PT2}
		{EXF2}	{set name PT2}
		{SPIF}	{set name PS}
		{TI}	{set name PS}
		{RI}	{set name PS}
		{CF}	{set name PC}
	}
	interrupt_handler $name [intr2vector $name] $flag 1
	$this interrupt_monitor_intr $flag
}

## Increment interrupt priority for certain interrupt
 # @parm String flag - Interrupt flag (e.g. CF)
 # @return void
public method simulator_incr_intr_priority {flag} {
	set level [simulator_get_interrupt_priority $flag]
	if {[simulator_get_max_intr_priority] <= $level} {
		return
	}
	incr level
	set_interrupt_priority_flag $flag $level
}

## Decrement interrupt priority for certain interrupt
 # @parm String flag - Interrupt flag (e.g. IE0)
 # @return void
public method simulator_decr_intr_priority {flag} {
	set level [simulator_get_interrupt_priority $flag]
	if {!$level} {
		return
	}
	incr level -1
	set_interrupt_priority_flag $flag $level
}

## Set interrupt priority for certain interrupt
 # Auxiliary procedure for procedures:
 #	"simulator_incr_intr_priority"
 #	"simulator_decr_intr_priority"
 # @parm String flag	- Interrupt flag (e.g. RI)
 # @parm Int level	- New priority level (0..3)
 # @return void
private method set_interrupt_priority_flag {flag level} {
	# IP: - PC PT2 PS | PT1 PX1 PT0 PX0
	switch -- $flag {
		IE0	{set bit_mask 1}
		TF0	{set bit_mask 2}
		IE1	{set bit_mask 4}
		TF1	{set bit_mask 8}
		TI	{set bit_mask 16}
		RI	{set bit_mask 16}
		SPIF	{set bit_mask 16}
		TF2	{set bit_mask 32}
		EXF2	{set bit_mask 32}
		CF	{set bit_mask 64}
		default {
			return
		}
	}

	# Adjust register IPH
	if {$feature_available(iph)} {
		if {${::Simulator::reverse_run_steps}} {
			stepback_reg_change S $symbol(IPH)
		}

		# Set priority bit
		if {$level / 2} {
			set sfr($symbol(IPH)) [expr $sfr($symbol(IPH)) | $bit_mask]
		# Clear priority bit
		} else {
			set sfr($symbol(IPH)) [expr $sfr($symbol(IPH)) & ($bit_mask ^ 255)]
		}

		# Adjust internal engine configuration
		evaluate_sfr $symbol(IPH)
	}

	## Adjust register IP
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S $symbol(IP)
	}
	 # Set priority bit
	if {$level % 2} {
		set sfr($symbol(IP)) [expr $sfr($symbol(IP)) | $bit_mask]
	 # Clear priority bit
	} else {
		set sfr($symbol(IP)) [expr $sfr($symbol(IP)) & ($bit_mask ^ 255)]
	}
	 # Adjust internal engine configuration
	evaluate_sfr $symbol(IP)
}

## Clear certain interrupt flag
 # @parm String flag - Interrupt flag (e.g. RI)
 # @return void
public method simulator_clear_intr_flag {flag} {
	# Determinate register address and mask
	switch -- $flag {
		IE0 {
			set addr 0x88	;# TCON
			set mask 0xFD	;# 0x02
		}
		IE1 {
			set addr 0x88	;# TCON
			set mask 0xF7	;# 0x20
		}
		TF0 {
			set addr 0x88	;# TCON
			set mask 0xDF	;# 0x08
		}
		TF1 {
			set addr 0x88	;# TCON
			set mask 0x7F	;# 0x80
		}
		TI {
			set addr 0x98	;# SCON
			set mask 0xFD	;# 0x02
		}
		RI {
			set addr 0x98	;# SCON
			set mask 0xFE	;# 0x01
		}
		SPIF {
			set addr 0xAA	;# SPCR
			set mask 0x7F	;# 0x80
		}
		TF2 {
			set addr 0xC8	;# T2CON
			set mask 0x7F	;# 0x8F
		}
		EXF2 {
			set addr 0xC8	;# T2CON
			set mask 0xBF	;# 0x40
		}
		CF {
			set addr 0x97	;# ACSR
			set mask 0xEF	;# 0x10
		}
		default {
			return
		}
	}

	# Adjust register which contains the specified flag
	set addr [expr "$addr"]
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S $addr
	}
	set sfr($addr) [expr {$sfr($addr) & $mask}]

	# Adjust internal engine configuration
	evaluate_sfr $addr

	if {$::GUI_AVAILABLE} {
		$this interrupt_monitor_intr_flags [simulator_get_active_intr_flags]
	}
}

## Force return from certain interrupt
 # @parm String flag - Interrupt flag (e.g. RI)
 # @return void
public method simulator_cancel_interrupt {flag} {
	set index [lsearch $inter_in_p_flags $flag]
	if {$index == -1} {
		return
	}
	set last [llength $inter_in_p_flags]
	incr last -1

	$this interrupt_monitor_reti	[lindex $inter_in_p_flags $index]
	set interrupts_in_progress	[lreplace $interrupts_in_progress $index $index]
	set inter_in_p_flags		[lreplace $inter_in_p_flags $index $index]

	if {$last != $index} {return}

	incr run_statistics(8)
	$this subprograms_return 1
	if {$::GUI_AVAILABLE} {
		if {[llength $interrupts_in_progress]} {
			set vector [format %X [intr2vector [lindex $interrupts_in_progress end]]]
			simulator_Sbar [mc "Interrupt at vector 0x%s  " $vector] 1 $this
		} else {
			simulator_Sbar {} 0 $this
		}
	}

	set pch [stack_pop]
	set pcl [stack_pop]

	set pc [expr {($pch << 8) + $pcl}]
	$this move_simulator_line $Line($pc)
}

## Get list of interrupt flags which are set
 # @return List - List of active interrupt flags (e.g. {TF0 CF})
public method simulator_get_active_intr_flags {} {
	set result {}
	foreach flag {IE0 TF0 IE1 TF1 TI RI SPIF TF2 EXF2 CF} {
		if {$controllers_conf($flag)} {
			lappend result $flag
		}
	}
	return $result
}

## Get arguments for function "interrupt_monitor_intr_prior"
 # Get list of possible interrupt flags in order of their priorities
 # @return List - Interrupt flags in order of their priorities (decremental)
public method simulator_get_intr_flags_with_priorities {} {
	return $interrupt_pri_flg
}

## Get list of interrupt flags of interrupts which are in progress
 # @return List - Interrupt flags
public method simulator_get_interrupts_in_progress {} {
	return $inter_in_p_flags
}

## Return list of interrupt priority bits of these intrerrupts which are currently in progress
 # @return List - Priority bits
public method simulator_get_interrupts_in_progress_pb {} {
	return $interrupts_in_progress
}

## Get list of possible interrupt flags on this MCU
 # @return List - Something like {IE0 TF0 IE1 TF1 RI TI CF}
public method simulator_get_intr_flags {} {
	set result {IE0 TF0 IE1 TF1}
	if {$feature_available(uart)}		{lappend result RI TI}
	if {$feature_available(spi)}		{lappend result SPIF}
	if {$feature_available(t2)}		{lappend result TF2 EXF2}
	if {$feature_available(acomparator)}	{lappend result CF}
	return $result
}

## Get list of addresses in data EEPROM which are beeing written
 # @return List - {dec_addr0 dec_addr1 ...}
public method simulator_get_eeprom_beeing_written {} {
	set result {}
	foreach reg $eeprom_prev {
		lappend result [lindex $reg 0]
	}
	return $result
}

## Cancel data EEPROM write cycle
 # @return void
public method simulator_cancel_write_to_eeprom {} {
	if {!$eeprom_size || !$eeprom_WR} {return}

	foreach reg $eeprom_prev {
		set addr [lindex $reg 0]
		stepback_reg_change P $addr
		set eeprom($addr) [lindex $reg 1]
		::X::sync_eeprom_mem_window [format %X $addr] 0 $this
	}
	simulator_finalize_write_to_eeprom
}

## Finalize EEPROM write cycle
 # @return void
public method simulator_finalize_write_to_eeprom {} {
	if {!$eeprom_size || !$eeprom_WR} {return}

	# Clear background highlight in EEPROM hex editor
	foreach reg $eeprom_prev {
		::X::sync_eeprom_clear_bg_hg [lindex $reg 0] $this
	}

	# Adjust engine configuration
	if {$::GUI_AVAILABLE} {
		$this simulator_GUI_cancel_write_to_eeprom
	}
	set eeprom_WR		0
	set eeprom_WR_time	0
	set eeprom_WR_ofs	{}
	set eeprom_prev		{}

	# Set flag EECON.RDYBSY (EEPROM is ready)
	$this sim_GUI_bit_set_clear 1 EECON RDYBSY
	if {${::Simulator::reverse_run_steps}} {
		stepback_reg_change S 150
	}
	set sfr(150) [expr {$sfr(150) | 2}]
	set controllers_conf(RDYBSY) 1
	if {$sync_ena} {
		$this Simulator_GUI_sync S 150
	}
}

## Try to translate line number to address in CODE
 # @parm Int line - Line number (in source code)
 # @parm Int file - File number
 # @return Int	- Address in program memory or {} on fail
public method simulator_line2address {line file} {
	if {$line == {}} {
		return {}
	}
	set line [expr $line]
	if {[llength [array names line2PC -exact "$line,$file"]]} {
		return $line2PC($line,$file)
	} else {
		return {}
	}
}

## Determinate list of all unreachable breakpoints in the code
 # @return List - { { file_number line_number } ... }
public method simulator_getInvalidBreakpoints {} {
	# Local variables
	set ln		0	;# Int: Line number
	set fn		0	;# Int: File number
	set idx		0	;# Index in list of breakpoints

	set list_of_breakpoints [list]
	foreach {f b} [array get breakpoints] {
		foreach l $b {
			lappend list_of_breakpoints [list $f $l]
		}
	}

	foreach ln_fn [array names line2PC] {
		scan $ln_fn {%d,%d} ln fn

		set idx [lsearch -ascii -exact $list_of_breakpoints [list $fn $ln]]

		if {$idx != -1} {
			set list_of_breakpoints [lreplace $list_of_breakpoints $idx $idx]
		}
	}

	set list_of_breakpoints [lsort -integer -index 0 $list_of_breakpoints]
	set list_of_breakpoints [lsort -integer -index 1 $list_of_breakpoints]
	return $list_of_breakpoints
}

## Set watchdog timer value
 # This procedure does nothing on MCUs without watchdog timer
 # @parm Int value - new value (0..8192)
 # @return void
public method simulator_setWatchDogTimer {value} {
	if {!$feature_available(wtd)} {return}
	set watchdog_value $value
}

## Get value of watchdog timer
 # @return Int - Current value of watchdog timer 0..8192
public method simulator_getWatchDogTimerValue {} {
	return $watchdog_value
}

	## Get size of watch dog prescaler (0 - 128)
	 # @return Int - Maximum value - 1
public method simulator_getWatchDogPrescalerSize {} {
	return $controllers_conf(WatchDogPrescaler)
}

## Get current value of watchdog prescaler
 # @return Int - Prescaler content
public method simulator_getWatchDogPrescalerValue {} {
	return $wdt_prescaler_val
}

## Set value of watchdog prescaler
 # @parm Int value - New prescaler value
 # @return void
public method simulator_setWatchDogPrescalerValue {value} {
	set wdt_prescaler_val $value
}

## Start/Stop watchdog timer
 # This procedure does nothing on MCUs without watchdog timer
 # @parm Bool bool - 0 == STOP; 1 == START
 # @return void
public method simulator_startStopWatchDogTimer {bool} {
	if {!$feature_available(wtd)} {return}
	set controllers_conf(WatchDogTimer) $bool
}

## Determinate wheather watchdog timer is running or not
 # @return Bool - 1 == RUNNING; 0 == STOPPED
public method simulator_isWatchDogTimerRuning {} {
	return $controllers_conf(WatchDogTimer)
}

## Perform subprogram call
 # @parm Int value - Subprogram vector
 # @return void
public method simulator_subprog_call {value} {
	stack_push [expr {$value & 0xFF}]
	stack_push [expr {($value & 0xFF00) >> 8}]
	incr run_statistics(6)
	$this subprograms_call 3 $pc $value
	if {$::GUI_AVAILABLE} {
		$this stack_monitor_set_last_values_as 1 2
		$this stopwatch_refresh
	}
	set pc $value
}

## Set value of Program Couter (PC)
 # @parm Int value - new value
 # @return void
public method setPC {value} {
	set pc $value
}

## Get current value of Program Couter (PC)
 # @return Int - PC value
public method getPC {} {
	return $pc
}

## Get information about current line
 # @return List - {line_number file_number level block}
public method simulator_getCurrentLine {} {
	return $Line($pc)
}

## Get current line number only
 # @return Int - Line number
public method simulator_get_line_number {} {
	return [lindex $Line($pc) 0]
}

## Translate address in program memory to line info
 # @parm Int addr - Address to translate
 # @return List - Line information list
public method simulator_address2line {addr} {
	return $Line($addr)
}

## Change content of internal data memory
 # @parm Int addr	- Register address (decimal)
 # @parm String val	- New value (hexadecimal) or {} (means '0')
 # @return void
public method setData {addr val} {
	if {$val == {}} {
		set val 0
	}
	set ram($addr) [expr "0x$val"]
}

## Change content of internal data memory
 # @parm Int addr	- Register address (decimal)
 # @parm String val	- New value (decimal) or {} (means '0')
 # @return void
public method setDataDEC {addr val} {
	if {$val == {}} {
		set val 0
	}
	set ram($addr) $val
}

## Change content of register in SFR area
 # @parm Int addr	- Register address (decimal)
 # @parm String val	- New value (hexadecimal) or {} (means '0')
 # @return void
public method setSfr {addr val} {
	# Empty value == zero
	if {$val == {}} {
		set val 0
	}

	# Set value
	set foo $stepback_ena
	set stepback_ena 0
	switch -- $addr {
		153 {	;# SBUF R
			set sfr(153) [expr "0x$val"]
		}
		default {
			write_sfr $addr [expr "0x$val"]
		}
	}

	# Take care of read-only bits
	switch -- $addr {
		{150} {	;# EECON
			if {$sfr(150) & 1} {
				set controllers_conf(WRTINH) 1
			} else {
				set controllers_conf(WRTINH) 0
			}
		}
	}

	# Adjust internal engine configuration
	evaluate_sfr $addr 0
	set stepback_ena $foo

	# If address points to Primary Accumulator (Acc) -> reevaluate PSW
	if {$addr == 224} {
		$this Simulator_GUI_sync S 208
	}
}

## Change content of register in SFR area directly
 # @parm Int addr	- Register address (decimal)
 # @parm String val	- New value (decimal)
 # @return void
public method setSfr_directly {addr val} {
	set sfr($addr) $val
}

## Change content of external data memory
 # @parm Int addr	- Register address (decimal)
 # @parm String val	- New value (hexadecimal) or {} (means '0')
 # @return void
public method setXdata {addr val} {
	if {$val == {}} {
		set val 0
	}
	set xram($addr) [expr "0x$val"]
}

## Change content of expanded data memory
 # @parm Int addr	- Register address (decimal)
 # @parm String val	- New value (hexadecimal) or {} (means '0')
 # @return void
public method setEram {addr val} {
	if {$val == {}} {
		set val 0
	}
	set eram($addr) [expr "0x$val"]
}

## Change content of external data memory
 # @parm Int addr	- Register address (decimal)
 # @parm String val	- New value (decimal) or {} (means '0')
 # @return void
public method setXdataDEC {addr val} {
	if {$val == {}} {
		set val 0
	}
	set xram($addr) $val
}

## Change content of expanded data memory
 # @parm Int addr	- Register address (decimal)
 # @parm String val	- New value (decimal) or {} (means '0')
 # @return void
public method setEramDEC {addr val} {
	if {$val == {}} {
		set val 0
	}
	set eram($addr) $val
}

## Change content of the program memory
 # @parm Int addr	- Register address (decimal)
 # @parm String val	- New value (hexadecimal) or {}
 # @return void
public method setCode {addr val} {
	set code($addr) [expr "0x$val"]
}

## Change content of the program memory
 # @parm Int addr	- Register address (decimal)
 # @parm String val	- New value (decimal) or {}
 # @return void
public method setCodeDEC {addr val} {
	set code($addr) $val
}

## Get value (DEC) of some register in expanded data memory
 # @parm Int addr - register address
 # @return Int - register value
public method getEramDEC {addr} {
	return $eram($addr)
}

## Get value (HEX) of some register in expanded data memory
 # @parm Int addr - register address
 # @return String - register value (2 hexadecimal digits)
public method getEram {addr} {
	# Get hexadecimal value
	set result [format "%X" $eram($addr)]
	# Adjust the value
	if {[string length $result] == 1} {
		set result "0$result"
	}
	# Return the value
	return $result
}

## Get value (HEX) of some register in internal data memory
 # @parm Int addr - register address
 # @return String - register value (2 hexadecimal digits)
public method getData {addr} {
	# Get hexadecimal value
	set result [format "%X" $ram($addr)]
	# Adjust the value
	if {[string length $result] == 1} {
		set result "0$result"
	}
	# Return the value
	return $result
}

## Get value (HEX) of some register in SFR area
 # @parm Int addr - register address
 # @return String - register value (2 hexadecimal digits)
public method getSfr {addr} {

	# Get hexadecimal value
	set result [format "%X" $sfr($addr)]

	# Adjust the value
	if {[string length $result] == 1} {
		set result "0$result"
	}
	# Return the value
	return $result
}

## Get value (DEC) of some register in SFR area
 # @parm Int addr - register address
 # @return Int - register value
public method getSfrDEC {addr} {
	return $sfr($addr)
}

## Get value (DEC) of some register in SFR area
 # @parm Int addr - register address
 # @return Int - register value
public method getDataDEC {addr} {
	return $ram($addr)
}

## Get value (DEC) of some register in data EEPROM
 # @parm Int addr - register address
 # @return Int - register value
public method getEepromDEC {addr} {
	return $eeprom($addr)
}

## Get value (HEX) of some register in data EEPROM
 # @parm Int addr - register address
 # @return String - register value (2 hexadecimal digits)
public method getEeprom {addr} {
	# Get hexadecimal value
	set result [format "%X" $eeprom($addr)]
	# Adjust the value
	if {[string length $result] == 1} {
		set result "0$result"
	}
	# Return the value
	return $result
}

## Change content of external data memory
 # @parm Int addr	- Register address (decimal)
 # @parm String val	- New value (decimal) or {} (means '0')
 # @return void
public method setEepromDEC {addr val} {
	if {$val == {}} {
		set val 0
	}
	set eeprom($addr) $val
}

## Get value (HEX) of some register in external data memory
 # @parm Int addr - register address
 # @return String - register value (2 hexadecimal digits)
public method getXdata {addr} {
	# Get hexadecimal value
	set result [format "%X" $xram($addr)]
	# Adjust the value
	if {[string length $result] == 1} {
		set result "0$result"
	}
	# Return the value
	return $result
}

## Get value (DEC) of some register in external data memory
 # @parm Int addr - register address
 # @return Int - register value
public method getXdataDEC {addr} {
	return $xram($addr)
}

## Get value (HEX) of some register in the program memory
 # @parm Int addr - register address
 # @return String - register value (2 hexadecimal digits) or {}
public method getCode {addr} {
	# Get value (and return {} if it's {})
	if {![simulator_address_range C $addr] || $code($addr) == {}} {return {}}
	set result [format "%X" $code($addr)]
	# Normalize the value
	if {[string length $result] == 1} {
		set result "0$result"
	}
	# Return the value
	return $result
}

## Get value (DEC) of certain register in program memory
 # @parm Int addr - Register address
 # @return Int - Register value
public method getCodeDEC {addr} {
	if {![simulator_address_range C $addr]} {
		return {}
	}
	return $code($addr)
}

## Get value (DEC) of certain cell in data EEPROM write buffer
 # @parm Int addr - Cell address
 # @return Int - Register value
public method getEepromWrBufDEC {addr} {
	return $eeprom_WR_buff($addr)
}

## Set value (DEC) of certain cell in data EEPROM write buffer
 # @parm Int addr	- Cell address
 # @parm Int val	- New cell value
 # @return void
public method setEepromWrBufDEC {addr val} {
	set eeprom_WR_buff($addr) $val
}

## Set value (DEC) of EEPROM write buffer offset
 # @return Int - Offset (0..65535)
public method getEepromWrOffsetDEC {} {
	return $eeprom_WR_ofs
}

## Load program to virtual processor from ADF file (Assembler Debug File)
 # @parm File adf_file - ADF file ID (content of *.adf file)
 # @return void
public method load_program_from_adf {adf_file} {
	unload_program	;# Clear current content of the program memory

	set programming_language 0

	set firts_line 1
	set list_of_filenames [list]

	# Parse the program data
	while {![eof $adf_file]} {
		set line [gets $adf_file]

		# Skip empty lines and comments
		if {$line == {} || [regexp {^\s*#} $line]} {continue}

		# Take first line
		if {$firts_line} {
			set firts_line 0
			set project_dir [$this cget -projectPath]
			set len [llength $line]
			for {set i 1} {$i < $len} {incr i 2} {
				lappend list_of_filenames	\
					[file join $project_dir [lindex $line $i]]
			}
			continue
		}

		# Local variables
		set fileNum	[lindex $line 0]	;# File number
		set lineNum	[lindex $line 1]	;# Number of line in source code
		set addr	[lindex $line 2]	;# Code address
		set line	[lreplace $line 0 2]	;# List of codes (DEC)

		# Set address for translating from line number
		set line2PC($lineNum,$fileNum) $addr

		# Iterate over codes and save them
		foreach num $line {
			# Check for allowed address range
			if {$addr >= $code_size} {
				tk_messageBox		\
					-parent .	\
					-icon warning	\
					-type ok	\
					-title [mc "Out of memory"]	\
					-message [mc "%s has not enough program memory to load this program. Simulator will work but the loaded code is incomplete" [$this cget -P_option_mcu_type]]
				return 0
			}
			set Line($addr) [list $lineNum $fileNum 0 0]	;# Set line number
			set code($addr) $num				;# Set program code
			incr addr					;# Increment address
		}
	}
}

## Load program to virtual processor from CDB file
 # @parm File filename - Full name of source file from which SIM file was generaded
 # @parm File cdb_file - CDB file ID (content of *.cdb file)
 # @parm File ihx_file - HEX file ID (content of *.ihx or *.hex file)
 # @return Bool - 1 == Success; 0 == Failure
public method load_program_from_cdb {filename cdb_file ihx_file} {
	unload_program	;# Clear current content of the program memory

	set programming_language 1

	set lineNum		0
	set highest_addr	0
	set eof			0

	# Iterate over HEX records
	while {![eof $ihx_file]} {
		set line [gets $ihx_file]
		incr lineNum	;# Increment line number

		# Skip comments
		if {[string index $line 0] != {:}} {continue}

		# Check for valid charters
		if {![regexp {^:[0-9A-Fa-f]+$} $line]} {
			return 0
		}
		# Check for odd lenght
		set len [string length $line]
		if {[expr {$len % 2}] != 1} {
			return 0
		}

		# Analize HEX record
		set len		[ string range $line 1		2	] ;# Lenght field
		set addr	[ string range $line 3		6	] ;# Address field
		set type	[ string range $line 7		8	] ;# Type field
		set data	[ string range $line 9		{end-2}	] ;# Data field
		set check	[ string range $line {end-1}	end	] ;# Checksum field
		set line	[ string range $line 1		{end-2}	] ;# Record without ':' and checksum

		# Handle record type (01 == EOF; 00 == normal record)
		if {$type == {01}} {
			set eof 1
			break
		} elseif {$type != {00}} {
			return 0
		}

		# Check for valid checksum
		set new_check [::IHexTools::getCheckSum $line]
		if {$new_check != $check} {
			return 0
		}

		# Check for correct value of the length field
		set len [expr "0x$len"]
		if {([string length $data] / 2) != $len} {
			return 0
		}

		# Parse and load data field
		set addr [expr "0x$addr"]
		for {set i 0; set j 1} {$i < ($len * 2)} {incr i 2; incr j 2} {
			set code($addr) [expr "0x[string range $data $i $j]"]
			incr addr
		}

		# Store highest address
		if {$addr > $highest_addr} {
			set highest_addr $addr
		}
	}

	# If there is no EOF then report that as an error
	if {!$eof} {return 0}

	# Parse CDB file
	set list_of_filenames [list $filename]
	set filenumber		0
	set filename		{}
	set level		{}
	set block		{}
	while {![eof $cdb_file]} {
		set line [split [gets $cdb_file] {:$}]

		if {[lindex $line 0] != {L}} {continue}
		if {[lindex $line 1] != {C}} {continue}

		set filename	[lindex $line 2]
		set linenumber	[lindex $line 3]
		set level	[lindex $line 4]
		set block	[lindex $line 5]
		scan		[lindex $line 6] {%x} address

		set filename [file normalize [file join [$this cget -projectPath] $filename]]
		set filenumber [lsearch -exact -ascii $list_of_filenames $filename]
		if {$filenumber == -1} {
			set filenumber [llength $list_of_filenames]
			lappend list_of_filenames $filename
		}
		set Line($address) [list $linenumber $filenumber $level $block]
		set line2PC($linenumber,$filenumber) $address
	}
	return 1
}

## Get name of loaded CDB file (C language DeBug file) generated by SDCC
 # @return String - full filename
public method simulator_get_cdb_filename {} {
	set filename [lindex $list_of_filenames 0]
	set filename [file rootname $filename]
	return $filename.cdb
}

## Clear current content of the program memory
 # @return void
public method unload_program {} {
	array unset line2PC
	array unset breakpoints

	for {set i 0} {$i < $code_size} {incr i} {
		set code($i) {}
		set Line($i) {{} {} {} {}}
	}
	for {set i $code_size} {$i <= 0xFFFF} {incr i} {
		set Line($i) {}
	}
}

## Import list of breakpoints (e.g. '{0 0 0 1 0 0 1 1 0}')
 # @parm String full_filename	- Name of source code file
 # @parm List breakpoints_list	- list of breakpoints
 # @return void
public method Simulator_import_breakpoints {full_filename breakpoints_list} {
	set file_number [lsearch -exact -ascii $list_of_filenames $full_filename]
	set breakpoints($file_number) {}
	set line 0
	foreach bool $breakpoints_list {
		if {$bool == 1} {
			lappend breakpoints($file_number) $line
		}
		incr line
	}
}

## Set MCU clock
 # @parm Int clockkHz - clock frequency in kHz
 # @return void
public method setEngineClock {clockkHz} {
	set clock_kHz $clockkHz
}

## Get MCU clock frequency
 # @return - clock frequency in kHz
public method getEngineClock {} {
	return $clock_kHz
}

## Get program uptime as human readable string
 # @return String - the time (eg. '2 s  42 ms 987 us')
public method getTime {} {
	# Initial computations
	if {!$clock_kHz} {
		set s	0
		set ms	0
		set ns	0
	} else {
		set s	[expr {int($overall_time * (0.012 / $clock_kHz))}]
		set ms	[expr {int($overall_time * (12000.0 / $clock_kHz)) % 1000000}]
		set ns	[expr {int($overall_time * (12000000.0 / $clock_kHz)) % 1000}]
	}

	# Local variables
	set us [expr {($ms % 1000)}]	;# Number of microseconds
	set ms [expr {$ms / 1000}]	;# Number of miliseconds
	set s [expr {int($s)}]		;# Number of seconds
	set h [expr {$s / 3600}]	;# Number of hours
	set s [expr {$s % 3600}]
	set m [expr {$s / 60}]		;# Number of minutes
	set s [expr {$s % 60}]

	# Adjust length of nano-seconds string
	set len [string length $ns]
	if {$len < 3} {
		set ns_s "[string repeat {0} [expr {3 - $len}]]$ns"
	} else {
		set ns_s $ns
	}

	# Adjust length of micro-seconds string
	set len [string length $us]
	if {$len < 3} {
		set us_s "[string repeat { } [expr {3 - $len}]]$us"
	} else {
		set us_s $us
	}

	# Adjust length of mili-seconds string
	set len [string length $ms]
	if {$len < 3} {
		set ms_s "[string repeat { } [expr {3 - $len}]]$ms"
	} else {
		set ms_s $ms
	}

	# Adjust seconds and minutes strings
	if {[string length $s] == 1} {
		set s_s " $s"
	} else {
		set s_s $s
	}
	if {[string length $m] == 1} {
		set m_s " $m"
	} else {
		set m_s $m
	}

	# Initialize resulting string
	set result {}

	# Append hours
	if {$h > 0} {
		append result
	}
	# Append minutes
	if {$m > 0 || $result != {}} {
		append result " ${m_s}m"
	}
	# Append seconds
	if {$s > 0 || $result != {}} {
		append result " ${s_s}s"
	}
	# Append mili-seconds
	if {$ms > 0 || $result != {}} {
		append result " ${ms_s}ms"
	}
	# Append micro-seconds
	if {$us > 0 || $result != {}} {
		append result " ${us_s}.${ns_s}µs"
	}

	# Done ...
	return [string trim $result]
}

# >>> File inclusion guard
}
# <<< File inclusion guard

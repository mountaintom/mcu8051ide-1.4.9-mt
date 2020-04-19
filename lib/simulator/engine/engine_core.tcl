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
if { ! [ info exists _ENGINE_CORE_TCL ] } {
set _ENGINE_CORE_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements virtual 8051 processor. This class is a part 8051 simulator.
# But this file contains only simulator engine core.
#
# Class consist of the groups of procedures:
#	- Initialization & cleanup related procedures
#	- Control procedures
#	- External interface management procedures
#	- Virtual HW controller procedures
#	- Instruction procedures
#	- Opcode procedures
#	- Mcu configuration related procedures
#	- Auxiliary alo functions
#	- Memory management related procedures
#	- Backward stepping related procedures
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Somilator engine was modified & fixed by Kostya V. Ivanov <kostya@istcom.spb.ru>
#
# Special thanks to Kostya V. Ivanov !
# --------------------------------------------------------------------------

# Load hibernation facility
source "${::LIB_DIRNAME}/simulator/hibernate.tcl"

class Simulator_ENGINE {

	inherit Hibernate	;# Import hibernation facility

	## COMMON
	public common symbol		;# Array of SFR symbolic names (eg. $symbol(P0) == "80")
	public common PIN		;# Array describing pins with some special function
	public common PORT_LATCHES	;# List: Port latch registers
	public common GUI_UPDATE_INT 66;# Int: Time interval [ms] in which the GUI is regulary updated in the run mode

	# Default values for SFR (values to set after reset)
	public common reset_reg_values {
		{A	0}	{B	0}	{DP0L	0}	{DP0H	0}
		{IE	0}	{IP	0}	{PSW	0}	{TCON	0}
		{TMOD	0}	{TH0	0}	{TH1	0}	{TL0	0}
		{TL1	0}	{PCON	0}	{SP	7}
	}
	# Default values for special (uC dependend) SFR (values to set after reset)
	public common reset_reg_values_1 {
		{T2CON	0}	{T2MOD	0}	{RCAP2L	0}	{RCAP2H	0}
		{TL2	0}	{TH2	0}	{AUXR1	0}	{ACSR	0}
		{AUXR	0}	{P0	255}	{P1	255}	{P2	255}
		{P3	255}	{P4	255}	{SCON	0}	{DP1L	0}
		{DP1H	0}	{SADEN	0}	{SADDR	0}	{IPH	0}
		{CLKREG	0}	{WDTCON	0}	{EECON	3}	{SPCR	4}
		{SPSR	0}
	}

	## PUBLIC
	public variable programming_language	0	;# Int: ID of used programming language (0 == Assembler; 1 == C language)

	## PRIVATE
	private variable breakpoints			;# Array of Lists of breakpoints -- (eg '$breakpoints($file_number) == {1 45 399}')

	private variable ram				;# Array of internal RAM;	addr: 0..255;	val: 0..255
	private variable eram				;# Array of expanded RAM;	addr: 0..4096;	val: 0..255
	private variable sfr				;# Array of SFR;		addr: 128..255;	val: 0..255
	private variable xram				;# Array of external RAM;	addr: 0..65535;	val: 0..255
	private variable code				;# Array of program memory;	addr: 0..65535;	val: 0..255
	private variable eeprom 			;# Array of data EEPROM;	addr: 0..65535;	val: 0..255
	private variable iram_size			;# Capacity of internal data memory
	private variable eram_size			;# Capacity of expanded data memory
	private variable xram_size			;# Capacity of external data memory
	private variable code_size			;# Capacity of program memory
	private variable eeprom_size			;# Capacity of data EEPROM

	private variable eeprom_prev		{}	;# List: Previous values of EEPROM registers before write cycle ({{addr val} ...})
	private variable eeprom_WR_ofs		{}	;# Int: EEPROM write buffer offset (for EEPROM WB window only)
	private variable eeprom_WR_buff			;# List: Data EEPROM write buffer for page mode; addr: 0..31; val: 0..255
	private variable eeprom_WR		0	;# Bool: Data EEPROM write cycle in progress
	private variable eeprom_WR_time		0	;# Float: Time of EEPROM write cycle (micro-seconds)

	private variable Line				;# $Line($PC) == {line in source code} {filenumber} {level} {block}
	private variable list_of_filenames		;# List of filenames for [lindex $Line($pc) 1]
	private variable line2PC			;# $line2PC($line_number,$file_number) == PC
	private variable bank			0	;# Current register bank (0..3)
	private variable pc			0	;# Program counter
	private variable clock_kHz		0	;# MCU clock in kHz
	private variable time			0	;# Number of instruction cycles consumed by current instruction
	private variable sync_ena		0	;# Bool: Enabled synchronization with an external interface
	private variable address_error		0	;# Bool: Addressing error occurred

	private variable break			0	;# Bool: Immediately terminate the loaded program
	private variable simulation_in_progress 0	;# Bool: Engine is running
	private variable run_in_progress	0	;# Bool: Mode "Run" engaged
	private variable animation_in_progress	0	;# Bool: Mode "Animation" engaged
	private variable stepover_in_progress	0	;# Bool: Mode "Stepover" engaged
	private variable ports_previous_state	{}	;# List: {P0_hex P1_hex P2_hex P3_hex P4_hex}
	private variable rmw_instruction	0	;# Bool: This instruction is one of READ-MODIFY-WRITE ones

	private variable available_sfr		{}	;# List: Addresses of implemented SFR
	private variable feature_available		;# Array: available features
	private variable restricted_bits	{}	;# List: Decimal addresses of unimplemented bits
	private variable write_only_regs	{}	;# List: Decimal addresses of write only registers
	private variable incomplete_regs	{}	;# List: Decimal addresses of not fully implemented registers
	private variable incomplete_regs_mask		;# Array: key == dec. addr.; val == mask of implemented bits

	private variable DPL {DP0L}			;# Address of current DPL register (DTPR)
	private variable DPH {DP0H}			;# Address of current DPH register (DTPR)
	private variable hidden_DPTR0		{0 0}	;# Value of DPTR0 (if dual DPTR is hidden)
	private variable hidden_DPTR1		{0 0}	;# Value of DPTR1 (if dual DPTR is hidden)

	private variable watchdog_value		0	;# Int: Current value of watchdog timer (if available)
	private variable wdtrst_prev_val	0	;# Int: Previous value of register WDTRST
	private variable wdt_prescaler_val	0	;# Int: Watchdog prescaler value (content)

	private variable stepback_spec		{}	;# List: List of special values (for function stepback)
	private variable stepback_local		{}	;# List: The same as stepback_normal but only for 1 instruction
	private variable stepback_local_regs	{}	;# List: Register addresses recorded in stepback_local
	private variable stepback_ena		0	;# Bool: Enable stepback
	private variable stepback_length	0	;# Int: Length of stepback stack
	## List: List of changed memory registers (for function stepback)
	 # Format: {{{MEM_TYPE ADDRESS VALUE} ...} ...}
	 # MEM_TYPE	== E (Eram), X (XRAM), I (IRAM), S (SFR)
	 # ADDRESS	== Decimal address
	 # VALUE	== Decimal value
	private variable stepback_normal	{}

	private variable interrupts_in_progress	{}	;# List: Priority flags of interrupts which are in progress
	private variable inter_in_p_flags	{}	;# List: Interrupt flags of interrupts which are in progress
	private variable interrupt_on_next	0	;# Bool: Engage interrupt routine on the next instruction cycle
	private variable skip_interrupt		0	;# Bool: Last instruction was RETI or any access to the IE or IP
	private variable interrupt_pri_flg	{}	;# List: Interrupt flags in order of their priorities
	private variable interrupt_pri_num	{}	;# List: Interrup priorities levels in decremental order (by intr flags)

	private variable timer_0_running	0	;# Bool: Timer/Counter 0 engaged
	private variable timer_1_running	0	;# Bool: Timer/Counter 1 engaged
	private variable timer_2_running	0	;# Bool: Timer/Counter 2 engaged
	private variable pwm_running		0	;# Bool: PWM controller engaged (uses Timer/Counter 0 & 1)
	private variable pwm_OCR		0	;# Int: Content of OCR (8-bit data register)

	private variable anlcmp_running		0	;# Bool: Analog comparator is engaged
	private variable anlcmp_output		0	;# Bool: Output from Analog comparator
	private variable anlcpm_db_timer	0	;# Int: Analog comparator debounce timer

	private variable uart_clock_prescaler	0	;# Int: UART clock prescaler
	private variable timer1_overflow	0	;# Bool: Timer 1 overflow detected
	private variable timer2_overflow	0	;# Bool: Timer 2 overflow detected
	private variable uart_RX_clock		0	;# Int: UART 16-bit RX clock prescaler
	private variable uart_TX_clock		0	;# Int: UART 16-bit TX clock prescaler
	private variable uart_RX_in_progress	0	;# Bool: UART reception in progress
	private variable uart_TX_in_progress	0	;# Bool: UART transmission in progress
	private variable uart_RX_shift_reg	0	;# Int: UART reception receive register
	private variable uart_TX_shift_reg	0	;# Int: UART transmission receive register

	private variable controllers_conf		;# Array of various internal configuration flags
	private variable overall_time		0	;# Overall program time in 1/CLOCK seconds
	private variable overall_instructions	0	;# Counter of instruction cycles

	## Array of Int: Program run statistics
	 # IDX	- Meaning
	 # ---------------------------------
	 # 0	- Nano-seconds
	 # 1	- Clock cycles
	 # 2	- Instruction cycles
	 # 3	- Instructions passed
	 # 4	- Program bytes passed
	 # 5	- Interrupts invoked
	 # 6	- Subprogram calls
	 # 7	- Returns from subprogram
	 # 8	- Returns from interrupt
	 # 9	- Breakpoints reached
	private variable run_statistics

	# ----------------------------------------------------------------
	# INITIALIZATION & CLEANUP RELATED PROCEDURES
	# ----------------------------------------------------------------

	source "${::LIB_DIRNAME}/simulator/engine/engine_initialization_cleanup.tcl"


	# ----------------------------------------------------------------
	# CONTROL PROCEDURES
	# ----------------------------------------------------------------

	source "${::LIB_DIRNAME}/simulator/engine/engine_control.tcl"


	# ----------------------------------------------------------------
	# EXTERNAL INTERFACE MANAGEMENT PROCEDURES
	# ----------------------------------------------------------------

	source "${::LIB_DIRNAME}/simulator/engine/engine_external_interface_management.tcl"


	# ----------------------------------------------------------------
	# VIRTUAL HW CONTROLLER PROCEDURES
	# ----------------------------------------------------------------

	source "${::LIB_DIRNAME}/simulator/engine/engine_virtual_hw_controller.tcl"


	# ----------------------------------------------------------------
	# INSTRUCTION PROCEDURES
	# ----------------------------------------------------------------

	source "${::LIB_DIRNAME}/simulator/engine/engine_instructions.tcl"


	# ----------------------------------------------------------------
	# OPCODE PROCEDURES
	# ----------------------------------------------------------------

	source "${::LIB_DIRNAME}/simulator/engine/engine_opcodes.tcl"


	# ----------------------------------------------------------------
	# MCU CONFIGURATION RELATED PROCEDURES
	# ----------------------------------------------------------------

	source "${::LIB_DIRNAME}/simulator/engine/engine_mcu_configuration.tcl"


	# ----------------------------------------------------------------
	# AUXILIARY ALO FUNCTIONS
	# ----------------------------------------------------------------

	source "${::LIB_DIRNAME}/simulator/engine/engine_auxiliary_alo_functions.tcl"


	# ----------------------------------------------------------------
	# MEMORY MANAGEMENT RELATED PROCEDURES
	# ----------------------------------------------------------------

	source "${::LIB_DIRNAME}/simulator/engine/engine_memory_management.tcl"


	# ----------------------------------------------------------------
	# BACKWARD STEPPING RELATED PROCEDURES
	# ----------------------------------------------------------------

	source "${::LIB_DIRNAME}/simulator/engine/engine_backward_stepping.tcl"


	# ----------------------------------------------------------------
	# HIBERNATION RELATED PROCEDURES
	# ----------------------------------------------------------------

	source "${::LIB_DIRNAME}/simulator/engine/engine_hibernation.tcl"

}

# Initialize NS variables
Simulator_ENGINE::InitializeNS

# >>> File inclusion guard
}
# <<< File inclusion guard

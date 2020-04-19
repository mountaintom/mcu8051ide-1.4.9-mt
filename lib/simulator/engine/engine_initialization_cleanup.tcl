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
if { ! [ info exists _ENGINE_INITIALIZATION_CLEANUP_TCL ] } {
set _ENGINE_INITIALIZATION_CLEANUP_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Part of simulator engine functionality.
#
# --------------------------------------------------------------------------
# INITIALIZATION & CLEANUP RELATED PROCEDURES
# --------------------------------------------------------------------------


## Object constructor
constructor {} {
	# Initialize array of program run statistics
	for {set i 0} {$i < 10} {incr i} {
		set run_statistics($i) 0
	}

	# Initialize program memory debugging map
	for {set i 0} {$i <= 0xFFFF} {incr i} {
		set Line($i) {}
	}
}

## Object destructor
destructor {
	set break 1
}

## This procedure sets these SFR which are not affected by reset
 # This function is called after each simulator start
 # @return void
private method simulator_system_power_on {} {
	if {$feature_available(wtd)} {
		set sfr($symbol(WDTRST)) [undefined_octet]
		set wdtrst_prev_val $sfr($symbol(WDTRST))
		if {$sync_ena} {
			catch {$this Simulator_GUI_sync S 166}
		}
	}

	if {$feature_available(uart)} {
		set sfr($symbol(SBUFR)) [undefined_octet]
		set sfr($symbol(SBUFT)) [undefined_octet]
		set controllers_conf(UART_M) 0
		if {$sync_ena} {
			catch {$this Simulator_GUI_sync S 153}
			catch {$this Simulator_GUI_sync S 409}
		}
	}

	if {$feature_available(pof)} {
		set controllers_conf(POF) 1
		set sfr($symbol(PCON)) 16
		if {$sync_ena} {
			catch {$this Simulator_GUI_sync S 135}
		}
	}

	if {$feature_available(spi)} {
		set sfr($symbol(SPDR)) 0
		if {$sync_ena} {
			catch {$this Simulator_GUI_sync S $symbol(SPDR)}
		}
	}
}

## Initialize memory (this function must be called before using this class)
 # This function is called after constructor
 # @return void
public method simulator_initialize_mcu {} {
	# Get processor definition
	set proc_data [$this cget -procData]

	# Determinate capacities of uC memories
	set iram_size [lindex $proc_data 3]
	set eram_size [lindex $proc_data 8]
	set eeprom_size [lindex $proc_data 32]
	set xram_size [expr {int([$this cget -P_option_mcu_xdata])}]
	set code_size [expr {
		int(([lindex $proc_data 2] * 1024)
			+
		[$this cget -P_option_mcu_xcode])}]

	# Parse processor definition and set array feature_available
	foreach index	{
			5	6	7	9	10	11	17
			20	21	22	23	24	25	26
			27	28	29	30	31	33	34
			35	36	37		38	39	40
			41		42		0	1
		} name	{
			uart	t2	wtd	ddp	auxr	t2mod	pof
			gf1	gf0	pd	idl	smod0	iph	acomparator
			euart	clkreg	pwdex	spi	wdtcon	intelpe	pwm
			x2reset	ckcon	auxr1gf3	ao	wdtprg	hddptr
			auxrwdidle	auxrdisrto	xram	xcode
	} {
		if {[lindex $proc_data $index] == {yes}} {
			set feature_available($name) 1
		} else {
			set feature_available($name) 0
		}
	}
	for {set i 12; set j 0} {$i < 17} {incr i; incr j} {
		set port_mask [lindex $proc_data $i]
		if {$port_mask != {} && $port_mask != {00000000}} {
			set feature_available(p$j) 1
			set feature_available(port$j) $port_mask
		} else {
			set feature_available(p$j) 0
			set feature_available(port$j) {00000000}
		}
	}

	# Set incomplete_regs_mask, restricted_bits and incomplete_regs
	array unset incomplete_regs_mask
	set restricted_bits {}
	foreach reg_mask [lindex $proc_data 18] {
		set addr [string range $reg_mask 0 1]
		set mask [string range $reg_mask 2 3]
		set addr [expr "0x$addr"]
		set mask [expr "0x$mask"]

		set incomplete_regs_mask($addr) $mask

		if {$addr > 127 && !($addr % 8)} {
			for {set i 1} {$i <= 128} {set i [expr {$i * 2}]; incr addr} {
				if {![expr $mask & $i]} {
					lappend restricted_bits $addr
				}
			}
		}
	}
	set incomplete_regs [array names incomplete_regs_mask]

	# Determiate list of write-only registers
	set write_only_regs {}
	foreach reg [lindex $proc_data 19] {
		lappend write_only_regs [expr "0x$reg"]
	}

	# (Re)initialize uC memories and configuration
	array unset sfr
	array unset ram
	array unset eram
	array unset xram
	array unset code
	array unset eeprom
	array unset eeprom_WR_buff
	array unset controllers_conf

	# Set critical MCU configuration
	set controllers_conf(WatchDogPrescaler)	0
	set controllers_conf(RDYBSY)	1
	set controllers_conf(WRTINH)	1
	foreach key {
		X2 HWDT WDTEN WSWRST IE0 TF0 IE1 TF1 TI RI SPIF TF2
		EXF2 CF DPS DCEN T2OE T0_MOD T1_MOD UART_M SMOD0 FE
		CEN INT0 INT1 TCLK RCLK SMOD T2EX T2 T1 T0 T2_out
	} {
		set controllers_conf($key) 0
	}

	# Power on virtual uC and derminate list of implemented SFR
	simulator_system_power_on
	master_reset 0
	set available_sfr [array names sfr]

	# Initialize/Clear code memory and data EEPROM
	simulator_clear_memory code
	simulator_clear_memory eeprom
}

## Clear memory content
 # @parm String mem_type - Type of memory to clear
 #	code	- Program memory
 #	xdata	- External data memory
 #	eram	- Expanded data memory
 #	eeprom	- Data EEPROM
 # @return void
public method simulator_clear_memory {mem_type} {
	switch -- $mem_type {
		{code} {	;# Program memory
			for {set i 0} {$i < $code_size} {incr i} {
				set code($i) {}
			}
		}
		{xdata} {	;# External data memory
			for {set i 0} {$i < $xdata_size} {incr i} {
				set xdata($i) {}
			}
		}
		{eram} {	;# Expanded data memory
			for {set i 0} {$i < $eram_size} {incr i} {
				set eram($i) {}
			}
		}
		{eeprom} {	;# Data EEPROM
			for {set i 0} {$i < $eeprom_size} {incr i} {
				set eeprom($i) 0
			}
			if {$eeprom_size} {
				for {set i 0} {$i < 32} {incr i} {
					set eeprom_WR_buff($i) {}
				}
			}
		}
	}
}

## Inicliaze array 'symbol' -- this function must be called after definition of this class
 # @return void
proc InitializeNS {} {
	variable symbol	;# Array of SFR symbolic names (eg. $symbol(P0) == "80")

	foreach symb_name {
		{P0	80}	{SP	81}	{DP0L	82}	{DP0H	83}
		{DP1L	84}	{DP1H	85}	{IPH	B7}	{SADDR	A9}
		{PCON	87}	{TCON	88}	{TMOD	89}	{TL0	8A}
		{TL1	8B}	{TH0	8C}	{TH1	8D}	{AUXR	8E}
		{P1	90}	{SCON	98}	{SBUFR	99}	{P2	A0}
		{AUXR1	A2}	{WDTRST	A6}	{IE	A8}	{P3	B0}
		{IP	B8}	{P4	C0}	{T2CON	C8}	{T2MOD	C9}
		{RCAP2L	CA}	{RCAP2H	CB}	{TL2	CC}	{TH2	CD}
		{PSW	D0}	{A	E0}	{B	F0}	{SPDR	86}
		{WDTCON	A7}	{EECON	96}	{CLKREG	8F}	{ACSR	97}
		{SADEN	B9}	{SPCR	D5}	{SPSR	AA}	{SBUFT	199}

		{IT0	88}	{IE0	89}	{IT1	8A}	{IE1	8B}
		{TR0	8C}	{TF0	8D}	{TR1	8E}	{TF1	8F}

		{RI	98}	{TI	99}	{RB8	9A}	{TB8	9B}
		{REN	9C}	{SM2	9D}	{SM1	9E}	{SM0	9F}

		{EX0	A8}	{ET0	A9}	{EX1	AA}	{ET1	AB}
		{ES	AC}	{ET2	AD}	{EC	AE}	{EA	AF}

		{RXD	B0}	{TXD	B1}	{INT0	B2}	{INT1	B3}
		{T0	B4}	{T1	B5}	{WR	B6}	{RD	B7}

		{PX0	B8}	{PT0	B9}	{PX1	BA}	{PT1	BB}
		{PS	BC}	{PT2	BD}	{PC	BE}

		{TF2	CF}	{EXF2	CE}	{RCLK	CD}	{TCLK	CC}
		{EXEN2	CB}	{TR2	CA}	{CT2	C9}	{CPRL2	C8}

		{P	D0}			{OV	D2}	{RS0	D3}
		{RS1	D4}	{F0	D5}	{AC	D6}	{C	D7}
	} {
		set symbol([lindex $symb_name 0]) [expr "0x[lindex $symb_name 1]"]
	}

	array set ::Simulator_ENGINE::PIN {
		AD0	{0 0}
		AD1	{0 1}
		AD2	{0 2}
		AD3	{0 3}
		AD4	{0 4}
		AD5	{0 5}
		AD6	{0 6}
		AD7	{0 7}

		T2	{1 0}
		ANL1	{1 0}
		ANL0	{1 1}
		T2EX	{1 1}
		MOSI	{1 5}
		MISO	{1 6}
		SCK	{1 7}

		A15	{2 7}
		A14	{2 6}
		A13	{2 5}
		A12	{2 4}
		A11	{2 3}
		A10	{2 2}
		A9	{2 1}
		A8	{2 0}

		RXD	{3 0}
		TXD	{3 1}
		INT0	{3 2}
		INT1	{3 3}
		T0	{3 4}
		T1	{3 5}
		WR	{3 6}
		RD	{3 7}
	}

	set PORT_LATCHES [list $symbol(P0) $symbol(P1) $symbol(P2) $symbol(P3) $symbol(P4)]
}

## Stop simulator engine
 # @return void
private method internal_shutdown {} {
	set break 1
	$this Simulator_sync_clock
}

## Determinate if the specified feature is available on this MCU
 # @parm String key - feature name (e.g. 'p0')
 # @return Bool - result (1 == yes; 0 == no)
public method get_feature_available {key} {
	return $feature_available($key)
}

## Get number of implemented ports and list of port indexes
 # @return List - {number_of_ports {idx0 idx1...}} (e.g. {4 {0 1 2 3}})
public method get_ports_info {} {
	set sum 0
	for {set i 0} {$i < 5} {incr i} {
		if {$feature_available(p$i)} {
			incr sum
			lappend lst $i
		}
	}
	return [list $sum $lst]
}

# >>> File inclusion guard
}
# <<< File inclusion guard

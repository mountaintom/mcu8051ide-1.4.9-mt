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
if { ! [ info exists _SIMULATOR_TCL ] } {
set _SIMULATOR_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements 8051 Simulator environment.
# Object constist of GUI panel of controls (class Simulator_GUI)
# and Simulator Engine (class Simulator_ENGINE).
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# This file was modified & fixed by Kostya V. Ivanov <kostya@istcom.spb.ru>
#
# Special thanks to Kostya V. Ivanov !
# --------------------------------------------------------------------------

# Load sources
source "${::LIB_DIRNAME}/simulator/engine/engine_core.tcl"	;# Simulator engine
source "${::LIB_DIRNAME}/simulator/simulator_gui.tcl"		;# Simulator panel
source "${::LIB_DIRNAME}/simulator/interruptmonitor.tcl"	;# Interrupt monitor
source "${::LIB_DIRNAME}/simulator/uart_monitor.tcl"		;# UART monitor
source "${::LIB_DIRNAME}/simulator/sfrmap.tcl"			;# SFR Map monitor
source "${::LIB_DIRNAME}/simulator/stopwatch.tcl"		;# Stopwatch
source "${::LIB_DIRNAME}/simulator/bitmap.tcl"			;# Map of bit addressable area
source "${::LIB_DIRNAME}/simulator/stackmonitor.tcl"		;# Stack monitor

class Simulator {
	inherit Simulator_GUI Simulator_ENGINE InterruptMonitor SFRMap Stopwatch BitMap StackMonitor UARTMonitor

	## COMMON
	public common highlight_color	{#DD8800}	;# Foreground color for changed registers
	public common normal_color	{#000000}	;# Foreground color for unchanged registers
	public common error_dialog_project		;# Object: $this for current addressing error dialog
	public common not_again_val		0	;# Bool: Value of checkbutton "Do not shot this dialog again"

	public common reverse_run_steps	10	;# Int: Number of steps which can be taken back
	public common ignore_stack_overflow	0	;# Bool: Do not show "Stack overflow" dialog
	public common ignore_stack_underflow	0	;# Bool: Do not show "Stack underflow" dialog
	public common ignore_watchdog_reset	0	;# Bool: Ignore reset invoked by watchdog overflow
	public common ignore_read_from_wr_only	0	;# Bool: Ignore reading from read only register
	public common ignore_invalid_reti	0	;# Bool: Ignore invalid return fom interrupt
	public common ignore_invalid_ins	0	;# Bool: Ignore invalid instructions
	public common ignore_invalid_IDATA	0	;# Bool: Ignore access to unimplemented IDATA memory
	public common ignore_invalid_EDATA	0	;# Bool: Ignore access to unimplemented EDATA memory
	public common ignore_invalid_XDATA	0	;# Bool: Ignore access to unimplemented XDATA memory
	public common ignore_invalid_BIT	0	;# Bool: Ignore access to unimplemented bit
	public common ignore_invalid_CODE	0	;# Bool: Ignore access to unimplemented CODE memory
	public common ignore_invalid_USB	0	;# Bool: Ignore "UART: Frame discarded"
	public common ignore_invalid_UMC	0	;# Bool: Ignore "UART mode has been changed while UART was engaged"
	public common ignore_invalid_TMC	0	;# Bool: Ignore "Timer mode has been changed while timer was running"
	public common ignore_invalid_brkpoints	0	;# Bool: Do not warn user about invalid (unreachable) breakpoints

	public common ignore_EEPROM_WR_fail	0	;# Bool: Ignore EEPROM write failure (due to EECON.WRTINH, EECON.RDYBSY or EECON.EEMWE)
	public common ignore_EEPROM_WR_abort	0	;# Bool: Ignore EEPROM write cycle abort
	public common undefined_value		2	;# Int: 2 == Random; 1 == 255; 0 == 0

	# Normal font for error dialog
	public common error_normal_font	[font create		\
		-family {helvetica}				\
		-size [expr {int(-14 * $::font_size_factor)}]	\
	]
	# Bold font for error dialog
	public common error_bold_font		[font create		\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight bold					\
	]
	# Header font for error dialog
	public common error_header_font	[font create		\
		-family {helvetica}				\
		-size [expr {int(-17 * $::font_size_factor)}]	\
		-weight bold					\
	]
	# Main header font
	public common error_main_header	[font create		\
		-family {helvetica}				\
		-size [expr {int(-20 * $::font_size_factor)}]	\
		-weight bold					\
	]

	## PRIVATE
	private variable widgets		;# Array of widgets related to MCU registers
	private variable highlight_ena 0	;# Enable regsters highlighting
	private variable error_dialog_textwdg	;# Widget: Text widget used in error dialog
	private variable addr_error_save_type	;# Type of file to save

	# Bool: Related to warnings dialogues
	private variable ignore_warnings_related_to_changes_in_SFR	0

	## Obejct constructor
	constructor {} {
	}

	## Synchronize GUI with Engine, Entries: PC, Clock and Watchdog
	 # @return void
	public method Simulator_sync_PC_etc {} {
		# Disable GUI synchronization
		$this SimGUI_disable_sync

		# Get new and old value of Program Counter
		set new_val [getPC]
		set original_val [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_PC_dec"]

		# Display new value of PC and highlight it if it has changed
		set ::Simulator_GUI::ENV${obj_idx}_PC_dec $new_val
		if {$original_val != $new_val} {
			if {$highlight_ena} {
				mark_entry PC
			}
			$this sim_eval_PC dec $new_val
		}

		# Mode program pointer in code mememory hex editor
		::X::program_counter_changed $this $new_val

		# Synchronize Watchdog
		if {[$this get_feature_available wtd]} {
			set val [format %X [$this simulator_getWatchDogTimerValue]]
			set len [string length $val]
			if {$len != 4} {
				set val "[string repeat {0} [expr {4 - $len}]]$val"
			}
			set ::Simulator_GUI::ENV${obj_idx}_WatchDog $val
			$this simulator_evaluate_wtd_onoff_switch
			$this watchdog_validate $val

			if {[$this get_feature_available wdtcon] || [$this get_feature_available wdtprg]} {
				set val [format %X [$this simulator_getWatchDogPrescalerValue]]
				if {[string length $val] == 1} {
					set val "0$val"
				}
				set ::Simulator_GUI::ENV${obj_idx}_WatchDogP $val
			}
		}

		# Synchronize Clock
		Simulator_sync_clock

		# Enable GUI synchronization
		$this SimGUI_enable_sync
	}

	## Synchronize GUI with Engine, Entry: Time
	 # @return void
	public method Simulator_sync_clock {} {
		# Display the new value of the clock
		if {[$this cget -P_option_clock] != {}} {
			set ::Simulator_GUI::ENV${obj_idx}_TIME [getTime]
		}
	}

	## Set new clock value (entrybox: Clock)
	 # @parm Int value - new clock frequency 0..99999 (kHz)
	 # @return void
	public method Simulator_set_clock {value} {
		set ::Simulator_GUI::ENV${obj_idx}_CLOCK $value
	}

	## Synchronize particular register in Internal Data Memory
	 # @parm Int addr - address of register to synchronize
	 # @return void
	public method Simulator_sync_reg {addr} {
		Simulator_GUI_sync I $addr
	}

	## Synchronize particular register in SFR area
	 # @parm Int addr - address of register to synchronize
	 # @return void
	public method Simulator_sync_sfr {addr} {
		Simulator_GUI_sync S $addr
	}

	## Synchronize particular register in External and Expanded Data Memory
	 # @parm Int addr - address of register to synchronize
	 # @return void
	public method Simulator_XDATA_sync {addr} {
		# Convert address to 4 and 3 digits HEX number
		set addr [format "%X" $addr]
		set len [string length $addr]
		if {$len < 4} {
			$this rightPanel_watch_sync "[string repeat 0 [expr {3 - $len}]]$addr"
			set addr "[string repeat 0 [expr {4 - $len}]]$addr"
		}

		# Synchronize with HEX Editor
		X::sync_xram_mem_window $addr $this

		# Synchronize with C variables view
		$this cvarsview_sync F [expr "0x$addr"]
	}

	## Synchronize particular register in Internal Data Memory or SFR area
	 # @pamr Char type	- I == IDATA; S == SFR
	 # @parm Int addr - address of register to synchronize
	 # @return void
	public method Simulator_GUI_sync {type addr} {
		# Internal RAM
		if {$type == {I}} {
			# Get new and old value
			set new_val [getDataDEC $addr]
			set original_val [simulator_hexeditor get_values $addr $addr]
			if {$original_val == {}} {
				set original_val 0
			}

			# Display (and highlight) new value
			if {$addr < 32} {
				set hexvalue [getData $addr]
				set ::Simulator_GUI::ENV${obj_idx}_DATA($addr) $hexvalue

				set bnk [expr {$addr / 8}]
				set idx [expr {$addr % 8}]
				if {$bnk == [getBank]} {
					set ::Simulator_GUI::ENV${obj_idx}_R${idx} $hexvalue
					if {$highlight_ena && ($original_val != $new_val)} {
						mark_entry R${idx}
					}
				}
			}

			# Update IDATA hex editor
			simulator_hexeditor setValue $addr $new_val
			if {$highlight_ena && ($original_val != $new_val)} {
				simulator_hexeditor setHighlighted $addr 1
			}

			# Update RAM help window
			set hex_addr [format %X $addr]
			if {[string length $hex_addr] == 1} {
				set hex_addr "0$hex_addr"
			}
			help_window_update $hex_addr $new_val

			# Synchronize with C variables view
			if {$addr < 128} {
				$this cvarsview_sync E $addr
			} else {
				$this cvarsview_sync G $addr
			}

			# Synchronize watches on right panel and stack monitor
			$this rightPanel_watch_sync $hex_addr
			$this stack_monitor_sync $addr

			# Synchronize with map of bit addressable area
			$this bitmap_sync $addr

			# Done ..
			return

		# Program Status Word
		} elseif {$addr == 208} {
			# Get value of PSW
			set psw [getSfr 208]
			set psw [expr "0x$psw"]

			# Evaluate separate bits and highlight them
			set mask 256
			foreach bit {C AC F0 RS1 RS0 OV - P} {

				# Evaluate bit mask
				set mask [expr {$mask >> 1}]
				# Skip NULL registers
				if {$bit == {-}} {continue}

				# Determinate boolean value of the bit
				if {$psw == 0} {
					set bool 0
				} else {
					if {[expr {$psw & $mask}] > 0} {
						set bool 1
					} else {
						set bool 0
					}
				}

				# Set bit value
				set ::Simulator_GUI::ENV${obj_idx}_SFR($bit) $bool

				# Take care of bit color
				if {$bool} {
					$Simulator_panel_parent._PSW_$bit configure -fg $on_color
				} else {
					$Simulator_panel_parent._PSW_$bit configure -fg $off_color
				}
			}
			# Set Registers values
			for {set i 0} {$i < 8} {incr i} {
				set idx [expr {[getBank] * 8 + $i}]
				set hexvalue [getData $idx]
				set ::Simulator_GUI::ENV${obj_idx}_R${i} $hexvalue
			}
			# Synchronize with SFR watches
			$this sfr_watches_sync 208 $psw
			$this sfrmap_map_sync 208 $psw
			$this rightPanel_watch_sync_sfr 208

			# Update RAM help window
			help_window_update {D0 SFR} $psw

			# Synchronize with C variables view
			$this cvarsview_sync I 208

			# Done ..
			return

		# Special Function Registers
		} else {
			# Evaluate register name
			set name_resolved 1
			switch -- $addr {
				128	{set regName {P0}	}
				144	{set regName {P1}	}
				160	{set regName {P2}	}
				176	{set regName {P3}	}
				192	{set regName {P4}	}
				131	{set regName {DPH}	}
				130	{set regName {DPL}	}
				133	{set regName {DP1H}	}
				132	{set regName {DP1L}	}
				153	{set regName {SBUFR}	}
				409	{set regName {SBUFT}	}
				152	{set regName {SCON}	}
				141	{set regName {TH1}	}
				139	{set regName {TL1}	}
				140	{set regName {TH0}	}
				138	{set regName {TL0}	}
				136	{set regName {TCON}	}
				137	{set regName {TMOD}	}
				135	{set regName {PCON}	}
				168	{set regName {IE}	}
				184	{set regName {IP}	}
				129	{set regName {SP}	}
				224	{set regName {A_hex}	}
				240	{set regName {B_hex}	}
				200	{set regName {T2CON}	}
				201	{set regName {T2MOD}	}
				202	{set regName {RCAP2L}	}
				203	{set regName {RCAP2H}	}
				204	{set regName {TL2}	}
				205	{set regName {TH2}	}
				162	{set regName {AUXR1}	}
				166	{set regName {WDTRST}	}
				142	{set regName {AUXR}	}
				151	{set regName {ACSR}	}
				183	{set regName {IPH}	}
				169	{set regName {SADDR}	}
				185	{set regName {SADEN}	}
				213	{set regName {SPCR}	}
				170	{set regName {SPSR}	}
				134	{set regName {SPDR}	}
				150	{set regName {EECON}	}
				143	{
					if {[$this get_feature_available ckcon]} {
						set regName {CKCON}
					} else {
						set regName {CLKREG}
					}
				}
				167	{
					if {[$this get_feature_available wdtprg]} {
						set regName {WDTPRG}
					} else {
						set regName {WDTCON}
					}
				}
				default	{set name_resolved 0}
			}

			# Synchronize with SFR watches
			set new_val [getSfr $addr]
			set dec_val [expr {"0x$new_val"}]
			$this sfr_watches_sync $addr $dec_val

			# Synchronize with SFR map
			$this sfrmap_map_sync $addr $dec_val

			# Synchronize with C variables view
			$this cvarsview_sync I $addr

			# Synchronize with simulator control panel
			if {$name_resolved} {
				set original_val [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_${regName}"]
				set ::Simulator_GUI::ENV${obj_idx}_${regName} $new_val

				if {$highlight_ena && ($original_val != $new_val)} {
					mark_entry $addr
				}

				# Synchronize special values
				switch -- $addr {
					152 {	;# SCON
						## Synchronize bits FE and SM0
						 # FE
						set bit_FE [$this sim_engine_get_FE]
						if {$bit_FE != {}} {
							set ::Simulator_GUI::ENV${obj_idx}_SFR(FE) $bit_FE
							if {$bit_FE} {
								$Simulator_panel_parent._SCON_FE configure -fg $::Simulator_GUI::on_color
							} else {
								$Simulator_panel_parent._SCON_FE configure -fg $::Simulator_GUI::off_color
							}
						}
						 # SM0
						if {[$this sim_engine_get_SM0]} {
							$Simulator_panel_parent._SCON_SM0 configure -fg $::Simulator_GUI::on_color
							set ::Simulator_GUI::ENV${obj_idx}_SFR(SM0) 1
						} else {
							$Simulator_panel_parent._SCON_SM0 configure -fg $::Simulator_GUI::off_color
							set ::Simulator_GUI::ENV${obj_idx}_SFR(SM0) 0
						}
					}
					153 {	;# SBUF
						## Synchronize both registers (receive & transmit)
						Simulator_GUI_sync S ${::Simulator_ENGINE::symbol(SBUFT)}
					}
				}
			}

			# Update RAM help window
			set hex_addr [format %X $addr]
			if {[string length $hex_addr] == 1} {
				set hex_addr "0$hex_addr"
			}
			help_window_update [list $hex_addr {SFR}] $new_val

			$this rightPanel_watch_sync_sfr $addr

			# Explicitly call entry box validator
			switch -- $addr {
				224	{$this sim_eval_AB A hex $new_val}
				240	{$this sim_eval_AB B hex $new_val}

				205	- 	204	-	203	-
				202	-	141	-	139	-
				140	-
				138	{$this validate_Txx $regName $new_val}

				128	-	144	-	160	-
				176	-
				192	{$this sim_eval_Px $regName hex $new_val}

				142	-	162	-	151	-
				150	-	213	-	170	-
				167	-	167	-	183	-
				143	-	200	-	201	-
				135	-	152	-	168	-
				184	-	136	-
				137	{$this validate_hex_bitmap_reg $new_val $regName}
			}
		}
	}

	## Synchronize all registers in IRAM and SFR
	 # @return void
	public method Simulator_sync {} {
		# Synchronize PC and Clock
		Simulator_sync_PC_etc

		# Synchronize IRAM
		set iram_size [lindex [$this cget -procData] 3]
		for {set i 0} {$i < $iram_size} {incr i} {
			Simulator_sync_reg $i
		}

		# Synchronize SFR
		foreach addr [simulator_get_available_sfr] {
			Simulator_GUI_sync S $addr
		}
	}

	## Synchronization after simulator initialization
	 # @return void
	public method Simulator_first_sync {} {
		set highlight_ena 0
		Simulator_sync
		set highlight_ena 1
	}

	## Reset simulator engine and synchronize all registers
	 # @parm Int arg - argument for reset procedure
	 # @return void
	public method Simulator_reset {arg} {
		# Perform master reset
		master_reset $arg

		# Synchronize
		set highlight_ena 0
		Simulator_sync
		set highlight_ena 1

		# Clear stepback stack
		stepback_discard_stack
		::X::stepback_button_set_ena 0

		# Clear highlight
		simulator_clear_highlight

		# Clear time entry
		set ::Simulator_GUI::ENV${obj_idx}_TIME {}
	}

	## Clear highlight for all internal registers
	 # @return void
	public method simulator_clear_highlight {} {
		simulator_hexeditor clearHighlighting
		foreach addr [simulator_get_available_sfr] {
			unmark_entry $addr
		}
		foreach addr {R0 R1 R2 R3 R4 R5 R6 R7} {
			unmark_entry $addr
		}
		unmark_entry PC
	}

	## Add register entry widget reference to array of registers
	 # @parm Int addr	- Register address
	 # @parm Widget widget	- Register entry widget
	 # @return void
	public method add_sfr_entry {addr widget} {
		lappend widgets($addr) $widget
	}

	## Clear list of registred widgets in simulator control panel
	 # This list is used for enabling/disabling these widgets on start/shutdown
	 # @return void
	public method sumulator_clear_widgets {} {
		array unset widgets
	}

	## Highlight register entry widget
	 # @parm Int addr	- Register address
	 # @return void
	public method mark_entry {addr} {
		# Skip PSW
		if {$addr == 208} {return}

		foreach wdg $widgets($addr) {
			if {[winfo class $wdg] == {TEntry}} {
				$wdg configure -style Simulator_HG.TEntry
			} else {
				$wdg configure -fg $highlight_color
			}
		}
	}

	## "Unhighlight" register entry widget
	 # @parm Int addr	- Register address
	 # @return void
	public method unmark_entry {addr} {
		# Skip PSW
		if {$addr == 208} {return}

		foreach wdg $widgets($addr) {
			if {[winfo class $wdg] == {TEntry}} {
				$wdg configure -style Simulator.TEntry
			} else {
				$wdg configure -fg $normal_color
			}
		}
	}

	## Invokes error message "Undefined result"
	 # @parm Char location	- Memory type
	 #	D == IDATA direct addressing
	 #	I == IDATA indirect addressing (or operations on stack)
	 #	B == Bit area
	 #	E == ERAM
	 #	X == XDATA
	 #	C == CODE
	 # @parm Int address	- Memory address (0..65536)
	 # @return void
	public method invalid_addressing_dialog {location address} {
		# Gain error and processor details
		set addr_dec $address
		set address [format %X $address]
		set len [string length $address]
		if {$len < 4} {
			set address "[string repeat 0 [expr {4 - $len}]]$address"
		}
		set processor [$this cget -P_option_mcu_type]
		switch -- $location {
			{D} {	;# IDATA direct addressing
				set conf_variable {ignore_invalid_IDATA}
				set addressing {direct }
				if {$addr_dec > 127} {
					set memory {special function registers area}
					set mem {SFR}
				} else {
					set mem {IDATA}
					set memory {internal data memory}
				}
			}
			{I} {	;# IDATA indirect addressing (or operations with stack)
				set conf_variable {ignore_invalid_IDATA}
				set addressing {indirect }
				set memory {internal data memory}
				set mem {IDATA}
			}
			{B} {	;# Bit area
				set conf_variable {ignore_invalid_BIT}
				set addressing {direct }
				set memory {bit addressable area}
				set mem {Bit area}
			}
			{X} {	;# XDATA
				set conf_variable {ignore_invalid_XDATA}
				set addressing {indirect }
				set memory {external data memory}
				set mem {XDATA}
			}
			{C} {	;# CODE
				set conf_variable {ignore_invalid_CODE}
				set addressing {}
				set memory {program memory}
				set mem {CODE}
			}
		}

		# Create dialog window
		set win [toplevel .undefined_result -class {Error dialog} -bg ${::COMMON_BG_COLOR}]

		# Create dialog header
		set top_frame [frame $win.top_frame]
		pack [label $top_frame.left			\
			-image ::ICONS::32::messagebox_critical	\
		] -side left
		pack [label $top_frame.right		\
			-text [mc "Undefined result"]	\
			-font $error_main_header	\
		] -side left -fill x

		# Create middle frame (text widget and scrollbar)
		set middle_frame [frame $win.middle_frame]
		set text_wdg [text $middle_frame.text			\
			-height 0 -width 0 -font $error_normal_font	\
			-yscrollcommand "$middle_frame.scrollbar set"	\
			-wrap word -relief flat -bg ${::COMMON_BG_COLOR}		\
			-tabstyle wordprocessor				\
		]
		set error_dialog_textwdg $text_wdg
		pack $text_wdg -side left -fill both -expand 1
		pack [ttk::scrollbar $middle_frame.scrollbar	\
			-command "$text_wdg yview"		\
			-orient vertical			\
		] -side right -fill y -after $text_wdg

		# Create bottom frame (buttons: Save as text, Save as XHTML, Ok)
		set bottom_frame [frame $win.bottom_frame]
		pack [ttk::button $bottom_frame.save_as_txt		\
			-image ::ICONS::16::ascii			\
			-compound left					\
			-text [mc "Save as plain text"]			\
			-command "$this simulator_addr_error_save T"	\
		] -side left -padx 2
		pack [ttk::button $bottom_frame.save_as_xhtml		\
			-image ::ICONS::16::html			\
			-compound left					\
			-text [mc "Save as XHTML"]			\
			-command "$this simulator_addr_error_save X"	\
		] -side left -padx 2
		pack [ttk::button $bottom_frame.ok			\
			-image ::ICONS::16::ok				\
			-compound left					\
			-text [mc "Ok"]					\
			-command "grab release $win; destroy $win"	\
		] -side right

		$text_wdg tag configure tag_bold	-font $error_bold_font
		$text_wdg tag configure tag_header	-font $error_header_font

		# Error summary
		$text_wdg insert end [mc "Summary:"]
		$text_wdg tag add tag_header {insert linestart} insert
		$text_wdg insert end [mc "\nYour program tried ${addressing}access to register at address "]
		set index [$text_wdg index insert]
		$text_wdg insert end [mc "0x%s in $memory" $address]
		$text_wdg tag add tag_bold $index insert
		$text_wdg insert end [mc ". This register is not implemented on this processor ("]
		set index [$text_wdg index insert]
		$text_wdg insert end "$processor"
		$text_wdg tag add tag_bold $index insert
		$text_wdg insert end [mc ") in this configuration. You can continue in simulation but result of this operation is undefined."]

		# Error details
		$text_wdg insert end [mc "\n\nError details:"]
		$text_wdg tag add tag_header {insert linestart} insert
		$text_wdg insert end [mc "\n\tTarget memory:\t\t"]
		$text_wdg tag add tag_bold {insert linestart} insert
		$text_wdg insert end [mc $mem]
		$text_wdg insert end [mc "\n\tTarget address: \t"]
		$text_wdg tag add tag_bold {insert linestart} insert
		$text_wdg insert end "0x$address ($addr_dec)"
		$text_wdg insert end [mc "\n\tLine:\t\t\t"]
		$text_wdg tag add tag_bold {insert linestart} insert
		$text_wdg insert end [$this editor_actLineNumber]
		$text_wdg insert end [mc "\n\tFile:\t\t\t"]
		$text_wdg tag add tag_bold {insert linestart} insert
		$text_wdg insert end [$this editor_procedure {} cget -filename]
		$text_wdg insert end [mc "\n\tProject:\t\t"]
		$text_wdg tag add tag_bold {insert linestart} insert
		$text_wdg insert end [$this cget -projectName]

		# Processor details
		$text_wdg insert end [mc "\n\nProcessor details:"]
		$text_wdg tag add tag_header {insert linestart} insert
		$text_wdg insert end [mc "\n\tType:\t\t\t"]
		$text_wdg tag add tag_bold {insert linestart} insert
		$text_wdg insert end [$this cget -P_option_mcu_type]
		$text_wdg insert end [mc "\n\tRam size:\t\t"]
		$text_wdg tag add tag_bold {insert linestart} insert
		$text_wdg insert end "[lindex [$this cget -procData] 3] B"
		$text_wdg insert end [mc "\n\tProgram memory: \t"]
		$text_wdg tag add tag_bold {insert linestart} insert
		$text_wdg insert end "[expr [lindex [$this cget -procData] 2] * 1024 + [$this cget -P_option_mcu_xcode]] B"
		$text_wdg insert end [mc "\n\tExternal memory:\t"]
		$text_wdg tag add tag_bold {insert linestart} insert
		$text_wdg insert end "[$this cget -P_option_mcu_xdata] B"
		$text_wdg insert end [mc "\n\tExpanded memory:\t"]
		$text_wdg tag add tag_bold {insert linestart} insert
		$text_wdg insert end "[lindex [$this cget -procData] 8] B"

		# Disable text widget and pack dialog frames
		$text_wdg configure -state disabled
		pack $top_frame -pady 5
		pack $middle_frame -fill both -expand 1 -pady 15 -padx 10
		pack [ttk::separator $win.sep -orient horizontal] -fill x -padx 5 -pady 5
		set ::Simulator::not_again_val 0
		pack [checkbutton $win.not_again_checkbutton		\
			-text [mc "Do not show this dialog again"]	\
			-variable ::Simulator::not_again_val		\
			-command "::configDialogues::simulator::set_variable $conf_variable \$::Simulator::not_again_val" \
		] -anchor w -padx 15 -pady 5
		DynamicHelp::add $win.not_again_checkbutton	\
			-text [mc "See simulator configuration dialog\nMain Menu -> Configure -> Simulator"]
		pack $bottom_frame -fill x -side bottom -after $middle_frame -padx 5 -pady 5

		# Show dialog window
		bell
		focus -force $bottom_frame.ok
		wm title $win [mc "Undefined result - MCU 8051 IDE"]
		wm iconphoto $win ::ICONS::16::no
		wm minsize $win 470 400
		wm protocol $win WM_DELETE_WINDOW "
			grab release $win
			destroy $win
		"
		wm transient $win .
		wm geometry $win "+[expr {([winfo screenwidth .] - 450) / 2}]+[expr {([winfo screenheight .] - 400) / 2}]"
		raise $win
		catch {
			grab $win
		}
		tkwait window $win
	}

	## Invoke dialog to save contents of dialog "Undefined result" as plain text or XHTML
	 # @parm Char type - T == plain text; X == XHTML
	 # @return void
	public method simulator_addr_error_save {type} {
		set addr_error_save_type $type
		set error_dialog_project $this
		if {$type == {T}} {
			set init {error.log}
			set filetypes [list					\
				[list [::mc "Log files"]	{*.log}]	\
				[list [::mc "All files"]	{*}]		\
			]
		} else {
			set init {error.html}
			set filetypes [list					\
				[list [::mc "HTML files"]	{*.html}]	\
				[list [::mc "All files"]	{*}]		\
			]
		}

		# Invoke the file selection dialog
		catch {delete object fsd}
		KIFSD::FSD fsd	 					\
			-title [mc "Save error log - MCU 8051 IDE"]	\
			-directory [$this cget -projectPath]		\
			-initialfile $init -defaultmask 0		\
			-filetypes $filetypes -multiple 0

		# Open file after press of OK button
		fsd setokcmd {
			# Get filename
			set filename [::Simulator::fsd get]
			if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
				if {![regexp "^(~|/)" $filename]} {
				set filename "[${::Simulator::error_dialog_project} cget -ProjectDir]/$filename"
				}
			} else {	;# Microsoft windows way
				if {![regexp {^\w:} $filename]} {
					set filename [file join [${::Simulator::error_dialog_project} cget -ProjectDir] $filename]
				}
			}
			set filename [file normalize $filename]

			# Overwrite ?
			if {[file exists $filename]} {
				if {[tk_messageBox		\
					-icon question		\
					-type yesno		\
					-title [mc "Overwrite file ?"]	\
					-parent .undefined_result	\
					-message [mc "Specified file does already exist,\ndo you want to overwrite it ?"]
				] != {yes}} then {
					return
				}
			}

			# Open the specified file
			if {[catch {
				${::Simulator::error_dialog_project} simulator_save_error_log $filename
			} result]} then {
				puts stderr $result
				tk_messageBox				\
					-type ok			\
					-icon warning			\
					-parent .undefined_result	\
					-title [mc "Permission denied"]	\
					-message [mc "Unable to access file:\n%s" $filename]
			}
		}

		# activate the dialog
		fsd activate
	}

	## Wrap lines in the given text to the specified length
	 # @parm Int length	- Maximum line length
	 # @parm String txt	- Text to wrap
	 # @return String - Wrapped text
	private method line_wrap {length txt} {
		set result {}
		foreach line [split $txt "\n"] {
			set len [string length $line]
			if {$len <= $length} {
				append result $line "\n"
				continue
			}

			while {$len > $length} {
				append result [string range $line 0 [expr {$length - 1}]] "\n"
				set line [string range $line $length end]
				set len [string length $line]
			}
		}
		return $result
	}

	## Save contents of dialog "Undefined result" as plain text or XHTML
	 # Type of file depends on variable $addr_error_save_type
	 # @parm String filename - target file
	 # @return void
	public method simulator_save_error_log {filename} {
		set file [open $filename w]

		## SAVE AS PLAIN TEXT
		if {$addr_error_save_type == {T}} {
			puts -nonewline $file [line_wrap 70 [$error_dialog_textwdg get 1.0 end]]

		## SAVE AS XHTML
		} else {
			# Local variables
			set end [$error_dialog_textwdg index end]	;# Widget end index
			set last_index 0	;# Current position (by characters)
			set line(1) 0		;# Map of indexes ($line(num) == scalar_index)

			# Create XHTML declaration and header
			set html "<?xml version='1.0' encoding='utf-8' standalone='no'?>\n"
			append html "<!DOCTYPE html PUBLIC\n"
			append html "\t'-//W3C//DTD XHTML 1.1//EN'\n"
			append html "\t'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'>\n"
			append html "<html xmlns='http://www.w3.org/1999/xhtml' xml:lang='en'>\n"
			append html "\t<head>\n"
			append html "\t\t<title>$filename</title>\n"
			append html "\t\t<meta http-equiv=\"Content-Type\" content=\"application/xhtml+xml; charset=UTF-8\">\n"
			append html "\t\t<meta name=\"Generator\" content=\"${::APPNAME}\" />\n"
			append html "\t</head>\n"
			append html "\t<body>\n"
			puts -nonewline $file $html
			set html {}

			# Create map of indexes
			for {set i 1; set j 2} {$i < $end} {incr i; incr j} {
				# Determinate last column of the line
				set idx [$error_dialog_textwdg index [list $i.0 lineend]]
				regexp {\d+$} $idx idx

				# Adjust map of indexes
				incr last_index $idx
				incr last_index
				set line($j) $last_index
			}

			## Determinate highlighting tag ranges
			set ranges {}
			foreach tag {tag_header tag_bold} {
				# Local variables
				set range [$error_dialog_textwdg tag ranges $tag]	;# List of tag ranges
				set len [llength $range]				;# Number of ranges

				# If the tag isn't present in the text -> skip
				if {$len == 0} {continue}
				# Adjust tag name
				if {$tag == {tag_header}} {
					set tag {h2}
				} elseif {$tag == {tag_bold}} {
					set tag {b}
				}

				for {set i 0} {$i < $len} {incr i} {
					lappend ranges [list [lindex $range $i] $tag 1]
					incr i
					lappend ranges [list [lindex $range $i] $tag 0]
				}
			}
			set ranges [lsort -command "::FileList::editor__sort_tag_ranges" $ranges]

			# Write XHTML tags to plain text
			set i 0
			set html [$error_dialog_textwdg get 1.0 end]
			foreach range $ranges {
				# Local variables
				set idx [split [lindex $range 0] {.}]	;# Text index
				set row [lindex $idx 0]			;# Line number
				set col [lindex $idx 1]			;# Column number

				# Determinate scalar text index
				set idx [expr {$line($row) + $col}]
				# Skip unused tags
				if {$idx < 0} {set idx 0}

				# Deterinate string to insert
				if {[lindex $range 2]} {
					set tag [lindex $range 1]
				} else {
					set tag "/[lindex $range 1]"
				}

				# Insert XHTML tag into the text
				set char [string index $html $idx]
				set html [string replace $html $idx $idx "<$tag>$char"]

				incr i
			}

			regsub -all {\n} $html "<br />\n" html
			append html "\n\t</body>\n"
			append html "</html>\n"
			puts -nonewline $file $html
		}

		close $file
	}

	## Set flag: ignore_warnings_related_to_changes_in_SFR
	 # @parm Bool value - New value
	 # @return void
	public method set_ignore_warnings_related_to_changes_in_SFR {value} {
		set ignore_warnings_related_to_changes_in_SFR $value
	}

	## Invoke simulator warning dialog "UART: Frame discarded"
	 # @parm Int pc		- Value of program counter
	 # @parm Int line	- Line in source code where this error occurred
	 # @return void
	public method simulator_uart_invalid_stop_bit {pc line} {
		if {$ignore_warnings_related_to_changes_in_SFR || ![$this sim_is_busy]} {
			return
		}
		if {$line == {}} {
			set line {-}
		}

		simulator_warning_dialog	\
			ignore_invalid_USB	\
			[mc "UART: Frame discarded (according to MCS-51 manual)\n"] $pc $line
	}

	## Invoke simulator warning dialog "UART mode has been changed while UART was engaged"
	 # @parm Int pc		- Value of program counter
	 # @parm Int line	- Line in source code where this error occurred
	 # @return void
	public method simulator_invalid_uart_mode_change {pc line} {
		if {$ignore_warnings_related_to_changes_in_SFR || ![$this sim_is_busy]} {
			return
		}
		if {$line == {}} {
			set line {-}
		}

		simulator_warning_dialog	\
			ignore_invalid_UMC	\
			[mc "UART mode has been changed while UART was engaged.\n"] $pc $line
	}

	## Invoke simulator warning dialog "Timer mode has been changed while timer was running"
	 # @parm Int pc		- Value of program counter
	 # @parm Int line	- Line in source code where this error occurred
	 # @parm Int timer	- Timer number (0/1/2)
	 # @return void
	public method simulator_invalid_timer_mode_change {timer pc line} {
		if {$ignore_warnings_related_to_changes_in_SFR || ![$this sim_is_busy]} {
			return
		}
		if {$line == {}} {
			set line {-}
		}

		simulator_warning_dialog	\
			ignore_invalid_TMC	\
			[mc "Timer mode has been changed while timer was running.\nIt is important to stop timer/counter before changing modes.\n\nTimer number: %s\n" $timer] $pc $line
	}

	## Invoke watchdog reset dialog
	 # @parm Int pc		- Value of program counter
	 # @parm Int line	- Line in source code where this error occurred
	 # @return void
	public method simulator_watchdog_reset {pc line} {
		if {$line == {}} {
			set line {-}
		}

		simulator_warning_dialog	\
			ignore_watchdog_reset	\
			[mc "WATCHDOG OVERFLOW\n"] $pc $line
	}

	## Invokes dialog "Stack Overflow" / "Stack underflow"
	 # @parm String type	- {over} == overflow; {under} == underflow
	 # @parm Int pc		- Value of program counter
	 # @parm Int line	- Line in source code where this error occurred
	 # @return void
	public method simulator_stack_warning {type pc line} {
		if {$line == {}} {
			set line {-}
		}
		if {$type == {over}} {
			set foo {overflow}
			set conf_variable {ignore_stack_overflow}
		} else {
			set foo {underflow}
			set conf_variable {ignore_stack_underflow}
		}

		simulator_warning_dialog	\
			$conf_variable		\
			[mc "Stack $foo\n"] $pc $line
	}

	## Invoke dialog "Invalid instruction OP code"
	 # @parm Int pc		- Value of program counter
	 # @parm Int line	- Line in source code where this error occurred
	 # @return void
	public method simulator_invalid_instruction {pc line} {
		$this simulator_warning_dialog	\
			ignore_invalid_ins	\
			[mc "Invalid instruction OP code\n"] $pc $line
	}


	## Invoke dialog "Reading from write-only register"
	 # @parm Int addr	- Register address
	 # @parm Int pc		- Value of program counter
	 # @parm Int line	- Line in source code where this error occurred
	 # @return void
	public method simulator_reading_wr_only {addr pc line} {
		if {$line == {}} {
			set line {-}
		}

		simulator_warning_dialog		\
			ignore_read_from_wr_only	\
			[mc "Unable to read write-only register.\nRandom value returned.\n\nRegister:\t\t0x%s" [format %X $addr]] $pc $line
	}

	## Invoke dialog "EEPROM programming cycle abort"
	 # @parm Int pc		- Value of program counter
	 # @parm Int line	- Line in source code where this error occurred
	 # @return void
	public method simulator_EEPROM_WR_abort {pc line} {
		if {$line == {}} {
			set line {-}
		}

		simulator_warning_dialog	\
			ignore_EEPROM_WR_abort	\
			[mc "Data EEPROM write cycle aborted\n"] $pc $line
	}

	## Invoke dialog "EEPROM write failed"
	 # @parm Int pc		- Value of program counter
	 # @parm Int line	- Line in source code where this error occurred
	 # @return void
	public method simulator_EEPROM_WR_fail {pc line} {
		if {$line == {}} {
			set line {-}
		}

		simulator_warning_dialog	\
			ignore_EEPROM_WR_fail	\
			[mc "Unable to initialize EEPROM programming cycle\nbecause EEMWE, RDYBSY and WRTINH must be set\n"] $pc $line
	}

	## Invoke dialog "Invalid return from interrupt"
	 # @parm Int pc		- Value of program counter
	 # @parm Int line	- Line in source code where this error occurred
	 # @return void
	public method simulator_invalid_reti_dlg {pc line} {
		if {$line == {}} {
			set line {-}
		}

		simulator_warning_dialog	\
			ignore_invalid_reti	\
			[mc "Invalid return from interrupt"] $pc $line
	}

	## Invoke simulator warning dialog (like tk_messageBox)
	 # @parm String conf_variable	- Configuration variable for disabling this dialog
	 # @parm String text		- Text to show
	 # @parm Int pc			- Value of program counter
	 # @parm List line		- Line in source code where this error occurred
	 # @return void
	public method simulator_warning_dialog {conf_variable text pc line} {

		# Create dialog window
		set win {.simulator_warning_dialog}
		if {[winfo exists $win]} {
			destroy $win
		}
		toplevel $win -class {Error dialog} -bg ${::COMMON_BG_COLOR}

		## Create dialog icon and text
		set top_frame [frame $win.top_frame]
		pack [label $top_frame.left			\
			-image ::ICONS::32::messagebox_critical	\
		] -side left -padx 10

		append text "\n[mc {PC:}]\t\t0x" [format %X $pc] "\n[mc {Line:}]\t\t" [lindex $line 0] "\n[mc {File:}]\t\t" [file tail [$this simulator_get_filename [lindex $line 1]]]
		pack [label $top_frame.right	\
			-justify left		\
			-text $text	 	\
		] -side left -fill x

		## Create bottom frame
		 # Checkbutton  "Do not show this dialog again"
		set bottom_frame [frame $win.bottom_frame]
		set ::Simulator::not_again_val 0
		pack [checkbutton $bottom_frame.not_again_checkbutton		\
			-text [mc "Do not show this dialog again"]		\
			-variable ::Simulator::not_again_val			\
			-command "::configDialogues::simulator::set_variable $conf_variable \$::Simulator::not_again_val" \
		] -anchor w -side left -anchor w
		DynamicHelp::add $bottom_frame.not_again_checkbutton	\
			-text [mc "See simulator configuration dialog\nMain Menu -> Configure -> Simulator"]
		 # Button  "Ok"
		pack [ttk::button $bottom_frame.ok			\
			-image ::ICONS::16::ok				\
			-compound left					\
			-text [mc "Ok"]					\
			-command "grab release $win; destroy $win"	\
		] -side right -anchor e

		# Pack dialog fames
		pack $top_frame		-padx 5 -pady 5 -fill x -side top
		pack $bottom_frame	-padx 5 -pady 5 -fill x -side bottom

		# Show dialog window
		bell
		focus -force $bottom_frame.ok
		wm iconphoto $win ::ICONS::16::status_unknown
		wm title $win [mc "Simulator warning"]
		wm minsize $win 350 100
		wm protocol $win WM_DELETE_WINDOW "
			grab release $win
			destroy $win"
		wm transient $win .
		wm geometry $win "+[expr {([winfo screenwidth .] - 350) / 2}]+[expr {([winfo screenheight .] - 100) / 2}]"
		raise $win
		catch {
			grab $win
		}
		tkwait window $win
	}

	## Detect all invalid breakpoints (breakpoints at unreachable locations) and report them via messages panel
	 # @return void
	public method report_invalid_breakpoints {} {
		if {$ignore_invalid_brkpoints} {
			return
		}

		$this messages_text_append "\n"
		foreach fn_ln [$this simulator_getInvalidBreakpoints] {
			$this messages_text_append "[file tail [$this simulator_get_filename [lindex $fn_ln 0]]]:[lindex $fn_ln 1]: warning: Invalid breakpoint"
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

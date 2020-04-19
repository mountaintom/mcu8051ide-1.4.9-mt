#!/usr/bin/tclsh
# Part of MCU 8051 IDE ( http://http://www.moravia-microsystems.com/mcu8051ide )

############################################################################
#    Copyright (C) 2011-2011 by Martin Ošmera                              #
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
if { ! [ info exists _ENGINE_TEXT_BASED_INTERFACE_TCL ] } {
set _ENGINE_TEXT_BASED_INTERFACE_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
#
# Command line interface for the simulator engine. Listens to simple commands,
# like `read-sfr-by-name PCON'. Each command must be on separate line, empty
# lines and everything after `#' characater are ignored. Response to every
# command is either `DONE' or
# `ERROR (line: <line_number>; command: <command>): <error_info>'. Some commands
# returns some values, in that case these values are printed before the `DONE'
# string. Commands are case insensitive, but the same may not apply for their
# arguments.
#
# Note: This interface is supposed to be available via main.tcl invoked with
# --simulator option. That means that to access this inteface it should be
# sufficient to run `mcu8051ide --simulator' command.
#
# List of commands:
# ================
#
#	COMMAND			DESCRIPTION
#	-------			-----------
#	echo-on
#	echo-off
#	set-mcu
#	set-clock
#	set-xcode
#	set-xdata
#	load-code
#	load-code-adf
#	load-code-cdb
#	load-idata
#	load-xdata
#	load-eeprom
#	load-eram
#	dump-code
#	dump-idata
#	dump-xdata
#	dump-eeprom
#	dump-eram
#	write-code
#	write-idata
#	write-xdata
#	write-eeprom
#	write-eram
#	write-sfr
#	write-sfr
#	write-bit
#	read-code
#	read-idata
#	read-xdata
#	read-eeprom
#	read-eram
#	read-sfr
#	read-sfr-by-name
#	read-bit
#	step
#	step-back
#	list-changes
#	read-pc
#	write-pc
#	read-position
#	reset
#	run
#	input
#	output
#	hibernate
#	resume
#	core-dump
#	core-alter
#	exit
# --------------------------------------------------------------------------

namespace eval SimulatorEngineCLI {
	variable command_line
	variable cmd_line_idx
	variable simulator
	variable line_counter
	variable echo
	variable error_reported

	class SimEngineWrapper {
		inherit Simulator_ENGINE Pale

	public common changed_registers		[list]

		# TODO: get rid of these variables:
		public variable procData		{}
		public variable P_option_mcu_type	{}
		public variable P_option_mcu_xdata	0
		public variable P_option_mcu_xcode	0
		public variable projectPath		{.}

		public method is_ready {} {
			if {[llength $procData]} {
				return 1
			} else {
				return 0
			}
		}

		public method Simulator_GUI_sync args {
			lappend changed_registers $args
		}

		public method Simulator_sync_PC_etc {} {
		}

		public method get_changed_registers {} {
			return $changed_registers
		}

		public method clear_changed_registers {} {
			set changed_registers [list]
		}
	}

	proc enter_main_loop {} {
		variable command_line
		variable cmd_line_idx
		variable simulator
		variable line_counter	0
		variable echo		0
		variable error_reported

		set simulator [SimEngineWrapper #auto]

		namespace eval ::Simulator {
			variable undefined_value	2
			variable reverse_run_steps	100
		}

		namespace eval ::X {
			variable critical_procedure_in_progress 0
		}

		puts "READY"

		while {![eof stdin]} {
			incr line_counter
			set command_line [gets stdin]
			set command_line [regsub {#.*$} $command_line {}]
			set command_line [string trim $command_line]
			set cmd_line_idx 1
			set error_reported 0

			if {[catch {
				set command [string tolower [lindex $command_line 0]]
			}]} then {
				set tmp $command_line
				set command_line {<unknown>}
				abort_now "Unable to understand line: \"$tmp\""
			}

			# Do nothing with an empty line
			if {![string length $command_line]} {
				continue
			}

			if {$echo} {
				puts "> $command_line"
			}
			if {[lsearch -ascii -exact {set-mcu echo-on echo-off} $command] == -1 && ![$simulator is_ready]} {
				report_error "Processor type has to be specified first"
				continue
			}
			if {[command_switch $command]} {
				break
			}

			if {!$error_reported} {
				puts "OK"
			}
		}
		puts "EXITING"
	}

	proc command_switch {command} {
		variable echo
		switch -- $command {
			{echo-on} {
				expect_no_more_arguments
				command__echo_on
			}
			{echo-off} {
				expect_no_more_arguments
				command__echo_off
			}
			{set-mcu} {
				expect_string
				expect_no_more_arguments

				command__set_mcu
			}
			{set-clock} {
				expect_integer 1 99999
				expect_no_more_arguments

				command__set_clock
			}
			{set-xcode} {
				expect_integer 0 65536
				expect_no_more_arguments

				command__set_xcode
			}
			{set-xdata} {
				expect_integer 0 65536
				expect_no_more_arguments

				command__set_xdata
			}

			{load-code} {
				expect_no_more_arguments
				command__load_code
			}
			{load-code-adf} {
				expect_string
				expect_no_more_arguments

				command__load_code_adf
			}
			{load-code-cdb} {
				expect_string
				expect_string
				expect_string
				expect_no_more_arguments
				command__load_code_cdb
			}
			{load-idata} {
				expect_no_more_arguments
				command__load_idata
			}
			{load-xdata} {
				expect_no_more_arguments
				command__load_xdata
			}
			{load-eeprom} {
				expect_no_more_arguments
				command__load_eeprom
			}
			{load-eram} {
				expect_no_more_arguments
				command__load_eram
			}

			{dump-code} {
				expect_no_more_arguments
				command__dump_code
			}
			{dump-idata} {
				expect_no_more_arguments
				command__dump_idata
			}
			{dump-xdata} {
				expect_no_more_arguments
				command__dump_xdata
			}
			{dump-eeprom} {
				expect_no_more_arguments
				command__dump_eeprom
			}
			{dump-eram} {
				expect_no_more_arguments
				command__dump_eram
			}

			{write-code} {
				expect_integer 0 65536
				expect_integer 0 256
				expect_no_more_arguments

				command__write_code
			}
			{write-idata} {
				expect_integer 0 256
				expect_integer 0 256
				expect_no_more_arguments

				command__write_idata
			}
			{write-xdata} {
				expect_integer 0 65536
				expect_integer 0 256
				expect_no_more_arguments

				command__write_xdata
			}
			{write-eeprom} {
				expect_integer 0 65536
				expect_integer 0 256
				expect_no_more_arguments

				command__write_eeprom
			}
			{write-eram} {
				expect_integer 0 65536
				expect_integer 0 256
				expect_no_more_arguments

				command__write_eram
			}
			{write-sfr} {
				expect_integer 128 256
				expect_integer 0 256
				expect_no_more_arguments

				command__write_sfr
			}
			{write-sfr} {
				expect_string
				expect_integer 0 256
				expect_no_more_arguments

				command__write_sfr_by_name
			}
			{write-bit} {
				expect_integer 0 256
				expect_integer 0 256
				expect_no_more_arguments

				command__write_bit
			}

			{read-code} {
				expect_integer 0 65536
				expect_no_more_arguments

				command__read_code
			}
			{read-idata} {
				expect_integer 0 256
				expect_no_more_arguments

				command__read_idata
			}
			{read-xdata} {
				expect_integer 0 65536
				expect_no_more_arguments

				command__read_xdata
			}
			{read-eeprom} {
				expect_integer 0 65536
				expect_no_more_arguments

				command__read_eeprom
			}
			{read-eram} {
				expect_integer 0 65536
				expect_no_more_arguments

				command__read_eram
			}
			{read-sfr} {
				expect_integer 128 256
				expect_no_more_arguments

				command__read_sfr
			}
			{read-sfr-by-name} {
				expect_string
				expect_no_more_arguments

				command__read_sfr_by_name
			}
			{read-bit} {
				expect_integer 0 256
				expect_no_more_arguments

				command__read_bit
			}

			{step} {
				expect_no_more_arguments
				command__step
			}
			{step-back} {
				expect_no_more_arguments
				command__step_back
			}

			{list-changes} {
				expect_no_more_arguments
				command__list_changes
			}
			{read-pc} {
				expect_no_more_arguments
				command__read_pc
			}
			{write-pc} {
				expect_integer 0 65536
				expect_no_more_arguments

				command__write_pc
			}
			{read-position} {
				expect_no_more_arguments
				command__read_position
			}
			{reset} {
				expect_no_more_arguments
				command__reset
			}
			{run} {
				expect_no_more_arguments
				command__run
			}

			{input} {
				expect_integer 0 4
				expect_no_more_arguments

				command__input
			}
			{output} {
				expect_integer 0 4
				expect_no_more_arguments

				command__output
			}

			{hibernate} {
				expect_string
				expect_no_more_arguments

				command__hibernate
			}
			{resume} {
				expect_string
				expect_no_more_arguments

				command__resume
			}

			{core-dump} {
				expect_no_more_arguments
				command__core_dump
			}
			{core-alter} {
				expect_string
				expect_no_more_arguments

				command__core_alter
			}

			{exit} {
				expect_no_more_arguments
				return 1
			}
			default {
				report_error "Unrecognised command: \"$command\""
			}
		}
		return 0
	}

	proc abort_now {info} {
		report_error $info
		puts "ABORTING"
		exit 1
	}

	proc report_error {info} {
		variable error_reported
		variable line_counter
		variable command_line

		set error_reported 1
		puts stderr "ERROR (line: $line_counter; command: [lindex $command_line 0]): $info"
	}

	proc expect_no_more_arguments {} {
		variable command_line
		variable cmd_line_idx

		if {[llength $command_line] > $cmd_line_idx} {
			abort_now "Too many aguments given to to command [lindex $command_line 0]"
		}
	}

	proc expect_string {{max_length {}}} {
		variable command_line
		variable cmd_line_idx

		set arg [lindex $command_line $cmd_line_idx]
		if {![string length $arg]} {
			abort_now "Argument missing for command [lindex $command_line 0] at index $cmd_line_idx"
		} elseif {$max_length != {} && [string length $arg] > $max_length} {
			abort_now "Agrument given to command [lindex $command_line 0] at index $cmd_line_idx is too long, mimum allowed length is $max_length"
		}
		incr cmd_line_idx
	}

	proc expect_integer {{min {}} {max {}}} {
		variable command_line
		variable cmd_line_idx

		set arg [lindex $command_line $cmd_line_idx]
		if {![string is digit -strict $arg]} {
			abort_now "Non integer agrument given to command [lindex $command_line 0] at index $cmd_line_idx"
		} elseif {($min != {} && $arg < $min) || ($max != {} && $arg > $max)} {
			abort_now "Integer agrument given to command [lindex $command_line 0] at index $cmd_line_idx is out of its allowed range \[$min;$max\]"
		}
		incr cmd_line_idx
	}

	proc load_hex {set_command memory_size} {
		variable simulator

		set hex_data {}

		while {![eof stdin]} {
			set line [gets stdin]
			append hex_data $line "\n"

			# Stop when EOF sequnce is found
			if {[string range $line 7 8] == {01}} {
				break
			}
		}

		::IHexTools::free_resources
		::IHexTools::load_hex_data $hex_data
		if {${::IHexTools::error_count}} {
			report_error ${::IHexTools::error_string}
			return
		}

		if {${::IHexTools::highest_addr} >= $memory_size} {
			report_error "You are attempting to load more data than the memory capacity allows. Capacity: $memory_size; Required: [expr {${::IHexTools::highest_addr} + 1}]"
		}

		set val {}
		for {set i 0} {$i < ${::IHexTools::highest_addr}} {incr i} {
			set val [::IHexTools::get_value $i]
			if {$val == -1} {
				set val {}
			}
			$simulator $set_command $i $val
		}
		for {} {$i < $memory_size} {incr i} {
			$simulator $set_command $i {}
		}
	}

	# ----------------------------------------------------------------------
	# COMMANDS
	# ----------------------------------------------------------------------

	proc command__echo_on {} {
		variable echo 1
	}
	proc command__echo_off {} {
		variable echo 0
	}
	proc command__set_mcu {} {
		variable simulator
		variable command_line

		set new_processor [string toupper [lindex $command_line 1]]

		if {[lsearch -ascii -exact [SelectMCU::get_available_processors] $new_processor] == -1} {
			abort_now "Unsupported processor: [lindex $command_line 1]"
		}

		$simulator configure -P_option_mcu_type $new_processor
		set proc_data [SelectMCU::get_processor_details $new_processor]
		if {$proc_data == {}} {
			abort_now "Internal error"
		}
		$simulator configure -procData $proc_data

		$simulator simulator_initialize_mcu
	}
	proc command__set_clock {} {
		variable simulator
		variable command_line

		$simulator setEngineClock [lindex $command_line 1]
	}
	proc command__set_xcode {} {
		variable simulator
		variable command_line

		set arg [lindex $command_line 1]

		set icode [expr {[lindex [$simulator cget -procData] 2] * 1024}]
		if {$arg > (0xFFFF - $icode)} {
			abort_now "This MCU has CODE memory limit 0x10000 B (65536)"
		}

		if {[lindex [$simulator cget -procData] 1] != {yes}} {
			abort_now "This MCU cannot have connected external program memory"
		} else {
			$simulator configure -P_option_mcu_xcode $arg
			$simulator simulator_resize_code_memory $arg
		}
	}
	proc command__set_xdata {} {
		variable simulator
		variable command_line

		set arg [lindex $command_line 1]
		if {[lindex [$simulator cget -procData] 0] != {yes}} {
			abort_now "This MCU cannot have connected external data memory"
		} else {
			$simulator configure -P_option_mcu_xdata $arg
			$simulator simulator_resize_xdata_memory $arg
		}
	}
	proc command__reset {} {
		variable simulator
		$simulator master_reset -
	}

	proc command__load_code {} {
		variable simulator
		variable command_line

		load_hex setCodeDEC [expr {[$simulator cget -P_option_mcu_xcode] + ([lindex [$simulator cget -procData] 2] * 1024)}]
	}

	proc command__load_code_adf {} {
		variable simulator
		variable command_line

		if {[catch {
			set file [open [lindex $command_line 1] {r}]
		}]} then {
			abort_now "Unable to open file: [lindex $command_line 1]"
		}

		$simulator load_program_from_adf $file
		foreach filename [$simulator simulator_get_list_of_filenames] {
			$simulator Simulator_import_breakpoints $filename [list]
		}

		catch {
			close $file
		}
	}
	proc command__load_code_cdb {} {
		variable simulator
		variable command_line

		set filename [lindex $command_line 1]
		set cdb_flnm [lindex $command_line 2]
		set ihx_flnm [lindex $command_line 3]

		set cdb_file {}
		set ihx_file {}

		if {![file exists $filename]} {
			report_error "File does not exist: \"$filename\""
			return
		}

		if {[catch {
			set cdb_file [open $cdb_flnm {r}]
		}]} then {
			report_error "Cannot open file: \"$cdb_flnm\""
			return
		}
		if {[catch {
			set ihx_file [open $ihx_flnm {r}]
		}]} then {
			catch {close $cdb_file}
			report_error "Cannot open file: \"$ihx_flnm\""
			return
		}

		if {![$simulator load_program_from_cdb $filename $cdb_file $ihx_file]} {
			report_error ${::IHexTools::error_string}
		} else {
			foreach filename [$simulator simulator_get_list_of_filenames] {
				$simulator Simulator_import_breakpoints $filename [list]
			}
		}

		catch {close $cdb_file}
		catch {close $ihx_file}
	}
	proc command__load_idata {} {
		variable simulator
		variable command_line

		load_hex setDataDEC [lindex [$simulator cget -procData] 3]
	}
	proc command__load_xdata {} {
		variable simulator
		variable command_line

		load_hex setXdataDEC [$simulator cget -P_option_mcu_xdata]
	}
	proc command__load_eeprom {} {
		variable simulator
		variable command_line

		load_hex setEepromDEC [lindex [$simulator cget -procData] 32]
	}
	proc command__load_eram {} {
		variable simulator
		variable command_line

		load_hex setEramDEC [lindex [$simulator cget -procData] 8]
	}
	proc command__dump_code {} {
		variable simulator
		variable command_line

		set capacity [expr {[$simulator cget -P_option_mcu_xcode] + ([lindex [$simulator cget -procData] 2] * 1024)}]
		::IHexTools::free_resources
		for {set addr 0} {$addr < $capacity} {incr addr} {
			::IHexTools::content [$simulator getCode $addr]
		}
		puts -nonewline [::IHexTools::get_hex_data]
	}
	proc command__dump_idata {} {
		variable simulator
		variable command_line

		set capacity [lindex [$simulator cget -procData] 3]
		::IHexTools::free_resources
		for {set addr 0} {$addr < $capacity} {incr addr} {
			::IHexTools::content [$simulator getData $addr]
		}
		puts -nonewline [::IHexTools::get_hex_data]
	}
	proc command__dump_xdata {} {
		variable simulator
		variable command_line

		set capacity [$simulator cget -P_option_mcu_xdata]
		::IHexTools::free_resources
		for {set addr 0} {$addr < $capacity} {incr addr} {
			::IHexTools::content [$simulator getXdata $addr]
		}
		puts -nonewline [::IHexTools::get_hex_data]
	}
	proc command__dump_eeprom {} {
		variable simulator
		variable command_line

		set capacity [lindex [$simulator cget -procData] 32]
		::IHexTools::free_resources
		for {set addr 0} {$addr < $capacity} {incr addr} {
			::IHexTools::content [$simulator getEeprom $addr]
		}
		puts -nonewline [::IHexTools::get_hex_data]
	}
	proc command__dump_eram {} {
		variable simulator
		variable command_line

		set capacity [lindex [$simulator cget -procData] 8]
		::IHexTools::free_resources
		for {set addr 0} {$addr < $capacity} {incr addr} {
			::IHexTools::content [$simulator getEram $addr]
		}
		puts -nonewline [::IHexTools::get_hex_data]
	}
	proc command__write_code {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]
		set val  [lindex $command_line 2]

		if {![$simulator simulator_address_range C $addr]} {
			report_error "Invalid address: $addr"
		} else {
			$simulator setCodeDEC $addr $val
		}
	}
	proc command__write_idata {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]
		set val  [lindex $command_line 2]

		if {![$simulator simulator_address_range I $addr]} {
			report_error "Invalid I-DATA address: $addr"
		} else {
			$simulator setDataDEC $addr $val
		}
	}
	proc command__write_xdata {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]
		set val  [lindex $command_line 2]

		if {![$simulator simulator_address_range X $addr]} {
			report_error "Invalid X-DATA address: $addr"
		} else {
			$simulator setXdataDEC $addr $val
		}
	}
	proc command__write_eeprom {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]
		set val  [lindex $command_line 2]

		if {![$simulator simulator_address_range P $addr]} {
			report_error "Invalid EEPROM address: $addr"
		} else {
			$simulator setEepromDEC $addr $val
		}
	}
	proc command__write_eram {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]
		set val  [lindex $command_line 2]

		if {![$simulator simulator_address_range E $addr]} {
			report_error "Invalid ERAM address: $addr"
		} else {
			$simulator setEramDEC $addr $val
		}
	}
	proc command__write_sfr {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]
		set val  [lindex $command_line 2]

		if {![$simulator simulator_address_range S $addr]} {
			report_error "Invalid SFR address: $addr"
		} else {
			if {$addr == $::Simulator_ENGINE::symbol(SBUFR)} {
				set addr $::Simulator_ENGINE::symbol(SBUFT)
			}
			$simulator setSfrDEC $addr $val
		}
	}
	proc command__write_sfr_by_name {} {
		variable simulator
		variable command_line

		set name [lindex $command_line 1]
		set val  [lindex $command_line 2]

		if {[lsearch -ascii -exact [array names ::Simulator_ENGINE::symbol] [string toupper $name]] == -1} {
			report_error "Invalid SFR name: $name"
		} else {
			set addr $::Simulator_ENGINE::symbol([string toupper $name])

			if {![$simulator simulator_address_range S $addr]} {
				report_error "Invalid SFR address: $addr"
			} else {
				if {$addr == $::Simulator_ENGINE::symbol(SBUFR)} {
					set addr $::Simulator_ENGINE::symbol(SBUFT)
				}
				$simulator setSfrDEC $addr $val
			}
		}
	}
	proc command__write_bit {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]
		set val  [lindex $command_line 2]

		if {![$simulator simulator_address_range B $addr]} {
			report_error "Invalid BIT address: $addr"
		} else {
			$simulator setBit $addr
		}
	}
	proc command__read_code {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]

		if {![$simulator simulator_address_range C $addr]} {
			report_error "Invalid address: $addr"
		} else {
			puts [$simulator getCodeDEC $addr]
		}
	}
	proc command__read_idata {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]

		if {![$simulator simulator_address_range I $addr]} {
			report_error "Invalid I-DATA address: $addr"
		} else {
			puts [$simulator getDataDEC $addr]
		}
	}
	proc command__read_xdata {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]

		if {![$simulator simulator_address_range X $addr]} {
			report_error "Invalid X-DATA address: $addr"
		} else {
			puts [$simulator getXdataDEC $addr]
		}
	}
	proc command__read_eeprom {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]

		if {![$simulator simulator_address_range P $addr]} {
			report_error "Invalid EEPROM address: $addr"
		} else {
			puts [$simulator getEepromDEC $addr]
		}
	}
	proc command__read_eram {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]

		if {![$simulator simulator_address_range E $addr]} {
			report_error "Invalid ERAM address: $addr"
		} else {
			puts [$simulator getEramDEC $addr]
		}
	}
	proc command__read_sfr {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]

		if {![$simulator simulator_address_range S $addr]} {
			report_error "Invalid SFR address: $addr"
		} else {
			puts [$simulator getSfrDEC $addr]
		}
	}
	proc command__read_sfr_by_name {} {
		variable simulator
		variable command_line

		set name [lindex $command_line 1]
		set val  [lindex $command_line 2]

		if {[lsearch -ascii -exact [array names ::Simulator_ENGINE::symbol] [string toupper $name]] == -1} {
			report_error "Invalid SFR name: $name"
		} else {
			set addr $::Simulator_ENGINE::symbol([string toupper $name])

			if {![$simulator simulator_address_range S $addr]} {
				report_error "Invalid SFR address: $addr"
			} else {
				puts [$simulator getSfrDEC $addr]
			}
		}
	}
	proc command__read_bit {} {
		variable simulator
		variable command_line

		set addr [lindex $command_line 1]

		if {![$simulator simulator_address_range B $addr]} {
			report_error "Invalid BIT address: $addr"
		} else {
			puts [$simulator getBit $addr]
		}
	}
	proc command__step {} {
		variable simulator

		$simulator clear_changed_registers
		$simulator step
	}
	proc command__step_back {} {
		variable simulator

		$simulator clear_changed_registers
		puts [$simulator stepback]
	}
	proc command__list_changes {} {
		variable simulator
		variable command_line

		puts [$simulator get_changed_registers]
	}
	proc command__read_pc {} {
		variable simulator

		puts [$simulator getPC]
	}
	proc command__write_pc {} {
		variable simulator
		variable command_line

		$simulator setPC [lindex $command_line 1]
	}
	proc command__read_position {} {
		variable simulator
		variable command_line

		set pos [$simulator simulator_getCurrentLine]
		puts "F: \"[$simulator simulator_get_filename [lindex $pos 1]]\""
		puts "L: [lindex $pos 0]"
		puts "V: [lindex $pos 2]"
		puts "B: [lindex $pos 3]"
	}
	proc command__run {} {
		variable simulator
		$simulator sim_run
	}
	proc command__input {} {
		variable simulator
		variable command_line
		# TODO: Complete it
	}
	proc command__output {} {
		variable simulator
		variable command_line
		# TODO: Complete it
	}
	proc command__hibernate {} {
		variable simulator
		variable command_line
		# TODO: Complete it
	}
	proc command__resume {} {
		variable simulator
		variable command_line
		# TODO: Complete it
	}
	proc command__core_dump {} {
		variable simulator
		variable command_line
		# TODO: Complete it
	}
	proc command__core_alter {} {
		variable simulator
		variable command_line
		# TODO: Complete it
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

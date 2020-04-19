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
if { ! [ info exists _PALE_TCL ] } {
set _PALE_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# PALE (Peripheral Abstraction Layer Engine) - simulates virtual hardware
# --------------------------------------------------------------------------

if {$::GUI_AVAILABLE} {
	# Load base class for Virtual HW components
	source "${::LIB_DIRNAME}/pale/virtual_hw_component.tcl"

	# Load Virtual HW components
	source "${::LIB_DIRNAME}/pale/ledpanel.tcl"
	source "${::LIB_DIRNAME}/pale/leddisplay.tcl"
	source "${::LIB_DIRNAME}/pale/ledmatrix.tcl"
	source "${::LIB_DIRNAME}/pale/multiplexedleddisplay.tcl"
	source "${::LIB_DIRNAME}/pale/simplekeypad.tcl"
	source "${::LIB_DIRNAME}/pale/matrixkeypad.tcl"
	source "${::LIB_DIRNAME}/pale/lcd_hd44780.tcl"
	source "${::LIB_DIRNAME}/pale/ds1620.tcl"
	source "${::LIB_DIRNAME}/pale/virtual_uart_term.tcl"
	source "${::LIB_DIRNAME}/pale/file_interface.tcl"
}

class Pale {
	private variable scenario_file	{}	;# String: Name of PALE scenario file

	private variable portLatch	{}	;# List: Nx{5x{8x{...}}} States of port latches
	private variable portState	{}	;# List: Nx{5x{8x{...}}} True port states
	private variable portOutput	{}	;# List: Nx{5x{8x{...}}} True port outputs
	private variable portInput	{}	;# List: 5x{8x{...}} Port inputs
	private variable special_func	{}	;# List: Values of alternative port functions
	private variable portConfig		;# Array of Int: Index 0..4, defines port pin functions
	private variable portConfig_mod	0	;# Bool: $portConfig contain special configuration

	private variable instruction_cycles 0	;# Int: Number of instruction cycles performed during this simulation cycle

	private variable last_output	{}	;# List: 5x{8x{...}} Last port outputs
	private variable last_input	{}	;# List: 5x{8x{...}} Last port inputs
	private variable last_state	{}	;# List: 5x{8x{...}} Last true port states

	private variable input_devices	[list]	;# List of Object: Input devices (can affect true state)
	private variable output_devices	[list]	;# List of Object: Output devices (cannot affect true state)
	private variable engaged_pins		;# Array of Lists of Objects: Output devices which uses pin specified by index (index: (port_num,pin_num))

	private variable is_enabled	0	;# Bool: PALE sysetem on-line
	private variable modified	0	;# Bool: Modified flag

	## Object constructor
	 # Perform PALE sysetem reset
	constructor {} {
		pale_reset

		for {set p 0} {$p < 5} {incr p} {
			for {set b 0} {$b < 8} {incr b} {
				set engaged_pins($p,$b) {}
			}
		}
	}

	## Object destructor
	 # Save PALE scenarion file and destroy all PALE VHW components
	destructor {
		pale_save_scenario_file

		foreach dev [concat $output_devices $input_devices] {
			delete object $dev
		}
	}

	## Save PALE scenario under the specified file name
	 # @parm String filename - Name of the target file
	 # @return Bool - 1 upon success; 0 upon fail
	public method pale_save_as {filename} {
		set scenario_file_org $scenario_file
		set scenario_file [file join [$this cget -ProjectDir] $filename]

		# Adjust file extension
		if {![regexp {\.vhw$} $scenario_file]} {
			append scenario_file {.vhw}
		}

		if {[pale_save_scenario_file]} {
			return 1
		}

		set scenario_file $scenario_file_org
		return 0
	}

	## Save PALE scenario to a file
	 # If there is no predefined file name then it will call "::X::__save_as_VHW"
	 # @return Bool - 1 upon success; 0 upon fail
	public method pale_save {} {
		if {$scenario_file == {}} {
			::X::__save_as_VHW
			return 0
		}
		return [pale_save_scenario_file]
	}

	## Save PALE scenario to a file
	 # @return void
	public method pale_save_scenario_file {} {
		# Abort on empty file name
		if {$scenario_file == {}} {
			return 0
		}

		# Create a backup file
		catch {
			file rename -force $scenario_file "$scenario_file~"
		}

		# Try to open the file
		if {[catch {
			set file [open $scenario_file "w" 0640]
		}]} then {
			puts stderr "Unable to save to file: \"$scenario_file\""
			return 0
		}

		# Save data to the file
		puts $file "# MCU 8051 IDE: Virtual HW configuration file"
		puts $file "# Project: [$this cget -projectName]\n"
		foreach dev [concat $output_devices $input_devices] {
			puts $file [$dev get_config]
		}

		# Finalize
		catch {
			close $file
		}
		set modified 0
		return 1
	}

	## Get value of flag modified
	 # @return Bool - The modified flag
	public method pale_modified {} {
		return $modified
	}

	## Set flag modified
	 # @return Bool - Always 1
	public method pale_set_modified {} {
		set modified 1

		return 1
	}

	## Get name of PALE scenarion file
	 # @return String - Name of the file
	public method pale_get_scenario_filename {} {
		# Determinate project root path
		set prj_path [$this cget -projectPath]
		append prj_path {/}

		# Return relative directory location
		if {![string first $prj_path $scenario_file]} {
			return [string range $scenario_file [string length $prj_path] end]
		# Return absolute directory location
		} else {
			return $scenario_file
		}
	}

	## Remove all devices from the current scenarion
	 # @return void
	public method pale_remove_all_devices {} {
		foreach dev [concat $output_devices $input_devices] {
			delete object $dev
		}
	}

	## Reset pale to initial state
	 # @return void
	public method pale_forget_all {} {
		pale_remove_all_devices
		set scenario_file {}
		set modified 0
	}

	## Open the specified PALE scenarion file
	 # @parm String filename - Source file
	 # @return Int - Exit status
	 #	0 - Ok
	 #	1 - Error
	 #	2 - File is not usable
	public method pale_open_scenario {filename} {
		set filename [file join [$this cget -ProjectDir] $filename]
		if {
			![file exists $filename] ||
			![file isfile $filename] ||
			(!$::MICROSOFT_WINDOWS && ![file readable $filename])
		} then {
			return 0
		}

		pale_remove_all_devices

		set scenario_file $filename
		set modified 0
		return [pale_load_scenarion $filename]
	}

	## Import the specified PALE scenarion file
	 # @parm String filename - Source file
	 # @return Int - Exit status
	 #	0 - Ok
	 #	1 - Error
	 #	2 - File is not usable
	public method pale_load_scenarion {filename} {
		# Check for file usability
		if {![file exists $filename] || ![file isfile $filename] || (!$::MICROSOFT_WINDOWS && ![file readable $filename])} {
			return 2
		}

		# Try to open the specified file
		if {[catch {
			set file [open $filename {r}]
		}]} then {
			puts stderr "Unable to open file: \"$scenario_file\", that might not be important ..."
			return 1
		}

		# Read the file line by line
		set result 0
		while {![eof $file]} {
			set line [gets $file]

			# Skip empty lines and comments
			if {$line == {} || [regexp {^\s*#} $line]} {continue}

			# Decomposite file records
			set obj [lindex $line 0]	;# VHW component class name
			set conf [lindex $line 1]	;# VHW component configuration

			# Create component object and set its configuration
			if {[catch {
				set obj [$obj ::#auto $this]
				$obj set_config $conf
			# Error detected
			}]} then {
				puts stderr "Unable to create PALE object: \"$obj\", maybe you are using an old version of MCU 8051 IDE.\n"
				puts stderr $::errorInfo

				catch {
					delete object $obj
				}

				set result 1
			}
		}

		# Finalize ...
		catch {
			close $file
		}
		set modified 1
		return $result
	}

	## Reset whole PALE system
	 # @return void
	public method pale_reset {} {
		set portConfig_mod 0
		array set portConfig	{
			0 {0 0 0 0 0 0 0 0}
			1 {0 0 0 0 0 0 0 0}
			2 {0 0 0 0 0 0 0 0}
			3 {0 0 0 0 0 0 0 0}
			4 {0 0 0 0 0 0 0 0}
		}
		set last_output [list		\
			[list 1 1 1 1 1 1 1 1]	\
			[list 1 1 1 1 1 1 1 1]	\
			[list 1 1 1 1 1 1 1 1]	\
			[list 1 1 1 1 1 1 1 1]	\
			[list 1 1 1 1 1 1 1 1]	\
		]
		set last_input $last_output
		set last_state $last_output
		set portState [list $last_output]

		foreach dev [concat $input_devices $output_devices] {
			$dev reset
		}

		pale_reevaluate_IO
	}

	## Withdraw windows of all PALE components
	 # Usefull to speedup exit program procedure
	 # @return void
	public method pale_withdraw_all_windows {} {
		foreach dev [concat $output_devices $input_devices] {
			$dev withdraw_window
		}
	}

	## Inform pale about interrupt comminted by simulatoe
	 # @parm Int vector - Interrupt vector
	 # @return void
	public method pale_interrupt {vector} {
		$this graph_draw_interrupt_line
	}

	## Perform one PALE simulation cycle
	 # @parm List - State of 5 port latches
	 # @return void
	public method pale_simulation_cycle args {
		if {!$is_enabled} {return}

		set ports [list]
		foreach byte [lindex $args 0] {
			set byte [NumSystem::dec2bin $byte]
			set bin_len [string length $byte]
			if {$bin_len < 8} {
				set byte "[string repeat {0} [expr {8 - $bin_len}]]$byte"
			}

			lappend ports [split $byte {}]
		}
		lappend portLatch $ports
		incr instruction_cycles
	}

	## Set Line Special Function (Bypass port latch)
	 # @parm List port_and_bit	- {port_number bit_number}
	 # @parm Int type		- Function
	 #	0 - Nomal operation -- port latch is outputed
	 #	1 - Special logical IO function (UART, triggers, external memory, etc.)
	 #	2 - High speed digital output (possibly a few pulses per instruction cycle)
	 #	3 - PWM output (it's low speed logical output)
	 #	4 - Analog comparator input (accepts values between 0 and 1)
	 #	5 - External memory
	 #	6 - Not implemented pin
	 # @return void
	public method pale_SLSF {port_and_bit type} {
		# Modify ports configuration
		lset portConfig([lindex $port_and_bit 0])	\
			[expr {7 - [lindex $port_and_bit 1]}] $type

		# Adjust flag portConfig_mod
		set portConfig_mod 0
		for {set i 0} {$i < 5} {incr i} {
			for {set j 0} {$j < 5} {incr j} {
				if {[lindex $portConfig($i) $j] != 0} {
					set portConfig_mod 1
					return
				}
			}
		}
	}

	## Read Real Port Voltage - 8 bit value (0..255)
	 # @parm Int port - Port number
	 # @return Int - Port value
	public method pale_RRPV {port} {
		if {!$is_enabled} {return 255}

		set result_tmp [lindex $portState [list end $port]]
		set result {}
		foreach bit $result_tmp {
			switch -- $bit {
				{?} {	;# No volatge
					append result [expr {rand() < 0.5}]
				}
				{X} {	;# Access to external memory
					append result [expr {rand() < 0.5}]
				}
				{-} {	;# Indeterminable value (some noise)
					append result [expr {rand() < 0.5}]
				}
				{|} {	;# High frequency
					append result 1
				}
				{=} {	;# High forced to low
					append result 0
				}
				default {
					append result $bit
				}
			}
		}
		set result [NumSystem::bin2dec $result]
		return $result
	}

	## Read Real Port Pin Voltage - 1 bit value (0 or 1)
	 # @parm List pn_bn	- {port_number bit_number}
	 # @parm Int position=0	- Position in history (positive number)
	 # @return Bool - Boolean value
	public method pale_RRPPV {pn_bn {position 0}} {
		if {!$is_enabled} {return 1}

		# Parse input arguments
		set port	[lindex $pn_bn 0]
		set bit		[lindex $pn_bn 1]

		# Adjust arguments
		if {$position < 0} {
			set position [expr {[llength $portState] + $position}]
		}
		set bit [expr {7 - $bit}]

		# Evaluate result
		set result [lindex $portState [list $position $port $bit]]
		switch -- $result {
			{?} {	;# No volatge
				return [expr {rand() < 0.5}]
			}
			{X} {	;# Access to external memory
				return [expr {rand() < 0.5}]
			}
			{|} {	;# High frequency
				return 1
			}
			{1} {	;# Logical 1
				return 1
			}
			{0} {	;# Logical 0
				return 0
			}
			{=} {	;# High forced to low
				return 0
			}
			default {
				return 1
			}
		}
	}

	## Write to port with bypassed latch (takes effect on next simulation cycle)
	 # @parm Int port	- Port number
	 # @parm List value 	- New value -- list of 8 values {bit0 bit1 bit2 ... bit7}
	 #	'0' - Logical 0
	 #	'1' - Logical 1
	 #	'|' - High frequency pulse
	 #	'X' - Access to external memory
	 #	'?' - No volatge
	 #	'-' - Indeterminable value (some noise)
	 #	'=' - High forced to low
	 # @parm Int position=0	- Position in history (zero or negative number)
	 # @return void
	public method pale_WPBL {port value {position 0}} {
		if {!$is_enabled} {return}

		# Set value
		for {set bit 0} {$bit < 8} {incr bit} {
			lappend special_func [list $port $bit $value $position]
		}
	}

	## Write to port bit with bypassed latch
	 # @parm List pn_bn	- {port_number bit_number}
	 # @parm Char value	- New value
	 #	'0' - Logical 0
	 #	'1' - Logical 1
	 #	'|' - High frequency pulse
	 #	'X' - Access to external memory
	 #	'?' - No volatge
	 #	'-' - Indeterminable value (some noise)
	 #	'=' - High forced to low
	 # @parm Int position=0	- Position in history (zero or negative number)
	 # @return void
	public method pale_WPBBL {pn_bn value {position 0}} {
		if {!$is_enabled} {return}

		# Parse input arguments
		set port	[lindex $pn_bn 0]
		set bit		[lindex $pn_bn 1]

		set bit [expr {7 - $bit}]

		# Set value
		lappend special_func [list $port $bit $value $position]
	}

	## Finalize this simulation cycle
	 # @return void
	public method pale_finish_simulation_cycle {} {
		if {!$is_enabled} {return}

		# ---------------------------------------------------
		# DETERMINATE TRUE OUTPUT VALUES
		# ---------------------------------------------------
		set portOutput $portLatch

		if {$portConfig_mod} {
			# Adjust port outputs to contain '#' where are the
			#+ bits with active alternative function
			for {set port 0} {$port < 5} {incr port} {
				for {set bit 0} {$bit < 8} {incr bit} {
					switch -- [lindex $portConfig($port) $bit] {
						0 {	;# Nomal operation -- port latch is outputed
						}
						1 {	;# Special logical IO function (UART, triggers, external memory, etc.)
							for {set i 0} {$i < $instruction_cycles} {incr i} {
								lset portOutput [list $i $port $bit] {#}
							}
						}
						2 {	;# High speed digital output (possibly a few pulses per machine cycle)
							for {set i 0} {$i < $instruction_cycles} {incr i} {
								lset portOutput [list $i $port $bit] {#}
							}
						}
						3 {	;# PWM output (it's low speed logical output)
							for {set i 0} {$i < $instruction_cycles} {incr i} {
								lset portOutput [list $i $port $bit] {#}
							}
						}
						4 {	;# Analog comparator input (accepts values between 0 and 1)
							for {set i 0} {$i < $instruction_cycles} {incr i} {
								lset portOutput [list $i $port $bit] {?}
							}
						}
						5 {	;# Access to external memory
							for {set i 0} {$i < $instruction_cycles} {incr i} {
								lset portOutput [list $i $port $bit] {X}
							}
						}
						6 {	;# Not implemented pin
							for {set i 0} {$i < $instruction_cycles} {incr i} {
								lset portOutput [list $i $port $bit] {?}
							}
						}
					}
				}
			}
			# Adjust port outputs to contain values generated by alternaive functions
			foreach spec $special_func {
				set port	[lindex $spec 0]
				set bit		[lindex $spec 1]
				set value	[lindex $spec 2]
				set position	[lindex $spec 3]

				incr position $instruction_cycles
				incr position -1

				lset portOutput [list $position $port $bit] $value
			}
			# Adjust port outputs to repeat previous values on
			#+ bits with active alternative function.
			#+ In other words, eliminate all '#' and replace them with reasonable values
			for {set i -1; set j 0} {$j < $instruction_cycles} {incr i; incr j} {
				if {$i < 0} {
					set previous_output_state $last_output
				} else {
					set previous_output_state [lindex $portOutput $i]
				}
				foreach prev $previous_output_state new [lindex $portOutput $j] port {0 1 2 3 4} {
					if {[lsearch -ascii -exact $new {#}] != -1} {
						foreach p $prev n $new bit {0 1 2 3 4 5 6 7} {
							switch -- $n {
								{#} {	;# Repeat last value
									lset portOutput [list $j $port $bit] $p
								}
							}
						}
					}
				}
			}
		}

		# ---------------------------------------------------
		# DETERMINATE TRUE STATE
		# ---------------------------------------------------

		# Call input devices to evaluate input values
		read_port_input

		# Determinate true port states using function "pale_combine_values"
		#+ and graw graphs
		set graw_graph	[expr {![$this sim_run_in_progress]}]
		set portState	[list]
		set state_one_p [list]
		set state_all_p [list]
		for {set i 0} {$i < $instruction_cycles} {incr i} {
			foreach output [lindex $portOutput $i] input [lindex $portInput $i] {
				foreach out $output in $input {
					lappend state_one_p [pale_combine_values $in $out]
				}

				lappend state_all_p $state_one_p
				set state_one_p [list]
			}

			if {$graw_graph} {
				$this graph_new_output_state L [lindex $portLatch $i]
				$this graph_new_output_state O [lindex $portOutput $i]
				$this graph_new_output_state S $state_all_p
			}

			lappend portState $state_all_p
			set state_all_p [list]
		}

		# Clean up
		set instruction_cycles 0
		set last_output [lindex $portOutput end]
		set last_input [lindex $portInput end]
		set last_state [lindex $portState end]
		set portLatch [list]
		set portOutput [list]
		set portInput [list]
		set special_func [list]

		# Inform output devices about the new port outputs
		foreach dev $output_devices {
			$dev new_state last_state
		}
		update
	}

	## Determinate resulting value when two values clash on one wire
	 # @parm Char in0 - 1st wire state
	 # @parm Char in1 - The other wire state
	 # @return Char - Resulting state
	public method pale_combine_values {in0 in1}  {
		if {$in1 == 0} {
			return {0}
		} elseif {$in1 == {}} {
			return $in0
		}
		switch -- $in0 {
			{|} {	;# High frequency
				if {$in1 == 1 || $in1 == {|} || $in1 == {?}} {
					return {|}
				} else {
					return {-}
				}
			}
			{X} {	;# Access to external memory
				if {$in1 == 1 || $in1 == {X} || $in1 == {?}} {
					return {X}
				} else {
					return {-}
				}
			}
			{?} {	;# No volatge
				return $in1
			}
			{-} {	;# Indeterminable value (some noise)
				return {-}
			}
			{=} {	;# High forced to low
				return {=}
			}
			{0} {	;# Logical 0
				return 0
			}
			{1} {	;# Logical 1
				if {$in1 == {?}} {
					return 1
				} else {
					return $in1
				}
			}
			{} {	;# Not connected
				return $in1
			}
			default {
				error "ERROR in function pale_combine_value\npale_combine_values {{$in0} {$in1}}"
			}
		}
	}

	## Reevaluate inputs & outputs for all PALE devices and the MCU
	 # @return void
	public method pale_reevaluate_IO {} {
		# Get last output
		set input $last_output

		# Call all input devices
		foreach dev $input_devices {
			# Call device to change the current state
			$dev new_state input

			# Clear list of devices already confronted with the new state
			set already_evaluated [list]

			# Inform all other devices interconnected with this one
			for {set p 0} {$p < 5} {incr p} {
				for {set b 0} {$b < 8} {incr b} {
					# Search for connected devices
					set idx [lsearch -ascii -exact $engaged_pins($p,$b) $dev]
					if {$idx == -1} {
						continue
					}
					if {[llength $engaged_pins($p,$b)] == 1} {
						continue
					}

					# Call all affected devices
					foreach affected_dev $engaged_pins($p,$b) {
						# Do not confront the device with itself
						if {$affected_dev == $dev} {
							continue
						}

						# Do not confront the device with another device more than once per ``foreach dev ...'' iteration
						if {[lsearch -ascii -exact $already_evaluated $affected_dev] != -1} {
							continue
						}

						lappend already_evaluated $affected_dev
						$affected_dev new_state input
					}

					# Again call the current device
					$dev new_state input
				}
			}
		}
		set last_input $input

		# Determinate true port states using function "pale_combine_values"
		set state_one_p [list]
		set last_state [list]
		foreach output $last_output input $last_input {
			foreach out $output in $input {
				lappend state_one_p [pale_combine_values $in $out]
			}

			lappend last_state $state_one_p
			set state_one_p [list]
		}

		# Update more complex information about true port states
		set portState [lreplace $portState end end $last_state]

		# Inform output devices about the new port outputs
		foreach dev $output_devices {
			$dev new_state last_state
		}
		update
	}

	## Call input devices to evaluate input values
	 # @return void
	private method read_port_input {} {
		# Get last output
		set input [lindex $portOutput end]

		# Call all input devices
		foreach dev $input_devices {
			# Call device to change the current state
			$dev new_state input

			# Clear list of devices already confronted with the new state
			set already_evaluated [list]

			# Inform all other devices interconnected with this one
			for {set p 0} {$p < 5} {incr p} {
				for {set b 0} {$b < 8} {incr b} {
					# Search for connected devices
					set idx [lsearch -ascii -exact $engaged_pins($p,$b) $dev]
					if {$idx == -1} {
						continue
					}
					if {[llength $engaged_pins($p,$b)] == 1} {
						continue
					}

					# Call all affected devices
					foreach affected_dev $engaged_pins($p,$b) {
						# Do not confront the device with itself
						if {$affected_dev == $dev} {
							continue
						}

						# Do not confront the device with another device more than once per ``foreach dev ...'' iteration
						if {[lsearch -ascii -exact $already_evaluated $affected_dev] != -1} {
							continue
						}

						$affected_dev new_state input
					}

					# Again call the current device
					$dev new_state input
				}
			}
		}

		# Fill in list of port onputs
		for {set i 1} {$i < $instruction_cycles} {incr i} {
			lappend portInput $last_input
		}
		lappend portInput $input
	}

	## Adjust PALE to new state "ON/OFF"
	 # @parm Bool _is_enabled - 1 == Turn on; 0 == Turn off
	 # @return void
	public method pale_on_off {_is_enabled} {
		set is_enabled $_is_enabled

		foreach dev [concat $input_devices $output_devices] {
			$dev on_off $is_enabled
		}
	}

	## Turn whole PALE system on or off
	 # @return void
	public method pale_all_on_off {} {
		$this graph_change_status_on
	}

	## Determinate whether PALE is on-line or not
	 # @return Bool - 1 == online; 0 - offline
	public method pale_is_enabled {} {
		return $is_enabled
	}

	## Inform PALE about new output device (device which CANNOT affect port inputs)
	 # Every output device must be registred in PALE system in
	 #+ this way otherwise it wont work !
	 # @parm Object object - PALE VHW component object reference
	 # @return void
	 #
	 # Note: PALE VHW component must extend class "VirtualHWComponent"
	public method pale_register_output_device {object} {
		lappend output_devices $object
	}

	## Unregister device prevously registred by "pale_register_output_device"
	 # @parm Object object - PALE VHW component object reference
	 # @return void
	public method pale_unregister_output_device {object} {
		set idx [lsearch -ascii -exact $output_devices $object]
		if {$idx == -1} {
			return
		}
		set output_devices [lreplace $output_devices $idx $idx]
	}

	## Inform PALE about new input device (device which CAN affect port inputs)
	 # Every input device must be registred in PALE system in
	 #+ this way otherwise it wont work !
	 # @parm Object object - PALE VHW component object reference
	 # @return void
	 #
	 # Note: PALE VHW component must extend class "VirtualHWComponent"
	public method pale_register_input_device {object} {
		lappend input_devices $object
	}

	## Unregister device prevously registred by "pale_register_input_device"
	 # @parm Object object - PALE VHW component object reference
	 # @return void
	public method pale_unregister_input_device {object} {
		# Find the specified device
		set idx [lsearch -ascii -exact $input_devices $object]
		if {$idx == -1} {
			return
		}

		# Unregister the device
		set input_devices [lreplace $input_devices $idx $idx]

		# Disconnect the device from all other devices
		for {set p 0} {$p < 5} {incr p} {
			for {set b 0} {$b < 8} {incr b} {
				pale_disengage_pin_by_input_device $p $b $object
			}
		}

		# Make this change in the environment visible right away
		pale_reevaluate_IO
	}

	## Inform PALE system about that than some input device is
	 #+ connected to the specified port and pin.
	 #
	 # THIS IS VERY IMPORTANT FUNCTION to achieve correct PALE
	 # system functionality !!!
	 #
	 # @parm Int port	- Port number		(0..4)
	 # @parm Int pin	- Port bit number	(0..7)
	 # @parm Object dev	- Input device (PALE VHW component)
	 # @return void
	 #
	 # Notes:
	 #	* PALE VHW component must extend class "VirtualHWComponent"
	 #	* Input devices CAN affect port inputs, output cannot
	public method pale_engage_pin_by_input_device {port pin dev} {
		if {[lsearch -ascii -exact $engaged_pins($port,$pin) $dev] != -1} {
			return
		}
		lappend engaged_pins($port,$pin) $dev
	}

	## Inform PALE system about that than some input device is
	 #+ no longer connected to the specified port and pin.
	 # In other words the right opposite of method
	 # "pale_engage_pin_by_input_device".
	 #
	 # THIS IS VERY IMPORTANT FUNCTION to achieve correct PALE
	 # system functionality !!!
	 #
	 # @parm Int port	- Port number		(0..4)
	 # @parm Int pin	- Port bit number	(0..7)
	 # @parm Object dev	- Input device (PALE VHW component)
	 # @return void
	 #
	 # Notes:
	 #	* PALE VHW component must extend class "VirtualHWComponent"
	 #	* Input devices CAN affect port inputs, output cannot
	public method pale_disengage_pin_by_input_device {port pin dev} {
		set idx [lsearch -ascii -exact $engaged_pins($port,$pin) $dev]

		if {$idx == -1} {
			return
		}

		set engaged_pins($port,$pin)	\
			[lreplace $engaged_pins($port,$pin) $idx $idx]
	}

	## Determinate whether the specified port pin is engaged
	 # by any input device
	 # @parm Int port	- Port number		(0..4)
	 # @parm Int pin	- Port bit number	(0..7)
	 # @return void
	 #
	 # Note: Input devices CAN affect port inputs, output cannot
	public method pale_is_engaged {port pin} {
		return $engaged_pins($port,$pin)
	}

	## Get true port outputs (that means latches plus alternate functions)
	 # @return List of Char - 5 x {8 x $bit_val} -- {bit0 bit1 bit2 ... bit7}
	 #	$bit_val can be one of the following values:
	 #		'0' - Logical 0
	 #		'1' - Logical 1
	 #		'|' - High frequency pulse
	 #		'X' - Access to external memory
	 #		'?' - No volatge
	 #		'-' - Indeterminable value (some noise)
	 #		'=' - High forced to low
	public method pale_get_output_state {} {
		return $last_output
	}

	## Get true port states
	 # @return List of Char - 5 x {8 x $bit_val} -- {bit0 bit1 bit2 ... bit7}
	 #	$bit_val can be one of the following values:
	 #		'0' - Logical 0
	 #		'1' - Logical 1
	 #		'|' - High frequency pulse
	 #		'X' - Access to external memory
	 #		'?' - No volatge
	 #		'-' - Indeterminable value (some noise)
	 #		'=' - High forced to low
	public method pale_get_true_state {} {
		return $last_state
	}

	## Get list of available port number on the current MCU
	 # @return List of Int - e.g. {1 3}
	public method pale_get_available_ports {} {
		return [lindex [$this get_ports_info] 1]
	}

	## Inform PALE sysetem about MCU change
	 # @return void
	public method pale_MCU_changed {} {
		foreach dev [concat $input_devices $output_devices] {
			$dev mcu_changed
		}
	}

	## Get number of instruction cycles performed during this simulation cycle
	 # @return Int - Number of instruction cycles
	public method pale_get_number_of_instruction_cycles {} {
		return $instruction_cycles
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

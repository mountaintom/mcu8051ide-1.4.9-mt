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
if { ! [ info exists _IHEXTOOLS_TCL ] } {
set _IHEXTOOLS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides some tools for manipulating IHEX8, binary and sim files.
# It's intented for converting between these file types and for
# normalizing hex files.
# --------------------------------------------------------------------------

namespace eval IHexTools {

	## PUBLIC
	variable update 	0	;# Bool: Periodicaly update GUI and increment progress
	variable abort		0	;# Bool: Abort currently running procedure
	variable progress	1	;# Int: Variable for progress bars
	variable error_count	0	;# Int: Count of errors
	variable error_string	{}	;# Error messages
	variable highest_addr	0	;# Int: Highest address in loaded IHEX file

	## PRIVATE
	variable content		;# Array: Currently loaded data (content(0..65535) => 00..FF)
	variable INITIALIZED	0	;# Bool: Namespace variables initialized
	variable data_field		;# Auxiliary variable for creating IHEX records
	variable data_field_len		;# Auxiliary variable for creating IHEX records


	# ----------------------------------------------------------------
	# GENERAL PURPOSE PROCEDURES
	# ----------------------------------------------------------------

	## Compute checksum for the given HEX field (without leading colon)
	 # @parm String hex_data - HEX field without leading colon
	 # @return String - resulting hexadecimal checksum
	proc getCheckSum {hex_data} {

		set sum 256	;# Initial checksum
		set hex_data [split $hex_data {}]

		# Iterate over hex data
		for {set i 0} {1} {incr i} {

			# Gain 1st hex digit
			set val [lindex $hex_data $i]

			# If the 1st digit is empty -> return result
			if {$val == {}} {
				# Handle overflow
				if {$sum == 256} {return {00}}
				# Convert decimal checksum to hexadecimal
				set sum [format "%X" $sum]
				if {[string length $sum] == 1} {
					set sum "0$sum"
				}
				return $sum
			}

			# Gain 2nd hex digit
			incr i
			append val [lindex $hex_data $i]
			set val [expr "0x$val"]

			# Decrement checksum
			incr sum -$val

			# Handle undeflow
			if {$sum < 0} {incr sum 256}
		}
	}

	## Get maximum value for progressbar when loading hex or sim file
	 # @parm String data - input sim or hex data
	 # @return Int - number of iterations divided by 25
	proc get_number_of_iterations {data} {
		# Any EOL to LF
		regsub -all {\r\n?} $data "\n" data

		# Local variables
		set result 0	;# Resulting number
		set index 0	;# Last search result

		# Get number of LF chracters
		while {1} {
			set index [string first "\n" $data $index]
			if {$index == -1} {break}
			incr index
		}

		# Return result
		return [expr {$result / 25 + 1}]
	}

	## Load IHEX 8 file into internal memory
	 # @parm String hex_data - Content of IHEX8 file to load
	 # @return Bool - result
	proc load_hex_data {hex_data} {
		variable INITIALIZED		;# Bool: Namespace variables initialized

		variable content		;# Array: Currently loaded data
		variable update			;# Bool: Periodicaly update GUI and increment progress
		variable abort		0	;# Bool: Abort currently running procedure
		variable progress	1	;# Int: Variable for progress bars
		variable error_count	0	;# Int: Count of errors
		variable error_string	{}	;# Error messages
		variable highest_addr	0	;# Int: Highest address in loaded IHEX file

		# Initialize array of loaded data
		if {!$INITIALIZED} {
			free_resources
		}
		# Convert any EOL to LF
		regsub -all {\r\n?} $hex_data "\n" hex_data

		# Local variables
		set lineNum	0	;# Number of the current line
		set eof		0	;# Bool: EOF detected

		# Iterate over HEX records
		foreach line [split $hex_data "\n"] {
			incr lineNum	;# Increment line number

			# Skip comments
			if {[string index $line 0] != {:}} {continue}

			# Check for valid charters
			if {![regexp {^:[0-9A-Fa-f]+$} $line]} {
				Error $lineNum [mc "Line contains invalid characters"]
				continue
			}
			# Check for odd lenght
			set len [string length $line]
			if {[expr {$len % 2}] != 1} {
				Error $lineNum [mc "Line contains even number of characters"]
				continue
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
				Error $lineNum [mc "Unknown record type '%s'" $type]
				continue
			}

			# Check for valid checksum
			set new_check [getCheckSum $line]
			if {$new_check != $check} {
				Error $lineNum [mc "Bad checksum"]
				continue
			}

			# Check for correct value of the length field
			set len [expr "0x$len"]
			if {([string length $data] / 2) != $len} {
				Error $lineNum [mc "Bad length"]
				continue
			}

			# Parse and load data field
			set addr [expr "0x$addr"]
			for {set i 0; set j 1} {$i < ($len * 2)} {incr i 2; incr j 2} {
				set content($addr) [string range $data $i $j]
				incr addr
			}

			# Store highest address
			if {$addr > $highest_addr} {
				set highest_addr $addr
			}

			# Update GUI and progress variable
			if {$update} {
				if {![expr {$lineNum % 25}]} {
					# Conditional abort
					if {$abort} {return 0}
					# Update progress variable and GUI
					incr progress
					update
				}
			}
		}

		# If there is no EOF then report that as an error
		if {!$eof} {
			Error - [mc "Missing EOF"]
		}

		# Return result
		if {$error_count} {
			return 0
		} else {
			return 1
		}
	}

	## Load binary file into internal memory
	 # @parm String data - Binary data to load
	 # @return Bool - result
	proc load_bin_data {data} {
		variable INITIALIZED		;# Bool: Namespace variables initialized

		variable content		;# Array: Currently loaded data
		variable update			;# Bool: Periodicaly update GUI and increment progress
		variable abort		0	;# Bool: Abort currently running procedure
		variable progress	1	;# Int: Variable for progress bars
		variable error_count	0	;# Int: Count of errors
		variable error_string	{}	;# Error messages

		# Initialize array of loaded data
		if {!$INITIALIZED} {
			free_resources
		}

		# Check for allowed data length
		set len [string length $data]
		if {$len > 0x10000} {
			Error - [mc "Data length exceeding limit 0x10000"]
			return 0
		}

		# Load data
		set val 0
		for {set i 0} {$i < $len} {incr i} {
			binary scan [string index $data $i] c val			;# bin -> dec
			set content($i) [string range [format %X $val] end-1 end]	;# dec -> hex
		}
		return 1
	}

	## Load simulator file into internal memory
	 # @parm String data - Content of simulator file to load
	 # @return Bool - result
	proc load_sim_data {data} {
		variable INITIALIZED		;# Bool: Namespace variables initialized

		variable content		;# Array: Currently loaded data
		variable update			;# Bool: Periodicaly update GUI and increment progress
		variable abort		0	;# Bool: Abort currently running procedure
		variable progress	1	;# Int: Variable for progress bars
		variable error_count	0	;# Int: Count of errors
		variable error_string	{}	;# Error messages

		# Initialize array of loaded data
		if {!$INITIALIZED} {
			free_resources
		}

		# Adjust input data
		regsub -all {\r\n?} $data "\n" data		;# Any EOL to LF
		regsub -all {\s*#[^\n]*\n} $data {} data	;# Remove comments

		set lineNum -1	;# Line number

		# Iterate over lines in the given data
		foreach line [split $data "\n"] {
			incr lineNum	;# Increment line number

			# Discard the first line
			if {!$lineNum} {
				continue
			}

			# Skip empty lines
			if {$line == {}} {continue}

			# Anylize line
			set ln		[lindex $line 0]	;# Line number
			set addr	[lindex $line 1]	;# Address
			set line	[lreplace $line 0 1]	;# Processor codes

			# Check for validity of line number
			if {![string is digit -strict $ln]} {
				Error $lineNum [mc "Invalid line number '%s'" $ln]
				continue
			}
			# Check for validity of address
			if {![string is digit -strict $addr]} {
				Error $lineNum [mc "Invalid address '%s'" $addr]
				continue
			}
			# Check for allowed characters
			if {![regexp {^[\d \t]+$} $line] || ![llength $line]} {
				Error $lineNum [mc "Invalid data field"]
				continue
			}

			# Load processor codes
			foreach val $line {
				set content($addr) [format %X $val]
				incr addr
			}

			# Update GUI and progress variable
			if {$update} {
				if {![expr {$lineNum % 25}]} {
					# Conditional abort
					if {$abort} {return 0}
					# Update progress variable and GUI
					incr progress
					update
				}
			}
		}

		# Return result
		if {$error_count} {
			return 0
		} else {
			return 1
		}
	}

	## Get loaded data as binary string
	 # @return String - Resulting binary data
	proc get_bin_data {} {
		variable content		;# Array: Currently loaded data
		variable update			;# Bool: Periodicaly update GUI and increment progress
		variable abort		0	;# Bool: Abort currently running procedure
		variable progress	1	;# Int: Variable for progress bars

		# Local variables
		set addr	0	;# Current address
		set pad		{}	;# Padding
		set result	{}	;# Resulting binary string

		# Load data and convert them (16 x 4096 interations)
		for {set j 0} {$j < 16} {incr j} {
			for {set i 0} {$i < 4096} {incr i} {
				# Get hexadecimal value
				set hex $content($addr)
				# Convert it to binary value
				if {$hex == {}} {
					append pad "\0"
				} else {
					if {$pad != {}} {
						append result $pad
						set pad {}
					}
					append result [subst -nocommands "\\x$hex"]
				}
				# Increment address
				incr addr
			}

			# Update GUI and progress variable
			if {$update} {
				# Update progress variable and GUI
				incr progress
				update
				# Conditional abort
				if {$abort} {
					return {}
				}
			}
		}

		# Return resulting binary string
		return $result
	}

	## Get loaded data as IHEX8
	 # @return String - Resulting IHEX8
	proc get_hex_data {} {
		variable content		;# Array: Currently loaded data
		variable update			;# Bool: Periodicaly update GUI and increment progress
		variable abort		0	;# Bool: Abort currently running procedure
		variable progress	1	;# Int: Variable for progress bars
		variable data_field		;# Auxiliary variable for creating IHEX records
		variable data_field_len		;# Auxiliary variable for creating IHEX records

		# Local variables
		set pointer		0	;# Current address
		set data_field_len	0	;# IHEX8 Data field lenght
		set data_field		{}	;# IHEX8 Data field
		set result		{}	;# Resulting IHEX8

		# Load data (16 x 4096 interations)
		for {set j 0} {$j < 16} {incr j} {
			for {set i 0} {$i < 4096} {incr i} {
				# Determinate HEX value
				set hex $content($pointer)

				# If HEX value if empty -> write record
				if {$hex == {} && $data_field_len} {
					create_hex_record [expr {$pointer - $data_field_len}]
					append result $data_field
					set data_field {}

				# Append HEX value to the current data field
				} elseif {$hex != {}} {
					if {[string length $hex] == 1} {
						set hex "0$hex"
					}

					append data_field $hex
					incr data_field_len
				}

				# Increment current address
				incr pointer

				# If data field length is high -> write record
				if {$data_field_len == ${::Compiler::Settings::max_ihex_rec_length}} {
					create_hex_record [expr {$pointer - $data_field_len}]
					append result $data_field
					set data_field {}
				}
			}

			# Update GUI and progress variable
			if {$update} {
				# Update progress variable and GUI
				incr progress
				update
				# Conditional abort
				if {$abort} {
					return {}
				}
			}
		}

		# Append EOF and return result
		append result {:00000001FF}
		append result "\n"
		return $result
	}

	## Free used resources
	 # @return void
	proc free_resources {} {
		variable content		;# Array: Currently loaded data
		variable error_string	{}	;# Error messages
		variable data_field	0	;# Auxiliary variable for creating IHEX records

		# Reset array of loaded data
		for {set i 0} {$i < 0x10000} {incr i} {
			set content($i) {}
		}
	}

	## Get value of particular cell in the loaded array
	 # @parm Int addr - Must be 0..65535
	 # @return Int - -1 == Not defined; 0..255 loaded value
	proc get_value {addr} {
		variable content		;# Array: Currently loaded data

		if {$addr < 0 || $addr > 0xFFFF} {
			return -1
		}
		set result $content($addr)
		if {$result == {}} {
			return -1
		} else {
			return $result
		}
	}



	# ----------------------------------------------------------------
	# INTERNAL AUXILIARY PROCEDURES
	# ----------------------------------------------------------------

	## Create IHEX8 record (result -> data_field)
	 # @parm String addr - Content of address firld (decimal number)
	 # @return void
	proc create_hex_record {addr} {
		variable data_field	;# Auxiliary variable for creating IHEX records
		variable data_field_len	;# Auxiliary variable for creating IHEX records

		# Adjust address
		set addr [format %X $addr]
		set len [string length $addr]
		if {$len != 4} {
			set addr "[string repeat 0 [expr {4 - $len}]]$addr"
		}
		# Adjust lenght
		set len [format %X $data_field_len]
		if {[string length $len] == 1} {
			set len "0$len"
		}

		# Create HEX field
		set data_field ":${len}${addr}00${data_field}[getCheckSum ${len}${addr}00${data_field}]\n"
		set data_field_len 0
	}

	## Append error message to error_string
	 # @parm Int line	- Number of line where the error occurred
	 # @parm String		- Error message
	 # @return void
	proc Error {line string} {
		variable error_count	;# Int: Count of errors
		variable error_string	;# Error messages

		incr error_count
		append error_string [mc "Error at %s:\t" $line] $string "\n"
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

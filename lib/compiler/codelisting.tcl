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
if { ! [ info exists _CODELISTING_TCL ] } {
set _CODELISTING_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Hepler namespace to generate code listing.
# This code is part of compiler (see 'compiler.tcl' and 'assembler.tcl').
# --------------------------------------------------------------------------


namespace eval CodeListing {

	## Resulting LST code
	 # format: {lineNum address opcode value includeLevel macroLevel {lineContent}}
	variable lst		{}
	variable Enabled	1	;# Bool: LIST/NOLIST flag
	variable pageNum		;# Page number
	variable pageLines		;# Number of lines at the current page
	variable header		{}	;# Title string
	variable errors_count	0	;# Number of errors
	variable warnings_count	0	;# Number of warnings
	variable symbol_table	{}	;# Table of symbolic names
	variable error_summary	{}	;# Error summmary string
	variable new_sync_map	{}	;# Tempotary Map of lines in code listing
	variable sync_map	{}	;# Map of lines in code listing
	variable tmp_lst	{}	;# Tempotary LST code


	# ----------------------------------------------------------------
	# GENERAL PURPOSE PROCEDURES
	# ----------------------------------------------------------------

	## Format resulting code listing
	 # @access public
	 # @return String - code listing
	proc getListing {} {
		variable lst		;# Resulting LST code
		variable error_summary	;# Error summmary string
		variable errors_count	;# Number of errors
		variable warnings_count	;# Number of warnings
		variable symbol_table	;# Table of symbolic names
		variable header		;# Title string
		variable pageNum	;# Page number
		variable pageLines	;# Number of lines at the current page

		# Initialize NS variables
		set pageNum 1
		set pageLines 0

		# Validate compiler settings
		if {${::Compiler::Settings::PAGELENGTH} < 5} {
			set Compiler::Settings::PAGELENGTH 5
		} elseif {${::Compiler::Settings::PAGELENGTH} == 0} {
			set Compiler::Settings::PAGING 0
		}
		if {${::Compiler::Settings::PAGEWIDTH} < 68} {
			set Compiler::Settings::PAGEWIDTH 68
		} elseif {${::Compiler::Settings::PAGEWIDTH} == 0} {
			set Compiler::Settings::PAGEWIDTH 116
		}

		# Create page header
		set header ${::Compiler::Settings::INPUT_FILE_NAME}
		set len [string length ${::Compiler::Settings::INPUT_FILE_NAME}]
		if {$len < 15} {
			append header [string repeat { } [expr {15 - $len}]]
		}
		append header { } ${::Compiler::Settings::TITLE}

		set len [string length $header]
		incr len 23

		# Adjust page header width
		if {$len > ${::Compiler::Settings::PAGEWIDTH}} {
			set header [string range $header 0 [expr {${::Compiler::Settings::PAGEWIDTH} - 24}]]
			append header {... }

		} elseif {$len < ${::Compiler::Settings::PAGEWIDTH}} {
			set len [expr {${::Compiler::Settings::PAGEWIDTH} - $len}]
			append header [string repeat { } $len]
		}

		# Create date
		set len [string length ${::Compiler::Settings::DATE}]
		if {$len > 10} {
			set Compiler::Settings::DATE [string range 0 7 ${::Compiler::Settings::DATE}]
			append Compiler::Settings::DATE {...}

		} elseif {$len < 10} {
			set len [expr {10 - $len}]
			append Compiler::Settings::DATE [string repeat { } $len]
		}

		append header ${::Compiler::Settings::DATE} { PAGE}

		# Create error summary and symbol table
		create_error_summary
		if {${::Compiler::Settings::SYMBOLS}} {
			create_symbol_table
		}

		# Create code listing text
		format_listing

		append lst "\nASSEMBLY COMPLETE"

		# Append final result
		if {$errors_count == 1} {
			append lst ", 1 ERROR FOUND"
		} elseif {$errors_count > 1} {
			append lst ", $errors_count ERRORS FOUND"
		} else {
			append lst ", NO ERRORS FOUND"
		}

		if {$warnings_count == 1} {
			append lst ", 1 WARNING"
		} elseif {$warnings_count > 1} {
			append lst ", $warnings_count WARNINGS"
		} else {
			append lst ", NO WARNINGS"
		}

		# Create final result
		append lst "\n"

		# Error summary
		if {($errors_count != 0) || ($warnings_count != 0)} {
			append lst "\n\n"
			append lst $error_summary
		}

		# Symbol table
		if {${::Compiler::Settings::SYMBOLS}} {
			append lst "\n\n"
			append lst $symbol_table
		}

		# restore special characters
		regsub -all {\\\\} $lst "\\" lst
		regsub -all {\\\{} $lst "\{" lst
		regsub -all {\\\}} $lst "\}" lst
		regsub -all {\\\"} $lst "\"" lst

		# Return result
		return $lst
	}

	## Directive LIST
	 # @access public
	 # @parm Int idx - index where the directive occurred
	 # @return void
	proc directive_list {idx} {
		variable lst		;# Resulting LST code

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}
		if {${::Compiler::Settings::_list} != 0} {return}

		# Adjust code listing
		set idx [getIdx $idx]
		increment_sync_map $idx 1
		set lst [linsert $lst $idx {LIST}]
	}

	## Directive NOLIST
	 # @access public
	 # @parm Int idx - index where the directive occurred
	 # @return void
	proc directive_nolist {idx} {
		variable lst		;# Resulting LST code

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}
		if {${::Compiler::Settings::_list} != 0} {return}

		# Adjust code listing
		set idx [getIdx $idx]
		incr idx
		increment_sync_map $idx 1
		set lst [linsert $lst $idx {NOLIST}]
	}

	## Debuging procedure
	 # Write current content of the code listing to stdout (max. 501 lines)
	 # @access public
	 # @return void
	proc write_lst {} {
		variable lst		;# Resulting LST code
		variable sync_map	;# Map of lines in code listing

		set idx 0
		foreach line $lst {
			puts "$idx:\t$line"
			incr idx
			if {$idx > 500} {break}
		}
	}

	## Initialize code listing
	 # Should be called on preprocessor start up
	 # @access public
	 # @parm String data - input source code
	 # @return void
	proc create_listing {data} {
		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		variable lst		;# Resulting LST code
		variable sync_map	;# Map of lines in code listing
		variable error_summary	;# Error summmary string
		variable symbol_table	;# Table of symbolic names
		variable Enabled	;# Bool: LIST/NOLIST flag

		# Reset NS variables
		set lst			{}
		set Enabled		1
		set sync_map		{}
		set symbol_table	{}
		set error_summary	{}

		# Initialize code listing list
		set idx -1
		foreach line $data {
			incr idx
			lappend lst [list {} {} {} 0 0 [lindex $line 2]]
			lappend sync_map $idx
		}
	}

	## Import table of symbolic names from preprocessor
	 # @access public
	 # @return void
	proc import_symbolic_names {} {
		variable symbol_table	;# Table of symbolic names

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}
		if {!${::Compiler::Settings::SYMBOLS}} {return}

		# Iterate over definition ists and write them to the table
		foreach def_list {
				defined_BIT	defined_CODE	defined_DATA	defined_IDATA
				defined_XDATA	defined_LABEL	defined_EQU	defined_EQU_SPEC
			} val_array {
				const_BIT	const_CODE	const_DATA	const_IDATA
				const_XDATA	labels		const_EQU	const_EQU_SPEC
			} type {
				ADDR		ADDR		ADDR		ADDR
				ADDR		ADDR		NUMB		SPEC
			} char {
				B		C		D		I
				X		C		N		S
			} \
		{
			# Get list of defined names
			set def_list [subst -nocommands "\$PreProcessor::$def_list"]

			# Write defined names to the table
			foreach var $def_list {
				set value [subst -nocommands "\$PreProcessor::${val_array}($var)"]

				# Handle special constants
				if {$char == {S}} {
					lappend symbol_table [list	\
						[string toupper $var]	\
						$char			\
						$type			\
						[string toupper $value]	\
						1 0]

				# Other constants ...
				} else {
					lappend symbol_table [list	\
						[string toupper $var]	\
						$char			\
						$type			\
						[get_4hex $value]	\
						1 0]
				}
			}
		}

		# Write defined variables (directive "SET")
		foreach var ${::PreProcessor::defined_SET} {
			set value [lindex $::PreProcessor::const_SET($var) {end 1}]
			lappend symbol_table [list [string toupper $var] { } NUMB [get_4hex $value] 1 1]
		}

		# Write defined special variables (directive "SET")
		foreach var ${::PreProcessor::defined_SET_SPEC} {
			set value [lindex $::PreProcessor::const_SET_SPEC($var) {end 1}]
			lappend symbol_table [list [string toupper $var] {S} SPEC [string toupper $value] 1 1]
		}

		# Sort table of symbols by names
		set symbol_table [lsort -index 0 $symbol_table]
	}

	## Set flag used to 1 for symbol written in table of symbols
	 # @access public
	 # @parm String symbolic_name	- Symbol name
	 # @parm String type		- Symbol type
	 # @return Bool - result
	proc symbol_used {symbolic_name type} {
		variable symbol_table	;# Table of symbolic names

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}
		if {!${::Compiler::Settings::SYMBOLS}} {return}

		# Find the specified symbol in the table
		set symbolic_name [string toupper $symbolic_name]
		set idx -1
		foreach var $symbol_table {
			incr idx

			# Symbol found -> set flag used
			if {[lindex $var 0] == $symbolic_name} {
				lset symbol_table [list $idx 4] 0
				return 1
			}
		}

		# Symbol not found -> failed
		return 0
	}

	## Write error message to the code listing
	 # @access public
	 # @parm Int idx	- Index where the error occurred
	 # @parm String info	- Error message
	 # @return void
	proc Error {idx info} {
		variable lst	;# Resulting LST code

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Adjust index
		set idx [getIdx $idx]
		if {$idx == {}} {
			puts stderr "Assembler internal failure 0 -- code listing will not be complete"
			return
		}
		incr idx
		increment_sync_map $idx 1

		# Write the message
		set lst [linsert $lst $idx [list {****} "ERROR: $info"]]
	}

	## Write warning message to the code listing
	 # @access public
	 # @parm Int idx	- Index where the warning occurred
	 # @parm String info	- Warning message
	 # @return void
	proc Warning {idx info} {
		variable lst		;# Resulting LST code

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Adjust index
		set idx [getIdx $idx]
		if {$idx == {}} {
			puts stderr "Assembler internal failure 4 -- code listing will not be complete"
			return
		}
		incr idx
		increment_sync_map $idx 1

		# Write the message
		set lst [linsert $lst $idx [list {****} "WARNING: $info"]]
	}

	## Directive "$EJECT"
	 # @access public
	 # @parm Int idx	- Source index
	 # @return void
	proc directive_eject {idx} {
		variable lst		;# Resulting LST code

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Adjust index
		set idx [getIdx $idx]
		if {$idx == {}} {
			puts stderr "Assembler internal failure 5 -- code listing will not be complete"
			return
		}
		incr idx 2
		increment_sync_map $idx 1

		# Write the message
		set lst [linsert $lst $idx EJECT]
	}

	## Directive "DB"
	 # @access public
	 # @parm Int idx	- Source index
	 # @parm List values	- Hexadecimal values (eg. '{FA 4 5 2D C'})
	 # @return void
	proc db {idx values} {
		variable lst		;# Resulting LST code

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Determinate original values
		set sub_idx [getIdx $idx]

		if {$sub_idx != {}} {
			set new_values [lindex $lst [list $sub_idx 1]]
		} else {
			set new_values {}
		}

		# Adjust list of values
		foreach val $values {
			if {![string is digit -strict $val]} {
				append new_values " {} {$val} "
				continue
			}
			set val [string trimleft $val 0]
			if {$val == {}} {
				set val {00}
			} else {
				set val [format %X $val]
				if {[string length $val] == 1} {
					set val "0$val"
				}
			}
			append new_values $val
		}

		# Set OP code for the current line
		set_opcode $idx $new_values
	}

	## Expansion of macro instruction
	 # @access public
	 # @parm Int idx		- Source index
	 # @parm String macro_code	- Code of the macro instruction
	 # @return void
	proc macro {idx macro_code} {
		variable sync_map	;# Map of lines in code listing
		variable tmp_lst	;# Tempotary LST code
		variable lst		;# Resulting LST code

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Create empty space in code listing
		insert_lines $idx [llength $macro_code]

		# Determinate target index
		set idx [getIdx $idx]
		# Initialize auxiliary code listing list
		set tmp_lst {}

		# Adjust Macro expansion level and Inclusion level
		set IncLevel [lindex $lst [list $idx 3]]
		set MacLevel [lindex $lst [list $idx 4]]
		if {![regexp {^\d+$} $MacLevel]} {
			puts stderr "Assembler internal failure 1 -- code listing will not be complete"
			return
		}
		incr MacLevel

		# Adjust code of macro instruction
		foreach line $macro_code {
			lappend tmp_lst [list {} {} {} $IncLevel $MacLevel "\t\t$line"]
		}

		# Set macro expansion level
		lset lst [list $idx 4] $MacLevel

		# Insert code of macro to the current code listing
		incr idx
		append tmp_lst { }
		append tmp_lst [lrange $lst $idx end]
		set lst [lreplace $lst $idx end]

		append lst { }
		append lst $tmp_lst
		set tmp_lst {}
	}

	## Adjust current code listing to the fiven code organization
	 # @access public
	 # @parm List organization - new organization (see Preprocessor)
	 # @return void
	proc org {organization} {
		variable sync_map	;# Map of lines in code listing
		variable new_sync_map	;# Tempotary Map of lines in code listing

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Reformat synchronization map
		set new_sync_map {}
		foreach org $organization {
			# Local variables
			set start [lindex $org 0]	;# Start line
			set end [lindex $org 1]		;# End line

			append new_sync_map { }
			append new_sync_map [lrange $sync_map $start $end]
			set sync_map [lreplace $sync_map $start $end]
		}
		if {$sync_map != {}} {
			append new_sync_map { }
			append new_sync_map $sync_map
		}

		set sync_map $new_sync_map
	}

	## Set instruction OP code
	 # @access public
	 # @parm Int idx	- Source index
	 # @parm String opcode	- Haxadecimal OP code
	 # @return void
	proc set_opcode {idx opcode} {
		variable lst		;# Resulting LST code

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Adjust code listing
		set idx [getIdx $idx]

		if {$idx == {}} {return}
		if {[catch {
			lset lst [list $idx 1] $opcode
		}]} then {
			puts stderr "Assembler internal failure 2 -- code listing will not be complete"
			return
		}
	}

	## Set instruction address
	 # @access public
	 # @parm Int idx	- Source index
	 # @parm Int addr	- Instruction address
	 # @return void
	proc set_addr {idx addr} {
		variable lst		;# Resulting LST code
		variable sync_map	;# Map of lines in code listing

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Adjust code listing
		set idx [getIdx $idx]
		if {$idx == {}} {return}
		if {[catch {
			lset lst [list $idx 0] [get_4hex $addr]
		}]} then {
			puts stderr "Assembler internal failure 3 -- code listing will not be complete"
			return
		}
	}

	## Directive "END"
	 # @access public
	 # @parm Int idx - Source index
	 # @parm Bool preserve_current_line=false - Do not remove the `$idx' line from the sync. map
	 # @return void
	proc end_directive {idx {preserve_current_line 0}} {
		variable sync_map	;# Map of lines in code listing
		variable lst		;# Resulting LST code

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Determinate target index
		set lst_idx [getIdx $idx]
		incr lst_idx
		if {$lst_idx == {}} {return}
		if {$lst_idx > ([llength $lst] - 1)} {return}

		# Adjust code listing and synchronization map
		set lst [lreplace $lst $lst_idx end]
		if {$preserve_current_line} {
			incr idx
		}
		if {$idx < [llength $sync_map]} {
			set sync_map [lreplace $sync_map $idx end]
		}
	}

	## Set value for symbol definition
	 # @access public
	 # @parm Int idx	- Source index
	 # @parm Int value	- Symbol value
	 # @return void
	proc set_value {idx value} {
		variable lst		;# Resulting LST code

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Determinate target index
		set idx [getIdx $idx]
		if {$idx == {}} {return}

		# Adjust code listing
		lset lst [list $idx 2] [get_4hex $value]
	}

	## Set value for special symbol definition
	 # @access public
	 # @parm Int idx	- Source index
	 # @parm Int value	- Symbol value
	 # @return void
	proc set_spec_value {idx value} {
		# This procedure does nothing and that's what is should do ...
	}

	## Directive "INCLUDE"
	 # @access public
	 # @parm Int idx	- Source index
	 # @parm String data	- Included source code
	 # @return void
	proc include {idx data} {
		variable tmp_lst	;# Tempotary LST code
		variable lst		;# Resulting LST code

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Insert empty lines for the included code
		insert_lines $idx [expr {[llength $data] - 1}]

		# Determinate target index
		set idx [getIdx $idx]

		# Adjust macro expansion level and inclusion level
		set IncLevel [lindex $lst [list $idx 3]]
		set MacLevel [lindex $lst [list $idx 4]]
		incr IncLevel

		# Adjust the given source code
		set tmp_lst {}
		foreach line $data {
			lappend tmp_lst [list {} {} {} $IncLevel $MacLevel [lindex $line 2]]
		}

		# Reformat code listing
		incr idx
		append tmp_lst { }
		append tmp_lst [lrange $lst $idx end]
		incr idx -1
		set lst [lreplace $lst $idx end]
		append lst { }
		append lst $tmp_lst
		set tmp_lst {}

	}

	## Get last index in the synchronization map
	 # @return Int - The index
	proc get_last_index_in_sync_map {} {
		 return [expr {[llength ${::CodeListing::sync_map}] - 1}]
	}

	## Line removed -- adjust synchronization map
	 # @access public
	 # @parm Int idx - source index
	 # @return void
	proc delete_line {idx} {
		variable sync_map	;# Map of lines in code listing

		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		# Adjust synchronization map
		set sync_map [lreplace $sync_map $idx $idx]
	}

	## Adjust synchronization map to create a space which cannot contain anything
	 # @access public
	 # @parm Int dest_idx	- Target index
	 # @parm Int len	- Number of lines
	 # @return void
	proc insert_empty_lines {dest_idx len} {
		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}

		variable sync_map	;# Map of lines in code listing
		variable new_sync_map	;# Tempotary Map of lines in code listing

		# Abort if there s nothing to insert
		if {$len == 0} {return}

		# Create $len empty items in sync map at index $dest_idx
		set new_sync_map {}
		set idx -1
		foreach item $sync_map {
			incr idx

			lappend new_sync_map $item
			if {$idx == $dest_idx} {
				for {set i 0} {$i < $len} {incr i} {
					lappend new_sync_map {}
				}
			}
		}

		set sync_map $new_sync_map
	}

	## Free reserved resources
	 # @access public
	 # @return void
	proc free_resources {} {
		variable lst	;# Resulting LST code
		set lst {}
	}


	# ----------------------------------------------------------------
	# INTERNAL AUXILIARY PROCEDURES
	# ----------------------------------------------------------------

	## Reformat internal listing to human readable text
	 # @access private
	 # @return void
	proc format_listing {} {
		variable header		;# Title string
		variable pageNum	;# Page number
		variable pageLines	;# Number of lines at the current page
		variable lst		;# Resulting LST code
		variable Enabled	;# Bool: LIST/NOLIST flag

		# Write page header
		set result $header
		append result { } $pageNum "\n"

		# Initialize variables
		set pageLines 0
		set lineNum 0

		# Reformat code
		foreach line $lst {
			incr lineNum

			# Take case of directives "LIST" and "NOLIST"
			if {$line == {NOLIST}} {
				set Enabled 0
				incr lineNum -1
				continue
			} elseif {$line == {LIST}} {
				set Enabled 1
				incr lineNum -1
				continue
			}

			# Skip line if listing is disabled
			if {!$Enabled} {
				continue
			}

			# Create new page if paging is enabled
			if {${::Compiler::Settings::PAGING}} {
				incr pageLines
				if {$pageLines > ${::Compiler::Settings::PAGELENGTH}} {
					incr pageNum
					set pageLines 1
					append result "\n\f" $header { } $pageNum "\n\n"
				}
			}


			# Directive "$EJECT"
			if {[lindex $line 0] == {EJECT}} {
				incr pageNum
				set pageLines 1
				append result "\n\f" $header { } $pageNum "\n\n"
				incr lineNum -1

			# Line containing an error message
			} elseif {[lindex $line 0] == {****}} {
				append result "****" [lindex $line 1] "\n"
				incr lineNum -1

			# Normal line
			} else {
				# Local variables
				set addr	[lindex $line 0] ;# Address field
				set opcode	[lindex $line 1] ;# Instruction OP code
				set value	[lindex $line 2] ;# Value of defined constant
				set IncLevel	[lindex $line 3] ;# Inclusion level
				set MacLevel	[lindex $line 4] ;# Macro expansion level
				set code	[lindex $line 5] ;# Source code

				# Adjust inclusion level
				if {$IncLevel == 0} {
					set IncLevel {   }
				} else {
					set IncLevel "=$IncLevel"
					if {[string length $IncLevel] == 2} {
						append IncLevel { }
					}
				}

				# Adjust macro expansion level
				if {$MacLevel == 0} {
					set MacLevel {   }
				} else {
					set MacLevel "+$MacLevel"
					if {[string length $MacLevel] == 2} {
						append MacLevel { }
					}
				}

				# Adjust line number
				set line_number $lineNum
				set len [string length $line_number]
				if {$len < 5} {
					set line_number "[string repeat { } [expr {5 - $len}]]$line_number"
				}

				## Create filed 0 (address + OP code // constant value)
				set field0 {}

				# Adjust opcode length (for continuation on the next line)
				set opcode_len [string length $opcode]
				if {$opcode_len > 10} {
					set opcode_continue [string replace $opcode 0 9]
					set opcode [string range $opcode 0 9]
				}

				# Only constant value
				if {$value != {}} {
					append field0 {  } $value {          }
				# Address + OP code
				} elseif {($opcode != {}) && ($addr != {})} {
					if {$opcode_len < 10} {
						append opcode [string repeat { } [expr {10 - $opcode_len}]]
					}
					append field0 $addr { } $opcode { }
				# Empty
				} else {
					set field0 [string repeat { } 16]
				}

				# Composite final line
				set line {}
				append line $field0 { } $IncLevel { } $line_number
				append line { } $MacLevel { } [tabs2spaces $code]
				append result [string range $line 0 [expr ${::Compiler::Settings::PAGEWIDTH} - 1]] "\n"

				# Continue in unfinished opcode
				if {$opcode_len > 10} {
					incr opcode_len -10
					for {set i 0; set j 9} {$i < $opcode_len} {incr i 10; incr j 10} {
						append result {     } [string range $opcode_continue $i $j] "\n"
					}
				}
			}
		}

		# Restore characters '{' and '}'
		regsub -all {\a} $result "\{" result
		regsub -all {\b} $result "\}" result
		# Remove redutant white space
		set lst [regsub -all -line {\s+$} $result {}]
	}

	## Convert tabulators to spaces
	 # @access private
	 # @parm String data - input data
	 # @return String - output data
	proc tabs2spaces {data} {
		set tmp {}	;# Auxiliary variable
		while {1} {
			# Search for 1st tabulator
			set idx [string first "\t" $data]

			# Tabulator not found -> return result
			if {$idx == -1} {
				return $data
			# 1st char
			} elseif {$idx == 0} {
				regsub {\t} $data {        } data
			# Somewhere else
			} else {
				# Determinate string before tabulator
				incr idx -1
				set tmp [string range $data 0 $idx]
				# Determinate string after tabulator
				incr idx 2
				set data [string range $data $idx end]
				# Determinate number of spaces
				set len [string length $tmp]
				set len [expr {8 - ($len % 8)}]
				# Recomposite source string
				append tmp [string repeat { } $len]
				append tmp $data
				set data $tmp
			}
		}
	}

	## Create string containing error summary
	 # Modifies content of variables:
	 #	- error_summary
	 #	- errors_count
	 #	- warnings_count
	 # @access private
	 # @return void
	proc create_error_summary {} {
		variable lst		;# Resulting LST code
		variable error_summary	;# Error summmary string
		variable errors_count	;# Number of errors
		variable warnings_count	;# Number of warnings
		variable header		;# Title string
		variable pageNum	;# Page number
		variable pageLines	;# Number of lines at the current page

		# Reset error counters
		set errors_count 0
		set warnings_count 0
		# Initialize resulting string
		set error_summary {}

		# Create new page
		if {${::Compiler::Settings::PAGING}} {
			incr pageNum
			set pageLines 0
			append error_summary "\n\f" $header { } $pageNum "\n\n"
		}

		append error_summary {ERROR SUMMARY:}

		# Search code for errors and warnings
		set lineNum -1
		foreach line $lst {
			incr lineNum

			# Create new page if nessesary
			if {${::Compiler::Settings::PAGING}} {
				incr pageLines

				if {$pageLines > ${::Compiler::Settings::PAGEWIDTH}} {
					incr pageNum
					set pageLines 1
					append error_summary "\n\f" $header { } $pageNum "\n\n"
				}
			}

			# Error/Warning found
			if {[lindex $line 0] == {****}} {

				if {[lindex $line {1 0}] == {ERROR:}} {
					incr errors_count
				} else {
					incr warnings_count
				}

				# Append error/warning information
				append error_summary "\n" Line { } $lineNum {, } [lindex $line 1]
			}
		}
	}

	## Create table of symbolic names
	 # Result is stored in variable symbol_table
	 # @access private
	 # @return void
	proc create_symbol_table {} {
		variable symbol_table	;# Table of symbolic names
		variable header		;# Title string
		variable pageNum	;# Page number
		variable pageLines	;# Number of lines at the current page

		# Initialize resulting string
		set result {}

		# Create new page
		if {${::Compiler::Settings::PAGING}} {
			incr pageNum
			set pageLines 0
			append result "\n\f" $header { } $pageNum "\n\n"
		}
		append result {SYMBOL TABLE:}

		# Create string for paddings
		set padding [string repeat { .} 18]

		# Convert current table to human readable string
		foreach var $symbol_table {

			# Create new page if nessesary
			if {${::Compiler::Settings::PAGING}} {
				incr pageLines

				if {$pageLines > ${::Compiler::Settings::PAGEWIDTH}} {
					incr pageNum
					set pageLines 1
					append result "\n\f" $header { } $pageNum "\n\n"
				}
			}

			# Local variables
			set rd		[lindex $var 5] ;# Bool: redefinable
			set nu		[lindex $var 4] ;# Bool: not used
			set val		[lindex $var 3] ;# Value
			set name	[lindex $var 0] ;# Symbolic name
			## Type
			 #	NUMB == number
			 #	ADDR == address
			 #	SPEC == special value
			set type	[lindex $var 2]
			## Character
			 #	C == code
			 #	D == data
			 #	B == bit
			 #	X == external
			 #	S == special value
			set char	[lindex $var 1]

			# Adjust rd
			if {$rd == 1} {
				set rd {REDEFINABLE}
			} else {
				set rd {}
			}

			# Adjust nu
			if {$nu == 1} {
				set nu {NOT USED}
			} else {
				set nu {        }
			}

			# Adjuts symbolic name
			set len [string length $name]
			incr len -1
			set name [string replace $padding 0 $len $name]

			# Composite final line
			if {$char != {S}} {
				set h {H}
			} else {
				set nu {        }
				set h [string repeat { } [expr {5 - [string length $val]}]]
			}
			append result "\n" $name {  } $char {  } $type {  } $val $h {  } $nu {  } $rd
		}
		append result "\n"

		# Remove all redutant white space
		regsub -all -line {\s+$} $result {} symbol_table
	}

	## Increment values in synchronization map
	 # @access private
	 # @parm Int idx	- Index where incrementation begins
	 # @parm Int value	- Value to increment by
	 # @return void
	proc increment_sync_map {idx value} {
		variable sync_map	;# Map of lines in code listing
		variable new_sync_map	;# Tempotary Map of lines in code listing

		set new_sync_map {}
		foreach item $sync_map {
			if {$item >= $idx} {
				if {$item != {}} {
					incr item $value
				}
			}
			lappend new_sync_map $item
		}
		set sync_map $new_sync_map
	}

	## Convert decimal value to four digit hexadecimal value
	 # @access private
	 # @parm Int number - number to convert
	 # @return String - result
	proc get_4hex {number} {
		# Convert value
		set number [format %X $number]
		# Adjust length
		set len [string length $number]
		if {$len < 4} {
			set number "[string repeat 0 [expr {4 - $len}]]$number"
		}
		# Return result
		return $number
	}

	## Translate source index to target index according to synchronization map
	 # @access private
	 # @parm Int idx - Source index
	 # @return Int - target index
	proc getIdx {idx} {
		variable sync_map	;# Map of lines in code listing

		set result [lindex $sync_map $idx]
		if {$result == {}} {
			set result 0
		}
		return $result
	}

	## Adjust synchronization map to create empty space to insert something
	 # @access private
	 # @parm Int dest_idx	- Target index
	 # @parm Int len	- Number of lines
	 # @return void
	proc insert_lines {dest_idx len} {
		# Check if code listing is enabled
		if {!${::Compiler::Settings::PRINT}} {return}
		if {$len == 0} {return}

		variable sync_map	;# Map of lines in code listing
		variable new_sync_map	;# Tempotary Map of lines in code listing

		# Adjust synchronization map
		set dest_item [lindex $sync_map $dest_idx]
		if {$dest_item == {}} {
			set dest_item 0
		}
		set new_sync_map {}
		set idx -1
		foreach item $sync_map {
			incr idx

			# Taget index
			if {$idx == $dest_idx} {
				if {$item == {}} {
					continue
				}
				set tmp [expr {$len + $item}]
				while {$item <= $tmp} {
					lappend new_sync_map $item
					incr item
				}

			# Empty index or too low index to be changed
			} elseif {$item == {} || $item < $dest_item} {
				lappend new_sync_map $item

			# Index somewhere in the affected area
			} else {
				incr item $len
				lappend new_sync_map $item
			}
		}

		set sync_map $new_sync_map
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

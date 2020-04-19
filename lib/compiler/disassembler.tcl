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
if { ! [ info exists _DISASSEMBLER_TCL ] } {
set _DISASSEMBLER_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# Disassembler 8051
#
# DESCRIPTION:
#	Converts data from Intel HEX 8 fromat to assembler 51.
#
# SUMMARY:
#	* Generated code doesn't contain any compiler directives except 'DB', 'ORG' and 'END'.
#	* Unrecognized opcodes are traslated to 'DB opcode'
#	* Labels referencing to "nowhere" are traslated as 'label EQU address'
#	* Input code must be absolutely clear so it mustn't contain any
#	  ambiguity and all addresses must be in icremental order
#	* Lines in hex code which don't start with colon ':' are ignored
#
# USAGE:
#	disassembler::compile $hex_data ;# -> asm code
#
# --------------------------------------------------------------------------

namespace eval disassembler {

	variable tmp_asm	{}	;# Tempotary variable for code procedure: 'final_stage'
	variable hex_data	{}	;# Raw input data
	variable hex		{}	;# Adjusted input data, list: {addr hex0 hex1 hex2 ...}
	variable lineNum	{}	;# Number of line currently beeing parsed
	variable error_count	{}	;# Number of errors raised during disassembly
	variable warning_count	{}	;# Number of warnings occurred
	variable label_idx	{}	;# Label index
	variable final_lbls	0	;# Number of final labels
	variable label			;# Array of tempotary labels, label(int) -> addr
	variable asm		{}	;# Resulting source code


	# ----------------------------------------------------------------
	# GENERAL PURPOSE PROCEDURES
	# ----------------------------------------------------------------

	## Initiate disassembly
	 # @parm string data - Input IHEX8 code
	 # @return string - output asm code or {}
	proc compile {data} {

		variable hex_data	;# Raw input
		variable hex		;# Adjusted input data, list: {addr hex0 hex1 hex2 ...}
		variable lineNum	;# Number of line currently beeing parsed
		variable error_count	;# Number of errors raised during disassembly
		variable warning_count	;# Number of warnings occurred
		variable asm		;# Resulting source code

		set error_count 0	;# reset errors count
		set warning_count 0	;# reset errors count
		set hex {}		;# clear hex data used for futher prosessing
		set hex_data $data	;# set input data

		# Adjust input data
		regexp -all {\r\n?} hex_data "\n" hex_data
		set hex_data [split $hex_data "\n"]

		${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {SN}][mc "Initializing disassembler ..."]

		# Verify input code validity and set variable 'hex'
		adjust_code

		# Exit if the code does not seem to be valid
		if {$error_count != 0} {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[::Compiler::msgc {EN}][mc "Disassembly FAILED ..."]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[::Compiler::msgc {EN}][mc "\033\[31;1mDisassembly FAILED\033\[m ..."]
			}
			return {}
		}

		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {EN}][mc "Aborted"]
			free_resources
			return {}
		}

		# Convert processor code into asm code
		decompile_code

		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {EN}][mc "Aborted"]
			free_resources
			return {}
		}

		# Create labels in resulting code
		parse_labels

		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {EN}][mc "Aborted"]
			free_resources
			return {}
		}

		# Final stage
		final_stage

		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {EN}][mc "Aborted"]
			free_resources
			return {}
		}

		# Free memory used during disassembly
		free_resources

		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {EN}][mc "Aborted"]
			free_resources
			return {}
		}

		if {${::Compiler::Settings::NOCOLOR}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
				[::Compiler::msgc {SN}][mc "Disassembly complete"]
		} else {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
				[mc "\033\[32;1mDisassembly complete\033\[m"]
		}

		# Return resulting source code
		return $asm
	}


	# ----------------------------------------------------------------
	# INTERNAL AUXILIARY PROCEDURES
	# ----------------------------------------------------------------

	## Verify input code validity and set variable 'hex'
	 # @return void
	proc adjust_code {} {
		variable hex		;# Adjusted input data
		variable lineNum	;# Number of line currently beeing parsed
		variable hex_data	;# Raw input (hex data)

		set pointer -1		;# Program address pointer
		set lineNum 0		;# Line number

		foreach line $hex_data {

			if {[expr {$lineNum % 10}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}

			incr lineNum	;# line number

			# Skip comments
			if {[string index $line 0] != {:}} {continue}

			# Check for valid characters
			set line [string range $line 1 end]
			if {![regexp {^[0-9A-Fa-f]*$} $line]} {
				Error $lineNum [mc "Invalid line (line contain not allowed characters)"]
				continue
			}

			# Check for odd number of characters
			set len [string length $line]
			if {[expr {$len % 2}] != 0} {
				Error $lineNum [mc "Line do not contain odd number of chars"]
				continue
			}

			# Check for valid checksum
			set check [string range $line {end-1} end]
			set new_check [::IHexTools::getCheckSum [string range $line 0 {end-2}]]
			if {$check != $new_check} {
				Error $lineNum [mc "Bad checksum, given: %s ; computed: %s" $check $new_check]
				continue
			}

			# Check for correct record type
			set type [string range $line 6 7]
			if {$type == {01}} {
				break
			} elseif {$type != {00}} {
				Error $lineNum [mc "Unknown record type number `%s' (Intel HEX 8 can contain only 00 and 01)" $type]
			}

			# Check valid line length
			set len [string range $line 0 1]
			set len [expr "0x$len"]
			set data [string range $line 8 {end-2}]
			if {$len != ([string length $data] / 2)} {
				Error $lineNum [mc "Length field do not correspond true data length"]
				continue
			}

			# Check for valid incremental addressing without any ambiguity
			set addr_hex [string range $line 2 5]
			set addr [expr "0x$addr_hex"]
			if {$addr <= $pointer} {
				Error $lineNum [mc "Unexpected address -- code is not well formatted"]
				continue
			} elseif {$addr > ($pointer + 1)} {
				set pointer $addr
			} else {
				incr pointer $len
			}

			## Convert line into this form:
			 # {
			 #	{addr hex hex hex ...}
			 #	...
			 # }
			set len [expr {($len * 2) - 1}]
			set line {}
			for {set i 0} {$i <= $len} {incr i} {
				append line { }
				append line [string index $data $i]
				incr i
				append line [string index $data $i]
			}
			lappend hex [string toupper "${addr_hex}${line}"]
		}
		set hex_data {}		;# delete input data
	}

	## Convert processor code into source code
	 # @return void
	proc decompile_code {} {

		variable hex		;# Adjusted input data, list: {{addr hex0 hex1 hex2 ...} ...}
		variable asm		;# Resulting source code
		variable label		;# Array of tempotary labels, label(int) -> addr
		variable label_idx	;# Number of usages of code memory addressing

		set pointer	0	;# reset code memory pointer
		set label_idx	-1	;# set label counter
		set asm		{}	;# reset asm
		set idx		0

		set trailing_data	[list]	;# data remained after parsing last line
		set trailing_data_length 0	;# length od trailing_data

		foreach line $hex {

			if {[expr {$idx % 10}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}

   			incr idx

			set addr	[lindex $line 0]	;# address field (hex)
			set line	[lreplace $line 0 0]	;# data fields (hex)
			set addr_dec	[expr "0x$addr"]	;# decimal value of address

			## If requested address overlaping expected address then
			 # adjust pointer and write trailing data by DB directive
			if {$addr_dec > ($pointer + 1 + $trailing_data_length) || ($pointer == 0)} {
				if {$trailing_data_length} {
					# Write trailing data
					foreach opcode $trailing_data {
						lappend asm _$pointer [list {DB} "0${opcode}h" {}]
						incr pointer
					}
					# Reset trailing data
					set trailing_data_length 0
					set trailing_data [list]
				}

				# Adjust pointer
				set pointer $addr_dec
				lappend asm {} {} {} [list {ORG} "[HEX $addr]h" {}]
			}

			# Number of data fields
			set len [llength $line]

			# Append trailing data from last parsing to the current line
			if {$trailing_data_length} {
				# append
				incr len $trailing_data_length
				set line [concat $trailing_data $line]
				# reset
				set trailing_data_length 0
				set trailing_data [list]
			}

			# Translate opcodes to source code
			set instruction_skipped 0
			set remaining_bytes $len
			incr len -1
			for {set idx 0} {$idx <= $len} {incr idx} {

				set opcode [lindex $line $idx]	;# current opcode
				# Search for he given opcode
				if {[lsearch ${::CompilerConsts::defined_OPCODE} $opcode] == -1} {
					# opcode not found -> write opcode directly to source code
					lappend asm "_$pointer" [list {DB} "0${opcode}h" {}]
					set length 1
				} else {
					# opcode found -> resolve it's definition
					set def $::CompilerConsts::Opcode($opcode)

					set instruction	[lindex $def 0]		;# Instruction name
					set opr_types	[lindex $def 1]		;# Oprand types
					set length	[lindex $def 2]		;# Instruction length
					set mask_opr	[lindex $def 3]		;# Opreand mask
					set operands	{}			;# reset operand values

					## If remaining code on this line has insufficient length to
					 # make valid instruction then continue to next line and
					 # append remainder of current line to the next line
					if {$length > $remaining_bytes} {
						set trailing_data_length $remaining_bytes
						set trailing_data [lrange $line $idx end]

						break
					}

					# Resolve operands
					set opr {}
					foreach type $opr_types {

						if {[lsearch ${::CompilerConsts::FixedOperands} [string tolower $type]] != -1} {
							# Fixed operand -> only copy
							set opr $type
						} else {
							# Get operand value
							incr idx

							if {$idx > $len} {
								lappend asm "_$pointer" [{DB} "0${opcode}h" {}]
								set instruction_skipped 1
								set length 1
								incr idx -1
								break
							}
							switch -- $type {
								{imm8}	{	;# Immediate addressing 8 bit
									set opr "#[HEX [lindex $line $idx]]h"
								}
								{imm16}	{	;# Immmediate addressing 16 bit
									set opr "#[HEX [lindex $line $idx]]"
									incr idx

									if {$idx > $len} {
										lappend asm "_$pointer" [list {DB} "0${opcode}h" {}]
										set instruction_skipped 1
										set length 1
										incr idx -2
										break
									}
									append opr "[lindex $line $idx]h"
								}
								{bit}	{	;# Direct addressing bit
									set opr "[HEX [lindex $line $idx]]h"
									set tmp_opr [string range $opr 0 {end-1}]
									set tmp_opr [expr "0x$tmp_opr"]
									foreach item ${::CompilerConsts::MapOfSFRBitArea} {
										if {[expr "0x[lindex $item 1]"] == $tmp_opr} {
											set opr [lindex $item 0]
											break
										}
									}
								}
								{/bit}	{	;# Direct inverted addressing bit
									set opr "/[HEX [lindex $line $idx]]h"
									set tmp_opr [string range $opr 1 {end-1}]
									set tmp_opr [expr "0x$tmp_opr"]
									foreach item ${::CompilerConsts::MapOfSFRBitArea} {
										if {[expr "0x[lindex $item 1]"] == $tmp_opr} {
											set opr [lindex $item 0]
											break
										}
									}
								}
								{data}	{	;# Direct addressing
									set opr "[HEX [lindex $line $idx]]h"
									set tmp_opr [string range $opr 0 {end-1}]
									set tmp_opr [expr "0x$tmp_opr"]
									foreach item ${::CompilerConsts::MapOfSFRArea} {
										if {[expr "0x[lindex $item 1]"] == $tmp_opr} {
											set opr [lindex $item 0]
											break
										}
									}
								}
								{code8}	{	;# Immediate addressing code memory, 8 bit
									incr label_idx
									set opr "lbl${label_idx}-"

									set label($label_idx) [expr "0x[lindex $line $idx]"]

									if {$label($label_idx) > 127} {
										incr label($label_idx) -256
									}

									incr label($label_idx) $pointer
									incr label($label_idx) $length

									if {$label($label_idx) > 0x0FFFF || $label($label_idx) < 0} {
										set label($label_idx) [expr {$label($label_idx) & 0x0FFFF}]
										Warning [mc "Code address overflow, instruction: %s" $instruction]
									} elseif {$label($label_idx) == $pointer} {
										unset label($label_idx)
										incr label_idx -1
										set opr {$}
									}
								}
								{code11} {	;# Immediate addressing code memory, 11 bit
									incr label_idx
									set opr "lbl${label_idx}-"
									set label($label_idx) "$mask_opr[lindex $line $idx]"
									set label($label_idx) [expr "0x$label($label_idx)"]
									set label($label_idx) [expr {($label($label_idx) & 0x007ff) | ($pointer & 0x0f800)}]

									if {$label($label_idx) == $pointer} {
										unset label($label_idx)
										incr label_idx -1
										set opr {$}
									}
								}
								{code16} {	;# Immediate addressing code memory, 16 bit
									incr label_idx
									set opr "lbl${label_idx}-"
									set label($label_idx) [lindex $line $idx]
									incr idx

									if {$idx > $len} {
										lappend asm "_$pointer" [list {DB} "0${opcode}h" {}]
										set length 1
										incr idx -2
										set instruction_skipped 1
										break
									}
									append label($label_idx) [lindex $line $idx]
									set label($label_idx) [expr "0x$label($label_idx)"]

									if {$label($label_idx) == $pointer} {
										unset label($label_idx)
										incr label_idx -1
										set opr {$}
									}
								}
							}
						}
						# Resulting operand value to operand list
						lappend operands $opr
					}

					if {$instruction_skipped} {
						set instruction_skipped 0
						incr pointer $length
						incr remaining_bytes -$length
						continue
					}

					# Swap operands in case if of instruction "MOV data, data"
					if {
						$instruction == {mov}		&&
						[lindex $opr_types 0] == {data}	&&
						[lindex $opr_types 1] == {data}
					} then {
						set operands [list [lindex $operands 1] [lindex $operands 0]]
					}

					# Append line to source code list
					lappend asm "_$pointer" [list $instruction $operands {}]
				}
				# Increment program address pointer
				incr pointer $length
				incr remaining_bytes -$length
			}
		}
	}

	## Create labels in resulting code
	 # Replace tempotary labels references by theirs final forms
	 # and add appropriate labels to lines (label:   mov   A, #56q)
	proc parse_labels {} {

		variable asm		;# Resulting source code
		variable label		;# Array of tempotary labels, label(int) -> addr
		variable label_idx	;# Label index
		variable final_lbls	;# Number of final labels

		set addrs	{}	;# List of set addresses
		set equ_block	{}	;# Reset block of declarations of unresoved labels

		# Replace each tempotary label with final label
		set lbl_idx -1
		for {set i 0} {$i <= $label_idx} {incr i} {
			set idx [lsearch $addrs $label($i)]
			if {$idx != -1} {
				# Reuse an existing label
				regsub -all "lbl${i}-" $asm "label$idx" asm
			} else {
				# Realy a new label
				lappend addrs $label($i)
				incr lbl_idx
				regsub -all "lbl${i}-" $asm "label$lbl_idx" asm
			}
		}
		set final_lbls $lbl_idx

		# Write final labels to the source code
		set i 0
		foreach addr $addrs {
			set idx [lsearch $asm "_$addr"]
			if {$idx == -1} {
				# Not found
				append equ_block "{} {CODE [HEX [format %X $addr]]h label$i} "
			} else {
				# Found
				incr idx
				lset asm [list $idx 2] "label$i"
			}
			incr i
		}

		# Append block of declarations of unresolved labels to resulting source code
		append equ_block $asm
		set asm $equ_block
	}

	## Final stage
	 # list -> plain text
	proc final_stage {} {
		variable asm		;# Resulting code
		variable tmp_asm	;# Tempotary variable only this procedure
		variable final_lbls	;# Number of final labels

		set tmp_asm {}		;# reset tempotary code
		set len [llength $asm]	;# length of source code list
		incr len -1

		# Rewrite the source code
		for {set i 1} {$i <= $len} {incr i 2} {

			if {[expr {$len % 5}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}

			set line [lindex $asm $i]	;# Get line

			# Empty line
			if {$line == {}} {
				append tmp_asm "\n"
				continue

			# Not an empty line
			} else {
				set label [lindex $line 2]	;# label
				set instr [lindex $line 0]	;# instruction
				set oprs [lindex $line 1]	;# oprands

				if {$label != {} && $instr != {CODE}} {
					append label {:}
					if {[string length $label] > 7} {
						append tmp_asm "$label\n"
						set label {}
					}
				}
				if {$instr == {CODE}} {
					if {$final_lbls > 999 && [string length $label] < 8} {
						append label "\t"
					}
				}
			}

			# Write line
			append label "\t" $instr "\t" [join $oprs {, }]
			append tmp_asm [string trimright $label] "\n"
		}

		# Append 'END' directive at the end
		append tmp_asm "\n\tEND"
		set asm $tmp_asm
	}

	## Free memory used during processing
	proc free_resources {} {
		variable tmp_asm	;# Tempotary variable for procedure: 'final_stage'
		variable hex_data	;# Raw input data
		variable hex		;# Adjusted input data, list: {addr hex0 hex1 hex2 ...}
		variable lineNum	;# Number of line currently beeing parsed
		variable error_count	;# Number of errors raised during disassembly
		variable label_idx	;# Label index
		variable label		;# Array of tempotary labels, label(int) -> addr
		variable asm		;# Resulting source code

		set tmp_asm	{}
		set hex_data	{}
		set hex		{}
		set lineNum	{}
		set error_count	{}
		set label_idx	{}
		catch {array unset label}
	}

	## Adjust hexadecimal number
	 # note: resulting number starts with digit
	 # @parm String number - input
	 # @return String - result
	proc HEX {number} {

		set number [string trimleft $number 0]
		if {$number == {}} {return 0}

		if {[regexp {^[a-fA-F]} $number]} {
			return "0$number"
		}

		return $number
	}

	## Report warning message
	 # @parm Int LineNumber		- Number of line where it occurred
	 # @parm String ErrorInfo	- Text of the warning
	 # @return void
	proc Warning {ErrorInfo} {
		variable idx		;# Current position in asm list
		variable warning_count	;# Number of warnings occurred

		# Increment warning counter
		incr warning_count

		# Report the warning
		if {${::Compiler::Settings::WARNING_LEVEL} < 2} {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {WN}][mc "Warning: %s" $ErrorInfo]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "\033\[33mWarning\033\[m: %s" $ErrorInfo]
			}
		}
	}

	## Error
	 # @parm Int lineNumber	- number of line, where the error occurred
	 # @parm String info	- error string
	proc Error {lineNumber info} {
		variable error_count
		incr error_count
		if {$lineNumber != {}} {
			if {${::Compiler::Settings::NOCOLOR}} {
				set lineNumber [mc " at %s" $lineNumber]
			} else {
				set lineNumber [mc " at \033\[31;1;4m%s\033\[m" $lineNumber]
			}
		}
		if {${::Compiler::Settings::WARNING_LEVEL} < 3} {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {EL}][mc "Error%s: %s" $lineNumber $info]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "\033\[31;1mError%s\033\[m: %s" $lineNumber $info]
			}
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

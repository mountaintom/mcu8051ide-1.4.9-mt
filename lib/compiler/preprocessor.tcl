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
if { ! [ info exists _PREPROCESSOR_TCL ] } {
set _PREPROCESSOR_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# 8051 Assembly language compiler preprocessor. This code is part of Compiler
# (see compiler.tcl). This NS generates precompiled code for assembler
# (see assembler.tcl).
#
# Requires:
#	- CompilerConsts	(compilerconsts.tcl)
#	- CodeListing		(codelisting.tcl)
#	- NumSystem		(Math.tcl)
#
# Basic principle of operation:
#	1) Remove comments and include files
#	2) Process control sequences ($SOMETHING)
#	3) Define as much constants/variables as possible (with cross references)
#	4) Conditional compilation and directive USING
#	5) Define macro instructions
#	6) Recomposite code according to ORG directives
#	7) Expand macro instructions (recursive with cross references)
#	8) Final stage
#
# Summary:
#	As you can see it is not just antother two pass assembler. This one
#	is much more sophisticated an much much slower than almost any other
#	8051 assembler. This assembler should be backward compatible with
#	MetaLink® ASM51 and ASEM-51 by W.W. Heinz.
# --------------------------------------------------------------------------

namespace eval PreProcessor {

	## General
	variable asm		{}	;# Resulting pre-compiled code
	variable tmp_asm	{}	;# Temporary auxiliary pre-compiled code
	variable lineNum	0	;# Number of the current line
	variable fileNum	0	;# Number of the current file
	variable program_memory		;# String of booleans: Map of program memory usage
	variable idx		0	;# Current position in asm list
	variable optims		0	;# Number of performed optimizations
	variable macros_first	1	;# Bool: Define and expand macro instruction before conditional
					;#+ assembly and constants expansions

	## Errors and warnings
	variable ErrorAtLine	0	;# Bool: Error occurred on the current line
	variable Error		0	;# Bool: An error occurred during precompilation
	variable error_count	0	;# Number of errors occurred
	variable warning_count	0	;# Number of warnings occurred

	## Conditional compilation
	variable Enable		1	;# Bool: Compilation enabled (conditional compilation)
	variable IfElse_map		;# Array: Conditional compilation map ($IfElse_map($level) == $bool)
	variable IfElse_pcam		;# Array: Conditional compilation -- Positive condition already met ($IfElse_pcam($level) == $bool)
	variable IfElse_level	0	;# Current level of conditional compilation evaluation

	## Memory reservation
	variable selected_segment	;# Current memory segment (one of {cseg bseg dseg iseg xseg})
	variable memory_reservation_map	;# Array: memory reservation map (see code)
	variable segment_pointer	;# Current memory segment pointer

	## Contants/Variables definitions
	variable const_BIT		;# Array: Bit values -- ($const_BIT($bit_name) == $value)
	variable const_CODE		;# Array: Constants defined by directive 'CODE'
	variable const_DATA		;# Array: Constants defined by directive 'DATA'
	variable const_IDATA		;# Array: Constants defined by directive 'IDATA'
	variable const_XDATA		;# Array: Constants defined by directive 'XDATA'
	variable const_SET		;# Array: Constants defined by directive 'CODE'
	variable const_EQU		;# Array: Constants defined by directive 'EQU'
	variable const_SET_SPEC		;# Array: Special constants defined by directive 'CODE'
	variable const_EQU_SPEC		;# Array: Special constants defined by directive 'EQU'
	variable labels			;# Array: Values of defined labels ($labels($label) == $address)
	variable defined_BIT	{}	;# List of defined bits (directove 'BIT')
	variable defined_CODE	{}	;# List of constants defined by 'CODE'
	variable defined_DATA	{}	;# List of constants defined by 'DATA'
	variable defined_IDATA	{}	;# List of constants defined by 'IDATA'
	variable defined_XDATA	{}	;# List of constants defined by 'XDATA'
	variable defined_SET	{}	;# List of variables defined by 'SET'
	variable defined_EQU	{}	;# List of constants defined by 'EQU'
	variable defined_SET_SPEC {}	;# List of special variables defined by 'SET'
	variable defined_EQU_SPEC {}	;# List of special constants defined by 'EQU'
	variable defined_LABEL	{}	;# List of defined labels

	# List of lists containing names of defined constants
	variable const_definitions {
		defined_BIT	defined_CODE
		defined_DATA	defined_IDATA
		defined_XDATA	defined_SET
		defined_EQU	defined_SET_SPEC
		defined_EQU_SPEC
	}

	## Macro expansion
	variable macro			;# Array: Code of defined macro instructions
	variable defined_MACRO	{}	;# List of defined macro instructions
	variable local_M_labels		;# Array of lists: Local labels in macros $local_M_labels($macro_name) == {integer label0 ... labelN}
	variable macro_name_to_append	;# Name of currently defined macro instruction

	## Special variables
	variable original_expression	;# Auxiliary variable (see proc. 'ComputeExpr')
	variable tmp			;# General purpose tempotary variable
	variable DB_asm		{}	;# Temporary asm code for creating code memory tables
	variable included_files	{}	;# List: Unique unsorted list of included files
	variable working_dir	{}	;# String: Current working directory
	variable origin_d_addr	{}	;# List: Addresses of static program blocks

	## Configuration variables
	variable max_include_level 8	;# Maximum inclusion level
	variable max_macro_level   8	;# Maximum macro expansion level
	variable check_sfr_usage   0	;# Bool: Check for legal usage of SFR and SFB
	variable available_SFR	   {}	;# List: Available SFR and SFB on the target MCU


	# ----------------------------------------------------------------
	# GENERAL PURPOSE PROCEDURES
	# ----------------------------------------------------------------

	## Initialize preprocessor
	 # @parm String current_dir	- Directory containing source file
	 # @parm String filename	- Name of file containing source code
	 # @parm String data		- Source code to compile
	 # @return List - precompiled source code
	proc compile {current_dir filename data} {
		variable macros_first	1	;# Bool: Define and expand macro instruction before conditional
						;#+ assembly and constants expansions
		variable memory_reservation_map	;# Array: memory reservation map (see code)
		variable working_dir		;# String: Current working directory
		variable asm			;# Resulting pre-compiled code
		variable segment_pointer	;# Current memory segment pointer
		variable error_count		;# Number of errors occurred
		variable warning_count		;# Number of warnings occurred
		variable max_include_level	;# Maximum inclusion level
		variable max_macro_level	;# Maximum macro expansion level
		variable optims			;# Number of performed optimizations
		variable included_files		;# List: Unique unsorted list of included files
		variable selected_segment	;# Current memory segment (one of {cseg bseg dseg iseg xseg})
		variable const_EQU		;# Array: Constants defined by directive 'EQU'
		variable defined_EQU		;# List of constants defined by 'EQU'

		# Reset memory segment pointers
		set segment_pointer(bseg)	0
		set segment_pointer(dseg)	0
		set segment_pointer(iseg)	0
		set segment_pointer(xseg)	0
		set selected_segment		cseg

		# Reset maps of memory reservation
		set memory_reservation_map(bseg) [ string repeat 0 256	]
		set memory_reservation_map(iseg) [ string repeat 0 256	]
		set memory_reservation_map(dseg) [ string repeat 0 256	]
		set memory_reservation_map(xseg) [ string repeat 0 65536]

		# Set constants "??MCU_8051_IDE" and "??VERSION"
		lappend defined_EQU {??mcu_8051_ide} {??version}
		set const_EQU(??mcu_8051_ide) 32849 ;# 8051h
		scan $::VERSION "%d.%d.%d" i j k
		set i [expr {($i << 8) + ($j << 4) + $k}]
		set const_EQU(??version) $i

		# Reset counters of errors and warnings
		set error_count		0
		set warning_count	0

		# Incialize list of included files
		set working_dir $current_dir
		set included_files [list [file normalize [file join $current_dir $filename]]]

		set asm $data
		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
			free_resources
			return
		}

		## Convert code to this format:
		 # {
		 #	{{lineNumber} {fileNumber} {line of code}}
		 #	...
		 # }
		line_numbers

		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
			free_resources
			return
		}

		# Import code pieces (INCLUDE file.asm // $INCLUDE('file.inc'))
		set counter 0
		while {1} {
			if {![include_directive $current_dir]} {break}
			incr counter
			if {$counter > $max_include_level} {
				CompilationError "unknown" {} [mc "Inclusion nesting exceeded maximum allowed level"]
				break
			}
		}

		# Remove code after END directive
		end_of_code

		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
			free_resources
			return
		}

		# Remove comments and redutant white space
		trim_code
		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
			free_resources
			return
		}

		## Parse controls like $TITLE('bla...bla') or $DATE(36/13/1907)
		parse_controls
		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
			free_resources
			return
		}

		# Discard code listing if listing os not required
		if {!${::Compiler::Settings::PRINT}} {
			CodeListing::free_resources
		}

		# Define basic symbolc names (eg. P0)
		if {!${::Compiler::Settings::NOMOD}} {
			define_basic_symbolic_names
		}

		if {$macros_first} {
			# Define macro instructions
			define_macro_instructions
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			# Expand macro instructions
			set counter 0
			while {1} {
				if {![expand_macro_instructions]} {break}
				incr counter
				if {$counter > $max_macro_level} {
					CompilationError "unknown" {} [mc "Macro nesting exceeded maximum allowed level"]
					break
				}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}
		}

		## Parse these directives:
		 #	- Donditional compilation		(IF, ELSE, ENDIF)			(group 0)
		 #	- Code listing enable/disable		(LIST, NOLIST)				(group 1)
		 #	- Active bank selection			(USING)					(group 2)
		 #	- Data memory segment selection		(BSEG, DSEG, ISEG, XSEG)		(group 3)
		 #	- Constant definitions			(SET, EQU, BIT, DATA, IDATA, XDATA)	(group 4)
		 #	- Date memory reservation		(DS, DBIT)				(group 5)
		while {1} {
			if {![parse_Consts_and_ConditionalCompilation {0 0 1 1 1 1} 1]} {
				break
			}
		}

		parse_Consts_and_ConditionalCompilation {1 1 1 1 1 1} 1
		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
			free_resources
			return
		}

		# Process code memory related directives (CSEG DB DW)
		code_segment 1
		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
			free_resources
			return
		}

		if {!$macros_first} {
			# Define macro instructions
			define_macro_instructions
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}
		}

		# Reassemble code according to ORG directives
		origin_directive
		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
			free_resources
			return
		}

		if {!$macros_first} {
			# Expand macro instructions
			set counter 0
			while {1} {
				if {![expand_macro_instructions]} {break}
				incr counter
				if {$counter > $max_macro_level} {
					CompilationError "unknown" {} [mc "Macro nesting exceeded maximum allowed level"]
					break
				}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}
		}

		## Do three things:
		 # * Convert code to this format:
		 # 	{
		 #		{
		 #			{lineNumber} {fileNumber} {instructionAddress} {instructionLength} {instruction}
		 #				{oprerand0 operand1 ...} {operand0_type ...}
		 #		} ...
		 # 	}
		 # * Parse labels definition
		 # * Create map of program memory usage (bitmap)
		parse_instructions

		# Perform code optimizations
		set optims 0
		if {${::Compiler::Settings::optim_ena}} {
			optimization
		}

		# Final constants expansion
		while {1} {
			if {![parse_Consts_and_ConditionalCompilation {0 0 1 1 1 1} 0]} {
				break
			}
		}

		# Import table of symbols to current code listing
		CodeListing::import_symbolic_names

		if {${::Compiler::Settings::ABORT_VARIABLE}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
			free_resources
			return
		}

		## Final stage -- finaly encapsulate code to the resulting form:
		 # 	{
		 #		{
		 #			{lineNumber} {fileNumber} {instructionAddress} {instruction}
		 #				{oprerand0 operand1 ...} {operand0_type ...}
		 #		} ...
		 # 	}
		final_stage

		# Free reserved resources
		free_resources

		# Return precompiled code
		return $asm
	}

	## Free reserved resources
	 # @return void
	proc free_resources {} {
		variable memory_reservation_map	;# Array: memory reservation map (see code)
		variable segment_pointer	;# Current memory segment pointer
		variable const_BIT		;# Array: Bit values -- ($const_BIT($bit_name) == $value)
		variable const_CODE		;# Array: Constants defined by directive 'CODE'
		variable const_DATA		;# Array: Constants defined by directive 'DATA'
		variable const_IDATA		;# Array: Constants defined by directive 'IDATA'
		variable const_XDATA		;# Array: Constants defined by directive 'XDATA'
		variable const_SET		;# Array: Constants defined by directive 'CODE'
		variable const_EQU		;# Array: Constants defined by directive 'EQU'
		variable macro			;# Array: Code of defined macro instructions
		variable local_M_labels		;# Array of lists: Local labels in macros $local_M_labels($macro_name) == {integer label0 ... labelN}
		variable program_memory		;# String of booleans: Map of program memory usage
		variable labels			;# Array: Values of defined labels ($labels($label) == $address)
		variable defined_BIT	{}	;# List of defined bits (directove 'BIT')
		variable defined_CODE	{}	;# List of constants defined by 'CODE'
		variable defined_DATA	{}	;# List of constants defined by 'DATA'
		variable defined_IDATA	{}	;# List of constants defined by 'IDATA'
		variable defined_XDATA	{}	;# List of constants defined by 'XDATA'
		variable defined_SET	{}	;# List of variables defined by 'SET'
		variable defined_EQU	{}	;# List of constants defined by 'EQU'
		variable defined_SET_SPEC {}	;# List of variables defined by 'SET'
		variable defined_EQU_SPEC {}	;# List of constants defined by 'EQU'
		variable defined_LABEL	{}	;# List of defined labels
		variable defined_MACRO	{}	;# List of defined macro instructions

		catch {unset macro}
		catch {unset local_M_labels}
		catch {unset memory_reservation_map}
		catch {unset segment_pointer}
		catch {unset const_BIT}
		catch {unset const_CODE}
		catch {unset const_DATA}
		catch {unset const_IDATA}
		catch {unset const_XDATA}
		catch {unset const_SET}
		catch {unset const_EQU}
		catch {unset const_SET_SPEC}
		catch {unset const_EQU_SPEC}
		catch {unset program_memory}
		catch {unset labels}
	}


	# ----------------------------------------------------------------
	# INTERNAL AUXILIARY PROCEDURES
	# ----------------------------------------------------------------

	## Define basic symbolic names according to MapOfSFRArea, MapOfSFRBitArea and progVectors
	 # @return void
	proc define_basic_symbolic_names {} {
		variable const_BIT	;# Array: Bit values -- ($const_BIT($bit_name) == $value)
		variable const_DATA	;# Array: Constants defined by directive 'DATA'
		variable const_CODE	;# Array: Constants defined by directive 'CODE'
		variable defined_BIT	;# List of defined bits (directove 'BIT')
		variable defined_DATA	;# List of constants defined by 'DATA'
		variable defined_CODE	;# List of constants defined by 'CODE'

		# Define bits
		foreach def ${::CompilerConsts::MapOfSFRBitArea} {
			set var [lindex $def 0]	;# Name
			set val [lindex $def 1]	;# Address
			# Adjust name
			set var [string tolower $var]
			# Define
			lappend defined_BIT $var
			set const_BIT($var) [expr "0x$val"]
		}

		# Define registers
		foreach def ${::CompilerConsts::MapOfSFRArea} {
			set var [lindex $def 0]	;# Name
			set val [lindex $def 1]	;# Address
			# Adjust name
			set var [string tolower $var]
			# Define
			lappend defined_DATA $var
			set const_DATA($var) [expr "0x$val"]
		}

		# Define Program vectors
		foreach def ${::CompilerConsts::progVectors} {
			set var [lindex $def 0]	;# Name
			set val [lindex $def 1]	;# Address
			# Adjust name
			set var [string tolower $var]
			# Define
			lappend defined_CODE $var
			set const_CODE($var) [expr "0x$val"]
		}
	}

	## Split the given cotrol sequence into its name and argument (without parentheses and quotes)
	 # @parm String data - line of source code to evaluate
	 # @return List - {control argument}
	proc evaluateControl {data} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		# Make backup for input data
		set original_data $data

		# Determinate control name
		set data [string range $data 1 end]
		if {[regexp {^\w+} $data control]} {
			regsub {^\w+} $data {} data
			set control [string tolower $control]
		} else {
			set control {}
		}

		# Control without argument
		if {$data == {}} {
			return [list $control {}]
		}

		# Determinate argument
		if {[regexp {^\(.*\)} $data argument]} {
			# Remove parentheses
			regsub {^\(.*\)} $data {} data
			set argument [string trimleft $argument {(}]
			set argument [string trimright $argument {)}]

			# Remove quotes
			if {[string index $argument 0] == {'}} {
				if {[string index $argument end] != {'}} {
					SyntaxError $lineNum $fileNum [mc "Invalid argument: %s" $argument]
				} else {
					set argument [string trimleft $argument {'}]
					set argument [string trimright $argument {'}]
				}
			}
		} else {
			set argument {}
		}

		# Line cannot contain anything except CS
		if {$data != {}} {
			SyntaxError $lineNum $fileNum [mc "Extra characters after control sequence: %s" $original_data]
		}

		# Return result
		return [list $control $argument]

	}

	## Adjust compiler settings to the specified control sequence
	 # @parm String condition	- Condition variable (if 1 then dismiss)
	 # @parm String setting		- Target configuration variable
	 # @parm String value		- New configuration value
	 # @return Bool - One if setting was accepted, zero if setting was dismissed
	proc AssemblerContol {condition setting value} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		# Determinate condition value
		set condition [subst -nocommands "\${::Compiler::Settings::$condition}"]

		# Accept
		if {$condition == 0} {
			set Compiler::Settings::$setting $value
			return 1
		# Dismiss
		} else {
			Notice $lineNum $fileNum [mc "Control %s has been overridden (by compiler settings)" $setting]
			return 0
		}
	}

	## Invoke error message if the given control sequence has no argument
	 # @parm String control		- Control sequence (name only)
	 # @parm String argument	- Argument (without parantesis and quotes)
	 # @return Bool - result (1 == success; 0 == error message)
	proc AssemblerContol_expect_one_argument {control argument} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		if {$argument == {}} {
			SyntaxError $lineNum $fileNum	\
				[mc "Control `%s' expect exactly one argument, but no argument given" "\$[string toupper $control]"]
			return 0
		}
		return 1
	}

	## Invoke error message if the given control sequence has an argument
	 # @parm String control		- Control sequence (name only)
	 # @parm String argument	- Argument (without parantesis and quotes)
	 # @return Bool - result (1 == success; 0 == error message)
	proc AssemblerContol_expect_no_argument {control argument} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		if {$argument != {}} {
			SyntaxError $lineNum $fileNum [mc "Control `%s' takes no arguments." "\$[string toupper $control]"]
			return 0
		}
		return 1
	}

	## Evaluate and remove control sequences
	 # @return void
	proc parse_controls {} {
		variable asm		;# Resulting pre-compiled code
		variable tmp_asm	;# Temporary auxiliary pre-compiled code
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable idx		;# Current position in asm list

		variable macros_first	1	;# Bool: Define and expand macro instruction before conditional
						;#+ assembly and constants expansions

		# Reset NS variables
		set tmp_asm {}
		set idx -1

		# Iterate over the code
		foreach line $asm {
			incr idx

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			# Determinate line number and line content
			set lineNum	[lindex $line 0]
			set fileNum	[lindex $line 1]
			set line	[lindex $line 2]

			# Skip lines without a control sequence
			if {[string index $line 0] != "\$"} {
				lappend tmp_asm [list $lineNum $fileNum $line]
				continue
			}

			# Remove this line from sync. map in code listing
			CodeListing::delete_line $idx
			incr idx -1

			# Get and anylize control sequence
			set ctrl [evaluateControl $line]
			set control	[lindex $ctrl 0]	;# Name
			set argument	[lindex $ctrl 1]	;# Argument

			# Adjust compiler settings according to the control sequence
			switch -- $control {
				{nomacrosfirst} {
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						set macros_first 0
					}
				}
				{eject}		{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						CodeListing::directive_eject $idx
					}
				}
				{ej}		{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						CodeListing::directive_eject $idx
					}
				}
				{nolist}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						CodeListing::directive_nolist $idx
					}
				}
				{noli}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						CodeListing::directive_nolist $idx
					}
				}
				{list}		{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						CodeListing::directive_list $idx
					}
				}
				{li}		{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						CodeListing::directive_list $idx
					}
				}
				{nomod}		{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _nomod NOMOD 1
					}
				}
				{nomod51}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _nomod NOMOD 1
					}
				}
				{nomo}		{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _nomod NOMOD 1
					}
				}
				{paging}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _paging PAGING 1
					}
				}
				{pi}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _paging PAGING 1
					}
				}
				{nopaging}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _paging PAGING 0
					}
				}
				{nopi}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _paging PAGING 0
					}
				}
				{pagewidth}	{
					if {[AssemblerContol_expect_one_argument $control $argument]} {
						if {[regexp {^\d+$} $argument]} {
							AssemblerContol _pagewidth PAGEWIDTH $argument
						} else {
							SyntaxError $lineNum $fileNum	\
								[mc "Invalid argument (must be integer): %s" $argument]
						}
					}
				}
				{pw}	{
					if {[AssemblerContol_expect_one_argument $control $argument]} {
						if {[regexp {^\d+$} $argument]} {
							AssemblerContol _pagewidth PAGEWIDTH $argument
						} else {
							SyntaxError $lineNum $fileNum	\
								[mc "Invalid argument (must be integer): %s" $argument]
						}
					}
				}
				{pagelength}	{
					if {[AssemblerContol_expect_one_argument $control $argument]} {
						if {[regexp {^\d+$} $argument]} {
							AssemblerContol _pagelength PAGELENGTH $argument
						} else {
							SyntaxError $lineNum $fileNum	\
								[mc "Invalid argument (must be integer): %s" $argument]
						}
					}
				}
				{pl}	{
					if {[AssemblerContol_expect_one_argument $control $argument]} {
						if {[regexp {^\d+$} $argument]} {
							AssemblerContol _pagelength PAGELENGTH $argument
						} else {
							SyntaxError $lineNum $fileNum	\
								[mc "Invalid argument (must be integer): %s" $argument]
						}
					}
				}
				{title}		{
					if {[AssemblerContol_expect_one_argument $control $argument]} {
						AssemblerContol _title TITLE $argument
					}
				}
				{tt}		{
					if {[AssemblerContol_expect_one_argument $control $argument]} {
						AssemblerContol _title TITLE $argument
					}
				}
				{date}		{
					if {[AssemblerContol_expect_one_argument $control $argument]} {
						AssemblerContol _date DATE $argument
					}
				}
				{da}		{
					if {[AssemblerContol_expect_one_argument $control $argument]} {
						AssemblerContol _date DATE $argument
					}
				}
				{object}	{
					if {[AssemblerContol_expect_one_argument $control $argument]} {
						AssemblerContol _object OBJECT_FILE $argument
						AssemblerContol _object OBJECT 1
					}
				}
				{noobject}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _object OBJECT 0
					}
				}
				{nosb}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _symbols SYMBOLS 0
					}
				}
				{nosymbols}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _symbols SYMBOLS 0
					}
				}
				{noprint}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _print PRINT 0
					}
				}
				{symbols}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _symbols SYMBOLS 1
					}
				}
				{sb}	{
					if {[AssemblerContol_expect_no_argument $control $argument]} {
						AssemblerContol _symbols SYMBOLS 1
					}
				}
				{print}		{
					if {[AssemblerContol_expect_one_argument $control $argument]} {
						AssemblerContol _print PRINT_FILE $argument
						AssemblerContol _print PRINT 1
					}
				}
				default		{
					Warning $lineNum $fileNum [mc "Unsupported control sequence: %s -- control sequence ignored" $line]
				}
			}
		}

		# Replace old code with the new one
		set asm $tmp_asm

	}

	## Evaluate and code memory reservation directives (CSEG DB DW)
	 # @parm Bool ignore_undefined	- Ignore undefined symbolic names
	 # @return void
	proc code_segment {ignore_undefined} {
		variable asm			;# Resulting pre-compiled code
		variable tmp_asm		;# Temporary auxiliary pre-compiled code
		variable lineNum		;# Number of the current line
		variable fileNum		;# Number of the current file
		variable selected_segment	;# Current memory segment (one of {cseg bseg dseg iseg xseg})
		variable segment_pointer	;# Current memory segment pointer
		variable idx			;# Current position in asm list

		# Reset NS variables
		set tmp_asm	{}
		set segment_pointer(cseg) {}

		set value	{}
		set idx -1

		# Iterate over the code
		foreach line $asm {
			incr idx

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			# Anylize line
			set lineNum	[lindex $line 0]			;# Line number
			set fileNum	[lindex $line 1]			;# File number
			set line	[lindex $line 2]			;# Line code
			set cmd		[split_line $line]			;# label, command and argumet(s)
			set directive	[regsub {^\.} [lindex $cmd 1] {}]	;# Directive

			# Directive 'DB' (byte reservation) or 'DW' (word reservation)
			if {$directive == {db} || $directive == {dw} || $directive == {byte}} {
				# Handle directive "BYTE", which has exactly the same meaning as the "DB"
				#+ "BYTE" is borrowed from AS31 assembler
				if {$directive == {byte}} {
					Warning $lineNum $fileNum [mc "You are using unusual directive 'BYTE', consider usage of 'DB' instead"]
					set directive {db}
				}

				set result [reserve_code_memory $cmd $directive $idx $ignore_undefined]
				if {$result != {}} {
					incr idx $result
				}

			# Directive 'CSEG' - code segment selection
			} elseif {$directive == {cseg}} {
				set discontinue 0

				# Check if there is a label
				if {[lindex $cmd 0] != {}} {
					SyntaxError $lineNum $fileNum [mc "CSEG cannot take any label: %s" [lindex $cmd 0]]
					set discontinue 1
				}

				if {!$discontinue} {
					# Set the code segment
					set selected_segment {cseg}

					# Check for presence of an address expression
					set expr [lindex $cmd 2]
					if {$expr == {}} {
						set segment_pointer(cseg) {}
						set discontinue 1
					}

					if {!$discontinue} {
						# Check for presence of 'AT' operator (CSEG AT addr)
						if {[string tolower [lindex $expr 0]] != {at}} {
							SyntaxError $lineNum $fileNum [mc "Missing `AT' operator"]
							set discontinue 1
						}
						set expr [lreplace $expr 0 0]
					}
				}

				# Remove this line from the code listing
				if {$discontinue} {
					CodeListing::delete_line $idx
					incr idx -1
					continue
				}

				# Determinate, set and validate segment pointer
				set value [ComputeExpr $expr]
				if {$value != {}} {
					# Validate address
					if {$value > 65535} {
						SyntaxError $lineNum $fileNum [mc "Argument value out of range: %s  (%s)" $expr $value]
						continue
					}
					# Set pointer
					set segment_pointer(cseg) $value
					# Adjust code
					lappend tmp_asm [list $lineNum $fileNum [list {ORG} $value]]
				} else {
					SyntaxError $lineNum $fileNum [mc "Invalid expression `%s'" $expr]
					CodeListing::delete_line $idx
					incr idx -1
				}

			# Line does not contain any of {CSEG DB DW}
			} else {
				lappend tmp_asm [list $lineNum $fileNum $line]
			}
		}

		# Finalize code adjustment
		append tmp_asm { }
		set asm $tmp_asm
	}

	## Reserve code memory (byte or word) -- directives 'DB' 'DW'
	 # -- auxiliary procedure for proc. 'code_segment'
	 # This procedure writes result to NS variable 'tmp_asm'
	 # @parm String cmd		- Line of source code adjusted by proc. 'split_line'
	 # @parm String directive	- Directive name (one of {DB DW})
	 # @parm String idx		- Source index (precompiled code list)
	 # @parm Bool ignore_undefined	- Ignore undefined symbolic names
	 # @return Int - Byte length of occupied program memory
	proc reserve_code_memory {cmd directive idx ignore_undefined} {
		variable lineNum		;# Number of the current line
		variable fileNum		;# Number of the current file
		variable selected_segment	;# Current memory segment (one of {cseg bseg dseg iseg xseg})
		variable segment_pointer	;# Current memory segment pointer
		variable tmp_asm		;# Temporary auxiliary pre-compiled code

		# Determinate maximum value
		if {$directive == {db}} {
			set directive_db 1
			set max 255
		} elseif {$directive == {dw}} {
			set directive_db 0
			set max 65535
		} else {
			CompilationError $lineNum $fileNum "Unknown error 7"
			return
		}

		# Check if the currently selected memory segment is 'CSEG'
		if {$selected_segment != {cseg}} {
			Warning $lineNum $fileNum [mc "Using `%s', but active segment is `%s' (should be CSEG)" [string toupper $directive] [string toupper $selected_segment]]
		}

		# Validate directive operands
		set operands [lindex $cmd 2]
		if {$operands == {}} {
			SyntaxError $lineNum $fileNum [mc "Missing value"]
			return
		}
		set operands [getOperands $operands 1]
		if {[llength $operands] == 0} {
			SyntaxError $lineNum $fileNum [mc "Invalid value"]
			return
		}
		# Check for allowed number of arguments
		if {!$directive_db && [llength $operands] > 1} {
			SyntaxError $lineNum $fileNum [mc "Directive DW can take only one argument"]
			return
		}

		# Determinate label
		set label [lindex $cmd 0]
		if {$label != {}} {
			append label { }
		}

		# Iterate over directive operands
		set first_time 1
		set undefined 0
		set total_len 0
		foreach opr $operands {
			set undefined 0
			set len -1

			# Operand is a string
			if {![isExpression $opr] && ([string index $opr 0] == {'}) && ([string index $opr end] == {'})} {
				# Adjust operand
				set opr [string trimleft $opr {'}]
				set opr [string trimright $opr {'}]
				regsub -all {''} $opr {'} opr
				set opr [subst -nocommands -novariables $opr]
				set opr_length [string length $opr]

				# Initialize list of decimal operand values (per bytes)
				set values {}

				# Convert each character separately (to decimal)
				set escaped 0
				for {set char_idx 0} {$char_idx < $opr_length} {incr char_idx} {
					set char [string index $opr $char_idx]

					# Convert character
					set value [character2number $char]

					# Invalid value
					if {$value == {}} {
						CompilationError $lineNum $fileNum [mc "Unable to recognize character: `%s'" $char]
						continue

					# Valid value
					} else {
						if {$first_time} {
							set line [list [list $lineNum $fileNum "${label}DB $value"]]
						} else {
							set line [list [list $lineNum $fileNum [list DB $value]]]
						}
						set first_time 0
						lappend values $value
					}

					incr len

					# Adjust precompiled code
					append tmp_asm { }
					append tmp_asm $line
				}

				# Adjust code listing
				CodeListing::db $idx $values
				CodeListing::insert_empty_lines $idx $len

			# Operand is a direct numerical value, expression, constant, label or variable
			} else {

				# Evaluate operand value
				set value [ComputeExpr $opr $ignore_undefined]

				# Unable to compute value
				if {$value == {}} {
					# Value could not be determinated in this pass
					if {$ignore_undefined} {
						set undefined 1
						set value $opr

					# Invalid value
					} else {
						CompilationError $lineNum $fileNum [mc "Invalid expression `%s'" $opr]
						continue
					}
				}

				## Valid value

				# Check for valid range
				if {!$undefined && (($value > $max) || ($value < 0))} {
					SyntaxError $lineNum $fileNum [mc "Argument value out of range: %s" $opr]
					continue
				}

				# Round value
				if {!$undefined} {
					set value [expr {int($value)}]
				}

				# One byte (directive DB)
				if {$directive_db} {
					if {$first_time} {
						set line [list [list $lineNum $fileNum "${label}DB $value"]]
					} else {
						set line [list [list $lineNum $fileNum [list DB $value]]]
					}

					incr len
					set first_time 0

					# Adjust code listing
					CodeListing::db $idx $value

				# Two bytes (directive DW)
				} else {
					# Spilt value into high- and low-order bytes
					if {$undefined} {
						set H_value "(($value) / 256)"
						set L_value "(($value) % 256)"
					} else {
						set H_value [expr {$value / 256}]
						set L_value [expr {$value % 256}]
					}
					if {$first_time} {
						set line [list						\
							[list $lineNum $fileNum "${label}DB {$H_value}"]\
							[list $lineNum $fileNum [list {DB} $L_value]]	\
						]
					} else {
						set line [list						\
							[list $lineNum $fileNum [list {DB} $H_value]]	\
							[list $lineNum $fileNum [list {DB} $L_value]]	\
						]
					}

					incr len 2
					set first_time 0

					# Adjust code listing
					CodeListing::db $idx [list $H_value $L_value]
					CodeListing::insert_empty_lines $idx 1
				}

				# Adjust precompiled code
				append tmp_asm { }
				append tmp_asm $line
			}

			incr len
			incr total_len $len
		}

		CodeListing::insert_empty_lines $idx [expr {[llength $operands] - 1}]

		incr total_len -1
		return $total_len
	}

	## Split the given line of code into label, command and argumet(s)
	 # @parm String line - Line of source code
	 # @return List - {label command argument} or {label}
	proc split_line {line} {
		# Determinate label
		if {[regexp {^\w+:} $line label]} {
			regsub {^\w+:\s*} $line {} line
		} else {
			set label {}
		}
		# If line contains only label -> return only label
		if {$line == {}} {
			return $label
		}

		# Determinate command and argumet(s)
		if {![regexp {^\s*\.?\w+} $line command]} {
			set command {}
		} else {
			set command [string tolower [string trim $command]]
		}
		set argument [regsub {^[^\s]+\s*} $line {}]

		# Return result
		return [list $label $command $argument]
	}

	## Convert given list op operands to their final values (expand constants, labels and expressions)
	 # @parm Int address		- Instruction address
	 # @parm Int instr_lenght	- Instruction length in bytes
	 # @parm List operands		- List of operands
	 # @parm List operand_types	- List of operand types
	 # @parm String instruction	- Instruction name
	 # @parm Bool ignore_undefined	- Ignore undefined symbolic names
	 # @return List - resulting list of operands
	proc operands_to_absolute_values {address instr_lenght operands operand_types instruction ignore_undefined} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		# Initialize list of operands
		if {$instruction == {db}} {
			set new_operands $operands
			set operands {}
		} else {
			set new_operands {}
		}

		# Replace symbolic names with absolute values
		foreach opr $operands type $operand_types {

			# Fixed value (eg. 'A')
			if {[isFixed $opr]} {
				set char {}
				set opr_val $opr

			# Regular value
			} else {
				# Adjust value (remove 1st char is it's one of {# @ /})
				set char [string index $opr 0]
				if {$char == {#} || $char == {@} || $char == {/}} {
					set opr [string replace $opr 0 0]
				} else {
					set char {}
				}
				set opr_val {}

				# Value is an expression
				if {[isExpression $opr]} {
					append opr_val [ComputeExpr $opr $ignore_undefined $address]

				# Value is bit addres represented by dot notation
				} elseif {[regexp {^\w+\.\w+$} $opr]} {

					if {$type != {bit} && $type != {/bit}} {
						if {!$ignore_undefined} {
							SyntaxError $lineNum $fileNum [mc "Expected bit address: %s" $opr]
						}
					} else {
						set bitAddr [getBitAddr $opr $ignore_undefined]
						if {$bitAddr == {}} {set bitAddr 0}
						append opr_val $bitAddr
					}

				# Value is regular symbolic name
				} elseif {[isSymbolicName $opr]} {
					# Determinate list of substitution priorities
					switch -- $type {
						{code8}		{set priorities {labels code equset xdata}		}
						{code11}	{set priorities {labels code equset xdata}		}
						{code16}	{set priorities {labels code equset xdata}		}

						{imm8}		{set priorities {equset data idata xdata bit code labels}}
						{imm16}		{set priorities {equset data idata xdata bit code labels}}

						{data}		{set priorities {data idata equset}			}
						{bit}		{set priorities {bit equset}				}
						{/bit}		{set priorities {bit equset}				}
						default {
							CompilationError $lineNum $fileNum "Unknown error 0"
						}
					}

					# Perform substitution
					append opr_val [getValueOfSymbolicName	\
						$opr $priorities $address	\
						$ignore_undefined		\
					]

				# Direct value (some number)
				} else {
					append opr_val [COprToDec $opr]
				}

				# Adjust relative offset
				if {[string is digit -strict $opr_val]} {
					if {$type == {code8}} {
						incr opr_val -$address
						incr opr_val -$instr_lenght
						if {($opr_val > 127) || ($opr_val < -128)} {
							incr opr_val -0x10000
							if {($opr_val > 127) || ($opr_val < -128)} {
								if {!$ignore_undefined} {
									SyntaxError $lineNum $fileNum	\
										[mc "Label is too far for 8-bit relative addressing.\nTry to disable peephole optimizations if they are on."]
								}
								set opr_val 0
							}
						}
						if {$opr_val < 0} {
							incr opr_val 0x100
						}
					} elseif {$type == {code11}} {
						if {($opr_val & 0x0f800) != (($address + $instr_lenght) & 0x0f800)} {
							if {!$ignore_undefined} {
								SyntaxError $lineNum $fileNum [mc "Operand value out of range: `%s' (`%s')" $opr $opr_val]
							}
							set opr_val 0
						} else {
							set opr_val [expr {$opr_val & 0x007ff}]
						}
					}
				}
			}

			# Adjust list of operands
			lappend new_operands "${char}${opr_val}"

			# Check for valid value range
			if {$opr_val != {} && ![checkRange $opr_val $type]} {
				if {!$ignore_undefined && [string is digit -strict $opr_val]} {
					SyntaxError $lineNum $fileNum [mc "Operand value out of range: `%s' (`%s')" $opr $opr_val]
				} else {
					return {}
				}
			}
		}

		# Return result
		return $new_operands
	}

	## Finaly precompiled encapsulate code to the resulting form
	 # @return void
	proc final_stage {} {
		variable asm		;# Resulting pre-compiled code
		variable tmp_asm	;# Temporary auxiliary pre-compiled code
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable idx		;# Current position in asm list

		# Reset NS variables
		set idx -1
		set tmp_asm {}
		set new_operands {}

		# Expand constants, variables and labels
		foreach line $asm {
			incr idx

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			# Split line into separate fields
			set i 0
			foreach var {lineNum fileNum address instr_lenght instruction operands operand_types} {
				set $var [lindex $line $i]
				incr i
			}

			# Directive DB
			if {$instruction == {db}} {
				# Undefined value -> try to define
				set operands [lindex $operands 0]

				if {![string is digit -strict $operands]} {
					set value [ComputeExpr $operands 0 $address]
					if {$value == {}} {
						SyntaxError $lineNum $fileNum [mc "Invalid expression: `%s'" $operands]
					} elseif {$value < 0 || $value > 255} {
						SyntaxError $lineNum $fileNum [mc "Value out of range: `%s' (%s)" $operands $value]
					}
					set operands $value
				}

			# Check for instruction validity
			} elseif {[lsearch -exact -ascii ${::CompilerConsts::AllInstructions} $instruction] == -1} {
				if {[string index $address end] == {:}} {
					SyntaxError $lineNum $fileNum [mc "Invalid label declaration: `%s'\n\tLabels can contain alphanumeric characters only and must not begin with a digit" $address]
				} else {
					SyntaxError $lineNum $fileNum [mc "Unknown keyword: `%s'\n\t`%s' is neither macro nor instruction nor directive" [lindex $address 0] [lindex $address 0]]
				}
				continue
			}

			# Append adjusted line to the code
			lappend tmp_asm [list					\
				$lineNum	$fileNum	$address	\
				$instruction					\
				[operands_to_absolute_values			\
					$address	$instr_lenght		\
					$operands	$operand_types		\
					$instruction	0			\
				]						\
				$operand_types					\
			]
		}

		# Resolve: "DW <label>", and "DB ..., <label>, ..."
		if {${::Compiler::Settings::PRINT}} {
			set new_lst {}
			foreach lst_line $CodeListing::lst {
				set op_code [lindex $lst_line 1]
				if {[llength $op_code] > 1} {
					set take_next 0
					set new_op_code {}
					foreach op $op_code {
						if {{} == $op} {
							set take_next 1
							continue
						} elseif {$take_next} {
							set take_next 0
							append new_op_code [format %02X [ComputeExpr $op 0]]
						} else {
							append new_op_code $op
						}
					}
					lset lst_line 1 $new_op_code
				}
				lappend new_lst $lst_line
			}
			set CodeListing::lst $new_lst
		}

		# Replace old code with the new one
		set asm $tmp_asm
	}

	## Convert bit addres represented by dot notation to decimal string
	 # @parm String expression - bit address (eg. 'PSW.4')
	 # @parm Bool ignore_undefined		- Ignore undefined symbolic names
	 # @return Int - Bit address
	proc getBitAddr {expression ignore_undefined} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		# Split bit address into two parts
		set opr1 [split $expression {.}]
		set opr0 [lindex $opr1 0]	;# Register
		set opr1 [lindex $opr1 1]	;# Bit

		# Register is 'A'
		if {$opr0 == {A} || $opr0 == {a}} {
			set regAddr 224
		# Register is a symbolic name
		} elseif {[isSymbolicName $opr0]} {
			set regAddr [getValueOfSymbolicName	\
				$opr0 {data idata equset} {}	\
				$ignore_undefined		\
			]
		# Register is regular number
		} else {
			set regAddr [COprToDec $opr0]
		}

		# Bit is a symbolic name
		if {[isSymbolicName $opr1]} {
			set bitNum [getValueOfSymbolicName	\
				$opr1 {equset} {}		\
				$ignore_undefined		\
			]
		# Bit is regular number
		} else {
			set bitNum [COprToDec $opr1]
		}

		# Check for valid bit number value
		if {$bitNum < 0 || $bitNum > 7} {
			SyntaxError $lineNum $fileNum [mc "Invalid bit designator: %s" $expression]
			return {}
		}

		# Register is in high bit addressable area
		if {$regAddr > 31 && $regAddr < 48} {
			return [expr {($regAddr - 32) * 8 + $bitNum}]
		# Register bit addressable SFR
		} elseif {[lsearch -exact -ascii {128 136 144 152 160 168 176 184 208 224 240} $regAddr] != -1} {
			return [expr {$regAddr + $bitNum}]
		# Register is not bit addressable
		} else {
			SyntaxError $lineNum $fileNum [mc "Given register does not belong to the bit addressable area: %s" $expression]
			return {}
		}
	}

	## Convert operand value to decimal string (operand must not be an expression)
	 # @parm String operand - operand string (eg. '#0F5h')
	 # @return String - converted operand
	proc COprToDec {operand} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		# If the given operand is fixed string -> return it unchanged
		if {[lsearch -exact -ascii ${::CompilerConsts::FixedOperands} [string tolower $operand]] != -1} {
			return $operand
		}

		# Adjust operand string
		set char [string index $operand 0]
		if {$char == {#} || $char == {@} || $char == {/}} {
			set operand [string replace $operand 0 0]
		} else {
			set char {}
		}

		# Handle prefix notation for hexadecimal numbers, like 0xfa
		if {
			[string index $operand 0] == {0}
				&&
			([string index $operand 1] == {x} || [string index $operand 1] == {X})
		} then {
			set operand [string replace $operand 0 1]
			if {![string is digit [string index $operand 0]]} {
				set operand "0${operand}"
			}
			append operand {h}
		}

		# Determinate numeric base and adjust operand string
		set base	[string index $operand end]
		set operand	[string range $operand 0 {end-1}]

		# No base specified -- decimal number
		if {[regexp {[0-9]} $base]} {
			append operand $base

			# Convert and return
			if {[NumSystem::isdec $operand]} {
				return "$char$operand"
			} else {
				SyntaxError $lineNum $fileNum [mc "Invalid value: `%s'" "${char}${operand}"]
			}

		# Value is a charater
		} elseif {$base == {'}} {
			# Remove leading quote
			if {[string index $operand 0] != {'}} {
				SyntaxError $lineNum $fileNum [mc "Invalid value: `%s'" "${char}${operand}"]
				return {}
			} else {
				set operand [string range $operand 1 end]
			}
		}

		# Conevert operand value to decimal string
		set base [string tolower $base]
		switch -- $base {
			{h} {	;# From hexadecimal
				if {[NumSystem::ishex $operand]} {
					set operand [expr "0x$operand"]
					return "$char$operand"
				} else {
					SyntaxError $lineNum $fileNum [mc "Invalid value: `%s'" "${operand}${base}"]
					return {}
				}
			}
			{b} {	;# From binary
				if {[NumSystem::isbin $operand]} {
					set operand [NumSystem::bin2dec $operand]
					return "$char$operand"
				} else {
					SyntaxError $lineNum $fileNum [mc "Invalid value: `%s'" "${operand}${base}"]
					return {}
				}
			}
			{o} {	;# From octal
				if {[NumSystem::isoct $operand]} {
					set operand [NumSystem::oct2dec $operand]
					return "$char$operand"
				} else {
					SyntaxError $lineNum $fileNum [mc "Invalid value: `%s'" "${operand}${base}"]
					return {}
				}
			}
			{q} {	;# From octal
				if {[NumSystem::isoct $operand]} {
					set operand [NumSystem::oct2dec $operand]
					return "$char$operand"
				} else {
					SyntaxError $lineNum $fileNum [mc "Invalid value: `%s'" "${operand}${base}"]
					return {}
				}
			}
			{'} {	;# From character
				if {[string length $operand] != 0} {
					set operand $char[character2number [subst -nocommands -novariables $operand]]
				} else {
					SyntaxError $lineNum $fileNum [mc "Invalid value: `%s'" $operand]
					return {}
				}
			}
			{d} {	;# From decimal (no conversion)
				if {[NumSystem::isdec $operand]} {
					return "$char$operand"
				} else {
					SyntaxError $lineNum $fileNum [mc "Invalid value: `%s'" "${operand}${base}"]
					return {}
				}
			}
			default {	;# Error -- invalid base
				SyntaxError $lineNum $fileNum [mc "Invalid numeric base `%s'\n\tPossible options are: __H (hex), __D (dec) __B (bin), __Q __O (oct) and 'char'" $base]
				return {}
			}
		}
	}

	## Check for valid operand range
	 # @parm String operand	- Operand string
	 # @parm String type	- Operand type (one of {code8 code11 code16 imm8 imm16 data bit /bit})
	 # @return Bool - result (1 == valid; 0 == invalid)
	proc checkRange {operand type} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		# Both strings to lowercase
		set type	[string tolower $type]
		set operand	[string tolower $operand]

		# Fixed operand
		if {[lsearch -exact -ascii ${::CompilerConsts::FixedOperands} $operand] != -1} {
			if {$operand == $type} {
				return 1
			} else {
				return 0
			}
		}

		# Adjust operand
		set char [string index $operand 0]
		if {$char == {#} || $char == {@} || $char == {/}} {
			set operand [string trimleft $operand {#@/}]
		} else {
			set char {}
		}

		# Determinate maximum value
		switch -- $type {
			{code8}		{set max 255}
			{code11}	{set max 2047}
			{code16}	{set max 65535}

			{imm8}		{set max 255}
			{imm16}		{set max 65535}

			{data}		{set max 255}

			{bit}		{set max 255}
			{/bit}		{set max 255}
			default {
				CompilationError $lineNum $fileNum "Unknown error 1"
				return 0
			}
		}

		# Check for allowed range
		if {$operand > $max || $operand < 0} {
			return 0
		} else {
			return 1
		}
	}

	## Determinate whether the given string is an expression
	 # @parm String expression - expression
	 # @return Bool - result (1 == is an expression; 0 == is not an expression)
	proc isExpression {expression} {
		# Remove strings and quoted characters
		regsub -all {'[^']*'} $expression {} expression

		# Remove redutant white space
		set expression [string trimleft $expression "\t "]
		set expression [string trimright $expression "\t "]

		if {[regexp {[ \?\+\-\=<>\(\)\*/%]} $expression]} {
			return 1
		} else {
			return 0
		}
	}

	## Determinate whether the given string is fixed value (for instance 'A' or 'AB')
	 # @parm String operand - operand string to evaluate
	 # @return Bool - result (1 == is fixed; 0 == is not fixed)
	proc isFixed {operand} {
		set operand [string tolower $operand]
		if {[lsearch -exact -ascii ${::CompilerConsts::FixedOperands} $operand] != -1} {
			return 1
		} else {
			return 0
		}
	}

	## Determinate whether the given string is a symbolic name
	 # @parm String symbolic_name - operand string to evaluate
	 # @return Bool - result (1 == is symbolic name; 0 == is not symbolic name)
	proc isSymbolicName {symbolic_name} {
		# Adjust operand
		set char [string index $symbolic_name 0]
		if {$char == {#} || $char == {@} || $char == {/}} {
			set symbolic_name [string trimleft $symbolic_name {#@/}]
		}

		# Check if the string starts with a digit or quote
		if {[regexp {^(\d|')} $symbolic_name]} {
			return 0
		} else {
			return 1
		}
	}

	## Determinate value of the given symbolic name
	 # @parm String symbolic_name		- Symbolic name to evaluate
	 # @parm List list_of_priorities	- Substitution priorities
	 # @parm Int address			- Instruction address
	 # @parm Bool ignore_undefined		- Ignore undefined symbolic names
	 # @return Int - decimal string
	proc getValueOfSymbolicName {symbolic_name list_of_priorities address ignore_undefined} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable check_sfr_usage;# Bool: Check for legal usage of SFR and SFB
		variable available_SFR	;# List: Available SFR and SFB on the target MCU

		variable const_BIT	;# Array: Bit values -- ($const_BIT($bit_name) == $value)
		variable const_CODE	;# Array: Constants defined by directive 'CODE'
		variable const_DATA	;# Array: Constants defined by directive 'DATA'
		variable const_IDATA	;# Array: Constants defined by directive 'IDATA'
		variable const_XDATA	;# Array: Constants defined by directive 'XDATA'
		variable const_SET	;# Array: Constants defined by directive 'CODE'
		variable const_EQU	;# Array: Constants defined by directive 'EQU'

		variable defined_BIT	;# List of defined bits (directove 'BIT')
		variable defined_CODE	;# List of constants defined by 'CODE'
		variable defined_DATA	;# List of constants defined by 'DATA'
		variable defined_IDATA	;# List of constants defined by 'IDATA'
		variable defined_XDATA	;# List of constants defined by 'XDATA'
		variable defined_SET	;# List of variables defined by 'SET'
		variable defined_EQU	;# List of constants defined by 'EQU'

		variable labels		;# Array: Values of defined labels ($labels($label) == $address)
		variable defined_LABEL	;# List of defined labels

		# Convert symbolic name to tower case
		set symbolic_name [string tolower $symbolic_name]

		# Search definition list
		foreach type $list_of_priorities {
			switch -- $type {
				{labels} {
					if {
						([lsearch -exact -ascii $defined_LABEL $symbolic_name] == -1) &&
						($symbolic_name != "\$")
					} then {
						continue
					}

					if {$symbolic_name == "\$"} {
						set value $address
					} else {
						set value $labels($symbolic_name)
					}
					CodeListing::symbol_used $symbolic_name {label}
					return $value
				}
				{code} {
					if {[lsearch -exact -ascii $defined_CODE $symbolic_name] != -1} {
						CodeListing::symbol_used $symbolic_name {code}
						return $const_CODE($symbolic_name)
					}
				}
				{xdata} {
					if {[lsearch -exact -ascii $defined_XDATA $symbolic_name] != -1} {
						CodeListing::symbol_used $symbolic_name {xdata}
						return $const_XDATA($symbolic_name)
					}
				}
				{idata} {
					if {[lsearch -exact -ascii $defined_IDATA $symbolic_name] != -1} {
						CodeListing::symbol_used $symbolic_name {idata}
						return $const_IDATA($symbolic_name)
					}
				}
				{data} {
					if {[lsearch -exact -ascii $defined_DATA $symbolic_name] != -1} {
						CodeListing::symbol_used $symbolic_name {data}

						if {$check_sfr_usage} {
							if {
								[lsearch -ascii -exact $::CompilerConsts::defined_SFR $symbolic_name] != -1
									&&
								[lsearch -ascii -exact $available_SFR $symbolic_name] == -1
							} then {
								Warning $lineNum $fileNum [mc "Special function register \"%s\" is not available on the target MCU" [string toupper $symbolic_name]]
							}
						}

						return $const_DATA($symbolic_name)
					}
				}
				{bit} {
					if {[lsearch -exact -ascii $defined_BIT $symbolic_name] != -1} {
						CodeListing::symbol_used $symbolic_name {bit}

						if {$check_sfr_usage} {
							if {
								[lsearch -ascii -exact $::CompilerConsts::defined_SFRBitArea $symbolic_name] != -1
									&&
								[lsearch -ascii -exact $available_SFR $symbolic_name] == -1
							} then {
								Warning $lineNum $fileNum [mc "Special function bit \"%s\" is not available on the target MCU" [string toupper $symbolic_name]]
							}
						}

						return $const_BIT($symbolic_name)
					}
				}
				{equset} {
					if {![const_exists $symbolic_name]} {
						continue
					}

					set val [const_value $symbolic_name $lineNum]
					if {$val == {}} {
						break
					} else {
						CodeListing::symbol_used $symbolic_name {equset}
						return $val
					}
				}
				default {
					CompilationError $lineNum $fileNum "Unknown error 2"
				}
			}
		}

		# Symbolic name not found
		if {!$ignore_undefined} {
			SyntaxError $lineNum $fileNum [mc "Symbol not defined: %s" $symbolic_name]
		}
		return {}
	}

	## Perform peerhole optimization
	 # This function must be called between "parse_instructions" and "final_stage"
	 # @return void
	proc optimization {} {
		variable asm		;# Resulting pre-compiled code
		variable tmp_asm	;# Temporary auxiliary pre-compiled code
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable idx		;# Current position in asm list
		variable labels		;# Array: Values of defined labels ($labels($label) == $address)
		variable defined_LABEL	;# List of defined labels
		variable program_memory	;# String of booleans: Map of program memory usage
		variable optims		;# Number of performed optimizations
		variable origin_d_addr	;# List: Addresses of static program blocks

		# Iterate over the code
		set tmp_asm {}
		set asm_len [llength $asm]
		for {set idx 0} {$idx < $asm_len} {incr idx} {

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			# Split line into separate fields
			set i 0
			foreach var {lineNum fileNum address instr_lenght instruction operands operand_types} {
				set $var [lindex $asm [list $idx $i]]
				incr i
			}

			# Convert instruction operands to absolute values
			set operands_abs [operands_to_absolute_values	\
				$address	$instr_lenght		\
				$operands	$operand_types		\
				$instruction	1			\
			]

			# Do not try to optimalize unresolved lines
			if {$operands_abs == {} || [string first {$} $operands] != -1} {
				lappend tmp_asm [list					\
					$lineNum	 $fileNum	$address	\
					$instr_lenght	$instruction	$operands	\
					$operand_types					\
				]
				continue
			}

			# Optimalize code on this line
			set bytes_saved 0
			switch -- $instruction {
				{setb} {	;# SETB 215 --> SETB C
					if {[lindex $operands_abs 0] == {215}} {
						lset operands 0 C
						lset operand_types 0 c
						set bytes_saved 1
					}
				}
				{clr} {		;# CLR 215 --> CLR C
					if {[lindex $operands_abs 0] == {215}} {
						lset operands 0 C
						lset operand_types 0 c
						set bytes_saved 1
					}
				}
				{jmp} {		;# A) JMP code11 --> AJMP code11
						;# B) JMP code8  --> SJMP code8
					## A)
					if {[string is digit -strict [lindex $operands_abs 0]]} {
						set diff [expr {$address - [lindex $operands_abs 0]}]
					} else {
						set diff 200	;# Some value out of range [-126; 129]
					}

					if {[lindex $operand_types 0] != {code8} && $diff >= -126 && $diff <= 129} {
						set instruction {sjmp}
						set operand_types {code8}
						set bytes_saved 1

					## B)
					} elseif {
						[lindex $operand_types 0] != {code8} &&
						[lindex $operand_types 0] != {code11} &&
						($address & 0x0f800) == ([lindex $operands_abs 0] & 0x0f800)
					} then {
						set instruction {ajmp}
						set operand_types {code11}
						set bytes_saved 1
					}
				}
				{ljmp} {	;# A) LJMP code11 --> AJMP code11
						;# B) LJMP code8  --> SJMP code8
					## A)
					if {[string is digit -strict [lindex $operands_abs 0]]} {
						set diff [expr {$address - [lindex $operands_abs 0]}]
					} else {
						set diff 200	;# Some value out of range [-126; 129]
					}
					if {$diff >= -126 && $diff <= 129} {
						set instruction {sjmp}
						set operand_types {code8}
						set bytes_saved 1

					## B)
					} elseif {[lindex $operands_abs 0] < 2048} {
						set instruction {ajmp}
						set operand_types {code11}
						set bytes_saved 1
					}
				}
				{ajmp} {	;# AJMP code8  --> SJMP code8
					if {[string is digit -strict [lindex $operands_abs 0]]} {
						set diff [expr {$address - [lindex $operands_abs 0]}]
					} else {
						set diff 200	;# Some value out of range [-126; 129]
					}
					if {$diff >= -126 && $diff <= 129} {
						set instruction {sjmp}
						set operand_types {code8}
					}
				}
				{call} {	;# CALL code11 --> ACALL code11
					if {
						[lindex $operand_types 0] != {code11}
							&&
						($address & 0x0f800) == ([lindex $operands_abs 0] & 0x0f800)
					} then {
						set instruction {acall}
						set operand_types {code11}
						set bytes_saved 1
					}
				}
				{lcall} {	;# LCALL code11 --> ACALL code11
					if {[lindex $operands_abs 0] < 2048} {
						set instruction {acall}
						set operand_types {code11}
						set bytes_saved 1
					}
				}
				{mov} {		;# A) MOV 224, ... --> MOV A, ...
						;# B) MOV ..., 224 --> MOV ..., A
					## A)
					if {
						[lindex $operands_abs 0] == 224
							&&
						[lindex $operand_types 0] == {data}
					} then {
						if {[lindex $operands_abs 1] != {A}} {
							lset operands 0 A
							lset operand_types 0 a
							set bytes_saved 1
						}
					## B)
					} elseif {
						[lindex $operands_abs 1] == 224
							&&
						[lindex $operand_types 1] == {data}
					} then {
						lset operands 1 A
						lset operand_types 1 a
						set bytes_saved 1
					}
				}
			}

			if {$bytes_saved} {
				# Increment number of performed optimizations
				incr optims

				# Shift code
				set max_addr $address
				set last_len $instr_lenght
				for {set i [expr {$idx + 1}]} {$i < $asm_len} {incr i} {
					set addr [lindex $asm [list $i 2]]
					if {$addr != ($max_addr + $last_len) || [lsearch $origin_d_addr $addr] != -1} {
						break
					}
					set max_addr $addr
					set last_len [lindex $asm [list $i 3]]
					lset asm [list $i 2] [expr {$addr - $bytes_saved}]
				}

				# Shift labels
				foreach lbl $defined_LABEL {
					if {$labels($lbl) > $address && $labels($lbl) <= $max_addr} {
						incr labels($lbl) -$bytes_saved
					}
				}

				# Adjust instruction length
				incr instr_lenght -$bytes_saved
			}

			lappend tmp_asm [list					\
				$lineNum	 $fileNum	$address	\
				$instr_lenght	$instruction	$operands	\
				$operand_types					\
			]
		}

		set asm $tmp_asm
	}

	## Evaluate and remove instructions
	 # @return void
	proc parse_instructions {} {
		variable asm		;# Resulting pre-compiled code
		variable tmp_asm	;# Temporary auxiliary pre-compiled code
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable idx		;# Current position in asm list
		variable labels		;# Array: Values of defined labels ($labels($label) == $address)
		variable defined_LABEL	;# List of defined labels
		variable program_memory	;# String of booleans: Map of program memory usage

		variable const_SET_SPEC		;# Array: Special constants defined by directive 'CODE'
		variable const_EQU_SPEC		;# Array: Special constants defined by directive 'EQU'
		variable defined_SET_SPEC	;# List of special variables defined by 'SET'
		variable defined_EQU_SPEC	;# List of special constants defined by 'EQU'

		# Reset NS variables
		set lineNum		{}
		set instruction_len	{}
		set instruction		{}
		set operands		{}
		set operand_types	{}
		set local_labels	{}
		set tmp_asm		{}
		set program_memory	[string repeat 0 65536]
		set program_pointer	0
		set new_program_pointer	0
		set idx			-1

		# Iterate over the code
		foreach line $asm {
			incr idx

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			# Determinate line number and line content
			set lineNum	[lindex $line 0]
			set fileNum	[lindex $line 1]
			set line	[lindex $line 2]

			## Conditionaly change program pointer
			if {![regexp {^\s*\w+} $line first_field]} {
				set first_field {}
			} else {
				set first_field [string trim $first_field]
			}
			if {$first_field == {ORG}} {
				CodeListing::delete_line $idx
				incr idx -1
				set program_pointer [lindex $line 1]
				continue
			}

			## Determinate label
			if {[regexp {^\w+:} $line label]} {
				# Check for label validity
				set lbl [string trimright $label {:}]
				if {[regexp {^\w*:$} $label] && ![regexp {^\d} $label]} {
					if {
						[lsearch -exact -ascii ${::CompilerConsts::defined_SFR} $lbl] != -1
							||
						[lsearch -exact -ascii ${::CompilerConsts::defined_progVectors} $lbl] != -1
							||
						[lsearch -exact -ascii ${::CompilerConsts::defined_SFRBitArea} $lbl] != -1
							||
						[lsearch -exact -ascii ${::CompilerConsts::FixedOperands} $lbl] != -1
					} then {
						SyntaxError $lineNum $fileNum [mc "Unable redefine constant: %s" $lbl]
					} else {
						set label $lbl
						if {[isReservedKeyword $label]} {
							Warning $lineNum $fileNum [mc "Reserved keyword used as label"]
						}
						lappend local_labels $label
					}
				} else {
					SyntaxError $lineNum $fileNum [mc "Invalid label: `%s' \n\t(labels can contain only alphanumeric characters and must not begin with a digit)" $label]
				}

				# Remove label from the line
				regsub {^\w+:\s*} $line {} line
			}

			# If the line contains only label then exit
			if {$line == {}} {
				CodeListing::delete_line $idx
				incr idx -1
				continue
			}

			## Determinate instruction
			if {![regexp {^\s*\.?\w+} $line instruction]} {
				set instruction {}
			} else {
				set instruction [string tolower [string trim $instruction]]
			}

			# Directive 'SKIP'
			if {$instruction == {skip} || $instruction == {.skip}} {
				set skip [ComputeExpr [regsub {^\s*\.?\w+\s*} $line {}]]
				if {$skip == {}} {
					set instruction_len 0
					SyntaxError $lineNum $fileNum [mc "Invalid expression `%s'" [regsub {^\s*\.?\w+\s*} $line {}]]
				} else {
					set instruction_len $skip
				}

				set instruction {}	;# <-- That means delete this line

			# Directive 'DB'
			} elseif {$instruction == {db}} {
				set instruction_len 1
				set operand_types {}
				set operands [regsub {^\w+\s*} $line {}]

			# Regular instruction
			} else {
				# Check for instruction validity
				if {[lsearch -exact -ascii ${::CompilerConsts::AllInstructions} $instruction] == -1} {
					lappend tmp_asm [list $lineNum $fileNum {C} $line]
					continue
				}
				# Remove instruction from the line
				regsub {^\w+\s*} $line {} line

				# Determinate operands
				set operands [getOperands $line 1]

				# Determinate operand types and instruction length
				set instr_info [getInstructionInfo $instruction $operands $program_pointer]
				if {$instr_info == {}} {continue}
				set instruction_len	[lindex $instr_info 0]
				set operand_types	[lindex $instr_info 1]
				set operands		[lindex $instr_info 2]
			}

			# Define found labels
			define_labels $local_labels $program_pointer

			# Determinate expected program position
			set new_program_pointer $program_pointer
			incr new_program_pointer $instruction_len

			# Check for program pointer validity
			for {set i $program_pointer} {$i <= $new_program_pointer} {incr i} {
				if {[string index $program_memory $i] != 0} {
					CompilationError $lineNum $fileNum [mc "Unable to overwrite already reserved program memory at address 0x%s -- compilation failed" [format %X $i]]
				}
			}
			if {$program_pointer >= ${::Compiler::Settings::code_size}} {
				Warning $lineNum $fileNum [mc "This instruction exceeding code memory capacity"]
			}

			# Adjust map of code memory usage
			set program_memory [string replace $program_memory		\
				$program_pointer [expr {$new_program_pointer - 1}]	\
				[string repeat 1 $instruction_len]			\
			]

			# Create new code line
			if {$instruction != {}} {
				lappend tmp_asm [list					\
					$lineNum		$fileNum		\
					$program_pointer	$instruction_len	\
					$instruction		$operands		\
					$operand_types					\
				]
			}

			# Adjust code listing and program pointer
			CodeListing::set_addr $idx $program_pointer
			set program_pointer $new_program_pointer

			# Reset
			set lineNum		{}
			set fileNum		{}
			set instruction_len	{}
			set instruction		{}
			set operands		{}
			set operand_types	{}
			set local_labels	{}
		}

		# Chech if reset address engaged
		if {![string index $program_memory 0]} {
			Warning $lineNum $fileNum [mc "No instruction found at address 0x00. Consider usage of appropriate ORG directive to clarify correct code placement."]
		}

		# Finalize
		define_labels $local_labels $program_pointer
		set asm $tmp_asm
	}

	## Determinate whether the given string is reserved keyword
	 # @parm String string		- String to evaluate
	 # @parm Bool symbols_too	- Consider also special register names
	 # @return Bool - result (1 == is reserved; 0 == is not reserved)
	proc isReservedKeyword {string {symbols_too 0}} {

		set string [string tolower $string]

		if {
			[lsearch -exact -ascii ${::CompilerConsts::AllInstructions} $string] != -1
				||
			[lsearch -exact -ascii ${::CompilerConsts::AllDirectives} $string] != -1
				||
			[lsearch -exact -ascii ${::CompilerConsts::FixedOperands} $string] != -1
		} then {
			return 1
		} elseif {$symbols_too && (
				[lsearch -exact -ascii ${::CompilerConsts::defined_SFR} $string] != -1
					||
				[lsearch -exact -ascii ${::CompilerConsts::defined_progVectors} $string] != -1
					||
				[lsearch -exact -ascii ${::CompilerConsts::defined_SFRBitArea} $string] != -1
			)
		} then {
			return 1
		} else {
			return 0
		}
	}

	## Assign the given address to the given labels
	 # @parm List list_of_labels	- Labels to define
	 # @parm Int address		- address to assign
	 # @return void
	proc define_labels {list_of_labels address} {
		variable defined_LABEL	;# List of defined labels
		variable labels		;# Array: Values of defined labels ($labels($label) == $address)
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		# Return if the given list is empty
		if {![llength $list_of_labels]} {return}

		# Define the given labels
		set list_of_labels [string tolower $list_of_labels]
		foreach label $list_of_labels {
			if {[lsearch -exact -ascii $defined_LABEL $label] != -1} {
				SyntaxError $lineNum $fileNum [mc "Label was already defined: `%s'" $label]
			} else {
				lappend defined_LABEL $label
				set labels($label) $address
			}
		}
	}

	## Determinate instruction length and list of operand types
	 # @parm String instruction	- instruction name
	 # @parm List operands		- instruction operands
	 # @parm Inr address		- instruction address
	 # @return List - {instruction_length list_of_operand_types operands}
	proc getInstructionInfo {instruction operands address} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		variable const_SET_SPEC		;# Array: Special constants defined by directive 'CODE'
		variable const_EQU_SPEC		;# Array: Special constants defined by directive 'EQU'
		variable defined_SET_SPEC	;# List of special variables defined by 'SET'
		variable defined_EQU_SPEC	;# List of special constants defined by 'EQU'

		# Convert fixed operands to uppercase
		set l [llength $operands]
		for {set i 0} {$i < $l} {incr i} {
			set o [lindex $operands $i]
			if {[lsearch -exact -ascii ${::CompilerConsts::FixedOperands} [string tolower $o]] != -1} {
				set operands [lreplace $operands $i $i [string toupper $o]]
			}
		}

		# Initialize variables containing result
		set operand_types	{}
		set instr_len		0

		# Expand special constants
		set l [llength $operands]
		for {set i 0} {$i < $l} {incr i} {
			set o [string tolower [lindex $operands $i]]
			if {
				[lsearch -ascii -exact $defined_EQU_SPEC $o] != -1
					||
				[lsearch -ascii -exact $defined_SET_SPEC $o] != -1
			} then {
				set n [const_value $o $lineNum 1]
				set operands [lreplace $operands $i $i $n]

				Notice $lineNum $fileNum [mc "Overwriting `%s' with `%s' (according to your previous definition!)" [string toupper $o] [string toupper $n]]
			}
		}

		# Determinate basic operand types
		set operand_types {}
		foreach opr $operands {
			lappend operand_types [operandType $opr $instruction $address]
		}

		# Find instruction set for given instruction
		if {[lsearch -exact -ascii ${::CompilerConsts::AllInstructions} $instruction] == -1} {
			CompilationError $lineNum $fileNum "Unknown error 3"
			return {}
		}
		set ins_def $::CompilerConsts::InstructionDefinition($instruction)

		# Check for valid operands count
		set max_oprs [lindex $ins_def 0]
		if {[llength $operands] > $max_oprs} {
			SyntaxError $lineNum $fileNum [mc "Too many operands, %s can take only %s operand[expr {$max_oprs == 1 ? {} : {s}}]" $instruction $max_oprs]
			return {}
		} elseif {[llength $operands] < $max_oprs} {
			SyntaxError $lineNum $fileNum [mc "Too few operands, %s must take exactly %s operand[expr {$max_oprs == 1 ? {} : {s}}]" $instruction $max_oprs]
			return {}
		}

		# Find matching operand set
		set operand_types	[string tolower $operand_types]
		set operands_org	$operands
		set operands_changed	$operands
		set operand_types_org	$operand_types
		set match		1
		for {set i 0} {$i < 3} {incr i} {
			foreach opr_set_def [lindex $ins_def 1] {

				set opr_list [lindex $opr_set_def 0]

				set match 1
				foreach given_type $operand_types possible_type $opr_list {
					if {[lsearch -exact -ascii $given_type $possible_type] == -1} {
						set match 0
						break
					}
				}
				if {$match} {
					set operand_types $opr_list
					set instr_len [lindex $opr_set_def 1]
					break
				}
			}
			if {$match} {
				if {$i} {
					Notice $lineNum $fileNum [mc "`%s' changed by compiler to `%s'" "$instruction [join $operands_org {, }]" "$instruction [join $operands_changed {, }]"]
				}
				break
			}

			# Try to change operand set without changing meaning
			set operands_i {}
			while {$i < 2} {
				set operands_i [lindex $operands $i]
				if {
					$operands_i != {A}
						&&
					$operands_i != {C}
						&&
					$operands_i != {/C}
				} then {
					incr i
					continue
				}

				set operands		$operands_org
				set operands_changed	$operands
				set operand_types	$operand_types_org

				if {$operands_i == {A}} {
					lset operands $i {224}
					lset operands_changed $i {ACC}
					lset operand_types $i {data}

				} elseif {$operands_i == {C}} {
					lset operands $i {215}
					lset operands_changed $i {CY}
					lset operand_types $i {bit}

				} elseif {$operands_i == {/C}} {
					lset operands $i {/215}
					lset operands_changed $i {/CY}
					lset operand_types $i {/bit}

				}
				break
			}
		}

		# No matching operand set found -> error
		if {!$match} {
			SyntaxError $lineNum $fileNum [mc "Invalid set of operands: %s %s" $instruction [join $operands {,}]]
			return {}
		}

		# Return result
		return [list $instr_len $operand_types $operands]
	}

	## Determinate type of the given operand
	 # @parm String instruction	- instruction name
	 # @parm String operand		- operand to evaluate
	 # @parm Int address		- instruction address
	 # @return List - list of possible types
	proc operandType {operand instruction address} {
		variable labels		;# Array: Values of defined labels ($labels($label) == $address)
		variable const_DATA	;# Array: Constants defined by directive 'DATA'
		variable const_IDATA	;# Array: Constants defined by directive 'IDATA'
		variable const_XDATA	;# Array: Constants defined by directive 'XDATA'
		variable defined_LABEL	;# List of defined labels
		variable defined_BIT	;# List of defined bits (directove 'BIT')
		variable defined_DATA	;# List of constants defined by 'DATA'
		variable defined_IDATA	;# List of constants defined by 'IDATA'
		variable defined_XDATA	;# List of constants defined by 'XDATA'
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		# To lowercase
		set operand [string tolower $operand]

		# Fixed value
		if {[lsearch -exact -ascii ${::CompilerConsts::FixedOperands} $operand] != -1} {
			return [string toupper $operand]
		}

		# Immediate or bit address
		switch -regexp -- $operand {
			{^/.*$}	{ return {/bit}		}
			{^#.*$}	{ return {imm8 imm16}	}
		}

		# determinate whether the instruction can changed content of PC
		if {[lsearch {} $instruction] == -1} {
			set no_branch 1
		} else {
			set no_branch 0
		}

		# Variable length operand (pseudo-instructions: "CALL <code>" and "JMP <code>")
		if {$instruction == {jmp} || $instruction == {call}} {
			# Value is an expression
			if {[isExpression $operand]} {
				set operand [ComputeExpr $operand 1 $address]
			# Value is regular symbolic name
			} elseif {[isSymbolicName $operand]} {
				set operand [getValueOfSymbolicName	\
					$operand {labels code equset} 	\
					$address 1			\
				]
			# Direct value (some number)
			} else {
				set operand [COprToDec $operand]
				Warning $lineNum $fileNum [mc "Direct value used as operand for %s" $instruction]
			}

			# Determinate appropriate operand type
			if {$operand == {}} {
				return {code16}
			} elseif {$operand >= 0x800} {
				return {code16}
			} elseif {(abs($address - $operand) > 126) || $instruction == {call}} {
				return {code11}
			} else {
				return {code8}
			}

		# Register in SFR area
		} elseif {[lsearch ${::CompilerConsts::defined_SFR} $operand] != -1} {
			return {data}

		# Bit in SFB area
		} elseif {[lsearch ${::CompilerConsts::defined_SFRBitArea} $operand] != -1} {
			return {bit /bit}

		# Address in program memory
		} elseif {[lsearch ${::CompilerConsts::defined_progVectors} $operand] != -1} {
			return {code16 code11 code8}

		# Another type
		} else {
			return {data code16 code11 code8 bit /bit}
		}
	}

	## Expand macro instructions
	 # @return Bool - macro expanded
	proc expand_macro_instructions {} {
		variable asm		;# Resulting pre-compiled code
		variable tmp_asm	;# Temporary auxiliary pre-compiled code
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable macro		;# Array: Code of defined macro instructions
		variable local_M_labels		;# Array of lists: Local labels in macros $local_M_labels($macro_name) == {integer label0 ... labelN}
		variable defined_MACRO	;# List of defined macro instructions
		variable idx		;# Current position in asm list

		# Skip procedure if there are no defined macro instructions
		if {![llength $defined_MACRO]} {
			return 0
		}

		set label	{}
		set operands	{}
		set instruction	{}
		set macro_code	{}
		set tmp_asm	{}
		set idx		-1
		set del_line	0

		set repeat	0	;# Bool: Macro expanded

		# Iterate over the code
		foreach line $asm {
			incr idx

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			# Determinate line number and line content
			set lineNum	[lindex $line 0]
			set fileNum	[lindex $line 1]
			set line	[lindex $line 2]
			# Make line backup
			set original_line $line

			# Determinate label, instruction and operands
			set label {}
			if {[regexp {^\w+:} $line label]} {
				regsub {^\w+:\s*} $line {} line
			}
			if {![regexp {^\s*\.?\w+} $line instruction]} {
				set instruction {}
			} else {
				set instruction [string tolower [string trim $instruction]]
			}
			regsub {^\.?\w+\s*} $line {} operands

			# Check if the instruction is macro
			if {[lsearch -exact -ascii $defined_MACRO $instruction] == -1} {
				lappend tmp_asm [list $lineNum $fileNum $original_line]
				continue
			}

			set repeat 1

			# Get code of the macro
			set macro_code [getMacro $instruction [getOperands $operands 1]]
			if {$macro_code == {}} {continue}

			# Adjust the precompiled code and code listing
			if {$label != {}} {
				lappend tmp_asm [list $lineNum $fileNum $label]
				set del_line 0
			} else {
				set del_line 1
			}

			CodeListing::macro $idx $macro_code
			if {$del_line} {
				CodeListing::delete_line $idx
				incr idx -1
			}

			foreach line $macro_code {
				lappend tmp_asm [list $lineNum $fileNum $line]
				incr idx
			}
		}

		# Replace old code with the new one and return result
		set asm $tmp_asm
		return $repeat
	}

	## Debugging procedure
	 # Write current content of the precompiled code to stdout
	 # @return void
	proc write_asm {} {
		variable asm	;# Resulting pre-compiled code
		puts ""
		set idx -1
		foreach line $asm {
			incr idx
			puts "$idx:\t$line"
		}
	}

	## Debugging procedure
	 # Write current content of the tempotary precompiled code to stdout
	 # @return void
	proc write_tmp_asm {} {
		variable tmp_asm	;# Temporary auxiliary pre-compiled code
		puts ""
		set idx -1
		foreach line $tmp_asm {
			incr idx
			puts "$idx:\t$line"
		}
	}

	## Get adjusted code of the given macro instruction
	 # @parm String macro_name	- Macro name
	 # @parm List args		- Expansion arguments (wrapped in '{}')
	 # @return List - code of the macro
	proc getMacro {macro_name args} {
		variable macro		;# Array: Code of defined macro instructions
		variable local_M_labels	;# Array of lists: Local labels in macros $local_M_labels($macro_name) == {integer label0 ... labelN}
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		# Adjust list of arguments
		set args [lindex $args 0]

		# Local variables
		set new_operands	{}	;# Instruction operands
		set result		{}	;# Resulting list

		# Determinate code of the macro and its operands
		set macro_code $macro($macro_name)
		set m_pars [lindex $macro_code 0]
		set macro_code [lindex $macro_code 1]

		# Check for valid number of arguments
		set arg_len_diff [expr {[llength $args] - [llength $m_pars]}]
		if {$arg_len_diff < 0} {
			set arg_len_diff [expr {$arg_len_diff * -1}]
			SyntaxError $lineNum $fileNum [mc "Too few arguments, %d argument(s) missing for %s ..." $arg_len_diff $macro_name]
			return {}
		} elseif {$arg_len_diff > 0} {
			SyntaxError $lineNum $fileNum [mc "Too many arguments, %d extra argument(s)" $arg_len_diff]
			return {}
		}

		# Increment counter of expansions of this macro
		lset local_M_labels($macro_name) 0 [expr {1 + [lindex $local_M_labels($macro_name) 0]}]

		# Substitute macro parametrs
		foreach line $macro_code {
			set new_operands {}

			# Determinate label
			if {![regexp {^(\?\?)?[A-Za-z_][^\s:]*:\s*} $line label]} {
				set label {}
			} else {
				regsub {^(\?\?)?[A-Za-z_][^\s:]*:\s*} $line {} line
				regsub -all {\s+} $label {} label
				set label [string trimright $label {:}]
				if {[lsearch -ascii -exact [lrange $local_M_labels($macro_name) 1 end] $label] != -1} {
					set label "${macro_name}_[lindex $local_M_labels($macro_name) 0]__${label}"
				}
			}

			# Determinate instruction and operands
			if {![regexp {^\.?\w+\s*} $line instruction]} {
				set instruction {}
			} else {
				regsub -all {\s+} $instruction {} instruction
			}
			regsub {^\.?\w+\s*} $line {} operands
			if {$operands == {}} {
				if {$label != {}} {
					lappend result "${label}:\t${instruction}"
				} else {
					lappend result $instruction
				}
				continue
			}

			if {[lsearch -ascii -exact {if ifn ifdef ifndef elseif elseifn elseifdef elseifndef} [string tolower $instruction]] == -1} {
				set operands [getOperands $operands 0]
				set if_statement 0
			} else {
				set if_statement 1
			}

			# Perform substitution
			foreach opr $operands {

				# Adjust operand
				set char [string index $opr 0]
				if {
					($char == {/})	||
					($char == {#})	||
					($char == {@})
				} then {
					set opr [string range $opr 1 end]
				} else {
					set char {}
				}

				# Find operand in macro parameters
				set new_opr [list]
				regsub -all {[\(\)]} $opr { & } opr
				foreach o $opr {
					set idx [lsearch -exact -ascii $m_pars $o]
					if {$idx != -1} {
						set o [lindex $args $idx]

						if {[isReservedKeyword [lindex $m_pars $idx] 1]} {
							Warning $lineNum $fileNum [mc "Reserved keyword substituted with macro argument: %s --> %s" [lindex $m_pars $idx] [lindex $args $idx]]
						}
					} elseif {[lsearch -exact -ascii [lrange $local_M_labels($macro_name) 1 end] $o] != -1} {
						set o "${macro_name}_[lindex $local_M_labels($macro_name) 0]__${o}"
					}

					append new_opr $o { }
				}

				lappend new_operands "$char$new_opr"
			}

			# Recomposite line of macro instruction code
			if {$if_statement} {
				set operands [join $new_operands { }]
			} else {
				set operands [join $new_operands {, }]
			}
			append instruction "\t"
			append instruction $operands

			if {$label != {}} {
				set instruction "${label}:\t${instruction}"
			}
			lappend result $instruction
		}

		# Return resulting list
		return $result
	}

	## Determinate list of operands
	 # @parm String operands	- Operands (eg. 'A, #55d,main')
	 # @parm Bool keep_case		- Keep letters case
	 # @return List - list of operands (eg. {A #55d main})
	proc getOperands {operands keep_case} {
		if {$operands == {}} {return {}}

		# Local variables
		set simple_operands	$operands	;# Original string without strings and chars
		set result		{}		;# Resulting list

		# Convert strings and quoted characters to underscores
		while {1} {
			if {![regexp {'[^']*'} $simple_operands str]} {break}

			set padding [string repeat {_} [string length $str]]
			regsub {'[^']*'} $simple_operands $padding simple_operands
		}

		# Determinate operands
		while {1} {
			set idx [string first {,} $simple_operands]
			if {$idx == -1} {break}

			incr idx -1
			set operand [string range $operands 0 $idx]
			set operand [string trimleft $operand { }]
			set operand [string trimright $operand { }]
			lappend result $operand
			incr idx 2

			set operands [string range $operands $idx end]
			set simple_operands [string range $simple_operands $idx end]
		}
		set operands [string trim $operands]

		lappend result $operands
		if {$keep_case} {
			return $result
		} else {
			return [string tolower $result]
		}
	}

	## Parse and remove definitions of macro instructions
	 # @return void
	proc define_macro_instructions {} {
		variable asm			;# Resulting pre-compiled code
		variable tmp_asm		;# Temporary auxiliary pre-compiled code
		variable lineNum		;# Number of the current line
		variable fileNum		;# Number of the current file
		variable macro			;# Array: Code of defined macro instructions
		variable local_M_labels		;# Array of lists: Local labels in macros $local_M_labels($macro_name) == {integer label0 ... labelN}
		variable defined_MACRO		;# List of defined macro instructions
		variable idx			;# Current position in asm list
		variable macro_name_to_append	;# Name of currently defined macro instruction

		# Reset NS variables
		set tmp_asm	{}
		set idx		-1

		# Local variables
		set Macro		0	;# Bool: definition opened
		set NoMacro		0	;# Definition failed
		set del_line		1	;# Bool: remove this line
		set macro_name		{}	;# Name of the macro
		set macro_params	{}	;# List of the macro parameters
		set rept_macro		0	;# Bool: repeat macro starts

		# Iterate over the code
		foreach line $asm {
			incr idx

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			set del_line 1	;# Flag "remove this line"

			# Determinate line number and line content
			set lineNum	[lindex $line 0]
			set fileNum	[lindex $line 1]
			set line	[lindex $line 2]

			# Spilt line into first 2 separate fields
			if {![regexp {^\s*\.?\w+} $line field0]} {
				set field0 {}
			} else {
				set field0 [string trim $field0]
			}
			if {![regexp {^\s*\.?\w+:?\s+\.?\w+} $line field1]} {
				set field1 {}
			} else {
				regexp {\.?\w+$} $field1 field1
			}
			set field0_l [regsub {^\.} [string tolower $field0] {}]
			set field1_l [regsub {^\.} [string tolower $field1] {}]

			# Repeat macro
			if {$field0_l == {rept} || $field0_l == {times}} {
				if {$Macro} {
					SyntaxError $lineNum $fileNum	\
						[mc "Cannot define macro inside another one -- macro processing failed"]
				} else {
					regsub {^\s*\.?\w+\s*} $line {} macro_params
					set macro_params [ComputeExpr $macro_params]
					if {$macro_params == {}} {
						SyntaxError $lineNum $fileNum [mc "Missing number of repeats"]
						set NoMacro 1
					} elseif {$macro_params < 0} {
						Warning $lineNum $fileNum [mc "Number of repeats is lower than zero"]
						set NoMacro 1
					} elseif {$macro_params == 0} {
						Notice $lineNum $fileNum [mc "Zero number of repeats"]
						set NoMacro 1
					}
					set macro_name ${idx}

					set macro_name_to_append $macro_name
					set macro($macro_name) {}
					set Macro 1
					set rept_macro 1
				}

			# Open macro definition
			} elseif {$field1_l == {macro}} {
				if {$Macro} {
					SyntaxError $lineNum $fileNum	\
						[mc "Cannot define macro inside another one -- macro processing failed"]
				} else {
					# Determinate name and parameters
					regsub {^\w+\s+\.?\w+\s*} $line {} macro_params
					set macro_params [getOperands $macro_params 0]
					set macro_name $field0_l

					foreach parm $macro_params {
						if {[isReservedKeyword $parm 1]} {
							Warning $lineNum $fileNum [mc "Reserved keyword used as macro parameter: %s in macro %s" $parm $macro_name]
						}
					}

					# Check for validity of the name
					if {[isReservedKeyword $macro_name]} {
						# Invalid name
						SyntaxError $lineNum $fileNum [mc "Macro name is reserved keyword: %s" $macro_name]
						set NoMacro 1
					} else {
						# Check for validity of the name (again, but invoke only warning this time)
						if {[isReservedKeyword $macro_name 1]} {
							# Invalid name
							Warning $lineNum $fileNum [mc "Macro name is reserved keyword: %s" $macro_name]
							set NoMacro 1
						}
						# Valid name
						if {[lsearch -exact -ascii $defined_MACRO $macro_name] != -1} {
							SyntaxError $lineNum $fileNum [mc "Macro `%s' is already defined" $macro_name]
							set NoMacro 1
						} else {
							set macro_name_to_append $macro_name
							set macro($macro_name) [list]
							set local_M_labels($macro_name) [list 0]
						}
						set Macro 1
					}
				}

			# Close macro definition
			} elseif {$field0_l == {endm}} {
				# No macro was opened
				if {!$Macro} {
					SyntaxError $lineNum $fileNum [mc "Unable to close macro, no macro is opened"]
				# Close macro
				} else {
					if {$rept_macro} {
						set line $macro($macro_name)
						set macro($macro_name) [list]
						set local_M_labels($macro_name) [list 0]
						for {set i 0} {$i < $macro_params} {incr i} {
							set macro($macro_name) [concat $macro($macro_name) $line]
						}

						set macro_params {}
						set del_line 0
						lappend tmp_asm [list $lineNum $fileNum $macro_name]
					}

					if {!$NoMacro} {
						set macro($macro_name) [list $macro_params $macro($macro_name)]
						regsub -all {\s+} $macro($macro_name) { } macro($macro_name)
						regsub -all "\\\{ " $macro($macro_name) "\{" macro($macro_name)

						lappend defined_MACRO $macro_name_to_append
					}
				}

				# Reset some local variables
				set Macro 0
				set NoMacro 0
				set rept_macro 0

				# Directive takes no arguments
				if {[string length $field1_l]} {
					Warning $lineNum $fileNum [mc "Directive %s takes no arguments" [string toupper $field0_l]]
				}

			# Regular line
			} else {
				# Part of macro definition
				if {$Macro} {
					# Register local label in the macro
					if {$field0_l == {local}} {
						if {[regexp {^\w+$} $field1_l]} {
							lappend local_M_labels($macro_name) $field1_l
						} else {
							SyntaxError $lineNum $fileNum [mc "Invalid label specification: ``%s''" $field0_l]
						}
					# Append the line to the currenly opened macro
					} else {
						if {!$NoMacro} {
							lappend macro($macro_name) $line
						}
					}
				# Common line
				} else {
					if {$field0_l == {macro}} {
						SyntaxError $lineNum $fileNum [mc "Missing name of macro"]
					} elseif {[regexp {^\s*\w+:} $line] && ($field1_l == {endm})} {
						SyntaxError $lineNum $fileNum [mc "Labels are not allowed before directives ENDM"]
					} else {
						lappend tmp_asm [list $lineNum $fileNum $line]
					}
					set del_line 0
				}
			}

			# Remove the current line
			if {$del_line} {
				CodeListing::delete_line $idx
				incr idx -1
			}
		}

		# Replace old code with the new one
		set asm $tmp_asm
	}

	## Evaluate and remove inclusion directives
	 # @parm String dir - path to the current working directory
	 # @return Bool - code included
	proc include_directive {dir} {
		variable included_files	;# List: Unique unsorted list of included files
		variable asm		;# Resulting pre-compiled code
		variable tmp_asm	;# Temporary auxiliary pre-compiled code
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable idx		;# Current position in asm list

		# Reset NS variables
		set tmp_asm	{}

		# Local variables
		set repeat 0	;# Flag "code included"

		# Iterate over the code
		set asm_len [llength $asm]
		for {set idx 0} {$idx < $asm_len} {incr idx} {
			set line [lindex $asm $idx]
			set line_org $line

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			set file	{}			;# File to include
			set lineNum	[lindex $line 0]	;# Number of the current line
			set fileNum	[lindex $line 1]	;# Number of the current file
			set line	[lindex $line 2]	;# Code of the current line

			# Remove comment
			regsub {\s*;.*$} $line {} line

			# Determinate label
			if {[regexp {^\s*\w+:} $line label]} {
				regsub {^\s*\w+:\s*} $line {} line
				set label [string trimleft $label " \t"]
				set label [string trimright $label " \t"]
			} else {
				set label {}
			}

			# Determinate directive
			if {![regexp {^\s*\.?\w+} $line directive]} {
				set directive {}
			} else {
				set directive [string trim $directive]
			}
			set directive_l [string tolower $directive]

			# Directive 'INCLUDE file'
			if {[regsub {^\.} $directive_l {}] == {include}} {
				regsub {^\s*\.?\w+} $line {} file_name
				regsub {^\s+} $file_name {} file_name
				if {![string length $file_name]} {
					SyntaxError $lineNum $fileNum [mc "Missing file name"]
				}
				set asm [lreplace $asm $idx $idx [list $lineNum $fileNum $label]]

			# Control sequence '$INCLUDE(file)'
			} elseif {[regexp -nocase -- {^[\s ]*\$inc(lude)?[\s ]*\([^\(\)]*\)} $line file_name]} {
				set file_name [regsub -nocase -- {^[\s ]*\$include[\s ]*} $file_name {}]
				set file_name [string range $file_name 1 end-1]
				if {![string length $file_name]} {
					SyntaxError $lineNum $fileNum [mc "Missing file name"]
				}
				set asm [lreplace $asm $idx $idx [list $lineNum $fileNum $label]]

			# Nothing interesting
			} else {
				set file_name {}
			}

			# Read file if any
			if {$file_name != {}} {
				# Determinate final file name
				set file_name [regsub -all "\\\\\"" [string trim $file_name] "\""]
				if {
					([string index $file_name 0] == "\"" && [string index $file_name end] == "\"")
						||
					([string index $file_name 0] == {'} && [string index $file_name end] == {'})
				} then {
					set file_name [string range $file_name 1 end-1]
				}
				set file_name [string trim $file_name]
				set file_name [file normalize [file join $dir $file_name]]

				# Determinate file number
				set file_number [lsearch -ascii -exact $included_files $file_name]
				if {$file_number == -1} {
					set file_number [llength $included_files]
					lappend included_files $file_name
				}

				# Read file and adjust $asm
				set file [getFile $dir $file_name $file_number]
			}

			# File is not empty
			if {[string length $file]} {
				set repeat 1

				CodeListing::include $idx [concat [list $line_org] $file]
				set idx_plus_1 [expr {$idx + 1}]
				if {$idx_plus_1 >= $asm_len} {
					lappend CodeListing::sync_map {}
					lappend asm [list $lineNum $fileNum {}]
				}
				set tmp_asm [lrange $asm $idx_plus_1 end]
				set asm [lreplace $asm $idx_plus_1 end]
				append asm { }
				append asm $file
				append asm { }
				append asm $tmp_asm

				set file_len [llength $file]
				incr asm_len $file_len
				incr idx $file_len
			}
		}

		# Return flag "code included"
		return $repeat
	}

	## Get content of the specified file
	 # @parm String dir		- Current working directory
	 # @parm String file		- Name of file to include
	 # @parm Int file_number	- Index in $included_files
	 # @return Bool - content of the file
	proc getFile {dir file file_number} {
		variable fileNum	;# Number of the current file
		variable lineNum	;# Number of the current line
		variable tmp_asm	;# Temporary auxiliary pre-compiled code

		set tmp_asm {}

		# File name enclosed by quotes
		if {[string index $file 0] == {'}} {
			if {[string index $file end] != {'}} {
				SyntaxError $lineNum $fileNum [mc "Invalid expression: `%s'" $file]
			} else {
				set file [string range $file 1 {end-1}]
			}
		} elseif {[string index $file 0] == "\""} {
			if {[string index $file end] != "\""} {
				SyntaxError $lineNum $fileNum [mc "Invalid expression: `%s'" $file]
			} else {
				set file [string range $file 1 {end-1}]
			}
		}

		# File exists
		if {[file exists $file]} {
			if {[catch {
				set file [open $file r]
				set data [read $file]
				close $file
			}]} then {
				CompilationError $lineNum $fileNum [mc "Unable to open file: %s" $file]
				return {}
			} else {
				# Any EOL to LF
				regsub -all {\r\n?} $data "\n" data

				# Adjust file content
				set line_number 1
				foreach line [split $data "\n"] {
					lappend tmp_asm [list $line_number $file_number $line]
					incr line_number
				}

				return $tmp_asm
			}
		# File does not exist
		} else {
			CompilationError $lineNum $fileNum [mc "File not found: %s" $file]
			return {}
		}
	}

	## Parse and remove directive(s) 'END'
	 # @return void
	proc end_of_code {} {
		variable asm		;# Resulting pre-compiled code
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable idx		;# Current position in asm list

		# Reset NS variables
		set idx		-1

		# Local variables
		set end		0
		set last_line	{}

		# Iterate over the code
		foreach line $asm {
			incr idx

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			# Determinate line number and line content
			set lineNum	[lindex $line 0]
			set fileNum	[lindex $line 1]
			set line	[lindex $line 2]

			# Skip lines without word 'END'
			if {![regexp -nocase {end} $line]} {
				continue
			}

			regsub {\s*;.*$} $line {} line
			regsub -all {:} $line {: } line

			# Determinate 1st and 2nd field of the line
			if {![regexp {^\s*[^\s]+} $line field0]} {
				set field0 {}
			} else {
				set field0 [string trim $field0]
			}
			if {![regexp {^\s*[^\s]+\s+[^\s]+} $line field1]} {
				set field1 {}
			} else {
				regexp {[^\s]+$} $field1 field1
			}
			set field0 [string tolower [regsub {^\.} $field0 {}]]
			set field1 [string tolower [regsub {^\.} $field1 {}]]

			# Directive 'end' detected in the 1st field
			if {$field0 == {end}} {
				set end 1
				break

			# Directive 'end' and some label
			} elseif {
				[regexp {^\w+:$} $field0]
					&&
				($field1 == {end})
			} then {
				# Determinate content of the last line of the code (that label)
				if {![regexp {^\w+:$} $field0 last_line]} {
					set last_line {}
				}

				# Check if the line does not contain anything except the label and 'END'
				regsub {^\s*\w+:\s*} $line {} line
				set line [string tolower $line]
				if {$line != {end}} {
					SyntaxError $lineNum $fileNum [mc "Extra symbols after `END' directive"]
				}

				set end 1
				break
			}
		}

		# Directive 'end' detected -> adjust the code
		if {$end} {
			set asm [lreplace $asm $idx end]
			set preserve_current_line 0
			if {$last_line != {}} {
				lappend asm [list $lineNum $fileNum $last_line]
				set preserve_current_line 1
			}
			CodeListing::end_directive $idx $preserve_current_line

		# Directive 'end' not found -> invoke warning
		} else {
			Warning 0 0 [mc "Missing `END' directive"]
		}
	}

	## Parse and remove directive(s) 'ORG' and reorganize the current code
	 # @return void
	proc origin_directive {} {
		variable asm		;# Resulting pre-compiled code
		variable tmp_asm	;# Temporary auxiliary pre-compiled code
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable idx		;# Current position in asm list
		variable defined_LABEL	;# List of defined labels
		variable labels		;# Array: Values of defined labels ($labels($label) == $address)
		variable ErrorAtLine	;# Bool: Error occurred on the current line
		variable origin_d_addr	;# List: Addresses of static program blocks

		# Reset NS variables
		set tmp_asm	{}
		set idx		-1
		set origin_d_addr {}

		## Map of program memory organization
		 # {
		 #	{lineNumber fileNumber address}
		 #	...
		 # }
		set organization {}

		# Create code organization map and remove lines containing directive 'ORG'
		set last_value 0
		foreach line $asm {
			incr idx
			set ErrorAtLine 0

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			# Determinate line number and line content
			set lineNum	[lindex $line 0]
			set fileNum	[lindex $line 1]
			set line	[lindex $line 2]

			# Skip lines without word 'ORG'
			if {![regexp -nocase {\.?org} $line]} {
				lappend tmp_asm [list $lineNum $fileNum $line]
				continue
			}

			# Determinate label
			if {![regexp {^\w+:} $line label]} {
				set label {}
			}

			# Remove label from the line
			regsub {^\w+:} $line {} line
			set line [string tolower $line]

			# Directive ORG detected
			if {![regexp {^\s*\.?\w+} $line field0]} {
				set field0 {}
			} else {
				set field0 [string trim $field0]
			}
			if {[regsub {^\.} $field0 {}] == {org}} {
				# Determinate argument
				set line [lreplace $line 0 0]
				set value {}
				set error 0
				if {$line == {}} {
					SyntaxError $lineNum $fileNum [mc "Missing address"]
					set error 1
				} else {
					set value [ComputeExpr $line]
				}

				# Adjust label and check if it is not already defined
				if {$label != {}} {
					set label [string trimright $label {:}]
					if {[regexp {^[a-zA-Z]\w*$} $label]} {
						if {[lsearch -exact -ascii $defined_LABEL $label] != -1} {
							SyntaxError $lineNum $fileNum [mc "Label already defined: `%s'" $label]
							set error 1
						}
					} else {
						SyntaxError $lineNum $fileNum [mc "Invalid label: `%s'" $label]
						set error 1
					}
				}

				# Empty argument -> error
				if {!$error && $value == {}} {
					SyntaxError $lineNum $fileNum [mc "Invalid expression `%s'" $line]
					set error 1
				}

				# Skip lines containing error
				if {$error} {continue}

				# Define the label
				if {$label != {}} {
					lappend defined_LABEL $label
					set labels($label) $value
				}

				# Adjust the code and organization map
				lappend tmp_asm [list $lineNum $fileNum [list {ORG} $value]]
				lappend organization [list $lineNum $fileNum $value]
				if {$last_value > $value} {
					Warning $lineNum $fileNum [mc "This ORG has lower value than the previous one"]
				}
				set last_value $value

			# Directive ORG wasn't detected
			} else {
				lappend tmp_asm [list $lineNum $fileNum $line]
			}
		}

		# Replace old code with the new one
		set asm $tmp_asm

		# Empty organization map -> abort
		if {$organization == {}} {return}

		## Convert map of program organization to this form:
		 # {
		 #	{lineNumber_start fileNum_start lineNumber_end fileNum_end address}
		 #	...
		 # }

		# Sort organization map by start line
		set organization [lsort -index 0 -integer $organization]

		set last_line		{}	;# Last line number
		set last_file		{}	;# Last file number
		set last_addr		{}	;# Last address or origin
		set new_organization	{}	;# New organization map

		# Reformat organization map
		foreach org $organization {
			set line [lindex $org 0]	;# Line number
			set file [lindex $org 1]	;# File number
			set addr [lindex $org 2]	;# Address or origin

			# Adjust new organization map
			if {$last_line != {}} {
				incr line -1
				lappend new_organization [list $last_line $last_file $line $file $last_addr]
				incr line
			}
			set last_line $line	;# Last line number
			set last_file $file	;# Last file number
			set last_addr $addr	;# Last address or origin

		}
		lappend new_organization [list $last_line $last_file [lindex $asm {end 0}] [lindex $asm {end 1}] $addr]

		# Sort organization map by address
		set organization [lsort -index 4 -integer $new_organization]

		## Reassemble the code
		set tmp_asm		{}
		set new_organization	{}
		foreach org $organization {
			set start [lineNum2idx [lindex $org 0] [lindex $org 1] 1]	;# Line of the start
			set end [lineNum2idx [lindex $org 2] [lindex $org 3] 0]	;# Line of the end

			lappend origin_d_addr [lindex $org 4]
			lappend new_organization [list $start $end]

			append tmp_asm { }
			append tmp_asm [lrange $asm $start $end]
			set asm [lreplace $asm $start $end]
		}
		if {$asm != {}} {
			append tmp_asm { }
			append tmp_asm $asm
		}
		set asm $tmp_asm

		# Adjust code listing
		CodeListing::org $new_organization
	}

	## Convert pair line number and file number to index in the code list
	 # @parm Int line_number - line number
	 # @parm Int file_number - file number
	 # @parm Bool first	 - match the first
	 # @return Int - list index
	proc lineNum2idx {line_number file_number first} {
		variable asm	;# Resulting pre-compiled code

		set idx -1
		set ln 0
		foreach line $asm {
			incr idx

			if {[lindex $line 1] != $file_number} {
				continue
			}

			set ln [lindex $line 0]

			if {($first && ($ln >= $line_number)) || (!$first && ($ln > $line_number))} {
				if {$ln > $line_number} {
					incr idx -1
				}
				if {$idx < 0} {
					return 0
				} else {
					return $idx
				}
			}
		}
		set len [llength $asm]
		incr len -1
		return $len
	}

	## Convert the current code into numbered list (see proc. 'compile')
	 # @return void
	proc line_numbers {} {
		variable asm		;# Resulting pre-compiled code
		variable tmp_asm	;# Temporary auxiliary pre-compiled code
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		# Reset NS variables
		set tmp_asm	{}
		set lineNum	0
		set idx		-1

		# Adjust some special characters
		regsub -all {\r\n?} $asm "\n" asm
		regsub -all {\\} $asm "\\\\" asm
		regsub -all {\{} $asm "\\\{" asm
		regsub -all {\}} $asm "\\\}" asm
		regsub -all {\"} $asm "\\\"" asm

		# Create new code list
		foreach line [split $asm "\n"] {
			incr idx
			incr lineNum
			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}
			# Append adjusted line to the code
			lappend tmp_asm [list $lineNum 0 $line]
		}

		# Replace old code with the new one
		set asm $tmp_asm

		# Create code listing
		CodeListing::create_listing $asm
	}

	## Evaluate and remove directives related to:
	 #	- Conditional compilation		(IF, ELSE, ENDIF)			(group 0)
	 #	- Code listing enable/disable		(LIST, NOLIST)				(group 1)
	 #	- Active bank selection			(USING)					(group 2)
	 #	- Data memory segment selection		(BSEG, DSEG, ISEG, XSEG)		(group 3)
	 #	- Constant definitions			(SET, EQU, BIT, DATA, IDATA, XDATA)	(group 4)
	 #	- Data memory reservation		(DS, DBIT)				(group 5)
	 # @parm List on 6 Bools	- Groups to parse
	 # @parm Bool ignore_undefined	- Ignore undefined symbolic names
	 # @return Bool - Anything expanded
	proc parse_Consts_and_ConditionalCompilation {groups ignore_undefined} {
		variable asm			;# Resulting pre-compiled code
		variable tmp_asm		;# Temporary auxiliary pre-compiled code
		variable ErrorAtLine		;# Bool: Error occurred on the current line
		variable lineNum		;# Number of the current line
		variable fileNum		;# Number of the current file
		variable idx			;# Current position in asm list
		variable Enable			;# Bool: Compilation enabled (conditional compilation)
		variable memory_reservation_map	;# Array: memory reservation map (see code)
		variable defined_SET		;# List of variables defined by 'SET'
		variable const_SET		;# Array: Constants defined by directive 'CODE'
		variable selected_segment	;# Current memory segment (one of {cseg bseg dseg iseg xseg})
		variable segment_pointer	;# Current memory segment pointer

		# Reset NS variables
		set idx		-1
		set tmp_asm	{}
		set Enable	1

		# Local variables
		set deleteLine	1	;# Remove the current line
		set fin_result	0	;# Anything expanded
		set loc_result	0

		# Iterate over the code
		foreach line $asm {
			incr idx

			# Final stage -- skip lines without constant definition
			if {[llength $line] != 3 && [lindex $line 2] != {C}} {
				lappend tmp_asm $line
				continue
			}

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return $fin_result
			}

			## Determinate line number and line content
			set lineNum	[lindex $line 0]
			set fileNum	[lindex $line 1]
			 # Firts level pass
			if {[llength $line] == 3} {
				set line	[lindex $line 2]
				regsub -nocase -- {if\(} $line {if (} line	;# Make construction "IF(something)" valid
			 # Final level pass
			} else {
				set line	[lindex $line 3]
			}

			set ErrorAtLine	0	;# Reset last error
			set deleteLine	1	;# Remove the current error

			# Determinate 1st field of the line
			if {![regexp {^\s*\.?\w+:?} $line line_first_field]} {
				set line_first_field {}
			} else {
				set line_first_field [string trim $line_first_field]
			}
			set directive0 [string tolower $line_first_field]
			set directive0 [regsub {^\.} $directive0 {}]

			# Determinate 2nd field of the line
			if {![regexp {^\s*\.?\w+:?\s*\.?\w+} $line directive1]} {
				set directive1 {}
			} else {
				regsub {^\s*\.?\w+:?\s*} $directive1 {} directive1
				set directive1 [string trim $directive1]
			}
			set directive1 [string tolower $directive1]
			set directive1 [regsub {^\.} $directive1 {}]

			set label {}

			# Constant definition (SET EQU BIT ...) without constant to define (syntax error)
			if {
				[lindex $groups 4] && $Enable &&
				([lsearch -exact -ascii ${::CompilerConsts::ConstDefinitionDirectives} $directive0] != -1)
			} then {
				if {[regexp {^\s*\.?\w+\s+\w+\s*\,\s*.+$} $line]} {
					Warning $lineNum $fileNum [mc "This formulation is deprecated, consider usage of \"<Const> <Directive> <Value>\" instead"]

					set line_expr {}
					regsub {^\s*\.?\w+\s+\w+\s*\,\s*} $line {} line_expr
					set line_aux $directive1
					append line_aux { } $directive0 { } $line_expr

					set loc_result [define_const $directive0 $line_aux $idx $ignore_undefined]
					if {$loc_result == 2} {
						lappend tmp_asm [list $lineNum $fileNum $line]
						set deleteLine 0
					} elseif {$loc_result == 0} {
						set fin_result 1
					}
				} else {
					SyntaxError $lineNum $fileNum [mc "Missing name of constant to define"]
				}

			# Constant definition (SET EQU BIT ...)
			} elseif {
				[lindex $groups 4] && $Enable &&
				([lsearch -exact -ascii ${::CompilerConsts::ConstDefinitionDirectives} $directive1] != -1)
			} then {
				set loc_result [define_const $directive1 $line $idx $ignore_undefined]
				if {$loc_result == 2} {
					lappend tmp_asm [list $lineNum $fileNum $line]
					set deleteLine 0
				} elseif {$loc_result == 0} {
					set fin_result 1
				}

			# Listing control (LIST, NOLIST)
			} elseif {
				[lindex $groups 1] && (
					($directive0 == {list})		||
					($directive0 == {nolist})	||
					($directive1 == {list} && [regexp {^\w+:$} $directive0 label])	||
					($directive1 == {nolist} && [regexp {^\w+:$} $directive0 label])
				)
			} then {
				# Warning messages
				if {($directive0 == {list} || $directive0 == {nolist}) && [string length $directive1]} {
					Warning $lineNum $fileNum [mc "Directive %s takes no arguments" [string toupper $directive0]]
				} elseif {($directive1 == {list} || $directive1 == {nolist}) && [string length [regsub {^\s*\.?\w+:?\s+\.?\w+} $line {}]]} {
					Warning $lineNum $fileNum [mc "Directive %s takes no arguments" [string toupper $directive1]]
				}

				if {($directive0 == {nolist}) || ($directive1 == {nolist})} {
					CodeListing::directive_nolist $idx
				} else {
					CodeListing::directive_list $idx
				}

				if {($label != {}) && $Enable} {
					lappend tmp_asm [list $lineNum $fileNum $label]
					set deleteLine 0
				}

			# Active bank selection directive -- in 1st field (USING)
			} elseif {[lindex $groups 2] && $Enable && ($directive0 == {using})} {
				set loc_result [define_active_bank			\
					[regsub {^\.?\w+\s*} $line {}] $ignore_undefined	\
				]
				if {$loc_result == 2} {
					lappend tmp_asm [list $lineNum $fileNum $line]
					set deleteLine 0
				} elseif {$loc_result == 0} {
					set fin_result 1
				}

			# Active bank selection directive -- in 2nd field (USING)
			} elseif {
				[lindex $groups 2] && ($directive1 == {using}) && $Enable
					&&
				([regexp {^\w+:$} $directive0 label])
			} then {
				set loc_result [define_active_bank				\
					[regsub {^\w+:\s*\.?\w+\s*} $line {}] $ignore_undefined	\
				]
				set deleteLine 0
				if {$loc_result == 2} {
					lappend tmp_asm [list $lineNum $fileNum $line]
				} elseif {$loc_result == 0} {
					lappend tmp_asm [list $lineNum $fileNum $label]
					set fin_result 1
				} else {
					lappend tmp_asm [list $lineNum $fileNum $label]
				}

			# Data segment selection (XSEG DSEG ...)
			} elseif {
				[lindex $groups 3] && $Enable &&
				([lsearch -exact -ascii ${::CompilerConsts::ConstDataSegmentSelectionDirectives} $directive0] != -1)
			} then {
				set loc_result [data_segment_selection				\
					$directive0 $directive1 $line $idx $ignore_undefined	\
				]
				if {$loc_result == 2} {
					lappend tmp_asm [list $lineNum $fileNum $line]
					set deleteLine 0
				} elseif {$loc_result == 0} {
					set fin_result 1
				}

			# ORG in other than CODE segment
			} elseif {
				$directive0 == {org} || $directive1 == {org}
			} then {
				if {$selected_segment != {cseg}} {
					regsub {org} $line "$selected_segment at" line

					set address {}
					if {$directive0 == {org}} {
						set address [ComputeExpr $directive1]
					} elseif {$directive1 == {org}} {
						set address [ComputeExpr [regsub {^\w+:\s*\.?\w+\s*} $line {}]]
					}
					if {$address != {}} {
						set segment_pointer($selected_segment) $address
					}
				}

				lappend tmp_asm [list $lineNum $fileNum $line]
				set deleteLine 0

			# Data memory reservation -- without label (DBIT 125)
			} elseif {
				[lindex $groups 5] && $Enable	&&
				([lsearch -exact -ascii ${::CompilerConsts::ConstDataMemoryReservationDirectives} $directive0] != -1)
			} then {
				regsub {^\.?\w+\s*} $line {} value
				set loc_result [data_memory_reservation {} $directive0 $value $idx $ignore_undefined]
				if {$loc_result == 2} {
					lappend tmp_asm [list $lineNum $fileNum $line]
					set deleteLine 0
				} elseif {$loc_result == 0} {
					set fin_result 1
				}

			# Data memory reservation -- with label (ram: DS 4Fh)
			} elseif {
				[lindex $groups 5] && [regexp {^\w+:$} $line_first_field] && $Enable
					&&
				([lsearch -exact -ascii ${::CompilerConsts::ConstDataMemoryReservationDirectives} $directive1] != -1)
			} then {
				regsub {^\s*\w+:\s*\.?\w+\s*} $line {} value
				set loc_result [data_memory_reservation				\
					$line_first_field $directive1 $value $idx $ignore_undefined	\
				]
				if {$loc_result == 2} {
					lappend tmp_asm [list $lineNum $fileNum $line]
					set deleteLine 0
				} elseif {$loc_result == 0} {
					set fin_result 1
				}

			# Conditional compilation statement -- in 2nd field (IF ELSE ENDIF IFNDEF IFDEF IFN ELSEIF ELSEIFN ELSEIFDEF ELSEIFNDEF)
			} elseif {
				[lindex $groups 0] && (
					[lsearch -ascii -exact {if else endif ifndef ifdef ifn elseif elseifn elseifdef elseifndef} $directive1] != -1
				) && (
					[regexp {^\w+:$} $line_first_field label]
				)
			} then {
				# Is compilation enabled ?
				if {$Enable} {
					lappend tmp_asm [list $lineNum $fileNum $label]
					set deleteLine 0
				}

				regsub {^\w+:\s*\.?\w+\s*} $line {} value
				If_Else_Endif $directive1 $value

				# Directive takes no arguments
				if {($directive1 == {else} || $directive1 == {endif}) && [string length $value]} {
					Warning $lineNum $fileNum [mc "Directive %s takes no arguments" [string toupper $directive1]]
				}

			} else {
				# Conditional compilation statement -- in 1st field (IF ELSE ENDIF IFNDEF IFDEF IFN ELSEIFN ELSEIFDEF ELSEIFNDEF)
				if {
					[lindex $groups 0] && (
						[lsearch -ascii -exact {if else endif ifndef ifdef ifn elseif elseifn elseifdef elseifndef} $directive0] != -1
					)
				} then {

					regsub {^\.?\w+\s*} $line {} value

					# Directive takes no arguments
					if {($directive1 == {else} || $directive1 == {endif}) && [string length $value]} {
						Warning $lineNum $fileNum [mc "Directive %s takes no arguments" [string toupper $directive0]]
					}

					If_Else_Endif $directive0 $value
				} else {
					# Is compilation enabled ?
					if {$Enable} {
						lappend tmp_asm [list $lineNum $fileNum $line]
						set deleteLine 0

						if {$directive0 == {cseg} || $directive1 == {cseg}} {
							set selected_segment {cseg}
						}
					}
				}
			}

			if {$deleteLine} {
				CodeListing::delete_line $idx
				incr idx -1
			}
		}

		# Sort list of SET variables by line numbers
		foreach const $defined_SET {
			set const_SET($const) [lsort -integer -index 0 $const_SET($const)]
		}

		# Replace old code with the new one
		set asm $tmp_asm

		return $fin_result
	}

	## Set active register bank
	 # @parm String expr		- expression defining bank number
	 # @parm Bool ignore_undefined	- Ignore undefined symbolic names in declaration
	 # @return Bool - 0 == Resolved; 1 == Unresolved (discard line);  2 == Unresolved (keep line)
	proc define_active_bank {expr ignore_undefined} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		# Expression must not be empty
		if {$expr == {}} {
			SyntaxError $lineNum $fileNum [mc "Empty expression"]
			return 1
		}

		# Determinate expression value
		set value [ComputeExpr $expr $ignore_undefined]
		if {$value == {}} {
			if {$ignore_undefined} {
				return 2
			}
			SyntaxError $lineNum $fileNum [mc "Invalid expression: `%s'" $expr]
			return 1
		}

		# Check for value validity
		if {($value > 3) || ($value < 0)} {
			SyntaxError $lineNum $fileNum [mc "Argument value is out of range ({0 1 2 3}) : `%s'" $value]
			return 1
		}

		# Define variables AR0..7
		set value [expr {$value * 8}]
		for {set i 0} {$i < 8} {incr i} {
			define_variable "ar$i" $value 0
			incr value
		}

		return 0
	}

	## Reserve space in data memory
	 # --auxiliary procedure for 'parse_Consts_and_ConditionalCompilation'
	 # @parm String label		- Label
	 # @parm String directive	- Directive
	 # @parm String expr		- Directive argument
	 # @parm Int idx		- Current index in the code list
	 # @parm Bool ignore_undefined	- Ignore undefined symbolic names in declaration
	 # @return Bool - 0 == Resolved; 1 == Unresolved (discard line);  2 == Unresolved (keep line)
	proc data_memory_reservation {label directive expr idx ignore_undefined} {
		variable lineNum		;# Number of the current line
		variable fileNum		;# Number of the current file
		variable selected_segment	;# Current memory segment (one of {cseg bseg dseg iseg xseg})

		# Compute expression value
		if {![string length $expr]} {
			SyntaxError $lineNum $fileNum [mc "Missing size"]
			set value 1
		} else {
			set value [ComputeExpr $expr $ignore_undefined]
		}

		# Check for value validity
		if {$value == {}} {
			if {$ignore_undefined} {
				return 2
			}
			SyntaxError $lineNum $fileNum [mc "Invalid expression `%s'" $expr]
			return 1
		} elseif {$value < 0} {
			SyntaxError $lineNum $fileNum [mc "Length of data area cannot be negative number: %s" $value]
			return 1
		}

		# Adjust label
		set label [string tolower $label]

		# Reserve bit
		if {$directive == {dbit}} {
			# Check if the active segment is (BSEG)
			if {$selected_segment != {bseg}} {
				Warning $lineNum $fileNum [mc "Using `DBIT' directive, but active segment is `%s' (should be BSEG)" [string toupper $selected_segment]]
			}

			# Reserve memory
			return [reserve_memory $label bseg $value $idx]

		# Reserve byte
		} elseif {$directive == {ds}} {
			# Check if the active segment is one of {DSEG ISEG XSEG}
			if {
				($selected_segment != {dseg})	&&
				($selected_segment != {iseg})	&&
				($selected_segment != {xseg})
			} then {
				Warning $lineNum $fileNum [mc "Using `%s' directive, but currently active segment is `%s'" [string toupper $directive] [string toupper $selected_segment]]
				set seg {dseg}
			} else {
				set seg $selected_segment
			}

			# Reserve memory
			return [reserve_memory $label $seg $value $idx]

		# Unknown request -> compilation error
		} else {
			CompilationError $lineNum $fileNum "Unknown error 4"
			return 1
		}

		return 0
	}

	## Reserve bits or bytes of data memory
	 # --auxiliary procedure for 'data_memory_reservation'
	 # @parm String label	- Symbolic name
	 # @parm String segment	- Target memory segment (one of {dseg iseg xseg bseg})
	 # @parm Int value	- Number of bits/bytes to reserve
	 # @parm Int idx	- Current index in the code list
	 # @return Bool - 0 == Resolved; 1 == Unresolved
	proc reserve_memory {label segment value idx} {
		variable lineNum		;# Number of the current line
		variable fileNum		;# Number of the current file
		variable segment_pointer	;# Current memory segment pointer
		variable memory_reservation_map	;# Array: memory reservation map (see code)
		variable const_BIT		;# Array: Bit values -- ($const_BIT($bit_name) == $value)
		variable const_DATA		;# Array: Constants defined by directive 'DATA'
		variable const_IDATA		;# Array: Constants defined by directive 'IDATA'
		variable const_XDATA		;# Array: Constants defined by directive 'XDATA'
		variable defined_BIT		;# List of defined bits (directove 'BIT')
		variable defined_DATA		;# List of constants defined by 'DATA'
		variable defined_IDATA		;# List of constants defined by 'IDATA'
		variable defined_XDATA		;# List of constants defined by 'XDATA'

		## Determinate these things:
		 #	- Type of the defined constant		:: const_type
		 #	- Recomended maximum			:: recomended_max
		 #	- Name of the target memory segment	:: segment_name
		 #	- Maximum value				:: max
		 #	- Unit (Bytes or Bits)			:: Bytes
		switch -- $segment {
			{dseg} {	;# General data memory
				set const_type		{DATA}
				set recomended_max	235
				set segment_name	{general data memory}
				set area_name		{byte}
				set max			255
				set unit		{Bytes}
			}
			{iseg} {	;# Internal data memory
				set const_type		{IDATA}
				set recomended_max	235
				set segment_name	{internal data memory}
				set area_name		{byte}
				set max			255
				set unit		{Bytes}
			}
			{xseg} {	;# External data memory
				set const_type		{XDATA}
				set recomended_max	60000
				set segment_name	{external data memory}
				set area_name		{byte}
				set max			65535
				set unit		{Bytes}
			}
			{bseg} {	;# Bit addressable area
				set const_type		{BIT}
				set recomended_max	117
				set segment_name	{bit}
				set area_name		{bit addressable}
				set max			127
				set unit		{bites}
			}
			default {	;# Fatal error
				CompilationError $lineNum $fileNum "Unknown error 5"
			}
		}

		# Check if there is enough free space in the segment
		set end [expr {$segment_pointer($segment) + $value}]
		if {$end > $max} {
			Warning $lineNum $fileNum [mc "Exceeding %s segment boundary by %s $unit." $segment_name [expr {$max - $end}]]
		} elseif {$end > $recomended_max} {
			Notice $lineNum $fileNum [mc "Nearing %s segment boundary" $segment_name]
		}

		# Check if the requested area if not already reserved
		set area [string range $memory_reservation_map($segment) $segment_pointer($segment) $end]
		if {[string first 1 $area] != -1} {
			set idx 0
			set overflow {}
			foreach bit [split $area {}] {
				if {$bit} {
					lappend overwrite [expr {$idx + $segment_pointer($segment)}]
				}
				incr idx
			}

			set overwrite_dec_hex {}
			foreach val $overwrite {
				set val [format %X $val]
				if {[string length $val] < 4} {
					set val "[string repeat 0 [expr {4 - [string length $val]}]]$val"
				}
				append overwrite_dec_hex { 0x} $val
			}

			Warning $lineNum $fileNum [mc "Overwriting reserved memory -- in %s area at addresses: %s" $area_name $overwrite_dec_hex]
		}

		# Adjust map of reserved memory
		set memory_reservation_map($segment)						\
			[string replace $memory_reservation_map($segment)			\
				$segment_pointer($segment) $end [string repeat 1 $value]	\
			]

		# Abort if there is no label
		if {$label == {}} {return}

		# Check for label validity
		if {![regexp {^[a-zA-Z_]\w*:$} $label]} {
			SyntaxError $lineNum $fileNum [mc "Invalid label: `%s'" $label]
			return 1
		}
		# Determinate name of the constant
		set const [string trimright $label {:}]

		# Assing block pointer to symbolic name specified by label
		if {[lsearch -exact -ascii [subst -nocommands "\$defined_$const_type"] $const] != -1} {
			SyntaxError $lineNum $fileNum [mc "Unable redefine constant: %s" $const]
			return 1
		} else {
			# Check if this symbol is not already defined
			if {[isConstAlreadyDefined $const]} {
				Warning $lineNum $fileNum [mc "Ambiguous symbol definition: %s" $const]
			}

			# Adjust code listing
			CodeListing::set_addr $idx $segment_pointer($segment)
			# Define the symbolic name
			set const_${const_type}($const) $segment_pointer($segment)
			lappend defined_${const_type} $const
			# Adjust segment pointer
			incr segment_pointer($segment) $value
		}

		return 0
	}

	## Determinate whether the given symbolic name is aleady defined
	 # @parm String const_name - Symbolic name to evaluate
	 # @return Bool - result (1 == aleady defined; 0 == not defined yet)
	proc isConstAlreadyDefined {const_name} {
		variable defined_BIT		;# List of defined bits (directove 'BIT')
		variable defined_CODE		;# List of constants defined by 'CODE'
		variable defined_DATA		;# List of constants defined by 'DATA'
		variable defined_IDATA		;# List of constants defined by 'IDATA'
		variable defined_XDATA		;# List of constants defined by 'XDATA'
		variable defined_SET		;# List of variables defined by 'SET'
		variable defined_EQU		;# List of constants defined by 'EQU'
		variable defined_MACRO		;# List of defined macro instructions
		variable defined_SET_SPEC	;# List of special variables defined by 'SET'
		variable defined_EQU_SPEC	;# List of special constants defined by 'EQU'

		# Adjust symbolic name
		set const_name [string tolower $const_name]

		# Search all lists of symbolic names
		if {
			[lsearch -exact -ascii [concat					\
				$defined_BIT	$defined_CODE	$defined_DATA		\
				$defined_IDATA	$defined_XDATA	$defined_SET		\
				$defined_EQU	$defined_MACRO	$defined_SET_SPEC	\
				$defined_EQU_SPEC					\
				${::CompilerConsts::defined_progVectors}		\
				${::CompilerConsts::defined_SFRBitArea}			\
				${::CompilerConsts::defined_SFR}			\
			] $const_name] != -1
		} then {
			return 1
		}
		return 0
	}

	## Change selected data memory segment
	 # --auxiliary procedure for proc. 'parse_Consts_and_ConditionalCompilation'
	 # @parm String directive	- Directive of segment selection
	 # @parm String operator	- Operator (should be 'AT')
	 # @parm String line		- Code of the current line
	 # @parm Int idx		- Current index in the code list
	 # @parm Bool ignore_undefined	- Ignore undefined symbolic names in declaration
	 # @return Bool - 0 == Resolved; 1 == Unresolved (discard line);  2 == Unresolved (keep line)
	proc data_segment_selection {directive operator line idx ignore_undefined} {
		variable lineNum		;# Number of the current line
		variable fileNum		;# Number of the current file
		variable selected_segment	;# Current memory segment (one of {cseg bseg dseg iseg xseg})
		variable segment_pointer	;# Current memory segment pointer

		# Change memory segment
		set selected_segment $directive
		if {[regsub {^\.} [string tolower $line] {}] == $directive} {
			return 0
		}

		# Check for operator validity
		if {$operator != {at}} {
			SyntaxError $lineNum $fileNum [mc "Unknown operator: `%s', should be `%s at <address>', e.g. `%s at X+0FFh'" $operator $directive $directive]
			return 1
		}

		# Determinate and evaluate expression
		regsub {^\.?\w+\s+\w+\s*} $line {} expr
		set value [ComputeExpr $expr $ignore_undefined]
		if {$value == {}} {
			if {$ignore_undefined} {
				return 2
			}
			SyntaxError $lineNum $fileNum [mc "Invalid expression `%s'" $expr]
			return 1
		}

		# Determinate maximum value of the segment pointer
		switch -- $selected_segment {
			{bseg}	{set max 127}
			{dseg}	{set max 255}
			{iseg}	{set max 255}
			{xseg}	{set max 65535}
			default	{
				return 1
				CompilationError $lineNum $fileNum "Unknown error 6"
			}
		}

		# Check for valid pointer value
		if {$value > $max} {
			SyntaxError $lineNum $fileNum [mc "Segment pointer is too high: %s / %s" $value $max]
		} elseif {$value < 0} {
			SyntaxError $lineNum $fileNum [mc "Segment pointer cannot be negative: `%s'" $value]
		} else {
			set segment_pointer($selected_segment) $value
			CodeListing::set_addr $idx $value

			if {$ignore_undefined} {
				return 2
			} else {
				return 0
			}
		}
		return 1
	}

	## Take care of conditional compilation control directives (IF, ELSE, ENDIF, IFN, IFDEF, IFNDEF, ELSEIF ELSEIFN ELSEIFDEF ELSEIFNDEF)
	 # --auxiliary procedure for 'parse_Consts_and_ConditionalCompilation'
	 # @parm String directive	- Directive
	 # @parm String cond		- Expression of the condition
	 # @return void
	proc If_Else_Endif {directive cond} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable IfElse_map	;# Array: Conditional compilation map ($IfElse_map($level) == $bool)
		variable IfElse_pcam	;# Array: Conditional compilation -- Positive condition already met ($IfElse_pcam($level) == $bool)
		variable IfElse_level	;# Current level of conditional compilation evaluation
		variable Enable		;# Bool: Compilation enabled (conditional compilation)

		set cond_orig $cond
		switch -- $directive {
			{if}	{
				# Missing condition expression
				if {![string length $cond]} {
					SyntaxError $lineNum $fileNum [mc "Missing condition"]
					set cond 1
				}

				# Evaluate the condition expression
				if {$Enable} {
					set cond [ComputeExpr $cond]
					if {$cond == {}} {
						SyntaxError $lineNum $fileNum [mc "Invalid expression `%s'" $cond_orig]
						set cond 1
					}
				} else {
					set cond 0
				}

				# Increment counter of nested block level
				incr IfElse_level

				# Adjust map of conditional compilation map and flag "Enable"
				set IfElse_map($IfElse_level) $cond
				set IfElse_pcam($IfElse_level) $cond
				if {!$Enable || !$cond} {
					set Enable 0
				}
			}
			{ifn}	{	;# IF Not
				# Missing condition expression
				if {![string length $cond]} {
					SyntaxError $lineNum $fileNum [mc "Missing condition"]
					set cond 1
				}

				# Evaluate the condition expression
				if {$Enable} {
					set cond [ComputeExpr $cond]
					if {$cond == {}} {
						SyntaxError $lineNum $fileNum [mc "Invalid expression `%s'" $cond_orig]
						set cond 1
					}
				} else {
					set cond 1
				}

				# Invert the condition
				set cond [expr {!$cond}]

				# Increment counter of nested block level
				incr IfElse_level

				# Adjust map of conditional compilation map and flag "Enable"
				set IfElse_map($IfElse_level) $cond
				set IfElse_pcam($IfElse_level) $cond
				if {!$Enable || !$cond} {
					set Enable 0
				}
			}
			{ifdef}	{	;# IF DEFined
				# Remove brackets
				set cond [string trim $cond {()}]

				# Missing condition expression
				if {![string length $cond]} {
					SyntaxError $lineNum $fileNum [mc "Missing condition"]
					set cond 1
				}

				# Evaluate the condition expression
				set cond [expr {$Enable && [isConstAlreadyDefined $cond]}]

				# Increment counter of nested block level
				incr IfElse_level

				# Adjust map of conditional compilation map and flag "Enable"
				set IfElse_map($IfElse_level) $cond
				set IfElse_pcam($IfElse_level) $cond
				if {!$Enable || !$cond} {
					set Enable 0
				}
			}
			{ifndef} {	;# IF Not DEFined
				# Remove brackets
				set cond [string trim $cond {()}]

				# Missing condition expression
				if {![string length $cond]} {
					SyntaxError $lineNum $fileNum [mc "Missing condition"]
					set cond 1
				}

				# Evaluate the condition expression
				set cond [expr {$Enable && ![isConstAlreadyDefined $cond]}]

				# Increment counter of nested block level
				incr IfElse_level

				# Adjust map of conditional compilation map and flag "Enable"
				set IfElse_map($IfElse_level) $cond
				set IfElse_pcam($IfElse_level) $cond
				if {!$Enable || !$cond} {
					set Enable 0
				}
			}
			{else}	{
				if {[llength [array names IfElse_map $IfElse_level]] == 0} {
					SyntaxError $lineNum $fileNum [mc "Unexpected `ELSE'"]
				} else {
					set IfElse_map($IfElse_level) [expr {!$IfElse_pcam($IfElse_level)}]
					set Enable 1
					for {set i 1} {$i <= $IfElse_level} {incr i} {
						set Enable [expr {$IfElse_map($i) && $Enable}]
					}
				}
			}
			{elseifn}	-
			{elseifdef}	-
			{elseifndef}	-
			{elseif}	{
				if {[llength [array names IfElse_map $IfElse_level]] == 0} {
					SyntaxError $lineNum $fileNum [mc "Unexpected `ELSEIF'"]
				} else {
					# Missing condition expression
					if {![string length $cond]} {
						SyntaxError $lineNum $fileNum [mc "Missing condition"]
						set cond 1
					}

					# Evaluate the condition expression
					if {
						!$IfElse_pcam($IfElse_level)
							&&
						($IfElse_level == 1 || $IfElse_map([expr {$IfElse_level - 1}]))
					} then {
						switch -- $directive {
							{elseif}	{
								set cond [ComputeExpr $cond]
							}
							{elseifn}	{
								set cond [ComputeExpr $cond]
								if {$cond != {}} {
									set cond [expr {!$cond}]
								}
							}
							{elseifdef}	{
								set cond [isConstAlreadyDefined $cond]
							}
							{elseifndef}	{
								set cond [expr {![isConstAlreadyDefined $cond]}]
							}
						}
						if {$cond == {}} {
							SyntaxError $lineNum $fileNum [mc "Invalid expression `%s'" $cond_orig]
							set cond 1
						}
					} else {
						set cond 0
					}

					if {$cond} {
						set IfElse_pcam($IfElse_level) 1
					}
					set IfElse_map($IfElse_level) $cond
					set Enable 1
					for {set i 1} {$i <= $IfElse_level} {incr i} {
						set Enable [expr {$IfElse_map($i) && $Enable}]
					}
				}
			}
			{endif}	{
				incr IfElse_level -1	;# Decrement counter of nested block level
				set Enable 1

				# End of nested statement
				if {$IfElse_level >= 0} {
					for {set i 1} {$i <= $IfElse_level} {incr i} {
						set Enable [expr {$IfElse_map($i) && $Enable}]
					}

				# Invalid directive usage
				} else {
					incr IfElse_level
					SyntaxError $lineNum $fileNum [mc "Unexpected `ENDIF'"]
				}
			}
			default	{
				CompilationError $lineNum $fileNum "`$directive' is not a if/else/endif/ifn/ifdef/ifndef/elseif directive (procedure: If_Else_Endif)"
			}
		}
	}

	## Define symbolic name
	 # --auxiliary procedure for 'parse_Consts_and_ConditionalCompilation'
	 # @parm String directive	- Definition directive
	 # @parm String line		- Line of source code
	 # @parm Int idx		- Current index in the code list
	 # @parm Bool ignore_undefined	- Ignore undefined symbolic names in declaration
	 # @return Bool - 0 == Resolved; 1 == Unresolved (discard line);  2 == Unresolved (keep line)
	proc define_const {directive line idx ignore_undefined} {
		variable const_BIT	;# Array: Bit values -- ($const_BIT($bit_name) == $value)
		variable const_CODE	;# Array: Constants defined by directive 'CODE'
		variable const_DATA	;# Array: Constants defined by directive 'DATA'
		variable const_IDATA	;# Array: Constants defined by directive 'IDATA'
		variable const_XDATA	;# Array: Constants defined by directive 'XDATA'
		variable const_SET	;# Array: Constants defined by directive 'CODE'
		variable const_EQU	;# Array: Constants defined by directive 'EQU'

		variable defined_BIT	;# List of defined bits (directove 'BIT')
		variable defined_CODE	;# List of constants defined by 'CODE'
		variable defined_DATA	;# List of constants defined by 'DATA'
		variable defined_IDATA	;# List of constants defined by 'IDATA'
		variable defined_XDATA	;# List of constants defined by 'XDATA'
		variable defined_SET	;# List of variables defined by 'SET'
		variable defined_EQU	;# List of constants defined by 'EQU'

		variable const_SET_SPEC		;# Array: Special constants defined by directive 'CODE'
		variable const_EQU_SPEC		;# Array: Special constants defined by directive 'EQU'
		variable defined_SET_SPEC	;# List of special variables defined by 'SET'
		variable defined_EQU_SPEC	;# List of special constants defined by 'EQU'

		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable ErrorAtLine	;# Bool: Error occurred on the current line

		# Handle directive "FLAG", which has the same meaning as "BIT"
		if {$directive == {flag}} {
			set directive {bit}
		}

		# Detrminate 1st field and the last (3rd) field
		if {![regexp {^\s*\w+} $line const]} {
			set const {}					;# symbolic name
		} else {
			set const [string tolower [string trim $const]]	;# symbolic name
		}
		if {![regsub {^\w+\s+\.?\w+\s+} $line {} value]} {
			SyntaxError $lineNum $fileNum [mc "Missing expression"]
			return 1
		}

		# Check for symbolic name validity
		if {![regexp {^[a-zA-Z_]\w*$} $const]} {
			SyntaxError $lineNum $fileNum [mc "Invalid symbolic name: %s" $const]
			return 1
		}

		# Does value field contain comma ?
		if {[string first {,} $value] != -1} {
			# Is const field an instruction ?
			if {[lsearch -exact -ascii ${::CompilerConsts::AllInstructions} $const] != -1} {
				# yes -> skip this line
				if {$ignore_undefined} {
					return 2
				} else {
					return 1
				}
			} else {
				# no -> remove line & report syntax error
				SyntaxError $lineNum $fileNum [mc "Invalid expression: `%s'" $value]
				return 1
			}
		}

		# Is the 1st field a label ? (label:)
		if {[regexp {^\w+:$} $const]} {
			SyntaxError $lineNum $fileNum [mc "Expected symbol to define, but got label: `%s'" $const]
			return 1
		}

		# Check if the 1st field contain only allowed symbols
		if {![regexp {^[a-zA-Z_]\w*$} $const]} {
			SyntaxError $lineNum $fileNum [mc "Invalid symbol name: `%s'" $const]
			return 1
		}

		# Determinate value of expression
		set special_value 0
		if {[regexp {^\w+\.\w+$} $value]} {
			set value [getBitAddr $value $ignore_undefined]
			if {$value == {}} {
				set value 0
			}
		} elseif {
			[lsearch -ascii -exact ${::CompilerConsts::FixedOperands} [string tolower $value]] != -1
			&& ($directive == {equ} || $directive == {set})
		} then {
			Notice $lineNum $fileNum [mc "Special value (with no numerical representation) assigned to constant: %s <- %s" [string toupper $const] [string toupper $value]]
			set special_value 1
		} else {
			set value_orig $value
			set value [ComputeExpr $value $ignore_undefined]
		}

		# Check for value validity
		if {$value == {}} {
			if {$ignore_undefined} {
				return 2
			}
			SyntaxError $lineNum $fileNum [mc "Invalid expression `%s'" $value_orig]
			return 1
		}

		# Adjust code listing
		if {$special_value} {
			CodeListing::set_spec_value $idx $value
		} else {
			CodeListing::set_value $idx $value
		}
		# Define symbolic name
		switch -- $directive {
			{bit}	{
				if {[lsearch -exact -ascii $defined_BIT $const] != -1} {
					SyntaxError $lineNum $fileNum [mc "Trying to overwrite constant: %s" $const]
					return 1
				}
				if {$value > 255} {
					SyntaxError $lineNum $fileNum [mc "Expression out of range"]
					return 1
				}
				if {[isConstAlreadyDefined $const]} {
					Warning $lineNum $fileNum [mc "Ambiguous symbol definition: %s" $const]
				}
				set const_BIT($const) $value
				lappend defined_BIT $const
			}
			{code}	{
				if {[lsearch -exact -ascii $defined_CODE $const] != -1} {
					SyntaxError $lineNum $fileNum [mc "Trying to overwrite constant: %s" $const]
					return 1
				}
				if {$value > 0xFFFF} {
					SyntaxError $lineNum $fileNum [mc "Expression out of range"]
					return 1
				} elseif {$value >= ${::Compiler::Settings::code_size}} {
					Warning $lineNum $fileNum [mc "Exceeding code memory capacity: %s <- %s" $const $value]
				}
				if {[isConstAlreadyDefined $const]} {
					Warning $lineNum $fileNum [mc "Ambiguous symbol definition: %s" $const]
				}
				set const_CODE($const) $value
				lappend defined_CODE $const
			}
			{data}	{
				if {
					([lsearch -exact -ascii $defined_IDATA $const] != -1)
						||
					([lsearch -exact -ascii $defined_DATA $const] != -1)
				} then {
					SyntaxError $lineNum $fileNum [mc "Trying to overwrite constant: %s" $const]
					return 1
				}
				if {$value > 0xFF} {
					SyntaxError $lineNum $fileNum [mc "Expression out of range"]
					return 1
				} elseif {$value >= ${::Compiler::Settings::iram_size}} {
					Warning $lineNum $fileNum [mc "Exceeding internal data memory capacity: %s <- %s" $const $value]
				}
				if {[isConstAlreadyDefined $const]} {
					Warning $lineNum $fileNum [mc "Ambiguous symbol definition: %s" $const]
				}
				set const_DATA($const) $value
				lappend defined_DATA $const
			}
			{idata}	{
				if {
					([lsearch -exact -ascii $defined_IDATA $const] != -1)
						||
					([lsearch -exact -ascii $defined_DATA $const] != -1)
				} then {
					SyntaxError $lineNum $fileNum [mc "Trying to overwrite constant: %s" $const]
					return 1
				}
				if {$value > 0xFF} {
					SyntaxError $lineNum $fileNum [mc "Expression out of range"]
					return 1
				} elseif {$value >= ${::Compiler::Settings::iram_size}} {
					Warning $lineNum $fileNum [mc "Exceeding internal data memory capacity: %s <- %s" $const $value]
				}
				if {[isConstAlreadyDefined $const]} {
					Warning $lineNum $fileNum [mc "Ambiguous symbol definition: %s" $const]
				}
				set const_IDATA($const) $value
				lappend defined_IDATA $const
			}
			{xdata}	{
				if {[lsearch -exact -ascii $defined_XDATA $const] != -1} {
					SyntaxError $lineNum $fileNum [mc "Trying to overwrite constant: %s" $const]
					return 1
				}
				if {$value > 0xFFFF} {
					SyntaxError $lineNum $fileNum [mc "Expression out of range"]
				} elseif {$value >= ${::Compiler::Settings::xram_size}} {
					Warning $lineNum $fileNum [mc "Exceeding external data memory capacity: %s <- %s" $const $value]
				}
				if {[isConstAlreadyDefined $const]} {
					Warning $lineNum $fileNum [mc "Ambiguous symbol definition: %s" $const]
				}
				set const_XDATA($const) $value
				lappend defined_XDATA $const
			}
			{equ}	{
				if {[lsearch -exact -ascii $defined_EQU $const] != -1 || [lsearch -exact -ascii $defined_EQU_SPEC $const] != -1} {
					SyntaxError $lineNum $fileNum [mc "Trying to overwrite constant: %s" $const]
					return 1
				}
				if {[lsearch -exact -ascii $defined_SET $const] != -1 || [lsearch -exact -ascii $defined_SET_SPEC $const] != -1} {
					SyntaxError $lineNum $fileNum [mc "Trying to change variable `%s' with wrong directive (EQU)" $const]
					set idx [lsearch -exact -ascii $defined_SET $const]
					if {$idx != -1} {
						set defined_SET [lreplace $defined_SET $idx $idx]
					} else {
						set idx [lsearch -exact -ascii $defined_SET_SPEC $const]
						if {$idx != -1} {
							set defined_SET_SPEC [lreplace $defined_SET_SPEC $idx $idx]
						}
					}
					return 1
				}
				if {[isConstAlreadyDefined $const]} {
					Warning $lineNum $fileNum [mc "Ambiguous symbol definition: %s" $const]
				}
				if {$special_value} {
					set const_EQU_SPEC($const) [string tolower $value]
					lappend defined_EQU_SPEC $const
				} else {
					set const_EQU($const) $value
					lappend defined_EQU $const
				}
			}
			{set}	{
				# note:
				#	$const_SET($const) == { { line value } ... }
				#
				return [define_variable $const $value $special_value]
			}
		}

		return 0
	}

	## Define variable (directive 'SET')
	 # --auxiliary procedure for 'define_const'
	 # @parm String const		- Name of the variable
	 # @parm Int value		- Current value of the variable
	 # @parm Bool special_value	- Assign special value like (A, AB, R0, etc.)
	 # @return Bool - 0 == Resolved; 1 == Unresolved
	proc define_variable {const value special_value} {
		variable defined_EQU	;# List of constants defined by 'EQU'
		variable defined_SET	;# List of variables defined by 'SET'
		variable const_SET	;# Array: Constants defined by directive 'CODE'
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		variable const_SET_SPEC		;# Array: Special constants defined by directive 'CODE'
		variable const_EQU_SPEC		;# Array: Special constants defined by directive 'EQU'
		variable defined_SET_SPEC	;# List of special variables defined by 'SET'
		variable defined_EQU_SPEC	;# List of special constants defined by 'EQU'

		# Check if the variable is not already defined as a constant
		if {[lsearch -exact -ascii $defined_EQU $const] != -1} {
			SyntaxError $lineNum $fileNum [mc "Trying to overwrite constant: %s" $const]
			return 1
		}

		# Set (new) variable value
		if {[lsearch -exact -ascii $defined_SET $const] != -1} {
			Notice $lineNum $fileNum [mc "Setting new variable value: %s <- %s" $const $value]
		} else {
			if {[isConstAlreadyDefined $const]} {
				Warning $lineNum $fileNum [mc "Ambiguous symbol definition: %s" $const]
			}
			if {$special_value} {
				lappend defined_SET_SPEC $const
			} else {
				lappend defined_SET $const
			}
		}
		if {$special_value} {
			lappend const_SET_SPEC($const) [list $lineNum $value]
		} else {
			lappend const_SET($const) [list $lineNum $value]
		}
		return 0
	}

	# Check if given constant/variable is defined
	 # @parm string const - constant/variable name
	 # @return bool
	proc const_exists {const} {
		variable defined_SET	;# List of variables defined by 'SET'
		variable defined_EQU	;# List of constants defined by 'EQU'

		if {
			([lsearch -exact -ascii $defined_SET $const] != -1) ||
			([lsearch -exact -ascii $defined_EQU $const] != -1)
		} then {
			return 1
		} else {
			return 0
		}
	}

	## Get constant/variable value
	 # @parm String const 		- const_name
	 # @parm Int line={}		-lineNumber
	 # @parm Bool special_value=0	- Allow special values like (A, AB, R0, etc.)
	 # @return mixed - value or emty string if nothing found
	proc const_value {const {line {}} {special_value 0}} {
		variable defined_SET		;# List of variables defined by 'SET'
		variable defined_EQU		;# List of constants defined by 'EQU'
		variable const_SET		;# Array: Constants defined by directive 'CODE'
		variable const_EQU		;# Array: Constants defined by directive 'EQU'

		variable const_SET_SPEC		;# Array: Special constants defined by directive 'CODE'
		variable const_EQU_SPEC		;# Array: Special constants defined by directive 'EQU'
		variable defined_SET_SPEC	;# List of special variables defined by 'SET'
		variable defined_EQU_SPEC	;# List of special constants defined by 'EQU'

		# Constants defined by directive 'EQU'
		if {[lsearch -exact -ascii $defined_EQU $const] != -1} {
			return $const_EQU($const)
		}

		# Constants defined by directive 'EQU'
		if {$special_value && [lsearch -exact -ascii $defined_EQU_SPEC $const] != -1} {
			return $const_EQU_SPEC($const)
		}

		# Variables defined by directive 'SET'
		if {$line != {}} {
			# Know line number ... search
			if {[lsearch -exact -ascii $defined_SET $const] != -1} {
				set value {}
				# Iterate over definitions
				foreach item $const_SET($const) {
					if {[lindex $item 0] > $line} {break}
					set value [lindex $item 1]
				}
				return $value
			}
		}
		# Special variables defined by directive 'SET'
		if {$special_value && $line != {}} {
			# Know line number ... search
			if {[lsearch -exact -ascii $defined_SET_SPEC $const] != -1} {
				set value {}
				# Iterate over definitions
				foreach item $const_SET_SPEC($const) {
					if {[lindex $item 0] > $line} {break}
					set value [lindex $item 1]
				}
				return $value
			}
		}

		# Nothing found -> failure
		return {}
	}

	## Compute value of the given expression
	 # @parm String expression		- Expression to evaluate
	 # @parm Bool ignore_undefined=0	- Ignore undefined symbolic names
	 # @parm Int address={}			- Current instruction address (for `$' expansion)
	 # @return Int - result or {}
	proc ComputeExpr {expression {ignore_undefined 0} {address {}}} {
		variable lineNum		;# Number of the current line
		variable fileNum		;# Number of the current file
		variable original_expression	;# Auxiliary variable (see proc. 'ComputeExpr')
		variable tmp			;# General purpose tempotary variable
		variable ErrorAtLine		;# Bool: Error occurred on the current line
		variable check_sfr_usage	;# Bool: Check for legal usage of SFR and SFB
		variable available_SFR		;# List: available SFR and SFB on the target MCU

		variable const_BIT		;# Array: Bit values -- ($const_BIT($bit_name) == $value)
		variable const_CODE		;# Array: Constants defined by directive 'CODE'
		variable const_DATA		;# Array: Constants defined by directive 'DATA'
		variable const_IDATA		;# Array: Constants defined by directive 'IDATA'
		variable const_XDATA		;# Array: Constants defined by directive 'XDATA'
		variable const_SET		;# Array: Constants defined by directive 'CODE'
		variable const_EQU		;# Array: Constants defined by directive 'EQU'

		variable defined_BIT		;# List of defined bits (directove 'BIT')
		variable defined_CODE		;# List of constants defined by 'CODE'
		variable defined_DATA		;# List of constants defined by 'DATA'
		variable defined_IDATA		;# List of constants defined by 'IDATA'
		variable defined_XDATA		;# List of constants defined by 'XDATA'
		variable defined_SET		;# List of variables defined by 'SET'
		variable defined_EQU		;# List of constants defined by 'EQU'

		variable labels			;# Array: Values of defined labels ($labels($label) == $address)
		variable defined_LABEL		;# List of defined labels

		variable selected_segment	;# Current memory segment (one of {cseg bseg dseg iseg xseg})
		variable segment_pointer	;# Current memory segment pointer

		set ErrorAtLine 0


		# Make backup copy of the original expression
		set original_expression $expression
		set expression " $expression "

		# Hide parantesis in strings
		set expression [replace_in_strings $expression {\(} "\a"]
		set expression [replace_in_strings $expression {\)} "\b"]

		# Check if parantesis are balanced
		if {[regexp {[\(\)]} $expression]} {
			set left_p 0
			set idx 0
			while {1} {
				set idx [string first {(} $expression $idx]
				if {$idx == -1} {break}
				incr idx
				incr left_p
			}
			set right_p 0
			set idx 0
			while {1} {
				set idx [string first {)} $expression $idx]
				if {$idx == -1} {break}
				incr idx
				incr right_p
			}

			if {$right_p != $left_p} {
				SyntaxError $lineNum $fileNum [mc "Invalid expression - parentheses are not balanced: `%s'" $original_expression]
			}
		}

		## Operators replacement
		 # symbol operators (like % or >=)
		foreach	ASM_operator	{\\=\\= !\\= \\= <> % \\* / \\- \\+ > < >\\= <\\= \\( \\)	} \
			TCL_operator	{==     !=   ==  != % *   / -   +   > < >=   <=   (   )		} {
			regsub -all -- $ASM_operator $expression " $TCL_operator " expression
		}
		 # word operators (like MOD or GE)
		foreach	ASM_oprator	{mod xor or and not eq ne gt ge lt le shr shl	} \
			TCL_operator	{ %   \^ |  \\&  \~  == != >  >= <  <= >>  <<	} {
			regsub -all -nocase --					\
				"\[\\s \]$ASM_oprator\[\\s \]"	$expression	\
				" $TCL_operator "		expression
		}

		 # operators "HIGH" and "LOW" (case-insensitive)
		if {
			([string first {low} [string tolower $expression]] != -1)
				||
			([string first {high} [string tolower $expression]] != -1)
		} then {
			foreach operator	{low		high}		\
				before		{0xFF&int(	int(}		\
				after		{)		)/0x100}	\
			{
				while {1} {
					if {![regexp -nocase -- "\\s$operator\\s+((\\w+)|(\\(\[^\\(\\)\]+\\)))" $expression str]} {
						break
					}
					set idx [string first $str $expression]
					set len [string length $str]

					set str [string replace $str 0 4]
					set str " (${before} ${str} ${after})"
					set expression [string replace $expression $idx [expr {$idx + $len - 1}] $str]
				}
			}
		}

		# Unhide parantesis in strings
		regsub -all "\a" $expression {(} expression
		regsub -all "\b" $expression {)} expression

		# Split expression into a list
		set expression [split [string trim $expression]]
		set tmp {}

		# Convert all numbers to decimal
		foreach word [replace_in_strings $expression { } "\a"] {
			if {$word == {}} {continue}

			# Handle prefix notation for hexadecimal numbers, like 0xfa
			if {
				[string index $word 0] == {0}
					&&
				([string index $word 1] == {x} || [string index $word 1] == {X})
					&&
				[string is xdigit [string index $word 2]]
			} then {
				set word [string replace $word 0 1]
				if {![string is digit [string index $word 0]]} {
					set word "0${word}"
				}
				append word {h}
			}

			if {[regexp {^\d\w+$} $word] && ![regexp {^\d+$} $word]} {
				set base [string index $word end]
				set word [string range $word 0 {end-1}]

				switch -- [string tolower $base] {
					{d} {
						if {![NumSystem::isdec $word]} {
							SyntaxError $lineNum $fileNum [mc "Invalid numeric value: %s (should be decimal number)" "${word}d"]
						}
					}
					{h} {
						if {![NumSystem::ishex $word]} {
							SyntaxError $lineNum $fileNum [mc "Invalid numeric value: %s (should be hexadecimal number)" "${word}h"]
						} else {
							set word [expr "0x$word"]
						}
					}
					{b} {
						if {![NumSystem::isbin $word]} {
							SyntaxError $lineNum $fileNum [mc "Invalid numeric value: %s (should be binary number)" "${word}b"]
						} else {
							set word [NumSystem::bin2dec $word]
						}
					}
					{o} {
						if {![NumSystem::isoct $word]} {
							SyntaxError $lineNum $fileNum [mc "Invalid numeric value: %s (should be octal number)" "${word}o"]
						} else {
							set word [NumSystem::oct2dec $word]
						}
					}
					{q} {
						if {![NumSystem::isoct $word]} {
							SyntaxError $lineNum $fileNum [mc "Invalid numeric value: %s (should be octal number)" "${word}q"]
						} else {
							set word [NumSystem::oct2dec $word]
						}
					}
				}
			} else {
				if {[string index $word end] == {'}} {
					if {[string index $word 0] != {'}} {
						SyntaxError $lineNum $fileNum [mc "Invalid value: `%s' (should be char)" $word]
					} else {
						set word [string range $word 1 end-1]
						regsub -all "\a" $word { } word
						set word [character2number [subst -nocommands -novariables $word]]
					}
				}
			}
			lappend tmp $word
		}
		set expression $tmp
		set tmp {}

		# Expand possible constants and variables
		foreach word $expression {
			if {$word == {}} {continue}
			# Dollar sign (`$')
			if {$word == {$}} {
				# Current instruction address
				if {$address != {}} {
					set word $address
				# Address pointer in the selected memory segment
				} elseif {$selected_segment != {cseg}} {
					set word $segment_pointer($selected_segment)
				} elseif {!$ignore_undefined} {
					SyntaxError $lineNum $fileNum [mc "Value of `\$' is unknown at this point" $word]
					set ErrorAtLine 1
				}

				lappend tmp $word
				continue
			}

			# Normal symbolic name
			if {![regexp {^(\?\?)?[A-Za-z_].*$} $word]} {
				set word [string trimleft $word 0]
				if {$word == {}} {
					set word 0
				}
				lappend tmp $word
				continue
			}
			set word [string tolower $word]

			# Search in SET and EQU
			if {[const_exists $word]} {
				CodeListing::symbol_used $word {equset}
				set word [const_value $word $lineNum]

			# Search in DATA
			} elseif {[lsearch -exact -ascii $defined_DATA $word] != -1} {
				if {$check_sfr_usage} {
					if {
						[lsearch -ascii -exact $::CompilerConsts::defined_SFR $word] != -1
							&&
						[lsearch -ascii -exact $available_SFR $word] == -1
					} then {
						Warning $lineNum $fileNum [mc "Special function register \"%s\" is not available on the target MCU" [string toupper $word]]
					}
				}
				set word $const_DATA($word)

			# Search in IDATA
			} elseif {[lsearch -exact -ascii $defined_IDATA $word] != -1} {
				CodeListing::symbol_used $word {idata}
				set word $const_IDATA($word)

			# Search in XDATA
			} elseif {[lsearch -exact -ascii $defined_XDATA $word] != -1} {
				CodeListing::symbol_used $word {xdata}
				set word $const_XDATA($word)

			# Search in CODE
			} elseif {[lsearch -exact -ascii $defined_CODE $word] != -1} {
				CodeListing::symbol_used $word {code}
				set word $const_CODE($word)

			# Search in BIT
			} elseif {[lsearch -exact -ascii $defined_BIT $word] != -1} {
				if {$check_sfr_usage} {
					if {
						[lsearch -ascii -exact $::CompilerConsts::defined_SFRBitArea $word] != -1
							&&
						[lsearch -ascii -exact $available_SFR $word] == -1
					} then {
						Warning $lineNum $fileNum [mc "Special function bit \"%s\" is not available on the target MCU" [string toupper $word]]
					}
				}
				CodeListing::symbol_used $word {bit}
				set word $const_BIT($word)

			# Search in LABEL
			} elseif {[lsearch -exact -ascii $defined_LABEL $word] != -1} {
				CodeListing::symbol_used $word {label}
				set word $labels($word)

			# Requeted symb. name not fount -> syntax error
			} else {
				if {$ignore_undefined} {
					return {}
				}
				SyntaxError $lineNum $fileNum [mc "Undefined symbol name: %s" $word]
				set ErrorAtLine 1
				set word 1
			}

			lappend tmp $word
		}
		set expression $tmp
		set tmp {}

		# Return empty string if evaluation is incomplete
		if {$ErrorAtLine} {return {}}

		# Compute expression and return possible result
		if {[catch {
			set expression [expr "$expression"]
		}]} then {
			return {}
		}

		if {[catch {
			set tmp [expr {int($expression)}]
		}]} then {
			return {}
		}
		if {($tmp - $expression) != 0} {
			Notice $lineNum $fileNum [mc "Floating point value converted to integer value `%s' -> `%s'" $expression $tmp]
		}
		set expression $tmp

		set tmp $expression
		while {$expression < 0} {
			incr expression 0x10000
		}
		while {$expression >= 0x10000} {
			incr expression -0x10000
		}
		if {$tmp != $expression} {
			Notice $lineNum $fileNum [mc "Overflow `%s' -> `%s'" $tmp $expression]
		}

		return $expression
	}

	## Remove comments and redutant white space
	 # @return void
	proc trim_code {} {
		variable asm		;# Resulting pre-compiled code
		variable tmp_asm	;# Temporary auxiliary pre-compiled code
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file
		variable idx		;# Current position in asm list

		# Reset NS variables
		set tmp_asm	{}
		set tmp_line	{}
		set idx		-1

		# Iterate over the code
		foreach line $asm {
			incr idx

			# Update after each 25 iterations
			if {[expr {$idx % 25}] == 0} {
				${::Compiler::Settings::UPDATE_COMMAND}
			}
			if {${::Compiler::Settings::ABORT_VARIABLE}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Aborted"]
				free_resources
				return
			}

			# Determinate line number and line content
			set lineNum	[lindex $line 0]
			set fileNum	[lindex $line 1]
			set line	[lindex $line 2]

			# Skip empty lines
			if {[regexp {^\s*$} $line]} {
				CodeListing::delete_line $idx
				incr idx -1
				continue
			}

			# Remove comment
			set tmp_line $line
			while {1} {
				if {[regexp {'[^']*'} $tmp_line str]} {
					regsub {'[^']*'} $tmp_line [string repeat {_} [string length $str]] tmp_line
				} else {
					break
				}
			}
			set semicolon_idx [string first {;} $tmp_line]
			if {$semicolon_idx == 0} {
				CodeListing::delete_line $idx
				incr idx -1
				continue
			}
			if {$semicolon_idx > 0} {
				incr semicolon_idx -1
				set line [string range $line 0 $semicolon_idx]
			}

			# Remove leading and trainling white space
			regsub {^\s+} $line {} line
			regsub {\s+$} $line {} line

			lappend tmp_asm [list $lineNum $fileNum $line]
		}

		# Replace old code with the new one
		set asm $tmp_asm
	}

	## Replace certain character by another character only within strings
	 # For instance replace_in_strings("a 'a a' a", "a", "b") --> "a 'b b' a"
	 # @parm String string		- Source string
	 # @parm String search		- Character or substring to replace
	 # @parm String replacement	- Replacement
	 # @return String - result
	proc replace_in_strings {string search replacement} {
		set idx 0
		while {1} {
			if {![regexp -start $idx -- {'[^']*'} $string str]} {
				break
			}

			set len [string length $str]
			set idx [string first $str $string $idx]
			regsub -all $search [string range $str 1 end-1] $replacement str
			set string [string replace $string $idx [expr {$idx + $len - 1}] "'$str'"]
			incr idx [expr {[string length $str] + 2}]
		}
		return $string
	}

	## Convert one logical character to a number
	 # It can translate even characters like `''', `\t', `X'
	 # @parm String value - Character to translate
	 # @return Int - Value
	proc character2number {value} {
		variable lineNum	;# Number of the current line
		variable fileNum	;# Number of the current file

		regsub -all {''} $value {'} value
		if {[string length $value] == 1} {
			binary scan $value c value
			return $value
		} else {
			if {[string index $value 0] == "\\"} {
				set value [string range $value 1 end]
				switch -- $value {
					{0} {return 0}
					{a} {return 7}
					{b} {return 8}
					{t} {return 9}
					{n} {return 10}
					{v} {return 11}
					{f} {return 12}
					{r} {return 13}
					{e} {return 101}
					default {
						set next [string index $value 0]
						if {$next == {x}} {
							set value [string range $value 1 end]
							if {[string is xdigit -strict $value]} {
								return [expr "0x$value"]
							}

						} elseif {[regexp {^[0-7]+$} $value]} {
							return [expr "0$value"]

						} elseif {$next == {c}} {
							set value [string range $value 1 end]
							if {[string length $value] == 1} {
								binary scan $value c value
								return [expr {$value & 0x1F}]
							}
						}

						SyntaxError $lineNum $fileNum [mc "Cannot to use string `%s' as a valid value" $value]
						return {}
					}
				}
			} else {
				SyntaxError $lineNum $fileNum [mc "Cannot to use string `%s' as value" $value]
				return {}
			}
		}
	}

	## Report error message -- compilation error (bug in compiler ?)
	 # @parm Int LineNumber		- Number of line where the error occurred
	 # @parm Int FileNumber		- Number of file where the error occurred, {} == unknown
	 # @parm String ErrorInfo	- Error string
	 # @return void
	proc CompilationError {LineNumber FileNumber ErrorInfo} {
		variable included_files	;# List: Unique unsorted list of included files
		variable working_dir	;# String: Current working directory
		variable idx		;# Current position in asm list
		variable error_count	;# Number of errors occurred

		# Increment error counter
		incr error_count

		# Adjust code listing
		CodeListing::Error $idx $ErrorInfo

		# Report the error
		if {$FileNumber != {}} {
			set filename [lindex $included_files $FileNumber]
			if {![string first $working_dir $filename]} {
				set filename [string replace $filename 0 [string length $working_dir]]
			}
			if {[regexp {\s} $filename]} {
				set filename "\"$filename\""
			}
			set filename [mc " in %s" $filename]
		} else {
			set filename {}
		}
		if {${::Compiler::Settings::WARNING_LEVEL} < 3} {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[::Compiler::msgc {EL}][mc "Compilation error at %s: %s" "$LineNumber$filename" $ErrorInfo]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[mc "\033\[31;1mCompilation error\033\[m at \033\[31;1;4m%s\033\[m%s: %s" $LineNumber $filename $ErrorInfo]
			}
		}
	}

	## Report notice
	 # @parm Int LineNumber		- Number of line where it occurred
	 # @parm Int FileNumber		- Number of file where the error occurred, {} == unknown
	 # @parm String ErrorInfo	- Text of the notice
	 # @return void
	proc Notice {LineNumber FileNumber ErrorInfo} {
		variable working_dir	;# String: Current working directory
		variable included_files	;# List: Unique unsorted list of included files

		if {$FileNumber != {}} {
			set filename [lindex $included_files $FileNumber]
			if {![string first $working_dir $filename]} {
				set filename [string replace $filename 0 [string length $working_dir]]
			}
			if {[regexp {\s} $filename]} {
				set filename "\"$filename\""
			}
			set filename [mc " in %s" $filename]
		} else {
			set filename {}
		}
		if {${::Compiler::Settings::WARNING_LEVEL} < 1} {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[::Compiler::msgc {WL}][mc "Notice at %s: %s" "$LineNumber$filename" $ErrorInfo]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[mc "\033\[33;1mNotice\033\[m at \033\[33;1;4m%s\033\[m%s: %s" $LineNumber $filename $ErrorInfo]
			}
		}
	}

	## Report warning message
	 # @parm Int LineNumber		- Number of line where it occurred
	 # @parm Int FileNumber		- Number of file where the error occurred, {} == unknown
	 # @parm String ErrorInfo	- Text of the warning
	 # @return void
	proc Warning {LineNumber FileNumber ErrorInfo} {
		variable working_dir	;# String: Current working directory
		variable included_files	;# List: Unique unsorted list of included files
		variable idx		;# Current position in asm list
		variable warning_count	;# Number of warnings occurred

		# Increment warning counter
		incr warning_count

		# Adjust code listing
		CodeListing::Warning $idx $ErrorInfo

		# Report the warning
		if {$FileNumber != {}} {
			set filename [lindex $included_files $FileNumber]
			if {![string first $working_dir $filename]} {
				set filename [string replace $filename 0 [string length $working_dir]]
			}
			if {[regexp {\s} $filename]} {
				set filename "\"$filename\""
			}
			set filename [mc " in %s" $filename]
		} else {
			set filename {}
		}
		if {${::Compiler::Settings::WARNING_LEVEL} < 2} {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[::Compiler::msgc {WL}][mc "Warning at %s: %s" "$LineNumber$filename" $ErrorInfo]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[mc "\033\[33mWarning\033\[m at \033\[33;4m%s\033\[m%s: %s" $LineNumber $filename $ErrorInfo]
			}
		}
	}

	## Report error message -- syntax error (badly formatted input code)
	 # @parm Int LineNumber		- Number of line where the error occurred
	 # @parm Int FileNumber		- Number of file where the error occurred, {} == unknown
	 # @parm String ErrorInfo	- Error string
	 # @return void
	proc SyntaxError {LineNumber FileNumber ErrorInfo} {
		variable working_dir	;# String: Current working directory
		variable included_files	;# List: Unique unsorted list of included files
		variable idx		;# Current position in asm list
		variable error_count	;# Number of errors occurred
		variable ErrorAtLine	;# Bool: Error occurred on the current line
		variable Error		;# Bool: An error occurred during precompilation

		# Adjust NS variable
		incr error_count
		set ErrorAtLine	1
		set Error	1

		# Adjust code listing
		CodeListing::Error $idx $ErrorInfo

		# Report the error
		if {$FileNumber != {}} {
			set filename [lindex $included_files $FileNumber]
			if {![string first $working_dir $filename]} {
				set filename [string replace $filename 0 [string length $working_dir]]
			}
			if {[regexp {\s} $filename]} {
				set filename "\"$filename\""
			}
			set filename [mc " in %s" $filename]
		} else {
			set filename {}
		}
		if {${::Compiler::Settings::WARNING_LEVEL} < 3} {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[::Compiler::msgc {EL}][mc "Syntax error at %s: %s" "$LineNumber$filename" $ErrorInfo]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[mc "\033\[31;1mSyntax error\033\[m at \033\[31;1;4m%s\033\[m%s: %s" $LineNumber $filename $ErrorInfo]
			}
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

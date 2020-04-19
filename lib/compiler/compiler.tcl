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
if { ! [ info exists _COMPILER_TCL ] } {
set _COMPILER_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# 8051 COMPILER - BASE NAMESPACE
# --------------------------------------------------------------------------

# Include other parts
source "${::LIB_DIRNAME}/compiler/codelisting.tcl"	;# Code listing creator
source "${::LIB_DIRNAME}/compiler/assembler.tcl"	;# Assembler
source "${::LIB_DIRNAME}/compiler/disassembler.tcl"	;# Disassembler
source "${::LIB_DIRNAME}/compiler/preprocessor.tcl"	;# Preprocessor
source "${::LIB_DIRNAME}/compiler/compilerconsts.tcl"	;# Compiler constant definitons
source "${::LIB_DIRNAME}/compiler/external_compiler.tcl";# External compiler interface

namespace eval Compiler {
	variable error_count	;# Number of errors occurred during compilation
	variable warning_count	;# Number of warning reported during compilation

	variable in_IDE	0	;# Bool: Running in IDE (I mean GUI)

	# Procedure which do nothing (for better portability)
	proc doNothing args {}

	## Initiate compilation
	 # @parm String project_dir			- Project directory
	 # @parm String current_dir			- Current working directory
	 # @parm String input_file_name			- Name of input source code
	 # @parm String input_file_extension={}		- Extension of input file
	 # @return Bool - result
	proc compile {project_dir current_dir input_file_name {input_file_extension {}}} {
		variable error_count	;# Number of errors occurred during compilation
		variable warning_count	;# Number of warning reported during compilation

		# Compiler settings to defaults
		Compiler::Settings::restoreDefaults

		# Adjust compiler settings
		if {${::Compiler::Settings::_print} == 2} {
			set ::Compiler::Settings::PRINT 0
		} else {
			set ::Compiler::Settings::PRINT 1
		}
		if {${::Compiler::Settings::_object} == 2} {
			set ::Compiler::Settings::OBJECT 0
		} else {
			set ::Compiler::Settings::OBJECT 1
		}

		# Reset errors and warnings counters
		set error_count 0
		set warning_count 0

		# Set input filename and determinate time of start of compilation
		set Settings::INPUT_FILE_NAME $input_file_name
		set sec [clock seconds]

		# Adjust input file extension
		if {$input_file_extension != {}} {
			set input_file_extension ".$input_file_extension"
		}

		# Check for usability of the given input file
		set file [file join $current_dir $input_file_name$input_file_extension]

		# Open and read contents of the input file
		if {[catch {
			set asm [open $file r]
			set asm_data [read $asm]
			close $asm
		}]} then {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {EN}][mc "Unable to open the specified file. (%s)" $file]
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {EN}][mc "Compilation FAILED !"]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Unable to open the specified file. (\033\[34;1m%s\033\[m)" $file]
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "\033\[31;1mCompilation FAILED !\033\[m"]
			}
			return 0
		}

		# Initialize preprocessor
		if {!${::Compiler::Settings::QUIET}} {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					"\n\n[::Compiler::msgc {SN}][mc {Compiling file: %s}  $input_file_name$input_file_extension]"
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[mc "\n\nCompiling file: \033\[34;1m%s\033\[m" $input_file_name$input_file_extension]
			}
			${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
				[mc "Initializing pre-processor ..."]
		}
		set precompiledCode [PreProcessor::compile $current_dir $file $asm_data]
		set asm_data {}
		incr error_count ${::PreProcessor::error_count}
		incr warning_count ${::PreProcessor::warning_count}
		if {${::PreProcessor::error_count} > 0} {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {EN}][mc "Pre-processing FAILED !"]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "\033\[31;1mPre-processing FAILED !\033\[m"]
			}
			report_status $current_dir $input_file_name
			return 0
		}

		if {${::Compiler::Settings::ABORT_VARIABLE}} {return 0}

		# Initialize Assembler
		if {!${::Compiler::Settings::QUIET}} {
			${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Compiling ..."]
		}
		assembler::compile					\
			[md5::md5 -hex -file $file]			\
			[clock format [clock seconds] -format "%D"]	\
			$project_dir					\
			[file join $current_dir $input_file_name$input_file_extension]	\
			${::PreProcessor::included_files}		\
			$precompiledCode
		set ::PreProcessor::included_files {}
		incr error_count ${::assembler::error_count}
		if {${::assembler::error_count} > 0} {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [::Compiler::msgc {EN}][mc "Compilation FAILED !"]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "\033\[31;1mCompilation FAILED !\033\[m"]
			}
			report_status $current_dir $input_file_name
			return 0
		}

		if {${::Compiler::Settings::ABORT_VARIABLE}} {return 0}

		# Write resulting object code
		if {${::Compiler::Settings::OBJECT}} {
			if {${::Compiler::Settings::OBJECT_FILE} != {}} {
				set object_file ${::Compiler::Settings::OBJECT_FILE}
			} else {
				set object_file $input_file_name
				append object_file {.hex}
			}
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[mc "Creating IHEX8 ...\t\t\t-> \"%s\"" $object_file]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
				[mc "Creating IHEX8 ...\t\t\t-> \"\033\[34;1m%s\033\[m\"" $object_file]
			}
			makeBackupFile $current_dir $object_file
			if {[catch {
				set hex [open [file join $current_dir $object_file] w 0640]
			}]} then {
				if {${::Compiler::Settings::NOCOLOR}} {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[::Compiler::msgc {EN}][mc "Error: Unable to open file \"%s\" for writing" [file join $current_dir $object_file]]
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[::Compiler::msgc {EN}][mc "Compilation FAILED !"]
				} else {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "\033\[31;1mError\033\[m: Unable to open file \"\033\[34;1m%s\033\[m\" for writing" [file join $current_dir $object_file]]
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "\033\[31;1mCompilation FAILED !\033\[m"]
				}
				report_status $current_dir $input_file_name
				return 0
			} else {
				puts -nonewline $hex ${::assembler::hex}
				close $hex
			}
		}

		if {${::Compiler::Settings::ABORT_VARIABLE}} {return 0}

		# Write resulting binary object code
		if {${::Compiler::Settings::CREATE_BIN_FILE}} {
			if {!${::Compiler::Settings::QUIET}} {
				if {${::Compiler::Settings::NOCOLOR}} {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "Creating object file ...\t\t-> \"%s\"" "${input_file_name}.bin"]
				} else {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "Creating object file ...\t\t-> \"\033\[34;1m%s\033\[m\"" "${input_file_name}.bin"]
				}
			}

			makeBackupFile $current_dir "${input_file_name}.bin"
			if {[catch {
				set bin [open [file join $current_dir $input_file_name.bin] w 0640]
			}]} then {
				if {${::Compiler::Settings::NOCOLOR}} {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[::Compiler::msgc {EN}][mc "Error: Unable to open file \"%s\" for writing" [file join $current_dir $input_file_name.bin]]
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[::Compiler::msgc {EN}][mc "Compilation FAILED !"]
				} else {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "Error: Unable to open file \"\033\[34;1m%s\033\[m\" for writing" [file join $current_dir "${input_file_name}.bin"]]
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "\033\[31;1mCompilation FAILED !\033\[m"]
				}
				report_status $current_dir $input_file_name
				return 0
			} else {
				fconfigure $bin -translation binary
				puts -nonewline $bin ${::assembler::bin}
				close $bin
			}
			set bin_data {}
		}
		set hex_data {}

		if {${::Compiler::Settings::ABORT_VARIABLE}} {return 0}

		# Write simulator data file
		if {${::Compiler::Settings::CREATE_SIM_FILE}} {
			if {!${::Compiler::Settings::QUIET}} {
				if {${::Compiler::Settings::NOCOLOR}} {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "Creating assembler debug file ...\t-> \"%s\"" "${input_file_name}.adf"]
				} else {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "Creating simulator data file ...\t-> \"\033\[34;1m%s\033\[m\"" "${input_file_name}.adf"]
				}
			}
			makeBackupFile $current_dir "${input_file_name}.adf"
			if {[catch {
				set sim [open [file join $current_dir $input_file_name.adf] w 0640]
			}]} then {
				if {${::Compiler::Settings::NOCOLOR}} {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[::Compiler::msgc {EN}][mc "Error: Unable to open file \"%s]\" for writing" [file join $current_dir $input_file_name.adf]]
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[::Compiler::msgc {EN}][mc "Compilation FAILED !"]
				} else {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "\033\[31;1mError\033\[m: Unable to open file \"\033\[34;1m%s\033\[m\" for writing" [file join $current_dir $input_file_name.adf]]
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "\033\[31;1mCompilation FAILED !\033\[m"]
				}
				report_status $current_dir $input_file_name
				return 0
			} else {
				puts -nonewline $sim ${::assembler::adf}
				close $sim
			}
		}

		if {${::Compiler::Settings::ABORT_VARIABLE}} {return 0}

		# Report final status
		report_status $current_dir $input_file_name
		if {!${::Compiler::Settings::QUIET}} {
			if {${::Compiler::Settings::optim_ena}} {
				if {${::Compiler::Settings::NOCOLOR}} {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "Number of optimization performed: %s" ${::PreProcessor::optims}]
				} else {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[mc "Number of optimization performed: \033\[1m%s\033\[m" ${::PreProcessor::optims}]
				}
			}
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[::Compiler::msgc {SN}][mc "Compilation successful. (time: %s sec.)" [expr {[clock seconds] - $sec}]]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[mc "\033\[32;1mCompilation successful.\033\[m (time: %s sec.)" [expr {[clock seconds] - $sec}]]
			}
		}

		# Successful
		return 1
	}

	## Free resureces reserved during compilation
	 # @return void
	proc free_resources {} {
		::assembler::free_resources
		::CodeListing::free_resources
		set ::PreProcessor::asm {}
		set ::PreProcessor::tmp_asm {}
	}

	## Report final status and write code listing file
	 # @parm String current_dir	- Working directory
	 # @parm String input_file_name	- Name of input file
	 # @return void
	proc report_status {current_dir input_file_name} {
		variable error_count	;# Number of errors occurred during compilation
		variable warning_count	;# Number of warning reported during compilation

		# Determinate name of code listing file
		if {${::Compiler::Settings::PRINT_FILE} != {}} {
			set print_file ${::Compiler::Settings::PRINT_FILE}
		} else {
			set print_file $input_file_name
			append print_file {.lst}
		}

		# Message "Creating code listing file"
		if {!${::Compiler::Settings::QUIET} && ${::Compiler::Settings::PRINT}} {
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[mc "Creating code listing file ...\t\t-> \"%s\"" $print_file]
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
					[mc "Creating code listing file ...\t\t-> \"\033\[34;1m%s\033\[m\"" $print_file]
			}
		}

		# Report number of errors and warning
		if {!${::Compiler::Settings::QUIET}} {
			if {$::TRANSLATION_LOADED} {
				set text [mc "%s errors, %s warnings" $error_count $warning_count]
			} else {
				set text "$error_count error"
				if {$error_count != 1} {
					append text "s"
				}
				append text ", $warning_count warning"
				if {$warning_count != 1} {
					append text "s"
				}
			}
			if {${::Compiler::Settings::NOCOLOR}} {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} $text
			} else {
				${::Compiler::Settings::TEXT_OUPUT_COMMAND} "\033\[1m$text\033\[m"
			}
		}

		# Write code listing file
		if {${::Compiler::Settings::PRINT}} {
			makeBackupFile $current_dir $print_file
			if {[catch {
				set lst [open [file join $current_dir $print_file] w 0640]
			}]} then {
				if {${::Compiler::Settings::NOCOLOR}} {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[::Compiler::msgc {EN}][mc "Error: Unable to open file \"%s\" for writing" [file join $current_dir $print_file]]
					${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "Compilation FAILED !"]
				} else {
					${::Compiler::Settings::TEXT_OUPUT_COMMAND}	\
						[::Compiler::msgc {EN}][mc "Error: Unable to open file \"\033\[34;1m%s\033\[m\" for writing" [file join $current_dir $print_file]]
					${::Compiler::Settings::TEXT_OUPUT_COMMAND} [mc "\033\[31;1mCompilation FAILED !\033\[m"]
				}
				return 0
			} else {
				puts -nonewline $lst [CodeListing::getListing]
				close $lst
			}
		}
	}

	## Create backup copy of the specified file
	 # @parm String current_dir	- Working directory
	 # @parm String filename	- File name
	 # @parm String extension	- File extension
	 # @return void
	proc makeBackupFile {current_dir filename} {
		if {[file exists [file join $current_dir $filename]]} {
			catch {
				file rename -force	\
					[file join $current_dir $filename]	\
					"[file join $current_dir $filename]~"
			}
		}
	}

	## Namespace containing compiler settings
	namespace eval Settings {
		## Peephole optimization enable flag
		variable optim_ena		0	;# Bool: 0 == disabled; 1 == enabled

		## Memory limits
		variable iram_size		0x100	;# Internal data memory
		variable xram_size		0x10000	;# External data memory
		variable code_size 		0x10000	;# Overall program memory

		## Enable/Disable controls
		 # options:
		 #	0 - Controled by compiler
		 #	1 - Always
		 #	2 - Never
		variable _symbols		0	;# Control: $SYMBOLS
		variable _print			0	;# Control: $PRINT
		variable _object		0	;# Control: $OBJECT

		 # Options:
		 #	0 - use value defined in source code
		 #	1 - ignore
		variable _nomod			0	;# Control: $NOMOD
		variable _paging		0	;# Control: $PAGING
		variable _pagelength		0	;# Control: $PAGELENGTH(int)
		variable _pagewidth		0	;# Control: $PAGEWIDTH(int)
		variable _title			0	;# Control: $TITLE('string')
		variable _date			0	;# Control: $DATE('date')
		variable _list			0	;# Controls: $LIST $NOLIST; Directives: list nolist

		# Default values for some controls
		variable _object_file		{}	;# Location of IHEX8 object file
		variable _print_file		{}	;# Location of Code Listing file
		variable _title_value		{}	;# Title string for code listing
		variable _date_value		{}	;# Date string for code listing
		variable _nomod_value		0	;# Bool: use predefined SFR addresses
		variable _paging_value		0	;# Bool: Use Form Feeds in code listing
		variable _pagelength_value	0	;# Number of lines per page in code listing
		variable _pagewidth_value	132	;# Number of characters per line in code listing

		# Active settings
		variable SYMBOLS		{}	;# Bool: Include table of symbols to code listing
		variable NOMOD			{}	;# Bool: Do not use predefined SFR register addresses
		variable PAGING			{}	;# Bool: Use 'FF' in code listing
		variable PAGELENGTH		{}	;# Number of characters per line in code listing
		variable PAGEWIDTH		{}	;# Number of characters per line in code listing
		variable TITLE			{}	;# Title string for code listing
		variable DATE			{}	;# Date string for code listing
		variable OBJECT			{}	;# Bool: Generate IHEX8 object file
		variable OBJECT_FILE		{}	;# Location of IHEX8 object file
		variable PRINT			{}	;# Bool: Generate Code Listing file
		variable PRINT_FILE		{}	;# Location of Code Listing file
		variable INPUT_FILE_NAME	{}	;# Location of input file

		variable CREATE_SIM_FILE	1	;# Bool: Crete simulator data file
		variable CREATE_BIN_FILE	1	;# Bool: Create binary object code

		variable max_ihex_rec_length	16	;# Int: Maximum length of IHEX-8 record

		## Warning level
		 # 0 - all
		 # 1 - Errors + Warnings
		 # 2 - Errros only
		 # 3 - Nothing
		variable WARNING_LEVEL		0

		# Do not print what's going on
		variable QUIET			0
		# Update command (eg. 'update')
		variable UPDATE_COMMAND		{::Compiler::doNothing}
		# Bool: 1 == abort now
		variable ABORT_VARIABLE		0
		# Text output command (eg. 'puts')
		variable TEXT_OUPUT_COMMAND	{puts}
		# Disable color output
		variable NOCOLOR		1

		## Restore default settings
		 # @return void
		proc restoreDefaults {} {

			variable _symbols		;# Control: $SYMBOLS
			variable _print			;# Control: $PRINT
			variable _object		;# Control: $OBJECT

			variable SYMBOLS		;# Bool: Include table of symbols to code listing
			variable NOMOD			;# Bool: Do not use predefined SFR register addresses
			variable PAGING			;# Bool: Use 'FF' in code listing
			variable PAGELENGTH		;# Number of characters per line in code listing
			variable PAGEWIDTH		;# Number of characters per line in code listing
			variable TITLE			;# Title string for code listing
			variable DATE			;# Date string for code listing
			variable OBJECT			;# Bool: Generate IHEX8 object file
			variable OBJECT_FILE		;# Location of IHEX8 object file
			variable PRINT			;# Bool: Generate Code Listing file
			variable PRINT_FILE		;# Location of Code Listing file
			variable INPUT_FILE_NAME	;# Location of input file

			variable _object_file		;# Location of IHEX8 object file
			variable _print_file		;# Location of Code Listing file
			variable _title_value		;# Title string for code listing
			variable _date_value		;# Date string for code listing
			variable _nomod_value		;# Bool: use predefined SFR addresses
			variable _paging_value		;# Bool: Use Form Feeds in code listing
			variable _pagelength_value	;# Number of lines per page in code listing
			variable _pagewidth_value	;# Number of characters per line in code listing

			# Reset settings
			foreach	var {
					NOMOD		PAGING		PAGELENGTH		PAGEWIDTH
					TITLE		DATE		OBJECT_FILE		PRINT_FILE
				} default {
					_nomod_value	_paging_value	_pagelength_value	_pagewidth_value
					_title_value	_date_value	_object_file		_print_file
				} \
			{
				set $var [subst -nocommands "\$$default"]
			}

			# Finalize
			if {($_symbols == 1) || ($_symbols == 0)} {
				set SYMBOLS 1
			} elseif {$_symbols == 2} {
				set SYMBOLS 0
			}
			if {($_print == 1) || ($_print == 0)} {
				set PRINT 1
			} elseif {$_print == 2} {
				set PRINT 0
			}
			if {($_object == 1) || ($_object == 0)} {
				set OBJECT 1
			} elseif {$_object == 2} {
				set OBJECT 0
			}
		}
	}

	## Generate parser-friendly error code
	 # @parm String code - Basic message specification (e.g. EL means ERROR and LINE)
	 # @return Char - A special (unprintable) character represention the message
	proc msgc {code} {
		variable in_IDE		;# Bool: Running in IDE (I mean GUI)

		if {!$in_IDE} {
			return {}
		}

		switch -- $code {
			{EL} {	;# ERROR and LINE specification
				return "|EL|"
			}
			{EN}  {	;# Just ERROR
				return "|EN|"
			}
			{WL}  {	;# WARNING and LINE specification
				return "|WL|"
			}
			{WN}  {	;# Just WARNING
				return "|WN|"
			}
			{SN}  {	;# SUCCESS
				return "|SN|"
			}
		}
	}
}

# Compiler settings to defaults
Compiler::Settings::restoreDefaults

# >>> File inclusion guard
}
# <<< File inclusion guard

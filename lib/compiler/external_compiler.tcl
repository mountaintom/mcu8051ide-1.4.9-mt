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
if { ! [ info exists _EXTERNAL_COMPILER_TCL ] } {
set _EXTERNAL_COMPILER_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements interface to external compilers
# --------------------------------------------------------------------------

namespace eval ExternalCompiler {
	variable input_filename	;# String: Name of file to compile (without extension)
	variable compiler_used	;# Int: Compiler ID (1 == ASEM-51; 2 == ASL; 3 == AS31, other values have no meaning)
	variable project_dir	;# String: Project directory
	variable working_dir	;# String: Compiler working directory
	variable input_file_base;# String: Full file name of the primary source file

	## Int: Preffered assembler
	 # 0 - Native MCU 8051 IDE assembler
	 # 1 - ASEM-51
	 # 2 - ASL
	 # 3 - AS31
	variable selected_assembler	0
	variable selected_assembler_def	0	;# Int: Default value for $selected_assembler

	#
	## External assembler configuration
	#

	## ASEM-51
	 # Default ASEM-51 assembler configuration
	variable assembler_ASEM51_config_def {
		--omf-51	0
		--columns	0
		--verbose	1
		-i		{}
		custom		{}
	}
	 # Current ASEM-51 assembler configuration
	variable assembler_ASEM51_config
	 # Default ASEM-51 additional configuration
	variable assembler_ASEM51_addcfg_def {
		adf		1
	}
	 # Current ASEM-51 additional configuration
	variable assembler_ASEM51_addcfg

	## ASL
	 # Array: ASL additional configuration
	variable assembler_ASL_addcfg
	 # Default ASL assembler configuration
	variable assembler_ASL_config_def {
		-A	0		-a	0
		-C	0		-c	0
		-h	0		-I	1
		-L	1		-M	0
		-P	0		-n	0
		-quiet	0		-s	1
		-u	0		-U	0
		-w	0		-x	0

		-r	{}		-i	{}
		-g	{MAP}		-cpu	{8051}
		custom	{}
	}
	 # Current ASL assembler configuration
	variable assembler_ASL_config
	 # Default ASL additional configuration
	variable assembler_ASL_addcfg_def {
		ihex		1
		adf		1
	}
	 # Current ASL additional configuration
	variable assembler_ASL_addcfg

	## AS31
	 # Array: AS31 additional configuration
	variable assembler_AS31_addcfg
	 # Default AS31 assembler configuration
	variable assembler_AS31_config_def {
		-l	1		-F	{hex}
		-A	{}		custom	{}
	}
	 # Current AS31 assembler configuration
	variable assembler_AS31_config
	 # Default AS31 additional configuration
	variable assembler_AS31_addcfg_def {
		adf		1
	}
	 # Current ASL additional configuration
	variable assembler_AS31_addcfg

	## SDCC
	 # Default SDCC boolean options
	variable sdcc_bool_options_def {
		--verbose			1
		-V				1
		-S				0
		--compile-only			0
		--preprocessonly		0
		--c1mode			0
		--print-search-dirs		0
		--use-stdout			0
		--nostdlib			0
		--nostdinc			0
		--less-pedantic			0
		--debug				1
		--cyclomatic			0
		--fdollars-in-identifiers	0
		--funsigned-char		0
		--xstack			0
		--int-long-reent		0
		--float-reent			0
		--main-return			0
		--xram-movc			0
		--profile			0
		--fommit-frame-pointer		0
		--all-callee-saves		0
		--stack-probe			0
		--parms-in-bank1		0
		--no-xinit-opt			0
		--no-c-code-in-asm		0
		--no-peep-comments		0
		--fverbose-asm			0
		--short-is-8bits		0
		--stack-auto			0
		--nooverlay			1
		--nogcse			0
		--nolabelopt			0
		--noinvariant			0
		--noinduction			1
		--nojtbound			0
		--noloopreverse			0
		--no-peep			0
		--no-reg-params			0
		--peep-asm			0
		--opt-code-speed		0
		--opt-code-size			0
		--out-fmt-ihx			0
		--out-fmt-s19			0
	}
	 # Current SDCC boolean options
	variable sdcc_bool_options
	 # Default SDCC string options
	variable sdcc_string_options_def {
		model		--model-small
		standard	--std-sdcc89
		stack           {}
		custom		{}
	}
	 # Current SDCC string options
	variable sdcc_string_options
	 # Default SDCC optional string options
	variable sdcc_optional_string_options_def {
		--codeseg	{}
		--constseg	{}
		--lib-path	{}
		--xram-loc	{}
		--xstack-loc	{}
		--code-loc	{}
		--stack-loc	{}
		--data-loc	{}
		--stack-size	{}
	}
	 # Current SDCC optional string options
	variable sdcc_optional_string_options
	 # Default semicolon separated optional string options
	variable sdcc_scs_string_options_def {
		-I			{}
		-l			{}
		-L			{}
		--disable-warning	{}
	}
	 # Current semicolon separated optional string options
	variable sdcc_scs_string_options

	## Make utility
	 # General options, this is an array!
	variable makeutil_config
	 # Default values for the eneral options
	variable makeutil_config_def {
		c_ena	0
		c_file	{}
		co_file	{}
		ct_file	{}
	}

	## Make backup copies for files with the given extensions and remove original files
	 # (input_filename.extension -> input_filename.extension~)*
	 # @parm List suffixes - List of file extensions (e.g. {asm c h})
	 # @return void
	proc backup_and_remove {suffixes} {
		variable input_filename	;# String: Name of file to compile (without extension)

		foreach ext $suffixes {
			catch {
				file rename -force -- "$input_filename.$ext" "$input_filename.$ext~"
			}
		}
	}

	## Start SDCC (ANSI C compiler)
	 # @parm String work_dir	- Current working directory
	 # @parm String input_file	- C source file to compile
	 # @parm Int iram		- Amount of internal data memory
	 # @parm Int xram		- Amount of external data memory
	 # @parm Int code		- Amount of overall program memory
	 # @return Int - Compiler PID
	proc compile_C {work_dir input_file iram xram code} {
		variable input_filename	;# String: Name of file to compile (without extension)
		variable compiler_used	;# Int: Compiler ID (1 == ASEM-51; 2 == ASL; 3 == AS31, other values have no meaning)
		variable makeutil_config;# Make utility - general options

		set compiler_used 0
		set input_filename [file rootname $input_file]
		backup_and_remove {asm cdb ihx}
		set sdcc_opts [determinate_sdcc_options]
		if {${::PROGRAM_AVAILABLE(sdcc-sdcc)}} {
			set sdcc_cmd {sdcc-sdcc}
		} else {
			set sdcc_cmd {sdcc}
		}

		# Normal way (POSIX)
		if {!$::MICROSOFT_WINDOWS} {
			# Start GNU make
			if {$makeutil_config(c_ena) && ${::PROGRAM_AVAILABLE(make)}} {
				::X::messages_text_append [::Compiler::msgc {S}][mc "\n\nStarting make ..."]
				::X::messages_text_append "\ncd \"${work_dir}\"\nmake -f \"${makeutil_config(c_file)}\" ${makeutil_config(co_file)} ${makeutil_config(ct_file)}"

			# Start SDCC
			} else {
				::X::messages_text_append [::Compiler::msgc {S}][mc "\n\nStarting compiler ..."]
				::X::messages_text_append "\ncd \"${work_dir}\"\n${sdcc_cmd} -mmcs51 --iram-size ${iram} --xram-size ${xram} --code-size ${code} ${sdcc_opts} \"${input_file}\""
			}
		# Microsoft Windows way
		} else {
			regsub -all {/} $work_dir "\\\\\\\\" work_dir
			regsub -all {/} $input_file "\\\\\\\\" input_file

			::X::messages_text_append [::Compiler::msgc {S}][mc "\n\nStarting compiler ..."]
			::X::messages_text_append "\ncd \"${work_dir}\"\n${sdcc_cmd} -mmcs51 --iram-size ${iram} --xram-size ${xram} --code-size ${code} ${sdcc_opts} \"${input_file}\""
		}
		if {[catch {
			cd $work_dir
		}]} then {
			::X::messages_text_append [::Compiler::msgc {E}][mc "\nError: Unable to change working directory to '%s'" $work_dir]
		}
		if {!$::MICROSOFT_WINDOWS} {	;# Normal way (POSIX)
			# Start GNU make
			if {$makeutil_config(c_ena) && ${::PROGRAM_AVAILABLE(make)}} {
				return [exec -- /bin/sh -c "make -f \"${makeutil_config(c_file)}\" ${makeutil_config(co_file)} ${makeutil_config(ct_file)}" |&	\
						tclsh "${::LIB_DIRNAME}/external_command.tcl"		\
						[tk appname]						\
						{::ExternalCompiler::ext_compilation_complete 1}	\
						::X::compilation_message &				\
				]

			# Start SDCC
			} else {
				return [exec -- /bin/sh -c "$sdcc_cmd -mmcs51	\
					--iram-size $iram			\
					--xram-size $xram			\
					--code-size $code 			\
					$sdcc_opts \"$input_file\"" |&		\
						tclsh "${::LIB_DIRNAME}/external_command.tcl"	\
						[tk appname]					\
						{::ExternalCompiler::ext_compilation_complete 1}\
						::X::compilation_message &			\
				]
			}
		} else { ;# Microsoft Windows way
			eval [subst -nocommands {
				return [exec -- "${::INSTALLATION_DIR}/startsdcc.bat"		\
					"${work_dir}"						\
					$sdcc_opts						\
					"${input_file}"						\
						|&						\
					"${::INSTALLATION_DIR}/external_command.bat"		\
					"${::INSTALLATION_DIR}/external_command.exe"		\
					"[tk appname]"						\
					{::ExternalCompiler::ext_compilation_complete 1}	\
					::X::compilation_message &				\
				]
			}]
		}
	}

	## Start AS31 (Assembler)
	 # @parm String work_dir		- Current working directory
	 # @parm String input_file		- Assembler source file to compile
	 # @parm String project_directory	- Project directory (for debug file)
	 # @return Int - Compiler PID
	proc as31_compile {work_dir input_file project_directory} {
		variable project_dir	;# String: Project directory
		variable compiler_used	;# Int: Compiler ID (1 == ASEM-51; 2 == ASL; 3 == AS31, other values have no meaning)
		variable input_filename	;# String: Name of file to compile (without extension)
		variable working_dir	;# String: Compiler working directory
		variable input_file_base;# String: Full file name of the primary source file
		global argv

		set compiler_used 3
		set project_dir $project_directory
		set input_file_base [file normalize [file join $work_dir $input_file]]
		set input_filename [file rootname $input_file_base]
		set working_dir $work_dir

		set as31_options [determinate_as31_options]
		::X::messages_text_append [::Compiler::msgc {S}][mc "\n\nStarting compiler ..."]
		::X::messages_text_append "\ncd \"$work_dir\"\nas31 $as31_options \"$input_file\""
		if {[catch {
			cd $work_dir
		}]} then {
			::X::messages_text_append [::Compiler::msgc {E}][mc "\nError: Unable to change working directory to '%s'" $work_dir]
		}
		backup_and_remove {adf hex lst}

		return [exec -- /bin/sh -c "as31 $as31_options \"$input_file\"" |&	\
			tclsh "${::LIB_DIRNAME}/external_command.tcl" "[tk appname]"	\
			::ExternalCompiler::ext_compilation_complete ::X::compilation_message &	\
		]
	}

	## Start ASEM-51 (Assembler)
	 # @parm String work_dir		- Current working directory
	 # @parm String input_file		- Assembler source file to compile
	 # @parm String project_directory	- Project directory (for debug file)
	 # @return Int - Compiler PID
	proc asem51_compile {work_dir input_file project_directory} {
		variable project_dir	;# String: Project directory
		variable compiler_used	;# Int: Compiler ID (1 == ASEM-51; 2 == ASL; 3 == AS31, other values have no meaning)
		variable input_filename	;# String: Name of file to compile (without extension)
		variable working_dir	;# String: Compiler working directory
		variable input_file_base;# String: Full file name of the primary source file
		global argv

		set compiler_used 1
		set project_dir $project_directory
		set input_file_base [file normalize [file join $work_dir $input_file]]
		set input_filename [file rootname $input_file_base]
		set working_dir $work_dir

		::X::messages_text_append [::Compiler::msgc {S}][mc "\n\nStarting compiler ..."]

		set asem51_options [determinate_asem51_options]
		if {$::MICROSOFT_WINDOWS} {
			regsub -all -- {--verbose} $asem51_options {} asem51_options
			regsub -all -- {--} $asem51_options {/} asem51_options
			regsub -all -- {=} $asem51_options {:} asem51_options
			regsub -all -- {;} $asem51_options { /includes:} asem51_options
			regsub -all {/} $work_dir "\\\\\\\\" work_dir
			regsub -all {/} $input_file "\\\\\\\\" input_file
			::X::messages_text_append "\ncd \"$work_dir\"\nasem \"$input_file\" $asem51_options"
		} else {
			::X::messages_text_append "\ncd \"$work_dir\"\nasem $asem51_options \"$input_file\""
		}
		if {[catch {
			cd $work_dir
		}]} then {
			::X::messages_text_append [::Compiler::msgc {E}][mc "\nError: Unable to change working directory to '%s'" $work_dir]
		}
		backup_and_remove {adf hex lst omf}

		if {!$::MICROSOFT_WINDOWS} {	;# Normal way (POSIX)
			return [exec -- /bin/sh -c "asem $asem51_options \"$input_file\"" |&	\
				tclsh "${::LIB_DIRNAME}/external_command.tcl" "[tk appname]"	\
				::ExternalCompiler::ext_compilation_complete ::X::compilation_message &	\
			]
		} else { ;# Microsoft Windows way
			eval [subst -nocommands {
				return [exec -- "${::INSTALLATION_DIR}/startasem.bat"		\
					"${work_dir}"						\
					"${input_file}"						\
					$asem51_options						\
						|&						\
					"${::INSTALLATION_DIR}/external_command.bat"		\
					"${::INSTALLATION_DIR}/external_command.exe"		\
					"[tk appname]"						\
					{::ExternalCompiler::ext_compilation_complete 1}	\
					::X::compilation_message &				\
				]
			}]
		}
	}

	## Start ASL (Assembler)
	 # @parm String work_dir		- Current working directory
	 # @parm String input_file		- Assembler source file to compile
	 # @parm String project_directory	- Project directory (for debug file)
	 # @return Int - Compiler PID
	proc asl_compile {work_dir input_file project_directory} {
		variable project_dir		;# String: Project directory
		variable compiler_used		;# Int: Compiler ID (1 == ASEM-51; 2 == ASL; 3 == AS31, other values have no meaning)
		variable input_filename		;# String: Name of file to compile (without extension)
		variable assembler_ASL_addcfg	;# Current ASL additional configuration
		global argv

		set compiler_used 2
		set project_dir $project_directory
		set input_filename [file join $work_dir [file rootname $input_file]]
		backup_and_remove {hex lst map adf}
		set asl_opts [determinate_asl_options]
		set additional_commands {}
		if {$assembler_ASL_addcfg(ihex)} {
			append additional_commands {&& p2hex "} $input_filename.p {" "} $input_filename.hex {"}
		}

		::X::messages_text_append [::Compiler::msgc {S}][mc "\n\nStarting compiler ..."]
		::X::messages_text_append "\ncd \"$work_dir\"\nasl $asl_opts \"$input_file\""
		if {[catch {
			cd $work_dir
		}]} then {
			::X::messages_text_append [::Compiler::msgc {E}][mc "\nError: Unable to change working directory to '%s'" $work_dir]
		}
		return [exec -- /bin/sh -c "asl $asl_opts \"$input_file\" $additional_commands" |&	\
			tclsh "${::LIB_DIRNAME}/external_command.tcl" "[tk appname]"	\
			::ExternalCompiler::ext_compilation_complete ::X::compilation_message &	\
		]
	}

	## Create file containg MD5 hashes of source files
	 # Suitable for C language only!
	 # This file will be later used to chech wheter any of these files was changed or not.
	 # @return void
	proc create_hashes_file {} {
		variable input_filename		;# String: Name of file to compile (without extension)

		# List of files included files in the main file
		set included_files [list]

		set cbd_file {}	;# We will set this variable later ...

		# Open C DeBug file generated by SDCC compiler
		if {[catch {
			set cdb_file [open $input_filename.cdb r]
		}]} then {
			::X::messages_text_append [::Compiler::msgc {E}][mc "\nUnable to find \"%s\"" [file rootname $input_filename].cdb]
			return
		}

		# Open the hashes file for writing (possibly create the file)
		if {[catch {
			set hs_file [open $input_filename.hashes w 0640]
		}]} then {
			::X::messages_text_append [::Compiler::msgc {E}][mc "\nUnable to create \"%s\"" [file rootname $input_filename].hashes]
			catch {close $cbd_file}
			return
		}

		# Iterate over lines in the C DeBug file and list all included source files
		while {![eof $cdb_file]} {
			set line [gets $cdb_file]

			if {[string first {L:C$} $line]} {
				continue
			}

			set line [string replace $line 0 3]
			set line [string replace $line [string first {$} $line] end]

			if {[lsearch -ascii -exact $included_files $line] == -1} {
				lappend included_files $line
			}
		}

		# Compute MD5 hash for each of the included files
		foreach filename $included_files {
			catch {
				puts $hs_file "[::md5::md5 -hex -file $filename] \"$filename\" "
			}
		}

		# Clean up
		catch {close $cdb_file}
		catch {close $hs_file}
	}

	## This function must be called after exteral compiler finished its work
	 # @parm Int action=0 - Action to perform after successfull compilation
	 #	0 - No action
	 #	1 - Copy <file>.ihx to <file>.hex
	 # @return void
	proc ext_compilation_complete {{action 0}} {
		variable input_filename		;# String: Name of file to compile (without extension)
		variable compiler_used		;# Int: Compiler ID (1 == ASEM-51; 2 == ASL; 3 == AS31, other values have no meaning)
		variable assembler_ASEM51_addcfg;# Current ASEM-51 assembler configuration
		variable assembler_ASL_addcfg	;# Current ASL additional configuration
		variable assembler_AS31_addcfg	;# Current AS31 additional configuration

		# Compilation successfull
		if {$::X::compilation_successfull} {

			# Create MCU 8051 IDE assembler debug file -
			switch -- $compiler_used {
				1 {	;# - from ASEM-51 code listing (*.lst)
					if {$assembler_ASEM51_addcfg(adf) && ![asem_51_analyze]} {
						::X::messages_text_append [::Compiler::msgc {E}][mc "\nUnable to find \"%s\"\n\tMCU 8051 IDE debug file (*.adf) could not be generated\n\tPLEASE CHECK YOUR %s CONFIGURATION" [file rootname $input_filename].lst {ASEM-51}]
					}
				}
				2 {	;# - from ASL native debug file (*.map)
					if {$assembler_ASL_addcfg(adf) && ![asl_analyze]} {
						::X::messages_text_append [::Compiler::msgc {E}][mc "\nUnable to find \"%s\"\n\tMCU 8051 IDE debug file (*.adf) could not be generated\n\tPLEASE CHECK YOUR %s CONFIGURATION" [file rootname $input_filename].map {ASL}]
					}
				}
				3 {	;# - from AS31 code listing file (*.lst)
					if {$assembler_ASL_addcfg(adf) && ![as31_analyze]} {
						::X::messages_text_append [::Compiler::msgc {E}][mc "\nUnable to find \"%s\"\n\tMCU 8051 IDE debug file (*.adf) could not be generated\n\tPLEASE CHECK YOUR %s CONFIGURATION" [file rootname $input_filename].lst {AS31}]
					}
				}
				0 {	;# SDCC used: Create .hashes file from .cdb file
					create_hashes_file
				}
			}

			if {$::X::compilation_successfull} {
				::X::messages_text_append [::Compiler::msgc {S}][mc "\nCompilation successful"]
			}

			# Perform specified after successfull compilation
			switch -- $action {
				0 {	;# No action
				}
				1 {	;# Copy <file>.ihx to <file>.hex
					catch {
						file rename -force -- "$input_filename.hex" "$input_filename.hex~"
					}
					catch {
						file copy -force -- "$input_filename.ihx" "$input_filename.hex"
					}
				}
			}
		}

		# Compilation failed
		if {!$::X::compilation_successfull} {
			::X::messages_text_append [::Compiler::msgc {E}][mc "\nCompilation FAILED"]
		}
		::X::ext_compilation_complete
	}

	## Create MCU 8051 IDE assembler debug file from AS31 code listing
	 # @return Bool - 1 == success; 0 == failure
	proc as31_analyze {} {
		variable project_dir	;# String: Project directory
		variable working_dir	;# String: Compiler working directory
		variable input_filename	;# String: Name of file to compile (without extension)
		variable input_file_base;# String: Full file name of the primary source file

		# Local variables
		set line_number		0	;# Line number in LST file
		set adf_line		0	;# Line number to record in ADF file
		set adf_code		{}	;# Processor code in decimal representation (for ADF file)
		set address		{}	;# Address in code memory
		set processor_code	{}	;# Processor code read from LST file

		# Try to open code listing file and some tempotary debug file
		if {[catch {
			set lst_file [open $input_filename.lst r]
			set adf_file [open $input_filename.adf w 0640]
		} result]} then {
			::X::messages_text_append [::Compiler::msgc {E}][mc "File access error:\n%s" $result]
			return 0
		}

		# Write file header
		puts $adf_file "# Assembler Debug File created by ${::APPNAME}"
		puts $adf_file "# Used assembler: AS31"

		# Write MD5 of the source file
		puts -nonewline $adf_file [::md5::md5 -hex -file $input_file_base]
		puts -nonewline $adf_file { }
		puts -nonewline $adf_file [string replace $input_file_base 0 [string length $project_dir]]

		# One pass compilation LST -> ADF
		while {![eof $lst_file]} {
			incr line_number

			# Read one line from the code listing
			set line [string range [gets $lst_file] 0 17]

			# Lines which does not contain address or code will be ignored
			#+ but line number counter must be still incremented on these lines
			if {[regexp {^\s*$} $line]} {
				continue
			}

			set address [string trim [string range $line 0 3]]
			set code [string trim [string range $line 6 17]]

			# If there is no processor code then skip the line
			if {$code == {}} {
				continue
			}

			# Convert processor code to format suitable for this application,
			#+ that means convert list of HH to list of DDD
			if {[catch {
				set adf_code {}
				foreach h $code {
					scan $h %x h
					lappend adf_code $h
				}
			}]} then {
				::X::messages_text_append [::Compiler::msgc {E}][mc "Unable to understand formulation at %s in file %s" $line_number $input_filename.lst]
				close $lst_file
				close $adf_file
				return 0
			}

			# If there is no address then append the current code to the last ADF record
			if {$address == {}} {
				puts -nonewline $adf_file { }
				puts -nonewline $adf_file $adf_code
			} else {
				if {[catch {
					scan $address %x address
				}]} then {
					::X::messages_text_append [::Compiler::msgc {E}][mc "Unable to understand formulation at %s in file %s" $line_number $input_filename.lst]
					close $lst_file
					close $adf_file
					return 0
				}
				set adf_line $line_number

				puts -nonewline $adf_file "\n0 $adf_line $address $adf_code"
			}
		}

		# Close all files and finalize ...
		puts $adf_file {}
		close $lst_file
		close $adf_file
		return 1
	}

	## Create MCU 8051 IDE assembler debug file from ASEM-51 code listing
	 # @return Bool - 1 == success; 0 == failure
	proc asem_51_analyze {} {
		variable project_dir	;# String: Project directory
		variable working_dir	;# String: Compiler working directory
		variable input_filename	;# String: Name of file to compile (without extension)
		variable input_file_base;# String: Full file name of the primary source file

		# Local variables
		array set line_number	{}	;# Array of Int: Line number within certain inslusion level
		set inclusion_level	0	;# Int: Current inclusion level
		set file_number		0	;# Int: Current file number (number of included file in $included_files)
		set file_number_changed	0	;# Bool: Next line includes new file
		set address		0	;# Int(H|D): Address in machine code
		set code		{}	;# List of Int(H|D): Machine code
		set included_files	[list $input_file_base]	;# List of all included files (unique, unsorted)

		# Try to open code listing file and some tempotary debug file
		if {[catch {
			set lst_file [open $input_filename.lst r]
			set adf_file [open $input_filename._adf w 0640]
		} result]} then {
			::X::messages_text_append [::Compiler::msgc {E}][mc "File access error:\n%s" $result]
			return 0
		}

		# Initialize line number counter
		for {set i 0} {$i < 100} {incr i} {
			set line_number($i) 0
		}

		# One pass compilation LST -> ADF
		while {![eof $lst_file]} {
			# Read 1 line
			set line [gets $lst_file]

			# Normal line corresponding to certain line in source code
			if {[regexp {^ *\d+:(..)?} $line inclusion_level]} {
				# Extract numbers after "line_num: inc_lvl "
				set line [string range $line [string length $inclusion_level] end]
				regexp {^[0-9a-fA-F\s]+} $line code

				# Determinate address and machine code
				set address [lindex $code 0]
				set code [lrange $code 1 end]

				# Determinate inclusion level
				set inclusion_level [string trim [string range $inclusion_level end-1 end]]
				if {$inclusion_level == {} || [string index $inclusion_level end] == {:}} {
					set inclusion_level 0
					set file_number 0
				}
				incr line_number($inclusion_level)

			# Continuation of previous unfinished line
			} elseif {![string first {	  } $line]} {
				set address [lindex $line 0]
				set code [lrange $line 1 end]

			# Other lines
			} else {
				continue
			}

			# Detect directive "$INCLUDE(file)"
			if {[regexp -nocase -- {.*\$include\s*\([^\(\)]+\)} $line line]} {
				regsub {;.+$} $line {} line
				set line [string trim $line]
				regexp -nocase --  {\$include\s*\([^\(\)]+\)} $line line
				if {$line == {}} {
					continue
				}
				set line [string replace $line 0 7]
				set line [string trim $line {( )}]
				set line [file normalize [file join $working_dir $line]]
				set file_number_changed 1
				set file_number [lsearch -ascii -exact $included_files $line]
				if {$file_number == -1} {
					set file_number [llength $included_files]
					lappend included_files $line
				}
				continue
			}

			# Next file included -> Reset lines counter
			if {$file_number_changed} {
				set line_number($inclusion_level) 1
				set file_number_changed 0
			}

			# Convert machine code from hexadecimal to decimal value
			set code_dec {}
			foreach byte $code {
				if {[string length $byte] != 2 || ![string is xdigit -strict $byte]} {
					break
				}
				scan $byte %x byte
				lappend code_dec $byte
			}

			# Machine code must not be empty
			if {$code_dec == {}} {continue}

			# Check for valid address
			if {[string length $address] != 4 || ![string is xdigit -strict $address]} {
				continue
			}

			# Write line to tempotary debug file
			scan $address %x address
			puts -nonewline $adf_file [list $file_number $line_number($inclusion_level) $address]
			puts -nonewline $adf_file { }
			puts $adf_file $code_dec
		}
		close $adf_file

		# Open final debug file
		if {[catch {
			set adf_file [open $input_filename.adf w 0640]
		} result]} then {
			::X::messages_text_append [::Compiler::msgc {E}][mc "File access error:\n%s" $result]
			return 0
		}
		# Write file header
		puts $adf_file "# Assembler Debug File created by ${::APPNAME}"
		puts $adf_file "# Used assembler: ASEM-51"
		# Create list of included files with MD5 hashes
		set hashes_and_files {}
		set project_dir_len [string length $project_dir]
		foreach filename $included_files {
			if {[catch {
				lappend hashes_and_files [::md5::md5 -hex -file $filename]
			} result]} then {
				lappend hashes_and_files 0
				::X::messages_text_append [::Compiler::msgc {E}][mc "File access error:\n%s" $result]
			}
			if {![string first $project_dir $filename]} {
				set filename [string replace $filename 0 $project_dir_len]
			}
			lappend hashes_and_files $filename
		}
		# Write list of included files
		puts $adf_file $hashes_and_files
		# Copy content of tempotary debug file to final debug file
		if {[catch {
			set adf__file [open $input_filename._adf r]
		} result]} then {
			::X::messages_text_append [::Compiler::msgc {E}][mc "File access error:\n%s" $result]
			return 0
		}
		while {![eof $adf__file]} {
			puts $adf_file [gets $adf__file]
		}

		# Close all files and delete tempotary file
		close $adf__file
		close $lst_file
		close $adf_file
		file delete -force $input_filename._adf
		return 1
	}

	## Create MCU 8051 IDE assembler debug file from ASL code listing
	 # @return Bool - 1 == success; 0 == fail
	proc asl_analyze {} {
		variable project_dir	;# String: Project directory
		variable input_filename	;# String: Name of file to compile (without extension)

		# Try to open all required files
		if {[catch {
			set map_file [open $input_filename.map r]	;# ASL debug file
			set hex_file [open $input_filename.hex r]	;# Machine code
			set adf_file [open $input_filename.adf w 0640]	;# MCU 8051 IDE debug file
		} result]} then {
			::X::messages_text_append [::Compiler::msgc {E}][mc "File access error:\n%s" $result]
			return 0
		}

		# Load machine code
		::IHexTools::free_resources
		if {![::IHexTools::load_hex_data [read $hex_file]]} {
			::X::messages_text_append [::Compiler::msgc {E}][mc "Compilation error:\nFile \"%s\" is not a valid Intel® HEX 8 file" $input_filename.hex]
			return 0
		}
		close $hex_file

		# Initialize local variables
		set filenames		{}
		set hashes_and_files	{}
		set filename		{}
		set project_dir_len	[string length $project_dir]
		set read_values		0

		## 1st pass
		 # Determinate list of included files (and list of files and MD5 hashes)
		while {![eof $map_file]} {
			# Get significant line from the code
			set line [gets $map_file]
			if {$line == {Segment CODE}} {
				set read_values 1
				continue
			}
			if {$line == {}} {
				break
			}
			if {!$read_values} {
				continue
			}

			# Ignore lines which doesn't start with "File "
			if {[string first {File } $line]} {
				continue
			}

			# Determinate raw name of included file
			set filename [string replace $line 0 4]

			# Adjust list of included files
			if {[lsearch $filenames $filename] != -1} {
				lappend filenames $filename
				continue
			}

			# Determinate final file name and its MD5 hash
			lappend filenames $filename
			set filename [file join $project_dir [file normalize $filename]]
			if {[catch {
				lappend hashes_and_files [::md5::md5 -hex -file $filename]
			} result]} then {
				::X::messages_text_append [::Compiler::msgc {E}][mc "\nFile access error:\n%s" $result]
				lappend hashes_and_files {0}
			}
			if {![string first $project_dir $filename]} {
				set filename [string replace $filename 0 $project_dir_len]
			}

			# Adjust list of files and MD5 hashes
			lappend hashes_and_files $filename
			continue
		}

		# Create ADF file header
		seek $map_file 0
		puts $adf_file "# Assembler Debug File created by ${::APPNAME}"
		puts $adf_file "# Used assembler: ASL"
		puts $adf_file $hashes_and_files
		unset hashes_and_files

		## 2nd (final) pass
		 # Create ADF (Assembler Debug File)
		set last_line		-1	;#
		set last_address	-1	;#
		set last_file_num	0	;#
		set line_number		0	;#
		set file_number		0	;#
		set read_values		0	;#
		while {![eof $map_file]} {
			# Get significant line from the code
			set line [gets $map_file]
			if {$line == {Segment CODE}} {
				set read_values 1
				continue
			}
			if {$line == {}} {
				break
			}
			if {!$read_values} {
				continue
			}

			# Change file number
			if {![string first {File } $line]} {
				set file_number [lsearch $filenames [string replace $line 0 4]]
				continue
			}

			# Create ADF record(s)
			foreach item $line {
				# Determinate line number and address
				set item [split $item {:}]
				set line_number [lindex $item 0]
				scan [lindex $item 1] %x address

				# Handle firts record (first of all)
				if {$last_line == -1} {
					set last_line $line_number
					set last_address $address
					set last_file_num $file_number
					continue
				}

				# Write record
				write_to_adf_from_hex $adf_file $last_address	\
					[expr {$address - 1}] $last_line $last_file_num
				set last_line $line_number
				set last_address $address
				set last_file_num $file_number
			}
		}

		# Write last record (last of all)
		if {$last_line != -1} {
			write_to_adf_from_hex $adf_file $last_address	\
				${::IHexTools::highest_addr}	\
				$last_line $last_file_num
		}

		# Clean up
		::IHexTools::free_resources
		close $map_file
		close $adf_file
		return 1
	}

	## Write record to MCU 8051 IDE assembler debug file (*.adf)
	 # Auxiliary procedure for procedure asl_analyze
	 # @parm Chanel adf_file	- Target file
	 # @parm Int start_address	- Starting address in machine code
	 # @parm Int end_address	- End address in machine code
	 # @parm Int linenum		- Line number
	 # @parm Int filenum		- File number (ID of included file)
	 # @return void
	proc write_to_adf_from_hex {adf_file start_address end_address linenum filenum} {
		# Get machine code from NS ::IHexTools
		set code {}
		for {set i $start_address} {$i <= $end_address} {incr i} {
			set val [::IHexTools::get_value $i]
			if {$val > -1} {
				lappend code [expr "0x$val"]
			} else {
				lappend code 0
			}
		}

		# Write to file
		if {$linenum == {}} {
			set linenum 0
		}
		puts -nonewline $adf_file [list $filenum $linenum $start_address]
		puts -nonewline $adf_file { }
		puts $adf_file $code
	}

	## Determinate CLI options for external compiler sdcc
	 # @return String - Options for sdcc
	proc determinate_sdcc_options {} {
		variable sdcc_bool_options		;# Default SDCC boolean options
		variable sdcc_string_options		;# Default SDCC string options
		variable sdcc_optional_string_options	;# Default SDCC optional string options
		variable sdcc_scs_string_options	;# Default semicolon separated optional string options

		set result {}

		# Boolean options
		foreach key [array names sdcc_bool_options] {
			if {$sdcc_bool_options($key)} {
				append result { } $key
			}
		}

		# String options
		foreach key [array names sdcc_string_options] {
			append result { } [regsub -all {\n} $sdcc_string_options($key) {}]
		}

		# Optional string options
		foreach key [array names sdcc_optional_string_options] {
			set value $sdcc_optional_string_options($key)
			if {$value != {}} {
				if {[regexp {\s} $value]} {
					append result { } $key { } "\"" $value "\""
				} else {
					append result { } $key { } $value
				}
			}
		}

		# Semicolon separated optional string options
		foreach key [array names sdcc_scs_string_options] {
			set values $sdcc_scs_string_options($key)
			foreach value [split $values {;}] {
				if {$value != {}} {
					if {[regexp {\s} $value]} {
						append result { } $key { } "\"" $value "\""
					} else {
						append result { } $key { } $value
					}
				}
			}
		}

		return $result
	}

	## Determinate CLI options for external assembler ASEM-51
	 # @return String - Options for ASEM-51
	proc determinate_asem51_options {} {
		variable assembler_ASEM51_config	;# Current ASEM-51 assembler configuration

		set result $assembler_ASEM51_config(custom)
		if {$assembler_ASEM51_config(-i) != {}} {
			append result " --includes=$assembler_ASEM51_config(-i)"
		}
		foreach opt {--omf-51 --columns --verbose} {
			if {$assembler_ASEM51_config($opt)} {
				append result { } $opt
			}
		}

		return $result
	}

	## Determinate CLI options for external assembler AS31
	 # @return String - Options for AS31
	proc determinate_as31_options {} {
		variable assembler_AS31_config		;# Current AS31 assembler configuration

		set result {}
		if {$assembler_AS31_config(custom) != {}} {
			append result { } ${assembler_AS31_config(custom)}
		}
		foreach opt {-l} {
			if {$assembler_AS31_config($opt)} {
				append result { } $opt
			}
		}
		foreach opt {-F -A} {
			if {$assembler_AS31_config($opt) != {}} {
				append result { } $opt $assembler_AS31_config($opt)
			}
		}

		return $result
	}

	## Determinate CLI options for external assembler ASL
	 # @return String - Options for ASL
	proc determinate_asl_options {} {
		variable assembler_ASL_config		;# Current ASL assembler configuration

		set result {-gnuerrors}
		if {$assembler_ASL_config(custom) != {}} {
			append result { } ${assembler_ASL_config(custom)}
		}
		foreach opt {-A -a -C -c -h -I -L -M -P -n -quiet -s -u -U -w -x} {
			if {$assembler_ASL_config($opt)} {
				append result { } $opt
			}
		}
		foreach opt {-r -i -g -cpu} {
			if {$assembler_ASL_config($opt) != {}} {
				append result { } $opt { "} $assembler_ASL_config($opt) {"}
			}
		}

		return $result
	}

	## Initialize NS variables
	 # @return void
	proc initialize {} {
		# Assembler
		array set ::ExternalCompiler::assembler_ASEM51_addcfg		\
			$::ExternalCompiler::assembler_ASEM51_addcfg_def
		array set ::ExternalCompiler::assembler_ASEM51_config		\
			$::ExternalCompiler::assembler_ASEM51_config_def
		array set ::ExternalCompiler::assembler_ASL_addcfg		\
			$::ExternalCompiler::assembler_ASL_addcfg_def
		array set ::ExternalCompiler::assembler_ASL_config		\
			$::ExternalCompiler::assembler_ASL_config_def
		array set ::ExternalCompiler::assembler_AS31_addcfg		\
			$::ExternalCompiler::assembler_AS31_addcfg_def
		array set ::ExternalCompiler::assembler_AS31_config		\
			$::ExternalCompiler::assembler_AS31_config_def

		# SDCC
		array set ::ExternalCompiler::sdcc_bool_options			\
			$::ExternalCompiler::sdcc_bool_options_def
		array set ::ExternalCompiler::sdcc_string_options		\
			$::ExternalCompiler::sdcc_string_options_def
		array set ::ExternalCompiler::sdcc_optional_string_options	\
			$::ExternalCompiler::sdcc_optional_string_options_def
		array set ::ExternalCompiler::sdcc_scs_string_options		\
			$::ExternalCompiler::sdcc_scs_string_options_def

		# Make utility
		foreach {key value} ${::ExternalCompiler::makeutil_config_def} {
			set ::ExternalCompiler::makeutil_config($key) $value
		}
	}
}

# Initialize NS variables
ExternalCompiler::initialize

# >>> File inclusion guard
}
# <<< File inclusion guard

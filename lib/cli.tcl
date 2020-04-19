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
if { ! [ info exists _CLI_TCL ] } {
set _CLI_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Handle options given by command line interface
# --------------------------------------------------------------------------


# SET COMMMAND LINE OPTIONS TO DEFAULTS
# --------------------------------------
set CLI_OPTION(notranslation)	0	;# Disable i18n
set CLI_OPTION(quiet)		0	;# Don't display status of initialization progress on start-up
set CLI_OPTION(nosplash)	0	;# Don't show splash screen
set CLI_OPTION(nocolor)		0	;# Disable color output
set CLI_OPTION(defaults)	0	;# Start with default settings
set CLI_OPTION(minimalized)	0	;# Start with minimalized window
set CLI_OPTION(ignore_last)	0	;# Start with an empty session
set CLI_OPTION(check_libraries)	0	;# Check if all necessary Tcl libraries are available
set CLI_OPTION(reset_settings)	0	;# Reset all user settings to defaults
set CLI_OPTION(help)		0	;# Show help message and exit
set CLI_OPTION(convert)		0	;# Convert one file to another format
set CLI_OPTION(no_opt)		0	;# Disable optimization
set CLI_OPTION(comp_quiet)	0	;# Suppress compiler console output
set CLI_OPTION(no_sim)		0	;# Do not generate SIM file
set CLI_OPTION(no_bin)		0	;# Do not generate binary object code
set CLI_OPTION(no_lst)		0	;# Do not generate code listing
set CLI_OPTION(no_hex)		0	;# Do not generate IHEX8 object code
set CLI_OPTION(warning_level)	0	;# Compiler warning level
set CLI_OPTION(input_output)	{}	;# List of file to convert: [0] == input file; [1] == output file
set CLI_OPTION(compile)		{}	;# Compile this asm file and exit
set CLI_OPTION(open_project)	{}	;# Open only project specified by this var if any
set CLI_OPTION(config_file)	{}	;# Specify path to file containing user settings
set CLI_OPTION(autoindent)	{}	;# Specify path to file to indent
set CLI_OPTION(iram-size)	{}	;# Size of internal data memory
set CLI_OPTION(xram-size)	{}	;# Size of external data memory
set CLI_OPTION(code-size)	{}	;# Size of program memory
set CLI_OPTION(disassemble)	{}	;# IHEX8 file to disassemble
set CLI_OPTION(no-plugins)	0	;# Disable plug-ins
set CLI_OPTION(simulator)	0	;# Start simulator only


# ------------------------------------------------------------------------------
# Microsoft Windows OS specific code
# ------------------------------------------------------------------------------
if {$::MICROSOFT_WINDOWS} {
	# Windows has no terminal control codes (at least I am not aware of them)
	set CLI_OPTION(nocolor) 1
	# It's usually only annoying to have verbose output on Windows
	set CLI_OPTION(quiet) 1
}
# ------------------------------------------------------------------------------


# DEFINE FUNCTIONS
# ------------------

## Only print version information and exit program
 # @return void
proc CLI_display_version_and_exit {} {
	# Load ToolKit
	if {[catch {package require Tk}]} {
		libraryLoadFailed {Tk}
	}

	# Get rid of main window
	wm withdraw .

	# Display the message
	puts "\n${::SHORTNAME}:"
	puts "\tProgram version:\t${::VERSION}"
	puts "\tTcl version:\t\t${::tcl_version}"
	puts "\tTk version:\t\t${::tk_version}"
	exit
}

## Helper procedure for CLI options --iram-size, --xram-size and --code-size
 # @parm String option		- Command line option without leading dashes (eg. xram-size)
 # @parm String value		- Value taken from CLI
 # @parm String maximum_in_hex	- Maximum value in hexadecimal (eg. 0x10000)
 # @parm String memtype		- Memory type (eg. "external data")
 # @return void
proc CLI_set_memory_limit {option value maximum_in_hex memtype} {
	set arg [string tolower $value]
	if {[string index $arg end] == {k}} {
		set arg [string replace $arg end end]
		set kilo 1
	} else {
		set kilo 0
	}
	if {![string is digit -strict $arg]} {
		puts stderr "Expected integer after --$option"
		exit 1
	}
	if {$kilo} {
		set arg [expr {$arg * 1024}]
	}
	if {$arg > $maximum_in_hex} {
		puts stderr "Maximum acceptable size of $memtype memory is $maximum_in_hex ([expr {$maximum_in_hex}])"
		exit 1
	}
	set CLI_OPTION($option) $arg
}

## Handle options --hex2bin, --bin2hex, --sim2hex, --sim2bin and --normalize-hex
 # @parm Int i		- index in $argv
 # @parm Int type	- requested type of conversion
 #				1 - hex2bin
 #				2 - bin2hex
 #				3 - sim2hex
 #				4 - sim2bin
 #				5 - normalize-hex
 # @return void
proc CLI_convert {i type}  {
	global argc	;# Arguments count
	global argv	;# Arguments list

	# Check if there are all nessesary values available
	if {($i + 2) >= $argc} {
		puts "${::APPNAME}"
		puts stderr "\tERROR: You must specify input and output file"
		exit 1
	}

	# Set CLI options array
	set ::CLI_OPTION(input_output) {}
	set ::CLI_OPTION(convert) $type
	lappend ::CLI_OPTION(input_output) [lindex $argv [expr {$i + 1}]]
	lappend ::CLI_OPTION(input_output) [lindex $argv [expr {$i + 2}]]

	# Check for validity of given data

	# * input file must be readable
	set file [lindex $argv [expr {$i + 1}]]
	if {[file isdirectory $file] || ![file exists $file] || (!$::MICROSOFT_WINDOWS && ![file readable $file])} {
		puts "${::APPNAME}"
		puts stderr "\tERROR: Unable to read file '[lindex $argv [expr {$i + 1}]]'"
		exit 1
	}
	# * output file must be writable if exists
	set file [lindex $argv [expr {$i + 2}]]
	if {[file exists $file]} {
		if {
			[file isdirectory $file] ||
			![file writable $file]
		} then {
			puts "${::APPNAME}"
			puts stderr "\tERROR: Unable to write to file '$file'"
			exit 1
		}
	}
}

## Get next argument (some file) and store it in the given variable
 # @parm Int i		- Index of the current command line argument
 # @parm String option	- Command line option (for error message)
 # @parm String key	- Key in array 'CLI_OPTION'
 # @return void
proc CLI_next_arg {i option key} {
	global argc	;# Arguments count
	global argv	;# Arguments list

	# Check if the next argument (some file) is available
	incr i
	if {$i >= $argc} {
		puts "${::APPNAME}"
		puts stderr "\tERROR: Expected filename after $option"
		exit 1
	}

	# Set CLI option
	set ::CLI_OPTION($key) [file normalize [lindex $argv $i]]

	# Check if the specified file does exist
	if {
		[file isdirectory $::CLI_OPTION($key)]	||
		![file exists $::CLI_OPTION($key)]	||
		(!$::MICROSOFT_WINDOWS && ![file readable $::CLI_OPTION($key)])
	} then {
		puts "${::APPNAME}"
		puts stderr "\tERROR: Unable to read file '$::CLI_OPTION($key)'"
		exit 1
	}
}

## Parse command line options
 # @return void
proc parse_cli_options {} {
	global argc		;# Int: Arguments count
	global argv		;# List: Arguments list
	global CLI_OPTION	;# Array: Commmand line options

	# Open project file, if it's the only argument given to the program
	if {$argc == 1 && [regexp {^.+\.mcu8051ide$} [lindex $argv 0]]} {
		set CLI_OPTION(open_project) [file normalize [lindex $argv 0]]
		return
	}

	# iterate over all given arguments
	for {set i 0} {$i < $argc} {incr i} {
		set arg [lindex $argv $i]

		# decide what to do with each of them
		switch -exact -- $arg {

			{--help} {		;# Display help message only
				set CLI_OPTION(help) 1
			}
			{-h} {			;# Display help message only
				set CLI_OPTION(help) 1
			}
			{--quiet} {		;# Don't display initialization progress on start-up
				set CLI_OPTION(quiet) 1
			}
			{--no-translation} {	;# Disable i18n
				set CLI_OPTION(notranslation) 1
			}
			{--no-i18n} {		;# Disable i18n
				set CLI_OPTION(notranslation) 1
			}
			{-q} {			;# Don't display initialization progress on start-up
				set CLI_OPTION(quiet) 1
			}
			{--nosplash} {		;# Don't show splash screen
				set CLI_OPTION(nosplash) 1
			}
			{--nocolor} {		;# Disable color output
				set CLI_OPTION(nocolor) 1
			}
			{-n} {			;# Disable color output
				set CLI_OPTION(nocolor) 1
			}
			{--version} {		;# Display version information
				CLI_display_version_and_exit
			}
			{-V} {			;# Display version information
				CLI_display_version_and_exit
			}
			{--defaults} {		;# Start with default settings
				set CLI_OPTION(defaults) 1
			}
			{--minimalized} {	;# Start with minimalized window
				set CLI_OPTION(minimalized) 1
			}
			{--check-libraries} {	;# Check if all nessery Tcl libraries are avaible
				set CLI_OPTION(check_libraries) 1
			}
			{--ignore-last-session} {	;# Start with and empty session
				set CLI_OPTION(ignore_last) 1
			}
			{--open-project} {	;# Open only this project
				CLI_next_arg $i {--open-project} {open_project}
				incr i
			}
			{--config-file} {	;# Specify path to file containg user settings
				CLI_next_arg $i {--config-file} {config_file}
				incr i
			}
			{--assemble} -
			{--compile} {		;# Compile asm file and exit
				CLI_next_arg $i {--compile} {compile}
				incr i
			}
			{--reset-user-settings} {	;# Reset all user settings to defaults
				set CLI_OPTION(reset_settings) 1
			}
			{--hex2bin} {		;# Convert Intel Hex 8 file to binary file
				CLI_convert $i 1
				incr i 2
			}
			{--bin2hex} {		;# Convert binary file to Intel Hex 8 file
				CLI_convert $i 2
				incr i 2
			}
			{--sim2hex} {		;# Convert simulator file to Intel Hex 8 file
				CLI_convert $i 3
				incr i 2
			}
			{--sim2bin} {		;# Convert simulator file to binary file
				CLI_convert $i 4
				incr i 2
			}
			{--normalize-hex} {	;# Normalize IHEX8 file
				CLI_convert $i 5
				incr i 2
			}
			{--auto-indent}	{	;# Reformat indention
				CLI_next_arg $i {--auto-indent} {autoindent}
				incr i
			}
			{--iram-size}	{	;# Set size of internal data memory
				incr i
				CLI_set_memory_limit {iram-size} [lindex $argv $i] 0x100 {internal data}
			}
			{--xram-size}	{	;# Set size of external data memory
				incr i
				CLI_set_memory_limit {xram-size} [lindex $argv $i] 0x10000 {external data}
			}
			{--code-size}	{	;# Set size of program memory
				incr i
				CLI_set_memory_limit {code-size} [lindex $argv $i] 0x10000 {code}
			}
			{--no-opt} {		;# Disable optimization
				set CLI_OPTION(no_opt) 1
			}
			{--comp-quiet} {	;# Suppress compiler console output
				set CLI_OPTION(comp_quiet) 1
			}
			{--no-sim} {		;# Do not generate SIM file
				set CLI_OPTION(no_sim) 1
			}
			{--no-bin} {		;# Do not generate binary object code
				set CLI_OPTION(no_bin) 1
			}
			{--no-lst} {		;# Do not generate code listing
				set CLI_OPTION(no_lst) 1
			}
			{--no-hex} {		;# Do not generate IHEX8 object code
				set CLI_OPTION(no_hex) 1
			}
			{--warning-level} {	;# Compiler warning level
				incr i
				set arg [lindex $argv $i]
				if {$arg != {0} && $arg != {1} && $arg != {2} && $arg != {3}} {
					puts stderr "Bad value for option --warning-level, possible values are {0 1 2 3}"
					exit 1
				}
				set CLI_OPTION(warning_level) $arg
			}
			{--disassemble} {	;# Disaseble IHEX8 code
				CLI_next_arg $i {--disassemble} {disassemble}
				incr i
			}
			{--no-plugins} {	;# Disable plugins
				set CLI_OPTION(no-plugins) 1
			}
			{--simulator} {		;# Start simulator only
				set CLI_OPTION(simulator) 1
			}
			default {		;# Unknown option -- terminate program
				puts stderr "Unknown command line option: '$arg'"
				exit 1
			}
		}
	}

	# discard CLI arguments
	set argc 0
	set argv [list]
}

# PARSE COMMAND LINE OPTIONS
# --------------------------

if {$argc} {
	parse_cli_options
}

# HANDLE CLI OPTIONS WHICH REQUIRE INSTANT RESPONSE
# --------------------------------------------------

# Display help message and exit
if {$CLI_OPTION(help)} {
	puts "\n${::APPNAME}"
	puts "IDE for MSC-51 based microcontrolers.\n"
	if {$CLI_OPTION(nocolor)} {
		puts "Options:"
		set clr_end {}
		set clr_opt {}
		set clr_arg {}
	} else {
		puts "\033\[1mOptions:\033\[m"
		set clr_end "\033\[m"
		set clr_opt "\033\[32m"
		set clr_arg "\033\[33;1m"
	}
	puts "\t${clr_opt}--no-translation${clr_end},\tDisable program language translation\n\t${clr_opt}--no-i18n${clr_end}"
	puts "\t${clr_opt}--help${clr_end}, ${clr_opt}-h${clr_end}\t\tDisplay this message"
	puts "\t${clr_opt}--quiet${clr_end}, ${clr_opt}-q${clr_end}\t\tDon't display status of initialization progress on start-up"
	puts "\t${clr_opt}--no-plugins${clr_end}\t\tDisable plugins"
	puts "\t${clr_opt}--nosplash${clr_end}\t\tDon't show splash screen"
	puts "\t${clr_opt}--nocolor${clr_end}, ${clr_opt}-n${clr_end}\t\tDisable color output"
	puts "\t${clr_opt}--version${clr_end}, ${clr_opt}-V${clr_end}\t\tDisplay version information"
	puts "\t${clr_opt}--defaults${clr_end}\t\tStart with default settings (low level GUI settings (panel sizes ...))"
	puts "\t${clr_opt}--minimalized${clr_end}\t\tStart with minimalized window"
	puts "\t${clr_opt}--config-file ${clr_arg}filename${clr_end}\tSpecify path to file containg user settings"
	puts "\t${clr_opt}--check-libraries${clr_end}\tCheck if all nessesary Tcl libraries are avaible"
	puts "\t${clr_opt}--ignore-last-session${clr_end}\tStart with an empty session (no project will be opened at start-up)"
	puts "\t${clr_opt}--open-project ${clr_arg}project${clr_end}\tOpen only this project"
	puts "\t${clr_opt}--reset-user-settings${clr_end}\tReset all user settings to defaults"
	puts ""
	puts "\t${clr_opt}--auto-indent ${clr_arg}input${clr_end}\tReformat indention in source code"
	puts "\t${clr_opt}--hex2bin ${clr_arg}input output${clr_end}\tConvert Intel Hex 8 file to binary file"
	puts "\t${clr_opt}--bin2hex ${clr_arg}input output${clr_end}\tConvert binary file to Intel Hex 8 file"
	puts "\t${clr_opt}--sim2hex ${clr_arg}input output${clr_end}\tConvert ${::APPNAME} simulator file to Intel Hex 8 file"
	puts "\t${clr_opt}--sim2bin ${clr_arg}input output${clr_end}\tConvert ${::APPNAME} simulator file to binary file"
	puts "\t${clr_opt}--normalize-hex ${clr_arg}input${clr_end}\tNormalize IHEX8 file"
	puts ""
	puts "\t${clr_opt}--disassemble ${clr_arg}hex_file${clr_end}\tDisaseble IHEX8 code to ${clr_arg}hex_file.asm${clr_end}"
	puts "\t${clr_opt}--assemble ${clr_arg}asm_file${clr_end}\tCompile asm file and exit"
	puts "\t${clr_opt}--compile ${clr_arg}asm_file${clr_end}\tThe same as ``--assemble''"
	puts "\t${clr_opt}--iram-size ${clr_arg}size${clr_end}\tSet size of internal data memory\t(eg. 1K or 1024) (default: 0x100)"
	puts "\t${clr_opt}--code-size ${clr_arg}size${clr_end}\tSet size of program memory\t\t(eg. 1K or 1024) (default: 0x10000)"
	puts "\t${clr_opt}--xram-size ${clr_arg}size${clr_end}\tSet size of external data memory\t(eg. 1K or 1024) (default: 0x10000)"
	puts "\t${clr_opt}--no-opt${clr_end}\t\tDisable optimization"
	puts "\t${clr_opt}--comp-quiet${clr_end}\t\tSuppress compiler console output"
	puts "\t${clr_opt}--no-sim${clr_end}\t\tDo not generate ADF file (Asm. Debug File for MCU 8051 IDE simulator)"
	puts "\t${clr_opt}--no-bin${clr_end}\t\tDo not generate binary object code"
	puts "\t${clr_opt}--no-lst${clr_end}\t\tDo not generate code listing"
	puts "\t${clr_opt}--no-hex${clr_end}\t\tDo not generate IHEX8 object code"
	puts "\t${clr_opt}--warning-level ${clr_arg}N${clr_end}\tSet compiler warning level"
	puts "\t\t${clr_arg}3${clr_end} - Nothing"
	puts "\t\t${clr_arg}2${clr_end} - Errros only"
	puts "\t\t${clr_arg}1${clr_end} - Errors + Warnings"
	puts "\t\t${clr_arg}0${clr_end} - All (Default)"
	puts ""
	puts "\t${clr_opt}--simulator${clr_end}\t\tStart simulator only, see manual for more details"
	exit
}

# Convert some file to another
if {$CLI_OPTION(convert)} {
	puts "${::APPNAME}"

	# Import required code
	package require md5 2.0.1
	source "${::LIB_DIRNAME}/lib/Math.tcl"
	source "${::LIB_DIRNAME}/lib/ihextools.tcl"

	# Set input and output file names
	set input [lindex $CLI_OPTION(input_output) 0]
	set output [lindex $CLI_OPTION(input_output) 1]

	# Make backup for target file if that file does already exist
	if {[file exists $output]} {
		puts "Creating backup for $output -> $output~"
		file rename -force $output "$output~"
	}
	puts "Converting ..."

	# Open input and output file
	set input [open $input {r}]
	set output [open $output {w} 0640]
	fconfigure $input -translation binary
	fconfigure $output -translation binary

	# Decide what to do
	switch -- $CLI_OPTION(convert) {
		1 {	;# Hex -> Bin
			::IHexTools::load_hex_data [read $input]
			if {!${::IHexTools::error_count}} {
				puts -nonewline $output [::IHexTools::get_bin_data]
			}
		}
		2 {	;# Bin -> Hex
			::IHexTools::load_bin_data [read $input]
			if {!${::IHexTools::error_count}} {
				puts -nonewline $output [::IHexTools::get_hex_data]
			}
		}
		3 {	;# Sim -> Hex
			::IHexTools::load_sim_data [read $input]
			if {!${::IHexTools::error_count}} {
				puts -nonewline $output [::IHexTools::get_hex_data]
			}
		}
		4 {	;# Sim -> Bin
			::IHexTools::load_sim_data [read $input]
			if {!${::IHexTools::error_count}} {
				puts -nonewline $output [::IHexTools::get_bin_data]
			}
		}
		5 {	;# Hex -> Hex
			::IHexTools::load_hex_data [read $input]
			if {!${::IHexTools::error_count}} {
				puts -nonewline $output [::IHexTools::get_hex_data]
			}
		}
		default {	;# Something went wrong
			puts stderr "FATAL INTERNAL ERROR - invalid value of \$CLI_OPTION(convert)"
			exit 1
		}
	}

	if {${::IHexTools::error_count}} {
		puts "FAILED !"
		puts ${::IHexTools::error_string}
	} else {
		puts "Successful"
	}

	exit
}

if {$CLI_OPTION(autoindent) != {}} {
	puts "${::APPNAME}"

	# Import nessesary code
	package require md5 2.0.1
	source "${::LIB_DIRNAME}/X.tcl"
	source "${::LIB_DIRNAME}/syntaxhighlight.tcl"

	# Make backup for target file if that file does already exist
	if {[file exists $CLI_OPTION(autoindent)]} {
		puts "Creating backup for $CLI_OPTION(autoindent) -> $CLI_OPTION(autoindent)~"
		file rename -force $CLI_OPTION(autoindent) "$CLI_OPTION(autoindent)~"

		# Ensure than the file is writable
		if {![file writable $CLI_OPTION(autoindent)]} {
			puts "Error: Cannot write to the given file"
			exit 1
		}
	}
	puts "Formatting ..."

	# Load and reformat file content
	set ::X::reformat_code_abort 0
	set ::X::compilation_progress 0
	set file [open $CLI_OPTION(autoindent) r]
	set data [::X::reformat_code_core [read $file]]
	close $file

	# Save file
	set file [open $CLI_OPTION(autoindent) w 0640]
	puts -nonewline $file $data
	close $file

	# Done ...
	puts "Done"
	exit
}

# Disassemble code
if {$CLI_OPTION(disassemble) != {}} {
	# Import required sources
	source "${::LIB_DIRNAME}/lib/Math.tcl"	;# Special mathematical operations
	source "${::LIB_DIRNAME}/compiler/compiler.tcl"	;# 8051 Assemly language compiler
	source "${::LIB_DIRNAME}/lib/ihextools.tcl"	;# Tools for manipulating with IHEX8

	# Other compiler settings
	set Compiler::Settings::NOCOLOR $CLI_OPTION(nocolor)

	# Open source and destination files
	if {[catch {
		set src_file [open $CLI_OPTION(disassemble) {r}]
		set trg_file [open [file rootname $CLI_OPTION(disassemble)].asm w 0640]
	}]} then {
		puts stderr "Unable to open either \"$CLI_OPTION(disassemble)\" or \"[file rootname $CLI_OPTION(disassemble)].asm\""
		exit 1
	}

	# Initialize disassembler
	puts ""
	::IHexTools::load_hex_data [read $src_file]
	if {!${::IHexTools::error_count} && !${::IHexTools::abort}} {
		puts -nonewline $trg_file [disassembler::compile [::IHexTools::get_hex_data]]
	}

	# Write error messages
	if {${::IHexTools::error_count}} {
		puts ${::IHexTools::error_string}
		if {$CLI_OPTION(nocolor)} {
			puts "Disassembly FAILED"
		} else {
			puts "\033\[31;1mDisassembly FAILED\033\[m"
		}
	}

	if {$CLI_OPTION(nocolor)} {
		puts "Result stored in \"[file rootname $CLI_OPTION(disassemble)].asm\"\n"
	} else {
		puts "Result stored in \"\033\[34;1m[file rootname $CLI_OPTION(disassemble)].asm\033\[m\"\n"
	}

	# Close source and destination files
	close $src_file
	close $trg_file

	exit
}

# Compile asm source and exit
if {$CLI_OPTION(compile) != {}} {
	# Import required sources
	package require md5 2.0.1
	source "${::LIB_DIRNAME}/lib/Math.tcl"		;# Special mathematical operations
	source "${::LIB_DIRNAME}/compiler/compiler.tcl"	;# 8051 Assemly language compiler
	source "${::LIB_DIRNAME}/lib/ihextools.tcl"	;# Tools for manipulating with IHEX8

	# Determinate working directory and input file
	set directory	[file dirname $CLI_OPTION(compile)]
	set filename	[regsub {\.[^\.]*$} [file tail $CLI_OPTION(compile)] {}]
	set extension	[string replace [file extension $CLI_OPTION(compile)] 0 0]

	# Set memory limits
	if {$CLI_OPTION(iram-size) != {}} {
		set Compiler::Settings::iram_size $CLI_OPTION(iram-size)
	}
	if {$CLI_OPTION(code-size) != {}} {
		set Compiler::Settings::code_size $CLI_OPTION(code-size)
	}
	if {$CLI_OPTION(xram-size) != {}} {
		set Compiler::Settings::xram_size $CLI_OPTION(xram-size)
	}

	# Enable / Disable optimization
	if {$CLI_OPTION(no_opt)} {
		set Compiler::Settings::optim_ena 0
	}
	# Suppress compiler console output
	set Compiler::Settings::QUIET		$CLI_OPTION(comp_quiet)
	# Compiler warning level
	set Compiler::Settings::WARNING_LEVEL	$CLI_OPTION(warning_level)
	# Do not generate SIM file
	set Compiler::Settings::CREATE_SIM_FILE	[expr {!$CLI_OPTION(no_sim)}]
	# Do not generate binary object code
	set Compiler::Settings::CREATE_BIN_FILE	[expr {!$CLI_OPTION(no_bin)}]
	# Do not generate IHEX8 object code
	if {$CLI_OPTION(no_hex)} {
		set Compiler::Settings::_object 2
	}
	# Do not generate code listing
	if {$CLI_OPTION(no_lst)} {
		set Compiler::Settings::_print 2
	}
	# Other compiler settings
	set Compiler::Settings::NOCOLOR $CLI_OPTION(nocolor)

	# Initialize compiler
	set result [Compiler::compile $directory $directory $filename $extension]

	# Exit according to compilation result
	exit [expr {!$result}]
}

# Check if all nessery Tcl libraries are avaible
if {$CLI_OPTION(check_libraries)} {

	# Local varibale
	set librariesToCheck [llength $::LIBRARIES_TO_LOAD]	;# Number of libs to check
	set failsVer	0	;# Number of libraries which didn't pass version check
	set failsLib	0	;# Number of libraries which could not be found
	set failsTotal	0	;# Number of fails tottaly

	puts "$::APPNAME\n"
	puts "\tChecking libraries..."

	# Iterate over list of needed libraries
	for {set i 0} {$i < $librariesToCheck} {incr i} {
		# Local variables
		set library [lindex $::LIBRARIES_TO_LOAD [list $i 0]]	;# Library name
		set version [lindex $::LIBRARIES_TO_LOAD [list $i 1]]	;# Library version

		# Skip optional libraries.
		if {[lsearch $::OPTIONAL_LIBRARIES $library] != -1} {
			continue
		}

		# Print what library is currently being checked
		if {$CLI_OPTION(nocolor)} {
			puts "\t\t[expr {$i + 1}]/$librariesToCheck Checking for library $library"
		} else {
			puts "\t\t\033\[33m[expr {$i + 1}]/$librariesToCheck\033\[m \033\[37mChecking for library\033\[m \033\[32m$library\033\[m"
		}

		# Perform presence check and diplay result
		puts -nonewline "\t\t\tLibrary present\t... "
		flush stdout
		if {[catch {package require $library}]} {
			if {$CLI_OPTION(nocolor)} {
				puts "NO !"
			} else {
				puts "\033\[31;01mNO !\033\[m"
			}
			incr failsLib
		} else {
			if {$CLI_OPTION(nocolor)} {
				puts "YES"
			} else {
				puts "\033\[32;01mYES\033\[m"
			}
		}

		# Perform version check and diplay result
		if {$CLI_OPTION(nocolor)} {
			puts -nonewline "\t\t\tVersion $version\t... "
		} else {
			puts -nonewline "\t\t\tVersion \033\[36m$version\033\[m\t... "
		}
		flush stdout
		if {[catch {package require $library $version}]} {
			if {$CLI_OPTION(nocolor)} {
				puts "NO !"
			} else {
				puts "\033\[31;01mNO !\033\[m"
			}
			incr failsVer
		} else {
			if {$CLI_OPTION(nocolor)} {
				puts "YES"
			} else {
				puts "\033\[32;01mYES\033\[m"
			}
		}
	}

	# Determinate number of total fails
	if {$failsVer > $failsLib} {
		set failsTotal $failsVer
	} else {
		set failsTotal $failsLib
	}

	# Print final results
	puts "\n\tRESULTS:"
	if {$failsTotal} {
		# FAILED
		if {$CLI_OPTION(nocolor)} {
			puts "\t\tNumber of fails: $failsTotal"
			puts "\t\tPROGRAM WILL NOT RUN, please install the missing libraries"
		} else {
			puts "\t\tNumber of fails: \033\[31m$failsTotal\033\[m"
			puts "\t\t\033\[31;01mPROGRAM WILL NOT RUN\033\[m, please install the missing libraries"
		}
	} else {
		# SUCCESSFUL
		if {$CLI_OPTION(nocolor)} {
			puts "\t\tNumber of fails: $failsTotal"
			puts "\t\tEverything seems ok"
		} else {
			puts "\t\tNumber of fails: \033\[32;01m$failsTotal\033\[m"
			puts "\t\t\033\[32mEverything seems ok\033\[m"
		}
	}
	puts {}

	# done ...
	exit
}

# Start simulator only
if {$CLI_OPTION(simulator)} {
	puts [list $::SHORTNAME {SIM-ENGINE} $::VERSION]

	# Import required libraries
	package require Itcl 3.4
	package require tdom 0.8

	# Configure environment
	set ::GUI_AVAILABLE 0
	namespace import -force ::itcl::*

	# Tools for manipulating with IHEX8
	source "${::LIB_DIRNAME}/lib/ihextools.tcl"
	# Simulator engine
	source "${::LIB_DIRNAME}/simulator/engine/engine_core.tcl"
	# PALE
	source "${::LIB_DIRNAME}/pale/pale.tcl"
	# Simulator enginine CLI
	source "${::LIB_DIRNAME}/simulator/engine/engine_text_based_interface.tcl"
	# Database of supported MCUs
	source "${::LIB_DIRNAME}/dialogues/selectmcu.tcl"
	#
	source "${::LIB_DIRNAME}/lib/Math.tcl"
	#
	source "${::LIB_DIRNAME}/compiler/assembler.tcl"
	#
	source "${::LIB_DIRNAME}/compiler/compilerconsts.tcl"


	# Enter main loop of the sim. engine CLI
	SimulatorEngineCLI::enter_main_loop

	# done ...
	exit
}

# >>> File inclusion guard
}
# <<< File inclusion guard

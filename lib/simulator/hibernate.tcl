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
if { ! [ info exists _HIBERNATE_TCL ] } {
set _HIBERNATE_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides program hibernation capability. It ohter words it can save
# current state of simulator engine to a file (*.m5ihib) and later
# restrore state save in that file and resume hibernated program.
#
# Usage:
#	hibernate_hibernate <filename.m5ihib> <sourcefile> <source_md5> <exclude_stepback>
#		;# -> Bool (1 == successfull; 0 == failed)
#		;# This function also invokes dialog showing hibernation progress
#
#	hibernate_resume  <filename.m5ihib> <exclude_stepback>
#		;# -> Bool (1 == successfull; 0 == failed)
#		;# This function also invokes dialog showing progress
#
#	Note: These functions are safe (checks for filename usability)
# --------------------------------------------------------------------------

class Hibernate {
	## COMMON
	public common version		{1.0}	;# Float: Hibernate facility version
	public common hib_progress_d	0	;# Int: Variable for hibernation progress dialog -- Memory
	public common hib_progress_s	0	;# Int: Variable for hibernation progress dialog -- Program steps
	public common hib_abort	0	;# Bool: Abort hibernation process
	public common expected			;# String: Expected next XML element
	public common take_data		;# Bool: Take element data on next parsing cycle
	public common current_element	{}	;# String: Current XML element -- auxiliary variable for XML parser handler
	public common xml_tmp		{}	;# Mixed: Auxiliary variable of any kind for XML parser handler
	public common source_file	{}	;# String: Filename of the file from which the given file was generated
	public common exclude_stepback	0	;# Bool: Exclude program steps
	public common counter		0	;# Int: Counter of iterations for resume function for XML parser handler
	public common xdata_size	0	;# Int: Size of external data memory
	public common eeprom_size	0	;# Int: Size of data EEPROM
	public common sbs_length	0	;# Int: Size of stepback stack
	public common file_variable		;# Bool: Checkbox variable for "Different filename"
	public common mcu_variable		;# Bool: Checkbox variable for "Different processor"
	public common xdata_variable		;# Int: RadioButton variable for "Different XDATA size"
	public common md5_variable		;# Bool: Checkbox variable for "Different MD5 hash"

	if {$::GUI_AVAILABLE} {
		# Big font for dialog "Program resumption"
	public common big_font		[font create			\
			-family {helvetica}				\
			-weight bold					\
			-size [expr {int(-35 * $::font_size_factor)}]	\
		]
		# Normal font for dialog "Program resumption"
	public common text_font	[font create			\
			-family {helvetica}				\
			-weight bold					\
			-size [expr {int(-14 * $::font_size_factor)}]	\
		]
	}

	## PRIVATE
	private variable parser		;# Object: Reference to active XML parser
	private variable mem_prg_bar	;# Widget: Memory progress bar
	private variable stb_prg_bar	;# Widget: Program steps progress bar

	private variable dlg_ok_but	;# Widget: Button "Ok" in dialog "Program resumption"
	private variable dlg_result	;# Bool: Result of dialog "Program resumption"
	private variable dlg_bits	;# List of Booleans: Differencies between hibernation file and engine config

	## Dafety close hibernation/resumption progress dialog
	 # @return void
	public method hibernate_close_progress_dialog {} {
		set win {.hibernation_progress_dialog}
		if {[winfo exists $win]} {
			grab release $win
			destroy $win
		}
	}

	## Set maximum value for some progress bar in the hibernation progress dialog
	 # @parm String for_what	- "data" == Memory ProgressBar; "step" == "Program steps"
	 # @parm Int value		- New maximum value
	 # @return void
	private method progress_dialog_set_max {for_what value} {
		if {![winfo exists {.hibernation_progress_dialog}]} {
			return
		}
		if {$value < 1} {
			set value 1
		}
		if {$for_what == {data}} {
			$mem_prg_bar configure -maximum $value
		} else {
			$stb_prg_bar configure -maximum $value
		}
	}

	## Invoke hibernation / resumption progress dialog
	 # @parm String header		- Window header
	 # @parm Int data_max		- Maximum value for progress bar "Memory" (can be less than 1)
	 # @parm Int stepback_max	- Maximum value for progress bar "Program steps" (can be less than 1)
	 # @return void
	private method show_progress_dialog {header data_max stepback_max} {
		# Reset NS variables related to this dialog
		set hib_progress_d	0
		set hib_progress_s	0
		set hib_abort		0

		# Adjust input values
		if {$data_max < 1} {
			set data_max 1
		}
		incr data_max 2
		if {$stepback_max < 1} {
			set stepback_max 1
		}

		# Create dialog window
		set win [toplevel .hibernation_progress_dialog -class {Progress dialog} -bg ${::COMMON_BG_COLOR}]

		# Create dialog header
		pack [label $win.header						\
			-text $header						\
			-font [font create					\
				-size [expr {int(-17 * $::font_size_factor)}]	\
				-weight {bold}					\
				-family {helvetica}				\
			]							\
		] -fill x

		# Create progress bar "Memory"
		set frame [frame $win.frame_0]
		pack [label $frame.label -text {Memory}] -anchor w -padx 5
		set mem_prg_bar [ttk::progressbar $frame.progressbar	\
			-mode determinate				\
			-variable ::Hibernate::hib_progress_d		\
			-maximum $data_max				\
		]
		pack $mem_prg_bar -fill x
		pack $frame -pady 5 -fill x -padx 5

		# Create progress bar "Program steps"
		set frame [frame $win.frame_1]
		pack [label $frame.label -text {Program steps}] -anchor w -padx 5
		set stb_prg_bar [ttk::progressbar $frame.progressbar	\
			-mode determinate				\
			-variable ::Hibernate::hib_progress_s		\
			-maximum $stepback_max				\
		]
		pack $stb_prg_bar -fill x
		pack $frame -pady 5 -fill x -padx 5

		# Create button "Abort"
		pack [ttk::button $win.abort_button		\
			-text [mc "Abort"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command {set ::Hibernate::hib_abort 1}	\
		] -pady 5

		# Configure dialog window
		wm iconphoto $win ::ICONS::16::bar5
		wm title $win [mc "Hibernation progress"]
		wm minsize $win 300 140
		wm protocol $win WM_DELETE_WINDOW "$this hibernate_close_progress_dialog"
		wm transient $win .
		update
		catch {
			grab $win
			raise $win
		}
	}

	## Hibernate running program
	 # @parm String filename	- Target file
	 # @parm String sourcefile	- Source file (current file in code editor)
	 # @parm String md5		- MD5 hash of the source file
	 # @parm Bool exclude_stepback	- Exclude program steps
	 # @return Bool - 1 == Successful; 0 == Failed
	public method hibernate_hibernate {filename sourcefile md5 exclude_stepback} {
		# Try to open the destination file
		if {[catch {
			set file [open $filename w 0640]
		}]} then {
			return 0
		}

		# Determinate depth of stepback stack and size of XDATA memory
		if {$exclude_stepback} {
			set stacklength 0
		} else {
			set stacklength [$this simulator_get_SBS_len]
		}
		set xdata_size [$this cget -P_option_mcu_xdata]
		set eeprom_size [lindex [$this cget -procData] 32]

		# Invoke progress dialog
		show_progress_dialog					\
			{Hibernating program}				\
			[expr {($xdata_size + $eeprom_size) / 4096}]	\
			[expr {$stacklength / 10}]

		# Write XML header to the destination file
		puts -nonewline $file "<?xml version='1.0' encoding='utf-8'?>\n"
		puts -nonewline $file "<!--\n"
		puts -nonewline $file "\tThis is MCU 8051 IDE hibernation data file.\n"
		puts -nonewline $file "\tIt does not contain program code, only data.\n\n"
		puts -nonewline $file "\tPLEASE DO NOT EDIT THIS FILE MANUALY, BECAUSE\n"
		puts -nonewline $file "\tBAD FORMATTING OF THIS FILE WILL LEAD MCU 8051 IDE TO CRASH !\n"
		puts -nonewline $file "-->\n"

		# Write DTD (Document Type Declaration) to the destination file
		if {[file exists "${::ROOT_DIRNAME}/data/m5ihib.dtd"]} {
			if {[catch {
				set dtd	[open "${::ROOT_DIRNAME}/data/m5ihib.dtd" r]
			}]} then {
				puts stderr "Unable to open m5ihib.dtd, please check your installation."
			} else {
				puts -nonewline $file "<!DOCTYPE m5ihib \[\n\n"
				while {1} {
					if {[eof $dtd]} {
						close $dtd
						break
					}
					puts -nonewline $file "\t"
					puts $file [gets $dtd]
				}
				puts -nonewline $file "\]>\n"
			}
		}

		# Write header
		puts -nonewline $file "<m5ihib\n"
		puts -nonewline $file "\tversion=\"$version\"\n"
		puts -nonewline $file "\tdatetime=\"[clock format [clock seconds] -format {%D %T}]\"\n"
		puts -nonewline $file "\tsource_file=\"$sourcefile\"\n"
		puts -nonewline $file "\tprocessor=\"[$this cget -P_option_mcu_type]\"\n"
		puts -nonewline $file "\txdata=\"$xdata_size\"\n"
		puts -nonewline $file "\teeprom=\"$eeprom_size\"\n"
		puts -nonewline $file "\tmd5=\"$md5\">\n"

		## Write current state of simulator engine
		puts -nonewline $file "\t<currentstate>\n"
		 # Internal data memory
		puts -nonewline $file "\t\t<iram>\n\t\t\t"
		for {set i 0; set j 0} {$i < [lindex [$this cget -procData] 3]} {incr i; incr j} {
			if {$j > 7} {
				set j 0
				puts -nonewline $file "\n\t\t\t"
			}
			puts -nonewline $file [$this getDataDEC $i]
			puts -nonewline $file "\t"
		}
		incr hib_progress_d
		puts -nonewline $file "\n\t\t</iram>\n"
		 # Expanded data memory
		puts -nonewline $file "\t\t<eram>\n\t\t\t"
		for {set i 0; set j 0} {$i < [lindex [$this cget -procData] 8]} {incr i; incr j} {
			if {$j > 7} {
				set j 0
				puts -nonewline $file "\n\t\t\t"
			}
			puts -nonewline $file [$this getEramDEC $i]
			puts -nonewline $file "\t"
		}
		incr hib_progress_d
		puts -nonewline $file "\n\t\t</eram>\n"
		 # External data memory
		puts -nonewline $file "\t\t<xram>\n\t\t\t"
		set i 0
		set j 0
		for {set m 0} {$m < 8} {incr m} {
			for {set k 0} {$i < $xdata_size && $k < 4096} {incr k} {
				if {$j > 7} {
					set j 0
					puts -nonewline $file "\n\t\t\t"
				}
				puts -nonewline $file [$this getXdataDEC $i]
				puts -nonewline $file "\t"
				incr i
				incr j

				if {$hib_abort} {
					catch {
						file delete -force $filename
					}
					hibernate_close_progress_dialog
					return 1
				}
			}
			incr hib_progress_d
			update
		}
		puts -nonewline $file "\n\t\t</xram>\n"
		 # Special function registers
		puts -nonewline $file "\t\t<eeprom>\n\t\t\t"
		set i 0
		set j 0
		for {set m 0} {$m < 8} {incr m} {
			for {set k 0} {$i < $eeprom_size && $k < 4096} {incr k} {
				if {$j > 7} {
					set j 0
					puts -nonewline $file "\n\t\t\t"
				}
				puts -nonewline $file [$this getEepromDEC $i]
				puts -nonewline $file "\t"
				incr i
				incr j

				if {$hib_abort} {
					catch {
						file delete -force $filename
					}
					hibernate_close_progress_dialog
					return 1
				}
			}
			incr hib_progress_d
			update
		}
		puts -nonewline $file "\n\t\t</eeprom>\n"
		 # Special function registers
		puts -nonewline $file "\t\t<sfr>\n"
		puts -nonewline $file "\t\t\t<addresses>\n\t\t\t\t"
		set sfr [$this simulator_get_available_sfr]
		set j 0
		foreach addr $sfr {
			if {$j > 6} {
				set j 0
				puts -nonewline $file "\n\t\t\t\t"
			}
			puts -nonewline $file $addr
			puts -nonewline $file "\t"
			incr j
		}
		puts -nonewline $file "\n\t\t\t</addresses>\n"
		puts -nonewline $file "\t\t\t<values>\n\t\t\t\t"
		set j 0
		foreach addr $sfr {
			if {$j > 6} {
				set j 0
				puts -nonewline $file "\n\t\t\t\t"
			}
			puts -nonewline $file [$this getSfrDEC $addr]
			puts -nonewline $file "\t"
			incr j
		}
		puts -nonewline $file "\n\t\t\t</values>\n"
		puts -nonewline $file "\t\t</sfr>\n"
		 # Special engine configuration string
		puts -nonewline $file "\t\t<special>\n\t\t\t"
		puts -nonewline $file [$this simulator_get_special]
		puts -nonewline $file "\n\t\t</special>\n"
		puts -nonewline $file "\t</currentstate>\n"

		## Write content of list of active interrupts
		puts -nonewline $file "\t<subprograms count=\"[$this subprograms_get_count]\">\n"
		foreach sub [$this subprograms_get_formatted_content] {
			set source	[lindex $sub 0]
			set target	[lindex $sub 1]
			set type	[lindex $sub 2]
			puts -nonewline $file "\t\t<sub source=\"$source\" target=\"$target\" type=\"$type\"/>\n"
		}
		puts -nonewline $file "\t</subprograms>\n"

		## Write stepback stack
		puts -nonewline $file "\t<stepback stacklength=\"$stacklength\">\n"
		for {set i 0} {$i < $stacklength} {incr i} {
			puts -nonewline $file "\t\t<step>\n"
			puts -nonewline $file "\t\t\t<spec>\n\t\t\t\t"
			puts -nonewline $file [$this simulator_hib_get_SB_spec $i]
			puts -nonewline $file "\n\t\t\t</spec><normal>\n"
			set stepback_normal [$this simulator_hib_get_SB_norm $i]
			set norm_len [llength $stepback_normal]
			for {set j 0} {$j < $norm_len} {incr j} {
				puts -nonewline $file "\t\t\t\t<reg type=\""
				puts -nonewline $file [lindex $stepback_normal [list $j 0]]
				puts -nonewline $file "\" addr=\""
				puts -nonewline $file [lindex $stepback_normal [list $j 1]]
				puts -nonewline $file "\" val=\""
				puts -nonewline $file [lindex $stepback_normal [list $j 2]]
				puts -nonewline $file "\"/>\n"
			}
			puts -nonewline $file "\t\t\t</normal>\n"
			puts -nonewline $file "\t\t</step>\n"

			if {!($i % 10)} {
				incr hib_progress_s
				update
			}
			if {$hib_abort} {
				catch {
					file delete -force $filename
				}
				hibernate_close_progress_dialog
				return 1
			}
		}
		puts -nonewline $file "\t</stepback>\n"
		puts -nonewline $file "</m5ihib>\n"

		# Close progress dialog and the destination file
		hibernate_close_progress_dialog
		if {[catch {close $file}]} {
			return 0
		} else {
			return 1
		}
	}

	## Resume hibernated program
	 # @parm String filename	- Source file (XML containing hibernation data)
	 # @parm Bool exclude_stepback	- Exclude program steps for step back function
	 # @return Int - Exit code
	 #	0 - Success
	 #	1 - Unable to open the given file
	 #	2 - Unable to parse the given file
	public method hibernate_resume {filename _exclude_stepback} {
		# Initialize parser variables
		set expected		{m5ihib}
		set take_data		0
		set counter		0
		set sbs_length		0
		set current_element	{}
		set xml_tmp		{}
		set source_file		$filename
		set exclude_stepback	$_exclude_stepback

		set exit_code 0

		# Open hibernation data file
		if {[catch {
			set file [open $filename {r}]
		}]} then {
			return 1
		}

		# Show progress dialog
		show_progress_dialog [mc "Resuming hibernated program"] 1 1

		# Create XML parser object
		if {[catch {
			set parser [::xml::parser -final 1 -ignorewhitespace 1				\
				-elementstartcommand	[list $this hibernate_xml_parser_element]	\
				-characterdatacommand	[list $this hibernate_xml_parser_data]		\
			]
		}]} then {
			hibernate_close_progress_dialog
			tk_messageBox				\
				-type ok -icon error -parent .	\
				-title "::xml::parser error"	\
				-message "Unknown error occurred in XML parser library,\nplease try to reinstall package \"tdom\"."
			return 2
		}

		# Prepare simulator engine
		if {!$exclude_stepback} {
			$this stepback_discard_stack
		}

		# Start XML parser
		$this set_ignore_warnings_related_to_changes_in_SFR 1
		if {[catch {
			$parser parse [read $file]
		} result]} then {
			puts stderr $result
			set exit_code 2
		} else {
			if {$xml_tmp != {}} {
				$this simulator_hib_append_SB_norm $xml_tmp
			}
		}

		# Close the file and free the parser
		if {[catch {
			close $file
		}]} then {
			set exit_code 1
		}
		catch {
			$parser free
		}

		# Synchronize simulator GUI
		$this clear_graph
		$this Simulator_sync
		$this interrupt_monitor_reevaluate
		$this stopwatch_refresh
		set interrupts_in_progress [$this simulator_get_interrupts_in_progress_pb]
		if {[llength $interrupts_in_progress]} {
			simulator_Sbar [mc "Interrupt at vector 0x%s  " [format %X [$this intr2vector [lindex $interrupts_in_progress end]]]] 1 $this
		} else {
			simulator_Sbar {} 0 $this
		}
		set lineNum [$this simulator_getCurrentLine]
		if {$lineNum != {}} {
			$this move_simulator_line $lineNum
		} else {
			$this editor_procedure {} unset_simulator_line {}
		}
		::X::stepback_button_set_ena [$this simulator_get_SBS_len]

		# Cleanup
		set xml_tmp {}
		hibernate_close_progress_dialog
		$this set_ignore_warnings_related_to_changes_in_SFR 0
		return $exit_code
	}

	## Element XML parser handler for method hibernate_resume
	 # @parm String arg1	- name of the element
	 # @parm List attrs	- list of attributes '{attr0 val0 attr1 val1 ...}'
	 # @return void
	public method hibernate_xml_parser_element {arg1 attrs} {
		if {$hib_abort} {
			$parser free
			return
		}

		set current_element $arg1
		if {[lsearch $expected $current_element] == -1} {
			error "Unexpected element: `$current_element'"
		}

		switch -- $arg1 {
			{m5ihib} {		;# ROOT ELEMENT
				set expected	{currentstate}
				set take_data	0

				# Read the file header
				set len [llength $attrs]
				set xml_tmp [list {} {} {} {} {} {} {}]
				for {set i 0} {$i < $len} {incr i} {
					set arg [lindex $attrs $i]
					incr i
					set val [lindex $attrs $i]
					switch -- $arg {
						{version}	{lset xml_tmp 0 $val}
						{datetime}	{lset xml_tmp 1 $val}
						{source_file}	{lset xml_tmp 2 $val}
						{processor}	{lset xml_tmp 3 $val}
						{xdata}		{lset xml_tmp 4 $val}
						{eeprom}	{lset xml_tmp 5 $val}
						{md5}		{lset xml_tmp 6 $val}
					}
				}

				# Check if all of required fields are present
				foreach str $xml_tmp {
					if {![string length $str]} {
						error "XML tag <m5ihib>: Some required attributes missing"
					}
				}

				# Check for minimum required version
				if {$version < [lindex $xml_tmp 0]} {
					tk_messageBox		\
						-parent .	\
						-type ok	\
						-icon warning	\
						-title [mc "Fatal error"]	\
						-message [mc "Version of this M5IHIB file is higher than %s\nUnable to continue." $version]
					set hib_abort 1
				}

				# Set maximum for ProgressBar "Memory" and set size of XDATA memory
				set xdata_size [lindex $xml_tmp 4]
				set eeprom_size [lindex $xml_tmp 5]
				progress_dialog_set_max data [expr {$xdata_size / 4096}]

				# Check for remaining requirements
				check_file_usability

				set xml_tmp {}

			}
			{currentstate} {	;# Current state of MCU
				set expected	{iram}
				set take_data	0
			}
			{iram} {		;# Internal data memory in decimal
				set expected	{eram}
				set take_data	1
			}
			{eram} {		;# Expanded data memory in decimal
				set expected	{xram}
				set take_data	1
			}
			{xram} {		;# External data memory in decimal
				set expected	{eeprom}
				set take_data	1
				set counter	0
			}
			{eeprom} {	;# Data EEPROM in decimal
				set expected	{sfr}
				set take_data	1
				set counter	0
			}
			{sfr} {			;# Special function registers
				set expected	{addresses}
				set take_data	0
			}
			{addresses} {		;# SFR decimal addresses in the same order as in tag values
				set expected	{values}
				set take_data	1
			}
			{values} {		;# SFR decimal values in the same order as in tag values
				set expected	{special}
				set take_data	1
			}
			{special} {		;# Special engine variables
				set expected	{subprograms}
				set take_data	1

				if {$exclude_stepback} {
					set hib_abort 1
				}
			}
			{subprograms} {		;# Content of list of active interrupts
				set expected	{stepback sub}
				set take_data	0

				$this subprograms_clear
			}
			{sub} {			;# Active interrupt
				set expected	{stepback sub}
				set take_data	0

				set source	{}
				set target	{}
				set type	{}

				set len [llength $attrs]
				for {set i 0} {$i < $len} {incr i} {
					switch -- [lindex $attrs $i] {
						{type} {
							incr i
							set type [lindex $attrs $i]
						}
						{source} {
							incr i
							set source [lindex $attrs $i]
						}
						{target} {
							incr i
							set target [lindex $attrs $i]
						}
						default {
							incr i
						}
					}
				}
				if {$source != {} && $target != {} && $type != {}} {
					$this subprograms_call $type $source $target
				} else {
					error "Invalid argument set in tag <step>"
				}
			}
			{stepback} {		;# Stack for stepback function (backward stepping)
				set expected	{step}
				set take_data	0
				set counter	0

				set len [llength $attrs]
				for {set i 0} {$i < $len} {incr i 2} {
					if {[lindex $attrs $i] == {stacklength}} {
						incr i
						set stacklength [lindex $attrs $i]
						$this simulator_set_SBS_len $stacklength
						progress_dialog_set_max stepback [expr {$stacklength / 10}]
						break
					} else {
						incr i
					}
				}
			}
			{step} {		;# One program step
				set expected	{spec}
				set take_data	0
			}
			{spec} {		;# Special engine variables
				set expected	{normal}
				set take_data	1
			}
			{normal} {		;# Ordinary registers
				set expected	{step reg}
				set take_data	0

				if {$xml_tmp != {}} {
					$this simulator_hib_append_SB_norm $xml_tmp
				}
				set xml_tmp {}
			}
			{reg} {			;# One register
				set expected	{reg step}
				set take_data	0

				set reg [list {} {} {}]
				set len [llength $attrs]

				for {set i 0} {$i < $len} {incr i} {
					set arg [lindex $attrs $i]
					incr i
					set val [lindex $attrs $i]

					switch -- $arg {
						{type}	{lset reg 0 $val}
						{addr}	{lset reg 1 $val}
						{val}	{lset reg 2 $val}
					}
				}

				lappend xml_tmp $reg
			}
		}
	}

	## Data XML parser handler for method hibernate_resume
	 # @parm String arg1	- content of the element
	 # @return void
	public method hibernate_xml_parser_data {arg1} {
		if {$hib_abort} {
			$parser free
			return
		}

		# Take data only if they were expected
		if {!$take_data} {return}
		set take_data 0

		switch -- $current_element {
			{iram} {	;# Internal data memory in decimal
				for {set i 0} {$i < [lindex [$this cget -procData] 3]} {incr i} {
					$this setDataDEC $i [lindex $arg1 $i]
				}
				incr hib_progress_d
			}
			{eram} {	;# Expanded data memory in decimal
				for {set i 0} {$i < [lindex [$this cget -procData] 8]} {incr i} {
					$this setEramDEC $i [lindex $arg1 $i]
				}
				incr hib_progress_d
			}
			{xram} {	;# External data memory in decimal
				set addr 0
				for {set m 0} {$m < 8} {incr m} {
					for {set k 0} {$addr < $xdata_size && $k < 4096} {incr k} {
						$this setXdataDEC $addr [lindex $arg1 $addr]
						incr addr

						if {$hib_abort} {
							hibernate_close_progress_dialog
							return 1
						}
					}
					incr hib_progress_d
					update
				}
			}
			{eeprom} {	;# Data EEPROM in decimal
				set addr 0
				for {set m 0} {$m < 8} {incr m} {
					for {set k 0} {$addr < $eeprom_size && $k < 4096} {incr k} {
						$this setEepromDEC $addr [lindex $arg1 $addr]
						incr addr

						if {$hib_abort} {
							hibernate_close_progress_dialog
							return 1
						}
					}
					incr hib_progress_d
					update
				}
			}
			{addresses} {	;# SFR decimal addresses in the same order as in tag values
				set xml_tmp $arg1
			}
			{values} {	;# SFR decimal values in the same order as in tag values
				foreach addr $xml_tmp val $arg1 {
					$this setSfr_directly $addr $val
				}
				set xml_tmp {}
			}
			{special} {	;# Special engine variables
				$this simulator_set_special $arg1
			}
			{spec} {	;# Special engine variables for stepback funtion
				$this simulator_hib_append_SB_spec $arg1

				incr counter
				if {!($counter % 10)} {
					incr hib_progress_s
					update
				}
			}
		}
	}

	## Check if the current hibernation file is usable and invoke dialog to configure simulator engine
	 # @return void
	private method check_file_usability {} {
		# Determinate full name of source file and its MD5 hash
		set sourcefile [list				\
			[$this cget -projectPath]		\
			[$this cget -P_option_main_file]	\
		]
		if {[lindex $sourcefile 1] == {}} {
			set sourcefile [$this editor_procedure {} getFileName {}]
		}
		set sourcefile_md5 {}
		catch {
			set sourcefile_md5 [::md5::md5 -hex -file \
				[file join [lindex $sourcefile 0] [lindex $sourcefile 1]]]
		}

		## Determinate list of differencies
		set differences [list 0 0 0 0]
		if {[lindex $xml_tmp 2] != [lindex $sourcefile 1]} {
			lset differences 0 1
		}
		if {[lindex $xml_tmp 3] != [$this cget -P_option_mcu_type]} {
			lset differences 1 1
		}
		if {[lindex $xml_tmp 4] != [$this cget -P_option_mcu_xdata]} {
			lset differences 2 1
		}
		if {[lindex $xml_tmp 6] != $sourcefile_md5} {
			lset differences 3 1
		}

		# If there are some differencies -> invoke dialog
		foreach bool $differences {
			if {$bool} {
				if {[ask_user_what_to_do $differences]} {
					set hib_abort 1
				}
				break
			}
		}
	}

	## Invoke dialog showing differencies between the hibernation file and engine configuration
	 # @parm List differences -
	 # @return Bool - 1 == abort process; 0 == keep alive
	private method ask_user_what_to_do {differences} {
		# Set NS variables
		set file_variable	1
		set mcu_variable	1
		set xdata_variable	1
		set md5_variable	1

		set win [toplevel .hibernation_bad_file_dialog -class {Error dialog} -bg ${::COMMON_BG_COLOR}]
		set dlg_result 1
		set dlg_bits $differences

		# Create dialog header
		pack [label $win.header_label	\
			-font $text_font	\
			-text [mc "The following problems must be \nresolved before program resumption"] \
		] -fill x -padx 10 -pady 5

		# Create main frame
		set main_frame [frame $win.main_frame]

		# MCU is different
		set num 0
		if {[lindex $differences 1]} {
			incr num
			set frame [dialog_create_item $num $main_frame [mc "This file is indented for %s but the current MCU is %s" [lindex $xml_tmp 3] [$this cget -P_option_mcu_type]]]
			pack [checkbutton $frame.chbut				\
				-text [mc "Set current MCU to %s" [lindex $xml_tmp 3]]	\
				-variable ::Hibernate::mcu_variable		\
				-command "$this hibernation_chbut_rabut_command"	\
			] -anchor w
		}
		# XDATA is different
		if {[lindex $differences 2]} {
			incr num
			set frame [dialog_create_item $num $main_frame [mc "This file contains %s B of external data memory but but your processor has %s B" [lindex $xml_tmp 4] [$this cget -P_option_mcu_xdata]]]
			pack [radiobutton $frame.rabut0		\
				-text [mc "Set current XDATA capacity to %s B" [lindex $xml_tmp 4]]	\
				-variable ::Hibernate::xdata_variable -value 1		\
				-command "$this hibernation_chbut_rabut_command"	\
			] -anchor w
			pack [radiobutton $frame.rabut1					\
				-text [mc "Ignore this difference"]			\
				-variable ::Hibernate::xdata_variable -value 2		\
				-command "$this hibernation_chbut_rabut_command"	\
			] -anchor w
		}
		# MD5 is different
		if {[lindex $differences 3]} {
			incr num
			set frame [dialog_create_item $num $main_frame [mc "Current file (%s) has different MD5 hash than MD5 recorded in this hibernation file" [lindex [$this editor_procedure {} getFileName {}] 1]]]
			pack [checkbutton $frame.chbut		\
				-text [mc "Ignore this difference"]	\
				-variable ::Hibernate::md5_variable	\
				-command "$this hibernation_chbut_rabut_command"	\
			] -anchor w
		}
		# Filename is different
		if {[lindex $differences 0]} {
			incr num
			set frame [dialog_create_item $num $main_frame [mc "This hibernation file was generated from \"%s\" but current file is \"%s\"" [lindex $xml_tmp 2] [lindex [$this editor_procedure {} getFileName {}] 1]]]
			pack [checkbutton $frame.chbut			\
				-text [mc "Ignore this difference"]	\
				-variable ::Hibernate::file_variable	\
				-command "$this hibernation_chbut_rabut_command"	\
			] -anchor w
		}

		pack $main_frame -fill both -expand 1

		# Create buttons "Ok" and "Cancel"
		set button_frame [frame $win.button_frame]
		set dlg_ok_but [ttk::button $button_frame.button_ok	\
			-text [mc "Ok"]					\
			-command "$this hibernation_cls_dlg 0"		\
			-compound left					\
			-image ::ICONS::16::ok				\
		]
		pack $dlg_ok_but -side left -padx 2
		pack [ttk::button $button_frame.button_cancel	\
			-text [mc "Cancel"]			\
			-command "$this hibernation_cls_dlg 1"	\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
		] -side left -padx 2
		pack $button_frame -side bottom -anchor e -padx 10 -pady 5

		# Configure dialog window
		wm iconphoto $win ::ICONS::16::resume
		wm title $win [mc "Program resumption"]
		wm minsize $win 480 200
		wm protocol $win WM_DELETE_WINDOW "
			grab release $win
			destroy $win"
		wm transient $win .hibernation_progress_dialog

		update
		catch {
			grab $win
			raise $win
		}
		focus -force $dlg_ok_but
		tkwait window $win
		return $dlg_result
	}

	## Create one item in dialog generated by proc. ask_user_what_to_do
	 # @parm Int number		- Item number
	 # @parm Widget mainframe	- Frame where to pack this item
	 # @parm String text		- Item text
	 # @return Widget - Frame "Options:"
	private method dialog_create_item {number mainframe text} {
		# Create horizontal separator
		pack [ttk::separator $mainframe.sep_${number}	\
			-orient horizontal			\
		] -fill x -pady 7 -expand 1 -padx 5

		# Create label with number
		set local_frame [frame $mainframe.frame_${number}]
		pack [label $local_frame.lbl			\
			-font $big_font -text "${number}."	\
		] -side left -anchor n -padx 3
		set right_frame [frame $local_frame.right]

		# Create text widget for the given message
		set text_wdg [text $right_frame.top_text	\
			-width 0 -height 3 -wrap word -bd 0	\
			-relief flat -bg ${::COMMON_BG_COLOR} 		\
			-font $text_font -cursor left_ptr	\
		]
		$text_wdg insert end $text
		$text_wdg configure -state disabled
		pack $text_wdg -fill both -expand 1 -pady 3

		# Create frame "Options:"
		pack [label $right_frame.opt_lbl -text [mc "Options:"]] -anchor w -padx 10
		set options_frame [frame $right_frame.options]

		# Pack parts of this item and return frame "Options:"
		pack $options_frame -padx 35 -anchor w
		pack $right_frame -side left -fill both -expand 1
		pack $local_frame  -fill both -expand 1 -padx 10
		return $options_frame
	}

	## Command for checkbuttons and radiobuttons in options frame
	 # Enables / disables Ok button
	 # @return void
	public method hibernation_chbut_rabut_command {} {
		if {$file_variable && $mcu_variable && $xdata_variable && $md5_variable} {
			$dlg_ok_but configure -state normal
		} else {
			$dlg_ok_but configure -state disabled
		}
	}

	## Close dialog with some result
	 # @parm Mixed new_result - Dialog result
	 # @return void
	public method hibernation_cls_dlg {new_result} {
		if {!$new_result} {
			# Adjust processor type
			if {[lindex $dlg_bits 1]} {
				::X::change_processor [lindex $xml_tmp 3]
			}

			# Adjust size of external data memory
			if {[lindex $dlg_bits 2]} {
				# Set new value
				if {$xdata_variable == 1} {
					if {[lindex [$this cget -procData] 0] == {yes}} {
						$this configure -P_option_mcu_xdata $xdata_size
						::X::close_hexedit xdata $this
						$this simulator_resize_xdata_memory $xdata_size
					} else {
						set xdata_size 0
					}

				# Ignore
				} elseif {$xdata_variable == 2} {
					set xdata_size [$this cget -P_option_mcu_xdata]
				}
			}
		}

		# Set dialog result and destroy it
		set dlg_result $new_result

		catch {
			grab release .hibernation_bad_file_dialog
		}
		catch {
			destroy .hibernation_bad_file_dialog
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

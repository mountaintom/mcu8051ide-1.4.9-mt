#!/usr/bin/wish
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
if { ! [ info exists _X_TCL ] } {
set _X_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# "Provides various dialogues and various variables for various things"
# For instance the "Go to" dialog is placed here
# --------------------------------------------------------------------------

# Dialog for selecting MCU and loading MCU details from definition file
source "${::LIB_DIRNAME}/dialogues/selectmcu.tcl"

namespace eval X {

	## General
	variable unsaved_projects	{}		;# List: List of project object marked as "unsaved"
	variable critical_procedure_in_progress	1	;# Bool: Disable critical procedures (like compilation, start simulator, etc.)
	variable foo_procedure_in_progress	0	;# Bool: Disables some non-critical procedures
	variable last_WIN_GEOMETRY	{}		;# Last window geometry (main window)
	variable actualProject		{}		;# Object: Current project
	variable openedProjects		{}		;# List of opened projects (Object references)
	variable actualProjectIdx	-1		;# Index of the current project in $openedProjects
	variable project_menu_locked	1		;# Bool: Indicates than there is at least one opened project
	if {!$::MICROSOFT_WINDOWS} {
		variable defaultDirectory	${::env(HOME)}		;# Default directory
	} else {
		variable defaultDirectory	${::env(USERPROFILE)}	;# Default directory
	}
	variable simulator_enabled	{}		;# List of booleans: Simulator engaged
	variable editor_lines				;# Number of lines in the current editor
	variable fsd_result		{}		;# Value returnded by file selection dialog (in some cases)
	variable projectmenu		{.project_menu}	;# ID of Popup menu for project tabs
	variable projectmenu_project	{}		;# Object: project selected by project popup menu
	variable selectedView				;# Object: Selected editor by editor statusbar popup menu
	variable open_f_external_editor	0		;# Bool: Use procedure __open to open new file for embedded external editor
	variable file_recent_files	{}		;# List: recently opened files
	variable project_recent_files	{}		;# List: recently opened projects
	variable vhw_recent_files	{}		;# List: recently opened Virtual HW files
	# List of supported processors
	variable available_processors	[::SelectMCU::get_available_processors]
	variable procedure_exit_in_progress	0	;# Bool: proc "__exit" in progress

	## Doxygen
	variable doxygen_run_doxywizard		0	;# Bool: Run doxywizard
	variable doxygen_build_api_doc		0	;# Bool: Build API documentation
	variable doxygen_pid			0	;# Int: Doxygen PID
	variable doxygen_mess_project			;# Object: Project related to running doxygen compilation

	## ASCII chart
	variable ascii_chart_win_object		{}	;# Object: ASCII chart window object

	## Interactive 8051 instruction table
	variable table_of_instructions_object	{}	;# Object: Interactive 8051 instruction table

	## 8-Segment LED editor
	variable eightsegment_editors		{}	;# List: All 8-segment LED display editors invoked

	## Base converter
	variable base_converters		{}	;# List: All base converter objects

	## Special calculator
	variable spec_calc_objects		{}	;# List: All special calculator objects

	## UART/RS232 debugger
	variable rs232debugger_objects		{}	;# List: All "RS232 debugger" objects

	## LCD display controlled by HD44780
	variable vhw_HD44780_rect			;# Array: Rectangles in dialog "Set display size"
	variable vhw_HD44780_canvas			;# Widget: Canvas widget in dialog "Set display size"
	variable vhw_HD44780_counter		0	;# Int: Counter of dialog instances
	variable vhw_HD44780_size_lbl			;# Widget: Label showing the LCD size in dialog "Set display size"
	variable vhw_HD44780_dialog			;# Widget: Toplevel window of dialog "Set display size"
	variable vhw_HD44780_size		{0 0}	;# List of Int: LCD display size chosen by the user, {HEIGHT WIDTH}

	## Dialog "Go to"
	variable goto					;# Line where to go

	## Function "Auto-indent"
	variable reformat_code_abort			;# Bool: Abort function 'reformat_code'

	## Dialog "Find"
	variable find_String				;# Search string
	variable find_forward_index			;# Search index for forward search
	variable find_backward_index			;# Search index for backward search
	variable find_option_CS				;# Bool: Case sensitive
	variable find_option_notCS			;# Bool: Case insensitive
	variable find_option_back			;# Bool: Search backwards (checkbox)
	variable find_option_cur			;# Book: Search from cursor
	variable find_option_sel			;# Bool: Search only in the seleted text
	variable find_option_reg			;# Bool: Consider search string to be a regular expression
	variable find_allow_selection			;# Bool: There is some selected text in editor
	variable find_retry_search			;# Bool: Search restarted from beginning/end
	variable find_back_dir				;# Bool: Search backwards (real option)
	variable find_history		{}		;# List of the last 10 search strings
	variable find_next_prev_in_P	0		;# Bool: Procedure 'find_next_prev' in progress

	## Dialog "Replace"
	variable replace_String				;# String to replace
	variable replace_Replacement			;# Replacement for the search string
	variable replace_option_CS			;# Bool: Case sensitive
	variable replace_option_back			;# Bool: Search backwards (checkbox)
	variable replace_option_cur			;# Book: Search from cursor
	variable replace_option_reg			;# Bool: Consider search string to be a regular expression
	variable replace_option_prompt			;# Bool: Prompt on replace
	variable replace_prompt_opened		0	;# Bool: Replace prompt dialog opened
	variable replace_prompt_return_value		;# Replace prompt dialog return value
	variable replace_prompt_geometry		;# Geometry of replace prompt dialog window
	variable replace_search_history		{}	;# List of the last 10 search strings
	variable replace_repl_history		{}	;# List of the last 10 replacement strings

	## Dialog "Select directory"
	variable select_directory_var		{}	;# Selected directory

	## Dialog "New project"
	variable project_new_name		{}	;# Name of the new project
	variable project_new_dir		{}	;# Directory of the new project

	## Variable common for "New project" and "Edit project"
	variable project_new_processor			;# Processor type (e.g. "8051")
	variable project_new_xdata_ena			;# Bool: XDATA memory connected
	variable project_new_xcode_ena			;# Bool: XCODE memory connected
	variable project_new_xdata			;# Int: Amount of XDATA memory
	variable project_new_xcode			;# Int: Amount of XCODE memory
	variable project_new_max_xcode			;# Int: Maximum valid value of external program memory
	variable project_new_xd_chb			;# Widget: XDATA enable checkbutton
	variable project_new_xd_scl			;# Widget: XDATA scale
	variable project_new_xd_spb			;# Widget: XDATA spinbox
	variable project_new_xc_chb			;# Widget: XCODE enable checkbutton
	variable project_new_xc_scl			;# Widget: XCODE scale
	variable project_new_xc_spb			;# Widget: XCODE spinbox

	## Dialog "Edit project"
	variable project_edit_version			;# Project version
	variable project_edit_date			;# Project date (last update)
	variable project_edit_copyright			;# Copyright information
	variable project_edit_license			;# License information
	variable project_edit_authors			;# Project authors
	variable project_edit_description		;# Project description
	variable project_edit_clock			;# Default clock rate
	variable project_edit_main_file			;# Project main file
	variable project_edit_main_file_clr_but		;# Widget: Project main file clear button
	# Some default project values
	#	format: {{variable value} {variable value} ...}
	variable project_edit_defaults		{
		{project_edit_family	8051	}
		{project_edit_clock	12000	}
		{project_edit_calc_rad	Dec	}
		{project_edit_calc_ang	rad	}
	}

	## Functions related to project management (save, load)
	variable project_watches_file			;# File of register watches of the current poject
	variable project_todo				;# Todo text
	variable project_graph				;# Graph configuration list
	variable project_calculator			;# Calculator list (display contents, etc.)
	variable project_other_options			;# Other project options
	variable project_compiler_options		;# Compiler options
	variable project_files				;# List of project files (special format)
	variable project_file				;# Full name of the project file
	variable project_dir				;# Path to project directory

	## Compilation related variables
	variable compilation_success_callback	{}	;# String: Indented for HW plugins
	variable compilation_fail_callback	{}	;# String: Indented for HW plugins
	variable compilation_mess_project	{}	;# Object: Project related to running compilation
	variable compilation_successfull	1	;# Bool: Compilation successful
	variable compilation_in_progress	0	;# Bool: Compiler engaged
	variable compilation_progress		0	;# Variable for compilation progressbar
	variable compiler_pid			0	;# Int: PID of external compiler if used
	variable compilation_start_simulator	0	;# Bool: Start simulator after successful compilation
	variable compile_this_file_only		0	;# Bool: Compile the current file only

	## Dialog "Select input/output file"
	variable input_file				;# Input file
	variable output_file				;# Output file
	variable IO					;# Bool: 1 == choose input file; 0 == choose output file

	### Dialogues "Hex->Bin; Bin->Hex; Sim->Hex; Sim->Bin; Nomalize Hex"
	 # Type of conversion
	 #	0 == Bin -> Hex
	 #	1 == Hex -> Bin
	 #	2 == Sim -> Hex
	 #	3 == Sim -> Bin
	variable hex__bin
	variable input_file			{}	;# Input file
	variable output_file			{}	;# Output file

	## XDATA/CODE/ERAM/EEPROM/UNI memory hexadecimal editors
	variable opened_code_mem_windows	{}	;# List of project object with opened CODE memory hex editor
	variable code_mem_window_objects	{}	;# List of CODE memory hex editor objects
	variable opened_xdata_mem_windows	{}	;# List of project object with opened XDATA memory hex editor
	variable xdata_mem_window_objects	{}	;# List of XDATA memory hex editor objects
	variable opened_eram_windows		{}	;# List of project object with opened ERAM hex editor
	variable eram_window_objects		{}	;# List of ERAM hex editor objects
	variable opened_eeprom_mem_windows	{}	;# List of project object with opened data EEPROM hex editor
	variable eeprom_mem_window_objects	{}	;# List of data EEPROM hex editor objects
	variable opened_eeprom_wr_bf_windows	{}	;# List of project objects with opened data EEPROM write buffer editor
	variable eeprom_wr_bf_window_objects	{}	;# List of data EEPROM write buffer hex editor objects
	variable eeprom_wr_buf_counter		0	;# Counter of EEPROM write buffer hex editor objects
	variable saving_progress		0	;# Variable for progressbars representing saving progress
	variable abort_saving			0	;# Bool: Abort saving of IHEX8 file
	variable independent_hexeditor_count	0	;# Counter of intances of independent hexadecimal editor

	# Path to file defining the last session
	variable session_file	"${::CONFIG_DIR}/last_session.conf"

	## Dialog "Cleanup project folder"
	 # GLOB patterns in certain order !
	variable cleanup_masks {
		*.asm~		*.lst~		*.sim~		*.hex~
		*.bin~		*.html~		*.tex~		*.wtc~
		*.mcu8051ide~	*.m5ihib~	*.cdb~		*.ihx~
		*.adf~		*.omf~		*.map~		*.c~
		*.h~		*.vhc~		*.vhw~		*.txt~
		*~

		*.lst	*.sim	*.hex	*.bin	*.html	*.tex	*.m5ihib
		*.noi	*.obj	*.map	*.p	*.mac	*.i	*.ihx
		*.adf	*.adb	*.rel	*.cdb	*.mem	*.lnk	*.sym
		*.omf	*.rst	*.hashes *bak
	}
	variable cleanup_files	{}	;# List: Files marked for potential removal

	## Dialog "Change letter case"
	variable change_letter_case_options		;# Options (which fields should be adjusted)

	## Dialog "Line to address"
	variable line2pc				;# Int: Selected line in source code
	variable line2pc_jump			1	;# Bool: Perform program jump (1) or subprogram call (0)
	variable line2pc_line_max			;# Int: Number of lines in the source code
	variable line2pc_value_lbl			;# Widget: Label containing PC value
	variable line2pc_new_value			;# Int: Resolved address or {}
	variable line2pc_org_line			;# Int: Original line
	variable line2pc_ok_button			;# Widget: Button "OK"
	variable line2pc_file_number			;# Int: File number

	## Dialog "File statistics"
	variable statistics_counter		0	;# Int: Counter of invocations of this dialog

	## Project details window
	variable PROJECTDETAILSWIN			;# ID of project details window
	variable projectdetails_last_project	{}	;# Project object of the last project details window

	## Custom commands related variables
	variable custom_cmd_dialog_index	0	;# Index of results dialog (to keep win IDs unique)
	variable custom_command_cmd			;# Array of custom commands (shell scripts)
	variable custom_command_options			;# Array of Lists of custom command options
	variable custom_command_desc			;# Array of custom command descriptions
	variable custom_command_PID			;# Array of custom command PIDs (Process IDentifiers)
	variable custom_command_NUM			;# Array of custom command numbers
	variable custom_command_counter		0	;# Counter of custom command invocations

	## Initialize custom commands related variables
	 # Shell scripts
	set custom_command_cmd(0) [mc "echo \"This is a custom command\"\necho \"\tYou can configure it in Main menu->Configure->Edit user commands.\"\necho \"\tCustom commands are intended for running external programs from this IDE (e.g. program uploaders)\""]

	append custom_command_cmd(0) "\n\n"
	append custom_command_cmd(0) "echo \"\"\n"
	append custom_command_cmd(0) "echo \"%%URIS == \\\"%URIS\\\"\"\n"
	append custom_command_cmd(0) "echo \"%%URI == \\\"%URI\\\"\"\n"
	append custom_command_cmd(0) "echo \"%%directory == \\\"%directory\\\"\"\n"
	append custom_command_cmd(0) "echo \"%%filename == \\\"%filename\\\"\"\n"
	append custom_command_cmd(0) "echo \"%%basename == \\\"%basename\\\"\"\n"
	append custom_command_cmd(0) "echo \"%%mainfile == \\\"%mainfile\\\"\"\n"
	append custom_command_cmd(0) "echo \"%%line == \\\"%line\\\"\"\n"
	append custom_command_cmd(0) "echo \"%%column == \\\"%column\\\"\"\n"
	append custom_command_cmd(0) "echo \"%%selection == \\\"%selection\\\"\"\n"

	set custom_command_cmd(1) $custom_command_cmd(0)
	set custom_command_cmd(2) $custom_command_cmd(0)
	 # Command options
	set custom_command_options(0) {0 1 0 0}
	set custom_command_options(1) $custom_command_options(0)
	set custom_command_options(2) $custom_command_options(0)
	 # Command descritpions
	set custom_command_desc(0) [mc "More: Main menu -> Configure -> Edit user commands"]
	set custom_command_desc(1) $custom_command_desc(0)
	set custom_command_desc(2) $custom_command_desc(0)
	 # Command Thread IDentifiers
	set custom_command_PID(0) {}
	set custom_command_PID(1) $custom_command_PID(0)
	set custom_command_PID(2) $custom_command_PID(0)
	 # Custom command numbers
	set custom_command_NUM(0) {}
	set custom_command_NUM(1) $custom_command_NUM(0)
	set custom_command_NUM(2) $custom_command_NUM(0)

	## Menu and Toolbar related variables
	 # Menu bar items which require opened project
	variable mainmenu_project_dependent_buttons {
		{ ".mainMenu"
			{ "Edit" "View" "Simulator" "Virtual MCU" "Virtual HW" "Tools"}
		} { ".mainMenu.project"
			{ "Save" "Edit project" "Close without saving" "Save and close"}
		} { ".mainMenu.file"
			{ "New" "Open" "Open recent" "Save" "Save as" "Save all" "Close" "Close all" "File statistics"}
		} { ".mainMenu.configure"
			{ "Configure Compiler"}
		}
	}
	 # Menu bar items which require ENGAGED simulator
	variable mainmenu_simulator_engaged {
		{ ".mainMenu.simulator"
			{ "Step" "Step over" "Animate" "Run"
			"Jump to line" "Find cursor" "Step back" "Clear highlight"
			"Hiberante program" "Resume hibernated program"
			}
		} { ".mainMenu.virtual_mcu"
			{ "Reset" }
		}
	}
	 # Menu bar items which require DISENGAGED simulator
	variable mainmenu_simulator_disengaged {
		{ ".mainMenu.file"
			{ "New" "Open" "Close" "Close all"}
		} { ".mainMenu.edit"
			{ "Undo" "Redo" "Cut" "Paste" "Replace"
			"Comment" "Uncomment" "Indent" "Unindent"}
		} { ".mainMenu.display"
			{ "Read only mode" "Reload"}
		}
		{ ".mainMenu.simulator"
			{ "Debug this file only" }
		} { ".mainMenu.tools"
			{ "Compile" "Disassemble" "Encoding" "End of line"
			"Auto indent" "Change letter case" "Document current function"
			"Compile this file"}
		}
	}
	 # Menu bar items which are not available when editor is in read only mode
	variable mainmenu_editor_readonly {
		{ ".mainMenu.edit"
			{ "Undo" "Redo" "Cut" "Paste" "Replace"
			"Comment" "Uncomment" "Indent" "Unindent"}
		} { ".mainMenu.tools"
			{ "Auto indent" "Change letter case" "Document current function"}
		}
	}
	 # Menu bar items which are not available only for C language
	variable mainmenu_editor_c_only {
		{ ".mainMenu.tools"
			{ "Document current function"}
		}
	}
	 # Menu bar items which are not available when external embedded editor is used
	variable mainmenu_editor_external_na {
		{.mainMenu.tools {
				{Encoding}		{End of line}
				{Auto indent}		{Change letter case}
				{Export as XHTML}	{Export as LaTeX}
				{Auto indent}		{Change letter case}
				{Document current function}
			}
		} {.mainMenu.file {
				{Save}			{Save as}
				{Save all}		{File statistics}
			}
		} {.mainMenu.display {
				{Read only mode}	{Switch to command line}
				{Highlight}		{Show/Hide line numbers}
				{Reload}		{Show/Hide icon border}
			}
		} {.mainMenu.simulator {
				{Find cursor}		{Jump to line}
			}
		} {.mainMenu {
				{Edit}
			}
		}
	}

	 # Toolbar buttons which require opened project
	variable toolbar_project_dependent_buttons {
		new		open		save		save_as
		save_all	close		close_all	undo
		redo		cut		copy		paste
		find		findnext	findprev	replace
		goto		reload		clear		proj_save
		proj_edit	proj_close	proj_close_imm	show_code_mem
		show_ext_mem	start_sim	reset		step
		stepover	animate		run		assemble
		disasm		reformat_code	toHTML		toLaTeX
		cleanup		custom0		custom1		custom2
		change_case	forward		back		clear_hg
		intrmon		hibernate	resume		stepback
		find_sim_cur	line2addr	show_exp_mem	sfrmap
		show_eeprom	show_eem_wr_b	stopwatch	bitmap
		uartmon

		ledpanel	leddisplay	ledmatrix	mleddisplay
		simplekeypad	matrixkeypad	vhw_open	vhw_load
		vhw_save	vhw_saveas	vhw_remove_all	hd44780
		ds1620		vuterm		fintr

		stack		d52
	}
	 # Toolbar buttons which require ENGAGED simulator
	variable toolbar_simulator_engaged {
		reset		step		stepover	animate
		run		clear_hg	find_sim_cur	line2addr
		stepback	hibernate	resume
	}
	 # Toolbar buttons which require DISENGAGED simulator
	variable toolbar_simulator_disengaged {
		new		open		close		close_all
		undo		redo		cut		copy
		paste		replace		reload		assemble
		start_sim0	disasm		reformat_code	change_case
		assemble0	d52
	}
	 # Toolbar items which are not available when editor is in read only mode
	variable toolbar_editor_readonly {
		undo		redo		cut		paste
		replace		reformat_code	change_case
	}
	 # Toolbar items which are not available only for C language
	variable toolbar_editor_c_only {
	}
	 # Toolbar items which are not available when external embedded editor is used
	variable toolbar_editor_external_na {
		save	save_as	undo		redo		cut
		copy	paste	find		findnext	findprev
		replace	goto	reload		reformat_code	change_case
		toHTML	toLaTeX	find_sim_cur	line2addr	save_all
	}

	## This function should be immediately after load of environment.tcl
	 # @return void
	proc initialize {} {
		variable projectmenu	;# ID of Popup menu for project tabs

		menuFactory {
			{command	"Save"			"$project:proj_save"	0
				{__project_pmenu_save}
				"filesave"	"Save this project"}
			{command	"Edit project"		"$project:proj_edit"	0
				{__project_pmenu_edit}
				"configure"	"Edit additional project detail"}
			{separator}
			{command	"Save and close"	"$project:proj_close"	1
				{__project_pmenu_close}
				"fileclose"	"Save and close this project"}
			{command	"Close without saving"	"$project:proj_clsimm"	0
				{__project_pmenu_close_imm}
				"no"	"Close this project"}
			{separator}
			{command	"Move left"		""			5
				{__project_move_to_left}
				"1leftarrow"	"Move this tab to right the beginning of the tab bar"}
			{command	"Move right"		""			5
				{__project_move_to_right}
				"1rightarrow"	"Move this tab to right the end of the tab bar"}
			{separator}
			{command	"Move to beginning"		""		8
				{__project_move_to_beginning}
				"2leftarrow"	"Move this tab to right the beginning of the tab bar"}
			{command	"Move to end"		""			9
				{__project_move_to_end}
				"2rightarrow"	"Move this tab to right the end of the tab bar"}
		} $projectmenu 0 "::X::" 0 {} [namespace current]
	}

	## Switch current project
	 # @parm String project_name - Project object reference
	 # @return void
	proc switch_project {project_name} {
		variable actualProject		;# Object: Current project
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable openedProjects		;# List of opened projects (Object references)
		variable simulator_enabled	;# List of booleans: Simulator engaged

		# Ensure that autocompletion window is closed
		::Editor::close_completion_popup_window_NOW

		if {$actualProjectIdx != -1 && ([lindex $simulator_enabled $actualProjectIdx] == 1)} {
			if {[$actualProject sim_stepover_in_progress]} {
				$actualProject sim_stepover
			} elseif {[$actualProject sim_run_in_progress]} {
				$actualProject sim_run
			} elseif {[$actualProject sim_anim_in_progress]} {
				$actualProject sim_animate
			}
		}

		set actualProject [string trimleft $project_name {:}]
		set actualProjectIdx [lsearch -exact -ascii $openedProjects $actualProject]

		disaena_menu_toolbar_for_current_project
		adjust_title

		$actualProject adjust_compiler_settings
		$actualProject switchfile
	}

	## Enable / Disable menu and toolbar item according to current state of current project
	 # @return void
	proc disaena_menu_toolbar_for_current_project {} {
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project
		variable actualProject		;# Object: Current project
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable simulator_enabled	;# List of booleans: Simulator engaged

		# This procedure requires at least one opened project
		if {$project_menu_locked} {return}

		# Adjust state simulator related menu/toolbar items
		if {[lindex $simulator_enabled $actualProjectIdx] == 1} {
			Unlock_simulator_menu

			# Enable / Disabled stepback buttons
			stepback_button_set_ena [$actualProject simulator_get_SBS_len]
		} else {
			Lock_simulator_menu
			adjust_mainmenu_and_toolbar_to_editor	\
				${::editor_RO_MODE}		\
				[expr {1 == [$actualProject editor_procedure {} get_language {}]}]
		}

		# set MCU name in statusbar, kdb
		.statusbarMCU configure -text [$actualProject cget -P_option_mcu_type]

		## Disable/Enable menu+toolbar entries related to simulator controls which depends on current MCU
		disena_simulator_menu $actualProject
	}

	## Disable/Enable menu+toolbar entries related to simulator
	 # +controls which depends on current MCU
	 # @parm Object project - Current project
	 # @return void
	proc disena_simulator_menu {project} {
		# Enable/Disable controls related to hexadecimal editors
		ena_dis_menu_buttons 0 {{ ".mainMenu.virtual_mcu"
			{ "Show XDATA memory" "Show ERAM" "Show EEPROM write buffer" "Show Data EEPROM"}
		}}
		ena_dis_iconBar_buttons	0 .mainIconBar. {
			show_ext_mem show_exp_mem show_eeprom show_eem_wr_b
		}
		set toolbar {}
		set mainmenu {}
		if {[lindex [$project cget -procData] 8]} {
			lappend toolbar {show_exp_mem}
			lappend mainmenu {Show ERAM}
		}
		if {[$project cget -P_option_mcu_xdata]} {
			lappend toolbar {show_ext_mem}
			lappend mainmenu {Show XDATA memory}
		}
		if {[lindex [$project cget -procData] 32]} {
			lappend toolbar {show_eeprom}
			lappend toolbar {show_eem_wr_b}
			lappend mainmenu {Show EEPROM write buffer}
			lappend mainmenu {Show Data EEPROM}
		}
		ena_dis_menu_buttons	1 [list [list {.mainMenu.virtual_mcu} $mainmenu]]
		ena_dis_iconBar_buttons	1 .mainIconBar. $toolbar
	}

	## Ensure than simulator isn't engaged
	 # @parm Bool message - Invoke error message if simulator is engaged
	 # @return Bool - result (1 == is engaged; 0 == is not engaged)
	proc simulator_must_be_disabled {message} {
		variable simulator_enabled	;# List of booleans: Simulator engaged
		variable actualProjectIdx	;# Index of the current project in $openedProjects

		if {[lindex $simulator_enabled $actualProjectIdx] == {}} {
			return 1
		}

		if {[lindex $simulator_enabled $actualProjectIdx] == 1} {
			if {$message} {
				tk_messageBox				\
					-parent .			\
					-title [mc "Unable to comply"]	\
					-icon info			\
					-type ok			\
					-message [mc "Simulator is engaged, shutdown the simulator first."]
			}
			return 1
		}

		return 0
	}

	## New file
	 # @return void
	proc __new {} {
		variable actualProject			;# Object: Current project
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 1]} {return}

		# Use dialog "Open file" to create new file with embedded external editor
		if {${::Editor::editor_to_use}} {
			__open 1
			return
		}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Create new editor
		$actualProject editor_new

		set critical_procedure_in_progress 0
	}

	## Open file
	 # @parm Bool p_open_f_external_editor=0 - 1 == New file (for embedded external editor); 0 == Open an existing file
	 # @return void
	proc __open {{p_open_f_external_editor 0}} {
		variable actualProject			;# Object: Current project
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable open_f_external_editor		;# Bool: Use procedure __open to open new file for embedded external editor

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 1]} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Parse input arguments
		set open_f_external_editor $p_open_f_external_editor
		if {$open_f_external_editor} {
			set title [mc "New file - MCU 8051 IDE"]
		} else {
			set title [mc "Open file - MCU 8051 IDE"]
		}

		# Invoke the file selection dialog
		switch -- [file extension [lindex [$actualProject editor_procedure {} getFileName {}] 1]] {
			{.asm}	{set defaultmask 0}
			{.c}	{set defaultmask 1}
			{.h}	{set defaultmask 2}
			{.lst}	{set defaultmask 3}
			default	{set defaultmask 4}
		}
		set directory [lindex [$actualProject editor_procedure {} getFileName {}] 0]
		if {$directory == {.}} {
			set directory [$actualProject cget -projectPath]
		}
		catch {delete object fsd}
		KIFSD::FSD fsd	 					\
			-title $title -directory $directory		\
			-defaultmask $defaultmask -multiple 1 -filetypes [list \
				[list [mc "Assembly language"]	{*.asm}] \
				[list [mc "C source"]		{*.c}] \
				[list [mc "C header"]		{*.h}] \
				[list [mc "Code listing"]	{*.lst}] \
				[list [mc "All files"]		{*}] \
			]

		# Open file after press of OK button
		fsd setokcmd {
			foreach filename [X::fsd get] {
				if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
					if {![regexp "^(~|/)" $filename]} {
					set filename "[${::X::actualProject} cget -ProjectDir]/$filename"
					}
				} else {	;# Microsoft windows way
					if {![regexp {^\w:} $filename]} {
						set filename [file join [${::X::actualProject} cget -ProjectDir] $filename]
					}
				}
				set filename [file normalize $filename]

				if {[file isdirectory $filename]} {
					tk_messageBox		\
						-type ok	\
						-icon warning	\
						-parent .	\
						-title [mc "Operation aborted"] \
						-message [mc "The file you choosed appears to be a directory:\n%s\n\nSuch an operation doesn't make sense." $filename]
					continue
				}

				# Open the specified file
				if {${::X::open_f_external_editor} || [file exists $filename]} {
					if {[${::X::actualProject} openfile $filename 1	\
						[X::fsd get_window_name] def def 0 0 {}] != {}
					} then {
						${::X::actualProject} switch_to_last
						update idletasks
						${::X::actualProject} editor_procedure {} parseAll {}

						# Make LST read only
						if {[file extension $filename] == {.lst}} {
							set ::editor_RO_MODE 1
							${::X::actualProject} switch_editor_RO_MODE
						}

						::X::recent_files_add 1 $filename
					}

				} else {
					if {!${::Editor::editor_to_use}} {
						tk_messageBox		\
							-type ok	\
							-icon warning	\
							-parent .	\
							-title [mc "File not found - MCU 8051 IDE"] \
							-message [mc "The selected file do not exist:\n%s" $filename]
					}

					${::X::actualProject} editor_new
					${::X::actualProject} save_as $filename 1
				}
			}
		}

		# activate the dialog
		fsd activate

		adjust_title
		set critical_procedure_in_progress 0
	}

	## Save file
	 # @return void
	proc __save {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Save file
		$actualProject editor_procedure {} save {}

		set critical_procedure_in_progress 0
	}

	## Save file under different filename
	 # @return void
	proc __save_as {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# Won't save read-only file
		if {[$actualProject editor_procedure {} cget {-ro_mode}]} {
			return
		}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Invoke the dialog
		set filename [$actualProject editor_procedure {} getFileName {}]
		switch -- [file extension [lindex $filename 1]] {
			{.asm}	{set defaultmask 0}
			{.c}	{set defaultmask 1}
			{.h}	{set defaultmask 2}
			default	{set defaultmask 3}
		}
		set directory [lindex [$actualProject editor_procedure {} getFileName {}] 0]
		if {$directory == {.}} {
			set directory [$actualProject cget -projectPath]
		}
		catch {delete object fsd}
		KIFSD::FSD fsd	 					\
			-initialfile [lindex $filename 1]		\
			-title [mc "Save file - MCU 8051 IDE"]		\
			-directory $directory				\
			-defaultmask $defaultmask -multiple 0 -filetypes [list	\
				[list [mc "Assembly language"]	{*.asm}]	\
				[list [mc "C source"]		{*.c}]		\
				[list [mc "C header"]		{*.h}]		\
				[list [mc "All files"]		{*}]		\
			]

		# Save file after press of OK button
		fsd setokcmd {
			set filename [X::fsd get]
			${::X::actualProject} save_as $filename
		}

		# activate the dialog
		fsd activate

		set critical_procedure_in_progress 0
	}

	## Save all opened file of the current project
	 # @return void
	proc __save_all {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Save all opened files
		$actualProject editor_save_all

		set critical_procedure_in_progress 0
	}

	## Close the curent file
	 # @return void
	proc __close {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 1]} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Close file
		$actualProject editor_close 1 {}

		set critical_procedure_in_progress 0
	}

	## Close all opened files
	 # @return void
	proc __close_all {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 1]} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Close all files
		$actualProject editor_close_all 1 0

		set critical_procedure_in_progress 0
	}

	## Take back the last operation
	 # @return void
	proc __undo {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} return
		if {$critical_procedure_in_progress} {return}

		# Undo
		$actualProject editor_procedure {} undo {}
	}

	## Take back the last undo operation
	 # @return void
	proc __redo {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} return
		if {$critical_procedure_in_progress} {return}

		# Redo
		$actualProject editor_procedure {} redo {}
	}

	## Copy selected text to clipboard
	 # @return void
	proc __copy {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} return
		if {$critical_procedure_in_progress} {return}

		# Copy
		$actualProject editor_procedure {} copy {}
	}

	## Cut selected text (copy to clipboard and remove)
	 # @return void
	proc __cut {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} return
		if {$critical_procedure_in_progress} {return}

		# Cut
		$actualProject editor_procedure {} cut {}
	}

	## Paste text from clipboard
	 # @return void
	proc __paste {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} return
		if {$critical_procedure_in_progress} {return}

		# Paste
		$actualProject editor_procedure {} paste {}
	}

	## Indent selected text or the current line
	 # @return void
	proc __indent {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} return
		if {$critical_procedure_in_progress} {return}

		# Indent
		$actualProject editor_procedure {} indent {}
	}

	## Unindent selected text or the current line
	 # @return void
	proc __unindent {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} return
		if {$critical_procedure_in_progress} {return}

		# Unindent
		$actualProject editor_procedure {} unindent {}
	}

	## Invoke find dialog
	 # @return void
	proc __find {} {
		variable actualProject			;# Object: Current project
		variable find_String		{}	;# Search string
		variable find_option_CS			;# Bool: Case sensitive
		variable find_option_back		;# Bool: Search backwards (checkbox)
		variable find_option_cur		;# Book: Search from cursor
		variable find_option_sel		;# Bool: Search only in the seleted text
		variable find_option_reg		;# Bool: Consider search string to be a regular expression
		variable find_allow_selection		;# Bool: There is some selected text in editor
		variable find_history			;# List of the last 10 search strings
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {${::Editor::editor_to_use}} {return}
		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		# Determinate selected text
		set selectedText [$actualProject editor_procedure {} getselection {}]
		if {$selectedText != {}} {
			set find_String $selectedText
		}

		# Create a new toplevel window for the dialog
		set win [toplevel .find -class {Find dialog} -bg ${::COMMON_BG_COLOR}]

		# String to search for
		label $win.findLabel -compound left -image ::ICONS::16::find -text [mc "Text to find:"]
		set findFrame [ttk::labelframe $win.findFrame	\
			-labelwidget $win.findLabel		\
			-relief flat				\
		]
		pack $findFrame -fill x -expand 1 -pady 10 -padx 5
		pack [ttk::combobox $findFrame.entry	\
			-textvariable X::find_String	\
			-exportselection 0		\
			-values $find_history		\
		] -fill x -expand 1 -padx 10
		DynamicHelp::add $findFrame.entry -text [mc "String to find"]

		# Create and pack options labelframe
		label $win.optionsLabel -compound left -image ::ICONS::16::configure -text [mc "Options"]
		set optionsFrame [ttk::labelframe $win.optionsFrame	\
			-labelwidget $win.optionsLabel			\
		]
		pack $optionsFrame -fill both -expand 1 -padx 10

		# Determinate wheather there is some selected text
		if {[$actualProject editor_procedure {} getselection {}] == {}} {
			set find_allow_selection 0
		} else {
			set find_allow_selection 1
		}

		# Create matrix of option checkbuttons
		set col 0	;# Grid column
		set row 0	;# Grid row
		foreach opt { CS		back		cur		sel		reg		} \
			txt { "Case sensitive"	"Backwards"	"From cursor"	"Selected text"	"Regular expr."	} \
			helptext {
				"Case sensitive search"
				"Search backwards from the specified location"
				"Start search from cursor instead of beginning"
				"Search within selected text only"
				"Use search string as regular expression"
			} \
		{
			# Disable/Enable "in selection" checkbox
			if {$opt == {sel} && !$find_allow_selection}  {
				set state disabled
				set X::find_option_sel 0
			} else {
				set state normal
			}

			# Create checkbutton
			grid [checkbutton $optionsFrame.option_$opt	\
				-text [mc $txt]				\
				-variable X::find_option_$opt		\
				-state $state				\
			] -column $col -row $row -sticky wns
			DynamicHelp::add $optionsFrame.option_$opt -text [mc $helptext]

			incr col
			if {$col == 2} {
				set col 0
				incr row
			}
		}

		# Create and pack 'OK' and 'CANCEL' buttons
		set buttonFrame [frame $win.buttonFrame]
		pack [ttk::button $buttonFrame.ok	\
			-text [mc "Ok"]			\
			-compound left			\
			-image ::ICONS::16::ok		\
			-command {X::find_FIND}		\
		] -side left -padx 2
		pack [ttk::button $buttonFrame.cancel		\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command {X::find_CANCEL} 		\
		] -side left -padx 2
		pack $buttonFrame -pady 5

		# Events binding (Enter == Find; Escape == Cancel)
		bind $win <KeyRelease-Return>	{X::find_FIND; break}
		bind $win <KeyRelease-KP_Enter>	{X::find_FIND; break}
		bind $win <KeyRelease-Escape>	{X::find_CANCEL; break}

		# Nessesary window manager options -- for modal window
		wm iconphoto $win ::ICONS::16::find
		wm title $win [mc "Find - MCU 8051 IDE"]
		wm minsize $win 300 210
		wm protocol $win WM_DELETE_WINDOW {
			X::find_CANCEL
		}
		wm transient $win .
		update
		raise $win
		catch {grab $win}
		focus $findFrame.entry
		catch {
			$findFrame.entry.e selection range 0 end
		}
		tkwait window $win
	}

	## Cancel find dialog -- auxiliary procedure for '__find'
	 # @return void
	proc find_CANCEL {} {
		if {![winfo exists .find]} {return}

		destroy .find
		grab release .find
	}

	## Perform search -- auxiliary procedure for '__find'
	 # @return Bool - result
	proc find_FIND {} {
		variable actualProject		;# Object: Current project
		variable find_allow_selection	;# Bool: There is some selected text in editor
		variable find_String		;# Search string
		variable find_forward_index	;# Search index for forward search
		variable find_backward_index	;# Search index for backward search
		variable find_option_CS		;# Bool: Case sensitive
		variable find_option_notCS	;# Bool: Case insensitive
		variable find_option_back	;# Bool: Search backwards (checkbox)
		variable find_option_cur	;# Book: Search from cursor
		variable find_option_sel	;# Bool: Search only in the seleted text
		variable find_option_reg	;# Bool: Consider search string to be a regular expression
		variable find_retry_search	;# Bool: Search restarted from beginning/end
		variable find_back_dir		;# Bool: Search backwards (real option)
		variable find_history		;# List of the last 10 search strings

		# Append search string to history
		if {[lsearch -exact -ascii $find_history $find_String] == -1} {
			lappend find_history $find_String
		}
		# History mustn't contain more than 10 items
		if {[llength $find_history] > 10} {
			set find_history [lrange $find_history [expr {[llength $find_history] - 10}] end]
		}

		# New search
		set find_retry_search 0			;# Search has not been restarted
		set find_back_dir $find_option_back	;# Search backwards/forwards

		# Cancel the find dialog
		find_CANCEL

		# Check for validity of the search string
		if {$find_String == {}} {
			return 0
		}

		# Adjust option "Search in selected text"
		set find_option_notCS [expr {!$find_option_CS}]
		if {!$find_allow_selection} {
			set option_sel 0
		} else {
			set option_sel $find_option_sel
		}

		# Perform search
		set result [$actualProject editor_procedure {} find [list	\
			$find_option_cur	$find_option_back		\
			$find_option_reg	$find_option_notCS		\
			$option_sel		{}				\
			$find_String]]

		# Search failed -> show error message
		if {[lindex $result 0] == -1} {
			tk_messageBox		-icon warning	\
				-parent .	-type ok	\
				-title [mc "Unable to execute"]	\
				-message [lindex $result 1]
			return 0
		}

		# Set search indexes
		set find_backward_index	[lindex $result 0]
		set find_forward_index	[lindex $result 1]

		# Finalize
		set matches [lindex $result 2]
		Sbar [mc "Search result: %s matches found" $matches]	;# Show final result
		if {$matches == 0} retry_search				;# Ask for retry

		# Success
		return 1
	}

	## Retry search -- auxiliary procedure for '__find'
	 # Useful when search cursor reach beginning/end of the document
	 # @return Bool result
	proc retry_search {} {
		variable find_retry_search	;# Bool: Search restarted from beginning/end
		variable find_String		;# Search string
		variable find_option_back	;# Bool: Search backwards (checkbox)
		variable find_option_cur	;# Book: Search from cursor
		variable find_backward_index	;# Search index for backward search
		variable find_forward_index	;# Search index for forward search
		variable find_back_dir		;# Bool: Search backwards (real option)
		variable find_next_prev_in_P	;# Bool: Procedure 'find_next_prev' in progress

		# There is only one allowed retry
		if {$find_retry_search || !$find_option_cur} {
			set find_retry_search 0
			tk_messageBox				\
				-icon warning			\
				-type ok			\
				-title [mc "Find - %s" ${::APPNAME}]	\
				-message [mc "Search string '%s' not found !" $find_String] \
				-parent .
			set find_next_prev_in_P 0
			return
		}

		set find_option_cur_tmp	$find_option_cur	;# Search cursor
		set find_retry_search	1			;# This is the first retry

		# Backward search
		if {$find_back_dir} {
			if {[tk_messageBox		\
				-icon question		\
				-type yesno		\
				-parent .		\
				-title [mc "Find - %s" ${::APPNAME}]	\
				-message [mc "Beginning of document reached\n\nContinue from end ?"] \
			] == {yes}} then {
				set find_next_prev_in_P		0
				set find_backward_index		end
				set find_forward_index		1.0
				set find_option_cur		0
				# Retry search
				find_next_prev [expr {!$find_option_back}]
			}

		# Forward search
		} else {
			if {[tk_messageBox	\
				-icon question	\
				-type yesno	\
				-parent .	\
				-title [mc "Find - %s" ${::APPNAME}]	\
				-message [mc "End of document reached\n\nContinue from beginning ?"] \
			] == {yes}} then {
				set find_next_prev_in_P		0
				set find_backward_index		end
				set find_forward_index		1.0
				set find_option_cur		0
				# Retry search
				find_next_prev $find_option_back
			}
		}

		set find_next_prev_in_P 0
		set find_option_cur $find_option_cur_tmp
		set find_retry_search 0
	}

	## Find next occurrence of the search string
	 # @return void
	proc __find_next {} {
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		# Perform search
		find_next_prev 0
	}

	## Find previous occurrence of the search string
	 # @return void
	proc __find_prev {} {
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		# Perform search
		find_next_prev 1
	}

	## Find next/previous occurrence of the search string
	 # @parm Bool back_dir	- Search backwards
	 # @return void
	proc find_next_prev {back_dir} {
		variable actualProject		;# Object: Current project
		variable find_String		;# Search string
		variable find_backward_index	;# Search index for backward search
		variable find_forward_index	;# Search index for forward search
		variable find_option_notCS	;# Bool: Case insensitive
		variable find_option_back	;# Bool: Search backwards (checkbox)
		variable find_option_cur	;# Book: Search from cursor
		variable find_option_sel	;# Bool: Search only in the seleted text
		variable find_option_reg	;# Bool: Consider search string to be a regular expression
		variable find_retry_search	;# Bool: Search restarted from beginning/end
		variable find_back_dir		;# Bool: Search backwards (real option)
		variable find_next_prev_in_P	;# Bool: Procedure 'find_next_prev' in progress

		# This function is not available for exeternal embedded editors
		if {${::Editor::editor_to_use}} {return}

		# This function cannot run multithreaded
		if {$find_next_prev_in_P} {return}
		set find_next_prev_in_P 1

		# Check for valid search index
		if {![info exists find_backward_index]} {
			Sbar [mc "Editor: Nothing to search ..."]
			set find_next_prev_in_P 0
			return
		}

		# Determinate direction
		set find_back_dir [expr {$find_option_back ^ $back_dir}]

		# Determinate start index
		if {$find_option_cur} {
			set editor [[$actualProject get_current_editor_object] cget -editor]
			if {$find_back_dir} {
				if {[$editor compare $find_forward_index == insert]} {
					$editor mark set insert $find_backward_index
				}
			} else {
				if {[$editor compare $find_backward_index == insert]} {
					$editor mark set insert $find_forward_index
				}
			}
			set index insert
		} else {
			if {$find_back_dir} {
				set index $find_backward_index
			} else {
				set index $find_forward_index
			}
		}

		# Perform search
		set result [$actualProject editor_procedure {} find [list	\
			$find_option_cur	$find_back_dir			\
			$find_option_reg	$find_option_notCS		\
			$find_option_sel	$index				\
			$find_String]]

		# Set search indexes
		set find_backward_index	[lindex $result 0]
		set find_forward_index	[lindex $result 1]

		# Finalize
		set matches [lindex $result 2]
		Sbar [mc "Search result: %s matches found" $matches]	;# Show final result
		if {$matches == 0} retry_search				;# Retry search if this one failed
		set find_next_prev_in_P 0
	}

	## Invoke dialog to replace one string with another (in editor)
	 # @return void
	proc __replace {} {
		variable actualProject			;# Object: Current project
		variable replace_String		{}	;# String to replace
		variable replace_Replacement	{}	;# Replacement for the search string
		variable replace_option_CS		;# Bool: Case sensitive
		variable replace_option_back		;# Bool: Search backwards (checkbox)
		variable replace_option_cur		;# Book: Search from cursor
		variable replace_option_reg		;# Bool: Consider search string to be a regular expression
		variable replace_option_prompt		;# Bool: Prompt on replace
		variable replace_search_history		;# List of the last 10 search strings
		variable replace_repl_history		;# List of the last 10 replacement strings
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {${::Editor::editor_to_use}} {return}
		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} {return}
		if {$critical_procedure_in_progress} {return}

		# Determinate selected text
		set selectedText [$actualProject editor_procedure {} getselection {}]
		if {$selectedText != {}} {
			set replace_String $selectedText
		}

		# Create a new toplevel window for the dialog
		set win [toplevel .replace -class {Replace dialog} -bg ${::COMMON_BG_COLOR}]

		# Create labelframe "String to find"
		label $win.findLabel -compound left -image ::ICONS::16::find -text [mc "Text to find: "]
		set findFrame [ttk::labelframe $win.findFrame	\
			-labelwidget $win.findLabel		\
			-relief flat				\
		]
		pack $findFrame -fill x -expand 1 -pady 10 -padx 5
		pack [ttk::combobox $findFrame.entry		\
			-textvariable X::replace_String		\
			-exportselection 0			\
			-values $replace_search_history		\
		] -fill x -expand 1 -padx 10
		DynamicHelp::add $findFrame.entry -text [mc "String to replace"]
		pack $findFrame

		# Create labelframe "Replace with"
		set replaceFrame [ttk::labelframe $win.replaceFrame	\
			-text [mc "Replace with:"]			\
			-relief flat					\
		]
		pack $replaceFrame -fill x -expand 1 -pady 5 -padx 5
		pack [ttk::combobox $replaceFrame.entry		\
			-textvariable X::replace_Replacement	\
			-exportselection 0			\
			-values $replace_repl_history		\
		] -fill x -expand 1 -padx 10
		DynamicHelp::add $replaceFrame.entry -text [mc "Replacement for search string"]

		# Create and pack options checkboxes labelframe
		label $win.optionsLabel -compound left -image ::ICONS::16::configure -text [mc "Options"]
		set optionsFrame [ttk::labelframe $win.optionsFrame	\
			-labelwidget $win.optionsLabel			\
		]
		pack $optionsFrame -fill both -expand 1 -padx 10

		# Create matrix of option checkboxes
		set col 0	;# Grid column
		set row 0	;# Grid row
		foreach opt { CS		back		cur		reg		prompt} \
			txt { "Case sensitive"	"Backwards"	"From cursor"	"Regular expr."	"Prompt on replace"} \
			helptext {
				"Case sensitive search"
				"Search backwards from the specified location"
				"Start search from cursor instead of beginning"
				"Use search string as regular expression"
				"Prompt on replace"
			} \
		{

			# Create checkbutton
			grid [checkbutton $optionsFrame.option_$opt	\
				-text [mc $txt]				\
				-variable X::replace_option_$opt	\
			] -column $col -row $row -sticky wns
			DynamicHelp::add $optionsFrame.option_$opt -text [mc $helptext]

			incr col
			if {$col == 2} {
				set col 0
				incr row
			}
		}

		# Create and pack 'OK' and 'CANCEL' buttons
		set buttonFrame [frame $win.buttonFrame]
		pack [ttk::button $buttonFrame.ok	\
			-text [mc "Ok"]			\
			-compound left			\
			-image ::ICONS::16::ok		\
			-command {X::replace_REPLACE}	\
		] -side left -padx 2
		pack [ttk::button $buttonFrame.cancel		\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command {X::replace_CANCEL}		\
		] -side left -padx 2
		pack $buttonFrame -pady 5

		# Events binding (Enter == Replace; Escape == Cancel)
		bind $win <KeyRelease-Return>	{X::replace_REPLACE; break}
		bind $win <KeyRelease-KP_Enter>	{X::replace_REPLACE; break}
		bind $win <KeyRelease-Escape>	{X::replace_CANCEL; break}

		# Nessesary window manager options -- for modal window
		wm iconphoto $win ::ICONS::16::find
		wm title $win [mc "Replace - MCU 8051 IDE"]
		wm minsize $win 300 270
		wm protocol $win WM_DELETE_WINDOW {
			X::replace_CANCEL
		}
		wm transient $win .
		update
		raise $win
		catch {grab $win}
		focus $findFrame.entry
		catch {
			$findFrame.entry.e selection range 0 end
		}
		tkwait window $win
	}

	## Perform replacement -- auxiliary procedure for '__replace'
	 # @return Bool - result
	proc replace_REPLACE {} {
		variable actualProject		;# Object: Current project
		variable replace_String		;# String to replace
		variable replace_Replacement	;# Replacement for the search string
		variable replace_option_CS	;# Bool: Case sensitive
		variable replace_option_back	;# Bool: Search backwards (checkbox)
		variable replace_option_cur	;# Book: Search from cursor
		variable replace_option_reg	;# Bool: Consider search string to be a regular expression
		variable replace_option_prompt	;# Bool: Prompt on replace
		variable replace_search_history	;# List of the last 10 search strings
		variable replace_repl_history	;# List of the last 10 replacement strings

		# Append search string to history
		if {[lsearch -exact -ascii $replace_search_history $replace_String] == -1} {
			lappend replace_search_history $replace_String
		}
		# History mustn't contain more than 10 items
		if {[llength $replace_search_history] > 10} {
			set replace_search_history [lrange $replace_search_history	\
				[expr {[llength $replace_search_history] - 10}] end]
		}

		# Append replace string to history
		if {[lsearch -exact -ascii $replace_repl_history $replace_Replacement] == -1} {
			lappend replace_repl_history $replace_Replacement
		}
		# History mustn't contain more than 10 items
		if {[llength $replace_repl_history] > 10} {
			set replace_repl_history [lrange	\
				$replace_repl_history		\
				[expr {[llength $replace_repl_history] - 10}]	\
				end	\
			]
		}

		# Cancel the replace dialog
		replace_CANCEL

		# Perform replacement
		set replace_option_notCS [expr {!$replace_option_CS}]
		if {![$actualProject editor_procedure {} replace [list		\
				$replace_option_cur	$replace_option_back	\
				$replace_option_reg	$replace_option_notCS	\
				$replace_String	$replace_Replacement		\
				$replace_option_prompt	X::replace_prompt]
		]} then {
			if {!$replace_option_cur} {return}

			set replace_option_cur_tmp $replace_option_cur
			set replace_option_cur 0

			# Retry search
			if {$replace_option_back} {
				if {[tk_messageBox	\
					-icon question	\
					-type yesno	\
					-parent .	\
					-title [mc "Replace - %s" ${::APPNAME}]	\
					-message [mc "Beginning of document reached\n\nContinue from end ?"] \
				]} then {
					replace_REPLACE
				}
			} else {
				if {[tk_messageBox	\
					-icon question	\
					-type yesno	\
					-parent .	\
					-title [mc "Replace - %s" ${::APPNAME}]	\
					-message [mc "End of document reached\n\nContinue from beginning ?"] \
				]} then {
					replace_REPLACE
				}
			}

			set replace_option_cur $replace_option_cur_tmp
		}
	}

	## Cancel replace dialog -- auxiliary procedure for '__replace'
	 # @return bool
	proc replace_CANCEL {} {
		destroy .replace
		grab release .replace
	}

	## Invoke dialog "Replace confirmation"
	 # @return bool
	proc replace_prompt {} {
		variable replace_prompt_opened		;# Bool: Replace prompt dialog opened
		variable replace_prompt_return_value	;# Replace prompt dialog return value
		variable replace_prompt_geometry	;# Geometry of replace prompt dialog window

		# Dialog already opened -> close it
		if {$replace_prompt_opened} {
			replace_prompt_DESTROY
		# Open the dialog
		} else {
			set replace_prompt_opened 1

			# Create dialog window and restore previous geometry
			toplevel .replace_prompt -class {Replace prompt dialog} -bg ${::COMMON_BG_COLOR}
			if {[info exists replace_prompt_geometry]} {
				wm geometry .replace_prompt $replace_prompt_geometry
			}

			# Create window header
			pack [frame .replace_prompt.topFrame] -fill x -expand 1
			pack [label .replace_prompt.topFrame.image	\
				-image ::ICONS::32::help		\
			] -side left -padx 10
			pack [label .replace_prompt.topFrame.label \
				-text [mc "Found an occurrence of your search term.\nWhat do you want to do ?"] \
			] -fill both -expand 1 -side right

			# Create separator
			pack [ttk::separator .replace_prompt.separator -orient horizontal] -fill x -expand 1
			pack [frame .replace_prompt.buttonFrame] -fill x -expand 1

			# Create buttuns
			foreach	id	{ repl		relp_close		repl_all	find_next	close	} \
				text	{ "Replace"	"Replace & close"	"Replace all"	"Find next"	"Close"	} \
				val	{ 0		1			2		3		4	} \
				under	{ 0		2			8		0		0	} {

				pack [ttk::button .replace_prompt.buttonFrame.$id			\
					-text [mc $text] -underline $under				\
					-command "X::replace_prompt_return $val;set wait 1;unset wait"	\
				] -fill x -expand 1 -side left -padx 5
			}

			# Set key-events bindings
			bind .replace_prompt <Alt-Key-r> {
				X::replace_prompt_return 0
				set wait 1
				unset wait
				break
			}
			bind .replace_prompt <Alt-Key-p> {
				X::replace_prompt_return 1
				set wait 1
				unset wait
				break
			}
			bind .replace_prompt <Alt-Key-a> {
				X::replace_prompt_return 2
				set wait 1
				unset wait
				break
			}
			bind .replace_prompt <Alt-Key-f> {
				X::replace_prompt_return 3
				set wait 1
				unset wait
				break
			}
			bind .replace_prompt <Alt-Key-c> {
				X::replace_prompt_return 4
				set wait 1
				unset wait
				break
			}

			# Nessesary window manager options -- modal window
			wm iconphoto .replace_prompt ::ICONS::16::help
			wm title .replace_prompt [mc "Replace confirmation - %s" ${::APPNAME}]
			wm minsize .replace_prompt 480 100
			wm protocol .replace_prompt WM_DELETE_WINDOW {
				X::replace_prompt_DESTROY
			}
			wm transient .replace_prompt .
			raise .replace_prompt

			vwait ::wait
			return $replace_prompt_return_value
		}
	}

	## Cancel replace prompt dialog -- auxiliary procedure for 'replace_prompt'
	 # @return bool
	proc replace_prompt_DESTROY {} {
		variable replace_prompt_opened		;# Bool: Replace prompt dialog opened
		variable replace_prompt_geometry	;# Geometry of replace prompt dialog window

		# Save the current dialog geometry
		set replace_prompt_geometry [wm geometry .replace_prompt]

		# Destroy dislog window
		destroy .replace_prompt
		set replace_prompt_opened 0
	}

	## Cancel replace prompt dialog and set its return value
	 # @parm Int val - result value of the dialog
	 # @return void
	proc replace_prompt_return {val} {
		variable replace_prompt_return_value	;# Replace prompt dialog return value

		set replace_prompt_return_value $val
		replace_prompt_DESTROY
	}

	## Select all text in the editor
	 # @return void
	proc __select_all {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# Select all
		$actualProject editor_procedure {} select_all {}
	}

	## Invoke dialog "Go to"
	 # If simulator is engaged the run this: __simulator_set_PC_by_line
	 # @return void
	proc __goto {} {
		variable actualProject			;# Object: Current project
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable goto				;# Line where to go
		variable editor_lines			;# Number of lines in the current editor
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable simulator_enabled		;# List of booleans: Simulator engaged

		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		if {[lindex $simulator_enabled $actualProjectIdx] == 1} {
			__simulator_set_PC_by_line
			return
		}

		set goto		[$actualProject editor_actLineNumber]
		set editor_lines	[$actualProject editor_linescount]

		# Create dialog window
		set goto_opened 1
		set win [toplevel .goto -class {Go to dialog} -bg ${::COMMON_BG_COLOR}]

		# Create window label frame
		label $win.header -text [mc "Go to line"] -image ::ICONS::16::goto -compound left
		set topFrame [ttk::labelframe $win.topFrame -labelwidget $win.header -relief flat]
		pack $topFrame -expand 1 -fill x -padx 10

		# Create scale widget
		pack [ttk::scale $topFrame.scale	\
			-from 1 -to $editor_lines	\
			-orient horizontal		\
			-variable X::goto		\
			-command "
				set ::X::goto \[expr {int(\${::X::goto})}\]
				$topFrame.spinbox selection range 0 end
			#"	\
		] -side left -expand 1 -fill x -padx 2
		DynamicHelp::add $topFrame.scale	\
			-text [mc "Graphical representation of line where to go"]

		# Create spinbox widget
		pack [ttk::spinbox $topFrame.spinbox		\
			-from 1 -to $editor_lines		\
			-textvariable ::X::goto			\
			-validate key				\
			-validatecommand {::X::goto_validate %P}\
			-width 6				\
		] -side left
		DynamicHelp::add $topFrame.spinbox -text [mc "Line where to go"]

		# Create and pack 'OK' and 'CANCEL' buttons
		set buttonFrame [frame .goto.buttonFrame]
		pack [ttk::button $buttonFrame.ok	\
			-text [mc "Ok"]			\
			-compound left			\
			-image ::ICONS::16::ok		\
			-command {X::goto_OK}		\
		] -side left -padx 2
		pack [ttk::button $buttonFrame.cancel		\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command {X::goto_CANCEL}		\
		] -side left -padx 2
		pack $buttonFrame -pady 5 -padx 5

		# Events binding (Enter == Ok, Esc == CANCEL)
		bind $win <KeyRelease-Return>	{X::goto_OK; break}
		bind $win <KeyRelease-KP_Enter>	{X::goto_OK; break}
		bind $win <KeyRelease-Escape>	{X::goto_CANCEL; break}

		# Focus on the Spinbox
		focus $topFrame.spinbox
		$topFrame.spinbox selection range 0 end

		# Nessesary window manager options -- modal window
		wm iconphoto $win ::ICONS::16::goto
		wm title $win [mc "Go to line - MCU 8051 IDE"]
		wm minsize $win 200 100
		wm protocol $win WM_DELETE_WINDOW {
			X::goto_CANCEL
		}
		wm transient $win .
		catch {grab $win}
		raise $win
		tkwait window $win
	}

	## Validate value of spinbox in the Go to dialog -- auxiliary procedure for '__goto'
	 # @parm
	 # @return bool
	proc goto_validate {value} {
		variable editor_lines	;# Number of lines in the current editor

		if {$value > $editor_lines} {
			return 0
		} else {
			return 1
		}
	}

	## Cancel Go to dialog -- auxiliary procedure for '__goto'
	 # @return bool
	proc goto_CANCEL {} {
		destroy .goto
		grab release .goto
	}

	## Go to line -- auxiliary procedure for '__goto'
	 # @return bool
	proc goto_OK {} {
		variable actualProject	;# Object: Current project
		variable goto		;# Line where to go

		# Go to the specified line
		$actualProject editor_procedure {} goto $goto
		# Destroy dialog window
		goto_CANCEL
	}

	## Comment block of selected text in the editor
	 # @return void
	proc __comment {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} {return}
		if {$critical_procedure_in_progress} {return}

		# Comment
		$actualProject editor_procedure {} comment {}
	}

	## Uncomment block of selected text in the editor
	 # @return void
	proc __uncomment {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} return
		if {$critical_procedure_in_progress} {return}

		# Uncomment
		$actualProject editor_procedure {} uncomment {}
	}

	## Reload the current file
	 # @return void
	proc __reload {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} return
		if {$critical_procedure_in_progress} {return}

		# Reload
		$actualProject filelist_reload_file
	}

	## Invoke directory selection dialog
	 # @parm Widget master - GUI parent
	 # @return void
	proc select_directory {master} {
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable actualProject			;# Object: Current project
		variable select_directory_var	{}	;# Selected directory
		variable defaultDirectory		;# Default directory

		# Determinate initial directory
		if {$project_menu_locked} {
			set directory {~}
		} else {
			set directory [$actualProject cget -projectPath]
		}

		# Invoke the dialog
		catch {delete object fsd}
		KIFSD::FSD fsd	 					\
			-title [mc "Choose directory - MCU 8051 IDE"]	\
			-directory $directory -fileson 0 -master $master

		# Save choice to variable select_directory_var
		fsd setokcmd {
			set X::select_directory_var [X::fsd get]
		}

		fsd activate	;# Activate the dialog

		# Return path to the selected directory
		return $select_directory_var
	}

	## Invoke dialog "New Project"
	 # @return void
	proc __proj_new {} {
		variable available_processors		;# List of supported processors
		variable actualProject			;# Object: Current project
		variable project_new_name	{}	;# Name of the new project
		variable project_new_dir	{}	;# Directory of the new project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_new_processor {AT89S52};# Processor type (e.g. "AT89C2051")
		variable project_new_xdata_ena	0	;# Bool: XDATA memory connected
		variable project_new_xcode_ena	0	;# Bool: XCODE memory connected
		variable project_new_xdata	0	;# Int: Amount of XDATA memory
		variable project_new_xcode	0	;# Int: Amount of XCODE memory
		variable project_new_max_xcode	0	;# Int: Maximum valid value of external program memory
		variable project_new_xd_chb		;# Widget: XDATA enable checkbutton
		variable project_new_xd_scl		;# Widget: XDATA scale
		variable project_new_xd_spb		;# Widget: XDATA spinbox
		variable project_new_xc_chb		;# Widget: XCODE enable checkbutton
		variable project_new_xc_scl		;# Widget: XCODE scale
		variable project_new_xc_spb		;# Widget: XCODE spinbox

		if {$critical_procedure_in_progress} {return}

		# Create dialog window
		set win [toplevel .project_new -class {New project} -bg ${::COMMON_BG_COLOR}]

		# Create window header (text and some icon)
		set header [frame $win.header]

		pack [label $header.image -image ::ICONS::32::wizard] -padx 10 -side left
		pack [label $header.text \
			-text [mc "Create a new project.\n All entries are required. Other options --> edit project."] \
		] -side left -expand 1 -fill x
		pack $header -fill both -expand 1

		# Create labelframe "General"
		set genaral_labelframe [ttk::labelframe $win.general -text [mc "General"]]

		# Entry "Project name"
		set name [ttk::labelframe $genaral_labelframe.name	\
			-text [mc "Project name"]			\
			-relief flat					\
		]
		pack [ttk::entry $name.entry			\
			-textvariable X::project_new_name	\
			-width 20				\
		] -fill x -expand 1
		DynamicHelp::add $name.entry -text [mc "Name of XML file representing the project"]
		pack $name -fill x -expand 1 -padx 10 -pady 5

		# Entry "Project directory"
		set dir [ttk::labelframe $genaral_labelframe.dir	\
			-text [mc "Project directory"]			\
			-relief flat					\
		]
		pack [ttk::entry $dir.entry			\
			-textvariable X::project_new_dir	\
			-width 20				\
		] -side left -fill x -expand 1
		DynamicHelp::add $dir.entry -text [mc "Directory where the project file should be located"]

		pack [ttk::button $dir.choose					\
			-image ::ICONS::16::fileopen				\
			-style Flat.TButton					\
			-command {
				set foo [X::select_directory .project_new]
				if {$foo != {}} {
					set X::project_new_dir $foo
				}
				unset foo
			}	\
		] -side left
		DynamicHelp::add $dir.choose -text [mc "Choose destination location"]

		pack $dir -fill x -expand 1 -padx 10 -pady 5
		pack $genaral_labelframe -fill both -expand 1 -pady 10 -padx 10

		# Create labelframe "Processor"
		set proc_frame		[ttk::labelframe $win.proc_frame -text [mc "Processor"]]
		set proc_frame_top	[frame $proc_frame.top]
		set proc_frame_middle	[frame $proc_frame.middle]
		set proc_frame_middle_left	[ttk::labelframe $proc_frame_middle.middle	\
			-padding 5 -text [mc "External RAM (XDATA)"]]
		set proc_frame_middle_right	[ttk::labelframe $proc_frame_middle.right	\
			-padding 5 -text [mc "External ROM/FLASH (XCODE)"]]

		# Create components of top frame (Type: <ComboBox> <Button>)
		pack [label $proc_frame_top.lbl -text [mc "Type:"]] -side left
		pack [ttk::combobox $proc_frame_top.combo		\
			-values $available_processors			\
			-state readonly					\
			-textvariable ::X::project_new_processor	\
		] -side left -fill x -fill x
		bind $proc_frame_top.combo <<ComboboxSelected>> {::X::proj_new_mcu_changed}
		DynamicHelp::add $proc_frame_top.combo -text [mc "Selected uC"]

		pack [ttk::button $proc_frame_top.but				\
			-text [mc "Select MCU"]					\
			-image ::ICONS::16::back				\
			-compound left						\
			-command {::X::proj_new_select_mcu .project_new}	\
		] -side right -after $proc_frame_top.combo -padx 10
		DynamicHelp::add $proc_frame_top.but -text [mc "Choose processor from database"]

		# Create components of XDATA labelframe
		set project_new_xd_chb [checkbutton $proc_frame_middle_left.checkbutton	\
			-variable ::X::project_new_xdata_ena	\
			-text [mc "Enable"]			\
			-command ::X::proj_new_xdata_disena	\
		]
		pack $project_new_xd_chb -anchor w
		DynamicHelp::add $proc_frame_middle_left.checkbutton		\
			-text [mc "Connect external data memory"]
		set proc_frame_left_btm [frame $proc_frame_middle_left.btm]
		set project_new_xd_scl [ttk::scale $proc_frame_left_btm.scale	\
			-orient horizontal					\
			-variable ::X::project_new_xdata			\
			-from 0 -to 0x10000					\
			-command "
				set ::X::project_new_xdata \[expr {int(\${::X::project_new_xdata})}\]
				$proc_frame_left_btm.spinbox selection range 0 end
			#"	\
		]
		DynamicHelp::add $project_new_xd_scl	\
			-text [mc "Amount of external data memory"]
		pack $project_new_xd_scl -fill x -side left -expand 1 -padx 2
		set project_new_xd_spb [ttk::spinbox $proc_frame_left_btm.spinbox	\
			-textvariable ::X::project_new_xdata				\
			-width 5 -from 0 -to 0x10000					\
			-validate all							\
			-validatecommand {::SelectMCU::validate_xdata %P}		\
		]
		DynamicHelp::add $project_new_xd_spb	\
			-text [mc "Amount of external data memory"]
		pack $project_new_xd_spb -side right -after $project_new_xd_scl
		pack $proc_frame_left_btm -fill both -expand 1

		# Create components of XCODE labelframe
		set project_new_xc_chb [checkbutton $proc_frame_middle_right.checkbutton	\
			-variable ::X::project_new_xcode_ena	\
			-text [mc "Enable"]			\
			-command ::X::proj_new_xcode_disena	\
		]
		pack $project_new_xc_chb -anchor w
		DynamicHelp::add $proc_frame_middle_right.checkbutton		\
			-text [mc "Connect external program memory"]
		set proc_frame_right_btm [frame $proc_frame_middle_right.btm]
		set project_new_xc_scl [ttk::scale $proc_frame_right_btm.scale	\
			-orient horizontal					\
			-variable ::X::project_new_xcode			\
			-from 0 -to 0x10000					\
			-command "
				set ::X::project_new_xcode \[expr {int(\${::X::project_new_xcode})}\]
				$proc_frame_right_btm.spinbox selection range 0 end
			#"	\
		]
		DynamicHelp::add $project_new_xc_scl	\
			-text [mc "Amount of total program memory minus internal program memory"]
		pack $project_new_xc_scl -fill x -side left -expand 1 -padx 2
		set project_new_xc_spb [ttk::spinbox $proc_frame_right_btm.spinbox	\
			-textvariable ::X::project_new_xcode				\
			-width 5 -from 0 -to 0x10000					\
			-validate all							\
			-validatecommand {::X::proj_new_validate_xcode %P}		\
		]
		DynamicHelp::add $project_new_xc_spb	\
			-text [mc "Amount of total program memory minus internal program memory"]
		pack $project_new_xc_spb -side right -after $project_new_xc_scl
		pack $proc_frame_right_btm -fill both -expand 1

		pack $proc_frame_top -anchor w -pady 10 -padx 10 -fill x
		pack $proc_frame_middle_left -side left -fill x -expand 1 -padx 7
		pack $proc_frame_middle_right -side left -fill x -expand 1 -padx 7
		pack $proc_frame_middle -fill both -expand 1 -pady 5
		pack $proc_frame -fill both -expand 1 -padx 10 -pady 10

		# Create 'OK' and 'CANCEL' buttons
		set buttonFrame [frame $win.buttonFrame]
		pack [ttk::button $buttonFrame.ok	\
			-text [mc "Ok"]			\
			-compound left			\
			-image ::ICONS::16::ok		\
			-command {X::project_new_OK}	\
		] -side left -padx 2
		pack [ttk::button $buttonFrame.cancel		\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command {X::project_new_CANCEL}	\
		] -side left -padx 2
		pack $buttonFrame -pady 5

		focus -force $name.entry

		# Adjust XDATA & XCODE controls
		proj_new_mcu_changed

		# Events binding (Enter == Ok; Escape == Cancel)
		bind $win <Key-Return>		{X::project_new_OK; break}
		bind $win <Key-KP_Enter>	{X::project_new_OK; break}
		bind $win <Key-Escape>		{X::project_new_CANCEL; break}

		# Nessesary window manager options -- modal window
		wm iconphoto $win ::ICONS::16::filenew
		wm title $win [mc "New project - MCU 8051 IDE"]
		wm minsize $win 400 400
		wm protocol $win WM_DELETE_WINDOW {
			X::project_new_CANCEL
		}
		wm transient $win .
		catch {grab $win}
		raise $win
		tkwait window $win
	}

	## Binding for processor type combobox -modifycmd
	 # Usage: ComboBox -modifycmd ::X::proj_new_mcu_changed
	 # This function gets informations about selected processor
	 # and adjusts XCODE & XDATA memory controls.
	 # @return void
	proc proj_new_mcu_changed {} {
		variable project_new_processor	;# Processor type (e.g. "8051")
		variable project_new_xdata_ena	;# Bool: XDATA memory connected
		variable project_new_xcode_ena	;# Bool: XCODE memory connected
		variable project_new_max_xcode	;# Int: Maximum valid value of external program memory
		variable project_new_xd_chb	;# Widget: XDATA enable checkbutton
		variable project_new_xc_chb	;# Widget: XCODE enable checkbutton
		variable project_new_xc_scl	;# Widget: XCODE scale
		variable project_new_xc_spb	;# Widget: XCODE spinbox

		# Get processor details
		set details [::SelectMCU::get_processor_details $project_new_processor]
		if {$details == {}} {
			puts stderr "Unknown error occurred in ::X::proj_new_mcu_changed !\nPlease check your installation."
			return
		}

		# Enable/Disable XDATA memory enable checkbutton
		if {[lindex $details 0] != {yes}} {
			set project_new_xdata_ena 0
			$project_new_xd_chb configure -state disabled
		} else {
			$project_new_xd_chb configure -state normal
		}

		# Enable/Disable XCODE memory enable checkbutton
		if {[lindex $details 1] != {yes}} {
			set project_new_xcode_ena 0
			$project_new_xc_chb configure -state disabled
		} else {
			$project_new_xc_chb configure -state normal
		}

		# Adjust XCODE memory scale & spinbox maximum value
		set project_new_max_xcode [expr {0x10000 - ([lindex $details 2] * 1024)}]
		$project_new_xc_scl configure -to $project_new_max_xcode
		$project_new_xc_spb configure -to $project_new_max_xcode

		# Enable/Disable XDATA & XCODE scale + XDATA & XCODE spinbox
		proj_new_xdata_disena
		proj_new_xcode_disena
	}

	## Enable/Disable XDATA scale & spinbox according to $project_new_xdata_ena
	 # @return void
	proc proj_new_xdata_disena {} {
		variable project_new_xd_scl	;# Widget: XDATA scale
		variable project_new_xd_spb	;# Widget: XDATA spinbox
		variable project_new_xdata_ena	;# Bool: XDATA memory connected

		# Enable
		if {$project_new_xdata_ena} {
			$project_new_xd_scl state !disabled
			$project_new_xd_spb configure -state normal
		# Disable
		} else {
			$project_new_xd_scl state disabled
			$project_new_xd_spb configure -state disabled
		}
	}

	## Enable/Disable XCODE scale & spinbox according to $project_new_xcode_ena
	 # @return void
	proc proj_new_xcode_disena {} {
		variable project_new_xc_scl	;# Widget: XCODE scale
		variable project_new_xc_spb	;# Widget: XCODE spinbox
		variable project_new_xcode_ena	;# Bool: XCODE memory connected

		# Enable
		if {$project_new_xcode_ena} {
			$project_new_xc_scl state !disabled
			$project_new_xc_spb configure -state normal
		# Disable
		} else {
			$project_new_xc_scl state disabled
			$project_new_xc_spb configure -state disabled
		}
	}

	## Validate content of XCODE spinbox
	 # @parm String string - string to validate
	 # @return Bool - true if validation successful
	proc proj_new_validate_xcode {string} {
		variable project_new_max_xcode	;# Int: Maximum valid value of external program memory
		if {![string is digit $string]} {
			return 0
		}
		if {$string == {}} {
			return 1
		}
		if {$string < 0 || $string > $project_new_max_xcode} {
			return 0
		}
		return 1
	}

	## Invoke MCU selection dialog
	 # @parm Widget win - parent window
	 # @return void
	proc proj_new_select_mcu {win} {
		variable project_new_processor	;# Processor type (e.g. "AT89C2051")
		variable project_new_xdata_ena	;# Bool: XDATA memory connected
		variable project_new_xcode_ena	;# Bool: XCODE memory connected
		variable project_new_xdata	;# Int: Amount of XDATA memory
		variable project_new_xcode	;# Int: Amount of XCODE memory

		# Determinate initial XDATA memory for the dialog
		if {$project_new_xdata_ena} {
			set xdata $project_new_xdata
		} else {
			set xdata 0
		}
		# Determinate initial XCODE memory for the dialog
		if {$project_new_xcode_ena} {
			set xcode $project_new_xcode
		} else {
			set xcode 0
		}

		# Invoke dialog
		set result [SelectMCU::activate $win [list $project_new_processor $xdata $xcode]]
		if {$result == {}} {
			return
		}

		# Process results
		set project_new_processor	[lindex $result 0]
		set project_new_xdata		[lindex $result 1]
		set project_new_xcode		[lindex $result 2]

		# Adjust XCODE & XDATA checkbuttons
		if {$project_new_xdata} {
			set project_new_xdata_ena 1
		} else {
			set project_new_xdata_ena 0
		}
		if {$project_new_xcode} {
			set project_new_xcode_ena 1
		} else {
			set project_new_xcode_ena 0
		}

		proj_new_mcu_changed
	}

	## Cancel dialog "Create new project" -- auxiliary procedure for '__proj_new'
	 # @return void
	proc project_new_CANCEL {} {
		grab release .project_new
		destroy .project_new
	}

	## Create new project -- auxiliary procedure for '__proj_new'
	 # @return void
	proc project_new_OK {} {
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project
		variable actualProject		;# Object: Current project
		variable project_new_name	;# Name of the new project
		variable project_new_dir	;# Directory of the new project
		variable project_edit_defaults	;# Some default project values
		variable project_edit_clock	;# Default clock rate
		variable simulator_enabled	;# List of booleans: Simulator engaged
		variable openedProjects		;# List of opened projects (Object references)
		variable project_new_processor	;# Processor type (e.g. "AT89C2051")
		variable project_new_xdata_ena	;# Bool: XDATA memory connected
		variable project_new_xcode_ena	;# Bool: XCODE memory connected
		variable project_new_xdata	;# Int: Amount of XDATA memory
		variable project_new_xcode	;# Int: Amount of XCODE memory
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time

		# This is critical procedure
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Check for presence of all nessesary informations
		if {$project_new_dir == {} || $project_new_name == {}} {
			tk_messageBox		\
				-icon warning	\
				-type ok	\
				-title [mc "Invalid request"]	\
				-message [mc "Both entries in section general must be filled."] \
				-parent .project_new
			set critical_procedure_in_progress 0
			return 0
		}

		# Adjust project directory
		regsub {[\\\/]$} $project_new_dir {} project_new_dir

		# Check for validity of the specified directory
		if {![file exists $project_new_dir] || ![file isdirectory $project_new_dir]} {
			# Ask for creating a new directory
			set result [tk_messageBox	\
				-icon question		\
				-type yesno		\
				-parent .project_new	\
				-title [mc "Create directory - MCU 8051 IDE"]	\
				-message [mc "The specified directory does not exist do you want to create it ?"]	\
			]
			if {$result == {yes}} {
			# (Yes) -> Create new directory
				if {[catch {file mkdir $project_new_dir}]} {
					tk_messageBox			\
						-icon error		\
						-parent .project_new	\
						-type ok		\
						-title [mc "File access error"] \
						-message [mc "Creation of directory '%s' FAILED !\nPlease check your permissions." $project_new_dir]
					set critical_procedure_in_progress 0
					return 0
				}
			# (No) -> Cancel
			} else {
				set critical_procedure_in_progress 0
				return 0
			}
		} else {
			# Check if this the project does not already exist
			if {[file exists "$project_new_dir/$project_new_name.mcu8051ide"]} {
				# Ask for owerwrite
				if {
					[tk_messageBox			\
						-icon question		\
						-type yesno		\
						-default no		\
						-parent .project_new	\
						-title [mc "File already exists - MCU 8051 IDE"]	\
						-message [mc "Some project with the same name already exists in the specified directory. \nDo you want to overwrite it ?"]	\
					] != {yes}
				} then {
				# (No) -> Cancel
					set critical_procedure_in_progress 0
					return 0
				}
			}
		}

		# Close the dialog window
		project_new_CANCEL

		# Set project values to defaults
		foreach default $project_edit_defaults {
			switch -- [lindex $default 0] {
				{project_edit_calc_rad}	{
					set calc_radix	[lindex $default 1]
				}
				{project_edit_calc_ang}	{
					set calc_angle	[lindex $default 1]
				}
				default {
					set [lindex $default 0] [lindex $default 1]
				}
			}
		}
		set project_new_xdata [expr {int($project_new_xdata)}]
		set project_new_xcode [expr {int($project_new_xcode)}]

		## Format of this list is: {
		 #+	{version date creator_ver}			# tag: tk_mcuide_project
		 #+	{authors copyright license}			# tag: authors copyright license
		 #+	{type clock xdata xcode}			# tag: processor
		 #+	{watches_file scheme main_file auto_sw_enabled}	# tag: options
		 #+	{grid_mode magnification drawing_on
		 #+		mark_flags_true_state mark_flags_latched
		 #+		mark_flags_output active_page}		# tag: graph
		 #+	{description todo}				# tag: descriptin todo
		 #+	{radix angle_unit				# tag: calculator
		 #+		display0 display1 display2
		 #+		memory0 memory1 memory2
		 #+		frequency time mode}
		 #+	{other_options}					# tag: other_options
		 #+	{compiler_options}
		 #+	{files_count {current_file			# tag: files
		 #+		current_file2 pwin_sash pwin_orient}
		 #+		{					# tag: file actual_line md5_hash path bookmarks breakpoints
		 #+			name		active		o_bookmark	p_bookmark
		 #+			file_index	read_only	actual_line	md5_hash
		 #+			path		bookmarks	breakpoints	eol
		 #+			enc		highlight	notes
		 #+		}
		 #+		...
		 #+	}
		 #+ }
		set project_data [list						\
			[list {} [clock format [clock seconds] -format {%D}] {}]\
			[list [file tail [file normalize ~]]  {} {}]		\
			[list							\
				$project_new_processor				\
				$project_edit_clock				\
				$project_new_xdata				\
				$project_new_xcode]				\
			[list {} {} {} 1]					\
			[list {y} 0 0						\
				[string repeat 0 170]				\
				[string repeat 0 170]				\
				[string repeat 0 170]				\
				{state}						\
			]							\
			[list {} {}]						\
			[list $calc_radix $calc_angle {} {} {} {} {} {}]	\
			{} {}							\
			[list 0 [list {} {} 0 {}]]				\
		]

		# Create a new project file
		if {[catch {
			set prj_file [open "$project_new_dir/$project_new_name.mcu8051ide" w 0640]
		}]} then {
			# Failed
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon error	\
				-message [mc "Unable to write to file:\n\"%s\"" "$project_new_dir/$project_new_name.mcu8051ide"]
			set critical_procedure_in_progress 0
			return
		}

		# Fill in the file with project definition data
		puts -nonewline $prj_file [Project::create_project_file_as_string $project_data]
		close $prj_file
		set done 0

		# Insure than the project descriptor is unique
		set projectDescriptor [regsub -all -- {\s} $project_new_name {-}]
		regsub -all {[\\\/\.\,`\!@#\$%\^&:\;\|\*\"\(\)\[\]\{\}]} $projectDescriptor	\
			{_} projectDescriptor
		set projectDescriptor "project_${projectDescriptor}"

		if {[lsearch -exact -ascii ${X::openedProjects} $projectDescriptor] != -1} {
			append project_new_name {(0)}
			append projectDescriptor {_0}

			while {1} {
				if {[lsearch -exact -ascii ${X::openedProjects} $projectDescriptor] == -1} {break}

				regexp {\d+$} $projectDescriptor index
				regsub {_\d+$} $projectDescriptor {} projectDescriptor

				regexp {\d+\)$} $project_new_name index
				set index [string trimright $index {\)}]
				regsub {\(\d+\)$} $project_new_name {} project_new_name

				incr index
				append project_new_name "($index)"
				append projectDescriptor "_$index"
			}
		}

		# Show project notebook
		if {$project_menu_locked} {
			pack .mainFrame.mainNB -expand 1 -fill both
		}

		# Open created project
		lappend openedProjects $projectDescriptor
		lappend simulator_enabled 0
		MainTab ::$projectDescriptor $project_new_name $project_new_dir $project_new_name.mcu8051ide $project_data
		switch_project $projectDescriptor

		::X::recent_files_add 0 [file join [file normalize $project_new_dir] $project_new_name.mcu8051ide]

		# Project opened
		if {$project_menu_locked} {
			Unlock_project_menu
		}
		disaena_menu_toolbar_for_current_project

		# set MCU name in status bar, kdb
		.statusbarMCU configure -text $project_new_processor

		set critical_procedure_in_progress 0
	}

	## Disable menu items and functions functions which are
	 # available only if there is at least one opened project
	 # @return void
	proc Lock_project_menu {} {
		variable project_menu_locked			;# Bool: Indicates than there is at least one opened project
		variable toolbar_project_dependent_buttons	;# Toolbar buttons which require opened project
		variable mainmenu_project_dependent_buttons	;# Menu bar items which require opened project

		# Hide project notebook
		pack forget .mainFrame.mainNB

		# Disable menu items
		set project_menu_locked 1
		ena_dis_menu_buttons 0 $mainmenu_project_dependent_buttons
		ena_dis_iconBar_buttons 0 .mainIconBar. $toolbar_project_dependent_buttons
		adjust_mm_and_tb_ext_editor
	}

	## Enable menu items and functions functions which are available only if there
	 # is at least one opened project and create NoteBook for project tabs
	 # @return void
	proc Unlock_project_menu {} {
		variable project_menu_locked			;# Bool: Indicates than there is at least one opened project
		variable toolbar_project_dependent_buttons	;# Toolbar buttons which require opened project
		variable mainmenu_project_dependent_buttons	;# Menu bar items which require opened project
		variable toolbar_simulator_engaged		;# Toolbar buttons which require ENGAGED simulator
		variable mainmenu_simulator_engaged		;# Menu bar items which require ENGAGED simulator

		# Enable menu items
		set project_menu_locked 0
		ena_dis_menu_buttons 1 $mainmenu_project_dependent_buttons
		ena_dis_menu_buttons 0 $mainmenu_simulator_engaged
		ena_dis_iconBar_buttons 1 .mainIconBar. $toolbar_project_dependent_buttons
		ena_dis_iconBar_buttons 0 .mainIconBar. $toolbar_simulator_engaged
		adjust_mm_and_tb_ext_editor
	}

	## Disable menu entries and toolbar buttons which are functional on when simulator is on
	 # @return void
	proc Lock_simulator_menu {} {
		variable toolbar_simulator_disengaged	;# Toolbar buttons which require DISENGAGED simulator
		variable toolbar_simulator_engaged	;# Toolbar buttons which require ENGAGED simulator
		variable mainmenu_simulator_engaged	;# Menu bar items which require ENGAGED simulator
		variable mainmenu_simulator_disengaged	;# Menu bar items which require DISENGAGED simulator

		ena_dis_menu_buttons 1 $mainmenu_simulator_disengaged
		ena_dis_menu_buttons 0 $mainmenu_simulator_engaged
		ena_dis_iconBar_buttons 1 .mainIconBar. $toolbar_simulator_disengaged
		ena_dis_iconBar_buttons 0 .mainIconBar. $toolbar_simulator_engaged
		adjust_mm_and_tb_ext_editor
	}

	## Enable menu entries and toolbar buttons which are functional on when simulator is on
	 # @return void
	proc Unlock_simulator_menu {} {
		variable toolbar_simulator_disengaged	;# Toolbar buttons which require DISENGAGED simulator
		variable toolbar_simulator_engaged	;# Toolbar buttons which require ENGAGED simulator
		variable mainmenu_simulator_engaged	;# Menu bar items which require ENGAGED simulator
		variable mainmenu_simulator_disengaged	;# Menu bar items which require DISENGAGED simulator

		ena_dis_menu_buttons 0 $mainmenu_simulator_disengaged
		ena_dis_menu_buttons 1 $mainmenu_simulator_engaged
		ena_dis_iconBar_buttons 0 .mainIconBar. $toolbar_simulator_disengaged
		ena_dis_iconBar_buttons 1 .mainIconBar. $toolbar_simulator_engaged
		adjust_mm_and_tb_ext_editor
	}

	## Open project
	 # @return void
	proc __proj_open {} {
		variable defaultDirectory		;# Default directory
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Invoke project selection dialog
		catch {delete object fsd}
		KIFSD::FSD fsd	 					\
			-title [mc "Open project - MCU 8051 IDE"]	\
			-directory $defaultDirectory			\
			-defaultmask 0 -multiple 0 -filetypes [list				\
				[list [mc "MCU 8051 IDE project"]	{*.mcu8051ide}	]	\
				[list [mc "All files"]			{*}		]	\
			]

		# Open the selected after press of OK button
		fsd setokcmd {
			set filename [X::fsd get]
			X::fsd deactivate
			if {![Project::open_project_file $filename]} {
				tk_messageBox		\
					-type ok	\
					-icon warning	\
					-parent .	\
					-title [mc "Error - MCU 8051 IDE"] \
					-message [mc "Unable to load file: %s" $filename]
			} else {
				${::X::actualProject} editor_procedure {} highlight_visible_area {}
				::X::recent_files_add 0 $filename
			}
		}

		fsd activate	;# Activate the dialog

		adjust_title
		disaena_menu_toolbar_for_current_project
		set critical_procedure_in_progress 0
	}

	## Retrieve project related data from object of the current project
	 # @parm Bool all_info - All data (include to do list and such)
	 # @return void
	proc Project_retrieve_data_from_application {all_info} {
		variable actualProject			;# Object: Current project
		variable project_new_processor		;# Processor type (e.g. "AT89C2051")
		variable project_new_xdata_ena		;# Bool: XDATA memory connected
		variable project_new_xcode_ena		;# Bool: XCODE memory connected
		variable project_new_xdata		;# Int: Amount of XDATA memory
		variable project_new_xcode		;# Int: Amount of XCODE memory
		variable project_edit_version		;# Project version
		variable project_edit_date		;# Project date (last update)
		variable project_edit_copyright		;# Copyright information
		variable project_edit_license		;# License information
		variable project_edit_authors		;# Project authors
		variable project_edit_description	;# Project description
		variable project_edit_main_file		;# Project main file
		variable project_watches_file		;# File of register watches definition
		variable project_todo			;# Todo text
		variable project_graph			;# Graph configuration list
		variable project_calculator		;# Calculator list (display contents, etc.)
		variable project_other_options		;# Other project options
		variable project_compiler_options	;# Compiler options
		variable project_files			;# List of project files (special format)
		variable project_file			;# Full name of the project file
		variable project_dir			;# Path to project directory
		variable project_edit_clock		;# Default clock rate
		variable project_scenario_file		;# Scenario file

		set project_edit_version	[ $actualProject cget -P_information_version	]
		set project_edit_date		[ $actualProject cget -P_information_date	]
		set project_edit_authors	[ $actualProject cget -G_information_authors	]
		set project_edit_copyright	[ $actualProject cget -G_information_copyright	]
		set project_edit_license	[ $actualProject cget -G_information_license	]
		set project_edit_clock		[ $actualProject cget -P_option_clock		]
		set project_edit_description	[ $actualProject cget -project_description	]
		set project_new_processor	[ $actualProject cget -P_option_mcu_type	]
		set project_new_xdata		[ $actualProject cget -P_option_mcu_xdata	]
		set project_new_xcode		[ $actualProject cget -P_option_mcu_xcode	]
		set project_edit_main_file	[ $actualProject cget -P_option_main_file	]
		set project_new_xdata_ena	0
		set project_new_xcode_ena	0
		if {$project_new_xdata}		{set project_new_xdata_ena 1}
		if {$project_new_xcode}		{set project_new_xcode_ena 1}
		if {$all_info} {
			set project_graph		[ $actualProject graph_get_config		]
			set project_todo		[ $actualProject TodoProc_read_text_as_sgml	]
			set project_calculator		[ $actualProject get_calculator_list		]
			set project_other_options	[ $actualProject cget -other_options		]
			set project_files		[ $actualProject get_project_files_list		]
			set project_file		[ $actualProject cget -projectFile		]
			set project_dir			[ $actualProject cget -projectPath		]
			set project_watches_file	[ $actualProject getWatchesFileName		]
			set project_scenario_file	[ $actualProject pale_get_scenario_filename	]
			set project_compiler_options	[ $actualProject get_compiler_config		]
		}
	}

	## Free some resources reserved by procedure 'Project_retrieve_data_from_application'
	 # @return void
	proc Project_RDFA_cleanup {} {
		variable project_watches_file	{}	;# File of register watches of the current poject
		variable project_scenario_file	{}	;# Scenario file
		variable project_todo		{}	;# Todo text
		variable project_graph		{}	;# Graph configuration list
		variable project_calculator	{}	;# Calculator list (display contents, etc.)
		variable project_other_options	{}	;# Other project options
		variable project_compiler_options {}	;# Compiler options
		variable project_files		{}	;# List of project files (special format)
		variable project_file		{}	;# Full name of the project file
		variable project_dir		{}	;# Path to project directory
		variable project_edit_clock	{}	;# Default clock rate
	}

	## Save the current project
	 # @return void
	proc __proj_save {} {
		variable actualProject			;# Object: Current project
		variable openedProjects			;# List of opened projects (Object references)
		variable project_edit_version		;# Project version
		variable project_edit_date		;# Project date (last update)
		variable project_edit_copyright		;# Copyright information
		variable project_edit_license		;# License information
		variable project_edit_authors		;# Project authors
		variable project_edit_description	;# Project description
		variable project_edit_clock		;# Default clock rate
		variable project_edit_main_file		;# Project main file
		variable project_todo			;# Todo text
		variable project_graph			;# Graph configuration list
		variable project_calculator		;# Calculator list (display contents, etc.)
		variable project_other_options		;# Other project options
		variable project_compiler_options	;# Compiler options
		variable project_files			;# List of project files (special format)
		variable project_file			;# Full name of the project file
		variable project_dir			;# Path to project directory
		variable project_watches_file		;# File of register watches of the current poject
		variable project_new_processor		;# Processor type (e.g. "AT89C2051")
		variable project_new_xdata		;# Int: Amount of XDATA memory
		variable project_new_xcode		;# Int: Amount of XCODE memory
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable project_scenario_file		;# Scenario file

		if {$project_menu_locked} {return}

		# Do not attempt to save a project with read only flag set
		if {[$actualProject cget -S_flag_read_only]} {
			puts "Read-only project, saving aborted."
			return
		}

		# This is critical procedure
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Save register watches definition file
		if {[$actualProject rightPanel_watch_modified]} {
			$actualProject rightPanel_watch_save {} 1
		}

		# Save PALE Virtual HW connections
		if {[$actualProject pale_modified]} {
			$actualProject pale_save_scenario_file
		}

		# Create project definition data
		Project_retrieve_data_from_application 1
		set project_data [list							\
			[list								\
				[Project::escape_curlies $project_edit_version]		\
				[Project::escape_curlies $project_edit_date]		\
				${::VERSION}]						\
			[list								\
				$project_edit_authors					\
				[Project::escape_curlies $project_edit_copyright]	\
				[Project::escape_curlies $project_edit_license]]	\
			[list								\
				$project_new_processor					\
				$project_edit_clock					\
				$project_new_xdata					\
				$project_new_xcode]					\
			[list								\
				$project_watches_file					\
				$project_scenario_file					\
				$project_edit_main_file					\
				[$actualProject get_file_switching_enabled]]		\
			$project_graph							\
			[list								\
				[Project::escape_curlies $project_edit_description]	\
				[Project::escape_curlies $project_todo]]		\
			$project_calculator						\
			[Project::escape_curlies $project_other_options]		\
			[list $project_compiler_options]				\
			$project_files							\
		]

		set project_data [Project::create_project_file_as_string $project_data]
		set filename "$project_dir/$project_file"
		Project_RDFA_cleanup

		# Create backup copy for the project file
		if {[file exists $filename]} {
			catch {
				file rename -force $filename "$filename~"
			}
		}

		# Save project definition file
		if {[catch {
			set prj_file [open $filename w 0640]
		}]} then {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon error	\
				-title [mc "IO Error"]	\
				-message [mc "Unable to write to file:\n\"%s\"" $filename]
			set critical_procedure_in_progress 0
			return
		}
		puts -nonewline $prj_file $project_data
		close $prj_file

		# Done ...
		Sbar [mc "Project saved to %s" $filename]
		set critical_procedure_in_progress 0
	}

	## Invoke dialog "Edit project"
	 # @parm Bool choose_MCU_now=0 - Invoke MCU selection dialog right away and inore other config options ...
	 # @return void
	proc __proj_edit {{choose_MCU_now 0}} {
		variable actualProject			;# Object: Current project
		variable available_processors		;# List of supported processors

		variable project_edit_version		;# Project version
		variable project_edit_date		;# Project date (last update)
		variable project_edit_copyright		;# Copyright information
		variable project_edit_license		;# License information
		variable project_edit_authors		;# Project authors
		variable project_edit_description	;# Project description
		variable project_edit_clock		;# Default clock rate
		variable project_edit_main_file		;# Project main file

		variable project_edit_main_file_clr_but	;# Widget: Project main file clear button

		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		variable project_new_processor	{8051}	;# Processor type (e.g. "AT89C2051")
		variable project_new_xdata_ena	0	;# Bool: XDATA memory connected
		variable project_new_xcode_ena	0	;# Bool: XCODE memory connected
		variable project_new_xdata	0	;# Int: Amount of XDATA memory
		variable project_new_xcode	0	;# Int: Amount of XCODE memory
		variable project_new_max_xcode	0	;# Int: Maximum valid value of external program memory
		variable project_new_xd_chb		;# Widget: XDATA enable checkbutton
		variable project_new_xd_scl		;# Widget: XDATA scale
		variable project_new_xd_spb		;# Widget: XDATA spinbox
		variable project_new_xc_chb		;# Widget: XCODE enable checkbutton
		variable project_new_xc_scl		;# Widget: XCODE scale
		variable project_new_xc_spb		;# Widget: XCODE spinbox

		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		# Retrieve existing informations about the project
		Project_retrieve_data_from_application 0

		# Create dialog window
		set win [toplevel .project_edit -class {Edit project} -bg ${::COMMON_BG_COLOR}]

		# Create main frames (top.left; top.right; bottom)
		set top_frame		[frame $win.top]
		set bottom_frame	[frame $win.bottom]
		set top_left_frame	[frame $top_frame.left]
		set top_right_frame	[frame $top_frame.right]

		## GENERAL INFORMATION (version, date, authors, copyright, license)
		label $win.lb_general_info_label		\
			-compound left				\
			-text [mc "General information"]	\
			-image ::ICONS::16::contents
		set lb_general_info [ttk::labelframe $top_left_frame.lb_general_info	\
			-labelwidget $win.lb_general_info_label -padding 7 	\
		]
		pack $lb_general_info -fill both -expand 1

		set bframe [frame $lb_general_info.bframe]
		pack $bframe -fill x -expand 1 -anchor w

		# version
		grid [Label $bframe.version_label			\
			-text [mc "Version"]				\
			-helptext [mc "Project version (any string)"]	\
		] -row 1 -column 1 -sticky w
		grid [ttk::entry $bframe.version_entry				\
			-textvariable X::project_edit_version			\
			-validate key						\
			-validatecommand {::X::project_edit_validate %P}	\
		] -row 1 -column 2 -sticky we -columnspan 2
		DynamicHelp::add $bframe.version_entry -text [mc "Project version (any string)"]

		# date
		grid [Label $bframe.date_label			\
			-text [mc "Date"]			\
			-helptext [mc "Project last update"]	\
		] -row 2 -column 1 -sticky w
		grid [ttk::entry $bframe.date_entry				\
			-textvariable X::project_edit_date			\
			-validate key						\
			-validatecommand {::X::project_edit_validate %P}	\
		] -row 2 -column 2 -sticky we
		DynamicHelp::add $bframe.date_entry -text [mc "Project last update"]

		# button 'today'
		grid [ttk::button $bframe.now			\
			-style Flat.TButton			\
			-takefocus 0				\
			-image ::ICONS::16::today		\
			-command {X::project_edit_today}	\
		] -row 2 -column 3 -sticky e
		DynamicHelp::add $bframe.now -text [mc "Fill date entry with the current date"]

		# copyright
		grid [Label $bframe.copyright_label		\
			-text [mc "Copyright"]			\
			-helptext [mc "Copyright information"]	\
		] -row 3 -column 1 -sticky w
		grid [ttk::entry $bframe.copyright_entry			\
			-textvariable X::project_edit_copyright			\
			-validate key						\
			-validatecommand {::X::project_edit_validate %P}	\
		] -row 3 -column 2 -sticky we -columnspan 2
		DynamicHelp::add $bframe.copyright_entry -text [mc "Copyright information"]

		# license
		grid [Label $bframe.license_label		\
			-text [mc "License"]			\
			-helptext [mc "Name of the license"]	\
		] -row 4 -column 1 -sticky w
		grid [ttk::entry $bframe.license_entry				\
			-textvariable X::project_edit_license			\
			-validate key						\
			-validatecommand {::X::project_edit_validate %P}	\
		] -row 4 -column 2 -sticky we -columnspan 2
		DynamicHelp::add $bframe.license_entry -text [mc "Name of the license"]

		# authors
		set tframe [frame .project_edit.top.left.lb_general_info.tframe]
		pack $tframe -fill both -expand 1 -padx 5
		pack [Label $tframe.label					\
			-text [mc "Authors:"]					\
			-helptext [mc "List of project authors (one per line)"]	\
		] -anchor w
		pack [frame $tframe.frame] -fill both -expand 1

		pack [text $tframe.frame.text				\
			-width 0 -height 0				\
			-yscrollcommand "$tframe.frame.scrollbar set"	\
		] -fill both -expand 1 -side left
		$tframe.frame.text insert end $project_edit_authors
		pack [ttk::scrollbar $tframe.frame.scrollbar	\
			-orient vertical			\
			-command "$tframe.frame.text yview"	\
		] -fill y -side right

		## Simulator & Compiler (MCU type, XDATA + XCODE memory + CLOCK)
		label $win.lb_compiler_label		\
			-compound left			\
			-text [mc "Processor"]		\
			-image ::ICONS::16::kcmmemory
		set lb_compiler [ttk::labelframe $top_right_frame.lb_compiler	\
			-labelwidget $win.lb_compiler_label			\
		]
		set proc_frame_top0	[frame $lb_compiler.top0]
		set proc_frame_top1	[frame $lb_compiler.top1]
		set proc_frame_middle	[frame $lb_compiler.middle]
		set proc_frame_middle_left	[ttk::labelframe $proc_frame_middle.middle	\
			-padding 5 -text [mc "External RAM (XDATA)"]]
		set proc_frame_middle_right	[ttk::labelframe $proc_frame_middle.right	\
			-padding 5 -text [mc "External ROM/FLASH (XCODE)"]]

		# MCU clock frequency
		grid [Label $proc_frame_top1.clock_label			\
			-text [mc "Clock \[kHz\]:"] -width 11 -anchor w		\
			-helptext [mc "Default clock used by simulator engine"]	\
		] -row 0 -column 1 -sticky w
		grid [ttk::entry $proc_frame_top1.clock_entry			\
			-width 10						\
			-textvariable X::project_edit_clock			\
			-validate key						\
			-validatecommand {::X::project_edit_CLOCK_validate %P}	\
		] -row 0 -column 3 -sticky w
		DynamicHelp::add $proc_frame_top1.clock_entry	\
			-text [mc "Default clock used by simulator engine"]

		# Main file
		grid [Label $proc_frame_top1.file_label			\
			-text [mc "Main file:"] -width 11 -anchor w	\
			-helptext [mc "Project main file (e.g. main.c)\n(empty string means always compile current file)"]	\
		] -row 1 -column 1 -sticky w
		set project_edit_main_file_clr_but [ttk::button		\
			$proc_frame_top1.clear_but			\
			-style Flat.TButton				\
			-takefocus 0					\
			-image ::ICONS::16::locationbar_erase		\
			-command {
				set ::X::project_edit_main_file {}
				::X::proj_edit_mf_validator {}
			}	\
			-state disabled					\
		]
		DynamicHelp::add $proc_frame_top1.clear_but -text [mc "Clear"]
		grid $project_edit_main_file_clr_but -row 1 -column 2 -sticky w
		grid [ttk::entry $proc_frame_top1.file_entry			\
			-width 25						\
			-validate all						\
			-validatecommand {::X::proj_edit_mf_validator %P}	\
			-textvariable X::project_edit_main_file			\
		] -row 1 -column 3 -sticky we
		proj_edit_mf_validator ${::X::project_edit_main_file}
		DynamicHelp::add $proc_frame_top1.file_entry	\
			-text [mc "Project main file (e.g. main.c)\n(empty string means always compile current file)"]
		grid [ttk::button $proc_frame_top1.file_select_but	\
			-style Flat.TButton				\
			-takefocus 0					\
			-image ::ICONS::16::fileopen			\
			-command {X::project_edit_select_main_file}	\
		] -row 1 -column 4 -sticky e -pady 5
		DynamicHelp::add $proc_frame_top1.file_select_but -text [mc "Select main file"]

		# Create components of top frame (Type: <ComboBox> <Button>)
		pack [label $proc_frame_top0.lbl -text [mc "Type:"] -width 14 -anchor w] -side left
		pack [ttk::combobox $proc_frame_top0.combo	\
			-values $available_processors		\
			-state readonly				\
			-textvariable ::X::project_new_processor\
		] -side left -fill x
		bind $proc_frame_top0.combo <<ComboboxSelected>> {::X::proj_new_mcu_changed}
		DynamicHelp::add $proc_frame_top0.combo -text [mc "Selected uC"]

		pack [ttk::button $proc_frame_top0.but				\
			-text [mc "Select MCU"]					\
			-image ::ICONS::16::back				\
			-compound left						\
			-command {::X::proj_new_select_mcu .project_edit}	\
		] -side right -after $proc_frame_top0.combo -padx 5
		DynamicHelp::add $proc_frame_top0.combo -text [mc "Choose processor from database"]

		# Create components of XDATA labelframe
		set project_new_xd_chb [checkbutton $proc_frame_middle_left.checkbutton	\
			-variable ::X::project_new_xdata_ena	\
			-text [mc "Enable"]			\
			-command ::X::proj_new_xdata_disena	\
		]
		pack $project_new_xd_chb -anchor w
		DynamicHelp::add $proc_frame_middle_left.checkbutton	\
			-text [mc "Connect external data memory"]
		set proc_frame_left_btm [frame $proc_frame_middle_left.btm]
		set project_new_xd_scl [ttk::scale $proc_frame_left_btm.scale	\
			-orient horizontal					\
			-variable ::X::project_new_xdata			\
			-from 0 -to 0x10000					\
			-command "
				set ::X::project_new_xdata \[expr {int(\${::X::project_new_xdata})}\]
				$proc_frame_left_btm.spinbox selection range 0 end
			#"	\
		]
		DynamicHelp::add $project_new_xd_scl	\
			-text [mc "Size of external data memory"]
		pack $project_new_xd_scl -fill x -side left -expand 1 -padx 2
		set project_new_xd_spb [ttk::spinbox $proc_frame_left_btm.spinbox	\
			-textvariable ::X::project_new_xdata				\
			-width 5 -from 0 -to 0x10000					\
			-validate all							\
			-validatecommand {::SelectMCU::validate_xdata %P}		\
		]
		DynamicHelp::add $project_new_xd_spb	\
			-text [mc "Size of external data memory"]
		pack $project_new_xd_spb -side right -after $project_new_xd_scl
		pack $proc_frame_left_btm -fill both -expand 1
		proj_new_xdata_disena

		# Create components of XCODE labelframe
		set project_new_xc_chb [checkbutton $proc_frame_middle_right.checkbutton	\
			-variable ::X::project_new_xcode_ena	\
			-text [mc "Enable"]			\
			-command ::X::proj_new_xcode_disena	\
		]
		pack $project_new_xc_chb -anchor w
		DynamicHelp::add $proc_frame_middle_right.checkbutton		\
			-text [mc "Connect external program memory"]
		set proc_frame_right_btm [frame $proc_frame_middle_right.btm]
		set project_new_xc_scl [ttk::scale $proc_frame_right_btm.scale	\
			-orient horizontal					\
			-variable ::X::project_new_xcode			\
			-from 0 -to 0x10000					\
			-command "
				set ::X::project_new_xcode \[expr {int(\${::X::project_new_xcode})}\]
				$proc_frame_right_btm.spinbox selection range 0 end
			#"	\
		]
		DynamicHelp::add $project_new_xc_scl	\
			-text [mc "Amount of total program memory minus internal program memory"]
		pack $project_new_xc_scl -fill x -side left -expand 1 -padx 2
		set project_new_xc_spb [ttk::spinbox $proc_frame_right_btm.spinbox	\
			-textvariable ::X::project_new_xcode				\
			-width 5 -from 0 -to 0x10000					\
			-validate all							\
			-validatecommand {::X::proj_new_validate_xcode %P}		\
		]
		DynamicHelp::add $project_new_xc_spb	\
			-text [mc "Amount of total program memory minus internal program memory"]
		pack $project_new_xc_spb -side right -after $project_new_xc_scl
		pack $proc_frame_right_btm -fill both -expand 1
		proj_new_xcode_disena

		pack $proc_frame_top0	-anchor w -pady 5 -padx 10
		pack $proc_frame_top1	-anchor w -pady 5 -padx 10
		pack $proc_frame_middle_left -side left -fill x -expand 1 -padx 7
		pack $proc_frame_middle_right -side left -fill x -expand 1 -padx 7
		pack $proc_frame_middle	-fill both -expand 1 -pady 5
		pack $lb_compiler -fill both -expand 1

		# Adjust XDATA & XCODE controls - TODO why is this needed here?
		# editor window has just been created, user hasn't made any selections yet
		# meaning that mcu has not changed
		proj_new_mcu_changed
		# Martin: Oh yes, now I remeber :) proj_new_mcu_changed has to be called here in order to ensure that the
		# scale widgets don't offer values out of range. Try to remove the call and then invoke the project
		# editing dialog and you will see.

		## PROJECT DESCRIPTION
		label $win.lb_desc_label		\
			-compound left			\
			-text [mc "Project description"]	\
			-image ::ICONS::16::edit
		set lb_desc [ttk::labelframe $bottom_frame.lb_desc	\
			-labelwidget $win.lb_desc_label -padding 7	\
		]
		pack $lb_desc -fill both -expand 1
		pack [text $lb_desc.text				\
			-width 0 -height 7				\
			-yscrollcommand "$lb_desc.scrollbar set"	\
		] -fill both -expand 1 -side left
		$lb_desc.text insert end $project_edit_description
		pack [ttk::scrollbar $lb_desc.scrollbar	\
			-orient vertical		\
			-command "$lb_desc.text yview"	\
		] -side right -fill y

		# Pack main frames
		pack $top_left_frame	-fill both -expand 1 -padx 5 -side left -pady 10
		pack $top_right_frame	-fill both -expand 1 -padx 5 -side right -pady 10
		pack $top_frame		-fill both -expand 1 -pady 5
		pack $bottom_frame	-fill both -expand 1 -pady 5 -padx 5

		# Buttons 'Ok' and 'Cancel'
		pack [ttk::separator $win.separator -orient horizontal] -pady 5 -fill x
		set buttons [frame $win.buttons]
		pack [ttk::button $buttons.ok		\
			-text [mc "Ok"]			\
			-compound left			\
			-image ::ICONS::16::ok		\
			-command {X::project_edit_OK}	\
		] -side left -padx 5
		pack [ttk::button $buttons.cancel		\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command {X::project_edit_CANCEL}	\
		] -side left -padx 5
		pack $buttons -anchor center -pady 5

		# Setup some nessesary window manager options -- for modal window
		wm iconphoto $win ::ICONS::16::edit
		wm title $win [mc "Edit project - MCU 8051 IDE"]
		wm minsize $win 660 440
		wm protocol $win WM_DELETE_WINDOW {
			X::project_edit_CANCEL
		}
		wm transient $win .

		if {$choose_MCU_now} {
			wm withdraw $win
			proj_new_select_mcu .
			project_edit_OK
			return
		}

		update
		catch {grab $win}
		raise $win
		tkwait window $win
	}

	## Project main file EntryBox validator
	 # Enables/Disables project main file clear button
	 # @parm String string - EntryBox contents
	 # @return Bool - allways 1
	proc proj_edit_mf_validator {string} {
		variable project_edit_main_file_clr_but	;# Widget: Project main file clear button
		if {[string length $string]} {
			$project_edit_main_file_clr_but configure -state normal
		} else {
			$project_edit_main_file_clr_but configure -state disabled
		}
		return 1
	}

	## Select project main file
	 # -- Auxiliary procedure for __proj_edit
	 # @return void
	proc project_edit_select_main_file {} {
		variable project_edit_main_file		;# Project main file
		variable actualProject			;# Object: Current project

		set ext [file extension $project_edit_main_file]
		if {$ext == {.asm} || $ext == {.inc}} {
			set defaultmask 0
		} elseif {$ext == {.c} || $ext == {.cpp} || $ext == {.cc} || $ext == {.cxx}} {
			set defaultmask 1
		} elseif {$ext == {.h}} {
			set defaultmask 2
		} else {
			set defaultmask 3
		}
		catch {delete object fsd}
		KIFSD::FSD fsd						\
			-initialfile $project_edit_main_file		\
			-directory [$actualProject cget -projectPath]	\
			-title [mc "Select main file - %s - MCU 8051 IDE" $actualProject]	\
			-defaultmask $defaultmask -multiple 0 -filetypes [list	\
				[list [mc "Assembly language"]	{*.asm}	]	\
				[list [mc "C source"]		{*.c}	]	\
				[list [mc "C header"]		{*.h}	]	\
				[list [mc "All files"]		{*}	]	\
			]
		fsd setokcmd {
			set ::X::project_edit_main_file [X::fsd get]
			if {![string first [$::X::actualProject cget -projectPath] $::X::project_edit_main_file]} {
				set ::X::project_edit_main_file	\
					[string replace $::X::project_edit_main_file	\
						0 [string length [$::X::actualProject cget -projectPath]]]
				::X::proj_edit_mf_validator ${::X::project_edit_main_file}
			}
		}
		fsd activate
	}

	## Validate content of entry wingets in dialog "Edit project"
	 # -- axiliary procedure for '__proj_edit'
	 # @parm String string - String to validate
	 # @return Bool - result
	proc project_edit_validate {string} {
		if {[string length $string] > 40} {
			return 0
		} else {
			return 1
		}
	}

	## Set project date to today -- axiliary procedure for '__proj_edit'
	 # @return void
	proc project_edit_today {} {
		variable project_edit_date	;# Project date (last update)

		set sec [clock seconds]
		set project_edit_date [clock format $sec -format {%D}]
	}

	## Validate content of clock entry in dialog "Edit project"
	 # -- axiliary procedure for '__proj_edit'
	 # @parm String number - String to validate
	 # @return Bool - result
	proc project_edit_CLOCK_validate {number} {
		if {![regexp {^\d+(\.\d*)?$} $number]} {return 0}
		if {$number > 99999} {return 0}
		return 1
	}

	## Cancel dialog "Edit project" -- auxiliary procedure for '__proj_edit'
	 # @return void
	proc project_edit_CANCEL {} {
		grab release .project_edit
		destroy .project_edit
	}

	## Save project values -- auxiliary procedure for '__proj_edit'
	 # @return void
	proc project_edit_OK {} {
		variable actualProject		;# Object: Current project
		variable simulator_enabled	;# List of booleans: Simulator engaged
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable project_edit_version	;# Project version
		variable project_edit_date	;# Project date (last update)
		variable project_edit_copyright	;# Copyright information
		variable project_edit_license	;# License information
		variable project_edit_clock	;# Default clock rate
		variable project_edit_main_file	;# Project main file
		variable project_new_processor	;# Processor type (e.g. "AT89C2051")
		variable project_new_xdata_ena	;# Bool: XDATA memory connected
		variable project_new_xcode_ena	;# Bool: XCODE memory connected
		variable project_new_xdata	;# Int: Amount of XDATA memory
		variable project_new_xcode	;# Int: Amount of XCODE memory
		variable project_new_xc_spb	;# Widget: XCODE spinbox
		variable project_edit_defaults	;# Some default project values

		variable projectdetails_last_project {}	;# Project object of the last project details window

		# Adjust XCODE & XDATA values
		if {!$project_new_xdata_ena} {
			set project_new_xdata 0
		}
		if {!$project_new_xcode_ena} {
			set project_new_xcode 0
		}

		# Set MCU name in status bar, kdb
		.statusbarMCU configure -text $project_new_processor

		# Adjust values
		if {$project_edit_clock == {}} {
			set project_edit_clock [lindex $project_edit_defaults {1 1}]
		}
		set project_edit_clock [string trimright $project_edit_clock {.}]
		set project_new_xdata [expr {int($project_new_xdata)}]
		set project_new_xcode [expr {int($project_new_xcode)}]

		# Determinate original values
		set xdata_prev [$actualProject cget -P_option_mcu_xdata]
		set xcode_prev [$actualProject cget -P_option_mcu_xcode]
		set proc_prev [$actualProject cget -P_option_mcu_type]

		# Change object variables
		foreach	parm	{
				P_option_mcu_xdata	P_option_mcu_xcode	P_information_version
				P_information_date	G_information_license	G_information_copyright
				P_option_clock		P_option_mcu_type	P_option_main_file
			} \
			value	{
				project_new_xdata	project_new_xcode	project_edit_version
				project_edit_date	project_edit_license	project_edit_copyright
				project_edit_clock	project_new_processor	project_edit_main_file
			} \
		{
			$actualProject configure -$parm [subst -nocommands "\$$value"]
		}
		$actualProject Simulator_set_clock $project_edit_clock
		$actualProject configure -project_description		\
			[.project_edit.bottom.lb_desc.text get 1.0 end-1c]
		$actualProject configure -G_information_authors		\
			[.project_edit.top.left.lb_general_info.tframe.frame.text get 1.0 end-1c]

		## Adjust simulator control panel, register watches and hex editors
		 # Hex editors
		close_hexedit eram $actualProject
		close_hexedit eeprom $actualProject
		close_hexedit eeprom_wr_bf $actualProject
		if {$xdata_prev != $project_new_xdata} {
			close_hexedit xdata $actualProject
			$actualProject simulator_resize_xdata_memory $project_new_xdata
		}
		if {$xcode_prev != $project_new_xcode} {
			close_hexedit code $actualProject
			$actualProject simulator_resize_code_memory	\
				[expr {$project_new_xcode + 0x10000 - [$project_new_xc_spb cget -to]}]
		}
		 # Simulator control panel and register watches
		if {$proc_prev != $project_new_processor} {
			change_processor $project_new_processor
		}
		 # Adjust register watches
		if {$xdata_prev != $project_new_xdata && $proc_prev == $project_new_processor} {
			$actualProject rightPanel_watch_force_enable
			$actualProject rightPanel_watch_sync_all
			$actualProject rightPanel_watch_disable
		}
		 # Menu and toolbar
		disena_simulator_menu $actualProject

		# Finalize
		Sbar [mc "New values saved."]
		project_edit_CANCEL	;# Close the dialog
		return 1
	}

	## Change current MCU even in running simulator
	 # @parm String new_processor - Processor type
	 # @return void
	proc change_processor {new_processor} {
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable actualProject			;# Object: Current project
		variable simulator_enabled		;# List of booleans: Simulator engaged
		variable actualProjectIdx		;# Index of the current project in $openedProjects

		set intr_mon_opeded [$actualProject interrupt_monitor_is_opened]
		set was_enabled [lindex $simulator_enabled $actualProjectIdx]
		if {$was_enabled} {
			set tmp $critical_procedure_in_progress
			set critical_procedure_in_progress 0
			__initiate_sim
		}

		$actualProject configure -P_option_mcu_type $new_processor
		$actualProject configure -procData	\
			[SelectMCU::get_processor_details $new_processor]
		$actualProject refresh_project_available_SFR

		$actualProject stack_monitor_monitor_close
		$actualProject interrupt_monitor_close
		$actualProject uart_monitor_close
		$actualProject simulator_initialize_mcu
		$actualProject SimGUI_clean_up
		$actualProject simulator_itialize_simulator_control_panel
		$actualProject graph_itialize_simulator_graph_panel {}

		$actualProject sfrmap_commit_new_sfr_set
		$actualProject rightPanel_watch_force_enable
		$actualProject rightPanel_watch_sync_all
		$actualProject rightPanel_watch_disable
		$actualProject sfr_watches_commit_new_sfr_set
		$actualProject pale_MCU_changed
		$actualProject stopwatch_clear_all C
		$actualProject stopwatch_clear_all O

		if {$was_enabled} {
			__initiate_sim
			set critical_procedure_in_progress $tmp
		}
		if {$intr_mon_opeded} {
			$actualProject interrupt_monitor_invoke_dialog
		}

		# Refresh syntax highligh in all editors
		foreach e [$actualProject cget -editors] {
			$e parseAll
		}
	}

	## Close the current project
	 # @return void
	proc __proj_close {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		__proj_save				;# Save project
		$actualProject editor_close_all 0 1	;# Close all opened files
		close_project				;# Close project
	}

	## Close the current project without saving
	 # @return Bool - project closed
	proc __proj_close_imm {} {
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project
		variable actualProject		;# Object: Current project

		if {$project_menu_locked} {return}

		set modified 0
		foreach e [$actualProject cget -editors] {
			if {[$e cget -modified]} {
				set modified 1
				break
			}
		}

		set response {yes}

		# Invoke confirmation dialog
		if {$modified} {
			set response [tk_messageBox	\
				-icon question		\
				-parent .		\
				-type yesno		\
				-title [mc "Requesting confirmation %s" ${::APPNAME}] \
				-message [mc "Are you sure want to close the project without saving changes ?"] \
			]
		}
		# Close project
		if {$response == {yes}} {
			close_project
			return 1
		} else {
			return 0
		}
	}

	## Close the current project -- auxiliary procedure for '__proj_close_imm' and '__proj_close'
	 # @return void
	proc close_project {} {
		variable compilation_mess_project	;# Object: Project related to running compilation
		variable compilation_in_progress	;# Bool: Compiler engaged
		variable actualProject			;# Object: Current project
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable openedProjects			;# List of opened projects (Object references)
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable simulator_enabled		;# List of booleans: Simulator engaged
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time

		# Make sure that there are no help windows visible
		remove_all_help_windows

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Abort running compilation
		if {$compilation_in_progress && $compilation_mess_project == $actualProject} {
			__abort_compilation
		}

		# Abort running simulation
		if {$actualProjectIdx != -1 && ([lindex $simulator_enabled $actualProjectIdx] == 1)} {
			set critical_procedure_in_progress 0
			__initiate_sim
			set critical_procedure_in_progress 1
		}

		# Delete project object
		close_hexedit xdata $actualProject
		close_hexedit code $actualProject
		close_hexedit eram $actualProject
		close_hexedit eeprom $actualProject
		delete object $actualProject
		# Adjust list of opened project and simlator started flag
		set openedProjects	[lreplace $openedProjects $actualProjectIdx $actualProjectIdx]
		set simulator_enabled	[lreplace $simulator_enabled $actualProjectIdx $actualProjectIdx]

		# Raise nex tab or disable project menu and procedures
		if {[llength $openedProjects] > 0} {
			set actualProjectIdx 0
			set actualProject [lindex $openedProjects $actualProjectIdx]
			${::main_nb} raise [string trimleft $actualProject {:}]
		} else {
			set project_menu_locked 1
			Lock_project_menu
		}

		set critical_procedure_in_progress 0

		update
		foreach project $openedProjects {
			$project bottomNB_redraw_pane
		}
	}

	## Compile current file
	 # @parm Bool force=0 - Force compilation -- ignore running critical procedure
	 # @parm Bool compilation_start_simulator=0 - Start simulator after successful compilation
	 # @parm Bool compile_this_file_only=0 - Compile current file only (not the main file)
	 # @return Bool - result or {}
	proc __compile {{force 0} {_compilation_start_simulator 0} {_compile_this_file_only 0}} {
		variable simulator_enabled		;# List of booleans: Simulator engaged
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable compilation_successfull	;# Bool: Compilation successfull
		variable actualProject			;# Object: Current project
		variable compilation_in_progress	;# Bool: Compiler engaged
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable compiler_pid			;# Int: PID of external compiler, if used
		variable compilation_start_simulator	;# Bool: Start simulator after successful compilation
		variable compile_this_file_only		;# Bool: Compile the current file only
		variable compilation_mess_project	;# Object: Project related to running compilation

		if {!${::APPLICATION_LOADED}} {
			return {}
		}

		# It is not allowed to compile the source code while simulator is engaged
		if {[lindex $simulator_enabled $actualProjectIdx]} {
			return {}
		}

		if {$project_menu_locked}			{return}
		if {!$force && $critical_procedure_in_progress}	{return}
		if {$compilation_in_progress} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Unable to run assembler"]	\
				-message [mc "Something is already running in background."]
			return 0
		}

		set compile_this_file_only $_compile_this_file_only
		set compilation_start_simulator $_compilation_start_simulator

		# Compilation started
		set compilation_mess_project	$actualProject
		set compilation_successfull	1
		set result			0
		set compiler_pid		0
		set compilation_in_progress	1
		set Compiler::Settings::ABORT_VARIABLE 0
		#  Save current file
		if {![$actualProject editor_procedure {} save {}]} {
			set compilation_in_progress 0
			return 0
		}
		# Raise tab "Messages"
		$actualProject bottomNB_show_up {Messages}
		# Determinate name of file to compile
		if {$compile_this_file_only} {
			set input_file {}
		} else {
			set input_file [list					\
				[$actualProject cget -projectPath]		\
				[$actualProject cget -P_option_main_file]	\
			]
		}
		if {[lindex $input_file 1] == {}} {
			set input_file [$actualProject editor_procedure {} getFileName {}]
			set language [$actualProject editor_procedure {} get_language {}]
		} else {
			set ext [string trimleft [file extension [lindex $input_file 1]] {.}]
			if {$ext == {c} || $ext == {h} || $ext == {cxx} || $ext == {cpp} || $ext == {cc}} {
				set language 1
			} elseif {$ext == {lst}} {
				set language 2
			} else {
				set language 0
			}
		}
		# Adjust filename
		set cur_dir [lindex $input_file 0]
		set input_file_name [lindex $input_file 1]
		if {[regexp {\.[^\.]*$} $input_file_name input_file_extension]} {
			regsub {\.[^\.]*$} $input_file_name {} input_file_name
			set input_file_extension [string range $input_file_extension 1 end]
		} else {
			set input_file_extension {}
		}
		# Asjust file extension
		if {$input_file_extension == {h}} {
			set input_file_extension {c}
		} elseif {$input_file_extension == {lst}} {
			set input_file_extension {asm}
		}

		# Adjust statusbar
		Sbar [mc "Compiling ..."]
		make_progressBar_on_Sbar
		compilation_progress

		# Determinate memory limits
		set iram_size [lindex [$actualProject cget -procData] 3]
		set eram_size [lindex [$actualProject cget -procData] 8]
		set xram_size [$actualProject cget -P_option_mcu_xdata]
		if {$eram_size > $xram_size} {
			set xram_size $eram_size
		}
		set code_size [expr {
			([lindex [$actualProject cget -procData] 2] * 1024)
				+
			[$actualProject cget -P_option_mcu_xcode]
		}]

		## C language
		if {$language == 1} {
			if {!${::PROGRAM_AVAILABLE(sdcc)} && !${::PROGRAM_AVAILABLE(sdcc-sdcc)}} {
				tk_messageBox		\
					-parent .	\
					-type ok	\
					-icon warning	\
					-title [mc "Compiler not found"]	\
					-message [mc "Unable to find sdcc, please install sdcc and restart MCU 8051 IDE"]
			} else {
				# Start compiler
				set compiler_pid [::ExternalCompiler::compile_C			\
					$cur_dir	$input_file_name.$input_file_extension	\
					$iram_size	$xram_size	$code_size		\
				]
				return 2
			}

		## Assembly language
		} else {
			# Check if the choosen assembler is available in the system
			set available 0
			switch -- $::ExternalCompiler::selected_assembler {
				0 {	;# Native assembler
					set available 1
					set assembler_name [mc "MCU 8051 IDE Native assembler"]
					set assembler_cmd {mcu8051ide --assemble}
				}
				1 {	;# ASEM-51
					set available ${::PROGRAM_AVAILABLE(asem)}
					set assembler_name "ASEM-51"
					set assembler_cmd {asem}
				}
				2 {	;# ASL
					set available ${::PROGRAM_AVAILABLE(asl)}
					set assembler_name "ASL"
					set assembler_cmd {asl}
				}
				3 {	;# AS31
					set available ${::PROGRAM_AVAILABLE(as31)}
					set assembler_name "AS31"
					set assembler_cmd {as31}
				}
				default {
					error "Unknown internal error -- Invalid ID of the selected assembler"
				}
			}
			if {!$available} {
				tk_messageBox		\
					-parent .	\
					-type ok	\
					-icon error	\
					-title [mc "%s assembler not found" $assembler_name]	\
					-message [mc "Unable to run program \"%s\". Please check if you have installed this assembler or choose a different one in compiler configuration dialog." $assembler_cmd]
				finalize_compilation 0
				return 0
			}

			# Execute compiler
			switch -- $::ExternalCompiler::selected_assembler {
				0 {	;# Native assembler
					# Adjust compiler settings
					set ::Compiler::Settings::TEXT_OUPUT_COMMAND X::messages_text_append
					set ::Compiler::Settings::UPDATE_COMMAND {update}
					set ::Compiler::Settings::iram_size $iram_size
					set ::Compiler::Settings::xram_size $xram_size
					set ::Compiler::Settings::code_size $code_size
					set ::PreProcessor::check_sfr_usage 1
					set ::PreProcessor::available_SFR [string tolower [$actualProject cget -available_SFR]]

					# Perform code compilation
					if {[catch {
						set result [Compiler::compile				\
							[$actualProject cget -projectPath]		\
							$cur_dir $input_file_name $input_file_extension	\
						]
					}]} then {
						puts stderr "Compiler crashed: \"${::errorInfo}\""
						tk_messageBox		\
							-parent .	\
							-icon error	\
							-type ok	\
							-title [mc "Compiler crash - MCU 8051 IDE"]	\
							-message [mc "Compiler crashed, we are terribly sorry about that.\n\nPlease report this bug via project web or mail to author and please don't forget to include source code on which this error occurred."]
					}
					::Compiler::free_resources
					set Compiler::Settings::ABORT_VARIABLE 0
				}
				1 {	;# ASEM-51
					set compiler_pid [::ExternalCompiler::asem51_compile $cur_dir	\
						$input_file_name.$input_file_extension			\
						[$actualProject cget -projectPath]			\
					]
					return 2
				}
				2 {	;# ASL
					set compiler_pid [::ExternalCompiler::asl_compile $cur_dir	\
						$input_file_name.$input_file_extension			\
						[$actualProject cget -projectPath]			\
					]
					return 2
				}
				3 {	;# AS31
					set compiler_pid [::ExternalCompiler::as31_compile $cur_dir	\
						$input_file_name.$input_file_extension			\
						[$actualProject cget -projectPath]			\
					]
					return 2
				}
				default {
					error "Unknown internal error -- Invalid ID of the selected assembler"
				}
			}
		}

		finalize_compilation $result
		return $result
	}

	## Compile the current file or the main file if it has not been already compiled
	 # @parm String success_callback	- Procedure to call upon successfull compilation
	 # @parm String fail_callback		- Procedure to call upon failed compilation
	 # @return void
	proc compile_if_nessesary_and_callback {success_callback fail_callback} {
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable actualProject			;# Object: Current project
		variable compilation_in_progress	;# Bool: Compiler engaged
		variable compilation_success_callback	;# String: Indented for HW plugins
		variable compilation_fail_callback	;# String: Indented for HW plugins

		if {$project_menu_locked} {
			return
		}

		set compilation_success_callback	$success_callback
		set compilation_fail_callback		$fail_callback

		set full_file_name [list				\
			[$actualProject cget -projectPath]		\
			[$actualProject cget -P_option_main_file]	\
		]
		set relative_name [lindex $full_file_name 1]
		if {$relative_name == {}} {
			set full_file_name [$actualProject editor_procedure {} getFileName {}]
			set language [$actualProject editor_procedure {} get_language {}]
			set relative_name [lindex $full_file_name 1]
		} else {
			set ext [string trimleft [file extension $relative_name] {.}]
			if {$ext == {c} || $ext == {h} || $ext == {cxx} || $ext == {cpp} || $ext == {cc}} {
				set language 1
			} elseif {$ext == {lst}} {
				set language 2
			} else {
				set language 0
			}
		}
		set full_file_name [file join [lindex $full_file_name 0] [lindex $full_file_name 1]]
		set full_file_name [file rootname $full_file_name]
		if {$language != 1} {
			append full_file_name {.adf}
		} else {
			append full_file_name {.hashes}
		}


		if  {![catch {
			# C language
			if {$language == 1} {
				set hashes_file [open $full_file_name r]
				set expected_md5s [read $hashes_file]
				close $hashes_file

			# Assembly language
			} elseif {$language == 0} {
				set expected_md5s {}
				set simulator_file [open $full_file_name r]
				while {![eof $simulator_file]} {
					set line [gets $simulator_file]
					if {$line == {} || [regexp {^\s*#} $line]} {
						continue
					}
					set expected_md5s $line
					break
				}
				close $simulator_file

			# Invalid request!
			} else {
				error "Invalid request!"
			}

		}]} then {
			if {[verify_md5_hashes 1 $expected_md5s [file dirname $full_file_name]]} {
				__compile
				return
			}
		} else {
			__compile
			return
		}

		eval "$compilation_success_callback"
	}

	## Finalize compilation process
	 # Auxiliary procedure for procedures: __compile && ext_compilation_complete
	 # @parm Bool result - 1 == Compilation successfull; 0 == Compilation failed
	 # @return void
	proc finalize_compilation {result} {
		variable compilation_in_progress	;# Bool: Compiler engaged
		variable compilation_success_callback	;# String: Indented for HW plugins
		variable compilation_fail_callback	;# String: Indented for HW plugins
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time

		set critical_procedure_in_progress 0

		# Adjust statusbar
		destroy_progressBar_on_Sbar
		if {$result} {
			Sbar [mc "Compilation successful"]
			if {$compilation_success_callback != {}} {
				eval "$compilation_success_callback"
				set compilation_fail_callback {}
				set compilation_success_callback {}
			}
		} else {
			Sbar [mc "Compilation failed"]
			if {$compilation_fail_callback != {}} {
				eval "$compilation_fail_callback"
				set compilation_fail_callback {}
				set compilation_success_callback {}
			}
		}

		# Done ...
		set compilation_in_progress 0
	}

	## Handle text output from external or internal compiler
	 # @parm String text - Output from external compiler
	 # @return void
	proc compilation_message args {
		variable compilation_successfull	;# Bool: Compilation successfull
		variable compilation_mess_project	;# Object: Project related to running compilation

		set args [string replace			\
				[regsub -all "\\\{"		\
					[regsub -all "\\\}"	\
						[lindex $args 0]\
					"\}"]			\
				"\{"]				\
			0 0]

		# Backspace characters
		set idx 0
		while {1} {
			set idx [string first "\b" $args $idx]
			if {$idx == -1} {
				break
			}
			set args [string replace $args [expr {$idx - 1}] [expr {$idx + 1}]]
			incr idx -1
		}

		if {[$compilation_mess_project messages_text_append [string trimright $args]]} {
			set compilation_successfull 0
		}
	}

	## External compiler finnished its work
	 # @return void
	proc ext_compilation_complete {} {
		variable compilation_mess_project	;# Object: Project related to running compilation
		variable actualProject			;# Object: Current project
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable openedProjects			;# List of opened projects (Object references)
		variable compilation_start_simulator	;# Bool: Start simulator after successful compilation
		variable compile_this_file_only		;# Bool: Compile the current file only
		variable compilation_successfull	;# Bool: Compilation successfull

		finalize_compilation $compilation_successfull

		# Conditionaly start simulator
		if {$compilation_start_simulator && $compilation_successfull} {
			set actualProject_org $actualProject
			set actualProjectIdx_org $actualProjectIdx

			set actualProject $compilation_mess_project
			set actualProjectIdx [lsearch -exact -ascii $openedProjects $actualProject]

			__initiate_sim $compile_this_file_only

			set actualProject $actualProject_org
			set actualProjectIdx $actualProjectIdx_org
		} elseif {$compilation_start_simulator && !$compilation_successfull} {
			tk_messageBox		\
				-parent .	\
				-icon error	\
				-type ok	\
				-title [mc "Compilation failed"]	\
				-message [mc "Compilation failed, see messages for details."]
		}
	}

	## Abort running compilation -- auxiliary procedure for '__compile'
	 # @return void
	proc __abort_compilation {} {
		variable compilation_in_progress	;# Bool: Compiler engaged
		variable doxygen_pid			;# Int: Doxygen PID
		variable compiler_pid			;# Int: PID of external compiler if used

		set Compiler::Settings::ABORT_VARIABLE 1
		destroy_progressBar_on_Sbar

		if {!$::MICROSOFT_WINDOWS} { ;# There is no kill command on Microsoft Windows
			# Kill doxygen
			if {${doxygen_pid} != {}} {
				foreach pid $doxygen_pid {
					if {$pid == [pid] || $pid == 0} {
						continue
					}
					catch {
						exec -- kill -9 $pid
					}
				}
			}

			# Kill external compiler
			if {${compiler_pid} != {}} {
				foreach pid $compiler_pid {
					if {$pid == [pid] || $pid == 0} {
						continue
					}
					catch {
						exec -- kill -9 $pid
					}
				}
			}
		}

		set compilation_in_progress	0
		set compiler_pid		0
		set doxygen_pid			0
	}

	## Create progressbar on status bar (showing compilation progress)
	 # -- auxiliary procedure for '__compile'
	 # @return void
	proc make_progressBar_on_Sbar {} {
		# Frame
		pack [frame .statusbarR] -in .statusbarF -side right
		# Label "Compilation"
		pack [label .status_sim_label		\
			-text [mc "Compilation: "]	\
		] -in .statusbarR -side left
		# Button "Abort"
		pack [ttk::button .status_sim_button		\
			-text [mc "Abort"]			\
			-image ::ICONS::16::cancel		\
			-compound left				\
			-command {X::__abort_compilation}	\
		] -in .statusbarR -side left
		# Progressbar
		pack [ttk::progressbar .status_sim_prog		\
			-maximum 1000				\
			-mode indeterminate			\
			-variable X::compilation_progress	\
			-length 100				\
		] -in .statusbarR -side left
	}

	## Destroy progressbar on status bar (showing compilation progress)
	 # -- auxiliary procedure for '__compile'
	 # @return void
	proc destroy_progressBar_on_Sbar {} {
		catch {
			destroy .statusbarR
			destroy .status_sim_label
			destroy .status_sim_button
			destroy .status_sim_prog
		}
	}

	## Increment progreesbar on statusbar (compilation progress)
	 # -- auxiliary procedure for '__compile'
	 # @return void
	proc compilation_progress {} {
		variable compilation_progress		;# Variable for compilation progressbar
		variable compilation_in_progress	;# Bool: Compiler engaged

		if {!$compilation_in_progress} {return}

		incr compilation_progress
		if {$compilation_progress > 100} {
			set compilation_progress 0
		}
		after 200 {X::compilation_progress}
	}

	## Append text to messages text (bottom panel - tab "Messages")
	 # @parm String text - Text to append
	 # @return Bool - True if error occurred
	proc messages_text_append {text} {
		variable actualProject			;# Object: Current project
		variable compilation_mess_project	;# Object: Project related to running compilation
		variable compilation_successfull	;# Bool: Compilation successfull

		set result [$compilation_mess_project messages_text_append $text]
		if {$result} {
			set compilation_successfull 0
		}
		return $result
	}

	## Copy selected text in messages text to clipboard (bottom panel - tab "Messages")
	 # @return void
	proc __copy_messages_text {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		# Copy
		$actualProject copy_messages_text
	}

	## Select all text in messages text (bottom panel - tab "Messages")
	 # @return void
	proc __select_all_messages_text {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		# Select all
		$actualProject select_all_messages_text
	}

	## Clear content of messages text (bottom panel - tab "Messages")
	 # @return void
	proc __clear_messages_text {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		# CLear
		$actualProject clear_messages_text
	}

	## Export content of the current editor as XHTML/LaTeX
	 # -- auxiliary procedure for '__toHTML' and '__toLaTeX'
	 # @parm String	- Target type ('-html' or '-latex')
	 # @parm String	- Title of the dialog window
	 # @return void
	proc exportToX args {
		variable actualProject			;# Object: Current project
		variable compilation_progress		;# Variable for compilation progressbar
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable fsd_result			;# Value returnded by file selection dialog (in some cases)

		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		# Expect 2 arguments
		if {[llength $args] != 2} {
			error "expected exactly 2 arguments"
		}

		# Check if the editor isn't empty
		if {
			[$actualProject editor_procedure {} getLinesCount {}] == 1
				&&
			[$actualProject editor_procedure {} getLineContent 1] == {}
		} then {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Unable to comply"]	\
				-message [mc "This editor seems to be empty"]
			return
		}

		# Determinate target file type (html/latex)
		set targetType [lindex $args 0]
		# Compilation started
		set compilation_progress 1
		# Determinate maximum value for progress bar
		set max [$actualProject editor_procedure {} highlight_all_count_of_iterations {}]
		incr max

		# Create diwlog window
		set win [toplevel .exportToX_dialog -class [mc "Export dialog"] -bg ${::COMMON_BG_COLOR}]
		wm withdraw $win

		# Label and progress bar
		set main_frame [frame $win.main_frame]
		pack [label $main_frame.header			\
			-text [mc "Finishing syntax highlight ..."]	\
		] -pady 10 -padx 20 -anchor w
		pack [ttk::progressbar $main_frame.progress_bar	\
			-maximum $max				\
			-mode determinate			\
			-variable {X::compilation_progress}	\
			-length 430				\
		] -fill y
		pack $main_frame -fill x -expand 1

		# Button abort
		pack [ttk::button $win.abort_button			\
			-text [mc "Abort"]				\
			-command "X::exportToX_abort $targetType"	\
			-image ::ICONS::16::cancel			\
			-compound left					\
		] -pady 5

		# Determinate target file name
		set file [$actualProject editor_procedure {} getFileName {}]
		set filename [lindex $file 1]
		if {[lindex $file 0] != {}} {
			set dir [lindex $file 0]
		} else {
			set dir [$actualProject cget -projectPath]
		}
		regsub {\.[^\.]*$} $filename {} filename
		if {$targetType == "-html"} {
			set suffix {html}
		} else {
			set suffix {tex}
		}
		append filename {.} $suffix
		catch {delete object fsd}
		KIFSD::FSD fsd								\
			-initialfile $filename -directory $dir	 			\
			-title [mc "Export as %s - MCU 8051 IDE" [lindex $args 1]]	\
			-defaultmask 0 -multiple 0 -filetypes [list				\
				[list [mc [string toupper $suffix] {file}]	"*.$suffix"]	\
				[list [mc "All files"]				{*}]		\
			]
		fsd setokcmd {
			set ::X::fsd_result [X::fsd get]
		}
		set fsd_result {}
		fsd activate

		set filename $fsd_result
		if {[file isdirectory $filename] || ![string length $filename]} {
			exportToX_abort $targetType
			return
		}
		if {![regexp {\.\w+$} $filename]} {
			append filename {.} $suffix
		}

		# Create backup file
		if {[file exists $filename] && [file isfile $filename]} {
			if {![file writable $filename]} {
				tk_messageBox		\
					-parent .	\
					-type ok	\
					-icon error	\
					-title [mc "Permission denied"]	\
					-message [mc "Unable to access file: %s" $filename]
				exportToX_abort $targetType
				return
			}
			# Ask user for overwrite existing file
			if {[tk_messageBox	\
				-type yesno	\
				-icon question	\
				-parent .	\
				-title [mc "Overwrite file"]	\
				-message [mc "A file name '%s' already exists. Are you sure you want to overwrite it ?" [file tail $filename]]
				] != {yes}
			} then {
				exportToX_abort $targetType
				return
			}
			# Create a backup file
			catch {
				file rename -force $filename "$filename~"
			}
		}

		# Open target file
		if {[catch {
			set file [open $filename w 0640]
		}]} then {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon error	\
				-title [mc "Permission denied"]	\
				-message [mc "Unable to write to file: \"%s\"" $filename]
			exportToX_abort $targetType
			return
		}

		# Set window attributes
		if {![winfo exists $win]} {return}
		wm iconphoto $win ::ICONS::16::html
		wm deiconify $win
		wm title $win [mc "[lindex $args 1] - MCU 8051 IDE"]
		wm minsize $win 450 110
		wm protocol $win WM_DELETE_WINDOW {
			exportToX_abort
		}
		wm transient $win .
		catch {grab $win}
		raise $win
		update

		# Highlight all lines in the editor
		$actualProject editor_procedure {} highlight_all {}
		if {![winfo exists $win]} {return}

		# Ajust window (Second stage)
		set max [$actualProject editor_procedure {} getDataAsXHTML_count_of_iterations {}]
		incr max
		$main_frame.header configure -text [mc "Converting ..."]
		$main_frame.progress_bar configure -maximum $max
		set compilation_progress 1
		update

		# Export and write data
		if {$targetType == "-html"} {
			$actualProject editor_procedure {} getDataAsXHTML $file
		} elseif {$targetType == "-latex"} {
			$actualProject editor_procedure {} getDataAsLaTeX $file
		} else {
			error "Unknown argument: $targetType\n\tpossible vaues are: -html -latex"
		}
		close $file
		exportToX_abort $targetType

		# Show result
		Sbar [mc "Exported data saved to %s" $filename]
	}

	## Abort export content of the current editor as XHTML/LaTeX
	 # -- auxiliary procedure for '__toHTML' and '__toLaTeX'
	 # @parm String	- Target type ('-html' or '-latex')
	 # @return void
	proc exportToX_abort {targetType} {
		variable actualProject	;# Object: Current project

		# Abort export
		if {$targetType == "-html"} {
			$actualProject editor_procedure {} getDataAsXHTML_abort_now {}
		} elseif {$targetType == "-latex"} {
			$actualProject editor_procedure {} getDataAsLaTeX_abort_now {}
		} else {
			error "Unknown argument: $targetType\n\tpossible vaues are: -html -latex"
		}

		# Destroy dialog window
		destroy .exportToX_dialog
		grab release .exportToX_dialog
	}

	## Export data contained in the current editor as XHTML
	 # @return void
	proc __toHTML {} {
		exportToX -html "Export to XHTML"
	}

	## Export data contained in the current editor as LaTeX
	 # @return void
	proc __toLaTeX {} {
		exportToX -latex "Export to LaTeX"
	}

	## Exit program
	 #	- Ask for saving unsaved files and projects
	 #	- Save all projects
	 #	- Save session file
	 #	- Exit
	 # @parm Bool do_not_print_exit_message=0	- Print message "Exiting on user request"
	 # @parm Bool force=0				- Do not allow user to cancel the request
	 # @return void
	proc __exit {{do_not_print_exit_message 0} {force 0}} {
		variable openedProjects			;# List of opened projects (Object references)
		variable actualProject			;# Object: Current project
		variable compilation_in_progress	;# Bool: Compiler engaged
		variable procedure_exit_in_progress	;# Bool: proc "__exit" in progress
		variable unsaved_projects		;# List: List of project object marked as "unsaved"
		variable eightsegment_editors		;# List: All 8-Segment LED display editors invoked
		variable spec_calc_objects		;# List: All special calculator objects
		variable rs232debugger_objects		;# List: All "RS232 debugger" objects

		# If application is not loaded -> exit immediately
		if {!${::APPLICATION_LOADED}} {
			exit
		}

		# This procedure cannot be recursive
		if {$procedure_exit_in_progress} {
			return
		}
		set procedure_exit_in_progress 1

		# Ask hardware whether it's ready for exit
		foreach project $openedProjects {
			if {![$project hw_manager_comfirm_exit]} {
				set procedure_exit_in_progress 0
				return
			}
		}

		foreach obj [concat $eightsegment_editors $spec_calc_objects $rs232debugger_objects] {
			catch {
				delete object $obj
			}
		}

		# Cancel running compilation
		if {$compilation_in_progress} {
			__abort_compilation
		}

		# Determinate list of unsaved projects
		set unsaved_projects {}
		foreach project $openedProjects {
			foreach editor [$project cget -editors] {
				catch {
					if {[$editor cget -modified]} {
						lappend unsaved_projects [list $project $editor]
					}
				}
			}
		}

		# Ask user for saving unsaved files -- use proc 'shutdown_dialog'
		if {[llength $unsaved_projects] != 0} {
			switch -- [shutdown_dialog $force] {
				0 {	;# SAVESELECTED
					set i 0
					foreach unsaved $unsaved_projects {
						set bool [subst -nocommands "\$::unsavedfile$i"]
						if {$bool == 1} {
							[lindex [lindex $unsaved_projects $i] 1] save
						}
						incr i
					}
				}
				1 {	;# SAVEALL
					set last_project {}
					foreach project $unsaved_projects {
						set project [lindex $project 0]
						if {$last_project == $project} {continue}
						set last_project $project
						$project editor_save_all
					}
				}
				2 {	;# DISCARD
				}
				3 {	;# CANCEL
					set procedure_exit_in_progress 0
					return 0
				}
			}
		}

		# Stop watching for modifications in designaded files
		FSnotifications::stop

		if {!$do_not_print_exit_message} {
			puts [mc "\nExiting program on user request ..."]
		}

		# Save session
		if {[catch {
			save_session
		} result]} then {
			puts stderr [mc "An error occurred when saving the last session"]
			puts stderr $result
		}


		# Withdraw main window
		wm withdraw .
		# Withdraw all PALE windows
		foreach project $openedProjects {
			$project pale_withdraw_all_windows
		}
		update

		# Save all projects
		foreach project $openedProjects {
			$project kill_childern
			set actualProject $project
			puts [mc "Saving project: %s" $project]
			__proj_save
		}

		# Kill the spell checker used by the editor
		if {!$::MICROSOFT_WINDOWS} {
			::Editor::kill_spellchecker_process
		}

		puts [mc "Program terminated"]
		exit
	}

	## Save the current session
	 # @return void
	proc save_session {} {
		variable openedProjects		;# List of opened projects (Object references)
		variable actualProject		;# Object: Current project
		variable session_file		;# Path to file defining the last session
		variable actualProjectIdx	;# Index of the current project in $openedProjects

		variable line2pc_jump		;# Bool: Perform program jump (1) or subprogram call (0)
		variable find_option_CS		;# Bool: Case sensitive
		variable find_option_back	;# Bool: Search backwards (checkbox)
		variable find_option_cur	;# Book: Search from cursor
		variable find_option_sel	;# Bool: Search only in the seleted text
		variable find_option_reg	;# Bool: Consider search string to be a regular expression
		variable replace_option_CS	;# Bool: Case sensitive
		variable replace_option_back	;# Bool: Search backwards (checkbox)
		variable replace_option_cur	;# Book: Search from cursor
		variable replace_option_reg	;# Bool: Consider search string to be a regular expression

		variable file_recent_files	;# List: recently opened files
		variable project_recent_files	;# List: recently opened projects
		variable vhw_recent_files	;# List: recently opened Virtual HW files

		variable base_converters	;# List: All base converter objects

		variable change_letter_case_options	;# Options (which fields should be adjusted)

		# Create configuration directory if it is not exist already
		if {![file exists ${::CONFIG_DIR}] || ![file isdirectory ${::CONFIG_DIR}]} {
			if {[catch {[file mkdir ${::CONFIG_DIR}]}]} {
				tk_messageBox				\
					-type ok			\
					-icon error			\
					-title [mc "Permission denied"]	\
					-message [mc "Unable to save running configuration"]
				return 0
			}
		}

		# Get project dependent options
		if {([llength $openedProjects] > 0) && ($actualProject != {})} {
			array set ::CONFIG [subst {
				LINE_NUMBERS			[$actualProject cget -lineNumbers]
				ICON_BORDER			[$actualProject cget -iconBorder]
				LEFT_PANEL			[$actualProject isLeftPanelVisible]
				RIGHT_PANEL			[$actualProject isRightPanelVisible]
				BOTTOM_PANEL			[$actualProject isBottomPanelVisible]
				LEFT_PANEL_SIZE			[$actualProject getLeftPanelSize]
				RIGHT_PANEL_SIZE		[$actualProject getRightPanelSize]
				BOTTOM_PANEL_SIZE		[$actualProject getBottomPanelSize]
				LEFT_PANEL_ACTIVE_PAGE		{[$actualProject getLeftPanelActivePage]}
				RIGHT_PANEL_ACTIVE_PAGE		{[$actualProject getRightPanelActivePage]}
				BOTTOM_PANEL_ACTIVE_PAGE	{[$actualProject getBottomPanelActivePage]}
				SUBP_MON_CONFIG			{[$actualProject subprograms_get_config]}
				FS_BROWSER_MASK			{[$actualProject fs_browser_get_current_mask]}
				FIND_IN_FILES_CONFIG		{[$actualProject findinfiles_get_config]}
				STOPWATCH_CONFIG		{[$actualProject stopwatch_get_config]}
				C_VARS_VIEW_CONF		{[$actualProject cvarsview_get_config]}
				BITMAP_CONFIG			{[$actualProject bitmap_get_config]}
				HW_MANAGER_CONFIG		{[$actualProject hw_manager_get_cfg]}
				REGWATCHES_CONFIG		{[$actualProject rightPanel_watch_get_config]}
				FILE_NOTES			{[$actualProject get_file_notes_config]}
			}]
		}
		# Get project independent options
		array set ::CONFIG [subst {
			KIFSD_CONFIG		{[::KIFSD::FSD::get_config_array]}
			HEXEDIT_CONFIG		{[::HexEditDlg::getConfig]}
			FIND_OPTIONS		{[list	$find_option_CS		\
							$find_option_back	\
							$find_option_cur	\
							$find_option_sel	\
							$find_option_reg]}
			REPLACE_OPTIONS		{[list	$replace_option_CS	\
							$replace_option_back	\
							$replace_option_cur	\
							$replace_option_reg]}
			INTR_MON_GEOMETRY	{${::InterruptMonitor::geometry}}
			OPEN_WITH_DLG		{${::FileList::open_with}}
			SYMBOL_VIEWER_CONFIG	{${::SymbolViewer::config_list}}
			LINE2PC_JUMP		{$line2pc_jump}
			FILE_RECENT_FILES	{$file_recent_files}
			PROJECT_RECENT_FILES	{$project_recent_files}
			VHW_RECENT_FILES	{$vhw_recent_files}
			EIGHT_SEG_EDITOR	{${::EightSegment::config}}
			SPEC_CALC		{${::SpecCalc::config}}
			ASK_ON_FILE_OPEN	{${::FileList::ask__append_file_to_project}}
			RS232_DEBUGGER		{${::RS232Debugger::config_list}}
			STACK_MON_GEOMETRY	{${::StackMonitor::geometry}}
			STACK_MON_COLLAPSED	{${::StackMonitor::collapsed}}
			SPELL_CHECK_ENABLED	{${::Editor::spellchecker_enabled}}
			SPELL_CHECK_DICTIONARY	{${::Editor::spellchecker_dictionary}}
			UART_MON_GEOMETRY	{${::UARTMonitor::geometry}}
			SHOW_PALE_WARN		{${::Graph::show_sim_per_warn}}
		}]
		set ::CONFIG(LETTER_CASE) {}
		for {set i 0} {$i < 21} {incr i} {
			lappend ::CONFIG(LETTER_CASE) $change_letter_case_options($i)
		}
		set ::CONFIG(BASE_CONVERTERS) {}
		foreach obj $base_converters {
			lappend ::CONFIG(BASE_CONVERTERS) [$obj get_config]
		}

		# Open session file
		if {[catch {
			set file [open $session_file w 0640]
		}]} then {
			tk_messageBox				\
				-parent .			\
				-type ok			\
				-icon error			\
				-title [mc "Access denied"]	\
				-message [mc "Unable to write to file: \"%s\"" $session_file]
			return
		}

		# Write session file
		puts $file "# ${::APPNAME}"
		puts $file "# Please do not modify this file manually.\n"

		puts $file "# booleans"
		if {$::MICROSOFT_WINDOWS} {
			if {[wm state .] == {zoomed}} {
				puts $file "WINDOW_ZOOMED = 1"
			} else {
				puts $file "WINDOW_ZOOMED = 0"
			}
		} else {
			puts $file "WINDOW_ZOOMED = [wm attributes . -zoomed]"
		}
		puts $file "LINE_NUMBERS = $::CONFIG(LINE_NUMBERS)"
		puts $file "ICON_BORDER = $::CONFIG(ICON_BORDER)"
		puts $file "LEFT_PANEL = $::CONFIG(LEFT_PANEL)"
		puts $file "RIGHT_PANEL = $::CONFIG(RIGHT_PANEL)"
		puts $file "BOTTOM_PANEL = $::CONFIG(BOTTOM_PANEL)"
		puts $file "TOOLBAR_VISIBLE = $::CONFIG(TOOLBAR_VISIBLE)"
		puts $file "BREAKPOINTS_ALLOWED = $::CONFIG(BREAKPOINTS_ALLOWED)"
		puts $file "LINE2PC_JUMP = $::CONFIG(LINE2PC_JUMP)"
		puts $file "ASK_ON_FILE_OPEN = $::CONFIG(ASK_ON_FILE_OPEN)"
		puts $file "SHOW_EDITOR_TAB_BAR = $::CONFIG(SHOW_EDITOR_TAB_BAR)"
		puts $file "STACK_MON_COLLAPSED = $::CONFIG(STACK_MON_COLLAPSED)"
		puts $file "SPELL_CHECK_ENABLED = $::CONFIG(SPELL_CHECK_ENABLED)"
		puts $file "SHOW_PALE_WARN = $::CONFIG(SHOW_PALE_WARN)"
		puts $file "\n# integers"
		puts $file "LEFT_PANEL_SIZE = $::CONFIG(LEFT_PANEL_SIZE)"
		puts $file "RIGHT_PANEL_SIZE = $::CONFIG(RIGHT_PANEL_SIZE)"
		puts $file "BOTTOM_PANEL_SIZE = $::CONFIG(BOTTOM_PANEL_SIZE)"
		puts $file "VALIDATION_LEVEL = $::CONFIG(VALIDATION_LEVEL)"
		puts $file "\n# strings"
		puts $file "LEFT_PANEL_ACTIVE_PAGE = \"$::CONFIG(LEFT_PANEL_ACTIVE_PAGE)\""
		puts $file "RIGHT_PANEL_ACTIVE_PAGE = \"$::CONFIG(RIGHT_PANEL_ACTIVE_PAGE)\""
		puts $file "BOTTOM_PANEL_ACTIVE_PAGE = \"$::CONFIG(BOTTOM_PANEL_ACTIVE_PAGE)\""
		puts $file "OPEN_WITH_DLG = \"$::CONFIG(OPEN_WITH_DLG)\""
		puts $file "FS_BROWSER_MASK = \"$::CONFIG(FS_BROWSER_MASK)\""
		puts $file "FILE_RECENT_FILES = \"$::CONFIG(FILE_RECENT_FILES)\""
		puts $file "PROJECT_RECENT_FILES = \"$::CONFIG(PROJECT_RECENT_FILES)\""
		puts $file "VHW_RECENT_FILES = \"$::CONFIG(VHW_RECENT_FILES)\""
		puts $file "SPELL_CHECK_DICTIONARY = \"$::CONFIG(SPELL_CHECK_DICTIONARY)\""
		puts $file "\n# lists"
		puts $file "CLEANUP_OPTIONS = \"[regsub -all {\s+} $::CONFIG(CLEANUP_OPTIONS) { }]\""
		puts $file "FIND_OPTIONS = \"$::CONFIG(FIND_OPTIONS)\""
		puts $file "REPLACE_OPTIONS = \"$::CONFIG(REPLACE_OPTIONS)\""
		puts $file "LETTER_CASE = \"$::CONFIG(LETTER_CASE)\""
		puts $file "KIFSD_CONFIG = \"$::CONFIG(KIFSD_CONFIG)\""
		puts $file "HEXEDIT_CONFIG = \"$::CONFIG(HEXEDIT_CONFIG)\""
		puts $file "SUBP_MON_CONFIG = \"$::CONFIG(SUBP_MON_CONFIG)\""
		puts $file "FIND_IN_FILES_CONFIG = \"$::CONFIG(FIND_IN_FILES_CONFIG)\""
		puts $file "SYMBOL_VIEWER_CONFIG = \"$::CONFIG(SYMBOL_VIEWER_CONFIG)\""
		puts $file "STOPWATCH_CONFIG = \"$::CONFIG(STOPWATCH_CONFIG)\""
		puts $file "C_VARS_VIEW_CONF = \"$::CONFIG(C_VARS_VIEW_CONF)\""
		puts $file "BITMAP_CONFIG = \"$::CONFIG(BITMAP_CONFIG)\""
		puts $file "HW_MANAGER_CONFIG = \"$::CONFIG(HW_MANAGER_CONFIG)\""
		puts $file "REGWATCHES_CONFIG = \"$::CONFIG(REGWATCHES_CONFIG)\""
		puts $file "FILE_NOTES = \"$::CONFIG(FILE_NOTES)\""
		puts $file "EIGHT_SEG_EDITOR = \"$::CONFIG(EIGHT_SEG_EDITOR)\""
		puts $file "BASE_CONVERTERS = \"$::CONFIG(BASE_CONVERTERS)\""
		puts $file "SPEC_CALC = \"$::CONFIG(SPEC_CALC)\""
		puts $file "RS232_DEBUGGER = \"$::CONFIG(RS232_DEBUGGER)\""
		puts $file "\n# other"
		puts $file "WINDOW_GEOMETRY = \"[wm geometry .]\""
		puts $file "ACTIVE_PROJECT = $actualProjectIdx"
		puts $file "INTR_MON_GEOMETRY = \"$::CONFIG(INTR_MON_GEOMETRY)\""
		puts $file "STACK_MON_GEOMETRY = \"$::CONFIG(STACK_MON_GEOMETRY)\""
		puts $file "UART_MON_GEOMETRY = \"$::CONFIG(UART_MON_GEOMETRY)\""

		set projects [list]
		foreach prj $openedProjects {
			if {![$prj cget -S_flag_read_only]} {	;# Do not reopen read-only projects
				lappend projects [file join	\
					[$prj cget -projectPath]\
					[$prj cget -projectFile]\
				]
			}
		}

		puts $file "OPENED_PROJECTS = ($projects)"

		# Finalize
		close $file
		return 1
	}

	## Restore previous session
	 # @return Bool - session file found
	proc restore_session {} {
		variable session_file		;# Path to file defining the last session

		variable line2pc_jump		;# Bool: Perform program jump (1) or subprogram call (0)
		variable find_option_CS		;# Bool: Case sensitive
		variable find_option_back	;# Bool: Search backwards (checkbox)
		variable find_option_cur	;# Book: Search from cursor
		variable find_option_sel	;# Bool: Search only in the seleted text
		variable find_option_reg	;# Bool: Consider search string to be a regular expression
		variable replace_option_CS	;# Bool: Case sensitive
		variable replace_option_back	;# Bool: Search backwards (checkbox)
		variable replace_option_cur	;# Book: Search from cursor
		variable replace_option_reg	;# Bool: Consider search string to be a regular expression

		variable file_recent_files	;# List: recently opened files
		variable project_recent_files	;# List: recently opened projects
		variable vhw_recent_files	;# List: recently opened Virtual HW files

		variable change_letter_case_options	;# Options (which fields should be adjusted)

		# Set default values
		array set ::CONFIG {
			WINDOW_ZOOMED			0
			LINE_NUMBERS			1
			ICON_BORDER			1
			LEFT_PANEL			1
			RIGHT_PANEL			1
			BOTTOM_PANEL			1
			LEFT_PANEL_SIZE			193
			RIGHT_PANEL_SIZE		329
			BOTTOM_PANEL_SIZE		190
			LEFT_PANEL_ACTIVE_PAGE		opened_files
			RIGHT_PANEL_ACTIVE_PAGE		Watches
			BOTTOM_PANEL_ACTIVE_PAGE	Simulator
			WINDOW_GEOMETRY			800x600
			ACTIVE_PROJECT			{}
			OPENED_PROJECTS			{}
			VALIDATION_LEVEL		2
			TOOLBAR_VISIBLE			1
			BREAKPOINTS_ALLOWED		1
			CLEANUP_OPTIONS			{
								1 1 1 1 1 1 1 1 1 1 1 1 1 1
								1 1 1 1 1 1 1 0 0 0 0 0 0 0
								0 0 0 0 0 0 0 0 0 0 0 0 0 0
								0 0 0 0
							}
			FIND_OPTIONS			{1 0 1 0 0}
			REPLACE_OPTIONS			{1 0 0 0}
			LETTER_CASE			{- - - - - - - - - - - - - - - - - - - - -}
			KIFSD_CONFIG			{}
			HEXEDIT_CONFIG			{+0+0 hex 0 left}
			INTR_MON_GEOMETRY		{850x270}
			UART_MON_GEOMETRY		{850x270}
			SHOW_PALE_WARN			1
			SUBP_MON_CONFIG			{1 1}
			OPEN_WITH_DLG			{}
			FS_BROWSER_MASK			{*.asm}
			FIND_IN_FILES_CONFIG		{1 0 1 {} {*.asm,*.c,*.h} {}}
			SYMBOL_VIEWER_CONFIG		{1 1 1 1 1 1 1 0 0 0 620x450}
			LINE2PC_JUMP			1
			STOPWATCH_CONFIG		{{} 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
			C_VARS_VIEW_CONF		{400}
			BITMAP_CONFIG			{}
			HW_MANAGER_CONFIG		{}
			FILE_RECENT_FILES		{}
			PROJECT_RECENT_FILES		{}
			VHW_RECENT_FILES		{}
			REGWATCHES_CONFIG		{1 1 0}
			FILE_NOTES			{1 200}
			EIGHT_SEG_EDITOR		{
				{0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7}
				{0 0 1 0 2 0 3 0 4 0 5 0 6 0 7 0}
			}
			BASE_CONVERTERS			{}
			SPEC_CALC			{}
			ASK_ON_FILE_OPEN		1
			SHOW_EDITOR_TAB_BAR		1
			RS232_DEBUGGER			{9600 n 8 1 1 0 {} {} 0 0}
			STACK_MON_GEOMETRY		{}
			STACK_MON_COLLAPSED		1
			SPELL_CHECK_ENABLED		1
			SPELL_CHECK_DICTIONARY		{}
		}

		# Set default dictionary for the spell checking
		set ::CONFIG(SPELL_CHECK_DICTIONARY) [join					\
			[list									\
				[string tolower [lindex [split [::msgcat::mclocale] {_}] 0]]	\
				[string toupper [lindex [split [::msgcat::mclocale] {_}] 1]]	\
			]									\
			{_}									\
		]

		if {$::MICROSOFT_WINDOWS} {
			lset ::CONFIG(FIND_IN_FILES_CONFIG) 3 ${::env(USERPROFILE)}
		}
		set default_CLEANUP_OPTIONS	{
			1 1 1 1 1 1 1 1 1 1 1 1 1 1
			1 1 1 1 1 1 1 0 0 0 0 0 0 0
			0 0 0 0 0 0 0 0 0 0 0 0 0 0
			0 0 0 0
		}
		set default_FIND_OPTIONS	{1 0 1 0 0}
		set default_REPLACE_OPTIONS	{1 0 0 0}

		set session_file_exists [file exists $session_file]

		# Parse session file
		if {!$::CLI_OPTION(defaults) && $session_file_exists} {
			# List of keys which may appear in the session file
			set acceptable_keys {
				LINE_NUMBERS			ICON_BORDER		LEFT_PANEL
				BOTTOM_PANEL			LEFT_PANEL_SIZE		RIGHT_PANEL_SIZE
				BOTTOM_PANEL_SIZE		LEFT_PANEL_ACTIVE_PAGE	RIGHT_PANEL_ACTIVE_PAGE
				BOTTOM_PANEL_ACTIVE_PAGE	WINDOW_GEOMETRY		ACTIVE_PROJECT
				OPENED_PROJECTS			RIGHT_PANEL		KIFSD_CONFIG
				VALIDATION_LEVEL		TOOLBAR_VISIBLE		CLEANUP_OPTIONS
				BREAKPOINTS_ALLOWED		FIND_OPTIONS		REPLACE_OPTIONS
				LETTER_CASE			HEXEDIT_CONFIG		INTR_MON_GEOMETRY
				SUBP_MON_CONFIG			OPEN_WITH_DLG		FS_BROWSER_MASK
				FIND_IN_FILES_CONFIG		SYMBOL_VIEWER_CONFIG	LINE2PC_JUMP
				STOPWATCH_CONFIG		C_VARS_VIEW_CONF	BITMAP_CONFIG
				HW_MANAGER_CONFIG		FILE_RECENT_FILES	PROJECT_RECENT_FILES
				REGWATCHES_CONFIG		EIGHT_SEG_EDITOR	VHW_RECENT_FILES
				BASE_CONVERTERS			WINDOW_ZOOMED		SPEC_CALC
				ASK_ON_FILE_OPEN		SHOW_EDITOR_TAB_BAR	RS232_DEBUGGER
				FILE_NOTES			STACK_MON_GEOMETRY	STACK_MON_COLLAPSED
				SPELL_CHECK_ENABLED		SPELL_CHECK_DICTIONARY	UART_MON_GEOMETRY
				SHOW_PALE_WARN
			}
			# List of datatypes for these keys
			set datatypes {
				B				B			B
				B				I			I
				I				S			S
				S				G			S
				S				B			S
				I				B			S
				B				S			S
				S				S			G
				S				S			S
				S				S			B
				S				S			S
				S				S			S
				S				S			S
				S				B			S
				B				B			S
				S				S			B
				B				S			G
				B
			}

			# Open session file
			set file [open $session_file r]
			while {1} {
				# Break on EOF
				if {[eof $file]} {
					close $file
					break
				}

				# Get and adjust line
				set line [gets $file]
				regsub {\s*#.*$} $line {} line
				if {$line == {}} {continue}

				# Determinate key and value
				regexp {^\w+} $line key
				regexp {\=.*$} $line value
				set value [string replace $value 0 0]
				set key [string trim $key]
				set value [string trim $value "\" \t"]

				# Check for valid key
				set keyIndex [lsearch -exact -ascii $acceptable_keys $key]
				if {$keyIndex == -1} {
					puts stderr "Unrecognized key: '$key'"
					continue
				}
				# Check for valid datatype
				set dt [lindex $datatypes $keyIndex]
				switch -- $dt {
					B {	;# Boolean
						if {![string is boolean -strict $value]} {
							puts stderr "Invalid value '$value', expected boolean"
							continue
						}
					}
					I {	;# unsigned Integer
						if {![string is integer -strict $value]} {
							puts stderr "Invalid value '$value', expected integer"
							continue
						}
					}
					S {	;# String
					}
					G {	;# window Geometry
						if {![regexp {=?\d+x\d+(\+\d+\+\d+)?} $value]} {
							puts stderr "Invalid value '$value', expected win. geometry (key == $key)"
							continue
						}
					}
				}

				# Parse key "OPENED_PROJECTS"
				if {$key == {OPENED_PROJECTS}} {
					set value [string trim $value {( )}]
				}

				# Set appropriate value of config array
				set ::CONFIG($key) $value
			}
		}

		# Validate some configuration values
		if {![regexp {^\s*([01]\s+){45}[01]\s*$} $::CONFIG(CLEANUP_OPTIONS)]} {
			puts stderr "Invalid record CLEANUP_OPTIONS -- setting to default value"
			set ::CONFIG(CLEANUP_OPTIONS) $default_CLEANUP_OPTIONS
		}
		if {![regexp {^\s*[01]\s[01]\s[01]\s[01]\s[01]\s*$} $::CONFIG(FIND_OPTIONS)]} {
			puts stderr "Invalid record FIND_OPTIONS -- setting to default value"
			set ::CONFIG(FIND_OPTIONS) $default_FIND_OPTIONS
		}
		if {![regexp {^\s*[01]\s[01]\s[01]\s[01]\s*$} $::CONFIG(REPLACE_OPTIONS)]} {
			puts stderr "Invalid record REPLACE_OPTIONS -- setting to default value"
			set ::CONFIG(REPLACE_OPTIONS) $default_REPLACE_OPTIONS
		}
		if {![regexp {^\s*[01]\s+[01]\s+[01]\s*$} $::CONFIG(REGWATCHES_CONFIG)]} {
			puts stderr "Invalid record REGWATCHES_CONFIG -- setting to default value"
			set ::CONFIG(REGWATCHES_CONFIG) {1 1 0}
		}

		# Adjust some configuration values
		set line2pc_jump	$::CONFIG(LINE2PC_JUMP)

		set find_option_CS	[lindex $::CONFIG(FIND_OPTIONS) 0]
		set find_option_back	[lindex $::CONFIG(FIND_OPTIONS) 1]
		set find_option_cur	[lindex $::CONFIG(FIND_OPTIONS) 2]
		set find_option_sel	[lindex $::CONFIG(FIND_OPTIONS) 3]
		set find_option_reg	[lindex $::CONFIG(FIND_OPTIONS) 4]

		set replace_option_CS	[lindex $::CONFIG(REPLACE_OPTIONS) 0]
		set replace_option_back	[lindex $::CONFIG(REPLACE_OPTIONS) 1]
		set replace_option_cur	[lindex $::CONFIG(REPLACE_OPTIONS) 2]
		set replace_option_reg	[lindex $::CONFIG(REPLACE_OPTIONS) 3]

		set file_recent_files		$::CONFIG(FILE_RECENT_FILES)
		set project_recent_files	$::CONFIG(PROJECT_RECENT_FILES)
		set vhw_recent_files		$::CONFIG(VHW_RECENT_FILES)

		for {set i 0} {$i < 21} {incr i} {
			set val [lindex $::CONFIG(LETTER_CASE) $i]
			if {$val != {U} && $val != {L} && $val != {-}} {
				set val {-}
			}
			set change_letter_case_options($i) $val
		}

		if {!$::CLI_OPTION(defaults)} {
			if {$::CLI_OPTION(ignore_last)} {
				set ::CONFIG(OPENED_PROJECTS) {}
			}
			if {$::CLI_OPTION(open_project) != {}} {
				set ::CONFIG(OPENED_PROJECTS) [list $::CLI_OPTION(open_project)]
			}
		}

		# Return result
		return $session_file_exists
	}

	## Invoke dialog "Exit program"
	 # @parm Bool force=0 - Do not allow user to cancel the request
	 # @return Int - result
	 #	'0' == Save selected
	 #	'1' == Save all
	 #	'2' == Discard
	 #	'3' == Cancel
	proc shutdown_dialog {{force 0}} {
		variable unsaved_projects	;# List: List of project object marked as "unsaved"

		catch {unset ::exit_dialog_result}

		# Create dialog window
		set dialog [toplevel .save_multiple_projects -class {Save multimple} -bg ${::COMMON_BG_COLOR}]

		# Create the top part of dialog (Header and some icon)
		pack [frame $dialog.topframe] -fill x -expand 1
		pack [label $dialog.topframe.image	\
			-image ::ICONS::32::fileclose	\
		] -side left -padx 10
		pack [label $dialog.topframe.message \
			-text [mc "The following documents have been modified,\ndo you want to save them before closing ?"] \
		] -side right -fill x -expand 1

		# Create the middle part of the dialog (list of unsaved files)
		ttk::labelframe $dialog.lf -text [mc "Unsaved files"] -labelanchor nw -padding 5
		set last_project {}
		set i 0
		foreach unsaved $unsaved_projects {
			# Project name
			if {[lindex $unsaved 0] != $last_project} {
				set last_project [lindex $unsaved 0]
				pack [label $dialog.lf.chp$i						\
					-text [mc "Project: \"%s\"" [$last_project cget -projectName]]	\
					-image ::ICONS::16::kcmdevices					\
					-compound left							\
				] -anchor w -padx 20 -pady 5
			}
			# Unsaved files
			set ::unsavedfile$i 1
			pack [checkbutton $dialog.lf.chb$i			\
				-text [[lindex $unsaved 1] cget -filename]	\
				-variable ::unsavedfile$i			\
			] -anchor w -padx 60
			incr i
		}

		# Create the bottom part of the dialog (buttons)
		ttk::separator $dialog.separator -orient horizontal
		frame $dialog.f
		# button SAVESELECTED
		pack [ttk::button $dialog.f.b_save_selected	\
			-text [mc "Save selected"]		\
			-underline 0				\
			-compound left				\
			-image ::ICONS::16::filesave		\
			-command {set ::exit_dialog_result 0}	\
		] -side left -padx 5
		bind $dialog.f.b_save_selected <Return> {set ::exit_dialog_result 0}
		bind $dialog.f.b_save_selected <KP_Enter> {set ::exit_dialog_result 0}
		# button SAVEALL
		pack [ttk::button $dialog.f.b_save_all		\
			-text [mc "Save all"]			\
			-underline 5				\
			-compound left				\
			-image ::ICONS::16::save_all		\
			-command {set ::exit_dialog_result 1}	\
		] -side left -padx 5
		bind $dialog.f.b_save_all <Return> {set ::exit_dialog_result 1}
		bind $dialog.f.b_save_all <KP_Enter> {set ::exit_dialog_result 1}
		# button DESTROY
		pack [ttk::button $dialog.f.b_discard		\
			-text [mc "Discard"]			\
			-underline 0				\
			-compound left				\
			-image ::ICONS::16::editdelete		\
			-command {set ::exit_dialog_result 2}	\
		] -side left -padx 5
		bind $dialog.f.b_discard <Return> {set ::exit_dialog_result 2}
		bind $dialog.f.b_discard <KP_Enter> {set ::exit_dialog_result 2}
		# button CANCEL
		if {!$force} {
			pack [ttk::button $dialog.f.b_cancel		\
				-text [mc "Cancel"]			\
				-underline 0				\
				-compound left				\
				-image ::ICONS::16::button_cancel	\
				-command {set ::exit_dialog_result 3}	\
			] -side left -padx 5
			bind $dialog.f.b_cancel <Return> {set ::exit_dialog_result 3}
			bind $dialog.f.b_cancel <KP_Enter> {set ::exit_dialog_result 3}
		}

		# Pack GUI parts
		pack $dialog.lf -fill both -expand 1  -pady 10 -padx 10
		pack $dialog.separator -fill x -expand 1 -padx 10
		pack $dialog.f -pady 5 -padx 5

		# Set key-events bindings
		bind $dialog <Alt-Key-s> {set ::exit_dialog_result 0}
		bind $dialog <Alt-Key-a> {set ::exit_dialog_result 1}
		bind $dialog <Alt-Key-d> {set ::exit_dialog_result 2}
		bind $dialog <Alt-Key-c> {set ::exit_dialog_result 3}

		# Window manager options -- modal window
		wm iconphoto $dialog ::ICONS::16::exit
		wm title $dialog [mc "Exit program - MCU 8051 IDE"]
		wm state $dialog normal
		wm minsize $dialog 350 200
		grab $dialog
		focus -force $dialog.f.b_save_all
		wm transient $dialog .
		if {!$force} {
			wm protocol $dialog WM_DELETE_WINDOW "
				grab release $dialog
				destroy $dialog
				set ::exit_dialog_result 3
			"
		} else {
			wm protocol $dialog WM_DELETE_WINDOW "
				tk_messageBox \
					-parent $dialog \
					-type ok \
					-icon warning \
					-title {[mc {Attention}]} \
					-message {[mc {You have to chose one action}]}
			"

		}
		vwait ::exit_dialog_result
		grab release $dialog
		destroy $dialog
		return ${::exit_dialog_result}
	}

	## Simulator: STEPBACK
	 # @return void
	proc __stepback {} {
		variable simulator_enabled		;# List of booleans: Simulator engaged
		variable actualProject			;# Object: Current project
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Check if simulator is engaged
		if {![lindex $simulator_enabled $actualProjectIdx]} {
			Sbar [mc "Simulator is not started"]
			set critical_procedure_in_progress 0
			return
		}

		# Check if simulator isn't busy
		if {[$actualProject sim_is_busy]} {
			Sbar [mc "Simulator is busy"]
			set critical_procedure_in_progress 0
			return
		}

		# Perform program step
		stepback_button_set_ena [$actualProject stepback]
		set lineNum [$actualProject simulator_getCurrentLine]
		if {$lineNum != {}} {
			$actualProject move_simulator_line $lineNum
		} else {
			$actualProject editor_procedure {} unset_simulator_line {}
		}
		$actualProject Simulator_sync_PC_etc

		# Finalize
		set critical_procedure_in_progress 0
	}

	## Simulator: STEP
	 # @return void
	proc __step {} {
		variable simulator_enabled		;# List of booleans: Simulator engaged
		variable actualProject			;# Object: Current project
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Check if simulator is engaged
		if {![lindex $simulator_enabled $actualProjectIdx]} {
			Sbar [mc "Simulator is not started"]
			set critical_procedure_in_progress 0
			return
		}

		# Check if simulator isn't busy
		if {[$actualProject sim_is_busy]} {
			Sbar [mc "Simulator is busy"]
			set critical_procedure_in_progress 0
			return
		}

		# Perform program step
		set lineNum [$actualProject step]
		if {$lineNum != {}} {
			$actualProject move_simulator_line $lineNum
		} else {
			$actualProject editor_procedure {} unset_simulator_line {}
		}
		stepback_button_set_ena [$actualProject simulator_get_SBS_len]
		$actualProject Simulator_sync_PC_etc

		# Finalize
		set critical_procedure_in_progress 0
	}

	## Simulator: STEPOVER
	 # @return void
	proc __stepover {} {
		variable simulator_enabled		;# List of booleans: Simulator engaged
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Check if simulator is engaged
		if {![lindex $simulator_enabled $actualProjectIdx]} {
			Sbar [mc "Simulator is not started"]
			set critical_procedure_in_progress 0
			return
		}
		# Check if simulator isn't busy
		if {[$actualProject sim_run_in_progress] || [$actualProject sim_anim_in_progress]} {
			Sbar [mc "Simulator is busy"]
			set critical_procedure_in_progress 0
			return
		}



		# Change button image (simulator control panel)
		$actualProject invert_stepover_button

		# Perform program step
		set lineNum [$actualProject sim_stepover]
		if {$lineNum != {}} {
			$actualProject move_simulator_line $lineNum
		} else {
			$actualProject editor_procedure {} unset_simulator_line {}
		}

		stepback_button_set_ena [$actualProject simulator_get_SBS_len]
		$actualProject invert_stepover_button	;# Change button image (simulator control panel)
		$actualProject Simulator_sync_PC_etc	;# Synchronize PC and Time
	}

	## Simulator: ANIMATE
	 # @return void
	proc __animate {} {
		variable simulator_enabled		;# List of booleans: Simulator engaged
		variable actualProject			;# Object: Current project
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Check if simulator is engaged
		if {![lindex $simulator_enabled $actualProjectIdx]} {
			Sbar [mc "Simulator is not started"]
			set critical_procedure_in_progress 0
			return
		}

		# Check if simulator isn't busy
		if {[$actualProject sim_run_in_progress] || [$actualProject sim_stepover_in_progress]} {
			Sbar [mc "Simulator is busy"]
			set critical_procedure_in_progress 0
			return
		}

		stepback_button_set_ena [$actualProject simulator_get_SBS_len]
		$actualProject invert_animate_button	;# Change button image (simulator control panel)
		$actualProject sim_animate		;# Start simulator in mode "animate"
		$actualProject invert_animate_button	;# Change button image (simulator control panel)
	}

	## Simulator: RUN
	 # @return void
	proc __run {} {
		variable simulator_enabled		;# List of booleans: Simulator engaged
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Check if simulator isn't already engaged
		if {![lindex $simulator_enabled $actualProjectIdx]} {
			Sbar [mc "Simulator is not started"]
			set critical_procedure_in_progress 0
			return
		}

		# Check if simulator isn't busy
		if {[$actualProject sim_anim_in_progress] || [$actualProject sim_stepover_in_progress]} {
			Sbar [mc "Simulator is busy"]
			set critical_procedure_in_progress 0
			return
		}

		# Change button image (simulator control panel)
		$actualProject invert_run_button
		## Start simulator
		# Remove simulator cursor from editor
		$actualProject editor_procedure {} unset_simulator_line {}
		# Engage mode "run"
		set line_num [$actualProject sim_run]
		if {$line_num != {}} {
			$actualProject move_simulator_line $line_num
		} else {
			$actualProject editor_procedure {} unset_simulator_line {}
		}
		# Adjust simulator control panel
		$actualProject invert_run_button
		stepback_button_set_ena [$actualProject simulator_get_SBS_len]
		# Synchronize
		$actualProject Simulator_sync		;# Simulator GUI (registers)
		$actualProject Simulator_sync_clock	;# Simulator GUI (time)
		$actualProject Simulator_sync_PC_etc	;# Simulator GUI (PC, Watchdog, etc.)
		refresh_xram_mem_window $actualProject		;# XDATA memory hexadecimal editor
		refresh_eram_mem_window $actualProject		;# EDATA memory hexadecimal editor
		refresh_eeprom_mem_window $actualProject	;# Data EEPROM  hexadecimal editor
	}

	## Simulator: RESET
	 # @parm Char arg - reset mode
	 #		'-' == no change	(IRAM and XRAM)
	 #		'0' == all zeroes	(IRAM and XRAM)
	 #		'1' == all ones		(IRAM and XRAM)
	 #		'r' == random values	(IRAM and XRAM)
	 # @return void
	proc __reset {arg} {
		variable simulator_enabled		;# List of booleans: Simulator engaged
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable opened_code_mem_windows	;# List of project object with opened CODE memory hex editor
		variable code_mem_window_objects	;# List of CODE memory hex editor objects

		if {$project_menu_locked} {return}

		# This function is critical + simulator must be on
		if {$critical_procedure_in_progress} {return}
		if {![lindex $simulator_enabled $actualProjectIdx]} {
			Sbar [mc "Simulator is not started"]
			return
		}
		set critical_procedure_in_progress 1

		# Clear program time
		$actualProject simulator_clear_overall_time
		# Clear graph
		$actualProject clear_graph
		# Perform reset
		$actualProject Simulator_reset $arg
		$actualProject simulator_setWatchDogTimer 0
		# Move simulator cursor in editor to the beginning of the program
		foreach editor [$actualProject cget -editors] {
			$editor unset_simulator_line
		}
		$actualProject move_simulator_line [$actualProject simulator_getCurrentLine]

		# Synchronize with Hex editor and Register watches on right panel
		if {$arg != {-}} {
			refresh_xram_mem_window $actualProject
			refresh_eram_mem_window $actualProject
			refresh_eeprom_mem_window $actualProject
			$actualProject rightPanel_watch_sync_all
		}

		# Inform code memory hexadecimal editor about the reset
		program_counter_changed $actualProject 0

		# Finalize
		set critical_procedure_in_progress 0
	}

	## Start/Shutdown simulator
	 # @parm Bool current_file_only=0 - Load debug file for the current file only (not the main file)
	 # @return void
	proc __initiate_sim {{current_file_only 0}} {
		variable actualProject			;# Object: Current project
		variable simulator_enabled		;# List of booleans: Simulator engaged
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable opened_code_mem_windows	;# List of project object with opened CODE memory hex editor
		variable code_mem_window_objects	;# List of CODE memory hex editor objects

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Clear program timer
		$actualProject simulator_clear_overall_time

		# Shutdown simulator
		if {[lindex $simulator_enabled $actualProjectIdx] == 1} {
			lset simulator_enabled $actualProjectIdx 0	;# Simlulator disabled (set flag)
			$actualProject Simulator_shutdown		;# Shutdown simulator engine
			$actualProject sim_disable			;# Disable widgets of simulator GUI
			$actualProject sfr_watches_disable		;# Disable SFR watches
			$actualProject rightPanel_watch_disable		;# Disable widgets of register watches
			$actualProject sfrmap_setEnabled 0		;# Disable SFR map
			$actualProject bitmap_setEnabled 0		;# Disable map of bit area
			$actualProject thaw				;# Unlock menus in file lists
			line2pc_safely_close				;# Safely Close dialog "Line to address"
			$actualProject subprograms_setEnabled 0		;# Disable list of subprograms
			$actualProject cvarsview_setEnabled 0		;# Disable C vars view
			$actualProject stack_monitor_set_enabled 0	;# Disable stack monitor
			update
			Lock_simulator_menu				;# Lock simulator menu and toolbar
			$actualProject interrupt_monitor_disable_buttons;# Disable interrupt monitor

			# Remove simulator pointers
			foreach editor [$actualProject cget -editors] {
				$editor unset_simulator_line
			}

			# Inform code memory hexadecimal editor about that
			set idx [lsearch -exact -ascii $opened_code_mem_windows [string trimleft $actualProject {:}]]
			if {$idx != -1} {
				[lindex $code_mem_window_objects $idx] simulator_stared_stopped 0
			}

		# Start simulator
		} else {
			# Get ID of currently active page on bottom notebook
			set bottom_page_ID [$actualProject getBottomPanelActivePage]

			# Determinate name of simulator data file
			set full_file_name [list				\
				[$actualProject cget -projectPath]		\
				[$actualProject cget -P_option_main_file]	\
			]
			set relative_name [lindex $full_file_name 1]
			if {$current_file_only || $relative_name == {}} {
				set full_file_name [$actualProject editor_procedure {} getFileName {}]
				set language [$actualProject editor_procedure {} get_language {}]
				set relative_name [lindex $full_file_name 1]
			} else {
				set ext [string trimleft [file extension $relative_name] {.}]
				if {$ext == {c} || $ext == {h} || $ext == {cxx} || $ext == {cpp} || $ext == {cc}} {
					set language 1
				} elseif {$ext == {lst}} {
					set language 2
				} else {
					set language 0
				}
			}
			set full_file_name [file join [lindex $full_file_name 0] [lindex $full_file_name 1]]
			set full_file_name [file rootname $full_file_name]
			if {$language == 1} {
				append full_file_name {.cdb}
			} else {
				append full_file_name {.adf}
			}

			# Try to open the file and determinate expected MD5 hash
			if  {![catch {
				# C language
				if {$language == 1} {
					set hashes_file [open "[file rootname $full_file_name].hashes" {r}]
					set expected_md5s [read $hashes_file]
					close $hashes_file

				# Assembly language
				} elseif {$language == 0} {
					set expected_md5s {}
					set simulator_file [open $full_file_name r]
					while {![eof $simulator_file]} {
						set line [gets $simulator_file]
						if {$line == {} || [regexp {^\s*#} $line]} {
							continue
						}
						set expected_md5s $line
						break
					}
					close $simulator_file

				# Invalid request!
				} else {
					error "Invalid request!"
				}

			}]} then {
				# MD5 hash verification failed -> ask for recompilation
				if {($language == 0 || $language == 1) && [verify_md5_hashes 1 $expected_md5s [file dirname $full_file_name]]} {
					# Ask for recompilation
					set response [
						tk_messageBox			\
							-parent .		\
							-icon question		\
							-type yesno		\
							-default {yes}		\
							-title [mc "Recompile ?"]	\
							-message [mc "MD5 hashes verification failed. That probably means than some source files have been modified since last compilation.\n\nDo you want to recompile the code ?"] \
					]
					if {$response != {yes}} {
						set critical_procedure_in_progress 0
						return
					}

					## Compile the source code
					set compilation_result [__compile 1 1]
					 # (0) Compilation failed
					if {!$compilation_result} {
						tk_messageBox		\
							-parent .	\
							-icon error	\
							-type ok	\
							-title [mc "Compilation failed"]	\
							-message [mc "Compilation failed, see messages for details."]
						set critical_procedure_in_progress 0
						return
					 # (2) External compiler used
					} elseif {$compilation_result == 2} {
						return
					}
				}
			# Unable to open the simulator data file -> ask for recompilation
			} else {
				# Ask for recompilation
				set response [
					tk_messageBox		\
						-parent .	\
						-icon question	\
						-type yesno	\
						-title [mc "File not found"]	\
						-message [mc "Simulator data file not found.\nDo you want create it ?"]
				]
				if {$response != {yes}} {
					set critical_procedure_in_progress 0
					return
				}

				## Compile the source code
				set compilation_result [__compile 1 1]
				 # (0) Compilation failed
				if {!$compilation_result} {
					tk_messageBox		\
						-parent .	\
						-icon error	\
						-type ok	\
						-title [mc "Compilation failed"]	\
						-message [mc "Compilation failed, see messages for details."]
					set critical_procedure_in_progress 0
					return
				 # (2) External compiler used
				} elseif {$compilation_result == 2} {
					return
				}

				set full_file_name [list				\
					[$actualProject cget -projectPath]		\
					[$actualProject cget -P_option_main_file]	\
				]
				if {[lindex $full_file_name 1] == {}} {
					set full_file_name [$actualProject editor_procedure {} getFileName {}]
				}
				set full_file_name [file join [lindex $full_file_name 0] [lindex $full_file_name 1]]
				regsub {\.[^\.]*$} $full_file_name {} full_file_name
				append full_file_name {.adf}
			}

			# Open simulator data file
			if {[catch {
				set simulator_file [open $full_file_name r]
			}]} then {
				tk_messageBox		\
					-parent .	\
					-icon warning	\
					-type ok	\
					-title [mc "Unable to start simulator"]	\
					-message [mc "Unable to read simulator file. Possibly you have disabled generation of simulator file in compiler configuration dialog."]
				set critical_procedure_in_progress 0
				return
			}

			# Try to load IHX file if C language is used
			if {$language == 1} {
				if {[catch {
					set hex_file [open "[file rootname $full_file_name].ihx" r]
				} result]} then {
					puts stderr $result
					tk_messageBox		\
						-parent .	\
						-type ok	\
						-icon warning	\
						-title [mc "Unable to find hex file"]	\
						-message [mc "Unable to open:\n'%s'" "[file rootname $full_file_name].ihx"]
					return
				}
			}

			$actualProject freeze	;# Switch filelist to "Simulator mode"
			update

			# Raise tab "Simulator" on the bottom panel
			if {[lsearch {Graph Simulator CVarsView} $bottom_page_ID] == -1} {
				$actualProject bottomNB_show_up {Simulator}
			} else {
				$actualProject bottomNB_show_up $bottom_page_ID
			}

			## Engage simulator
			lset simulator_enabled $actualProjectIdx 1	;# Set simulator enabled flag to True
			$actualProject sim_enable			;# Enable simulator GUI
			$actualProject sfr_watches_enable		;# Enable SFR watches
			$actualProject sfrmap_setEnabled 1		;# Enable SFR map
			$actualProject bitmap_setEnabled 1		;# Enable map of bit area

			# Load program into simulator engine
			if {$language == 1} {
				if {[$actualProject load_program_from_cdb	\
					[file rootname $full_file_name].c	\
					$simulator_file $hex_file		\
				]} {
					seek $simulator_file 0
					$actualProject cvarsview_load_cdb $simulator_file
				}
				close $hex_file
			} else {
				$actualProject load_program_from_adf $simulator_file
			}

			# Autoload list of defined symbolic name into register watches
			$actualProject rightPanel_watch_autoload [file rootname $full_file_name].lst

			# Some more initialization
			close $simulator_file				;# Close simulator data file
			$actualProject clear_graph			;# Clear graph
			$actualProject Simulator_sync			;# Synchronize simulator (due to reset)
			$actualProject rightPanel_watch_enable		;# Enable entry widgets in register watches
			$actualProject subprograms_setEnabled 1		;# Enable list of subprograms
			$actualProject cvarsview_setEnabled 1		;# Enable C vars view
			$actualProject stack_monitor_set_enabled 1	;# Enable stack monitor
			$actualProject Simulator_initiate		;# Initialize simulator engine
			$actualProject interrupt_monitor_enable_buttons	;# Enable interrupt monitor
			__sim_clear_highlight				;# Clear all highlights

			# Reset virtual MCU
			set critical_procedure_in_progress 0
			__reset -
			set critical_procedure_in_progress 1

			# Load breakpoints into simulator engine
			set found 0
			set editor {}
			set editors [$actualProject cget -editors]
			foreach filename [$actualProject simulator_get_list_of_filenames] {
				set found 0
				foreach editor $editors {
					if {$filename == [$editor cget -fullFileName]} {
						set found 1
						break
					}
				}
				if {$found} {
					$actualProject Simulator_import_breakpoints	\
						$filename [$editor getBreakpoints]
				} else {
					$actualProject Simulator_import_breakpoints $filename {}
				}
			}

			# Detect and report invalid breakpoints
			$actualProject report_invalid_breakpoints

			$actualProject now_frozen

			# Set simulator cursor in editor to the first OP code
			$actualProject move_simulator_line [$actualProject simulator_getCurrentLine]
			refresh_code_mem_window $actualProject			;# Synchronize CODE memory hex editor
			update
			Unlock_simulator_menu				;# Unlock simulator menu and toolbar
			stepback_button_set_ena 0			;# Disable StepBack controls

			# Inform code memory hexadecimal editor about that
			set idx [lsearch -exact -ascii $opened_code_mem_windows [string trimleft $actualProject {:}]]
			if {$idx != -1} {
				[lindex $code_mem_window_objects $idx] simulator_stared_stopped 1
			}
		}

		# Finalize
		set critical_procedure_in_progress 0
	}

	## Verify MD5 hashes for the given files (only for current project)
	 # @parm Bool save_files	- Save modified files mentioned in the given list
	 # @parm List hashes		- {hash filename hash filename ...}
	 # @parm String dir		- Directory where the function will search for the files mentioned in "$hashes"
	 # @return Int - Final result
	 #	0 == All correct
	 #	1 == Verification failed
	 #	2 == File access error
	proc verify_md5_hashes {save_files hashes dir} {
		variable actualProject	;# Object: Current project

		# Local variables
		set len		[llength $hashes]	;# Length of the given list of hashes and files
		set filenames	{}			;# List of filenames only
		set md5_hashes	{}			;# List of md5 hashes only

		# Separate filenames and hashes
		for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {
			lappend filenames [file join $dir [lindex $hashes $j]]
			lappend md5_hashes [lindex $hashes $i]
		}
		set len [expr {int($len/2)}]

		# Save mentioned files
		if {$save_files} {
			set idx		0
			set e_filenames	{}
			set editors	[$actualProject cget -editors]

			# Determinate list of opened files
			foreach editor $editors {
				set filename [$editor cget -fullFileName]
				if {$filename == {}} {
					continue
				}

				lappend e_filenames $filename
			}

			# Save files
			for {set i 0} {$i < $len} {incr i} {
				set idx [lsearch $e_filenames [lindex $filenames $i]]

				if {$idx == -1} {continue}

				if {[[lindex $editors $idx] cget -modified]} {
					[lindex $editors $idx] save
				}
			}
		}

		# Check MD5s
		for {set i 0} {$i < $len} {incr i} {
			set recorded_md5 [lindex $md5_hashes $i]
			if {[catch {
				set computed_md5 [::md5::md5 -hex -file [lindex $filenames $i]]
			}]} then {
				return 2
			}

			if {$recorded_md5 != $computed_md5} {
				return 1
			}
		}

		return 0
	}

	## Invoke file selection dialog to normalize IHEX8 file
	 # @return void
	proc __normalize_hex {} {
		variable input_file			;# Input file
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time

		if {$critical_procedure_in_progress} {return}

		# Invoke dialog to select input file
		set input_file {}
		select_input_output 1 {hex} .
		if {$input_file == {}} {return}

		# File name is not valid -> invoke error message
		if {
			$input_file == {}		||
			![file exists $input_file]	||
			![file isfile $input_file]	||
			(!$::MICROSOFT_WINDOWS && ![file writable $input_file])	||
			(!$::MICROSOFT_WINDOWS && ![file readable $input_file])
		} then {
			tk_messageBox				\
				-parent . -icon warning		\
				-title [mc "Error - MCU 8051 IDE"]	\
				-message [mc "Unable to gain unlimited access to the given file"]
		# File name is valid -> normalize its content
		} else {
			# Progress dialog
			create_progress_bar .prgDl		\
				.				\
				{}				\
				"Parsing file: $input_file"	\
				::IHexTools::progress		\
				1				\
				[mc "Parsing file ..."]		\
				::ICONS::16::bottom1		\
				[mc "Abort"]			\
				{set ::IHexTools::abort 1}

			# Read file
			set file [open $input_file r]
			set data [read $file]
			close $file

			# Normalize content
			set ::IHexTools::update 1
			catch {.prgDl.f.progressbar configure -maximum [::IHexTools::get_number_of_iterations $data]}
			::IHexTools::load_hex_data $data
			if {!${::IHexTools::abort} && !${::IHexTools::error_count}} {
				catch {.prgDl.f.progressbar configure -maximum 16}
				set data [::IHexTools::get_hex_data]
			}

			# Destroy progress dialog
			catch {destroy .prgDl}

			# No errors occurred -> rewrite file
			if {!${::IHexTools::error_count}} {
				if {[catch {
					set file [open $input_file w 0640]
				}]} then {
					tk_messageBox		\
						-type ok	\
						-icon error	\
						-parent .	\
						-title [mc "Permission denied"]	\
						-message [mc "Unable to open file:\n\"%s\"\nfor writing" $input_file]
					return
				} else {
					puts -nonewline $file $data
					close $file
				}
			# Errors occurred -> Invoke error message dialog
			} else {
				# Create dialog window
				set dialog [toplevel .error_message_dialog -class {Error dialog} -bg ${::COMMON_BG_COLOR}]

				# Create main frame (text widget and scrolbar)
				set main_frame [frame $dialog.main_frame]

				# Create text widget
				set text [text $main_frame.text				\
					-yscrollcommand "$main_frame.scrollbar set"	\
					-width 0 -height 0		\
				]
				pack $text -side left -fill both -expand 1
				# Create scrollbar
				pack [ttk::scrollbar $main_frame.scrollbar	\
					-orient vertical			\
					-command "$text yview"			\
				] -side right -fill y

				# Pack main frame and create button "Close"
				pack $main_frame -fill both -expand 1
				pack [ttk::button $dialog.ok_button				\
					-text [mc "Close"]					\
					-command "grab release $dialog; destroy $dialog"	\
				]

				# Show error string and disable the text widget
				$text insert end ${::IHexTools::error_string}
				$text configure -state disabled

				# Set window attributes
				wm iconphoto $dialog ::ICONS::16::status_unknown
				wm title $dialog [mc "Error(s) occurred while parsing IHEX file - %s" ${::APPNAME}]
				wm minsize $dialog 500 250
				wm protocol $dialog WM_DELETE_WINDOW [mc "grab release %s; destroy %s" $dialog $dialog]
				wm transient $dialog .
				grab $dialog
				raise $dialog
				tkwait window $dialog
			}

			# Free resources reserved during normalization
			::IHexTools::free_resources
		}
	}

	## Invoke dialog for converting Binary files to Intel® HEX 8 files
	 # @return void
	proc __bin2hex {} {
		variable hex__bin	;# Type of conversion

		set hex__bin 0
		hex2bin2hex
	}

	## Invoke dialog for converting Intel® HEX 8 files to Binary files
	 # @return void
	proc __hex2bin {} {
		variable hex__bin	;# Type of conversion
		set hex__bin 1
		hex2bin2hex
	}

	## Invoke dialog for converting Simulator data files to Intel® HEX 8 files
	 # @return void
	proc __sim2hex {} {
		variable hex__bin	;# Type of conversion
		set hex__bin 2
		hex2bin2hex
	}

	## Invoke dialog for converting Simulator data files to Binary files
	 # @return void
	proc __sim2bin {} {
		variable hex__bin	;# Type of conversion
		set hex__bin 3
		hex2bin2hex
	}

	## Invoke conversion dialog -- auxiliary procedure for '__bin2hex', '__hex2bin', '__sim2hex', '__sim2bin'
	 # @return void
	proc hex2bin2hex {} {
		variable input_file			;# Input file
		variable output_file			;# Output file
		variable hex__bin			;# Type of conversion
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time

		if {$critical_procedure_in_progress} {return}

		# Create dialog window
		set win [toplevel .hex2bin2hex_dialog -class {Conversion} -bg ${::COMMON_BG_COLOR}]
		set mainframe [frame $win.frame]

		# Label, Entry and Button "Input file"
		grid [Label $mainframe.lbl_input		\
			-text [mc "Input file"]			\
			-helptext [mc "File to convert"]	\
		] -column 1 -row 1 -sticky w
		grid [ttk::entry $mainframe.entry_input	\
			-textvariable X::input_file	\
			-width 50			\
		] -column 2 -row 1 -sticky we
		DynamicHelp::add $mainframe.entry_input -text [mc "File to convert"]
		grid [ttk::button $mainframe.button_select_input_file	\
			-image ::ICONS::16::fileopen			\
			-takefocus 0					\
			-style Flat.TButton				\
			-command {
				# Determinate file suffix
				if {${::X::hex__bin} == 0} {
					set mask {bin}
				} elseif {${::X::hex__bin} == 1} {
					set mask {{hex,ihx}}
				} else {
					set mask {adf}
				}
				# Invoke file selection dialog
				X::select_input_output 1 $mask .hex2bin2hex_dialog
			}	\
		] -column 3 -row 1 -sticky e
		DynamicHelp::add $mainframe.button_select_input_file	\
			-text [mc "Invoke dialog to select input file"]

		# Label, Entry and Button "Output file"
		grid [Label $mainframe.lbl_output			\
			-text [mc "Output file"]			\
			-helptext [mc "File where to save result"]	\
		] -column 1 -row 2 -sticky w
		grid [ttk::entry $mainframe.entry_output	\
			-textvariable X::output_file	\
			-width 50			\
		] -column 2 -row 2 -sticky we
		DynamicHelp::add $mainframe.entry_output	\
			-text [mc "File where to save result"]
		grid [ttk::button $mainframe.button_select_output_file	\
			-image ::ICONS::16::fileopen			\
			-style Flat.TButton				\
			-command {
				# Determinate file suffix
				if {${::X::hex__bin} == 0} {
					set mask {{hex,ihx}}
				} elseif {${::X::hex__bin} == 1} {
					set mask {bin}
				} elseif {${::X::hex__bin} == 2} {
					set mask {{hex,ihx}}
				} elseif {${::X::hex__bin} == 3} {
					set mask {bin}
				}
				# Invoke file selection dialog
				X::select_input_output 0 $mask .hex2bin2hex_dialog
			}	\
		] -column 3 -row 2 -sticky e
		DynamicHelp::add $mainframe.button_select_output_file	\
			-text [mc "Invoke dialog to select output file"]

		# Create separator
		grid [ttk::separator $mainframe.separator	\
			-orient horizontal			\
		] -column 1 -columnspan 3 -row 3 -sticky we -pady 10

		# Create buttons "Ok" and "Cancel"
		set button_frame [frame $mainframe.button_frame]
		pack [ttk::button $button_frame.button_ok	\
			-text [mc "Ok"]			\
			-command {X::hex2bin2hex_OK}	\
			-compound left			\
			-image ::ICONS::16::ok		\
		] -side left -padx 5
		pack [ttk::button $button_frame.button_cancel	\
			-text [mc "Cancel"]			\
			-command {X::hex2bin2hex_CANCEL}	\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
		] -side left -padx 5
		grid $button_frame -column 1 -columnspan 3 -row 4

		# Set window title
		if {$hex__bin == 0} {
			wm title $win [mc "Convert Binary file to Intel HEX 8 - MCU 8051 IDE"]
		} elseif {$hex__bin == 1} {
			wm title $win [mc "Convert Intel HEX 8 to binary file - MCU 8051 IDE"]
		} elseif {$hex__bin == 2} {
			wm title $win [mc "Convert sim file to Intel HEX 8 - MCU 8051 IDE"]
		}

		pack $mainframe -fill both -expand 1 -padx 5 -pady 5

		# Event bindings (Enter == Ok; Escape == Cancel)
		bind $win <KeyRelease-Return>	{X::hex2bin2hex_OK; break}
		bind $win <KeyRelease-KP_Enter>	{X::hex2bin2hex_OK; break}
		bind $win <KeyRelease-Escape>	{X::hex2bin2hex_CANCEL; break}

		# Set window attributes -- modal window
		wm iconphoto $win ::ICONS::16::bottom1
		wm minsize $win 450 100
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW {
			X::hex2bin2hex_CANCEL
		}
		wm transient $win .
		catch {grab $win}
		raise $win
		tkwait window $win
	}

	## Increment compilation progress variable and call update command
	 # @return void
	proc update_progress {} {
		variable compilation_progress	;# Variable for compilation progressbar

		incr compilation_progress
		update
	}

	## Set maximum for progressbar in file conversion dialog
	 # -- internal auxiliary procedure for 'hex2bin2hex_OK'
	 # @parm Int max - value to set
	 # @return void
	proc hex2bin2hex_set_progress_max {max} {
		.hex2bin2hex_dialog.button_frame.progress_bar configure -maximum $max
	}

	## Perform file conversion -- auxiliary procedure for 'hex2bin2hex'
	 # @return void
	proc hex2bin2hex_OK {} {
		variable input_file	;# Input file
		variable output_file	;# Output file
		variable hex__bin	;# Type of conversion

		# Check if input and output file names are not empty strings
		if {$input_file == {} || $output_file == {}} {
			tk_messageBox				\
				-parent .hex2bin2hex_dialog	\
				-icon warning -type ok		\
				-title "MCU 8051 IDE"		\
				-message [mc "Both entries must be filled"]
			return
		}

		# Normalize name of input file
		if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
			if {![regexp "^(~|/)" $input_file]} {
			set filename "[${::X::actualProject} cget -ProjectDir]/$input_file"
			}
		} else {	;# Microsoft windows way
			if {![regexp {^\w:} $input_file]} {
				set filename [file join [${::X::actualProject} cget -ProjectDir] $input_file]
			}
		}
		set input_file [file normalize $input_file]

		# Normalize name of output file
		if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
			if {![regexp "^(~|/)" $output_file]} {
			set filename "[${::X::actualProject} cget -ProjectDir]/$output_file"
			}
		} else {	;# Microsoft windows way
			if {![regexp {^\w:} $output_file]} {
				set filename [file join [${::X::actualProject} cget -ProjectDir] $output_file]
			}
		}
		set output_file [file normalize $output_file]

		set win .hex2bin2hex_dialog

		bind $win <KeyRelease-Return>	{}
		bind $win <KeyRelease-KP_Enter>	{}
		bind $win <KeyRelease-Escape>	{}

		# Diable entry widgets in file selection dialog
		foreach wdg [subst {
			$win.frame.entry_input
			$win.frame.entry_output
			$win.frame.button_select_input_file
			$win.frame.button_select_output_file
		}] {
			$wdg configure -state disabled
		}

		# Destroy buttons "Ok" and "Cancel"
		destroy $win.frame.button_frame.button_ok
		destroy $win.frame.button_frame.button_cancel

		# Change window size
		wm minsize $win 450 170

		# Create staus label, progressbar and Abort button
		set status_label [label $win.frame.button_frame.status_label -justify left]
		set progressbar [ttk::progressbar		\
			$win.frame.button_frame.progress_bar	\
			-variable ::IHexTools::progress		\
			-mode determinate			\
			-length 440				\
		]
		pack $status_label -anchor w -padx 10
		pack $progressbar -pady 15
		pack [ttk::button $win.frame.button_frame.button_ok	\
			-text [mc "Abort"]				\
			-image ::ICONS::16::cancel			\
			-compound left					\
			-command {X::hex2bin2hex_ABORT}			\
		] -pady 5

		# Create backup copy for output file
		if {[file exists $output_file] && [file isfile $output_file]} {
			if {![file writable $output_file]} {
				tk_messageBox					\
					-type ok				\
					-icon error				\
					-parent $win				\
					-title [mc "Permission denied"]		\
					-message [mc "Unable to access file: %s" $output_file]
				hex2bin2hex_CANCEL
				return
			}
			# Ask user for overwrite existing file
			if {[tk_messageBox			\
				-type yesno			\
				-icon question			\
				-parent $win			\
				-title [mc "Overwrite file"]	\
				-message [mc "A file name '%s' already exists. Are you sure you want to overwrite it ?" [file tail $output_file]]
				] != {yes}
			} then {
				hex2bin2hex_CANCEL
				return
			}
			# Create a backup file
			catch {
				file rename -force $output_file "$output_file~"
			}
		}

		# Read input file
		if {[catch {
			set file [open $input_file r]
			fconfigure $file -translation binary
			set data [read $file]
			close $file
		}]} then {
			tk_messageBox		\
				-type ok	\
				-icon warning	\
				-parent $win	\
				-title [mc "File not found - MCU 8051 IDE"] \
				-message [mc "Unable to open file '%s'" $input_file]

		} else {
			# Update progress variable
			set ::IHexTools::update 1

			# Perform cnversion
			switch -- $hex__bin {
				0 {	;# Bin -> Hex
					$status_label configure -text [mc "Loading file ..."]
					::IHexTools::load_bin_data $data
					set data {}
					if {!${::IHexTools::abort} && !${::IHexTools::error_count}} {
						$status_label configure -text [mc "Saving file ..."]
						$progressbar configure -maximum 16
						set data [::IHexTools::get_hex_data]
					}
				}
				1 {	;# Hex -> Bin
					$status_label configure -text [mc "Loading file ..."]
					$progressbar configure -maximum [::IHexTools::get_number_of_iterations $data]
					::IHexTools::load_hex_data $data
					set data {}
					if {!${::IHexTools::abort} && !${::IHexTools::error_count}} {
						$status_label configure -text [mc "Saving file ..."]
						$progressbar configure -maximum 16
						set data [::IHexTools::get_bin_data]
					}
				}
				2 {	;# Sim -> Hex
					$status_label configure -text [mc "Loading file ..."]
					$progressbar configure -maximum [::IHexTools::get_number_of_iterations $data]
					::IHexTools::load_sim_data $data
					set data {}
					if {!${::IHexTools::abort} && !${::IHexTools::error_count}} {
						$status_label configure -text [mc "Saving file ..."]
						$progressbar configure -maximum 16
						set data [::IHexTools::get_hex_data]
					}
				}
				3 {	;# Sim -> Bin
					$status_label configure -text [mc "Loading file ..."]
					$progressbar configure -maximum [::IHexTools::get_number_of_iterations $data]
					::IHexTools::load_sim_data $data
					set data {}
					if {!${::IHexTools::abort} && !${::IHexTools::error_count}} {
						$status_label configure -text [mc "Saving file ..."]
						$progressbar configure -maximum 16
						set data [::IHexTools::get_bin_data]
					}
				}
				default {
					set data {}
				}
			}

			# Write output file
			if {[string length $data]} {
				if {[catch {
					set file [open $output_file w 0640]
				}]} then {
					tk_messageBox		\
						-type ok	\
						-icon error	\
						-parent .	\
						-title [mc "Permission denied"]	\
						-message [mc "Unable to open file:\n\"%s\"\nfor writing" $output_file]
					hex2bin2hex_CANCEL
					return
				} else {
					fconfigure $file -translation binary
					puts -nonewline $file $data
					close $file
				}
			}
		}

		# If errors occurred -> Invoke error message dialog
		if {${::IHexTools::error_count}} {
			# Create dialog window
			set dialog [toplevel .error_message_dialog -class {Error dialog} -bg ${::COMMON_BG_COLOR}]

			# Create main frame (text and scrollbar)
			set main_frame [frame $dialog.main_frame]
			set text [text $main_frame.text				\
				-yscrollcommand "$main_frame.scrollbar set"	\
				-width 0 -height 0				\
			]
			pack $text -side left -fill both -expand 1
			pack [ttk::scrollbar $main_frame.scrollbar	\
				-orient vertical			\
				-command "$text yview"			\
			] -side right -fill y
			pack $main_frame -fill both -expand 1

			# Create button "Close"
			pack [ttk::button $dialog.ok_button			\
				-text [mc "Close"]				\
				-command "grab release $dialog; destroy $dialog"\
			]

			$text insert end ${::IHexTools::error_string}
			$text configure -state disabled

			# Set window attributes -- modal window
			wm iconphoto $dialog ::ICONS::16::no
			wm title $dialog [mc "Corrupted file - MCU 8051 IDE"]
			wm minsize $dialog 520 250
			wm protocol $dialog WM_DELETE_WINDOW "grab release $dialog; destroy $dialog"
			wm transient $dialog .hex2bin2hex_dialog
			grab $dialog
			raise $dialog
			tkwait window $dialog
		}

		# Close original dialog
		hex2bin2hex_CANCEL
	}

	## Abort file conversion -- auxiliary procedure for 'hex2bin2hex'
	 # @return void
	proc hex2bin2hex_ABORT {} {
		set ::IHexTools::abort 1
	}

	## Close file conversion dialog -- auxiliary procedure for 'hex2bin2hex'
	 # @return void
	proc hex2bin2hex_CANCEL {} {
		::IHexTools::free_resources
		grab release .hex2bin2hex_dialog
		destroy .hex2bin2hex_dialog
	}

	## Invoke file selection dialog to select input or output file
	 # Result is stored in variable '::X::input_file' or '::X::output_file'
	 # @parm Bool io	- 1 == Input; 0 == Output
	 # @parm String mask	- File suffix
	 # @parm Widget master	- GUI parent
	 # @return void
	proc select_input_output {io mask master} {
		variable IO		;# Bool: 1 == choose input file; 0 == choose output file
		variable actualProject	;# Object: Current project
		variable openedProjects	;# List of opened projects (Object references)

		set IO $io

		if {[llength $openedProjects]} {
			set project_dir [${::X::actualProject} cget -ProjectDir]
		} else {
			set project_dir ${::env(HOME)}
		}

		# Invoke the dialog
	 	catch {delete object fsd}
		KIFSD::FSD fsd	 					\
			-title [mc "Open file - MCU 8051 IDE"]		\
			-directory $project_dir				\
			-defaultmask 0 -multiple 0 -filetypes [list	\
				[list [mc "Input file"]	"*.$mask"]	\
				[list [mc "All files"]	{*}]		\
			]

		# Ok button
		fsd setokcmd {
			set filename [X::fsd get]
			if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
				if {![regexp "^(~|/)" $filename]} {
				set filename "$project_dir/$filename"
				}
			} else {	;# Microsoft windows way
				if {![regexp {^\w:} $filename]} {
					set filename [file join $project_dir $filename]
				}
			}
			set filename [file normalize $filename]
			if {${X::IO}} {
				set X::input_file $filename
			} else {
				set X::output_file $filename
			}
		}

		fsd activate	;# Activate the dialog
	}

	## Invoke dialog "Disassemble"
	 # @return void
	proc __disasm {} {
		variable actualProject			;# Object: Current project
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 1]} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Invoke the file selection dialog
		catch {delete object fsd}
		KIFSD::FSD fsd	 					\
			-title [mc "Open file - MCU 8051 IDE"]		\
			-directory [$actualProject cget -projectPath]	\
			-defaultmask 0 -multiple 0 -filetypes [list	\
				[list [mc "IHEX 8"]	{*.{hex,ihx}}]	\
				[list [mc "All files"]	{*}]		\
			]

		# Open file after press of OK button
		fsd setokcmd {
			X::fsd deactivate

			set filename [X::fsd get]
			if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
				if {![regexp "^(~|/)" $filename]} {
				set filename "[${::X::actualProject} cget -ProjectDir]/$filename"
				}
			} else {	;# Microsoft windows way
				if {![regexp {^\w:} $filename]} {
					set filename [file join [${::X::actualProject} cget -ProjectDir] $filename]
				}
			}
			set filename [file normalize $filename]

			if {
				![file exists $filename]	||
				![file isfile $filename]	||
				(!$::MICROSOFT_WINDOWS && ![file readable $filename])
			} then {
				tk_messageBox						\
					-type ok					\
					-icon warning					\
					-parent .					\
					-title [mc "File not found - MCU 8051 IDE"]	\
					-message [mc "The selected file %s does not exist." $filename]
			} else {
				set data [X::decompile $filename]

				if {$data != {}} {
					${::X::actualProject} background_open $data
					if {[lindex ${X::simulator_enabled} ${X::actualProjectIdx}] == 0} {
						${::X::actualProject} switch_to_last
					}
				} else {
					tk_messageBox					\
						-type ok				\
						-parent .				\
						-icon warning				\
						-title [mc "Disassembly failed"]	\
						-message [mc "Disassembly failed -- see messages for details"]
				}
			}
		}
		# activate the dialog
		fsd activate

		set critical_procedure_in_progress 0
	}

	## Disaaemble the given file -- auxiliary procedure for '__disasm'
	 # @parm String filename - name of IHEX8 file to disassemble
	 # @return String - resulting source code
	proc decompile {filename} {
		variable compilation_in_progress	;# Bool: Compiler engaged
		variable compilation_mess_project	;# Object: Project related to running compilation
		variable actualProject			;# Object: Current project

		set compilation_in_progress 1
		set compilation_mess_project $actualProject
		messages_text_append [mc "\nLoading IHEX file ..."]

		# Open the specified file
		if {[catch {
			set file [open $filename r]
		}]} then {
			tk_messageBox			\
				-parent .		\
				-icon warning		\
				-type ok		\
				-title [mc "Unable to open file"]	\
				-message [mc "Unable to read file '%s'" $filename]
			return {}
		}

		# Adjust GUI
		make_progressBar_on_Sbar	;# Create compilation progress bar on status bar
		compilation_progress		;# Initialize compilation progress bar
		$actualProject bottomNB_show_up {Messages}	;# Raise tab "Messages" on bottom panel

		# Setup compiler
		set Compiler::Settings::ABORT_VARIABLE 0
		set Compiler::Settings::TEXT_OUPUT_COMMAND X::messages_text_append
		set Compiler::Settings::UPDATE_COMMAND {update}

		# Perform disassembly
		set data {}
		set ::IHexTools::update 1
		::IHexTools::load_hex_data [read $file]
		if {!${::IHexTools::error_count} && !${::IHexTools::abort}} {
			messages_text_append [mc "Successful"]
			set data [::disassembler::compile [::IHexTools::get_hex_data]]
			set ::disassembler::asm {}
		}
		close $file

		# Finalize
		set Compiler::Settings::ABORT_VARIABLE 0
		destroy_progressBar_on_Sbar
		set compilation_in_progress 0

		# Write error messages
		if {${::IHexTools::error_count}} {
			messages_text_append ${::IHexTools::error_string}
			messages_text_append [mc "FAILED"]
		}

		# Free resources reserved during disassembly
		::IHexTools::free_resources

		return $data
	}

	## Show/Hide Line numbers (in Editor)
	 # @return void
	proc __show_hine_LineN {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		# Show/Hide line numbers
		$actualProject show_hide_lineNumbers
	}

	## Show/Hide Icon border (in Editor)
	 # @return void
	proc __show_hine_IconB {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		# Show/Hide Icon border
		$actualProject show_hide_IconBorder
	}

	## Redraw pane windows -- binding for event <Configure>
	 # @return void
	proc redraw_panes {} {
		variable last_WIN_GEOMETRY	;# Last window geometry (main window)
		variable openedProjects		;# List of opened projects (Object references)

		# Window geometry unchanged -> return
		if {$last_WIN_GEOMETRY == [wm geometry .]} {
			return
		# Refresh last window geometry variable
		} else {
			set last_WIN_GEOMETRY [wm geometry .]
		}

		# Gain window height and width
		evaluate_new_window_geometry

		# Bottom NoteBook
		if {${::last_WIN_GEOMETRY_width} != ${::WIN_GEOMETRY_width}} {
			set ::last_WIN_GEOMETRY_width ${::WIN_GEOMETRY_width}
			foreach project $openedProjects {
				catch {
					$project leftpanel_redraw_pane
					$project right_panel_redraw_pane
					$project todo_panel_redraw_pane
				}
			}
		}
		# Right panel & File notes
		if {${::last_WIN_GEOMETRY_height} != ${::WIN_GEOMETRY_height}} {
			set ::last_WIN_GEOMETRY_height ${::WIN_GEOMETRY_height}
			foreach project $openedProjects {
				catch {
					$project bottomNB_redraw_pane
				}
			}
		}
	}

	## Invoke dialog "About"
	 # @return void
	proc __about {} {
		# Create dialog window
		set win [toplevel .about -class [mc "About dialog"] -bg ${::COMMON_BG_COLOR}]

		# Create dialog header
		pack [label $win.header			\
			-compound left			\
			-image [image create photo	\
				-format png	\
				-file "${::ROOT_DIRNAME}/icons/other/Moravia_Microsystems.png"	\
			]	\
			-text "  ${::APPNAME}"		\
			-font [font create	\
				-size -20	\
				-family {helvetica}]
		] -side top -pady 5

		# Display short information about current translation
		set translation_info "Translated into _Language_ by _Name_ (_country_) <_email_>"
		if {[mc $translation_info] != $translation_info} {
			pack [label $win.trans_info		\
				-text [mc $translation_info]	\
				-font [font create		\
					-size -12		\
					-family {helvetica}]
			] -side top -pady 2
		}


		# Create notebook
		set nb [ModernNoteBook $win.nb]

		# Create tab "About"
		set about_tab [$nb insert end {About} -text [mc "About"]]
		pack [text $about_tab.text					\
			-width 0 -height 0 -cursor left_ptr			\
			-yscrollcommand "$about_tab.scrollbar set"		\
			-font [font create					\
				-size [expr {int(-12 * $::font_size_factor)}]	\
				-family {helvetica}]				\
		] -fill both -expand 1 -side left
		pack [ttk::scrollbar $about_tab.scrollbar	\
			-orient vertical			\
			-command "$about_tab.text yview"	\
		] -fill y -side right
		# fill in the about tab
		$about_tab.text insert end "${::APPNAME}\n"
		$about_tab.text insert end [mc "An open source IDE for MCS-51 based microconrollers for POSIX Systems, this software is licenced under the GNU GPL v2 licence. You can find more at the project web page http://www.moravia-microsystems.com/mcu-8051-ide/\n"]
		$about_tab.text insert end "\n(c) 2007, 2008, 2009, 2010, 2011, 2012 Martin Ošmera <mailto:martin.osmera@gmail.com>\n"
		$about_tab.text insert end "\n(c) 2014 Moravia Micorsystems, s.r.o. <mailto:martin.osmera@moravia-microsystems.com>\n"
		if {$::MICROSOFT_WINDOWS} {
			$about_tab.text insert end "\n"
			$about_tab.text insert end [mc "You are currently using version for Microsoft® Windows®.\n"]
			$about_tab.text insert end "(This version was made using the FreeWrap tool, by Dennis R. LaBelle <freewrapmgr@users.sourceforge.net>.)\n"
		}
		create_link_tag_in_text_widget $about_tab.text
		convert_all_https_to_links $about_tab.text

		# Finalize text widget creation
		$about_tab.text configure -state disabled

		# Create tab "Thanks to"
		set thanks_tab [$nb insert end {Thanks} -text [mc "Thanks to"]]
		pack [text $thanks_tab.text				\
			-width 0 -height 0 -cursor left_ptr	\
			-yscrollcommand "$thanks_tab.scrollbar set"	\
		] -fill both -expand 1 -side left
		pack [ttk::scrollbar $thanks_tab.scrollbar	\
			-orient vertical			\
			-command "$thanks_tab.text yview"	\
		] -fill y -side right

		$thanks_tab.text insert end [mc "Special thanks to Kara Blackowiak (USA) for submitting various help file fixes.\n\n"]
		$thanks_tab.text insert end [mc "Thanks to Yuanhui Zhang for bug reports and help with debugging.\n"]
		$thanks_tab.text insert end [mc "Thanks to Fabricio Alcalde for bug reports and suggestions.\n"]
		$thanks_tab.text insert end [mc "Thanks to Marek Nožka for help with debugging.\n"]
		$thanks_tab.text insert end [mc "Thanks to Miroslav Hradílek for bug reports.\n"]
		$thanks_tab.text insert end [mc "Thanks to Trevor Spiteri for help with debugging (patches) the HD44780 simulator.\n"]
		$thanks_tab.text insert end [mc "Thanks to Kostya V. Ivanov for significant bug fixes.\n"]
		$thanks_tab.text insert end [mc "Thanks to Shakthi Kannan for including this IDE in FEL.\n\n"]
		$thanks_tab.text insert end [mc "Thanks to all the SDCC developers.\n"]
		$thanks_tab.text configure -state disabled

		# Create tab "License"
		set license_tab [$nb insert end {License} -text [mc "License"]]
		pack [text $license_tab.text				\
			-width 0 -height 0				\
			-yscrollcommand "$license_tab.scrollbar set"	\
			-font [font create				\
				-family $::DEFAULT_FIXED_FONT		\
				-size -12				\
			]						\
		] -fill both -expand 1 -side left
		pack [ttk::scrollbar $license_tab.scrollbar	\
			-orient vertical			\
			-command "$license_tab.text yview"	\
		] -fill y -side right
		# Fill in the license tab
		if {[file exists "${::ROOT_DIRNAME}/data/license.txt"]} {
			$license_tab.text insert end [read [open "${::ROOT_DIRNAME}/data/license.txt" {r}]]
		} else {
			$license_tab.text insert end [mc "FILE \"license.txt\" WAS NOT FOUND\n\n"]
			$license_tab.text insert end [mc "Text of the license agreement is not available,\n"]
			$license_tab.text insert end [mc "please check your installation."]
		}
		$license_tab.text configure -state disabled

		# Pack NoteBook
		pack [$nb get_nb] -fill both -expand 1 -side top -padx 10
		$nb raise {About}
		# Create button "Close"
		pack [ttk::button $win.close			\
			-text [mc "Close"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command {X::about_CLOSE}		\
		] -side bottom -pady 5

		# Events binding (Enter, Escape == Close)
		bind $win <KeyRelease-Return>	{X::about_CLOSE; break}
		bind $win <KeyRelease-KP_Enter>	{X::about_CLOSE; break}
		bind $win <KeyRelease-Escape>	{X::about_CLOSE; break}

		# Focus on button "Close"
		focus $win.close

		# Window manager options -- modal window
		wm iconphoto $win ::ICONS::16::mcu8051ide
		wm title $win [mc "About - MCU 8051 IDE"]
		wm minsize $win 620 320
		wm protocol $win WM_DELETE_WINDOW {
			X::about_CLOSE
		}
		wm transient $win .
		catch {grab $win}
		raise $win
		tkwait window $win
	}

	## Close dialog "About" -- auxiliary procedure for '__about'
	 # @return void
	proc about_CLOSE {} {
		grab release .about
		destroy .about
	}

	## Auto indent source code in the current editor
	 # @return void
	proc __reformat_code {} {
		variable actualProject			;# Object: Current project
		variable editor_lines			;# Number of lines in the current editor
		variable compilation_progress		;# Variable for compilation progressbar
		variable reformat_code_abort		;# Bool: Abort function 'reformat_code'
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 1]} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# C language
		if {[$actualProject editor_procedure {} get_language {}] == 1} {
			if {$::MICROSOFT_WINDOWS} { ;# Not implemented yet on Microsoft Windows
				tk_messageBox		\
					-parent .	\
					-icon warning	\
					-type ok	\
					-title [mc "Sorry, unable to comply"]	\
					-message [mc "Unable to indent C source without program indent, MCU 8051 IDE is unable to localize this program on Microsoft Windows operating system. So this feature is not available in version for MS Windows. Correction of this limitation is planed but right now it's not available."]
				set critical_procedure_in_progress 0
				return
			}

			# Check for program "indent"
			if {!${::PROGRAM_AVAILABLE(indent)}} {
				tk_messageBox		\
					-parent .	\
					-icon warning	\
					-type ok	\
					-title [mc "Unable to comply"]	\
					-message [mc "Unable to indent C source without program indent, please install indent and restart MCU 8051 IDE."]
				set critical_procedure_in_progress 0
				return
			}

			# Save file
			if {![$actualProject editor_procedure {} save {}]} {
				set critical_procedure_in_progress 0
				return
			}

			# Perform indention and refresh editor
			set filename [$actualProject editor_procedure {} getFileName {}]
			set filename [file join [lindex $filename 0] [lindex $filename 1]]
			if {[catch {exec -- indent -kr -npro $filename} result]} {
				puts stderr $result
				tk_messageBox		\
					-parent .	\
					-icon warning	\
					-type ok	\
					-title [mc "Unable to comply"]	\
					-message [mc "Unable to indent C source code.\n\n%s" $result]
			} else {
				$actualProject filelist_reload_file
			}

		# Assembly language
		} else {
			# Prepare
			set reformat_code_abort 0					;# Reset auto indention abort flag
			set editor_lines [$actualProject editor_linescount]		;# Number of lines in the editor
			set compilation_progress 0					;# Reset compilation progress variable
			set editor [$actualProject editor_procedure {} cget -editor]	;# Editor widget
			set lastLine [$actualProject editor_actLineNumber]		;# Current line
			set new_content {}						;# Initialize new content string

			set max [expr {$editor_lines / 10}]
			if {!$max} {
				set max 1
			}

			# Create progress dialog
			create_progress_bar .prgDl		\
				.				\
				{}				\
				[::mc "Reformatting code"]	\
				::X::compilation_progress	\
				$max				\
				[mc "Reformatting code"]	\
				::ICONS::16::filter		\
				[mc "Abort"]			\
				{::X::reformat_code_stop}

			$editor configure -autoseparators 0

			# Perform auto indention
			set new_content [reformat_code_core [$editor get 1.0 end]]
			$editor delete 1.0 end

			# Insert new content in the editor
			$editor insert end [string replace $new_content {end-1} end]
			$actualProject editor_procedure {} parseAll {}
			$actualProject editor_procedure {} goto $lastLine

			$editor edit separator
			$editor configure -autoseparators 1

			# Finalize
			catch {
				destroy .prgDl	;# Destroy progress dialog
			}
		}
		set critical_procedure_in_progress 0
	}

	## Abort auto indention -- auxiliary procedure for '__reformat_code'
	 # @return void
	proc reformat_code_stop {} {
		variable reformat_code_abort	;# Bool: Abort function 'reformat_code'
		set reformat_code_abort 1
	}

	## Perform auto indention -- auxiliary procedure for '__reformat_code'
	 # @parm String data - data to parse
	 # @return String - result
	proc reformat_code_core {data} {
		variable compilation_progress	;# Variable for compilation progressbar
		variable reformat_code_abort	;# Bool: Abort function 'reformat_code'

		set idx		1	;# Line number
		set new_content	{}	;# Resulting string

		# Parse input data (line by line)
		set data [split $data "\n"]
		foreach line $data {
			if {$reformat_code_abort} {break}	;# Conditional abort
			incr idx				;# Increment line number

			# Replace lines containg only white space with empty lines
			if {[regexp {^\s*$} $line]} {
				append new_content "\n"
				if {![expr {$idx % 10}]} {
					incr compilation_progress
				}
				continue
			}

			# Line fields
			set field_0 {}	;# 1st field (labels, constants, etc.)
			set field_1 {}	;# 2nd field (instructins, directives, macros, etc.)
			set field_2 {}	;# 3rd field (operands, arguments, etc.)
			set field_3 {}	;# 4th field (comments only)

			# Determinate line with replaced strings and chars with underscores
			set line_tmp $line
			while {1} {
				if {![regexp {'[^']+'} $line_tmp str]} {break}
				set len [string length $str]
				regsub {'[^']+'} $line_tmp [string repeat {_} $len] line_tmp
			}

			# Determinate comment field (field_3)
			set commentBegin [string first {;} $line_tmp]
			if {$commentBegin != -1} {
				set field_3 [string range $line $commentBegin end]
				regsub {\s*;.*$} $line_tmp {} line_tmp
				set line [string range $line 0 [expr {$commentBegin - 1}]]
			}

			# Determinate fields 0 and 1
			set pos 0
			for {set j 0} {$j < 2} {incr j} {
				if {![regexp {^\s*[^\s]+} $line_tmp str]} {break}
				set len [string length $str]
				set i [expr {$len - 1}]
				set space [string repeat { } $len]
				regsub {^\s*[^\s]+} $line_tmp $space line_tmp
				set field_$j [regsub {^\s+} [string range $line $pos $i] {}]
				set line [string replace $line $pos $i $space]
				incr pos $len
			}

			# Remove leading white space from Field 2
			set field_2 [regsub {^\s+} $line {}]

			# Handle situation when there is no space between label and the 1st field
			if {[regexp {[^\s:]+:[^\s:]+} $field_0]} {
				set j [string first {:} $field_0]
				append field_1 $field_2
				set field_2 $field_1
				set field_1 [string range $field_0 [expr {$j + 1}] end]
				set field_0 [string range $field_0 0 $j]
			}

			# Field 1 >> Field 2; Field 0 -> Field 1; "" -> Field 0;
			if {[string index $field_1 0] == {.}} {
				set field_1_without_leading_dot [string range $field_1 1 end]
			} else {
				set field_1_without_leading_dot $field_1
			}
			if {
				[regexp {^\.?\w+$} $field_0]	&&
				![regexp {^\d} $field_0]	&&
				[lsearch -exact -ascii ${::ASMsyntaxHighlight::directive_type2}	\
					[string toupper $field_1_without_leading_dot]] == -1
			} then {
				append field_1 $field_2
				set field_2 $field_1
				set field_1 {}
				if {[string toupper $field_0] != {ENDM} && [string toupper $field_0] != {.ENDM}} {
					set field_1 $field_0
					set field_0 {}
				}
			}

			# If line contains only comment then Field 3 -> Field 1
			if {
				$field_3 != {} &&
				$field_0 == {} &&
				$field_1 == {} &&
				$field_2 == {} &&
				$commentBegin != 0
			} then {
				set field_1 $field_3
				set field_3 {}
			}

			# Adjust space between operans/arguments
			set field_2_new {}
			if {$field_2 != {}} {
				# Strings/Chars to underscores
				set field_2_tmp $field_2
				while {1} {
					if {![regexp {'[^']+'} $field_2_tmp str]} {break}
					set len [string length $str]
					regsub {'[^']+'} $field_2_tmp [string repeat {_} $len] field_2_tmp
				}
				# Recomposite Field 2
				while {1} {
					set i [string first {,} $field_2_tmp]
					if {$i == -1} {
						append field_2_new {, }
						append field_2_new [string trim $field_2]
						break
					}
					append field_2_new {, }
					append field_2_new [string trim [string range $field_2 0 [expr {$i - 1}]]]
					set field_2 [string range $field_2 [expr {$i + 1}] end]
					set field_2_tmp [string range $field_2_tmp [expr {$i + 1}] end]
				}
				set field_2 [string trimleft $field_2_new {, }]
			}

			# Recomposite line
			set line $field_0
			if {$field_1 != {}} {
				append line "\t"
				append line $field_1
			}
			if {$field_2 != {}} {
				append line "\t"
				append line $field_2
			}
			if {$field_3 != {}} {
				# Adjust field 3 (insure appropriate number of leading tabs)
				if {$line != {}} {
					set i -1
					set spaces 0
					set correction 0
					set falseLength [string length $line]

					while {1} {
						set i [string first "\t" $line [expr {$i + 1}]]
						if {$i == -1} {break}

						set spaces [expr {8 - (($i + $correction) % 8)}]
						set spaces_1 [expr {$spaces - 1}]
						incr correction $spaces_1
						incr falseLength $spaces_1
					}

					set spaces [expr {4 - ($falseLength / 8)}]
					if {$spaces < 1} {
						set spaces 1
					}

					append line [string repeat "\t" $spaces]
				}
				append line $field_3
			}

			# Append new line to the result
			append new_content $line
			append new_content "\n"
			if {![expr {$idx % 10}]} {
				incr compilation_progress
			}
		}

		# Return result
		return $new_content
	}

	## Invoke dialog "Clean up project folder"
	 # @return void
	proc __cleanup {} {
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {$critical_procedure_in_progress} {return}

		# Create dialog window
		set win [toplevel .cleanup -class [mc "Options dialog"] -bg ${::COMMON_BG_COLOR}]
		set bottom_frame [frame $win.buttonFrame]
		set status_bar_lbl [label $bottom_frame.status_bar	\
			-justify left -anchor w				\
		]

		# Create label frames
		set backup_labelframe [ttk::labelframe $win.backup_labelframe	\
			-text [mc "Backup files"]				\
		]
		set other_labelframe [ttk::labelframe $win.other_labelframe	\
			-text [mc "Other files"]				\
		]

		set i 0		;# Checkbutton index

		# Fill in top labelframe
		set row 0	;# Row in the grid
		set col 0	;# Column in the grid
		foreach	text {
				*.asm~	*.lst~	*.sim~	*.hex~	*.bin~		*.html~
				*.tex~	*.wtc~	*.mcu8051ide~	*.m5ihib~	*.cdb~
				*.ihx~	*.adf~	*.omf~	*.map~	*.c~		*.h~
				*.vhc~	*.vhw~	*.txt~	*~
			} ID {
				asm	lst	sim	hex	bin	html
				tex	wtc	mcu8051ide	m5ihib	cdb
				ihx	adf	omf	map	c	h
				vhc	vhw	txt	all_bc
			} helptext {
				{Assembly language sources}
				{Code listing files}
				{Assembly debug files (before v1.0.5)}
				{IHEX object code files}
				{Binary object code files}
				{HTML files}
				{TeX sources}
				{Register watches definition files}
				{MCU 8051 IDE project}
				{Hibernated programs}
				{SDCC debug files}
				{SDCC IHEX8 object files}
				{MCU 8051 IDE Assembler debug files}
				{OMF-51 object files}
				{SDCC: The memory map for the load module}
				{C sources}
				{C headers}
				{Virtual Hardware Component}
				{Virtual Hardware}
				{Text files}
				{All backup files}
			}	\
		{
			set helptext [mc $helptext]
			set button [checkbutton $backup_labelframe.$ID	\
				-text $text -anchor w			\
				-command "::X::cleanup_option $i"	\
				-variable __cleanup_$ID			\
			]
			grid $button -row $row -column $col -sticky w -padx 5
			if {[lindex $::CONFIG(CLEANUP_OPTIONS) $i] != {0}} {
				$button select
			} else {
				$button deselect
			}
			bind $button <Enter> "$status_bar_lbl configure -text {$helptext}"
			bind $button <Leave> "$status_bar_lbl configure -text {}"

			incr i
			incr col
			if {$col == 4} {
				set col 0
				incr row
			}
		}

		# Fill in bottom labelframe
		set row 0	;# Row in the grid
		set col 0	;# Column in the grid
		foreach	text {
				*.lst	*.sim	*.hex	*.bin	*.html	*.tex	*.m5ihib
				*.noi	*.obj	*.map	*.p	*.mac	*.i	*.ihx
				*.adf	*.adb	*.rel	*.cdb	*.mem	*.lnk	*.sym
				*.omf	*.rst	*.hashes *.bak
			} ID {
				lst	sim	hex	bin	html	tex	m5ihib
				noi	obj	map	p	mac	i	ihx
				adf	adb	rel	cdb	mem	lnk	sym
				omf	rst	hashes	bak
			} helptext {
				{Code listing files}
				{Assembly debug files (before v1.0.5)}
				{IHEX object code files}
				{Binary object code files}
				{HTML files}
				{TeX sources}
				{Hibernated programs}
				{ASL: NoICE-compatible command ﬁle}
				{ASL: Atmel debug file used by the AVR tools}
				{SDCC: The memory map for the load module}
				{ASL object files}
				{Macro definition file}
				{Macro output files}
				{SDCC IHEX8 object files}
				{MCU 8051 IDE Assembler debug files}
				{SDCC Assembler debug files}
				{SDCC: Object file created by the assembler}
				{SDCC debug files}
				{SDCC: A file with a summary of the memory usage}
				{SDCC: Linker script}
				{SDCC: Symbol listing for the source file}
				{OMF-51 object files}
				{SDCC: Listing file updated with linkedit information}
				{MD5 hashes for C source files}
				{Doxygen backup file}
			}	\
		{
			set helptext [mc $helptext]
			set button [checkbutton $other_labelframe.$ID	\
				-text $text -anchor w			\
				-command "::X::cleanup_option $i"	\
				-variable __cleanup__$ID		\
			]
			grid $button -row $row -column $col -sticky w -padx 5
			if {[lindex $::CONFIG(CLEANUP_OPTIONS) $i] != {0}} {
				$button select
			} else {
				$button deselect
			}
			bind $button <Enter> "$status_bar_lbl configure -text {$helptext}"
			bind $button <Leave> "$status_bar_lbl configure -text {}"

			incr i
			incr col
			if {$col == 4} {
				set col 0
				incr row
			}
		}

		# Set column sizes
		grid columnconfigure $backup_labelframe 0 -minsize 130
		grid columnconfigure $backup_labelframe 1 -minsize 130
		grid columnconfigure $backup_labelframe 2 -minsize 130
		grid columnconfigure $backup_labelframe 3 -minsize 130
		grid columnconfigure $other_labelframe 0 -minsize 130
		grid columnconfigure $other_labelframe 1 -minsize 130
		grid columnconfigure $other_labelframe 2 -minsize 130
		grid columnconfigure $other_labelframe 3 -minsize 130

		# Pack label frames
		pack $backup_labelframe -fill both -expand 1 -padx 10 -pady 5
		pack $other_labelframe -fill both -expand 1 -padx 10 -pady 5

		# Create 'OK' and 'CANCEL' buttons
		pack $status_bar_lbl -side left -fill x -expand 1
		pack [ttk::button $win.buttonFrame.ok		\
			-text [mc "Remove files"]		\
			-compound left				\
			-image ::ICONS::16::ok			\
			-command {X::cleanup_OK}		\
		] -side left -padx 2
		pack [ttk::button $win.buttonFrame.cancel	\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command {X::cleanup_CANCEL}		\
		] -side left -padx 2
		pack $bottom_frame -pady 5 -fill x -padx 5

		# Events binding (Enter == Ok; Esc == Cancel)
		bind $win <KeyRelease-Return>	{X::cleanup_OK; break}
		bind $win <KeyRelease-KP_Enter>	{X::cleanup_OK; break}
		bind $win <KeyRelease-Escape>	{X::cleanup_CANCEL; break}

		# Set window attributes -- modal window
		wm iconphoto .cleanup ::ICONS::16::emptytrash
		wm title .cleanup [mc "Cleanup project folder - MCU 8051 IDE"]
		wm minsize .cleanup 360 310
		wm resizable .cleanup 0 0
		wm protocol .cleanup WM_DELETE_WINDOW {
			X::cleanup_CANCEL
		}
		wm transient .cleanup .
		grab .cleanup
		raise .cleanup
		tkwait window .cleanup
	}

	## Change cleanup option -- auxiliary procedure for '__cleanup'
	 # @parm Int idx - checkbutton index
	 # @return void
	proc cleanup_option {idx} {
		lset ::CONFIG(CLEANUP_OPTIONS) $idx	\
			[expr {[lindex $::CONFIG(CLEANUP_OPTIONS) $idx] == {0}}]
	}

	## Start cleanup -- auxiliary procedure for '__cleanup'
	 # @return void
	proc cleanup_OK {} {
		variable cleanup_masks	;# GLOB patterns
		variable cleanup_files	;# List: Files marked for potential removal
		variable actualProject	;# Object: Current project

		# Determinate list of GLOB expressions of selected for removal
		set dir [$actualProject cget -projectPath]
		set cleanup_files [list]
		foreach mask $cleanup_masks bool $::CONFIG(CLEANUP_OPTIONS) {
			if {$bool} {
				lappend cleanup_files $mask
			}
		}

		# Determinate list of files selected for removal
		set files_n [list]
		catch {	;# For Microsoft Windows it has to be enclosed by catch
			foreach f $cleanup_files {
				append files_n { } [glob -directory $dir -nocomplain -type f $f]
			}
		}
		set cleanup_files [lsort -unique $files_n]

		# Finalize
		cleanup_ask
	}

	## Proceed with the project folder clean up
	 # @return void
	proc cleanup_PROCEED {} {
		variable cleanup_files	;# List: Files marked for potential removal

		# Invoke confirmation dialog
		if {
			[tk_messageBox					\
				-parent .cleanup_ask			\
				-icon question				\
				-type yesno				\
				-title [mc "Cleanup project folder"]	\
				-message [mc "Are you sure ?"]		\
			] != {yes}
		} then {
			return
		}

		# Remove the specified files
		set count 0
		foreach file $cleanup_files {
			if {[catch {
				file delete -force -- $file
			}]} then {
				puts stderr "Unable to delete file: $file"
			} else {
				incr count
			}
		}

		tk_messageBox			\
			-parent .cleanup_ask	\
			-icon info		\
			-type ok		\
			-title [mc "Cleanup project folder"] \
			-message [mc "%d file(s) removed." $count]

		cleanup_CANCEL		;# Close dialog window
	}

	## Close dialog "Clean up project folder" -- auxiliary procedure for 'cleanup_OK'
	 # @return void
	proc cleanup_CANCEL {} {
		variable cleanup_files	;# List: Files marked for potential removal
		set cleanup_files [list]

		destroy .cleanup
	}

	## Show results of files removal -- auxiliary procedure for 'cleanup_OK'
	 # @return void
	proc cleanup_ask {} {
		variable cleanup_files	;# List: Files marked for potential removal

		# Create dialog window
		set win [toplevel .cleanup_ask -class {Confirmation dialog} -bg ${::COMMON_BG_COLOR}]

		# Create window header
		pack [label $win.header_label					\
			-text [mc "These files will be removed"]		\
			-font [font create					\
				-size [expr {int(-20 * $::font_size_factor)}]	\
				-family {helvetica}]
		] -anchor center -side top -fill x

		# Create top frame (text widget and scrollbar)
		set frame [frame $win.top_frame]

		# Create text widget and its scrollbar
		set scrollbar [ttk::scrollbar $frame.scrollbar	\
			-command "$frame.text yview"		\
			-orient vertical			\
		]
		set text [text $frame.text			\
			-yscrollcommand "$frame.scrollbar set"	\
			-width 1 -height 1			\
			-cursor left_ptr			\
		]

		# Fill in the text widget
		foreach txt $cleanup_files {
			# On MS Windows change '/' to '\' in file path
			if {$::MICROSOFT_WINDOWS} {
				regsub -all {/} $txt "\\" txt
			}

			$text insert end $txt
			$text insert end "\n"
		}
		$text configure -state disabled

		# Pack scrollbar and the text widget
		pack $scrollbar -side right -fill y
		pack $text -side left -fill both -expand 1
		pack $frame -side top -fill both -expand 1 -pady 5 -padx 5

		# Pack the top frame and create button "Ok"
		set but_frame [frame $win.but_frame]
		pack [ttk::button $but_frame.ok_button	\
			-text [mc "Proceed"]		\
			-compound left			\
			-image ::ICONS::16::ok		\
			-command "
				::X::cleanup_PROCEED
				destroy $win
			"	\
		] -side left -padx 5
		pack [ttk::button $but_frame.cancel_button	\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command [list destroy $win]		\
		] -side left -padx 5
		focus -force $but_frame.ok_button
		pack $but_frame -side bottom -anchor e -pady 5 -pady 5

		# Set window attributes -- modal window
		wm iconphoto $win ::ICONS::16::emptytrash
		wm title $win [mc "Cleanup project folder - MCU 8051 IDE"]
		wm minsize $win 520 300
		wm protocol $win WM_DELETE_WINDOW "grab release $win; destroy $win"
		wm transient $win .
		catch {grab $win}
		raise $win
		tkwait window $win
	}

	## Execute custom command
	 # @parm Int cmd_num - command number
	 # @return void
	proc __exec_custom_cmd {cmd_num} {
		variable custom_command_cmd		;# Array of custom commands (shell scripts)
		variable custom_command_options		;# Array of Lists of custom command options
		variable custom_command_PID		;# Array of custom command TIDs (Thread IDentifiers)
		variable custom_command_NUM		;# Array of custom command numbers
		variable custom_command_counter		;# Counter of custom command invocations
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Check if the command is not already running
		if {$custom_command_PID($cmd_num) != {}} {
			if {[tk_messageBox	\
				-parent .	\
				-icon warning	\
				-type yesno	\
				-title [mc "Confirm termination - MCU 8051 IDE"]	\
				-message [mc "This process is already in progress. Do you want to terminate it ?"]
			] == {yes}} {
				if {!$::MICROSOFT_WINDOWS} { ;# There is no kill command on Microsoft Windows
					if {$custom_command_PID($cmd_num) != {}} {
						foreach pid $custom_command_PID($cmd_num) {
							if {$pid == [pid] || $pid == 0} {
								continue
							}
							catch {
								exec -- /bin/sh -c "kill -s 9 \$(ps -o pid --no-headers --ppid $pid)"
							}
						}
					}
				}
				custom_cmd_icon_reset $custom_command_NUM($cmd_num)
			}
			set critical_procedure_in_progress 0
			return
		}

		# Invoke confiramation dialog (if requested)
		if {[lindex $custom_command_options($cmd_num) 0]} {
			if {
				[tk_messageBox					\
					-parent .				\
					-icon question				\
					-type yesno				\
					-title [mc "Confirmation required"]	\
					-message [mc "Do you really want to execute\ncustom command %s ?" $cmd_num] \
				] != {yes}
			} then {
				set critical_procedure_in_progress 0
				return
			}
		}

		# Adjust button icon on main toolbar
		if {[winfo exists .mainIconBar.custom$cmd_num]} {
			.mainIconBar.custom$cmd_num configure	\
				-image ::ICONS::22::gear${cmd_num}_play
		}

		# Perform variables substitution in the command string
		set cmd $custom_command_cmd($cmd_num)
		regsub -all {%%} $cmd "\a" cmd
		if {[regexp {%} $cmd]} {
			# Determinate editor object reference
			set editor [$actualProject get_current_editor_object]

			regsub -all {%URL} $cmd {%URI} cmd

			if {[regexp {%URIS} $cmd]} {
				set URIS {}
				foreach e [$actualProject cget -editors] {
					set url [$e cget -fullFileName]
					if {[regexp {\s} $url]} {
						append URIS "\"" $url "\"" { }
					} else {
						append URIS $url { }
					}
				}
				regsub -all {%URIS} $cmd [string replace $URIS end end] cmd
			}
			if {[regexp {%URI} $cmd]} {
				regsub -all {%URI} $cmd [$editor cget -fullFileName] cmd
			}
			if {[regexp {%directory} $cmd]} {
				regsub -all {%directory} $cmd [$actualProject cget -projectPath] cmd
			}
			if {[regexp {%filename} $cmd]} {
				regsub -all {%filename} $cmd [$editor cget -filename] cmd
			}
			if {[regexp {%basename} $cmd]} {
				regsub -all {%basename} $cmd [file tail [file rootname [$editor cget -filename]]] cmd
			}
			if {[regexp {%mainfile} $cmd]} {
				regsub -all {%mainfile} $cmd [$actualProject cget -P_option_main_file] cmd
			}
			if {!${::Editor::editor_to_use}} {
				if {[regexp {%line} $cmd]} {
					regsub -all {%line} $cmd [$editor get_current_line_number] cmd
				}
				if {[regexp {%column} $cmd]} {
					regexp {\d+$} [[$editor cget -editor] index insert] col
					regsub -all {%column} $cmd $col cmd
				}
				if {[regexp {%selection} $cmd]} {
					regsub -all {%selection} $cmd [$editor getselection] cmd
				}
				if {[regexp {%text} $cmd]} {
					regsub -all {%text} $cmd [$editor getdata] cmd
				}
			} else {
				if {[regsub -all {%(line|column|selection|text)} $cmd {} cmd]} {
					tk_messageBox		\
						-parent .	\
						-type ok	\
						-icon warning	\
						-title [mc "Warning - Custom command"]	\
						-message [mc "Some variables in user command could not be resolved."]
				}
			}
		}
		regsub -all "\a" $cmd {%} cmd

		## Execute the specified command
		set custom_command_NUM($cmd_num) $custom_command_counter
		 # Run in terminal
		if {[lindex $custom_command_options($cmd_num) 3] && $::PROGRAM_AVAILABLE(urxvt)} {
			exec_custom_cmd_in_terminal $cmd_num $cmd
			custom_cmd_icon_reset $custom_command_NUM($cmd_num)
		 # Run normally
		} else {
			set custom_command_PID($cmd_num) [exec -- tclsh 		\
				${::LIB_DIRNAME}/custom_command.tcl [tk appname]	\
				$custom_command_NUM($cmd_num) << $cmd &			\
			]
		}
		incr custom_command_counter

		# Finalize
		set critical_procedure_in_progress 0
	}

	## Invoke dialog "Custom command finished"
	 # -- auxiliary procedure for '__exec_custom_cmd'
	 # @parm Int num	- Command number
	 # @parm String result	- Result string
	 # @return void
	proc custom_cmd_finish {num result} {
		variable custom_command_options	;# Array of Lists of custom command options

		# Set toolbar button icon to default and determinate command index
		set i [custom_cmd_icon_reset $num]
		if {$i == {}} {return}

		# Check if result dialogues are allowed
		if {![lindex $custom_command_options($i) 1]} {return}
		# Invoke results dialog
		invoke_custom_cmd_dialog $i {#00DD00} [mc "Custom command finished"] $result
	}

	## Invoke dialog "Custom command failed"
	 # -- auxiliary procedure for '__exec_custom_cmd'
	 # @parm Int num	- Command number
	 # @parm String result	- Result string
	 # @return void
	proc custom_cmd_error {num result} {
		variable custom_command_options	;# Array of Lists of custom command options

		# Set toolbar button icon to default and determinate command index
		set i [custom_cmd_icon_reset $num]
		if {$i == {}} {return}

		# Check if error dialogues are allowed
		if {[lindex $custom_command_options($i) 2]} {return}
		# Invoke error dialog
		invoke_custom_cmd_dialog $i {#DD0000} [mc "Custom command failed"] $result
	}

	## Execute custom command in terminal emulator
	 # @parm Int cmd_num	- Number of the custom command to execute
	 # @parm String cmd	- Command string to execute
	 # @return void
	proc exec_custom_cmd_in_terminal {cmd_num cmd} {
		variable custom_cmd_dialog_index	;# Index of results dialog (to keep win IDs unique)

		incr custom_cmd_dialog_index

		# Create dialog window
		set win [toplevel .custom_cmd_dialog${custom_cmd_dialog_index} -class {Custom command running} -bg ${::COMMON_BG_COLOR}]

		# Create dialog header
		pack [label $win.header_label					\
			-compound left						\
			-text [mc "Custom command %s - MCU 8051 IDE" $cmd_num]	\
			-image ::ICONS::22::gear${cmd_num}_play			\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-20 * $::font_size_factor)}]	\
				-weight bold					\
			] \
		] -pady 5

		# Create main frame (text widget and scrollbar)
		set main_frame [frame $win.main_frame -container 1]
		bind $main_frame <Destroy> [list destroy $win]
		pack $main_frame -fill both -expand 1 -padx 5 -pady 5

		# Set window attributes
		wm iconphoto $win ::ICONS::16::gear
		wm title $win [mc "Custom command %s - MCU 8051 IDE" $cmd_num]
		wm minsize $win 550 300
		wm protocol $win WM_DELETE_WINDOW {}
		update

		# Run terminal emulator
		if {[catch {
			set terminal_pid [exec -- urxvt					\
				-embed [expr [winfo id $main_frame]]			\
				-hold -sr -b 0 -w 0 -bg ${::Terminal::configuration(bg)}\
				-fg ${::Terminal::configuration(fg)}			\
				-fn "xft:${::Terminal::configuration(font_family)}:pixelsize=${::Terminal::configuration(font_size)}" \
				-e bash -i -c $cmd \
				& \
			]
		} result]} then {
			destroy $win
			tk_messageBox		\
				-parent .	\
				-icon warning	\
				-type ok	\
				-title [mc "Unknow error"]	\
				-message [mc "Unable to execute your script in the urxvt terminal emulator."]
			puts stderr $result
		} else {
			wm protocol $win WM_DELETE_WINDOW [list ::X::close_custom_cmd_term $terminal_pid $win]
		}
	}

	## Close terminal emulator with a custom command
	 # @parm Int pid	- Terminal PID
	 # @parm Widget dialog	- Dialog window in which the terminal is mapped
	 # @return void
	proc close_custom_cmd_term {pid dialog} {
		# Get list of child processes of the terminal
		set children [list]
		catch {
			set children [exec -- /bin/sh -c "ps -o pid --no-headers --ppid $pid"]
		}

		# Ask user, if he/she wishes to kill the children, if there are any
		if {
			[llength $children]
				&&
			[tk_messageBox		\
				-parent $dialog	\
				-icon question	\
				-type yesno	\
				-title [mc "Kill the script?"] \
				-message [mc "Closing this window terminates all child processes of the terminal.\n\nDo you want to proceed?"] \
			] != {yes}
		} then {
			return
		}

		# Kill the terminal
		if {[catch {
			exec -- kill $pid &
		}]} then {
			puts stderr "Something went wrong here..."
			puts stderr $::errorInfo
		}
	}

	## Invoke dialog window showing results of some custom command
	 # -- auxiliary procedure for 'custom_cmd_error' and 'custom_cmd_finish'
	 # @parm Int i		- Index of the custom command (0..2)
	 # @parm RGB color	- Color for dialog header (24-bit RGB color code)
	 # @parm String label	- Text of the dialog header
	 # @parm String result	- Text of the messages area
	 # @return void
	proc invoke_custom_cmd_dialog {i color label result} {
		variable custom_cmd_dialog_index	;# Index of results dialog (to keep win IDs unique)

		incr custom_cmd_dialog_index

		# Create dialog window
		set win [toplevel .custom_cmd_dialog${custom_cmd_dialog_index} -class {Custom command finished} -bg ${::COMMON_BG_COLOR}]

		# Create dialog header
		pack [label $win.header_label					\
			-compound left						\
			-fg $color						\
			-text $label						\
			-image ::ICONS::22::gear$i				\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-20 * $::font_size_factor)}]	\
				-weight bold					\
			] \
		] -pady 5

		# Create main frame (text widget and scrollbar)
		set main_frame [frame $win.main_frame]
		set text [text $main_frame.text				\
			-width 1 -height 1				\
			-yscrollcommand "$main_frame.scrollbar set"	\
		]
		pack $text -side left -fill both -expand 1
		pack [ttk::scrollbar $main_frame.scrollbar	\
			-command "$text yview"			\
			-orient vertical			\
		] -fill y -side right
		pack $main_frame -fill both -expand 1 -pady 5

		# Create button "Ok"
		pack [ttk::button $win.ok_button	\
			-text [mc "Ok"]			\
			-command "destroy $win"		\
			-compound left			\
			-image ::ICONS::16::ok		\
		] -pady 5

		# Fill in the text widget and disable it
		$text insert end [string replace [regsub -all {\\\{} [regsub -all {\\\}} $result "\}"] "\{"] 0 0]
		$text configure -state disabled

		# Events binding (Enter/Escape == Ok)
		bind $win <KeyRelease-Return>	"destroy $win; break"
		bind $win <KeyRelease-KP_Enter>	"destroy $win; break"
		bind $win <KeyRelease-Escape>	"destroy $win; break"

		# Set window attributes
		wm iconphoto $win ::ICONS::16::gear
		wm title $win [mc "Custom command %s - MCU 8051 IDE" $i]
		wm minsize $win 550 300
		wm protocol $win WM_DELETE_WINDOW "destroy $win"
		wm transient $win .
	}

	## Set toolbar button icon to default and determinate index of custom command
	 # -- auxiliary procedure for 'custom_cmd_error' and 'custom_cmd_finish'
	 # @parm Int num - Command number
	 # @return Int - index of the specified custom command (by TID) or {} (means 'not found')
	proc custom_cmd_icon_reset {num} {
		variable custom_command_NUM	;# Array of custom command numbers
		variable custom_command_PID	;# Array of custom command TIDs (Thread IDentifiers)

		# Search for command index
		set found 0	;# Bool: Corresponding index found
		for {set i 0} {$i < 3} {incr i} {
			if {[string equal $custom_command_NUM($i) $num]} {
				set found 1
				break
			}
		}
		# If index not found -> return {}
		if {!$found} {return {}}

		# Reset toolbar button icon
		if {[winfo exists .mainIconBar.custom$i]} {
			.mainIconBar.custom$i configure	-image ::ICONS::22::gear${i}
		}
		# Reset command PID and return result
		set custom_command_PID($i) {}
		return $i
	}

	## Invoke welcome dialog
	 # @return void
	proc __welcome_dialog {} {
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time

		if {$critical_procedure_in_progress} {return}
		if {[winfo exists .welcome]} {
			return
		}

		# Create dialog window
		set win [toplevel .welcome -class {Welcome dialog} -bg ${::COMMON_BG_COLOR}]

		# Create header label
		pack [label $win.header_label					\
			-compound left -fg {#0000DD}				\
			-text [mc "Welcome to MCU 8051 IDE !"]			\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-20 * $::font_size_factor)}]	\
				-weight {bold}					\
				-slant {italic}					\
			]							\
		] -pady 10

		# Create frame for the text widget and its scrollbar
		set text_frame [frame $win.text_frame]

		# Create text widget showing the dialog message
		set text [text $text_frame.text					\
			-bg ${::COMMON_BG_COLOR} -takefocus 0			\
			-width 0 -heigh 0 -bd 0					\
			-cursor left_ptr					\
			-wrap word						\
			-yscrollcommand [list $text_frame.scrollbar set]	\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-12 * $::font_size_factor)}]	\
			]							\
		]

		# Create scrollbar for the text widget
		set scrollbar [ttk::scrollbar $text_frame.scrollbar	\
			-command [list $text yview]			\
			-orient vertical				\
		]

		# Pack scrollbar and the text widget
		pack $text -side left  -fill both -expand 1
		pack $scrollbar -side right -fill y
		pack $text_frame -fill both -expand 1 -padx 15

		# Create button "Ok"
		pack [ttk::button $win.ok_button			\
			-text [mc "Ok"]					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command "grab release $win; destroy $win"	\
		] -pady 5

		# Create label for opening demostration project
		set open_demo_label [label $text.open_demo_label		\
			-text [mc "Click here to open demonstration project."]	\
			-justify left						\
			-fg {#0055FF}						\
			-cursor hand2						\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-12 * $::font_size_factor)}]	\
			]							\
			-image ::ICONS::16::2_rightarrow			\
			-compound left						\
			-padx 5							\
		]
		bind $open_demo_label <Enter> {%W configure -fg {#00DD00}}
		bind $open_demo_label <Leave> {%W configure -fg {#0055FF}}
		bind $open_demo_label <Button-1> "
			grab release $win
			destroy $win
			::X::open_demo_project
			break
		"

		# Load images
		set image_new	::ICONS::16::filenew
		set image_start	::ICONS::16::launch
		set image_step	::ICONS::16::goto
		set image_list0	::ICONS::16::dot_r
		set image_list1	::ICONS::16::dot_g
		set image_list2	::ICONS::16::dot

		# Create text tags
		$text tag configure bold -font [font create		\
			-family {helvetica}				\
			-size [expr {int(-12 * $::font_size_factor)}]	\
			-weight bold					\
		]
		$text tag configure header -font [font create		\
			-family {helvetica}				\
			-size [expr {int(-12 * $::font_size_factor)}]	\
			-weight bold					\
			-underline 1					\
		] -foreground {#0000DD}

		# Fill in the text widget
		$text insert end [mc "MCU 8051 IDE is a fully featured Integrated Development Environment"]
		$text insert end [mc " for MCS-51 based microcontrollers.  It's written for POSIX Operating Systems (GNU/Linux, etc.) "]
		if {$::MICROSOFT_WINDOWS} {
			$text insert end [mc "and since version 1.3.5 it is also available for Microsoft® Windows® operating system."]
		}
		$text insert end "\n\n"
		$text insert end [mc "Main features:"]
		$text tag add header {insert linestart} insert
		$text insert end "\n\t"
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Editor with syntax highlight, validation and popup-based completion\n\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "MCS-51 Assembler and Disassembler\n\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "MCS-51 Simulator (not all MCUs are fully supported!)\n\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Support for C language (using C compiler SDCC)\n\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Partial support for some HW tools\n\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Project management\n\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Custom editable commands (using shell scripts)\n\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Dynamic help for instruction at the current line\n\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Hexadecimal editor for eXternal RAM, Expanded RAM, Code memory, etc.\n\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Scientific calculator\n\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Simple hardware simulation (LED's, etc.)\n\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Graph showing voltage levels on ports\n\n"]

		$text insert end [mc "Where to start:"]
		$text tag add header {insert linestart} insert
		$text insert end [mc "\n\t1. Create a new project"]
		$text image create end -image $image_new -padx 5
		$text insert end "\n\t\t"
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Enter project name\n\t\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Choose project directory\n\t\t"]
		$text image create end -image $image_list1 -padx 5
		$text insert end [mc "Choose microcontroller (e.g. AT89S52)\n"]
		$text insert end [mc "\t2. Write your code in the opened editor and click on "]
		$text image create end -image $image_start -padx 5
		$text insert end [mc " to start the simulator\n"]
		$text insert end [mc "\t3. Step through your program by clicking on "]
		$text image create end -image $image_step -padx 5
		$text insert end "\n\t----\n\t"
		$text window create end -window $open_demo_label
		$text insert end ""

		$text insert end "\n\n"
		$text insert end [mc "Web site:"]
		$text tag add bold {insert linestart} insert
		$text insert end "\thttp://mcu8051ide.sourceforge.net\n"
		$text insert end [mc "Authors:"]
		$text tag add bold {insert linestart} insert
		$text insert end "\tMartin Ošmera <martin.osmera@gmail.com>\n"

		$text insert end [mc "Thank you for using/trying MCU 8051 IDE."]
		$text tag add bold {insert linestart} insert

		create_link_tag_in_text_widget $text
		convert_all_https_to_links $text
		$text configure -state disabled

		# Set window attributes
		wm iconphoto $win ::ICONS::16::info
		wm title $win [mc "Welcome to MCU 8051 IDE"]
		wm minsize $win 580 400
		wm protocol $win WM_DELETE_WINDOW "grab release $win; destroy $win"
		wm transient $win .
		catch {grab $win}
		raise $win
	}

	## Open demostration project -- auxiliary procedure for '__welcome_dialog'
	 # @return void
	proc open_demo_project {} {
		variable openedProjects	;# List of opened projects (Object references)

		if {[Project::open_project_file "${::INSTALLATION_DIR}/demo/Demo project.mcu8051ide"]} {
			# The demostration project is for reading only, it cannot be saved
			[lindex $openedProjects end] set_read_only
		}
	}

	## Invoke dialog "Change letter case"
	 # @return void
	proc __change_letter_case {} {
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable change_letter_case_options	;# Options (which fields should be adjusted)
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 1]} {return}

		if {$critical_procedure_in_progress} {return}

		# Create dialog window
		set win [toplevel .change_letter_case -class [mc "Options dialog"] -bg ${::COMMON_BG_COLOR}]

		# Create dialog header
		pack [label $win.header						\
			-compound left						\
			-image ::ICONS::22::change_case				\
			-text [mc "Change letter case"]				\
			-font [font create					\
				-size [expr {int(-20 * $::font_size_factor)}]	\
				-family {times}]
		] -side top -pady 5

		# Create main frame (contains labels and radio buttons)
		set main_frame [frame $win.main_frame]

		# Create header
		foreach	column	{1	2	3		5	6	7		} \
			image	{up0	down0	button_cancel	up0	down0	button_cancel	} \
			helptext	{
				{Uppercase}	{Lowercase}	{Keep case}
				{Uppercase}	{Lowercase}	{Keep case}
			}	\
		{
			grid [Label $main_frame.header_label$column	\
				-pady 0 -bd 0 -helptext [mc $helptext]	\
				-image ::ICONS::16::$image		\
			] -row 0 -column $column -sticky w
		}

		# Create matrix of radiobuttons and labels
		set i 0
		set row 1
		set col 0
		foreach text {
				{Hexadecimal number}	{Octal number}
				{Decimal number}	{Binary number}
				{Constant}		{Generic number}
				{Comment}		{Control sequence}
				{Symbol}		{Directive}
				{Label}			{Instruction}
				{SFR register}		{Indirect address}
				{Immediate hex}		{Immediate oct}
				{Immediate dec}		{Immediate bin}
				{Immediate const}	{Immediate generic}
				{Macro instruction}
			} \
		{
			# Create label
			grid [label $main_frame.label$i		\
				-text [mc $text] -justify left	\
				-highlightthickness 0		\
				-pady 0 -bd 0			\
			] -row $row -column [expr {$col * 4}] -sticky w

			# Radiobutton "Uppercase"
			grid [radiobutton $main_frame.upper$i			\
				-value {U} -highlightthickness 0 -pady 0	\
				-variable ::X::change_letter_case_options($i)	\
			] -row $row -column [expr {$col * 4 + 1}] -sticky w
			# Radiobutton "Lowercase"
			grid [radiobutton $main_frame.lower$i			\
				-value {L} -highlightthickness 0 -pady 0	\
				-variable ::X::change_letter_case_options($i)	\
			] -row $row -column [expr {$col * 4 + 2}] -sticky w
			# Radiobutton "Keep"
			grid [radiobutton $main_frame.keep$i			\
				-value {-} -highlightthickness 0 -pady 0	\
				-variable ::X::change_letter_case_options($i)	\
			] -row $row -column [expr {$col * 4 + 3}] -sticky w

			incr col
			incr i
			if {$col > 1} {
				set col 0
				incr row
			}
		}

		# Set column sizes
		grid columnconfigure $main_frame 0 -minsize 140
		grid columnconfigure $main_frame 3 -minsize 50
		grid columnconfigure $main_frame 4 -minsize 140

		# Create button frame
		set button_frame [frame $win.button_frame]
		# Create buttons "All up", "All down" and "All keep"
		foreach	image	{up0	down0	button_cancel}	\
			state	{U	L	-}		\
		{
			pack [ttk::button $button_frame.${image}_but			\
				-compound right						\
				-text [mc "All "]					\
				-image ::ICONS::16::$image				\
				-command "::X::change_letter_case_all_to $state"	\
			] -side left -padx 2
		}
		# Create and pack buttons "OK" and "CANCEL"
		pack [ttk::button $button_frame.ok_button	\
			-text [mc "Ok"]				\
			-compound left				\
			-image ::ICONS::16::ok			\
			-command {X::change_letter_case_OK}	\
		] -side right -padx 2
		pack [ttk::button $button_frame.cancel_button	\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command {X::change_letter_case_CANCEL} \
		] -side right -padx 2

		# Events binding (Enter == Ok; Escape == Cancel)
		bind $win <KeyRelease-Return>	{::X::change_letter_case_OK; break}
		bind $win <KeyRelease-KP_Enter>	{::X::change_letter_case_OK; break}
		bind $win <KeyRelease-Escape>	{::X::change_letter_case_CANCEL; break}

		# Pack frames
		pack $main_frame -fill both -expand 1 -padx 10 -pady 10
		pack $button_frame -side bottom -fill x -padx 5 -pady 5

		# Set window attributes
		wm iconphoto $win ::ICONS::16::change_case
		wm title $win [mc "Change letter case - MCU 8051 IDE"]
		wm minsize $win 450 70
		wm protocol $win WM_DELETE_WINDOW {
			::X::change_letter_case_CANCEL
		}
		wm transient $win .
		catch {grab $win}
		raise $win
		tkwait window $win
	}

	## Perform letter case change -- auxiliary procedure for '__change_letter_case'
	 # @return void
	proc change_letter_case_OK {} {
		change_letter_case_CANCEL	;# Close dialog window
		change_letter_case_start	;# Perform change
	}

	## Close "Change letter case" dialog window
	 # -- auxiliary procedure for '__change_letter_case'
	 # @return void
	proc change_letter_case_CANCEL {} {
		grab release .change_letter_case
		destroy .change_letter_case
	}

	## Set all options to the specified state
	 # -- auxiliary procedure for '__change_letter_case'
	 # @parm Char state - new state
	 #			'U' == Uppercase
	 #			'L' == Lowercase
	 #			'-' == Keep
	 # @return void
	proc change_letter_case_all_to {state} {
		variable change_letter_case_options	;# Options (which fields should be adjusted)

		for {set i 0} {$i < 21} {incr i} {
			set change_letter_case_options($i) $state
		}
	}

	## Perform letter case change -- auxiliary procedure for 'change_letter_case_OK'
	 # @return void
	proc change_letter_case_start {} {
		variable actualProject			;# Object: Current project
		variable compilation_progress		;# Variable for compilation progressbar
		variable change_letter_case_options	;# Options (which fields should be adjusted)

		# Check if the current editor is not empty
		if {
			[$actualProject editor_procedure {} getLinesCount {}] == 1
				&&
			[$actualProject editor_procedure {} getLineContent 1] == {}
		} then {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon error	\
				-title [mc "Unable to comply"]	\
				-message [mc "This editor seems to be empty"]
			return
		}

		set compilation_progress 1	;# Reset compilation progress variable

		# Set maximum for 1st progress bar ("Finishing highlight")
		set max [$actualProject editor_procedure {} highlight_all_count_of_iterations {}]
		incr max

		# Create progress dialog window
		set win [toplevel .change_letter_case_dialog -class {Progress dialog} -bg ${::COMMON_BG_COLOR}]

		# Create label and progress bar
		set main_frame [frame $win.main_frame]
		pack [label $main_frame.header -text [mc "Finishing highlight ..."]]	\
			-pady 10 -padx 20 -anchor w
		pack [ttk::progressbar $main_frame.progress_bar	\
			-maximum $max				\
			-mode determinate			\
			-variable {X::compilation_progress}	\
			-length 430				\
		] -fill y
		pack $main_frame -fill x -expand 1
		pack [ttk::button $win.abort_button		\
			-text [mc "Abort"]			\
			-image ::ICONS::16::cancel		\
			-compound left				\
			-command {X::change_letter_case_abort}	\
		]

		# Create options list
		for {set i 0} {$i < 21} {incr i} {
			lappend options $change_letter_case_options($i)
		}

		# Set window attributes
		wm iconphoto $win ::ICONS::16::change_case
		wm title $win [mc "Change letter case - MCU 8051 IDE"]
		wm minsize $win 450 70
		wm protocol $win WM_DELETE_WINDOW {
			exportToX_abort
		}
		wm transient $win .
		catch {grab $win}
		raise $win
		update

		# Finish highlight
		$actualProject editor_procedure {} highlight_all {}
		if {![winfo exists $win]} {return}

		# Determinate maximum value for the 2nd progress bar ("Formatting")
		set max [$actualProject editor_procedure {} change_letter_case_get_count_of_iterations "{$options}"]
		incr max
		# Change progress bar header label
		$main_frame.header configure -text [mc "Formatting ..."]
		$main_frame.progress_bar configure -maximum $max

		set compilation_progress 1	;# Reset compilation progress variable
		update

		# Finaly perform letter case change
		$actualProject editor_procedure {} change_letter_case [list $options]

		# Close the window
		catch {
			grab release .change_letter_case_dialog
			destroy .change_letter_case_dialog
		}
	}

	## Abort letter case change-- auxiliary procedure for 'change_letter_case_start'
	 # @return void
	proc change_letter_case_abort {} {
		variable actualProject	;# Object: Current project

		# Abort the procedure in editor
		$actualProject editor_procedure {} change_letter_case_abort_now {}

		# Close progress dialog
		grab release .change_letter_case_dialog
		destroy .change_letter_case_dialog
	}

	## Switch to the previous editor in the current project
	 # @return void
	proc __prev_editor {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Switch editor
		$actualProject prev_editor

		# Finalize
		set critical_procedure_in_progress 0

	}

	## Switch to the next editor in the current project
	 # @return void
	proc __next_editor {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Switch editor
		$actualProject next_editor

		# Finalize
		set critical_procedure_in_progress 0
	}

	## Change EOL character in the current editor
	 # @return void
	proc change_EOL {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} {return}
		if {$critical_procedure_in_progress} {return}

		# Change EOL
		$actualProject change_EOL
	}

	## Change character encoding in the current editor
	 # @return void
	proc change_encoding {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[simulator_must_be_disabled 0]} {return}
		if {$critical_procedure_in_progress} {return}

		# Change encoding
		$actualProject change_encoding
	}

	## Switch between RO and RW modes in the current editor
	 # @return void
	proc switch_editor_RO_MODE {} {
		variable actualProject			;# Object: Current project
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {![$actualProject switch_editor_RO_MODE]} {
			# Switch the flag back if the operation was unsuccessful
			set ::editor_RO_MODE [expr {!$::editor_RO_MODE}]
		}
	}

	## Prepare window "Project details"
	 # @parm Object project - project object descriptor
	 # @return void
	proc create_project_details {project} {
		variable openedProjects			;# List of opened projects (Object references)
		variable PROJECTDETAILSWIN		;# ID of project details window
		variable projectdetails_last_project	;# Project object of the last project details window

		# Check if the given project is a valid object reference
		if {[lsearch -ascii -exact $openedProjects $project] == -1} {
			return
		}

		if {$projectdetails_last_project == $project} {
			project_details_move
			return
		} else {
			set projectdetails_last_project $project
		}

		# Destroy previous window
		catch {destroy $PROJECTDETAILSWIN}

		set authors [$project cget -G_information_authors]
		set authors [join [split $authors "\n"] {, }]
		if {[string length $authors] > 40} {
			set authors [string range $authors 0 36]
			append authors {...}
		}

		# Create window
		set PROJECTDETAILSWIN [frame .project_details_win -bg {#BBBBFF}]
		set project_details_win [frame $PROJECTDETAILSWIN.frm -bg {#FFFFFF}]

		# Create header
		pack [label $project_details_win.header		\
			-text [$project cget -projectName]	\
			-justify left -pady 0 -padx 15		\
			-compound left -anchor w -bg {#BBBBFF}	\
			-image ::ICONS::16::kcmdevices		\
		] -fill x

		# Create main frame (containing everything except the header)
		set main_frame [frame $project_details_win.main_frame -bg {#FFFFFF}]

		# File name
		grid [label $main_frame.filename_label	\
			-text [mc "File name:"]		\
			-fg {#880033} -bg {#FFFFFF}	\
			-anchor w -pady 0		\
		] -row 0 -column 0 -sticky w -pady 0
		grid [label $main_frame.filename_value		\
			-text [$project cget -projectFile]	\
			-anchor w -pady 0 -bg {#FFFFFF}		\
		] -row 0 -column 1 -sticky w -pady 0
		# Path
		grid [label $main_frame.path_label	\
			-text [mc "Path:"] -fg {#880033}\
			-anchor w -pady 0 -bg {#FFFFFF}	\
		] -row 1 -column 0 -sticky w -pady 0
		set path [$project cget -projectPath]
		if {$::MICROSOFT_WINDOWS} {
			regsub -all {/} $path "\\" path
		}
		grid [label $main_frame.path_value	\
			-text $path			\
			-anchor w -pady 0 -bg {#FFFFFF}	\
		] -row 1 -column 1 -sticky w -pady 0

		# Separator
		grid [ttk::separator $main_frame.sep0 -orient horizontal	\
		] -row 2 -column 0 -columnspan 2 -sticky we -pady 5

		# MCU:
		grid [label $main_frame.family_label	\
			-text [mc "MCU:"] -fg {#0000AA}	\
			-anchor w -pady 0 -bg {#FFFFFF}	\
		] -row 3 -column 0 -sticky w -pady 0
		grid [label $main_frame.family_value		\
			-text [$project cget -P_option_mcu_type]\
			-anchor w -pady 0 -bg {#FFFFFF}		\
		] -row 3 -column 1 -sticky w -pady 0
		# XDATA:
		grid [label $main_frame.xdata_label		\
			-text [mc "XDATA:"] -fg {#0000AA}	\
			-anchor w -pady 0 -bg {#FFFFFF}		\
		] -row 4 -column 0 -sticky w -pady 0
		grid [label $main_frame.xdata_value			\
			-text "[$project cget -P_option_mcu_xdata] B"	\
			-anchor w -pady 0 -bg {#FFFFFF}			\
		] -row 4 -column 1 -sticky w -pady 0
		# XCODE:
		grid [label $main_frame.xcode_label		\
			-text [mc "XCODE:"] -fg {#0000AA}	\
			-anchor w -pady 0 -bg {#FFFFFF}		\
		] -row 5 -column 0 -sticky w -pady 0
		grid [label $main_frame.xcode_value			\
			-text "[$project cget -P_option_mcu_xcode] B"	\
			-anchor w -pady 0 -bg {#FFFFFF}			\
		] -row 5 -column 1 -sticky w -pady 0
		# Clock:
		grid [label $main_frame.clock_label		\
			-text [mc "Clock:"] -fg {#0000AA}	\
			-anchor w -pady 0 -bg {#FFFFFF}		\
		] -row 6 -column 0 -sticky w -pady 0
		grid [label $main_frame.clock_value			\
			-text "[$project cget -P_option_clock] kHz"	\
			-anchor w -pady 0 -bg {#FFFFFF}			\
		] -row 6 -column 1 -sticky w -pady 0

		set more_details_available 0
		# Version
		if {[string length [$project cget -P_information_version]]} {
			set more_details_available 1
			grid [label $main_frame.ver_label		\
				-text [mc "Version:"] -fg {#0000AA}	\
				-anchor w -pady 0 -bg {#FFFFFF}		\
			] -row 8 -column 0 -sticky w -pady 0
			grid [label $main_frame.ver_value			\
				-text [$project cget -P_information_version]	\
				-anchor w -pady 0 -bg {#FFFFFF}			\
			] -row 8 -column 1 -sticky w -pady 0
		}
		# Date
		if {[string length [$project cget -P_information_date]]} {
			set more_details_available 1
			grid [label $main_frame.date_label		\
				-text [mc "Date:"] -fg {#0000AA}	\
				-anchor w -pady 0 -bg {#FFFFFF}		\
			] -row 9 -column 0 -sticky w -pady 0
			grid [label $main_frame.date_value			\
				-anchor w -pady 0 -bg {#FFFFFF}			\
				-text [$project cget -P_information_date]	\
			] -row 9 -column 1 -sticky w -pady 0
		}
		# License
		if {[string length [$project cget -G_information_license]]} {
			set more_details_available 1
			grid [label $main_frame.license_label	\
				-text [mc "License:"]		\
				-fg {#0000AA}			\
				-anchor w -pady 0 -bg {#FFFFFF}	\
			] -row 10 -column 0 -sticky w -pady 0
			grid [label $main_frame.license_value			\
				-text [$project cget -G_information_license]	\
				-anchor w -pady 0 -bg {#FFFFFF}			\
			] -row 10 -column 1 -sticky w -pady 0
		}
		# Copyright
		if {[string length [$project cget -G_information_copyright]]} {
			set more_details_available 1
			grid [label $main_frame.copyright_label	\
				-text [mc "Copyright:"]		\
				-fg {#0000AA} -bg {#FFFFFF}	\
				-anchor w -pady 0		\
			] -row 11 -column 0 -sticky w -pady 0
			grid [label $main_frame.copyright_value	\
				-anchor w -pady 0 -bg {#FFFFFF}	\
				-text [$project cget -G_information_copyright]	\
			] -row 11 -column 1 -sticky w -pady 0
		}
		# Authors
		if {[string length $authors]} {
			set more_details_available 1
			grid [label $main_frame.authors_label	\
				-text [mc "Authors:"]		\
				-fg {#0000AA}			\
				-anchor w -pady 0 -bg {#FFFFFF}	\
			] -row 12 -column 0 -sticky w -pady 0
			grid [label $main_frame.authors_value	\
				-text $authors -anchor w	\
				-pady 0 -bg {#FFFFFF}		\
			] -row 12 -column 1 -sticky w -pady 0
		}
		# Separator
		if {$more_details_available} {
			grid [ttk::separator $main_frame.sep1 -orient horizontal	\
			] -row 7 -column 0 -columnspan 2 -sticky we -pady 5
		}

		# Pack main frame
		grid columnconfigure $main_frame 0 -minsize 80
		pack $main_frame -fill both -expand 1 -padx 8 -pady 3
		pack $project_details_win -fill both -expand 1 -padx 2 -pady 2

		# Configure the window in a way that it will close when the user clicks on it
		foreach w [concat $project_details_win [pack slaves $project_details_win] [grid slaves $main_frame]] {
			bind $w <Button-1> {::X::close_project_details}
		}

		# Show window "Project details"
		project_details_move
	}

	## Move window "Project details"
	 # @return void
	proc project_details_move args {
		variable PROJECTDETAILSWIN	;# ID of project details window

		# Show the window
		catch {
			place $PROJECTDETAILSWIN -anchor nw				\
				-x [expr {[winfo pointerx .] - [winfo rootx .] + 20}]	\
				-y [expr {[winfo pointery .] - [winfo rooty .] + 20}]
			update
			raise $PROJECTDETAILSWIN
		}
	}

	## Hide window "Project details"
	 # @return void
	proc close_project_details args {
		variable PROJECTDETAILSWIN		;# ID of project details window

		# Hide the window
		catch {place forget $PROJECTDETAILSWIN}
	}

	## Invokes menu for manipulating project tab
	 # @parm Int x		- Absolute X coordinate of mouse pointer
	 # @parm Int y		- Absolute Y coordinate of mouse pointer
	 # Object project	- project object descriptor
	proc invoke_project_menu {x y project} {
		variable projectmenu		;# ID of Popup menu for project tabs
		variable projectmenu_project	;# Object: project selected by project popup menu
		variable openedProjects		;# List of opened projects (Object references)

		# Check if the given project exists (due to a bug in BWidget-1.7)
		if {[lsearch -ascii -exact $openedProjects $project] == -1} {
			puts stderr "Internal error detected: Please install BWidget-1.8 or higher"
			return
		}

		# Enable/Disable menu entries
		set tabindex [${::main_nb} index $project]
		if {!$tabindex} {
			$projectmenu entryconfigure [::mc "Move to beginning"]	-state disabled
			$projectmenu entryconfigure [::mc "Move left"]		-state disabled
		} else {
			$projectmenu entryconfigure [::mc "Move to beginning"]	-state normal
			$projectmenu entryconfigure [::mc "Move left"]		-state normal
		}
		if {$tabindex == ([llength [${::main_nb} pages]] - 1)} {
			$projectmenu entryconfigure [::mc "Move right"]		-state disabled
			$projectmenu entryconfigure [::mc "Move to end"]	-state disabled
		} else {
			$projectmenu entryconfigure [::mc "Move right"]		-state normal
			$projectmenu entryconfigure [::mc "Move to end"]	-state normal
		}

		# Invoke the menu and set project identifier
		set projectmenu_project $project
		tk_popup $projectmenu $x $y
	}

	## Function for project popup menu
	 # -- Save this project
	 # @return void
	proc __project_pmenu_save {} {
		variable actualProject		;# Object: Current project
		variable openedProjects		;# List of opened projects (Object references)
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable projectmenu_project	;# Object: project selected by project popup menu

		set tmp			$actualProject
		set actualProject	$projectmenu_project
		set tmp_idx		$actualProjectIdx
		set actualProjectIdx	[lsearch -exact -ascii $openedProjects $actualProject]

		__proj_save

		set actualProject	$tmp
		set actualProjectIdx	$tmp_idx
	}

	## Function for project popup menu
	 # -- Edit this project
	 # @return void
	proc __project_pmenu_edit {} {
		variable actualProject		;# Object: Current project
		variable openedProjects		;# List of opened projects (Object references)
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable projectmenu_project	;# Object: project selected by project popup menu

		set tmp			$actualProject
		set actualProject	$projectmenu_project
		set tmp_idx		$actualProjectIdx
		set actualProjectIdx	[lsearch -exact -ascii $openedProjects $actualProject]

		__proj_edit

		set actualProject	$tmp
		set ctualProjectIdx	$tmp_idx
	}

	## Function for project popup menu
	 # -- Close this project
	 # @return void
	proc __project_pmenu_close {} {
		variable actualProject		;# Object: Current project
		variable openedProjects		;# List of opened projects (Object references)
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable projectmenu_project	;# Object: project selected by project popup menu

		# Adjust variables identifing current project
		set tmp			$actualProject
		set tmp_idx		$actualProjectIdx
		set actualProject	$projectmenu_project
		set actualProjectIdx	[lsearch -exact -ascii $openedProjects $actualProject]
		if {$actualProjectIdx == $tmp_idx} {
			set this_closed 1
		} else {
			set this_closed 0
		}

		# Close project
		__proj_close
	}

	## Function for project popup menu
	 # -- Close this project without saving
	 # @return void
	proc __project_pmenu_close_imm {} {
		variable actualProject		;# Object: Current project
		variable openedProjects		;# List of opened projects (Object references)
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable projectmenu_project	;# Object: project selected by project popup menu

		# Adjust variables identifing current project
		set tmp			$actualProject
		set tmp_idx		$actualProjectIdx
		set actualProject	$projectmenu_project
		set actualProjectIdx	[lsearch -exact -ascii $openedProjects $actualProject]
		if {$actualProjectIdx == $tmp_idx} {
			set this_closed 1
		} else {
			set this_closed 0
		}

		# Close project and restore variables identifing current project
		if {[__proj_close_imm] && !$this_closed} {
			if {$tmp_idx > $actualProjectIdx} {
				incr tmp_idx -1
			}
			set actualProjectIdx	$tmp_idx
			set actualProject	$tmp
		}
	}

	## Function for project popup menu
	 # -- Move this tab left
	 # @return void
	proc __project_move_to_left {} {
		variable projectmenu_project	;# Object: project selected by project popup menu

		set index [${::main_nb} index $projectmenu_project]
		if {!$index} {
			return
		}

		incr index -1
		${::main_nb} move $projectmenu_project $index
	}

	## Function for project popup menu
	 # -- Move this tab right
	 # @return void
	proc __project_move_to_right {} {
		variable projectmenu_project	;# Object: project selected by project popup menu

		set index [${::main_nb} index $projectmenu_project]
		if {$index == ([llength [${::main_nb} index pages]] - 1)} {
			return
		}

		incr index
		${::main_nb} move $projectmenu_project $index
	}

	## Function for project popup menu
	 # -- Move this tab to the beginning
	 # @return void
	proc __project_move_to_beginning {} {
		variable projectmenu_project	;# Object: project selected by project popup menu

		if {![${::main_nb} index $projectmenu_project]} {
			return
		}
		${::main_nb} move $projectmenu_project 0
	}

	## Function for project popup menu
	 # -- Move this tab to the end
	 # @return void
	proc __project_move_to_end {} {
		variable projectmenu_project	;# Object: project selected by project popup menu

		set end [expr {[llength [${::main_nb} pages]] - 1}]
		if {[${::main_nb} index $projectmenu_project] == $end} {
			return
		}

		${::main_nb} move $projectmenu_project $end
	}

	## Invert flag "allow breakpoints"
	 # @return void
	proc __invert_allow_breakpoints {} {
		set ::CONFIG(BREAKPOINTS_ALLOWED) [expr {!$::CONFIG(BREAKPOINTS_ALLOWED)}]
	}

	## Refresh bookmarks in file system browser in all projects
	 # @return void
	proc refresh_bookmarks_in_fs_browsers {} {
		variable openedProjects	;# List of opened projects (Object references)

		foreach project $openedProjects {
			$project filelist_fsb_refresh_bookmarks
		}
	}

	## Invoke dialog "Tip of the day"
	 # @return void
	proc __tip_of_the_day {} {
		::Tips::show_tip_of_the_day_win
	}

	## Refresh program pointer in CODE memory hexadecimal editor
	 # @parm Object project	- Project object
	 # @parm Int new_PC	- New value of PC (-1 after reset)
	 # @return void
	proc program_counter_changed {project new_PC} {
		variable opened_code_mem_windows	;# List of project object with opened CODE memory hex editor
		variable code_mem_window_objects	;# List of CODE memory hex editor objects

		set idx [lsearch -exact -ascii $opened_code_mem_windows [string trimleft $project {:}]]
		if {$idx != -1} {
			set opcode [$project getCode $new_PC]
			if {[lsearch ${::CompilerConsts::defined_OPCODE} $opcode] == -1} {
				set ins_length 1
			} else {
				set ins_length [lindex $::CompilerConsts::Opcode($opcode) 2]
			}
			[lindex $code_mem_window_objects $idx] move_program_pointer $new_PC $ins_length
		}
	}

	## Refresh program pointer in CODE memory hexadecimal editor
	 # @parm Object project	- Project object
	 # @parm Int new_PC	- New value of PC (-1 after reset)
	 # @return void
	proc code_hex_editor_directly_move_program_pointer {project new_PC} {
		variable opened_code_mem_windows	;# List of project object with opened CODE memory hex editor
		variable code_mem_window_objects	;# List of CODE memory hex editor objects

		set idx [lsearch -exact -ascii $opened_code_mem_windows [string trimleft $project {:}]]
		if {$idx != -1} {
			if {$new_PC != -1} {
				set opcode [$project getCode $new_PC]
				if {[lsearch ${::CompilerConsts::defined_OPCODE} $opcode] == -1} {
					set ins_length 1
				} else {
					set ins_length [lindex $::CompilerConsts::Opcode($opcode) 2]
				}
			} else {
				set ins_length 0
			}
			[lindex $code_mem_window_objects $idx] move_program_pointer_directly $new_PC $ins_length
		}
	}

	## Refresh the current page in CODE memory hexadecimal editor
	 # @parm Object project	- Project object
	 # @return void
	proc refresh_code_mem_window {project} {
		variable opened_code_mem_windows	;# List of project object with opened CODE memory hex editor
		variable code_mem_window_objects	;# List of CODE memory hex editor objects

		set idx [lsearch -exact -ascii $opened_code_mem_windows [string trimleft $project {:}]]
		if {$idx != -1} {
			[lindex $code_mem_window_objects $idx] refresh
		}
	}

	## Refresh the current page in XDATA memory hexadecimal editor
	 # @parm Object project	- Project object
	 # @return void
	proc refresh_xram_mem_window {project} {
		variable opened_xdata_mem_windows	;# List of project object with opened XDATA memory hex editor
		variable xdata_mem_window_objects	;# List of XDATA memory hex editor objects

		set idx [lsearch -exact -ascii $opened_xdata_mem_windows [string trimleft $project {:}]]
		if {$idx != -1} {
			[lindex $xdata_mem_window_objects $idx] refresh
		}
	}

	## Refresh the current page in EDATA memory hexadecimal editor
	 # @parm Object project	- Project object
	 # @return void
	proc refresh_eram_mem_window {project} {
		variable opened_eram_windows		;# List of project object with opened ERAM hex editor
		variable eram_window_objects		;# List of ERAM hex editor objects

		set idx [lsearch -exact -ascii $opened_eram_windows [string trimleft $project {:}]]
		if {$idx != -1} {
			[lindex $eram_window_objects $idx] refresh
		}
	}

	## Refresh the current page in data EEPROM hexadecimal editor
	 # @parm Object project	- Project object
	 # @return void
	proc refresh_eeprom_mem_window {project} {
		variable opened_eeprom_mem_windows	;# List of project object with opened ERAM hex editor
		variable eeprom_mem_window_objects	;# List of ERAM hex editor objects

		set idx [lsearch -exact -ascii $opened_eeprom_mem_windows [string trimleft $project {:}]]
		if {$idx != -1} {
			[lindex $eeprom_mem_window_objects $idx] refresh
		}
	}

	## Clear background highlight for certain cell in hex editor of data EEPROM
	 # @parm Int addr	- Register address (absolute)
	 # @parm Object project	- Project object
	 # @return void
	proc sync_eeprom_clear_bg_hg {addr project} {
		variable opened_eeprom_mem_windows	;# List of project object with opened data EEPROM hex editor
		variable eeprom_mem_window_objects	;# List of data EEPROM hex editor objects

		set idx [lsearch -exact -ascii $opened_eeprom_mem_windows [string trimleft $project {:}]]
		if {$idx != -1} {
			[lindex $eeprom_mem_window_objects $idx] set_bg_hg_clr $addr 0
		}
	}

	## Synchronize the specified cell in data EEPROM hexadecimal editor
	 # @parm String addr	- Hexadecimal address (0 - FFFF)
	 # @parm Int hg		-
	 #	 1 == highlight background
	 #	 0 == do not affect bg. highlight
	 # @parm Object project	- Project object
	 # @return void
	proc sync_eeprom_mem_window {addr hg project} {
		variable opened_eeprom_mem_windows	;# List of project object with opened data EEPROM hex editor
		variable eeprom_mem_window_objects	;# List of data EEPROM hex editor objects

		set idx [lsearch -exact -ascii $opened_eeprom_mem_windows [string trimleft $project {:}]]
		if {$idx != -1} {
			set obj [lindex $eeprom_mem_window_objects $idx]
			$obj reg_sync $addr
			if {$hg} {
				$obj set_bg_hg_clr [expr "0x$addr"] 1
			}
		}
	}

	## Synchronize the specified cell in XDATA/ERAM hexadecimal editor
	 # @parm String addr - Hexadecimal address (0 - FFFF)
	 # @parm Object project	- Project object
	 # @return void
	proc sync_xram_mem_window {addr project} {
		variable opened_xdata_mem_windows	;# List of project object with opened XDATA memory hex editor
		variable xdata_mem_window_objects	;# List of XDATA memory hex editor objects
		variable opened_eram_windows		;# List of project object with opened ERAM hex editor
		variable eram_window_objects		;# List of ERAM hex editor objects

		set project [string trimleft $project {:}]

		# Syncronize XDATA
		set idx [lsearch -exact -ascii $opened_xdata_mem_windows $project]
		if {$idx != -1} {
			[lindex $xdata_mem_window_objects $idx] reg_sync $addr
		}
		# Syncronize ERAM
		set idx [lsearch -exact -ascii $opened_eram_windows $project]
		if {$idx != -1} {
			[lindex $eram_window_objects $idx] reg_sync $addr
		}
	}

	## Show/Close CODE memory hexadecimal editor
	 # @return void
	proc __show_code_mem {} {
		show_X_memory code
	}

	## Show/Close XDATA memory hexadecimal editor
	 # @return void
	proc __show_ext_mem {} {
		show_X_memory xdata
	}

	## Show/Close ERAM hexadecimal editor
	 # @return void
	proc __show_exp_mem {} {
		show_X_memory eram
	}

	## Show/Close ERAM hexadecimal editor
	 # @return void
	proc __show_eeprom {} {
		show_X_memory eeprom
	}

	## Invoke hex editor dialog
	 # @see __show_exp_mem, __show_ext_mem, __show_code_mem, __show_eeprom
	 # @parm String type - memory type (one of {eeprom xdata code eram})
	 # @return void
	proc show_X_memory {type} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable actualProjectIdx		;# Index of the current project in $openedProjects
		variable simulator_enabled		;# List of booleans: Simulator engaged

		variable opened_xdata_mem_windows	;# List of project object with opened XDATA memory hex editor
		variable xdata_mem_window_objects	;# List of XDATA memory hex editor objects
		variable opened_code_mem_windows	;# List of project object with opened CODE memory hex editor
		variable code_mem_window_objects	;# List of CODE memory hex editor objects
		variable opened_eram_windows		;# List of project object with opened ERAM hex editor
		variable eram_window_objects		;# List of ERAM hex editor objects
		variable opened_eeprom_mem_windows	;# List of project object with opened data EEPROM hex editor
		variable eeprom_mem_window_objects	;# List of data EEPROM hex editor objects

		if {$project_menu_locked} {return}

		# Determinate index of the currently opened hex editor for the current project
		switch -- $type {
			{xdata} {
				if {![$actualProject cget -P_option_mcu_xdata]} {
					return
				}
				set idx [lsearch -exact -ascii $opened_xdata_mem_windows $actualProject]
				set list_of_opened {opened_xdata_mem_windows}
				set window_objects {xdata_mem_window_objects}
			}
			{eram} {
				if {![lindex [$actualProject cget -procData] 8]} {
					return
				}
				set idx [lsearch -exact -ascii $opened_eram_windows $actualProject]
				set list_of_opened {opened_eram_windows}
				set window_objects {eram_window_objects}
			}
			{code} {
				set idx [lsearch -exact -ascii $opened_code_mem_windows $actualProject]
				set list_of_opened {opened_code_mem_windows}
				set window_objects {code_mem_window_objects}
			}
			{eeprom} {
				if {![lindex [$actualProject cget -procData] 32]} {
					return
				}
				set idx [lsearch -exact -ascii $opened_eeprom_mem_windows $actualProject]
				set list_of_opened {opened_eeprom_mem_windows}
				set window_objects {eeprom_mem_window_objects}
			}
		}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Close
		if {$idx != -1} {
			close_hexedit $type $actualProject
			set critical_procedure_in_progress 0
			return
		# Show
		} else {
			set object "hexedit_${type}_${actualProject}"
			HexEditDlg ::$object $actualProject $type
			lappend $list_of_opened $actualProject
			lappend $window_objects $object
		}

		# Set filename for code memory and program pointer
		if {$type == {code}} {
			set filename [list					\
				[$actualProject cget -projectPath]		\
				[$actualProject cget -P_option_main_file]	\
			]
			if {[lindex $filename 1] == {}} {
				set filename [$actualProject editor_procedure {} getFileName {}]
			}
			set filename [file join [lindex $filename 0] [lindex $filename 1]]

			set ext [file extension $filename]
			set filename [file rootname $filename]
			if {$ext == {.c} || $ext == {.h} || $ext == {.cxx} || $ext == {.cpp} || $ext == {.cc}} {
				append filename {.ihx}
			} else {
				append filename {.hex}
			}

			::$object set_filename $filename
			if {[lindex $simulator_enabled $actualProjectIdx] == 1} {
				program_counter_changed $actualProject [$actualProject getPC]
			}

		# Highlight cells which are beeing written (EEPROM only)
		} elseif {$type == {eeprom}} {
			foreach addr [$actualProject simulator_get_eeprom_beeing_written] {
				::$object set_bg_hg_clr $addr 1
			}
		}

		# Finalize
		set critical_procedure_in_progress 0
	}

	## Synchronize cell in data EEPROM write buffer with simulator engine
	 # @parm Int addr	- Cell address (0..31)
	 # @parm Object project	- Project object
	 # @return void
	proc sync_eeprom_write_buffer {addr project} {
		variable actualProject			;# Object: Current project
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable opened_eeprom_wr_bf_windows	;# List of project objects with opened data EEPROM write buffer editor
		variable eeprom_wr_bf_window_objects	;# List of data EEPROM write buffer hex editor objects

		if {$project_menu_locked} {return}
		set idx [lsearch -exact -ascii $opened_eeprom_wr_bf_windows [string trimleft $project {:}]]
		if {$idx == -1} {return}
		[string replace [lindex $eeprom_wr_bf_window_objects $idx] 0 0]	\
			setValue $addr [$project getEepromWrBufDEC $addr]
	}

	## Clear data EEPROM write buffer
	 # @parm Object project	- Project object
	 # @return void
	proc clear_eeprom_write_buffer {project} {
		variable actualProject			;# Object: Current project
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable opened_eeprom_wr_bf_windows	;# List of project objects with opened data EEPROM write buffer editor
		variable eeprom_wr_bf_window_objects	;# List of data EEPROM write buffer hex editor objects

		if {$project_menu_locked} {return}
		set idx [lsearch -exact -ascii $opened_eeprom_wr_bf_windows [string trimleft $project {:}]]
		if {$idx == -1} {return}
		set hexeditor [string replace [lindex $eeprom_wr_bf_window_objects $idx] 0 0]
		for {set addr 0} {$addr < 32} {incr addr} {
			$hexeditor setValue $addr {}
		}
	}

	## Set offset for data EEPROM write buffer window
	 # @parm String offset	- New offset (format: 0xXXXX or {})
	 # @parm Object project	- Project object
	 # @return void
	proc eeprom_write_buffer_set_offset {offset project} {
		variable actualProject			;# Object: Current project
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable opened_eeprom_wr_bf_windows	;# List of project objects with opened data EEPROM write buffer editor
		variable eeprom_wr_bf_window_objects	;# List of data EEPROM write buffer hex editor objects

		if {$project_menu_locked} {return}
		set idx [lsearch -exact -ascii $opened_eeprom_wr_bf_windows [string trimleft $project {:}]]
		if {$idx == -1} {return}
		if {$offset == {}} {
			set offset [mc "< Undefined >"]
		}
		[lindex $eeprom_wr_bf_window_objects $idx].offset_frame.val configure -text $offset
	}

	## Binding for pseudo-events <cell_enter> and <cell_leave> in data EEPROM write buffer hex editor
	 # Set value of curosor label at the bottom of the window
	 # This function takes list of attributes with any length gerater
	 #+ than one but only first two are significant
	 # @parm Widget	- Data EEPROM write buffer window
	 # @parm Int	- Cell address
	 # @return void
	proc eeprom_write_buffer_change_cursor_addr args {
		variable foo_procedure_in_progress	;# Bool: Disables some non-critical procedures

		if {$foo_procedure_in_progress} {return}
		set foo_procedure_in_progress 1

		# Parse input arguments
		set win		[lindex $args 0]
		set addr	[lindex $args 1]

		# Increment the given address by offset
		set offset [$win.offset_frame.val cget -text]
		if {$addr != {} && [regexp {^0x[0-9a-fA-F]{4}$} $offset]} {
			incr addr [expr "$offset"]
		}

		# Modify content of cursor label
		if {$addr == {}} {
			$win.bottom_frame.cur_val configure -text {      }
		} else {
			set addr [format %X $addr]
			set len [string length $addr]
			if {$len < 4} {
				set addr "[string repeat {0} [expr {4 - $len}]]$addr"
			}
			$win.bottom_frame.cur_val configure -text "0x$addr"
		}

		set foo_procedure_in_progress 0
	}

	## Invoke hex editor with data EEPROM write buffer
	 # @return void
	proc __show_eeprom_write_buffer {} {
		variable actualProject			;# Object: Current project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable opened_eeprom_wr_bf_windows	;# List of project objects with opened data EEPROM write buffer editor
		variable eeprom_wr_bf_window_objects	;# List of data EEPROM write buffer hex editor objects
		variable eeprom_wr_buf_counter		;# Counter of EEPROM write buffer hex editor objects

		# Check if this function call is valid
		if {$project_menu_locked} {return}
		if {![lindex [$actualProject cget -procData] 32]} {
			return
		}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Check if the dialog is not already opened
		if {[lsearch -exact -ascii $opened_eeprom_wr_bf_windows $actualProject] != -1} {
			close_hexedit eeprom_wr_bf $actualProject
			set critical_procedure_in_progress 0
			return
		}

		# Create dialog window
		incr eeprom_wr_buf_counter
		set win [toplevel .eeprom_write_buffer_${eeprom_wr_buf_counter} -class {EEPROM} -bg ${::COMMON_BG_COLOR}]

		# Adjust NS variables
		lappend eeprom_wr_bf_window_objects	$win
		lappend opened_eeprom_wr_bf_windows	$actualProject

		# Create window header
		pack [label $win.header						\
			-text [mc "%s - EEPROM write buffer" $actualProject]	\
		] -fill x -pady 10

		# Create offset label
		set offset_frame [frame $win.offset_frame]
		pack [label $offset_frame.lbl					\
			-text [mc "OFFSET = "]					\
			-font [font create					\
				-size [expr {int(-17 * $::font_size_factor)}]	\
				-weight bold					\
				-family {helvetica}]				\
		] -side left
		pack [label $offset_frame.val					\
			-fg {#0000FF}						\
			-font [font create					\
				-size [expr {int(-17 * $::font_size_factor)}]	\
				-weight bold					\
				-family {helvetica}]				\
		] -side left
		pack $offset_frame -anchor w

		# Create middle frame (hexeditor)
		set hexeditor [HexEditor ::eeprom_write_buffer_${eeprom_wr_buf_counter}	\
			$win.mainframe 8 4 2 hex 1 0 4 32				\
		]
		$hexeditor showHideScrollbar 0
		$hexeditor bindCellValueChanged "$actualProject setEepromWrBufDEC"
		$hexeditor bindCellEnter "::X::eeprom_write_buffer_change_cursor_addr $win"
		$hexeditor bindCellLeave "::X::eeprom_write_buffer_change_cursor_addr $win {}"
		for {set i 0} {$i < 32} {incr i} {
			$hexeditor setValue $i [$actualProject getEepromWrBufDEC $i]
		}
		eeprom_write_buffer_set_offset [$actualProject getEepromWrOffsetDEC] $actualProject
		$hexeditor focus_left_view
		pack $win.mainframe

		# Create bottom frame
		set bottom_frame [frame $win.bottom_frame]
		pack [ttk::button $bottom_frame.close_but			\
			-text [mc "Close"]					\
			-compound left						\
			-image ::ICONS::16::button_cancel			\
			-command "X::close_hexedit eeprom_wr_bf $actualProject"	\
		] -side left -anchor w -padx 2 -pady 2
		pack [label $bottom_frame.cur_val				\
			-text {      } -fg {#0000FF}				\
			-font [font create					\
				-family $::DEFAULT_FIXED_FONT			\
				-size [expr {int(-12 * $::font_size_factor)}]	\
				-weight bold					\
			]				\
		] -side right -anchor e -padx 5
		pack [label $bottom_frame.cur_lbl	\
			-text [mc "Cursor: "]		\
		] -side right -anchor e
		pack $bottom_frame -side bottom -fill x

		# Configure dialog window
		wm iconphoto $win ::ICONS::16::kcmmemory
		wm title $win [mc "EEPROM write buffer - %s - MCU 8051 IDE" [$actualProject cget -projectName]]
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW	\
			"X::close_hexedit eeprom_wr_bf $actualProject"

		# Finalize
		set critical_procedure_in_progress 0

	}

	## Close hexadecimal editor window
	 # -- auxiliary procedure for '__show_ext_mem' and '__show_code_mem'
	 # @parm String type	- Editor type ('eeprom', 'eeprom_wr_bf' 'eram', 'code' or 'xdata')
	 # @parm Object project	- Project object descriptor
	 # @return void
	proc close_hexedit {type project} {
		variable opened_code_mem_windows	;# List of project object with opened CODE memory hex editor
		variable code_mem_window_objects	;# List of CODE memory hex editor objects
		variable opened_xdata_mem_windows	;# List of project object with opened XDATA memory hex editor
		variable xdata_mem_window_objects	;# List of XDATA memory hex editor objects
		variable opened_eram_windows		;# List of project object with opened ERAM hex editor
		variable eram_window_objects		;# List of ERAM hex editor objects
		variable opened_eeprom_mem_windows	;# List of project object with opened data EEPROM hex editor
		variable eeprom_mem_window_objects	;# List of data EEPROM hex editor objects
		variable opened_eeprom_wr_bf_windows	;# List of project objects with opened data EEPROM write buffer editor
		variable eeprom_wr_bf_window_objects	;# List of data EEPROM write buffer hex editor objects
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time

		# Close CODE memory editor
		if {$type == {code}} {
			set opened_windows_var	{opened_code_mem_windows}
			set window_objects_var	{code_mem_window_objects}
			set opened_windows	$opened_code_mem_windows
			set window_objects	$code_mem_window_objects

		# Close ERAM editor
		} elseif {$type == {eram}} {
			set opened_windows_var	{opened_eram_windows}
			set window_objects_var	{eram_window_objects}
			set opened_windows	$opened_eram_windows
			set window_objects	$eram_window_objects

		# Close XDATA memory editor
		} elseif {$type == {xdata}} {
			set opened_windows_var	{opened_xdata_mem_windows}
			set window_objects_var	{xdata_mem_window_objects}
			set opened_windows	$opened_xdata_mem_windows
			set window_objects	$xdata_mem_window_objects

		# Close data EEPROM editor
		} elseif {$type == {eeprom}} {
			set opened_windows_var	{opened_eeprom_mem_windows}
			set window_objects_var	{eeprom_mem_window_objects}
			set opened_windows	$opened_eeprom_mem_windows
			set window_objects	$eeprom_mem_window_objects

		# Close EEPROM write buffer
		} elseif {$type == {eeprom_wr_bf}} {
			set opened_windows_var	{opened_eeprom_wr_bf_windows}
			set window_objects_var	{eeprom_wr_bf_window_objects}
			set opened_windows	$opened_eeprom_wr_bf_windows
			set window_objects	$eeprom_wr_bf_window_objects

		# Close project independent hexadecimal editor
		} elseif {$type == {uni}} {
			return

		# Invalid request
		} else {
			return
		}


		# Determinate editor index
		set idx [lsearch -exact -ascii $opened_windows $project]
		if {$idx == -1} {return}
		# Destroy editor object
		if {$type == {eeprom_wr_bf}} {
			destroy [lindex $window_objects $idx]
		} else {
			delete object [lindex $window_objects $idx]
		}
		# Delete references
		set $opened_windows_var [lreplace $opened_windows $idx $idx]
		set $window_objects_var [lreplace $window_objects $idx $idx]
	}

	## Adjust main window title to current project and file
	 # @return void
	proc adjust_title {} {
		variable actualProject		;# Object: Current project
		set title {}			;# New title

		# Project opened
		if {$actualProject != {}} {
			# Gain data from the project
			if {[catch {
				if {[$actualProject editor_procedure {} cget -modified]} {
					append title {[modified] }
				}
				append title [$actualProject cget -projectName]
				append title { : }
				append title [$actualProject editor_procedure {} cget -filename]
				append title { - MCU 8051 IDE}
				wm title . $title

			# Error -- default title
			}]} then {
				wm title . ${::APPNAME}
			}

		# No project opened -- default title
		} else {
			wm title . ${::APPNAME}
		}
	}

	## Clear highlight for changed registers in simulator panels
	 # @return void
	proc __sim_clear_highlight {} {
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project
		variable actualProject			;# Object: Current project
		variable opened_xdata_mem_windows	;# List of project object with opened XDATA memory hex editor
		variable xdata_mem_window_objects	;# List of XDATA memory hex editor objects
		variable opened_eram_windows		;# List of project object with opened ERAM hex editor
		variable eram_window_objects		;# List of ERAM hex editor objects
		variable opened_eeprom_mem_windows	;# List of project object with opened data EEPROM hex editor
		variable eeprom_mem_window_objects	;# List of data EEPROM hex editor objects

		if {$project_menu_locked} {return}
		$actualProject simulator_clear_highlight
		$actualProject rightPanel_watch_clear_highlight
		$actualProject bitmap_clear_hg
		$actualProject sfrmap_clear_hg

		set idx [lsearch -exact -ascii $opened_xdata_mem_windows $actualProject]
		if {$idx != -1} {
			[lindex $xdata_mem_window_objects $idx] clear_highlight
		}
		set idx [lsearch -exact -ascii $opened_eram_windows $actualProject]
		if {$idx != -1} {
			[lindex $eram_window_objects $idx] clear_highlight
		}
		set idx [lsearch -exact -ascii $opened_eeprom_mem_windows $actualProject]
		if {$idx != -1} {
			[lindex $eeprom_mem_window_objects $idx] clear_highlight
		}
	}

	## Insure than simulator cursor is in editor visible area
	 # @return void
	proc __see_sim_cursor {} {
		variable actualProject		;# Object: Current project
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable simulator_enabled	;# List of booleans: Simulator engaged
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[lindex $simulator_enabled $actualProjectIdx] == 1} {
			$actualProject editor_procedure {} see_sim_cursor {}
		}
	}

	## Load value to PC in simulator control panel; line -> address
	 # @return void
	proc __simulator_set_PC_by_line {} {
		variable actualProject		;# Object: Current project
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable simulator_enabled	;# List of booleans: Simulator engaged
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		variable line2pc		;# Int: Selected line in source code
		variable line2pc_jump		;# Bool: Perform program jump (1) or subprogram call (0)
		variable line2pc_value_lbl	;# Widget: Label containing PC value
		variable line2pc_new_value	;# Int: Resolved address or {}
		variable line2pc_org_line	;# Int: Original line
		variable line2pc_line_max	;# Int: Number of lines in the source code
		variable line2pc_ok_button	;# Widget: Button "OK"
		variable line2pc_file_number	;# Int: File number

		if {$project_menu_locked} {return}

		# Check if simulator is started
		if {![lindex $simulator_enabled $actualProjectIdx]} {
			return
		}
		set filename [$actualProject editor_procedure {} cget -fullFileName]
		if {[lindex $filename 0] == {}} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Unable to comply"]	\
				-message [mc "This operation cannot be performed on an untitled file"]
			return
		}
		set line2pc_file_number [$actualProject simulator_get_filenumber $filename]
		if {$line2pc_file_number == -1} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Unable to comply"]	\
				-message [mc "This file does not contain any part of the running program"]
			return
		}

		# Load some NS variables
		set line2pc_line_max	[$actualProject editor_linescount]
		set line2pc_org_line	[lindex [$actualProject simulator_getCurrentLine] 0]
		set line2pc_new_value	[$actualProject simulator_line2address $line2pc_org_line $line2pc_file_number]
		set line2pc		$line2pc_org_line

		# Create dialog window
		set win [toplevel .goto_line2pc -class [mc "Goto dialog"] -bg ${::COMMON_BG_COLOR}]

		# Create window label frame
		label $win.header			\
			-text [mc "Line to address"]	\
			-image ::ICONS::16::goto	\
			-compound left

		# Create middle frame
		set middle_frame [frame $win.middle_frame]
		pack [label $middle_frame.left_lbl				\
			-text [mc "PC = "]					\
			-font [font create					\
				-size [expr {int(-16 * $::font_size_factor)}]	\
				-weight bold					\
				-family {helvetica}]				\
		] -side left
		set line2pc_value_lbl [label $middle_frame.right_lbl		\
			-font [font create					\
				-size [expr {int(-16 * $::font_size_factor)}]	\
				-weight bold					\
				-family {helvetica}]				\
		]
		pack $line2pc_value_lbl -side left
		set middle_right_frame [frame $middle_frame.right_frame]
		pack [radiobutton $middle_right_frame.jump_rabut	\
			-variable ::X::line2pc_jump			\
			-value 1 -text [mc "Program jump"]		\
		] -anchor w
		pack [radiobutton $middle_right_frame.call_rabut	\
			-variable ::X::line2pc_jump			\
			-value 0 -text [mc "Subprogram call"]		\
		] -anchor w
		pack $middle_right_frame -side right
		pack $middle_frame -padx 5 -fill x -pady 5

		# Create and pack 'OK' and 'CANCEL' buttons
		set buttonFrame [frame $win.buttonFrame]
		set line2pc_ok_button [ttk::button $buttonFrame.ok	\
			-text [mc "Ok"]					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {X::line2pc_OK}			\
		]
		pack $line2pc_ok_button -side left -padx 2
		pack [ttk::button $buttonFrame.cancel		\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command {X::line2pc_CANCEL}		\
		] -side left
		pack $buttonFrame -after $middle_frame -pady 5 -padx 2

		## Create top frame
		set topFrame [ttk::labelframe $win.topFrame -labelwidget $win.header -relief flat]
		pack $topFrame -expand 1 -fill x -before $middle_frame -padx 5 -pady 5
		 # Create scale widget
		pack [ttk::scale $topFrame.scale	\
			-from 1				\
			-to $line2pc_line_max		\
			-orient horizontal		\
			-variable ::X::line2pc		\
			-command "
				set ::X::line2pc \[expr {int(\${::X::line2pc})}\]
				::X::line2pc_validate \$::X::line2pc $topFrame.spinbox
				$topFrame.spinbox selection range 0 end
			#"	\
		] -side left -expand 1 -fill x -padx 2
		DynamicHelp::add $topFrame.scale	\
			-text [mc "Graphical representation of the line where to go"]
		 # Create spinbox widget
		pack [ttk::spinbox $topFrame.spinbox			\
			-from 1 -to $line2pc_line_max			\
			-textvariable ::X::line2pc			\
			-validate all					\
			-validatecommand {::X::line2pc_validate %P %W}	\
			-command  "::X::line2pc_validate \$::X::line2pc $topFrame.spinbox" \
			-width 4					\
		] -side left
		DynamicHelp::add $topFrame.spinbox -text [mc "Line where to go"]

		# Events binding (Enter == Ok, Esc == CANCEL)
		bind $win <KeyRelease-Return>	{X::line2pc_OK; break}
		bind $win <KeyRelease-KP_Enter>	{X::line2pc_OK; break}
		bind $win <KeyRelease-Escape>	{X::line2pc_CANCEL; break}

		# Focus on the Spinbox
		focus $topFrame.spinbox
		$topFrame.spinbox selection range 0 end

		# Nessesary window manager options -- modal window
		wm iconphoto $win ::ICONS::16::exec
		wm title $win [mc "Line to address"]
		wm minsize $win 380 140
		wm protocol $win WM_DELETE_WINDOW {
			X::line2pc_CANCEL
		}
		catch {grab $win}
		raise $win
		tkwait window $win
	}

	## Validate content od spinbox in dialog "Line to address"
	 # @parm String content - String to validate
	 # @return Bool - result
	proc line2pc_validate {content line2pc_spinbox} {
		variable actualProject		;# Object: Current project

		variable line2pc		;# Int: Selected line in source code
		variable line2pc_value_lbl	;# Widget: Label containing PC value
		variable line2pc_new_value	;# Int: Resolved address or {}
		variable line2pc_org_line	;# Int: Original line
		variable line2pc_line_max	;# Int: Number of lines in the source code
		variable line2pc_ok_button	;# Widget: Button "OK"
		variable line2pc_file_number	;# Int: File number

		if {$content == {}} {
			return 1
		}

		# Validate the given string
		set content [regsub {\..*$} $content {}]
		if {![string is digit $content] || ($content > $line2pc_line_max) || ($content < 0)} {
			catch {
				$line2pc_spinbox configure -style TSpinbox
			}
			return 0
		}

		# Try to determinate address in program memory
		set content [expr $content]
		set line2pc_new_value [$actualProject simulator_line2address $content $line2pc_file_number]

		# Fail
		if {$line2pc_new_value == {}} {
			# Adjust PC value label
			$line2pc_value_lbl configure	\
				-fg {#DD0000}		\
				-text [mc "Unable to resolve"]

			code_hex_editor_directly_move_program_pointer $actualProject -1
			$actualProject editor_procedure {} unset_simulator_line {}		;# Adjust editor
			$line2pc_ok_button configure -state disabled				;# Adjust Ok button
			catch {
				$line2pc_spinbox configure -style RedBg.TSpinbox		;# Adjust SpinBox
			}

		# Success
		} else {
			# Translate address to hexadecimal system
			set addr_in_hex [format %X $line2pc_new_value]
			set len [string length $addr_in_hex]
			if {$len < 4} {
				set addr_in_hex "[string repeat {0} [expr {4 - $len}]]$addr_in_hex"
			}
			$line2pc_value_lbl configure	\
				-fg {#00DD00}		\
				-text "0x$addr_in_hex"

			# Adjust editor
			code_hex_editor_directly_move_program_pointer $actualProject $line2pc_new_value
			$actualProject move_simulator_line [list $content $line2pc_file_number]
			$line2pc_ok_button configure -state normal			;# Adjust Ok button
			catch {
				$line2pc_spinbox configure -style GreenBg.TSpinbox	;# Adjust SpinBox
			}
		}
		return 1
	}

	## Safely close dialog "Line to address"
	 # @return void
	proc line2pc_safely_close {} {
		if {[winfo exists .goto_line2pc]} {
			grab release .goto_line2pc
			destroy .goto_line2pc
		}
	}

	## Cancel dialog "Line to address"
	 # @return void
	proc line2pc_CANCEL {} {
		variable line2pc_org_line	;# Int: Original line
		variable actualProject		;# Object: Current project

		if {$line2pc_org_line == {}} {
			$actualProject editor_procedure {} unset_simulator_line {}
		} else {
			$actualProject move_simulator_line $line2pc_org_line
		}
		code_hex_editor_directly_move_program_pointer $actualProject -1

		grab release .goto_line2pc
		destroy .goto_line2pc
	}

	## Confirm dialog "Line to address"
	 # @return void
	proc line2pc_OK {} {
		variable line2pc_new_value	;# Int: Resolved address or {}
		variable actualProject		;# Object: Current project
		variable line2pc_jump		;# Bool: Perform program jump (1) or subprogram call (0)
		variable line2pc		;# Int: Selected line in source code

		if {$line2pc_new_value == {}} {
			line2pc_CANCEL
			return
		}

		$actualProject move_simulator_line $line2pc
		if {$line2pc_jump} {
			$actualProject setPC $line2pc_new_value
		} else {
			$actualProject simulator_subprog_call $line2pc_new_value
		}
		code_hex_editor_directly_move_program_pointer $actualProject -1
		$actualProject Simulator_sync_PC_etc

		grab release .goto_line2pc
		destroy .goto_line2pc
	}

	## Switch to the previous editor in the current project (from editor statusbar popup menu)
	 # @return void
	proc __prev_editor_from_pmenu {} {
		variable actualProject			;# Object: Current project
		variable selectedView			;# Object: Selected editor view
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Switch editor
		$actualProject filelist_editor_selected $selectedView
		$actualProject prev_editor

		# Finalize
		set critical_procedure_in_progress 0
	}

	## Switch to the next editor in the current project (from editor statusbar popup menu)
	 # @return void
	proc __next_editor_from_pmenu {} {
		variable actualProject			;# Object: Current project
		variable selectedView			;# Object: Selected editor view
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Switch editor
		$actualProject filelist_editor_selected $selectedView
		$actualProject next_editor

		# Finalize
		set critical_procedure_in_progress 0
	}

	## Switch to editor command line
	 # @return void
	proc __switch_to_cmd_line {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		$actualProject cmd_line_on
	}

	## Split editor vertical
	 # @return void
	proc __split_vertical {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		$actualProject split_vertical
	}

	## Split editor horizontal
	 # @return void
	proc __split_horizontal {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		$actualProject split_horizontal
	}

	## Close current view (editor) from editor statusbar popup menu
	 # @return void
	proc __close_current_view_from_pmenu {} {
		variable selectedView		;# Object: Selected editor view
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		$actualProject close_current_view $selectedView
	}

	## Close current view (editor)
	 # @return void
	proc __close_current_view {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		$actualProject close_current_view {}
	}

	## Enable / Disable stepback controls
	 # @parm Bool bool - 1 == enable; 0 == disable
	 # @return void
	proc stepback_button_set_ena {bool} {
		variable actualProject	;# Object: Current project

		if {$bool != 0} {
			set boot 1
		}
		$actualProject stepback_button_set_ena $bool
		ena_dis_menu_buttons $bool {{{.mainMenu.simulator} {{Step back}}}}
		ena_dis_iconBar_buttons	$bool	.mainIconBar. {stepback}
	}

	## Hibernate running program to a file
	 # This function also invokes file selection dialog to select target file.
	 # @return void
	proc __hibernate {} {
		hibernate_or_resume 1
	}

	## Resume hibernated program
	 # This function also invokes file selection dialog to select source file.
	 # @return void
	proc __resume {} {
		hibernate_or_resume 0
	}

	## Hibernate running program // Resume hibernated program
	 # @parm Bool hib_res - 1 == Hiberanate; 0 == Resume
	 # @return void
	proc hibernate_or_resume {hib_res} {
		variable actualProject		;# Object: Current project
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable simulator_enabled	;# List of booleans: Simulator engaged
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time

		# Simulator must be engaged for this function
		if {$project_menu_locked} {return}
		if {![lindex $simulator_enabled $actualProjectIdx]} {
			return
		}

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		set sourcefile [list					\
			[$actualProject cget -projectPath]		\
			[$actualProject cget -P_option_main_file]	\
		]
		if {[lindex $sourcefile 1] == {}} {
			set sourcefile [$actualProject editor_procedure {} getFileName {}]
		}
		set sourcefile [file join [lindex $sourcefile 0] [lindex $sourcefile 1]]
		set initialfile [file rootname [file tail $sourcefile]]
		if {$hib_res} {
			set title [mc "Hibernate running program - MCU 8051 IDE"]
			set cmd {__hibernate_to}
		} else {
			set title [mc "Resume hibernated program - MCU 8051 IDE"]
			set cmd {__resume_from}
		}

		# Invoke file selection dialog
		catch {delete object fsd}
		KIFSD::FSD fsd	 					\
			-title $title -initialfile $initialfile		\
			-directory [$actualProject cget -projectPath]	\
			-defaultmask 0 -multiple 0 -filetypes [list					\
				[list [mc "MCU 8051 IDE hibernated program"]	{*.m5ihib}	]	\
				[list [mc "All files"]				{*}		]	\
			]

		# Open file after press of OK button
		fsd setokcmd "
			::X::fsd deactivate
			::X::$cmd \[X::fsd get\] {$sourcefile}
		"

		# Activate FSD
		fsd activate

		# Finalize
		set critical_procedure_in_progress 0
	}

	## Hibernate running program to the given file
	 # @parm String filename	- Target file
	 # @parm String sourcefile	- Source file
	 # @return void
	proc __hibernate_to {filename sourcefile} {
		variable actualProject		;# Object: Current project
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable simulator_enabled	;# List of booleans: Simulator engaged
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		# Simulator must be engaged for this function
		if {$project_menu_locked} {return}
		if {![lindex $simulator_enabled $actualProjectIdx]} {
			return
		}

		# Adjust the given name of the target file
		if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
			if {![regexp "^(~|/)" $filename]} {
			set filename "[${::X::actualProject} cget -ProjectDir]/$filename"
			}
		} else {	;# Microsoft windows way
			if {![regexp {^\w:} $filename]} {
				set filename [file join [${::X::actualProject} cget -ProjectDir] $filename]
			}
		}
		if {[file extension $filename] == {}} {
			append filename {.m5ihib}
		}
		set filename [file normalize $filename]

		# Create backup copy the target file
		if {[file exists $filename] && [file isfile $filename]} {
			# Ask user for overwrite existing file
			if {[tk_messageBox	\
				-type yesno	\
				-icon question	\
				-parent .	\
				-title [mc "Overwrite file"]	\
				-message [mc "A file name '%s' already exists. Are you sure you want to overwrite it ?" [file tail $filename]]
				] != {yes}
			} then {
				return
			}
			# Create a backup file
			catch {
				file rename -force $filename "$filename~"
			}
		}

		# Hibernate running program
		set sourcefile_md5 {}
		catch {
			set sourcefile_md5 [::md5::md5 -hex -file $sourcefile]
		}
		if {![$actualProject hibernate_hibernate			\
			$filename [file tail $sourcefile] $sourcefile_md5 0	\
		]} then {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Hibernation failed"]	\
				-message [mc "Unable to write to file:\n%s\nCheck your permissions." $filename]
		}
	}

	## Resume hibernated program
	 # @parm String filename	- Hibernation file
	 # @parm String sourcefile	- Name of file from which the hibernation file was generated
	 # @return void
	proc __resume_from {filename sourcefile} {
		variable actualProject		;# Object: Current project
		variable actualProjectIdx	;# Index of the current project in $openedProjects
		variable simulator_enabled	;# List of booleans: Simulator engaged
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		# Simulator must be engaged for this function
		if {$project_menu_locked} {return}
		if {![lindex $simulator_enabled $actualProjectIdx]} {
			return
		}

		# Adjust the given name of the target file
		if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
			if {![regexp "^(~|/)" $filename]} {
			set filename "[${::X::actualProject} cget -ProjectDir]/$filename"
			}
		} else {	;# Microsoft windows way
			if {![regexp {^\w:} $filename]} {
				set filename [file join [${::X::actualProject} cget -ProjectDir] $filename]
			}
		}
		set filename [file normalize $filename]

		# Resume hibernated program
		set result [$actualProject hibernate_resume $filename 0]

		# ERROR: Cannot open the specified file
		if {$result == 1} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Resumption failed"]	\
				-message [mc "Unable to read file:\n%s\nCheck your permissions." $filename]

		# ERROR: Cannot parse the specified file
		} elseif {$result == 2} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Resumption failed"]	\
				-message [mc "This hibernation is corrupted or it is not MCU 8051 IDE M5IHIB file."]
		}
	}

	## Invoke interrupt monitor window
	 # @parm Object project_object=actualProject - Project
	 # @return void
	proc __interrupt_monitor args {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[string length $args]} {
			$args interrupt_monitor_invoke_dialog
		} else {
			$actualProject interrupt_monitor_invoke_dialog
		}
	}

	## Invoke UART monitor window
	 # @return void
	proc __uart_monitor args {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		$actualProject uart_monitor_invoke_dialog
	}

	## Invoke stack monitor window
	 # @parm Object project_object=actualProject - Project
	 # @return void
	proc __stack_monitor args {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {[string length $args]} {
			$args stack_monitor_invoke_dialog
		} else {
			$actualProject stack_monitor_invoke_dialog
		}
	}

	## Invoke SFR map window
	 # @return void
	proc __sfr_map {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		$actualProject sfrmap_invoke_dialog
	}

	## Show bit adrea
	 # @return void
	proc __bitmap {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		$actualProject bitmap_invoke_dialog
	}

	## Adjust application language to variable ::GLOBAL_CONFIG(language)
	 # @return void
	proc switch_language {} {
		# ${::GLOBAL_CONFIG(language)}
	}

	## Set syntax highlight for current editor
	 # @param Int highlight_num -  -1 == None; 0 == Assembler; 1 == ISO C; 2 == Assembler code listing
	 # @return void
	proc __set_highlight {highlight_num} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		$actualProject editor_procedure {} force_language $highlight_num
	}

	## Highlight parrern for the current editor has been changed
	 # @return void
	proc highlight_pattern_changed {} {
		__set_highlight $::editor_SH
	}

	## Invoke independent hexadecimal editor
	 # @return Object - Hex editor object reference
	proc __hexeditor {} {
		variable independent_hexeditor_count	;# Counter of intances of independent hexadecimal editor
		incr independent_hexeditor_count

		return [HexEditDlg ::independent_hexeditor_$independent_hexeditor_count {} uni]
	}

	## Document current function in editor
	 # @return void
	proc __document_current_func {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		$actualProject editor_procedure {} document_current_func {}
	}

	## Create doxygen configuration file if it does not already exist
	 # @return void
	proc create_doxyfile {} {
		variable doxygen_pid			;# Int: Doxygen PID
		variable compilation_in_progress	;# Bool: Compiler engaged
		variable actualProject			;# Object: Current project

		if {$compilation_in_progress} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Unable to comply"]	\
				-message [mc "Something is already running in background."]
			return
		}

		set compilation_in_progress 1
		make_progressBar_on_Sbar

		if {[catch {
			set path [$actualProject cget -projectPath]
			if {$::MICROSOFT_WINDOWS} {
				regsub -all {/} $path "\\" path
			}
			$actualProject messages_text_append "\ncd $path\n"
			cd [$actualProject cget -projectPath]
		}]} then {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Permission denied"]	\
				-message [mc "Unable to change directory to '%s'." [$actualProject cget -projectPath]]
			return
		}
		if {!$::MICROSOFT_WINDOWS} {
			if {![file exists Doxyfile]} {
				$actualProject messages_text_append "doxygen -g Doxyfile\n"
				set doxygen_pid [exec --						\
					doxygen -g Doxyfile && doxygen -u Doxyfile |&			\
					tclsh ${::LIB_DIRNAME}/external_command.tcl [tk appname]	\
					::X::doxygen_finish ::X::doxygen_message &			\
				]
			} else {
				$actualProject messages_text_append "doxygen -u Doxyfile\n"
				set doxygen_pid [exec --					\
					doxygen -u Doxyfile |& tclsh				\
					${::LIB_DIRNAME}/external_command.tcl [tk appname]	\
					::X::doxygen_finish ::X::doxygen_message &		\
				]
			}
		} else {
			if {![file exists Doxyfile]} {
				$actualProject messages_text_append "doxygen -g Doxyfile\n"
				set doxygen_pid [exec --				\
					doxygen -g Doxyfile && doxygen -u Doxyfile	\
						|&					\
					"${::INSTALLATION_DIR}/external_command.bat"	\
					"${::INSTALLATION_DIR}/external_command.exe"	\
					"[tk appname]"					\
					::X::doxygen_finish ::X::doxygen_message &	\
				]
			} else {
				$actualProject messages_text_append "doxygen -u Doxyfile\n"
				set doxygen_pid [exec --				\
					doxygen -u Doxyfile				\
						|&					\
					"${::INSTALLATION_DIR}/external_command.bat"	\
					"${::INSTALLATION_DIR}/external_command.exe"	\
					"[tk appname]"					\
					::X::doxygen_finish ::X::doxygen_message &	\
				]
			}

		}
	}

	## Handle end of doxygen text output
	 # @return void
	proc doxygen_finish {} {
		variable actualProject			;# Object: Current project
		variable doxygen_run_doxywizard		;# Bool: Run doxywizard
		variable doxygen_build_api_doc		;# Bool: Build API documentation
		variable doxygen_pid			;# Int: Doxygen PID
		variable compilation_in_progress	;# Bool: Compiler engaged

		if {$doxygen_run_doxywizard} {
			exec -- doxywizard Doxyfile &
		} elseif {$doxygen_build_api_doc} {
			set doxygen_build_api_doc 0
			if {[catch {
				cd [$actualProject cget -projectPath]
			}]} then {
				$actualProject messages_text_append [mc "\nUnable to change directory to '%s'\n" [$actualProject cget -projectPath]]
				destroy_progressBar_on_Sbar
				set compilation_in_progress 0
				set doxygen_pid 0
				return
			}

			$actualProject messages_text_append "\ndoxygen Doxyfile\n"
			set doxygen_pid [exec --					\
				doxygen Doxyfile |& tclsh				\
				${::LIB_DIRNAME}/external_command.tcl [tk appname]	\
				::X::doxygen_finish ::X::doxygen_message &		\
			]
		}

		destroy_progressBar_on_Sbar
		set compilation_in_progress 0
		set doxygen_pid 0
	}

	## Handle text output doxygen
	 # @parm String text - Output from external compiler
	 # @return void
	proc doxygen_message args {
		variable doxygen_mess_project	;# Object: Project related to running doxygen compilation
		$doxygen_mess_project messages_text_append \
			[string replace [regsub -all "\\\{" [regsub -all "\\\}" [lindex $args 0] "\}"] "\{"] 0 0]
	}

	## Build C API documentation
	 # @return void
	proc __generate_documentation {} {
		variable doxygen_mess_project		;# Object: Project related to running doxygen compilation
		variable doxygen_build_api_doc		;# Bool: Build API documentation
		variable doxygen_pid			;# Int: Doxygen PID
		variable compilation_in_progress	;# Bool: Compiler engaged
		variable actualProject			;# Object: Current project
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {$compilation_in_progress} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Unable to comply"]	\
				-message [mc "Something is already running in background."]
			return
		}
		set doxygen_mess_project $actualProject
		set doxygen_build_api_doc 1
		if {!$::PROGRAM_AVAILABLE(doxygen)} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Unable to find Doxygen"]	\
				-message [mc "Unable to find Doxygen. Please install doxygen and restart MCU 8051 IDE."]
			return
		}
		$actualProject bottomNB_show_up {Messages}
		create_doxyfile
	}

	## Run doxygen graphical front-end
	 # @return void
	proc __run_doxywizard {} {
		variable doxygen_mess_project		;# Object: Project related to running doxygen compilation
		variable doxygen_run_doxywizard		;# Bool: Run doxywizard
		variable actualProject			;# Object: Current project
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		if {!$::PROGRAM_AVAILABLE(doxywizard)} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Unable to find doxywizard"]	\
				-message [mc "Unable to find doxywizard. Please install doxygen and restart MCU 8051 IDE."]
			return
		}
		set doxygen_run_doxywizard 1
		set doxygen_mess_project $actualProject
		create_doxyfile
	}

	## Remove doxygen documentation
	 # @return void
	proc __clear_documentation {} {
		variable actualProject			;# Object: Current project
		variable doxygen_mess_project		;# Object: Project related to running doxygen compilation
		variable compilation_in_progress	;# Bool: Compiler engaged
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}
		set doxygen_mess_project $actualProject
		if {[catch {
			cd [$actualProject cget -projectPath]
		}]} then {
			$actualProject messages_text_append [mc "\nError: Unable to change directory to '%s'\n" [$actualProject cget -projectPath]]
			return
		}

		$actualProject bottomNB_show_up {Messages}
		$actualProject messages_text_append "\nrm -rfv html/* && rm -rfv latex/* && rm -rfv xml/*\n"
		catch {exec -- /bin/sh <<						\
			"rm -rfv html/* && rm -rfv latex/* && rm -rfv xml/*" |&		\
			tclsh ${::LIB_DIRNAME}/external_command.tcl [tk appname]	\
			::X::doxygen_message ::X::doxygen_message &			\
		}
	}

	## Display file statistic for the current file
	 # @return void
	proc __statistics {} {
		variable actualProject			;# Object: Current project
		variable statistics_counter		;# Int: Counter of invocations of this dialog
		variable project_menu_locked		;# Bool: Indicates than there is at least one opened project

		# Check if this procedure can be run
		if {$project_menu_locked} {return}
		if {${::Editor::editor_to_use}} {
			tk_messageBox		\
				-parent .	\
				-icon warning	\
				-type ok	\
				-title [mc "Unable to comply"]	\
				-message [mc "Unable to gain file statistics while external editor is used"]
			return
		}

		# Create dialog window (not modal)
		incr statistics_counter
		set win [toplevel .statistics$statistics_counter -class {File statistics} -bg ${::COMMON_BG_COLOR}]

		# Local variables
		set bold_font	[font create -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight bold]
		set normal_font	[font create -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight normal]
		set header_font [font create -family {helvetica} -size [expr {int(-20 * $::font_size_factor)}] -weight normal]
		set statistics	[$actualProject editor_procedure {} getFileStatistics {}]

		# Create window header
		set dialog_header [label $win.dialog_header	\
			-width 25 -font $header_font		\
			-text [lindex [$actualProject editor_procedure {} getFileName {}] 1]	\
		]

		set main_frame [frame $win.main_frame]
		 # Header: "Characters"
		grid [label $main_frame.characters_lbl -pady 0	\
			-text [mc "Characters"] -font $bold_font	\
		] -row 0 -column 0 -columnspan 3 -sticky w
		 # - Words and numbers
		grid [Label $main_frame.c_words_name_lbl	\
			-text [mc "Words and numbers:"]		\
			-font $normal_font -pady 0		\
			-helptext [mc "Alphanumeric characters and connector punctuation characters"] \
		] -row 1 -column 1 -sticky w
		grid [label $main_frame.c_words_value_lbl	\
			-text [lindex $statistics 0]		\
			-font $normal_font -pady 0		\
		] -row 1 -column 2 -sticky e
		 # - Comments
		grid [Label $main_frame.c_comments_name_lbl	\
			-text [mc "Comments:"]			\
			-font $normal_font -pady 0		\
			-helptext [mc "Characters highlighted as comments"]	\
		] -row 2 -column 1 -sticky w
		grid [label $main_frame.c_comments_value_lbl	\
			-text [lindex $statistics 1]		\
			-font $normal_font -pady 0		\
		] -row 2 -column 2 -sticky e
		 # - Other characters
		grid [Label $main_frame.c_other_name_lbl	\
			-text [mc "Other characters:"]		\
			-font $normal_font -pady 0		\
			-helptext [mc "All other characters without EOLs (e.g. spaces and brackets)"] \
		] -row 3 -column 1 -sticky w
		grid [label $main_frame.c_other_value_lbl	\
			-text [lindex $statistics 2]		\
			-font $normal_font -pady 0		\
		] -row 3 -column 2 -sticky e
		 # Separator
		grid [ttk::separator $main_frame.sep_0	\
			-orient horizontal		\
		] -row 4 -column 2 -sticky we
		 # - Total characters
		grid [Label $main_frame.c_total_name_lbl	\
			-text [mc "Total characters:"]		\
			-font $normal_font -pady 0		\
			-helptext [mc "All characters in the text without EOLs"] \
		] -row 5 -column 1 -sticky w
		grid [label $main_frame.c_total_value_lbl	\
			-text [lindex $statistics 3]		\
			-font $normal_font -pady 0		\
		] -row 5 -column 2 -sticky e
		 # Header: "Strings"
		grid [label $main_frame.strings_lbl -pady 0	\
			-text [mc "Strings"] -font $bold_font	\
		] -row 7 -column 0 -columnspan 3 -sticky w
		 # - Words
		grid [Label $main_frame.s_words_name_lbl	\
			-text [mc "Words:"]			\
			-font $normal_font -pady 0		\
			-helptext [mc "Just normal words (not keywords and not comments)"]	\
		] -row 8 -column 1 -sticky w
		grid [label $main_frame.s_words_value_lbl	\
			-text [lindex $statistics 4]		\
			-font $normal_font -pady 0		\
		] -row 8 -column 2 -sticky e
		 # - Keywords
		grid [Label $main_frame.s_keywords_name_lbl	\
			-text [mc "Keywords:"]			\
			-font $normal_font -pady 0		\
			-helptext [mc "Instructions, Assembler directives, C directives, C keywords"]	\
		] -row 9 -column 1 -sticky w
		grid [label $main_frame.s_keywords_value_lbl	\
			-text [lindex $statistics 5]		\
			-font $normal_font -pady 0		\
		] -row 9 -column 2 -sticky e
		 # - Comments
		grid [Label $main_frame.s_comments_name_lbl	\
			-text [mc "Comments:"]			\
			-font $normal_font -pady 0		\
			-helptext [mc "Words in comments"]	\
		] -row 10 -column 1 -sticky w
		grid [label $main_frame.s_comments_value_lbl	\
			-text [lindex $statistics 6]		\
			-font $normal_font -pady 0		\
		] -row 10 -column 2 -sticky e
		 # Separator
		grid [ttk::separator $main_frame.sep_1	\
			-orient horizontal		\
		] -row 11 -column 2 -sticky we
		 # - Total strings
		grid [Label $main_frame.s_total_name_lbl	\
			-text [mc "Total strings:"]		\
			-font $normal_font -pady 0		\
			-helptext [mc "Total number of words in the text"]	\
		] -row 12 -column 1 -sticky w
		grid [label $main_frame.s_total_value_lbl	\
			-text [lindex $statistics 7]		\
			-font $normal_font -pady 0		\
		] -row 12 -column 2 -sticky e
		 # Header: "Lines"
		grid [label $main_frame.lines_lbl	\
			-text [mc "Lines"]		\
			-font $bold_font -pady 0	\
		] -row 14 -column 0 -columnspan 3 -sticky w
		 # - Empty lines
		grid [Label $main_frame.l_empty_name_lbl	\
			-text [mc "Empty lines:"]		\
			-font $normal_font -pady 0		\
			-helptext [mc "Totally empty lines (without even spaces)"]	\
		] -row 15 -column 1 -sticky w
		grid [label $main_frame.l_empty_value_lbl	\
			-text [lindex $statistics 8]		\
			-font $normal_font -pady 0		\
		] -row 15 -column 2 -sticky e
		 # - Commented lines
		grid [Label $main_frame.l_commented_name_lbl	\
			-text [mc "Commented lines:"]		\
			-font $normal_font -pady 0		\
			-helptext [mc "Lines which are all commented"]	\
		] -row 16 -column 1 -sticky w
		grid [label $main_frame.l_commented_value_lbl	\
			-text [lindex $statistics 9]		\
			-font $normal_font -pady 0		\
		] -row 16 -column 2 -sticky e
		 # - Normal lines
		grid [Label $main_frame.l_normal_name_lbl	\
			-text [mc "Normal lines:"]		\
			-font $normal_font -pady 0		\
			-helptext [mc "Just normal code lines"]	\
		] -row 17 -column 1 -sticky w
		grid [label $main_frame.l_normal_value_lbl	\
			-text [lindex $statistics 10]		\
			-font $normal_font -pady 0		\
		] -row 17 -column 2 -sticky e
		 # Separator
		grid [ttk::separator $main_frame.sep_2	\
			-orient horizontal		\
		] -row 18 -column 2 -sticky we
		 # - Total lines
		grid [Label $main_frame.l_total_name_lbl	\
			-text [mc "Total lines:"]		\
			-font $normal_font -pady 0		\
			-helptext [mc "Total number of lines in the text"]	\
		] -row 19 -column 1 -sticky w
		grid [label $main_frame.l_total_value_lbl	\
			-text [lindex $statistics 11]		\
			-font $normal_font -pady 0		\
		] -row 19 -column 2 -sticky e

		# Configure main frame
		grid columnconfigure	$main_frame 0 -minsize 25
		grid columnconfigure	$main_frame 1 -weight 1
		grid rowconfigure	$main_frame 6 -minsize 10
		grid rowconfigure	$main_frame 13 -minsize 10

		# Create and pack 'COPY' and 'OK' buttons
		set button_frame [frame $win.button_frame]
		pack [ttk::button $button_frame.ok	\
			-text [mc "Ok"]			\
			-compound left			\
			-image ::ICONS::16::ok		\
			-command "X::statistics_close $statistics_counter"	\
		] -side right -padx 2
		pack [ttk::button $button_frame.copy		\
			-text [mc "Copy"]			\
			-compound left				\
			-image ::ICONS::16::editcopy		\
			-command "X::statistics_copy $statistics_counter"	\
		] -side left -padx 2

		# Pack dialog frames
		pack $dialog_header	-side top	-fill x -pady 5
		pack $main_frame	-side top	-anchor nw -fill x -pady 15 -padx 10
		pack $button_frame	-side bottom	-anchor se -pady 5 -padx 5

		# Set window manager options
		wm iconphoto $win ::ICONS::16::graph
		wm title $win [mc "File statistics - MCU 8051 IDE"]
		wm minsize $win 250 400
		wm transient $win .
		wm protocol $win WM_DELETE_WINDOW "X::statistics_close $statistics_counter"
		update
		focus $button_frame.ok
		raise $win
	}

	## Close dialog "File statistics"
	 # @parm Int dialog_number -
	 # @return void
	proc statistics_close {dialog_number} {
		variable statistics_counter	;# Int: Counter of invocations of this dialog
		if {![winfo exists .statistics$statistics_counter]} {return}
		destroy .statistics$statistics_counter
	}

	## Copy contents of file statistics dialog to the clipboard
	 # @parm Int dialog_number -
	 # @return void
	proc statistics_copy {dialog_number} {
		variable statistics_counter	;# Int: Counter of invocations of this dialog
		if {![winfo exists .statistics$statistics_counter]} {return}

		set win .statistics$statistics_counter
		set main_frame $win.main_frame

		clipboard clear
		clipboard append [mc "Statistics for: %s\n\n" [$win.dialog_header cget -text]]
		clipboard append [mc "Characters:\n"]
		clipboard append [mc "  Words and numbers:\t\t%s\n" [$main_frame.c_words_value_lbl cget -text]]
		clipboard append [mc "  Comments:\t\t\t%s\n" [$main_frame.c_comments_value_lbl cget -text]]
		clipboard append [mc "  Other characters:\t\t%s\n" [$main_frame.c_other_value_lbl cget -text]]
		clipboard append [mc "  				------\n"]
		clipboard append [mc "  Total characters:\t\t%s\n\n" [$main_frame.c_total_value_lbl cget -text]]
		clipboard append [mc "Strings:\n"]
		clipboard append [mc "  Words:\t\t\t%s\n" [$main_frame.s_words_value_lbl cget -text]]
		clipboard append [mc "  Keywords:\t\t\t%s\n" [$main_frame.s_keywords_value_lbl cget -text]]
		clipboard append [mc "  Comments:\t\t\t%s\n" [$main_frame.s_comments_value_lbl cget -text]]
		clipboard append [mc "  				------\n"]
		clipboard append [mc "  Total strings:\t\t%s\n" [$main_frame.s_total_value_lbl cget -text]]
		clipboard append [mc "Lines:\n"]
		clipboard append [mc "  Empty lines:\t\t\t%s\n" [$main_frame.l_empty_value_lbl cget -text]]
		clipboard append [mc "  Commented lines:\t\t%s\n" [$main_frame.l_commented_value_lbl cget -text]]
		clipboard append [mc "  Normal lines:\t\t\t%s\n" [$main_frame.l_normal_value_lbl cget -text]]
		clipboard append [mc "  				------\n"]
		clipboard append [mc "  Total lines:\t\t\t%s\n" [$main_frame.l_total_value_lbl cget -text]]
	}

	## Modify main menu and main toolbar according to configuration of the current editor
	 # @parm Bool read_only		- 1 == Read only; 	0 == Normal mode;	{} == Do not change
	 # @parm Bool c_language	- 1 == Uses C language;	0 == Uses Assembler;	{} == Do not change
	 # @return void
	proc adjust_mainmenu_and_toolbar_to_editor {read_only c_language} {
		variable mainmenu_editor_readonly	;# Menu bar items which are not available when editor is in read only mode
		variable toolbar_editor_readonly	;# Tool bar items which are not available when editor is in read only mode
		variable mainmenu_editor_c_only		;# Menu bar items which are not available only for C language
		variable toolbar_editor_c_only		;# Toolbar items which are not available only for C language

		# Read only flag
		if {$read_only != {}} {
			set read_only [expr {!$read_only}]
			ena_dis_menu_buttons	$read_only $mainmenu_editor_readonly
			ena_dis_iconBar_buttons	$read_only .mainIconBar. $toolbar_editor_readonly
		}

		# C language
		if {$c_language != {}} {
			ena_dis_menu_buttons	$c_language $mainmenu_editor_c_only
			ena_dis_iconBar_buttons	$c_language .mainIconBar. $toolbar_editor_c_only
		}
	}

	## Conditionaly disable menu and toolbar items which
	 #+ are not available when external editor used
	 # @return void
	proc adjust_mm_and_tb_ext_editor {} {
		variable mainmenu_editor_external_na	;# Menu bar items which are not available when external embedded editor is used
		variable toolbar_editor_external_na	;# Toolbar items which are not available when external embedded editor is used

		if {!${::Editor::editor_to_use}} {
			return
		}

		ena_dis_menu_buttons	0 $mainmenu_editor_external_na
		ena_dis_iconBar_buttons	0 .mainIconBar. $toolbar_editor_external_na
	}

	## Invoke assembly language symbols viewer
	 # @return void
	proc __symb_view {} {
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project
		variable actualProject		;# Object: Current project

		# Open dialog window
		set obj [SymbolViewer #auto]

		# Try to load some file into the viewer
		if {!$project_menu_locked} {
			set file [$actualProject cget -P_option_main_file]
			if {$file == {}} {
				set file [$actualProject editor_procedure {} getFileName {}]
				set file [file join [lindex $file 0] [lindex $file 1]]
			}
			if {$file != {}} {
				$obj open_file 1 [file rootname $file].lst
			}
		}
	}

	## Invoke 8-Segment LED display editor
	 # @return void
	proc __eightsegment {} {
		variable eightsegment_editors	;# List: All 8-Segment LED display editors invoked

		lappend eightsegment_editors [EightSegment #auto]
	}

	## Invoke ASCII chart
	 # @return void
	proc __ascii_chart {} {
		variable ascii_chart_win_object	;# Object: ASCII chart window object
		if {$ascii_chart_win_object != {}} {
			if {[$ascii_chart_win_object is_visible]} {
				$ascii_chart_win_object raise_window
			} else {
				$ascii_chart_win_object restore_window
			}
		} else {
			set ascii_chart_win_object [AsciiChart #auto]
		}
	}

	## Switch editor to block selection mode
	 # @return void
	proc __block_selection_mode {} {
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project
		variable actualProject		;# Object: Current project

		if {$project_menu_locked} {return}
		$actualProject editor_procedure {} switch_sel_mode {}
	}

	## Invoke stopwatch timer window
	 # @return void
	proc __stopwatch_timer {} {
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project
		variable actualProject		;# Object: Current project

		if {$project_menu_locked} {return}
		$actualProject stopwatch_invoke_dialog
	}

	## Referesh contents of menu "Open recent"
	 # @param Int what
	 #	0 - Recent project files
	 #	1 - Recent source code files
	 #	2 - Recent Virtual HW files
	 # @return void
	proc refresh_recent_files {what} {
		variable file_recent_files	;# List: recently opened files
		variable project_recent_files	;# List: recently opened projects
		variable vhw_recent_files	;# List: recently opened Virtual HW files

		# Refresh "Recent Virtual HW files"
		if {$what == 2} {
			# Clean up the menu
			.mainMenu.virtual_hw.open_recent delete 0 end
			.mainMenu.virtual_hw.load_recent delete 0 end
			# Interate over recently opened files and add them to the menu
			foreach file $vhw_recent_files {
				.mainMenu.virtual_hw.open_recent add command	\
					-label $file -command [list ::X::open_recent 2 $file]
				.mainMenu.virtual_hw.load_recent add command	\
					-label $file -command [list ::X::open_recent -2 $file]
			}

		# Refresh "Recent source code file"
		} elseif {$what == 1} {
			# Clean up the menu
			.mainMenu.file.open_recent delete 0 end

			# Interate over recently opened files and add them to the menu
			foreach file $file_recent_files {

				# Determinate file type and appropriate icon
				set ext [string trimleft [file extension $file] {.}]
				if {$ext == {c}} {
					set img {source_c}
				} elseif {$ext == {h}} {
					set img {source_h}
				} elseif {$ext == {cxx} || $ext == {cpp} || $ext == {cc}} {
					set img {source_cpp}
				} elseif {$ext == {lst}} {
					set img {ascii}
				} elseif {$ext == {asm}} {
					set img {asm}
				} else {
					set img {ascii}
				}

				# Create a new menu entry
				.mainMenu.file.open_recent add command		\
					-label $file -compound left -image ::ICONS::16::$img	\
					-command [list ::X::open_recent $what $file]
			}

		# Refresh "Recent project file"
		} elseif {$what == 0} {
			# Clean up the menu
			.mainMenu.project.open_recent delete 0 end
			# Interate over recently opened files and add them to the menu
			foreach file $project_recent_files {
				.mainMenu.project.open_recent add command	\
					-label $file -command [list ::X::open_recent $what $file]
			}
		}


	}

	## Open recent file
	 # @param Int what
	 #	0 - Recent project files
	 #	1 - Recent source code files
	 #	2 - Recent Virtual HW files (OPEN)
	 #	-2 - Recent Virtual HW files (LOAD)
	 # @param String filename	- Name of file to open
	 # @return void
	proc open_recent {what filename} {
		variable critical_procedure_in_progress	;# Bool: Disable critical procedures (like compilation, start simulator, etc.)
		variable actualProject			;# Object: Current project
		variable openedProjects			;# List of opened projects (Object references)
		variable vhw_recent_files		;# List: recently opened Virtual HW files

		# This function is critical
		if {$critical_procedure_in_progress} {return}
		set critical_procedure_in_progress 1

		# Open "Recent Virtual HW file"
		if {$what == 2} {
			if {[$actualProject pale_open_scenario $filename]} {
				tk_messageBox		\
					-parent .	\
					-type ok	\
					-icon error	\
					-title [mc "IO Error"]	\
					-message [mc "Unable to read file:\n\"%s\"" $filename]
			}

		# Load "Recent Virtual HW file"
		} elseif {$what == -2} {
			if {[$actualProject pale_load_scenarion $filename]} {
				tk_messageBox		\
					-parent .	\
					-type ok	\
					-icon error	\
					-title [mc "IO Error"]	\
					-message [mc "Unable to read file:\n\"%s\"" $filename]
			}

		# Open "Recent source code file"
		} elseif {$what == 1} {
			# If there is no project opened -> invalid function call -> abort
			if {![llength $openedProjects]} {
			set critical_procedure_in_progress 0
				return
			}

			# Open the specified file
			if {[$actualProject openfile $filename 1 . def def 0 0 {}] != {}} {
				$actualProject switch_to_last
				update
				$actualProject editor_procedure {} parseAll {}

				# Make LST read only
				if {[file extension $filename] == {.lst}} {
					set ::editor_RO_MODE 1
					$actualProject switch_editor_RO_MODE
				}
			}

		# Open "Recent project file"
		} elseif {$what == 0} {
			# Try to open he specified project file
			if {![Project::open_project_file $filename]} {
				tk_messageBox		\
					-type ok	\
					-icon warning	\
					-parent .	\
					-title [mc "Error - MCU 8051 IDE"] \
					-message [mc "Unable to load file: %s" $filename]
			} else {
				$actualProject editor_procedure {} highlight_visible_area {}
			}

			adjust_title
			disaena_menu_toolbar_for_current_project
		}

		# Unlock critical procedures
		set critical_procedure_in_progress 0
	}

	## Add item into list of recent files
	 # @param Int what
	 #	0 - Recent project files
	 #	1 - Recent source code files
	 #	2 - Recent Virtual HW files
	 # @param String filename	- Name of file to add
	 # @return void
	proc recent_files_add {what filename} {
		variable file_recent_files	;# List: recently opened files
		variable project_recent_files	;# List: recently opened projects
		variable vhw_recent_files	;# List: recently opened Virtual HW files

		# Add "Recent Virtual HW file"
		if {$what == 2} {
			# Check wheather the specified file is already in the list
			set tmp [lsearch -ascii -exact $vhw_recent_files $filename]
			if {$tmp != -1} {
				set vhw_recent_files [linsert [lreplace $vhw_recent_files $tmp $tmp] 0 $filename]
				refresh_recent_files $what
				return
			}

			# Trim list length to 10
			if {[llength $vhw_recent_files] >= 10} {
				set vhw_recent_files [lreplace $vhw_recent_files end end]
			}

			# Add new item and refersh menu
			set vhw_recent_files [linsert $vhw_recent_files 0 $filename]
			refresh_recent_files $what

		# Add "Recent source code file"
		} elseif {$what == 1} {
			# Check wheather the specified file is already in the list
			set tmp [lsearch -ascii -exact $file_recent_files $filename]
			if {$tmp != -1} {
				set file_recent_files [linsert [lreplace $file_recent_files $tmp $tmp] 0 $filename]
				refresh_recent_files $what
				return
			}

			# Trim list length to 10
			if {[llength $file_recent_files] >= 10} {
				set file_recent_files [lreplace $file_recent_files end end]
			}

			# Add new item and refersh menu
			set file_recent_files [linsert $file_recent_files 0 $filename]
			refresh_recent_files $what

		# Add "Recent project file"
		} elseif {$what == 0} {
			# Check wheather the specified file is already in the list
			set tmp [lsearch -ascii -exact $project_recent_files $filename]
			if {$tmp != -1} {
				set project_recent_files [linsert [lreplace $project_recent_files $tmp $tmp] 0 $filename]
				refresh_recent_files $what
				return
			}

			# Trim list length to 10
			if {[llength $project_recent_files] >= 10} {
				set project_recent_files [lreplace $project_recent_files end end]
			}

			# Add new item and refersh menu
			set project_recent_files [linsert $project_recent_files 0 $filename]
			refresh_recent_files $what

		}
	}

	## Invoke "scribble notepad"
	 # @return void
	proc __notes {} {
		Notes #auto {} {}
	}

	## Invoke "Base converter"
	 # @return void
	proc __base_converter {} {
		variable base_converters	;# List: All base converter objects

		set obj [BaseConverter #auto]
		lappend base_converters ::X::$obj

		return $obj
	}

	## Close "Base converter"
	 # @return void
	proc __base_converter_close {obj} {
		variable base_converters	;# List: All base converter objects

		set idx [lsearch -ascii -exact $base_converters $obj]
		if {$idx != -1} {
			set base_converters [lreplace $base_converters $idx $idx]
		}
	}

	## Invoke "LED panel" (section Virtual Hardware)
	 # @return void
	proc __vhw_LED_panel {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		return [LedPanel #auto $actualProject]
	}

	## Invoke "LED display" (section Virtual Hardware)
	 # @return void
	proc __vhw_LED_display {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		return [LedDisplay #auto $actualProject]
	}

	## Invoke "LED matrix" (section Virtual Hardware)
	 # @return void
	proc __vhw_LED_matrix {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		return [LedMatrix #auto $actualProject]
	}

	## Invoke "Virtual UART Terminal" (section Virtual Hardware)
	 # @return void
	proc __vhw_UART_terminal {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		return [VirtualUARTTerminal #auto $actualProject]
	}

	## Invoke "File Interface" (section Virtual Hardware)
	 # @return void
	proc __vhw_file_interface {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		return [PaleFileInterface #auto $actualProject]
	}

	## Invoke "LCD display controlled by HD44780" (section Virtual Hardware)
	 # @parm List $display_size={} - Size of the LCD display to create, format: {rows columns}, empty list means invoke size selection dialog
	 # @return void
	 #
	 # Note: If the first argument is omitted then this function will create a "Size selection dialog"
	proc __vhw_HD44780 {{display_size {}}} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project
		variable vhw_HD44780_rect	;# Array: Rectangles in dialog "Set display size"
		variable vhw_HD44780_canvas	;# Widget: Canvas widget in dialog "Set display size"
		variable vhw_HD44780_counter	;# Int: Counter of dialog instances
		variable vhw_HD44780_size_lbl	;# Widget: Label showing the LCD size in dialog "Set display size"
		variable vhw_HD44780_dialog	;# Widget: Toplevel window of dialog "Set display size"
		variable vhw_HD44780_size	;# List of Int: LCD display size chosen by the user, {HEIGHT WIDTH}

		# This function requires at least one project opened
		if {$project_menu_locked} {return}

		# LCD display size specified -- create the display and return
		if {[llength $display_size]} {
			set object [LcdHD44780 #auto $actualProject]
			$object set_config [list [lindex $display_size 0] [lindex $display_size 1]]
			return $object
		}


		# --------------------------------------------------------------
		# Create the size selection dialog
		# --------------------------------------------------------------

		# Create the dialog window
		set dialog [toplevel .set_lcd_size$vhw_HD44780_counter -class {Set display size} -bg ${::COMMON_BG_COLOR}]

		# Set some namespace variables
		incr vhw_HD44780_counter	;# Int: Counter of dialog instances
		set vhw_HD44780_dialog $dialog	;# Widget: Toplevel window of dialog "Set display size"
		set vhw_HD44780_size {0 0}	;# List of Int: LCD display size chosen by the user, {HEIGHT WIDTH}

		# Create top frame (text: "Set display size" and actual display size)
		set top_frame [frame $dialog.top_frame]
		pack [label $top_frame.header_lbl				\
			-text [mc "Set display size"]				\
			-font [font create					\
				-size [expr {int(-17 * $::font_size_factor)}]	\
				-family {helvetica}]				\
		] -side left -padx 10
		set vhw_HD44780_size_lbl [label $top_frame.size_lbl	\
			-text {0 × 0}					\
			-text [mc "Set display size"]			\
			-font [font create					\
				-size [expr {int(-16 * $::font_size_factor)}]	\
				-family {helvetica} -weight {bold}]		\
		]
		pack $vhw_HD44780_size_lbl -side right -padx 10
		pack $top_frame -fill x

		## Create the matrix of rectangles for display size selection
		set w 12
		set h 17
		set x0 3
		set x $x0
		set y 3
		set canvas [canvas $dialog.canvas		\
			-bg {#FFFFFF}				\
			-height [expr {2 * ($h + 3) + 6}]	\
			-width [expr {40 * ($w + 3) + 6}]	\
			-bd 0					\
			-highlightthickness 0			\
		]
		set vhw_HD44780_canvas $canvas
		for {set row 1} {$row <= 2} {incr row} {
			for {set col 1} {$col <= 40} {incr col} {
				set r [$canvas create rectangle	\
					$x			\
					$y			\
					[expr {$x + $w}]	\
					[expr {$y + $h}]	\
					-outline {#0000FF}	\
				]

				incr x $w
				incr x 3

				set vhw_HD44780_rect($row,$col) $r

				$canvas bind $r <Enter> [list ::X::vhw_HD44780_ENTER $row $col]
				$canvas bind $r <Leave> [list ::X::vhw_HD44780_ENTER 0 0]
				$canvas bind $r <Button-1> [list ::X::vhw_HD44780_GO $row $col]
			}
			set x $x0
			incr y $h
			incr y 3
		}
		pack $canvas

		# Set window parameters
		wm iconphoto $dialog ::ICONS::16::set_lcd_size
		wm title $dialog [mc "Set display size"]
		wm resizable $dialog 0 0
		wm protocol $dialog WM_DELETE_WINDOW {
			X::vhw_HD44780_CANCEL
		}
		wm transient $dialog .
		update
		raise $dialog
		catch {grab $dialog}

		# Wait the dialog window is destroyed
		tkwait window $dialog

		# If the size was set then create the display
		if {[lindex $vhw_HD44780_size 0] && [lindex $vhw_HD44780_size 1]} {
			set object [LcdHD44780 #auto $actualProject]
			$object set_config [list [lindex $vhw_HD44780_size 0] [lindex $vhw_HD44780_size 1]]
			return $object
 		}
	}

	## Handle pointer enter event in the canvas widget of the LCD display size selection dialog
	 # @parm Int target_row - Designated row
	 # @parm Int target_col - Designated column
	 # @return void
	proc vhw_HD44780_ENTER {target_row target_col} {
		variable vhw_HD44780_rect	;# Array: Rectangles in dialog "Set display size"
		variable vhw_HD44780_canvas	;# Widget: Canvas widget in dialog "Set display size"
		variable vhw_HD44780_size_lbl	;# Widget: Label showing the LCD size in dialog "Set display size"

		# Adjust appearance of the matrix of rectangles
		for {set row 1} {$row <= 2} {incr row} {
			for {set col 1} {$col <= 40} {incr col} {
				if {$row <= $target_row && $col <= $target_col} {
					set fill {#AAFFDD}
				} else {
					set fill {#FFFFFF}
				}
				$vhw_HD44780_canvas itemconfigure $vhw_HD44780_rect($row,$col) -fill $fill
			}
		}

		# Adjust contents of the label displaying the designated size
		$vhw_HD44780_size_lbl configure -text [format {%d × %d} $target_row $target_col]
	}

	## Set display size and close the LCD display size selection dialog
	 # @parm Int rows - Number of rows
	 # @parm Int cols - Number of columns
	 # @return void
	proc vhw_HD44780_GO {rows cols} {
		variable vhw_HD44780_size	;# List of Int: LCD display size chosen by the user, {HEIGHT WIDTH}
		set vhw_HD44780_size [list $rows $cols]
		vhw_HD44780_CANCEL
	}

	## Close the LCD display size selection dialog
	 # @return void
	proc vhw_HD44780_CANCEL {} {
		variable vhw_HD44780_dialog	;# Widget: Toplevel window of dialog "Set display size"

		if {[winfo exists $vhw_HD44780_dialog]} {
			destroy $vhw_HD44780_dialog
		}
	}

	## Invoke "Multiplexed LED display" (section Virtual Hardware)
	 # @return void
	proc __vhw_M_LED_display {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		return [MultiplexedLedDisplay #auto $actualProject]
	}

	## Invoke "Simple keypad" (section Virtual Hardware)
	 # @return void
	proc __vhw_keys {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		return [SimpleKeyPad #auto $actualProject]
	}

	## Invoke "DS1620 temperature sensor" (section Virtual Hardware)
	 # @return void
	proc __vhw_ds1620 {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		return [Ds1620 #auto $actualProject]
	}

	## Invoke "Matrix keypad" (section Virtual Hardware)
	 # @return void
	proc __vhw_matrix_keypad {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		return [MatrixKeyPad #auto $actualProject]
	}

	## Open VHW file (section Virtual Hardware)
	 # @return void
	proc __open_VHW {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# Ask user for save modified VHW scenario
		if {[${::X::actualProject} pale_modified]} {
			if {[tk_messageBox		\
				-parent .		\
				-type yesno		\
				-icon question		\
				-title [mc "File modified"]	\
				-message [mc "The current VHW connections have been modified,\ndo you want to save them before closing ?"]
			] == {yes}} then {
				if {![$actualProject pale_save]} {
					tk_messageBox		\
						-parent .	\
						-type ok	\
						-icon error	\
						-title [mc "IO Error"]	\
						-message [mc "Unable to write to file:\n\"%s\"" [$actualProject pale_get_scenario_filename]]
				}
			}
		}

		# Create file selection dialog
		catch {delete object ::fsd}
		KIFSD::FSD ::fsd	 					\
			-title [mc "Open file - Virtual HW - MCU 8051 IDE"]	\
			-directory [$actualProject cget -projectPath]		\
			-defaultmask 0 -multiple 0 -filetypes [list		\
				[list [mc "All relevant"]	{*.{vhw,vhc}}]	\
				[list [mc "Virtual HW"]		{*.vhw}]	\
				[list [mc "VH component"]	{*.vhc}]	\
				[list [mc "All files"]		{*}]		\
			]

		# Open file after press of OK button
		::fsd setokcmd {
			set filename [::fsd get]
			if {[${::X::actualProject} pale_open_scenario $filename]} {
				tk_messageBox		\
					-parent .	\
					-type ok	\
					-icon error	\
					-title [mc "IO Error"]	\
					-message [mc "Unable to read file:\n\"%s\"" $filename]
			} else {
				::X::recent_files_add 2 $filename
			}
		}

		# activate the dialog
		::fsd activate
	}

	## Import virtual hardware file
	 # @return void
	proc __load_VHW {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# Create file selection dialog
		catch {delete object ::fsd}
		KIFSD::FSD ::fsd	 					\
			-title [mc "Load file - Virtual HW - MCU 8051 IDE"]	\
			-directory [$actualProject cget -projectPath]		\
			-defaultmask 0 -multiple 1 -filetypes [list		\
				[list [mc "All relevant"]	{*.{vhw,vhc}}]	\
				[list [mc "Virtual HW"]		{*.vhw}]	\
				[list [mc "VH component"]	{*.vhc}]	\
				[list [mc "All files"]		{*}]		\
			]

		# Open file after press of OK button
		::fsd setokcmd {
			foreach filename [::fsd get] {
				if {[${::X::actualProject} pale_load_scenarion $filename]} {
					tk_messageBox		\
						-parent .	\
						-type ok	\
						-icon error	\
						-title [mc "IO Error"]	\
						-message [mc "Unable to read file:\n\"%s\"" $filename]
				} else {
					::X::recent_files_add 2 $filename
				}
			}
		}

		# Activate the dialog
		::fsd activate
	}

	## Save virtual hardware scenario to a file
	 # @return void
	proc __save_VHW {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		if {![$actualProject pale_save]} {
			Sbar [mc "Unable to save Virtual HW connections"]
		}
	}

	## Save virtual hardware scenario under a different filename
	 # @return void
	proc __save_as_VHW {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# Create file selection dialog
		catch {delete object ::fsd}
		KIFSD::FSD ::fsd	 					\
			-title [mc "Save file - Virtual HW - MCU 8051 IDE"]	\
			-directory [$actualProject cget -projectPath]		\
			-initialfile [$actualProject pale_get_scenario_filename]\
			-defaultmask 0 -multiple 1 -filetypes [list	\
				[list [mc "Virtual HW"]	{*.vhw}]	\
				[list [mc "All files"]	{*}]		\
			]

		# Open file after press of OK button
		::fsd setokcmd {
			set abort 0
			set filename [::fsd get]

			# Ask user for overwrite existing file
			if {[file exists $filename]} {
				if {[tk_messageBox	\
					-type yesno	\
					-icon question	\
					-parent .	\
					-title [mc "Overwrite file"]	\
					-message [mc "A file name '%s' already exists. Do you want to overwrite it ?" [file tail $filename]]
					] != {yes}
				} then {
					set abort 1
				}
			}

			if {!$abort} {
				if {![${::X::actualProject} pale_save_as $filename]} {
					tk_messageBox		\
						-parent .	\
						-type ok	\
						-icon error	\
						-title [mc "IO Error"]	\
						-message [mc "Unable to save file:\n\"%s\"" $filename]
				} else {
					::X::recent_files_add 2 $filename
				}
			}
		}

		# Activate the dialog
		::fsd activate
	}

	## Remove all virtual hardware and forget VHW filename
	 # @return void
	proc __remove_all_VHW {} {
		variable actualProject		;# Object: Current project
		variable project_menu_locked	;# Bool: Indicates than there is at least one opened project

		if {$project_menu_locked} {return}

		# Ask user for comfirmation
		if {[tk_messageBox	\
			-type yesno	\
			-icon question	\
			-parent .	\
			-title [mc "Are you sure ?"]	\
			-message [mc "Do you really want to remove all virtual hardware from the current simulation scenario ?"]
			] != {yes}
		} then {
			return
		}

		$actualProject pale_forget_all
	}

	## Toggle full screen mode
	 # @return void
	proc __toggle_fullscreen {} {
		# Normal window
		if {[wm attributes . -fullscreen]} {
			if {[winfo exists .mainIconBar.fullscreen]} {
				.mainIconBar.fullscreen configure -image ::ICONS::22::window_fullscreen
			}
			wm attributes . -fullscreen 0
		# Full screen window
		} else {
			if {[winfo exists .mainIconBar.fullscreen]} {
				.mainIconBar.fullscreen configure -image ::ICONS::22::window_nofullscreen
			}
			wm attributes . -fullscreen 1
		}

		# Without this help windows won't work properly on MS Windows
		if {$::MICROSOFT_WINDOWS} {
			after idle {
				wm geometry . [wm geometry .]
			}
		}

		# Restore position of bottom pane
		after 300 {
			foreach project ${::X::openedProjects} {
				$project bottomNB_redraw_pane
			}
		}
	}

	## Invoke the special calculator
	 # @return void
	proc __spec_calc {} {
		variable spec_calc_objects	;# List: All special calculator objects

		lappend spec_calc_objects [SpecCalc #auto]
	}

	## Invoke RS232/UART debugger
	 # @return void
	proc __rs232debugger {} {
		variable rs232debugger_objects	;# List: All RS232 Debugger objects

		lappend rs232debugger_objects [RS232Debugger #auto]
	}

	## Invoke a functional diagram of the given type
	 # @parm Int type -
	 # @return void
	proc __functional_diagram {type} {
	}

	## Open arbitrary URI in user preffered application
	 # @parm String uri -- URI to open
	 # @return void
	proc open_uri {uri} {
		# On Linux and similars systems we use "xdg-open"
		if {!$::MICROSOFT_WINDOWS} {
			catch {
				exec -- xdg-open $uri &
			}

		# On MS Windows we use its buildin command "start"
		} else {
			catch {
				exec -- "cmd" "/c" "start [regsub -all {[^/\\]+\s[^/\\]*} $uri {"&"}]" &
			}
		}
	}

	## Open project web page in user preferred browser
	 # @return void
	proc __web_page {} {
		open_uri {http://mcu8051ide.sourceforge.net}
	}

	## Open web page for reporting bugs in user preferred browser
	 # @return void
	proc __bug_report {} {
		open_uri {http://sourceforge.net/tracker/?group_id=185864&atid=914981}
	}

	## Open handbook in user preferred PDF reader
	 # @return void
	proc __handbook {} {
		if {[file exists "${::INSTALLATION_DIR}/doc/handbook/mcu8051ide.${::GLOBAL_CONFIG(language)}.pdf"]} {
			open_uri "${::INSTALLATION_DIR}/doc/handbook/mcu8051ide.${::GLOBAL_CONFIG(language)}.pdf"
		} else {
			open_uri "${::INSTALLATION_DIR}/doc/handbook/mcu8051ide.en.pdf"
		}
	}

	## Open web page with SDCC manual in user preferred browser
	 # @return void
	proc __sdcc_manual {} {
		open_uri {http://sdcc.sourceforge.net/doc/sdccman.html}
	}

	## Open web page with ASEM-51 manual in user preferred browser
	 # @return void
	proc __asem51_manual {} {
		open_uri {http://plit.de/asem-51/docs.htm}
	}

	## Open interactive 8051 instruction table
	 # @return void
	proc __table_of_instructions {} {
		variable table_of_instructions_object	;# Object: Interactive 8051 instruction table
		if {$table_of_instructions_object != {}} {
			if {[$table_of_instructions_object is_visible]} {
				$table_of_instructions_object raise_window
			} else {
				$table_of_instructions_object restore_window
			}
		} else {
			set table_of_instructions_object [TableOfInstructions #auto]
		}
	}

	## Make sure that there are no help windows visible
	 # @return void
	proc remove_all_help_windows {} {
		variable openedProjects		;# List of opened projects (Object references)

		foreach project $openedProjects {
			$project file_details_win_hide
		}
		::Editor::close_completion_popup_window_NOW
		close_project_details
		help_window_hide
	}

	## Perform secure send command
	 # Secure means that it will not crash or something like that in case of any errors.
	 # But instead it will popup an error message to the user (Tk dialog).
	 # @parm List args - Arguments for the send command
	 # @return void
	proc secure_send args {
		if {[catch {
			eval "send $args"
		} result]} then {
			puts stderr "Unknown IO Error :: $result"
			return 1

		} else {
			return 1
		}
	}

	proc __d52 {} {
		variable critical_procedure_in_progress	;# Bool: Disables procedures which takes a long time

		if {$critical_procedure_in_progress} {return}

		# Create dialog window
		set win [toplevel .d52_open_dialog -class {Disassemble with D52} -bg ${::COMMON_BG_COLOR}]
		set mainframe [frame $win.frame]

		# Label, Entry and Button "Input file"
		grid [Label $mainframe.lbl_input		\
			-text [mc "Input file"]			\
			-helptext [mc "File to disassemble"]	\
		] -column 1 -row 1 -sticky w
		grid [ttk::entry $mainframe.entry_input	\
			-textvariable X::input_file	\
			-width 50			\
		] -column 2 -row 1 -sticky we
		DynamicHelp::add $mainframe.entry_input -text [mc "File to disassemble"]
		grid [ttk::button $mainframe.button_select_input_file	\
			-image ::ICONS::16::fileopen			\
			-takefocus 0					\
			-style Flat.TButton				\
			-command {
				# Invoke file selection dialog
				X::select_input_output 1 {{hex,ihx}} .d52_open_dialog
			}	\
		] -column 3 -row 1 -sticky e
		DynamicHelp::add $mainframe.button_select_input_file	\
			-text [mc "Invoke dialog to select input file"]

		# Create separator
		grid [ttk::separator $mainframe.separator	\
			-orient horizontal			\
		] -column 1 -columnspan 3 -row 2 -sticky we -pady 10

		# Create buttons "Ok" and "Cancel"
		set button_frame [frame $mainframe.button_frame]
		pack [ttk::button $button_frame.button_ok	\
			-text [mc "Ok"]				\
			-command {X::d52_OK}			\
			-compound left				\
			-image ::ICONS::16::ok			\
		] -side left -padx 5
		pack [ttk::button $button_frame.button_cancel	\
			-text [mc "Cancel"]			\
			-command {X::d52_CANCEL}		\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
		] -side left -padx 5
		grid $button_frame -column 1 -columnspan 3 -row 3

		pack $mainframe -fill both -expand 1 -padx 5 -pady 5

		# Event bindings (Enter == Ok; Escape == Cancel)
		bind $win <KeyRelease-Return>	{X::d52_OK; break}
		bind $win <KeyRelease-KP_Enter>	{X::d52_OK; break}
		bind $win <KeyRelease-Escape>	{X::d52_CANCEL; break}

		# Set window attributes -- modal window
		wm iconphoto $win ::ICONS::16::d52
		wm title $win [mc "Disassemble with D52 - MCU 8051 IDE"]
		wm minsize $win 450 70
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW {
			X::d52_CANCEL
		}
		wm transient $win .
		catch {grab $win}
		raise $win
		tkwait window $win
	}

	proc d52_CANCEL {} {
		catch {
			destroy .d52_open_dialog
		}
	}

	proc d52_OK {} {
		variable input_file	;# Input file

		d52_CANCEL
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

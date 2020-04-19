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
if { ! [ info exists _MAINTAB_TCL ] } {
set _MAINTAB_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Manages central widget of this program, each instance of this class
# stands for one project
# --------------------------------------------------------------------------

source "${::LIB_DIRNAME}/pale/pale.tcl"	;# Peripheral Abstraction Layer Engine

class MainTab {
	inherit FileList BottomNoteBook Pale

	public variable fileList_Pane	;# ID of pane window containing list of files and editor
	public variable top_Pane	;# ID of pane window containing fileList_Pane and right panel
	public variable main_Pane	;# ID of pane window containing top_Pane and bottom panel
	public variable rightPanel	;# ID of right panel container

	public variable projectName	;# Name of project related to this instance
	public variable projectPath	;# Path to directory where the project file is located
	public variable projectFile	;# Name of the project file
	public variable procData	;# Processor definition list
	public variable available_SFR	;# List of SFR and SFB which are available on the choosen MCU

	# Compiler configuration related variables
	private variable PCC_native_assembler	;# --> ::Compiler::Settings::*
	private variable PCC_selected_assembler	;# --> ::ExternalCompiler::selected_assembler
	private variable PCC_ASEM51_config	;# --> ::ExternalCompiler::assembler_ASEM51_config
	private variable PCC_ASEM51_addcfg	;# --> ::ExternalCompiler::assembler_ASEM51_addcfg
	private variable PCC_ASL_config		;# --> ::ExternalCompiler::assembler_ASL_config
	private variable PCC_ASL_addcfg		;# --> ::ExternalCompiler::assembler_ASL_addcfg
	private variable PCC_AS31_config	;# --> ::ExternalCompiler::assembler_AS31_config
	private variable PCC_AS31_addcfg	;# --> ::ExternalCompiler::assembler_AS31_addcfg
	private variable PCC_sdcc_bool_opt	;# --> ::ExternalCompiler::sdcc_bool_options
	private variable PCC_sdcc_str_opt	;# --> ::ExternalCompiler::sdcc_string_options
	private variable PCC_sdcc_opt_str_opt	;# --> ::ExternalCompiler::sdcc_optional_string_options
	private variable PCC_sdcc_scs_str_opt	;# --> ::ExternalCompiler::sdcc_scs_string_options

	## Project information variables
	 # (P - project; G - general; S - Special)
	public variable P_information_version	;# Project version
	public variable P_information_date	;# Date of last project update
	public variable G_information_authors	;# List of project authors
	public variable G_information_copyright	;# Project copyright information
	public variable G_information_license	;# Project license information
	public variable S_flag_read_only	;# Project is for reading only (e.g. "Demo project")
	public variable P_option_mcu_type	;# Processor type (e.g. AT89C51RC)
	public variable P_option_clock		;# Project default simulator clock rate
	public variable P_option_mcu_xdata	;# Size of external data memory
	public variable P_option_mcu_xcode	;# Size of external program memory
	public variable P_option_main_file	;# Project main source file

	public variable project_description	;# Project description text
	public variable todoText		;# Content of TODO list
	public variable calculatorList		;# List of values for calculator (see class Calculator)
	public variable other_options		;# Other options
	public variable projectFiles		;# List of project source code files

	private variable mainTab		;# NoteBook tab identifier (container)

	## Object constructor
	 # @parm String projectpath	- Path to directory where the project file is located
	 # @parm String projectfile	- Name of the project file
	 # @parm List dataList		- Data extracted from project file (see NS Project)
	constructor {ProjectName projectpath projectfile dataList} {
		set projectName $ProjectName
		set S_flag_read_only 0

		#
		## PROCESS PROJECT SPECIFICATION DATA
		#

		set i 0
		foreach info {version date} {
			regsub -all {\\\}} [regsub -all {\\\{} [lindex $dataList "0 $i"] "{"] "}" P_information_$info
			incr i
		}

		set i 0
		foreach info {authors copyright license} {
			regsub -all {\\\}} [regsub -all {\\\{} [lindex $dataList "1 $i"] "{"] "}" G_information_$info
			incr i
		}

		set P_option_mcu_type	[lindex $dataList {2 0}]
		set P_option_clock	[lindex $dataList {2 1}]
		set P_option_mcu_xdata	[lindex $dataList {2 2}]
		set P_option_mcu_xcode	[lindex $dataList {2 3}]

		set watches_file	[lindex $dataList {3 0}]
		set scenario_file	[lindex $dataList {3 1}]
		set P_option_main_file	[lindex $dataList {3 2}]
		set editor_sw_lock	[lindex $dataList {3 3}]
		set graphList		[lindex $dataList 4]

		set project_description	[lindex $dataList {5 0}]
		regsub -all {\\\{} $project_description "{" project_description
		regsub -all {\\\}} $project_description "}" project_description
		set todoText		[lindex $dataList {5 1}]
		regsub -all {\\\{} $todoText "{" todoText
		regsub -all {\\\}} $todoText "}" todoText
		set calculatorList	[lindex $dataList 6]
		set other_options	[lindex $dataList 7]

		# Load compiler configurations
		if {[llength [lindex $dataList 8]]} {
			array set PCC_native_assembler	[lindex $dataList {8 0}]
			set PCC_selected_assembler	[lindex $dataList {8 1}]
			array set PCC_ASEM51_config	[lindex $dataList {8 2}]
			array set PCC_ASEM51_addcfg	[lindex $dataList {8 3}]
			array set PCC_ASL_config	[lindex $dataList {8 4}]
			array set PCC_ASL_addcfg	[lindex $dataList {8 5}]
			array set PCC_sdcc_bool_opt	[lindex $dataList {8 6}]
			array set PCC_sdcc_str_opt	[lindex $dataList {8 7}]
			array set PCC_sdcc_opt_str_opt	[lindex $dataList {8 8}]
			array set PCC_sdcc_scs_str_opt	[lindex $dataList {8 9}]

			if {[llength [lindex $dataList 8]] > 10} {
				array set PCC_AS31_config	[lindex $dataList {8 10}]
				array set PCC_AS31_addcfg	[lindex $dataList {8 11}]
			}
		} else {
			retrieve_compiler_settings
		}

		set projectFiles	[lindex $dataList 9]

		# Load default values if the given values is not valid
		if {[lsearch ${::X::available_processors} $P_option_mcu_type] == -1} {
			set P_option_mcu_type [lindex ${X::project_edit_defaults} {0 1}]
			puts stderr "Unsupported processor type -- setting to [lindex ${X::project_edit_defaults} {0 1}]"
		}
		set procData [SelectMCU::get_processor_details $P_option_mcu_type]

		# set MCU type in status bar, kdb -- Are you sure Kara that this line does anathing??
		.statusbarMCU configure -text $P_option_mcu_type

		if {$procData == {}} {
			wm withdraw .
			tk_messageBox		\
				-icon error	\
				-type ok	\
				-title [mc "FATAL ERROR"]	\
				-message [mc "MCUs database file is corrupted,\nthis program cannot run without it.\nPlease reinstall MCU 8051 IDE."]
			exit 1
		}
		refresh_project_available_SFR
		if {![string is digit -strict $P_option_mcu_xdata] || $P_option_mcu_xdata > 0x10000} {
			set P_option_mcu_xdata 0
			puts "Invalid XDATA capacity -- setting to 0"
		}
		if {
			![string is digit -strict $P_option_mcu_xcode]
				||
			$P_option_mcu_xcode > [expr {0x10000 - ([lindex $procData 2] * 1024)}]
		} then {
			set P_option_mcu_xcode 0
			puts "Invalid XCODE capacity -- setting to 0"
		}
		if {[lindex $procData 0] != {yes}} {
			set P_option_mcu_xdata 0
		}
		if {[lindex $procData 1] != {yes}} {
			set P_option_mcu_xcode 0
		}
		if {[regexp {^\d+(\.\d+)?$} $P_option_clock]} {
			if {$P_option_clock > 99999} {
				set P_option_clock [lindex ${X::project_edit_defaults} {1 1}]
				puts stderr "Clock value must be below 99999 -- setting to [lindex ${X::project_edit_defaults} {1 1}]"
			}
		} else {
			set P_option_clock [lindex ${X::project_edit_defaults} {1 1}]
			puts stderr "Invalid clock value -- setting to [lindex ${X::project_edit_defaults} {1 1}]"
		}
		if {![string is boolean -strict $editor_sw_lock]} {
			puts stderr "Invalid file switching lock value -- setting to 1"
			set editor_sw_lock 1
		}

		# set some object variables
		set projectPath		$projectpath
		set projectFile		$projectfile

		# create higher-level container
		set mainTab [${::main_nb} insert end			\
			[string trimleft $this {:}]			\
			-text $projectName				\
			-image ::ICONS::16::kcmdevices			\
			-raisecmd [list X::switch_project $this]	\
		]
		after idle {
			update
			foreach project ${::X::openedProjects} {
				$project bottomNB_redraw_pane
			}
		}

		# Invoke progress dialog
		set ::FileList::open_files_cur_file [mc "Initializing ..."]
		create_progress_bar .prgDl			\
			.					\
			::FileList::open_files_cur_file		\
			{}					\
			::FileList::open_files_progress		\
			0					\
			[mc "Opening project files"]		\
			::ICONS::16::fileopen			\
			[mc "Abort"]				\
			{set ::FileList::open_files_abort 1}

		# create paned windows
		set main_Pane	[panedwindow $mainTab.main_Pane		\
			-orient vertical	\
			-sashwidth 4		\
			-showhandle 0		\
			-opaqueresize 1		\
			-sashrelief raised	\
		]
		set top_Pane	[panedwindow $main_Pane.top_Pane	\
			-orient horizontal	\
			-sashwidth 2		\
			-showhandle 0		\
			-opaqueresize 1		\
			-sashrelief raised	\
		]
		set fileList_Pane [panedwindow $top_Pane.fileList_Pane	\
			-orient horizontal	\
			-sashwidth 2		\
			-showhandle 0		\
			-opaqueresize 1		\
			-sashrelief flat	\
		]

		# Initalize mainTab
		set bottom_pane [frame $main_Pane.bottomNB]
		set rightPanel [frame $top_Pane.rightPanel]

		# Insert all widgets at places where there should be
		$top_Pane add $fileList_Pane
		$top_Pane add $rightPanel
		$main_Pane add $top_Pane
		$main_Pane add $bottom_pane

		# Intialize all panels
		simulator_initialize_mcu
		initialize_rightPanel $rightPanel $top_Pane $watches_file
		initalize_BottomNoteBook $bottom_pane $main_Pane $todoText $calculatorList $graphList
		initalize_FileList $fileList_Pane $projectPath $projectFiles $editor_sw_lock

		# Adjust progress dialog
		catch {.prgDl configure -command {puts stderr "Unable to abort at this stage !"}}
		set ::FileList::open_files_cur_file [mc "Finishing ..."]

		# Pack main pane
		pack $main_Pane -expand 1 -fill both

		# Raise last tab in mainNB
		${::main_nb} raise [string trimleft $this {:}]

		# Take care of proper geometry management
		bottomNB_redraw_pane
		right_panel_redraw_pane
		todo_panel_redraw_pane
		filelist_adjust_size_of_tabbar

		# Highlight all loaded source codes, import breakpoints and bookmarks etc.
		filelist_global_highlight

		ensure_that_both_editors_are_properly_initialized

		# Load scenario file
		if {[pale_open_scenario $scenario_file] == 1} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon error	\
				-title [mc "IO Error"]	\
				-message [mc "Unable to open VHW file:\n\"%s\"" $filename]
		}

		# (just workaround ...)
		$this rightPanel_refresh_font_settings 1

		# Destroy progress dialog invoked from procedure initiate_FileList
		catch {destroy .prgDl}
	}

	## Object destructor
	destructor {
		${::main_nb} delete [string trimleft $this {:}]
	}

	## Kill all child processes
	 # @return void
	public method kill_childern {} {
		$this terminal_kill_childern
		$this filelist_kill_childern
		$this hw_man_kill_childern
	}

	## Refresh list of available SFR and SFB
	 # @return void
	public method refresh_project_available_SFR {} {
		set available_SFR [concat [lindex $procData 43] {
			R0	R1	R2	R3	R4	R5	R6	R7
			B	ACC	A	TMOD	TH0	TH1	SP	DPL	DPH	PCON
			TL0	TL1	AB	DPTR
			RXD	TXD	INT0	INT1	T0	T1	WR	RD

			PSW		C CY	AC	F0	RS1	RS0	OV		P
			IE		EA				ET1	EX1	ET0	EX0
			IP						PT1	PX1	PT0	PX0
			TCON		TF1	TR1	TF0	TR0	IE1	IT1	IE0	IT0
		}] ;#	REGISTER	BIT 7	BIT 6	BIT 5	BIT 4	BIT 3	BIT 2	BIT 1	BIT 0

		foreach editor [$this cget -editors] {
			$editor refresh_available_SFR
		}
	}

	## Adjust the compilers settings to the current project configuration
	 # @return void
	public method adjust_compiler_settings {} {
		# Native assembler
		foreach key [array names PCC_native_assembler] {
			set ::Compiler::Settings::$key $PCC_native_assembler($key)
		}

		## Preferred assembler
		set ::ExternalCompiler::selected_assembler $PCC_selected_assembler
		## ASEM-51
		array set ::ExternalCompiler::assembler_ASEM51_config	\
			[array get PCC_ASEM51_config]
		array set ::ExternalCompiler::assembler_ASEM51_addcfg	\
			[array get PCC_ASEM51_addcfg]
		## ASL
		array set ::ExternalCompiler::assembler_ASL_config	\
			[array get PCC_ASL_config]
		array set ::ExternalCompiler::assembler_ASL_addcfg	\
			[array get PCC_ASL_addcfg]
		## AS31
		array set ::ExternalCompiler::assembler_AS31_config	\
			[array get PCC_AS31_config]
		array set ::ExternalCompiler::assembler_AS31_addcfg	\
			[array get PCC_AS31_addcfg]
		## SDCC
		 # Copy boolean options
		array set ::ExternalCompiler::sdcc_bool_options			\
			[array get PCC_sdcc_bool_opt]
		 # Copy string options
		array set ::ExternalCompiler::sdcc_string_options		\
			[array get PCC_sdcc_str_opt]
		 # Copy optional strings
		array set ::ExternalCompiler::sdcc_optional_string_options	\
			[array get PCC_sdcc_opt_str_opt]
		 # Copy semicolon separated optional string options
		array set ::ExternalCompiler::sdcc_scs_string_options		\
			[array get PCC_sdcc_scs_str_opt]
	}

	## Adjust the current project configuration to the compilers settings
	 # @return void
	public method retrieve_compiler_settings {} {
		# Native assembler
		foreach key ${::configDialogues::compiler::defaults} {
			set key [lindex $key 0]
			set PCC_native_assembler($key) [subst -nocommands "\$::Compiler::Settings::$key"]
		}
		set PCC_native_assembler(WARNING_LEVEL)	\
			${::Compiler::Settings::WARNING_LEVEL}
		set PCC_native_assembler(max_ihex_rec_length)	\
			${::Compiler::Settings::max_ihex_rec_length}

		## Preferred assembler
		set PCC_selected_assembler $::ExternalCompiler::selected_assembler
		## ASEM-51
		array set PCC_ASEM51_config	\
			[array get ::ExternalCompiler::assembler_ASEM51_config]
		array set PCC_ASEM51_addcfg	\
			[array get ::ExternalCompiler::assembler_ASEM51_addcfg]
		## ASL
		array set PCC_ASL_config	\
			[array get ::ExternalCompiler::assembler_ASL_config]
		array set PCC_ASL_addcfg	\
			[array get ::ExternalCompiler::assembler_ASL_addcfg]
		## AS31
		array set PCC_AS31_config	\
			[array get ::ExternalCompiler::assembler_AS31_config]
		array set PCC_AS31_addcfg	\
			[array get ::ExternalCompiler::assembler_AS31_addcfg]

		## SDCC
		 # Copy boolean options
		array set PCC_sdcc_bool_opt	\
			[array get ::ExternalCompiler::sdcc_bool_options]
		 # Copy string options
		array set PCC_sdcc_str_opt	\
			[array get ::ExternalCompiler::sdcc_string_options]
		 # Copy optional strings
		array set PCC_sdcc_opt_str_opt	\
			[array get ::ExternalCompiler::sdcc_optional_string_options]
		 # Copy semicolon separated optional string options
		array set PCC_sdcc_scs_str_opt	\
			[array get ::ExternalCompiler::sdcc_scs_string_options]
	}

	## Get compilers configuration (intended for project saving)
	 # @return void
	public method get_compiler_config {} {
		return [list				\
			[array get PCC_native_assembler]\
			$PCC_selected_assembler		\
			[array get PCC_ASEM51_config]	\
			[array get PCC_ASEM51_addcfg]	\
			[array get PCC_ASL_config]	\
			[array get PCC_ASL_addcfg]	\
			[array get PCC_sdcc_bool_opt]	\
			[array get PCC_sdcc_str_opt]	\
			[array get PCC_sdcc_opt_str_opt]\
			[array get PCC_sdcc_scs_str_opt]\
			[array get PCC_AS31_config]	\
			[array get PCC_AS31_addcfg]	\
		]
	}

	## Set project read only flag
	 #
	 # The flag inhibits proc ::X::__proj_save.
	 # @return void
	public method set_read_only {} {
		set S_flag_read_only 1
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

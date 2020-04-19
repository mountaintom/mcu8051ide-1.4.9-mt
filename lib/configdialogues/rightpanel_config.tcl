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
if { ! [ info exists _RIGHTPANEL_CONFIG_TCL ] } {
set _RIGHTPANEL_CONFIG_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements right panel configuration dialog
# --------------------------------------------------------------------------

namespace eval rightPanel {

	variable win			;# ID of toplevel dialog window
	variable dialog_opened	0	;# Bool: True if this dialog is already opened

	variable changed		;# Bool: Settings changed
	variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)

	variable apply_button		;# ID of button "Apply"
	variable instruction_tags	;# Highlighting tags for instruction details
	variable watch_text_tags	;# Highlighting tags for register watches

	## Create the dialog
	 # @parm Int tab_number=0 - number of tab to raise
	 # @return void
	proc mkDialog {{tab_number 0}} {
		variable win		;# ID of toplevel dialog window
		variable dialog_opened	;# Bool: True if this dialog is already opened

		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable changed		;# Bool: Settings changed
		variable apply_button		;# ID of button "Apply"
		variable instruction_tags	;# Highlighting tags for instruction details
		variable watch_text_tags	;# Highlighting tags for register watches

		# Destroy the dialog if it's already opened
		if {$dialog_opened} {
			destroy .rightPanel_config_dialog
		}
		set anything_modified 0
		set dialog_opened 1
		set changed 0

		# Get settings from Compiler NS
		getSettings

		# Create toplevel window
		set win [toplevel .rightPanel_config_dialog -class {Configuration dialog} -bg ${::COMMON_BG_COLOR}]

		# Create window header
		label $win.header_label				\
			-compound left				\
			-text [mc "Right panel configuration"]	\
			-font [font create -size [expr {int(-20 * $::font_size_factor)}]]

		## Create notebook
		set nb [ModernNoteBook $win.nb]
		 # Tab "Register watches"
		set watches_tab [$nb insert end watches_tab -text [mc "Register watches"]]		
		 # Tab "Instruction details"
		set instruction_tab [$nb insert end instruction_tab -text [mc "Instruction details"]]		

		#
		## Tab "Register watches"
		#

		# Create header
		grid [label $watches_tab.lbl_header_1 -anchor w	\
			-text [mc "Bold"]			\
		] -column 1 -row 0


		# Create buttons
		set idx 0	;# Current tag index
		set row 1	;# Row in the grid
		foreach tag $watch_text_tags {

			# Local variables
			set tag_name	[lindex $tag 0]	;# Tag name
			set color	[lindex $tag 1]	;# Foreground color (RGB)
			set boldItalic	[lindex $tag 2]	;# Bool: 1 == Bold, 0 == Italic

			# Short tag decription
			grid [label $watches_tab.lbl_${tag_name}	\
				-text [tag2name $tag_name] -pady 0	\
				-highlightthickness 0 -bd 0 -anchor w	\
			] -column 0 -row $row -sticky we

			# Checkbutton "Bold"
			set checkbutton [checkbutton $watches_tab.chbut_${tag_name}		\
				-pady 0 -highlightthickness 0					\
				-command "::configDialogues::rightPanel::change_style $idx 1"	\
			]
			if {$boldItalic == {1}} {
				$checkbutton select
			}
			grid $checkbutton -column 1 -row $row -sticky we

			# Button for selecting foreground color
			grid [button $watches_tab.but_${tag_name}	\
				-bd 1 -relief raised -pady 0 -highlightthickness 0	\
				-bg $color -width 10 -activebackground $color		\
				-command "::configDialogues::rightPanel::select_color $idx $watches_tab.but_${tag_name} 1"
			] -column 2 -row $row -sticky ns -padx 10

			incr row ;# Row in the grid
			incr idx ;# Current tag index
		}

		# Adjust the grid
		grid columnconfigure $watches_tab 0 -minsize 150


		#
		## Tab "Instruction details"
		#

		# Create header
		grid [label $instruction_tab.lbl_header_2 -anchor w	\
			-text [mc "Bold"]	\
		] -column 2 -row 0 -sticky we

		# Create buttons
		set row 1	;# Row in the grid
		set idx 0	;# Current tag index
		foreach tag $instruction_tags {

			# Skip highlight for numbers
			if {[llength $tag] != 3} {
				incr idx
				continue
			}

			# Local variables
			set tag_name	[lindex $tag 0]	;# Tag name
			set color	[lindex $tag 1]	;# Foreground color (RGB)
			set boldItalic	[lindex $tag 2]	;# Bool: 1 == Bold, 0 == Italic

			# Short tag decription
			grid [label $instruction_tab.lbl_${tag_name}	\
				-text [tag2name $tag_name] -pady 0	\
				-highlightthickness 0 -bd 0 -anchor w	\
			] -column 1 -row $row -sticky we

			# Checkbutton "Bold"
			set checkbutton [checkbutton $instruction_tab.chbut_${tag_name}		\
				-pady 0 -highlightthickness 0					\
				-command "::configDialogues::rightPanel::change_style $idx 0"	\
			]
			if {$boldItalic} {
				$checkbutton select
			}
			grid $checkbutton -column 2 -row $row -sticky we

			# Button for selecting foreground color
			grid [button $instruction_tab.but_${tag_name}	\
				-bd 1 -relief raised -pady 0 -highlightthickness 0	\
				-bg $color -width 10 -activebackground $color		\
				-command "::configDialogues::rightPanel::select_color $idx $instruction_tab.but_${tag_name} 0"
			] -column 3 -row $row -sticky ns -padx 10


			incr row ;# Row in the grid
			incr idx ;# Current tag index
		}

		# Adjust the grid
		grid columnconfigure $instruction_tab 1 -minsize 150

		# Raise appropriate tab
		if {$tab_number == {}} {
			$nb raise watches_tab
		} else {
			$nb raise [lindex [$nb pages] $tab_number]
		}

		# Create button frame at the bottom
		set but_frame [frame $win.button_frame]
			# Button "Apply"
		set apply_button [ttk::button $but_frame.but_apply	\
			-state disabled					\
			-text [mc "Apply"]				\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::rightPanel::APPLY}	\
		]
		pack $apply_button -side left
			# Button "Ok"
		pack [ttk::button $but_frame.but_ok			\
			-text [mc "Ok"]					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::rightPanel::OK}	\
		] -side right -padx 2
			# Button "Cancel"
		pack [ttk::button $but_frame.but_cancel			\
			-text [mc "Cancel"]				\
			-compound left					\
			-image ::ICONS::16::button_cancel		\
			-command {::configDialogues::rightPanel::CANCEL}	\
		] -side right -padx 2

		# Pack frames and notebook
		pack $but_frame -side bottom -fill x -expand 0 -anchor s -padx 10 -pady 5
		pack $win.header_label -side top -pady 6
		pack [$nb get_nb] -side top -fill both -expand 1 -padx 10

		# Finalize creation of the dialog
		wm iconphoto $win ::ICONS::16::configure
		wm transient $win .
		wm title $win [mc "Configure right panel - %s" ${::APPNAME}]
		wm geometry $win =340x380
		wm resizable $win 0 0
		raise $win
		catch {grab $win}
		wm protocol $win WM_DELETE_WINDOW {
			::configDialogues::rightPanel::CANCEL
		}
		tkwait window $win
	}

	## Traslate tag name to human readable string
	 # @return String - result or {}
	proc tag2name {tag} {
		switch -- $tag {
			{tag_code8}	{return "code8"}
			{tag_code11}	{return "code11"}
			{tag_code16}	{return "code16"}
			{tag_imm8}	{return "imm8"}
			{tag_imm16}	{return "imm16"}
			{tag_data}	{return "data"}
			{tag_bit}	{return "bit"}
			{tag_DPTR}	{return "DPTR"}
			{tag_A}		{return "A"}
			{tag_AB}	{return "AB"}
			{tag_SFR}	{return "C, R0..R7"}
			{tag_indr}	{return "@R0, @R0[mc { etc.}]"}
			{tag_Baddr}	{return [mc "Bit"]}
			{tag_Xaddr}	{return "XDATA"}
			{tag_Eaddr}	{return "EDATA"}
			{tag_addr}	{return "IDATA"}
			{tag_name}	{return [mc "Name"]}
			default		{return {}}
		}
	}

	## Toggle style flag for given text tag (Bold <-> Italic / Roman)
	 # @parm Int row	- Index of the target text tag
	 # @parm Bool for	- 0 == instruction_tags; 1 == watch_text_tags
	 # @return void
	proc change_style {row for} {
		variable instruction_tags	;# Highlighting tags for instruction details
		variable watch_text_tags	;# Highlighting tags for register watches

		if {$for} {
			if {[lindex $watch_text_tags [list $row 2]] != 1} {
				lset watch_text_tags [list $row 2] 1
			} else {
				lset watch_text_tags [list $row 2] {}
			}
		} else {
			lset instruction_tags [list $row 2] [expr {!([lindex $instruction_tags [list $row 2]])}]
		}

		# Adjust status changed
		settings_changed
	}

	## Change color for given text tag and adjust given bg color of given button
	 # @parm Int row	- Index of the target text tag
	 # @parm Widget button	- ID of source button
	 # @parm Bool for	- 0 == instruction_tags; 1 == watch_text_tags
	 # @return void
	proc select_color {row button for} {
		variable instruction_tags	;# Highlighting tags for instruction details
		variable watch_text_tags	;# Highlighting tags for register watches
		variable win			;# ID of toplevel dialog window

		# Destroy prevoisly opened color selection dialog
		if {[winfo exists .select_color]} {
			destroy .select_color
		}

		# Invoke new color selection dialog
		if {$for} {
			set color [lindex $watch_text_tags [list $row 1]]
		} else {
			set color [lindex $instruction_tags [list $row 1]]
		}
		set color [SelectColor .select_color			\
			-parent $win					\
			-color $color					\
			-title [mc "Select color - %s" ${::APPNAME}]	\
		]

		# Change button background color
		if {$color != {}} {
			if {$for} {
				lset watch_text_tags [list $row 1] $color
			} else {
				lset instruction_tags [list $row 1] $color
			}
			$button configure -bg $color -activebackground $color

			# Adjust status changed
			settings_changed
		}
	}

	## Adjust all editors to fit new settings
	 # @return Bool - result
	proc apply_settings {} {
		# Check if there is at least 1 opened editor
		if {[llength ${::X::openedProjects}] == 0} {
			return 0
		}

		# Apply new settings in all projects
		foreach project ${::X::openedProjects} {
			$project rightPanel_refresh_instruction_highlighting
			$project rightPanel_refresh_regwatches_highlighting
		}

		# Done ...
		return 1
	}

	## Change content of configuration variables RightPanel NS
	 # @return void
	proc use_settings {} {
		variable watch_text_tags	;# Highlighting tags for register watches
		variable instruction_tags	;# Highlighting tags for instruction details

		set ::InstructionDetails::instruction_tags $instruction_tags
		set ::RegWatches::watch_text_tags $watch_text_tags
	}

	## Retrieve settings related to this dialog from the program
	 # @return void
	proc getSettings {} {
		variable instruction_tags	;# Highlighting tags for instruction details
		variable watch_text_tags	;# Highlighting tags for register watches

		set instruction_tags ${::InstructionDetails::instruction_tags}
		set watch_text_tags ${::RegWatches::watch_text_tags}
	}

	## Save configuration to config file
	 # @return void
	proc save_config {} {

		# Save configuration of "Instruction details"
		foreach item ${::InstructionDetails::instruction_tags} {
			# Save config
			set key [lindex $item 0]
			set value [lrange $item 1 end]
			::settings setValue "Instruction details/$key" $value
		}

		# Save configuration of "Register watches"
		foreach item ${::RegWatches::watch_text_tags} {
			# Save config
			set key [lindex $item 0]
			set value [lrange $item 1 end]
			::settings setValue "Register watches/$key" $value
		}

		# Commit
		::settings saveConfig
	}

	## Load configuratin from config file
	 # @return void
	proc load_config {} {
		variable instruction_tags	;# Highlighting tags for instruction details
		variable watch_text_tags	;# Highlighting tags for register watches

		set instruction_tags {}
		set watch_text_tags {}
		foreach item ${::InstructionDetails::instruction_tags} {
			# Load config
			set key [lindex $item 0]
			set value [lrange $item 1 end]
			set value [::settings getValue "Instruction details/$key" $value]
			lappend instruction_tags [concat $key $value]
		}
		foreach item ${::RegWatches::watch_text_tags} {
			# Load config
			set key [lindex $item 0]
			set value [lrange $item 1 end]
			set value [::settings getValue "Register watches/$key" $value]
			lappend watch_text_tags [concat $key $value]
		}
		set ::InstructionDetails::instruction_tags $instruction_tags
		set ::RegWatches::watch_text_tags $watch_text_tags
		unset instruction_tags
		unset watch_text_tags
	}

	## Set status changed to True
	 # @return true
	proc settings_changed {} {
		variable changed		;# Bool: Settings changed
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable apply_button		;# ID of button "Apply"

		if {$changed} {return}

		set changed 1
		set anything_modified 1
		$apply_button configure -state normal
	}

	## Take back changes and destroy dialog window
	 # @return void
	proc CANCEL {} {
		variable win			;# ID of dialog toplevel window
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable dialog_opened		;# Bool: True if this dialog is already opened

		# Restore previous configuration
		if {$anything_modified} {
			load_config
			apply_settings
			set anything_modified 0
		}

		# Get rid of dialog window
		set dialog_opened 0
		grab release $win
		destroy $win
	}

	## Apply changes and destroy dialog window
	 # @return void
	proc OK {} {
		variable win		;# ID of dialog toplevel window
		variable changed	;# Bool: Settings changed
		variable dialog_opened	;# Bool: True if this dialog is already opened

		# Apply new settings
		if {$changed} {
			use_settings	;# Adjust NS variables
			apply_settings	;# Adjust GUI
			save_config	;# Save new config
		}

		# Get rid of dialog window
		set dialog_opened 0
		grab release $win
		destroy $win
	}

	## Apply changes in GUI
	 # @return Bool - result
	proc APPLY {} {
		variable apply_button	;# ID of button "Apply"
		variable changed	;# Bool: Settings changed

		# Check if there is at least 1 opened editor
		if {[llength ${::X::openedProjects}] == 0} {
			return 0
		}

		# Reset status changed
		set changed 0
		$apply_button configure -state disabled

		# Adjust NS variables
		use_settings
		# Adjust GUI in current project
		${::X::actualProject} rightPanel_refresh_instruction_highlighting
		${::X::actualProject} rightPanel_refresh_regwatches_highlighting

		# done ...
		return 1
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

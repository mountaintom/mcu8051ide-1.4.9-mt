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
if { ! [ info exists _SIMULATOR_CONFIG_TCL ] } {
set _SIMULATOR_CONFIG_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements simulator configuration dialog
# --------------------------------------------------------------------------

namespace eval simulator {

	variable win			;# ID of toplevel dialog window
	variable dialog_opened	0	;# Bool: True if this dialog is already opened
	variable on_color_button	;# Widget: Button "ON color" in section "Colors"
	variable off_color_button	;# Widget: Button "OFF color" in section "Colors"

	# List of default settings
	variable defaults {
		{reverse_run_steps		10}
		{ignore_read_from_wr_only	0}
		{ignore_invalid_reti		0}
		{ignore_watchdog_reset		0}
		{ignore_stack_overflow		0}
		{ignore_stack_underflow		0}
		{ignore_invalid_ins		0}
		{ignore_invalid_IDATA		0}
		{ignore_invalid_XDATA		0}
		{ignore_invalid_BIT		0}
		{ignore_invalid_CODE		0}
		{ignore_EEPROM_WR_fail		0}
		{ignore_EEPROM_WR_abort		0}
		{ignore_invalid_USB		0}
		{ignore_invalid_UMC		0}
		{ignore_invalid_TMC		0}
		{undefined_value		2}
		{ignore_invalid_brkpoints	0}
		{on_color			#00CC00}
		{off_color			#DD0000}
	}

	# Option variables
	variable reverse_run_steps		;# Int: Number of steps which can be taken back
	variable ignore_watchdog_reset		;# Bool: Ignore reset invoked by watchdog overflow
	variable ignore_read_from_wr_only	;# Bool: Ignore reading from read only register
	variable ignore_stack_overflow		;# Bool: Do not show "Stack overflow" dialog
	variable ignore_stack_underflow		;# Bool: Do not show "Stack underflow" dialog
	variable ignore_invalid_reti		;# Bool: Ignore invalid return fom interrupt
	variable ignore_invalid_ins		;# Bool: Ignore invalid instructions
	variable ignore_invalid_IDATA		;# Bool: Ignore access to unimplemented IDATA memory
	variable ignore_invalid_XDATA		;# Bool: Ignore access to unimplemented XDATA memory
	variable ignore_invalid_BIT		;# Bool: Ignore access to unimplemented bit
	variable ignore_invalid_CODE		;# Bool: Ignore access to unimplemented CODE memory
	variable ignore_EEPROM_WR_fail		;# Bool: Ignore EEPROM write failure
	variable ignore_EEPROM_WR_abort		;# Bool: Ignore EEPROM write abort
	variable ignore_invalid_USB		;# Bool: Ignore UART frame discart
	variable ignore_invalid_UMC		;# Bool: Ignore invalid UART mode change
	variable ignore_invalid_TMC		;# Bool: Ignore invalid Timer/Counter mode change
	variable undefined_value		;# Int: How to handle undefined values (0 == 0; 1 == 255; 2 == random)
	variable ignore_invalid_brkpoints	;# Bool: Do not warn user about invalid (unreachable) breakpoints
	variable on_color			;# RGB: Color to display a bit name for a bit set to log. 1
	variable off_color			;# RGB: Color to display a bit name for a bit set to log. 0

	## Create the dialog
	 # @return void
	proc mkDialog {} {
		variable win			;# ID of toplevel dialog window
		variable dialog_opened		;# Bool: True if this dialog is already opened
		variable on_color_button	;# Widget: Button "ON color" in section "Colors"
		variable off_color_button	;# Widget: Button "OFF color" in section "Colors"

		# Destroy the dialog if it's already opened
		if {$dialog_opened} {
			destroy .simulator_config_dialog
		}
		set dialog_opened 1

		# Get settings from Compiler NS
		getSettings

		# Create toplevel window
		set win [toplevel .simulator_config_dialog -class {Configuration dialog} -bg ${::COMMON_BG_COLOR}]

		# Create window header
		label $win.header_label				\
			-compound left				\
			-image ::ICONS::32::kcmmemory		\
			-text [mc "Simulator configuration"]	\
			-font [font create	\
				-size -20]

		## Create notebook
		set nb [ModernNoteBook $win.nb]
		 # Tab "Warning dialogues"
		set warnings_tab [$nb insert end warnings_tab -text [mc "Warning dialogues"]]
		
		  # Tab "Other"
		set other_tab [$nb insert end other_tab -text [mc "Other"]]

		#
		## Tab "Warning dialogues"
		#
		set row 0
		foreach text {
				{Ignore stack overflow}
				{Ignore stack underflow}
				{-}
				{Ignore invalid instructions}
				{Ignore watchdog overflow}
				{Ignore invalid return from interrupt}
				{Ignore reading from write only register}
				{-}
				{Ignore invalid access to IDATA/SFR}
				{Ignore invalid access to EDATA}
				{Ignore invalid access to XDATA}
				{Ignore invalid access to bit}
				{Ignore invalid access to CODE}
				{-}
				{Ignore EEPROM write failure}
				{Ignore EEPROM write abort}
				{-}
				{Ignore UART frame discard}
				{Ignore illegal UART mode change}
				{Ignore illegal Timer/Counter mode change}
				{-}
				{Do not complain about invalid breakpoints}
			} helptext {
				{Check this to disable warning on stack overflow}
				{Check this to disable warning on stack underflow}
				{-}
				{Check this to disable warning on\ninvalid instruction}
				{Do not stop simulation on device reset\ninvoked by watchdog timer overflow}
				{Do not show warning dialog when program trying to return from interrupt which has not been invoked}
				{Do not display warning dialog when\nreading from write-only register}
				{-}
				{Do not display dialog "Undefined result" when simulated program\naccessing unimplemented Internal Data Memory (IDATA) or SFR area}
				{Do not display dialog "Undefined result" when simulated program\naccessing unimplemented Expanded Data Memory (EDATA)}
				{Do not display dialog "Undefined result" when simulated program\naccessing unimplemented External Data Memory (XDATA)}
				{Do not display dialog "Undefined result" when simulated program\naccessing unimplemented bit in IDATA or SFR area}
				{Do not display dialog "Undefined result" when simulated program\naccessing unimplemented Program Memory (CODE)}
				{-}
				{Check this to disable warning on\ndata eeprom write failure}
				{Check this to disable warning on\ndata eeprom write abort}
				{-}
				{Check this to disable warning on UART frame discard}
				{Check this to disable warning on illegal UART mode change}
				{Check this to disable warning on illegal Timer/Counter mode change}
				{-}
				{Disable warning: "warning: Invalid breakpoint"}
			} variable {
				ignore_stack_overflow	ignore_stack_underflow
				-
				ignore_invalid_ins	ignore_watchdog_reset
				ignore_invalid_reti	ignore_read_from_wr_only
				-
				ignore_invalid_IDATA	ignore_invalid_EDATA
				ignore_invalid_XDATA	ignore_invalid_BIT
				ignore_invalid_CODE
				-
				ignore_EEPROM_WR_fail	ignore_EEPROM_WR_abort
				-
				ignore_invalid_USB	ignore_invalid_UMC
				ignore_invalid_TMC
				-
				ignore_invalid_brkpoints
		} {
			incr row

			# Create separator
			if {$text == {-}} {
				grid [ttk::separator $warnings_tab.sep_$row	\
					-orient horizontal			\
				] -column 0 -row $row -columnspan 2 -sticky we -pady 5 -padx 5
				continue
			}

			# Create
			grid [Label $warnings_tab.label__$row		\
				-text [mc $text]			\
				-helptext [subst [mc $helptext]]	\
			] -row $row -column 0 -sticky w -padx 5
			grid [checkbutton $warnings_tab.chbutton_$row		\
				-variable ::configDialogues::simulator::$variable	\
			] -row $row -column 1 -sticky e -padx 5
			DynamicHelp::add $warnings_tab.chbutton_$row	\
				-text [subst $helptext]
		}
		grid columnconfigure $warnings_tab 0 -minsize 250
		grid columnconfigure $warnings_tab 1 -weight 1

		#
		# Tab "Other"
		#

		# LabelFrame: "Undefined values"
		set undefined_labelframe [ttk::labelframe $other_tab.undefined_labelframe	\
			-text [mc "Undefined values"] -padding 7				\
		]
		pack [radiobutton $undefined_labelframe.random			\
			-value 2 -text [mc "Return random value"]		\
			-variable ::configDialogues::simulator::undefined_value	\
		] -anchor w
		pack [radiobutton $undefined_labelframe.zero			\
			-value 0 -text [mc "Return zero value"]			\
			-variable ::configDialogues::simulator::undefined_value	\
		] -anchor w
		pack [radiobutton $undefined_labelframe.one			\
			-value 1 -text [mc "Return highest possible value"]	\
			-variable ::configDialogues::simulator::undefined_value	\
		] -anchor w
		pack $undefined_labelframe -fill x -padx 5 -pady 5

		# LabelFrame: "Reverse run"
		set reverse_run_labelframe [ttk::labelframe $other_tab.reverse_run_labelframe	\
			-text [mc "Reverse run"] -padding 7					\
		]
		grid [Label $reverse_run_labelframe.rrun_lbl				\
			-text [mc "Stack capacity"]					\
			-helptext [mc "Number of steps which can be taken back"]	\
		] -row 4 -column 0 -sticky w -padx 5
		grid [ttk::spinbox $reverse_run_labelframe.rrun_spinbox				\
			-from 0 -to 1000 -validate all -width 4					\
			-validatecommand "::configDialogues::simulator::rrun_spinbox_val %P"	\
			-textvariable ::configDialogues::simulator::reverse_run_steps		\
		] -row 4 -column 1 -sticky we -padx 5
		DynamicHelp::add $reverse_run_labelframe.rrun_spinbox	\
			-text [mc "Number of steps which can be taken back"]
		grid columnconfigure $reverse_run_labelframe 0 -minsize 250
		grid columnconfigure $reverse_run_labelframe 1 -weight 1
		pack $reverse_run_labelframe -fill x -padx 5 -pady 5

		# LabelFrame: "Colors"
		set colors_labelframe [ttk::labelframe $other_tab.colors_labelframe	\
			-text [mc "Colors"] -padding 7					\
		]
		set row -1
		foreach text {
			{ON color}
			{OFF color}
		} helptext {
			{Color to display a bit name for a bit set to log. 1}
			{Color to display a bit name for a bit set to log. 0}
		} variable {
			on_color
			off_color
		} buttonvar {
			on_color_button
			off_color_button
		} {
			incr row

			set text [mc $text]
			set helptext [mc $helptext]
			set variable "::configDialogues::simulator::$variable"

			# Get color from the given variable
			set color [subst -nocommands "\${$variable}"]

			# Create label
			grid [Label $colors_labelframe.lbl$row	\
				-text $text			\
				-helptext $helptext		\
			] -row $row -column 0 -sticky w -padx 5

			# Create button
			set button [button $colors_labelframe.button$row		\
				-bd 1 -relief raised -pady 0 -highlightthickness 0	\
				-bg $color -width 10 -activebackground $color		\
				-command "::configDialogues::simulator::select_color $variable $colors_labelframe.button$row"
			]
			grid $button -row $row -column 1 -sticky we -padx 5
			set $buttonvar $button
			DynamicHelp::add $colors_labelframe.button$row -text $helptext
		}
		grid columnconfigure $colors_labelframe 0 -minsize 250
		grid columnconfigure $colors_labelframe 1 -weight 1
		pack $colors_labelframe -fill x -padx 5 -pady 5

		# Raise tab "Output"
		$nb raise warnings_tab

		# Create button frame at the bottom
		set but_frame [frame $win.button_frame]
		 # Button "Defaults"
		pack [ttk::button $but_frame.but_default			\
			-text [mc "Defaults"]					\
			-command {::configDialogues::simulator::DEFAULTS}		\
		] -side left
		DynamicHelp::add $but_frame.but_default -text [mc "Reset settings to defaults"]
		 # Button "Ok"
		pack [ttk::button $but_frame.but_ok			\
			-text [mc "Ok"]					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::simulator::OK}	\
		] -side right -padx 2
		 # Button "Cancel"
		pack [ttk::button $but_frame.but_cancel			\
			-text [mc "Cancel"]				\
			-compound left					\
			-image ::ICONS::16::button_cancel		\
			-command {::configDialogues::simulator::CANCEL}	\
		] -side right -padx 2

		# Pack frames and notebook
		pack $win.header_label -side top -pady 6
		pack [$nb get_nb] -side top -fill both -expand 1 -padx 10
		pack $but_frame -side top -fill x -anchor s -padx 10 -pady 5

		# Set window attributes
		wm iconphoto $win ::ICONS::16::configure
		wm transient $win .
		wm title $win [mc "Simulator configuration - %s" ${::APPNAME}]
		wm minsize $win 380 520
		raise $win
		catch {grab $win}
		wm protocol $win WM_DELETE_WINDOW {
			::configDialogues::simulator::CANCEL
		}
		tkwait window $win
	}

	## Select some color (command for buttons in labelbox "Colors")
	 # @parm Variable variable	- variable containing current color (format RGB)
	 # @parm Widget button		- ID of button which invoked this procedure
	 # @return void
	proc select_color {variable button} {
		variable win	;# ID of dialog toplevel window

		# Destroy previously opened color selection dialog
		if {[winfo exists .select_color]} {
			destroy .select_color
		}

		# Invoke new color selection dialog
		set color [subst -nocommands "\$$variable"]
		set color [SelectColor .select_color			\
			-parent $win					\
			-color $color					\
			-title [mc "Select color - %s" ${::APPNAME}]	\
		]

		# Set new content of the given variable and button background color
		if {$color != {}} {
			set $variable $color
			$button configure -bg $color -activebackground $color
		}
	}

	## Validate contents of spinbox in section "Reverse Run"
	 # @parm String content - String to validate
	 # @return Bool - validation result (0 == failed; 1 == successfull)
	proc rrun_spinbox_val {content} {
		if {![string is digit $content]} {
			return 0
		}
		if {$content > 1000} {
			return 0
		}
		return 1
	}

	## Set configuration variable
	 # This function is unsafe -- you must be sure by the given arguments
	 # @parm String variable	- variable to set
	 # @parm Mixed value		- new value
	proc set_variable {variable value} {
		variable reverse_run_steps		;# Int: Number of steps which can be taken back
		variable ignore_watchdog_reset		;# Bool: Ignore reset invoked by watchdog overflow
		variable ignore_read_from_wr_only	;# Bool: Ignore reading from read only register
		variable ignore_invalid_reti		;# Bool: Ignore invalid return fom interrupt
		variable ignore_stack_overflow		;# Bool: Do not show "Stack overflow" dialog
		variable ignore_stack_underflow		;# Bool: Do not show "Stack underflow" dialog
		variable ignore_invalid_ins		;# Bool: Ignore invalid instructions
		variable ignore_invalid_IDATA		;# Bool: Ignore access to unimplemented IDATA memory
		variable ignore_invalid_EDATA		;# Bool: Ignore access to unimplemented EDATA memory
		variable ignore_invalid_XDATA		;# Bool: Ignore access to unimplemented XDATA memory
		variable ignore_invalid_BIT		;# Bool: Ignore access to unimplemented bit
		variable ignore_invalid_CODE		;# Bool: Ignore access to unimplemented CODE memory
		variable ignore_EEPROM_WR_fail		;# Bool: Ignore EEPROM write failure
		variable ignore_EEPROM_WR_abort		;# Bool: Ignore EEPROM write abort
		variable undefined_value		;# Int: How to handle undefined values (0 == 0; 1 == 255; 2 == random)
		variable ignore_invalid_brkpoints	;# Bool: Do not warn user about invalid (unreachable) breakpoints

		getSettings
		set $variable $value
		use_settings
		save_config
	}

	## Retrieve settings from simulator NS
	 # @return void
	proc getSettings {} {
		variable defaults		;# List of default settings

		# Set local option variables
		foreach var $defaults {
			set var [lindex $var 0]
			if {$var == {on_color} || $var == {off_color}} {
				set ::configDialogues::simulator::${var} [subst -nocommands "\$::Simulator_GUI::${var}"]
			} else {
				set ::configDialogues::simulator::${var} [subst -nocommands "\$::Simulator::${var}"]
			}
		}
	}

	## Set simulator according to local settings
	 # @return void
	proc use_settings {} {
		variable reverse_run_steps	;# Int: Number of steps which can be taken back
		variable defaults		;# List of default settings

		# Adjust RR stack capacity
		if {$reverse_run_steps == {}} {
			set reverse_run_steps 0
		}

		# Set option variables
		foreach var $defaults {
			set var [lindex $var 0]
			if {$var == {on_color} || $var == {off_color}} {
				set ::Simulator_GUI::$var [subst -nocommands "\$::configDialogues::simulator::${var}"]
			} else {
				set ::Simulator::$var [subst -nocommands "\$::configDialogues::simulator::${var}"]
			}
		}
	}

	## Save settings to the config file
	 # @return void
	proc save_config {} {
		variable defaults	;# List of default settings

		# Save option variables
		foreach var $defaults {
			set var [lindex $var 0]
			if {$var == {on_color} || $var == {off_color}} {
				::settings setValue "Simulator/$var" [subst -nocommands "\$::Simulator_GUI::${var}"]
			} else {
				::settings setValue "Simulator/$var" [subst -nocommands "\$::Simulator::${var}"]
			}
		}

		# Synchronize
		::settings saveConfig
	}

	## Load settings from config file
	 # @return void
	proc load_config {} {
		variable defaults	;# List of default settings

		# Load normal options
		foreach item $defaults {
			set var [lindex $item 0]
			set val [lindex $item 1]
			if {$var == {on_color} || $var == {off_color}} {
				set ::Simulator_GUI::${var} [::settings getValue "Simulator/$var" $val]
			} else {
				set ::Simulator::${var} [::settings getValue "Simulator/$var" $val]
			}
		}
	}

	## Destroy the dialog
	 # @return void
	proc CANCEL {} {
		variable win		;# ID of toplevel dialog window
		variable dialog_opened	;# Bool: True if this dialog is already opened

		# Destroy dialog window
		set dialog_opened 0
		grab release $win
		destroy $win
	}

	## Use settings and destroy the dialog
	 # @return void
	proc OK {} {
		# Use and save settings
		use_settings
		save_config

		# Destroy dialog window
		CANCEL
	}

	## Restrore defaults
	 # @return void
	proc DEFAULTS {} {
		variable win			;# ID of toplevel dialog window
		variable defaults		;# List of default settings
		variable on_color_button	;# Widget: Button "ON color" in section "Colors"
		variable off_color_button	;# Widget: Button "OFF color" in section "Colors"

		if {[tk_messageBox		\
			-parent $win		\
			-type yesno		\
			-icon question		\
			-title [mc "Are you sure ?"]	\
			-message [mc "Are you sure you want to restore default settings"]	\
		] != {yes}} {
			return
		}

		# Restore normal options
		foreach item $defaults {
			set var [lindex $item 0]
			set val [lindex $item 1]
			set ::configDialogues::simulator::${var} $val

			# Update colors of color buttons
			if {$var == {on_color}} {
				$on_color_button configure -bg $val -activebackground $val
			} elseif {$var == {off_color}} {
				$off_color_button configure -bg $val -activebackground $val
			}
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

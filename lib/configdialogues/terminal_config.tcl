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
if { ! [ info exists _TERMINAL_CONFIG_TCL ] } {
set _TERMINAL_CONFIG_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements terminal configuration dialog
# --------------------------------------------------------------------------

namespace eval terminal {
	variable dialog_opened	0	;# Bool: True if this dialog is already opened
	variable win			;# ID of dialog toplevel window
	variable changed	0	;# Bool: Settings changed
	variable example_text		;# Widget: Label widget containing example text
	variable selected_font		;# Font: Current font
	variable fg_clr_but		;# Widget: Button for selecting foreground color
	variable bg_clr_but		;# Widget: Button for selecting background color

	## Configuration variables
	variable configuration		;# Array: Configuration array

	## Create the dialog
	 # @return void
	proc mkDialog {} {
		variable win		;# ID of toplevel dialog window
		variable dialog_opened	;# Bool: True if this dialog is already opened
		variable configuration	;# Array: Configuration array
		variable changed	;# Bool: Settings changed
		variable example_text	;# Widget: Label widget containing example text
		variable selected_font	;# Font: Current font
		variable fg_clr_but	;# Widget: Button for selecting foreground color
		variable bg_clr_but	;# Widget: Button for selecting background color

		# Destroy the dialog if it's already opened
		if {$dialog_opened} {
			destroy .terminal_config_dialog
		}

		set dialog_opened 1
		set changed 0

		# Get settings from main NS
		getSettings

		# Create toplevel window
		set win [toplevel .terminal_config_dialog -class {Configuration dialog} -bg ${::COMMON_BG_COLOR}]

		# Create window header
		label $win.header_label				\
			-text [mc "Terminal configuration"]	\
			-font [font create -size [expr {int(-20 * $::font_size_factor)}]]

		# Create horizontal separator
		Separator $win.sep -orient horizontal

		## Create main frame
		set main_frame [frame $win.main_frame]
		set row 0
			# Foreground color
		grid [label $main_frame.fg_lbl		\
			-text [mc "Foreground color"]	\
		] -row $row -column 0 -sticky w
		set fg_clr_but [button $main_frame.fg_but	\
			-bd 1 -relief raised -pady 0 -width 10	\
			-bg $configuration(fg)			\
			-activebackground $configuration(fg)	\
			-command "::configDialogues::terminal::select_color {foreground} fg $main_frame.fg_but"	\
		]
		grid $fg_clr_but -column 1 -row $row -sticky wens
		incr row
			# Background color
		grid [label $main_frame.bg_lbl		\
			-text [mc "Background color"]	\
		] -row $row -column 0 -sticky w
		set bg_clr_but [button $main_frame.bg_but	\
			-bd 1 -relief raised -pady 0 -width 10	\
			-bg $configuration(bg)			\
			-activebackground $configuration(bg)	\
			-command "::configDialogues::terminal::select_color {background} bg $main_frame.bg_but"	\
		]
		grid $bg_clr_but -column 1 -row $row -sticky wens
		incr row
			# Font size
		grid [label $main_frame.font_size_lbl	\
			-text [mc "Font size"]		\
		] -row $row -column 0 -sticky w
		grid [ttk::spinbox $main_frame.font_size_spb					\
			-from 4 -to 22 -validate all -width 0					\
			-validatecommand {::configDialogues::terminal::font_size_valiade %P}	\
			-textvariable ::configDialogues::terminal::configuration(font_size)	\
			-command ::configDialogues::terminal::font_changed			\
		] -row $row -column 1 -sticky we
		incr row
			# Font family
		grid [label $main_frame.font_family_lbl	\
			-text [mc "Font family"]	\
		] -row $row -column 0 -sticky w
		grid [ttk::combobox $main_frame.font_family_cbx					\
			-state readonly								\
			-values [lsort [font families]]						\
			-width 20								\
			-textvariable ::configDialogues::terminal::configuration(font_family)	\
		] -row $row -column 1 -sticky we
		bind $main_frame.font_family_cbx <<ComboboxSelected>>	\
			{::configDialogues::terminal::font_changed}
		incr row
			# Example text
		set selected_font [font create			\
			-family $configuration(font_family)	\
			-size -$configuration(font_size)	\
		]
		set example_text [label $main_frame.example_text_lbl	\
			-text "rxvt-unicode "	\
			-font $selected_font	\
		]
		grid $example_text -row $row -column 0 -sticky w -columnspan 2
			# Finalize
		grid columnconfigure $main_frame 0 -weight 1

		# Button "Restart terminal emulator"
		set restart_but [ttk::button $win.restart_but			\
			-text [mc "Use settings and restart terminal emulator"]	\
			-compound left						\
			-image ::ICONS::16::reload				\
			-command {::configDialogues::terminal::RESTART}		\
		]

		## Button frame at the bottom
		set but_frame [frame $win.button_frame]
			# Button "Reset"
		pack [ttk::button $but_frame.but_default		\
			-text [mc "Reset to defaults"]			\
			-command {::configDialogues::terminal::DEFAULTS}	\
		] -side left
		DynamicHelp::add $but_frame.but_default	\
			-text [mc "Reset all settings to defaults"]
			# Button "Ok"
		pack [ttk::button $but_frame.but_ok			\
			-text [mc "Ok"]					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::terminal::OK}	\
		] -side right -padx 2
		DynamicHelp::add $but_frame.but_ok	\
			-text [mc "Commit new settings"]
			# Button "Cancel"
		pack [ttk::button $but_frame.but_cancel			\
			-text [mc "Cancel"]				\
			-compound left					\
			-image ::ICONS::16::button_cancel		\
			-command {::configDialogues::terminal::CANCEL}	\
		] -side right -padx 2
		DynamicHelp::add $but_frame.but_cancel	\
			-text [mc "Take changes back and close dialog"]

		# Pack frames and notebook
		pack $win.header_label -side top -pady 6
		pack $win.sep -side top -fill x -after $win.header_label
		pack $main_frame -side top -padx 10 -anchor nw -pady 10 -fill x
		pack $but_frame -side bottom -fill x -anchor s -padx 10 -pady 5
		pack $restart_but -side bottom -fill x -expand 1 -anchor s -padx 10

		# Set window attributes
		wm iconphoto $win ::ICONS::16::configure
		wm transient $win .
		wm title $win [mc "Configure terminal emulator"]
		wm minsize $win 380 280
		raise $win
		catch {grab $win}
		wm protocol $win WM_DELETE_WINDOW {
			::configDialogues::terminal::CANCEL
		}
		tkwait window $win
	}

	## Valiadte content of font size spinbox
	 # @pamr String content - String to valiadte
	 # @return void
	proc font_size_valiade {content} {
		if {$content == {}} {
			return 1
		}
		if {![string is digit $content]} {
			return 0
		}
		if {$content > 22} {
			return 0
		}
		after idle {
			::configDialogues::terminal::font_changed
		}
		return 1
	}

	## Change font for example text
	 # @return void
	proc font_changed {} {
		variable configuration	;# Array: Configuration array
		variable example_text	;# Widget: Label widget containing example text
		variable selected_font	;# Font: Current font
		variable changed	;# Bool: Settings changed

		if {$configuration(font_size) == {} || $configuration(font_size) < 4} {
			return
		}

		font delete $selected_font
		set selected_font [font create			\
			-family $configuration(font_family)	\
			-size -$configuration(font_size)	\
		]
		$example_text configure -font $selected_font
		set changed 1
	}

	## Select color
	 # @parm String what_clr	- What color (foreground / background ...)
	 # @parm String var		- Key in configuration array
	 # @parm Widget button		- Source button
	 # @return void
	proc select_color {what_clr var button} {
		variable configuration	;# Array: Configuration array
		variable win		;# ID of toplevel dialog window
		variable changed	;# Bool: Settings changed

		switch -- $what_clr {
			{foreground} {
				set txt [mc "Select foreground color"]
			}
			{background} {
				set txt [mc "Select background color"]
			}
		}

		set color [SelectColor .select_color	\
			-parent $win			\
			-color $configuration($var)	\
			-title $txt			\
		]

		# Set new content of the given variable and button background color
		if {$color != {}} {
			set configuration($var) $color
			$button configure -bg $color -activebackground $color

			# Adjust status changed
			set changed 1
		}
	}

	## Retrieve settings from main NS
	 # @return void
	proc getSettings {} {
		variable configuration	;# Array: Configuration array
		array set configuration [array get ::Terminal::configuration]
	}

	## Set application according to local settings
	 # @return void
	proc use_settings {} {
		variable configuration	;# Array: Configuration array
		if {$configuration(font_size) == {} || $configuration(font_size) < 4} {
			set configuration(font_size) 13
		}
		array set ::Terminal::configuration [array get configuration]
	}

	## Save settings to the config file
	 # @return void
	proc save_config {} {
		variable configuration	;# Array: Configuration array

		foreach key [array names configuration] {
			::settings setValue "Terminal emulator/$key" $::Terminal::configuration($key)
		}

		::settings saveConfig
	}

	## Load configuration from config file
	 # @return void
	proc load_config {} {
		# Load configuration
		array set default_conf ${::Terminal::configuration_def}
		foreach key [array names ::Terminal::configuration] {
			set ::Terminal::configuration($key) [::settings getValue	\
				"Terminal emulator/$key" $default_conf($key)		\
			]
		}

		# Validate configuration
		if {![regexp {^#[0-9a-fA-F]{6,12}$} ${::Terminal::configuration(bg)}]} {
			puts stderr [mc "Invalid value of key: '%s'" {bg}]
			set ::Terminal::configuration(bg) {#FFFFFF}
		}
		if {![regexp {^#[0-9a-fA-F]{6,12}$} ${::Terminal::configuration(fg)}]} {
			puts stderr [mc "Invalid value of key: '%s'" {fg}]
			set ::Terminal::configuration(fg) {#000000}
		}
		if {
			![regexp {^\d+$} ${::Terminal::configuration(font_size)}]
				||
			${::Terminal::configuration(font_size)} < 4
				||
			${::Terminal::configuration(font_size)} > 22
		} then {
			puts stderr [mc "Invalid value of key: '%s'" {font_size}]
			set ::Terminal::configuration(font_size) 13
		}
		if {![string length [string trim ${::Terminal::configuration(font_family)}]]} {
			puts stderr [mc "Invalid value of key: '%s'" {font_family}]
			set ::Terminal::configuration(font_family) $::DEFAULT_FIXED_FONT
		}
	}

	## Resart terminal emulators for all projects
	 # @return void
	proc RESTART {} {
		use_settings
		foreach project ${::X::openedProjects} {
			$project terminal_restart
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
		variable win		;# ID of toplevel dialog window
		variable changed	;# Bool: Settings changed

		# Use and save settings
		if {$changed} {
			use_settings
			save_config
		}

		# Destroy dialog window
		CANCEL
	}

	## Restrore defaults
	 # @return void
	proc DEFAULTS {} {
		variable configuration	;# Array: Configuration array
		variable fg_clr_but	;# Widget: Button for selecting foreground color
		variable bg_clr_but	;# Widget: Button for selecting background color

		array set configuration ${::Terminal::configuration_def}
		$fg_clr_but configure		\
			-bg $configuration(fg)	\
			-activebackground $configuration(fg)
		$bg_clr_but configure		\
			-bg $configuration(bg)	\
			-activebackground $configuration(bg)
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

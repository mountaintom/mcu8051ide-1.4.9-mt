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
if { ! [ info exists _CUSTOM_COMMANDS_CONFIG_TCL ] } {
set _CUSTOM_COMMANDS_CONFIG_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements custom commands configuration dialog
# --------------------------------------------------------------------------

namespace eval custom_commands {
	variable win			;# ID of toplevel dialog window
	variable dialog_opened	0	;# Bool: True if this dialog is already opened

	# Font for text widgets
	variable cmd_font [font create				\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
	]

	variable text_0		;# ID of text widget for command 0
	variable text_1		;# ID of text widget for command 1
	variable text_2		;# ID of text widget for command 2

	variable description	;# Array: Command description (-textvariable) (idx: 0..2)
	variable cmfr_dialog	;# Array of Bool: Variable for checkbutton "Confirmation dialog"
	variable results_dialog	;# Array of Bool: Variable for checkbutton "Show results"
	variable ignore_errors	;# Array of Bool: Variable for checkbutton "Ignore errors"
	variable run_in_term	;# Array of Bool: Variable for checkbutton "Ignore errors"

	## Create the dialog
	 # @parm Int tab_number=0 - number of tab to raise
	 # @return void
	proc mkDialog {{tab_number 0}} {
		variable win		;# ID of toplevel dialog window
		variable dialog_opened	;# Bool: True if this dialog is already opened
		variable cmd_font	;# Font for text widgets

		variable text_0		;# ID of text widget for command 0
		variable text_1		;# ID of text widget for command 1
		variable text_2		;# ID of text widget for command 2

		variable description	;# Array: Command description (-textvariable) (idx: 0..2)
		variable cmfr_dialog	;# Array of Bool: Variable for checkbutton "Confirmation dialog"
		variable results_dialog	;# Array of Bool: Variable for checkbutton "Show results"
		variable ignore_errors	;# Array of Bool: Variable for checkbutton "Ignore errors"
		variable run_in_term	;# Array of Bool: Variable for checkbutton "Ignore errors"

		# Destroy the dialog if it's already opened
		if {$dialog_opened} {
			destroy .custom_commands_config_dialog
		}
		set dialog_opened 1

		# Create toplevel window
		set win [toplevel .custom_commands_config_dialog -class {Configuration dialog} -bg ${::COMMON_BG_COLOR}]

		# Create window header
		label $win.header_label			\
			-compound left			\
			-image ::ICONS::22::gear	\
			-text [mc "Edit custom commands"]	\
			-font [font create -size [expr {int(-20 * $::font_size_factor)}]]

		# Create notebook
		set nb [ModernNoteBook $win.nb]

		# Create notebook tabs
		for {set idx 0} {$idx < 3} {incr idx} {
			# Create tab
			set tab [$nb insert end tab_$idx -image ::ICONS::22::gear$idx]			

			# Create "Short description" (entry and label)
			pack [Label $tab.desc_label		\
				-text [mc "Short description"]	\
				-helptext [mc "This string will be used as status bar tip (max. 100 chars)"]
			] -anchor w -padx 5 -pady 5
			pack [ttk::entry $tab.desc_entry						\
				-validate key								\
				-textvariable ::configDialogues::custom_commands::description($idx)	\
				-validatecommand {::configDialogues::custom_commands::desc_validate %P}	\
			] -fill x -padx 5

			## Create options labelframe
			label $tab.labelframe_label -compound left -image ::ICONS::16::configure -text [mc "Options"]
			set frame [ttk::labelframe $tab.labelframe -labelwidget $tab.labelframe_label]
			 # Create checkbutton "Confirmation dialog"
			set button [checkbutton $frame.cmfr_cbutton -anchor w			\
				-text [mc "Confirmation dialog"]				\
				-variable ::configDialogues::custom_commands::cmfr_dialog($idx)	\
			]
			grid $button -sticky w -row 1 -column 1 -padx 5 -pady 2
			DynamicHelp::add $button -text [mc "Invoke dialog to confirm command execution."]
			 # Create checkbutton "Show results"
			set button [checkbutton $frame.results_cbutton					\
				-text [mc "Show results"] -anchor w					\
				-variable ::configDialogues::custom_commands::results_dialog($idx)	\
			]
			grid $button -sticky w -row 2 -column 1 -padx 5 -pady 2
			DynamicHelp::add $button -text [mc "After finish show dialog with results."]
			 # Create checkbutton "Ignore errors"
			set button [checkbutton $frame.ignore_cbutton				\
				-text [mc "Ignore errors"] -anchor w				\
				-variable ::configDialogues::custom_commands::ignore_errors($idx)	\
			]
			grid $button -sticky w -row 1 -column 2 -padx 5 -pady 2
			DynamicHelp::add $button -text [mc "Do not invoke error dialog if the process fails."]
			 # Create checkbutton "Run in terminal"
			set button [checkbutton $frame.run_in_term_button				\
				-text [mc "Run in terminal"] -anchor w					\
				-variable ::configDialogues::custom_commands::run_in_term($idx)	\
			]
			grid $button -sticky w -row 2 -column 2 -padx 5 -pady 2
			DynamicHelp::add $button -text [mc "Run interactively in terminal emulator."]
			if {!$::PROGRAM_AVAILABLE(urxvt)} {
				$button configure -state disabled
			}
			pack $frame -fill x -pady 10 -padx 5

			# Create label "Commands to execute" and help button
			set frame [frame $tab.cmd_label_frame]
			pack [label $frame.label			\
				-text [mc "Bash script to execute."]	\
			] -side left -padx 5
			pack [ttk::button $frame.button					\
				-image ::ICONS::16::help				\
				-style Flat.TButton					\
				-command {::configDialogues::custom_commands::show_help}	\
			] -side right
			DynamicHelp::add $frame.button	\
				-text [mc "Show help"]
			pack $frame -fill x

			# Create text for entering commands
			set frame [frame $tab.text_frame]
			set text [text $frame.text			\
				-background {#FFFFFF}			\
				-width 1 -height 1			\
				-font $cmd_font -undo 1			\
				-yscrollcommand "$frame.scrollbar set"	\
			]
			pack $text -side left -fill both -expand 1
			pack [ttk::scrollbar $frame.scrollbar	\
				-orient vertical		\
				-command "$text yview"		\
			] -side right -fill y
			pack $frame -fill both -expand 1 -padx 5

			# Set NS variable -- text widget reference
			set text_$idx $text

			# Get settins from the program
			if {[regexp {\s*[01]\s+[01]\s+[01]\s+[01]\s*} $::X::custom_command_options($idx)]} {
				set cmfr_dialog($idx)		[lindex $::X::custom_command_options($idx) 0]
				set results_dialog($idx)	[lindex $::X::custom_command_options($idx) 1]
				set ignore_errors($idx)		[lindex $::X::custom_command_options($idx) 2]
				set run_in_term($idx)		[lindex $::X::custom_command_options($idx) 3]
			}

			set description($idx) $::X::custom_command_desc($idx)
			$text insert end $::X::custom_command_cmd($idx)
		}

		# Raise tab
		$nb raise [lindex [$nb pages] $tab_number]

		# Create button frame at the bottom
		set but_frame [frame $win.button_frame]
			# Button "Ok"
		pack [ttk::button $but_frame.but_ok			\
			-text [mc "Ok"]					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::custom_commands::OK}	\
		] -side right -padx 2 -pady 2
			# Button "Cancel"
		pack [ttk::button $but_frame.but_cancel				\
			-text [mc "Cancel"]					\
			-compound left						\
			-image ::ICONS::16::button_cancel			\
			-command {::configDialogues::custom_commands::CANCEL}	\
		] -side right -padx 2 -pady 2

		# Pack frames and notebook
		pack $but_frame -side bottom -fill x -expand 0 -anchor s -padx 10 -pady 5
		pack $win.header_label -side top -pady 6
		pack [$nb get_nb] -side top -fill both -expand 1 -padx 10

		# Finalize dialog creation
		wm iconphoto $win ::ICONS::16::configure
		wm transient $win .
		wm title $win [mc "Edit custom commands - %s" ${::APPNAME}]
		wm minsize $win 460 400
		raise $win
		catch {grab $win}
		wm protocol $win WM_DELETE_WINDOW {
			::configDialogues::custom_commands::CANCEL
		}
		tkwait window $win
	}

	## Show help window
	 # @return void
	proc show_help {} {
		# Destroy previous help window
		if {[winfo exists .custom_commands_help]} {
			destroy .custom_commands_help
			return
		}
		set x [expr {[winfo pointerx .] - 400}]
		set y [winfo pointery .]

		# Create new help window
		set win [toplevel .custom_commands_help -class {Help} -bg ${::COMMON_BG_COLOR}]
		set frame [frame $win.f -bg {#555555} -bd 0 -padx 1 -pady 1]
		wm overrideredirect $win 1

		# Click to close
		bind $win <Button-1> "grab release $win; destroy $win"

		# Create header "-- click to close --"
		pack [label $frame.lbl_header			\
			-text [mc "-- click to close --"]	\
			-bg {#FFFF55} -font $::smallfont	\
			-fg {#000000} -anchor c			\
		] -side top -anchor c -fill x

		# Create text widget
		set text [text $frame.text	\
			-bg {#FFFFCC}		\
			-exportselection 0	\
			-takefocus 0		\
			-cursor left_ptr	\
			-bd 0 -relief flat	\
		]

		pack $frame -fill both -expand 1

		# Create text tags
		$text tag configure tag_bold_small				\
			-font [font create					\
				-weight bold					\
				-size [expr {int(-12 * $::font_size_factor)}]	\
				-family $::DEFAULT_FIXED_FONT			\
			]
		$text tag configure tag_bold_big				\
			-foreground {#0000DD} -underline 1 			\
			-font [font create					\
				-weight bold					\
				-size [expr {int(-14 * $::font_size_factor)}]	\
				-family $::DEFAULT_FIXED_FONT			\
			]

		# Fill in the text widget
		$text insert end [mc "VARIABLES:"]
		$text tag add tag_bold_big {insert linestart} {insert lineend}
		$text insert end "\n  %URI"
		$text tag add tag_bold_small {insert linestart} {insert lineend}
		$text insert end [mc "\t\tThe full URI of the current file\n"]
		$text insert end "  %URIS"
		$text tag add tag_bold_small {insert linestart} {insert lineend}
		$text insert end [mc "\t\tList of the URIs of all open documents\n"]
		$text insert end "  %directory"
		$text tag add tag_bold_small {insert linestart} {insert lineend}
		$text insert end [mc "\t\tProject directory\n"]
		$text insert end "  %filename"
		$text tag add tag_bold_small {insert linestart} {insert lineend}
		$text insert end [mc "\t\tThe file name of the current document\n"]
		$text insert end "  %basename"
		$text tag add tag_bold_small {insert linestart} {insert lineend}
		$text insert end [mc "\t\tSame as %filename, but without extension\n"]
		$text insert end "  %mainfile"
		$text tag add tag_bold_small {insert linestart} {insert lineend}
		$text insert end [mc "\t\tName of project main file\n"]
		$text insert end "  %line"
		$text tag add tag_bold_small {insert linestart} {insert lineend}
		$text insert end [mc "\t\tNumber of the current line\n"]
		$text insert end "  %column"
		$text tag add tag_bold_small {insert linestart} {insert lineend}
		$text insert end [mc "\t\tNumber of the current column\n"]
		$text insert end "  %selection"
		$text tag add tag_bold_small {insert linestart} {insert lineend}
		$text insert end [mc "\t\tThe selected text in the current file\n"]
		$text insert end "  %text"
		$text tag add tag_bold_small {insert linestart} {insert lineend}
		$text insert end [mc "\t\tThe full text of the current file\n"]
		$text insert end "  %%"
		$text tag add tag_bold_small {insert linestart} {insert lineend}
		$text insert end [mc "\t\tPercent sign\n\n"]
		$text insert end [mc "Variables %line, %column, %selection and %text"]
		foreach start {10 17 26 41} end {15 24 36 46} {
			$text tag add tag_bold_small			\
				[list insert linestart+${start}c]	\
				[list insert linestart+${end}c]
		}
		$text insert end [mc "\nare not available if external editor is used"]

		# Show the text widget
		$text configure -state disabled
		pack $text -side bottom -fill both -expand 1

		# Set window attributes
		wm geometry $win "=420x330+$x+$y"
		wm protocol $win WM_DELETE_WINDOW "
			grab release $win
			destroy $win
			grab .custom_commands_config_dialog"
		wm transient $win .custom_commands_config_dialog
		raise $win
		update
		catch {
			grab -global $win
		}
		tkwait window $win
	}

	## Validate content of entry "Description"
	 # @parm String content - String to validate
	 # @return Bool - result
	proc desc_validate {content} {
		if {[string length $content] > 100} {
			return 0
		} else {
			return 1
		}
	}

	## Change content of configuration variables
	 # @return void
	proc use_settings {} {
		variable description	;# Array: Command description (-textvariable) (idx: 0..2)
		variable cmfr_dialog	;# Array of Bool: Variable for checkbutton "Confirmation dialog"
		variable results_dialog	;# Array of Bool: Variable for checkbutton "Show results"
		variable ignore_errors	;# Array of Bool: Variable for checkbutton "Ignore errors"
		variable run_in_term	;# Array of Bool: Variable for checkbutton "Ignore errors"

		variable text_0		;# ID of text widget for command 0
		variable text_1		;# ID of text widget for command 1
		variable text_2		;# ID of text widget for command 2

		for {set i 0} {$i < 3} {incr i} {
			# Change content of configuration variables
			set ::X::custom_command_options($i)	\
				"$cmfr_dialog($i) $results_dialog($i) $ignore_errors($i) $run_in_term($i)"
			set ::X::custom_command_desc($i) $description($i)
			set ::X::custom_command_cmd($i) [regsub {\n$} [[subst -nocommands "\$text_${i}"] get 1.0 end] {}]

			# Change status tips
			if {[winfo exists .mainIconBar.custom$i]} {
				setStatusTip				\
					-widget .mainIconBar.custom$i	\
					-text [mc "Custom command %s: %s" $i $description($i)]
				::DynamicHelp::add .mainIconBar.custom$i -text [mc "Custom command %s: %s" $i $description($i)]
			}
		}
	}

	## Save configuration to config file
	 # @return void
	proc save_config {} {
		# Save settings
		for {set i 0} {$i < 3} {incr i} {
			::settings setValue "Custom command $i/options"		\
				$::X::custom_command_options($i)
			::settings setValue "Custom command $i/description"	\
				$::X::custom_command_desc($i)
			::settings setValue "Custom command $i/command"		\
				$::X::custom_command_cmd($i)
		}

		# Commit
		::settings saveConfig
	}

	## Load configuratin from config file
	 # @return void
	proc load_config {} {
		for {set i 0} {$i < 3} {incr i} {
			# Options
			set def_options $::X::custom_command_options($i)
			set ::X::custom_command_options($i)	[::settings	\
				getValue "Custom command $i/options"		\
				$::X::custom_command_options($i)]
			if {![regexp {\s*[01]\s+[01]\s+[01]\s+[01]\s*} $::X::custom_command_options($i)]} {
				puts stderr "Invalid custom command options, setting to defaults."
				set ::X::custom_command_options($i) $def_options
			}
			if {!$::PROGRAM_AVAILABLE(urxvt)} {
				set ::X::custom_command_options($i) [lreplace $::X::custom_command_options($i) 3 3 0]
			}
			# Description
			set ::X::custom_command_desc($i)	[::settings	\
				getValue "Custom command $i/description"	\
				$::X::custom_command_desc($i)]
			# Command
			set ::X::custom_command_cmd($i)		[::settings	\
				getValue "Custom command $i/command"		\
				$::X::custom_command_cmd($i)]
		}
	}

	## Take back changes and destroy dialog window
	 # @return void
	proc CANCEL {} {
		variable win		;# ID of dialog toplevel window
		variable dialog_opened	;# Bool: True if this dialog is already opened

		# Get rid of dialog window
		set dialog_opened 0
		grab release $win
		destroy $win
	}

	## Apply changes and destroy dialog window
	 # @return void
	proc OK {} {
		variable win		;# ID of dialog toplevel window

		# Apply new settings
		use_settings		;# Adjust NS variables
		save_config		;# Save new config

		# Get rid of the dialog window
		CANCEL
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

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
if { ! [ info exists _GLOBAL_CONFIG_TCL ] } {
set _GLOBAL_CONFIG_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements global configuration dialog
# --------------------------------------------------------------------------


## Global configuration dialog
 # see Array OPTION in root NS
namespace eval global {

	variable dialog_opened	0	;# Bool: True if this dialog is already opened
	variable win			;# ID of dialog toplevel window

	variable available_languages	;# List: Available languages (their codes)
	variable language_names		;# List: Available languages (their names)

	## Configuration variables
	variable show_splash		;# Bool: Show splash creen on start-up
	variable show_tips		;# Bool: Show tips on start-up
	variable language		;# String: Language code
	variable language_name		;# String: Language name
	variable font_size		;# Float: Global font size factor
	variable font_size_desc		;# String: Global font size factor in its "string" form (I mean description)
	variable background		;# String: Human readable description of the common background color
	variable wstyle			;# String: Preffered widget style

	## Create the dialog
	 # @return void
	proc mkDialog {} {
		variable win			;# ID of toplevel dialog window
		variable dialog_opened		;# Bool: True if this dialog is already opened
		variable available_languages	;# List: Available languages (their codes)
		variable language_names		;# List: Available languages (their names)

		# Destroy the dialog if it's already opened
		if {$dialog_opened} {
			destroy .global_config_dialog
		}
		set dialog_opened 1

		# Determinate available languages
		get_languages

		# Get settings from main NS
		getSettings

		# Create toplevel window
		set win [toplevel .global_config_dialog -class {Configuration dialog} -bg ${::COMMON_BG_COLOR}]

		# Create window header
		label $win.header_label				\
			-compound left				\
			-image ::ICONS::32::kcmmemory		\
			-text [mc "MCU 8051 IDE configuration"]	\
			-font [font create -size [expr {int(-20 * $::font_size_factor)}]]

		# Create horizontal separator
		Separator $win.sep -orient horizontal

		## Create middle frame
		set middle_frame [frame $win.middle_frame]
		 # Checkbutton "Display splash screen"
		grid [Label $middle_frame.lbl_splash			\
			-text [mc "Display splash screen"]		\
			-helptext [mc "Show splash screen on start-up"]	\
		] -row 0 -column 0 -sticky w
		grid [checkbutton $middle_frame.chb_splash		\
			-variable ::configDialogues::global::show_splash	\
		] -row 0 -column 1 -sticky w
		DynamicHelp::add $middle_frame.chb_splash	\
			-text [mc "Show splash screen on start-up"]
		 # Checkbutton "Show tips on start-up"
		grid [Label $middle_frame.lbl_tips		\
			-text [mc "Show tips on start-up"]	\
			-helptext [mc "Invoke dialog with tip of the day on start-up"]	\
		] -row 1 -column 0 -sticky w
		grid [checkbutton $middle_frame.chb_tips		\
			-variable ::configDialogues::global::show_tips	\
		] -row 1 -column 1 -sticky w
		DynamicHelp::add $middle_frame.chb_tips	\
			-text [mc "Invoke dialog with tip of the day on start-up"]
		 # Combo "Language"
		grid [Label $middle_frame.lbl_lang			\
			-text [mc "Language"]				\
			-helptext [mc "Your preferred language"]	\
		] -row 2 -column 0 -sticky w
		grid [ttk::combobox $middle_frame.cb_lang			\
			-values $language_names					\
			-state readonly						\
			-textvariable ::configDialogues::global::language_name	\
		] -row 2 -column 1 -sticky w
		bind $middle_frame.cb_lang <<ComboboxSelected>> {
			bind %W <<ComboboxSelected>> {
				set ::configDialogues::global::language	\
					[lindex ${::configDialogues::global::available_languages} [%W current]]
			}
			set ::configDialogues::global::language	\
				[lindex ${::configDialogues::global::available_languages} [%W current]]
			::configDialogues::global::language_changed
		}
		DynamicHelp::add $middle_frame.cb_lang	\
			-text [mc "Your preferred language"]
		 # SpinBox "Font Size Factor"
		grid [Label $middle_frame.lbl_fontsize			\
			-text [mc "Global font size factor"]		\
			-helptext [mc "Allows you to adjust size of (almost) all fonts used in this IDE"]	\
		] -row 3 -column 0 -sticky w
		grid [ttk::combobox $middle_frame.cb_fontsize			\
			-values [list						\
				[mc "Normal"]		[mc "A little larger"]	\
				[mc "Notably larger"]	[mc "Much larger"]	\
				[mc "Huge"]		[mc "Too BIG"]		\
			]							\
			-state readonly						\
			-textvariable ::configDialogues::global::font_size_desc	\
		] -row 3 -column 1 -sticky w
		bind $middle_frame.cb_fontsize <<ComboboxSelected>> "
			bind $middle_frame.cb_fontsize <<ComboboxSelected>> {}
			::configDialogues::global::fontsize_changed
		"
		DynamicHelp::add $middle_frame.cb_fontsize	\
			-text [mc "Allows you to adjust size of (almost) all fonts used in this IDE"]

		 # Combo "Widget style"
		grid [Label $middle_frame.lbl_style			\
			-text [mc "Widget style"]			\
			-helptext [mc "Your preferred widget style"]	\
		] -row 4 -column 0 -sticky w
		grid [ttk::combobox $middle_frame.cb_style		\
			-values [ttk::style theme names]		\
			-state readonly					\
			-textvariable ::configDialogues::global::wstyle	\
		] -row 4 -column 1 -sticky w
		bind $middle_frame.cb_style <<ComboboxSelected>> "
			bind $middle_frame.cb_style <<ComboboxSelected>> {}
			::configDialogues::global::restart_required
		"
		DynamicHelp::add $middle_frame.cb_style	\
			-text [mc "Your preferred widget style"]

		 # Combo "Background color"
		if {!$::MICROSOFT_WINDOWS} {
			grid [Label $middle_frame.lbl_background		\
				-text [mc "Background color"]			\
				-helptext [mc "Common background color for almost everything in the GUI"] \
			] -row 5 -column 0 -sticky w
			grid [ttk::combobox $middle_frame.cb_background			\
				-values [list						\
					{Default}		{Windows}		\
					{Tk}			{Light}			\
					{Dark}						\
				]							\
				-state readonly						\
				-textvariable ::configDialogues::global::background	\
			] -row 5 -column 1 -sticky w
			bind $middle_frame.cb_background <<ComboboxSelected>> "
				bind $middle_frame.cb_background <<ComboboxSelected>> {}
				::configDialogues::global::restart_required
			"
			DynamicHelp::add $middle_frame.cb_background	\
				-text [mc "Common background color for almost everything in the GUI"]
		}

		 # Separator
		grid [ttk::separator $middle_frame.sep -orient horizontal]	\
			-columnspan 2 -sticky we -row 10 -column 0 -pady 5
		 # Checkbutton "Do not ask whether ..."
		grid [text $middle_frame.lbl_ask	\
			-wrap word			\
			-height 4			\
			-width 0			\
			-bg ${::COMMON_BG_COLOR}	\
			-bd 0				\
		] -row 11 -column 0 -sticky we
		$middle_frame.lbl_ask insert end [mc "Do not always ask whether to add file to the project after the file is opened"]
		$middle_frame.lbl_ask configure -state disabled
		grid [checkbutton $middle_frame.cb_ask		\
			-onvalue 0 -offvalue 1 			\
			-variable ::FileList::ask__append_file_to_project	\
		] -row 11 -column 1 -sticky w
		 # Checkbutton "Do not show performnace warning ..."
		grid [text $middle_frame.lbl_dont_per_warn	\
			-wrap word				\
			-height 4				\
			-width 0				\
			-bg ${::COMMON_BG_COLOR}		\
			-bd 0					\
		] -row 12 -column 0 -sticky we
		$middle_frame.lbl_dont_per_warn insert end [mc "Do not show performance warning when enabling external HW simulation."]
		$middle_frame.lbl_dont_per_warn configure -state disabled
		grid [checkbutton $middle_frame.cb_dont_per_warn\
			-onvalue 0 -offvalue 1 			\
			-variable ::Graph::show_sim_per_warn	\
		] -row 12 -column 1 -sticky w

		# Finalize
		grid columnconfigure $middle_frame 0 -minsize 200

		## Button frame at the bottom
		set but_frame [frame $win.button_frame]
		 # Button "Reset"
		pack [ttk::button $but_frame.but_default		\
			-text [mc "Reset to defaults"]			\
			-command {::configDialogues::global::DEFAULTS}	\
		] -side left
		DynamicHelp::add $but_frame.but_default	\
			-text [mc "Reset all settings to defaults"]
		 # Button "Ok"
		pack [ttk::button $but_frame.but_ok			\
			-text [mc "Ok"]					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::global::OK}	\
		] -side right -padx 2
		DynamicHelp::add $but_frame.but_ok	\
			-text [mc "Commit new settings"]
		 # Button "Cancel"
		pack [ttk::button $but_frame.but_cancel			\
			-text [mc "Cancel"]				\
			-compound left					\
			-image ::ICONS::16::button_cancel		\
			-command {::configDialogues::global::CANCEL}	\
		] -side right -padx 2
		DynamicHelp::add $but_frame.but_cancel	\
			-text [mc "Take changes back and close dialog"]

		# Pack frames and notebook
		pack $win.header_label -side top -pady 6
		pack $win.sep -side top -fill x -after $win.header_label
		pack $middle_frame -side top -padx 10 -anchor nw -pady 10
		pack $but_frame -side bottom -fill x -expand 1 -anchor s -padx 5 -pady 5

		# Set window attributes
		wm iconphoto $win ::ICONS::16::configure
		wm transient $win .
		wm title $win [mc "Configure MCU 8051 IDE"]
		wm minsize $win 380 380
		raise $win
		catch {grab $win}
		wm protocol $win WM_DELETE_WINDOW {
			::configDialogues::global::CANCEL
		}
		tkwait window $win
	}

	## Application language changed
	 # Takes any set of arguments and discards them
	 # @parm List - meaningless
	 # @return void
	proc language_changed args {
		tk_messageBox				\
			-parent .global_config_dialog	\
			-type ok -icon info		\
			-title [mc "Application language changed"]	\
			-message [mc "Language for this application has been changed. The change will take effect upon next start of application"]
	}

	## Display message "The change will take effect upon next start of application"
	 # Takes any set of arguments and discards them
	 # @parm List - meaningless
	 # @return void
	proc restart_required args {
		tk_messageBox				\
			-parent .global_config_dialog	\
			-type ok -icon info		\
			-title [mc "Restart required"]	\
			-message [mc "The change will take effect upon next start of application"]
	}


	## Global font size factor changed
	 # Takes any set of arguments and discards them
	 # @parm List - meaningless
	 # @return void
	proc fontsize_changed args {
		tk_messageBox				\
			-parent .global_config_dialog	\
			-type ok -icon info		\
			-title [mc "Global font size factor changed"]	\
			-message [mc "The change will take effect upon next start of application"]
	}

	## Retrieve list of available translations
	 # @return void
	proc get_languages {} {
		variable available_languages	;# List: Available languages (their codes)
		variable language_names		;# List: Available languages (their names)

		set available_languages {en}
		set tmp [list]
		catch {	;# For Microsoft Windows it has to be enclosed in catch block
			set tmp [glob -nocomplain -types f -tails			\
				-directory "${::INSTALLATION_DIR}/translations" *.msg	\
			]
		}

		foreach translation $tmp {
			lappend available_languages [file rootname $translation]
		}

		set language_names [list]
		foreach lang $available_languages {
			set idx [lsearch -ascii -exact ${::LANGUAGE_CODES} $lang]
			if {$idx == -1} {
				lappend language_names $lang
			} else {
				incr idx
				lappend language_names [lindex ${::LANGUAGE_CODES} $idx]
			}
		}
	}

	## Set configuration variable
	 # @parm String variable	- variable to set
	 # @parm Mixed value		- new value
	proc set_variable {variable value} {
		variable show_splash	;# Bool: Show splash creen on start-up
		variable show_tips	;# Bool: Show tips on start-up
		variable language	;# String: Language
		variable font_size	;# Float: Global font size factor
		variable background	;# String: Human readable description of the common background color
		variable wstyle		;# String: Preffered widget style

		getSettings

		switch -- $variable {
			{splash} {
				set show_splash $value
			}
			{tips} {
				set show_tips $value
			}
			{language} {
				set language $value
			}
			{fontsize} {
				set font_size $value
			}
			{background} {
				set background $value
			}
			{wstyle} {
				set wstyle $value
			}
			default {
				puts stderr "::configDialogues::global::set_variable(): `$variable' was not recognized"
			}
		}

		use_settings
		save_config
	}

	## Retrieve settings from main NS
	 # @return void
	proc getSettings {} {
		variable show_splash		;# Bool: Show splash creen on start-up
		variable show_tips		;# Bool: Show tips on start-up
		variable language		;# String: Language code
		variable language_name		;# String: Language name
		variable available_languages	;# List: Available languages (their codes)
		variable language_names		;# List: Available languages (their names)
		variable font_size		;# Float: Global font size factor
		variable font_size_desc		;# String: Global font size factor in its "string" form (I mean description)
		variable background		;# String: Human readable description of the common background color
		variable wstyle			;# String: Preffered widget style

		set show_splash	${::GLOBAL_CONFIG(splash)}
		set show_tips	${::GLOBAL_CONFIG(tips)}
		set language	${::GLOBAL_CONFIG(language)}
		set font_size	$::font_size_factor
		set background	${::GLOBAL_CONFIG(background)}
		set wstyle	${::GLOBAL_CONFIG(wstyle)}

		switch -- $font_size {
			1.0	{set font_size_desc [mc "Normal"]		}
			1.1	{set font_size_desc [mc "A little larger"]	}
			1.2	{set font_size_desc [mc "Notably larger"]	}
			1.3	{set font_size_desc [mc "Much larger"]		}
			1.4	{set font_size_desc [mc "Huge"]			}
			1.5	{set font_size_desc [mc "Too BIG"]		}
			default	{set font_size_desc [mc "Normal"]		}
		}

		if {[catch {
			set language_name [lindex $language_names [lsearch -ascii -exact $available_languages $language]]
		}]} then {
			set language_name {<unknown>}
		}
	}

	## Set application according to local settings
	 # @return void
	proc use_settings {} {
		variable show_splash	;# Bool: Show splash creen on start-up
		variable show_tips	;# Bool: Show tips on start-up
		variable language	;# String: Language code
		variable font_size	;# Float: Global font size factor
		variable font_size_desc	;# String: Global font size factor in its "string" form (I mean description)
		variable background	;# String: Human readable description of the common background color
		variable wstyle		;# String: Preffered widget style

		switch -- $font_size_desc [subst {
			{[mc "Normal"]}			{set font_size 1.0}
			{[mc "A little larger"]}	{set font_size 1.1}
			{[mc "Notably larger"]}		{set font_size 1.2}
			{[mc "Much larger"]}		{set font_size 1.3}
			{[mc "Huge"]}			{set font_size 1.4}
			{[mc "Too BIG"]}		{set font_size 1.5}
			default				{set font_size 1.0}

		}]

		if {${::GLOBAL_CONFIG(language)} != $language} {
			set lang_changed 1
		} else {
			set lang_changed 0
		}

		set ::GLOBAL_CONFIG(splash)	$show_splash
		set ::GLOBAL_CONFIG(tips)	$show_tips
		set ::GLOBAL_CONFIG(language)	$language
		set ::font_size_factor		$font_size
		set ::GLOBAL_CONFIG(background)	$background
		set ::GLOBAL_CONFIG(wstyle)	$wstyle

		if {$lang_changed} {
			::X::switch_language
		}
	}

	## Save settings to the config file
	 # @return void
	proc save_config {} {
		variable show_splash	;# Bool: Show splash creen on start-up
		variable show_tips	;# Bool: Show tips on start-up
		variable language	;# String: Language code
		variable font_size	;# Float: Global font size factor
		variable background	;# String: Human readable description of the common background color
		variable wstyle		;# String: Preffered widget style

		if {[catch {
			set conf_file [open "${::CONFIG_DIR}/base.conf" w]
			puts -nonewline $conf_file	\
				[list $show_splash $show_tips $language $font_size $background $wstyle]
			close $conf_file
		}]} then {
			puts stderr [mc "Unable to write to base configuration file"]
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
		variable win	;# ID of toplevel dialog window

		# Use and save settings
		use_settings
		save_config

		# Destroy dialog window
		CANCEL
	}

	## Restrore defaults
	 # @return void
	proc DEFAULTS {} {
		variable show_splash		;# Bool: Show splash creen on start-up
		variable show_tips		;# Bool: Show tips on start-up
		variable language		;# String: Language code
		variable language_name		;# String: Language name
		variable available_languages	;# List: Available languages (their codes)
		variable language_names		;# List: Available languages (their names)
		variable font_size_desc		;# String: Global font size factor in its "string" form (I mean description)
		variable background		;# String: Human readable description of the common background color
		variable wstyle			;# String: Preffered widget style

		set show_splash		1
		set show_tips		1
		set language		{en}
		set font_size_desc	{Normal}
		set background		{Default}
		set wstyle		{clam}

		if {[catch {
			set language_name [lindex $language_names [lsearch -ascii -exact $available_languages $language]]
		}]} then {
			set language_name {<unknown>}
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

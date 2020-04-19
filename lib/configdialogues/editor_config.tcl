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
if { ! [ info exists _EDITOR_CONFIG_TCL ] } {
set _EDITOR_CONFIG_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements editor configuration dialog
# --------------------------------------------------------------------------

namespace eval editor {

	variable dialog_opened	0	;# Bool: True if this dialog is already opened
	variable row		0	;# General purpose variable (some row somewhere)
	variable win			;# ID of dialog toplevel window
	variable button_index	0	;# Button index (for creating many buttons)

	variable anything_modified 	;# Bool: Settings changed (stay set to 1 even after APPLY)
	variable changed		;# Bool: Settings changed
	variable apply_button		;# ID of button "Apply"

	variable autocompletion_turned_on	0

	# Notebook related
	variable nb			;# Widget: Notebook itself
	variable editor_tab		;# Widget: Tab "Editor"
	variable general_tab		;# Widget: Tab "General"
	variable colors_tab		;# Widget: Tab "Colors"
	variable fonts_tab		;# Widget: Tab "Fonts"
	variable highlight_tab		;# Widget: Tab "Syntax highlight"
	variable highlight_tab_asm	;# Widget: Tab "Syntax highlight"/"Assembler"
	variable highlight_tab_C	;# Widget: Tab "Syntax highlight"/"C language"
	variable highlight_tab_lst	;# Widget: Tab "Syntax highlight"/"Code listing"
	variable tab_created_so_far	;# List: ID of already created tabs.

	## Tab "Editor"
	## Int: Editor to use
	 # 0 - Native editor
	 # 1 - Vim
	 # 2 - Emacs
	 # 3 - Nano
	 # 4 - dav
	 # 5 - le
	variable editor_to_use

	# Tab "General"
	variable default_encoding	;# Default encoding for opening files
	variable default_eol		;# Default EOL character
	variable intentation_mode	;# Editor indentation mode
	variable spaces_no_tabs		;# Bool: Use spaces instead of tabs
	variable number_of_spaces	;# Int: Number of spaces to use instead of tab
	variable tab_width		;# Int: Tab width
	variable autosave		;# Int: Autosave interval in minutes (0 == disabled)
	variable auto_brackets		;# Automaticaly insert oposite brackets, quotes, etc.
	variable hg_trailing_sp		;# Bool: Highlight trailing space
	variable auto_completion	;# Bool: Enable popup-based completion
	variable cline_completion	;# Bool: Enable popup-based completion for command line
	variable available_encodings {
		utf-8			iso8859-1		iso8859-2
		iso8859-3		iso8859-4		iso8859-5
		iso8859-6		iso8859-7		iso8859-8
		iso8859-9		iso8859-10		iso8859-13
		iso8859-14		iso8859-15		iso8859-16
		cp1250			cp1251			cp1252
		cp1253			cp1254			cp1255
		cp1256			cp1257			cp1258
	}

	# Tab "Colors"
	variable color_normal_text	;# RGB: Editor backgound color
	variable color_selected_text	;# RGB: Backgound color for selected text
	variable color_current_line	;# RGB: Backgound color for current line
	variable color_bookmark		;# RGB: Backgound color for bookmarks
	variable color_breakpoint	;# RGB: Backgound color for breakpoints
	variable color_breakpoint_I	;# RGB: Backgound color for invalid breakpoints
	variable color_simulator_line	;# RGB: Backgound color for simulator line
	variable color_error_line	;# RGB: Backgound color for line containing an error
	variable color_trailing_space	;# RGB: Backgound color for trailing space
	variable color_iconBorder_bg	;# RGB: Backgound color for icon border
	variable color_lineNumbers_bg	;# RGB: Backgound color for line numbers
	variable color_lineNumbers_fg	;# RGB: Foregound color for line numbers

	# Tab "Fonts"
	variable sample_text		;# ID of text widget for sample text
	variable sample_text_size	;# Font size
	variable sample_text_family	;# Font family

	## Tab "Assembler syntax highlight"
	variable highlight_tags_asm			;# List: Definition of colors and styles for assembler syntax highlighting
	variable list_of_tags_asm			;# List: Highlighting tags
	variable highlight_tab_scr_text_asm		;# ID of text widget for configuring syntax
	variable highlight_tab_scr_sample_text_asm	;# ID of text widget for sample text
		# List of checkbuttons affected by changing cursor position in sample text
	variable highlight_tab_checkbuttons_asm

	## Tab "C" syntax highlight"
	variable highlight_tags_C			;# List: Definition of colors and styles for C syntax highlighting
	variable list_of_tags_C				;# List: Highlighting tags
	variable highlight_tab_scr_text_C		;# ID of text widget for configuring syntax
	variable highlight_tab_scr_sample_text_C	;# ID of text widget for sample text
	 # List of checkbuttons affected by changing cursor position in sample text
	variable highlight_tab_checkbuttons_C

	## Tab "LST" syntax highlight"
	variable highlight_tags_lst			;# List: Definition of colors and styles for LST syntax highlighting
	variable list_of_tags_lst			;# List: Highlighting tags
	variable highlight_tab_scr_text_lst		;# ID of text widget for configuring syntax
	variable highlight_tab_scr_sample_text_lst	;# ID of text widget for sample text
	 # List of checkbuttons affected by changing cursor position in sample text
	variable highlight_tab_checkbuttons_lst


	## Create the dialog
	 # @parm String tab_to_raise={} - Tab to raise on start up
	 # @return void
	proc mkDialog {{tab_to_raise {}}} {
		variable nb			;# Widget: Notebook itself
		variable editor_tab		;# Widget: Tab "Editor"
		variable general_tab		;# Widget: Tab "General"
		variable colors_tab		;# Widget: Tab "Colors"
		variable fonts_tab		;# Widget: Tab "Fonts"
		variable highlight_tab		;# Widget: Tab "Syntax highlight"
		variable highlight_tab_asm	;# Widget: Tab "Syntax highlight"/"Assembler"
		variable highlight_tab_C	;# Widget: Tab "Syntax highlight"/"C language"
		variable highlight_tab_lst	;# Widget: Tab "Syntax highlight"/"Code listing"
		variable tab_created_so_far	;# List: ID of already created tabs.

		variable apply_button		;# ID of button "Apply"
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable changed		;# Bool: Settings changed
		variable editor_to_use		;# Int: Prefred editor
		variable sample_text		;# ID of text widget for sample text
		variable sample_text_size	;# Font size
		variable sample_text_family 	;# Font family
		variable row			;# General purpose variable (some row somewhere)
		variable win			;# ID of dialog toplevel window
		variable dialog_opened		;# Bool: True if this dialog is already opened
		variable button_index		;# Button index (for creating many buttons)
		variable highlight_tags_asm	;# List: Definition of colors and styles for assembler syntax highlighting
		variable highlight_tags_C	;# List: Definition of colors and styles for C syntax highlighting
		variable highlight_tags_lst	;# List: Definition of colors and styles for LST syntax highlighting


		set button_index 0

		# Destroy dialog windows if it is already opened
		if {$dialog_opened} {
			destroy .editor_config_dialog
		}
		set dialog_opened 1
		set changed 0
		set anything_modified 0
		# Get settings from the program
		getSettings
		# Create toplevel window
		set win [toplevel .editor_config_dialog -class {Configuration dialog} -bg ${::COMMON_BG_COLOR}]

		# Create window header
		label $win.header_label				\
			-compound left				\
			-image ::ICONS::32::configure		\
			-text [mc "Editor configuration"]	\
			-font [font create -size [expr {int(-20 * $::font_size_factor)}]]

		# Create button "Apply" in advance
		set but_frame [frame $win.button_frame]
		set apply_button [ttk::button $but_frame.but_apply	\
			-text [mc "Apply"]				\
			-state disabled					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::editor::APPLY}	\
		]

		# Create notebook
		set nb [ModernNoteBook $win.nb]
		set tab_created_so_far [list]
		 # Create Tab "Editor"
		if {!$::MICROSOFT_WINDOWS} {	;# External editors are not available on Microsoft Windows
			set editor_tab [$nb insert end editor_tab -text [mc "Editor"] -createcmd {::configDialogues::editor::create_tab editor}]
		}
		 # Create Tab "General"
		set general_tab [$nb insert end general_tab 				\
			-text [mc "General"]						\
			-createcmd {::configDialogues::editor::create_tab general}	\
		]
		 # Create Tab "Colors"
		set colors_tab [$nb insert end colors_tab				\
			-text [mc "Colors"]						\
			-createcmd {::configDialogues::editor::create_tab colors}	\
		]
		 # Create Tab "Fonts"
		set fonts_tab [$nb insert end fonts_tab					\
			-text [mc "Fonts"]						\
			-createcmd {::configDialogues::editor::create_tab fonts}	\
		]
		 # Create Tab "Highlight"
		set highlight_tab [$nb insert end highlight_tab				\
			-text [mc "Syntax highlight"]					\
			-createcmd {::configDialogues::editor::create_tab highlight}	\
		]

		#
		## Finalize
		#

		if {[string length $tab_to_raise]} {
			if {!$::MICROSOFT_WINDOWS} {	;# External editors are not available on Microsoft Windows
				$nb raise [lindex [$nb pages]	\
					[lsearch [list {Editor} {General} {Colors} {Fonts} {Highlight}] $tab_to_raise]]
			} else {
				$nb raise [lindex [$nb pages]	\
					[lsearch [list {General} {Colors} {Fonts} {Highlight}] $tab_to_raise]]
			}
		} else {
			if {!$::MICROSOFT_WINDOWS} {	;# External editors are not available on Microsoft Windows
				if {$editor_to_use} {
					foreach tab [list highlight_tab general_tab] {
						$nb itemconfigure $tab -state disabled
					}
					$nb raise editor_tab
				} else {
					$nb raise general_tab
				}
			} else {
				$nb raise general_tab
			}
		}

		# Create button frame at the bottom
		pack $apply_button -side left
		 # Button "Ok"
		pack [ttk::button $but_frame.but_ok			\
			-text [mc "Ok"]					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::editor::OK}	\
		] -side right -padx 2
		 # Button "Cancel"
		pack [ttk::button $but_frame.but_cancel			\
			-text [mc "Cancel"]				\
			-compound left					\
			-image ::ICONS::16::button_cancel		\
			-command {::configDialogues::editor::CANCEL}	\
		] -side right -padx 2

		# Pack frames and notebook
		pack $but_frame -side bottom -fill x -expand 0 -anchor s -padx 10 -pady 5
		pack $win.header_label -side top -pady 6
		pack [$nb get_nb] -side top -fill both -expand 1 -padx 10

		# Finalize creation of the dialog
		wm transient $win .
		wm iconphoto $win ::ICONS::16::configure
		wm title $win [mc "Editor configuration - %s" ${::APPNAME}]
		wm geometry $win =350x500
		wm resizable $win 0 1
		wm minsize $win 350 470
		raise $win
		catch {grab $win}
		wm protocol $win WM_DELETE_WINDOW {
			::configDialogues::editor::CANCEL
		}
		tkwait window $win
	}

	## Create tab in notebook
	 # @parm String tab_name - Name of tab to create
	 # @return void
	proc create_tab {tab_name} {
		variable nb			;# Widget: Notebook itself
		variable editor_tab		;# Widget: Tab "Editor"
		variable general_tab		;# Widget: Tab "General"
		variable colors_tab		;# Widget: Tab "Colors"
		variable fonts_tab		;# Widget: Tab "Fonts"
		variable available_encodings	;# available encodings
		variable highlight_tab		;# Widget: Tab "Syntax highlight"
		variable highlight_tab_asm	;# Widget: Tab "Syntax highlight"/"Assembler"
		variable highlight_tab_C	;# Widget: Tab "Syntax highlight"/"C language"
		variable highlight_tab_lst	;# Widget: Tab "Syntax highlight"/"Code listing"
		variable tab_created_so_far	;# List: ID of already created tabs.

		variable editor_to_use		;# Int: Prefred editor
		variable sample_text		;# ID of text widget for sample text
		variable sample_text_size	;# Font size
		variable sample_text_family 	;# Font family
		variable row			;# General purpose variable (some row somewhere)
		variable win			;# ID of dialog toplevel window
		variable dialog_opened		;# Bool: True if this dialog is already opened
		variable button_index		;# Button index (for creating many buttons)

		if {[lsearch $tab_created_so_far $tab_name] != -1} {
			return
		} else {
			lappend tab_created_so_far $tab_name
		}

		switch -- $tab_name {
			{editor} {	;# Tab "Editor selection"
				set editor_top_frame [frame $editor_tab.top_frame]
				# Preferred editor
				grid [label $editor_top_frame.editor_lbl		\
					-text [mc "Preferred editor:"] -anchor w	\
				] -row 0 -column 0 -sticky w -pady 10 -padx 10
				set row 1
				set i 0
				foreach text [list			\
						[mc "Native editor"]	\
						{Vim}			\
						{Emacs}			\
						{Nano}			\
						{dav}			\
						{le}			\
					] {
						grid [radiobutton $editor_top_frame.rabut_$i	\
							-variable ::configDialogues::editor::editor_to_use \
							-value $i -text $text -state disabled	\
							-command ::configDialogues::editor::editor_to_use_changed \
						] -column 0 -padx 25 -row $row -sticky w
						incr i
						incr row
				}
				$editor_top_frame.rabut_0 configure -state normal
				if {${::PROGRAM_AVAILABLE(urxvt)}} {
					if {${::PROGRAM_AVAILABLE(vim)}} {
						$editor_top_frame.rabut_1 configure -state normal
					}
					if {${::PROGRAM_AVAILABLE(emacs)}} {
						$editor_top_frame.rabut_2 configure -state normal
					}
					if {${::PROGRAM_AVAILABLE(nano)}} {
						$editor_top_frame.rabut_3 configure -state normal
					}
					if {${::PROGRAM_AVAILABLE(dav)}} {
						$editor_top_frame.rabut_4 configure -state normal
					}
					if {${::PROGRAM_AVAILABLE(le)}} {
						$editor_top_frame.rabut_5 configure -state normal
					}
				}
				grid [label $editor_top_frame.editor_note			\
					-fg {#555555} -font [font create			\
						-family {helvetica}				\
						-size [expr {int(-14 * $::font_size_factor)}]	\
						-slant italic					\
					]	\
					-text [mc "(This change will take effect upon next start.)"]	\
				] -row 20 -column 0 -columnspan 2 -sticky w

				# Finalize
				grid columnconfigure $editor_top_frame 0 -minsize 200
				grid columnconfigure $editor_top_frame 1 -weight 1
				pack $editor_top_frame -side top -anchor nw -padx 5 -fill x
			}
			{general} {	;# Tab "General"
				# Create label frames
				set editing_labelframe [ttk::labelframe $general_tab.labelframe_edit	\
					-text [mc "Editing"]						\
				]
				set open_labelframe [ttk::labelframe $general_tab.labelframe_open	\
					-text [mc "File opening, saving, etc."]				\
				]
				set cmd_labelframe [ttk::labelframe $general_tab.labelframe_cmd		\
					-text [mc "Command line"]					\
				]

				## Labelframe "Editing"
				 # Item: "Auto brackets"
				grid [Label $editing_labelframe.autob_lbl	\
					-text [mc "Auto brackets"]		\
					-helptext [mc "If you type a left bracket, editor\nwill automatically insert right bracket"]	\
				] -row 1 -column 0 -sticky w -padx 5
				grid [checkbutton $editing_labelframe.autob_chbutton		\
					-variable ::configDialogues::editor::auto_brackets	\
					-command ::configDialogues::editor::settings_changed	\
				] -row 1 -column 1 -sticky w -padx 5
				DynamicHelp::add $editing_labelframe.autob_chbutton	\
					-text [mc "When you type a left bracket editor\nwill automatically insert right bracket"]
				# Item: "Indentation mode"
				grid [Label $editing_labelframe.imode_lbl	\
					-text [mc "Indentation mode"]		\
					-helptext [mc "What to do when you press enter\n\tnone\t- start on the beginning of the next line\n\tnormal\t- keep indention of the previous line"]	\
				] -row 2 -column 0 -sticky w -padx 5
				grid [ttk::combobox $editing_labelframe.imode_cb			\
					-values [list [mc "none"] [mc "normal"]]			\
					-state readonly							\
					-width 0							\
					-textvariable ::configDialogues::editor::intentation_mode	\
				] -row 2 -column 1 -sticky we -padx 5
				bind $editing_labelframe.imode_cb <<ComboboxSelected>>	\
					{::configDialogues::editor::settings_changed}
				DynamicHelp::add $editing_labelframe.imode_cb	\
					-text [mc "What to do when you press enter\n\tnone\t- start on the beginning of the next line\n\tnormal\t- keep indention of the previous line"]
				# Item: "Tab width"
				grid [Label $editing_labelframe.tabw_lbl\
					-text [mc "Tab width"]		\
					-helptext [mc "Maximum width of the tab character, measured in number of spaces"]	\
				] -row 3 -column 0 -sticky w -padx 5
				grid [ttk::spinbox $editing_labelframe.tabw_spinbox				\
					-from 1 -to 40 -validate all						\
					-validatecommand "::configDialogues::editor::tabw_spinbox_val %P"	\
					-textvariable ::configDialogues::editor::tab_width			\
					-command ::configDialogues::editor::settings_changed			\
				] -row 3 -column 1 -sticky we -padx 5
				DynamicHelp::add $editing_labelframe.tabw_spinbox	\
					-text [mc "Maximum width of the tab character, measured in number of spaces"]
				# Item: "Insert spaces instead of tabs"
				grid [Label $editing_labelframe.tabis_lbl		\
					-text [mc "Insert spaces instead of tabs"]	\
					-helptext [mc "Use spaces instead of tabs"]	\
				] -row 4 -column 0 -sticky w -padx 5
				grid [checkbutton $editing_labelframe.tabis_chbutton		\
					-variable ::configDialogues::editor::spaces_no_tabs	\
					-command ::configDialogues::editor::settings_changed	\
				] -row 4 -column 1 -sticky w -padx 5
				DynamicHelp::add $editing_labelframe.tabis_chbutton	\
					-text [mc "Use spaces instead of tabs"]
				# Item: "Number of spaces"
				grid [Label $editing_labelframe.nofs_lbl				\
					-text [mc "Number of spaces"]					\
					-helptext [mc "Number of spaces to use instead of tabs"]	\
				] -row 5 -column 0 -sticky w -padx 5
				grid [ttk::spinbox $editing_labelframe.nofs_spinbox				\
					-from 1 -to 16 -validate all						\
					-validatecommand "::configDialogues::editor::nofs_spinbox_val %P"	\
					-textvariable ::configDialogues::editor::number_of_spaces		\
					-command ::configDialogues::editor::settings_changed			\
				] -row 5 -column 1 -sticky we -padx 5
				DynamicHelp::add $editing_labelframe.nofs_spinbox	\
					-text [mc "Number of spaces to use instead of tabs"]
				# Item: "Enable autocompletion"
				grid [Label $editing_labelframe.completion_lbl		\
					-text [mc "Enable autocompletion"]			\
					-helptext [mc "Enable popup-based autocompletion"]	\
				] -row 6 -column 0 -sticky w -padx 5
				grid [checkbutton $editing_labelframe.completion_chbutton	\
					-variable ::configDialogues::editor::auto_completion	\
					-command ::configDialogues::editor::settings_changed	\
				] -row 6 -column 1 -sticky w -padx 5
				DynamicHelp::add $editing_labelframe.completion_chbutton	\
					-text [mc "Enable popup-based autocompletion"]
				# Item: "Highlight trailing space"
				grid [Label $editing_labelframe.trail_sp_lbl	\
					-text [mc "Highlight trailing space"]	\
				] -row 7 -column 0 -sticky w -padx 5
				grid [checkbutton $editing_labelframe.trail_sp_chbutton	\
					-variable ::configDialogues::editor::hg_trailing_sp	\
					-command ::configDialogues::editor::settings_changed	\
				] -row 7 -column 1 -sticky w -padx 5
				# Finalize
				grid columnconfigure $editing_labelframe 0 -minsize 200
				grid columnconfigure $editing_labelframe 1 -weight 1

				## Labelframe "File opening & saving"
				 # Item: "Show tab bar"
				grid [Label $open_labelframe.show_editor_tab_bar_lbl	\
					-text [mc "Show tab bar"]			\
				] -row 0 -column 0 -sticky w -padx 5
				grid [checkbutton $open_labelframe.show_editor_tab_bar_chb	\
					-onvalue 1 -offvalue 0					\
					-variable ::CONFIG(SHOW_EDITOR_TAB_BAR)			\
					-command ::configDialogues::editor::settings_changed	\
				] -row 0 -column 1 -sticky w -padx 5

				# Item: "Default charset"
				grid [Label $open_labelframe.charset_lbl	\
					-text [mc "Default encoding"]		\
					-helptext [mc "When you open file with unknown encoding\nthis encoding will be used"]	\
				] -row 1 -column 0 -sticky w -padx 5
				grid [ttk::combobox $open_labelframe.charset_cb			\
					-width 0						\
					-state readonly						\
					-values $available_encodings				\
					-textvariable ::configDialogues::editor::default_encoding	\
				] -row 1 -column 1 -sticky we -padx 5
				bind $open_labelframe.charset_cb <<ComboboxSelected>>	\
					{::configDialogues::editor::settings_changed}
				DynamicHelp::add $open_labelframe.charset_cb	\
					-text [mc "When you open file with unknown encoding\nthis encoding will be used"]
				# Item: "Default EOL"
				grid [Label $open_labelframe.eol_lbl		\
					-text [mc "Default EOL"]			\
					-helptext [mc "When you open file with unknown\nEOL (End Of Line) this EOL will be used"]	\
				] -row 2 -column 0 -sticky w -padx 5
				grid [ttk::combobox $open_labelframe.eol_cb			\
					-textvariable ::configDialogues::editor::default_eol	\
					-width 0						\
					-state readonly						\
					-values {{lf} {cr} {crlf}}				\
				] -row 2 -column 1 -sticky we -padx 5
				bind $open_labelframe.eol_cb <<ComboboxSelected>>	\
					{::configDialogues::editor::settings_changed}
				DynamicHelp::add $open_labelframe.eol_cb	\
					-text [mc "When you open file with unknown\nEOL (End Of Line) this EOL will be used"]
				# Item: "Autosave"
				grid [Label $open_labelframe.autosave_lbl	\
					-text [mc "Autosave interval \[minutes\]"]	\
					-helptext [mc "Autosave interval in minutes (0 means disabled)"]	\
				] -row 3 -column 0 -sticky w -padx 5
				grid [ttk::combobox $open_labelframe.autosave_cb	\
					-width 0					\
					-state readonly					\
					-values {0 1 2 5 10 15 20 30 45 60}		\
					-textvariable ::configDialogues::editor::autosave	\
				] -row 3 -column 1 -sticky we -padx 5
				bind $open_labelframe.autosave_cb <<ComboboxSelected>>	\
					{::configDialogues::editor::settings_changed}
				DynamicHelp::add $open_labelframe.autosave_cb	\
					-text [mc "Autosave interval in minutes (0 means disabled)"]
				# Finalize
				grid columnconfigure $open_labelframe 0 -minsize 200
				grid columnconfigure $open_labelframe 1 -weight 1

				## Labelframe "Command line"
				 # Item: "Enable autocompletion"
				grid [Label $cmd_labelframe.completion_lbl		\
					-text [mc "Enable autocompletion"]			\
					-helptext [mc "Enable popup-based autocompletion"]	\
				] -row 0 -column 0 -sticky w -padx 5
				grid [checkbutton $cmd_labelframe.completion_chbutton		\
					-variable ::configDialogues::editor::cline_completion	\
					-command ::configDialogues::editor::settings_changed	\
				] -row 0 -column 1 -sticky w -padx 5
				# Finalize
				grid columnconfigure $cmd_labelframe 0 -minsize 200
				grid columnconfigure $cmd_labelframe 1 -weight 1

				# Pack label frames of tab "General"
				pack $editing_labelframe	-fill both -expand 1 -padx 5 -pady 5
				pack $open_labelframe		-fill both -expand 1 -padx 5 -pady 5
				pack $cmd_labelframe		-fill both -expand 1 -padx 5 -pady 5
			}
			{colors} {	;# Tab "Colors"
				# Create label frames
				set frm_textAreaBackfround [ttk::labelframe	\
					$colors_tab.textAreaBackfround		\
					-text [mc "Text area background"]	\
					-padding 5				\
				]
				set frm_additionalElements [ttk::labelframe	\
					$colors_tab.additionalElements		\
					-text [mc "Additional elements"]	\
					-padding 5				\
				]

				# Create buttons in label frame "Text area background"
				set row 0
				foreach name {
						normal_text		selected_text		current_line
						bookmark		simulator_line		breakpoint
						breakpoint_I		error_line		trailing_space
					} text [list								\
						[mc "Normal text"]		[mc "Selected text"]		\
						[mc "Current line"]		[mc "Bookmark"]			\
						[mc "Simulator line"]		[mc "Breakpoint"]		\
						[mc "Invalid breakpoint"]	[mc "Line with an error"]	\
						[mc "Trailing space"]						\
					] {

					mk_button_select_menu					\
						$frm_textAreaBackfround				\
						"::configDialogues::editor::color_$name"	\
						$name						\
						$text
				}

				grid columnconfigure $frm_textAreaBackfround 1 -minsize 200

				# Create buttons in label frame "Text area background"
				set row 0
				foreach name {
						iconBorder_bg			lineNumbers_bg
						lineNumbers_fg
					} text [list				\
						[mc "Icon border background"]	\
						[mc "Line numbers background"]	\
						[mc "Line numbers foreground"]	\
					] {

					mk_button_select_menu				\
						$frm_additionalElements			\
						"::configDialogues::editor::color_$name"	\
						$name		\
						$text

					grid columnconfigure $frm_additionalElements 1 -minsize 200
				}

				# Pack label frames
				pack $frm_textAreaBackfround -fill both -expand 1 -pady 5 -padx 5
				pack $frm_additionalElements -fill both -expand 1 -pady 5 -padx 5
			}
			{fonts} {	;# Tab "Fonts"
				# Create frames
				set top_frame [frame $fonts_tab.frm_top_frame]
				set bottom_frame [frame $fonts_tab.frm_bottom_frame]
				set top_left_frame [frame $top_frame.frm_left]
				set top_right_frame [frame $top_frame.frm_right]

				# Create fonts listbox
				set scrollbar [ttk::scrollbar $top_left_frame.scrollbar	\
					-orient vertical				\
					-command "$top_left_frame.list_box yview"	\
				]
				set listBox [ListBox $top_left_frame.list_box	\
					-bg white				\
					-yscrollcommand "$scrollbar set"	\
					-selectfill 1				\
					-selectbackground #8888FF		\
					-highlightthickness 0			\
					-height 15				\
					-width 25				\
					-font [font create			\
						-size -13			\
						-family {helvetica}		\
					]					\
				]
				pack $scrollbar -side right -fill y
				pack $listBox -side left -fill both -expand 1
				$listBox bindText <1> {::configDialogues::editor::select_font_family %W}
				if {[winfo exists $listBox.c]} {
					bind $listBox.c <Button-5> {%W yview scroll +5 units; break}
					bind $listBox.c <Button-4> {%W yview scroll -5 units; break}
				}

				# Create size listbox
				set scrollbar [ttk::scrollbar $top_right_frame.scrollbar\
					-orient vertical				\
					-command "$top_right_frame.list_box yview"	\
				]
				set listBox [ListBox $top_right_frame.list_box		\
					-bg white				\
					-yscrollcommand "$scrollbar set"	\
					-selectfill 1				\
					-selectbackground #8888FF		\
					-width 7				\
					-height 15				\
					-highlightthickness 0			\
					-font [font create			\
						-size -13			\
						-family {helvetica}		\
					]					\
				]
				pack $scrollbar -side right -fill y
				pack $listBox -side left -fill y
				$listBox bindText <1> {::configDialogues::editor::select_font_size %W}
				if {[winfo exists $listBox.c]} {
					bind $listBox.c <Button-5> {%W yview scroll +5 units; break}
					bind $listBox.c <Button-4> {%W yview scroll -5 units; break}
				}

				# Create sample text entry
				set sample_text [entry $bottom_frame.entry	\
					-bg ${::COMMON_BG_COLOR}		\
					-bd 0					\
					-width 30				\
					-font [font create			\
						-family $sample_text_family	\
						-size -$sample_text_size	\
					]					\
				]
				pack $sample_text -pady 25
				$sample_text insert end [mc "The Quick Brown Fox Jumps Over The Lazy Dog"]

				# Pack frames
				pack $top_left_frame -side left -padx 5 -fill x
				pack $top_right_frame -side right -padx 5
				pack $top_frame -side top -pady 10
				pack $bottom_frame -side bottom -fill both -expand 1

				# Fill up sizes listbox
				for {set i 4} {$i < 22} {incr i} {
					$listBox insert end $i -text "$i"
					if {$i == $sample_text_size} {
						$top_right_frame.list_box selection set $i
					}
				}

				pack [label $bottom_frame.progress			\
					-text [mc "Searching for available fonts ..."]	\
				]

				# Fill up fonts listbox
				after idle [subst {
					if {[winfo exists $top_left_frame.list_box]} {
						set i 0
						foreach font \[font families\] {
							set font_ref \[font create -family \$font\]
							if {!\[font metrics \$font_ref -fixed\]} {
								font delete \$font_ref
								continue
							}
							font delete \$font_ref

							$top_left_frame.list_box insert end \$i -text \$font
							if {\$font == {$sample_text_family}} {
								$top_left_frame.list_box selection set \$i
							}
							incr i
							update
						}
						destroy $bottom_frame.progress
					}
				}]
			}
			{highlight} {	;# Tab "Syntax highlight"
				set highlight_notebook [ModernNoteBook $highlight_tab.nb]
				set highlight_tab_asm [$highlight_notebook insert end highlight_tab_asm	\
					-createcmd {::configDialogues::editor::create_highlight_tab 0}	\
					-text [mc "Assembler"]						\
				]
				set highlight_tab_C   [$highlight_notebook insert end highlight_tab_C	\
					-createcmd {::configDialogues::editor::create_highlight_tab 1}	\
					-text [mc "C language"]						\
				]
				set highlight_tab_lst [$highlight_notebook insert end highlight_tab_lst	\
					-createcmd {::configDialogues::editor::create_highlight_tab 2}	\
					-text [mc "Code listing"]					\
				]

				$highlight_notebook raise highlight_tab_asm
				pack [$highlight_notebook get_nb] -fill both -expand 1
			}
		}
	}

	## Create tab synatx highlight in notebook "Syntax highlight"
	 # @parm Int language - Highlighting pattern
	 #	0 - Assembler
	 #	1 - C language
	 #	2 - Code listing
	 # @retuer void
	proc create_highlight_tab {language} {
		## General
		variable highlight_tags_asm	;# List: Definition of colors and styles for assembler syntax highlighting
		variable highlight_tags_C	;# List: Definition of colors and styles for C syntax highlighting
		variable highlight_tags_lst	;# List: Definition of colors and styles for LST syntax highlighting
		variable highlight_tab_asm	;# Widget: Tab "Syntax highlight"/"Assembler"
		variable highlight_tab_C	;# Widget: Tab "Syntax highlight"/"C language"
		variable highlight_tab_lst	;# Widget: Tab "Syntax highlight"/"Code listing"

		## Assembler
		variable highlight_tab_scr_text_asm		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_asm	;# ID of text widget for sample text
		variable highlight_tab_checkbuttons_asm		;# List of checkbuttons affected by changing cursor
		variable list_of_tags_asm			;# List: Highlighting tags

		# C language
		variable highlight_tab_scr_text_C		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_C	;# ID of text widget for sample text
		variable highlight_tab_checkbuttons_C		;# List of checkbuttons affected by changing cursor
		variable list_of_tags_C				;# List: Highlighting tags

		# Code listing
		variable highlight_tab_scr_text_lst		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_lst	;# ID of text widget for sample text
		variable highlight_tab_checkbuttons_lst		;# List of checkbuttons affected by changing cursor
		variable list_of_tags_lst			;# List: Highlighting tags

		# Determinate set of highlighting tags
		switch -- $language {
			0 {
				set tab_frame $highlight_tab_asm
				set highlight_tags $highlight_tags_asm
			}
			1 {
				set tab_frame $highlight_tab_C
				set highlight_tags $highlight_tags_C
			}
			2 {
				set tab_frame $highlight_tab_lst
				set highlight_tags $highlight_tags_lst
			}
		}

		## Create widgets
		# Top frame - Contains: SCR frame (SRC header, list of tags), scrollbar
		set highlight_tab_top_frame	[frame $tab_frame.top_frame]
		# SCR frame - Contains: SRC header, list of tags
		set highlight_tab_scr_frm	[frame $highlight_tab_top_frame.src_frm -bd 1 -relief sunken]
		# Scrollbar (in Top frame)
		set highlight_tab_scrollbar	[ttk::scrollbar			\
			$highlight_tab_top_frame.scrollbar			\
			-orient vertical					\
			-command "$highlight_tab_scr_frm.scr_text_c yview"	\
		]
		# SRC header (in SCR frame)
		set highlight_tab_scr_header [text $highlight_tab_scr_frm.scr_text_h	\
			-bd 0								\
			-height 2							\
			-bg {#DFDFDF}							\
			-height 1							\
			-width 0							\
			-cursor left_ptr						\
			-font [font create						\
				-family $::DEFAULT_FIXED_FONT				\
				-size -16						\
			]	\
		]
		bind $highlight_tab_scr_header <<Selection>> {false_selection %W}
		bind $highlight_tab_scr_header <ButtonRelease-3> {break}
		bind $highlight_tab_scr_header <Key-Menu> {break}
		# Padding above the list of tags (see below)
		set padding_widget [text $highlight_tab_scr_frm.padding	\
			-bd 0					\
			-bg {#FFFFFF}				\
			-cursor left_ptr			\
			-font [font create			\
				-size -15			\
				-family $::DEFAULT_FIXED_FONT	\
			]					\
			-height 1				\
			-width 1				\
		]
		# List of tags (in SCR frame)
		set highlight_tab_scr_text [text $highlight_tab_scr_frm.scr_text_c	\
			-bd 0								\
			-bg {#FFFFFF}							\
			-cursor left_ptr						\
			-font [font create						\
				-size -12						\
				-family $::DEFAULT_FIXED_FONT				\
			]								\
			-yscrollcommand "$highlight_tab_scrollbar set"			\
			-width 1							\
			-tabstyle wordprocessor						\
		]
		$highlight_tab_scr_text tag configure sel_user	\
			-borderwidth 1 -background {#CCCCFF} -relief raised
		switch -- $language {
			0 {set sh_ns ASMsyntaxHighlight}
			1 {set sh_ns CsyntaxHighlight}
			2 {set sh_ns LSTsyntaxHighlight}
		}
		${sh_ns}::create_tags $highlight_tab_scr_text 12 $::DEFAULT_FIXED_FONT $highlight_tags 1
		bind $highlight_tab_scr_text <<Selection>> {false_selection %W}
		bind $highlight_tab_scr_text <ButtonRelease-3> {break}
		bind $highlight_tab_scr_text <Key-Menu> {break}
		bind $highlight_tab_scr_text <Button-4> "$highlight_tab_scr_text yview scroll -1 units"
		bind $highlight_tab_scr_text <Button-5> "$highlight_tab_scr_text yview scroll +1 units"
		# Sample text
		set highlight_tab_scr_sample_text [text $tab_frame.scr_text_sample	\
			-bd 1								\
			-bg {#FFFFFF}							\
			-width 0							\
			-height 3							\
			-maxundo 0							\
			-wrap none							\
			-selectborderwidth 1						\
			-highlightcolor gray						\
			-tabstyle wordprocessor						\
			-font [font create -weight bold -size -12 -family $::DEFAULT_FIXED_FONT] \
		]
		${sh_ns}::create_tags $highlight_tab_scr_sample_text 12 $::DEFAULT_FIXED_FONT $highlight_tags
		bind $highlight_tab_scr_sample_text <KeyRelease> "::configDialogues::editor::parse %K $language"
		bind $highlight_tab_scr_sample_text <ButtonPress-1>	\
			"::configDialogues::editor::syntax_sample_text_click %x %y $language"
		switch -- $language {
			0 {
				$highlight_tab_scr_sample_text insert end [join [list \
					"FOX0	equ	(100 % Xer)\n" \
					"main:	inc	FOX0	; [mc {increment some register}]\n" \
					"	sjmp	main	; [mc {close main loop}]" \
				] {}]
			}
			1 {
				$highlight_tab_scr_sample_text insert end [join [list \
					"/** @sa DOXYGEN <b> **/ // [mc {Comment}]\n" \
					"unsigned int func() {\n" \
						"\treturn 0xFA+044-58+'d'\n" \
					"}\n" \
					"printf(\"[mc {String}] %f\", 7.2);\n" \
					"#define [mc {macro Some value}]\n" \
					"#include <some_lib.h>" \
				] {}]
			}
			2 {
				$highlight_tab_scr_sample_text insert end [join {
					{  0055			18	X       data	55h}	\
					{		=1	32	sub_0:}			\
					{0014 1122	=1	33 +1		inc	A}	\
				} "\n"]
			}
		}

		# Pack widgets
		pack $highlight_tab_scr_header -in $highlight_tab_scr_frm -fill x -expand 1 -anchor n
		pack $padding_widget -in $highlight_tab_scr_frm -fill x
		pack $highlight_tab_scr_text -in $highlight_tab_scr_frm -fill both -expand 1
		pack $highlight_tab_scrollbar -side right -fill y
		pack $highlight_tab_scr_frm -side left -expand 1 -fill both
		pack $highlight_tab_scr_sample_text -side bottom -fill x -expand 0
		pack $highlight_tab_top_frame -side top -fill both -expand 1

		# Create content of "SCR header"
		$highlight_tab_scr_header tag configure tag_normal \
			-font [$highlight_tab_scr_text cget -font]
		$highlight_tab_scr_header insert end "  [mc {Content}]               "
		$highlight_tab_scr_header image create end -image ::ICONS::16::text_italic -pady 0
		$highlight_tab_scr_header insert end " "
		$highlight_tab_scr_header image create end -image ::ICONS::16::text_strike -pady 0
		$highlight_tab_scr_header insert end " "
		$highlight_tab_scr_header image create end -image ::ICONS::16::text_bold -pady 0
		$highlight_tab_scr_header insert end " [mc {Color}]"
		$highlight_tab_scr_header configure -state disabled
		$highlight_tab_scr_header tag add tag_normal 1.0 end

		# Create content of "list of tags"
		set row 0				;# Number of current row
		set list_of_tags {}			;# List of highlighting tags
		set highlight_tab_checkbuttons {}	;# List of check buttons
		foreach key $highlight_tags {
			incr row

			# Local variables
			set tag		[lindex $key 0]	;# ID of the text tag
			set content	{  }		;# Name of the text tag
			set color	[lindex $key 1]	;# RGB: Foreground color
			set overstrike	[lindex $key 2]	;# Bool: Overstrike
			set italic	[lindex $key 3]	;# Bool: Italic
			set bold	[lindex $key 4]	;# Bool: Bold

			# Modify some variables
			append content [mc [key2name $tag]]
			set localButtons {}
			lappend list_of_tags $tag

			# Determinate font weight
			if {$bold} {
				set weight bold
			} else {
				set weight normal
			}

			# Determinate font slant
			if {$italic} {
				set slant italic
			} else {
				set slant roman
			}

			# Initialize some NS variables
			set ::configDialogues::editor::__${language}_${row}_italic $italic
			set ::configDialogues::editor::__${language}_${row}_overstrike $overstrike
			set ::configDialogues::editor::__${language}_${row}_bold $bold

			# Insert tag name and some '\t'
			$highlight_tab_scr_text insert end $content
			set len [string length $content]
			$highlight_tab_scr_text tag add $tag		\
				[$highlight_tab_scr_text index {insert linestart}]	\
				[$highlight_tab_scr_text index insert]
			$highlight_tab_scr_text insert end [string repeat { } [expr {24 - $len}]]

			# Insert checkbutton "Italic"
			set button [checkbutton $highlight_tab_scr_frm.italic_${row}			\
				-command "::configDialogues::editor::change_style italic $row $language"\
				-variable ::configDialogues::editor::__${language}_${row}_italic	\
				-relief flat								\
				-pady 0									\
				-highlightthickness 0							\
				-bg {#FFFFFF}								\
				-activebackground {#FFFFFF}						\
				-selectcolor {#FFFFFF}							\
			]
			lappend localButtons $button
			$highlight_tab_scr_text window create end -window $button
			$highlight_tab_scr_text insert end " "

			# Insert checkbutton "Overstike"
			set button [checkbutton $highlight_tab_scr_frm.overstrike_${row}			\
				-command "::configDialogues::editor::change_style overstrike $row $language"	\
				-variable ::configDialogues::editor::__${language}_${row}_overstrike		\
				-relief flat									\
				-pady 0										\
				-highlightthickness 0								\
				-bg {#FFFFFF}									\
				-activebackground {#FFFFFF}							\
				-selectcolor {#FFFFFF}								\
			]
			lappend localButtons $button
			$highlight_tab_scr_text window create end -window $button
			$highlight_tab_scr_text insert end " "

			# Insert checkbutton "Bold"
			set button [checkbutton $highlight_tab_scr_frm.bold_${row}			\
				-command "::configDialogues::editor::change_style bold $row $language"	\
				-variable ::configDialogues::editor::__${language}_${row}_bold		\
				-relief flat								\
				-pady 0									\
				-highlightthickness 0							\
				-bg {#FFFFFF}								\
				-activebackground {#FFFFFF}						\
				-selectcolor {#FFFFFF}							\
			]
			lappend localButtons $button
			$highlight_tab_scr_text window create end -window $button
			$highlight_tab_scr_text insert end " "

			# Insert button "Color"
			set button [button $highlight_tab_scr_frm.color_${row}		\
				-bd 1 -relief raised -pady 0 -highlightthickness 0	\
				-bg $color -activebackground $color -width 3		\
				-command "::configDialogues::editor::select_bg_color $highlight_tab_scr_frm.color_${row} $row $language"	\
			]
			$highlight_tab_scr_text window create end -window $button

			# Insert LF
			$highlight_tab_scr_text insert end "\n"

			# Append local buttons to list of checkbuttons
			lappend highlight_tab_checkbuttons $localButtons
		}

		# Disable text widget "List of tags" and remove last line (empty line)
		$highlight_tab_scr_text delete end-1l end
		$highlight_tab_scr_text configure -state disabled

		# Set NS variables
		switch -- $language {
			0 {
				set highlight_tab_scr_text_asm		$highlight_tab_scr_text
				set highlight_tab_scr_sample_text_asm	$highlight_tab_scr_sample_text
				set highlight_tab_checkbuttons_asm	$highlight_tab_checkbuttons
				set list_of_tags_asm			$list_of_tags
			}
			1 {
				set highlight_tab_scr_text_C		$highlight_tab_scr_text
				set highlight_tab_scr_sample_text_C	$highlight_tab_scr_sample_text
				set highlight_tab_checkbuttons_C	$highlight_tab_checkbuttons
				set list_of_tags_C			$list_of_tags
			}
			2 {
				set highlight_tab_scr_text_lst		$highlight_tab_scr_text
				set highlight_tab_scr_sample_text_lst	$highlight_tab_scr_sample_text
				set highlight_tab_checkbuttons_lst	$highlight_tab_checkbuttons
				set list_of_tags_lst			$list_of_tags
			}
		}

		# Initialize syntax highlight
		if {$language != 1} {
			for {set i 1} {$i < int([$highlight_tab_scr_sample_text index end])} {incr i} {
				set lineEnd [$highlight_tab_scr_sample_text index "$i.0 lineend"]
				set lineStart $i.0

				${sh_ns}::highlight $highlight_tab_scr_sample_text $i
			}
		} else {
			parse {} 1
		}
	}

	## This function should be called always after change of $editor_to_use
	 # @return void
	proc editor_to_use_changed {} {
		variable nb		;# Widget: Notebook itself
		variable editor_to_use	;# Int: Preferred editor
		variable general_tab	;# Widget: Tab "General"
		variable highlight_tab	;# Widget: Tab "Syntax highlight"

		settings_changed

		if {$editor_to_use} {
			set state disabled
		} else {
			set state normal
		}
		foreach tab [list general_tab highlight_tab] {
			$nb itemconfigure $tab -state $state
		}
	}

	## Create some text tag in the given text widget
	 # @parm Widget text_widget	- target text widget
	 # @parm Int item		- index of the tag (in variable highlight_tags)
	 # @parm Int language		- Highlighting pattern
		#	0 - Assembler
		#	1 - C language
		#	2 - Code listing
	 # @return void
	proc create_tags {text_widget item language} {
		variable highlight_tags_asm	;# List: Definition of colors and styles for assembler syntax highlighting
		variable highlight_tags_C	;# List: Definition of colors and styles for C syntax highlighting
		variable highlight_tags_lst	;# List: Definition of colors and styles for LST syntax highlighting

		# Determinate set of highlighting tags
		switch -- $language {
			0 {
				set highlight_tags $highlight_tags_asm
			}
			1 {
				set highlight_tags $highlight_tags_C
			}
			2 {
				set highlight_tags $highlight_tags_lst
			}
		}

		# Gain tag definition
		set item [lindex $highlight_tags $item]
		# Create array of tag attributes
		for {set i 0} {$i < 5} {incr i} {
			set tag($i) [lindex $item $i]
		}

		# Foreground color
		if {$tag(1) == {}} {
			set tag(1) black
		}
		# Font slant
		if {$tag(3) == 1} {
			set tag(3) italic
		} else {
			set tag(3) roman
		}

		# Font weight
		if {!$::MICROSOFT_WINDOWS} {
			if {$tag(4) == 1} {
				set tag(4) bold
			} else {
				set tag(4) normal
			}
		} else {
			set tag(4) normal
		}

		# Create the tag
		$text_widget tag configure $tag(0)		\
			-foreground $tag(1)			\
			-font [ font create			\
				-overstrike $tag(2)		\
				-slant $tag(3)			\
				-weight $tag(4)			\
				-size -12			\
				-family $::DEFAULT_FIXED_FONT	\
			]
	}

	## Call procedure syntax_find
	 # @parm Int x - relative X coordinate
	 # @parm Int y - relative Y coordinate
	 # @parm Int language - Highlighting pattern
	 #	0 - Assembler
	 #	1 - C language
	 #	2 - Code listing
	 # @return void
	proc syntax_sample_text_click {x y language} {
		variable highlight_tab_scr_sample_text_asm	;# ID of text widget for sample text
		variable highlight_tab_scr_sample_text_C	;# ID of text widget for sample text
		variable highlight_tab_scr_sample_text_lst	;# ID of text widget for sample text

		switch -- $language {
			0 {set text $highlight_tab_scr_sample_text_asm}
			1 {set text $highlight_tab_scr_sample_text_C}
			2 {set text $highlight_tab_scr_sample_text_lst}
		}
		syntax_find [$text index @$x,$y] $language
	}

	## Find tag used at the giuven index
	 # @parm TextIndex text_index - text index
	 # @parm Int language - Highlighting pattern
	 #	0 - Assembler
	 #	1 - C language
	 #	2 - Code listing
	 # @return void
	proc syntax_find {text_index language} {
		variable list_of_tags_asm			;# List: Highlighting tags
		variable highlight_tab_checkbuttons_asm		;# List of checkbuttons affected by changing curosr
		variable highlight_tab_scr_text_asm		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_asm	;# ID of text widget for sample text

		## Assembler
		variable highlight_tab_scr_text_asm		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_asm	;# ID of text widget for sample text
		variable highlight_tab_checkbuttons_asm		;# List of checkbuttons affected by changing cursor
		variable list_of_tags_asm			;# List: Highlighting tags

		# C language
		variable highlight_tab_scr_text_C		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_C	;# ID of text widget for sample text
		variable highlight_tab_checkbuttons_C		;# List of checkbuttons affected by changing cursor
		variable list_of_tags_C				;# List: Highlighting tags

		# Code listing
		variable highlight_tab_scr_text_lst		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_lst	;# ID of text widget for sample text
		variable highlight_tab_checkbuttons_lst		;# List of checkbuttons affected by changing cursor
		variable list_of_tags_lst			;# List: Highlighting tags


		# Determinate set of highlighting tags
		switch -- $language {
			0 {
				set list_of_tags			$list_of_tags_asm
				set highlight_tab_checkbuttons		$highlight_tab_checkbuttons_asm
				set highlight_tab_scr_text		$highlight_tab_scr_text_asm
				set highlight_tab_scr_sample_text	$highlight_tab_scr_sample_text_asm
			}
			1 {
				set list_of_tags			$list_of_tags_C
				set highlight_tab_checkbuttons		$highlight_tab_checkbuttons_C
				set highlight_tab_scr_text		$highlight_tab_scr_text_C
				set highlight_tab_scr_sample_text	$highlight_tab_scr_sample_text_C
			}
			2 {
				set list_of_tags			$list_of_tags_lst
				set highlight_tab_checkbuttons		$highlight_tab_checkbuttons_lst
				set highlight_tab_scr_text		$highlight_tab_scr_text_lst
				set highlight_tab_scr_sample_text	$highlight_tab_scr_sample_text_lst
			}
		}

		# Remove previous selection
		if {[$highlight_tab_scr_text tag ranges {sel_user}] != {}} {
			set index [$highlight_tab_scr_text index sel_user.first]
			set buttons [lindex $highlight_tab_checkbuttons [expr {int($index) - 1}]]
			foreach button $buttons {
				$button configure		\
					-bg {#FFFFFF}		\
					-selectcolor {#FFFFFF}	\
					-activebackground {#FFFFFF}
			}
			$highlight_tab_scr_text tag remove sel_user 1.0 end
		}

		# Determinate tag name
		set index [$highlight_tab_scr_sample_text index $text_index]
		set index [$highlight_tab_scr_sample_text tag names $index]

		# Remove tags subdued to other tags which are also contained in the tag list
		if {[llength $index] > 1} {
			set idx [lsearch -ascii -exact $index tag_c_dox_comment]
			if {$idx != -1} {
				set index [lreplace $index $idx $idx]
			}

			set idx [lsearch -ascii -exact $index tag_normal]
			if {$idx != -1} {
				set index [lreplace $index $idx $idx]
			}
		}

		# If the tag could not be determinated -> abort
		set index [lindex $index 0]
		if {$index == {}} {return}

		# Determinate tag number
		set index [lsearch $list_of_tags $index]
		if {$index == -1} {return}

		# Change background color for checkbuttons related to the tag
		set buttons [lindex $highlight_tab_checkbuttons $index]
		foreach button $buttons {
			$button configure		\
				-bg {#CCCCFF}		\
				-selectcolor {#CCCCFF}	\
				-activebackground {#CCCCFF}
		}

		# Select row related to the tag
		incr index
		$highlight_tab_scr_text tag add sel_user $index.0 [expr {$index + 1}].0
		$highlight_tab_scr_text see $index.0
	}

	## Manages syntax highlighting in sample text
	 # @parm String key - ID of the released key
	 # @parm Int language - Highlighting pattern
	 #	0 - Assembler
	 #	1 - C language
	 #	2 - Code listing
	 # @return void
	proc parse {key language} {
		variable highlight_tab_scr_sample_text_asm	;# ID of text widget for sample text
		variable highlight_tab_scr_sample_text_C	;# ID of text widget for sample text
		variable highlight_tab_scr_sample_text_lst	;# ID of text widget for sample text

		switch -- $language {
			0 {
				set widget $highlight_tab_scr_sample_text_asm
			}
			1 {
				set widget $highlight_tab_scr_sample_text_C
			}
			2 {
				set widget $highlight_tab_scr_sample_text_lst
			}
		}

		set lineNumber [expr {int([$widget index insert])}]

		# Keep indentication level after line break
		if {$key == "KP_Enter" || $key == "Return"} {
			# Get content of previous line
			set prev_line [$widget get				\
				[$widget index {insert - 1 line linestart}]	\
				[$widget index {insert - 1 line lineend}]	\
			]

			# Determinate indentication characters
			set indent_chars {}
			regexp {^\s+} $prev_line indent_chars

			# Insert indentication characters
			if {$indent_chars != {}} {
				$widget insert $lineNumber.0 $indent_chars
			}
		}

		# Syntax highlight for assembler or code listing
		if {$language == 0 || $language == 2} {
			# Highlight current line
			if {[lsearch {
					Left Right Down Up Insert Home Prior
					End Next Shift_R Control_R Alt_L Alt_R
					Control_L Shift_L Escape
				} $key] == -1} then {
					if {$language == 0} {
						::ASMsyntaxHighlight::highlight $widget $lineNumber
					} else {
						::LSTsyntaxHighlight::highlight $widget $lineNumber
					}
			}

		# Syntax highlight for C language
		} else {
			# Highlight all lines
			if {[lsearch {
					Left Right Down Up Insert Home Prior
					End Next Shift_R Control_R Alt_L Alt_R
					Control_L Shift_L Escape
				} $key] == -1} then {
					set status 1
					set end_line [expr {int([$widget index end])}]
					for {set line 0} {$line < $end_line} {incr line} {
						set status [::CsyntaxHighlight::highlight	\
							$widget $line $status			\
						]
					}
			}
		}

		# Change selection in "Tag List"
		syntax_find [$widget index insert] $language
	}

	## Change font family for sample text entry in tab "Fonts"
	 # @parm Widget widget	- source listbox
	 # @parm String item	- ID of current item in source listbox
	 # @return void
	proc select_font_family {widget item} {
		variable sample_text		;# ID of text widget for sample text
		variable sample_text_size	;# Font size
		variable sample_text_family	;# Font family

		# Select item in the lisbox
		set sample_text_family [$widget itemcget $item -text]
		$widget selection set $item

		# Change font in sample text
		$sample_text configure -font [font create	\
			-family $sample_text_family		\
			-size -$sample_text_size]

		# Adjust status changed
		settings_changed
	}

	## Change font size for sample text entry in tab "Fonts"
	 # @parm Widget widget	- source listbox
	 # @parm String item	- ID of current item in source listbox
	 # @return void
	proc select_font_size {widget item} {
		variable sample_text		;# ID of text widget for sample text
		variable sample_text_size	;# Font size
		variable sample_text_family	;# Font family

		# Select item in the lisbox
		set sample_text_size $item
		$widget selection set $item

		# Change font in sample text
		$sample_text configure -font [font create	\
			-family $sample_text_family		\
			-size -$sample_text_size		\
		]

		# Adjust status changed
		settings_changed
	}

	## Change font style in sample text and list of tags in tab "Syntax highlight"
	 # @parm String what	- ID of style
	 # @parm Int row	- number of row in "List of tags"
	 # @parm Int language - Highlighting pattern
	 #	0 - Assembler
	 #	1 - C language
	 #	2 - Code listing
	 # @return void
	proc change_style {what row language} {
		variable highlight_tags_asm		;# List: Definition of colors and styles for assembler syntax highlighting
		variable highlight_tags_C		;# List: Definition of colors and styles for C syntax highlighting
		variable highlight_tags_lst		;# List: Definition of colors and styles for LST syntax highlighting

		variable highlight_tab_scr_text_C		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_C	;# ID of text widget for sample text
		variable highlight_tab_scr_text_asm		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_asm	;# ID of text widget for sample text
		variable highlight_tab_scr_text_lst		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_lst	;# ID of text widget for sample text


		incr row -1

		# Determinate set of highlighting tags and text widget
		switch -- $language {
			0 {
				set highlight_tab_scr_sample_text	$highlight_tab_scr_sample_text_asm
				set highlight_tab_scr_text		$highlight_tab_scr_text_asm
				set highlight_tags			highlight_tags_asm
			}
			1 {
				set highlight_tab_scr_sample_text	$highlight_tab_scr_sample_text_C
				set highlight_tab_scr_text		$highlight_tab_scr_text_C
				set highlight_tags			highlight_tags_C
			}
			2 {
				set highlight_tab_scr_sample_text	$highlight_tab_scr_sample_text_lst
				set highlight_tab_scr_text		$highlight_tab_scr_text_lst
				set highlight_tags			highlight_tags_lst
			}
		}

		# Decide what to change
		switch -- $what {
			overstrike	{
				lset $highlight_tags [list $row 2]	\
					[subst -nocommands "\${::configDialogues::editor::__${language}_[expr {$row + 1}]_overstrike}"]
			}
			italic	{
				lset $highlight_tags [list $row 3]	\
					[subst -nocommands "\${::configDialogues::editor::__${language}_[expr {$row + 1}]_italic}"]
			}
			bold	{
				lset $highlight_tags [list $row 4]	\
					[subst -nocommands "\${::configDialogues::editor::__${language}_[expr {$row + 1}]_bold}"]
			}
			default {return}
		}

		# Change tags
		create_tags $highlight_tab_scr_sample_text $row $language
		create_tags $highlight_tab_scr_text $row $language

		# Adjust status changed
		settings_changed
	}

	## Validate content of nofs_spinbox
	 # @parm String content - content to validate
	 # @return Bool - success
	proc nofs_spinbox_val {content} {
		if {![string length $content]} {
			return 1
		}
		if {![string is digit $content]} {
			return 0
		}
		if {$content > 16 || $content < 1} {
			return 0
		}
		::configDialogues::editor::settings_changed
		return 1
	}

	## Validate content of tabw_spinbox
	 # @parm String content - content to validate
	 # @return Bool - success
	proc tabw_spinbox_val {content} {
		if {![string length $content]} {
			return 1
		}
		if {![string is digit $content]} {
			return 0
		}
		if {$content > 40 || $content < 1} {
			return 0
		}
		::configDialogues::editor::settings_changed
		return 1
	}

	## Change font color in sample text and list of tags in tab "Syntax highlight"
	 # @parm Widget button	- ID of the button used to change the color
	 # @parm Int row	- number of row in "List of tags"
	 # @parm Int language - Highlighting pattern
	 #	0 - Assembler
	 #	1 - C language
	 #	2 - Code listing
	 # @return void
	proc select_bg_color {button row language} {
		variable win				;# ID of dialog toplevel window
		variable highlight_tags_asm		;# List: Definition of colors and styles for assembler syntax highlighting
		variable highlight_tags_C		;# List: Definition of colors and styles for C syntax highlighting
		variable highlight_tags_lst		;# List: Definition of colors and styles for LST syntax highlighting

		variable highlight_tab_scr_text_asm		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_asm	;# ID of text widget for sample text
		variable highlight_tab_scr_text_C		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_C	;# ID of text widget for sample text
		variable highlight_tab_scr_text_lst		;# ID of text widget for configuring syntax
		variable highlight_tab_scr_sample_text_lst	;# ID of text widget for sample text

		# Determinate set of highlighting tags
		switch -- $language {
			0 {
				set highlight_tab_scr_sample_text	$highlight_tab_scr_sample_text_asm
				set highlight_tab_scr_text		$highlight_tab_scr_text_asm
				set highlight_tags_var			highlight_tags_asm
				set highlight_tags			$highlight_tags_asm
			}
			1 {
				set highlight_tab_scr_sample_text	$highlight_tab_scr_sample_text_C
				set highlight_tab_scr_text		$highlight_tab_scr_text_C
				set highlight_tags_var			highlight_tags_C
				set highlight_tags			$highlight_tags_C
			}
			2 {
				set highlight_tab_scr_sample_text	$highlight_tab_scr_sample_text_lst
				set highlight_tab_scr_text		$highlight_tab_scr_text_lst
				set highlight_tags_var			highlight_tags_lst
				set highlight_tags			$highlight_tags_lst
			}
		}

		incr row -1

		# Destroy prevoisly opened color selection dialog
		if {[winfo exists .select_color]} {
			destroy .select_color
		}

		# Invoke new color selection dialog
		set color [lindex $highlight_tags [list $row 1]]
		set color [SelectColor .select_color		\
			-parent $win				\
			-color $color				\
			-title [mc "Select color - %s" ${::APPNAME}]	\
		]

		# Change button background color
		if {$color != {}} {
			lset $highlight_tags_var [list $row 1] $color
			$button configure -bg $color -activebackground $color
		}

		# Change tags
		create_tags $highlight_tab_scr_sample_text $row $language
		create_tags $highlight_tab_scr_text $row $language

		# Adjust status changed
		settings_changed
	}

	## Translate Tk tag name to human readable string
	 # @parm String key - tag name
	 # @return String - result
	proc key2name {key} {
		switch -- $key {
			tag_char		{return {Char}}
			tag_hex			{return {Hexadecimal number}}
			tag_oct			{return {Octal number}}
			tag_dec			{return {Decimal number}}
			tag_bin			{return {Binary number}}
			tag_constant		{return {Constant}}
			tag_unknown_base	{return {Generic number}}
			tag_string		{return {String}}
			tag_comment		{return {Comment}}
			tag_control		{return {Control sequence}}
			tag_symbol		{return {Symbol}}
			tag_oper_sep		{return {Operand separator}}
			tag_directive		{return {Directive}}
			tag_label		{return {Label}}
			tag_instruction 	{return {Instruction}}
			tag_sfr			{return {SFR register}}
			tag_indirect		{return {Indirect address}}
			tag_imm_char		{return {Immediate char}}
			tag_imm_hex		{return {Immediate hex}}
			tag_imm_oct		{return {Immediate oct}}
			tag_imm_dec		{return {Immediate dec}}
			tag_imm_bin		{return {Immediate bin}}
			tag_imm_constant	{return {Immediate const}}
			tag_imm_unknown		{return {Immediate generic}}
			tag_macro		{return {Macro instruction}}

			tag_c_keyword		{return {Keyword}}
			tag_c_data_type		{return {Data type}}
			tag_c_dec		{return {Decimal}}
			tag_c_hex		{return {Hexadecimal}}
			tag_c_bin		{return {Binary number}}
			tag_c_oct		{return {Octal}}
			tag_c_char		{return {Char}}
			tag_c_float		{return {Float}}
			tag_c_string		{return {String}}
			tag_c_string_char	{return {String char}}
			tag_c_comment		{return {Comment}}
			tag_c_symbol		{return {Symbol}}
			tag_c_bracket		{return {Bracket}}
			tag_c_preprocessor	{return {Preprocessor}}
			tag_c_directive		{return {Directive}}
			tag_c_prep_lib		{return {Preprocessor lib.}}
			tag_normal		{return {Normal text}}
			tag_c_dox_comment	{return {Doxygen: Comment}}
			tag_c_dox_tag		{return {Doxygen: Tag}}
			tag_c_dox_word		{return {Doxygen: Word}}
			tag_c_dox_name		{return {Doxygen: Name}}
			tag_c_dox_html		{return {Doxygen: HTML}}
			tag_c_dox_harg		{return {Doxygen: HTML arg.}}
			tag_c_dox_hargval	{return {Doxygen: HTML val.}}

			tag_lst_number		{return {Value}}
			tag_lst_code		{return {Processor code}}
			tag_lst_address		{return {Address}}
			tag_lst_line		{return {Line number}}
			tag_lst_macro		{return {Macro level}}
			tag_lst_include		{return {Inclusion level}}
			tag_lst_error		{return {Error / Warning}}
			tag_lst_msg		{return {Message}}
		}
	}


	## Create button for selecting some color (used in tab "Colors")
	 # @parm Widget parent		- parent frame
	 # @parm Variable variable	- variable containg button background color (RGB format)
	 # @parm String name		- button name (used in GUI path)
	 # @parm String text		- text showed beside the button
	 # @return void
	proc mk_button_select_menu {parent variable name text} {
		variable row		;# General purpose variable (some row somewhere)
		variable win		;# ID of dialog toplevel window
		variable button_index	;# Button index (for creating many buttons)

		# Get color from the given variable
		set color [subst -nocommands "\${$variable}"]

		# Create button label
		grid [label $parent.${name}${button_index}	\
			-text $text		\
			-anchor w -bd 0 -relief raised		\
			-pady 0 -highlightthickness 0		\
		] -column 1 -row $row -sticky we
		# Create button
		set button [button $parent.but_normal_text$button_index		\
			-bd 1 -relief raised -pady 0 -highlightthickness 0	\
			-bg $color -width 10 -activebackground $color		\
			-command "::configDialogues::editor::select_color $variable $parent.but_normal_text$button_index"
		]

		# Show button
		grid $button -column 2 -row $row -sticky ns -padx 10

		# Adjust button index and current row
		incr button_index
		incr row
	}

	## Select some color (command for buttons in tab "Colors")
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

			# Adjust status changed
			settings_changed
		}
	}

	## Retrieve settings related to this dialog from the program
	 # @return void
	proc getSettings {} {
		variable editor_to_use		;# Int: Prefred editor
		variable default_encoding	;# Default encoding for opening files
		variable default_eol		;# Default EOL character
		variable intentation_mode	;# Editor indentation mode
		variable spaces_no_tabs		;# Bool: Use spaces instead of tabs
		variable number_of_spaces	;# Number of spaces to use instead of tab
		variable tab_width		;# Int: Tab width
		variable autosave		;# Int: Autosave interval in minutes (0 == disabled)
		variable auto_completion	;# Bool: Enable popup-base completion
		variable cline_completion	;# Bool: Enable popup-based completion for command line
		variable auto_brackets		;# Automaticaly insert oposite brackets, quotes, etc.
		variable hg_trailing_sp		;# Bool: Highlight trailing space

		variable color_normal_text	;# RGB: Editor backgound color
		variable color_selected_text	;# RGB: Backgound color for selected text
		variable color_current_line	;# RGB: Backgound color for current line
		variable color_bookmark		;# RGB: Backgound color for bookmarks
		variable color_breakpoint	;# RGB: Backgound color for breakpoints
		variable color_breakpoint_I	;# RGB: Backgound color for invalid breakpoints
		variable color_simulator_line	;# RGB: Backgound color for simulator line
		variable color_error_line	;# RGB: Backgound color for line containing an error
		variable color_trailing_space	;# RGB: Backgound color for trailing space

		variable color_iconBorder_bg	;# RGB: Backgound color for icon border
		variable color_lineNumbers_bg	;# RGB: Backgound color for line numbers
		variable color_lineNumbers_fg	;# RGB: Foregound color for line numbers

		variable sample_text_size	;# Font size
		variable sample_text_family	;# Font family
		variable highlight_tags_asm	;# List: Definition of colors and styles for assembler syntax highlighting
		variable highlight_tags_C	;# List: Definition of colors and styles for C syntax highlighting
		variable highlight_tags_lst	;# List: Definition of colors and styles for LST syntax highlighting


		# Get highlighting tags
		set highlight_tags_asm	${::ASMsyntaxHighlight::highlight_tags}
		set highlight_tags_C	${::CsyntaxHighlight::highlight_tags}
		set highlight_tags_lst	${::LSTsyntaxHighlight::highlight_tags}

		# Get data from editor NS
		set intentation_mode		[mc ${::Editor::intentation_mode}]
		set spaces_no_tabs		${::Editor::spaces_no_tabs}
		set number_of_spaces		${::Editor::number_of_spaces}
		set tab_width			${::Editor::tab_width}
		set auto_completion		${::Editor::auto_completion}
		set cline_completion		${::Editor::cline_completion}
		set autosave			${::Editor::autosave}
		set auto_brackets		${::Editor::auto_brackets}
		set hg_trailing_sp		${::Editor::hg_trailing_sp}
		set sample_text_size		${::Editor::fontSize}
		set sample_text_family		${::Editor::fontFamily}
		set color_normal_text		${::Editor::normal_text_bg}
		set color_iconBorder_bg		${::Editor::iconBorder_bg}
		set color_lineNumbers_bg	${::Editor::lineNumbers_bg}
		set color_lineNumbers_fg	${::Editor::lineNumbers_fg}
		set editor_to_use		[::settings getValue	\
			"Editor config/editor_to_use"			\
			${::Editor::editor_to_use}			\
		]

		# Get data from filelist NS
		set default_encoding		${::FileList::default_encoding}
		set default_eol			${::FileList::default_eol}

		foreach record ${::Editor::line_markers} {
			set key [lindex $record 0]
			set val [lindex $record 1]

			switch -- $key {
				{sel}			{
					set color_selected_text	$val
				}
				{tag_current_line}	{
					set color_current_line	$val
				}
				{tag_bookmark}		{
					set color_bookmark	$val
				}
				{tag_breakpoint}	{
					set color_breakpoint	$val
				}
				{tag_breakpoint_INVALID} {
					set color_breakpoint_I	$val
				}
				{tag_simulator_curr}	{
					set color_simulator_line $val
				}
				{tag_error_line}	{
					set color_error_line	$val
				}
				{tag_trailing_space}	{
					set color_trailing_space $val
				}
				default {
					error "Error: Inconsistency in configuration managment, ::Editor::line_markers"
				}
			}
		}
	}

	## Change content of configuration variables in Editor NS, Filelist NS and SyntaxHighlight NS
	 # @return void
	proc use_settings {} {
		variable autocompletion_turned_on

		variable default_encoding	;# Default encoding for opening files
		variable default_eol		;# Default EOL character
		variable intentation_mode	;# Editor indentation mode
		variable spaces_no_tabs		;# Bool: Use spaces instead of tabs
		variable number_of_spaces	;# Number of spaces to use instead of tab
		variable tab_width		;# Int: Tab width
		variable autosave		;# Int: Autosave interval in minutes (0 == disabled)
		variable auto_completion	;# Bool: Enable popup-base completion
		variable cline_completion	;# Bool: Enable popup-based completion for command line
		variable auto_brackets		;# Automaticaly insert oposite brackets, quotes, etc.
		variable hg_trailing_sp		;# Bool: Highlight trailing space

		variable editor_to_use		;# Int: Prefred editor
		variable color_normal_text	;# RGB: Editor backgound color
		variable color_selected_text	;# RGB: Backgound color for selected text
		variable color_current_line	;# RGB: Backgound color for current line
		variable color_bookmark		;# RGB: Backgound color for bookmarks
		variable color_breakpoint	;# RGB: Backgound color for breakpoints
		variable color_breakpoint_I	;# RGB: Backgound color for invalid breakpoints
		variable color_simulator_line	;# RGB: Backgound color for simulator line
		variable color_error_line	;# RGB: Backgound color for line containing an error
		variable color_trailing_space	;# RGB: Backgound color for trailing space

		variable color_iconBorder_bg	;# RGB: Backgound color for icon border
		variable color_lineNumbers_bg	;# RGB: Backgound color for line numbers
		variable color_lineNumbers_fg	;# RGB: Foregound color for line numbers

		variable sample_text_size	;# Font size
		variable sample_text_family	;# Font family
		variable highlight_tags_asm	;# List: Definition of colors and styles for assembler syntax highlighting
		variable highlight_tags_C	;# List: Definition of colors and styles for C syntax highlighting
		variable highlight_tags_lst	;# List: Definition of colors and styles for LST syntax highlighting

		if {!${::Editor::auto_completion} && $auto_completion} {
			set autocompletion_turned_on 1
		} else {
			set autocompletion_turned_on 0
		}

		## Filelist
		set FileList::default_encoding	$default_encoding
		set FileList::default_eol	$default_eol

		## Editor
		set Editor::intentation_mode	[mc $intentation_mode]
		set Editor::spaces_no_tabs	$spaces_no_tabs
		set Editor::auto_brackets	$auto_brackets
		set Editor::hg_trailing_sp	$hg_trailing_sp
		set Editor::auto_completion	$auto_completion
		set Editor::cline_completion	$cline_completion
		set Editor::autosave		$autosave
		set Editor::normal_text_bg	$color_normal_text
		set Editor::iconBorder_bg	$color_iconBorder_bg
		set Editor::lineNumbers_bg	$color_lineNumbers_bg
		set Editor::lineNumbers_fg	$color_lineNumbers_fg
		set Editor::fontSize		$sample_text_size
		set Editor::fontFamily		$sample_text_family

		if {$number_of_spaces != {}} {
			set Editor::number_of_spaces	$number_of_spaces
		} else {
			set Editor::number_of_spaces 8
		}
		if {$tab_width != {}} {
			set Editor::tab_width	$tab_width
		} else {
			set Editor::tab_width 8
		}

		set Editor::line_markers	[list				  \
			[list sel			$color_selected_text	] \
			[list tag_current_line		$color_current_line	] \
			[list tag_bookmark		$color_bookmark		] \
			[list tag_breakpoint		$color_breakpoint	] \
			[list tag_simulator_curr	$color_simulator_line	] \
			[list tag_error_line		$color_error_line	] \
			[list tag_trailing_space	$color_trailing_space	] \
			[list tag_breakpoint_INVALID	$color_breakpoint_I	] \
		]

		set Editor::defaultFont 	[font create	\
			-size -$sample_text_size		\
			-family $sample_text_family		\
		]
		set Editor::defaultFont_bold 	[font create	\
			-size -$sample_text_size		\
			-family $sample_text_family		\
			-weight {bold}				\
		]

		## Syntax highlight
		set ::ASMsyntaxHighlight::highlight_tags	$highlight_tags_asm
		set ::CsyntaxHighlight::highlight_tags		$highlight_tags_C
		set ::LSTsyntaxHighlight::highlight_tags	$highlight_tags_lst
	}

	## Adjust all editors to fit new settings
	 # @return Bool - result
	proc apply_settings {} {
		variable autocompletion_turned_on

		# Check if there is at least 1 opened editor
		if {[llength ${::X::openedProjects}] == 0} {
			return 0
		}

		# Iterate over projects
		foreach project ${::X::openedProjects} {

			# Refresh font settings in right panel
			$project rightPanel_refresh_font_settings 1
			$project rightPanel_clear_symbol_list

			# Adjust tab bar
			$project show_hide_tab_bar

			# Refresh font settings in all editors
			foreach editor [$project cget -editors] {
				$editor change_colors
				$editor refresh_font_settings
				$editor define_line_markers
				if {$autocompletion_turned_on} {
					$editor autocompletion_turned_on
				}
				ASMsyntaxHighlight::create_tags	\
					[$editor cget -editor]	\
					${::Editor::fontSize}	\
					${::Editor::fontFamily}
				CsyntaxHighlight::create_tags	\
					[$editor cget -editor]	\
					${::Editor::fontSize}	\
					${::Editor::fontFamily}
				LSTsyntaxHighlight::create_tags	\
					[$editor cget -editor]	\
					${::Editor::fontSize}	\
					${::Editor::fontFamily}
			}

			$project rightPanel_refresh_symbols
		}

		# done ...
		return 1
	}

	## Set status changed to True
	 # @return true
	proc settings_changed {} {
		variable apply_button		;# ID of button "Apply"
		variable changed		;# Bool: Settings changed
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)

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
		variable win			;# ID of dialog toplevel window
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable dialog_opened		;# Bool: True if this dialog is already opened

		# Apply new settings
		if {$anything_modified} {
			use_settings	;# Adjust NS variables
			apply_settings	;# Adjust GUI
			save_config	;# Save new config
		}

		# Get rid of dialog window
		grab release $win
		set dialog_opened 0
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

		${::X::actualProject} rightPanel_clear_symbol_list

		# Adjust NS variables
		use_settings

		## Apply settings in current editor
		set actualEditor	[${::X::actualProject} cget -actualEditor]
		set actualEditor2	[${::X::actualProject} cget -actualEditor2]
		${::X::actualProject} show_hide_tab_bar
		${::X::actualProject} rightPanel_refresh_font_settings 0
		${::X::actualProject} editor_procedure $actualEditor change_colors		{}
		${::X::actualProject} editor_procedure $actualEditor refresh_font_settings	{}
		${::X::actualProject} editor_procedure $actualEditor define_line_markers	{}
		if {$actualEditor2 >= 0} {
			${::X::actualProject} editor_procedure $actualEditor2 change_colors		{}
			${::X::actualProject} editor_procedure $actualEditor2 refresh_font_settings	{}
			${::X::actualProject} editor_procedure $actualEditor2 define_line_markers	{}
		}
		set editors [${::X::actualProject} cget -editors]
		ASMsyntaxHighlight::create_tags [[lindex $editors $actualEditor] cget -editor]	\
			${::Editor::fontSize} ${::Editor::fontFamily}
		CsyntaxHighlight::create_tags [[lindex $editors $actualEditor] cget -editor]	\
			${::Editor::fontSize} ${::Editor::fontFamily}
		LSTsyntaxHighlight::create_tags [[lindex $editors $actualEditor] cget -editor]	\
			${::Editor::fontSize} ${::Editor::fontFamily}
		if {$actualEditor2 >= 0} {
			ASMsyntaxHighlight::create_tags [[lindex $editors $actualEditor2] cget -editor]	\
				${::Editor::fontSize} ${::Editor::fontFamily}
			CsyntaxHighlight::create_tags [[lindex $editors $actualEditor2] cget -editor]	\
				${::Editor::fontSize} ${::Editor::fontFamily}
			LSTsyntaxHighlight::create_tags [[lindex $editors $actualEditor2] cget -editor]	\
				${::Editor::fontSize} ${::Editor::fontFamily}
		}
		${::X::actualProject} rightPanel_refresh_symbols

		# done ...
		return 1
	}

	## Save configuration to config file
	 # @return void
	proc save_config {} {
		variable editor_to_use	;# Int: Prefred editor

		# Section "Syntax highlight"
		foreach item [concat				\
			${::ASMsyntaxHighlight::highlight_tags}	\
			${::CsyntaxHighlight::highlight_tags}	\
			${::LSTsyntaxHighlight::highlight_tags}	\
		] {
			set key [lindex $item 0]
			set value [lrange $item 1 end]
			::settings setValue "Syntax highlight/$key" $value
		}

		# Section "Editor colors"
		foreach key {
				normal_text_bg	iconBorder_bg	lineNumbers_bg	lineNumbers_fg
				fontSize	fontFamily	line_markers
			} {
				::settings setValue "Editor colors/$key" [subst -nocommands "\$::Editor::$key"]
		}

		# Section "Editor config"
		foreach key {
				intentation_mode	spaces_no_tabs
				number_of_spaces	auto_brackets
				auto_completion		autosave
				cline_completion	hg_trailing_sp
				tab_width
			} {
				::settings setValue "Editor config/$key" [subst -nocommands "\$::Editor::$key"]
		}
		::settings setValue "Editor config/default_encoding"	${::FileList::default_encoding}
		::settings setValue "Editor config/default_eol"		${::FileList::default_eol}
		::settings setValue "Editor config/editor_to_use"	$editor_to_use

		# Commit
		::settings saveConfig
	}

	## Load configuration from config file
	 # @return void
	proc load_config {} {
		variable available_encodings	;# Encodings supported by editor

		## Section "Syntax highlight"
		 # Assembler
		set highlight_tags {}
		foreach item ${::ASMsyntaxHighlight::highlight_tags} {
			set key [lindex $item 0]
			set value [lrange $item 1 end]
			set value [::settings getValue "Syntax highlight/$key" $value]
			lappend highlight_tags [concat $key $value]
		}
		set ::ASMsyntaxHighlight::highlight_tags $highlight_tags
		 # C language
		set highlight_tags {}
		foreach item ${::CsyntaxHighlight::highlight_tags} {
			set key [lindex $item 0]
			set value [lrange $item 1 end]
			set value [::settings getValue "Syntax highlight/$key" $value]
			lappend highlight_tags [concat $key $value]
		}
		set ::CsyntaxHighlight::highlight_tags $highlight_tags
		unset highlight_tags
		 # Code listing
		set highlight_tags {}
		foreach item ${::LSTsyntaxHighlight::highlight_tags} {
			set key [lindex $item 0]
			set value [lrange $item 1 end]
			set value [::settings getValue "Syntax highlight/$key" $value]
			lappend highlight_tags [concat $key $value]
		}
		set ::LSTsyntaxHighlight::highlight_tags $highlight_tags
		unset highlight_tags

		# Section "Editor config"
		foreach key {
				intentation_mode	spaces_no_tabs
				number_of_spaces	auto_brackets
				auto_completion		autosave
				cline_completion	editor_to_use
				hg_trailing_sp		tab_width
			} {
				set value [subst -nocommands "\$::Editor::$key"]
				set value [::settings getValue "Editor config/$key" $value]
				set ::Editor::$key $value
		}
		if {
			![string is integer ${::Editor::editor_to_use}]
				||
			${::Editor::editor_to_use} < 0
				||
			${::Editor::editor_to_use} > 5
		} then {
			set ::Editor::editor_to_use 0
			puts stderr [mc "Invalid key: '%s'" {editor_to_use}]
		} elseif {${::Editor::editor_to_use}} {
			if {!${::PROGRAM_AVAILABLE(urxvt)}} {
				puts stderr [mc "Unable to use external embedded editor because rxvt-unicode is not available"]
				set ::Editor::editor_to_use 0
			} else {
				switch -- ${::Editor::editor_to_use} {
					1 {set program {vim}	}
					2 {set program {emacs}	}
					3 {set program {nano}	}
					4 {set program {dav}	}
					5 {set program {le}	}
				}
				if {!$::PROGRAM_AVAILABLE($program)} {
					puts stderr [mc "Program %s is not available. Using native editor." $program]
					set ::Editor::editor_to_use 0
				}
			}
		}
		if {![string is boolean -strict ${::Editor::spaces_no_tabs}]} {
			set FileList::spaces_no_tabs 0
			puts stderr [mc "Invalid key: '%s'" {spaces_no_tabs}]
		}
		if {![string is boolean -strict ${::Editor::auto_brackets}]} {
			set FileList::auto_brackets 1
			puts stderr [mc "Invalid key: '%s'" {auto_brackets}]
		}
		if {![string is boolean -strict ${::Editor::hg_trailing_sp}]} {
			set FileList::hg_trailing_sp 1
			puts stderr [mc "Invalid key: '%s'" {hg_trailing_sp}]
		}
		if {![string is digit -strict ${::Editor::autosave}]} {
			set Editor::autosave 0
			puts stderr [mc "Invalid key: '%s'" {autosave}]
		} else {
			if {${::Editor::autosave} > 60 || ${::Editor::autosave} < 0} {
				set Editor::autosave 0
				puts stderr [mc "Invalid key: '%s'" {autosave}]
			}
		}
		if {![string is digit -strict ${::Editor::tab_width}]} {
			set Editor::tab_width 8
			puts stderr [mc "Invalid key: '%s'" {tab_width}]
		} else {
			if {${::Editor::tab_width} > 40 || ${::Editor::tab_width} < 1} {
				set Editor::tab_width 8
				puts stderr [mc "Invalid key: '%s'" {tab_width}]
			}
		}
		if {![string is digit -strict ${::Editor::number_of_spaces}]} {
			set FileList::number_of_spaces 8
			puts stderr [mc "Invalid key: '%s'" {number_of_spaces}]
		} else {
			if {${::Editor::number_of_spaces} > 16 || ${::Editor::number_of_spaces} < 1} {
				set FileList::number_of_spaces 8
				puts stderr [mc "Invalid key: '%s'" {number_of_spaces}]
			}
		}
		if {![string is boolean -strict ${::Editor::auto_completion}]} {
			set FileList::auto_completion 1
			puts stderr [mc "Invalid key: '%s'" {auto_completion}]
		}
		if {![string is boolean -strict ${::Editor::cline_completion}]} {
			set FileList::cline_completion 1
			puts stderr [mc "Invalid key: '%s'" {cline_completion}]
		}
		if {
			${::Editor::intentation_mode} != {none}
				&&
			${::Editor::intentation_mode} != {normal}
		} then {
			set FileList::intentation_mode {normal}
			puts stderr [mc "Invalid key: '%s'" {intentation_mode}]
		}

		set FileList::default_encoding	[::settings getValue	\
			"Editor config/default_encoding" {utf-8}]
		if {[lsearch $available_encodings ${FileList::default_encoding}] == -1} {
			set FileList::default_encoding {utf-8}
			puts stderr [mc "Invalid key: '%s'" {default_encoding}]
		}

		set FileList::default_eol	[::settings getValue "Editor config/default_eol" {lf}]
		if {
			${FileList::default_eol} != {lf} &&
			${FileList::default_eol} != {cr} &&
			${FileList::default_eol} != {crlf}
		} then {
			set FileList::default_eol {lf}
			puts stderr [mc "Invalid key: '%s'" {default_eol}]
		}

		# Section "Editor colors" and "Fonts"
		foreach key {
				normal_text_bg	iconBorder_bg	lineNumbers_bg	lineNumbers_fg
				fontSize	fontFamily	line_markers
			} {
				set value [subst -nocommands "\$::Editor::$key"]
				set value [::settings getValue "Editor colors/$key" $value]

				set valid 1

				# Validate line_markers
				if {$key == {line_markers}} {
					foreach def ${::Editor::line_markers} new $value {
						if {![string equal [lindex $def 0] [lindex $new 0]]} {
							puts stderr [mc "-- Invalid key: '%s'" [lindex $new 0]]
							set valid 0
							break
						}
					}
				}

				if {$valid} {
					set ::Editor::$key $value
				}
		}

		# Set editor default font
		set ::Editor::defaultFont	[font create	\
			-size -${::Editor::fontSize}		\
			-family ${::Editor::fontFamily}		\
		]
		set ::Editor::defaultFont_bold 	[font create	\
			-size -${::Editor::fontSize}		\
			-family ${::Editor::fontFamily}		\
			-weight {bold}				\
		]
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

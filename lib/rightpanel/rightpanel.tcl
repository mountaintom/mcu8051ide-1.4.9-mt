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
if { ! [ info exists _RIGHTPANEL_TCL ] } {
set _RIGHTPANEL_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements Right Panel
# Right Panel Notebook consist of:
#	- List of bookmarks
#	- List of breakpoints
#	- List of register watches
#	- Instruction details
#	- List of active subprograms
# --------------------------------------------------------------------------

# Import nesesary sources
source "${::LIB_DIRNAME}/rightpanel/regwatches.tcl"		;# Register watches
source "${::LIB_DIRNAME}/rightpanel/instructiondetails.tcl"	;# Instruction details
source "${::LIB_DIRNAME}/rightpanel/subprograms.tcl"		;# List of active subprograms
source "${::LIB_DIRNAME}/rightpanel/hwmanager.tcl"		;# Hardware tools manager

class RightPanel {
	inherit RegWatches InstructionDetails SubPrograms HwManager

	## COMMON
	 # Background color for selected rows -- light
	public common selection_color		{#EEFFDD}
	 # Background color for selected rows -- dark
	public common selection_color_dark	{#DDDDFF}
	 # Default font size for text widgets
	public common fontSize		${Editor::fontSize}
	 # Default font family for text widgets
	public common fontFamily	${Editor::fontFamily}
	 # Font used in Editor
	public common editor_font	[font create -size -$fontSize -family $fontFamily]
	 # Definition of popup menu for bookmark list
	public common BOOKMARKMENU {
		{command	{Remove}	{$edit:bookmark}	0	"editor_procedure {} Bookmark {}"
			{button_cancel}	"Add/Remove editor bookmark to/from current line"}
		{separator}
		{command	{Previous}	{}	0	"rightPanel_bm_up"	{1uparrow}
			"Go to previous bookmark"}
		{command	{Next}		{}	0	"rightPanel_bm_up"	{1downarrow}
			"Go to next bookmark"}
		{separator}
		{command	{Remove all}	{}	0	"editor_procedure {} clear_all_bookmarks {}"
			{editdelete}	"Remove all bookmarks from the editor"}
	}
	 # Definition of popup menu for breakpoint list
	public common BREAKPOINTMENU {
		{command	{Remove}	{$edit:breakpoint}	0	"editor_procedure {} Breakpoint {}"
			{button_cancel}	"Add/Remove editor breakpoint to/from current line"}
		{separator}
		{command	{Previous}	{}	0	"rightPanel_bp_up"	{1uparrow}
			"Go to previous breakpoint"}
		{command	{Next}		{}	0	"rightPanel_bp_up"	{1downarrow}
			"Go to next breakpoint"}
		{separator}
		{command	{Remove all}	{}	0	"editor_procedure {} clear_all_breakpoints {}"
			{editdelete}	"Remove all breakpoints from the editor"}
	}
	 # Definition of popup menu for symbols list
	public common SYMBOLSKMENU {}

	## PRIVATE
	private variable notebook_frame		;# ID of panel main frame
	private variable notebook		;# ID of panel NoteBook
	private variable bookmarks		;# ID of tab "Bookmarks"
	private variable breakpoints		;# ID of tab "Breakpoints"
	private variable watches		;# ID of tab "Register watches"
	private variable instruction		;# ID of tab "Instruction details"
	private variable subprograms		;# ID of tab "Active subprograms"
	private variable hwmanager		;# ID of tab "Hardware manager"
	private variable table_of_symbols	;# ID of tab "Table of symbols"
	private variable obj_idx		;# Number of this object

	private variable bookmarks_menu   {}	;# ID of popup menu for "Bookmarks"
	private variable breakpoints_menu {}	;# ID of popup menu for "Breakpoints"
	private variable symbols_menu		;# ID of popup menu for "Symbol list"

	private variable bm_pagesManager	;# ID of pages manager for tab "Bookmarks"
	private variable bp_pagesManager	;# ID of pages manager for tab "Breakpoints"
	private variable sm_pagesManager	;# ID of pages manager for tab "Symbol list"

	private variable bookmarks_lineNumbers	;# ID of text widget showing line numbers - tab "Bookmarks"
	private variable breakpoints_lineNumbers ;# ID of text widget showing line numbers - tab "Breakpoints"
	private variable bookmarks_text		;# ID of list of bookmarks (text widget) - tab "Bookmarks"
	private variable breakpoints_text	;# ID of list of breakpoints (text widget) - tab "Breakpoints"
	private variable bm_up_button		;# ID of button "Up"		- tab "Bookmarks"
	private variable bm_down_button		;# ID of button "Down"		- tab "Bookmarks"
	private variable bm_clear_button	;# ID of button "Clear all"	- tab "Bookmarks"
	private variable bp_up_button		;# ID of button "Up"		- tab "Breakpoints"
	private variable bp_down_button		;# ID of button "Down"		- tab "Breakpoints"
	private variable bp_clear_button	;# ID of button "Clear all"	- tab "Breakpoints"
	private variable sm_text		;# ID of symbol list text widget - tab "Symbols"
	private variable sm_lineNumbers		;# ID of text widget showing line numbers - tab "Symbols"

	private variable LIST_bookmarks_lineNumbers	{} ;# List of $bookmarks_lineNumbers (for each editor)
	private variable LIST_breakpoints_lineNumbers	{} ;# List of $breakpoints_lineNumbers (for each editor)
	private variable LIST_bookmarks_text		{} ;# List of $bookmarks_text (for each editor)
	private variable LIST_breakpoints_text		{} ;# List of $breakpoints_text (for each editor)
	private variable LIST_bm_up_button		{} ;# List of $bm_up_button (for each editor)
	private variable LIST_bm_down_button		{} ;# List of $bm_down_button (for each editor)
	private variable LIST_bm_clear_button		{} ;# List of $bm_clear_button (for each editor)
	private variable LIST_bp_up_button		{} ;# List of $bp_up_button (for each editor)
	private variable LIST_bp_down_button		{} ;# List of $bp_down_button (for each editor)
	private variable LIST_bp_clear_button		{} ;# List of $bp_clear_button (for each editor)
	private variable LIST_sm_text			{} ;# List of $sm_text (for each editor)
	private variable LIST_sm_lineNumbers		{} ;# List of $sm_lineNumbers (for each editor)

	private variable bm_bp_pages_list	{}	;# List of editor numbers present in the panel
	private variable editors_count		0	;# Counter of added editors
	private variable current_editor_idx	0	;# Int: Index of currently active editor

	private variable block_select		0	;# Bool: Block selection of an item for certain procedures
	private variable search_val_in_progress	0	;# Bool: Search procedure is in progress

	private variable button_bar			;# ID of button bar which replaces notebook on hide
	private variable redraw_pane_in_progress 0	;# (see procedure right_panel_redraw_pane)
	private variable parentPane			;# ID of parent container (some frame)
	private variable last_PanelSize			;# Last panel widgth
	private variable PanelSize	$::CONFIG(RIGHT_PANEL_SIZE)		;# Current panel width
	private variable active_page	$::CONFIG(RIGHT_PANEL_ACTIVE_PAGE)	;# ID of the active page
	private variable PanelVisible	$::CONFIG(RIGHT_PANEL)			;# Bool: is panel visible

	private variable enabled	0	;# Bool: enable procedures which are needless while loading project

	## Object constructor
	constructor {} {
	}

	## Object destructor
	destructor {
		# Clean up GUI
		destroy $notebook_frame

		# Remove status bar tips for popup menus
		menu_Sbar_remove $bookmarks_menu
		menu_Sbar_remove $breakpoints_menu
	}

	## Create right panel
	 # @parm Widget notebookframe	- frame where to pack NoteBook
	 # @parm Widget ParentPane	- parent paned window
	 # @parm String watches_file	- definition file for register watches
	 # @return void
	public method initialize_rightPanel {notebookframe ParentPane watches_file} {

		# Object variables
		set parentPane $ParentPane	;# Parent container (some frame)
		 # Main frame of this panel
		set notebook_frame $notebookframe

		## Create NoteBook
		set notebook [ModernNoteBook $notebook_frame.ntb_rightPanel]

		# Register notebook status bar tips
		notebook_Sbar_set {rightpanel} [list \
			Bookmarks	[mc "List of bookmarks in the current editor"] \
			Breakpoints	[mc "List of breakpoints in the current editor"] \
			Instruction	[mc "Details for instruction on the current line"] \
			Watches		[mc "Register watches (for internal data memory, external data memory, expanded data memory and bits)"] \
			Subprograms	[mc "List of active subprograms"] \
			Symbols		[mc "Symbol list"] \
			Hardware	[mc "Hardware manager"] \
			Hide		[mc "Hide the panel"] \
		]
		$notebook bindtabs <Enter> "notebook_Sbar rightpanel"
		$notebook bindtabs <Leave> "Sbar {} ;#"

		#
		# Create  tabs
		#

		if {!${::Editor::editor_to_use}} {
			# Tab "Bookmarks"
			set bookmarks [$notebook insert end {Bookmarks}				\
				-image ::ICONS::16::bookmark_toolbar				\
				-raisecmd [list $this rightPanel_set_active_page Bookmarks]	\
				-helptext [mc "List of bookmarks in editor (Ctrl+6)"]		\
			]
			# Tab "Breakpoints"
			set breakpoints [$notebook insert end {Breakpoints}			\
				-image ::ICONS::16::flag					\
				-raisecmd [list $this rightPanel_set_active_page Breakpoints]	\
				-helptext [mc "List of breakpoints in editor (Ctrl+7)"]		\
			]
			# Tab "Symbols"
			set table_of_symbols [$notebook insert end {Symbols}			\
				-image ::ICONS::16::_blockdevice				\
				-raisecmd [list $this rightPanel_set_active_page Symbols]	\
				-helptext [mc "Symbol List"]					\
			]
			# Tab "Instruction"
			set instruction [$notebook insert end {Instruction}			\
				-image ::ICONS::16::info					\
				-raisecmd [list $this rightPanel_set_active_page Instruction]	\
				-helptext [mc "Instruction details (Ctrl+8)"]			\
				-createcmd [list $this CreateInstructionDetailsGUI]		\
			]
		}
		 # Tab "Watches"
		set watches [$notebook insert end {Watches}				\
			-image ::ICONS::16::player_playlist				\
			-raisecmd [list $this rightPanel_set_active_page Watches]	\
			-helptext [mc "Register watches (Ctrl+9)"]			\
			-createcmd [list $this CreateRegWatchesGUI]			\
		]
		 # Tab "Subprograms"
		set subprograms [$notebook insert end {Subprograms}			\
			-image ::ICONS::16::queue					\
			-raisecmd [list $this rightPanel_set_active_page Subprograms]	\
			-helptext [mc "Active subprograms (Ctrl+0)"]			\
			-createcmd [list $this CreateSubProgramsGUI]			\
		]
		 # Tab "Hardware manager"
		set hwmanager [$notebook insert end {Hardware}				\
			-image ::ICONS::16::kcmpci					\
			-raisecmd [list $this rightPanel_set_active_page Hardware]	\
			-helptext [mc "Hardware manager"]				\
			-createcmd [list $this CreateHwManagerGUI]			\
		]

		 # Tab "Hide"
		$notebook insert end {Hide}				\
			-image ::ICONS::16::2rightarrow			\
			-raisecmd [list $this right_panel_show_hide]	\
			-helptext [mc "Hide the panel"]

		# Prepare panel componenets but do not create GUI elements
		PrepareRegWatches $watches $watches_file
		PrepareSubPrograms $subprograms
		PrepareHwManager $hwmanager

		if {!${::Editor::editor_to_use}} {
			PrepareInstructionDetails $instruction
		}

		## Create Button bar
		 # Button "Show"
		set button_bar [frame $notebook_frame.button_bar]
		pack [ttk::button $button_bar.but_show		\
			-image ::ICONS::16::2leftarrow		\
			-style ToolButton.TButton		\
			-command "$this right_panel_show_hide"	\
		]
		DynamicHelp::add $button_bar.but_show -text [mc "Show the panel"]
		setStatusTip -widget $button_bar.but_show -text [mc "Show the panel"]
		 # Separator
		pack [ttk::separator $button_bar.sep -orient horizontal] -fill x -pady 2
		 # Button "Hardware manager"
		pack [ttk::button $button_bar.but_hwman			\
			-image ::ICONS::16::kcmpci			\
			-style ToolButton.TButton			\
			-command "$this rightPanel_show_up Hardware"	\
		]
		DynamicHelp::add $button_bar.but_hwman -text [mc "Hardware tools"]
		setStatusTip -widget $button_bar.but_hwman	\
			-text [mc "Hardware tools manager"]
		 # Button "Active Subprograms"
		pack [ttk::button $button_bar.but_subprog			\
			-image ::ICONS::16::queue				\
			-style ToolButton.TButton				\
			-command "$this rightPanel_show_up Subprograms"		\
		]
		DynamicHelp::add $button_bar.but_subprog -text [mc "Active subprograms (Ctrl+0)"]
		setStatusTip -widget $button_bar.but_subprog	\
			-text [mc "List of active subprograms"]
		 # Button "Register watches"
		pack [ttk::button $button_bar.but_reg_watch		\
			-image ::ICONS::16::player_playlist		\
			-style ToolButton.TButton			\
			-command "$this rightPanel_show_up Watches"	\
		]
		DynamicHelp::add $button_bar.but_reg_watch -text [mc "MCU register watches (Ctrl+9)"]
		setStatusTip -widget $button_bar.but_reg_watch	\
			-text [mc "Register watches for internal data memory, external data memory and expanded data memory"]
		if {!${::Editor::editor_to_use}} {
			# Button "Instruction details"
			pack [ttk::button $button_bar.but_ins_det		\
				-image ::ICONS::16::info			\
				-style ToolButton.TButton			\
				-command "$this rightPanel_show_up Instruction"	\
				-state [expr {${::Editor::editor_to_use} ? {disabled} : {!disabled}}]	\
			]
			DynamicHelp::add $button_bar.but_ins_det -text [mc "Instruction details (Ctrl+8)"]
			setStatusTip -widget $button_bar.but_ins_det	\
				-text [mc "Details for instruction on the current line"]
			# Button "Symbol List"
			pack [ttk::button $button_bar.but_symbols		\
				-image ::ICONS::16::_blockdevice		\
				-style ToolButton.TButton			\
				-command "$this rightPanel_show_up Symbols"	\
				-state [expr {${::Editor::editor_to_use} ? {disabled} : {!disabled}}]	\
			]
			DynamicHelp::add $button_bar.but_symbols -text [mc "Symbol List"]
			setStatusTip -widget $button_bar.but_symbols	\
				-text [mc "Symbol List"]
			# Button "Breakpoints"
			pack [ttk::button $button_bar.but_breakpoints		\
				-image ::ICONS::16::flag			\
				-style ToolButton.TButton			\
				-command "$this rightPanel_show_up Breakpoints"	\
				-state [expr {${::Editor::editor_to_use} ? {disabled} : {!disabled}}]	\
			]
			DynamicHelp::add $button_bar.but_breakpoints -text [mc "List of breakpoints in editor (Ctrl+7)"]
			setStatusTip -widget $button_bar.but_breakpoints	\
				-text [mc "List of breakpoints in the current editor"]
			# Button "Bookmarks"
			pack [ttk::button $button_bar.but_bookmarks		\
				-image ::ICONS::16::bookmark_toolbar		\
				-style ToolButton.TButton			\
				-command "$this rightPanel_show_up Bookmarks"	\
				-state [expr {${::Editor::editor_to_use} ? {disabled} : {!disabled}}]	\
			]
			DynamicHelp::add $button_bar.but_bookmarks -text [mc "List of bookmarks in editor (Ctrl+6)"]
			setStatusTip -widget $button_bar.but_bookmarks	\
				-text [mc "List of bookmarks in the current editor"]
		}

		if {!${::Editor::editor_to_use}} {
			# Pack pages managers
			set bm_pagesManager [PagesManager $bookmarks.pgm_rightPanel_bm -background ${::COMMON_BG_COLOR}]
			pack $bm_pagesManager -expand 1 -fill both
			$bm_pagesManager compute_size

			set bp_pagesManager [PagesManager $breakpoints.pgm_rightPanel_pm -background ${::COMMON_BG_COLOR}]
			pack $bp_pagesManager -expand 1 -fill both
			$bp_pagesManager compute_size

			set sm_pagesManager [PagesManager $table_of_symbols.sm_pagesManager -background ${::COMMON_BG_COLOR}]
			pack $sm_pagesManager -expand 1 -fill both
			$sm_pagesManager compute_size

			# Create popup menus
			set bookmarks_menu	$notebook_frame.menu_rightPanel_bookmarks
			set breakpoints_menu	$notebook_frame.menu_rightPanel_breakpoints
			set symbols_menu	$notebook_frame.menu_rightPanel_symbols
			menuFactory $BREAKPOINTMENU	$breakpoints_menu	0 "$this " 0 {} [namespace current]
			menuFactory $BOOKMARKMENU	$bookmarks_menu		0 "$this " 0 {} [namespace current]
			menuFactory $SYMBOLSKMENU	$symbols_menu		0 "$this " 0 {} [namespace current]
		}


		#
		# Post-initialization
		#

		bind $parentPane <ButtonRelease-1> "$this right_panel_set_size"

		# Show panel GUI components
		if {$PanelVisible} {
			# Show NoteBook
			$parentPane paneconfigure $notebook_frame -minsize 295
			pack [$notebook get_nb] -expand 1 -fill both -padx 5 -pady 5
			$parentPane configure -sashwidth 2

			if {[catch {
				$notebook raise $active_page
				if {
					${::Editor::editor_to_use} &&
					([lsearch {Bookmarks Breakpoints Instruction Symbols} $active_page] != -1)
				} then {
					set active_page {Watches}
					$notebook raise {Watches}
				}
			}]} then {
				set active_page {Watches}
				$notebook raise {Watches}
			}
		} else {
			# Show button bar
			$parentPane paneconfigure $notebook_frame -minsize 0
			pack $button_bar -anchor nw
			$parentPane configure -sashwidth 0
			bind $parentPane <Button> {break}
			set last_PanelSize $PanelSize
			set PanelSize 60
		}
	}

	## Synchronously scroll list of bookmarks and its line numbers
	 # @parm Char	- what (m == Bookmarks; p == Breakpoints; s == Symbols)
	 # @parm String	- string "moveto"
	 # @parm Float	- number between 0.0 and 1.0 (0.0 == 'start', 1.0 == 'end')
	 # @return void
	public method rightPanel_scroll args {
		# Local variables
		set what	[lindex $args 0]	;# m == Bookmarks; p == Breakpoints; s == Symbols
		set cmd		[lindex $args 1]	;# Scroll command (moveto, scroll and such)
		set frac	[lindex $args 2]	;# Fraction where to move
		set units	[lindex $args 3]	;# Units (optonal)

		switch -- $what {
			{m} {	;# Bookmarks
				set lnb $bookmarks_lineNumbers
				set txt $bookmarks_text
			}
			{p} {	;# Breakpoints
				set lnb $breakpoints_lineNumbers
				set txt $breakpoints_text
			}
			{s} {	;# Symbols
				set lnb $sm_lineNumbers
				set txt $sm_text
			}
		}

		if {$units == {}} {
			$lnb yview $cmd $frac
			$txt yview $cmd $frac
		} else {
			$lnb yview $cmd $frac $units
			$txt yview $cmd $frac $units
		}
	}

	## Set position for scrollbar and line numbers in bookmark list
	 # @parm Char what		- (m == Bookmarks; p == Breakpoints; s == Symbols)
	 # @parm Widget scrollbar	- ID of scrollbar widget to adjust
	 # @parm Float fraction0	- y position
	 # @parm Float fraction1	- x position
	 # @return Bool - result
	public method rightPanel_scrollSet {what scrollbar fraction0 fraction1} {
		switch -- $what {
			{m} {	;# Bookmarks
				set txt $bookmarks_text
			}
			{p} {	;# Breakpoints
				set txt $breakpoints_text
			}
			{s} {	;# Symbols
				set txt $sm_text
			}
		}

		if {![winfo exists $txt]} {
			return 0
		}

		catch {
			if {$fraction0 == {0.0} && $fraction1 == {1.0}} {
				if {[winfo ismapped $scrollbar]} {
					pack forget $scrollbar
				}
			} else {
				if {![winfo ismapped $scrollbar]} {
					pack $scrollbar -side right -fill y -after $txt
				}
			}
		}


		$scrollbar set $fraction0 $fraction1
		rightPanel_scroll $what moveto $fraction0

		return 1
	}

	## Refresh font settings for all text widgets in the panel
	 # @parm Bool for_all - 0 == only for the current editor; 1 == for all editors
	 # @return void
	public method rightPanel_refresh_font_settings {for_all} {
		if {${::Editor::editor_to_use}} {return}
		if {$for_all} {
			foreach widget $LIST_bookmarks_lineNumbers {
				$widget configure -font ${Editor::defaultFont_bold}
			}

			foreach widget $LIST_breakpoints_lineNumbers {
				$widget configure -font ${Editor::defaultFont_bold}
			}

			set i 0
			foreach widget $LIST_bookmarks_text {
				$widget configure -font ${Editor::defaultFont_bold}
				ASMsyntaxHighlight::create_tags $widget ${Editor::fontSize} ${Editor::fontFamily}
				set language [$this editor_procedure $i get_language {}]
				if {$language == 1} {
					CsyntaxHighlight::create_tags	\
						$widget ${Editor::fontSize} ${Editor::fontFamily}
				} elseif {$language == 2} {
					LSTsyntaxHighlight::create_tags	\
						$widget ${Editor::fontSize} ${Editor::fontFamily}
				}
				incr i
			}

			set i 0
			foreach widget $LIST_breakpoints_text {
				$widget configure -font ${Editor::defaultFont_bold}
				ASMsyntaxHighlight::create_tags $widget ${Editor::fontSize} ${Editor::fontFamily}
				set language [$this editor_procedure $i get_language {}]
				if {$language == 1} {
					CsyntaxHighlight::create_tags	\
						$widget ${Editor::fontSize} ${Editor::fontFamily}
				} elseif {$language == 2} {
					LSTsyntaxHighlight::create_tags	\
						$widget ${Editor::fontSize} ${Editor::fontFamily}
				}
				incr i
			}
		} else {
			$bookmarks_lineNumbers		configure -font ${Editor::defaultFont_bold}
			$bookmarks_text			configure -font ${Editor::defaultFont_bold}
			$breakpoints_lineNumbers	configure -font ${Editor::defaultFont_bold}
			$breakpoints_text		configure -font ${Editor::defaultFont_bold}
			$sm_lineNumbers			configure -font ${Editor::defaultFont_bold}
			$sm_text			configure -font ${Editor::defaultFont_bold}

			ASMsyntaxHighlight::create_tags $bookmarks_text ${Editor::fontSize} ${Editor::fontFamily}
			ASMsyntaxHighlight::create_tags $breakpoints_text ${Editor::fontSize} ${Editor::fontFamily}
			set language [$this editor_procedure {end} get_language {}]
			if {$language == 1} {
				CsyntaxHighlight::create_tags	\
					$bookmarks_text ${Editor::fontSize} ${Editor::fontFamily}
				CsyntaxHighlight::create_tags	\
					$breakpoints_text ${Editor::fontSize} ${Editor::fontFamily}
			} elseif {$language == 2} {
				CsyntaxHighlight::create_tags	\
					$bookmarks_text ${Editor::fontSize} ${Editor::fontFamily}
				CsyntaxHighlight::create_tags	\
					$breakpoints_text ${Editor::fontSize} ${Editor::fontFamily}
			}

			create_tags_in_symbol_list
		}
	}

	## Create highlight tag for list of bookmarks and breakpoints for the current editor
	 # @return void
	public method rightPanel_add_Editor__create_menu_and_tags {} {
		if {${::Editor::editor_to_use}} {return}
		ASMsyntaxHighlight::create_tags $breakpoints_text $fontSize $fontFamily
		ASMsyntaxHighlight::create_tags $bookmarks_text $fontSize $fontFamily
		set language [$this editor_procedure {end} get_language {}]
		if {$language == 1} {
			rightPanel_bm_bp_create_c_hg_tags
		} elseif {$language == 2} {
			rightPanel_bm_bp_create_lst_hg_tags
		}

		create_tags_in_symbol_list
	}

	## Create highlighting tags in the text widget in the "List of Symbols"
	 # @return void
	private method create_tags_in_symbol_list {} {
		set tags_to_define [list tag_label tag_constant tag_normal tag_macro]
		foreach tag_def [concat ${::ASMsyntaxHighlight::highlight_tags} ${::CsyntaxHighlight::highlight_tags}] {
			if {[lsearch -ascii -exact $tags_to_define [lindex $tag_def 0]] == -1} {
				continue
			}

			# Create array of tag attributes
			for {set i 0} {$i < 5} {incr i} {
				set tag_def_item($i) [lindex $tag_def $i]
			}

			# Foreground color
			if {$tag_def_item(1) == {}} {
				set tag_def_item(1) black
			}
			# Fonr slant
			if {$tag_def_item(3) == 1} {
				set tag_def_item(3) italic
			} else {
				set tag_def_item(3) roman
			}
			# Font weight
			if {$tag_def_item(4) == 1} {
				set tag_def_item(4) bold
			} else {
				set tag_def_item(4) normal
			}

			# Create the tag in the target text widget
			$sm_text tag configure $tag_def_item(0)		\
				-foreground $tag_def_item(1)		\
				-font [font create			\
					-overstrike $tag_def_item(2)	\
					-slant $tag_def_item(3)		\
					-weight $tag_def_item(4)	\
					-size -$::Editor::fontSize	\
					-family $::Editor::fontFamily 	\
				]
		}

		# Create tag for C function
		$sm_text tag configure tag_c_func	\
			-foreground {#0000DD}		\
			-font ${::Editor::defaultFont}
	}

	## Create highlighting tags for Codelisting for the current editor
	 # @return void
	public method rightPanel_bm_bp_create_lst_hg_tags {} {
		LSTsyntaxHighlight::create_tags $breakpoints_text $fontSize $fontFamily
		LSTsyntaxHighlight::create_tags $bookmarks_text $fontSize $fontFamily
	}
	## Create highlighting tags for C language for the current editor
	 # @return void
	public method rightPanel_bm_bp_create_c_hg_tags {} {
		CsyntaxHighlight::create_tags $breakpoints_text $fontSize $fontFamily
		CsyntaxHighlight::create_tags $bookmarks_text $fontSize $fontFamily
	}

	## Add new list of bookmarks and list of breakpoints for new editor
	 # @parm Bool create_menu_and_tags	- Create popup menus and highlighting tags
	 # @return void
	public method rightPanel_add_Editor {create_menu_and_tags} {
		if {${::Editor::editor_to_use}} {return}

		# Local variables
		set bm_page [$bm_pagesManager add $editors_count]	;# ID of current bookmarks page
		set bp_page [$bp_pagesManager add $editors_count]	;# ID of current breakpoints page
		set sm_page [$sm_pagesManager add $editors_count]	;# ID of current page in symbol list

		# Register new editor
		set current_editor_idx $editors_count
		lappend bm_bp_pages_list $editors_count
		incr editors_count	;# increment counter of editors


		#
		# Create tab "Bookmarks"
		#

		## Create icon bar (up, down, bookmark, clear all)
		 # Create button frame
		set button_frame [frame $bm_page.frm_rightPanel_bm_button_frame]
		pack $button_frame -side top -fill x
		# Button "Up"
		set bm_up_button [ttk::button $button_frame.but_rightPanel_bm_up	\
			-image ::ICONS::16::1uparrow					\
			-state disabled							\
			-command "$this rightPanel_bm_up"				\
			-style ToolButton.TButton					\
		]
		pack $bm_up_button -side left
		DynamicHelp::add $bm_up_button -text [mc "Move to previous bookmark"]
		setStatusTip -widget $bm_up_button	\
			-text [mc "Go to to line of previous bookmark"]
		# Button "Down"
		set bm_down_button [ttk::button $button_frame.but_rightPanel_bm_down	\
			-image ::ICONS::16::1downarrow					\
			-state disabled							\
			-command "$this rightPanel_bm_down"				\
			-style ToolButton.TButton					\
		]
		pack $bm_down_button -side left
		DynamicHelp::add $bm_down_button -text [mc "Move to the next bookmark"]
		setStatusTip -widget $bm_down_button	\
			-text [mc "Go to to line of next bookmark"]
		# Separator
		pack [ttk::separator $button_frame.but_rightPanel_bm_sep	\
			-orient vertical					\
		] -side left -fill y -padx 2
		# Button "Bookmark"
		set button [ttk::button $button_frame.but_rightPanel_bm_bookmark	\
			-image ::ICONS::16::bookmark_add				\
			-command "$this editor_procedure {} Bookmark {}"		\
			-style ToolButton.TButton					\
		]
		pack $button -side left
		DynamicHelp::add $button -text [mc "Add/Remove bookmark on the current line"]
		setStatusTip -widget $button	\
			-text [mc "Add/Remove bookmark on the current line in editor"]
		# Button "Clear all"
		set bm_clear_button [ttk::button $button_frame.but_rightPanel_bm_clear	\
			-image ::ICONS::16::editdelete					\
			-state disabled							\
			-command "$this editor_procedure {} clear_all_bookmarks {}"	\
			-style ToolButton.TButton					\
		]
		pack $bm_clear_button -side right
		DynamicHelp::add $bm_clear_button -text [mc "Clear all bookmarks"]
		setStatusTip -widget $bm_clear_button	\
			-text [mc "Clear all bookmarks from editor"]

		# Create text frame (Contains: text widget, scrollbar, LineNumbers)
		set text_frame [frame $bm_page.frm_rightPanel_bm_text_frame -bd 1 -relief sunken]
		pack $text_frame -fill both -expand 1 -side bottom

		# Create scrollbar
		set scrollbar [ttk::scrollbar			\
			$text_frame.scr_rightPanel_bookmars	\
			-orient vertical			\
			-command "$this rightPanel_scroll m"	\
		]
		# Create line numbers
		set bookmarks_lineNumbers [text $text_frame.txt_rightPanel_bm_lineNumbers	\
			-yscrollcommand "$this rightPanel_scrollSet m $scrollbar"	\
			-cursor left_ptr	\
			-width 1 -height 1	\
			-bg gray		\
			-fg white		\
			-relief flat		\
			-bd 1			\
			-state disabled		\
			-exportselection 0	\
			-takefocus 0		\
			-font ${Editor::defaultFont_bold}	\
		]
		$bookmarks_lineNumbers tag configure right -justify right
		# Create list of bookmarks
		set bookmarks_text [text $text_frame.txt_rightPanel_bookmars		\
			-cursor left_ptr -state disabled -width 1 -height 1		\
			-wrap none -exportselection 0 -bd 1 -relief flat		\
			-yscrollcommand "$this rightPanel_scrollSet m $scrollbar"	\
			-font ${Editor::defaultFont_bold}				\
		]
		$bookmarks_text tag configure curLine	\
			-borderwidth 1			\
			-relief raised			\
			-background ${::RightPanel::selection_color}

		# Set bindings
		bind $bookmarks_text <<Selection>> "false_selection $bookmarks_text; break"
		bind $bookmarks_text <Button-1> "$this rightPanel_xx_txt_click m %x %y; break"
		bind $bookmarks_text <ButtonRelease-3> "$this rightPanel_bm_popupmenu %X %Y %x %y; break; break"
		bind $bookmarks_lineNumbers <ButtonRelease-3> "$this rightPanel_bm_popupmenu %X %Y %x %y; break; break"
		bind $bookmarks_text <Key-Menu> {break}
		bind $bookmarks_lineNumbers <<Selection>> "false_selection $bookmarks_lineNumbers; break"

		# Pack components of "Text frame"
		pack $bookmarks_lineNumbers -side left -fill y
		pack $bookmarks_text -side left -expand 1 -fill both


		#
		# Breakpoints tab
		#

		## Create icon bar (up, down, breakpoint, clear all)
		 # Create button frame
		set button_frame [frame $bp_page.frm_rightPanel_bp_button_frame]
		pack $button_frame -side top -fill x
		 # Button "Up"
		set bp_up_button [ttk::button $button_frame.but_rightPanel_bp_up	\
			-image ::ICONS::16::1uparrow					\
			-state disabled							\
			-command "$this rightPanel_bp_up"				\
			-style ToolButton.TButton					\
		]
		pack $bp_up_button -side left
		DynamicHelp::add $bp_up_button -text [mc "Move to previous breakpoint"]
		setStatusTip -widget $bp_up_button	\
			-text [mc "Go to to line of previous breakpoint"]
		 # Button "Down"
		set bp_down_button [ttk::button $button_frame.but_rightPanel_bp_down	\
			-image ::ICONS::16::1downarrow					\
			-state disabled							\
			-command "$this rightPanel_bp_down"				\
			-style ToolButton.TButton					\
		]
		pack $bp_down_button -side left
		DynamicHelp::add $bp_down_button -text [mc "Move to next breakpoint"]
		setStatusTip -widget $bp_down_button	\
			-text [mc "Go to to line of next breakpoint"]
		 # Separator
		pack [ttk::separator $button_frame.but_rightPanel_bp_sep	\
			-orient vertical					\
		] -side left -fill y -padx 2
		 # Button "Breakpoint"
		set button [ttk::button $button_frame.but_rightPanel_bp_breakpoint	\
			-image ::ICONS::16::flag					\
			-command "$this editor_procedure {} Breakpoint {}"		\
			-style ToolButton.TButton					\
		]
		pack $button -side left
		DynamicHelp::add $button -text [mc "Add/Remove breakpoint on the current line"]
		setStatusTip -widget $button	\
			-text [mc "Add/Remove breakpoint on the current line in editor"]
		 # Buttton "Clear all"
		set bp_clear_button [ttk::button $button_frame.but_rightPanel_bp_clear	\
			-image ::ICONS::16::editdelete					\
			-state disabled							\
			-command "$this editor_procedure {} clear_all_breakpoints {}"	\
			-style ToolButton.TButton					\
		]
		pack $bp_clear_button -side right
		DynamicHelp::add $bp_clear_button -text [mc "Clear all breakpoints"]
		setStatusTip -widget $bp_clear_button	\
			-text [mc "Clear all breakpoints from editor"]

		# Create text frame (Contains: text widget, scrollbar, LineNumbers)
		set text_frame [frame $bp_page.frm_rightPanel_bp_text_frame -bd 1 -relief sunken]
		pack $text_frame -fill both -expand 1 -side bottom

		# Create scrollbar
		set scrollbar [ttk::scrollbar			\
			$text_frame.scr_rightPanel_breakpoints	\
			-orient vertical			\
			-command "$this rightPanel_scroll p"	\
		]
		# Create line numbers
		set breakpoints_lineNumbers [text $text_frame.txt_rightPanel_bp_lineNumbers	\
			-yscrollcommand "$this rightPanel_scrollSet p $scrollbar"	\
			-cursor left_ptr	\
			-width 1 -height 1	\
			-exportselection 0	\
			-bg gray		\
			-fg white		\
			-relief flat		\
			-bd 1			\
			-state disabled		\
			-takefocus 0		\
			-font ${Editor::defaultFont_bold}	\
		]
		$breakpoints_lineNumbers tag configure right -justify right
		# Create list of breakpoints
		set breakpoints_text [text $text_frame.txt_rightPanel_breakpoints	\
			-cursor left_ptr -state disabled				\
			-wrap none -exportselection 0 -bd 1 -relief flat		\
			-font ${Editor::defaultFont_bold} -width 1 -height 1		\
			-yscrollcommand "$this rightPanel_scrollSet p $scrollbar"	\
		]
		$breakpoints_text tag configure curLine	\
			-borderwidth 1			\
			-relief raised			\
			-background ${::RightPanel::selection_color}

		# Pack widgets of the text frame
		pack $breakpoints_lineNumbers -side left -fill y
		pack $breakpoints_text -side left -expand 1 -fill both

		# Set bindings
		bind $breakpoints_text <<Selection>> "false_selection $breakpoints_text; break"
		bind $breakpoints_text <Button-1> "$this rightPanel_xx_txt_click p %x %y; break"
		bind $breakpoints_text <ButtonRelease-3> "$this rightPanel_bp_popupmenu %X %Y %x %y; break; break"
		bind $breakpoints_lineNumbers <ButtonRelease-3> "$this rightPanel_bp_popupmenu %X %Y %x %y; break; break"
		bind $breakpoints_text <Key-Menu> {break}
		bind $breakpoints_lineNumbers <<Selection>> "false_selection $breakpoints_lineNumbers; break"


		#
		# Symbol list
		#

		## Create icon bar (up, down, breakpoint, clear all)
		 # Create button frame
		set button_frame [frame $sm_page.button_frame]
		pack $button_frame -side top -fill x
		 # Button "Refresh"
		set refresh_but [ttk::button $button_frame.refresh_but	\
			-image ::ICONS::16::reload			\
			-command "$this rightPanel_refresh_symbols"	\
			-style ToolButton.TButton			\
		]
		pack $refresh_but -side left
		DynamicHelp::add $refresh_but -text [mc "Reevaluate"]
		setStatusTip -widget $refresh_but	\
			-text [mc "Reevaluate ..."]

		# Button "Clear search string"
		set sm_search_clear [ttk::button $button_frame.clear_search	\
			-image ::ICONS::16::clear_left				\
			-style Flat.TButton					\
			-command "$button_frame.search_entry delete 0 end"	\
			-state disabled						\
		]
		DynamicHelp::add $button_frame.clear_search -text [mc "Clear search string"]
		pack $sm_search_clear -side right
		setStatusTip -widget $sm_search_clear	\
			-text [mc "Clear search string"]
		# Entry "Search"
		set sm_search_entry [ttk::entry $button_frame.search_entry				\
			-validate key									\
			-width 0									\
			-validatecommand "$this rightPanel_sm_search_validate %P %W $sm_search_clear"	\
		]
		DynamicHelp::add $sm_search_entry -text [mc "Search for a constant, variable, function or macro"]
		pack $sm_search_entry -side right -fill x -expand 1
		setStatusTip -widget $sm_search_entry	\
			-text [mc "Search for a constant, variable, function or macro"]
		# Label "Search:"
		pack [label $button_frame.search_lbl -text [mc "    Search:"]] -side right

		# Create text frame (Contains: text widget, scrollbar, LineNumbers)
		set text_frame [frame $sm_page.text_frame -bd 1 -relief sunken]
		pack $text_frame -fill both -expand 1 -side bottom

		# Create scrollbar
		set scrollbar [ttk::scrollbar $text_frame.scr	\
			-orient vertical			\
			-command "$this rightPanel_scroll s"	\
		]
		set sm_lineNumbers [text $text_frame.ln			\
			-yscrollcommand "$this rightPanel_scrollSet s $scrollbar"	\
			-cursor left_ptr	-width 1		\
			-exportselection 0	-bg gray		\
			-height 1		-fg white		\
			-relief flat		-bd 1			\
			-state disabled		-takefocus 0		\
			-font ${Editor::defaultFont_bold} 		\
		]
		$sm_lineNumbers tag configure right -justify right
		set sm_text [text $text_frame.txt				\
			-cursor left_ptr -state disabled			\
			-wrap none -exportselection 0 -bd 1 -relief flat	\
			-font ${Editor::defaultFont_bold} -width 1 -height 1	\
			-yscrollcommand "$this rightPanel_scrollSet s $scrollbar"	\
		]
		$sm_text tag configure curLine	\
			-borderwidth 1		\
			-relief raised		\
			-background ${::RightPanel::selection_color}

		# Pack widgets of the text frame
		pack $scrollbar -side right -fill y
		pack $sm_lineNumbers -side left -fill y
		pack $sm_text -side left -expand 1 -fill both

		# Set bindings
		bind $sm_text <<Selection>> "false_selection $sm_text; break"
		bind $sm_text <Button-1> "$this rightPanel_xx_txt_click s %x %y; break"
		bind $sm_text <Key-Menu> {break}
		bind $sm_text <ButtonRelease-3> {break}
		bind $sm_lineNumbers <<Selection>> "false_selection $sm_lineNumbers; break"
		bind $sm_lineNumbers <Key-Menu> {break}
		bind $sm_lineNumbers <ButtonRelease-3> {break}

		## FINISH

		# Append create d widgets to lists
		lappend LIST_bookmarks_lineNumbers	$bookmarks_lineNumbers
		lappend LIST_breakpoints_lineNumbers	$breakpoints_lineNumbers
		lappend LIST_bookmarks_text		$bookmarks_text
		lappend LIST_breakpoints_text		$breakpoints_text
		lappend LIST_bm_up_button		$bm_up_button
		lappend LIST_bm_down_button		$bm_down_button
		lappend LIST_bm_clear_button		$bm_clear_button
		lappend LIST_bp_up_button		$bp_up_button
		lappend LIST_bp_down_button		$bp_down_button
		lappend LIST_bp_clear_button		$bp_clear_button
		lappend LIST_sm_text			$sm_text
		lappend LIST_sm_lineNumbers		$sm_lineNumbers

		if {$create_menu_and_tags} {
			rightPanel_add_Editor__create_menu_and_tags
		}
	}

	## Enable/Disable buttons on Bookmarks+Breakpoints icon bar
	 # @return void
	private method bm_bp_disEna_buttons {} {

		# Bookmarks
		set end [$bookmarks_text index end]
		switch -- $end {
			{2.0} {		;# Empty list
				$bm_up_button		configure -state disabled
				$bm_down_button		configure -state disabled
				$bm_clear_button	configure -state disabled
			}
			{3.0} {		;# One item
				$bm_up_button		configure -state disabled
				$bm_down_button		configure -state disabled
				$bm_clear_button	configure -state normal
			}
			default {	;# More items
				$bm_up_button		configure -state normal
				$bm_down_button		configure -state normal
				$bm_clear_button	configure -state normal
			}
		}

		# Breakpoints
		set end [$breakpoints_text index end]
		switch -- $end {
			{2.0} {		;# Empty list
				$bp_up_button		configure -state disabled
				$bp_down_button		configure -state disabled
				$bp_clear_button	configure -state disabled
			}
			{3.0} {		;# One item
				$bp_up_button		configure -state disabled
				$bp_down_button		configure -state disabled
				$bp_clear_button	configure -state normal
			}
			default {	;# More items
				$bp_up_button		configure -state normal
				$bp_down_button		configure -state normal
				$bp_clear_button	configure -state normal
			}
		}
	}

	## Recreate popup menus
	 # @return void
	public method rightPanel_makePopupMenu {} {
		regwatches_makePopupMenu

		if {[winfo exists $breakpoints_menu]}	{destroy $breakpoints_menu}
		if {[winfo exists $bookmarks_menu]}	{destroy $bookmarks_menu}
		menuFactory $BREAKPOINTMENU	$breakpoints_menu	0 "$this " 0 {} [namespace current]
		menuFactory $BOOKMARKMENU	$bookmarks_menu		0 "$this " 0 {} [namespace current]
	}

	## Invoke bookmarks popup menu
	 # @parm Int X - Absolute X coordinate
	 # @parm Int Y - Absolute Y coordinate
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method rightPanel_bm_popupmenu {X Y x y} {

		# Change position in the list
		rightPanel_xx_txt_click m $x $y

		# Enable/Disable menu items
		set end [$bookmarks_text index end]
		switch -- $end {
			{2.0} {		;# Empty list
				$bookmarks_menu entryconfigure [::mc "Remove"]		-state disabled
				$bookmarks_menu entryconfigure [::mc "Next"]		-state disabled
				$bookmarks_menu entryconfigure [::mc "Previous"]	-state disabled
				$bookmarks_menu entryconfigure [::mc "Remove all"]	-state disabled
			}
			{3.0} {		;# One item
				$bookmarks_menu entryconfigure [::mc "Remove"]		-state normal
				$bookmarks_menu entryconfigure [::mc "Next"]		-state disabled
				$bookmarks_menu entryconfigure [::mc "Previous"]	-state disabled
				$bookmarks_menu entryconfigure [::mc "Remove all"]	-state normal
			}
			default {	;# More items
				$bookmarks_menu entryconfigure [::mc "Remove"]		-state normal
				$bookmarks_menu entryconfigure [::mc "Next"]		-state normal
				$bookmarks_menu entryconfigure [::mc "Previous"]	-state normal
				$bookmarks_menu entryconfigure [::mc "Remove all"]	-state normal
			}
		}

		# Invoke the menu
		tk_popup $bookmarks_menu $X $Y
	}

	## Invoke breakpoints popup menu
	 # @parm Int X - Absolute X coordinate
	 # @parm Int Y - Absolute Y coordinate
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method rightPanel_bp_popupmenu {X Y x y} {

		# Change position in the list
		rightPanel_xx_txt_click p $x $y

		# Enable/Disable menu items
		set end [$breakpoints_text index end]
		switch -- $end {
			{2.0} {		;# Empty list
				$breakpoints_menu entryconfigure [::mc "Remove"]	-state disabled
				$breakpoints_menu entryconfigure [::mc "Next"]		-state disabled
				$breakpoints_menu entryconfigure [::mc "Previous"]	-state disabled
				$breakpoints_menu entryconfigure [::mc "Remove all"]	-state disabled
			}
			{3.0} {		;# One item
				$breakpoints_menu entryconfigure [::mc "Remove"]	-state normal
				$breakpoints_menu entryconfigure [::mc "Next"]		-state disabled
				$breakpoints_menu entryconfigure [::mc "Previous"]	-state disabled
				$breakpoints_menu entryconfigure [::mc "Remove all"]	-state normal
			} default {	;# More items
				$breakpoints_menu entryconfigure [::mc "Remove"]	-state normal
				$breakpoints_menu entryconfigure [::mc "Next"]		-state normal
				$breakpoints_menu entryconfigure [::mc "Previous"]	-state normal
				$breakpoints_menu entryconfigure [::mc "Remove all"]	-state normal
			}
		}

		# Invoke the menu
		tk_popup $breakpoints_menu $X $Y
	}

	## Remove editor from the list
	 # @parm Int idx - editor index
	 # @return void
	public method rightPanel_remove_Editor {idx} {
		if {${::Editor::editor_to_use}} {return}

		# Remove pages from pages managers
		$bm_pagesManager delete [lindex $bm_bp_pages_list $idx]
		$bp_pagesManager delete [lindex $bm_bp_pages_list $idx]
		$sm_pagesManager delete [lindex $bm_bp_pages_list $idx]
		set bm_bp_pages_list [lreplace $bm_bp_pages_list $idx $idx]

		# Remove widget references from its lists
		set LIST_bookmarks_lineNumbers		[lreplace $LIST_bookmarks_lineNumbers	$idx $idx]
		set LIST_breakpoints_lineNumbers	[lreplace $LIST_breakpoints_lineNumbers	$idx $idx]
		set LIST_bookmarks_text			[lreplace $LIST_bookmarks_text		$idx $idx]
		set LIST_breakpoints_text		[lreplace $LIST_breakpoints_text	$idx $idx]
		set LIST_bm_up_button			[lreplace $LIST_bm_up_button		$idx $idx]
		set LIST_bm_down_button			[lreplace $LIST_bm_down_button		$idx $idx]
		set LIST_bm_clear_button		[lreplace $LIST_bm_clear_button		$idx $idx]
		set LIST_bp_up_button			[lreplace $LIST_bp_up_button		$idx $idx]
		set LIST_bp_down_button			[lreplace $LIST_bp_down_button		$idx $idx]
		set LIST_bp_clear_button		[lreplace $LIST_bp_clear_button		$idx $idx]
		set LIST_sm_text			[lreplace $LIST_sm_text			$idx $idx]
		set LIST_sm_lineNumbers			[lreplace $LIST_sm_lineNumbers		$idx $idx]
	}

	## Change the current editor
	 # @parm Int idx - editor index
	 # @return void
	public method rightPanel_switch_editor {idx} {
		if {${::Editor::editor_to_use}} {return}

		set current_editor_idx $idx
		rightPanel_switch_page $idx
		rightPanel_switch_editor_vars $idx
	}

	## Change the current page in pages managers
	 # @parm Int idx - editor index
	 # @return void
	public method rightPanel_switch_page {idx} {
		if {${::Editor::editor_to_use}} {return}

		set current_editor_idx $idx
		$bm_pagesManager raise [lindex $bm_bp_pages_list $idx]
		$bp_pagesManager raise [lindex $bm_bp_pages_list $idx]
		$sm_pagesManager raise [lindex $bm_bp_pages_list $idx]

		if {$active_page == {Symbols}} {
			catch {$this editor_procedure {} comp_win_highlight_all_in_background {}}
		}
	}

	## Change current editor but don not affect GUI
	 # @parm Int idx - editor index
	 # @return void
	public method rightPanel_switch_editor_vars {idx} {
		if {${::Editor::editor_to_use}} {return}

		# Set active widgets
		set current_editor_idx		$idx
		set bookmarks_lineNumbers	[lindex $LIST_bookmarks_lineNumbers	$idx]
		set breakpoints_lineNumbers	[lindex $LIST_breakpoints_lineNumbers	$idx]
		set bookmarks_text		[lindex $LIST_bookmarks_text		$idx]
		set breakpoints_text		[lindex $LIST_breakpoints_text		$idx]
		set bm_up_button		[lindex $LIST_bm_up_button		$idx]
		set bm_down_button		[lindex $LIST_bm_down_button		$idx]
		set bm_clear_button		[lindex $LIST_bm_clear_button		$idx]
		set bp_up_button		[lindex $LIST_bp_up_button		$idx]
		set bp_down_button		[lindex $LIST_bp_down_button		$idx]
		set bp_clear_button		[lindex $LIST_bp_clear_button		$idx]
		set sm_text			[lindex $LIST_sm_text			$idx]
		set sm_lineNumbers		[lindex $LIST_sm_lineNumbers		$idx]
	}


	## Binding for event <Button-1> for list of ...
	 # Change selection in the widget and change current line in the editor
	 # @parm Char	- what (m == Bookmarks; p == Breakpoints; s == Symbols)
	 # @parm Int x - relative X coordinate
	 # @parm Int y - relative Y coordinate
	 # @return Bool - result
	public method rightPanel_xx_txt_click {what x y} {
		if {$block_select} {return}

		switch -- $what {
			{m} {	;# Bookmarks
				set lnb $bookmarks_lineNumbers
				set txt $bookmarks_text
			}
			{p} {	;# Breakpoints
				set lnb $breakpoints_lineNumbers
				set txt $breakpoints_text
			}
			{s} {	;# Symbols
				set lnb $sm_lineNumbers
				set txt $sm_text
			}
		}

		# Determinate line number
		set lineNum [rightPanel_txt_click $txt $lnb $x $y]
		if {$lineNum == {}} {return 0}

		# Change current line in the editor
		set block_select 1
		$this editor_procedure {} goto $lineNum
		update idletasks
		set block_select 0

		return 1
	}

	## Determinate line number and select the line
	 # @parm Widget txt_widget	- ID of the text widget
	 # @parm Widget ln_widget	- ID of line numbers widget
	 # @parm Int x			- relative X coordinate
	 # @parm Int y			- relative X coordinate
	 # @return Int - line number (from line numbers panel)
	private method rightPanel_txt_click {txt_widget ln_widget x y} {
		set idx [$txt_widget index @$x,$y]

		# Determinate traslated line number
		set lineNum [$ln_widget get [list $idx linestart] [list $idx lineend]]

		# Select the line
		if {$lineNum != {}} {
			$txt_widget tag remove curLine 1.0 end
			$txt_widget tag add curLine [list $idx linestart] [list $idx+1l linestart]
		}

		# Retrun result
		return $lineNum
	}

	## If the given line contain symbol declaration then select it in the list
	 # This function should be called after change on the line in the editor
	 # @parm Int lineNum - line number
	 # @return Bool - result
	public method rightPanel_sm_select {lineNum} {
		if {!$enabled || $block_select} {return}
		if {![info exists sm_text]} {return}

		# Unset selection in the list
		$sm_text tag remove curLine 1.0 end

		# Check for bookmark presence
		set idx0 [lsearch -ascii -exact [$sm_lineNumbers get 1.0 end] $lineNum]
		if {$idx0 == -1} {return 0}

		# Select the line
		incr idx0
		set idx1 $idx0
		incr idx1
		$sm_text tag add curLine $idx0.0 $idx1.0
		$sm_text see $idx0.0
		return 1
	}

	## If the given line contain bookmark then select it in the list
	 # This function should be called after change on the line in the editor
	 # @parm Int lineNum - line number
	 # @return Bool - result
	public method rightPanel_bm_select {lineNum} {
		if {!$enabled || $block_select} {return}
		if {![info exists bookmarks_text]} {return}

		# Check for bookmark presence
		set idx0 [lsearch -ascii -exact [$bookmarks_lineNumbers get 1.0 end] $lineNum]
		if {$idx0 == -1} {return 0}

		# Select the line
		incr idx0
		set idx1 $idx0
		incr idx1
		$bookmarks_text tag remove curLine 1.0 end
		$bookmarks_text tag add curLine $idx0.0 $idx1.0
		$bookmarks_text see $idx0.0
		return 1
	}

	## If the given line contain bookmark then select it in the list
	 # This function should be called after change on the line in the editor
	 # @parm Int lineNum - line number
	 # @return Bool - result
	public method rightPanel_bp_select {lineNum} {
		if {!$enabled || $block_select} {return}
		if {![info exists breakpoints_text]} {return}

		# Check for bookmark presence
		set idx0 [lsearch -ascii -exact [$breakpoints_lineNumbers get 1.0 end] $lineNum]
		if {$idx0 == -1} {return 0}

		# Select the line
		incr idx0
		set idx1 $idx0
		incr idx1
		$breakpoints_text tag remove curLine 1.0 end
		$breakpoints_text tag add curLine $idx0.0 $idx1.0
		$breakpoints_text see $idx0.0
		return 1
	}

	## Unset selection in list of bookmarks
	 # @return void
	public method rightPanel_bm_unselect {} {
		if {!$enabled || $block_select} {return}
		if {![info exists bookmarks_text]} {return}
		$bookmarks_text tag remove curLine 1.0 end
	}

	## Unset selection in list of breakpoints
	 # @return void
	public method rightPanel_bp_unselect {} {
		if {!$enabled || $block_select} {return}
		if {![info exists breakpoints_text]} {return}
		$breakpoints_text tag remove curLine 1.0 end
	}

	## Copy line from the editor to target widget and preserve highlight
	 # @parm Widget target_widget	- target widget, where to copy the line
	 # @parm TextIndex idx		- target text index
	 # @parm Int lineNum		- source line number
	 # @parm Int editor_idx		- editor index
	 # @return void
	private method insert_text {target_widget idx lineNum editor_idx} {

		# Copy text
		set line [$this editor_procedure $editor_idx getLineContent $lineNum]
		regsub -all {\t} $line { } line
		append line "\n"
		$target_widget insert $idx $line

		# Gain list of text tags in source widget
		set ranges [$this editor_procedure $editor_idx getTagsRanges $lineNum]
		# Determinate row in the target widget
		if {$idx == {end}} {
			set row [$target_widget index end]
			set row [expr {int($row) - 2}]
		} else {
			set row [expr {int($idx)}]
		}
		# Iterate over source text tags and add them to target widget
		foreach range $ranges {
			# Local variables
			set tag		[lindex $range 0]	;# Text tag
			set range	[lindex $range 1]	;# Tag range
			set range_len	[llength $range]	;# Number of indexes in tag range

			# Iterate over ranges
			for {set i 0} {$i < $range_len} {incr i} {

				# Translate indexes
				set idx0 [lindex $range $i]
				regsub {^\d+} $idx0 $row idx0
				incr i
				set idx1 [lindex $range $i]
				regsub {^\d+} $idx1 $row idx1

				# Set tag
				$target_widget tag add $tag $idx0 $idx1
			}
		}
	}

	## Add bookmark to the list
	 # @parm Int lineNum - line number in the editor
	 # @return void
	public method rightPanel_add_bookmark {lineNum} {
		if {$block_select} {return}

		## Determinate target text index
		set indexes [$bookmarks_lineNumbers get 1.0 end]

		set idx -1
		set i 0
		foreach line $indexes {
			incr i
			if {$line > $lineNum} {
				set idx $i
				break
			}
		}

		if {$idx == -1} {
			set idx {end}
		} else {
			append idx {.0}
		}

		# Enable widgets
		$bookmarks_lineNumbers configure -state normal
		$bookmarks_text configure -state normal

		# Insert new line to line numbers
		$bookmarks_lineNumbers insert $idx "$lineNum\n"
		adjust_width $bookmarks_lineNumbers

		# Insert text to the list
		insert_text $bookmarks_text $idx $lineNum {}

		# Disable widgets
		$bookmarks_lineNumbers configure -state disabled
		$bookmarks_text configure -state disabled

		# Reevaluate icon bar button states
		bm_bp_disEna_buttons
	}

	## Remove bookmark from the list
	 # @parm Int lineNum - line number (in Editor)
	 # @return void
	public method rightPanel_remove_bookmark {lineNum} {
		if {$block_select} {return}

		# Determinate start and end index
		set idx [lsearch [$bookmarks_lineNumbers get 1.0 end] $lineNum]
		if {$idx == -1} {return}

		set idx0 [expr {int($idx) + 1}]
		set idx1 [expr {int($idx) + 2}]

		# Enable widgets
		$bookmarks_lineNumbers configure -state normal
		$bookmarks_text configure -state normal

		# Remove line from line numbers
		$bookmarks_lineNumbers delete $idx0.0 $idx1.0
		adjust_width $bookmarks_lineNumbers

		# Remove line from the list
		$bookmarks_text delete $idx0.0 $idx1.0

		# Disable widgets
		$bookmarks_lineNumbers configure -state disabled
		$bookmarks_text configure -state disabled

		# Reevaluate icon bar button states
		bm_bp_disEna_buttons
	}

	## Add breakpoint to the list
	 # @parm Int lineNum - line number in the editor
	 # @return void
	public method rightPanel_add_breakpoint {lineNum} {
		if {$block_select} {return}

		## Determinate target text index
		set indexes [$breakpoints_lineNumbers get 1.0 end]

		set idx -1
		set i 0
		foreach line $indexes {
			incr i
			if {$line > $lineNum} {
				set idx $i
				break
			}
		}

		if {$idx == -1} {
			set idx {end}
		} else {
			append idx {.0}
		}

		# Enable widgets
		$breakpoints_lineNumbers configure -state normal
		$breakpoints_text configure -state normal

		# Insert new line to line numbers
		$breakpoints_lineNumbers insert $idx "$lineNum\n"
		adjust_width $breakpoints_lineNumbers

		# Insert text to the list
		insert_text $breakpoints_text $idx $lineNum {}

		# Disable widgets
		$breakpoints_lineNumbers configure -state disabled
		$breakpoints_text configure -state disabled

		# Reevaluate icon bar button states
		bm_bp_disEna_buttons
	}

	## Remove breakpoint from the list
	 # @parm Int lineNum - line number (in Editor)
	 # @return void
	public method rightPanel_remove_breakpoint {lineNum} {
		if {$block_select} {return}

		# Determinate start and end index
		set idx [lsearch [$breakpoints_lineNumbers get 1.0 end] $lineNum]
		if {$idx == -1} {return}

		set idx0 [expr {int($idx) + 1}]
		set idx1 [expr {int($idx) + 2}]

		# Enable widgets
		$breakpoints_lineNumbers configure -state normal
		$breakpoints_text configure -state normal

		# Remove line from line numbers
		$breakpoints_lineNumbers delete $idx0.0 $idx1.0
		adjust_width $breakpoints_lineNumbers

		# Remove line from the list
		$breakpoints_text delete $idx0.0 $idx1.0

		# Disable widgets
		$breakpoints_lineNumbers configure -state disabled
		$breakpoints_text configure -state disabled

		# Reevaluate icon bar button states
		bm_bp_disEna_buttons
	}

	## Adjust width of given text widget to fit lenght of the last line
	 # @parm Widget widget - target text widget
	 # @return void
	private method adjust_width {widget} {
		$widget configure -width [string length [lindex [$widget get end-2l end] end]]

		catch {
			$widget tag add right 0.0 end
		}
	}

	## Binding for button "Up" (Bookmarks icon bar) - select bookmark above the current line
	 # @return void
	public method rightPanel_bm_up {} {

		# Gain list of bookmarks (line numbers)
		set lineNumbers [$bookmarks_lineNumbers get 1.0 end]
		if {[llength $lineNumbers] == 0} {return}

		# Get current line in the editor
		set curLineNum [$this editor_procedure {} get_current_line_number {}]

		# Find nearest bookmark
		set lineNum [lindex $lineNumbers end]
		set idx -2
		foreach line $lineNumbers {
			incr idx
			if {$line >= $curLineNum} {
				if {$idx >= 0} {
					set lineNum [lindex $lineNumbers $idx]
				}
				break
			}
		}

		# Select designated bookmark and jump to its line
		rightPanel_bm_select $lineNum
		$this editor_procedure {} goto $lineNum
	}

	## Binding for button "Up" (Breakpoints icon bar) - select breakpoint above the current line
	 # @return void
	public method rightPanel_bp_up {} {

		# Gain list of breakpoints (line numbers)
		set lineNumbers [$breakpoints_lineNumbers get 1.0 end]
		if {[llength $lineNumbers] == 0} {return}

		# Get current line in the editor
		set curLineNum [$this editor_procedure {} get_current_line_number {}]

		# Find nearest breakpoint
		set lineNum [lindex $lineNumbers end]
		set idx -2
		foreach line $lineNumbers {
			incr idx
			if {$line >= $curLineNum} {
				if {$idx >= 0} {
					set lineNum [lindex $lineNumbers $idx]
				}
				break
			}
		}

		# Select designated breakpoint and jump to its line
		rightPanel_bp_select $lineNum
		$this editor_procedure {} goto $lineNum
	}

	## Binding for button "Down" (Bookmarks icon bar) - select bookmark below the current line
	 # @return void
	public method rightPanel_bm_down {} {
		# Gain list of bookmarks (line numbers)
		set lineNumbers [$bookmarks_lineNumbers get 1.0 end]
		if {[llength $lineNumbers] == 0} {return}

		# Get current line in the editor
		set curLineNum [$this editor_procedure {} get_current_line_number {}]

		# Find nearest bookmark
		set lineNum [lindex $lineNumbers 0]
		set idx -1
		foreach line $lineNumbers {
			incr idx
			if {$line > $curLineNum} {
				set lineNum [lindex $lineNumbers $idx]
				break
			}
		}

		# Select designated bookmark and jump to its line
		rightPanel_bm_select $lineNum
		$this editor_procedure {} goto $lineNum
	}

	## Binding for button "Down" (Breakpoints icon bar) - select breakpoint below the current line
	 # @return void
	public method rightPanel_bp_down {} {
		# Gain list of breakpoints (line numbers)
		set lineNumbers [$breakpoints_lineNumbers get 1.0 end]
		if {[llength $lineNumbers] == 0} {return}

		# Get current line in the editor
		set curLineNum [$this editor_procedure {} get_current_line_number {}]

		# Find nearest breakpoint
		set lineNum [lindex $lineNumbers 0]
		set idx -1
		foreach line $lineNumbers {
			incr idx
			if {$line > $curLineNum} {
				set lineNum [lindex $lineNumbers $idx]
				break
			}
		}

		# Select designated breakpoint and jump to its line
		rightPanel_bp_select $lineNum
		$this editor_procedure {} goto $lineNum
	}

	## Remove all bookmarks from the list
	 # @return void
	public method rightPanel_clear_all_bookmarks {} {
		# Enable widgets
		$bookmarks_lineNumbers configure -state normal
		$bookmarks_text configure -state normal
		# Clear text widgets
		$bookmarks_lineNumbers delete 1.0 end
		adjust_width $bookmarks_lineNumbers
		$bookmarks_text delete 1.0 end
		# Disable widgets
		$bookmarks_lineNumbers configure -state disabled
		$bookmarks_text configure -state disabled

		# Reevaluate button states (icon bar)
		bm_bp_disEna_buttons
	}

	## Remove all breapoints editor
	 # @return void
	public method rightPanel_clear_all_breakpoints {} {
		# Enable widgets
		$breakpoints_lineNumbers configure -state normal
		$breakpoints_text configure -state normal
		# Clear text widgets
		$breakpoints_lineNumbers delete 1.0 end
		adjust_width $breakpoints_lineNumbers
		$breakpoints_text delete 1.0 end
		# Disable widgets
		$breakpoints_lineNumbers configure -state disabled
		$breakpoints_text configure -state disabled

		# Reevaluate button states (icon bar)
		bm_bp_disEna_buttons
	}

	## Manage list of bookmarks - some lines have been removed from editor widget
	 # @parm Int start_line	- start of deleted area
	 # @parm Int end_line	- end of deleted area
	 # @return void
	public method rightPanel_remove_bookmarks {start_line end_line} {

		# Gain list of bookmarks
		set lineNumbers [$bookmarks_lineNumbers get 1.0 end]

		## Determinate start and end text indexes (list of bookmarks)

		# Start index
		set start_idx {}
		set idx 0
		foreach line $lineNumbers {
			incr idx
			if {$line >= $start_line} {
				set start_idx $idx.0
				break
			}
		}

		# End index
		set end_idx {end}
		set idx 0
		foreach line $lineNumbers {
			incr idx
			if {$line > $end_line} {
				if {$idx != 0} {
					set end_idx $idx.0
				}
				break
			}
		}

		# Default start index
		if {$start_idx == {}} {
			if {[lindex $lineNumbers end] != $end_line} {
				return
			} else {
				set start_idx 1.0
			}
		}

		# Determinate number of lines to remove
		set diff [expr {$end_line - $start_line + 1}]

		# Enable line numbers
		$bookmarks_lineNumbers configure -state normal
		# Gain list of lines to recomputation
		set lineNumbers [$bookmarks_lineNumbers get $end_idx end]
		# Remove lines from line numbers
		$bookmarks_lineNumbers delete $start_idx end
		if {[llength [$bookmarks_lineNumbers get 1.0 end]] != 0} {
			$bookmarks_lineNumbers insert end "\n"
		}
		# Compute missing lines in line numbers
		foreach line $lineNumbers {
			$bookmarks_lineNumbers insert end [expr {$line - $diff}]
			$bookmarks_lineNumbers insert end "\n"
		}
		# Finish adjustemnt of line numbers
		adjust_width $bookmarks_lineNumbers
		$bookmarks_lineNumbers configure -state disabled

		# Remove lines from list of bookmarks
		$bookmarks_text configure -state normal
		$bookmarks_text delete $start_idx $end_idx
		$bookmarks_text configure -state disabled

		# Reevaluate button states (icon bar)
		bm_bp_disEna_buttons
	}

	## Manage list of breakpoints - some lines have been removed from editor widget
	 # @parm Int start_line	- start of deleted area
	 # @parm Int end_line	- end of deleted area
	 # @return void
	public method rightPanel_remove_breakpoints {start_line end_line} {

		# Gain list of breakpoints
		set lineNumbers [$breakpoints_lineNumbers get 1.0 end]

		## Determinate start and end text indexes (list of breakpoints)

		# Start index
		set start_idx {}
		set idx 0
		foreach line $lineNumbers {
			incr idx
			if {$line >= $start_line} {
				set start_idx $idx.0
				break
			}
		}

		# End index
		set end_idx {end}
		set idx 0
		foreach line $lineNumbers {
			incr idx
			if {$line > $end_line} {
				if {$idx != 0} {
					set end_idx $idx.0
				}
				break
			}
		}

		# Default start index
		if {$start_idx == {}} {
			if {[lindex $lineNumbers end] != $end_line} {
				return
			} else {
				set start_idx 1.0
			}
		}

		# Determinate number of lines to remove
		set diff [expr {$end_line - $start_line + 1}]

		# Enable line numbers
		$breakpoints_lineNumbers configure -state normal
		# Gain list of lines to recomputation
		set lineNumbers [$breakpoints_lineNumbers get $end_idx end]
		# Remove lines from line numbers
		$breakpoints_lineNumbers delete $start_idx end
		if {[llength [$breakpoints_lineNumbers get 1.0 end]] != 0} {
			$breakpoints_lineNumbers insert end "\n"
		}
		# Compute missing lines in line numbers
		foreach line $lineNumbers {
			$breakpoints_lineNumbers insert end [expr {$line - $diff}]
			$breakpoints_lineNumbers insert end "\n"
		}
		# Finish adjustemnt of line numbers
		adjust_width $breakpoints_lineNumbers
		$breakpoints_lineNumbers configure -state disabled

		# Remove lines from list of breakpoints
		$breakpoints_text configure -state normal
		$breakpoints_text delete $start_idx $end_idx
		$breakpoints_text configure -state disabled

		# Reevaluate button states (icon bar)
		bm_bp_disEna_buttons
	}

	## Clear the list of symbols
	 # @return void
	public method rightPanel_clear_symbol_list {} {
		$sm_lineNumbers configure -state normal
		$sm_text configure -state normal

		$sm_lineNumbers delete 0.0 end
		$sm_text delete 0.0 end
		adjust_width $sm_lineNumbers

		$sm_lineNumbers configure -state disabled
		$sm_text configure -state disabled
	}

	## Refresh the list of symbols
	 # @return void
	public method rightPanel_refresh_symbols {} {
		rightPanel_clear_symbol_list

		$this editor_procedure {} autocompletion_turned_on {}
		$this editor_procedure {} clear_autocompletion_list {}
		$this editor_procedure {} comp_win_highlight_all_in_background {}
	}

	## Validator for search entrybox in the list of symbols
	 # @parm String content	- A string to search for
	 # @parm Widget widget	- Search entrybox widget
	 # @parm Widget clr_b	- Clear button
	 # @return Bool - Success
	public method rightPanel_sm_search_validate {content widget clr_b} {
		# No recursion ...
		if {$search_val_in_progress} {return 0}
		set search_val_in_progress 1

		# Empty string
		if {![string length $content]} {
			$widget configure -style TEntry
			$clr_b configure -state disabled

			set search_val_in_progress 0
			return 1

		# Not empty string
		} else {
			$clr_b configure -state normal
		}

		# Perform the search
		set content [string toupper $content]
		set e [expr {int([$sm_text index insert])}]
		for {set i 1} {$i < $e} {incr i} {
			if {![string first $content [string toupper [$sm_text get $i.2 [list $i.0 lineend]]]]} {
				$widget configure -style StringFound.TEntry

				$sm_text tag remove curLine 1.0 end
				$sm_text tag add curLine $i.0 [list $i.0+1l linestart]
				$sm_text see $i.0

				set block_select 1
				$this editor_procedure {} goto [$sm_lineNumbers get $i.0 [list $i.0 lineend]]
				update idletasks
				set block_select 0
				set search_val_in_progress 0
				return 1
			}
		}

		$widget configure -style StringNotFound.TEntry
		set search_val_in_progress 0
		return 1
	}

	## Adjust list of symbols
	 # @parm Int lineNum		- Line number
	 # @parm String symbol_name	- Symbol name
	 # @parm Int symbol_type	-
	 #	0 - Label
	 #	1 - Constant
	 #	2 - Something else
	 #	3 - Macro
	 # @parm Bool add__remove	- 1 == Add; 0 == Remove
	 # @return void
	public method rightPanel_adjust_symbol_list {lineNum symbol_name symbol_type add__remove {editor_object {}}} {
		if {[$this is_splitted] && $editor_object != {}} {
			set idx [lsearch -ascii -exact [$this cget -editors] $editor_object]

			if {$idx != $current_editor_idx} {
				rightPanel_switch_editor_vars $idx
			}
		}
	
		$sm_lineNumbers configure -state normal
		$sm_text configure -state normal

		# Add symbol
		if {$add__remove} {
			set indexes [$sm_lineNumbers get 1.0 end]

			set idx -1
			set i 0
			foreach line $indexes {
				incr i
				if {$line > $lineNum} {
					set idx $i
					break
				}
			}

			if {$idx == -1} {
				set idx [$sm_text index {end-1l}]
			} else {
				append idx {.0}
			}

			switch -- $symbol_type {
				0 {	;# Label
					set tag {tag_label}
					set icon {symbol1}
				}
				1 {	;# Constant
					set tag {tag_constant}
					set icon {symbol3}
				}
				2 {	;# C variable
					set tag {tag_normal}
					set icon {symbol4}
				}
				3 {	;# Macro
					set tag {tag_macro}
					set icon {symbol2}
				}
				7 {	;# C function
					set tag {tag_c_func}
					set icon {symbol0}
				}
				default {
					set tag {}
					set icon {symbol5}
				}
			}

			$sm_lineNumbers insert $idx "$lineNum\n"

			if {${::Editor::defaultCharHeight} < 16} {
				$sm_text insert ${idx} { }
			} else {
				$sm_text image create $idx -image ::ICONS::16::$icon
			}
			$sm_text insert ${idx}+1c " $symbol_name\n"

			if {$tag != {}} {
				$sm_text tag add $tag $idx [list $idx lineend]
			}

		# Remove symbol
		} else {
			if {$lineNum == {all}} {
				set idx [list]
				set e [expr {int([$sm_lineNumbers index end]) - 1}]
				for {set i 0} {$i < $e} {incr i} {
					lappend idx $i
				}
			} else {
				set idx [lsearch -all [$sm_lineNumbers get 1.0 end] $lineNum]
			}

			if {$idx == {}} {
				return
			}
			foreach i $idx {
				incr i
				if {[string equal [$sm_text get $i.2 [list $i.0 lineend]] $symbol_name]} {
					$sm_text delete $i.0 $i.0+1l
					$sm_lineNumbers delete $i.0 $i.0+1l
					break
				}
			}
		}

		adjust_width $sm_lineNumbers
		$sm_lineNumbers configure -state disabled
		$sm_text configure -state disabled
	}

	## Shift list of symbols by certain number of lines
	 # @parm Int lineNum 	- Starting line
	 # @parm Int length	- Number of lines to shift by
	 # @return void
	public method rightPanel_shift_symbols {lineNum length} {
		if {![info exists sm_lineNumbers]} {return}

		# Get list of bookmarks
		set lineNumbers [$sm_lineNumbers get 1.0 end]

		# Deterinate start index
		set start_idx {}
		set idx 0
		foreach line $lineNumbers {
			incr idx
			if {$line >= $lineNum} {
				set start_idx $idx.0
				break
			}
		}

		if {$start_idx == {}} {return}

		# Adjust line numbers
		$sm_lineNumbers configure -state normal
		set lineNumbers [$sm_lineNumbers get $start_idx end]
		$sm_lineNumbers delete $start_idx end
		if {[llength [$sm_lineNumbers get 1.0 end]] != 0} {
			$sm_lineNumbers insert end "\n"
		}
		foreach line $lineNumbers {
			$sm_lineNumbers insert end [expr {$line + $length}]
			$sm_lineNumbers insert end "\n"
		}
		adjust_width $sm_lineNumbers
		$sm_lineNumbers configure -state disabled
	}

	## Manage list of bookmarks - some lines have been added to editor widget
	 # @parm Int lineNum	- line number
	 # @parm Int length	- number of lines
	 # @return void
	public method rightPanel_shift_bookmarks {lineNum length} {
		if {![info exists bookmarks_lineNumbers]} {return}

		# Get list of bookmarks
		set lineNumbers [$bookmarks_lineNumbers get 1.0 end]

		# Deterinate start index
		set start_idx {}
		set idx 0
		foreach line $lineNumbers {
			incr idx
			if {$line >= $lineNum} {
				set start_idx $idx.0
				break
			}
		}

		if {$start_idx == {}} {return}

		# Adjust line numbers
		$bookmarks_lineNumbers configure -state normal
		set lineNumbers [$bookmarks_lineNumbers get $start_idx end]
		$bookmarks_lineNumbers delete $start_idx end
		if {[llength [$bookmarks_lineNumbers get 1.0 end]] != 0} {
			$bookmarks_lineNumbers insert end "\n"
		}
		foreach line $lineNumbers {
			$bookmarks_lineNumbers insert end [expr {$line + $length}]
			$bookmarks_lineNumbers insert end "\n"
		}
		adjust_width $bookmarks_lineNumbers
		$bookmarks_lineNumbers configure -state disabled
	}

	## Manage list of breakpoints - some lines have been added to editor widget
	 # @parm Int lineNum	- line number
	 # @parm Int length	- number of lines
	 # @return void
	public method rightPanel_shift_breakpoints {lineNum length} {
		if {![info exists bookmarks_lineNumbers]} {return}

		# Get list of bookmarks
		set lineNumbers [$breakpoints_lineNumbers get 1.0 end]

		# Deterinate start index
		set start_idx {}
		set idx 0
		foreach line $lineNumbers {
			incr idx
			if {$line >= $lineNum} {
				set start_idx $idx.0
				break
			}
		}

		if {$start_idx == {}} {return}

		# Adjust line numbers
		$breakpoints_lineNumbers configure -state normal
		set lineNumbers [$breakpoints_lineNumbers get $start_idx end]
		$breakpoints_lineNumbers delete $start_idx end
		if {[llength [$breakpoints_lineNumbers get 1.0 end]] != 0} {
			$breakpoints_lineNumbers insert end "\n"
		}
		foreach line $lineNumbers {
			$breakpoints_lineNumbers insert end [expr {$line + $length}]
			$breakpoints_lineNumbers insert end "\n"
		}
		adjust_width $breakpoints_lineNumbers
		$breakpoints_lineNumbers configure -state disabled
	}

	## Invoke right panel configuration dialog
	 # This function takes any list of arguments
	 # @return void
	public method rightPanel_configure args {
		::configDialogues::rightPanel::mkDialog $args
	}

	## Return true if this panel is in visible state
	 # @return Bool - result
	public method isRightPanelVisible {} {return $PanelVisible}

	## Get width of the panel
	 # @return Int - width in pixels
	public method getRightPanelSize {} {
		if {$PanelVisible} {
			return $PanelSize
		} else {
			return $last_PanelSize
		}
	}

	## Get ID of currently active page
	 # @return String - the ID
	public method getRightPanelActivePage {} {return $active_page}

	## Show/Hide this panel
	 # @return void
	public method right_panel_show_hide {} {
		# Hide the panel
		if {$PanelVisible} {
			$parentPane paneconfigure $notebook_frame -minsize 0

			pack forget [$notebook get_nb]	;# Hide notebook
			set last_PanelSize $PanelSize	;# Save current panel width
			set PanelSize 60		;# Change panel width
			right_panel_redraw_pane		;# Redraw panel

			# Show button bar
			pack $button_bar -anchor nw
			# Hide pane sash
			$parentPane configure -sashwidth 0
			bind $parentPane <Button> {break}
			# Set panel visibility flag
			set PanelVisible 0

		# Show the panel
		} else {
			$parentPane paneconfigure $notebook_frame -minsize 295

			# Hide button bar
			pack forget $button_bar
			# Show panel notebook
			set PanelSize $last_PanelSize
			right_panel_redraw_pane
			$notebook raise $active_page
			pack [$notebook get_nb] -expand 1 -fill both
			# Show pane sash
			$parentPane configure -sashwidth 2
			bind $parentPane <Button> {}
			# Set panel visibility flag
			set PanelVisible 1
		}
	}

	## Change panel active page
	 # @parm String page - ID of the page to show
	 # @return void
	public method rightPanel_show_up {page} {
		if {!$PanelVisible} right_panel_show_hide
		$notebook raise $page
	}

	## Set active page but do not show it
	 # @parm String pageName - ID of the page
	 # @return void
	public method rightPanel_set_active_page {pageName} {
		switch -- $active_page {
			{Symbols} {
				catch {
					$this editor_procedure {} comp_win_highlight_all_in_background {}
				}
			}
			{Instruction} {
				right_panel_instruction_details_set_enabled 0
			}
		}

		set active_page $pageName

		switch -- $active_page {
			{Symbols} {
				catch {
					$this editor_procedure {} comp_win_highlight_all_in_background {}
				}
			}
			{Instruction} {
				right_panel_instruction_details_set_enabled $enabled
				catch {
					$this editor_procedure {} adjust_instruction_details {}
				}
			}
		}
	}

	## Set panel width according to current sash position
	 # @return void
	public method right_panel_set_size {} {
		set PanelSize [lindex [$parentPane sash coord 0] 0]
		set PanelSize [expr {${::WIN_GEOMETRY_width} - $PanelSize}]
	}

	## Redraw panel (move pane sash) acorning to current value of $PanelSize
	 # @return void
	public method right_panel_redraw_pane {} {
		if {$redraw_pane_in_progress} {
			after 50 "$this right_panel_redraw_pane"
			return
		}
		set redraw_pane_in_progress 1

		update
		$parentPane sash place 0 [expr {${::WIN_GEOMETRY_width} - $PanelSize}] 0
		update

		set redraw_pane_in_progress 0
	}

	## Create text tags inteded for "Instruction details"
	 # @parm Widget widget		- tagret text widget
	 # @parm List definition_list	- List of tags to create ({tag_name fg_color ?bold_or_italic?} ...)
	 # @parm Bool use_editor_font	- Use font family and size from code editor
	 # @return void
	public method right_panel_create_highlighting_tags {widget definition_list use_editor_font} {
		if {$use_editor_font == 1} {
			set font $fontFamily
			set size $fontSize
		} elseif {$use_editor_font == -1} {
			set font $::DEFAULT_FIXED_FONT
			set size [expr {int(-14 * $::font_size_factor)}]
		} else {
			set font $::DEFAULT_FIXED_FONT
			set size [expr {int(-12 * $::font_size_factor)}]
		}

		# Iterate over tags definition
		foreach tag $definition_list {

			# Explicit flag "Bold or Italic"
			if {[lindex $tag 2] != {}} {
				# Bold font
				if {[lindex $tag 2]} {
					$widget tag configure [lindex $tag 0]	\
						-foreground [lindex $tag 1]	\
						-font [font create -size $size	\
							-family $font		\
							-weight {bold}		\
							-slant {roman}]
				# Italic font
				} else {
					$widget tag configure [lindex $tag 0]	\
						-foreground [lindex $tag 1]	\
						-font [font create -size $size	\
							-family $font		\
							-weight {normal}	\
							-slant {italic}]
				}

			# No bold, no italic
			} else {
				$widget tag configure [lindex $tag 0]	\
					-foreground [lindex $tag 1]	\
					-font [font create -size $size	\
						-family $font		\
						-weight {normal}	\
						-slant {roman}]
			}
		}
	}

	## Enable selections in list of bookmarks and breakpoints and enbale instruction details
	 # @return void
	public method rightPanel_enable {} {
		set enabled 1
		$this right_panel_watches_set_enabled $enabled
		$this right_panel_instruction_details_set_enabled $enabled
	}

	## Disable selections in list of bookmarks and breakpoints and enbale instruction details
	 # @return void
	public method rightPanel_disable {} {
		set enabled 0
		$this right_panel_watches_set_enabled $enabled
		$this right_panel_instruction_details_set_enabled $enabled
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

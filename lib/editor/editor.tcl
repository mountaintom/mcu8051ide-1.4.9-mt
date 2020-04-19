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
if { ! [ info exists _EDITOR_TCL ] } {
set _EDITOR_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements source code editor with syntax highligh and
# lightweight syntax validation.
# This GUI component consist of line numbers border, icon border,
# editor, command line and status bar.
#
# Consist of:
#	* PROCEDURES RELATED TO EDITOR COMMAND LINE
#	* GENERAL PURPOSE PROCEDURES
#	* EXPORTS TO OTHER DATA FORMATS (XHTML && LATEX)
#	* KEY EVENT HANDLERS
#	* AUTOCOMPLETION RELATED PROCEDURES
# --------------------------------------------------------------------------

# Load syntax highlighting
source "${::LIB_DIRNAME}/editor/ASMsyntaxhighlight.tcl"
source "${::LIB_DIRNAME}/editor/R_ASMsyntaxhighlight.tcl"
source "${::LIB_DIRNAME}/editor/Csyntaxhighlight.tcl"
source "${::LIB_DIRNAME}/editor/LSTsyntaxhighlight.tcl"

# Initialize variable containing count of matched strings
set ::editor_search_count 0

class Editor {
	## COMMON
	 ## Editor to use
	  # 0 - Native editor
	  # 1 - Vim
	  # 2 - Emacs
	  # 3 - Nano
	  # 4 - dav
	  # 5 - le
	public common editor_to_use	0
	public common intentation_mode	{normal};# Editor indentation mode
	public common spaces_no_tabs	0	;# Bool: Use spaces instead of tabs
	public common number_of_spaces	8	;# Number of spaces to use instead of tab
	public common auto_brackets	1	;# Automaticaly insert oposite brackets, quotes, etc.
	public common auto_completion	1	;# Enable popup-base completion for code editor
	public common cline_completion	1	;# Enable popup-base completion for command line
	public common autosave		0	;# Int: 0 == Disable autosave; N > 0 == minutes
	public common hg_trailing_sp	1	;# Bool: Highlight trailing spaces

	public common finishigh_hg_dlg_max 	;# Int: Highlight dialog -- maximum value for progress bar
	public common finishigh_hg_dlg_const	;# Int: Highlight dialog -- current value for progress bar

	public common set_shortcuts	{}	;# Currently set shortcut bindigs
	public common shortcuts_cat	{edit}	;# Key shortcut categories related to this segment
	public common count		0	;# Counter of class instances
	public common bookmark		0	;# Auxiliary variable for popup menu for Icon Border
	public common breakpoint	0	;# Auxiliary variable for popup menu for Line Numbers
	public common pmenu_cline	0	;# Auxiliary variable for popup menu for Icon Border and Line Numbers
	public common wrap_char	"\uB7"	;# Character intended for marking wrapped lines

	# Commands supported by editor command line
	public common editor_commands {
		animate		assemble	auto-indent	bookmark	breakpoint
		capitalize	clear		comment		copy		custom
		cut		date		exit		exit-program	find
		goto		help		char		indent		kill-line
		open		paste		redo		reload		replace
		run		save		set-icon-border	sim		set-line-numbers
		step		tolower		toupper		uncomment	undo
		unindent	d2h		d2o		d2b		h2d
		h2o		h2b		o2h		o2d		o2b
		b2h		b2d		b2o		hibernate	resume
		switch-mcu	set-xcode	set-xdata
	}
	# Editor commands wich can take options
	public common commands_with_option {find replace}
	## Tags which defines background color for specific type of lines
	 # {{tagname	bg-color	bool-priority} ...}
	public common line_markers {
		{sel			#AAAAFF}
		{tag_current_line	#FFFF88}
		{tag_bookmark		#DDDDFF}
		{tag_breakpoint		#FF0000}
		{tag_simulator_curr	#AAFFAA}
		{tag_error_line		#FFDDDD}
		{tag_trailing_space	#E8FFF0}
		{tag_breakpoint_INVALID	#888888}
	}

	# Font for command line: Normal help window text
	public common cl_hw_nrml_font	[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-14 * $::font_size_factor)}]	\
	]
	# Font for command line: Bold help window text
	public common cl_hw_bold_font	[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight bold					\
	]
	# Font for command line: Subheader in help window text
	public common cl_hw_hdr_font	[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight bold					\
	]
	# Font for command line: Main header in help window text
	public common cmd_line_win_font [font create			\
		-size [expr {int(-17 * $::font_size_factor)}]	\
		-weight bold					\
		-family {helvetica}				\
	]
	# Font size for command line
	public common cmd_line_fontSize	[expr {int(14 * $::font_size_factor)}]
	# Font family for command line
	public common cmd_line_fontFamily	$::DEFAULT_FIXED_FONT
	# Font for editor command line
	public common cmd_line_font	[font create	\
		-family $cmd_line_fontFamily	\
		-size -$cmd_line_fontSize	\
	]
	## Highlight tags for command line
	 # {
	 #	{tag_name ?foreground? ?overstrike? ?italic? ?bold?}
	 # }
	public common cmd_line_highlighting	{
		{tag_cmd		#0000DD	0 0 1}
		{tag_argument		#00DD00	0 0 0}
		{tag_option		#DD0000	0 0 1}
	}

	public common normal_text_bg	#FFFFFF	;# Default background color for editor
	public common iconBorder_bg	#C8C5FF	;# Default background color for icon border
	public common lineNumbers_bg	#9497D8	;# Default background color for line numbers
	public common lineNumbers_fg	#FFFFFF	;# Default foreground color for line numbers
	# Items in editor menu, which should be disabled when editor goes to simulator mode
	public common freezable_menu_items {
		Cut Paste Undo Redo Comment Uncomment Indent
		Unindent Uppercase Lowercase Capitalize
	}
	# Items in editor menu, which should be disabled when editor is in read only mode
	public common read_na_only_menu_items {
		Cut Paste Undo Redo Comment Uncomment Indent
		Unindent Uppercase Lowercase Capitalize
	}

	# Maximum width of the tab character, measured in number of spaces
	public common tab_width		8

	# Default font size
	public common fontSize		[expr {int(13 * $::font_size_factor)}]
	# Default font family
	public common fontFamily	$::DEFAULT_FIXED_FONT

	# Default font for editor
	public common defaultFont		\
		[font create		\
		-size -$fontSize	\
		-family $fontFamily	\
		-weight {normal}	\
	]
	public common defaultFont_bold		\
		[font create		\
		-size -$fontSize	\
		-family $fontFamily	\
		-weight {bold}		\
	]
	public common defaultCharWidth		0	;# Width of one character of the default font
	public common defaultCharHeight	0	;# Height of one character of the default font
	# Font for status bar (Normal)
	public common statusBarFont					\
		[font create					\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-family $::DEFAULT_FIXED_FONT			\
	]
	# Font for status bar (Bold)
	public common statusBarBoldFont				\
		[font create					\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
		-family $::DEFAULT_FIXED_FONT			\
	]
	# Definition of editor popup menu
	public common EDITORMENU {
		{command	{LJMP this line} {$edit:jmp}	2	"ljmp_this_line {}"
			{exec}		"Program jump"}
		{command	{LCALL this line} {$edit:call}	4	"lcall_this_line {}"
			{exec}		"Call subprogram"}
		{separator}
		{command	{Breakpoint}	{$edit:breakpoint}	0	"Breakpoint {}"
			{flag}		"Add/Remove breakpoint to/from current line"}
		{command	{Bookmark}	{$edit:bookmark}	1	"Bookmark {}"
			{bookmark_add}	"Add/Remove bookmark to/from current line"}
		{separator}
		{command	{Undo}		{$edit:undo}	0		"undo {}"
			{undo}		"Take back last operation"}
		{command	{Redo}		{$edit:redo}	2		"redo {}"
			{redo}		"Take back last undo"}
		{separator}
		{command	{Cut}		{$edit:cut}		2	"cut {}"
			{editcopy}	"Move selected text into the clipboard"}
		{command	{Copy}		{$edit:copy}		0	"copy {}"
			{editcut}	"Copy selected text into the clipboard"}
		{command	{Paste}		{$edit:paste}		0	"paste {}"
			{editpaste}	"Paste text from clipboard"}
		{separator}
		{command	{Select all}	{$edit:select_all}	0	"select_all {}"
			{}		"Select all text in the editor"}
		{separator}
		{command	{Comment}	{$edit:comment}		1	"comment {}"
			{}		"Comment selected text"}
		{command	{Uncomment}	{$edit:uncomment}	4	"uncomment {}"
			{}		"Uncomment selected text"}
		{separator}
		{command	{Indent}	{$edit:indent}		2	"indent {}"
			{indent}	"Indent selected text"}
		{command	{Unindent}	{$edit:unindent}	1	"unindent {}"
			{unindent}	"Unindent selected text"}
		{separator}
		{command	{Uppercase}	{$edit:uppercase}	0	"lowercase {}"
			{up0}		"Indent selected text"}
		{command	{Lowercase}	{$edit:lowercase}	2	"uppercase {}"
			{down0}		"Unindent selected text"}
		{command	{Capitalize}	{$edit:capitalize}	4	"capitalize {}"
			{}		"Unindent selected text"}
		{separator}
		{command	{Save file}	{$edit:save}		0	"save {}"
			{filesave}	"Save this file"}
	}
	# Definition of popup menu for icon border
	public common IBMENU {
		{checkbutton	"Bookmark"	{$edit:bookmark}	{::Editor::bookmark}	1 0 0
			{Bookmark ${::Editor::pmenu_cline}}}
		{separator}
		{command	"Configure panel"	""	0	{configDialogues_mkDialog Colors}
			{configure}	"Invoke editor configuration dialog"}
		{command	"Hide"			""	0	{show_hine_IconB}
			{2leftarrow}	"Hide this panel"}
	}
	# Definition of popup menu for line numbers
	public common LNMENU {
		{checkbutton	"Breakpoint"	{$edit:breakpoint}	{::Editor::breakpoint}	1 0 0
			{Breakpoint ${::Editor::pmenu_cline}}}
		{separator}
		{command	"Configure panel"	""	0	{configDialogues_mkDialog Colors}
			{configure}	"Invoke editor configuration dialog"}
		{command	"Hide panel" 		""	0	{show_hine_LineN}
			{2leftarrow}	"Hide this panel"}
	}
	# Definition of popup menu for editor statis bar
	public common STATMENU {
		{command	"Split vertical" 	{$edit:split_v}		8	{__split_vertical}
			{view_left_right}	"Split the editor vertically"}
		{command	"Split horizontal" 	{$edit:split_h}		6	{__split_horizontal}
			{view_top_bottom}	"Split the editor horizontally"}
		{separator}
		{command	"Close current view" 	{$edit:close_cv}	2	{__close_current_view_from_pmenu}
			{view_remove}		""}
		{separator}
		{command	"Back" 			{$edit:prev}		0	{__prev_editor_from_pmenu}
			{left}			"Go to previous file in the file list"}
		{command	"Forward" 		{$edit:next}		0	{__next_editor_from_pmenu}
			{right}			"Go to next file in the file list"}
	}

	## PUBLIC
	public variable editor			;# text widget identifier
	public variable ed_sc_frame		;# frame identifier (need packing)
	public variable show_iconBorder	1	;# on/off indicator for Icon Border (bool)
	public variable show_lineNum	1	;# on/off indicator for Line Numbers (bool)
	public variable iconBorder		;# Identifier of Icon Border text widget
	public variable lineNumbers		;# Identifier of Line Numbers text widget
	public variable scrollbar		;# Identifier of scrollbar widget
	public variable lastEnd		2	;# Last end index of Editor text widget (for speed optimization)
	public variable Sbar_lock_file		;# Identifier of image label widget at the left site of status bar
	public variable Sbar_sim_mode		;# Identifier of label widget at the left site of status bar
	public variable Sbar_ssim_mode
	public variable Sbar_dis_mode		;# Identifier of label widget at the left site of status bar
	public variable Sbar_CRT_frame		;# ID of frame on statusbar containing labels "Line: x Col: x Total: x"
	public variable Sbar_row		;# ID of label showing current line number
	public variable Sbar_col		;# ID of label showing current column
	public variable Sbar_total		;# ID of label showing total number of lines
	public variable Sbar_image		;# Identifier of floppy disk icon at the middle site of status bar
	public variable Sbar_fileName		;# Identifier of the text of filename at the right site of status bar
	public variable Sbar_prog_lang		;# ID of text specifying file type at the right site of status bar
	public variable fullFileName		;# Full file name of the current file ("" == untitled)
	public variable filename		;# Name of currently opened file or 'untitled'
	public variable modified	0	;# Boolean value indicating than the text has been modified since last save
	public variable encoding		;# Current character encoding (eg. 'utf-8')
	public variable eol			;# Current End of Line character (one of {lf crlf cr})
	public variable ro_mode		0	;# Bool: Read only mode

	## PRIVATE
	private variable file_change_notif_flg	0	;# Bool: The opened file was modified on disk by another program
	private variable finishigh_hg_dlg_wdg	{}	;# Widget: Finishing highlight dialog
	private variable finishigh_hg_dlg_tmr	{}	;# Timer: Finishing highlight dialog
	private variable object_initialized	0	;# Bool: Flag "Object initialized"
	private variable c_hg_tags_created	0	;# Bool: C language highlight tags created
	private variable lst_hg_tags_created	0	;# Bool: Code listing highlight tags created
	private variable cmd_prefix			;# Command prefix for popup menu
	private variable last_cur_line		1	;# Number of the last current line in the editor
	private variable last_sim_line		1	;# Number of the last simulator line in the editor
	private variable enable_parseAll	1	;# Enable reparese whole document (used by: parse_all)
	private variable bookmarks		{0}	;# List of boolean bookmarks, eg. {0 0 0 1 1 0 0}
	private variable breakpoints		{0}	;# List of boolean breakpoint, eg. {0 0 0 1 1 0 0}
	private variable menu				;# Identifier of popup menu for editor text widget
	private variable stat_menu			;# Identifier of popup menu for editor statusbar
	private variable IB_menu			;# Identifier of popup menu for icon border
	private variable ins_mode_lbl			;# Identifier of insertion mode label (on status bar)
	private variable sel_mode_lbl			;# Identifier of selection mode label (on status bar)
	private variable left_frame_L			;# ID of frame containing Line Numbers
	private variable left_frame_R			;# ID of frame containing Icon Border
	private variable LN_menu			;# Identifier of popup menu for line numbers
	private variable frozen			0	;# Bool: True if the editor is in simulator mode
	private variable getDataAsXHTML_abort	0	;# Set this variable to 1 to immediate stop export to XHTML
	private variable getDataAsLaTeX_abort	0	;# Set this variable to 1 to immediate stop export to LaTeX
	private variable changeLCase_abort	0	;# Set this variable to 1 to immediate stop changing letter case
	private variable parentObject			;# Identifier parent GUI component (some frame widget)
	private variable lastUpDownIndex	0	;# Last column index (for Up and Down actions)
	private variable scroll_in_progress	0	;# Bool: scroll procedure in progress
	private variable highlighted_lines	{0}	;# String/array of highlighted lines (eg. 00011111110001111)
	private variable critical_edit_proc	0	;# Bool: Critical edit procedure in progess
	private variable map_of_wraped_lines	{}	;# Map of wrapped lines (eg. {0 0 5 0 0 2 0})
	private variable number_of_wraps	0	;# Number of line wraps
	private variable ins_ovr_mode		1	;# Current insertion mode (1 == INS; 0 == OVR)
	private variable editor_width		0	;# Width of active area of the editor widget
	private variable editor_height		0
	private variable cmd_line			;# ID of command line entry widget
	private variable cmd_line_listbox	{}	;# Widget: ListBox of command line auto-completion window
	private variable completion_listbox	{}	;# Widget: ListBox of editor popup-based completion
	private variable do_not_hide_comp_win	0	;# Bool: Disable highing of editor completion win. on KeyRelease
	private variable autosave_timer		{}	;# ID of autosave timer (command "after")
	private variable key_handler_buffer	{}	;# List: Buffer for <Key> event handler
	private variable key_handler_in_progress 0	;# Bool: <Key> event handler in progress
	private variable statusbar_menu_config	{}	;# List: Status bar menu configuration list
	private variable auto_switching_lock	0	;# Bool: Automatic file switching enabled
	private variable selection_in_progress	0	;# Bool: Procedure "editor_selection" in progress
	private variable selection_mode		0	;# Bool: Block selection mode flag
	private variable save_in_progress	0	;# Bool: Saving in progress
	 ## Programming language
	  # 0 - Assembly language
	  # 1 - C
	  # 2 - Code listing
	  # 3 - ASX8051
	private variable prog_language		0

	private variable top_frame			;# Widget: Container frame for embedded external editor
	private variable terminal_created	0	;# Bool: Terminal emulator to run embedded editor has been created
	private variable top_frame_idx		0	;# Int: Unique number of container frame for embedded editor
	private variable pid			{}	;# Int: Process indentifier of embedded external editor (e.g. Vim)



	# Load procedures related to editor command line
	source "${::LIB_DIRNAME}/editor/commandline.tcl"

	# Load procedures related to exports to other data formats
	source "${::LIB_DIRNAME}/editor/exports.tcl"

	# Load autocompletion related procedures
	source "${::LIB_DIRNAME}/editor/autocompletion.tcl"

	# Load general purpose procedures
	source "${::LIB_DIRNAME}/editor/generalproc.tcl"

	# Load event handlers
	source "${::LIB_DIRNAME}/editor/eventhandlers.tcl"

	# Spell checker interface
	source "${::LIB_DIRNAME}/editor/spell_check.tcl"



	## Object constructor
	 # @parm Bool create_tags	- Create highlighting tags
	 # @parm String eol_char	- EOL (one of {lf cr crlf})
	 # @parm String enc		- Character encoding (some iso-8859-x or utf-8)
	 # @parm Bool read_only		- Read only flag
	 # @parm Bool switch_lock	- Automatic file switching enabled
	 # @parm widget parentobject	- Reference to parent object
	 # @parm String fileName	- filename to be showed in statusbar
	 # @parm String filepath	- location where to optionaly save the data, "" == untitled document
	 # @parm String cmd_prefix	- command prefix for popup menu
	 # @parm String data		- an input text data
	 # @parm Int sh			- Syntax highlight
	constructor {create_tags eol_char enc read_only switch_lock parentobject fileName filepath Cmd_prefix data sh} {
		close_completion_popup_window_NOW

		set bold_font [font create -size -$fontSize -family $fontFamily -weight {bold}]
		set italic_font [font create -size -$fontSize -family $fontFamily -slant {italic}]
		if {[font metrics $bold_font -displayof . -linespace] < [font metrics $italic_font -displayof . -linespace]} {
			set defaultFont_bold $italic_font
		} else {
			set defaultFont_bold $bold_font
		}

		# Configure specific ttk styles
		ttk::style configure Editor_DarkBg.TButton	\
			-background {#DDDDDD}			\
			-padding 0				\
			-borderwidth 1				\
			-relief flat
		ttk::style map Editor_DarkBg.TButton	\
			-relief [list active raised !active flat]

		# increment instance counter
		incr count

		# Set object variables
		array set autocompletion_list {0 {} 1 {} 2 {} 3 {} 4 {} 5 {} 6 {} 7 {}}
		set autocompletion_list(5) [lsort -ascii ${::ASMsyntaxHighlight::expr_instructions}]
		set autocompletion_list(6) [lsort -ascii [concat\
			${::CsyntaxHighlight::doxy_tags_type2}	\
			${::CsyntaxHighlight::doxy_tags_type1}	\
			${::CsyntaxHighlight::doxy_tags_type0}	\
		]]
		set auto_switching_lock [expr {!$switch_lock}]
		set ro_mode $read_only
		set encoding $enc
		set eol $eol_char
		set cmd_prefix $Cmd_prefix
		set parentObject $parentobject	;# Identifier parent GUI component (some frame widget)
		set fullFileName $filepath	;# Full file name (including path) of current file
		set filename $fileName		;# Name of currently opened file or 'untitled'
		refresh_available_SFR

		if {$sh == {}} {
			determinate_prog_lang 0
		} else {
			set prog_language_old $prog_language
			set prog_language $sh
		}

		if {$editor_to_use} {
			set ed_sc_frame [frame .editor_frame$count -bd 2 -relief sunken]
			recreate_terminal $fullFileName
			set editor [text .editor_frame$count.dummy_editor]
			return
		}

		# Create frames
		set ed_sc_frame		[frame .editor_frame$count]
		set top_frame		[frame $ed_sc_frame.editor_top_frame -relief sunken -bd 1]
		set left_frame		[frame $top_frame.editor_left_frame]
		set left_frame_L	[frame $left_frame.left -bg $iconBorder_bg]
		set left_frame_R	[frame $left_frame.right -bg $lineNumbers_bg]
		set bottom_frame	[frame $ed_sc_frame.bottom_frame]
		set statusbar		[frame $bottom_frame.editor_status -bg #DDDDDD]

		# Create command line
		set cmd_line [text $bottom_frame.cmd_line	\
			-bd 1					\
			-bg {#FFFFFF}				\
			-highlightcolor {#8888FF}		\
			-highlightthickness 1			\
			-height 1				\
			-font $cmd_line_font			\
		]
		setStatusTip -widget $cmd_line	\
			-text [mc "Editor command line, type `help' for more"]
		$cmd_line delete 1.0 end

		## Create "Icon border"
		set iconBorder [text $left_frame_L.editor_iconB	\
			-font $defaultFont_bold	\
			-width 2		\
			-bd 0			\
			-highlightthickness 0	\
			-bg $iconBorder_bg	\
			-exportselection 0	\
			-state disabled		\
			-takefocus 0		\
			-cursor hand2		\
			-relief flat		\
		]
		$iconBorder tag configure center -justify center
		setStatusTip -widget $iconBorder \
			-text [mc "Icon border - click to add/remove bookmark"]
		# Create poup menu for "Icon border"
		set IB_menu $iconBorder.editor_iconB_menu

		## Create "Line numbers"
		set lineNumbers [text $left_frame_R.editor_lines	\
			-font $defaultFont_bold	\
			-width 0		\
			-bd 0			\
			-highlightthickness 0	\
			-exportselection 0	\
			-bg $lineNumbers_bg	\
			-fg $lineNumbers_fg	\
			-state normal		\
			-takefocus 0		\
			-cursor hand2		\
			-relief flat		\
		]
		$lineNumbers delete 1.0 end
		$lineNumbers insert end {1}
		$lineNumbers configure -state disabled
		$lineNumbers tag configure right -justify right
		$lineNumbers tag configure center -justify center
		$lineNumbers tag raise center right
		setStatusTip -widget $lineNumbers \
			-text [mc "Line numbers - click to add/remove breakpoint"]

		# Create poup menu for "Line numbers"
		set LN_menu $lineNumbers.editor_lines_menu

		# Create "Editor"
		frame $top_frame.f -bd 0 -bg $normal_text_bg -cursor xterm

		set tab_width_un [expr {$tab_width * [font measure $defaultFont_bold 0]}]
		set editor [text $top_frame.f.editor			\
			-bg $normal_text_bg				\
			-font $defaultFont_bold				\
			-undo 1 -exportselection 1			\
			-wrap word					\
			-maxundo 0					\
			-selectborderwidth 1				\
			-bd 0 -relief flat				\
			-tabstyle wordprocessor				\
			-tabs [list $tab_width_un left]			\
		]
		bind $top_frame.f <Button-1> "$this click_under_editor %x %y; break"
		bind $top_frame.f <Button-4> "$this scroll scroll -3 units; break"
		bind $top_frame.f <Button-5> "$this scroll scroll +3 units; break"
		# Create scrollbar
		set scrollbar [ttk::scrollbar		\
			$top_frame.editor_scrollbar	\
			-orient vertical		\
			-command "$this scroll_0"	\
		]

		# Set new font attributes
		set defaultCharWidth [font measure $defaultFont_bold -displayof $editor { }]
		set defaultCharHeight [font metrics $defaultFont_bold -displayof $editor -linespace]

		## Pack that all into mainframe
		 # Parts of Left frame
		pack $lineNumbers -fill none -expand 1 -side right -anchor n
		pack $iconBorder -fill none -expand 1 -side left -anchor n
		pack [frame $left_frame.editor_redutant_frame] -side left
		pack $left_frame_L -side left -fill y
		pack $left_frame_R -side right -fill y
		 # Parts of Top frame
		pack $left_frame -side left -fill y -expand 0
		pack $scrollbar -fill y -expand 0 -side right
		pack $top_frame.f -fill both -expand 1 -side left
		pack $editor -fill x -expand 1 -side left -anchor nw
		 # Parts of Bottom frame
		pack $statusbar -side bottom -fill x
		 # Bottom and Top frame$ins_mode_lbl
		pack $bottom_frame -side bottom -fill x
		pack $top_frame -side top -fill both -expand 1

		## Create statusbar
		set stat_menu		$statusbar.popup_menu
		set status_left		[frame $statusbar.editor_status_left -bg #DDDDDD]
		set status_middle	[frame $statusbar.editor_status_middle -width 16 -bg #DDDDDD]
		set status_right	[frame $statusbar.editor_status_right -bg #DDDDDD]
		set ins_mode_lbl	[Label $statusbar.ins_mode_lbl	\
			-text [mc "INS"] -fg #000000 -pady 0		\
			-bg #DDDDDD -cursor hand2			\
			-helptext [mc "Insertion mode"]			\
			-font $statusBarBoldFont			\
		]
		set sel_mode_lbl	[Label $statusbar.sel_mode_lbl	\
			-text [mc "NORM"] -fg #000000 -pady 0		\
			-bg #DDDDDD -cursor hand2			\
			-helptext [mc "Selection mode"]			\
			-font $statusBarBoldFont -width 7		\
		]
		setStatusTip -widget $sel_mode_lbl -text [mc "Selection mode -- BLK == block; NORM == normal"]
		bind $sel_mode_lbl <Button-1> "$this switch_sel_mode"

		pack $status_left	-side left -padx 10
		pack $status_middle	-side left
		pack $ins_mode_lbl	-side left -padx 5
		pack $sel_mode_lbl	-side left -padx 5 -pady 3
		pack $status_right	-side right -fill x -padx 10

		# Frame for "Line: x Col: x Total: x"
		set Sbar_CRT_frame [frame $status_left.sbar_crt_frame -bg #DDDDDD]
		# Labels "Line:"
		pack [label $Sbar_CRT_frame.sbar_row_lbl	\
			-text [mc "Line:"] -fg {#444444}	\
			-bg #DDDDDD 				\
			-font $statusBarFont -pady 0		\
		] -side left -pady 0
		set Sbar_row [label $Sbar_CRT_frame.sbar_row_val	\
			-fg {#0000AA} -font $statusBarBoldFont -pady 0	\
			-bg #DDDDDD -anchor e -bd 1			\
		]
		pack $Sbar_row -side left -pady 0
		# Labels "Column:"
		pack [label $Sbar_CRT_frame.sbar_col_lbl	\
			-text [mc " Column:"] -fg {#444444}	\
			-bg #DDDDDD				\
			-font $statusBarFont -pady 0		\
		] -side left -pady 0
		set Sbar_col	[label $Sbar_CRT_frame.sbar_col_val	\
			-fg {#0000AA} -font $statusBarBoldFont -pady 0	\
			-bg #DDDDDD -anchor e				\
		]
		pack $Sbar_col -side left -pady 0
		# Labels "Total:"
		pack [label $Sbar_CRT_frame.sbar_total_lbl	\
			-text [mc " Total:"] -fg {#444444}	\
			-bg #DDDDDD				\
			-font $statusBarFont -pady 0		\
		] -side left -pady 0
		set Sbar_total	[label $Sbar_CRT_frame.sbar_total_val	\
			-fg {#006600} -font $statusBarBoldFont -pady 0	\
			-bg #DDDDDD -anchor e				\
		]
		pack $Sbar_total -side left -pady 0
		# Image label: Lock/Unlock file
		set Sbar_lock_file [ttk::button $status_left.editor_status_left_lock	\
			-style Editor_DarkBg.TButton					\
			-command "$this invert_lock"					\
		]
		set_lock $auto_switching_lock
		# Label: "Simulator mode"
		set Sbar_sim_mode [Label $status_left.editor_status_left_l0	\
			-font $statusBarBoldFont		\
			-fg #DD0000 -bg #DDDDDD			\
			-helptext [mc "Editor status bar"]	\
			-padx 5 -pady 0				\
			-text [mc "Simulator mode    "]		\
		]
		# Label: "Simulator mode"
		set Sbar_ssim_mode [Label $status_left.editor_status_left_l2	\
			-font $statusBarBoldFont		\
			-fg #555555 -bg #DDDDDD			\
			-helptext [mc "Editor status bar"]	\
			-padx 5 -pady 0				\
			-text [mc "Starting simulator"]		\
		]
		# Label: "Editor disabled"
		set Sbar_dis_mode [Label $status_left.editor_status_left_l1	\
			-font $statusBarBoldFont		\
			-fg #3333DD -bg #DDDDDD			\
			-helptext [mc "Editor status bar"]	\
			-padx 5 -pady 0				\
			-text [mc "Editor disabled"]		\
		]
		set Sbar_image [Label $status_middle.editor_status_middle_l	\
			-bg #DDDDDD	\
			-pady 0		\
			-cursor hand2	\
		]
		bind $Sbar_image <Button-1>	"$this save"
		bind $Sbar_image <Double-1>	"$this save"
		setStatusTip -widget $Sbar_image \
			-text [mc "File has been modified, click to save"]

		pack $Sbar_CRT_frame

		set Sbar_fileName [Label $status_right.editor_status_right_l	\
			-text $filename			\
			-helptext $filename		\
			-font $statusBarBoldFont	\
			-bg #DDDDDD			\
		]
		pack $Sbar_fileName -side left
		setStatusTip -widget $Sbar_fileName \
			-text [mc "Name of the current file or \"untitled\" if the file has not yet been saved under any name"]

		set Sbar_prog_lang [Label $status_right.sbar_prog_lang	\
			-helptext [mc "File type\n  C/H\tC source / header\n  ASM\tAssembly language\n  LST\tCode listing\n  ASX\tASX8051 assembler"]	\
			-font $statusBarBoldFont	\
			-bg #DDDDDD			\
		]
		adjust_sbar_to_prog_lang
		pack $Sbar_prog_lang -side right -padx 5
		setStatusTip -widget $Sbar_prog_lang -text [mc "File type"]

		# Set status bar event bindings
		bind $statusbar <ButtonRelease-3> "$this statusbar_popup_menu $editor %X %Y; break"
		foreach widget [winfo children $statusbar] {
			bind $widget <ButtonRelease-3> "$this statusbar_popup_menu $editor %X %Y; break"
			foreach wdg [winfo children $widget] {
				bind $wdg <ButtonRelease-3> "$this statusbar_popup_menu $editor %X %Y; break"
				foreach w [winfo children $wdg] {
					bind $w <ButtonRelease-3> "$this statusbar_popup_menu $editor %X %Y; break"
				}
			}
		}

		# Create text tags
		$editor tag configure tag_wrong_spelling -underline 1
		if {$create_tags} {
			create_highlighting_tags
		}
		define_line_markers
		$editor tag configure c_lang_var
		$editor tag configure c_lang_func
		$editor tag raise sel tag_current_line
		$editor tag raise sel tag_bookmark
		$editor tag raise sel tag_simulator_curr
		$editor tag raise sel tag_trailing_space
		$editor tag raise tag_error_line	tag_bookmark
		$editor tag raise tag_error_line	tag_trailing_space
		$editor tag raise tag_current_line	tag_bookmark
		$editor tag raise tag_current_line	tag_error_line
		$editor tag raise tag_trailing_space	tag_current_line
		$editor tag raise tag_simulator_curr	tag_current_line
		$editor tag raise tag_simulator_curr	tag_error_line
		$editor tag raise tag_simulator_curr	tag_bookmark
		$editor tag raise tag_simulator_curr	tag_trailing_space

		# Insert the given data
		if {$data != {}} {
			$editor insert end $data
			$editor edit modified 0
			$editor edit reset
		}

		# Reset status modified
		set modified 0

		## Set unredefinable event bindings for editor
		 # Set priorities
		bindtags $editor [list $editor . all]
		 # Special keys
		for {set i 1} {$i < 21} {incr i} {
			bind $editor "<Key-F$i>" {continue}
		}
		bind $editor <Control-Key>	{continue}
		bind $editor <Alt-Key>		{continue}
		 # Keep default
		foreach key {
				<ButtonRelease-1>	<B1-Enter>	<B1-Leave>
				<B2-Motion>		<MouseWheel>
			} {
				bind $editor $key [bind Text $key]
		}

		 # Scroll wheel
		bind $editor <Button-4> "$this scroll scroll -3 units; break"
		bind $editor <Button-5> "$this scroll scroll +3 units; break"

		bind $editor <XF86Back>		{::X::__prev_editor}
		bind $editor <XF86Forward>	{::X::__next_editor}
		bind $editor <XF86Reload>	{::X::__reload}

		 # Other
		foreach key {
				<Double-Shift-Button-1>		<Shift-Button-1>
				<Triple-Shift-Button-1>		<Control-Button-1>
				<Control-Shift-Key-Right>	<Control-Shift-Key-Left>
				<Control-Key-Right>		<Control-Key-Left>
				<Shift-Key-Next>		<Shift-Key-Prior>
				<Shift-Key-Right>		<Shift-Key-Left>
				<Shift-Key-End>			<Key-End>
				<Control-Key-T>
			} {
				bind $editor $key "
					[bind Text $key]
					$this rightPanel_adjust \[expr {int(\[%W index insert\])}\]
					$this recalc_status_counter {}
					$this resetUpDownIndex
					break"
		}
		bind $editor <Shift-Button-5> "
			$this scroll scroll +30 lines
			break
		"
		bind $editor <Shift-Button-4> "
			$this scroll scroll -30 lines
			break
		"
		bind $editor <Double-Button-1> "
			if {\[string is alnum -strict \[%W get insert-1c insert\]\]} {
				[bind Text <Double-Button-1>]
			}

			$this rightPanel_adjust \[expr {int(\[%W index insert\])}\]
			$this recalc_status_counter {}
			$this resetUpDownIndex
			break"
		bind $editor <Shift-Key-Down>	"
			if {\[catch {$this shift_down}\]} {
				[bind Text <Shift-Key-Down>]
				$this rightPanel_adjust \[expr {int(\[%W index insert\])}\]
				$this recalc_status_counter {}
			}
			break"
		bind $editor <Shift-Key-Up>	"
			if {\[catch {$this shift_up}\]} {
				[bind Text <Shift-Key-Up>]
				$this rightPanel_adjust \[expr {int(\[%W index insert\])}\]
				$this recalc_status_counter {}
			}
			break"
		bind $editor <Control-Shift-Up>	"$this control_shift_updown 1; break"
		bind $editor <Control-Shift-Down> "$this control_shift_updown 0; break"
		bind $editor <Control-Insert>	"$this copy; break"
		bind $editor <Shift-Insert>	"$this paste; break"
		bind $editor <Shift-Delete>	"$this cut; break"
		bind $editor <Control-Key-Down>	"$this control_down; break"
		bind $editor <Control-Key-Up>	"$this control_up; break"
		bind $editor <Key-Down>		"$this down; break"
		bind $editor <Key-Up>		"$this up; break"
		bind $editor <Control-Key-Home>	"$this control_home; break"
		bind $editor <Control-Key-End>	"$this control_end; break"
		bind $editor <Key-Home>		"$this home_press; break"
		bind $editor <Shift-Key-Home>	"$this shift_home; break"
		bind $editor <Key-Insert>	"$this switch_ins_ovr; break"
		bind $editor <Key-Tab>		"$this tab_press; break"
		if {!$::MICROSOFT_WINDOWS} {
			bind $editor <Key-ISO_Left_Tab>	"$this unindent; break"
		}
		bind $editor <Button-2>		"$this paste 1 %x %y; break"
		bind $editor <<Paste>>		"$this paste; break"
		bind $editor <<Cut>>		"$this cut; break"
		bind $editor <<Copy>>		"$this copy; break"
		bind $editor <Control-Key-V>	"$this paste; break"
		bind $editor <Control-Key-X>	"$this cut; break"
		bind $editor <Control-Key-C>	"$this copy; break"
		bind $editor <<Undo>>		"$this undo; break"
		bind $editor <<Redo>>		"$this redo; break"
		bind $editor <Shift-Return>	"$this shift_enter; break"
		bind $editor <Shift-KP_Enter>	"$this shift_enter; break"
		bind $editor <Return>		"$this enter; break"
		bind $editor <KP_Enter>		"$this enter; break"
		bind $editor <Key>		"$this Key %A %K; break"
		bind $editor <KeyRelease>	"$this KeyRelease %K; break"
		bind $editor <ButtonRelease-3>	"$this popupMenu %X %Y %x %y; break"
		bind $editor <Key-Menu>		"$this Key_Menu; break"
		bind $editor <Key-Escape>	"$this key_escape"
		bind $editor <Control-Key-y>	"$this delete_current_line; break"
		bind $editor <Key-BackSpace>	"$this key_backspace; break"
		bind $editor <Key-Delete>	"$this key_delete; break"
		bind $editor <Key-Prior> "
			%W mark set insert {insert-30l}
			$this scroll scroll -30 lines
			$this resetUpDownIndex
			$this rightPanel_adjust \[expr {int(\[%W index insert\])}\]
			$this recalc_status_counter {}
			break"
		bind $editor <Key-Next> "
			%W mark set insert {insert+30l}
			$this scroll scroll +30 lines
			$this resetUpDownIndex
			$this rightPanel_adjust \[expr {int(\[%W index insert\])}\]
			$this recalc_status_counter {}
			break"
		bind $editor <Control-Key-Next> "break"
		bind $editor <Control-Key-Prior> "break"
		bind $editor <Key-Left> "
			[bind Text <Key-Left>]
			$this resetUpDownIndex
			$this recalc_status_counter {}
			$this rightPanel_adjust \[expr {int(\[%W index insert\])}\]
			break"
		bind $editor <Key-Right> "
			[bind Text <Key-Right>]
			$this resetUpDownIndex
			$this recalc_status_counter {}
			$this rightPanel_adjust \[expr {int(\[%W index insert\])}\]
			break"
		bind $editor <Control-Key-t> "
			set ln \[expr {int(\[$editor index insert\])}\]

			$this autocompletion_maybe_important_change \$ln.0 \$ln.0
			[bind Text <Control-Key-t>]
			$this resetUpDownIndex
			$this parse \$ln
			$this manage_autocompletion_list \$ln
			update
			break"
		bind $editor <<PasteSelection>> "
			[bind Text <<PasteSelection>>]
			$this resetUpDownIndex
			$this recalc_left_frame
			$this parse \[expr {int(\[$editor index insert\])}\]
			catch {$editor tag remove sel sel.first sel.last}
			update
			break"
		bind $editor <Button-1> "
			# Check spelling on the line which we are now leaving
			$this spellcheck_check_all \[expr {int(\[%W index insert\])}\]

			[bind Text <Button-1>]
			$this rightPanel_adjust \[expr {int(\[%W index insert\])}\]
			$this resetUpDownIndex
			$this recalc_status_counter
			focus -force $editor
			break"
		bind $editor <B1-Motion> "
			[bind Text <B1-Motion>]
			$this rightPanel_adjust \[expr {int(\[%W index @%x,%y\])}\]
			$this resetUpDownIndex
			$this recalc_status_counter
			break"
		bind $editor <<Selection>> "$this editor_selection; break"


		# Set event bindings for editor command line
		bind $cmd_line <Key-Escape> "
			\${::X::actualProject} cmd_line_off
			pack forget $cmd_line
			catch {$this cmd_line_menu_close_now}
			focus $editor
			update
			break"
		for {set i 1} {$i < 21} {incr i} {
			bind $cmd_line <F$i>		{continue}
			bind $cmd_line <Control-F$i>	{continue}
		}
		bind $cmd_line <Control-Key>	{continue}
		bind $cmd_line <Alt-Key>	{continue}
		bind $cmd_line <Control-a>	{%W tag add sel {insert linestart} {insert lineend}; break}
		bind $cmd_line <Key-Return>	"$this cmd_line_enter;		break"
		bind $cmd_line <Key-KP_Enter>	"$this cmd_line_enter;		break"
		bind $cmd_line <KeyPress>	"$this cmd_line_key_press %A;	break"
		bind $cmd_line <Delete>		"$this cmd_line_key Delete;	break"
		bind $cmd_line <BackSpace>	"$this cmd_line_key BackSpace;	break"
		bind $cmd_line <Home>		"$this cmd_line_key Home;	break"
		bind $cmd_line <End>		"$this cmd_line_key End;	break"
		bind $cmd_line <Left>		"$this cmd_line_key Left;	break"
		bind $cmd_line <Right>		"$this cmd_line_key Right;	break"
		bind $cmd_line <Down>		"if {\[$this cmd_line_down\]} {break}"
		bind $cmd_line <Shift-Left>	"if {!\[$this cmd_line_key SLeft\]} {break}"
		bind $cmd_line <Shift-Right>	"if {!\[$this cmd_line_key SRight\]} {break}"
		foreach keysym {Shift-Home Shift-End Up} {
			bind $cmd_line <$keysym> "[bind Text <$keysym>];break"
		}
		foreach keysym {Undo Redo Cut Copy Paste} {
			bind $cmd_line <<$keysym>> "[bind Text <<$keysym>>];break"
		}

		# Create bindings for defined key shortcuts
		shortcuts_reevaluate

		# Create editor popup menu
		set menu $editor.editor_menu
		makePopupMenu

		bind $editor <Configure> "$this Configure"
		bind $editor <FocusIn> "$parentObject filelist_editor_selected $this"
		bind $cmd_line <FocusIn> "$parentObject filelist_editor_selected $this"

		# Set event bindings for "Line numbers"
		bind $lineNumbers <Button-1> "
			$parentObject filelist_editor_selected $this
			focus -force $editor
			$this lineNumbers_click %x %y
			break"
		bind $lineNumbers <ButtonRelease-3> "
			$parentObject filelist_editor_selected $this
			focus -force $editor
			$this lineNumbers_popup_menu %X %Y %x %y
			break"
		bind $lineNumbers <Button-4> "$this scroll scroll -20 units; break"
		bind $lineNumbers <Button-5> "$this scroll scroll +20 units; break"
		bindtags $lineNumbers [list $lineNumbers . all]

		# Set event bindings for "Icon border"
		bind $iconBorder <Button-1> "
			$parentObject filelist_editor_selected $this
			focus -force $editor
			$this iconBorder_click %x %y
			break"
		bind $iconBorder <ButtonRelease-3> "
			$parentObject filelist_editor_selected $this
			focus -force $editor
			$this iconBorder_popup_menu %X %Y %x %y
			break"
		bind $iconBorder <Button-4> "$this scroll scroll -20 units; break"
		bind $iconBorder <Button-5> "$this scroll scroll +20 units; break"
		bindtags $iconBorder [list $iconBorder . all]

		# Finalize initialization
		$editor configure -yscrollcommand "$this scrollSet"
		set object_initialized 1
		change_RO_MODE $ro_mode

		# Start watching for changes in the file
		FSnotifications::watch $fullFileName [list ::Editor::file_change_notif $this]
	}

	## Object destructor
	destructor {
		if {$editor_to_use} {
			kill_childern
		} else {
			# Stop autosave timer
			catch {
				after cancel $autosave_timer
			}
			# Cancel highlight dialog timer
			if {$finishigh_hg_dlg_tmr != {}} {
				after cancel $finishigh_hg_dlg_tmr
			}
			# Unregister statusbar tips
			menu_Sbar_remove $menu
			menu_Sbar_remove $IB_menu
			menu_Sbar_remove $LN_menu
		}

		# Destroy main frame
		destroy $ed_sc_frame
	}

	## Adjust number of lines (height) in the editor text widget
	 # This function ensures that the editor text widget height conforms to
	 #+ height of its scrollbar / line_height
	 # @return void
	private method adjust_editor_height {} {
		set editor_height [$editor cget -height]
		set nh [expr {int([winfo height $scrollbar] / $defaultCharHeight)}]
		if {$nh == $editor_height} {
			return
		}
		$editor configure -height $nh
		$lineNumbers configure -height $nh
		$iconBorder configure -height $nh
	}

	## Refresh color setting (excluding highlightind)
	 # @return void
	public method change_colors {} {
		if {$editor_to_use} {return}

		$lineNumbers	configure -bg $lineNumbers_bg -fg $lineNumbers_fg
		$left_frame_R	configure -bg $lineNumbers_bg

		$iconBorder	configure -bg $iconBorder_bg
		$left_frame_L	configure -bg $iconBorder_bg

		$editor		configure -bg $normal_text_bg
		$top_frame.f	configure -bg $normal_text_bg
	}

	## Refresh font setting (excluding highlightind)
	 # @return void
	public method refresh_font_settings {} {
		if {$editor_to_use} {return}

		# Set new font specification variables
		set defaultCharHeight_org $defaultCharHeight
		set defaultFont	[font create -size -$fontSize -family $fontFamily]
		set bold_font [font create -size -$fontSize -family $fontFamily -weight {bold}]
		set italic_font [font create -size -$fontSize -family $fontFamily -slant {italic}]
		if {[font metrics $bold_font -displayof $editor -linespace] < [font metrics $italic_font -displayof $editor -linespace]} {
			set defaultFont_bold $italic_font
		} else {
			set defaultFont_bold $bold_font
		}
		set defaultCharWidth [font measure $defaultFont_bold -displayof $editor { }]
		set defaultCharHeight [font metrics $defaultFont_bold -displayof $editor -linespace]

		# Remove all text tags
		foreach tag [$editor tag names] {
			if {[lsearch {
					sel		tag_current_line	tag_bookmark
					tag_breakpoint	tag_breakpoint_INVALID	tag_simulator_curr
					tag_error_line
				} $tag] != -1
			} then {
				break
			}
			$editor tag remove $tag 1.0 end
		}
		# Change fonts and tab width
		set tab_width_un [expr {$tab_width * [font measure $defaultFont_bold 0]}]
		$iconBorder	configure -font $defaultFont_bold
		$lineNumbers	configure -font $defaultFont_bold
		$editor		configure -font $defaultFont_bold -tabs [list $tab_width_un left]

		$lineNumbers tag configure right -justify right
		$lineNumbers tag configure center -justify center
		$lineNumbers tag raise center right
		$iconBorder tag configure center -justify center

		# Enable writing to the left border
		$iconBorder configure -state normal
		# Adjust bookmark images
		if {$defaultCharHeight_org != $defaultCharHeight} {
			set indexes {}
			if {$defaultCharHeight_org < 9} {
				set idx 1.0
				set idx_prev $idx
				while {1} {
					set idx [$iconBorder search -exact -- {*} $idx]
					if {$idx == {}} {break}
					if {[$iconBorder compare $idx_prev >= $idx]} {break}
					lappend indexes $idx
					set idx_prev $idx
					set idx [$iconBorder index "$idx+1c"]
				}
			} else {
				foreach img [$iconBorder image names] {
					lappend indexes [$iconBorder index $img]
				}
			}
			if {$defaultCharHeight < 9} {
				foreach idx $indexes {
					$iconBorder delete $idx "$idx+1c"
					$iconBorder insert $idx {*}
				}
			} else {
				if {$defaultCharHeight < 15} {
					set image {dot}
				} else {
					set image {bookmark}
				}
				foreach idx $indexes {
					$iconBorder delete $idx "$idx+1c"
					$iconBorder image create $idx		\
						-image ::ICONS::16::$image	\
						-align center
				}
			}
		}
		# Disable writing to the left border
		$iconBorder configure -state disabled
		# Reset line wrap settings
		set highlighted_lines [string repeat 0 [string bytelength $highlighted_lines]]
		update idletasks
		highlight_visible_area

		# Adjust editor height
		adjust_editor_height
	}

	## Adjust Insert/Overwrite label on status bar
	 # @return void
	private method adjust_INS_OVR_label {} {
		if {$ins_ovr_mode} {
			$ins_mode_lbl configure -text [mc "INS"] -fg #000000
			$editor configure -blockcursor 0
		} else {
			$ins_mode_lbl configure -text [mc "OVR"] -fg #FF0000
			$editor configure -blockcursor 1
		}
	}

	## This function should be called after each column change
	 # -- Close popup completion menu
	 # @return void
	public method resetUpDownIndex {} {
		set lastUpDownIndex 0
	}

	## Restore tags "Bookmark" and "Error" on the given line
	 # @parm Int line - line number
	 # @return void
	private method restore_line_markers {line} {
		# Restore bookmark
		if {[lindex $bookmarks $line] == 1} {
			$editor tag add tag_bookmark $line.0 "$line.0+1l"
		}
		# Restore tag error
		if {
			$prog_language != 2 &&
			[llength [$editor tag nextrange tag_error $line.0 "$line.0 lineend"]]
		} then {
			$editor tag add tag_error_line $line.0 "$line.0+1l"
		}
	}

	## Determinate whether editor text has been modified
	 # and adjust internal variables
	 # @parm bool force	- 1: "I'm sure it has been modified !"
	 #			  0: "discover it automatically"
	 # @return bool - a new modified flag or {}
	public method recalc_status_modified {force} {

		# Modified
		if {[$editor edit modified] || $force} {

			# Adjust editor status bar
			$Sbar_image configure	\
				-image ::ICONS::16::filesave	\
				-helptext [mc "File has been modified, click to save"]
			pack $Sbar_image -side left

			# Set modified flag
			set modified 1

			# Start autosave timer
			if {$autosave} {
				catch {
					after cancel $autosave_timer
				}
				set autosave_timer [after [expr {$autosave * 60000}] "catch {$this save}"]
			}

		# Not modifed
		} else {
			# Adjust editor status bar
			pack forget $Sbar_image

			# Set modified flag
			set modified 0

			# Stop autosave timer
			catch {
				after cancel $autosave_timer
			}
		}

		::X::adjust_title

		# Return modified flag
		return $modified
	}

	## Call ::configDialogues::mkDialog $args
	 # @return void
	public method configDialogues_mkDialog args {
		::configDialogues::editor::mkDialog $args
	}

	## Recalculate variables related to bookmarks, line numbers and list of highlighted lines
	 # @parm Bool force=1	- perform recalcutaion even if length of text wasn't changed
	 # @return bool - 0: failed; 1: successful
	public method recalc_left_frame {{force 0}} {
		if {$editor_to_use} {return}

		# Determinate editor lines count and End index
		set End [$editor index end]
		set Tlines [expr {int($End)}]

		# Current line number -> Actline
		set insert [$editor index insert]
		set Actline [expr {int($insert)}]

		# Return if lines count has not been changed
		if {!$force && $lastEnd == $Tlines} {
			return 0
		}
		incr Tlines -1

		# Determinate iconBorder lines count - 1
		set Ilines [expr {int([$iconBorder index end]) - $number_of_wraps - 1}]

		# Remove wrap markers from line numbers
		if {$number_of_wraps && ($Ilines != $Tlines)} {
			$lineNumbers configure -state normal
			set remaining $number_of_wraps
			set i 1
			foreach wrap $map_of_wraped_lines {
				if {$wrap > 0} {
					$lineNumbers delete $i.0 $i.0+${wrap}l
					incr remaining -$wrap
				}
				if {!$remaining} {break}
				incr i
			}
		}

		## Some lines have been removed
		if {$Ilines > $Tlines} {
			# Determinate how many lines should be removed
			regexp {\d+$} $insert cur_line_col
			if {$cur_line_col != 0} {
				set Actline_m1 $Actline
				incr Actline
				restore_line_markers $Actline_m1
			}

			set diff $Actline
			incr diff -$Tlines
			incr diff $Ilines

			# Delete bookmark icon(s) from left bar
			$iconBorder configure -state normal
			set Actline_tmp $Actline
			set diff_tmp $diff
			if {$number_of_wraps} {
				set remaining $number_of_wraps
				for {set i 1} {$i < $diff} {incr i} {
					set wrap [lindex $map_of_wraped_lines $i]
					if {$wrap < 0} {
						set wrap 0
					}
					incr diff_tmp $wrap
					if {$i < $Actline} {
						incr Actline_tmp $wrap
					}
					incr remaining -$wrap
					if {!$remaining} {break}
				}
			}
			$iconBorder delete $Actline_tmp.0 $diff_tmp.0
			$iconBorder configure -state disabled

			# Unregister bookmarks for deletion
			incr diff -1
			set bookmarks [lreplace $bookmarks $Actline $diff]
			set breakpoints [lreplace $breakpoints $Actline $diff]
			for {set i $Actline} {$i <= $diff} {incr i} {
				set number_of_wraps [expr {$number_of_wraps - [lindex $map_of_wraped_lines $i]}]
			}
			set map_of_wraped_lines [lreplace $map_of_wraped_lines $Actline $diff]
			set highlighted_lines [string replace $highlighted_lines $Actline $diff]

			# Adjust the right panel
			$parentObject rightPanel_remove_bookmarks $Actline $diff
			$parentObject rightPanel_remove_breakpoints $Actline $diff
			$parentObject rightPanel_shift_symbols $Actline [expr {$Actline - $diff - 1}]

			# rewrite breakpoints
			rewrite_breakpoint_tags 1

		## Some lines have been added
		} elseif {$Ilines < $Tlines} {
			# Determinate how many lines should be added
			set diff [expr {$Tlines - $Ilines}]

			set ins [string repeat "\n" $diff]
			set BMStr [string range [string repeat {0 } $diff] 0 end-1]
			set insIndex $Actline
			incr insIndex -$diff
			if {$insIndex == 0} {incr insIndex}
			set insLineEnd [$editor index "$insIndex.0 lineend"]
			regexp {\d+$} $insLineEnd ins_line_col

			set insIndex_1 $insIndex
			incr insIndex_1

			if {$ins_line_col != 0} {
				# Remove tag "Bookmark"
				if {[lindex $bookmarks $insIndex] == 1} {
					$editor tag remove tag_bookmark $insIndex.0 [expr {$Actline + 1}].0
				}

				# Adjust insert index
				incr insIndex
				incr insIndex_1

				# Prepare lists
				if {[string length $highlighted_lines] == $insIndex} {
					append highlighted_lines 0
				}
				if {[llength $bookmarks] == $insIndex} {
					lappend bookmarks 0
				}
				if {[llength $breakpoints] == $insIndex} {
					lappend breakpoints 0
				}
				if {[llength $map_of_wraped_lines] == $insIndex} {
					lappend map_of_wraped_lines 0
				}

				# Adjust list of highlighted lines
				set highlighted_lines [string replace $highlighted_lines	\
					[expr {$insIndex - 1}] [expr {$insIndex - 1}]		\
					[string repeat 0 [expr {$diff + 1}]]]

				# Adjust bookmark and breakpoint lists
				set map_of_wraped_lines [linsert $map_of_wraped_lines $insIndex $BMStr]
				set bookmarks [linsert $bookmarks $insIndex $BMStr]
				set breakpoints [linsert $breakpoints $insIndex $BMStr]
				regsub -all {[\{\}]} $map_of_wraped_lines {} map_of_wraped_lines
				regsub -all {[\{\}]} $bookmarks {} bookmarks
				regsub -all {[\{\}]} $breakpoints {} breakpoints

				# Shift bookmarks and breakpoints on the right panel
				$parentObject rightPanel_shift_bookmarks $insIndex $diff
				$parentObject rightPanel_shift_breakpoints $insIndex $diff
				$parentObject rightPanel_shift_symbols $insIndex $diff

				if {[lindex $bookmarks [expr {$insIndex - 1}]] == 1} {
					$editor tag add tag_bookmark [expr {$insIndex - 1}].0 $insIndex.0
				}

			} else {
				# Adjust list of lighted lines
				set highlighted_lines [string replace		\
					$highlighted_lines $insIndex $insIndex	\
					[string repeat 0 [expr {$diff + 1}]]]

				# Adjust bookmark and breakpoint lists
				set map_of_wraped_lines [linsert $map_of_wraped_lines $insIndex $BMStr]
				set bookmarks [linsert $bookmarks $insIndex $BMStr]
				set breakpoints [linsert $breakpoints $insIndex $BMStr]
				regsub -all {[\{\}]} $map_of_wraped_lines {} map_of_wraped_lines
				regsub -all {[\{\}]} $bookmarks {} bookmarks
				regsub -all {[\{\}]} $breakpoints {} breakpoints

				$parentObject rightPanel_shift_bookmarks $insIndex $diff
				$parentObject rightPanel_shift_breakpoints $insIndex $diff
				$parentObject rightPanel_shift_symbols $insIndex $diff
			}

			$iconBorder configure -state normal
			if {$number_of_wraps} {
				set insIndex_tmp $insIndex
				for {set i 1} {$i < $insIndex_tmp} {incr i} {
					incr insIndex [lindex $map_of_wraped_lines $i]
				}
			}
			$iconBorder insert $insIndex.0 $ins
			$iconBorder configure -state disabled

			# rewrite breakpoints
			rewrite_breakpoint_tags 1
		}

		## Recalculate Line Numbers
		# Prepare Line Numbers
		if {$Tlines != [expr {int([$lineNumbers index end]) - 1}]} {
			# Enable the widget
			$lineNumbers configure -state normal
		}

		# Determinate LineNumbers lines count - 1
		set Llines [expr {int([$lineNumbers index end])}]
		incr Llines -1

		if {$Llines > $Tlines} {	;# too many lines -> remove some ones
			$lineNumbers delete $End end

		} elseif {$Llines < $Tlines} {	;# not enough lines -> add some ones
			# Create string to insert to Line Numbers
			set ins {}
			for {set i [expr {$Llines + 1}]} {$i <= $Tlines} {incr i} {
				append ins "\n$i"
			}

			# Insert it at the end of widget and adjust widget width
			$lineNumbers insert end $ins
		}

		# Finalize
		if {$Llines != $Tlines} {
			# Adjust widget width
			$lineNumbers configure -width [string length [expr {int([$lineNumbers index end]) - 1}]]
			# Restore wrap markers
			if {$number_of_wraps} {
				set remaining $number_of_wraps
				for {set i [expr {[llength $map_of_wraped_lines] - 1}]} {$i > 0} {incr i -1} {
					set wrap [lindex $map_of_wraped_lines $i]
					if {$wrap > 0} {
						set ln [expr {$i + 1}]
						$lineNumbers insert $ln.0 [string repeat "$wrap_char\n" $wrap]
						$lineNumbers tag add center $ln.0 [expr {$ln + $wrap}].0
						incr remaining -$wrap
					}
					if {!$remaining} {break}
				}
			}
			# Disable Line Numbers
			$lineNumbers configure -state disabled
		}
		scrollSet [lindex [$editor yview] 0] [lindex [$editor yview] 1]
		$lineNumbers tag add right 1.0 end
		$iconBorder tag add center 1.0 end

		# Parse the current line
		parse $Actline
		highlight_visible_area

		# Save last lines count
		set lastEnd [expr {int($End)}]
		# done ...
		return 1
	}

	## Select appropriate item in right panel lists (bookmarks and breapoints)
	 # @parm Int lineNumber - current line
	 # @return void
	public method rightPanel_adjust {lineNumber} {

		# Adjust list of bookmarks
		if {[lindex $bookmarks $lineNumber] == 1} {
			$parentObject rightPanel_bm_select $lineNumber
		} else {
			$parentObject rightPanel_bm_unselect
		}

		# Adjust list of breakpoints
		if {[lindex $breakpoints $lineNumber] == 1} {
			$parentObject rightPanel_bp_select $lineNumber
		} else {
			$parentObject rightPanel_bp_unselect
		}

		# Adjust list of symbols
		$parentObject rightPanel_sm_select $lineNumber
	}

	## Line wrapping manager - variant 2
	 # Adjust map of wrapped lines and left border to wrap of the specified line
	 # This function using function 'get_count_of_lines' (slow)
	 # @parm Int line_number - Line number
	 # @return Bool - result
	private method wrap_mgr2 {line_number} {
		# Check if editor is properly initialized
		if {$editor_width <= 0 || $map_of_wraped_lines == {}} {return 1}

		# Not empty line
		if {[$editor compare [$editor index "$line_number.0 linestart"] != "$line_number.0 lineend"]} {
			set new_wrap [get_count_of_lines $line_number.0 "$line_number.0 lineend"]
			incr new_wrap -1
		# Empty line
		} else {
			set new_wrap 0
		}

		# Determinate the current wrap factor
		set wrap [lindex $map_of_wraped_lines $line_number]
		if {$new_wrap == $wrap} {return 1}

		# Adjust map of wrapped lines
		if {$line_number >= [llength $map_of_wraped_lines]} {
			Configure
			return
		} else {
			lset map_of_wraped_lines $line_number $new_wrap
		}

		# Adjust line number
		set line_number_tmp $line_number
		for {set i 1} {$i < $line_number_tmp} {incr i} {
			incr line_number [lindex $map_of_wraped_lines $i]
		}
		incr line_number

		# Adjust left border and number of line wraps
		set scroll_in_progress 1
		$lineNumbers configure -state normal
		$iconBorder configure -state normal
		if {$new_wrap > $wrap} {
			set diff [expr {$new_wrap - $wrap}]
			incr number_of_wraps $diff
			$lineNumbers insert $line_number.0 [string repeat "$wrap_char\n" $diff]
			$iconBorder insert $line_number.0 [string repeat "\n" $diff]
			$lineNumbers tag add center $line_number.0 [expr {$line_number + $diff}].0
		} elseif {$new_wrap < $wrap} {
			set diff [expr {$wrap - $new_wrap}]
			incr number_of_wraps $diff
			$lineNumbers delete $line_number.0 $line_number.0+${diff}l
			$iconBorder delete $line_number.0 $line_number.0+${diff}l
		}
		$lineNumbers configure -state disabled
		$iconBorder configure -state disabled
		set scroll_in_progress 0

		# Success
		return 1
	}

	## Line wrapping manager - variant 1
	 # Adjust map of wrapped lines and left border to wrap of the specified line
	 # This function is using method 'dlineinfo' (fast)
	 # @parm Int line_number - Line number
	 # @return Bool - result
	private method wrap_mgr {line_number} {
		# Check if editor is properly initialized
		if {$editor_width <= 0 || $map_of_wraped_lines == {}} {return 1}

		# Deterinate current and previous wrap factor
		set new_wrap [lindex [$editor dlineinfo $line_number.0+1l] 1]
		set wrap [lindex [$editor dlineinfo $line_number.0] 1]
		if {$wrap == {} || $new_wrap == {}} {
			return 0
		}
		set new_wrap [expr {($new_wrap - $wrap) / $defaultCharHeight - 1}]
		set wrap [lindex $map_of_wraped_lines $line_number]
		if {$new_wrap == $wrap} {return 1}

		# Adjust map of wrapped lines
		if {$line_number >= [llength $map_of_wraped_lines]} {
			Configure
			return
		} else {
			lset map_of_wraped_lines $line_number $new_wrap
		}

		# Adjust line number
		set line_number_tmp $line_number
		for {set i 1} {$i < $line_number_tmp} {incr i} {
			incr line_number [lindex $map_of_wraped_lines $i]
		}
		incr line_number

		# Adjust left border
		set scroll_in_progress 1
		$lineNumbers configure -state normal
		$iconBorder configure -state normal
		if {$new_wrap > $wrap} {
			set diff [expr {$new_wrap - $wrap}]
			incr number_of_wraps $diff
			$lineNumbers insert $line_number.0 [string repeat "$wrap_char\n" $diff]
			$iconBorder insert $line_number.0 [string repeat "\n" $diff]
			$lineNumbers tag add center $line_number.0 [expr {$line_number + $diff}].0
		} elseif {$new_wrap < $wrap} {
			set diff [expr {$wrap - $new_wrap}]
			set number_of_wraps [expr {$number_of_wraps - $diff}]
			$lineNumbers delete $line_number.0 $line_number.0+${diff}l
			$iconBorder delete $line_number.0 $line_number.0+${diff}l
		}
		$lineNumbers configure -state disabled
		$iconBorder configure -state disabled
		set scroll_in_progress 0

		# Success
		return 1
	}

	## Reset map of wrapped lines and count of line wraps
	 # @return void
	public method reset_wraped_lines {} {
		set number_of_wraps 0
		set map_of_wraped_lines [string repeat {0 } [expr {int([$editor index end])}]]
		return
	}

	## Create highlight dialog
	 # @return void
	public method open_highlight_wait_dialog {} {
		# Create dialog frame
		set finishigh_hg_dlg_wdg [frame $ed_sc_frame.hg_dialog	\
			-bg {#EEEEFF} -bd 2 -relief raised		\
		]

		# Create heder label
		pack [label $finishigh_hg_dlg_wdg.label	\
			-text [mc "Finishing highlight"]\
			-bg {#EEEEFF} -fg {#0000FF}	\
		] -fill x
		# Create progress bar
		pack [ttk::progressbar $finishigh_hg_dlg_wdg.progressbar\
			-mode determinate -orient horizontal		\
			-maximum $finishigh_hg_dlg_max			\
			-variable ::Editor::finishigh_hg_dlg_const	\
		] -fill x -pady 5 -padx 5

		# Show dialog
		place $finishigh_hg_dlg_wdg			\
			-width 200 -height 45 -in $ed_sc_frame	\
			-x -100 -y -25 -relx 0.5 -rely 0.5
		raise $finishigh_hg_dlg_wdg
		grab $finishigh_hg_dlg_wdg
		update
	}

	## Close highlight dialog
	 # @return void
	private method close_highlight_wait_dialog {} {
		if {$finishigh_hg_dlg_tmr != {}} {
			after cancel $finishigh_hg_dlg_tmr
			set finishigh_hg_dlg_tmr {}
		}
		if {[winfo exists $finishigh_hg_dlg_wdg]} {
			grab release $finishigh_hg_dlg_wdg
			destroy $finishigh_hg_dlg_wdg
		}
	}

	## Perform syntax highlight for C language on specified line
	 # @return void
	private method c_syntax_highlight {lineNumber} {
		# Get highlight status of the previous line
		if {$lineNumber > 1} {
			set highlight_status [string index $highlighted_lines [expr {$lineNumber - 1}]]
			if {$highlight_status == {}} {
				set highlight_status 0
			}
		} else {
			set highlight_status 1
		}

		# Highlighted all lines before the current one
		if {!$highlight_status} {
			# determinate highlight status of previous line
			set i [string first 0 $highlighted_lines 1]
			set highlight_status [string index $highlighted_lines [expr {$i - 1}]]
			if {$highlight_status == {}} {
				set highlight_status 1
			}

			# Highlight dialog
			set finishigh_hg_dlg_const 0
			set finishigh_hg_dlg_max [expr {($lineNumber - $i) / 500}]
			if {$object_initialized && $finishigh_hg_dlg_tmr == {}} {
				set finishigh_hg_dlg_tmr [after 500 "$this open_highlight_wait_dialog"]
			}

			# Highlight preceeding lines
			for {set j 0} {$i < $lineNumber} {incr i; incr j} {
				highlight_trailing_space $i
				set highlight_status [CsyntaxHighlight::highlight $editor $i $highlight_status]
				autocompletion_c_syntax_analyze $i
				set highlighted_lines [string replace $highlighted_lines $i $i $highlight_status]

				if {$j > 500} {
					set j 0
					incr finishigh_hg_dlg_const
					update
				}
			}

			# Close highlight dialog
			if {$object_initialized} {
				close_highlight_wait_dialog
			}
		}

		# Highlight this line
		set i $lineNumber
		set last_visible_line [expr {int([lindex [$editor yview] 1] * int([$editor index end])) + 1}]

		# Highlight all line after the current one until it is not nessesary
		while {1} {
			autocompletion_maybe_important_change $i.0 $i.0
			set highlight_status_org [string index $highlighted_lines $i]
			set highlight_status [CsyntaxHighlight::highlight $editor $i $highlight_status]
			autocompletion_c_syntax_analyze $i
			if {$i == $lineNumber} {
				manage_autocompletion_list $i
			}
			set highlighted_lines	\
				[string replace $highlighted_lines $i $i $highlight_status]
			if {
				$highlight_status_org != 0	&&
				$highlight_status_org != {}	&&
				$highlight_status_org != $highlight_status
			} then {
				incr i
			} else {
				break
			}
			if {$i > $last_visible_line} {
				set highlighted_lines					\
					[string replace $highlighted_lines $i end	\
						[string repeat 0 [expr {		\
								[string length $highlighted_lines] - $i
							}]	\
						]		\
					]
				break
			}
		}
	}

	## Highlight trailing space
	 # @parm Int lineNumber - number of the target line
	 # @return void
	private method highlight_trailing_space {lineNumber} {
		$editor tag remove tag_trailing_space $lineNumber.0 [list $lineNumber.0 lineend]
		if {$hg_trailing_sp && [regexp {[\t  ]+$} [$editor get $lineNumber.0 [list $lineNumber.0 lineend]] space]} {
			$editor tag add tag_trailing_space				\
				[list $lineNumber.0 lineend]-[string length $space]c	\
				[list $lineNumber.0 lineend]
		}
	}

	## Parse given line
	 # Restore highlight, recalculate counters on status bar, adjust right panel
	 # @parm Int lineNumber		- Number of the target line
	 # @parm Bool force_spell_check	- Force spelling check
	 # @return Bool - result from wrap manager
	public method parse {lineNumber {force_spell_check 0}} {
		# Check if the given line number is valid
		if {$lineNumber >= int([$editor index end])} {
			set lineNumber [expr {int([$editor index end]) - 1}]
		}

		# Is the given line number is the current line ?
		if {int([$editor index insert]) == $lineNumber} {
			set curLine 1
		} else {
			set curLine 0
		}

		# Highlight trailing space
		highlight_trailing_space $lineNumber

		# Basic validation
		if {!$curLine || !${::ASMsyntaxHighlight::validation_L1}} {
			## Restore highlight
			 # Assembly language
			if {$prog_language == 0} {
				ASMsyntaxHighlight::highlight $editor $lineNumber

				# Adjust list of highlighted lines
				if {[string index $highlighted_lines $lineNumber] == 0} {
					set highlighted_lines	\
						[string replace $highlighted_lines $lineNumber $lineNumber 1]
				}

			 # C language
			} elseif {$prog_language == 1} {
				c_syntax_highlight $lineNumber

			 # Code listing
			} elseif {$prog_language == 2} {
				LSTsyntaxHighlight::highlight $editor $lineNumber

				# Adjust list of highlighted lines
				if {[string index $highlighted_lines $lineNumber] == 0} {
					set highlighted_lines	\
						[string replace $highlighted_lines $lineNumber $lineNumber 1]
				}

			# ASX8051
			} elseif {$prog_language == 3} {
				R_ASMsyntaxHighlight::highlight $editor $lineNumber

				# Adjust list of highlighted lines
				if {[string index $highlighted_lines $lineNumber] == 0} {
					set highlighted_lines	\
						[string replace $highlighted_lines $lineNumber $lineNumber 1]
				}

			 # No highlighting
			} else {
				set highlight_status 1
			}

			manage_autocompletion_list $lineNumber

			# Finalize validation
			validate_line $lineNumber 0
		}

		# Check spelling if not current line and if enabled
		if {!$curLine || $force_spell_check} {
			spellcheck_check_all $lineNumber 1
		}

		# Recalculate counters on status bar
		if {$curLine} {
			recalc_status_counter {}
		}

		# Put tag "tag_error_line" (but not for code listing)
		if {$prog_language != 2} {
			set add 0
			set remove 0

			if {${::ASMsyntaxHighlight::validation_L0}} {
				if {[llength [$editor tag nextrange tag_error $lineNumber.0 [list $lineNumber.0 lineend]]]} {
					set add 1
				} else {
					set remove 1
				}
			# Remove tag "tag_error_line"
			} elseif {!${::ASMsyntaxHighlight::validation_L1}} {
				set remove 1
			}

			if {$add || $remove} {
				$iconBorder configure -state normal
				if {$add} {
					$editor tag add tag_error_line $lineNumber.0 $lineNumber.0+1l

					if {$defaultCharHeight >= 15} {
						set lineNumber_i [wrap_aux_idx2line $lineNumber]
						$iconBorder delete $lineNumber_i.0 $lineNumber_i.2

						if {[lindex $bookmarks $lineNumber] == 1} {
							set image {bm_ex}
						} else {
							set image {exclamation}
						}

						$iconBorder image create $lineNumber_i.0	\
							-image ::ICONS::16::$image		\
							-align center
					}

				} else {
					$editor tag remove tag_error_line $lineNumber.0 $lineNumber.0+1l

					if {$defaultCharHeight >= 15} {
						set lineNumber_i [wrap_aux_idx2line $lineNumber]
						$iconBorder delete $lineNumber_i.0 $lineNumber_i.2

						if {[lindex $bookmarks $lineNumber] == 1} {
							$iconBorder image create $lineNumber_i.0	\
								-image ::ICONS::16::bookmark		\
								-align center
						}
					}
				}
				$iconBorder configure -state disabled
			}
		}

		if {$curLine} {
			resetUpDownIndex
			recalc_status_modified 0
		}

		# Agjust right panel
		rightPanel_changeLineContent $lineNumber

		set result [wrap_mgr $lineNumber]
		if {!$result} {
			wrap_mgr2 $lineNumber
		}
		return $result
	}

	## Finalize syntax validation on the given line (validates operands only)
	 # @parm Int line		- Number of line in source code
	 # @parm Bool ins_det=1		- Affect panel "Instruction details"
	 # @return void
	private method validate_line {line {ins_det 1}} {
		# Check if basic validation is enabled
		if {!${::ASMsyntaxHighlight::validation_L0}} {
			return
		}

		# Validate breakpoint first
		if {[is_breakpoint_valid $line]} {
			mark_breakpoint_as_valid $line
		} else {
			mark_breakpoint_as_invalid $line
		}

		# Detereminate range of instruction tag
		set ins_range [$editor tag nextrange tag_instruction $line.0 "$line.0 lineend"]

		# Detereminate instruction name
		if {[llength $ins_range]} {
			set instruction [$editor get [lindex $ins_range 0] [lindex $ins_range 1]]
			set instruction [string tolower $instruction]

			if {[lsearch -ascii -exact ${CompilerConsts::AllInstructions} $instruction] == -1} {
				return
			}

		} else {
			return
		}

		# Unset selection in "Instruction details" tab on the Right Panel
		if {$ins_det} {
			$parentObject rightPanel_ins_unselect
		}

		# Check for allowed number of operands
		if {
			${::ASMsyntaxHighlight::operands_count}
				!=
			[lindex $::CompilerConsts::InstructionDefinition($instruction) 0]
		} then {
			$editor tag add tag_error [lindex $ins_range 0] [lindex $ins_range 1]
			return
		}

		# Handle instruction without operands
		if {!${::ASMsyntaxHighlight::operands_count}} {
			if {$ins_det} {
				$parentObject rightPanel_ins_select 1 0
			}
			return
		}

		# Check for valid operand types
		if {${::ASMsyntaxHighlight::validation_L1}} {
			# Local variables
			set matches	{}	;# List of matched operand sets
			set matches0	{}	;# List of not perfectly matched operand sets

			# Iterate over simple definitions and find matches
			set operands		${::ASMsyntaxHighlight::opr_types}
			set operands_org	$operands
			for {set i 0} {$i < 3} {incr i} {

				set idx 0
				foreach opr_set $CompilerConsts::SimpleOperandDefinitions($instruction) {
					if {$opr_set == $operands} {
						if {$i} {
							lappend matches0 $idx
						} else {
							lappend matches $idx
						}
					}
					incr idx
				}

				# Try to change operand set without changing meaning
				while {$i < 2} {
					if {
						[lindex $operands $i] != {A}
							&&
						[lindex $operands $i] != {C}
					} then {
						incr i
						continue
					}

					set operands $operands_org
					if {[lindex $operands $i] == {A}} {
						lset operands $i {D}
					} elseif {[lindex $operands $i] == {C}} {
						lset operands $i {D}
					}
					break
				}
			}

			# Highlight corresponding operand sets in "Instruction details"
			if {[llength $matches] || [llength $matches0]} {
				if {$ins_det} {
					if {[llength $matches]} {
						$parentObject rightPanel_ins_select 1 $matches
					}
					if {[llength $matches0]} {
						$parentObject rightPanel_ins_select 0 $matches0
					}
				}
			} else {
				$editor tag add tag_error [lindex $ins_range 0] [lindex $ins_range 1]
			}

			# Check for legal usege of SFRs and SFBs
			set sfr_range_start	$line.0
			set sfr_range		{}
			set sfr_name		{}
			while {1} {
				# Try to find SFR
				set sfr_range [$editor tag nextrange tag_sfr $sfr_range_start [list $line.0 lineend]]
				if {![llength $sfr_range]} {
					break
				}

				# Check for its legality
				set sfr_range_start [lindex $sfr_range 1]
				set sfr_name [$editor get [lindex $sfr_range 0] [lindex $sfr_range 1]]

				if {[string index $sfr_name 0] == {/}} {
					set sfr_name [string range $sfr_name 1 end]
				}

				if {
					[lsearch -ascii -exact				\
						[$parentObject cget -available_SFR]	\
						[string toupper $sfr_name]		\
					] == -1
				} then {
					$editor tag add tag_error [lindex $sfr_range 0] [lindex $sfr_range 1]
				}
			}
		}
	}

	## Adjust content of the given line in list of bookmarks and list of breakpoint (in right panel)
	 # This function should be called after change in content of a line
	 # @parm Int lineNumber - line number
	 # @return void
	private method rightPanel_changeLineContent {lineNumber} {
		# Adjust list of bookmarks
		if {[lindex $bookmarks $lineNumber] == 1} {
			$parentObject rightPanel_remove_bookmark	$lineNumber
			$parentObject rightPanel_add_bookmark		$lineNumber
			$parentObject rightPanel_bm_select		$lineNumber
		}

		# Adjust list of breakpoints
		if {[lindex $breakpoints $lineNumber] == 1} {
			$parentObject rightPanel_remove_breakpoint	$lineNumber
			$parentObject rightPanel_add_breakpoint		$lineNumber
			$parentObject rightPanel_bp_select		$lineNumber
		}
	}

	## Convert editor line number to left border line number
	 # @parm Int idx	- line number (in editor)
	 # @return Int		- line number (in left border)
	private method wrap_aux_idx2line {idx} {
		if {$number_of_wraps} {
			set remaining $number_of_wraps
			set line $idx
			for {set i 1} {$i < $idx} {incr i} {
				set wrap [lindex $map_of_wraped_lines $i]
				if {$wrap < 0} {
					set wrap 0
				}
				incr line $wrap
				incr remaining -$wrap
				if {!$remaining} {break}
			}
			return $line
		} else {
			return $idx
		}
	}

	## Convert left border line number to editor line number
	 # @parm Int idx	- line number (in left border)
	 # @return Int		- line number (in editor)
	private method wrap_aux_line2idx {line} {
		if {$number_of_wraps} {
			set i 1
			while {1} {
				incr line [expr { -1 - [lindex $map_of_wraped_lines $i]}]
				if {$line < 1 || $line == {}} {break}
				incr i
			}
			return $i
		} else {
			return $line
		}
	}

	## Focus on the editor widget
	 # @return void
	public method focus_in {} {
		focus -force $editor
	}

	## Get ranges for all highlighting tags on the given line
	 # @parm Int lineNum - line number
	 # @return List - tag ranges {{tag_name {start_idx end_idx ...}} ... }
	public method getTagsRanges {lineNum} {
		# Initialize resulting ranges
		set ranges {}

		# Determnate end index
		set endIdx [$editor index "$lineNum.0 lineend"]

		# Iterate over defined highlighting tags
		foreach tag [concat				\
			${ASMsyntaxHighlight::highlight_tags}	\
			${CsyntaxHighlight::highlight_tags}	\
			${LSTsyntaxHighlight::highlight_tags}	\
			{tag_macro_def tag_constant_def}	\
		] {

			# Determinate tag name
			set tag [lindex $tag 0]

			# Determinate range of the tag
			set range {}
			while {1} {
				# Determinate start index
				set startIdx [lindex $range [expr {[llength $range] - 1}]]
				if {$startIdx == {}} {
					set startIdx $lineNum.0
				}
				# Gain tag range
				set rng [$editor tag nextrange $tag $startIdx $endIdx]
				if {![llength $rng]} {break}
				# Append range
				append range $rng
				append range { }
			}
			set range [string range $range 0 {end-1}]

			# Skip empty ranges
			if {[llength $range] == 0} {continue}

			# Append the range to result
			lappend tag $range
			lappend ranges $tag
		}

		# Return resulting range
		return $ranges
	}

	## Make breakpoint on the specified line as VALID (reachable)
	 # @param Int line_number - line number
	 # @return void
	private method mark_breakpoint_as_valid {line_number} {
		if {[lindex $breakpoints $line_number] != 1} {
			return
		}

		set line_number [wrap_aux_idx2line $line_number]

		$lineNumbers tag remove tag_breakpoint_INVALID $line_number.0 [list $line_number.0+1l]
		$lineNumbers tag add tag_breakpoint $line_number.0 [list $line_number.0+1l]
	}

	## Make breakpoint on the specified line as INVALID (unreachable)
	 # @param Int line_number - line number
	 # @return void
	private method mark_breakpoint_as_invalid {line_number} {
		if {[lindex $breakpoints $line_number] != 1} {
			return
		}

		set line_number [wrap_aux_idx2line $line_number]

		$lineNumbers tag remove tag_breakpoint $line_number.0 [list $line_number.0+1l]
		$lineNumbers tag add tag_breakpoint_INVALID $line_number.0 [list $line_number.0+1l]
	}

	## Determinate whether breakpoint on the specified line is valid or could be
	 #+ valid in case there is no breakpoint yet
	 # @param Int line_number - line number
	 # @return Bool - 1 == is valid; 0 == is NOT valid
	private method is_breakpoint_valid {line_number} {

		if {$prog_language == 2 || $prog_language == 3} {
			return 0
		}

		if {
			!$prog_language
				&&
			${::ASMsyntaxHighlight::validation_L0}
				&&
			![llength [$editor tag nextrange tag_instruction $line_number.0 [list $line_number.0 lineend]]]
				&&
			![llength [$editor tag nextrange tag_macro $line_number.0 [list $line_number.0 lineend]]]
		} then {
			return 0
		}

		return 1
	}

	## Restore breakpoint tags in "Line numbers"
	 # @parm Bool ignore_wrap=0 - Ignore line wrapping (see recalc_left_frame)
	 # @return void
	private method rewrite_breakpoint_tags {{ignore_wrap 0}} {
		if {$editor_to_use} {return}

		# Enable line numbers
		$lineNumbers configure -state normal

		# Remove current tags
		$lineNumbers tag remove tag_breakpoint 1.0 end
		$lineNumbers tag remove tag_breakpoint_INVALID 1.0 end

		# Restore tags
		if {!$ignore_wrap && $number_of_wraps} {
			set i 0
			set line 0
			foreach wrap $map_of_wraped_lines {
				if {[lindex $breakpoints $line] == 1} {
					if {[is_breakpoint_valid $line]} {
						$lineNumbers tag add tag_breakpoint $i.0 "$i.0+1l"
					} else {
						$lineNumbers tag add tag_breakpoint_INVALID $i.0 "$i.0+1l"
					}
				}

				incr wrap
				incr i $wrap
				incr line
			}
		} else {
			foreach line [lsearch -ascii -exact -all $breakpoints 1] {
				if {[is_breakpoint_valid $line]} {
					$lineNumbers tag add tag_breakpoint $line.0 "$line.0+1l"
				} else {
					$lineNumbers tag add tag_breakpoint_INVALID $line.0 "$line.0+1l"
				}
			}
		}

		# Disable line numbers
		$lineNumbers configure -state disabled
	}

	## Define line markers (bookmark, breakpoint, simulator line, etc.)
	 # @return void
	public method define_line_markers {} {
		if {$editor_to_use} {return}

		# Iterate over definition
		foreach tag_definition $line_markers {
			# Create tag in editor
			$editor tag configure [lindex $tag_definition 0] -background [lindex $tag_definition 1]
			# Create tag in line numbers
			if {[lsearch {tag_breakpoint_INVALID tag_breakpoint} [lindex $tag_definition 0]] != -1} {
				$lineNumbers tag configure [lindex $tag_definition 0]	\
					-background [lindex $tag_definition 1] -relief raised -borderwidth 1
			}
		}
		$editor tag configure tag_current_line -borderwidth 0 -relief flat
	}

	## Create bindings for defined key shortcuts
	 # @return void
	public method shortcuts_reevaluate {} {
		# Unset previous configuration
		foreach key $set_shortcuts {
			bind $editor <$key> {}
		}
		set set_shortcuts {}

		# Iterate over shortcuts definition
		foreach block ${::SHORTCUTS_LIST} {
			# Determinate category
			set category	[lindex $block 0]
			if {[lsearch $shortcuts_cat $category] == -1} {continue}

			# Determinate definition list and its length
			set block	[lreplace $block 0 2]
			set len		[llength $block]

			# Iterate over definition list and create bindings
			for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {
				# Determinate key sequence
				set key [lindex $block $i]
				if {$key == {cmd_line}} {
					catch {
						bind $cmd_line <$::SHORTCUTS_DB($category:$key)>	\
							"$this cmd_line_focus; break"
						bind . <$::SHORTCUTS_DB($category:$key)>		\
							"\${::X::actualProject} cmd_line_on; break"
					}
					continue
				}
				if {[catch {
					set key $::SHORTCUTS_DB($category:$key)
				}]} then {
					continue
				}
				if {$key == {}} {continue}

				# Create and register new binding
				lappend set_shortcuts $key
				set cmd [subst [lindex $block [list $j 1]]]
				append cmd {;break}

				bind $editor <$key> $cmd
			}
		}
	}

	## Define popup menu
	 # @return void
	public method makePopupMenu {} {
		if {[winfo exists $menu]} {destroy $menu}
		menuFactory $EDITORMENU $menu 0 $cmd_prefix 0 {} [namespace current]

		if {[winfo exists $stat_menu]} {destroy $stat_menu}
		menuFactory $STATMENU $stat_menu 0 {::X::} 0 {} [namespace current]

		if {[winfo exists $IB_menu]} {destroy $IB_menu}
		menuFactory $IBMENU $IB_menu 0 "$this " 0 {} [namespace current]

		if {[winfo exists $LN_menu]} {destroy $LN_menu}
		menuFactory $LNMENU $LN_menu 0 "$this " 0 {} [namespace current]
	}

	## Configure state of statusbar popup menu entries
	 # @parm Bool split	- Enable Spit vertial / horizontal	or {} == keep previous value
	 # @parm Bool close	- Enable "Close current view"		or {} == keep previous value
	 # @parm Bool prev	- Enable "Back"				or {} == keep previous value
	 # @parm Bool next	- Enable "Forward"			or {} == keep previous value
	 # @return void
	public method configure_statusbar_menu {split close prev next} {
		if {[llength $statusbar_menu_config] != 4} {
			set statusbar_menu_config [list 1 1 1 1]
		}
		if {$split != {}} {
			lset statusbar_menu_config 0 [expr "$split"]
		}
		if {$close != {}} {
			lset statusbar_menu_config 1 [expr "$close"]
		}
		if {$prev != {}} {
			lset statusbar_menu_config 2 [expr "$prev"]
		}
		if {$next != {}} {
			lset statusbar_menu_config 3 [expr "$next"]
		}
	}

	## Rewrite left site of editor status bar
	 # @parm List coord={} 			- Relative mouse cursor coordinates ({%x,%y})
	 #					  {} == keyboard input (eg. leftArrow pressed)
	 # @parm Bool perform_highlight=1	- Highlight current line and such things
	 # @return void
	public method recalc_status_counter {{coord {}} {perform_highlight 1}} {
		if {$editor_to_use} {return}

# 		# Procedure can executed only in normal editor mode
# 		if {$frozen} {return}

		# Parse arguments
		if {$coord == {}} {
			set coord insert
		} else {
			set coord "@[lindex $coord 0],[lindex $coord 1]"
		}

		# Translate text index into number
		set Index [$editor index $coord]
		# Determinate line number and column
		set line [expr {int($Index)}]
		regexp {\d+$} $Index col

		# Adjust column number
		set lineText [$editor get "$Index linestart" $Index]
		set Index $col
		if {[regexp {\t} $lineText]} {
			set idx -1
			set cor 0
			while {1} {
				set idx [string first "\t" $lineText [expr {$idx + 1}]]
				if {$idx == -1 || $idx > $Index} {break}

				incr cor [expr {7 - (($idx + $cor) % 8)}]
			}
			incr col $cor
		}

		# Restore tag current line
		set tmp $last_cur_line
		incr tmp
		if {$perform_highlight || $last_cur_line != $line} {
			$editor tag remove tag_current_line 1.0 end
			set tmp $line
			incr tmp
			$editor tag add tag_current_line $line.0 $tmp.0
			set last_cur_line $line
		} else {
			$editor tag add tag_current_line $line.0 $tmp.0
		}

		# Restore highlight
		if {$perform_highlight && ${::ASMsyntaxHighlight::validation_L1}} {
			if {$prog_language == 0} {
				ASMsyntaxHighlight::highlight $editor $line
			} elseif {$prog_language == 1} {
				if {$line > 1 && [string index $highlighted_lines [expr {$line - 1}]] != 0} {
					c_syntax_highlight $line
				} elseif {$line == 1} {
					c_syntax_highlight 1
				}
			} elseif {$prog_language == 2} {
				LSTsyntaxHighlight::highlight $editor $line
			} elseif {$prog_language == 3} {
				R_ASMsyntaxHighlight::highlight $editor $line
			}

			manage_autocompletion_list $line
		}

		# Highlight trailing space
		if {$perform_highlight} {
			highlight_trailing_space $line
		}

		# Adjust content of "Instruction details" on Right Panel
		adjust_instruction_details

		# Advanced validation
		if {$perform_highlight && ${::ASMsyntaxHighlight::validation_L1}} {
			validate_line $line
		}

		restore_line_markers $line

		# Change content of editor status bar
		incr col
		set total	[expr {$lastEnd - 1}]
		set line_len	[string length $line]
		set col_len	[string length $col]
		set total_len	[string length $total]
		if {$line_len < $total_len} {
			set line "[string repeat { } [expr {$total_len - $line_len}]]$line"
		}
		if {$col_len < 3} {
			set col "[string repeat { } [expr {3 - $col_len}]]$col"
		}
		$Sbar_row	configure -text $line
		$Sbar_col	configure -text $col
		$Sbar_total	configure -text $total
	}

	## Adjust content of "Instruction details" on Right Panel
	 # @return void
	public method adjust_instruction_details {} {
		set ins_range [$editor tag nextrange tag_instruction {insert linestart} {insert lineend}]

		if {[llength $ins_range]} {
			$parentObject rightPanel_ins_change [$editor get [lindex $ins_range 0] [lindex $ins_range 1]]
		} else {
			set ins_range [$editor tag nextrange tag_directive {insert linestart} {insert lineend}]
			if {[llength $ins_range]} {
				$parentObject rightPanel_dir_change D [$editor get [lindex $ins_range 0] [lindex $ins_range 1]]
			} else {
				set ins_range [$editor tag nextrange tag_control {insert linestart} {insert lineend}]
				if {[llength $ins_range]} {
					$parentObject rightPanel_dir_change C [$editor get [lindex $ins_range 0] [lindex $ins_range 1]]
				} else {
					$parentObject rightPanel_ins_clear
				}
			}
		}
	}

	## Determinate new cursor position when moving by one line up or down
	 # @return TextIndex - New cursor position
	private method get_up_down_idx {up__down} {
		# Local variables
		set insertIndex [$editor index insert]	;# Insert index
		set lineNum [expr {int($insertIndex)}]	;# Line number

		# Line start
		if {
			!$lastUpDownIndex && $insertIndex == [$editor index {insert linestart}]
		} then {
			if {$up__down} {
				return [$editor index {insert-1l linestart}]
			} else {
				return [$editor index {insert+1l linestart}]
			}

		# Somewhere else
		} else {
			# Determinate true column number
			set col [text_index_to_column $insertIndex]

			# Determinate target column number
			if {!$lastUpDownIndex} {
				set lastUpDownIndex $col
			} else {
				set col $lastUpDownIndex
			}

			# Traslate column number to text index
			if {$up__down} {
				incr lineNum -1
			} else {
				incr lineNum
			}

			return [$editor index $lineNum.[column_to_text_index $lineNum $col]]
		}
	}

	## Translate text index (e.g. 5.11) to column number
	 # @parm TextIndex insertIndex - Text index to translate
	 # @return Int - Resulting column
	private method text_index_to_column {insertIndex} {
		set col [lindex [split $insertIndex {.}] 1]
		set lineText [$editor get [list $insertIndex linestart] $insertIndex]

		if {[string first "\t" $lineText] != -1} {
			set idx -1
			set cor 0
			while {1} {
				set idx [string first "\t" $lineText [expr {$idx + 1}]]
				if {$idx == -1} {break}

				incr cor [expr {7 - (($idx + $cor) % 8)}]
			}
			incr col $cor
		}
		return $col
	}

	## Translate column number to text index
	 # @parm Int lineNum	- Line number
	 # @parm Int col	- Column number
	 # @return TextIndex - Resulting insertIndex
	private method column_to_text_index {lineNum col} {
		if {!$col} {
			return 0
		}
		set lineText [$editor get $lineNum.0 [list $lineNum.0 lineend]]

		if {[string first "\t" $lineText] != -1} {
			set col_x 0
			set i 0
			set l [string length $lineText]

			for {set i 0} {$i < $l} {incr i} {
				switch -- [string index $lineText $i] {
					"\t"	{
						incr col_x [expr {8 - ($col_x % 8)}]
					}
					default	{
						incr col_x
					}
				}

				if {$col_x >= $col} {
					if {($col_x - $col) < 2} {
						incr i
					}
					break
				}
			}

			return $i

		} else {
			return $col
		}
	}

	## Adjust current selection (tag "sel") to block selection mode
	 # @return void
	private method adjust_selection_to_block {} {
		# Nothing selected -> abort
		if {![llength [$editor tag nextrange sel 1.0]]} {
			return
		}

		# Get current selection shape
		set sel_range_s [$editor tag nextrange sel 1.0]
		set sel_range_e [$editor tag prevrange sel end]
		scan [lindex $sel_range_s 0] %d.%d row_s0 col_s0
		scan [lindex $sel_range_s 1] %d.%d row_s1 col_s1
		scan [lindex $sel_range_e 0] %d.%d row_e0 col_e0
		scan [lindex $sel_range_e 1] %d.%d row_e1 col_e1

		# This is only a speed improvement (may cause unexected probles)
		if {$row_s0 == $row_s1 && $row_e0 == $row_e1 && $col_s0 == $col_e0 && $col_s1 == $col_e1} {
			return
		}

		# Translate column numbers to real column numbers
		set col_s0 [text_index_to_column $row_s0.$col_s0]
		set col_s1 [text_index_to_column $row_s1.$col_s1]
		set col_e0 [text_index_to_column $row_e0.$col_e0]
		set col_e1 [text_index_to_column $row_e1.$col_e1]

		# Adjust column numbers
		if {$col_s0 > $col_s1} {
			set tmp $col_s0
			set col_s0 $col_s1
			set col_s1 $tmp
		}
		if {$col_e0 > $col_e1} {
			set tmp $col_e0
			set col_e0 $col_e1
			set col_e1 $tmp
		}

		# Adjust row numbers
		set row_s1 $row_s0
		if {$row_s0 != $row_s1} {
			col_s0 $col_s1
		}
		set row_e0 $row_e1
		if {$row_e0 != $row_e1} {
			col_e1 $col_e0
		}

		# Determinate width of the selected block
		if {abs($col_s1 - $col_s0) < abs($col_e1 - $col_e0)} {
			set width [expr {abs($col_s1 - $col_s0)}]
		} else {
			set width [expr {abs($col_e1 - $col_e0)}]
		}

		# Regerate selection tags
		$editor tag remove sel 0.0 end
		set col 0
		for {set row $row_s0} {$row <= $row_e1} {incr row} {
			set col0 [column_to_text_index $row $col_s0]
			set col1 [column_to_text_index $row [expr {$col_s0 + $width}]]
			if {[$editor compare $row.$col0 >= [list $row.0 lineend]]} {
				continue
			}
			if {[$editor compare $row.$col1 > [list $row.0 lineend]]} {
				$editor tag add sel $row.$col0 [list $row.0 lineend]
			} else {
				$editor tag add sel $row.$col0 $row.$col1
			}
		}
	}

	## Define highlighting tags in editor text widget and command line text widget
	 # @retrun void
	public method create_highlighting_tags {} {
		if {$editor_to_use} {return}

		if {$prog_language == 1} {
			CsyntaxHighlight::create_tags $editor $fontSize $fontFamily
		} elseif {$prog_language == 2} {
			LSTsyntaxHighlight::create_tags $editor $fontSize $fontFamily
		}
		ASMsyntaxHighlight::create_tags $editor $fontSize $fontFamily
		ASMsyntaxHighlight::create_tags $cmd_line $cmd_line_fontSize	\
			$cmd_line_fontFamily $cmd_line_highlighting

		refresh_highlighting_for_autocompletion
	}

	## Create terminal emulator with external editor embedded into editor frame
	 # IMPORTANT: This is only an auxiliary function for "recreate_terminal"
	 # @parm String filename - Name of file to open with the external editor
	 # @return void
	public method create_terminal {filename} {
		if {$terminal_created} {return}
		set terminal_created 1

		if {$filename == {untitled}} {
			set filename {}
		}

		# Determinate editor command
		set opt {}
		switch -- $editor_to_use {
			1 {set cmd {vim}}
			2 {
				set cmd {emacs}
				set opt {-nw}
			}
			3 {set cmd {nano}}
			4 {set cmd {dav}}
			5 {set cmd {le}}
			default {
				error "Unknown internal error in ::Editor::create_terminal($filename)"
			}
		}

		# Change directory
		set cur_dir [pwd]

		if {[catch {
			if {$filename == {}} {
				cd [$parentObject cget -projectPath]
			} else {
				cd [file dirname $filename]
			}
		}]} then {
			cd ~
		}

		# Run embedded editor
		if {[catch {
			if {$opt == {}} {
				if {$filename == {}} {
					set pid [exec -- urxvt -embed [expr [winfo id $top_frame]]	\
						+sb -bg "$normal_text_bg" -b 0 -w 0 -sl 0	\
						-fn "xft:$fontFamily:pixelsize=$fontSize"	\
						-e $cmd &]
				} else {
					set pid [exec -- urxvt -embed [expr [winfo id $top_frame]]	\
						+sb -bg "$normal_text_bg" -b 0 -w 0 -sl 0	\
						-fn "xft:$fontFamily:pixelsize=$fontSize"	\
						-e $cmd "$filename" &]
				}
			} else {
				if {$filename == {}} {
					set pid [exec -- urxvt -embed [expr [winfo id $top_frame]]	\
						+sb -bg "$normal_text_bg" -b 0 -w 0 -sl 0	\
						-fn "xft:$fontFamily:pixelsize=$fontSize"	\
						-e $cmd $opt &]
				} else {
					set pid [exec -- urxvt -embed [expr [winfo id $top_frame]]	\
						+sb -bg "$normal_text_bg" -b 0 -w 0 -sl 0	\
						-fn "xft:$fontFamily:pixelsize=$fontSize"	\
						-e $cmd $opt "$filename" &]
				}
			}
		} result]} then {
			puts stderr $result
			tk_messageBox		\
				-parent .	\
				-icon error	\
				-type ok	\
				-title [mc "FATAL ERROR"]	\
				-message [mc "Unable to start embedded editor due to an unknown error. This error did not occurred in MCU 8051 IDE code but somewhere else. Please try to restart MCU 8051 IDE with --reset-user-settings"]
		}

		# Return to previous directory
		cd $cur_dir
	}

	## Create terminal emulator with external editor embedded into editor frame
	 # @parm String filename - Name of file to open with the external editor
	 # @return void
	public method recreate_terminal {filename} {
		update idletasks
		if {![winfo exists $ed_sc_frame]} {return}
		set top_frame [frame $ed_sc_frame.top_frame_$top_frame_idx -container 1]
		pack $top_frame -expand 1 -fill both
		bind $top_frame <Visibility> "update; $this create_terminal {$filename}"
		bind $top_frame <Destroy> "$this recreate_terminal {$filename}"
		set terminal_created 0
		incr top_frame_idx
	}

	## Determinate file type according to its name extension
	 # @parm Bool reset - Reset syntax highlight
	 # @return void
	private method determinate_prog_lang {reset} {
		# Determinate file type
		set ext [string replace [file extension $filename] 0 0]
		set prog_language_old $prog_language
		 # - C language
		if {$ext == {c} || $ext == {h} || $ext == {cxx} || $ext == {cpp} || $ext == {cc}} {
			set prog_language 1
		 # - Code listing
		} elseif {$ext == {lst}} {
			set prog_language 2
		 # - Unknown -> Assembly language
		} else {
			set prog_language 0
		}

		# Reset highlight
		if {$reset && ($prog_language_old != $prog_language)} {
			prog_lang_changed
		}
	}

	## This function shoul be called after each change of file type
	 # Reset syntax highlight and adjust editor status bar
	 # @return void
	private method prog_lang_changed {} {
		if {$editor_to_use} {return}
		# Clear current highlighting tags
		$editor tag remove tag_error		0.0 end
		$editor tag remove tag_error_line	0.0 end
		$editor tag remove tag_constant_def	0.0 end
		$editor tag remove tag_macro_def	0.0 end
		$editor tag remove c_lang_func		0.0 end
		$editor tag remove c_lang_var		0.0 end
		foreach tag [concat					\
				${::CsyntaxHighlight::highlight_tags}	\
				${::ASMsyntaxHighlight::highlight_tags}	\
				${::LSTsyntaxHighlight::highlight_tags}	\
			] {
				$editor tag remove [lindex $tag 0] 0.0 end
		}

		# Create C highlighting tags
		if {$object_initialized && $prog_language == 1 && !$c_hg_tags_created} {
			set c_hg_tags_created 1
			CsyntaxHighlight::create_tags $editor $fontSize $fontFamily
			$parentObject rightPanel_bm_bp_create_c_hg_tags
			refresh_highlighting_for_autocompletion

		# Create LST highlighting tags
		} elseif {$object_initialized && $prog_language == 2 && !$lst_hg_tags_created} {
			set lst_hg_tags_created 1
			::LSTsyntaxHighlight::create_tags $editor $fontSize $fontFamily
			$parentObject rightPanel_bm_bp_create_lst_hg_tags
		}

		# Create new highlight
		parseAll

		# Adjust status bar
		adjust_sbar_to_prog_lang

		# Adjust main menu and main toolbar
		if {$prog_language == 1} {
			set uses_c 1
		} else {
			set uses_c 0
		}
		::X::adjust_mainmenu_and_toolbar_to_editor {} $uses_c
		$parentObject filelist_editor_sh_changed $this $prog_language
	}

	## Adjust editor status bar the language used (file type)
	 # @return void
	private method adjust_sbar_to_prog_lang {} {
		if {$editor_to_use} {return}
		if {$prog_language == -1} {
			$Sbar_prog_lang configure -text {}
		} elseif {$prog_language == 1} {
			$Sbar_prog_lang configure -fg {#AA8800} -text "C/H"
		} elseif {$prog_language == 2} {
			$Sbar_prog_lang configure -fg {#00DDEE} -text "LST"
		} elseif {$prog_language == 3} {
			$Sbar_prog_lang configure -fg {#0000DD} -text "ASX"
		} else {
			$Sbar_prog_lang configure -fg {#00CC00} -text "ASM"
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

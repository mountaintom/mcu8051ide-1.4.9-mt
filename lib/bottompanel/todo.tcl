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
if { ! [ info exists _TODO_TCL ] } {
set _TODO_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides autonome GUI component intented for writing ToDo list
# --------------------------------------------------------------------------

class Todo {
	public common buttonActiveBg	{#2222FF}	;# Color for button representing currently active text tags
	public common buttonSemiActBg	{#8888FF}	;#		- || -			 semi active tags

	# Normal font for messages text
	public common todo_normal_font [font create	\
		-family ${Editor::fontFamily}	\
		-size -${Editor::fontSize}	\
	]
	public common normal_font [font create				\
		-family {helvetica}				\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight {normal}				\
	]
	public common bold_font [font create				\
		-family {helvetica}				\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight {bold}					\
	]
	# List of used text tags
	public common textTags		{
		tag_bold tag_italic tag_overstrike tag_underline
	}
	# List of XML tags for text tags (above)
	public common xmlTags		{
		b i s u
	}
	# List "tagging" buttons
	public common tagButtons	{
		button_bold button_italic button_strike button_under
	}
	# List of self closing tags
	public common selfCtags {bookmark}
	public common set_shortcuts	{}	;# Currently set shortcut bindigs
	public common shortcuts_cat	{todo}	;# Key shortcut categories related to this segment
	# ID of bookmark image
	public common bookmarkImage	ok
	# Definition of the popup menu
	public common TODOMENU {
		{command	{Undo}			{Ctrl+Z}	0	"undo"		{undo}
			"Undo last operation"}
		{command	{Redo}			{Ctrl+Shift+Z}	2	"redo"		{redo}
			"Take back last undo operation"}
		{separator}
		{command	{Cut}			{Ctrl+X}	2	"cut"		{editcut}	{}}
		{command	{Copy}			{Ctrl+C}	0	"copy"		{editcopy}	{}}
		{command	{Paste}			{Ctrl+V}	0	"paste"		{editpaste}	{}}
		{command	{Clear}			{}		1	"clear"		{editdelete}	{}}
		{separator}
		{command	{Select all} 		{Ctrl+A}	0	"selectall"	{}		{}}
		{separator}
		{command	{Find}			{$todo:todo_find} 0	"find_dialog"	{find}		{}}
		{command	{Find next}		{$todo:todo_find_n} 5	"find_next"	{down0}		{}}
		{command	{Find previous}		{$todo:todo_find_p} 8	"find_prev"	{up0}		{}}
		{separator}
		{command	{Bold text}		{$todo:bold}	0	"bold"		{text_bold}
			"Use bold font"}
		{command	{Italic text}		{$todo:italic}	0	"italic"	{text_italic}
			"Use italic font"}
		{command	{Strikethrough text}	{$todo:strike}	0	"strike"	{text_strike}
			"Use strikethrough font"}
		{command	{Underline text}	{$todo:under}	1	"under"		{text_under}
			"Use underline font"}
		{separator}
		{command	{Erase tags}		{$todo:edrase}	0	"eraser"	{eraser}
			"Clear rich text tags"}
		{command	{Insert OK image}	{$todo:insert}	1	"bookmark"	{ok}
			"Insert image \"Ok\""}
	}

	# Variables related to object initialization
	private variable input_text			;# String: initial content of the text widget
	private variable todo_gui_initialized	0	;# Bool: GUI created

	# Other variables
	private variable main_frame			;# ID of main frame (text_widget; scrollbar; button_frame)
	private variable text_widget			;# ID of the text widget
	private variable scrollbar			;# ID of scrollbar
	private variable button_frame			;# ID of button frame (on left)
	private variable parent_container		;# ID of parent contaner (some frame)
	private variable button_bold			;# ID of button "Bold"
	private variable button_italic			;# ID of button "Italic"
	private variable button_strike			;# ID of button "Strikethrough"
	private variable button_under			;# ID of button "Underline"
	private variable active_tags		{}	;# Currently active tags
	private variable menu			{}	;# ID of popup menu

	private variable editor_count		0	;# Int: Counter of editor instances
	private variable file_notes_pagesManager	;# Widget: Pages Manager for the file notes
	private variable LIST_file_notes	{}	;# List of Widget: Text widgets with the file notes
	private variable LIST_file_notes_name	{}	;# List of Widget: Label with the file name
	private variable file_notes			;# Widget: File specific notepad
	private variable file_notes_name		;# Widget: Label above file specific notepad (file name)
	private variable file_notes_pages

	private variable notes_invisible_frm		;# Widget: Frame to show when file notes is hidden
	private variable paned_win			;# Widget: Paned window containing "File notes" and "Notes"
	private variable right_pane			;# Widget: Right part of the $paned_win
	private variable left_pane			;# Widget: Left part of the $paned_win

	 # Bool: Paned window redraw procedure is in progress
	private variable redraw_pane_in_progress	0
	 # Bool: File Notes is visible
	private variable notes_visible			[lindex $::CONFIG(FILE_NOTES) 0]
	 # Int: File notes panel size
	private variable panel_size			[lindex $::CONFIG(FILE_NOTES) 1]
	 # Int: File notes panel size (value before it was hidden)
	private variable panel_size_last		[lindex $::CONFIG(FILE_NOTES) 1]

	# Variables related to search bar
	private variable search_frame			;# Widget: Search bar frame
	private variable last_find_index	{}	;# String: Index of last found occurrence of the search string
	private variable search_string		{}	;# String: Search string
	private variable search_string_length	0	;# Int: Length of the search string
	private variable search_entry			;# Widget: Search bar entry box
	private variable search_find_next		;# Widget: Button "Next"
	private variable search_find_prev		;# Widget: Button "Prev"

	## Object constructor
	constructor {} {
		# Configure specific ttk styles
		ttk::style configure Todo_Active.TButton	\
			-background $buttonActiveBg 		\
			-padding 0				\
			-relief flat
		ttk::style map Todo_Active.TButton	\
			-relief [list active raised]	\
			-background [list disabled ${::COMMON_BG_COLOR} active $buttonActiveBg]

		ttk::style configure Todo_SemiAct.TButton	\
			-background $buttonSemiActBg		\
			-padding 0				\
			-relief flat
		ttk::style map Todo_SemiAct.TButton	\
			-relief [list active raised]	\
			-background [list disabled ${::COMMON_BG_COLOR} active $buttonSemiActBg]
	}

	## Object destructor
	destructor {
		# Remove dynamic help on status bar
		if {[winfo exists $menu]} {
			menu_Sbar_remove $menu
		}
	}

	## Get configuration list for file specific notepad
	 # @return void
	public method get_file_notes_config {} {
		if {$panel_size < $panel_size_last} {
			set panel_size_max $panel_size_last
		} else {
			set panel_size_max $panel_size
		}
		return [list $notes_visible $panel_size_max]
	}

	## Get contents of file specific notepad
	 # @parm Int idx=<current> - Index in $LIST_file_notes
	 # @return void
	public method get_file_notes_data {{idx {}}} {
		CreateTodoGUI

		if {$idx == {}} {
			return [$file_notes get 1.0 {end-1l lineend}]
		} else {
			set w [lindex $LIST_file_notes $idx]
			if {$w == {}} {
				return {}
			} else {
				return [$w get 1.0 {end-1l lineend}]
			}
		}
	}

	## Set contents of file specific notepad
	 # @parm String data - Text
	 # @return void
	public method set_file_notes_data {data} {
		CreateTodoGUI

		$file_notes delete 0.0 end
		$file_notes insert end $data
	}

	## Prepare object for creating its GUI
	 # @parm Widget parentContainer	- parent contaner (some frame)
	 # @parm String inputText	- initial content of the text widget
	 # @return void
	public method PrepareTodo {parentContainer _input_text} {
		set parent_container $parentContainer
		set input_text $_input_text
		set todo_gui_initialized 0
	}

	## Inform this tab than it has became active
	 # @return void
	public method TodoTabRaised {} {
		focus $text_widget
		after idle "update; catch {$this todo_panel_redraw_pane}"
	}

	## Add file specific notepad for a newly created editor
	 # @parm String data - Text of the notes
	 # @return void
	public method todo_add_Editor {data} {
		CreateTodoGUI

		# Create a new page in the pages manager for the file specific notepad
		set frm [$file_notes_pagesManager add $editor_count]

		# Create top and bottom frame
		set tf [frame $frm.t]
		set bf [frame $frm.b]

		# Create widgets for the top frame
		pack [label $tf.hl -text [mc "Notes for file:"] -font $normal_font] -side left
		set file_notes_name [label $tf.file_name -font $bold_font]
		pack $file_notes_name -side left
		pack [ttk::button $tf.hide_button				\
			-image ::ICONS::16::2rightarrow				\
			-command "$this todo_file_notes_show_hide 0"		\
			-style Flat.TButton					\
		] -side right

		# Create widgets for the bottom frame
		set file_notes [text $bf.text					\
			-font $todo_normal_font -undo 1 -bg white		\
			-selectbackground {#AAFFAA} -selectborderwidth 1	\
			-selectforeground {#000000} -highlightthickness 0	\
			-yscrollcommand "$bf.scrollbar set"			\
			-wrap word -width 1 -height 1 -tabstyle wordprocessor	\
		]
		pack $file_notes -fill both -expand 1 -side left
		pack [ttk::scrollbar $bf.scrollbar	\
			-command "$file_notes yview"	\
			-orient vertical		\
		] -fill y -side right

		# Pack frames
		pack $tf -side top -anchor nw -fill x
		pack $bf -side bottom -fill both -expand 1

		# Register the newly created widgets
		lappend file_notes_pages $editor_count
		lappend LIST_file_notes $file_notes
		lappend LIST_file_notes_name $file_notes_name

		set_file_notes_data $data
		incr editor_count
	}

	## Redraw panel (move pane sash) acorning to current value of $PanelSize
	 # @return void
	public method todo_panel_redraw_pane {} {
		if {!$todo_gui_initialized} {return}

		if {$redraw_pane_in_progress} {
			after 50 "$this todo_panel_redraw_pane"
			return
		}
		set redraw_pane_in_progress 1

		update
		$paned_win sash place 0 [expr {${::WIN_GEOMETRY_width} - $panel_size}] 0
		update

		set redraw_pane_in_progress 0
	}

	## Set panel width according to current sash position
	 # @return void
	public method todo_panel_set_size {} {
		set panel_size [lindex [$paned_win sash coord 0] 0]
		set panel_size [expr {${::WIN_GEOMETRY_width} - $panel_size}]
	}

	## Show or hide the file specific notepad
	 # @parm Bool show__hide - 1 == Show; 0 == Hide
	 # @return void
	public method todo_file_notes_show_hide {show__hide} {
		CreateTodoGUI
		set notes_visible $show__hide

		# Show
		if {$notes_visible} {
			pack forget $notes_invisible_frm
			pack $file_notes_pagesManager -fill both -expand 1
			$paned_win paneconfigure $right_pane -minsize 200
			set panel_size $panel_size_last

		# Hide
		} else {
			pack forget $file_notes_pagesManager
			pack $notes_invisible_frm -fill y -anchor nw
			$paned_win paneconfigure $right_pane -minsize 20
			set panel_size_last $panel_size
			set panel_size 60
		}

		todo_panel_redraw_pane
	}

	## Remove file specific notes
	 # @parm Int idx - Editor index
	 # @return void
	public method todo_remove_editor {idx} {
		CreateTodoGUI

		$file_notes_pagesManager delete [lindex $file_notes_pages $idx]
		set file_notes_pages [lreplace $file_notes_pages $idx $idx]
		set LIST_file_notes [lreplace $LIST_file_notes $idx $idx]
		set LIST_file_notes_name [lreplace $LIST_file_notes_name $idx $idx]
	}

	## Switch file specific notes to another editor
	 # @parm Int idx - Editor index
	 # @return void
	public method todo_switch_editor {idx} {
		CreateTodoGUI

		set file_notes_name [lindex $LIST_file_notes_name $idx]
		set file_notes [lindex $LIST_file_notes $idx]
		$file_notes_pagesManager raise [lindex $file_notes_pages $idx]
	}

	## Change file name shown in the file specific notes to another string
	 # @parm Int idx	- Editor index
	 # @parm String newname	- New file name
	 # @return void
	public method todo_change_filename {idx newname} {
		$file_notes_name configure -text $newname
	}

	## Swithc some variables related to the file specific notes to another editor
	 # @parm Inr idx - Editor index
	 # @return void
	public method todo_switch_editor_vars {idx} {
		CreateTodoGUI

		set file_notes_name [lindex $LIST_file_notes_name $idx]
		set file_notes [lindex $LIST_file_notes $idx]
	}

	## Set text for thec urrent file specific notepad
	 # @parm String text - The text
	 # @return void
	public method todo_file_notes_set_text {text} {
		$file_notes delete 0.0 end
		$file_notes insert end $text
	}

	## Get text from the file specific notepad
	 # @return void
	public method todo_file_notes_get_text {} {
		return [$file_notes get 0.0 end]
	}

	## Initialize to do text
	 # @return void
	public method CreateTodoGUI {} {
		if {$todo_gui_initialized} {return}
		set todo_gui_initialized 1

		if {${::DEBUG}} {
			puts "CreateTodoGUI \[ENTER\]"
		}

		set paned_win [panedwindow $parent_container.paned_win			\
			-sashwidth 4 -showhandle 0 -opaqueresize 1 -orient horizontal	\
		]
		bind $paned_win <ButtonRelease-1> "$this todo_panel_set_size"

		set left_pane [frame $paned_win.l]
		set right_pane [frame $paned_win.r]

		$paned_win add $left_pane
		$paned_win add $right_pane

		$paned_win paneconfigure $left_pane -minsize 200
		$paned_win paneconfigure $right_pane -minsize 200


		#
		# RIGHT PART
		#

		set file_notes_pagesManager [PagesManager $right_pane.pmgr -background ${::COMMON_BG_COLOR}]
		$file_notes_pagesManager compute_size

		set notes_invisible_frm [frame $right_pane.notes_invisible_frm]
		pack [ttk::button $notes_invisible_frm.hide_button		\
			-image ::ICONS::16::2leftarrow				\
			-command "$this todo_file_notes_show_hide 1"		\
			-style Flat.TButton					\
		] -anchor nw

		todo_file_notes_show_hide $notes_visible

		#
		# LEFT PART
		#

		# Create GUI components in main frame
		set main_frame [frame $left_pane.main_frame]
		set text_widget [text $main_frame.todo_text			\
			-yscrollcommand "$main_frame.todo_text_scrl set"	\
			-font $todo_normal_font -undo 1 -bg white		\
			-selectbackground {#AAFFAA} -selectborderwidth 1	\
			-selectforeground {#000000} -highlightthickness 0	\
			-wrap word -width 1 -height 1 -tabstyle wordprocessor	\
		]
		set scrollbar [ttk::scrollbar $main_frame.todo_text_scrl	\
			-command "$text_widget yview"				\
			-orient vertical					\
		]
		set button_frame	[frame $main_frame.todo_text_bframe]

		# Pack GUI of main frame
		pack $button_frame -side left -anchor n
		pack $text_widget -fill both -expand 1 -side left
		pack $scrollbar -fill y -side right

		## Create GUI components in search bar frame
		set search_frame [frame $left_pane.search_frame]
		 # Search entry box
		set search_entry [ttk::entry $search_frame.entry	\
			-width 30					\
			-validate all					\
			-validatecommand "$this TodoProc_search %P"	\
		]
		bind $search_entry <Key-Escape> "$this TodoProc_hide_find_dialog"
		 # Button: "Next"
		set search_find_next [ttk::button $search_frame.find_next_but	\
			-image ::ICONS::16::down0				\
			-command "$this TodoProc_find_next"			\
			-state disabled						\
			-style Flat.TButton					\
		]
		DynamicHelp::add $search_frame.find_next_but \
			-text [mc "Find next occurrence of search string"]
		 # Button: "Prev"
		set search_find_prev [ttk::button $search_frame.find_prev_but	\
			-image ::ICONS::16::up0					\
			-command "$this TodoProc_find_prev"			\
			-state disabled						\
			-style Flat.TButton					\
		]
		DynamicHelp::add $search_frame.find_prev_but \
			-text [mc "Find previous occurrence of search string"]
		 # Button: "Close"
		pack [ttk::button $search_frame.close_but		\
			-image ::ICONS::16::button_cancel		\
			-command "$this TodoProc_hide_find_dialog"	\
			-style Flat.TButton				\
		] -side left
		DynamicHelp::add $search_frame.close_but \
			-text [mc "Hide search bar"]
		 # Separator
		pack [ttk::separator $search_frame.sep	\
			-orient vertical		\
		] -fill y -padx 5 -side left -pady 2
		 # Label: "Find"
		pack [label $search_frame.find_lbl	\
			-text [mc "Find:"]		\
		] -side left
		 # Pack entry and buttons next and prev
		pack $search_entry -side left
		pack $search_find_next -side left -padx 5
		pack $search_find_prev -side left
		 # Checkbutton: "Match case"
		pack [checkbutton $search_frame.match_case_chb	\
			-text [mc "Match case"]			\
			-variable ::Todo::match_case		\
			-command "$this TodoProc_perform_search 1 1.0"	\
		] -side left -padx 5

		# Pack main frame
		pack $main_frame -fill both -expand 1

		 # Show the search bar frame
		TodoProc_find_dialog 0

		# Adjust text widget parameters
		TodoProc_write_text_from_sgml $input_text
		unset input_text
		$text_widget edit modified 0
		$text_widget edit reset

		# create events bindings
		foreach key [bind Text] {
			bind $text_widget $key {continue}
		}
		bind $text_widget <<Undo>> "$this TodoProc_undo; break"
		bind $text_widget <<Redo>> "$this TodoProc_redo; break"
		foreach key {
				<Key-End>	<Key-Home>
				<Key-Down>	<Key-Up>
				<Key-Right>	<Key-Left>
				<Key-Next>	<Key-Prior>
			} \
		{
			bind $text_widget $key "
				[bind Text $key]
				$this recalc_left_panel insert
				break"
		}
		bind $text_widget <KeyRelease>		"break"
		bind $text_widget <KeyPress>		"$this TodoProc_Key %A; break"
		bind $text_widget <ButtonPress-1>	"$this TodoProc_leftClick %x %y"
		bind $text_widget <ButtonRelease-1>	"$this TodoProc_leftRelease"
		bind $text_widget <ButtonRelease-3>	"$this TodoProc_popupMenu %X %Y %x %y; break"
		bind $text_widget <Key-Menu>		"$this TodoProc_Key_Menu; break"
		TodoProc_shortcuts_reevaluate

		## Create button bar
		# Button "Bold"
		set button_bold [ttk::button $button_frame.todo_text_bB		\
			-image ::ICONS::16::text_bold				\
			-command "$this TodoProc_bold"				\
			-style Flat.TButton					\
		]
		DynamicHelp::add $button_bold -text [mc "Bold font"]
		setStatusTip -widget $button_bold	\
			-text [mc "Use bold font"]
		# Button "Italic"
		set button_italic [ttk::button $button_frame.todo_text_bI	\
			-image ::ICONS::16::text_italic				\
			-command "$this TodoProc_italic"			\
			-style Flat.TButton					\
		]
		DynamicHelp::add $button_italic \
			-text [mc "Italic text"]
		setStatusTip -widget $button_italic	\
			-text [mc "Use italic font"]
		# Button "Strikethrough"
		set button_strike [ttk::button $button_frame.todo_text_bS	\
			-image ::ICONS::16::text_strike				\
			-command "$this TodoProc_strike"			\
			-style Flat.TButton					\
		]
		DynamicHelp::add $button_strike \
			-text [mc "Strikethrough font"]
		setStatusTip -widget $button_strike -text [mc "Use strikethrough font"]
		# Button "Underline"
		set button_under [ttk::button $button_frame.todo_text_bU	\
			-image ::ICONS::16::text_under				\
			-command "$this TodoProc_under"				\
			-style Flat.TButton					\
		]
		DynamicHelp::add $button_under		\
			-text [mc "Underline font"]
		setStatusTip -widget $button_under	\
			-text [mc "Use underline font"]

		# pack these buttons
		foreach wdg $tagButtons {
			pack [subst -nocommands "\$$wdg"]
		}
		# Button "Eraser"
		pack [ttk::button $button_frame.todo_text_bE	\
			-image ::ICONS::16::eraser		\
			-command "$this TodoProc_eraser"	\
			-style Flat.TButton			\
		]
		DynamicHelp::add $button_frame.todo_text_bE \
			-text [mc "Erase text tags"]
		setStatusTip -widget $button_frame.todo_text_bE	\
			-text [mc "Remove formatting tags within selected area"]
		# Button "Bookmark"
		pack [ttk::button $button_frame.todo_text_bBm	\
			-image ::ICONS::16::$bookmarkImage 	\
			-command "$this TodoProc_bookmark"	\
			-style Flat.TButton			\
		]
		DynamicHelp::add $button_frame.todo_text_bBm \
			-text [mc "Insert OK image"]
		setStatusTip -widget $button_frame.todo_text_bBm	\
			-text [mc "Insert \"Ok\" image at the current cursor position"]

		# create popup menu
		set menu $text_widget.todo_menu
		TodoProc_makePopupMenu

		# Create text tags and set main font
		todo_refresh_font_settings

		pack $paned_win -fill both -expand 1
	}

	## Recreate all text tags and font font for the text widget
	 # @return void
	public method todo_refresh_font_settings {} {
		if {!$todo_gui_initialized} {CreateTodoGUI}
		$text_widget configure -font [font create	\
			-family ${Editor::fontFamily}		\
			-size -${Editor::fontSize}		\
		]
		todo_create_tags
	}

	## Create bindings for defined key shortcuts
	 # @return void
	public method TodoProc_shortcuts_reevaluate {} {
		if {!$todo_gui_initialized} {CreateTodoGUI}

		# Unset previous configuration
		foreach key $set_shortcuts {
			bind $text_widget <$key> {}
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
				bind $text_widget <$key> $cmd
				bind $search_entry <$key> $cmd
			}
		}
	}

	## Create popup menu
	 # @return void
	public method TodoProc_makePopupMenu {} {
		if {!$todo_gui_initialized} {return}
		if {[winfo exists $menu]} {
			destroy $menu
		}
		menuFactory $TODOMENU $menu 0 "$this TodoProc_" 0 {} [namespace current]
		$menu entryconfigure [::mc "Find next"] -state disabled
		$menu entryconfigure [::mc "Find previous"] -state disabled
	}

	## Create text tags in to do text widget
	 # @return void
	private method todo_create_tags {} {
		# Tag "Bold"
		$text_widget tag configure tag_bold				\
			-font [font create -size -${Editor::fontSize}		\
			-weight bold -family ${Editor::fontFamily}		\
		]
		# Tag "Italic"
		$text_widget tag configure tag_italic				\
			-font [font create -size -${Editor::fontSize}		\
			-slant italic -family ${Editor::fontFamily}		\
		]
		# Tag "Underline"
		$text_widget tag configure tag_underline -underline 1
		# Tag "Overstrike"
		$text_widget tag configure tag_overstrike -overstrike 1
	}

	## Invoke the popup menu
	 # @parm Int X - Absolute x coordinate
	 # @parm Int Y - Absolute y coordinate
	 # @parm Int x - Relative x coordinate
	 # @parm Int y - Relative y coordinate
	 # @return void
	public method TodoProc_popupMenu {X Y x y} {
		popup_menu_disena
		tk_popup $menu $X $Y
		$text_widget mark set insert @$x,$y
	}

	## Handles event: 'Menu' -- invoke popup menu
	 # @return void
	public method TodoProc_Key_Menu {} {
		popup_menu_disena
		$text_widget see insert
		set bbox [$text_widget bbox [$text_widget index insert]]
		tk_popup $menu	\
			[expr {[winfo rootx $text_widget] + [lindex $bbox 0] + 10}]	\
			[expr {[winfo rooty $text_widget] + [lindex $bbox 1] + 10}]
	}

	## Enable/Disable popup menu items according to state of the text widget
	 # Auxiliary procedure for 'TodoProc_popupMenu' and 'TodoProc_Key_Menu'
	 # @return void
	private method popup_menu_disena {} {
		set state [$text_widget cget -state]
		if {[llength [$text_widget tag nextrange sel 1.0]]} {
			if {$state != {disabled}} {
				$menu entryconfigure [::mc "Cut"] -state normal
			}
			$menu entryconfigure [::mc "Copy"] -state normal
		} else {
			$menu entryconfigure [::mc "Cut"] -state disabled
			$menu entryconfigure [::mc "Copy"] -state disabled
		}
		foreach entry {Undo Redo Paste Clear} {
			$menu entryconfigure [::mc $entry] -state $state
		}
	}

	## Write text to the text widget from SGML formatted data
	 # @parm String inputData - SGML data
	 # @return void
	public method TodoProc_write_text_from_sgml {inputData} {
		if {!$todo_gui_initialized} {CreateTodoGUI}

		# Replace all \r\n shit with LF
		regsub -all {(\r)|(\r\n)} $inputData "\n" inputData

		# Insert plain text
		set plainText [regsub -all {<[^<>]*>} $inputData {}]
		regsub -all {&lt;} $plainText {<} plainText
		regsub -all {&gt;} $plainText {>} plainText
		$text_widget insert end $plainText

		# Convert entities to spaces
		regsub -all {&lt;} $inputData { } inputData
		regsub -all {&gt;} $inputData { } inputData

		## Parse pair tags
		foreach xmltag $xmlTags texttag $textTags {

			# modify input data for later processing
			set data $inputData
			foreach tag $xmlTags {
				if {$tag == $xmltag} {continue}
				regsub -all "<$tag>"	$data {} data
				regsub -all "</$tag>"	$data {} data
				regsub -all "<bookmark/>"	$data {} data
			}

			# Translate XML tags to Tk's native text tags
			set StartRow 1
			set EndCol 0
			while {1} {
				set SRow 0
				set ERow 0
				set tagLength [string length "<$xmltag>"]

				set startIdx [string first "<$xmltag>" $data]
				if {$startIdx == -1} {break}

				set LFidx 0
				set LastLFidx $LFidx
				while {1} {
					set LFidx [string first "\n" $data $LFidx]
					if {($LFidx >= $startIdx) || ($LFidx == -1)} {
						set correction 0
						if {$SRow == 0} {
							set correction $EndCol
							incr correction
						}
						set StartCol [expr {$startIdx - $LastLFidx - 1 + $correction}]
						set StartRow [expr {$StartRow + $SRow}]
						break
					} else {
						set LastLFidx $LFidx
						incr SRow
						incr LFidx
					}
				}
				set EndRow $StartRow

				set data [string range $data [expr {$tagLength + $startIdx}] end]
				set endIdx [string first "</$xmltag>" $data]
				if {$endIdx == -1} {break}

				set LFidx 0
				set LastLFidx $LFidx
				while {1} {
					set LFidx [string first "\n" $data $LFidx]
					if {($LFidx >= $endIdx) || ($LFidx == -1)} {
						set correction 0
						if {$ERow == 0} {set correction $StartCol}
						set EndCol [expr {$endIdx - $LastLFidx - $ERow + $correction}]
						set EndRow [expr {$EndRow + $ERow}]
						break
					} else {
						set LastLFidx $LFidx
						incr ERow
						incr LFidx
					}
				}
				set data [string range $data [expr {$tagLength + $endIdx + 1}] end]

				if {($StartRow == $EndRow) && ($StartCol >= $EndCol)} {break}
				$text_widget tag add $texttag $StartRow.$StartCol $EndRow.$EndCol
				set StartRow $EndRow
			}
		}

		## Parse non pair tags

		# modify input data for later processing
		set data $inputData
		regsub -all {<[^<>]*[^/]>} $data {} data
		append data "\n"

		foreach tag $selfCtags {
			set Row 1
			set Col 0
			while {1} {
				set tagIdx [string first "<$tag" $data]
				set tagEndIdx [string first "/>" $data]
				if {($tagEndIdx < $tagIdx) || ($tagIdx == -1)} {break}

				set tagEndIdx [expr {$tagEndIdx + 2}]
				set rowTmp 0
				set LFidx 0
				set LastLFidx $LFidx

				while {1} {
					set LFidx [string first "\n" $data $LFidx]

					if {$LFidx >= $tagIdx} {
						set correction 0
						if {$rowTmp == 0} {set correction [expr {$Col + 2}]}
						set Col [expr {$tagIdx - $LastLFidx - 1 + $correction}]
						set Row [expr {$Row + $rowTmp}]
						break
					} else {
						set LastLFidx $LFidx
						incr rowTmp
						incr LFidx
					}
				}

				set data [string range $data $tagEndIdx end]

				switch $tag {
					{bookmark}	{
						$text_widget delete $Row.$Col $Row.$Col+1c
						$text_widget image create $Row.$Col -image ::ICONS::16::$bookmarkImage
					}
				}
			}
		}
	}

	## Return content of text widget formatted as SGML
	 # @return String - SGML code
	public method TodoProc_read_text_as_sgml {} {
		if {!$todo_gui_initialized} {return $input_text}

		# Determinate end index
		set textEnd [$text_widget index end]
		set textEnd [expr {int($textEnd)}]

		# Determinate length of each line
		set lineIndex(1) -1
		set sum -1
		for {set i 1; set i0 2} {$i < $textEnd} {incr i; incr i0} {
			set lineend [$text_widget index "$i.0 lineend"]
			regexp {\d+$} $lineend lineend
			incr sum [expr {$lineend + 1}]
			set lineIndex($i0) $sum
		}

		# Determinate tag indexes
		set tagList {}
		foreach xmltag $xmlTags texttag $textTags {
			set ranges [$text_widget tag ranges $texttag]

			set i 0
			set index {}
			while {1} {
				set index [lindex $ranges $i]
				if {$index == {}} {break}
				lappend tagList [list $index $xmltag]
				incr i
				lappend tagList [list [lindex $ranges $i] "/$xmltag"]
				incr i
			}
		}

		# Extract plain text data from the text widget
		set data [$text_widget get 1.0 end]

		# Determinate images indexes and adjust lines idxs
		set imageIdxs {}
		foreach imageName [$text_widget image names] {
			lappend imageIdxs [$text_widget index $imageName]
		}
		set imageIdxs [lsort -command "$this read_text_as_sgml_aux_compare 0" $imageIdxs]

		set lastRow 0
		set col 0
		set row 0
		set index 0
		foreach imageIdx $imageIdxs {

			scan $imageIdx %d.%d row col
			set index [expr {$lineIndex($row) + $col}]
			set data [string replace $data $index $index "[string index $data $index] "]

			if {$row == $lastRow} {
				regexp {\d+$} $imageIdx col

				incr colCorrection -1
				incr col $colCorrection

				set imageIdx "$row.$col"
			} else {
				set lastRow $row
				set colCorrection 0
			}

			lappend tagList [list $imageIdx {bookmark/}]
		}

		# Special reverse sorting of tag list
		set tagList [lsort -command "$this read_text_as_sgml_aux_compare 1" -index 0 $tagList]

		# Traslate angle brackets to some special characters
		regsub -all {<} $data "\a" data	;# '<' -> alert
		regsub -all {>} $data "\b" data	;# '>' -> backspace

		# Insert SGML tags into plain text data
		foreach xmlTagIdx $tagList {
			set index [lindex $xmlTagIdx 0]
			set tag   [lindex $xmlTagIdx 1]

			scan $index %d.%d row col
			set index [expr {$lineIndex($row) + $col}]

			if {$index == -1} {
				incr index
				set char [string index $data $index]
				set data [string replace $data $index $index "<$tag>$char"]
			} else {
				set char [string index $data $index]
				set data [string replace $data $index $index "$char<$tag>"]
			}
		}

		# Traslate angle brackets back
		regsub -all {\a} $data {\&lt;} data	;# alert	-> '&lt;'
		regsub -all {\b} $data {\&gt;} data	;# backspace	-> '&gt;

		regsub -all -line {[  \t]+$} $data {} data
		regsub -all {<[^<>]+>\n</[^<>]+>} $data "\n" data

		# return final SGML
		return $data
	}

	## Special comparation for text indexes
	 # @parm Bool reverse		- Invert result
	 # @parm TextIndex first	- Firts index
	 # @parm TextIndex second	- Second index
	 # @return Int - result, one of {-1 0 1}
	public method read_text_as_sgml_aux_compare {reverse first second} {

		# Set return values
		if {$reverse} {
			set A -1
			set B 1
		} else {
			set A 1
			set B -1
		}

		# Determinate First/End Row/Column
		regexp {^\d+} $first FR		;# First Row
		regexp {\d+$} $first FC		;# First Column
		regexp {^\d+} $second ER	;# End Row
		regexp {\d+$} $second EC	;# End Column

		# Perform comparation
		if {$FR > $ER} {
			return $A
		} elseif {$FR == $ER} {
			if {$FC > $EC} {
				return $A
			} elseif {$FC == $EC} {
				return 0
			} else {
				return $B
			}
		} else {
			return $B
		}
	}

	## Get content of text widget as plain text
	 # @return String - result
	public method read_plain_text {} {
		if {!$todo_gui_initialized} {CreateTodoGUI}
		return [$text_widget get 1.0]
	}

	## Switch to bold font
	 # @return void
	public method TodoProc_bold {} {
		addRemoveTag tag_bold $button_bold
		after idle [list focus $text_widget]
	}

	## Switch to italic font
	 # @return void
	public method TodoProc_italic {} {
		addRemoveTag tag_italic $button_italic
		after idle [list focus $text_widget]
	}

	## Switch to strikethrough font
	 # @return void
	public method TodoProc_strike {} {
		addRemoveTag tag_overstrike $button_strike
		after idle [list focus $text_widget]
	}

	## Switch to underline font
	 # @return void
	public method TodoProc_under {} {
		addRemoveTag tag_underline $button_under
		after idle [list focus $text_widget]
	}

	## Erase tags
	 # @parm List idxs={}	- Indexes of selected area
	 # @parm Bool reset=1	- Reset font settings on left panel
	 # @return Bool - result
	public method TodoProc_eraser {{idxs {}} {reset 1}} {
		if {$idxs == {}} {
			set idxs [getSelectionIdx]
		}
		if {$idxs == {}} {
			reset_left_panel
			return 0
		}
		foreach tag $textTags {
			$text_widget tag remove $tag [lindex $idxs 0] [lindex $idxs 1]
		}
		if {$reset} {
			reset_left_panel
			set active_tags [list]
		}
		return 1
	}

	## Select all text in the text widget
	 # @return void
	public method TodoProc_selectAll {} {
		$text_widget tag add sel 1.0 end
	}

	## Insert bookmark image at current cursor position
	 # @return void
	public method TodoProc_bookmark {} {
		set idx [$text_widget index insert]
		$text_widget image create $idx -image ::ICONS::16::$bookmarkImage
	}

	## Take back last operation
	 # @return void
	public method TodoProc_undo {} {
		catch {
			$text_widget edit undo
		}
	}

	## Take back last undo
	 # @return void
	public method TodoProc_redo {} {
		catch {
			$text_widget edit redo
		}
	}

	## Cut selected text
	 # @return void
	public method TodoProc_cut {} {
		if {![llength [$text_widget tag nextrange sel 1.0]]} {return}
		clipboard clear
		clipboard append [$text_widget get sel.first sel.last]
		$text_widget delete sel.first sel.last
	}

	## Copy selected text to clipboard
	 # @return void
	public method TodoProc_copy {} {
		if {![llength [$text_widget tag nextrange sel 1.0]]} {return}
		clipboard clear
		clipboard append [$text_widget get sel.first sel.last]
	}

	## Paste text from clipboard
	 # @return void
	public method TodoProc_paste {} {
		if {[catch {
			set data [clipboard get]
		}]} then {
			return
		}
		catch {$text_widget delete sel.first sel.last}
		$text_widget insert insert $data
	}

	## Clear all text
	 # @return void
	public method TodoProc_clear {} {
		if {!$todo_gui_initialized} {CreateTodoGUI}
		catch {$text_widget delete 1.0 end}
	}

	## Select all text
	 # @return void
	public method TodoProc_selectall {} {
		catch {$text_widget tag add sel 1.0 end}
	}

	## Handles key press
	 # @parm String key - ID of pressed key
	 # @return void
	public method TodoProc_Key {key} {

		# Skip values with no meaning
		if {[string length $key] != 1} {return}

		# Delete seleced text
		catch {
			$text_widget delete sel.first sel.last
		}

		# Get text index before change
		regexp {\d+$} [$text_widget index insert] col0
		incr col0

		# Change content of the text widget
		$text_widget insert insert $key

		# Get text index after change
		regexp {\d+$} [$text_widget index insert] col1

		# Apply active tags
		if {$col0 == $col1} {
			foreach tag $active_tags {
				$text_widget tag add $tag {insert-1c} insert
			}
		}
	}

	## Manage left panel, must be called after each click to the text widget
	 # @parm Int x - relative x coordinate
	 # @parm Int y - relative y coordinate
	 # @return void
	public method TodoProc_leftClick {x y} {
		recalc_left_panel [$text_widget index @$x,$y]
	}

	## Determinate active tags in the selected area, should be called after each LeftRelease
	 # @return Bool - result
	public method TodoProc_leftRelease {} {

		# Determinate start and end index of selected region
		set idxs [getSelectionIdx]
		# If nothing selected -> return False
		if {$idxs == {}} {return 0}

		# Local variables
		regexp {^\d+} [lindex $idxs 0] StartRow	;# Row of start index
		regexp {^\d+} [lindex $idxs 1] EndRow	;# Row of end index
		regexp {\d+$} [lindex $idxs 0] StartCol	;# Column of start index
		regexp {\d+$} [lindex $idxs 1] EndCol	;# Column of end index

		# Object variables
		set active_tags {}	;# Curretly active tags
		set semiActiveTags {}	;# Currently semi-active tags

		# Iterate over rows of selected region
		for {set row $StartRow} {$row <= $EndRow} {incr row} {

			# Iterate over columns of selected reegion
			for {set col $StartCol} {$col <= $EndCol} {incr col} {

				# Determinate list of active tags at the current index
				set tags [$text_widget tag names $row.$col-1c]

				# Append these tags to content of object variable active_tags
				foreach tag $tags {
					if {$tag == {sel}} {
						continue
					}
					if {[lsearch $active_tags $tag] == -1 && [lsearch $semiActiveTags $tag] == -1} {
						lappend active_tags $tag
					}
				}

				# Determinate semi-active tags
				foreach tag $active_tags {
					if {[lsearch $tags $tag] == -1} {
						set i [lsearch $active_tags $tag]
						set repleceTag [lindex $active_tags $i]
						lappend semiActiveTags $tag
						set active_tags [lreplace $active_tags $i $i]
					}
				}
			}
		}

		# Restore highlight of left panel buttons
		reset_left_panel
		foreach tag $active_tags {
			set_button_bg_by_tag_name $tag 1
		}
		foreach tag $semiActiveTags {
			set_button_bg_by_tag_name $tag 2
		}

		# done ...
		return 1
	}

	## Set background color for button related to given text tag according to given state
	 # @parm String tag	- name of text tag
	 # @parm Int state	- state number (0 == passive; 1 == active; 2 == semi-active)
	 # @return void
	private method set_button_bg_by_tag_name {tag state} {
		switch $tag {
			{tag_bold}		"setButtonBg $button_bold	$state"
			{tag_italic}		"setButtonBg $button_italic	$state"
			{tag_overstrike}	"setButtonBg $button_strike	$state"
			{tag_underline}		"setButtonBg $button_under	$state"
		}
	}

	## Reevaluate background color for each button on left panel
	 # @parm TextIndex index - index in the text widget
	 # @return void
	public method recalc_left_panel {index} {

		# Determinate list of active tags
		set active_tags [$text_widget tag names $index-1c]
		# Remove tag sel from the list
		set i [lsearch -ascii -exact $active_tags {sel}]
		if {$i != -1} {
			set active_tags [lreplace $active_tags $i $i]
		}
		# No active tags -> reset panel and return
		if {$active_tags == {}} {
			reset_left_panel
			return
		}

		# Determinate list of buttons related to active tags
		set affected {}
		foreach tag $active_tags {
			switch $tag {
				{tag_bold} {		;# Bold font
					if {[lsearch $affected button_bold] != -1} {continue}
					lappend affected button_bold
				}
				{tag_italic} {		;# Italic font
					if {[lsearch $affected button_italic] != -1} {continue}
					lappend affected button_italic
				}
				{tag_overstrike} {	;# Overstrike font
					if {[lsearch $affected button_strike] != -1} {continue}
					lappend affected button_strike
				}
				{tag_underline} {	;# Underline font
					if {[lsearch $affected button_under] != -1} {continue}
					lappend affected button_under
				}
			}
		}

		# Set background color for each button on left panel
		foreach button $tagButtons {

			# Determinate ID of button widget
			set buttonWdg [subst -nocommands "\$$button"]

			# Determinate state number and set Bg
			if {[lsearch $affected $button] != -1} {
				setButtonBg $buttonWdg 1
			} else {
				setButtonBg $buttonWdg 0
			}
		}
	}

	## Set default background color for each button on the left panel
	 # @return void
	private method reset_left_panel {} {
		foreach button $tagButtons {
			setButtonBg [subst -nocommands "\$$button"] 0
		}
	}

	## Set background color for given button according to given state
	 # @parm Widget button	- ID of button to modify
	 # @parm Int state	- state number (0 == passive; 1 == active; 2 == semi-active)
	 # @return void
	private method setButtonBg {button state} {
		switch $state {
			0	{set style {Flat.TButton}}
			1	{set style {Todo_Active.TButton}}
			2	{set style {Todo_SemiAct.TButton}}
		}

		$button configure -style $style
	}

	## Use given text tag (for selection or next characters)
	 # @parm String tagName		- name of text tag
	 # @parm Widget buttonName	- ID of button related to that tag
	 # @return void
	private method addRemoveTag {tagName buttonName} {
		# Index of given tag in list of active tags
		set tagIdx [lsearch $active_tags $tagName]

		# Tag is inactive -> add the tag
		if {$tagIdx == -1} {
			setButtonBg $buttonName 1
			lappend active_tags $tagName

		# Tag is active -> remove the tag
		} else {
			setButtonBg $buttonName 0
			set active_tags [lreplace $active_tags $tagIdx $tagIdx]
		}

		## Modify the selected area
		set idxs [getSelectionIdx]
		 # There is no selected area
		if {$idxs == {}} {
			set char_before_cursor [$text_widget get insert-1c insert]
			if {$char_before_cursor == { } || $char_before_cursor == "\t" || $char_before_cursor == "\xC2"} {
				set idxs [list [$text_widget index insert-1c] [$text_widget index insert]]
			}
		}
		if {$idxs != {}} {
			TodoProc_eraser $idxs 0
			foreach tag $active_tags {
				setTagAtSel $tag $idxs
			}
		}
	}

	## Set given text tag for area determinated by given indexes
	 # @parm String tagName	- name of text tag to set
	 # @parm List idxs	- target area {first_idx last_idx}
	 # @return Bool - result
	private method setTagAtSel {tagName idxs} {
		if {$idxs == {}} {return 0}
		$text_widget tag add $tagName [lindex $idxs 0] [lindex $idxs 1]
		return 1
	}

	## Get list of indexes of selected area
	 # @return List - text indexes '{first last}' or '{}'
	private method getSelectionIdx {} {
		# Try to determinate indexes
		set start	{}
		set end		{}
		catch {
			set start	[$text_widget index sel.first]
			set end		[$text_widget index sel.last]
		}
		# Return result
		if {$start != {} && $end != {}} {
			return [list $start $end]
		} else {
			return {}
		}
	}

	## Hide search bar
	 # @return void
	public method TodoProc_hide_find_dialog {} {
		if {[winfo ismapped $search_frame]} {
			pack forget $search_frame
		}
	}

	## Show search bar
	 # @parm Bool do_focus_entrybox - Automatically focus the search EntryBox
	 # @return void
	public method TodoProc_find_dialog {{do_focus 1}} {
		if {![winfo ismapped $search_frame]} {
			pack $search_frame -before $main_frame -side top -anchor w
			$search_entry delete 0 end
			if {$do_focus} {
				focus -force $search_entry
			}
		} else {
			if {$do_focus} {
				focus -force $search_entry
			}
		}
	}

	## Search for the given string within the text
	 # @parm String string - Text to find
	 # @return Bool - Always 1
	public method TodoProc_search {string} {
		if {$string == {}} {
			$search_entry configure -style TEntry
			$search_find_next configure -state disabled
			$search_find_prev configure -state disabled
			$menu entryconfigure [::mc "Find next"] -state disabled
			$menu entryconfigure [::mc "Find previous"] -state disabled
			return 1
		}
		set search_string $string
		TodoProc_perform_search 1 1.0

		return 1
	}

	## Perform search for $search_string in the text widget
	 # @parm Bool forw__back	- 1 == Search forwards; 0 == Search backard
	 # @parm String from		- Start index
	 # @return void
	public method TodoProc_perform_search {forw__back from} {
		if {$search_string == {}} {return}

		if {$forw__back} {
			set direction {-forwards}
		} else {
			set direction {-backwards}
		}
		if {${::Todo::match_case}} {
			set last_find_index [$text_widget search $direction -- $search_string $from]
		} else {
			set last_find_index [$text_widget search $direction -nocase -- $search_string $from]
		}
		if {$last_find_index == {}} {
			$search_entry configure -style StringNotFound.TEntry
			$search_find_next configure -state disabled
			$search_find_prev configure -state disabled
			$menu entryconfigure [::mc "Find next"] -state disabled
			$menu entryconfigure [::mc "Find previous"] -state disabled
		} else {
			$search_entry configure -style StringFound.TEntry
			$search_find_next configure -state normal
			$search_find_prev configure -state normal
			$menu entryconfigure [::mc "Find next"] -state normal
			$menu entryconfigure [::mc "Find previous"] -state normal

			set search_string_length [string length $search_string]
			$text_widget see $last_find_index
			catch {
				$text_widget tag remove sel 0.0 end
			}
			$text_widget tag add sel $last_find_index $last_find_index+${search_string_length}c
		}
	}

	## Find next occurrence of the search string
	 # @return void
	public method TodoProc_find_next {} {
		if {![winfo ismapped $search_frame]} {
			pack $search_frame -before $main_frame -side top -anchor w
		}
		if {$last_find_index == {}} {
			return
		}
		TodoProc_perform_search 1 $last_find_index+${search_string_length}c
	}

	## Find previous occurrence of the search string
	 # @return void
	public method TodoProc_find_prev {} {
		if {![winfo ismapped $search_frame]} {
			pack $search_frame -before $main_frame -side top -anchor w
		}
		if {$last_find_index == {}} {
			return
		}
		TodoProc_perform_search 0 $last_find_index
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

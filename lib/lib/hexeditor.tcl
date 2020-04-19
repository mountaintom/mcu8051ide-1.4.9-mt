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
if { ! [ info exists _HEXEDITOR_TCL ] } {
set _HEXEDITOR_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# This class provides simple hex editor with selectable view mode
# and optional ascii view. See constructor and section
# "GENERAL PUBLIC INTERFACE" for more details.
# --------------------------------------------------------------------------

class HexEditor {
	# Font for editor text widget(s) - normal size
	if {!$::MICROSOFT_WINDOWS} {
	public common view_font_n [font create				\
			-family $::DEFAULT_FIXED_FONT			\
			-size [expr {int(-15 * $::font_size_factor)}]	\
		]
	} else {
	public common view_font_n [font create				\
			-family $::DEFAULT_FIXED_FONT			\
			-size [expr {int(-15 * $::font_size_factor)}]	\
			-weight bold					\
		]
	}
	# Font for editor headers - normal size
	public common header_font_n [font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-15 * $::font_size_factor)}]	\
		-weight bold					\
	]
	# Font for editor headers - small size
	public common header_font_s [font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
	]
	public common view_font_s $header_font_s	;# Font for editor text widget(s) - small size
	public common header_bg	{#9999FF}	;# Background color for headers
	public common header_fg	{#FFFFFF}	;# Foreground color for headers
	public common n_row_bg		{#DDDDDD}	;# Background color for Nth rows
	public common highlight_fg	{#FFAA00}	;# Foreground color for chaged values
	public common highlight_bg	{#888888}	;# Background color for background highlight (variant 0)
	public common highlight_bg1	{#FFDD33}	;# Background color for background highlight (variant 1)
	public common highlight_bg2	{#FFAA00}	;# Background color for background highlight (variant 2)
	public common unprintable_fg	{#FF0000}	;# Foreground color for unprintable characters in ascii view
	public common current_full_bg	{#00FF00}	;# Background color for cursor in active view
	public common current_half_bg	{#AAFFAA}	;# Background color for cursor in inactive view
	 ## Variables related to find dialog
	public common find_dialog_win		{}	;# Widget: Find dialog
	public common find_dialog_count	0	;# Int: Counter find dialog opens
	public common text_to_find		{}	;# String: Text/Value to find
	public common where_to_search		left	;# String: Where to search (left or right view)
	  ## Array: Find options
	   # fc - Bool: Find option "From cursor"
	   # bw - Bool: Find option "Backwards"
	public common find_opt

	private variable left_top_button	;# ID of button in left top corner (select all)
	private variable left_address_bar	;# ID of left address bar
	private variable left_header		;# ID of left header (horizontal address bar)
	private variable right_header		;# ID of right header (horizontal address bar)
	private variable left_view		;# ID of text of left view
	private variable right_view		;# ID of text of right view
	private variable scrollbar		;# ID of vertical crollbar
	private variable main_frame		;# ID of main frame (frame for all these widgets)

	private variable view_font		;# Current font for left (and right) view
	private variable header_font		;# Current font for headers
	private variable highlighted_cells	;# Array of Bool: highlighted cells
	private variable bg_hg			;# Array of Bool: cells with background highlight (variant 0)
	private variable bg_hg1			;# Array of Bool: cells with background highlight (variant 1)
	private variable bg_hg2			;# Array of Bool: cells with background highlight (variant 2)

	private variable current_cell_changed_cmd	{}	;# Command to call on event "CurrentCellChanged"
	private variable cell_value_changed_cmd		{}	;# Command to call on event "CellValueChanged"
	private variable cell_enter_cmd			{}	;# Command to call on event "CellMouseEnter"
	private variable cell_leave_cmd			{}	;# Command to call on event "CellMouseLeave"
	private variable cell_motion_cmd		{}	;# Command to call on event "CellMouseMotion"
	private variable scroll_action_cmd		{}	;# Command to call on event "Scroll"
	private variable selection_action_cmd		{}
	private variable current_cell_changed_cmd_set	0	;# Bool: current_cell_changed_cmd not empty
	private variable cell_value_changed_cmd_set	0	;# Bool: cell_value_changed_cmd not empty
	private variable cell_enter_cmd_set		0	;# Bool: cell_enter_cmd not empty
	private variable cell_leave_cmd_set		0	;# Bool: cell_leave_cmd not empty
	private variable cell_motion_cmd_set		0	;# Bool: cell_motion_cmd not empty
	private variable scroll_action_cmd_set 		0	;# Bool: scroll_action_cmd not empty
	private variable selection_action_cmd_set	0

	private variable cell_under_cursor		{0.0}	;# Text index of cell under mouse pointer
	private variable in_cell			0	;# Bool: mouse pointer in cell (see code below)
	private variable motion_binding			0	;# Bool: Bindings for special mouse events set
	private variable view_mode				;# Current view mode (one of {dec hec oct bin})
	private variable ascii_view				;# Bool: Ascii view available
	private variable address_length				;# Int: Length of addresses on left address bar
	private variable physical_height			;# Int: Height of view in rows
	private variable width					;# Int: Number of cells in left view in one row
	private variable height					;# Int: Number of rows in left view
	private variable total_capacity				;# Int: Total editor capacity in bytes
	private variable left_view_width			;# Int: Number of charcers in left view on one row
	private variable value_length				;# Int: Number of characters in one cell
	private variable cur_idx			0.0	;# TextIndex: Last text index before selection
	private variable selected_view			{}	;# ID of active view
	private variable popup_menu				;# ID of popup menu for both views
	private variable selection_sync_in_P		0	;# Bool: View selection synchronization in progress
	private variable scroll_in_progress		0	;# Bool: Scrolling procedure in progress
	private variable cursor_address			0	;# Int: Address of the current cell
	private variable top_row			1	;# Int: Number of topmost visible row
	private variable disabled			0	;# Bool: Editor disabled
	private variable last_find_index		{}	;# String: Index of first matched characted (find dialog)
	private variable scrollbar_visible		0	;# Bool: Scrollbar visibility flag

	## Costructor
	 # @parm WidgetPath mainframe	- Path where to create editor main frame
	 # @parm Int Width		- Number of columns in row (max. 16)
	 # @parm Int Height		- Number rows
	 # @parm Int addresslength	- Number of characters on one row in left address bar
	 # @parm String mode		- Initial view mode (one of {hex dec bin oct})
	 # @parm Bool ascii		- Display also ascii view
	 # @parm Bool small		- Use small fonts
	 # @parm Int physicalheight	- Heigh of views in rows
	 # @parm Int totalcapacity	- Total capacity in Bytes
	constructor {mainframe Width Height addresslength mode ascii small physicalheight totalcapacity} {
		# Set object variables
		set view_mode $mode
		set ascii_view $ascii
		set physical_height $physicalheight
		set address_length $addresslength
		set width $Width
		set height $Height
		set total_capacity $totalcapacity

		# Initalize  array of highlighted cells
		for {set i 0} {$i < $total_capacity} {incr i} {
			set highlighted_cells($i) 0
			set bg_hg($i) 0
			set bg_hg1($i) 0
			set bg_hg2($i) 0
		}

		# Validate inputs arguments
		if {$width > 16} {
			error "Width cannot be grater than 16"
		}
		if {![string is boolean $small]} {
			error "Invalid value for argument small: $small"
		}

		# Determinate fonts
		if {$small} {
			set view_font $view_font_s
			set header_font $header_font_s
		} else {
			set view_font $view_font_n
			set header_font $header_font_n
		}

		# Create main frame
		set main_frame [frame $mainframe]
		bind $main_frame <Destroy> "catch {::itcl::delete object $this}"

		# Create GUI components
		create_gui		;# Create text widgets
		create_popup_menu	;# Create popup menu
		create_tags		;# Create text tags
		create_bindings		;# Create bindings
		fill_headers		;# Fill headers with appropriate addresses
		fill_views		;# Fill views with spaces

		# Finalize GUI initialization
		$left_view mark set insert 1.0
		set_selected_view {left}
	}

	## Object destructor
	destructor {
		catch {
			destroy $main_frame
		}

		# Remove find dialog window if exists
		if {[winfo exists $find_dialog_win]} {
			destroy $find_dialog_win
		}
	}

	## Create popup menu (for left & right view)
	 # @return void
	private method create_popup_menu {} {
		set popup_menu $main_frame.popup_menu
		menuFactory {
			{command	{Copy}		{Ctrl+C}	0
				"text_copy"	{editcopy}	{}}
			{command	{Paste}		{Ctrl+V}	0
				"text_paste"	{editpaste}	{}}
			{separator}
			{command	{Select all}	{Ctrl+A}	0
				"text_selall"	{}		{}}
			{separator}
			{command	{Find}		{Ctrl+F}	0
				"find_dialog"	{find}		{}}
			{command	{Find next}	{F3}		5
				"find_next"	{1downarrow}	{}}
			{command	{Find previous}	{Shift+F3}	8
				"find_prev"	{1uparrow}	{}}
			{separator}
			{command	{Fill with pseudo-random values} {} 0
				"text_random"	{}		{}}
		} $popup_menu 0 "$this " 0 {} [namespace current]

		# Configure menu entries
		$popup_menu entryconfigure [::mc "Find next"] -state disabled
		$popup_menu entryconfigure [::mc "Find previous"] -state disabled
	}

	## Create all hex editor widgets expect popup menu
	 # @return void
	private method create_gui {} {
		# Determinate width of left view text widget and cell width
		switch -- $view_mode {
			{hex} {
				set left_view_width [expr {$width * 3 - 1}]
				set value_length 2
			}
			{oct} {
				set left_view_width [expr {$width * 4 - 1}]
				set value_length 3
			}
			{dec} {
				set left_view_width [expr {$width * 4 - 1}]
				set value_length 3
			}
			default {
				error "Invalid mode: $view_mode"
			}
		}

		# Create button "Select All" in left top corner
		if {!$::MICROSOFT_WINDOWS} {
			set left_top_button [button $main_frame.left_top_button		\
				-bg $header_bg -bd 0 -padx 0 -pady 0			\
				-activebackground white -relief flat			\
				-highlightthickness 0					\
				-command "$main_frame.left_view tag add sel 1.0 end"	\
			]
			DynamicHelp::add $main_frame.left_top_button -text [mc "Select all"]
			grid $left_top_button -row 0 -column 0 -sticky nsew
		}
		# Create left address bar
		set left_address_bar [text $main_frame.left_address_bar	\
			-height $physical_height -width $address_length	\
			-font $header_font -bg $header_bg		\
			-relief flat -bd 1 -fg $header_fg		\
			-highlightthickness 0 -takefocus 0		\
			-yscrollcommand "$this scrollSet"		\
			-cursor left_ptr				\
		]
		grid $left_address_bar -row 1 -column 0 -sticky ns

		# Create horizontal header for left view
		set left_header [text $main_frame.left_header	\
			-height 1 -width $left_view_width	\
			-font $header_font -bg $header_bg	\
			-relief flat -bd 1 -fg $header_fg	\
			-highlightthickness 0 -takefocus 0	\
			-cursor left_ptr			\
		]
		grid $left_header -row 0 -column 1
		# Create horizontal header for ascii view
		if {$ascii_view} {
			grid [ttk::separator $main_frame.sep	\
				-orient horizontal		\
			] -row 0 -rowspan 2 -column 2 -sticky ns

			set right_header [text $main_frame.right_header	\
				-height 1 -width $width -bg $header_bg	\
				-font $header_font -relief flat -bd 1	\
				-fg $header_fg -highlightthickness 0 	\
				-takefocus 0				\
				-cursor left_ptr			\
			]
			grid $right_header -row 0 -column 3
		}

		# Create text widget of the left view
		set left_view [text $main_frame.left_view		\
			-font $header_font -relief flat -bd 1		\
			-width $left_view_width -bg white		\
			-highlightthickness 0 -height $physical_height	\
			-yscrollcommand "$this scrollSet"		\
		]
		grid $left_view -row 1 -column 1 -sticky ns
		# Create text widget for ascii view
		if {$ascii_view} {
			set right_view [text $main_frame.right_view		\
				-font $header_font -relief flat -bd 1		\
				-width $width -bg white				\
				-highlightthickness 0 -height $physical_height	\
				-exportselection 0 -insertwidth 0		\
				-yscrollcommand "$this scrollSet"		\
			]
			grid $right_view -row 1 -column 3 -sticky ns
		}

		# Create vertical scrollbar
		set scrollbar [ttk::scrollbar $main_frame.scrollbar	\
			-orient vertical				\
			-command "$this scroll"				\
		]
		set scrollbar_visible 0
		showHideScrollbar 1

		grid rowconfigure $main_frame 1 -weight 1
	}

	## Create event bindings for all hex editor widgets (except popup menu)
	 # @return void
	private method create_bindings {} {
		## LEFT PART
		bindtags $left_header $left_header
		bindtags $left_address_bar $left_address_bar
		bindtags $left_view [list $left_view . all]

		foreach key {Left Right Up Down Home End Prior Next} {
			bind $left_view <Key-$key> "$this left_view_movement 0 {$key}; break"
			bind $left_view <Shift-Key-$key> "$this left_view_movement 1 {$key}; break"
		}
		for {set i 1} {$i < 21} {incr i} {
			bind $left_view <Key-F$i> {continue}
		}
		bind $left_view <Control-Key>		{continue}
		bind $left_view <Alt-Key>		{continue}
		bind $left_view <Key-BackSpace>		"$this left_view_movement 0 Left; break"
		bind $left_view <Key-Menu>		"$this popup_menu left %x %y %X %Y; break"
		bind $left_view <ButtonRelease-3>	"$this popup_menu left %x %y %X %Y; break"
		bind $left_view <Key-Tab>		"$this switch_views; break"
		if {!$::MICROSOFT_WINDOWS} {
			bind $left_view <Key-ISO_Left_Tab>	"$this switch_views; break"
		}
		bind $left_view <KeyPress>		"$this left_view_key %A; break"
		bind $left_view <Button-1>		"$this left_view_B1 %x %y; break"
		bind $left_view <<Paste>>		"$this text_paste; break"
		bind $left_view <Control-Key-a>		"$left_view tag add sel 1.0 end"
		bind $left_view <<Selection>>		"$this left_view_selection; break"
		bind $left_view <FocusIn>		"$this set_selected_view left"
		bind $left_view <Key-Escape>		{catch {%W tag remove sel 0.0 end}; break}
		bind $left_view <Control-Key-f>		"$this find_dialog; break"
		bind $left_view <Control-Key-F>		"$this find_dialog; break"
		bind $left_view <F3>			"$this find_next; break"
		if {!$::MICROSOFT_WINDOWS} {
			bind $left_view <XF86_Switch_VT_3> "$this find_prev; break"
		}
		bind $left_view <B1-Motion>		"
			$this left_view_B1_Motion %x %y
			$this text_view_leave
			break"
		foreach key {
				<ButtonRelease-1>	<B1-Enter>	<B1-Leave>
				<B2-Motion>		<Button-5>	<Button-4>
				<MouseWheel>		<<Copy>>	<Double-Button-1>
			} {
				bind $left_view $key "[bind Text $key]; break"
		}
		bind $left_view <Double-Button-1> {break}
		bind $left_view <Triple-Button-1> {break}

		bind $left_view <Button-4> "$this scroll scroll -3 units"
		bind $left_view <Button-5> "$this scroll scroll +3 units"
		bind $left_address_bar <Button-4> "$this scroll scroll -3 units"
		bind $left_address_bar <Button-5> "$this scroll scroll +3 units"
		bind $left_address_bar <MouseWheel> "[bind Text <MouseWheel>]; break"

		## RIGHT PART
		if {$ascii_view} {
			bindtags $right_view [list $right_view . all]
			bindtags $right_header $right_header

			foreach key {<Copy> Double-Button-1} {
				bind $right_view <$key> {continue}
			}
			for {set i 1} {$i < 21} {incr i} {
				bind $right_view <Key-F$i> {continue}
			}
			foreach event {
				Key-Prior	Key-Next	Shift-Key-Up	Shift-Key-Down
				Shift-Key-Home	Key-Home	Shift-Key-Prior	Shift-Key-Next
				Button-1	Key-Up		Key-Down
				Shift-Key-Left	Shift-Key-Right	Shift-Key-End
			} {
				bind $right_view <$event> "
					[bind Text <$event>]
					$this right_view_adjust_cursor
					break"
			}
			bind $right_view <Key-Left>		"$this right_view_movement Left"
			bind $right_view <Key-Right>		"$this right_view_movement Right"
			bind $right_view <Key-End>		"$this right_view_movement End"

			bind $right_view <B1-Motion> "
				[bind Text <B1-Motion>]
				$this right_view_adjust_cursor
				$this text_view_leave
				break"
			bind $right_view <Key-BackSpace> "
				[bind Text <Key-Left>]
				$this right_view_adjust_cursor
				break"
			bind $right_view <Key-Menu>		"$this popup_menu right %x %y %X %Y; break"
			bind $right_view <ButtonRelease-3>	"$this popup_menu right %x %y %X %Y; break"
			bind $right_view <Key-Tab>		"$this switch_views; break"
			if {!$::MICROSOFT_WINDOWS} {
				bind $right_view <Key-ISO_Left_Tab>	"$this switch_views; break"
			}
			bind $right_view <KeyPress>		"$this right_view_key %A; break"
			bind $right_view <<Paste>>		"$this text_paste; break"
			bind $right_view <Control-Key-a>	"$right_view tag add sel 1.0 end"
			bind $right_view <<Selection>>		"$this right_view_selection; break"
			bind $right_view <FocusIn>		"$this set_selected_view right"
			bind $right_view <Key-Escape>		{catch {%W tag remove sel 0.0 end}; break}
			bind $right_view <Control-Key-f>	"$this find_dialog; break"
			bind $right_view <Control-Key-F>	"$this find_dialog; break"
			bind $right_view <F3>			"$this find_next; break"
			if {!$::MICROSOFT_WINDOWS} {
				bind $right_view <XF86_Switch_VT_3> "$this find_prev; break"
			}
			foreach key {
					<ButtonRelease-1>	<B1-Enter>	<B1-Leave>
					<MouseWheel>		<<Copy>>	<Double-Button-1>
					<B2-Motion>
				} {
					bind $right_view $key "[bind Text $key]; break"
			}
			bind $right_view <Double-Button-1> {break}
			bind $right_view <Triple-Button-1> {break}

			bind $right_view <Button-4> "$this scroll scroll -3 units"
			bind $right_view <Button-5> "$this scroll scroll +3 units"
		}
	}

	## Create text tags
	 # @return void
	private method create_tags {} {
		#
		## LEFT PART
		#

		# Cursor position
		$left_address_bar tag configure tag_current_full	\
			-font $header_font				\
			-background $current_full_bg			\
			-foreground {#000000}
		# Cursor position for active view and inactive view
		foreach widget [list $left_header $left_view]	\
			font [list $header_font $view_font]	\
		{
			$widget tag configure tag_current_full	\
				-font $font			\
				-background $current_full_bg	\
				-foreground {#000000}
			$widget tag configure tag_current_half	\
				-font $font			\
				-background $current_half_bg	\
				-foreground {#000000}
		}
		# Nth row backrgound
		$left_view tag configure tag_n_row	\
			-background $n_row_bg		\
			-font $view_font
		# Cell highlight
		$left_view tag configure tag_hg		\
			-foreground $highlight_fg	\
			-font $view_font
		$left_view tag configure tag_bg_hg	\
			-background $highlight_bg	\
			-font $view_font
		$left_view tag configure tag_bg_hg1	\
			-background $highlight_bg1	\
			-font $view_font
		$left_view tag configure tag_bg_hg2	\
			-background $highlight_bg2	\
			-font $view_font
		# Other tags
		$left_view tag configure normal_font	\
			-font $view_font

		# Set tags priorities
		$left_view tag raise sel tag_n_row
		$left_view tag raise sel tag_current_full
		$left_view tag raise sel tag_current_half
		$left_view tag raise sel tag_bg_hg
		$left_view tag raise sel tag_bg_hg1
		$left_view tag raise sel tag_bg_hg2
		$left_view tag raise tag_current_full normal_font
		$left_view tag raise tag_current_half normal_font
		$left_view tag raise tag_bg_hg normal_font
		$left_view tag raise tag_bg_hg1 normal_font
		$left_view tag raise tag_bg_hg2 normal_font
		$left_view tag raise tag_bg_hg2 tag_bg_hg1
		$left_view tag raise tag_bg_hg tag_n_row
		$left_view tag raise tag_bg_hg1 tag_n_row
		$left_view tag raise tag_bg_hg2 tag_n_row
		$left_view tag raise tag_current_full tag_n_row
		$left_view tag raise tag_current_half tag_n_row
		$left_view tag raise tag_current_full tag_bg_hg
		$left_view tag raise tag_current_half tag_bg_hg
		$left_view tag raise tag_current_full tag_bg_hg1
		$left_view tag raise tag_current_half tag_bg_hg1
		$left_view tag raise tag_current_full tag_bg_hg2
		$left_view tag raise tag_current_half tag_bg_hg2

		#
		## RIGHT PART
		#
		if {$ascii_view} {
			# Unprintable characters
			$right_view tag configure tag_np	\
				-font $view_font		\
				-foreground $unprintable_fg

			# Cursor position for active view
			$right_header tag configure tag_current_full	\
				-font $header_font			\
				-background $current_full_bg		\
				-foreground {#000000}
			# Cursor position for inactive view
			$right_header tag configure tag_current_half	\
				-font $header_font			\
				-background $current_half_bg		\
				-foreground {#000000}

			# Cursor position for active view
			$right_view tag configure tag_current_full	\
				-font $view_font			\
				-background $current_full_bg
			# Cursor position for inactive view
			$right_view tag configure tag_current_half	\
				-font $view_font			\
				-background $current_half_bg

			# Nth row backrgound
			$right_view tag configure tag_n_row	\
				-background $n_row_bg		\
				-font $view_font
			# Cell highlight
			$right_view tag configure tag_hg	\
				-foreground $highlight_fg	\
				-font $view_font
			$right_view tag configure tag_bg_hg	\
				-background $highlight_bg	\
				-font $view_font
			$right_view tag configure tag_bg_hg1	\
				-background $highlight_bg1	\
				-font $view_font
			$right_view tag configure tag_bg_hg2	\
				-background $highlight_bg2	\
				-font $view_font

			# Other tags
			$right_view tag configure normal_font	\
				-font $view_font

			# Set tags priorities
			$right_view tag raise sel tag_current_full
			$right_view tag raise sel tag_current_half
			$right_view tag raise sel tag_n_row
			$right_view tag raise sel tag_bg_hg
			$right_view tag raise sel tag_bg_hg1
			$right_view tag raise sel tag_bg_hg2
			$right_view tag raise tag_current_full normal_font
			$right_view tag raise tag_current_half normal_font
			$right_view tag raise tag_bg_hg normal_font
			$right_view tag raise tag_bg_hg1 normal_font
			$right_view tag raise tag_bg_hg2 normal_font
			$right_view tag raise tag_bg_hg2 tag_bg_hg1
			$right_view tag raise tag_bg_hg tag_n_row
			$right_view tag raise tag_bg_hg1 tag_n_row
			$right_view tag raise tag_bg_hg2 tag_n_row
			$right_view tag raise tag_current_full tag_n_row
			$right_view tag raise tag_current_half tag_n_row
			$right_view tag raise tag_current_full tag_bg_hg
			$right_view tag raise tag_current_half tag_bg_hg
			$right_view tag raise tag_current_full tag_bg_hg1
			$right_view tag raise tag_current_half tag_bg_hg1
			$right_view tag raise tag_current_full tag_bg_hg2
			$right_view tag raise tag_current_half tag_bg_hg2
		}
	}

	## Restore cell highlight
	 # @parm Int address - Cell address
	 # @return void
	private method restore_cell_highlight {address} {
		if {$highlighted_cells($address)} {
			set highlighted_cells($address) 0
			setHighlighted $address 1
		}
		if {$bg_hg($address)} {
			set bg_hg($address) 0
			set_bg_hg $address 1 0
		}
		if {$bg_hg1($address)} {
			set bg_hg1($address) 0
			set_bg_hg $address 1 1
		}
		if {$bg_hg2($address)} {
			set bg_hg2($address) 0
			set_bg_hg $address 1 2
		}
	}

	## Fill headres with addresses
	 # @return void
	private method fill_headers {} {
		# Left horizontal header
		fill_left_header

		# Left address bar
		$left_address_bar delete 1.0 end
		$left_address_bar insert end [string repeat {0} $address_length]
		set line {}
		set address {}
		for {set i 1} {$i < $height} {incr i} {
			set address [format {%X} [expr {$i * $width}]]
			set line "\n"
			append line [string repeat {0}	\
				[expr {$address_length - [string length $address]}]]
			append line $address
			$left_address_bar insert end $line
		}

		# Right horizontal header
		set header_values [list 0 1 2 3 4 5 6 7 8 9 A B C D E F]
		if {$ascii_view} {
			$right_header delete 1.0 end
			for {set i 0} {$i < $width} {incr i} {
				$right_header insert end [lindex $header_values $i]
			}
		}
	}

	## Left horizontal header with cell addresses
	 # @return void
	private method fill_left_header {} {
		set header_values [list 0 1 2 3 4 5 6 7 8 9 A B C D E F]
		$left_header delete 1.0 end
		if {$view_mode == {hex}} {
			set space { }
		} else {
			$left_header insert end { }
			set space {  }
		}
		for {set i 0} {$i < $width} {incr i} {
			if {$i} {
				$left_header insert end $space
			}
			$left_header insert end {x}
			$left_header insert end [lindex $header_values $i]
		}
	}

	## Fill all views with spaces
	 # @return void
	public method fill_views {} {
		# Fill left view with spaces
		$left_view delete 1.0 end
		set line [string repeat { } $left_view_width]
		$left_view insert end $line
		$left_view tag add normal_font {insert linestart} {insert lineend}
		for {set i 1} {$i < $height} {incr i} {
			$left_view insert end "\n"
			$left_view tag add normal_font {insert linestart} {insert lineend}
			$left_view insert end $line

			if {![expr {$i % 3}]} {
				$left_view tag add tag_n_row			\
					[expr {$i - 1}].$left_view_width	\
					[expr {$i + 1}].0
			}
		}

		# Fill right view with spaces
		if {$ascii_view} {
			$right_view delete 1.0 end
			set line [string repeat { } $width]
			$right_view insert end $line
			$right_view tag add normal_font {insert linestart} {insert lineend}
			for {set i 1} {$i < $height} {incr i} {
				$right_view insert end "\n"
				$right_view tag add normal_font {insert linestart} {insert lineend}
				$right_view insert end $line

				if {![expr {$i % 3}]} {
					$right_view tag add tag_n_row			\
						[expr {$i - 1}].$left_view_width	\
						[expr {$i + 1}].0
				}
			}
		}
	}

	## Translate cell address to text indexes
	 # @parm Int address - address to translate
	 # @return List {row column_in_right_view start_col_in_left_view end_col_in_left_view}
	private method address_to_index {address} {
		# Local variable
		set row		[expr {$address / $width + 1}]	;# Row
		set cell	[expr {$address % $width}]	;# Column in right view
		set start_col	0				;# Start column in left view

		# Determinate start column
		if {$cell} {
			if {$view_mode != {hex}} {
				set start_col [expr {$cell * 4}]
			} else {
				set start_col [expr {$cell * 3}]
			}
		}

		# Determinate end column
		set end_col $start_col
		if {$view_mode != {hex}} {
			incr end_col 3
		} else {
			incr end_col 2
		}

		# Return results
		return [list $row $cell $start_col $end_col]
	}

	## Translate text index to address
	 # @parm String view		- View from which is index to translate
	 # @parm TextIndex index	- Indext to translate
	 # @return Int address
	private method index_to_address {view index} {
		# Left view
		if {$view == {left}} {
			if {$view_mode != {hex}} {
				set step 4
			} else {
				set step 3
			}
			scan [$left_view index $index] {%d.%d} row col
			set cell [expr {($col / $step)}]
		# Right view
		} else {
			scan [$right_view index $index] {%d.%d} row cell
		}

		# Return result
		incr row -1
		return [expr {$row * $width + $cell}]
	}

	## Normalize column in left view
	 # @parm Int col - column to normalize
	 # @return {start_column end_column cell_number_in_row}
	private method col_to_start_end {col} {
		if {$view_mode != {hex}} {
			set step 4
		} else {
			set step 3
		}

		set cell [expr {($col / $step)}]
		set start [expr {$cell * $step}]
		set end [expr {$start + $step - 1}]

		return [list $start $end $cell]
	}

	## Adjust cursor tags to the current cursor positions (for left view)
	 # @return void
	private method left_view_adjust_cursor {} {
		scan [$left_view index insert] {%d.%d} row col

		set boundaries [col_to_start_end $col]
		set col_s [lindex $boundaries 0]
		set col_e [lindex $boundaries 1]
		set cell [lindex $boundaries 2]
		set cursor_address_original $cursor_address
		set cursor_address [expr {($row - 1) * $width + $cell}]
		if {$cursor_address >= $total_capacity} {
			set cursor_address $cursor_address_original
			setCurrentCell $cursor_address_original
			return
		}

		# Clear cell highlight
		if {$highlighted_cells($cursor_address)} {
			setHighlighted $cursor_address 0
		}
		# Execute command binded to event CurrentCellChanged
		if {$current_cell_changed_cmd_set && $cursor_address_original != $cursor_address} {
			eval "$current_cell_changed_cmd $cursor_address"
		}

		## Create cursor tags in right view
		if {$ascii_view} {
			$right_header tag remove tag_current_half 0.0 end
			$right_header tag add tag_current_half 1.$cell 1.$cell+1c

			$right_view tag remove tag_current_half 0.0 end
			$right_view tag add tag_current_half $row.$cell "$row.$cell +1c"
		}

		## Create cursor tags in left view
		$left_address_bar tag remove tag_current_full 0.0 end
		$left_address_bar tag add tag_current_full $row.0 $row.0+1l

		$left_header tag remove tag_current_full 0.0 end
		$left_header tag add tag_current_full 1.$col_s 1.$col_e

		$left_view tag remove tag_current_full 0.0 end
		$left_view tag add tag_current_full $row.$col_s $row.$col_e
	}

	## Create binding for <Motion> and <Leave> events for left and right view
	 # @return void
	private method bind_mouse_motions {} {
		if {$motion_binding} {return}
		set motion_binding 1

		bind $left_view <Motion> "$this left_view_motion %x %y %X %Y"
		bind $left_view <Leave> "$this text_view_leave"

		if {$ascii_view} {
			bind $right_view <Motion> "$this right_view_motion %x %y %X %Y"
			bind $right_view <Leave> "$this text_view_leave"
		}
	}

	## Binding for event <ButtonPress-1> in left view
	 # @parm Int x - Relative horizontal position of mouse pointer
	 # @parm Int y - Relative vertical position of mouse pointer
	 # @return void
	private method left_view_move_insert {x y} {
		set index [$left_view index @$x,$y]
		scan $index {%d.%d} row col

		if {$view_mode != {hex}} {
			if {($col % 4) == 3} {
				set index [$left_view index "$index+1c"]
			}
		} else {
			if {($col % 3) == 2} {
				set index [$left_view index "$index+1c"]
			}
		}
		$left_view mark set insert $index
		left_view_adjust_cursor
	}

	## Adjust cursor tags to the current cursor positions (for right view)
	 # @return void
	public method right_view_adjust_cursor {} {
		if {!$ascii_view} {
			return
		}

		scan [$right_view index insert] {%d.%d} row cell
		if {$view_mode != {hex}} {
			set step 4
		} else {
			set step 3
		}
		set cursor_address_original $cursor_address
		set cursor_address [expr {($row - 1) * $width + $cell}]
		if {$cursor_address >= $total_capacity} {
			set cursor_address [expr {$total_capacity - 1}]
			set index [address_to_index $cursor_address]
			set row [lindex $index 0]
			set cell [lindex $index 1]
			$right_view mark set insert $row.$cell
		}
		set col_s [expr {$cell * $step}]
		set col_e [expr {$col_s + $step - 1}]

		# Clear cell highlight
		if {$highlighted_cells($cursor_address)} {
			setHighlighted $cursor_address 0
		}
		# Execute command binded to event CurrentCellChanged
		if {$current_cell_changed_cmd_set && $cursor_address_original != $cursor_address} {
			eval "$current_cell_changed_cmd $cursor_address"
		}

		## Adjust cursor tags in right view
		$right_header tag remove tag_current_full 0.0 end
		$right_header tag add tag_current_full 1.$cell 1.$cell+1c

		$right_view tag remove tag_current_full 0.0 end
		$right_view tag add tag_current_full $row.$cell "$row.$cell +1c"

		## Adjust cursor tags in left view
		$left_address_bar tag remove tag_current_full 0.0 end
		$left_address_bar tag add tag_current_full $row.0 $row.0+1l

		$left_header tag remove tag_current_half 0.0 end
		$left_header tag add tag_current_half 1.$col_s 1.$col_e

		$left_view tag remove tag_current_half 0.0 end
		$left_view tag add tag_current_half $row.$col_s $row.$col_e
	}

	## Binding for event <KeyPress> in right view
	 # @parm String key - binary key code
	 # @return void
	public method right_view_key {key} {
		if {$disabled} {return}
		if {!$ascii_view} {
			return
		}
		# Key must be 8 bit printable character
		if {![string is print -strict $key] || ([string bytelength $key] > 1)} {
			return
		}

		# Determinate row, column and index of insertion cursor
		set index [$right_view index insert]
		scan $index {%d.%d} row col

		# Check for valid position (insert mustn't be after the end of editor)
		if {($row == $height) && ($col >= $width)} {
			return
		}

		# Convert value to decimal and check for valid ASCII value
		binary scan $key c key
		if {$key > 126 || $key < 0} {
			return
		}

		# Synchronize views
		incr row -1
		set address [expr {$row * $width + $col}]
		setValue $address $key
		if {$cell_value_changed_cmd_set} {
			eval "$cell_value_changed_cmd $address $key"
		}
	}

	## Fill the selected are with random values
	 # @return void
	public method text_random {} {
		#
		if {$selected_view == {left}} {
			set view_widget $left_view
			
		} elseif {$ascii_view && $selected_view == {right}} {
			set view_widget $right_view
			
		} else {
			return
		}

		#
		if {![llength [$view_widget tag nextrange sel 0.0]]} {
			return
		}

		#
		set start_address [index_to_address $selected_view [$view_widget index sel.first]]
		set end_address   [index_to_address $selected_view [$view_widget index sel.last]]

		#
		for {set i $start_address} {$i <= $end_address} {incr i} {
			if {$i >= $total_capacity} {
				break
			}

			set value [expr {int(256 * rand()) & 0x0ff}]
			setValue $i $value
			if {$cell_value_changed_cmd_set} {
				eval "$cell_value_changed_cmd $i $value"
			}
		}
	}

	## Synchronize selection in right view with left view
	 # Binding for event <<Selection>>
	 # @return void
	public method right_view_selection {} {
		if {$selection_sync_in_P} {return}
		set selection_sync_in_P 1

		$left_view tag remove sel 0.0 end
		if {![llength [$right_view tag nextrange sel 0.0]]} {
			set selection_sync_in_P 0
			set anything_selected 0
		} else {
			set anything_selected 1
		}

		if {$selection_action_cmd_set} {
			set flag $anything_selected
			if {$flag} {
				if {![string length [string trim [$right_view get sel.first sel.last]]]} {
					set flag 0
				}
			}
			eval "$selection_action_cmd $flag"
		}

		if {!$anything_selected} {
			return
		}

		if {!$ascii_view} {
			return
		}

		if {$view_mode != {hex}} {
			set step 4
		} else {
			set step 3
		}

		scan [$right_view index sel.first] {%d.%d} start_row start_col
		set start_col [expr {$start_col * $step}]
		scan [$right_view index sel.last] {%d.%d} end_row end_col
		set end_col [expr {$end_col * $step}]

		$left_view tag add sel $start_row.$start_col $end_row.$end_col
		set selection_sync_in_P 0
	}

	## Make scrollbar visible or not
	 # @parm Bool display - 1 == Visible; 0 == Invisible
	 # @return void
	public method showHideScrollbar {display} {

		# Show scrollbar
		if {!$scrollbar_visible && $display} {
			set scrollbar_visible 1
			grid $scrollbar -row 0 -rowspan 2 -column 4 -sticky ns

		# Hide scrollbar
		} elseif {$scrollbar_visible && !$display} {
			set scrollbar_visible 0
			grid forget $scrollbar
		}
	}

	## Set scrollbar and synchronize visible area in both views
	 # text $x -yscrollcommand "$this scrollSet"
	 # @parm float fraction0 - Fraction of topmost visible area
	 # @parm float fraction1 - Fraction of bottommost visible area
	 # @return void
	public method scrollSet {fraction0 fraction1} {
		$scrollbar set $fraction0 $fraction1
		scroll moveto $fraction0
	}

	## Scroll both views, left address bar and adjust scrollbar
	 # $scrollbar -command "$this scrollSet"
	 # @parm String args - Here should be something like "moveto 0.1234"
	 # @return void
	public method scroll args {
		if {$scroll_in_progress} {return}
		set scroll_in_progress 1

		eval "$left_view yview $args"

		set idx [$left_view index @5,5]
		scan $idx "%d.%d" row col
		incr row -1
		set top_row $row
		$left_view yview $row
		$left_address_bar yview $row

		if {$ascii_view} {
			$right_view yview $row
		}

		if {$scroll_action_cmd_set} {
			eval $scroll_action_cmd
		}

		update idletasks
		set scroll_in_progress 0
	}

	## Synchronize selection in left view with left view
	 # Binding for event <<Selection>>
	 # @return void
	public method left_view_selection {} {
		if {$selection_sync_in_P} {return}
		set selection_sync_in_P 1

		if {$ascii_view} {
			$right_view tag remove sel 0.0 end
		}
		if {![llength [$left_view tag nextrange sel 0.0]]} {
			set selection_sync_in_P 0
			set anything_selected 0
		} else {
			set anything_selected 1
		}

		if {$selection_action_cmd_set} {
			set flag $anything_selected
			if {$flag} {
				if {![string length [string trim [$left_view get sel.first sel.last]]]} {
					set flag 0
				}
			}
			eval "$selection_action_cmd $flag"
		}

		if {!$anything_selected} {
			return
		}

		if {!$ascii_view} {
			return
		}

		scan [$left_view index sel.first] {%d.%d} start_row start_col
		set start_col [lindex [col_to_start_end $start_col] 2]
		scan [$left_view index {sel.last-1c}] {%d.%d} end_row end_col
		set end_col [lindex [col_to_start_end $end_col] 2]
		incr end_col

		$right_view tag add sel $start_row.$start_col $end_row.$end_col
		set selection_sync_in_P 0
	}

	## Copy text from selected view
	 # @return void
	public method text_copy {} {
		if {![llength [$left_view tag nextrange sel 0.0]]} {
			return
		}

		if {$selected_view == {left}} {
			clipboard clear
			clipboard append [string trim [$left_view get sel.first sel.last]]
		} elseif {($selected_view == {right}) && $ascii_view} {
			clipboard clear
			clipboard append [string trim [$right_view get sel.first sel.last]]
		}
	}

	## Paste text to active view
	 # @return void
	public method text_paste {} {
		if {$disabled} {return}

		# Get clipboard contents
		if {[catch {
			set text [clipboard get]
		}]} then {
			set text {}
		}
		# If clipboard empty then return
		if {![string length $text]} {
			return
		}

		# Paste to left view
		if {$selected_view == {left}} {
			# Remove all characters invalid in current view mode
			switch -- $view_mode {
				{hex} {
					regsub -all {[^0-9a-fA-F ]} $text {} text
					set step 1
				}
				{oct} {
					regsub -all {[^0-7 ]} $text {} text
					set step 2
				}
				{dec} {
					regsub -all {[^0-9 ]} $text {} text
					set step 2
				}
			}

			# Determinate start address
			set address [index_to_address left [$left_view index insert]]

			# Iterate over the text and convert each pair/triad of charaters
			set len [string length $text]
			for {set i 0} {$i < $len} {incr i $value_length} {
				# Get character pair/triad
				set val [string range $text $i [expr {$i + $step}]]
				if {[string is space -strict $val]} {
					incr address
					if {$address >= $total_capacity} {
						break
					}
					continue
				}
				set val [string trim $val]
				set val [string trimleft $val 0]

				# Convert value to decimal
				if {$val == {}} {
					set val 0
				}
				if {$view_mode == {hex}} {
					set val [expr int("0x$val")]
				} elseif {$view_mode == {oct}} {
					set val [expr int("0$val")]
				}

				# Check for allowed range
				if {$val < 0 || $val > 255} {
					continue
				}

				# Set value in editor, simulator and others
				setValue $address $val
				if {$cell_value_changed_cmd_set} {
					eval "$cell_value_changed_cmd $address $val"
				}
				incr address
				incr i
				if {$address >= $total_capacity} {
					break
				}
			}

			# Adjust insertion cursor
			set address [address_to_index $address]
			$left_view mark set insert [lindex $address 0].[lindex $address 2]
			$left_view see insert
			left_view_adjust_cursor

		# Paste to right view
		} elseif {($selected_view == {right}) && $ascii_view} {
			# Determinate start address, row and column
			scan [$right_view index insert] {%d.%d} row col
			incr row -1
			set address [expr {$row * $width + $col}]

			# Iterate over characters in the text
			foreach val [split $text {}] {
				# Convert to decimal
				binary scan $val c val
				if {$val < 0 || $val > 126} {
					incr address
					continue
				}

				# Check for valid address
				if {$address >= $total_capacity} {
					break
				}

				# Set value in editor, simulator and others
				setValue $address $val
				if {$cell_value_changed_cmd_set} {
					eval "$cell_value_changed_cmd $address $val"
				}
				incr address
			}

			# Adjust insertion cursor
			set address [address_to_index $address]
			$right_view mark set insert [lindex $address 0].[lindex $address 1]
			$right_view see insert
			right_view_adjust_cursor
		}
	}

	## Select all text in both views
	 # @return void
	public method text_selall {} {
		$left_view tag add sel 1.0 end
	}

	## Left view event handler: <B1-Motion>
	 # @parm Int x - Relative cursor position
	 # @parm Int y - Relative cursor position
	 # @return void
	public method left_view_B1_Motion {x y} {
		# If x,y overlaps widget area -> abort
		set max_x [winfo width $left_view]
		incr max_x -3
		set max_y [winfo height $left_view]
		incr max_y -3
		if {($x < 3) || ($x > $max_x) || ($y < 3) || ($y > $max_y)} {
			return
		}

		# If x,y is conresponding to current selection -> abort
		set target_idx [$left_view index @$x,$y]
		if {[llength [$left_view tag nextrange sel 0.0]]} {
			if {
				([$left_view compare $cur_idx == sel.first]
					&&
				[$left_view compare $target_idx == sel.last])
					||
				([$left_view compare $cur_idx == sel.last]
					&&
				[$left_view compare $target_idx == sel.first])
			} then {
				return
			}
		}

		# Adjust selection
		$left_view tag remove sel 0.0 end
		if {[$left_view compare $cur_idx < $target_idx]} {
			$left_view tag add sel $cur_idx $target_idx
		} elseif {[$left_view compare $cur_idx > $target_idx]} {
			$left_view tag add sel $target_idx $cur_idx
		}

		# Adjust cursor
		left_view_move_insert $x $y
		update
	}

	## Left view event handler: <Button-1>
	 # @parm Int x - Relative cursor position
	 # @parm Int y - Relative cursor position
	 # @return void
	public method left_view_B1 {x y} {
		$left_view tag remove sel 0.0 end
		focus $left_view
		left_view_move_insert $x $y
		set cur_idx [$left_view index @$x,$y]
	}

	## Set active view
	 # @parm String side - "left" or "right"
	 # @return void
	public method set_selected_view {side} {
		if {$selected_view == $side} {
			return
		}
		set selected_view $side

		# Remove cursor tags
		foreach widget [list $left_header $left_view]  {
			$widget tag remove tag_current_full 0.0 end
			$widget tag remove tag_current_half 0.0 end
		}
		if {$ascii_view} {
			foreach widget [list $right_header $right_view] {
				$widget tag remove tag_current_full 0.0 end
				$widget tag remove tag_current_half 0.0 end
			}
		}

		# Create new cursor tags
		if {$selected_view == {left}} {
			set index [address_to_index $cursor_address]
			$left_view mark set insert [lindex $index 0].[lindex $index 2]
			left_view_adjust_cursor

		} elseif {$ascii_view && $selected_view == {right}} {
			set row [expr {($cursor_address / $width) + 1}]
			set col [expr {$cursor_address % $width}]

			$right_view mark set insert $row.$col
			right_view_adjust_cursor
		}
	}

	## Invoke hex editor popup menu
	 # @parm String side	- "left" or "right"
	 # @parm Int x		- Relative mouse pointer position
	 # @parm Int y		- Relative mouse pointer position
	 # @parm Int X		- Absolute mouse pointer position
	 # @parm Int Y		- Absolute mouse pointer position
	 # @return void
	public method popup_menu {side x y X Y} {
		# Set widget to deal with
		if {$selected_view == {left}} {
			set widget $left_view
			left_view_move_insert $x $y
		} else {
			set widget $right_view
		}

		# Fucus on that widget and determinate cursor position
		focus $widget
		set cur_idx [$widget index @$x,$y]
		if {$ascii_view && $selected_view == {right}} {
			$widget mark set insert $cur_idx
			right_view_adjust_cursor
		}

		# Configure popup menu
		if {[llength [$widget tag nextrange sel 0.0]]} {
			$popup_menu entryconfigure [::mc "Copy"] -state normal
		} else {
			$popup_menu entryconfigure [::mc "Copy"] -state disabled
		}
		if {[catch {
			if {[string length [clipboard get]]} {
				$popup_menu entryconfigure [::mc "Paste"] -state normal
			} else {
				$popup_menu entryconfigure [::mc "Paste"] -state disabled
			}
		}]} then {
			$popup_menu entryconfigure [::mc "Paste"] -state disabled
		}

		# Invoke popup menu
		tk_popup $popup_menu $X $Y
	}

	## Left view event handler: <Key>
	 # Unprintable characters, invalid and non 8 bit characters will be ignored
	 # @parm Char key - Binary code of pressed key
	 # @return void
	public method left_view_key {key} {
		if {$disabled} {return}

		# Check if the given value is printable character
		if {![string is print -strict $key]} {
			return
		}

		# Determinate current row and column
		scan [$left_view index insert] {%d.%d} row col
		if {($row == $height) && ($col >= $left_view_width)} {
			return
		}

		# Validate the given value
		switch -- $view_mode {
			{dec} {
				if {![string is integer -strict $key]} {
					return
				}
			}
			{hex} {
				if {![string is xdigit -strict $key]} {
					return
				}
			}
			{oct} {
				if {![regexp {^[0-7]+$} $key]} {
					return
				}
			}
		}

		# Local variables
		set boundaries	[col_to_start_end $col]				;# Tempotary variable
		set col_s	[lindex $boundaries 0]				;# Starting column
		set col_e	[lindex $boundaries 1]				;# End column
		set cell	[lindex $boundaries 2]				;# Cell number in row
		set org_val	[$left_view get $row.$col_s $row.$col_e]	;# Original cell value
		set org_idx	[$left_view index insert]			;# Original insertion index

		# Replace character at current insertion index with the new one
		$left_view delete insert {insert+1c}
		$left_view insert insert $key
		$left_view mark set insert {insert-1c}
		$left_view tag add normal_font {insert linestart} {insert lineend}

		# Determinate new cell value
		set val [$left_view get $row.$col_s $row.$col_e]
		set val [string trim $val]
		set val [string trimleft $val 0]
		if {$val == {}} {
			set val 0
		}

		# Convert new cell value to decimal integer
		if {$view_mode == {hex}} {
			set val [expr "0x$val"]
		} elseif {$view_mode == {oct}} {
			set val [expr "0$val"]
		}

		# Check for valid value range
		if {$val > 255} {
			$left_view delete $row.$col_s $row.$col_e
			$left_view tag add normal_font [list $row.0 linestart] [list $row.0 lineend]
			$left_view insert $row.$col_s $org_val
			$left_view mark set insert $org_idx
			left_view_adjust_cursor
			return
		}

		# Invoke pseudo-event <cell_value_changed>
		if {$cell_value_changed_cmd_set} {
			eval "$cell_value_changed_cmd $cursor_address $val"
		}

		# Adjust right view
		if {$ascii_view} {
			set char [format %c $val]
			set cell "$row.$cell"
			$right_view delete $cell "$cell+1c"
			if {($val < 127) && [string is print -strict $char]} {
				$right_view insert $cell $char
				$right_view tag remove tag_np $cell "$cell+1c"
			} else {
				$right_view insert $cell {.}
				$right_view tag add tag_np $cell "$cell+1c"
			}
			$right_view tag add normal_font [list $cell linestart] [list $cell lineend]
		}

		# Adjust insertion cursor
		if {($row == $height) && ($col >= ($left_view_width - 1))} {
			left_view_adjust_cursor
		} else {
			left_view_movement 0 Right
		}
	}

	## Perform certain movement action on the right (ascii) view
	 # @parm String key	- Action (one of {Left Right End})
	 # @return void
	public method right_view_movement {key} {
		# Remove selection and determinate current column and row
		$right_view tag remove sel 0.0 end
		scan [$right_view index insert] {%d.%d} row col

		# Determinate correction for insertion cursor
		switch -- $key {
			{Left} {	;# Move left by one character
				if {$row == 1 && $col == 0} {
					return
				}

				incr col -1
				if {$col < 0} {
					set col [expr {$width - 1}]
					incr row -1
				}
			}
			{Right} {	;# Move right by one character
				if {($row == $height) && ($col >= ($width - 1))} {
					return
				}

				incr col
				if {$col >= $width} {
					set col 0
					incr row
				}
			}
			{End} {		;# Move to the end of the current line
				if {$col >= ($width - 1)} {
					return
				}

				set col [expr {$width - 1}]
			}
			default {	;# CRITICAL ERROR
				error "Unrecognized key: $key"
				return
			}
		}

		# Adjust insertion cursor
		$right_view mark set insert $row.$col
		$right_view see insert

		# Adjust cursor highlighting tags
		right_view_adjust_cursor
	}

	## Perform certain movement action on the left view
	 # @parm Bool select	- Manipulate selection
	 # @parm String key	- Action (one of {Left Right Up Down Home End Prior Next})
	 # @return void
	public method left_view_movement {select key} {
		# Remove selection and determinate current column and row
		$left_view tag remove sel 0.0 end
		scan [$left_view index insert] {%d.%d} row col

		# Determinate cell boundaries
		if {$key == {Left} || $key == {Right}} {
			set boundaries [col_to_start_end $col]
			set col_s [lindex $boundaries 0]
			set col_e [lindex $boundaries 1]
		}

		# Determinate correction for insertion cursor
		switch -- $key {
			{Left} {	;# Move left by one character
				if {$row == 1 && $col == 0} {
					return
				}
				if {$col == $col_s} {
					set correction {-2c}
				} else {
					set correction {-1c}
				}
			}
			{Right} {	;# Move right by one character
				incr col_e -1
				if {($row == $height) && ($col >= ($left_view_width - 1))} {
					return
				}
				if {$col == $col_e} {
					set correction {+2c}
				} else {
					set correction {+1c}
				}
			}
			{Up} {		;# Move up by one row
				if {!$row} {
					return
				}
				set correction {-1l}
			}
			{Down} {	;# Move down by one row
				if {$row == $height} {
					return
				}
				set correction {+1l}
			}
			{Home} {	;# Move to the beginning of the current line
				if {!$col} {
					return
				}
				set correction {linestart}
			}
			{End} {		;# Move to the end of the current line
				if {$col >= ($left_view_width - 1)} {
					return
				}
				set correction {lineend-1c}
			}
			{Prior} {	;# Move up by a few lines
				set correction {-8l}
			}
			{Next} {	;# Move up by a few lines
				set correction {+8l}
			}
			default {	;# CRITICAL ERROR
				error "Unrecognized key: $key"
				return
			}
		}

		# Adjust insertion cursor
		$left_view mark set insert [$left_view index "insert $correction"]
		$left_view see insert

		# Adjust selection
		if {!$select} {
			set cur_idx [$left_view index insert]
		} else {
			if {[$left_view compare $cur_idx <= insert]} {
				$left_view tag add sel $cur_idx insert
			} else {
				$left_view tag add sel insert $cur_idx
			}
		}

		# Adjust cursor highlighting tags
		left_view_adjust_cursor
	}

	## Left view event handler: <Leave>
	 # Manages pseudo-event <cell_leave>
	 # @return void
	public method text_view_leave {} {
		if {!$in_cell} {
			return
		}

		set in_cell 0
		set cell_under_cursor {0.0}

		if {$cell_leave_cmd_set} {
			eval $cell_leave_cmd
		}
	}

	## Right view event handler: <Motion>
	 # Manages pseuso-events <cell_motion>, <cell_enter> and <cell_leave>
	 # @parm Int x	- Relative mouse pointer position
	 # @parm Int y	- Relative mouse pointer position
	 # @parm Int X	- Absolute mouse pointer position
	 # @parm Int Y	- Absolute mouse pointer position
	 # @return void
	public method right_view_motion {x y X Y} {
		set index [$right_view index @$x,$y]
		set dlineinfo [$right_view dlineinfo $index]
		if {$y > ([lindex $dlineinfo 1] + [lindex $dlineinfo 3])} {
			text_view_leave
			return
		}
		scan $index {%d.%d} row col

		# Motion
		if {$cell_under_cursor == $index} {
			if {$cell_motion_cmd_set} {
				eval "$cell_motion_cmd $X $Y"
			}

		# (Leave + ) Enter
		} else {
			if {$in_cell} {
				if {$cell_leave_cmd_set} {
					eval $cell_leave_cmd
				}
				set in_cell 0
			}
			if {$cell_enter_cmd_set} {
				set address [expr {($row - 1) * $width + $col}]
				if {$address >= $total_capacity} {
					set address $total_capacity
				}
				eval "$cell_enter_cmd $address $X $Y"
			}
			set in_cell 1
		}

		set cell_under_cursor $index
	}

	## Left view event handler: <Motion>
	 # Manages pseuso-events <cell_motion>, <cell_enter> and <cell_leave>
	 # @parm Int x	- Relative mouse pointer position
	 # @parm Int y	- Relative mouse pointer position
	 # @parm Int X	- Absolute mouse pointer position
	 # @parm Int Y	- Absolute mouse pointer position
	 # @return void
	public method left_view_motion {x y X Y} {
		set index [$left_view index @$x,$y]
		set dlineinfo [$left_view dlineinfo $index]
		if {$y > ([lindex $dlineinfo 1] + [lindex $dlineinfo 3])} {
			text_view_leave
			return
		}
		scan $index {%d.%d} row col
		if {$view_mode != {hex}} {
			set step 4
		} else {
			set step 3
		}

		# Enter
		if {$cell_under_cursor != $index} {
			if {$in_cell && $cell_leave_cmd_set} {
				eval $cell_leave_cmd
			}
			if {$cell_enter_cmd_set} {
				set address [expr {($row - 1) * $width + ($col / $step)}]
				if {$address >= $total_capacity} {
					set address $total_capacity
				}
				eval "$cell_enter_cmd $address $x $y $X $Y"
			}
			set in_cell 1

		# Motion
		} elseif {$cell_motion_cmd_set} {
			eval "$cell_motion_cmd $X $Y"
		}

		set cell_under_cursor $index
	}


	# -------------------------------------------------------------------
	# GENERAL PUBLIC INTERFACE
	# -------------------------------------------------------------------

	## Get editor scroll bar object reference
	 # @return Widget - Scrolbar
	public method get_scrollbar {} {
		return $scrollbar
	}

	## Get editor popup menu object reference
	 # @return Widget - Popup menu
	public method get_popup_menu {} {
		return $popup_menu
	}

	## Get list of values from hex editor
	 # @parm Int start	- Start address
	 # @parm Int end	- End address
	 # @return List - List of decimal values (e.g. {0 226 {} {} 126 {} 6 8})
	public method get_values {start end} {
		# Check for allowed address range
		if {${::DEBUG}} {
			if {$end >= $total_capacity} {
				error "Address out of range"
			}
			if {$end != [expr {int($end)}]} {
				error "Address must be integer"
			}
			if {$start < 0} {
				error "Address out of range"
			}
			if {$start != [expr {int($start)}]} {
				error "Address must be integer"
			}
		}

		# Determinate text indexes of area to extract
		set index [address_to_index $start]
		set start_row	[lindex $index 0]
		set start_col	[lindex $index 2]
		set index [address_to_index $end]
		set end_row	[lindex $index 0]
		set end_col	[lindex $index 3]
		incr end_col

		# Determinate cell legth and cell length+space
		if {$view_mode != {hex}} {
			set step 4
			set len 3
		} else {
			set step 3
			set len 2
		}

		# Initiate extraction
		set result {}
		set value {}
		for {set row $start_row} {$row <= $end_row} {incr row} {
			# Interate over cells withing the row
			for {set col_s $start_col} {$col_s < $left_view_width} {incr col_s $step} {
				# Determinate cell end index
				set col_e $col_s
				incr col_e $len
				if {($row == $end_row) && ($col_s == $end_col)} {
					break
				}

				# Determinate cell value
				set value [$left_view get $row.$col_s $row.$col_e]
				set value [string trim $value]

				# Skip conversion for empty cells
				if {$value == {}} {
					lappend result {}
					continue
				}

				# Convert cell value to decimal integer
				set value [string trimleft $value 0]
				if {$value == {}} {
					set value 0
				}
				switch -- $view_mode {
					{dec} {
						lappend result $value
					}
					{hex} {
						lappend result [expr "0x$value"]
					}
					{oct} {
						lappend result [expr "0$value"]
					}
				}
			}
		}

		if {$start == $end} {
			return [lindex $result 0]
		} else {
			return $result
		}
	}

	## Set value of the specified cell
	 # @parm Int address	- Cell address
	 # @parm Int value	- New cell value (must be withing interval [0;255])
	 # @return void
	public method setValue {address value} {
		# Local variables
		set index	[address_to_index $address]	;# Text index
		set row		[lindex $index 0]		;# Row in left view
		set cell	[lindex $index 1]		;# Column in right view / cell number in row
		set start_col	[lindex $index 2]		;# Starting column in left view
		set end_col	[lindex $index 3]		;# End column in left view
		set index	[$left_view index insert]	;# Current insertion index in left view

		# Empty value means clear the cell
		if {$value == {}} {
			# Clear cell in the left view
			$left_view delete $row.$start_col $row.$end_col
			if {$view_mode != {hex}} {
				$left_view insert $row.$start_col {   }
			} else {
				$left_view insert $row.$start_col {  }
			}
			$left_view mark set insert $index
			$left_view tag add normal_font [list $row.0 linestart] [list $row.0 lineend]

			# Clear cell in the right view
			if {$ascii_view} {
				$right_view delete $row.$cell $row.$end_col
				$right_view insert $row.$cell { }
				$right_view tag add normal_font [list $row.0 linestart] [list $row.0 lineend]
			}

			# Restore insertion cursor tags
			if {$cursor_address == $address} {
				if {$selected_view == {left}} {
					left_view_adjust_cursor
				} else {
					right_view_adjust_cursor
				}
			}

			# Restore cell highlight
			restore_cell_highlight $address

			# Abort the rest of procedure
			return
		}

		# Validate input address and value
		if {${::DEBUG}} {
			if {$address >= $total_capacity} {
				error "Address out of range"
			}
			if {$address != [expr {int($address)}]} {
				error "Address must be integer"
			}
			if {$value > 255 || $value < 0} {
				error "Value of of range"
			}
			if {$value != [expr {int($value)}]} {
				error "Value must be integer"
			}
		}

		# Convert the given value to appropriate string
		set original_value $value
		switch -- $view_mode {
			{hex} {
				set value [format %X $value]
				if {[string length $value] == 1} {
					set value "0$value"
				}
			}
			{oct} {
				set value [format %o $value]
				set len [string length $value]
				if {$len != 3} {
					set value "[string repeat {0} [expr {3 - $len}]]$value"
				}
			}
			{dec} {
				set value [expr $value]
				set len [string length $value]
				if {$len != 3} {
					set value "[string repeat {0} [expr {3 - $len}]]$value"
				}
			}
		}

		# Replace current content of the cell with new value
		$left_view delete $row.$start_col $row.$end_col
		$left_view insert $row.$start_col $value
		$left_view mark set insert $index
		$left_view tag add normal_font [list $row.0 linestart] [list $row.0 lineend]

		# Adjust right view
		if {$ascii_view} {
			set end_col $cell
			incr end_col

			# Convert to character
			set value [format %c $original_value]

			# Insert value to the text widget
			$right_view delete $row.$cell $row.$end_col
			if {($original_value < 127) && [string is print -strict $value]} {
				$right_view insert $row.$cell $value
				$right_view tag remove tag_np $row.$cell "$row.$cell+1c"
			} else {
				$right_view insert $row.$cell {.}
				$right_view tag add tag_np $row.$cell $row.$end_col
			}
			$right_view tag add normal_font [list $row.0 linestart] [list $row.0 lineend]

			# Adjust cursor postion
			scan [$right_view index {insert}] {%d.%d} row cell
			if {$cell == $width} {
				set cell 0
				incr row
			}
			$right_view mark set insert $row.$cell
		}

		# Restore insertion cursor tags
		if {$cursor_address == $address} {
			if {$selected_view == {left}} {
				left_view_adjust_cursor
			} else {
				right_view_adjust_cursor
			}
		}

		# Restore cell highlight
		restore_cell_highlight $address
	}

	## Switch view (from left to right and on the contrary)
	 # @return void
	public method switch_views {} {
		if {!$ascii_view} {
			return
		}
		if {$selected_view == {left}} {
			focus $right_view
		} else {
			focus $left_view
		}
	}

	## Get current view (left or right)
	 # @return String - "left" or "right"
	public method getCurrentView {} {
		return $selected_view
	}

	## Focus on the left view
	 # @return void
	public method focus_left_view {} {
		focus -force $left_view
	}

	## Focus on the right view
	 # @return void
	public method focus_right_view {} {
		if {$ascii_view} {
			focus -force $right_view
		}
	}

	## Set cell background highlight (as write in progress)
	 # @parm Int address	- Cell address
	 # @parm Bool bool	- 1 == highlight; 0 == clear highlight
	 # @parm Int type	- Type of highlight (color)
	 # @return void
	public method set_bg_hg {address bool type} {
		# Validate input address
		if {${::DEBUG}} {
			if {$address >= $total_capacity} {
				error "Address out of range"
			}
			if {$address != [expr {int($address)}]} {
				error "Address must be integer"
			}
			if {![string is boolean $bool]} {
				error "'$bool' in not booleand value"
			}
		}

		switch -- $type {
			0 {
				set arr {bg_hg}
				set tag {tag_bg_hg}
			}
			1 {
				set arr {bg_hg1}
				set tag {tag_bg_hg1}
			}
			2 {
				set arr {bg_hg2}
				set tag {tag_bg_hg2}
			}
		}
		if {[subst -nocommands "\$${arr}($address)"] == $bool} {
			return
		}
		set ${arr}($address) $bool

		# Local variables
		set index	[address_to_index $address]	;# (Auxiliary variable)
		set row		[lindex $index 0]		;# Cell row
		set cell	[lindex $index 1]		;# Cell number in the row
		set start_col	[lindex $index 2]		;# Starting column
		set end_col	[lindex $index 3]		;# End column

		# Create highlight
		if {$bool} {
			set bool {add}
		} else {
			set bool {remove}
		}
		$left_view tag $bool $tag $row.$start_col $row.$end_col
		if {$ascii_view} {
			$right_view tag $bool $tag $row.$cell "$row.$cell+1c"
		}
	}

	## Set cell highlight (as changed)
	 # @parm Int address	- Cell address
	 # @parm Bool bool	- 1 == highlight; 0 == clear highlight
	 # @return void
	public method setHighlighted {address bool} {
		# Validate input address
		if {${::DEBUG}} {
			if {$address >= $total_capacity} {
				error "Address out of range"
			}
			if {$address != [expr {int($address)}]} {
				error "Address must be integer"
			}
			if {![string is boolean $bool]} {
				error "'$bool' in not booleand value"
			}
		}

		if {$highlighted_cells($address) == $bool} {
			return
		}
		set highlighted_cells($address) $bool

		# Local variables
		set index	[address_to_index $address]	;# (Auxiliary variable)
		set row		[lindex $index 0]		;# Cell row
		set cell	[lindex $index 1]		;# Cell number in the row
		set start_col	[lindex $index 2]		;# Starting column
		set end_col	[lindex $index 3]		;# End column

		# Create highlight
		if {$bool} {
			set bool {add}
		} else {
			set bool {remove}
		}
		$left_view tag $bool tag_hg $row.$start_col $row.$end_col
		if {$ascii_view} {
			$right_view tag $bool tag_hg $row.$cell "$row.$cell+1c"
		}
	}

	## Remove all foreground highlighting tags
	 # @return void
	public method clearHighlighting {} {
		for {set i 0} {$i < $total_capacity} {incr i} {
			set highlighted_cells($i) 0
		}
		$left_view tag remove tag_hg 0.0 end
		if {$ascii_view} {
			$right_view tag remove tag_hg 0.0 end
		}
	}

	## Remove all background highlighting tags
	 # @parm Int type - Type of highlight (color)
	 # @return void
	public method clearBgHighlighting {type} {
		switch -- $type {
			0 {
				set arr {bg_hg}
				set tag {tag_bg_hg}
			}
			1 {
				set arr {bg_hg1}
				set tag {tag_bg_hg1}
			}
			2 {
				set arr {bg_hg2}
				set tag {tag_bg_hg2}
			}
		}
		for {set i 0} {$i < $total_capacity} {incr i} {
			set ${arr}($i) 0
		}
		$left_view tag remove $tag 0.0 end
		if {$ascii_view} {
			$right_view tag remove $tag 0.0 end
		}
	}

	## Get address of current cell
	 # @return Int - Address
	public method getCurrentCell {} {
		return $cursor_address
	}

	## Set current cell
	 # @parm Int address - Cell address
	 # @return void
	public method setCurrentCell {address} {
		# Check for allowed range
		if {$address >= $total_capacity} {
			return
		}

		# Local variables
		set index	[address_to_index $address]	;# (Auxiliary variable)
		set row		[lindex $index 0]		;# Cell row
		set cell	[lindex $index 1]		;# Cell number in the row
		set start_col	[lindex $index 2]		;# Cell starting column

		# Adjust cursor
		set cursor_address $address
		if {$selected_view == {left}} {
			$left_view mark set insert $row.$start_col
			$left_view see insert
			left_view_adjust_cursor
		} else {
			$right_view mark set insert $row.$cell
			$right_view see insert
			right_view_adjust_cursor
		}
	}

	## Scroll to certain cell
	 # @parm Int address - Cell address
	 # @return void
	public method seeCell {address} {
		# Check for allowed range
		if {$address >= $total_capacity} {
			return
		}

		# Local variables
		set index	[address_to_index $address]	;# (Auxiliary variable)
		set row		[lindex $index 0]		;# Cell row
		set cell	[lindex $index 1]		;# Cell number in the row
		set start_col	[lindex $index 2]		;# Cell starting column

		# Adjust cursor
		if {$selected_view == {left}} {
			$left_view see $row.$start_col
		} else {
			$right_view see $row.$cell
		}
	}

	## Bind command to pseudo-event <current_cell_changed>
	 # @parm String cmd - command to invoke from root namespace
	 #	Command invocation: eval "$cmd $cursor_address"
	 # @return void
	public method bindCurrentCellChanged {cmd} {
		set current_cell_changed_cmd_set 1
		set current_cell_changed_cmd $cmd
	}

	## Bind command to pseudo-event <cell_value_changed>
	 # @parm String cmd - command to invoke from root namespace
	 #	Command invocation: eval "$cmd $cursor_address $new_value"
	 # @return void
	public method bindCellValueChanged {cmd} {
		set cell_value_changed_cmd_set 1
		set cell_value_changed_cmd $cmd
	}

	## Bind command to pseudo-event <cell_enter>
	 # @parm String cmd - command to invoke from root namespace
	 #	Command invocation: eval "$cmd $cursor_address $X $Y"
	 # @return void
	public method bindCellEnter {cmd} {
		set cell_enter_cmd_set 1
		set cell_enter_cmd $cmd
		bind_mouse_motions
	}

	## Bind command to pseudo-event <cell_leave>
	 # @parm String cmd - command to invoke from root namespace
	 #	Command invocation: eval "$cmd"
	 # @return void
	public method bindCellLeave {cmd} {
		set cell_leave_cmd_set 1
		set cell_leave_cmd $cmd
		bind_mouse_motions
	}

	## Bind command to pseudo-event <cell_motion>
	 # @parm String cmd - command to invoke from root namespace
	 #	Command invocation: eval "$cmd $X $Y"
	 # @return void
	public method bindCellMotion {cmd} {
		set cell_motion_cmd_set 1
		set cell_motion_cmd $cmd
		bind_mouse_motions
	}

	## Bind command to pseudo-event <scroll_action>
	 # @parm String cmd - command to invoke from root namespace
	 #	Command invocation: eval "$cmd"
	 # @return void
	public method bindScrollAction {cmd} {
		set scroll_action_cmd_set 1
		set scroll_action_cmd $cmd
	}

	## Bind command to pseudo-event <selection_action>
	 # @parm String cmd - command to invoke from root namespace
	 #	Command invocation: eval "$cmd bool__something_selected_or_not"
	 # @return void
	public method bindSelectionAction {cmd} {
		set selection_action_cmd_set 1
		set selection_action_cmd $cmd
	}

	##
	 # @return
	public method getRangeOfSelection {} {
		if {[llength [$left_view tag nextrange sel 0.0]]} {
			return [list								\
				[index_to_address {left} [$left_view index sel.first+1c]]	\
				[index_to_address {left} [$left_view index sel.last-1c]]	\
			]
		} else {
			return {}
		}
	}

	## Get number of topmost visible row in both views
	 # @return Int - Row number (1st row has number 1)
	public method getTopRow {} {
		return $top_row
	}

	## Switch view mode (HEX, DEC etc.)
	 # @parm String newmode - New mode for left view (one of {hex oct dec})
	 # @return void
	public method switch_mode {newmode} {
		if {$newmode == $view_mode} {
			return
		}
		set original_mode $view_mode
		set view_mode $newmode
		switch -- $view_mode {
			{hex} {
				set new_value_length 2
				set left_view_width [expr {$width * 3 - 1}]
			}
			{oct} {
				set new_value_length 3
				set left_view_width [expr {$width * 4 - 1}]
			}
			{dec} {
				set new_value_length 3
				set left_view_width [expr {$width * 4 - 1}]
			}
			default {
				error "Invalid mode: $view_mode"
			}
		}
		switch -- $original_mode {
			{hex} {
				set value_length 2
				set skip 3
			}
			{oct} {
				set value_length 3
				set skip 4
			}
			{dec} {
				set value_length 3
				set skip 4
			}
		}

		$left_view configure -cursor watch
		$left_header configure -cursor watch
		$left_address_bar configure -cursor watch
		if {$ascii_view} {
			$right_header configure -cursor watch
			$right_view configure -cursor watch
		}
		update
		$left_view configure -width $left_view_width
		$left_header configure -width $left_view_width

		# Iterate over rows in left view
		for {set row 1} {$row <= $height} {incr row} {
			set start 0
			set end $value_length
			set values {}
			set lineend [$left_view index [list $row.0 lineend]]

			# Save line to list
			for {set cell 0} {$cell < $width} {incr cell} {
				lappend values [string trim [$left_view get $row.$start $row.$end]]
				incr start $skip
				incr end $skip
			}
			$left_view delete $row.0 $lineend

			# Convert list
			set first 1
			set space [string repeat { } $new_value_length]
			foreach val $values {
				if {!$first} {
					$left_view insert $lineend { }
				} else {
					set first 0
				}
				if {$val == {}} {
					$left_view insert $lineend $space
					continue
				} else {
					set val [string trimleft $val 0]
					if {$val == {}} {
						set val 0
					}
					switch -- $original_mode {
						{hex} {
							# HEX -> DEC
							if {$view_mode == {dec}} {
								set val [expr "0x$val"]

							# HEX -> OCT
							} else {
								set val [expr "0x$val"]
								set val [format {%o} $val]
							}
						}
						{dec} {
							# DEC -> HEX
							if {$view_mode == {hex}} {
								set val [format %X $val]

							# DEC -> OCT
							} else {
								set val [format %o $val]
							}
						}
						{oct} {
							# OCT -> HEX
							if {$view_mode == {hex}} {
								set val [expr "0$val"]
								set val [format %X $val]

							# OCT -> DEC
							} else {
								set val [expr "0$val"]
							}
						}
					}
				}

				set len [string length $val]
				if {$len < $new_value_length} {
					set len [expr {$new_value_length - $len}]
					set val "[string repeat 0 $len]$val"
				}

				$left_view insert $lineend $val
				$left_view tag add normal_font [list $lineend linestart] [list $lineend lineend]
			}
		}

		fill_left_header
		for {set i 0} {$i < $total_capacity} {incr i} {
			if {$highlighted_cells($i)} {
				set highlighted_cells($i) 0
				setHighlighted $i 1
			}
			if {$bg_hg($i)} {
				set bg_hg($i) 0
				set_bg_hg $i 1
			}
		}
		$left_view configure -cursor xterm
		$left_header configure -cursor left_ptr
		$left_address_bar configure -cursor left_ptr
		if {$ascii_view} {
			$right_header configure -cursor left_ptr
			$right_view configure -cursor xterm
		}
	}

	## Set hex editor enabled/disabled state
	 # @parm Bool bool - 1 == enabled; 0 == disabled
	 # @return void
	public method setDisabled {bool} {
		set disabled $bool

		if {$bool} {
			set state {disabled}
		} else {
			set state {normal}
		}

		# Set state for the left view
		$left_view configure -state $state
		if {$bool} {
			$left_view configure -bg {#F8F8F8} -fg {#999999}	;#DDDDDD
		} else {
			$left_view configure -bg {#FFFFFF} -fg {#000000}
		}

		# Set state for the right view
		if {$ascii_view} {
			$right_view configure -state $state
			if {$bool} {
				$right_view configure -bg {#F8F8F8} -fg {#999999}	;#DDDDDD
			} else {
				$right_view configure -bg {#FFFFFF} -fg {#000000}
			}
		}

		# Set state for certain menu entries
		$popup_menu entryconfigure [::mc "Paste"] -state $state
		$popup_menu entryconfigure [::mc "Fill with pseudo-random values"] -state $state
	}

	## Get reference of left view text widget
	 # @return Widget - Text widget
	public method getLeftView {} {
		return $left_view
	}

	## Get reference of right view text widget
	 # @return Widget - Text widget or {}
	public method getRightView {} {
		return $right_view
	}

	## Get configuration list
	 # @return List - Configuration list
	proc get_config {} {
		return [list $text_to_find $find_opt(fc) $find_opt(bw)]
	}

	## Load configuration list generated by function `get_config'
	 # @param List config - Configuration list generated by `get_config'
	 # @return void
	proc load_config_list {config_list} {
		# Load configuration
		set text_to_find	[lindex $config_list 0]
		set find_opt(fc)	[lindex $config_list 1]
		set find_opt(bw)	[lindex $config_list 2]

		# Validate loaded configuration
		if {![string is boolean -strict $find_opt(fc)]} {
			set find_opt(fc) 1
		}
		if {![string is boolean -strict $find_opt(bw)]} {
			set find_opt(bw) 0
		}
	}

	## Find next occurrence of search string
	 # @return Bool - 0 == Invalid call; 1 == Valid call
	public method find_next {} {
		if {$last_find_index == {}} {
			return 0
		}
		if {$find_opt(bw)} {
			set result [find_FIND $last_find_index-[string length $text_to_find]c]
		} else {
			set result [find_FIND $last_find_index]
		}
		return $result
	}

	## Find previous occurrence of search string
	 # @return Bool - 0 == Invalid call; 1 == Valid call
	public method find_prev {} {
		if {$last_find_index == {}} {
			return 0
		}

		set backward_org $find_opt(bw)
		set find_opt(bw) [expr {!$find_opt(bw)}]

		if {$find_opt(bw)} {
			set result [find_FIND $last_find_index-[string length $text_to_find]c]
		} else {
			set result [find_FIND $last_find_index]
		}

		set find_opt(bw) $backward_org
		return $result
	}

	## Invoke dialog: Find string
	 # @return Bool - 1 == string found; 0 == string not found
	public method find_dialog {} {
		# Remove previous find dialog windows
		if {[winfo exists $find_dialog_win]} {
			destroy $find_dialog_win
		}

		# Create toplevel find_dialog_window
		incr find_dialog_count
		set find_dialog_win [toplevel .hex_editor_find_dialog_$find_dialog_count]

		## Create top frame
		set top_frame [frame $find_dialog_win.top_frame]
		 # Text to find
		grid [label $top_frame.string_lbl	\
			-text [mc "Text to find"]	\
		] -row 0 -column 0 -columnspan 4 -sticky w
		grid [ttk::entry $top_frame.string_entry	\
			-textvariable ::HexEditor::text_to_find	\
			-width 0				\
		] -row 1 -column 1 -sticky we -columnspan 3
		 # Where
		grid [label $top_frame.where_lbl	\
			-text [mc "Where"]		\
		] -row 2 -column 0 -columnspan 2 -sticky w
		grid [radiobutton $top_frame.radio_0		\
			-variable ::HexEditor::where_to_search	\
			-text [mc "Left view"] -value left	\
		] -row 3 -column 1 -sticky w
		grid [radiobutton $top_frame.radio_1		\
			-variable ::HexEditor::where_to_search	\
			-text [mc "Right view"] -value right	\
		] -row 4 -column 1 -sticky w
		set ::HexEditor::where $selected_view
		if {!$ascii_view} {
			$top_frame.radio_1 configure -state disabled
		}
		 # Options
		grid [label $top_frame.options_lbl	\
			-text [mc "Options"]		\
		] -row 2 -column 2 -columnspan 2 -sticky w
		grid [checkbutton $top_frame.opt_fc_chb		\
			-variable ::HexEditor::find_opt(fc)	\
			-onvalue 1 -offvalue 0			\
			-text [mc "From cursor"]		\
		] -row 3 -column 3 -sticky w
		grid [checkbutton $top_frame.opt_bw_chb		\
			-variable ::HexEditor::find_opt(bw)	\
			-onvalue 1 -offvalue 0			\
			-text [mc "Backwards"]			\
		] -row 4 -column 3 -sticky w

		# Finalize top frame creation
		grid columnconfigure $top_frame 0 -minsize 25
		grid columnconfigure $top_frame 1 -weight 1
		grid columnconfigure $top_frame 2 -minsize 25
		grid columnconfigure $top_frame 3 -weight 1

		# Create and pack 'OK' and 'CANCEL' buttons
		set buttonFrame [frame $find_dialog_win.button_frame]
		pack [ttk::button $buttonFrame.ok		\
			-text [mc "Ok"]			\
			-compound left			\
			-image ::ICONS::16::ok		\
			-command "$this find_FIND"	\
		] -side left -padx 2
		pack [ttk::button $buttonFrame.cancel		\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command "$this find_CANCEL"		\
		] -side left -padx 2

		# Events binding (Enter == Find; Escape == Cancel)
		bind $find_dialog_win <KeyRelease-Return>	"$this find_FIND; break"
		bind $find_dialog_win <KeyRelease-KP_Enter>	"$this find_FIND; break"
		bind $find_dialog_win <KeyRelease-Escape>	"$this find_CANCEL; break"

		# Pack dialog frames
		pack $top_frame -fill both -anchor nw -padx 5 -pady 5
		pack $buttonFrame -side bottom -anchor e -padx 5 -pady 5

		# Window manager options -- modal find_dialog_window
		wm iconphoto $find_dialog_win ::ICONS::16::find
		wm title $find_dialog_win [mc "Find"]
		wm minsize $find_dialog_win 260 140
		wm transient $find_dialog_win $main_frame
		wm protocol $find_dialog_win WM_DELETE_WINDOW "
			grab release $find_dialog_win
			destroy $find_dialog_win
		"
		update
		grab $find_dialog_win
		$top_frame.string_entry selection range 0 end
		focus -force $top_frame.string_entry

		tkwait window $find_dialog_win
		if {$last_find_index == {}} {
			return 0
		} else {
			return 1
		}
	}

	# -------------------------------------------------------------------
	# HELPER PROCEDURES
	# -------------------------------------------------------------------

	## Initiate serach
	 # @return void
	public method find_FIND args {
		# Determinate search options
		set start_index [lindex $args 0]
		if {$where_to_search == {left}} {
			set widget $left_view
		} else {
			set widget $right_view
		}
		if {$find_opt(bw)} {
			set direction {-backwards}
		} else {
			set direction {-forwards}
		}
		if {$start_index == {}} {
			if {$find_opt(fc)} {
				set start_index [$widget index insert]
			} else {
				set start_index 1.0
			}
		}

		# Perform search
		set last_find_index [$widget search $direction -nocase -- $text_to_find $start_index]

		# String found
		if {$last_find_index != {}} {
			$popup_menu entryconfigure [::mc "Find next"] -state normal
			$popup_menu entryconfigure [::mc "Find previous"] -state normal
			catch {
				$widget tag remove sel 0.0 end
			}
			set end_idx $last_find_index+[string length $text_to_find]c
			$widget tag add sel $last_find_index $end_idx
			$widget mark set insert $end_idx
			$widget see $end_idx
			set last_find_index $end_idx
			set result 1

		# String not found
		} else {
			$popup_menu entryconfigure [::mc "Find next"] -state disabled
			$popup_menu entryconfigure [::mc "Find previous"] -state disabled

			if {[winfo exists $find_dialog_win]} {
				set parent $find_dialog_win
			} else {
				set $main_frame
			}
			tk_messageBox		\
				-parent $parent	\
				-type ok	\
				-icon warning	\
				-title [mc "String not found"]	\
				-message [mc "Search string '%s' not found !" $text_to_find]
			set result 0
		}

		# Close find dialog
		if {[winfo exists $find_dialog_win]} {
			find_CANCEL
		}

		return $result
	}

	## Close find dialog
	 # @return void
	public method find_CANCEL {} {
		grab release $find_dialog_win
		destroy $find_dialog_win
	}
}

## Initialize NS variables
 # Find options
array set ::HexEditor::find_opt {
	fc 1
	bw 0
}

# >>> File inclusion guard
}
# <<< File inclusion guard

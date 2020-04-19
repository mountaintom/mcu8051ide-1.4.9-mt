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
if { ! [ info exists _HEXEDITDLG_TCL ] } {
set _HEXEDITDLG_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Prodides hexadecimal editor for external data and program memory.
# This editor uses dynamic data loading.
# --------------------------------------------------------------------------

class HexEditDlg {
	public common count		0	;# Instance counter
	public common win_pos		{+0+0}	;# Window position (+X+Y)
	public common mode		{hex}	;# View mode {hex dec oct}
	public common cell		{0}	;# Current cell (0 - 0xFFFF)
	public common current_view	{left}	;# Focused view {left right}
	# Font for mode combobox
	public common mode_cb_font	[font create			\
		-family {Helvetica}				\
		-size [expr {int(-17 * $::font_size_factor)}]	\
		-weight bold					\
	]
	# General normal size bold font
	public common bold_font	[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
	]
	# Status bar tips for main menu for XDATA mode
	public common HELPFILE_XDATA {
		{
			{Load IHEX8 file into editor and simulator XDATA memory}
			{}
			{Save current content of XDATA memory to IHEX8 file}
			{Save current document under a different name}
			{}
			{Reload data from simulator XDATA memory}
			{}
			{Exit editor}
		} {
			{Copy selected text to clipboard}
			{Paste clipboard contents}
			{}
			{}
			{Invoke dialog for searching strings in the text}
			{Find next occurrence of the search string}
			{Find previous occurrence of the search string}
		} {
			{Switch view mode to hexadecimal}
			{Switch view mode to decimal}
			{Switch view mode to octal}
		}
	}
	# Status bar tips for main menu for CODE mode
	public common HELPFILE_CODE {
		{
			{Load IHEX8 file into editor and simulator XDATA memory}
			{Save current content of program (CODE) memory to IHEX8 file}
			{}
			{Save}
			{Save current document under a different name}
			{}
			{Exit editor}
		} {
			{Copy selected text to clipboard}
			{Paste clipboard contents}
			{}
			{}
			{Invoke dialog for searching strings in the text}
			{Find next occurrence of the search string}
			{Find previous occurrence of the search string}
		} {
			{Switch view mode to hexadecimal}
			{Switch view mode to decimal}
			{Switch view mode to octal}
		}
	}

	## PRIVATE
	private variable project			;# Object: Project realted to this editor
	private variable type				;# String: HexEditor type (one of {xdata code})
	private variable hexeditor			;# Object: Hexadecimal editor pseudowidget
	private variable win				;# Widget: Dialog toplevel window
	private variable mainmenu			;# ID of dialog main menu
	private variable edit_menu			;# ID of dialog edit menu
	private variable mode_combo_box			;# ID of mode combobox
	private variable right_sbar_label		;# ID of right label on dialog status bar
	private variable middle_sbar_label		;# ID of middle label on dialog status bar
	private variable left_sbar_label		;# ID of left label on dialog status bar
	private variable current_cell			;# Current cell (0 - 0xFFFF)
	private variable validation_ena		0	;# Bool: EntryBox validation enable
	private variable dec_val_entry			;# EntryBox: Value - Decimal
	private variable oct_val_entry			;# EntryBox: Value - Octal
	private variable hex_val_entry			;# EntryBox: Value - Hexadecimal
	private variable bin_val_entry			;# EntryBox: Value - Binary
	private variable dec_addr_entry			;# EntryBox: Address - Decimal
	private variable oct_addr_entry			;# EntryBox: Address - Octal
	private variable hex_addr_entry			;# EntryBox: Address - Hexadecimal
	private variable bin_addr_entry			;# EntryBox: Address - Binary
	private variable sub_call_but			;# Button: Call subprogram
	private variable prg_jump_but			;# Button: Perform program jump
	private variable obj_idx			;# Index of the current instance
	private variable loaded_lines		{}	;# Map of loaded lines (for dynamic data loading)
	private variable opened_file		{}	;# Name of opened file
	private variable modified		0	;# Bool: fag modified
	private variable capacity		0	;# Int: Memory capacity
	private variable last_PC		-1	;# Int: Last position of PC pointer
	private variable last_PC_length		0	;# Int: Length of the last PC pointer
	private variable last_PC_d		-1	;# Int: Last position of PC pointer (func move_program_pointer_directly)
	private variable last_PC_length_d	0	;# Int: Length of the last PC pointer (func move_program_pointer_directly)
	private variable pre_last_PC		-1	;# Int: Last value of $last_PC
	private variable pre_last_PC_length	0	;# Int: Last value of $last_PC_length

	## Object constructor
	 # @parm Object _project	- Parent project
	 # @parm String _type		- Type of contents (one of {xdata code eram eeprom uni})
	constructor {_project _type} {
		# Initalize object variables
		set project	$_project
		set type	$_type
		set obj_idx	$count
		set win		[toplevel .hexeditdlg${obj_idx} -class {Hex Editor} -bg ${::COMMON_BG_COLOR}]
		set loaded_lines [string repeat [string repeat 0 0xFF] 0xFF]

		incr count	;# Increment instance counter

		# Determinate memory capacity
		switch -- $type {
			{code} {
				set capacity	[$project cget -P_option_mcu_xcode]
				incr capacity [expr {[lindex [$project cget -procData] 2] * 1024}]
			}
			{xdata} {
				set capacity	[$project cget -P_option_mcu_xdata]
			}
			{eram}	{
				set capacity [lindex [$project cget -procData] 8]
			}
			{eeprom} {
				set capacity [lindex [$project cget -procData] 32]
			}
			{uni} {
				set capacity 0x10000
			}
		}

		# Create dialog frames
		set tool_bar_frame	[frame $win.tool_bar]		;# Toolbar
		set middle_frame	$win.middle_frame		;# Left view and right view
		set bottom_frame	[frame $win.bottom_frame]	;# EntryBoxes: Value & Address
		set statusbar_frame	[frame $win.statusbar_frame]	;# Dialog statusbar

		# Create dialog componets
		create_status_bar $statusbar_frame
		create_main_menu
		create_tool_bar $tool_bar_frame
		create_middle_bottom_frame $middle_frame $bottom_frame
		create_main_win_bindings

		# Add items "LJMP" and "LCALL" to popup menu
		if {$type == {code}} {
			if {[$project is_frozen]} {
				set state normal
			} else {
				set state disabled
			}

			[$hexeditor get_popup_menu] add separator
			[$hexeditor get_popup_menu] add command -label [mc "LJMP this_address"]	\
				-underline 1 -command "$this prog_jump" -state $state		\
				-compound left -image ::ICONS::16::exec
			[$hexeditor get_popup_menu] add command -label [mc "LCALL this_address"]\
				-underline 1 -command "$this sub_call" -state $state		\
				-compound left -image ::ICONS::16::exec
		}

		# Load data from simulator engine to current visible area
		load_data_to_current_view

		# Fill EntryBoxes
		if {$cell >= $capacity} {
			set current_cell [expr {$capacity - 1}]
		} else {
			set current_cell $cell
		}
		set value [$hexeditor get_values $current_cell $current_cell]
		fill_entries {} val $value
		fill_entries {} addr $current_cell
		set validation_ena 1

		# Pack dialog frames
		pack $tool_bar_frame -fill x -anchor w -padx 3
		pack $middle_frame -anchor nw -after $tool_bar_frame -pady 10
		pack $bottom_frame -anchor w -after $middle_frame
		pack $statusbar_frame -side bottom -fill x -after $bottom_frame

		# Set window title
		if {$type == {code}} {
			set window_icon {kcmmemory_C}
			wm title $win "[mc {Code memory}] - $project - MCU 8051 IDE"
		} elseif {$type == {eram}} {
			set window_icon {kcmmemory_E}
			wm title $win "[mc {Expanded RAM}] - $project - MCU 8051 IDE"
		} elseif {$type == {eeprom}} {
			set window_icon {kcmmemory_P}
			wm title $win "[mc {Data EEPROM}] - $project - MCU 8051 IDE"
		} elseif {$type == {xdata}} {
			set window_icon {kcmmemory_X}
			wm title $win "[mc {XDATA memory}] - $project - MCU 8051 IDE"
		} else {
			set window_icon {ascii}
			wm title $win "[mc {untitled}] - [mc {Hexadecimal editor}] - MCU 8051 IDE"
		}

		# Set window geometry
		wm resizable $win 0 0
		if {$mode == {hex}} {
			wm geometry $win ${win_pos}
		} else {
			wm geometry $win ${win_pos}
		}

		# Finalize window configuration
		wm iconphoto $win ::ICONS::16::$window_icon
		if {$type == {uni}} {
			wm protocol $win WM_DELETE_WINDOW "$this quit"
		} else {
			wm protocol $win WM_DELETE_WINDOW	\
				[list ::X::close_hexedit $type $project]
		}
	}

	## Object destructor
	destructor {
		# Save current window parameters
		set win_pos [wm geometry $win]
		set win_pos [split $win_pos {+}]
		set win_pos "+[lindex $win_pos 1]+[lindex $win_pos 2]"
		set cell [$hexeditor getCurrentCell]
		set current_view [$hexeditor getCurrentView]

		# Remove dialog window and uset its variables
		destroy $win
		unset ::HexEditDlg::dec_val_${obj_idx}
		unset ::HexEditDlg::hex_val_${obj_idx}
		unset ::HexEditDlg::oct_val_${obj_idx}
		unset ::HexEditDlg::bin_val_${obj_idx}
		unset ::HexEditDlg::dec_addr_${obj_idx}
		unset ::HexEditDlg::hex_addr_${obj_idx}
		unset ::HexEditDlg::oct_addr_${obj_idx}
		unset ::HexEditDlg::bin_addr_${obj_idx}
		unset ::HexEditDlg::mode_${obj_idx}
	}

	## Create key event bindings for dialog window
	 # @return void
	private method create_main_win_bindings {} {
		foreach widget [list $win [$hexeditor getLeftView] [$hexeditor getRightView]] {
			bind $widget <Control-Key-o>	"$this openhex;	break"
			bind $widget <Control-Key-s>	"$this save;	break"
			bind $widget <Control-Key-S>	"$this saveas;	break"
			bind $widget <Key-F5>		"$this reload;	break"
			bind $widget <Control-Key-q>	"$this quit;	break"
		}
	}

	## Create main dialog menu
	 # @return voi
	private method create_main_menu {} {
		## Create menu widgets
		 # Main
		set mainmenu	[menu $win.mainmenu	\
			-bd 0 -tearoff 0 -bg ${::COMMON_BG_COLOR}	\
			-activeforeground {#6666FF}	\
			-activebackground ${::COMMON_BG_COLOR}	\
		]
		set file_menu	[menu $mainmenu.file_menu -tearoff 0]	;# Main -> File
		set edit_menu	[menu $mainmenu.edit_menu -tearoff 0]	;# Main -> Edit
		set mode_menu	[menu $mainmenu.mode_menu -tearoff 0]	;# Main -> Mode

		# Create menu event bindings for purpose of status bar tips
		bind $file_menu <<MenuSelect>> "$this menu_sbar_show 0 \[%W index active\]"
		bind $edit_menu <<MenuSelect>> "$this menu_sbar_show 1 \[%W index active\]"
		bind $mode_menu <<MenuSelect>> "$this menu_sbar_show 2 \[%W index active\]"
		bind $file_menu <Leave> "$this sbar_show {}"
		bind $edit_menu <Leave> "$this sbar_show {}"
		bind $mode_menu <Leave> "$this sbar_show {}"

		# Create File menu
		if {$type == {code}} {
			$file_menu add command -label [mc "Open ADF"] -compound left	\
				-command "$this opensim" -underline 0			\
				-image ::ICONS::16::fileopen
		}
		$file_menu add command -label [mc "Open IHEX8"] -compound left	\
			-accelerator "Ctrl+O" -command "$this openhex"		\
			-image ::ICONS::16::fileopen -underline 1
		$file_menu add separator
		$file_menu add command -label [mc "Save"] -compound left	\
			-accelerator "Ctrl+S" -command "$this save"		\
			-image ::ICONS::16::filesave -underline 0
		$file_menu add command -label [mc "Save as"] -compound left	\
			-accelerator "Ctrl+Shift+S" -command "$this saveas"	\
			-image ::ICONS::16::filesaveas -underline 1
		$file_menu add separator
		if {$type != {code}} {
			$file_menu add command -label [mc "Reload"] -compound left	\
				-accelerator "F5" -command "$this reload"		\
				-image ::ICONS::16::reload -underline 1
			$file_menu add separator
		}
		$file_menu add command -label [mc "Exit"] -compound left	\
			-accelerator "Ctrl+Q" -command "$this quit"		\
			-image ::ICONS::16::exit -underline 1

		# Create Edit menu
		$edit_menu add command -label [mc "Copy"] -compound left	\
			-accelerator "Ctrl+C" -command "$this text_copy"	\
			-image ::ICONS::16::editcopy -underline 0
		$edit_menu add command -label [mc "Paste"] -compound left	\
			-accelerator "Ctrl+V" -command "$this text_paste"	\
			-image ::ICONS::16::editpaste -underline 0
		$edit_menu add separator
		$edit_menu add command -label [mc "Find"] -compound left		\
			-accelerator "Ctrl+F" -command "$this find_string 0"		\
			-image ::ICONS::16::find -underline 0
		$edit_menu add command -label [mc "Find next"] -compound left		\
			-accelerator "F3" -command "$this find_string 1"		\
			-image ::ICONS::16::1downarrow -underline 5
		$edit_menu add command -label [mc "Find previous"] -compound left	\
			-accelerator "Shift+F3" -command "$this find_string 2"		\
			-image ::ICONS::16::1uparrow -underline 8

		# Create Mode menu
		set ::HexEditDlg::mode_${obj_idx} $mode
		$mode_menu add radiobutton -label [mc "HEX"]			\
			-variable ::HexEditDlg::mode_${obj_idx}			\
			-indicatoron 0 -compound left -image ::ICONS::raoff	\
			-selectimage ::ICONS::raon -value {hex} -underline 0	\
			-command [list $this adjust_mode]
		$mode_menu add radiobutton -label [mc "DEC"]			\
			-variable ::HexEditDlg::mode_${obj_idx}			\
			-indicatoron 0 -compound left -image ::ICONS::raoff	\
			-selectimage ::ICONS::raon -value {dec} -underline 0	\
			-command [list $this adjust_mode]
		$mode_menu add radiobutton -label [mc "OCT"]			\
			-variable ::HexEditDlg::mode_${obj_idx}			\
			-indicatoron 0 -compound left -image ::ICONS::raoff	\
			-selectimage ::ICONS::raon -value {oct} -underline 0	\
			-command [list $this adjust_mode]

		# Create Main menu
		$mainmenu add cascade -label [mc "File"] -underline 0 -menu $file_menu
		$mainmenu add cascade -label [mc "Edit"] -underline 0 -menu $edit_menu
		$mainmenu add cascade -label [mc "Mode"] -underline 0 -menu $mode_menu
		$win configure -menu $mainmenu
	}

	## Create dialog toolbar
	 # @parm Widget frame -target frame
	 # @return void
	private method create_tool_bar {frame} {
		# Create toolbar frame
		set toolbar_frame [frame $frame.toolbar]
		# - Button "Open Hex"
		pack [ttk::button $toolbar_frame.openhex	\
			-command "$this openhex"		\
			-image ::ICONS::22::fileopen		\
			-style Flat.TButton			\
		] -side left -padx 2
		DynamicHelp::add $toolbar_frame.openhex -text [mc "Load IHEX8 file"]
		set_sbar_tip $toolbar_frame.openhex [mc "Open file"]
		# - Separator
		pack [ttk::separator $toolbar_frame.sep0	\
			-orient vertical			\
		] -side left -padx 4 -fill y -expand 1
		# - Button "Save"
		pack [ttk::button $toolbar_frame.save	\
			-command "$this save"		\
			-image ::ICONS::22::filesave	\
			-style Flat.TButton		\
		] -side left -padx 2
		DynamicHelp::add $toolbar_frame.save -text [mc "Save current data to IHEX8 file"]
		set_sbar_tip $toolbar_frame.save [mc "Save file"]
		# - Button "Save as"
		pack [ttk::button $toolbar_frame.saveas	\
			-command "$this saveas"		\
			-image ::ICONS::22::filesaveas	\
			-style Flat.TButton		\
		] -side left -padx 2
		DynamicHelp::add $toolbar_frame.saveas -text [mc "Save current data to IHEX8 file under a different name"]
		set_sbar_tip $toolbar_frame.saveas [mc "Save as"]
		# - Separator
		pack [ttk::separator $toolbar_frame.sep1	\
			-orient vertical			\
		] -side left -padx 4 -fill y -expand 1
		if {$type != {code}} {
			# - Button "Reload"
			pack [ttk::button $toolbar_frame.reload	\
				-command "$this reload"		\
				-image ::ICONS::22::reload	\
				-style Flat.TButton		\
			] -side left -padx 2
			DynamicHelp::add $toolbar_frame.reload -text [mc "Reload data from simulator"]
			set_sbar_tip $toolbar_frame.reload [mc "Reload"]
			# - Separator
			pack [ttk::separator $toolbar_frame.sep2	\
				-orient vertical			\
			] -side left -padx 4 -fill y -expand 1
		}
		# - Button "Exit"
		pack [ttk::button $toolbar_frame.exit	\
			-style Flat.TButton		\
			-command "$this quit"		\
			-image ::ICONS::22::exit	\
		] -side left -padx 2
		DynamicHelp::add $toolbar_frame.exit -text [mc "Exit editor"]
		set_sbar_tip $toolbar_frame.exit [mc "Exit"]

		pack $toolbar_frame -side left -anchor w

		# - Mode ComboBox
		set mode_combo_box [ttk::combobox $frame.mode_cb	\
			-values {HEX DEC OCT}				\
			-state readonly					\
			-font $mode_cb_font				\
			-width 4					\
		]
		bind $mode_combo_box <<ComboboxSelected>> [list $this switch_mode]
		DynamicHelp::add $mode_combo_box -text [mc "Current view mode"]
		set_sbar_tip $frame.mode_cb	\
			[mc "View mode"]
		$mode_combo_box current [lsearch {hex dec oct} $mode]
		pack $mode_combo_box -side right -anchor e -fill y -expand 0
	}

	## Set status tip for the given widget
	 # @parm Widget wdg - Target widget
	 # @parm String txt - Status tip
	 # @return void
	private method set_sbar_tip {wdg txt} {
		bind $wdg <Enter> [list $this sbar_show $txt]
		bind $wdg <Leave> [list $this sbar_show {}]
	}

	## Create hex editor and entryboxes for address and value
	 # @parm Widget middle_frame - Frame for hex editor
	 # @parm Widget bottom_frame - Frame for entryboxes
	 # @return void
	private method create_middle_bottom_frame {middle_frame bottom_frame} {
		## Create and configure HexEditor
		set hg [expr {$capacity / 16}]
		if {[expr {$capacity % 16}]} {
			incr hg
		}
		set hexeditor [HexEditor editor${obj_idx} $middle_frame 16 $hg 4 $mode 1 0 16 $capacity]
		if {$current_view == {left}} {
			$hexeditor focus_left_view
		} else {
			$hexeditor focus_right_view
		}
		$hexeditor setCurrentCell $cell
		$hexeditor bindCellEnter "$this change_right_stat_bar_addr"
		$hexeditor bindCellLeave "$this change_right_stat_bar_addr {}"
		$hexeditor bindCurrentCellChanged "$this current_cell_changed"
		$hexeditor bindCellValueChanged "$this cell_value_changed"
		$hexeditor bindScrollAction "$this load_data_to_current_view"

		# Create labelframes for Value & Address
		set value_lframe [ttk::labelframe $bottom_frame.value_label_frame	\
			-text [mc "VALUE"] -padding 5					\
		]
		set address_lframe [ttk::labelframe $bottom_frame.address_label_frame	\
			-text [mc "ADDRESS"] -padding 5					\
		]

		# Create entryboxes
		set i 0
		set width [list 4 4 9 9 8 8 17 17]
		foreach valtype {val addr} frm [list $value_lframe $address_lframe] {
			foreach radix {dec oct hex bin} {
				set ${radix}_${valtype}_entry [ttk::entry $frm.${radix}_${valtype}_entry	\
					-width [lindex $width $i]						\
					-validate all								\
					-textvariable ::HexEditDlg::${radix}_${valtype}_${obj_idx}		\
					-validatecommand [list $this validate_entry ${valtype} ${radix} %P]	\
				]
				bindtags $frm.${radix}_${valtype}_entry	\
					[list $frm.${radix}_${valtype}_entry TEntry $win all .]
				incr i
			}
		}

		# Pack entry boxes and create labels for them
		grid [label $value_lframe.dec_label -text [mc "DEC: "]] -row 0 -column 0
		grid [label $value_lframe.oct_label -text [mc "OCT: "]] -row 1 -column 0
		grid [label $value_lframe.hex_label -text [mc "HEX: "]] -row 0 -column 3
		grid [label $value_lframe.bin_label -text [mc "BIN: "]] -row 1 -column 3
		grid $dec_val_entry -row 0 -column 1 -sticky e
		grid $oct_val_entry -row 1 -column 1 -sticky e
		grid $hex_val_entry -row 0 -column 4 -sticky e
		grid $bin_val_entry -row 1 -column 4 -sticky e
		grid columnconfigure $value_lframe 2 -minsize 10

		grid [label $address_lframe.dec_label -text [mc "DEC: "]] -row 0 -column 0
		grid [label $address_lframe.oct_label -text [mc "OCT: "]] -row 1 -column 0
		grid [label $address_lframe.hex_label -text [mc "HEX: "]] -row 0 -column 3
		grid [label $address_lframe.bin_label -text [mc "BIN: "]] -row 1 -column 3
		grid $dec_addr_entry -row 0 -column 1 -sticky e
		grid $oct_addr_entry -row 1 -column 1 -sticky e
		grid $hex_addr_entry -row 0 -column 4 -sticky e
		grid $bin_addr_entry -row 1 -column 4 -sticky e
		grid columnconfigure $address_lframe 2 -minsize 10

		# Create buttons "Call" and "Jump"
		if {$type == {code}} {
			if {[$project is_frozen]} {
				set state normal
			} else {
				set state disabled
			}

			set prg_jump_but [ttk::button $address_lframe.prg_jump_but	\
				-text [mc "LJMP"]					\
				-state $state						\
				-command "$this prog_jump"				\
				-width 6						\
			]
			DynamicHelp::add $prg_jump_but -text [mc "Perform program jump"]
			set_sbar_tip $prg_jump_but [mc "Program jump"]
			set sub_call_but [ttk::button $address_lframe.sub_call_but	\
				-text [mc "LCALL"]					\
				-state $state						\
				-command "$this sub_call"				\
				-width 6						\
			]
			DynamicHelp::add $sub_call_but -text [mc "Perform subprogram call"]
			set_sbar_tip $sub_call_but [mc "Subprogram call"]

			grid [ttk::separator $address_lframe.sep -orient vertical]	\
				-row 0 -column 5 -sticky ns -padx 5 -rowspan 2
			grid $prg_jump_but -row 0 -column 6 -sticky we
			grid $sub_call_but -row 1 -column 6 -sticky we
		}

		pack $value_lframe -side left -padx 10
		pack $address_lframe -side left -padx 10
	}

	## Create dialog status bar
	 # @parm Widget frame - Frame for the status bar
	 # @return void
	private method create_status_bar {frame} {
		# Create status bar labels
		set left_sbar_label	[label $frame.left -anchor w]
		set middle_sbar_label	[Label $frame.middle]
		set right_sbar_label	[label $frame.right	\
			-fg {#0000FF} -font $bold_font -width 6	\
		]

		# Set filename to "untitled" if editor is universal
		$middle_sbar_label configure -text {untitled}

		# Pack status bar labels
		pack $left_sbar_label -side left -fill x -expand 1 -anchor w
		pack $middle_sbar_label -side left -fill none -anchor w -after $left_sbar_label -padx 10
		pack [label $frame.left_left	\
			-text [mc "Cursor:"]	\
			-font $bold_font	\
			-fg {#555555}		\
		] -side left -after $middle_sbar_label
		pack $right_sbar_label -side left -after $frame.left_left

		# Set status tips for right part of the status bar
		set_sbar_tip $frame.left_left	[mc "Address of entry under mouse cursor"]
		set_sbar_tip $right_sbar_label	[mc "Address of entry under mouse cursor"]

		# Initialize pointer address display
		change_right_stat_bar_addr {}
	}

	## Write value to simulator engine and synchronize with all watchers
	 # @parm Int addr	- Target address
	 # @parm int val	- Register value
	 # @return void
	private method write_to_simulator {addr val} {
		if {$type == {uni}} {
			return
		}

		# XRAM or ERAM
		if {$type != {code}} {
			set hex_addr [format "%X" $addr]
			set len [string length $hex_addr]
			if {$len < 4} {
				set hex_addr "[string repeat 0 [expr {4 - $len}]]$hex_addr"
			}
			if {$type == {xdata}} {
				$project setXdataDEC $addr $val
			} elseif {$type == {eeprom}} {
				$project setEepromDEC $addr $val
			} else {
				$project setEramDEC $addr $val
			}
			$project rightPanel_watch_sync $hex_addr

		# Code memory
		} else {
			$project setCodeDEC $addr $val
		}
	}

	## Set flag modified and adjust dialog window title
	 # @parm Bool bool - New flag value
	 # @return void
	private method setModified {bool} {
		if {$opened_file == {} || $modified == $bool} {
			return
		}
		set modified $bool
		if {$modified} {
			wm title $win "\[modified\] [wm title $win]"
		} else {
			wm title $win [string range [wm title $win] 11 end]
		}
	}


	## Parse given data (IHEX-8 and load it into the editor + sync with external components)
	 # @parm String hex_data - input data
	 # @return Bool - 1 == success; 0 == failure
	private method readHex {hex_data} {
		# Any EOL -> LF
		regsub -all {\r\n?} $hex_data "\n" hex_data
		# Split by lines
		set hex_data [split $hex_data "\n"]

		# Local variables
		set pointer		0	;# Current address
		set line_number		0	;# Number of the current line
		set errors_count	0	;# Number of errors occurred while parsing ihex file
		set eof			0	;# Bool: EOF detected
		set error_string	{}	;# Text of error message

		# Clear current data
		if {$type != {code} && $type != {uni}} {
			if {$type == {xdata}} {
				for {set i 0} {$i < $capacity} {incr i} {
					$project setXdataDEC $i 0
				}
			} elseif {$type == {eram}} {
				for {set i 0} {$i < $capacity} {incr i} {
					$project setEramDEC $i 0
				}
			}
			$project rightPanel_watch_sync_all
		}

		# Iterate over data lines
		foreach line $hex_data {
			incr line_number

			# Skip comments
			if {[string index $line 0] != {:}} {continue}

			# Check for allowed characters
			if {![regexp {^:[0-9A-Fa-f]+$} $line]} {
				incr errors_count
				append error_string [mc "Line\t%s:\tInvalid characters\n"] $line_number
				continue
			}

			# Local variables
			set check	[string range $line {end-1} end]	;# Control count
			set line	[string range $line 1 {end-2}]		;# Whole line (just without Control count)
			set data	[string range $line 8 end]		;# Data
			set len		[string range $line 0 1]		;# Length of data
			set addr	[string range $line 2 5]		;# Address
			set rectype	[string range $line 6 7]		;# Record type

			# Convert address and length to decimal
			set addr [expr "0x$addr"]
			set len [expr "0x$len"]

			# Check for valid control count
			if {$check != [::IHexTools::getCheckSum $line]} {
				incr errors_count
				append error_string [mc "Line\t%s:\tInvalid chceksum\n" $line_number]
				continue
			}
			# Check for valid lenght
			if {($len * 2) != [string bytelength $data]} {
				incr errors_count
				append error_string [mc "Line\t%s:\tInvalid length\n" $line_number]
				continue
			}
			# Check for supported record types
			if {$rectype == {01}} {
				set eof 1
				break
			}
			if {$rectype != {00}} {
				incr errors_count
				append error_string [mc "Line\t%s:\tUnknown record type: '%s'\n" $line_number $rectype]
				continue
			}

			# Set current address
			set pointer $addr
			if {$pointer >= $capacity} {
				break
			}

			# Parse data field
			set len [expr {$len * 2}]
			for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {
				set number [string range $data $i $j]
				if {$type == {uni}} {
					$hexeditor setValue $pointer [expr "0x$number"]
				} else {
					write_to_simulator $pointer [expr "0x$number"]
				}
				incr pointer
			}
		}

		# Append error if there is no EOF
		if {!$eof} {
			incr errors_count
			append error_string [mc "Line\t%s:\tMissing EOF" [expr {$line_number + 1}]]
		}

		# Invoke error dialog
		if {$errors_count} {
			# Create dialog window
			set dialog [toplevel $win.error_message_dialog -bg ${::COMMON_BG_COLOR}]

			# Create main frame (text widget and scrolbar)
			set main_frame [frame $dialog.main_frame]

			# Create text widget
			set text [text $main_frame.text				\
				-yscrollcommand "$main_frame.scrollbar set"	\
				-bg {#FFFFFF} -width 0 -height 0		\
			]
			pack $text -side left -fill both -expand 1
			# Create scrollbar
			pack [ttk::scrollbar $main_frame.scrollbar	\
				-orient vertical		\
				-command "$text yview"		\
			] -side right -fill y

			# Pack main frame and create button "Close"
			pack $main_frame -fill both -expand 1
			pack [ttk::button $dialog.ok_button				\
				-text [mc "Close"]					\
				-command "
					grab release $dialog
					destroy $dialog
				"	\
			]

			# Show error string and disable the text widget
			$text insert end $error_string
			$text configure -state disabled

			# Set window attributes
			wm iconphoto $dialog ::ICONS::16::no
			wm title $dialog [mc "Error(s) occurred while parsing IHEX file"]
			wm minsize $dialog 500 250
			wm protocol $dialog WM_DELETE_WINDOW "grab release $dialog; destroy $dialog"
			wm transient $dialog $win
			grab $dialog
			raise $dialog
			tkwait window $dialog
			return 0
		} else {
			return 1
		}
	}

	## Synchronize all EntryBoxes with the given value
	 # @parm String exclude	- Name entry to exclude from synchronization {dec hex oct bin}
	 # @parm String valtype	- Value type (one of {val addr}) (Value | Address)
	 # @parm Int value	- Value  (must be in decimal)
	 # @return void
	private method fill_entries {exclude valtype value} {
		# Determinate maximum value length (number of digits)
		if {$valtype == {val}} {
			set hexlen 2
			set octlen 3
			set binlen 8
		} else {
			set hexlen 4
			set octlen 7
			set binlen 16
		}

		# Empty value -> clear entry boxes
		if {$value == {}} {
			set hex {}
			set oct {}
			set bin {}
		# Non empty value -> convert
		} else {
			# To hexadecimal
			set hex [format %X $value]
			set len [string length $hex]
			if {$len != $hexlen} {
				set hex "[string repeat {0} [expr {$hexlen - $len}]]$hex"
			}

			# To octal
			set oct [format %o $value]
			set len [string length $oct]
			if {$len != $octlen} {
				set oct "[string repeat {0} [expr {$octlen - $len}]]$oct"
			}

			# To binary
			set bin [NumSystem::dec2bin $value]
			set len [string length $bin]
			if {$len < $binlen} {
				set bin "[string repeat {0} [expr {$binlen - $len}]]$bin"
			}
		}

		# Synchronize EntryBoxes
		if {$valtype == {val}} {
			if {$exclude != {dec}} {
				set ::HexEditDlg::dec_val_${obj_idx} $value
			}
			if {$exclude != {hex}} {
				set ::HexEditDlg::hex_val_${obj_idx} $hex
			}
			if {$exclude != {oct}} {
				set ::HexEditDlg::oct_val_${obj_idx} $oct
			}
			if {$exclude != {bin}} {
				set ::HexEditDlg::bin_val_${obj_idx} $bin
			}
		} else {
			if {$exclude != {dec}} {
				set ::HexEditDlg::dec_addr_${obj_idx} $value
			}
			if {$exclude != {hex}} {
				set ::HexEditDlg::hex_addr_${obj_idx} $hex
			}
			if {$exclude != {oct}} {
				set ::HexEditDlg::oct_addr_${obj_idx} $oct
			}
			if {$exclude != {bin}} {
				set ::HexEditDlg::bin_addr_${obj_idx} $bin
			}
		}
	}

	## Change content of cursor address display on status bar
	 # @parm Mixed args - [lindex $args 0] == Decimal address
	 # @return void
	public method change_right_stat_bar_addr args {
		set address [lindex $args 0]

		# Empty address
		if {$address == {}} {
			$right_sbar_label configure -text "  --- "
			return
		}

		# Non empty address -> convert to HEX and display
		set address [format %X $address]
		set len [string length $address]
		if {$len < 4} {
			set address "[string repeat {0} [expr {4 - $len}]]$address"
		}
		$right_sbar_label configure -text "0x$address"
	}

	## Adjust view mode to content of mode combobox
	 # @return void
	public method switch_mode {} {
		set mode [lindex {hex dec oct} [$mode_combo_box current]]
		set ::HexEditDlg::mode_${obj_idx} $mode
		sbar_show {Working ...}
		update
		$hexeditor switch_mode $mode
		sbar_show {}
	}

	## This method should be called after value change in hex editor
	 # This method writes new value to simulator engine, watchers and EntryBoxes
	 # @parm Int addr	- Address of changed cell
	 # @parm int val	- New value of the entry
	 # @return void
	public method cell_value_changed {addr val} {
		set current_cell $addr
		set validation_ena 0
		fill_entries {} val $val
		write_to_simulator $addr $val
		setModified 1
		set validation_ena 1
	}

	## This method should be called after current cell change in hex editor
	 # Synchronizes EntryBoxes
	 # @parm Int addr - New cell address
	 # @return void
	public method current_cell_changed {addr} {
		set validation_ena 0
		set current_cell $addr
		set value [$hexeditor get_values $addr $addr]
		fill_entries {} val $value
		fill_entries {} addr $addr
		set validation_ena 1
	}

	## Validate content of EntryBox in bottom frame
	 # + Synchronize value with all others (if valid)
	 # @parm String valtype - Value type (Address {addr} | Value {val})
	 # @parm String radix	- Number base (one of {oct hex dec bin})
	 # @parm String value	- Value to validate (and synchronize)
	 # @return void
	public method validate_entry {valtype radix value} {
		# If validation is disabled or value is empty -> abort
		if {!$validation_ena || $value == {}} {
			return 1
		}

		# Check for valid characters
		if {$valtype == {val}} {
			set m 1
		} else {
			set m 2
		}
		set len [string length $value]
		switch -- $radix {
			{dec} {
				if {$len > (3 * $m) || ![string is digit $value]} {
					return 0
				}
			}
			{hex} {
				if {$len > (2 * $m) || ![string is xdigit $value]} {
					return 0
				}
			}
			{oct} {
				if {!$len > (3 * $m) || [regexp {^[0-7]+$} $value]} {
					return 0
				}
			}
			{bin} {
				if {$len > (8 * $m) || ![regexp {^[01]+$} $value]} {
					return 0
				}
			}
		}

		# Tempotary disable validations (to prevent infinite event loops)
		set validation_ena 0

		# Convert value to decimal
		set value [string trimleft $value 0]
		if {$value == {}} {
			set value 0
		}
		switch -- $radix {
			{hex} {
				set value [expr "0x$value"]
			}
			{oct} {
				set value [expr "0$value"]
			}
			{bin} {
				set value [NumSystem::bin2dec $value]
			}
		}

		# Check for allowed value range
		if {$valtype == {val}} {
			if {$value > 255} {
				set validation_ena 1
				return 0
			}
		} else {
			if {$value >= $capacity} {
				set validation_ena 1
				return 0
			}
		}

		# Synchronize with all other
		fill_entries $radix $valtype $value
		if {$valtype == {val}} {
			$hexeditor setValue $current_cell $value
			write_to_simulator $current_cell $value
		} else {
			set current_cell $value
			$hexeditor setCurrentCell $value
		}

		# Set flag modified + Reenable validations
		setModified 1
		set validation_ena 1

		return 1
	}

	## Perform program jump
	 # @return void
	public method prog_jump {} {
		if {$type != {code}} {return}
		$project setPC [subst -nocommands "\$::HexEditDlg::dec_addr_${obj_idx}"]
		set lineNum [$project simulator_getCurrentLine]
		if {$lineNum != {}} {
			$project move_simulator_line $lineNum
		} else {
			$project editor_procedure {} unset_simulator_line {}
		}
		$project Simulator_sync_PC_etc
	}

	## Perform subprogram call
	 # @return void
	public method sub_call {} {
		if {$type != {code}} {return}
		$project simulator_subprog_call [subst -nocommands "\$::HexEditDlg::dec_addr_${obj_idx}"]
		set lineNum [$project simulator_getCurrentLine]
		if {$lineNum != {}} {
			$project move_simulator_line $lineNum
		} else {
			$project editor_procedure {} unset_simulator_line {}
		}
		$project Simulator_sync_PC_etc
	}

	## Adjust view mode to state of mode menu
	 # @return void
	public method adjust_mode {} {
		$mode_combo_box current [lsearch {hex dec oct} [subst -nocommands "\$::HexEditDlg::mode_${obj_idx}"]]
		sbar_show {Working ...}
		update
		$hexeditor switch_mode [subst -nocommands "\$::HexEditDlg::mode_${obj_idx}"]
		sbar_show {Working}
	}

	## Quit dialog
	 # @return void
	public method quit {} {
		if {$modified} {
			set response [tk_messageBox	\
				-parent $win		\
				-type yesnocancel	\
				-icon question		\
				-title [mc "File modified"]	\
				-message [mc "File %s has been modifed.\nDo you want to save it ?" [file tail $opened_file]]]
			if {$response == {yes}} {
				save
			} elseif {$response != {no}} {
				return
			}
		}
		if {$type == {uni}} {
			delete object $this
		} else {
			::X::close_hexedit $type $project
		}
	}

	## Show status tip for menu entry
	 # @parm Int help_file_index	- Menu index
	 # @parm Int entry_index	- Entry index
	 # @return void
	public method menu_sbar_show {help_file_index entry_index} {
		# Validate input data
		if {![string is digit $entry_index]} {
			$left_sbar_label configure -text {}
			return
		}
		if {![string is digit $help_file_index]} {
			$left_sbar_label configure -text {}
			return
		}

		# Show status tip
		if {$type == {code}} {
			$left_sbar_label configure -text	\
				[mc [lindex $HELPFILE_CODE [list $help_file_index $entry_index]]]
		} else {
			$left_sbar_label configure -text	\
				[mc [lindex $HELPFILE_XDATA [list $help_file_index $entry_index]]]
		}
	}

	## Load data from simulator engine to current visible area
	 # @return void
	public method load_data_to_current_view {} {
		if {$type == {uni}} {return}

		# Local variables
		set startrow	[$hexeditor getTopRow]			;# Start row
		set endrow	[expr {$startrow + 15}]			;# End row
		set startaddr	[expr {$startrow * 16}]			;# Start address for 1st row
		set endaddr	[expr {($startrow + 1) * 16 - 1}]	;# End address for 1st row

		# Determinate command to gain data
		if {$type == {code}} {
			set cmd {getCodeDEC}
		} elseif {$type == {xdata}} {
			set cmd {getXdataDEC}
		} elseif {$type == {eeprom}} {
			set cmd {getEepromDEC}
		} else {
			set cmd {getEramDEC}
		}

		# Iterate over visible rows and load data to them
		for {set row $startrow} {$row <= $endrow} {incr row} {
			if {[string index $loaded_lines $row] == 1} {
				incr startaddr	16
				incr endaddr	16
				continue
			}

			for {set addr $startaddr} {$addr <= $endaddr} {incr addr} {
				if {$addr >= $capacity} {
					break
				}
				$hexeditor setValue $addr [$project $cmd $addr]
			}

			incr startaddr	16
			incr endaddr	16
		}

		# Adjust map of loaded lines
		set loaded_lines [string replace $loaded_lines $startrow $endrow [string repeat 1 16]]
	}

	## Show text in status bar
	 # @parm String text - Text to show
	 # @return void
	public method sbar_show {text} {
		$left_sbar_label configure -text $text
	}

	## Action for Menu/Toolbar - Copy
	 # Invoke dialog "Find string"
	 # @return void
	public method text_copy {} {
		$hexeditor text_copy
	}

	## Action for Menu/Toolbar - Paste
	 # Invoke dialog "Find string"
	 # @return void
	public method text_paste {} {
		$hexeditor text_paste
	}

	## Action for Menu/Toolbar - "Find" or "Find next" or "Find previous"
	 # Invoke dialog "Find string"
	 # @return void
	public method find_string {action} {
		switch -- $action {
			0 {$hexeditor find_dialog}
			1 {$hexeditor find_next}
			2 {$hexeditor find_prev}
		}
	}

	## Action for Menu/Toolbar - Reload
	 # Reload content of HexEditor
	 # @return void
	public method reload {} {

		if {$modified} {
			set response [tk_messageBox	\
				-parent $win		\
				-type yesno		\
				-icon warning		\
				-title [mc "File modified"]	\
				-message [mc "Content of the hex editor has been changed.\nDo you really want to reload without saving it?"]]
			if {$response == {no}} {
				return
			}
		}

		# Store original cursor position
		set current_cursor_pos [$hexeditor getCurrentCell]

		if {$type != {xdata} && $type != {uni}} {return}
		if {$type == {uni}} {
			set ext [string replace [file extension $opened_file] 0 0]
			if {$ext != {} && $opened_file != {}} {
				open_file $opened_file $ext
			}
		} else {
			refresh
		}

		# Restore original cursor position
		update
		$hexeditor setCurrentCell $current_cursor_pos
		$hexeditor seeCell $current_cursor_pos
	}

	## Action for Menu/Toolbar - Save as
	 # Save current content of hex editor as IHEX8 file and ask for file name
	 # @return void
	public method saveas {} {
		set directory [file dirname $opened_file]
		if {$type == {uni}} {
			if {${::X::project_menu_locked}} {
				set project {}
			} else {
				set project ${::X::actualProject}
			}
		}
		if {$directory == {.}} {
			if {$project == {}} {
				set directory ${::X::defaultDirectory}
			} else {
				set directory [$project cget -projectPath]
			}
		}
		catch {delete object fsd}
		KIFSD::FSD fsd	 				\
			-title [mc "Save file - MCU 8051 IDE"]	\
			-master $win				\
			-directory $directory			\
			-initialfile [$middle_sbar_label cget -text]			\
			-defaultmask 0 -multiple 0 -filetypes [list			\
				[list [mc "Intel 8 HEX"]	{*.{hex,ihx}}	]	\
				[list [mc "All files"]		{*}		]	\
			]
		fsd setokcmd "$this save_file_proc \[::HexEditDlg::fsd get\]"
		fsd activate
	}

	## Action for Menu/Toolbar - Save
	 # Save current content of the editor to $opened_file
	 # @return void
	public method save {} {
		if {$opened_file == {}} {
			saveas
			return
		}
		save_file_proc $opened_file
	}

	## Action for Menu/Toolbar - Open Hex
	 # @return void
	public method openhex {} {
		set directory [file dirname $opened_file]
		if {$type == {uni}} {
			if {${::X::project_menu_locked}} {
				set project {}
			} else {
				set project ${::X::actualProject}
			}
		}
		if {$directory == {.}} {
			if {$project == {}} {
				set directory ${::X::defaultDirectory}
			} else {
				set directory [$project cget -projectPath]
			}
		}
		catch {delete object fsd}
		KIFSD::FSD fsd	 				\
			-title [mc "Open file - MCU 8051 IDE"]	\
			-master $win -directory $directory	\
			-defaultmask 0 -multiple 0 -filetypes [list			\
				[list [mc "Intel 8 HEX"]	{*.{hex,ihx}}	]	\
				[list [mc "All files"]		{*}		]	\
			]
		fsd setokcmd "$this open_file \[::HexEditDlg::fsd get\] hex"
		fsd activate
	}

	## Action for Menu/Toolbar - Open Adb
	 # @return void
	public method opensim {} {
		if {$type != {code}} {return}
		set directory [file dirname $opened_file]
		if {$directory == {.}} {
			set directory [$project cget -projectPath]
		}
		catch {delete object fsd}
		KIFSD::FSD fsd	 				\
			-title [mc "Open file - MCU 8051 IDE"]	\
			-master $win -directory $directory	\
			-defaultmask 0 -multiple 0 -filetypes [list		\
				[list [mc "Simulator file"]	{*.adb}	]	\
				[list [mc "All files"]		{*}	]	\
			]
		fsd setokcmd "$this open_file \[::HexEditDlg::fsd get\] adf"
		fsd activate
	}

	## Open the give file and load its contents into editor
	 # @parm String filename	- Relative or absolute filename
	 # @parm String extension	- Fily type {adf hex}
	 # @return Bool - 1 == success; 0 == failure
	public method open_file {filename extension} {
		# Store original cursor position
		set current_cursor_pos [$hexeditor getCurrentCell]

		# Normalize filename
		set filename [file normalize $filename]
		set directory [file dirname $filename]
		if {$type == {uni}} {
			if {${::X::project_menu_locked}} {
				set project {}
			} else {
				set project ${::X::actualProject}
			}
		}
		if {$directory == {.}} {
			if {$project == {}} {
				set directory ${::X::defaultDirectory}
			} else {
				set directory [$project cget -projectPath]
			}
		}
		if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
			if {![regexp "^(~|/)" $filename]} {
				set filename "$directory/$filename"
			}
		} else {	;# Microsoft windows way
			if {![regexp {^\w:} $filename]} {
				set filename [file join $directory $filename]
			}
		}

		# Open file
		if {[catch {
			set file [open $filename r]
		}]} then {
			tk_messageBox		\
				-parent $win	\
				-type ok	\
				-icon warning	\
				-title [mc "Permission denied"]	\
				-message [mc "Unable to open file:\n%s" $filename]
			return 0
		}

		# Clear editor
		if {$type == {uni}} {
			$hexeditor fill_views
		} else {
			$project simulator_clear_memory $type
		}

		# Load contents
		if {$extension == {adf}} {
			$project load_program_from_adf $filename
		} else {
			readHex [read $file]
		}

		# Finalize
		close $file
		set_filename $filename
		refresh

		# Restore original cursor position
		update
		$hexeditor setCurrentCell $current_cursor_pos
		$hexeditor seeCell $current_cursor_pos

		return 1
	}

	## Save content of the editor into the given file in format IHEX8
	 # @parm String filename - target filename
	 # @return void
	public method save_file_proc {filename} {
		# Adjust filename
		set filename [file normalize $filename]
		set directory [file dirname $filename]
		set rootname $filename
		if {$type == {uni}} {
			if {${::X::project_menu_locked}} {
				set project {}
			} else {
				set project ${::X::actualProject}
			}
		}
		if {$directory == {.}} {
			if {$project == {}} {
				set directory ${::X::defaultDirectory}
			} else {
				set directory [$project cget -projectPath]
			}
		}
		if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
			if {![regexp "^(~|/)" $filename]} {
				set filename "$directory/$filename"
			}
		} {	;# Microsoft windows way
			if {![regexp {^\w:} $filename]} {
				set filename [file join $directory $filename]
			}
		}

		# Adjust file extension
		if {![regexp {\.(hex|ihx)$} $filename]} {
			if {$type != {code} && $type != {uni} } {
				append filename {.xdata.hex}
			} else {
				append filename {.hex}
			}
		}

		if {[file exists $filename]} {
			# Check if the file is writable
			if {![file writable $filename]} {
				tk_messageBox -type ok -icon error -title [mc "Permission denied"]	\
					-message [mc "Unable to access file: %s" $filename] -parent $win
				return
			}
			# Ask user for overwrite existing file
			if {[tk_messageBox	\
				-type yesno	\
				-icon question	\
				-parent $win	\
				-title [mc "Overwrite file"]	\
				-message [mc "A file name '%s' already exists. Are you sure you want to overwrite it ?" [file tail $filename]]
				] != {yes}
			} then {
				return
			}
			# Create a backup file
			catch {
				file rename -force $filename "$filename~"
			}
		}

		# Write filename on statusbar
		set_filename $filename

		if {$type == {xdata}} {
			set getDataCommand {getXdata}

		} elseif {$type == {eram}} {
			set getDataCommand {getEram}

		} elseif {$type == {eeprom}} {
			set getDataCommand {getEeprom}

		} else {
			set getDataCommand {getCode}
		}

		# Open file
		if {[catch {
			set file [open $filename w 0640]
		}]} then {
			tk_messageBox		\
				-parent $win	\
				-type ok	\
				-icon warning	\
				-title [mc "Permission denied"]	\
				-message [mc "Unable to open file:\n%s" $filename]
			return
		}

		# Determinate number of 2048 B blocks
		set maximum [expr {$capacity / 2048 + 1}]

		# Create progress dialog
		set ::X::saving_progress 0
		set ::X::abort_saving 0

		create_progress_bar .prgDl	\
			$win			\
			{}			\
			"Saving: $rootname"	\
			::X::saving_progress	\
			$maximum		\
			[mc "Saving file"]	\
			::ICONS::16::filesave	\
			[mc "Abort"]		\
			{set ::X::abort_saving 1}

		# Local variables
		set addr 0			;# Address
		set len 0			;# Length
		set data {}			;# Data field
		set pointer -1			;# Current address

		# $maximum* update Progress Dialog
		for {set i 0} {$i < $maximum} {incr i} {

			# Create 8*32 IHEX records
			for {set j 0} {$j < 2048} {incr j} {

				# Increment address pointer
				incr pointer
				if {$pointer >= $capacity} {
					break
				}

				# Get register value
				set code [$hexeditor get_values $pointer $pointer]
				if {$code != {}} {
					set code [format {%X} $code]
					if {[string length $code] == 1} {
						set code "0$code"
					}
				}

				# If buffer is full -> create record
				if {$code == {} || $len == 255} {
					# Save record
					if {$len != 0} {
						puts -nonewline $file {:}
						puts $file [createHexRecord	\
							[format "%X" $len]	\
							[format "%X" $addr]	\
							00 $data		\
						]
					}
					# Reset some variables related to the last record
					set addr $pointer
					incr addr
					set len 0
					set data {}
					if {$len != 255} {continue}
				}

				# Increment length field and append register value to data field
				incr len
				append data $code
			}

			# Update Progress Dialog
			incr ::X::saving_progress
			update
			# Optionaly abort
			if {${::X::abort_saving}} {
				set abort_saving 0
				destroy .prgDl
				return
			}
		}

		# Destroy Progress Dialog
		catch {destroy .prgDl}

		# Save the last (incomplete) record
		if {$len != 0} {
			puts -nonewline $file {:}
			puts $file [::HexEditDlg::createHexRecord	\
				[format "%X" $len] [format "%X" $addr] 00 $data]
		}

		# Save EOF
		puts $file {:00000001FF}

		# Done ...
		close $file
		setModified 0
		if {$::MICROSOFT_WINDOWS} { ;# "/" --> "\"
			regsub -all {/} $filename "\\" filename
		}
		sbar_show [mc "File %s saved" $filename]
	}

	## Create Intel HEX 8 field
	 # @parm String len	- field length	(max. 2 hex digits)
	 # @parm String addr	- field address	(max. 4 hex digits)
	 # @parm String type	- field type	(exaclty 2 hex digits (eg. '00' or '01'))
	 # @parm String data	- data		(even number of hex digits, max. 512)
	 # @return String - Intel HEX 8 field
	proc createHexRecord {len addr rectype data} {
		# Adjust length
		if {[string length $len] == 1} {set len "0$len"}
		# Adjust address
		set addr_len [string length $addr]
		if {$addr_len < 4} {
			set addr "[string repeat 0 [expr {4 - $addr_len}]]$addr"
		}
		# Create field
		set result "${len}${addr}${rectype}"
		append result $data
		# Compute control count (see Compiler)
		append result [::IHexTools::getCheckSum $result]
		# Return result
		return $result
	}

	# -------------------------------------------------------------------
	# GENERAL PUBLIC INTERFACE
	# -------------------------------------------------------------------

	## Inform hex editor about simulator start or shutdown
	 # @parm Bool started - 1 == Simulator started; 0 == Simulator stopped
	 # @return void
	public method simulator_stared_stopped {started} {
		if {$type != {code}} {
			return
		}

		if {$started} {
			set state {normal}
		} else {
			set state {disabled}
		}
		$sub_call_but configure -state $state
		$prg_jump_but configure -state $state
		[$hexeditor get_popup_menu] entryconfigure [::mc "LJMP this_address"] -state $state
		[$hexeditor get_popup_menu] entryconfigure [::mc "LCALL this_address"] -state $state
	}

	## Move program pointer (highlight cells)
	 # -- available only for code memory hex editor
	 # @parm Int new_PC	- New program counter
	 # @parm Int int_length	- Instruction length
	 # @return void
	public method move_program_pointer {new_PC int_length} {
		if {$type != {code}} {
			return
		}

		if {$pre_last_PC > -1} {
			for {set i 0} {$i < $pre_last_PC_length} {incr i} {
				$hexeditor set_bg_hg $pre_last_PC 0 1
				incr pre_last_PC
			}
		}
		set pre_last_PC $last_PC
		set pre_last_PC_length $last_PC_length

		if {$last_PC > -1} {
			for {set i 0} {$i < $last_PC_length} {incr i} {
				$hexeditor set_bg_hg $last_PC 1 1
				$hexeditor set_bg_hg $last_PC 0 2
				incr last_PC
			}
		}

		set last_PC_length_d 0
		set last_PC_d -1
		set last_PC_length $int_length
		set last_PC $new_PC

		for {set i 0} {$i < $int_length} {incr i} {
			$hexeditor set_bg_hg $new_PC 1 2
			$hexeditor set_bg_hg $new_PC 0 1
			incr new_PC
		}
		$hexeditor seeCell $new_PC
	}

	## Directly move program pointer (do not affect previous PC pointer)
	 # -- available only for code memory hex editor
	 # @parm Int new_PC	- New program counter (-1 == unresolved)
	 # @parm Int int_length	- Instruction length
	 # @return void
	public method move_program_pointer_directly {new_PC int_length} {
		if {$type != {code}} {
			return
		}

		if {$last_PC_d > -1} {
			for {set i 0} {$i < $last_PC_length_d} {incr i} {
				$hexeditor set_bg_hg $last_PC_d 0 0
				incr last_PC_d
			}
		}
		if {$new_PC == -1} {
			set last_PC_length_d 0
			set last_PC_d -1
			return
		}
		set last_PC_length_d $int_length
		set last_PC_d $new_PC

		for {set i 0} {$i < $int_length} {incr i} {
			$hexeditor set_bg_hg $new_PC 1 0
			incr new_PC
		}
		$hexeditor seeCell $new_PC
	}

	## Clear highlight for all cells in the editor
	 # @return void
	public method clear_highlight {} {
		$hexeditor clearHighlighting
	}

	## Set background highlight
	 # @parm Int addr	- Cell address
	 # @parm Bool bool	- 1 == Set; 0 == Clear
	 # @return void
	public method set_bg_hg_clr {addr bool} {
		$hexeditor set_bg_hg $addr $bool 0
	}

	## Write value to the editor
	 # - available only in modes: XDATA and ERAM
	 # @parm String address	- hexadecimal address
	 # @return void
	public method reg_sync {address} {
		if {$type == {code}} {
			return
		}

		set address [expr "0x$address"]
		if {$type == {xdata}} {
			set val [$project getXdataDEC $address]
		} elseif {$type == {eeprom}} {
			set val [$project getEepromDEC $address]
		} else {
			set val [$project getEramDEC $address]
		}
		set org_val [$hexeditor get_values $address $address]
		$hexeditor setValue $address $val
		if {$org_val != $val} {
			$hexeditor setHighlighted $address 1
		}
		if {$address == $current_cell} {
			set validation_ena 0
			fill_entries {} val $val
			set validation_ena 1
		}
		setModified 1
	}

	## Reload content of the editor
	 # @return void
	public method refresh {} {
		if {$type == {uni}} {return}

		set loaded_lines [string repeat [string repeat 0 0xFF] 0xFF]
		load_data_to_current_view
		setModified 0
	}

	## Get configuration list
	 # @return List - config list for procedure loadConfig
	proc getConfig {} {
		return [list $win_pos $mode $cell $current_view [::HexEditor::get_config]]
	}

	## Load config list (result of procedure getConfig)
	 # @parm List - config list
	 # @return void
	proc loadConfig {config} {
		# Parse config list
		set win_pos		[lindex $config 0]
		set mode		[lindex $config 1]
		set cell		[lindex $config 2]
		set current_view	[lindex $config 3]

		# load configuration for hex editor widget
		::HexEditor::load_config_list [lindex $config 4]

		# Validate loaded values
		if {![regexp {^\+\d+\+\d+$} $win_pos]} {
			puts stderr "Invalid value of key win_pos (`$win_pos')"
			set win_pos {+0+0}
		}
		if {$mode != {hex} && $mode != {dec} && $mode != {oct}} {
			puts stderr "Invalid value of key mode (`$mode')"
			set mode {hex}
		}
		if {![string is digit -strict $cell]} {
			puts stderr "Invalid value of key cell (`$cell')"
			set cell 0
		}
		if {$current_view != {left} && $current_view != {right}} {
			puts stderr "Invalid value of key current_view (`$current_view')"
			set current_view {left}
		}
	}

	## Set name of current file (for purpose of saving and for status bar)
	 # @parm String filename - Full filename
	 # @return void
	public method set_filename {filename} {
		set opened_file $filename

		set filename [file tail $filename]
		$middle_sbar_label configure -text $filename -helptext $opened_file
		if {$type == {uni}} {
			if {$modified} {
				wm title $win "\[modified\] $filename - [mc {Hexadecimal editor}] - MCU 8051 IDE"
			} else {
				wm title $win "$filename - [mc {Hexadecimal editor}] - MCU 8051 IDE"
			}
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

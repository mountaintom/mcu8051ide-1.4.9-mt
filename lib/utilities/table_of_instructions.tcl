#!/usr/bin/tclsh
# Part of MCU 8051 IDE ( http://http://www.moravia-microsystems.com/mcu8051ide )

############################################################################
#    Copyright (C) 2011 by Martin Ošmera                                   #
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
if { ! [ info exists _TABLE_OF_INSTRUCTIONS_TCL ] } {
set _TABLE_OF_INSTRUCTIONS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# 8051 Instruction Table
# --------------------------------------------------------------------------

class TableOfInstructions {
	public common tbl_of_inst_count 0		;# Int: Counter of object instances
	public common oprs_color	{#00DD00}	;# RGB Color: Number of operands
	public common len_color	{#00AA55}	;# RGB Color: Instruction length
	public common time_color	{#8800DD}	;# RGB Color: Time to execute
	public common ins_color	{#0000DD}	;# RGB Color: Instruction mnemonics

	# Font for instruction name
	public common instruction_font [font create			\
		-family {helvetica}				\
		-size [expr {int(-10 * $::font_size_factor)}]	\
	]
	# Font for numbers below the instruction name
	public common number_font [font create				\
		-family {helvetica}				\
		-size [expr {int(-10 * $::font_size_factor)}]	\
		-weight {bold}					\
	]
	# Font for labels in details frame (normal)
	public common details_n_font [font create			\
		-family {helvetica}				\
		-size [expr {int(-12 * $::font_size_factor)}]	\
	]
	# Font for labels in details frame (bold)
	public common details_b_font [font create			\
		-family {helvetica}				\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight {bold}					\
	]

	private variable win			;# Widget: Dialog window
	private variable window_visible	0	;# Bool: Visibility flag
	private variable cells			;# Array of Widget: Chart cell frames
	private variable vh_cells		;# Array of Widget: Vertical headers
	private variable hh_cells		;# Array of Widget: Horizontal headers
	private variable selected_cell	-1	;# Int: Currently selected cell
	private variable status_bar_lbl		;# Widget: Status bar
	private variable validation_ena	1	;# Bool: EntryBox validation enabled
	private variable matrix_frame		;# Widget: Frame for the chart
	private variable vertical_scrollbar	;# Widget: Scrollbar for the scrollable frame
	private variable scrollable_frame	;# Widget: Scrollable frame containing the chart

	private variable opcode_ent		;# Widget: Entry box with the OP code
	private variable title_v_lbl		;# Widget: Label containing instruction name along with its operands
	private variable class_v_lbl		;# Widget: Label containing the class
	private variable desc_v_lbl		;# Widget: Label containing the description
	private variable length_v_lbl		;# Widget: Label containing the length
	private variable time_v_lbl		;# Widget: Label containing the time
	private variable flags_v_lbl		;# Widget: Label containing the flags
	private variable note_v_lbl		;# Widget: Label containing the note

	constructor {} {
		# Configure local ttk styles
		ttk::style configure TblOfIns_RedBg.TEntry	-fieldbackground {#FFDDDD}
		ttk::style configure TblOfIns_GreenBg.TEntry	-fieldbackground {#DDFFDD}

		# Create dialog window
		set window_visible 1
		set win [toplevel .tableofinstructions${tbl_of_inst_count}  -class {8051 Instruction Table} -bg ${::COMMON_BG_COLOR}]
		incr tbl_of_inst_count

		# Create dialog GUI
		create_gui

		# Set window event bindings
		bind $win <Control-Key-q> "$this close_window; break"
		bindtags $win [list $win Toplevel all .]

		# Set window parameters
		wm iconphoto $win ::ICONS::16::fsview
		wm title $win "[mc {8051 Instruction Table}] - MCU 8051 IDE"
		wm resizable $win 0 1
		wm protocol $win WM_DELETE_WINDOW "$this close_window"
		update

		# Compute required width of the window
		set w [winfo width $matrix_frame.hh_lbl1]
		incr w [winfo width $vertical_scrollbar]
		for {set i 0} {$i < 16} {incr i} {
			incr w [winfo width $matrix_frame.cell_$i]
			incr w
		}
		wm minsize $win $w 400
	}

	destructor {
		destroy $win
	}

	## Determinate wheather the window is visble or not
	 # @return Bool - Visibility flag
	public method is_visible {} {
		return $window_visible
	}

	## Raise dialog window (insure than it is visible)
	 # @return void
	public method raise_window {} {
		if {!$window_visible} {return}
		raise $win .
	}

	## Restore dialog window
	 # @return void
	public method restore_window {} {
		set window_visible 1
		wm deiconify $win
		raise $win .
	}

	## Close dialog window, but keep object
	 # @return void
	public method close_window {} {
		set window_visible 0
		wm withdraw $win
	}

	## Create window GUI
	 # @return void
	private method create_gui {} {
		## Create bottom frame
		set bottom_frame [frame $win.bottom_frame]
		set status_bar_lbl [label $bottom_frame.status_bar_lbl -justify left -anchor w]
		pack $status_bar_lbl -side left -fill x -in $bottom_frame -padx 5
		pack [ttk::button $bottom_frame.close_but	\
			-text [mc "Exit"]			\
			-command "$this close_window"		\
			-compound left				\
			-image ::ICONS::16::exit		\
		] -side right -padx 5 -pady 5

		## Create main frame
		set main_frame [frame $win.main_frame -bg ${::COMMON_BG_COLOR}]
		set scrollable_frame [ScrollableFrame $main_frame.scrollable_frame	\
			-bg ${::COMMON_BG_COLOR}					\
			-yscrollcommand "$main_frame.vertical_scrollbar set"		\
		]
		set matrix_frame [$scrollable_frame getframe]
		bind $matrix_frame <Button-5> "$scrollable_frame yview scroll +1 units; break"
		bind $matrix_frame <Button-4> "$scrollable_frame yview scroll -1 units; break"
		set vertical_scrollbar [ttk::scrollbar $main_frame.vertical_scrollbar	\
			-orient vertical -command "$main_frame.scrollable_frame yview"	\
		]
		 # Create vertical header
		set header [list {}			\
			{0x0_} {0x1_} {0x2_} {0x3_}	\
			{0x4_} {0x5_} {0x6_} {0x7_}	\
			{0x8_} {0x9_} {0xA_} {0xB_}	\
			{0xC_} {0xD_} {0xE_} {0xF_}	\
		]
		grid [frame $matrix_frame.top_right_lbl -bg ${::COMMON_BG_COLOR}] -sticky wens -row 0 -column 0
		for {set y 1} {$y < 17} {incr y} {
			grid [label $matrix_frame.vh_lbl$y -text [lindex $header $y] -bg {#FFFFFF}] \
				-row $y -column 0 -pady [expr {$y % 2}] -sticky wens
			set vh_cells([expr {$y - 1}]) $matrix_frame.vh_lbl$y
		}
		 # Create horizontal header
		set header [list {}			\
			{0x_0} {0x_1} {0x_2} {0x_3}	\
			{0x_4} {0x_5} {0x_6} {0x_7}	\
			{0x_8} {0x_9} {0x_A} {0x_B}	\
			{0x_C} {0x_D} {0x_E} {0x_F}	\
		]
		for {set x 1} {$x < 17} {incr x} {
			grid [label $matrix_frame.hh_lbl$x -text [lindex $header $x] -bg {#FFFFFF}] \
				-row 0 -column $x -padx [expr {$x % 2}] -sticky wens
			set hh_cells([expr {$x - 1}]) $matrix_frame.hh_lbl$x
		}
		 # Create instruction table
		set address -1
		for {set y 1} {$y < 17} {incr y} {
			for {set x 1} {$x < 17} {incr x} {
				incr address

				# Create cell frame
				set frame [frame $matrix_frame.cell_$address	\
					-bg white -bd 0				\
				]

				# Get instruction OP code in 2-digits uppercase hexadecimal form
				set opcode [convert_to_opcode $address]

				# Handle undefined OP codes (0xA5)
				if {[lsearch -ascii -exact ${::CompilerConsts::defined_OPCODE} $opcode] == -1} {
					destroy $frame
					continue
				}

				# Get some information about the instruction
				set def $::CompilerConsts::Opcode($opcode)
				set instruction	[string toupper [lindex $def 0]]
				set operands	[llength [lindex $def 1]]
				set length	[lindex $def 2]
				set time	[lindex $def 4]

				# Create label containing instruction name
				pack [label $frame.ins_lbl	\
					-text $instruction	\
					-fg $ins_color		\
					-bg white		\
					-pady 0			\
					-font $instruction_font	\
				]

				# Create label widgets for numbers belowe instruction name
				set f [frame $frame.f]
				foreach val [list $operands	$length		$time		] \
					wdg [list oprs_lbl	len_lbl		time_lbl	] \
					fg  [list $oprs_color	$len_color	$time_color	] \
				{
					pack [label $frame.$wdg		\
						-text $val		\
						-fg $fg			\
						-bg white		\
						-pady 0			\
						-font $number_font	\
					] -side left
				}
				pack $f

				grid $frame -row $y -column $x -padx [expr {$x % 2}] -pady [expr {$y % 2}] -sticky wens
				set cells($address) $frame
				foreach wdg [list $frame $frame.f $frame.ins_lbl $frame.oprs_lbl $frame.len_lbl $frame.time_lbl] {
					bind $wdg <Enter> "$this cell_enter $address"
					bind $wdg <Leave> "$this cell_leave $address"
					bind $wdg <Button-1> "$this cell_click $address; focus $frame"

					bind $wdg <Button-5> "$scrollable_frame yview scroll +1 units; break"
					bind $wdg <Button-4> "$scrollable_frame yview scroll -1 units; break"
				}

				if {$address < 255} {
					bind $frame <Key-Right> [list $this cell_click [expr {$address + 1}]]
				}
				if {$address > 0} {
					bind $frame <Key-Left> [list $this cell_click [expr {$address - 1}]]
				}
				if {$address > 16} {
					bind $frame <Key-Up> [list $this cell_click [expr {$address - 16}]]
				}
				if {$address < 240} {
					bind $frame <Key-Down>  [list $this cell_click [expr {$address + 16}]]
				}
			}
		}
		# Ensure than all cells have the same width and heigh
		for {set i 0} {$i < 17} {incr i} {
			grid columnconfigure $matrix_frame $i -uniform toi
		}
		for {set i 1} {$i < 17} {incr i} {
			grid rowconfigure $matrix_frame $i -uniform toi
		}

		# Create middle frame (contains details and legend)
		set middle_frame [frame $win.middle_frame]

		## Create legend
		set legend_frame [frame $middle_frame.legend_frame]
		grid [label $legend_frame.l_h	\
			-font $instruction_font	\
			-text "Legend:"		\
		] -column 0 -row 0 -columnspan 2 -sticky w
		 # Instruction mnemonics
		grid [label $legend_frame.l03	\
			-fg $ins_color		\
			-bg $ins_color		\
			-text {X}		\
			-font $number_font	\
		] -column 0 -row 1 -sticky w -padx 2
		grid [label $legend_frame.l13	\
			-text [mc "Mnemonics"]	\
			-font $number_font	\
		] -column 1 -row 1 -sticky w
		 # Number of operands
		grid [label $legend_frame.l00	\
			-fg $oprs_color		\
			-bg $oprs_color		\
			-text {X}		\
			-font $number_font	\
		] -column 0 -row 2 -sticky w -padx 2
		grid [label $legend_frame.l10	\
			-text [mc "Operands"]	\
			-font $number_font	\
		] -column 1 -row 2 -sticky w
		 # Length
		grid [label $legend_frame.l01	\
			-fg $len_color		\
			-bg $len_color		\
			-text {X}		\
			-font $number_font	\
		] -column 0 -row 3 -sticky w -padx 2
		grid [label $legend_frame.l11	\
			-text [mc "Length"]	\
			-font $number_font	\
		] -column 1 -row 3 -sticky w
		 # Time
		grid [label $legend_frame.l02	\
			-fg $time_color		\
			-bg $time_color		\
			-text {X}		\
			-font $number_font	\
		] -column 0 -row 4 -sticky w -padx 2
		grid [label $legend_frame.l12	\
			-text [mc "Time"]	\
			-font $number_font	\
		] -column 1 -row 4 -sticky w

		## Create details frame
		 # Create labelframe
		set details_frame_header_frm [frame $win.details_frame_header_frm]
		pack [label $details_frame_header_frm.lbl	\
			-text [mc "OP code (hex): "]		\
			-font $details_n_font			\
		] -side left
		set opcode_ent [ttk::entry $details_frame_header_frm.ent	\
			-validatecommand "$this opcode_validator %P"		\
			-width 4						\
			-validate key						\
		]
		pack $opcode_ent -side left
		set title_v_lbl [label $details_frame_header_frm.title_v_lbl	\
			-fg $ins_color						\
			-font $details_b_font					\
		]
		pack $title_v_lbl -side left -padx 15
		set details_frame [ttk::labelframe $middle_frame.details_frame	\
			-labelwidget $details_frame_header_frm		\
			-padding 5					\
		]
		 # Labels: Class & Description
		grid [label $details_frame.class_l_lbl	\
			-text [mc "Class: "]		\
			-font $details_b_font		\
		] -row 0 -column 0 -sticky w
		set class_v_lbl [label $details_frame.class_v_lbl -font $details_n_font]
		grid $class_v_lbl -row 0 -column 1 -sticky w
		grid [label $details_frame.desc_l_lbl	\
			-text [mc "Description: "]	\
			-font $details_b_font		\
		] -row 1 -column 0 -sticky w
		set desc_v_lbl [label $details_frame.desc_v_lbl -font $details_n_font]
		grid $desc_v_lbl -row 1 -column 1 -sticky w
		 # Labels: Length & Time
		grid [label $details_frame.length_l_lbl	\
			-text [mc "Length: "]		\
			-font $details_b_font		\
		] -row 0 -column 2 -sticky w
		set length_v_lbl [label $details_frame.length_v_lbl -font $details_n_font]
		grid $length_v_lbl -row 0 -column 3 -sticky w
		grid [label $details_frame.time_l_lbl	\
			-text [mc "Time: "]		\
			-font $details_b_font		\
		] -row 1 -column 2 -sticky w
		set time_v_lbl [label $details_frame.time_v_lbl -font $details_n_font]
		grid $time_v_lbl -row 1 -column 3 -sticky w
		 # Label: Note & Flags
		grid [label $details_frame.note_l_lbl	\
			-text [mc "Note: "]		\
			-font $details_b_font		\
		] -row 2 -column 0 -sticky w
		set note_v_lbl [label $details_frame.note_v_lbl -font $details_n_font]
		grid $note_v_lbl -row 2 -column 1 -sticky w
		grid [label $details_frame.flags_l_lbl	\
			-text [mc "Flags: "]		\
			-font $details_b_font		\
		] -row 2 -column 2 -sticky w
		set flags_v_lbl [label $details_frame.flags_v_lbl -font $number_font -fg {#DD0000}]
		grid $flags_v_lbl -row 2 -column 3 -sticky w
		 # Configure details frame
		grid columnconfigure $details_frame 1 -weight 1
		grid columnconfigure $details_frame 3 -minsize [expr {int(55 * $::font_size_factor)}]

		# Finalize ...
		pack $scrollable_frame -side left -fill both -expand 1
		pack $vertical_scrollbar -side right -fill y
		pack $main_frame -pady 5 -side top -fill both -expand 1
		pack $details_frame -padx 5 -fill x -side left -expand 1
		pack $legend_frame -padx 5 -side right -anchor nw
		pack $middle_frame -fill x
		pack $bottom_frame -fill x
	}

	## Validator for entrybox "OP code"
	 # @parm String string - New entrybox contents
	 # @return Bool - Always 1
	public method opcode_validator {string} {
		if {!$validation_ena} {return 1}

		# Handle an empty string
		if {![string length $string]} {
			$opcode_ent configure -style TEntry
			return 1
		}

		# Check for maximum allowable length
		if {[string length $string] > 2} {
			return 0
		}

		# Normalize the length
		if {[string length $string] == 1} {
			set string "0$string"
		}

		# Check whether the given value is really a hexadecimal number
		if {![string is xdigit -strict $string]} {
			$opcode_ent configure -style TblOfIns_RedBg.TEntry
			return 1
		}

		# Convert the string to upper case letters and to integer
		set string [string toupper $string]
		set address [expr "0x$string"]

		# Check for existence of the given OP code
		if {[lsearch -ascii -exact ${::CompilerConsts::defined_OPCODE} $string] == -1} {
			$opcode_ent configure -style TblOfIns_RedBg.TEntry
			tk_messageBox \
				-type ok \
				-icon info \
				-parent $win \
				-title [mc "OP code not defined"] \
				-message [mc "This instruction does not exist on 8051"]
			return 1
		}

		# Highlight the cell with the corresponding instruction
		$opcode_ent configure -style TblOfIns_GreenBg.TEntry
		select_cell $address
		if {$selected_cell != -1} {
			fill_details $address 1
		}
		return 1
	}

	## Set background color for certain cell in the chart matrix
	 # @parm Int address	- Cell address
	 # @parm Color color	- New background color
	 # @return void
	private method sel_bg_color {address color} {
		set frame $cells($address)
		foreach wdg [list $frame $frame.f $frame.ins_lbl $frame.oprs_lbl $frame.len_lbl $frame.time_lbl] {
			$wdg configure -bg $color
		}

		$hh_cells([expr {$address & 0x0F}]) configure -bg $color
		$vh_cells([expr {($address & 0xF0) >> 4}]) configure -bg $color
	}

	## Handles event when mouse pointer enters certain cell in the chart
	 # @parm Int address - Cell address
	 # @return void
	public method cell_enter {address} {
		$status_bar_lbl configure -text {}
		if {$selected_cell != $address} {
			sel_bg_color $address {#DDFFDD}
		}

		set def $::CompilerConsts::Opcode([convert_to_opcode $address])
		$status_bar_lbl configure -text "[string toupper [lindex $def 0]] [join [lindex $def 1] {, }]"
	}

	## Handles event when mouse pointer leaves certain cell in the chart
	 # @parm Int address - Cell address
	 # @return void
	public method cell_leave {address} {
		if {$selected_cell == $address} {
			return
		}
		sel_bg_color $address {#FFFFFF}
		$status_bar_lbl configure -text {}

		if {$selected_cell != -1} {
			$hh_cells([expr {$selected_cell & 0x0F}]) configure -bg {#BBBBFF}
			$vh_cells([expr {($selected_cell & 0xF0) >> 4}]) configure -bg {#BBBBFF}
		}
	}

	## Handles event when clicks on certain cell in the chart
	 # @parm Int address - Cell address
	 # @return void
	public method cell_click {address} {
		if {$selected_cell == $address} {
			unselect_current_cell 1 1
			set selected_cell -1
			return
		}
		if {![winfo exists $matrix_frame.cell_$address]} {
			return
		}

		focus $matrix_frame.cell_$address
		select_cell $address
		if {$selected_cell != -1} {
			fill_details $address
		}
	}

	## Select specified cell in the chart (mark as selected and adjust details frame)
	 # @parm Int address - Cell address
	 # @return void
	private method select_cell {address} {
		if {$selected_cell != -1} {
			unselect_current_cell 0 0
		}
		set selected_cell $address
		sel_bg_color $address {#BBBBFF}
	}

	## Unselect specified cell in the chart (mark as normal and clear details frame)
	 # @parm Bool keep_current	- Mark cell as a cell under mouse pointer (light green bg. color)
	 # @parm Bool affect_entryboxes	- Clear entryboxes in details frame
	 # @return void
	private method unselect_current_cell {keep_current affect_entryboxes} {
		if {$selected_cell == -1} {
			return
		}

		# Set new background color
		if {$keep_current} {
			sel_bg_color $selected_cell {#DDFFDD}
		} else {
			sel_bg_color $selected_cell {#FFFFFF}
		}

		# Clear entryboxes in details frame
		if {$affect_entryboxes} {
			$title_v_lbl	configure -text {}
			$class_v_lbl	configure -text {}
			$desc_v_lbl	configure -text {}
			$length_v_lbl	configure -text {}
			$time_v_lbl	configure -text {}
			$flags_v_lbl	configure -text {}
			$note_v_lbl	configure -text {}

			set validation_ena 0
			$opcode_ent delete 0 end
			$opcode_ent configure -style TEntry
			set validation_ena 1
		}
	}

	## Get instruction OP code in 2-digits uppercase hexadecimal form
	 # @parm Int int_address - OP code in decimal form
	 # @return String - 2-digits uppercase hexadecimal number (e.g. ``B9'')
	private method convert_to_opcode {int_address} {
		set opcode [format %X $int_address]
		if {[string length $opcode] == 1} {
			set opcode "0$opcode"
		}
		return $opcode
	}

	## Fill the details about the instruction
	 # @parm Int address		- Integer representation of the instruction OP code
	 # @parm Bool exclude_opcode	- Do not affect the entry box with OP code
	 # @return void
	public method fill_details {address {exclude_opcode 0}} {
		$scrollable_frame see $matrix_frame.cell_$address

		## Obtain detailed informations about the instruction

		set opcode [convert_to_opcode $address]
		set def $::CompilerConsts::Opcode($opcode)

		set instruction	[lindex $def 0]		;# Instruction name
		set operands	[lindex $def 1]		;# Oprand types
		set length	[lindex $def 2]		;# Instruction length
		set time	[lindex $def 4]		;# Time

		set operands_tmp	[list]
		foreach operand $operands {
			switch -glob -nocase -- $operand {
				a	-
				c	-
				ab	-
				@dptr	-
				@a+dptr	-
				@a+pc	-
				dptr	{
					set operand [string toupper $operand]
				}
				r?	{
					set operand {Rn}
				}
				@r?	{
					set operand {@Ri}
				}
				imm8	{
					set operand {#data}
				}
				imm16	{
					set operand {#data16}
				}
				code8	{
					set operand {rel}
				}
				code11	{
					set operand {addr11}
				}
				code16	{
					set operand {addr16}
				}
				bit	{
					set operand {bit}
				}
				/bit	{
					set operand {/bit}
				}
				data	{
					set operand {direct}
				}
			}
			lappend operands_tmp $operand
		}

		set operands [join $operands_tmp {, }]
		set instruction [string toupper $instruction]
		set title "$instruction\t$operands"

		set idx [lsearch -ascii -exact ${::InstructionDetails::INSTRUCTION_DESCRIPTION} $title]
		if {$idx == -1} {
			set ins_class {}
			set ins_desc {}
			set ins_note {}
			set flags {}
		} else {
			incr idx
			set def [lindex ${::InstructionDetails::INSTRUCTION_DESCRIPTION} $idx]
			set ins_desc	[lindex $def 0]
			set ins_class	[lindex $def 1]
			set ins_note	[lindex $def 2]
			set flags	{}

			foreach i {0 1 2} f {C OV AC} {
				if {[string length [lindex $def [list 3 $i]]]} {
					lappend flags $f
				}
			}
		}

		if {!$exclude_opcode} {
			$opcode_ent	delete 0 end
			$opcode_ent	insert 0 $opcode
		}

		$title_v_lbl	configure -text $title
		$class_v_lbl	configure -text [namespace eval ::InstructionDetails "mc {$ins_class}"]
		$desc_v_lbl	configure -text [namespace eval ::InstructionDetails "mc {$ins_desc}"]
		$length_v_lbl	configure -text $length
		$time_v_lbl	configure -text $time
		$flags_v_lbl	configure -text [join $flags {, }]
		$note_v_lbl	configure -text [namespace eval ::InstructionDetails "mc {$ins_note}"]
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

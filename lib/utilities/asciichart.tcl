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
if { ! [ info exists _ASCIICHART_TCL ] } {
set _ASCIICHART_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Interactive ASCII chart
# --------------------------------------------------------------------------

class AsciiChart {
	public common ascii_chr_count	0	;# Int: Counter of object instances
	public common ASCII_TABLE		;# Array of List: ASCII table
	array set ASCII_TABLE {
		0   {NUL ^@  \\0 {Null character}}
		1   {SOH ^A  {}  {Start of Header}}
		2   {STX ^B  {}  {Start of Text}}
		3   {ETX ^C  {}  {End of Text}}
		4   {EOT ^D  {}  {End of Transmission}}
		5   {ENQ ^E  {}  {Enquiry}}
		6   {ACK ^F  {}  {Acknowledgment}}
		7   {BEL ^G  \\a {Bell}}
		8   {BS  ^H  \\b {Backspace}}
		9   {HT  ^I  \\t {Horizontal Tab}}
		10  {LF  ^J  \\n {Line feed}}
		11  {VT  ^K  \\v {Vertical Tab}}
		12  {FF  ^L  \\f {Form feed}}
		13  {CR  ^M  \\r {Carriage return}}
		14  {SO  ^N  {}  {Shift Out}}
		15  {SI  ^O  {}  {Shift In}}
		16  {DLE ^P  {}  {Data Link Escape}}
		17  {DC1 ^Q  {}  {Device Control 1 (oft. XON)}}
		18  {DC2 ^R  {}  {Device Control 2}}
		19  {DC3 ^S  {}  {Device Control 3 (oft. XOFF)}}
		20  {DC4 ^T  {}  {Device Control 4}}
		21  {NAK ^U  {}  {Negative Acknowledgement}}
		22  {SYN ^V  {}  {Synchronous Idle}}
		23  {ETB ^W  {}  {End of Trans. Block}}
		24  {CAN ^X  {}  {Cancel}}
		25  {EM  ^Y  {}  {End of Medium}}
		26  {SUB ^Z  {}  {Substitute}}
		27  {ESC ^[  \\e {Escape}}
		28  {FS  ^\\ {}  {File Separator}}
		29  {GS  ^]  {}  {Group Separator}}
		30  {RS  ^^  {}  {Record Separator}}
		31  {US  ^_  {}  {Unit Separator}}
		127 {DEL ^?  {}  {Delete}}

		32  {{ }}	33  !		34  \\\"	35  #
		36  $		37  %		38  &		39  '
		40  (		41  )		42  *		43  +
		44  ,		45  -		46  .		47  /
		48  0		49  1		50  2		51  3
		52  4		53  5		54  6		55  7
		56  8		57  9		58  :		59  ;
		60  <		61  =		62  >		63  ?
		64  @		65  A		66  B		67  C
		68  D		69  E		70  F		71  G
		72  H		73  I		74  J		75  K
		76  L		77  M		78  N		79  O
		80  P		81  Q		82  R		83  S
		84  T		85  U		86  V		87  W
		88  X		89  Y		90  Z		91  [
		92  \\		93  ]		94  ^		95  _
		96  `		97  a		98  b		99  c
		100 d		101 e		102 f		103 g
		104 h		105 i		106 j		107 k
		108 l		109 m		110 n		111 o
		112 p		113 q		114 r		115 s
		116 t		117 u		118 v		119 w
		120 x		121 y		122 z		123 \\\{
		124 |		125 \\\}	126 ~
	}

	private variable obj_idx		;# Int: Object index (for entrybox textvariables)
	private variable selected_cell	-1	;# Int: Currently selected cell
	private variable validation_ena	1	;# Bool: EntryBox validation enabled
	private variable win			;# Widget: Dialog window
	private variable window_visible	0	;# Bool: Visibility flag
	private variable cells			;# Array of Widget: Chart cell frames
	private variable vh_cells		;# Array of Widget: Vertical headers
	private variable hh_cells		;# Array of Widget: Horizontal headers

	private variable status_bar_lbl		;# Widget: Status bar
	private variable char_ent		;# Widget: Entrybox "Character:"
	private variable hex_addr_ent		;# Widget: Entrybox "Hexadecimal address:"
	private variable dec_addr_ent		;# Widget: Entrybox "Decimal address:"
	private variable oct_addr_ent		;# Widget: Entrybox "Octal address:"
	private variable bin_addr_ent		;# Widget: Entrybox "Binary address:"
	private variable caret_not_ent		;# Widget: Entrybox "Caret notation:"
	private variable escape_seq_ent		;# Widget: Entrybox "C escape sequence:"

	constructor {} {
		# Configure local ttk styles
		ttk::style configure AsciiChart_BlueFg.TEntry	-foreground {#0000DD}
		ttk::style configure AsciiChart_RedFg.TEntry	-foreground {#DD0000}
		ttk::style configure AsciiChart_RedBg.TEntry	-fieldbackground {#FFDDDD}
		ttk::style configure AsciiChart_GreenBg.TEntry	-fieldbackground {#DDFFDD}

		# Create dialog window
		set window_visible 1
		set win [toplevel .asciichart${ascii_chr_count}  -class {ASCII chart} -bg ${::COMMON_BG_COLOR}]
		set obj_idx $ascii_chr_count
		incr ascii_chr_count

		# Create dialog GUI
		create_gui

		# Set window event bindings
		bind $win <Control-Key-q> "$this close_window; break"
		bindtags $win [list $win Toplevel all .]

		# Set window parameters
		wm iconphoto $win ::ICONS::16::math_matrix
		wm title $win "[mc {ASCII chart}] - MCU 8051 IDE"
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW "$this close_window"
	}

	destructor {
		destroy $win
	}

	## Determinate wheather the window is visble or not
	 # @return Bool - Visibility flag
	public method is_visible {} {
		return $window_visible
	}

	## Close dialog window, but keep object
	 # @return void
	public method close_window {} {
		set window_visible 0
		wm withdraw $win
	}

	## Restore dialog window
	 # @return void
	public method restore_window {} {
		set window_visible 1
		wm deiconify $win
		raise $win .
	}

	## Raise dialog window (insure than it is visible)
	 # @return void
	public method raise_window {} {
		if {!$window_visible} {return}
		raise $win .
	}

	## Create window GUI
	 # @return void
	private method create_gui {} {
		# Create bottom frame
		set bottom_frame [frame $win.bottom_frame]
		set status_bar_lbl [label $bottom_frame.status_bar_lbl -justify left -anchor w]
		pack $status_bar_lbl -side left -fill x -in $bottom_frame
		pack [ttk::button $bottom_frame.close_but	\
			-text [mc "Exit"]			\
			-command "$this close_window"		\
			-compound left				\
			-image ::ICONS::16::exit		\
		] -side right -padx 5 -pady 5

		## Create main frame
		set main_frame [frame $win.main_frame -bg {#DDDDDD}]
		 # Create vertical header
		grid [frame $main_frame.top_right_lbl -bg ${::COMMON_BG_COLOR}] -sticky wens -row 0 -column 0
		set header [list {}			\
			{0x0_} {0x1_} {0x2_} {0x3_}	\
			{0x4_} {0x5_} {0x6_} {0x7_}	\
		]
		for {set y 1} {$y < 9} {incr y} {
			grid [label $main_frame.vh_lbl$y -text [lindex $header $y] -bg {#FFFFFF}] \
				-row $y -column 0 -pady [expr {$y % 2}] -sticky wens
			set vh_cells([expr {$y - 1}]) $main_frame.vh_lbl$y
		}
		 # Create horizontal header
		set header [list {}			\
			{0x_0} {0x_1} {0x_2} {0x_3}	\
			{0x_4} {0x_5} {0x_6} {0x_7}	\
			{0x_8} {0x_9} {0x_A} {0x_B}	\
			{0x_C} {0x_D} {0x_E} {0x_F}	\
		]
		for {set x 1} {$x < 17} {incr x} {
			grid [label $main_frame.hh_lbl$x -text [lindex $header $x] -bg {#FFFFFF}] \
				-row 0 -column $x -padx [expr {$x % 2}] -sticky wens
			set hh_cells([expr {$x - 1}]) $main_frame.hh_lbl$x
		}
		 # Create ASCII chart matrix
		set hex_addr 0
		set address 0
		for {set y 1} {$y < 9} {incr y} {
			for {set x 1} {$x < 17} {incr x} {
				# Create cell frame
				set frame [frame $main_frame.cell_$address	\
					-bg white -bd 0				\
				]

				# Determinate hexadecimal address
				set hex_addr [format %X $address]
				if {$address < 16} {
					set hex_addr "0$hex_addr"
				}
				set hex_addr "0x$hex_addr"

				# Determinate character in the chart and color for it
				set val [lindex $ASCII_TABLE($address) 0]
				if {[string length $val] > 1} {
					set foreground {#DD0000}
				} else {
					set foreground {#0000DD}
				}

				# Create label containing character name
				pack [label $frame.char_lbl -pady 0		\
					-fg $foreground -bg white -text $val	\
				]
				# Create label containing character address
				pack [label $frame.val_lbl		\
					-fg {#00DD00} -text $hex_addr	\
					-bg white -pady 0 		\
				]

				grid $frame -row $y -column $x -padx [expr {$x % 2}] -pady [expr {$y % 2}] -sticky wens
				set cells($address) $frame
				foreach wdg [list $frame $frame.val_lbl $frame.char_lbl] {
					bind $wdg <Enter> "$this cell_enter $address"
					bind $wdg <Leave> "$this cell_leave $address"
					bind $wdg <Button-1> "$this cell_click $address"
				}

				if {$address < 127} {
					bind $frame <Key-Right> [list $this cell_click [expr {$address + 1}]]
				}
				if {$address > 0} {
					bind $frame <Key-Left> [list $this cell_click [expr {$address - 1}]]
				}
				if {$address > 16} {
					bind $frame <Key-Up> [list $this cell_click [expr {$address - 16}]]
				}
				if {$address < 112} {
					bind $frame <Key-Down>  [list $this cell_click [expr {$address + 16}]]
				}

				incr address
			}
		}
		# Ensure than all cells have the same width and heigh
		for {set i 0} {$i < 17} {incr i} {
			grid columnconfigure $main_frame $i -uniform ascii
		}
		for {set i 1} {$i < 9} {incr i} {
			grid rowconfigure $main_frame $i -uniform ascii
		}
		 # Show ASCII chart
		pack $main_frame -pady 5 -side top

		## Create details frame (character details)
		 # Create labelframe
		set details_frame_header_frm [frame $win.details_frame_header_frm]
		pack [label $details_frame_header_frm.lbl -text [mc "Character: "]] -side left
		set char_ent [ttk::entry $details_frame_header_frm.ent	\
			-validatecommand "$this char_ent_validator %P"	\
			-width 4					\
			-validate key					\
		]
		pack $char_ent -side left
		set details_frame [ttk::labelframe $win.details_frame	\
			-labelwidget $details_frame_header_frm		\
			-padding 10					\
		]
		 # Entryboxes: HEX and DEC
		grid [label $details_frame.hex_addr_lbl	\
			-text [mc "Hex address"]	\
		] -row 0 -column 0 -sticky w
		grid [label $details_frame.dec_addr_lbl	\
			-text [mc "Dec address"]	\
		] -row 1 -column 0 -sticky w
		set hex_addr_ent [ttk::entry $details_frame.hex_addr_ent	\
			-validatecommand "$this addr_ent_validator H %P"	\
			-validate key						\
			-width 3						\
		]
		set dec_addr_ent [ttk::entry $details_frame.dec_addr_ent	\
			-validatecommand "$this addr_ent_validator D %P"	\
			-validate key						\
			-width 3						\
		]
		grid $hex_addr_ent -row 0 -column 2 -sticky w
		grid $dec_addr_ent -row 1 -column 2 -sticky w
		 # Entryboxes: OCT and BIN
		grid [label $details_frame.oct_addr_lbl	\
			-text [mc "Oct address"]	\
		] -row 0 -column 4 -sticky w
		grid [label $details_frame.bin_addr_lbl	\
			-text [mc "Bin address"]	\
		] -row 1 -column 4 -sticky w
		set oct_addr_ent [ttk::entry $details_frame.oct_addr_ent	\
			-validate key						\
			-width 3						\
			-validatecommand "$this addr_ent_validator O %P"	\
		]
		set bin_addr_ent [ttk::entry $details_frame.bin_addr_ent	\
			-validate key						\
			-width 8						\
			-validatecommand "$this addr_ent_validator B %P"	\
		]
		grid $oct_addr_ent -row 0 -column 6 -sticky w
		grid $bin_addr_ent -row 1 -column 6 -sticky w
		 # Entryboxes: "Caret notation" and "C Escape Code"
		grid [label $details_frame.caret_not_lbl	\
			-text [mc "Caret notation"]		\
		] -row 0 -column 8 -sticky w
		grid [label $details_frame.escape_seq_lbl	\
			-text [mc "C Escape Code"]		\
		] -row 1 -column 8 -sticky w
		set caret_not_ent [ttk::entry $details_frame.caret_not_ent	\
			-validate key						\
			-width 3						\
			-validatecommand "$this more_detail_ent_validator C %P"	\
		]
		set escape_seq_ent [ttk::entry $details_frame.escape_seq_ent	\
			-validate key						\
			-width 3						\
			-validatecommand "$this more_detail_ent_validator E %P"	\
		]
		grid $caret_not_ent -row 0 -column 10 -sticky w
		grid $escape_seq_ent -row 1 -column 10 -sticky w
		 # Create copy buttons (copy entrybox contents to clipboard)
		foreach type	{H D O B C E} \
			row	{0 1 0 1 0 1} \
			col	{1 1 5 5 9 9} \
		{
			grid [ttk::button $details_frame.copy_${type}_but	\
				-command "$this copy_contents ${type}"		\
				-image ::ICONS::16::editcopy			\
				-style Flat.TButton				\
			] -row $row -column $col -sticky w -padx 3
			DynamicHelp::add $details_frame.copy_${type}_but	\
				-text [mc "%s - Copy contents of entrybox to clipboard" $type]
			bind $details_frame.copy_${type}_but <Enter> \
				"$status_bar_lbl configure -text {[mc {Copy to clipboard}]}"
			bind $details_frame.copy_${type}_but <Leave> \
				"$status_bar_lbl configure -text {}"
		}
		 # Configure event bindings for entryboxes
		foreach widget [list							\
			$char_ent	$hex_addr_ent	$dec_addr_ent	$oct_addr_ent	\
			$bin_addr_ent	$caret_not_ent	$escape_seq_ent			\
		] {
			bindtags $widget [list $widget TEntry $win all .]
		}
		 # Configure details frame
		grid columnconfigure $details_frame 3 -minsize 20
		grid columnconfigure $details_frame 7 -minsize 20
		grid columnconfigure $details_frame 11 -weight 1

		# Finalize ...
		pack $details_frame -padx 5 -anchor w -fill x
		pack $bottom_frame -fill x
		focus -force $char_ent
	}

	## Set background color for certain cell in ASCII chart matrix
	 # @parm Int address	- Cell address
	 # @parm Color color	- New background color
	 # @return void
	private method sel_bg_color {address color} {
		$cells($address) configure -bg $color
		$cells($address).char_lbl configure -bg $color
		$cells($address).val_lbl configure -bg $color

		$hh_cells([expr {$address & 0x0F}]) configure -bg $color
		$vh_cells([expr {($address & 0xF0) >> 4}]) configure -bg $color
	}

	## Handles event when mouse pointer enters certain cell in the ASCII chart
	 # @parm Int address - Cell address
	 # @return void
	public method cell_enter {address} {
		$status_bar_lbl configure -text [lindex $ASCII_TABLE($address) 3]
		if {$selected_cell == $address} {
			return
		}
		sel_bg_color $address {#DDFFDD}
	}

	## Handles event when mouse pointer leaves certain cell in the ASCII chart
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

	## Handles event when clicks on certain cell in the ASCII chart
	 # @parm Int address - Cell address
	 # @return void
	public method cell_click {address} {
		if {$selected_cell == $address} {
			unselect_current_cell 1 1
			set selected_cell -1
			return
		}
		focus $cells($address)
		select_cell $address
		if {$selected_cell != -1} {
			fill_entryboxes $address {}
		}
	}

	## Copy contents of certain entrybox to clipboard
	 # @parm Char type - Entrybox ID
	 #	H - Hexadecimal address
	 #	D - Decimal address
	 #	O - Octal address
	 #	B - Binary address
	 #	C - Caret notation
	 #	E - C escape sequence
	 # @return void
	public method copy_contents {type} {
		switch -- $type {
			{H} {set widget $hex_addr_ent}
			{D} {set widget $dec_addr_ent}
			{O} {set widget $oct_addr_ent}
			{B} {set widget $bin_addr_ent}
			{C} {set widget $caret_not_ent}
			{E} {set widget $escape_seq_ent}
		}

		clipboard clear
		clipboard append [$widget get]
	}

	## Select specified cell in ASCII chart (mark as selected and adjust details frame)
	 # @parm Int address - Cell address
	 # @return void
	private method select_cell {address} {
		if {$selected_cell != -1} {
			unselect_current_cell 0 0
		}
		set selected_cell $address
		sel_bg_color $address {#BBBBFF}
	}

	## Unselect specified cell in ASCII chart (mark as normal and clear details frame)
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
			set validation_ena 0
			foreach widget [list								\
					$char_ent	$hex_addr_ent	$dec_addr_ent	$oct_addr_ent	\
					$bin_addr_ent	$caret_not_ent	$escape_seq_ent			\
				] {
					$widget delete 0 end
					$widget configure -style TEntry
			}
			$char_ent configure -style TEntry
			set validation_ena 1
		}
	}

	## Clear entryboxes in details frame
	 # @parm Char type - Entrybox to exclude
	 #	M - Character
	 #	H - Hexadecimal address
	 #	D - Decimal address
	 #	O - Octal address
	 #	B - Binary address
	 #	C - Caret notation
	 #	E - C escape sequence
	 # @return void
	private method clear_entryboxes {type} {
		set validation_ena 0
		foreach entry_type	{M H D O B C E}						\
			entry_widget	[list							\
				$char_ent	$hex_addr_ent	$dec_addr_ent	$oct_addr_ent	\
				$bin_addr_ent	$caret_not_ent	$escape_seq_ent			\
			] \
		{
			if {$type == $entry_type} {
				continue
			}
			$entry_widget delete 0 end
			$entry_widget configure -style TEntry
		}
		set validation_ena 1
	}

	## Show details for character in specified address
	 # @parm Int address	- Cell address
	 # @parm Char type	- Entrybox to exclude
	 #	M - Character
	 #	H - Hexadecimal address
	 #	D - Decimal address
	 #	O - Octal address
	 #	B - Binary address
	 #	C - Caret notation
	 #	E - C escape sequence
	 # @return void
	private method fill_entryboxes {address type} {
		clear_entryboxes $type
		set validation_ena 0

		# Character
		if {$type != {M}} {
			set value [lindex $ASCII_TABLE($address) 0]
			$char_ent insert insert $value
			if {[string length $value] > 1} {
				$char_ent configure -style AsciiChart_RedFg.TEntry
			} else {
				$char_ent configure -style AsciiChart_BlueFg.TEntry
			}
		}
		# Hexadecimal address
		if {$type != {H}} {
			set value [format %X $address]
			if {$address < 16} {
				set value "0$value"
			}
			$hex_addr_ent insert insert $value
		}
		# Decimal address
		if {$type != {D}} {
			$dec_addr_ent insert insert $address
		}
		# Octal address
		if {$type != {O}} {
			$oct_addr_ent insert insert [::NumSystem::dec2oct $address]
		}
		# Binary address
		if {$type != {B}} {
			set value [::NumSystem::dec2bin $address]
			set len [string length $value]
			if {$len < 8} {
				set value "[string repeat 0 [expr {8 - $len}]]$value"
			}
			$bin_addr_ent insert insert $value
		}
		# Caret notation
		if {$type != {C}} {
			$caret_not_ent insert insert [lindex $ASCII_TABLE($address) 1]
		}
		# C escape sequence
		if {$type != {E}} {
			$escape_seq_ent insert insert [lindex $ASCII_TABLE($address) 2]
		}

		set validation_ena 1
	}

	## Validator for entrybox "Character"
	 # @parm String string - New entrybox contents
	 # @return Bool - Always 1
	public method char_ent_validator {string} {
		if {!$validation_ena} {return 1}
		set validation_ena 0

		## Validate input string
		set length [string length $string]
		if {!$length} {
			$char_ent configure -style TEntry
			clear_entryboxes M
			unselect_current_cell 0 0
			set validation_ena 1
			return 1
		}
		if {$length > 3} {
			set validation_ena 1
			return 0
		}

		# Search for the given character in the ASCII chart
		if {$length > 1} {
			set string [string toupper $string]
		}
		for {set i 0} {$i < 128} {incr i} {
			if {![string compare [lindex $ASCII_TABLE($i) 0] $string]} {
				select_cell $i
				fill_entryboxes $i M

				if {$length > 1} {
					$char_ent configure -style AsciiChart_RedFg.TEntry
				} else {
					$char_ent configure -style AsciiChart_BlueFg.TEntry
				}

				set validation_ena 1
				return 1
			}
		}

		# Character not found
		clear_entryboxes M
		unselect_current_cell 0 0
		$char_ent configure -style StringNotFound.TEntry
		set validation_ena 1
		return 1
	}

	## Validator for entryboxes "Hex","Dec","Oct" and "Bin"
	 # @parm Char type	- Source entry box
	 #	H - Hexadecimal address
	 #	D - Decimal address
	 #	O - Octal address
	 #	B - Binary address
	 # @parm String string	- New entrybox contents
	 # @return Bool - Allways 1
	public method addr_ent_validator {type string} {
		if {!$validation_ena} {return 1}
		set validation_ena 0

		switch -- $type {
			H {set widget $hex_addr_ent}
			D {set widget $dec_addr_ent}
			O {set widget $oct_addr_ent}
			B {set widget $bin_addr_ent}
		}

		# Empty input string
		set length [string length $string]
		if {!$length} {
			$widget configure -style TEntry
			clear_entryboxes $type
			unselect_current_cell 0 0
			set validation_ena 1
			return 1
		}

		# Validate input string and convert it into integer
		switch -- $type {
			H {	;# Hexadecimal
				if {$length > 2 || ![string is xdigit -strict $string]} {
					set validation_ena 1
					return 0
				}
				set string [expr "0x$string"]
			}
			D {	;# Decimal
				if {$length > 3 || ![string is digit -strict $string]} {
					set validation_ena 1
					return 0
				}
			}
			O {	;# Octal
				if {$length > 3 || ![regexp {^[0-7]+$} $string]} {
					set validation_ena 1
					return 0
				}
				set string [expr "0$string"]
			}
			B {	;# Binary
				if {$length > 8 || ![regexp {^[01]+$} $string]} {
					set validation_ena 1
					return 0
				}
				set string [::NumSystem::bin2dec $string]
			}
		}
		set string [string trimleft $string 0]
		if {$string == {}} {
			set string 0
		}

		# Check value range
		if {$string > 127 || $string < 0} {
			clear_entryboxes $type
			unselect_current_cell 0 0
			$widget configure -style AsciiChart_RedBg.TEntry
			set validation_ena 1
			return 1
		}

		# Adjust GUI (ACII chart and details frame)
		select_cell $string
		fill_entryboxes $string $type
		$widget configure -style AsciiChart_GreenBg.TEntry
		return 1
	}

	## Validator for entryboxes "Caret notation" and "C escape sequence"
	 # @parm Char type	- Source entry box
	 #	C - Caret notation
	 #	E - C escape sequence
	 # @parm String string	- New entrybox contents
	 # @return Bool - Allways 1
	public method more_detail_ent_validator {type string} {
		if {!$validation_ena} {return 1}
		set validation_ena 0

		# Dterminate widget object and index in ASCII chart array
		if {$type == {C}} {
			set widget $caret_not_ent
			set index 1
		} else {
			set widget $escape_seq_ent
			set index 2
		}

		# Empty input string
		if {![string length $string]} {
			$widget configure -style TEntry
			clear_entryboxes $type
			unselect_current_cell 0 0
			set validation_ena 1
			return 1
		}

		# Inputs string must not be longer than 2 characters
		if {[string length $string] > 2} {
			set validation_ena 1
			return 0
		}

		# Search for the given string in the ASCII chart array
		for {set i 0} {$i < 128} {incr i} {
			if {![string compare [lindex $ASCII_TABLE($i) $index] $string]} {
				select_cell $i
				fill_entryboxes $i $type

				$widget configure -style AsciiChart_GreenBg.TEntry
				set validation_ena 1
				return 1
			}
		}

		# String not found
		clear_entryboxes $type
		unselect_current_cell 0 0
		$widget configure -style AsciiChart_RedBg.TEntry
		set validation_ena 1
		return 1
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

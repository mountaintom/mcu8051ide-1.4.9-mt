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
if { ! [ info exists _BASECONVERTER_TCL ] } {
set _BASECONVERTER_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# Utility "Base Converter"
# --------------------------------------------------------------------------

class BaseConverter {
	## COMMON
	public common base_c_count			0	;# Int: Counter of class instances
	public common INITIAL_HEIGHT			130	;# Int: Initial heightof the window  in pixels
	public common INITIAL_WIDTH			150	;# Int: Initial width of the window in pixels
	public common EXTENDED_WIDTH			340	;# Int: Width of the window when it is in extended mode

	# On MS Windows these values has to be a bit different
	if {$::MICROSOFT_WINDOWS} {
		set INITIAL_HEIGHT	125
		set INITIAL_WIDTH	165
		set EXTENDED_WIDTH	355
	}
	 # Font entryboxes
	public common entry_font [font create		\
		-size -12			\
		-family $::DEFAULT_FIXED_FONT	\
		-weight bold			\
	]

	## PRIVATE
	private variable win				;# Widget: Window
	private variable win_obj			;# Object: Window object

	private variable less_more_button		;# Widget: Button "Less/More"
	private variable enlarge_shrink_button		;# Widget: Button "Enlarge/Shrink"

	private variable right_top_frame		;# Widget: Right top frame
	private variable left_top_frame			;# Widget: Left top frame

	private variable less_more		0	;# Bool: Mode flag "More"
	private variable large			0	;# Bool: Flag enlarged

	private variable left_rows_created	0	;# Int: Number of created rows in the left frame
	private variable right_rows_created	0	;# Int: Number of created rows in the right frame

	private variable validation_in_progress	0	;# Bool: Validation procedure in progress

	private variable val_to_set	[list {} {} {}]	;# List: Decimal values to set in the bottom 3 entryboxes after enlarge

	private variable entry_h	;# Array of Widget: Entrybox "HEX", index is row (starting from 0)
	private variable entry_d	;# Array of Widget: Entrybox "DEC", index is row (starting from 0)
	private variable entry_b	;# Array of Widget: Entrybox "BIN", index is row (starting from 0)
	private variable entry_o	;# Array of Widget: Entrybox "OCT", index is row (starting from 0)
	private variable entry_t	;# Array of Widget: Canvas containing bits
	private variable entry_c0	;# Array of Widget: Entrybox "BCD L", index is row (starting from 0)
	private variable entry_c1	;# Array of Widget: Entrybox "BCD H", index is row (starting from 0)
	private variable entry_a	;# Array of Widget: Entrybox "ASCII", index is row (starting from 0)
	private variable bit		;# CanvasObject: bit rectangle, $bit(row_number,bit_number)

	## Object constructor
	constructor {} {
		# Configure ttk styles
		if {!$base_c_count} {
			ttk::style configure BaseConverter_Focused_D.TEntry -fieldbackground {#AAAAFF}
			ttk::style configure BaseConverter_Focused_I.TEntry -fieldbackground {#DDDDFF}
			ttk::style configure BaseConverter_NotFocused.TEntry
		}

		incr base_c_count

		create_window
		create_gui
	}

	## Object destructor
	destructor {
	}

	## Commence a new configuration
	 # @parm List conf_list - Configuration list previously returned by proc. "get_config"
	 # @return void
	public method set_config {conf_list} {
		# Set window position
		$win_obj geometry			\
			{} {}				\
			[lindex $conf_list {0 2}]	\
			[lindex $conf_list {0 3}]

		# Adjust modes
		if {[lindex $conf_list 2]} {
			less_more
		}
		if {[lindex $conf_list 3]} {
			enlarge_shrink
		}

		# Fill in the entryboxes
		for {set i 0} {$i < $left_rows_created} {incr i} {
			validate {t} $i [lindex $conf_list [list 4 $i]]
		}
		if {$left_rows_created < 6} {
			for {set i 0; set j 3} {$i < 3} {incr i; incr j} {
				lset val_to_set $i [lindex $conf_list [list 4 $j]]
			}
		}

		# Adjust flag "Shaded"
		if {[lindex $conf_list 1]} {
			update
			$win_obj collapse_expand
		}
	}

	## Get configuration list
	 # @return List - Configuration list
	public method get_config {} {
		# Create list of current values in the entryboxes
		set values {}
		lappend values [$entry_d(0) get] [$entry_d(1) get] [$entry_d(2) get]
		if {$left_rows_created > 3} {
			lappend values			\
				[$entry_d(3) get]	\
				[$entry_d(4) get]	\
				[$entry_d(5) get]
		} else {
			lappend values {} {} {}
		}

		# Finalize configuration list
		return [list				\
			[$win_obj geometry]		\
			[$win_obj get_minim_flag]	\
			$less_more			\
			$large				\
			$values				\
		]
	}

	## Create window using class "InnerWindow"
	 # @return void
	private method create_window {} {
		set win_obj [InnerWindow #auto				\
			.baseconverter_${base_c_count}			\
			[list $INITIAL_WIDTH $INITIAL_HEIGHT 100 100]	\
			[mc "Converter"]				\
			::ICONS::16::kaboodleloop			\
			"$this close_window"				\
		]
		set win [$win_obj get_frame]
	}

	## Create all window GUI
	 # @return void
	private method create_gui {} {
		# Create frames
		set top_frame [frame $win.top_frame]
		set left_top_frame [frame $top_frame.left_frame]
		set right_top_frame [frame $top_frame.right_frame]
		set bottom_frame [frame $win.bottom_frame]

		# Start in mode "Shirked" + !"More"
		create_left_frame

		## Create buttons in the bottom frame
		 # Button "Enlarge"/"Shrink"
		set enlarge_shrink_button					\
			[ttk::button $bottom_frame.enlarge_shrink_button	\
			-text [mc "Enlarge"]					\
			-compound left						\
			-image ::ICONS::16::1downarrow				\
			-command "$this enlarge_shrink"				\
			-width 7						\
			-style Flat.TButton					\
		]
		pack $enlarge_shrink_button -side left -padx 2 -pady 2
		 # Button "More"/"Less"
		set less_more_button [ttk::button $bottom_frame.less_more_button\
			-text [mc "More"]					\
			-compound right						\
			-image ::ICONS::16::1rightarrow				\
			-command "$this less_more"				\
			-width 5						\
			-style Flat.TButton					\
		]
		pack $less_more_button -side right -padx 2 -pady 2

		# Pack frames
		pack $left_top_frame -side left -anchor nw
		pack $top_frame -fill both -expand 1
		pack $bottom_frame -fill x

		# Focus the firts hexadecimal entrybox
		focus -force $entry_h(0)
	}

	## Close the window and forget configuration
	 # Calls proc. "::X::__base_converter_close"
	 # @return void
	public method close_window {} {
		::X::__base_converter_close $this
		$win_obj close_window
		delete object $this
	}

	## Validator for entryboxes
	 # Can be used to set a certain value for a certain row in this way:
	 # validate {t} $row_number $decimal_value
	 # @parm Char type	- Value source
	 #	h  - Hexadecimal
	 #	d  - Decimal
	 #	b  - Binary
	 #	o  - Octal
	 #	c0 - BCD - Low order nibble
	 #	c1 - BCD - High order nibble
	 #	a  - ASCII
	 #	t  - Bits (Do not validate, just accept)
	 # @parm Int row	- Row number, starting at zero
	 # @parm String content	- String to validate and evaluate
	 # @return Bool - 1 == Legal; 0 == Illegal
	public method validate {type row content} {
		# This method cannot be recursive in any way
		if {$validation_in_progress} {return 1}
		set validation_in_progress 1

		# Local variables
		set result	1	;# Bool: Result of validation
		set zero_length 0	;# Bool: Zero length input string
		set value	{}	;# Mixed: Decimal representation the validate value or {} (no value)

		# Detect zero length input string
		if {[string length $content]} {
			set zero_length 0
		} else {
			set zero_length 1
			set content 0
		}

		# Validate input string
		switch -- $type {
			{h} {	;# Hexadecimal
				if {![regexp {^[[:xdigit:]]{0,2}$} $content]} {
					set result 0
				} else {
					scan $content "%x" value
				}
			}
			{d} {	;# Decimal
				if {![regexp {^[[:digit:]]{0,3}$} $content]} {
					set result 0
				} elseif {$content > 255} {
					set result 0
				} else {
					set value $content
				}
			}
			{b} {	;# Binary
				if {![regexp {^[01]{0,8}$} $content]} {
					set result 0
				} else {
					set value [NumSystem::bin2dec $content]
				}
			}
			{o} {	;# Octal
				if {![regexp {^[0-7]{0,3}$} $content]} {
					set result 0
				} elseif {$content > 377} {
					set result 0
				} else {
					scan $content "%o" value
				}
			}
			{c0} {	;# BCD - Low order nibble
				if {![regexp {^[[:digit:]]{0,2}$} $content]} {
					set result 0
				} elseif {$content > 15} {
					set result 0
				} else {
					set value [$entry_c1($row) get]
					if {![string length $value]} {
						set value 0
					}
					set value [expr {$content + ($value << 4)}]
				}
				set zero_length 0
			}
			{c1} {	;# BCD - High order nibble
				if {![regexp {^[[:digit:]]{0,2}$} $content]} {
					set result 0
				} elseif {$content > 15} {
					set result 0
				} else {
					set value [$entry_c0($row) get]
					if {![string length $value]} {
						set value 0
					}
					set value [expr {$value + ($content << 4)}]
				}
				set zero_length 0
			}
			{a} {	;# ASCII
				if {$zero_length} {
					set content {}
				}
				set zero_length 0

				if {[string length $content] > 1} {
					set result 0
				} else {
					set value [NumSystem::ascii2dec $content]
				}

				if {![string length $value]} {
					set value [$entry_d($row) get]
					if {![string length $value]} {
						set zero_length 1
					}
				}
			}
			{t} {	;# Bits (Do not validate, just accept)
				set value $content
			}
		}

		# Synchronize with the other entryboxes on the row
		if {$result} {
			fill_entryboxes $row $value $zero_length $type
		}

		# Finish ...
		set validation_in_progress 0
		return $result
	}

	## Synchronize the specified value with the other entryboxes on the row
	 # @parm Int row		- Row number
	 # @parm Int value		- Value to fill in (in decimal)
	 # @parm Bool zero_length	- Just clear all entryboxes
	 # @parm Char exclude		- Entrybox to exclude during filling
	 #	h  - Hexadecimal
	 #	d  - Decimal
	 #	b  - Binary
	 #	o  - Octal
	 #	c0 - BCD - Low order nibble
	 #	c1 - BCD - High order nibble
	 #	a  - ASCII
	 #	t  - No meaning ...
	 # @return void
	private method fill_entryboxes {row value zero_length exclude} {
		# Clear entryboxes on the left
		foreach w [list				\
				$entry_h($row)	$entry_d($row)	\
				$entry_b($row)	$entry_o($row)	\
			] t {
				h		d
				b		o
			}	\
		{
			if {$exclude == $t} {
				continue
			}
			$w delete 0 end
		}

		# Fill in entryboxes on the left
		if {!$zero_length} {
			if {$exclude != {h}} {
				$entry_h($row) insert 0 [format {%X} $value]
			}
			if {$exclude != {d}} {
				$entry_d($row) insert 0 $value
			}
			if {$exclude != {b}} {
				$entry_b($row) insert 0 [NumSystem::dec2bin $value]
			}
			if {$exclude != {o}} {
				$entry_o($row) insert 0 [format {%o} $value]
			}
		}

		if {$row < $right_rows_created} {
			# Clear entryboxes on the right
			foreach w [list $entry_c0($row) $entry_c1($row) $entry_a($row)] \
				t {c0 c1 a} \
			{
				if {$exclude == $t} {
					continue
				}

				$w delete 0 end
			}

			# Adjust canvas widget with bit rectangles
			set mask 1
			for {set i 0} {$i < 8} {incr i} {
				if {$zero_length} {
					set fill {#FFFFFF}
					set outline {#888888}
				} elseif {[expr $value & $mask]} {
					set fill ${::BitMap::one_fill}
					set outline ${::BitMap::one_outline}
				} else {
					set fill ${::BitMap::zero_fill}
					set outline ${::BitMap::zero_outline}
				}

				$entry_t($row) itemconfigure $bit($row,$i)	\
					-fill $fill -outline $outline

				set mask [expr {$mask << 1}]
			}

			# Fill in entryboxes on the right
			if {!$zero_length} {
				if {$exclude != {c0}} {
					$entry_c0($row) insert 0 [expr {$value & 0x0F}]
				}
				if {$exclude != {c1}} {
					$entry_c1($row) insert 0 [expr {$value >> 4}]
				}
				if {$exclude != {a}} {
					if {$value > 31 && $value < 127} {
						$entry_a($row) insert 0 [format {%c} $value]
					}
				}
			}
		}
	}

	## Handles event <Enter> on canvas widget with bits,
	 # @parm Int r - Row number (0..5)
	 # @parm Int b - Bit number (0..7)
	 # @return void
	public method bit_enter {r b} {
		# Determinate current rectangle fill and outline
		set fill [$entry_t($r) itemcget $bit($r,$b) -fill]
		set outline [$entry_t($r) itemcget $bit($r,$b) -outline]

		# Determinate new rectangle fill and outline
		if {$fill == ${::BitMap::one_fill}} {
			set fill ${::BitMap::one_a_fill}
			set outline ${::BitMap::one_a_outline}
		} elseif {$fill == ${::BitMap::zero_fill}} {
			set fill ${::BitMap::zero_a_fill}
			set outline ${::BitMap::zero_a_outline}
		}

		# Set new rectangle fill and outline and adjust cursor
		$entry_t($r) itemconfigure $bit($r,$b)	\
			-fill $fill -outline $outline
		$entry_t($r) configure -cursor hand2
	}

	## Handles event <leave> on canvas widget with bits,
	 # @parm Int r - Row number (0..5)
	 # @parm Int b - Bit number (0..7)
	 # @return void
	public method bit_leave {r b} {
		# Determinate current rectangle fill and outline
		set fill [$entry_t($r) itemcget $bit($r,$b) -fill]
		set outline [$entry_t($r) itemcget $bit($r,$b) -outline]

		# Determinate new rectangle fill and outline
		if {$fill == ${::BitMap::one_a_fill}} {
			set fill ${::BitMap::one_fill}
			set outline ${::BitMap::one_outline}
		} elseif {$fill == ${::BitMap::zero_a_fill}} {
			set fill ${::BitMap::zero_fill}
			set outline ${::BitMap::zero_outline}
		}

		# Set new rectangle fill and outline and adjust cursor
		$entry_t($r) itemconfigure $bit($r,$b)	\
			-fill $fill -outline $outline
		$entry_t($r) configure -cursor left_ptr
	}

	## Handles event <Button-1> on canvas widget with bits,
	 # @parm Int r - Row number (0..5)
	 # @parm Int b - Bit number (0..7)
	 # @return void
	public method bit_click {r b} {
		# Determinate current rectangle fill
		set fill [$entry_t($r) itemcget $bit($r,$b) -fill]

		# Determinate new bit value
		if {
			$fill == ${::BitMap::one_a_fill}
				||
			$fill == ${::BitMap::one_fill}
		} then {
			set value 0
		} else {
			set value [expr {1 << $b}]
		}

		# Determinate new value for the whole row
		set dec [$entry_d($r) get]
		if {![string length $dec]} {
			set dec 0
		}
		set dec [expr {$dec & (0x0FF ^ (1 << $b))}]
		incr dec $value

		# Set new value for the whole row
		validate {t} $r $dec
	}

	## Set envent binds specific to this appliaction for the specified entrybox
	 # @parm Widget w	- Entrybox widget
	 # @parm Char t		- Entrybox type
	 #	h  - Hexadecimal
	 #	d  - Decimal
	 #	b  - Binary
	 #	o  - Octal
	 #	c0 - BCD - Low order nibble
	 #	c1 - BCD - High order nibble
	 #	a  - ASCII
	 # @parm Int r		- Row number (0..5)
	 # @return void
	private method set_bindings_for_an_entrybox {w t r} {
		bind $w <Key-Up>		"$this entry_key $t $r u; break"
		bind $w <Key-Down>		"$this entry_key $t $r d; break"
		bind $w <Key-Left>		"$this entry_key $t $r l; break"
		bind $w <Key-Right>		"$this entry_key $t $r r; break"
		bind $w <Key-Tab>		"$this entry_key $t $r t; break"
		if {!$::MICROSOFT_WINDOWS} {
			bind $w <Key-ISO_Left_Tab> "$this entry_key $t $r s; break"
		}
		bind $w <Key-Return>		"$this entry_key $t $r e; break"
		bind $w <Key-KP_Enter>		"$this entry_key $t $r e; break"

		bind $w <FocusIn>		"$this entry_focus $t $r 1"
		bind $w <FocusOut>		"$this entry_focus $t $r 0"
	}

	## Create the left frame of the window
	 # @return void
	private method create_left_frame {} {
		# Create labels
		if {!$left_rows_created} {
			set col 1
			foreach text {
				{HEX} {DEC} {BIN} {OCT}
			} {
				grid [label $left_top_frame.header_lbl_${col}		\
					-font $::smallfont -text [mc $text] -pady 0	\
				] -pady 0 -ipady 0 -row 1 -column $col
				incr col
			}
		}

		# Create entryboxes
		set row 0
		for {set row $left_rows_created} {$row < ($large ? 6 : 3)} {incr row} {
			set col 1
			foreach width {
					2 3 8 3
				} type {
					h d b o
				}	\
			{
				set entry_wgd [ttk::entry $left_top_frame.e_${type}_$row	\
					-width $width						\
					-validate key 						\
					-validatecommand "$this validate $type $row %P"		\
					-style BaseConverter_NotFocused.TEntry			\
					-font $entry_font					\
				]
				set entry_${type}($row) $entry_wgd
				grid $entry_wgd -row [expr {$row + 2}] -column $col

				set_bindings_for_an_entrybox $entry_wgd $type $row

				incr col
			}
		}
		set left_rows_created $row

		if {$large} {
			for {set i 0; set j 3} {$i < 3} {incr i; incr j} {
				validate {t} $j [lindex $val_to_set $i]
			}
		}
	}

	## Create the left frame of the window
	 # @return void
	private method create_right_frame {} {
		# Create labels
		if {!$right_rows_created} {
			set col 1
			grid [label $right_top_frame.header_lbl_${col}		\
				-font $::smallfont -text [mc "Bits"] -pady 0	\
			] -pady 0 -ipady 0 -row 1 -column $col
			incr col
			grid [label $right_top_frame.header_lbl_${col}		\
				-font $::smallfont -text [mc "BCD"] -pady 0	\
			] -pady 0 -ipady 0 -row 1 -column $col -columnspan 2
			incr col 2
			grid [label $right_top_frame.header_lbl_${col}	\
				-font $::smallfont -text [mc "ASCII"] -pady 0\
			] -pady 0 -ipady 0 -row 1 -column $col
			incr col
		}

		# Create entryboxes and canvas widget
		set row 0
		for {set row $right_rows_created} {$row < ($large ? 6 : 3)} {incr row} {
			set col 1
			foreach type {
					t c a
				}	\
			{
				switch -- $type {
					{a} {	;# ASCII
						set entry_wgd [ttk::entry $right_top_frame.e_${type}_$row	\
							-width 2						\
							-validate all						\
							-validatecommand "$this validate ${type} $row %P"	\
							-style BaseConverter_NotFocused.TEntry			\
							-font $entry_font					\
						]
						set entry_${type}($row) $entry_wgd
						grid $entry_wgd -row [expr {$row + 2}] -column $col
						set_bindings_for_an_entrybox $entry_wgd $type $row
					}
					{c} {	;# BCD
						set entry_wgd [ttk::entry $right_top_frame.e_${type}1_$row	\
							-width 2						\
							-validate all						\
							-validatecommand "$this validate ${type}1 $row %P"	\
							-style BaseConverter_NotFocused.TEntry			\
							-font $entry_font					\
						]
						set entry_${type}1($row) $entry_wgd
						grid $entry_wgd -row [expr {$row + 2}] -column $col
						set_bindings_for_an_entrybox $entry_wgd "${type}1" $row

						incr col

						set entry_wgd [ttk::entry $right_top_frame.e_${type}0_$row	\
							-width 2						\
							-validate all						\
							-validatecommand "$this validate ${type}0 $row %P"	\
							-style BaseConverter_NotFocused.TEntry			\
							-font $entry_font					\
						]
						set entry_${type}0($row) $entry_wgd
						grid $entry_wgd -row [expr {$row + 2}] -column $col
						set_bindings_for_an_entrybox $entry_wgd "${type}0" $row
					}
					{t} {	;# Bits
						set x0 2

						set y0 0
						set y1 2


						set canvas [canvas $right_top_frame.canvas_${row}	\
							-width 118 -height 18 -bd 0 -bg white		\
							-relief flat -highlightthickness 0		\
						]
						grid $canvas -row [expr {$row + 2}] -column $col
						set entry_${type}($row) $canvas

						for {set b 7} {$b >= 0} {incr b -1} {

							# Create bit rectagle
							set bit($row,$b) [$canvas create	\
								rectangle $x0 $y1		\
								[expr {$x0 + 12}]		\
								[expr {$y1 + 12}]		\
								-fill {#FFFFFF}			\
								-outline {#888888}		\
							]

							$canvas bind $bit($row,$b) <Enter> "$this bit_enter $row $b"
							$canvas bind $bit($row,$b) <Leave> "$this bit_leave $row $b"
							$canvas bind $bit($row,$b) <Button-1> "$this bit_click $row $b"

							# Adjust X position for the next rectagle
							incr x0 14
							if {$b == 4} {
								incr x0 3
							}
						}
					}
				}

				incr col
			}
		}
		set right_rows_created $row
	}

	## Switch between modes "Enlarged" and "Shrinked"
	 # @return void
	public method enlarge_shrink {} {
		# Invert the mode flag
		set large [expr {!$large}]

		# Adjust buttons on the bottom bar and create the missing widgets if nessesary
		if {$large} {
			create_right_frame
			create_left_frame
			$win_obj geometry {} [expr {[winfo height $entry_h(0)] * 3 + $INITIAL_HEIGHT}] {} {}
			$enlarge_shrink_button configure	\
				-image ::ICONS::16::1uparrow	\
				-text [mc "Shrink"]
		} else {
			$win_obj geometry {} $INITIAL_HEIGHT {} {}
			$enlarge_shrink_button configure	\
				-image ::ICONS::16::1downarrow	\
				-text [mc "Enlarge"]

			for {set i 0; set j 3} {$i < 3} {incr i; incr j} {
				lset val_to_set $i [$entry_d($j) get]
			}
		}

		# Show or hide appropriate GUI elements
		foreach w [list						\
				entry_h		entry_d		entry_b	\
				entry_o		entry_t		entry_c1\
				entry_c0	entry_a			\
			] c {
				1		2		3
				4		1		2
				3		4
		} {
			for {set i 3; set r 5} {$i < 6} {incr i; incr r} {
				if {$large} {
					grid [subst -nocommands "\$${w}($i)"] -column $c -row $r
				} else {
					grid forget [subst -nocommands "\$${w}($i)"]
				}
			}
		}

	}

	## Switch between modes "More" and "Less"
	 # @return void
	public method less_more {} {
		# Invert the mode flag
		set less_more [expr {!$less_more}]

		# Adjust GUI
		if {$less_more} {
			create_right_frame
			pack $right_top_frame -side left -anchor nw
			$less_more_button configure			\
				-compound left -text [mc "Less"]	\
				-image ::ICONS::16::1leftarrow
			$win_obj geometry $EXTENDED_WIDTH {} {} {}

			for {set i 0} {$i < $right_rows_created} {incr i} {
				validate {t} $i [$entry_d($i) get]
			}
		} else {
			pack forget $right_top_frame
			$less_more_button configure			\
				-compound right -text [mc "More"]	\
				-image ::ICONS::16::1rightarrow
			$win_obj geometry $INITIAL_WIDTH {} {} {}
		}
	}

	## Entybox event handler for <FocusIn> and <FocusOut>
	 # Change entryboxes background colors
	 # @parm Char type	- Entrybox type
	 #	h  - Hexadecimal
	 #	d  - Decimal
	 #	b  - Binary
	 #	o  - Octal
	 #	c0 - BCD - Low order nibble
	 #	c1 - BCD - High order nibble
	 #	a  - ASCII
	 # @parm Int row	- Row number (0..5)
	 # @parm Bool focused	- 1 == <FocusIn>; 0 == <FocusOut>
	 # @return void
	public method entry_focus {type row focused} {
		if {$focused} {
			set style BaseConverter_Focused_I.TEntry
			set bg {#DDDDFF}
		} else {
			set style BaseConverter_NotFocused.TEntry
			set bg {#FFFFFF}
		}

		foreach w [list						\
				$entry_h($row)		$entry_d($row)	\
				$entry_b($row)		$entry_o($row)	\
			]						\
		{
			$w configure -style $style
		}

		if {$right_rows_created > $row} {
			foreach w [list				\
					$entry_c1($row)		\
					$entry_c0($row)		\
					$entry_a($row)		\
				]				\
			{
				$w configure -style $style
			}

			$entry_t($row) configure -bg $bg
		}

		if {$focused} {
			[subst -nocommands "\$entry_${type}($row)"] configure -style BaseConverter_Focused_D.TEntry
		} else {
			[subst -nocommands "\$entry_${type}($row)"] selection clear
		}

	}


	## Entybox event handler for <Key-Up>, <Key-Down>, <Key-Left>, <Key-Right>, <Key-Tab>,
	 #+ <Key-ISO_Left_Tab>, <Key-Return> and <Key-KP_Enter>
	 # @parm Char type	- Entrybox type
	 #	h  - Hexadecimal
	 #	d  - Decimal
	 #	b  - Binary
	 #	o  - Octal
	 #	c0 - BCD - Low order nibble
	 #	c1 - BCD - High order nibble
	 #	a  - ASCII
	 # @parm Int y		- Row number (0..5)
	 # @parm Char key	- Key pressed
	 #	u - Up
	 #	d - Down
	 #	l - Left
	 #	r - Right
	 #	t - Tab
	 #	s - Shift-Tab
	 #	e - Enter
	 # @return void
	public method entry_key {type y key} {
		set entrybox [subst -nocommands "\$entry_${type}($y)"]
		set insert [$entrybox index insert]
		set max_y $left_rows_created
		incr max_y -1
		switch -- $type {
			{h}  {set x 0}
			{d}  {set x 1}
			{b}  {set x 2}
			{o}  {set x 3}
			{c1} {set x 4}
			{c0} {set x 5}
			{a}  {set x 6}
		}

		$entrybox selection clear
		switch -- $key {
			{u} {	;# Up
				if {!$y} {
					return
				}
				incr y -1
			}
			{d} {	;# Down
				if {$y == $max_y} {
					return
				}
				incr y
			}
			{l} {	;# Left
				if {!$x || $insert} {
					$entrybox icursor [expr {$insert-1}]
					return
				}
				incr x -1
			}
			{r} {	;# Right
				if {($x == 6) || ($insert != [$entrybox index end])} {
					$entrybox icursor [expr {$insert+1}]
					return
				}
				incr x
			}
			{t} {	;# Tab
				if {$x == 6} {
					return
				}
				incr x
			}
			{s} {	;# Shift-Tab
				if {!$x} {
					return
				}
				incr x -1
			}
			{e} {	;# Enter
				if {$y == $max_y} {
					return
				}
				incr y
			}
		}

		if {$x > 3 && $y >= $right_rows_created} {
			return
		}

		set insert [expr {[$entrybox index end] - $insert}]
		switch -- $x {
			{0} {set type h}
			{1} {set type d}
			{2} {set type b}
			{3} {set type o}
			{4} {set type c1}
			{5} {set type c0}
			{6} {set type a}
		}
		set entrybox [subst -nocommands "\$entry_${type}($y)"]
		$entrybox selection range 0 end
		$entrybox icursor [expr {[$entrybox index end] - $insert}]
		focus $entrybox
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

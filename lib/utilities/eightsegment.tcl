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
if { ! [ info exists _EIGHTSEGMENT_TCL ] } {
set _EIGHTSEGMENT_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# 8 segment LED display configurator
# --------------------------------------------------------------------------

class EightSegment {
	public common ld_ed_count	0		;# Int: Counter of object instances

	private variable obj_idx	;# Int: Current object ID
	private variable win		;# Widget: Dialog window
	private variable canvas_widget	;# Widget: Canvas widget for LED display
	private variable status_bar	;# Widget: Status bar label
	private variable leds		;# Array of Bool: key == "Segment number" (0..7); value == ON/OFF (0|1)
	private variable canvas_objects	;# Array: LED segments in canvas widget
	private variable validation_ena 1 ;# Bool: Entryboxs validation enabled

	private variable cc_hex_entry	;# Widget: Entrybox "Common cathode - Hex"
	private variable cc_dec_entry	;# Widget: Entrybox "Common cathode - Dec"
	private variable cc_bin_entry	;# Widget: Entrybox "Common cathode - Bin"
	private variable ca_hex_entry	;# Widget: Entrybox "Common anode - Hex"
	private variable ca_dec_entry	;# Widget: Entrybox "Common anode - Dec"
	private variable ca_bin_entry	;# Widget: Entrybox "Common anode - Bin"

	private variable seg2pin	;# Array of Int: Segment no. -> Pin no.
	private variable cbx		;# Array of widget: ComboBox widgets for connecting LED's to pins

	constructor {} {
		# Create dialog window
		set win [toplevel .eightsegment${ld_ed_count} -class {8 segment editor} -bg ${::COMMON_BG_COLOR}]
		set obj_idx $ld_ed_count
		incr ld_ed_count

		# Restore last session
		for {set i 0} {$i < 8} {incr i} {
			set seg2pin($i) $i
			set leds($i) 0
		}
		array set seg2pin	[lindex ${::EightSegment::config} 0]
		array set leds		[lindex ${::EightSegment::config} 1]
		for {set i 0} {$i < 8} {incr i} {
			set ::EightSegment::con_${obj_idx}_$i $seg2pin($i)
		}

		create_gui		;# Create GUI elements
		refresh_canvas		;# Initialize canvas (LED diaplay)
		reconnect 0		;# Highight badly connected pins
		refresh_entryboxes	;# Refresh EntryBoxes with values

		# Set event bindings for the dialog window
		bindtags $win [list $win Toplevel all .]
		bind $win <Control-Key-q> "::itcl::delete object $this; break"

		# Set window parameters
		wm iconphoto $win ::ICONS::16::8seg
		wm title $win [mc "8 segment editor"]
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW "::itcl::delete object $this"
	}

	destructor {
		for {set i 0} {$i < 8} {incr i} {
			unset ::EightSegment::con_${obj_idx}_$i
		}

		set ::EightSegment::config [list [array get seg2pin] [array get leds]]
		destroy $win
	}

	## LED <-> PIN connection changed
	 # @parm Int segment - Number of segment LED
	 # @return void
	public method reconnect {segment} {
		# Unhighlight all ComboBoxes
		for {set i 0} {$i < 8} {incr i} {
			$cbx($i) configure -style TCombobox
		}

		# Highlight ComboBoxes related to pins which are in confict
		for {set segment 0} {$segment < 8} {incr segment} {
			set pin [subst -nocommands "\$::EightSegment::con_${obj_idx}_$segment"]
			set seg2pin($segment) $pin

			for {set i 0} {$i < 8} {incr i} {
				if {$i == $segment} {
					continue
				}

				if {$seg2pin($i) == $pin} {
					$cbx($i) configure -style EightSegment_RedFg.TCombobox
				}
			}
		}

		# Adjust display
		refresh_canvas
	}

	## Create window GUI
	 # @return void
	private method create_gui {} {
		# Create frames
		set main_frame [frame $win.main_frame]		;# Entryboxes (left) and canvas (right)
		set bottom_frame [frame $win.bottom_frame]	;# Status bar and button "Exit"

		# Create status bar
		set status_bar [label $bottom_frame.status_bar	\
			-justify left -anchor w			\
		]

		ttk::style configure EightSegment_RedFg.TCombobox -foreground {#FF0000}

		## Create entryboxes
		 # - Common cathode
		set left_frame [frame $main_frame.left_frame]
		grid [label $left_frame.header_CC_lbl -text [mc "Common cathode"]] \
			-row 0 -column 0 -columnspan 4 -sticky w
		grid [label $left_frame.sub_header_CC_hex_lbl -text [mc "Hex:"]] \
			-row 1 -column 1 -sticky w
		grid [label $left_frame.sub_header_CC_dec_lbl -text [mc "Dec:"]] \
			-row 2 -column 1 -sticky w
		grid [label $left_frame.sub_header_CC_bin_lbl -text [mc "Bin:"]] \
			-row 3 -column 1 -sticky w
		set cc_hex_entry [ttk::entry $left_frame.cc_hex_ent	\
			-width 3					\
			-validate all					\
			-validatecommand "$this entry_validate C H %P"	\
		]
		set cc_dec_entry [ttk::entry $left_frame.cc_dec_ent	\
			-width 3					\
			-validate all					\
			-validatecommand "$this entry_validate C D %P"	\
		]
		set cc_bin_entry [ttk::entry $left_frame.cc_bin_ent	\
			-width 8					\
			-validate all					\
			-validatecommand "$this entry_validate C B %P"	\
		]
		grid $cc_hex_entry -row 1 -column 3 -sticky w
		grid $cc_dec_entry -row 2 -column 3 -sticky w
		grid $cc_bin_entry -row 3 -column 3 -sticky w
		foreach type {H D B} row {1 2 3} {
			grid [ttk::button $left_frame.copy_C${type}_but		\
				-command "$this copy_contents C ${type}"	\
				-image ::ICONS::16::editcopy			\
				-style Flat.TButton				\
			] -row $row -column 2 -sticky w -padx 3
			DynamicHelp::add $left_frame.copy_C${type}_but -text	\
				[mc "Copy contents of the entrybox to clipboard"]
			set_local_status_tip $left_frame.copy_C${type}_but [mc "Copy to clipboard"]
		}
		 # - Common anode
		grid [label $left_frame.header_CA_lbl -text [mc "Common anode"]] \
			-row 5 -column 0 -columnspan 4 -sticky w
		grid [label $left_frame.sub_header_CA_hex_lbl -text [mc "Hex:"]] \
			-row 6 -column 1 -sticky w
		grid [label $left_frame.sub_header_CA_dec_lbl -text [mc "Dec:"]] \
			-row 7 -column 1 -sticky w
		grid [label $left_frame.sub_header_CA_bin_lbl -text [mc "Bin:"]] \
			-row 8 -column 1 -sticky w
		set ca_hex_entry [ttk::entry $left_frame.ca_hex_ent	\
			-width 3					\
			-validate all					\
			-validatecommand "$this entry_validate A H %P"	\
		]
		set ca_dec_entry [ttk::entry $left_frame.ca_dec_ent	\
			-width 3					\
			-validate all					\
			-validatecommand "$this entry_validate A D %P"	\
		]
		set ca_bin_entry [ttk::entry $left_frame.ca_bin_ent	\
			-width 8					\
			-validate all					\
			-validatecommand "$this entry_validate A B %P"	\
		]
		grid $ca_hex_entry -row 6 -column 3 -sticky w
		grid $ca_dec_entry -row 7 -column 3 -sticky w
		grid $ca_bin_entry -row 8 -column 3 -sticky w
		foreach type {H D B} row {6 7 8} {
			grid [ttk::button $left_frame.copy_A${type}_but		\
				-command "$this copy_contents A ${type}"	\
				-image ::ICONS::16::editcopy			\
				-style Flat.TButton				\
			] -row $row -column 2 -sticky w -padx 3
			DynamicHelp::add $left_frame.copy_A${type}_but -text	\
				[mc "Copy contents of the entrybox to clipboard"]
			set_local_status_tip $left_frame.copy_A${type}_but [mc "Copy to clipboard"]
		}
		 # Set event bindings for entryboxes
		foreach widget [list					\
			${cc_hex_entry}	${cc_dec_entry}	${cc_bin_entry}	\
			${ca_hex_entry}	${ca_dec_entry}	${ca_bin_entry}	\
		] {
			bindtags $widget [list $widget TEntry $win all .]
		}
		 # Configure and pack left top frame
		grid rowconfigure $left_frame 4 -minsize 10
		grid columnconfigure $left_frame 0 -minsize 20
		pack $left_frame -side left -padx 5

		# Create canvas widget - LED display
		set canvas_widget [canvas $main_frame.canvas	\
			-width 125 -height 180 -bg white	\
			-bd 1 -relief solid			\
		]
		set canvas_objects(0) [$canvas_widget create polygon	\
			36 15	46 5	97 5	107 15	97 25	46 25	\
		]
		set canvas_objects(1) [$canvas_widget create polygon	\
			110 18	120 28	112 72	100 84	91 75	99 29	\
		]
		set canvas_objects(2) [$canvas_widget create polygon	\
			100 90	110 100	102 144	90 156	81 147	89 101	\
		]
		set canvas_objects(3) [$canvas_widget create polygon	\
			87 159	77 169	26 169	16 159	26 149	77 149	\
		]
		set canvas_objects(4) [$canvas_widget create polygon	\
			13 156	25 144	33 100	23 90	12 101	4 147	\
		]
		set canvas_objects(5) [$canvas_widget create polygon	\
			23 84	35 72	43 28	33 18	22 29	14 75	\
		]
		set canvas_objects(6) [$canvas_widget create polygon	\
			26 87	36 97	87 97	97 87	87 77	36 77	\
		]
		set canvas_objects(7) [$canvas_widget create oval 98 155 116 173]
		for {set i 0} {$i < 8} {incr i} {
			$canvas_widget itemconfigure $canvas_objects($i)	\
				-outline {#FF0000} -activeoutline {#00FF00}
			$canvas_widget bind $canvas_objects($i) <Button-1> "$this select_segment $i"
		}
		foreach coords {{70 15} {105 50} {95 125} {50 160} {20 125} {30 50} {60 88} {107 164}} \
			text {A B C D E F G P} \
			i {0 1 2 3 4 5 6 7} \
		{
			set obj [$canvas_widget create text		\
				[lindex $coords 0] [lindex $coords 1]	\
				-text $text -fill {#000000}		\
			]
			$canvas_widget bind $obj <Button-1> "$this select_segment $i"
		}
		pack $canvas_widget -side left -padx 5

		## Create right frame (Connections)
		set right_frame [frame $main_frame.right_frame]
		 # Header - "LED"
		grid [label $right_frame.header_0_lbl	\
			-text [mc "LED"]		\
		] -row 0 -column 0
		 # Header - "PIN"
		grid [label $right_frame.header_1_lbl	\
			-text [mc "PIN"]		\
		] -row 0 -column 1
		 # Create ComboBoxes and their labels
		for {set i 0} {$i < 8} {incr i} {
			grid [label $right_frame.pin_${i}_lbl	\
				-text [lindex {A B C D E F G P} $i]	\
			] -row [expr {$i + 1}] -column 0
			set cbx($i) [ttk::combobox $right_frame.cb_p$i		\
				-width 1					\
				-state readonly					\
				-values {0 1 2 3 4 5 6 7}			\
				-textvariable ::EightSegment::con_${obj_idx}_$i	\
			]
			bind $cbx($i) <<ComboboxSelected>> "$this reconnect $i"
			grid $cbx($i) -row [expr {$i + 1}] -column 1
		}
		 # Pack the right frame
		pack $right_frame -side left -padx 5 -anchor nw

		# Create button "Exit"
		pack [ttk::button $bottom_frame.close_but	\
			-compound left				\
			-text [mc "Close"]			\
			-command "::itcl::delete object $this"	\
			-image ::ICONS::16::exit		\
		] -side right -pady 5 -padx 5
		pack $status_bar -side left -fill x

		# Pack window frames
		pack $main_frame -fill both -expand 1 -pady 5 -side top
		pack $bottom_frame -fill x -side top
	}

	## Set status bar tip in this window only
	 # @parm Widget widget	- Widget related to the status tip
	 # @parm String text	- Status bar tip text
	 # @return void
	private method set_local_status_tip {widget text} {
		bind $widget <Enter> [list $status_bar configure -text $text]
		bind $widget <Leave> [list $status_bar configure -text {}]
	}

	## Copy contents of the specified exntrybox to clipboard
	 # @parm Char common_electrode	- C == Cathode; A == Anode
	 # @parm Char radix		- H == Hexadecimal; D == Decimal; B == Binary
	 # @return void
	public method copy_contents {common_electrode radix} {
		# Common cathode
		if {$common_electrode == {C}} {
			switch -- $radix {
				{H} {set widget ${cc_hex_entry}}
				{D} {set widget ${cc_dec_entry}}
				{B} {set widget ${cc_bin_entry}}
			}
		# Common anode
		} else {
			switch -- $radix {
				{H} {set widget ${ca_hex_entry}}
				{D} {set widget ${ca_dec_entry}}
				{B} {set widget ${ca_bin_entry}}
			}
		}

		clipboard clear
		clipboard append [$widget get]
	}

	## Invert LED in specified segment
	 # @parm Int i - Segment number
	 # @return void
	public method select_segment {i} {
		set leds($seg2pin($i)) [expr {!$leds($seg2pin($i))}]
		refresh_canvas
		refresh_entryboxes
	}

	## Value entrybox validator
	 # @parm Char common_electrode	- C == Cathode; A == Anode
	 # @parm Char radix		- H == Hexadecimal; D == Decimal; B == Binary
	 # @parm String value		- String to validate
	 # @return Bool - always 1
	public method entry_validate {common_electrode radix value} {
		if {![string length $value]} {return 1}
		if {!$validation_ena} {return 1}
		set validation_ena 0

		## Validate extrybox contents
		switch -- $radix {
			H {
				set max_length 2
				set char_class xdigit
			}
			D {
				set max_length 3
				set char_class digit
			}
			B {
				set max_length 8
				set char_class digit
				if {![regexp {^[01]*$} $value]} {
					set validation_ena 1
					return 0
				}
			}
		}
		if {[string length $value] > $max_length} {
			set validation_ena 1
			return 0
		}
		if {![string is $char_class -strict $value]} {
			set validation_ena 1
			return 0
		}

		# Convert value to decimal
		switch -- $radix {
			{H} {
				set value [expr "0x$value"]
			}
			{B} {
				set value [::NumSystem::bin2dec $value]
			}
			{D} {
				set value [string trimleft $value 0]
				if {$value == {}} {
					set value 0
				}
			}
		}

		# Adjust array $led() (LED states)
		if {$common_electrode == {C}} {
			set mask 1
			for {set i 0} {$i < 8} {incr i} {
				set leds($i) [expr {$value & $mask}]
				set mask [expr {$mask * 2}]
			}
		} else {
			set mask 1
			for {set i 0} {$i < 8} {incr i} {
				set leds($i) [expr {!($value & $mask)}]
				set mask [expr {$mask * 2}]
			}
		}

		# Adjust canvas and other entryboxes
		refresh_entryboxes ${common_electrode}${radix}
		refresh_canvas

		set validation_ena 1
		return 1
	}

	## Adjust canvas (LED display) to array $led (LED states)
	 # @return void
	private method refresh_canvas {} {
		for {set i 0} {$i < 8} {incr i} {
			if {$leds($seg2pin($i))} {
				$canvas_widget itemconfigure $canvas_objects($i) -fill #FF0000
			} else {
				$canvas_widget itemconfigure $canvas_objects($i) -fill #FFFFFF
			}
		}
	}

	## Adjust entryboxes to array $led (LED states)
	 # @parm String - Entrybox to exclude; value == ${common_electrode}${Number system}
	 # @return void
	private method refresh_entryboxes args {
		set validation_ena 0

		# Determinate value displayed on LED display
		set value 0
		set inv_value 255
		set mask 1
		for {set i 0} {$i < 8} {incr i} {
			if {$leds($i)} {
				incr value $mask
				incr inv_value -$mask
			}
			set mask [expr {$mask * 2}]
		}

		## Clear entryboxes
		if {$args != {CH}} {
			$cc_hex_entry delete 0 end
		}
		if {$args != {CD}} {
			$cc_dec_entry delete 0 end
		}
		if {$args != {CB}} {
			$cc_bin_entry delete 0 end
		}
		if {$args != {AH}} {
			$ca_hex_entry delete 0 end
		}
		if {$args != {AD}} {
			$ca_dec_entry delete 0 end
		}
		if {$args != {AB}} {
			$ca_bin_entry delete 0 end
		}

		## Fill in entryboxes
		if {$args != {CD}} {
			$cc_dec_entry insert insert $value
		}
		if {$args != {CH}} {
			set foo_value [format %X $value]
			if {[string length $foo_value] < 2} {
				set foo_value "0$foo_value"
			}
			$cc_hex_entry insert insert $foo_value
		}
		if {$args != {CB}} {
			set foo_value [::NumSystem::dec2bin $value]
			if {[string length $foo_value] < 8} {
				set foo_value "[string repeat 0 [expr {8 - [string length $foo_value]}]]$foo_value"
			}
			$cc_bin_entry insert insert $foo_value
		}

		if {$args != {AD}} {
			$ca_dec_entry insert insert $inv_value
		}
		if {$args != {AH}} {
			set foo_value [format %X $inv_value]
			if {[string length $foo_value] < 2} {
				set foo_value "0$foo_value"
			}
			$ca_hex_entry insert insert $foo_value
		}
		if {$args != {AB}} {
			set foo_value [::NumSystem::dec2bin $inv_value]
			if {[string length $foo_value] < 8} {
				set foo_value "[string repeat 0 [expr {8 - [string length $foo_value]}]]$foo_value"
			}
			$ca_bin_entry insert insert $foo_value
		}

		set validation_ena 1
	}
}
set ::EightSegment::config $::CONFIG(EIGHT_SEG_EDITOR)

# >>> File inclusion guard
}
# <<< File inclusion guard

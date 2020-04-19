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
if { ! [ info exists _DS1620_TCL ] } {
set _DS1620_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
#
# Consists of:
#	INTERNAL APPLICATION LOGIC
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM PALE ENGINE
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
# --------------------------------------------------------------------------

class Ds1620 {
	inherit VirtualHWComponent

	# Font: Font to be used in the panel -- bold
	public common cb_font	[font create				\
		-weight bold					\
		-size [expr {int(-10 * $::font_size_factor)}]	\
		-family {helvetica}				\
	]
	# Font: Font to be used in the panel -- bold
	public common small_font	[font create			\
		-size [expr {int(-9 * $::font_size_factor)}]	\
		-family {helvetica}				\
	]

	public common COMPONENT_NAME	"DS1620 temperature sensor"	;# Name of this component
	public common CLASS_NAME	"Ds1620"			;# Name of this class
	public common COMPONENT_ICON	{ds1620}			;# Icon for this panel (16x16)

	# Configuration menu
	public common CONFMENU {
		{checkbutton	"Disable delays"	{}	{::Ds1620::_no_delays}
			1 0 0	{no_delays_changed}
			""}
		{command	{Show DS1620 log}	{}	5	"show_log"	{bar5}
			"Display the log of events which are currently happening in the simulated DS1620 chip"}
		{separator}
		{command	{Show help}		{}	5	"show_help"	{help}
			"Show brief help"}
		{separator}
		{command	{Save configuration}	{}	0	"save_as"	{filesave}
			"Save configuration into a file"}
		{command	{Load configuration}	{}	0	"load_from"	{fileopen}
			"Load configuration from a file"}
		{separator}
		{checkbutton	"Window always on top"	{}	{::Ds1620::menu_keep_win_on_top}
			1 0 0	{keep_win_on_top_changed}
			""}
	}

	#
	public common STATUS_BITS		{DONE THF TLF NVB 1 0 CPU 1SHOT}
	public common MAX_LOG_LENGTH		100		;# Int: Maximum number of row in the log window
	public common SIGNAL_NAMES		{DQ CLK RST TH TL TCOM}
	public common EEPROM_WRITE_CYCLE_TIME	10000
	public common T_CONVERSION_TIME_MS	750
	public common _no_delays		0

	private variable input_error
	private variable input_error_desc

	private variable connection_port		;# Array of Int: Index is key number, value is port number or {-}
	private variable connection_pin			;# Array of Int: Index is key number, value is bit number or {-}

	private variable wires				;# Array of CanvasObject (line): Wire connection between the IC and the MCU
	private variable temp_ind_y_offset
	private variable temp_ind_x_offset
	private variable temperature		22
	private variable temp_point_y		0
	private variable enaged				;# Array of Bool: enaged(port_num,bit_num) --> Is connected to this device ?
	private variable ds1620_reg			;# Array of
	private variable entrybox			;# Array of
	private variable reg_bit			;# Array of
	private variable status				;# Array of
	private variable no_delays		0
	private variable log_win_text		{}
	private variable warning_indicator	{}
	private variable time_mark		0	;# Int: Time mark pointing to this point of time according to the MCU simulator engine
	private variable keep_win_on_top 0	;# Bool: Toplevel window
	private variable log_time_mark		0
	private variable log_window_geometry	{}
	private variable signal
	private variable log_enabled		1	;# Bool: Logging of events enabled (slower simulation)
	private variable log_on_off_chbut		;# Widget: Checkbox for enabling and disabling the logging of events

	private variable bit_number 0
	private variable byte_received
	private variable command_received	0
	private variable reception_or_transmission 1
	private variable receive_command_or_data 1
	private variable number_of_bits
	private variable data_to_send 0
	private variable conversion_running	0
	private variable delay_transmission	1
	private variable communication_disabled	0
	private variable write_to_NVM		0
	private variable t_conversion_time_mark	0
	private variable time_of
	private variable pending_communication	0


	# ------------------------------------------------------------------
	# INTERNAL APPLICATION LOGIC
	# ------------------------------------------------------------------

	## Object constructor
	 # @parm Object _project - Project object
	constructor {_project} {
		# Set object variables identifing this component (see the base class)
		set component_name	$COMPONENT_NAME
		set class_name		$CLASS_NAME
		set component_icon	$COMPONENT_ICON

		# Set other object variables
		set project $_project
		array set connection_port	{0 - 1 - 2 - 3 - 4 - 5 -}
		array set connection_pin	{0 - 1 - 2 - 3 - 4 - 5 -}
		array set ds1620_reg		{
			TH		30		TL		20
			TEMP		392		PER_C		100
			REMAIN		0		STATUS		136
		}
		array set signal {
			CLK		0		CLK_prev	0
			RST		0		RST_prev	0
			DQ		0		DQ_prev		0
			TH		0		TL		0
			TCOM		0
		}
		array set time_of {
			CLK_up		0		CLK_down	0
			RST_up		0		RST_down	0
			DQ_up		0		DQ_down		0
		}
		for {set port 0} {$port < 5} {incr port} {
			for {set bit 0} {$bit < 8} {incr bit} {
				set enaged($port,$bit) 0
			}
		}

		# Inform PALE
		$project pale_register_input_device $this
		$project pale_set_modified

		# Create panel GUI
		create_gui
		mcu_changed
		on_off [$project pale_is_enabled]
		reset_ds1620
		create_log

		# ComboBoxes to default state
		for {set i 0} {$i < 6} {incr i} {
			$canvas_widget.cb_b$i current 0
			$canvas_widget.cb_p$i current 0
		}
	}

	## Object destructor
	destructor {
		# Inform PALE
		$project pale_unregister_input_device $this

		# Destroy GUI
		destroy $win
	}

	## Value of configuration menu variable "keep_win_on_top" has been changed
	 # @return void
	public method keep_win_on_top_changed {} {
		set keep_win_on_top $Ds1620::menu_keep_win_on_top
		if {$keep_win_on_top} {
			wm attributes $win -topmost 1 -alpha 0.8
		} else {
			wm attributes $win -topmost 0 -alpha 1.0
		}
	}

	## Reconnect the specified line to another port pin
	 # @parm Int i - line number (0..5)
	 # @return void
	public method reconnect {i} {
		# Adjust connections
		set connection_port($i) [$canvas_widget.cb_p$i get]
		set connection_pin($i)	[$canvas_widget.cb_b$i get]
		if {$connection_pin($i) != {-}} {
			set connection_pin($i)	[expr {7 - $connection_pin($i)}]
		}

		# Reevaluate array of MCU port pins engaged by this device
		evaluete_enaged_pins

		# Change state of the device
		if {$drawing_on} {
			$project pale_reevaluate_IO
		}

		# Set flag modified
		set_modified
	}

	## Reevaluate array of MCU port pins engaged by this device
	 # @return void
	private method evaluete_enaged_pins {} {
		# Mark all as disengaged and infrom PALE
		for {set port 0} {$port < 5} {incr port} {
			for {set bit 0} {$bit < 8} {incr bit} {
				if {$enaged($port,$bit)} {
					$project pale_disengage_pin_by_input_device $port $bit $this
					set enaged($port,$bit) 0
				}
			}
		}

		# Find the engaged ones and infrom PALE
		for {set i 0} {$i < 6} {incr i} {
			if {$i == 1 || $i == 2} {
				continue
			}

			set port $connection_port($i)
			set bit $connection_pin($i)

			if {$port == {-} || $bit == {-}} {
				continue
			}

			set enaged($port,$bit) 1
			$project pale_engage_pin_by_input_device $port $bit $this
		}
	}

	## Create GUI of this panel
	 # @return void
	private method create_gui {} {
		# Create panel window and canvas widget
		set win [toplevel .ledpanel$count -class $component_name -bg ${::COMMON_BG_COLOR}]
		set canvas_widget [canvas $win.canvas	\
			-bg white -width 0 -height 0	\
			-highlightthickness 0		\
		]

		$canvas_widget create text 85 145	\
			-text [mc "Note"]		\
			-font $cb_font			\
			-anchor e
		$canvas_widget create window 90 145	\
			-window [ttk::entry $canvas_widget.usr_note	\
				-validate key				\
				-validatecommand "$this set_modified"	\
			]	\
			-width 405 -anchor w
		bindtags $canvas_widget.usr_note	\
			[list $canvas_widget.usr_note TEntry $win all .]


		draw_ic_package 73 10
		draw_combo_boxes 35 10
		draw_temperature_indicator 245 20
		draw_registers 280 30

		adjust_temp_ind

		# Create "ON/OFF" button
		set start_stop_button [ttk::button $canvas_widget.start_stop_button	\
			-command "$this on_off_button_press"				\
			-style Flat.TButton						\
			-width 3							\
		]
		DynamicHelp::add $canvas_widget.start_stop_button	\
			-text [mc "Turn HW simulation on/off"]
		setStatusTip -widget $start_stop_button -text [mc "Turn HW simulation on/off"]
		bind $start_stop_button <Button-3> "$this on_off_button_press; break"
		$canvas_widget create window 30 135 -window $start_stop_button -anchor nw
		bindtags $start_stop_button [list $start_stop_button TButton all .]

		# Create configuration menu button
		set conf_button [ttk::button $canvas_widget.conf_but	\
			-image ::ICONS::16::configure			\
			-style FlatWhite.TButton			\
			-command "$this config_menu"			\
		]
		setStatusTip -widget $conf_button -text [mc "Configure"]
		$canvas_widget create window 28 135 -window $conf_button -anchor ne
		bindtags $conf_button [list $conf_button TButton all .]

		# Pack canvas
		pack $canvas_widget -fill both -expand 1

		# Set window parameters
		wm minsize $win 500 160
		wm iconphoto $win ::ICONS::16::$component_icon
		wm title $win "[mc $component_name] - [$project cget -projectName] - MCU 8051 IDE"
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW "$this close_window"
		bindtags $win [list $win Toplevel all .]
	}

	public method reg_bit_event {type reg bit_no} {
		switch -- $type {
			1 {
				set ds1620_reg($reg) [expr {$ds1620_reg($reg) ^ (1 << $bit_no)}]
				update_reg $reg
			}
			{E} { ;# Enter
				set bit [expr {$ds1620_reg($reg) & (1 << $bit_no)}]
				if {$bit} {
					set fill ${::BitMap::one_a_fill}
					set outline ${::BitMap::one_a_outline}
				} else {
					set fill ${::BitMap::zero_a_fill}
					set outline ${::BitMap::zero_a_outline}
				}
				$canvas_widget itemconfigure $reg_bit($reg,$bit_no) -outline $outline -fill $fill
				$canvas_widget configure -cursor hand2
			}
			{L} { ;# Leave
				set bit [expr {$ds1620_reg($reg) & (1 << $bit_no)}]
				if {$bit} {
					set fill ${::BitMap::one_fill}
					set outline ${::BitMap::one_outline}
				} else {
					set fill ${::BitMap::zero_fill}
					set outline ${::BitMap::zero_outline}
				}
				$canvas_widget itemconfigure $reg_bit($reg,$bit_no) -outline $outline -fill $fill
				$canvas_widget configure -cursor left_ptr
			}
		}
	}

	private method draw_registers {x_offset y_offset} {
		set labels [list {TH} {TL} {TEMP}]
		for {set i 0} {$i < 3} {incr i} {
			set reg_name [lindex $labels $i]

			$canvas_widget create text \
				[expr {$x_offset + 0}] [expr {$y_offset + ($i * 20)}] \
				-text $reg_name \
				-font $cb_font \
				-anchor w

			set sep 0
			for {set j 0} {$j < 9} {incr j} {
				set k [expr {8 - $j}]
				set reg_bit($reg_name,$k) [$canvas_widget create rectangle \
					[expr {$x_offset + 38 + ($j * 13) + $sep}] [expr {$y_offset + ($i * 20) - 7}] \
					[expr {$x_offset + 38 + ($j * 13) + 10 + $sep}] [expr {$y_offset + ($i * 20) - 7 + 10}] \
					-width 1 \
				]
				switch -- $j {
					0 -
					4 {
						incr sep 3
					}
				}

				$canvas_widget bind $reg_bit($reg_name,$k) <Button-1> [list $this reg_bit_event 1 $reg_name $k]
				$canvas_widget bind $reg_bit($reg_name,$k) <Enter> [list $this reg_bit_event E $reg_name $k]
				$canvas_widget bind $reg_bit($reg_name,$k) <Leave> [list $this reg_bit_event L $reg_name $k]
			}
			set entrybox($reg_name) [ttk::entry $canvas_widget.reg_$reg_name	\
				-validate key							\
				-validatecommand [list $this validate_reg_entry $reg_name %P]	\
				-width 5							\
				-font $cb_font							\
			]
			$canvas_widget create window \
				[expr {$x_offset + 163}] [expr {$y_offset + ($i * 20) - 10}]	\
				-window $entrybox($reg_name) \
				-anchor nw

			$canvas_widget create text \
				[expr {$x_offset + 202}] [expr {$y_offset + ($i * 20)}] \
				-text {°C} \
				-font $cb_font \
				-anchor w
		}

		set i 7
		set sep 0
		foreach bit_name $STATUS_BITS {
			set status($bit_name) [$canvas_widget create text \
				[expr {$x_offset - 0 + $sep}] [expr {$y_offset + 70}] \
				-text $bit_name \
				-font $::Simulator_GUI::bitfont \
				-anchor w
			]

			if {$i != 3 && $i != 2} {
 				$canvas_widget bind $status($bit_name) <Enter> [list $this status_bit_event E $bit_name $i]
 				$canvas_widget bind $status($bit_name) <Leave> [list $this status_bit_event L $bit_name $i]
 				$canvas_widget bind $status($bit_name) <Button-1> [list $this status_bit_event 1 $bit_name $i]
 			} elseif {$i == 2} {
				$canvas_widget itemconfigure $status($bit_name) -fill ${::Simulator_GUI::off_color}
 			} elseif {$i == 3} {
				$canvas_widget itemconfigure $status($bit_name) -fill ${::Simulator_GUI::on_color}
 			}

			incr i -1
			incr sep 2
			incr sep [expr {9 * [string length $bit_name]}]
		}
	}

	public method validate_reg_entry {reg_name content} {
		if {![string length $content]} {
			return 1
		}
		if {[string index $content 0] == {-} && [string length $content] == 1} {
			return 1
		}
		if {[regexp {^\-?\d+\.$} $content]} {
			return 1
		}

		if {![regexp {^\-?(\d+(\.\d)?)?$} $content]} {
			return 0
		}

		if {$content > 127.5 || $content < -128.0} {
			return 0
		}

		if {$reg_name == {STATUS}} {
			set ds1620_reg($reg_name) $content
		} else {
			set content [expr {int($content * 2)}]
			if {$content < 0} {
				set content [expr {$content & 0x1ff}]
			}
			set ds1620_reg($reg_name) $content
		}
		update_reg $reg_name 1

		return 1
	}

	private method update_reg {reg_name {do_not_affect_entrybox 0}} {
		if {$reg_name == {STATUS}} {
			set i 7
			foreach bit_name $STATUS_BITS {
				if {$ds1620_reg(STATUS) & (1 << $i)} {
					set color ${::Simulator_GUI::on_color}
				} else {
					set color ${::Simulator_GUI::off_color}
				}
				$canvas_widget itemconfigure $status($bit_name) -fill $color

				incr i -1
			}
		} else {
			for {set bit_no 0} {$bit_no < 9} {incr bit_no} {
				set bit [expr {$ds1620_reg($reg_name) & (1 << $bit_no)}]
				if {$bit} {
					set outline ${::BitMap::one_outline}
					set fill ${::BitMap::one_fill}
				} else {
					set outline ${::BitMap::zero_outline}
					set fill ${::BitMap::zero_fill}
				}
				$canvas_widget itemconfigure $reg_bit($reg_name,$bit_no) -outline $outline -fill $fill
			}

			if {!$do_not_affect_entrybox} {
				set dec_val [expr {$ds1620_reg($reg_name) & 0xff}]
				if {$ds1620_reg($reg_name) & 0x100} {
					set dec_val [expr {$dec_val - 256}]
				}
				set dec_val [expr {$dec_val / 2.0}]
				$entrybox($reg_name) delete 0 end
				$entrybox($reg_name) insert 0 $dec_val
			}
		}

		if {$reg_name == {TEMP}} {
			update_outputs_Th_Tl_Tcom
		}
	}

	public method status_bit_event {type bit_name bit_no} {
		switch -- $type {
			{1} {
				set ds1620_reg(STATUS) [expr {$ds1620_reg(STATUS) ^ (1 << $bit_no)}]
				update_reg STATUS
			}
			{E} {
				$canvas_widget configure -cursor hand2
				$canvas_widget itemconfigure $status($bit_name) -font $::Simulator_GUI::bitfont_under
			}
			{L} {
				$canvas_widget configure -cursor left_ptr
				$canvas_widget itemconfigure $status($bit_name) -font $::Simulator_GUI::bitfont
			}
		}
	}

	private method draw_temperature_indicator {x_offset y_offset} {
		set x $x_offset
		set y $y_offset

		set temp_ind_x_offset $x_offset
		set temp_ind_y_offset $y_offset

		for {set i 0} {$i <= 100} {incr i} {
			$canvas_widget create line \
				[expr {$x + 0}] [expr {$y + $i}] \
				[expr {$x + 10}] [expr {$y + $i}] \
				-fill [format {#%02x33%02x} [expr {255 - int($i * 2.55)}] [expr {int($i * 2.55)}]] \
				-tags temperature_indicator
		}

		$canvas_widget create line \
			[expr {$x - 0}] [expr {$y + 0}] \
			[expr {$x - 15}] [expr {$y + 0}] \
			[expr {$x + 25}] [expr {$y + 0}] \
			[expr {$x + 10}] [expr {$y + 0}] \
			-fill {#000000} -arrow both \
			-tags {temperature_pointer temperature_indicator}

		$canvas_widget create text [expr {$x - 40}] [expr {$y - 8}] \
			-text {°C} \
			-font $cb_font \
			-anchor w \
			-tags temperature_C
		$canvas_widget create text [expr {$x + 50}] [expr {$y - 8}] \
			-text {°F} \
			-font $cb_font \
			-anchor e \
			-tags temperature_F


		$canvas_widget bind temperature_indicator <Button-1> [list $this temp_ind_event 1 %y]
		$canvas_widget bind temperature_indicator <Button-5> [list $this temp_ind_event 5]
		$canvas_widget bind temperature_indicator <Button-4> [list $this temp_ind_event 4]
		$canvas_widget bind temperature_indicator <B1-Motion> [list $this temp_ind_event 1 %y]
	}

	private method adjust_temp_ind {} {
		set y [expr {100 - int(($temperature + 55) / 1.8)}]

		$canvas_widget move temperature_pointer 0 [expr {$y - $temp_point_y}]
		set temp_point_y $y

		$canvas_widget itemconfigure temperature_C -text [format {%s%3.1f°C} [expr {$temperature > 0 ? "" : "-"}] $temperature]
		$canvas_widget itemconfigure temperature_F -text [format {%s%3.1f°F} [expr {($temperature * (9.0/5) + 32) > 0 ? "" : "-"}] [expr {($temperature * (9.0/5) + 32)}]]
	}

	public method temp_ind_event {type {y 0}} {
		switch -- $type {
			1 {
				incr y -$temp_ind_y_offset
				set temperature [expr {180 - int($y * 1.8) - 55}]
			}
			4 { ;# Wheel up
				set temperature [expr {$temperature + 0.5}]
			}
			5 { ;# Wheel down
				set temperature [expr {$temperature - 0.5}]
			}
		}

		if {$temperature < -55} {
			set temperature -55
		} elseif {$temperature > 125} {
			set temperature 125
		}

		adjust_temp_ind
	}

	private method draw_combo_boxes {x_offset y_offset} {
		set x $x_offset
		set y $y_offset

		incr y 12

		for {set i 0} {$i < 6} {incr i} {
			$canvas_widget create window $x $y -anchor e	\
				-window [ttk::combobox $canvas_widget.cb_p$i	\
					-width 1				\
					-font $cb_font				\
					-state readonly				\
				]
			bind $canvas_widget.cb_p$i <<ComboboxSelected>> "$this reconnect $i"

			$canvas_widget create window $x $y -anchor w	\
				-window [ttk::combobox $canvas_widget.cb_b$i	\
					-width 1				\
					-font $cb_font				\
					-values {- 0 1 2 3 4 5 6 7}		\
					-state readonly				\
				]
			bind $canvas_widget.cb_b$i <<ComboboxSelected>> "$this reconnect $i"

			bindtags $canvas_widget.cb_p$i	\
				[list $canvas_widget.cb_p$i TCombobox all .]
			bindtags $canvas_widget.cb_b$i	\
				[list $canvas_widget.cb_b$i TCombobox all .]

			if {$i == 2} {
				incr x 160
				incr y -25
			} else {
				incr y 25
			}
		}

		$canvas_widget create text		\
			[expr {$x_offset + 0}]		\
			[expr {$y_offset + 5 + 3*25}]	\
			-text [mc "PORT"]		\
			-font $cb_font			\
			-anchor e
		$canvas_widget create text		\
			[expr {$x_offset + 5}]		\
			[expr {$y_offset + 5 + 3*25}]	\
			-text [mc "BIT"]		\
			-font $cb_font			\
			-anchor w

		$canvas_widget create text		\
			[expr {$x_offset + 160}]	\
			[expr {$y_offset + 21}]		\
			-text [mc "PORT"]		\
			-font $cb_font			\
			-anchor e
		$canvas_widget create text		\
			[expr {$x_offset + 165}]	\
			[expr {$y_offset + 21}]		\
			-text [mc "BIT"]		\
			-font $cb_font			\
			-anchor w
	}

	private method draw_ic_package {x_offset y_offset} {
		$canvas_widget create line \
			[expr {$x_offset + 15}] [expr {$y_offset + 0}] \
			[expr {$x_offset + 70}] [expr {$y_offset + 0}] \
			[expr {$x_offset + 70}] [expr {$y_offset + 100}] \
			[expr {$x_offset + 15}] [expr {$y_offset + 100}] \
			[expr {$x_offset + 15}] [expr {$y_offset + 0}] \
			-fill {#000000}

		$canvas_widget create text \
			[expr {$x_offset + 42}] [expr {$y_offset + 102}] \
			-text {DS1620} \
			-anchor n \
			-font [font create -family $::DEFAULT_FIXED_FONT -size -13]

		set i 0
		for {set x 0} {$x < 2} {incr x} {
			for {set y 0} {$y < 4} {incr y} {
				$canvas_widget create rectangle \
					[expr {$x_offset + ($x * 70) + 0}] [expr {$y_offset + ($y * 25) + 5}] \
					[expr {$x_offset + ($x * 70) + 15}] [expr {$y_offset + ($y * 25) + 20}] \
					-fill {#ffffff}
				$canvas_widget create text \
					[expr {$x_offset + ($x * 70) + 7}] [expr {$y_offset + ($y * 25) + 13}] \
					-text [lindex {1 2 3 4 8 7 6 5} $i] \
					-font $cb_font
				$canvas_widget create text \
					[expr {$x_offset + ($x ? 39 : 10) + 7}] [expr {$y_offset + ($y * 25) + 13}] \
					-text [lindex {DQ CLK RST GND V T T T} $i] \
					-font $small_font \
					-anchor w
				if {$i > 3} {
					$canvas_widget create text \
						[expr {$x_offset + 45 + 7}] [expr {$y_offset + ($y * 25) + 18}] \
						-text [lindex {{} {} {} {} dd high low com} $i] \
						-font $small_font \
						-anchor w
				}

				set line [$canvas_widget create line \
					[expr {$x_offset + ($x ? 85 : -15)}] [expr {$y_offset + ($y * 25) + 12}] \
					[expr {$x_offset + ($x ? 100 : 0)}] [expr {$y_offset + ($y * 25) + 12}] \
				]
				if {$i < 3 || $i > 4} {
					if {$i < 3} {
						set j $i
					} else {
						set j [expr {$i - 2}]
					}
					set wires($j) $line

				# GND
				} elseif {$i == 3} {
					$canvas_widget itemconfigure $line -fill {#00ff00}
					$canvas_widget create line \
						[expr {$x_offset - 15}] [expr {$y_offset + ($y * 25) + 12}] \
						[expr {$x_offset - 15}] [expr {$y_offset + ($y * 25) + 27}] \
						[expr {$x_offset - 7}] [expr {$y_offset + ($y * 25) + 27}] \
						[expr {$x_offset - 23}] [expr {$y_offset + ($y * 25) + 27}] \
						 -fill {#00ff00}

				# Vdd
				} elseif {$i == 4} {
					$canvas_widget itemconfigure $line -fill {#ff0000}
					$canvas_widget create line \
						[expr {$x_offset + 100}] [expr {$y_offset + ($y * 25) + 12}] \
						[expr {$x_offset + 100}] [expr {$y_offset + ($y * 25) - 3}] \
						 -fill {#ff0000} -arrow last
				}

				incr i
			}
		}

		$canvas_widget create arc \
			[expr {$x_offset + 37}] [expr {$y_offset - 5}] \
			[expr {$x_offset + 47}] [expr {$y_offset + 5}] \
			-start 0 \
			-extent -180
	}

	## Determinate which port pin is connected to the specified LED
	 # @parm Int i - LED number
	 # @return List - {port_number bit_number}
	private method which_port_pin {i} {
		return [list $connection_port($i) $connection_pin($i)]
	}

	## Handle "ON/OFF" button press
	 # Turn whole PALE system on or off
	 # @return void
	public method on_off_button_press {} {
		$project pale_all_on_off
	}

	## Show the log window
	 # The log window must have been once created by method create_log prior to
	 #+ the call to this method
	 # @return void
	public method show_log {} {
		if {$warning_indicator != {}} {
			$canvas_widget delete $warning_indicator
			set warning_indicator {}
		}

		set dialog $win.log_window
		if {[wm state $dialog] == {normal}} {
			raise $dialog
			return
		}
		if {![winfo exists $dialog]} {
			return
		}
		wm deiconify $dialog
		if {$log_window_geometry != {}} {
			wm geometry $dialog $log_window_geometry
		}
	}

	## Create the log dialog window, but do not show it until method show_log is called
	 # @return void
	public method create_log {} {
		# Create the dialog window (hidden for now)
		set dialog $win.log_window
		toplevel $dialog
		wm withdraw $dialog

		## Create main frame (text and scrollbar)
		set main_frame [frame $dialog.main_frame]
		 # Text widget
		set text_widget [text $main_frame.text				\
			-width 0 -height 0 -font $hlp_normal_font		\
			-yscrollcommand [list $main_frame.scrollbar set]	\
			-wrap word -padx 5 -pady 5 -state disabled		\
		]
		set log_win_text $text_widget
		bindtags $text_widget [list $text_widget Text $win all .]
		pack $text_widget -side left -fill both -expand 1
		 # Create text tag in the text widget
		$text_widget tag configure tag_info	-foreground {#FFFFFF} -background {#0000EE}
		$text_widget tag configure tag_warning	-foreground {#FFFFFF} -background {#EE8800}
		$text_widget tag configure tag_error	-foreground {#FFFFFF} -background {#DD0000}
		$text_widget tag configure tag_line \
			-background {#DDDDDD} \
			-font [font create \
				-family ${::DEFAULT_FIXED_FONT} \
				-size -1 \
			]

		 # Scrollbar
		pack [ttk::scrollbar $main_frame.scrollbar	\
			-orient vertical			\
			-command [list $text_widget yview]	\
		] -side right -fill y
		 # Finalize ...
		pack $main_frame -fill both -expand 1 -padx 2

		# Create bottom frame
		set bottom_frame [frame $dialog.bottom_frame]
		 # Button "Close"
		pack [ttk::button $bottom_frame.close_button	\
			-text [mc "Close"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command [list $this close_log_win]	\
		] -side right
		pack [ttk::button $bottom_frame.clear_button	\
			-text [mc "Clear log"]			\
			-compound left				\
			-image ::ICONS::16::editdelete		\
			-command "
				$text_widget configure -state normal
				$text_widget delete 0.0 end
				$text_widget configure -state disabled
			" \
		] -side left
		 # CheckBox: "Enable log"
		set log_on_off_chbut [checkbutton $bottom_frame.on_off_chbut	\
			-command [list $this log_on_off]			\
			-text [mc "Enable log"]					\
		]
		if {$log_enabled} {
			$log_on_off_chbut select
		} else {
			$log_on_off_chbut deselect
		}
		setStatusTip -widget $log_on_off_chbut -text [mc "Disabled logging may notably improve simulation speed"]
		DynamicHelp::add $log_on_off_chbut -text [mc "Disabled logging may notably improve simulation speed"]
		pack $log_on_off_chbut -side left -padx 5
		pack $bottom_frame -pady 2 -padx 5 -fill x

		# Set window parameters
		wm minsize $dialog [expr {int(300 * $::font_size_factor)}] [expr {int(150 * $::font_size_factor)}]
		wm iconphoto $dialog ::ICONS::16::bar5
		wm title $dialog [mc "DS1620 log - MCU 8051 IDE"]
		wm protocol $dialog WM_DELETE_WINDOW [list $this close_log_win]
		bindtags $dialog [list $dialog Toplevel $win all .]
	}

	## Enable or disable logging of events
	 # @return void
	public method log_on_off {} {
		set log_enabled [expr {!$log_enabled}]

		# Set flag modified
		set_modified
	}

	## Close the DS1620 log window
	 # @return void
	public method close_log_win {} {
		set dialog $win.log_window
		if {![winfo exists $dialog]} {
			return
		}

		set log_window_geometry [wm geometry $dialog]
		wm withdraw $dialog
	}

	## Informs the DS1620 simulator about change of _no_delays flag (used by configuration menu)
	 # @return void
	public method no_delays_changed {} {
		set no_delays ${::Ds1620::_no_delays}
	}

	## Write a message to the log
	 # @parm Char type	- Message type "I" == Information; "W" == Warning; "E" == Error
	 # @parm String string	- Text of the message
	 # @return void
	private method write_to_log {type string} {
		# Do not do anything if the log is not available at all
		if {!$log_enabled || $log_win_text == {}} {
			return
		}

		# Enable the text widget
		$log_win_text configure -state normal

		# Manage the log length, the number of row in the log must not exceed the specified maximum
		if {int([$log_win_text index end]) > ($MAX_LOG_LENGTH + 1)} {
			set diff [expr {int([$log_win_text index end]) - $MAX_LOG_LENGTH}]
			$log_win_text delete 1.0 $diff.0
		}
		$log_win_text mark set insert {end -1l lineend}

		# Insert separators (horizontal lines) between events with the same time mark
		if {$time_mark && $log_time_mark != $time_mark} {
			set log_time_mark $time_mark
			$log_win_text insert insert "\n"
			$log_win_text tag add tag_line insert-1l insert
		}

		# Insert the information about the message type
		switch -- $type {
			{I} {	;# Information
				$log_win_text insert insert [mc "\[INFO\] "]
				$log_win_text tag add tag_info {insert linestart} insert-1c
			}
			{W} {	;# Warning
				$log_win_text insert insert [mc "\[WARNING\] "]
				$log_win_text tag add tag_warning {insert linestart} insert-1c
			}
			{E} {	;# Error
				$log_win_text insert insert [mc "\[ERROR\] "]
				$log_win_text tag add tag_error {insert linestart} insert-1c
			}
		}

		# Insert the message itself
		$log_win_text insert insert $string
		$log_win_text insert insert "\n"
		$log_win_text see insert

		# Disable the text widget
		$log_win_text configure -state disabled

		#
		if {$type == {E} && $warning_indicator == {}} {
			set warning_indicator [$canvas_widget create image 35 105 -anchor ne -image ::ICONS::16::status_unknown]
			$canvas_widget bind $warning_indicator <Button-1> [list $this show_log]
			$canvas_widget bind $warning_indicator <Enter> {%W configure -cursor hand2}
			$canvas_widget bind $warning_indicator <Leave> {%W configure -cursor left_ptr}
		}
	}


	# ------------------------------------------------------------------
	# DS1620 INTERNAL FUNCTIONS
	# ------------------------------------------------------------------

	private method update_outputs_Th_Tl_Tcom {} {
		set temp_dec $ds1620_reg(TEMP)
		set th_dec $ds1620_reg(TH)
		set tl_dec $ds1620_reg(TL)

		if {$temp_dec & 0x100} {
			incr temp_dec -512
		}
		if {$th_dec & 0x100} {
			incr th_dec -512
		}
		if {$tl_dec & 0x100} {
			incr tl_dec -512
		}

		if {$temp_dec > $th_dec} {
			if {!$signal(TH)} {
				write_to_log I [mc "Current temperature exceeds TH temperature"]
			}

			set signal(TH) 1
			set signal(TCOM) 1

			set ds1620_reg(STATUS) [expr {$ds1620_reg(STATUS) | 0x40}]
			update_reg STATUS
		} else {
			set signal(TH) 0
		}
		if {$temp_dec < $tl_dec} {
			if {!$signal(TL)} {
				write_to_log I [mc "Current temperature is below TL temperature"]
			}

			set signal(TL) 1
			set signal(TCOM) 0

			set ds1620_reg(STATUS) [expr {$ds1620_reg(STATUS) | 0x20}]
			update_reg STATUS
		} else {
			set signal(TL) 0
		}
	}

	private method finalize_conversion {} {
		# One-shot conversion mode
		if {$ds1620_reg(STATUS) & 0x01} {
			set conversion_running 0
		}

		if {$temperature < 0} {
			set ds1620_reg(TEMP) [expr {512 - int($temperature * -2)}]
		} else {
			set ds1620_reg(TEMP) [expr {int($temperature * 2)}]
		}
		set ds1620_reg(STATUS) [expr {$ds1620_reg(STATUS) | 0x80}]
		set ds1620_reg(REMAIN) [expr {int(rand() * 0x1ff)}]
		update_reg TEMP
		update_reg STATUS

		if {!$no_delays} {
			write_to_log I [mc "Temperature conversion finished"]
		}
	}

	private method proceed_with_t_conversion {} {
		if {!$t_conversion_time_mark} {
			restart_t_conversion
		}
		if {$no_delays || $t_conversion_time_mark <= $time_mark} {
			if {!$no_delays} {
				restart_t_conversion
			}
			finalize_conversion
		}
	}

	private method restart_t_conversion {} {
		write_to_log I [mc "Temperature conversion will be completed when MCU time reach %dns" [expr {$time_mark + $T_CONVERSION_TIME_MS * 1000000}]]
		set t_conversion_time_mark [expr {$time_mark + $T_CONVERSION_TIME_MS * 1000000}]
	}

	private method transmit_data {} {
		if {0 && $delay_transmission} {
			set delay_transmission 0
			return 0
		} else {
			set signal(DQ) [expr {($data_to_send & (1 << $bit_number)) ? 1 : 0}]
			incr bit_number

			if {$bit_number == $number_of_bits} {
				set communication_disabled 1
				set pending_communication 0
			}
			return 1
		}
	}

	private method receive_data {} {
		if {!$bit_number} {
			set byte_received 0
		}
		set byte_received [expr {$byte_received | ($signal(DQ) << $bit_number)}]
		incr bit_number

		if {$receive_command_or_data && $bit_number == 8} {
			set bit_number 0
			set command_received $byte_received

			switch -- $command_received {
				{170} {	;# Read Temperature [AAh]
					write_to_log I [mc "Received command: Read Temperature \[AAh\] -- sending 9 data bits"]
					set delay_transmission 1
					set reception_or_transmission 0
					set number_of_bits 9
					set data_to_send $ds1620_reg(TEMP)
				}
				{1} {	;# Write TH [01h]
					write_to_log I [mc "Received command: Write TH \[01h\] -- expecting 9 data bits"]
					set receive_command_or_data 0
					set number_of_bits 9
				}
				{2} {	;# Write TL [02h]
					write_to_log I [mc "Received command: Write TL \[02h\] -- expecting 9 data bits"]
					set receive_command_or_data 0
					set number_of_bits 9
				}
				{161} {	;# Read TH [A1h]
					write_to_log I [mc "Received command: Read TH \[A1h\] -- sending 9 data bits"]
					set delay_transmission 1
					set reception_or_transmission 0
					set number_of_bits 9
					set data_to_send $ds1620_reg(TH)
				}
				{162} {	;# Read TL [A2h]
					write_to_log I [mc "Received command: Read TL \[A2h\] -- sending 9 data bits"]
					set delay_transmission 1
					set reception_or_transmission 0
					set number_of_bits 9
					set data_to_send $ds1620_reg(TL)
				}
				{160} {	;# Read Counter [A0h]
					write_to_log I [mc "Received command: Read Counter \[A0h\] -- sending 9 data bits"]
					set delay_transmission 1
					set reception_or_transmission 0
					set number_of_bits 9
					set data_to_send $ds1620_reg(REMAIN)
				}
				{169} {	;# Read Slope [A9h]
					write_to_log I [mc "Received command: Read Slope \[A9h\] -- sending 9 data bits"]
					set delay_transmission 1
					set reception_or_transmission 0
					set number_of_bits 9
					set data_to_send $ds1620_reg(PER_C)
				}
				{238} {	;# Start Convert T [EEh]
					if {$ds1620_reg(STATUS) & 0x01} {
						if {$conversion_running} {
							write_to_log I [mc "Received command: Start Convert T \[EEh\] -- Starting T conversion on demand"]
						} else {
							write_to_log I [mc "Received command: Start Convert T \[EEh\] -- Restarting T conversion on demand"]
						}
					} else {
						if {$conversion_running} {
							write_to_log I [mc "Received command: Start Convert T \[EEh\] -- Starting continuous T conversion"]
						} else {
							write_to_log I [mc "Received command: Start Convert T \[EEh\] -- Restarting continuous T conversion"]
						}
					}

					restart_t_conversion

					set conversion_running 1
					set communication_disabled 1
					set pending_communication 0
				}
				{34} {	;# Stop Convert T [22h]
					if {$conversion_running} {
						if {$ds1620_reg(STATUS) & 0x01} {
							write_to_log I [mc "Received command: Stop Convert T \[22h\] -- Stopping T conversion which is currently in progress"]
						} else {
							write_to_log I [mc "Received command: Stop Convert T \[22h\] -- Stopping continuous T conversion"]
						}
						restart_t_conversion
					} else {
						write_to_log W [mc "Received command: Stop Convert T \[22h\] -- No T conversion in progress -- command has no effect"]
					}
					set conversion_running 0
					set communication_disabled 1
					set pending_communication 0
				}
				{12} {	;# Write Config [0Ch]
					write_to_log I [mc "Received command: Write Config \[0Ch\] -- expecting 8 data bits"]
					set receive_command_or_data 0
					set number_of_bits 8
				}
				{172} {	;# Read Config [ACh]
					write_to_log I [mc "Received command: Read Config \[ACh\] -- sending 8 data bits"]
					set delay_transmission 1
					set reception_or_transmission 0
					set number_of_bits 8
					set data_to_send $ds1620_reg(STATUS)

				}
				default {
					write_to_log E [mc "Received unknown command: %02Xh" $command_received]
				}
			}

		} elseif {!$receive_command_or_data && $bit_number == $number_of_bits} {
			set communication_disabled 1
			set pending_communication 0

			write_to_log I [mc "Received data: %03Xh -- finishing command" $byte_received]

			switch -- $command_received {
				{1} {	;# Write TH [01h]
					if {$ds1620_reg(STATUS) & 0x10} {
						write_to_log E [mc "Nonvolatile memory is still busy -- command ignored"]
					} else {
						set write_to_NVM [expr {[$project get_run_statistics 0] + $EEPROM_WRITE_CYCLE_TIME * 1000}]
						set ds1620_reg(TH) $byte_received
						update_reg TH

						write_to_log I [mc "Commencing write to nonvolatile memory: TH := %02Xh" $byte_received]
					}
				}
				{2} {	;# Write TL [02h]
					if {$ds1620_reg(STATUS) & 0x10} {
						write_to_log E [mc "Nonvolatile memory is still busy -- command ignored"]
					} else {
						set write_to_NVM [expr {[$project get_run_statistics 0] + $EEPROM_WRITE_CYCLE_TIME * 1000}]
						set ds1620_reg(TL) $byte_received
						update_reg TL

						write_to_log I [mc "Commencing write to nonvolatile memory: TL := %02Xh" $byte_received]
					}
				}
				{12} {	;# Write Config [0Ch]
					if {$ds1620_reg(STATUS) & 0x10} {
						write_to_log E [mc "Nonvolatile memory is still busy -- command ignored"]
					} else {
						set write_to_NVM [expr {[$project get_run_statistics 0] + $EEPROM_WRITE_CYCLE_TIME * 1000}]
						set ds1620_reg(STATUS) [expr {($ds1620_reg(STATUS) & 0x9C) | ($byte_received & 0x63) | 0x10}]
						update_reg STATUS

						write_to_log I [mc "Commencing write to nonvolatile memory: STATUS/CONFIG := %02Xh" $byte_received]
					}
				}
			}
		}
	}

	private method check_proper_timing {event} {
		set time_of($event) $time_mark
		if {$no_delays} {
			return
		}

		switch -- $event {
			{DQ_up} {
				# Check for valid t_CDH (CLK to Data Hold) >= 40
				if {($time_mark < ($time_of(CLK_up) + 40)) || ($time_mark < ($time_of(CLK_down) + 40))} {
					write_to_log E [mc "Bad timing: t_CDH (CLK to Data Hold) too low, must be at least 40ns"]
				}
			}
			{DQ_down} {
				# Check for valid t_CDH (CLK to Data Hold) >= 40
				if {($time_mark < ($time_of(CLK_up) + 40)) || ($time_mark < ($time_of(CLK_down) + 40))} {
					write_to_log E [mc "Bad timing: t_CDH (CLK to Data Hold) too low, must be at least 40ns"]
				}
			}
			{RST_up} {
				# Check for valid t_CWH (RST Inactive Time) >= 125
				if {$command_received == 0x01 || $command_received == 0x02 || $command_received == 0x0C} {
					set min_time [expr {$EEPROM_WRITE_CYCLE_TIME * 1000}]
				} else {
					set min_time 125
				}
				if {$time_mark < ($time_of(RST_down) + $min_time)} {
					write_to_log E [mc "Bad timing: t_CWH (RST Inactive Time) too low, must be at least %dns" ${min_time}]
				}
			}
			{RST_down} {
				if {$signal(RST)} {
					# Check for valid t_CCH (CLK to RST Hold) >= 40
					if {$time_mark < ($time_of(CLK_up) + 40)} {
						write_to_log E [mc "Bad timing: t_CCH (CLK to RST Hold too low, must be at least 40ns"]
					}
				}
			}
			{CLK_up} {
				if {$signal(RST)} {
					# Check for valid t_DC (Data to CLK Setup) >= 35
					if {($time_mark < ($time_of(DQ_up) + 35)) || $time_mark < ($time_of(DQ_down) + 35)} {
						write_to_log E [mc "Bad timing: t_DC (Data to CLK Setup) too low, must be at least 35ns"]
					}
					# Check for valid t_CL (CLK Low Time) >= 285ns
					if {$time_mark < ($time_of(CLK_down) + 285)} {
						write_to_log E [mc "Bad timing: t_CL (CLK Low Time) too low, must be at least 285ns"]
					}
				} else {
					# Check for valid t_CNV (Convert Pulse Width) >= 250ns & <= 500ms
					if {($time_mark < ($time_of(CLK_down) + 250)) || ($time_mark > ($time_of(CLK_down) + 500000000))} {
						write_to_log E [mc "Bad timing: t_CNV (Convert Pulse Width) too low or too high, must be at least 250ns and at most 500ms"]
					}

				}
			}
			{CLK_down} {
				# Check for valid t_CC (RST To CLK Setup) >= 100ns
				if {$time_mark < ($time_of(RST_up) + 100)} {
					write_to_log E [mc "Bad timing: t_CC (RST To CLK Setup) too low, must be at least 100ns"]
				}
				# Check for valid t_CH (CLK High Time) >= 285ns
				if {$time_mark < ($time_of(CLK_up) + 285)} {
					write_to_log E [mc "Bad timing: t_CH (CLK High Time) too low, must be at least 285ns"]
				}
			}
		}
	}

	private method ds1620_core__evaluate {} {
		# Continuous conversion mode or One-shot conversion mode
		if {$conversion_running} {
			proceed_with_t_conversion
		# Stand-alone mode
		} elseif {!($ds1620_reg(STATUS) & 0x02) && !$signal(RST) && !$signal(CLK)} {
			proceed_with_t_conversion
		}

		if {$ds1620_reg(STATUS) & 0x10} {
			if {$no_delays || $write_to_NVM <= $time_mark} {
				write_to_log I [mc "Write to nonvolatile memory is complete"]
				set ds1620_reg(STATUS) [expr {$ds1620_reg(STATUS) ^ 0x10}]
			}
		}

		# RESET signal is high -- Communicate with MCU
		if {$signal(RST)} {
			# Detect raising edge on the DQ signal
			#       ____
			#      /
			# ____/
			if {!$signal(DQ_prev) && $signal(DQ)} {
				check_proper_timing DQ_up
			# Detect falling edge on the DQ signal
			# ____
			#     \
			#     \____
			} elseif {$signal(DQ_prev) && !$signal(DQ)} {
				check_proper_timing DQ_down
			}

			# Detect raising edge on the RST signal
			#       ____
			#      /
			# ____/
			if {!$signal(RST_prev)} {
				check_proper_timing RST_up
				set pending_communication 1
				write_to_log I [mc "RESET signal was driven high -- commencing communication over 3-wire protocol"]
			}

			# Detect falling edge on the CLOCK signal - output bit to DQ
			# ____
			#     \
			#     \____
			if {$signal(CLK_prev) && !$signal(CLK) && !$reception_or_transmission} {
				check_proper_timing CLK_down
				if {$communication_disabled} {
					write_to_log W [mc "Transmission is no longer relevant"]
				} else {
					if {[transmit_data]} {
						write_to_log I [mc "Transmitting bit #%d = %d" [expr {$bit_number - 1}] $signal(DQ)]
					}
				}

			# Detect raising edge on the CLOCK signal - read bit from DQ
			#       ____
			#      /
			# ____/
			} elseif {!$signal(CLK_prev) && $signal(CLK) && $reception_or_transmission} {
				check_proper_timing CLK_up
				if {$communication_disabled} {
					write_to_log W [mc "Reception is no longer relevant"]
				} else {
					write_to_log I [mc "Receiving bit #%d = %d" $bit_number $signal(DQ)]
					receive_data
				}
			}

		# RESET signal is low -- Terminate all communications and commence stand-alone operation
		} else {
			# Detect falling edge on the RST signal
			# ____
			#     \
			#     \____
			if {$signal(RST_prev)} {
				check_proper_timing RST_down
				write_to_log I [mc "Received RESET signal -- commencing stand-alone operation"]
			}

			# Detect raising edge on the CLOCK signal
			#       ____
			#      /
			# ____/
			if {!$signal(CLK_prev) && $signal(CLK)} {
				check_proper_timing CLK_up
			# Detect falling edge on the CLOCK signal - output bit to DQ
			# ____
			#     \
			#     \____
			} elseif {$signal(CLK_prev) && !$signal(CLK)} {
				check_proper_timing CLK_down
			}

			if {$pending_communication} {
				set pending_communication 0
				write_to_log W [mc "Data communication over 3-wire protocol was terminated by RESET signal!"]
			}

			set bit_number 0
			set reception_or_transmission 1
			set receive_command_or_data 1
			set communication_disabled 0
		}
	}

	public method reset_ds1620 {} {
		set ds1620_reg(TEMP)	392
		set ds1620_reg(REMAIN)	0
		set ds1620_reg(STATUS)	[expr {($ds1620_reg(STATUS) & 0x03) | 0x88}]

		foreach reg {TH TL TEMP STATUS} {
			update_reg $reg
		}
	}

	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE
	# ------------------------------------------------------------------

	## Simulated MCU has been changed
	 # @return void
	public method mcu_changed {} {
		# Refresh lists of possible values in port selection ComboBoxes
		set available_ports [concat - [$project pale_get_available_ports]]

		for {set i 0} {$i < 6} {incr i} {
			$canvas_widget.cb_p$i configure -values $available_ports

			if {[lsearch -ascii -exact $available_ports $connection_port($i)] == -1} {
				$canvas_widget.cb_p$i current 0
				set connection_port($i) {-}
			}
		}
	}

	## Accept new state of ports
	 # @parm List state - Port states ( 5 x {8 x bit} -- {bit0 bit1 bit2 ... bit7} )
	 # @return void
	 #
	 # Possible bit values:
	 #	'|' - High frequency
	 #	'X' - Access to external memory
	 #	'?' - No volatge
	 #	'-' - Indeterminable value (some noise)
	 #	'=' - High forced to low
	 #	'0' - Logical 0
	 #	'1' - Logical 1
	public method new_state {_state} {
		upvar $_state state

		read_inputs state

		if {!$time_mark} {
			set signal(CLK_prev) $signal(CLK)
			set signal(RST_prev) $signal(RST)
			if {$signal(DQ) != {}} {
				set signal(DQ_prev) $signal(DQ)
			}
		}

		if {$time_mark != [$project get_run_statistics 0]} {
			set time_mark [$project get_run_statistics 0]
			if {$input_error} {
				write_to_log E $input_error_desc

				set input_error 0
				set input_error_desc {}
			}

			ds1620_core__evaluate
			process_outputs state

			set signal(CLK_prev) $signal(CLK)
			set signal(RST_prev) $signal(RST)
			if {$signal(DQ) != {}} {
				set signal(DQ_prev) $signal(DQ)
			}
		}

		# Reset last I/O error
		set input_error 0
		set input_error_desc {}

		adjust_wire_colors state
	}

	private method process_outputs {_state} {
		upvar $_state state

		set lines_to_update [list 3 4 5]
		if {!$signal(CLK) && $signal(RST)} {
			lappend lines_to_update 0
		}
		foreach i $lines_to_update {
			# Determinate index in the list of port states
			set pp [which_port_pin $i]

			# Not connected
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
				continue
			}

			lset state $pp $signal([lindex $SIGNAL_NAMES $i])
		}
	}

	private method read_inputs {_state} {
		upvar $_state state

		foreach i {2 1 0} {
			# Determinate index in the list of port states
			set pp [which_port_pin $i]

			# Not connected
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
				set signal_value {}
			} else {
				set signal_value [lindex $state $pp]
			}

			# Convert any possible I/O signal value to Boolean value
			switch -- $signal_value {
				{0} -
				{1} {}
				{=} {
					set signal_value 0
				}
				default {
					if {($i == 2) || ($i == 1) || ($i == 0 && $signal(RST))} {
						set input_error 1
						set input_error_desc [mc \
							"Received an invalid input on signal %s" \
							[lindex $SIGNAL_NAMES $i]
						]
						set signal_value [expr {rand() > 0.5 ? 1 : 0}]
					}
				}
			}
			set signal([lindex $SIGNAL_NAMES $i]) $signal_value
		}
	}

	private method adjust_wire_colors {_state} {
		upvar $_state state

		for {set i 0} {$i < 6} {incr i} {
			# Determinate index in the list of port states
			set pp [which_port_pin $i]

			# Not connected
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
				$canvas_widget itemconfigure $wires($i) -fill {#000000}
				continue
			}

			# Determinate wire and LED color
			switch -- [lindex $state $pp] {
				{0} {	;# Logical 0
					set wire_color		{#00FF00}
				}
				{1} {	;# Logical 1
					set wire_color		{#FF0000}
				}
				{=} {	;# High forced to low
					set wire_color		{#FF00AA}
				}
				{} {	;# Not connected
					set wire_color		{#000000}
				}
				{?} {	;# No volatge
					set wire_color		{#888888}
				}
				default {
					set wire_color		{#FF8800}
				}
			}

			$canvas_widget itemconfigure $wires($i) -fill $wire_color
		}
	}

	## Withdraw panel window from the screen
	 # @return void
	public method withdraw_window {} {
		wm withdraw $win
	}

	## Get panel configuration list (usable with method "set_config")
	 # @return List - configuration list
	public method get_config {} {
		return [list		\
			$class_name	\
			[list		\
				[array get connection_port]	\
				[array get connection_pin]	\
				[wm geometry $win]		\
				[$canvas_widget.usr_note get]	\
				$ds1620_reg(TH)			\
				$ds1620_reg(TL)			\
				$no_delays			\
				[wm geometry $win.log_window]	\
				[wm state $win.log_window]	\
				$temperature			\
				[expr {$ds1620_reg(STATUS) & 0x03}] \
				$log_enabled			\
				$keep_win_on_top		\
			]	\
		]
	}

	## Set panel configuration from list gained from method "get_config"
	 # @parm List state - Configuration list
	 # @return void
	public method set_config {state} {
		if {[catch {
			# Load connections to the MCU
			array set connection_port [lindex $state 0]
			array set connection_pin [lindex $state 1]

			# Restore window geometry
			if {[string length [lindex $state 2]]} {
				wm geometry $win [regsub {^\=?\d+x\d+} [lindex $state 2] [join [wm minsize $win] {x}]]
			}

			# Load user note
			$canvas_widget.usr_note delete 0
			$canvas_widget.usr_note insert 0 [lindex $state 3]

			set ds1620_reg(TH) [lindex $state 4]
			set ds1620_reg(TL) [lindex $state 5]

			set no_delays [lindex $state 6]

			# Display the log window
			set log_window_geometry [lindex $state 7]
			if {[lindex $state 8] == {normal}} {
				show_log
			}

			set temperature [lindex $state 9]
			set ds1620_reg(STATUS) [expr {($ds1620_reg(STATUS) & 0xFC) | ([lindex $state 10] & 0x03)}]

			set log_enabled [lindex $state 11]
			if {$log_enabled} {
				$log_on_off_chbut select
			} else {
				$log_on_off_chbut deselect
			}

			if {[lindex $state 12] != {}} {
				set keep_win_on_top [lindex $state 12]
				if {$keep_win_on_top} {
					wm attributes $win -topmost 1 -alpha 0.8
				}
			}

			# Restore state of ComboBoxes
			for {set i 0} {$i < 6} {incr i} {
				## PIN
				set pin $connection_pin($i)
				if {$pin != {-}} {
					set pin	[expr {7 - $pin}]
				}
				set idx [lsearch -ascii -exact			\
					[$canvas_widget.cb_b$i cget -values]	\
					$pin					\
				]
				if {$idx == -1} {
					set idx 0
				}
				$canvas_widget.cb_b$i current $idx

				## PORT
				set idx [lsearch -ascii -exact			\
					[$canvas_widget.cb_p$i cget -values]	\
					$connection_port($i)			\
				]
				if {$idx == -1} {
					set idx 0
				}
				$canvas_widget.cb_p$i current $idx
			}

			# Adjust internal logic and the rest of PALE
			foreach reg {TH TL TEMP STATUS} {
				update_reg $reg
			}
			adjust_temp_ind
			evaluete_enaged_pins
			$project pale_reevaluate_IO
			update

		# Fail
		}]} then {
			puts "Unable to load configuration for $class_name"
			return 0

		# Success
		} else {
			clear_modified
			return 1
		}
	}

	## Simulated MCU has been reseted
	 # @return void
	public method reset {} {
		set state [$project pale_get_true_state]
		new_state state
	}


	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
	# ------------------------------------------------------------------

	## This method is called before configuration menu invocation
	 # @return void
	public method config_menu_special {} {
		set ::${class_name}::_no_delays $no_delays
		set ::${class_name}::menu_keep_win_on_top $keep_win_on_top
	}

	## This method is called after configuration menu has beed created
	 # @return void
	public method create_config_menu_special {} {
	}

	## This method is called to fill in the help dialog
	 # @parm Widget text_widget - Target text widget
	 # @return void
	 #
	 # Note: There is defined text tag "tag_bold" in the text widget
	public method show_help_special {text_widget} {
	}

	## This method is called before panel window closure
	 # @return void
	public method close_window_special {} {
	}

	## Commit new on/off state
	 # @return void
	public method on_off_special {} {
		if {[$project pale_is_enabled]} {
			reset_ds1620
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

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
if { ! [ info exists _MULTIPLEXEDLEDDISPLAY_TCL ] } {
set _MULTIPLEXEDLEDDISPLAY_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements PALE VHW component "Multiplexed LED display"
#
# Consists of:
#	INTERNAL APPLICATION LOGIC
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM PALE ENGINE
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
# --------------------------------------------------------------------------

class MultiplexedLedDisplay {
	inherit VirtualHWComponent

	# Font: Font to be used in the panel -- bold
	public common cb_font		[font create			\
		-weight bold					\
		-size [expr {int(-10 * $::font_size_factor)}]	\
		-family {helvetica}				\
	]
	public common COMPONENT_NAME	"Multiplexed LED Display"	;# Name of this component
	public common CLASS_NAME	"MultiplexedLedDisplay"		;# Name of this class
	public common COMPONENT_ICON	{mleddisplay}			;# Icon for this panel (16x16)

	## Colors for display segments
	 # There are 6 lists (red orange yellow green blue purple)
	 # and each of them contain 3 colors (semi-dim bright dim)
	public common COLORS {
		{#AA5555 #FF0000 #FF5555}
		{#AAAA55 #FF8800 #FFCC55}
		{#AAAA55 #FFFF00 #FFFF55}

		{#55AA55 #00FF00 #55FF55}
		{#5555AA #0000FF #5555FF}
		{#AA55AA #8800FF #CC55FF}
	}
	public common DIMMED_COLOR	{#BBBBBB}

	# Configuration menu
	public common CONFMENU {
		{cascade	{Common electrode}	7	"diode"		.ca	false 1 {
			{radiobutton	"Common anode"	{}
				::MultiplexedLedDisplay::cfg_common_anode	1
				"common_electrode_changed"	7	""}
			{radiobutton	"Common cathode"	{}
				::MultiplexedLedDisplay::cfg_common_anode	0
				"common_electrode_changed"	7	""}
		}}
		{cascade	{Fade out interval}	5	"player_time"	.dim	false 1 {
			{radiobutton	"0"		{}
				::MultiplexedLedDisplay::dim_interval	0
				"dim_interval_changed"	-1
				"Set LED dim interval to 0 instruction cycles"}
			{radiobutton	"5"		{}
				::MultiplexedLedDisplay::dim_interval	5
				"dim_interval_changed"	-1
				"Set LED dim interval to 5 instruction cycles"}
			{radiobutton	"10"		{}
				::MultiplexedLedDisplay::dim_interval	10
				"dim_interval_changed"	-1
				"Set LED dim interval to 10 instruction cycles"}
			{radiobutton	"20"		{}
				::MultiplexedLedDisplay::dim_interval	20
				"dim_interval_changed"	-1
				"Set LED dim interval to 20 instruction cycles"}
			{radiobutton	"50"		{}
				::MultiplexedLedDisplay::dim_interval	50
				"dim_interval_changed"	-1
				"Set LED dim interval to 50 instruction cycles"}
			{radiobutton	"100"		{}
				::MultiplexedLedDisplay::dim_interval	100
				"dim_interval_changed"	-1
				"Set LED dim interval to 100 instruction cycles"}
			{radiobutton	"200"		{}
				::MultiplexedLedDisplay::dim_interval	200
				"dim_interval_changed"	-1
				"Set LED dim interval to 200 instruction cycles"}
			{radiobutton	"500"		{}
				::MultiplexedLedDisplay::dim_interval	500
				"dim_interval_changed"	-1
				"Set LED dim interval to 500 instruction cycles"}
			{radiobutton	"1000"		{}
				::MultiplexedLedDisplay::dim_interval	1000
				"dim_interval_changed"	-1
				"Set LED dim interval to 1000 instruction cycles"}
		}}
		{cascade	{Color}			0	"colorize"	.color	false 1 {
			{radiobutton	"Red"		{}
				::MultiplexedLedDisplay::color		{red}
				"color_changed"	0	""}
			{radiobutton	"Orange"	{}
				::MultiplexedLedDisplay::color		{orange}
				"color_changed"	0	""}
			{radiobutton	"Yellow"	{}
				::MultiplexedLedDisplay::color		{yellow}
				"color_changed"	0	""}
			{radiobutton	"Green"		{}
				::MultiplexedLedDisplay::color		{green}
				"color_changed"	0	""}
			{radiobutton	"Blue"		{}
				::MultiplexedLedDisplay::color		{blue}
				"color_changed"	0	""}
			{radiobutton	"Purple"	{}
				::MultiplexedLedDisplay::color		{purple}
				"color_changed"	0	""}
		}}
		{separator}
		{command	{All fade out}		{}	0	"dim_all"	{ledgray}
			"Dim all LEDs"}
		{command	{Show help}		{}	5	"show_help"	{help}
			"Show brief help"}
		{separator}
		{command	{Save configuration}	{}	0	"save_as"	{filesave}
			"Save configuration into a file"}
		{command	{Load configuration}	{}	0	"load_from"	{fileopen}
			"Load configuration from a file"}
		{separator}
		{checkbutton	"Window always on top"	{}	{::MultiplexedLedDisplay::menu_keep_win_on_top}
			1 0 0	{keep_win_on_top_changed}
			""}
	}

	private variable conf_dim_interval 50	;# Int: Interval to dim LED's in instruction cycles
	private variable conf_led_color	{red}	;# Color: Selected color for display segments
	private variable keep_win_on_top 0	;# Bool: Toplevel window

	private variable leds			;# Array of CanvasObject (polygon): leds(display_num,segment_num) --> LED polygon
	## Array of CanvasObject (line):
	 # wires(n)  --> wire connected to LED's	[n e {0..7}]
	 # wires(Tn) --> wire connected transistor	[n e {0..3}]
	private variable wires
	private variable connection_port	;# Array of Int: Index is key number, value is port number or {-}
	private variable connection_pin		;# Array of Int: Index is key number, value is bit number or {-}
	private variable prev_state		;# List: Previous port states
	private variable common_anode	1	;# Bool: 1 == common anode; 0 == common cathode

	private variable t_state		;# List: Transistor states


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
		array set connection_port {
			0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 -
			T0 - T1 - T2 - T3 -
		}
		array set connection_pin {
			0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 -
			T0 - T1 - T2 - T3 -
		}
		for {set j 0} {$j < 4} {incr j} {
			for {set i 0} {$i < 8} {incr i} {
				set prev_state($j,$i) 0
			}
		}

		# Inform PALE
		$project pale_register_output_device $this
		$project pale_set_modified

		# Create panel GUI
		create_gui
		mcu_changed
		on_off [$project pale_is_enabled]

		# ComboBoxes to default state
		for {set i 0} {$i < 8} {incr i} {
			$canvas_widget.cb_b$i current 0
			$canvas_widget.cb_p$i current 0
		}
		for {set i 0} {$i < 4} {incr i} {
			$canvas_widget.cb_t_p$i current 0
			$canvas_widget.cb_t_b$i current 0
		}
	}

	## Object destructor
	destructor {
		# Inform PALE
		$project pale_unregister_output_device $this

		# Destroy GUI
		destroy $win
	}

	## Create GUI of this panel
	 # @return void
	private method create_gui {} {
		# Create panel window and canvas widget
		set win [toplevel .multiplexedleddisplay$count -class {Mult. LED Display} -bg ${::COMMON_BG_COLOR}]
		set canvas_widget [canvas $win.canvas	\
			-bg white -width 0 -height 0	\
			-highlightthickness 0		\
		]

		# Draw display and wires
		set x 90
		set y 15
		draw_connections $x $y
		for {set i 0} {$i < 4} {incr i} {
			draw_8_segment $x $y [expr {3 - $i}]
			draw_wires $x $y [lindex {0 1 1 0} $i]

			incr x 80
		}

		# Create ComboBoxes
		set tx_p_y 150
		set cb_p_y 168
		set cb_b_y 188
		set x 110
		for {set i 0} {$i < 8} {incr i} {
			$canvas_widget create window $x $cb_p_y -anchor center	\
				-window [ttk::combobox $canvas_widget.cb_p$i	\
					-width 1				\
					-font $cb_font				\
					-state readonly				\
				]
			bind $canvas_widget.cb_p$i <<ComboboxSelected>> "$this reconnect S $i"

			$canvas_widget create window $x $cb_b_y -anchor center	\
				-window [ttk::combobox $canvas_widget.cb_b$i	\
					-width 1				\
					-font $cb_font				\
					-values {- 0 1 2 3 4 5 6 7}		\
					-state readonly				\
				]
			bind $canvas_widget.cb_b$i <<ComboboxSelected>> "$this reconnect S $i"

			bindtags $canvas_widget.cb_p$i	\
				[list $canvas_widget.cb_p$i TCombobox all .]
			bindtags $canvas_widget.cb_b$i	\
				[list $canvas_widget.cb_b$i TCombobox all .]

			lappend wires($i) [$canvas_widget create text	\
				[expr {$x - 3}] $tx_p_y			\
				-text [lindex {A B C D E F G P} $i]	\
				-font $cb_font -fill #000000 -anchor e	\
			]

			lappend wires($i) [$canvas_widget create line	\
				$x $cb_p_y $x [expr {100 + $y + 4*$i}]	\
				-width 1 -fill #000000	\
			]

			if {[lindex {0 0 1 1 1 1 0 1} $i]} {
				lappend wires($i) [$canvas_widget create oval		\
					[expr {$x - 2}] [expr {100 + $y + 4*$i - 2}]	\
					[expr {$x + 2}] [expr {100 + $y + 4*$i + 2}]		\
					-width 0 -fill #000000				\
				]
			}

			incr x 40
		}

		# Draw junctions
		set x 90
		set y 15
		foreach coords {
			{244 122	248 126}
			{76 98		80 102}
			{72 102		76 106}
		} index {
			6
			0
			1
		} {
			set coordinates [list]
			set len [llength $coords]

			for {set m 0; set n 1} {$n < $len} {incr m 2; incr n 2} {
				lappend coordinates	\
					[expr {[lindex $coords $m] + $x}]
				lappend coordinates	\
					[expr {[lindex $coords $n] + $y}]
			}

			lappend wires($index) [$canvas_widget create oval	\
				$coordinates -width 0 -fill #000000		\
			]
		}

		# Draw transistors and their ComboBoxes
		set cb_x 30
		set cb_y 55
		set tr_x 55
		set tr_y 45

		set txA_x 50
		set txA_y 33
		set txB_x 105
		set txB_y 30
		for {set i 0} {$i < 4} {incr i} {
			draw_transistor $tr_x $tr_y $i

			$canvas_widget create window $cb_x $cb_y -anchor e	\
				-window [ttk::combobox $canvas_widget.cb_t_p$i	\
					-width 1				\
					-font $cb_font				\
					-state readonly				\
				]
			bind $canvas_widget.cb_t_p$i <<ComboboxSelected>> "$this reconnect T $i"

			$canvas_widget create window $cb_x $cb_y -anchor w	\
				-window [ttk::combobox $canvas_widget.cb_t_b$i	\
					-width 1				\
					-font $cb_font				\
					-values {- 0 1 2 3 4 5 6 7}		\
					-state readonly				\
				]
			bind $canvas_widget.cb_t_b$i <<ComboboxSelected>> "$this reconnect T $i"

			bindtags $canvas_widget.cb_t_p$i	\
				[list $canvas_widget.cb_t_p$i TCombobox all .]
			bindtags $canvas_widget.cb_t_b$i	\
				[list $canvas_widget.cb_t_b$i TCombobox all .]

			set x_foo [expr {$tr_x + 18 + 4 + 4*$i}]
			set x_bar [expr {135 + (3 - $i)*80}]
			set wires(T$i) [$canvas_widget create line	\
				[expr {$tr_x + 18}] $tr_y	\
				$x_foo $tr_y	\
				$x_foo [expr {2 + $i*4}]	\
				$x_bar [expr {2 + $i*4}]	\
				$x_bar 19	\
				-width 1 -fill #000000	\
			]
			lappend wires(T$i) [$canvas_widget create line	\
				[expr {$x_bar - 38}] 30	\
				[expr {$x_bar - 38}] 19	\
				[expr {$x_bar + 38}] 19	\
				[expr {$x_bar + 38}] 30	\
				-width 2 -fill #000000	\
			]

			$canvas_widget create text $txA_x $txA_y	\
				-text $i -font $cb_font
			$canvas_widget create text $txB_x $txB_y	\
				-text [expr {3 - $i}] -font $cb_font

			incr tr_y 40
			incr cb_y 40
			incr txA_y 40
			incr txB_x 80
		}

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
		$canvas_widget create window 22 2 -window $start_stop_button -anchor nw
		bindtags $start_stop_button [list $start_stop_button TButton all .]

		# Create configuration menu button
		set conf_button [ttk::button $canvas_widget.conf_but	\
			-image ::ICONS::16::configure			\
			-style FlatWhite.TButton			\
			-command "$this config_menu"			\
		]
		setStatusTip -widget $conf_button -text [mc "Configure"]
		$canvas_widget create window 20 2 -window $conf_button -anchor ne
		bindtags $conf_button [list $conf_button TButton all .]

		# Create EntryBox for user note
		$canvas_widget create text 40 210	\
			-text [mc "Note"]		\
			-font $cb_font			\
			-anchor e
		$canvas_widget create window 45 210		\
			-window [ttk::entry $canvas_widget.usr_note	\
				-validate key				\
				-validatecommand "$this set_modified"	\
			]	\
			-width 380 -anchor w
		bindtags $canvas_widget.usr_note	\
			[list $canvas_widget.usr_note TEntry $win all .]

		# Pack canvas
		pack $canvas_widget -fill both -expand 1

		# Set window parameters
		wm minsize $win 430 225
		wm iconphoto $win ::ICONS::16::$component_icon
		wm title $win "[mc $component_name] - [$project cget -projectName] - MCU 8051 IDE"
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW "$this close_window"
		bindtags $win [list $win Toplevel all .]
	}

	## Value of configuration menu variable "keep_win_on_top" has been changed
	 # @return void
	public method keep_win_on_top_changed {} {
		set keep_win_on_top $MultiplexedLedDisplay::menu_keep_win_on_top
		if {$keep_win_on_top} {
			wm attributes $win -topmost 1 -alpha 0.8
		} else {
			wm attributes $win -topmost 0 -alpha 1.0
		}
	}

	## LED dim interval changed (meaningfull for multiplexed mode)
	 # @return void
	public method dim_interval_changed {} {
		set conf_dim_interval ${::MultiplexedLedDisplay::dim_interval}
		set_modified
	}

	## LED's common electrode changed
	 # @return void
	public method common_electrode_changed {} {
		set common_anode ${::MultiplexedLedDisplay::cfg_common_anode}

		if {$drawing_on} {
			dim_all
			set state [$project pale_get_true_state]
			new_state state 1
		}
		set_modified
	}

	## LED color changed
	 # @return void
	public method color_changed {} {
		set conf_led_color ${::MultiplexedLedDisplay::color}

		if {$drawing_on} {
			set state [$project pale_get_true_state]
			new_state state 1
		}
		set_modified
	}

	## Dim all LED's and reset their previous states
	 # @return void
	public method dim_all {} {
		for {set i 0} {$i < 8} {incr i} {
			for {set j 0} {$j < 4} {incr j} {
				if {$prev_state($j,$i)} {
					set prev_state($j,$i) 0
					$canvas_widget itemconfigure $leds($j,$i)	\
						-fill {#555555} -outline {#FFFFFF}
				}
			}
		}
	}

	## Reconnect the specified key to another port pin
	 # @parm Char type	- Connection type ('S' => Segment; 'T' => Transistor)
	 # @parm Int i		- Connection wire (type == 'S' => {0..3}  ^  type == 'T' => {0..7})
	 # @return void
	public method reconnect {type i} {
		# Adjust connections
		if {$type == {S}} {
			set connection_port($i) [$canvas_widget.cb_p$i get]
			set connection_pin($i)	[$canvas_widget.cb_b$i get]
			if {$connection_pin($i) != {-}} {
				set connection_pin($i)	[expr {7 - $connection_pin($i)}]
			}
		} else {
			set connection_port(T$i) [$canvas_widget.cb_t_p$i get]
			set connection_pin(T$i)	[$canvas_widget.cb_t_b$i get]
			if {$connection_pin(T$i) != {-}} {
				set connection_pin(T$i)	[expr {7 - $connection_pin(T$i)}]
			}
		}

		# Change state of the device
		if {$drawing_on} {
			set state [$project pale_get_true_state]
			new_state state 1
		}

		# Set flag modified
		set_modified
	}

	## Draw PNP transistor
	 # @parm Int x		- X origin coordinate
	 # @parm Int y		- Y origin coordinate
	 # @parm Int index	- 0..3
	 # @return void
	private method draw_transistor {x y index} {
		set coords {
			0 9	8 9	8 0	8 18	8 9
			9 9	18 0	9 9	18 18	18 24
		}
# 		11 11	11 15	11 11	15 11	11 11

		# Transform coordinates -- adjust them to the given origin
		set coordinates [list]
		set len [llength $coords]
		for {set m 0; set n 1} {$n < $len} {incr m 2; incr n 2} {
			lappend coordinates	\
				[expr {[lindex $coords $m] + $x}]
			lappend coordinates	\
				[expr {[lindex $coords $n] + $y}]
		}

		# Draw transistor
		$canvas_widget create line $coordinates	\
			-tags transistor -width 1 -fill #000000

		# Draw supply pin
		$canvas_widget create oval 			\
			[expr {$x + 15}] [expr {$y + 24}]	\
			[expr {$x + 21}] [expr {$y + 30}]	\
			-tags transistor -width 1 -outline #000000
	}

	## Draw wires connecting all 4 displays
	 # @parm Int x		- X origin coordinate
	 # @parm Int y		- Y origin coordinate
	 # @return void
	private method draw_connections {x y} {
		set coords {
			{
				20 100 319 100
			} {
				60 104	315 104
			} {
				70 108	311 108
			} {
				35 112	276 112
			} {
				10 116	251 116
			} {
				2 120	243 120
			} {
				6 124	260 124
			} {
				64 128	305 128
			}
		}

		# Transform coordinates -- adjust them to the given origin
		#+ Draw wires
		for {set i 0} {$i < 8} {incr i} {
			set coordinates [list]
			set local_coords [lindex $coords $i]
			set len [llength $local_coords]

			# Adjust
			for {set m 0; set n 1} {$n < $len} {incr m 2; incr n 2} {
				lappend coordinates	\
					[expr {[lindex $local_coords $m] + $x}]
				lappend coordinates	\
					[expr {[lindex $local_coords $n] + $y}]
			}

			# Draw
			set wires($i) [$canvas_widget create line	\
				$coordinates -width 1 -fill #000000	\
			]
		}
	}

	## Draw wires from LED's
	 # @parm Int x		- X origin coordinate
	 # @parm Int y		- Y origin coordinate
	 # @parm Bool junction	- Draw juction at the end of the wire
	 # @return void
	private method draw_wires {x y junction} {
		set coords {
			{
				46 10	46 8	78 8	78 100
			} {
				70 37	74 37	74 104
			} {
				64 72	70 72	70 108
			} {
				35 95	35 112
			} {
				14 70	10 70	10 116
			} {
				19 33	2 33	2 120
			} {
				25 53	6 53	6 124
			} {
				64 96	64 128
			}
		}

		# Transform coordinates -- adjust them to the given origin
		#+ Draw wires
		for {set i 0} {$i < 8} {incr i} {
			set coordinates [list]
			set local_coords [lindex $coords $i]
			set len [llength $local_coords]

			# Adjust
			for {set m 0; set n 1} {$n < $len} {incr m 2; incr n 2} {
				lappend coordinates	\
					[expr {[lindex $local_coords $m] + $x}]
				lappend coordinates	\
					[expr {[lindex $local_coords $n] + $y}]
			}

			# Draw wire
			lappend wires($i) [$canvas_widget create line	\
				$coordinates -width 1 -fill #000000	\
			]

			# Draw junction
			if {$junction} {
				set oval [expr {[lindex $coordinates end-1] - 2}]
				lappend oval [expr {[lindex $coordinates end] - 2}]
				lappend oval [expr {[lindex $coordinates end-1] + 2}]
				lappend oval [expr {[lindex $coordinates end] + 2}]
				lappend wires($i) [$canvas_widget create oval	\
					$oval -width 0 -fill #000000	\
				]
			}
		}
	}

	## Draw one LED display
	 # @parm Int x		- X origin coordinate
	 # @parm Int y		- Y origin coordinate
	 # @parm Int index	- Display index
	 # @return void
	private method draw_8_segment {x y index} {
		set coords {
			{
				19 7	25 1	47 1	53 7	53 8
				47 14	25 14	19 8
			} {
				55 9	62 16	58 34	50 42	44 36
				49 15	55 9
			} {
				50 45	57 52	53 70	46 77	45 77
				39 71	44 51	50 45
			} {
				15 73	38 73	44 79	37 86	15 86
				9 80	9 79
			} {
				7 78	15 70	19 52	12 45	5 52
				1 72
			} {
				12 42	20 34	25 16	17 9	10 16
				6 36
			} {
				14 43	20 37	42 37	48 43	48 44
				42 50	20 50	14 44
			}
		}

		# Transform coordinates -- adjust them to the given origin
		#+ Draw LED polygons -- for segments A..G
		for {set i 0} {$i < 7} {incr i} {
			set coordinates [list]
			set local_coords [lindex $coords $i]
			set len [llength $local_coords]

			# Adjust
			for {set m 0; set n 1} {$n < $len} {incr m 2; incr n 2} {
				lappend coordinates	\
					[expr {[lindex $local_coords $m] + $x + 10}]
				lappend coordinates	\
					[expr {[lindex $local_coords $n] + $y + 10}]
			}

			# Draw
			set leds($index,$i) [$canvas_widget create polygon	\
				$coordinates -width 0 -fill #555555	\
			]
		}

		# Transform coordinates -- adjust them to the given origin
		#+ Draw LED oval -- for segment P (point)
		set leds($index,7) [$canvas_widget create oval			\
			[expr {49 + $x + 10}] [expr {77 + $y + 10}]	\
			[expr {58 + $x + 10}] [expr {86 + $y + 10}]	\
			-width 0 -fill #555555				\
		]

		# Print segment labels
		foreach coords {{35 7} {53 25} {48 62} {26 79} {10 61} {15 25} {31 43}} \
			text {A B C D E F G} \
		{
			$canvas_widget create text			\
				[expr {[lindex $coords 0] + $x + 10}]	\
				[expr {[lindex $coords 1] + $y + 10}]	\
				-text $text -fill {#FFFFFF}		\
				-font $::smallfont
		}
	}

	## Determinate which port pin is connected to the specified wire
	 # @parm Char type	- Connection type ('S' => Segment; 'T' => Transistor)
	 # @parm Int i		- Connection wire (type == 'S' => {0..3}  ^  type == 'T' => {0..7})
	 # @return void
	private method which_port_pin {type i} {
		if {$type == {S}} {
			return [list $connection_port($i) $connection_pin($i)]
		} else {
			return [list $connection_port(T$i) $connection_pin(T$i)]
		}
	}

	## Handle "ON/OFF" button press
	 # Turn whole PALE system on or off
	 # @return void
	public method on_off_button_press {} {
		$project pale_all_on_off
	}


	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE
	# ------------------------------------------------------------------

	## Simulated MCU has been changed
	 # @return void
	public method mcu_changed {} {
		# Refresh lists of possible values in port selection ComboBoxes
		set available_ports [concat - [$project pale_get_available_ports]]

		# For segments ...
		for {set i 0} {$i < 8} {incr i} {
			$canvas_widget.cb_p$i configure -values $available_ports

			if {[lsearch -ascii -exact $available_ports $connection_port($i)] == -1} {
				$canvas_widget.cb_p$i current 0
				set connection_port($i) {-}
			}
		}

		# For transistors ...
		for {set i 0} {$i < 4} {incr i} {
			$canvas_widget.cb_t_p$i configure -values $available_ports

			if {[lsearch -ascii -exact $available_ports $connection_port(T$i)] == -1} {
				$canvas_widget.cb_t_p$i current 0
				set connection_port(T$i) {-}
			}
		}
	}

	## Accept new state of ports
	 # @parm List state - Port states ( 5 x {8 x bit} -- {bit0 bit1 bit2 ... bit7} )
	 # @parm Bool preserve_prvious_state=0 - Preserve previous state of component
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
	public method new_state {_state {preserve_prvious_state 0}} {
		upvar $_state state

		# Determinate index of LED color in list COLORS
		set color_idx [lsearch -ascii -exact		\
			{red orange yellow green blue purple}	\
			$conf_led_color				\
		]

		# Determinate which displays are online and which are offline
		for {set i 0} {$i < 4} {incr i} {
			# Determinate index in the list of port states
			set pp [which_port_pin T $i]

			# Not connected
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
				set t_state($i) {}
			# Connected
			} else {
				set t_state($i) [lindex $state $pp]
			}

			# Determinate state
			switch -- $t_state($i) {
				{0} {	;# Logical 0
					if {$common_anode} {
						set t_state($i)	2
					} else {
						set t_state($i)	0
					}
					set wire_color	{#FF0000}
				}
				{1} {	;# Logical 1
					if {$common_anode} {
						set t_state($i)	0
					} else {
						set t_state($i)	2
					}
					set wire_color	{#00FF00}
				}
				{=} {	;# High forced to low
					if {$common_anode} {
						set t_state($i)	2
					} else {
						set t_state($i)	0
					}
					set wire_color	{#00FF00}
				}
				{?} {	;# No volatge
					set t_state($i)	0
					set wire_color	{#888888}
				}
				{} {	;# Not connected
					set t_state($i)	0
					set wire_color	{#000000}
				}
				default {
					set t_state($i)	1
					set wire_color	{#FF8800}
				}
			}

			# Adjust wire colors
			foreach item $wires(T$i) {
				$canvas_widget itemconfigure $item -fill $wire_color
			}
		}

		# Adjust displays
		for {set i 0} {$i < 8} {incr i} {
			# Determinate index in the list of port states
			set pp [which_port_pin S $i]

			# Not connected
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
				for {set j 0} {$j < 4} {incr j} {
					$canvas_widget itemconfigure $leds($j,$i) -fill $DIMMED_COLOR -outline {#FFFFFF}
				}
				foreach item $wires($i) {
					$canvas_widget itemconfigure $item -fill {#000000}
				}
				continue
			}

			# Determinate state
			set state_pp [lindex $state $pp]

			# Adjust wire colors
			switch -- $state_pp {
				{0} {	;# Logical 0
					set wire_color	{#00FF00}
				}
				{1} {	;# Logical 1
					set wire_color	{#FF0000}
				}
				{=} {	;# High forced to low
					set wire_color	{#FF00AA}
				}
				{} {	;# Not connected
					set wire_color	{#000000}
				}
				{?} {	;# No volatge
					set wire_color	{#888888}
				}
				default {
					set wire_color	{#FF8800}
				}
			}
			foreach item $wires($i) {
				$canvas_widget itemconfigure $item -fill $wire_color
			}

			# Adjust displays
			for {set j 0} {$j < 4} {incr j} {

				# Determinate segment color number
				switch -- $state_pp {
					{0} {	;# Logical 0
						if {$common_anode} {
							switch -- $t_state($j) {
								{2} {
									set segment_color {2}
								}
								{1} {
									set segment_color {1}
								}
								{0} {
									set segment_color {0}
								}
							}
						} else {
							set segment_color {0}
						}
					}
					{1} {	;# Logical 1
						if {$common_anode} {
							set segment_color {0}
						} else {
							switch -- $t_state($j) {
								{2} {
									set segment_color {2}
								}
								{1} {
									set segment_color {1}
								}
								{0} {
									set segment_color {0}
								}
							}
						}
					}
					{=} {	;# High forced to low
						set segment_color {0}
					}
					{} {	;# Not connected
						set segment_color {0}
					}
					{?} {	;# No volatge
						set segment_color {0}
					}
					default {
						switch -- $t_state($j) {
							{2} {
								set segment_color {1}
							}
							{1} {
								set segment_color {0}
							}
							{0} {
								set segment_color {0}
							}
						}
					}
				}

				## LED's dims with delay ...
				set outline {#FFFFFF}
				 # Dim with delay
				if {$segment_color == {0}} {
					if {$prev_state($j,$i) == {}} {
						set prev_state($j,$i) 0
					}
					if {$prev_state($j,$i)} {
						if {!$preserve_prvious_state} {
							incr prev_state($j,$i) -1
						}
						if {$prev_state($j,$i)} {
							set segment_color {3}
						}
					}
				 # Light up now
				} elseif {$segment_color == {2}} {
					if {!$preserve_prvious_state} {
						set prev_state($j,$i) $conf_dim_interval
					}
					set outline [lindex $COLORS [list $color_idx $segment_color]]
				}

				# Determinate segment color (true color, not just number)
				if {!$segment_color} {
					set segment_color $DIMMED_COLOR
				} else {
					incr segment_color -1
					set segment_color [lindex $COLORS [list $color_idx $segment_color]]
				}

				# Change segment color
				$canvas_widget itemconfigure $leds($j,$i)	\
					-fill $segment_color -outline $outline
			}
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
				$conf_led_color			\
				$conf_dim_interval		\
				$common_anode			\
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

			# Restore LED's configuration
			set conf_led_color	[lindex $state 4]
			set conf_dim_interval	[lindex $state 5]
			set common_anode	[lindex $state 6]
			if {$common_anode == {}} {
				set common_anode 1
			}

			if {[lindex $state 7] != {}} {
				set keep_win_on_top [lindex $state 7]
				if {$keep_win_on_top} {
					wm attributes $win -topmost 1 -alpha 0.8
				}
			}

			## Restore state of ComboBoxes
			 # For segments ...
			for {set i 0} {$i < 8} {incr i} {
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
			 # For transistors ...
			for {set i 0} {$i < 4} {incr i} {
				## PIN
				set pin $connection_pin(T$i)
				if {$pin != {-}} {
					set pin	[expr {7 - $pin}]
				}
				set idx [lsearch -ascii -exact			\
					[$canvas_widget.cb_t_b$i cget -values]	\
					$pin					\
				]
				if {$idx == -1} {
					set idx 0
				}
				$canvas_widget.cb_t_b$i current $idx

				## PORT
				set idx [lsearch -ascii -exact			\
					[$canvas_widget.cb_t_p$i cget -values]	\
					$connection_port(T$i)			\
				]
				if {$idx == -1} {
					set idx 0
				}
				$canvas_widget.cb_t_p$i current $idx
			}

			# Accept new state of ports
			set state [$project pale_get_true_state]
			new_state state
			update

		# Fail
		}]} then {
			puts stderr "Unable to load configuration for $class_name"
			puts stderr $::errorInfo
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
		dim_all
		set state [$project pale_get_true_state]
		new_state state
	}


	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
	# ------------------------------------------------------------------

	## This method is called before configuration menu invocation
	 # @return void
	public method config_menu_special {} {
		set ::${class_name}::dim_interval $conf_dim_interval
		set ::${class_name}::color $conf_led_color
		set ::${class_name}::cfg_common_anode $common_anode
		set ::${class_name}::menu_keep_win_on_top $keep_win_on_top
	}

	## This method is called after configuration menu has beed created
	 # @return void
	public method create_config_menu_special {} {
		foreach item {	Red	Orange	Yellow	Green	Blue	Purple	} \
			color {	#DD0000	#DD8800	#DDDD00	#00DD00	#0000DD	#8800DD	} \
		{
			$conf_menu.color entryconfigure [::mc $item] -foreground $color
		}
	}

	## This method is called to fill in the help dialog
	 # @parm Widget text_widget - Target text widget
	 # @return void
	 #
	 # Note: There is defined text tag "tag_bold" in the text widget
	public method show_help_special {text_widget} {
		$text_widget insert insert [mc "Virtual Multiplexed LED Display with common anode (default) or cathode.  Each segment can be connected to any port pin of the simulated uC.  Connections with the uC are made with ComboBoxes.  Panel configuration can be saved to a file with extension vhc, and can be loaded from that file later.  LED fade out interval and LED colors are configurable.\n\n"]

		set color_idx [lsearch -ascii -exact		\
			{red orange yellow green blue purple}	\
			$conf_led_color				\
		]

		$text_widget insert insert [mc "LED states:"]
		$text_widget tag add tag_bold {insert linestart} {insert lineend}
		$text_widget insert insert [mc "\n  "]
		$text_widget window create insert -pady 1 -create "frame $text_widget.f0 -bd 1 -width 14 -height 16 -bg $DIMMED_COLOR"
		$text_widget insert insert [mc "  Off\n  "]
		$text_widget window create insert -pady 1 -create "frame $text_widget.f1 -bd 1 -width 14 -height 16 -bg [lindex $COLORS [list $color_idx 0]]"
		$text_widget insert insert [mc "  Fast blinking\n  "]
		$text_widget window create insert -pady 1 -create "frame $text_widget.f2 -bd 1 -width 14 -height 16 -bg [lindex $COLORS [list $color_idx 1]]"
		$text_widget insert insert [mc "  Shining\n  "]
		$text_widget window create insert -pady 1 -create "frame $text_widget.f3 -bd 1 -width 14 -height 16 -bg [lindex $COLORS [list $color_idx 2]]"
		$text_widget insert insert [mc "  Fading out\n  "]
	}

	## This method is called before panel window closure
	 # @return void
	public method close_window_special {} {
	}

	## Commit new on/off state
	 # @return void
	public method on_off_special {} {
		if {!$drawing_on} {
			for {set j 0} {$j < 4} {incr j} {
				for {set i 0} {$i < 8} {incr i} {
					$canvas_widget itemconfigure $leds($j,$i) -fill {#555555}
					foreach item $wires($i) {
						$canvas_widget itemconfigure $item -fill {#000000}
					}
				}
			}
		} else {
			set state [$project pale_get_true_state]
			new_state state 1
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

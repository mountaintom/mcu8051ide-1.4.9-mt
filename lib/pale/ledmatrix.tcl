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
if { ! [ info exists _LEDMATRIX_TCL ] } {
set _LEDMATRIX_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# Implements PALE VHW component "LED matrix"
#
# Consists of:
#	INTERNAL APPLICATION LOGIC
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM PALE ENGINE
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
# --------------------------------------------------------------------------

class LedMatrix {
	inherit VirtualHWComponent

	# Font: Font to be used in the panel -- bold
	public common cb_font	[font create				\
		-weight bold					\
		-size [expr {int(-10 * $::font_size_factor)}]	\
		-family {helvetica}				\
	]
	public common COMPONENT_NAME	"LED Matrix"	;# Name of this component
	public common CLASS_NAME	"LedMatrix"	;# Name of this class
	public common COMPONENT_ICON	{ledmatrix}	;# Icon for this panel (16x16)

	# Configuration menu
	public common CONFMENU {
		{cascade	{Fade out interval}	5	"player_time"	.dim	false 1 {
			{radiobutton	"0"		{}
				::LedMatrix::dim_interval	0
				"dim_interval_changed"	-1
				"Set LED dim interval to 0 instruction cycles"}
			{radiobutton	"5"		{}
				::LedMatrix::dim_interval	5
				"dim_interval_changed"	-1
				"Set LED dim interval to 5 instruction cycles"}
			{radiobutton	"10"		{}
				::LedMatrix::dim_interval	10
				"dim_interval_changed"	-1
				"Set LED dim interval to 10 instruction cycles"}
			{radiobutton	"20"		{}
				::LedMatrix::dim_interval	20
				"dim_interval_changed"	-1
				"Set LED dim interval to 20 instruction cycles"}
			{radiobutton	"50"		{}
				::LedMatrix::dim_interval	50
				"dim_interval_changed"	-1
				"Set LED dim interval to 50 instruction cycles"}
			{radiobutton	"100"		{}
				::LedMatrix::dim_interval	100
				"dim_interval_changed"	-1
				"Set LED dim interval to 100 instruction cycles"}
			{radiobutton	"200"		{}
				::LedMatrix::dim_interval	200
				"dim_interval_changed"	-1
				"Set LED dim interval to 200 instruction cycles"}
			{radiobutton	"500"		{}
				::LedMatrix::dim_interval	500
				"dim_interval_changed"	-1
				"Set LED dim interval to 500 instruction cycles"}
			{radiobutton	"1000"		{}
				::LedMatrix::dim_interval	1000
				"dim_interval_changed"	-1
				"Set LED dim interval to 1000 instruction cycles"}
		}}
		{cascade	{Mapping}		5	"matrix2"	.mapping false 1 {
			{radiobutton	"Random"	{}
				::LedMatrix::matrix_mapping	0
				"matrix_mapping_changed"	-1
				"Random access to the matrix (default)"}
			{radiobutton	"Row"		{}
				::LedMatrix::matrix_mapping	1
				"matrix_mapping_changed"	-1
				"When a particular row is activated, it's previous state is forgotten"}
			{radiobutton	"Column"	{}
				::LedMatrix::matrix_mapping	2
				"matrix_mapping_changed"	-1
				"When a particular column is activated, it's previous state is forgotten"}
		}}
		{cascade	{Color}			0	"colorize"	.color	false 1 {
			{radiobutton	"Red"		{}
				::LedMatrix::color		{red}
				"color_changed"	0	""}
			{radiobutton	"Orange"	{}
				::LedMatrix::color		{orange}
				"color_changed"	0	""}
			{radiobutton	"Yellow"	{}
				::LedMatrix::color		{yellow}
				"color_changed"	0	""}
			{radiobutton	"Green"		{}
				::LedMatrix::color		{green}
				"color_changed"	0	""}
			{radiobutton	"Blue"		{}
				::LedMatrix::color		{blue}
				"color_changed"	0	""}
			{radiobutton	"Purple"	{}
				::LedMatrix::color		{purple}
				"color_changed"	0	""}
		}}
		{cascade	{Light up when}		0	"ledgreen"	.cond	false 1 {
			{radiobutton	"Row 0 & Column 0"	{}
				::LedMatrix::cond		{0 0}
				"cond_changed"	0
				"Light up LED when both wires are in low"}
			{radiobutton	"Row 0 & Column 1"	{}
				::LedMatrix::cond		{0 1}
				"cond_changed"	0
				"Light up LED when row wire is in low and column wire is in high"}
			{radiobutton	"Row 1 & Column 0"	{}
				::LedMatrix::cond		{1 0}
				"cond_changed"	0
				"Light up LED when row wire is in high and column wire is in low"}
			{radiobutton	"Row 1 & Column 1"	{}
				::LedMatrix::cond		{1 1}
				"cond_changed"	0
				"Light up LED when both wires are in high"}
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
		{checkbutton	"Window always on top"	{}	{::LedMatrix::menu_keep_win_on_top}
			1 0 0	{keep_win_on_top_changed}
			""}
	}

	private variable conf_dim_interval 50	;# Int: Interval to dim LED's in instruction cycles
	private variable conf_matrix_mapping 0	;# Int: Type of matrix mapping: 0 == Random; 1 == Row; 2 == Column
	private variable conf_led_color	{red}	;# Color: Selected color for LED's
	private variable keep_win_on_top 0	;# Bool: Toplevel window
	## List of Bool: LED light up condition
	 # Index 0 - Row must be in:	1 == log. 1; 0 == log. 0
	 # Index 1 - Column must be in:	1 == log. 1; 0 == log. 0
	private variable conf_led_cond	{0 0}
	private variable leds			;# Array of CanvasObject (image): LED's, leds(row,column)
	private variable col			;# Array of CanvasObject (line): Column wires
	private variable row			;# Array of CanvasObject (line): Row wires
	private variable prev_state		;# List: Previous port states
	private variable connection_port	;# Array of Int: Index is key number, value is port number or {-}
	private variable connection_pin		;# Array of Int: Index is key number, value is bit number or {-}


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
			R0 - R1 - R2 - R3 - R4 - R5 - R6 - R7 -
			C0 - C1 - C2 - C3 - C4 - C5 - C6 - C7 -
		}
		array set connection_pin {
			R0 - R1 - R2 - R3 - R4 - R5 - R6 - R7 -
			C0 - C1 - C2 - C3 - C4 - C5 - C6 - C7 -
		}
		for {set j 0} {$j < 8} {incr j} {
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
			$canvas_widget.cb_r_b$i current 0
			$canvas_widget.cb_r_p$i current 0

			$canvas_widget.cb_c_b$i current 0
			$canvas_widget.cb_c_p$i current 0
		}
	}

	## Object destructor
	destructor {
		# Inform PALE
		$project pale_unregister_output_device $this

		# Destroy GUI
		destroy $win
	}

	## Value of configuration menu variable "keep_win_on_top" has been changed
	 # @return void
	public method keep_win_on_top_changed {} {
		set keep_win_on_top $LedMatrix::menu_keep_win_on_top
		if {$keep_win_on_top} {
			wm attributes $win -topmost 1 -alpha 0.8
		} else {
			wm attributes $win -topmost 0 -alpha 1.0
		}
	}

	## Reconnect the specified wire to another port pin
	 # @parm Char col_or_row	- 'C' => Column; 'R' => Row
	 # @parm Int i			- Wire number (0..7)
	 # @return void
	public method reconnect {col_or_row i} {
		# Row
		if {$col_or_row == {R}} {
			set connection_port(R$i) [$canvas_widget.cb_r_p$i get]
			set connection_pin(R$i)	[$canvas_widget.cb_r_b$i get]
			if {$connection_pin(R$i) != {-}} {
				set connection_pin(R$i)	[expr {7 - $connection_pin(R$i)}]
			}
		# Column
		} else {
			set connection_port(C$i) [$canvas_widget.cb_c_p$i get]
			set connection_pin(C$i)	[$canvas_widget.cb_c_b$i get]
			if {$connection_pin(C$i) != {-}} {
				set connection_pin(C$i)	[expr {7 - $connection_pin(C$i)}]
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

	## LED matrix mapping type changed (meaningfull for multiplexed mode)
	 # @return void
	public method matrix_mapping_changed {} {
		set conf_matrix_mapping ${::LedMatrix::matrix_mapping}

		# Set flag modified
		set_modified
	}

	## LED dim interval changed (meaningfull for multiplexed mode)
	 # @return void
	public method dim_interval_changed {} {
		set conf_dim_interval ${::LedMatrix::dim_interval}

		# Set flag modified
		set_modified
	}

	## LED color was changed
	 # @return void
	public method color_changed {} {
		set conf_led_color ${::LedMatrix::color}


		# Change state of the device
		if {$drawing_on} {
			set state [$project pale_get_true_state]
			new_state state 1
		}

		# Set flag modified
		set_modified
	}

	## LED light up condition was changed
	 # @return void
	public method cond_changed {} {
		set conf_led_cond ${::LedMatrix::cond}

		if {$drawing_on} {
			set state [$project pale_get_true_state]
			new_state state
		}
		set_modified
	}

	## Dim all LED's and reset their previous states
	 # @return void
	public method dim_all {} {
		for {set i 0} {$i < 8} {incr i} {
			for {set j 0} {$j < 8} {incr j} {
				if {$prev_state($j,$i)} {
					set prev_state($j,$i) 0
					$canvas_widget itemconfigure $leds($j,$i)	\
						-image ::ICONS::16::ledgray
				}
			}
		}
	}

	## Create GUI of this panel
	 # @return void
	private method create_gui {} {
		# Create panel window and canvas widget
		set win [toplevel .ledmatrix$count -class $component_name -bg ${::COMMON_BG_COLOR}]
		set canvas_widget [canvas $win.canvas	\
			-bg white -width 0 -height 0	\
			-highlightthickness 0		\
		]

		# Create column wires
		set led_sep 15
		set sep 25
		set y_0 100
		set x_0 90
		set y_1 [expr {$y_0 + 10}]
		set x_1 [expr {$x_0 + 35}]

		set cb_x $x_0
		set cb_y [expr {$y_0 - 80}]

		set x $x_1
		set y $y_1
		incr y -$led_sep
		for {set i 0} {$i < 8} {incr i} {
			set fin [expr {$cb_y + 30 + abs($x - $cb_x)}]
			set col($i) [$canvas_widget create line	\
				$cb_x [expr {$cb_y + 20}]	\
				$cb_x [expr {$cb_y + 30}]	\
				$x $fin $x [expr {$y - 8}]	\
				-fill {#000000} -width 1	\
			]
			lappend col($i) [$canvas_widget create text $x $y	\
				-text $i -font $cb_font -fill {#000000}	\
			]
			incr x $led_sep
			incr cb_x $sep
		}

		# Create row wires
		set cb_x $x_0
		set cb_y $y_0
		incr cb_y -$sep
		incr cb_x -55

		set x $x_1
		set y $y_1
		incr x -$led_sep
		for {set i 0} {$i < 8} {incr i} {
			set fin [expr {$cb_x + 30 + abs($y - $cb_y)}]
			set row($i) [$canvas_widget create line		\
				$cb_x $cb_y [expr {$cb_x + 30}] $cb_y	\
				$fin $y [expr {$x - 8}] $y		\
				-fill {#000000} -width 1		\
			]
			lappend row($i) [$canvas_widget create text $x $y	\
				-font $cb_font -fill {#000000}		\
				-text [lindex {A B C D E F G H} $i]	\
			]

			incr y $led_sep
			incr cb_y $sep
		}

		# Create LED's
		set y $y_1
		set x $x_1
		for {set j 0} {$j < 8} {incr j} {
			for {set i 0} {$i < 8} {incr i} {
				set leds($j,$i) [$canvas_widget create image $x $y	\
					-image ::ICONS::16::ledgray			\
				]
				incr x $led_sep
			}
			incr y $led_sep
			set x $x_1
		}

		# Create row ComboBoxes
		set x $x_0
		set y $y_0
		incr y -$sep
		incr x -55
		for {set i 0} {$i < 8} {incr i} {
			$canvas_widget create window $x $y -anchor e	\
				-window [ttk::combobox $canvas_widget.cb_r_p$i	\
					-width 1				\
					-font $cb_font				\
					-state readonly				\
				]
			bind $canvas_widget.cb_r_p$i <<ComboboxSelected>> "$this reconnect R $i"

			$canvas_widget create window $x $y -anchor w	\
				-window [ttk::combobox $canvas_widget.cb_r_b$i	\
					-width 1				\
					-font $cb_font				\
					-values {- 0 1 2 3 4 5 6 7}		\
					-state readonly				\
				]
			bind $canvas_widget.cb_r_b$i <<ComboboxSelected>> "$this reconnect R $i"

			bindtags $canvas_widget.cb_r_p$i	\
				[list $canvas_widget.cb_r_p$i TCombobox all .]
			bindtags $canvas_widget.cb_r_b$i	\
				[list $canvas_widget.cb_r_b$i TCombobox all .]

			incr y $sep
		}

		# Create column ComboBoxes
		set x $x_0
		set cb_p_y [expr {$y_0 - 85}]
		set cb_b_y [expr {$y_0 - 65}]
		for {set i 0} {$i < 8} {incr i} {
			$canvas_widget create window $x $cb_p_y -anchor center	\
				-window [ttk::combobox $canvas_widget.cb_c_p$i	\
					-width 1				\
					-font $cb_font				\
					-state readonly				\
				]
			bind $canvas_widget.cb_c_p$i <<ComboboxSelected>> "$this reconnect C $i"

			$canvas_widget create window $x $cb_b_y -anchor center	\
				-window [ttk::combobox $canvas_widget.cb_c_b$i	\
					-width 1				\
					-font $cb_font				\
					-values {- 0 1 2 3 4 5 6 7}		\
					-state readonly				\
				]
			bind $canvas_widget.cb_c_b$i <<ComboboxSelected>> "$this reconnect C $i"

			bindtags $canvas_widget.cb_c_p$i	\
				[list $canvas_widget.cb_c_p$i TCombobox all .]
			bindtags $canvas_widget.cb_c_b$i	\
				[list $canvas_widget.cb_c_b$i TCombobox all .]

			incr x $sep
		}

		# Create labels
		set x $x_0
		set y $y_0
		incr y -$sep
		incr x -55

		$canvas_widget create text 70 $cb_p_y	\
			-text [mc "PORT"]		\
			-font $cb_font			\
			-anchor e
		$canvas_widget create text 70 $cb_b_y	\
			-text [mc "BIT"]		\
			-font $cb_font			\
			-anchor e
		$canvas_widget create text [expr {$x_0 - 53}] [expr {$y_0 - 2*$sep}]	\
			-text [mc "PORT"]		\
			-font $cb_font			\
			-anchor ne
		$canvas_widget create text [expr {$x_0 - 50}] [expr {$y_0 - 2*$sep}]	\
			-text [mc "BIT"]		\
			-font $cb_font			\
			-anchor nw

		$canvas_widget create text 35 278	\
			-text [mc "Note"]		\
			-font $cb_font			\
			-anchor e
		$canvas_widget create window 40 278			\
			-window [ttk::entry $canvas_widget.usr_note	\
				-validate key				\
				-validatecommand "$this set_modified"	\
			]	\
			-width 230 -anchor w
		bindtags $canvas_widget.usr_note	\
			[list $canvas_widget.usr_note TEntry $win all .]


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
		$canvas_widget create window 2 22 -window $start_stop_button -anchor sw
		bindtags $start_stop_button [list $start_stop_button TButton all .]

		# Create configuration menu button
		set conf_button [ttk::button $canvas_widget.conf_but	\
			-image ::ICONS::16::configure			\
			-style FlatWhite.TButton			\
			-command "$this config_menu"			\
		]
		setStatusTip -widget $conf_button -text [mc "Configure"]
		$canvas_widget create window 2 22 -window $conf_button -anchor nw
		bindtags $conf_button [list $conf_button TButton all .]

		# Pack canvas
		pack $canvas_widget -fill both -expand 1

		# Set window parameters
		wm minsize $win 280 295
		wm iconphoto $win ::ICONS::16::$component_icon
		wm title $win "[mc $component_name] - [$project cget -projectName] - MCU 8051 IDE"
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW "$this close_window"
		bindtags $win [list $win Toplevel all .]
	}

	## Determinate which port pin is connected to the specified wire
	 # @parm Char col_or_row	- 'C' => Column; 'R' => Row
	 # @parm Int i			- Wire number  (0..7)
	 # @return List - {port_number bit_number}
	private method which_port_pin {col_or_row i} {
		return [list $connection_port(${col_or_row}${i}) $connection_pin(${col_or_row}${i})]
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

		for {set i 0} {$i < 8} {incr i} {
			$canvas_widget.cb_r_p$i configure -values $available_ports
			$canvas_widget.cb_c_p$i configure -values $available_ports

			if {[lsearch -ascii -exact $available_ports $connection_port(R$i)] == -1} {
				$canvas_widget.cb_r_p$i current 0
				set connection_port(R$i) {-}
			}
			if {[lsearch -ascii -exact $available_ports $connection_port(C$i)] == -1} {
				$canvas_widget.cb_c_p$i current 0
				set connection_port(C$i) {-}
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

		# Change column wire colors
		for {set i 0} {$i < 8} {incr i} {
			# Determinate index in the list of port states
			set pp [which_port_pin C $i]

			# Not connected
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
				foreach item $col($i) {
					$canvas_widget itemconfigure $item -fill {#000000}
				}
				continue
			}

			# Determinate wire color
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

			# Change wire color
			foreach item $col($i) {
				$canvas_widget itemconfigure $item -fill $wire_color
			}
		}

		# Change row wire colors
		for {set i 0} {$i < 8} {incr i} {
			# Determinate index in the list of port states
			set pp [which_port_pin R $i]

			# Not connected
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
				foreach item $row($i) {
					$canvas_widget itemconfigure $item -fill {#000000}
				}
				continue
			}

			# Determinate wire color
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

			# Change wire color
			foreach item $row($i) {
				$canvas_widget itemconfigure $item -fill $wire_color
			}
		}

		## Change LED colors
		 # Iterate over rows
		for {set j 0} {$j < 8} {incr j} {
			# Determinate index in the list of port states
			set pp [which_port_pin R $j]

			# Not connected
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
				for {set i 0} {$i < 8} {incr i} {
					$canvas_widget itemconfigure	\
						$leds($j,$i)		\
						-image ::ICONS::16::ledgray
				}
				continue
			}

			# Determinate row state in this way:
			#+ row_state == 0   =>   Dim
			#+ row_state == 1   =>   Half dim
			#+ row_state == 2   =>   Brighten
			set row_state [lindex $state $pp]
			switch -- $row_state {
				{0} {	;# Logical 0
					if {[lindex $conf_led_cond 0]} {
						set row_state 0
					} else {
						set row_state 2
					}
				}
				{1} {	;# Logical 1
					if {[lindex $conf_led_cond 0]} {
						set row_state 2
					} else {
						set row_state 0
					}
				}
				{?} {	;# No volatge
					set row_state 0
				}
				{=} {	;# High forced to low
					set row_state 0
				}
				{} {	;# Not connected
					set row_state 0
				}
				default {
					set row_state 1
				}
			}

			# Iterate over rows
			for {set i 0} {$i < 8} {incr i} {
				# Determinate index in the list of port states
				set pp [which_port_pin C $i]

				# Not connected
				if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
					$canvas_widget itemconfigure $leds($j,$i) -image ::ICONS::16::ledgray
					continue
				}

				# Determinate LED color
				switch -- [lindex $state $pp] {
					{0} {	;# Logical 0
						if {[lindex $conf_led_cond 1]} {
							set image 0	;# ledgray
						} else {
							set image 1	;# shining LED
						}
					}
					{1} {	;# Logical 1
						if {[lindex $conf_led_cond 1]} {
							set image 1	;# shining LED
						} else {
							set image 0	;# ledgray
						}
					}
					{?} {	;# No volatge
						set image 0	;# ledgray
					}
					{=} {	;# High forced to low
						set image 0	;# ledgray
					}
					{} {	;# Not connected
						set image 0	;# ledgray
					}
					default {
						switch -- $row_state {
							{0} {
								set image 0	;# ledgray
							}
							{1} {
								set image 0	;# ledgray
							}
							{2} {
								set image 2	;# ledgray${conf_led_color}
							}
						}
					}
				}

				# Adjust previous states of LEDs to the type of matrix mapping
				if {$conf_matrix_mapping == 1} {
					if {$row_state == 2} {
						set prev_state($j,$i) 0
					}
				} elseif {$conf_matrix_mapping == 2} {
					if {$image == 1} {
						set prev_state($j,$i) 0
					}
				}

				# Translate "shine" to appropriate color
				if {$image == 1} {	;# shining LED
					switch -- $row_state {
						{0} {
							set image 0	;# ledgray
						}
						{1} {
							set image 2	;# ledgray${conf_led_color}
						}
						{2} {
							set image 3	;# led${conf_led_color}
						}
					}
				}

				## LED's dims with delay ...
				 # Dim with delay
				if {$image == 0} {
					if {$prev_state($j,$i)} {
						if {!$preserve_prvious_state} {
							incr prev_state($j,$i) -1
						}
						if {$prev_state($j,$i)} {
							set image 4	;# led${conf_led_color}2
						}
					}
				 # Light up now
				} elseif {$image == 3} {
					if {!$preserve_prvious_state} {
						set prev_state($j,$i) $conf_dim_interval
					}
				}

				switch -- $image {
					0	{set image "ledgray"}
					1	{set image ""}
					2	{set image "ledgray${conf_led_color}"}
					3	{set image "led${conf_led_color}"}
					4	{set image "led${conf_led_color}2"}
				}

				# Change LED color
				$canvas_widget itemconfigure $leds($j,$i)	\
					-image ::ICONS::16::$image
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
				$conf_led_cond			\
				$conf_matrix_mapping		\
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
			set conf_led_cond	[lindex $state 6]
			set conf_matrix_mapping	[lindex $state 7]

			if {$conf_matrix_mapping == {}} {
				set conf_matrix_mapping 0
			}

			if {[lindex $state 8] != {}} {
				set keep_win_on_top [lindex $state 8]
				if {$keep_win_on_top} {
					wm attributes $win -topmost 1 -alpha 0.8
				}
			}

			# Restore state of ComboBoxes
			foreach foo {R C} bar {r c} {
				for {set i 0} {$i < 8} {incr i} {
					## PIN
					set pin $connection_pin(${foo}${i})
					if {$pin != {-}} {
						set pin	[expr {7 - $pin}]
					}
					set idx [lsearch -ascii -exact				\
						[$canvas_widget.cb_${bar}_b$i cget -values]	\
						$pin						\
					]
					if {$idx == -1} {
						set idx 0
					}
					$canvas_widget.cb_${bar}_b$i current $idx

					## PORT
					set idx [lsearch -ascii -exact				\
						[$canvas_widget.cb_${bar}_p$i cget -values]	\
						$connection_port(${foo}$i)			\
					]
					if {$idx == -1} {
						set idx 0
					}
					$canvas_widget.cb_${bar}_p$i current $idx
				}
			}

			# Accept new state of ports
			set state [$project pale_get_true_state]
			new_state state
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
		set ::${class_name}::matrix_mapping $conf_matrix_mapping
		set ::${class_name}::color $conf_led_color
		set ::${class_name}::cond $conf_led_cond
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
		$text_widget insert insert [mc "This tool consists of 64 LED's.  Each of them can be connected to any port pin of the simulated uC.  Connections with the uC are made with ComboBoxes.  Panel configuration can be saved to a file with extension vhc, and can be loaded from that file later.  Condition on which a LED lights up and LED colors are configurable.  Also fade out interval is configurable.\n\n"]

		$text_widget insert insert [mc "LED states:"]
		$text_widget tag add tag_bold {insert linestart} {insert lineend}
		$text_widget insert insert [mc "\n  "]
		$text_widget image create insert -image ::ICONS::16::ledgray
		$text_widget insert insert [mc "  Off\n  "]
		$text_widget image create insert -image ::ICONS::16::ledgray${conf_led_color}
		$text_widget insert insert [mc "  Fast blinking\n  "]
		$text_widget image create insert -image ::ICONS::16::led${conf_led_color}
		$text_widget insert insert [mc "  Shining\n  "]
		$text_widget image create insert -image ::ICONS::16::led${conf_led_color}2
		$text_widget insert insert [mc "  Fading out"]
	}

	## This method is called before panel window closure
	 # @return void
	public method close_window_special {} {
	}

	## Commit new on/off state
	 # @return void
	public method on_off_special {} {
		if {!$drawing_on} {
			for {set j 0} {$j < 8} {incr j} {
				for {set i 0} {$i < 8} {incr i} {
					$canvas_widget itemconfigure $leds($j,$i)	\
						-image ::ICONS::16::ledgray
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

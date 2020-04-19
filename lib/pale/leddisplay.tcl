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
if { ! [ info exists _LEDDISPLAY_TCL ] } {
set _LEDDISPLAY_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# Implements PALE VHW component "LED display"
#
# Consists of:
#	INTERNAL APPLICATION LOGIC
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM PALE ENGINE
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
# --------------------------------------------------------------------------

class LedDisplay {
	inherit VirtualHWComponent

	# Font: Font to be used in the panel -- bold
	public common cb_font	[font create				\
		-weight bold					\
		-size [expr {int(-10 * $::font_size_factor)}]	\
		-family {helvetica}				\
	]
	public common COMPONENT_NAME	"LED Display"	;# Name of this component
	public common CLASS_NAME	"LedDisplay"	;# Name of this class
	public common COMPONENT_ICON	{leddisplay}	;# Icon for this panel (16x16)

	## Colors for display segments
	 # There are 6 lists (red orange yellow green blue purple)
	 # and each of them contain 3 colors (semi-dim bright dim)
	public common COLORS {
		{#AA5555 #FF0000}
		{#AAAA55 #FF8800}
		{#AAAA55 #FFFF00}

		{#55AA55 #00FF00}
		{#5555AA #0000FF}
		{#AA55AA #8800FF}
	}
	public common DIMMED_COLOR	{#BBBBBB}

	# Configuration menu
	public common CONFMENU {
		{cascade	{Common electrode}	7	"diode"		.ca	false 1 {
			{radiobutton	"Common anode"	{}
				::LedDisplay::cfg_common_anode	1
				"common_electrode_changed"	7	""}
			{radiobutton	"Common cathode"	{}
				::LedDisplay::cfg_common_anode	0
				"common_electrode_changed"	7	""}
		}}
		{cascade	{Color}			0	"colorize"	.color	false 1 {
			{radiobutton	"Red"		{}
				::LedDisplay::color		{red}
				"color_changed"	0	""}
			{radiobutton	"Orange"	{}
				::LedDisplay::color		{orange}
				"color_changed"	0	""}
			{radiobutton	"Yellow"	{}
				::LedDisplay::color		{yellow}
				"color_changed"	0	""}
			{radiobutton	"Green"		{}
				::LedDisplay::color		{green}
				"color_changed"	0	""}
			{radiobutton	"Blue"		{}
				::LedDisplay::color		{blue}
				"color_changed"	0	""}
			{radiobutton	"Purple"	{}
				::LedDisplay::color		{purple}
				"color_changed"	0	""}
		}}
		{separator}
		{command	{Show help}		{}	5	"show_help"	{help}
			"Show brief help"}
		{separator}
		{command	{Save configuration}	{}	0	"save_as"	{filesave}
			"Save configuration into a file"}
		{command	{Load configuration}	{}	0	"load_from"	{fileopen}
			"Load configuration from a file"}
		{separator}
		{checkbutton	"Window always on top"	{}	{::LedDisplay::menu_keep_win_on_top}
			1 0 0	{keep_win_on_top_changed}
			""}
	}

	private variable conf_led_color	{red}	;# Color: Selected color for LED's
	private variable keep_win_on_top 0	;# Bool: Toplevel window

	private variable leds			;# Array of CanvasObject (polygon): leds(segment_num) --> LED polygon
	private variable wires			;# Array of CanvasObject (line): Wire connection LED with uC
	private variable connection_port	;# Array of Int: Index is key number, value is port number or {-}
	private variable connection_pin		;# Array of Int: Index is key number, value is bit number or {-}
	private variable common_anode	1	;# Bool: 1 == common anode; 0 == common cathode

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
		array set connection_port	{0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 -}
		array set connection_pin	{0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 -}

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
		set win [toplevel .leddisplay$count -class $component_name -bg ${::COMMON_BG_COLOR}]
		set canvas_widget [canvas $win.canvas	\
			-bg white -width 0 -height 0	\
			-highlightthickness 0		\
		]

		# Draw display and wires
		draw_8_segment 85 30
		draw_wires 0 -10

		# Create ComboBoxes
		set cb_p_x0 200
		set cb_b_x0 200
		set cb_p_x1 40
		set cb_b_x1 40
		set y_0 30
		set y_1 120
		set y_inc 30
		for {set i 0} {$i < 8} {incr i} {
			if {$i == 0} {
				set y $y_0
				set cb_p_x $cb_p_x0
				set cb_b_x $cb_b_x0
			} elseif {$i == 4} {
				set y $y_1
				set y_inc -$y_inc
				set cb_p_x $cb_p_x1
				set cb_b_x $cb_b_x1
			}

			$canvas_widget create window $cb_p_x $y -anchor e	\
				-window [ttk::combobox $canvas_widget.cb_p$i	\
					-width 1				\
					-font $cb_font				\
					-state readonly				\
				]
			bind $canvas_widget.cb_p$i <<ComboboxSelected>>	"$this reconnect $i"

			$canvas_widget create window $cb_b_x $y -anchor w	\
				-window [ttk::combobox $canvas_widget.cb_b$i	\
					-width 1				\
					-font $cb_font				\
					-values {- 0 1 2 3 4 5 6 7}		\
					-state readonly				\
				]
			bind $canvas_widget.cb_b$i <<ComboboxSelected>>	"$this reconnect $i"

			bindtags $canvas_widget.cb_p$i	\
				[list $canvas_widget.cb_p$i TCombobox all .]
			bindtags $canvas_widget.cb_b$i	\
				[list $canvas_widget.cb_b$i TCombobox all .]

			incr y $y_inc
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
		$canvas_widget create window 115 2 -window $start_stop_button -anchor nw
		bindtags $start_stop_button [list $start_stop_button TButton all .]

		# Create configuration menu button
		set conf_button [ttk::button $canvas_widget.conf_but	\
			-image ::ICONS::16::configure			\
			-style FlatWhite.TButton			\
			-command "$this config_menu"			\
		]
		setStatusTip -widget $conf_button -text [mc "Configure"]
		$canvas_widget create window 113 2 -window $conf_button -anchor ne
		bindtags $conf_button [list $conf_button TButton all .]

		# Print labels
		$canvas_widget create text 40 5	\
			-text [mc "PORT"]	\
			-font $cb_font		\
			-anchor ne
		$canvas_widget create text 42 5	\
			-text [mc "BIT"]	\
			-font $cb_font		\
			-anchor nw
		$canvas_widget create text 200 5\
			-text [mc "PORT"]	\
			-font $cb_font		\
			-anchor ne
		$canvas_widget create text 202 5\
			-text [mc "BIT"]	\
			-font $cb_font		\
			-anchor nw

		$canvas_widget create text 35 160	\
			-text [mc "Note"]		\
			-font $cb_font			\
			-anchor e
		$canvas_widget create window 40 160		\
			-window [ttk::entry $canvas_widget.usr_note	\
				-validate key				\
				-validatecommand "$this set_modified"	\
			]	\
			-width 180 -anchor w
		bindtags $canvas_widget.usr_note	\
			[list $canvas_widget.usr_note TEntry $win all .]

		# Pack canvas
		pack $canvas_widget -fill both -expand 1

		# Set window parameters
		wm minsize $win 230 175
		wm iconphoto $win ::ICONS::16::$component_icon
		wm title $win "[mc $component_name] - [$project cget -projectName] - MCU 8051 IDE"
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW "$this close_window"
		bindtags $win [list $win Toplevel all .]
	}

	## Value of configuration menu variable "keep_win_on_top" has been changed
	 # @return void
	public method keep_win_on_top_changed {} {
		set keep_win_on_top $LedDisplay::menu_keep_win_on_top
		if {$keep_win_on_top} {
			wm attributes $win -topmost 1 -alpha 0.8
		} else {
			wm attributes $win -topmost 0 -alpha 1.0
		}
	}

	## Reconnect the specified LED to another port pin
	 # @parm Int i - LED number (0..7)
	 # @return void
	public method reconnect {i} {
		# Adjust connections
		set connection_port($i) [$canvas_widget.cb_p$i get]
		set connection_pin($i)	[$canvas_widget.cb_b$i get]
		if {$connection_pin($i) != {-}} {
			set connection_pin($i)	[expr {7 - $connection_pin($i)}]
		}

		# Change state of the device
		if {$drawing_on} {
			set state [$project pale_get_true_state]
			new_state state
		}

		# Set flag modified
		set_modified
	}

	## LED's common electrode changed
	 # @return void
	public method common_electrode_changed {} {
		set common_anode ${::LedDisplay::cfg_common_anode}

		if {$drawing_on} {
			set state [$project pale_get_true_state]
			new_state state
		}
		set_modified
	}

	## LED color changed
	 # @return void
	public method color_changed {} {
		set conf_led_color ${::LedDisplay::color}

		if {$drawing_on} {
			set state [$project pale_get_true_state]
			new_state state
		}
		set_modified
	}

	## Draw wires conneting LED's with uC (ComboBoxes)
	 # @parm Int x	- X origin coordinate
	 # @parm Int y	- Y origin coordinate
	 # @return void
	private method draw_wires {x y} {
		set coords {
			{
				120 40	180 40
			} {
				145 70	180 70
			} {
				140 100	180 100
			} {
				110 125	110 130	180 130
			} {
				87 110	82 110	82 130	50 130
			} {
				91 75	82 75	82 100	50 100
			} {
				116 78	116 70	50 70
			} {
				138 125	138 150	5 150	5 40	30 40
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

	## Draw LED display
	 # @parm Int x	- X origin coordinate
	 # @parm Int y	- Y origin coordinate
	 # @return void
	private method draw_8_segment {x y} {
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
					[expr {[lindex $local_coords $m] + $x}]
				lappend coordinates	\
					[expr {[lindex $local_coords $n] + $y}]
			}

			# Draw
			set leds($i) [$canvas_widget create polygon		\
				$coordinates -width 0 -fill $DIMMED_COLOR	\
			]
		}

		# Transform coordinates -- adjust them to the given origin
		#+ Draw LED oval -- for segment P (point)
		set leds(7) [$canvas_widget create oval		\
			[expr {49 + $x}] [expr {77 + $y}]	\
			[expr {58 + $x}] [expr {86 + $y}]	\
			-width 0 -fill $DIMMED_COLOR		\
		]

		# Print segment labels
		foreach coords {{35 7} {53 25} {48 62} {26 79} {10 61} {15 25} {31 43}} \
			text {A B C D E F G} \
		{
			$canvas_widget create text			\
				[expr {[lindex $coords 0] + $x}]	\
				[expr {[lindex $coords 1] + $y}]	\
				-text $text -fill {#FFFFFF}		\
				-font $::smallfont
		}
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


	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE
	# ------------------------------------------------------------------

	## Simulated MCU has been changed
	 # @return void
	public method mcu_changed {} {
		# Refresh lists of possible values in port selection ComboBoxes
		set available_ports [concat - [$project pale_get_available_ports]]

		for {set i 0} {$i < 8} {incr i} {
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

		# Determinate index of LED color in list COLORS
		set color_idx [lsearch -ascii -exact		\
			{red orange yellow green blue purple}	\
			$conf_led_color				\
		]

		# Iterate over 8 segments
		for {set i 0} {$i < 8} {incr i} {
			# Determinate index in the list of port states
			set pp [which_port_pin $i]

			# Not connected
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
				$canvas_widget itemconfigure $leds($i) -fill $DIMMED_COLOR
				$canvas_widget itemconfigure $wires($i) -fill {#000000}
				continue
			}

			# Determinate wire and LED color
			switch -- [lindex $state $pp] {
				{0} {	;# Logical 0
					if {$common_anode} {
						set segment_color	{2}
					} else {
						set segment_color	{0}
					}
					set wire_color		{#00FF00}
				}
				{1} {	;# Logical 1
					if {$common_anode} {
						set segment_color	{0}
					} else {
						set segment_color	{2}
					}
					set wire_color		{#FF0000}
				}
				{=} {	;# High forced to low
					set segment_color	{0}
					set wire_color		{#FF00AA}
				}
				{} {	;# Not connected
					set segment_color	{0}
					set wire_color		{#000000}
				}
				{?} {	;# No volatge
					set segment_color	{0}
					set wire_color		{#888888}
				}
				default {
					set segment_color	{1}
					set wire_color		{#FF8800}
				}
			}

			# Determinate segment color (true color, not just number)
			if {!$segment_color} {
				set segment_color $DIMMED_COLOR
			} else {
				incr segment_color -1
				set segment_color [lindex $COLORS [list $color_idx $segment_color]]
			}

			# Change segment and wire color
			$canvas_widget itemconfigure $leds($i) -fill $segment_color
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
				$conf_led_color			\
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
			set conf_led_color [lindex $state 4]
			set common_anode [lindex $state 5]
			if {$common_anode == {}} {
				set common_anode 1
			}

			if {[lindex $state 6] != {}} {
				set keep_win_on_top [lindex $state 6]
				if {$keep_win_on_top} {
					wm attributes $win -topmost 1 -alpha 0.8
				}
			}

			# Restore state of ComboBoxes
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
			set state [$project pale_get_true_state]
			new_state state
	}


	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
	# ------------------------------------------------------------------

	## This method is called before configuration menu invocation
	 # @return void
	public method config_menu_special {} {
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
		$text_widget insert insert [mc "Virtual LED display with common anode (default) or cathode.  Each segment can be connected to any port pin of the simulated uC.  Connections with the uC are made with ComboBoxes on the bottom of the panel.  Panel configuration can be saved to a file with extension vhc, and can be loaded from that file later.\n\n"]

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
	}

	## This method is called before panel window closure
	 # @return void
	public method close_window_special {} {
	}

	## Commit new on/off state
	 # @return void
	public method on_off_special {} {
		if {!$drawing_on} {
			for {set i 0} {$i < 8} {incr i} {
				$canvas_widget itemconfigure $leds($i) -fill {#888888}
				$canvas_widget itemconfigure $wires($i) -fill {#000000}
			}
		} else {
			set state [$project pale_get_true_state]
			new_state state
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

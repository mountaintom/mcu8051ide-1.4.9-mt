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
if { ! [ info exists _LEDPANEL_TCL ] } {
set _LEDPANEL_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# Implements PALE VHW component "LED panel"
#
# Consists of:
#	INTERNAL APPLICATION LOGIC
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM PALE ENGINE
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
# --------------------------------------------------------------------------

class LedPanel {
	inherit VirtualHWComponent

	# Font: Font to be used in the panel -- bold
	public common cb_font	[font create				\
		-weight bold					\
		-size [expr {int(-10 * $::font_size_factor)}]	\
		-family {helvetica}				\
	]
	public common COMPONENT_NAME	"LED Panel"	;# Name of this component
	public common CLASS_NAME	"LedPanel"	;# Name of this class
	public common COMPONENT_ICON	{ledpanel}	;# Icon for this panel (16x16)

	# Configuration menu
	public common CONFMENU {
		{cascade	{Color}			0	"colorize"	.color	false 1 {
			{radiobutton	"Red"		{}
				::LedPanel::color		{red}
				"color_changed"	0	""}
			{radiobutton	"Orange"	{}
				::LedPanel::color		{orange}
				"color_changed"	0	""}
			{radiobutton	"Yellow"	{}
				::LedPanel::color		{yellow}
				"color_changed"	0	""}
			{radiobutton	"Green"		{}
				::LedPanel::color		{green}
				"color_changed"	0	""}
			{radiobutton	"Blue"		{}
				::LedPanel::color		{blue}
				"color_changed"	0	""}
			{radiobutton	"Purple"	{}
				::LedPanel::color		{purple}
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
		{checkbutton	"Window always on top"	{}	{::LedPanel::menu_keep_win_on_top}
			1 0 0	{keep_win_on_top_changed}
			""}
	}


	private variable keep_win_on_top 0	;# Bool: Toplevel window
	private variable conf_led_color	{red}	;# Color: Selected color for LED's
	private variable leds			;# Array of CanvasObject (image): LED's
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

	## Value of configuration menu variable "keep_win_on_top" has been changed
	 # @return void
	public method keep_win_on_top_changed {} {
		set keep_win_on_top $LedPanel::menu_keep_win_on_top
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

	## LED color changed
	 # @return void
	public method color_changed {} {
		set conf_led_color ${::LedPanel::color}

		if {$drawing_on} {
			set state [$project pale_get_true_state]
			new_state state
		}
		set_modified
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

		# Print labels
		set led_y 35
		set cb_p_y 65
		set cb_b_y 85
		set usr_n_y 110
		set x 50
		$canvas_widget create text 5 $cb_p_y	\
			-text [mc "PORT"]		\
			-font $cb_font			\
			-anchor w
		$canvas_widget create text 5 $cb_b_y	\
			-text [mc "BIT"]		\
			-font $cb_font			\
			-anchor w
		$canvas_widget create text 30 $usr_n_y	\
			-text [mc "Note"]		\
			-font $cb_font			\
			-anchor e
		$canvas_widget create window 35 $usr_n_y	\
			-window [ttk::entry $canvas_widget.usr_note	\
				-validate key				\
				-validatecommand "$this set_modified"	\
			]	\
			-width 330 -anchor w
		bindtags $canvas_widget.usr_note	\
			[list $canvas_widget.usr_note TEntry $win all .]

		# Create LES's and ComboBoxes
		for {set i 0} {$i < 8} {incr i} {
			set leds($i) [$canvas_widget create image $x $led_y	\
				-image ::ICONS::16::ledgray		\
			]

			incr x 6

			$canvas_widget create window $x $cb_p_y -anchor center	\
				-window [ttk::combobox $canvas_widget.cb_p$i	\
					-width 1				\
					-font $cb_font				\
					-state readonly				\
				]
			bind $canvas_widget.cb_p$i <<ComboboxSelected>> "$this reconnect $i"

			$canvas_widget create window $x $cb_b_y -anchor center	\
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

			incr x 6
			draw_led $x 10

			incr x 30
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

		# Pack canvas
		pack $canvas_widget -fill both -expand 1

		# Set window parameters
		wm minsize $win 380 130
		wm iconphoto $win ::ICONS::16::$component_icon
		wm title $win "[mc $component_name] - [$project cget -projectName] - MCU 8051 IDE"
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW "$this close_window"
		bindtags $win [list $win Toplevel all .]
	}

	## Draw LED and resistor symbol
	 # @parm Int x	- X origin coordinate
	 # @parm Int y	- Y origin coordinate
	 # @return void
	private method draw_led {x y} {
		$canvas_widget create line			\
			[expr {4 + $x}]		[expr {2 + $y}]	\
			[expr {6 + $x}]		[expr {0 + $y}]	\
			[expr {8 + $x}]		[expr {2 + $y}]	\
			[expr {6 + $x}]		[expr {0 + $y}]	\
			[expr {6 + $x}]		[expr {6 + $y}]	\
			[expr {8 + $x}]		[expr {6 + $y}]	\
			[expr {8 + $x}]		[expr {17 + $y}]\
			[expr {4 + $x}]		[expr {17 + $y}]\
			[expr {4 + $x}]		[expr {6 + $y}]	\
			[expr {6 + $x}]		[expr {6 + $y}]	\
			[expr {4 + $x}]		[expr {6 + $y}]	\
			[expr {4 + $x}]		[expr {17 + $y}]\
			[expr {6 + $x}]		[expr {17 + $y}]\
			[expr {6 + $x}]		[expr {37 + $y}]\
			[expr {6 + $x}]		[expr {28 + $y}]\
			[expr {0 + $x}]		[expr {28 + $y}]\
			[expr {12 + $x}]	[expr {28 + $y}]\
			[expr {6 + $x}]		[expr {28 + $y}]\
			[expr {6 + $x}]		[expr {27 + $y}]\
			[expr {0 + $x}]		[expr {21 + $y}]\
			[expr {12 + $x}]	[expr {21 + $y}]\
			[expr {6 + $x}]		[expr {27 + $y}]\
			[expr {6 + $x}]		[expr {37 + $y}]\
			[expr {0 + $x}]		[expr {43 + $y}]\
			-fill {#888888}

		$canvas_widget create line			\
			[expr {14 + $x}]	[expr {22 + $y}]\
			[expr {17 + $x}]	[expr {19 + $y}]\
			[expr {15 + $x}]	[expr {19 + $y}]\
			[expr {17 + $x}]	[expr {19 + $y}]\
			[expr {17 + $x}]	[expr {21 + $y}]\
			-fill {#888888}

		$canvas_widget create line			\
			[expr {14 + $x}]	[expr {26 + $y}]\
			[expr {17 + $x}]	[expr {23 + $y}]\
			[expr {15 + $x}]	[expr {23 + $y}]\
			[expr {17 + $x}]	[expr {23 + $y}]\
			[expr {17 + $x}]	[expr {25 + $y}]\
			-fill {#888888}
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

		for {set i 0} {$i < 8} {incr i} {
			# Determinate index in the list of port states
			set pp [which_port_pin $i]

			# Not connected
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
				$canvas_widget itemconfigure $leds($i) -image ::ICONS::16::ledgray
				continue
			}

			# Change LED color
			switch -- [lindex $state $pp] {
				{0} {	;# Logical 0
					set image led${conf_led_color}
				}
				{1} {	;# Logical 1
					set image ledgray
				}
				{?} {	;# No volatge
					set image ledgray
				}
				{=} {	;# High forced to low
					set image ledgray
				}
				{} {	;# Not connected
					set image ledgray
				}
				default {
					set image ledgray${conf_led_color}
				}
			}
			$canvas_widget itemconfigure $leds($i) -image ::ICONS::16::$image
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

			if {[lindex $state 5] != {}} {
				set keep_win_on_top [lindex $state 5]
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
		$text_widget insert insert [mc "This tool consists of 8 LED's.  Each of them can be connected to any port pin of the simulated uC.  Connections with the uC are made with ComboBoxes on the bottom of the panel.  Panel configuration can be saved to a file with extension vhc, and can be loaded from that file later.  LED colors are configurable.\n\n"]

		$text_widget insert insert [mc "LED states:"]
		$text_widget tag add tag_bold {insert linestart} {insert lineend}
		$text_widget insert insert [mc "\n  "]
		$text_widget image create insert -image ::ICONS::16::ledgray
		$text_widget insert insert [mc "  Off\n  "]
		$text_widget image create insert -image ::ICONS::16::ledgray${conf_led_color}
		$text_widget insert insert [mc "  Fast blinking\n  "]
		$text_widget image create insert -image ::ICONS::16::led${conf_led_color}
		$text_widget insert insert [mc "  Shining"]
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
				$canvas_widget itemconfigure $leds($i)	\
					-image ::ICONS::16::ledgray
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

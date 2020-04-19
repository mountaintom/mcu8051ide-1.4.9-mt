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
if { ! [ info exists _SIMPLEKEYPAD_TCL ] } {
set _SIMPLEKEYPAD_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# Implements PALE VHW component "Simple Keypad"
#
# Consists of:
#	INTERNAL APPLICATION LOGIC
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM PALE ENGINE
#	VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
# --------------------------------------------------------------------------

class SimpleKeyPad {
	inherit VirtualHWComponent

	# Font: Font to be used in the panel -- bold
	public common cb_font [font create				\
		-weight bold					\
		-size [expr {int(-10 * $::font_size_factor)}]	\
		-family {helvetica}				\
	]
	# Font: Font to be used in the panel -- normal weight
	public common cb_font_n [font create				\
		-size [expr {int(-10 * $::font_size_factor)}]	\
		-family {helvetica}				\
	]

	public common COMPONENT_NAME	"Simple Keypad"	;# Name of this component
	public common CLASS_NAME	"SimpleKeyPad"	;# Name of this class
	public common COMPONENT_ICON	{simplekeypad}	;# Icon for this panel (16x16)

	# Configuration menu
	public common CONFMENU {
		{checkbutton	"Radio buttons"		{}	{::SimpleKeyPad::menu_radio_buttons}
			1 0 0	{value_radio_buttons_changed}
			""}
		{command	{Show help}		{}	5	"show_help"	{help}
			"Show brief help"}
		{separator}
		{command	{Save configuration}	{}	0	"save_as"	{filesave}
			"Save configuration into a file"}
		{command	{Load configuration}	{}	0	"load_from"	{fileopen}
			"Load configuration from a file"}
		{separator}
		{checkbutton	"Window always on top"	{}	{::SimpleKeyPad::menu_keep_win_on_top}
			1 0 0	{keep_win_on_top_changed}
			""}
	}

	private variable radio_buttons	 0	;# Bool: Disallow key combinations
	private variable keep_win_on_top 0	;# Bool: Toplevel window
	private variable keys			;# Array of Bool: Indicates key press
	private variable wire			;# Array of CanvasObject (line): Wires connected to MCU pins
	private variable wire_o			;# Array of CanvasObject (oval): Wires connected to MCU pins
	private variable rect			;# Array of CanvasObject (rectangle): Key rectangles
	private variable lever			;# Array of CanvasObject (line): Key levers
	private variable text			;# Array of CanvasObject (text): Key descriptions
	private variable connection_port	;# Array of Int: Index is key number, value is port number or {-}
	private variable connection_pin		;# Array of Int: Index is key number, value is bit number or {-}
	private variable enaged			;# Array of Bool: enaged(port_num,bit_num) --> Is connected to this device?


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
		set radio_buttons 1
		array set connection_port	{0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 -}
		array set connection_pin	{0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 -}
		array set keys			{0 0 1 0 2 0 3 0 4 0 5 0 6 0 7 0}
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

		# ComboBoxes to default state
		for {set i 0} {$i < 8} {incr i} {
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
		for {set i 0} {$i < 8} {incr i} {
			set port $connection_port($i)
			set bit $connection_pin($i)

			if {$port == {-} || $bit == {-}} {
				continue
			}

			set enaged($port,$bit) 1
			$project pale_engage_pin_by_input_device $port $bit $this
		}
	}

	## Reconnect the specified key to another port pin
	 # @parm Int i - Key number (0..7)
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

		# Inform PALE system about the change in order
		#+ to make immediate change in device states
		if {$drawing_on} {
			$project pale_reevaluate_IO
		}

		# Set flag modified
		set_modified
	}

	## Create GUI of this panel
	 # @return void
	private method create_gui {} {
		# Create panel window and canvas widget
		set win [toplevel .simplekeypad$count -class $component_name -bg ${::COMMON_BG_COLOR}]
		set canvas_widget [canvas $win.canvas -bg white -width 0 -height 0]

		set cb_p_y 65
		set cb_b_y 85
		set usr_n_y 110
		set x 50

		# Create labels
		$canvas_widget create text 5 $cb_p_y	\
			-text [mc "PORT"]		\
			-font $cb_font			\
			-anchor w
		$canvas_widget create text 5 $cb_b_y	\
			-text [mc "BIT"]		\
			-font $cb_font			\
			-anchor w
		$canvas_widget create text 32 $usr_n_y	\
			-text [mc "Note"]		\
			-font $cb_font			\
			-anchor e
		$canvas_widget create window 37 $usr_n_y	\
			-window [ttk::entry $canvas_widget.usr_note	\
				-validate key				\
				-validatecommand "$this set_modified"	\
			]	\
			-width 220 -anchor w
		bindtags $canvas_widget.usr_note	\
			[list $canvas_widget.usr_note TEntry $win all .]

		# Create ComboBoxes
		for {set i 0} {$i < 8} {incr i} {
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

			incr x -13
			draw_key $x 15 $i

			incr x 40
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
		wm minsize $win 265 125
		wm iconphoto $win ::ICONS::16::$component_icon
		wm title $win "[mc $component_name] - [$project cget -projectName] - MCU 8051 IDE"
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW "$this close_window"
		bindtags $win [list $win Toplevel all .]
	}

	## Handle click on a virtual key
	 # @parm Int i - Key number
	 # @return void
	public method key_click {i} {
		# Adjust state of the key
		set keys($i) [expr {!$keys($i)}]
		key_state_changed $i

		# Release all other keys if the panel was configured to use radio buttons
		if {$radio_buttons} {
			for {set j 0} {$j < 8} {incr j} {
				if {$j == $i} {
					continue
				}
				if {$keys($j)} {
					set keys($j) 0
					key_state_changed $j
				}
			}
		}

		# Inform PALE system about the change in order
		#+ to make immediate change in device states
		if {$drawing_on} {
 			$project pale_reevaluate_IO
 		}

		# Set flag modified
		set_modified
	}

	## Adjust GUI to new state of a virtual key
	 # @parm Int i - Key number
	 # @return void
	private method key_state_changed {i} {
		# Key pressed
		if {$keys($i)} {
			$canvas_widget itemconfigure $lever(0$i) -fill #FFFFFF
			$canvas_widget itemconfigure $lever(1$i) -fill #00DD00
			$canvas_widget itemconfigure $text($i) -font $cb_font
			$canvas_widget itemconfigure $rect($i) -outline #333333 -width 2

		# Key released
		} else {
			$canvas_widget itemconfigure $lever(0$i) -fill #000000
			$canvas_widget itemconfigure $lever(1$i) -fill #FFFFFF
			$canvas_widget itemconfigure $text($i) -font $cb_font_n
			$canvas_widget itemconfigure $rect($i) -outline #CCCCCC -width 1
		}
	}

	## Handle mouse pointer enter on a virtual key
	 # @parm Int i - Key number
	 # @return void
	public method key_leave {i} {
		if {$keys($i)} {
			set color {#333333}
		} else {
			set color {#CCCCCC}
		}
		$canvas_widget itemconfigure $rect($i) -outline $color
	}

	## Handle mouse pointer leave on a virtual key
	 # @parm Int i - Key number
	 # @return void
	public method key_enter {i} {
		$canvas_widget itemconfigure $rect($i) -outline {#0000FF}
	}

	## Draw virtual key on the panel canvas
	 # @parm Int x - X coordinate of top left corner of the key
	 # @parm Int y - Y coordinate of top left corner of the key
	 # @parm Int i - Key number
	 # @return void
	private method draw_key {x y i} {
		# Draw rectangle sorrounding the key
		set rect($i) [$canvas_widget create rectangle	\
			[expr {$x + 1}] [expr {$y + 1}]		\
			[expr {$x + 25}] [expr {$y + 29}]	\
			-width 1 -outline #CCCCCC -fill #FFFFFF	\
		]

		# Draw lines connecting the key to MCU port pin
		set wire($i) [$canvas_widget create line	\
			[expr {$x + 13}] [expr {$y + 26}]	\
			[expr {$x + 13}] [expr {$y + 40}]	\
			-width 1 -fill #000000			\
		]
		set wire_o($i) [$canvas_widget create oval 	\
			[expr {$x + 11}] [expr {$y + 21}]	\
			[expr {$x + 15}] [expr {$y + 25}]	\
			-width 1 -outline #000000		\
		]

		# Draw lever in the key
		set lever(1$i) [$canvas_widget create line	\
			[expr {$x + 11}] [expr {$y + 22}]	\
			[expr {$x + 11}] [expr {$y + 6}]	\
			-width 1 -fill #FFFFFF			\
		]
		set lever(0$i) [$canvas_widget create line	\
			[expr {$x + 10}] [expr {$y + 22}]	\
			[expr {$x + 5}] [expr {$y + 6}]		\
			-width 1 -fill #000000			\
		]

		# Draw lines connecting the key to the electrical ground
		$canvas_widget create line			\
			[expr {$x + 13}] [expr {$y + 4}]	\
			[expr {$x + 13}] [expr {$y - 10}]	\
			[expr {$x + 8}] [expr {$y - 10}]	\
			[expr {$x + 18}] [expr {$y - 10}]	\
			-width 1 -fill #00DD00
		set lines [$canvas_widget create oval 		\
			[expr {$x + 11}] [expr {$y + 5}]	\
			[expr {$x + 15}] [expr {$y + 9}]	\
			-width 1 -outline #00DD00		\
		]

		# Print key label
		set text($i) [$canvas_widget create text 	\
			[expr {$x + 20}] [expr {$y + 15}]	\
			-font $cb_font_n			\
			-text [lindex {A B C D E F G H} $i]	\
		]

		# Set event bindings for the key
		foreach items [list					\
			$rect($i)	$lines		$text($i)	\
			$lever(0$i)	$lever(1$i)	$wire_o($i)	\
		] {
			foreach item $items {
				$canvas_widget bind $item <Enter> "$this key_enter $i"
				$canvas_widget bind $item <Leave> "$this key_leave $i"
				$canvas_widget bind $item <Button-1> "$this key_click $i"
			}
		}
	}

	## Determinate which port pin is connected to the specified key
	 # @parm Int i - Key number
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

	## Value of configuration menu variable "menu_radio_buttons" has been changed
	 # @return void
	public method value_radio_buttons_changed {} {
		set radio_buttons $::SimpleKeyPad::menu_radio_buttons
	}

	## Value of configuration menu variable "keep_win_on_top" has been changed
	 # @return void
	public method keep_win_on_top_changed {} {
		set keep_win_on_top $SimpleKeyPad::menu_keep_win_on_top
		if {$keep_win_on_top} {
			wm attributes $win -topmost 1 -alpha 0.8
		} else {
			wm attributes $win -topmost 0 -alpha 1.0
		}
	}

	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE -- CALLED FROM PALE ENGINE
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

	## Evaluate new state of ports
	 # @parm List state	- Port states ( 5 x {8 x bit} -- {bit0 bit1 bit2 ... bit7} )
	 # @return state	- New port states modified by this device
	 # 			  format is the same as parameter $state
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

		# Iterate over keys
		for {set i 0} {$i < 8} {incr i} {
			# Determinate index in the list of port states
			set pp [which_port_pin $i]

			# Key is not connected or panel is turned off
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-} || !$drawing_on} {
				if {$keys($i)} {
					set wire_color {#00DD00}
				} else {
					set wire_color {#000000}
				}

				$canvas_widget itemconfigure $wire($i) -fill $wire_color
				$canvas_widget itemconfigure $lever($keys(${i})${i}) -fill $wire_color
				$canvas_widget itemconfigure $wire_o($i) -outline $wire_color

				continue
			}

			# Pressed key forces port pin state to logical 0
			if {$keys($i)} {
				lset state $pp 0
			}

			# Determinate color for wires connected to the MCU
			switch -- [lindex $state $pp] {
				{0} {	;# Logical 0
					set wire_color	{#00FF00}
				}
				{1} {	;# Logical 1
					set wire_color	{#FF0000}
				}
				{=} {	;# High forced to low
					set wire_color	{#FF00AA}
				}
				{} { 	;# Not connected
					set wire_color	{#000000}
				}
				{?} {	;# No volatge
					set wire_color	{#888888}
				}
				default {
					set wire_color	{#FF8800}
				}
			}

			# Adjust key apparence
			$canvas_widget itemconfigure $wire($i) -fill $wire_color
			$canvas_widget itemconfigure $lever($keys(${i})${i}) -fill $wire_color
			$canvas_widget itemconfigure $wire_o($i) -outline $wire_color
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
				[array get keys]		\
				$radio_buttons			\
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

			# Restore keys configuration and states
			array set keys [lindex $state 4]
			set radio_buttons [lindex $state 5]
			if {[lindex $state 6] != {}} {
				set keep_win_on_top [lindex $state 6]
				if {$keep_win_on_top} {
					wm attributes $win -topmost 1
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

				# Adjust key apparence
				key_state_changed $i
			}

			# Adjust internal logic and the rest of PALE
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
		set ::${class_name}::menu_radio_buttons $radio_buttons
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
		$text_widget insert insert [mc "This tool consists of 8 switches.  Each of them can connect any port pin of the simulated uC to ground.  Connections with the uC are made with ComboBoxes on the bottom of the panel.  Panel configuration can be saved to a file with extension vhc, and can be loaded from that file later.  Wire colors are identical to colors used in graph representing IO ports.\n\n"]
		$text_widget insert insert [mc "Keypad can be configured in two ways:"]
		$text_widget tag add tag_bold {insert linestart}  {insert lineend}
		$text_widget insert insert [mc "\n   "]
		$text_widget insert insert [mc "1)"]
		$text_widget tag add tag_bold {insert linestart}  {insert lineend}
		$text_widget insert insert [mc " To allow key combinations\n      Menu -> Check \"Radio buttons\"\n   "]
		$text_widget insert insert [mc "2)"]
		$text_widget tag add tag_bold {insert linestart}  {insert lineend}
		$text_widget insert insert [mc " To not allow key combinations\n      Menu -> Uncheck \"Radio buttons\""]
	}

	## This method is called before panel window closure
	 # @return void
	public method close_window_special {} {
	}

	## Commit new on/off state
	 # @return void
	public method on_off_special {} {
		set state [$project pale_get_true_state]
		new_state state
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

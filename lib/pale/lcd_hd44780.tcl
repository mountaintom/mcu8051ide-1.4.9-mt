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

# --------------------------------------------------------------------------
# Thanks to Trevor Spiteri <trevor.spiteri@um.edu.mt> there are 2 bugs less:
#
# - [PATCH 1/2] Fix 4-bit instructions for HD44780
# - [PATCH 2/2] Start 2nd row at 0x40 not at 40 for HD44780
# --------------------------------------------------------------------------

# >>> File inclusion guard
if { ! [ info exists _LCD_HD44780_TCL ] } {
set _LCD_HD44780_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
#
# Simulator of LCD character display controlled by HD44780.
# --------------------------------------------------------------------------

class LcdHD44780 {
	inherit VirtualHWComponent

	public common COMPONENT_NAME	"LCD display"	;# Name of this component
	public common CLASS_NAME	"LcdHD44780"	;# Name of this class
	public common COMPONENT_ICON	{hd44780}	;# Icon for this panel (16x16)

	# Configuration menu
	public common CONFMENU {
		{cascade	"Set font"		0	"hd44780"	.set_rom_code		false 1 {
			{radiobutton	"ROM code A00"		{}
				::LcdHD44780::font_id		{0}
				"font_changed"		3	""}
			{radiobutton	"ROM code A02"		{}
				::LcdHD44780::font_id		{2}
				"font_changed"		3	""}
		}}
		{cascade	"Set character size"	0	"hd44780"	.set_char_size		false 1 {
			{radiobutton	"5 × 8"			{}
				::LcdHD44780::char_size		{0}
				"char_size_changed"	5	""}
			{radiobutton	"5 × 10"		{}
				::LcdHD44780::char_size		{1}
				"char_size_changed"	5	""}
		}}
		{separator}
		{checkbutton	"Disable delays"	{}	{::LcdHD44780::_no_delays}
			1 0 0	{no_delays_changed}
			""}
		{checkbutton	"Ignore errors"		{}	{::LcdHD44780::_ignore_errors}
			1 0 0	{ignore_errors_changed}
			""}
		{separator}
		{command	{Show HD44780 log}	{}	5	"show_log"	{bar5}
			"Display the log of events which are currently happening in the simulated HD44780 chip"}
		{command	{Show CGROM}		{}	5	"show_cgrom"	{kcmmemory}
			"Display content of HD44780 Character Generator ROM"}
		{command	{Show CGRAM}		{}	5	"show_cgram"	{kcmmemory}
			"Display content of HD44780 Character Generator RAM"}
		{command	{Show DDRAM}		{}	5	"show_ddram"	{kcmmemory}
			"Display content of HD44780 Display data RAM"}
		{separator}
		{command	{Reset HD44780}		{}	6	"reset_hd44780"	{rebuild}
			"Reinitialize the simulated HD44780, but do not affect DDRAM and CGRAM"}
		{command	{Clear DDRAM & CGRAM}	{}	6	"clear_xxRAM"	{editdelete}
			"Clear the entire Display Data RAM and Character Generator RAM"}
		{separator}
		{command	{Show help}		{}	5	"show_help 1"	{help}
			"Show brief help"}
		{separator}
		{command	{Save configuration}	{}	0	"save_as"	{filesave}
			"Save configuration into a file"}
		{command	{Load configuration}	{}	0	"load_from"	{fileopen}
			"Load configuration from a file"}
		{separator}
		{checkbutton	"Window always on top"	{}	{::LcdHD44780::menu_keep_win_on_top}
			1 0 0	{keep_win_on_top_changed}
			""}
	}

	# Font: Font to be used in the panel -- bold
	public common common_font	[font create			\
		-weight bold					\
		-size [expr {int(-10 * ($::font_size_factor > 1.2 ? 1.2 : $font_size_factor))}]	\
		-family {helvetica}				\
	]
	# Font: Font to be used in the panel -- bold, underline
	public common common_font_u	[font create			\
		-weight bold					\
		-size [expr {int(-10 * ($::font_size_factor > 1.2 ? 1.2 : $font_size_factor))}]	\
		-family {helvetica}				\
		-underline 1					\
	]

	public common ON_COLOR			{#000000}	;# RGB: Color for darken pixels
	public common OFF_COLOR		{#DDDDDD}	;# RGB: Color for blank pixels
	public common USER_DEF_COLOR		{#AAAAFF}	;# RGB: Color used in CGROM table for user defined characters

	# List: Names of IO signals of the simulated LCD display controller
	public common SIGNAL_NAMES		[list {RS} {R/W} {E} {D7} {D6} {D5} {D4} {D3} {D2} {D1} {D0}]

	# List: Keys for the array (status_led) of status LEDs
	public common STATUS_LEDS_NAMES	[list {B} {S} {D} {C} {N} {F} {ID}  {DL} {OMN} {BF}]

	# List: Labels displayed beside of the status LEDs
	public common STATUS_LEDS_TEXTS	[list {B} {S} {D} {C} {N} {F} {I/D} {DL} {OMN} {BF}]

	# List: Help texts for the labels of the status LEDs
	public common STATUS_LEDS_HELPTEXTS	[list					\
		[mc "Cursor blinking"]						\
		[mc "Accompanies display shift"]				\
		[mc "Display ON/OFF"]						\
		[mc "Cursor ON/OFF"]						\
		[mc "2 lines display / 1 line display"]				\
		[mc "5 × 10 dots / 5 × 8 dots"]					\
		[mc "Increment AC / Decrement AC"]				\
		[mc "8-bit data transfer / 4-bit data transfer"]		\
		[mc "One More Nibble to transfer / data transfer complete"]	\
		[mc "Internally operating / Instructions acceptable"]		\
	]
	public common MAX_LOG_LENGTH		100	;# Int: Maximum number of row in the log window
	public common CURSOR_BLINK_FREQUENCY	 3	;# Int: Frequency (in Hz) of cursor blinking

	# Values used by the configuration menu
	public common _no_delays		0	;# Bool: Disable delays (simulated execution times)
	public common _ignore_errors		0	;# Bool: Do not display special error message dialog in cases when an error occurs
	public common font_id			0	;# Int: Font ID to be used for addressing the CGROM
	public common char_size		0	;# Bool: Character height from the HW point of view, 0 == 5x8; 1==5x10

	# Load CGROM
	source "${::LIB_DIRNAME}/pale/hd44780_cgrom.tcl"

	private variable conf_color		{red}	;# Color: Selected color for LED's
	private variable keep_win_on_top 0	;# Bool: Toplevel window
	private variable connection_port		;# Array of Int: Index is key number, value is port number or {-}
	private variable connection_pin			;# Array of Int: Index is key number, value is bit number or {-}
	private variable enaged				;# Array of Bool: enaged(port_num,bit_num) --> Is connected to this device ?

	private variable ddram_hexeditor	{}	;# Object: Hexadecimal editor for editing content of DDRAM
	private variable cgram_hexeditor	{}	;# Object: Hexadecimal editor for editing content of CGRAM

	private variable ddram_window_params	{0 {}}	;# List: Parameters of DDRAM hex. editor window, format: {IS_VISIBLE GEOMETRY}
	private variable cgram_window_params	{0 {}}	;# List: Parameters of CGRAM hex. editor window, format: {IS_VISIBLE GEOMETRY}

	private variable display_width			;# Int: LCD dot matrix width in number of characters which it is able to display on one line
	private variable display_height			;# Int: LCD dot matrix height in number of text rows, it can be 1 one 2
	private variable win_minwidth			;# Int: Minimum allowed width of the main window of this LCD display simulator in number of pixels

	private variable input_error		0	;# Bool: I/O error has occurred
	private variable input_error_desc	{}	;# String: Description of the last I/O error

	private variable es_but_left_right		;# Widget: Button "Show/Hide right part of the window"
	private variable es_but_up_down			;# Widget: Button "Show/Hide bottom part of the window"
	private variable visible_lr		1	;# Bool: Is the right part of the window currently visible
	private variable visible_ud		1	;# Bool: Is the bottom part of the window currently visible

	private variable log_win_text		{}	;# Widget: Text widget fro the log of events
	private variable ignore_errors		0	;# Bool: Do not display special error message dialog in cases when an error occurs
	private variable time_mark		0	;# Int: Time mark pointing to this point of time according to the MCU simulator engine
	private variable log_time_mark		0	;# Int: Time mark used to separate events in the log which happened during the same evaluation iteration
	private variable no_delays		0	;# Bool: Disable delays (simulated execution times)
	private variable log_enabled		1	;# Bool: Logging of events enabled (slower simulation)
	private variable log_on_off_chbut		;# Widget: Checkbox for enabling and disabling the logging of events

	private variable disp_frame			;# Widget: The black frame around the LCD dot matrix
	private variable signal_label			;# Array of canvas objects: Labels above ComboBoxes for GPIO signal selection
	private variable lcd_pixel			;# Array of canvas objects: Segments of LCD dot matrix
	private variable cgram_pixel			;# Array of canvas objects: Same as lcd_pixel but for CGRAM
	private variable entrybox			;# Array of Widgets: Entryboxes showing HD44780 registers, key is name of the register diaplyed the CGRAM viewer
	private variable status_led			;# Array of Widgets: LEDs showing status of HD44780 flags like: S, F, D, B, etc.
	private variable inhibit_vcmd		1	;# Bool: Disable validation function for entryboxes like "IR:" or "AC:"

	private variable ddram				;# Array: Display Data RAM
	private variable cgram				;# List: Character Generator RAM, format: { 8× (char) { 8× (row) { 5× (column) {0|1} } } }
	private variable inst_reg			;# Int: Instruction register (IR) as specified in the HD44780 manual
	private variable data_reg			;# Int: Data register (DR) as specified in the HD44780 manual
	private variable time_of_completion	0	;# Int: Time (according to the MCU simulator engine) when the current operation will be finished
	private variable address_counter	0	;# Int: Address Counter (AC) as specified in the HD44780 manual, interval [0;0x7F]
	private variable address_counter_old	0	;# Int: The same as AC, but this one might contain an outdated information (incr./decr. delay)
	private variable cursor_address		0	;# Int: Current address (not position) of the cursor, interval [0;0x7F]
	private variable cursor_timer		{}	;# Timer: Timer for LCD cursor blinking
	private variable return_value		-1	;# Int: Result of an READ operation, this value is supposed to be send to the data bus
	private variable display_shift		0	;# Int: Current display shift, this value suppose to be added to the AC, interval [0;0x7F]
	private variable signal_E_prev		0	;# Bool: Signal Enable, value from the last VHW evaluation iteration before this one
	private variable signal_E		0	;# Bool: Signal Enable
	private variable signal_RS		0	;# Bool: Signal Register Select
	private variable signal_RW		0	;# Bool: Signal Read/Write
	private variable signal_D		0	;# int: Value taken from the data bus

	## Array of HD44780 configuration flags
	 # KEY		MEANING WHEN 0			MEANING WHEN 1
	 # ---  	------------			------------
	 # ID		0 == Decrement 			1 == Increment
	 # S		0 == (Normal) 			1 == Accompanies display shift
	 # D		0 == Display OFF 		1 == Display ON
	 # C		0 == Cursor OFF 		1 == Cursor ON
	 # B		0 == Cursor blinking OFF 	1 == Cursor blinking ON
	 # DL		0 == 4-bit data transfer 	1 == 8-bit data transfer
	 # N		0 == 1 line display 		1 == 2 lines display
	 # F		0 == 5 × 8 dots 		1 == 5 × 10 dots
	 # BF		0 == Instructions acceptable 	1 == Internally operating
	 # OMN		0 == Transfer completed 	1 == One More Nibble to transfer
	 # B_pre	backup for ``B'' used by method clear_cursor in order to ensure correct erase of the cursor
	 # F_pre	backup for ``F'' used by method clear_cursor in order to ensure correct erase of the cursor
	private variable diver_cfg

	private variable rom_code		0	;# Int: Font ID, this is used for addressing the CGROM
	private variable lcd_char_size		0	;# Bool: Character height from the HW point of view, 0 == 5x8; 1==5x10

	# ------------------------------------------------------------------
	# GUI RELATED FUNCTIONS AND SO ON
	# ------------------------------------------------------------------

	## Object constructor
	 # @parm Object _project - Project object
	constructor {_project} {
		# Set object variables identifing this component (see the base class)
		set component_name	$COMPONENT_NAME
		set class_name		$CLASS_NAME
		set component_icon	$COMPONENT_ICON

		# Reset the array of MCU GPIO lines engaged by this device, for internal purposes only
		for {set port 0} {$port < 5} {incr port} {
			for {set bit 0} {$bit < 8} {incr bit} {
				set enaged($port,$bit) 0
			}
		}

		# Initialize array of HD44780 configuration flags
		array set diver_cfg {
			ID	1	S	0	D	0
			C	0	B	0	DL	1
			N	0	F	0	BF	0
			OMN	0	B_pre	0	F_pre	0
		}

		# Set other object variables
		set project $_project

		# Inform PALE
		$project pale_register_input_device $this
		$project pale_set_modified
	}

	## Object destructor
	destructor {
		# Inform PALE
		$project pale_unregister_input_device $this

		# Dispose the timer for cursor blinking
		catch {
			after cancel $cursor_timer
		}

		# Destroy GUI
		if {[winfo exists $win]} {
			destroy $win
		}
	}

	## Value of configuration menu variable "keep_win_on_top" has been changed
	 # @return void
	public method keep_win_on_top_changed {} {
		set keep_win_on_top $LcdHD44780::menu_keep_win_on_top
		if {$keep_win_on_top} {
			wm attributes $win -topmost 1 -alpha 0.8
		} else {
			wm attributes $win -topmost 0 -alpha 1.0
		}
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
		for {set i 3} {$i < 11} {incr i} {
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
	 # @parm Int i - Connection wire number ({0..3} => Row; {4..7} => Column)
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
		set win [toplevel .lcd_display$count -class $component_name -bg ${::COMMON_BG_COLOR}]

		# Create the canvas widget which contains everything else visible in the window
		set canvas_widget [canvas $win.canvas	\
			-bg {#FFFFFF}			\
			-width 0 			\
			-height 0 			\
			-highlightthickness 0		\
		]

		# Draw LEDs showing status of HD44780 flags like: S, F, D, B, etc.
		draw_status_leds

		# Draw the LCD dot matrix
		draw_display

		# Create ComboBoxes for specifying the connections between this device and the MCU simulator
		draw_comboboxes 3 [expr {$display_height * 35 + 10}]

		# Draw CGRAM viewer/editor
		draw_cgram 400 [expr {$display_height * 35 + 38}]

		# Create the entryboxes showing the most important HD44780 registers in the panel above the CGRAM viewer
		draw_entyboxes 400 [expr {$display_height * 35 + 20}]

		# Create "ON/OFF" button
		create_on_off_button 5 [expr {$display_height * 35 + ($display_height == 1 ? 15 : 12)}]

		# Create configuration menu button
		create_configuration_menu_button 370 [expr {$display_height * 35 + 63}] ;#[expr {$display_height * 35 + 40}]

		# Create "Show/Hide" buttons
		create_enlarge_shirnk_buttons 370 [expr {$display_height * 35 + 13}]

		# Pack canvas
		pack $canvas_widget -fill both -expand 1

		# Set window parameters
		configure_win

		# Disable or enable the "Show/Hide" buttons according to configuration of the window
		disena_es_buttons
	}

	## Show or Hide the bottom part of the window
	 # @return void
	public method show_hide0 {} {
		# Hide
		if {$visible_ud} {
			set new_height [expr {$display_height * 35 + 38}]
			set image {_1downarrow}

			$canvas_widget move connections_configuration 0 100
			$canvas_widget move config_menu_button -330 -50
			$canvas_widget move show_hide_but -300 0
			$canvas_widget move right_bottom_panel 0 100

			if {$visible_lr} {
				show_hide1 1
				set visible_lr 1
			}

		# Show
		} else {
			set new_height [expr {$display_height * 35 + 102}]
			set image {_1uparrow}

			$canvas_widget move connections_configuration 0 -100
			$canvas_widget move config_menu_button 330 50
			$canvas_widget move show_hide_but 300 0
			$canvas_widget move right_bottom_panel 0 -100

			if {$visible_lr} {
				set visible_lr 0
				show_hide1
			}
		}

		# Set new window geometry
		set geometry [split [wm geometry $win] {=x+}]
		lset geometry 1 $new_height
		wm minsize $win 0 0
		wm geometry $win "=[lindex $geometry 0]x[lindex $geometry 1]+[lindex $geometry 2]+[lindex $geometry 3]"

		# Set other values
		set visible_ud [expr {!$visible_ud}]
		$es_but_up_down configure -image ::ICONS::16::$image
		update idletasks
	}

	## Show or Hide the right part of the window
	 # @parm Bool allow_even_smaller=0 - Allow the window to be even smaller than $win_minwidth, see the code for details
	 # @return void
	public method show_hide1 {{allow_even_smaller 0}} {
		# Hide
		if {$visible_lr} {
			if {$allow_even_smaller} {
				# Set window width just to contain the LCD dot matrix, CGRAM and so on can be omitted here
				set new_width [expr {8 + 23 * $display_width}]
				if {$display_height == 1} {
					incr new_width 123
				} else {
					incr new_width 73
				}
			} else {
				set new_width [expr {$win_minwidth - 226}]
			}
			set image {_1rightarrow}

		# Show
		} else {
			set new_width $win_minwidth
			set image {_1leftarrow}
		}

		# Set new window geometry
		set geometry [split [wm geometry $win] {=x+}]
		lset geometry 0 $new_width
		wm minsize $win 0 0
		wm geometry $win "=[lindex $geometry 0]x[lindex $geometry 1]+[lindex $geometry 2]+[lindex $geometry 3]"

		# Set other values
		set visible_lr [expr {!$visible_lr}]
		$es_but_left_right configure -image ::ICONS::16::$image

		update idletasks
	}

	## Disable or enable the "Show/Hide" buttons according to configuration of the window
	 # @return void
	private method disena_es_buttons {} {
		if {$display_width > 18} {
			$es_but_left_right configure -state disabled
		}
	}

	## Create "Show/Hide" buttons at the specified coordinates
	 # @parm Int x - X coordinate
	 # @parm Int y - Y coordinate
	 # @return void
	private method create_enlarge_shirnk_buttons {x y} {
		# Button "Show/Hide the bottom part"
		set but [ttk::button $canvas_widget.show_hide0	\
			-style FlatWhite.TButton		\
			-command [list $this show_hide0]	\
			-image ::ICONS::16::_1uparrow		\
		]
		setStatusTip -widget $but -text [mc "Show or hide the bottom part"]
		DynamicHelp::add $but -text [mc "Show or hide the bottom part"]
		$canvas_widget create window $x $y -window $but -anchor nw -tags show_hide_but
		bindtags $but [list $but TButton all .]
		set es_but_up_down $but

		# Button "Show/Hide the right part"
		set but [ttk::button $canvas_widget.show_hide1	\
			-style FlatWhite.TButton		\
			-command [list $this show_hide1]	\
			-image ::ICONS::16::_1leftarrow		\
		]
		setStatusTip -widget $but -text [mc "Show or hide the right part"]
		DynamicHelp::add $but -text [mc "Show or hide the right part"]
		$canvas_widget create window $x [expr {$y + 25}] -window $but -anchor nw
		bindtags $but [list $but TButton all .]
		set es_but_left_right $but
	}

	## Create "ON/OFF" button at the specified coordinates
	 # @parm Int x - X coordinate
	 # @parm Int y - Y coordinate
	 # @return void
	private method create_on_off_button {x y} {
		# Create "ON/OFF" button
		set start_stop_button [ttk::button $canvas_widget.start_stop_button	\
			-command [list $this on_off_button_press]			\
			-style Flat.TButton						\
			-width 3							\
		]
		DynamicHelp::add $start_stop_button	\
			-text [mc "Turn HW simulation on/off"]
		setStatusTip -widget $start_stop_button -text [mc "Turn HW simulation on/off"]
		bind $start_stop_button <Button-3> "$this on_off_button_press; break"
		$canvas_widget create window $x $y -window $start_stop_button -anchor nw
		bindtags $start_stop_button [list $start_stop_button TButton all .]
	}

	## Create menu button for the configuration menu at the specified coordinates
	 # @parm Int x - X coordinate
	 # @parm Int y - Y coordinate
	 # @return void
	private method create_configuration_menu_button {x y} {
		# Create configuration menu button
		set conf_button [ttk::button $canvas_widget.conf_but	\
			-image ::ICONS::16::configure			\
			-style FlatWhite.TButton			\
			-command [list $this config_menu]		\
		]
		setStatusTip -widget $conf_button -text [mc "Configure"]
		$canvas_widget create window $x $y -window $conf_button -anchor nw -tags config_menu_button
		bindtags $conf_button [list $conf_button TButton all .]
	}

	## Set main window parameters
	 # @return void
	private method configure_win {} {
		# Decide minum allowable window width
		set win_minwidth [expr {8 + 23 * $display_width}]
		if {$display_height == 1} {
			incr win_minwidth 123
		} {
			incr win_minwidth 73
		}
		if {$win_minwidth < 625} {
			set win_minwidth 625
		}

		# Set window parameters
		wm minsize $win $win_minwidth [expr {$display_height * 35 + 102}]
		wm iconphoto $win ::ICONS::16::$component_icon
		wm title $win "$display_height × $display_width [mc $component_name] - [$project cget -projectName] - MCU 8051 IDE"
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW [list $this close_window]
		bindtags $win [list $win Toplevel all .]
	}

	## Determinate which port pin is connected to the specified HD44780 wire
	 # @parm Int i - HD44780 signal, see SIGNAL_NAMES for the numbers of the signals
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

	## Create ComboBoxes for specifying the connections between this device and the MCU simulator
	 # @parm Int x_offset - X coordinate where this suppose to be drawn
	 # @parm Int y_offset - Y coordinate where this suppose to be drawn
	 # @return void
	private method draw_comboboxes {x_offset y_offset} {
		set cb_l_y [expr {$y_offset + 13}]
		set cb_p_y [expr {$y_offset + 33}]
		set cb_b_y [expr {$y_offset + 53}]
		set note_y [expr {$y_offset + 75}]

		# Print labels and the user note entrybox
		set x [expr {$x_offset + 30}]
		$canvas_widget create text $x $cb_p_y	\
			-tags connections_configuration	\
			-text [mc "PORT"]		\
			-font $common_font		\
			-anchor e
		$canvas_widget create text $x $cb_b_y	\
			-tags connections_configuration	\
			-text [mc "BIT"]		\
			-font $common_font		\
			-anchor e
		$canvas_widget create text $x $note_y	\
			-tags connections_configuration	\
			-text [mc "NOTE"]		\
			-font $common_font		\
			-anchor e
		incr x 5
		$canvas_widget create window $x $note_y			\
			-tags connections_configuration			\
			-window [ttk::entry $canvas_widget.usr_note	\
				-validate key				\
				-validatecommand "$this set_modified"	\
			]	\
			-width 325 -anchor w
		bindtags $canvas_widget.usr_note	\
			[list $canvas_widget.usr_note TEntry $win all .]

		# Create LES's and ComboBoxes
		for {set i 0} {$i < 11} {incr i} {
			# Label with name of the HD44780 pin
			set signal_label($i) [$canvas_widget create text	\
				[expr {$x + 12}] $cb_l_y			\
				-tags connections_configuration			\
				-text [lindex $SIGNAL_NAMES $i]			\
				-font $common_font				\
				-anchor center					\
				-fill {#000000}					\
			]

			# MCU port selection ComboBoxe
			$canvas_widget create window $x $cb_p_y			\
				-anchor w					\
				-tags connections_configuration			\
				-window [ttk::combobox $canvas_widget.cb_p$i	\
					-width 1				\
					-font $common_font			\
					-state readonly				\
				]
			bind $canvas_widget.cb_p$i <<ComboboxSelected>> "$this reconnect $i"

			# MCU port bit selection ComboBoxe
			$canvas_widget create window $x $cb_b_y			\
				-anchor w					\
				-tags connections_configuration			\
				-window [ttk::combobox $canvas_widget.cb_b$i	\
					-width 1				\
					-font $common_font			\
					-values {- 0 1 2 3 4 5 6 7}		\
					-state readonly				\
				]
			bind $canvas_widget.cb_b$i <<ComboboxSelected>> "$this reconnect $i"

			# Finalize ...
			bindtags $canvas_widget.cb_p$i	\
				[list $canvas_widget.cb_p$i TCombobox all .]
			bindtags $canvas_widget.cb_b$i	\
				[list $canvas_widget.cb_b$i TCombobox all .]

			incr x 30
		}
	}

	## Validator function for entryboxes with the most important HD44780 registers in the panel above the CGRAM viewer
	 # @parm String type	- Entryboxes purpose; watched HD44780 register
	 # @parm String content	- String to validate
	 # @return Bool - 1 == Passed; 0 == Incorrect input
	public method vcmd {type content} {
		if {$inhibit_vcmd} {
			set inhibit_vcmd 1
			return 1
		}

		# Allow empty strings
		if {![string length $content]} {
			set inhibit_vcmd 0
			return 1
		}

		# Allow only hexadecimal digits up to length of two
		if {![string is xdigit -strict $content] || [string length $content] > 2} {
			set inhibit_vcmd 0
			return 0
		}

		# Update the actual HD44780 register
		set dec_value [expr "0x$content"]
		switch -- $type {
			{IR} {	;# Instruction Register
				set inst_reg $dec_value
			}
			{DR} {	;# Data register
				set data_reg $dec_value
			}
			{AC} {	;# Address counter
				if {$dec_value > 0x7f} {
					return 0
				}
				set address_counter $dec_value
				set address_counter_old $dec_value
				refresh_display
			}
			{SHIFT} {	;# Display Shift
				if {$dec_value > 0x7f} {
					return 0
				}
				set display_shift $dec_value
				refresh_display
			}
		}

		# Successfully done
		set inhibit_vcmd 0
		return 1
	}

	## Update content of all entryboxes with the most important HD44780 registers in the panel above the CGRAM viewer
	 # @return void
	private method update_entry_boxes {} {
		set inhibit_vcmd 1

		# Instruction Register
		$entrybox(IR) delete 0 end
		$entrybox(IR) insert 0 [format {%02X} $inst_reg]

		# Data register
		$entrybox(DR) delete 0 end
		$entrybox(DR) insert 0 [format {%02X} $data_reg]

		# Address counter
		$entrybox(AC) delete 0 end
		$entrybox(AC) insert 0 [format {%02X} $address_counter]

		# Display Shift
		$entrybox(SHIFT) delete 0 end
		$entrybox(SHIFT) insert 0 [format {%02X} $display_shift]

		set inhibit_vcmd 0
	}

	## Create the entryboxes showing the most important HD44780 registers in the panel above the CGRAM viewer
	 # @parm Int x_offset - X coordinate where this suppose to be drawn
	 # @parm Int y_offset - Y coordinate where this suppose to be drawn
	 # @return void
	private method draw_entyboxes {x_offset y_offset} {
		set x $x_offset
		set y $y_offset

		incr x 15

		# Instruction Register
		$canvas_widget create text	\
			$x $y			\
			-text {IR:}		\
			-font $common_font	\
			-anchor e		\
			-tags right_bottom_panel
		incr x 5
		set entrybox(IR) [ttk::entry $canvas_widget.ir_ent	\
			-width 2					\
			-font $common_font				\
			-validate key					\
			-validatecommand [list $this vcmd {IR} {%P}]	\
		]
		$canvas_widget create window $x $y	\
			-window $entrybox(IR)		\
			-anchor w			\
			-tags right_bottom_panel
		incr x 50

		# Data register
		$canvas_widget create text	\
			$x $y			\
			-text {DR:}		\
			-font $common_font	\
			-anchor e		\
			-tags right_bottom_panel
		incr x 5

		set entrybox(DR) [ttk::entry $canvas_widget.dr_ent	\
			-width 2					\
			-font $common_font				\
			-validate key					\
			-validatecommand [list $this vcmd {DR} {%P}]	\
		]
		$canvas_widget create window $x $y	\
			-window $entrybox(DR)		\
			-anchor w			\
			-tags right_bottom_panel
		incr x 50

		# Address counter
		$canvas_widget create text	\
			$x $y			\
			-text {AC:}		\
			-font $common_font	\
			-anchor e		\
			-tags right_bottom_panel
		incr x 5
		set entrybox(AC) [ttk::entry $canvas_widget.ac_ent	\
			-width 2					\
			-font $common_font				\
			-validate key					\
			-validatecommand [list $this vcmd {AC} {%P}]	\
		]
		$canvas_widget create window $x $y	\
			-window $entrybox(AC)		\
			-anchor w			\
			-tags right_bottom_panel
		incr x 55

		# Display Shift
		$canvas_widget create text	\
			$x $y			\
			-text [mc "Shift:"]	\
			-font $common_font	\
			-anchor e		\
			-tags right_bottom_panel
		incr x 5
		set entrybox(SHIFT) [ttk::entry $canvas_widget.sh_ent	\
			-width 2					\
			-font $common_font				\
			-validate key					\
			-validatecommand [list $this vcmd {SHIFT} {%P}]	\
		]
		$canvas_widget create window $x $y	\
			-window $entrybox(SHIFT)	\
			-anchor w			\
			-tags right_bottom_panel

		# Configure binding tags
		foreach key [array names entrybox] {
			bindtags $entrybox($key) [list $entrybox($key) TEntry $win all .]
		}
	}

	## Draw CGRAM viewer/editor
	 # @parm Int x_offset - X coordinate where this suppose to be drawn
	 # @parm Int y_offset - Y coordinate where this suppose to be drawn
	 # @return void
	private method draw_cgram {x_offset y_offset} {
		$canvas_widget create text			\
			$x_offset [expr {$y_offset + 3}]	\
			-text {CGRAM:}				\
			-font $common_font			\
			-anchor w				\
			-tags right_bottom_panel
		incr y_offset 10

		set square_size 4
		set sep 1
		set sep2 3

		set x $x_offset
		set y [expr {$y_offset + 0}]
		for {set k 0} {$k < 8} {incr k} {

			for {set i 0} {$i < 8} {incr i} {
				for {set j 0} {$j < 5} {incr j} {
					set cgram_pixel($k,$j,$i) [$canvas_widget	\
						create rectangle $x $y			\
						[expr {$x + $square_size}]		\
						[expr {$y + $square_size}]		\
						-fill $OFF_COLOR			\
						-outline {#000000}			\
						-width 0
					]

					foreach event {Enter Leave Button-1} {
						$canvas_widget bind $cgram_pixel($k,$j,$i) <$event> \
							[list $this cgram_pixel_event $event $k $j $i]
					}

					incr x $square_size
					incr x $sep
				}
				incr x [expr {-5 * ($square_size + $sep)}]
				incr y [expr {$square_size + $sep}]
			}
			$canvas_widget create text [expr {$x + (5 * $square_size) / 2}] [expr {$y + 8}] -text $k -font $common_font

			incr x [expr {$sep2 + 5 * ($square_size + $sep)}]
			incr y [expr {-8 * ($square_size + $sep)}]
		}
	}

	## Handle events on CGRAM viewer character points
	 # @parm String event	- Event type (e.g. "Leave")
	 # @parm Int char	- Number of character where it occurred
	 # @parm Int col	- Column in the character
	 # @parm Int row	- Row in the character
	 # @return void
	public method cgram_pixel_event {event char col row} {
		switch -- $event {
			{Enter} { ;# Highlight the cell
				$canvas_widget itemconfigure $cgram_pixel($char,$col,$row) -width 1
			}
			{Leave} { ;# "Unhighlight" cell
				$canvas_widget itemconfigure $cgram_pixel($char,$col,$row) -width 0
			}
			{Button-1} {	;# Invert the cell and also adjust the CGRAM accordingly
				set value [lindex $cgram [list $char $row $col]]
				set value [expr {!$value}]

				lset cgram [list $char $row $col] $value

				if {$value} {
					$canvas_widget itemconfigure $cgram_pixel($char,$col,$row) -fill $ON_COLOR
				} else {
					$canvas_widget itemconfigure $cgram_pixel($char,$col,$row) -fill $OFF_COLOR
				}

				if {$cgram_hexeditor != {}} {
					set val 0
					for {set j 0} {$j < 5} {incr j} {
						set val [expr {$val | (([lindex $cgram [list $char $row $j]] ? 1 : 0) << $j)}]
					}

					set addr [expr {($char << 3) | $row}]
					$cgram_hexeditor setValue $addr $val
					$cgram_hexeditor setHighlighted $addr 1
				}
			}
		}
	}

	## Synchronize all of the status LEDs with current state of the HD44780 core
	 # @return void
	private method adjust_status_leds {} {
		foreach key $STATUS_LEDS_NAMES {
			if {$diver_cfg($key)} {
				set image {dot}
			} else {
				set image {dot_gray}
			}
			$canvas_widget itemconfigure $status_led($key) -image ::ICONS::16::$image
		}
	}

	## Invert the specified HD44780 configuration flag (e.g. F, S, D, B)
	 # This method suppose to be called from the status LEDs panel
	 # @parm String config_param_name - HD44780 flag, like B (Blink) or C (Cursor)
	 # @return void
	public method change_config {config_param_name} {
		set diver_cfg($config_param_name) [expr {$diver_cfg($config_param_name) ? 0 : 1}]
		refresh_display
		adjust_status_leds
	}

	## Draw LEDs showing status of HD44780 flags like: S, F, D, B, etc.
	 # @parm Int x_offset - X coordinate where this suppose to be drawn
	 # @parm Int y_offset - Y coordinate where this suppose to be drawn
	 # @return void
	private method draw_status_leds {{x_offset 6} {y_offset 5}} {
		# Determinate dimensions of matrix of status LEDs
		if {$display_height == 1} {
			set rows 3
			set cols 4
		} {
			set rows 5
			set cols 2
		}
		set items_total 10

		set k 0
		for {set i 0} {$i < $cols} {incr i} {
			for {set j 0} {$j < $rows} {incr j} {
				# Create the LED
				set status_led([lindex $STATUS_LEDS_NAMES $k]) \
					[$canvas_widget create image $x_offset $y_offset -anchor nw -image ::ICONS::16::dot_gray]

				# Create label for the LED
				set label [label $canvas_widget.status_lbl_${k}	\
					-text [lindex $STATUS_LEDS_TEXTS $k]	\
					-fg {#000000}				\
					-bg {#FFFFFF}				\
					-font $common_font			\
				]

				# Set event some handlers for the label widget in order to make it work
				#+ also as a button which changes value of the watched flag
				bind $label <Enter> {+
					%W configure		\
						-fg {#0000FF}	\
						-cursor hand2	\
						-font ${::LcdHD44780::common_font_u}
				}
				bind $label <Leave> {+
					%W configure			\
						-fg {#000000}		\
						-cursor left_ptr	\
						-font ${::LcdHD44780::common_font}
				}
				bind $label <Button-1> [list $this change_config [lindex $STATUS_LEDS_NAMES $k]]
				::DynamicHelp::add $label -text [lindex $STATUS_LEDS_HELPTEXTS $k]

				# Show the label widget
				$canvas_widget create window [expr {$x_offset + 10}] [expr {$y_offset - 3}]	\
					-anchor nw								\
					-window $label

				incr y_offset 14
				incr k

				if {$k >= $items_total} {
					break
				}
			}

			incr y_offset [expr {$rows * -14}]
			incr x_offset 25
		}
	}

	## Draw the LCD dot matrix
	 # @parm Int x_offset - X coordinate where this suppose to be drawn
	 # @parm Int y_offset - Y coordinate where this suppose to be drawn
	 # @return void
	private method draw_display {{x_offset 73} {y_offset 3}} {
		set square_size 3
		set sep 1
		set sep2 3

		if {$display_height == 1} {
			incr x_offset 50
		}

		set disp_frame [$canvas_widget create rectangle $x_offset $y_offset \
			[expr {$x_offset + $sep2 - $sep + $display_width * ($sep2 + 5 * ($square_size + $sep))}] \
			[expr {$y_offset + $sep2 - $sep + $display_height * ($sep2 + 8 * ($square_size + $sep)) + 2 * $lcd_char_size * ($square_size + $sep)}] \
			-outline {#000000} -width 1 \
		]

		incr x_offset $sep2
		incr y_offset $sep2

		set x $x_offset
		set y $y_offset
		for {set row 0} {$row < $display_height} {incr row} {
			for {set col 0} {$col < $display_width} {incr col} {
				for {set i 0} {$i < (8 + 2 * $lcd_char_size)} {incr i} {
					for {set j 0} {$j < 5} {incr j} {
						set lcd_pixel($col,$row,$j,$i) [$canvas_widget	\
							create rectangle $x $y		\
							[expr {$x + $square_size}]	\
							[expr {$y + $square_size}]	\
							-fill $OFF_COLOR		\
							-width 0
						]
						incr x $square_size
						incr x $sep
					}
					incr x [expr {-5 * ($square_size + $sep)}]
					incr y [expr {$square_size + $sep}]
				}
				incr x [expr {$sep2 + 5 * ($square_size + $sep)}]
				incr y [expr {(-8 - 2 * $lcd_char_size) * ($square_size + $sep)}]
			}
			set x $x_offset
			incr y [expr {$sep2 + (8 + 2 * $lcd_char_size) * ($square_size + $sep)}]
		}
	}

	## Create and show CGRAM hex. editor window
	 # @return void
	public method show_cgram {} {
		if {[winfo exists $win.cgram_window]} {
			raise $win.cgram_window
			return
		}

		# Create dialog window
		set dialog [toplevel $win.cgram_window -class {CGRAM (HD44780)} -bg ${::COMMON_BG_COLOR}]

		# Create bottom frame
		set bottom_frame [frame $dialog.bottom_frame]
		pack [ttk::button $bottom_frame.close_but		\
			-text [mc "Close"]				\
			-compound left					\
			-image ::ICONS::16::button_cancel		\
			-command [list $this close_cgram_window]	\
		] -side left -anchor w -padx 2 -pady 2
		set cursor_lbl [label $bottom_frame.cur_val			\
			-text {    } -fg {#0000FF}				\
			-font [font create					\
				-family $::DEFAULT_FIXED_FONT			\
				-size [expr {int(-12 * $::font_size_factor)}]	\
				-weight bold					\
			]							\
		]
		pack $cursor_lbl -side right -anchor e -padx 5
		pack [label $bottom_frame.cur_lbl	\
			-text [mc "Cursor: "]		\
		] -side right -anchor e

		# Create middle frame (hexeditor)
		set hexeditor_frame $dialog.hexeditor_frame
		set hexeditor [HexEditor #auto			\
			$hexeditor_frame 8 8 2 hex 1 0 3 64	\
		]
		set cgram_hexeditor $hexeditor
		$hexeditor showHideScrollbar 1
		$hexeditor bindCellValueChanged [list $this write_to_cgram_from_hex_editor]
		$hexeditor bindCellEnter [list $this show_address_in_hex_label $cursor_lbl]
		$hexeditor bindCellLeave [list $cursor_lbl configure -text {    }]
		for {set i 0} {$i < 64} {incr i} {
			set val 0
			set pattern [lindex $cgram [expr {$i / 8}] [expr {$i % 8}]]
			for {set j 0} {$j < 5} {incr j} {
				set val [expr {$val | (([lindex $pattern $j] ? 1 : 0) << $j)}]
			}
			$hexeditor setValue $i $val
		}
		$hexeditor focus_left_view

		pack $hexeditor_frame -fill both -expand 1
		pack $bottom_frame -side bottom -fill x

		# Configure dialog window
		wm iconphoto $dialog ::ICONS::16::kcmmemory
		wm title $dialog "CGRAM (HD44780) - [$::X::actualProject cget -projectName] - MCU 8051 IDE"
		wm resizable $dialog 0 1
		wm minsize $dialog 0 120
		wm protocol $dialog WM_DELETE_WINDOW [list $this close_cgram_window]
		if {[lindex $cgram_window_params 1] != {}} {
			wm geometry $dialog [lindex $cgram_window_params 1]
		}
	}

	## Write a value to CGRAM (suppose to be used as a callback for CGRAM hex. editor window)
	 # @parm Int address	- Address to CGRAM
	 # @parm Int data	- New value to store in CGRAM (character pattern fragment -- one row)
	public method write_to_cgram_from_hex_editor {address pattern} {
		set char	[expr {($address & 0x38) >> 3}]
		set row		[expr {$address & 0x07}]
		set pattern	[expr {$pattern & 0x1F}]

		write_to_cgram $char $row $pattern 1
	}

	## Close CGRAM hex. editor window if it is opened
	 # @return void
	public method close_cgram_window {} {
		if {$cgram_hexeditor == {}} {
			return
		}
		set cgram_window_params [list 0 [wm geometry $win.cgram_window]]
		destroy $win.cgram_window
		set cgram_hexeditor {}
	}

	## Create and show DDRAM hex. editor window
	 # @return void
	public method show_ddram {} {
		if {[winfo exists $win.ddram_window]} {
			raise $win.ddram_window
			return
		}

		# Create dialog window
		set dialog [toplevel $win.ddram_window -class {DDRAM (HD44780)} -bg ${::COMMON_BG_COLOR}]

		# Create bottom frame
		set bottom_frame [frame $dialog.bottom_frame]
		pack [ttk::button $bottom_frame.close_but		\
			-text [mc "Close"]				\
			-compound left					\
			-image ::ICONS::16::button_cancel		\
			-command [list $this close_ddram_window]	\
		] -side left -anchor w -padx 2 -pady 2
		set cursor_lbl [label $bottom_frame.cur_val			\
			-text {    } -fg {#0000FF}				\
			-font [font create					\
				-family $::DEFAULT_FIXED_FONT			\
				-size [expr {int(-12 * $::font_size_factor)}]	\
				-weight bold					\
			]							\
		]
		pack $cursor_lbl -side right -anchor e -padx 5
		pack [label $bottom_frame.cur_lbl	\
			-text [mc "Cursor: "]		\
		] -side right -anchor e

		# Create middle frame (hexeditor)
		set hexeditor_frame $dialog.hexeditor_frame
		set hexeditor [HexEditor #auto			\
			$hexeditor_frame 8 10 2 hex 1 0 3 0x80	\
		]
		set ddram_hexeditor $hexeditor
		$hexeditor showHideScrollbar 1
		$hexeditor bindCellValueChanged [list $this write_to_ddram_from_hex_editor]
		$hexeditor bindCellEnter [list $this show_address_in_hex_label $cursor_lbl]
		$hexeditor bindCellLeave [list $cursor_lbl configure -text {    }]
		for {set i 0} {$i < 0x80} {incr i} {
			$hexeditor setValue $i $ddram($i)
		}
		$hexeditor focus_left_view

		pack $hexeditor_frame -fill both -expand 1
		pack $bottom_frame -side bottom -fill x

		# Configure dialog window
		wm iconphoto $dialog ::ICONS::16::kcmmemory
		wm title $dialog "DDRAM (HD44780) - [$::X::actualProject cget -projectName] - MCU 8051 IDE"
		wm resizable $dialog 0 1
		wm minsize $dialog 0 120
		wm protocol $dialog WM_DELETE_WINDOW [list $this close_ddram_window]
		if {[lindex $ddram_window_params 1] != {}} {
			wm geometry $dialog [lindex $ddram_window_params 1]
		}
	}

	## Write a value to DDRAM (suppose to be used as a callback for DDRAM hex. editor window)
	 # @parm Int address	- Address to DDRAM
	 # @parm Int data	- New value to store in DDRAM
	 # @return void
	public method write_to_ddram_from_hex_editor {address data} {
		write_to_ddram $address $data 1
	}

	## Update cursor address label in xxRAM hex. editor window
	 # @parm Widget cursor_lbl	- Cursor address label to update
	 # @parm Int dec_address	- Decimal address to be shown in hexadecimal format
	 # @parm ...			- Any other arguments are discarded
	 # @return void
	public method show_address_in_hex_label {cursor_lbl dec_address args} {
		$cursor_lbl configure -text "0x[format {%02X} $dec_address]"
	}

	## Close DDRAM hex. editor window if it is opened
	 # @return void
	public method close_ddram_window {} {
		if {$ddram_hexeditor == {}} {
			return
		}
		set ddram_window_params [list 0 [wm geometry $win.ddram_window]]
		destroy $win.ddram_window
		set ddram_hexeditor {}
	}

	## Show Character Generator ROM, concrete table depends on variable $rom_code
	 # @return void
	public method show_cgrom {} {
		# Create the dialog window
		set dialog "${win}_cgrom_${rom_code}"
		if {[winfo exists $dialog]} {
			raise $dialog
			return
		}
		toplevel $dialog -class {HD44780 CGROM}
		set cgrom_canvas [canvas $dialog.canvas \
			-bg {#FFFFFF}			\
		]

		# Some parameters of the matrix where characters will be displayed
		set sep 1		;# LCD segment separator
		set sep2 1		;# Character column separator
		set sep3 13		;# Character row separator
		set square_size 3	;# LCD segment square size

		set header_x_offset 15	;# Position of the header
		set header_y_offset 15	;# Position of the header
		set matrix_x_offset 30	;# Position of the matrix
		set matrix_y_offset 30	;# Position of the matrix

		# Create horizontal header
		set x [expr {$matrix_x_offset + int(2.5 * ($square_size + $sep))}]
		set y $header_y_offset
		for {set i 0} {$i < 16} {incr i} {
			$cgrom_canvas create text $x $y -text "[format {%X} $i]_" -font $common_font -fill {#FF0000}
			incr x [expr {$sep3 + 5 * ($square_size + $sep)}]
		}

		# Create vertical header
		set x $header_x_offset
		set y [expr {$matrix_y_offset + 4 * ($square_size + $sep)}]
		for {set i 0} {$i < 16} {incr i} {
			$cgrom_canvas create text $x $y -text "_[format {%X} $i]" -font $common_font -fill {#FF0000}
			incr y [expr {$sep2 + 10 * ($square_size + $sep)}]
		}

		# Create the matrix of characters
		set x $matrix_x_offset
		set y $matrix_y_offset
		set char_code 0
		for {set row 0} {$row < 16} {incr row} {
			for {set col 0} {$col < 16} {incr col} {

				# Draw character
				set char_code [expr {16 * $col + $row}]
				for {set i 0} {$i < 10} {incr i} {
					for {set j 0} {$j < 5} {incr j} {
						if {$col < 14 && $i > 7} {
							set color {#FFFFFF}
						} elseif {$char_code < 16} {
							set color $USER_DEF_COLOR
						} elseif {[lindex $CGROM [list $rom_code [expr {$char_code - 16}] $i $j]]} {
							set color $ON_COLOR
						} else {
							set color $OFF_COLOR
						}

						$cgrom_canvas create rectangle $x $y	\
							[expr {$x + $square_size}]	\
							[expr {$y + $square_size}]	\
							-fill $color		\
							-width 0

						incr x $square_size
						incr x $sep
					}
					incr x [expr {-5 * ($square_size + $sep)}]
					incr y [expr {$square_size + $sep}]
				}
				incr x [expr {$sep3 + 5 * ($square_size + $sep)}]
				incr y [expr {-10 * ($square_size + $sep)}]

			}
			set x $matrix_x_offset
			incr y [expr {$sep2 + 10 * ($square_size + $sep)}]
		}

		pack $cgrom_canvas -fill both -expand 1

		# Set window parameters
		wm minsize $dialog 555 690
		wm iconphoto $dialog ::ICONS::16::kcmmemory
		wm title $dialog [mc "HD44780 Character Generator ROM (ROM Code: A0%d) - MCU 8051 IDE" ${rom_code}]
		wm resizable $dialog 0 0
		bindtags $dialog [list $dialog Toplevel $win all .]
	}

	## Show the log window
	 # The log window must have been once created by method create_log prior to
	 #+ the call to this method
	 # @return void
	public method show_log {} {
		set dialog $win.log_window
		if {[wm state $dialog] == {normal}} {
			raise $dialog
			return
		}
		if {![winfo exists $dialog]} {
			return
		}
		wm deiconify $dialog
		raise $dialog
	}

	## Create the log dialog window, but do not show it until method show_log is called
	 # @parm String geometry={} - Desired geometry of the window, {} means default geometry
	 # @return void
	public method create_log {{geometry {}}} {
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
		 # Button "Clear log"
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
		} {
			$log_on_off_chbut deselect
		}
		setStatusTip -widget $log_on_off_chbut -text [mc "Disabled logging may notably improve simulation speed"]
		DynamicHelp::add $log_on_off_chbut -text [mc "Disabled logging may notably improve simulation speed"]
		pack $log_on_off_chbut -side left -padx 5
		pack $bottom_frame -pady 2 -padx 5 -fill x

		# Set window parameters
		wm minsize $dialog [expr {int(300 * $::font_size_factor)}] [expr {int(150 * $::font_size_factor)}]
		wm iconphoto $dialog ::ICONS::16::bar5
		wm title $dialog [mc "HD44780 log - MCU 8051 IDE"]
		wm protocol $dialog WM_DELETE_WINDOW [list $this close_log_win]
		bindtags $dialog [list $dialog Toplevel $win all .]

		if {$geometry != {}} {
			wm geometry $dialog $geometry
		}
	}

	## Enable or disable logging of events
	 # @return void
	public method log_on_off {} {
		set log_enabled [expr {!$log_enabled}]

		# Set flag modified
		set_modified
	}

	## Close the HD44780 log window
	 # @return void
	public method close_log_win {} {
		set dialog $win.log_window
		if {![winfo exists $dialog]} {
			return
		}

		wm withdraw $dialog
	}

	## Informs the HD44780 simulator about change of _no_delays flag (used by configuration menu)
	 # @return void
	public method no_delays_changed {} {
		set no_delays ${::LcdHD44780::_no_delays}
	}

	## Informs the HD44780 simulator about change of _ignore_errors flag (used by configuration menu)
	 # @return void
	public method ignore_errors_changed {} {
		set ignore_errors ${::LcdHD44780::_ignore_errors}
	}

	## Informs the HD44780 simulator about change of character size (used by configuration menu)
	 # @return void
	public method char_size_changed {} {
		set lcd_char_size ${::LcdHD44780::char_size}
		if {$display_height == 2 && $lcd_char_size == 1} {
			set lcd_char_size 0
			return
		}
		accept_new_character_size
	}

	## Informs the HD44780 simulator about change of font (used by configuration menu)
	 # @return void
	public method font_changed {} {
		set rom_code ${::LcdHD44780::font_id}
		refresh_display
	}

	## Adapt the LCD dot matrix to a new character size value, that means create additional
	 #+ dots and get rid of some of the dots currently displayed
	 # @return void
	private method accept_new_character_size {} {
		if {$display_height == 2} {
			return
		}

		$canvas_widget delete $disp_frame
		foreach key [array names lcd_pixel] {
			$canvas_widget delete $lcd_pixel($key)
		}
		draw_display
		refresh_display
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

		# Show also a special erro message dialog if this is a case of an error and if it is allowed
		if {$type == {E} && !$ignore_errors} {
			if {[$project sim_run_in_progress]} {
				$project sim_run
			} elseif {[$project sim_anim_in_progress]} {
				$project sim_animate
			}
			tk_messageBox \
				-parent $win \
				-title [mc "HD44780 ERROR"] \
				-icon error \
				-type ok \
				-message $string
		}
	}

	# ------------------------------------------------------------------
	# HD44780 CORE FUNCTIONS
	# ------------------------------------------------------------------

	## HD44780 instruction: Clear Display
	 # Clears entire display and sets DDRAM address 0 in address counter.
	 # @return void
	private method inst_ClearDisplay {} {
		write_to_log I [mc "Received instruction: %s" "Clear Display"]
		if {[must_not_be_enaged]} {return}
		engage_core 1700

		set address_counter 0
		for {set i 0} {$i < 0x80} {incr i} {
			write_to_ddram $i 20
		}

		update_entry_boxes
	}

	## HD44780 instruction: Return Home
	 # Sets DDRAM address 0 in address counter. Also returns display from
	 #+ being shifted to original position. DDRAM contents remain unchanged.
	 # @return void
	private method inst_ReturnHome {} {
		write_to_log I [mc "Received instruction: %s" "Return Home"]
		if {[must_not_be_enaged]} {return}
		engage_core 1700

		set address_counter 0
		set display_shift 0

		update_entry_boxes
		refresh_display
	}

	## HD44780 instruction: Entry Mode Set
	 # Sets cursor move direction and specifies display shift. These
	 #+ operations are performed during data write and read.
	 # @return void
	private method inst_EntryModeSet {} {
		write_to_log I [mc "Received instruction: %s" "Entry Mode Set"]
		if {[must_not_be_enaged]} {return}
		engage_core 40

		set diver_cfg(ID) [expr {($inst_reg & 0x02) ? 1 : 0}]
		set diver_cfg(S)  [expr {($inst_reg & 0x01) ? 1 : 0}]

		write_to_log I "I/D = $diver_cfg(ID), S = $diver_cfg(S)"

		update_entry_boxes
		adjust_status_leds
		refresh_display
	}

	## HD44780 instruction: Display On Off Control
	 # Sets entire display (D) on/off, cursor on/off (C), and blinking of
	 #+ cursor position character (B).
	 # @return void
	private method inst_DisplayOnOffControl {} {
		write_to_log I [mc "Received instruction: %s" "Display On Off Control"]
		if {[must_not_be_enaged]} {return}
		engage_core 40

		set diver_cfg(D) [expr {($inst_reg & 0x04) ? 1 : 0}]
		set diver_cfg(C) [expr {($inst_reg & 0x02) ? 1 : 0}]
		set diver_cfg(B) [expr {($inst_reg & 0x01) ? 1 : 0}]

		write_to_log I "D = $diver_cfg(D), C = $diver_cfg(C), B = $diver_cfg(B)"

		update_entry_boxes
		adjust_status_leds
		refresh_display
	}

	## HD44780 instruction: Cursor Or Display Shift
	 # Sets entire display (D) on/off, cursor on/off (C), and blinking of
	 #+ cursor position character (B).
	 # @return void
	private method inst_CursorOrDisplayShift {} {

		write_to_log I [mc "Received instruction: %s" "Cursor Or Display Shift"]
		if {[must_not_be_enaged]} {return}
		engage_core 40

		set sc [expr {($inst_reg & 0x08) ? 1 : 0}]
		set rl [expr {($inst_reg & 0x04) ? 1 : 0}]

		write_to_log I "S/C = $sc, R/L = $rl"

		# Shift display
		if {$sc} {
			# Right
			if {$rl} {
				incr display_shift -1
			# Left
			} else {
				incr display_shift
			}
			set display_shift [expr {$display_shift % 0x80}]
		# Move cursor
		} else {
			set address_counter_old $address_counter
			# Right
			if {$rl} {
				incr address_counter
			# Left
			} else {
				incr address_counter -1
			}
			set address_counter [expr {$address_counter % 0x80}]
			move_cursor $address_counter
		}

		update_entry_boxes
		refresh_display
	}

	## HD44780 instruction: Function Set
	 # Sets interface data length (DL), number of display lines (N), and
	 #+ character font (F).
	 # @return void
	private method inst_FunctionSet {} {
		write_to_log I [mc "Received instruction: %s" "Function Set"]
		if {[must_not_be_enaged]} {return}
		engage_core 40

		set diver_cfg(DL) [expr {($inst_reg & 0x10) ? 1 : 0}]
		set diver_cfg(N)  [expr {($inst_reg & 0x08) ? 1 : 0}]
		set diver_cfg(F)  [expr {($inst_reg & 0x04) ? 1 : 0}]

		write_to_log I "DL = $diver_cfg(DL), N = $diver_cfg(N), F =$diver_cfg(F)"

		update_entry_boxes
		adjust_status_leds
		refresh_display
	}

	## HD44780 instruction: Set CGRAM Address
	 # Sets CGRAM address. CGRAM data is sent and received after this setting.
	 # @return void
	private method inst_SetCGRAMAddress {} {
		write_to_log I [mc "Received instruction: %s" "Set CGRAM Address"]
		if {[must_not_be_enaged]} {return}
		engage_core 40

		set address_counter [expr {0x3F & $inst_reg}]

		write_to_log I "ACG = $address_counter"

		update_entry_boxes
	}

	## HD44780 instruction: Set DDRAM Address
	 # Sets DDRAM address. DDRAM data is sent and received after this setting.
	 # @return void
	private method inst_SetDDRAMAddress {} {
		write_to_log I [mc "Received instruction: %s" "Set DDRAM Address"]
		if {[must_not_be_enaged]} {return}
		engage_core 40

		set address_counter [expr {0x7F & $inst_reg}]
		move_cursor $address_counter

		write_to_log I "ADD = $address_counter"

		update_entry_boxes
	}

	## HD44780 instruction: Read Busy Flag & Address
	 # Reads busy flag (BF) indicating internal operation is being performed
	 #+ and reads address counter contents.
	 # @return void
	private method inst_ReadBusyFlagAndAddress {} {
		write_to_log I [mc "Received instruction: %s" "Read Busy Flag & Address"]

		## Simulate address counter update delay (approx. 6 us)
		if {$diver_cfg(BF)} {
			set return_value [expr {(($diver_cfg(BF) ? 1 : 0) << 7) + ($address_counter_old & 0x7f)}]
			return
		} elseif {($time_of_completion + 6) > [lindex [$project get_run_statistics] 0]} {
			set return_value [expr {(($diver_cfg(BF) ? 1 : 0) << 7) + ($address_counter_old & 0x7f)}]
			return
		}

		set return_value [expr {(($diver_cfg(BF) ? 1 : 0) << 7) + ($address_counter & 0x7f)}]
	}

	## HD44780 instruction: Write Data To CG Or DDRAM
	 # Writes data into DDRAM or CGRAM.
	 # @return void
	private method inst_WriteDataToCGOrDDRAM {} {
		write_to_log I [mc "Received instruction: %s" "Write Data To CG Or DDRAM"]
		if {[must_not_be_enaged]} {return}
		engage_core 40

		# Write to the Display Data RAM (DDRAM)
		if {0x80 & $inst_reg} {
			write_to_ddram $address_counter $data_reg
		# Write to the Character Generator RAM (CGRAM)
		} elseif {0x40 & $inst_reg} {
			write_to_cgram [expr {($address_counter & 0xf8) >> 3}] [expr {$address_counter & 0x07}] $data_reg
		# Write to nowhere -- Error condition, abort
		} else {
			write_to_log E [mc "Neither \"Set DDRAM Address\" nor \"Set CGRAM Address\" instruction was issued prior to the write instruction"]
			return
		}

		# Perform automatic Address Counter (AC) update and display shift as described in the HD44780 manual
		set address_counter_old $address_counter
		if {$diver_cfg(ID)} {
			incr address_counter
			if {$diver_cfg(S)} {
				incr display_shift -1
			}
		} else {
			incr address_counter -1
			if {$diver_cfg(S)} {
				incr display_shift
			}
		}
		set address_counter [expr {$address_counter % 0x80}]
		set display_shift [expr {$display_shift % 0x80}]

		# Synchronize with the LCD cursor
		if {0x80 & $inst_reg} {
			move_cursor $address_counter
		}

		# Update entry boxes showing content of some HD44780 registers
		update_entry_boxes
	}

	## HD44780 instruction: Read Data From CG Or DDRAM
	 # Reads data from DDRAM or CGRAM.
	 # @return void
	private method inst_ReadDataFromCGOrDDRAM {} {
		write_to_log I [mc "Received instruction: %s" "Read Data From CG Or DDRAM"]
		if {[must_not_be_enaged]} {return}
		engage_core 40

		# Read from the Display Data RAM (DDRAM)
		if {0x80 & $inst_reg} {
			set return_value $ddram($address_counter)

		# Read from the Character Generator RAM (CGRAM)
		} elseif {0x40 & $inst_reg} {
			set return_value 0
			for {set i 4} {$i >= 0} {incr i -1} {
				set return_value [expr {$return_value | ([lindex $cgram \
					[expr {($address_counter & 0x38) >> 3}] \
					[expr {$address_counter & 0x07}] \
					[expr {4 - $i}]] << $i
				)}]
			}

		# Read from nowhere -- Error condition, abort
		} else {
			write_to_log E [mc "Neither \"Set DDRAM Address\" nor \"Set CGRAM Address\" instruction was issued prior to the read instruction"]
			return
		}

		# Perform automatic Address Counter (AC) update and display shift as described in the HD44780 manual
		set address_counter_old $address_counter
		if {$diver_cfg(ID)} {
			incr address_counter
			if {$diver_cfg(S)} {
				incr display_shift -1
			}
		} else {
			incr address_counter -1
			if {$diver_cfg(S)} {
				incr display_shift
			}
		}
		set address_counter [expr {$address_counter % 0x80}]
		set display_shift [expr {$display_shift % 0x80}]

		# Synchronize with the LCD cursor
		if {0x80 & $inst_reg} {
			move_cursor $address_counter
		}

		# Update entry boxes showing content of some HD44780 registers
		update_entry_boxes
	}

	## Raise an error message if the core is engaged by some operation
	 # @return Bool - 0 == Not egaged; 1 == Is engaged
	private method must_not_be_enaged {} {
		if {$diver_cfg(BF)} {
			if {$no_delays} {
				set diver_cfg(BF) 0
			} else {
				write_to_log W [mc "Controller is busy, unable to execute requested instruction."]
				return 1
			}
		} else {
			return 0
		}
	}

	## Simulate the execution time of an operation
	 # @parm int time_us - Time for how long the HD44780 will be engaged by the operation in micro-seconds
	 # @return void
	private method engage_core {time_us} {
		# Mention it in the log
		write_to_log I [mc "Commencing execution, this action will take %d micro-seonds to comply." $time_us]

		# Skip delay if the simulator has been configure this way
		if {$no_delays} {
			set time_us 0
			write_to_log I [mc "Skipping delay"]
		}

		# Set time when the execution will be completed (time is taken from the MCU simulator engine)
		set time_of_completion [lindex [$project get_run_statistics] 0]
		incr time_of_completion [expr {$time_us * 1000}]

		# Set the Busy Flag
		if {$no_delays} {
			set diver_cfg(BF) 0
		} else {
			set diver_cfg(BF) 1
		}

		# Synchronize with the status LEDs
		adjust_status_leds
	}

	## Reset the simulated HD44780 controller
	 # @return void
	public method reset_hd44780 {} {
		set inhibit_vcmd 1		;# Disable validation function for entryboxes like "IR:" or "AC:"

		# Fill the DDRAM with 0x20 (SPACE) characters
		clear_ddram

		# Reset some object variables containing LCD display configuration
		set display_shift	0 ;# Current display shift, this value suppose to be added to the AC
		set address_counter	0 ;# Address Counter (AC) as specified in the HD44780 manual
		set inst_reg		0 ;# Instruction register (IR) as specified in the HD44780 manual
		set data_reg		0 ;# Data register (DR) as specified in the HD44780 manual

		# Array of HD44780 configuration flags
		set diver_cfg(ID)	1 ;# 0 == Decrement 			; 1 == Increment
		set diver_cfg(S)	0 ;# 0 == (Normal) 			; 1 == Accompanies display shift
		set diver_cfg(D)	0 ;# 0 == Display OFF 			; 1 == Display ON
		set diver_cfg(C)	0 ;# 0 == Cursor OFF 			; 1 == Cursor ON
		set diver_cfg(B)	0 ;# 0 == Cursor blinking OFF 		; 1 == Cursor blinking ON
		set diver_cfg(DL)	1 ;# 0 == 4-bit data transfer 		; 1 == 8-bit data transfer
		set diver_cfg(N)	0 ;# 0 == 1 line display 		; 1 == 2 lines display
		set diver_cfg(F)	0 ;# 0 == 5 × 8 dots 			; 1 == 5 × 10 dots
		set diver_cfg(BF)	0 ;# 0 == Instructions acceptable 	; 1 == Internally operating
		set diver_cfg(OMN)	0 ;# 0 == Transfer completed 		; 1 == One More Nibble to transfer

		clear_display		;# Ensure that that the LCD dot matrix is clear
		clear_cursor		;# Make the LCD cursor disappear
		adjust_status_leds	;# Synchronize with the status LEDs (right from the LCD dot matrix)
		update_entry_boxes	;# Update entryboxes like "IR:" or "AC:"

		# Mention this in the log
		write_to_log I [mc "Device reset"]

		set inhibit_vcmd 0	;# Enable validation function for entryboxes like "IR:" or "AC:"
	}

	## Write octet into Display Data RAM (DDRAM)
	 # @parm Int address			- Address in DDRAM [0;7f]
	 # @parm Int char_code			- Octet to write
	 # @parm Bool do_not_affect_hexeditor=0	- Do not synchronize wit the DDRAM hex editor window
	 # @return void
	public method write_to_ddram {address char_code {do_not_affect_hexeditor 0}} {
		# Validate the given address
		if {$address > 0x7f} {
			write_to_log W [mc "DDRAM address is too high: %d" $address]
		}

		# Write to the actual DDRAM
		set ddram($address) $char_code

		# Synchronize the DDRAM hex editor window if it is allowed and possible
		if {$ddram_hexeditor != {} && !$do_not_affect_hexeditor} {
			$ddram_hexeditor setValue $address $char_code
			$ddram_hexeditor setHighlighted $address 1
		}

		# Determinate target position
		set position [address_to_position $address]

		# ABORT! if the target position is out of visible range
		if {![is_position_visible $position]} {

			return
		}

		## Convert position into row and column
		 # Two lines display
		if {$diver_cfg(N) && $display_height == 2 && $position >= 0x40} {
			set col [expr {$position - 0x40}]
			set row 1
		 # One line display
		} else {
			set col $position
			set row 0
		}

		## Get character bitmap image
		 # Access to CGRAM (Character Generator RAM)
		if {$char_code < 16} {
			set char_pattern [lindex $cgram $char_code]
		 # Access to CGROM (Character Generator ROM)
		} else {
			incr char_code -16
			set char_pattern [lindex $CGROM [list $rom_code $char_code]]
		}

		# Determinate actual character height
		if {$display_height == 1 && $diver_cfg(F)} {
			set max_char_row [expr {8 + 2 * $lcd_char_size}]
		} else {
			set max_char_row 8
		}

		## Adjust the LCD dot matrix
		 # Iterate over rows
		for {set y 0} {$y < $max_char_row} {incr y} {
			# Iterate over columns
			for {set x 0} {$x < 5} {incr x} {
				if {$diver_cfg(D) && [lindex $char_pattern [list $y $x]]} {
					set color $ON_COLOR
				} else {
					set color $OFF_COLOR
				}
				$canvas_widget itemconfigure $lcd_pixel($col,$row,$x,$y) -fill $color
			}
		}
	}

	## Write one row of character patter into the Character Generator RAM (CGRAM)
	 # @parm Int char_code			- Number of the user defined character [0;7]
	 # @parm Int row			- Row in the patter [0;7] (0 - top; 7 - bottom)
	 # @parm List data			- Pattern fragment in decimal representation (e.g. 0x15 means {1 0 1 0 1} or 0x03 means {0 0 1 1 1})
	 # @parm Bool do_not_affect_hexeditor=0	- Do not synchronize wit the CGRAM hex editor window
	 # @return void
	private method write_to_cgram {char_code row data {do_not_affect_hexeditor 0}} {

		# Validate input data
		if {$char_code > 7} {
			write_to_log W [mc "CGRAM address is too high: %d" $char_code]
		}
		if {$data > 31} {
			write_to_log W [mc "Value is too high: 0x%X" $data]
			set data [expr {$data & 0x1f}]
		}
		set char_code [expr {$char_code % 8}]

		# Convert the given pattern fragment to this format:
		#+ {B B B B B}, where B is 0 or 1, 0 == blank dot, 1 == black dot
		set char_pattern [list]
		for {set i 4} {$i >= 0} {incr i -1} {
			lappend char_pattern [expr {($data & (1 << $i)) ? 1 : 0}]
		}

		# Write to the CGRAM
		lset cgram [list $char_code $row] $char_pattern

		# Synchronize the CGRAM viewer
		for {set col 0} {$col < 5} {incr col} {
			if {[lindex $char_pattern $col]} {
				set color $ON_COLOR
			} else {
				set color $OFF_COLOR
			}
			$canvas_widget itemconfigure $cgram_pixel($char_code,$col,$row) -fill $color
		}

		# Synchronize the CGRAM hex editor window if it is allowed and possible
		if {$cgram_hexeditor != {} && !$do_not_affect_hexeditor} {
			set addr [expr {($char_code << 3) | $row}]
			$cgram_hexeditor setValue $addr $data
			$cgram_hexeditor setHighlighted $addr 1
		}
	}

	## Fill the entire Character Generator RAM (CGRAM) with zeros
	 # @return void
	private method clear_cgram {} {
		# Dispose the CGRAM memory
		set cgram [list]

		# Generate an empty character pattern
		set char [list]
		for {set i 0} {$i < 8} {incr i} {
			lappend char [list 0 0 0 0 0]
		}

		# Refill the CGRAM memory
		for {set i 0} {$i < 16} {incr i} {
			lappend cgram $char
		}

		# Synchronize the CGRAM viewer
		if {$canvas_widget != {}} {
			for {set i 0} {$i < 8} {incr i} {
				for {set y 0} {$y < 8} {incr y} {
					for {set x 0} {$x < 5} {incr x} {
						$canvas_widget itemconfigure $cgram_pixel($i,$x,$y) -fill $OFF_COLOR
					}
				}
			}
		}

		# Synchronize the CGRAM hex editor window if possible
		if {$cgram_hexeditor != {}} {
			for {set i 0} {$i < 64} {incr i} {
				$cgram_hexeditor setValue $i 0
			}
		}
	}

	## Fill the entire Display Data RAM (DDRAM) with 0x20 characters (SPACE), but do not refresh the display
	 # @return void
	private method clear_ddram {} {
		# Fill the DDRAM
		for {set i 0} {$i < 0x80} {incr i} {
			set ddram($i) 32	;# 0x20 (SPACE) character
		}

		# Synchronize the DDRAM hex editor window is possible
		if {$ddram_hexeditor != {}} {
			for {set i 0} {$i < 0x80} {incr i} {
				$ddram_hexeditor setValue $i $ddram($i)
			}
		}
	}

	## Clear the entire Display Data RAM and Character Generator RAM
	 # @return void
	public method clear_xxRAM {} {
		clear_ddram
		clear_cgram
		refresh_display
	}

	## Determinate whether the specified position is visible or not
	 # @parm Int position - Position address [0,7f]
	 # @return Bool - 1 == Visible; 0 == Not visible
	private method is_position_visible {position} {
		if {$position < 0} {
			return 0
		}

		if {$position >= 0x80} {
			return 0
		}

		if {$position >= $display_width} {
			if {$display_height == 1} {
				return 0
			} else {
				if {!$diver_cfg(N)} {
					return 0
				} elseif {$position < 0x40 || $position >= ($display_width + 0x40)} {
					return 0
				}
			}
		}

		return 1
	}

	## Refresh display according to the DDRAM content and (new) HD44780 configuration
	 # @return void
	private method refresh_display {} {
		for {set i 0} {$i < 0x80} {incr i} {
			write_to_ddram $i $ddram($i) 1
		}
		move_cursor $address_counter
	}

	## Ensure that that the LCD dot matrix is clear
	 # @return void
	private method clear_display {} {
		for {set row 0} {$row < $display_height} {incr row} {
			for {set col 0} {$col < $display_width} {incr col} {
				for {set i 0} {$i < (8 + 2 * $lcd_char_size)} {incr i} {
					for {set j 0} {$j < 5} {incr j} {
						$canvas_widget itemconfigure $lcd_pixel($col,$row,$j,$i) -fill $OFF_COLOR
					}
				}
			}
		}
	}


	## Make the LCD cursor disappear
	 # @return void
	private method clear_cursor {} {
		# Determinate target position
		set position [address_to_position $cursor_address]

		# ABORT! if the target position is out of visible range
		if {![is_position_visible $position]} {
			return
		}

		## Convert position into row and column
		 # Two lines display
		if {$diver_cfg(N) && $display_height == 2 && $position >= 0x40} {
			set col [expr {$position - 0x40}]
			set row 1
		 # One line display
		} else {
			set col $position
			set row 0
		}

		# Blinking cursor
		if {$diver_cfg(B_pre)} {
			if {$cursor_timer != {}} {
				after cancel $cursor_timer
				set cursor_timer {}
			}

			# Overwrite the cursor with actual character at its position
			write_to_ddram $cursor_address $ddram($cursor_address) 1

		#  Normal cursor
		} else {
			if {$diver_cfg(F_pre)} {
				if {$lcd_char_size} {
					set max_char_row 9
				} {
					set max_char_row -1
				}
			} else {
				set max_char_row 7
			}
			if {$max_char_row != -1} {
				for {set x 0} {$x < 5} {incr x} {
					$canvas_widget itemconfigure $lcd_pixel($col,$row,$x,$max_char_row) -fill $OFF_COLOR
				}
			}
		}
	}

	## Draw LCD cursor according to current HD44780 settings and at position given by variable $cursor_address
	 # @return void
	private method draw_cursor {} {
		# Cursor is disabled -- abort
		if {!$diver_cfg(C)} {
			return
		}

		# Determinate target position
		set position [address_to_position $cursor_address]

		# Abort if the target position is out of visible range
		if {![is_position_visible $position]} {
			return
		}

		## Convert position into row and column
		 # Two lines display
		if {$diver_cfg(N) && $display_height == 2 && $position >= 0x40} {
			set col [expr {$position - 0x40}]
			set row 1
		 # One line display
		} else {
			set col $position
			set row 0
		}

		# Cursor appearance is affected also by the font size
		if {$diver_cfg(F)} {
			if {$lcd_char_size} {
				set max_char_row 10
			} else {
				set max_char_row -1
			}
		} {
			set max_char_row 8
		}

		set diver_cfg(B_pre) $diver_cfg(B)
		set diver_cfg(F_pre) $diver_cfg(F)

		# Draw blinking cursor
		if {$diver_cfg(B)} {
			# Stop the LCD cursor blinking timer
			if {$cursor_timer != {}} {
				after cancel $cursor_timer
			}
			# Normalize number of rows of the cursor rectangle
			if {$max_char_row == -1} {
				set max_char_row 8
			}
			# Draw the black cursor rectangle
			for {set y 0} {$y < $max_char_row} {incr y} {
				for {set x 0} {$x < 5} {incr x} {
					$canvas_widget itemconfigure $lcd_pixel($col,$row,$x,$y) -fill $ON_COLOR
				}
			}
			# Start the LCD cursor blinking timer
			set cursor_timer [after [expr {int(1000 / $CURSOR_BLINK_FREQUENCY)}] [list $this cursor_timer_callback 1]]

		# Draw normal cursor (a sort of underscore)
		} else {
			if {$max_char_row != -1} {
				incr max_char_row -1
				for {set x 0} {$x < 5} {incr x} {
					$canvas_widget itemconfigure $lcd_pixel($col,$row,$x,$max_char_row) -fill $ON_COLOR
				}
			}
		}
	}

	## Move the LCD cursor to a new location
	 # @parm Int new_address - Address in DDRAM
	 # @return void
	 #
	 # Note: This function could be also used to refresh the cursor
	private method move_cursor {new_address} {
		clear_cursor
		set cursor_address $new_address
		draw_cursor
	}

	## Callback function fo the LCD cursor blinking timer
	 # @parm Bool clear - 1 == Clear the cursor rectangle; 0 == Draw the cursor rectangle
	 # @return void
	public method cursor_timer_callback {clear} {
		if {$clear} {
			clear_cursor

			# Reset the LCD cursor blinking timer
			if {$diver_cfg(B) && $diver_cfg(C)} {
				set cursor_timer [after [expr {int(1000 / $CURSOR_BLINK_FREQUENCY)}] [list $this cursor_timer_callback 0]]
			}

		} elseif {$diver_cfg(B) && $diver_cfg(C)} {
			draw_cursor
		}
	}

	## Convert the specified DDRAM address into position in the LCD dot matrix
	 # @parm int ddram_address - Address to convert, must be be in interval [0;7f]!
	 # @return Int - The position [0;7f]
	private method address_to_position {ddram_address} {
		# Two lines display
		if {$diver_cfg(N)} {
			set position [expr {($ddram_address + $display_shift) % 0x40}]
			if {$ddram_address >= 0x40} {
				incr position 0x40
			}

		# One line display
		} else {
			set position [expr {($ddram_address + $display_shift) % 0x80}]
		}

		return $position
	}

	## Start execution of the requested instruction
	 # @see new_state
	 # @parm List state	- Port states ( 5 x {8 x bit} -- {bit0 bit1 bit2 ... bit7} )
	 # @return state	- New port states modified by this device
	 # 			  format is the same as parameter $state
	private method commence_operations {_state} {
		upvar $_state state

		# Detect falling edge on signal E (Enable) & Completed data transfer (in case of 4-bit mode)
		#+ --> Input instruction or data
		if {$signal_E_prev && !$signal_E && !$diver_cfg(OMN)} {
			# Manage Busy Flag
			if {$diver_cfg(BF)} {
				# Simulated execution times are disabled
				if {$no_delays} {
					# Clear the Busy Flag unconditionally
					set diver_cfg(BF) 0
					adjust_status_leds
					write_to_log I [mc "Operation finished"]

				# Simulated execution times are enabled
				} else {
					# Clear the Busy Flag if the execution time already passed
					set current_time [$project get_run_statistics 0]
					if {$current_time >= $time_of_completion} {
						set diver_cfg(BF) 0
						adjust_status_leds
						write_to_log I [mc "Operation finished"]
					}
				}
			}

			# Write to log the last I/O error if there is one
			if {$input_error} {
				write_to_log E [mc "Input is corrupted: %s" $input_error_desc]
			}

			# Input an "regular" instruction (write to the IR)
			if {!$signal_RS && !$signal_RW} {
				set return_value -1

				# Update the IR (Instruction Register)
				set inst_reg $signal_D
				update_entry_boxes

				# Instruction: Set DDRAM Address (1 ADD ADD ADD | ADD ADD ADD ADD)
				if {0x80 & $signal_D} {
					inst_SetDDRAMAddress

				# Instruction: Set CGRAM Address (0 1 ACG ACG | ACG ACG ACG ACG)
				} elseif {0x40 & $signal_D} {
					inst_SetCGRAMAddress

				# Instruction: Function Set (0 0 1 DL | N F - -)
				} elseif {0x20 & $signal_D} {
					inst_FunctionSet

				# Instruction: Cursor Or Display Shift (0 0 0 1 | S/C R/L - -)
				} elseif {0x10 & $signal_D} {
					inst_CursorOrDisplayShift

				# Instruction: Display On Off Control (0 0 0 0 | 1 D C B)
				} elseif {0x08 & $signal_D} {
					inst_DisplayOnOffControl

				# Instruction: Entry Mode Set (0 0 0 0 | 0 1 I/D S)
				} elseif {0x04 & $signal_D} {
					inst_EntryModeSet

				# Instruction: Return Home (0 0 0 0 | 0 0 1 -)
				} elseif {0x02 & $signal_D} {
					inst_ReturnHome

				# Instruction: Clear Display (0 0 0 0 | 0 0 0 1)
				} elseif {0x01 & $signal_D} {
					inst_ClearDisplay

				# Code 0 -- Invalid instruction
				} else {
					write_to_log W [mc "Invalid instruction: %2Xh" $signal_D]
				}

			# Read Busy Flag And Address
			} elseif {!$signal_RS && $signal_RW} {
				set data_reg $signal_D
				update_entry_boxes
				inst_ReadBusyFlagAndAddress

			# Write Data To CG Or DDRAM
			} elseif {$signal_RS && !$signal_RW} {
				set return_value -1

				set data_reg $signal_D
				update_entry_boxes
				inst_WriteDataToCGOrDDRAM

			# Read Data From CG Or DDRAM
			} elseif {$signal_RS && $signal_RW} {
				set data_reg $signal_D
				update_entry_boxes
				inst_ReadDataFromCGOrDDRAM
			}
		}

		# Detect signal Enable & Read request & Ready state (not busy) & Data waiting to be send ($return_value)
		#+ --> Output data
		if {$signal_E && $signal_RW && !$diver_cfg(BF) && $return_value != -1} {

			# 8-bit transfer mode
			if {$diver_cfg(DL)} {
				for {set i 3} {$i < 11} {incr i} {
					set pp [which_port_pin $i]
					if {[lindex $pp 0] != {-} && [lindex $pp 1] != {-}} {
						lset state $pp [expr {($return_value & (1 << (10 - $i))) ? 1 : 0}]
					}
				}

			# 4-bit transfer mode
			} else {
				if {$diver_cfg(OMN)} {
					set bus_offset 10
				} else {
					set bus_offset 14
				}
				for {set i 7} {$i < 11} {incr i} {
					set pp [which_port_pin $i]
					if {[lindex $pp 0] != {-} && [lindex $pp 1] != {-}} {
						lset state $pp [expr {($return_value & (1 << ($bus_offset - $i))) ? 1 : 0}]
					}
				}

				# Invert flag "One More Nibble"
				set diver_cfg(OMN) [expr {$diver_cfg(OMN) ? 0 : 1}]
				adjust_status_leds
			}
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

		# Configure the ComboBoxes
		for {set i 0} {$i < 11} {incr i} {
			$canvas_widget.cb_p$i configure -values $available_ports

			if {[lsearch -ascii -exact $available_ports $connection_port($i)] == -1} {
				$canvas_widget.cb_p$i current 0
				set connection_port($i) {-}
			}
		}
	}

	## Accept new state of ports
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

		# Start execution of the last requested instruction. It's done this way in order to cope with
		#+ multiple new_state invocations during the Virtual HW evaluation loop
		if {$time_mark != [$project get_run_statistics 2]} {
			commence_operations state
			set time_mark [$project get_run_statistics 2]
			set signal_E_prev $signal_E
		}

		# Reset last I/O error
		set input_error 0
		set input_error_desc {}

		# Iterate over all I/O lines
		for {set i 0} {$i < 11} {incr i} {
			# Determinate index in the list of port states
			set pp [which_port_pin $i]

			# Not connected
			if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
				$canvas_widget itemconfigure $signal_label($i) -fill {#000000}
				set signal_value {}
			} else {
				set signal_value [lindex $state $pp]
			}

			# Determinate the color for the PIN label
			switch -- $signal_value {
				{0} {	;# Logical 0
					set label_color {#00FF00}
				}
				{1} {	;# Logical 1
					set label_color {#FF0000}
				}
				{=} {	;# High forced to low
					set label_color {#00FF00}
				}
				{?} {	;# No volatge
					set label_color {#888888}
				}
				{} {	;# Not connected
					set label_color {#000000}
				}
				default {
					set label_color {#FF8800}
				}
			}

			# Change color of the PIN label
			$canvas_widget itemconfigure $signal_label($i) -fill $label_color

			# Convert any possible I/O signal value to Boolean value
			switch -- $signal_value {
				{0} -
				{1} {}
				{=} {
					set signal_value 0
				}
				default {
# 					if {$diver_cfg(DL) || $i >= 7} {
						set input_error 1
						set input_error_desc [mc \
							"Received an invalid input on signal %s" \
							[lindex $SIGNAL_NAMES $i]
						]
						set signal_value [expr {rand() > 0.5 ? 1 : 0}]
# 					}
				}
			}

			# Process the input
			switch -- $i {
				{0} {
					# Signal Register Select
					set signal_RS $signal_value
				}
				{1} {
					# Signal Read/Write
					set signal_RW $signal_value
				}
				{2} {
					# Signal Enable
					set signal_E $signal_value
				}
				{3} -
				{4} -
				{5} -
				{6} -
				{7} -
				{8} -
				{9} -
				{10} {	;# 8-bit data bus

					# Set received data to zero when the first bit is received
					if {$i == 3 && !$diver_cfg(OMN)} {
						set signal_D 0
					}

					# 8-bit transfer mode
					if {$diver_cfg(DL) && !$signal_RW} {
						set signal_D [expr {$signal_D | ($signal_value << (10 - $i))}]

					# 4-bit transfer mode -- accept data on rising edge of signal E (Enable) from DB4..DB7
					} elseif {!$signal_RW && $signal_E_prev && !$signal_E && $i < 7} {
						if {$diver_cfg(OMN)} {
							set signal_D [expr {$signal_D | ($signal_value << (6 - $i))}]
						} else {
							set signal_D [expr {$signal_D | ($signal_value << (10 - $i))}]
						}

						if {$i == 6} {
							if {$diver_cfg(OMN)} {
								set diver_cfg(OMN) 0
								write_to_log I [mc "Receiving the Less Significant Nibble (%02Xh)" [expr {$signal_D & 0x0F}]]
							} else {
								set diver_cfg(OMN) 1
								write_to_log I [mc "Receiving the More Significant Nibble (%02Xh)" [expr {$signal_D & 0xF0}]]
							}
							adjust_status_leds
						}
					}
				}
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
		# Get DDRAM hex editor windows parameters is it's visible
		if {$ddram_hexeditor != {}} {
			set ddram_window_params [list 1 [wm geometry $win.ddram_window]]
		}
		# Get CGRAM hex editor windows parameters is it's visible
		if {$cgram_hexeditor != {}} {
			set cgram_window_params [list 1 [wm geometry $win.cgram_window]]
		}

		# Formulate the result
		return [list		\
			$class_name	\
			[list		\
				$display_height			\
				$display_width			\
				[wm geometry $win]		\
				[array get connection_port]	\
				[array get connection_pin]	\
				[$canvas_widget.usr_note get]	\
				$visible_lr			\
				$visible_ud			\
				$rom_code			\
				$lcd_char_size			\
				$ignore_errors			\
				$no_delays			\
				[wm geometry $win.log_window]	\
				[wm state $win.log_window]	\
				$ddram_window_params		\
				$cgram_window_params		\
				$log_enabled			\
				$keep_win_on_top		\
			] \
		]
	}

	## Set panel configuration from list gained from method "get_config"
	 # @parm List state - Configuration list
	 # @return void
	public method set_config {state} {
		if {[catch {
			# Determinate whether we are re-configuring already operating
			#+ HD44780 simulator or creating a new one from scratch
			set new_instance	[expr {![winfo exists $win]}]

			# Set display width (number of columns) and height (number of rows)
			if {$new_instance} {
				set display_height	[lindex $state 0]
				set display_width	[lindex $state 1]
			}

			# Load connections to the MCU (port numbers)
			if {[llength [lindex $state 3]]} {
				array set connection_port [lindex $state 3]
			} else {
				array set connection_port {0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 - 9 - 10 -}
			}

			# Load connections to the MCU (port pin numbers)
			if {[llength [lindex $state 4]]} {
				array set connection_pin [lindex $state 4]
			} else {
				array set connection_pin {0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 - 9 - 10 -}
			}

			# Set flags: "Right part visible" and "Bottom part visible"
			if {[string length [lindex $state 6]]} {
				set visible_lr	[lindex $state 6]
			}
			if {[string length [lindex $state 7]]} {
				set visible_ud	[lindex $state 7]
			}

			# Set font to use (specification of character patterns not their size)
			if {[string length [lindex $state 8]]} {
				set rom_code [lindex $state 8]
			}

			# Set font size to use (could be 5×8 or 5×10)
			if {[string length [lindex $state 9]]} {
				set lcd_char_size [lindex $state 9]

				# Validate value of character size parameter
				if {$display_height == 2 && $lcd_char_size == 1} {
					set lcd_char_size 0
				}
			}

			# Flags: "Ignore errors" and "Disable delays"
			if {[string length [lindex $state 10]]} {
				set ignore_errors [lindex $state 10]
			}
			if {[string length [lindex $state 11]]} {
				set no_delays [lindex $state 11]
			}

			# Log window parameters
			set log_window_geometry [lindex $state 12]
			set log_window_state [lindex $state 13]

			# DDRAM and CGRAM hex editor windows parameters
			if {[string length [lindex $state 14]]} {
				set ddram_window_params [lindex $state 14]
			}
			if {[string length [lindex $state 15]]} {
				set cgram_window_params [lindex $state 15]
			}

			# Enable or disable logging of events
			if {[string length [lindex $state 16]]} {
				set log_enabled [lindex $state 16]
			}

			if {[lindex $state 17] != {}} {
				set keep_win_on_top [lindex $state 17]
			}

		# Fail
		}]} then {
			puts stderr "Unable to load configuration for $class_name"
			return 0

		# Success
		} else {
			if {$new_instance} {
				# Create panel GUI
				create_gui
				create_log $log_window_geometry
				reset_hd44780
				mcu_changed

				if {$keep_win_on_top} {
					wm attributes $win -topmost 1
				}

				# Display the log window
				if {$log_window_state == {normal}} {
					show_log
				}

				# Initialize HD44780 simulator
				clear_cgram
				on_off [$project pale_is_enabled]
			}

			# Restore window geometry
			if {[string length [lindex $state 2]]} {
				wm geometry $win [regsub {^\=?\d+x\d+} [lindex $state 2] [regsub {\+\d+\+\d+} [wm geometry $win] {}]]
			}

			# Load user note
			if {[string length [lindex $state 5]]} {
				$canvas_widget.usr_note delete 0
				$canvas_widget.usr_note insert 0 [lindex $state 5]
			}

			# Hide some parts of the window accordingly to the settings
			if {!$visible_lr} {
				set visible_lr 1
				show_hide1
			}
			if {!$visible_ud} {
				set visible_ud 1
				show_hide0
			}

			# Adjust log enable/disable checkbox
			if {$log_enabled} {
				$log_on_off_chbut select
			} else {
				$log_on_off_chbut deselect
			}

			# Restore/Set state of ComboBoxes
			for {set i 0} {$i < 11} {incr i} {
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
				if {[llength [$canvas_widget.cb_p$i cget -values]]} {
					$canvas_widget.cb_p$i current $idx
				}
			}

			# Adjust display appearance to fit the current character size
			accept_new_character_size

			# Adjust internal logic and the rest of PALE
			evaluete_enaged_pins
			$project pale_reevaluate_IO

			# Display the DDRAM and CGRAM hex editor windows
			if {$new_instance} {
				if {[lindex $ddram_window_params 0]} {
					show_ddram
				}
				if {[lindex $cgram_window_params 0]} {
					show_cgram
				}
			}

			# Accept new state of ports
			if {$new_instance} {
				set state [$project pale_get_true_state]
				new_state state
			}

			# Finalize ...
			clear_modified
			update

			return 1
		}
	}

	## Simulated MCU has been reset
	 # @return void
	public method reset {} {
		# There is nothing special what has to be done here, the
		#+ controller, HD44780, has its own reset mechanism independent
		#+ on the simulated MCU
	}


	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
	# ------------------------------------------------------------------

	## This method is called before configuration menu invocation
	 # @return void
	public method config_menu_special {} {
		set ::${class_name}::font_id $rom_code
		set ::${class_name}::char_size $lcd_char_size
		set ::${class_name}::_ignore_errors $ignore_errors
		set ::${class_name}::_no_delays $no_delays
		set ::${class_name}::menu_keep_win_on_top $keep_win_on_top
	}

	## This method is called after configuration menu is created
	 # @return void
	public method create_config_menu_special {} {
		# Changing character size is allowed only for 1 line displays
		if {$display_height == 2} {
			set state {disabled}
		} else {
			set state {normal}
		}
		$conf_menu entryconfigure [mc "Set character size"] -state $state
	}

	## This method is called to fill in the help dialog
	 # @parm Widget text_widget - Target text widget
	 # @return void
	 #
	 # Note: There is defined text tag "tag_bold" in the text widget
	public method show_help_special {text_widget} {
		$text_widget insert insert [mc "LCD display controled by HD44780 driver\n\n"]

		$text_widget insert insert [mc "This tool simulates a HD44780 character LCD of any size up to 2 rows and 64 columns. There are 11 lines serving as interface for the MCU, ``E'', ``RS'', ``R/W'' and ``D0''..``D7''. User can view end modify content of display data RAM (DDRAM), character generator RAM (CGRAM) and certain HD44780 registers: instruction register (IR), data register (DR), address counter (AC) and display shift, these registers are shown hexadecimal. User can also view content of character generator ROM (CGROM) and set font to use. All of the driver command are fully supported, all important events occurring in the simulated driver (HD44780) are recorded in the log. User can also see and modify certain HD44780 configuration flags like ``B'', ``S'', ``D'' and so on."]
	}

	## This method is called before panel window closure
	 # @return void
	public method close_window_special {} {
	}

	## Commit new on/off state
	 # @return void
	public method on_off_special {} {
		# Boot-up the controller, it takes 10ms according to manual
		if {[$project pale_is_enabled]} {
			# Clear CGRAM and reset the code
			clear_cgram
			reset_hd44780

			# Update log
			write_to_log I [mc "Starting the HD44780 boot-up sequence."]

			# Ensure that that the LCD dot matrix is clear
			clear_display

			# On a real HW would take about 10 ms
			engage_core 10000
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

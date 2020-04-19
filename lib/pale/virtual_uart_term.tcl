#!/usr/bin/tclsh
# Part of MCU 8051 IDE ( http://http://www.moravia-microsystems.com/mcu8051ide )

############################################################################
#    Copyright (C) 2011 by Martin Ošmera                                   #
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
if { ! [ info exists _VIRTUAL_UART_TERM_TCL ] } {
set _VIRTUAL_UART_TERM_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
#
# -------------------------------------------------------------------------

class VirtualUARTTerminal {
	inherit VirtualHWComponent

	# Font: Big bold font
	public common bold_font [font create		\
		-family {helvetica}		\
		-size [expr {int(-12 * $::font_size_factor)}] -weight {bold}	\
	]
	 # Font: Tiny normal font
	public common tiny_font [font create		\
		-family {helvetica}		\
		-size [expr {int(-9 * $::font_size_factor)}] -weight {normal}	\
	]
	 # Font: Tiny bold font
	public common tiny_font_bold [font create	\
		-family {helvetica}		\
		-size [expr {int(-9 * $::font_size_factor)}] -weight {bold}	\
	]
	 # Font: Normal font
	public common normal_font [font create		\
		-family {helvetica}		\
		-size [expr {int(-11 * $::font_size_factor)}] -weight {normal}	\
	]
	 # Font: Also normal font, but a bit larger
	public common big_font [font create		\
		-family {helvetica}		\
		-size [expr {int(-12 * $::font_size_factor)}] -weight {normal}	\
	]
	# Font: Font to be used in the panel -- bold
	public common cb_font	[font create				\
		-weight bold					\
		-size [expr {int(-10 * $::font_size_factor)}]	\
		-family {helvetica}				\
	]

	 # List of Int: Available baud rates for RS232
	public common available_baud_rates {
		50	75	110	134	150	200
		300	600	1200	1800	2400	4800
		9600	19200	38400	57600	115200	230400
		460800
	}

	public common COMPONENT_NAME	"Virtual UART Terminal"		;# Name of this component
	public common CLASS_NAME	"VirtualUARTTerminal"		;# Name of this class
	public common COMPONENT_ICON	{chardevice}			;# Icon for this panel (16x16)

	# Configuration menu
	public common CONFMENU {
		{command	{Show log window}	{}	5	"show_log"	{bar5}
			"Display the log of events which are currently happening in the simulated UART driver"}
		{separator}
		{command	{Show help}		{}	5	"show_help 1"	{help}
			"Show brief help"}
		{separator}
		{command	{Save configuration}	{}	0	"save_as"	{filesave}
			"Save configuration into a file"}
		{command	{Load configuration}	{}	0	"load_from"	{fileopen}
			"Load configuration from a file"}
		{separator}
		{checkbutton	"Window always on top"	{}	{::VirtualUARTTerminal::menu_keep_win_on_top}
			1 0 0	{keep_win_on_top_changed}
			""}
	}

	public common rect_size	12
	public common empty_fill	{#888888}
	public common empty_outline	{#AAAAAA}

	public common MAX_LOG_LENGTH		100		;# Int: Maximum number of row in the log window

	## PRIVATE
	private variable status_bar_label		;# Widget: Status bar

	private variable connection_port		;# Array of Int: Index is key number, value is port number or {-}
	private variable connection_pin			;# Array of Int: Index is key number, value is bit number or {-}

	private variable baud_conf		{9600}	;# Int: Selected baud rate for communication
	private variable parity_conf		{n}	;# Char: Selected type of parity
	private variable data_conf		{8}	;# Int: Number of data bits
	private variable stop_conf		{1}	;# Int: Number of stop bits

	private variable baud_cb			;#
	private variable parity_cb			;#
	private variable data_cb			;#
	private variable stop_cb			;#

	private variable send_selected_button
	private variable clear_selected_snd_button
	private variable clear_selected_rec_button

	private variable enaged				;# Array of Bool: enaged(port_num,bit_num) --> Is connected to this device ?
	private variable usr_note
	private variable cb
	private variable sbuf_r_canvas
	private variable sbuf_t_canvas
	private variable keep_win_on_top 0		;# Bool: Toplevel window

	private variable controls_frame

	private variable log_win_text		{}
	private variable warning_indicator	{}
	private variable log_time_mark		0
	private variable log_window_geometry	{}
	private variable log_enabled		1	;# Bool: Logging of events enabled (slower simulation)
	private variable log_on_off_chbut		;# Widget: Checkbox for enabling and disabling the logging of events

	private variable time_mark		0	;# Int: Time mark pointing to this point of time according to the MCU simulator engine
	private variable bit_time		104166.666
	private variable bit_rect
	private variable arrow
	private variable reg_val

	private variable graph_position
	private variable graph_prev_state
	private variable graph_elements

	private variable send_hexeditor
	private variable receive_hexeditor
	private variable reception_address	0

	private variable rxd_signal		1	;# Bool:
	private variable rxd_signal_prev	1
	private variable reception_in_progress	0
	private variable reception_bit_no
	private variable reception_sample_time
	private variable reception_data		0

	private variable output_buffer		{}
	private variable transmission_in_prog	0
	private variable byte_to_send		-1
	private variable transmission_bit_no	-1
	private variable transmission_sample_time
	private variable last_txd		1


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
		array set arrow {
			r  {}
			r8 {}
			t  {}
			t8 {}
		}
		array set reg_val {
			rxd {}
			txd {}
		}
		array set graph_position {
			t 0	r 0
		}
		array set graph_prev_state {
			t 1	r 1
		}
		array set graph_elements {
			t {}	r {}
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
		create_log

		# ComboBoxes to default state
		for {set i 0} {$i < 2} {incr i} {
			$cb(b$i) current 0
			$cb(p$i) current 0
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
		set keep_win_on_top $VirtualUARTTerminal::menu_keep_win_on_top
		if {$keep_win_on_top} {
			wm attributes $win -topmost 1 -alpha 0.8
		} else {
			wm attributes $win -topmost 0 -alpha 1.0
		}
	}

	## Reconnect the specified line to another port pin
	 # @parm Int i - line number (0..1)
	 # @return void
	public method reconnect {i} {
		# Adjust connections
		set connection_port($i) [$cb(p$i) get]
		set connection_pin($i)	[$cb(b$i) get]
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
		for {set i 0} {$i < 1} {incr i} {
			set port $connection_port($i)
			set bit $connection_pin($i)

			if {$port == {-} || $bit == {-}} {
				continue
			}

			set enaged($port,$bit) 1
			$project pale_engage_pin_by_input_device $port $bit $this
		}
	}

	## Invoke interrupt monitor window
	 # @return void
	private method create_gui {} {
		set dialog_opened 1

		# Create window
		set win [toplevel .virtual_uart_term$count -class [mc "UART Monitor"] -bg ${::COMMON_BG_COLOR}]
		incr count

		# Create status bar
		set status_bar_label [label $win.status_bar_label -justify left -pady 0 -anchor w]
		pack $status_bar_label -side bottom -fill x

		set main_frame [frame $win.main_frame]
		create_top_frame $main_frame	;# Create top frame
		create_bottom_frame $main_frame	;# Create bottom frame
		pack $main_frame -fill both -expand 1

		# Configure window
		wm title $win "[mc $component_name] - [$project cget -projectName] - MCU 8051 IDE"
		wm iconphoto $win ::ICONS::16::_chardevice
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW [list $this close_window]
		bindtags $win [list $win Toplevel all .]
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
		wm title $dialog [mc "UART simulator log - MCU 8051 IDE"]
		wm protocol $dialog WM_DELETE_WINDOW [list $this close_log_win]
		bindtags $dialog [list $dialog Toplevel $win all .]
	}

	## Show the log window
	 # The log window must have been once created by method create_log prior to
	 #+ the call to this method
	 # @return void
	public method show_log {} {
		if {$warning_indicator != {}} {
			destroy $warning_indicator
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

	## Set status bar tip for specified widget
	 # @parm Widget widget	- Target widget
	 # @parm String text	- Text of the stutus tip
	 # @return void
	private method termial_set_status_tip {widget text} {
		bind $widget <Enter> "$status_bar_label configure -text {$text}"
		bind $widget <Leave> "$status_bar_label configure -text {}"
	}

	private method create_top_top_frame {target_frame} {
		set target_frame [frame $target_frame.target_frame -pady 5 -padx 5]
		set controls_frame $target_frame

		 # - Baud rate
		grid [label $target_frame.baud_lbl	\
			-text [mc "Baud rate"]		\
		] -row 1 -column 5 -sticky w
		set baud_cb [ttk::combobox $target_frame.baud_cb	\
			-state readonly					\
			-width 6					\
			-exportselection 0				\
			-values $available_baud_rates			\
		]
		bind $baud_cb <<ComboboxSelected>>	\
			"$this change_port_config b \[$target_frame.baud_cb get\]"
		termial_set_status_tip $baud_cb [mc "Connection speed in bps"]
		grid $baud_cb -row 1 -column 6 -sticky w
		$target_frame.baud_cb current [lsearch [$target_frame.baud_cb cget -values] $baud_conf]
		 # - Parity
		grid [label $target_frame.parity_lbl	\
			-text [mc "Parity"]		\
		] -row 2 -column 5 -sticky w
		set parity_cb [ttk::combobox $target_frame.parity_cb	\
			-values {none odd even}				\
			-state readonly					\
			-width 6					\
			-exportselection 0				\
		]
		bind $parity_cb <<ComboboxSelected>>	\
			"$this change_port_config p \[$target_frame.parity_cb get\]"
		termial_set_status_tip $parity_cb [mc "Parity"]
		grid $parity_cb -row 2 -column 6 -sticky w
		$target_frame.parity_cb current [lsearch {n o e m s} $parity_conf]
		 # - Data bits
		grid [label $target_frame.data_lbl	\
			-text [mc "Data bits"]		\
		] -row 1 -column 8 -sticky w
		set data_cb [ttk::combobox $target_frame.data_cb	\
			-state readonly				\
			-width 1				\
			-values {5 6 7 8}			\
			-exportselection 0			\
		]
		bind $data_cb <<ComboboxSelected>>	\
			"$this change_port_config d \[$target_frame.data_cb get\]"
		termial_set_status_tip $data_cb [mc "Number of data bits"]
		grid $data_cb -row 1 -column 9 -sticky w
		$target_frame.data_cb current [lsearch [$target_frame.data_cb cget -values] $data_conf]
		 # - Stop bits
		grid [label $target_frame.stop_lbl	\
			-text [mc "Stop bits"]		\
		] -row 2 -column 8 -sticky w
		set stop_cb [ttk::combobox $target_frame.stop_cb	\
			-state readonly					\
			-width 1					\
			-values {1 2}					\
			-exportselection 0				\
		]
		bind $stop_cb <<ComboboxSelected>>	\
			"$this change_port_config s \[$target_frame.stop_cb get\]"
		termial_set_status_tip $stop_cb [mc "Number of stop bits"]
		grid $stop_cb -row 2 -column 9 -sticky w
		$target_frame.stop_cb current [lsearch [$target_frame.stop_cb cget -values] $stop_conf]

		# Create "ON/OFF" button
		set start_stop_button [ttk::button $target_frame.start_stop_button	\
			-command [list $this on_off_button_press]			\
			-style Flat.TButton						\
			-width 3							\
		]
		DynamicHelp::add $target_frame.start_stop_button	\
			-text [mc "Turn HW simulation on/off"]
		setStatusTip -widget $start_stop_button -text [mc "Turn HW simulation on/off"]
		bind $start_stop_button <Button-3> "$this on_off_button_press; break"
		bindtags $start_stop_button [list $start_stop_button TButton all .]
		grid $start_stop_button -row 1 -column 1 -sticky w

		# Create configuration menu button
		set conf_button [ttk::button $target_frame.conf_but	\
			-image ::ICONS::16::configure			\
			-style Flat.TButton				\
			-command [list $this config_menu]		\
		]
		setStatusTip -widget $conf_button -text [mc "Configure"]
		bindtags $conf_button [list $conf_button TButton all .]
		grid $conf_button -row 1 -column 2 -sticky w

		grid [label $target_frame.note_lbl	\
			-text [mc "Note:"]		\
		] -row 2 -column 1 -sticky w
		set usr_note [ttk::entry $target_frame.usr_note		\
			-validate key					\
			-validatecommand [list $this set_modified]	\
			-width 30					\
		]
		bindtags $usr_note [list $usr_note TEntry all .]
		grid $usr_note -row 2 -column 2 -sticky w

		grid columnconfigure $target_frame 4 -weight 1
		grid columnconfigure $target_frame 7 -minsize 10

		return $target_frame
	}

	##
	 # @parm Widget target_frame - Parent frame
	 # @return Widget - Created frame
	private method create_sbuf_t_frame {target_frame} {
		set sbuf_t_frame [frame $target_frame.sbuf_t_frame]
		set sbuf_t_canvas [canvas $sbuf_t_frame.sbuf_t_canvas	\
			-bg $::COMMON_BG_COLOR				\
			-width 250					\
			-height 60					\
			-highlightthickness 0				\
		]
		set canvas $sbuf_t_canvas

		set cb(p0) [ttk::combobox $canvas.cb_p0		\
				-width 1			\
				-font $cb_font			\
				-state readonly			\
			]
		bind $cb(p0) <<ComboboxSelected>> [list $this reconnect 0]
		bindtags $cb(p0) [list $cb(p0) TCombobox all .]

		set cb(b0) [ttk::combobox $canvas.cb_b0		\
				-width 1			\
				-font $cb_font			\
				-values {- 0 1 2 3 4 5 6 7}	\
				-state readonly			\
			]
		bind $cb(b0) <<ComboboxSelected>> [list $this reconnect 0]
		bindtags $cb(b0) [list $cb(b0) TCombobox all .]

		$canvas create text 45 0			\
			-text {TxD}				\
			-font ${::Simulator_GUI::bitfont}	\
			-anchor ne
		$canvas create window 30 40	\
			-window	$cb(p0)		\
			-anchor ne
		$canvas create window 30 40	\
			-window	$cb(b0)		\
			-anchor nw
		$canvas create text 45 20			\
			-text {SBUF-T}				\
			-font ${::Simulator_GUI::bitfont}	\
			-anchor ne
		$canvas create text 210 0			\
			-text {Parity}				\
			-font ${::Simulator_GUI::bitfont}	\
			-anchor nw
		set reg_val(txd) [$canvas create text 210 20	\
			-text { -- }				\
			-font ${::Simulator_GUI::bitfont}	\
			-anchor nw				\
		]

		set labels [list S 0 1 2 3 4 5 6 7 P S]

		set x 50
		set y 20
		for {set i 0} {$i < 11} {incr i} {
			if {$i == 1 || $i == 9 || $i == 10} {
				incr x 3
			} else {
				incr x 1
			}

			set bit_rect(t,$i) [$canvas create rectangle $x $y		\
				[expr {$x + $rect_size}] [expr {$y + $rect_size}]	\
				-fill $empty_fill -outline $empty_outline		\
			]
			$canvas create text			\
				[expr {$x + ($rect_size / 2)}]	\
				[expr {$y + ($rect_size / 2)}]	\
				-text [lindex $labels $i]	\
				-font $tiny_font

			incr x $rect_size
		}

		# Create dash line pointing to parity bit
		set pos [expr {55 + $rect_size + 9 * ($rect_size + 1) - ($rect_size + 1) / 2}]
		$canvas create line 210 6 $pos 6 $pos 20 -arrow none -dash {,}

		# Draw graph grid
		for {set x 65} {$x < 250} {incr x 5} {
			$canvas create line $x 43 $x 58 -fill {#AAAAAA} -tags grid -dash .
		}

		pack $sbuf_t_canvas -padx 5 -pady 5 -fill x
		return $sbuf_t_frame
	}

	##
	 # @parm Widget target_frame - Parent frame
	 # @return Widget - Created frame
	private method create_sbuf_r_frame {target_frame} {
		set sbuf_r_frame [frame $target_frame.sbuf_r_frame]
		set sbuf_r_canvas [canvas $sbuf_r_frame.sbuf_r_canvas	\
			-bg $::COMMON_BG_COLOR				\
			-width 250					\
			-height 60					\
			-highlightthickness 0				\
		]
		set canvas $sbuf_r_canvas

		set cb(p1) [ttk::combobox $canvas.cb_p1		\
				-width 1			\
				-font $cb_font			\
				-state readonly			\
			]
		bind $cb(p1) <<ComboboxSelected>> [list $this reconnect 1]
		bindtags $cb(p1) [list $cb(p1) TCombobox all .]

		set cb(b1) [ttk::combobox $canvas.cb_b1		\
				-width 1			\
				-font $cb_font			\
				-values {- 0 1 2 3 4 5 6 7}	\
				-state readonly			\
			]
		bind $cb(b1) <<ComboboxSelected>> [list $this reconnect 1]
		bindtags $cb(b1) [list $cb(b1) TCombobox all .]

		$canvas create text 45 0			\
			-text {RxD}				\
			-font ${::Simulator_GUI::bitfont}	\
			-anchor ne
		$canvas create window 30 40	\
			-window	$cb(p1)		\
			-anchor ne
		$canvas create window 30 40	\
			-window	$cb(b1)		\
			-anchor nw
		$canvas create text 45 20			\
			-text {SBUF-R}				\
			-font ${::Simulator_GUI::bitfont}	\
			-anchor ne
		$canvas create text 210 0			\
			-text {Parity}				\
			-font ${::Simulator_GUI::bitfont}	\
			-anchor nw
		set reg_val(rxd) [$canvas create text 210 20	\
			-text { -- }				\
			-font ${::Simulator_GUI::bitfont}	\
			-anchor nw				\
		]

		set labels [list S 0 1 2 3 4 5 6 7 P S]

		set x 50
		set y 20
		for {set i 0} {$i < 11} {incr i} {
			if {$i == 1 || $i == 9 || $i == 10} {
				incr x 3
			} else {
				incr x 1
			}

			set bit_rect(r,$i) [$canvas create rectangle $x $y		\
				[expr {$x + $rect_size}] [expr {$y + $rect_size}]	\
				-fill $empty_fill -outline $empty_outline		\
			]
			$canvas create text			\
				[expr {$x + ($rect_size / 2)}]	\
				[expr {$y + ($rect_size / 2)}]	\
				-font $tiny_font	\
				-text [lindex $labels $i]

			incr x $rect_size
		}

		set_bit_arrow r 0

		set pos [expr {55 + $rect_size + 9 * ($rect_size + 1) - ($rect_size + 1) / 2}]
		$canvas create line 210 6 $pos 6 $pos 20 -arrow none -dash {,}

		# Draw graph grid
		for {set x 65} {$x < 250} {incr x 5} {
			$canvas create line $x 43 $x 58 -fill {#AAAAAA} -tags grid -dash .
		}

		pack $sbuf_r_canvas -padx 5 -pady 5 -fill x
		return $sbuf_r_frame
	}

	## Create top frame in the dialog window (connector_canvas (left) and configuration (right))
	 # @parm Widget target_frame - Parent frame
	 # @return void
	private method create_top_frame {target_frame} {
		grid [create_top_top_frame $target_frame]	-row 1 -column 1 -sticky nwes -columnspan 4 -padx 1
		grid [create_sbuf_t_frame $target_frame]	-row 2 -column 1 -sticky nwes -columnspan 2 -padx 1
		grid [create_sbuf_r_frame $target_frame]	-row 2 -column 3 -sticky nwes -columnspan 2 -padx 1
	}

	## Create bottom frame (hexadecimal editors)
	 # @parm Widget target_frame - Parent frame
	 # @return void
	private method create_bottom_frame {target_frame} {
		# Create headers ("Data to send", "Received data")
		grid [label $target_frame.lbl_a		\
			-text [mc "Data to send"]	\
			-compound right			\
			-image ::ICONS::16::forward	\
			-padx 15 -font $bold_font	\
		] -row 4 -column 1 -columnspan 2
		grid [label $target_frame.lbl_b		\
			-text [mc "Received data"]	\
			-compound left			\
			-image ::ICONS::16::forward	\
			-padx 15 -font $bold_font	\
		] -row 4 -column 3 -columnspan 2

		# Create hexadecimal editors
		set send_hexeditor [HexEditor #auto		\
			$target_frame.send_hexeditor 8 32 2	\
			hex 1 1 5 256				\
		]
		[$send_hexeditor getLeftView] configure -exportselection 0
		$send_hexeditor bindSelectionAction [list $this hexeditor_selection s]
		grid $target_frame.send_hexeditor -row 5 -column 1 -columnspan 2

		set receive_hexeditor [HexEditor #auto		\
			$target_frame.receive_hexeditor 8 32 2	\
			hex 1 1 5 256				\
		]
		[$send_hexeditor getLeftView] configure -exportselection 0
		$receive_hexeditor bindSelectionAction [list $this hexeditor_selection r]
		$receive_hexeditor set_bg_hg $reception_address 1 0
		grid $target_frame.receive_hexeditor -row 5 -column 3 -columnspan 2

		# Create buttons "Send selected" and "Clear selected" in send part
		set send_selected_button [ttk::button		\
			$target_frame.send_selected_button	\
			-text [mc "Send selected"]		\
			-image ::ICONS::16::forward		\
			-command [list $this send_selected]	\
			-compound left				\
			-state disabled				\
		]
		set clear_selected_snd_button [ttk::button	\
			$target_frame.clear_selected_snd_button	\
			-text [mc "Clear selected"]		\
			-image ::ICONS::16::eraser		\
			-command [list $this clear_selected_snd]\
			-compound left				\
			-state disabled				\
		]
		termial_set_status_tip $send_selected_button [mc "Send selected data"]
		termial_set_status_tip $clear_selected_snd_button [mc "Remove selected data"]
		grid $send_selected_button -row 6 -column 1 -sticky we
		grid $clear_selected_snd_button -row 6 -column 2 -sticky we

		# Create buttons "Receive here" and "Clear selected" in reception part
		set receive_here_button [ttk::button		\
			$target_frame.receive_here_button	\
			-text [mc "Receive here"]		\
			-image ::ICONS::16::down0		\
			-command [list $this receive_here]	\
			-compound left				\
		]
		set clear_selected_rec_button [ttk::button	\
			$target_frame.clear_selected_rec_button	\
			-text [mc "Clear selected"]		\
			-image ::ICONS::16::eraser		\
			-command [list $this clear_selected_rec]\
			-compound left				\
			-state disabled				\
		]
		termial_set_status_tip $receive_here_button [mc "Receive data on current cursor position"]
		termial_set_status_tip $clear_selected_rec_button [mc "Remove selected data"]
		grid $receive_here_button -row 6 -column 3 -sticky we
		grid $clear_selected_rec_button -row 6 -column 4 -sticky we
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

	public method clear_selected_rec {} {
		set rangeofselection [$receive_hexeditor getRangeOfSelection]
		if {$rangeofselection == {}} {
			return
		}

		set start_cell [lindex $rangeofselection 0]
		set end_cell [lindex $rangeofselection 1]

		for {set i $start_cell} {$i <= $end_cell} {incr i} {
			$receive_hexeditor setValue $i {}
		}
	}

	public method clear_selected_snd {} {
		# Get range of text indexes determinating the selection
		set rangeofselection [$send_hexeditor getRangeOfSelection]
		if {$rangeofselection == {}} {
			return
		}

		# Determinate index of the start and end cell
		set start_cell [lindex $rangeofselection 0]
		set end_cell [lindex $rangeofselection 1]

		# Clear all selected cell one by one
		for {set i $start_cell} {$i <= $end_cell} {incr i} {
			$send_hexeditor setValue $i {}
		}
	}

	public method send_selected {} {
		# Get range of text indexes determinating the selection
		set rangeofselection [$send_hexeditor getRangeOfSelection]
		if {$rangeofselection == {}} {
			return
		}

		if {$transmission_in_prog} {
			return
		}

		set transmission_in_prog 1
		set byte_to_send -1
		set output_buffer [list]
		set start_cell [lindex $rangeofselection 0]
		set end_cell [lindex $rangeofselection 1]
		foreach value [$send_hexeditor get_values $start_cell $end_cell] {
			if {$value == {}} {
				continue
			}
			lappend output_buffer [expr "0x$value"]
		}

		write_to_log I [mc "TxD: Starting transmission of block"]

		$send_selected_button configure		\
			-text [mc "Stop transmission"]	\
			-image ::ICONS::16::fileclose	\
			-command [$this stop_transmission]
	}

	public method hexeditor_selection {source anything_selected} {
		if {$anything_selected} {
			set state {normal}
		} else {
			set state {disabled}
		}

		if {$source == {s}} {
			if {!$transmission_in_prog} {
				$send_selected_button	configure -state $state
			}
			$clear_selected_snd_button	configure -state $state
		} else {
			$clear_selected_rec_button	configure -state $state
		}
	}

	public method change_port_config {what new_value} {
		switch -- $what {
			b {
				set baud_conf $new_value
				set bit_time [expr {1000000000.0 / $baud_conf}]
			}
			p {
				switch -- $new_value {
					{none} {
						set new_value {n}
					}
					{odd} {
						set new_value {o}
					}
					{even} {
						set new_value {e}
					}
				}

				set parity_conf $new_value
			}
			d {
				set data_conf $new_value
			}
			s {
				set stop_conf $new_value
			}
		}
	}

	## Change reception adddress to address of the current cell
	 # @return void
	public method receive_here {} {
		set cell [$receive_hexeditor getCurrentCell]
		set reception_address $cell

		$receive_hexeditor clearBgHighlighting 0
		$receive_hexeditor set_bg_hg $cell 1 0
	}

	private method set_bit_color {interface bit state} {
		if {$interface == {r}} {
			set canvas $sbuf_r_canvas
		} else {
			set canvas $sbuf_t_canvas
		}

		if {$state == 1} {
			set fill ${::BitMap::one_fill}
			set outline ${::BitMap::one_outline}
		} elseif {$state == 0} {
			set fill ${::BitMap::zero_fill}
			set outline ${::BitMap::zero_outline}
		} elseif {$state == -1} {
			set fill {#888888}
			set outline {#AAAAAA}
		}

		$canvas itemconfigure $bit_rect($interface,$bit)	\
			-fill $fill					\
			-outline $outline
	}

	private method set_bit_arrow {interface position} {
		if {$interface == {r}} {
			set canvas $sbuf_r_canvas
		} else {
			set canvas $sbuf_t_canvas
		}

		if {$arrow($interface) != {}} {
			$canvas delete $arrow($interface)
		}
		if {$position != -1} {
			if {!$position} {
				set corr 0
			} elseif {$position >= 1 && $position <= 8} {
				set corr 2
			} elseif {$position == 9} {
				set corr 4
			} else {
				set corr 6
			}

			set pos [expr {51 + $rect_size + $position * ($rect_size + 1) - ($rect_size + 1) / 2 + $corr}]
			set arrow($interface) [$canvas create line 50 6 $pos 6 $pos 20 -arrow last]
		}
	}

	private method highlight_arrow {interface highlight} {
		if {$interface == {r}} {
			set canvas $sbuf_r_canvas
		} else {
			set canvas $sbuf_t_canvas
		}

		$canvas itemconfigure $arrow($interface) -width [expr {($highlight ? 1 : 0) + 1}]
	}

	private method graph_clear {interface} {
		if {$interface == {r}} {
			set canvas $sbuf_r_canvas
		} else {
			set canvas $sbuf_t_canvas
		}

		$canvas delete graph

		set graph_position($interface) 0
		set graph_prev_state($interface) 1
		set graph_elements($interface) [list]
	}

	private method graph_draw {interface state} {
		if {$interface == {r}} {
			set canvas $sbuf_r_canvas
		} else {
			set canvas $sbuf_t_canvas
		}

		if {$graph_position($interface) == 185} {
			$canvas move graph -1 0
			foreach item [lindex $graph_elements($interface) 0] {
				$canvas delete $item
			}
			set graph_elements($interface) [lreplace $graph_elements($interface) 0 0]
			incr graph_position($interface) -1
		}

		set x_0 [expr {65 + $graph_position($interface)}]
		set x_1 [expr {$x_0 + 1}]

		switch -- $graph_prev_state($interface) {
			0 {
				switch -- $state {
					0 {	;# 0 --> 0
						lappend graph_elements($interface) [list \
							[$canvas create line $x_0 58 $x_1 58 -tags graph -fill {#00FF00}] \
						]
					}
					1 {	;# 0 --> 1
						lappend graph_elements($interface) [list \
							[$canvas create line $x_0 43 $x_0 50 -tags graph -fill {#FF0000}] \
							[$canvas create line $x_0 50 $x_0 58 -tags graph -fill {#00FF00}] \
						]
					}
					default {
						lappend graph_elements($interface) [list \
							[$canvas create line $x_0 43 $x_0 58 -tags graph -fill {#0000FF}] \
						]
					}
				}
			}
			1 {
				switch -- $state {
					0 {	;# 1 --> 0
						lappend graph_elements($interface) [list \
							[$canvas create line $x_0 43 $x_0 50 -tags graph -fill {#FF0000}] \
							[$canvas create line $x_0 50 $x_0 58 -tags graph -fill {#00FF00}] \
						]
					}
					1 {	;# 1 --> 1
						lappend graph_elements($interface) [list \
							[$canvas create line $x_0 43 $x_1 43 -tags graph -fill {#FF0000}] \
						]
					}
					default {
						lappend graph_elements($interface) [list \
							[$canvas create line $x_0 43 $x_0 58 -tags graph -fill {#0000FF}] \
						]
					}
				}
			}
			default {
				lappend graph_elements($interface) [list \
					[$canvas create line $x_0 43 $x_0 58 -tags graph -fill {#0055FF}] \
				]
			}
		}

		incr graph_position($interface)
		set graph_prev_state($interface) $state
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
			set warning_indicator [label $controls_frame.w_lbl	\
				-image ::ICONS::16::status_unknown		\
				-cursor hand2					\
			]
			grid $warning_indicator -row 2 -column 4
			bind $warning_indicator <Button-1> [list $this show_log]
		}
	}

	# ------------------------------------------------------------------
	# UART SIMULATOR CORE
	# ------------------------------------------------------------------

	private method transmission_control {{txd {}}} {
		if {!$transmission_in_prog} {
			return $txd
		}

		if {$byte_to_send == -1} {
			if {[manage_output_buffer $txd]} {
				return $txd
			}
		}

		if {$time_mark >= $transmission_sample_time} {
			if {$time_mark >= ($transmission_sample_time + $bit_time)} {
				write_to_log E [mc "Simulated MCU has clock frequency set too low to even receive the transmitted data!"]
			} else {
				stop_transmission 1
				update_last_txd $txd
			}
		}

		return $last_txd
	}

	private method manage_output_buffer {txd} {
		if {![llength $output_buffer]} {
			set transmission_in_prog 0

			$sbuf_t_canvas itemconfigure $reg_val(txd) -text { -- }
			for {set i 0} {$i < 11} {incr i} {
				set_bit_color t $i -1
			}

			highlight_arrow t 0
			set_bit_arrow t -1

			write_to_log I [mc "TxD: Transmission of block finished"]

			return 1
		}

		set byte_to_send [lindex $output_buffer 0]
		set output_buffer [lreplace $output_buffer 0 0]
		set transmission_bit_no -1
		set transmission_sample_time 0

		$sbuf_t_canvas itemconfigure $reg_val(txd) -text [format {0x%02X} $byte_to_send]

		set_bit_color t 0 0
		for {set i 1} {$i <= $data_conf} {incr i} {
			set_bit_color t $i [expr {$byte_to_send & (1 << ($i - 1))}]
		}
		for {set i $data_conf} {$i < 8} {incr i} {
			set_bit_color t $i -1
		}
		if {$parity_conf != {n}} {
			set_bit_color t 9 [compute_parity $byte_to_send]
		} else {
			set_bit_color t 9 -1
		}
		set_bit_color t 10 1
		set_bit_arrow t 0
		highlight_arrow t 1

		write_to_log I [mc "TxD: Starting transmission of byte: 0x%02X" $byte_to_send]

		return 0
	}

	private method update_last_txd {txd} {
		if {$transmission_bit_no == -1} {
			set transmission_sample_time [expr {$time_mark + $bit_time}]
		} else {
			set transmission_sample_time [expr {$transmission_sample_time + $bit_time}]
		}

		# Send START bit
		if {$transmission_bit_no == -1} {
			set txd 0
			set transmission_bit_no 0

		# Send DATA bit
		} elseif {$transmission_bit_no < $data_conf} {
			set txd [expr {($byte_to_send & (1 << $transmission_bit_no)) ? 1 : 0}]
			incr transmission_bit_no

		# Send PARITY or STOP bit
		} elseif {$transmission_bit_no == $data_conf} {
			if {$parity_conf != {n}} {
				set txd [compute_parity $byte_to_send]
				set transmission_bit_no 9
			} else {
				set txd 1
				set transmission_bit_no 10
			}

		# Send STOP bit
		} elseif {$transmission_bit_no == 9} {
			set txd 1
			set transmission_bit_no 10

		# Send STOP bit / End of transmission
		} elseif {$transmission_bit_no == 10} {
			set txd 1
			if {$stop_conf == 1} {
				write_to_log I [mc "TxD: Transmission of byte: 0x%02X complete" $byte_to_send]
				set byte_to_send -1
			} else {
				set transmission_bit_no 11
			}

		# End of transmission
		} elseif {$transmission_bit_no == 11} {
			write_to_log I [mc "TxD: Transmission of byte: 0x%02X complete" $byte_to_send]
			set byte_to_send -1
		}

		if {$transmission_bit_no < 11} {
			set_bit_arrow t $transmission_bit_no
		}

		set last_txd $txd
	}

	public method stop_transmission {{internal_error 0}} {
		set output_buffer {}
		set byte_to_send -1

		$sbuf_t_canvas itemconfigure $reg_val(txd) -text { -- }
		$send_selected_button configure		\
			-text [mc "Send selected"]	\
			-image ::ICONS::16::forward	\
			-command [list $this send_selected]

		if {$internal_error} {
			write_to_log I [mc "TxD: Transmission TERMINATED on user request"]
		} else {
			write_to_log W [mc "TxD: Transmission TERMINATED due to an error"]
		}
	}

	private method reception_control {} {
		if {$reception_in_progress} {
			if {$time_mark >= $reception_sample_time} {
				set reception_data [expr {$reception_data | (($rxd_signal ? 1 : 0) << $reception_bit_no)}]
				set reception_sample_time [expr {$reception_sample_time + $bit_time}]
				$sbuf_r_canvas itemconfigure $reg_val(rxd) -text [format {0x%02X} [expr {($reception_data & 0x1fe) >> 1}]]

				if {$reception_bit_no < 11} {
					set_bit_color r $reception_bit_no $rxd_signal
				}

				incr reception_bit_no

				if {$reception_bit_no == ($data_conf + 1)} {
					set reception_bit_no 9

					if {$parity_conf == {n}} {
						incr reception_bit_no

					}
				} elseif {$reception_bit_no == 10 && $stop_conf == 1} {
					incr reception_bit_no
				}

				if {$reception_bit_no < 11} {
					set_bit_arrow r $reception_bit_no
				}
				highlight_arrow r 1

				if {$reception_bit_no == 12} {
					set_bit_arrow r 0
					highlight_arrow r 0
					$sbuf_r_canvas itemconfigure $reg_val(rxd) -text { -- }
					for {set i 0} {$i < 11} {incr i} {
						set_bit_color r $i -1
					}
					reception_complete
				}
			} else {
				highlight_arrow r 0
			}
		} else {
			if {$rxd_signal_prev && !$rxd_signal} {
				set reception_in_progress 1
				set reception_bit_no 1
				set reception_data 0
				set reception_sample_time [expr {$time_mark + $bit_time * 1.5}]

				set_bit_color r 0 0
				set_bit_arrow r 1

				write_to_log I [mc "RxD: Receiving byte, address = 0x%02X" $reception_address]
			}
		}
	}

	private method reception_complete {} {
		set reception_in_progress 0

		if {$reception_address >= 255} {
			set reception_address 0
			write_to_log W [mc "RxD: Reception buffer overflow"]
		}

		set data [expr {($reception_data & 0x1fe) >> 1}]
		$receive_hexeditor setValue $reception_address $data
		$receive_hexeditor set_bg_hg $reception_address 1 1

		# Verify rceived byte
		if {$parity_conf != {n}} {
			if {[compute_parity $data] != (($data & 0x20) ? 1 : 0)} {
				write_to_log E [mc "RxD: Parity flag doesn't match"]
			}
		}
		if {!(($data & 0x80) ? 1 : 0) || (($stop_conf > 1) && !(($data & 0x40) ? 1 : 0))} {
			write_to_log E [mc "RxD: Invalid STOP bit(s)"]
		}

		write_to_log I [mc "RxD: Byte received, address = 0x%02X, data = 0x%02X" $reception_address $data]

		incr reception_address
		$receive_hexeditor seeCell $reception_address
	}

	private method compute_parity {data} {
		set count 0
		set mask 1
		for {set i 0} {$i < 8} {incr i} {
			if {$data & $mask} {
				incr count
			}
			set mask [expr {$mask << 1}]
		}

		set data [expr {($count % 2) ? 1 : 0}]
		if {$parity_conf == {o}} {
			set data [expr {!$data}]
		}

		return $data
	}

	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE
	# ------------------------------------------------------------------

	## Simulated MCU has been changed
	 # @return void
	public method mcu_changed {} {
		# Refresh lists of possible values in port selection ComboBoxes
		set available_ports [concat - [$project pale_get_available_ports]]

		for {set i 0} {$i < 2} {incr i} {
			$cb(p$i) configure -values $available_ports

			if {[lsearch -ascii -exact $available_ports $connection_port($i)] == -1} {
				$cb(p$i) current 0
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

		if {$time_mark == [$project get_run_statistics 0]} {
			return
		}
		set time_mark [$project get_run_statistics 0]
		set cycles [$project pale_get_number_of_instruction_cycles]

		# --------------------------------------------------------------
		# TxD part
		# --------------------------------------------------------------
		set pp [which_port_pin 0]

		if {[lindex $pp 0] != {-} && [lindex $pp 1] != {-}} {
			lset state $pp [transmission_control [lindex $state $pp]]
		} else {
			transmission_control
		}
		for {set i 0} {$i < $cycles} {incr i} {
			graph_draw t $last_txd
		}

		# --------------------------------------------------------------
		# RxD part
		# --------------------------------------------------------------
		set pp [which_port_pin 1]

		if {[lindex $pp 0] != {-} && [lindex $pp 1] != {-}} {
			reception_control

			set rxd_signal_prev $rxd_signal
			set rxd_signal [lindex $state $pp]

			# Convert any possible I/O signal value to Boolean value
			switch -- $rxd_signal {
				{0} -
				{1} {}
				{=} {
					set rxd_signal 0
				}
				default {
					write_to_log E [mc "RxD: Input corrupted!"]
				}
			}

			for {set i 0} {$i < $cycles} {incr i} {
				graph_draw r [$project pale_RRPPV $pp $i]
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
				[array get connection_port]		\
				[array get connection_pin]		\
				[wm geometry $win]			\
				[$usr_note get]				\
				$baud_conf				\
				$parity_conf				\
				$data_conf				\
				$stop_conf				\
				[$send_hexeditor get_values 0 255]	\
				[$send_hexeditor getCurrentCell]	\
				[$receive_hexeditor get_values 0 255]	\
				[$receive_hexeditor getCurrentCell]	\
				$reception_address			\
				[wm geometry $win.log_window]		\
				[wm state $win.log_window]		\
				$keep_win_on_top			\
			]	\
		]
	}

	## Set panel configuration from list gained from method "get_config"
	 # @parm List state - Configuration list
	 # @return void
	public method set_config {state} {
			# Load connections to the MCU
			array set connection_port [lindex $state 0]
			array set connection_pin [lindex $state 1]

			# Restore window geometry
			if {[string length [lindex $state 2]]} {
				wm geometry $win [regsub {^\=?\d+x\d+} [lindex $state 2] [join [wm size $win] {x}]]
			}

			# Load user note
			$usr_note delete 0
			$usr_note insert 0 [lindex $state 3]

			set baud_conf [lindex $state 4]
			set bit_time [expr {1000000000.0 / $baud_conf}]
			set parity_conf [lindex $state 5]
			set data_conf [lindex $state 6]
			set stop_conf [lindex $state 7]

			$baud_cb current [lsearch [$baud_cb cget -values] $baud_conf]
			$parity_cb current [lsearch {n o e} $parity_conf]
			$data_cb current [lsearch [$data_cb cget -values] $data_conf]
			$stop_cb current [lsearch [$stop_cb cget -values] $stop_conf]

			for {set i 0} {$i < 0x100} {incr i} {
				$send_hexeditor setValue $i [lindex $state [list 8 $i]]
			}
			$send_hexeditor setCurrentCell [lindex $state 9]
			for {set i 0} {$i < 0x100} {incr i} {
				$receive_hexeditor setValue $i [lindex $state [list 10 $i]]
			}
			$receive_hexeditor setCurrentCell [lindex $state 11]
			set reception_address [lindex $state 12]
			$receive_hexeditor clearBgHighlighting 0
			$receive_hexeditor set_bg_hg $reception_address 1 0

			# Display the log window
			set log_window_geometry [lindex $state 13]
			if {[lindex $state 14] == {normal}} {
				show_log
			}

			if {[lindex $state 15] != {}} {
				set keep_win_on_top [lindex $state 15]
				if {$keep_win_on_top} {
					wm attributes $win -topmost 1 -alpha 0.8
				}
			}

			# Restore state of ComboBoxes
			for {set i 0} {$i < 2} {incr i} {
				## PIN
				set pin $connection_pin($i)
				if {$pin != {-}} {
					set pin	[expr {7 - $pin}]
				}
				set idx [lsearch -ascii -exact	\
					[$cb(b$i) cget -values]	\
					$pin			\
				]
				if {$idx == -1} {
					set idx 0
				}
				$cb(b$i) current $idx

				## PORT
				set idx [lsearch -ascii -exact		\
					[$cb(p$i) cget -values]		\
					$connection_port($i)		\
				]
				if {$idx == -1} {
					set idx 0
				}
				$cb(p$i) current $idx
			}

			# Adjust internal logic and the rest of PALE
			evaluete_enaged_pins
			$project pale_reevaluate_IO
			update

		if {[catch {
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

		graph_clear t
		graph_clear r
	}


	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
	# ------------------------------------------------------------------

	## This method is called before configuration menu invocation
	 # @return void
	public method config_menu_special {} {
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
			graph_clear t
			graph_clear r
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

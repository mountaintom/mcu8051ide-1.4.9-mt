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
if { ! [ info exists _RS232DEBUGGER_TCL ] } {
set _RS232DEBUGGER_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# Implements RS232/UART debugger
# --------------------------------------------------------------------------

class RS232Debugger {
	## COMMON
	public common count	0	;# Int: Counter of class instances
	 # Font: Big bold font
	public common bold_font [font create				\
		-family {helvetica}				\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight {bold}					\
	]
	 # Font: Tiny normal font
	public common tiny_font [font create				\
		-family {helvetica}				\
		-size [expr {int(-9 * $::font_size_factor)}]	\
		-weight {normal}				\
	]
	 # Font: Tiny bold font
	public common tiny_font_bold [font create			\
		-family {helvetica}				\
		-size [expr {int(-9 * $::font_size_factor)}]	\
		-weight {bold}					\
	]
	 # Font: Normal font
	public common normal_font [font create				\
		-family {helvetica}				\
		-size [expr {int(-11 * $::font_size_factor)}]	\
		-weight {normal}				\
	]
	 # Font: Also normal font, but a bit larger
	public common big_font [font create				\
		-family {helvetica}				\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight {normal}				\
	]
	 # Int: Pool interval for selected RS232 interface
	public common POOL_INTERVAL	50	;# mili-seconds
	 # List of Int: Available baud rates for RS232
	public common available_baud_rates {
		50	75	110	134	150	200
		300	600	1200	1800	2400	4800
		9600	19200	38400	57600	115200	230400
		460800
	}

	 # List: Configuration list
	public common config_list	$::CONFIG(RS232_DEBUGGER)


	## PRIVATE
	private variable obj_idx			;# Int: Object index
	private variable win				;# Widget: Dialog window
	private variable connector_canvas		;# Widget: Canvas widget displaying the DE-9 connector
	private variable port_combobox			;# Widget: Combobox for device file selection
	private variable status_bar_label		;# Widget: Status bar

	private variable baud_cb			;# Widget: ComboBox for selecting baud rate
	private variable parity_cb			;# Widget: ComboBox for selecting type of parity
	private variable data_cb			;# Widget: ComboBox for selecting number of data bits
	private variable stop_cb			;# Widget: ComboBox for selecting number of stop bits
	private variable enable_reception_chb		;# Widget: Check button "Enable reception"
	private variable close_connection_button	;# Widget: Button "Close connection"

	private variable leds				;# Array of CanvasObjects: LEDs indicating logical states on wires
	private variable dtr_button			;# Widget: Button "DTR"
	private variable rts_button			;# Widget: Button "RTS"
	private variable break_button			;# Widget: Button "Break"

	private variable send_selected_button		;# Widget: Button "Send selected"
	private variable clear_selected_rec_button	;# Widget: Button "Clear selected" in section "Receive"
	private variable receive_here_button		;# Widget: Button "Receive here"
	private variable clear_selected_snd_button	;# Widget: Button "Clear selected" in section "Send"
	private variable receive_hexeditor		;# Object: Hex editor intented for reception
	private variable send_hexeditor			;# Object: Hex editor intented for sending

	private variable pool_timer		{}	;# Object: Pool timer object
	private variable channel		{}	;# Channel: Opened device file
	private variable port_filename		{}	;# String: Device file name
	private variable reception_address	0	;# Int: Address in reception hex editor where received data are stored
	private variable reception_enabled	1	;# Bool: Reception enabled
	private variable prev_tty_status		;# List: Previous TTY status (before any action performed by this code)

	private variable baud_conf		{9600}	;# Int: Selected baud rate for communication
	private variable parity_conf		{n}	;# Char: Selected type of parity
	private variable data_conf		{8}	;# Int: Number of data bits
	private variable stop_conf		{1}	;# Int: Number of stop bits


	## Object constructor
	constructor {} {
		# Configure local ttk styles
		ttk::style configure RS232Debugger_FileInUse.TCombobox		\
			-fieldbackground {#DDFFDD}
		ttk::style map RS232Debugger_FileInUse.TCombobox		\
			-fieldbackground [list {readonly !readonly} {#DDFFDD}]

		ttk::style configure RS232Debugger_FileFound.TCombobox		\
			-fieldbackground {#FFFFAA}
		ttk::style map RS232Debugger_FileFound.TCombobox		\
			-fieldbackground [list {readonly !readonly} {#FFFFAA}]

		ttk::style configure RS232Debugger_FileNotFound.TCombobox	\
			-fieldbackground {#FFDDDD}
		ttk::style map RS232Debugger_FileNotFound.TCombobox	\
			-fieldbackground [list {readonly !readonly} {#FFDDDD}]

		ttk::style configure RS232Debugger_SignalAllDefault.TButton	\
			-foreground {#000000}					\
			-background {#DDDDDD}
		ttk::style map RS232Debugger_SignalAllDefault.TButton		\
			-background [list active ${::COMMON_BG_COLOR}]

		ttk::style configure RS232Debugger_SignalTxDTrue.TButton	\
			-background {#AAFFAA}					\
			-foreground {#000000}
		ttk::style map RS232Debugger_SignalTxDTrue.TButton		\
			 -background [list active {#DDFFDD}]			\
			 -foreground [list active {#00FF00}]

		ttk::style configure RS232Debugger_SignalNormalTrue.TButton	\
			-background {#AAFFAA}					\
			-foreground {#000000}
		ttk::style map RS232Debugger_SignalNormalTrue.TButton		\
			-background [list active {#DDFFDD}]			\
			-foreground [list active {#00FF00}]

		ttk::style configure RS232Debugger_SignalTxDFalse.TButton	\
			-background {#DDDDDD}					\
			-foreground {#000000}
		ttk::style map RS232Debugger_SignalTxDFalse.TButton		\
			-background [list active ${::COMMON_BG_COLOR}]			\
			-foreground [list active {#000000}]

		ttk::style configure RS232Debugger_SignalNormalFalse.TButton	\
			-background {#FFAAAA}					\
			-foreground {#000000}
		ttk::style map RS232Debugger_SignalNormalFalse.TButton		\
			-background [list active {#FFDDDD}]			\
			-foreground [list active {#FF0000}]


		incr count
		set obj_idx $count

		array set prev_tty_status {0 {} cts {} dsr {} ri {} dcd {} dtr {} rts {} break {}}

		# Validate and possibly correct configuration list
		if {[lsearch -ascii -exact $available_baud_rates [lindex $config_list 0]] == -1} {
			puts stderr [mc "RS232 DBG: Invalid baud rate, setting to default: %s" $baud_conf]
			lset config_list 0 $baud_conf
		}
		if {[lsearch -ascii -exact {n o e m s} [lindex $config_list 1]] == -1} {
			puts stderr [mc "RS232 DBG: Invalid parity, setting to default: %s" $parity_conf]
			lset config_list 1 $parity_conf
		}
		if {[lsearch -ascii -exact {5 6 7 8} [lindex $config_list 2]] == -1} {
			puts stderr [mc "RS232 DBG: Invalid data length, setting to default: %s" $data_conf]
			lset config_list 2 $data_conf
		}
		if {[lsearch -ascii -exact {1 2} [lindex $config_list 3]] == -1} {
			puts stderr [mc "RS232 DBG: Invalid stop bit length, setting to default: %s" $stop_conf]
			lset config_list 3 $stop_conf
		}
		if {[lsearch -ascii -exact {0 1} [lindex $config_list 4]] == -1} {
			puts stderr [mc "RS232 DBG: Invalid flag reception_enabled, setting to default: %s" $reception_enabled]
			lset config_list 4 $reception_enabled
		}
		if {![string is digit -strict [lindex $config_list 9]] || [lindex $config_list 9] < 0 || [lindex $config_list 9] > 256} {
			puts ">> {[lindex $config_list 9]}"
			puts stderr [mc "RS232 DBG: Invalid reception address, setting to default: %s" $reception_address]
			lset config_list 9 $reception_address
		}
		if {![string is digit -strict [lindex $config_list 7]] || [lindex $config_list 7] < 0 || [lindex $config_list 7] > 255} {
			puts stderr [mc "RS232 DBG: Invalid current cell address, setting to default: %s" "0"]
			lset config_list 7 0
		}
		if {![string is digit -strict [lindex $config_list 8]] || [lindex $config_list 8] < 0 || [lindex $config_list 8] > 255} {
			puts stderr [mc "RS232 DBG: Invalid current cell address, setting to default: %s" "0"]
			lset config_list 8 0
		}

		# Load configuration list
		set baud_conf		[lindex $config_list 0]
		set parity_conf		[lindex $config_list 1]
		set data_conf		[lindex $config_list 2]
		set stop_conf		[lindex $config_list 3]
		set reception_enabled	[lindex $config_list 4]
		set reception_address	[expr {int([lindex $config_list 9])}]
		if {$reception_address == 256} {
			set reception_address 0
		}

		# Initialize GUI
		create_gui
		set_tty_controls_state 0

		# Restore data displayed in hex editors
		foreach idx {5 6} hexedit [list $receive_hexeditor $send_hexeditor] {
			set data [lindex $config_list $idx]
			if {![llength $data]} {
				continue
			}

			for {set i 0} {$i < 0x100} {incr i} {
				$hexedit setValue $i [lindex $data $i]
			}
		}

		# restore addresses of current cells in hex editors
		$receive_hexeditor	setCurrentCell [lindex $config_list 7]
		$send_hexeditor		setCurrentCell [lindex $config_list 8]
	}

	## Object destructor
	destructor {
		# Create a new configuration list
		set config_list [list					\
			$baud_conf	$parity_conf	$data_conf	\
			$stop_conf	$reception_enabled		\
			[$receive_hexeditor get_values 0 255]		\
			[$send_hexeditor get_values 0 255]		\
			[$receive_hexeditor getCurrentCell]		\
			[$send_hexeditor getCurrentCell]		\
			$reception_address				\
		]

		# Cancel pool timer
		catch {after cancel $pool_timer}

		# Close opened channel
		if {$channel !={}} {
			catch {fileevent $channel readable {}}
			catch {close $channel}
		}

		# Destroy GUI
		destroy $win
	}

	## Create dialog GUI
	 # @return void
	private method create_gui {} {
		# Create window
		set win [toplevel .rs232debugger$count -class [mc "RS232 Debugger"] -bg ${::COMMON_BG_COLOR}]

		# Create status bar
		set status_bar_label [label $win.status_bar_label -justify left -pady 0 -anchor w]
		pack $status_bar_label -side bottom -fill x

		# Create top frame
		set top_frame [frame $win.top_frame]
		create_top_frame $top_frame
		pack $top_frame -fill x -anchor nw

		# Create bottom frame
		set bottom_frame [frame $win.bottom_frame]
		create_bottom_frame $bottom_frame
		pack $bottom_frame -fill x -anchor nw

		$receive_hexeditor clearBgHighlighting 0
		$receive_hexeditor set_bg_hg $reception_address 1 0

		# Configure window
		wm title $win [mc "UART/RS232 Debugger - MCU 8051 IDE"]
		wm iconphoto $win ::ICONS::16::chardevice
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW "catch {delete object $this}"
	}

	## Set status bar tip for specified widget
	 # @parm Widget widget	- Target widget
	 # @parm String text	- Text of the stutus tip
	 # @return void
	private method set_status_tip {widget text} {
		bind $widget <Enter> "$status_bar_label configure -text {$text}"
		bind $widget <Leave> "$status_bar_label configure -text {}"
	}

	## Draw DE-9 connector in the $connector_canvas
	 # @parm Int x - X offset
	 # @parm Int y - Y offset
	 # @return void
	private method draw_connector {x y} {
		## Draw package
		set coords {
			1 19	3 16	27 1	33 1	37 6	37 88
			33 91	27 91	3 80	1 74	1 19
		}

		# Transform coordinates -- adjust them to the given origin
		set coordinates [list]
		set len [llength $coords]
		for {set m 0; set n 1} {$n < $len} {incr m 2; incr n 2} {
			lappend coordinates	\
				[expr {[lindex $coords $m] + $x}]
			lappend coordinates	\
				[expr {[lindex $coords $n] + $y}]
		}

		$connector_canvas create line $coordinates	\
			-tags connector -width 1 -fill #000000

		## Draw pins
		set coords {
			28 16	28 32	28 48	28 64	28 80
			12 24	12 40	12 56	12 72
		}
		set tags {dcd_pin rxd_pin txd_pin dtr_pin gnd_pin dsr_pin rts_pin cts_pin ri_pin}

		# Transform coordinates -- adjust them to the given origin
		set len [llength $coords]
		for {set m 0; set n 1; set i 0} {$n < $len} {incr m 2; incr n 2; incr i} {
			$connector_canvas create oval			\
				[expr {[lindex $coords $m] - 2 + $x}]	\
				[expr {[lindex $coords $n] - 2 + $y}]	\
				[expr {[lindex $coords $m] + 2 + $x}]	\
				[expr {[lindex $coords $n] + 2 + $y}]	\
				-tags connector -width 1		\
				-outline #000000 -tags [lindex $tags $i]
		}

		## Draw pin numbers
		set coords {
			21 16	21 32	21 48	21 64	21 80
			5 24	5 40	5 56	5 72
		}
		set tags {{} dcd_num rxd_num txd_num dtr_num gnd_num dsr_num rts_num cts_num ri_num}

		# Transform coordinates -- adjust them to the given origin
		set len [llength $coords]
		for {set m 0; set n 1; set i 1} {$n < $len} {incr m 2; incr n 2; incr i} {
			$connector_canvas create text			\
				[expr {[lindex $coords $m] + $x}]	\
				[expr {[lindex $coords $n] + $y}]	\
				-tags connector -fill #000000		\
				-anchor center -justify center -text $i	\
 				-font $tiny_font -tags [lindex $tags $i]
		}

		## Draw common ground
		set coords {
			31 80	60 80	60 105	53 105	67 105
		}

		# Transform coordinates -- adjust them to the given origin
		set coordinates [list]
		set len [llength $coords]
		for {set m 0; set n 1} {$n < $len} {incr m 2; incr n 2} {
			lappend coordinates	\
				[expr {[lindex $coords $m] + $x}]
			lappend coordinates	\
				[expr {[lindex $coords $n] + $y}]
		}

		$connector_canvas create line $coordinates	\
			-tags gnd_wire -width 1 -fill #000000

		$connector_canvas bind gnd_wire <Enter> "$this wire_enter gnd"
		$connector_canvas bind gnd_wire <Leave> "$this wire_leave gnd"

		## Write texts
		$connector_canvas create text			\
			[expr {$x + 10}] [expr {$y - 30}]	\
			-anchor n -justify left			\
			-font $big_font -text [mc "RS-232\nDTE"]
		$connector_canvas create text			\
			[expr {$x + 10}] [expr {$y + 100}]	\
			-anchor n -justify left			\
			-font $big_font -text [mc "DE-9"]
	}

	## Draw wires, LEDs and buttons in the $connector_canvas
	 # @parm Int x - X offset
	 # @parm Int y - Y offset
	 # @return void
	private method draw_wires_and_controls {x y} {
		## DCD
		set leds(dcd) [label $connector_canvas.dcd_led	\
			-image ::ICONS::16::ledgray		\
		]
		bind $leds(dcd) <Enter> "$this wire_enter dcd"
		bind $leds(dcd) <Leave> "$this wire_leave dcd"
		$connector_canvas create window			\
			[expr {$x + 100}] [expr {$y + 1}]	\
			-anchor center -window $leds(dcd)
		$connector_canvas create line			\
			[expr {$x + 31}] [expr {$y + 16}]	\
			[expr {$x + 100}] [expr {$y + 16}]	\
			[expr {$x + 100}] [expr {$y + 1}]	\
			-width 1 -fill {#888888} -tags dcd_wire
		$connector_canvas create line			\
			[expr {$x + 74}] [expr {$y + 16}]	\
			[expr {$x + 75}] [expr {$y + 16}]	\
			-width 1 -fill {#888888} -tags dcd_wire	\
			-arrow last
		$connector_canvas create text			\
			[expr {$x + 100}] [expr {$y - 7}]	\
			-tags connector -fill #000000		\
			-anchor s -justify left -text [mc "DCD"]\
			-font $normal_font

		## DSR
		set leds(dsr) [label $connector_canvas.dsr_led	\
			-image ::ICONS::16::ledgray		\
		]
		bind $leds(dsr) <Enter> "$this wire_enter dsr"
		bind $leds(dsr) <Leave> "$this wire_leave dsr"
		$connector_canvas create window			\
			[expr {$x + 135}] [expr {$y + 1}]	\
			-anchor center -window $leds(dsr)

		$connector_canvas create line			\
			[expr {$x + 15}] [expr {$y + 24}]	\
			[expr {$x + 135}] [expr {$y + 24}]	\
			[expr {$x + 135}] [expr {$y + 1}]	\
			-width 1 -fill {#888888} -tags dsr_wire
		$connector_canvas create line			\
			[expr {$x + 74}] [expr {$y + 24}]	\
			[expr {$x + 75}] [expr {$y + 24}]	\
			-width 1 -fill {#888888} -tags dsr_wire	\
			-arrow last
		$connector_canvas create text			\
			[expr {$x + 135}] [expr {$y - 7}]	\
			-tags connector -fill #000000		\
			-anchor s -justify left -text [mc "DSR"]\
			-font $normal_font

		## CTS
		set leds(cts) [label $connector_canvas.cts_led	\
			-image ::ICONS::16::ledgray		\
		]
		bind $leds(cts) <Enter> "$this wire_enter cts"
		bind $leds(cts) <Leave> "$this wire_leave cts"
		$connector_canvas create window			\
			[expr {$x + 170}] [expr {$y + 1}]	\
			-anchor center -window $leds(cts)

		$connector_canvas create line			\
			[expr {$x + 15}] [expr {$y + 56}]	\
			[expr {$x + 170}] [expr {$y + 56}]	\
			[expr {$x + 170}] [expr {$y + 1}]	\
			-width 1 -fill {#888888} -tags cts_wire
		$connector_canvas create line			\
			[expr {$x + 74}] [expr {$y + 56}]	\
			[expr {$x + 75}] [expr {$y + 56}]	\
			-width 1 -fill {#888888} -tags cts_wire	\
			-arrow last
		$connector_canvas create text			\
			[expr {$x + 170}] [expr {$y - 7}]	\
			-tags connector -fill #000000		\
			-anchor s -justify left -text [mc "CTS"]\
			-font $normal_font

		## RI
		set leds(ri) [label $connector_canvas.ri_led	\
			-image ::ICONS::16::ledgray		\
		]
		bind $leds(ri) <Enter> "$this wire_enter ri"
		bind $leds(ri) <Leave> "$this wire_leave ri"
		$connector_canvas create window			\
			[expr {$x + 205}] [expr {$y + 1}]	\
			-anchor center -window $leds(ri)

		$connector_canvas create line			\
			[expr {$x + 15}] [expr {$y + 72}]	\
			[expr {$x + 205}] [expr {$y + 72}]	\
			[expr {$x + 205}] [expr {$y + 1}]	\
			-width 1 -fill {#888888} -tags ri_wire
		$connector_canvas create line			\
			[expr {$x + 74}] [expr {$y + 72}]	\
			[expr {$x + 75}] [expr {$y + 72}]	\
			-width 1 -fill {#888888} -tags ri_wire	\
			-arrow last
		$connector_canvas create text			\
			[expr {$x + 205}] [expr {$y - 7}]	\
			-tags connector -fill #000000		\
			-anchor s -justify left -text [mc "RI"]	\
			-font $normal_font


		## DTR
		set dtr_button [ttk::button $connector_canvas.dtr_button	\
			-style RS232Debugger_SignalAllDefault.TButton		\
			-command "$this invert_tty_status_bit dtr"		\
			-text "-"						\
			-width 2						\
		]
		bind $dtr_button <Enter> "$this wire_enter dtr"
		bind $dtr_button <Leave> "$this wire_leave dtr"
		$connector_canvas create window			\
			[expr {$x + 100}] [expr {$y + 90}]	\
			-anchor center -window $dtr_button

		$connector_canvas create line			\
			[expr {$x + 31}] [expr {$y + 64}]	\
			[expr {$x + 100}] [expr {$y + 64}]	\
			[expr {$x + 100}] [expr {$y + 95}]	\
			-width 1 -fill {#888888} -tags dtr_wire
		$connector_canvas create line			\
			[expr {$x + 46}] [expr {$y + 64}]	\
			[expr {$x + 45}] [expr {$y + 64}]	\
			-width 1 -fill {#888888} -tags dtr_wire	\
			-arrow last
		$connector_canvas create text			\
			[expr {$x + 100}] [expr {$y + 105}]	\
			-tags connector -fill #000000		\
			-anchor n -justify left -text [mc "DTR"]\
			-font $normal_font

		## RTS
		set rts_button [ttk::button $connector_canvas.rts_button	\
			-style RS232Debugger_SignalAllDefault.TButton		\
			-command "$this invert_tty_status_bit rts"		\
			-text "-"						\
			-width 2						\
		]
		bind $rts_button <Enter> "$this wire_enter rts"
		bind $rts_button <Leave> "$this wire_leave rts"
		$connector_canvas create window			\
			[expr {$x + 135}] [expr {$y + 90}]	\
			-anchor center -window $rts_button

		$connector_canvas create line			\
			[expr {$x + 15}] [expr {$y + 40}]	\
			[expr {$x + 135}] [expr {$y + 40}]	\
			[expr {$x + 135}] [expr {$y + 95}]	\
			-width 1 -fill {#888888} -tags rts_wire
		$connector_canvas create line			\
			[expr {$x + 46}] [expr {$y + 40}]	\
			[expr {$x + 45}] [expr {$y + 40}]	\
			-width 1 -fill {#888888} -tags rts_wire	\
			-arrow last
		$connector_canvas create text			\
			[expr {$x + 135}] [expr {$y + 105}]	\
			-tags connector -fill #000000		\
			-anchor n -justify left -text [mc "RTS"]\
			-font $normal_font

		## TxD
		set break_button [ttk::button $connector_canvas.break_button	\
			-style RS232Debugger_SignalAllDefault.TButton		\
			-command "$this invert_tty_status_bit break"		\
			-text [mc "Break"]					\
			-width 5						\
		]
		bind $break_button <Enter> "$this wire_enter txd"
		bind $break_button <Leave> "$this wire_leave txd"
		$connector_canvas create window			\
			[expr {$x + 180}] [expr {$y + 90}]	\
			-anchor center -window $break_button

		$connector_canvas create line			\
			[expr {$x + 31}] [expr {$y + 48}]	\
			[expr {$x + 180}] [expr {$y + 48}]	\
			[expr {$x + 180}] [expr {$y + 95}]	\
			-width 1 -fill {#0000FF} -tags txd_wire
		$connector_canvas create line			\
			[expr {$x + 46}] [expr {$y + 48}]	\
			[expr {$x + 45}] [expr {$y + 48}]	\
			-width 1 -fill {#0000FF} -tags txd_wire	\
			-arrow last
		$connector_canvas create line			\
			[expr {$x + 180}] [expr {$y + 120}]	\
			[expr {$x + 180}] [expr {$y + 105}]	\
			-width 1 -fill {#0000FF} -arrow last

		## RxD
		$connector_canvas create line			\
			[expr {$x + 31}] [expr {$y + 32}]	\
			[expr {$x + 220}] [expr {$y + 32}]	\
			[expr {$x + 220}] [expr {$y + 90}]	\
			[expr {$x + 250}] [expr {$y + 120}]	\
			-width 1 -fill {#0000FF} -tags rxd_wire	\
			-arrow last
		$connector_canvas create line			\
			[expr {$x + 74}] [expr {$y + 32}]	\
			[expr {$x + 75}] [expr {$y + 32}]	\
			-width 1 -fill {#0000FF} -tags rxd_wire	\
			-arrow last

		foreach wire {dcd dsr cts ri dtr rts txd rxd} {
			$connector_canvas bind ${wire}_wire <Enter> "$this wire_enter $wire"
			$connector_canvas bind ${wire}_wire <Leave> "$this wire_leave $wire"
		}
	}

	## Create top frame in the dialog window (connector_canvas (left) and configuration (right))
	 # @parm Widget target_frame - Parent frame
	 # @return void
	private method create_top_frame {target_frame} {

		#
		## Connector canvas
		#

		# Create canvas widget
		set connector_canvas [canvas $target_frame.canvas	\
			-width 280 -height 150 -bg ${::COMMON_BG_COLOR}		\
			-bd 0 -relief flat -highlightthickness 0	\
		]
		pack $connector_canvas -side left -padx 5 ;#-anchor sw

		# Fill in the connector canvas
		draw_connector 20 30
		draw_wires_and_controls 20 30



		#
		## Configuration frame
		#

		# Create labelframe
		set conf_frame [ttk::labelframe $target_frame.conf_frame\
			-padding 5					\
			-labelwidget [label $target_frame.conf_label	\
				-font $bold_font			\
				-compound left				\
				-text [mc "Port configuration"]		\
				-image ::ICONS::16::configure		\
			]						\
		]
		pack $conf_frame -side right -anchor nw -padx 5
		 # - Physical port
		grid [label $conf_frame.port_lbl	\
			-text [mc "Physical port"]	\
		] -row 1 -column 1 -sticky w
		set port_combobox [ttk::combobox $conf_frame.port_cb		\
			-width 12						\
			-validate all						\
			-validatecommand "$this port_combobox_validate %P"	\
			-exportselection 0					\
		]
		bind $port_combobox <<ComboboxSelected>>	\
			"$this port_combobox_accept"
		bind $port_combobox <Return> "$this port_combobox_accept"
		bind $port_combobox <KP_Enter> "$this port_combobox_accept"

		port_combobox_refresh
		grid $port_combobox -row 1 -column 2 -sticky w
		set_status_tip $port_combobox [mc "Special character file representing the target physical device"]
		grid [ttk::button $conf_frame.port_combobox_refresh_button	\
			-image ::ICONS::16::reload				\
			-command "$this port_combobox_refresh"			\
			-style Flat.TButton					\
		] -row 1 -column 3 -sticky w
		set_status_tip $conf_frame.port_combobox_refresh_button [mc "Refresh list of relevant devices"]
		 # - Baud rate
		grid [label $conf_frame.baud_lbl	\
			-text [mc "Baud rate"]		\
		] -row 3 -column 1 -sticky w
		set baud_cb [ttk::combobox $conf_frame.baud_cb	\
			-state readonly				\
			-width 6				\
			-exportselection 0			\
			-values $available_baud_rates		\
		]
		bind $baud_cb <<ComboboxSelected>>	\
			"$this change_port_config b \[$conf_frame.baud_cb get\]"
		set_status_tip $baud_cb [mc "Connection speed in bps"]
		grid $baud_cb -row 3 -column 2 -sticky w
		$conf_frame.baud_cb current [lsearch [$conf_frame.baud_cb cget -values] $baud_conf]
		 # - Parity
		grid [label $conf_frame.parity_lbl	\
			-text [mc "Parity"]		\
		] -row 4 -column 1 -sticky w
		set parity_cb [ttk::combobox $conf_frame.parity_cb	\
			-state readonly					\
			-width 6					\
			-exportselection 0				\
			-values [list		[mc "none"]		\
				[mc "odd"]	[mc "even"]		\
				[mc "mark"]	[mc "space"]		\
			]
		]
		bind $parity_cb <<ComboboxSelected>>	\
			"$this change_port_config p \[$conf_frame.parity_cb current\]"
		set_status_tip $parity_cb [mc "Parity"]
		grid $parity_cb -row 4 -column 2 -sticky w
		$conf_frame.parity_cb current [lsearch {n o e m s} $parity_conf]
		 # - Data bits
		grid [label $conf_frame.data_lbl	\
			-text [mc "Data bits"]		\
		] -row 5 -column 1 -sticky w
		set data_cb [ttk::combobox $conf_frame.data_cb	\
			-state readonly				\
			-width 1				\
			-values {5 6 7 8}			\
			-exportselection 0			\
		]
		bind $data_cb <<ComboboxSelected>>	\
			"$this change_port_config d \[$conf_frame.data_cb get\]"
		set_status_tip $data_cb [mc "Number of data bits"]
		grid $data_cb -row 5 -column 2 -sticky w
		$conf_frame.data_cb current [lsearch [$conf_frame.data_cb cget -values] $data_conf]
		 # - Stop bits
		grid [label $conf_frame.stop_lbl	\
			-text [mc "Stop bits"]		\
		] -row 6 -column 1 -sticky w
		set stop_cb [ttk::combobox $conf_frame.stop_cb	\
			-state readonly				\
			-width 1				\
			-values {1 2}				\
			-exportselection 0			\
		]
		bind $stop_cb <<ComboboxSelected>>	\
			"$this change_port_config s \[$conf_frame.stop_cb get\]"
		set_status_tip $stop_cb [mc "Number of stop bits"]
		grid $stop_cb -row 6 -column 2 -sticky w
		$conf_frame.stop_cb current [lsearch [$conf_frame.stop_cb cget -values] $stop_conf]
		# Bottom frame in configuration frame
		set bottom_frame [frame $conf_frame.bottom_frame]
		 # - Enable reception
		set enable_reception_chb [checkbutton $bottom_frame.enable_reception_chb\
			-text [mc "Enable reception"] -onvalue 1 -offvalue 0		\
			-command "$this reception_ena_dis"				\
			-variable "::RS232Debugger::enable_reception${obj_idx}"		\
		]
		set_status_tip $enable_reception_chb [mc "Display incoming data or discard them"]
		set ::RS232Debugger::enable_reception${obj_idx} $reception_enabled
		pack $enable_reception_chb -side left
		 # - Close connection
		set close_connection_button [ttk::button		\
			$bottom_frame.close_connection_button		\
			-text [mc "Close"]				\
			-compound left					\
			-width 5					\
			-image ::ICONS::16::fileclose			\
			-command "$this safely_terminate_connection"	\
		]
		set_status_tip $close_connection_button [mc "Terminate connection"]
		pack $close_connection_button -side right -padx 5

		grid $bottom_frame -row 7 -column 1 -sticky we -columnspan 3
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
		] -row 0 -column 1 -columnspan 2
		grid [label $target_frame.lbl_b		\
			-text [mc "Received data"]	\
			-compound left			\
			-image ::ICONS::16::forward	\
			-padx 15 -font $bold_font	\
		] -row 0 -column 3 -columnspan 2

		# Create hexadecimal editors
		set send_hexeditor [HexEditor #auto		\
			$target_frame.send_hexeditor 8 32 2	\
			hex 1 1 5 256				\
		]
		[$send_hexeditor getLeftView] configure -exportselection 0
		$send_hexeditor bindSelectionAction "$this hexeditor_selection s"
		grid $target_frame.send_hexeditor -row 1 -column 1 -columnspan 2

		set receive_hexeditor [HexEditor #auto		\
			$target_frame.receive_hexeditor 8 32 2	\
			hex 1 1 5 256				\
		]
		[$send_hexeditor getLeftView] configure -exportselection 0
		$receive_hexeditor bindSelectionAction "$this hexeditor_selection r"
		grid $target_frame.receive_hexeditor -row 1 -column 3 -columnspan 2

		# Create buttons "Send selected" and "Clear selected" in send part
		set send_selected_button [ttk::button		\
			$target_frame.send_selected_button	\
			-text [mc "Send selected"]		\
			-image ::ICONS::16::forward		\
			-command "$this send_selected"		\
			-compound left				\
			-state disabled				\
		]
		set clear_selected_snd_button [ttk::button	\
			$target_frame.clear_selected_snd_button	\
			-text [mc "Clear selected"]		\
			-image ::ICONS::16::eraser		\
			-command "$this clear_selected_snd"	\
			-compound left				\
			-state disabled				\
		]
		set_status_tip $send_selected_button [mc "Send selected data"]
		set_status_tip $clear_selected_snd_button [mc "Remove selected data"]
		grid $send_selected_button -row 2 -column 1 -sticky we
		grid $clear_selected_snd_button -row 2 -column 2 -sticky we

		# Create buttons "Receive here" and "Clear selected" in reception part
		set receive_here_button [ttk::button		\
			$target_frame.receive_here_button	\
			-text [mc "Receive here"]		\
			-image ::ICONS::16::down0		\
			-command "$this receive_here"		\
			-compound left				\
		]
		set clear_selected_rec_button [ttk::button	\
			$target_frame.clear_selected_rec_button	\
			-text [mc "Clear selected"]		\
			-image ::ICONS::16::eraser		\
			-command "$this clear_selected_rec"	\
			-compound left				\
			-state disabled				\
		]
		set_status_tip $receive_here_button [mc "Receive data on current cursor position"]
		set_status_tip $clear_selected_rec_button [mc "Remove selected data"]
		grid $receive_here_button -row 2 -column 3 -sticky we
		grid $clear_selected_rec_button -row 2 -column 4 -sticky we
	}

	## Accept new device file
	 # @return void
	public method port_combobox_accept {} {
		change_port_file [$port_combobox get]
	}

	## Validate contetnts of port combo box
	 # @parm String content - String to validate
	 # @return Bool - Allways true
	public method port_combobox_validate {content} {
		# Empty string
		if {![string length $content]} {
			$port_combobox configure -style TCombobox
			return 1
		}

		# Exiting file
		if {[file exists $content]} {
			if {$port_filename == $content} {
				$port_combobox configure -style RS232Debugger_FileInUse.TCombobox
			} else {
				$port_combobox configure -style RS232Debugger_FileFound.TCombobox
			}
		# Not exiting file
		} else {
			$port_combobox configure -style RS232Debugger_FileNotFound.TCombobox
		}

		return 1
	}

	## Refresh list of possible values on port combobox
	 # @return void
	public method port_combobox_refresh {} {
		if {!$::MICROSOFT_WINDOWS} { ;# POSIX way
			$port_combobox configure -values \
				[lsort -decreasing \
					[glob -directory {/dev} -nocomplain -type {c} -- {tty{S,USB}*}] \
				]

		} else { ;# Microsoft Widnows way
			set available_ms_windows_ports [list]

			for {set i 0} {$i < 10} {incr i} {
				if {[file exists "COM${i}"]} {
					lappend available_ms_windows_ports "COM${i}"
				}
			}

			$port_combobox configure -values $available_ms_windows_ports
		}
	}

	## Change current device file
	 # @parm String filename - Path to the new device file
	 # @return void
	private method change_port_file {filename} {
		# File name is the same at the one already in use -> abort
		if {$port_filename == $filename} {
			return
		}

		# Safely terminate current connection
		set channel_prev $channel
		safely_terminate_connection
		if {$channel_prev != {}} {
			catch {
				close $channel_prev
			}
		}

		## Try to open the device file
		if {[catch {
			if {!$::MICROSOFT_WINDOWS} { ;# POSIX way
				set channel [open $filename {RDWR BINARY NONBLOCK}]
			} { ;# MS Windows does not support NONBLOCK
				set channel [open $filename {RDWR BINARY}]
			}

		 # -> Fail
		} reason]} then {
			safely_terminate_connection
			after idle "
				set reason {$reason}
				tk_messageBox		\
					-parent $win	\
					-type ok	\
					-icon error	\
					-title {[mc {Access Error}]}	\
					-message \"[mc {Unable to open the specified file}]\n\n\${reason}\""
		 # -> Success
		} else {
			# Try to configure opened channel according to specified parameters
			if {[catch {
				fconfigure $channel	\
					-handshake none	\
					-buffersize 0	\
					-mode $baud_conf,$parity_conf,$data_conf,$stop_conf

				fileevent $channel readable "$this receive_data"

				set pool_timer [after $POOL_INTERVAL "catch {$this pool_ttystatus}"]
				set_tty_controls_state 1

			 # -> Fail
			} reason]} then {
				safely_terminate_connection
				after idle "
					tk_messageBox		\
						-parent $win	\
						-type ok	\
						-icon error	\
						-title {[mc {Access Error}]}	\
						-message \"[mc {Unable to use the specified file}]\""
			 # -> Success
			} else {
				$port_combobox configure -style RS232Debugger_FileInUse.TCombobox
				set port_filename $filename
			}
		}
	}

	## Modify comlink attributes
	 # @parm Char what	- Attribute ID
	 # @parm String value	- Attribute value
	 # @return void
	public method change_port_config {what value} {
		switch -- $what {
			{b} {	;# Baud rate
				set baud_conf $value
			}
			{p} {	;# Parity bit
				set parity_conf [lindex {n o e m s} $value]
			}
			{d} {	;# Data bits
				set data_conf $value
			}
			{s} {	;# Stop bits
				set stop_conf $value
			}
		}

		# Cancel if there is no channel opened
		if {$channel == {}} {
			return
		}

		# Change channel configuration
		if {[catch {
			fconfigure $channel -mode $baud_conf,$parity_conf,$data_conf,$stop_conf
		} reason]} {
			tk_messageBox		\
				-parent $win	\
				-type ok	\
				-icon error	\
				-title [mc "Unknown failure"]	\
				-message [mc "Unable to change port configuration"]
		}
	}

	## Handle selection event in hex editor
	 # @parm Char editor		- Editor ID
	 # @parm Bool anything_selected	- 1 == anything selected; 0 == Nothing selected
	 # @return void
	public method hexeditor_selection {editor anything_selected} {
		if {$anything_selected} {
			set state {normal}
		} else {
			set state {disabled}
		}

		if {$editor == {s}} {
			$send_selected_button		configure -state $state
			$clear_selected_snd_button	configure -state $state
		} else {
			$clear_selected_rec_button	configure -state $state
		}
	}

	## Clear selected data in send hex editor
	 # @return void
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

	## Send selected data over RS232 interface
	 # @return void
	public method send_selected {} {
		# Get range of text indexes determinating the selection
		set rangeofselection [$send_hexeditor getRangeOfSelection]
		if {$rangeofselection == {}} {
			return
		}

		# Abort if there was no channel opened
		if {$channel == {}} {
			tk_messageBox			\
				-parent $win		\
				-title [mc "IO Error"]	\
				-type ok -icon warning	\
				-message [mc "No port opened."]
			return
		}

		# Generate binary data from the selected hexadecimal string
		set data {}
		set start_cell [lindex $rangeofselection 0]
		set end_cell [lindex $rangeofselection 1]
		foreach value [$send_hexeditor get_values $start_cell $end_cell] {
			if {$value == {}} {
				continue
			}
			append data [format %c $value]
		}

		# Send the generated binary data
		if {[catch {
			puts -nonewline $channel $data
			flush $channel
		} reason]} {
			tk_messageBox			\
				-parent $win		\
				-title [mc "IO Error"]	\
				-type ok -icon warning	\
				-message [mc "Unable to send the data\n\n%s" $reason]
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

	## Receive data from the channel
	 # This function is trigered automatically by fileevent facitily
	 # @return void
	public method receive_data {} {
		# Read binary data
                if {[catch {
                    set data [read $channel]
                }]} then {
                        unknown_port_io_error
                        return
                }

		# Discard the data if reception is not enabled
		if {!$reception_enabled} {
			return
		}

		# Check if the data has non zero length
		if {![string length $data]} {
			unknown_port_io_error
			return
		}

		# Load the data into hexadecimal editor
		set len [string bytelength $data]
		$receive_hexeditor clearBgHighlighting 1
		for {set i 0} {$i < $len} {incr i} {
			if {$reception_address >= 256} {
				receive_buffer_overflow_warning_dialog
				break
			}

			scan [string index $data $i] %c byte
			$receive_hexeditor setValue $reception_address $byte

			incr reception_address
		}
		$receive_hexeditor set_bg_hg [expr {$reception_address - 1}] 1 1
		$receive_hexeditor seeCell [expr {$reception_address - 1}]
	}

	## Diaply dialog "Not enough space in the receive buffer !"
	 # @return void
	private method receive_buffer_overflow_warning_dialog {} {
		if {[winfo exists .data_lost_dialog]} {
			return
		}
		set dialog [toplevel .data_lost_dialog -class [mc "Error message"] -bg ${::COMMON_BG_COLOR}]

		pack [label $dialog.label					\
			-font $bold_font -compound left -padx 5			\
			-text [mc "Not enough space in the receive buffer !"]	\
			-image ::ICONS::22::stop				\
		] -fill x -pady 5 -padx 5

		pack [frame $dialog.frm] -pady 5
		pack [ttk::button $dialog.frm.ok_button	\
			-text [mc "Ok"]			\
			-command "
				grab release $dialog
				destroy $dialog
			" \
		] -side left

		pack [ttk::separator $dialog.sep -orient horizontal] -fill x -pady 10
		pack [checkbutton $dialog.enable_reception_chb				\
			-text [mc "Keep reception enabled"] -onvalue 1 -offvalue 0	\
			-command "$this reception_ena_dis"				\
			-variable "::RS232Debugger::enable_reception${obj_idx}"		\
		] -anchor w

		# Set window attributes
		wm iconphoto $dialog ::ICONS::16::status_unknown
		wm title $dialog [mc "Data lost"]
		wm resizable $dialog 0 0
		wm transient $dialog $win
		catch {grab $dialog}
		wm protocol $dialog WM_DELETE_WINDOW "
			grab release $dialog
			destroy $dialog
		"
		raise $dialog
		focus -force $dialog.frm.ok_button
		tkwait window $dialog
	}

	## Clear selected data in receive hex editor
	 # @return void
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

	## Enable/Disable reception
	 # @return void
	public method reception_ena_dis {} {
		set reception_enabled [subst -nocommands "\$::RS232Debugger::enable_reception${obj_idx}"]
	}

	## Read TTY status from the interface and update GUI accordingly
	 # @return void
	public method pool_ttystatus {} {
		# Setup the pool timer
		set pool_timer [after $POOL_INTERVAL "catch {$this pool_ttystatus}"]

		# Read TTY status
		if {[catch {
			set ttystatus [fconfigure $channel -ttystatus]
		}]} then {
			unknown_port_io_error
			return
		}

		# Check whether any change occurred
		if {$prev_tty_status(0) == $ttystatus} {
			return
		} else {
			set prev_tty_status(0) $ttystatus
		}

		# Transform values read to these four variables:
		set cts	{}
		set dsr	{}
		set ri	{}
		set dcd	{}
		set ts_len [llength $ttystatus]
		for {set i 0; set j 1} {$i < $ts_len} {incr i 2; incr j 2} {
			set key [lindex $ttystatus $i]
			set val [lindex $ttystatus $j]

			switch -- $key {
				{CTS}	{set cts $val}
				{DSR}	{set dsr $val}
				{RING}	{set ri $val}
				{DCD}	{set dcd $val}
			}
		}

		# Update GUI accordingly
		show_new_ttystatus $cts $dsr $ri $dcd
	}

	## Show new TTY status in the GUI
	 # @parm Bool cts	- CTS line state
	 # @parm Bool dsr	- DSR line state
	 # @parm Bool ri	- RI line state
	 # @parm Bool dcd	- DCD line state
	 # @return void
	private method show_new_ttystatus args {
		foreach signal {cts dsr ri dcd} value $args {
			if {$prev_tty_status($signal) == $value} {
				continue
			} else {
				set prev_tty_status($signal) $value
			}

			switch -- $value {
				0 {
					set color {#FF0000}
					set image ledred
				}
				1 {
					set color {#00FF00}
					set image ledgreen
				}
				default {
					set color {#888888}
					set image ledgray
				}
			}

			$connector_canvas itemconfigure ${signal}_wire -fill $color
			$leds($signal) configure -image ::ICONS::16::$image
		}
	}

	## Report an unknown IO error occurred on the interface
	 # Plus disable reception and safely terminate connection
	 # @return void
	private method unknown_port_io_error {} {
		# Disable reception
		set reception_enabled 0
		set ::RS232Debugger::enable_reception${obj_idx} 0

		# Safely terminate connection
		safely_terminate_connection
		$port_combobox configure -style RS232Debugger_FileFound.TCombobox

		# Display the error message
		tk_messageBox			\
			-parent $win		\
			-title [mc "IO Error"]	\
			-type ok -icon warning	\
			-message [mc "There is something wrong with the port. Closing connection and disabling reception on this channel!"]

		update
	}

	## Safely terminate connection to the HW interface
	 # @return void
	public method safely_terminate_connection {} {
		catch {fileevent $channel readable {}}
		catch {
			after cancel $pool_timer
		}
		set prev_tty_status(0) {}
		set channel {}
		set port_filename {}

		show_new_ttystatus {} {} {} {}
		set_tty_controls_state 0
		$port_combobox configure -style RS232Debugger_FileFound.TCombobox
	}

	## Enable or disable TTY controls
	 # @parm Bool enabled - 1 == Enable; 0 == Disable
	 # @return void
	private method set_tty_controls_state {enabled} {
		if {$enabled} {
			set state {normal}
			set state2 {readonly}
			set_tty_controls_to_defaults
		} else {
			set state {disabled}
			set state2 {disabled}
			set_tty_controls_to_unknown_state
		}

		$dtr_button configure -state $state
		$rts_button configure -state $state
		$break_button configure -state $state

		$enable_reception_chb configure -state $state
		$close_connection_button configure -state $state

		$baud_cb configure -state $state2
		$parity_cb configure -state $state2
		$data_cb configure -state $state2
		$stop_cb configure -state $state2
	}

	## Set tty controls to defaults
	 # @return void
	private method set_tty_controls_to_defaults {} {
		set_new_tty_status dtr 0
		set_new_tty_status rts 0
		set_new_tty_status break 0
	}

	## Set tty controls to unknown state
	 # @return void
	private method set_tty_controls_to_unknown_state {} {
		set_new_tty_status dtr {}
		set_new_tty_status rts {}
		set_new_tty_status break {}
	}

	## Invert tty status bit
	 # @parm String wire - Bit/Wire ID
	 # @return void
	public method invert_tty_status_bit {wire} {
		if {$prev_tty_status($wire) == {}} {
			return
		}

		set_new_tty_status $wire [expr {!$prev_tty_status($wire)}]
	}

	## Change color of the specified color
	 # @parm String wire	- Wire ID
	 # @parm String value	- New value (e.g. 0 or {})
	 # @return void
	private method set_new_tty_status {wire value} {
		set prev_tty_status($wire) $value

		switch -- $value {
			0 {	;# Loical 0
				if {$wire == {break}} {
					[subst -nocommands "\${${wire}_button}"] configure -text {Break}	\
						-style RS232Debugger_SignalTxDFalse.TButton
					$connector_canvas itemconfigure txd_wire -fill {#0000FF}
				} else {
					[subst -nocommands "\${${wire}_button}"] configure -text {1}	\
						-style RS232Debugger_SignalNormalFalse.TButton
					$connector_canvas itemconfigure ${wire}_wire -fill {#FF0000}
				}
			}
			1 {	;# Logical 1
				if {$wire == {break}} {
					[subst -nocommands "\${${wire}_button}"] configure -text {BREAK}	\
						-style RS232Debugger_SignalTxDTrue.TButton
					$connector_canvas itemconfigure txd_wire -fill {#00FF00}
				} else {
					[subst -nocommands "\${${wire}_button}"] configure -text {0}	\
						-style RS232Debugger_SignalNormalTrue.TButton
					$connector_canvas itemconfigure ${wire}_wire -fill {#00FF00}
				}
			}
			default {	;# Unknown state
				if {$wire == {break}} {
					[subst -nocommands "\${${wire}_button}"] configure -text {Break}	\
						-style RS232Debugger_SignalAllDefault.TButton
					$connector_canvas itemconfigure txd_wire -fill {#0000FF}
				} else {
					[subst -nocommands "\${${wire}_button}"] configure -text {-}	\
						-style RS232Debugger_SignalAllDefault.TButton
					$connector_canvas itemconfigure ${wire}_wire -fill {#888888}
				}
				return
			}
		}

		if {[catch {
			fconfigure $channel -ttycontrol [list $wire $value]
		}]} then {
			unknown_port_io_error
			return
		}
	}

	## Handle "<Enter>" event on wire
	 # @parm String wire - Wire ID
	 # @return void
	public method wire_enter {wire} {
		$connector_canvas itemconfigure ${wire}_wire -width 2
		$connector_canvas itemconfigure ${wire}_pin -fill {#000000}
		$connector_canvas itemconfigure ${wire}_num -font $tiny_font_bold

		set text {}
		switch -- $wire {
			{gnd} {set text [mc "RS232 pin: GND -- Common ground"]}
			{dcd} {set text [mc "RS232 pin: DCD -- Carrier Detect"]}
			{dsr} {set text [mc "RS232 pin: DSR -- Data Set Ready"]}
			{cts} {set text [mc "RS232 pin: CTS -- Clear To Send"]}
			{ri}  {set text [mc "RS232 pin: RI  -- Ring Indicator"]}
			{dtr} {set text [mc "RS232 pin: DTR -- Data Terminal Ready"]}
			{rts} {set text [mc "RS232 pin: RTS -- Request To Send"]}
			{txd} {set text [mc "RS232 pin: TxD -- Transmitted Data"]}
			{rxd} {set text [mc "RS232 pin: RxD -- Received Data"]}
		}
		$status_bar_label configure -text $text
	}

	## Handle "<Leave>" event on wire
	 # @parm String wire - Wire ID
	 # @return void
	public method wire_leave {wire} {
		$connector_canvas itemconfigure ${wire}_wire -width 1
		$connector_canvas itemconfigure ${wire}_pin -fill ${::COMMON_BG_COLOR}
		$connector_canvas itemconfigure ${wire}_num -font $tiny_font

		$status_bar_label configure -text {}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

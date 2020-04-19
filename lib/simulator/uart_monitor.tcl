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
if { ! [ info exists _UART_MONITOR_TCL ] } {
set _UART_MONITOR_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# UART monitor
# -------------------------------------------------------------------------

class UARTMonitor {

	public common geometry		${::CONFIG(UART_MON_GEOMETRY)}	;# Last window geometry
	public common uart_mon_count	0				;# Counter of intances

	 # Font: Tiny normal font
	public common tiny_font [font create		\
		-family {helvetica}		\
		-size [expr {int(-9 * $::font_size_factor)}]	\
		-weight {normal}	\
	]
	 # Font: Big bold font
	public common big_font [font create		\
		-family {helvetica}		\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight {bold}	\
	]
	 # Font: Normal font
	public common normal_font [font create		\
		-family {helvetica}		\
		-size [expr {int(-11 * $::font_size_factor)}]	\
		-weight {normal}	\
	]
	 # Font:
	public common normal_fixed_font [font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-11 * $::font_size_factor)}]	\
		-weight {normal}				\
	]
	 # Font:
	public common bold_fixed_font [font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-11 * $::font_size_factor)}]	\
		-weight {bold}				\
	]

	public common rect_size	12
	public common empty_fill	{#888888}
	public common empty_outline	{#AAAAAA}

	public common MAX_G_LOG_LENGTH		100		;# Int:
	public common MAX_D_LOG_LENGTH		100		;# Int:

	private variable dialog_opened		0	;# Bool: Dialog window opened
	private variable win				;# Widget: Dialog window

	private variable status_bar		1
	private variable rxd_frame
	private variable txd_frame

	private variable general_log
	private variable general_log_length
	private variable data_transfer_log
	private variable data_transfer_log_length
	private variable canvas
	private variable bit_rect
	private variable uart_value_label
	private variable shift_reg
	private variable shift_reg_bits_written
	private variable bit

	private variable graph_position
	private variable graph_prev_states
	private variable graph_elements

	constructor {} {
		array set data_transfer_log_length {
			r 0	t 0
		}
		array set general_log_length {
			r 0	t 0
		}
		array set shift_reg {
			r 0	t 0
		}
		array set shift_reg_bits_written {
			r 0	t 0
		}
		array set graph_position {
			r 0	t 0
		}
		array set graph_prev_states {
			t 1	r 1
		}
		array set graph_elements {
			t {}	r {}
		}
		array set bit {
			fe	0	sm0	0
			sm1	0	sm2	0
			ren	0	ti	0
			ri	0	smod1	0
			tclk	0	rclk	0
		}
	}

	destructor {
		uart_monitor_close
	}

	## Invoke interrupt monitor window
	 # @return void
	public method uart_monitor_invoke_dialog {} {
		set win [toplevel .uartmonitor${uart_mon_count}]
		incr uart_mon_count

		set main_frame [frame $win.main_frame]
		set status_bar [label $win.status_bar]

		# --------------------------------------------------------------
		# RECEIVER PART
		# --------------------------------------------------------------
		grid [label $main_frame.r_header_lbl	\
			-font $big_font			\
			-text [mc "RxD line"]		\
		] -row 0 -column 1 -sticky w -padx 0 -columnspan 2 -sticky we
		 # Mode:
		grid [label $main_frame.r_mode_lbl	\
			-text [mc "Mode:"]		\
		] -row 1 -column 1 -sticky w -padx 5
		set uart_value_label(r_mode) [label $main_frame.r_mode_v_lbl]
		grid $uart_value_label(r_mode) -row 1 -column 2 -sticky w -padx 5
		 # Line function:
		grid [label $main_frame.r_lf_lbl	\
			-text [mc "Line function:"]	\
		] -row 2 -column 1 -sticky w -padx 5
		set uart_value_label(r_lf) [label $main_frame.r_lf_v_lbl]
		grid $uart_value_label(r_lf) -row 2 -column 2 -sticky w -padx 5
		 # BR Generator:
		grid [label $main_frame.r_brg_lbl	\
			-text [mc "BR Generator:"]	\
		] -row 3 -column 1 -sticky w -padx 5
		set uart_value_label(r_brg) [label $main_frame.r_brg_v_lbl]
		grid $uart_value_label(r_brg) -row 3 -column 2 -sticky w -padx 5
		 # BRG prescaler:
		grid [label $main_frame.r_brgp_lbl	\
			-text [mc "BRG prescaler:"]	\
		] -row 4 -column 1 -sticky w -padx 5
		set uart_value_label(r_brgp) [label $main_frame.r_brgp_v_lbl]
		grid $uart_value_label(r_brgp) -row 4 -column 2 -sticky w -padx 5
		 # Resulting bdps:
		grid [label $main_frame.r_rbdps_lbl	\
			-text [mc "Resulting bdps:"]	\
		] -row 5 -column 1 -sticky w -padx 5
		set uart_value_label(r_rbdps) [label $main_frame.r_rbdps_v_lbl]
		grid $uart_value_label(r_rbdps) -row 5 -column 2 -sticky w -padx 5
		 # State:
		grid [label $main_frame.r_state_lbl	\
			-text [mc "State:"]		\
		] -row 6 -column 1 -sticky w -padx 5
		set uart_value_label(r_state) [label $main_frame.r_state_v_lbl]
		grid $uart_value_label(r_state) -row 6 -column 2 -sticky w -padx 5

		set canvas(r) [canvas $main_frame.r_canvas	\
			-width 240				\
			-height 175				\
			-bg $::COMMON_BG_COLOR			\
			-highlightthickness 0			\
		]
		fill_canvas r
		grid $canvas(r) -row 8 -column 1 -columnspan 2 -sticky we

		set data_transfer_log(r) [text $main_frame.r_data_transfer_log	\
			-height 4						\
			-width 0						\
			-bd 0							\
			-bg $::COMMON_BG_COLOR					\
			-highlightthickness 0					\
			-font $normal_fixed_font				\
			-wrap none						\
			-xscrollcommand [list $main_frame.r_stl_scrollbar set]	\
		]
		$data_transfer_log(r) tag configure tag_bold -font $bold_fixed_font
		$data_transfer_log(r) insert end [mc "HEX   \nDEC   \nOCT   \nASCII "]
		$data_transfer_log(r) configure -state disabled
		for {set i 1} {$i <= 4} {incr i} {
			$data_transfer_log(r) tag add tag_bold $i.0 $i.5
		}
		grid $data_transfer_log(r) -row 9 -column 1 -columnspan 2 -sticky we
		grid [ttk::scrollbar $main_frame.r_stl_scrollbar	\
			-orient horizontal				\
			-command [list $data_transfer_log(r) xview]	\
		]  -row 10 -column 1 -columnspan 2 -sticky we

		set general_log_frame [frame $main_frame.r_general_log_frame]
		set general_log(r) [text $general_log_frame.general_log		\
			-height 4						\
			-width 0						\
			-yscrollcommand [list $general_log_frame.scrollbar set]	\
			-state disabled						\
		]
		set general_log_sc_bar [ttk::scrollbar $general_log_frame.scrollbar	\
			-orient vertical						\
			-command [list $general_log(r) yview]				\
		]
		pack $general_log_sc_bar -side right -fill y
		pack $general_log(r) -side left -fill both -expand 1
		grid $general_log_frame -row 11 -column 1 -columnspan 2 -sticky wens -pady 2

		# --------------------------------------------------------------
		# TRANSMITTER PART
		# --------------------------------------------------------------
		grid [label $main_frame.t_header_lbl	\
			-font $big_font			\
			-text [mc "TxD line"]		\
		] -row 0 -column 4 -sticky w -padx 0 -columnspan 2 -sticky we
		 # Mode:
		grid [label $main_frame.t_mode_lbl	\
			-text [mc "Mode:"]	\
		] -row 1 -column 4 -sticky w -padx 5
		set uart_value_label(t_mode) [label $main_frame.t_mode_v_lbl]
		grid $uart_value_label(t_mode) -row 1 -column 5 -sticky w -padx 5
		 # Line function:
		grid [label $main_frame.t_lf_lbl	\
			-text [mc "Line function:"]	\
		] -row 2 -column 4 -sticky w -padx 5
		set uart_value_label(t_lf) [label $main_frame.t_lf_v_lbl]
		grid $uart_value_label(t_lf) -row 2 -column 5 -sticky w -padx 5
		 # BR Generator:
		grid [label $main_frame.t_brg_lbl	\
			-text [mc "BR Generator:"]	\
		] -row 3 -column 4 -sticky w -padx 5
		set uart_value_label(t_brg) [label $main_frame.t_brg_v_lbl]
		grid $uart_value_label(t_brg) -row 3 -column 5 -sticky w -padx 5
		 # BRG prescaler:
		grid [label $main_frame.t_brgp_lbl	\
			-text [mc "BRG prescaler:"]	\
		] -row 4 -column 4 -sticky w -padx 5
		set uart_value_label(t_brgp) [label $main_frame.t_brgp_v_lbl]
		grid $uart_value_label(t_brgp) -row 4 -column 5 -sticky w -padx 5
		 # Resulting bdps:
		grid [label $main_frame.t_rbdps_lbl	\
			-text [mc "Resulting bdps:"]	\
		] -row 5 -column 4 -sticky w -padx 5
		set uart_value_label(t_rbdps) [label $main_frame.t_rbdps_v_lbl]
		grid $uart_value_label(t_rbdps) -row 5 -column 5 -sticky w -padx 5
		 # State:
		grid [label $main_frame.t_state_lbl	\
			-text [mc "State:"]		\
		] -row 6 -column 4 -sticky w -padx 5
		set uart_value_label(t_state) [label $main_frame.t_state_v_lbl]
		grid $uart_value_label(t_state) -row 6 -column 5 -sticky w -padx 5

		set canvas(t) [canvas $main_frame.t_canvas	\
			-width 240				\
			-height 175				\
			-bg $::COMMON_BG_COLOR			\
			-highlightthickness 0			\
		]
		fill_canvas t
		grid $canvas(t) -row 8 -column 4 -columnspan 2 -sticky nw

		set data_transfer_log(t) [text $main_frame.t_data_transfer_log	\
			-height 4						\
			-width 0						\
			-bd 0							\
			-bg $::COMMON_BG_COLOR					\
			-highlightthickness 0					\
			-font $normal_fixed_font				\
			-wrap none						\
			-xscrollcommand [list $main_frame.t_stl_scrollbar set]	\
		]
		$data_transfer_log(t) tag configure tag_bold -font $bold_fixed_font
		$data_transfer_log(t) insert end [mc "HEX   \nDEC   \nOCT   \nASCII "]
		$data_transfer_log(t) configure -state disabled
		for {set i 1} {$i <= 4} {incr i} {
			$data_transfer_log(t) tag add tag_bold $i.0 $i.5
		}
		grid $data_transfer_log(t) -row 9 -column 4 -columnspan 2 -sticky we
		grid [ttk::scrollbar $main_frame.t_stl_scrollbar	\
			-orient horizontal				\
			-command [list $data_transfer_log(t) xview]	\
		]  -row 10 -column 4 -columnspan 2 -sticky we

		set general_log_frame [frame $main_frame.t_general_log_frame]
		set general_log(t) [text $general_log_frame.general_log		\
			-height 4						\
			-width 0						\
			-yscrollcommand [list $general_log_frame.scrollbar set]	\
			-state disabled						\
		]
		set general_log_sc_bar [ttk::scrollbar $general_log_frame.scrollbar	\
			-orient vertical						\
			-command [list $general_log(t) yview]				\
		]
		pack $general_log_sc_bar -side right -fill y
		pack $general_log(t) -side left -fill both -expand 1
		grid $general_log_frame -row 11 -column 4 -columnspan 2 -sticky wens -pady 2

		grid [ttk::separator $main_frame.sep -orient vertical] -row 0 -column 3 -rowspan 12 -padx 2 -sticky ns
		pack $main_frame -fill y -padx 2 -pady 2 -anchor nw -expand 1

		# Pack main frame and create bottom frame
		pack $main_frame -fill both -expand 1
		pack [ttk::separator $win.sep -orient horizontal]	\
			-fill x -pady 1
		pack $status_bar -side left -fill x -padx 5
		pack [ttk::button $win.close_but			\
			-text [mc "Close"]				\
			-compound left					\
			-command [list $this uart_monitor_close]	\
			-image ::ICONS::16::button_cancel 		\
		] -side right -pady 2 -padx 5
		uart_monitor_set_status_tip $win.close_but [mc "Close this dialog window"]

		# Set window attributes
		wm iconphoto $win ::ICONS::16::__blockdevice
		wm title $win "[mc {UART Monitor}] - [$this cget -projectName] - MCU 8051 IDE"
		wm minsize $win 500 500
		wm resizable $win 1 1
		wm protocol $win WM_DELETE_WINDOW [list $this uart_monitor_close]
		bindtags $win [list $win Toplevel all .]

		update idletasks
		if {$geometry != {}} {
			regsub {\+\d+\+\d+} $geometry [format {+%d+%d} [winfo width $win] [winfo height $win]] geometry
			wm geometry $win $geometry
		}

		set dialog_opened 1

# 		#< DEBUG !!!
# 		uart_monitor_byte_received	100 111 132
# 		uart_monitor_byte_transmitted	101 112 122
#
		uart_monitor_refresh_configuration
		uart_monitor_write_to_log r "THIS TOOL IS NOT FUNCTIONAL YET!"
		uart_monitor_write_to_log t "THIS TOOL IS NOT FUNCTIONAL YET!"
#
# 		uart_monitor_shift_reg_input r 1 1
# 		uart_monitor_shift_reg_input r 1 0
# 		uart_monitor_shift_reg_input r 1 0
# 		uart_monitor_shift_reg_input r 1 1
# 		uart_monitor_shift_reg_input r 1 1
#
# 		uart_monitor_shift_reg_input t 0 1
# 		uart_monitor_shift_reg_input t 0 0
# 		uart_monitor_shift_reg_input t 0 0
# 		uart_monitor_shift_reg_input t 0 1
# 		uart_monitor_shift_reg_input t 0 1
#
# 		uart_monitor_update_sbuf r
# 		uart_monitor_update_sbuf t
#
# 		uart_monitor_graph_draw t {1 0 1 0 1}
# 		uart_monitor_graph_draw t {1 0 1 1 1}
# 		uart_monitor_graph_draw t {0 1 1 1 1}
# 		uart_monitor_graph_draw t {1 0 1 1 1}
# 		uart_monitor_graph_draw t {1 0 1 1 0}
# 		uart_monitor_graph_draw t {1 0 1 0 1}
# 		uart_monitor_graph_draw t {1 0 1 1 1}
# 		uart_monitor_graph_draw t {0 1 1 1 1}
# 		uart_monitor_graph_draw t {1 0 1 1 1}
# 		uart_monitor_graph_draw t {1 0 1 1 0}
# 		#> DEBUG !!!
	}

	public method uart_monitor_close {} {
		if {!$dialog_opened} {
			return
		}

		set geometry		[wm geometry $win]
		set dialog_opened	0

		if {[winfo exists $win]} {
			destroy $win
		}
	}

	## Set status bar tip for certain widget
	 # @parm Widget widget	- Some button or label ...
	 # @parm String text	- Status tip
	 # @return void
	private method uart_monitor_set_status_tip {widget text} {
		bind $widget <Enter> [list $status_bar configure -text $text]
		bind $widget <Leave> [list $status_bar configure -text {}]
	}

	private method fill_canvas {side} {
		set labels [list 8 7 6 5 4 3 2 1 0]

		set x 5
		set j 0
		for {set i 0} {$i < 10} {incr i} {
			set y 20
			set bit_rect(s,$side,$i) [$canvas($side) create rectangle $x $y	\
				[expr {$x + $rect_size}] [expr {$y + $rect_size}]	\
				-fill $empty_fill -outline $empty_outline		\
			]

			if {($side == {r} && $i > 0 && $i < 10) || ($side == {t} && $i >= 0 && $i < 9)} {
				if {$j == 1} {
					incr x 3
				}
				set y 50
				set bit_rect(b,$side,$j) [$canvas($side) create rectangle $x $y	\
					[expr {$x + $rect_size}] [expr {$y + $rect_size}]	\
					-fill $empty_fill -outline $empty_outline		\
				]
				$canvas($side) create text		\
					[expr {$x + ($rect_size / 2)}]	\
					[expr {$y + ($rect_size / 2)}]	\
					-text [lindex $labels $j]	\
					-font $tiny_font
				if {$j == 1} {
					incr x -3
				}
				incr j
			}

			incr x $rect_size
			incr x 2
		}

		$canvas($side) create text 5 5 -anchor nw -font $normal_font -text [mc "The shift register:"]
		$canvas($side) create text 5 35 -anchor nw -font $normal_font -text "SBUF [string toupper $side]:"

		# --------------------------------------------------------------

		if {$side == {r}} {
			set graph_label [list	\
				[mc "RxD"]	\
				[mc "RI"]	\
				[mc "ALE"]	\
				[mc "SHIFT"]	\
				[mc "SBUF"]	\
			]
		} else {
			set graph_label [list	\
				[mc "TxD"]	\
				[mc "TI"]	\
				[mc "ALE"]	\
				[mc "SHIFT"]	\
				[mc "SBUF"]	\
			]
		}
		for {set y 0} {$y < 5} {incr y} {
			set y_0 [expr {75 + $y * 20}]
			set y_1 [expr {$y_0 + 15}]

			for {set x 45} {$x <= 235} {incr x 5} {
				$canvas($side) create line $x $y_0 $x $y_1 -fill {#AAAAAA} -tags grid -dash .
			}

			$canvas($side) create text 5 $y_0 -anchor nw -font $bold_fixed_font -text [lindex $graph_label $y]

			incr y_0 -3
			$canvas($side) create line 45 $y_0 235 $y_0 -fill {#AAAAAA} -tags grid
		}
	}

	public method uart_monitor_refresh_configuration {} {
		if {!$dialog_opened} {
			return
		}

		set pcon [$this getSfrDEC $::Simulator_ENGINE::symbol(PCON)]
		set scon [$this getSfrDEC $::Simulator_ENGINE::symbol(SCON)]

		set bit(fe)  [$this sim_engine_get_FE]
		set bit(sm0) [$this sim_engine_get_SM0]
		set bit(sm1) [expr {$scon & 0x40}]
		set bit(sm2) [expr {$scon & 0x20}]
		set bit(ren) [expr {$scon & 0x10}]
		set bit(ti)  [expr {$scon & 0x02}]
		set bit(ri)  [expr {$scon & 0x01}]

		set bit(smod1) [expr {$pcon & 0x80}]

		if {[$this get_feature_available t2]} {
			set bit(tclk) [$this getBit $::Simulator_ENGINE::symbol(TCLK)]
			set bit(rclk) [$this getBit $::Simulator_ENGINE::symbol(RCLK)]
		} else {
			set bit(tclk) 0
			set bit(rclk) 0
		}

		## Determinate mode of operation
		 # Mode 0
		if {!$bit(sm0) && !$bit(sm1)} {
			set mode [mc "0 (8-bit Shift register)"]
		 # Mode 1
		} elseif {!$bit(sm0) && $bit(sm1)} {
			set mode [mc "1 (8-bit UART)"]
		 # Mode 2
		} elseif {$bit(sm0) && !$bit(sm1)} {
			set mode [mc "2 (9-bit UART)"]
		 # Mode 3
		} elseif {$bit(sm0) && $bit(sm1)} {
			set mode [mc "3 (9-bit UART)"]
		}

		## Determinate line functions
		if {!$bit(sm0) && !$bit(sm1)} {
			set r_lf [mc "Data input/output"]
			set t_lf [mc "Shift clock output"]
		} else {
			set r_lf [mc "Data input"]
			set t_lf [mc "Data output"]
		}

		## Determinate source of baud rate clock
		if {$bit(sm1)} {
			if {$bit(rclk)} {
				set r_brg [mc "Timer 2"]
			} else {
				set r_brg [mc "Timer 1"]
			}
			if {$bit(tclk)} {
				set t_brg [mc "Timer 2"]
			} else {
				set t_brg [mc "Timer 1"]
			}
		} else {
			set r_brg [mc "Master clock"]
			set t_brg [mc "Master clock"]
		}

		## Determinate resulting baud rate
		set r_rbdps [determinate_baud_rate t]
		set t_rbdps [determinate_baud_rate t]

		## Determinate state of the interface
		set r_state [mc "WAITING"]
		set t_state [mc "WAITING"]

		# --------------------------------------------------------------
		# RECEIVER PART
		# --------------------------------------------------------------
		$uart_value_label(r_mode) configure -text $mode
		$uart_value_label(r_lf) configure -text $r_lf
		$uart_value_label(r_brg) configure -text $r_brg
		$uart_value_label(r_rbdps) configure -text $r_rbdps
		$uart_value_label(r_state) configure -text $r_state

		# --------------------------------------------------------------
		# TRANSMITTER PART
		# --------------------------------------------------------------
		$uart_value_label(t_mode) configure -text $mode
		$uart_value_label(t_lf) configure -text $t_lf
		$uart_value_label(t_brg) configure -text $t_brg
		$uart_value_label(t_rbdps) configure -text $t_rbdps
		$uart_value_label(t_state) configure -text $t_state
	}

	private method determinate_baud_rate {side} {
		# RxD side
		if {$side == {r}} {
			# Timer 2
			if {$bit(rclk)} {
				return [mc "Determinated by timer 2"]

			# Timer 1
			} else {
				set tmod [$this getSfrDEC $::Simulator_ENGINE::symbol(PCON)]
				if {$tmod & 0x40} {
					return [mc "Unknown"]
				}
				set clock_f [expr {1000 * [$this getEngineClock] * (1 + ([$this get_X2] ? 1 : 0))}]
				set mode [expr {($tmod & 0x30) >> 4}]
				switch -- $mode {
					0 {
						return [expr {$clock_f / 8192.0}]
					}
					1 {
						return [expr {$clock_f / 65536.0}]
					}
					2 {
						set th1 [$this getSfrDEC $::Simulator_ENGINE::symbol(TH1)]
						return [expr {$clock_f / (256.0 - $th1)}]
					}
					3 {
						return 0
					}
				}
			}

		# TxD side
		} else {
			# Timer 2
			if {$bit(tclk)} {
				return [mc "Determinated by timer 2"]

			# Timer 1
			} else {
				set tmod [$this getSfrDEC $::Simulator_ENGINE::symbol(PCON)]
				if {$tmod & 0x40} {
					return [mc "Unknown"]
				}
				set clock_f [expr {1000 * [$this getEngineClock] * (1 + ([$this get_X2] ? 1 : 0))}]
				set mode [expr {($tmod & 0x30) >> 4}]
				switch -- $mode {
					0 {
						return [expr {$clock_f / 8192.0}]
					}
					1 {
						return [expr {$clock_f / 65536.0}]
					}
					2 {
						set th1 [$this getSfrDEC $::Simulator_ENGINE::symbol(TH1)]
						return [expr {$clock_f / (256.0 - $th1)}]
					}
					3 {
						return 0
					}
				}
			}
		}

		return [mc "Unknown"]
	}

	public method uart_monitor_update_prescaler {side value} {
		if {!$dialog_opened} {
			return
		}

		$uart_value_label(${side}_brgp) configure -text $value
	}

	public method uart_monitor_byte_received {args} {
		if {!$dialog_opened} {
			return
		}

		foreach byte $args {
			write_to_data_transfer_log r $byte
		}
	}

	public method uart_monitor_byte_transmitted {args} {
		if {!$dialog_opened} {
			return
		}

		foreach byte $args {
			write_to_data_transfer_log t $byte
		}
	}

	private method write_to_data_transfer_log {side byte} {
		if {!$dialog_opened} {
			return
		}

		$data_transfer_log($side) configure -state normal
		if {$data_transfer_log_length($side) == $MAX_D_LOG_LENGTH} {
			for {set i 1} {$i < 5} {incr i} {
				$data_transfer_log($side) delete $i.4 $i.6
			}
			incr data_transfer_log_length($side) -1
		}

		set i [expr {6 + $data_transfer_log_length($side) * 4}]

		$data_transfer_log($side) insert 1.$i [format {%3X } $byte]
		$data_transfer_log($side) insert 2.$i [format {%3d } $byte]
		$data_transfer_log($side) insert 3.$i [format {%3o } $byte]
		if {[string is print -strict [format {%c} $byte]]} {
			$data_transfer_log($side) insert 4.$i [format {  %c } $byte]
		} else {
			$data_transfer_log($side) insert 4.$i {    }
		}
		$data_transfer_log($side) configure -state disabled

		incr data_transfer_log_length($side)
	}

	public method uart_monitor_write_to_log {side text} {
		if {!$dialog_opened} {
			return
		}

		$general_log($side) configure -state normal
		if {$general_log_length($side) == $MAX_G_LOG_LENGTH} {
			$general_log($side) delete 1.0 2.0
			$general_log($side) mark set {end-1l lineend}
		}

		$general_log($side) insert insert $text
		$general_log($side) insert insert "\n"
		$general_log($side) see insert
		$general_log($side) configure -state disabled
	}

	public method uart_monitor_shift_reg_input {side right__left bit_val} {
		if {!$dialog_opened} {
			return
		}

		incr shift_reg_bits_written($side)
		if {$right__left} {
			set shift_reg($side) [expr {($shift_reg($side) >> 1) | (($bit_val ? 1 : 0) << 9)}]
			set start 0
			set end [expr {$shift_reg_bits_written($side) - 1}]
		} else {
			set shift_reg($side) [expr {0x3FF & (($shift_reg($side) << 1) | ($bit_val ? 1 : 0))}]
			set start [expr {9 - $shift_reg_bits_written($side)}]
			set end 9
		}

		for {set i $start} {$i <= $end} {incr i} {
			if {$shift_reg($side) & (1 << (9 - $i))} {
				set outline ${::BitMap::one_outline}
				set fill ${::BitMap::one_fill}
			} else {
				set outline ${::BitMap::zero_outline}
				set fill ${::BitMap::zero_fill}
			}

			$canvas($side) itemconfigure $bit_rect(s,$side,$i)	\
				-outline $outline				\
				-fill $fill
		}
	}
	public method uart_monitor_shift_reg_clear {side} {
		if {!$dialog_opened} {
			return
		}

		for {set i 0} {$i < 9} {incr i} {
			$canvas($side) itemconfigure $bit_rect(s,$side,$i)	\
				-outline $empty_outline				\
				-fill $empty_fill
		}
		set shift_reg($side) 0
		set shift_reg_bits_written($side) 0
	}
	public method uart_monitor_update_sbuf {side} {
		if {!$dialog_opened} {
			return
		}

		if {$side == {r}} {
			set sbuf [$this getSfrDEC $::Simulator_ENGINE::symbol(SBUFR)]
			set bit8 [$this getBit $::Simulator_ENGINE::symbol(RB8)]
		} else {
			set sbuf [$this getSfrDEC $::Simulator_ENGINE::symbol(SBUFT)]
			set bit8 [$this getBit $::Simulator_ENGINE::symbol(TB8)]
		}

		for {set i 0} {$i < 9} {incr i} {
			if {!$i} {
				set value $bit8
			} else {
				set value [expr {$sbuf & (1 << (8 - $i))}]
			}

			if {$value} {
				set outline ${::BitMap::one_outline}
				set fill ${::BitMap::one_fill}
			} else {
				set outline ${::BitMap::zero_outline}
				set fill ${::BitMap::zero_fill}
			}

			$canvas($side) itemconfigure $bit_rect(b,$side,$i)	\
				-outline $outline				\
				-fill $fill
		}
	}
	public method uart_monitor_graph_clear {side} {
		$canvas($side) delete graph

		set graph_position($side) 0
		set graph_prev_states($side) 1
		set graph_elements($side) [list]
	}

	public method uart_monitor_graph_draw {side values} {
		if {$graph_position($side) == 190} {
			$canvas($side) move graph -1 0
			foreach items [lindex $graph_elements($side) 0] {
				foreach item $items {
					$canvas($side) delete $item
				}
			}
			set graph_elements($side) [lreplace $graph_elements($side) 0 0]
			incr graph_position($side) -1
		}

		set x_0 [expr {45 + $graph_position($side)}]
		set x_1 [expr {$x_0 + 1}]

		set i 0
		set prev_state [list]
		set graph_elems [list]
		foreach state $values {
			set top [expr {75 + $i * 20}]
			set mid [expr {82 + $i * 20}]
			set bot [expr {90 + $i * 20}]
			switch -- [lindex $graph_prev_states($side) $i] {
				0 {
					switch -- $state {
						0 {	;# 0 --> 0
							lappend graph_elems [list \
								[$canvas($side) create line $x_0 $bot $x_1 $bot -tags graph -fill {#00FF00}] \
							]
						}
						1 {	;# 0 --> 1
							lappend graph_elems [list \
								[$canvas($side) create line $x_0 $top $x_0 $mid -tags graph -fill {#FF0000}] \
								[$canvas($side) create line $x_0 $mid $x_0 $bot -tags graph -fill {#00FF00}] \
							]
						}
						default {
							lappend graph_elems [list \
								[$canvas($side) create line $x_0 $top $x_0 $bot -tags graph -fill {#0000FF}] \
							]
						}
					}
				}
				1 {
					switch -- $state {
						0 {	;# 1 --> 0
							lappend graph_elems [list \
								[$canvas($side) create line $x_0 $top $x_0 $mid -tags graph -fill {#FF0000}] \
								[$canvas($side) create line $x_0 $mid $x_0 $bot -tags graph -fill {#00FF00}] \
							]
						}
						1 {	;# 1 --> 1
							lappend graph_elems [list \
								[$canvas($side) create line $x_0 $top $x_1 $top -tags graph -fill {#FF0000}] \
							]
						}
						default {
							lappend graph_elems [list \
								[$canvas($side) create line $x_0 $top $x_0 $bot -tags graph -fill {#0000FF}] \
							]
						}
					}
				}
				default {
					lappend graph_elems [list \
						[$canvas($side) create line $x_0 $top $x_0 $bot -tags graph -fill {#0055FF}] \
					]
				}
			}

			incr i
			lappend prev_state $state
		}

		incr graph_position($side)
		set graph_prev_states($side) $prev_state
		lappend graph_elements($side) $graph_elems
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

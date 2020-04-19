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
if { ! [ info exists _BITMAP_TCL ] } {
set _BITMAP_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides graphical view on bit addressable area in simulated MCU.
# --------------------------------------------------------------------------

class BitMap {
	## COMMON
	public common btmap_count	0	;# Int: Counter of object instances
	# Last window geometry
	public common win_geometry	[lindex $::CONFIG(BITMAP_CONFIG) 0]

	public common bit_addr_clr	{#0000FF}	;# Color: Bit address
	public common reg_addr_clr	{#00DD00}	;# Color: Register address
	public common rect_size	14		;# Int: Size of rectangle repersenting one bit
	public common rect_sep		2		;# Int: Space between bits
	public common reg_sep		4		;# Int: Space between octetes
	public common row_sep		4		;# Int: Space between rows
	public common bm_x_org		50		;# Int: Bitmap origin (X)
	public common bm_y_org		20		;# Int: Bitmap origin (Y)

	public common zero_fill	#FF0000		;# Color: Bit fill color for log. 0	(Non-selected)
	public common zero_outline	#FF8888		;# Color: Bit outline color for log. 0	(Non-selected)
	public common zero_a_fill	#FF8888		;# Color: Bit fill color for log. 0	(Selected bit)
	public common zero_a_outline	#FFDDDD		;# Color: Bit outline color for log. 0	(Selected bit)

	public common one_fill		#00FF00		;# Color: Bit color for log. 1		(Non-selected)
	public common one_outline	#88FF88		;# Color: Bit outline color for log. 1	(Non-selected)
	public common one_a_fill	#88FF88		;# Color: Bit fill color for log. 1	(Selected bit)
	public common one_a_outline	#DDFFDD		;# Color: Bit outline color for log. 1	(Selected bit)

	# Font: Normal font for canvas widget
	public common bitmap_n_font	[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
	]
	# Font: Bold font for canvas widget
	public common bitmap_b_font	[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
	]


	## PRIVATE
	private variable win			;# Widget: Dialog window
	private variable dialog_opened	0	;# Bool: Window opened

	private variable main_frame		;# Widget: Main frame (contains canvas widget)
	private variable bitmap_canvas		;# Widget: Canvas widget
	private variable bits			;# Array of Objects: bit rectangles in canvas widget
	private variable bits_states		;# Array of Booleans: States of particular bits

	private variable bit_addr_lbl		;# Widget: Label showing bit address on status bar
	private variable reg_addr_lbl		;# Widget: Label showing register address on status bar

	private variable sync_ena	1	;# Bool: Synchroniation with engine enabled
	private variable enabled	0	;# Bool: Changes enabled


	constructor {} {
	}

	destructor {
	}

	## Enable or disable changes in registers
	 # @parm Bool _enabled - 1 == Enable; 0 == Disable
	 # @return void
	public method bitmap_setEnabled {_enabled} {
		set enabled $_enabled
	}

	## Get configuration list (for restoring sessions)
	 # @return List - Dialog configuration
	public method bitmap_get_config {} {
		return [list $win_geometry]
	}

	## Close dialog
	 # @return void
	public method bitmap_close_dialog {} {
		set win_geometry [wm geometry $win]
		set dialog_opened 0
		destroy $win
	}

	## Open dialog window
	 # @return void
	public method bitmap_invoke_dialog {} {
		# Exit if the dialog is already opened
		if {$dialog_opened} {
			raise $win
			return
		}

		# Create dialog window
		set win [toplevel .bitmap_${btmap_count} -class {Bitmap} -bg ${::COMMON_BG_COLOR}]
		incr btmap_count

		# ----------------------------------------------------------------
		# Create main frame and canvas widget
		# ----------------------------------------------------------------

		set main_frame [frame $win.main_frame]
		set bitmap_canvas [canvas $main_frame.canvas		\
			-width 620 -height 110 -relief flat -bd 0	\
			-highlightthickness 0 -takefocus 0		\
		]

		## Create matrix of rectangles
		set addr 128		;# Int: Bit address
		set x0 $bm_x_org	;# Int: Rectangle horizontal coordinate
		set y0 $bm_y_org	;# Int: Rectangle vertical coordinate
		# Create 4 rows
		for {set y 0} {$y < 4} {incr y} {
			# Create 4 registers in each row
			for {set r 0} {$r < 4} {incr r} {
				# Create 8 bits in each register
				for {set x 0} {$x < 8} {incr x} {
					# Create bit rectagle
					set bit [$bitmap_canvas create rectangle $x0 $y0		\
						[expr {$x0 + $rect_size}] [expr {$y0 + $rect_size}]	\
						-fill $zero_fill -outline $zero_outline			\
					]

					# Adjust X position for the next rectagle
					incr x0 $rect_size
					incr x0 $rect_sep

					# Register created rectagle for future referecing
					incr addr -1
					set bits($addr) $bit
					set bits_states($addr) 0

					# Set rectagle event bindings
					$bitmap_canvas bind $bit <Enter> "$this bitmap_bit_enter $addr"
					$bitmap_canvas bind $bit <Leave> "$this bitmap_bit_leave $addr"
					$bitmap_canvas bind $bit <Button-1> "$this bitmap_bit_click $addr"
				}
				# Adjust X position for the next register
				incr x0 $reg_sep
			}
			# Adjust X and Y position for the next row
			set x0 $bm_x_org
			incr y0 $rect_size
			incr y0 $row_sep
		}

		## Create bottom horizonal header
		# Bit addresses
		foreach txt {{1F 18} {17 10} {0F 08} {07 00}} {
			# MSB
			$bitmap_canvas create text $x0 $y0 -text [lindex $txt 0]	\
				-font $bitmap_n_font -anchor nw -justify left -fill $bit_addr_clr
			incr x0 [expr {7 * ($rect_sep + $rect_size)}]
			# LSB
			$bitmap_canvas create text $x0 $y0 -text [lindex $txt 1]	\
				-font $bitmap_n_font -anchor nw -justify left -fill $bit_addr_clr
			incr x0 [expr {$rect_sep + $rect_size + $reg_sep}]
		}
		# Register addresses
		set x0 [expr {$bm_x_org + 4 * ($rect_sep + $rect_size)}]
		foreach txt {23 22 21 20} {
			$bitmap_canvas create text $x0 $y0 -text $txt	\
				-font $bitmap_b_font -anchor n -justify center -fill $reg_addr_clr
			incr x0 [expr {8 * ($rect_sep + $rect_size) + $reg_sep}]
		}

		## Create top horizonal header
		set y0 $bm_y_org
		# Bit addresses
		set x0 $bm_x_org
		foreach txt {{7F 78} {77 70} {6F 68} {67 60}} {
			# MSB
			$bitmap_canvas create text $x0 $y0 -text [lindex $txt 0]	\
				-font $bitmap_n_font -anchor sw -justify left -fill $bit_addr_clr
			incr x0 [expr {7 * ($rect_sep + $rect_size)}]
			# LSB
			$bitmap_canvas create text $x0 $y0 -text [lindex $txt 1]	\
				-font $bitmap_n_font -anchor sw -justify left -fill $bit_addr_clr
			incr x0 [expr {$rect_sep + $rect_size + $reg_sep}]
		}
		# Register addresses
		set x0 [expr {$bm_x_org + 4 * ($rect_sep + $rect_size)}]
		foreach txt {2F 2E 2D 2C} {
			$bitmap_canvas create text $x0 $y0 -text $txt	\
				-font $bitmap_b_font -anchor s -justify center -fill $reg_addr_clr
			incr x0 [expr {8 * ($rect_sep + $rect_size) + $reg_sep}]
		}

		## Create left vertical header
		# Bit addresses
		set y0 $bm_y_org
		set x0 [expr {$bm_x_org - 4}]
		foreach txt {7F 5F 3F 1F} {
			$bitmap_canvas create text $x0 $y0 -text $txt		\
				-font $bitmap_n_font -anchor ne -justify right	\
				-fill $bit_addr_clr
			incr y0 $rect_size
			incr y0 $row_sep
		}
		# Register addresses
		set y0 $bm_y_org
		set x0 [expr {$bm_x_org - 25}]
		foreach txt {2F 2B 27 23} {
			$bitmap_canvas create text $x0 $y0 -text $txt		\
				-font $bitmap_b_font -anchor ne -justify left	\
				-fill $reg_addr_clr
			incr y0 $rect_size
			incr y0 $row_sep
		}

		## Create right vertical header
		# Bit addresses
		set y0 $bm_y_org
		set x0 [expr {$bm_x_org + 32 * ($rect_sep + $rect_size) + 4 * $reg_sep}]
		foreach txt {60 40 20 00} {
			$bitmap_canvas create text $x0 $y0 -text $txt		\
				-font $bitmap_n_font -anchor nw -justify left	\
				-fill $bit_addr_clr
			incr y0 $rect_size
			incr y0 $row_sep
		}
		# Register addresses
		set y0 $bm_y_org
		set x0 [expr {$bm_x_org + 32 * ($rect_sep + $rect_size) + 4 * $reg_sep + 18}]
		foreach txt {2C 28 24 20} {
			$bitmap_canvas create text $x0 $y0 -text $txt		\
				-font $bitmap_b_font -anchor nw -justify left	\
				-fill $reg_addr_clr
			incr y0 $rect_size
			incr y0 $row_sep
		}


		# ----------------------------------------------------------------
		# Create bottom frame
		# ----------------------------------------------------------------

		set bottom_frame [frame $main_frame.bottom_frame]
		set bottom_left_frame [frame $bottom_frame.left_frame]
		set bottom_right_frame [frame $bottom_frame.right_frame]

		## Create legend
		# Log. 0
		set frame [frame $bottom_left_frame.frm_0]
		pack [label $frame.lg0_lbl	\
			-text [mc "Log. 0"]		\
		] -side left
		pack [label $frame.lg0_frm	\
			-bg {#FF0000} -width 3	\
			-bd 1 -relief raised	\
			-height 1		\
		] -side left -pady 2
		pack $frame -side left -padx 5
		# Log. 1
		set frame [frame $bottom_left_frame.frm_1]
		pack [label $frame.lg0_lbl	\
			-text [mc "Log. 1"]		\
		] -side left
		pack [label $frame.lg0_frm	\
			-bg {#00FF00} -width 3	\
			-bd 1 -relief raised	\
			-height 1		\
		] -side left -pady 2
		pack $frame -side left -padx 5
		# Bit addr.
		set frame [frame $bottom_left_frame.frm_2]
		pack [label $frame.bit_lbl	\
			-text [mc "Bit addr."]		\
		] -side left
		pack [label $frame.bit_frm	\
			-bg $bit_addr_clr	\
			-width 3 -height 1	\
			-bd 1 -relief raised	\
		] -side left -pady 2
		pack $frame -side left -padx 5
		# Reg. addr.
		set frame [frame $bottom_left_frame.frm_3]
		pack [label $frame.reg_lbl	\
			-text [mc "Reg. addr."]	\
		] -side left
		pack [label $frame.reg_frm	\
			-bg $reg_addr_clr	\
			-width 3 -height 1	\
			-bd 1 -relief raised	\
		] -side left -pady 2
		pack $frame -side left -padx 5

		## Create address meters
		# Register address
		pack [label $bottom_right_frame.reg_n_lbl -text [mc "Register: "] -fg {#888888}] -side left
		set reg_addr_lbl [label $bottom_right_frame.reg_addr_lbl	\
			-width 4 -fg $reg_addr_clr -text { -- }			\
		]
		# Bit address
		pack $reg_addr_lbl -side left
		pack [label $bottom_right_frame.bit_n_lbl -text [mc "   Bit address: "] -fg {#888888}] -side left
		set bit_addr_lbl [label $bottom_right_frame.bit_addr_lbl	\
			-width 4 -fg $bit_addr_clr -text { -- }			\
		]
		pack $bit_addr_lbl -side left

		# Pack parts of bottom frame
		pack $bottom_left_frame -side left
		pack $bottom_right_frame -side right

		# ----------------------------------------------------------------
		# Finalize
		# ----------------------------------------------------------------

		# Pack main parts of the window
		pack $bitmap_canvas
		pack $bottom_frame -fill x -side bottom
		pack $main_frame -fill both -expand 1

		# Set window parameters
		wm protocol $win WM_DELETE_WINDOW "$this bitmap_close_dialog"
		wm resizable $win 0 0
		wm title $win [mc "Bit addressable area - %s - %s - %s" [$this cget -P_option_mcu_type] [$this cget -projectName] "MCU 8051 IDE"]
		wm iconphoto $win ::ICONS::16::kcmmemory_BA
		catch {
			wm geometry $win $win_geometry
		}
		bindtags $win [list $win Toplevel all .]

		# Set flag dialog opened
		set dialog_opened 1

		# Synchronize with simulator engine
		for {set i 32} {$i < 48} {incr i} {
			bitmap_sync $i
		}
		bitmap_clear_hg
	}

	## Bit rectangle event handler for event <Enter>
	 # @parm Int addr - Register address
	 # @return void
	public method bitmap_bit_enter {addr} {
		# Determinate new rectangle outline and fill colors
		if {$bits_states($addr)} {
			set outline $one_a_outline
			set fill $one_a_fill
		} else {
			set outline $zero_a_outline
			set fill $zero_a_fill
		}
		# Set new rectangle colors and changle cursor
		if {$enabled} {
			$bitmap_canvas itemconfigure $bits($addr) -outline $outline -fill $fill
			$bitmap_canvas configure -cursor hand2
		}

		## Adjust address meters
		# Bit address
		set hex_addr [format %X $addr]
		if {[string length $hex_addr] == 1} {
			set hex_addr "0$hex_addr"
		}
		set hex_addr "0x$hex_addr"
		$bit_addr_lbl configure -text $hex_addr
		# Register address
		set hex_addr [format %X [expr {$addr / 8 + 32}]]
		if {[string length $hex_addr] == 1} {
			set hex_addr "0$hex_addr"
		}
		set hex_addr "0x$hex_addr"
		$reg_addr_lbl configure -text $hex_addr
	}

	## Bit rectangle event handler for event <Leave>
	 # @parm Int addr - Register address
	 # @return void
	public method bitmap_bit_leave {addr} {
		# Determinate new rectangle outline and fill colors
		if {$bits_states($addr)} {
			set outline $one_outline
			set fill $one_fill
		} else {
			set outline $zero_outline
			set fill $zero_fill
		}

		# Adjust address meters
		$bit_addr_lbl configure -text { -- }
		$reg_addr_lbl configure -text { -- }

		# Set new rectangle colors
		$bitmap_canvas itemconfigure $bits($addr) -outline $outline -fill $fill
		$bitmap_canvas configure -cursor left_ptr
	}

	## Bit rectangle event handler for event <Button-1>
	 # Invert bit value
	 # @parm Int addr - Register address
	 # @return void
	public method bitmap_bit_click {addr} {
		# Dialog must be enabled to perform this operation
		if {!$enabled} {
			return
		}

		# Disable this procedure
		set sync_ena 0

		# Invert bit value and adjust color
		set bits_states($addr) [expr {!$bits_states($addr)}]
		bitmap_bit_enter $addr

		## Synchronize with simulator engine
		# Determinate register value
		set bit_addr [expr {($addr / 8) * 8}]
		set reg_addr [expr {$addr / 8 + 32}]
		set reg_val 0
		set mask 1
		for {set i 0} {$i < 8} {incr i} {
			if {$bits_states($bit_addr)} {
				incr reg_val $mask
			}

			set mask [expr {$mask << 1}]
			incr bit_addr
		}
		# Synchronize
		$this setDataDEC $reg_addr $reg_val
		$this Simulator_sync_reg $reg_addr

		# Enable this procedure
		set sync_ena 1
	}

	## Synchronize with simulator engine (data are taken from the engine)
	 # @parm Int reg_addr - Register address (meaningfull are values from 32 to 47)
	 # @return void
	public method bitmap_sync {reg_addr} {
		# Check if this procedure can be done
		if {!$dialog_opened} {return}
		if {!$sync_ena} {return}
		if {$reg_addr < 32 || $reg_addr > 47} {
			return
		}

		# Determinate LSB address and rehister address
		set reg_val [$this getDataDEC $reg_addr]
		set bit_addr [expr {($reg_addr - 32) * 8}]

		# Synchronize
		set mask 1
		for {set i 0} {$i < 8} {incr i} {
			# Adjust bit value in bitmap
			set original_val $bits_states($bit_addr)
			set bits_states($bit_addr) [expr {$mask & $reg_val}]

			# Adjust rectangle colors if bit was changed
			if {$original_val != $bits_states($bit_addr)} {
				if {$bits_states($bit_addr)} {
					set fill $one_fill
				} else {
					set fill $zero_fill
				}

				$bitmap_canvas itemconfigure $bits($bit_addr)	\
					-outline {#000000} -fill $fill
			}

			# Adjust bit address and bit mask
			incr bit_addr
			set mask [expr {$mask << 1}]
		}
	}

	## Clear highlight of changed cells
	 # @return void
	public method bitmap_clear_hg {} {
		if {!$dialog_opened} {return}
		for {set i 0} {$i < 128} {incr i} {
			if {$bits_states($i)} {
				set outline $one_outline
			} else {
				set outline $zero_outline
			}
			$bitmap_canvas itemconfigure $bits($i) -outline $outline
		}
	}
}


# >>> File inclusion guard
}
# <<< File inclusion guard

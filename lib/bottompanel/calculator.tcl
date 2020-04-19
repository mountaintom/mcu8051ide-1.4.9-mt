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
if { ! [ info exists _CALCULATOR_TCL ] } {
set _CALCULATOR_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
#
# --------------------------------------------------------------------------

class Calculator {

	public common calc_count	0	;# counter of instances
	# Font for numerical keypad
	public common large_font	[font create			\
		-family {helveticat}				\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight {bold}					\
	]

	public common oper_fg_color	{#0000FF}	;# Foreground color for operator display
	public common error_bg_color	{#FF6666}	;# Background color for display containing too many characters
	public common display_bg_color	{#DDFFDD}	;# Background color for main display
	public common buffer_bg_color	{#DDDDFF}	;# Background color for buffer display

	# Variables related to object initialization
	private variable parent				;# Teportary variable -- GUI parent
	private variable calculatorList			;# Teportary variable -- COnfiguration list
	private variable calc_gui_initialized	0	;# Bool: GUI created

	# GUI variables
	private variable calc_num_keypad		;# Container of left side of calc. (keypad)
	private variable calc_num_display		;# Container for right side (displays etc.)
	private variable calc_timers_calc		;# ID of label frame of timer preset calculator
	private variable calc_display_widget		;# ID of main display widget
	private variable calc_oper_widget		;# ID of operator display widget
	private variable calc_buffer_widget		;# ID of buffer display widget
	private variable timerscalc_THxDec_label	;# ID of THx (dec) label
	private variable timerscalc_THxHex_label	;# ID of THx (hex) label
	private variable timerscalc_THxOct_label	;# ID of THx (oct) label
	private variable timerscalc_TLxDec_label	;# ID of TLx (dec) label
	private variable timerscalc_TLxHex_label	;# ID of TLx (hex) label
	private variable timerscalc_TLxOct_label	;# ID of TLx (oct) label
	private variable timerscalc_RepeatDec_label	;# ID of Repeat (dec) label
	private variable timerscalc_RepeatHex_label	;# ID of Repeat (hex) label
	private variable timerscalc_RepeatOct_label	;# ID of Repeat (oct) label
	private variable timerscalc_CorrectionDec_label	;# ID of Correction (dec) label
	private variable timerscalc_CorrectionHex_label	;# ID of Correction (hex) label
	private variable timerscalc_CorrectionOct_label	;# ID of Correction (oct) label
	private variable timerscalc_freq_entry		;# ID of frequency entry widget
	private variable timerscalc_mode_spinbox	;# ID of mode spinbox widget
	private variable timerscalc_time_entry		;# ID of tim entry widget
	private variable mem_entry_0			;# ID of memory 0 entry widget
	private variable mem_entry_1			;# ID of memory 1 entry widget
	private variable mem_entry_2			;# ID of memory 2 entry widget

	# Core variables
	private variable base			;# Numeric base (Hex, Dec. Oct, Bin)
	private variable last_base		;# Last numeric base
	private variable angle			;# Angle unit (rad, deg, grad)
	private variable last_angle		;# Last angle unit
	private variable calc_oper	{}	;# Chosen mathematical operation
	private variable calc_oper_h		;# Human readible $calc_oper
	private variable calc_last_oper		;# Last $calc_oper
	private variable calc_display		;# Actual display text variable
	private variable calc_buffer		;# Last display text variable
	private variable calc_last_display	;# Var. for UNDO/REDO (takes back $calc_display)
	private variable calc_last_buffer	;# Var. for UNDO/REDO (takes back $calc_buffer)
	private variable ena_undo	0	;# Undo enabled
	private variable ena_redo	0	;# Redo enabled
	private variable after_eval	0	;# Clear display if actual display val. is result of last operation
	private variable scrollable_frame	;# Widget: Scrollable area (parent for all other widgets)
	private variable horizontal_scrollbar	;# Widget: Horizontal scrollbar for scrollable area

	# other public variables
	private variable calc_idx				;# number of current instance
	private variable timerscalc_validation_dis	1	;# Disabled validation of timers calc

	# definition of calculator keyboard
	# {
	#	# row
	# 	{	# button
	#		{text		path_part		command_postfix
	#				columnspan		rowspan
	#				helptext		width
	#				height			bgColor
	#				activeBackground	bool_large_font
	#		}
	#		{separator}
	#	}
	# }
	public common calculator_keyboard {
		{
			{{AND}	{and}	{calc_opr and 1} {} {}
				{Bit-wise AND}
				{5} {} {} {Calculator_GREEN} {#CCFFCC} 0
				{Bit-wise AND. Valid for integer operands only.}}
			{{Sin}	{S}	{calc_opr Sin 1} {} {}
				{Sine}
				{5} {} {} {Calculator_RED} {#FFDDDD} 0
				{Sine}}
			{{Cos}	{Cs}	{calc_opr Cos 1} {} {}
				{Cosine}
				{5} {} {} {Calculator_RED} {#FFDDDD} 0
				{Cosine}}
			{{Tan}	{T}	{calc_opr Tan 1} {} {}
				{Tangent}
				{5} {} {} {Calculator_RED} {#FFDDDD} 0
				{Tangent}}
			{{A}	{A}	{calc_val A} {} {} {} {} {} {5} {Calculator_PURPLE} {#DDDDFF} 1}
			{{F}	{F}	{calc_val F} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{/}	{div}	{calc_opr div 1} {} {} {} {} {} {} {Calculator_YELLOW} {#FFFFDD} 1}
			{{*}	{mul}	{calc_opr mul 1} {} {} {} {} {} {} {Calculator_YELLOW} {#FFFFDD} 1}
			{{-}	{min}	{calc_opr min 1} {} {} {} {} {} {} {Calculator_YELLOW} {#FFFFDD} 1}
		} {
			{{OR}	{or}	{calc_opr or 1} {} {}
				{Bit-wise OR}
				{5} {} {} {Calculator_GREEN} {#CCFFCC} 0
				{Bit-wise OR. Valid for integer operands only.}}
			{{ASin}	{AS}	{calc_opr ASin 1} {} {}
				{Arc sine}
				{5} {} {} {Calculator_RED} {#FFDDDD} 0
				{Arc sine. Argument should be in the range [-1,1].}}
			{{ACos}	{AC}	{calc_opr ACos 1} {} {}
				{Arc cosine}
				{5} {} {} {Calculator_RED} {#FFDDDD} 0
				{Arc cosine. Argument should be in the range [-1,1].}}
			{{ATan}	{AT}	{calc_opr ATan 1} {} {}
				{Arc tangent}
				{5} {} {} {Calculator_RED} {#FFDDDD} 0
				{Arc tangent}}

			{{B}	{B}	{calc_val B} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{7}	{7}	{calc_val 7} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{8}	{8}	{calc_val 8} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{9}	{9}	{calc_val 9} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{+}	{add}	{calc_opr add 1} {} {2} {} {} {2} {} {Calculator_YELLOW} {#FFFFDD} 1}
		} {
			{{NOT}	{not}	{calc_opr not 1} {} {}
				{Bit-wise NOT}
				{5} {} {} {Calculator_GREEN} {#CCFFCC} 0
				{Bit-wise NOT. Valid for integer operands only.}}
			{{e**}	{exp}	{calc_opr Exp 1} {} {}
				{Exponential of argument (e**arg)}
				{5} {} {} {Calculator_CYAN} {#AAFFFF} 0
				{Exponential of argument (e**arg)}}
			{{sqrt}	{sqr}	{calc_opr Sqr 1} {} {}
				{Square root}
				{5} {} {} {Calculator_CYAN} {#AAFFFF} 0
				{Square root. Argument must be non-negative.}}
			{{pow}	{power}	{calc_opr pow 1} {} {}
				{Power}
				{5} {} {} {Calculator_CYAN} {#AAFFFF} 0
				{Computes the value of x raised to the power y. If x is negative, y must be an integer value.}}

			{{C}	{C}	{calc_val C} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{4}	{4}	{calc_val 4} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{5}	{5}	{calc_val 5} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{6}	{6}	{calc_val 6} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
		} {
			{{XOR}	{xor}	{calc_opr xor 1} {} {}
				{Bit-wise exclusive OR}
				{5} {} {} {Calculator_GREEN} {#CCFFCC} 0
				{Bit-wise exclusive OR. Valid for integer operands only.}}
			{{Log}	{L}	{calc_opr Log 1} {} {}
				{Base 10 logarithm}
				{5} {} {} {Calculator_CYAN} {#AAFFFF} 0
				{Returns the base 10 logarithm of argument. Argument must be a positive value.}}
			{{Ln}	{Ln}	{calc_opr Ln 1}	{} {}
				{Natural logarithm}
				{5} {} {} {Calculator_CYAN} {#AAFFFF} 0
				{Returns the natural logarithm of argument. Argument must be a positive value.}}
			{{PI}	{P}	{calc_val PI}	{} {}
				{Constant Pi}
				{5} {} {} {Calculator_CYAN} {#AAFFFF} 0
				{Constant Pi}}

			{{D}	{D}	{calc_val D} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{1}	{1}	{calc_val 1} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{2}	{2}	{calc_val 2} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{3}	{3}	{calc_val 3} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{=}	{=}	{calc_Evaluate}	{} {2} {} {} {2} {} {Calculator_YELLOW} {#FFFFDD} 1}
		} {
			{{>>}	{right}	{calc_opr right 1} {} {}
				{Right shift}
				{5} {} {} {Calculator_GREEN} {#CCFFCC} 0
				{Right shift. Valid for integer operands only. A right shift always propagates the sign bit.}}
			{{Mod}	{M}	{calc_opr mod 1} {} {}
				{Modulo}
				{5} {} {} {Calculator_CYAN} {#AAFFFF} 0
				{Computes remainder of integer division}}
			{{UNDO}	{U}	{calc_UNDO} {} {}
				{Undo last operation}
				{5} {} {} {Calculator_GRAY} {#F8F8F8} 0
				{Undo last operation. Not all operations are supported.}}
			{{REDO}	{RE}	{calc_REDO} {} {}
				{Take back last undo operation}
				{5} {} {} {Calculator_GRAY} {#F8F8F8} 0
				{Take back last undo operation. Not all operations are supported.}}

			{{E}	{E}	{calc_val E} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
			{{0}	{0}	{calc_val 0} {2} {} {} {5} {} {} {Calculator_PURPLE} {#DDDDFF} 1}

			{{.}	{dot}	{calc_val .} {} {} {} {} {} {} {Calculator_PURPLE} {#DDDDFF} 1}
		}
	}

	## object constructor
	constructor {} {
		# Initialize some variables
		incr calc_count		;# Instance counter
		set calc_idx $calc_count;# Index of this object
		set base Dec		;# Default numeric base
		set angle rad		;# Default angle unit
		set last_base $base	;# Last numeric base
		set last_angle $angle	;# Last angle unit

		# Configure ttk styles
		ttk::style configure Calculator_Buffer.TEntry	\
			-fieldbackground $buffer_bg_color
		ttk::style configure Calculator_Oper.TEntry	\
			-fieldbackground {#FFDDDD}		\
			-fieldforeground $oper_fg_color		\
			-justify center
		ttk::style configure Calculator_OperError.TEntry\
			-fieldbackground {#FFDDDD}		\
			-foreground {#FF0000}			\
			-justify center
		ttk::style configure Calculator_Display.TEntry 	\
			-fieldbackground $display_bg_color
		ttk::style configure Calculator_Error.TEntry 	\
			-fieldbackground $error_bg_color

		ttk::style configure Calculator_GREEN.TButton -padding 2
		ttk::style map Calculator_GREEN.TButton \
			-background [list active {#AAFFAA} {!active !disabled} {#CCFFCC} disabled {#DDEEDD}]

		ttk::style configure Calculator_RED.TButton -padding 2
		ttk::style map Calculator_RED.TButton \
			-background [list active {#FFAAAA} {!active !disabled} {#FFDDDD} disabled {#EEDDDD}]

		ttk::style configure Calculator_CYAN.TButton -padding 2
		ttk::style map Calculator_CYAN.TButton \
			-background [list active {#88EEEE} {!active !disabled} {#AAFFFF} disabled {#DDEEEE}]

		ttk::style configure Calculator_GRAY.TButton -padding 2
		ttk::style map Calculator_GRAY.TButton \
			-background [list active {#DDDDDD} {!active !disabled} {#F8F8F8} disabled ${::COMMON_BG_COLOR}]

		ttk::style configure Calculator_PURPLE.TButton -padding 2 -font $large_font
		ttk::style map Calculator_PURPLE.TButton \
			-background [list active {#AAAAFF} {!active !disabled} {#DDDDFF} disabled {#DDDDEE}]

		ttk::style configure Calculator_YELLOW.TButton -padding 2 -font $large_font
		ttk::style map Calculator_YELLOW.TButton \
			-background [list active {#FFFFAA} {!active !disabled} {#FFFFDD} disabled {#EEEEDD}]
	}

	## object destructor
	destructor {
		# Unallocate GUI related variables
		catch {
			unset ::Calculator::calc_base$calc_idx
			unset ::Calculator::calc_angle$calc_idx
			unset ::Calculator::calc_buffer$calc_idx
			unset ::Calculator::calc_oper$calc_idx
			unset ::Calculator::calc_displ$calc_idx
			unset ::Calculator::calc_mem0_$calc_idx
			unset ::Calculator::calc_mem1_$calc_idx
			unset ::Calculator::calc_mem2_$calc_idx
		}
	}

	## Append given value to the end of the display
	 # Use carefully, it does not check value validity !
	 # @parm String value - value to append
	 # @return String - new display content
	public method calc_val {value} {
		# Read raw content of the main display
		reread_display 1

		# Insert PI
		if {$value == {PI}} {
			# Conver PI to selected numeric base
			switch -- $base {
				{Hex}	{set value [NumSystem::dec2hex ${Angle::PI}]}
				{Dec}	{set value ${Angle::PI}}
				{Oct}	{set value [NumSystem::dec2oct ${Angle::PI}]}
				{Bin}	{set value [NumSystem::dec2bin ${Angle::PI}]}
			}
			# Save current values
			set calc_last_display [reread_display]	;# Main display
			set calc_last_buffer [reread_buffer]	;# Buffer
			# Clear main display
			set calc_display {}
			# Save current opetaror
			set calc_last_oper $calc_oper
			enable_undo	;# enable UNDO operation

		# Clear main display if current value is result of the last operation
		} elseif {$after_eval} {
			set calc_last_display $calc_display	;# Save current content of display
			set calc_last_buffer {}
			set calc_last_oper {}
			set calc_display {}
			set after_eval 0
			enable_undo	;# enable UNDO operation
		}

		# Append given value to the end of main display
		set tmp "$calc_display$value"
		if {[calc_validate $calc_display_widget $tmp]} {
			set ::Calculator::calc_displ$calc_idx $tmp

			catch {
				$calc_display_widget delete sel.first sel.last
			}
		}

		$calc_display_widget icursor end
		$calc_buffer_widget icursor end
		return $calc_display
	}

	## Choose mathematical operation
	 # @parm String operation	- Selected operation
	 # @parm Bool external		- Evaluate result
	 # @return void
	public method calc_opr {operation external} {

		# Save current operator and set the new one
		set calc_last_oper $calc_oper
		set calc_oper $operation
		# Clear displays if external
		if {$external} {
			set calc_last_display [reread_display]
			set calc_last_buffer [reread_buffer]
			set calc_buffer $calc_display
			set calc_display {}
			enable_undo
			rewrite_buffer
			rewrite_display
		}

		# Evaluate specified operation
		switch -- $operation {
			{div}	{	;# Division
				set calc_oper_h {/}
			}
			{mul}	{	;# Multiplication
				set calc_oper_h {*}
			}
			{min}	{	;# Subtraction
				set calc_oper_h {-}
			}
			{add}	{	;# Addition
				set calc_oper_h {+}
			}
			{pow}	{	;# Power
				set calc_oper_h {**}
			}
			{mod}	{	;# Modulo
				set calc_oper_h {mod}
			}
			{and}	{	;# Bit-wise and
				set calc_oper_h {&}
			}
			{or}	{	;# Bit-wise inclusive or
				set calc_oper_h {|}
			}
			{xor}	{	;# Bit-wise exclusive or
				set calc_oper_h {^}
			}
			{right}	{	;# Right shift
				set calc_oper_h {>>}
			}

			{not}	{	;# Bit-wise inversion
				set calc_oper_h {~}
				if {$external} {calc_Evaluate}
			}
			{Exp}	{	;# Exponential of argument
				set calc_oper_h {e**}
				if {$external} {calc_Evaluate}
			}
			{Sqr}	{	;# Square root
				set calc_oper_h {sqrt}
				if {$external} {calc_Evaluate}
			}
			{Log}	{	;# Decimal logarithm
				set calc_oper_h {lg}
				if {$external} {calc_Evaluate}
			}
			{Ln}	{	;# Natural logarithm
				set calc_oper_h {ln}
				if {$external} {calc_Evaluate}
			}
			{Sin}	{	;# Sine
				set calc_oper_h {sin}
				if {$external} {calc_Evaluate}
			}
			{Cos}	{	;# Cosine
				set calc_oper_h {cos}
				if {$external} {calc_Evaluate}
			}
			{Tan}	{	;# Tangent
				set calc_oper_h {tan}
				if {$external} {calc_Evaluate}
			}
			{ASin}	{	;# Arc sine
				set calc_oper_h {asin}
				if {$external} {calc_Evaluate}
			}
			{ACos}	{	;# Arc cosine
				set calc_oper_h {acos}
				if {$external} {calc_Evaluate}
			}
			{ATan}	{	;# Acr cotangent
				set calc_oper_h {atan}
				if {$external} {calc_Evaluate}
			}
			default	{	;# No operand
				set calc_oper_h {}
			}
		}

		# Display selected operand
		set ::Calculator::calc_oper$calc_idx $calc_oper_h
	}

	## Perform operation with calulator memory
	 # @parm String action	- "Save" (to main display) or "Load" (from main display)
	 # @parm Int cell	- Index of memory cell
	 # @return void
	public method mem {action cell} {
		if {$action == {Save}} {
			# Show message on status bar
			Sbar [mc "Calculator: M%s saved" $cell]
			# Save content of main display
			set calc_mem [reread_display]
			if {[regexp {\.0$} $calc_mem]} {
				set calc_mem [string range $calc_mem 0 {end-2}]
			}
			set ::Calculator::calc_mem${cell}_$calc_idx $calc_mem
		} else {
			# Load memory content into main display
			set calc_display [subst -nocommands "\$::Calculator::calc_mem${cell}_$calc_idx"]
			rewrite_display
		}
	}

	## Perform evaluation of given mathematical expression
	 # @return void
	public method calc_Evaluate {} {

		## Check for presence of nessesary values
		# * For unary operations
		set display [reread_display]
		set buffer [reread_buffer]
		if {$buffer == {} || $buffer == {-}} {
			Sbar [mc "Calculator: Unable to evaluate, missing argument"]
			return 0
		}
		if {$calc_oper == {}} {
			Sbar [mc "Calculator: Unable to evaluate, missing operator"]
			return 0
		}
		# * For binary operations
		if {
			$calc_oper == {div}	||	$calc_oper == {mul}	||
			$calc_oper == {min}	||	$calc_oper == {add}	||
			$calc_oper == {pow}	||	$calc_oper == {mod}	||
			$calc_oper == {and}	||	$calc_oper == {or}	||
			$calc_oper == {xor}	||	$calc_oper == {nand}
		} then {
			# Check display value length
			if {$display == {}} {
				Sbar [mc "Calculator: Unable to evaluate, missing argument"]
				return 0
			}
		}

		# Make backup for display, buffer and operator
		enable_undo	;# enable UNDO operation
		set calc_last_display $display
		set calc_last_buffer $buffer

		# Load up content of buffer and display
		read_buffer_inDec
		read_display_inDec

		# Perform evaluation in safe environment
		if {[catch {
			switch -- $calc_oper {
				{and}	{	;# Bit-wise and
					set calc_display [expr {wide($calc_buffer) & wide($calc_display)}]
				}
				{or}	{	;# Bit-wise or
					set calc_display [expr {wide($calc_buffer) | wide($calc_display)}]
				}
				{xor}	{	;# Bit-wise xor
					set calc_display [expr {wide($calc_buffer) ^ wide($calc_display)}]
				}
				{right}	{	;# Right shift
					set tmp [expr {wide($calc_display)}]
					if {$tmp > 0} {
						set calc_display [expr {wide($calc_buffer) >> $tmp}]
					} elseif {$tmp < 0} {
						set calc_display [expr {wide($calc_buffer) << abs($tmp)}]
					} else {
						set calc_display [expr {wide($calc_buffer)}]
					}
				}
				{mul}	{	;# Multiplication
					set calc_display [expr {$calc_buffer * $calc_display}]
				}
				{min}	{	;# Subtraction
					set calc_display [expr {$calc_buffer - $calc_display}]
				}
				{add}	{	;# Addtion
					set calc_display [expr {$calc_buffer + $calc_display}]
				}
				{mod}	{	;# Modulo
					set calc_display [expr {int(fmod($calc_buffer,$calc_display))}]
				}
				{pow}	{	;# Power
					set calc_display [expr {pow($calc_buffer, $calc_display)}]
				}
				{div}	{	;# Division
					if {$calc_display == 0} {
						Sbar [mc "Calculator: WARNING result is +/- infinity => operation terminated !"]
						return
					}
					if {![regexp {\.} $calc_buffer]} {
						set calc_buffer "$calc_buffer.0"
					}
					set calc_display [expr {$calc_buffer / $calc_display}]
				}
				{not}	{	;# Bit-wise inversion
					set len [string length [format {%X} [expr {int($calc_buffer)}]]]
					if {$len > 8} {
						Sbar [mc "Calculator: This value is too high to invert (max. 0xFFFFFFFF)"]
						return
					}
					incr len -1
					set calc_display [expr {0x7FFFFFFF ^ int($calc_buffer)}]
					set calc_display [format {%X} $calc_display]
					set calc_display [string range $calc_display end-$len end]
					set calc_display [expr "0x$calc_display"]
				}
				{Exp}	{	;# Exponential of argument
					set calc_display [expr {exp($calc_buffer)}]
				}
				{Sqr}	{	;# Square root
					set calc_display [expr {sqrt($calc_buffer)}]
				}
				{Log}	{	;# Decimal logarithm
					set calc_display [expr {log10($calc_buffer)}]
				}
				{Ln}	{	;# Natiral logarithm
					set calc_display [expr {log($calc_buffer)}]
				}
				{ASin}	{	;# Arc sine
					set calc_display [expr {asin($calc_buffer)}]
					set calc_display [rad_to_Xangle $calc_display]
				}
				{ACos}	{	;# Arc cosine
					set calc_display [expr {acos($calc_buffer)}]
					set calc_display [rad_to_Xangle $calc_display]
				}
				{ATan}	{	;# Arc Tangent
					set calc_display [expr {atan($calc_buffer)}]
					set calc_display [rad_to_Xangle $calc_display]
				}
				{Sin}	{	;# Sine
					set calc_buffer [Xangle_to_rad $calc_buffer]
					set calc_display [expr {sin($calc_buffer)}]
				}
				{Cos}	{	;# Cosine
					set calc_buffer [Xangle_to_rad $calc_buffer]
					set calc_display [expr {cos($calc_buffer)}]
				}
				{Tan}	{	;# Arc tangent
					set calc_buffer [Xangle_to_rad $calc_buffer]
					set calc_display [expr {tan($calc_buffer)}]
				}
			}
		}]} then {
			# If error occurred -> show error message
			Sbar [mc "Calculator: ERROR (result value is out of allowed range)"]
			return
		}

		# If result value contain exponent -> show error message
		if {[regexp {e} $calc_display]} {
			Sbar[mc "Calculator: Unable to evaluate, result value is too high"]
			return
		}

		# Display result
		set calc_buffer {}
		set after_eval 1
		rewrite_buffer
		calc_opr {} 0
		write_display_inXbase $calc_display
	}

	## Safely clear display
	 # @return void
	public method calc_ClearActual {} {
		# enable UNDO operation
		enable_undo
		# save actual values
		set calc_last_display [reread_display]
		set calc_display {}
		set calc_last_buffer [reread_buffer]
		# show new values
		rewrite_display
	}

	## Safely clear display and buffer
	 # @return void
	public method calc_Clear {} {
		# enable UNDO operation
		enable_undo
		# save actual values
		set calc_last_display [reread_display]
		set calc_display {}
		set calc_last_buffer [reread_buffer]
		set calc_buffer {}
		calc_opr {} 0
		# show new values
		rewrite_display
		rewrite_buffer
	}

	## Enable execution of UNDO operation and disable REDO
	 # @return void
	private method enable_undo {} {
		# set status
		set ena_undo 1
		set ena_redo 0
		# enable/disable UNDO and REDO buttons
		enable_buttons {U}
		disable_buttons {RE}
	}

	## Enable execution of REDO operation and disable UNDO
	 # @return void
	private method enable_redo {} {
		# set status
		set ena_undo 0
		set ena_redo 1
		# enable/disable UNDO and REDO buttons
		enable_buttons {RE}
		disable_buttons {U}
	}

	## Take back the last operation
	 # @return void
	public method calc_UNDO {} {
		# enable REDO operation
		enable_redo
		# ....
		set after_eval 0
		# save actual status and restore previous
		calc_opr $calc_last_oper 0
		set tmp [reread_display]
		set calc_display $calc_last_display
		set calc_last_display $tmp
		set tmp [reread_buffer]
		set calc_buffer $calc_last_buffer
		set calc_last_buffer $tmp
		# show new values
		rewrite_display
		rewrite_buffer
		# inform user by starts bar
		Sbar [mc "Calculator: UNDO: previous state was: %s %s %s" $calc_last_buffer $calc_last_oper $calc_last_display]
	}

	## Take back the UNDO operation
	 # @return void
	public method calc_REDO {} {
		# enable UNDO operation
		enable_undo
		# save actual status and restore previous
		calc_opr $calc_last_oper 0
		set tmp [reread_display]
		set calc_display $calc_last_display
		set calc_last_display $tmp
		set tmp [reread_buffer]
		set calc_buffer $calc_last_buffer
		set calc_last_buffer $tmp
		# show new values
		rewrite_display
		rewrite_buffer
		# inform user by starts bar
		Sbar [mc "Calculator: REDO: previous state was: %s %s %s" $calc_last_buffer $calc_last_oper $calc_last_display]
	}

	## Convert content of both displays and all merory cells using given command
	 # @parm String command - command to use for converion
	 # @return void
	private method convert_displays {command} {

		# Determinate what displays aren't empty
		if {[reread_display] == {}} {set dis 0} {set dis 1}
		if {[reread_buffer] == {}} {set buf 0} {set buf 1}

		# Determinate what memory cells aren't empty
		for {set i 0} {$i < 3} {incr i} {
			set mem [[subst -nocommands "\$mem_entry_$i"] get]
			if {[string index $mem end] == {.}} {
				append mem 0
			}
			set memory$i $mem
			if {$mem == {} || $mem == 0} {
				set mem$i 0
			} else {
				set mem$i 1
			}
		}

		# Convert all non empty displays
		foreach cnd [list $dis $buf $mem0 $mem1 $mem2]	\
			var {calc_display calc_buffer memory0 memory1 memory2} {
			if {$cnd} {
				if {[catch {
					set $var [$command [subst -nocommands "\$$var"]]
				}]} then {
					Sbar [mc "Calculator: Value is too high to convert, value deleted !"]
					set $var 0
				}
			}
		}

		# Display new content of memory cells
		for {set i 0} {$i < 3} {incr i} {
			[subst -nocommands "\$mem_entry_$i"] delete 0 end
			[subst -nocommands "\$mem_entry_$i"] insert end [subst -nocommands "\$memory$i"]
		}
	}

	## Switch numeric base
	 # @return void
	public method cal_switchBase {} {

		# Get chosen value
		set base [subst -nocommands "\$::Calculator::calc_base$calc_idx"]

		# Convert display content to setected numeric system
		if {$base == $last_base} {
			set last_base $base
			return
		}

		# Adjust value in display and buffer
		if {[regexp {\.0$} $calc_display]} {
			set calc_display [string range $calc_display 0 {end-2}]
		}
		if {[regexp {\.0$} $calc_buffer]} {
			set calc_buffer [string range $calc_buffer 0 {end-2}]
		}

		# Covert content of all displays to new numeric base
		switch -- $base {
			{Hex}	{	;# to Hexadecimal
				enable_buttons {0 1 2 3 4 5 6 7 8 9 A B C D E F}
				switch -- $last_base {
					{Dec}	{convert_displays NumSystem::dec2hex}
					{Oct}	{convert_displays NumSystem::oct2hex}
					{Bin}	{convert_displays NumSystem::bin2hex}
				}
			}
			{Dec}	{	;# to Decimal
				disable_buttons {A B C D E F}
				enable_buttons {0 1 2 3 4 5 6 7 8 9}
				switch -- $last_base {
					{Hex}	{convert_displays NumSystem::hex2dec}
					{Oct}	{convert_displays NumSystem::oct2dec}
					{Bin}	{convert_displays NumSystem::bin2dec}
				}
			}
			{Oct}	{	;# to Octal
				disable_buttons {8 9 A B C D E F}
				enable_buttons {0 1 2 3 4 5 6 7}
				switch -- $last_base {
					{Hex}	{convert_displays NumSystem::hex2oct}
					{Dec}	{convert_displays NumSystem::dec2oct}
					{Bin}	{convert_displays NumSystem::bin2oct}
				}
			}
			{Bin}	{	;# to Binary
				disable_buttons {2 3 4 5 6 7 8 9 A B C D E F}
				enable_buttons {0 1}
				switch -- $last_base {
					{Hex}	{convert_displays NumSystem::hex2bin}
					{Dec}	{convert_displays NumSystem::dec2bin}
					{Oct}	{convert_displays NumSystem::oct2bin}
				}
			}
		}

		# Display new values
		rewrite_display
		rewrite_buffer

		# set last value
		set last_base $base
	}

	## Disable buttons specified in the given list
	 # example: disable_buttons {1 2} ;# disable .calc_1_0 and .calc_2_0
	 # @return void
	private method disable_buttons {buttons_list} {
		foreach path $buttons_list {
			$calc_num_keypad.calc_${path}	\
				configure -state disabled
		}
	}

	## Enable buttons specified in the given list
	 # example: enable_buttons {1 2} ;# enable .calc_1_0 and .calc_2_0
	 # @return void
	private method enable_buttons {buttons_list} {
		foreach path $buttons_list {
			$calc_num_keypad.calc_${path}	\
				configure -state normal
		}
	}

	## Switch angle unit
	 # @return void
	public method cal_switchAngle {} {

		# Get chosen unit
		set angle [subst -nocommands "\$::Calculator::calc_angle$calc_idx"]

		# Convert all displays
		if {$angle == $last_angle} {
			set last_angle $angle
			return
		}

		# Convert display if is not empty
		if {[read_display_inDec] != {}} {
			write_display_inXbase [Angle::${last_angle}2${angle} $calc_display]
		}

		# Convert buffer if is not empty
		if {[read_buffer_inDec] != {}} {
			write_buffer_inXbase [Angle::${last_angle}2${angle} $calc_buffer]
		}

		# Conver memory cells
		for {set i 0} {$i <3} {incr i} {
			# Get memory cell value
			set mem [[subst -nocommands "\$mem_entry_$i"] get]

			# Convert to decimal value
			if {$base != {Dec}} {
				switch -- $base {
					{Hex}	{	;# from Hexadecimal
						set mem [NumSystem::hex2dec $mem]
					}
					{Oct}	{	;# from Octal
						set mem [NumSystem::oct2dec $mem]
					}
					{Bin}	{	;# from Binary
						set mem [NumSystem::bin2dec $mem]
					}
				}
			}

			# Adjust that value
			if {[string index $mem end] == {.}} {
				append mem 0
			}

			# Display new value
			if {$mem != {}} {
				set mem [Angle::${last_angle}2${angle} $mem]

				# Convert to back from decimal value
				if {$base != {Dec}} {
					switch -- $base {
						{Hex}	{	;# to Hexadecimal
							set mem [NumSystem::dec2hex $mem]
						}
						{Oct}	{	;# to Octal
							set mem [NumSystem::dec2oct $mem]
						}
						{Bin}	{	;# to Binary
							set mem [NumSystem::dec2bin $mem]
						}
					}
				}

				[subst -nocommands "\$mem_entry_$i"] delete 0 end
				[subst -nocommands "\$mem_entry_$i"] insert end $mem
			}
		}

		# Set last unit
		set last_angle $angle
	}

	## Read content of main display in decimal system
	 # @return Float result
	private method read_display_inDec {} {
		# get display content
		if {[reread_display] != {}} {
			# convert to decimal value
			if {$base != {Dec}} {
				switch -- $base {
					{Hex}	{	;# from Hexadecimal
						set calc_display [NumSystem::hex2dec $calc_display]
					}
					{Oct}	{	;# from Octal
						set calc_display [NumSystem::oct2dec $calc_display]
					}
					{Bin}	{	;# from Binary
						set calc_display [NumSystem::bin2dec $calc_display]
					}
				}
			}
		}
		# done
		return $calc_display
	}

	## Write the given number (in dec) to main display (in selected base)
	 # @parm Float dec_content - number to display
	 # @return void
	private method write_display_inXbase {dec_content} {

		# If selected numeric base isn't Dec -> perform conversion
		if {$base != {Dec}} {
			switch -- $base {
				{Hex}	{	;# to Hexadecimal
					if {[catch {
						set calc_display [NumSystem::dec2hex $dec_content]
					}]} then {
						Sbar [mc "Calculator: ERROR, result is too high (cannot be displayed)"]
						set calc_display 0
					}
				}
				{Oct}	{	;# to Octal
					if {[catch {
						set calc_display [NumSystem::dec2oct $dec_content]
					}]} then {
						Sbar [mc "Calculator: ERROR, result is too high (cannot be displayed)"]
						set calc_display 0
					}
				}
				{Bin}	{	;# to Binary
					if {[catch {
						set calc_display [NumSystem::dec2bin $dec_content]
					}]} then {
						Sbar [mc "Calculator: ERROR, result is too high (cannot be displayed)"]
						set calc_display 0
					}
				}
			}
		# If selected numeric base is Dec -> do nothing
		} else {
			set calc_display $dec_content
		}

		# display (new) value
		rewrite_display
	}

	## Read content of buffer in decimal system
	 # @return Float result
	private method read_buffer_inDec {} {
		# Get content buffer display
		if {[reread_buffer] != {}} {
			# Convert to decimal value
			if {$base != {Dec}} {
				switch -- $base {
					{Hex}	{	;# from Hexadecimal
						set calc_buffer [NumSystem::hex2dec $calc_buffer]
					}
					{Oct}	{	;# from Octal
						set calc_buffer [NumSystem::oct2dec $calc_buffer]
					}
					{Bin}	{	;# from BInary
						set calc_buffer [NumSystem::bin2dec $calc_buffer]
					}
				}
			}
		}
		# done
		return $calc_buffer
	}

	## Write the given number (in dec) to buffer display (in selected base)
	 # @parm Float dec_content - number to display
	 # @return void
	private method write_buffer_inXbase {dec_content} {

		# If selected numeric base isn't Dec -> perform conversion
		if {$base != {Dec}} {
			switch -- $base {
				{Hex}	{	;# to Hexadecimal
					if {[catch {
						set calc_buffer [NumSystem::dec2hex $dec_content]
					}]} then {
						Sbar [mc "Calculator: ERROR, value is too high"]
						set calc_buffer 0
					}
				}
				{Oct}	{	;# to Octal
					if {[catch {
						set calc_buffer [NumSystem::dec2oct $dec_content]
					}]} then {
						Sbar [mc "Calculator: ERROR, value is too high"]
						set calc_buffer 0
					}
				}
				{Bin}	{	;# to Binary
					if {[catch {
						set calc_buffer [NumSystem::dec2bin $dec_content]
					}]} then {
						Sbar [mc "Calculator: ERROR, value is too high"]
						set calc_buffer 0
					}
				}
			}
		# If selected numeric base is Dec -> do nothing
		} else {
			set calc_buffer $dec_content
		}

		# display (new) value
		rewrite_buffer
	}

	## Write adjusted content of variable calc_display to main display widget
	 # @return void
	private method rewrite_display {} {
		# Adust content of source variable
		if {[regexp {\.0$} $calc_display]} {
			set calc_display [string range $calc_display 0 {end-2}]
		}
		# Show its content
		set ::Calculator::calc_displ$calc_idx $calc_display
	}

	## Write adjusted content of variable calc_buffer to buffer display widget
	 # @return void
	private method rewrite_buffer {} {
		# Adust content of source variable
		if {[regexp {\.0$} $calc_buffer]} {
			set calc_buffer [string range $calc_buffer 0 {end-2}]
		}
		# Show its content
		set ::Calculator::calc_buffer$calc_idx $calc_buffer
	}

	## Read true content of main display widget converted
	 # @parm args atf=0 - do not adjust to float
	 # @return Float - content of the main display
	private method reread_display {{atf 0}} {

		# Get content of the widget
		set calc_display [$calc_display_widget get]
		regsub {\,} $calc_display {.} calc_display

		# Adjust to float (if requested)
		if {!$atf} {
			if {[regexp {^\.} $calc_display]} {
				set calc_display "0$calc_display"
			} elseif {[regexp {\.$} $calc_display]} {
				append calc_display 0
			}
			if {[string first {.} $calc_display] == -1} {
				append calc_display {.0}
			}
		}

		# Remove trailing '.0'
		if {[regexp {^\.0$} $calc_display]} {
			set calc_display {}
		}

		# Return result
		return $calc_display
	}

	## Read true content of buffer display widget converted
	 # @return Float - content of the buffer
	private method reread_buffer {} {

		# Get content of the widget
		set calc_buffer [$calc_buffer_widget get]
		regsub {\,} $calc_buffer {.} calc_buffer

		# Adhust to float
		if {[regexp {^\.} $calc_buffer]} {
			set calc_buffer "0$calc_buffer"
		} elseif {[regexp {\.$} $calc_buffer]} {
			append calc_buffer 0
		}
		if {[string first {.} $calc_buffer] == -1} {
			append calc_buffer {.0}
		}

		# Remove trailing '.0'
		if {[regexp {^\.0$} $calc_buffer]} {
			set calc_buffer {}
		}

		# Return result
		return $calc_buffer
	}

	## Covert given angle to current angle unit
	 # @parm Float dec_angle - angle to convert in decimal
	 # @return Float - angle in radians
	private method Xangle_to_rad {dec_angle} {
		# If current angle unit isn't radians -> perform converison
		if {$angle != {rad}} {
			# From grad
			if {$angle == {grad}} {
				set dec_angle [Angle::grad2rad $dec_angle]
			# From degrees
			} else {
				set dec_angle [Angle::deg2rad $dec_angle]
			}
		}
		# return result
		return $dec_angle
	}

	## Convert given angle in radians to current angle unit
	 # @parm Float dec_angle - angle to conver in radians (decimal)
	 # @return Float - converted angle
	private method rad_to_Xangle {dec_angle} {
		# If current angle unit isn't radians -> perform converison
		if {$angle != {rad}} {
			# To grad
			if {$angle == {grad}} {
				set dec_angle [Angle::rad2grad $dec_angle]
			# To degrees
			} else {
				set dec_angle [Angle::rad2deg $dec_angle]
			}
		}
		# return result
		return $dec_angle
	}

	## Validate display content
	 # @parm Widget widget	- entry widget
	 # @parm String content - content to validate
	 # @return bool - result
	public method calc_validate {widget content} {

		# Set default background color for that widget
		if {$widget == $calc_display_widget} {
			$widget configure -style Calculator_Display.TEntry
		} elseif {$widget == $calc_buffer_widget} {
			$widget configure -style Calculator_Buffer.TEntry
		} else {
			$widget configure -style TEntry
		}

		# Valid if content is empty
		set len [string length $content]
		if {$len == 0 || $content == {-}} {
			return 1
		}

		# Invalid if content is too wide
		if {$len > 40} {
			Sbar [mc "Calculator: ERROR, value is too high"]
			if {[string length [$widget get]] > 13} {
				$widget configure -style Calculator_Error.TEntry
			}
			return 0
		}

		# Adjust content
		regsub {\,} $content {.} content
		if {[regexp {\.$} $content]} {
			append content 0
		}

		# Check for valid numeric base
		switch -- $base {
			{Hex}	{set content [NumSystem::ishex $content]}
			{Dec}	{set content [NumSystem::isdec $content]}
			{Oct}	{set content [NumSystem::isoct $content]}
			{Bin}	{set content [NumSystem::isbin $content]}
			default	{set content 0}
		}

		# Evaluate filan result
		if {$content} {
			if {$len > 13} {
				$widget configure -style Calculator_Error.TEntry
			}
			return 1
		} else {
			Sbar [mc "Calculator: Trying to insert invalid value"]
			return 0
		}
	}

	## Validate content of operator diaplay
	 # @parm String content - string to validate
	 # @return Bool - result of validation
	public method calc_oper_validate {content} {

		# Check for length
		if {[string length $content] > 4} {
			return 0
		}

		# Check for allowed content
		switch -- $content {
			{/}	{set calc_oper {div}}
			{*}	{set calc_oper {mul}}
			{-}	{set calc_oper {min}}
			{+}	{set calc_oper {add}}
			{**}	{set calc_oper {pow}}
			{mod}	{set calc_oper {mod}}
			{&}	{set calc_oper {and}}
			{|}	{set calc_oper {or}}
			{^}	{set calc_oper {xor}}
			{>>}	{set calc_oper {right}}
			{~}	{set calc_oper {not}}
			{e**}	{set calc_oper {Exp}}
			{sqrt}	{set calc_oper {Sqr}}
			{lg}	{set calc_oper {Log}}
			{ln}	{set calc_oper {Ln}}
			{sin}	{set calc_oper {Sin}}
			{cos}	{set calc_oper {Cos}}
			{tan}	{set calc_oper {Tan}}
			{asin}	{set calc_oper {ASin}}
			{acos}	{set calc_oper {ACos}}
			{atan}	{set calc_oper {ATan}}
			default	{
				# Set foteground color to #FF0000 if content is invalid
				set calc_oper {}
				$calc_oper_widget configure -style Calculator_OperError.TEntry
				return 1
			}
		}

		# Set foreground color to default and return result (True)
		$calc_oper_widget configure -style Calculator_Oper.TEntry
		return 1
	}

	## Negate content of the main display
	 # @return void
	public method calc_NegateDis {} {
		# Empty display -> abort
		if {[reread_display] == {}} {
			return

		# Negate value
		} else {
			if {[regexp {^\-} $calc_display]} {
				set calc_display [string range $calc_display 1 end]
			} else {
				set calc_display "-$calc_display"
			}
		}

		# Write result
		rewrite_display
	}

	## Prepare object for creating its GUI
	 # @parm Widget _parent		- parent widget (some frame)
	 # @parm List _calculatorList	- List of initial values (displays,, memory, radix, angle unit)
	 # @return void
	public method PrepareCalculator {_parent _calculatorList} {
		set parent $_parent
		set calculatorList $_calculatorList
		set calc_gui_initialized 0
	}

	## Inform this tab than it has became active
	 # @return void
	public method CalculatorTabRaised {} {
		$calc_display_widget selection range 0 end
		$calc_display_widget icursor end
		focus $calc_display_widget

		update idletasks
		$scrollable_frame yview scroll 0 units
	}

	## Initialize calculator GUI
	 # @return void
	public method CreateCalculatorGUI {} {
		if {$calc_gui_initialized} {return}
		set calc_gui_initialized 1

		if {${::DEBUG}} {
			puts "CreateCalculatorGUI \[ENTER\]"
		}

		# Create scrollable area
		set scrollable_frame [ScrollableFrame $parent.scrollable_frame	\
			-xscrollcommand "$this calc_gui_scroll_set"		\
		]
		set horizontal_scrollbar [ttk::scrollbar $parent.horizontal_scrollbar	\
			-orient horizontal -command "$scrollable_frame xview"		\
		]
		pack $scrollable_frame -fill both -side bottom -expand 1
		set parent [$scrollable_frame getframe]

		# LEFT HALF

		# create numeric keypad
		set calc_num_keypad [frame $parent.calc_num_keypad]
		makeKeypad $calc_num_keypad $calculator_keyboard


		# RIGHT HALF

		# create display
		set calc_num_display	[frame $parent.calc_num_display]
		set frame0		[frame $calc_num_display.calc_num_display0]
		set frame1		[frame $calc_num_display.calc_num_display1]

		# Buffer display
		set calc_buffer_widget	[ttk::entry $frame0.calc_buffer		\
			-textvariable ::Calculator::calc_buffer$calc_idx	\
			-validate key						\
			-validatecommand [list $this calc_validate %W %P]	\
			-width 13						\
			-style Calculator_Buffer.TEntry				\
		]
		DynamicHelp::add $frame0.calc_buffer -text [mc "Buffer display"]
		setStatusTip -widget $calc_buffer_widget \
			-text [mc "Calculator buffer"]
		# Operator display
		set calc_oper_widget	[ttk::entry $frame0.calc_oper		\
			-textvariable ::Calculator::calc_oper$calc_idx		\
			-validate all						\
			-width 3						\
			-validatecommand [list $this calc_oper_validate %P]	\
			-style Calculator_Oper.TEntry				\
		]
		DynamicHelp::add $frame0.calc_oper -text [mc "Selected operation"]
		setStatusTip -widget $calc_oper_widget	\
			-text [mc "Selected operation"]
		# Main display
		set calc_display_widget	[ttk::entry $frame0.calc_displ		\
			-textvariable ::Calculator::calc_displ$calc_idx		\
			-validate key						\
			-validatecommand [list $this calc_validate %W %P]	\
			-width 13						\
			-style Calculator_Display.TEntry			\
		]
		DynamicHelp::add $frame0.calc_displ -text [mc "Main display"]
		setStatusTip -widget $calc_display_widget \
			-text [mc "Main display"]
		# Pack displays
		pack $calc_buffer_widget	-side left
		pack $calc_oper_widget		-side left
		pack $calc_display_widget	-side left
		# Create binding for displays
		bind $calc_buffer_widget	<KP_Enter> [list $this calc_Evaluate]
		bind $calc_oper_widget		<KP_Enter> [list $this calc_Evaluate]
		bind $calc_display_widget	<KP_Enter> [list $this calc_Evaluate]
		bind $calc_buffer_widget	<Return> [list $this calc_Evaluate]
		bind $calc_oper_widget		<Return> [list $this calc_Evaluate]
		bind $calc_display_widget	<Return> [list $this calc_Evaluate]


		## Create: numeric base and angle unit switch + CA + C
		frame $frame1.lf
		# Numeric base switch
		pack [ttk::combobox $frame1.lf.calc_base_CB		\
			-state readonly 				\
			-values {Hex Dec Oct Bin}			\
			-textvariable ::Calculator::calc_base$calc_idx	\
			-width 4					\
		] -side left -padx 2
		bind $frame1.lf.calc_base_CB <<ComboboxSelected>> "$this cal_switchBase"
		DynamicHelp::add $frame1.lf.calc_base_CB -text [mc "Numeric base"]
		setStatusTip -widget $frame1.lf.calc_base_CB	\
			-text [mc "Numeric base"]
		# Angle unit switch
		pack [ttk::combobox $frame1.lf.calc_angle_CB		\
			-state readonly					\
			-values {rad deg grad}				\
			-textvariable ::Calculator::calc_angle$calc_idx	\
			-width 4					\
		] -side left -padx 2
		bind $frame1.lf.calc_angle_CB <<ComboboxSelected>> "$this cal_switchAngle"
		DynamicHelp::add $frame1.lf.calc_angle_CB -text [mc "Angle unit"]
		setStatusTip -widget $frame1.lf.calc_angle_CB	\
			-text [mc "Angle unit"]
		pack $frame1.lf -side left -padx 5

		frame $frame1.rf
		# Button "Clear"
		pack [ttk::button $frame1.rf.calc_Clear		\
			-text {C}				\
			-command [list $this calc_Clear]	\
			-width 3				\
		] -side left -padx 2
		DynamicHelp::add $frame1.rf.calc_Clear		\
			-text [mc "Clear both displays"]
		setStatusTip -widget $frame1.rf.calc_Clear	\
			-text [mc "Clear both displays"]
		# Button "Clear actual"
		pack [ttk::button $frame1.rf.calc_Clear_act	\
			-text {CA}				\
			-command [list $this calc_ClearActual]	\
			-width 3				\
		] -side left -padx 2
		DynamicHelp::add $frame1.rf.calc_Clear_act	\
			-text [mc "Clear main display"]
		setStatusTip -widget $frame1.rf.calc_Clear_act	\
			-text [mc "Clear main display"]
		# Button "Negate"
		pack [ttk::button $frame1.rf.calc_Negate_dis	\
			-text {+/-}				\
			-command [list $this calc_NegateDis]	\
			-width 3				\
		] -side left -padx 2
		DynamicHelp::add $frame1.rf.calc_Negate_dis	\
			-text [mc "Negate value in main display"]
		setStatusTip -widget $frame1.rf.calc_Negate_dis	\
			-text [mc "Negate value in main display"]
		pack $frame1.rf -side right -padx 5

		# Create calculator memory cells
		for {set i 0} {$i < 3} {incr i} {
			# Determinate ID of target frame
			set frame_id [frame $calc_num_display.calc_num_display[expr $i + 2]]
			# Label "Mx:"
			pack [Label $frame_id.calc_mem_label_${i}		\
				-text "M$i: " -helptext [mc "Memory bank %s" $i]\
			] -side left
			setStatusTip -widget $frame_id.calc_mem_label_${i}	\
				-text [mc "Memory bank %s" $i]
			# Entry widget
			set entry [ttk::entry $frame_id.calc_mem_entry_${i}		\
				-textvariable ::Calculator::calc_mem${i}_${calc_idx}	\
				-validate all						\
				-validatecommand [list $this calc_validate %W %P]	\
			]
			DynamicHelp::add $frame_id.calc_mem_entry_${i} -text [mc "Memory bank %s" $i]
			pack $entry -side left
			set mem_entry_$i $entry
			setStatusTip -widget $entry -text [mc "Memory bank %s" $i]
			# Button "Save"
			pack [ttk::button $frame_id.calc_mem_save_button_${i}	\
				-text [mc "Save"]				\
				-command "$this mem Save $i"			\
				-width 5					\
			] -side left -padx 2 -pady 2
			DynamicHelp::add $frame_id.calc_mem_save_button_${i}	\
				-text [mc "Save content of main display to this memory bank %s" $i]
			setStatusTip -widget $frame_id.calc_mem_save_button_${i}	\
				-text [mc "Save content of main display to this memory bank %s" $i]
			# Button "Load"
			pack [ttk::button $frame_id.calc_mem_load_button_${i}	\
				-text [mc "Load"]				\
				-command "$this mem Load $i"			\
				-width 5					\
			] -side left -padx 2 -pady 2
			DynamicHelp::add $frame_id.calc_mem_load_button_${i}	\
				-text [mc "Load content of this bank into main display"]
			setStatusTip -widget $frame_id.calc_mem_load_button_${i} \
				-text [mc "Load content of memory bank %s into calculator main display" $i]
		}

		bind $mem_entry_0 <Up>		"focus $mem_entry_2"
		bind $mem_entry_0 <Down>	"focus $mem_entry_1"

		bind $mem_entry_1 <Up>		"focus $mem_entry_0"
		bind $mem_entry_1 <Down>	"focus $mem_entry_2"

		bind $mem_entry_2 <Up>		"focus $mem_entry_1"
		bind $mem_entry_2 <Down>	"focus $mem_entry_0"


		# TIMERS CALC

		set calc_timers_calc [ttk::labelframe $parent.calc_timers_calc -text [mc "Timers preset"]]
		makeTimersCalc $calc_timers_calc


		# INNER INITIALIZATION

		# pack "left side" of calculator
		pack $calc_num_keypad -side left

		# pack "right side" of calculator
		for {set i 0} {$i < 5} {incr i} {
			if {$i == 1} {
				pack $calc_num_display.calc_num_display${i} -pady 10
			} else {
				pack $calc_num_display.calc_num_display${i}
			}
		}
		pack $calc_num_display -side left -padx 10

		# pack timres calc
		pack $calc_timers_calc -side left -expand 0 -anchor nw

		## save data given by $calculatorList
		 # "$base $angle $calc_display $calc_oper $calc_buffer $calc_mem0 $calc_mem1 $calc_mem2"
		set base	[lindex $calculatorList 0]
		set angle	[lindex $calculatorList 1]
		if {
			$base != {Hex} && $base != {Dec} &&
			$base != {Oct} && $base != {Bin}
		} then {
			set base [lindex ${X::project_edit_defaults} {3 1}]
			puts stderr [mc "Invalid numerical base: '%s'" $base]
		}
		if {$angle != {rad} && $angle != {deg} && $angle != {grad}} {
			puts stderr [mc "Invalid angle unit: '%s'" $angle]
			set angle [lindex ${X::project_edit_defaults} {4 1}]
		}
		set ::Calculator::calc_base$calc_idx	$base
		set ::Calculator::calc_angle$calc_idx	$angle

		set last_base	$base
		set last_angle	$angle

		# Enable/Disable buttons on numeric keypad
		switch -- $base {
			{Hex} {
				enable_buttons {0 1 2 3 4 5 6 7 8 9 A B C D E F}
				disable_buttons {U RE}}
			{Dec} {
				enable_buttons {0 1 2 3 4 5 6 7 8 9}
				disable_buttons {A B C D E F U RE}}
			{Oct} {
				enable_buttons {0 1 2 3 4 5 6 7}
				disable_buttons {8 9 A B C D E F U RE}}
			{Bin} {
				enable_buttons {0 1}
				disable_buttons {2 3 4 5 6 7 8 9 A B C D E F U RE}}
		}

		# Fill displays
		set calc_display	[lindex $calculatorList 2]
		rewrite_display
		calc_opr		[lindex $calculatorList 3] 0
		set calc_buffer		[lindex $calculatorList 4]
		rewrite_buffer
		set ::Calculator::calc_mem0_$calc_idx	[lindex $calculatorList 5]
		set ::Calculator::calc_mem1_$calc_idx	[lindex $calculatorList 6]
		set ::Calculator::calc_mem2_$calc_idx	[lindex $calculatorList 7]

		# Set frequenci and mode in timers calculator
		set freq [lindex $calculatorList 8]
		set mode [lindex $calculatorList 10]
		if {$freq == {} || [regexp {^\d\+$} $freq] || $freq < 0 || $freq > 99999} {
			set freq 12000
		}
		if {$mode != 0 && $mode != 1 && $mode != 2} {
			set mode 0
		}
		$timerscalc_freq_entry		insert 0 $freq
		$timerscalc_time_entry		insert 0 [lindex $calculatorList 9]
		$timerscalc_mode_spinbox	delete 0 end
		$timerscalc_mode_spinbox	insert 0 $mode

		# Unset teportary variables
		unset parent
		unset calculatorList
	}

	## Get calculator list for later initialization
	 # @return List - resulting list of values
	public method get_calculator_list {} {
		if {!$calc_gui_initialized} {CreateCalculatorGUI}
		return	[list $base $angle 		\
			[$calc_display_widget get]	\
			$calc_oper			\
			[$calc_buffer_widget get]	\
			[subst -nocommands "\$::Calculator::calc_mem0_$calc_idx"]	\
			[subst -nocommands "\$::Calculator::calc_mem1_$calc_idx"]	\
			[subst -nocommands "\$::Calculator::calc_mem2_$calc_idx"]	\
			[$timerscalc_freq_entry get]	\
			[$timerscalc_time_entry get]	\
			[$timerscalc_mode_spinbox get]]
	}

	## Validate and evaluate content of Frequency entry (timers calculator)
	 # @parm String content - String to validate (and evaluate)
	 # @return Bool - result of validation
	public method calc_timerscalc_freq_validate {content} {
		# If validation disabled -> abort
		if {$timerscalc_validation_dis} {
			return 1
		}

		# Ignore empty value
		if {$content == {}} {
			return 1
		}

		# If content is decimal number (max 5. digits) -> evaluate and return True
		if {[regexp {^\d+(\.\d*)?$} $content] && ([string length $content] < 9)} {
			calc_timerscalc_evaluate		\
				$content			\
				[$timerscalc_time_entry get]	\
				[$timerscalc_mode_spinbox get]	\

			return 1
		}
		# Otherwise -> return False
		Sbar [mc "Calculator - timers preset: you are trying to insert an invalid value"]
		return 0
	}

	## Validate and evaluate content of Mode entry (timers calculator)
	 # @parm String content - String to validate (and evaluate)
	 # @return Bool - result of validation
	public method calc_timerscalc_mode_validate {content} {
		# If validation disabled -> abort
		if {$timerscalc_validation_dis} {
			return 1
		}
		# If the given value is one of {0 1 2} the evaluate and return True
		if {[regexp {^\d?$} $content]} {
			if {$content > 2} {
				return 0
			}
			calc_timerscalc_evaluate		\
				[$timerscalc_freq_entry get]	\
				[$timerscalc_time_entry get]	\
				$content
			return 1
		}
		# Otherwise -> return False
		Sbar [mc "Calculator - timers preset: you are trying to insert an invalid value"]
		return 0
	}

	## Validate and evaluate content of Time entry (timers calculator)
	 # @parm String content - String to validate (and evaluate)
	 # @return Bool - result of validation
	public method calc_timerscalc_time_validate {content} {
		# If validation disabled -> abort
		if {$timerscalc_validation_dis} {
			return 1
		}
		# If content is decimal number (max 9. digits) -> evaluate and return True
		if {[regexp {^\d*$} $content] && ([string length $content] < 10)} {
			calc_timerscalc_evaluate		\
				[$timerscalc_freq_entry get]	\
				$content			\
				[$timerscalc_mode_spinbox get]
			return 1
		}
		# Otherwise -> return False
		Sbar [mc "Calculator - timers preset: you are trying to insert an invalid value"]
		return 0
	}

	## Highlight result of timer preset calculator
	 # @parm Bool valid - highlight for valid results
	 # @return void
	private method calc_timerscalc_highlight {valid} {

		# List of widgets to highlight
		set widgets "
			$timerscalc_THxDec_label
			$timerscalc_THxHex_label
			$timerscalc_THxOct_label
			$timerscalc_TLxDec_label
			$timerscalc_TLxHex_label
			$timerscalc_TLxOct_label
			$timerscalc_RepeatDec_label
			$timerscalc_RepeatHex_label
			$timerscalc_RepeatOct_label
			$timerscalc_CorrectionDec_label
			$timerscalc_CorrectionHex_label
			$timerscalc_CorrectionOct_label
		"

		# Perform highlighting
		if {$valid} {
			foreach widget $widgets {
				$widget configure -state normal
			}
		} else {
			foreach widget $widgets {
				$widget configure -state disabled
			}
		}
	}

	## Evaluate tmers preset (timers preset calculator)
	 # @parm Int freq	- Frequency
	 # @parm Int time	- Time in miliseconds
	 # @parm Int mode	- Mode {0 1 2}
	 # @return Bool - Resulting status
	private method calc_timerscalc_evaluate {freq time mode} {

		# Set default results
		set TLx		0
		set THx		0
		set repeat	0
		set correction	0

		# Remove leading dot from the frequency value
		set freq [string trimright $freq {.}]

		# Check for validity of given values
		if {$freq == {} || $freq == 0 || $time == {} || $mode == {} } {
			set mode {invalid}
		} else {
			# Compute time in machine cycles
			set time [expr {int($time * ($freq / 12000.0))}]
		}

		# Perform computation for the given mode
		switch -- $mode {
			0 {
				# Determinate apparent number of repeats
				set repeat [expr {($time >> 13) + 1}]
				# Compute tempotary results
				if {[expr {!($time & 0x1FFF)}]} {
					incr repeat -1
					set stepsPerIter 0x1FFF
				} else {
					set stepsPerIter [expr {$time / $repeat}]
					set tmp [expr {0x2000 - $stepsPerIter}]
					set TLx [expr {$tmp & 0x1F}]
					set THx [expr {$tmp >> 5}]
					set correction [expr {$time - ((0x1FFF - $tmp) * $repeat)}]
				}
			}
			1 {
				# Determinate apparent number of repeats
				set repeat [expr {($time >> 16) + 1}]
				# Compute tempotary results
				if {[expr {!($time & 0xFFFF)}]} {
					incr repeat -1
					set stepsPerIter 0xFFFF
				} else {
					set stepsPerIter [expr {$time / $repeat}]
					set tmp [expr {0x10000 - $stepsPerIter}]
					set TLx [expr {$tmp & 0xFF}]
					set THx [expr {$tmp >> 8}]
					set correction [expr {$time - ((0x10000 - $tmp) * $repeat)}]
				}
			}
			2 {
				# Determinate apparent number of repeats
				set repeat [expr {($time >> 8) + 1}]
				# Compute tempotary results
				if {[expr {!($time & 0xFF)}]} {
					incr repeat -1
					set stepsPerIter 0xFF
				} else {
					set stepsPerIter [expr {$time / $repeat}]
					set TLx [expr {0x100 - $stepsPerIter}]
					set THx $TLx
					set correction [expr {$time - ((0xFF - $THx) * $repeat)}]
				}
			}
			{invalid} {	;# Invalid input data
				calc_timerscalc_highlight 0
			}
			default {	;# Something went wrong
				error "Calculator error: Invalid timer mode $mode"
				return 0
			}
		}

		# If pre-computation was performed succesfully -- finish the results
		if {$mode != {invalid}} {
			# Highlight results as valid
			calc_timerscalc_highlight 1

			# Perform correction
			if {$correction >= $stepsPerIter} {
				incr repeat [expr {$correction / $stepsPerIter}]
				set correction [expr {$correction % $stepsPerIter}]
			}
		}

		# Check for allowed length of results (string representation)
		if {
			[string length [format "%o" $repeat]] > 6
				||
			[string length [format "%o" $correction]] > 6
		} then {
			set TLx		0
			set THx		0
			set repeat	0
			set correction	0
			calc_timerscalc_highlight 0
			Sbar [mc "Calculator: Unable to evaluate, result value is too high"]
		}

		## Write results
		 # THx values
		$timerscalc_THxDec_label configure -text $THx
		$timerscalc_THxHex_label configure -text [format "%X" $THx]
		$timerscalc_THxOct_label configure -text [format "%o" $THx]
		 # TLx values
		$timerscalc_TLxDec_label configure -text $TLx
		$timerscalc_TLxHex_label configure -text [format "%X" $TLx]
		$timerscalc_TLxOct_label configure -text [format "%o" $TLx]
		 # Repeat values
		$timerscalc_RepeatDec_label configure -text $repeat
		$timerscalc_RepeatHex_label configure -text [format "%X" $repeat]
		$timerscalc_RepeatOct_label configure -text [format "%o" $repeat]
		 # Correction values
		$timerscalc_CorrectionDec_label configure -text $correction
		$timerscalc_CorrectionHex_label configure -text [format "%X" $correction]
		$timerscalc_CorrectionOct_label configure -text [format "%o" $correction]

		return 1
	}

	## Create widgets of timers preset calculator
	 # @parm widget parent - parent contaner (some frame)
	 # @return void
	private method makeTimersCalc {parent} {
		# TOP HALF
		set top_frame [frame $parent.calc_timerscalc_top_frame]
		# frequency
		grid [label $top_frame.calc_timerscalc_freq_label	\
			-text [mc "Frequency \[kHz\]"]			\
		] -row 0 -column 0 -sticky w
		set timerscalc_freq_entry [ttk::entry					\
			$top_frame.calc_timerscalc_freq_entry				\
			-width 5							\
			-validate all							\
			-validatecommand "$this calc_timerscalc_freq_validate %P"	\
		]
		grid $timerscalc_freq_entry -row 0 -column 1 -sticky we
		# mode
		grid [label $top_frame.calc_timerscalc_mode_label	\
			-text [mc "Mode"]				\
		] -row 0 -column 2 -sticky w
		set timerscalc_mode_spinbox [ttk::spinbox			\
			$top_frame.calc_timerscalc_mode_spinbox		\
			-from 0 -to 2 -width 1 -validate key		\
			-validatecommand "$this calc_timerscalc_mode_validate %P"	\
			-command "$this calc_timerscalc_mode_validate \[$top_frame.calc_timerscalc_mode_spinbox get\]"
		]
		grid $timerscalc_mode_spinbox -row 0 -column 3 -sticky we
		# time
		grid [label $top_frame.calc_timerscalc_time_label	\
			-text [mc "Time \[us\]"]			\
		] -row 1 -column 0 -sticky w
		set timerscalc_time_entry [ttk::entry					\
			$top_frame.calc_timerscalc_time_entry				\
			-width 8							\
			-validate all							\
			-validatecommand "$this calc_timerscalc_time_validate %P"	\
		]
		grid $timerscalc_time_entry -row 1 -column 1 -sticky we -columnspan 3

		# BOTTOM HALF
		set bottom_frame [frame $parent.calc_timerscalc_bottom_frame]

		# "dec" "hex" "oct"
		grid [label $bottom_frame.calc_timerscalc_dec_label	\
			-text [mc "DEC"] -font $::smallfont -anchor e	\
			-highlightthickness 0				\
		] -row 0 -column 1 -ipadx 12
		grid [label $bottom_frame.calc_timerscalc_hex_label	\
			-text [mc "HEX"] -font $::smallfont -anchor e	\
			-highlightthickness 0				\
		] -row 0 -column 2 -ipadx 12
		grid [label $bottom_frame.calc_timerscalc_oct_label	\
			-text [mc "OCT"] -font $::smallfont -anchor e	\
			-highlightthickness 0				\
		] -row 0 -column 3 -ipadx 12

		# "THx" "TLx" "Repeat" "Correction"
		grid [label $bottom_frame.calc_timerscalc_thx_label	\
			-text "THx"					\
		] -row 1 -column 0 -sticky w
		grid [label $bottom_frame.calc_timerscalc_tlx_label	\
			-text "TLx"					\
		] -row 2 -column 0 -sticky w
		grid [label $bottom_frame.calc_timerscalc_repeat_label	\
			-text [mc "Repeats"]				\
		] -row 3 -column 0 -sticky w
		grid [label $bottom_frame.calc_timerscalc_correction_label	\
			-text [mc "Correction"]					\
		] -row 4 -column 0 -sticky w

		# THx values
		set timerscalc_THxDec_label [label				\
			$bottom_frame.calc_timerscalc_THxDec_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}	\
		]
		set timerscalc_THxHex_label [label				\
			$bottom_frame.calc_timerscalc_THxHex_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}	\
		]
		set timerscalc_THxOct_label [label				\
			$bottom_frame.calc_timerscalc_THxOct_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}	\
		]

		# TLx values
		set timerscalc_TLxDec_label [label				\
			$bottom_frame.calc_timerscalc_TLxDec_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}	\
		]
		set timerscalc_TLxHex_label [label				\
			$bottom_frame.calc_timerscalc_TLxHex_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}	\
		]
		set timerscalc_TLxOct_label [label				\
			$bottom_frame.calc_timerscalc_TLxOct_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}	\
		]

		# Repeat values
		set timerscalc_RepeatDec_label [label				\
			$bottom_frame.calc_timerscalc_RepeatDec_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}	\
		]
		set timerscalc_RepeatHex_label [label				\
			$bottom_frame.calc_timerscalc_RepeatHex_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}	\
		]
		set timerscalc_RepeatOct_label [label				\
			$bottom_frame.calc_timerscalc_RepeatOct_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}	\
		]

		# Correction values
		set timerscalc_CorrectionDec_label [label				\
			$bottom_frame.calc_timerscalc_CorrectionDec_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}		\
		]
		set timerscalc_CorrectionHex_label [label				\
			$bottom_frame.calc_timerscalc_CorrectionHex_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}		\
		]
		set timerscalc_CorrectionOct_label [label				\
			$bottom_frame.calc_timerscalc_CorrectionOct_label		\
			-text "0" -disabledforeground {#AAAAAA} -fg {#000033}		\
		]

		# Show widgets
		grid $timerscalc_THxDec_label		-row 1 -column 1 -sticky e
		grid $timerscalc_THxHex_label		-row 1 -column 2 -sticky e
		grid $timerscalc_THxOct_label		-row 1 -column 3 -sticky e
		grid $timerscalc_TLxDec_label		-row 2 -column 1 -sticky e
		grid $timerscalc_TLxHex_label		-row 2 -column 2 -sticky e
		grid $timerscalc_TLxOct_label		-row 2 -column 3 -sticky e
		grid $timerscalc_RepeatDec_label	-row 3 -column 1 -sticky e
		grid $timerscalc_RepeatHex_label	-row 3 -column 2 -sticky e
		grid $timerscalc_RepeatOct_label	-row 3 -column 3 -sticky e
		grid $timerscalc_CorrectionDec_label	-row 4 -column 1 -sticky e
		grid $timerscalc_CorrectionHex_label	-row 4 -column 2 -sticky e
		grid $timerscalc_CorrectionOct_label	-row 4 -column 3 -sticky e

		# Make widgets in table as small as possible
		foreach widget "
			$bottom_frame.calc_timerscalc_dec_label
			$bottom_frame.calc_timerscalc_hex_label
			$bottom_frame.calc_timerscalc_oct_label
			$bottom_frame.calc_timerscalc_thx_label
			$bottom_frame.calc_timerscalc_tlx_label
			$bottom_frame.calc_timerscalc_repeat_label
			$bottom_frame.calc_timerscalc_correction_label
			$timerscalc_THxDec_label
			$timerscalc_THxHex_label
			$timerscalc_THxOct_label
			$timerscalc_TLxDec_label
			$timerscalc_TLxHex_label
			$timerscalc_TLxOct_label
			$timerscalc_RepeatDec_label
			$timerscalc_RepeatHex_label
			$timerscalc_RepeatOct_label
			$timerscalc_CorrectionDec_label
			$timerscalc_CorrectionHex_label
			$timerscalc_CorrectionOct_label
		" {
			$widget configure -bd 0 -relief raised -pady 0 -highlightthickness 0
		}

		# Pack frames
		pack $top_frame -padx 5 -pady 2
		pack $bottom_frame -padx 5 -pady 2

		# Highlight calculator results as invalid
		calc_timerscalc_highlight 0
		set timerscalc_validation_dis 0
	}

	## Create calculator keypad
	 # @parm widget parent		- target contaner (some frame)
	 # @parm List definition	- keypad definition (see class header)
	 # @return void
	private method makeKeypad {parent definition} {
		# Local variables
		set row 0	;# Current row in the grid

		# Oterate over row definitions in the given keypad definition
		foreach line $definition {
			# Local variables
			set col 0	;# current column in the grid

			# Iterate  over button definitions in the row
			foreach item $line {
				if {$item == "separator"} {continue}

				# Inicalize array of button features
				for {set i 0} {$i < 13} {incr i} {
					set parm($i) [lindex $item $i]
				}

				if {[lsearch -ascii -exact {A B C D E} $parm(0)] != -1} {
					incr col
				}

				# Initialize default values for some items
				foreach i {3 4 7} {
					if {$parm($i) == {}} {set parm($i) 1}
				}
				if {$parm(6) == {}} {set parm(6) 2}
				if {$parm(8) == {}} {set parm(8) 0}
				if {$parm(9) == {}} {set parm(9) {#FFFFFF}}
				if {$parm(10) == {}} {set parm(10) {#FFFFFF}}

				if {[string index $parm(9) 0] == {#}} {
					set parm(9) {Calculator}
				}

				# Set button ID
				set path "$parent.calc_$parm(1)"
				# Create button
				ttk::button $path			\
					-text $parm(0)			\
					-command "$this $parm(2)"	\
					-width $parm(6)			\
					-style $parm(9).TButton
# 				-activebackground $parm(10)	\
# 				-height		$parm(7)	\
				DynamicHelp::add $path -text [mc $parm(5)]
				# Confugure button
# 				if {$parm(11) == 1} {$path configure -font $large_font -pady 2}
				if {$parm(12) != {}} {
					setStatusTip -widget $path -text [mc $parm(12)]
				}

				if {$parm(3) > 1} {
					set sticky {we}
				} elseif {$parm(4) > 1} {
					set sticky {ns}
				} else {
					set sticky {}
				}

				# Show button
				grid $path			\
					-columnspan $parm(3)	\
					-rowspan $parm(4)	\
					-sticky $sticky		\
					-padx 2			\
					-pady 2			\
					-column $col		\
					-row $row

				# Incremet number of current column
				incr col $parm(3)
			}
			# Incremet number of current row
			incr row
		}

		grid columnconfigure $parent 4 -minsize 10
	}

	## Adjust scrollbar for scrollable area
	 # @parm Float frac0	- 1st fraction
	 # @parm Float frac0	- 2nd fraction
	 # @return void
	public method calc_gui_scroll_set {frac0 frac1} {
		# Hide scrollbar
		if {$frac0 == 0 && $frac1 == 1} {
			if {[winfo ismapped $horizontal_scrollbar]} {
				pack forget $horizontal_scrollbar
				update
			}
		# Show scrollbar
		} else {
			if {![winfo ismapped $horizontal_scrollbar]} {
				pack $horizontal_scrollbar -fill x -side top -before $scrollable_frame
			}
			$horizontal_scrollbar set $frac0 $frac1
			update
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

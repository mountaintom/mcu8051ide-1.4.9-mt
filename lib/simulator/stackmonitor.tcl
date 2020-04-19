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
#    MERCHANTABILITY or FITNESS FOR A PARTMCULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program; if not, write to the                         #
#    Free Software Foundation, Inc.,                                       #
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################

# >>> File inclusion guard
if { ! [ info exists _STACKMONITOR_TCL ] } {
set _STACKMONITOR_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# MCU stack monitor, a part of simulator GUI
# --------------------------------------------------------------------------

class StackMonitor {

	## COMMON
	public common push_value	{}				;# String: Value to PUSH onto the stack by user
	public common stack_mon_count	0				;# Int: Counter of intances
	public common geometry		${::CONFIG(STACK_MON_GEOMETRY)}	;# Geometry: Last window geometry
	public common collapsed	${::CONFIG(STACK_MON_COLLAPSED)};# Bool: Bottom bar hidden
	 # Font for the text widget representing the stack (bold)
	public common font0		[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
	]
	 # Font for the text widget representing the stack (normal)
	public common font1		[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight normal					\
	]

	## PRIVATE
	private variable dialog_opened	0	;# Bool: Dialog window opened
	private variable win			;# Widget: Dialog window
	private variable obj_idx		;# Int: Object index
	private variable enabled	0	;# Bool: Monitor enabled
	private variable addresses	[list]	;#

	private variable values_txt		;# Widget: Text widget representing the stack contents
	private variable sp_val			;# Widget: Entry widget for SP
	private variable col_exp_button		;# Widget: Button show/hide bottom bar (legend)
	private variable clear_all_but		;# Widget: Button "Clear"
	private variable push_but		;# Widget: Button "PUSH"
	private variable pop_but		;# Widget: Button "POP"
	private variable tool_frame		;# Widget: Frame with the bottom bar (legend)

	constructor {} {
		# Increment counter of object instances
		incr stack_mon_count
		set obj_idx $stack_mon_count
	}

	destructor {
		# Close stack monitor window
		stack_monitor_monitor_close
	}


	## Invoke stack monitor window
	 # @return void
	public method stack_monitor_invoke_dialog {} {
		if {$dialog_opened} {
			raise $win
			return
		}
		set dialog_opened 1

		# Create dialog window
		set win [toplevel .stack_monitor${stack_mon_count} -class {Interrupt monitor} -bg ${::COMMON_BG_COLOR}]
		incr stack_mon_count

		# Create window frames (main frame and status bar, etc.)
		set top_frame [frame $win.top_frame]
		set bottom_frame [frame $win.bottom_frame]
		set tool_frame [frame $win.tool_frame]

		## Create GUI part with the text widget representing the stack contents
		set left_frame [frame $top_frame.left_frame -bd 1 -relief sunken]
		 # Text widget
		set values_txt [text $left_frame.values_txt		\
			-width 27 -state disabled -cursor left_ptr	\
			-font $font0 -bd 0 -height 0			\
			-yscrollcommand "$top_frame.scrollbar set"	\
			-highlightthickness 0				\
		]
		 # Header
		pack [label $left_frame.header				\
			-font $font0 -width 27				\
			-justify left -anchor w -background {#DDDDDD}	\
			-bd 0 -text [mc "Addr HH Dec  Binary  Oct A"]	\
		] -anchor w -fill x
		pack $values_txt -fill both -expand 1
		$values_txt tag configure tag_general -background {#CCCCFF}
		$values_txt tag configure tag_subprog -background {#CCFFCC}
		$values_txt tag configure tag_interrupt -background {#FFCCCC}
		bind $values_txt <ButtonRelease-3> {break}
		bind $values_txt <<Selection>> "false_selection $values_txt; break"
		 # Scrollbar
		pack $left_frame -side left -fill both -expand 1
		pack [ttk::scrollbar $top_frame.scrollbar	\
			-command "$values_txt yview"		\
			-orient vertical			\
		] -side right -fill y


		## Stack pointer
		pack [label $bottom_frame.sp_lbl	\
			-text [mc "SP: "]		\
		] -side left
		 # Create register hexadecimal entry
		set sp_val [ttk::entry $bottom_frame.sp_val				\
			-validatecommand "$this entry_2_hex_validate_and_sync %P SP"	\
			-textvariable ::Simulator_GUI::ENV${obj_idx}_SP			\
			-font $::Simulator_GUI::entry_font				\
			-validate key							\
			-width 2							\
		]
		DynamicHelp::add $sp_val -text [mc "Current stack pointer value"]
		bindtags $sp_val [list $sp_val TEntry all .]
		pack $sp_val -side left

		## Buttons ("Clear", "PUSH", "POP", etc.)
		set clear_all_but [ttk::button $bottom_frame.clr_but	\
			-text [mc "Clear"]				\
			-command "$this stack_monitor_clear_all"	\
			-width 5					\
		]
		pack $clear_all_but -side right
		set push_but [ttk::button $bottom_frame.push_but	\
			-text [mc "PUSH"]				\
			-command "$this stack_monitor_manual_push"	\
			-width 5					\
		]
		pack $push_but -side right
		set pop_but [ttk::button $bottom_frame.pop_but		\
			-text [mc "POP"]				\
			-command "$this stack_monitor_manual_pop"	\
			-width 5					\
		]
		pack $pop_but -side right
		set col_exp_button [ttk::button $bottom_frame.expand_button	\
			-image ::ICONS::16::2downarrow				\
			-style Flat.TButton					\
			-command "$this stack_monitor_col_exp"			\
			-width 5						\
		]
		DynamicHelp::add $sp_val -text [mc "Show/Hide tool bar"]
		pack $col_exp_button -side right -padx 5

		# Pack frames except for the bottom bar (with legend)
		pack $top_frame -fill both -expand 1
		pack $bottom_frame -anchor w -fill x

		## Create bottom bar (with legend)
		pack [ttk::separator $tool_frame.sep -orient horizontal] -fill x
		 # Legend itself
		pack [label $tool_frame.legent_lbl -text [mc "Legend:"]] -anchor w
		pack [frame $tool_frame.lf] -fill y
		pack [label $tool_frame.lf.gl1 -text [mc "General"] -font $font0 -bg {#CCCCFF}] -side left -fill y
		pack [label $tool_frame.lf.sl1 -text [mc "Subprogram"] -font $font0 -bg {#CCFFCC}] -side left -fill y -padx 3
		pack [label $tool_frame.lf.il1 -text [mc "Interrupt"] -font $font0 -bg {#FFCCCC}] -side left -fill y

		# Show or keep the bottom bar hidden according to previous session
		if {!$collapsed} {
			set collapsed [expr {!$collapsed}]
			stack_monitor_col_exp
		}
		stack_monitor_set_enabled $enabled

		# Set window attributes
		wm iconphoto $win ::ICONS::16::kcmmemory_ST
		wm title $win [mc "Stack - %s - MCU 8051 IDE" [$this cget -projectName]]
		wm minsize $win 225 90
		if {$geometry != {}} {
			wm geometry $win $geometry
		}
		wm resizable $win 0 1
		wm protocol $win WM_DELETE_WINDOW "$this stack_monitor_monitor_close"
		bindtags $win [list $win Toplevel all .]
	}

	## Close stack monitor window
	 # @return void
	public method stack_monitor_monitor_close {} {
		if {!$dialog_opened} {return}

		set geometry		[wm geometry $win]
		set dialog_opened	0

		if {[winfo exists $win]} {
			destroy $win
		}
	}

	## Reset the stack monitor -- Clear all entries
	 # This should be called when the simulated MCU get reseted
	 # @return void
	public method stack_monitor_reset {} {
		if {!$dialog_opened} {return}

		set addresses [list]

		$values_txt configure -state normal
		$values_txt delete 0.0 end
		$values_txt configure -state disabled
	}

	## Push a value on the MCU stack monitor
	 # In other words, this method informs the stack monitor that there was
	 #+ some value pushed on the MCU stack in simulator.
	 # This method should be called from simulator engine only.
	 # @parm Int addr	- Address where the value is physicaly located
	 # @parm Int dec_val	- Decimal representation of the pushed value
	 # @return void
	public method stack_monitor_push {addr dec_val} {
		# If the dialog is not opened then abort this
		if {!$dialog_opened} {return}

		# Adjust list of register addresses involved
		lappend addresses $addr

		# Convert address to two digits hexadecimal number
		set str {}
		set val [format {%X} $addr]
		if {[string length $val] == 1} {
			set val "0${val}"
		}
		append str { } $val {  }
		# Convert value to two digits hexadecimal number
		set val [format {%X} $dec_val]
		if {[string length $val] == 1} {
			set val "0${val}"
		}
		# Convert value to three digits decimal number
		append str $val { } [string repeat { } [expr {3 - [string length $dec_val]}]] $dec_val { }
		# Convert value to eight digits binary number
		set val [NumSystem::dec2bin $dec_val]
		append str [string repeat {0} [expr {8 - [string length $val]}]] $val { }
		# Convert value to three digits octal number
		set val [NumSystem::dec2oct $dec_val]
		append str [string repeat {0} [expr {3 - [string length $val]}]] $val { }
		set val { }
		# Convert value to one character long ASCII representation
		if {$dec_val >= 0x20 && $dec_val <= 0x7E} {
			set val [format %c $dec_val]
		}
		append str $val "\n"

		# Show it to user
		$values_txt configure -state normal
		$values_txt insert 1.0 $str
		$values_txt configure -state disabled
	}

	## Mark a few most recent values as values of certain type
	 # @parm Int type	-
	 #	0 - General
	 #	1 - Subprogram return address
	 #	2 - Interrupt routine return address
	 # @parm Int length	- Number of bytes to mask
	 # @return void
	public method stack_monitor_set_last_values_as {type length} {
		if {!$dialog_opened} {return}

		switch -- $type {
			0 {set tag {tag_general}}
			1 {set tag {tag_subprog}}
			2 {set tag {tag_interrupt}}
		}

		for {set i 1} {$i <= $length} {incr i} {
			$values_txt tag add $tag $i.0 $i.4
		}
	}

	## Pop a value from the MCU stack monitor
	 # In other words, this method informs the stack monitor that there was
	 #+ some value poped from the MCU stack in simulator.
	 # @return void
	public method stack_monitor_pop {} {
		if {!$dialog_opened} {return}

		set addresses [lreplace $addresses end end]

		$values_txt configure -state normal
		$values_txt delete 1.0 2.0
		$values_txt configure -state disabled
	}


	## Show or hide bottom panel with legend
	 # @return void
	public method stack_monitor_col_exp {} {
		set collapsed [expr {!$collapsed}]

		if {$collapsed} {
			set image 2downarrow
			pack forget $tool_frame
		} else {
			set image 2uparrow
			pack $tool_frame -fill y -anchor nw
		}

		$col_exp_button configure -image ::ICONS::16::$image
	}


	## Pop the last pushed value manually (do it also in the simulator)
	 # @return void
	public method stack_monitor_manual_pop {} {
		if {!$dialog_opened || !$enabled} {return}

		# Decrement SP register
		set sp [$this getSfrDEC 129]
		if {!$sp} {return}
		$this setSfr 129 [format {%x} [expr {$sp - 1}]]
		$this Simulator_GUI_sync S 129

		stack_monitor_pop
	}


	## Push a value manually (do it also in the simulator)
	 # This method just pushes a value previously entered via the dialog
	 #+ intended for that purpose
	 # @return void
	public method stack_monitor_manual_push_val {} {
		# Retrieve the value from the dialog GUI
		set value ${::StackMonitor::push_value}

		# Check validity of the value
		if {$value == {}} {
			return
		}
		if {![string is xdigit $value]} {
			return
		}

		# Convert it from hexadecimal to decimal
		set value [expr "0x$value"]
		if {$value > 255 || $value < 0} {
			return
		}

		## Push it on the MCU stack
		set foo ${::Simulator::reverse_run_steps}
		$this stack_push $value
		$this Simulator_sync_reg [$this getSfrDEC 129]
		stack_monitor_set_last_values_as 0 1
		$this Simulator_GUI_sync S 129
		set ::Simulator::reverse_run_steps $foo
	}

	## Invoke dialog intended for pushing values on the stack
	 # @return void
	public method stack_monitor_manual_push {} {
		# Stack monitor must be opened and enabled ...
		if {!$dialog_opened || !$enabled} {return}

		# This dialog cannot be opened more than once at the time
		if {[winfo exists .manual_push${obj_idx}]} {
			raise .manual_push${obj_idx}
			return
		}

		# Create toplevel window
		set dlg [toplevel .manual_push${obj_idx}  -class {Push value onto stack} -bg ${::COMMON_BG_COLOR}]

		# Create label, entryBox and horizontal separator
		pack [label $dlg.lbl -text [mc "Push value onto stack (HEX)"]] -fill x -anchor w -padx 5
		pack [ttk::entry $dlg.ent				\
			-width 3					\
			-validate all					\
			-textvariable ::StackMonitor::push_value	\
			-validatecommand {apply {p {
					if {[string length $p] > 2 || ![string is xdigit $p]} {
						return 0
					} else {
						return 1
					}
					}} %P
			}
		] -fill x -padx 10 -side left
		bindtags $dlg.ent [list $dlg.ent TEntry $dlg $win all .]

		bind $dlg.ent <Return>		"$this stack_monitor_manual_push_val"
		bind $dlg.ent <KP_Enter>	"$this stack_monitor_manual_push_val"

		# Create button frame
		set buttonFrame [frame $dlg.buttonFrame]
		pack [ttk::button $buttonFrame.ok			\
			-width 5					\
			-text [mc "PUSH"]				\
			-compound left					\
			-image ::ICONS::16::down0			\
			-command "$this stack_monitor_manual_push_val"	\
		] -side left -padx 2
		pack [ttk::button $buttonFrame.cancel		\
			-width 5				\
			-text [mc "Close"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command "
				grab release $dlg
				destroy $dlg"			\
		] -side left -padx 2
		pack $buttonFrame -side right -padx 5

		# Set window attributes
		wm iconphoto $dlg ::ICONS::16::kcmmemory_ST
		wm title $dlg [mc "Push value onto stack."]
		wm minsize $dlg 200 60
		wm transient $dlg $win
		wm protocol $dlg WM_DELETE_WINDOW "
			grab release $dlg
			destroy $dlg"
		update
		raise $dlg
		focus $dlg.ent
	}


	## Clear contents of the monitor and do not affect simulator engine
	 # This method shoul be called on user request. It asks for confimation.
	 # @return void
	public method stack_monitor_clear_all {} {
		if {!$dialog_opened || !$enabled} {return}

		# Confirmation
		if {[tk_messageBox		\
			-type yesno		\
			-default yes		\
			-icon question		\
			-parent $win		\
			-title [mc "Confirmation"]	\
			-message [mc "Do you really want to clear the list without any effect in simulator engine ?"]
		] != {yes}} {
			return
		}

		# Clear all
		set addresses [list]
		$values_txt configure -state normal
		$values_txt delete 0.0 end
		$values_txt configure -state disabled
	}

	## Enable or disable the stack monitor
	 # When simulator get started or stopped this method should be used to
	 #+ inform the dialog about it
	 # @parm Bool bool - 1 == Enable; 0 == Disable
	 # @return void
	public method stack_monitor_set_enabled {bool} {
		set enabled $bool
		if {!$dialog_opened} {return}

		if {$enabled} {
			set state {normal}
		} else {
			set state {disabled}
		}

		$clear_all_but	configure -state $state
		$push_but	configure -state $state
		$pop_but	configure -state $state
		$sp_val	configure -state $state
	}

	## Synchronize the stack monitor with the simulator engine
	 # @parm Int addr - Address of register to synchronize
	 # @return void
	public method stack_monitor_sync {addr} {
		if {!$dialog_opened} {return}

		# Determinate whether the specified address is involved in the stack
		set idx [lsearch -ascii -exact $addresses $addr]
		if {$idx == -1} {return}

		# Get the new value of the register
		set idx [expr {[llength $addresses] - $idx}]
		set dec_val [$this getDataDEC $addr]

		# Display the new value to the user ...
		set val [format {%X} $dec_val]
		if {[string length $val] == 1} {
			set val "0${val}"
		}
		append str $val { } [string repeat { } [expr {3 - [string length $dec_val]}]] $dec_val { }
		set val [NumSystem::dec2bin $dec_val]
		append str [string repeat {0} [expr {8 - [string length $val]}]] $val { }
		set val [NumSystem::dec2oct $dec_val]
		append str [string repeat {0} [expr {3 - [string length $val]}]] $val { }
		set val { }
		if {$dec_val >= 0x20 && $dec_val <= 0x7E} {
			set val [format %c $dec_val]
		}
		append str $val
		$values_txt configure -state normal
		$values_txt delete $idx.5 [list $idx.0 lineend]
		$values_txt insert $idx.5 $str
		$values_txt configure -state disabled
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

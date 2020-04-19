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
if { ! [ info exists _INTERRUPTMONITOR_TCL ] } {
set _INTERRUPTMONITOR_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements interrupt monitor
# --------------------------------------------------------------------------

class InterruptMonitor {
	## COMMON
	public common geometry		${::CONFIG(INTR_MON_GEOMETRY)}	;# Last window geometry
	public common intr_mon_count	0				;# Counter of intances
	public common bg_color		{#0088FF}			;# Color for highlighted background
	 # Small header font
	public common header_font	[font create			\
		-size [expr {int(-17 * $::font_size_factor)}]	\
		-weight bold					\
		-family {helvetica}				\
	]
	 # Big header font
	public common header_font_big	[font create			\
		-size [expr {int(-21 * $::font_size_factor)}]	\
		-weight bold					\
		-family {helvetica}				\
	]
	 # Common label font
	public common lbl_font		[font create			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-family {helvetica}				\
	]
	 # Font for value labels
	public common val_font		[font create			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
		-family {helvetica}				\
	]
	 # Font for value labels - underline
	public common val_font_under	[font create			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
		-family {helvetica}				\
		-underline 1					\
	]


	## PRIVATE
	private variable dialog_opened		0	;# Bool: Dialog window opened
	private variable win				;# Widget: Dialog window
	private variable in_progress_frame		;# Widget: Scrollable frame area for interrupts in progress
	private variable pending_frame			;# Widget: Scrollable frame area for pending interrupts
	private variable priorities_frame		;# Widget: Scrollable frame area for interrupt priorities
	private variable in_progress_frame_f		;# Widget: Scrollable frame for interrupts which are in progress
	private variable pending_frame_f		;# Widget: Scrollable frame for pending interrupts
	private variable priorities_frame_f		;# Widget: Scrollable frame for interrupt priorities
	private variable status_bar			;# Widget: Dialog status bar label

	private variable in_progress_wdg	{}	;# List: Interrupt sub windows for interrupts in porgress
	private variable in_progress_flg	{}	;# List: Flags of interrupts which are in progress
	private variable intr_priorities	{}	;# List: Interrupt flags in order of their priorities (decremental)
	private variable pending_flg		{}	;# List: Flags of pending interrupts
	private variable available_interrs	{}	;# List: available interrupt flags
	private variable maximum_priority	0	;# Int: Maximum valid priority


	constructor {} {
		# Configure specific ttk styles
		ttk::style configure InterruptMonitor_Flat.TButton	\
			-background $bg_color				\
			-padding 0					\
			-borderwidth 1					\
			-relief flat
		ttk::style map InterruptMonitor_Flat.TButton		\
			-relief [list active raised]			\
			-background [list disabled $bg_color active $bg_color]
	}

	destructor {
	}

	## Close interrupt monitor window and free its resources
	 # @return void
	public method interrupt_monitor_close {} {
		if {!$dialog_opened} {
			return
		}

		set geometry		[wm geometry $win]
		set dialog_opened	0
		set in_progress_wdg	{}
		set in_progress_flg	{}
		set pending_flg		{}
		set intr_priorities	{}
		set available_interrs	{}

		if {[winfo exists $win]} {
			destroy $win
		}
	}

	## Invoke interrupt monitor window
	 # @return void
	public method interrupt_monitor_invoke_dialog {} {
		if {$dialog_opened} {return}
		set dialog_opened 1

		# Create dialog window, main frame and status bar
		set win [toplevel .interrupt_monitor${intr_mon_count} -class {Interrupt monitor} -bg ${::COMMON_BG_COLOR}]
		incr intr_mon_count
		set main_frame [frame $win.main_frame]
		set status_bar [label $win.status_bar]

		# Create scrollable frames
		set in_progress_frame_f	[ScrollableFrame $main_frame.in_p	\
			-width 280 -areawidth 280				\
			-yscrollcommand "$main_frame.in_p_scrl set"		\
		]
		set pending_frame_f	[ScrollableFrame $main_frame.pending	\
			-width 250 -areawidth 250				\
			-yscrollcommand "$main_frame.pend_scrl set"		\
		]
		set priorities_frame_f	[ScrollableFrame $main_frame.prior	\
			-width 250 -areawidth 250				\
			-yscrollcommand "$main_frame.prior_scrl set"		\
		]

		# Create headers for scrollable frames
		set top_frame_0 [frame $main_frame.top_frame_0]
		set top_frame_1 [frame $main_frame.top_frame_1]
		set top_frame_2 [frame $main_frame.top_frame_2]
		foreach num {0 1 2} text {
			"Interrupts in progress"
			"Pending interrupts"
			"Interrupt priorities"
		} {
			set frame [subst -nocommands "\$top_frame_${num}"]
			pack [ttk::button $frame.expand					\
				-image ::ICONS::16::add					\
				-style Flat.TButton					\
				-command "$this interrupt_monitor_expand $num"		\
			] -side left -anchor w -padx 3
			set_status_tip $frame.expand [mc "Expand all"]
			pack [ttk::button $frame.collapse				\
				-image ::ICONS::16::sub					\
				-style Flat.TButton					\
				-command "$this interrupt_monitor_collapse $num"	\
			] -side left -anchor w
			set_status_tip $frame.collapse [mc "Collapse all"]
			pack [label $frame.in_p_lbl	\
				-font $header_font	\
				-text [mc $text]	\
			] -side left -fill x -expand 1
		}

		# Show headers for scrollable frames
		grid $top_frame_0 -row 0 -column 0 -columnspan 2 -sticky we -padx 5
		grid $top_frame_1 -row 0 -column 3 -columnspan 2 -sticky we -padx 5
		grid $top_frame_2 -row 0 -column 6 -columnspan 2 -sticky we -padx 5

		# Crate and show scrollbars
		grid [ttk::scrollbar	$main_frame.in_p_scrl	\
			-orient vertical			\
			-command "$in_progress_frame_f yview"	\
		] -row 1 -column 1 -sticky ns
		grid [ttk::scrollbar	$main_frame.pend_scrl	\
			-orient vertical			\
			-command "$pending_frame_f yview"	\
		] -row 1 -column 4 -sticky ns
		grid [ttk::scrollbar	$main_frame.prior_scrl	\
			-orient vertical			\
			-command "$priorities_frame_f yview"	\
		] -row 1 -column 7 -sticky ns

		# Show scrollable frames
		grid $in_progress_frame_f	-sticky ns -padx 3 -row 1 -column 0
		grid $pending_frame_f		-sticky ns -padx 3 -row 1 -column 3
		grid $priorities_frame_f	-sticky ns -padx 3 -row 1 -column 6
		grid rowconfigure $main_frame 1 -weight 1

		# Set spaces between scrollable frames
		grid columnconfigure $main_frame 2 -minsize 2
		grid columnconfigure $main_frame 5 -minsize 2

		# Set container frames fro scrollable frames
		set in_progress_frame	[$in_progress_frame_f	getframe]
		set pending_frame	[$pending_frame_f	getframe]
		set priorities_frame	[$priorities_frame_f	getframe]

		# Fill GUI
		set maximum_priority		[$this simulator_get_max_intr_priority]
		interrupt_monitor_set_available	[$this simulator_get_intr_flags]
		interrupt_monitor_reevaluate

		# Pack main frame and create bottom frame
		pack $main_frame -fill both -expand 1
		pack [ttk::separator $win.sep -orient horizontal]	\
			-fill x -pady 3
		pack $status_bar -side left -fill x -padx 10
		pack [ttk::button $win.close_but			\
			-text [mc "Close"]				\
			-compound left					\
			-command "$this interrupt_monitor_close"	\
			-image ::ICONS::16::button_cancel 		\
		] -side right -pady 5 -padx 10
		set_status_tip $win.close_but [mc "Close this dialog window"]

		# Set window attributes
		wm iconphoto $win ::ICONS::16::kcmdf
		wm title $win "[mc {Interrupt monitor}] - [$this cget -projectName] - MCU 8051 IDE"
		wm minsize $win 850 270
		if {$geometry != {}} {
			regsub {\+\d+\+} $geometry {+850+} geometry
			wm geometry $win $geometry
		}
		wm resizable $win 0 1
		wm protocol $win WM_DELETE_WINDOW [list $this interrupt_monitor_close]
		bindtags $win [list $win Toplevel all .]
	}

	## Return true if this dialog is opened
	 # @return Bool result
	public method interrupt_monitor_is_opened {} {
		return $dialog_opened
	}

	## Reevaluate content of the monitor
	 # @return void
	public method interrupt_monitor_reevaluate {} {
		if {!$dialog_opened} {return}

		# Remove interrupts in progress
		foreach widget $in_progress_wdg {
			destroy $widget
		}
		set in_progress_flg {}
		set in_progress_wdg {}

		# Priorities
		interrupt_monitor_intr_prior	[$this simulator_get_intr_flags_with_priorities]
		# Pending interrupts
		interrupt_monitor_intr_flags	[$this simulator_get_active_intr_flags]

		# Enable/Disabled buttons "Invoke this interrupt"
		set state [expr {([$this is_frozen]) ? "normal" : "disabled"}]
		foreach flag $available_interrs {
			$priorities_frame.[string tolower $flag].secondary.exec_but configure -state $state
		}

		# Evaluate list of active interrupts
		set intrs [$this simulator_get_interrupts_in_progress]
		for {set i [expr {[llength $intrs] - 1}]} {$i >= 0} {incr i -1} {
			interrupt_monitor_intr [lindex $intrs $i]
			$priorities_frame.[string tolower [lindex $intrs $i]].secondary.exec_but	\
				configure -state disabled
		}
	}

	## Set status bar tip for certain widget
	 # @parm Widget widget	- Some button or label ...
	 # @parm String text	- Status tip
	 # @return void
	private method set_status_tip {widget text} {
		bind $widget <Enter> "$status_bar configure -text {$text}"
		bind $widget <Leave> "$status_bar configure -text {}"
	}

	## Clear content of frames "Interrupts in progress" and "Pending iterrupts"
	 # @return void
	public method interrupt_monitor_reset {} {
		if {!$dialog_opened} {return}
		foreach wdg [pack slaves $pending_frame] {
			destroy $wdg
		}
		foreach wdg [pack slaves $in_progress_frame] {
			destroy $wdg
		}
		set in_progress_wdg	{}
		set in_progress_flg	{}
		set pending_flg		{}
		set intr_priorities	$available_interrs
		foreach flag $available_interrs {
			set flag [string tolower $flag]
			$priorities_frame.$flag.secondary.exec_but configure -state normal
		}
	}

	## Expand all in scrollable frame specifie by the given number
	 # @parm Int num - 0 == "In progress"; 1 == "Pending"; 2 == "Priorities"
	 # @return void
	public method interrupt_monitor_expand {num} {
		switch -- $num {
			{0} {set frame $in_progress_frame}
			{1} {set frame $pending_frame}
			{2} {set frame $priorities_frame}
		}

		foreach sub_frame [pack slaves $frame] {
			if {![winfo ismapped $sub_frame.tertiary]} {
				pack $sub_frame.tertiary -fill both -padx 2 -pady 2
			}
		}

		update
	}

	## Collapse all in scrollable frame specifie by the given number
	 # @parm Int num - 0 == "In progress"; 1 == "Pending"; 2 == "Priorities"
	 # @return void
	public method interrupt_monitor_collapse {num} {
		switch -- $num {
			{0} {set frame $in_progress_frame}
			{1} {set frame $pending_frame}
			{2} {set frame $priorities_frame}
		}

		foreach sub_frame [pack slaves $frame] {
			if {[winfo ismapped $sub_frame.tertiary]} {
				pack forget $sub_frame.tertiary
			}
		}

		update
	}

	## Collapse / Expand sub window (interrupt details)
	 # @parm Widget widget - Details frame
	 # @return void
	public method interrupt_monitor_collapse_expand {widget} {
		if {[winfo ismapped $widget]} {
			pack forget $widget
		} else {
			pack $widget -fill both -padx 2 -pady 2
		}
		update
	}

	## Set available interrupt flags
	 # @parm List flags - Interrupt flags (e.g. {TF2 CF RI IE0})
	 # @return void
	private method interrupt_monitor_set_available {flags} {
		# Set available interrupts
		set available_interrs $flags

		# Create sub windows in frame "Priorities"
		foreach flag_bit $flags {
			# Get interrupt details
			set intr [get_interrupt_details $flag_bit]

			# Create frame for header and details
			set primary_frame [frame $priorities_frame.[string tolower $flag_bit] -bg $bg_color]

			## Create header
			set secondary_frame [frame $primary_frame.secondary -bg $bg_color]
			 # Priority value
			pack [label $secondary_frame.priority_val	\
				-pady 0 -font $val_font			\
			] -side left -padx 7 -anchor w
			set_status_tip $secondary_frame.priority_val [mc "Priority level"]
			 # Header label
			pack [label $secondary_frame.name	\
				-text [lindex $intr 3] -pady 0	\
				-bg $bg_color -fg white		\
				-cursor hand2 -anchor w		\
			] -side left -anchor w -fill x -expand 1
			bind $secondary_frame.name <Button-1>	\
				"$this interrupt_monitor_collapse_expand $primary_frame.tertiary"
			 # Button "Increase priority level"
			pack [ttk::button $secondary_frame.up_but			\
				-image ::ICONS::16::up					\
				-style InterruptMonitor_Flat.TButton			\
				-command "$this simulator_incr_intr_priority $flag_bit"	\
			] -side right -anchor e
			set_status_tip $secondary_frame.up_but [mc "Increase priority level"]
			# Button "Decrease priority level"
			pack [ttk::button $secondary_frame.down_but			\
				-image ::ICONS::16::down				\
				-style InterruptMonitor_Flat.TButton			\
				-command "$this simulator_decr_intr_priority $flag_bit"	\
			] -side right -anchor e
			set_status_tip $secondary_frame.down_but [mc "Decrease priority level"]
			 # Button "Invoke interrupt"
			pack [ttk::button $secondary_frame.exec_but			\
				-image ::ICONS::16::launch				\
				-style InterruptMonitor_Flat.TButton			\
				-command "$this simulator_invoke_interrupt $flag_bit"	\
			] -side right -anchor e -padx 7
			set_status_tip $secondary_frame.exec_but [mc "Invoke this interrupt"]

			# Create details frame
			set tertiary_frame [frame $primary_frame.tertiary -bg {#FFFFFF}]
			set row 2
			set col 0
			set pri_bits [lindex $intr 2]
			if {[$this get_feature_available iph]} {
				set pri_bits [linsert $pri_bits 0 "[lindex $intr 2]H"]
			}
			foreach lbl {
					{Vector:}		{Enable bit:}
					{Flag bit:}		{Priority bits:}
				}	\
				val [list						\
					[lindex $intr 0]	[lindex $intr 1]	\
					$flag_bit		$pri_bits		\
				]	\
				type {
					vector			e_bit
					f_bit			p_bit
				}	\
			{
				# Label describing type of flags
				grid [label $tertiary_frame.lbl_${row}_${col}	\
					-text [mc $lbl]				\
					-bg white -font $lbl_font -pady 0	\
				] -sticky w -row $row -column $col -pady 0
				incr col

				# Create frame for labels representing bits themselfes
				set bits_frame [frame $tertiary_frame.$type -bg white]
				grid $bits_frame -sticky we -row $row -column $col -pady 0

				# Create bits (or possibly other type of labels)
				switch -- $type {
					vector	{
						set cursor {left_ptr}
						set is_bit 0
					}
					e_bit	-
					p_bit	-
					f_bit	{
						set cursor {hand2}
						set is_bit 1
					}
				}
				set bit_i 0
				foreach bit $val {
					# Create label containing "," (comma)
					if {$bit_i} {
						pack [label $bits_frame.comma_lbl_$bit_i\
							-bg white -font $val_font 	\
							-text {,} -padx 0 -pady 0	\
						] -side left -padx 0 -anchor w -ipadx 0
					}

					# Determinate initial bit color
					if {$is_bit == 0} {
						set color {black}
					} elseif {[intr_mon_getBit $bit]} {
						set color $::Simulator_GUI::on_color
					} else {
						set color $::Simulator_GUI::off_color
					}

					# Create bit label
					set label [label $bits_frame.val_$bit	\
						-bg white -font $val_font  	\
						-cursor $cursor -padx 0 	\
						-fg $color -text $bit -pady 0	\
					]
					pack $label -pady 0 -side left -padx 0 -ipadx 0 -anchor w

					# Set event bindings for bit label
					if {$is_bit} {
						bind $label <Button-1> "$this interrupt_monitor_invert_bit $bit"
						set_status_tip $label [mc [get_bit_stip $bit]]
						bind $label <Enter> {+%W configure -font $::InterruptMonitor::val_font_under}
						bind $label <Leave> {+%W configure -font $::InterruptMonitor::val_font}
					}
					incr bit_i
				}

				incr col 2
				if {$col > 3} {
					set col 0
					incr row
				}
			}

			# Finalize
			grid columnconfigure $tertiary_frame 2 -weight 1
			pack $secondary_frame -fill x
		}
		scrolling_bindings $priorities_frame_f $priorities_frame 1
	}

	## Change interrupt priorities
	 # @parm List flags - List of intr. flags in order of their priorities (decremental)
	 # @return void
	public method interrupt_monitor_intr_prior {flags} {
		if {!$dialog_opened} {return}
		set intr_priorities $flags

		# Forget current subwindows
		foreach wdg [pack slaves $priorities_frame] {
			pack forget $wdg
		}

		# Show subwindows in new order
		foreach flag_bit [string tolower $flags] {
			pack $priorities_frame.$flag_bit -pady 2 -fill x
		}

		# Adjust value of priority level in each subwindow
		foreach flag_bit $available_interrs {
			set pri__clr [get_priority_and_color $flag_bit]
			set pri_bits [lindex [get_interrupt_details $flag_bit] 2]
			set flag_bit [string tolower $flag_bit]
			if {[$this get_feature_available iph]} {
				lappend pri_bits "${pri_bits}H"
			}


			# Frame: "Interrupt priorities"
			$priorities_frame.$flag_bit.secondary.priority_val	\
				configure -text [lindex $pri__clr 0] -bg [lindex $pri__clr 1]
			if {[lindex $pri__clr 0] == $maximum_priority} {
				$priorities_frame.$flag_bit.secondary.up_but	\
					configure -state disabled
			} else {
				$priorities_frame.$flag_bit.secondary.up_but	\
					configure -state normal
			}
			if {[lindex $pri__clr 0]} {
				$priorities_frame.$flag_bit.secondary.down_but	\
					configure -state normal
			} else {
				$priorities_frame.$flag_bit.secondary.down_but	\
					configure -state disabled
			}
			# Pending interrupts
			if {[winfo exists $pending_frame.$flag_bit]} {
				$pending_frame.$flag_bit.tertiary.priority_val		\
					configure -text [lindex $pri__clr 0] -bg [lindex $pri__clr 1]
			}
			# Interrupts in progress
			if {[winfo exists $in_progress_frame.$flag_bit]} {
				$in_progress_frame.$flag_bit.tertiary.priority_val	\
					configure -text [lindex $pri__clr 0] -bg [lindex $pri__clr 1]
			}

			# Adjust colors of priority bits
			foreach pri_bit $pri_bits {
				# Determinate new color
				if {[intr_mon_getBit $pri_bit]} {
					set color $::Simulator_GUI::on_color
				} else {
					set color $::Simulator_GUI::off_color
				}

				# Set new color
				foreach widget [list							\
						$priorities_frame.$flag_bit.tertiary.p_bit.val_$pri_bit	\
						$pending_frame.$flag_bit.tertiary.p_bit.val_$pri_bit	\
						$in_progress_frame.$flag_bit.tertiary.p_bit.val_$pri_bit\
					] {
						if {[winfo exists $widget]} {
							$widget configure -fg $color
						}
				}
			}
		}
	}

	## Set new pending interrupts
	 # @parm List flags - List of intr. flags in decremental order of their priorities
	 # @return void
	public method interrupt_monitor_intr_flags {flags} {
		if {!$dialog_opened} {return}

		# Remove subwindows of interrupts which does not longer
		#+ belong to category pending interrupts
		foreach flag $pending_flg {
			if {[lsearch $flags $flag] == -1 || [lsearch $in_progress_flg $flag] != -1} {
				destroy $pending_frame.[string tolower $flag]
			}
		}

		# Remove flags which are in category "In progress" already
		set new_flag {}
		foreach flag $flags {
			if {[lsearch $in_progress_flg $flag] == -1} {
				lappend new_flag $flag
			}
		}
		set flags $new_flag

		# Sort flags by priority
		set new_flag	{}
		foreach priority_flag $intr_priorities {
			if {[lsearch $flags $priority_flag] != -1} {
				lappend new_flag $priority_flag
			}
		}
		set pending_flg $new_flag

		# Forget or create subwindows for current set of pending interrupts
		foreach flag $new_flag {
			if {[winfo exists $pending_frame.[string tolower $flag]]} {
				pack forget $pending_frame.[string tolower $flag]
			} else {
				create_pending_interrupt $flag
			}
		}

		# Show new subwindows in order of intr. priorities
		foreach flag $new_flag {
			set pri__clr [get_priority_and_color $flag]

			set flag [string tolower $flag]
			$pending_frame.$flag.tertiary.priority_val configure	\
				-text [lindex $pri__clr 0] -bg [lindex $pri__clr 1]
			pack $pending_frame.$flag -pady 2 -fill x
		}

		# Adjust colors of flag bits
		foreach flag_bit $available_interrs {
			# Determinate new color
			if {[intr_mon_getBit $flag_bit]} {
				set color $::Simulator_GUI::on_color
			} else {
				set color $::Simulator_GUI::off_color
			}
			set flag [string tolower $flag_bit]

			# Set new color
			foreach widget [list							\
					$priorities_frame.$flag.tertiary.f_bit.val_$flag_bit	\
					$pending_frame.$flag.tertiary.f_bit.val_$flag_bit	\
					$in_progress_frame.$flag.tertiary.f_bit.val_$flag_bit	\
				] {
					if {[winfo exists $widget]} {
						$widget configure -fg $color
					}
			}
		}
	}

	## Reevaluate state of interrupt enable bits
	 # @return void
	public method interrupt_monitor_intr_ena_dis {} {
		if {!$dialog_opened} {return}

		# Adjust colors of flag bits
		foreach flag_bit $available_interrs {
			set ena_bit [lindex [get_interrupt_details $flag_bit] 1]

			# Determinate new color
			if {[intr_mon_getBit $ena_bit]} {
				set color $::Simulator_GUI::on_color
			} else {
				set color $::Simulator_GUI::off_color
			}

			set flag_bit [string tolower $flag_bit]

			# Set new color
			foreach widget [list							\
					$priorities_frame.$flag_bit.tertiary.e_bit.val_$ena_bit	\
					$pending_frame.$flag_bit.tertiary.e_bit.val_$ena_bit	\
					$in_progress_frame.$flag_bit.tertiary.e_bit.val_$ena_bit\
				] {
					if {[winfo exists $widget]} {
						$widget configure -fg $color
					}
			}
		}
	}

	## Get priority level and color for the given interrupt
	 # @parm String flag - Interrupt flag (e.g. RI)
	 # @return List - {priority color}
	private method get_priority_and_color {flag} {
		set priority [$this simulator_get_interrupt_priority $flag]
		switch -- $priority {
			0 {set bg_clr {#00FF00}}
			1 {set bg_clr {#DDDD00}}
			2 {set bg_clr {#FF8800}}
			3 {set bg_clr {#FF0000}}
		}
		return [list $priority $bg_clr]
	}

	## Add an interrupt to category "Pending interrupts"
	 # @parm String flag - Interrupt flag (e.g. TI)
	 # @return void
	private method create_pending_interrupt {flag_bit} {
		if {!$dialog_opened} {return}
		set intr [get_interrupt_details $flag_bit]

		# Create frame for header and details
		set primary_frame [frame $pending_frame.[string tolower $flag_bit] -bg $bg_color]

		## Create subwindow header
		set secondary_frame [frame $primary_frame.secondary -bg $bg_color]
		 # Label with interrupt name
		pack [label $secondary_frame.name	\
			-text [lindex $intr 3] -pady 0	\
			-bg $bg_color -fg white		\
			-cursor hand2 -anchor w		\
		] -side left -anchor w -fill x -padx 3 -expand 1
		bind $secondary_frame.name <Button-1>	\
			"$this interrupt_monitor_collapse_expand $primary_frame.tertiary"
		 # Close button
		pack [ttk::button $secondary_frame.close_but			\
			-style InterruptMonitor_Flat.TButton			\
			-image ::ICONS::16::button_cancel			\
			-command "$this simulator_clear_intr_flag $flag_bit"	\
		] -side right -anchor e -padx 3
		set_status_tip $secondary_frame.close_but {Clear interrupt flag}

		## Create frame for interrupt details
		set tertiary_frame [frame $primary_frame.tertiary -bg {#FFFFFF}]
		 # Priority:
		grid [label $tertiary_frame.priority_lbl	\
			-pady 0 -text [mc "Priority:"]		\
			-bg white -font $lbl_font		\
		] -sticky w -pady 0 -row 0 -column 0
		set pri__clr [get_priority_and_color $flag_bit]
		grid [label $tertiary_frame.priority_val	\
			-pady 0 -font $val_font			\
			-text [lindex $pri__clr 0]		\
			-bg [lindex $pri__clr 1]		\
		] -sticky w -pady 0 -row 0 -column 1
		set_status_tip $tertiary_frame.priority_val {Priority level}
		 # (Separator)
		grid [ttk::separator $tertiary_frame.sep -orient horizontal]	\
			-sticky we -row 1 -column 0 -columnspan 5 -pady 0
		 # Vector, Enable bit, Flag bit, Priority bits
		set row 2
		set col 0
		set pri_bits [lindex $intr 2]
		if {[$this get_feature_available iph]} {
			set pri_bits [linsert $pri_bits 0 "[lindex $intr 2]H"]
		}
		foreach lbl {
				{Vector:}		{Enable bit:}
				{Flag bit:}		{Priority bits:}
			}	\
			val [list						\
				[lindex $intr 0]	[lindex $intr 1]	\
				$flag_bit		$pri_bits		\
			]	\
			type {
				vector			e_bit
				f_bit			p_bit
			}	\
		{
			# Label describing type of flags
			grid [label $tertiary_frame.lbl_${row}_${col}	\
				-text [mc $lbl]				\
				-bg white -font $lbl_font -pady 0	\
			] -sticky w -row $row -column $col -pady 0
			incr col

			# Create frame for labels representing bits themselfes
			set bits_frame [frame $tertiary_frame.$type -bg white]
			grid $bits_frame -sticky w -row $row -column $col -pady 0

			# Create bits (or possibly other type of labels)
			switch -- $type {
				vector	{
					set cursor {left_ptr}
					set is_bit 0
				}
				e_bit	-
				p_bit	-
				f_bit	{
					set cursor {hand2}
					set is_bit 1
				}
			}
			set bit_i 0
			foreach bit $val {
				# Create label containing "," (comma)
				if {$bit_i} {
					pack [label $bits_frame.comma_lbl_$bit_i\
						-bg white -font $val_font 	\
						-text {,} -padx 0 -pady 0	\
					] -side left -padx 0 -anchor w -ipadx 0
				}

				# Determinate initial bit color
				if {$is_bit == 0} {
					set color {black}
				} elseif {[intr_mon_getBit $bit]} {
					set color $::Simulator_GUI::on_color
				} else {
					set color $::Simulator_GUI::off_color
				}

				# Create bit label
				set label [label $bits_frame.val_$bit		\
					-bg white -font $val_font -pady 0 	\
					-cursor $cursor -padx 0 -text $bit	\
					-fg $color				\
				]
				pack $label -pady 0 -side left -padx 0 -ipadx 0 -anchor w

				# Set event bindings for bit label
				if {$is_bit} {
					bind $label <Button-1> "$this interrupt_monitor_invert_bit $bit"
					set_status_tip $label [mc [get_bit_stip $bit]]
					bind $label <Enter> {+%W configure -font $::InterruptMonitor::val_font_under}
					bind $label <Leave> {+%W configure -font $::InterruptMonitor::val_font}
				}
				incr bit_i
			}

			incr col 2
			if {$col > 3} {
				set col 0
				incr row
			}
		}

		grid columnconfigure $tertiary_frame 2 -weight 1
		pack $secondary_frame -fill x
		scrolling_bindings $pending_frame_f $primary_frame 1
	}

	## Add an interrupt to category "Interrupts in progress"
	 # @parm String flag - Interrupt flag (e.g. TF0)
	 # @return void
	public method interrupt_monitor_intr {flag_bit} {
		if {!$dialog_opened} {return}

		# Local variables
		set intr [get_interrupt_details $flag_bit]
		set from_pc [format %X [$this getPC]]
		set len [string length $from_pc]
		if {$len < 4} {
			set from_pc "[string repeat {0} [expr {4 - $len}]]$from_pc"
		}
		set from_pc	"0x$from_pc"
		set frame_desc [string tolower $flag_bit]

		# Insure than the same subwindow does not exist already
		if {[winfo exists $pending_frame.$frame_desc]} {
			destroy $pending_frame.$frame_desc
		}

		# Disable button "Invoke this interrupt" in priorities frame
		$priorities_frame.$frame_desc.secondary.exec_but configure -state disabled

		# Create frame for header and details
		set primary_frame [frame $in_progress_frame.$frame_desc -bg $bg_color]

		## Create subwindow header
		set secondary_frame [frame $primary_frame.secondary -bg $bg_color]
		 # Label with interrupt name
		pack [label $secondary_frame.name	\
			-text [lindex $intr 3] -pady 0	\
			-bg $bg_color -fg white		\
			-cursor hand2 -anchor w		\
		] -side left -anchor w -fill x -padx 3 -expand 1
		bind $secondary_frame.name <Button-1>	\
			"$this interrupt_monitor_collapse_expand $primary_frame.tertiary"
		 # Close button
		pack [ttk::button $secondary_frame.close_but			\
			-style InterruptMonitor_Flat.TButton			\
			-image ::ICONS::16::button_cancel			\
			-command "$this simulator_cancel_interrupt $flag_bit"	\
		] -side right -anchor e -padx 3
		set_status_tip $secondary_frame.close_but {Force return from this interrupt (may damage program integrity)}

		## Create frame for interrupt details
		set tertiary_frame [frame $primary_frame.tertiary -bg {#FFFFFF}]
		 # Priority
		grid [label $tertiary_frame.priority_lbl	\
			-pady 0 -text [mc "Priority:"]		\
			-bg white -font $lbl_font		\
		] -sticky w -pady 0 -row 0 -column 0
		set pri__clr [get_priority_and_color $flag_bit]
		grid [label $tertiary_frame.priority_val	\
			-pady 0 -font $val_font			\
			-text [lindex $pri__clr 0]		\
			-bg [lindex $pri__clr 1]		\
		] -sticky w -pady 0 -row 0 -column 1
		set_status_tip $tertiary_frame.priority_val {Priority level}
		 # (Separator)
		grid [ttk::separator $tertiary_frame.sep -orient horizontal]	\
			-sticky we -row 1 -column 0 -columnspan 5 -pady 0

		 # Vector, Flag bit, Enable bit, Priority bits
		set row 2
		set pri_bits [lindex $intr 2]
		if {[$this get_feature_available iph]} {
			set pri_bits [linsert $pri_bits 0 "[lindex $intr 2]H"]
		}
		foreach lbl {
				{Vector:}		{Flag bit:}
				{Enable bit:}		{Priority bits:}
			}	\
			val [list					\
				[lindex $intr 0]	$flag_bit	\
				[lindex $intr 1]	$pri_bits	\
			]	\
			type {
				vector			f_bit
				e_bit			p_bit
			}	\
		{
			# Label describing type of flags
			grid [label $tertiary_frame.lbl_$row		\
				-text [mc $lbl]				\
				-bg white -font $lbl_font -pady 0	\
			] -sticky w -row $row -column 0 -pady 0

			# Create frame for labels representing bits themselfes
			set bits_frame [frame $tertiary_frame.$type -bg white]
			grid $bits_frame -sticky w -row $row -column 1 -pady 0

			# Create bits (or possibly other type of labels)
			switch -- $type {
				vector	{
					set cursor {left_ptr}
					set is_bit 0
				}
				e_bit	-
				p_bit	-
				f_bit	{
					set cursor {hand2}
					set is_bit 1
				}
			}
			set bit_i 0
			foreach bit $val {
				# Create label containing "," (comma)
				if {$bit_i} {
					pack [label $bits_frame.comma_lbl_$bit_i\
						-bg white -font $val_font 	\
						-text {,} -padx 0 -pady 0	\
					] -side left -padx 0 -anchor w -ipadx 0
				}

				# Determinate initial bit color
				if {!$is_bit} {
					set color {black}
				} elseif {[intr_mon_getBit $bit]} {
					set color $::Simulator_GUI::on_color
				} else {
					set color $::Simulator_GUI::off_color
				}

				# Create bit label
				set label [label $bits_frame.val_$bit		\
					-bg white -font $val_font -pady 0 	\
					-cursor $cursor -padx 0 -text $bit	\
					-fg $color				\
				]
				pack $label -pady 0 -side left -padx 0 -ipadx 0 -anchor w

				# Set event bindings for bit label
				if {$is_bit} {
					bind $label <Button-1> "$this interrupt_monitor_invert_bit $bit"
					set_status_tip $label [mc [get_bit_stip $bit]]
					bind $label <Enter> {+%W configure -font $::InterruptMonitor::val_font_under}
					bind $label <Leave> {+%W configure -font $::InterruptMonitor::val_font}
				}
				incr bit_i
			}
			incr row
		}
		 # Invoked from:
		set row 2
		grid [label $tertiary_frame.lbl__$row	\
			-text [mc "Invoked from:"] -pady 0	\
			-bg white -font $lbl_font	\
		] -sticky w -row $row -column 3 -pady 0 -columnspan 2
		incr row
		 # PC:
		grid [label $tertiary_frame.lbl__$row	\
			-pady 0 -text [mc "    PC:"]	\
			-bg white -font $lbl_font 	\
		] -sticky w -row $row -column 3 -pady 0
		grid [label $tertiary_frame.val__$row	\
			-pady 0 -text $from_pc		\
			-bg white -font $val_font	\
		] -sticky w -row $row -column 4 -pady 0
		incr row
		 # File:
		grid [label $tertiary_frame.lbl__$row	\
			-pady 0 -text [mc "    File:"]	\
			-bg white -font $lbl_font 	\
		] -sticky w -row $row -column 3 -pady 0
		set filename [$this filelist_get_simulator_editor_obj]
		if {$filename != {}} {
			set filename [$filename cget -fullFileName]
		} else {
			set filename [lindex [$this simulator_get_list_of_filenames] 0]
		}
		grid [label $tertiary_frame.val__$row		\
			-pady 0 -bg white -font $val_font	\
			-text [file tail $filename]		\
		] -sticky w -row $row -column 4 -pady 0
		incr row
		 # Line:
		grid [label $tertiary_frame.lbl__$row	\
			-pady 0 -text [mc "    Line:"]	\
			-bg white -font $lbl_font 	\
		] -sticky w -row $row -column 3 -pady 0
		grid [label $tertiary_frame.val__$row		\
			-pady 0 -bg white -font $val_font	\
			-text [$this simulator_get_line_number]	\
		] -sticky w -row $row -column 4 -pady 0

		grid columnconfigure $tertiary_frame 4 -weight 1
		pack $secondary_frame -fill x

		# Pack the created subwindow just after the topmost subwindow in the scrollable frame
		set wdg [lindex $in_progress_wdg end]
		if {$wdg != {}} {
			pack $primary_frame -fill x -before $wdg -pady 2
		} else {
			pack $primary_frame -fill x -pady 2
		}

		# Register this subwindow for future use
		lappend in_progress_flg $flag_bit
		lappend in_progress_wdg $primary_frame

		scrolling_bindings $in_progress_frame_f $primary_frame 1
	}

	## Remove interrupt from category "In progress"
	 # @parm String flag_bit - Interrupt flag (e.g. TF0)
	 # @return void
	public method interrupt_monitor_reti {flag_bit} {
		if {!$dialog_opened} {return}
		set idx [lsearch $in_progress_flg $flag_bit]
		if {$idx == -1} {
			return
		}
		destroy [lindex $in_progress_wdg $idx]
		$priorities_frame.[string tolower $flag_bit].secondary.exec_but configure -state normal

		set in_progress_flg [lreplace $in_progress_flg $idx $idx]
		set in_progress_wdg [lreplace $in_progress_wdg $idx $idx]
	}

	## Get details for the given interrupt
	 # @parm String flag_bit - Interrupt flag (e.g. EXF2)
	 # @return List - {vector_hex enable_bit priority_bit short_description}
	private method get_interrupt_details {flag_bit} {
		switch -- $flag_bit {
			{IE0}	{return {{0x03}	{EX0}	{PX0}	{External Interrupt 0}}}
			{TF0}	{return {{0x0B}	{ET0}	{PT0}	{Timer 0 Overflow}}}
			{IE1}	{return {{0x13}	{EX1}	{PX1}	{External Interrupt 1}}}
			{TF1}	{return {{0x1B}	{ET1}	{PT1}	{Timer 1 Overflow}}}
			{RI}	{return {{0x23}	{ES}	{PS}	{UART receive}}}
			{TI}	{return {{0x23}	{ES}	{PS}	{UART transmit}}}
			{SPIF}	{return {{0x23}	{ES}	{PS}	{SPI}}}
			{TF2}	{return {{0x2B}	{ET2}	{PT2}	{Timer 2 Overflow}}}
			{EXF2}	{return {{0x2B}	{ET2}	{PT2}	{Timer 2 External}}}
			{CF}	{return {{0x33}	{EC}	{PC}	{Analog comparator}}}
		}
	}

	## Get status tip for particular bit
	 # @param String bit_name - Name of bit
	 # @return String - Status tip
	private method get_bit_stip {bit_name} {
		switch -- $bit_name {
			IE0	{return {Bit address: 0x89  --  External Interrupt 0 edge flag}}
			TF0	{return {Bit address: 0x8D  --  Timer 0 overflow flag}}
			IE1	{return {Bit address: 0x8B  --  External Interrupt 1 edge flag}}
			TF1	{return {Bit address: 0x8F  --  Timer 1 overflow flag}}
			RI	{return {Bit address: 0x98  --  Receive interrupt flag}}
			TI	{return {Bit address: 0x99  --  Transmit interrupt flag}}
			SPIF	{return {SPSR.7             --  SPI interrupt flag}}
			TF2	{return {Bit address: 0xCF  --  Timer 2 overflow flag}}
			EXF2	{return {Bit address: 0xCE  --  Timer 2 external flag}}
			CF	{return {ACSR.4             --  Comparator Interrupt}}

			EX0	{return {Bit address: 0xA8  --  Enable or disable External Interrupt 0}}
			ET0	{return {Bit address: 0xA9  --  Enable or disable the Timer 0 overflow interrupt}}
			EX1	{return {Bit address: 0xAA  --  Enable or disable External Interrupt 1}}
			ET1	{return {Bit address: 0xAB  --  Enable or disable the Timer 1 overflow interrupt}}
			ES	{return {Bit address: 0xAC  --  Enable or disable the serial port interrupt}}
			ET2	{return {Bit address: 0xAD  --  Enable or disable the Timer 2 overflow interrupt}}
			EC	{return {Bit address: 0xAE  --  Enable or disable the comparator interrupt}}

			PX0	{return {Bit address: 0xB8  --  Defines the External Interrupt 0 priority level}}
			PT0	{return {Bit address: 0xB9  --  Defines the Timer 0 interrupt priority level}}
			PX1	{return {Bit address: 0xBA  --  Defines External Interrupt 1 priority level}}
			PT1	{return {Bit address: 0xBB  --  Defines the Timer 1 interrupt priority level}}
			PS	{return {Bit address: 0xBC  --  Defines the Serial Port interrupt priority level}}
			PT2	{return {Bit address: 0xBD  --  Defines the Timer 2 interrupt priority level}}
			PC	{return {Bit address: 0xBE  --  Defines the comparator interrupt priority level}}

			PX0H	{return {IPH.0              --  Defines the External Interrupt 0 priority level}}
			PT0H	{return {IPH.1              --  Defines the Timer 0 interrupt priority level}}
			PX1H	{return {IPH.2              --  Defines External Interrupt 1 priority level}}
			PT1H	{return {IPH.3              --  Defines the Timer 1 interrupt priority level}}
			PSH	{return {IPH.4              --  Defines the Serial Port interrupt priority level}}
			PT2H	{return {IPH.5              --  Defines the Timer 2 interrupt priority level}}
			PCH	{return {IPH.6              --  Defines the comparator interrupt priority level}}
			default	{return {}}
		}
	}

	## Disable buttons on this panel which can manipulate with simulator
	 # @return void
	public method interrupt_monitor_enable_buttons {} {
		if {!$dialog_opened} {return}
		foreach widget [pack slaves $priorities_frame] {
			$widget.secondary.exec_but configure -state normal
		}
	}

	## Disable all buttons on this panel which can manipulate with simulator
	 # @return void
	public method interrupt_monitor_disable_buttons {} {
		if {!$dialog_opened} {return}
		foreach frame [list $in_progress_frame $pending_frame] {
			foreach widget [pack slaves $frame] {
				$widget.secondary.close_but configure -state disabled
			}
		}
		foreach widget [pack slaves $priorities_frame] {
			$widget.secondary.down_but configure -state disabled
			$widget.secondary.up_but configure -state disabled
			$widget.secondary.exec_but configure -state disabled
		}
	}

	## Create event bindings to provide scrolling ability for all childern widgets
	 # @parm Widget scrollable_frame	- Parent frame (scrollable frame)
	 # @parm Widget this_frame		- This frame
	 # @parm Bool also_this			- This should be always 1
	 # @return void
	private method scrolling_bindings {scrollable_frame this_frame also_this} {
		if {$also_this} {
			bind $this_frame <Button-5> "$scrollable_frame yview scroll +1 units"
			bind $this_frame <Button-4> "$scrollable_frame yview scroll -1 units"
		}
		foreach w [winfo children $this_frame] {
			bind $w <Button-5> "$scrollable_frame yview scroll +1 units"
			bind $w <Button-4> "$scrollable_frame yview scroll -1 units"
			scrolling_bindings $scrollable_frame $w 0
		}
	}

	## Invert particular bit in simulator
	 # @parm String bit_name - Name of bit to invert (uppercase)
	 # @return void
	public method interrupt_monitor_invert_bit {bit_name} {
		if {![$this is_frozen]} {
			return
		}

		$this intr_mon_setBit $bit_name [expr {![intr_mon_getBit $bit_name]}]
	}

	## Set value for particular bit
	 # @parm String bit_name	- Name of bit to set (uppercase)
	 # @parm Bool value		- New bit value
	 # @return void
	private method intr_mon_setBit {bit_name value} {
		switch -- $bit_name {
			SPIF	{
				set reg		{SPSR}
				set bit_num	7
			}
			CF	{
				set reg		{ACSR}
				set bit_num	4
			}
			PX0H	{
				set reg		{IPH}
				set bit_num	0
			}
			PT0H	{
				set reg		{IPH}
				set bit_num	1
			}
			PX1H	{
				set reg		{IPH}
				set bit_num	2
			}
			PT1H	{
				set reg		{IPH}
				set bit_num	3
			}
			PSH	{
				set reg		{IPH}
				set bit_num	4
			}
			PT2H	{
				set reg		{IPH}
				set bit_num	5
			}
			PCH	{
				set reg		{IPH}
				set bit_num	6
			}
			default {
				$this setBit $::Simulator_ENGINE::symbol($bit_name) $value
				return
			}
		}

		# Determinate register address, register value and bit mask for bit to set
		set reg $::Simulator_ENGINE::symbol($reg)
		set reg_val [$this getSfrDEC $reg]
		set bit_num [expr {1 << $bit_num}]

		# Set bit
		if {(($reg_val & $bit_num) ? 1 : 0) != ($value ? 1 : 0)} {
			set reg_val [expr {$reg_val ^ $bit_num}]
			$this setSfr $reg [format %X $reg_val]
			$this Simulator_sync_sfr $reg
		}
	}

	## Get value of particular bit in simulator
	 # @parm String bit_name - Name of bit (uppercase)
	 # @return Bool - bit value
	private method intr_mon_getBit {bit_name} {
		switch -- $bit_name {
			SPIF	{return [$this getBitByReg $::Simulator_ENGINE::symbol(SPSR)	7]}
			CF	{return [$this getBitByReg $::Simulator_ENGINE::symbol(ACSR)	4]}
			PX0H	{return [$this getBitByReg $::Simulator_ENGINE::symbol(IPH)	0]}
			PT0H	{return [$this getBitByReg $::Simulator_ENGINE::symbol(IPH)	1]}
			PX1H	{return [$this getBitByReg $::Simulator_ENGINE::symbol(IPH)	2]}
			PT1H	{return [$this getBitByReg $::Simulator_ENGINE::symbol(IPH)	3]}
			PSH	{return [$this getBitByReg $::Simulator_ENGINE::symbol(IPH)	4]}
			PT2H	{return [$this getBitByReg $::Simulator_ENGINE::symbol(IPH)	5]}
			PCH	{return [$this getBitByReg $::Simulator_ENGINE::symbol(IPH)	6]}
			default {return [$this getBit $::Simulator_ENGINE::symbol($bit_name)]	}
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

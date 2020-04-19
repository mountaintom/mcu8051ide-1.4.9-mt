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
if { ! [ info exists _GRAPH_WDG_TCL ] } {
set _GRAPH_WDG_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Graph widget for showing port states
# --------------------------------------------------------------------------

class GraphWidget {
	## COMMON
	public common step_y		13	;# Int: Vertical distance between graph rows
	public common half_edge	5	;# Int: Half length of bit edge
	public common full_edge	10	;# Int: Full length of bit edge

	# Big font (vertical header)
	public common big_font		[font create	\
		-family $::DEFAULT_FIXED_FONT	\
		-size -14			\
		-weight bold			\
	]
	# Small font (horizontal header)
	public common small_font	[font create	\
		-family $::DEFAULT_FIXED_FONT	\
		-size -14			\
		-weight bold			\
	]
	# Font for booleans values for each port
	public common bool_font	[font create	\
		-family $::DEFAULT_FIXED_FONT	\
		-size -12			\
		-weight bold			\
	]
	# Definition of graph popup menu
	public common GRAPHMENU {
		{command	{ON/OFF}	{}	0	"graph_change_status_on"
			{}		"Enable/Disable graph"}
		{separator}
		{command	{Change grid}	{}	1	"graph_switch_grid_mode 1"
			{}	"Change grid morphology"}
		{separator}
		{command	{Zoom in}	{}	1	"graph_zoom_in"
			{viewmag_in}	"Change bit length on X axis to a lower value"}
		{command	{Zoom out}	{}	1	"graph_zoom_out"
			{viewmag_out}	"Change bit length on X axis to a higher value"}
		{separator}
		{command	{Remove marks}	{}	1	"graph_clear_marks"
			{editdelete}	"Clear user marks"}
	}

	# Variables related to object initialization
	private variable graph_w_gui_initialized 0	;# Bool: GUI created
	private variable _parent			;# Parent widget
	private variable parent				;# Innert parent widget

	private variable canvasWidget			;# ID of the canvas widget
	private variable grid_mode		{b}	;# Current grid mode (one of {b n x y})
	private variable drawing_on		0	;# Bool: Graph enabled
	private variable magnification		0	;# Magnification level (0..3)
	private variable graph_elements			;# Array: IDs of graph elements (green and red lines)
	private variable intr_lines		{}	;# List of IDs of interrupt lines
	private variable marks			{}	;# List of IDs mark rectangulars
	private variable mark_flags		{}	;# List of Boolean mark flags
	private variable state_history		{}	;# History of X bits (for changing magnification level and stepback)
	private variable intr_history		{}	;# History of X interrupt flags
	private variable previous_state			;# Array: previous state of each bit
	private variable menu			{}	;# ID of canvas popup menu
	private variable step_x				;# Number of pixels required for draw one bit
	private variable scrollable_frame		;# Widget: Scrollable area (parent for all other widgets)
	private variable horizontal_scrollbar		;# Widget: Horizontal scrollbar for scrollable area
	private variable number_of_ports		;# Int: Number of MCU's ports (see engine proc. get_ports_info)
	private variable port_numbers			;# List: Numbers of implemented ports (e.g. {0 3})
	private variable port_length_in_px		;# Length of one port segment in PX
	private variable port_graph_length		;# Same as port_length_in_px but only visible area
	private variable history_max_length		;# Maximum history depth

	private variable Super				;# Object: Super


	## Prepare object for creating its GUI
	 # @parm Widget Parent	- GUI parent widget
	 # @parm List _data_list	- Configuration data list
	 # @return void
	constructor {Parent super} {
		set _parent $Parent
		set Super $super
		set graph_w_gui_initialized 0
	}

	## Object destructor
	destructor {
		if {$graph_w_gui_initialized} {
			menu_Sbar_remove $menu
		}
	}

	## React to MCU change
	 # @return void
	public method change_mcu {} {
		if {!$graph_w_gui_initialized} {return}

		foreach wdg [winfo children $_parent] {
			destroy $wdg
		}
		set graph_w_gui_initialized 0
		CreateGraphGUI
	}

	## Initialize graph
	 # @return void
	public method CreateGraphGUI {} {
		if {$graph_w_gui_initialized} {return}
		set graph_w_gui_initialized 1

		# Determinate number of ports and port indexes
		set number_of_ports	[$Super get_ports_info]
		set port_numbers	[lindex $number_of_ports 1]
		set number_of_ports	[lindex $number_of_ports 0]

		set port_length_in_px	[expr {840 / $number_of_ports}]
		set port_graph_length	[expr {$port_length_in_px - 15}]
		set history_max_length	[expr {$port_graph_length / 5}]

		# Create scrollable area
		set scrollable_frame [ScrollableFrame $_parent.scrollable_frame	\
			-xscrollcommand "$this graph_gui_scroll_set"		\
		]
		set horizontal_scrollbar [ttk::scrollbar $_parent.horizontal_scrollbar	\
			-orient horizontal -command "$scrollable_frame xview"		\
		]
		pack $scrollable_frame -fill both -side bottom -expand 1
		set parent [$scrollable_frame getframe]

		# Create canvas widget
		set canvasWidget [canvas $parent.canvas	\
			-height 120 -width 860 -bd 0	\
			-highlightthickness 0		\
		]

		# Create graph headers
		for {set i 0; set y 17} {$i < 8} {incr i; incr y $step_y} {
			$canvasWidget create text 10 $y -text $i -font $small_font -anchor n -fill {#0000FF} -tags background
		}
		for {set i 0} {$i < $number_of_ports} {incr i} {
			set x [expr {$i * $port_length_in_px + $port_length_in_px / 2 + 20}]
			$canvasWidget create text $x 7	\
				-text "P[lindex $port_numbers $i]"	\
				-font $big_font -fill {#0000FF} -tags background
		}
		# Create separators
		$canvasWidget create line 20 0 20 120 -fill {#000000} -tags background
		$canvasWidget create line 0 15 860 15 -fill {#000000} -tags background
		for {set i 1} {$i <= $number_of_ports} {incr i} {
			set x [expr {$i * $port_length_in_px + 20}]
			$canvasWidget create line $x 0 $x 120 -fill {#000000} -tags background
			incr x -$step_y
			$canvasWidget create line $x 0 $x 120 -fill {#888888} -tags background
		}

		# Initialize array of graph elements and previous states
		for {set i 0} {$i < 40} {incr i} {
			set graph_elements($i) {}
			set previous_state($i) 1
		}

		# Create canvas popup menu
		set menu $canvasWidget.menu
		menuFactory $GRAPHMENU $menu 0 "$Super " 0 {} [namespace current]


		# Set event bindings for the canvas widget
		bind $canvasWidget <Motion>		"$this graph_highlight %x %y"
		bind $canvasWidget <Leave>		"$this graph_unhighlight"
		bind $canvasWidget <ButtonRelease-3>	"$this graph_popup_menu %X %Y"
		bind $canvasWidget <Button-1>		"$this graph_place_mark %x %y"

		# Pack the canvas widget
		set marks [string repeat {{} } [expr {$history_max_length + 1}]]
		pack $canvasWidget -fill none -expand 0 -anchor nw -side left

		# Commit magnification level
		commit_magnification $magnification

		# Commit ON/OFF state
		commit_state_on_off $drawing_on

		# Create graph grid
		graph_switch_grid_mode $grid_mode
	}

	## Draw interrupt line
	 # @parm String nh={} - If "nohistory" the history of interrupt lines will not be modified
	 # @return void
	public method graph_draw_interrupt_line {{nh {}}} {
		if {!$graph_w_gui_initialized} {CreateGraphGUI}

		# Check if graph is enabled
		if {!$drawing_on} {return}

		# Adjust history
		if {$nh != {nohistory}} {
			if {[llength $intr_history]} {
				lset intr_history end 1
			} else {
				lappend intr_history 1
			}
		}

		# Create interrupt lines
		set lines {}
		for {set col 0} {$col < $number_of_ports} {incr col} {
			set x [expr {$col * $port_length_in_px + ([llength $graph_elements(0)] * $step_x) + 20}]
			lappend lines [$canvasWidget create line $x 16 $x 120	\
				-fill {#DDAA00} -tags graph -width 2 -dash ,]
		}

		# Adjust list of canvas elements related to this line
		if {$nh != {nohistory}} {
			if {[llength $intr_lines]} {
				lset intr_lines end $lines
			} else {
				lappend intr_lines $lines
			}
		}
	}

	## Draw new port states in the graph
	 # A) With history enabled:
	 #	@parm String - Hexadecimal value of P0
	 #	@parm String - Hexadecimal value of P1
	 #	@parm String - Hexadecimal value of P2
	 #	@parm String - Hexadecimal value of P3
	 #	@parm String - Hexadecimal value of P4
	 # B) With disabled:
	 #	@parm List - {# {P0_hex P1_hex P2_hex P3_hex P4_hex}}
	 # @return void
	public method graph_new_output_state args {
		if {!$graph_w_gui_initialized} {CreateGraphGUI}

		# Check if graph is enabled
		if {!$drawing_on} {return}

		# Determinate number of bits per block and the current position
		set treshold [expr {$port_graph_length / $step_x}]
		set position [llength $graph_elements(0)]

		# If graph is full -> remove last elements and move the graph
		if {$position == $treshold} {
			# Remove elemets
			for {set i 0} {$i < ($number_of_ports * 8)} {incr i} {
				foreach elm [lindex $graph_elements($i) 0] {
					$canvasWidget delete $elm
				}
				set graph_elements($i) [lreplace $graph_elements($i) 0 0]
			}
			foreach elm [lindex $intr_lines 0] {
				$canvasWidget delete $elm
			}
			set intr_lines [lreplace $intr_lines 0 0]
			# Adjust position index
			incr position -1
			# Move graph
			$canvasWidget move graph -$step_x 0
		}

		# Adjust history (cannot be longer than 38)
		if {[llength $intr_history] > $history_max_length} {
			set intr_history [lreplace $intr_history 0 0]
			set state_history [lreplace $state_history 0 0]
		}

		# Adjust history
		set args [join $args {}]
		if {[lindex $args 0] != {#}} {
			lappend state_history [list {#} $args]
			lappend intr_history 0
		} else {
			set args [lindex $args 1]
		}
		lappend intr_lines {}

		# Adjust arguments
		set ports {}
		foreach idx $port_numbers {
			lappend ports [lindex $args $idx]
		}

		# Create new elements
		set p_idx	0		;# Port index (not port number)
		set idx		0		;# Bit index
		$canvasWidget delete booleans	;# Clear boolean values
		foreach num_x $ports {
			set num [list 0 0 0 0 0 0 0 0]
			for {set i 0; set j 7} {$i < 8} {incr i; incr j -1} {
				lset num $j [lindex $num_x $i]
			}

			# Draw bits
			foreach bit $num {
				draw_bit $idx $position $bit
				incr idx
			}
			# Draw booleans
			write_boolean $p_idx $num
			incr p_idx
		}
	}

	## Write boolean values for the given port
	 # @parm Int port_idx	- Port number
	 # @parm Int val	- Port value
	 # @return void
	private method write_boolean {port_idx val} {
		set x [expr {($port_idx + 1) * $port_length_in_px + 13}]

		for {set i 0; set y 17} {$i < 8} {incr i; incr y $step_y} {
			switch -- [lindex $val $i] {
				{1} {
					set txt {H}
					set clr {#FF0000}
				}
				{0} {
					set txt {L}
					set clr {#00FF00}
				}
				{|} {
					set txt {-}
					set clr {#FF8800}
				}
				{?} {
					set txt {-}
					set clr {#888888}
				}
				{X} {
					set txt {-}
					set clr {#8800FF}
				}
				{-} {
					set txt {?}
					set clr {#AAAA00}
				}
				{=} {
					set txt {L}
					set clr {#FF00AA}
				}
				default {
					set txt {?}
					set clr {#888888}
				}
			}

			$canvasWidget create text $x $y	\
				-text $txt		\
				-font $bool_font	\
				-anchor n		\
				-fill $clr		\
				-tags booleans
		}
	}

	## Draw one bit to the graph
	 # @parm Int idx	- Bit index (0..39)
	 # @parm Int pos	- Target position
	 # @parm Char bool	- Bit value
	 # @return void
	private method draw_bit {idx pos bool} {
		# Local variables
		set prev $previous_state($idx)			;# Previous state of the bit
		set offset_y [expr {($idx % 8) * $step_y + 18}]	;# Y offset
		set lines {}					;# List of line IDs
		# X offset
		set offset_x [expr {
			($idx / 8) * $port_length_in_px + ($pos * $step_x) + 20
		}]

		# Determinate length of line elements according to the current magnification level
		switch -- $magnification {
			{0} {
				set line_len 3
				set enge_diff 0
				set enge_inc0 0
				set enge_inc1 0
			}
			{1} {
				set line_len 4
				set enge_diff 1
				set enge_inc0 1
				set enge_inc1 1
			}
			{2} {
				set line_len 6
				set enge_diff 1
				set enge_inc0 2
				set enge_inc1 1
			}
			{3} {
				set line_len 8
				set enge_diff 2
				set enge_inc0 2
				set enge_inc1 2
			}
		}

		# Logical one forced to zero (e.g. by NPN transistor)
		if {$bool == {=}} {
			set bool 0
			set zero_color {#FF00AA}
		} else {
			set zero_color {#FF0000}
		}

		## Draw graph line(s)

		# High frequency pulse
		if {$bool == {|}} {
			# Draw transition from the previous value
			switch -- $prev {
				{0} {	;# From logical 0
					lappend lines [$canvasWidget create line		\
						$offset_x [expr {$offset_y + $full_edge}]	\
						$offset_x [expr {$offset_y + $half_edge}]	\
						-fill {#00FF00} -tags graph]
					lappend lines [$canvasWidget create line		\
						$offset_x [expr {$offset_y + $half_edge}]	\
						$offset_x [expr {$offset_y + 0}]		\
						-fill $zero_color -tags graph]
				}
				{1} {	;# From logical 1
				}
				{?} {	;# From no voltage
					lappend lines [$canvasWidget create line		\
						$offset_x [expr {$offset_y + $half_edge}]	\
						$offset_x [expr {$offset_y + 0}]		\
						-fill $zero_color -tags graph]
				}
				{-} {	;# From indeterminable state
					lappend lines [$canvasWidget create line		\
						$offset_x [expr {$offset_y + $half_edge}]	\
						$offset_x [expr {$offset_y + 0}]		\
						-fill $zero_color -tags graph]
				}
			}

			if {$magnification == 0} {
				lappend lines [$canvasWidget create line			\
					$offset_x $offset_y					\
					[expr {$offset_x + 1}] $offset_y			\
					[expr {$offset_x + 1}] [expr {$offset_y + $half_edge}]	\
					-fill $zero_color -tags graph]

				lappend lines [$canvasWidget create line			\
					[expr {$offset_x + 1}] [expr {$offset_y + $half_edge}]	\
					[expr {$offset_x + 1}] [expr {$offset_y + $full_edge}]	\
					[expr {$offset_x + 3}] [expr {$offset_y + $full_edge}]	\
					[expr {$offset_x + 3}] [expr {$offset_y + $half_edge}]	\
					-fill {#00FF00} -tags graph]

				lappend lines [$canvasWidget create line			\
					[expr {$offset_x + 4}] [expr {$offset_y + $half_edge}]	\
					[expr {$offset_x + 4}] [expr {$offset_y}]		\
					-fill $zero_color -tags graph]
			} else {
					switch -- $magnification {
						{1} {
							set line_len 3
							set enge_diff 0
							set enge_inc0 0
							set enge_inc1 0
						}
						{2} {
							set line_len 4
							set enge_diff 1
							set enge_inc0 1
							set enge_inc1 1
						}
						{3} {
							set line_len $half_edge
							set enge_diff 1
							set enge_inc0 2
							set enge_inc1 1
						}
					}

					lappend lines [$canvasWidget create line	\
						$offset_x $offset_y			\
						[expr {$offset_x + $line_len}] $offset_y\
						-fill $zero_color -tags graph]
					incr offset_x $line_len
					lappend lines [$canvasWidget create line\
						$offset_x $offset_y		\
						[expr {$offset_x + $enge_diff}]	\
						[expr {$offset_y + $half_edge}]	\
						-fill $zero_color -tags graph	\
					]
					incr offset_x $enge_inc0
					incr offset_y $half_edge
					lappend lines [$canvasWidget create line\
						$offset_x $offset_y		\
						[expr {$offset_x + $enge_diff}]	\
						[expr {$offset_y + 5}]		\
						-fill {#00FF00} -tags graph	\
					]
					incr offset_x $enge_inc1
					incr offset_y $half_edge
					lappend lines [$canvasWidget create line		\
						$offset_x $offset_y				\
						[expr {$offset_x + $line_len + 1}] $offset_y	\
						-fill {#00FF00} -tags graph]

					incr offset_x $line_len
					incr offset_x
					lappend lines [$canvasWidget create line\
						$offset_x $offset_y		\
						[expr {$offset_x + $enge_diff}]	\
						[expr {$offset_y - $half_edge}]	\
						-fill {#00FF00} -tags graph]
					incr offset_x $enge_inc0
					incr offset_y -$half_edge
					lappend lines [$canvasWidget create line\
						$offset_x $offset_y		\
						[expr {$offset_x + $enge_diff}]	\
						[expr {$offset_y - $half_edge}]	\
						-fill $zero_color -tags graph]
					incr offset_x $enge_inc1
					incr offset_y -$half_edge
					lappend lines [$canvasWidget create line		\
						$offset_x $offset_y				\
						[expr {$offset_x + $line_len}] $offset_y	\
						-fill $zero_color -tags graph]
			}

		# Access to external memory
		} elseif {$bool == {X}} {
			lappend lines [$canvasWidget create rectangle				\
				$offset_x $offset_y						\
				[expr {$offset_x + $step_x}] [expr {$offset_y + $half_edge}]	\
				-fill $zero_color -width 0 -tags graph]
			lappend lines [$canvasWidget create rectangle				\
				$offset_x [expr {$offset_y + $half_edge}]			\
				[expr {$offset_x + $step_x}] [expr {$offset_y + $full_edge}]	\
				-fill {#00FF00} -width 0 -tags graph]


			set bool $prev

		# Underminable state
		} elseif {$bool == {-}} {
			# Draw transition from the previous value
			switch -- $prev {
				{0} {	;# From logical zero
					lappend lines [$canvasWidget create line		\
						$offset_x [expr {$offset_y + $full_edge}]	\
						$offset_x [expr {$offset_y + $half_edge}]	\
						-fill {#00FF00} -tags graph]
				}
				{1} {	;# From logical one
					lappend lines [$canvasWidget create line		\
						$offset_x [expr {$offset_y + 0}]		\
						$offset_x [expr {$offset_y + $half_edge}]	\
						-fill $zero_color -tags graph]
				}
				{|} {	;# From high frequency pulse
					lappend lines [$canvasWidget create line		\
						$offset_x [expr {$offset_y + 0}]		\
						$offset_x [expr {$offset_y + $half_edge}]	\
						-fill $zero_color -tags graph]
				}
			}

			incr offset_y $half_edge
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y			\
				[expr {$offset_x + $line_len}] [expr {$offset_y + int(rand() * $half_edge)}]	\
				[expr {$offset_x + $line_len + $enge_inc0}] $offset_y	\
				[expr {$offset_x + $line_len + $enge_inc0 + $enge_inc1}] [expr {$offset_y - int(rand() * $half_edge)}]	\
				[expr {$offset_x + 2*$line_len + $enge_inc0 + $enge_inc1}] $offset_y	\
				-fill {#FF8800} -tags graph]

		# "Indeterminable state" -> "Zero"
		} elseif {$prev == {-} && $bool == 0} {
			lappend lines [$canvasWidget create line				\
				$offset_x [expr {$offset_y + $half_edge}]			\
				$offset_x [expr {$offset_y + $full_edge}]			\
				[expr {$offset_x + $step_x}] [expr {$offset_y + $full_edge}]	\
				-fill {#00FF00} -tags graph]

		# "Indeterminable state" -> "One"
		} elseif {$prev == {-} && $bool == 1} {
			lappend lines [$canvasWidget create line			\
				$offset_x [expr {$offset_y + $half_edge}]		\
				$offset_x [expr {$offset_y + 0}]			\
				[expr {$offset_x + $step_x}] [expr {$offset_y + 0}]	\
				-fill $zero_color -tags graph]

		# No voltage
		} elseif {$bool == {?}} {
			# Draw transition from the previous value
			switch -- $prev {
				{0} {	;# From logical zero
					lappend lines [$canvasWidget create line		\
						$offset_x [expr {$offset_y + $full_edge}]	\
						$offset_x [expr {$offset_y + $half_edge}]	\
						-fill {#00FF00} -tags graph]
				}
				{1} {	;# From logical one
					lappend lines [$canvasWidget create line		\
						$offset_x [expr {$offset_y + 0}]		\
						$offset_x [expr {$offset_y + $half_edge}]	\
						-fill $zero_color -tags graph]
				}
				{|} {	;# From high frequency pulse
					lappend lines [$canvasWidget create line		\
						$offset_x [expr {$offset_y + 0}]		\
						$offset_x [expr {$offset_y + $half_edge}]	\
						-fill $zero_color -tags graph]
				}
			}

			incr offset_y $half_edge
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y			\
				[expr {$offset_x + $step_x}] $offset_y	\
				-fill {#888888} -tags graph -width 2]

		# "No voltage" -> "Zero"
		} elseif {$prev == {?} && $bool == 0} {
			lappend lines [$canvasWidget create line			\
				$offset_x [expr {$offset_y + $half_edge}]			\
				$offset_x [expr {$offset_y + $full_edge}]			\
				[expr {$offset_x + $step_x}] [expr {$offset_y + $full_edge}]	\
				-fill {#00FF00} -tags graph]

		# "No voltage" -> "One"
		} elseif {$prev == {?} && $bool == 1} {
			lappend lines [$canvasWidget create line			\
				$offset_x [expr {$offset_y + $half_edge}]			\
				$offset_x [expr {$offset_y + 0}]			\
				[expr {$offset_x + $step_x}] [expr {$offset_y + 0}]	\
				-fill $zero_color -tags graph]

		# "High freq. pulse" -> "Zero"
		} elseif {$prev == {|} && $bool == 0} {
			lappend lines [$canvasWidget create line			\
				$offset_x [expr {$offset_y + 0}]			\
				$offset_x [expr {$offset_y + $half_edge}]			\
				-fill $zero_color -tags graph]
			lappend lines [$canvasWidget create line			\
				$offset_x [expr {$offset_y + $half_edge}]			\
				$offset_x [expr {$offset_y + $full_edge}]			\
				[expr {$offset_x + $step_x}] [expr {$offset_y + $full_edge}]	\
				-fill {#00FF00} -tags graph]

		# "High freq. pulse" -> "One"
		} elseif {$prev == {|} && $bool == 1} {
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y			\
				[expr {$offset_x + $step_x}] $offset_y	\
				-fill $zero_color -tags graph]

		# 1 -> 1
		} elseif {$prev == 1 && $bool == 1} {
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y			\
				[expr {$offset_x + $step_x}] $offset_y	\
				-fill $zero_color -tags graph]

		# 1 -> 0
		} elseif {$prev == 1 && $bool == 0} {
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y [expr {$offset_x + $line_len}] $offset_y	\
				-fill $zero_color -tags graph]
			incr offset_x $line_len
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y			\
				[expr {$offset_x + $enge_diff}] [expr {$offset_y + $half_edge}]	\
				-fill $zero_color -tags graph]
			incr offset_x $enge_inc0
			incr offset_y $half_edge
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y			\
				[expr {$offset_x + $enge_diff}] [expr {$offset_y + 5}]	\
				-fill {#00FF00} -tags graph]
			incr offset_x $enge_inc1
			incr offset_y $half_edge
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y [expr {$offset_x + $line_len}] $offset_y	\
				-fill {#00FF00} -tags graph]

		# 0 -> 1
		} elseif {$prev == 0 && $bool == 1} {
			incr offset_y $full_edge
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y [expr {$offset_x + $line_len}] $offset_y	\
				-fill {#00FF00} -tags graph]
			incr offset_x $line_len
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y			\
				[expr {$offset_x + $enge_diff}] [expr {$offset_y - $half_edge}]	\
				-fill {#00FF00} -tags graph]
			incr offset_x $enge_inc0
			incr offset_y -$half_edge
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y			\
				[expr {$offset_x + $enge_diff}] [expr {$offset_y - $half_edge}]	\
				-fill $zero_color -tags graph]
			incr offset_x $enge_inc1
			incr offset_y -$half_edge
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y [expr {$offset_x + $line_len}] $offset_y	\
				-fill $zero_color -tags graph]

		# 0 -> 0
		} else {
			incr offset_y $full_edge
			lappend lines [$canvasWidget create line	\
				$offset_x $offset_y			\
				[expr {$offset_x + $step_x}] $offset_y	\
				-fill {#00FF00} -tags graph]
		}

		# Adjust array of graph elements and previous states
		lappend graph_elements($idx) $lines
		set previous_state($idx) $bool
	}

	## Iterate over available grid modes
	 # @parm Int by - Iterate by
	 # @return void
	public method graph_switch_grid_mode {_grid_mode} {
		set grid_mode $_grid_mode

		# Adjust button in button bar and canvas popup menu
		switch -- $grid_mode {
			{b}	{set image {grid0}}
			{n}	{set image {grid1}}
			{y}	{set image {grid2}}
			{x}	{set image {grid3}}
		}
		$menu		entryconfigure [::mc "Change grid"] -image ::ICONS::16::$image
		# Redraw grid
		adjust_grid
	}

	## Adjust grid morphology to the current grid mode
	 # @return void
	private method adjust_grid {} {
		# Remove the current grid
		catch {
			$canvasWidget delete grid
		}
		# Create new grid
		switch -- $grid_mode {
			{b}	{
				draw_y_grid
				draw_x_grid
			}
			{n}	{}
			{y}	{draw_y_grid}
			{x}	{draw_x_grid}
		}
	}

	## Draw vertical grid lines
	 # @return void
	private method draw_y_grid {} {
		# Iterate over graph blocks
		for {set i 0} {$i < $number_of_ports} {incr i} {
			# Determinate horizontal boundaries
			set xoff [expr {$i * $port_length_in_px + 20 + $step_x}]
			set xend [expr {($i + 1) * $port_length_in_px + 5}]
			# Draw vertical lines
			for {set x $xoff} {$x < $xend} {incr x $step_x} {
				$canvasWidget create line $x 16 $x 120 -fill {#AAAAAA} -tags grid -dash .
			}
		}
	}

	## Draw horizontal grid lines
	 # @return void
	private method draw_x_grid {} {
		for {set y 30} {$y < 120} {incr y $step_y} {
			$canvasWidget create line 0 $y 860 $y -fill {#888888} -tags grid
		}
	}

	## Set graph configuration variables
	 # @parm Char _grid_mode	- Grid morphology (one of {'n' 'x' 'y' 'b'})
	 # @parm Int _magnification	- Magnification mode (one of {0 1 2 3})
	 # @parm Bool _drawing_on	- Widget enabled
	 # @parm List _mark_flags	- List of mark flags (e.g {0 0 0 1 1 0})
	 # @return void
	public method graph_set_data {_grid_mode _magnification _drawing_on _mark_flags} {
		set grid_mode $_grid_mode
		set magnification $_magnification
		set drawing_on $_drawing_on
		set mark_flags $_mark_flags
	}

	## Get mark flags
	 # @return String - String of boolean flags
	public method graph_get_marks {} {
		set result [::NumSystem::bin2hex [join $mark_flags {}]]
		set len [string length $result]
		if {$len < 43} {
			set result "[string repeat {0} [expr {43 - $len}]]$result"
		}

		return "X$result"
	}

	## Adjust graph to the current magnification level
	 # @parm Int _magnification - Maginification level (0..3)
	 # @return void
	public method commit_magnification {_magnification} {
		set magnification $_magnification

		# Determinate one bit X axis step
		set step_x [expr {$magnification * 5 + 5}]

		clear_graph keephistory	;# Clear graph
		adjust_grid		;# Adjust graph grid
		# Remove user marks
		catch {
			$canvasWidget delete mark
		}

		# Restore graph content from the history (voltage levels and interrupt lines)
		set length [expr {$port_graph_length / $step_x - 1}]
		foreach	state	[lrange $state_history end-$length end]	\
			intr	[lrange $intr_history end-$length end]	\
		{
			graph_new_output_state $state
			if {$intr == 1} {
				graph_draw_interrupt_line nohistory
			}
		}

		# Restore user marks
		set x_off [expr {21 - $step_x}]
		set i -1
		foreach mark [lrange $mark_flags 0 $length] {
			incr i
			incr x_off $step_x
			if {!$mark} {continue}

			set x $x_off
			set lines [list]
			for {set j 0} {$j < $number_of_ports} {incr j} {
				lappend lines [$canvasWidget create rectangle	\
					$x 16 [expr {$x + $step_x - 1}] 120	\
					-fill {#AA88FF} -tags mark -width 0]
				incr x $port_length_in_px
			}
			lset marks $i $lines
		}
	}

	## Remove all graph elements (voltage levels)
	 # @parm String - If "keephistory" then do not clear history
	 # @return void
	public method clear_graph args {
		if {!$graph_w_gui_initialized} {CreateGraphGUI}

		catch {
			$canvasWidget delete graph
		}
		catch {
			$canvasWidget delete highlight
		}
		catch {
			$canvasWidget delete booleans
		}
		for {set i 0} {$i < 40} {incr i} {
			set graph_elements($i) {}
		}
		set intr_lines {}

		if {$args != {keephistory}} {
			set state_history {}
			set intr_history {}
			for {set i 0} {$i < 40} {incr i} {
				set previous_state($i) 1
			}
		}
	}

	## Turn graph ON/OFF
	 # @return void
	public method graph_change_status_on {} {
		$Super graph_commit_state_on_off $drawing_on
	}

	## Adjust object to the current value of flag 'drawing_on'
	 # @return void
	public method commit_state_on_off {_drawing_on} {
		if {!$graph_w_gui_initialized} {CreateGraphGUI}
		set drawing_on $_drawing_on

		# Enable widgets
		if {$drawing_on} {
			$menu entryconfigure [::mc "Remove marks"] -state normal
			$menu entryconfigure [::mc "Change grid"] -state normal
			$canvasWidget configure -state normal

		# Disable widgets, clear graph and clear history
		} else {
			$menu entryconfigure [::mc "Remove marks"] -state disabled
			$menu entryconfigure [::mc "Change grid"] -state disabled
			$menu entryconfigure [::mc "Zoom in"] -state disabled
			$menu entryconfigure [::mc "Zoom out"] -state disabled
			$canvasWidget configure -state disabled
			clear_graph
		}
	}

	## Highlight graph segment
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method graph_highlight {x y} {
		# Remove previous highlight
		graph_unhighlight

		# Check for allowed coordinate range
		if {$y < 17 || $x < 21} {return}
		set x [expr {($x - 20) % $port_length_in_px}]
		if {$x >= $port_graph_length - ($port_graph_length % $step_x)} {return}

		incr x [expr {-($x % $step_x)}]
		incr x 21

		# Draw highlight rectangulars
		for {set i 0} {$i < $number_of_ports} {incr i} {
			$canvasWidget create rectangle	\
				$x 16 [expr {$x + $step_x - 1}] 120	\
				-fill {#88FFFF} -tags highlight -width 0
			incr x $port_length_in_px
		}

		set y [expr {$y - (($y - 17) % $step_y)}]

		$canvasWidget create rectangle		\
			0 $y 860 [expr {$y + $step_y}]	\
			-fill {#88FFFF} -tags highlight -width 0

		# Set tag priorities
		catch {
			$canvasWidget lower highlight mark
		}
		catch {
			$canvasWidget lower highlight grid
		}
		catch {
			$canvasWidget lower highlight graph
		}
		catch {
			$canvasWidget lower highlight booleans
		}
		catch {
			$canvasWidget lower highlight background
		}
	}

	## Remove highlightion
	 # @return void
	public method graph_unhighlight {} {
		catch {
			$canvasWidget delete highlight
		}
	}

	## Popup canvas menu
	 # @parm Int X - Absolute X coordinate
	 # @parm Int Y - Absolute X coordinate
	 # @return void
	public method graph_popup_menu {X Y} {
		tk_popup $menu $X $Y
	}

	## Place mark in the graph
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method graph_place_mark {x y} {
		# Check for allowed coordinate range
		if {$y < 17 || $x < 21} {return}
		set x [expr {($x - 20) % $port_length_in_px}]
		if {$x >= $port_graph_length - ($port_graph_length % $step_x)} {return}

		incr x [expr {-($x % $step_x)}]
		set idx [expr {$x / $step_x}]

		# Create mark
		if {[lindex $mark_flags $idx] != 1} {
			incr x 21
			set lines {}
			for {set i 0} {$i < $number_of_ports} {incr i} {
				lappend lines [$canvasWidget create rectangle	\
					$x 16 [expr {$x + $step_x - 1}] 120	\
					-fill {#AA88FF} -tags mark -width 0]
				incr x $port_length_in_px
			}
			catch {
				$canvasWidget raise mark highlight
			}
			catch {
				$canvasWidget lower mark grid
			}
			catch {
				$canvasWidget lower mark graph
			}
			lset marks $idx $lines
			lset mark_flags $idx 1

		# Remove mark
		} else {
			catch {
				foreach elm [lindex $marks $idx] {
					$canvasWidget delete $elm
				}
			}
			lset marks $idx {}
			lset mark_flags $idx 0
		}
	}

	## Remove all user marks from the graph
	 # @return void
	public method graph_clear_marks {} {
		catch {
			$canvasWidget delete mark
		}
		set marks [string repeat {{} } [expr {$history_max_length + 1}]]
		set mark_flags [string repeat {0 } [expr {$history_max_length + 1}]]
	}

	## Adjust scrollbar for scrollable area
	 # @parm Float frac0	- 1st fraction
	 # @parm Float frac0	- 2nd fraction
	 # @return void
	public method graph_gui_scroll_set {frac0 frac1} {
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

	## Try to restore graph state before the given number of program steps
	 # @parm Int bits - Number of steps to take back
	 # @return void
	public method graph_stepback {bits} {
		if {!$graph_w_gui_initialized} {CreateGraphGUI}
		if {!$drawing_on} {return}

		# Remove elemets
		incr bits -1
		for {set i 0} {$i < ($number_of_ports * 8)} {incr i} {
			foreach elm [lrange $graph_elements($i) end-$bits end] {
				foreach e $elm {
					$canvasWidget delete $e
				}
			}
			foreach elm [lrange $intr_lines end-$bits end] {
				foreach e $elm {
					$canvasWidget delete $e
				}
			}
			set graph_elements($i) [lreplace $graph_elements($i) end-$bits end]
		}
		set intr_lines [lreplace $intr_lines end-$bits end]

		# Adjust history
		set intr_history [lreplace $intr_history end-$bits end]
		set state_history [lreplace $state_history end-$bits end]

		# Return graph to state before $bits steps
		set last_state [lindex $state_history {end 1}]
		if {[llength $last_state]} {
			set ports {}
			foreach idx $port_numbers {
				lappend ports [lindex $last_state $idx]
			}

			set p_idx	0		;# Port index (not port number)
			set idx		0		;# Bit index
			$canvasWidget delete booleans	;# Clear boolean values
			foreach num $ports {
				foreach bit $num {
					set previous_state($idx) $bit
					incr idx
				}
				# Draw booleans
				write_boolean $p_idx $num
				incr p_idx
			}
		} else {
			clear_graph
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

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
if { ! [ info exists _GRAPH_TCL ] } {
set _GRAPH_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Graph panel in the bottom panel - shows states of ports
# --------------------------------------------------------------------------

source "${::LIB_DIRNAME}/bottompanel/graph_wdg.tcl"	;# Graph widget

class Graph {
	## COMMON
	 # Bool: The message: "Performance warning" was already displayed to the user
	public common performance_warning_already_shown	0
	 # Bool: show performance warning when enabling external HW simulation
	public common show_sim_per_warn			${::CONFIG(SHOW_PALE_WARN)}

	# Variables related to object initialization
	private variable data_list			;# Teportary variable -- Configuration list
	private variable graph_gui_initialized	0	;# Bool: GUI created
	private variable parent				;# Parent widget

	private variable grid_mode		{b}	;# Current grid mode (one of {b n x y})
	private variable drawing_on		0	;# Bool: Graph enabled
	private variable magnification		0	;# Magnification level (0..3)
	private variable active_page		{}	;# String: ID of currently active page

	private variable start_stop_button		;# Widget: Button "ON"/"OFF"
	private variable zoom_in_button			;# Widget: Button "Zoom in"
	private variable zoom_out_button		;# Widget: Button "Zoom out"
	private variable clear_marks_button		;# Widget: Button "Clear marks"
	private variable grid_button			;# Widget: Button "Change grid"

	private variable pages_manager			;# Widget: Pages manager for graph widgets
	private variable nb_state_frame			;# Widget: Frame containing graph "True state"
	private variable nb_latches_frame		;# Widget: Frame containing graph "Latches"
	private variable nb_output_frame		;# Widget: Frame containing graph "True Output"

	private variable state_but			;# Widget: Button "True state"
	private variable latches_but			;# Widget: Button "Latches"
	private variable output_but			;# Widget: Button "True Output"

	private variable graph_state			;# Object: Graph widget representing "True state"
	private variable graph_latches			;# Object: Graph widget representing "Latches"
	private variable graph_output			;# Object: Graph widget representing "True Output"

	private variable graph_state_created	0	;# Bool: GUI of object $graph_state created
	private variable graph_latches_created	0	;# Bool: GUI of object $graph_latches created
	private variable graph_output_created	0	;# Bool: GUI of object $graph_output created


	## Object constructor
	constructor {} {
		# Configure localy used ttk styles
		ttk::style configure Graph_ActiveTab.TButton	\
			-background {#AAAAFF}			\
			-padding 0				\
			-borderwidth 1
		ttk::style map Graph_ActiveTab.TButton		\
			-background [list active {#DDDDFF}]	\
			-foreground [list active {#0000DD} !active {#000000}]
	}

	## Object destructor
	destructor {
	}

	## Prepare object for creating its GUI
	 # @parm Widget Parent		- GUI parent widget
	 # @parm List _data_list	- Configuration data list
	 # @return void
	public method PrepareGraph {Parent _data_list} {
		set parent $Parent
		set data_list $_data_list
		set graph_gui_initialized 0

		# Enable or disable PALE
		$this pale_on_off [lindex $data_list 2]
	}

	## Inform this tab than it has became active
	 # @return void
	public method GraphTabRaised {} {
	}

	## Initialize graph
	 # @return void
	public method CreateGraphGUI {} {
		if {$graph_gui_initialized} {return}
		set graph_gui_initialized 1

		if {${::DEBUG}} {
			puts "CreateGraphGUI \[ENTER\]"
		}

		# Create panel frames
		set top_bar [frame $parent.top_bar -bg {#CCCCCC}]	;# Buttons for switching pages
		set bottom_frame [frame $parent.bottom_frame]		;# Graphs
		set left_bar [frame $bottom_frame.left_bar]		;# Button bar on the left

		## Create button bar
		 # Button "Enable/Disable"
		set start_stop_button [ttk::button $left_bar.start_stop_button	\
			-command "$this graph_change_status_on"			\
			-width 3						\
		]
		DynamicHelp::add $left_bar.start_stop_button	\
			-text [mc "Turn graph on/off"]
		setStatusTip -widget $start_stop_button -text [mc "Enable/Disable graph"]
		bind $start_stop_button <Button-3> "$this graph_change_status_on; break"
		pack $start_stop_button -anchor n
		 # Separator
		pack [ttk::separator $left_bar.sep0 -orient horizontal] -fill x -pady 2
		 # Button "Change grid mode"
		set grid_button [ttk::button $left_bar.grid_button	\
			-style Flat.TButton				\
			-image ::ICONS::16::grid1			\
			-command "$this graph_switch_grid_mode 1"	\
		]
		DynamicHelp::add $grid_button -text [mc "Change grid"]
		setStatusTip -widget $grid_button -text [mc "Change grid morphology"]
		pack $grid_button -anchor n
		bind $grid_button <Button-1> "$this graph_switch_grid_mode 1; break"
		bind $grid_button <Button-3> "$this graph_switch_grid_mode -1; break"
		 # Separator
		pack [ttk::separator $left_bar.sep1 -orient horizontal] -fill x -pady 2
		 # Button "Zoom in"
		set zoom_in_button [ttk::button $left_bar.zoom_in_button	\
			-image ::ICONS::16::viewmag_in				\
			-command "$this graph_zoom_in"				\
			-style Flat.TButton					\
		]
		DynamicHelp::add $zoom_in_button -text [mc "Change bit length on X axis to a lower value"]
		setStatusTip -widget $zoom_in_button -text [mc "Zoom in (X axis)"]
		pack $zoom_in_button
		 # Button "Zoom out"
		set zoom_out_button [ttk::button $left_bar.zoom_out_button	\
			-image ::ICONS::16::viewmag_out				\
			-command "$this graph_zoom_out"				\
			-style Flat.TButton					\
		]
		DynamicHelp::add $zoom_out_button -text [mc "Change bit length on X axis to a higher value"]
		setStatusTip -widget $zoom_out_button -text [mc "Zoom out (X axis)"]
		pack $zoom_out_button
		 # Separator
		pack [ttk::separator $left_bar.sep2 -orient horizontal] -fill x -pady 2
		 # Button "Clear marks"
		set clear_marks_button [ttk::button $left_bar.clear_marks_button	\
			-image ::ICONS::16::editdelete					\
			-command "$this graph_clear_marks"				\
			-style Flat.TButton						\
		]
		DynamicHelp::add $clear_marks_button -text [mc "Clear user marks"]
		setStatusTip -widget $clear_marks_button -text [mc "Clear marks"]
		pack $clear_marks_button

		# Create graphs
		set pages_manager	[PagesManager $bottom_frame.pages_manager -background ${::COMMON_BG_COLOR}]
		set nb_state_frame	[$pages_manager add {state}]
		set nb_latches_frame	[$pages_manager add {latches}]
		set nb_output_frame	[$pages_manager add {output}]

		## Create buttons
		 # Button "True state"
		set state_but [ttk::button $top_bar.state_but			\
			-text [mc "True state"]					\
			-image ::ICONS::16::dot_g				\
			-command "$this Graph_set_active_page {state}"		\
			-compound left						\
			-style Flat.TButton					\
		]
		pack $state_but -side left -pady 0 -ipady 0 -padx 1
		 # Button "Port Latches"
		set latches_but [ttk::button $top_bar.latches_but		\
			-text [mc "Port latches"]				\
			-compound left						\
			-image ::ICONS::16::dot					\
			-command "$this Graph_set_active_page {latches}"	\
			-style Flat.TButton					\
		]
		pack $latches_but -side left -pady 0 -ipady 0 -padx 1
		 # Button "True Output"
		set output_but [ttk::button $top_bar.output_but			\
			-text [mc "True output"]				\
			-compound left						\
			-image ::ICONS::16::dot_r		 		\
			-command "$this Graph_set_active_page {output}"		\
			-style Flat.TButton					\
		]
		pack $output_but -side left -pady 0 -ipady 0 -padx 1
		 # Button "Show legend"
		set help_but [ttk::button $top_bar.help_but			\
			-text [mc "Legend"]					\
			-command "$this Graph_show_legend"			\
			-style Flat.TButton					\
		]
		pack $help_but -side left -pady 0 -ipady 0 -padx 1

		set graph_state		[GraphWidget #auto $nb_state_frame $this]
		set graph_latches	[GraphWidget #auto $nb_latches_frame $this]
		set graph_output	[GraphWidget #auto $nb_output_frame $this]

		pack $top_bar -anchor nw -ipady 1
		pack $left_bar -anchor n -side left
		pack [ttk::separator $bottom_frame.sep -orient vertical] -fill y -side left -padx 1
		pack $pages_manager -fill both -expand 1 -side left
		pack $bottom_frame -fill both -expand 1

		# Adjust configuration to the given datalist
		set grid_mode		[lindex $data_list 0]
		set magnification	[lindex $data_list 1]
		set drawing_on		[lindex $data_list 2]
		set mark_flags_s	[lindex $data_list 3]
		set mark_flags_l	[lindex $data_list 4]
		set mark_flags_o	[lindex $data_list 5]
		set active_page		[lindex $data_list 6]

		# Validate the loaded confiuration
		foreach mark_flags {mark_flags_s mark_flags_l mark_flags_o} {
			set mark_flags_data [subst -nocommands "\$$mark_flags"]
			if {[string index $mark_flags_data 0] == {X}} {
				set mark_flags_data [string range $mark_flags_data 1 end]
				if {
					[string length $mark_flags_data] != 43
						||
					![string is xdigit $mark_flags_data]
				} then {
					puts stderr "Invalid graph mark flags -- discarded"
					set $mark_flags [string repeat {0 } 170]
				} else {
					set bin [::NumSystem::hex2bin $mark_flags_data]
					set len [string length $bin]
					if {$len < 170} {
						set bin "[string repeat {0} [expr {170 - $len}]]$bin"
					}
					set $mark_flags [split $bin {}]
				}
			} else {
				if {
					![regexp {^[01]+$} $mark_flags_data]
						||
					[string bytelength $mark_flags_data] != 170
				} then {
					puts stderr "Invalid graph mark flags -- discarded"
					set $mark_flags [string repeat {0 } 170]
				} else {
					set $mark_flags [split $mark_flags_data {}]
				}
			}
		}
		if {
			$magnification != {0}	&&	$magnification != {1}	&&
			$magnification != {2}	&&	$magnification != {3}
		} then {
			puts stderr "Invalid graph magnification level -- setting to default"
			set magnification 0
		}
		if {$drawing_on != {0} && $drawing_on != {1}} {
			puts stderr "Invalid graph on/off flag -- setting to 'on'"
			set drawing_on 1
		}
		if {
			$grid_mode != {b}	&&	$grid_mode != {n}	&&
			$grid_mode != {y}	&&	$grid_mode != {x}
		} then {
			puts stderr "Invalid graph grid mode -- setting to 'y'"
			set grid_mode {y}
		}
		if {[lsearch -ascii -exact {state latches output} $active_page] == -1} {
			puts stderr "Invalid graph active page -- setting to 'state'"
			set active_page {state}
		}

		set mark_flags [list $mark_flags_s $mark_flags_l $mark_flags_o]
		set i 0
		foreach obj [list $graph_state $graph_latches $graph_output] {
			$obj graph_set_data	\
				$grid_mode	\
				$magnification	\
				$drawing_on	\
				[lindex $mark_flags $i]
			incr i
		}

		adjust_mag_buttons
		adjust_on_off_button
		adjust_grid_button

		# Unset tempotary variables
		unset data_list

		Graph_set_active_page $active_page
	}

	## Show legend for graph
	 # @return void
	public method Graph_show_legend {} {
		# Destroy legend window
		if {[winfo exists .graph_help_win]} {
			grab release .graph_help_win
			destroy .graph_help_win
			return
		}
		set win_x [expr {[winfo pointerx .] + 10}]
		set win_y [winfo pointery .]

		# Create legend window
		set win [toplevel .graph_help_win -class {Help} -bg ${::COMMON_BG_COLOR}]
		set frame [frame $win.f -bg {#555555} -bd 0 -padx 1 -pady 1]
		wm overrideredirect $win 1

		# Click to close
		bind $win <Button-1> "grab release $win; destroy $win"

		# Create header "-- click to close --"
		pack [label $frame.lbl_header			\
			-text [mc "-- click to close --"]	\
			-bg {#FFFF55} -font $::smallfont	\
			-fg {#000000} -anchor c			\
		] -side top -anchor c -fill x

		# Create canvas widget
		set canvas [canvas $frame.canvas\
			-bg {#FFFFFF}		\
			-takefocus 0		\
			-cursor left_ptr	\
			-bd 0 -relief flat	\
			-width 1 -height 1	\
		]

		pack $frame -fill both -expand 1

		# Fill in the canvas widget
		Graph_create_legend $canvas 0

		# Show the canvas
		pack $canvas -side bottom -fill both -expand 1

		# Show the window
		wm geometry $win "=260x135+$win_x+$win_y"
		update
		catch {
			grab -global $win
		}
	}

	## Fill in the specified canvas widget to contain the graph legend
	 # @parm Widget canvas - Target canvas widget
	 # @parm Bool nc_instead_of_X	- Show "Not connected" instead of "Access to external memory"
	 # @return void
	public method Graph_create_legend {canvas nc_instead_of_X} {
		set x 10
		 # {=}	Log. 1 forced to log. 0
		$canvas create line $x 20 [expr {$x + 20}] 20 -fill {#FF00AA} -width 2
		incr x 20
		 # {}	Not connected
		if {$nc_instead_of_X} {
			$canvas create line $x 20 $x 15 -fill {#FF00AA} -width 2
			$canvas create line $x 15 [expr {$x + 20}] 15 -fill {#000000} -width 2

		 # {X}	Access to external memory
		} else {
			$canvas create rectangle $x 20	\
				[expr {$x + 20}] 15	\
				-fill {#00FF00} -width 0 -outline {#00FF00}
			$canvas create rectangle $x 15	\
				[expr {$x + 20}] 10	\
				-fill {#FF0000} -width 0 -outline {#FF0000}
		}
		incr x 20
		 # {-}	Indeterminable state
		$canvas create line $x 15	\
			[expr {$x + 5}] 11	\
			[expr {$x + 10}] 15	\
			[expr {$x + 15}] 17	\
			[expr {$x + 20}] 14 -fill {#FF8800} -width 2
		incr x 20
		 # {?}	No voltage
		$canvas create line $x 15 [expr {$x + 20}] 15 -fill {#888888} -width 2
		incr x 20
		 # {1}	Log. 1
		$canvas create line $x 15 $x 10 [expr {$x + 20}] 10 [expr {$x + 20}] 15 -fill {#FF0000} -width 2
		incr x 20
		 # {0}	Log. 0
		$canvas create line $x 15 $x 20 [expr {$x + 20}] 20 -fill {#00FF00} -width 2
		incr x 20

		## Descriptions
		 # {=}	Log. 1 forced to log. 0
		$canvas create line 20 23	20 100	30 100	\
			-fill {#000000} -arrow first -arrowshape {6 6 2}
		$canvas create text 30 100 -fill {#000000} -anchor w	\
			-text [mc "Log. 1 forced to log. 0"]		\
			-font $::smallfont
		 # {}	Not connected
		if {$nc_instead_of_X} {
			set tmp_txt [mc "Not connected"]
		 # {X}	Access to external memory
		} else {
			set tmp_txt [mc "Access to external memory"]
		}
		$canvas create line 40 23	40 86	50 86		\
			-fill {#000000} -arrow first -arrowshape {6 6 2}
		$canvas create text 50 86 -fill {#000000} -anchor w	\
			-text $tmp_txt -font $::smallfont
		 # {-}	Indeterminable state
		$canvas create line 60 23	60 72	70 72		\
			-fill {#000000} -arrow first -arrowshape {6 6 2}
		$canvas create text 70 72 -fill {#000000} -anchor w	\
			-text [mc "Indeterminable state"] -font $::smallfont
		 # {?}	No voltage
		$canvas create line 80 23	80 58	90 58		\
			-fill {#000000} -arrow first -arrowshape {6 6 2}
		$canvas create text 90 58 -fill {#000000} -anchor w	\
			-text [mc "No voltage"] -font $::smallfont
		 # {1}	Log. 1
		$canvas create line 100 23	100 44	110 44		\
			-fill {#000000} -arrow first -arrowshape {6 6 2}
		$canvas create text 110 44 -fill {#000000} -anchor w	\
			-text [mc "Log. 1"] -font $::smallfont
		 # {0}	Log. 0
		$canvas create line 120 23	120 30	130 30		\
			-fill {#000000} -arrow first -arrowshape {6 6 2}
		$canvas create text 130 30 -fill {#000000} -anchor w	\
			-text [mc "Log. 0"] -font $::smallfont
	}

	## Create GUI for the specified tab
	 # @parm String page - Tab ID
	 # @return void
	public method Graph_create_tab {page} {
		switch -- $page {
			{state} {	;# Tab: True state
				if {!$graph_state_created} {
					set graph_state_created 1
					$graph_state	CreateGraphGUI
				}
			}
			{latches} {	;# Tab: Port Latches
				if {!$graph_latches_created} {
					set graph_latches_created 1
					$graph_latches	CreateGraphGUI
				}
			}
			{output} {	;# Tab: True Output
				if {!$graph_output_created} {
					set graph_output_created 1
					$graph_output	CreateGraphGUI
				}
			}
		}
	}

	## Set current active page
	 # @parm String page - Tab ID
	 # @return void
	public method Graph_set_active_page {page} {
		set active_page $page
		Graph_create_tab $page
		$pages_manager raise $page

		# Adjust buttons on the top
		foreach w [list $state_but $latches_but $output_but] {
			$w configure -style Flat.TButton
		}
		switch -- $page {
			{state} {	;# Tab: True state
				$state_but configure -style Graph_ActiveTab.TButton
			}
			{latches} {	;# Tab: Port Latches
				$latches_but configure -style Graph_ActiveTab.TButton
			}
			{output} {	;# Tab: True Output
				$output_but configure -style Graph_ActiveTab.TButton
			}
		}
	}

	## Draw interrupt line
	 # @parm String nh={} - If "nohistory" the history of interrupt lines will not be modified
	 # @return void
	public method graph_draw_interrupt_line {{nh {}}} {
		if {!$graph_gui_initialized} {CreateGraphGUI}
		create_all_graph_widgets

		$graph_state	graph_draw_interrupt_line $nh
		$graph_latches	graph_draw_interrupt_line $nh
		$graph_output	graph_draw_interrupt_line $nh
	}

	## Draw new port states in the graph
	 # @parm String target	- Target Graph, one of {S L O}
	 # @parm List values	- Values to display ...
	 # @return void
	public method graph_new_output_state {target values} {
		if {!$graph_gui_initialized} {CreateGraphGUI}
		create_all_graph_widgets

		switch -- $target {
			{S} {	;# Tab: True state
				$graph_state	graph_new_output_state $values
			}
			{L} {	;# Tab: Port Latches
				$graph_latches	graph_new_output_state $values
			}
			{O} {	;# Tab: True Output
				$graph_output	graph_new_output_state $values
			}
		}
	}

	## Adjust magnification buttons to the current magnification level
	 # @return void
	private method adjust_mag_buttons {} {
		# The lowest possible magnification level
		if {!$magnification} {
			$zoom_in_button configure -state normal
			$zoom_out_button configure -state disabled
		# The highest possible magnification level
		} elseif {$magnification == 3} {
			$zoom_in_button configure -state disabled
			$zoom_out_button configure -state normal
		# Something in the middle
		} else {
			$zoom_in_button configure -state normal
			$zoom_out_button configure -state normal
		}
	}

	## Switch between ON and OFF
	 # @return void
	public method graph_change_status_on {} {
		set drawing_on [expr {!$drawing_on}]
		graph_commit_state_on_off

		# Show performance warning
		if {$show_sim_per_warn && !$performance_warning_already_shown && $drawing_on} {
			set performance_warning_already_shown 1
			if {[winfo exists .performance_warning_dialog]} {
				destroy .performance_warning_dialog
			}
			set dialog [toplevel .performance_warning_dialog]
			set top_frame [frame $dialog.top]
			pack [label $top_frame.img -image ::ICONS::32::messagebox_info] -side left -padx 5
			pack [label $top_frame.txt -text [mc "You have just enabled simulation of external devices. Having this feature enabled causes serious reduction of simulator performance, the number of instructions executed per second in real time usually decreases by a factor of hundreds, maybe even thousands."] -wraplength 300 -justify left] -side left -fill both -padx 5

			set bottom_frame [frame $dialog.bottom]
			pack [checkbutton $bottom_frame.chb		\
				-text [mc "Do not display again"]	\
				-onvalue 0				\
				-offvalue 1				\
				-variable ::Graph::show_sim_per_warn	\
			] -anchor e -pady 5
			pack [ttk::button $bottom_frame.button_ok		\
				-text [mc "Ok"] -compound left			\
				-image ::ICONS::16::ok				\
				-command "grab release $dialog; destroy $dialog"\
			] -pady 10
			bind $bottom_frame.button_ok <Return> "grab release $dialog; destroy $dialog"
			bind $bottom_frame.button_ok <KP_Enter> "grab release $dialog; destroy $dialog"

			# Pack window frames
			pack $top_frame -expand 1 -padx 5 -pady 5
			pack $bottom_frame -padx 5 -fill x

			# Window manager options -- modal window
			wm iconphoto $dialog ::ICONS::16::info
			wm title $dialog [mc "Performance warning"]
			wm resizable $dialog 0 0
			wm transient $dialog .
			catch {grab $dialog}
			wm protocol $dialog WM_DELETE_WINDOW "
				grab release $dialog
				destroy $dialog
			"
			raise $dialog
			update
			focus -force $bottom_frame.button_ok
			tkwait window $dialog
		}
	}

	## Commit new ON/OFF state
	 # @return void
	public method graph_commit_state_on_off {} {
		create_all_graph_widgets

		$graph_state	commit_state_on_off $drawing_on
		$graph_latches	commit_state_on_off $drawing_on
		$graph_output	commit_state_on_off $drawing_on

		adjust_mag_buttons
		adjust_on_off_button
	}

	## Adjust apparence of all "ON/OFF" buttons in the PALE system
	 # @return void
	private method adjust_on_off_button {} {
		$this pale_on_off $drawing_on

		# ON
		if {$drawing_on} {
			$start_stop_button configure -style GreenBg.TButton -text [mc "ON"]
			$grid_button		configure -state normal
			$clear_marks_button	configure -state normal

		# OFF
		} else {
			$start_stop_button configure -style RedBg.TButton -text [mc "OFF"]

			$zoom_in_button		configure -state disabled
			$zoom_out_button	configure -state disabled
			$grid_button		configure -state disabled
			$clear_marks_button	configure -state disabled
		}
	}

	## Adjust apparence of all "Grid" buttons in the PALE system
	 # @return void
	private method adjust_grid_button {} {
		# Adjust button in button bar and canvas popup menu
		switch -- $grid_mode {
			{b}	{set image {grid0}}
			{n}	{set image {grid1}}
			{y}	{set image {grid2}}
			{x}	{set image {grid3}}
		}
		$grid_button	configure -image ::ICONS::16::$image

	}

	## Zoom in/out
	 # @parm Int by - Steps
	 # @return void
	public method graph_switch_grid_mode {by} {
		create_all_graph_widgets

		# Determinate number of the current grid mode
		set i [lsearch {b n y x} $grid_mode]
		# Increment by '$by'
		incr i $by
		while {$i > 3} {
			incr i -4
		}
		while {$i < 0} {
			incr i 4
		}
		# Set new grid mode
		set grid_mode [lindex {b n y x} $i]
		adjust_grid_button

		$graph_state	graph_switch_grid_mode $grid_mode
		$graph_latches	graph_switch_grid_mode $grid_mode
		$graph_output	graph_switch_grid_mode $grid_mode
	}

	## Zoom out
	 # @return void
	public method graph_zoom_out {} {
		if {!$magnification} {return}
		incr magnification -1
		commit_magnification
	}

	## Zoom in
	 # @return void
	public method graph_zoom_in {} {
		if {$magnification == 3} {return}
		incr magnification
		commit_magnification
	}

	## Commit new magnification level
	 # @return void
	private method commit_magnification {} {
		create_all_graph_widgets

		$graph_state	commit_magnification $magnification
		$graph_latches	commit_magnification $magnification
		$graph_output	commit_magnification $magnification

		# Adjust states of magnification buttons
		adjust_mag_buttons
	}

	## Clear graph marks in the the current graph
	 # @return void
	public method graph_clear_marks {} {
		switch -- $active_page {
			{state} {	;# Tab: True state
				$graph_state graph_clear_marks
			}
			{latches} {	;# Tab: Port Latches
				$graph_latches graph_clear_marks
			}
			{output} {	;# Tab: True Output
				$graph_output graph_clear_marks
			}
		}
	}

	## Clear all graphs
	 # @return void
	public method clear_graph {} {
		create_all_graph_widgets

		$graph_state	clear_graph
		$graph_latches	clear_graph
		$graph_output	clear_graph
	}

	## Create GUI of all graphs
	 # @return void
	private method create_all_graph_widgets {} {
		if {!$graph_gui_initialized} {CreateGraphGUI}

		Graph_create_tab state
		Graph_create_tab latches
		Graph_create_tab output
	}

	## Get graph configuration values -- for project save
	 # @return List - Configuration list
	public method graph_get_config {} {
		if {!$graph_gui_initialized} {CreateGraphGUI}

		create_all_graph_widgets

		return [list $grid_mode $magnification $drawing_on	\
			[$graph_state graph_get_marks]			\
			[$graph_latches graph_get_marks]		\
			[$graph_output graph_get_marks]			\
			$active_page					\
		]
	}

	## Try to restore graph state before the given number of program steps
	 # @parm Int bits - Number of steps to take back
	 # @return void
	public method graph_stepback {bits} {
		if {!$graph_gui_initialized} {CreateGraphGUI}
		if {!$drawing_on} {return}

		create_all_graph_widgets

		$graph_state	graph_stepback $bits
		$graph_latches	graph_stepback $bits
		$graph_output	graph_stepback $bits
	}

	## React to MCU change
	 # @return void
	public method graph_change_mcu {} {
		if {$graph_state_created} {
			$graph_state	change_mcu
		}
		if {$graph_latches_created} {
			$graph_latches	change_mcu
		}
		if {$graph_output_created} {
			$graph_output	change_mcu
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

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
if { ! [ info exists _INNERWINDOW_TCL ] } {
set _INNERWINDOW_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# Implements tool for creating application inner windows. That means windows
# which are enclosed in the main window. And which are not managed by window
# manager but by their own implementation. These windows are inside the main
# window and cannot be dragged outside.
#
# REQUIREMENTS:
#	Librararies: "Incr TCL", "BWidget", "Tk"
#	This class also requires this: "namespace import ::itcl::*"
# --------------------------------------------------------------------------

class InnerWindow {
	## COMMON
	public common active_titclr	{#AAAAFF}	;# Color: Active background color
	public common inactive_titclr	{#DDDDDD}	;# Color: Inactive background color
	public common title_bar_height	10		;# Int: Height of the titlebar in pixels

	# List: Title bar popup menu
	public common MENU {
		{command	"Shade/Unshade"	""	0	{collapse_expand}
			{}}
		{command	"Close"		""	0	{close_window}
			{}}
	}

	## PRIVATE
	private variable win_height
	private variable max_X				;# Int: Auxiliary variable for storing max. allowed position
	private variable max_Y				;# Int: Auxiliary variable for storing max. allowed position
	private variable click_X			;# Int: Auxiliary variable for storing last position
	private variable click_Y			;# Int: Auxiliary variable for storing last position

	private variable close_cmd
	private variable title_bar			;# Widget: Window title bar
	private variable title_label			;# Widget: Label containg text "Scribble notepad"
	private variable close_button			;# Widget: Close button
	private variable coll_exp_but			;# Widget: Shade button
	private variable win
	private variable main_frame			;# Widget: Main window frame
	private variable minim_flag		0	;# Bool: Shaded or not
	private variable allow_raise_win	1	;# Bool: Allows to use command

	private variable menu				;# Widget: Title bar popup menu
	private variable menu_created	 0		;# Bool:  Title bar popup menu created

	private variable close_window_in_progress 0	;# Bool: Close procedure is in progress

	## Object constructor
	 # @parm Widget path		- Window path (e.g. ".window_agent_007")
	 # @parm List geometry		- {W H X Y} (Coordinates are raltive to the transient window)
	 # @parm String title		- Window title
	 # @parm Image icon		- Window icon, {} means no icon
	 # @parm String _close_cmd	- Command to execute on close in the root namespace (stack frame #0)
	constructor {path geometry title icon _close_cmd} {

		# Configure specific ttk styles
		ttk::style configure InnerWindow_Active.TButton		\
			-background $active_titclr			\
			-padding 0					\
			-borderwidth 1					\
			-relief flat
		ttk::style map InnerWindow_Active.TButton		\
			-background [list active $active_titclr]	\
			-relief [list active raised]

		ttk::style configure InnerWindow_Inactive.TButton	\
			-background $inactive_titclr			\
			-padding 0					\
			-borderwidth 1					\
			-relief flat
		ttk::style map InnerWindow_Inactive.TButton		\
			-background [list active $inactive_titclr]	\
			-relief [list active raised]

		# Set object variables
		set max_X 1000
		set max_Y 1000
		set close_cmd $_close_cmd

		# Create window GUI components
		set win [frame $path -bd 1 -relief raised -bg $active_titclr -padx 2 -pady 2]
		set main_frame  [frame $win.main_frame]
		set menu $win.menu

		## Create title bar
		 # - Title bar frame
		set title_bar [frame $win.title_bar	\
			-bg $active_titclr		\
			-height $title_bar_height	\
		]
		set title_label [label $title_bar.text	\
			-bg $active_titclr -pady 0	\
			-compound left -text $title	\
			-cursor left_ptr		\
		]
		if {$icon != {}} {
			$title_label configure -image $icon -padx 5
		}
		 # - Button "Close"
		set close_button [ttk::button $title_bar.close_but	\
			-style InnerWindow_Active.TButton		\
			-command "$this close_window"			\
			-image ::ICONS::16::button_cancel		\
			-takefocus 0					\
		]
		DynamicHelp::add $close_button -text [mc "Close"]
		setStatusTip -widget $close_button -text [mc "Close"]
		 # - Button "Shade"
		set coll_exp_but [ttk::button $title_bar.col_exp_but	\
			-style InnerWindow_Flat.TButton			\
			-command "$this collapse_expand"		\
			-image ::ICONS::16::_1uparrow  			\
			-takefocus 0					\
		]
		DynamicHelp::add $coll_exp_but -text [mc "Shade"]
		setStatusTip -widget $coll_exp_but -text [mc "Shade"]
		 # Pack buttons
		pack $coll_exp_but -padx 5 -side left -pady 0 -ipady 0
		pack $close_button -side right -pady 0 -ipady 0 -padx 3
		pack $title_label -side left -fill x -pady 0 -ipady 0 -expand 1
		raise $close_button
		 # Set title bar event bindings
		bind $title_label <Double-1> "$this collapse_expand; break"
		bind $title_label <Button-1> "$this title_B1 %X %Y"
		bind $title_label <B1-Motion> "$this title_B1_motion %X %Y; break"
		bind $title_label <ButtonRelease-1>  "$this title_B1_release; break"
		bind $title_label <ButtonRelease-3>  "$this title_B3_release %X %Y; break"


		pack $title_bar -fill x
		pack $main_frame -fill both -expand 1

		# Show the window
		set win_height [lindex $geometry 1]
		bind $win <Destroy> "catch {delete object $this}"
		bind $main_frame <Destroy> "catch {delete object $this}"
		bind $win <Visibility> "$this raise_win"
		bind $win <FocusIn> "$this focusin"
		bind $win <FocusOut> "$this focusout"
		place $win				\
			-width [lindex $geometry 0]	\
			-height [lindex $geometry 1]	\
			-x [lindex $geometry 2]		\
			-y [lindex $geometry 3]		\
			-anchor nw
		raise $win
	}

	## Object destructor
	destructor {
		close_window
	}

	## Withdraw the window
	 # Note: Window can be taken back to visible state using method "geometry"
	 # @see geometry
	 # @return
	public method withdraw {} {
		place forget $win
	}

	## Close the window
	 # @return void
	public method close_window {} {
		if {$close_window_in_progress} {return}
		set close_window_in_progress 1

		uplevel #0 $close_cmd
		destroy $win
	}

	## Get window inner frame where to map widgets in the window
	 # @return Widget - Inner frame
	public method get_frame {} {
		return $main_frame
	}

	## Get and/or set window geometry including frame and title bar
	 # @parm Int w={} - Width
	 # @parm Int h={} - Height
	 # @parm Int x={} - Relative position -- X
	 # @parm Int y={} - Relative position -- Y
	 # Note: If you want to set only certain attributes then set others as {}
	 # @return Current window geometry {W H X Y}
	public method geometry {{w {}} {h {}} {x {}} {y {}}} {
		# Set geometry
		if {$w != {} || $h != {} || $x != {} || $y != {}} {
			if {[string length $w]} {
				place $win -width $w
			}
			if {[string length $h]} {
				place $win -height $h
				set win_height $h
			}
			if {[string length $x]} {
				place $win -x $x
			}
			if {[string length $y]} {
				place $win -y $y
			}
			update
		}

		# Get geometry
		return [list			\
			[winfo width $win]	\
			[winfo height $win]	\
			[winfo x $win]		\
			[winfo y $win]		\
		]
	}

	## Event handler: window frame <FocusIn>
	 # @return void
	public method focusin {} {
		update
		foreach widget [list $title_bar $title_label $win] {
			$widget configure -bg $active_titclr
		}
		foreach widget [list $close_button $coll_exp_but] {
			$widget configure -style InnerWindow_Active.TButton
		}

		update
	}

	## Event handler: window frame <FocusOut>
	 # @return void
	public method focusout {} {
		if {![winfo exists $win]} {
			return
		}

		update
		foreach widget [list $title_bar $title_label $win] {
			$widget configure -bg $inactive_titclr
		}
		foreach widget [list $close_button $coll_exp_but] {
			$widget configure -style InnerWindow_Inactive.TButton
		}
		update
	}

	## (Un)Shade window
	 # @return void
	public method collapse_expand {} {
		# Object variables
		set minim_flag [expr {!$minim_flag}]

		# Shade
		if {$minim_flag} {
			set image _1downarrow
			pack forget $main_frame
			place $win -height [expr {[winfo height $win.title_bar] + 4}]
		# Unshade
		} else {
			set image _1uparrow
			pack $main_frame -fill both -expand 1
			place $win -height $win_height
		}
		$coll_exp_but configure -image ::ICONS::16::$image
	}

	## Determinate whether the window is shaded or not
	 # @return Bool - 1 == Shaded; 0 == Not shaded
	public method get_minim_flag {} {
		return $minim_flag
	}

	## Insure window visibility
	 # @return void
	public method raise_win {} {
		if {!$allow_raise_win} {return}
		set allow_raise_win 0
		after 1000 "catch {$this set_allow_raise_win}"
		raise $win
	}

	## @see raise_win
	 # @return void
	public method set_allow_raise_win {} {
		set allow_raise_win 1
	}

	## Event handler: title bar <Button-1>
	 # @parm Int x - Absolute X coordinate
	 # @parm Int y - Absolute Y coordinate
	 # @return void
	public method title_B1 {x y} {
		set click_X [expr {[winfo x $win] - $x}]
		set click_Y [expr {[winfo y $win] - $y}]

		set max_X [winfo width .]
		set max_Y [winfo height .]
		incr max_X -70
		incr max_Y -70

		focus $win
		$title_label	configure -cursor fleur
	}

	## Event handler: title bar <ButtonRelease-1>
	 # @return void
	public method title_B1_release {} {
		$title_label	configure -cursor left_ptr
	}

	## Event handler: title bar <ButtonRelease-3>
	 # @parm Int x - Absolute X coordinate
	 # @parm Int y - Absolute Y coordinate
	 # @return void
	public method title_B3_release {X Y} {
		focus $win

		if {!$menu_created} {
			menuFactory $MENU $menu 0 "$this " 0 {} [namespace current]
			set menu_created 1
		}

		tk_popup $menu $X $Y
	}

	## Event handler: title bar <B1-Motion>
	 # @parm Int x - Absolute X coordinate
	 # @parm Int y - Absolute Y coordinate
	 # @return void
	public method title_B1_motion {x y} {
		incr x $click_X
		incr y $click_Y

		if {$x > 0 && $x < $max_X} {
			place $win -x $x
		}
		if {$y > 0 && $y < $max_Y} {
			place $win -y $y
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

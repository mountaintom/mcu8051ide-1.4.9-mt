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
if { ! [ info exists _NOTES_TCL ] } {
set _NOTES_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION:
# Scribble notes independent on project
# --------------------------------------------------------------------------

class Notes {
	## COMMON
	public common count	0			;# Int: Counter of object instances
	public common bgcolor	{#EEEE55}		;# Color: Background color for title bar and window border
	public common bgcolor2	{#FFFF88}		;# Color: Background color for the canvas widget
	# Font: For inserted text
	public common canvas_text_font [font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight bold					\
	]
	# List: Popup menu for the canvas widget
	public common MENU {
		{radiobutton	"Pencil"	{}	::Notes::__mode		{P}
			"change_mode P"		0}
		{radiobutton	"Line"		{}	::Notes::__mode		{L}
			"change_mode L"		0}
		{radiobutton	"Arrow"		{}	::Notes::__mode		{A}
			"change_mode A"		0}
		{radiobutton	"Rectangle"	{}	::Notes::__mode		{R}
			"change_mode R"		0}
		{radiobutton	"Oval"		{}	::Notes::__mode		{O}
			"change_mode O"		0}
		{radiobutton	"Insert text"	{}	::Notes::__mode		{T}
			"change_mode T"		0}
		{radiobutton	"Move canvas"	{}	::Notes::__mode		{M}
			"change_mode M"		0}
		{radiobutton	"Eraser"	{}	::Notes::__mode		{C}
			"change_mode C"		0}
		{separator}
		{command	"Zoom in"	""	0	{canvas_zoom_in_from_pmenu}
			{viewmag_in}}
		{command	"Zoom out"	""	0	{canvas_zoom_out_from_pmenu}
			{viewmag_out}}
		{separator}
		{command	"Insert image"	""	0	{load_image}
			{fileimport}}
		{command	"Select color"	""	0	{select_color}
			{colorize}}
		{separator}
		{command	"Clear all"	""	0	{canvas_clear_all}
			{emptytrash}}
	}

	## PRIVATE
	private variable filename			;# String: Nothing yet ...
	private variable geometry			;# Geometry: Window geometry
	private variable win				;# Widget: Dialog window (widget class Frame)

	private variable main_frame			;# Widget: Main window frame
	private variable canvas_widget			;# Widget: Canvas widget for writing notes
	private variable title_bar			;# Widget: Window title bar
	private variable title_label			;# Widget: Label containg text "Scribble notepad"
	private variable close_button			;# Widget: Close button
	private variable coll_exp_but			;# Widget: Shade button
	private variable minim_flag		0	;# Bool: Shaded or not
	private variable allow_raise_win	1	;# Bool: Allows to use command "raise" to force window visibility
	private variable popup_menu_created	0	;# Bool: Canvas widget popup menu has been created
	private variable menu				;# Widget: Popup menu for he canvas widget

	private variable drawing_mode	P		;# Char: Current drawing mode
	private variable selected_color	black		;# Color: Selected drawing color
	private variable loaded_image	{}		;# Image: Image to insert (image object not filename)
	private variable text_to_write	{}		;# String: Text to insert

	private variable click_X			;# Int: Auxiliary variable for storing last position
	private variable click_Y			;# Int: Auxiliary variable for storing last position

	private variable max_X				;# Int: Auxiliary variable for storing max. allowed position
	private variable max_Y				;# Int: Auxiliary variable for storing max. allowed position

	private variable mode_pen_but			;# Widget: Button "Pencil" mode
	private variable mode_line_but			;# Widget: Button "Line" mode
	private variable mode_arrow_but			;# Widget: Button "Arrow" mode
	private variable mode_rectangle_but		;# Widget: Button "Rectangle" mode
	private variable mode_oval_but			;# Widget: Button "Oval" mode
	private variable mode_text_but			;# Widget: Button "Insert text" mode
	private variable mode_clear_but			;# Widget: Button "Eraser" mode
	private variable load_image_but			;# Widget: Button "Import image"
	private variable select_color_but		;# Widget: Button "Select color"
	private variable move_but			;# Widget: Button "Move canvas" mode
	private variable flag_modified		0	;# Bool: Flag modified

	## contructor
	 # @parm String _file_name	- (Nothing yet)
	 # @parm List _geometry		- {X Y W H}
	constructor {_file_name _geometry} {
		incr count

		set filename $_file_name
		if {$_geometry == {}} {
			set geometry {50 50 300 300}
		} else {
			set geometry $_geometry
		}

		# Configure specific ttk styles
		ttk::style configure Notes.TButton	\
			-padding 0			\
			-background $bgcolor
		ttk::style configure Notes_Flat.TButton	\
			-background $bgcolor		\
			-padding 0			\
			-borderwidth 1			\
			-relief flat
		ttk::style map Notes_Flat.TButton	\
			-relief [list active raised]	\
			-background [list disabled ${::COMMON_BG_COLOR}]

		create_win
	}

	destructor {
		destroy $win
	}

	## Close the window
	 # @return void
	public method close {} {
		if {$flag_modified} {
			if {[tk_messageBox		\
				-type yesno		\
				-icon question		\
				-parent $win		\
				-title [mc "Really close ?"] \
				-message [mc "Do you really want to close your notes ? (There is no save function ...)"]	\
			] != {yes}} then {
				return
			}
		}
		delete object $this
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

		focus $title_label
		$title_label	configure -cursor fleur
	}

	## Event handler: title bar <ButtonRelease-1>
	 # @return void
	public method title_B1_release {} {
		$title_label	configure -cursor left_ptr
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

	## Event handler: right bottom corner <Button-1>
	 # @return void
	public method resize_B1 {} {
		set click_X [expr {-[winfo x $win] - [winfo x .]}]
		set click_Y [expr {-[winfo y $win] - [winfo y .]}]

		set max_X [expr {[winfo width .]  + [winfo x .]}]
		set max_Y [expr {[winfo height .] + [winfo y .]}]
	}

	## Event handler: right bottom corner <B1-Motion>
	 # @parm Int x - Absolute X coordinate
	 # @parm Int y - Absolute Y coordinate
	 # @return void
	public method resize_B1_motion {x y} {
		set _x $x
		set _y $y
		incr x $click_X
		incr y $click_Y

		if {$x < 200 || $_x > $max_X} {
			set x [winfo width $win]
		}
		if {$y < 200 || $_y > $max_Y} {
			set y [winfo height $win]
		}
		place $win -width $x -height $y
	}

	## Change drawing mode
	 # @parm Char mode - New mode
	 #	A - Arrow
	 #	C - Eraser
	 #	T - Insert text
	 #	O - Oval
	 #	R - Rectangle
	 #	L - Line
	 #	P - Pencil
	 #	I - Insert image
	 #	M - Move canvas
	 # @return void
	public method change_mode {mode} {
		# Local variables
		set drawing_mode_org $drawing_mode

		# Object variables
		set drawing_mode $mode

		# Bring toolbar buttons to default states
		foreach w [list							\
			$mode_pen_but		$mode_line_but	$mode_arrow_but	\
			$mode_rectangle_but	$mode_oval_but	$mode_text_but	\
			$mode_clear_but		$load_image_but	$move_but	\
		] {
			$w configure -style Notes_Flat.TButton
		}

		# Switch drawing mode
		set w {}
		switch -- $drawing_mode {
			A {	;# Arrow
				$canvas_widget configure -cursor cross
				set w $mode_arrow_but
			}
			C {	;# Eraser
				$canvas_widget configure -cursor left_ptr
				set w $mode_clear_but
			}
			T {	;# Insert text
				if {[prompt_for_text]} {
					$canvas_widget configure -cursor cross
					set w $mode_text_but
				} else {
					if {$drawing_mode_org == {T}} {
						set drawing_mode_org {M}
					}
					change_mode $drawing_mode_org
				}
			}
			O {	;# Draw oval
				$canvas_widget configure -cursor cross
				set w $mode_oval_but
			}
			R {	;# Draw rectangle
				$canvas_widget configure -cursor cross
				set w $mode_rectangle_but
			}
			L {	;# Draw line
				$canvas_widget configure -cursor cross
				set w $mode_line_but
			}
			P {	;# Pencil
				$canvas_widget configure -cursor pencil
				set w $mode_pen_but
			}
			I {	;# Insert image
				$canvas_widget configure -cursor cross
				set w $load_image_but
			}
			M {	;# Move canvas
				$canvas_widget configure -cursor fleur
				set w $move_but
			}
		}

		# Highlight toolbar button belonging to the selected mode
		if {$w != {}} {
			$w configure -style Notes.TButton
		}
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
			pack $main_frame -fill both -expand 1 -padx 2 -pady 2
			place $win -height [expr {[lindex $geometry 3] + 2}]
		}
		$coll_exp_but configure -image ::ICONS::16::$image
	}

	## Create popup menu
	 # @return void
	private method create_popup_menu {} {
		if {$popup_menu_created} {return}
		set popup_menu_created 1

		set menu $canvas_widget.menu
		menuFactory $MENU $menu 0 "$this " 0 {} [namespace current]
	}

	## Popup menu
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @parm Int X - Absolute X coordinate
	 # @parm Int Y - Absolute Y coordinate
	 # @return void
	public method popup_menu {x y X Y} {
		create_popup_menu
		set ::Notes::__mode $drawing_mode
		set ::Notes::_menu_x $x
		set ::Notes::_menu_y $y

		tk_popup $menu $X $Y
		focus $title_label
	}

	## Zoom in canvas contents from the specified coordinates
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method canvas_zoom_in {x y} {
		$canvas_widget scale all $x $y 1.5 1.5
	}

	## Zoom out canvas contents from the specified coordinates
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method canvas_zoom_out {x y} {
		$canvas_widget scale all $x $y 0.75 0.75
	}

	## Zoom in canvas contents (from popup menu)
	 # @return void
	public method canvas_zoom_in_from_pmenu {} {
		canvas_zoom_in $::Notes::_menu_x $::Notes::_menu_y
	}

	## Zoom out canvas contents (from popup menu)
	 # @return void
	public method canvas_zoom_out_from_pmenu {} {
		canvas_zoom_out $::Notes::_menu_x $::Notes::_menu_y
	}

	## Create notepad window
	 # @return void
	private method create_win {} {
		# Create window frame
		set win [frame .notes$count -bd 1 -relief raised -bg $bgcolor]

		## Create title bar
		 # - Title bar frame
		set title_bar [frame $win.title_bar -bg $bgcolor]
		set title_label [label $title_bar.text	\
			-bg $bgcolor -compound left	\
			-text [mc "Scribble notepad"]	\
			-image ::ICONS::16::pencil	\
			-pady 0				\
		]
		 # - Button "Close"
		set close_button [ttk::button $title_bar.close_but	\
			-style Notes_Flat.TButton			\
			-command "$this close"				\
			-image ::ICONS::16::button_cancel		\
			-takefocus 0					\
		]
		DynamicHelp::add $title_bar.close_but -text [mc "Close"]
		setStatusTip -widget $close_button -text [mc "Close"]
		 # - Button "Shade"
		set coll_exp_but [ttk::button $title_bar.col_exp_but	\
			-style Notes_Flat.TButton			\
			-command "$this collapse_expand"		\
			-image ::ICONS::16::_1uparrow			\
			-takefocus 0					\
		]
		DynamicHelp::add $title_bar.col_exp_but -text [mc "Shade"]
		setStatusTip -widget $coll_exp_but -text [mc "Shade"]
		 # Pack buttons
		pack $coll_exp_but -padx 5 -side left -pady 0 -ipady 0
		pack $title_label -side left -fill x -pady 0 -ipady 0 -expand 1
		pack $close_button -side right -pady 0 -ipady 0 -padx 3
		 # Set title bar event bindings
		bind $title_label <Double-1> "$this collapse_expand"
		bind $title_label <Button-1> "$this title_B1 %X %Y"
		bind $title_label <B1-Motion> "$this title_B1_motion %X %Y"
		bind $title_label <ButtonRelease-1>  "$this title_B1_release"

		## Create main frame
		set main_frame  [frame $win.main_frame -bg $bgcolor2]
		set canvas_widget [canvas $main_frame.canvas	\
			-bg $bgcolor2 -highlightthickness 0	\
			-width 0 -height 0 -bd 0		\
		]
		bind $canvas_widget <Button-1> "$this canvas_B1 %x %y"
		bind $canvas_widget <B1-Motion> "$this canvas_B1_motion %x %y"
		bind $canvas_widget <Motion> "$this canvas_motion %x %y"
		bind $canvas_widget <ButtonRelease-1> "$this canvas_B1_release %x %y"
		bind $canvas_widget <ButtonRelease-3> "$this popup_menu %x %y %X %Y"
		bind $canvas_widget <Leave> "$this canvas_leave"
		bind $canvas_widget <Enter> "$this canvas_enter %x %y"

		bind $canvas_widget <Button-4> "$this canvas_zoom_in %x %y"
		bind $canvas_widget <Button-5> "$this canvas_zoom_out %x %y"

		## Create bottom frame
		 # Create the frame
		set bottom_frame [frame $main_frame.bottom_frame -bg $bgcolor]
		 # - Resizing corner
		pack [label $bottom_frame.resize	\
			-bg $bgcolor -cursor lr_angle	\
			-image ::ICONS::16::corner	\
		] -side right
		 # - Set event bindings for the resizing corner
		bind $bottom_frame.resize <Button-1> "$this resize_B1"
		bind $bottom_frame.resize <B1-Motion> "$this resize_B1_motion %X %Y"
		 # - Button "Pencil"
		set mode_pen_but [ttk::button $bottom_frame.mode_pen_but	\
			-command "$this change_mode P"				\
			-image ::ICONS::16::pencil				\
		]
		DynamicHelp::add $bottom_frame.mode_pen_but -text [mc "Pencil"]
		setStatusTip -widget $mode_pen_but -text [mc "Pencil"]
		pack $mode_pen_but -side left -ipady 0
		 # - Button "Line"
		set mode_line_but [ttk::button $bottom_frame.mode_line_but	\
			-command "$this change_mode L"				\
			-image ::ICONS::16::line				\
		]
		DynamicHelp::add $bottom_frame.mode_line_but -text [mc "Line"]
		setStatusTip -widget $mode_line_but -text [mc "Draw lines"]
		pack $mode_line_but -side left -ipady 0
		 # - Button "Arrow"
		set mode_arrow_but [ttk::button $bottom_frame.mode_arrow_but	\
			-command "$this change_mode A"				\
			-image ::ICONS::16::arr					\
		]
		DynamicHelp::add $bottom_frame.mode_arrow_but -text [mc "Arrow"]
		setStatusTip -widget $mode_arrow_but -text [mc "Draw arrows"]
		pack $mode_arrow_but -side left -ipady 0
		 # - Button "Retangle"
		set mode_rectangle_but [ttk::button $bottom_frame.mode_rectangle_but	\
			-command "$this change_mode R"					\
			-image ::ICONS::16::grid1					\
		]
		DynamicHelp::add $bottom_frame.mode_rectangle_but -text [mc "Retangle"]
		setStatusTip -widget $mode_rectangle_but -text [mc "Draw rectangles"]
		pack $mode_rectangle_but -side left -ipady 0
		 # - Button "Oval"
		set mode_oval_but [ttk::button $bottom_frame.mode_oval_but	\
			-command "$this change_mode O"				\
			-image ::ICONS::16::oval				\
		]
		DynamicHelp::add $bottom_frame.mode_oval_but -text [mc "Oval"]
		setStatusTip -widget $mode_oval_but -text [mc "Draw ovals"]
		pack $mode_oval_but -side left -ipady 0
		 # - Button "Insert text"
		set mode_text_but [ttk::button $bottom_frame.mode_text_but	\
			-command "$this change_mode T"				\
			-image ::ICONS::16::editclear				\
		]
		DynamicHelp::add $bottom_frame.mode_text_but -text [mc "Insert text"]
		setStatusTip -widget $mode_text_but -text [mc "Insert text"]
		pack $mode_text_but -side left -ipady 0
		 # - Button "Move"
		set move_but [ttk::button $bottom_frame.move_but		\
			-command "$this change_mode M"				\
			-image ::ICONS::16::mouse				\
		]
		DynamicHelp::add $bottom_frame.move_but -text [mc "Move"]
		setStatusTip -widget $move_but -text [mc "Move"]
		pack $move_but -side left -ipady 0
		 # - Button "Eraser"
		set mode_clear_but [ttk::button $bottom_frame.mode_clear_but	\
			-command "$this change_mode C"				\
			-image ::ICONS::16::eraser				\
		]
		DynamicHelp::add $bottom_frame.mode_clear_but -text [mc "Eraser"]
		setStatusTip -widget $mode_clear_but -text [mc "Eraser"]
		pack $mode_clear_but -side left -ipady 0
		 # - Button "Select color"
		set select_color_but [button $bottom_frame.select_color_but	\
			-command "$this select_color"		\
			-bd 1 -relief raised -overrelief raised	\
			-activebackground $selected_color	\
			-bg $selected_color -pady 0 -width 2	\
		]
		DynamicHelp::add $bottom_frame.select_color_but -text [mc "Select color"]
		setStatusTip -widget $select_color_but -text [mc "Select color"]
		pack $select_color_but -side right -ipady 0 -pady 0 -padx 8
		 # - Button "Insert image"
		set load_image_but [ttk::button $bottom_frame.load_image_but	\
			-command "$this load_image"				\
			-image ::ICONS::16::fileimport				\
		]
		DynamicHelp::add $bottom_frame.load_image_but -text [mc "Insert image"]
		setStatusTip -widget $load_image_but -text [mc "Insert image"]
		pack $load_image_but -side right -ipady 0
		 # - Button "Clear all"
		set clear_all_but [ttk::button $bottom_frame.clear_all_but	\
			-command "$this canvas_clear_all"		\
			-image ::ICONS::16::emptytrash			\
		]
		DynamicHelp::add $bottom_frame.clear_all_but -text [mc "Clear all"]
		setStatusTip -widget $clear_all_but -text [mc "Clear all"]
		pack $clear_all_but -side right -ipady 0
		 # - Separator
		pack [ttk::separator $bottom_frame.sep0	\
			-orient vertical		\
		] -fill y -padx 5 -side right
		 # Restore default states of buttons on the bottom bar
		foreach w [list							\
			$mode_pen_but		$mode_line_but	$mode_arrow_but	\
			$mode_rectangle_but	$mode_oval_but	$mode_text_but	\
			$mode_clear_but		$load_image_but	$clear_all_but	\
			$move_but						\
		] {
			$w configure -style Notes_Flat.TButton
		}

		# Pack all components of the window
		pack $title_bar -fill x
		pack $canvas_widget -fill both -expand 1
		pack $bottom_frame -fill x -side bottom
		pack $main_frame -fill both -expand 1 -padx 2 -pady 2

		# Set default drawing mode
		change_mode P

		# Show the window
		bind $win <Visibility> "$this raise_win"
		place $win				\
			-x [lindex $geometry 0]		\
			-y [lindex $geometry 1]		\
			-width [lindex $geometry 2]	\
			-height [lindex $geometry 3]	\
			-anchor nw
		raise $win
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

	## Prompt user for text to insert to the canvas
	 # @return void
	private method prompt_for_text {} {
		set ::Notes::text_prompt_text {}
		set dialog [toplevel .notes_pd -bg ${::COMMON_BG_COLOR}]

		## Create top frame
		set frame [frame $dialog.frm]
		 # - Label "Text"
		pack [label $frame.lbl		\
			-text [mc "Text:"]	\
		] -side left
		 # - EntryBox
		set entry [ttk::entry $frame.text_entry		\
			-textvariable ::Notes::text_prompt_text	\
			-width 30				\
		]
		 # Pack them
		pack $entry -side left -fill x -expand 1
		pack $frame -padx 5 -pady 5 -fill x -expand 1
		 # Set events bindings
		bind $entry <Return> "
			grab release $dialog
			destroy $dialog
		"
		bind $entry <Escape> "
			set ::Notes::text_prompt_text {}
			grab release $dialog
			destroy $dialog
		"

		## Create bottom frame
		set frame [frame $dialog.frm_b]
		 # - Button "Cancel"
		pack [ttk::button $dialog.cancel_button		\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-text [mc "Cancel"]			\
			-command "
				set ::Notes::text_prompt_text {}
				grab release $dialog
				destroy $dialog
			"	\
		] -side right
		 # - Button "Ok"
		pack [ttk::button $dialog.ok_button	\
			-compound left		\
			-image ::ICONS::16::ok	\
			-text [mc "Ok"]		\
			-command "
				grab release $dialog
				destroy $dialog
			"	\
		] -side right
		pack $frame -pady 5 -padx 5 -fill x

		wm title $dialog [mc "Enter text"]
		wm transient $dialog .
		wm geometry $dialog =250x70+[expr {[winfo screenwidth $win] / 2 - 250}]+[expr {[winfo screenheight $win] / 2 - 70}]
		update
		focus -force $entry
		grab $dialog
		raise $dialog
		tkwait window $dialog

		set text_to_write ${::Notes::text_prompt_text}
		return [string length $text_to_write]
	}

	## Event handler: canvas <Enter>
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method canvas_enter {x y} {
		switch -- $drawing_mode {
			T {	;# Insert text
				$canvas_widget create text $x $y -text $text_to_write -anchor w -tags incomplete -font $canvas_text_font -fill $selected_color
			}
			I {	;# Import image
				$canvas_widget create image $x $y -image $loaded_image -tags incomplete
			}
		}
	}

	## Event handler: canvas <Button-1>
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method canvas_B1 {x y} {
		set click_X $x
		set click_Y $y

		switch -- $drawing_mode {
			C {	;# Eraser
				set flag_modified 1
				$canvas_widget create rectangle			\
					[expr {$x - 10}] [expr {$y - 10}]	\
					[expr {$x + 10}] [expr {$y + 10}]	\
					-outline $bgcolor2 -fill $bgcolor2
			}
			T {	;# Insert text
				set flag_modified 1
				$canvas_widget dtag incomplete incomplete
				$canvas_widget create text $x $y -text $text_to_write -anchor w -tags incomplete -font $canvas_text_font -fill $selected_color
			}
			I {	;# Import image
				set flag_modified 1
				$canvas_widget dtag incomplete incomplete
				$canvas_widget create image $x $y -image $loaded_image -tags incomplete
			}
		}

		focus $canvas_widget
	}

	## Event handler: canvas <Motion>
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method canvas_motion {x y} {
		switch -- $drawing_mode {
			C {	;# Eraser
				$canvas_widget delete incomplete
				$canvas_widget create rectangle		\
					[expr {$x - 10}] [expr {$y - 10}]	\
					[expr {$x + 10}] [expr {$y + 10}]	\
					-tag incomplete -outline #FF0000
			}
			T {	;# Insert text
				$canvas_widget coords incomplete $x $y
			}
			I {	;# Import image
				$canvas_widget coords incomplete $x $y
			}
		}
	}

	## Event handler: canvas <B1-Motion>
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method canvas_B1_motion {x y} {
		$canvas_widget delete incomplete
		switch -- $drawing_mode {
			C {	;# Eraser
				set flag_modified 1
				$canvas_widget create rectangle			\
					[expr {$x - 10}] [expr {$y - 10}]	\
					[expr {$x + 10}] [expr {$y + 10}]	\
					-outline $bgcolor2 -fill $bgcolor2
				$canvas_widget create rectangle			\
					[expr {$x - 10}] [expr {$y - 10}]	\
					[expr {$x + 10}] [expr {$y + 10}]	\
					-tag incomplete -outline #FF0000
			}
			T {	;# Insert text
				if {![llength [$canvas_widget find withtag incomplete]]} {
					$canvas_widget create text $x $y -text $text_to_write -anchor w -tags incomplete -font $canvas_text_font -fill $selected_color
				}
				$canvas_widget coords incomplete $x $y
			}
			O {	;# Draw oval
				$canvas_widget create oval $click_X $click_Y $x $y -tag incomplete -dash {_} -outline $selected_color
			}
			R {	;# Draw rectangle
				$canvas_widget create rectangle $click_X $click_Y $x $y -tag incomplete -dash {_} -outline $selected_color
			}
			L {	;# Draw line
				$canvas_widget create line $click_X $click_Y $x $y -tag incomplete -dash {_} -fill $selected_color
			}
			P {	;# Pencil
				set flag_modified 1
				$canvas_widget create line $click_X $click_Y $x $y -fill $selected_color
				set click_X $x
				set click_Y $y
			}
			A {	;# Draw arrow
				$canvas_widget create line $click_X $click_Y $x $y -tag incomplete -dash {_} -arrow last -fill $selected_color
			}
			I {	;# Import image
				if {![llength [$canvas_widget find withtag incomplete]]} {
					$canvas_widget create image $x $y -image $loaded_image -tags incomplete
				}
				$canvas_widget coords incomplete $x $y
			}
			M {	;# Move canvas
				$canvas_widget move all [expr {$x - $click_X}] [expr {$y - $click_Y}]

				set click_X $x
				set click_Y $y
			}
		}
	}

	## Event handler: canvas <ButtonRelease-1>
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method canvas_B1_release {x y} {
		switch -- $drawing_mode {
			O {	;# Draw oval
				set flag_modified 1
				$canvas_widget itemconfigure incomplete -dash {} -outline $selected_color
				$canvas_widget dtag incomplete incomplete
			}
			R {	;# Draw rectangle
				set flag_modified 1
				$canvas_widget itemconfigure incomplete -dash {} -outline $selected_color
				$canvas_widget dtag incomplete incomplete
			}
			L {	;# Draw line
				set flag_modified 1
				$canvas_widget itemconfigure incomplete -dash {} -fill $selected_color
				$canvas_widget dtag incomplete incomplete
			}
			A {	;# Draw arrow
				set flag_modified 1
				$canvas_widget itemconfigure incomplete -dash {} -fill $selected_color
				$canvas_widget dtag incomplete incomplete
			}
		}
	}

	## Event handler: canvas <Leave>
	 # @return void
	public method canvas_leave {} {
		$canvas_widget delete incomplete
	}

	## Completely clear the canvas
	 # @return void
	public method canvas_clear_all {} {
		if {[tk_messageBox		\
			-parent .		\
			-type yesno		\
			-icon question		\
			-title [mc "Are you sure ?"]	\
			-message [mc "Do you really want to clear this notepad\n(there is no undo action)"]	\
		] != {yes}} {
			return
		}
		$canvas_widget delete all
	}

	## Select drawing color
	 # @return void
	public method select_color {} {
		set color [SelectColor .select_color	\
			-parent .			\
			-color $selected_color		\
			-title [mc "Select color"]	\
		]

		if {$color != {}} {
			set selected_color $color
			$select_color_but configure -bg $color -activebackground $color
		}
	}

	## Select image file to import
	 # @return void
	public method load_image {} {
		catch {delete object ::fsd}

		set directory {}
		catch {
			set directory [$::X::actualProject cget -projectPath]
		}

		KIFSD::FSD ::fsd				\
			-directory $directory			\
			-title [mc "Insert image from file"]	\
			-defaultmask 0 -multiple 0 -filetypes [list			\
				[list [mc "Portable network graphics"]	{*.png}	]	\
				[list [mc "All files"]			{*}	]	\
			]

		::fsd setokcmd "$this load_image_file \[::fsd get\]"
		::fsd activate
	}

	## Import image from file
	 # @parm String file - Full file name
	 # @return void
	public method load_image_file {file} {
		set loaded_image {}
		if {[catch {
			set loaded_image [image create photo -file $file]
		}]} then {
			tk_messageBox			\
				-parent .		\
				-type ok		\
				-icon warning		\
				-title [mc "Unable to read file"]	\
				-message [mc "Unable to read file:\n%s" $file]
			return
		}

		if {$loaded_image != {}} {
			change_mode I
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

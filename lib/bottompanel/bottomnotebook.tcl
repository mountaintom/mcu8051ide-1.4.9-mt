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
if { ! [ info exists _BOTTOMNOTEBOOK_TCL ] } {
set _BOTTOMNOTEBOOK_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements bottom panel of the project tab
# --------------------------------------------------------------------------

# Import nesesary sources
source "${::LIB_DIRNAME}/bottompanel/calculator.tcl"	;# Calculator
source "${::LIB_DIRNAME}/bottompanel/todo.tcl"		;# Todo list
source "${::LIB_DIRNAME}/bottompanel/graph.tcl"		;# Graph
source "${::LIB_DIRNAME}/bottompanel/messages.tcl"	;# Messages
source "${::LIB_DIRNAME}/bottompanel/terminal.tcl"	;# Terminal
source "${::LIB_DIRNAME}/bottompanel/find_in_files.tcl"	;# Find in files
source "${::LIB_DIRNAME}/bottompanel/cvarsview.tcl"	;# C variables

class BottomNoteBook {

	# Inherit content of some other clases
	inherit Calculator Todo Simulator Graph Messages Terminal FindInFiles CVarsView

	## Public
	public variable simulator_frame		;# Identifier of tab of NoteBook widget for simulator
	public variable cvarsview_frame		;# Identifier of tab of NoteBook widget for c variables
	public variable graph_frame		;# Identifier of tab of NoteBook widget for graph
	public variable messages_frame		;# Identifier of tab of NoteBook widget for messages box
	public variable todo_frame		;# Identifier of tab of NoteBook widget for to do box
	public variable calculator_frame	;# Identifier of tab of NoteBook widget for calculator
	public variable terminal_frame		;# Identifier of tab of NoteBook widget for terminal
	public variable findinfiles_frame	;# Identifier of tab of NoteBook widget for terminal

	## Private
	private variable pri_notebook		;# Identifier of NoteBook widget when panel is visible
	private variable main_frame		;# Identifier of frame containing both NoteBooks

	private variable panel_hidding_ena		1	;# Is panel hidding enabled
	private variable redraw_pane_in_progress	0	;# Is panel pane redraw in progress
	private variable parentPane				;# Identifier of parent pane
	private variable last_PanelSize				;# Last panel height
	private variable PanelVisible	$CONFIG(BOTTOM_PANEL)			;# Is panel visible
	private variable active_page	$CONFIG(BOTTOM_PANEL_ACTIVE_PAGE)	;# Identifier of active NoteBook page
	private variable PanelSize	$CONFIG(BOTTOM_PANEL_SIZE)		;# Current panel height

	## object constructor
	constructor {} {
		# Validate and set active page
		if {$active_page == {Terminal}} {
			set active_page {Simulator}
		} elseif {
			[lsearch {Simulator CVarsView Graph Messages Todo Calculator FindInFiles} $active_page] == -1
		} then {
			puts stderr "Invalid value of active page '$active_page', setting to {Simulator}"
			set active_page {Simulator}
		}
	}

	## object destructor
	destructor {
		# Destroy GUI
		destroy $main_frame
		notebook_Sbar_unset {bottomnb}
	}

	## Create Bottom NoteBook (This function must be called after contructor)
	 # @parm widget mainframe	- Frame for bottom notebook
	 # @parm widget PaneWindow	- parent pane window contaier
	 # @parm String todoText	- content of to do text
	 # @parm List calculatorList	- List of values for calculator (display content, radix, etc.)
	 # @parm List graph_config	- Graph configuration list
	 # @return Widget - ID of frame containg both notebooks
	public method initalize_BottomNoteBook {mainframe PaneWindow todoText calculatorList graph_config} {

		# set parent pane window
		set parentPane $PaneWindow

		## Create some widgets
		# Frame for primary and secondary notebook
		set main_frame $mainframe
		# Primary notebook
		set pri_notebook [ModernNoteBook $main_frame.ntb_bottomNB_pri]

		# Register notebook status bar tips
		notebook_Sbar_set {bottomnb} [list					\
			Simulator	[mc "Simulator panel"]				\
			CVarsView	[mc "List of variables defined in C program"]	\
			Graph		[mc "Graph showing voltage levels"]		\
			Messages	[mc "Compiler messages"]			\
			Todo		[mc "Editable notepad"]				\
			Calculator	[mc "Scientific calculator"]			\
			Terminal	[mc "Linux terminal emulator"]			\
			FindInFiles	[mc "Search string in files"]			\
			Hide		[mc "Hide the panel"]				\
			Show		[mc "Show the panel"]				\
		]
		$pri_notebook bindtabs <Enter> "notebook_Sbar bottomnb"
		$pri_notebook bindtabs <Leave> "Sbar {} ;#"

		## create Primary NoteBook tabs
		# Tab "Simulator"
		set simulator_frame	[$pri_notebook insert end {Simulator}		\
			-text [mc "Simulator"]						\
			-image ::ICONS::16::kcmmemory					\
			-raisecmd [list $this bottomNB_set_active_page {Simulator}]	\
			-helptext [mc "Simulator panel %s" "(Ctrl+1)"]			\
			-createcmd [list $this CreateSimulatorGUI]			\
		]
		# Tab "C variables"
		set cvarsview_frame	[$pri_notebook insert end {CVarsView}		\
			-text [mc "C variables"]					\
			-image ::ICONS::16::player_playlist				\
			-raisecmd [list $this bottomNB_set_active_page {CVarsView}]	\
			-helptext [mc "Variables from C source code %s" ""]		\
			-createcmd [list $this CreateCVarsViewGUI]			\
		]
		# Tab "Graph"
		set graph_frame	[$pri_notebook insert end {Graph}		\
			-text [mc "IO Ports"]					\
			-image ::ICONS::16::graph				\
			-raisecmd [list $this bottomNB_set_active_page {Graph}]	\
			-helptext [mc "Graph showing state of MCU ports %s" "(Ctrl+2)"]	\
			-createcmd [list $this CreateGraphGUI]			\
		]
		# Tab "Messages"
		set messages_frame	[$pri_notebook insert end {Messages}		\
			-text [mc "Messages"]						\
			-image ::ICONS::16::kcmsystem					\
			-raisecmd [list $this bottomNB_set_active_page {Messages}]	\
			-helptext [mc "Compiler messages %s" "(Ctrl+3)"]		\
			-createcmd [list $this CreateMessagesGUI]			\
			-leavecmd "
				$pri_notebook itemconfigure {Messages} -image ::ICONS::16::kcmsystem
			"	\
		]
		# Tab "Notes"
		set todo_frame		[$pri_notebook insert end {Todo} 	\
			-text [mc "Notes"]					\
			-image ::ICONS::16::camera_test				\
			-raisecmd [list $this bottomNB_set_active_page {Todo}]	\
			-helptext [mc "Personal to do list & notepad %s" "(Ctrl+4)"]\
			-createcmd [list $this CreateTodoGUI]			\
		]
		# Tab "Calculator"
		set calculator_frame	[$pri_notebook insert end {Calculator}		\
			-text [mc "Calculator"]						\
			-image ::ICONS::16::xcalc					\
			-raisecmd [list $this bottomNB_set_active_page {Calculator}]	\
			-helptext [mc "Scientific calculator %s" "(Ctrl+5)"]		\
			-createcmd [list $this CreateCalculatorGUI]			\
		]
		if {!$::MICROSOFT_WINDOWS} {	;# Microsoft Windows has no terminal emulator
			# Tab "Terminal"
			set terminal_frame	[$pri_notebook insert end {Terminal}		\
				-text [mc "Terminal"]						\
				-image ::ICONS::16::terminal					\
				-raisecmd [list $this bottomNB_set_active_page {Terminal}]	\
				-helptext [mc "Terminal emulator %s" ""]			\
				-createcmd [list $this CreateTerminalEmulGUI]			\
				-state [expr {${::PROGRAM_AVAILABLE(urxvt)} ? "normal" : "disabled"}]	\
			]
		}
		# Tab "Find in files"
		set findinfiles_frame	[$pri_notebook insert end {FindInFiles}		\
			-text [mc "Find in files"]					\
			-image ::ICONS::16::filefind					\
			-raisecmd [list $this bottomNB_set_active_page {FindInFiles}]	\
			-helptext [mc "Find in files %s" ""]				\
			-createcmd [list $this CreateFindInFilesGUI]			\
		]

		# Tab "Hide"
		$pri_notebook insert end {Hide}				\
			-text [mc "Hide"]				\
			-image ::ICONS::16::2downarrow			\
			-raisecmd [list $this bottomNB_show_hide]	\
			-helptext [mc "Hide this panel"]		\

		# Prepare panel componenets but do not create GUI elements
		PrepareCalculator	$calculator_frame	$calculatorList
		PrepareGraph		$graph_frame		$graph_config
		PrepareMessages		$messages_frame
		PrepareTodo		$todo_frame		$todoText

		PrepareSimulator	$simulator_frame
		PrepareCVarsView	$cvarsview_frame
		if {!$::MICROSOFT_WINDOWS} {	;# Microsoft Windows has no terminal emulator
			PrepareTerminal		$terminal_frame
		}
		PrepareFindInFiles	$findinfiles_frame

		# take case of proper pane resizing
		bind $parentPane <ButtonRelease-1> "$this bottomNB_panel_set_size"

		# Show primary notebook if panel is visible or secondary notebook ohterwise
		pack [$pri_notebook get_nb] -expand 1 -fill both -padx 5 -pady 5
		if {$PanelVisible != 0} {
			$parentPane paneconfigure $main_frame -minsize 215
			$parentPane configure -sashwidth 4

			# Raise tab
			catch {$pri_notebook raise $active_page}
		} else {
			$pri_notebook hide_pages_area
			$pri_notebook deselect_tab_button
			$pri_notebook itemconfigure {Hide}			\
				-text [mc "Show"]				\
				-image ::ICONS::16::2uparrow			\
				-helptext [mc "Show this panel"]

			$parentPane paneconfigure $main_frame -minsize 0
			$parentPane configure -sashwidth 0
			bind $parentPane <Button> {break}
			set last_PanelSize $PanelSize
			set PanelSize 34
		}
	}

	## Return true if the panel is visible
	 # @return bool result
	public method isBottomPanelVisible	{} {return $PanelVisible}

	## Return panel height
	 # @return int panle height
	public method getBottomPanelSize	{} {
		if {$PanelVisible} {
			return $PanelSize
		} else {
			return $last_PanelSize
		}
	}

	## Return ID of active page of the NoteBook
	 # @return String Active page
	public method getBottomPanelActivePage	{} {return $active_page}

	## Set active page for both notebooks (primary and secondary)
	 # This function may also inform GUI of new active page about that it has became active
	 # @parm String pageName - ID of page to set
	 # @return void
	public method bottomNB_set_active_page {pageName} {
		switch -- $pageName {
			Simulator	{$this SimulatorTabRaised}
			CVarsView	{$this CVarsViewTabRaised}
			Graph		{$this GraphTabRaised}
			Messages	{$this MessagesTabRaised}
			Todo		{$this TodoTabRaised}
			Calculator	{$this CalculatorTabRaised}
			FindInFiles	{$this FindInFilesTabRaised}
		}
		if {$pageName != {Hide}} {
			set active_page $pageName
		}
		if {!$PanelVisible} {
			bottomNB_show_hide
		}
	}

	## Show or hide the panel
	 # @parm String a_page={} - name of active page (show panel)
	 # @return void
	public method bottomNB_show_hide {{a_page {}}} {

		# If panel hidding is disabled -- abort
		if {!$panel_hidding_ena} {return}

		# Hide the panel
		if {$PanelVisible} {
			$parentPane paneconfigure $main_frame -minsize 0

			$pri_notebook hide_pages_area
			$pri_notebook deselect_tab_button
			$pri_notebook itemconfigure {Hide}			\
				-text [mc "Show"]				\
				-image ::ICONS::16::2uparrow			\
				-helptext [mc "Show this panel"]
			set last_PanelSize $PanelSize	;# Save current panel size
			set PanelSize 34		;# Set New panel size
			bottomNB_redraw_pane		;# Perform hidding

			set panel_hidding_ena 0
			set panel_hidding_ena 1
			$parentPane configure -sashwidth 0
			bind $parentPane <Button> {break}

			# Panel is now hidden
			set PanelVisible 0

		# Show the panel
		} else {
			$parentPane paneconfigure $main_frame -minsize 215

			$pri_notebook show_pages_area
			$pri_notebook itemconfigure {Hide}			\
				-text [mc "Hide"]				\
				-image ::ICONS::16::2downarrow			\
				-helptext [mc "Hide this panel"]

			# Create and show primary notebook
			set PanelSize $last_PanelSize	;# Restore panel size
			bottomNB_redraw_pane		;# Perform showing

			# Raise active page
			if {$a_page == {}} {
				$pri_notebook raise $active_page
			} else {
				$pri_notebook raise $a_page
			}
			# Restore sash width
			$parentPane configure -sashwidth 4
			bind $parentPane <Button> {}

			# Panel is now shown
			set PanelVisible 1
		}

		update idletasks
		$this editor_procedure {} Configure {}
	}

	## Get true panel size and store it into variable PanelSize
	 # @return void
	public method bottomNB_panel_set_size {} {
		set PanelSize [lindex [$parentPane sash coord 0] 1]
		set PanelSize [expr {[winfo height $parentPane] - $PanelSize}]

		update idletasks
		$this editor_procedure {} Configure {}
		$this editor_procedure {} goto	\
			[$this editor_procedure {} get_current_line_number {}]
	}

	## Move panel pane up by the given number of pixels
	 # @parm Int by - pixels
	 # @return void
	public method bottomNB_move_pane_up {by} {
		update idletasks
		$parentPane sash place 0 0 [expr {[winfo height $parentPane] - $PanelSize - $by}]
	}

	## Redraw panel pane
	 # @return  void
	public method bottomNB_redraw_pane {} {
		update idletasks
		catch {
			$parentPane sash place 0 0 [expr {[winfo height $parentPane] - $PanelSize}]
		}
	}

	## Redraw panel pane on expose event
	 # @return  void
	public method bottomNB_redraw_pane_on_expose {} {
		if {$redraw_pane_in_progress} {
			after 50 "$this bottomNB_redraw_pane_on_expose"
			return
		}
		set redraw_pane_in_progress 1

		update idletasks
		$parentPane sash place 0 0 [expr {[winfo height $parentPane] - $PanelSize}]
		update idletasks

		set redraw_pane_in_progress 0
	}

	## Raise specified page
	 # This function should not be bypased
	 # @parm String page - ID of page to show
	 # @return void
	public method bottomNB_show_up {page} {
		if {$PanelVisible} {
			$pri_notebook raise $page
		} else {
			bottomNB_show_hide $page
		}
	}

	## Destroy current simulator control panel and create a new one
	 # @return void
	public method simulator_itialize_simulator_control_panel {} {
		foreach wdg [winfo children $simulator_frame] {
			destroy $wdg
		}
		$this sumulator_clear_widgets
		PrepareSimulator $simulator_frame
		CreateSimulatorGUI
	}

	## Destroy current graph panel and create a new one
	 # @return void
	public method graph_itialize_simulator_graph_panel {graph_config} {
		$this graph_change_mcu
	}

	## Configure particular page on bottom notebook widget
	 # @parm String page	- Page ID
	 # @parm List options	- Any options acceptable by the notebook widget
	 # @return void
	public method bottomnotebook_pageconfigure {page options} {
		eval "$pri_notebook itemconfigure {$page} $options"
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

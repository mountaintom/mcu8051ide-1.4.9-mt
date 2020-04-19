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
if { ! [ info exists _FSD_TCL ] } {
set _FSD_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# This class provides file selection dialog
# Usage:
#	KIFSD::FSD <fsd_object>					;# Create dialog object
#	<fsd_object> setokcmd {set filename [<fsd_object> get]}	;# Set command for Ok button
#	<fsd_object> activate <some_command>			;# Show up the dialog
#
# Constructor options:
#	-title		String = {}	;# Dialog title
#	-initialfile	String = {}	;# Initial file
#	-directory	String = {~}	;# Initiali directory
#	-multiple	Bool = 0	;# Allow selection of multiple files (get will return list instead of string)
#	-filetypes	List = {{All} {*}}	;# { {{Some string} {GLOB}} ... }
#	-defaultmask	Int = 0		;# Number of detault mask (see -filetypes) (1st is zero)
#	-modal		Bool = 1	;# Create as modal window
#	-doubleclick	Bool = 0	;# Use double click to open folder instead of single click
#	-autoclose	Bool = 1	;# Close dialog after pressure of Ok button
#	-master		Widget = .	;# Master window (wm transient $master)
#	-fileson	Bool = 1	;# 1 == Select file(s); 0 == Select directory/ies
#
# Other public methods:
#	set_bookmark_change_command	Command	;# Set command to invoke when bookmarks changes
#	deactivate				;# Deactivate the dialog
#	close_dialog				;# Close dialog window but keep object alive
#	get_config_array	-> List		;# Get dialog configuration array for proc. load_config_array
#	load_config_array List			;# Load dialog configuration array
#	get_window_name		-> Widget	;# Get path to dialog window
# --------------------------------------------------------------------------

itcl::class KIFSD::FSD {

	public common bookmark_change_command	{}	;# Command to invoke on bokmark change
	# Font for quick navigation panel
	public common quick_nav_panel_font	[font create		\
		-family {helvetica}				\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
	]
	# Font for files listbox in mode (Short view)
	public common listbox_font_short	[font create		\
		-family {helvetica}				\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight normal					\
	]
	# Font for files listbox in mode (Detailed view) and directories listbox
	public common listbox_font_detailed	[font create		\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight normal					\
	]
	# Font for listbox header
	public common listbox_header_font	[font create		\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
	]

	## Values given by constructor arguments
	private variable option_title		{Select file}	;# Dialog title
	private variable option_filetypes	{{All} {*}}	;# File types
	if {!$::MICROSOFT_WINDOWS} {
		variable option_directory	${::env(HOME)}		;# Initial directory
	} else {
		variable option_directory	${::env(USERPROFILE)}	;# Initial directory
	}
	private variable option_master		{.}	;# Window master
	private variable option_fileson		{1}	;# 1 == Files on (select file); 0 == Files off (select directory)
	private variable option_doubleclick	{0}	;# Use doble click instead of single clicks
	private variable option_modal		{1}	;# Open dialog windown as modal window
	private variable option_initialfile	{}	;# Initial file
	private variable option_multiple	{0}	;# Allow mulstiple selection
	private variable option_defaultmask	{0}	;# Index of default mask in $option_filetypes
	private variable option_autoclose	{1}	;# 1 == Close dialog after press of Ok button

	private variable bookmark_edit_listbox	{}	;# Widget: ListBox in bookmarks editor
	private variable bookmark_menu		{}	;# Widget: Bookmarks menu
	private variable config_menu		{}	;# Widget: Configuration menu
	private variable listbox_font		{}	;# Font: Current font for files listbox
	private variable current_directory	{}	;# String: Current directory
	private variable back_history		{}	;# List: Backward history
	private variable forward_history	{}	;# List: Forward hitory
	private variable ok_command		{}	;# String: Ok command
	private variable current_mask		{*}	;# GLOB: Current fileter mask
	private variable item_menu_request	0	;# Bool: Item popup menu request
	private variable current_item		{}	;# String: ID of currenly selected item
	private variable current_item_index	0	;# Int: Index of currently selected item
	private variable cur_listbox		{}	;# String currently selected listbox {dir} or {file}

	private variable dialog_loaded		0	;# Bool: Dialog is completely loaded
	private variable win				;# Widget: Dialog window
	private variable ok_button			;# Widget: Button "Ok"
	private variable location_cb			;# Widget: Location ComboBox
	private variable filter_cb			;# Widget: Filter ComboBox
	private variable dir_combobox			;# Widget: Directory ComboBox
	private variable toolbar			;# Widget: Frame containing toolbar
	private variable quick_access_bar		;# Widget: Quick access bar ListBox
	private variable dir_listbox_scrollbar	{}	;# Widget: Directory ListBox scrollbar
	private variable dir_listbox		{}	;# Widget: Directory ListBox
	private variable main_paned_window		;# Widget: Paned window for quick access bar and other LBs
	private variable leftframe			;# Widget: Frame contaning quick access bar and its scrollbar
	private variable rightframe			;# Widget: Frame containing directory & file ListBoxes
 	private variable right_top_right_frame		;# Widget: files ListBox
	private variable right_top_left_frame		;# Widget: Frame for files ListBox
	private variable right_top_frame		;# Widget: Frame for $right_paned_window
	private variable right_paned_window		;# Widget: Paned window for directories ListBox and files ListBox
	private variable file_listbox			;# Widget: Files ListBox
	private variable file_listbox_header		;# Widget: Header for files ListBox
	private variable file_listbox_frame		;# Widget: Frame for $file_listbox_header and $file_listbox
	private variable file_listbox_vscrollbar {}	;# Widget: Vertical scollbar for files ListBox
	private variable file_listbox_hscrollbar {}	;# Widget: Hotizontal scollbar for files ListBox
	private variable right_top_right_top_frame	;# Widget: Frame for $file_listbox_frame and scrollbars

	proc static_reload {object args} {
		catch [list $object reload]
	}

	## Dialog constructor
	 # For complite list of possible arguments see desctiption above
	constructor args {

		# Configure local ttk styles
		ttk::style configure FSD_RedBg.TCombobox -fieldbackground {#FFDDDD}
		ttk::style configure FSD_RedBg.TEntry -fieldbackground {#FFDDDD}

		## Parse given arguments and set appropriate object variables
		set arglen [llength $args]
		set arg {}
		for {set i 0} {$i < $arglen} {incr i} {
			set arg [lindex $args $i]
			switch -- $arg {
				-modal {
					incr i
					set option_modal [lindex $args $i]
					if {![string is boolean -strict $option_modal]} {
						error "-modal must have value either 0 or 1"
					}
				}
				-doubleclick {
					incr i
					set option_doubleclick [lindex $args $i]
					if {![string is boolean -strict $option_doubleclick]} {
						error "-doubleclick must have value either 0 or 1"
					}
				}
				-autoclose {
					incr i
					set option_autoclose [lindex $args $i]
					if {![string is boolean -strict $option_autoclose]} {
						error "-autoclose must have value either 0 or 1"
					}
				}
				-initialfile {
					incr i
					set option_initialfile [lindex $args $i]
				}
				-multiple {
					incr i
					set option_multiple [lindex $args $i]
					if {![string is boolean -strict $option_multiple]} {
						error "-multiple must have value either 0 or 1"
					}
				}
				-defaultmask {
					incr i
					set option_defaultmask [lindex $args $i]
					if {![string is integer -strict $option_defaultmask]} {
						error "-defaultmask must be an integer"
					}
				}
				-title {
					incr i
					set option_title [lindex $args $i]
				}
				-filetypes {
					incr i
					set option_filetypes [lindex $args $i]
				}
				-directory {
					incr i
					set option_directory [lindex $args $i]
				}
				-master {
					incr i
					set option_master [lindex $args $i]
				}
				-fileson {
					incr i
					set option_fileson [lindex $args $i]
					if {![string is boolean -strict $option_modal]} {
						error "-fileson must have value either 0 or 1"
					}
				}
				default {
					error "Option '$arg' is not valid"
				}
			}
		}
		set args {}
		set current_directory [file normalize $option_directory]

		# Cretate dialog window
		create_dialog

		# Initalize window key shortcuts
		create_shortcuts

		# Finalize
		set dialog_loaded 1
	}

	## Destrurtor
	destructor {
		catch {
			# Save position of right paned window sash
			if {[winfo ismapped $right_paned_window]} {
				set ::KIFSD::FSD::config(right_PW_size)	\
					[lindex [$right_paned_window sash coord 0] 0]
			}
			# Save position of main paned window sash
			if {[winfo ismapped $main_paned_window]} {
				set ::KIFSD::FSD::config(main_PW_size)	\
					[lindex [$main_paned_window sash coord 0] 0]
			}
			# Save window geometry
			set ::KIFSD::FSD::config(win_geometry) [wm geometry $win]
		}

		# Destroy dialog window
		grab release $win
		destroy $win
	}

	## Create dialog GUI elements
	 # @return void
	private method create_dialog {} {
		# Determinate window name (path)
		set win_base {}
		if {$option_master != {.}} {
			set win_base $option_master
		}
		append win_base .[string tolower [regsub -all {:} $this {}]]
		set win $win_base
		set i 0
		while [winfo exists $win] {
			set win $win_base
			append win $i
			incr i
		}

		# Create and configure dialog window
		toplevel $win -bg ${::COMMON_BG_COLOR}
		wm iconphoto $win ::ICONS::16::fileopen
		wm withdraw $win
		wm title $win $option_title
		wm minsize $win 540 290
		wm protocol $win WM_DELETE_WINDOW "catch {itcl::delete object $this}"
		wm transient $win $option_master
		wm geometry $win ${::KIFSD::FSD::config(win_geometry)}
		wm resizable $win 0 0
		raise $win
		update
		if {$option_modal} {
			catch {
				grab $win
			}
		}


		create_popup_menus			;# Create popup menus
		set topframe [frame $win.topframe]	;# Create frame above ListBoxes
		set toolbar [frame $topframe.toobar]	;# Create toolbar frame
		create_tool_bar				;# Create toolbar

		# Create directory ComboBox
		set dir_combobox [ttk::combobox $topframe.dir_cb				\
			-values {}								\
			-exportselection 0							\
			-validate all								\
			-validatecommand "::KIFSD::FSD::dir_validate $topframe.dir_cb %W %P"	\
		]
		bind $dir_combobox <<ComboboxSelected>> [list $this dir_cb_modify]
		bind $dir_combobox <KP_Enter> [list $this dir_cb_modify]
		bind $dir_combobox <Return> [list $this dir_cb_modify]

		DynamicHelp::add $dir_combobox -text [mc "Current directory"]
		pack $dir_combobox -side right -expand 1 -fill x -padx 5

		# Create main paned window and some frames
		set mainframe [frame $win.mainframe]
		set main_paned_window [panedwindow $mainframe.main_paned_window	\
			-orient horizontal -opaqueresize 1 -sashwidth 2		\
			-showhandle 0 -sashrelief flat				\
		]
		set leftframe [frame $mainframe.leftframe]
		set rightframe [frame $mainframe.rightframe]

		# Create quick access bar
		set quick_access_bar [ListBox $leftframe.quick_access_bar		\
			-selectfill 1 -selectbackground white -bd 1 -padx 30 -width 15	\
			-selectmode single -highlightthickness 0 -bg white -deltay 30	\
			-selectforeground black -highlightcolor {#BBBBFF}	\
		]
		refresh_quick_access_bar
		$quick_access_bar bindText	<ButtonRelease-3>	[list $this quick_access_bar_item_menu %X %Y	]
		$quick_access_bar bindImage	<ButtonRelease-3>	[list $this quick_access_bar_item_menu %X %Y	]
		$quick_access_bar bindText	<Double-Button-1>	[list $this quick_access_bar_doubleclick	]
		$quick_access_bar bindImage	<Double-Button-1>	[list $this quick_access_bar_doubleclick	]
		bind $quick_access_bar		<<ListboxSelect>>	[list $this quick_access_bar_select		]
		if {[winfo exists $quick_access_bar.c]} {
			bind $quick_access_bar.c <Button-5>		{%W yview scroll +5 units; break}
			bind $quick_access_bar.c <Button-4>		{%W yview scroll -5 units; break}
			bind $quick_access_bar.c <ButtonRelease-3>	[list $this quick_access_bar_menu %X %Y		]
		}
		pack $quick_access_bar -fill both -expand 1

		# Create right paned window
		set right_top_frame [frame $rightframe.topframe]
		set right_bottom_frame [frame $rightframe.bottomframe]
		set right_paned_window [panedwindow $right_top_frame.right_paned_window	\
			-orient horizontal -opaqueresize 1 -sashwidth 2			\
			-showhandle 0 -sashrelief flat					\
		]
		set right_top_left_frame [frame $win.left_frame]
		set right_top_right_frame [frame $win.right_frame]

		# Create directories ListBox
		if {$option_fileson} {
			set dir_listbox [ListBox $right_top_left_frame.dir_listbox		\
				-bd 1 -padx 19 -selectfill 1 -width 1 -highlightcolor {#BBBBFF}	\
				-selectmode single -highlightthickness 0 -bg white -deltay 18	\
				-yscrollcommand "$this dir_listbox_scroll"			\
			]
			set dir_listbox_scrollbar [ttk::scrollbar		\
				$right_top_left_frame.scrollbar			\
				-orient vertical -command "$dir_listbox yview"	\
			]
			$dir_listbox bindText	<Double-Button-1>	[list $this dir_listbox_doubleclick	]
			$dir_listbox bindImage	<Double-Button-1>	[list $this dir_listbox_doubleclick	]
			$dir_listbox bindText	<ButtonRelease-3>	[list $this dir_listbox_item_menu %X %Y	]
			$dir_listbox bindImage	<ButtonRelease-3>	[list $this dir_listbox_item_menu %X %Y	]
			bind $dir_listbox	<<ListboxSelect>>	[list $this dir_listbox_select		]
			if {[winfo exists $dir_listbox.c]} {
				bind $dir_listbox.c <Button-5>		{%W yview scroll +5 units; break}
				bind $dir_listbox.c <Button-4>		{%W yview scroll -5 units; break}
				bind $dir_listbox.c <ButtonRelease-3>	[list $this dir_listbox_menu %X %Y	]
			}
			pack $dir_listbox -side left -fill both -expand 1
		}

		# Create files ListBox
		if {$option_multiple} {
			set selmode {multiple}
		} else {
			set selmode {single}
		}
		set right_top_right_top_frame [frame $right_top_right_frame.right_top_right_top_frame]
		set file_listbox_frame [frame $right_top_right_top_frame.file_listbox_frame]
		set file_listbox_header [text $file_listbox_frame.text	\
			-width 1 -height 1 -takefocus 0 -bg white 	\
			-font $listbox_header_font -bd 1 -relief sunken	\
			-cursor left_ptr -wrap none		\
		]
		$file_listbox_header delete 1.0 end
		if {!$::MICROSOFT_WINDOWS} {
			$file_listbox_header insert end	\
				[mc "   Name                               Size      Rights  Date             "]
		} else {
			$file_listbox_header insert end	\
				[mc "   Name                               Size      Date             "]
		}
		bindtags $file_listbox_header $file_listbox_header
		$file_listbox_header configure -state disabled
		set file_listbox [ListBox $file_listbox_frame.file_listbox	\
			-bd 1							\
			-padx 17						\
			-width 1						\
			-height 1						\
			-bg white						\
			-deltay 18						\
			-selectfill 1						\
			-selectmode $selmode					\
			-highlightthickness 0					\
			-selectbackground {#88AAFF}				\
			-highlightcolor {#BBBBFF}				\
			-yscrollcommand "$this file_listbox_vscroll" 		\
			-xscrollcommand "$this file_listbox_hscroll"		\
		]
		pack $file_listbox -fill both -expand 1
		if {${::KIFSD::FSD::config(detailed_view)}} {
			$file_listbox configure -multicolumn 0
			set listbox_font $listbox_font_detailed
			pack $file_listbox_header -before $file_listbox -fill x -expand 0
		} else {
			$file_listbox configure -multicolumn 1
			set listbox_font $listbox_font_short
		}
		set file_listbox_vscrollbar [ttk::scrollbar		\
			$right_top_right_top_frame.vscrollbar		\
			-orient vertical -command "$file_listbox yview"	\
		]
		set file_listbox_hscrollbar [ttk::scrollbar		\
			$right_top_right_frame.hscrollbar		\
			-orient horizontal				\
			-command "$this file_listbox_hscrollbar_cmd"	\
		]
		$file_listbox bindText <Double-Button-1>	[list $this file_listbox_doubleclick]
		$file_listbox bindImage <Double-Button-1>	[list $this file_listbox_doubleclick]
		$file_listbox bindText <ButtonRelease-3>	[list $this file_listbox_item_menu %X %Y]
		$file_listbox bindImage <ButtonRelease-3>	[list $this file_listbox_item_menu %X %Y]
		bind $file_listbox <<ListboxSelect>>		[list $this file_listbox_select]
		if {[winfo exists $file_listbox.c]} {
			bind $file_listbox.c <Button-5>		[list $this file_listbox_scroll +5 units]
			bind $file_listbox.c <Button-4>		[list $this file_listbox_scroll -5 units]
			bind $file_listbox.c <ButtonRelease-3>	[list $this file_listbox_menu %X %Y]
		}
		pack $file_listbox_frame -fill both -expand 1 -side left
		pack $right_top_right_top_frame -fill both -expand 1 -side top
		pack $right_top_frame -side top -fill both -expand 1

		# Create Location Label+ComboBox and Filter Label+ComboBox
		grid [label $right_bottom_frame.location_label	\
			-text [mc "Location:"]			\
		] -sticky w -column 0 -row 0
		grid [label $right_bottom_frame.filter_label	\
			-text [mc "Filter:"]			\
		] -sticky w -column 0 -row 1

		set location_cb [ttk::combobox $right_bottom_frame.location_cb	\
			-values {}						\
			-exportselection 0					\
		]
		bind $location_cb <<ComboboxSelected>> "$file_listbox selection clear"
		DynamicHelp::add $location_cb -text [mc "Selected file(s)"]
		bind $location_cb <Key> "$file_listbox selection clear"
		bind $location_cb <KP_Enter> [list $this ok]
		bind $location_cb <Return> [list $this ok]

		set tmp_option_filetypes {}
		foreach type $option_filetypes {
			set glob_masks [lindex $type 1]
			if {[regexp {^\*\.\{\w+(,\w+)*\}$} $glob_masks]} {
				set glob_masks [split $glob_masks {{,}}]
				set glob_masks [lreplace $glob_masks 0 0]
				set glob_masks [lreplace $glob_masks end end]
				set glob_masks_new [list]
				foreach ext $glob_masks {
					lappend glob_masks_new [format "*.%s" $ext]
				}
				set glob_masks [join $glob_masks_new {, }]
			}
			lappend tmp_option_filetypes "[lindex $type 0] ($glob_masks)"
		}
		set filter_cb [ttk::combobox $right_bottom_frame.filter_cb	\
			-state readonly						\
			-values $tmp_option_filetypes				\
			-exportselection 0					\
		]
		DynamicHelp::add $right_bottom_frame.filter_cb -text [mc "Filter"]
		set tmp_option_filetypes {}
		foreach type $option_filetypes {
			lappend tmp_option_filetypes [lindex $type 1]
		}
		set option_filetypes $tmp_option_filetypes
		$filter_cb current $option_defaultmask
		set current_mask [lindex $option_filetypes $option_defaultmask]
		bind $filter_cb <<ComboboxSelected>> [list $this filter_cb_modify]
		grid $location_cb -sticky ew -column 1 -row 0
		grid $filter_cb -sticky ew -column 1 -row 1

		if {!$option_fileson} {
			$filter_cb configure -state disabled
		}

		# Create buttons "Ok" and "Cancel"
		set ok_button [ttk::button $right_bottom_frame.ok_button\
			-text [mc "Ok"]					\
			-compound left					\
			-width 8					\
			-image ::ICONS::16::ok				\
			-command [list $this ok]			\
		]
		grid $ok_button -sticky w -column 2 -row 0 -padx 7 -pady 2
		grid [ttk::button $right_bottom_frame.cancel_button	\
			-text [mc "Cancel"]				\
			-compound left					\
			-width 8					\
			-image ::ICONS::16::button_cancel		\
			-command "itcl::delete object $this"		\
		] -sticky w -column 2 -row 1 -padx 7 -pady 2

		grid columnconfigure $right_bottom_frame 1 -weight 1

		pack $right_bottom_frame -side bottom -fill x -expand 0 -anchor w

		pack $topframe -side top -fill x -padx 12 -pady 10
		pack $mainframe -side bottom -fill both -expand 1 -padx 12

		# Adjust paned windows to current configuration
		quick_access_panel_onoff
		separate_folders_onoff

		# Finalize
		$location_cb set $option_initialfile
		focus -force $location_cb
		catch {
			$location_cb.e selection range 0 end
		}
	}

	## Create dialog toolbar
	 # @return void
	private method create_tool_bar {} {
		set si 0
		foreach item {
			{up		"Parent folder"		{1uparrow}
				{up}}
			{back		"Back"			{1leftarrow}
				{back}}
			{forward	"Forward"		{1rightarrow}
				{forward}}
			{reload		"Reload"		{reload}
				{reload}}
			{separator}
			{newdir		"New folder"		{folder_new}
				{newdir}}
			{separator}
			{short		"Short view"		{view_icon}
				{short_view}}
			{detail		"Detailed view"		{view_detailed}
				{detail_view}}
			{separator}
			{bookmark	"Bookmarks"		{bookmark}
				{bookmark_menu}}
			{configure	"Configure"		{configure}
				{config_menu}}
		} \
		{
			# Create separator
			if {$item == {separator}} {
				pack [ttk::separator $toolbar.sep$si	\
					-orient vertical		\
				] -side left -padx 4 -fill both -expand 1
				incr si
				continue
			}

			# Create button
			if {[lindex $item 0] == {bookmark}} {
				set buttonWidget [ttk::menubutton $toolbar.[lindex $item 0]	\
					-image ::ICONS::22::[lindex $item 2]			\
					-menu $bookmark_menu					\
					-style Flat.TMenubutton					\
				]
			} elseif {[lindex $item 0] == {configure}} {
				set buttonWidget [ttk::menubutton $toolbar.[lindex $item 0]	\
					-image ::ICONS::22::[lindex $item 2]			\
					-menu $config_menu					\
					-style Flat.TMenubutton					\
				]
			} else {
				set buttonWidget [ttk::button $toolbar.[lindex $item 0]	\
					-command "$this [lindex $item 3]"		\
					-style Flat.TButton				\
					-image ::ICONS::22::[lindex $item 2]		\
				]
			}
			DynamicHelp::add $buttonWidget -text [mc [lindex $item 1]]

			# Pack it
			pack $buttonWidget -side left -padx 2
		}

		# Disable button for manipulating history
		$toolbar.back		configure -state disabled
		$toolbar.forward	configure -state disabled

		# Pack toolbar frame
		pack $toolbar -side left -expand 0 -fill none
	}


	## Create dialog popup menus
	 # @return void
	private method create_popup_menus {} {
		# Create configuration menu
		set config_menu [menu $win.config_menu -tearoff 0]

		## Create menu: Configuration -> Sorting
		set sorting_menu [menu $win.config_menu.sorting_menu -tearoff 0]
		 # Entry: "By name"
		$sorting_menu add radiobutton -label [mc "By name"]	\
			-variable ::KIFSD::FSD::config(sorting)		\
			-indicatoron 0 -compound left -image ::ICONS::raoff -selectimage ::ICONS::raon	\
			-value {name} -underline 3 -command [list $this reload]
		 # Entry: "By date"
		$sorting_menu add radiobutton -label [mc "By date"]	\
			-variable ::KIFSD::FSD::config(sorting)		\
			-indicatoron 0 -compound left -image ::ICONS::raoff -selectimage ::ICONS::raon	\
			-value {date} -underline 3 -command [list $this reload]
		 # Entry: "By size"
		$sorting_menu add radiobutton -label [mc "By size"]	\
			-variable ::KIFSD::FSD::config(sorting)		\
			-indicatoron 0 -compound left -image ::ICONS::raoff -selectimage ::ICONS::raon	\
			-value {size} -underline 3 -command [list $this reload]
		$sorting_menu add separator
		 # Entry: "Reverse"
		$sorting_menu add checkbutton -label [mc "Reverse"]	\
			-variable ::KIFSD::FSD::config(reverse_sorting)	\
			-indicatoron 0 -compound left -image ::ICONS::choff -selectimage ::ICONS::chon	\
			-command "$this reload" -underline 0
		 # Entry: "Folders first"
		$sorting_menu add checkbutton -label [mc "Folders first"]	\
			-variable ::KIFSD::FSD::config(folders_first)		\
			-indicatoron 0 -compound left -image ::ICONS::choff -selectimage ::ICONS::chon	\
			-command "$this reload" -underline 0
		 # Entry: "Case insensitive"
		$sorting_menu add checkbutton -label [mc "Case insensitive"]	\
			-variable ::KIFSD::FSD::config(case_insensitive)	\
			-indicatoron 0 -compound left -image ::ICONS::choff -selectimage ::ICONS::chon	\
			-command "$this reload" -underline 0

		## Create entries for configuraion menu (accessable from toolbar)
		 # Entry: "Sorting"
		$win.config_menu add cascade -label [mc "Sorting"] -underline 1 -menu $sorting_menu -image ::ICONS::16::sort_incr -compound left
		$win.config_menu add separator
		 # Entry: "Short view"
		$win.config_menu add command -label [mc "Short view"] -compound left	\
			-accelerator "F6" -command "$this short_view" -underline 0	\
			-image ::ICONS::16::view_icon
		 # Entry: "Detailed view"
		$win.config_menu add command -label [mc "Detailed view"] -compound left	\
			-accelerator "F7" -command "$this detail_view" -underline 0	\
			-image ::ICONS::16::view_detailed
		$win.config_menu add separator
		 # Entry: "Show hidden files"
		$win.config_menu add checkbutton -label [mc "Show hidden files"]		\
			-accelerator "F8" -variable ::KIFSD::FSD::config(show_hidden_files)	\
			-indicatoron 0 -compound left -image ::ICONS::choff -selectimage ::ICONS::chon	\
			-command "$this reload" -underline 5
		 # Entry: "Quick access navigation panel"
		$win.config_menu add checkbutton -label [mc "Quick access navigation panel"]	\
			-accelerator "F9" -variable ::KIFSD::FSD::config(quick_access_panel)	\
			-indicatoron 0 -compound left -image ::ICONS::choff -selectimage ::ICONS::chon	\
			-command "$this quick_access_panel_onoff" -underline 0
		 # Entry: "Separate folders"
		$win.config_menu add checkbutton -label [mc "Separate folders"]			\
			-accelerator "F12" -variable ::KIFSD::FSD::config(separate_folders)	\
			-indicatoron 0 -compound left -image ::ICONS::choff -selectimage ::ICONS::chon	\
			-command "$this separate_folders_onoff" -underline 9
		if {!$option_fileson} {
			$win.config_menu entryconfigure [mc "Separate folders"] -state disabled
			$sorting_menu entryconfigure [mc "Folders first"] -state disabled
			$sorting_menu entryconfigure [mc "By size"] -state disabled
		}

		## Create bookmarks menu (accessable from toolbar)
		set bookmark_menu [menu $win.bookmark_menu -tearoff 0]
		 # Entry: "Add bookmark"
		$bookmark_menu add command -label [mc "Add bookmark"]	\
			-command "$this add_bookmark"			\
			-underline 0 -image ::ICONS::16::bookmark_add -compound left
		 # Entry: "Edit bookmarks"
		$bookmark_menu add command -label [mc "Edit bookmarks"] -compound left	\
			-command "$this edit_bookmarks" -underline 0 -image ::ICONS::16::bookmark
		$bookmark_menu add separator
		refresh_bookmarks

		## Create ListBox item menu
		menu $win.listbox_menu -tearoff 0
		 # Entry: "Up"
		$win.listbox_menu add command -label [mc "Up"] -compound left	\
			-underline 0 -command [list $this up]	\
			-image ::ICONS::16::up
		 # Entry: "Back"
		$win.listbox_menu add command -label [mc "Back"] -compound left	\
			-underline 0 -command [list $this back]		\
			-image ::ICONS::16::left -state disabled
		 # Entry: "Forward"
		$win.listbox_menu add command -label [mc "Forward"] -compound left	\
			-underline 0 -command [list $this forward]	\
			-image ::ICONS::16::right -state disabled
		$win.listbox_menu add separator
		 # Entry: "Rename"
		$win.listbox_menu add command -label [mc "Rename"]		\
			-underline 0 -command [list $this rename_item_command]	\
			-compound left -image ::ICONS::16::edit
		 # Entry: "Delete"
		$win.listbox_menu add command -label [mc "Delete"]		\
			-underline 0 -command [list $this delete_item_command]	\
			-compound left -image ::ICONS::16::editdelete
		 # Entry: "New folder"
		$win.listbox_menu add command -label [mc "New folder"]		\
			-accelerator "F10"					\
			-underline 0 -command [list $this newdir]		\
			-compound left -image ::ICONS::16::folder_new
		 # Entry: "Bookmark folder"
		$win.listbox_menu add command -label [mc "Bookmark folder"]	\
			-underline 0 -command [list $this item_bookmark_add]	\
			-compound left -image ::ICONS::16::bookmark_add
		$win.listbox_menu add separator
		 # Entry: "Properties"
		$win.listbox_menu add command -label [mc "Properties"]	\
			-underline 0 -command [list $this properties_item_command]

		## Create quick access bar popup menu
		menu $win.quick_access_panel_menu -tearoff 0
		 # Entry: "Add entry"
		$win.quick_access_panel_menu add command -label [mc "Add entry"]	\
			-underline 0 -image ::ICONS::16::filenew -compound left		\
			-command "$this quick_access_panel_add_entry"
		$win.quick_access_panel_menu add separator
		 # Entry: "Hide panel"
		$win.quick_access_panel_menu add command -label [mc "Hide panel"]	\
			-underline 0 -image ::ICONS::16::2leftarrow -compound left	\
			-accelerator "F9" -command "
				set ::KIFSD::FSD::config(quick_access_panel)	\
					\[expr {!\${::KIFSD::FSD::config(quick_access_panel)}}\]
				$this quick_access_panel_onoff"

		## Create quick access bar ITEM popup menu
		menu $win.quick_access_panel_item_menu -tearoff 0
		 # Entry: "Move up"
		$win.quick_access_panel_item_menu add command -label [mc "Move up"]	\
			-underline 0 -image ::ICONS::16::1uparrow -compound left	\
			-command "$this quick_access_panel_up"
		 # Entry: "Move down"
		$win.quick_access_panel_item_menu add command -label [mc "Move down"]	\
			-underline 0 -image ::ICONS::16::1downarrow -compound left	\
			-command "$this quick_access_panel_down"
		$win.quick_access_panel_item_menu add separator
		 # Entry: "Edit entry"
		$win.quick_access_panel_item_menu add command -label [mc "Edit entry"]	\
			-underline 0 -image ::ICONS::16::edit -compound left		\
			-command "$this quick_access_panel_edit_entry"
		$win.quick_access_panel_item_menu add separator
		 # Entry: "Add entry"
		$win.quick_access_panel_item_menu add command -label [mc "Add entry"]	\
			-underline 0 -image ::ICONS::16::filenew -compound left		\
			-command "$this quick_access_panel_add_entry"
		 # Entry: "Remove entry"
		$win.quick_access_panel_item_menu add command -label [mc "Remove entry"]\
			-underline 0 -image ::ICONS::16::editdelete -compound left	\
			-command "$this quick_access_panel_remove_entry"
		$win.quick_access_panel_item_menu add separator
		 # Entry: "Hide panel"
		$win.quick_access_panel_item_menu add command -label [mc "Hide panel"]	\
			-underline 0 -image ::ICONS::16::2leftarrow -compound left	\
			-accelerator "F9"	\
			-command "
				set ::KIFSD::FSD::config(quick_access_panel)	\
					\[expr {!\${::KIFSD::FSD::config(quick_access_panel)}}\]
				$this quick_access_panel_onoff"
	}

	## Define key shortcuts for the dialog
	 # @return void
	private method create_shortcuts {} {
		bind $win <Key-F5>	"$this reload; break"
		bind $win <Key-F6>	"$this short_view; break"
		bind $win <Key-F7>	"$this detail_view; break"
		bind $win <Key-F8>	"
			set ::KIFSD::FSD::config(show_hidden_files)	\
				\[expr {!\${::KIFSD::FSD::config(show_hidden_files)}}\]
			$this reload
			break
		"
		bind $win <Key-F9>	"
			set ::KIFSD::FSD::config(quick_access_panel)	\
				\[expr {!\${::KIFSD::FSD::config(quick_access_panel)}}\]
			$this quick_access_panel_onoff
			break
		"
		bind $win <Key-F10>	"$this newdir; break"
		if {$option_fileson} {
			bind $win <Key-F12>	"
				set ::KIFSD::FSD::config(separate_folders)	\
					\[expr {!\${::KIFSD::FSD::config(separate_folders)}}\]
				$this separate_folders_onoff
				break
			"
		}
	}

	## Change current directory
	 # This function checks for directory validity
	 # @parm String dir - New directory
	 # @return void
	public method change_directory {dir} {
		if {$::MICROSOFT_WINDOWS} {
			# Transform for instance "C:" to "C:/"
			if {[regexp {^\w+:$} $dir]} {
				append dir {/}
			}
		}

		# Check if the specified directory is valid
		if {![file exists $dir] || ![file isdirectory $dir]} {
			tk_messageBox		\
				-parent $win	\
				-type ok	\
				-icon warning	\
				-title [mc "Invalid folder"] \
				-message [mc "The specified folder does not exist:\n%s" $dir]
			return
		}
		set dir [file normalize $dir]

		# Adjust history
		if {$dir != $current_directory} {
			lappend back_history $current_directory
			set forward_history {}
			$win.listbox_menu entryconfigure [mc "Forward"] -state disabled
			$win.listbox_menu entryconfigure [mc "Back"] -state normal
			$toolbar.forward configure -state disabled
			$toolbar.back configure -state normal
		}

		# Option separate_folders ON
		FSnotifications::forget $current_directory
		FSnotifications::watch $dir [list KIFSD::FSD::static_reload $this]
		set current_directory $dir
		if {${::KIFSD::FSD::config(separate_folders)} && $option_fileson} {
			# Fill up directory ListBox with directories
			$dir_listbox delete [$dir_listbox items]
			foreach folder [dir_cmd $dir 1] {
				if {$folder == {..}} {
					set image {up}
				} else {
					set image {fileopen}
				}
				$dir_listbox insert end #auto		\
					-text $folder			\
					-image ::ICONS::16::$image	\
					-font $listbox_font_short
			}

			# Fill up file ListBox with files
			$file_listbox delete [$file_listbox items]
			foreach file [file_cmd $dir $current_mask] {
				if {${::KIFSD::FSD::config(detailed_view)}} {
					set filename [lindex $file 1]
					set file [lindex $file 0]
				} else {
					set filename $file
				}
				$file_listbox insert end #auto		\
					-text $file			\
					-image ::ICONS::16::ascii	\
					-font $listbox_font		\
					-data [list $filename {}]
			}
		# Option separate_folders OFF
		} else {
			# Option folders_first ON or option_fileson OFF
			$file_listbox delete [$file_listbox items]
			if {!$option_fileson || ${::KIFSD::FSD::config(folders_first)}} {
				# Fill up files ListBox with directories
				foreach folder [dir_cmd $dir] {
					if {${::KIFSD::FSD::config(detailed_view)}} {
						set fullname [lindex $folder 1]
						set folder [lindex $folder 0]
					} else {
						set fullname $folder
					}

					if {$folder == {..}} {
						set image {up}
						set fullname $folder
					} else {
						set image {fileopen}
					}

					$file_listbox insert end #auto		\
						-text $folder			\
						-image ::ICONS::16::$image	\
						-font $listbox_font		\
						-data [list {} $fullname]
				}
				# Option: option_fileson ON
				if {$option_fileson} {
					# Fill up files ListBox with files
					foreach file [file_cmd $dir $current_mask] {
						if {${::KIFSD::FSD::config(detailed_view)}} {
							set filename [lindex $file 1]
							set file [lindex $file 0]
						} else {
							set filename $file
						}

						$file_listbox insert end #auto		\
							-text $file			\
							-image ::ICONS::16::ascii	\
							-font $listbox_font		\
							-data [list $filename {}]
					}
				}
			# Option NOT ( folders_first ON or option_fileson OFF )
			} else {
				# Fill up files ListBox with files and directories
				foreach file [dir_file_cmd $dir $current_mask] {
					set filename {}
					set folder {}
					if {${::KIFSD::FSD::config(detailed_view)}} {
						set fullname [lindex $file {0 1}]
						set text [lindex $file {0 0}]
					} else {
						set fullname [lindex $file 0]
						set text $fullname
					}

					switch -- [lindex $file 1] {
						u	{
							set image {up}
							set folder {..}
						}
						d	{
							set image {fileopen}
							set folder $fullname
						}
						f	{
							set image {ascii}
							set filename $fullname
						}
					}

					$file_listbox insert end #auto		\
						-text $text			\
						-image ::ICONS::16::$image	\
						-font $listbox_font		\
						-data [list $filename $folder]
				}
			}
		}

		# Fill up location ComboBox with available files or directories
		if {$option_fileson} {
			$location_cb configure -values [file_cmd $dir $current_mask 1]
		} else {
			$location_cb configure -values [dir_cmd $dir 1]
		}
		$location_cb set {}

		# Fill up directory ComboBox
		set values {}
		set folder $dir
		while {1} {
			lappend values $folder
			if {$folder == [file separator]} {break}
			if {$::MICROSOFT_WINDOWS} {
				if {[regexp {^\w+:[\\\/]?$} $folder]} {break}
			}
			set folder [file normalize [file join $folder {..}]]
		}
		foreach folder [dir_cmd $dir 1] {
			if {$folder == {..}} {continue}
			lappend values [file join $dir $folder]
		}
		if {$::MICROSOFT_WINDOWS} { ;# Include drive letters on Microsoft Windows
			foreach drive_letter {A B C D E F G H I J K L M N O P Q R S T U V W X Y Z} {
				if {[file exists "${drive_letter}:/"]} {
					lappend values "${drive_letter}:/"
				}
			}
		}

		$dir_combobox configure -values $values
		$dir_combobox current 0
		$dir_combobox icursor end

		# Enable / Disable button "Up (Parent folder)"
		if {$dir == {/} || $dir == "\\"} {
			$toolbar.up configure -state disabled
			$win.listbox_menu entryconfigure [mc "Up"] -state disabled
		} else {
			$toolbar.up configure -state normal
			$win.listbox_menu entryconfigure [mc "Up"] -state normal
		}
	}

	## This function shoul be called after Filter ComboBox change
	 # @return void
	public method filter_cb_modify {} {
		set current_mask [lindex $option_filetypes [$filter_cb current]]
		reload
	}

	## Show / Hide quick access bar according to configuration variable quick_access_panel
	 # @return void
	public method quick_access_panel_onoff {} {
		# Show the panel
		if {${::KIFSD::FSD::config(quick_access_panel)}} {
			pack $main_paned_window -fill both -expand 1
			$main_paned_window add $leftframe
			$main_paned_window add $rightframe
			$main_paned_window paneconfigure $leftframe -minsize 100
			$main_paned_window paneconfigure $rightframe -minsize 300
			if {$dialog_loaded} {update}
			$main_paned_window sash place 0 ${::KIFSD::FSD::config(main_PW_size)} 0
			if {$dialog_loaded} {update}
		# Hide the panel
		} else {
			if {[winfo ismapped $main_paned_window]} {
				set ::KIFSD::FSD::config(main_PW_size)	\
					[lindex [$main_paned_window sash coord 0] {0 0}]
				$main_paned_window forget $leftframe
				$main_paned_window forget $rightframe
				pack forget $main_paned_window
			}
			pack $rightframe -fill both -expand 1 -padx 5
		}
	}

	## Show / Hide folders ListBox according to configuration variable separate_folders
	 # This function will show folders ListBox only if option_fileson == 1
	 # @return void
	public method separate_folders_onoff {} {
		# Show folders ListBox
		if {${::KIFSD::FSD::config(separate_folders)} && $option_fileson} {
			pack $right_paned_window -fill both -expand 1
			$right_paned_window add $right_top_left_frame
			$right_paned_window add $right_top_right_frame
			$right_paned_window paneconfigure $right_top_left_frame -minsize 150
			$right_paned_window paneconfigure $right_top_right_frame -minsize 200
			if {$dialog_loaded} {update}
			$right_paned_window sash place 0 ${::KIFSD::FSD::config(right_PW_size)} 0
			if {$dialog_loaded} {update}

		# Hide folders ListBox
		} else {
			if {[winfo ismapped $right_paned_window]} {
				set ::KIFSD::FSD::config(right_PW_size)	\
					[lindex [$right_paned_window sash coord 0] {0 0}]
				$right_paned_window forget $right_top_left_frame
				$right_paned_window forget $right_top_right_frame
				pack forget $right_paned_window
			}
			pack $right_top_right_frame -expand 1 -fill both -in $right_top_frame
		}

		# Refresh files and folders ListBoxes
		change_directory $current_directory
	}

	## Invoke bookmark menu
	 # @return void
	public method bookmark_menu {} {
		set x [winfo rootx $toolbar.bookmark]
		set y [winfo rooty $toolbar.bookmark]
		incr y [winfo height $toolbar.bookmark]
		tk_popup $win.bookmark_menu $x $y
	}

	## Invoke configuration menu
	 # @return void
	public method config_menu {} {
		set x [winfo rootx $toolbar.configure]
		set y [winfo rooty $toolbar.configure]
		incr y [winfo height $toolbar.configure]
		tk_popup $win.config_menu $x $y
	}

	## Scroll folders ListBox and (Un)Map its scrollbar
	 # @parm Float frac0 - 1st fraction
	 # @parm Float frac0 - 2nd fraction
	 # @return void
	public method dir_listbox_scroll {frac0 frac1} {
		# Hide scrollbar
		if {$frac0 == 0 && $frac1 == 1} {
			if {[winfo ismapped $dir_listbox_scrollbar]} {
				pack forget $dir_listbox_scrollbar
			}
		# Show scrollbar
		} else {
			if {![winfo ismapped $dir_listbox_scrollbar]} {
				pack $dir_listbox_scrollbar -fill y -expand 1 -after $dir_listbox
			}
			$dir_listbox_scrollbar set $frac0 $frac1
		}
	}

	## Switch to mode "Short View"
	 # @return void
	public method short_view {} {
		if {!${::KIFSD::FSD::config(detailed_view)}} {return}
		set ::KIFSD::FSD::config(detailed_view) 0
		$file_listbox configure -multicolumn 1
		set listbox_font $listbox_font_short
		pack forget $file_listbox_header
		reload
	}

	## Switch to mode "Detailed View"
	 # @return void
	public method detail_view {} {
		if {${::KIFSD::FSD::config(detailed_view)}} {return}
		set ::KIFSD::FSD::config(detailed_view) 1
		$file_listbox configure -multicolumn 0
		set listbox_font $listbox_font_detailed
		pack $file_listbox_header -before $file_listbox -fill x -expand 0
		reload
	}

	## Bookmark current folder
	 # @return void
	public method add_bookmark {} {
		lappend ::KIFSD::FSD::config(bookmarks) $current_directory
		$bookmark_menu add command					\
			-label $current_directory -compound left		\
			-image ::ICONS::16::fileopen				\
			-command "$this change_directory {$current_directory}"
		uplevel #0 $bookmark_change_command
	}

	## Invoke bookmark editor
	 # @return void
	public method edit_bookmarks {} {
		# Create dialog window
		set dialog [toplevel $win.edit_bookmarks -class {Edit bookmarks} -bg ${::COMMON_BG_COLOR}]

		# Create top frame (ListBox containing bookmarks and its scrollbar)
		set top_frame [frame $dialog.top_frame]
		set bookmark_edit_listbox [ListBox $top_frame.listbox	\
			-yscrollcommand "$top_frame.scrollbar set"	\
			-bg white -selectfill 1 -selectmode single	\
			-highlightcolor {#BBBBFF}			\
		]
		$bookmark_edit_listbox bindText <Double-1> "$this edit_bookmarks_edit"
		pack $bookmark_edit_listbox -side left -fill both -expand 1
		pack [ttk::scrollbar $top_frame.scrollbar	\
			-orient vertical 			\
			-command "$bookmark_edit_listbox yview"	\
		] -fill y -expand 1

		# Fill up ListBox with defined bookmarks
		foreach item ${::KIFSD::FSD::config(bookmarks)} {
			$bookmark_edit_listbox insert end #auto -text $item
		}

		## Create bottom frame (buttons)
		set bottom_frame [frame $dialog.bottom_frame]
		 # Button: "Remove"
		pack [ttk::button $bottom_frame.remove		\
			-text [::mc "Remove"]			\
			-compound left				\
			-image ::ICONS::16::editdelete		\
			-command "$this edit_bookmarks_remove"	\
			-width 8				\
		] -side left -padx 2
		 # Button: "Edit"
		pack [ttk::button $bottom_frame.edit		\
			-text [::mc "Edit"]			\
			-compound left				\
			-image ::ICONS::16::edit		\
			-command "$this edit_bookmarks_edit"	\
			-width 8				\
		] -side left -padx 2
		 # Button: "Up"
		pack [ttk::button $bottom_frame.up		\
			-text [::mc "Up"]			\
			-compound left				\
			-image ::ICONS::16::up			\
			-command "$this edit_bookmarks_up"	\
			-width 8				\
		] -side left -padx 2
		 # Button: "Down"
		pack [ttk::button $bottom_frame.down		\
			-text [::mc "Down"]			\
			-compound left				\
			-image ::ICONS::16::down		\
			-command "$this edit_bookmarks_down"	\
			-width 8				\
		] -side left -padx 2
		 # Button: "Ok"
		pack [ttk::button $bottom_frame.ok		\
			-text [::mc "Ok"]			\
			-compound left				\
			-image ::ICONS::16::ok			\
			-width 8				\
			-command "
				$this bookmark_edit_ok
				grab release $dialog
				destroy $dialog
			"	\
		] -side right -padx 2
		 # Button: "Cancel"
		pack [ttk::button $bottom_frame.cancel		\
			-text [::mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-width 8				\
			-command "
				grab release $dialog
				destroy $dialog
			"	\
		] -side right -padx 2

		# Pack dialog frames (top and bottom)
		pack $top_frame -side top -fill both -expand 1 -pady 5 -padx 5
		pack $bottom_frame -side top -after $top_frame -fill x -expand 0 -pady 5 -padx 5

		# Configure dialog window
		wm iconphoto $dialog ::ICONS::16::bookmark
		wm title $dialog "Edit bookmarks"
		wm minsize $dialog 550 240
		wm geometry $dialog 550x340
		wm protocol $dialog WM_DELETE_WINDOW "
			grab release $dialog
			destroy $dialog
		"
		if {[winfo ismapped $win]} {
			wm transient $dialog $win
		} else {
			wm transient $dialog .
		}
		grab $dialog
		raise $dialog
		tkwait window $dialog
	}

	## Auxiliary procedure for bookmark editor
	 # Remove current bookmark
	 # @return void
	public method edit_bookmarks_remove {} {
		set item [$bookmark_edit_listbox selection get]
		if {$item == {}} {return}
		$bookmark_edit_listbox delete $item
	}

	## Auxiliary procedure for bookmark editor
	 # Edit current bookmark
	 # @return void
	public method edit_bookmarks_edit args {
		set item [$bookmark_edit_listbox selection get]
		if {$item == {}} {return}
		set text [$bookmark_edit_listbox edit $item			\
				[$bookmark_edit_listbox itemcget $item -text]]
		if {$text == {}} {return}
		$bookmark_edit_listbox itemconfigure $item -text $text
	}

	## Auxiliary procedure for bookmark editor
	 # Move current bookmark up
	 # @return void
	public method edit_bookmarks_up {} {
		set item [$bookmark_edit_listbox selection get]
		if {$item == {}} {return}
		if {
			![$bookmark_edit_listbox index $item]
				||
			([llength [$bookmark_edit_listbox items]] < 2)
		} then {
			return
		}
		$bookmark_edit_listbox move $item [expr {[$bookmark_edit_listbox index $item] - 1}]
	}

	## Auxiliary procedure for bookmark editor
	 # Move current bookmark down
	 # @return void
	public method edit_bookmarks_down {} {
		set item [$bookmark_edit_listbox selection get]
		if {$item == {}} {return}
		if {
			[$bookmark_edit_listbox index $item]
				>=
			([llength [$quick_access_bar items]] - 1)
		} then {
			return
		}
		$bookmark_edit_listbox move $item [expr {[$bookmark_edit_listbox index $item] + 1}]
	}

	## Auxiliary procedure for bookmark editor
	 # Confirm bookmark edit dialog
	 # @return void
	public method bookmark_edit_ok {} {
		set ::KIFSD::FSD::config(bookmarks) {}
		foreach item [$bookmark_edit_listbox items] {
			lappend ::KIFSD::FSD::config(bookmarks)	\
				[$bookmark_edit_listbox itemcget $item -text]
		}
		refresh_bookmarks
		uplevel #0 $bookmark_change_command
	}

	## Reload items to bookmarks menu
	 # @return void
	private method refresh_bookmarks {} {
		if {[$bookmark_menu index end] > 2} {
			$bookmark_menu delete 3 end
		}
		foreach dir ${::KIFSD::FSD::config(bookmarks)} {
			$bookmark_menu add command			\
				-label $dir -compound left		\
				-image ::ICONS::16::fileopen		\
				-command "$this change_directory {$dir}"
		}
	}

	## Set command to execute when bookmark list changes
	 # @parm String command - Command to invoke from root namespace
	 # @return void
	proc set_bookmark_change_command {command} {
		set bookmark_change_command $command
	}

	## Unmap dialog window (but keep object alive)
	 # @return void
	public method deactivate {} {
		wm withdraw $win
	}

	## Activate (map) dialog window
	 # And wait until window is unmapped
	 # @return void
	public method activate {} {
		wm resizable $win 1 1
		wm deiconify $win
		update idletasks
		if {[winfo ismapped $right_paned_window]} {
			$right_paned_window sash place 0 ${::KIFSD::FSD::config(right_PW_size)} 0
		}
		if {[winfo ismapped $main_paned_window]} {
			$main_paned_window sash place 0 ${::KIFSD::FSD::config(main_PW_size)} 0
		}
		tkwait window $win
	}

	## Get selected item(s)
	 # @return String/List - Full path(s) to selected item(s)
	public method get {} {
		# Return List
		if {$option_multiple} {
			set result {}
			foreach	item [$file_listbox selection get] {
				lappend result [file join $current_directory	\
					[lindex [$file_listbox itemcget $item -data] 0]]
			}
			if {$result == {}} {
				lappend result [file join $current_directory [$location_cb get]]
			}
			return $result
		# Return String
		} else {
			return [file join $current_directory [$location_cb get]]
		}
	}

	## Destroy dialog object
	 # @return void
	public method close_dialog {} {
		catch {
			itcl::delete object $this
		}
	}

	## Set command to invoke from root namespace on action "Ok"
	 # @parm String command - Command (with arguments)
	 # @return void
	public method setokcmd {cmd} {
		set ok_command $cmd
	}

	## Ok action - command for button "Ok"
	 # @return void
	public method ok {} {
		if {$option_autoclose} {
			wm withdraw $win
			set ok_command_tmp $ok_command
			set ok_command {}
			uplevel #0 $ok_command_tmp
			close_dialog
		} else {
			uplevel #0 $ok_command
		}
	}

	## Command for files ListBox horizontal scrollbar
	 # Takes any list of arguments (see code)
	 # @return void
	public method file_listbox_hscrollbar_cmd args {
		eval "$file_listbox xview $args"
		eval "$file_listbox_header xview $args"
	}

	## Scroll files ListBox vertically
	 # This function manages scrollbar visibility
	 # @parm Float frac0 - 1st fraction (see Tk manual)
	 # @parm Float frac1 - 2nd fraction (see Tk manual)
	 # @return void
	public method file_listbox_vscroll {frac0 frac1} {
		# Hide scrollbar
		if {$frac0 == 0 && $frac1 == 1} {
			if {[winfo ismapped $file_listbox_vscrollbar]} {
				pack forget $file_listbox_vscrollbar
				update
			}

		# Show scrollbar
		} else {
			if {![winfo ismapped $file_listbox_vscrollbar]} {
				pack $file_listbox_vscrollbar		\
					-after $file_listbox_frame	\
					-fill y -expand 1
				update
			}
			$file_listbox_vscrollbar set $frac0 $frac1
		}
	}

	## Scroll files ListBox horizontaly
	 # This function manages scrollbar visibility
	 # @parm Float frac0 - 1st fraction (see Tk manual)
	 # @parm Float frac1 - 2nd fraction (see Tk manual)
	 # @return void
	public method file_listbox_hscroll {frac0 frac1} {

		# Hide scrollbar
		if {$frac0 == 0 && $frac1 == 1} {
			if {[winfo ismapped $file_listbox_hscrollbar]} {
				pack forget $file_listbox_hscrollbar
				update
			}

		# Show scrollbar
		} else {
			if {![winfo ismapped $file_listbox_hscrollbar]} {
				pack $file_listbox_hscrollbar			\
					-after $right_top_right_top_frame	\
					-side bottom -fill x -expand 0
				update
			}
			catch {
				$file_listbox_hscrollbar set $frac0 $frac1
			}
		}
	}

	## Event handler for quick access bar ListBox, event <<ListboxSelect>>
	 # @return void
	public method quick_access_bar_select {} {
		if {$option_doubleclick} {return}
		catch {
			change_directory \
				[$quick_access_bar itemcget \
					[$quick_access_bar selection get] -data]
		}
	}

	## Event handler for quick access bar ListBox, item event <Double-1>
	 # @parm String item - Item identifier
	 # @return void
	public method quick_access_bar_doubleclick {item} {
		if {!$option_doubleclick} {return}
		catch {
			change_directory \
				[$quick_access_bar itemcget \
					[$quick_access_bar selection get] -data]
		}
	}

	## Event handler for directories ListBox, item event <Double-1>
	 # @parm String item - Item identifier
	 # @return void
	public method dir_listbox_doubleclick {item} {
		# Abort if dirs ListBox widget is no longer available
		if {![winfo exists $dir_listbox]} {
			return
		}
		if {!$option_doubleclick} {return}
		catch {
			change_directory [file join $current_directory \
				[$dir_listbox itemcget $item -text]]
		}
	}

	## Event handler for directories ListBox, event <<ListboxSelect>>
	 # @return void
	public method dir_listbox_select {} {
		# Abort if dirs ListBox widget is no longer available
		if {![winfo exists $dir_listbox]} {
			return
		}
		if {$option_doubleclick} {return}
		catch {
			change_directory [file normalize [file join $current_directory \
				[$dir_listbox itemcget [$dir_listbox selection get] -text]]]
		}
	}

	## Event handler for files ListBox, item event <Double-1>
	 # @parm String item - Item identifier
	 # @return void
	public method file_listbox_doubleclick {item} {
		# Abort if files ListBox widget is no longer available
		if {![winfo exists $file_listbox]} {
			return
		}

		# Item directory or {} if it's a file
		if {[catch {
			set folder [lindex [$file_listbox itemcget $item -data] 1]
		}]} then {
			return
		}

		if {!$option_fileson} {
			if {$folder != {}} {
				change_directory [file join $current_directory $folder]
			}
			return
		}

		if {$option_doubleclick && !${::KIFSD::FSD::config(separate_folders)}} {
			if {$folder != {}} {
				change_directory [file join $current_directory $folder]
			}
		}

		if {!$option_doubleclick && ($folder == {})} {
			ok
		}
	}

	## Scroll files listbox
	 # Arguments are passed to yview or xview command
	 # @return void
	public method file_listbox_scroll args {
		if {${::KIFSD::FSD::config(detailed_view)}} {
			set cmd {yview}
		} else {
			set cmd {xview}
		}
		eval "$file_listbox.c $cmd scroll $args"
	}

	## Event handler for files ListBox, event <<ListboxSelect>>
	 # @return void
	public method file_listbox_select {} {
		set selection [$file_listbox selection get]

		# Change directory if the item represents a directory
		if {$option_fileson && !${::KIFSD::FSD::config(separate_folders)}} {
			set folder [$file_listbox itemcget [lindex $selection end] -data]
			set folder [lindex $folder 1]
			if {$folder != {}} {
				if {!$option_doubleclick} {
					change_directory [file join $current_directory $folder]
				}
				return
			}
		}

		# Change content of location ComboBox if item is a file
		if {[llength $selection] == 1} {
			set index [lindex [$file_listbox itemcget $selection -data] [expr {$option_fileson ? 0 : 1}]]
			if {$index != {..}} {
				set index [lsearch -ascii [$location_cb cget -values] $index]
				if {$index != -1} {
					$location_cb current $index
				}
			}
		} elseif {[llength $selection] > 1} {
			set text {}
			foreach item $selection {
				append text "\""
				append text [lindex [$file_listbox itemcget $item -data] [expr {$option_fileson ? 0 : 1}]]
				append text "\" "
			}
			$location_cb set $text
		}
	}

	## Reload content of quick access bar ListBox
	 # @return void
	private method refresh_quick_access_bar {} {
		# Remove existing items
		$quick_access_bar delete [$quick_access_bar items]

		# Create new items
		foreach item ${::KIFSD::FSD::config(quick_access_bar_data)} {
			# Determinate item icon
			switch -- [lindex $item 0] {
				0 {set image hdd_unmount}
				1 {set image folder_home}
				2 {set image desktop}
				3 {set image bookmark_folder}
			}
			# Insert item
			$quick_access_bar insert end #auto	\
				-font $quick_nav_panel_font	\
				-image ::ICONS::22::$image	\
				-text [lindex $item 1]		\
				-data [lindex $item 2]		\
		}
	}

	## Invoke popup menu for ListBox of Quick access bar
	 # @parm Int x - Relative position of mouse pointer
	 # @parm Int y - Relative position of mouse pointer
	 # @return void
	public method quick_access_bar_menu {x y} {
		if {$item_menu_request} {
			set item_menu_request 0
			return
		}
		catch {
			tk_popup $win.quick_access_panel_menu $x $y
		}
	}

	## Invoke popup menu for particular item in ListBox of Quick access bar
	 # @parm Int x		- Relative position of mouse pointer
	 # @parm Int y		- Relative position of mouse pointer
	 # @parm String item	- Item identifier
	 # @return void
	public method quick_access_bar_item_menu {x y item} {
		set item_menu_request 1
		set current_item $item
		set current_item_index [$quick_access_bar index $item]
		set len [llength [$quick_access_bar items]]

		# Enable / Disabled entry "Move down"
		if {$current_item_index >= ($len - 1)} {
			$win.quick_access_panel_item_menu entryconfigure [mc "Move down"] -state disabled
		} else {
			$win.quick_access_panel_item_menu entryconfigure [mc "Move down"] -state normal
		}

		# Enable / Disabled entry "Move up"
		if {!$current_item_index || ($len < 2)} {
			$win.quick_access_panel_item_menu entryconfigure [mc "Move up"] -state disabled
		} else {
			$win.quick_access_panel_item_menu entryconfigure [mc "Move up"] -state normal
		}

		# Invoke the menu
		tk_popup $win.quick_access_panel_item_menu $x $y
	}

	## Move current item in quick access bar down
	 # @return void
	public method quick_access_panel_down {} {
		# Check if the item is not the topmost one
		if {$current_item_index >= ([llength [$quick_access_bar items]] - 1)} {
			return
		}

		set ::KIFSD::FSD::config(quick_access_bar_data) [lreplace	\
			${::KIFSD::FSD::config(quick_access_bar_data)}		\
			$current_item_index [expr {$current_item_index + 1}]	\
			[lindex ${::KIFSD::FSD::config(quick_access_bar_data)}	\
				[expr {$current_item_index + 1}]]		\
			[lindex ${::KIFSD::FSD::config(quick_access_bar_data)}	\
				$current_item_index]
		]
		refresh_quick_access_bar
	}

	## Move current item in quick access bar up
	 # @return void
	public method quick_access_panel_up {} {
		# Check if the item is not the bottommost one
		if {!$current_item_index || ([llength [$quick_access_bar items]] < 2)} {
			return
		}

		set ::KIFSD::FSD::config(quick_access_bar_data) [lreplace	\
			${::KIFSD::FSD::config(quick_access_bar_data)}		\
			[expr {$current_item_index - 1}] $current_item_index	\
			[lindex ${::KIFSD::FSD::config(quick_access_bar_data)}	\
				$current_item_index]				\
			[lindex ${::KIFSD::FSD::config(quick_access_bar_data)}	\
				[expr {$current_item_index - 1}]]
		]
		refresh_quick_access_bar
	}

	## Invoke dialog to add entry to quick access bar
	 # @return void
	public method quick_access_panel_add_entry {} {
		set data [qa_panel_dialog "Add entry" {3} [::mc "New entry"] {~}]
		if {![string length [lindex $data 1]]} {return}
		if {![string length [lindex $data 2]]} {return}
		lappend ::KIFSD::FSD::config(quick_access_bar_data) $data
		refresh_quick_access_bar
	}

	## Invoke dialog to edit current entry in quick access bar
	 # @return void
	public method quick_access_panel_edit_entry {} {
		set data [lindex ${::KIFSD::FSD::config(quick_access_bar_data)} $current_item_index]
		set data [qa_panel_dialog "Edit entry" [lindex $data 0] [lindex $data 1] [lindex $data 2]]
		if {![string length [lindex $data 1]]} {return}
		if {![string length [lindex $data 2]]} {return}
		set ::KIFSD::FSD::config(quick_access_bar_data) [lreplace	\
			${::KIFSD::FSD::config(quick_access_bar_data)}		\
			$current_item_index $current_item_index $data		\
		]
		refresh_quick_access_bar
	}

	## Select icon in quick access bar edit dialog
	 # @parm Int index - Icon index [0; 4]
	 # @return void
	public method qa_panel_dialog_icon {index} {
		for {set i 0} {$i < 4} {incr i} {
			${win}.qa_panel_dialog.labelframe.button_$i configure -style Flat.TButton
		}
		${win}.qa_panel_dialog.labelframe.button_$index configure -style TButton
		set ::KIFSD::FSD::qa_panel_dialog_icon $index
	}

	## EntryBox validator
	 # If the content was an empty string then set entry background color to red
	 # @parm Widget widget	- EntryBox widget
	 # @parm String content	- EntryBox content
	 # @return Bool - Always 1
	proc not_empty_entry_validator {widget content} {
		if {![string length $content]} {
			$widget configure -style StringNotFound.TEntry
		} else {
			$widget configure -style TEntry
		}
		return 1
	}

	## Invoke dialog for editing entries in the quick access bar
	 # Auxiliary procedure for:
	 #	* quick_access_panel_add_entry
	 #	* quick_access_panel_edit_entry
	 # @parm String title	- Dialog title
	 # @parm Int icon	- Icon number [0;3]
	 # @parm String name	- Item name
	 # @parm String url	- Target URL
	 # @return List - {new_icon_number new_name new_url}
	private method qa_panel_dialog {title icon name url} {
		# Create dialog window
		set dialog [toplevel ${win}.qa_panel_dialog -class {Configuration dialog} -bg ${::COMMON_BG_COLOR}]

		# Set dialog variables
		set ::KIFSD::FSD::qa_panel_dialog_icon		$icon
		set ::KIFSD::FSD::qa_panel_dialog_name_entry	$name
		set ::KIFSD::FSD::qa_panel_dialog_url_entry	$url

		## Create main frame (Name: and URL:)
		set mid_frame [frame $dialog.middle]
		 # Label: "Name"
		grid [label $mid_frame.name_lbl	\
			-text [::mc "Name"]	\
		] -row 0 -column 0 -sticky w
		 # Label: "URL"
		grid [label $mid_frame.url_lbl	\
			-text [::mc "URL"]	\
		] -row 1 -column 0 -sticky w
		 # EntryBox: "Name"
		grid [ttk::entry $mid_frame.name_entry						\
			-width 1								\
			-validate all								\
			-validatecommand "::KIFSD::FSD::not_empty_entry_validator %W %P"	\
			-textvariable ::KIFSD::FSD::qa_panel_dialog_name_entry			\
		] -row 0 -column 1 -sticky we
		 # EntryBox: "URL"
		grid [ttk::entry $mid_frame.url_entry				\
			-width 1						\
			-validate all						\
			-textvariable ::KIFSD::FSD::qa_panel_dialog_url_entry	\
			-validatecommand "::KIFSD::FSD::dir_validate {} %W %P"	\
		] -row 1 -column 1 -sticky we
		grid columnconfigure $mid_frame 1 -weight 1
		pack $mid_frame -padx 10 -pady 5 -fill x -expand 1

		# Create frame for selecting icon
		pack [ttk::labelframe $dialog.labelframe	\
			-text [::mc "Icon"]			\
		] -fill none -expand 1 -anchor w -padx 10
		foreach icon {hdd_unmount folder_home desktop bookmark_folder} index {0 1 2 3} {
			pack [ttk::button $dialog.labelframe.button_$index	\
				-image ::ICONS::22::$icon			\
				-command "$this qa_panel_dialog_icon $index"	\
				-width 6					\
				-style Flat.TButton				\
			] -side left -padx 5 -pady 5
		}
		$dialog.labelframe.button_${::KIFSD::FSD::qa_panel_dialog_icon}	\
			configure -style TButton

		## Create bottom frame (Buttons "Ok" and "Cancel")
		set bot_frame [frame $dialog.bot]
		 # Button: "Ok"
		pack [ttk::button $bot_frame.ok	\
			-text [::mc "Ok"]	\
			-compound left		\
			-image ::ICONS::16::ok	\
			-command "
				if \[string length \${::KIFSD::FSD::qa_panel_dialog_name_entry}\] {
					if \[string length \${::KIFSD::FSD::qa_panel_dialog_url_entry}\] {
						grab release $dialog
						destroy $dialog
					}
				}"	\
		] -side left -fill none -expand 0 -padx 2
		 # Button: "Cancel"
		pack [ttk::button $bot_frame.cancel		\
			-text [::mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command "
				set ::KIFSD::FSD::qa_panel_dialog_url_entry	{}
				set ::KIFSD::FSD::qa_panel_dialog_name_entry	{}
				set ::KIFSD::FSD::qa_panel_dialog_icon		{}
				grab release $dialog
				destroy $dialog"	\
		] -side left -fill none -expand 0 -padx 2
		pack $bot_frame -anchor e -padx 10 -pady 5

		# Configure dialog window
		wm title $dialog $title
		wm resizable $dialog 0 0
		wm geometry $dialog 380x160
		wm protocol $dialog WM_DELETE_WINDOW "
			set ::KIFSD::FSD::qa_panel_dialog_url_entry	{}
			set ::KIFSD::FSD::qa_panel_dialog_name_entry	{}
			set ::KIFSD::FSD::qa_panel_dialog_icon		{}
			grab release $dialog
			destroy $dialog
		"
		wm transient $dialog $win
		grab $dialog
		raise $dialog
		focus -force $mid_frame.name_entry
		tkwait window $dialog

		# Return results
		return [list	\
			${::KIFSD::FSD::qa_panel_dialog_icon}		\
			${::KIFSD::FSD::qa_panel_dialog_name_entry}	\
			${::KIFSD::FSD::qa_panel_dialog_url_entry}	\
		]
	}

	## Remove entry from quick access bar (popup menu action)
	 # @return void
	public method quick_access_panel_remove_entry {} {
		set ::KIFSD::FSD::config(quick_access_bar_data)	\
			[lreplace ${::KIFSD::FSD::config(quick_access_bar_data)}	\
				$current_item_index $current_item_index]
		refresh_quick_access_bar
	}

	## Invoke popup menu for directories ListBox
	 # @parm Int x - Relative position of mouse pointer
	 # @parm Int y - Relative position of mouse pointer
	 # @return void
	public method dir_listbox_menu {x y} {
		if {$item_menu_request} {
			set item_menu_request 0
			return
		}
		foreach entry {Rename Delete Properties {Bookmark folder}} {
			$win.listbox_menu entryconfigure [mc $entry] -state disabled
		}
		tk_popup $win.listbox_menu $x $y
	}

	## Invoke popup menu for item in directories ListBox
	 # @parm Int x		- Relative position of mouse pointer
	 # @parm Int y		- Relative position of mouse pointer
	 # @parm String item	- Item identifier
	 # @return void
	public method dir_listbox_item_menu {x y item} {
		set item_menu_request 1
		foreach entry {Rename Delete Properties {Bookmark folder}} {
			$win.listbox_menu entryconfigure [mc $entry] -state normal
		}
		set cur_listbox {dir}
		set current_item $item
		set current_item_index [$dir_listbox index $item]
		tk_popup $win.listbox_menu $x $y
	}

	## Invoke popup menu for files ListBox
	 # @parm Int x - Relative position of mouse pointer
	 # @parm Int y - Relative position of mouse pointer
	 # @return void
	public method file_listbox_menu {x y} {
		if {$item_menu_request} {
			set item_menu_request 0
			return
		}
		foreach entry {Rename Delete Properties} {
			$win.listbox_menu entryconfigure [mc $entry] -state disabled
		}
		$win.listbox_menu entryconfigure [mc {Bookmark folder}] -state normal
		tk_popup $win.listbox_menu $x $y
	}

	## Invoke popup menu for item in files ListBox
	 # @parm Int x		- Relative position of mouse pointer
	 # @parm Int y		- Relative position of mouse pointer
	 # @parm String item	- Item identifier
	 # @return void
	public method file_listbox_item_menu {x y item} {
		set item_menu_request 1
		set current_item $item
		set current_item_index [$file_listbox index $item]
		foreach entry {Rename Delete Properties {Bookmark folder}} {
			$win.listbox_menu entryconfigure [mc $entry] -state normal
		}
		set cur_listbox {file}
		set current_item $item
		set current_item_index [$file_listbox index $item]
		tk_popup $win.listbox_menu $x $y
	}

	## Remove selected file or directory
	 # @return void
	public method delete_item_command {} {
		# Determinate URL to delete
		if {$cur_listbox == {dir}} {
			set filename [$dir_listbox itemcget $current_item -text]
		} else {
			set data [$file_listbox itemcget $current_item -data]
			if {[lindex $data 0] == {}} {
				set filename [lindex $data 1]
			} else {
				set filename [lindex $data 0]
			}
		}
		if {$filename == {}} {return}

		# Invoke confirmation dialog
		if {[tk_messageBox			\
			-parent $win			\
			-type yesno			\
			-icon question			\
			-title [::mc "Delete file"]	\
			-message [::mc "Do you really want to delete file:\n%s" $filename]]
				==
			{yes}
		} then {
			# Delete file/directory (+ invoke error dialog)
			if {[catch {file delete -force -- [file join $current_directory $filename]}]} {
				tk_messageBox		\
					-parent $win	\
					-type ok	\
					-icon warning	\
					-title [::mc "Permission denied"]	\
					-message [::mc "Unable to remove file:\n%s" $filename]
			}
		}
		reload
	}

	## Bookmark selected folder
	 # @return void
	public method item_bookmark_add {} {
		set tmp $current_directory
		if {$cur_listbox == {dir}} {
			set current_directory [file join $current_directory	\
				[$dir_listbox itemcget $current_item -text]]
		}
		add_bookmark
		set current_directory $tmp
	}

	## Rename selected file or directory
	 # @return void
	public method rename_item_command {} {
		if {$cur_listbox == {dir}} {
			set listbox $dir_listbox
		} else {
			set listbox $file_listbox
		}

		# Determinate old and new name
		set original [$listbox itemcget $current_item -text]
		set newname [$listbox edit $current_item	\
			[$listbox itemcget $current_item -text]]
		if {$newname == {}} {
			return
		}

		# Adjust old and new name
		set original [file join $current_directory $original]
		set newname [file join $current_directory $newname]

		# Rename file
		if {[catch {file rename -force $original $newname}]} {
			tk_messageBox		\
				-parent $win	\
				-type ok	\
				-icon warning	\
				-title [::mc "Permission denied"]	\
				-message [::mc "Unable to rename file:\n%s" $original]
		}
		reload
	}

	## Invoke item properties dialog
	 # @return void
	public method properties_item_command {} {
		# Determinate item name, type (File or Directory)
		if {$cur_listbox == {dir}} {
			set name [$dir_listbox itemcget $current_item -text]
			set type "Directory"
		} else {
			set name [$file_listbox itemcget $current_item -data]
			if {[lindex $name 0] == {}} {
				set name [lindex $name 1]
				set type "Directory"
			} else {
				set name [lindex $name 0]
				set type "File"
			}
		}

		# Determinate full name
		set fullname [file join $current_directory $name]
		if {![file exists $fullname]} {
			tk_messageBox		\
				-parent $win	\
				-type ok	\
				-icon warning	\
				-title [::mc "Unknown Error"]	\
				-message [::mc "This file apparently does not exist"]
			return
		}
		# Determinate size
		set size [file size $fullname]
		append size { B}
		# Determinate time of the last mofication
		set modified [clock format [file mtime $fullname] -format {%D %R}]
		# Determinate time of the last access
		set accessed [clock format [file atime $fullname] -format {%D %R}]
		# Determinate group, owner and permissions
		if {!$::MICROSOFT_WINDOWS} { ;# Microsoft Windows has no file rights (compatible with posix rights)
			set perms [file attributes $fullname]
			set group [lindex $perms 1]
			set owner [lindex $perms 3]
			set perms [lindex $perms 5]
			set perms [string range $perms {end-3} end]
			foreach var	{ur	uw	ux	gr	gw	gx	or	ow	ox} \
				mask	{0400	0200	0100	040	020	010	04	02	01} \
			{
				set ::KIFSD::FSD::item_properties($var) [expr {($perms & $mask) > 0}]
			}
		}

		# Create dialog window and Notebook
		set dialog [toplevel $win.properties_dialog -class {Configuration dialog} -bg ${::COMMON_BG_COLOR}]
		set nb [ModernNoteBook $dialog.nb]
		$nb insert end general -text "General"
		if {!$::MICROSOFT_WINDOWS} { ;# Microsoft Windows has no file rights (compatible with posix rights)
			$nb insert end permission -text "Permissions"
		}
		$nb raise general

		## Create GUI elements for tag "General"
		set frame [frame [$nb getframe general].frame]
		pack $frame -side top -anchor n -fill x -expand 1
		 # Name:
		set row 0
		grid [label $frame.lbl_$row		\
			-text [::mc "Name:"] -anchor w	\
			-font $listbox_font_short	\
		] -column 0 -row $row -sticky w -pady 3
		set ::KIFSD::FSD::item_properties(name) $name
		grid [ttk::entry $frame.val_lbl_$row						\
			-validate all								\
			-textvariable ::KIFSD::FSD::item_properties(name)			\
			-validatecommand "::KIFSD::FSD::not_empty_entry_validator %W %P"	\
		] -column 1 -row $row -sticky w -pady 3
		 # Type, Location, Size, Modified, Accessed
		incr row
		foreach	lbl [list "Type" "Location" "Size" "Modified" "Accessed"]	\
			value [list $type $current_directory $size $modified $accessed]	\
		{
			grid [label $frame.lbl_$row		\
				-text "[::mc $lbl]:" -anchor w	\
				-font $listbox_font_short	\
			] -column 0 -row $row -sticky w -pady 3
			grid [label $frame.val_lbl_$row		\
				-text $value -anchor w		\
			] -column 1 -row $row -sticky w -pady 3
			incr row
		}
		grid columnconfigure $frame 0 -minsize 100

		## Create GUI elements for tag "Permissions"
		if {!$::MICROSOFT_WINDOWS} { ;# Microsoft Windows has no file rights (compatible with posix rights)
			set frame [$nb getframe permission]
			set ap_frame [ttk::labelframe $frame.ap_frame	\
				-text [::mc "Access permissions"]	\
			]
			set i 0
			foreach	text [list "Class" "Read" "Write" "Exec" "Owner" "Group" "Others"]	\
				row {0 0 0 0 1 2 3}	\
				col {0 1 2 3 0 0 0}	\
			{
				grid [label $ap_frame.lbl_$i	\
					-text [::mc $text]	\
					-justify center		\
				] -row $row -column $col -sticky w -padx 4 -pady 4
				incr i
			}
			foreach	var {ur uw ux gr gw gx or ow ox}	\
				row {1 1 1 2 2 2 3 3 3}	\
				col {1 2 3 1 2 3 1 2 3}	\
			{
				grid [checkbutton $ap_frame.check_$i	\
					-variable ::KIFSD::FSD::item_properties($var)
				] -row $row -column $col
				incr i
			}

			grid columnconfigure $ap_frame 0 -minsize 70
			grid columnconfigure $ap_frame 0 -weight 1
			pack $ap_frame -side top -fill x -expand 1 -padx 5 -pady 5 -anchor nw

			set own_frame [ttk::labelframe $frame.own_frame	\
				-text [::mc "Ownership"]			\
			]
			grid [label $own_frame.owner_lbl			\
				-text [::mc "Owner"] -font $listbox_font_short	\
			] -row 0 -column 0 -padx 10 -pady 3 -sticky w
			grid [label $own_frame.owner_val_lbl	\
				-text $owner -anchor w		\
			] -row 0 -column 1 -padx 10 -pady 3 -sticky we
			grid [label $own_frame.group_lbl			\
				-text [::mc "Group"] -font $listbox_font_short	\
			] -row 1 -column 0 -padx 10 -pady 3 -sticky w
			grid [label $own_frame.group_val_lbl	\
				-text $group -anchor w		\
			] -row 1 -column 1 -padx 10 -pady 3 -sticky we
			grid columnconfigure $own_frame 0 -minsize 70
			grid columnconfigure $own_frame 1 -weight 1
			pack $own_frame -side top -fill x -expand 1 -padx 5 -pady 5
		}

		# Create bottom frame (buttons: "Ok" and "Cancel")
		set bottom_frame [frame $dialog.bottom_frame]
		pack [ttk::button $bottom_frame.ok				\
			-text [::mc "Ok"]					\
			-compound left						\
			-image ::ICONS::16::ok					\
			-command "$this properties_ok $dialog $fullname"	\
		] -side left -padx 2
		pack [ttk::button $bottom_frame.cancel		\
			-text [::mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command "
				grab release $dialog
				destroy $dialog
			"	\
		] -side left -padx 2

		# Pack notebook and bottom frame
		pack [$nb get_nb] -fill both -expand 1 -padx 10 -pady 5
		pack $bottom_frame -anchor e -after [$nb get_nb] -padx 10 -pady 5

		# Configure dialog window
		wm title $dialog [::mc "Item properties"]
		wm minsize $dialog 280 320
		wm protocol $dialog WM_DELETE_WINDOW "
			grab release $dialog
			destroy $dialog"
		wm transient $dialog $win
		grab $dialog
		raise $dialog
		tkwait window $dialog
	}

	## Confirm item properties dialog
	 # @parm Widget dialog	- Dialog window
	 # @parm String file	- File URL
	 # @return void
	public method properties_ok {dialog file} {
		set error 0
		set perm 0

		if {!$::MICROSOFT_WINDOWS} { ;# Microsoft Windows has no file rights (compatible with posix rights)
			foreach	var {ur uw ux gr gw gx or ow ox} \
				val {256 128 64 32 16 8 4 2 1} {
				if {$::KIFSD::FSD::item_properties($var)} {
					incr perm $val
				}
			}
			if {[catch {file attributes $file -permissions "0[format {%o} $perm]"}]} {
				set error 1
				tk_messageBox				\
					-type ok			\
					-icon warning			\
					-parent $dialog			\
					-title [::mc "Permission denied"]	\
					-message [::mc "Unable to change permissions for file:\n%s" [file tail $file]]
			}
		}
		set dir [file dirname $file]

		if {${::KIFSD::FSD::item_properties(name)} != [file tail $file]} {
			if {[catch {
				file rename -force --	\
					$file [file join $dir	\
						${::KIFSD::FSD::item_properties(name)}]}]
			} then {
				set error 1
				tk_messageBox				\
					-type ok			\
					-icon warning			\
					-parent $dialog			\
					-title [::mc "Permission denied"]	\
					-message [::mc "Unable to rename file:%s" "\n[file tail $file]\n\t=>\n${::KIFSD::FSD::item_properties(name)}"]
			}
			reload
		}

		if {!$error} {
			grab release $dialog
			destroy $dialog
		}
	}

	## Validate EntryBox containing directory location (set background color: red/white)
	 # @parm widget combobox	- ComboBox widget or {}
	 # @parm Widget widget		- EntryBox widget
	 # @parm String content		- EntryBox content
	 # @return Bool - Always 1
	proc dir_validate {combobox widget content} {
		if {![file exists $content] || ![file isdirectory $content]} {
			if {$combobox != {}} {
				$combobox configure -style FSD_RedBg.TCombobox
			} else {
				$widget configure -style FSD_RedBg.TEntry
			}
		} else {
			if {$combobox != {}} {
				$combobox configure -style TCombobox
			} else {
				$widget configure -style TEntry
			}

			# Fill directory location combobox
			if {$combobox != {}} {
				set folder $content
				set values {}
				while {1} {
					lappend values $folder
					if {$folder == [file separator]} {break}
					if {$::MICROSOFT_WINDOWS} {
						if {[regexp {^\w+:[\\\/]?$} $folder]} {break}
					}
					set folder [file normalize [file join $folder {..}]]
				}
				foreach folder [::KIFSD::FSD::dir_cmd $content 1] {
					if {$folder == {..}} {continue}
					lappend values [file join $content $folder]
				}
				if {$::MICROSOFT_WINDOWS} { ;# Include drive letters on Microsoft Windows
					foreach drive_letter {A B C D E F G H I J K L M N O P Q R S T U V W X Y Z} {
						if {[file exists "${drive_letter}:/"]} {
							lappend values "${drive_letter}:/"
						}
					}
				}
				$combobox configure -values $values
			}
		}
		return 1
	}

	## Reload content of directories ListBox and files ListBox
	 # @param List args - all arguments are ignored
	 # @return void
	public method reload {args} {
		update idletasks
		change_directory $current_directory
	}

	## Modify command for directory ComboBox
	 # @return void
	public method dir_cb_modify {} {
		change_directory [$dir_combobox get]
	}

	## Go to parrent folder
	 # @return void
	public method up {} {
		change_directory [file normalize [file join $current_directory {..}]]
	}

	## Go back in history
	 # @return void
	public method back {} {
		# Determinate new folder
		set folder [lindex $back_history end]
		if {$folder == {}} {return}

		# Adjust backward and forward history
		set back_history [lreplace $back_history end end]
		lappend forward_history $current_directory

		# Make backup copy of backward and forward history
		set tmp_forw_hist $forward_history
		set tmp_back_hist $back_history

		# Change current directory
		change_directory $folder

		# Restore backward and forward history
		set forward_history $tmp_forw_hist
		set back_history $tmp_back_hist

		# Enable / Disable buttons "Back" and "Forward"
		if {![llength $back_history]} {
			$toolbar.back configure -state disabled
			$win.listbox_menu entryconfigure [mc "Back"] -state disabled
		} else {
			$toolbar.back configure -state normal
			$win.listbox_menu entryconfigure [mc "Back"] -state normal
		}
		$win.listbox_menu entryconfigure [mc "Forward"] -state normal
		$toolbar.forward configure -state normal
	}

	## Go forward in history
	 # @return void
	public method forward {} {
		# Determinate new folder
		set folder [lindex $forward_history end]
		if {$folder == {}} {return}

		# Adjust backward and forward history
		set forward_history [lreplace $forward_history end end]
		lappend back_history $current_directory

		# Make backup copy of backward and forward history
		set tmp_forw_hist $forward_history
		set tmp_back_hist $back_history

		# Change current directory
		change_directory $folder

		# Restore backward and forward history
		set forward_history $tmp_forw_hist
		set back_history $tmp_back_hist

		# Enable / Disable buttons "Back" and "Forward"
		if {![llength $forward_history]} {
			$toolbar.forward configure -state disabled
			$win.listbox_menu entryconfigure [mc "Forward"] -state disabled
		} else {
			$toolbar.forward configure -state normal
			$win.listbox_menu entryconfigure [mc "Forward"] -state normal
		}
		$toolbar.back configure -state normal
		$win.listbox_menu entryconfigure [mc "Back"] -state normal
	}

	## Invoke dialog to create a new directory
	 # @return void
	public method newdir {} {
		# Create dialog window
		set dialog [toplevel $win.new_dir -class {New directory} -bg ${::COMMON_BG_COLOR}]

		# Create dialog header and EntryBox
		pack [label $dialog.header -justify left -text [mc "Create new folder in:\n%s" $current_directory]]	\
			-side top -anchor w -padx 15 -pady 5
		pack [ttk::entry $dialog.entry	\
		] -side top -fill x -expand 1 -padx 5 -pady 5

		# Bind button enter to confirmation action
		bind $dialog.entry <Return>	"[list $this create_new_folder]; break"
		bind $dialog.entry <KP_Enter>	"[list $this create_new_folder]; break"

		# Create bottom frame (Buttons: "Clear", "Ok" and "Cancel")
		set button_frame [frame $dialog.bottom]
		pack [ttk::button $button_frame.clear		\
			-text [mc "Clear"]			\
			-compound left				\
			-image ::ICONS::16::clear_left		\
			-command "$dialog.entry delete 0 end"	\
		] -side left -expand 0 -padx 2
		pack [ttk::button $button_frame.ok		\
			-text [mc "Ok"]				\
			-compound left				\
			-image ::ICONS::16::ok			\
			-command [list $this create_new_folder]	\
		] -side left -expand 0 -padx 2
		pack [ttk::button $button_frame.cancel		\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command "
				grab release $dialog
				destroy $dialog
			"	\
		] -side left -expand 0 -padx 2
		pack $button_frame -side bottom -anchor e -expand 0 -padx 5 -pady 5

		# Configure dialog window
		wm iconphoto $dialog ::ICONS::16::folder_new
		wm title $dialog [mc "New folder"]
		wm resizable $dialog 1 0
		wm minsize $dialog 340 120
		wm geometry $dialog 340x120
		wm protocol $dialog WM_DELETE_WINDOW "
			grab release $dialog
			destroy $dialog
		"
		wm transient $dialog $win
		grab $dialog
		raise $dialog
		focus -force $dialog.entry
		tkwait window $dialog
	}

	## Confirm dialog "Create new folder"
	 # @return void
	public method create_new_folder {} {
		set dialog ${win}.new_dir
		set folder [$dialog.entry get]
		set error 0

		if {$folder == {}} {
			set error 1
		}
		if {$error || [catch {file mkdir [file join $current_directory $folder]}]} {
			tk_messageBox		\
				-parent $dialog	\
				-icon warning	\
				-type ok	\
				-title [mc "Unable to create folder"] \
				-message [mc "Unable to create the specified folder"]
		} else {
			grab release $dialog
			destroy $dialog
			reload
		}
	}

	## Sort the given list of strings
	 # This procedure is closely related to inner logic of this
	 #+ class and it is difficult to properly explain its function
	 # @parm List items - List to sort
	 # @return void
	proc sort_items {items} {
		# Determinate sorting order
		if {${::KIFSD::FSD::config(reverse_sorting)}} {
			set order "-decreasing"
		} else {
			set order "-increasing"
		}

		if {${::KIFSD::FSD::config(sorting)} == {name}} {
			if {${::KIFSD::FSD::config(case_insensitive)}} {
				set method "-dictionary"
			} else {
				set method "-ascii"
			}
			return [lsort $method $order $items]
		} else {
			if {${::KIFSD::FSD::config(sorting)} == {size}} {
				# Sort by size
				set index 2
			} else {
				# Sort by date
				set index 1
			}
			set items [lsort -index $index $order $items]

			set result {}
			foreach file $items {
				lappend result [lindex $file 0]
			}
			return $result
		}
	}

	## Get unsorted list of subdirectories in the given directory
	 # @parm String dir - Directory
	 # @return List - List of relative URLs
	proc get_dirs_simple {dir} {
		# Search for directories
		set result [list]
		catch {	;# For Microsoft Windows it has to be enclosed by catch
			set result [glob -nocomplain -tails -directory $dir -types d *]
		}

		# Include hidden directories
		if {${::KIFSD::FSD::config(show_hidden_files)}} {
			catch {	;# For Microsoft Windows it has to be enclosed by catch
				set result [concat $result [glob -nocomplain -tails -directory $dir -types {d hidden} *]]
			}

			# Filter "." and ".."
			set foo_idx [lsearch $result {..}]
			if {$foo_idx != -1} {
				set result [lreplace $result $foo_idx $foo_idx]
				set foo_idx [lsearch $result {.}]
				if {$foo_idx != -1} {
					set result [lreplace $result $foo_idx $foo_idx]
				}
			}
		}

		return $result
	}

	## Get unsorted list of subdirectories in the given directory
	 # @parm String dir - Directory
	 # @return List - {{relative_URL mtime size_in_B} ... }
	proc get_dirs_extended {dir} {
		set result {}

		# Search for directories
		catch {	;# For Microsoft Windows it has to be enclosed by catch
			foreach file [glob -nocomplain -tails -directory $dir -types d *] {
				lappend result [list $file [file mtime [file join $dir $file]] 0]
			}
		}

		# Include hidden directories
		if {${::KIFSD::FSD::config(show_hidden_files)}} {
			catch {	;# For Microsoft Windows it has to be enclosed by catch
				foreach file [glob -nocomplain -tails -directory $dir -types {d hidden} *] {
					# Filter "." and ".."
					if {$file == {.} || $file == {..}} {
						continue
					}
					# Translate to full URL
					lappend result [list $file [file mtime [file join $dir $file]] 0]
				}
			}
		}

		return $result
	}

	## Get unsorted list of files in the given directory matching the given GLOB
	 # @parm String dir	- Directory
	 # @parm GLOB mask	- Glob expression
	 # @return List - List of relative URLs
	proc get_files_simple {dir mask} {
		set result [list]
		catch {	;# For Microsoft Windows it has to be enclosed by catch
			set result [glob -nocomplain -tails -directory $dir -types f $mask]
		}
		if {${::KIFSD::FSD::config(show_hidden_files)}} {
			catch {	;# For Microsoft Windows it has to be enclosed by catch
				set result [concat $result 	\
					[glob -nocomplain -tails -directory $dir -types {f hidden} $mask]]
			}
		}
		return $result
	}

	## Get unsorted list of files in the given directory matching the given GLOB
	 # @parm String dir	- Directory
	 # @parm GLOB mask	- Glob expression
	 # @return List - {{relative_URL mtime size_in_B} ... }
	proc get_files_extended {dir mask} {
		set result {}

		# Search for files matching the given GLOB
		catch {	;# For Microsoft Windows it has to be enclosed by catch
			foreach file [glob -nocomplain -tails -directory $dir -types f $mask] {
				if {[catch {
					lappend result [list				\
						$file					\
						[file mtime [file join $dir $file]]	\
						[file size [file join $dir $file]]	\
					]
				}]} then {
					lappend result [list $file 0 0]
				}
			}
		}

		# Include hidden files
		if {${::KIFSD::FSD::config(show_hidden_files)}} {
			catch {	;# For Microsoft Windows it has to be enclosed by catch
				foreach file [glob -nocomplain -tails -directory $dir -types {f hidden} $mask] {
					if {[catch {
						lappend result [list				\
							$file					\
							[file mtime [file join $dir $file]]	\
							[file size [file join $dir $file]]	\
						]
					}]} then {
						lappend result [list $file 0 0]
					}
				}
			}
		}
		return $result
	}

	## Get list of items to load to directories ListBox
	 # @parm String dir		- Source directory
	 # @parm Bool no_detail=0	- No details
	 # @return List - {text text ...}
	proc dir_cmd {dir {no_detail 0}} {
		# Normalize directory and determinate its parent
		set dir [file normalize $dir]
		if {$dir != {/}} {
			set parent {..}
		} else {
			set parent {}
		}


		if {${::KIFSD::FSD::config(sorting)} == {name}} {
			set result [sort_items [get_dirs_simple $dir]]
		} else {
			set result [sort_items [get_dirs_extended $dir]]
		}

		if {!$no_detail && ${::KIFSD::FSD::config(detailed_view)}} {
			return [concat $parent [add_details $result $dir]]
		} else {
			return [concat $parent $result]
		}
	}

	## Get list of items to load to files ListBox
	 # @parm String dir		- Source directory
	 # @parm GLOB mask		- GLOB expression which must match each returned file
	 # @parm Bool no_detail=0	- Detailed view
	 # @return List - {text text ...}
	proc file_cmd {dir mask {no_detail 0}} {
		if {${::KIFSD::FSD::config(sorting)} == {name}} {
			set result [sort_items [get_files_simple $dir $mask]]
		} else {
			set result [sort_items [get_files_extended $dir $mask]]
		}
		if {!$no_detail && ${::KIFSD::FSD::config(detailed_view)}} {
			return [add_details $result $dir]
		} else {
			return $result
		}
	}

	## Adjust list of files/directories returned by proc. file_cmd to
	 #+ format required to display in detailed view mode
	 # @parm List filelist	- List returned by procedure file_cmd
	 # @parm String dir	- Directory
	 # @return List - {{text text text ... } ... }
	proc add_details {filelist dir} {
		set result {}
		foreach filename $filelist {
			set line $filename
			set fullfilename [file join $dir $filename]
			if {[string length $line] > 31} {
				set line [string range $line 0 27]
				append line {...}
			}
			if {[catch {
				append line [string repeat { } [expr {35 - [string length $line]}]]
				set size [file size $fullfilename]
				if {$size < 1024} {
					append size { B}
				} elseif {$size < 1048576} {
					set size [expr {($size * 10) / 1024}]
					if {$size > 1023} {
						set size [expr {$size / 10}]
					} else {
						set size [string range $size 0 {end-1}].[string range $size end end]
					}
					append size { kB}
				} elseif {$size < 1073741824} {
					set size [expr {($size * 10) / 1048576}]
					if {$size > 1023} {
						set size [expr {$size / 10}]
					} else {
						set size [string range $size 0 {end-1}].[string range $size end end]
					}
					append size { MB}
				} elseif {$size < 1099511627776} {
					set size [expr {($size * 10) / 1073741824}]
					if {$size > 1023} {
						set size [expr {$size / 10}]
					} else {
						set size [string range $size 0 {end-1}].[string range $size end end]
					}
					append size { GB}
				} else {
					set size {>1TB}
				}
			}]} then {
				append line {   -       ----   -------- -----}
			} else {
				if {!$::MICROSOFT_WINDOWS} {
					append line [string repeat { } [expr {8 - [string length $size]}]] $size "   "	\
						[string range [lindex [file attributes $fullfilename] 5] {end-3} end] "   " \
						[clock format [file mtime $fullfilename] -format {%D %R}]
				} else {
					append line [string repeat { } [expr {8 - [string length $size]}]] $size "  "	\
						[clock format [file mtime $fullfilename] -format {%D %R}]
				}
			}
			lappend result [list $line $filename]
		}
		return $result
	}

	## Get list of items to load to files ListBox (mode "Separate folders" OFF)
	 # @parm String dir	- Source directory
	 # @parm GLOB mask	- GLOB expression which must match each returned file
	 # @return List - {text text ...}
	proc dir_file_cmd {dir mask} {
		set dir [file normalize $dir]
		set result {}

		# Determinate list of directories
		if {${::KIFSD::FSD::config(sorting)} == {name}} {
			set result [concat [get_dirs_simple $dir] [get_files_simple $dir $mask]]
		} else {
			set result [concat [get_dirs_extended $dir] [get_files_extended $dir $mask]]
		}
		if {$dir != {/}} {
			set parent [list [list {..} {u}]]
		} else {
			set parent {}
		}
		set tmp_result {}

		# Determinate list of files
		if {${::KIFSD::FSD::config(detailed_view)}} {
			foreach item [sort_items $result] {
				if {![file exists [file join $dir $item]]} {continue}
				if {[file isdirectory [file join $dir $item]]} {
					lappend tmp_result [concat [add_details [list $item] $dir] d]
				} else {
					lappend tmp_result [concat [add_details [list $item] $dir] f]
				}
			}
		} else {
			foreach item [sort_items $result] {
				if {![file exists [file join $dir $item]]} {continue}
				if {[file isdirectory [file join $dir $item]]} {
					lappend tmp_result [list $item d]
				} else {
					lappend tmp_result [list $item f]
				}
			}
		}
		return [concat $parent $tmp_result]
	}

	## Get configuration list for procedure load_config_array
	 # @return List - (List which specifies bookmarks, settings and such things)
	proc get_config_array {} {
		return [regsub -all "\n" [array get ::KIFSD::FSD::config] { }]
	}

	## Load configuration list returned by procedure get_config_array
	 # @parm List config - (List which specifies bookmarks, settings and such things)
	 # @return void
	proc load_config_array {config} {
		if {$config == {}} {
			return
		}

		if {[catch {
			array set ::KIFSD::FSD::config $config
		}]} then {
			puts stderr "KI File Selection Dialog: Unable to load the given configuration string -- using default"
			return 0
		} else {
			return 1
		}
	}

	## Get descriptor of dialog window
	 # @return Widget - Dialog window
	public method get_window_name {} {
		return $win
	}

	## Determinate path to the "Desktop" folder.
	 # @return String - The path, e.g. "~/Arbeitsfläche" in case of German Ubuntu.
	proc get_desktop_dir {} {
		if {![catch {
			set f [open "~/.config/user-dirs.dirs" "r"]
		}]} then {
			while {![eof $f]} {
				set l [gets $f]
				if {[string first "XDG_DESKTOP_DIR=" $l] != -1} {
					if {[regexp {"[^\"]+"} $l d]} {
						set d [string range $d 1 end-1]
						regsub {\$HOME} $d {~} d
						return $d
					}
				}
			}
			close $f
		}
		return "~/Desktop"
	}
}

## Text variables for dialog "Edit entry in Quick access bar"
set KIFSD::FSD::qa_panel_dialog_url_entry	{}	;# Entry URL
set KIFSD::FSD::qa_panel_dialog_name_entry	{}	;# Entry name
set KIFSD::FSD::qa_panel_dialog_icon		{}	;# Icon number [0;3]

## Dialog configuration array (these values are daults)
 # Invalid configuration list may cause program error !
array set KIFSD::FSD::config {
	win_geometry		{720x380}
	detailed_view		0
	separate_folders	1
	quick_access_panel	1
	sorting			name
	reverse_sorting		0
	folders_first		1
	case_insensitive	1
	show_hidden_files	0
	right_PW_size		200
	main_PW_size		180
	bookmarks		{}
}

if {$::MICROSOFT_WINDOWS} {
	set KIFSD::FSD::config(quick_access_bar_data) [subst {
		{0	{System Drive ${::env(SystemDrive)}}	{${::env(SystemDrive)}}}
		{1	{Documents and Settings}		{${::env(USERPROFILE)}}}
	}]
} else {
	set KIFSD::FSD::config(quick_access_bar_data) [subst {
		{0	{/}			{/}}
		{0	{Removable media}	{/media}}
		{1	{Home}			{~}}
		{2	{Desktop}		{[KIFSD::FSD::get_desktop_dir]}}
	}]
}

# >>> File inclusion guard
}
# <<< File inclusion guard

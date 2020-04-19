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
if { ! [ info exists _REGWATCHES_TCL ] } {
set _REGWATCHES_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements register watches (part of Right Panel)
# --------------------------------------------------------------------------

class RegWatches {

	## COMMON
	public common watches_set_shortcuts	{}		;# Currently set shortcuts for register watches
	public common watches_shortcuts_cat	{watches}	;# Key shortcut categories related to register watches
	# Counter of embedded entry widgets in register watches
	public common watch_entry_count	0
	# Conter of instances
	public common regw_count		0
	## Highlighting tags for register watches
	 # {
	 #	{tag_name foreground_color ?bold_or_italic?}
	 #	...
	 # }
	public common watch_text_tags {
		{tag_Baddr	#DD0000	1}
		{tag_Xaddr	#AA00FF	1}
		{tag_Eaddr	#00AAFF	1}
		{tag_addr	#0000DD	1}
		{tag_name	#8888DD {}}
	}
	public common regfont [font create -family $::DEFAULT_FIXED_FONT -size [expr {int(-14 * $::font_size_factor)}]]
	# Popup menu for register watches
	public common WATCHMENU {
		{command	{Move top}	{$watches:top}		0	"rightPanel_watch_move_top"
			{top}		"Move this register watch to the top of list"}
		{command	{Move up}	{$watches:up}		0	"rightPanel_watch_move_up"
			{1uparrow}	"Move this register watch up"}
		{command	{Move down}	{$watches:down}		1	"rightPanel_watch_move_down"
			{1downarrow}	"Move this register watch down"}
		{command	{Move bottom}	{$watches:bottom}	2	"rightPanel_watch_move_bottom"
			{bottom}	"Move this register watch to the bottom of list"}
		{separator}
		{command	{Remove}	{$watches:remove}	2	"rightPanel_watch_remove"
			{button_cancel}	"Remove this register watch from the list"}
		{separator}
		{command	{Remove all}	{$watches:remove_all}	0	"rightPanel_watch_clear"
			{editdelete}	"Clear the list of register watches"}
		{separator}
		{command	{Save}		{}	0	"rightPanel_watch_save {} 1"	{filesave}
			"Save this list to a file"}
		{command	{Configure}	{}	0	"rightPanel_configure 0"	{configure}
			"Configure this panel"}
	}
	# Configuration menu
	public common CONFMENU {
		{cascade	"Sort by"		0	""	.sort		false 1 {
			{command	"Name"		{}	0	"rightPanel_watch_sort_by N"	{}
				""}
			{command	"Address"	{}	0	"rightPanel_watch_sort_by A"	{}
				""}
			{command	"Type"		{}	0	"rightPanel_watch_sort_by T"	{}
				""}
			{separator}
			{radiobutton	"Incremental"			{}	::RegWatches::sorting_order	1
				{}	0	""}
			{radiobutton	"Decremental"			{}	::RegWatches::sorting_order	0
				{}	0	""}
		}}
		{command	"Remove all"		{}	0	"rightPanel_watch_clear"	{editdelete}
			""}
		{separator}
		{checkbutton	"Autoload from code listing"	{}	{::RegWatches::menu_autoload}	1 0 0
			{rightPanel_watch_toggle_autoload_flag}}
		{checkbutton	"Clear on auto-load"		{}	{::RegWatches::menu_autoclear}	1 0 0
			{rightPanel_watch_toggle_autoclear_flag}}
	}

	## PRIVATE
	private variable enabled	0	;# Bool: enable procedures which are needless while loading project
	private variable obj_idx		;# Number of this object
	private variable parent			;# Widget: parent widget
	private variable regw_gui_initialized 0	;# Bool: GUI initialized

	private variable conf_button		;# Widget: Configuration button
	private variable conf_menu	{}	;# Configuration menu
	private variable watch_menu		;# ID of popup menu for "Register watches"
	private variable watch_text		;# ID of text widget representing list of register watches
	private variable watch_remove_button	;# ID of button "Remove watch"	- Register watches
	private variable watch_new_button	;# ID of button "New watch"	- Register watches
	private variable watch_add_button	;# ID of button "Add watch"	- Register watches
	private variable watch_addr_entry	;# ID of entry "Address"	- Register watches
	private variable watch_search_entry	;# ID of entry "Search"		- Register watches
	private variable watch_search_clear	;# ID of button "Clear search entry" - Register watches

	# Bool: Autoload from LST file
	private variable autoload_flag		[lindex $::CONFIG(REGWATCHES_CONFIG) 0]
	private variable autoclear_flag		[lindex $::CONFIG(REGWATCHES_CONFIG) 2]
	private variable watches_modified	0	;# Bool: Register watches definition modified
	private variable search_val_in_progress	0	;# Bool: Search entry validation in porgress
	private variable watch_file_name	{}	;# Name of file currently loaded in register watches
	private variable watch_curLine		0	;# Current line in list of register watches
	private variable watch_AN_valid_ena	1	;# Bool: Enable validation of address entry in register watches
	private variable validator_engaged	0	;# Bool: Address entry validation in progress
	private variable watches_enabled	0	;# Bool: Entry widgets in register watches enabled

	private variable watch_addrs {}		;# List - {hex_addr hex_addr ...}
	## Array of Lists - info about particular watch
	 #	format: $watch_data($hex_addr) -> {regName textVariable}
	 #	note: embedded entry path == $watch_text.$textVariable
	private variable watch_data


	## Object constructor
	constructor {} {
		incr regw_count
		set obj_idx $regw_count
	}

	## Object destructor
	destructor {
		if {$regw_gui_initialized} {
			# Remove status bar tips for popup menus
			menu_Sbar_remove $watch_menu

			# Unallocate GUI related variables
			unset RightPanel::watch_addr$obj_idx
			unset RightPanel::watch_name$obj_idx
		}
	}

	## Prepare object for creating its GUI
	 # @parm Widget _parent		- GUI parent widget
	 # @parm String watches_file	- Definition file for register watches
	 # @return void
	public method PrepareRegWatches {_parent filename} {
		set parent $_parent
		set watch_file_name $filename
		set regw_gui_initialized 0
	}

	## Create GUI of register watches
	 # @return void
	public method CreateRegWatchesGUI {} {
		if {$regw_gui_initialized} {return}
		set regw_gui_initialized 1

		# Top frame
		set icon_bar	[frame $parent.frm_rightPanel_watch_iconBar]
		 # Bottom frame
		set text_frame	[frame $parent.frm_rightPanel_watch_txt]
		 # Toolbar
		set tool_bar	[frame $parent.frm_rightPanel_watch_toolBar]

		# Button "Configure"
		set button [ttk::button $icon_bar.conf_but		\
			-image ::ICONS::16::configure			\
			-command "$this rightPanel_watch_cfg_menu"	\
			-style Flat.TButton				\
		]
		set conf_button $button
		pack $button -side left -padx 3
		# Separator
		pack [ttk::separator $icon_bar.sep_rightPanel_watch_ib_sepm0	\
			-orient vertical					\
		] -side left -fill y -padx 3
		# Button "Save"
		set button [ttk::button $icon_bar.but_rightPanel_watch_save	\
			-image ::ICONS::16::filesave				\
			-command "$this rightPanel_watch_save {} 1"		\
			-style Flat.TButton					\
		]
		pack $button -side left -padx 3
		DynamicHelp::add $button -text [mc "Save"]
		setStatusTip -widget $button	\
			-text [mc "Save"]
		# Button "Save as"
		set button [ttk::button $icon_bar.but_rightPanel_watch_saveas	\
			-image ::ICONS::16::filesaveas				\
			-command "$this rightPanel_watch_saveas"		\
			-style Flat.TButton					\
		]
		pack $button -side left -padx 3
		DynamicHelp::add $button -text [mc "Save under a different file name"]
		setStatusTip -widget $button	\
			-text [mc "Save under a different file name"]
		# Separator
		pack [ttk::separator $icon_bar.sep_rightPanel_watch_ib_sep0	\
			-orient vertical					\
		] -side left -fill y -padx 3
		# Button "Open"
		set button [ttk::button $icon_bar.but_rightPanel_watch_open	\
			-image ::ICONS::16::fileopen				\
			-command "$this rightPanel_watch_open"			\
			-style Flat.TButton					\
		]
		pack $button -side left -padx 3
		DynamicHelp::add $button -text [mc "Open *.wtc file"]
		setStatusTip -widget $button	\
			-text [mc "Open *.wtc file"]
		# Button "Import"
		set button [ttk::button $icon_bar.but_rightPanel_watch_imp	\
			-image ::ICONS::16::fileimport				\
			-style Flat.TButton					\
			-command "$this rightPanel_watch_import"		\
		]
		pack $button -side left -padx 3
		DynamicHelp::add $button -text [mc "Import list of registers from code listing or WTC file"]
		setStatusTip -widget $button	\
			-text [mc "Import list of registers from *.lst or *.wtc file"]
		# Entry "Search"
		set watch_search_entry [ttk::entry $icon_bar.search_entry		\
			-validate key							\
			-width 0							\
			-validatecommand "$this rightPanel_watch_search_validate %P"	\
		]
		DynamicHelp::add $watch_search_entry	\
			-text [mc "Enter your search string here"]
		pack $watch_search_entry -side left -fill x -expand 1
		setStatusTip -widget $watch_search_entry	\
			-text [mc "Search for a name"]
		# Button "Clear search string"
		set watch_search_clear [ttk::button $icon_bar.clear_search	\
			-image ::ICONS::16::clear_left				\
			-command "$watch_search_entry delete 0 end"		\
			-state disabled						\
			-style Flat.TButton					\
		]
		DynamicHelp::add $icon_bar.clear_search -text [mc "Clear search string"]
		pack $watch_search_clear -side right -after $watch_search_entry
		setStatusTip -widget $icon_bar.clear_search	\
			-text [mc "Clear search string"]

		# Entry "Address"
		set entry [ttk::entry $tool_bar.ent_rightPanel_watch_addr		\
			-textvariable RightPanel::watch_addr${regw_count}		\
			-validatecommand "$this rightPanel_watch_addr_validate %P"	\
			-validate key 							\
			-width 5							\
		]
		DynamicHelp::add $entry		\
			-text [mc "Register address:\n  1 or 2 digits\tinternal RAM (not SFR)\n  3 digits\t\texpanded RAM\n  4 digits\t\texternal RAM\n  dot and 2 digits\tBit"]
		setStatusTip -widget $entry	\
			-text [mc "Register address or bit address"]
		grid $entry -sticky w -row 2 -column 1
		bind $entry <Return> "$this rightPanel_watch_add"
		bind $entry <KP_Enter> "$this rightPanel_watch_add"

		# Entry "Name"
		set entry [ttk::entry $tool_bar.ent_rightPanel_watch_name		\
			-textvariable RightPanel::watch_name${regw_count}		\
			-validatecommand "$this rightPanel_watch_name_validate %P"	\
			-validate key							\
			-width 20							\
		]
		setStatusTip -widget $entry	\
			-text [mc "Name of the watch. Any string."]
		grid $entry -sticky w -row 2 -column 2 -padx 3
		bind $entry <Return> "$this rightPanel_watch_add"
		bind $entry <KP_Enter> "$this rightPanel_watch_add"
		# Button "Add"
		set watch_add_button [ttk::button $tool_bar.but_rightPanel_watch_add	\
			-image ::ICONS::16::add						\
			-command "$this rightPanel_watch_add"				\
			-style Flat.TButton						\
		]
		DynamicHelp::add $watch_add_button -text [mc "Add this entry to register watches"]
		setStatusTip -widget $watch_add_button	\
			-text [mc "Add this entry to register watches"]
		grid $watch_add_button -sticky w -row 2 -column 3
		# Button "New"
		set watch_new_button [ttk::button $tool_bar.but_rightPanel_watch_new	\
			-image ::ICONS::16::filenew					\
			-command "$this rightPanel_watch_new"				\
			-style Flat.TButton						\
		]
		DynamicHelp::add $watch_new_button -text [mc "New register watches entry"]
		setStatusTip -widget $watch_new_button	\
			-text [mc "Create new register watch"]
		grid $watch_new_button -sticky w -row 2 -column 4
		# Button "Remove"
		set watch_remove_button [ttk::button $tool_bar.but_rightPanel_watch_remove	\
			-image ::ICONS::16::button_cancel					\
			-command "$this rightPanel_watch_remove"				\
			-style Flat.TButton							\
		]
		DynamicHelp::add $watch_remove_button -text [mc "Remove this entry"]
		setStatusTip -widget $watch_remove_button	\
			-text [mc "Remove this entry"]
		grid $watch_remove_button -sticky w -row 2 -column 5
		# Label "Addr"
		set watch_addr_entry [label $tool_bar.lbl_rightPanel_watch_addr	\
			-text [mc "Addr"]					\
			-font ${Simulator_GUI::smallfont}			\
			-fg ${Simulator_GUI::small_color}			\
		]
		grid $watch_addr_entry -row 1 -column 1
		# Label "Register name"
		grid [label $tool_bar.lbl_rightPanel_watch_name		\
			-text [mc "Register name"]			\
			-font ${Simulator_GUI::smallfont}		\
			-fg ${Simulator_GUI::small_color}		\
		] -row 1 -column 2

		# Create text widget representing list of register watches
		set watch_text [text $text_frame.txt_rightPanel_watch		\
			-yscrollcommand "$text_frame.src_rightPanel_watch set"	\
			-bg {#FFFFFF} -font $regfont				\
			-cursor left_ptr					\
			-state disabled -exportselection 0			\
		]
		# Create text tags
		$this right_panel_create_highlighting_tags $watch_text $watch_text_tags -1
		$watch_text tag configure tag_curLine -background ${::RightPanel::selection_color_dark}

		# Create scrollbar
		pack [ttk::scrollbar $text_frame.src_rightPanel_watch	\
			-orient vertical				\
			-command "$watch_text yview"			\
		] -side right -fill y
		pack $watch_text -side left -fill both -expand 1
		# Create event bindings
		bind $watch_text <ButtonRelease-3>	"$this rightPanel_watch_popupmenu %X %Y %x %y; break"
		bind $watch_text <Button-1>		"$this rightPanel_watch_click %x %y; break"
		bind $watch_text <<Selection>>		"false_selection $watch_text; break"
		bind $watch_text <Key-Menu>		{break}

		# Pack frames
		pack $tool_bar -side bottom -anchor w
		pack $icon_bar -side top -fill x
		pack $text_frame -side top -fill both -expand 1
		rightPanel_watch_switch_line 1

		# Create popup menu
		set watch_menu $parent.menu_rightPanel_watch
		regwatches_makePopupMenu

		# Refresh highlighting tags
		rightPanel_refresh_regwatches_highlighting

		# Open definition file
		if {$watch_file_name != {}} {
			rightPanel_watch_openfile $watch_file_name . 0
		}
	}

	## Sort register watches
	 # @parm Char sorting_key
	 #	N - Sort by name
	 #	A - Sort by address
	 #	T - Sort by type
	 # @return void
	public method rightPanel_watch_sort_by {sorting_key} {
		# Pack all watches into one sigle list
		set list_to_sort [list]
		set type {}
		foreach addr [array names watch_data] {

			switch -- [string length $addr] {
				4 {
					set type {X}
				}
				3 {
					if {[string index $addr 0] == {.}} {
						set type {B}
					} else {
						set type {E}
					}
				}
				default {
					set type {D}
				}
			}

			lappend list_to_sort [list $addr [lindex $watch_data($addr) 0] $type]
		}

		# Incremental sorting order
		if {$::RegWatches::sorting_order} {
			set order {-increasing}
		# Decremental sorting order
		} else {
			set order {-decreasing}
		}

		switch -- $sorting_key {
			N {	;# Name
				set index 1
			}
			A {	;# Address
				set index 0
			}
			T {	;# Type
				set index 2
			}
		}

		# Sort the list
		set list_to_sort [lsort -dictionary $order -index $index $list_to_sort]

		# Refill the panel
		rightPanel_watch_clear 1
		foreach entry $list_to_sort {
			set addr [lindex $entry 0]
			set name [lindex $entry 1]

			rightPanel_watch_add $addr $name
		}
	}

	## Perform autoload on simulator start
	 # @parm String filename - Code listinf file
	 # @return void
	public method rightPanel_watch_autoload {filename} {
		if {!$autoload_flag} {return}
		if {![file exists $filename]} {return}

		if {$autoclear_flag} {
			rightPanel_watch_clear 1
		}
		rightPanel_watch_import_file $filename .
	}

	## Autoload flag toggled (this function should be invoked from configuration menu)
	 # @return void
	public method rightPanel_watch_toggle_autoload_flag {} {
		set autoload_flag $::RegWatches::menu_autoload
	}

	## Autoclear flag toggled (this function should be invoked from configuration menu)
	 # @return void
	public method rightPanel_watch_toggle_autoclear_flag {} {
		set autoclear_flag $::RegWatches::menu_autoclear
	}

	## Get configuration list
	 # @return void
	public method rightPanel_watch_get_config {} {
		return [list				\
			$autoload_flag			\
			$::RegWatches::sorting_order	\
			$autoclear_flag			\
		]
	}

	## Create configuration menu
	 # @return void
	private method create_conf_menu {} {
		if {$conf_menu != {}} {
			return
		}
		set conf_menu $parent.conf_menu
		menuFactory $CONFMENU $conf_menu 0 "$this " 0 {} [namespace current]

		watch_disEna_buttons
	}

	## Invoke configuration menu
	 # @return void
	public method rightPanel_watch_cfg_menu {} {
		create_conf_menu

		set x [winfo rootx $conf_button]
		set y [winfo rooty $conf_button]
		incr y [winfo height $conf_button]

		set ::RegWatches::menu_autoload $autoload_flag
		set ::RegWatches::menu_autoclear $autoclear_flag
		tk_popup $conf_menu $x $y
	}

	## Refresh highlighting tags
	 # @return void
	public method rightPanel_refresh_regwatches_highlighting {} {
		if {!$regw_gui_initialized} {return}
		$this right_panel_create_highlighting_tags $watch_text $watch_text_tags -1
	}

	## Recreate popup menu
	 # @return void
	public method regwatches_makePopupMenu {} {
		if {!$regw_gui_initialized} {return}
		if {[winfo exists $watch_menu]} {destroy $watch_menu}
		menuFactory $WATCHMENU $watch_menu 0 "$this " 0 {} [namespace current]
	}


	## Retrun name of file currently loaded in register watches
	 # @return String - filename
	public method getWatchesFileName {} {
		# Determinate project root path
		set prj_path [$this cget -projectPath]
		append prj_path {/}

		# Return relative directory location
		if {![string first $prj_path $watch_file_name]} {
			return [string range $watch_file_name [string length $prj_path] end]
		# Return absolute directory location
		} else {
			return $watch_file_name
		}
	}

	## (Re)set dynamic shortcuts for the given entry widget
	 # @parm Widget entry - Target entry widget
	 # @return void
	private method watch_entry_shortcuts_reset {entry} {
		if {!$regw_gui_initialized} {return}

		# Unset previous configuration
		foreach key $watches_set_shortcuts {
			bind $entry <$key> {}
		}
		set set_shortcuts {}

		# Iterate over shortcuts definition
		foreach block ${::SHORTCUTS_LIST} {
			# Determinate category
			set category	[lindex $block 0]
			if {[lsearch $watches_shortcuts_cat $category] == -1} {continue}

			# Determinate definition list and its length
			set block	[lreplace $block 0 2]
			set len		[llength $block]

			# Iterate over definition list and create bindings
			for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {
				# Determinate key sequence
				set key [lindex $block $i]
				if {[catch {
					set key $::SHORTCUTS_DB($category:$key)
				}]} then {
					continue
				}
				if {$key == {}} {continue}

				# Create and register new binding
				lappend watches_set_shortcuts $key
				set cmd [subst [lindex $block [list $j 1]]]
				append cmd {;break}
				bind $entry <$key> $cmd
			}
		}
	}

	## Get adjusted value of address entry (register watches)
	 # @parm String string - input data ("\n" == get value from entry widget)
	 # @return String - result address
	private method get_watchAddr {string} {

		# Evaluate input string
		if {$string == {} || $string == {.}} {
			return { .00}
		}
		if {$string == "\n"} {
			set string [subst -nocommands "\$::RightPanel::watch_addr${obj_idx}"]
			regsub {^\s+} $string {} string
		}
		if {[string index $string 0] == {.}} {
			set string [string replace $string 0 0]
			set bit_addr 1
		} else {
			set bit_addr 0
		}

		# Adjust address
		set len [string length $string]
		if {$len > 2} {
			if {$len != 4} {
				set string " $string"
			}
		} else {
			if {$len == 1} {
				set string "0$string"
			}
			set string "  $string"
		}

		# Resturn result
		if {$bit_addr} {
			return [string replace $string 1 1 {.}]
		} else {
			return [string toupper $string]
		}
	}

	## Get adjusted value of register name (Register watches)
	 # @parm String string - input data ("\n" == get value from entry widget)
	 # @return String - resulting register name
	private method get_watchName {string} {
		# Conditionaly get value from entry widget
		if {$string == "\n"} {
			set string [subst -nocommands "\$::RightPanel::watch_name${obj_idx}"]
			regsub {\t+$} $string {} string
		}

		# Adjust resulting string
		set len [string length $string]
		append string [string repeat { } [expr {23 - $len}]]

		# Return result
		return $string
	}

	## Validate content of address entry - Register watches
	 # @parm String value - input value
	 # @return Bool - result
	public method rightPanel_watch_addr_validate {value} {

		# Check if validation is enabled
		if {!$watch_AN_valid_ena} {return 1}

		# Check for allowed length
		if {[string length $value] > 4} {
			return 0
		}

		# Check for allowed characters
		if {!([regexp {^[A-Fa-f0-9]*$} $value] || [regexp {^\.[A-Fa-f0-9]{0,2}$} $value])} {
			return 0
		}

		# Change content of address field in register watches text widget
		if {$watch_curLine != 0 && $value != {}} {

			# Get address
			set value [get_watchAddr $value]
			regsub {^\s+} $value {} real_value

			# Check it the desired address is unique
			if {[lsearch -ascii -exact $watch_addrs $real_value] != -1} {
				Sbar [mc "Unable to assign, address is already in use"]
				return 1
			}

			# Modify variables related to the current entry
			set idx [expr {$watch_curLine - 1}]
			set addr [lindex $watch_addrs $idx]
			set var [lindex $watch_data($addr) 1]
			set watch_data($real_value) $watch_data($addr)
			unset watch_data($addr)
			lset watch_addrs $idx $real_value

			# Synchronize
			$watch_text.$var configure -state normal
			rightPanel_watch_sync $real_value
			$watch_text.$var configure -fg ${Simulator::normal_color}
			if {!$watches_enabled || [read_from_simulator $real_value] == {--}} {
				$watch_text.$var configure -state disabled
			}

			# Enable entry watches text widget
			$watch_text configure -state normal

			# Change content of address field
			$watch_text delete $watch_curLine.0 $watch_curLine.4
			$watch_text insert $watch_curLine.0 $value

			# Bit -> Byte
			if {[string index $addr 0] == {.} && [string index $real_value 0] != {.}} {
				$watch_text.$var configure -width 2
				help_window_hide

			# Byte -> Bit
			} elseif {[string index $addr 0] != {.} && [string index $real_value 0] == {.}} {
				$watch_text.$var configure -width 1
				help_window_hide
			}

			# Highlight address field
			set len [string length $real_value]
			if {$len == 4} {
				set addr_tag {tag_Xaddr}
			} elseif {$len == 3 && ([string index $real_value 0] == {.})} {
				set addr_tag {tag_Baddr}
			} elseif {$len == 3} {
				set addr_tag {tag_Eaddr}
			} else {
				set addr_tag {tag_addr}
			}
			$watch_text tag add $addr_tag $watch_curLine.0 $watch_curLine.4

			# Change selection
			$watch_text tag remove tag_curLine 1.0 end
			$watch_text tag add tag_curLine $watch_curLine.0 "$watch_curLine.0 + 1 line"

			$watch_text configure -state disabled

			# Adjust help window
			help_window_update_addr $addr $real_value
			bind $watch_text.[lindex $watch_data($real_value) 1] <Enter>	\
				"$this create_help_window_ram ${real_value}h; help_window_variable_addr"

			# Adjust flag: modified
			set watches_modified 1
		}

		# Success
		return 1
	}

	## Validate content of register name entry - Register watches
	 # @parm String value - input value
	 # @return Bool - result
	public method rightPanel_watch_name_validate {value} {
		# Check if validation is enabled
		if {!$watch_AN_valid_ena} {return 1}

		# Check for allowed length
		if {[string length $value] > 23} {
			return 0
		}

		# Change content of register name field in register watches text widget
		if {$watch_curLine != 0} {
			# Local variables
			set name [get_watchName $value]		;# Register name

			# Change reg. name in object variable watch_data
			lset watch_data([lindex $watch_addrs [expr {$watch_curLine - 1}]]) 0 [string trimright $value]

			# Enable list of watches widget
			$watch_text configure -state normal

			# Change current register name
			$watch_text delete $watch_curLine.5 "$watch_curLine.0 lineend - 1 char"
			$watch_text insert $watch_curLine.5 $name

			# Restore reg. name text tag
			$watch_text tag add tag_name $watch_curLine.5 $watch_curLine.28

			# Adjust selection
			$watch_text tag remove tag_curLine 1.0 end
			$watch_text tag add tag_curLine $watch_curLine.0 "$watch_curLine.0 + 1 line"

			# Disable list of watches widget
			$watch_text configure -state disabled

			# Adjust status modified
			set watches_modified 1
		}

		# Success
		$watch_search_entry delete 0 end
		return 1
	}

	## Validate content of embedded entries in list of register watches
	 # @parm String addr	- hexadecimal representation of register addres
	 # @parm String value	- string to validate
	 # @return Bool - result
	public method rightPanel_watch_value_validate {addr value} {
		if {$validator_engaged} {return 1}
		set validator_engaged 1

		# Check for allowed length
		if {[string length $value] > 2} {
			set validator_engaged 0
			return 0
		}

		# Check for allowed characters
		if {![regexp {^[A-Fa-f0-9]*$} $value]} {
			set validator_engaged 0
			return 0
		}

		## Synchronize new content with simulator engine
		if {[string index $addr 0] == {.}} {
			set addr [string replace $addr 0 0]
			set bit_addr 1
		} else {
			set bit_addr 0
		}
		set dec_addr [expr "0x$addr"]
		# Bit
		if {$bit_addr} {
			if {$value == {}} {
				set value 0
			}
			if {![regexp {^[01]?$} $value]} {
				set validator_engaged 0
				return 0
			}
			$this setBit $dec_addr $value

		# External RAM
		} elseif {[string length $addr] == 4} {
			$this setXdata $dec_addr $value
			$this Simulator_XDATA_sync $addr

		# Expanded RAM
		} elseif {[string length $addr] == 3} {
			$this setEram $dec_addr $value
			$this Simulator_XDATA_sync $addr

		# Internal RAM
		} else {
			$this setData $dec_addr $value
			$this SimGUI_disable_sync
			$this Simulator_GUI_sync I $dec_addr
			$this SimGUI_enable_sync
		}

		if {$bit_addr} {
			set addr .$addr
		}
		$watch_text.[lindex $watch_data($addr) 1] configure -fg ${Simulator::normal_color}

		# Synchronize with help window
		help_window_update $addr $value

		# Done ...
		set validator_engaged 0
		return 1
	}

	## Enable entry widgets in register watches
	 # AFFECT ALL ENTRIES (not only valid ones) !!!
	 # @return void
	public method rightPanel_watch_force_enable {} {
		if {!$regw_gui_initialized} {CreateRegWatchesGUI}

		set watches_enabled 1
		foreach addr $watch_addrs {
			$watch_text.[lindex $watch_data($addr) 1] configure -state normal
		}
	}

	## Enable entry widgets in register watches
	 # Affect only entries with valid address (implemented on current MCU)
	 # @return void
	public method rightPanel_watch_enable {} {
		if {!$regw_gui_initialized} {CreateRegWatchesGUI}

		set watches_enabled 1
		foreach addr $watch_addrs {
			if {[string index $addr 0] == {.}} {
				set addr [string replace $addr 0 0]
				set bit_addr 1
			} else {
				set bit_addr 0
			}
			set dec_addr	[expr "0x$addr"]
			set len		[string length $addr]

			# Bit
			if {$bit_addr} {
				if {$dec_addr > 0x7F} {
					if {![$this simulator_is_sfr_available [$this getRegOfBit $dec_addr]]} {
						continue
					}
				}
				set addr ".$addr"

			# Internal RAM
			} elseif {$len < 3} {
				if {$dec_addr >= [lindex [$this cget -procData] 3]} {
					continue
				}

			# Expanded RAM
			} elseif {$len == 3} {
				if {$dec_addr >= [lindex [$this cget -procData] 8]} {
					continue
				}

			# External RAM
			} else {
				if {$dec_addr >= [$this cget -P_option_mcu_xdata]} {
					continue
				}
			}

			$watch_text.[lindex $watch_data($addr) 1] configure -state normal
		}
	}

	## Disable all entry widgets in register watches
	 # @return void
	public method rightPanel_watch_disable {} {
		if {!$regw_gui_initialized} {return}

		set watches_enabled 0
		foreach addr $watch_addrs {
			$watch_text.[lindex $watch_data($addr) 1] configure -state disabled
		}
	}
	## Select line in list of register watches
	 # @parm Int x - relative X coordinate
	 # @parm Int y - relative Y coordinate
	 # @return void
	public method rightPanel_watch_click {x y} {
		rightPanel_watch_switch_line [expr {int([$watch_text index @$x,$y])}]
		$watch_search_entry delete 0 end
	}

	## Change current line in register watches
	 # @parm Int row - target line
	 # @return void
	public method rightPanel_watch_switch_line {row} {
		if {!$regw_gui_initialized} {return}
		set watch_AN_valid_ena 0

		# Determinate number of the last row
		set end [$watch_text index end]
		set end [expr {int($end) - 1}]

		# Restore previous state of the last selected entry box
		if {$watch_curLine} {
			set addr [lindex $watch_addrs [expr {$watch_curLine - 1}]]
			set var [lindex $watch_data($addr) 1]
			$watch_text.$var selection clear
			$watch_text.$var configure		\
				-disabledbackground {#FFFFFF}	\
				-bg {#FFFFFF}
		}

		# Enable/Disable buttons and Clear/Keep entry widgets at the bottom
		if {$row == $end} {
			$watch_remove_button	configure -state disabled
			$watch_new_button	configure -state disabled
			$watch_add_button	configure -state normal
			set watch_curLine 0
			$watch_text tag remove tag_curLine 1.0 end
			set ::RightPanel::watch_name${obj_idx} {}
			set ::RightPanel::watch_addr${obj_idx} {}
			set watch_AN_valid_ena 1
			return 0
		} else {
			set watch_curLine $row
			$watch_remove_button	configure -state normal
			$watch_new_button	configure -state normal
			$watch_add_button	configure -state disabled
		}

		# Determinate text indexes
		set idx0 "$row.0"
		set idx1 [expr {$row + 1}]
		append idx1 {.0}

		# Set selection tag
		$watch_text tag remove tag_curLine 1.0 end
		$watch_text tag add tag_curLine $idx0 $idx1

		# Adjust content of entry widgets at the bottom
		set addr [lindex $watch_addrs [expr {$watch_curLine - 1}]]
		set name [lindex $watch_data($addr) 0]
		set var [lindex $watch_data($addr) 1]

		set ::RightPanel::watch_name${obj_idx} [string trimright $name]
		set ::RightPanel::watch_addr${obj_idx} [string trimright $addr]

		# Change foreground color of current value entry
		$watch_text.$var configure				\
			-fg ${Simulator::normal_color}			\
			-bg ${::RightPanel::selection_color_dark}	\
			-disabledbackground ${::RightPanel::selection_color_dark}

		# Focus on value entry
		focus $watch_text.$var
		$watch_text.$var selection range 0 end
		$watch_text see $row.0

		set watch_AN_valid_ena 1
	}

	## Create a new register watch
	 # @parm String	- Hex address,		{} == Content of address entry
	 # @parm String	- Register name,	{} == Content of name entry
	 # @return void
	public method rightPanel_watch_add args {
		# Local variables
		set row		[$watch_text index end]		;# Last row in the list
		set row		[expr {int($row) - 1}]
		set addr	[lindex $args 0]		;# Register address (Hex String)
		set name	[lindex $args 1]		;# Watch name
		set shortAddr	{}				;# Register address (Hex Number)

		if {$addr == {} || $name == {}} {
			set addr	[get_watchAddr "\n"]
			set name	[get_watchName "\n"]
			set no_sbar	0
		} else {
			set addr	[get_watchAddr $addr]
			set name	[get_watchName $name]
			set no_sbar	1
		}
		set shortAddr [regsub {^\s*} $addr {}]

		# Check address validity
		if {$shortAddr == {}} {
			if {!$no_sbar} {
				Sbar [mc "You must specify the register address."]
			}
			return 0
		}
		if {[lsearch -ascii -exact $watch_addrs $shortAddr] != -1} {
			if {!$no_sbar} {
				Sbar [mc "Specified address is already used."]
			}
			return 0
		}

		# Enable text widget
		$watch_text configure -state normal
		# Insert address and watch name
		$watch_text insert end "$addr $name"
		# Insert text tags
		regsub {^ +} $addr {} addr
		set entry [watch_create_entry $addr $row $watch_entry_count]
		$watch_text window create end -window $entry -pady 0
		$watch_text insert end "\n"
		set len [string length $addr]
		if {$len == 4} {
			set addr_tag {tag_Xaddr}
		} elseif {$len == 3 && ([string index $addr 0] == {.})} {
			set addr_tag {tag_Baddr}
		} elseif {$len == 3} {
			set addr_tag {tag_Eaddr}
		} else {
			set addr_tag {tag_addr}
		}
		$watch_text tag add $addr_tag $row.0 $row.4
		$watch_text tag add tag_name $row.5 $row.28
		# Disable text widget
		$watch_text configure -state disabled

		# Register new watch
		regsub {\t+$} $name {} name
		lappend watch_addrs $addr
		set watch_data($addr) [list $name $watch_entry_count]

		# Synchronize
		rightPanel_watch_sync $addr
		$entry configure -fg ${Simulator::normal_color}

		# Enable/Disable the entry widget
		if {!$watches_enabled} {
			$entry configure -state disabled
		}

		incr watch_entry_count

		# Reevaluate button states
		watch_disEna_buttons

		# Clear search entry
		$watch_search_entry delete 0 end

		# Adjust status modified
		set watches_modified 1
	}

	## Create entry widget for embedding in list of watches
	 # @parm String addr	- hexadecimal register address
	 # @parm Int row	- target row in text widget
	 # @parm Variable var	- entry text variable
	 # @return Widget - resulting entry widget
	private method watch_create_entry {addr row var} {
		if {[string index $addr 0] == {.}} {
			set width 1
		} else {
			set width 2
		}

		# Create entry widget
		set entry [entry $watch_text.$var				\
			-width $width						\
			-font ${::Simulator_GUI::entry_font}			\
			-bg {#FFFFFF}		-validate key			\
			-takefocus 0		-highlightthickness 0		\
			-disabledbackground {#FFFFFF}				\
			-vcmd "$this rightPanel_watch_value_validate $addr %P"	\
			-bd 0			-justify right			\
		]

		# Set event bindings
		bind $entry <Button-1>		"$this rightPanel_watch_switch_line $row"
		bind $entry <Key-Up>		"$this rightPanel_watch_up 1"
		bind $entry <Key-Down>		"$this rightPanel_watch_down 1"
		bind $entry <Key-Next>		"$this rightPanel_watch_down 4"
		bind $entry <Key-Prior>		"$this rightPanel_watch_up 4"
		bind $entry <Motion>		{help_window_show %X %Y}
		bind $entry <Leave>		{help_window_hide}
		bind $entry <Enter>		"$this create_help_window_ram ${addr}h; help_window_variable_addr"
		bind $entry <Button-4>		"$watch_text yview scroll -5 units"
		bind $entry <Button-5>		"$watch_text yview scroll +5 units"
		watch_entry_shortcuts_reset $entry

		# Return entry reference
		return $entry
	}

	## Clear highlight for all registers
	 # @return void
	public method rightPanel_watch_clear_highlight {} {
		if {!$regw_gui_initialized} {return}

		foreach addr $watch_addrs {
			$watch_text.[lindex $watch_data($addr) 1] configure -fg ${Simulator::normal_color}
		}
	}

	## Clear highlight for the given register
	 # @return void
	public method rightPanel_watch_unhighlight {addr} {
		if {!$regw_gui_initialized} {return}

		if {[lsearch $watch_addrs $addr] == -1} {
			return
		}
		$watch_text.[lindex $watch_data($addr) 1] configure -fg ${Simulator::normal_color}
	}

	## Move current watch to the top
	 # @return void
	public method rightPanel_watch_move_top {} {
		rightPanel_watch_move 1
	}

	## Move current watch to up
	 # @return void
	public method rightPanel_watch_move_up {} {
		# Determinate target line
		set target_line [expr {$watch_curLine - 1}]
		if {$target_line == 0} {return 0}
		# Move watch
		rightPanel_watch_move $target_line
	}

	## Move current watch to down
	 # @return void
	public method rightPanel_watch_move_down {} {
		# Determinate target line
		set target_line [expr {$watch_curLine + 1}]
		set end [$watch_text index end]
		set end [expr {int($end) - 1}]
		if {$target_line == $end} {return 0}
		# Move watch
		rightPanel_watch_move $target_line
	}

	## Move current watch to the bottom
	 # @return void
	public method rightPanel_watch_move_bottom {} {
		# Determinate target line
		set target_line [$watch_text index end]
		set target_line [expr {int($target_line) - 2}]
		# Move watch
		rightPanel_watch_move $target_line
	}

	## Move current watch to the given line
	 # @parm Int target_line - target line
	 # @return void
	private method rightPanel_watch_move {target_line} {
		# Validate current line value
		if {$watch_curLine == 0} {return}

		# Local variables
		set cur_idx	[expr {$watch_curLine - 1}]	;# index in $watch_addrs -- current line
		set trg_idx	[expr {$target_line - 1}]	;# index in $watch_addrs -- target line
		set addr	[lindex $watch_addrs $cur_idx]	;# register address
		set name	[lindex $watch_data($addr) 0]	;# watch name
		set var		[lindex $watch_data($addr) 1]	;# textvariable of the value entry

		# Modify variables related to the watch
		set watch_addrs [lreplace $watch_addrs $cur_idx $cur_idx]
		set watch_addrs [linsert $watch_addrs $trg_idx $addr]

		# Enable the widget
		$watch_text configure -state normal
		# Change textual content
		$watch_text delete $watch_curLine.0 "$watch_curLine.0 + 1 line linestart"
		$watch_text insert $target_line.0 "[get_watchAddr $addr] [get_watchName $name]\n"
		# Destroy the current entry widget
		destroy $watch_text.$var
		# Change embedded entry
		set entry [watch_create_entry $addr $target_line $var]
		$watch_text window create [list $target_line.0 lineend] -window $entry -pady 0
		set len [string length $addr]
		if {$len == 4} {
			set addr_tag {tag_Xaddr}
		} elseif {$len == 3 && ([string index [string trim $addr] 0] == {.})} {
			set addr_tag {tag_Baddr}
		} elseif {$len == 3} {
			set addr_tag {tag_Eaddr}
		} else {
			set addr_tag {tag_addr}
		}
		# Restore text tags
		$watch_text tag add $addr_tag $target_line.0 $target_line.4
		$watch_text tag add tag_name $target_line.5 $target_line.28
		# Disable the widget
		$watch_text configure -state disabled

		# Synchronize entry widget content
		rightPanel_watch_sync $addr

		# Enable/Disable the entry widget
		if {!$watches_enabled} {
			$entry configure -state disabled
		}

		# Set current line
		set watch_curLine $target_line
		rightPanel_watch_switch_line $target_line

		# Clear search entry
		$watch_search_entry delete 0 end

		# Adjust status modified
		set watches_modified 1
	}

	## Change current line in list of register watches to the line above the current one
	 # @parm Int lines - number of lines to skip - 1
	 # @return void
	public method rightPanel_watch_up {lines} {
		# Determinate number of last row in the widget
		set end [$watch_text index end]
		set end [expr {int($end) - 2}]

		# Change current line (logicaly)
		set line $watch_curLine
		incr line -$lines
		if {$line < 1} {
			set line 1
		}

		# Change current line (physicaly)
		$watch_text see $watch_curLine.0
		rightPanel_watch_switch_line $line

		# Clear search entry
		$watch_search_entry delete 0 end
	}

	## Change current line in list of register watches to the line below the current one
	 # @parm Int lines - number of lines to skip - 1
	 # @return void
	public method rightPanel_watch_down {lines} {
		# Determinate number of last row in the widget
		set end [$watch_text index end]
		set end [expr {int($end) - 2}]

		# Change current line (logicaly)
		set line $watch_curLine
		incr line $lines
		if {$line > $end} {
			set line $end
		}

		# Change current line (physicaly)
		$watch_text see $watch_curLine.0
		rightPanel_watch_switch_line $line

		# Clear search entry
		$watch_search_entry delete 0 end
	}

	## Binding for button "New" (Clears entry widgets at the bottom and unselect current watch)
	 # @return void
	public method rightPanel_watch_new {} {
		set end [$watch_text index end]
		set end [expr {int($end) - 1}]
		rightPanel_watch_switch_line $end

		# Clear search entry
		$watch_search_entry delete 0 end
	}

	## Remove the current register watch
	 # @return void
	public method rightPanel_watch_remove {} {
		# Determinate register address
		set addr [lindex $watch_addrs [expr {$watch_curLine - 1}]]
		if {$addr != {}} {
			# Destroy value entry
			set var [lindex $watch_data($addr) 1]
			destroy $watch_text.$var
			# Unregister watch
			unset watch_data($addr)
			set idx [lsearch $watch_addrs $addr]
			set watch_addrs [lreplace $watch_addrs $idx $idx]

			# Remove watch from the text widget
			$watch_text configure -state normal
			$watch_text delete $watch_curLine.0 "$watch_curLine.0 + 1 line"
			$watch_text configure -state disabled
		}

		# Change current line
		if {$watch_curLine > [llength $watch_addrs]} {
			set watch_curLine [llength $watch_addrs]
		}
		if {$watch_curLine} {
			rightPanel_watch_switch_line $watch_curLine
		} else {
			rightPanel_watch_switch_line 1
		}

		# Reevaluate button states
		watch_disEna_buttons
		# Clear search entry
		$watch_search_entry delete 0 end
		# Adjust status modified
		set watches_modified 1
	}

	## Save watches definition to a file
	 # @parm String filename	- Target filename or an empty string
	 # @parm Bool force=0		- Do not ask for overwrite
	 # @return void
	public method rightPanel_watch_save {filename {force 0}} {
		if {!$regw_gui_initialized} {CreateRegWatchesGUI}

		if {$filename != {}} {
			set watch_file_name $filename
		}

		# If no filename specified -> invoke dislog "Save as"
		if {$watch_file_name == {}} {
			rightPanel_watch_saveas

		# Save file
		} else {
			# Set new filename
			if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
				if {![regexp "^(~|/)" $watch_file_name]} {
				set filename "[$this cget -ProjectDir]/$watch_file_name"
				}
			} else {	;# Microsoft windows way
				if {![regexp {^\w:} $watch_file_name]} {
					set filename [file join [$this cget -ProjectDir] $watch_file_name]
				}
			}

			set watch_file_name [file normalize $watch_file_name]
			# Adjust file extension
			if {![regexp {\.wtc$} $watch_file_name]} {
				append watch_file_name {.wtc}
			}

			if {[file exists $watch_file_name] && [file isfile $watch_file_name]} {
				# Ask user for overwrite existing file
				if {!$force && [tk_messageBox	\
					-type yesno		\
					-icon question		\
					-parent .		\
					-title [mc "Overwrite file"]	\
					-message [mc "A file name '%s' already exists. Are you sure you want to overwrite it ?" [file tail $watch_file_name]]
					] != {yes}
				} then {
					return
				}
				# Create a backup file
				catch {
					file rename -force $watch_file_name "$watch_file_name~"
				}
			}
			if {[catch {
				set file [open $watch_file_name w 0640]
			}]} then {
				if {[winfo exists .fsd]} {
					set parent .fsd
				} else {
					set parent .
				}
				tk_messageBox		-type ok		\
					-parent $parent	-icon warning		\
					-title [mc "Error - MCU 8051 IDE"]	\
					-message [mc "Unable to access file \"%s\", check your permissions." $watch_file_name]
				return
			}

			# Write file header
			puts $file "# Watches definition file -- ${::APPNAME}"

			# Write watches definition
			puts -nonewline $file [regsub -all -line {\s+$} [$watch_text get 1.0 end] {}]

			# Finish
			close $file
			Sbar [mc "Definitions saved to \"%s\"" $watch_file_name]

			# Adjust status modified
			set watches_modified 0
		}
	}

	## Invoke dialog "Save as" - Register watches
	 # @return void
	public method rightPanel_watch_saveas {} {

		# Abort if there is already opened some file selection dialog
		if {[winfo exists .fsd]} {return}

		# Invoke the dialog
		KIFSD::FSD ::fsd	 					\
			-title [mc "Save watches - MCU 8051 IDE"]		\
			-directory [$this cget -ProjectDir]			\
			-defaultmask 0 -multiple 0 -filetypes [list				\
				[list [mc "MCU 8051 IDE watches definition"]	{*.wtc}]	\
				[list [mc "All files"]				{*}]		\
			]
		# Save file after press of OK button
		::fsd setokcmd {
			set ::filename [::fsd get]
			if {$::filename != {} && ![file isdirectory $::filename]} {
				${::X::actualProject} rightPanel_watch_save $::filename
			}
		}
		# Activate the dialog
		::fsd activate
	}

	## Open and process watches definition file
	 # @parm String filename	- name of source file
	 # @parm Widget parent		- GUI parent (for error dialogues)
	 # @parm Bool clear		- Clear watches before loading
	 # @return Bool - result
	public method rightPanel_watch_openfile {filename parent clear} {
		if {!$regw_gui_initialized} {CreateRegWatchesGUI}

		# Normalize filename
		if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
			if {![regexp "^(~|/)" $filename]} {
			set filename "[$this cget -projectPath]/$filename"
			}
		} else {	;# Microsoft windows way
			if {![regexp {^\w:} $filename]} {
				set filename [file join [$this cget -projectPath] $filename]
			}
		}
		set filename [file normalize $filename]

		# Set new watches filename
		set watch_file_name $filename

		# Open file
		if {[catch {
			set file [open $filename r]
		}]} then {
			tk_messageBox						\
				-parent $parent					\
				-icon warning					\
				-type ok					\
				-title [mc "File access error"]			\
				-message [mc "Unable to read file '%s'" $filename]
			set watch_file_name {}
			return 0
		}

		# Verify input data validity
		while {![eof $file]} {
			set line [gets $file]

			# Skip comments and empty lines
			if {[regexp {^\s*#} $line]} {continue}
			if {[regexp {^\s*$} $line]} {continue}

			# Local variables
			regexp {^\s*\.?\w+} $line addr		;# Register address
			regsub {^\s*\.?\w+\s*} $line {} name	;# Watch name
			regsub {\s+$} $name {} name

			# Check for address and name validity
			if {
				![regexp {^\s*\.?[A-Fa-f0-9]+$} $addr]	||
				[string length $addr] > 4		||
				[string length $name] > 23
			} then {
				tk_messageBox				\
					-title [mc "Corrupted file"]	\
					-icon error -type ok  -parent $parent	\
					-message [mc "file: %s is either corrupted or it is not a file in expected format." $filename]
				return 0
			}
		}

		# Clear watches
		if {$clear} {
			rightPanel_watch_clear 1
		}

		# Parse input data
		seek $file 0
		while {![eof $file]} {
			set line [gets $file]

			# Skip comments and empty lines
			if {[regexp {^\s*#} $line]} {continue}
			if {[regexp {^\s*$} $line]} {continue}

			regexp {^\s*\.?\w+} $line addr		;# Register address
			regsub {^\s*\.?\w+\s*} $line {} name	;# Watch name
			set addr [string trimleft $addr]
			set name [string trimright $name]

			# Create new register watch
			rightPanel_watch_add $addr $name
		}

		# Deselect all
		rightPanel_watch_new

		# Reevaluate button states (icon bar)
		watch_disEna_buttons

		# Adjust status modified
		set watches_modified 0

		# Success
		close $file
		return 1
	}

	## Invoke dialog "Open file"
	 # @return void
	public method rightPanel_watch_open {} {
		# Invoke the dialog
		KIFSD::FSD ::fsd	 					\
			-title [mc "Load watches from file - MCU 8051 IDE"]	\
			-directory [$this cget -ProjectDir] -autoclose 0	\
			-defaultmask 0 -multiple 0 -filetypes [list				\
				[list [mc "MCU 8051 IDE watches definition"]	{*.wtc}]	\
				[list [mc "All files"]				{*}]		\
			]

		# Open file after press of OK button
		fsd setokcmd {
			# Get chosen file name
			set filename [::fsd get]
			if {[${::X::actualProject} rightPanel_watch_openfile $filename [::fsd get_window_name] 1]} {
				::fsd deactivate
				delete object fsd
			}
		}

		# Activate the dialog
		fsd activate
	}

	## Invoke dialog "Import file"
	 # @return void
	public method rightPanel_watch_import {} {
		# Invoke the dialog
		KIFSD::FSD ::fsd	 					\
			-title [mc "Import file - MCU 8051 IDE"]		\
			-directory [$this cget -ProjectDir] -autoclose 0	\
			-defaultmask 0 -multiple 0 -filetypes [list				\
				[list [mc "Code listing"]			{*.lst}]	\
				[list [mc "MCU 8051 IDE watches definition"]	{*.wtc}]	\
				[list [mc "All files"]				{*}]		\
			]

		# Open file after press of OK button
		fsd setokcmd {
			# Get chosen file name
			set filename [::fsd get]
			if {[${::X::actualProject} rightPanel_watch_import_file $filename [::fsd get_window_name]]} {
				::fsd deactivate
				delete object fsd
			}
		}

		# Activate the dialog
		fsd activate
	}

	## Import file
	 # @parm String filename	- Name of source file (*.lst or *.wtc)
	 # @parm Widget parent		- GUI parent (for error dialogues)
	 # @return Bool - result
	public method rightPanel_watch_import_file {filename parent} {
		if {!$regw_gui_initialized} {CreateRegWatchesGUI}

		# Determinate file type
		set filename [file normalize [file join [$this cget -ProjectDir] $filename]]
		set file_type 0
		switch -nocase -- [file extension $filename] {
			{.wtc} {	;# Watches definition file
				set file_type 1
			}
			{.lst} {	;# Code listing
				set file_type 2
			}
			default {	;# Try to detect file type by file header
				catch {
					set file [open $filename r]
					if {[string first {# Watches definition file} [gets $file]] == 0} {
						set file_type 1
					}
					close $file
				}
			}
		}

		# Unknown file type
		if {!$file_type} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Unknown file"]	\
				-message [mc "Unable to recognize file format"]
			return 0
		}

		# -----------------------------------------------------------------------
		## WTC file - load and exit procedure
		# -----------------------------------------------------------------------
		if {$file_type == 1} {
			return [rightPanel_watch_openfile $filename $parent 0]
		}


		# -----------------------------------------------------------------------
		# LST file
		# -----------------------------------------------------------------------

		# Try to open file
		if {[catch {
			set file [open $filename r]
		}]} then {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "File access error"]	\
				-message [mc "Unable to open file:\n'%s'" $filename]
			return 0
		}

		# Parse file
		set read_line 0
		set line {}
		set name {}
		set addr {}
		set type {}
		set bita 0
		while {![eof $file]} {
			set bita 0
			set line [gets $file]

			# Empty line - stop reading
			if {![string length [string trimright $line "  \f"]]} {
				set read_line 0
				continue

			# MCU 8051 IDE Assembler symbol table
			} elseif {![string first {SYMBOL TABLE:} $line]} {
				set read_line 1
				continue

			# ASEM-51 Assembler symbol table
			} elseif {![string first {------------------------------------------------------------} $line]} {
				set read_line 2
				continue
			}


			# MCU 8051 IDE Assembler symbol
			if {$read_line == 1} {
				if {![regexp {^\w+} $line name]} {
					continue
				}
				if {![regexp {[\w\s]+$} $line line]} {
					continue
				}
				set type [lindex $line 0]

				# Ignore all types except address
				if {[lindex $line 1] != {ADDR}} {
					continue
				}

				# Internal data memory
				if {$type == {D} || $type == {I}} {
					set addr [string range [lindex $line 2] 2 3]
				# External data memory (inluding ERAM, EEPROM, etc.)
				} elseif {$type == {X}} {
					set addr [string range [lindex $line 2] 0 3]
				# Bit addressable area
				} elseif {$type == {B}} {
					set bita 1
					set addr [string range [lindex $line 2] 2 3]
				# Another type of memory -> IGNORE
				} else {
					continue
				}

				# Ignore unused symbols
				if {[lindex $line end-1] == {NOT} || [lindex $line end-2] == {NOT}} {
					continue
				}

			# ASEM-51 Assembler symbol
			} elseif {$read_line == 2} {
				# Remove dangerous characters
				regsub -all {\{\}\"\"} $line {} line

				# Ignore unused symbols
				if {[llength $line] < 4} {
					continue
				}

				# Determinate address and symbol name
				set type [lindex $line 1]
				set addr [lindex $line 2]
				set name [lindex $line 0]

				# Accept only internal and external data memory
				if {$type != {IDATA} && $type != {DATA} && $type != {XDATA} && $type != {BIT}} {
					continue
				}
				if {$type == {BIT}} {
					set bita 1
				}

			# This line is not a part of symbol table
			} else {
				continue
			}

			# Address must be a valid hexadecimal value
			if {![string is xdigit -strict $addr]} {
				continue
			}

			# Exclude SFR's
			if {[lsearch -ascii -exact ${::ASMsyntaxHighlight::spec_registers} $name] != -1} {
				continue
			}

			# Create new register watch
			if {[string length $name] > 23} {
				set name [string range $name 0 16]
				append name {..}
			}

			if {$bita} {
				set addr .$addr
			}

			rightPanel_watch_add $addr $name
			set watches_modified 1
		}

		# Finalize
		rightPanel_watch_new
		watch_disEna_buttons
		close $file
		return 1
	}

	## Remove all register watches
	 # Bool force=0	- Don't ask for user comfirmation
	 # @return void
	public method rightPanel_watch_clear {{force 0}} {
		if {!$regw_gui_initialized} {CreateRegWatchesGUI}

		# Ask user for comfirmation
		if {!$force} {
			if {[tk_messageBox	\
				-parent .	\
				-type yesno	\
				-icon question	\
				-title [mc "Are you sure ?"]	\
				-message [mc "Do you really want to clear the panel ?"]
			] != {yes}} {
				return
			}
		}

		# Clear text widget
		$watch_text configure -state normal
		$watch_text delete 1.0 end
		$watch_text configure -state disabled

		# Destroy all embedded entry widgets
		foreach addr $watch_addrs {
			destroy $watch_text.[lindex $watch_data($addr) 1]
		}

		# Clear entries on the bottom bar
		set watch_curLine 0
		set ::RightPanel::watch_name${obj_idx} {}
		set ::RightPanel::watch_addr${obj_idx} {}

		# Unregister all watches
		set watch_addrs {}
		catch {
			array unset watch_data
		}

		# Reevaluate button states (icon bar)
		watch_disEna_buttons

		# Adjust status modified
		set watches_modified 1
	}

	## Search for the given string in the list of register watches -- search entry validator
	 # @parm String content	- String to find/validate
	 # @return Bool - result
	public method rightPanel_watch_search_validate {content} {
		if {$search_val_in_progress} {return 0}
		set search_val_in_progress 1

		# Enable/Disable button "Clear search entry"
		if {$content == {}} {
			$watch_search_clear configure -state disabled
		} else {
			$watch_search_clear configure -state normal
		}

		# Validate search string
		if {[regexp {^\s*$} $content]} {
			$watch_search_entry configure -style TEntry
			set search_val_in_progress 0
			return 1
		}
		if {[string length $content] > 23} {
			set search_val_in_progress 0
			return 0
		}

		# Search for the given string
		set i 1
		set content [string trimright $content]
		set content [string tolower $content]
		foreach addr $watch_addrs {
			if {![string first $content [string tolower [lindex $watch_data($addr) 0]]]} {
				$watch_search_entry configure -style StringFound.TEntry
				rightPanel_watch_switch_line $i
				focus $watch_search_entry
				set search_val_in_progress 0
				return 1
			}
			incr i
		}

		# String not found
		$watch_search_entry configure -style StringNotFound.TEntry
		set search_val_in_progress 0
		return 1
	}

	## Syncronize all register watches
	 # @return void
	public method rightPanel_watch_sync_all {} {
		if {!$regw_gui_initialized} {CreateRegWatchesGUI}

		# Iterate over addresses
		foreach addr $watch_addrs {
			# Synchronize
			rightPanel_watch_sync $addr
			# Clear highligh
			set var [lindex $watch_data($addr) 1]
			$watch_text.$var configure -fg ${Simulator::normal_color}
		}
	}

	## Read value from simulator engine
	 # @parm String addr - hexadecimal register address
	 # @return String - hexadecimal value or {--}
	private method read_from_simulator {addr} {
		## Determinate address type (Bit / Internal / Enternal / Expanded)
		if {[string index $addr 0] == {.}} {
			set addr [string replace $addr 0 0]
			if {![string length $addr]} {
				return {--}
			}
			set bit_addr 1
		} else {
			set bit_addr 0
		}
		set len		[string length $addr]
		set val		{--}
		set addr_dec	[expr "0x$addr"]

		# Bit
		if {$bit_addr} {
			if {$addr_dec > 0x7F} {
				if {[$this simulator_is_sfr_available [$this getRegOfBit $addr_dec]]} {
					set val [$this getBit $addr_dec]
				}
			} else {
				set val [$this getBit $addr_dec]
			}

		# Internal RAM
		} elseif {$len < 3} {
			# Normalize address
			if {$len == 1} {
				set addr "0$addr"
			}
			# Get register value
			if {$addr_dec < [lindex [$this cget -procData] 3]} {
				set val [$this getData $addr_dec]
			}

		# Expanded RAM
		} elseif {$len == 3} {
			if {$addr_dec < [lindex [$this cget -procData] 8]} {
				set val [$this getEram $addr_dec]
			}

		# External RAM
		} elseif {$len == 4} {
			if {$addr_dec < [$this cget -P_option_mcu_xdata]} {
				set val [$this getXdata $addr_dec]
			}
		}

		return $val
	}

	## Synchronize all bits in the specified SFR
	 # @parm Int dec_addr - SFR register address
	 # @return void
	public method rightPanel_watch_sync_sfr {dec_addr} {

		if {$validator_engaged} {
			return
		}
		if {$dec_addr % 8} {
			return
		}

		for {set i 0} {$i < 8} {incr i} {
			rightPanel_watch_sync .[format %X $dec_addr]
			incr dec_addr
		}
	}

	## Synchronize one register watch
	 # @parm String addr - hexadecimal register address
	 # @return Bool - result
	public method rightPanel_watch_sync {addr} {
		if {$validator_engaged} {return 1}
		if {!$regw_gui_initialized} {CreateRegWatchesGUI}

		# Detect bit address
		if {[string index $addr 0] == {.}} {
			set bit_addr 1
		} else {
			set bit_addr 0
		}

		# Get register value
		set val [read_from_simulator $addr]

		# Synchronize bits in the given register
		if {!$validator_engaged && [string length $addr] == 2} {

			set dec_addr [expr "0x$addr"]

			if {$dec_addr >= 0x20 && $dec_addr <= 0x2F} {
				set dec_addr [expr {($dec_addr - 0x20) * 8}]
				for {set i 0} {$i < 8} {incr i} {

					set hex_addr [format %X $dec_addr]
					if {[string length $hex_addr] == 1} {
						set hex_addr "0$hex_addr"
					}

					rightPanel_watch_sync .$hex_addr
					incr dec_addr
				}
			}
		}

		# Check for watch presence
		if {[lsearch -ascii -exact $watch_addrs $addr] == -1} {
			return 0
		}

		# Normalize register value
		if {!$bit_addr && [string length $val] == 1} {
			set val "0$val"
		}

		set var [lindex $watch_data($addr) 1]
		set path $watch_text.$var	;# Path to watch entry widget

		# Determinate original value
		set original_val [$watch_text.$var get]

		# Highlight value entry
		if { "0x$original_val" != "0x$val"} {
			$path configure -fg ${Simulator::highlight_color}
		}

		# Set new entry value
		set validator_engaged 1
		$watch_text.$var delete 0 end
		$watch_text.$var insert 0 $val
		set validator_engaged 0

		# Synchronize with help window
		help_window_update $addr $val

		# Done ...
		return 1
	}

	## Enable/Disable buttons on watches icon bar
	 # @return void
	private method watch_disEna_buttons {} {
		if {!$regw_gui_initialized} {return}

		if {[$watch_text index end] == {2.0}} {
			set state {disabled}
		} else {
			set state {normal}
		}

		if {$conf_menu != {}} {
			$conf_menu entryconfigure [::mc "Sort by"] -state $state
			$conf_menu entryconfigure [::mc "Remove all"] -state $state
		}
	}

	## Get status modified for register watches
	 # @return Bool - true if register watches were modified
	public method rightPanel_watch_modified {} {
		return $watches_modified
	}

	## Invoke register watches popup menu
	 # @parm Int X - absolute X coordinate
	 # @parm Int Y - absolute Y coordinate
	 # @parm Int x - relative X coordinate
	 # @parm Int y - relative Y coordinate
	 # @return void
	public method rightPanel_watch_popupmenu {X Y x y} {
		# Change current line
		rightPanel_watch_click $x $y

		## Enable/Disable menu items

		# If address entry is not empty -> disable all
		set addr [subst -nocommands "\$::RightPanel::watch_addr${obj_idx}"]
		if {$addr != {}} {
			set end [$watch_text index end]
		} else {
			set end {2.0}
		}
		# Empty list
		if {$end == {2.0}} {
			$watch_menu entryconfigure [::mc "Move top"]		-state disabled
			$watch_menu entryconfigure [::mc "Move up"]		-state disabled
			$watch_menu entryconfigure [::mc "Move down"]		-state disabled
			$watch_menu entryconfigure [::mc "Move bottom"]		-state disabled
			$watch_menu entryconfigure [::mc "Remove"]		-state disabled
			$watch_menu entryconfigure [::mc "Remove all"]		-state disabled
		# One item
		} elseif {$end == {3.0}} {
			$watch_menu entryconfigure [::mc "Move top"]		-state disabled
			$watch_menu entryconfigure [::mc "Move up"]		-state disabled
			$watch_menu entryconfigure [::mc "Move down"]		-state disabled
			$watch_menu entryconfigure [::mc "Move bottom"]		-state disabled
			$watch_menu entryconfigure [::mc "Remove"]		-state normal
			$watch_menu entryconfigure [::mc "Remove all"]		-state normal
		# More items
		} else {
			# First item
			if {$watch_curLine == 1} {
				$watch_menu entryconfigure [::mc "Move top"]	-state disabled
				$watch_menu entryconfigure [::mc "Move up"]	-state disabled
				$watch_menu entryconfigure [::mc "Move down"]	-state normal
				$watch_menu entryconfigure [::mc "Move bottom"]	-state normal
			# Last item
			} elseif {$watch_curLine == ($end - 2)} {
				$watch_menu entryconfigure [::mc "Move top"]	-state normal
				$watch_menu entryconfigure [::mc "Move up"]	-state normal
				$watch_menu entryconfigure [::mc "Move down"]	-state disabled
				$watch_menu entryconfigure [::mc "Move bottom"]	-state disabled
			# Any other item
			} else {
				$watch_menu entryconfigure [::mc "Move top"]	-state normal
				$watch_menu entryconfigure [::mc "Move up"]	-state normal
				$watch_menu entryconfigure [::mc "Move down"]	-state normal
				$watch_menu entryconfigure [::mc "Move bottom"]	-state normal
			}
			$watch_menu entryconfigure [::mc "Remove"]		-state normal
			$watch_menu entryconfigure [::mc "Remove all"]		-state normal
		}

		# Invoke popup menu
		tk_popup $watch_menu $X $Y
	}


	## Create bindings for defined key shortcuts -- register watches
	 # @return void
	public method rightPanel_watch_shortcuts_reevaluate {} {
		if {!$regw_gui_initialized} {return}
		foreach addr $watch_addrs {
			watch_entry_shortcuts_reset watch_text.[lindex $watch_data($addr) 1]
		}
	}

	## Set flag enabled
	 # @parm Bool bool - New value
	 # @return void
	public method right_panel_watches_set_enabled {bool} {
		set enabled $bool
	}
}

set ::RegWatches::menu_autoload  [lindex $::CONFIG(REGWATCHES_CONFIG) 0]
set ::RegWatches::sorting_order  [lindex $::CONFIG(REGWATCHES_CONFIG) 1]
set ::RegWatches::menu_autoclear [lindex $::CONFIG(REGWATCHES_CONFIG) 2]

# >>> File inclusion guard
}
# <<< File inclusion guard

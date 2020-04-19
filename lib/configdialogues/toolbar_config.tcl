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
if { ! [ info exists _TOOLBAR_CONFIG_TCL ] } {
set _TOOLBAR_CONFIG_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements main toolbar configuration dialog
# --------------------------------------------------------------------------


namespace eval toolbar {
	variable win			;# ID of toplevel dialog window
	variable dialog_opened	0	;# Bool: True if this dialog is already opened

	variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
	variable changed		;# Bool: Settings changed
	variable apply_button		;# ID of button "Apply"

	variable current_ListBox	;# ID of ListBox containing current toolbar setup
	variable options_ListBox	;# ID of ListBox containing available icons
	variable current_search_entry	;# ID of search EntryBox for $current_ListBox
	variable options_search_entry	;# ID of search EntryBox for $options_ListBox
	variable current_search_clear	;# ID of search EntryBox clear button for $current_ListBox
	variable options_search_clear	;# ID of search EntryBox clear button for $options_ListBox
	variable up_button		;# ID of button "Up"
	variable left_button		;# ID of button "Left"
	variable right_button		;# ID of button "Right"
	variable down_button		;# ID of button "Down"

	## Create the dialog
	 # @return void
	proc mkDialog {} {
		variable win			;# ID of toplevel dialog window
		variable dialog_opened		;# Bool: True if this dialog is already opened

		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable changed		;# Bool: Settings changed
		variable apply_button		;# ID of button "Apply"

		variable current_ListBox	;# ID of ListBox containing current toolbar setup
		variable options_ListBox	;# ID of ListBox containing available icons
		variable current_search_entry	;# ID of search EntryBox for $current_ListBox
		variable options_search_entry	;# ID of search EntryBox for $options_ListBox
		variable current_search_clear	;# ID of search EntryBox clear button for $current_ListBox
		variable options_search_clear	;# ID of search EntryBox clear button for $options_ListBox
		variable up_button		;# ID of button "Up"
		variable left_button		;# ID of button "Left"
		variable right_button		;# ID of button "Right"
		variable down_button		;# ID of button "Down"

		# Destroy the dialog if it's already opened
		if {$dialog_opened} {
			destroy .toolbar_config_dialog
		}
		set anything_modified 0
		set dialog_opened 1
		set changed 0

		# Create toplevel window
		set win [toplevel .toolbar_config_dialog -class {Configuration dialog} -bg ${::COMMON_BG_COLOR}]

		# Create window header
		label $win.header_label				\
			-compound left				\
			-image ::ICONS::32::configure		\
			-text [mc "Toolbar configuration"]	\
			-font [font create -size [expr {int(-20 * $::font_size_factor)}]]

		# Create main frame (ListBoxes and Arrows)
		set main_frame [frame $win.main_frame]

		## Create arrows frame and buttons
		set arrows [frame $main_frame.arrows]
			# Arrow "Up"
		set up_button [ttk::button $arrows.up		\
			-image ::ICONS::16::up			\
			-state disabled				\
			-style Flat.TButton			\
			-command {::configDialogues::toolbar::up}	\
		]
			# Arrow "Left"
		set left_button [ttk::button $arrows.left		\
			-image ::ICONS::16::left			\
			-state disabled					\
			-style Flat.TButton				\
			-command {::configDialogues::toolbar::left}	\
		]
			# Arrow "Right"
		set right_button [ttk::button $arrows.right		\
			-image ::ICONS::16::right			\
			-state disabled					\
			-style Flat.TButton				\
			-command {::configDialogues::toolbar::right}	\
		]
			# Arrow "Down"
		set down_button [ttk::button $arrows.down		\
			-image ::ICONS::16::down			\
			-state disabled					\
			-style Flat.TButton				\
			-command {::configDialogues::toolbar::down}	\
		]

		# Place arrows to the grid
		grid $up_button		-column 1 -row 0
		grid $left_button	-column 0 -row 1
		grid $right_button	-column 2 -row 1
		grid $down_button	-column 1 -row 2

		# Create ListBox of available items and its scrollbar
		set options_frame [frame $main_frame.options_frame]
		set listbox_frame [frame $options_frame.listbox_frame]
		set options_ListBox [ListBox $listbox_frame.options_ListBox	\
			-background {#FFFFFF} -deltay 21			\
			-selectmode single					\
			-highlightcolor {#FFFFFF}				\
			-yscrollcommand "$listbox_frame.options_scrollbar set"	\
			-highlightthickness 0					\
		]
		if {[winfo exists $options_ListBox.c]} {
			bind $options_ListBox.c <Button-5> {%W yview scroll +5 units; break}
			bind $options_ListBox.c <Button-4> {%W yview scroll -5 units; break}
		}
		pack $options_ListBox -fill both -expand 1 -side left
		pack [ttk::scrollbar $listbox_frame.options_scrollbar	\
			-takefocus 0					\
			-orient vertical				\
			-command "$options_ListBox yview"		\
		] -side right -after $options_ListBox -fill y

		# Create search bar for ListBox of available items
		set search_frame [frame $options_frame.search_frame]
		set options_search_entry [ttk::entry $search_frame.entry		\
			-validate all							\
			-validatecommand {::configDialogues::toolbar::search O %P}	\
		]
		DynamicHelp::add $search_frame.entry -text [mc "Search for a string in ListBox"]
		pack $options_search_entry -side left -fill x -expand 1
		set options_search_clear [ttk::button $search_frame.button	\
			-image ::ICONS::16::clear_left				\
			-style Flat.TButton					\
			-command "$options_search_entry delete 0 end"		\
			-state disabled						\
		]
		DynamicHelp::add $search_frame.button	\
			-text [mc "Clear"]
		pack $options_search_clear -side right -after $options_search_entry

		# Pack frames of the left part (available items)
		pack $search_frame -fill x
		pack [label $options_frame.label -text [mc "available items"]] -pady 5
		pack $listbox_frame -fill both -expand 1


		# Create ListBox of current items and its scrollbar
		set current_frame [frame $main_frame.current_frame]
		set listbox_frame [frame $current_frame.listbox_frame]
		set current_ListBox [ListBox $listbox_frame.current_ListBox	\
			-background {#FFFFFF} -deltay 21			\
			-selectmode single					\
			-highlightcolor {#FFFFFF}				\
			-yscrollcommand "$listbox_frame.current_scrollbar set"	\
			-highlightthickness 0					\
		]
		if {[winfo exists $current_ListBox.c]} {
			bind $current_ListBox.c <Button-5> {%W yview scroll +5 units; break}
			bind $current_ListBox.c <Button-4> {%W yview scroll -5 units; break}
		}
		pack $current_ListBox -fill both -expand 1 -side left
		pack [ttk::scrollbar $listbox_frame.current_scrollbar	\
			-takefocus 0					\
			-orient vertical				\
			-command "$current_ListBox yview"		\
		] -side right -after $current_ListBox -fill y

		# Create search bar for ListBox of current items
		set search_frame [frame $current_frame.search_frame]
		set current_search_entry [ttk::entry $search_frame.entry		\
			-validate all							\
			-validatecommand {::configDialogues::toolbar::search C %P}	\
		]
		DynamicHelp::add $search_frame.entry -text [mc "Search for a string in ListBox"]
		pack $current_search_entry -side left -fill x -expand 1
		set current_search_clear [ttk::button $search_frame.button	\
			-image ::ICONS::16::clear_left				\
			-style Flat.TButton					\
			-command "$current_search_entry delete 0 end"		\
			-state disabled						\
		]
		DynamicHelp::add $search_frame.button	\
			-text [mc "Clear"]
		pack $current_search_clear -side right -after $current_search_entry

		# Pack frames of the left part (current items)
		pack $search_frame -fill x
		pack [label $current_frame.label -text [mc "Current toolbar items"]] -pady 5
		pack $listbox_frame -fill both -expand 1


		# Set event bindings for ListBoxes
		bind $options_ListBox <<ListboxSelect>>	\
			"::configDialogues::toolbar::reevaluateArrows"
		bind $current_ListBox <<ListboxSelect>>	\
			"::configDialogues::toolbar::reevaluateArrows"


		# Pack left ListBox, arrows frame, right ListBox
		pack $options_frame -side left -anchor n -fill both -expand 1 -padx 5
		pack $arrows -side left -anchor center
		pack $current_frame -side left -anchor n -fill both -expand 1 -padx 5

		# Fill up ListBoxes
		fillListBox ${::ICONBAR_CURRENT}

		# Create button frame at the bottom
		set but_frame [frame $win.button_frame]
			# Button "Defaults"
		pack [ttk::button $but_frame.but_default		\
			-text [mc "Defaults"]				\
			-command {::configDialogues::toolbar::DEFAULTS}	\
		] -side left
		DynamicHelp::add $but_frame.but_default	\
			-text [mc "Reset settings to defaults"]
			# Button "Ok"
		pack [ttk::button $but_frame.but_ok			\
			-text [mc "Ok"]					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::toolbar::OK}		\
		] -side right -padx 2
			# Button "Apply"
		set apply_button [ttk::button $but_frame.but_apply	\
			-state disabled					\
			-text [mc "Apply"]				\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::toolbar::APPLY}	\
		]
		pack $apply_button -side right -padx 2
			# Button "Cancel"
		pack [ttk::button $but_frame.but_cancel			\
			-text [mc "Cancel"]				\
			-compound left					\
			-image ::ICONS::16::button_cancel		\
			-command {::configDialogues::toolbar::CANCEL}	\
		] -side right -padx 2

		# Pack frames and notebook
		pack $but_frame -side bottom -fill x -expand 0 -anchor s -padx 10 -pady 5
		pack $win.header_label -side top -pady 6
		pack $main_frame -side top -fill both -expand 1 -padx 10

		# Finalize creation of the dialog
		wm iconphoto $win ::ICONS::16::configure
		wm transient $win .
		wm title $win [mc "Configure Main Toolbar - %s" ${::APPNAME}]
		wm minsize $win 600 400
		raise $win
		catch {grab $win}
		wm protocol $win WM_DELETE_WINDOW {
			if {${::configDialogues::toolbar::anything_modified}} {
				set result [tk_messageBox \
					-parent .toolbar_config_dialog \
					-title [mc "Save changes?"] \
					-icon question \
					-type yesno \
					-message [mc "The settings have been changed. Do you want to save the changes?"] \
				]
				if {$result == {yes}} {
					::configDialogues::toolbar::OK
				} else {
					::configDialogues::toolbar::CANCEL
				}
			} else {
					::configDialogues::toolbar::CANCEL
			}
		}
		tkwait window $win
	}

	## Validator procedure for search EntryBoxes
	 # Search for the given string in the given ListBox and
	 #+ adjust EntryBox background color according to search result
	 # @parm Char where	-
	 #	"O" (O as Omega not 0 as zero) == Options ListBox (available items)
	 #	"C" == ListBox containing current onfiguration
	 # @parm String what	- String to search for
	 # @return Bool - Always true
	proc search {where what} {
		variable current_ListBox	;# ID of ListBox containing current toolbar setup
		variable options_ListBox	;# ID of ListBox containing available icons
		variable current_search_entry	;# ID of search EntryBox for $current_ListBox
		variable options_search_entry	;# ID of search EntryBox for $options_ListBox
		variable current_search_clear	;# ID of search EntryBox clear button for $current_ListBox
		variable options_search_clear	;# ID of search EntryBox clear button for $options_ListBox

		if {$where == {C}} {
			set listbox $current_ListBox
			set entry $current_search_entry
			set clearbut $current_search_clear
		} else {
			set listbox $options_ListBox
			set entry $options_search_entry
			set clearbut $options_search_clear
		}

		# Empty string
		if {$what == {}} {
			$entry configure -style TEntry
			$clearbut configure -state disabled
			return 1
		} else {
			$clearbut configure -state normal
		}

		# Search for the given string
		set what [string tolower $what]
		foreach item [$listbox items] {
			if {
				[string first $what				\
					[string tolower				\
						[$listbox itemcget $item -text]	\
					]					\
				] != -1
			} then {
				$listbox selection clear
				$listbox selection set $item
				$listbox see $item
				$entry configure -style StringFound.TEntry
				return 1
			}
		}

		# String not found
		$entry configure -style StringNotFound.TEntry
		return 1
	}

	## Fill ListBoxes acoring to the given toolbar definition
	 # Note: function depends on toplevel variable 'ICONBAR_ICONS'
	 # @parm List definition - Definition of current toolbar (eg. {new open | exit})
	 # @return void
	proc fillListBox {definition} {
		variable current_ListBox	;# ID of ListBox containing current toolbar setup
		variable options_ListBox	;# ID of ListBox containing available icons

		# Fill in left ListBox
		$options_ListBox insert end sep -text [mc " -- SEPARATOR --"]
		for {set i 0} {$i < [llength ${::ICONBAR_ICONS}]} {incr i} {
			# Determinate item name
			set item [lindex ${::ICONBAR_ICONS} $i]
			incr i
			# Skip invalid items
			if {[lsearch $definition $item] != -1} {continue}
			# Insert item
			$options_ListBox insert end $item				\
				-text [mc [lindex ${::ICONBAR_ICONS} [list $i 0]]]	\
				-image ::ICONS::16::[lindex ${::ICONBAR_ICONS} [list $i 2]]
		}

		# Fill in right ListBox
		foreach key $definition {
			# Insert separator
			if {$key == {|}} {
				$current_ListBox insert end #auto -text [mc " -- SEPARATOR --"]
			}
			# Deteminate item index
			set i [lsearch ${::ICONBAR_ICONS} $key]
			if {$i == -1} {continue}
			incr i
			# Insert regular item
			$current_ListBox insert end $key				\
				-text [mc [lindex ${::ICONBAR_ICONS} [list $i 0]]]	\
				-image ::ICONS::16::[lindex ${::ICONBAR_ICONS} [list $i 2]]
		}
	}

	## Enable/Disable arrow buttons according to selection in ListBoxes
	 # @return void
	proc reevaluateArrows {} {
		variable current_ListBox	;# ID of ListBox containing current toolbar setup
		variable options_ListBox	;# ID of ListBox containing available icons
		variable left_button		;# ID of button "Left"
		variable right_button		;# ID of button "Right"

		# Button "Left"
		if {[$current_ListBox selection get] == {}} {
			$left_button configure -state disabled
		} else {
			$left_button configure -state normal
		}

		# Button "Right"
		if {[$options_ListBox selection get] == {}} {
			$right_button configure -state disabled
		} else {
			$right_button configure -state normal
		}

		# Evaluate buttons "Up/Down"
		reevaluateUpDown

	}

	## Enable/Disable Up/Down arrow according to selection in the right ListBox
	 # @return void
	proc reevaluateUpDown {} {
		variable current_ListBox	;# ID of ListBox containing current toolbar setup
		variable down_button		;# ID of button "Down"
		variable up_button		;# ID of button "Up"

		# Determinate ID of selected item
		set sel [$current_ListBox selection get]

		# Valid selection
		if {$sel != {}} {
			# Button "Up"
			set curIndex [$current_ListBox index $sel]
			if {$curIndex == 0} {
				$up_button configure -state disabled
			} else {
				$up_button configure -state normal
			}

			# Button "Down"
			set numberOfItems [llength [$current_ListBox items]]
			if {$curIndex == ($numberOfItems - 1)} {
				$down_button configure -state disabled
			} else {
				$down_button configure -state normal
			}
		# Empty selection
		} else {
			$up_button configure -state disabled
			$down_button configure -state disabled
		}
	}

	## Command for button "Up"
	 # Move selected item in the right listbox up
	 # @return void
	proc up {} {
		variable current_ListBox	;# ID of ListBox containing current toolbar setup

		# Deteminate ID of selected item
		set sel [$current_ListBox selection get]
		# Determinate target index
		set trgIdx [$current_ListBox index $sel]
		incr trgIdx -1
		# Move item
		$current_ListBox move $sel $trgIdx
		$current_ListBox see $sel

		# Enable/Disabled buttons "Up/Down"
		reevaluateUpDown
		# Adjust status changed
		settings_changed
	}

	## Command for button "Down"
	 # Move selected item in the right listbox down
	 # @return void
	proc down {} {
		variable current_ListBox	;# ID of ListBox containing current toolbar setup

		# Deteminate ID of selected item
		set sel [$current_ListBox selection get]
		# Determinate target index
		set trgIdx [$current_ListBox index $sel]
		incr trgIdx
		# Move item
		$current_ListBox move $sel $trgIdx
		$current_ListBox see $sel

		# Enable/Disabled buttons "Up/Down"
		reevaluateUpDown
		# Adjust status changed
		settings_changed
	}

	## Command for button "Left"
	 # Move selected item from the right ListBox to the left one
	 # @return void
	proc left {} {
		variable current_ListBox	;# ID of ListBox containing current toolbar setup
		variable options_ListBox	;# ID of ListBox containing available icons

		# Local variables
		set sel [$current_ListBox selection get]	;# ID of the selected item
		set idx [$current_ListBox index $sel]		;# Index of the selected item

		# Remove selected item
		$current_ListBox delete $sel

		# Regular item (no separator)
		if {![regexp {^\d+$} $sel]} {
			# Find index of the item (in available icons)
			set i [lsearch ${::ICONBAR_ICONS} $sel]
			if {$i == -1} {return}
			incr i

			# Insert removed item into left ListBox
			$options_ListBox insert 1 $sel			\
				-text [lindex ${::ICONBAR_ICONS} [list $i 0]]	\
				-image ::ICONS::16::[lindex ${::ICONBAR_ICONS} [list $i 2]]
		}

		# Restore selection
		if {[llength [$current_ListBox items]] == $idx} {
			if {$idx} {
				incr idx -1
			}
		}
		set idx [$current_ListBox item $idx]
		$current_ListBox selection set $idx
		$current_ListBox see $idx
		$options_ListBox see $sel

		# Enable/Disable arrow buttons
		reevaluateArrows
		# Adjust status changed
		settings_changed
	}

	## Command for button "Right"
	 # Move selected item from the left ListBox to the right one
	 # @return void
	proc right {} {
		variable current_ListBox	;# ID of ListBox containing current toolbar setup
		variable options_ListBox	;# ID of ListBox containing available icons

		# Determinate target index
		set sel [$current_ListBox selection get]
		if {$sel == {}} {
			set trgIdx {end}
		} else {
			set trgIdx [$current_ListBox index $sel]
		}
		# Determinate source index and source item ID
		set sel [$options_ListBox selection get]
		set idx [$options_ListBox index $sel]

		# Separator
		if {$sel == {sep}} {
			$current_ListBox insert $trgIdx #auto -text [mc " -- SEPARATOR --"]
		# Regular item
		} else {
			set i [lsearch ${::ICONBAR_ICONS} $sel]
			if {$i == -1} {return}
			incr i
			$current_ListBox insert $trgIdx $sel			\
				-text [lindex ${::ICONBAR_ICONS} [list $i 0]]	\
				-image ::ICONS::16::[lindex ${::ICONBAR_ICONS} [list $i 2]]

			$options_ListBox delete $sel
		}

		# Restore selection
		if {[llength [$options_ListBox items]] == $idx} {
			if {$idx} {
				incr idx -1
			}
		}
		set idx [$options_ListBox item $idx]
		$options_ListBox selection set $idx
		$options_ListBox see $idx
		$current_ListBox see [$current_ListBox item $trgIdx]

		# Enable/Disable arrow buttons
		reevaluateArrows
		# Adjust status changed
		settings_changed
	}

	## Change content of configuration variables
	 # @return void
	proc use_settings {} {
		variable current_ListBox	;# ID of ListBox containing current toolbar setup

		set ::ICONBAR_CURRENT { }
		append ::ICONBAR_CURRENT [$current_ListBox items]
		append ::ICONBAR_CURRENT { }
		regsub -all {\s\d+\s} ${::ICONBAR_CURRENT} { | } ::ICONBAR_CURRENT
		regsub -all {\s\d+\s} ${::ICONBAR_CURRENT} { | } ::ICONBAR_CURRENT
		set ::ICONBAR_CURRENT [string trim ${::ICONBAR_CURRENT}]
	}

	## Save configuration to config file
	 # @return void
	proc save_config {} {
		::settings setValue "Main toolbar" ${::ICONBAR_CURRENT}

		# Commit
		::settings saveConfig
	}

	## Load configuratin from config file
	 # @return void
	proc load_config {} {
		set ::ICONBAR_CURRENT [::settings getValue "Main toolbar" ${::ICONBAR_DEFAULT}]
	}

	## Set status changed to True
	 # @return true
	proc settings_changed {} {
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable changed		;# Bool: Settings changed
		variable apply_button		;# ID of button "Apply"

		if {$changed} {return}

		set changed 1
		set anything_modified 1
		$apply_button configure -state normal
	}

	## Take back changes and destroy dialog window
	 # @return void
	proc CANCEL {} {
		variable win			;# ID of dialog toplevel window
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable dialog_opened		;# Bool: True if this dialog is already opened

		# Restore previous configuration
		if {$anything_modified} {
			load_config
			iconbar_redraw
			set anything_modified 0
			::X::disaena_menu_toolbar_for_current_project
			set anything_modified 0
		}

		# Get rid of dialog window
		set dialog_opened 0
		grab release $win
		destroy $win
	}

	## Apply changes and destroy dialog window
	 # @return void
	proc OK {} {
		variable win		;# ID of dialog toplevel window
		variable changed	;# Bool: Settings changed
		variable dialog_opened	;# Bool: True if this dialog is already opened
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)

		# Apply new settings
		if {$anything_modified} {
			use_settings	;# Adjust NS variables
			iconbar_redraw	;# Adjust GUI
			save_config	;# Save new config
			# Restore previous state of menu items (enabled / disabled)
			::X::disaena_menu_toolbar_for_current_project
			set anything_modified 0
		}

		# Get rid of dialog window
		set dialog_opened 0
		grab release $win
		destroy $win
	}

	## Apply changes in GUI
	 # @return Bool - result
	proc APPLY {} {
		variable apply_button	;# ID of button "Apply"
		variable changed	;# Bool: Settings changed

		# Reset status changed
		set changed 0
		$apply_button configure -state disabled

		# Adjust NS variables
		use_settings
		iconbar_redraw
		# Restore previous state of menu items (enabled / disabled)
		::X::disaena_menu_toolbar_for_current_project

		# done ...
		return 1
	}

	## Restrore defaults
	 # @return void
	proc DEFAULTS {} {
		variable current_ListBox	;# ID of ListBox containing current toolbar setup
		variable options_ListBox	;# ID of ListBox containing available icons
		variable win			;# ID of dialog toplevel window

		# Ask user
		if {[tk_messageBox					\
			-parent $win	-type yesno			\
			-icon question	-title [mc "Restore defaults"]	\
			-message [mc "Are you sure that you want restore default settings ?"]
		] != {yes}} {
			return
		}

		# Clear ListBoxes
		$current_ListBox delete [$current_ListBox items]
		$options_ListBox delete [$options_ListBox items]
		# Refill ListBoxes
		fillListBox ${::ICONBAR_DEFAULT}
		# Adjust status changed
		settings_changed
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

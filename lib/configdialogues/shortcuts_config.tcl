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
if { ! [ info exists _SHORTCUTS_CONFIG_TCL ] } {
set _SHORTCUTS_CONFIG_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements shortcuts configuration dialog
# --------------------------------------------------------------------------

namespace eval shortcuts {
	variable dialog_opened	0	;# Bool: True if this dialog is already opened
	variable win			;# ID of dialog toplevel window

	variable changed		;# Bool: Settings changed
	variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
	variable local_DB		;# Array: Local database of shortcuts
	variable root_hard_cd		;# List of hadrcoded shortcuts (main window only)
	variable currentNode		;# ID of the currently selected tree node
	variable search_in_P		;# Bool: search in progress
	# Empty image
	variable empty_image [image create bitmap]
	# Font for entry "Current shortcut"
	variable current_entry_font	[font create				\
		-family $::DEFAULT_FIXED_FONT					\
		-weight [expr {$::MICROSOFT_WINDOWS ? "normal" : "bold"}]	\
		-size [expr {int(-12 * $::font_size_factor)}]			\
	]
	# Normal font for tree widget nodes
	variable node_font		[font create		\
		-family $::DEFAULT_FIXED_FONT			\
		-weight normal					\
		-size [expr {int(-12 * $::font_size_factor)}]	\
	]
	# Bold font for tree widget nodes
	variable node_font_b		[font create		\
		-family {helvetica}				\
		-weight bold					\
		-size [expr {int(-14 * $::font_size_factor)}]	\
	]

	variable status_label		;# ID of status label
	variable search_entry		;# ID of entry widget on search panel
	variable search_clear		;# ID of button "Clear search entry"
	variable treeWidget		;# ID of the tree widget
	variable bottom_lf_label	;# ID of label for bottom label frame
	variable discard_button		;# ID of button "Discard"
	variable accept_button		;# ID of button "Accept"
	variable default_entry		;# ID of label containging default key shortcut
	variable default_button		;# ID of button "Restore default" (bottom label frame)
	variable clear_button		;# ID of button "Clear"
	variable current_entry		;# ID of entry "Current shortcut"

	## Create the dialog
	 # @return void
	proc mkDialog {} {
		variable win			;# ID of toplevel dialog window
		variable dialog_opened		;# Bool: True if this dialog is already opened
		variable local_DB		;# Array: Local database of shortcuts
		variable changed		;# Bool: Settings changed
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable search_entry		;# ID of entry widget on search panel
		variable search_clear		;# ID of button "Clear search entry"
		variable treeWidget		;# ID of the tree widget
		variable search_in_P		;# Bool: search in progress
		variable bottom_lf_label	;# ID of label for bottom label frame
		variable discard_button		;# ID of button "Discard"
		variable accept_button		;# ID of button "Accept"
		variable default_entry		;# ID of label containging default key shortcut
		variable default_button		;# ID of button "Restore default" (bottom label frame)
		variable clear_button		;# ID of button "Clear"
		variable current_entry		;# ID of entry "Current shortcut"
		variable empty_image		;# Empty image
		variable current_entry_font	;# Font for entry "Current shortcut"
		variable currentNode		;# ID of the currently selected tree node
		variable status_label		;# ID of status label
		variable root_hard_cd		;# List of hadrcoded shortcuts (main window only)
		variable node_font		;# Normal font for tree widget nodes
		variable node_font_b		;# Bold font for tree widget nodes

		# Destroy dialog window if it is already opened
		if {$dialog_opened} {
			destroy .shortcuts_config_dialog
		}
		set anything_modified 0
		set dialog_opened 1
		set currentNode {}
		set search_in_P 0
		set changed 0

		# Configure ttk styles
		ttk::style configure Shortcuts_Default.TLabel -relief sunken -borderwidth 1 -background {#F0F0F0}

		# Get settings from the program
		getSettings

		# Create list of hard-coded shortcuts related to main window
		set root_hard_cd {}
		foreach key ${::HARDCODED_SHORTCUTS} {
			lappend root_hard_cd [simplify_key_seq $key]
		}

		# Create toplevel window
		set win [toplevel .shortcuts_config_dialog -class {Configuration dialog} -bg ${::COMMON_BG_COLOR}]

		# Create window header
		label $win.header_label				\
			-compound left				\
			-image ::ICONS::32::configure		\
			-text [mc "Configure key shortcuts"]	\
			-font [font create -size [expr {int(-20 * $::font_size_factor)}]]

		# Create header labels for label frames
		set top_lf_label [label $win.top_lf_label	\
			-text [mc "available items"]		\
			-image ::ICONS::16::view_choose		\
			-compound left				\
		]
		set bottom_lf_label [label $win.bottom_lf_label	\
			-text [mc "<Nothing selected>"]		\
			-compound left -height 20		\
			-image $empty_image			\
		]

		# Create label frames
		set top_labelframe [ttk::labelframe $win.top_labelframe		\
			-labelwidget $top_lf_label -padding 7			\
		]
		set bottom_labelframe [ttk::labelframe $win.bottom_labelframe	\
			-labelwidget $bottom_lf_label -padding 7		\
		]

		# Create serach panel
		set search_frame [frame $top_labelframe.search_frame]
		pack [Label $search_frame.label	\
			-text [mc "Search:"]				\
			-helptext [mc "Enter your search string here"]	\
		] -side left
		set search_entry [ttk::entry $search_frame.entry			\
			-validate all							\
			-validatecommand {::configDialogues::shortcuts::search %P}	\
		]
		DynamicHelp::add $search_frame.entry	\
			-text [mc "Enter your search string here"]
		pack $search_entry -side left -fill x -expand 1
		set search_clear [ttk::button $search_frame.button	\
			-image ::ICONS::16::clear_left			\
			-style Flat.TButton				\
			-command "$search_entry delete 0 end"		\
			-state disabled					\
		]
		DynamicHelp::add $search_frame.button	\
			-text [mc "Clear"]
		pack $search_clear -side right -after $search_entry
		pack $search_frame -fill x -pady 5

		# Create frame for the tree widget and its scrollbar
		set tree_frame [frame $top_labelframe.tree_frame]
		pack $tree_frame -fill both -expand 1

		# Create tree widget showing available items
		set treeWidget [Tree $tree_frame.tree		\
			-selectfill 1				\
			-showlines 1				\
			-linesfill {#888888}			\
			-bg {#FFFFFF}				\
			-selectbackground {#CCCCFF}		\
			-selectforeground {#0000FF}		\
			-highlightthickness 0			\
			-padx 5					\
			-deltay 20				\
			-deltax 20				\
			-yscrollcommand "$tree_frame.scrollbar set"	\
			-crossopenimage ::ICONS::16::1downarrow		\
			-crosscloseimage ::ICONS::16::1rightarrow	\
			-selectcommand {::configDialogues::shortcuts::item_selected}	\
		]
		pack $treeWidget -fill both -expand 1 -side left
		bind $treeWidget <Button-5> {%W yview scroll +5 units; break}
		bind $treeWidget <Button-4> {%W yview scroll -5 units; break}

		# Create scrollbar for the tree widget
		pack [ttk::scrollbar $tree_frame.scrollbar	\
			-command "$treeWidget yview"		\
			-orient vertical			\
		] -fill y -side left -after $treeWidget

		# Fill in the tree
		foreach block ${::SHORTCUTS_LIST} {
			# Determinate category
			set cat_org [lindex $block 0]
			set cat "__$cat_org"

			# Adjus list of harcoded shotcuts
			set hardcoded {}
			foreach key [lindex $block 2] {
				lappend hardcoded [simplify_key_seq $key]
			}

			# Create category node
			$treeWidget insert end root $cat	\
				-selectable 1			\
				-data $hardcoded		\
				-text [mc [lindex $block 1]]	\
				-fill {#0000FF}			\
				-font $node_font_b

			## Create item node
			set block	[lreplace $block 0 2]	;# Item definitions
			set len		[llength $block]	;# Length of data block

			# Iterate over item definitions
			for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {

				# Local variables
				set item	[lindex $block $i]		;# Item ID
				set image	[lindex $block [list $j 2]]	;# Image ID or {}
				set text	[mc [lindex $block [list $j 3]]];# Item text
				set txt_len	[string length $text]		;# Item text length

				# Adjust text width
				append text [string repeat "\t" [expr {4 - ($txt_len / 8)}]]

				# Determinate text to show in the node
				set text_and_key $text
				append text_and_key [simplify_key_seq $local_DB($cat_org:$item)]

				# Determinate image ID
				if {$image != {}} {
					set image "::ICONS::16::$image"
				} else {
					set image $empty_image
				}

				# Adjust key combination
				set key_seq [regsub {Key(Press|Release)?\-} $local_DB($cat_org:$item) {}]

				# Create node in the tree widget
				$treeWidget insert end $cat $item		\
					-selectable 1				\
					-font $node_font			\
					-text $text_and_key			\
					-data [list				\
						$text				\
						[lindex $block [list $j 0]]	\
						$key_seq			\
					]	\
					-image $image -padx 25
			}
		}

		## Create widgets of bottom label frame
		 # Label and entry "Current"
		grid [label $bottom_labelframe.current_label	\
			-text [mc "Current shortcut:"]		\
		] -row 0 -column 0 -sticky w
		set current_entry [ttk::entry $bottom_labelframe.current_entry		\
			-validatecommand {::configDialogues::shortcuts::cur_entry_val %P}	\
		]
		grid $current_entry -row 0 -column 1
		bind $current_entry <KeyPress>			\
			{::configDialogues::shortcuts::current_entry_key %K;		break}
		bind $current_entry <Control-KeyPress>		\
			{::configDialogues::shortcuts::current_entry_key Ctrl+%K;		break}
		bind $current_entry <Alt-KeyPress>		\
			{::configDialogues::shortcuts::current_entry_key Alt+%K;		break}
		bind $current_entry <Control-Alt-KeyPress>	\
			{::configDialogues::shortcuts::current_entry_key Ctrl+Alt+%K;	break}
		set clear_button [ttk::button $bottom_labelframe.clear_button	\
			-image ::ICONS::16::clear_left				\
			-state disabled						\
			-style Flat.TButton					\
			-command {::configDialogues::shortcuts::clear_current}	\
		]
		DynamicHelp::add $bottom_labelframe.clear_button -text [mc "Clear"]
		grid $clear_button -row 0 -column 2 -sticky w

			# Label and entry "Default"
		grid [label $bottom_labelframe.default_label	\
			-text [mc "Default:"]			\
		] -row 1 -column 0 -sticky w
		set default_entry [ttk::label $bottom_labelframe.default_entry		\
			-style Shortcuts_Default.TLabel					\
		]
		grid $default_entry -row 1 -column 1 -sticky we
		set default_button [ttk::button $bottom_labelframe.default_button	\
			-image ::ICONS::16::up0						\
			-state disabled							\
			-command {::configDialogues::shortcuts::to_default}		\
			-style Flat.TButton						\
		]
		DynamicHelp::add $bottom_labelframe.default_button -text [mc "Restore default"]
		grid $default_button -row 1 -column 2 -sticky w

		# Button "Accept"
		set accept_button [ttk::button $bottom_labelframe.accept_button	\
			-command {::configDialogues::shortcuts::accept_current}	\
			-text [mc "Accept"]					\
			-compound left						\
			-image ::ICONS::16::ok					\
			-state disabled						\
		]
		DynamicHelp::add $bottom_labelframe.accept_button -text [mc "Accept new shortcut"]
		grid $accept_button -row 0 -column 4 -rowspan 2
		# Button "Original"
		set discard_button [ttk::button $bottom_labelframe.discard_button	\
			-command {::configDialogues::shortcuts::discard_current}	\
			-text [mc "Original"]					\
			-compound left						\
			-image ::ICONS::16::button_cancel			\
			-state disabled						\
		]
		DynamicHelp::add $bottom_labelframe.discard_button -text [mc "Discard new shortcut"]
		grid $discard_button -row 0 -column 5 -rowspan 2

		# Create status label
		set status_label [label $bottom_labelframe.status_label		\
			-fg {#DD0000} -anchor w -text {}			\
		]
		grid $status_label -row 2 -column 0 -columnspan 6 -sticky w

		# Create empty space on column 3
		grid columnconfigure $bottom_labelframe 3 -minsize 70


		## Button frame at the bottom
		set but_frame [frame $win.button_frame]
		 # Button "Reset"
		pack [ttk::button $but_frame.but_default		\
			-text [mc "Defaults"]				\
			-command {::configDialogues::shortcuts::DEFAULTS}	\
		] -side left
		DynamicHelp::add $but_frame.but_default -text [mc "Reset all settings to defaults"]
		 # Button "Ok"
		pack [ttk::button $but_frame.but_ok			\
			-text [mc "Ok"]					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::shortcuts::OK}	\
		] -side right -padx 2
		DynamicHelp::add $but_frame.but_ok -text [mc "Commit new settings"]
			# Button "Cancel"
		pack [ttk::button $but_frame.but_cancel			\
			-text [mc "Cancel"]				\
			-compound left					\
			-image ::ICONS::16::button_cancel		\
			-command {::configDialogues::shortcuts::CANCEL}	\
		] -side right -padx 2
		DynamicHelp::add $but_frame.but_cancel -text [mc "Take changes back and close dialog"]

		# Pack frames
		pack $win.header_label -side top -pady 6
		pack $top_labelframe -side top -fill both -expand 1 -padx 10
		pack $bottom_labelframe -side top -fill x -padx 10 -pady 10 -after $top_labelframe
		pack $but_frame -side bottom -fill x -padx 10 -pady 5

		# Set window attributes
		wm iconphoto $win ::ICONS::16::configure
		wm transient $win .
		wm title $win [mc "Configure shortcuts - %s" ${::APPNAME}]
		wm minsize $win 600 520
		raise $win
		catch {grab $win}
		wm protocol $win WM_DELETE_WINDOW {
			::configDialogues::shortcuts::CANCEL
		}
		tkwait window $win
	}

	## Argument of parameter '-selectcommand' for the tree widget
	 # @parm Widget widget	- Source tree widget
	 # @parm List nodes	- Selected nodes
	 # @return void
	proc item_selected {widget nodes} {
		variable current_entry_font	;# Font for entry "Current shortcut"
		variable node_font		;# Normal font for tree widget nodes
		variable search_entry		;# ID of entry widget on search panel
		variable search_in_P		;# Bool: search in progress
		variable discard_button		;# ID of button "Discard"
		variable accept_button		;# ID of button "Accept"
		variable default_entry		;# ID of label containging default key shortcut
		variable bottom_lf_label	;# ID of label for bottom label frame
		variable default_button		;# ID of button "Restore default" (bottom label frame)
		variable clear_button		;# ID of button "Clear"
		variable current_entry		;# ID of entry "Current shortcut"
		variable empty_image		;# Empty image
		variable status_label		;# ID of status label
		variable changed		;# Bool: Settings changed
		variable currentNode		;# ID of the currently selected tree node

		# Empty selection -> disable widgets on the bottom frame and return
		if {$nodes == {}} {
			# Save last changed item
			if {$changed} {
				current_item_changed
			}

			# Clear and disable componets of the bottom frame
			$current_entry	delete 0 end
			cur_entry_val {}
			$default_entry	configure -text {}
			$status_label	configure -text {}
			$current_entry	configure -state disabled
			$default_button	configure -state disabled
			$accept_button	configure -state disabled
			$discard_button	configure -state disabled
			$bottom_lf_label configure -text [mc "<Nothing selected>"] -image $empty_image
			return
		}

		# Only one node can be selected
		set node [lindex $nodes end]
		if {[llength $nodes] > 1} {
			foreach nd [lreplace $nodes end end] {
				$widget selection remove $nd
			}
			return
		}

		# Clear status label, search entry and ask for saving the last change
		$status_label configure -text {}
		if {!$search_in_P} {
			$search_entry delete 0 end
			if {$changed} {
				current_item_changed
			}
		}

		# If the selected node is a toplevel one -> open its node
		if {[regexp {^__} $node]} {
			$widget toggle $node
			$widget selection clear
			return
		}

		if {$currentNode != {}} {
			$widget itemconfigure $currentNode -font $node_font
		}
		$widget itemconfigure $node -font $current_entry_font

		# Set the current node
		set currentNode	$node

		# Adjust bottom frame
		set data	[$widget itemcget $node -data]
		$bottom_lf_label configure			\
			-image [$widget itemcget $node -image]	\
			-text [string trimright [lindex $data 0]]
		$current_entry configure -state normal
		$current_entry delete 0 end
		$current_entry insert end [simplify_key_seq [lindex $data 2]]
		cur_entry_val [simplify_key_seq [lindex $data 2]]
		$default_entry	configure -text [simplify_key_seq [lindex $data 1]]
		$default_button	configure -state normal
		ena_dis__accept_discard 0
	}

	## Binding for X-Key event for entry "Custom shortcut" (see proc. 'mkDialog')
	 # @parm String key_seq - human readable key combination string
	 # @return void
	proc current_entry_key {key_seq} {
		variable current_entry	;# ID of entry "Current shortcut"
		variable status_label	;# ID of status label
		variable changed	;# Bool: Settings changed
		variable treeWidget	;# ID of the tree widget
		variable currentNode	;# ID of the currently selected tree node
		variable root_hard_cd	;# List of hadrcoded shortcuts (main window only)

		if {$currentNode == {}} {
			return
		}

		# Clear entry "Custom shortcut"
		$current_entry delete 0 end
		cur_entry_val {}

		# Adjust key combination
		set lastchar [string index $key_seq end]
		if {[string index $key_seq end-1] == {+}} {
			if {[string is lower -strict $lastchar]} {
				set key_seq [string replace $key_seq	\
					end end [string toupper $lastchar]]
			} else {
				set key_seq [string replace $key_seq end end	\
					"Shift+[string toupper $lastchar]"]
			}
		}

		# Check for validity of the given shortcut and set flag "changed"
		set changed 0
		if {![regexp {^(Ctrl|Alt)\+} $key_seq] && ![regexp {^F\d\d?$} $key_seq]} {
			$status_label configure -text [mc "Modifier required (Control or Alt)"]
		} elseif {[lsearch $root_hard_cd $key_seq] != -1} {
			$status_label configure -text	\
				[mc "This combination is hard-coded in the main window, so it cannot be used"]
		} elseif {[lsearch [$treeWidget itemcget [$treeWidget parent $currentNode] -data] $key_seq] != -1} {
			$status_label configure -text	\
				[mc "This combination is hard-coded, so it cannot be used"]
		} else {
			set changed 1
		}
		if {!$changed} {
			$current_entry insert end $key_seq
			cur_entry_val $key_seq
			ena_dis__accept_discard 0
			return
		}

		# Change content of entry "Custom shortcut"
		$current_entry insert end $key_seq
		cur_entry_val $key_seq

		# Check if the given combination is not already assigned to something
		set name [lindex [key_seq_to_name	\
			[extend_key_seq $key_seq]	\
			[$treeWidget parent $currentNode]] 1]
		if {$name != {} && $name != [string trim [lindex [$treeWidget itemcget $currentNode -data] 0]]} {
			$status_label configure -text	\
				[mc "The '%s' key combination has already been assigned to \"%s\"." $key_seq $name]
		} else {
			$status_label configure -text {}
		}

		# Enable buttons "Accept" and "Original" (but only if user is not trying to redefine a shortcut with the same key combination)
		if {$name != [string trim [lindex [$treeWidget itemcget $currentNode -data] 0]]} {
			ena_dis__accept_discard 1
		}
	}

	## Clear entry "Custom shortcut"
	 # @return void
	proc clear_current {} {
		variable changed		;# Bool: Settings changed
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable current_entry		;# ID of entry "Current shortcut"
		variable status_label		;# ID of status label

		# Adjust flag "Anything modified"
		if {[$current_entry get] != {}} {
			set anything_modified 1
		}
		# Clear the entry widget and status label
		$current_entry delete 0 end
		cur_entry_val {}
		$status_label configure -text {}
		# Enable buttons "Accept" and "Original"
		ena_dis__accept_discard 1
		# Set flag "Changed"
		set changed 1
	}

	## Validate content of entry "Current shortcut"
	 # @parm String content - content of entry "Current shortcut"
	 # @return Bool - always 1
	proc cur_entry_val {content} {
		variable clear_button	;# ID of button "Clear"

		# Enable/Disable button "Clear"
		if {$content == {}} {
			$clear_button configure -state disabled
		} else {
			$clear_button configure -state normal
		}

		return 1
	}

	## Set current shortcut to default
	 # @return void
	proc to_default {} {
		variable treeWidget		;# ID of the tree widget
		variable changed		;# Bool: Settings changed
		variable currentNode		;# ID of the currently selected tree node
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable current_entry		;# ID of entry "Current shortcut"
		variable default_entry		;# ID of label containging default key shortcut
		variable status_label		;# ID of status label

		# Se flag "Anything modified"
		if {[$current_entry get] != [$default_entry cget -text]} {
			set anything_modified 1
		}

		# Adjust content of entry "Current shortcut"
		set key [$default_entry cget -text]
		$current_entry delete 0 end
		$current_entry insert 0 $key
		cur_entry_val $key

		# Check if the new setting is unique
		set name [lindex [key_seq_to_name	\
			[extend_key_seq $key ]		\
			[$treeWidget parent $currentNode]] 1]
		if {$name != {}} {
			$status_label configure -text	\
				[mc "The '%s' key combination has already been assigned to \"%s\"." $key $name]
		}

		# Enable buttons "Accept" and "Original"
		ena_dis__accept_discard 1
		set changed 1
	}

	## Accept new key combination fot the currently selected action
	 # @return void
	proc accept_current {} {
		variable changed		;# Bool: Settings changed
		variable treeWidget		;# ID of the tree widget
		variable current_entry		;# ID of entry "Current shortcut"
		variable currentNode		;# ID of the currently selected tree node
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)
		variable local_DB		;# Local database of shortcuts
		variable status_label		;# ID of status label

		# Gain details about the current action
		set data	[$treeWidget itemcget $currentNode -data]
		set parent	[$treeWidget parent $currentNode]
		set category	[string replace $parent 0 1]
		set text_org	[lindex $data 0]
		set default	[lindex $data 1]
		set current	[extend_key_seq [$current_entry get]]
		set text	$text_org
		append text	[$current_entry get]

		## Redefine shortcut for action which have the same shortcut as the current one
		$treeWidget itemconfigure $currentNode -data {}
		set defined [key_seq_to_name $current $parent]
		 # Redefine
		if {$defined != {}} {
			$status_label configure -text	\
				[mc "Removing key combination for action \"%s\"" [lindex $defined 1]]
			set defined [lindex $defined 0]
			set cat [string replace [$treeWidget parent $defined] 0 1]
			set local_DB($cat:$defined) {}
			set dt [$treeWidget itemcget $defined -data]
			set txt [lindex $dt 0]
			set dt [lindex $dt 1]
			$treeWidget itemconfigure $defined	\
				-text $txt			\
				-data [list $txt $dt {}]
		 # Keep
		} else {
			$status_label configure -text {}
		}

		# Adjust local database and the tree widget
		set local_DB($category:$currentNode) $current
		$treeWidget itemconfigure $currentNode	\
			-text $text			\
			-data [list $text_org $default $current]

		# Adjust modifed flags and disable buttons "Accept" and "Original"
		set changed 0
		set anything_modified 1
		ena_dis__accept_discard 0
	}

	## Discard new key combination fot the currently selected action
	 # @return void
	proc discard_current {} {
		variable changed		;# Bool: Settings changed
		variable treeWidget		;# ID of the tree widget
		variable current_entry		;# ID of entry "Current shortcut"
		variable status_label		;# ID of status label
		variable currentNode		;# ID of the currently selected tree node
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)

		# Restore previous content of entry "Current shortcut"
		$current_entry delete 0 end
		$current_entry insert end [simplify_key_seq	\
			[lindex [$treeWidget itemcget $currentNode -data] 2]]
		cur_entry_val [$current_entry get]

		# Clear status label
		$status_label configure -text {}

		# Disable buttons "Accept" and "Original"
		ena_dis__accept_discard 0
		set changed 0
	}

	## Ask user about saving the last change and conditionly save it
	 # @return void
	proc current_item_changed {} {
		variable changed	;# Bool: Settings changed
		variable currentNode	;# ID of the currently selected tree node
		variable win		;# ID of toplevel dialog window

		set changed 0
		if {[tk_messageBox		\
			-type yesno		\
			-parent $win		\
			-icon question		\
			-title [mc "Item changed"]	\
			-message [mc "The previous item was modified. Do you want to save it ?"] \
			] != {yes}
		} then {
			return
		}

		accept_current
	}

	## Translate key combination acceptable by Tk to "human readable" representation
	 # @parm String key_seq - Human readable representation of a key combination
	 # @return String - Key combination acceptable by Tk
	proc extend_key_seq {key_seq} {
		if {$key_seq == {}} {
			return {}
		}

		regsub -all {\+} $key_seq {-} key_seq
		regsub {Ctrl\-} $key_seq {Control-} key_seq
		set last_char [string index $key_seq end]
		if {![string compare {Shift-} [string range $key_seq {end-6} {end-1}]]} {
			set last_char [string toupper $last_char]
			set key_seq [string range $key_seq 0 {end-7}]
			append key_seq $last_char
		} elseif {[string index $key_seq {end-1}] == {-}} {
			set key_seq [string replace $key_seq end end [string tolower $last_char]]
		}

		return $key_seq
	}

	## Find name of action specified by the given key combination
	 # @parm String key_seq		- Key combination acceptable by Tk
	 # @parm String parent_node	- Parent node (category)
	 # @return String - Action name or {}
	proc key_seq_to_name {key_seq parent_node} {
		variable treeWidget		;# ID of the tree widget

		if {$key_seq == {}} {
			return {}
		}

		# Search the tree widget
		foreach node [$treeWidget nodes $parent_node] {
			if {![string compare $key_seq				\
				[lindex [$treeWidget itemcget $node -data] 2]]}	\
			{
				return	[list $node		\
					[string trimright	\
						[lindex [$treeWidget itemcget $node -data] 0]]]
			}
		}

		return {}
	}

	## Enable/Disable buttons "Discard" and "Accept"
	 # @parm Bool ena_dis - Enable/Disable (1 == enable; 0 == disable)
	 # @return void
	proc ena_dis__accept_discard {ena_dis} {
		variable discard_button	;# ID of button "Discard"
		variable accept_button	;# ID of button "Accept"

		if {$ena_dis} {
			$discard_button configure -state normal
			$accept_button configure -state normal
		} else {
			$discard_button configure -state disabled
			$accept_button configure -state disabled
		}
	}

	## Search the given string in the tree widget
	 # @parm String string - string to find
	 # @return Bool - always 1
	proc search {string} {
		variable search_entry	;# ID of entry widget on search panel
		variable search_clear	;# ID of button "Clear search entry"
		variable treeWidget	;# ID of the tree widget
		variable search_in_P	;# Bool: search in progress
		variable changed	;# Bool: Settings changed

		# Empty input string
		if {$string == {}} {
			$search_clear configure -state disabled
			$search_entry configure -style TEntry
			return 1
		}
		$search_clear configure -state normal

		# String to lowercase
		set string [string tolower $string]

		# Search all nodes
		foreach top [$treeWidget nodes root] {
			foreach node [$treeWidget nodes $top] {
				set text [$treeWidget itemcget $node -text]
				set text [string tolower $text]

				# String found
				if {[string first $string $text] != -1} {
					# Select the node
					set search_in_P 1
					$treeWidget opentree [$treeWidget parent $node]
					$treeWidget selection set $node
					$treeWidget see $node

					# Adjust entry widget and return
					set search_in_P 0
					$search_entry configure -style StringFound.TEntry
					return 1
				}
			}
		}

		# String not found
		$search_entry configure -style StringNotFound.TEntry
		return 1
	}

	## Retrieve settings related to this dialog from the program
	 # @return void
	proc getSettings {} {
		variable local_DB	;# Local database of shortcuts

		foreach key [array names ::SHORTCUTS_DB] {
			set local_DB($key) $::SHORTCUTS_DB($key)
		}
	}

	## Change content of configuration variables
	 # @return void
	proc use_settings {} {
		variable local_DB	;# Local database of shortcuts

		foreach key [array names local_DB] {
			set ::SHORTCUTS_DB($key) $local_DB($key)
		}
	}

	## Adjust application to fit new settings
	 # @return Bool - result
	proc apply_settings {} {
		# Adjust main window
		shortcuts_reevaluate
		mainmenu_redraw

		# Adjust projects
		foreach project ${::X::openedProjects} {

			# Adjust editors
			foreach editor [$project cget -editors] {
				$editor shortcuts_reevaluate
				$editor makePopupMenu
			}

			# Adjust right panel
			$project rightPanel_makePopupMenu
			$project rightPanel_watch_shortcuts_reevaluate
			# Adjust to do list
			$project TodoProc_makePopupMenu
			$project TodoProc_shortcuts_reevaluate
			# Adjust messages text
			$project messages_text_makePopupMenu
			$project messages_text_shortcuts_reevaluate
			# Adjust filelist
			$project filelist_makePopupMenu
			$project filelist_fsb_makePopupMenu
		}

		# Restore previous state of menu items (enabled / disabled)
		::X::disaena_menu_toolbar_for_current_project
	}

	## Save configuration to config file
	 # @return void
	proc save_config {} {
		variable local_DB	;# Local database of shortcuts

		foreach key [array names local_DB] {
			::settings setValue "Shortcuts/$key" $local_DB($key)
		}

		# Commit
		::settings saveConfig
	}

	## Load configuratin from config file
	 # @return void
	proc load_config {} {
		array unset ::SHORTCUTS_DB
		foreach block ${::SHORTCUTS_LIST} {
			set category	[lindex $block 0]	;# Shortcut category (eg. 'edit')
			set block	[lreplace $block 0 2]	;# Item definitions
			set len		[llength $block]	;# Length of data block

			# Iterate over data block and redefine local database
			for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {
				set key [lindex $block $i]	;# Item name

				set ::SHORTCUTS_DB($category:$key)			\
					[::settings getValue "Shortcuts/$category:$key"	\
					[lindex $block [list $j 0]]]
			}
		}
	}

	## Destroy the dialog
	 # @return void
	proc CANCEL {} {
		variable win		;# ID of toplevel dialog window
		variable local_DB	;# Local database of shortcuts
		variable dialog_opened	;# Bool: True if this dialog is already opened
		variable root_hard_cd	;# List of hadrcoded shortcuts (main window only)

		# Discard local database of shortcuts
		array unset local_DB
		unset root_hard_cd

		# Destroy dialog window
		set dialog_opened 0
		grab release $win
		destroy $win
	}

	## Use settings and destroy the dialog
	 # @return void
	proc OK {} {
		variable win			;# ID of toplevel dialog window
		variable changed		;# Bool: Settings changed
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)

		# Save last changed item
		if {$changed} {
			current_item_changed
		}

		# Use and save settings
		if {$anything_modified} {
			use_settings
			apply_settings
			save_config
		}

		# Destroy the dialog window
		CANCEL
	}

	## Restrore defaults
	 # @return void
	proc DEFAULTS {} {
		variable local_DB		;# Local database of shortcuts
		variable treeWidget		;# ID of the tree widget
		variable win			;# ID of toplevel dialog window
		variable changed		;# Bool: Settings changed
		variable anything_modified	;# Bool: Settings changed (stay set to 1 even after APPLY)

		# Ask user
		if {[tk_messageBox			\
			-parent $win			\
			-type yesno			\
			-title [mc "Confirmation required"]	\
			-icon question			\
			-message [mc "This will discard all shortcut settings and replace them with defaults. Are you sure by that ?"]\
			] != {yes}
		} then {
			return
		}

		# Adjust flags
		set changed 0		;# Last item modified --> NO
		set anything_modified 1	;# Any item modified --> YES

		# Reset local database of shortcuts
		array unset local_DB
		foreach block ${::SHORTCUTS_LIST} {
			set category	[lindex $block 0]	;# Shortcut category (eg. 'edit')
			set block	[lreplace $block 0 2]	;# Item definitions
			set len		[llength $block]	;# Length of data block

			# Redefine local database
			for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {
				set key [lindex $block $i]
				set local_DB($category:$key) [lindex $block [list $j 0]]
			}
		}

		## Refresh content of the tree widget
		$treeWidget selection clear
		# Iterate over toplevel items
		foreach top [$treeWidget nodes root] {
			set cat [string replace $top 0 1]	;# Shortcut category (eg. 'edit')

			# Iterate over lowlevel items
			foreach node [$treeWidget nodes $top] {
				# Long key sequence (for Tk)
				set key_seq [regsub {Key(Press|Release)?\-} $local_DB($cat:$node) {}]

				# Determinate new item data
				set data [$treeWidget itemcget $node -data]
				lset data 2 $key_seq

				# Determinate item text
				set text_and_key [lindex $data 0]
				append text_and_key [simplify_key_seq $key_seq]

				# Adjust item
				$treeWidget itemconfigure $node	\
					-data $data		\
					-text $text_and_key
			}
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

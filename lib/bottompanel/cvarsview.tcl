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
if { ! [ info exists _CVARSVIEW_TCL ] } {
set _CVARSVIEW_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides GUI interface designed for the bottom panel to show and
# manipulate contents of variables in a running C program on simulated 8051
# --------------------------------------------------------------------------

class CVarsView {
	## COMMON
	 # Normal font fot the text widget
	public common text_wdg_font_n [font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight normal					\
		-slant roman					\
	]
	 # Bold font for the text widget
	public common text_wdg_font_b [font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
		-slant roman					\
	]
	 # Italic font for the text widget
	public common text_wdg_font_i [font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight normal					\
		-slant italic					\
	]
	 # Background color for selected lines
	public common color_selected_line	{#CCCCFF}

	private variable main_frame			;# Widget: Main frame

	# Variables related to object initialization
	private variable parent				;# Widget: parent widget
	private variable cvv_gui_initialized	0	;# Bool: GUI initialized

	private variable panedwindow			;# Widget: Paned window for local and global variables
	# Int: Last paned window sash position
	private variable panel_sash_position	[lindex $::CONFIG(C_VARS_VIEW_CONF) 0]

	private variable local_variables_nlist	{}	;# List of Strings: Names of all local variables
	private variable local_variables	{}	;# List of Lists: Detail definition of all local variables
	private variable local_addresses	{}	;# List of Lists: Addresses of all local variables
	private variable local_addresses_list	{}	;# List of Lists: {scope name level block}

	private variable global_variables_nlist	{}	;# List of Strings: Names of all global variables
	private variable global_variables	{}	;# List of Lists: Detail definition of all global variables
	private variable global_addresses	{}	;# List of Lists: Addresses of all global variables
	private variable global_addresses_list	{}	;# List of Lists: {scope name level block}
	private variable global_displayed	{}	;# List of Integers: Indexes of displayed variables

	private variable help_window_frame	{}	;# Widget: Main frame for the help window

	private variable text_widget_local		;# Widget: Text widget for local variables
	private variable text_widget_global		;# Widget: Text widget for global variables
	private variable current_level		{}	;# Int: Current code level (determinated by simulator)
	private variable current_block		{}	;# Int: Current code level (determinated by simulator)

	private variable validation_ena		1	;# Bool: Entries validation and synchronization enabled

	private variable search_entry_Local		;# Widget: Search entry for local variables
	private variable search_clear_Local		;# Widget: Clear button for search entry box for local variables
	private variable search_entry_Global		;# Widget: Search entry for global variables
	private variable search_clear_Global		;# Widget: Clear button for search entry box for global variables
	private variable search_val_in_progress 0	;# Bool: Search is in progress

	private variable selected_line_global	0	;# Int: Number of currently selected line in global variables (0 == nothig selected)
	private variable selected_line_local	0	;# Int: Number of currently selected line in local variables (0 == nothig selected)

	constructor {} {
	}

	destructor {
	}

	## Prepare object for creating its GUI
	 # @parm Widget _parent	- GUI parent widget
	 # @return void
	public method PrepareCVarsView {_parent} {
		set parent $_parent
		set cvv_gui_initialized 0
	}

	## Inform this tab than it has became active
	 # @return void
	public method CVarsViewTabRaised {} {
	}

	## Create GUI of this tab
	 # @return void
	public method CreateCVarsViewGUI {} {
		if {$cvv_gui_initialized} {return}
		set cvv_gui_initialized 1

		if {${::DEBUG}} {
			puts "CreateCVarsViewGUI \[ENTER\]"
		}

		## Create GUI of main frame
		set main_frame [frame $parent.main_frame]
		set panedwindow [panedwindow $main_frame.pw	\
			-sashwidth 5	-showhandle 0		\
			-opaqueresize 1	-orient horizontal	\
		]

		# Create part containing local variables
		set pane [create_list_of_variables Local]
# 		$panedwindow add $pane
# 		$panedwindow paneconfigure $pane -minsize 200

		# Create part containing global variables
		set pane [create_list_of_variables Global]
		$panedwindow add $pane
		$panedwindow paneconfigure $pane -minsize 200

		# Pack main GUI parts of the panel
		pack $panedwindow -fill both -expand 1
		pack $main_frame -fill both -expand 1

		# Restore sash position
		cvarsview_redraw_pane

		# Load CDB file if simulator is engaged and C language is used
		if {[$this cget -programming_language] && [$this is_frozen]} {
			set filename [$this simulator_get_cdb_filename]
			if {[catch {
				set file [open $filename r]
			}]} then {
				tk_messageBox		\
					-parent .	\
					-icon warning	\
					-type ok	\
					-title [mc "Permission denied"]	\
					-message [mc "Unable to read file\n'%s'"] $filename
			} else {
				cvarsview_load_cdb $file
				close $file
			}
		}
	}

	## Restore paned window sash position
	 # @return void
	public method cvarsview_redraw_pane {} {
		if {!$cvv_gui_initialized} {return}
# 		update idletasks
# 		$panedwindow sash place 0 $panel_sash_position 0
	}

	## Get panel configuration list
	 # @return List - Panel config
	public method cvarsview_get_config {} {
		if {$cvv_gui_initialized} {
# 			set panel_sash_position [lindex [$panedwindow sash coord 0] 0]
		}
		return [list $panel_sash_position]
	}

	## Search for certain variable by its name
	 # @parm String type	- Basic variable type specification ("Global" or "Local")
	 # @parm String string	- Variable name
	 # @return Bool - allways 1
	public method cvarsview_search {type string} {
		# Lock this function
		if {$search_val_in_progress} {return 0}
		set search_val_in_progress 1

		# Empty string given
		if {![string length $string]} {
			[subst -nocommands "\$search_entry_$type"] configure -style TEntry
			[subst -nocommands "\$search_clear_$type"] configure -state disabled
			set search_val_in_progress 0
			return 1
		}
		[subst -nocommands "\$search_clear_$type"] configure -state normal

		## Perform search
		set idx 0
		set found 0
		 # Global variable
		if {$type == {Global}} {
			foreach name $global_variables_nlist {
				if {![string first $string $name] && [lsearch $global_displayed $idx] != -1} {
					set found 1
					break
				}
				incr idx
			}
		 # Local variable
		} else {
		}


		# Variable found
		if {$found} {
			cvarsview_select_line $type [expr {[lsearch $global_displayed $idx] + 1}] 1
			[subst -nocommands "\$search_entry_$type"] configure -style StringFound.TEntry
		# Variable not found
		} else {
			[subst -nocommands "\$search_entry_$type"] configure -style StringNotFound.TEntry
		}


		# Unlock this function
		set search_val_in_progress 0
		return 1
	}

	## Select line in the text widget
	 # @parm String type		- Basic variable type specification ("Global" or "Local")
	 # @parm Int line_number	- Number of line to select (1 .. infinity)
	 # @parm Bool nofocus		- Do not focus the entrybox
	 # @return void
	public method cvarsview_select_line {type line_number nofocus} {
		cvarsview_unselect_line $type

		# Line with a global variable
		if {$type == {Global}} {
			set max [llength $global_displayed]
			if {$line_number > $max} {
				return
			}

			set selected_line_global $line_number
			$text_widget_global tag add tag_current_line $line_number.0 $line_number.0+1l
			$text_widget_global see $line_number.0
			incr line_number -1
			set eid [lindex $global_displayed $line_number]
			$text_widget_global.e_$eid configure	\
				-bg $color_selected_line	\
				-disabledbackground $color_selected_line
			if {!$nofocus} {
				focus $text_widget_global.e_$eid
			}

		# Line with a local variable
		} else {
		}
	}

	## Unselect line in the text widget
	 # @parm String type - Basic variable type specification ("Global" or "Local")
	 # @return void
	public method cvarsview_unselect_line {type} {
		# View with a global variable
		if {$type == {Global}} {
			if {$selected_line_global != 0} {
				incr selected_line_global -1
				$text_widget_global.e_[lindex $global_displayed $selected_line_global] configure	\
					-bg white -disabledbackground white
			}
			$text_widget_global tag remove tag_current_line 0.0 end
			set selected_line_global 0
		# View with a local variable
		} else {
		}
	}

	## Select line above the current one
	 # @parm Bool isglobal	- Global scope
	 # @parm Int lines	- Distance
	 # @return void
	public method cvarsview_selection_up {isglobal lines} {
		if {$isglobal} {
			if {$selected_line_global == 0} {
				return
			}
			set max [llength $global_displayed]
			set target_line $selected_line_global

			incr target_line -$lines
			while {$target_line < 1} {
				incr target_line $max
			}

			cvarsview_select_line Global $target_line 0
		}
	}

	## Select line below the current one
	 # @parm Bool isglobal	- Global scope
	 # @parm Int lines	- Distance
	 # @return void
	public method cvarsview_selection_down {isglobal lines} {
		if {$isglobal} {
			if {$selected_line_global == 0} {
				return
			}
			set max [llength $global_displayed]
			set target_line $selected_line_global

			incr target_line $lines
			while {$target_line > $max} {
				incr target_line -$max
			}

			cvarsview_select_line Global $target_line 0
		}
	}

	## Open the helpwindow for certain variable
	 # @parm Int id		- Variable ID
	 # @parm Bool isglobal	- Related to global scope variable
	 # @return void
	public method cvarsview_create_help_window {id isglobal} {
# 		set help_window_frame [frame .cvarsview_help_window -bg {#BBBBFF}]
#
# 		if {$isglobal} {
# 			set variable_def [lindex $global_variables $id]
# 			pack [label $help_window_frame.header	\
# 				-text [lindex $variable_def 1]	\
# 				-bg {#BBBBFF}			\
# 			] -anchor w
#
# 			set var_det_frame [frame $help_window_frame.details_frame -bg {#FFFFFF}]
# 			pack $var_det_frame -fill both -padx 2 -pady 2
#
# 			grid [label $var_det_frame.value_lbl	\
# 				-text "Value:"			\
# 			] -row 0 -column 0 -columnspan 3 -sticky w
#
# 		}
#
# # 			lappend global_variables [list						\
# # 				$scope				$name				\
# # 				[lindex $type_record 0]		[lindex $type_record end]	\
# # 				[lrange $type_record 1 end-1]	$address_space			\
# # 				$onstack			$stack				\
# # 				$registers			0				\
# # 				0								\
# # 			]
	}

	## Move with the help window
	 # @parm Bool isglobal	- Related to global scope variable
	 # @parm Int X		- Absolute X position
	 # @parm Int Y		- Absolute Y position
	 # @return void
	public method cvarsview_help_window_move {isglobal X Y} {
		if {[winfo exists $help_window_frame]} {
			incr X 10
			incr Y 10
			place $help_window_frame -x $X -y $Y -anchor sw
			raise $help_window_frame
		}
	}

	## Hide the help window
	 # @parm Bool isglobal	- Related to global scope variable
	 # @return void
	public method cvarsview_help_window_hide {isglobal} {
		if {[winfo exists $help_window_frame]} {
			destroy $help_window_frame
		}
	}

	## Create panel with list of global or local variables
	 # @parm String type - Basic variable type specification ("Global" or "Local")
	 # @return void
	private method create_list_of_variables {type} {
		set local_frame [frame $main_frame.var_${type}_frame]

		# Create the top frame
		set top_frame [frame $local_frame.top_frame]
		pack [label $top_frame.header	\
			-text [mc "$type static scalar variables"]	\
			-anchor w -justify left	\
		] -side left

		# Create search frame
		set search_frame [frame $top_frame.search_frame]
		pack [label $search_frame.search_lbl	\
			-text [mc "Search:"]		\
		] -side left
		set search_entry_$type [ttk::entry $search_frame.search_ent	\
			-validate all						\
			-validatecommand "$this cvarsview_search $type %P"	\
		]
		pack $search_frame.search_ent -side left
		set search_clear_$type [ttk::button $search_frame.search_clr_but\
			-image ::ICONS::16::clear_left				\
			-style Flat.TButton					\
			-command "$search_frame.search_ent delete 0 end"	\
			-state disabled						\
		]
		pack $search_frame.search_clr_but -side left

		# Pack top frame
		pack $search_frame -side right
		pack $top_frame -fill x -anchor nw

		# Create the text widget
		set text_frame [frame $local_frame.text_frame]
		set text_frame_main [frame $text_frame.main_frame -bd 1 -relief sunken]
		if {$type == {Local}} {
			set text [mc "Value        Level   Data type  Variable name"]
		} else {
			set text [mc "Value        Data type  Variable name"]
		}
		pack [label $text_frame_main.header		\
			-font $text_wdg_font_b -justify left	\
			-text $text				\
			-bd 0 -relief flat -bg white -anchor w	\
		] -fill x -anchor w -padx 0 -pady 0
		pack [ttk::separator $text_frame_main.sep	\
			-orient horizontal			\
		] -fill x
		set text_widget [text $text_frame_main.text	\
			-bg white -exportselection 0 -bd 0	\
			-width 0 -height 0 -relief flat		\
			-font $text_wdg_font_n			\
			-yscrollcommand "$text_frame.scrollbar set"	\
			-state disabled				\
			-cursor left_ptr			\
		]
		bind $text_widget <<Selection>>	"false_selection $text_widget; break"
		bind $text_widget <Button-1>	"$this cvarsview_select_line $type \[expr {int(\[%W index @%x,%y\])}\] 0"
		bind $text_widget <Menu>	{break}
		bind $text_widget <ButtonRelease-3> {break}
		pack $text_widget -fill both -expand 1

		pack $text_frame_main -fill both -expand 1 -side left
		pack [ttk::scrollbar $text_frame.scrollbar	\
			-command "$text_widget yview"		\
			-orient vertical			\
		] -fill y -side right -after $text_frame_main
		pack $text_frame -fill both -expand 1

		if {$type == {Local}} {
			set text_widget_local $text_widget
		} else {
			set text_widget_global $text_widget
		}

		# Create text tags
		$text_widget tag configure tag_current_line -background $color_selected_line
		$text_widget tag configure tag_variable -font $text_wdg_font_b
		$text_widget tag configure tag_datatype -font $text_wdg_font_i

		return $local_frame
	}

	## Load CDB file (debugging file generated by SDCC)
	 # @parm File cdb_file - Opened CDB file
	 # @return Bool - True in success
	public method cvarsview_load_cdb {cdb_file} {
		if {!$cvv_gui_initialized} {CreateCVarsViewGUI}
		set result 1

		set local_variables_nlist	{}
		set local_variables_list	{}
		set local_variables		{}
		set local_addresses		{}
		set local_addresses_list	{}
		set global_variables_nlist	{}
		set global_variables		{}
		set global_addresses		{}
		set global_addresses_list	{}

		# Parse linker and symbol records
		while {![eof $cdb_file]} {
			set line [gets $cdb_file]
			set subtype [string index $line 2]
			switch -- [string index $line 0] {
				{S} {	;# Symbol record
					if {$subtype != {G} && $subtype != {L} && $subtype != {F}} {
						continue
					}
					if {![symbol_record $subtype [string range $line 3 end]]} {
						set result 0
					}
				}
				{L} {	;# Linker record
					if {$subtype != {G} && $subtype != {L} && $subtype != {F}} {
						continue
					}
					if {![link_address_of_symbol $subtype [string range $line 3 end]]} {
						set result 0
					}
				}
				default {
					continue
				}
			}
		}

		# Initialize list of displayed global variables
		set global_displayed {}

		# Clear search entries
		$search_entry_Global delete 0 end

		# Adjust lists of addresses
		evaluate_lists_of_addresses

		# Clear the viewers
		cvarsview_clear_view local
		cvarsview_clear_view global

		# Load gained informations into the viewers
		cvarsview_load_global_variables

		return $result
	}

	## Adjust lists of addresses
	 # @see cvarsview_load_cdb
	 # Translate each start address to list of address of all registers occupied by the variable
	 # @return void
	private method evaluate_lists_of_addresses {} {

		# Process global vaiables
		set global_addresses_new {}
		set global_variables_new {}
		set global_variables_nlist_new {}
		foreach start_address $global_addresses name $global_addresses_list {
			set name [lindex $name 1]
			set idx [lsearch $global_variables_nlist $name]
			set addresses {}
			set lenght 0

			if {$idx == -1} {
				puts stderr "CVarsView::evaluate_lists_of_addresses :: Unknown error 0"
				continue
			}

			set glob_var_def [lindex $global_variables $idx]
			set length [lindex $glob_var_def 2]
			for {set i 0} {$i < $length} {incr i} {
				lappend addresses $start_address
				incr start_address
			}
			lappend global_addresses_new $addresses
			lappend global_variables_new $glob_var_def
			lappend global_variables_nlist_new $name
		}
		set global_addresses $global_addresses_new
		set global_variables $global_variables_new
		set global_variables_nlist $global_variables_nlist_new

		# Process local vaiables
	}

	## Handle symbol record
	 # @see cvarsview_load_cdb
	 # @parm Char subtype	- Variable scope ('G' == Global; 'L' == Local; 'F' == File)
	 # @parm String record	- Record data
	 # @return Bool - True on success
	private method symbol_record {subtype record} {
		set scope		{}
		set name		{}
		set level		{}
		set block		{}
		set type_record		{}
		set address_space	{}
		set onstack		{}
		set stack		{}
		set registers		{}

		if {$subtype == {F}} {
			set subtype {G}
		}
		set dolar_idx [string first {$} $record]
		if {$dolar_idx == -1} {return 0}
		set scope [string range $record 0 [expr {$dolar_idx - 1}]]

		set record [string replace $record 0 $dolar_idx]
		set dolar_idx [string first {$} $record]
		if {$dolar_idx == -1} {return 0}
		set name [string range $record 0 [expr {$dolar_idx - 1}]]

		set record [string replace $record 0 $dolar_idx]
		set dolar_idx [string first {$} $record]
		if {$dolar_idx == -1} {return 0}
		set level [string range $record 0 [expr {$dolar_idx - 1}]]

		set record [string replace $record 0 $dolar_idx]
		set bracket_idx [string first {(} $record]
		if {$bracket_idx == -1} {return 0}
		set block [string range $record 0 [expr {$bracket_idx - 1}]]

		set record [string replace $record 0 $bracket_idx]
		set bracket_idx [string first {)} $record]
		if {$bracket_idx == -1} {return 0}
		set type_record [string range $record 1 [expr {$bracket_idx - 1}]]
		set type_record [split $type_record {\{\},:}]

		set record [string replace $record 0 [expr {$bracket_idx + 1}]]
		set comma_idx [string first {,} $record]
		if {$comma_idx == -1} {return 0}
		set address_space [string range $record 0 [expr {$comma_idx - 1}]]

		set record [string replace $record 0 $comma_idx]
		set comma_idx [string first {,} $record]
		if {$comma_idx == -1} {return 0}
		set onstack [string range $record 0 [expr {$comma_idx - 1}]]

		set record [string replace $record 0 $comma_idx]
		set comma_idx [string first {,} $record]
		if {$comma_idx == -1} {
			set comma_idx [string length $record]
		}
		set stack [string range $record 0 [expr {$comma_idx - 1}]]

		if {$record != {}} {
			set record [string replace $record 0 $comma_idx]
			set registers [split [string range $record 1 end-1] {,}]
		}

		if {$subtype == {G}} {
			lappend global_variables_nlist $name
			lappend global_variables [list						\
				$scope				$name				\
				[lindex $type_record 0]		[lindex $type_record end]	\
				[lrange $type_record 1 end-1]	$address_space			\
				$onstack			$stack				\
				$registers			0				\
				0								\
			]
		} else {
			lappend local_variables_nlist $name
			lappend local_variables_list [list $level $block]
			lappend local_variables [list						\
				$scope				$name				\
				[lindex $type_record 0]		[lindex $type_record end]	\
				[lrange $type_record 1 end-1]	$address_space			\
				$onstack			$stack				\
				$registers			$level				\
				$block								\
			]
		}

		return 1
	}

	## Handle linker record
	 # @see cvarsview_load_cdb
	 # @parm Char subtype	- Variable scope ('G' == Global; 'L' == Local; 'F' == File)
	 # @parm String record	- Record data
	 # @return Bool - True on success
	private method link_address_of_symbol {subtype record} {
		set scope		{}
		set name		{}
		set level		{}
		set block		{}
		set address		{}

		if {$subtype == {F}} {
			set subtype {G}
		}

		set dolar_idx [string first {$} $record]
		if {$dolar_idx == -1} {return 0}
		set scope [string range $record 0 [expr {$dolar_idx - 1}]]

		set record [string replace $record 0 $dolar_idx]
		set dolar_idx [string first {$} $record]
		if {$dolar_idx == -1} {return 0}
		set name [string range $record 0 [expr {$dolar_idx - 1}]]

		set record [string replace $record 0 $dolar_idx]
		set dolar_idx [string first {$} $record]
		if {$dolar_idx == -1} {return 0}
		set level [string range $record 0 [expr {$dolar_idx - 1}]]

		set record [string replace $record 0 $dolar_idx]
		set colon_idx [string first {:} $record]
		if {$colon_idx == -1} {return 0}
		set block [string range $record 0 [expr {$colon_idx - 1}]]

		set address [string replace $record 0 $colon_idx]

		if {$subtype == {G}} {
			set addresses_lst	{global_addresses}
			set addresses_list_lst	{global_addresses_list}
		} else {
			set addresses_lst	{local_addresses}
			set addresses_list_lst	{local_addresses_list}
		}
		lappend $addresses_lst		[expr "0x$address"]
		lappend $addresses_list_lst	[list $scope $name $level $block]

		return 1
	}

	## Clear the specified viewer
	 # @parm String type - "Local" or "Global"
	 # @return void
	public method cvarsview_clear_view {type} {
		if {!$cvv_gui_initialized} {CreateCVarsViewGUI}

		if {$type == {local}} {
			set text_widget $text_widget_local
			set current_level {}
			set current_block {}
		} else {
			set text_widget $text_widget_global
		}
		$text_widget configure -state normal
		$text_widget delete 1.0 end
		$text_widget configure -state disabled
	}

	## Create variable record in the viewer
	 # @parm Int id			- Variable ID (an unique number)
	 # @parm String name		- Variable name
	 # @parm Int level		- Block level
	 # @parm Bool isglobal		- Is variable in global sope
	 # @parm Int isvector		- Is variable a vector
	 # @parm Int start_address	- Variable start address
	 # @parm Int end_address	- Variable end address
	 # @parm Char memory_type	- Type of memory where is the variable stored (see SDCC manual for more)
	 # @parm Bool signed		- Is variable signed (has meaning only for integers)
	 # @parm String datatype	- List describing data type (e.g. {SI DA2} is an array of two integers)
	 # @return void
	private method create_variable_record {id name level isglobal isvector start_address end_address memory_type signed datatype} {
		set data_type {}
		set dt_func {}
		set pointer { }
		if {$isglobal} {
			set text_widget $text_widget_global
		} else {
			set text_widget $text_widget_local
		}

		if {$start_address == {}} {
			puts "Error: start_address is empty: create_variable_record [list is=$id name=$name level=$level isglobal=$isglobal isvector=$isvector start_address=$start_address end_address=$end_address memory_type=$memory_type signed=$signed datatype=$datatype]"
			return
		}

		foreach dt $datatype {
			switch -glob -- $dt {
				{DA*} {	;# Array of <n> elements
					set argument [string replace $dt 0 1]
					return
				}
				{ST*} {	;# Structure of name <name>
					set argument [string replace $dt 0 1]
					return
				}
				{SB*} {	;# Bit ﬁeld of <n> bits
					set argument [string replace $dt 0 1]
					return
				}
				{SX} {	;# Sbit
					set data_type {sbit}
				}
				{DG} {	;# Generic pointer
					set pointer {*}
				}
				{DC} {	;# Code pointer
					set pointer {*}
				}
				{DX} {	;# External ram pointer
					set pointer {*}
				}
				{DD} {	;# Internal ram pointer
					set pointer {*}
				}
				{DP} {	;# Paged pointer
					set pointer {*}
				}
				{DI} {	;# Upper 128 byte pointer
					set pointer {*}
				}
				{DF} {	;# Function
					set dt_func {>> }
				}
				{SL} {	;# Long integer
					if {$signed == {U}} {
						set data_type {ulong}
					} else {
						set data_type {long}
					}
				}
				{SI} {	;# Integer
					if {$signed == {U}} {
						set data_type {uint}
					} else {
						set data_type {int}
					}
				}
				{SC} {	;# Char
					if {$signed == {U}} {
						set data_type {uchar}
					} else {
						set data_type {char}
					}
				}
				{SS} {	;# Short integer
					if {$signed == {U}} {
						set data_type {ushort}
					} else {
						set data_type {short}
					}
				}
				{SV} {	;# Void
					set data_type {void}
				}
				{SF} {	;# Float
					set data_type {float}
				}
			}
		}

		if {!$isglobal} {
			set level_str [string repeat { } [expr {7 - [string length $level]}]]
			append level_str $level { }
			$text_widget insert insert $level_str
		}

		$text_widget configure -state normal
		set entry [create_embedded_entry $text_widget $id $isglobal $start_address]
		if {$data_type == {float}} {
			$entry configure -state readonly
		}
		$text_widget window create insert -window $entry -pady 0

		set data_type "${dt_func}${data_type}${pointer}"
		set data_type "[string repeat { } [expr {12 - [string length $data_type]}]]$data_type"
		set tag_indexes {}

		lappend tag_indexes [$text_widget index insert]
		$text_widget insert insert $data_type
		lappend tag_indexes [$text_widget index insert]
		$text_widget insert insert { }
		lappend tag_indexes [$text_widget index insert]
		$text_widget insert insert $name
		lappend tag_indexes [$text_widget index insert]
		$text_widget insert insert "\n"

		$text_widget tag add tag_datatype [lindex $tag_indexes 0] [lindex $tag_indexes 1]
		$text_widget tag add tag_variable [lindex $tag_indexes 2] [lindex $tag_indexes 3]

		$text_widget configure -state disabled
	}

	## Create embeddable entry box for representing variable value
	 # @parm Widget target_widget	- Target text widget
	 # @parm Int id			- Variable ID (an unique number)
	 # @parm Bool isglobal		- Is variable in global scope
	 # @parm Int start_address	- Variable start address
	 # @return Widget - Created entry box
	private method create_embedded_entry {target_widget id isglobal start_address} {
		lappend global_displayed $id

		# Create entry widget
		set entry [entry $target_widget.e_$id			\
			-width 11 		-font $text_wdg_font_b	\
			-bg {#FFFFFF}		-validate key		\
			-takefocus 0		-highlightthickness 0	\
			-bd 0			-justify right		\
			-disabledbackground {#FFFFFF}			\
			-fg ${::Simulator::normal_color}		\
			-validatecommand [list $this cvarsview_validate $id $isglobal $start_address %P] \
		]
		$entry insert insert 0
		if {$isglobal} {
			set type {Global}
		} else {
			set type {Local}
		}

		# Set event bindings
		bind $entry <Button-1>		"$this cvarsview_select_line $type [expr {$id + 1}] 1"
		bind $entry <Key-Up>		"$this cvarsview_selection_up $isglobal 1"
		bind $entry <Key-Down>		"$this cvarsview_selection_down $isglobal 1"
		bind $entry <Key-Next>		"$this cvarsview_selection_down $isglobal 4"
		bind $entry <Key-Prior>		"$this cvarsview_selection_up $isglobal 4"
		bind $entry <Motion>		"$this cvarsview_help_window_move $isglobal %X %Y"
		bind $entry <Leave>		"$this cvarsview_help_window_hide $isglobal"
		bind $entry <Enter>		"$this cvarsview_create_help_window $id $isglobal"
		bind $entry <FocusIn>		"%W configure -fg ${::Simulator::normal_color}"
		bind $entry <Button-4>		"$target_widget yview scroll -5 units"
		bind $entry <Button-5>		"$target_widget yview scroll +5 units"

		# Return entry reference
		return $entry
	}

	## Load definded global variables into the viewer
	 # @return void
	public method cvarsview_load_global_variables {} {
		set id 0
		foreach variable_def $global_variables {
			set isvector 0
			set idx [lsearch $global_addresses_list [list					\
					[lindex $variable_def 0]	[lindex $variable_def 1]	\
					[lindex $variable_def 9]	[lindex $variable_def 10]	\
				]	\
			]
			if {$idx == -1} {
				continue
			}
			set start_address [lindex $global_addresses [list $idx 0]]
			set end_address [lindex $global_addresses [list $idx end]]
			create_variable_record				\
				$id [lindex $variable_def 1] {} 1	\
				$isvector $start_address $end_address	\
				[lindex $variable_def 5]		\
				[lindex $variable_def 3]		\
				[lindex $variable_def 4]
			incr id
		}
	}

	## Load definded global variables into the viewer
	 # TODO: This function is not implemented yet
	 # @return void
	 # @parm Int level	- Variable level
	 # @parm Int block	- Program block
	 # @return void
	public method cvarsview_load_local_variables {level block} {
		return
		if {$current_level == $level && $current_block == $block} {
			return
		}

		set current_level $level
		set current_block $block

		set idx [lsearch -ascii -exact $local_variables_list [list $level $block]]
		if {$idx == -1} {
			return 0
		}

		set variable_def [lindex $local_variables $idx]

		return 1
	}

	## Validator for entryboxes representing variable values
	 # @parm Int id		- Variable ID (an unique number)
	 # @parm Bool isglobal	- Variable is in the global scope
	 # @parm Int address	- Vaiable start address
	 # @parm String string	- String to validate
	 # @return Bool - Validation result
	public method cvarsview_validate {id isglobal address string} {
		set value $string
		set negative 0
		set min_value 0
		set max_value 0

		if {!$validation_ena} {return 1}
		set validation_ena 0

		if {$isglobal} {
			set definition [lindex $global_variables $id]
		} else {
			set validation_ena 1
			return 0 ;# <-- DEBUG
		}
		if {$address == {}} {
			error "Unknown address"
		}

		set datatype [lindex $definition 4]
		set mem_type [lindex $definition 5]
		set len [lindex $definition 2]
		set signed [lindex $definition 3]
		if {$signed == {S}} {
			set signed 1
		} else {
			set signed 0
		}

		# Check for valid characters
		if {$signed} {
			if {[string index $string 0] == {-}} {
				set negative 1
				set value [string replace $string 0 0]
			}
		}
		if {$value == {}} {
			set validation_ena 1
			return 1
		}
		if {![string is digit -strict $value]} {
			set validation_ena 1
			return 0
		}

		# Determinate valid value range
		if {$mem_type == {J} || $mem_type == {H}} {
			set max_value 1
		} else {
			set max_value [expr {int(pow(2, $len*8))}]
			if {$signed} {
				set min_value [expr {$max_value / 2}]
				set max_value [expr {$max_value / 2 - 1}]
			} else {
				incr max_value -1
			}
		}

		# Check for valid range
		if {$negative} {
			if {$value > $min_value} {
				set validation_ena 1
				return 0
			}
		} else {
			if {$value > $max_value} {
				set validation_ena 1
				return 0
			}
		}

		## Convert to list of decimal values
		 # Bit value
		if {$mem_type == {J} || $mem_type == {H}} {
			set value_list $value
		 # Other values
		} else {
			set value_list [list]
			set value [format %X $string]
			set value [string range $value end-[expr {$len * 2}] end]

			for {set i 0} {$i < $len} {incr i} {
				set val [string range $value end-1 end]
				set value [string replace $value end-1 end]

				if {$val == {}} {
					lappend value_list 0
				} else {
					lappend value_list [expr "0x$val"]
				}
			}
		}

		set command {}
		switch -- $mem_type {
			{A} { ;# External stack
			}
			{B} { ;# Internal stack
			}
			{C} { ;# Code
				set validation_ena 1
				return 0
			}
			{D} { ;# Code / static segment
				set validation_ena 1
				return 0
			}
			{E} { ;# Internal ram (lower 128) bytes
				set command {setDataDEC}
				set mem_type_for_SE D
				set synccmd {Simulator_sync_reg}
			}
			{F} { ;# External ram
				set command {setXdataDEC}
				set mem_type_for_SE X
				set synccmd {Simulator_XDATA_sync}
			}
			{G} { ;# Internal ram
				set command {setDataDEC}
				set mem_type_for_SE I
				set synccmd {Simulator_sync_reg}
			}
			{H} { ;# Bit addressable
				set mem_type_for_SE B
				if {[$this simulator_address_range $mem_type_for_SE $address]} {
					$this setBit $address $value
					$this Simulator_sync_reg [$this getRegOfBit $address]
				}
				set validation_ena 1
				return 1
			}
			{I} { ;# SFR space
				set mem_type_for_SE S
				set command {setSfr_directly}
				set synccmd {Simulator_sync_sfr}
			}
			{J} { ;# SBIT space
				set mem_type_for_SE J
				if {[$this simulator_address_range $mem_type_for_SE $address]} {
					$this setBit $address $value
					$this Simulator_sync_sfr [$this getRegOfBit $address]
				}
				set validation_ena 1
				return 1
			}
			{R} { ;# Register space
			}
			{Z} { ;# Used for function records, or any undeﬁned space code
			}
			default {
				set validation_ena 1
				return 1
			}
		}

		if {$command == {}} {
			set validation_ena 1
			return 0
		}
		foreach val $value_list {
			if {[$this simulator_address_range $mem_type_for_SE $address]} {
				$this $command $address $val
				$this $synccmd $address
			}
			incr address
		}

		set validation_ena 1
		return 1
	}

	## Enable or disable the panel
	 # @parm Bool enabled - 1 == Enable; 0 == Disable
	 # @return void
	public method cvarsview_setEnabled {enabled} {
		if {!$cvv_gui_initialized} {return}

		if {$enabled} {
			set state normal
		} else {
			set state disabled
		}

		foreach id $global_displayed {
			if {[$text_widget_global.e_$id cget -state] == {readonly}} {
				continue
			}
			$text_widget_global.e_$id configure -state $state
		}
	}

	## Synchronize with simulator engine (data are obtained from the engine)
	 # @parm Char memtype	- Type of memory (e.g. 'E' means IDATA)
	 # @parm Int address	- Address of changed register
	 # @return void
	public method cvarsview_sync {memtype address} {
		if {!$cvv_gui_initialized} {return}
		if {!$validation_ena} {return}
		if {$memtype == {I} && !($address % 8)} {
			set bitaddr $address
			for {set i 0} {$i < 8} {incr i} {
				cvarsview_sync J $bitaddr
				incr bitaddr
			}
		} elseif {$memtype == {E} && $address > 31 && $address < 40} {
			set bitaddr [expr {($address - 32) * 8}]
			for {set i 0} {$i < 8} {incr i} {
				cvarsview_sync H $bitaddr
				incr bitaddr
			}
		}

		set idx 0
		foreach addr $global_addresses {
			if {[lsearch $addr $address] != -1} {
				if {[lindex $global_variables [list $idx 5]] != $memtype} {
					continue
				}
				refresh_global_variable $idx
				break
			}
			incr idx
		}
	}

	## Refresh contents of certain global variable (synchronize with simulator engine)
	 # @parm Int idx - Variable ID
	 # @return void
	private method refresh_global_variable {idx} {
		if {[lsearch $global_displayed $idx] == -1} {
			return
		}

		set validation_ena 0
		set variable_def [lindex $global_variables $idx]
		set address_space [lindex $variable_def 5]
		set datatype [lindex $variable_def 4]
		set signed [lindex $variable_def 3]
		set length [lindex $variable_def 2]

		set value 0
		set byte_num 0
		foreach addr [lindex $global_addresses $idx] {
			switch -- $address_space {
				{G} {
					if {[$this simulator_address_range I $addr]} {
						incr value [expr {[$this getDataDEC $addr] << ($byte_num * 8)}]
					}
				}
				{E} {
					if {[$this simulator_address_range I $addr]} {
						incr value [expr {[$this getDataDEC $addr] << ($byte_num * 8)}]
					}
				}
				{I} {
					if {[$this simulator_address_range D $addr]} {
						incr value [expr {[$this getSfrDEC $addr] << ($byte_num * 8)}]
					}
				}
				{F} {
					if {[$this simulator_address_range X $addr]} {
						incr value [expr {[$this getXdataDEC $addr] << ($byte_num * 8)}]
					}
				}
				{J} {
					if {[$this simulator_address_range B $addr]} {
						incr value [$this getBit $addr]
					}
				}
				{H} {
					if {[$this simulator_address_range B $addr]} {
						incr value [$this getBit $addr]
					}
				}
			}
			incr byte_num
		}

		## Adjust value
		 # IEEE 754-1985 single precision floating-point number
		if {$datatype == {SF}} {
			## Special cases
			 # Zero
			if {$value == 0} {
			 # One
			} elseif {$value == 0x3F800000} {
				set value 1
			 # Minus One
			} elseif {$value == 0xBF800000} {
				set value -1
			 # Positive infinity
			} elseif {$value == 0x7F800000} {
				set value {+ infinity}
			 # Negative infinity
			} elseif {$value == 0xFF800000} {
				set value {- infinity}
			 # Not a number
			} elseif {(($value & 0x7F800000) == 0x7F800000) && ($value & 0x007FFFFF)} {
				set value {NaN}

			## Common cases
			} else {
				set sign	[expr {($value & 0x80000000) ? 1 : 0}]
				set exponent	[expr {int(($value & 0x7F800000) >> 23)}]
				set fraction_b	[expr {$value & 0x007FFFFF}]

				incr exponent -127

				set fraction 1
				set val 0.5
				set mask 0x00400000
				for {set i 0} {$i < 23} {incr i} {
					if {$fraction_b & $mask} {
						set fraction [expr {$fraction + $val}]
					}
					set val [expr {$val / 2}]
					set mask [expr {$mask >> 1}]
				}

				set value [expr {pow(-1,$sign) * pow(2,$exponent) * $fraction}]
			}

		 # Common signed integer
		} elseif {$signed == {S}} {
			set max_positive_value [expr {pow(2,($length * 8 - 1)) - 1}]
			if {$value > $max_positive_value} {
				set value [expr {$value - pow(2,($length * 8))}]
			}
			set value [expr {int($value)}]

		 # Common unsigned integer
		} else {
			set value [expr {int($value)}]
		}

		# Write value to the entrybox
		if {$datatype == {SF}} {
			$text_widget_global.e_$idx configure -state normal
		}
		$text_widget_global.e_$idx delete 0 end
		$text_widget_global.e_$idx insert 0 $value
		$text_widget_global.e_$idx configure -fg ${::Simulator::highlight_color}
		if {$datatype == {SF}} {
			$text_widget_global.e_$idx configure -state readonly
		}

		# Reeanable synchronization and entryboxes validation
		set validation_ena 1
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

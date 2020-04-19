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
if { ! [ info exists _SYMBOL_VIEWER_TCL ] } {
set _SYMBOL_VIEWER_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements assembly language symbols viewer (from code listing)
# --------------------------------------------------------------------------

class SymbolViewer {
	## Class variables
	 # Int: Counter of object intances
	public common count	0
	 # Font: Just normal font used in the table
	public common normal_font	[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight normal					\
	]
	 # Font: Bold font (the same size as $normal_font)
	public common bold_font	[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight bold					\
	]
	if {$::MICROSOFT_WINDOWS} {
		# it's better to do not use bold font for this purpose on MS Windows®
		set bold_font $normal_font
	}
	 # Dialog configuration
	public common config_list	$::CONFIG(SYMBOL_VIEWER_CONFIG)

	## Private object variables
	private variable obj_idx			;# Int: Current object number
	private variable symbol_table_data	{}	;# List: Data loaded from the code listing (see func. open_file)
	private variable current_line		{}	;# List: Current line data (selected lide in the table)
	private variable opened_file		{}	;# String: Full file name of the currently loaded code listing file
	private variable win				;# Widget: Dialog window
	private variable menu				;# Widget: Popup menu for the text widget
	private variable main_frame			;# Widget: Dialog main frame
	private variable reload_but			;# Widget: Button "Reload"
	private variable search_entry			;# Widget: EntryBox "Search"
	private variable clear_but			;# Widget: Button "Clear search entrybox"
	private variable status_bar_lbl			;# Widget: Status bar label widget
	private variable opened_file_lbl		;# Widget: Label on statusbar showing name of currently opened file
	private variable text_widget			;# Widget: Text widget containing the table of symbols

	constructor {} {
		# Create dialog window
		set win [toplevel .symbolviewer$count -class {Defined symbols} -bg ${::COMMON_BG_COLOR}]
		set obj_idx $count
		incr count

		# Create dialog GUI
		set main_frame [frame $win.main_frame]
		create_gui	;# Create widgets
		create_menus	;# Create menus
		create_tags	;# Create text tags
		create_bindings	;# Set event bindings

		# Set values for checkboxes in panel "Display"
		set i 0
		foreach name {DATA IDATA XDATA CODE BIT Number used unused} {
			set ::SymbolViewer::display_${obj_idx}($name) [lindex $config_list $i]
			incr i
		}
		# Set values for radiobuttons in panel "Sort by"
		set ::SymbolViewer::sort_by_${obj_idx}		[lindex $config_list $i]
		incr i
		set ::SymbolViewer::sort_by_order_${obj_idx}	[lindex $config_list $i]
		incr i

		# Finalize GUI
		pack $main_frame -fill both -expand 1 -padx 5 -pady 5
		bindtags $win [list $win Toplevel all .]
		focus -force $search_entry

		# Configure dialog window
		wm iconphoto $win ::ICONS::16::symbol
		wm title $win [mc "Assembly symbol table - MCU 8051 IDE"]
		wm minsize $win 520 350
		wm protocol $win WM_DELETE_WINDOW "$this close_window"
		update
		catch {
			wm geometry $win [regsub {^\=?\d+x\d+} [lindex $config_list $i]	\
				[regsub {\+\d+\+\d+$} [wm geometry $win] {}]	\
			]
		}

		# Set ...
		incr i
		set ::SymbolViewer::display_${obj_idx}(Special)	[lindex $config_list $i]
		if {[subst -nocommands "\$::SymbolViewer::display_${obj_idx}(Special)"] == {}} {
			set ::SymbolViewer::display_${obj_idx}(Special) 1
		}
	}

	destructor {
		# Save tool configuration
		if {[llength $config_list] < 12} {
			set config_list [list {} {} {} {} {} {} {} {} {} {} {} {}]
		}
		set i 0
		foreach name {DATA IDATA XDATA CODE BIT Number used unused} {
			lset config_list $i [subst -nocommands "\$::SymbolViewer::display_${obj_idx}($name)"]
			incr i
		}
		lset config_list $i [subst -nocommands "\$::SymbolViewer::sort_by_${obj_idx}"]
		incr i
		lset config_list $i [subst -nocommands "\$::SymbolViewer::sort_by_order_${obj_idx}"]
		incr i
		lset config_list $i [wm geometry $win]
		incr i
		lset config_list $i [subst -nocommands "\$::SymbolViewer::display_${obj_idx}(Special)"]

		# Clean up
		unset ::SymbolViewer::sort_by_${obj_idx}
		unset ::SymbolViewer::sort_by_order_${obj_idx}
		array unset ::SymbolViewer::display_${obj_idx}

		# Remove dialog window
		destroy $win
	}

	## Create menus
	 # @return void
	private method create_menus {} {
		## Create text widget popup menu
		set menu [menu $text_widget.menu]
		$menu add command -label [mc "Copy symbol name"] -compound left	\
			-underline 12 -command "$this text_copy_proc name"
		$menu add command -label [mc "Copy hex value"] -compound left	\
			-underline 5 -command "$this text_copy_proc hex"
		$menu add command -label [mc "Copy dec value"] -compound left	\
			-underline 5 -command "$this text_copy_proc dec"
		$menu add separator
		$menu add command -label [mc "Copy line"] -compound left	\
			-underline 1 -command "$this text_copy_proc line"	\
			-image ::ICONS::16::editcopy -accelerator {Ctrl+C}
	}

	## Set event bindings for window widgets
	 # @return void
	private method create_bindings {} {
		bind $text_widget <ButtonRelease-3>	"$this invoke_popup_menu %X %Y %x %y; break"
		bind $text_widget <<Selection>>		"false_selection $text_widget; break"
		bind $text_widget <Button-1>		"focus %W; $this select_line %x %y"
		bind $text_widget <Key-Down>		"$this key_down"
		bind $text_widget <Key-Up>		"$this key_up"
		bind $text_widget <Control-Key-c>	"$this text_copy_proc line; break"

		bind $win <Control-Key-o>		"$this open_file_dialog; break"
		bind $win <Key-F5>			"$this reload; break"
		bind $win <Control-Key-q>		"$this close_window; break"

		bindtags $search_entry	[list $search_entry TEntry $win all .]
		bindtags $text_widget	[list $text_widget Text $win all .]
	}

	## Create text tags
	 # @return void
	private method create_tags {} {
		$text_widget tag configure type_DATA	-foreground {#00DD00}
		$text_widget tag configure type_IDATA	-foreground {#0000DD}
		$text_widget tag configure type_XDATA	-foreground {#DD0000}
		$text_widget tag configure type_CODE	-foreground {#00DDDD}
		$text_widget tag configure type_BIT	-foreground {#AA8800}
		$text_widget tag configure type_Special	-foreground {#AA00FF}
		$text_widget tag configure type_Number	-foreground {#DD00DD}
		$text_widget tag configure used_YES	-foreground {#00DD00}
		$text_widget tag configure used_NO	-foreground {#DD0000}
		$text_widget tag configure tag_sel	-background {#DDDDDD} -font $bold_font
		$text_widget tag configure nth_row	-background ${::COMMON_BG_COLOR}

		$text_widget tag raise tag_sel nth_row
	}

	## Create window widgets
	 # @return void
	private method create_gui {} {
		# Create window frames
		set top_frame		[frame $main_frame.top_frame]		;# Button "Open"+"Reload" + Search bar
		set middle_frame	[frame $main_frame.middle_frame]	;# Table of symbols
		set bottom_frame	[frame $main_frame.bottom_frame]	;# Display options
		set sbar_frame		[frame $main_frame.sbar_frame]		;# Status bar

		## Create status bar
		set status_bar_lbl [label $sbar_frame.main_lbl	\
			-justify left -anchor w			\
		]
		set opened_file_lbl [label $sbar_frame.opened_file_lbl -fg {#0000DD}]
		pack $status_bar_lbl -fill x -side left
		pack $opened_file_lbl -side right -after $status_bar_lbl

		## Create top frame
		 # Button "Open file"
		pack [ttk::button $top_frame.open_but		\
			-image ::ICONS::16::fileopen		\
			-text [mc "Open *.LST"]			\
			-compound left 				\
			-command "$this open_file_dialog"	\
		] -side left
		DynamicHelp::add $top_frame.open_but	\
			-text [mc "Load table of symbols from list file (*.lst)\n\tOnly for: ASEM-51, MCU8051IDE and ASM51"]
		set_locat_status_tip $top_frame.open_but [mc "Open code listing"]
		 # Button "Reload"
		set reload_but [ttk::button $top_frame.reload_but	\
			-image ::ICONS::16::reload			\
			-text [mc "Reload"]				\
			-compound left 					\
			-command "$this reload"				\
			-state disabled					\
		]
		pack $reload_but -side left -padx 5
		set_locat_status_tip $reload_but [mc "Reload opened file"]
		 ## Create search bar
		set top_r_frame [frame $top_frame.right_frame]
		  # - Label
		pack [label $top_r_frame.search_lbl	\
			-text [mc "Search:"]		\
		] -side left
		  # - Entry
		set search_entry [ttk::entry $top_r_frame.search_entry		\
			-validate all						\
			-validatecommand "$this search_validate %P"		\
		]
		DynamicHelp::add $search_entry	\
			-text [mc "Search for symbol by its name or value"]
		set_locat_status_tip $search_entry [mc "Search for symbol"]
		pack $search_entry -side left
		  # - Button
		set clear_but [ttk::button $top_r_frame.clear_but	\
			-state disabled					\
			-style Flat.TButton				\
			-image ::ICONS::16::clear_left			\
			-command "$search_entry delete 0 end"		\
		]
		set_locat_status_tip $clear_but [mc "Clear search entry box"]
		pack $clear_but -side left
		pack $top_r_frame -side right

		## Create table of symbols
		set middle_l_frame [frame $middle_frame.left_frame -bd 1 -relief sunken]
		pack [label $middle_l_frame.header_lbl			\
			-bg white -padx 0 -pady 0 -width 0		\
			-text [mc "Symbol\t\t\t\tType\tHEX\tDEC\tUsed"]	\
			-font $bold_font -anchor w -justify left	\
		] -fill x
		pack [ttk::separator $middle_l_frame.sep	\
			-orient horizontal			\
		] -fill x
		set text_widget [text $middle_l_frame.text		\
			-bg white -width 0 -height 0 -bd 0 -relief flat	\
			-yscrollcommand "$middle_frame.scrollbar set"	\
			-cursor left_ptr -font $normal_font	\
			-state disabled					\
		]
		pack $text_widget -fill both -expand 1

		pack $middle_l_frame -side left -fill both -expand 1
		pack [ttk::scrollbar $middle_frame.scrollbar		\
			-orient vertical -command "$text_widget yview"	\
		] -fill y -side right -after $middle_l_frame

		## Create display options
		set main_opt_frame [ttk::labelframe	\
			$bottom_frame.main_opt_frm	\
			-text [mc "Display"]		\
			-padding 10			\
		]
		set row 0
		set col 0
		set i 0
		foreach name {DATA IDATA XDATA CODE BIT Number Special} {
			if {$col > 2} {
				set col 0
				incr row
			}
			grid [checkbutton $main_opt_frame.cb_x_$i			\
				-text $name -onvalue 1 -offvalue 0			\
				-variable ::SymbolViewer::display_${obj_idx}($name)	\
				-command "$this refresh"				\
			] -sticky w -row $row -column $col
			incr i
			incr col
		}
		incr row
		grid [ttk::separator $main_opt_frame.sep	\
			-orient horizontal			\
		] -sticky we -row $row -column 0 -columnspan 3
		incr row
		grid [checkbutton $main_opt_frame.cb_x_us			\
			-text [mc "Used symbols"] -onvalue 1 -offvalue 0	\
			-variable ::SymbolViewer::display_${obj_idx}(used)	\
			-command "$this refresh"				\
		] -sticky w -row $row -column 0 -columnspan 3
		incr row
		grid [checkbutton $main_opt_frame.cb_x_uus			\
			-text [mc "Unused symbols"] -onvalue 1 -offvalue 0	\
			-variable ::SymbolViewer::display_${obj_idx}(unused)	\
			-command "$this refresh"				\
		] -sticky w -row $row -column 0 -columnspan 3
		pack $main_opt_frame -side left -fill y -anchor n -padx 5

		# Create frame "Sort by"
		set sort_by_frame [ttk::labelframe	\
			$bottom_frame.sort_by_frm	\
			-text [mc "Sort by"]		\
			-padding 10			\
		]
		set row 0
		set col 0
		set i 0
		foreach name {{Symbol name} Type {Hex value} {Dec value} {Usage}} {
			if {$col > 2} {
				set col 0
				incr row
			}
			grid [radiobutton $sort_by_frame.rb_x_$i		\
				-text $name -value $i				\
				-variable ::SymbolViewer::sort_by_${obj_idx}	\
				-command "$this refresh"			\
			] -sticky w -row $row -column $col
			incr i
			incr col
		}
		incr row
		grid [ttk::separator $sort_by_frame.sep	\
			-orient horizontal		\
		] -sticky we -row $row -column 0 -columnspan 3
		incr row
		grid [radiobutton $sort_by_frame.rb_x_inc			\
			-text [mc "Incremental order"] -value 0			\
			-variable ::SymbolViewer::sort_by_order_${obj_idx}	\
			-command "$this refresh"				\
		] -sticky w -row $row -column 0 -columnspan 3
		incr row
		grid [radiobutton $sort_by_frame.rb_x_dec			\
			-text [mc "Decremental order"] -value 1			\
			-variable ::SymbolViewer::sort_by_order_${obj_idx}	\
			-command "$this refresh"				\
		] -sticky w -row $row -column 0 -columnspan 3
		pack $sort_by_frame -side left -fill y -anchor n -padx 10

		# Pack window frames
		pack $top_frame		-fill x
		pack $middle_frame	-fill both -expand 1 -pady 7
		pack $bottom_frame	-fill x
		pack $sbar_frame	-fill x
	}

	## Set local statusbar tip
	 # @parm Widget widget	- Target widget
	 # @parm String text	- Statusbar tip itselft
	 # @return void
	private method set_locat_status_tip {widget text} {
		bind $widget <Enter> [list $status_bar_lbl configure -text $text]
		bind $widget <Leave> [list $status_bar_lbl configure -text {}]
	}

	## Close dialog window
	 # @return void
	public method close_window {} {
		::itcl::delete object $this
	}

	## Invoke file selection dialog to load a new table of symbols for LST file
	 # @return void
	public method open_file_dialog {} {
		# Determinate initial directory
		if {$opened_file == {}} {
			if {${::X::project_menu_locked}} {
				set directory {~}
			} else {
				set directory [${::X::actualProject} cget -projectPath]
			}
		} else {
			set directory [file dirname $opened_file]
		}

		# Invoke project selection dialog
		KIFSD::FSD ::fsd	 				\
			-title [mc "Load symbol table - MCU 8051 IDE"]	\
			-directory $directory -master $win		\
			-defaultmask 0 -multiple 0 -filetypes [list		\
				[list [mc "Code listing"]	{*.lst}	]	\
				[list [mc "All files"]		{*}	]	\
			]

		# Open the selected after press of OK button
		::fsd setokcmd "
			::fsd deactivate
			$this open_file 0 \[::fsd get\]"

		::fsd activate	;# Activate the dialog
	}

	## Reload opened file if any
	 # @return void
	public method reload {} {
		open_file 0 $opened_file
	}

	## Try to open LST file and load table of symbols from it
	 # @parm Bool ignore_errors	- Ignore erros while opening the file
	 # @parm String filename	- Name of file to load
	 # @return void
	public method open_file {ignore_errors filename} {
		if {[catch {
			set file [open $filename r]
		}]} then {
			if {!$ignore_errors} {
				tk_messageBox		\
					-parent $win	\
					-type ok	\
					-icon warning	\
					-title [mc "Invalid file"]	\
					-message [mc "Unable to use selected file. Please check your permissions. File: '%s'" $filename]
			}
			return
		}

		# Parse file
		set symbol_table_data {}
		set read_line 0
		set line {}
		set name {}
		set addr {}
		set type {}
		set used 1
		while {![eof $file]} {
			set used 1
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
				if {![regexp {^(\?\?)?\w+} $line name]} {
					continue
				}
				if {![regexp {[\w\s]+$} $line line]} {
					continue
				}
				set type [lindex $line 0]
				if {$type == {S}} {
					set addr [lindex $line end]
				} else {
					set addr [string replace [lindex $line 2] end end]
				}

				# Determinate whether symbol is used
				if {[lindex $line end-1] == {NOT} || [lindex $line end-2] == {NOT}} {
					set used 0
				}

			# ASEM-51 Assembler symbol
			} elseif {$read_line == 2} {
				# Remove dangerous characters
				regsub -all {\{\}\"\"} $line {} line

				if {[llength $line] < 4} {
					set used 0
				}
				set addr [lindex $line 2]
				set name [lindex $line 0]
				set type [string index [lindex $line 1] 0]

				# Hexadecimal address must be 4 characters long
				if {!($type == {S} || $type == {R})} {
					set addr "[string repeat 0 [expr {4 - [string length $addr]}]]$addr"
				}

			# This line is not a part of symbol table
			} else {
				continue
			}

			# Address must be a valid hexadecimal value
			if {![string is xdigit -strict $addr] && !($type == {S} || $type == {R})} {
				continue
			}

			# Create new register watch
			if {[string length $name] > 31} {
				set name [string range $name 0 27]
				append name {...}
			}

			if {$type == {S} || $type == {R}} {
				lappend symbol_table_data [list $name $type $addr {0} $used]
			} else {
				lappend symbol_table_data [list $name $type $addr [expr "0x$addr"] $used]
			}
		}

		set opened_file $filename
		$reload_but configure -state normal
		$opened_file_lbl configure -text [file tail $filename]
		close $file
		refresh
	}

	## Sort list of loaded symbols according to user settings
	 # @return void
	private method sort_table {} {
		if {[subst -nocommands "\$::SymbolViewer::sort_by_order_${obj_idx}"]} {
			set order {-decreasing}
		} else {
			set order {-increasing}
		}
		set index [subst -nocommands "\$::SymbolViewer::sort_by_${obj_idx}"]
		if {$index == 3} {
			set type {-integer}
		} else {
			set type {-dictionary}
		}

		set symbol_table_data [lsort $order $type -index $index $symbol_table_data]
	}

	## Filter record with the given type and use flag
	 # @parm Char type	- Record type
	 # @parm Bool used	- Used flag
	 # @return List - {$long_type $long_used} or {0}
	private method filter_record {type used} {
		# Adjust symbol type
		switch -- $type {
			{D} {set type {DATA}}
			{I} {set type {IDATA}}
			{X} {set type {XDATA}}
			{C} {set type {CODE}}
			{B} {set type {BIT}}
			{N} {set type {Number}}
			{S} {set type {Special}}
			{R} {set type {Special}}
		}
		if {![subst -nocommands "\$::SymbolViewer::display_${obj_idx}($type)"]} {
			return 0
		}

		# Adjust flag USED
		if {$used} {
			if {![subst -nocommands "\$::SymbolViewer::display_${obj_idx}(used)"]} {
				return 0
			}
			set used [mc "YES"]
		} else {
			if {![subst -nocommands "\$::SymbolViewer::display_${obj_idx}(unused)"]} {
				return 0
			}
			set used [mc "NO"]
		}

		return [list $type $used]
	}

	## Refresh table of symbols (reload contents of the text widget from $symbol_table_data)
	 # @return void
	public method refresh {} {
		# There must be something loaded
		if {$opened_file == {}} {
			return
		}

		# Save data of the selected line
		if {$current_line != {}} {
			set current_line [$text_widget get $current_line.0 [list $current_line.0 lineend]]
			set current_line [list						\
				[lindex $current_line 0] [lindex $current_line 1]	\
				[lindex $current_line 2] [lindex $current_line 3]	\
				[lindex $current_line 4]				\
			]

			lset current_line 1 [string index [lindex $current_line 1] 0]
			if {[lindex $current_line 4] == {YES}} {
				lset current_line 4 1
			} else {
				lset current_line 4 0
			}
		}

		# Sort loaded table of symbols
		sort_table

		# Clear the text widget
		$text_widget configure -state normal
		$text_widget delete 0.0 end

		# Load table of symbols to the text widget
		set idx 0	;# Int: Symbol number (just index in the table, nothing more)
		set name {}	;# String: Symbol name defined in source code
		set type {}	;# Char: Symbol type (see func. code)
		set hexv {}	;# String: Hexadecimal symbol value
		set decv {}	;# Int: Decimal symbol value
		set used {}	;# Bool: Symbol used in source code
		set cur_found 0	;# Bool: Current line found
		foreach symbol_def $symbol_table_data {
			set name [lindex $symbol_def 0]
			set type [lindex $symbol_def 1]
			set hexv [lindex $symbol_def 2]
			set decv [lindex $symbol_def 3]
			set used [lindex $symbol_def 4]

			# Filter record
			set used [filter_record $type $used]
			if {$used == {0}} {
				continue
			}
			set type [lindex $used 0]
			set used [lindex $used 1]

			# Insert new record into the table
			$text_widget insert insert $name
			$text_widget insert insert [string repeat { } [expr {32 - [string length $name]}]]
			$text_widget insert insert $type
			$text_widget insert insert [string repeat { } [expr {8 - [string length $type]}]]
			$text_widget tag add type_${type} insert-8c insert
			if {$type == {Special}} {
				$text_widget insert insert $hexv
				$text_widget insert insert [string repeat { } [expr {16 - [string length $hexv]}]]
			} else {
				$text_widget insert insert $hexv
				$text_widget insert insert {    }
				$text_widget insert insert $decv
				$text_widget insert insert [string repeat { } [expr {8 - [string length $decv]}]]
			}
			$text_widget insert insert $used
			$text_widget tag add used_${used} insert-3c insert
			$text_widget insert insert "\n"
			if {!($idx % 3)} {
				$text_widget tag add nth_row insert-1l insert
			}

			# Try to find the selected line
			if {!$cur_found && [string equal $current_line $symbol_def]} {
				set cur_found 1
				set current_line $idx
				incr current_line
			}

			incr idx
		}

		# Restore selection
		if {$cur_found} {
			$text_widget tag add tag_sel $current_line.0 $current_line.0+1l
			$text_widget see $current_line.0
		} else {
			set current_line {}
		}

		# Disable the text widget and clear search entrybox
		$text_widget configure -state disabled
		$search_entry delete 0 end
	}

	## Select line in the table (event: <Button-1>)
	 # @parm Int x - Relative X coordinate
	 # @parm Int y - Relative Y coordinate
	 # @return void
	public method select_line {x y} {
		set current_line [expr {int([$text_widget index @$x,$y])}]
		if {$current_line == int([$text_widget index end])-1} {
			set current_line {}
			return
		}
		$search_entry delete 0 end
		$text_widget tag remove tag_sel 0.0 end
		$text_widget tag add tag_sel $current_line.0 $current_line.0+1l
	}

	## Search entrybox validator
	 # @parm String string	- String to validate (search for)
	 # @return Bool - always 1
	public method search_validate {string} {
		# Not empty string
		if {[string length $string]} {
			set string [string tolower [string trimleft $string 0]]
			$clear_but configure -state normal
		# Empty string -> abort
		} else {
			$search_entry configure -style TEntry
			$clear_but configure -state disabled
			return 1
		}

		# Search in the table
		set i 0
		set found_idx -1
		foreach symbol_def $symbol_table_data {
			set name [string tolower [lindex $symbol_def 0]]
			set type [lindex $symbol_def 1]
			set hexv [string trimleft [string tolower [lindex $symbol_def 2]] 0]
			set decv [lindex $symbol_def 3]
			set used [lindex $symbol_def 4]

			if {[filter_record $type $used] == {0}} {
				continue
			}

			if {![string first $string $name]} {
				set found_idx $i
				break
			}
			if {![string first $string $hexv]} {
				set found_idx $i
				break
			}
			if {![string first $string $decv]} {
				set found_idx $i
				break
			}

			incr i
		}

		set current_line {}
		$text_widget tag remove tag_sel 0.0 end

		# String not found
		if {$found_idx == -1} {
			$search_entry configure -style StringNotFound.TEntry
		# String found
		} else {
			set current_line [expr {$found_idx + 1}]
			$text_widget tag add tag_sel $current_line.0 $current_line.0+1l
			$text_widget see $current_line.0
			$search_entry configure -style StringFound.TEntry
		}

		return 1
	}

	## Event handler of the text widget <Key-Up>
	 # Select line above the currently selected one
	 # @return void
	public method key_up {} {
		if {$current_line == {} || $current_line < 2} {
			return
		}
		incr current_line -1
		$text_widget tag remove tag_sel 0.0 end
		$text_widget tag add tag_sel $current_line.0 $current_line.0+1l
		$search_entry delete 0 end
	}

	## Event handler of the text widget <Key-Down>
	 # Select line below the currently selected one
	 # @return void
	public method key_down {} {
		if {$current_line == {} || $current_line >= ([$text_widget index end] - 2)} {
			return
		}
		incr current_line
		$text_widget tag remove tag_sel 0.0 end
		$text_widget tag add tag_sel $current_line.0 $current_line.0+1l
		$search_entry delete 0 end
	}

	## Invoke text widget popup menu
	 # @parm Int X - Absolute mouse pointer X coordinate
	 # @parm Int Y - Absolute mouse pointer X coordinate
	 # @parm Int x - Relative mouse pointer X coordinate
	 # @parm Int y - Relative mouse pointer X coordinate
	 # @return void
	public method invoke_popup_menu {X Y x y} {
		select_line $x $y
		if {$current_line == {}} {
			set state disabled
		} else {
			set state normal
		}
		foreach entry {{Copy symbol name} {Copy hex value} {Copy dec value} {Copy line}} {
			$menu entryconfigure [::mc $entry] -state $state
		}
		tk_popup $menu $X $Y
	}

	## Copy piece of the table into clipboard
	 # @parm Char mode - What to copy
	 #	name	- Symbol name
	 #	hex	- Symbol hexadecimal value
	 #	dec	- Symbol decimal value
	 #	line	- Whole symbol definition
	 # @return void
	public method text_copy_proc {mode} {
		switch -- $mode {
			{name} {
				set s 0
				set e 31
			}
			{hex} {
				set s 39
				set e 44
			}
			{dec} {
				set s 47
				set e 52
			}
			{line} {
				set s 0
				set e 63
			}
		}

		clipboard clear
		clipboard append [string trim [$text_widget get $current_line.$s $current_line.$e]]
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

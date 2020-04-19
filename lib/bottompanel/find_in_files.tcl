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
if { ! [ info exists _FIND_IN_FILES_TCL ] } {
set _FIND_IN_FILES_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements panel "Find in files", GUI and function
# Inteted for bottom panel
# --------------------------------------------------------------------------

class FindInFiles {
	public common find_inf_count			0	;# Counter of class instances

	# Variables related to object initialization
	private variable parent				;# Widget: parent widget
	private variable find_inf_gui_initialized 0	;# Bool: GUI initialized

	private variable obj_idx			;# Int: Object index
	private variable abort_variable		0	;# Bool: Abort search
	private variable iteration		0	;# Int: Counter of search iterations (lines read)
	private variable folder				;# String: Choosen folder
	private variable pattern			;# String: Search pattern
	private variable reg_expr			;# Bool: Use regular expression
	private variable case_sen			;# Bool: Perform case sensitive search
	private variable pattern_length			;# Int: Pettern length

	private variable pattern_entry			;# Windegt: EntryBox "Pattern"
	private variable main_frame			;# Widget: Main frame
	private variable menu			{}	;# Widget: popup menu for text widge
	private variable text_widget			;# Widget: Text widget to show results
	private variable clear_button			;# Widget: Button "Clear"
	private variable find_stop_button	{}	;# Widget: Button "Find / Stop"

	constructor {} {
		# Increment object counter
		incr find_inf_count
		set obj_idx $find_inf_count

		# Load configuration
		if {[catch {
			set ::FindInFiles::recursive_$obj_idx		[lindex $::CONFIG(FIND_IN_FILES_CONFIG) 0]
			set ::FindInFiles::regular_expr_$obj_idx	[lindex $::CONFIG(FIND_IN_FILES_CONFIG) 1]
			set ::FindInFiles::case_sensitive_$obj_idx	[lindex $::CONFIG(FIND_IN_FILES_CONFIG) 2]
			set ::FindInFiles::folder_$obj_idx		[lindex $::CONFIG(FIND_IN_FILES_CONFIG) 3]
			set ::FindInFiles::mask_$obj_idx		[lindex $::CONFIG(FIND_IN_FILES_CONFIG) 4]
			set ::FindInFiles::pattern_$obj_idx		[lindex $::CONFIG(FIND_IN_FILES_CONFIG) 5]
		}]} then {
			set ::FindInFiles::recursive_$obj_idx		1
			set ::FindInFiles::regular_expr_$obj_idx	0
			set ::FindInFiles::case_sensitive_$obj_idx	1
			set ::FindInFiles::folder_$obj_idx		{}
			set ::FindInFiles::mask_$obj_idx		{*.asm,*.c,*.h}
			set ::FindInFiles::pattern_$obj_idx		{}
		}

		# Validate loaded configuration
		if {![string is boolean -strict [subst -nocommands "\$::FindInFiles::recursive_$obj_idx"]]} {
			set ::FindInFiles::recursive_$obj_idx 1
		}
		if {![string is boolean -strict [subst -nocommands "\$::FindInFiles::regular_expr_$obj_idx"]]} {
			set ::FindInFiles::regular_expr_$obj_idx 0
		}
		if {![string is boolean -strict [subst -nocommands "\$::FindInFiles::case_sensitive_$obj_idx"]]} {
			set ::FindInFiles::case_sensitive_$obj_idx 1
		}
	}

	destructor {
		# Remove status bar help for popup menus
		if {$menu != {}} {
			menu_Sbar_remove $menu
		}
	}

	## Prepare object for creating its GUI
	 # @parm Widget _parent	- GUI parent widget
	 # @return void
	public method PrepareFindInFiles {_parent} {
		set parent $_parent
		set find_inf_gui_initialized 0
	}

	## Inform this tab than it has became active
	 # @return void
	public method FindInFilesTabRaised {} {
		$pattern_entry selection range 0 end
		$pattern_entry icursor end
		focus $pattern_entry
	}

	## Create GUI of messages tab
	 # @return void
	public method CreateFindInFilesGUI {} {
		if {$find_inf_gui_initialized} {return}
		set find_inf_gui_initialized 1

		if {${::DEBUG}} {
			puts "CreateFindInFilesGUI \[ENTER\]"
		}

		create_findinfilesgui
		create_tags_and_bindings
		create_popup_menu
	}

	## Create GUI elements
	 # @return void
	private method create_findinfilesgui {} {
		set main_frame [frame $parent.main_frame]

		## Top frame
		set top_frame [frame $main_frame.top_frame]
		 # Entry "Pattern"
		set pattern_entry [ttk::entry $top_frame.pattern_entry			\
			-validate all							\
			-width 1							\
			-textvariable ::FindInFiles::pattern_$obj_idx			\
			-validatecommand "$this findinfiles_validate_crit_ent 0 %P"	\
		]
		bind $pattern_entry <Return> "$this findinfiles_search"
		bind $pattern_entry <KP_Enter> "$this findinfiles_search"
		setStatusTip -widget $pattern_entry	\
			-text [mc "Search pattern"]
		 # Entry "Mask"
		set mask_entry [ttk::entry $top_frame.mask_entry			\
			-validate all							\
			-width 1							\
			-textvariable ::FindInFiles::mask_$obj_idx			\
			-validatecommand "$this findinfiles_validate_crit_ent 1 %P"	\
		]
		bind $mask_entry <Return> "$this findinfiles_search"
		bind $mask_entry <KP_Enter> "$this findinfiles_search"
		setStatusTip -widget $mask_entry	\
			-text [mc "File mask (e.g. \"*.c,*.asm\")"]
		 # Entry "Folder"
		set folder_entry_frm [frame $top_frame.folder_entry_frm]
		set folder_entry [ttk::entry $folder_entry_frm.folder_entry		\
			-textvariable ::FindInFiles::folder_$obj_idx 			\
			-validate all							\
			-width 1							\
			-validatecommand "$this findinfiles_validate_crit_ent 2 %P"	\
		]
		set ::FindInFiles::folder_$obj_idx [$this cget -projectPath]
		bind $folder_entry <Return> "$this findinfiles_search"
		bind $folder_entry <KP_Enter> "$this findinfiles_search"
		pack $folder_entry -side left -fill x -expand 1 -pady 2
		 # Button "Select directory"
		pack [ttk::button $folder_entry_frm.select_dir_but	\
			-image ::ICONS::16::fileopen			\
			-style Flat.TButton				\
			-command "$this findinfiles_select_dir"		\
		] -side left
		DynamicHelp::add $folder_entry_frm.select_dir_but	\
			-text [mc "Choose destination location"]
		setStatusTip -widget $folder_entry_frm.select_dir_but -text [mc "Select folder"]
		 # Checkbutton "Recursive"
		pack [checkbutton $folder_entry_frm.recursive_chb	\
			-variable ::FindInFiles::recursive_$obj_idx	\
			-text [mc "Recursive"]				\
		] -side left -padx 10
		setStatusTip -widget $folder_entry_frm.recursive_chb -text [mc "Search in all subfolders"]
		 # Button "Start / Stop search"
		set top_bottom_frame [frame $top_frame.bottom_frame]
		set find_stop_button [ttk::button $top_bottom_frame.find_stop_button	\
			-text [mc "Find"]						\
			-image ::ICONS::16::find					\
			-compound left							\
			-command "$this findinfiles_search"				\
			-width 7							\
		]
		setStatusTip -widget $find_stop_button -text [mc "Start / Stop search"]
		 # Button "Clear"
		set clear_button [ttk::button $top_bottom_frame.clear_button	\
			-text [mc "Clear"]					\
			-image ::ICONS::16::clear_left				\
			-compound left						\
			-command "$this findinfiles_clear"			\
			-state disabled						\
			-width 7						\
		]
		setStatusTip -widget $clear_button -text [mc "Clear results"]
		pack $find_stop_button -side left -padx 2
		pack $clear_button -side left -padx 2
		 # Separator
		pack [ttk::separator $top_bottom_frame.sep	\
			-orient vertical			\
		] -fill y -side left -padx 10 -pady 2
		 # Checkbutton "Case sensitive"
		pack [checkbutton $top_bottom_frame.case_sen_chb		\
			-text [mc "Case sensitive"]				\
			-variable ::FindInFiles::case_sensitive_$obj_idx	\
		] -side left
		setStatusTip -widget $top_bottom_frame.case_sen_chb	\
			-text [mc "Perform case sensitive search"]
		 # Checkbutton "Regular expression"
		pack [checkbutton $top_bottom_frame.regular_expr_chb	\
			-text [mc "Regular expression"]			\
			-variable ::FindInFiles::regular_expr_$obj_idx	\
		] -side left
		setStatusTip -widget $top_bottom_frame.regular_expr_chb	\
			-text [mc "Pattern is a regular expression"]
		 # Labels ... (Pattern, Folder, Mask)
		grid [label $top_frame.pattern_lbl	\
			-text [mc "Pattern:"]		\
		] -row 0 -column 0 -sticky w
		grid [label $top_frame.folder_lbl	\
			-text [mc "Folder:"]		\
		] -row 0 -column 4 -sticky w
		grid [label $top_frame.template_lbl	\
			-text [mc "Mask:"]		\
		] -row 1 -column 0 -sticky w
		 # Button "Clear pattern entrybox"
		grid [ttk::button $top_frame.pattern_clr_but		\
			-image ::ICONS::16::clear_left			\
			-style Flat.TButton				\
			-command "set ::FindInFiles::pattern_$obj_idx {}"\
		] -row 0 -column 2
		setStatusTip -widget $top_frame.pattern_clr_but	\
			-text [mc "Clear pattern entrybox"]
		 # Button "Show help for file mask"
		grid [ttk::button $top_frame.mask_show_help	\
			-image ::ICONS::16::help		\
			-style Flat.TButton			\
			-command "$this findinfiles_hlp"	\
		] -row 1 -column 2
		setStatusTip -widget $top_frame.mask_show_help	\
			-text [mc "Show help for file mask"]
		 # Place some widgets into the grid
		grid $pattern_entry	-row 0 -column 1 -sticky we
		grid $folder_entry_frm	-row 0 -column 5 -sticky we
		grid $mask_entry	-row 1 -column 1 -sticky we
		grid $top_bottom_frame	-row 1 -column 4 -columnspan 2 -sticky we
		grid columnconfigure $top_frame 1 -weight 1
		grid columnconfigure $top_frame 5 -weight 1
		grid columnconfigure $top_frame 3 -minsize 20

		## Bottom frame (text widget and its scrollbar)
		set bottom_frame [frame $main_frame.bottom_frame]
		set text_widget [text $bottom_frame.text			\
			-bg white						\
			-state disabled						\
			-bd 1							\
			-wrap none						\
			-highlightthickness 0					\
			-exportselection 0					\
			-cursor left_ptr					\
			-width 0						\
			-height 0						\
			-yscrollcommand "$bottom_frame.scrollbar set"		\
			-font [font create					\
				-family helvetica				\
				-size [expr {int(-12 * $::font_size_factor)}]	\
			]							\
			-fg {#555555}						\
		]
		pack $text_widget -side left -fill both -expand 1
		pack [ttk::scrollbar $bottom_frame.scrollbar		\
			-orient vertical -command "$text_widget yview"	\
		] -side right -after $text_widget -fill y

		# Mask panel frames
		pack $top_frame -fill x -anchor nw
		pack $bottom_frame -fill both -expand 1
		pack $main_frame -fill both -expand 1

		# Adjust GUI
		findinfiles_validate_crit_ent -1 {}
	}

	## Create text tags and event binding for the text widget
	 # @return void
	private method create_tags_and_bindings {} {
		# Create tags
		set bold_font [font create -family helvetica -size [expr {int(-12 * $::font_size_factor)}] -weight bold]
		$text_widget tag configure tag_highlight	-foreground {#000000} -font $bold_font
		$text_widget tag configure tag_filename		-foreground {#0000DD}
		$text_widget tag configure tag_linenumber	-foreground {#00DD00}
		$text_widget tag configure tag_normal		-foreground {#000000}
		$text_widget tag configure tag_cur_line		-background {#FFFF88}

		# Create evet bindings
		bind $text_widget <ButtonRelease-3>	"$this findinfiles_popupmenu %X %Y %x %y; break"
		bind $text_widget <Button-1>		"$this findinfiles_click %x %y; break"
		bind $text_widget <Double-Button-1>	"$this findinfiles_doubleclick %x %y; break"
		bind $text_widget <<Selection>>		"false_selection $text_widget; break"
	}

	## Create popup menu for the text widget
	 # @return void
	private method create_popup_menu {} {
		set menu $text_widget.popup_menu
		menuFactory {
			{command	"Go to"	{}		0	"findinfiles_goto_cur_line"
				{goto}		"Go to this line"}
			{command	"Clear"		{}	0	"findinfiles_clear"
				{editdelete}	"Clear this panel"}
		} $menu 0 "$this " 0 {} [namespace current]
		$menu entryconfigure [::mc "Clear"] -state disabled
	}

	## Invoke file selection dialog to select folder where to search
	 # @return void
	public method findinfiles_select_dir {} {
		KIFSD::FSD ::fsd	 				\
			-title [mc "Choose directory - MCU 8051 IDE"]	\
			-fileson 0 -master .				\
			-directory [subst -nocommands "\$::FindInFiles::folder_$obj_idx"]
		fsd setokcmd "set ::FindInFiles::folder_$obj_idx \[::fsd get\]"
		fsd activate
	}

	## Start searching
	 # @return void
	public method findinfiles_search {} {
		# Gain search options
		set folder	[file normalize [subst -nocommands "\$::FindInFiles::folder_$obj_idx"]]
		set mask	[subst -nocommands "\$::FindInFiles::mask_$obj_idx"]
		set pattern	[subst -nocommands "\$::FindInFiles::pattern_$obj_idx"]
		set reg_expr	[subst -nocommands "\$::FindInFiles::regular_expr_$obj_idx"]
		set case_sen	[subst -nocommands "\$::FindInFiles::case_sensitive_$obj_idx"]

		# Validate search options
		if {![string length $folder] || ![string length $mask] || ![string length $pattern]} {
			return
		}
		if {![file exists $folder]} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Folder not found"]	\
				-message [mc "The specified folder does not exist.\n'%s'" $folder]
			return
		}
		if {![file isdirectory $folder]} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Folder not found"]	\
				-message [mc "The string specified as a folder is not a folder.\n'%s'" $folder]
			return
		}
		if {$reg_expr && [catch {regexp -about $pattern}]} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Error"]	\
				-message [mc "Invalid regular expression"]
			return
		}

		# Adjust GUI (Find button, text widget ...)
		$find_stop_button configure				\
			-text [mc "Stop"] -image ::ICONS::16::cancel	\
			-command "$this findinfiles_stop"
		$text_widget configure -state normal
		$text_widget delete 0.0 end
		update

		# Determinate list of files
		set new_mask {}
		foreach glob [split $mask {,}] {
			lappend new_mask $glob
		}
		set mask $new_mask
		set files [list]
		catch {	;# For Microsoft Windows it has to be enclosed by catch
			foreach m $mask {
				eval "append files { } \[glob -directory {$folder} -nocomplain -types {f l} -- $m\]"
			}
		}
		if {[subst -nocommands "\$::FindInFiles::recursive_$obj_idx"]} {
			append files { } [regsub -all {[\{\}]} [recursive_search $folder $mask] {\\&}]
		}

		# Search
		if {!$reg_expr && !$case_sen} {
			set pattern [string tolower $pattern]
		}
		set pattern_length [string length $pattern]
		set iteration 0
		foreach filename $files {
			if {[search_in_file $filename]} {
				break
			}
		}

		# Adjust GUI (Find button, text widget ...)
		$text_widget delete end-1l end
		$text_widget configure -state disabled
		$find_stop_button configure		\
			-text [mc "Find"]		\
			-image ::ICONS::16::find	\
			-command "$this findinfiles_search"

		# Enable / Disable clear button and clear entry in the popup menu
		if {[$text_widget index {1.0 lineend}] == {1.0}} {
			set state disabled
		} else {
			set state normal
		}
		$menu entryconfigure [::mc "Clear"] -state $state
		$clear_button configure -state $state
	}

	## Perform recursive search for ceratin files in certain folder
	 # @parm String folder	- Directory to search
	 # @parm String mask	- File masks
	 # @return List - Found files
	private method recursive_search {folder mask} {
		set files {}
		catch {	;# For Microsoft Windows it has to be enclosed by catch
			foreach dir [glob -directory $folder -nocomplain -types {d} -- *] {
				foreach m $mask {
					eval "append files { } \[glob -directory {$dir} -nocomplain -types {f l} -- $m\]"
				}
				append files { } [recursive_search $dir $mask]
			}
		}
		if {[llength $files]} {
			update
		}
		return $files
	}

	## Search in certain file
	 # @parm String filename - File where to search in
	 # @return Bool - 1 == Search aborted; 0 == Normal
	private method search_in_file {filename} {
		# Open file
		if {[catch {
			set file [open $filename r]
		}]} then {
			return 0
		}

		# Local variables
		set relative_filename [string replace $filename 0 [string length $folder]]
		set indexes {}
		set text_idx {end}
		set line_number 0
		set matched_str {}

		# Iterate over lines
		while {![eof $file]} {
			incr line_number
			incr iteration
			set line [gets $file]

			# Update GUI and evaluate abort variable
			if {$iteration > 100} {
				if {[lindex [$text_widget yview] 1] == 1} {
					$text_widget see end
				}
				update
				if {$abort_variable} {
					set abort_variable 0
					return 1
				}
			}

			## Search string
			if {!$case_sen} {
				set line [string tolower $line]
			}
			set indexes {}
			set lengths {}
			set last_idx -1
			set idx 0
			set found 1
			 # Regular expression
			if {$reg_expr} {
				while $found {
					set found 0
					if {$case_sen} {
						set found [regexp -start $idx -- $pattern $line matched_str]
					} else {
						set found [regexp -nocase -start $idx -- $pattern $line matched_str]
					}

					set idx [string first $matched_str $line $idx]
					if {$last_idx >= $idx} {
						break
					}

					lappend indexes $idx
					lappend lengths [string length $matched_str]
					incr idx
					set last_idx $idx
				}
			 # Pure string pattern
			} else {
				while {$idx != -1} {
					set idx [string first $pattern $line $idx]
					if {$last_idx >= $idx} {
						break
					}

					lappend indexes $idx
					lappend lengths $pattern_length
					incr idx
					set last_idx $idx
				}
			}
			if {![llength $indexes]} {
				continue
			}

			## Display result
			 # Filename
			$text_widget insert insert $relative_filename
			$text_widget tag add tag_filename [list insert linestart] insert
			set text_idx [$text_widget index insert]
			 # ":"
			$text_widget insert insert ": "
			$text_widget tag add tag_normal $text_idx insert
			set text_idx [$text_widget index insert]
			 # Line number
			$text_widget insert insert $line_number
			$text_widget tag add tag_linenumber $text_idx insert
			set text_idx [$text_widget index insert]
			 # ":"
			$text_widget insert insert ":   "
			$text_widget tag add tag_normal $text_idx insert
			set text_idx [$text_widget index insert]
			scan $text_idx {%d.%d} row col
			 # Line content and highlight pattern found
			$text_widget insert insert $line
			foreach index $indexes length $lengths {
				$text_widget tag add tag_highlight	\
					$row.[expr {$col + $index}]	\
					$row.[expr {$col + $index + $length}]
			}
			$text_widget insert insert "\n"
		}

		# Close file
		catch {
			close $file
		}
		return 0
	}

	## Abort search
	 # @return void
	public method findinfiles_stop {} {
		set abort_variable 1
	}

	## Clear results
	 # @return void
	public method findinfiles_clear {} {
		# Clear text widget
		$text_widget configure -state normal
		$text_widget delete 0.0 end
		$text_widget configure -state disabled

		# Adjust controls
		$menu entryconfigure [::mc "Clear"] -state disabled
		$clear_button configure -state disabled
	}

	## Invoke popup menu for the text widget
	 # @parm Int X - Absolute mouse pointer position (X axis)
	 # @parm Int Y - Absolute mouse pointer position (Y axis)
	 # @parm Int x - Relative mouse pointer position (X axis)
	 # @parm Int y - Relative mouse pointer position (Y axis)
	 # @return void
	public method findinfiles_popupmenu {X Y x y} {
		findinfiles_click $x $y
		set index [$text_widget index [list @$x,$y linestart]]
		if {[$text_widget compare $index == [list $index lineend]]} {
			set state disabled
		} else {
			set state normal
		}
		$menu entryconfigure [::mc "Go to"] -state $state
		tk_popup $menu $X $Y
	}

	## Select line in the text widget by mouse click
	 # @parm Int x - Relative mouse pointer position (X axis)
	 # @parm Int y - Relative mouse pointer position (Y axis)
	 # @return void
	public method findinfiles_click {x y} {
		set index [$text_widget index [list @$x,$y linestart]]
		$text_widget tag remove tag_cur_line 0.0 end
		if {[$text_widget compare $index != [list $index lineend]]} {
			$text_widget tag add tag_cur_line $index $index+1l
		}
	}

	## Handle <DoubleButton-1> event on the text widget
	 # - Switch editor and go to specified line
	 # @parm Int x - Relative mouse pointer position (X axis)
	 # @parm Int y - Relative mouse pointer position (Y axis)
	 # @return void
	public method findinfiles_doubleclick {x y} {
		editor_goto_line [$text_widget index [list @$x,$y linestart]]
	}

	## Activate hypertext link on the specified index
	 # @parm TextIndex index - Index of linestart
	 # @return void
	private method editor_goto_line {index} {
		# Determinate line number and relative name of file
		set filename	[$text_widget tag nextrange tag_filename $index [list $index lineend]]
		set linenumber	[$text_widget tag nextrange tag_linenumber $index [list $index lineend]]
		set filename	[$text_widget get [lindex $filename 0] [lindex $filename 1]]
		set linenumber	[$text_widget get [lindex $linenumber 0] [lindex $linenumber 1]]
		if {![string length $filename] || ![string length $linenumber]} {
			return
		}

		# Switch editor
		set current_filename [lindex [$this editor_procedure {} getFileName {}] 1]
		if {$filename != $current_filename} {
			if {![$this fucus_specific_editor $filename 1]} {
				set filename [file join $folder $filename]
				if {[$this openfile $filename 1	. def def 0 0 {}] != {}} {
					$this switch_to_last
					update idletasks
					$this editor_procedure {} parseAll {}
				} else {
					return
				}
			}
		}

		# Go to target line
		$this editor_procedure {} focus_in {}
		$this editor_procedure {} goto $linenumber
	}

	## Validator function for all entry widgets
	 # Conditionaly disables button "Find"
	 # @parm Int for_what	- Number of entrybox from which this function was invoked
	 #	0 - Pattern
	 #	1 - Folder
	 #	2 - Mask
	 # @parm String content	- String to validate
	 # @return Bool - Always 1
	public method findinfiles_validate_crit_ent {for_what content} {
		if {![winfo exists $find_stop_button]} {
			return 1
		}
		set state normal
		set string {}
		foreach	var [list pattern_$obj_idx folder_$obj_idx mask_$obj_idx] \
			number {0 1 2} \
		{
			if {$for_what == $number} {
				set string $content
			} else {
				set string [subst -nocommands "\$::FindInFiles::$var"]
			}
			if {![string length $string]} {
				set state disabled
				break
			}
		}
		$find_stop_button configure -state $state
		return 1
	}

	## Invoke helwindow for entrybox "Mask"
	 # @return void
	public method findinfiles_hlp {} {
		# Destroy legend window
		if {[winfo exists .findinfiles_help_win]} {
			grab release .findinfiles_help_win
			destroy .findinfiles_help_win
			return
		}
		set x [expr {[winfo pointerx .] + 10}]
		set y [winfo pointery .]

		# Create legend window
		set win [toplevel .findinfiles_help_win -class {Help} -bg ${::COMMON_BG_COLOR}]
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

		# Create text widget
		set text [text $frame.text	\
			-bg {#FFFFCC}		\
			-exportselection 0	\
			-takefocus 0		\
			-cursor left_ptr	\
			-bd 0 -relief flat	\
			-font ${::Editor::defaultFont}	\
		]

		pack $frame -fill both -expand 1

		# Fill the text widget
		$text insert end [mc "Comma separated list of file masks (e.g \"*.c,*.h,*.asm\")\n"]
		$text insert end [mc "The mask may contain any of the following special characters:\n"]
		$text insert end [mc  "	?	Matches any single character.\n"]
		$text insert end [mc "	*	Matches any sequence of zero or more characters.\n"]
		$text insert end [mc "	\[chars\]	Matches any single character in chars.\n"]
		$text insert end [mc "		If chars contains a sequence of the form a-b then any\n"]
		$text insert end [mc "		character between a and b (inclusive) will match.\n"]
		$text insert end [mc "	\\x	Matches the character x."]

		# Show the text
		$text configure -state disabled
		pack $text -side bottom -fill both -expand 1

		# Show the window
		wm geometry $win "=600x180+$x+$y"
		update
		catch {
			grab -global $win
		}
	}

	## Menu action "Go to"
	 # @return void
	public method findinfiles_goto_cur_line {} {
		set index [lindex [$text_widget tag nextrange tag_cur_line 1.0 end] 0]
		if {$index == {}} {
			return
		}
		editor_goto_line $index
	}

	## Get configuration list for this panel
	 # - Intented for session management
	 # @return void
	public method findinfiles_get_config {} {
		return [list								\
			[subst -nocommands "\$::FindInFiles::recursive_$obj_idx"]	\
			[subst -nocommands "\$::FindInFiles::regular_expr_$obj_idx"]	\
			[subst -nocommands "\$::FindInFiles::case_sensitive_$obj_idx"]	\
			[subst -nocommands "\$::FindInFiles::folder_$obj_idx"]		\
			[subst -nocommands "\$::FindInFiles::mask_$obj_idx"]		\
			[subst -nocommands "\$::FindInFiles::pattern_$obj_idx"]		\
		]
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

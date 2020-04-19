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
if { ! [ info exists _EVENTHANDLERS_TCL ] } {
set _EVENTHANDLERS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements event handlers
# This file should be loaded into class Editor in file "editor.tcl"
# --------------------------------------------------------------------------


## Binding for event <Configure>
 # Commit new width of the editor widget -- for correct line wrapping
 # @return void
public method Configure {} {
	if {$editor_to_use} {return}

	# Check if program is loaded
	if {!${::APPLICATION_LOADED}} {return}

	# Adjust editor height
	set eh_org $editor_height
	adjust_editor_height

	# Determinate width and height of the active area
	set width [winfo width $editor]
	incr width -6
	incr width [expr {-($width % $defaultCharWidth)}]

	# If width changed then adjust line wrapping
	if {$editor_width != $width} {
		set editor_width $width
		set highlighted_lines [string repeat 0 [string bytelength $highlighted_lines]]
		highlight_visible_area
	} elseif {$eh_org != $editor_height} {
		highlight_visible_area
	}
}

## This function handles mouse click in frame which wraps the editor text widget
 # This should happen much often, so this function ensures that everything
 # is still ok.
 # @parm Int x - X coordinate
 # @parm Int y - Y coordinate
 # @return void
public method click_under_editor {x y} {
	Configure

	catch {
		$editor tag remove sel 0.0 end
	}

	# Move insertion cursor
	$editor mark set insert [$editor index @$x,$y+1l]

	# Adjust meters
	rightPanel_adjust [expr {int([$editor index insert])}]
	recalc_status_counter {} 1
	$editor see insert

}

## Handle click on "Line numbers"
 # Add/Remove breakpoint
 # @parm Int x - realative X coordinate
 # @parm Int y - realative Y coordinate
 # @return void
public method lineNumbers_click {x y} {
	Breakpoint [wrap_aux_line2idx [expr {int([$lineNumbers index @$x,$y])}]]
}

## Handle click on "Icon border"
 # Add/Remove bookmarks
 # @parm Int x - realative X coordinate
 # @parm Int y - realative Y coordinate
 # @return void
public method iconBorder_click {x y} {
	Bookmark [wrap_aux_line2idx [expr {int([$iconBorder index @$x,$y])}]]
}

## Do the same as scroll + set up the scollbar
 # @parm Float fraction0	- Freaction where to move
 # @parm Float fraction1	- Freaction where to setup end of visible area for the scrollbar
 # @return void
public method scrollSet {fraction0 fraction1} {
	if {$editor_to_use} {return}

	$scrollbar set $fraction0 $fraction1
	scroll moveto $fraction0
}

public method scroll_0 args {
	if {$editor_to_use} {return}

	if {[lindex $args 0] != {moveto}} {
		eval "$this scroll $args"
		return
	}

	scroll [expr {int([lindex $args 1] * [$editor index end] + 1)}]
}

## Scroll simultaneously Icon border, Lines count and editor widget
 # @parm String		- Scroll command (eg. 'moveto')
 # @parm Float		- Scroll fraction
 # @parm String	= {}	- Units
 # @return void
public method scroll args {
	if {$editor_to_use} {return}

	# This function cannot be caled recursively
	if {$scroll_in_progress} {return}
	set scroll_in_progress 1

	set line 0
	if {[lindex $args 0] == {scroll}} {
		set line [expr {int([$editor index @5,5])}]
		set unit [string index [lindex $args end] 0]

		if {$unit != {p}} {
			incr line [lindex $args 1]
		} else {
			incr line [expr {30 * [lindex $args 1]}]
		}
		incr line -1

		$editor yview $line
		set row $line
		incr row
		set col 0

	} else {
		eval "$editor yview $args"

		set idx [$editor index @5,5]
		scan $idx "%d.%d" row col
		$editor see $idx
	}

	highlight_visible_area	;# Highlight lines which hasn't been highlighted yet
	update idletasks

	set tmp_row $row
	if {$number_of_wraps} {
		set remaining $number_of_wraps
		for {set i 1} {$i < $row} {incr i} {
			set wrap [lindex $map_of_wraped_lines $i]
			if {$wrap < 0} {
				set wrap 0
			}
			incr tmp_row $wrap
			incr remaining -$wrap
			if {!$remaining} {break}
		}
	}
	if {$col != 0} {
		incr tmp_row [get_count_of_lines "$idx linestart" "$idx"]
	}
	incr tmp_row -1

	$iconBorder yview $tmp_row
	$lineNumbers yview $tmp_row

	if {$number_of_wraps} {
		if {$tmp_row != $line} {
			highlight_visible_area	;# Highlight lines which hasn't been highlighted yet
		}
	}

	# Done ...
	update idletasks
	set scroll_in_progress 0
}

## Invoke editor popup menu
 # @parm Int X - absolute X coordinate
 # @parm Int Y - absolute Y coordinate
 # @parm Int x - relative X coordinate
 # @parm Int y - relative Y coordinate
 # @return void
public method popupMenu {X Y x y} {
	if {![winfo exists $menu]} {return}

	if {$frozen} {
		set address [$parentObject simulator_line2address	\
			[expr {int([$editor index @$x,$y])}]		\
			[$parentObject simulator_get_filenumber $fullFileName]	\
		]
		if {$address == {}} {
			set state {disabled}
		} else {
			set state {normal}
		}
		$menu entryconfigure [::mc "LJMP this line"] -state $state
		$menu entryconfigure [::mc "LCALL this line"] -state $state
	} else {
		$menu entryconfigure [::mc "LJMP this line"] -state disabled
		$menu entryconfigure [::mc "LCALL this line"] -state disabled
	}

	tk_popup $menu $X $Y
	$editor mark set insert "@$x,$y"
	recalc_status_counter {} 0
}

## Invoke Icon Border popup menu
 # @parm Int X - absolute X coordinate
 # @parm Int Y - absolute Y coordinate
 # @parm Int x - relative X coordinate
 # @parm Int y - relative Y coordinate
 # @return void
public method iconBorder_popup_menu {X Y x y} {
	if {![winfo exists $IB_menu]} {return}
	set line [expr {int([$iconBorder index @$x,$y])}]
	set line [wrap_aux_line2idx $line]
	set pmenu_cline $line
	set bookmark [lindex $bookmarks $line]
	tk_popup $IB_menu $X $Y
}

## Invoke Line Numbers popup menu
 # @parm Int X - absolute X coordinate
 # @parm Int Y - absolute Y coordinate
 # @parm Int x - relative X coordinate
 # @parm Int y - relative Y coordinate
 # @return void
public method lineNumbers_popup_menu {X Y x y} {
	if {![winfo exists $LN_menu]} {return}
	set line [expr {int([$lineNumbers index @$x,$y])}]
	set line [wrap_aux_line2idx $line]
	set pmenu_cline $line
	set breakpoint [lindex $breakpoints $line]
	tk_popup $LN_menu $X $Y
}

## Invoke statusbar popup menu
 # @parm Widget editor - Editor widget
 # @parm Int X - absolute X coordinate
 # @parm Int Y - absolute Y coordinate
 # @return void
public method statusbar_popup_menu {editor X Y} {
	if {![winfo exists $stat_menu]} {return}

	if {[lindex $statusbar_menu_config 0] != 0} {
		set state normal
	} else {
		set state disabled
	}
	$stat_menu entryconfigure [::mc "Split vertical"] -state $state
	$stat_menu entryconfigure [::mc "Split horizontal"] -state $state

	if {[lindex $statusbar_menu_config 1] != 0} {
		set state normal
	} else {
		set state disabled
	}
	$stat_menu entryconfigure [::mc "Close current view"] -state $state

	if {[lindex $statusbar_menu_config 2] != 0} {
		set state normal
	} else {
		set state disabled
	}
	$stat_menu entryconfigure [::mc "Back"] -state $state

	if {[lindex $statusbar_menu_config 3] != 0} {
		set state normal
	} else {
		set state disabled
	}
	$stat_menu entryconfigure [::mc "Forward"] -state $state
	set ::X::selectedView $this
	focus $editor
	tk_popup $stat_menu $X $Y
}

## Handles pseudo-event: "Selection"
 # @return void
public method editor_selection {} {
	if {$selection_in_progress} {return}
	set selection_in_progress 1

	switch -- $selection_mode {
		0 { ;# Normal selection mode
		}
		1 { ;# Block selection mode
			adjust_selection_to_block
		}
	}

	set selection_in_progress 0
}

## Handles event: "Control-Key-Up"
 # @return void
public method control_down {} {
	$editor yview scroll 1 units
}

## Handles event: "Control-Key-Up"
 # @return void
public method control_up {} {
	$editor yview scroll -1 units
}

## Handles event: "Control-Shift-Key-Up" and "Control-Shift-Key-Down"
 # @parm Bool up__down - 1 == Control-Shift-Key-Up; 0 == Control-Shift-Key-Down
 # @return void
public method control_shift_updown {up__down} {
	if {$up__down} {
		if {int([$editor index insert]) == 1} {
			return
		}
	} else {
		if {(int([$editor index insert]) + 1) == int([$editor index end])} {
			return
		}
	}

	$editor configure -autoseparators 0
	if {$up__down} {
		set target_idx [$editor index {insert-1l}]
		autocompletion_maybe_important_change [$editor index {insert-1l linestart}] [$editor index {insert lineend}]
	} else {
		set target_idx [$editor index {insert+1l}]
		autocompletion_maybe_important_change [$editor index {insert linestart}] [$editor index {insert+1l lineend}]
	}

	catch {
		$editor tag remove sel 1.0 end
	}

	set line0 [$editor get {insert linestart} {insert lineend}]
	if {$up__down} {
		set line1 [$editor get {insert-1l linestart} {insert-1l lineend}]
	} else {
		set line1 [$editor get {insert+1l linestart} {insert+1l lineend}]
	}

	$editor delete {insert linestart} {insert lineend}
	if {$up__down} {
		$editor delete {insert-1l linestart} {insert-1l lineend}
	} else {
		$editor delete {insert+1l linestart} {insert+1l lineend}
	}

	$editor insert insert $line1
	if {$up__down} {
		$editor insert {insert-1l} $line0
	} else {
		$editor insert {insert+1l} $line0
	}

	set idx [expr {int([$editor index insert])}]
	parse $idx
	manage_autocompletion_list $idx
	if {$up__down} {
		set idx [expr {int([$editor index insert-1l])}]
	} else {
		set idx [expr {int([$editor index insert+1l])}]
	}
	parse $idx
	manage_autocompletion_list $idx

	# Check spelling on the other line
	update
	spellcheck_check_all [expr {int([$editor index insert])}] 1

	# Move insertion cursor
	$editor mark set insert $target_idx
	$editor see insert

	$editor edit separator
	$editor configure -autoseparators 1
}

## Handles event: "Shift-Key-Down"
 # @return void
public method shift_down {} {
	# Check spelling on the line which we are noe leaving
	spellcheck_check_all [expr {int([$editor index insert])}]

	tk::TextKeySelect $editor [get_up_down_idx 0]

	# Adjust selection in list of bookmarks and list of breakpoints
	rightPanel_adjust [expr {int([$editor index insert])}]

	# Adjust status bar counters
	recalc_status_counter {}
	$editor see insert
}

## Handles event: "Shift-Key-Up"
 # @return void
public method shift_up {} {
	# Check spelling on the line which we are noe leaving
	spellcheck_check_all [expr {int([$editor index insert])}]

	tk::TextKeySelect $editor [get_up_down_idx 1]

	# Adjust selection in list of bookmarks and list of breakpoints
	rightPanel_adjust [expr {int([$editor index insert])}]

	# Adjust status bar counters
	recalc_status_counter {}
	$editor see insert
}

## Handles event: "Key-Up"
 # @return void
public method up {} {
	# Check spelling on the line which we are now leaving
	spellcheck_check_all [expr {int([$editor index insert])}]

	# Move insertion cursor
	$editor mark set insert [get_up_down_idx 1]

	# Remove selection
	catch {
		$editor tag remove sel 1.0 end
	}

	# Adjust selection in list of bookmarks and list of breakpoints
	rightPanel_adjust [expr {int([$editor index insert])}]

	# Adjust status bar counters
	recalc_status_counter {} 1
	$editor see insert
}

## Handles event: "Key-Down"
 # @return void
public method down {} {
	# Check spelling on the line which we are now leaving
	spellcheck_check_all [expr {int([$editor index insert])}]

	# Focus completion popup window
	if {$completion_win_opened} {
		catch {
			focus -force $completion_listbox
			$completion_listbox selection set [$completion_listbox items 0]
		}
		return
	}

	# Move insertion cursor
	$editor mark set insert [get_up_down_idx 0]

	# Remove selection
	catch {
		$editor tag remove sel 1.0 end
	}

	# Adjust selection in list of bookmarks and list of breakpoints
	rightPanel_adjust [expr {int([$editor index insert])}]

	# Adjust status bar counters
	recalc_status_counter {}
	$editor see insert
}

## Handles event: "Key-Escape"
 # @return void
public method key_escape {} {
	if {$completion_win_opened} {
		catch {
			detete_text_in_editor sel.first sel.last
		}
	}
	catch {
		$editor tag remove sel 1.0 end
	}
}

## Handles event: "Shift-Key-Home"
 # @return void
public method shift_home {} {
	# Selection tag defined
	if {[llength [$editor tag nextrange sel 1.0]]} {
		set sel_f [$editor index sel.first]
		set sel_l [$editor index sel.last]
		set idx0 [$editor index insert]
		$editor tag remove sel 1.0 end
		home_press
		set idx1 [$editor index insert]

		if {[$editor compare $idx0 == $sel_f]} {
			$editor tag add sel $idx1 $sel_l
		} elseif {[$editor compare $idx0 == $sel_l]} {
			$editor tag add sel $sel_f $idx1
		}

	# Nothing selected
	} else {
		set idx [$editor index insert]
		home_press
		catch {
			$editor tag remove sel 1.0 end
		}

		if {[$editor compare $idx < insert]} {
			$editor tag add sel $idx insert
		} else {
			$editor tag add sel insert $idx
		}
	}
}

## Handles event: "Control-Key-Home"
 # @return void
public method control_home {} {
	$editor mark set insert 1.0
	rightPanel_adjust [expr {int([$editor index insert])}]
	resetUpDownIndex
	recalc_status_counter {} 0
	$editor see insert
}

## Handles event: "Control-Key-End"
 # @return void
public method control_end {} {
	$editor mark set insert end
	rightPanel_adjust [expr {int([$editor index insert])}]
	resetUpDownIndex
	recalc_status_counter {} 0
	$editor see insert
}

## Handles event: "Key-Home"
 # @return void
public method home_press {} {
	# Local variables
	set idx [$editor index insert]	;# Insert index
	set row [expr {int($idx)}]	;# Current row
	regexp {\d+$} $idx col_original	;# Current column

	# Determinate start line index (true line start)
	if {[regexp {^\s+} [$editor get $row.0 "$row.0 lineend"] space]} {
		set col [string length $space]
		if {$col_original == $col} {
			$editor mark set insert $row.0
		} else {
			$editor mark set insert $row.$col
		}
	} else {
		$editor mark set insert $row.0
	}

	# Unset selection
	catch {
		$editor tag remove sel 1.0 end
	}

	# Adjust status bar counters
	resetUpDownIndex
	recalc_status_counter {} 0
	$editor see insert
}

## Handles event: "Key-Tab"
 # @return void
public method tab_press {} {
	if {$spaces_no_tabs} {
		set indent_char [string repeat { } $number_of_spaces]
	} else {
		set indent_char "\t"
	}

	# Nothing selected or popup completion window is opened -> insert tab character
	if {$completion_win_opened || [$editor tag ranges sel] == {}} {
		Key $indent_char

	# Something selected -> indent
	} else {
		# convert selection indexes to line numbers
		set start [expr {int([$editor index sel.first])}]
		set end_o [$editor index sel.last]
		set end [expr {int($end_o)}]
		if {$end == $end_o} {incr end -1}
		# perform indent on each line in the block
		for {set line $start} {$line <= $end} {incr line} {
			$editor insert $line.0 $indent_char
			rightPanel_changeLineContent $line
			restore_line_markers $line
		}
		$editor tag add sel $start.0 [expr {$end + 1}].0

		# Recalculate status bar
		recalc_status_counter {} 0

		$editor see insert
	}
}

## Handles event: "Shift-Key-Return", "Shift-Key-KP_Enter"
 # Smart new line
 # @return void
public method shift_enter {} {
	if {$critical_edit_proc} {return}
	set critical_edit_proc 1

	# Check spelling on the line which we are noe leaving
	spellcheck_check_all [expr {int([$editor index insert])}]

	deleteselection
	$editor insert insert "\n"

	set line [$editor get [list insert-1l linestart] [list insert-1l lineend]]
	if {![regexp {^\s*[^\w]+} $line line]} {
		set critical_edit_proc 0
		return
	}
	$editor insert insert $line

	# Recalcutlate Left frame, status bar and right panel
	$editor see insert
	update
	recalc_left_frame
	recalc_status_counter {}
	rightPanel_adjust [expr {int([$editor index insert])}]
	set critical_edit_proc 0

	# Reevaluate highlight on the next line if C language is used
	if {$prog_language == 1} {
		c_syntax_highlight [expr {int([$editor index insert])+1}]
	}
}

## Handles event: "Key-Return", "Key-KP_Enter"
 # @return void
public method enter {} {
	if {$critical_edit_proc} {return}
	set critical_edit_proc 1

	$editor configure -autoseparators 0

	set idx [$editor index insert]	;# Determinate insert index
	$editor insert $idx "\n"	;# Insert EOL
	resetUpDownIndex		;# Column changed

	set idx [expr {int($idx)}]
	incr idx

	# Check spelling on the line which we are noe leaving
	spellcheck_check_all $idx

	# Keep indention of the previous line
	if {$intentation_mode == {normal}} {

		# Determinate indetication characters
		set prev_line [$editor get \
			[$editor index {insert-1l linestart}]	\
			[$editor index {insert-1l lineend}]	\
		]
		if {[string length $prev_line]} {
			set indent_chars {}
			regexp {^\s+} $prev_line indent_chars

			# Insert indentication characers from the previous line
			if {$indent_chars != {}} {
				$editor insert $idx.0 $indent_chars
			}

			if {$prev_line == $indent_chars} {
				$editor delete {insert-1l linestart} {insert-1l lineend}
			}
		}
	}

	# Remove selected text
	deleteselection

	# Recalcutlate Left frame, status bar and right panel
	$editor see $idx.0
	update
	recalc_left_frame
	recalc_status_counter {}
	rightPanel_adjust $idx
	set critical_edit_proc 0

	# Reevaluate highlight on the next line if C language is used
	if {$prog_language == 1} {
		incr idx
		c_syntax_highlight $idx
	}

	$editor edit separator
	$editor configure -autoseparators 1
}

## Handles event: 'Menu'
 # @return void
public method Key_Menu {} {
	# Close autocompletion popup window
	if {$completion_win_opened} {
		close_completion_popup_window
	}

	# Invoke popup menu
	$editor see insert
	set bbox [$editor bbox [$editor index insert]]
	tk_popup $menu	\
		[expr {[winfo rootx $editor] + [lindex $bbox 0] + 10}]	\
		[expr {[winfo rooty $editor] + [lindex $bbox 1] + 10}]
}

## Handles event: 'KeyRelease'
 # @parm String key - Key name
 # @return void
public method KeyRelease {key} {
	if {[lsearch {ISO_Next_Group ISO_Prev_Group Alt_R Alt_L Control Meta Shift_L Shift_R} $key] == -1} {
		if {$do_not_hide_comp_win} {
			set do_not_hide_comp_win 0
		} else {
			close_completion_popup_window
		}
	}
}

## Handles event: 'Key'
 # @return void
public method Key {key {key_k {}}} {
	# Skip values with no meaning for us herw
	if {![string is print -strict $key] && $key != "\t"} {
		return
	}

	if {$key_handler_in_progress} {
		if {[llength $key_handler_buffer] < 4} {
			lappend key_handler_buffer $key
		}
		return
	}
	set key_handler_in_progress 1
	set scroll_in_progress 1	;# Block scrolling

	spellcheck_change_detected_pre
	autocompletion_maybe_important_change insert insert
	$editor configure -autoseparators 0

	if {
		$auto_brackets &&
		($key == {'} || $key == "\"" || $key == {(} || $key == "\[" || $key == "\{")
	} then {
		# Enclose selected text by the selected charactere
		if {[llength [$editor tag nextrange sel 1.0]]} {
			$editor insert sel.first $key
			switch -- $key {
				{(} {$editor insert sel.last {)}}
				{[} {$editor insert sel.last {]}}
				"\{" {$editor insert sel.last "\}"}
				default {
					$editor insert sel.last $key
				}
			}
			$editor mark set insert sel.last
			$editor tag remove sel 1.0 end

		# Insert the selected character twice
		} else {
			set next_char [$editor get insert insert+1c]
			$editor insert insert $key
			switch -- $key {
				{(} {$editor insert insert {)}}
				{[} {$editor insert insert {]}}
				"\{" {$editor insert insert "\}"}
				{'} {
					if {$next_char != {'}} {
						$editor insert insert {'}
					}
				}
				"\"" {
					if {$next_char != "\""} {
						$editor insert insert "\""
					}
				}
				default {
					$editor insert insert $key
				}
			}
			$editor mark set insert {insert - 1c}
		}

	} else {
		# Delete selected text
		deleteselection

		# Mode overwrite
		if {!$ins_ovr_mode} {
			if {[$editor compare insert != {insert lineend}]} {
				detete_text_in_editor insert insert+1c
			}
		}

		# Insert the given character
		$editor insert insert $key
	}
	# Restore highlight on the current line
	parse [expr {int([$editor index insert])}]
	set scroll_in_progress 1	;# Block scrolling
	recalc_left_frame
	set scroll_in_progress 1	;# Block scrolling

	# Invoke popup completion menu
	if {$auto_completion} {
		aux_Key_autocompletion_0			\
			[$editor index {insert-1c wordstart}]	\
			[$editor index {insert-1c wordend}]
	}

	$editor edit separator
	$editor configure -autoseparators 1

	if {[llength $key_handler_buffer]} {
		set key [lindex $key_handler_buffer 0]
		set key_handler_buffer [lreplace $key_handler_buffer 0 0]
		update
		set scroll_in_progress 0		;# Unblock scrolling
		set key_handler_in_progress 0
		Key $key
	}
	set key_handler_in_progress 0
	update
	set scroll_in_progress 0		;# Unblock scrolling
	spellcheck_change_detected_post
}

## Handles event: 'Key-Delete'
 # @return void
public method key_delete {} {
	if {![$this deleteselection 1]} {
		if {[$editor compare {insert linestart} != {insert+1c linestart}]} {
			set remove_trailing_space 1
		} else {
			set remove_trailing_space 0
		}

		$this detete_text_in_editor insert insert+1c

		if {$remove_trailing_space && [regexp {\s+$} [$editor get {insert linestart} {insert lineend}] space]} {
			set line_end [$editor index {insert lineend}]
			$editor delete $line_end-[string length $space]c {insert lineend}
		}
	}

	$this resetUpDownIndex
	$this recalc_left_frame
	$this parse [expr {int([$editor index insert])}]
	update
}

## Handles event: 'Key-Backspace'
 # @return void
public method key_backspace {} {
	if {$auto_brackets} {
		set char0 [$editor get insert-1c insert]
		set char1 [$editor get insert insert+1c]
		if {
			($char0 == "\{" && $char1 == "\}") ||
			($char0 == {(} && $char1 == {)}) ||
			($char0 == {[} && $char1 == {]})
		} then {
			$this detete_text_in_editor insert insert+1c
		} elseif {$char0 == $char1 && ($char0 == "\"" || $char1 == {'})} {
			$this detete_text_in_editor insert insert+1c
		}
	}
	if {![$this deleteselection]} {
		$this detete_text_in_editor insert-1c insert
	}
	$this resetUpDownIndex
	$this recalc_left_frame
	$this parse [expr {int([$editor index insert])}]
	update
}

# >>> File inclusion guard
}
# <<< File inclusion guard

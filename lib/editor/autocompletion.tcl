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
if { ! [ info exists _AUTOCOMPLETION_TCL ] } {
set _AUTOCOMPLETION_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements autocompletion related procedures
# This file should be loaded into class Editor in file "editor.tcl"
# --------------------------------------------------------------------------

public common invoke_com_win_in_p		0	;# Bool: invoke_completion_popup_window in progress
public common completion_win_opened		0	;# Bool: Editor popup-based completion window opended

## Array: Strings available for autocompletion
	# Index 0 - Labels in assembly
	# Index 1 - Constants/variables
	# Index 2 - C variables
	# Index 3 - Macros
	# Index 4 - SFR's
	# Index 5 - Expression symbols
	# Index 6 - Doxygen tags
	# Index 7 - C Functions
private variable autocompletion_list
private variable completion_win_str_i	1.0	;# TextIndex: String to complete - start index
private variable completion_win_end_i	1.0	;# TextIndex: String to complete - end index
private variable completion_win_mode	0	;# Int: Completion window mode
private variable comp_win_loading_in_p	0	;# Bool: Completion window list loading is in progress
private variable comp_win_loading_max	1	;# Int: Maximum for progressbar in the completion window
private variable macl_invocations	0	;# Int: Number of invocations of "manage_autocompletion_list"
private variable doxytag_fg		{#000000}	;# Color: Highlight color for doxygen tag
private variable indirect_fg		{#000000}	;# Color: Highlight color for indirect address
private variable symbol_fg		{#000000}	;# Color: Highlight color for asm. symbol
private variable sfr_fg			{#000000}	;# Color: Highlight color for SFR
private variable label_fg		{#000000}	;# Color: Highlight color for asm. label
private variable macro_fg		{#000000}	;# Color: Highlight color for asm. macro
private variable const_fg		{#000000}	;# Color: Highlight color for asm. const
private variable dir_fg			{#000000}	;# Color: Highlight color for asm. directive
private variable cs_fg			{#000000}	;# Color: Highlight color for constrol sequence
private variable ins_fg			{#000000}	;# Color: Highlight color for instruction
private variable doxytag_font		${::Editor::defaultFont}	;# Font: Font for doxygen tag
private variable indirect_font		${::Editor::defaultFont}	;# Font: Font for indirect address
private variable symbol_font		${::Editor::defaultFont}	;# Font: Font for asm. symbol
private variable sfr_font		${::Editor::defaultFont}	;# Font: Font for SFR
private variable label_font		${::Editor::defaultFont}	;# Font: Font for asm. label
private variable macro_font		${::Editor::defaultFont}	;# Font: Font for asm. macro
private variable const_font		${::Editor::defaultFont}	;# Font: Font for asm. const
private variable dir_font		${::Editor::defaultFont}	;# Font: Font for asm. directive
private variable cs_font		${::Editor::defaultFont}	;# Font: Font for constrol sequence
private variable ins_font		${::Editor::defaultFont}	;# Font: Font for instruction


## Refresh list of available SFR's and SFB's on the target uC
 # @return void
public method refresh_available_SFR {} {
	set autocompletion_list(4) [lsort -ascii [$parentObject cget -available_SFR]]
}

## Clear list of words for autocompletion window
 # @return void
public method clear_autocompletion_list {} {
	foreach i {0 1 2 3 7} {
		set autocompletion_list($i) {}
	}
	$parentObject rightPanel_clear_symbol_list
}

## Delete some string in the editor
 # It's important to delete strings in this way in order to keep
 #+ autocompletion list up to date
 # @parm TextIndex start_index	- Start
 # @parm TextIndex end_index	- End
 # @parm Bool do_spellcheck	- Perform spell check
 # @return void
public method detete_text_in_editor {start_index end_index {do_spellcheck 1}} {
	autocompletion_maybe_important_change $start_index $end_index
	if {$do_spellcheck} {
		spellcheck_change_detected_pre
	}
	$editor delete $start_index $end_index
	if {$do_spellcheck} {
		spellcheck_change_detected_post
	}
}

## Inform autocompletion mechanism about possibly deleted symbol
 # @parm TextIndex start_index	- Beginning on area to to analyze
 # @parm TextIndex end_index	- End on area to to analyze
 # @return void
public method autocompletion_maybe_important_change {start_index end_index} {
	set start_index [$editor index $start_index]
	set end_index [$editor index $end_index]

	# Detect new symvol
	foreach tag_name {tag_label tag_constant_def c_lang_var tag_macro_def c_lang_func} \
		index {0 1 2 3 7} \
	{
		set linestart_tmp [list $start_index linestart]
		while {1} {
			# Detect ...
			set range [$editor tag nextrange $tag_name		\
				$linestart_tmp [list $end_index lineend]	\
			]
			set linestart_tmp [lindex $range 1]

			# Nothing detected ...
			if {![llength $range]} {
				break
			}

			# Get symbol name
			set string [$editor get [lindex $range 0] [lindex $range 1]]

			# Adjust case (all to uppercase except C lang. symbols)
			if {$index != 2 && $index != 7} {
				set string [string toupper $string]
			}

			# Remove semicolon from labels in assembly
			if {!$index} {
				set string [string replace $string end end]
			}

			# Adjust autocompletion list
			set idx [lsearch -ascii -exact $autocompletion_list($index) $string]
			if {$idx != -1} {
				$parentObject rightPanel_adjust_symbol_list	\
					all $string $index 0 $this

				set autocompletion_list($index)	\
					[lreplace $autocompletion_list($index) $idx $idx]
			}
		}
	}
}

## Significant part of autocompletion mechanism related to C language
 # Creates tags "c_lang_var" and "c_lang_func" to mark C symbols
 # @parm Int line_number - Line number
 # @return void
private method autocompletion_c_syntax_analyze {line_number} {
	# Find word after data type specification
	set prev_range {}
	set range [list $line_number.0 $line_number.0]
	set line [$editor get $line_number.0 [list $line_number.0 lineend]]

	set par_idx [string first "(" $line]

	while {1} {
		set range [$editor tag nextrange tag_c_data_type	\
			[lindex $range 1] [list $line_number.0 lineend]	\
		]

		if {![llength $range] || ( ( $par_idx != -1 ) && ([lindex [split [lindex $range 0] {.}] 1] > $par_idx) )} {
			break
		}
		set prev_range $range
	}
	set range $prev_range


	# Nothing found -> abort
	if {![llength $range]} {
		return
	}

	set start [lindex [split [lindex $range 1] {.}] 1]
	if {![regexp -start $start -- {\w+} $line string]} {
		return
	}
	set start [string first $string $line $start]
	set end [expr {$start + [string length $string]}]

	# Mark the word
	if {[regexp -start $end -- {\s*\(} $line]} {
		$editor tag add c_lang_func $line_number.$start $line_number.$end
	} else {
		# Skip type conversions
		if {![regexp {[\(\)]} [$editor get [lindex $range 1] $line_number.$start]]} {
			$editor tag add c_lang_var $line_number.$start $line_number.$end
		}
	}
}

## Inform autocompletion mechanism about possibly newly defined symbol
 # @parm Int line_number	- Line number
 # @return void
public method manage_autocompletion_list {line_number} {
	# Detect new symbol
	foreach tag_name {tag_label tag_constant_def c_lang_var tag_macro_def c_lang_func} \
		index {0 1 2 3 7} \
	{
		set linestart_tmp $line_number.0
		while {1} {
			# Detect ...
			set range [$editor tag nextrange $tag_name		\
				$linestart_tmp [list $line_number.0 lineend]	\
			]
			set linestart_tmp [lindex $range 1]

			# Nothing detected ...
			if {![llength $range]} {
				break
			}

			# Get symbol name
			set string [$editor get [lindex $range 0] [lindex $range 1]]

			# Check if it not already defined
			if {$index != 2 && $index != 7} {
				set string [string toupper $string]
			} else {
				if {
					[lsearch -ascii -exact ${::CsyntaxHighlight::data_types} $string] != -1
						||
					[lsearch -ascii -exact ${::CsyntaxHighlight::keywords} $string] != -1
				} then {
					continue
				}
			}

			# Remove semicolon from labels in assembly
			if {!$index} {
				set string [string replace $string end end]
			}

			# Append to the autocompletion list
			if {[lsearch -ascii -exact $autocompletion_list($index) $string] == -1} {
				lappend autocompletion_list($index) $string
				$parentObject rightPanel_adjust_symbol_list	\
					$line_number $string $index 1 $this
				$parentObject rightPanel_sm_select $line_number
			}
		}
	}

	# Sort autocompletion list every 20nd iteration
	incr macl_invocations
	if {$macl_invocations > 20} {
		set macl_invocations 0
		foreach i {0 1 2 3 7} {
			set autocompletion_list($i) [lsort -ascii $autocompletion_list($i)]
		}
	}
}

## Invoke popup menu completon window
 # @parm Bool mode	- Mode of autocompletion
 #	0 - Instructions, directives and macro's
 #	1 - Constants and labels
 #	2 - C functions
 #	3 - Indirect values
 #	4 - Doxygen tags
 # @parm String str	- Incomplete instruction or directive
 # @parm Int x		- Relative X position of the popup window (relative to editor)
 # @parm Int y		- Relative Y position of the popup window (relative to editor)
 # @return void
private method invoke_completion_popup_window {mode start_idx end_idx} {
	if {$invoke_com_win_in_p} {
		update
		return
	}
	set invoke_com_win_in_p 1

	set bbox [$editor bbox $start_idx]
	if {![llength $bbox]} {
		set invoke_com_win_in_p 0
		return
	}
	set x [lindex $bbox 0]
	set y [expr {[lindex $bbox 1] + [lindex $bbox 3]}]
	set str [$editor get $start_idx $end_idx]

	if {![string length $str]} {
		close_completion_popup_window
		set invoke_com_win_in_p 0
		return
	}

	set loading 0
	if {!$comp_win_loading_in_p && [string first 0 $highlighted_lines 1] > 0} {
		set loading 1
		set ::X::compilation_progress 0
		set comp_win_loading_max [highlight_all_count_of_iterations]
	}

	# Close current window if any
	close_completion_popup_window

	# Adjust arguments
	set str_org $str

	# Set opened flag
	set completion_win_opened 1
	set do_not_hide_comp_win 1

	set completion_win_str_i $start_idx
	set completion_win_end_i $end_idx
	set completion_win_mode $mode

	# Create window
	if {![winfo exists .completion_win]} {
		set win [frame .completion_win -background {#000000}]
		bind $win <Button-1> "catch {$this completion_popup_window_but1 %X %Y}"
		bind $win <FocusOut> "catch {$this close_completion_popup_window}"
		bind $win <Destroy> "
			catch {$this detete_text_in_editor sel.first sel.last}
			$this parse \[expr {int(\[$editor index insert\])}\]"
		bind $win <Key-Escape> "
			catch {$this detete_text_in_editor sel.first sel.last}
			catch {$this close_completion_popup_window}"

		# Create lisbox and scrollbar
		set frame [frame $win.frame]
		set listbox [ListBox $frame.listbox		\
			-relief flat -bd 0 -selectfill 0	\
			-selectbackground {#AAAAFF}		\
			-bg white -cursor left_ptr		\
			-yscrollcommand "$frame.scrollbar set"	\
			-selectmode single -width 0 -height 0	\
			-highlightthickness 0 -padx 2		\
			-font $defaultFont_bold			\
		]
		set completion_listbox $listbox
		pack $listbox -side left -fill both -expand 1
		pack [ttk::scrollbar $frame.scrollbar	\
			-orient vertical		\
			-command "$listbox yview"	\
		] -side right -after $listbox -fill y

		ProgressBar .completion_win.progress_bar 	\
			-troughcolor #DDDDDD			\
			-type normal -height 4 -bd 0		\
			-variable {::X::compilation_progress}	\

		pack $frame -padx 1 -pady 1 -fill both -expand 1

		$listbox bindText <Button-1>	"catch {$this completion_accept}"
		$listbox bindText <Escape>	"catch {$this close_completion_popup_window}"
		bind $listbox <Key-Return>	"catch {$this completion_accept \[$listbox selection get\]}"
		bind $listbox <KP_Enter>	"catch {$this completion_accept \[$listbox selection get\]}"
		bind $listbox <Escape>		"catch {$this close_completion_popup_window}"
		if {[winfo exists $listbox.c]} {
			bind $listbox.c <Button-5>	{%W yview scroll +1 units; break}
			bind $listbox.c <Button-4>	{%W yview scroll -1 units; break}
		}
	}
	set listbox ".completion_win.frame.listbox"
	$listbox selection clear
	$listbox delete [$listbox items]
	update idletasks

	if {$loading || $comp_win_loading_in_p} {
		if {!($comp_win_loading_max > 1)} {
			set comp_win_loading_max 1
		}
		.completion_win.progress_bar configure -maximum $comp_win_loading_max
		catch {
			pack .completion_win.progress_bar -fill x -pady 0
		}
	}

	# Fill up listbox
	set end [string length $str]
	incr end -1

	set last_inserted {}
	set string_width 0
	set required_width 70
	if {$mode != 2 && $mode != 4} {
		set str [string toupper $str]
	}
	if {$mode == 3} {
		foreach command {@R0 @R1 @DPTR @A+DPTR @A+PC} {
			set shortcmd [string range $command 0 $end]
			if {$shortcmd == $str} {
				set last_inserted $command
				$listbox insert end #auto	\
					-text $command		\
					-fg $indirect_fg	\
					-font $indirect_font

				set string_width [font measure $defaultFont_bold $command]
				if {$required_width < $string_width} {
					set required_width $string_width
				}
			}
		}
	} else {
		for {set i 0} {$i < 8} {incr i} {
			switch -- $i {
				0 {
					if {$mode != 1} {
						continue
					}
					set color $label_fg
					set font $label_font
				}
				1 {
					if {$mode != 1} {
						continue
					}
					set color $const_fg
					set font $const_font
				}
				2 {
					if {$mode != 2 || $prog_language != 1} {
						continue
					}
					set color {black}
					set font $defaultFont
				}
				3 {
					if {$mode != 0} {
						continue
					}
					set color $macro_fg
					set font $macro_font
				}
				4 {
					if {$mode != 1} {
						continue
					}
					set color $sfr_fg
					set font $sfr_font
				}
				5 {
					if {$mode != 1} {
						continue
					}
					set color $symbol_fg
					set font $symbol_font
				}
				6 {
					if {$mode != 4} {
						continue
					}
					set color $doxytag_fg
					set font $doxytag_font
				}
				7 {
					if {$mode != 2 || $prog_language != 1} {
						continue
					}
					set color {#0000DD}
					set font $defaultFont
				}
			}
			foreach command $autocompletion_list($i) {
				set shortcmd [string range $command 0 $end]
				if {$shortcmd == $str} {
					set last_inserted $command
					$listbox insert end #auto	\
						-text $command		\
						-fg $color		\
						-font $font

					set string_width [font measure $defaultFont_bold $command]
					if {$required_width < $string_width} {
						set required_width $string_width
					}
				}
			}
		}
	}
	if {$mode == 0} {
		# Instructions and directives
		if {[string index $str 0] != {$}} {
			foreach command ${::ASMsyntaxHighlight::instructions} {
				set shortcmd [string range $command 0 $end]
				if {$shortcmd == $str} {
					set last_inserted $command
					$listbox insert end #auto	\
						-text $command		\
						-fg $ins_fg		\
						-font $ins_font
				}
			}
			foreach command ${::ASMsyntaxHighlight::all_directives} {
				set shortcmd [string range $command 0 $end]
				if {$shortcmd == $str} {
					set last_inserted $command
					$listbox insert end #auto	\
						-text $command		\
						-fg $dir_fg		\
						-font $dir_font
				}
			}

		# Control sequences
		} else {
			foreach command ${::ASMsyntaxHighlight::all_controls__with_dolar} {
				set shortcmd [string range $command 0 $end]
				if {$shortcmd == $str} {
					set last_inserted $command
					$listbox insert end #auto	\
						-text $command		\
						-fg $cs_fg		\
						-font $cs_font
				}
			}
		}
	}

	set num_of_items [llength [$listbox items]]

	# If the listbox is empty -> delete window
	set do_not_show 0
	if {!$num_of_items} {
		set do_not_show 1

	} elseif {$num_of_items == 1 && $last_inserted == $str} {
		set do_not_show 1

	# Automaticaly complete the incomplete command
	} else {
		set command	[$listbox itemcget [$listbox item 0] -text]
		set insert	[$editor index insert]
		set cmd_len	[string length $command]
		set str_len	[string length $str]

		if {$mode != 2 && ![string is upper [regsub -all {[_\d@]} $str_org {}]]} {
			set command [string tolower $command]
		}

		$editor configure -autoseparators 0
		catch {$editor tag remove sel 1.0 end}
		$editor insert insert [string range $command $str_len end]
		$editor mark set insert $insert
		$editor tag add sel insert insert+[expr {$cmd_len - $str_len}]c
		$editor edit separator
		$editor configure -autoseparators 1
		parse [expr {int([$editor index insert])}]
	}

	# Do not display the window
	if {$do_not_show} {
		set invoke_com_win_in_p 0
		close_completion_popup_window

	# Display the window
	} else {
		place .completion_win -width [expr {$required_width + 30}]	\
			-height 105 -anchor nw -x $x -y $y -in $editor
		raise .completion_win
		update
		catch {
			grab -global .completion_win
		}
	}
	set invoke_com_win_in_p 0

	# Highlight all in background to gain autocompletion list
	if {$loading && !$comp_win_loading_in_p} {
		comp_win_highlight_all_in_background
	}
}

## Auxiliary method for "comp_win_highlight_all_in_background"
 #+ (Highlight all in background), part of autocompletion mechanism
 # @return void
public method comp_win_highlight_all_in_background_AUX {} {
	if {!$comp_win_loading_in_p} {
		set comp_win_loading_in_p 1
		highlight_all
		set comp_win_loading_in_p 0
		catch {
			pack forget .completion_win.progress_bar
		}
	}
}

## Highlight all in background
 # @return void
public method comp_win_highlight_all_in_background {} {
	after idle "catch {$this comp_win_highlight_all_in_background_AUX}"
}

## Informs editor about that than autocompletion has been turned on
 # @return void
public method autocompletion_turned_on {} {
	set highlighted_lines [string repeat 0 [string bytelength $highlighted_lines]]
}

## Completion -- accept selection
 # @parm Sring item - Listbox item
 # @return void
public method completion_accept {item} {
	if {$item == {}} {
		return
	}

	if {[llength [$editor tag nextrange sel 1.0]]} {
		$editor delete sel.first sel.last
	}

	set item [$completion_listbox itemcget $item -text]
	set text_org [$editor get $completion_win_str_i $completion_win_end_i]

	if {$completion_win_mode != 2 && ![string is upper [regsub -all {[_\d@]} $text_org {}]]} {
		set item [string tolower $item]
	}
	$editor delete $completion_win_str_i $completion_win_end_i
	$editor insert $completion_win_str_i $item

	set line [expr {int([$editor index insert])}]
	recalc_status_counter {} 0
	parse $line

	close_completion_popup_window
}

## Close completion popup window if user clicked out of it
 # @parm Int X - absolute horizontal position of mouse pointer
 # @parm Int Y - absolute vertical position of mouse pointer
 # @retrun void
public method completion_popup_window_but1 {X Y} {
	set min_x [winfo rootx .completion_win]
	set min_y [winfo rooty .completion_win]
	set max_x [expr {$min_x + [winfo width .completion_win]}]
	set max_y [expr {$min_y + [winfo height .completion_win]}]

	if {$X > $max_x || $X < $min_x || $Y > $max_y || $Y < $min_y} {
		close_completion_popup_window
	}
}

## Unconditionaly safely close completion popup window
 # @return void
public method close_completion_popup_window {} {
	if {$invoke_com_win_in_p} {return}
	set invoke_com_win_in_p 1

	if {$completion_win_opened} {
		catch {$editor delete sel.first sel.last}
		grab release .completion_win
		place forget .completion_win
		focus -force $editor
		parse [expr {int([$editor index insert])}]
	}

	set completion_win_opened 0
	set invoke_com_win_in_p 0
}

## Unconditionaly safely close completion popup window regardless
 #+ state of this object
 # @return void
proc close_completion_popup_window_NOW {} {
	if {${::Editor::invoke_com_win_in_p}} {return}
	set ::Editor::invoke_com_win_in_p 1

	if {${::Editor::completion_win_opened}} {
		catch {
			grab release .completion_win
		}
		catch {
			place forget .completion_win
		}
	}

	set ::Editor::completion_win_opened 0
	set ::Editor::invoke_com_win_in_p 0
}

## Auxiliary method for method "Key"
 # Invokes autocompletion menu
 # @parm TextIndex wordstart	- Index of {insert-1c wordstart}
 # @parm TextIndex wordstart	- Index of {insert-1c wordend}
 # @return void
private method aux_Key_autocompletion_0 {wordstart wordend} {
	# Get range of tag MACRO (possibly incomplete instruction) on the curent line
	set mc_range [$editor tag nextrange tag_macro $wordstart $wordend]
	if {![llength $mc_range]} {
		set mc_range [$editor tag nextrange tag_directive $wordstart $wordend]
	}
	if {![llength $mc_range]} {
		set mc_range [$editor tag nextrange tag_instruction $wordstart $wordend]
	}
	if {![llength $mc_range]} {
		set mc_range [$editor tag nextrange tag_control $wordstart $wordend]
	}

	# Open completion window
	if {[llength $mc_range] && [$editor compare insert == [lindex $mc_range 1]]} {
		invoke_completion_popup_window 0	\
			[lindex $mc_range 0] [lindex $mc_range 1]

	# Try comething else ...
	} else {
		aux_Key_autocompletion_1 $wordstart $wordend
	}
}

## Auxiliary method for method "aux_Key_autocompletion_0"
 # Invokes autocompletion menu
 # @parm TextIndex wordstart	- Index of {insert-1c wordstart}
 # @parm TextIndex wordstart	- Index of {insert-1c wordend}
 # @return void
private method aux_Key_autocompletion_1 {wordstart wordend} {
	# Get range of tag CONSTANT or SFR on the curent line
	set mc_range [$editor tag nextrange tag_constant $wordstart $wordend]
	if {![llength $mc_range]} {
		set mc_range [$editor tag nextrange tag_sfr $wordstart $wordend]
	}

	# Open completion window
	if {[llength $mc_range] && [$editor compare insert == [lindex $mc_range 1]]} {
		invoke_completion_popup_window 1		\
			[lindex $mc_range 0] [lindex $mc_range 1]

	# Try comething else ...
	} else {
		aux_Key_autocompletion_2 $wordstart $wordend
	}
}

## Auxiliary method for method "aux_Key_autocompletion_1"
 # Invokes autocompletion menu
 # @parm TextIndex wordstart	- Index of {insert-1c wordstart}
 # @parm TextIndex wordstart	- Index of {insert-1c wordend}
 # @return void
private method aux_Key_autocompletion_2 {wordstart wordend} {
	# Get range of tag indirect on the curent line
	set mc_range [$editor tag nextrange tag_indirect $wordstart-1c $wordend]

	# Open completion window
	if {[llength $mc_range] && [$editor compare insert == [lindex $mc_range 1]]} {
		invoke_completion_popup_window 3		\
			[lindex $mc_range 0] [lindex $mc_range 1]

	# Try comething else ...
	} else {
		aux_Key_autocompletion_3 $wordstart $wordend
	}
}

## Auxiliary method for method "aux_Key_autocompletion_2"
 # Invokes autocompletion menu
 # @parm TextIndex wordstart	- Index of {insert-1c wordstart}
 # @parm TextIndex wordstart	- Index of {insert-1c wordend}
 # @return void
private method aux_Key_autocompletion_3 {wordstart wordend} {
	# Get range of tag IMMEDIATE CONSTANT on the curent line
	set mc_range [$editor tag nextrange tag_imm_constant $wordstart-1c $wordend]

	# Open completion window
	if {[llength $mc_range] && [$editor compare insert == [lindex $mc_range 1]]} {
		invoke_completion_popup_window 1				\
			[$editor index [list [lindex $mc_range 0] + 1c]]	\
			[lindex $mc_range 1]

	# Try comething else ...
	} else {
		aux_Key_autocompletion_4 $wordstart $wordend
	}
}

## Auxiliary method for method "aux_Key_autocompletion_3"
 # Invokes autocompletion menu
 # @parm TextIndex wordstart	- Index of {insert-1c wordstart}
 # @parm TextIndex wordstart	- Index of {insert-1c wordend}
 # @return void
private method aux_Key_autocompletion_4 {wordstart wordend} {
	# Get range of tag DOXYGEN TAG on the curent line
	set mc_range [$editor tag nextrange tag_c_dox_tag $wordstart-1c $wordend]

	# Open completion window
	if {
		$prog_language == 1
			&&
		[llength $mc_range]
			&&
		[$editor compare insert == [lindex $mc_range 1]]
	} then {
		invoke_completion_popup_window 4	\
			[lindex $mc_range 0] [lindex $mc_range 1]

	# Try comething else ...
	} else {
		aux_Key_autocompletion_5 $wordstart $wordend
	}
}

## Auxiliary method for method "aux_Key_autocompletion_4"
 # Invokes autocompletion menu
 # @parm TextIndex wordstart	- Index of {insert-1c wordstart}
 # @parm TextIndex wordstart	- Index of {insert-1c wordend}
 # @return void
private method aux_Key_autocompletion_5 {wordstart wordend} {
	# Find word with no tags
	if {
		$prog_language == 1
			&&
		[$editor compare insert == $wordend]
	} then {
		set tags [$editor tag names insert-1c]

		# Remove unimportant tags
		if {[llength $tags]} {
			foreach lm [concat $line_markers {tag_current_line}] {
				set idx [lsearch -ascii -exact $tags $lm]
				if {$idx != -1} {
					set tags [lreplace $tags $idx $idx]
				}
			}
		}

		# Open auto-completion window
		if {[llength $tags]} {
			invoke_completion_popup_window 2 $wordstart $wordend
		}

	# Close completion window
	} else {
		close_completion_popup_window
	}
}

## Determinate color for instructions, directives, etc.
 # @return void
private method refresh_highlighting_for_autocompletion {} {
	foreach key ${::ASMsyntaxHighlight::highlight_tags} {
		if {[lindex $key 0] == {tag_instruction}} {
			set ins_fg [lindex $key 1]
			set ins_font [$editor tag cget tag_instruction -font]

		} elseif {[lindex $key 0] == {tag_directive}} {
			set dir_fg [lindex $key 1]
			set dir_font [$editor tag cget tag_directive -font]

		} elseif {[lindex $key 0] == {tag_constant}} {
			set const_fg [lindex $key 1]
			set const_font [$editor tag cget tag_constant -font]

		} elseif {[lindex $key 0] == {tag_macro}} {
			set macro_fg [lindex $key 1]
			set macro_font [$editor tag cget tag_macro -font]

		} elseif {[lindex $key 0] == {tag_label}} {
			set label_fg [lindex $key 1]
			set label_font [$editor tag cget tag_label -font]

		} elseif {[lindex $key 0] == {tag_sfr}} {
			set sfr_fg [lindex $key 1]
			set sfr_font [$editor tag cget tag_sfr -font]

		} elseif {[lindex $key 0] == {tag_symbol}} {
			set symbol_fg [lindex $key 1]
			set symbol_font [$editor tag cget tag_symbol -font]

		} elseif {[lindex $key 0] == {tag_indirect}} {
			set indirect_fg [lindex $key 1]
			set indirect_font [$editor tag cget tag_indirect -font]

		} elseif {[lindex $key 0] == {tag_control}} {
			set cs_fg [lindex $key 1]
			set cs_font [$editor tag cget tag_control -font]
		}
	}

	if {$prog_language == 1} {
		foreach key ${::CsyntaxHighlight::highlight_tags} {
			if {[lindex $key 0] == {tag_c_dox_tag}} {
				set doxytag_fg [lindex $key 1]
				set doxytag_font [$editor tag cget tag_c_dox_tag -font]
			}
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

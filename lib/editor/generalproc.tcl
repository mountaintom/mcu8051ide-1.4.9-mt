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
if { ! [ info exists _GENERALPROC_TCL ] } {
set _GENERALPROC_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements general purpose procedures
# This file should be loaded into class Editor in file "editor.tcl"
# --------------------------------------------------------------------------


## Insure than simulator cursor is in visible area
 # @return void
public method see_sim_cursor {} {
	if {[llength [$editor tag nextrange tag_simulator_curr 1.0 end]]} {
		$editor see tag_simulator_curr.first
	}
}

## Switch betweeen selection modes (Normal / Block)
 # @return void
public method switch_sel_mode {} {
	set selection_mode [expr {!$selection_mode}]
	if {$selection_mode} {
		adjust_selection_to_block
		$sel_mode_lbl configure -text [mc "BLK"] -fg #0088CC
	} else {
		if {[llength [$editor tag nextrange sel 1.0]]} {
			$editor tag add sel sel.first sel.last
		}
		$sel_mode_lbl configure -text [mc "NORM"] -fg #000000
	}
}

## Switch between modes "Insert" and "Overwrite"
 # @return void
public method switch_ins_ovr {} {
	if {$ro_mode} {return}
	set ins_ovr_mode [expr {!$ins_ovr_mode}]
	adjust_INS_OVR_label
}

## Get list of breapoints
 # @return List - result (eg. '{0 1 1 0 0 0}')
public method getBreakpoints {} {
	return $breakpoints
}

## Find a string in the text, scroll to it and select it
 # @parm Bool fromCursor	- Search from cursor / whole document
 # @parm Bool Backwards		- Search backwards from cursor / forwards
 # @parm Bool regExp		- Use regular expressions / exact matching
 # @parm Bool noCase		- Case insensitive / sensitive
 # @parm Bool inSelection	- Search in the selected block / search globaly
 # @parm String Sindex		- index in the text where the search should start
 # @parm String String		- String to search
 # @return List - {indexMatchBeginning indexMatchEnd matchesCount}
public method find {fromCursor Backwards regExp noCase inSelection Sindex String} {

	## adjust search options

	# set Stop-Index (and Start-index) depending on variable $inSelection
	if {![llength [$editor tag nextrange sel 1.0]]} {
		set inSelection 0
	}
	if {$inSelection} {
		set Sindex sel.first
		set Eindex sel.last
	} else {
		if {$Backwards} {
			set Eindex 1.0
		} else {
			set Eindex {end}
		}
	}

	# set direction and possibly Start-index too
	if {$fromCursor} {
		# Sindex
		set Sindex {insert}
	} else {
		# Sindex
		if {$Sindex == {}} {
			if {$Backwards} {
				set Sindex end
			} else {
				set Sindex 1.0
			}
		}
	}

	# direction
	if {$Backwards} {
		append Sindex -[expr {[string length $String] - 1}]c
		set direction {-backwards}
	} else {
		set direction {-forwards}
	}

	# set exact or regexp based on search and case sensitivity
	if {$regExp}	{set regexp {-regexp}} {set regexp {-exact}}

	## Perform search
	if {[catch {
		if {$noCase} {
			set index [$editor search $direction $regexp -nocase	\
				-count {::editor_search_count} --		\
				$String $Sindex $Eindex]
		} else {
			set index [$editor search $direction $regexp	\
				-count {::editor_search_count} --	\
				$String $Sindex $Eindex]
		}
	} result]} then {
		return [list -1 $result]
	}

	## Focus on the found string
	if {$index != {}} {
		# Determinate number of column (begin) and row of matched string
		set lineNumber [expr {int($index)}]
		regexp {\d+$} $index colNumber
		# Determinate lenght of matched string
		if {$regExp} {
			regexp $String [$editor get $Sindex $Eindex] String
		}
		# Determinate number of end column of matched string
		set end_col [string length $String]
		set end_col [expr {$end_col + $colNumber}]
		# Goto line with the found match and select that matched string
		if {$Backwards} {
			goto $lineNumber.$colNumber
		} else {
			goto $lineNumber.$end_col
		}
		$editor tag remove sel 1.0 end
		$editor tag add sel $index $lineNumber.$end_col
		# set result according to values determinated above
		set matches "$index $lineNumber.$end_col ${::editor_search_count}"
	} else {
		# set result to something like 'nothing found'
		set matches "$Sindex $Sindex 0"
	}

	# return result (see procedure header for details)
	return $matches
}

## Find a string in the text and replce it by something else ...
 # note: using 'find' procedure
 # @parm Bool fromCursor	- Search from cursor / whole document
 # @parm Bool inSelection	- Search in the selected block / search globaly
 # @parm Bool Backwards		- Search backwards from cursor / forwards
 # @parm Bool regExp		- Use regular expressions / exact matching
 # @parm Bool noCase		- Case insensitive / sensitive
 # @parm String SearchString	- String to search
 # @parm String Replacement	- String to replace SearchString
 # @parm Bool confirm		- (see attribute confirmCMD below)
 # @parm String confirmCMD	- command which will be executed on each match if cofirm is 1,
 #				  acceptable return values are:
 #					0 : Replace and search next
 #					1 : Replace and close
 #					2 : Replace all without prompt
 #					3 : Search next
 #					4 : Close
 # @return Bool - 1 == Ok; 0 == last replacement was refused by user
public method replace {fromCursor Backwards regExp noCase SearchString Replacement confirm confirmCMD} {
	# Local variables
	set remaining	1	;# Int - Count of remaining matches to replace
	set repl_made	0	;# Int - Count of replacements made
	set close	0	;# Bool - Close after this replace
	set cnd		1	;# Bool - Perform replacement in this iteration

	# Save the current insertion cursor index
	set ins_index [$editor index insert]

	if {$critical_edit_proc} {return 0}
	set critical_edit_proc 1

	## Derminate indexes of the area to be affected
	if {$fromCursor} {
		# from actual cursor position
		set index {insert}
	} else {
		if {$Backwards} {
			set index {end}
		} else {
			set index 1.0
		}
	}

	## Perform replacement for each match
	set index_org {}
	set index_new {}
	while {1} {
		# Initiate search and determinate count of remaining matches
		set last_chance 0
		while {1} {
			set result [find $fromCursor $Backwards $regExp $noCase 0 $index $SearchString]

			set remaining [lindex $result 2]
			if {$remaining == 0} {break}

			# Determinate index where to reinitiate search
			set index_org $index_new
			set index [lindex $result [expr {!$Backwards}]]
			set index_new $index
			if {$index_org == $index} {
				if {$last_chance} {
					break
				} else {
					if {!$Backwards} {
						set index [$editor index [list $index {+1c}]]
					} else {
						set index [$editor index [list $index {-1c}]]
					}
					set last_chance 1
				}
			} else {
				set last_chance 0
				break
			}
		}
		if {$last_chance || $remaining == 0 || $remaining == {}} {
			break
		}

		# Ask user if there is requested confirmation before each replace
		if {$confirm} {
			# invoke confirmation command and setup new parameters
			switch -- [$confirmCMD] {
				0	{	;# Replace
					set cnd 1
				}

				1	{	;# Replace & close
					set cnd 1
					set close 1
				}

				2	{	;# Replace all
					set cnd 1;
					set confirm 0
				}

				3	{	;# Find next
					set cnd 0
				}

				4	{	;# Close
					set cnd 1
					break
				}
			}
		} else {
			# automatically replace all without any prompt
			set cnd 1
		}

		# Perform replace if it's allowed
		if {$cnd} {
			# Determinate indexes of string to replace
			set start 	[lindex $result 0]
			set end		[lindex $result 1]
			# Replace
			$editor configure -autoseparators 0
			detete_text_in_editor $start $end
			$editor insert $start $Replacement
			if {!$Backwards} {
				set index [$editor index insert]
			}
			$editor edit separator
			$editor configure -autoseparators 1
			# restore syntax highlight on all affected lines
			set start [expr {int($start)}]
			set end [expr {int($end)}]
			if {$confirm} {
				for {set line $start} {$line <= $end} {incr line} {
					parse $line
				}
			} else {
				for {set line $start} {$line <= $end} {incr line} {
					restore_line_markers $line
				}
				set highlighted_lines [string replace $highlighted_lines	\
					$start $end [string repeat 0 [expr {$end - $start + 1}]]]
			}
			# increment counter of made replacemetns
			incr repl_made
			# contitionaly break replacing loop
			if {$close} {break}
		}
		# decrease counter of remining replacements
		incr remaining -1
	}

	$editor tag remove sel 1.0 end

	## Change application status bar (show results)
	Sbar [mc "Replace: %s replacements made" $repl_made]

	goto $ins_index
	highlight_visible_area
	set critical_edit_proc 0
	return $cnd
}

## Select all content of the editor's text widget
 # @return void
public method select_all {} {
	catch {
		$editor tag remove sel 1.0 end
	}
	$editor tag add sel 1.0 end
}

## Comment the selected area or current line
 # @return void
public method comment {} {
	if {$editor_to_use} {return}
	if {$completion_win_opened} {return}

	set start [expr {int([$editor index insert])}]
	$editor configure -autoseparators 0

	# Assembly language
	if {$prog_language == 0 || $prog_language == 3 || [string index $highlighted_lines $start] == 6} {
		# determinate indexes of area to comment
		if {[getselection] == {}} {
			set restore_sel 0
			set end $start
		} else {
			set restore_sel 1
			set start [expr {int([$editor index sel.first])}]
			set end_o [$editor index sel.last]
			set end [expr {int($end_o)}]
			if {$end == $end_o} {incr end -1}
		}

		# comment each line in the block
		autocompletion_maybe_important_change $start.0 $end.0
		for {set line $start} {$line <= $end} {incr line} {
			$editor insert $line.0 {;}
			restore_line_markers $line
		}

	# C language
	} elseif {$prog_language == 1} {
		# determinate indexes of area to comment
		if {[getselection] == {}} {
			set by_lines 1
			set restore_sel 0
			set end $start
		} else {
			set start_o [$editor index sel.first]
			set start [expr {int($start_o)}]
			set end_o [$editor index sel.last]
			set end [expr {int($end_o)}]
			if {$end == $end_o && $start == $start_o} {
				set restore_sel 1
				set by_lines 1
			} else {
				set restore_sel 0
				set by_lines 0
			}
			if {$end == $end_o} {
				incr end -1
			}
		}

		# Comment each line in the block
		autocompletion_maybe_important_change $start.0 $end.0
		if {$by_lines} {
			for {set line $start} {$line <= $end} {incr line} {
				$editor insert $line.0 {// }
				restore_line_markers $line
			}
		# Comment only selected characters
		} else {
			$editor insert $end_o { */}
			$editor insert $start_o {/* }
			$editor tag add sel sel.first-3c sel.last+3c
		}
	} else {
		$editor edit separator
		$editor configure -autoseparators 1
		return
	}

	$editor edit separator
	$editor configure -autoseparators 1

	if {$prog_language != -1} {
		# Restore highlight
		if {$prog_language == 1 && ![string index $highlighted_lines $start] == 6} {
			parse $start
		} else {
			for {set i $start} {$i <= $end} {incr i} {
				parse $i
			}
		}

		# Restore selection shape
		if {$restore_sel} {
			$editor tag add sel "$start.0 linestart" "$end.0 lineend"
		}
	}
}

## Remove first semicolon in selected area or current line
 # @return bool - result
public method uncomment {} {
	if {$editor_to_use} {return}
	if {$completion_win_opened} {return}

	set succesful 0
	set start [expr {int([$editor index insert])}]
	$editor configure -autoseparators 0

	# Assembly language
	if {$prog_language == 0 || $prog_language == 3 || [string index $highlighted_lines $start] == 6} {
		# determinate indexes of area to uncomment
		if {[getselection] == {}} {
			set restore_sel 0
			set end $start
		} else {
			set restore_sel 1
			set start [expr {int([$editor index sel.first])}]
			set end_o [$editor index sel.last]
			set end [expr {int($end_o)}]
			if {$end == $end_o} {incr end -1}
		}

		# Uncomment each line in the block
		for {set line $start} {$line <= $end} {incr line} {
			# get line
			set line_data [$editor get $line.0 "$line.0 lineend"]

			if {[regexp {^\s*;\s*} $line_data comment]} {
				detete_text_in_editor $line.0 $line.[string length $comment] 0
				regsub {;} $comment {} comment
				$editor insert $line.0 $comment
				restore_line_markers $line
				manage_autocompletion_list $line
				set succesful 1
			}
		}

	# C language
	} elseif {$prog_language == 1} {
		# determinate indexes of area to comment
		if {[getselection] == {}} {
			set by_lines 1
			set restore_sel 0
			set end $start
		} else {
			set start_o [$editor index sel.first]
			set start [expr {int($start_o)}]
			set end_o [$editor index sel.last]
			set end [expr {int($end_o)}]
			if {$end == $end_o && $start == $start_o} {
				set restore_sel 1
				set by_lines 1
			} else {
				set restore_sel 0
				set by_lines 0
			}
			if {$end == $end_o} {
				incr end -1
			}
		}

		# Uncomment only selected characters
		if {!$by_lines} {
			set start_data	[$editor get $start_o [list $start_o lineend]]
			set end_data	[$editor get [list $end_o linestart] $end_o]
			if {
				[regexp {^\s*/\* ?} $start_data start_data]
					&&
				[regexp { ?\*/\s*$} $end_data end_data]
			} then {
				set succesful 1
				set start_data [string length $start_data]
				set end_data [string length $end_data]
				detete_text_in_editor $end_o-${end_data}c $end_o 0
				detete_text_in_editor $start_o $start_o+${start_data}c 0
			}
		}

		# Uncomment each line in the block
		for {set line $start} {$line <= $end} {incr line} {
			set line_data [$editor get $line.0 [list $line.0 lineend]]
			if {[regexp {^\s*// ?} $line_data line_data]} {
				set line_data [string length $line_data]
				detete_text_in_editor $line.0 $line.$line_data 0
				manage_autocompletion_list $line
				set succesful 1
			}
			restore_line_markers $line
		}
	} else {
		$editor edit separator
		$editor configure -autoseparators 1
		return $succesful
	}
	$editor edit separator
	$editor configure -autoseparators 1

	if {$prog_language != -1} {
		# Restore highlight
		if {$prog_language == 1 && ![string index $highlighted_lines $start] == 6} {
			parse $start
		} else {
			for {set i $start} {$i <= $end} {incr i} {
				parse $i
			}
		}

		# Restore selection shape
		if {$restore_sel} {
			$editor tag add sel "$start.0 linestart" "$end.0 lineend"
		}

	}

	# Perform spell checking for all the affected lines
	if {$spellchecker_enabled} {
		for {set i $start} {$i <= $end} {incr i} {
			spellcheck_check_all $i
		}
	}

	# Return result
	return $succesful
}

## Go to line number or text index in the text
 # @parm Number textIndex - Can be line number (like 154) or text index (like 32.17)
 # @return void
public method goto {textIndex} {
	if {$editor_to_use} {return}

	# Check for validity of the given argument
	if {![regexp {^\d+(\.\d+)?$} $textIndex]} {
		return
	}
	# Adjust the given parameter
	if {![regexp {\.} $textIndex]} {
		set textIndex "$textIndex.0"
	}
	# Scroll to the required index and move cursor there
	rightPanel_adjust [expr {int($textIndex)}]
	$editor mark set insert $textIndex
	if {!$frozen} {
		$editor tag remove tag_current_line 1.0 end
		$editor tag add tag_current_line			\
			[$editor index "$textIndex linestart"]		\
			[$editor index "$textIndex +1 line linestart"]
	}
	recalc_status_counter {} 0
	update idletasks
	$editor see insert
}

## Delete all selected characters
 # @return Bool - Anything deleted
public method deleteselection {{parse_lines 0}} {
	set ranges [$editor tag ranges sel]
	set len [llength $ranges]
	for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {
		detete_text_in_editor [lindex $ranges $i] [lindex $ranges $j]

		if {$prog_language == 1} {
			c_syntax_highlight [expr {int([lindex $ranges $i])}]
		}

		if {$parse_lines} {
			set first [expr {int([lindex $ranges $i])}]
			set last [expr {int([lindex $ranges $j])}]
			set highlighted_lines [string replace $highlighted_lines	\
				$first $last [string repeat 0 [expr {$last - $first + 1}]]]

			$this parse $first
		}
	}

	return [expr {!(!$len)}]
}

## Get currently selected text
 # @return String - content of the selected area
public method getselection {} {
	set data {}
	set ranges [$editor tag ranges sel]
	set len [llength $ranges]
	for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {
		if {$i} {
			append data "\n"
		}
		append data [$editor get [lindex $ranges $i] [lindex $ranges $j]]
	}
	return $data
}

## Indent content of the selected area or current line
 # @return void
public method indent {} {
	if {$completion_win_opened} {return}

	# Determinate indexes of area to be affected
	if {[getselection] == {}} {
		set restore_sel 0
		set start [expr {int([$editor index insert])}]
		set end $start
	} else {
		set restore_sel 1
		set start [expr {int([$editor index sel.first])}]
		set end_o [$editor index sel.last]
		set end [expr {int($end_o)}]
		if {$end == $end_o} {incr end -1}
	}

	# indent each line in the block
	if {$spaces_no_tabs} {
		set indent_char [string repeat { } $number_of_spaces]
	} else {
		set indent_char "\t"
	}
	for {set line $start} {$line <= $end} {incr line} {
		$editor insert $line.0 $indent_char
		rightPanel_changeLineContent $line
		restore_line_markers $line
	}
	# Restore selection shape
	if {$restore_sel} {
		$editor tag add sel "$start.0 linestart" "$end.0 lineend"
	}
	$editor tag add sel $start.0 [expr {$end + 1}].0
}

## Unindent content of the selected area or current line
 # @return void
public method unindent {} {
	if {$completion_win_opened} {return}

	# Determinate indexes of area to be affected
	if {[getselection] == {}} {
		set restore_sel 0
		set start [expr {int([$editor index insert])}]
		set end [expr {int([$editor index insert])}]
	} else {
		set restore_sel 1
		set start [expr {int([$editor index sel.first])}]
		set end_o [$editor index sel.last]
		set end [expr {int($end_o)}]
		if {$end == $end_o} {incr end -1}
	}
	# unindent each line in the block
	for {set line $start} {$line <= $end} {incr line} {
		set line_data [$editor get $line.0 "$line.0 lineend"]
		if {$spaces_no_tabs} {
			if {[regexp {^ +} $line_data space]} {
				set space [string length $space]
				if {$space > $number_of_spaces} {
					set space $number_of_spaces
				}
				detete_text_in_editor $line.0 $line.$space
			} elseif {[regexp {^\t} $line_data]} {
				detete_text_in_editor $line.0 $line.1
			}
		} else {
			if {[regexp {^[\t(        )]} $line_data]} {
				detete_text_in_editor $line.0 $line.1
			}
		}
		rightPanel_changeLineContent $line
	}
	# Restore selection shape
	if {$restore_sel} {
		$editor tag add sel "$start.0 linestart" "$end.0 lineend"
	}
	$editor tag add sel $start.0 [expr {$end + 1}].0
}

## Get contents of the text widget
 # EOL: LF
 # Encoding: UTF-8
 # @return String
public method getdata {} {
	return [regsub {\n$} [$editor get 1.0 end] {}]
}

## Get contents of the text widget
 # EOL: $eol
 # Encoding: $encoding
 # @return String
public method getdata_adjusted_ENC_and_EOL {} {
	switch -- $eol {
		{lf}	{set eol_char "\n"}
		{cr}	{set eol_char "\r"}
		{crlf}	{set eol_char "\r\n"}
	}
	return	[encoding convertto $encoding		\
		[regsub -all {\n}			\
			[regsub {\n$}			\
				[$editor get 1.0 end]	\
			{}]	\
		$eol_char]	\
	]			\
}

## Get MD5 of the opened file
 # @return String - MD5 hash
public method get_md5 {} {
	switch -- $eol {
		{lf}	{set eol_char "\n"}
		{cr}	{set eol_char "\r"}
		{crlf}	{set eol_char "\r\n"}
	}
	return	[md5::md5 -hex					\
		[encoding convertto $encoding			\
			[regsub -all {\n}			\
				[regsub {\n$}			\
					[$editor get 1.0 end]	\
				{}]				\
			$eol_char]				\
		]						\
	]
}

## Add/Remove bookmark to/from current line
 # Directly depends on variable "bookmarks" (managed by proc. recalc_left_frame)
 # @parm Int idx=NULL - target text index
 # @return bool - 0: bookmark removed; 1: bookmark created
public method Bookmark {{idx {}}} {
	if {$editor_to_use} {return}

	# Determinate line number
	if {$idx != {}} {
		set lineNumber [expr {int($idx)}]
	} else {
		set lineNumber [expr {int([$editor index insert])}]
	}

	# Check for maximum line number value
	if {[expr {$lineNumber - [llength $bookmarks]}] > -1} {
		recalc_left_frame
		return
	}

	# Add or remove bookmark ?
	if {[lindex $bookmarks $lineNumber] == 1} {set make 0} {set make 1}
	lset bookmarks $lineNumber $make

	# Adjust line number
	set lineNumber_i [wrap_aux_idx2line $lineNumber]

	## Add/remove bookmark icon to/from iconBorder


	$iconBorder configure -state normal	;# Enable the text widget
	set scroll_in_progress 1		;# Disable scrolling

	# Add icon
	if {$make} {
		$iconBorder delete $lineNumber_i.0 $lineNumber_i.2

		if {$defaultCharHeight < 9} {
			$iconBorder insert $lineNumber_i.0 {*}
		} elseif {$defaultCharHeight < 15} {
			$iconBorder image create $lineNumber_i.0	\
				-image ::ICONS::16::dot			\
				-align center
		} else {
			if {[llength [$editor tag nextrange tag_error $lineNumber.0 [list $lineNumber.0 lineend]]]} {
				set image {bm_ex}
			} else {
				set image {bookmark}
			}
			$iconBorder image create $lineNumber_i.0	\
				-image ::ICONS::16::$image		\
				-align center
		}
	# Remove icon
	} else {
		$iconBorder delete $lineNumber_i.0 $lineNumber_i.2
		if {
			[llength [$editor tag nextrange tag_error $lineNumber.0 [list $lineNumber.0 lineend]]]
				&&
			$defaultCharHeight >= 15
		} then {
			$iconBorder image create $lineNumber_i.0	\
				-image ::ICONS::16::exclamation		\
				-align center
		}
	}

	# Disable the text widget
	$iconBorder configure -state disabled

	# Take care of bookmark tag
	set tmp $lineNumber
	incr tmp
	# Add the tag
	if {$make} {
		$editor tag add tag_bookmark $lineNumber.0 $tmp.0
		$parentObject rightPanel_add_bookmark $lineNumber
		$parentObject rightPanel_bm_select $lineNumber
	# Remove the tag
	} else {
		$editor tag remove tag_bookmark $lineNumber.0 $tmp.0
		$parentObject rightPanel_remove_bookmark $lineNumber
		$parentObject rightPanel_bm_unselect
	}

	# Enable scrolling
	update idletasks
	set scroll_in_progress 0

	# Done ...
	return $make
}

## Add/Remove breapoint to/from current line
 # Directly depends on variable "breakpoints" (managed by proc. recalc_left_frame)
 # @parm Int idx=NULL - target text index
 # @return bool - 0: breakpoint removed; 1: breakpoint created; or {}
public method Breakpoint {{idx {}}} {

	# Determinate line number
	if {$idx != {}} {
		set lineNumber [expr {int($idx)}]
	} else {
		set lineNumber [expr {int([$editor index insert])}]
	}

	# Check for maximum line number value
	if {[expr {$lineNumber - [llength $breakpoints]}] > -1} {
		recalc_left_frame
		return
	}

	# Add or remove breakpoint ?
	if {[lindex $breakpoints $lineNumber] == 1} {set make 0} {set make 1}
	# Set breakpoint flag
	lset breakpoints $lineNumber $make

	# Adjust line number
	set lineNumber_i [wrap_aux_idx2line $lineNumber]

	## Add/remove breakpoint tag to/from LineNumbers
	set tmp $lineNumber_i
	incr tmp

	$lineNumbers configure -state normal	;# Enable the text widget
	set scroll_in_progress 1		;# Disable scrolling

	# Add the tag
	if {$make} {
		# Detereminate whether the breakpoint will be valid or not
		if {[is_breakpoint_valid $lineNumber]} {
			set tag {tag_breakpoint}
		} else {
			set tag {tag_breakpoint_INVALID}
		}

		$lineNumbers tag add $tag $lineNumber_i.0 $tmp.0
		$parentObject rightPanel_add_breakpoint $lineNumber
		$parentObject rightPanel_bp_select $lineNumber

	# Remove the tag
	} else {
		$lineNumbers tag remove tag_breakpoint $lineNumber_i.0 $tmp.0
		$lineNumbers tag remove tag_breakpoint_INVALID $lineNumber_i.0 $tmp.0
		$parentObject rightPanel_remove_breakpoint $lineNumber
		$parentObject rightPanel_bp_unselect
	}

	# Disable the text widget
	$lineNumbers configure -state disabled

	# Refresh breakpoint settings in simulator engine
	if {[lindex ${::X::simulator_enabled} ${::X::actualProjectIdx}] == 1} {
		$parentObject Simulator_import_breakpoints $fullFileName [getBreakpoints]
	}

	# Enable scrolling
	update idletasks
	set scroll_in_progress 0

	# done ...
	return $make
}

## Remove all bookmarks from the editor and from right panel
 # @return void
public method clear_all_bookmarks {} {
	if {$editor_to_use} {return}

	# Clear icon border
	$iconBorder configure -state normal
	set idx -1
	foreach bool $bookmarks {
		incr idx
		if {!$bool} {continue}
		$iconBorder delete $idx.0 $idx.1
	}
	$iconBorder configure -state disabled

	# Clear text tags
	$editor tag remove tag_bookmark 1.0 end

	# Clear list of bookmarks
	set len [llength $bookmarks]
	incr len -1
	set bookmarks 0
	append bookmarks [string repeat { 0} $len]

	# Clear list of bookmakrs in the right panel
	$parentObject rightPanel_clear_all_bookmarks
}

## Remove all breakpoints from the editor and from right panel
 # @return void
public method clear_all_breakpoints {} {

	# Clear breakpoints in  object variable
	set len [llength $bookmarks]
	incr len -1
	set breakpoints 0
	append breakpoints [string repeat { 0} $len]

	# Clear breakpoint tags from line numbers
	$lineNumbers tag remove tag_breakpoint 1.0 end
	$lineNumbers tag remove tag_breakpoint_INVALID 1.0 end

	# Clear right panel
	$parentObject rightPanel_clear_all_breakpoints
}

## Get number of the current line
 # @return Int - current line num.
public method get_current_line_number {} {
	set line [expr {int([$editor index insert])}]
	return $line
}

## Call ::X::__show_hine_IconB
 # @return void
public method show_hine_IconB {} {
	::X::__show_hine_IconB
}

## Call ::X::__show_hine_LineN
 # @return void
public method show_hine_LineN {} {
	::X::__show_hine_LineN
}

## Show the Icon Border
 # @return bool - result
public method showIconBorder {} {
	if {!$show_iconBorder} {
		pack $left_frame_L -fill y -side left
		set show_iconBorder 1
		recalc_left_frame
		return 1
	}
	return 0
}

## Hide the Icon Border
 # @return bool - result
public method hideIconBorder {} {
	if {$show_iconBorder} {
		pack forget $left_frame_L
		set show_iconBorder 0
		return 1
	}
	return 0
}

## Show the Line Numbers
 # @return bool - result
public method showLineNumbers {} {
	if {!$show_lineNum} {
		pack $left_frame_R -fill y -side right
		set show_lineNum 1
		recalc_left_frame
		return 1
	}
	return 0
}

## Hide the Line Numbers
 # @return bool - result
public method hideLineNumbers {} {
	if {$show_lineNum} {
		pack forget $left_frame_R
		set show_lineNum 0
		return 1
	}
	return 0
}

## Insert given data into the text
 # @parm String data		- Data to insert
 # @parm TextIndex position	- Target text index ({} == "end")
 # @return void
public method insertData {data position} {
	if {$position == ""} {
		set position end
	}
	# Insert data
	$editor insert $position [regsub -all {[\u0000-\u0008\u000B-\u000C\u000E-\u001F\u007F-\u009F]} $data {}]
	# Highlight
	update idletasks
	parseAll
}

## Restore syntax highlight in whole text
 # @return void
public method parseAll {} {
	if {$editor_to_use} {return}

	# Disable this function
	set enable_parseAll 0

	# Determinate number of the last line in the editor
	set lastEnd [expr {int([$editor index end])}]

	# Initialize list of highlighted lines
	set highlighted_lines [string repeat 0 $lastEnd]

	# Reevaluate bookmarks and breakpoints
	$lineNumbers configure -state normal
	$lineNumbers delete 1.0 end
	$lineNumbers insert end 1
	$lineNumbers tag add right 1.0 end
	import_line_markers_data [join $bookmarks {}] [join $breakpoints {}]

	# Highlight all visible lines
	highlight_visible_area

	# Recalculate left frame and status bar counters
	scrollSet [lindex [$editor yview] 0] [lindex [$editor yview] 1]
	set lastEnd [expr {int([$editor index end])}]
	recalc_status_counter {} 0

	# Enable this function
	set enable_parseAll 1
}

## Get content of the given line
 # @parm Int lineNumber - number of the target line
 # @return String - result
public method getLineContent {lineNumber} {
	# Check lineNumber validity
	set end [$editor index end]
	if {$end <= $lineNumber} {return {}}

	# Return the data
	return [$editor get $lineNumber.0 "$lineNumber.0 lineend"]
}

## Parse the current line
 # @return void
public method parse_current_line {} {
	if {$editor_to_use} {return}
	set line [expr {int([$editor index insert])}]
	parse $line
	set highlighted_lines [string replace $highlighted_lines $line $line 0]
}

## Get number of lines between the given indexes
 # @parm TextIndex index0 - Start index
 # @parm TextIndex index1 - End index
 # @return Int - lines count
private method get_count_of_lines {index0 index1} {
	# Check if editor width is properly set
	if {$editor_width <= 0} {return 1}

	# Determinate text between the given indexes
	set lineText [$editor get $index0 $index1]

	# Line contains tabulators
	if {[regexp {\t} $lineText]} {
		# Translate tabulators to spaces
		set idx -1
		set cor 0
		while {1} {
			set idx [string first "\t" $lineText [expr {$idx + 1}]]
			if {$idx == -1} {break}

			incr cor [expr {7 - (($idx + $cor) % 8)}]
		}
		regsub -all {\t} $lineText { } lineText
		# Determinate line width in pixels
		set line_width [font measure $defaultFont_bold -displayof $editor $lineText]
		incr line_width [expr {$cor * $defaultCharWidth}]
	# Line doesn't contain tabulators
	} else {
		set line_width [font measure $defaultFont_bold -displayof $editor $lineText]
	}

	# Determinate number of lines
	set new_wrap [expr {$line_width / $editor_width}]
	if {[expr {$line_width % $editor_width}]} {
		incr new_wrap
	}

	# Return result
	return $new_wrap
}

## Get total number of lines in editor
 # @return Int - result
public method getLinesCount {} {
	if {$editor_to_use} {return 0}

	set result [$editor index end]
	return [expr {int($result) - 1}]
}

## Get data of bookmarks and breapoints
 # @return List - {bookmarks breakpoints} (eg. {{1 15 96} {2 45}})
public method export_line_markers_data {} {
	set foo [lsearch -ascii -exact -all $bookmarks 1]
	if {![llength $foo]} {
		set foo 0
	}
	set bar [lsearch -ascii -exact -all $breakpoints 1]
	if {![llength $bar]} {
		set bar 0
	}
	return [list $foo $bar]
}

## Import list of bookmarks and breapoints
 # This function also validates given input data
 # This function does not do anything with the right panel
 # @parm String Bookmarks	- bookmakrs	(eg. {1 15 96})
 # @parm String Breakpoints	- breakpoints	(eg. {2 45})
 # @return void
public method import_line_markers_data {Bookmarks Breakpoints} {
	if {$editor_to_use} {return}

	# Determinate number of the last line in the editor
	set lastEnd [expr {int([$editor index end])}]

	# Check validity of the given data
	if {[string index $Bookmarks 0] == {0}} {
		if {![regexp {^[01]*$} $Bookmarks]} {
			puts stderr [mc "Invalid list of bookmarks -- bookmarks discarded"]
			set Bookmarks {}
		}
	} else {
		set foo $Bookmarks
		set Bookmarks {}
		for {set i 0} {$i <= $lastEnd} {incr i} {
			if {[lsearch -ascii -exact $foo $i] != -1} {
				append Bookmarks 1
			} else {
				append Bookmarks 0
			}
		}
	}
	if {[string index $Breakpoints 0] == {0}} {
		if {![regexp {^[01]*$} $Breakpoints]} {
			puts stderr [mc "Invalid list of breakpoints -- bookmarks discarded"]
			set Breakpoints {}
		}
	} else {
		set foo $Breakpoints
		set Breakpoints {}
		for {set i 0} {$i <= $lastEnd} {incr i} {
			if {[lsearch -ascii -exact $foo $i] != -1} {
				append Breakpoints 1
			} else {
				append Breakpoints 0
			}
		}
	}

	# Initialize list of highlighted lines
	set highlighted_lines [string repeat 0 $lastEnd]

	# Enable left panel
	$iconBorder configure -state normal
	$lineNumbers configure -state normal

	# Fill in text widgets in left frame
	$iconBorder delete 1.0 end
	$iconBorder insert end [string repeat "\n" [expr {$lastEnd-2}]]
	for {set i 2} {$i < $lastEnd} {incr i} {
		$lineNumbers insert end "\n$i"
	}
	$lineNumbers configure -width [string length [expr {$lastEnd-1}]]

	## Import bookmarks
	set len [string bytelength $Bookmarks]	;# Number of bookmark flags
	set bookmarks [split $Bookmarks {}]	;# Bookmarks -> List
	# Adjust given input data (length)
	if {$lastEnd > $len} {
		append bookmarks [string repeat { 0} [expr {$lastEnd - $len}]]
	} elseif {$lastEnd < $len} {
		set bookmarks [lrange $bookmarks 0 [expr {$lastEnd - 1}]]
	}
	# Determinate list of bookmarked lines
	foreach line [lsearch  -ascii -exact -all $bookmarks 1] {
		if {!$line} {continue}

		# Create bookmark image
		if {$defaultCharHeight < 9} {
			$iconBorder insert $line.0 {*}
		} elseif {$defaultCharHeight < 15} {
			$iconBorder image create $line.0	\
				-image ::ICONS::16::dot		\
				-align center
		} else {
			$iconBorder image create $line.0	\
				-image ::ICONS::16::bookmark	\
				-align center
		}
		# Create bookmark text tag
		$editor tag add tag_bookmark $line.0 [expr {$line + 1}].0
		parse $line
	}

	## Import breakpoints
	set len [string bytelength $Breakpoints]	;# Number of breakpoint flags
	set breakpoints [split $Breakpoints {}]		;# Breakpoints -> List
	# Adjust given input data (length)
	if {$lastEnd > $len} {
		set ins [string repeat { 0} [expr {$lastEnd - $len}]]
		append breakpoints $ins
	} elseif {$lastEnd < $len} {
		set breakpoints [lrange $breakpoints 0 [expr {$lastEnd - 1}]]
	}
	# Determinate list of lines marked with bookmark
	foreach line [lsearch  -ascii -exact -all $breakpoints 1] {
		if {!$line} {continue}

		set line_1 $line
		incr line_1
		$lineNumbers tag add tag_breakpoint $line.0 $line_1.0
		parse $line
	}

	# Disable left panel
	$lineNumbers tag add right 1.0 end
	$iconBorder tag add center 1.0 end
	$iconBorder configure -state disabled
	$lineNumbers configure -state disabled

	reset_wraped_lines
}

## Execute any editor procedure
 # @parm String null		- anything (doesn't matter)
 # @parm String procedure	- procudure name
 # @parm String arguments	- procedure arguments
 # @return String - procedure result
public method editor_procedure {null procedure arguments} {
	# call editor's procedure
	return [eval "$procedure $arguments"]
}

## Jump to the bookmark below the current line
 # @return Bool - result
public method goto_next_bookmark {} {
	if {$editor_to_use} {return}

	# Local varibales
	set line $last_cur_line			;# Current line
	set linesMax [llength $bookmarks]	;# Maximal line number

	incr line

	# Search for the nearest bookmark
	for {set i $line} {$i < $linesMax} {incr i} {
		if {[lindex $bookmarks $i] == 1} {
			goto $i
			return 1
		}
	}

	# Failed
	return 0
}

## Jump to the bookmark above the current line
 # @return Bool - result
public method goto_prev_bookmark {} {
	if {$editor_to_use} {return}

	# Local varibales
	set line $last_cur_line			;# Current line
	set linesMax [llength $bookmarks]	;# Maximal line number

	incr line -1

	# Search for the nearest bookmark
	for {set i $line} {$i > 0} {incr i -1} {
		if {[lindex $bookmarks $i] == 1} {
			goto $i
			return 1
		}
	}

	# Failed
	return 0
}

## Set state of editor lock on status bar
 # @parm Bool bool - 1 == Locked; 0 == Unlocked
 # @return void
public method set_lock {bool} {
	if {$bool} {
		setStatusTip -widget $Sbar_lock_file -text [mc "File switching locked"]
		Sbar -freeze [mc "File switching locked"]
		DynamicHelp::add $Sbar_lock_file -text [mc "Unlock file switching"]
		$Sbar_lock_file configure		\
			-image ::ICONS::16::lock
	} else {
		setStatusTip -widget $Sbar_lock_file -text [mc "File switching unlocked"]
		Sbar -freeze [mc "File switching unlocked"]
		DynamicHelp::add $Sbar_lock_file -text [mc "Lock file switching"]
		$Sbar_lock_file configure		\
			-image ::ICONS::16::unlock
	}
	set auto_switching_lock $bool
}

## Invert simulator lock
 # @return void
public method invert_lock {} {
	set_lock [expr {!$auto_switching_lock}]
	$parentObject set_editor_lock $this $auto_switching_lock
}

## Get value of internal flag "frozen"
 # @return Bool - True if the editor is in simulator mode, or disabled mode
public method get_flag_frozen {} {
	return $frozen
}

## Switch from editor mode to simulator mode
 # This operation will cause error if editor is in mode disabled
 # @return void
public method freeze {} {
	if {$editor_to_use} {return}
	close_completion_popup_window

	# Adjust editor
	$editor configure -state disabled
	$editor tag remove tag_current_line 1.0 end
	pack forget $Sbar_CRT_frame
	catch {
		pack forget $Sbar_dis_mode
	}
	catch {
		pack forget $Sbar_ssim_mode
	}
	catch {
		pack forget $Sbar_sim_mode
	}
	if {!$frozen} {
		pack $Sbar_ssim_mode -side right
		pack $Sbar_lock_file -side left
	} else {
		pack $Sbar_sim_mode -side right
	}
	# Disable some popup menu items
	foreach entry $freezable_menu_items {
		$menu entryconfigure [::mc $entry] -state disabled
	}
	# Set mode flag
	set frozen 1
}

## Switch from editor mode to disabled
 # This operation will cause error if editor is in simulator mode
 # @return void
public method disable {} {
	if {$editor_to_use} {return}
	close_completion_popup_window

	# Adjust editor
	$editor configure -state disabled
	$editor tag remove tag_current_line 1.0 end
	pack forget $Sbar_CRT_frame
	catch {
		pack forget $Sbar_sim_mode
	}
	pack $Sbar_dis_mode -side right
	if {!$frozen} {
		pack $Sbar_lock_file -side left
	}
	# Disable some popup menu items
	foreach entry $freezable_menu_items {
		$menu entryconfigure [::mc $entry] -state disabled
	}
	# Set mode flag
	set frozen 1
}

## Switch from simulator mode to editor mode
 # @return void
public method thaw {} {
	if {$editor_to_use} {return}

	# Set mode flag
	set frozen 0
	# Adjust editor
	if {!$ro_mode} {
		$editor configure -state normal
	}
	set idx [$editor index "insert linestart"]
	$editor tag add tag_current_line $idx "$idx + 1 line"
	pack $Sbar_CRT_frame
	pack forget $Sbar_lock_file
	catch {
		pack forget $Sbar_sim_mode
	}
	catch {
		pack forget $Sbar_ssim_mode
	}
	catch {
		pack forget $Sbar_dis_mode
	}
	# Enable all popup menu items
	if {!$ro_mode} {
		foreach entry $freezable_menu_items {
			$menu entryconfigure [::mc $entry] -state normal
		}
	}
	# Recalculate counters
	recalc_status_counter {} 0

	# Check the flag "file_change_notif_flg" and if set, inform the user
	#+ about modification to the currently opened file done by another
	#+ program.
	check_file_change_notif
}

## Move simulator line (line representing current position in simulator engine)
 # @parm Int lineNum - target line number
 # @return void
public method move_simulator_line {lineNum} {
	if {$editor_to_use} {return}
	set lineNum_1 $lineNum
	incr lineNum_1
	unset_simulator_line
	$editor tag add tag_simulator_curr $lineNum.0 $lineNum_1.0
	$editor see $lineNum.0
}

## Unset simulator line tag and restore current line tag
 # @return void
public method unset_simulator_line {} {
	$editor tag remove tag_simulator_curr 1.0 end
}


## IDE is now in "Simulator mode" (previous state was "Starting simulator")
 # @return void
public method now_frozen {} {
	if {$editor_to_use} {return}
	if {[winfo ismapped $Sbar_ssim_mode]} {
		pack forget $Sbar_ssim_mode
		pack $Sbar_sim_mode -side right
	}
}

## Highlight lines which hasn't been highlighted yet
 # @return void
public method highlight_visible_area {} {
	# Abort if the call is not relevant
	if {!$editor_height} {
		return
	}

	# Determinate indexes of the current view
	set lastLine	[expr {int([$editor index end])}]
	set start	[expr {int([$editor index @5,5])}]
	set end		[expr {$start + $editor_height - 1}]

	# Adjust start and end index
	if {$start < 1} {
		set start 1
	}
	if {$end > $lastLine} {
		set end $lastLine
	}

	# Abort if there is nothing to do
	if {[string first 0 [string range $highlighted_lines $start $end]] == -1} {
		return
	}

	# Enable editor if it's disabled
	if {$frozen} {$editor configure -state normal}

	# Highlight the current view
	for {set line $start} {$line <= $end} {incr line} {
		if {[string index $highlighted_lines $line] == 0} {
			if {![parse $line 1]} {
				if {$line != $start} {break}
			}
		}
	}

	# Ensure that the current line is also checked for correct spelling
	spellcheck_check_all [expr {int([$editor index insert])}] 1

	# Restore previous editor state
	if {$frozen} {$editor configure -state disabled}
}


## Save content of editor text widget
 # note: Name of the target file should be stored in $fullFileName,
 #	 if it is not then invoke procedure 'X::__save_as'
 # @return Bool - result
public method save {} {
	if {$ro_mode} {return 1}
	if {$editor_to_use} {return 1}
	if {$save_in_progress} {return 1}
	set save_in_progress 1

	# Check previously set filename
	if {$fullFileName == {}} {
		# Ask user for a new filename
		set ::X::critical_procedure_in_progress 0
		set save_in_progress 0
		X::__save_as
	} else {
		# save data to file
		if {[file exists $fullFileName]} {
			catch {
				file rename -force $fullFileName "$fullFileName~"
			}

			# Stop watching for modification of this file on disk (we will reenable it later)
			FSnotifications::forget $fullFileName
		}

		if {[catch {
			set chanel [open $fullFileName w 0640]
		}]} then {
			tk_messageBox		\
				-parent .	\
				-icon warning	\
				-type ok	\
				-title [mc "Permission denied"]	\
				-message [mc "Unable to open file:\n\"%s\"\nfor writing" $fullFileName]
			set save_in_progress 0

			# Again start watching for modification of this file on disk
			FSnotifications::watch $fullFileName [list ::Editor::file_change_notif $this]

			return 0
		}
		fconfigure $chanel -translation $eol -encoding $encoding
		puts -nonewline $chanel [getdata]
		close $chanel
		pack forget $Sbar_image
		$editor edit modified 0
		set modified 0

		# Again start watching for modification of this file on disk
		FSnotifications::watch $fullFileName [list ::Editor::file_change_notif $this]

		# Stop autosave timer
		catch {
			after cancel $autosave_timer
		}
	}

	# Change application status
	::X::adjust_title

	set save_in_progress 0
	if {$fullFileName == {}} {
		return 0
	} else {
		if {$::MICROSOFT_WINDOWS} { ;# "/" --> "\"
			regsub -all {/} $fullFileName "\\" fullFileName_win
		} else {
			set fullFileName_win $fullFileName
		}
		Sbar [mc "File %s saved" $fullFileName_win]
		return 1
	}
}

## Set internal flag "file_change_notif_flg" to true
 #
 # The flag indicates that the file opened in this editor was modified on disk
 # by another program. The flag is automatically cleared when the user is
 # informed about the modification to the file.
 #
 # @return void
public method set_file_change_notif_flg {} {
	set file_change_notif_flg 1
}

## Check flag "file_change_notif_flg" and if set, inform the user about this.
 #
 # The flag file_change_notif_flg indicates that the file opened in this editor
 # was modified on disk by another program. The flag is automatically cleared by
 # this method. The user is informed  via a dialog window giving him three
 # options, reload the file, overwrite it on disk, and ignore it.
 #
 # @return void
public method check_file_change_notif {} {
	# Check the flag, and clear it if it was set
	if {!$file_change_notif_flg} {
		return
	}
	set file_change_notif_flg 0

	# Create the dialog window
	set dialog [toplevel .file_change_notif_dlg]

	# Create top frame (dialog icon and text of the message)
	set dlg_top_frame [frame $dialog.top_frame]
	pack [label $dlg_top_frame.image -image ::ICONS::32::messagebox_warning] -side left -padx 5
	pack [label $dlg_top_frame.label \
		-justify left \
		-text [mc "The file '%s' was modified from outside of this program.\n\nWhat do you want to do with the modified file?" [file tail $fullFileName]]	\
	] -side left -fill x -expand 1 -padx 5

	# Create bottom bar with dialog buttons
	set button_frame [frame $dialog.button_frame]
	pack [ttk::button $button_frame.button_reload	\
		-text [mc "Reload in editor"]		\
		-compound left				\
		-image ::ICONS::16::reload		\
		-command "
			$parentObject filelist_reload_file $this 1
			grab release $dialog
			destroy $dialog
		" \
	] -side left -padx 2
	pack [ttk::button $button_frame.button_overwrt	\
		-text [mc "Overwrite on disk"]		\
		-compound left				\
		-image ::ICONS::16::filesave		\
		-command "
			$this save
			grab release $dialog
			destroy $dialog
		" \
	] -side left -padx 2
	pack [ttk::button $button_frame.button_cancel	\
		-text [mc "Do nothing"]			\
		-compound left				\
		-image ::ICONS::16::cancel		\
		-command "
			grab release $dialog
			destroy $dialog
		" \
	] -side left -padx 2

	# Pack window frames
	pack $dlg_top_frame -side top -fill x -expand 1 -padx 5 -pady 10
	pack $button_frame -side bottom -side right -padx 5 -pady 5

	bind $dialog <Escape> "
		grab release $dialog
		destroy $dialog
	"

	# Set dialog attributes (modal window)
	wm iconphoto $dialog ::ICONS::16::status_unknown
	wm title $dialog [mc "File changed on disk"]
	wm state $dialog normal
	wm minsize $dialog 400 110
	wm transient $dialog .
	wm protocol $dialog WM_DELETE_WINDOW "
		grab release $dialog
		destroy $dialog
	"
	update
	catch {
		grab $dialog
	}
	raise $dialog
	focus -force $button_frame.button_cancel
	tkwait window $dialog
}

## File change notification callback
 #
 # This function is supposed to be called by the FSnotifications component when
 # a modification to the currently opened file was made by another program.
 #
 # @return void
proc file_change_notif {editor_ref filename} {
	# This call is invalid if there are no projects opened
	if {![llength ${::X::openedProjects}]} {
		return
	}

	# Attempt to find the corresponding project and editor index number
	foreach project ${::X::openedProjects} {
		set list_of_editors [$project cget -editors]
		set actual_editor [$project cget -actualEditor]
		set actual_editor2 [$project cget -actualEditor2]
		set editor_idx [lsearch -ascii -exact $list_of_editors $editor_ref]

		if {$editor_idx == -1} {
			# Editor editor index number not found, move on to another project
			continue
		}

		# Try to get the "frozen" flag from the editor
		if {[catch {
			set editor_frozen [$editor_ref get_flag_frozen]
		}]} then {
			# Unable to comply, that probably means that the editor
			# does not exist any more
			return
		}

		# Set the "file_change_notif_flg" flag
		$project editor_procedure $editor_idx set_file_change_notif_flg {}

		# Check the "file_change_notif_flg" flag right away, if the
		#+ editor is currently visible to the user
		if {
			($project == ${::X::actualProject})
				&&
			($editor_idx == $actual_editor || $editor_idx == $actual_editor2)
		} then {
			# If the editor is in frozen state, i.e. the MCU
			# simulator is engaged, then don't annoy with nonsense
			# messages, and instead inform the user later.
			if {!$editor_frozen} {
				$project editor_procedure $editor_idx check_file_change_notif {}
			}
		}

		break
	}
}

## Set variable 'fullFileName' for later file save (method 'save')
 # note: also change editors status bar
 # @parm String full_filename	- the full filename (including path)
 # @parm String rootName	- only filename with extension
 # @return void
public method set_FileName {full_filename rootName} {
	if {$editor_to_use} {return}

	# Start watching for changes in the file (on disk)
	if {$fullFileName != {}} {
		# Stop watching the old file
		FSnotifications::watch forget $fullFileName
	}
	if {$full_filename != {}} {
		# Start watching the new file
		FSnotifications::watch $full_filename [list ::Editor::file_change_notif $this]
	}

	# set variables
	set fullFileName $full_filename
	set filename $rootName
	# change etitor status bar
	$Sbar_fileName configure -text $filename -helptext $filename
	# Determinate programming language
	determinate_prog_lang 1
}

## Get current filename
 # @return String - the filename
public method getFileName {} {
	return [list [file dirname $fullFileName] $filename]
}

## Change letter case according to the given options
 # @parm List options	- list of 21 values, each must be one of {- L -U}
 #			  '-' - keep case
 #			  'U' - Uppercase
 #			  'L' - Lowercase
 # @return void
public method change_letter_case {options} {

	# Reset abort condition
	set changeLCase_abort 0

	# Initialize conter of iterations
	set i 0

	# Perform case change
	foreach option $options	\
		tags {
			tag_hex			tag_oct
			tag_dec			tag_bin
			tag_constant		tag_unknown_base
			tag_comment		tag_control
			tag_symbol		tag_directive
			tag_label		tag_instruction
			tag_sfr			tag_indirect
			tag_imm_hex		tag_imm_oct
			tag_imm_dec		tag_imm_bin
			tag_imm_constant	tag_imm_unknown
			tag_macro
		} \
	{
		# Evaluate option
		if {$option == {-}} {continue}
		if {$option == {U}} {
			set option {toupper}
		} else {
			set option {tolower}
		}

		if {$tags == {tag_constant}} {
			lappend tags {tag_constant_def}
		} elseif {$tags == {tag_macro}} {
			lappend tags {tag_macro_def}
		}

		# Iterate over tag ranges and change their letter case
		foreach tag $tags {
			set ranges [$editor tag ranges $tag]
			for {set j 0} {$j < [llength $ranges]} {incr j} {
				# Determinate string indexes
				set firts [lindex $ranges $j]
				incr j
				set last [lindex $ranges $j]

				# Perform letter case change
				set string [string $option [$editor get $firts $last]]
				$editor delete $firts $last
				$editor insert $firts $string
				$editor tag add $tag $firts $last

				# Manage GUI
				if {![expr {$i % 50}]} {
					# Update progress bar
					incr ::X::compilation_progress
					update

					# Conditional abort
					if {$changeLCase_abort} {
						return
					}
				}

				# Increment counter of iterations
				incr i
			}
		}
	}
}

## Abort procedure 'change_letter_case'
 # @return void
public method change_letter_case_abort_now {} {
	set changeLCase_abort 1
}

## Get maximum value for progressbar showing change letter case progress (proc. 'change_letter_case')
 # @parm List options - same as with proc. 'change_letter_case'
 # @return Int - Number of iterations divided by 50
public method change_letter_case_get_count_of_iterations {options} {
	set result 0
	foreach option $options	\
		tag {	tag_hex			tag_oct
			tag_dec			tag_bin
			tag_constant		tag_unknown_base
			tag_comment		tag_control
			tag_symbol		tag_directive
			tag_label		tag_instruction
			tag_sfr			tag_indirect
			tag_imm_hex		tag_imm_oct
			tag_imm_dec		tag_imm_bin
			tag_imm_constant	tag_imm_unknown
			tag_macro}	\
	{
		if {$option == {-}} {continue}

		incr result [llength [$editor tag ranges $tag]]
		if {![expr {$result % 1000}]} {update}
	}
	return [expr {$result / 50}]
}

## Convert selected text to lowercase
 # @retrun void
public method lowercase {} {
	# Nothing to do -> terminate
	if {![llength [$editor tag nextrange sel 1.0]]} {
		Sbar [mc "Unable to execute: nothing selected"]
		return 0
	}

	$editor configure -autoseparators 0
	set ranges [$editor tag ranges sel]
	set len [llength $ranges]
	for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {
		set first [lindex $ranges $i]
		set last [lindex $ranges $j]
		set data [$editor get $first $last]
		$editor tag remove $first $last
		detete_text_in_editor $first $last
		$editor insert $first [string tolower $data]
		$editor tag add sel $first $last

		set first [expr {int($first)}]
		set last [expr {int($last)}]
		set highlighted_lines [string replace $highlighted_lines	\
			$first $last [string repeat 0 [expr {$last - $first + 1}]]]
	}

	highlight_visible_area
	$editor edit separator
	$editor configure -autoseparators 1
	return 1
}

## Convert selected text to uppercase
 # @retrun void
public method uppercase {} {
	# Nothing to do -> terminate
	if {![llength [$editor tag nextrange sel 1.0]]} {
		Sbar [mc "Unable to execute: nothing selected"]
		return 0
	}

	$editor configure -autoseparators 0
	set ranges [$editor tag ranges sel]
	set len [llength $ranges]
	for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {
		set first [lindex $ranges $i]
		set last [lindex $ranges $j]
		set data [$editor get $first $last]
		$editor tag remove $first $last
		detete_text_in_editor $first $last
		$editor insert $first [string toupper $data]
		$editor tag add sel $first $last

		set first [expr {int($first)}]
		set last [expr {int($last)}]
		set highlighted_lines [string replace $highlighted_lines	\
			$first $last [string repeat 0 [expr {$last - $first + 1}]]]
	}

	highlight_visible_area
	$editor edit separator
	$editor configure -autoseparators 1
	return 1
}

## Convert the first character of selected text to uppercase
 # @retrun void
public method capitalize {} {
	# Nothing to do -> terminate
	if {![llength [$editor tag nextrange sel 1.0]]} {
		Sbar [mc "Unable to execute: nothing selected"]
		return 0
	}

	$editor configure -autoseparators 0
	set first [$editor index sel.first]
	set last [$editor index sel.last]
	set data [string toupper [$editor get $first $first+1c]]
	detete_text_in_editor $first $first+1c
	$editor insert $first $data
	$editor tag add sel $first $last
	parse [expr {int($first)}]
	$editor edit separator
	$editor configure -autoseparators 1
	return 1
}

## Copy the selected text to the clipboard
 # @return bool - 1: successful; 0: failed
public method copy {} {
	# get selected text
	set data [getselection]

	# Nothing to do -> terminate
	if {$data == {}} {
		Sbar [mc "Unable to execute: nothing selected"]
		return 0
	# Adjust clipboard content
	} else {
		clipboard clear
		clipboard append $data
		return 1
	}
}

## Paste clipboard content to the text at the cursor position
 # @parm Bool use_X_sel=0	- Use X selection instead of the clipboard
 # @parm Int x			- X coordinate
 # @parm Int y			- Y coordinate
 # @return bool - 1: successful; 0: failed
public method paste {{use_X_sel 0} {x {}} {y {}}} {
	if {$critical_edit_proc} {return}
	set critical_edit_proc 1

	# Restore original cursor position in block selection mode
	if {$selection_mode} {
		set original_cur_pos [$editor index insert]
	}

	if {$use_X_sel} {
		set cmd {selection}
	} else {
		set cmd {clipboard}
	}

	# Get clipboard content
	if {[catch {
		set data [regsub -all {[\u0000-\u0008\u000B-\u000C\u000E-\u001F\u007F-\u009F]} [$cmd get] {}]
	}]} then {
		# Clipboard empty -> abort
		set critical_edit_proc 0
		return 0
	}

	if {$use_X_sel} {
		$editor mark set insert @$x,$y
		catch {
			$editor tag remove sel 0.0 end
		}
	}

	# delete selected block
	$editor configure -autoseparators 0
	deleteselection
	recalc_left_frame
	# insert data to the text, restore syntax highlight
	$editor insert [$editor index insert] $data
	recalc_left_frame
	recalc_status_counter {}
	$editor see [$editor index insert]
	update idletasks
	set line [expr {int([$editor index insert])}]
	rightPanel_adjust $line
	parse $line
	spellcheck_check_all $line 2	;# Perform spell check for the current line
	highlight_visible_area
	$editor edit separator
	$editor configure -autoseparators 1

	# Reevaluate highlight on the next line if C language is used
	if {$prog_language == 1} {
		incr line
		c_syntax_highlight $line
	}
	# Restore original cursor position in block selection mode
	if {$selection_mode} {
		$editor see $original_cur_pos
		$editor mark set insert $original_cur_pos
	}

	rewrite_breakpoint_tags

	update
	set critical_edit_proc 0
	return 1
}

## Take back last editor operation
 # @return void
public method undo {} {
	if {$critical_edit_proc} {return}
	set critical_edit_proc 1

	if {![catch {$editor edit undo}]} {
		# Inform autocompletion mechanism
		$editor edit redo
		parse_current_line
		autocompletion_maybe_important_change insert insert
		$editor edit undo
		manage_autocompletion_list [expr {int([$editor index insert])}]

		recalc_left_frame
		recalc_status_counter {}
		recalc_status_modified 1
		rightPanel_adjust [expr {int([$editor index insert])}]
		$editor see [$editor index insert]
		set highlighted_lines [string repeat 0 [string bytelength $highlighted_lines]]
		update
		highlight_visible_area
		catch {
			$editor tag remove sel 0.0 end
		}
	}
	set critical_edit_proc 0
}

## Take back last Undo operation
 # @return void
public method redo {} {
	if {$critical_edit_proc} {return}
	set critical_edit_proc 1
	if {![catch {$editor edit redo}]} {
		# Inform autocompletion mechanism
		$editor edit undo
		parse_current_line
		autocompletion_maybe_important_change insert insert
		$editor edit redo
		manage_autocompletion_list [expr {int([$editor index insert])}]

		recalc_left_frame
		recalc_status_counter {}
		recalc_status_modified 1
		rightPanel_adjust [expr {int([$editor index insert])}]
		$editor see [$editor index insert]
		set highlighted_lines [string repeat 0 [string bytelength $highlighted_lines]]
		update
		highlight_visible_area
		catch {
			$editor tag remove sel 1.0 end
		}
	}
	set critical_edit_proc 0
}

## Cut the selected text and put it into the clipboard
 # @return bool - 1: successful; 0: failed
public method cut {} {
	if {$critical_edit_proc} {return}
	set critical_edit_proc 1
	# get selected text
	set data [getselection]

	# Nothing to do -> terminate
	if {$data == {}} {
		Sbar [mc "Unable to execute: nothing selected"]
		set critical_edit_proc 0
		return 0
	# Cut
	} else {
		# Adjust clipboard content
		deleteselection
		clipboard clear
		clipboard append $data
		$editor see insert
		set line [expr {int([$editor index insert])}]
		parse $line
		update
		recalc_left_frame
		rightPanel_adjust $line
		set critical_edit_proc 0
		return 1
	}
}

## Delete current line
 # @return void
public method delete_current_line {} {
	if {
		[$editor compare {insert linestart} == {insert lineend}]
			&&
		[$editor compare {insert linestart} == {end-1l}]
	} then {
		return
	}
	detete_text_in_editor {insert linestart} {insert linestart + 1l}
	$this resetUpDownIndex
	$this recalc_left_frame
	$this parse [expr {int([$editor index insert])}]
	update
}

## Insure that command line is focused
 # @retrun void
public method cmd_line_force_on {} {
	if {$editor_to_use} {return}
	if {![winfo viewable $cmd_line]} {
		pack $cmd_line -side top -fill x
	}
	update
}

## Insure that command line is NOT focused
 # @retrun void
public method cmd_line_force_off {} {
	if {$editor_to_use} {return}

	if {!${::APPLICATION_LOADED}} {return}
	if {[winfo viewable $cmd_line]} {
		pack forget $cmd_line
		focus $editor
	}
	update
}

## Kill child processes
 # @return void
public method kill_childern {} {
	if {$editor_to_use} {
		bind $top_frame <Destroy> {}
		if {!$::MICROSOFT_WINDOWS} { ;# There is no kill command on Microsoft Windows
			if {$pid != [pid] && $pid != 0} {
				catch {
					exec -- kill $pid
				}
			}
		}
		catch {
			file delete -force -- [file join [${::X::actualProject} cget -ProjectDir] .#special:tmp]
		}
	}
}

## Get ID of file type (programming language used)
 # @return Int - 0 == Assembly language; 1 == C language
public method get_language {} {
	if {$prog_language == -1} {
		set ext [string trimleft [file extension $filename] {.}]
		if {$ext == {c} || $ext == {h} || $ext == {cxx} || $ext == {cpp} || $ext == {cc}} {
			return 1
		} elseif {$ext == {lst}} {
			return 2
		} else {
			return 0
		}
	} else {
		return $prog_language
	}
}

## Set file type (programming language used)
 # @parm Int lang -  -1 == unknown; 0 == Assembly language; 1 == C language
 # @return void
public method force_language {lang} {
	set prog_language_old $prog_language
	set prog_language $lang

	if {$prog_language_old != $prog_language} {
		prog_lang_changed
	}
}

## Document current function
 # @return void
public method document_current_func {} {
	# Critical procedure
	if {$critical_edit_proc} {return}
	set critical_edit_proc 1

	# Check if this procedure can be done
	if {$editor_to_use || $prog_language != 1} {return}

	# Determinate line content
	set line_number [expr {int([$editor index insert])}]
	set line_content [$editor get {insert linestart} {insert lineend}]
	set line_n $line_number
	for {set i 0} {$i < 50} {incr i} {
		if {[string first {)} $line_content] != -1} {
			break
		}
		incr line_n
		append line_content { } [$editor get [list $line_n.0 linestart] [list $line_n.0 lineend]]
	}

	# Check if line content is valid function declaration
	if {![regexp {^\s*(\w+\s+)+\w+\(.*\)} $line_content]} {
		Sbar [mc "No function to document"]
		set critical_edit_proc 0
		return
	}

	# Determinate leading space to keep indention level
	if {![regexp {^\s+} $line_content space]} {
		set space {}
	}

	# Insert '/**'
	$editor insert $line_number.0 "${space}/**\n"
	incr line_number

	# Document arguments
	set args {}
	if {[regexp {\(.*\)} $line_content args]} {
		set args [string range $args 1 end-1]
		foreach word [split $args {,}] {
			set word [split [string trim $word "\t  "]]
			if {[llength $word] < 2} {
				continue
			}
			set word [lindex $word end]
			regsub {\[.*\]$} $word {} word
			regsub {^(\&|\*\*?)} $word {} word
			$editor insert $line_number.0 "${space} * @param ${word}\n"
			incr line_number
		}
	}

	# Document return value
	if {![regexp {^\s*void\s+} $line_content]} {
		$editor insert $line_number.0 "${space} * @return\n"
		incr line_number
	}
	$editor insert $line_number.0 "${space} */\n"
	incr line_number

	# Highlight
	recalc_left_frame
	recalc_status_counter {}
	$editor see $line_number.0
	update
	rightPanel_adjust $line_number
	parse $line_number
	highlight_visible_area
	incr line_number
	c_syntax_highlight $line_number
	set critical_edit_proc 0
}

## Get file statistics
 # @return List - List of integers in this format:
 #	Index	Meaning
 #	0	Words and numbers	(Characters)
 #	1	Comments		(Characters)
 #	2	Others			(Characters)
 #	3	Total characters	(Characters)
 #	4	Words			(Strings)
 #	5	Keywords		(Strings)
 #	6	Comments		(Strings)
 #	7	Total strings		(Strings)
 #	8	Empty lines		(Lines)
 #	9	Commented lines		(Lines)
 #	10	Normal lines		(Lines)
 #	11	Total lines		(Lines)
public method getFileStatistics {} {
	if {$editor_to_use} {return {0 0 0 0 0 0 0 0}}
	set last_line [expr {int([$editor index end])}]

	set words_and_numbers	0
	set chars_comments	0
	set others		0
	set words		0
	set keywords		0
	set comments		0
	set empty_lines		0
	set commented_lines	0
	set normal_lines	0

	# List of highlighting tags related to comments
	set comment_tags {
		tag_comment	tag_c_comment	tag_c_dox_comment
		tag_c_dox_tag	tag_c_dox_word	tag_c_dox_name
		tag_c_dox_html
	}
	# List of highlighting tags related to keywords
	set keyword_tags {
		tag_directive	tag_instruction	tag_control
		tag_c_keyword	tag_c_directive
	}

	# Iterate over lines in editor
	for {set line_num 1} {$line_num < $last_line} {incr line_num} {
		# Get line length and content
		set line [string trimright [$editor get $line_num.0 [list $line_num.0 lineend]]]
		set len [string length $line]

		# Handle empty lines
		if {!$len} {
			incr empty_lines
			continue
		}
		# Save some values for purpose of section "Lines"
		set last_words		$words
		set last_keywords	$keywords
		set last_comments	$comments

		# Iterate over characters on the line
		set char {}
		set found 0
		set last_wordstart -1
		for {set i 0} {$i < $len} {incr i} {
			# Determinate word type
			set found 0
			set wordstart [$editor index [list $line_num.$i wordstart]]
			if {$wordstart != $last_wordstart} {
				set wordend [$editor index [list $line_num.$i wordend]]
				set last_wordstart $wordstart
				set tag_names [$editor tag names $line_num.$i]
				foreach tags [list $comment_tags $keyword_tags]	\
					var {comments keywords}			\
				{
					foreach tag $tag_names {
						if {[lsearch $tags $tag] != -1} {
							incr $var
							set found 1
							break
						}
					}
					if {$found} {break}
				}

				if {!$found} {
					incr words
				}
			}

			# Determinate character type
			set found 0
			set char [string index $line $i]
			foreach tag [$editor tag names $line_num.$i] {
				if {[lsearch $comment_tags $tag] != -1} {
					incr chars_comments
					set found 1
					break
				}
			}

			if {$found} {continue}
			if {[string is wordchar -strict $char]} {
				incr words_and_numbers
			} else {
				incr others
			}
		}

		# Determinate line type excluding empty lines
		if {$last_words == $words && $last_keywords == $keywords && $last_comments < $comments} {
			incr commented_lines
		} else {
			incr normal_lines
		}
	}

	# Composite and return results
	return [list								\
		$words_and_numbers	$chars_comments		$others		\
		[expr {$words_and_numbers + $chars_comments + $others}]		\
										\
		$words			$keywords		$comments	\
		[expr {$words + $keywords + $comments}]				\
										\
		$empty_lines		$commented_lines	$normal_lines	\
		[expr {$empty_lines + $commented_lines + $normal_lines}]	\
	]
}

## Set read only mode
 # @parm Bool mode_frag - 1 == Read only; 0 == Read and write
 # @return Bool - true == ok; false == cannot comply!
public method change_RO_MODE {mode_frag} {
	if {$editor_to_use} {return}
	set ro_mode $mode_frag

	if {!$ro_mode && [$parentObject cget -S_flag_read_only]} {
		tk_messageBox				\
			-parent .			\
			-type ok			\
			-icon warning			\
			-title [mc "Read-only project"]	\
			-message [mc "This project has a special purpose, modifications to this project are not allowed."]
		return 0
	}

	# Set to read only
	if {$ro_mode} {
		$editor configure -state disabled
		$ins_mode_lbl configure		\
			-bg {#DD0000}		\
			-fg {#FFFFFF}		\
			-text [mc " READ ONLY "]\
			-cursor left_ptr
		setStatusTip -widget $ins_mode_lbl \
			-text [mc "This editor is only for reading, to change that press alt+v and o"]
		bind $ins_mode_lbl <Button-1> {}
		set state {disabled}

	# Set to normal mode
	} else {
		$editor configure -state normal
		$ins_mode_lbl configure	\
			-bg {#DDDDDD}	\
			-cursor hand2
		setStatusTip -widget $ins_mode_lbl \
			-text [mc "Insertion mode -- OVR == overwrite; INS == insert"]
		bind $ins_mode_lbl <Button-1> "$this switch_ins_ovr"
		adjust_INS_OVR_label
		set state {normal}
	}

	# Adjust menus and main toolbar
	foreach entry $read_na_only_menu_items {
		$menu entryconfigure [::mc $entry] -state $state
	}
	::X::adjust_mainmenu_and_toolbar_to_editor $ro_mode {}
	return 1
}

## Perform program jump
 # @return void
public method ljmp_this_line {} {
	if {$editor_to_use} {return}
	# Determinate target address
	set address [$parentObject simulator_line2address	\
		[expr {int([$editor index insert])}]		\
		[$parentObject simulator_get_filenumber $fullFileName]	\
	]
	if {$address == {}} {
		return
	}

	# Perform program jump
	$parentObject setPC $address
	set lineNum [$parentObject simulator_getCurrentLine]
	if {$lineNum != {}} {
		$parentObject move_simulator_line $lineNum
	} else {
		$parentObject editor_procedure {} unset_simulator_line {}
	}
	$parentObject Simulator_sync_PC_etc
}

## Perform subprogram call
 # @return void
public method lcall_this_line {} {
	if {$editor_to_use} {return}
	# Determinate target address
	set address [$parentObject simulator_line2address		\
		[expr {int([$editor index insert])}]			\
		[$parentObject simulator_get_filenumber $fullFileName]	\
	]
	if {$address == {}} {
		return
	}

	# Perform subprogram call
	$parentObject simulator_subprog_call $address
	set lineNum [$parentObject simulator_getCurrentLine]
	if {$lineNum != {}} {
		$parentObject move_simulator_line $lineNum
	} else {
		$parentObject editor_procedure {} unset_simulator_line {}
	}
	$parentObject Simulator_sync_PC_etc
}

# >>> File inclusion guard
}
# <<< File inclusion guard

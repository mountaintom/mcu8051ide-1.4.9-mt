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
if { ! [ info exists _R_ASMSYNTAXHIGHLIGHT_TCL ] } {
set _R_ASMSYNTAXHIGHLIGHT_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements syntax highlighting interface for reallocable assembly
# --------------------------------------------------------------------------

namespace eval R_ASMsyntaxHighlight {
	## COMPILER DIRECTIVES
	# directives without arguments
	variable directive_type0 {
		.ELSE .ENDIF .PAGE .EVEN .ODD
	}
	# directives with argument(s) but without any label
	variable directive_type1 {
		.OPTSDCC .WORD .DW .INCLUDE .SETDP .GLOBL .IF .ORG .AREA .MODULE .TITLE
		.SBTTL .ASCII .ASCIS .ASCIZ .RADIX .BYTE .DB .BLKB .BLKW .DS
	}

	# symbol operators
	variable expr_symbols {
		= + - * /  > < % & | % ^
	}

	# control sequencies without any argument
	variable controls_type0 {
		NOLIST NOMOD NOOBJECT NOPAGING NOPRINT
		NOSYMBOLS EJECT LIST PAGING SYMBOLS
	}
	# control sequencies with exactly 1 argument
	variable controls_type1 {
		PAGEWIDTH PAGELENGTH PRINT TITLE OBJECT DATE INCLUDE
	}
	# list of all reserved keywords
	variable keyword_lists [list			\
 		${::ASMsyntaxHighlight::instructions}	\
		$directive_type0 $directive_type1	\
	]

	variable inline_asm		;# Is inline assembler
	variable editor			;# ID of the text widget
	variable lineNumber		;# Number of current line
	variable lineStart		;# Index of line start
	variable lineEnd		;# Index of line end
	variable data			;# Content of the line
	variable data_backup		;# Original content of the line
	variable last_index		;# Last parse index
	variable last_index_backup	;# Auxiliary variable (some index)

	variable seg_0			;# 1st field of the line
	variable seg_1			;# 2nd field of the line
	variable seg_2			;# 3rd field of the line
	variable seg_0_start		;# Start index of seg_0
	variable seg_1_start		;# Start index of seg_1
	variable seg_2_start		;# Start index of seg_2
	variable seg_0_end		;# End index of seg_0
	variable seg_1_end		;# End index of seg_1
	variable seg_2_end		;# End index of seg_2

	variable operand		;# Data of the current operand
	variable opr_end		;# End index of the current operand
	variable opr_start		;# Start index of the current operand

	variable validation_L0	1	;# Bool: Basic validation enabled
	variable validation_L1	1	;# Bool: Advancet validation enabled

	## Define highlighting text tags in the given text widget
	 # @parm Widget text_widget	- ID of the target text widget
	 # @parm Int fontSize		- font size
	 # @parm String fontFamily	- font family
	 # @parm List highlight=default	- Highlighting tags definition
	 # @parm Bool nobold=0		- Ignore bold flag
	 # @return void
	proc create_tags {text_widget fontSize fontFamily {highlight {}} {nobold 0}} {
		# Handle arguments
		if {$highlight == {}} {			;# highlighting definition
			set highlight $::ASMsyntaxHighlight::highlight_tags
		}

		# Iterate over highlighting tags definition
		foreach item $highlight {
			# Create array of tag attributes
			for {set i 0} {$i < 5} {incr i} {
				set tag($i) [lindex $item $i]
			}

			# Foreground color
			if {$tag(1) == {}} {
				set tag(1) black
			}
			# Fonr slant
			if {$tag(3) == 1} {
				set tag(3) italic
			} else {
				set tag(3) roman
			}
			# Font weight
			if {$tag(4) == 1 && !$nobold} {
				set tag(4) bold
			} else {
				set tag(4) normal
			}

			# Create the tag in the target text widget
			$text_widget tag configure $tag(0)	\
				-foreground $tag(1)		\
				-font [font create		\
					-overstrike $tag(2)	\
					-slant $tag(3)		\
					-weight $tag(4)		\
					-size -$fontSize	\
					-family $fontFamily 	\
				]
		}
		# Add tag error
		$text_widget tag configure tag_error -underline 1
	}

	## Perform syntax highlight on the given line in the given widget
	 # @parm Widget p_editor	- Text widget
	 # @parm Int linenumber		- Number of line to highlight
	 # @parm Bool inlineasm=0	- Inline assembler
	 # @parm Int linestart=0	- Start index
	 # @parm Int lineend=end	- End index
	 # @return Bool - result
	proc highlight {p_editor linenumber {inlineasm 0} {linestart {}} {lineend {}}} {
		variable editor		;# ID of the text widget
		variable lineNumber	;# Number of current line
		variable lineStart	;# Index of line start
		variable lineEnd	;# Index of line end
		variable inline_asm	;# Is inline assembler

		variable seg_0	{}	;# 1st field of the line
		variable seg_1	{}	;# 2nd field of the line
		variable seg_2	{}	;# 3rd field of the line
		variable seg_0_start	;# Start index of seg_0
		variable seg_1_start	;# Start index of seg_1
		variable seg_2_start	;# Start index of seg_2
		variable seg_0_end	;# End index of seg_0
		variable seg_1_end	;# End index of seg_1
		variable seg_2_end	;# End index of seg_2

		variable last_index	;# Last parse index
		variable data		;# Content of the line
		variable validation_L0	;# Bool: Basic validation enabled

		# Parse input arguments
		set editor $p_editor
		set lineNumber $linenumber
		set inline_asm $inlineasm
		if {$linestart == {}} {
			set lineStart $lineNumber.0
		} else {
			set lineStart $lineNumber.$linestart
		}
		if {$lineend == {}} {
			set lineEnd [$editor index "$lineStart lineend"]
		} else {
			set lineEnd $lineNumber.$lineEnd
		}
		if {$linestart != {}} {
			set start_offset $linestart
		} else {
			set start_offset 0
		}

		set data [$editor get $lineStart $lineEnd]
		set ::ASMsyntaxHighlight::operands_count 0
		set ::ASMsyntaxHighlight::opr_types {}

		if {$inline_asm} {
			delete_tags
		}

		# check if the line is not empty
		if {[regexp {^\s*$} $data]} {
			return 0
		}
		set line_length [string length $data]
		if {$line_length == 0} {
			return 0
		}

		# determinate comment field and highlight it (the last field)
		set comment_start {}
		if {[regexp {;} $data]} {

			# remove 'string' from the line
			set comment_data [hide_strings $data]

			if {[regexp {;.*$} $comment_data comment_start]} {

				set comment_start [string length $comment_start]
				set comment_start [expr {$line_length - $comment_start}]

				# remove comment and trailing space from the line
				if {$comment_start == 0} {
					set data {}
					delete_tags
				} else {
					set data [string range $data 0 [expr {$comment_start - 1}]]
					regsub {\s+$} $data {} data
				}

				incr comment_start $start_offset
			}
		}

		# Handle line containing only comment
		if {![string length $data]} {
			if {!$inline_asm} {
				delete_tags
			}
			$editor tag add tag_comment $lineNumber.$comment_start $lineEnd
			return 1
		}

		# determinate 1st segment of the line
		regexp {^\s*[^\s:\=]+:?:?} $data seg_0
		set seg_0_end [string length $seg_0]
		regsub {^\s+} $seg_0 {} seg_0

		set seg_0_start [string length $seg_0]
		set seg_0_start [expr {$seg_0_end - $seg_0_start}]

		set data [string replace $data 0 [expr {$seg_0_end - 1}]]
		incr seg_0_end $start_offset
		incr seg_0_start $start_offset
		set last_index $seg_0_end

		#
		# SYNTAX HIGHLIGHT
		#

		# delete existing tags within the line
		if {!$inline_asm} {
			delete_tags
		}

		# highlight comment
		if {$comment_start != {}} {
			$editor tag add tag_comment $lineNumber.$comment_start $lineEnd
		}
		# highlight 1st and 2nd field
		set seg_0_info [parse_segment $seg_0_start $seg_0_end $seg_0]

		# Conditional parsing with validation
		switch -- [lindex $seg_0_info 0] {
			{label}	{
				determinate_segment_1
				set seg_1_info [parse_segment $seg_1_start $seg_1_end $seg_1]
				switch -- [lindex $seg_1_info 0] {
					{label}	{
						put_error_on_segment 1
					}
					{instruction} {
						determinate_segment_2
						parse_operands
					}
					{directive_1} {}
					{directive_0} {}
					{unknown} {
						$editor tag add tag_macro	\
							$lineNumber.$seg_1_start $lineNumber.$seg_1_end
						if {
							$validation_L0 &&
							([regexp {^\d} $seg_1] || ![regexp {^\w+$} $seg_1])
						} then {
							put_error_on_segment 1
						}
						determinate_segment_2
						parse_operands
					}
					default {
						put_error_on_segment 1
					}
				}
			}
			{instruction} {
				determinate_segment_2
				parse_operands
			}
			{directive_1} {
				determinate_segment_2
				if {[string tolower $seg_0] == {.optsdcc}} {
					$editor tag add tag_string $lineNumber.$seg_0_end $lineEnd
				} else {
					parse_expressions
				}
			}
			{directive_0} {
				determinate_segment_1
				put_error_on_segment 1
				determinate_segment_2
				put_error_on_segment 2
			}
			{unknown} {
				determinate_segment_1
				set seg_1_info [parse_segment $seg_1_start $seg_1_end $seg_1]
				switch -- [lindex $seg_1_info 0] {
					{label}	{
						put_error_on_segment 0
					}
					{instruction} {
						put_error_on_segment 0
						determinate_segment_2
						parse_operands
					}
					{directive_1} {
						put_error_on_segment 0
						determinate_segment_2
						parse_expressions
					}
					{directive_0} {
						put_error_on_segment 0
						determinate_segment_2
						put_error_on_segment 2
					}
					{unknown} {
					}
					{assignment} {
						determinate_segment_2
						incr seg_0_start -1
						parse_expressions
						$editor tag add tag_constant $lineNumber.$seg_0_start $lineNumber.$seg_0_end
					}
					default {
					}
				}
			}
			default {}
		}

		return 1
	}

	## Remove previously defined syntax highlighting tags
	 # @return void
	proc delete_tags {} {
		variable editor			;# ID of the text widget
		variable lineStart		;# Index of line start
		variable lineEnd		;# Index of line end

		set lineStart_truestart [$editor index [list $lineStart linestart]]

		# Remove tag error
		$editor tag remove tag_error $lineStart_truestart $lineEnd

		# Remove tags according to pattern
		foreach tag $::ASMsyntaxHighlight::highlight_tags {
			$editor tag remove [lindex $tag 0] $lineStart_truestart $lineEnd
		}
	}

	## Take back extraction of segment 1
	 # @return void
	proc determinate_segment_1_take_back {} {
		variable data			;# Content of the line
		variable data_backup		;# Original content of the line
		variable last_index		;# Last parse index
		variable last_index_backup	;# Auxiliary variable (some index)

		set data $data_backup
		set last_index $last_index_backup
	}

	## Extract segment 1 from the line
	 # @return void
	proc determinate_segment_1 {} {
		variable seg_1			;# 2nd field of the line
		variable seg_1_start		;# Start index of seg_1
		variable seg_1_end		;# End index of seg_1
		variable last_index		;# Last parse index
		variable data			;# Content of the line
		variable data_backup		;# Original content of the line
		variable last_index_backup	;# Auxiliary variable (some index)

		# Line is empty
		if {![regexp {^\s*[^\s\.]+} $data seg_1]} {
			set seg_1 {}
			set seg_1_end $last_index
			set seg_1_start $last_index

		# Line is not empty
		} else {
			set data_backup $data
			set last_index_backup $last_index

			set seg_1_end [string length $seg_1]
			set data [string replace $data 0 $seg_1_end]
			incr seg_1_end $last_index

			regsub {^\s+} $seg_1 {} seg_1
			set seg_1_start [string length $seg_1]
			set seg_1_start [expr {$seg_1_end - $seg_1_start}]

			set last_index $seg_1_end
			incr last_index
		}
	}

	## Extract segment 2 from the line
	 # @return void
	proc determinate_segment_2 {} {
		variable seg_2		;# 3rd field of the line
		variable seg_2_start	;# Start index of seg_2
		variable seg_2_end	;# End index of seg_2
		variable last_index	;# Last parse index
		variable data		;# Content of the line

		# determinate the last segment of the line
		set seg_2_start $last_index
		if {[regexp {^\s+} $data space]} {
			incr seg_2_start [string length $space]
		}
		regsub {^\s+} $data {} seg_2
		regsub {\s+$} $seg_2 {} seg_2
		set seg_2_end [string length $seg_2]
		incr seg_2_end $last_index
		set data {}
	}

	## Shorthand for 'parse_expression $seg_2 $seg_2_start $seg_2_end'
	 # @return void
	proc parse_expressions {} {
		variable seg_2		;# 3rd field of the line
		variable seg_2_start	;# Start index of seg_2
		variable seg_2_end	;# End index of seg_2

		parse_expression $seg_2 $seg_2_start $seg_2_end
	}

	## Parse given segment, highlight it and determinate its type
	 # @parm Int start		- start column
	 # @parm int end		- end column
	 # @parm String segment_data	- content of segment to parse
	 # @return List - {segment_type expression_length} or {segment_type {}} or {{} {}}
	proc parse_segment {start end segment_data} {
		variable controls_type0		;# control sequencies without any argument
		variable controls_type1		;# control sequencies with exactly 1 argument

		variable inline_asm		;# Is inline assembler
		variable keyword_lists		;# list of all reserved keywords
		variable editor			;# ID of the text widget
		variable lineNumber		;# Number of current line
		variable lineStart		;# Index of line start
		variable lineEnd		;# Index of line end
		variable data			;# Content of the line
		variable validation_L0		;# Bool: Basic validation enabled

		# Local variables
		set seg_type {}		;# segment type
		set expr_len 0		;# length of expression

		# Handle empty segments
		if {$segment_data == {}} {
			return "$seg_type $expr_len"
		}

		# Convert segment data to uppre case (patterns are uppper-case)
		set segment_data [string toupper $segment_data]

		# Try to determinate segment type and perform highlight
		foreach	keyword_list	$keyword_lists \
			tag		{tag_instruction tag_directive tag_directive} \
			type		{instruction directive_0 directive_1} {
			if {[lsearch -ascii -exact $keyword_list $segment_data] != -1} {
				$editor tag add $tag $lineNumber.$start $lineNumber.$end
				set seg_type $type
				break
			}
		}

		if {$seg_type == {}} {
			if {[regexp -nocase {^[^\s]+\:\:?$} $segment_data]} {
				$editor tag add tag_label $lineNumber.$start $lineNumber.$end
				set seg_type label
			} elseif {$segment_data == {=} || $segment_data == {==}} {
				$editor tag add tag_symbol $lineNumber.$start $lineNumber.$end
				set seg_type {assignment}
			} else {
				set seg_type {unknown}
			}
		}

		# Return result
		return "$seg_type $expr_len"
	}

	## Tag the given segment as error
	 # @parm Int segment_number - number of the target segment
	 # @return void
	proc put_error_on_segment {segment_number} {
		variable editor		;# ID of the text widget
		variable lineNumber	;# Number of current line
		variable validation_L0	;# Bool: Basic validation enabled
		variable seg_0_start	;# Start index of seg_0
		variable seg_1_start	;# Start index of seg_1
		variable seg_2_start	;# Start index of seg_2
		variable seg_0_end	;# End index of seg_0
		variable seg_1_end	;# End index of seg_1
		variable seg_2_end	;# End index of seg_2

		return

		if {!$validation_L0} {
			return
		}

		# Determinate start and end index
		switch -- $segment_number {
			0 {
				set start $seg_0_start
				set end $seg_0_end
			}
			1 {
				set start $seg_1_start
				set end $seg_1_end
			}
			2 {
				set start $seg_2_start
				set end $seg_2_end
			}
		}
	}

	## Parse attributes in defintion of macro instruction
	 # @retunr void
	proc parse_arguments {} {
		variable editor			;# ID of the text widget
		variable lineNumber		;# Number of current line
		variable seg_2_start		;# Start index of seg_2
		variable seg_2			;# 3rd field of the line
		variable validation_L0		;# Bool: Basic validation enabled

		if {[regexp {^\s*$} $seg_2]} {return 0}

		while {1} {
			# Handle redutant commas
			while {1} {
				if {![regexp {^\s*\,} $seg_2]} {break}

				set space_len 0
				if {[regexp {^\s+} $seg_2 space_len]} {
					set space_len [string length $space_len]
				}

				incr seg_2_start $space_len
				set seg_2		[string range $seg_2 [expr {$space_len + 1}] end]

				$editor tag add tag_oper_sep		\
					$lineNumber.$seg_2_start	\
					$lineNumber.[expr {$seg_2_start + 1}]

				incr seg_2_start
			}

			# Determinate argument
			if {![regexp {^[^\,]+} $seg_2 argument]} {break}
			set argument_len_org	[string length $argument]
			set seg_2		[string range $seg_2 $argument_len_org end]
			set argument		[string trimleft $argument]
			set argument_len	[string length $argument]
			incr seg_2_start	[expr {$argument_len_org - $argument_len}]

			# Highlight argument
			$editor tag add tag_constant		\
				$lineNumber.$seg_2_start	\
				$lineNumber.[expr {$seg_2_start + $argument_len}]
			set argument [string trimright $argument]

			incr seg_2_start $argument_len

			# highlight argument separator
			if {[string index $seg_2 0] == {,}} {
				set sep_end $seg_2_start
				incr sep_end
				$editor tag add tag_oper_sep $lineNumber.$seg_2_start $lineNumber.$sep_end

				incr seg_2_start
				set seg_2 [string range $seg_2 1 end]
			}
		}
	}

	## Highlight all operands (segment 2) and their separators
	 # @return void
	proc parse_operands {} {

		variable editor			;# ID of the text widget
		variable lineNumber		;# Number of current line
		variable seg_2_start		;# Start index of seg_2
		variable seg_2			;# 3rd field of the line

		variable operand		;# Data of the current operand
		variable opr_end		;# End index of the current operand
		variable opr_start		;# Start index of the current operand

		variable validation_L0		;# Bool: Basic validation enabled
		variable validation_L1		;# Bool: Advancet validation enabled

		if {[regexp {^\s*$} $seg_2]} {return 0}
		set ::ASMsyntaxHighlight::operands_count 0
		set ::ASMsyntaxHighlight::opr_types {}

		# split data into single operands
		set i 0
		set last_index $seg_2_start
		set original_data $seg_2
		set data [hide_strings $seg_2]

		while {1} {
			# Handle redutant commas
			while {1} {
				if {![regexp {^\s*\,} $data]} {break}

				set space_len 0
				if {[regexp {^\s+} $data space_len]} {
					set space_len [string length $space_len]
				}
				incr last_index $space_len

				set data		[string range $data [expr {$space_len + 1}] end]
				set original_data	[string range $original_data [expr {$space_len + 1}] end]

				$editor tag add tag_oper_sep	\
					$lineNumber.$last_index	\
					$lineNumber.[expr {$last_index + 1}]

				incr last_index
			}

			# gain operand data
			if {![regexp {^[^\,]+} $data operand]} {break}
			set operand_len		[string length $operand]
			set data		[string range $data $operand_len end]
			set operand		[string range $original_data 0 [expr {$operand_len - 1}]]
			set original_data	[string range $original_data $operand_len end]

			# determinate start index
			if {[regexp {^\s+} $operand space]} {
				set space_len	[string length $space]
				set opr_start	[expr {$last_index + $space_len}]
				set operand	[string range $operand $space_len end]
			} else {
				set opr_start $last_index
			}

			# determinate end index
			if {[regexp {\s+$} $operand space]} {
				set space_len	[string length $space]
				set opr_end	[expr {$operand_len - $space_len}]
				set operand	[string range $operand 0 $opr_end]
			} else {
				set opr_end $operand_len
			}
			incr opr_end $last_index
			incr last_index $operand_len

			set operand [string trimright $operand "\t "]
			if {$validation_L1} {
				add_aperand_to__opr_types
			}
			highlight_operand
			incr ::ASMsyntaxHighlight::operands_count

			# highlight operand separator
			if {[string index $data 0] == {,}} {
				set sep_end $last_index
				incr sep_end
				$editor tag add tag_oper_sep $lineNumber.$last_index $lineNumber.$sep_end

				incr last_index
				set data [string range $data 1 end]
				set original_data [string range $original_data 1 end]
			}

			incr i
		}
	}

	## Append current operand (variable operand) to list of operand types in ::ASMsyntaxHighlight::opr_types
	 # Purpose of this function is to enable searching in instruction
	 #+ details panel while this syntaxt highlight pattern is used
	 # @return void
	proc add_aperand_to__opr_types {} {
		variable operand	;# Data of the current operand

		set opr [string toupper $operand]

		switch -- [string index $opr 0] {
			{#}	{lappend ::ASMsyntaxHighlight::opr_types {#}}
			{/}	{lappend ::ASMsyntaxHighlight::opr_types {/}}
			{@}	{lappend ::ASMsyntaxHighlight::opr_types $opr}
			default	{
				if {[lsearch -ascii -exact {R0 R1 R2 R3 R4 R5 R6 R7 DPTR A AB C} $opr] != -1} {
					lappend ::ASMsyntaxHighlight::opr_types $opr
				} else {
					lappend ::ASMsyntaxHighlight::opr_types {D}
				}
			}
		}
	}

	## Highlight current operand
	 # @return void
	proc highlight_operand {} {
		variable editor		;# ID of the text widget
		variable operand	;# Data of the current operand
		variable opr_end	;# End index of the current operand
		variable opr_start	;# Start index of the current operand
		variable validation_L0	;# Bool: Basic validation enabled
		variable inline_asm	;# Is inline assembler
		variable lineNumber	;# Number of current line

		## Determinate addressing type
		set addr_type [string index $operand 0]

		# Immediate adresing
		if {$addr_type == {#}} {
			set operand [string range $operand 1 end]

			# Immediate char value
			if {[string index $operand 0] == {'} && [string index $operand end] == {'}} {
				set len [string length $operand]

				if {$len > 3} {
					put_tag_on_operand tag_string
				} else {
					put_tag_on_operand tag_imm_char
				}

			# Label in inline assembler
			} elseif {[regexp {^\d+\$$} $operand]} {
				put_tag_on_operand tag_imm_constant

			# Operand has no value => incorrect operand
			} elseif {[regexp { |\(|\)|\+|\-|\%|\=|\>|\<|\*|\/} $operand]} {
				parse_expression $operand $opr_start $opr_end
				$editor tag add tag_symbol	\
					$lineNumber.$opr_start $lineNumber.$opr_start+1c

			} elseif {
					$validation_L0 &&
					([string length $operand] == 0 || ![regexp {^[\w\.\\]+$} $operand])
				} then {
# 					put_tag_on_operand tag_error

			# Operand value determinated successfully
			} else {
				parse_operand_auxiliary2 {
					tag_imm_unknown		tag_imm_hex	tag_imm_dec
					tag_imm_oct		tag_imm_bin	tag_imm_char
					tag_imm_constant	tag_string
				}
			}

		# Indirect adresing
		} elseif {$addr_type == {@}} {
			set operand [string range $operand 1 end]
			put_tag_on_operand tag_indirect

			# Check for operand validity
			if {!$validation_L0} {return}
			set operand [string toupper $operand]

		# Direct bit adresing
		} elseif {$addr_type == {/}} {
			set operand [string range $operand 1 end]

			if {[regexp {\(|\)|\+|\-|\%|\=|\>|\<|\*|\/} $operand]} {
				parse_expression $operand $opr_start $opr_end
				$editor tag add tag_symbol	\
					$lineNumber.$opr_start $lineNumber.$opr_start+1c

			} elseif {
				$validation_L0 &&
				([string length $operand] == 0 || ![regexp {^'?[\w\.]+'?$} $operand])
			} then {
				# Operand has no value => incorrect operand
# 				put_tag_on_operand tag_error

			} else {
				parse_operand_auxiliary $::ASMsyntaxHighlight::spec_bits {
					tag_unknown_base	tag_hex		tag_dec
					tag_oct			tag_bin		tag_char
					tag_constant		tag_string
				}
			}

		# Another kind of direct adresing
		} else {
			parse_operand_auxiliary $::ASMsyntaxHighlight::spec_registers {
				tag_unknown_base	tag_hex		tag_dec
				tag_oct			tag_bin		tag_char
				tag_constant		tag_string
			}
		}
	}

	## Auxiliary procedure for procedure highlight_operand
	 # @parm List SFR_set	- List of SFR keywords
	 # @parm List tag_list	- List of tags for procedure parse_operand_auxiliary2
	 # @return void
	proc parse_operand_auxiliary {SFR_set tag_list} {
		variable operand	;# Data of the current operand

		# SFR
		if {[lsearch -ascii -exact $SFR_set [string toupper $operand]] != -1} {
			put_tag_on_operand tag_sfr

		# Something else than SFR
		} else {
			parse_operand_auxiliary2 $tag_list
		}
	}

	## Auxiliary procedure for procedures highlight_operand and parse_operand_auxiliary
	 # @parm List tag_list - list of text tags (see code)
	 # @return void
	proc parse_operand_auxiliary2 {tag_list} {
		variable operand	;# Data of the current operand
		variable opr_start	;# Start index of the current operand
		variable opr_end	;# End index of the current operand
		variable editor		;# ID of the text widget
		variable lineNumber	;# Number of current line
		variable validation_L0	;# Bool: Basic validation enabled
		variable inline_asm	;# Is inline assembler

		# Label
		if {[regexp {^\d+\$$} $operand]} {
			put_tag_on_operand [lindex $tag_list 6]

		# Expression
		} elseif {[regexp {\(|\)|\+|\-|\%|\=|\>|\<|\*|\/} $operand]} {
			parse_expression $operand $opr_start $opr_end

		# Dot notation (bit addressing)
		} elseif {[regexp {^\w+\.\w+$} $operand]} {
			set opr [split $operand {.}]
			set operand [lindex $opr 0]

			set opr_true_end $opr_end
			set opr_end $opr_start
			incr opr_end [string length $operand]

			parse_operand_auxiliary $::ASMsyntaxHighlight::spec_registers $tag_list

			set opr_start [expr {$opr_end + 1}]
			$editor tag add tag_symbol $lineNumber.$opr_end $lineNumber.$opr_start

			set opr_end $opr_true_end
			set operand [lindex $opr 1]

			parse_operand_auxiliary2 $tag_list

		# Direct value
		} elseif {[regexp {^(\d|')} $operand]} {
			# gain information about the openand (radix and decimal value)
			set opr_info [which_radix 0 $operand]
			set opr_base [lindex $opr_info 0]
			set opr_in_dec [lindex $opr_info 1]

			# Radix determinated incorrectly => unknown number
			if {$opr_base == {}} {
				put_tag_on_operand [lindex $tag_list 0]

			# Radix determinated correctly - continue normaly
			} else {
				# highlight according to numeric base
				switch -- $opr_base {
					{hex} 		{put_tag_on_operand [lindex $tag_list 1]}
					{dec} 		{put_tag_on_operand [lindex $tag_list 2]}
					{oct} 		{put_tag_on_operand [lindex $tag_list 3]}
					{bin} 		{put_tag_on_operand [lindex $tag_list 4]}
					{ascii} 	{put_tag_on_operand [lindex $tag_list 5]}
					{string} 	{put_tag_on_operand [lindex $tag_list 7]}
				}
			}

		# defined by a symbolic name
		} else {
			put_tag_on_operand [lindex $tag_list 6]
		}
	}

	## Highlight current operand by the given tag
	 # @parm String tag_name - tag name
	 # @return void
	proc put_tag_on_operand {tag_name} {
		variable lineNumber	;# Number of current line
		variable opr_end	;# End index of the current operand
		variable opr_start	;# Start index of the current operand
		variable editor		;# ID of the text widget

		$editor tag add $tag_name $lineNumber.$opr_start $lineNumber.$opr_end
	}

	## Determinate numeric base of the given number
	 # @parm Bool norange	- 1 == determinate decimal value (sometimes...) and validate it (see code)
	 # @parm String number	- number to analyze
	 # @return List - {base decimal_value} or {base "error"}
	proc which_radix {norange number} {
		set original_len [string length $number]
		set len [string length [string trimleft $number {0}]]
		if {$original_len > 1 && $len == 1} {
			incr len
		}
		incr len -1
		set radix [string index $number end]
		set number [string range $number 0 {end-1}]
		set dec_val error
		set base {}

		# Character or string
		if {$radix == {'}} {
			if {[string index $number 0] == {'}} {
				set number [string range $number 1 end]

				set base ascii
				if {[string length $number] == 1} {
					set dec_val 0

				} elseif {[string length $number] > 1} {
					set base string
					set dec_val 0
				}
			}

		# Prefix hexadecimal notation
		} elseif {[string range $number 0 1] == {0x} || [string range $number 0 1] == {0X}} {
			append number $radix
			set base hex
			if {[regexp {^0[Xx][A-Fa-f0-9]+$} $number]} {
				set dec_val 0
			}

		# Regular numbers
		} else {
			set radix [string tolower $radix]
			switch -- $radix {
				{h} {	;# Hexadecimal
					set base hex
					if {$norange || ($len <= 4 && $len >= 1)} {
						if {[regexp {^[A-Fa-f0-9]*$} $number]} {
							set dec_val 0
						}
					}
				}
				{d} {	;# Decimal
					set base dec
					if {$norange || ($len <= 5 && $len >= 1)} {
						if {[regexp {^[0-9]*$} $number]} {
							set dec_val $number
						}
					}
				}
				{o} {	;# Octal
					set base oct
					if {$norange} {
						if {[regexp {^[0-7]*$} $number]} {
							set dec_val 0
						}
					} elseif {$len <= 6 && $len >= 1} {
						if {[regexp {^[0-7]*$} $number]} {
							if {$len != 3} {
								set dec_val 0
							} else {
								if {[string index $number 0] <= 3} {
									set dec_val 0
								}
							}
						}
					}
				}
				{q} {	;# Octal
					set base oct
					if {$norange} {
						if {[regexp {^[0-7]*$} $number]} {
							set dec_val 0
						}
					} elseif {$len <= 6 && $len >= 1} {
						if {[regexp {^[0-7]*$} $number]} {
							if {$len != 3} {
								set dec_val 0
							} else {
								if {[string index $number 0] <= 3} {
									set dec_val 0
								}
							}
						}
					}
				}
				{b} {	;# Binary
					set base bin
					if {$norange || ($len <= 16 && $len >= 1)} {
						if {[regexp {^[01]*$} $number]} {
							set dec_val 0
						}
					}
				}
				default {	;# Default
					set dec_val {}
				}
			}
		}

		# done ...
		return [list $base $dec_val]
	}

	## Highlight expressions (eg. '( 10d - X MOD 55h)')
	 # @parm String data		- expression to highlight
	 # @parm Int start_index	- expresssion start index
	 # @parm Int end_index		- expresssion end index
	 # @return void
	proc parse_expression {data start_index end_index} {
		variable editor			;# ID of the text widget
		variable lineNumber		;# Number of current line
		variable expr_symbols		;# symbol operators
		variable validation_L0		;# Bool: Basic validation enabled
		variable validation_L1		;# Bool: Advancet validation enabled

		# Adjust data to fit the given boundaries
		set data_len [string length $data]
		set dif [expr {$end_index - $start_index - $data_len}]
		if {$dif != 0} {
			set space [string repeat { } $dif]
			set data $space$data
		}

		# Remove strings
		set e_idx 0
		while {1} {
			if {![regexp -start $e_idx -- {'[^']*'} $data string_data]} {
				break
			}
			set len		[string length $string_data]
			set s_idx	[string first {'} $data $e_idx]
			set e_idx	[expr {$s_idx + $len}]

			if {$len > 2} {
				set data [string replace $data			\
					[expr {$s_idx + 1}] [expr {$e_idx - 2}]	\
					[string repeat { } [expr {$len - 2}]]	\
				]
			}
		}

		# remove and highlight '('
		set opened_par 0
		while {1} {
			set symbol_idx [string first {(} $data]
			if {$symbol_idx == -1} {break}

			incr opened_par
			set data [string replace $data $symbol_idx $symbol_idx { }]
			incr symbol_idx $start_index
			$editor tag add tag_symbol $lineNumber.$symbol_idx $lineNumber.[expr {$symbol_idx + 1}]
		}
		# remove and highlight ')'
		while {1} {
			set symbol_idx [string first {)} $data]
			if {$symbol_idx == -1} {break}

			incr opened_par -1
			set data [string replace $data $symbol_idx $symbol_idx { }]
			incr symbol_idx $start_index
			$editor tag add tag_symbol $lineNumber.$symbol_idx $lineNumber.[expr {$symbol_idx + 1}]
		}

		# highlight expr. symbols (+1 chars) and remove them from the string
		set adjusted_data [string toupper $data]
		regsub {\t} $adjusted_data { } adjusted_data
		# highlight expr. symbols (1 char) and remove them from the string
		foreach symbol $expr_symbols {
			while {1} {
				set symbol_idx [string first $symbol $data]
				if {$symbol_idx == -1} {break}
				set original_symbol_idx $symbol_idx
				set symbol_idx_org_1 [expr {$symbol_idx + 1}]

				set data [string replace $data $symbol_idx $symbol_idx { }]
				incr symbol_idx $start_index
				set symbol_idx_1 [expr {$symbol_idx + 1}]
				$editor tag add tag_symbol $lineNumber.$symbol_idx $lineNumber.$symbol_idx_1
			}
		}

		# highlight other parts
		set last_index $start_index
		set original_data $data
		set data [hide_strings $data]
		while {1} {
			if {![regexp {[^\s]+} $data value]} {break}

			set value_S_idx [string first $value $data]
			set value_len [string length $value]
			set value_E_idx $value_len
			incr value_E_idx $value_S_idx

			set value [string range $original_data $value_S_idx $value_E_idx]

			set data [string range $data $value_E_idx end]
			set original_data [string range $original_data $value_E_idx end]

			set tmp_idx $value_E_idx
			incr value_S_idx $last_index
			incr value_E_idx $last_index
			incr last_index $tmp_idx

			highlight_value [string trimright $value] $value_S_idx $value_E_idx
		}
	}

	## Highlight constant values
	 # @parm String data		- string to highlight
	 # @parm Int start_index	- start index
	 # @parm Int end_index		- end index
	 # @return void
	proc highlight_value {data start_index end_index} {
		variable editor		;# ID of the text widget
		variable lineNumber	;# Number of current line
		variable validation_L0	;# Bool: Basic validation enabled

		# Dot notation -- bit addressing
		if {[regexp {^\w+\.\w+$} $data]} {
			set data [split $data {.}]

			set end_index_org $end_index
			set end_index $start_index
			incr end_index [string length [lindex $data 0]]
			highlight_value [lindex $data 0] $start_index $end_index

			$editor tag add tag_symbol $lineNumber.$end_index $lineNumber.[expr {$end_index + 1}]

			incr end_index
			highlight_value [lindex $data 1] $end_index $end_index_org
			return

		} elseif {[regexp {^(\d|')} $data]} {
			# Gain information about the value
			set opr_info [which_radix 1 $data]
			set opr_base [lindex $opr_info 0]
			set opr_in_dec [lindex $opr_info 1]

			# Highlight value according to info
			if {$opr_base == {}} {
				$editor tag add tag_unknown_base $lineNumber.$start_index $lineNumber.$end_index
				return
			}

			# Highlight according to numeric base
			switch -- $opr_base {
				{hex} { 	;# Hexadecimal
					$editor tag add tag_hex $lineNumber.$start_index $lineNumber.$end_index
				}
				{dec} { 	;# Decimal
					$editor tag add tag_dec $lineNumber.$start_index $lineNumber.$end_index
				}
				{oct} { 	;# Octal
					$editor tag add tag_oct $lineNumber.$start_index $lineNumber.$end_index
				}
				{bin} { 	;# Binary
					$editor tag add tag_bin $lineNumber.$start_index $lineNumber.$end_index
				}
				{ascii} { 	;# Char
					$editor tag add tag_char $lineNumber.$start_index $lineNumber.$end_index
				}
				{string} { 	;# String
					$editor tag add tag_string $lineNumber.$start_index $lineNumber.$end_index
				}
			}
			return
		}

		# Constant
		$editor tag add tag_constant $lineNumber.$start_index $lineNumber.$end_index
	}

	## Replace all single quoted string with underscores (''abc'' -> '_____')
	 # @parm String data - input data
	 # @return String - output data
	proc hide_strings {data} {
		# Return string which dowsn't contain '''
		if {[string first {'} $data] == -1} {return $data}

		# Perform replacement
		while {1} {
			if {![regexp {'[^']*'} $data string]} {
				break
			}
			regsub {'[^']*'} $data [string repeat {_}	\
					[string length $string]		\
				] data
		}

		# Return result
		return $data
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

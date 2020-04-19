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
if { ! [ info exists _LSTSYNTAXHIGHLIGHT_TCL ] } {
set _LSTSYNTAXHIGHLIGHT_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements syntax highlighting interface for code listing
# --------------------------------------------------------------------------


namespace eval LSTsyntaxHighlight {

	## Highlight pattern - highlight tags definition
	 # {
	 #	{tag_name ?foreground? ?overstrike? ?italic? ?bold?}
	 # }
	variable highlight_tags	{
		{tag_lst_number		#000000	0 0 1}
		{tag_lst_code		#000000	0 0 1}
		{tag_lst_address	#000000	0 0 1}
		{tag_lst_line		#000000	0 0 1}
		{tag_lst_macro		#888888	0 0 0}
		{tag_lst_include	#888888	0 0 0}
		{tag_lst_error		#FF0000	0 0 1}
		{tag_lst_msg		#000000	0 0 1}
	}

	# Fixed messages
	variable const_messages {
		{SYMBOL				  TYPE     VALUE	LINE}
		{------------------------------------------------------------}
		{ Line  I  Addr  Code            Source}
		{	       L I S T   O F   S Y M B O L S}
		{	       =============================}
		{       =====================================================}
	}
	# Fixed messages with unknown end
	variable half_cont_msg {
		{       MCS-51 Family Macro Assembler   A S E M - 5 1}
		{	Source File:}
		{	Object File:}
		{	List File:}
		{                     register banks used:}
		{ASSEMBLY COMPLETE,}
		{ERROR SUMMARY:}
		{SYMBOL TABLE:}
		{ASEM-51}
	}

	variable editor		;# Widget: Editor text widget
	variable line_number	;# Int: Line number
	variable line_content	;# String: Line content
	variable line_start	;# Index of line start
	variable line_end	;# Index of line end


	## Define highlighting text tags in the given text widget
	 # @parm Widget text_widget	- ID of the target text widget
	 # @parm Int fontSize		- font size
	 # @parm String fontFamily	- font family
	 # @parm List highlight=default	- Highlighting tags definition
	 # @parm Bool nobold=0		- Ignore bold flag
	 # @return void
	proc create_tags {text_widget fontSize fontFamily {highlight {}} {nobold 0}} {
		variable highlight_tags	;# Highlight tags definition

		# Handle arguments
		if {$highlight == {}} {		;# highlighting definition
			set highlight $highlight_tags
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
				-font [ font create		\
					-overstrike $tag(2)	\
					-slant $tag(3)		\
					-weight $tag(4)		\
					-size -$fontSize	\
					-family $fontFamily 	\
				]
		}
	}

	## Perform syntax highlight on the given line in the given widget
	 # @parm Widget Editor	- Text widget
	 # @parm Int LineNumber	- Number of line to highlight
	 # @return Bool - result
	proc highlight {Editor LineNumber} {
		variable editor			;# Widget: Editor text widget
		variable line_number		;# Int: Line number
		variable line_content		;# String: Line content
		variable line_start		;# Index of line start
		variable line_end		;# Index of line end
		variable const_messages		;# Fixed messages
		variable half_cont_msg		;# Fixed messages with unknown end

		# Set NS variables
		set editor	$Editor
		set line_number	$LineNumber
		set line_start	$line_number.0
		set line_end	[$editor index [list $line_number.0 lineend]]
		set line_content [$editor get $line_start $line_end]

		# Remove current highlighting tags
		if {[string length [string trim $line_content]]} {
			delete_tags
		} else {
			return 0
		}

		# Search for constant messages
		if {[lsearch -ascii -exact $const_messages $line_content] != -1} {
			$editor tag add tag_lst_msg $line_start $line_end
			return 1
		}
		foreach msg $half_cont_msg {
			set idx [string first $msg $line_content]
			set len [string length $msg]
			if {!$idx} {
				$editor tag add tag_lst_msg $line_start $line_number.$len
				return 1
			}
		}

		# Search for error/warning messages
		if {[regexp {^(\s+@@@@@)|^(\*\*\*\*)|^(\s+\^)} $line_content]} {
			$editor tag add tag_lst_error $line_start $line_end
		}

		# Apply some rules, except for AS31
		if {${::ExternalCompiler::selected_assembler} != 3} {
			# Line must start eiter with a digit or equation mark
			if {![regexp {^\s*\=?[[:xdigit:]]} $line_content]} {
				return 0
			}
			if {[regexp {^\s+\d+ error detected} $line_content]} {
				return 0
			}
			# Don't highlight lines in symbol table
			if {[regexp {^\w+\s?\.} $line_content] || [regexp {^[\w\?]+\t} $line_content]} {
				return 0
			}
		}

		# AS31
		if {${::ExternalCompiler::selected_assembler} == 3} {
			set asm_start_index 19
			as31_highlight 19

		# ASEM-51
		} elseif {
			[regexp {^\s*\d+(\:|\+)} $line_content] ||
			[regexp {^(\t  )|(      [\d ]\d  )[[:xdigit:]]{4}} $line_content]
		} then {
			# Determinate ASM code start index
			set lineText $line_content
			set asm_start_index 33
			set idx -1
			set cor 0
			while {1} {
				set idx [string first "\t" $lineText [expr {$idx + 1}]]
				if {$idx == -1} {break}

				incr cor [expr {8 - (($idx + $cor) % 8)}]
				if {$idx + $cor >= 32} {
					break
				}
			}
			incr asm_start_index -$cor

			# Highlight
			asem_51_highlight $asm_start_index

		# SDCC assembler -- ASX8051
		} elseif {[string is digit -strict [string index $line_content 30]]} {
			sdcc_highlight 32
			::R_ASMsyntaxHighlight::highlight $editor $line_number 1 32
			return 1

		# MCU 8051 IDE Assembler
		} else {
			set asm_start_index 31
			mcu8051ide_highlight $asm_start_index
		}

		# Highlight remaining assembly code
		::ASMsyntaxHighlight::highlight $editor $line_number 1 $asm_start_index

		# Make sure there are no ASM error tags, they don't make sense here
		$editor tag remove tag_error $line_number.$asm_start_index $line_end

		return 1
	}

	## Remove previously put syntax highlighting tags
	 # @return void
	proc delete_tags {} {
		variable highlight_tags	;# Highlight tags definition
		variable editor			;# Widget: Editor text widget
		variable line_start		;# Index of line start
		variable line_end		;# Index of line end

		# Remove tags according to pattern
		foreach tag $highlight_tags {
			$editor tag remove [lindex $tag 0] $line_start $line_end
		}
	}

	## Highlight AS31 code listing line
	 # @parm Int asm_start_index - Assembly code start index
	 # @return void
	proc as31_highlight {asm_start_index} {
		variable editor		;# Widget: Editor text widget
		variable line_number	;# Int: Line number
		variable line_content	;# String: Line content
		variable line_start	;# Index of line start
		variable line_end	;# Index of line end

		set idx 0	;# Regular expression match start index

		# Alter line
		set line_content [string range $line_content 0 [expr {$asm_start_index - 1}]]

		# Address field present
		if {[regexp -start $idx -- {\A[[:xdigit:]]{4}\:} $line_content substring]} {
			# Highlight address
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_address $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len
		}

		# Highlight processor code
		if {[regexp -start $idx -- {\A\s+([[:xdigit:]]{2} )*[[:xdigit:]]{2}} $line_content substring]} {
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_code $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len
		}
	}

	## Highlight ASEM-51 code listing line
	 # @parm Int asm_start_index - Assembly code start index
	 # @return void
	proc asem_51_highlight {asm_start_index} {
		variable editor		;# Widget: Editor text widget
		variable line_number	;# Int: Line number
		variable line_content	;# String: Line content
		variable line_start	;# Index of line start
		variable line_end	;# Index of line end

		set idx 0	;# Regular expression match start index
		set foo 0	;# Foo :)

		# Alter line
		set line_content [string range $line_content 0 [expr {$asm_start_index - 1}]]

		# Highlight for LST line number
		if {[regexp -start $idx -- {\A\s*\d+[\:\+]} $line_content substring]} {
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_line $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len
		} else {
			set idx 6
			set foo 1
		}

		# Highlight for inclusion level
		if {[regexp -start $idx -- {\A[ \d]\d} $line_content substring]} {
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_include $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len

		} elseif {$idx == 6 && $foo} {
			set idx 0
		}

		## Address field present
		if {[regexp -start $idx -- {\A\s*[[:xdigit:]]{2,4}} $line_content substring]} {
			# Highlight address
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_address $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len
		}

		## Constant definition
		if {[regexp -start $idx -- {\A\s*[NBCDX]} $line_content substring]} {
			# Highlight letter 'N', 'B', etc. as processor code
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_code $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len

			# Highlight value of defined constant
			if {[regexp -start $idx -- {\A\s+[[:xdigit:]]{2,4}} $line_content substring]} {
				set substr_len [string length $substring]
				set idx [string first $substring $line_content $idx]
				$editor tag add tag_lst_number $line_number.$idx $line_number.[expr {$idx + $substr_len}]
				incr idx $substr_len
			}

		# Highlight processor code
		} elseif {[regexp -start $idx -- {\A\s+([[:xdigit:]]{2} )*[[:xdigit:]]{2}} $line_content substring]} {
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_code $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len
		}
	}

	## Highlight SDCC ASX8051 Assembler code listing line
	 # @parm Int asm_start_index - Assembly code start index
	 # @return void
	proc sdcc_highlight {asm_start_index} {
		variable editor		;# Widget: Editor text widget
		variable line_number	;# Int: Line number

		$editor tag add tag_lst_address	$line_number.3 $line_number.7
		$editor tag add tag_lst_code	$line_number.8 $line_number.19
		$editor tag add tag_lst_number	$line_number.20 $line_number.24
		$editor tag add tag_lst_line	$line_number.25 $line_number.31
	}

	## Highlight MCU 8051 IDE Assembler code listing line
	 # @parm Int asm_start_index - Assembly code start index
	 # @return void
	proc mcu8051ide_highlight {asm_start_index} {
		variable editor		;# Widget: Editor text widget
		variable line_number	;# Int: Line number
		variable line_content	;# String: Line content
		variable line_start	;# Index of line start
		variable line_end	;# Index of line end

		set idx 0	;# Regular expression match start index

		# Alter line
		set line_content [string range $line_content 0 [expr {$asm_start_index - 1}]]

		# Highlight processor code
		if {[regexp -start $idx -- {\A     [[:xdigit:]]{2,}} $line_content substring]} {
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_code $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len

			return
		}

		## Address field present -> Address Code ...
		if {[regexp -start $idx -- {\A[[:xdigit:]]{4}} $line_content substring]} {
			# Highlight address field
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_address $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len

			# Highlight processor code
			if {[regexp -start $idx -- {\A\s+[[:xdigit:]]{2,}} $line_content substring]} {
				set substr_len [string length $substring]
				set idx [string first $substring $line_content $idx]
				$editor tag add tag_lst_code $line_number.$idx $line_number.[expr {$idx + $substr_len}]
				incr idx $substr_len
			}

		# Address field not present -> "  Number"
		} elseif {[regexp -start $idx -- {\A  [[:xdigit:]]{4}} $line_content substring]} {
			# Highlight number (value of defined constant)
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_number $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len
		}

		# Highlight inclusion level
		if {[regexp -start $idx -- {\A\s+\=\d+} $line_content substring]} {
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_include $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len
		}
		# Highlight line number in code listing
		if {[regexp -start $idx -- {\A\s*\d+} $line_content substring]} {
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_line $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len
		}
		# Highlight macro expansion level
		if {[regexp -start $idx -- {\A\s*\+\d+} $line_content substring]} {
			set substr_len [string length $substring]
			set idx [string first $substring $line_content $idx]
			$editor tag add tag_lst_macro $line_number.$idx $line_number.[expr {$idx + $substr_len}]
			incr idx $substr_len
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

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
if { ! [ info exists _CSYNTAXHIGHLIGHT_TCL ] } {
set _CSYNTAXHIGHLIGHT_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements syntax highlighting interface for ISO C language
# --------------------------------------------------------------------------

namespace eval CsyntaxHighlight {
	variable editor			;# Widget: Editor text widget
	variable line_number		;# Int: Line number
	variable line_content		;# String: Line content
	variable line_start		;# Index of line start
	variable line_end		;# Index of line end
	variable validation_L0	1	;# Bool: Basic validation enabled
	variable validation_L1	1	;# Bool: Advanced validation enabled
	# List of compiler directives
	variable directives {
		#define	#error	#include
		#if	#ifdef	#ifndef
		#else	#elif	#endif
		#line	#pragma	#undef
		#warning
	}
	# List of data type specifiers
	variable data_types {
		void	int	float	double	char	signed	unsigned
		long	short	uchar	ushort	uint	ulong	const
		export	extern	static	mutable	volatile

		__data	__near	__xdata	__far	__idata	__pdata	__code
		__bit	__sfr	__sfr16	__sfr32	__sbit	__at

		bool	size_t		addr_t
		uint8_t	uint16_t	uint32_t	uint64_t
		int8_t	int16_t		int32_t 	int64_t
	}
	# List of C keywords
	variable keywords {
		auto	break	case	_endasm	while	union	continue
		default	do	else	enum	sizeof	for	namespace
		if	goto	return	struct	switch	typedef	using
		inline	_asm	__asm	__endasm
	}
	# List of doxygen tags -- No argument
	variable doxy_tags_type0 {
		@return		@see		@sa		@arg
		@li		@nosubgrouping	@subpage	@interface
		@f[		@f]		@f$		@{
		@}
	}
	# List of doxygen tags -- Word after tag
	variable doxy_tags_type1 {
		@class		@defgroup	@addtogroup	@weakgroup
		@ref		@page		@struct		@union
		@enum		@def		@file		@namespace
		@package	@param		@param[in]	@param[out]
		@param[in,out]
	}
	# List of doxygen tags -- Name after tag
	variable doxy_tags_type2 {
		@brief		@ingroup	@name		@mainpage
		@fn		@var		@typedef        @author
		@authors	@warning	@deprecated
	}
	# List of HTML tags (HTML 4.0 Strict)
	variable html_tags {
		a		abbr		acronym		address
		area		b		base		bdo
		big		blockquote	body		br
		button		caption		cite		code
		col		colgroup	dd		del
		dfn		div		dl		dt
		em		fieldset	form		frame
		frameset	h1		h2		h3
		h4		h5		h6		head
		hr		html		i		img
		input		ins		kbd		label
		legend		li		link		map
		meta		noscript	object		ol
		optgroup	option		p		param
		pre		q		samp		script
		select		small		span		strong
		style		sub		sup		table
		tbody		td		textarea	tfoot
		th		thead		title		tr
		tt		ul		var
	}

	## Highlight pattern - highlight tags definition
	 # {
	 #	{tag_name ?foreground? ?overstrike? ?italic? ?bold?}
	 # }
	variable highlight_tags	{
		{tag_c_keyword		#0000DD	0 0 1}
		{tag_c_data_type	#00CC00	0 0 1}
		{tag_c_dec		#0000FF	0 0 0}
		{tag_c_hex		#8800FF	0 0 0}
		{tag_c_bin		#5555AA	0 0 0}
		{tag_c_oct		#883300	0 0 0}
		{tag_c_char		#DD00DD	0 0 0}
		{tag_c_float		#AA00AA	0 0 0}
		{tag_c_string		#BB0000	0 0 0}
		{tag_c_string_char	#DD00DD	0 0 0}
		{tag_c_comment		#888888	0 1 0}
		{tag_c_symbol		#FF0000	0 0 1}
		{tag_c_bracket		#EE6600	0 0 1}
		{tag_c_preprocessor	#008800	0 0 0}
		{tag_c_directive	#558800	0 0 0}
		{tag_c_prep_lib		#885500	0 0 0}
		{tag_normal		#000000 0 0 0}

		{tag_c_dox_comment	#4444FF	0 1 0}
		{tag_c_dox_tag		#AA00DD	0 0 1}
		{tag_c_dox_word		#0088FF	0 0 1}
		{tag_c_dox_name		#FF0000	0 0 0}
		{tag_c_dox_html		#000000	0 0 1}
		{tag_c_dox_harg		#008800 0 0 0}
		{tag_c_dox_hargval	#DD0000 0 0 0}
	}

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
				-font [font create		\
					-overstrike $tag(2)	\
					-slant $tag(3)		\
					-weight $tag(4)		\
					-size -$fontSize	\
					-family $fontFamily 	\
				]
		}

		# Set tag priorities
		$text_widget tag raise tag_c_dox_tag	tag_c_dox_comment
		$text_widget tag raise tag_c_dox_word	tag_c_dox_comment
		$text_widget tag raise tag_c_dox_html	tag_c_dox_comment

		foreach t {
			tag_c_bracket	tag_c_symbol	tag_c_keyword
			tag_c_data_type	tag_c_char	tag_c_dec
			tag_c_oct	tag_c_hex	tag_c_float
			tag_c_bin
		} {
			$text_widget tag raise $t tag_normal
		}
	}

	## Perform syntax highlight on the given line in the given widget
	 # @parm Widget Editor	- Text widget
	 # @parm Int LineNumber	- Number of line to highlight
	 # @parm Int status	- Exit status of previous line
	 # @return Int - Exit status
	 #	1 - Normal
	 #	2 - Doxygen
	 #	3 - Comment
	 #	4 - String
	 #	5 - Assembly
	 #	6 - Assembly within
	 #	7 - Preprocessor
	proc highlight {Editor LineNumber status} {
		variable validation_L0	;# Bool: Basic validation enabled
		variable editor		;# Widget: Editor text widget
		variable line_number	;# Int: Line number
		variable line_content	;# String: Line content
		variable line_start	;# Index of line start
		variable line_end	;# Index of line end
		variable directives	;# List of compiler directives

		# Set NS variables
		set editor	$Editor
		set line_number	$LineNumber
		set line_start	$line_number.0
		set line_end	[$editor index [list $line_number.0 lineend]]
		set line_content [$editor get $line_start $line_end]

		# Validate input arguments
		if {!$status} {
			set status 1
		}

		# Local variables
		set last_idx_s		0	;# Int: Last search index
		set incr_last_i		0	;# Int: Increment last_idx by
		set last_idx		0	;# Int: Last index
		set idx			0	;# Int: Current index
		set this_line_only	0	;# Bool: Status is valid for this line only
		set last_status		$status	;# Int: Last highlight status

		# Remove existing highlighting tags
		delete_tags

		# Handle status "preprocessor"
		if {$status == 7} {
			if {[string index $line_content end] == "\\"} {
				$editor tag add tag_c_preprocessor $line_start $line_end-1c
				$editor tag add tag_c_symbol $line_end-1c $line_end
				return 7
			} else {
				$editor tag add tag_c_preprocessor $line_start $line_end
				return 1
			}

		# Search for preprocessor directive
		} elseif {$status == 1} {
			# Common directive
			if {[regexp {^\s*#\w+} $line_content directive]} {
				# Local variables
				set dir_start [string first {#} $line_content]	;# Int: Directive start index
				set dir_end [string length $directive]		;# Int: Directive end index
				set directive [string trim $directive]		;# String: Directive itself

				# Highlight directive
				$editor tag add tag_c_directive	\
					$line_number.$dir_start $line_number.$dir_end

				# Validate directive
				if {$validation_L0} {
					if {[lsearch -ascii -exact $directives $directive] == -1} {
						$editor tag add tag_error	\
							$line_number.$dir_start $line_number.$dir_end
					}
				}

				# Highlight directive argument
				if {$directive == {#include}} {
					set prep_tag {tag_c_prep_lib}
				} else {
					set prep_tag {tag_c_preprocessor}
				}

				# Determinate start of comment
				set com_start [string first {//} $line_content]
				if {$com_start != -1} {
					set cur_line_end $com_start
					incr cur_line_end -1
					set cur_line_end $line_number.$cur_line_end
				} else {
					set cur_line_end $line_end
				}

				# Determinate whether the directive continue on the next line or not
				if {[string index [regsub {\s+$} $line_content {}] end] == "\\"} {
					$editor tag add $prep_tag $line_number.$dir_end $cur_line_end-1c
					$editor tag add tag_c_symbol $cur_line_end-1c $cur_line_end
					set cur_status 7
				} else {
					$editor tag add $prep_tag $line_number.$dir_end $cur_line_end
					set cur_status 1
				}

				# There is a comment on the line
				if {$com_start != -1} {
					$editor tag add tag_c_comment	\
						$line_number.$com_start	\
						[list $line_number.0 lineend]
				}

				return $cur_status

			# Inline assembler
			} elseif {[regexp {^\s*_?_asm\s*$} $line_content]} {
				$editor tag add tag_c_keyword $line_start $line_end
				return 5
			}
		}

		# Split line into fields with different highlight status
		while {1} {
			set incr_last_i 0
			switch -- $status {
				1 {	;# Normal
					set i 0
					set idx [list {} {} {} {} {} {}]
					foreach str {{/**} {///} {/*} {//} \"} {
						lset idx $i [string first $str $line_content $last_idx_s]
						incr i
					}

					set min_idx 0
					set val 0
					set min 0xFFFF
					for {set i 0} {$i < 5} {incr i} {
						set val [lindex $idx $i]
						if {$val != -1 && $val < $min} {
							set min_idx $i
							set min $val
						}
					}

					set idx [lindex $idx $min_idx]
					if {$idx == -1} {break}
					set last_status $status
					switch -- $min_idx {
						0 {
							set status 2
							set incr_last_i 3
							set this_line_only 0
						}
						1 {
							set status 2
							set incr_last_i 3
							set this_line_only 1
						}
						2 {
							set status 3
							set incr_last_i 2
							set this_line_only 0
						}
						3 {
							set status 3
							set incr_last_i 2
							set this_line_only 1
						}
						4 {
							set status 4
							set incr_last_i 1
							set this_line_only 0
						}
					}
				}
				2 {	;# Doxygen
					set idx [string first {*/} $line_content $last_idx_s]
					if {$idx == -1} {break}
					incr idx 2
					set last_status $status
					set status 1
				}
				3 {	;# Comment
					set idx [string first {*/} $line_content $last_idx_s]
					if {$idx == -1} {break}
					incr idx 2
					set last_status $status
					set status 1
				}
				4 {	;# String
					set l_idx $last_idx_s
					while {1} {
						set idx [string first "\"" $line_content $l_idx]
						if {$idx < 1} {break}
						if {[string index $line_content [expr {$idx - 1}]] == "\\"} {
							incr l_idx
						} else {
							break
						}
					}
					if {$idx == -1} {break}
					incr idx
					set last_status $status
					set status 1
				}
				5 {	;# Inline assembler
					if {[regexp {^\s*_?_endasm[^\w]*} $line_content]} {
						mode_normal 0 [string length $line_content]
						return 1
					}
					set idx 0
					set last_status $status
					set status 6
					break
				}
				6 {	;# Inline assembler -- within asm block
					if {[regexp {^\s*_?_endasm[^\w]*} $line_content]} {
						mode_normal 0 [string length $line_content]
						return 1
					} else {
						break
					}
				}
			}

			# Highliht this chunk
			if {$last_idx != $idx} {
				highlight_aux $last_status $last_idx $idx
			}
			set last_idx $idx
			if {$this_line_only} {break}

			set last_idx_s $last_idx
			incr last_idx_s $incr_last_i
		}

		# Highlight last remaining chunk
		if {$last_idx != [string length $line_content]} {
			highlight_aux $status $last_idx [string length $line_content]
		}

		# Return final status
		if {$this_line_only} {
			return 1
		} else {
			return $status
		}
	}

	## Auxiliary procedure for procedure highlight
	 # This procedure calls other procedures to perform syntax
	 #+ highlight according to the given highlight status
	 # @parm Int status	- Highlight status
	 # @parm Int idx0	- Start index
	 # @parm Int idx1	- End index
	 # @return void
	proc highlight_aux {status idx0 idx1} {
		variable editor		;# Widget: Editor text widget
		variable line_number	;# Int: Line number

		# Validate input arguments
		if {$idx0 < 0} {
			set idx0 0
		}
		if {$idx1 < 0} {
			set idx1 0
		}

		# Determinate what to do
		switch -- $status {
			1 {	;# Normal
				mode_normal $idx0 $idx1
			}
			2 {	;# Doxygen
				mode_doxygen $idx0 $idx1
			}
			3 {	;# Comment
				$editor tag add tag_c_comment $line_number.$idx0 $line_number.$idx1
			}
			4 {	;# String
				mode_string $idx0 $idx1
			}
			5 {	;# Inline assembly
				mode_normal $idx0 $idx1
			}
			6 {	;# Inline assembly -- within
				::ASMsyntaxHighlight::highlight $editor $line_number 1
			}
		}
	}

	## Highlight text within specified indexes as string
	 # @parm Int idx0	- Start index
	 # @parm Int idx1	- End index
	 # @return void
	proc mode_string {idx0 idx1} {
		variable editor		;# Widget: Editor text widget
		variable line_number	;# Int: Line number
		variable line_content	;# String: Line content

		# Local variables
		set idx		0	;# Int: Index of backslash in the string
		set idx_idx0	0	;# Int: ($idx0 + $idx)
		set last_idx	0	;# Int: Last value of $idx
		 # String to highlight
		set string	[string range $line_content $idx0 [expr {$idx1 - 1}]]

		# Highlight escaped characters and character between them
		while {1} {
			# Search for backslash
			set idx [string first "\\" $string $idx]
			if {$idx == -1} {break}

			# Highlight
			set idx_idx0 [expr {$idx + $idx0}]
			$editor tag add tag_c_string $line_number.[expr {$last_idx + $idx0}] $line_number.$idx_idx0
			$editor tag add tag_c_string_char $line_number.$idx_idx0 $line_number.$idx_idx0+2c
			incr idx 2
			set last_idx $idx
		}
		# Highlight remaining chunk of the string
		$editor tag add tag_c_string $line_number.[expr {$last_idx + $idx0}] $line_number.$idx1
	}

	## Highlight text within specified indexes as doxygen document
	 # @parm Int idx0	- Start index
	 # @parm Int idx1	- End index
	 # @return void
	proc mode_doxygen {idx0 idx1} {
		variable validation_L1	;# Bool: Advanced validation enabled
		variable editor		;# Widget: Editor text widget
		variable line_number	;# Int: Line number
		variable line_content	;# String: Line content
		variable doxy_tags_type0;# List of doxygen tags -- No argument
		variable doxy_tags_type1;# List of doxygen tags -- Word after tag
		variable doxy_tags_type2;# List of doxygen tags -- Name after tag
		variable html_tags	;# List of HTML tags (HTML 4.0 Strict)

		# Local variables
		set tag_present	0	;# Bool: Doxygen tag present on line
		set asterix_p	0	;# Bool: Leading asterix present on line
		set i		-1	;# Int: Number of iteration
		set idx		-1	;# Int: Word start index
		set len		0	;# Int: Word length
		set tags	{}	;# List: Highlight tags to put on current word
		set is_word	0	;# Bool: This word is doxygen tag word
		 # Determinate string to highlight
		set string [string range $line_content $idx0 [expr {$idx1 - 1}]]
		 # Split line into words
		set words [split [regsub -all {>} [regsub -all {<} [regsub -all "\"" $string {\"}] { &}] {& }]]

		# Adjust HTML tags with argument(s) (they must be represented as a single word)
		set tag_opened 0
		set result_words {}
		foreach word $words {
			if {!$tag_opened} {
				append result_words { }		;# Insert a common space
			} else {
				append result_words "\xA0"	;# Insert NBSP
			}
			if {!$tag_opened && [regexp {^<\w+$} $word]} {
				set tag_opened 1
			} elseif {$tag_opened && [string index $word end] == {>}} {
				set tag_opened 0
			}
			append result_words [regsub -all {[\{\}]} $word {\\&}]
		}
		set words $result_words
		set result_words {}

		# Iterate over string words
		foreach word $words {
			# Skip empty words
			if {$word == {}} {continue}

			incr i
			set idx [string first [regsub -all "\xA0" $word { }] $string [expr {$idx + $len}]]
			set len [string length $word]

			# Detect doxygen tag word
			if {$is_word} {
				set is_word 0
				set tags {tag_c_dox_word}

			# Detect dogygen tag
			} elseif {[string index $word 0] == {@}} {
				# Tags without argument
				if {[lsearch -ascii -exact $doxy_tags_type0 $word] != -1 || $word == {@f[}} {
					set tags {tag_c_dox_tag}

				# Tags with one argument
				} elseif {[lsearch -ascii -exact $doxy_tags_type1 $word] != -1} {
					set tags {tag_c_dox_tag}
					set is_word 1

				# Tags witch has name after
				} elseif {[lsearch -ascii -exact $doxy_tags_type2 $word] != -1} {
					$editor tag add tag_c_dox_tag			\
						$line_number.[expr {$idx0 + $idx}]	\
						$line_number.[expr {$idx0 + $idx + $len}]
					$editor tag add tag_c_dox_name				\
						$line_number.[expr {$idx0 + $idx + $len}]	\
						$line_number.$idx1
					break

				# Invalid tag
				} else {
					set tags {tag_c_dox_tag}
					if {$validation_L1} {
						lappend tags {tag_error}
					}
				}

			# Detect HTML tags
			} elseif {[string index $word 0] == {<} && [string index $word end] == {>}} {
				set tags {}

				# Adjust word
				set word [string replace $word 0 0 { }]
				if {[string index $word 1] == {/}} {
					set word [string replace $word 1 1 { }]
				}
				set word [string replace $word end end { }]
				set word [regsub -all "\xA0" $word { }]

				# Mark empty tags as errors
				if {$validation_L1 && ![string length [string trim $word]]} {
					$editor tag add tag_error			\
						$line_number.[expr {$idx0 + $idx}]	\
						$line_number.[expr {$idx0 + $idx + $len}]
					$editor tag add tag_c_dox_html			\
						$line_number.[expr {$idx0 + $idx}]	\
						$line_number.[expr {$idx0 + $idx + $len}]
				}

				# Highlight each part of word separately (tag argument="value" ...)
				set sub_len	0
				set sub_idx	-1
				set w_idx	-1
				foreach w [split $word] {
					if {$w == {}} {continue}
					incr w_idx
					set sub_len [string length $w]
					incr sub_idx
					set sub_idx [string first $w $word $sub_idx]

					# Highlight and validate HTML tag
					if {!$w_idx} {
						# Highlight tagname
						$editor tag add tag_c_dox_html			\
							$line_number.[expr {$idx0 + $idx}]	\
							$line_number.[expr {$idx0 + $idx + $sub_idx + $sub_len}]

						# Check if HTML tag is valid HTML-4.0 Strict tag
						if {$validation_L1 && [lsearch $html_tags [string tolower $w]] == -1} {
							$editor tag add tag_error				\
								$line_number.[expr {$idx0 + $idx + $sub_idx}]	\
								$line_number.[expr {$idx0 + $idx + $sub_idx + $sub_len}]
						}

					# Highlight arguments
					} else {
						set first_equ_mark [string first {=} $w]
						incr first_equ_mark

						# Check if argument notation is valid
						if {$validation_L1 && $first_equ_mark == $sub_len} {
							$editor tag add tag_error				\
								$line_number.[expr {$idx0 + $idx + $sub_idx}]	\
								$line_number.[expr {$idx0 + $idx + $sub_idx + $sub_len}]
						}

						# Highlight argument value
						if {$first_equ_mark} {
							$editor tag add tag_c_dox_hargval	\
								$line_number.[expr {$idx0 + $idx + $sub_idx + $first_equ_mark}]	\
								$line_number.[expr {$idx0 + $idx + $sub_idx + $sub_len}]
						} else {
							set first_equ_mark $sub_len
						}

						# Highlight argument name
						$editor tag add tag_c_dox_harg				\
							$line_number.[expr {$idx0 + $idx + $sub_idx}]	\
							$line_number.[expr {$idx0 + $idx + $sub_idx + $first_equ_mark}]
					}
				}
				# Highlight last ">"
				$editor tag add tag_c_dox_html				\
					$line_number.[expr {$idx0 + $idx + $len - 1}]	\
					$line_number.[expr {$idx0 + $idx + $len}]

			# Doxygen comment
			} else {
				set tags {tag_c_dox_comment}
			}

			# Create chosen highlighting tags
			foreach tag $tags {
				$editor tag add $tag				\
					$line_number.[expr {$idx0 + $idx}]	\
					$line_number.[expr {$idx0 + $idx + $len}]
			}
		}
	}

	## Highlight text within specified indexes as normal text
	 # @parm Int idx0	- Start index
	 # @parm Int idx1	- End index
	 # @return void
	proc mode_normal {idx0 idx1} {
		variable validation_L0	;# Bool: Basic validation enabled
		variable editor		;# Widget: Editor text widget
		variable line_number	;# Int: Line number
		variable line_content	;# String: Line content
		variable data_types	;# List of data type specifiers
		variable keywords	;# List of C keywords

		# Determinate string to highligh and its length
		set string [string range $line_content $idx0 [expr {$idx1 - 1}]]
		set len [string length $string]

		# At first highlight all as a normal text
		$editor tag add tag_normal $line_number.$idx0 $line_number.$idx1

		# Highlight symbols
		set char {}
		for {set i 0; set j $idx0} {$i < $len} {incr i; incr j} {
			set char [string index $string $i]

			# Brackets
			if {
				$char == {(}	|| $char == {)}	|| $char == "\{" ||
				$char == "\}"	|| $char == {[}	|| $char == {]}
			} then {
				$editor tag add tag_c_bracket $line_number.$j $line_number.$j+1c

			# Other symbols
			} elseif {[lsearch -ascii -exact {; = , + - < > ! | & * / ? : % ^} $char] != -1} {
				$editor tag add tag_c_symbol $line_number.$j $line_number.$j+1c
			}
		}

		# Highlight keywords and data types
		set idx 0
		foreach words [list $keywords $data_types]	\
			tag {tag_c_keyword tag_c_data_type}	\
		{
			set idx -1
			foreach word $words {
				while {1} {
					incr idx
					set idx [string first $word $string $idx]
					if {$idx == -1} {break}
					set len [string length $word]
					if {[string is wordchar -strict [string index $string [expr {$idx - 1}]]]} {
						continue
					}
					if {[string is wordchar -strict [string index $string [expr {$idx + $len}]]]} {
						continue
					}
					$editor tag add $tag				\
						$line_number.[expr {$idx0 + $idx}]	\
						$line_number.[expr {$idx0 + $idx + $len}]
				}
			}
		}

		# Highlight numbers
		set idx		-1
		set len		0
		set tags	{}
		foreach word [split $string {  	;=,+-<>!|&*/?:%^{}[]()}] {
			if {$word == {}} {continue}

			incr idx
			set len [string length $word]
			set idx [string first $word $string $idx]

			regsub {[uU]?[lL]?[lL]?[uU]?$} $word {} word

			# Char
			if {![string is digit -strict [string index $word 0]]} {
				if {$word == {''}} {
					set tags {tag_error}
				} elseif {[regexp {^'[^']+'$} $word]} {
					set tags {tag_c_char}
				} else {
					continue
				}

			# Oct | Dec
			} elseif {[string is digit -strict $word]} {
				if {[string index $word 0] == {0}} {
					if {$len == 1} {
						set tags {tag_c_dec}
					} elseif {!$validation_L0 || [regexp {^0[0-7]+$} $word]} {
						set tags {tag_c_oct}
					} else {
						set tags {tag_c_oct tag_error}
					}
				} else {
					set tags {tag_c_dec}
				}

			# Hex
			} elseif {
					[string index $word 0] == {0} && (
						[string index $word 1] == {x}
							||
						[string index $word 1] == {X}
					)
			} then {
				if {!$validation_L0 || [string is xdigit -strict [string range $word 2 end]]} {
					set tags {tag_c_hex}
				} else {
					set tags {tag_c_hex tag_error}
				}

			# Bin
			} elseif {
					[string index $word 0] == {0} && (
						[string index $word 1] == {b}
							||
						[string index $word 1] == {B}
					)
			} then {
				if {!$validation_L0 || [regexp {^[01]+$} [string range $word 2 end]]} {
					set tags {tag_c_bin}
				} else {
					set tags {tag_c_bin tag_error}
				}

			# Float
			} elseif {[regexp {^\d+\.\d+$} $word]} {
				set tags {tag_c_float}

			# Invalid number
			} else {
				if {$validation_L0} {
					set tags {tag_error}
				}
			}

			# Put tags on text widget
			foreach tag $tags {
				$editor tag add $tag				\
					$line_number.[expr {$idx0 + $idx}]	\
					$line_number.[expr {$idx0 + $idx + $len}]
			}
		}
	}

	## Remove previously defined syntax highlighting tags
	 # @return void
	proc delete_tags {} {
		variable editor			;# Widget: Editor text widget
		variable highlight_tags	;# Highlight tags definition
		variable line_start		;# Index of line start
		variable line_end		;# Index of line end

		# Remove tag error
		$editor tag remove tag_error		$line_start $line_end
		$editor tag remove tag_error_line	$line_start $line_start+1l
		$editor tag remove c_lang_func		$line_start $line_start+1l
		$editor tag remove c_lang_var		$line_start $line_start+1l

		# Remove tags according to pattern
		foreach tag $highlight_tags {
			$editor tag remove [lindex $tag 0] $line_start $line_end
		}
		foreach tag $::ASMsyntaxHighlight::highlight_tags {
			$editor tag remove [lindex $tag 0] $line_start $line_end
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

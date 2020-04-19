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
if { ! [ info exists _EXPORTS_TCL ] } {
set _EXPORTS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements exports to other data formats (XHTML && LaTeX)
# This file should be loaded into class Editor in file "editor.tcl"
# --------------------------------------------------------------------------

## Get maximum value for progressbar showing highlightion progress (proc. highlight_all)
 # @return Int - Number of lines to highlight divided by 50
public method highlight_all_count_of_iterations {} {
	set result 0
	for {set i 1} {$i < [string bytelength $highlighted_lines]} {incr i} {
		if {[string index $highlighted_lines $i] == 0} {
			incr result
		}
		if {![expr {$i % 1000}]} {update}
	}
	return [expr {$result / 50}]
}

## Highlight all lines in the editor (can take a long time !)
 # @return void
public method highlight_all {} {
	# Reset abort variables
	set getDataAsLaTeX_abort 0

	# Highlight all lines
	set len [string bytelength $highlighted_lines]
	for {set i 1} {$i < $len} {incr i} {
		if {[string index $highlighted_lines $i]} {continue}

		# Highlight line
		parse $i

		# Update progress bar
		if {![expr {$i % 50}]} {
			incr ::X::compilation_progress
			update
		}

		# Conditional abort
		if {$getDataAsLaTeX_abort} {
			set getDataAsLaTeX_abort 0
			return
		}
	}
}

## Get maximum value for export progress bar
 # @return Int - the value
public method getDataAsXHTML_count_of_iterations {} {
	set result 0
	foreach tag_def [concat				\
		${ASMsyntaxHighlight::highlight_tags}	\
		${CsyntaxHighlight::highlight_tags}	\
		${LSTsyntaxHighlight::highlight_tags}	\
	] {
		set range [$editor tag ranges [lindex $tag_def 0]]
		incr result [llength $range]
		if {![expr {$result % 1000}]} {update}
	}
	return [expr {$result / 50}]
}

## Abort export to LaTeX
 # @return void
public method getDataAsLaTeX_abort_now {} {
	set getDataAsLaTeX_abort 1
}

## Export editor content as LaTeX source (include colors)
 # @parm File file - Target data channel
public method getDataAsLaTeX {file} {

	# Reset abort variables
	set getDataAsLaTeX_abort 0

	# Local variables
	set end [$editor index end]	;# Editor end index
	set last_index 0		;# Current position (by characters)
	set line(1) 0			;# Map of indexes ($line(num) == scalar_index)

	# Create map of indexes
	for {set i 1; set j 2} {$i < $end} {incr i; incr j} {

		# Conditional abort
		if {$getDataAsLaTeX_abort} {
			set getDataAsLaTeX_abort 0
			return {}
		}

		# Determinate last column of the line
		set idx [$editor index "$i.0 lineend"]
		regexp {\d+$} $idx idx

		# Adjust map of indexes
		incr last_index $idx
		incr last_index
		set line($j) $last_index
	}

	# Create LaTeX preamble
	puts -nonewline $file "\\documentclass\[a4paper,12pt\]{article}"
	puts -nonewline $file "\n\n% Creator: ${::APPNAME}\n\n"
	puts -nonewline $file "\\usepackage\[utf8\]{inputenc}\n"
	puts -nonewline $file "\\usepackage\[T1\]{fontenc}\n"
	puts -nonewline $file "\\usepackage{color}\n"
	puts -nonewline $file "\\title{$filename}\n"
	puts -nonewline $file "\\date{[clock format [clock seconds] -format {%D}]}\n"
	puts -nonewline $file "\n% define highlighting\n"

	## Determinate highlighting tag ranges and define colors for 'color' package
	set ranges {}
	# Iterate over predefined highlighting tags
	foreach tag_def [concat				\
		${ASMsyntaxHighlight::highlight_tags}	\
		${CsyntaxHighlight::highlight_tags}	\
		${LSTsyntaxHighlight::highlight_tags}	\
	] {

		# Conditional abort
		if {$getDataAsLaTeX_abort} {
			set getDataAsLaTeX_abort 0
			return {}
		}

		# Local variables
		set color	[lindex $tag_def 1]		;# RGB color
		set tag		[lindex $tag_def 0]		;# Tag name
		set range	[$editor tag ranges $tag]	;# List of tag ranges
		set len		[llength $range]		;# Number of ranges
		set mirror_tag	{}				;# Tag with exatly the same highlight

		# Convert 48b color format to 24b format
		if {[string length $color] == 13} {
			set new_color {#}
			for {set i 1} {$i < [string length $color]} {incr i 4} {
				append new_color [string range $color $i [expr {$i + 1}]]
			}
			set color $new_color
		}

		# Decompose the color code
		set red		[string range $color 1 2]	;# Color - RED
		set green	[string range $color 3 4]	;# Color - GREEN
		set blue	[string range $color 5 6]	;# Color - BLUE

		# Determinate mirror tag
		switch -- $tag {
			{tag_constant}	{set mirror_tag tag_constant_def}
			{tag_macro}	{set mirror_tag tag_macro_def}
		}
		if {$mirror_tag != {}} {
			set mirror_range [$editor tag ranges $mirror_tag]
		} else {
			set mirror_range {}
		}

		# If the tag isn't present in the text -> skip
		if {$len == 0 && ![llength $mirror_range]} {
			continue
		}
		# Adjust tag name
		set tag [string replace $tag 0 3]

		# Convert hexadecimal color values to decimal representation
		set red		[string range [expr "0x$red	/ 255.0"] 0 4]
		set green	[string range [expr "0x$green	/ 255.0"] 0 4]
		set blue	[string range [expr "0x$blue	/ 255.0"] 0 4]
		# Define color (for package color)
		puts -nonewline $file "\\definecolor{highlight_$tag}{rgb}{$red, $green, $blue}\n"

		# Adjust map of text tags
		set mirror_tag {}
		switch -- $tag {
			{constant}	{set mirror_tag tag_constant_def}
			{macro}		{set mirror_tag tag_macro_def}
		}
		for {set i 0} {$i < $len} {incr i} {
			lappend ranges [list [lindex $range $i] $tag 1]
			incr i
			lappend ranges [list [lindex $range $i] $tag 0]
		}
		if {$mirror_tag != {}} {
			set range [$editor tag ranges $mirror_tag]
			set len [llength $range]
			for {set i 0} {$i < $len} {incr i} {
				lappend ranges [list [lindex $range $i] $tag 1]
				incr i
				lappend ranges [list [lindex $range $i] $tag 0]
			}
		}
	}

	# Sort map of text tags (recursive)
	set ranges [lsort -command "::FileList::editor__sort_tag_ranges" $ranges]

	# Get plain text
	set text [$editor get 1.0 end]
	regsub -all {'} $text "\a" text

	## Create map of tabulators ("\t")
	set tab_map {}
	# Iterate ovet lines in editor
	foreach textLine [split $text "\n"] {

		if {$textLine == {}} {continue}
		set idx -1
		set spaces 0
		set correction 0

		while {1} {
			set idx [string first "\t" $textLine [expr {$idx + 1}]]
			if {$idx == -1} {break}

			set spaces [expr {8 - (($idx + $correction) % 8)}]
			incr correction [expr {$spaces - 1}]

			lappend tab_map $spaces
		}
	}

	# Write LaTeX control sequences
	set i 0
	foreach range $ranges {

		# Conditional abort
		if {$getDataAsLaTeX_abort} {
			set getDataAsLaTeX_abort 0
			return {}
		}

		# Update progress bar
		if {![expr {$i % 50}]} {
			incr ::X::compilation_progress
			update
		}

		set idx [split [lindex $range 0] {.}]	;# Text index
		set row [lindex $idx 0]			;# Line number
		set col [lindex $idx 1]			;# Column number

		# Determinate scalar text index
		set idx [expr {$line($row) + $col}]
		if {$idx < 0} {set idx 0}

		# Determinate string to insert
		if {[lindex $range 2]} {
			set tag "'\{\\color{highlight_[lindex $range 1]}\\verb'"
		} else {
			set tag "'\}\\verb'"
		}

		# Insert control sequence into plain text
		set char [string index $text $idx]
		set text [string replace $text $idx $idx "$tag$char"]

		incr i
	}

	# Covert tabs to spaces
	set i 0
	foreach spaces $tab_map {
		set idx [string first "\t" $text]
		if {$idx == -1} {break}

		set text [string replace $text $idx $idx [string repeat { } $spaces]]
		if {![expr {$i % 1000}]} {update}
		incr i
	}

	# Adjust lines
	regsub -all -line {^} $text {\\verb'} text
	regsub -all -line {$} $text "'\\\\\\" text
	regsub -all -line {\s+'\\\\$} $text {'\\\\} text
	regsub -all {\\verb''} $text {} text
	regsub -all -line {^\\\\$} $text {\\verb''&} text
	regsub -all "\a" $text {'\\verb"'"\\verb'} text

	# Create final LaTeX document
	puts -nonewline $file "\n\n\\begin{document}\n"
	puts -nonewline $file "\\ \\\\\n"
	puts -nonewline $file $text
	puts -nonewline $file "\n\\end{document}"
}

## Abort export to XHTML
 # @return void
public method getDataAsXHTML_abort_now {} {
	set getDataAsXHTML_abort 1
}

## Export editor content as XHTML source (include colors)
 # @parm File file - Target data channel
public method getDataAsXHTML {file} {

	# Reset abort variables
	set getDataAsXHTML_abort 0

	# Local variables
	set end [$editor index end]	;# Editor end index
	set last_index 0		;# Current position (by characters)
	set line(1) 0			;# Map of indexes ($line(num) == scalar_index)

	# Create map of indexes
	for {set i 1; set j 2} {$i < $end} {incr i; incr j} {

		# Conditional abort
		if {$getDataAsXHTML_abort} {
			set getDataAsXHTML_abort 0
			return {}
		}

		# Determinate last column of the line
		set idx [$editor index [list $i.0 lineend]]
		regexp {\d+$} $idx idx

		# Adjust map of indexes
		incr last_index $idx
		incr last_index
		set line($j) $last_index
	}

	# Create XHTML header
	puts -nonewline $file "<?xml version='1.0' encoding='utf-8' standalone='no'?>\n"
	puts -nonewline $file "<!DOCTYPE html PUBLIC\n"
	puts -nonewline $file "\t'-//W3C//DTD XHTML 1.1//EN'\n"
	puts -nonewline $file "\t'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'>\n"
	puts -nonewline $file "<html xmlns='http://www.w3.org/1999/xhtml' xml:lang='en'>\n"
	puts -nonewline $file "<!-- Creator: ${::APPNAME} -->\n"
	puts -nonewline $file "\t<head>\n"
	puts -nonewline $file "\t\t<title>$filename</title>\n"
	puts -nonewline $file "\t\t<meta http-equiv=\"Content-Type\" content=\"application/xhtml+xml; charset=UTF-8\" />\n"
	puts -nonewline $file "\t\t<meta name=\"Generator\" content=\"${::APPNAME}\" />\n"
	puts -nonewline $file "\t\t<style type=\"text/css\">\n"
	puts -nonewline $file "\t\t\tbody {\n\t\t\t\tfont-family: $fontFamily;\n\t\t\t\tfont-size: ${fontSize}px;\n\t\t\t}\n"

	## Determinate highlighting tag ranges and define inline CSS
	set ranges {}
	# Iterate over predefined highlighting tags
	foreach tag_def [concat				\
		${ASMsyntaxHighlight::highlight_tags}	\
		${CsyntaxHighlight::highlight_tags}	\
		${LSTsyntaxHighlight::highlight_tags}	\
	] {

		# Conditional abort
		if {$getDataAsXHTML_abort} {
			set getDataAsXHTML_abort 0
			return {}
		}

		# Local variables
		set tag [lindex $tag_def 0]		;# Tag name
		set range [$editor tag ranges $tag]	;# List of tag ranges
		set len [llength $range]		;# Number of ranges
		set mirror_tag {}			;# Tag with exatly the same highlight

		# Determinate mirror tag
		switch -- $tag {
			{tag_constant}	{set mirror_tag tag_constant_def}
			{tag_macro}	{set mirror_tag tag_macro_def}
		}
		if {$mirror_tag != {}} {
			set mirror_range [$editor tag ranges $mirror_tag]
		} else {
			set mirror_range {}
		}

		# If the tag isn't present in the text -> skip
		if {$len == 0 && ![llength $mirror_range]} {
			continue
		}
		# Adjust tag name
		set tag [string replace $tag 0 3]

		set color [lindex $tag_def 1]

		# Convert 48b color format to 24b format
		if {[string length $color] == 13} {
			set new_color {#}
			for {set i 1} {$i < [string length $color]} {incr i 4} {
				append new_color [string range $color $i [expr {$i + 1}]]
			}
			set color $new_color
		}

		# create CSS
		puts -nonewline $file "\t\t\t.$tag {\n"
		puts -nonewline $file "\t\t\t\tcolor: $color;\n"
		if {[lindex $tag_def 2]} {
			puts -nonewline $file "\t\t\t\ttext-decoration: line-through;\n"
		}
		if {[lindex $tag_def 3]} {
			puts -nonewline $file "\t\t\t\tfont-style: italic;\n"
		}
		if {[lindex $tag_def 4]} {
			puts -nonewline $file "\t\t\t\tfont-weight: bold;\n"
		}
		puts -nonewline $file "\t\t\t}\n"

		for {set i 0} {$i < $len} {incr i} {
			lappend ranges [list [lindex $range $i] $tag 1]
			incr i
			lappend ranges [list [lindex $range $i] $tag 0]
		}
		if {$mirror_tag != {}} {
			set len [llength $mirror_range]
			for {set i 0} {$i < $len} {incr i} {
				lappend ranges [list [lindex $mirror_range $i] $tag 1]
				incr i
				lappend ranges [list [lindex $mirror_range $i] $tag 0]
			}
		}
	}
	puts -nonewline $file "\t\t</style>\n"
	puts -nonewline $file "\t</head>\n"

	# Sort tag ranges (recursive)
	set ranges [lsort -command "::FileList::editor__sort_tag_ranges" $ranges]

	# Get plain text
	set text [$editor get 1.0 end]
	# Translate '<' and '>' to '\a' and '\b'
	regsub -all {<} $text "\a" text
	regsub -all {>} $text "\b" text

	# Write XHTML tags to plain text
	set i 0
	foreach range $ranges {

		# Conditional abort
		if {$getDataAsXHTML_abort} {
			set getDataAsXHTML_abort 0
			return {}
		}

		# Update progress bar
		if {![expr {$i % 50}]} {
			incr ::X::compilation_progress
			update
		}

		# Local variables
		set idx [split [lindex $range 0] {.}]	;# Text index
		set row [lindex $idx 0]			;# Line number
		set col [lindex $idx 1]			;# Column number

		# Determinate scalar text index
		set idx [expr {$line($row) + $col}]
		# Skip unused tags
		if {$idx < 0} {set idx 0}

		# Deterinate string to insert
		if {[lindex $range 2]} {
			set tag "span class='[lindex $range 1]'"
		} else {
			set tag {/span}
		}

		# Insert XHTML tag into the text
		set char [string index $text $idx]
		set text [string replace $text $idx $idx "<$tag>$char"]

		incr i
	}

	# Translate '&' -> &amp;
	regsub -all "&" $text {\&amp;} text
	# Traslate '\a', '\b' -> '&lt;', '&gt;'
	regsub -all "\a" $text {\&lt;} text
	regsub -all "\b" $text {\&gt;} text

	# Create final XHTML document
	puts -nonewline $file "\t<body>\n\t\t<pre>\n"
	puts -nonewline $file "\t\t<!-- CODE BLOCK - begin -->\n"
	puts -nonewline $file $text
	puts -nonewline $file "\t\t<!-- CODE BLOCK - end -->\n"
	puts -nonewline $file "\t\t</pre>\n\t</body>\n</html>"
}

# >>> File inclusion guard
}
# <<< File inclusion guard

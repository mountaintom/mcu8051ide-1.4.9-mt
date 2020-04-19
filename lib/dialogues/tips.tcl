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
if { ! [ info exists _TIPS_TCL ] } {
set _TIPS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides facility to show tips on start-up
#	* Tips are readed from file deindef in NS variable "tips_file"
#	* Format of definition file is XML and it supports mutiple languages
#	* Usage is simple: execute procedure "::Tips::show_tip_of_the_day_win"
#	* It requires NS ConfigDialogues (see ${::GLOBAL_CONFIG(tips)})
# --------------------------------------------------------------------------

namespace eval Tips {
	variable tip_of_the_day_win		;# ID of window "Tip of the day"
	variable tip_of_the_day_text		;# ID of text widget in "Tip of the day"
	variable tip_of_the_day_show_again	;# Bool: Show "Tip of the day"

	variable tips_data			;# List containing tips data
	variable number_of_tips			;# Number of tips available
	variable current_tip			;# Number of the currently displayed tip
	variable expected			;# Expeceted element
	variable take_data			;# Bool: Append data section to $tips_data
	# File containing tips data
	variable tips_file			"${::INSTALLATION_DIR}/data/tips.xml"

	## Invoke dialog "Tip on start-up"
	 # @return void
	proc show_tip_of_the_day_win {} {
		variable tip_of_the_day_win		;# ID of window "Tip of the day"
		variable tip_of_the_day_text		;# ID of text widget in "Tip of the day"
		variable tip_of_the_day_show_again	;# Bool: Show "Tip of the day"
		variable number_of_tips			;# Number of tips available
		variable tip_of_the_day_show_again	;# Bool: Show "Tip of the day"

		# Set value of checkbox "Show again"
		set tip_of_the_day_show_again ${::GLOBAL_CONFIG(tips)}
		# Load tips definition file
		load_tips_file

		# Create toplevel window
		set win [toplevel .tip_of_the_day -class {Tip of the day} -bg ${::COMMON_BG_COLOR}]
		set tip_of_the_day_win $win

		# Create window header
		pack [label $win.header			\
			-text [mc "Did you know ... "]	\
			-font [font create					\
				-family {times}					\
				-size [expr {int(-25 * $::font_size_factor)}]	\
				-weight bold					\
			]	\
			-compound right			\
			-image ::ICONS::32::help	\
		] -pady 5

		# Create middle frame (text windget and scrollbar)
		set middle_frame [frame $win.middle_frame]
		set text [text $middle_frame.text				\
			-width 0 -height 0 -bg white				\
			-wrap word						\
			-yscrollcommand "$middle_frame.scrollbar set"		\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-14 * $::font_size_factor)}]	\
				-weight normal					\
			]	\
		]
		pack $text -side left -fill both -expand 1
		pack [ttk::scrollbar $middle_frame.scrollbar	\
			-orient vertical			\
			-command [list $text yview]		\
		] -side left -fill y -after $text
		set tip_of_the_day_text $text

		## Create bottom frame
		set bottom_frame [frame $win.bottom_frame]
		# - CheckButton "Show tips on start-up"
		pack [checkbutton $bottom_frame.chbutton		\
			-variable ::Tips::tip_of_the_day_show_again	\
			-command {::Tips::tip_otd_show_again}		\
			-text [mc "Show tips on start-up"]		\
		] -side left -anchor e
		# - Button "Close"
		pack [ttk::button $bottom_frame.close_but	\
			-compound left				\
			-text [mc "Close"]			\
			-image ::ICONS::16::button_cancel	\
			-command {::Tips::tip_otd_CLOSE}	\
			-width 8				\
		] -side right -anchor w -padx 2
		# - Button "Next"
		pack [ttk::button $bottom_frame.next_but	\
			-compound left				\
			-text [mc "Next"]			\
			-image ::ICONS::16::right		\
			-command {::Tips::tip_otd_NEXT}		\
			-width 8				\
		] -side right -anchor w -padx 2
		# - Button "Previous"
		pack [ttk::button $bottom_frame.prev_but	\
			-compound left				\
			-text [mc "Previous"]			\
			-image ::ICONS::16::left		\
			-command {::Tips::tip_otd_PREV}		\
			-width 8				\
		] -side right -anchor w -padx 2

		# Pack window frames
		pack $middle_frame -side top -fill both -expand 1 -padx 10 -pady 5
		pack $bottom_frame -side bottom -fill x -after $middle_frame -padx 10 -pady 5

		# Configure text tags
		$text tag configure tag_bold -font [font create		\
			-family {helvetica}				\
			-size [expr {int(-14 * $::font_size_factor)}]	\
			-weight bold					\
		]
		# Configure text tags
		$text tag configure tag_code -font [font create		\
			-family $::DEFAULT_FIXED_FONT			\
			-size [expr {int(-14 * $::font_size_factor)}]	\
			-weight normal					\
		] -foreground {#DD8800}

		# Create tag for external hyperlinks
		create_link_tag_in_text_widget $text

		# Determinate random number of tip to show
		expr {srand([clock seconds])}
		display_tip [expr {int(rand() * $number_of_tips)}]

		# Configure dialog window
		wm iconphoto $win ::ICONS::16::info
		wm title $win [mc "Tip of the day - MCU 8051 IDE"]
		wm minsize $win 520 250
		wm protocol $win WM_DELETE_WINDOW {
			::Tips::tip_otd_CLOSE
		}
		wm transient $win .
		raise $win
		catch {
			grab $win
		}
	}

	## Load definition of tips
	 # @return void
	proc load_tips_file {} {
		variable tips_data	;# List containing tips data
		variable number_of_tips	;# Number of tips available
		variable tips_file	;# File containing tips data
		variable expected	;# Expeceted element
		variable take_data	;# Bool: Append data section to $tips_data

		# Initialize NS variables
		set take_data		0
		set number_of_tips	0
		set expected		{tips}
		set tips_data		{}

		# Open file
		if {[catch {
			set file [open $tips_file {r}]
		}]} then {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title "tips.xml"	\
				-message [mc "Unable to open file containing tips,\nplease check your installation"]
			return
		}

		# Create XML parser
		set parser [::xml::parser -final 1 -ignorewhitespace 1		\
			-elementstartcommand ::Tips::xml_data_parser_element	\
			-characterdatacommand ::Tips::xml_data_parser_data	\
		]

		# Start XML parser
		if {[catch {
			$parser parse [read $file]
		} result]} then {
			set number_of_tips 0
			set tips_data {}
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Unable to parse tips.xml"]	\
				-message [mc "File tips.xml is corrupted,\nplease check your installation"]
			puts stderr $result
			return
		}

		# Close file and free parser
		close $file
		$parser free
	}

	## Universal parser handler - handles XML tags and data
	 # @parm String arg1 - content of the element
	 # @return void
	proc xml_data_parser_data {arg1} {
		variable tips_data	;# List containing tips data
		variable number_of_tips	;# Number of tips available
		variable current_tip	;# Number of the currently displayed tip
		variable expected	;# Expeceted element
		variable take_data	;# Bool: Append data section to $tips_data

		if {!$take_data} {
			return
		}

		set take_data 0
		incr number_of_tips

		regsub -all {^\s+} $arg1 {} arg1
		regsub -all {\s+$} $arg1 {} arg1
		lappend tips_data [regsub -all -line {^\t+} $arg1 {}]
	}

	## XML parser handler - handles XML tags
	 # @parm String arg1	- name of the element
	 # @parm List attrs	- list of attributes '{attr0 val0 attr1 val1 ...}'
	 # @return void
	proc xml_data_parser_element {arg1 attrs} {
		variable tips_data	;# List containing tips data
		variable number_of_tips	;# Number of tips available
		variable current_tip	;# Number of the currently displayed tip
		variable expected	;# Expeceted element
		variable take_data	;# Bool: Append data section to $tips_data

		if {$arg1 != $expected} {
			error "Bad element `$arg1'"
		}
		if {$arg1 == {tips}} {
			set expected {tip}
		}

		# Iterate over element attributes
		for {set i 0} {$i < [llength $attrs]} {incr i} {
			if {[lindex $attrs $i] != {lang}} {
				incr i
				continue
			}
			incr i

			# Take data only if some translation has been loaded and it conforms with the text
			if {[string tolower [lindex $attrs $i]] == [string tolower ${::GLOBAL_CONFIG(language)}]} {
				set take_data 1
			} else {
				set take_data 0
			}
		}
	}

	## Close dialog
	 # @return void
	proc tip_otd_CLOSE {} {
		variable tips_data		;# List containing tips data
		variable number_of_tips		;# Number of tips available
		variable current_tip		;# Number of the currently displayed tip
		variable tip_of_the_day_win	;# ID of window "Tip of the day"

		# Remove dialog
		grab release $tip_of_the_day_win
		destroy $tip_of_the_day_win

		# Free dialog resources
		set tips_data		{}
		set number_of_tips	{}
		set current_tip		{}
	}

	## Display tip with the given number in the window
	 # @parm Int tip_number - number of the tip to show (can overlap allowed range)
	 # @return void
	proc display_tip {tip_number} {
		variable tips_data		;# List containing tips data
		variable number_of_tips		;# Number of tips available
		variable current_tip		;# Number of the currently displayed tip
		variable tip_of_the_day_text	;# ID of text widget in "Tip of the day"

		set current_tip $tip_number

		# Clear text widget
		$tip_of_the_day_text configure -state normal
		$tip_of_the_day_text delete 1.0 end

		# Validate tip number
		if {!$number_of_tips} {
			$tip_of_the_day_text configure -state disabled
			return
		}
		if {$tip_number >= $number_of_tips} {
			set current_tip $number_of_tips
			incr current_tip -1
		}

		# Create map of bold and code font tags
		set bold_tag_map [list]
		set code_tag_map [list]
		set content [lindex $tips_data $current_tip]
		foreach map {bold_tag_map	code_tag_map}	\
			tag {b			c}		\
		{
			while {1} {
				set tag_pair {}

				set idx [string first "<$tag>" $content]
				if {$idx == -1} {break}
				regsub "<$tag>" $content {} content
				lappend tag_pair $idx

				set idx [string first "</$tag>" $content]
				if {$idx == -1} {break}
				regsub "</$tag>" $content {} content
				lappend tag_pair $idx

				lappend $map $tag_pair
			}
		}

		# Fill text widget
		set start [$tip_of_the_day_text index insert]
		$tip_of_the_day_text insert end $content
		foreach pair $bold_tag_map {
			$tip_of_the_day_text tag add tag_bold $start+[lindex $pair 0]c $start+[lindex $pair 1]c
		}
		foreach pair $code_tag_map {
			$tip_of_the_day_text tag add tag_code $start+[lindex $pair 0]c $start+[lindex $pair 1]c
		}
		$tip_of_the_day_text configure -state disabled

		# Detect external hyperlinks and make the functional
		convert_all_https_to_links $tip_of_the_day_text
	}

	## Show next tip
	 # @return void
	proc tip_otd_NEXT {} {
		variable number_of_tips	;# Number of tips available
		variable current_tip	;# Number of the currently displayed tip

		incr current_tip
		if {$current_tip >= $number_of_tips} {
			set current_tip 0
		}
		display_tip $current_tip
	}

	## Show previous tip
	 # @return void
	proc tip_otd_PREV {} {
		variable number_of_tips	;# Number of tips available
		variable current_tip	;# Number of the currently displayed tip

		incr current_tip -1
		if {$current_tip < 0} {
			set current_tip [expr {$number_of_tips - 1}]
		}
		display_tip $current_tip
	}

	## Adjust base configuration file to variable "tip_of_the_day_show_again"
	 # @return void
	proc tip_otd_show_again {} {
		variable tip_of_the_day_show_again	;# Bool: Show "Tip of the day"

		::configDialogues::global::set_variable tips $tip_of_the_day_show_again
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

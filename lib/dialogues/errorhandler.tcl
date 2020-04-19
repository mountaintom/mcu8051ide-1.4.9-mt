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
if { ! [ info exists _ERRORHANDLER_TCL ] } {
set _ERRORHANDLER_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Background error handler
# --------------------------------------------------------------------------

namespace eval ErrorHandler {
	variable num_of_opened	0	;# Int: Number of currently opened dialogues
	variable count		0	;# Int: Counter of ivokations
	variable enabled	1	;# Bool: Dialog window enabled

	## Open dialog window
	 # @parm String message - Error message
	 # @return void
	proc open_dialog {message} {
		variable count		;# Int: Counter of ivokations
		variable enabled	;# Bool: Dialog window enabled
		variable num_of_opened	;# Int: Number of currently opened dialogues

		if {$num_of_opened > 2} {
			puts stderr "ERROR MESSAGE SUPPRESED (too many error dialogues opened at the time)"
			return
		}
		incr num_of_opened

		# Send error message to standard error output
		puts stderr [string repeat # 64]
		puts stderr "#                       PROGRAM ERROR                          #"
		puts stderr [string repeat # 64]
		puts stderr $::errorInfo
		puts stderr [string repeat # 64]

		# Save log file
		if {![catch {set log_file [open [file join ${::X::defaultDirectory} mcu8051ide_errors.log] a]}]} {
			puts $log_file [string repeat # 64]
			puts $log_file "Program version:\t${::VERSION}"
			puts $log_file "Tcl version:\t\t${::tcl_version}"
			puts $log_file "Tk version:\t\t${::tk_version}"
			puts $log_file [string repeat - 64]
			puts $log_file $::errorInfo
			close $log_file
		}

		# Create dialog window
		if {!$enabled} {return}
		incr count
		set win [toplevel .error_dialog$count -bg {#EE0000} -class {Error message} -bg ${::COMMON_BG_COLOR}]

		# Create window frames
		set main_frame [frame $win.main_frame]
		set top_frame [frame $main_frame.top_frame -bg {#EE0000}]
		set middle_frame [frame $main_frame.middle_frame]
		set bottom_frame [frame $main_frame.bottom_frame]

		# Create window header
		pack [label $top_frame.header_lbl				\
			-text [mc "PROGRAM ERROR  "]				\
			-bg {#EE0000} -fg {#FFFFFF}				\
			-font [font create					\
				-family helvetica				\
				-size [expr {int(-24 * $::font_size_factor)}]	\
				-weight bold					\
			]	\
		] -side left -fill x -expand 1

		# Create error message text and scrollbar
		pack [text $middle_frame.text				\
			-bg {white} -bd 0				\
			-yscrollcommand "$middle_frame.scrollbar set"	\
			-width 0 -height 0 -relief flat -wrap word	\
		] -side left -fill both -expand 1 -padx 5 -pady 5
		bind $middle_frame.text <Button-1> {focus %W}
		pack [ttk::scrollbar $middle_frame.scrollbar	\
			-orient vertical			\
			-command "$middle_frame.text yview"	\
		] -fill y -side right

		# Create text tags
		$middle_frame.text tag configure tag_bold			\
			-font [font create					\
				-family $::DEFAULT_FIXED_FONT			\
				-weight bold					\
				-size [expr {int(-12 * $::font_size_factor)}]	\
			]
		$middle_frame.text tag configure tag_tt				\
			-font [font create					\
				-family $::DEFAULT_FIXED_FONT			\
				-size [expr {int(-12 * $::font_size_factor)}]	\
			]
		$middle_frame.text tag configure tag_big_bold			\
			-font [font create					\
				-family {helvetica}				\
				-weight bold					\
				-size [expr {int(-17 * $::font_size_factor)}]	\
			]

		# Write error message
		$middle_frame.text insert end [mc "Program version: %s\n" "${::VERSION}"]
		$middle_frame.text insert end [mc "Error log saved in: %s\n" "${::X::defaultDirectory}[file separator]mcu8051ide_errors.log"]
		$middle_frame.text insert end [mc "Please send this file to %s\n\n\n" {<martin.osmera@moravia-microsystems.com>}]
		create_link_tag_in_text_widget $middle_frame.text
		convert_all_https_to_links $middle_frame.text
		$middle_frame.text tag add tag_big_bold 1.0 4.0
		$middle_frame.text insert end [mc "ERROR DETAILS:\n--------------\n"]
		$middle_frame.text tag add tag_bold 6.0 8.0
		$middle_frame.text insert end $::errorInfo
		$middle_frame.text tag add tag_tt 8.0 end
		$middle_frame.text configure -state disabled

		# Create button frame
		pack [ttk::button $bottom_frame.skip			\
			-text [mc "Skip errors"]			\
			-compound left					\
			-command "
				set ::ErrorHandler::enabled 0
				::ErrorHandler::close_dialog $count
			"	\
		] -side left
		pack [ttk::button $bottom_frame.ok			\
			-text [mc "Close"]			 	\
			-style GreenBg.TButton				\
			-command "::ErrorHandler::close_dialog $count"	\
		] -side right
		focus -force $bottom_frame.ok

		# Pack window frames
		pack $top_frame -fill x -anchor n
		pack $middle_frame -fill both -expand 1
		pack $bottom_frame -fill x
		pack $main_frame -fill both -expand 1 -padx 5 -pady 5

		# Configure dialog window
		set x [expr {[winfo screenwidth $win] / 2 - 225}]
		set y [expr {[winfo screenheight $win] / 2 - 125}]
		wm iconphoto $win ::ICONS::16::bug
		wm title $win [mc "PROGRAM ERROR - MCU 8051 IDE"]
		wm minsize $win 450 250
		wm geometry $win =550x250+$x+$y
		wm protocol $win WM_DELETE_WINDOW "::ErrorHandler::close_dialog $count"
		update
		raise $win
		catch {grab $win}
	}

	## Close dialog window
	 # @parm Int number - Dialog unique number
	 # @return void
	proc close_dialog {number} {
		variable num_of_opened	;# Int: Number of currently opened dialogues

		incr num_of_opened -1
		destroy .error_dialog$number
	}
}

# Register error handler
proc bgerror {message} {
	::ErrorHandler::open_dialog $message
}

# >>> File inclusion guard
}
# <<< File inclusion guard

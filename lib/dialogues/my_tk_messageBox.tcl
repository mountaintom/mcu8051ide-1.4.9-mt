#!/usr/bin/tclsh
# Part of MCU 8051 IDE ( http://http://www.moravia-microsystems.com/mcu8051ide )

############################################################################
#    Copyright (C) 2009, 2010, 2011, 2012 by Martin Ošmera                 #
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
if { ! [ info exists _MY_TK_MESSAGEBOX_TCL ] } {
set _MY_TK_MESSAGEBOX_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Replacement for Tk's tk_messageBox. Usage is the same as tk_messageBox,
# except for one thing, this one supports also "-icon ok".
# --------------------------------------------------------------------------

## This namespace implements dialog itself, but does not contain the
 # "tk_messageBox" function to invoke it. This function is defined onwards, but
 # still in this file.
namespace eval my_tk_messageBox {
	## Namespace variables
	variable return_value	{}	;# String: Dialog return value (e.g. "abort")
	variable dialog			;# Widget: Dialog toplevel window
	variable count		0	;# Int: Counter of object instances
	 # Buttons available in the dialog
	variable available_buttons {
		abort		retry		ignore
		ok		cancel		yes
		no
	}
	 # Icons for available buttons
	variable button_icons {
		button_cancel	reload		forward
		ok		cancel		ok
		no
	}

	## Invoke the dialog
	 # @parm Int arg_default	- Number of default button (0..2)
	 # @parm String arg_icon	- Dialog icon (one of values mentioned in variable button_icons)
	 # @parm String arg_message	- Message to display to the user
	 # @parm Widget arg_parent	- GUI parent
	 # @parm String arg_title	- Dialog title
	 # @parm String arg_type	- Name of big icon displyed beside the message (one of {error info question warning ok})
	 # @return String - Dialog return value, name of pressed button
	proc create {arg_default arg_icon arg_message arg_parent arg_title arg_type} {
		variable return_value {}	;# String: Dialog return value (e.g. "abort")
		variable button_icons		;# Icons for available buttons
		variable available_buttons	;# Buttons available in the dialog
		variable dialog			;# Widget: Dialog toplevel window
		variable count			;# Int: Counter of object instances

		set dialog [toplevel .my_tk_messageBox_${count}]
		set buttons [list]
		incr count

		# Translate icon name
		switch -- $arg_icon {
			{error} {
				set iconphoto	{cancel}
				set arg_icon	{messagebox_critical}
			}
			{info} {
				set iconphoto	{info}
				set arg_icon	{messagebox_info}
			}
			{question} {
				set iconphoto	{help}
				set arg_icon	{help}
			}
			{warning} {
				set iconphoto	{status_unknown}
				set arg_icon	{messagebox_warning}
			}
			{ok} {
				set iconphoto	{ok}
				set arg_icon	{button_ok}
			}
		}

		# Determinate list of buttons
		switch -- $arg_type {
			{abortretryignore} {
				set buttons [list abort retry ignore]
			}
			{ok} {
				set buttons [list ok]
			}
			{okcancel} {
				set buttons [list ok cancel]
			}
			{retrycancel} {
				set buttons [list retry cancel]
			}
			{yesno} {
				set buttons [list yes no]
			}
			{yesnocancel} {
				set buttons [list yes no cancel]
			}
		}

		# Adjuts argument "default"
		if {$arg_default == {}} {
			set arg_default [lindex $buttons 0]
		} elseif {[lsearch -ascii -exact $buttons $arg_default] == -1} {
			error "my_tk_messageBox: Invalid value of agument -default, must be one of: $buttons"
		}

		# Create top frame (dialog icon and text of the message)
		set top_frame [frame $dialog.top]
		pack [label $top_frame.img -image ::ICONS::32::$arg_icon] -side left -padx 5
		pack [label $top_frame.txt -text $arg_message -wraplength 300 -justify left] -side left -fill both -padx 5

		# Create bottom bar with dialog buttons
		set bottom_frame [frame $dialog.bottom]
		foreach button $buttons {
			set button_icon [lindex $button_icons [		\
				lsearch $available_buttons $button	\
			]]

			set text [string toupper [string index $button 0]]
			append text [string range $button 1 end]

			pack [ttk::button $bottom_frame.button_${button}		\
				-text [mc $text] -compound left				\
				-image ::ICONS::16::$button_icon			\
				-command "::my_tk_messageBox::button_press $button"	\
			] -side left -padx 2
			bind $bottom_frame.button_${button} <Return> "::my_tk_messageBox::button_press $button"
			bind $bottom_frame.button_${button} <KP_Enter> "::my_tk_messageBox::button_press $button"
			bind $bottom_frame.button_${button} <Escape> "
				grab release $dialog
				destroy $dialog
				set ::my_tk_messageBox::return_value {}
			"
		}

		# Pack window frames
		pack $top_frame -expand 1 -pady 10 -padx 5
		pack $bottom_frame -padx 5 -pady 10

		# Window manager options -- modal window
		wm iconphoto $dialog ::ICONS::16::$iconphoto
		wm title $dialog $arg_title
		wm state $dialog normal
		focus -force $bottom_frame.button_${arg_default}
		if {$arg_parent != {}} {
			wm transient $dialog $arg_parent
		}
		wm protocol $dialog WM_DELETE_WINDOW "
			grab release $dialog
			destroy $dialog
			set ::my_tk_messageBox::return_value {}
		"

		update

		if {![winfo exists $dialog]} {
			return $return_value
		}
		catch {
			grab $dialog
		}

		# Wait for user response
		tkwait window $dialog

		# Destroy dialog and return name of pressed button
		catch {
			grab release $dialog
			destroy $dialog
		}
		return $return_value
	}

	## Handles button press
	 # @parm String value - Name of pressed button
	 # @return void
	proc button_press {value} {
		variable return_value 	;# String: Dialog return value (e.g. "abort")g
		variable dialog		;# Widget: Dialog toplevel window

		grab release $dialog
		destroy $dialog
		set return_value $value
	}

	## Load needed images from the specified directory
	 # @parm String directory - Source directory
	 # @return void
	proc load_images {directory} {
		foreach subdir {16x16 32x32} ns {16 32} icons {
			{cancel info help status_unknown ok button_cancel reload forward no}
			{messagebox_critical messagebox_info help messagebox_warning button_ok}
		} \
		{
			foreach icon $icons {
				set filename [file join $directory {../icons} $subdir "${icon}.png"]

				if {[catch {
					image create photo ::ICONS::${ns}::${icon} -format png -file $filename
				} result]} then {
					puts stderr {}
					puts -nonewline stderr $result
					image create photo ::ICONS::${ns}::${icon}
				}
			}
		}
	}
}

## Replacement for Tk's command "tk_messageBox"
 # Usage is the same as "tk_messageBox" ...
proc my_tk_messageBox args {
	set length [llength $args]
	if {$length % 2} {
		error "my_tk_messageBox: Odd number of arguments given"
	}

	set arg_default	{}
	set arg_icon	{info}
	set arg_message	{}
	set arg_parent	{}
	set arg_title	{}
	set arg_type	{}

	for {set i 0; set j 1} {$i < $length} {incr i 2; incr j 2} {
		set attr [lindex $args $i]
		set val [lindex $args $j]

		switch -- $attr {
			{-default} {
				set arg_default $val
			}
			{-icon} {
				if {[lsearch -ascii -exact {error info question warning ok} $val] == -1} {
					error "my_tk_messageBox: Invalid message box icon: $val"
				}
				set arg_icon $val
			}
			{-message} {
				set arg_message $val
			}
			{-parent} {
				if {![winfo exists $val]} {
					error "my_tk_messageBox: Window $val does not exist."
				}
				set arg_parent $val
			}
			{-title} {
				set arg_title $val
			}
			{-type} {
				if {[lsearch -ascii -exact {abortretryignore ok okcancel retrycancel yesno yesnocancel} $val] == -1} {
					error "my_tk_messageBox: Invalid message box type: $val"
				}
				set arg_type $val
			}
			default {
				error "my_tk_messageBox: Unknown argument: $attr"
			}
		}
	}

	if {![string length $arg_message]} {
		error "my_tk_messageBox: No message box text specified"
	}
	if {![string length $arg_title]} {
		if {![string length $arg_icon]} {
			set arg_title {Message}
		} else {
			set arg_title [string toupper [string index $arg_icon 0]]
			append arg_title [string range $arg_icon 1 end]
		}
	}
	if {![string length $arg_type]} {
		set arg_type {ok}
	}

	return [my_tk_messageBox::create $arg_default $arg_icon $arg_message $arg_parent $arg_title $arg_type]
}

# Replace Tk's command "tk_messageBox"
rename tk_messageBox old_tk_messageBox
rename my_tk_messageBox tk_messageBox

# >>> File inclusion guard
}
# <<< File inclusion guard

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
if { ! [ info exists _VIRTUAL_HW_COMPONENT_TCL ] } {
set _VIRTUAL_HW_COMPONENT_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# Base class for virtual hardware components
# --------------------------------------------------------------------------

class VirtualHWComponent {
	public common count		0	;# Int: Counter of object instances
	public common hlp_dlg_count	0	;# Int: Counter of help dialog instances

	# Create fonts used in the text
	public common hlp_normal_font [font create			\
		-family {helvetica}				\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight {normal}				\
	]
	public common hlp_bold_font [font create			\
		-family {helvetica}				\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight {bold}					\
	]

	protected variable config_menu_created	0	;# Bool: COnfiguration menu created
	protected variable conf_menu		{}	;# Widget: Menu - Configuration menu

	protected variable modified		0	;# Bool: Flag modified

	protected variable project			;# Object: Project object
	protected variable win			{}	;# Widget: Dialog window
	protected variable drawing_on		1	;# Bool: Flag panel enabled
	protected variable canvas_widget	{}	;# Widget: Canvas widget - crucial part of the window
	protected variable start_stop_button		;# Widget: Button "ON/OFF"
	protected variable conf_button			;# Widget: Button to invoke configuration menu

	protected variable component_name	{}	;# String: Name of this VHW component
	protected variable class_name		{}	;# String: Name of class of this VHW component
	protected variable component_icon	{}	;# String: Name of icon of this VHW component
	protected variable current_filename	{}	;# String: Full name of file the current configuration

	## Object constructor
	 # Increments counter of class instances
	constructor {} {
		incr count
	}

	## Object destructor
	destructor {
	}

	## Close dialog window
	 # Ask user for save, call "close_window_special" and destroy the object
	 # @return void
	public method close_window {} {
		if {$modified} {
			switch -- [tk_messageBox	\
				-type yesnocancel	\
				-icon question		\
				-parent $win		\
				-title [mc "Component modified"]	\
				-message [mc "Do you want to save the configuration of this panel before closing?"] \
			] {
				{yes} {
					save_as

					if {$modified} {
						return
					}
				}
				{no} {
				}
				default {
					return
				}
			}
		}

		$this close_window_special
		delete object $this
	}

	## Set modified flag to 1, here and in whole PALE system
	 # @return void
	public method set_modified {} {
		set modified 1
		$project pale_set_modified

		if {[winfo exists $win]} {
			wm title $win "\[modified\] [regsub {^\[modified\] } [wm title $win] {}]"
		}

		return 1
	}

	## Set modified flag to 0
	 # @return void
	public method clear_modified {} {
		set modified 0

		if {[winfo exists $win]} {
			wm title $win [regsub {^\[modified\] } [wm title $win] {}]
		}
	}

	## Invoke configuration menu
	 # Call "config_menu_special" before popup
	 # @return void
	public method config_menu {} {
		if {!$config_menu_created} {
			create_config_menu
		}

		set x [winfo rootx $conf_button]
		set y [winfo rooty $conf_button]
		incr y [winfo height $conf_button]

		$this config_menu_special

		tk_popup $conf_menu $x $y
	}

	## Create configuration menu widgets
	 # Call create_config_menu_special after widgets were created
	 # @return void
	protected method create_config_menu {} {
		set config_menu_created 1
		set conf_menu $win.conf_menu
		menuFactory [subst -nocommands "\${${class_name}::CONFMENU}"]	\
			$conf_menu 0 "$this " 0 {} [$this info class]

		$this create_config_menu_special
	}

	## Action "Save as"
	 # @return void
	public method save_as {} {
		# Create file selection dialog
		catch {delete object ::fsd}
		KIFSD::FSD ::fsd	 				\
			-title "[mc {Save configuration}] - [mc $component_name] - [$project cget -projectName] - MCU 8051 IDE"	\
			-master $win					\
			-directory [$project cget -projectPath]		\
			-initialfile [file tail $current_filename]	\
			-defaultmask 0 -multiple 0 -filetypes [list		\
				[list [mc "VH component"]	{*.vhc}	]	\
				[list [mc "All files"]		{*}	]	\
			]

		# Open file after press of OK button
		::fsd setokcmd "$this save_config_to_file \[::fsd get\]"

		# activate the dialog
		::fsd activate
	}

	## Action "Open file"
	 # @return void
	public method load_from {} {
		# Create file selection dialog
		catch {delete object ::fsd}
		KIFSD::FSD ::fsd	 				\
			-title "[mc {Load configuration}] - [mc $component_name] - [$project cget -projectName] - MCU 8051 IDE"	\
			-master $win					\
			-directory [$project cget -projectPath]		\
			-initialfile [file tail $current_filename]	\
			-defaultmask 0 -multiple 0 -filetypes [list		\
				[list [mc "VH component"]	{*.vhc}	]	\
				[list [mc "All files"]		{*}	]	\
			]

		# Open file after press of OK button
		::fsd setokcmd "$this load_config_from_file \[::fsd get\]"

		# activate the dialog
		::fsd activate
	}

	## Save configuration to the specified file
	 # @parm String filename - Name of target file
	 # @return Bool - 1 upon success; 0 upon fail
	public method save_config_to_file {filename} {
		# Adjust file name
		if {![string length $filename]} {
			return 0
		}
		set filename [file join [$project cget -ProjectDir] $filename]

		# Adjust file extension
		if {![regexp {\.vhc$} $filename]} {
			append filename {.vhc}
		}

		if {[file exists $filename]} {
			if {[tk_messageBox	\
				-type yesno	\
				-icon question	\
				-parent $win	\
				-title [mc "Overwrite file"]	\
				-message [mc "A file with name '%s' already exists.  Do you want to overwrite it?" [file tail $filename]]
				] != {yes}
			} then {
				return 0
			}
		}

		# Create backup file
		if {[file isfile $filename]} {
			catch {
				file rename -force $filename "$filename~"
			}
		}

		# Try to open the file
		if {[catch {
			set file [open $filename {w} 0640]
		}]} then {
			tk_messageBox		\
				-type ok	\
				-icon error	\
				-parent $win	\
				-title [mc "IO Error"]	\
				-message [mc "Unable to write to file:\n\"%s\"" $filename]
			return 0
		}

		# Gain configuration list
		set config [$this get_config]
		lset config {1 2} {}	;# Remove geometry information

		# Save configuration to the file
		puts $file "# MCU 8051 IDE: Virtual HW component configuration file"
		puts $file "# Project: [$project cget -projectName]"
		puts $file "# Component: $component_name\n"
		puts $file $config

		# Finalize
		set current_filename $filename
		close $file
		clear_modified
		return 1
	}

	## Load configuration from the specified file
	 # @parm String filename - Name of source file
	 # @return void
	public method load_config_from_file {filename} {
		# Try to open the file
		if {[catch {
			set file [open $filename {r}]
		}]} then {
			tk_messageBox		\
				-type ok	\
				-icon error	\
				-parent $win	\
				-title [mc "IO Error"]	\
				-message [mc "Unable to read file:\n\"%s\"" $filename]
			return 0
		}

		# Read file line by line
		while {![eof $file]} {
			set line [gets $file]

			# Skip empty lines and comments
			if {$line == {} || [regexp {^\s*#} $line]} {continue}

			# Decomposite file records
			set obj [lindex $line 0]	;# VHW Object
			set conf [lindex $line 1]	;# Configuration

			# Detect wrong object name
			if {$obj != $class_name} {
				tk_messageBox		\
					-type ok	\
					-parent $win	\
					-icon error	\
					-title [mc "File corrupted"]	\
					-message [mc "Unable to read configuration from file:\n\"%s\"" $filename]
				return 0
			}

			# Set configuration for this component
			if {![$this set_config $conf]} {
				tk_messageBox		\
					-type ok	\
					-parent $win	\
					-icon error	\
					-title  [mc "File corrupted"]	\
					-message [mc "Unable to read configuration from file:\n\"%s\"" $filename]
				return 0
			}

			# Only first configuration record is accepted
			break
		}

		# Finalize ...
		set current_filename $filename
		close $file
		clear_modified
		return 1
	}

	## Show help dialog
	 # @parm Bool leave_empty=0 - Do not write implicitly anything into the help window
	 # @return void
	public method show_help {{leave_empty 0}} {
		# Increment counter of help dialog instances
		incr hlp_dlg_count

		# Create toplevel window
		set dialog [toplevel .help_dialog_${class_name}_${hlp_dlg_count} -class {Help} -bg ${::COMMON_BG_COLOR}]

		## Create top frame (header and icon)
		set top_frame [frame $dialog.top_frame]
		 # Icon
		pack [label $top_frame.header_image	\
			-image ::ICONS::22::$component_icon	\
		] -side left -padx 10
		 # Header text
		pack [label $top_frame.header_label	\
			-anchor w -justify left		\
			-text [namespace eval ::$class_name "mc {$component_name}"]	\
		] -side left
		pack $top_frame -anchor n -pady 2

		## Create main frame (text and scrollbar)
		set main_frame [frame $dialog.main_frame]
		 # Text widget
		set text_widget [text $main_frame.text			\
			-width 0 -height 0 -font $hlp_normal_font	\
			-yscrollcommand "$main_frame.scrollbar set"	\
			-wrap word -padx 5 -pady 5			\
		]
		pack $text_widget -side left -fill both -expand 1
		 # Scrollbar
		pack [ttk::scrollbar $main_frame.scrollbar	\
			-orient vertical			\
			-command "$text_widget yview"		\
		] -side right -fill y
		 # Finalize ...
		pack $main_frame -fill both -expand 1 -padx 2

		 # Button "Close"
		pack [ttk::button $dialog.close_button		\
			-text [mc "Close"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command "destroy $dialog"		\
		] -ipady 0 -pady 2


		# Create text tags in the text widget
		$text_widget tag configure tag_bold -font $hlp_bold_font

		# Fill in the text widget with the help message
		$this show_help_special $text_widget

		if {!$leave_empty} {
			## Display section "Wire colors"
			$text_widget insert insert "\n\n"
			$text_widget insert insert [mc "Wire colors:"]
			$text_widget tag add tag_bold {insert linestart}  {insert lineend}
			$text_widget insert insert "\n"
			 # Create canvas widget
			set cw [canvas $text_widget.canvas\
				-bg {#FFFFFF}		\
				-takefocus 0		\
				-cursor left_ptr	\
				-bd 0 -relief flat	\
				-width 170 -height 110	\
			]
			bind $cw <Button-5> "$text_widget yview scroll +5 units; break"
			bind $cw <Button-4> "$text_widget yview scroll -5 units; break"
			 # Fill in the canvas widget
			$project Graph_create_legend $cw 1
			 # Show the canvas widget
			$text_widget window create insert -window $cw
		}

		# Finalize ...
		$text_widget configure -state disabled
		wm minsize $dialog [expr {int(300 * $::font_size_factor)}] [expr {int(300 * $::font_size_factor)}]
		wm title $dialog [namespace eval ::$class_name "mc {$component_name}"]
		wm iconphoto $dialog ::ICONS::16::help
		focus -force $dialog.close_button
	}

	## Commit new on/off state
	 # @parm Bool state - 1 == ON; 0 == OFF
	 # @return void
	public method on_off {state} {
		# Adjust flag panel enabled
		set drawing_on $state

		## Adjust apparence of "ON/OFF" button
		 # Turn ON
		if {$state} {
			$start_stop_button configure -style GreenBg.TButton -text [mc "ON"]
		 # Turn OFF
		} else {
			$start_stop_button configure -style RedBg.TButton -text [mc "OFF"]
		}

		# Call component specific procedure
		$this on_off_special
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

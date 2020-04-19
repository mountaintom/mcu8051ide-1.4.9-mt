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
if { ! [ info exists _SUBPROGRAMS_TCL ] } {
set _SUBPROGRAMS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides panel for watching subprogram calls
# --------------------------------------------------------------------------

class SubPrograms {
	## COMMON
	public common fsd_filename	{}	;# Filename choosen by FSD
	 # Main font for the text widget
	public common main_font	[font create			\
		-family {helvetica}				\
		-size [expr {int(-14 * $::font_size_factor)}]	\
	]
	 # Bold font for the text widget
	public common bold_font	[font create			\
		-family {helvetica}				\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight {bold}					\
	]
	 # Font for status bar below the text box
	public common large_font	[font create			\
		-family {helvetica}				\
		-size [expr {int(-14 * $::font_size_factor)}]	\
	]
	 # Bold font for status bar below the text box
	public common large_bold_font	[font create			\
		-family {helvetica}				\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight {bold}					\
	]

	## PRIVATE
	private variable parent			;# Widget: parent widget
	private variable subp_gui_initialized 0	;# Bool: GUI initialized

	private variable text_widget		;# Widget: Text widget containg almost all the information
	private variable scrollbar		;# Widget: Scrollbar for the text widget
	private variable enable_chbut		;# Widget: Check button "Enable"
	private variable intr_chbut		;# Widget: Check button "Include interrupts"
	private variable total_val_lbl		;# Widget: Label containg the count of subprograms recorded
	private variable menu		{}	;# Widget: Popup menu for the text widget
	private variable enabled	1	;# Bool: Panel active
	private variable ena_intr	1	;# Bool: Taking interrupts enabled
	private variable return_but		;# Widget: Button "RETURN"
	private variable save_but		;# Widget: Button "Save"
	private variable clear_but		;# Widget: Button "Clear"
	private variable count		0	;# Int: Number of subprograms mentioned in the text widget
	private variable menu_source	{}	;# String: Auxiliary variable for the popup menu -- Source address
	private variable menu_target	{}	;# String: Auxiliary variable for the popup menu -- Target address

	constructor {} {
	}

	destructor {
		if {$subp_gui_initialized} {
			menu_Sbar_remove $menu
		}
	}

	## Prepare this panel for initialization of its GUI
	 # MUST BE called before "CreateSubProgramsGUI"
	 # @parm Widget _parent - Frame where this panel would be created
	 # @return void
	public method PrepareSubPrograms {_parent} {
		set parent $_parent
		set subp_gui_initialized 0
		load_config $::CONFIG(SUBP_MON_CONFIG)
	}

	## Finalize initialization of this panel
	 # @return void
	public method CreateSubProgramsGUI {} {
		create_gui
		subprograms_create_tags
		create_menus
		set_bindings
	}

	## Get configuration list for this panel
	 # @return void
	public method subprograms_get_config {} {
		return [list $enabled $ena_intr]
	}

	## Load configuration list for this panel
	 # @parm List conf - Configuration list
	 # @return void
	private method load_config {conf} {
		if {![regexp {^[01] [01]$} $conf]} {
			return
		}
		set enabled [lindex $conf 0]
		set ena_intr [lindex $conf 1]
	}

	## Create all widgets which this panel consist of
	 # @return void
	private method create_gui {} {
		if {$subp_gui_initialized} {return}
		set subp_gui_initialized 1

		# Create top frame (checkbuttons)
		set top_frame [frame $parent.top]
		set enable_chbut [checkbutton $top_frame.enable_chbut	\
			-text [mc "Enable"]				\
			-command "$this subprograms_dis_ena"		\
		]
		set intr_chbut [checkbutton $top_frame.intr_chbut	\
			-text [mc "Include interrupts"]			\
			-command "$this subprograms_intr_yesno"		\
		]
		pack $enable_chbut	-side left -padx 10
		pack $intr_chbut	-side left -padx 10

		# Adjust check buttons
		if {$enabled} {
			$enable_chbut select
		} else {
			$enable_chbut deselect
		}
		if {$ena_intr} {
			$intr_chbut select
		} else {
			$intr_chbut deselect
		}

		# Create button frame (Buttons: Save, Clear and Return)
		set button_frame [frame $parent.button_frame]
		set return_but [ttk::button $button_frame.return_but	\
			-text [mc "RETURN"]				\
			-compound left					\
			-image ::ICONS::16::button_cancel		\
			-command "$this subprograms_force_return"	\
			-state disabled					\
			-width 7					\
		]
		set clear_but [ttk::button $button_frame.clear_but	\
			-text [mc "Clear"]				\
			-style Flat.TButton				\
			-compound left					\
			-state disabled					\
			-image ::ICONS::16::editdelete			\
			-command "$this subprograms_clear"		\
			-width 5					\
		]
		set save_but [ttk::button $button_frame.filesaveas	\
			-text [mc "Save"]				\
			-style Flat.TButton				\
			-compound left					\
			-state disabled					\
			-image ::ICONS::16::filesaveas			\
			-command "$this subprograms_save"		\
			-width 5					\
		]
		pack $save_but -pady 0 -side left
		pack $clear_but -pady 0 -side left -padx 5
		pack $return_but -pady 0 -side right

		# Create middle frame (text widget and its scrollbar)
		set middle_frame [frame $parent.middle]
		set text_widget [text $middle_frame.text		\
			-yscrollcommand "$middle_frame.scrollbar set"	\
			-bg {#FFFFFF} -width 0 -height 0		\
			-font $main_font -insertontime 0 -wrap none	\
			-cursor left_ptr -takefocus 0			\
			-tabstyle wordprocessor				\
		]
		set scrollbar [ttk::scrollbar $middle_frame.scrollbar	\
			-orient vertical				\
			-command "$text_widget yview"			\
		]
		pack $text_widget -side left -fill both -expand 1
		pack $scrollbar -side right -fill y -after $text_widget

		# Create bottom frame
		set bottom_frame [frame $parent.bottom]
		pack [label $bottom_frame.total_lbl		\
			-text [mc "TOTAL: "] -font $large_font	\
			-fg {#555555}				\
		] -side left
		set total_val_lbl [label $bottom_frame.total_val_lbl	\
			-font $large_bold_font -text {0}		\
		]
		pack $total_val_lbl -side left

		# Pack all main frames
		pack $top_frame		-fill x
		pack $button_frame	-fill x
		pack $middle_frame	-fill both -expand 1
		pack $bottom_frame	-fill x -side bottom
	}

	## Set event bindings for the text widget
	 # @return void
	private method set_bindings {} {
		foreach event {
			<B1-Enter>	<B1-Leave>
			<B2-Motion>	<Button-5>	<Button-4>
			<MouseWheel>
		} {
			bind $text_widget $event [bind Text $event]
		}
		bind $text_widget <Button-1> "$this subprograms_click %x %y"
		bind $text_widget <ButtonRelease-3> "$this subprograms_popup %x %y %X %Y"
		bindtags $text_widget $text_widget
	}

	## Create popup menu for the text widget
	 # @return void
	private method create_menus {} {
		set menu "$text_widget.popup_menu"
		if {[winfo exists $menu]} {destroy $menu}
		menuFactory {
			{command	{Go to source line}			{}	0	"subprograms_menu_action 0"
				{goto}	"Navigate code editor to the line from which this subprogram was invoked"}
			{command	{Go to target line}			{}	0	"subprograms_menu_action 1"
				{goto}	"Navigate code editor to the line from where this subprogram resides"}
			{separator}
			{command	{Copy source address to clipboard}	{}	0	"subprograms_menu_action 2"
				{editcopy}	"Copy return address to clipboard (hexadecimal representation)"}
			{command	{Copy target address to clipboard}	{}	0	"subprograms_menu_action 3"
				{editcopy}	"Copy address where this subprogram begins to the clipboard"}
			{separator}
			{command	{Remove this}				{}	0	"subprograms_menu_action 4"
				{editdelete}	"Remove this entry"}
		} $menu 0 "$this " 0 {} [namespace current]
	}

	## Create highlighting tags for the text widget
	 # @return void
	private method subprograms_create_tags {} {
		$text_widget tag configure tag_sel -borderwidth 1 -relief raised
		$text_widget tag configure tag_from -foreground {#00AA00}
		$text_widget tag configure tag_to -foreground {#0000AA}
		$text_widget tag configure tag_ins -font $bold_font
		$text_widget tag configure tag_first -background {#DDDDDD}
	}

	## Toggle state enabled for whole panel
	 # @return void
	public method subprograms_dis_ena {} {
		set enabled [expr {!$enabled}]
		if {$enabled} subprograms_clear
	}

	## Toggle flag "Enable interrupts"
	 # @return void
	public method subprograms_intr_yesno {} {
		set ena_intr [expr {!$ena_intr}]
	}

	## Event handler for the text widget: <Button-1>
	 # @parm Int x - Relative pointer position
	 # @parm Int y - Relative pointer position
	 # @return void
	public method subprograms_click {x y} {
		set menu_source {}
		set menu_target {}
		$text_widget configure -state normal

		# Remove selection and determinate line number
		$text_widget tag remove tag_sel 1.0 end
		set line [expr {int([$text_widget index @$x,$y])}]

		# Adjust selection
		if {$line % 3} {
			set line [expr {($line / 3) * 3}]
			if {($line / 3) < $count} {
				# Set selection
				incr line
				$text_widget tag add tag_sel $line.0 [expr {$line+2}].0

				# Determinate source address of the selected subprogram
				regexp {\w+\s*$} [$text_widget get	\
					$line.0 [list $line.0 lineend]	\
				] menu_target
				set menu_target [string trimright $menu_target { h}]
				if {![string is xdigit $menu_target]} {
					set menu_target {}
				}

				# Determinate target address of the selected subprogram
				regexp {\w+\s*$} [$text_widget get		\
					[expr {$line + 1}].0			\
					[list [expr {$line + 1}].0 lineend]	\
				] menu_source
				set menu_source [string trimright $menu_source { h}]
				if {![string is xdigit $menu_source]} {
					set menu_source {}
				}
			}
		}

		# Disable the text widget again
		$text_widget configure -state disabled
	}

	## Perform certain menu action (popup menu for the text widget)
	 # @parm Int action - ID of action to execute
	 # @return void
	public method subprograms_menu_action {action} {
		switch -- $action {
			0 {	;# Action: "Go to source line"
				if {$menu_source != {}} {
					goto_line [expr {"0x$menu_source" - 1}]
				}
			}
			1 {	;# Action: "Go to target line"
				if {$menu_target != {}} {
					goto_line [expr "0x$menu_target"]
				}
			}
			2 {	;# Action: "Copy source address to clipboard"
				clipboard clear
				clipboard append $menu_source
			}
			3 {	;# Action: "Copy target address to clipboard"
				clipboard clear
				clipboard append $menu_target
			}
			4 {	;# Remove this entry
				if {[llength [$text_widget tag nextrange tag_sel 1.0]]} {
					$text_widget configure -state normal
					$text_widget delete tag_sel.first tag_sel.last+1l
					$text_widget configure -state disabled
				}
			}
		}
	}

	## Action: "Go to source line" / "Go to target line"
	 # @parm Int address - Address in code memory
	 # @return void
	private method goto_line {address} {
		# Resolve line number and source address
		set line [$this simulator_address2line $address]
		set address [$this simulator_line2address [lindex $line 0] [lindex $line 1]]

		# Line resolved
		if {$line != {}} {
			# Simulator is running
			if {[$this is_frozen]} {
				$this setPC $address
				$this Simulator_sync_PC_etc
				$this move_simulator_line $line
			# Simulator is not running
			} else {
				set filename [$this simulator_get_filename [lindex $line 1]]
				set filename [file tail $filename]
				if {[$this fucus_specific_editor $filename 0]} {
					$this editor_procedure {} goto [lindex $line 0]
				}
			}
		# Line unresolved
		} else {
			tk_messageBox		\
				-parent .	\
				-title [mc "Line not found"]	\
				-message [mc "There is no matching line in the source code"]
		}
	}

	## Invoke popup menu for the text widget
	 # @parm Int x - Relative position of mouse pointer
	 # @parm Int y - Relative position of mouse pointer
	 # @parm Int X - Absolute position of mouse pointer
	 # @parm Int Y - Absolute position of mouse pointer
	 # @return void
	public method subprograms_popup {x y X Y} {
		# Adjust selection
		subprograms_click $x $y

		# Determinate line and what to do with the menu
		set line [expr {int([$text_widget index @$x,$y])}]
		if {$line % 3} {
			set line [expr {$line / 3}]
			if {$line >= $count} {
				set state {disabled}
			} else {
				set state {normal}
			}
		} else {
			set state {disabled}
		}

		# Adjust states of certain items in the menu
		foreach entry {
			{Go to source line}
			{Go to target line}
			{Copy source address to clipboard}
			{Copy target address to clipboard}
			{Remove this}
		} {
			$menu entryconfigure [::mc $entry] -state $state
		}

		# Invoke the menu
		tk_popup $menu $X $Y
	}

	## Register subprogram call
	 # @parm Int type	- Invoked by: 0 == LCALL; 1 == ACALL; 2 == Interrupt; 3 == LCALL or ACALL
	 # @parm Int from	- Source address (return address)
	 # @parm Int to		- Target address
	 # @return void
	public method subprograms_call {type from to} {
		if {!$enabled} {return}
		if {!$subp_gui_initialized} CreateSubProgramsGUI

		# Determinate string to print as an instruction
		switch -- $type {
			0 {set ins " LCALL\t"}
			1 {set ins " ACALL\t"}
			2 {
				set ins " Interrupt\t"
				if {!$ena_intr} {
					return
				}
			}
			3 {set ins " CALL\t"}
		}

		# Convert value of source address to hexadecimal representation
		if {$from < 0} {
			set from {-----}
		} else {
			set from [format %X $from]
			set len [string length $from]
			if {$len < 4} {
				set from "[string repeat {0} [expr {4 - $len}]]$from"
			}
			append from {h}
		}

		# Convert value of target address to hexadecimal representation
		if {$to < 0} {
			set to {-----}
		} else {
			set to [format %X $to]
			set len [string length $to]
			if {$len < 4} {
				set to "[string repeat {0} [expr {4 - $len}]]$to"
			}
			append to {h}
		}

		# Enable the text widget
		$text_widget configure -state normal

		# Insert separator
		if {$count} {
			$text_widget insert 1.0 "\n"
		}

		# Print return address
		$text_widget insert 1.0 "\n"
		$text_widget insert 1.0 [mc " Return address:\t"]
		set idx [$text_widget index {1.0 lineend}]
		$text_widget insert {1.0 lineend} $from
		$text_widget tag add tag_from $idx {1.0 lineend}

		# Print type and target address
		$text_widget insert 1.0 "\n"
		$text_widget insert 1.0 "$ins\t"
		$text_widget tag add tag_ins 1.0 {1.0 lineend}
		set idx [$text_widget index {1.0 lineend}]
		$text_widget insert {1.0 lineend} $to
		$text_widget tag add tag_to $idx {1.0 lineend}

		$text_widget tag remove tag_first 1.0 end
		$text_widget tag add tag_first 1.0 3.0

		# Disable the text widget, adjust button bar, labels on the bottom
		$text_widget configure -state disabled
		incr count
		$total_val_lbl configure -text $count
		disena_buttonbar $count
	}

	## Disable or enable buttons on the button bar
	 # @parm Bool bool - 1 == enable; 0 == diable
	 # @return void
	private method disena_buttonbar {bool} {
		if {$bool} {
			set state {normal}
		} else {
			set state {disabled}
		}
		$return_but configure -state $state
		$clear_but configure -state $state
		$save_but configure -state $state
	}

	## Register return for subprogram
	 # @parm Bool intr__sub - 0 == Common subprogram; 1== Interrupt
	 # @return void
	public method subprograms_return {intr__sub} {
		if {!$enabled} {return}
		if {!$count} {return}
		if {$intr__sub && !$ena_intr} {return}
		if {!$subp_gui_initialized} CreateSubProgramsGUI

		$text_widget configure -state normal
		$text_widget delete 1.0 4.0
		$text_widget configure -state disabled
		incr count -1
		if {$count} {
			$text_widget tag remove tag_first 1.0 end
			$text_widget tag add tag_first 1.0 3.0
		}
		$total_val_lbl configure -text $count
		disena_buttonbar $count
	}

	## Clear the text widget
	 # @return void
	public method subprograms_clear {} {
		if {!$subp_gui_initialized} {return}
		set count 0
		$total_val_lbl configure -text 0
		$text_widget configure -state normal
		$text_widget delete 1.0 end
		$text_widget configure -state disabled
		disena_buttonbar 0
	}

	## Enable or disable this panel
	 # @parm Bool bool - 1 == Enable; 0 == Disbale
	 # @return void
	public method subprograms_setEnabled {bool} {
		if {!$subp_gui_initialized} {return}
		if {!$bool} {
			$return_but configure -state disabled
		}
	}

	## Force return from active subprogram (the topmost entry)
	 # Binding for button "RETURN" on the button bar
	 # @return void
	public method subprograms_force_return {} {
		if {![regexp {^\s*\w+} [$text_widget get 1.0 3.0] word]} {
			return
		}
		set word [string trim $word]
		if {$word == {Interrupt}} {
			set word 1
		} else {
			set word 0
		}
		$this simulator_return_from_SP $word
	}

	## Invoke file selection dialog to save file
	 # Binding for button "Save" on the button bar
	 # @return void
	public method subprograms_save {} {

		# Invoke the dialog
	 	catch {delete object fsd}
		KIFSD::FSD fsd	 					\
			-title [mc "Save file - MCU 8051 IDE"]		\
			-directory [$this cget -projectPath]	\
			-defaultmask 0 -multiple 0 -filetypes [list		\
				[list [mc "Plain text"]		{*.txt}	]	\
				[list [mc "All files"]		{*}	]	\
			]

		# Ok button
		fsd setokcmd {
			set fsd_filename [::SubPrograms::fsd get]
			if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
				if {![regexp "^(~|/)" $fsd_filename]} {
				set filename "[${::X::actualProject} cget -ProjectDir]/$fsd_filename"
				}
			} else {	;# Microsoft windows way
				if {![regexp {^\w:} $fsd_filename]} {
					set filename [file join [${::X::actualProject} cget -ProjectDir] $fsd_filename]
				}
			}

			set ::SubPrograms::fsd_filename [file normalize $fsd_filename]
		}

		# Activate the dialog
		fsd activate
		if {$fsd_filename != {}} {
			subprograms_save_proc $fsd_filename
		}
	}

	## Save content of the text widget under certain filename
	 # @parm String filename - Target filename
	 # @return void
	public method subprograms_save_proc {filename} {
		# Adjust file extension
		if {[file extension [file tail $filename]] != {.txt}} {
			append filename {.txt}
		}
		# Make backup copy of the file
		if {[file exists $filename] && [file isfile $filename]} {
			# Ask user for overwrite existing file
			if {[tk_messageBox	\
				-type yesno	\
				-icon question	\
				-parent .	\
				-title [mc "Overwrite file"]	\
				-message [mc "A file name '%s' already exists. Are you sure you want to overwrite it ?" [file tail $filename]]
				] != {yes}
			} then {
				return
			}
			# Create a backup file
			catch {
				file rename -force $filename "$filename~"
			}
		}
		# Try to open the file
		if {[catch {
			set file [open $filename w 0640]
		}]} then {
			tk_messageBox		\
				-parent .	\
				-icon warning	\
				-type ok	\
				-title [mc "Permission denied"]	\
				-message [mc "Unable to write to file:\n\"%s\"" $filename]
			return
		}
		# Write content of the text widget into the file and close the file
		puts -nonewline $file [$text_widget get 1.0 end]
		close $file
	}

	## Get number of recorder active subprograms
	 # @return Int - Count
	public method subprograms_get_count {} {
		if {!$subp_gui_initialized} {return 0}
		return $count
	}

	## Get content for purpose of program hibernation
	 # @return String - Text
	public method subprograms_get_formatted_content {} {
		if {!$subp_gui_initialized} {return {}}
		set result {}
		set source {}
		set target {}
		set type {}
		set line_num 0

		foreach line [split [$text_widget get 1.0 end] "\n"] {
			if {$line == {}} {
				if {$source != {} && $target != {} && $type != {}} {
					lappend result [list $source $target $type]
				}
				set line 0
				set source {}
				set target {}
				set type {}
				continue
			}
			if {$line_num} {
				regexp {\w+\s*$} $line source
				set source [string range $source 0 3]
				set source [expr "0x$source"]
			} else {
				regexp {\w+\s*$} $line target
				set target [string range $target 0 3]
				set target [expr "0x$target"]

				regexp {^\s*\w+} $line type
				switch -- [string trim $type] {
					{LCALL}		{set type 0}
					{ACALL}		{set type 1}
					{Interrupt}	{set type 2}
					{CALL}		{set type 3}
				}
			}
			incr line_num
		}
		return $result
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

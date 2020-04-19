
#!/usr/bin/tclsh
# Part of MCU 8051 IDE ( http://http://www.moravia-microsystems.com/mcu8051ide )

############################################################################
#    Copyright (C) 2011 by Martin Ošmera                                   #
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
if { ! [ info exists _FILE_INTERFACE_TCL ] } {
set _FILE_INTERFACE_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# File interface for the PALE subsystem, allow to read files as input for
# GPIO for simulated MCU and record changes in GPIO to a file
# -------------------------------------------------------------------------

class PaleFileInterface {
	inherit VirtualHWComponent

	# Font: Font to be used in the panel -- bold
	public common cb_font [font create				\
		-weight bold					\
		-size [expr {int(-10 * $::font_size_factor)}]	\
		-family {helvetica}				\
	]
	public common text_font [font create				\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-family ${::DEFAULT_FIXED_FONT}			\
	]
	public common text_font_bold [font create			\
		-weight bold					\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-family ${::DEFAULT_FIXED_FONT}			\
	]

	public common COMPONENT_NAME	"VHW File Interface"	;# Name of this component
	public common CLASS_NAME	"PaleFileInterface"	;# Name of this class
	public common COMPONENT_ICON	{compfile1}		;# Icon for this panel (16x16)

	# Configuration menu
	public common CONFMENU {
		{command	{Sync. files now}	{}	1	"sync"	{filesave}
			"Flush output file buffer"}
		{checkbutton	"Keep files synchronized"	{}	{::PaleFileInterface::_keep_sync}
			1 0 0	{keep_sync_changed}
			""}
		{separator}
		{command	{Show help}		{}	5	"show_help"	{help}
			"Show brief help"}
		{separator}
		{command	{Save configuration}	{}	0	"save_as"	{filesave}
			"Save configuration into a file"}
		{command	{Load configuration}	{}	0	"load_from"	{fileopen}
			"Load configuration from a file"}
		{separator}
		{checkbutton	"Window always on top"	{}	{::PaleFileInterface::menu_keep_win_on_top}
			1 0 0	{keep_win_on_top_changed}
			""}
	}

	public common _keep_sync		0

	private variable connection_port	;# Array of Int: Index is key number, value is port number or {-}
	private variable connection_pin		;# Array of Int: Index is key number, value is bit number or {-}
	private variable enaged			;# Array of Bool: enaged(port_num,bit_num) --> Is connected to this device ?
	private variable keep_win_on_top 0	;# Bool: Toplevel window
	private variable cb
	private variable usr_note

	private variable read_text_widget
	private variable read_file_entry
	private variable read_select_file_but
	private variable read_start_stop_but

	private variable write_file_entry
	private variable write_select_file_but
	private variable write_start_stop_but
	private variable write_trunc_but
	private variable write_status_lbl

	private variable file_to_read_is_opened		0
	private variable file_to_write_to_is_opened	0

	private variable file_to_read_channel		{}
	private variable file_to_write_to_channel	{}

	private variable current_input		{}
	private variable last_read_line		{}
	private variable last_written_line	{}

	private variable keep_sync		0
	private variable write_counter


	# ------------------------------------------------------------------
	# INTERNAL APPLICATION LOGIC
	# ------------------------------------------------------------------

	## Object constructor
	 # @parm Object _project - Project object
	constructor {_project} {
		# Configure local ttk styles
		ttk::style configure PaleFileInterface_FileInUse.TEntry		\
			-fieldbackground {#DDFFDD}
		ttk::style map PaleFileInterface_FileInUse.TEntry		\
			-fieldbackground [list {readonly !readonly} {#DDFFDD}]

		ttk::style configure PaleFileInterface_FileFound.TEntry		\
			-fieldbackground {#FFFFAA}
		ttk::style map PaleFileInterface_FileFound.TEntry		\
			-fieldbackground [list {readonly !readonly} {#FFFFAA}]

		ttk::style configure PaleFileInterface_FileNotFound.TEntry	\
			-fieldbackground {#FFDDDD}
		ttk::style map PaleFileInterface_FileNotFound.TEntry		\
			-fieldbackground [list {readonly !readonly} {#FFDDDD}]

		# Set object variables identifing this component (see the base class)
		set component_name	$COMPONENT_NAME
		set class_name		$CLASS_NAME
		set component_icon	$COMPONENT_ICON

		# Set other object variables
		set project $_project
		set radio_buttons 1
		array set connection_port	{0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 - 9 - 10 - 11 - 12 - 13 - 14 - 15 -}
		array set connection_pin	{0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 - 9 - 10 - 11 - 12 - 13 - 14 - 15 -}
		for {set port 0} {$port < 5} {incr port} {
			for {set bit 0} {$bit < 8} {incr bit} {
				set enaged($port,$bit) 0
			}
		}

		# Inform PALE
		$project pale_register_input_device $this
		$project pale_set_modified

		# Create panel GUI
		create_gui
		mcu_changed
		on_off [$project pale_is_enabled]

		# ComboBoxes to default state
		for {set i 0} {$i < 16} {incr i} {
			$cb(b$i) current 0
			$cb(p$i) current 0
		}
	}

	## Object destructor
	destructor {
		# Inform PALE
		$project pale_unregister_input_device $this

		# Destroy GUI
		destroy $win
	}

	## Value of configuration menu variable "keep_win_on_top" has been changed
	 # @return void
	public method keep_win_on_top_changed {} {
		set keep_win_on_top $PaleFileInterface::menu_keep_win_on_top
		if {$keep_win_on_top} {
			wm attributes $win -topmost 1 -alpha 0.8
		} else {
			wm attributes $win -topmost 0 -alpha 1.0
		}
	}

	## Reevaluate array of MCU port pins engaged by this device
	 # @return void
	private method evaluete_enaged_pins {} {
		# Mark all as disengaged and infrom PALE
		for {set port 0} {$port < 5} {incr port} {
			for {set bit 0} {$bit < 8} {incr bit} {
				if {$enaged($port,$bit)} {
					$project pale_disengage_pin_by_input_device $port $bit $this
					set enaged($port,$bit) 0
				}
			}
		}

		# Find the engaged ones and infrom PALE
		for {set i 8} {$i < 16} {incr i} {
			set port $connection_port($i)
			set bit $connection_pin($i)

			if {$port == {-} || $bit == {-}} {
				continue
			}

			set enaged($port,$bit) 1
			$project pale_engage_pin_by_input_device $port $bit $this
		}
	}

	## Reconnect the specified key to another port pin
	 # @parm Int i - Key number (0..7)
	 # @return void
	public method reconnect {i} {
		# Adjust connections
		set connection_port($i) [$cb(p$i) get]
		set connection_pin($i)	[$cb(b$i) get]
		if {$connection_pin($i) != {-}} {
			set connection_pin($i)	[expr {7 - $connection_pin($i)}]
		}

		# Reevaluate array of MCU port pins engaged by this device
		evaluete_enaged_pins

		# Inform PALE system about the change in order
		#+ to make immediate change in device states
		if {$drawing_on} {
			$project pale_reevaluate_IO
		}

		# Set flag modified
		set_modified
	}

	public method keep_sync_changed {} {
		set keep_sync ${::PaleFileInterface::_keep_sync}
	}

	public method sync {} {
		if {$file_to_write_to_is_opened} {
			flush $file_to_write_to_channel
		}
	}

	## Create GUI of this panel
	 # @return void
	private method create_gui {} {
		#
		set win [toplevel .pale_file_interface$count -class $component_name -bg ${::COMMON_BG_COLOR}]


		set top_frame [frame $win.top_frame]
		# Create "ON/OFF" button
		set start_stop_button [ttk::button $top_frame.start_stop_button	\
			-command "$this on_off_button_press"				\
			-style Flat.TButton						\
			-width 3							\
		]
		DynamicHelp::add $start_stop_button -text [mc "Turn HW simulation on/off"]
		setStatusTip -widget $start_stop_button -text [mc "Turn HW simulation on/off"]
		bind $start_stop_button <Button-3> "$this on_off_button_press; break"
		pack $start_stop_button -side left
		bindtags $start_stop_button [list $start_stop_button TButton all .]
		# Create configuration menu button
		set conf_button [ttk::button $top_frame.conf_but	\
			-image ::ICONS::16::configure			\
			-style Flat.TButton				\
			-command "$this config_menu"			\
		]
		setStatusTip -widget $conf_button -text [mc "Configure"]
		pack $conf_button -side left
		bindtags $conf_button [list $conf_button TButton all .]
		#
		pack [label $top_frame.note_lbl -text [mc "Note: "]] -side left
		set usr_note [ttk::entry $top_frame.usr_note		\
			-validate key					\
			-validatecommand [list $this set_modified]	\
			-width 0					\
		]
		pack $usr_note -side left -fill x -expand 1
		bindtags $top_frame.usr_note [list $top_frame.usr_note TEntry $win all .]

		set write_labelframe [ttk::labelframe $win.write_labelframe -text [mc "Write"] -padding 5]
		for {set i 0} {$i < 8} {incr i} {
			set j $i

			set cb(p$j) [ttk::combobox $write_labelframe.cb_p$i	\
				-width 1					\
				-font $cb_font					\
				-state readonly					\
			]

			set cb(b$j) [ttk::combobox $write_labelframe.cb_b$i	\
				-width 1					\
				-font $cb_font					\
				-values {- 0 1 2 3 4 5 6 7}			\
				-state readonly					\
			]

			grid $cb(p$j) -row 2 -column [expr {$i + 1}]
			grid $cb(b$j) -row 3 -column [expr {$i + 1}]

			bind $cb(p$j) <<ComboboxSelected>> [list $this reconnect $i]
			bind $cb(b$j) <<ComboboxSelected>> [list $this reconnect $i]

			bindtags $cb(p$j) [list $cb(p$j) TCombobox all .]
			bindtags $cb(b$j) [list $cb(b$j) TCombobox all .]
		}
		grid [label $write_labelframe.port_lbl	\
			-text [mc "PORT"]		\
		] -row 2 -column 0 -sticky w
		grid [label $write_labelframe.pin_lbl	\
			-text [mc "PIN"]		\
		] -row 3 -column 0 -sticky w
		grid [label $write_labelframe.file_lbl	\
			-text [mc "File: "]		\
		] -row 0 -column 0 -sticky w
		set write_file_entry [ttk::entry $write_labelframe.entry	\
			-width 0						\
			-validate key						\
			-validatecommand [list $this vcmd_write_file_entry %P]	\
		]
		DynamicHelp::add $write_file_entry -text [mc "Name of output file"]
		setStatusTip -widget $write_file_entry -text [mc "Name of output file"]
		bindtags $write_file_entry [list $write_file_entry TEntry $win all .]
		grid $write_file_entry -row 0 -column 1 -columnspan 5 -sticky we
		set write_select_file_but [ttk::button $write_labelframe.write_select_file_but	\
			-image ::ICONS::16::fileopen						\
			-style Flat.TButton							\
			-command [list $this write_select_file]					\
		]
		DynamicHelp::add $write_select_file_but -text [mc "Select file"]
		setStatusTip -widget $write_select_file_but -text [mc "Select file"]
		bindtags $write_select_file_but [list $write_select_file_but TButton all .]
		grid $write_select_file_but -row 0 -column 6 -sticky we
		set write_start_stop_but [ttk::button $write_labelframe.start_stop_but \
			-image ::ICONS::16::player_play		\
			-style Flat.TButton			\
			-command [list $this write_start_stop]	\
			-state disabled				\
		]
		DynamicHelp::add $write_start_stop_but -text [mc "Open or close the file"]
		setStatusTip -widget $write_start_stop_but -text [mc "Open or close the file"]
		bindtags $write_start_stop_but [list $write_start_stop_but TButton all .]
		grid $write_start_stop_but -row 0 -column 7 -sticky we
		set write_trunc_but [ttk::button $write_labelframe.trunc_but	\
			-image ::ICONS::16::editdelete				\
			-style Flat.TButton					\
			-command [list $this write_trunc]			\
			-state disabled						\
		]
		DynamicHelp::add $write_trunc_but -text [mc "Truncate the file"]
		setStatusTip -widget $write_trunc_but -text [mc "Truncate the file"]
		bindtags $write_trunc_but [list $write_trunc_but TButton all .]
		grid $write_trunc_but -row 0 -column 8 -sticky we
		set write_status_lbl [label $write_labelframe.write_status_lbl	\
			-justify right -anchor e				\
		]
		grid $write_status_lbl -row 4 -column 0 -columnspan 9 -sticky e
		grid rowconfigure $write_labelframe 1 -minsize 5

		set read_labelframe [ttk::labelframe $win.read_labelframe -text [mc "Read"] -padding 5]
		for {set i 0} {$i < 8} {incr i} {
			set j [expr {$i + 8}]

			set cb(p$j) [ttk::combobox $read_labelframe.cb_p$i	\
				-width 1					\
				-font $cb_font					\
				-state readonly					\
			]

			set cb(b$j) [ttk::combobox $read_labelframe.cb_b$i	\
				-width 1					\
				-font $cb_font					\
				-values {- 0 1 2 3 4 5 6 7}			\
				-state readonly					\
			]

			grid $cb(p$j) -row 2 -column [expr {$i + 1}]
			grid $cb(b$j) -row 3 -column [expr {$i + 1}]

			bind $cb(p$j) <<ComboboxSelected>> [list $this reconnect $j]
			bind $cb(b$j) <<ComboboxSelected>> [list $this reconnect $j]

			bindtags $cb(p$j) [list $cb(p$j) TCombobox all .]
			bindtags $cb(b$j) [list $cb(b$j) TCombobox all .]
		}
		grid [label $read_labelframe.port_lbl	\
			-text [mc "PORT"]		\
		] -row 2 -column 0 -sticky w
		grid [label $read_labelframe.pin_lbl	\
			-text [mc "PIN"]		\
		] -row 3 -column 0 -sticky w
		set read_text_widget [text $read_labelframe.text	\
			-height 3					\
			-width 0					\
			-state disabled					\
			-font $text_font				\
			-tabstyle wordprocessor				\
			-undo 0						\
			-exportselection 1				\
			-wrap word					\
		]
		$read_text_widget tag configure tag_current_line -font $text_font_bold
		$read_text_widget tag configure tag_log_0 -foreground {#00FF00}
		$read_text_widget tag configure tag_log_1 -foreground {#FF0000}
		$read_text_widget tag configure tag_hfl -foreground {#FF00AA}
		$read_text_widget tag configure tag_nv -foreground {#888888}
		$read_text_widget tag configure tag_noice -foreground {#FF8800}
		DynamicHelp::add $read_text_widget -text [mc "View on the file"]
		setStatusTip -widget $read_text_widget -text [mc "View on the file"]
		bindtags $read_text_widget [list $read_text_widget Ttext $win all .]
		grid $read_text_widget -row 4 -column 0 -columnspan 9 -sticky we
		grid [label $read_labelframe.file_lbl	\
			-text [mc "File: "]		\
		] -row 0 -column 0 -sticky w
		set read_file_entry [ttk::entry $read_labelframe.entry		\
			-width 0						\
			-validate key						\
			-validatecommand [list $this vcmd_read_file_entry %P]	\
		]
		DynamicHelp::add $read_file_entry -text [mc "Name of input file"]
		setStatusTip -widget $read_file_entry -text [mc "Name of input file"]
		bindtags $read_file_entry [list $read_file_entry TEntry $win all .]
		grid $read_file_entry -row 0 -column 1 -columnspan 5 -sticky we
		set read_select_file_but [ttk::button $read_labelframe.read_select_file_but	\
			-image ::ICONS::16::fileopen						\
			-style Flat.TButton							\
			-command [list $this read_select_file]					\
		]
		DynamicHelp::add $read_select_file_but -text [mc "Select file"]
		setStatusTip -widget $read_select_file_but -text [mc "Select file"]
		bindtags $read_select_file_but [list $read_select_file_but TButton all .]
		grid $read_select_file_but -row 0 -column 6 -sticky we
		set read_start_stop_but [ttk::button $read_labelframe.start_stop_but	\
			-image ::ICONS::16::player_play					\
			-style Flat.TButton						\
			-command [list $this read_start_stop]				\
			-state disabled							\
		]
		DynamicHelp::add $read_start_stop_but -text [mc "Open or close the file"]
		setStatusTip -widget $read_start_stop_but -text [mc "Open or close the file"]
		bindtags $read_start_stop_but [list $read_start_stop_but TButton all .]
		grid $read_start_stop_but -row 0 -column 7 -sticky we
		grid rowconfigure $read_labelframe 1 -minsize 5


		pack $read_labelframe -fill x -pady 3 -padx 5 -side right
		pack $top_frame -fill x -padx 5 -pady 2 -side bottom
		pack $write_labelframe -fill x -pady 3 -padx 5

		# Set window parameters
		wm iconphoto $win ::ICONS::16::$component_icon
		wm title $win "[mc $component_name] - [$project cget -projectName] - MCU 8051 IDE"
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW "$this close_window"
		bindtags $win [list $win Toplevel all .]
	}

	## Determinate which port pin is connected to the specified key
	 # @parm Int i - Key number
	 # @return List - {port_number bit_number}
	private method which_port_pin {i} {
		return [list $connection_port($i) $connection_pin($i)]
	}

	## Handle "ON/OFF" button press
	 # Turn whole PALE system on or off
	 # @return void
	public method on_off_button_press {} {
		$project pale_all_on_off
	}

	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE -- CALLED FROM PALE ENGINE
	# ------------------------------------------------------------------

	## Simulated MCU has been changed
	 # @return void
	public method mcu_changed {} {
		# Refresh lists of possible values in port selection ComboBoxes
		set available_ports [concat - [$project pale_get_available_ports]]

		for {set i 0} {$i < 16} {incr i} {
			$cb(p$i) configure -values $available_ports

			if {[lsearch -ascii -exact $available_ports $connection_port($i)] == -1} {
				$cb(p$i) current 0
				set connection_port($i) {-}
			}
		}
	}

	## Evaluate new state of ports
	 # @parm List state	- Port states ( 5 x {8 x bit} -- {bit0 bit1 bit2 ... bit7} )
	 # @return state	- New port states modified by this device
	 # 			  format is the same as parameter $state
	 #
	 # Possible bit values:
	 #	'|' - High frequency
	 #	'X' - Access to external memory
	 #	'?' - No volatge
	 #	'-' - Indeterminable value (some noise)
	 #	'=' - High forced to low
	 #	'0' - Logical 0
	 #	'1' - Logical 1
	public method new_state {_state} {
		upvar $_state state

		if {$file_to_write_to_is_opened} {
			set line [list]
			for {set i 0} {$i < 8} {incr i} {
				set pp [which_port_pin $i]

				if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
					lappend line {-}
				} else {
					lappend line [lindex $state $pp]
				}
			}
			if {$last_written_line != $line} {
				set last_written_line $line

				puts -nonewline $file_to_write_to_channel [$project get_run_statistics 0]
				puts -nonewline $file_to_write_to_channel "\t"
				puts $file_to_write_to_channel $line
				if {$keep_sync} {
					flush $file_to_write_to_channel
				}
				incr write_counter
				$write_status_lbl configure -text [mc "%d changes recorded" $write_counter]
			}
		}

		if {[catch {
			if {$file_to_read_is_opened} {
				if {$last_read_line == {}} {
					set last_read_line [gets $file_to_read_channel]
				}

				while {![eof $file_to_read_channel]} {
					if {
						($current_input == {})
							||
						([lindex $last_read_line 0] <= [$project get_run_statistics 0])
					} then {
						$read_text_widget configure -state normal
						$read_text_widget delete 0.0 end
						$read_text_widget insert 1.0 "\n\n"

						$read_text_widget insert 1.0 $current_input
						insert_last_read_line

						set current_input $last_read_line
						set flag 0
						while {![eof $file_to_read_channel]} {
							set last_read_line [gets $file_to_read_channel]
							regsub -all {\s*#.*$} $last_read_line {} last_read_line
							if {[string length $last_read_line]} {
								set flag 1
								break
							}
						}

						if {$flag} {
							$read_text_widget insert 3.0 $last_read_line
						}
						$read_text_widget configure -state disabled
					} else {
						break
					}
				}

				if {[llength $current_input] != 9} {
					error
				}
				for {set i 0} {$i < 0} {incr i} {
					if {[lsearch -ascii -exact {| X ? - = 0 1} [lindex $current_input $i]] == -1} {
						error
					}
				}

				for {set i 8; set j 1} {$i < 16} {incr i; incr j} {
					set pp [which_port_pin $i]

					if {[lindex $pp 0] == {-} || [lindex $pp 1] == {-}} {
						# nothing
					} else {
						lset state $pp [lindex $current_input $j]
					}
				}
			}
		}]} then {
			tk_messageBox \
				-parent $win \
				-icon warning \
				-title [mc "I/O Error"] \
				-message [mc "File corrupted:\n\"%s\"." [$read_file_entry get]] \
				-type ok
			read_start_stop
		}
	}

	private method insert_last_read_line {} {
		$read_text_widget insert 2.0 $last_read_line
		$read_text_widget tag add tag_current_line 2.0 3.0

		set j 1
		set k 0
		for {set i 8} {$i > 0} {incr i -1} {
			switch -- [lindex $last_read_line $i] {
				{0} {	;# Logical 0
					set tag {tag_log_0}
				}
				{1} {	;# Logical 1
					set tag {tag_log_1}
				}
				{=} {	;# High forced to low
					set tag {tag_hfl}
				}
				{?} {	;# No volatge
					set tag {tag_nv}
				}
				default {
					set tag {tag_noice}
				}
			}
			$read_text_widget tag add $tag [list 2.0 lineend - ${j}c] [list 2.0 lineend - ${k}c]

			incr j 2
			incr k 2
		}
	}

	## Withdraw panel window from the screen
	 # @return void
	public method withdraw_window {} {
		wm withdraw $win
	}

	## Get panel configuration list (usable with method "set_config")
	 # @return List - configuration list
	public method get_config {} {
		return [list		\
			$class_name	\
			[list		\
				[array get connection_port]	\
				[array get connection_pin]	\
				[wm geometry $win]		\
				[$usr_note get]			\
				[$read_file_entry get]		\
				[$write_file_entry get]		\
				$keep_sync			\
				$keep_win_on_top		\
			]	\
		]
	}

	## Set panel configuration from list gained from method "get_config"
	 # @parm List state - Configuration list
	 # @return void
	public method set_config {state} {
		if {[catch {
			# Load connections to the MCU
			array set connection_port [lindex $state 0]
			array set connection_pin [lindex $state 1]

			# Restore window geometry
			if {[string length [lindex $state 2]]} {
				wm geometry $win [regsub {^\=?\d+x\d+} [lindex $state 2] [join [wm size $win] {x}]]
			}

			# Load user note
			$usr_note delete 0
			$usr_note insert 0 [lindex $state 3]

			$read_file_entry delete 0
			$read_file_entry insert 0 [lindex $state 4]

			$write_file_entry delete 0
			$write_file_entry insert 0 [lindex $state 5]

			set keep_sync [lindex $state 6]

			if {[lindex $state 7] != {}} {
				set keep_win_on_top [lindex $state 7]
				if {$keep_win_on_top} {
					wm attributes $win -topmost 1 -alpha 0.8
				}
			}

			after 0 [subst {
				update
				$read_file_entry xview [$read_file_entry index end]
				$write_file_entry xview [$write_file_entry index end]
			}]

			# Restore state of ComboBoxes
			for {set i 0} {$i < 16} {incr i} {
				## PIN
				set pin $connection_pin($i)
				if {$pin != {-}} {
					set pin	[expr {7 - $pin}]
				}
				set idx [lsearch -ascii -exact	\
					[$cb(b$i) cget -values]	\
					$pin			\
				]
				if {$idx == -1} {
					set idx 0
				}
				$cb(b$i) current $idx

				## PORT
				set idx [lsearch -ascii -exact	\
					[$cb(p$i) cget -values]	\
					$connection_port($i)	\
				]
				if {$idx == -1} {
					set idx 0
				}
				$cb(p$i) current $idx
			}

			# Adjust internal logic and the rest of PALE
			evaluete_enaged_pins
			$project pale_reevaluate_IO
			update

		# Fail
		}]} then {
			puts "Unable to load configuration for $class_name"
			return 0

		# Success
		} else {
			clear_modified
			return 1
		}
	}

	## Simulated MCU has been reseted
	 # @return void
	public method reset {} {
		set state [$project pale_get_true_state]
		new_state state
	}

	public method read_select_file {{filename {}}} {
		if {$filename != {}} {
			$read_file_entry delete 0 end
			$read_file_entry insert 0 [lindex $filename 1]

			after 0 [subst {
				update
				$read_file_entry xview [$read_file_entry index end]
			}]
		} else {
			select_file [mc "Select file for reading"] [$read_file_entry get] read_select_file
		}
	}

	public method write_select_file {{filename {}}} {
		if {$filename != {}} {
			set filename [lindex $filename 1]
			if {[file extension $filename] == {}} {
				append filename {.gpio}
			}
			$write_file_entry delete 0 end
			$write_file_entry insert 0 $filename
			after 0 [subst {
				update
				$write_file_entry xview [$write_file_entry index end]
			}]
		} else {
			select_file [mc "Select file for writing"] [$write_file_entry get] write_select_file
		}
	}

	private method select_file {title initialfile cmd} {
		if {$initialfile == {}} {
			set directory [$project cget -projectPath]
		} else {
			set directory [file dirname $initialfile]
		}

		catch {delete object ::fsd}
		KIFSD::FSD ::fsd \
			-title $title \
			-directory $directory \
			-defaultmask 0 \
			-multiple 0 \
			-initialfile $initialfile \
			-master $win \
			-filetypes [list \
				[list [mc "General Purpose Input Output"]	{*.gpio}] \
				[list [mc "All files"]				{*}] \
			]

		::fsd setokcmd "$this $cmd \[list 1 \[::fsd get\]\]"
		::fsd activate
	}

	public method write_start_stop {{truncate 0}} {
		# Stop
		if {$file_to_write_to_is_opened} {
			if {[catch {
				close $file_to_write_to_channel
			}]} then {
				tk_messageBox \
					-parent $win \
					-icon warning \
					-title [mc "I/O Error"] \
					-message [mc "Unknown error occurred while closing file:\n\"%s\"." [$write_file_entry get]] \
					-type ok
			}
			set last_written_line {}
			set file_to_write_to_is_opened 0
			$write_start_stop_but configure -image ::ICONS::16::player_play
			$write_trunc_but configure -state disabled
			$write_select_file_but configure -state normal
			$write_file_entry configure -state normal
			$write_file_entry configure -style PaleFileInterface_FileFound.TEntry
			$write_status_lbl configure -text {}
			set write_counter 0
		# Start
		} else {
			if {[catch {
				if {$truncate} {
					set mode {w}
				} else {
					set mode {a}
				}
				set file_to_write_to_channel [open [$write_file_entry get] $mode]
			}]} then {
				tk_messageBox \
					-parent $win \
					-icon warning \
					-title [mc "Unable to open file"] \
					-message [mc "Unable to open file:\n\"%s\" for writing, please check your permissions." [$write_file_entry get]] \
					-type ok
			} else {
				set file_to_write_to_is_opened 1
				$write_start_stop_but configure -image ::ICONS::16::_player_pause
				$write_trunc_but configure -state normal
				$write_select_file_but configure -state disabled
				$write_file_entry configure -state readonly
				$write_file_entry configure -style PaleFileInterface_FileInUse.TEntry
			}
		}
	}
	public method write_trunc {} {
		if {!$file_to_write_to_is_opened} {
			return
		}

		write_start_stop
		write_start_stop 1
	}
	public method read_start_stop {} {
		# Stop
		if {$file_to_read_is_opened} {
			if {[catch {
				close $file_to_read_channel
			}]} then {
				tk_messageBox \
					-parent $win \
					-icon warning \
					-title [mc "I/O Error"] \
					-message [mc "Unknown error occurred while closing file:\n\"%s\"." [$read_file_entry get]] \
					-type ok
			}
			set file_to_read_is_opened 0
			$read_start_stop_but configure -image ::ICONS::16::player_play
			$read_select_file_but configure -state normal
			$read_file_entry configure -state normal
			$read_file_entry configure -style PaleFileInterface_FileFound.TEntry

			$read_text_widget configure -state normal
			$read_text_widget delete 0.0 end
			$read_text_widget configure -state disabled
		# Start
		} else {
			if {[catch {
				set file_to_read_channel [open [$read_file_entry get] {r}]
			}]} then {
				tk_messageBox \
					-parent $win \
					-icon warning \
					-title [mc "Unable to open file"] \
					-message [mc "Unable to open file:\n\"%s\" for reading, please check your permissions." [$read_file_entry get]] \
					-type ok
			} else {
				set file_to_read_is_opened 1
				$read_start_stop_but configure -image ::ICONS::16::_player_pause
				$read_select_file_but configure -state disabled
				$read_file_entry configure -state readonly
				$read_file_entry configure -style PaleFileInterface_FileInUse.TEntry
			}
		}
	}
	public method vcmd_read_file_entry {filename} {
		if {![string length $filename]} {
			$read_file_entry configure -style TEntry
			$read_start_stop_but configure -state disabled
		} elseif {[file exists $filename] && [file isfile $filename] && [file readable $filename]} {
			if {!$file_to_read_is_opened} {
				$read_file_entry configure -style PaleFileInterface_FileFound.TEntry
			} else {
				$read_file_entry configure -style PaleFileInterface_FileInUse.TEntry
			}
			$read_start_stop_but configure -state normal
		} else {
			$read_file_entry configure -style PaleFileInterface_FileNotFound.TEntry
			$read_start_stop_but configure -state disabled
		}

		return 1
	}
	public method vcmd_write_file_entry {filename} {
		if {![string length $filename]} {
			$write_file_entry configure -style TEntry
			$write_start_stop_but configure -state disabled
		} elseif {[file exists $filename] && [file isfile $filename] && [file readable $filename]} {
			if {!$file_to_write_to_is_opened} {
				$write_file_entry configure -style PaleFileInterface_FileFound.TEntry
			} else {
				$write_file_entry configure -style PaleFileInterface_FileInUse.TEntry
			}
			$write_start_stop_but configure -state normal
		} else {
			$write_file_entry configure -style PaleFileInterface_FileNotFound.TEntry
			$write_start_stop_but configure -state normal
		}

		return 1
	}

	# ------------------------------------------------------------------
	# VIRTUAL HW COMMON INTERFACE -- CALLED FROM THE BASE CLASS
	# ------------------------------------------------------------------

	## This method is called before configuration menu invocation
	 # @return void
	public method config_menu_special {} {
		set ::${class_name}::_keep_sync $keep_sync
		set ::${class_name}::menu_keep_win_on_top $keep_win_on_top
	}

	## This method is called after configuration menu has beed created
	 # @return void
	public method create_config_menu_special {} {
	}

	## This method is called to fill in the help dialog
	 # @parm Widget text_widget - Target text widget
	 # @return void
	 #
	 # Note: There is defined text tag "tag_bold" in the text widget
	public method show_help_special {text_widget} {
	}

	## This method is called before panel window closure
	 # @return void
	public method close_window_special {} {
	}

	## Commit new on/off state
	 # @return void
	public method on_off_special {} {
		set state [$project pale_get_true_state]
		new_state state
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

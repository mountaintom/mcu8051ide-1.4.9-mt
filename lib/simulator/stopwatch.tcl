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
if { ! [ info exists _STOPWATCH_TCL ] } {
set _STOPWATCH_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Stopwatch timer for MCU simulator
# --------------------------------------------------------------------------

class Stopwatch {
	## Class variables
	public common stopw_count	0	;# Int: Counter of class instances
	# List: Short names of stopwatch entries
	public common stats_keys {
		US		CC		IC
		IP		PB		IN
		SC		RT		RI
		BR
	}
	#  List: Full names of stopwatch entries
	public common stats_names {
		{Micro seconds}		{Clock cycles}	{Instruction cycles}
		{Instructions passed}	{Program bytes}	{Interrupts}
		{Subprogram calls}	{RET}		{RETI}
		{Breakpoints}
	}

	## Private varibales
	private variable win				;# Widget: Dialog window
	private variable obj_idx			;# Int: Current object number
	private variable entryboxes			;# Array of Widget: Entry boxes
	private variable clearbuttons			;# Array of Widget: Clear buttons
	private variable dialog_opened		0	;# Bool: 1 == Dialog opened; 0 == Dialog closed
	private variable status_bar_lbl			;# Widget: Status bar label widget
	private variable start_stop_button		;# Widget: Button "Start / Stop"
	private variable label_stopped_lbl		;# Widget: Label "Stoppped"
	private variable stopwatch_on		1	;# Bool: Stopwatch running
	private variable window_geometry	{}	;# Geometry: Window geometry

	constructor {} {
		# Configure ttk styles
		if {!$stopw_count} {
			ttk::style configure Stopwatch.TEntry -fieldreadonlybackground {#F8F8F8}
			ttk::style configure Stopwatch_Focused_D.TEntry -fieldbackground {#AAAAFF} -fieldreadonlybackground {#AAAAFF}
			ttk::style configure Stopwatch_Focused_D_Invalid.TEntry -fieldbackground {#AAAAFF} -foreground {#FF0000}
			ttk::style configure Stopwatch_Focused_I.TEntry -fieldbackground {#DDDDFF} -fieldreadonlybackground {#DDDDFF}
		}

		# Increment counter of object instances
		set obj_idx $stopw_count
		incr stopw_count

		# Restore configuration from the previous session
		set i 0
		set window_geometry [lindex ${::CONFIG(STOPWATCH_CONFIG)} $i]
		incr i
		set val [lindex ${::CONFIG(STOPWATCH_CONFIG)} $i]
		if {![string is digit -strict $val]} {
			set val 0
		}
		set ::Stopwatch::text_vars${obj_idx}(stop_sim) $val
		incr i
		foreach key $stats_keys {
			set val [lindex ${::CONFIG(STOPWATCH_CONFIG)} $i]
			if {![string is digit -strict $val]} {
				set val 0
			}
			set ::Stopwatch::text_vars${obj_idx}($key,S) $val
			incr i
		}
	}

	destructor {
		catch {
			array unset ::Stopwatch::text_vars${obj_idx}
		}
	}

	## Close window
	 # @return void
	public method stopwatch_close {} {
		set window_geometry [wm geometry $win]
		destroy $win
		set dialog_opened 0
	}

	## Open window
	 # @return void
	public method stopwatch_invoke_dialog {} {
		if {$dialog_opened} {return}
		set win [toplevel .stopwatch$obj_idx -class {Stopwatch} -bg ${::COMMON_BG_COLOR}]
		set dialog_opened 1
		set stopwatch_on 1

		stopwatch_create_gui
		stopwatch_refresh

		bind $win <Control-Key-q> "destroy $win; break"
		bindtags $win [list $win Toplevel all .]

		wm title $win "[mc {Stopwatch}] - [$this cget -projectName] - MCU 8051 IDE"
		wm iconphoto $win ::ICONS::22::history
		wm protocol $win WM_DELETE_WINDOW "$this stopwatch_close"
		wm resizable $win 0 0
		update
		catch {
			wm geometry $win [regsub {^\=?\d+x\d+} $window_geometry	\
				[regsub {\+\d+\+\d+$} [wm geometry $win] {}]	\
			]
		}
	}

	## Refresh window content (adjust to current simulator state)
	 # @return void
	public method stopwatch_refresh {} {
		if {!$dialog_opened} {return}

		array set run_statistics [$this get_run_statistics]
		set run_statistics(0) [expr {$run_statistics(0) / 1000}]
		set i 0
		set org_O 0
		set stop_a 0
		foreach key $stats_keys {
			# Overall
			set org_O [subst -nocommands "\$::Stopwatch::text_vars${obj_idx}($key,O)"]
			set ::Stopwatch::text_vars${obj_idx}($key,O) $run_statistics($i)

			# Current
			if {$stopwatch_on} {
				incr ::Stopwatch::text_vars${obj_idx}($key,C) [expr {$run_statistics($i) - $org_O}]
				set stop_a [subst -nocommands "\$::Stopwatch::text_vars${obj_idx}($key,S)"]

				# Conditional stop
				if {$stop_a && $stop_a <= [subst -nocommands "\$::Stopwatch::text_vars${obj_idx}($key,C)"]} {
					stopwatch_start_stop
					if {[subst -nocommands "\$::Stopwatch::text_vars${obj_idx}(stop_sim)"]} {
						if {[$this sim_run_in_progress]} {
							$this sim_run
						} elseif {[$this sim_anim_in_progress]} {
							$this sim_animate
						}
					}
				}
			}
			incr i
		}
	}

	## Create window GUI
	 # @return void
	private method stopwatch_create_gui {} {

		## Create bottom frame (status bar)
		set bottom_frame [frame $win.bottom_frame]
		set status_bar_lbl [label $bottom_frame.status_lbl	\
			-anchor w -justify left				\
		]
		pack $status_bar_lbl -fill x -side left


		## Create toolbar
		set top_frame [frame $win.top_frame]
		 # - Button "Start / Stop"
		set button [ttk::button $top_frame.start_but	\
			-command "$this stopwatch_start_stop"	\
			-style ToolButton.TButton		\
			-image ::ICONS::22::player_pause	\
		]
		set start_stop_button $button
		pack $button -side left -anchor w
		DynamicHelp::add $top_frame.start_but -text ""
		local_status_tip $top_frame.start_but [mc "Stop"]
		 # - Separator
		pack [ttk::separator $top_frame.sep0		\
			-orient vertical			\
		] -side left -fill y -anchor w -padx 2
		 # - Button "Save as plain text"
		set button [ttk::button $top_frame.save_but	\
			-command "$this stopwatch_save 1"	\
			-image ::ICONS::22::filesave		\
			-style ToolButton.TButton		\
		]
		pack $button -side left -anchor w
		DynamicHelp::add $top_frame.save_but -text ""
		local_status_tip $top_frame.save_but [mc "Save as plain text"]
		 # - Button "Save as XHTML"
		set button [ttk::button $top_frame.export_but	\
			-command "$this stopwatch_save 0"	\
			-image ::ICONS::22::html		\
			-style ToolButton.TButton		\
		]
		pack $button -side left -anchor w
		DynamicHelp::add $top_frame.export_but -text ""
		local_status_tip $top_frame.export_but [mc "Save as XHTML"]
		 # - Separator
		pack [ttk::separator $top_frame.sep1	\
			-orient vertical		\
		] -side left -fill y -anchor w -padx 2
		 # - Button "Close"
		set button [ttk::button $top_frame.exit_but	\
			-command "$this stopwatch_close"	\
			-image ::ICONS::22::exit		\
			-style ToolButton.TButton		\
		]
		pack $button -side left -anchor w
		DynamicHelp::add $top_frame.exit_but -text ""
		local_status_tip $top_frame.exit_but [mc "Close window"]
		 # - Label "STOPPED"
		set label_stopped_lbl [label $top_frame.label_stopped_lbl	\
			-font [font create					\
				-family {Helvetica}				\
				-size -21					\
				-weight bold					\
			] -text {STOPPED} -fg {#FF0000} -pady 0			\
		]

		## Create main frame
		set main_frame [frame $win.main_frame]
		# Create horizontal headers
		grid [label $main_frame.lbl_h_0	\
			-text [mc "Current"]	\
		] -sticky we -row 0 -column 2
		grid [ttk::button $main_frame.clr_C_but		\
			-image ::ICONS::16::clear_left_r	\
			-command "$this stopwatch_clear_all C"	\
			-style Flat.TButton			\
		] -sticky w -row 0 -column 3
		DynamicHelp::add $main_frame.clr_C_but	\
			-text [mc "Clear all"]
		local_status_tip $main_frame.clr_C_but [mc "Clear all"]
		grid [label $main_frame.lbl_h_1	\
			-text [mc "Stop after"]	\
		] -sticky we -row 0 -column 5
		grid [ttk::button $main_frame.clr_S_but		\
			-style Flat.TButton			\
			-image ::ICONS::16::clear_left_r	\
			-command "$this stopwatch_clear_all S"	\
		]  -sticky w -row 0 -column 6
		DynamicHelp::add $main_frame.clr_S_but	\
			-text [mc "Clear all"]
		local_status_tip $main_frame.clr_S_but [mc "Clear all"]
		grid [label $main_frame.lbl_h_2	\
			-text [mc "Overall"]		\
		] -sticky we -row 0 -column 8 -columnspan 2

		# Create matrix of entryboxes (and vertical headers)
		set row 1
		foreach text $stats_names key $stats_keys {
			# Vertical header
			grid [label $main_frame.lbl_f_$row	\
				-text [mc $text]		\
			] -sticky w -row $row -column 0

			# Create 3 entryboxes and 2 clear buttons
			set col 2
			foreach tp {C S O} {
				# Create clear button
				if {$tp != {O}} {
					set clearbuttons($key,$tp) [ttk::button $main_frame.clrbut_${key}_$tp	\
						-style Flat.TButton						\
						-image ::ICONS::16::clear_left					\
						-command "$this stopwatch_clear_entrybox $key $tp"		\
					]
					DynamicHelp::add $main_frame.clrbut_${key}_$tp	\
						-text [mc "Clear entrybox"]
				}

				# Clear entrybox
				set entrybox [ttk::entry $main_frame.entry_${key}_$tp				\
					-validatecommand "$this stopwatch_entrybox_validator $key $tp %P"	\
					-textvariable ::Stopwatch::text_vars${obj_idx}($key,$tp)		\
					-style Stopwatch.TEntry							\
					-validate key								\
					-width 12								\
				]
				bind $entrybox <Key-Up>			"$this stopwatch_entry_key $key $tp up;		break"
				bind $entrybox <Key-Down>		"$this stopwatch_entry_key $key $tp down;	break"
				bind $entrybox <Key-Left>		"$this stopwatch_entry_key $key $tp left;	break"
				bind $entrybox <Key-Right>		"$this stopwatch_entry_key $key $tp right;	break"
				bind $entrybox <Shift-Key-Left>		"continue"
				bind $entrybox <Shift-Key-Right>	"continue"
				bind $entrybox <Key-Tab>		"$this stopwatch_entry_key $key $tp tab;	break"
				if {!$::MICROSOFT_WINDOWS} {
					bind $entrybox <Key-ISO_Left_Tab> "$this stopwatch_entry_key $key $tp stab;	break"
				}
				bind $entrybox <Key-Return>		"$this stopwatch_entry_key $key $tp enter;	break"
				bind $entrybox <Key-KP_Enter>		"$this stopwatch_entry_key $key $tp enter;	break"
				bind $entrybox <FocusIn>		"$this stopwatch_entry_focus $key $tp 1"
				bind $entrybox <FocusOut>		"$this stopwatch_entry_focus $key $tp 0"
				bindtags $entrybox [list $entrybox TEntry $win all .]

				grid $entrybox -row $row -column $col -sticky we
				set entryboxes($key,$tp) $entrybox
				incr col

				if {$tp == {O}} {
					break
				}

				local_status_tip $clearbuttons($key,$tp) [mc "Clear"]
				grid $clearbuttons($key,$tp) -row $row -column $col -sticky w
				incr col 2
			}

			set ::Stopwatch::text_vars${obj_idx}($key,C) 0
			set ::Stopwatch::text_vars${obj_idx}($key,O) 0
			$entryboxes($key,O) configure -state readonly
			incr row
		}

		# Create checkbutton "Stop simulation"
		grid [checkbutton $main_frame.stop_sim_chb			\
			-variable ::Stopwatch::text_vars${obj_idx}(stop_sim)	\
			-text [mc "Stop simulation"]				\
		] -row $row -column 5 -sticky w -columnspan 2

		# Configure columns in main frame
		grid columnconfigure $main_frame 1 -minsize 10
		grid columnconfigure $main_frame 4 -minsize 10
		grid columnconfigure $main_frame 7 -minsize 10


		# Show dialog frames
		pack $top_frame -anchor w -pady 5 -padx 5 -fill x
		pack $main_frame -fill both -expand 1 -padx 10
		pack $bottom_frame -fill x
	}

	## Entybox event handler for <FocusIn> and <FocusOut>
	 # @parm String key	- Short entry name (from list: $stats_keys)
	 # @parm Char type	- Entry type (C == "Current"; S == "Stop after"; O == "Overall")
	 # @parm Bool focused	- 1 == <FocusIn>; 0 == <FocusOut>
	 # @return void
	public method stopwatch_entry_focus {key type focused} {
		if {$focused} {
			$entryboxes($key,C) configure -style Stopwatch_Focused_I.TEntry
			$entryboxes($key,S) configure -style Stopwatch_Focused_I.TEntry
			$entryboxes($key,$type) configure -style Stopwatch_Focused_D.TEntry
		} else {
			$entryboxes($key,$type) selection clear
			$entryboxes($key,C) configure -style TEntry
			$entryboxes($key,S) configure -style TEntry
			$entryboxes($key,$type) configure -style TEntry
		}
	}

	## Entybox event handler for <Key-Up>, <Key-Down>, <Key-Left>, <Key-Right>, <Key-Tab>,
	 #+ <Key-ISO_Left_Tab>, <Key-Return> and <Key-KP_Enter>
	 # @parm String ekey	- Short entry name (from list: $stats_keys)
	 # @parm Char type	- Entry type (C == "Current"; S == "Stop after"; O == "Overall")
	 # @parm String kkey	- Key name (e.g. "down")
	 # @return void
	public method stopwatch_entry_key {ekey type kkey} {
		set entrybox $entryboxes($ekey,$type)
		set insert [$entrybox index insert]
		set y [lsearch -ascii -exact $stats_keys $ekey]
		set max_y [llength $stats_keys]
		incr max_y -1
		switch -- $type {
			C {set x 0}
			S {set x 1}
			O {set x 2}
		}

		$entrybox selection clear
		switch -- $kkey {
			{up} {
				if {!$y} {
					return
				}
				incr y -1
			}
			{down} {
				if {$y == $max_y} {
					return
				}
				incr y
			}
			{left} {
				if {!$x || $insert} {
					$entrybox icursor [expr {$insert-1}]
					return
				}
				incr x -1
			}
			{right} {
				if {($x == 2) || ($insert != [$entrybox index end])} {
					$entrybox icursor [expr {$insert+1}]
					return
				}
				incr x
			}
			{tab} {
				if {$x == 2} {
					return
				}
				incr x
			}
			{stab} {
				if {!$x} {
					return
				}
				incr x -1
			}
			{enter} {
				if {$y == $max_y} {
					return
				}
				incr y
			}
		}

		set insert [expr {[$entrybox index end] - $insert}]
		set entrybox $entryboxes([lindex $stats_keys $y],[lindex {C S O} $x])
		$entrybox selection range 0 end
		$entrybox icursor [expr {[$entrybox index end] - $insert}]
		focus $entrybox
	}

	## Set local status tip
	 # @parm Widget wdg	- Target widget
	 # @parm String txt	- Status tip text
	 # @return void
	private method local_status_tip {wdg txt} {
		bind $wdg <Enter> [list $status_bar_lbl configure -text $txt]
		bind $wdg <Leave> [list $status_bar_lbl configure -text {}]
	}

	## Validator procedure for all entryboxes in the dialog
	 # @parm String key	- Short entry name (from list: $stats_keys)
	 # @parm Char type	- Entry type (C == "Current"; S == "Stop after"; O == "Overall")
	 # @parm String string	- Suggested content
	 # @return Bool - Validation result (1 == Allowed; 0 == Denied)
	public method stopwatch_entrybox_validator {key type string} {
		# Validate input string
		if {[string length $string] > 19 || ![string is digit $string]} {
			return 0
		}

		# Adjust foreground color for entrybox in column "Current"
		if {$type == {C} && $string != {}} {
			set max [subst -nocommands "\$::Stopwatch::text_vars${obj_idx}($key,S)"]
			if {$max != {} && $max != 0 && $string >= $max} {
				$entryboxes($key,C) configure -style Stopwatch_Focused_D_Invalid.TEntry
			} else {
				$entryboxes($key,C) configure -style Stopwatch_Focused_D.TEntry
			}
		}

		# Adjust clear button
		if {$type == {C} || $type == {S}} {
			if {$string != {} && $string != 0} {
				$clearbuttons($key,$type) configure -state normal
			} else {
				$clearbuttons($key,$type) configure -state disabled
			}
		}

		return 1
	}

	## Clear all entryboxes in the specified column
	 # @parm Char what - Entry type (C == "Current"; S == "Stop after"; O == "Overall")
	 # @return void
	public method stopwatch_clear_all {what} {
		foreach key $stats_keys {
			set ::Stopwatch::text_vars${obj_idx}($key,$what) 0
		}
	}

	## Clear the specified entrybox
	 # @parm String key	- Short entry name (from list: $stats_keys)
	 # @parm Char type	- Entry type (C == "Current"; S == "Stop after"; O == "Overall")
	 # @return void
	public method stopwatch_clear_entrybox {key type} {
		set ::Stopwatch::text_vars${obj_idx}($key,$type) 0
	}

	## Invoke file selection dialog to save content of stopwatch into a file
	 # @parm Bool text__html - File type (1 == Plain text; 0 == XHTML)
	 # @return void
	public method stopwatch_save {text__html} {
		# Determinate list of available file extensions
		if {$text__html} {
			set filetypes [list					\
				[list [::mc "Text files"]	{*.txt}]	\
				[list [::mc "All files"]	{*}]		\
			]
		} else {
			set filetypes [list					\
				[list [::mc "HTML files"]	{*.html}]	\
				[list [::mc "All files"]	{*}]		\
			]
		}

		# Invoke the file selection dialog
		KIFSD::FSD ::fsd	 					\
			-title [mc "Save stopwatch state - MCU 8051 IDE"]	\
			-directory [$this cget -projectPath]			\
			-master $win -filetypes [mc $filetypes]			\
			-defaultmask 0 -multiple 0				\
			-initialfile [$this cget -projectName]

		# Open file after press of OK button
		::fsd setokcmd "
			::fsd deactivate
			$this stopwatch_savefile_proc $text__html	\
				\[file normalize \[file join		\
					\[$this cget -ProjectDir\]	\
					\[::fsd get\]			\
				\]\]
		"

		# Activate the dialog
		::fsd activate
	}

	## Save content of stopwatch into the specified file
	 # @parm Bool text__html	- File type (1 == Plain text; 0 == XHTML)
	 # @parm String filename	- Full name of the target file
	 # @return void
	public method stopwatch_savefile_proc {text__html filename} {
		# Adjust filename extension
		if {![string length [file extension $filename]]} {
			if {$text__html} {
				append filename {.txt}
			} else {
				append filename {.html}
			}
		}

		# Create backup file
		if {[file exists $filename] && [file isfile $filename]} {
			# Ask user for overwrite existing file
			if {[tk_messageBox	\
				-type yesno	\
				-icon question	\
				-parent $win	\
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

		# Open the specified file
		if {[catch {
			set file [open $filename w 0640]
		}]} then {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Permission denied"]	\
				-message [mc "Unable to open file:\n'%s'" $filename]
			return
		}

		# Save as plain text
		if {$text__html} {
			set text {}
			append text	[string repeat { } 37] [mc "Current"]		\
					[string repeat { } 10] [mc "Stop after"]	\
					[string repeat { } 13] [mc "Overall"]
			puts $file $text
			foreach text $stats_names key $stats_keys {
				set text [mc $text]
				append text [string repeat { } [expr {24 - [string length $text]}]]
				foreach subkey {C S O} {
					set val [subst -nocommands "\$::Stopwatch::text_vars${obj_idx}($key,$subkey)"]
					append text [string repeat { } [expr {20 - [string length $val]}]] $val
				}
				puts $file $text
			}

			puts $file "\n[mc {Project:}] [$this cget -projectName]"
			puts $file [mc "Generated by %s" "${::APPNAME}  ( http://mcu8051ide.sf.net )"]

		# Save as XHTML
		} else {
			puts $file "<?xml version='1.0' encoding='utf-8' standalone='no'?>"
			puts $file "<!DOCTYPE html PUBLIC"
			puts $file "\t'-//W3C//DTD XHTML 1.1//EN'"
			puts $file "\t'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'>"
			puts $file "<html xmlns='http://www.w3.org/1999/xhtml' xml:lang='en'>"
			puts $file "<!-- Creator: ${::APPNAME} -->"
			puts $file "\t<head>"
			puts $file "\t\t<title>[$this cget -projectName] stopwatch state [clock format [clock seconds] -format {%D}]</title>"
			puts $file "\t\t<meta http-equiv=\"Content-Type\" content=\"application/xhtml+xml; charset=UTF-8\" />"
			puts $file "\t\t<meta name=\"Generator\" content=\"${::APPNAME}\" />"
			puts $file "\t\t<style type=\"text/css\">"
			puts $file "\t\t\t.sw_header {"
			puts $file "\t\t\t\tfont-weight: normal;"
			puts $file "\t\t\t}"
			puts $file "\t\t\t.sw_C {"
			puts $file "\t\t\t\tbackground-color: #FFEEEE;"
			puts $file "\t\t\t\tfont-weight: bold;"
			puts $file "\t\t\t\ttext-align: right;"
			puts $file "\t\t\t}"
			puts $file "\t\t\t.sw_S {"
			puts $file "\t\t\t\tbackground-color: #EEFFEE;"
			puts $file "\t\t\t\tfont-weight: bold;"
			puts $file "\t\t\t\ttext-align: right;"
			puts $file "\t\t\t}"
			puts $file "\t\t\t.sw_O {"
			puts $file "\t\t\t\tbackground-color: #EEEEFF;"
			puts $file "\t\t\t\tfont-weight: bold;"
			puts $file "\t\t\t\ttext-align: right;"
			puts $file "\t\t\t}"
			puts $file "\t\t</style>"
			puts $file "\t</head>"
			puts $file "\t<body>"
			puts $file "\t\t<table style=\"border-width: 1px\">"
			puts $file "\t\t\t<col /><col /><col /><col />"
			puts $file "\t\t\t<thead>"
			puts $file "\t\t\t\t<tr class=\"sw_header\"><th>&nbsp;</th><th>[mc {Current}]</th><th>[mc {Stop after}]</th><th>[mc {Overall}]</th></tr>"
			puts $file "\t\t\t</thead>"
			puts $file "\t\t\t<tbody>"
			foreach text $stats_names key $stats_keys {
				puts $file "\t\t\t\t<tr>"
				puts $file "\t\t\t\t\t<td class=\"sw_header\">[mc $text]</td>"
				foreach subkey {C S O} {
					puts -nonewline $file "\t\t\t\t\t<td class=\"sw_$subkey\">"
					puts -nonewline $file [subst -nocommands "\$::Stopwatch::text_vars${obj_idx}($key,$subkey)"]
					puts $file "</td>"
				}
				puts $file "\t\t\t\t</tr>"
			}
			puts $file "\t\t\t</tbody>"
			puts $file "\t\t</table>"

			puts $file "\t\t<p>"
			puts $file "\t\t\t[mc {Project:}] <b>[$this cget -projectName]</b><br />"
			puts $file "\t\t\t[mc {Generated by %s} "${::APPNAME}  ( <a href=\"http://mcu8051ide.sf.net\">http://mcu8051ide.sf.net</a> )"]"
			puts $file "\t\t</p>"

			puts $file "\t</body>"
			puts $file "</html>"
		}

		# Close target file
		close $file
	}

	## Enable / Disable stopwatch (swith between states ON and OFF)
	 # @return void
	public method stopwatch_start_stop {} {
		set stopwatch_on [expr {!$stopwatch_on}]

		# Start
		if {$stopwatch_on} {
			$start_stop_button configure -image ::ICONS::22::player_pause
			local_status_tip $start_stop_button [mc "Stop"]
			pack forget $label_stopped_lbl
		# Stop
		} else {
			$start_stop_button configure -image ::ICONS::22::player_play
			local_status_tip $start_stop_button [mc "Start"]
			pack $label_stopped_lbl -side right -pady 0 -ipady 0
		}
	}

	## Get configuration list (for session save procedure)
	 # @return void
	public method stopwatch_get_config {} {
		set result $window_geometry
		lappend result [subst -nocommands "\$::Stopwatch::text_vars${obj_idx}(stop_sim)"]

		foreach key $stats_keys {
			lappend result [subst -nocommands "\$::Stopwatch::text_vars${obj_idx}($key,S)"]
		}

		return $result
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

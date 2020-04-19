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
if { ! [ info exists _COMMANDLINE_TCL ] } {
set _COMMANDLINE_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements procedures related to editor command line
# This file should be loaded into class Editor in file "editor.tcl"
# --------------------------------------------------------------------------

## Binding for command line event <KeyPress>
 # @parm String key - text/binary code of pressed key
 # @retrun void
public method cmd_line_key_press {key} {
	if {![string is print -strict $key]} {
		return
	}
	catch {
		$cmd_line delete sel.first sel.last
	}
	$cmd_line insert insert $key
	cmd_line_highlight
}

## Binding for various KeyPress events on command line
 # @parm key - ID of presses key
 # @retrun Bool - event accepted
public method cmd_line_key {key} {
	set result 0
	switch -- $key {
		{Delete} {
			if {[llength [$cmd_line tag nextrange sel 1.0]]} {
				$cmd_line delete sel.first sel.last
			} else {
				if {[$cmd_line index insert] != [$cmd_line index {insert lineend}]} {
					$cmd_line delete insert {insert+1c}
				}
			}
		}
		{BackSpace} {
			if {[llength [$cmd_line tag nextrange sel 1.0]]} {
				$cmd_line delete sel.first sel.last
			} else {
				if {[$cmd_line index insert] != [$cmd_line index {insert linestart}]} {
					$cmd_line delete {insert-1c} insert
				}
			}
		}
		{Home} {
			$cmd_line tag remove sel 1.0 end
			$cmd_line mark set insert {insert linestart}
		}
		{End} {
			$cmd_line tag remove sel 1.0 end
			$cmd_line mark set insert {insert lineend}
		}
		{Left} {
			$cmd_line tag remove sel 1.0 end
			if {[$cmd_line index insert] != [$cmd_line index {insert linestart}]} {
				$cmd_line mark set insert {insert-1c}
			}
		}
		{Right} {
			$cmd_line tag remove sel 1.0 end
			if {[$cmd_line index insert] != [$cmd_line index {insert lineend}]} {
				$cmd_line mark set insert {insert+1c}
			}
		}
		{SLeft} {
			if {[$cmd_line index insert] != [$cmd_line index {insert linestart}]} {
				set result 1
			}
		}
		{SRight} {
			if {[$cmd_line index insert] != [$cmd_line index {insert lineend}]} {
				set result 1
			}
		}
		default {
			error "Unrecognized key: $key"
			return 0
		}
	}
	cmd_line_highlight 1
	return $result
}

## Get list of commands which starts with the given string
 # @parm String cmd - (in)complite command
 # @retrun List - possible command
private method cmd_line_get_possible_cmds {cmd} {
	set result {}
	set end [string length $cmd]
	incr end -1
	foreach command $editor_commands {
		set shortcmd [string range $command 0 $end]

		if {$command == $cmd} {
			return $cmd

		} elseif {$shortcmd == $cmd} {
			lappend result $command
		}
	}
	return $result
}

## Binding for command line event <Key-Return> and <Key-KP_Enter>
 # @return void
public method cmd_line_enter {} {
	if {[winfo exists .editor_cmd_help_widow]} {
		grab release .editor_cmd_help_widow
		destroy .editor_cmd_help_widow
	}

	set line [$cmd_line get {insert linestart} {insert lineend}]
	if {$line == {}} {return}

	if {[catch {
		set command [string tolower [lindex $line 0]]
	}]} then {
		Sbar [mc "Invalid command"]
		return
	}
	set options {}
	if {[regexp {\:\w*$} $command options]} {
		set options [string range $options 1 end]
		set options [split $options {}]
		regsub {\:\w*$} $command {} command
	}
	set command [cmd_line_get_possible_cmds $command]
	if {$command == {}} {
		Sbar [mc "EDITOR COMMAND LINE: invalid command, type `help list' to get list of available commands"]
		return
	} elseif {[llength $command] > 1} {
		Sbar [mc "Ambiguous command"]
		return
	}
	regsub {^[\w\-:]+\s*} $line {} args
	set args [string trim $args]

	switch -- $command {
		{help} {
			if {[llength $args] > 1} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "char"]
			}
			if {![llength $args]} {
				cmd_line_help_window [mc "Help"] [mc	\
				"This is MCU 8051 IDE command line\n\nusage: <b>command \[arguments\]</b>\n\nEnter <b>help list</b> for list of available commands or\n<b>help <STRING command></b> for help for individual command"]
				return
			}
			set command [lindex $args 0]
			if {$command != {list}} {
				set command [cmd_line_get_possible_cmds $command]
			}
			if {[llength $command] > 1} {
				Sbar [mc "Ambiguous command"]
				return
			}

			switch -- $command {
				{list} {
					cmd_line_help_window [mc "Available commands"]	\
					"<b>d2h</b>		[mc {DEC -> HEX}]
					<b>d2o</b>		[mc {DEC -> OCT}]
					<b>d2b</b>		[mc {DEC -> BIN}]
					<b>h2d</b>		[mc {HEX -> DEC}]
					<b>h2o</b>		[mc {HEX -> OCT}]
					<b>h2b</b>		[mc {HEX -> BIN}]
					<b>o2h</b>		[mc {OCT -> HEX}]
					<b>o2d</b>		[mc {OCT -> DEC}]
					<b>o2b</b>		[mc {OCT -> BIN}]
					<b>b2h</b>		[mc {BIN -> HEX}]
					<b>b2d</b>		[mc {BIN -> DEC}]
					<b>b2o</b>		[mc {BIN -> OCT}]
					<b>animate</b>		[mc {Animate program}]
					<b>assemble</b>		[mc {Compile current file}]
					<b>auto-indent</b>		[mc {Reformat code}]
					<b>bookmark</b>			[mc {Bookmark current line}]
					<b>breakpoint</b>		[mc {Add/Remove breakpoint}]
					<b>capitalize</b>		[mc {Capitalize selection}]
					<b>clear</b>		[mc {Clear history}]
					<b>comment</b>		[mc {Comment selected text}]
					<b>copy</b>		[mc {Copy selection}]
					<b>custom</b>		[mc {Custom command}]
					<b>cut</b>		[mc {Cut selection}]
					<b>date</b>		[mc {Insert date}]
					<b>exit</b>		[mc {Exit command line}]
					<b>exit-program</b>		[mc {Exit program}]
					<b>find</b>		[mc {Find string}]
					<b>goto</b>		[mc {Go to line}]
					<b>help</b>		[mc {Help}]
					<b>char</b>		[mc {Insert literal character}]
					<b>indent</b>		[mc {Indent selection}]
					<b>kill-line</b>		[mc {Remove current line}]
					<b>open</b>		[mc {Open file}]
					<b>paste</b>		[mc {Paste clipboard}]
					<b>redo</b>		[mc {Take back last undo}]
					<b>reload</b>		[mc {Reload current document}]
					<b>replace</b>		[mc {Replace strings}]
					<b>run</b>		[mc {Run simulation}]
					<b>save</b>		[mc {Save current line}]
					<b>set-icon-border</b>	[mc {Show/Hide icon border}]
					<b>set-line-numbers</b> [mc {Show/Hide line n. bar}]
					<b>sim</b>		[mc {Start/Stop simulator}]
					<b>step</b>		[mc {Step program}]
					<b>tolower</b>		[mc {To lowercase}]
					<b>toupper</b>		[mc {To uppercase}]
					<b>uncomment</b>		[mc {Uncomment selection}]
					<b>undo</b>		[mc {Take back last operation}]
					<b>unindent</b>		[mc {Unindent selection}]
					<b>hibernate</b>		[mc {Hibernate running program}]
					<b>resume</b>		[mc {Resume hibernated program}]
					<b>switch-mcu</b>		[mc {Change current MCU}]
					<b>set-xcode</b>		[mc {Set XCODE memory size for current MCU}]
					<b>set-xdata</b>		[mc {SET XDATA memory size for current MCU}]"
				}
				{hibernate} {
					cmd_line_help_window [mc "Command hibernate"] [mc \
					"<b>hibernate</b> \[<STRING target-file>\]\nHibernate running program (available only when simulator is stated).\n\nThis function saves current state of the simulator engine for future resumption. If no target is not specified it will invoke file selection dialog"]
				}
				{resume} {
					cmd_line_help_window [mc "Command resume"] [mc \
					"<b>resume</b> \[<STRING source-file>\]\nResume hibernated program (available only when simulator is stated).\n\nThis function restores previous state of the simulator engine stored in the given file. If no source is not specified it will invoke file selection dialog"]
				}
				{switch-mcu} {
					cmd_line_help_window [mc "Command switch-mcu"] [mc \
					"<b>switch-mcu</b> <STRING processor-type>\nChange current MCU. Type `switch-mcu list' for list of supported microcontrollers"]
				}
				{set-xcode} {
					cmd_line_help_window [mc "Command set-xcode"] [mc \
					"<b>set-xcode</b> <INT size>\nChange capacity of external program memory.\nNote: this command also close CODE memory hex editor"]
				}
				{set-xdata} {
					cmd_line_help_window [mc "Command set-xdata"] [mc \
					"<b>set-xdata</b> <INT size>\nChange capacity of external data memory.\nNote: this command also close XDATA memory hex editor"]
				}
				{run} {
					cmd_line_help_window [mc "Command run"] [mc \
					"Run simulation (available only when simulator is stated)"]
				}
				{exit} {
					cmd_line_help_window [mc "Command exit"] [mc \
					"Exits this command line"]
				}
				{exit-program} {
					cmd_line_help_window [mc "Command exit-program"] [mc \
					"Quit MCU 8051 IDE"]
				}
				{set-icon-border} {
					cmd_line_help_window [mc "Command set-icon-border"] [mc \
					"Sets the visibility of the icon border"]
				}
				{set-line-numbers} {
					cmd_line_help_window [mc "Command set-line-numbers"] [mc \
					"Sets the visibility of the line numbers."]
				}
				{help} {
					cmd_line_help_window [mc "Command help"] [mc \
					"<b>help</b> <STRING command>\nShows help for the given command\n\n<b>help list</b>\nShows list of available command"]
				}
				{open} {
					cmd_line_help_window [mc "Command open"] [mc \
					"<b>open</b> <STRING full_filename>\nOpens the given file in new editor"]
				}
				{indent} {
					cmd_line_help_window [mc "Command indent"] [mc \
					"Indents current line or selected area"]
				}
				{unindent} {
					cmd_line_help_window [mc "Command unindent"] [mc \
					"Unindents current line or selected area"]
				}
				{comment} {
					cmd_line_help_window [mc "Command comment"] [mc \
					"Comments current line or selected area"]
				}
				{uncomment} {
					cmd_line_help_window [mc "Command uncomment"] [mc \
					"Uncomments current line or selected area"]
				}
				{kill-line} {
					cmd_line_help_window [mc "Command kill-line"] [mc \
					"Removes the current line"]
				}
				{date} {
					cmd_line_help_window [mc "Command date"] [mc \
					"<b>date</b> <STRING format>\nInserts formatted date at the current position in text\n\n<b>Format string:</b>\n%%	=> %\n%a	=> Weekday name (Mon, Tue, etc.)\n%A	=> Weekday name (Monday, Tuesday, etc.)\n%b	=> Month name (Jan, Feb, etc.)\n%B	=> Full month name\n%C	=> Year (19 or 20)\n%d	=> Day of month (01 - 31)\n%D	=> %m/%d/%y\n%h	=> Abbreviated month name.\n%H	=> Hour (00 - 23)\n%I	=> Hour (01 - 12)\n%j	=> Day of year (001 - 366)\n%k	=> Hour (0 - 23)\n%l	=> Hour (1 - 12).\n%m	=> Month (01 - 12)\n%M	=> Minute (00 - 59)\n%n	=> Newline\n%p	=> AM/PM\n%R	=> %H:%M.\n%s	=> Unix timestamp\n%S	=> Seconds (00 - 59)\n%t	=> Tab\n%T	=> %H:%M:%S.\n%u	=> Weekday number (Monday = 1, Sunday = 7)\n%w	=> Weekday number (Sunday = 0, Saturday = 6)\n%y	=> Year without century (00 - 99)\n%Y	=> Year with century (e.g. 1459)"]
				}
				{clear} {
					cmd_line_help_window [mc "Command clear"] [mc \
					"Clears command line history"]
				}
				{char} {
					cmd_line_help_window [mc "Command char"] [mc \
					"<b>char</b> <NUMBER identifier>\nInserts literal characters by their numerical identifier.\nIdentifier can be in decimal hexadecimal or octal form."]
				}
				{goto} {
					cmd_line_help_window [mc "Command goto"] [mc \
					"<b>goto</b> <INT line>\nGo to the given line"]
				}
				{replace} {
					cmd_line_help_window [mc "Command replace"] [mc \
					"<b>replace\[:options\]</b> <STRING pattern> <STRING replacement>\n\n<b>options:</b>\nb	Search backwards\nc	Search from cursor position\nr	Regular expression search\ns	Case sensitive search\np	Ask before replacement"]
				}
				{find} {
					cmd_line_help_window [mc "Command find"] [mc \
					"<b>find\[:options\]</b> <STRING pattern>\n\n<b>options:</b>\nb	Search backwards\nc	Search from cursor position\ne	Search in the selection only\nr	Regular expression search\ns	Case sensitive search"]
				}
				{cut} {
					cmd_line_help_window [mc "Command cut"] [mc \
					"Cut selected text"]
				}
				{copy} {
					cmd_line_help_window [mc "Command copy"] [mc \
					"Copy selected text to clipboard"]
				}
				{paste} {
					cmd_line_help_window [mc "Command paste"] [mc \
					"Paste clipboard content"]
				}
				{tolower} {
					cmd_line_help_window [mc "Command tolower"] [mc \
					"Convert selected text to lowercase"]
				}
				{toupper} {
					cmd_line_help_window [mc "Command toupper"] [mc \
					"Convert selected text to uppercase"]
				}
				{capitalize} {
					cmd_line_help_window [mc "Command capitalize"] [mc \
					"Capitalize the selected text (convert 1st character to uppercase)"]
				}
				{save} {
					cmd_line_help_window [mc "Command save"] [mc \
					"Save the current document"]
				}
				{bookmark} {
					cmd_line_help_window [mc "Command bookmark"] [mc \
					"Bookmark the current line"]
				}
				{custom} {
					cmd_line_help_window [mc "Command custom"] [mc \
					"<b>custom</b> <INT command_number>\nExecute custom command (see menu Configuration -> Custom commands)"]
				}
				{breakpoint} {
					cmd_line_help_window [mc "Command breakpoint"] [mc \
					"Add / Remove breakpoint to the current line"]
				}
				{undo} {
					cmd_line_help_window [mc "Command undo"] [mc \
					"Take back last operation"]
				}
				{redo} {
					cmd_line_help_window [mc "Command redo"] [mc \
					"Take back last undo"]
				}
				{auto-indent} {
					cmd_line_help_window [mc "Command auto-indent"] [mc \
					"Reformat code"]
				}
				{reload} {
					cmd_line_help_window [mc "Command reload"] [mc \
					"Reload the current document"]
				}
				{assemble} {
					cmd_line_help_window [mc "Command assemble"] [mc \
					"Compile the current document"]
				}
				{sim} {
					cmd_line_help_window [mc "Command sim"] [mc \
					"Start / Stop simulator"]
				}
				{step} {
					cmd_line_help_window [mc "Command step"] [mc \
					"Step program (available only when simulator is stated)"]
				}
				{animate} {
					cmd_line_help_window [mc "Command animate"] [mc \
					"Animate program (available only when simulator is stated)"]
				}
				{d2h} {
					cmd_line_help_window [mc "Command d2h"] [mc \
					"Convert decimal number to hexadecimal and write result to editor"]
				}
				{d2o} {
					cmd_line_help_window [mc "Command d2o"] [mc \
					"Convert decimal number to octal and write result to editor"]
				}
				{d2b} {
					cmd_line_help_window [mc "Command d2b"] [mc \
					"Convert decimal number to binary and write result to editor"]
				}
				{h2d} {
					cmd_line_help_window [mc "Command h2d"] [mc \
					"Convert hexadecimal number to decimal and write result to editor"]
				}
				{h2o} {
					cmd_line_help_window [mc "Command h2o"] [mc \
					"Convert hexadecimal number to octal and write result to editor"]
				}
				{h2b} {
					cmd_line_help_window [mc "Command h2b"] [mc \
					"Convert hexadecimal number to binary and write result to editor"]
				}
				{o2h} {
					cmd_line_help_window [mc "Command o2h"] [mc \
					"Convert octal number to hexadecimal and write result to editor"]
				}
				{o2d} {
					cmd_line_help_window [mc "Command o2d"] [mc \
					"Convert octal number to decimal and write result to editor"]
				}
				{o2b} {
					cmd_line_help_window [mc "Command o2b"] [mc \
					"Convert octal number to binary and write result to editor"]
				}
				{b2h} {
					cmd_line_help_window [mc "Command b2h"] [mc \
					"Convert binary number to hexadecimal and write result to editor"]
				}
				{b2d} {
					cmd_line_help_window [mc "Command b2d"] [mc \
					"Convert binary number to decimal and write result to editor"]
				}
				{b2o} {
					cmd_line_help_window [mc "Command b2o"] [mc \
					"Convert binary number to octal and write result to editor"]
				}
				default {
					Sbar [mc "EDITOR COMMAND LINE: Unknown command: `%s'" [lindex $args 0]]
				}
			}
		}
		{hibernate} {
			if {[llength $args] > 2} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "hibernate"]
				return
			}

			if {![llength $args]} {
				::X::__hibernate
			} else {
				::X::__hibernate_to [lindex $args 0] $filename
			}
			Sbar [mc "Success"]
		}
		{resume} {
			if {[llength $args] > 2} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "resume"]
				return
			}

			if {![llength $args]} {
				::X::__resume
			} else {
				::X::__resume_from [lindex $args 0] $filename
			}
			Sbar [mc "Success"]
		}
		{switch-mcu} {
			if {[llength $args] > 2 || ![llength $args]} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "switch-mcu"]
				return
			}

			set arg [string toupper [lindex $args 0]]
			if {$arg == {list}} {
				set arg {}
				foreach mcu ${::X::available_processors} {
					append arg $mcu
					append arg "\n"
				}
				cmd_line_help_window {Supported microcontrollers} $arg
			} else {
				if {[lsearch ${::X::available_processors} $arg] == -1} {
					Sbar [mc "EDITOR COMMAND LINE: Unsupported processor `%s'" "$arg"]
				} else {
					::X::change_processor $arg
				}
			}
			Sbar [mc "Success"]
		}
		{set-xcode} {
			if {[llength $args] > 2 || ![llength $args]} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "set-xcode"]
				return
			}

			set arg [lindex $args 0]
			set error 0
			if {![string first {0x} $arg]} {
				if {![string is xdigit -strict [string range $arg 2 end]]} {set error 1}
				set arg [expr "$arg"]
			} elseif {[string index $arg 0] == {0}} {
				if {![regexp {^[0-7]+$} $arg]} {set error 1}
				set arg [expr "$arg"]
			} else {
				if {![string is digit -strict $arg]} {set error 1}
			}

			if {$error} {
				Sbar [mc "EDITOR COMMAND LINE: Expected integer but got `%s' (command: %s)" $arg "set-xcode"]
				return
			}

			set icode [expr {[lindex [${::X::actualProject} cget -procData] 2] * 1024}]
			if {$arg > (0xFFFF - $icode)} {
				Sbar [mc "EDITOR COMMAND LINE: This MCU has CODE memory limit 0x10000 B (65536) (command: %s)"] "set-xcode"
				return
			}

			if {[lindex [${::X::actualProject} cget -procData] 1] != {yes}} {
				Sbar [mc "This MCU cannot have connected external program memory"]
			} else {
				${::X::actualProject} configure -P_option_mcu_xcode $arg
				::X::close_hexedit code ${::X::actualProject}
				${::X::actualProject} simulator_resize_code_memory $arg
				Sbar [mc "Success"]
			}
		}
		{set-xdata} {
			if {[llength $args] > 2 || ![llength $args]} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "set-xdata"]
				return
			}

			set arg [lindex $args 0]
			set error 0
			if {![string first {0x} $arg]} {
				if {![string is xdigit -strict [string range $arg 2 end]]} {set error 1}
				set arg [expr "$arg"]
			} elseif {[string index $arg 0] == {0}} {
				if {![regexp {^[0-7]+$} $arg]} {set error 1}
				set arg [expr "$arg"]
			} else {
				if {![string is digit -strict $arg]} {set error 1}
			}

			if {$error} {
				Sbar [mc "EDITOR COMMAND LINE: Expected integer but got `%s' (command: %s)" $arg "set-xdata"]
				return
			}

			if {$arg > 0xFFFF} {
				Sbar [mc "EDITOR COMMAND LINE: This MCU has XDATA memory limit 0x10000 B (65536) (command: %s)" "set-xdata"]
				return
			}

			if {[lindex [${::X::actualProject} cget -procData] 0] != {yes}} {
				Sbar [mc "This MCU cannot have connected external data memory"]
			} else {
				${::X::actualProject} configure -P_option_mcu_xdata $arg
				::X::close_hexedit xdata ${::X::actualProject}
				${::X::actualProject} simulator_resize_xdata_memory $arg
				Sbar [mc "Success"]
			}
		}
		{d2h} {command_line_X2X_command {d2h} $args}
		{d2o} {command_line_X2X_command {d2o} $args}
		{d2b} {command_line_X2X_command {d2b} $args}
		{h2d} {command_line_X2X_command {h2d} $args}
		{h2o} {command_line_X2X_command {h2o} $args}
		{h2b} {command_line_X2X_command {h2b} $args}
		{o2h} {command_line_X2X_command {o2h} $args}
		{o2d} {command_line_X2X_command {o2d} $args}
		{o2b} {command_line_X2X_command {o2b} $args}
		{b2h} {command_line_X2X_command {b2h} $args}
		{b2d} {command_line_X2X_command {b2d} $args}
		{b2o} {command_line_X2X_command {b2o} $args}
		{set-icon-border} {
			::X::__show_hine_IconB
			command_without_args $args
		}
		{set-line-numbers} {
			::X::__show_hine_LineN
			command_without_args $args
		}
		{open} {
			if {![llength $args] || [llength $args] > 1} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "open"]
			}
			if {$fullFileName != {}} {
				set dir [file dirname $fullFileName]
			} else {
				set dir $projectPath
			}
			set filename [file join $dir [lindex $args 0]]
			if {![file exists $filename] || ![file isfile $filename]} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "unindent"]
			}
			if {[${::X::actualProject} openfile $filename 1 . def def 0 0 {}] != {}} {
				${::X::actualProject} switch_to_last
				update idletasks
				${::X::actualProject} editor_procedure {} parseAll {}
				Sbar [mc "Success"]
			}
		}
		{indent} {
			indent
			command_without_args $args
		}
		{unindent} {
			unindent
			command_without_args $args
		}
		{comment} {
			comment
			command_without_args $args
		}
		{uncomment} {
			uncomment
			command_without_args $args
		}
		{kill-line} {
			detete_text_in_editor {insert linestart} {insert+1l linestart}
			goto [expr {int([$editor index insert])}]
			Sbar [mc "Success"]
		}
		{date} {
			if {[catch {$editor insert insert [clock format [clock seconds] -format $args]}]} {
				Sbar [mc "EDITOR COMMAND LINE: Invalid format string"]
			} else {
				parse [expr {int([$editor index insert])}]
				Sbar [mc "Success"]
			}
		}
		{char} {
			if {[llength $args] > 1} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "char"]
			} else {
				Sbar [mc "Success"]
			}
			set char [lindex $args 0]
			if {![regexp {^(0|0x|0X)?[0-9]+$} $char]} {
				Sbar [mc "EDITOR COMMAND LINE: syntax error: expected integer (command: %s)" "char"]
				return
			}
			$editor insert insert [format %c $char]
			parse [expr {int([$editor index insert])}]
		}
		{goto} {
			if {[llength $args] > 1} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "goto"]
			} else {
				Sbar [mc "Success"]
			}
			set target_line [lindex $args 0]

			if {![regexp {^(0|0x|0X)?[0-9]+$} $target_line]} {
				Sbar [mc "EDITOR COMMAND LINE: syntax error: expected integer (command: %s)" "goto"]
				return
			}
			if {$target_line > [editor_linescount]} {
				Sbar [mc "Target line out of range"]
			} else {
				goto $target_line
				Sbar [mc "Success"]
			}
		}
		{replace} {
			if {[llength $args] > 2} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "replace"]
			} else {
				Sbar [mc "Success"]
			}
			set pattern [lindex $args 0]
			set replacement [lindex $args 1]
			set Backwards 0
			set fromCursor 0
			set regExp 0
			set noCase 0
			set confirm 0
			set options {}
			foreach opt $options {
				switch -- $opt {
					{b} {	;# Search backwards
						set Backwards 1
					}
					{c} {	;# Search from cursor position
						set fromCursor 1
					}
					{r} {	;# Regular expression search
						set regExp 1
					}
					{s} {	;# Do case sensitive search
						set noCase 1
					}
					{p} {	;# Prompt before replacement
						set confirm 1
					}
					default {
						Sbar [mc "Invalid option: %s" $opt]
					}
				}
			}
			replace	$fromCursor	$Backwards	$regExp		\
				$noCase		$pattern	$replacement	\
				$confirm	::X::replace_prompt
		}
		{find} {
			if {[llength $args] > 1} {
				Sbar [mc "EDITOR COMMAND LINE: wrong # args (command: %s)" "find"]
			}
			set pattern [lindex $args 0]
			set Backwards 0
			set fromCursor 0
			set regExp 0
			set noCase 0
			set confirm 0
			set inSelection 0
			set options {}
			foreach opt $options {
				switch -- $opt {
					{b} {	;# Search backwards
						set Backwards 1
					}
					{e} {	;# Search in the selection only
						set inSelection 1
					}
					{c} {	;# Search from cursor position
						set fromCursor 1
					}
					{r} {	;# Regular expression search
						set regExp 1
					}
					{s} {	;# Do case sensitive search
						set noCase 1
					}
					default {
						Sbar [mc "Invalid option: %s" $opt]
					}
				}
			}
			set result [find $fromCursor $Backwards $regExp $noCase $inSelection 1.0 $pattern]
			if {[lindex $result 0] == -1} {
				Sbar [mc "String not found: %s" [lindex $result 1]]
			} else {
				Sbar [mc "Found %s occurrence" [lindex $result 2]]
			}
		}
		{cut} {
			cut
			command_without_args $args
		}
		{copy} {
			copy
			command_without_args $args
		}
		{paste} {
			paste
			command_without_args $args
		}
		{tolower} {
			lowercase
			command_without_args $args
		}
		{toupper} {
			uppercase
			command_without_args $args
		}
		{capitalize} {
			capitalize
			command_without_args $args
		}
		{save} {
			save
			command_without_args $args
		}
		{bookmark} {
			Bookmark
			command_without_args $args
		}
		{breakpoint} {
			Breakpoint
			command_without_args $args
		}
		{undo} {
			undo
			command_without_args $args
		}
		{redo} {
			redo
			command_without_args $args
		}
		{auto-indent} {
			::X::__reformat_code
			command_without_args $args
		}
		{reload} {
			::X::__reload
			command_without_args $args
		}
		{assemble} {
			::X::__compile 0
			command_without_args $args
		}
		{sim} {
			::X::__initiate_sim
			command_without_args $args
		}
		{step} {
			::X::__step
			command_without_args $args
		}
		{animate} {
			::X::__animate
			command_without_args $args
		}
		{run} {
			::X::__run
			command_without_args $args
		}
		{custom} {
			set cmd [lindex $args 0]
			if {$cmd != 0 && $cmd != 1 && $cmd != 2}
			__exec_custom_cmd $cmd
			Sbar [mc "Success"]
		}
		{clear} {
			$cmd_line delete 1.0 end
			command_without_args $args
			return
		}
		{exit-program} {
			::X::__exit
		}
		{exit} {
			pack forget $cmd_line
			focus $editor
			command_without_args $args
		}
		default {
			Sbar [mc "EDITOR COMMAND LINE: invalid command, type `help list' to get list of available commands"]
		}
	}

	# Manage command line history
	if {int([$cmd_line index end-1l]) == int([$cmd_line index insert])} {
		$cmd_line insert {insert lineend} "\n"
	} else {
		set txt [$cmd_line get {insert linestart} {insert lineend}]
		$cmd_line mark set insert end
		$cmd_line insert insert $txt
		cmd_line_highlight 1
		$cmd_line insert insert "\n"
	}
	$cmd_line mark set insert end
	$cmd_line see end
}

## Auxiliary procedure for "cmd_line_enter"
 # Performs number base conversions
 # @parm String command		- Type of conversion (e.g h2b, d2o)
 # @parm String argument	- Number to convert
 # @retrun void
private method command_line_X2X_command {command argument} {
	set len [llength $argument]
	if {!$len} {
		Sbar [mc "EDITOR COMMAND LINE: This command requires exactly one argument"]
		return
	}

	set argument [lindex $argument 0]

	switch -- $command {
		{d2h} {	;# DEC -> HEX
			set ver_cmd	{isdec}
			set conv_cmd	{dec2hex}
		}
		{d2o} {	;# DEC -> OCT
			set ver_cmd	{isdec}
			set conv_cmd	{dec2oct}
		}
		{d2b} {	;# DEC -> BIN
			set ver_cmd	{isdec}
			set conv_cmd	{dec2bin}
		}
		{h2d} {	;# HEX -> DEC
			set ver_cmd	{ishex}
			set conv_cmd	{hex2dec}
		}
		{h2o} {	;# HEX -> OCT
			set ver_cmd	{ishex}
			set conv_cmd	{hex2oct}
		}
		{h2b} {	;# HEX -> BIN
			set ver_cmd	{ishex}
			set conv_cmd	{hex2bin}
		}
		{o2h} {	;# OCT -> HEX
			set ver_cmd	{isoct}
			set conv_cmd	{oct2hex}
		}
		{o2d} {	;# OCT -> BIN
			set ver_cmd	{isoct}
			set conv_cmd	{oct2dec}
		}
		{o2b} {	;# OCT -> BIN
			set ver_cmd	{isoct}
			set conv_cmd	{oct2bin}
		}
		{b2h} {	;# BIN -> HEX
			set ver_cmd	{isbin}
			set conv_cmd	{bin2hex}
		}
		{b2d} {	;# BIN -> DEC
			set ver_cmd	{isbin}
			set conv_cmd	{bin2dec}
		}
		{b2o} {	;# BIN -> OCT
			set ver_cmd	{isbin}
			set conv_cmd	{bin2oct}
		}
		default {
			error "Unknown error in Editor.command_line_X2X_command()"
		}
	}

	if {![::NumSystem::$ver_cmd $argument]} {
		Sbar [mc "EDITOR COMMAND LINE: Invalid number format"]
		return
	}

	$editor insert insert [::NumSystem::$conv_cmd $argument]
	parse [expr {int([$editor index insert])}]
	Sbar [mc "Success"]
}

## Check if the given list of arguments is empty and display result on main statusbar
 # @parm List args - list of arguments
 # @retrun void
private method command_without_args {args} {
	if {[llength $args]} {
		if {[llength $args] != 1 || [lindex $args 0] != {}} {
			Sbar [mc "EDITOR COMMAND LINE: This command takes no arguments"]
		}
	}
	Sbar [mc "Success"]
}

## Highlight current contents of editor command line
 # @parm Bool no_completion=0 - Disable popup-based completion
 # @return void
private method cmd_line_highlight {{no_completion 0}} {
	# Remove all tags from command line
	foreach tag {tag_cmd tag_argument tag_option tag_error} {
		$cmd_line tag remove $tag {insert linestart} {insert lineend}
	}

	# Get line contents and line number
	set line [$cmd_line get {insert linestart} {insert lineend}]
	set lineNumber [expr {int([$cmd_line index insert])}]

	# Split line into command and arguments
	set cmd {}
	set opt {}
	if {[regexp {^[\w:-]+} $line cmd]} {
		if {[regexp {\:\w*$} $cmd opt]} {
			set cmd [regsub {\:\w*$} $cmd {}]
		}
	}

	# Resolve possible commands, start index and end index
	set command [cmd_line_get_possible_cmds $cmd]
	set startIdx [$cmd_line index {insert linestart}]
	set endIdx [string length $cmd]
	# Highlight command (+ post down list of possible commands | + return)
	if {[llength $command] == 1} {
		$cmd_line tag add tag_cmd $startIdx $lineNumber.$endIdx
	} elseif {$endIdx && [llength $command] > 1 && [$cmd_line compare $lineNumber.$endIdx == insert]} {
		if {$cline_completion && !$no_completion} {
			# Automaticaly complete command
			set possible_cmd [lindex $command 0]
			set insert [$cmd_line index insert]
			$cmd_line insert insert [string range $possible_cmd $endIdx end]
			$cmd_line tag remove sel 1.0 end
			$cmd_line tag add sel $lineNumber.$endIdx $lineNumber.[string length $possible_cmd]
			$cmd_line mark set insert $insert
			# Postdown completion menu
			cmd_line_menu_postdown $command
		}
		return
	} else {
		$cmd_line tag add tag_error $startIdx $lineNumber.$endIdx
	}
	# Insure than list of possible commands is not visible
	cmd_line_menu_close

	# Highlight command options (characters after colon)
	if {$opt != {}} {
		set startIdx $endIdx
		incr endIdx [string length $opt]
		if {[lsearch $commands_with_option $command] != -1} {
			$cmd_line tag add tag_option $lineNumber.$startIdx $lineNumber.$endIdx
		} else {
			$cmd_line tag add tag_error $lineNumber.$startIdx $lineNumber.$endIdx
		}
	}

	# Highlight remaining as arguments
	$cmd_line tag add tag_argument $lineNumber.$endIdx {insert lineend}
}

## Postdown list of possible commands for command line
 # @parm List commands - contents of the list
 # @retrun void
private method cmd_line_menu_postdown {commands} {
	# List is not mapped -> create new toplevel window
	if {![winfo exists $cmd_line_listbox]} {
		# Determinate window coordinates and width
		set x [winfo rootx $cmd_line]
		set y [expr {[winfo rooty $cmd_line] + [winfo height $cmd_line]}]
		set width [winfo width $cmd_line]

		# Create window
		set win {.editor_cmd_help_widow}
		if {[winfo exists $win]} {
			grab release $win
			destroy $win
		}
		toplevel $win -background {#000000} -class {Help window}
		wm overrideredirect $win 1
		wm geometry $win "=${width}x100+${x}+${y}"
		bind $win <ButtonPress-1> "$this cmd_line_win_B1 %X %Y"
		bind $win <FocusOut> "$this cmd_line_menu_close_now"

		# Create listbox of possible commands
		set frame [frame $win.frame]
		set cmd_line_listbox [ListBox $frame.lisbox	\
			-relief flat -bd 0 -selectfill 1	\
			-selectbackground {#AAAAFF}		\
			-yscrollcommand "$frame.scrollbar set"	\
			-selectmode single -highlightthickness 0\
			-bg {#FFFFFF}				\
		]
		pack $cmd_line_listbox -fill both -expand 1 -side left
		# Create scrollbar
		pack [ttk::scrollbar $frame.scrollbar		\
			-orient vertical			\
			-command "$cmd_line_listbox yview"	\
		] -side right -after $cmd_line_listbox -fill y
		pack $frame -padx 1 -pady 1 -fill both -expand 1

		# Configure listbox event bindings
		if {[winfo exists $cmd_line_listbox.c]} {
			bind $cmd_line_listbox.c <Button-5>	{%W yview scroll +5 units; break}
			bind $cmd_line_listbox.c <Button-4>	{%W yview scroll -5 units; break}
		}
		bind $cmd_line_listbox <Key-Escape> "$this cmd_line_menu_close_now"
		bind $cmd_line_listbox <Key-Return>	\
			"$this cmd_line_listbox_sel \[$cmd_line_listbox selection get\]"
		bind $cmd_line_listbox <Key-KP_Enter>	\
			"$this cmd_line_listbox_sel \[$cmd_line_listbox selection get\]"
		$cmd_line_listbox bindText <Button-1>	"$this cmd_line_listbox_sel"
		$cmd_line_listbox bindText <Enter>	"
			update
			%W selection clear
			%W selection set"

		# Finalize window initialization (global grab)
		update idletasks
		catch {
			grab -global $win
			raise $win
		}
	}

	# Fill listbox with the given list of commands
	$cmd_line_listbox delete [$cmd_line_listbox items]
	foreach cmd $commands {
		$cmd_line_listbox insert end #auto -text $cmd
	}
}

## Binding for command line event <Key-Down>
 # Possible results:
 #	A) Focus on list of possible commands
 #	C) Return 0
 # @retrun Bool - $cmd_line_listbox focused
public method cmd_line_down {} {
	if {![winfo exists $cmd_line_listbox]} {
		return 0
	} else {
		$cmd_line_listbox selection set [$cmd_line_listbox item 0]
		focus -force $cmd_line_listbox
		return 1
	}
}

## Clear command line and write there text
 # of the given item in list of possible commands.
 # This procedure also closes command line help window
 # @parm String item - ID of choosen item
 # @retrun void
public method cmd_line_listbox_sel {item} {
	$cmd_line delete {insert linestart} {insert lineend}
	$cmd_line insert end [$cmd_line_listbox itemcget $item -text]
	$cmd_line tag add tag_cmd {insert linestart} {insert lineend}
	cmd_line_menu_close
}

## Binding common for all command line help windows: event <ButtonPress-1>
 # This procedure will close help window if user click outside it.
 # @parm Int X - absolute horizontal position of mouse pointer
 # @parm Int Y - absolute vertical position of mouse pointer
 # @retrun void
public method cmd_line_win_B1 {X Y} {
	set win {.editor_cmd_help_widow}
	set min_x [winfo rootx $win]
	set min_y [winfo rooty $win]
	set max_x [expr {$min_x + [winfo width $win]}]
	set max_y [expr {$min_y + [winfo height $win]}]

	if {$X > $max_x || $X < $min_x || $Y > $max_y || $Y < $min_y} {
		cmd_line_menu_close_now
	}
}

## Close command line help window if opened
 # @retrun void
public method cmd_line_menu_close {} {
	if {![winfo exists $cmd_line_listbox]} {
		return
	}
	cmd_line_menu_close_now
}

## Unconditionaly close command line help window
 # @retrun void
public method cmd_line_menu_close_now {} {
	grab release .editor_cmd_help_widow
	destroy .editor_cmd_help_widow
	if {[winfo viewable $cmd_line]} {
		focus -force $cmd_line
	}
}

## Create command line help window for purpose of help
 # @parm String header	- Window header
 # @parm String content	- Window contents (can contain tags <b>bold</b>)
 # @return Widget - Text widget
private method cmd_line_help_window {header content} {
	# Destroy the previous window
	if {[winfo exists .editor_cmd_help_widow]} {
		grab release .editor_cmd_help_widow
		destroy .editor_cmd_help_widow
	}

	# Create window
	set win [toplevel .editor_cmd_help_widow -bg ${::COMMON_BG_COLOR}]
	wm overrideredirect $win 1

	bind $win <ButtonPress-1> "$this cmd_line_win_B1 %X %Y"
	bind $win <FocusOut> "$this cmd_line_menu_close_now"

	# Create header
	set header_frame [frame $win.header -bg {#AAAAFF}]
	pack [label $header_frame.lbl_heder	\
		-text $header -fg {#FF0000}	\
		-bg {#AAAAFF} -bd 0 -anchor w	\
		-relief flat			\
		-font $cmd_line_win_font	\
	] -fill x -expand 1 -side left -ipadx 5
	pack [Button $header_frame.lbl_close	\
		-text [mc "Close"] -bd 0 -pady 0\
		-compound left -cursor hand2	\
		-bg {#AAAAFF} -relief flat	\
		-fg {#FFFFFF} -anchor e		\
		-image ::ICONS::16::button_cancel\
		-font $cmd_line_win_font	\
		-helptext [mc "Close this window"]\
		-command "destroy $win"		\
	] -fill none -side left -pady 0 -ipady 0
	pack $header_frame -fill x -side top

	# Create text widget
	set text [text $win.text	\
		-bg {#FFFFFF}		\
		-cursor left_ptr	\
		-bd 1			\
		-width 0 -height 0	\
		-font $cl_hw_nrml_font	\
		-yscrollcommand "$win.scrollbar set"	\
	]
	$text tag configure tag_bold -font $cl_hw_bold_font

	# Create map of bold font tags
	regsub -all -line {^\t+} $content {} content
	set bold_tag_map {}
	while {1} {
		set tag_pair {}

		set idx [string first {<b>} $content]
		if {$idx == -1} {break}
		regsub {<b>} $content {} content
		lappend tag_pair $idx

		set idx [string first {</b>} $content]
		if {$idx == -1} {break}
		regsub {</b>} $content {} content
		lappend tag_pair $idx

		lappend bold_tag_map $tag_pair
	}

	# Adjust content and insert tags
	set start [$text index insert]
	$text insert end $content
	foreach pair $bold_tag_map {
		$text tag add tag_bold $start+[lindex $pair 0]c $start+[lindex $pair 1]c
	}
	$text configure -state disabled

	# Create and pack scrollbar
	pack $text -side left -fill both -expand 1
	pack [ttk::scrollbar $win.scrollbar	\
		-orient vertical		\
		-command "$text yview"		\
	] -side right -fill y -after $text

	# Show the window
	set x [winfo rootx $cmd_line]
	set y [expr {[winfo rooty $cmd_line] + [winfo height $cmd_line]}]
	update idletasks
	if {150 > ([winfo height .] - $y)} {
		incr y -150
		incr y -[winfo height $cmd_line]
	}
	catch {
		wm transient $win .
		grab -global $win
		update
		wm geometry $win "=[winfo width $cmd_line]x150+${x}+${y}"
	}
}

## Focus on editor / editor command line
 # @parm Bool no_cmd_line_on=0 - Do not call proc. "cmd_line_on"
 # @return void
public method cmd_line_focus {{no_cmd_line_on 0}} {
	# Show command line
	if {![winfo viewable $cmd_line]} {
		pack $cmd_line -side top -fill x
		if {!$no_cmd_line_on} {
			${::X::actualProject} cmd_line_on
		}
	}

	if {[focus] == $cmd_line} {
		focus $editor
	} else {
		focus $cmd_line
	}
	update
}

# >>> File inclusion guard
}
# <<< File inclusion guard

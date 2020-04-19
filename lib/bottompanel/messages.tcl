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
if { ! [ info exists _MESSAGES_TCL ] } {
set _MESSAGES_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements messages text for the bottom panel of the project tab
# --------------------------------------------------------------------------

class Messages {

	## COMMON
	public common set_shortcuts	{}		;# Currently set shortcut bindigs for messages text
	public common shortcuts_cat	{messages}	;# Key shortcut categories related to messages text
	# Normal font for messages text
	public common messages_normal_font [font create		\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
	]
	# Bold font for messages text
	public common messages_bold_font [font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
	]
	# Definition of popup menu for messages text
	public common MESSAGESMENU {
		{command	{Select all}	{Ctrl+A}		0	"select_all_messages_text"
			{}		"Select all text in this TextBox"}
		{command	{Copy}		{Ctrl+C}		0	"copy_messages_text"
			{editcopy}	"Copy selected text into clipboard"}
		{command	{Clear}		{$messages:clear_mess}	1	"clear_messages_text"
			{editdelete}	"Clear all messages"}
		{separator}
		{command	{Find}		{$messages:mess_find}	0	"messages_text_find_dialog"
			{find}		{}}
		{command	{Find next}	{$messages:mess_find_n}	5	"messages_text_find_next"
			{down0}		{}}
		{command	{Find previous}	{$messages:mess_find_p}	8	"messages_text_find_prev"
			{up0}		{}}
	}

	private variable main_frame			;# Widget: Main frame
	private variable messages_text			;# Widget: text widget
	private variable menu			{}	;# Widget: popup menu
	private variable hyperlink_line_start		;# TextIndex: Active hyperlink line start index

	# Variables related to object initialization
	private variable parent				;# Widget: parent widget
	private variable msg_gui_initialized	0	;# Bool: GUI initialized

	# Variables related to search bar
	private variable search_frame			;# Widget: Search bar frame
	private variable last_find_index	{}	;# String: Index of last found occurrence of the search string
	private variable search_string		{}	;# String: Search string
	private variable search_string_length	0	;# Int: Length of the search string
	private variable search_entry			;# Widget: Search bar entry box
	private variable search_find_next		;# Widget: Button "Next"
	private variable search_find_prev		;# Widget: Button "Prev"

	constructor {} {
	}

	destructor {
		# Remove status bar help for popup menus
		if {$menu != {}} {
			menu_Sbar_remove $menu
		}
	}

	## Prepare object for creating its GUI
	 # @parm Widget _parent	- GUI parent widget
	 # @return void
	public method PrepareMessages {_parent} {
		set parent $_parent
		set msg_gui_initialized 0
	}

	## Inform this tab than it has became active
	 # @return void
	public method MessagesTabRaised {} {
		$this bottomnotebook_pageconfigure {Messages} "-image ::ICONS::16::kcmsystem"
		focus $messages_text
	}

	## Create GUI of messages tab
	 # @return void
	public method CreateMessagesGUI {} {
		if {$msg_gui_initialized} {return}
		set msg_gui_initialized 1

		if {${::DEBUG}} {
			puts "CreateMessagesGUI \[ENTER\]"
		}

		## Create GUI of main frame
		set main_frame [frame $parent.main_frame]
		# Create messages text and its scrollbar
		set messages_text [text $main_frame.messages_text	\
			-state disabled -cursor xterm			\
			-yscrollcommand "$main_frame.msg_text_scrl set"	\
			-font $messages_normal_font -wrap word		\
			-tabstyle wordprocessor				\
		]
		set messages_text_scrl [ttk::scrollbar $main_frame.msg_text_scrl	\
			-command "$messages_text yview" -orient vertical		\
		]
		# Text tags for messages text
		$messages_text tag configure error	\
			-foreground #FF0000		\
			-underline 1			\
			-font $messages_bold_font
		$messages_text tag configure error_nu	\
			-foreground #FF0000		\
			-underline 0			\
			-font $messages_bold_font
		$messages_text tag configure warning	\
			-foreground #FF8800		\
			-underline 1			\
			-font $messages_bold_font
		$messages_text tag configure warning_nu	\
			-foreground #FF8800		\
			-underline 0			\
			-font $messages_bold_font
		$messages_text tag configure successful	\
			-foreground #00DD00		\
			-font $messages_bold_font
		$messages_text tag configure hyper_link_over	\
			-foreground #0055FF -underline 0	\
			-font $messages_bold_font
		$messages_text tag raise hyper_link_over

		$messages_text tag bind error	<ButtonPress-1>	"$this messages_text_anchor %x %y"
		$messages_text tag bind error	<Enter>		"$this messages_text_hyperlink_enter %x %y"
		$messages_text tag bind error	<Leave>		"$this messages_text_hyperlink_leave"
		$messages_text tag bind error	<Motion>	"$this messages_text_hyperlink_motion %x %y"
		$messages_text tag bind warning	<ButtonPress-1> "$this messages_text_anchor %x %y"
		$messages_text tag bind warning	<Enter>		"$this messages_text_hyperlink_enter %x %y"
		$messages_text tag bind warning	<Leave>		"$this messages_text_hyperlink_leave"
		$messages_text tag bind warning	<Motion>	"$this messages_text_hyperlink_motion %x %y"
		# Popup menu for messages text
		set menu $messages_text.messages_text_menu
		messages_text_makePopupMenu
		# Bindings for messages text
		bind $messages_text <ButtonPress-1>	"focus $messages_text"
		bind $messages_text <Control-a>		"$this select_all_messages_text"
		bind $messages_text <ButtonRelease-3>	"tk_popup $menu %X %Y; break"
		bind $messages_text <Key-Menu>		"$this messages_text_key_menu; break"
		# Pack parts of main frame
		pack $messages_text -fill both -expand 1 -side left
		pack $messages_text_scrl -fill y -side right
		pack $main_frame -fill both -expand 1

		## Create GUI components in search bar frame
		set search_frame [frame $parent.search_frame]
		 # Search entry box
		set search_entry [ttk::entry $search_frame.entry		\
			-width 30						\
			-validate all						\
			-validatecommand "$this messages_text_search %P"	\
		]
		bind $search_entry <Key-Escape> "$this messages_text_hide_find_dialog"
		 # Button: "Next"
		set search_find_next [ttk::button $search_frame.find_next_but	\
			-image ::ICONS::16::down0				\
			-style Flat.TButton					\
			-command "$this messages_text_find_next"		\
			-state disabled						\
		]
		DynamicHelp::add $search_frame.find_next_but \
			-text [mc "Find next occurrence of search string"]
		 # Button: "Prev"
		set search_find_prev [ttk::button $search_frame.find_prev_but	\
			-image ::ICONS::16::up0					\
			-style Flat.TButton					\
			-command "$this messages_text_find_prev"		\
			-state disabled						\
		]
		DynamicHelp::add $search_frame.find_prev_but \
			-text [mc "Find previous occurrence of search string"]
		 # Button: "Close"
		pack [ttk::button $search_frame.close_but			\
			-image ::ICONS::16::button_cancel			\
			-style Flat.TButton					\
			-command "$this messages_text_hide_find_dialog"		\
		] -side left
		DynamicHelp::add $search_frame.close_but \
			-text [mc "Hide search bar"]
		 # Separator
		pack [ttk::separator $search_frame.sep	\
			-orient vertical		\
		] -fill y -padx 5 -side left -pady 2
		 # Label: "Find"
		pack [label $search_frame.find_lbl	\
			-text [mc "Find:"]		\
		] -side left
		 # Pack entry and buttons next and prev
		pack $search_entry -side left
		pack $search_find_next -side left -padx 5
		pack $search_find_prev -side left
		 # Checkbutton: "Match case"
		pack [checkbutton $search_frame.match_case_chb	\
			-text [mc "Match case"]			\
			-variable ::Todo::match_case		\
			-command "$this messages_text_perform_search 1 1.0"	\
		] -side left -padx 5
		 # Show the search bar frame
		messages_text_find_dialog 0

		messages_text_shortcuts_reevaluate
		unset parent
	}

	## Select all text in messages text
	 # @return void
	public method select_all_messages_text {} {
		if {!$msg_gui_initialized} {CreateMessagesGUI}
		$messages_text tag add sel 1.0 end
	}

	## Copy selected text in messages text into clipboard
	 # @return void
	public method copy_messages_text {} {
		if {!$msg_gui_initialized} {CreateMessagesGUI}
		clipboard clear
		if {[llength [$messages_text tag nextrange sel 1.0]]} {
			clipboard append [$messages_text get sel.first sel.last]
		} else {
			clipboard append [$messages_text get 1.0 end]
		}
	}

	## Create bindings for defined key shortcuts for messages text
	 # @return void
	public method messages_text_shortcuts_reevaluate {} {
		if {!$msg_gui_initialized} {CreateMessagesGUI}

		# Unset previous configuration
		foreach key $set_shortcuts {
			bind $messages_text <$key> {}
		}
		set set_shortcuts {}

		# Iterate over shortcuts definition
		foreach block ${::SHORTCUTS_LIST} {
			# Determinate category
			set category	[lindex $block 0]
			if {[lsearch $shortcuts_cat $category] == -1} {continue}

			# Determinate definition list and its length
			set block	[lreplace $block 0 2]
			set len		[llength $block]

			# Iterate over definition list and create bindings
			for {set i 0; set j 1} {$i < $len} {incr i 2; incr j 2} {
				# Determinate key sequence
				set key [lindex $block $i]
				if {[catch {
					set key $::SHORTCUTS_DB($category:$key)
				}]} then {
					continue
				}
				if {$key == {}} {continue}

				# Create and register new binding
				lappend set_shortcuts $key
				set cmd [subst [lindex $block [list $j 1]]]
				append cmd {;break}
				bind $messages_text <$key> $cmd
				bind $search_entry <$key> $cmd
			}
		}
	}

	## Define popup menu for messages text
	 # @return void
	public method messages_text_makePopupMenu {} {
		if {!$msg_gui_initialized} {return}
		if {[winfo exists $menu]} {
			destroy $menu
		}
		menuFactory $MESSAGESMENU $menu 0 "$this " 0 {} [namespace current]
		$menu entryconfigure [::mc "Find next"] -state disabled
		$menu entryconfigure [::mc "Find previous"] -state disabled
	}

	## Handles event: 'Menu' on messages text -- invoke popup menu
	 # @return void
	public method messages_text_key_menu {} {
		$messages_text see insert
		set bbox [$messages_text bbox [$messages_text index insert]]
		tk_popup $menu	\
			[expr {[winfo rootx $messages_text] + [lindex $bbox 0] + 10}]	\
			[expr {[winfo rooty $messages_text] + [lindex $bbox 1] + 10}]
	}

	## Clear all content of messages text
	 # @return void
	public method clear_messages_text {} {
		if {!$msg_gui_initialized} {CreateMessagesGUI}

		$messages_text configure -state normal
		$messages_text delete 0.0 end
		$messages_text configure -state disabled
	}

	## Go to line (in editor) which is somehow related to some tag in messages text
	 # @parm int x	- relative x coordinate in messages text widget
	 # @parm int y	- relative y coordinate in messages text widget
	 # @return void
	public method messages_text_anchor {x y} {
		# Determinate line number for editor
		set idx [$messages_text index @$x,$y]
		set line [$messages_text get "$idx linestart" "$idx lineend"]
		# Focus on editor and go to that line

		# Message from As31 assembler
		if {[regexp {^(Error)|(Warning)\, line \d+} $line line]} {
			if {![regexp {\d+$} $line lineNum]} {
				set lineNum 0
			}

			if {!$lineNum} {
				return
			}

		# Message from ASEM-51 assembler
		} elseif {[regexp {^([^\(\)]+\(\d+(\,\d+)?\)\: \w+)} $line line]} {
			if {![regexp {\(\d+(\,\d+)?\):} $line lineNum]} {
				set lineNum 0
			} else {
				set lineNum [string range $lineNum 1 end-2]
				set lineNum [lindex [split $lineNum {,}] 0]
			}
			if {[regexp {^.+\(\d+(\,\d+)?\):} $line target_filename]} {
				set target_filename [regsub {\(\d+(\,\d+)?\):$} $target_filename {}]
				set current_filename [lindex [$this editor_procedure {} getFileName {}] 1]
				if {$target_filename != $current_filename} {
					if {![$this fucus_specific_editor $target_filename 0]} {
						return
					}
				}
			}
			if {!$lineNum} {
				return
			}

		# GNU error message (from SDCC or ASL)
		} elseif {[regexp {\:\d+\:} $line linenum]} {
			if {[regexp {[^\:]+\:} $line target_filename]} {
				set target_filename [string trim [string range $target_filename 0 {end-1}]]
				set current_filename [lindex [$this editor_procedure {} getFileName {}] 1]
				if {$target_filename != $current_filename} {
					if {![$this fucus_specific_editor $target_filename 0]} {
						return
					}
				}
			}
			set lineNum [string trim $linenum {:}]

		# Message from MCU8051IDE assembler
		} elseif {[regexp {at \d+ in [^\:]+\:} $line line]} {
			if {[regexp { in [^\:]+\:} $line target_filename]} {
				set target_filename [string trim [string range $target_filename 4 {end-1}] "\""]
				set current_filename [lindex [$this editor_procedure {} getFileName {}] 1]
				if {$target_filename != $current_filename} {
					if {![$this fucus_specific_editor $target_filename 0]} {
						return
					}
				}
			}
			regexp {\d+} $line lineNum

		} else {
			return
		}

		$this editor_procedure {} goto $lineNum
		after idle "
			$this editor_procedure {} focus_in {}
		"
	}

	## Append text at the end of messages text
	 # @parm String txt - Text to append
	 # @return Bool - True if error occurred
	public method messages_text_append {txt} {
		if {!$msg_gui_initialized} {CreateMessagesGUI}

		# Enable the messages text widget
		$messages_text configure -state normal

		set ern 0	;# The text is some error, but text should not be underlined and linked to certain line
		set err 0	;# The text is some error
		set war 0	;# The text is some warning which points to specific line in source code
		set warn 0	;# The text is some warning
		set suc 0	;# The text is success message

		foreach text [split $txt "\n"] {
			set ern		0
			set err		0
			set war		0
			set warn	0
			set suc		0

			set spec 0

			# Determinate number of the last line in the widget
			set row [expr {int([$messages_text index end]) - 1}]

			## Determinate what kind of text will be inserted

			 # check for error which points to specific line in source code
			if {[regexp {^(\|EL\|.*)|^(Compilation error at \d+ in [^\:]+\:)|^(Syntax error at \d+ in [^\:]+\:)|^(Error at\s+\d+ in [^\:]+\:)|^(.+:\d+: .*error.*)|^(.+\(\d+(\,\d+)?\): \w+.*)|^(Error\, line \d+)} $text error]} {
				set len [string length $error]
				set err 1

			 # check for an error
			} elseif {[regexp {^(\|EN\|.*)|^(File access error:)|^(FAILED)|^(Compilation FAILED)|^(Pre-processing FAILED !)|^(Error:)|(^@@@@@ .+ @@@@@$)|(^.*returned errorcode.*)|^(Cannot open input file)|^(Cannot open file)|^(Errors in pass1, assembly aborted)|^(Errors in pass2, assembly aborted)|(: command not found)|(cannot generate code for target 'mcs51')} $text error]} {
				set len [string length $error]
				set ern 1

				if {[regexp {: command not found} $text error]} {
					set spec 2
					set len [string length $text]
				} elseif {[regexp {cannot generate code for target 'mcs51'} $text error]} {
					set spec 3
					set len [string length $text]
				}

			 # a special case of error; unable to find C debug file -- relevant only if user wants to start
			 #+ simulation right after compilation
			} elseif {[regexp {^Unable to find \".*\"$} $text error]} {
				set spec 1
				set len [string length $error]
				if {$::X::compilation_start_simulator} {
					set ern 1
				} else {
					set warn 1
				}

			 # check for warning which points to specific line in source code
			} elseif {[regexp {^(\|WL\|.*)|^(Notice at \d+ in [^\:]+\:)|^(Warning at \d+ in [^\:]+\:)|^(.+:\d+: warning.*)|^(Warning\, line \d+)} $text warning]} {
				set len [string length $warning]
				set war 1

			 # check for a warning
			} elseif {[regexp {^(\|WN\|.*)|^(.*: Warning:.*)|^(Warning:)} $text warning]} {
				set len [string length $warning]
				set warn 1

			 # check for success
			} elseif {[regexp {^(\|SN\|.*)|^((Dec|C)ompilation successful)|(Successful)|(Starting compiler ...)} $text success]} {
				set len [string length $success]
				set suc 1

			 # check for error which points to specific line in source code
			} elseif {[regexp {^(\|EL\|.*)|^(.+:\d+: .*)} $text error]} {
				set len [string length $error]
				set err 1
			}

			regsub {^(\|[EWS][LN]\|)} $text {} text

			# Insert specified text
			$messages_text insert end [regsub -all "\a" [regsub -all {\\} [regsub -all {\\\\} $text "\a"] {}] {\\}]
			$messages_text insert end "\n"

			switch -- $spec {
				0 {}
				1 {	;# Unable to find "<some file>.cdb"
					$messages_text insert end [mc "  |\n"]
					$messages_text insert end [mc "  +-- Most probably that indicates that you have disabled debugging switch, if it is not that what you want then go to\n"]
					$messages_text insert end [mc "      \[Main Menu\] --> \[Configure\] --> \[Compiler configuration\] --> \[C language\] --> \[General\] and enable \"--debug\" compiler switch.\n"]
				}
				2 {	;# /bin/sh: sdcc: command not found
					$messages_text insert end [mc "  |\n"]
					$messages_text insert end [mc "  +-- Most probably that indicates that you have not installed SDCC compiler\n"]
				}
				3 {	;# cannot generate code for target 'mcs51'
					$messages_text insert end [mc "  |\n"]
					$messages_text insert end [mc "  +-- That means that your SDCC compiler does not support MCS-51 architecture, please install SDCC with support for 8051\n"]
				}
			}

			# Insert appropriate text tags
			if {$err || $ern || $war || $warn || $suc} {
				# Insert error tag
				if {$ern} {
					set tag {error_nu}
				# Insert error tag
				} elseif {$err} {
					set tag {error}
				# Insert warning tag
				} elseif {$warn} {
					set tag {warning_nu}
				# Insert warning tag
				} elseif {$war} {
					set tag {warning}
				# Insert success tag
				} elseif {$suc} {
					set tag successful
				}
				$messages_text tag add $tag $row.0 $row.$len
			}
		}

		$messages_text see end
		$messages_text configure -state disabled

		# Change tab icon if some warning or error was displayed there
		if {$err || $ern || $warn || $war} {
			$this bottomnotebook_pageconfigure {Messages} "-image ::ICONS::16::status_unknown"
		}

		return [expr {$err || $ern}]
	}

	## Hide search bar
	 # @return void
	public method messages_text_hide_find_dialog {} {
		if {[winfo ismapped $search_frame]} {
			pack forget $search_frame
		}
	}

	## Show search bar
	 # @parm Bool do_focus_entrybox - Automatically focus the search EntryBox
	 # @return void
	public method messages_text_find_dialog {{do_focus 1}} {
		if {![winfo ismapped $search_frame]} {
			pack $search_frame -before $main_frame -side top -anchor w
			$search_entry delete 0 end
			if {$do_focus} {
				focus -force $search_entry
			}
		} else {
			if {$do_focus} {
				focus -force $search_entry
			}
		}
	}

	## Search for the given string within the text
	 # @parm String string - Text to find
	 # @return Bool - Always 1
	public method messages_text_search {string} {
		if {$string == {}} {
			$search_entry configure -style TEntry
			$search_find_next configure -state disabled
			$search_find_prev configure -state disabled
			$menu entryconfigure [::mc "Find next"] -state disabled
			$menu entryconfigure [::mc "Find previous"] -state disabled
			return 1
		}
		set search_string $string
		messages_text_perform_search 1 1.0

		return 1
	}

	## Perform search for $search_string in the text widget
	 # @parm Bool forw__back	- 1 == Search forwards; 0 == Search backard
	 # @parm String from		- Start index
	 # @return void
	public method messages_text_perform_search {forw__back from} {
		if {$search_string == {}} {return}

		if {$forw__back} {
			set direction {-forwards}
		} else {
			set direction {-backwards}
		}
		if {${::Todo::match_case}} {
			set last_find_index [$messages_text search $direction -- $search_string $from]
		} else {
			set last_find_index [$messages_text search $direction -nocase -- $search_string $from]
		}
		if {$last_find_index == {}} {
			$search_entry configure -style StringNotFound.TEntry
			$search_find_next configure -state disabled
			$search_find_prev configure -state disabled
			$menu entryconfigure [::mc "Find next"] -state disabled
			$menu entryconfigure [::mc "Find previous"] -state disabled
		} else {
			$search_entry configure -style StringFound.TEntry
			$search_find_next configure -state normal
			$search_find_prev configure -state normal
			$menu entryconfigure [::mc "Find next"] -state normal
			$menu entryconfigure [::mc "Find previous"] -state normal

			set search_string_length [string length $search_string]
			$messages_text see $last_find_index
			catch {
				$messages_text tag remove sel 0.0 end
			}
			$messages_text tag add sel $last_find_index $last_find_index+${search_string_length}c
		}
	}

	## Find next occurrence of the search string
	 # @return void
	public method messages_text_find_next {} {
		if {![winfo ismapped $search_frame]} {
			pack $search_frame -before $main_frame -side top -anchor w
		}
		if {$last_find_index == {}} {
			return
		}
		messages_text_perform_search 1 $last_find_index+${search_string_length}c
	}

	## Find previous occurrence of the search string
	 # @return void
	public method messages_text_find_prev {} {
		if {![winfo ismapped $search_frame]} {
			pack $search_frame -before $main_frame -side top -anchor w
		}
		if {$last_find_index == {}} {
			return
		}
		messages_text_perform_search 0 $last_find_index
	}

	## Enter hyperlink
	 # @parm Int x - Relative pointer position
	 # @parm Int x - Relative pointer position
	 # @return void
	public method messages_text_hyperlink_enter {x y} {
		set hyperlink_line_start [$messages_text index [list @$x,$y linestart]]
		hyperlink_active
	}

	## Leave hyperlink
	 # @return void
	public method messages_text_hyperlink_leave {} {
		$messages_text config -cursor xterm
		$messages_text tag remove hyper_link_over 0.0 end
	}

	## Enter pointer motion
	 # @parm Int x - Relative pointer position
	 # @parm Int x - Relative pointer position
	 # @return void
	public method messages_text_hyperlink_motion {x y} {
		set line_start [$messages_text index [list @$x,$y linestart]]
		if {$hyperlink_line_start == $line_start} {
			return
		}
		set hyperlink_line_start $line_start
		$messages_text tag remove hyper_link_over 0.0 end
		hyperlink_active
	}

	## Highlight hyperlink on line $hyperlink_line_start
	 # @return void
	private method hyperlink_active {} {
		set range [$messages_text tag nextrange error $hyperlink_line_start [list $hyperlink_line_start lineend]]
		if {![llength $range]} {
			set range [$messages_text tag nextrange warning $hyperlink_line_start [list $hyperlink_line_start lineend]]
		}
		if {![llength $range]} {
			return
		}
		$messages_text config -cursor hand2
		$messages_text tag add hyper_link_over [lindex $range 0] [lindex $range 1]
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

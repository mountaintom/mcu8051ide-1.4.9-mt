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
if { ! [ info exists _SFRWATCHES_TCL ] } {
set _SFRWATCHES_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides SFR watches for left panel
# --------------------------------------------------------------------------

class SFRWatches {

	## COMMON
	 # Font for addresses and register names
	public common main_font	[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-14 * $::font_size_factor)}]	\
		-weight bold					\
	]
	 # Just another font but not bold
	public common roman_font	[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-14 * $::font_size_factor)}]	\
	]
	 # Fonr for register entry boxes
	public common entry_font	[font create			\
		-family $::DEFAULT_FIXED_FONT			\
		-size [expr {int(-12 * $::font_size_factor)}]	\
		-weight bold					\
	]

	## PRIVATE
	private variable text_widget			;# Widget: Text widget containing SFR watches
	private variable scrollbar		{}	;# Widget: Scrollbar for $text_widget
	private variable search_entry			;# Widget: Search entry box at the bottom of the panel
	private variable search_clear_but		;# Widget: Button "Clear" at the bottom of the panel
	private variable main_left_frame		;# Widget: Frame containing $text_widget and its header label
	private variable entry_count		0	;# Int: Number of SFRs
	private variable validation_ena		1	;# Bool: SFR entry box validation enabled
	private variable haddr2idx			;# Array: $haddr2idx($hex_addr) --> row_in_text_widget - 1
	private variable addr2idx			;# Array: $addr2idx($dec_addr) --> row_in_text_widget - 1
	private variable reg2idx			;# Array: $addr2idx($register_name_uppercase) --> row_in_text_widget - 1
	private variable last_selected_line	0	;# Int: Selected row in the text widget
	private variable search_ena		1	;# Bool: Search enabled
	private variable menu				;# Widget: Popup menu for the text widget

	# Variables related to object initialization
	private variable parent				;# Parent GUI object (tempotary variable)
	private variable sfrw_gui_initialized	0	;# GUI ready

	constructor {} {
	}

	destructor {
		if {$sfrw_gui_initialized} {
			menu_Sbar_remove $menu
		}
	}

	## Prepare object for creating its GUI
	 # @parm Widget _parent - parent container (some frame)
	 # @return void
	public method PrepareSFRWatches {_parent} {
		set parent $_parent
		set sfrw_gui_initialized 0
	}

	## Initialize SFR watches GUI
	 # @return void
	public method CreateSFRWatchesGUI {} {
		if {$sfrw_gui_initialized} {return}
		set sfrw_gui_initialized 1

		set validation_ena 0
		create_GUI
		fill_gui
		set validation_ena 1

		if {![$this is_frozen]} {
			sfr_watches_disable
		}
	}

	## Create entry box to embedd in the text widget
	 # @parm Int i		- Entry index (row - 1)
	 # @parm String type	- Entry type (hex or dec)
	 # @parm Int addr	- SFR address (128..255)
	 # @parm String reg	- SFR name (e.g. PSW)
	 # @return Widget - Created entry box
	private method create_entry {i type addr reg} {
		# Determine entry box width
		if {$type == {hex}} {
			set width 2
		} else {
			set width 3
		}

		# Create entry widget
		set entry [entry $text_widget.${type}_entry_${i}		\
			-width $width 		-font $entry_font		\
			-bg {#FFFFFF}		-validate all			\
			-takefocus 0		-highlightthickness 0		\
			-disabledbackground {#FFFFFF}				\
			-vcmd "$this sfr_watches_validate ${type} $addr %P"	\
			-bd 0			-justify right			\
		]

		# Perform name correction for accumulators
		if {$reg == {A} || $reg == {B}} {
			append reg {_hex}
		}

		# Set event bindins
		bind $entry <Motion>	{help_window_show %X %Y}
		bind $entry <Leave>	{help_window_hide}
		bind $entry <FocusIn>	"$this unmark_entry $addr"
		bind $entry <Enter>	"$this create_help_window_ram $reg"
		bind $entry <Button-1>	"$this sfr_watches_select_line 0 [expr {$i + 1}] $type"
		bind $entry <Key-Up>	"$this sfr_watches_up $type 1"
		bind $entry <Key-Down>	"$this sfr_watches_down $type 1"
		bind $entry <Key-Next>	"$this sfr_watches_down $type 4"
		bind $entry <Key-Prior>	"$this sfr_watches_up $type 4"
		bind $entry <Button-4>	"$text_widget yview scroll -5 units"
		bind $entry <Button-5>	"$text_widget yview scroll +5 units"
		if {$type == {hex}} {
			bind $entry <Key-Right>	"
				focus $text_widget.dec_entry_${i}
				$text_widget.dec_entry_${i} selection clear
				update
				$text_widget.dec_entry_${i} icursor 0"
		} else {
			bind $entry <Key-Left>	"
				focus $text_widget.hex_entry_${i}
				$text_widget.hex_entry_${i} selection clear
				update
				$text_widget.dec_entry_${i} icursor end"
		}

		return $entry
	}

	## Complite GUI initialization (load all SFRs into the text widget)
	 # @return void
	private method fill_gui {} {
		set entry_count 0
		set validation_ena 0

		# Iterate over defined SFRs ({{addr name} ... })
		foreach reg [$this simulator_get_sfrs] {
			# Determine hexadecimal address
			set addr [lindex $reg 0]
			set hex_addr [format %X $addr]
			if {[string length $hex_addr] == 1} {
				set hex_addr "0$hex_addr"
			} elseif {[string length $hex_addr] == 3} {
				set hex_addr [string replace $hex_addr 0 0]
			}
			# Determine register name and make it 8 characters long
			set reg [lindex $reg 1]
			set reg_org $reg
			switch -- $reg {
				SBUFR {
					set reg {SBUF R}
				}
				SBUFT {
					set reg {SBUF T}
				}
				default {
					set reg $reg
				}
			}
			append reg [string repeat { } [expr {8 - [string length $reg]}]]

			# Register this SFR
			set haddr2idx($hex_addr) $entry_count
			set addr2idx($addr) $entry_count
			set reg2idx($reg_org) $entry_count

			# Insert address and name into the text widget
			$text_widget insert end $hex_addr
			$text_widget insert end { }
			$text_widget insert end $reg

			# Set highlighting tags
			set line [expr {int([$text_widget index insert])}]
			$text_widget tag add tag_addr $line.0 $line.2
			$text_widget tag add tag_name $line.3 $line.11

			# Create and insert embedded entry boxes
			set entry [create_entry $entry_count hex $addr $reg_org]
			$entry insert 0 [$this getSfr $addr]
			$text_widget window create end -window $entry -pady 0
			$text_widget insert end { }
			set entry [create_entry $entry_count dec $addr $reg_org]
			$entry insert 0 [$this getSfrDEC $addr]
			$text_widget window create end -window $entry -pady 0

			# Finalize this row
			$text_widget insert end "\n"
			incr entry_count
		}

		# Remove the last line (empty line) and disable the text widget
		$text_widget delete end-1l end
		set validation_ena 1
	}

	## Set value of SFR at current line to the specified value
	 # @parm String value - Hexadecimal value
	 # @return void
	public method sfr_watches_set_current_to {value} {
		set idx [expr {$last_selected_line - 1}]
		set addr [lindex [$this simulator_get_sfrs] [list $idx 0]]

		$this setSfr $addr $value
		$this Simulator_GUI_sync S $addr
	}

	## Create GUI elements of this panel
	 # @return void
	private method create_GUI {} {
		# Create and pack panel frames
		set main_frame [frame $parent.main_frame]
		set main_left_frame [frame $main_frame.left]
		pack $main_left_frame -side left -fill both -expand 1
		pack $main_frame -fill both -expand 1

		# Create text widget and its header
		pack [label $main_left_frame.header_label	\
			-anchor w -justify left -pady 0 -padx 2	\
			-fg ${::Simulator_GUI::small_color}	\
			-font ${::Simulator_GUI::smallfont}	\
			-text "[mc {Register}]		[mc {HEX}]    [mc {DEC}]" -width 1	\
		] -fill x -pady 0 -anchor nw
		set text_widget [text $main_left_frame.text		\
			-bg {#FFFFFF} -font $roman_font -bd 2		\
			-width 0 -height 0 -wrap none			\
			-yscrollcommand "$this sfr_watches_scroll_set"	\
			-cursor left_ptr				\
		]

		# Create popup menu for the text widget
		set menu $text_widget.menu
		menuFactory {
			{command	{Set to 0x00}	{}	9	"sfr_watches_set_current_to 00"
				{}	"Set this register to 0"}
			{command	{Set to 0xFF}	{}	9	"sfr_watches_set_current_to FF"
				{}	"Set this register to 255"}
		} $menu 0 "$this " 0 {} [namespace current]

		# Set event bindings for the text widget
		bindtags $text_widget $text_widget
		foreach event {
			<ButtonRelease-1>	<B1-Enter>	<B1-Leave>
			<B2-Motion>		<Button-5>	<Button-4>
			<MouseWheel>
		} {
			bind $text_widget $event [bind Text $event]
		}
		bind $text_widget <Button-1>	\
			"$this sfr_watches_select_line 0 \[expr {int(\[%W index @%x,%y\])}\] hex"
		bind $text_widget <ButtonRelease-3>	\
			"$this sfr_watches_select_line 0 \[expr {int(\[%W index @%x,%y\])}\] hex
			tk_popup $menu %X %Y"

		# Pack the text widget and create its scrollbar
		pack $text_widget -fill both -expand 1
		set scrollbar [ttk::scrollbar $main_frame.scrollbar	\
			-orient vertical -command "$text_widget yview"	\
		]

		# Create bottom frame (search bar)
		set search_frame [frame $parent.top]
		pack [label $search_frame.lbl	\
			-text [mc "Search:"]	\
		] -side left
		set search_entry [ttk::entry $search_frame.entry		\
			-width 0						\
			-validate all						\
			-validatecommand "$this sfr_watches_search_validate %P"	\
		]
		pack $search_entry -side left -fill x -expand 1
		set search_clear_but [ttk::button $search_frame.button	\
			-style Flat.TButton				\
			-state disabled					\
			-image ::ICONS::16::clear_left			\
			-command "$search_entry delete 0 end"		\
		]
		pack $search_clear_but -side right -after $search_entry
		pack $search_frame -fill x

		# Create highlighting tags for the text widget
		$text_widget tag configure tag_addr	\
			-foreground {#000000} -font $main_font
		$text_widget tag configure tag_name	\
			-foreground {#0000DD} -font $main_font
		$text_widget tag configure tag_curLine	\
			-background ${::RightPanel::selection_color_dark}
	}

	## Adjust scrollbar
	 # @parm Float frac0 - 1st fraction
	 # @parm Float frac1 - 2nd fraction
	 # @return void
	public method sfr_watches_scroll_set {frac0 frac1} {
		if {$scrollbar == {}} {
			return
		}

		# Hide scrollbar
		if {$frac0 == 0 && $frac1 == 1} {
			if {[winfo ismapped $scrollbar]} {
				pack forget $scrollbar
			}
		# Show scrollbar
		} else {
			if {![winfo ismapped $scrollbar]} {
				pack $scrollbar			\
					-side left		\
					-fill y			\
					-after $main_left_frame
			}
			$scrollbar set $frac0 $frac1
		}
	}

	## Validate content of search entry box at the bottom bar
	 # @parm String string - String to validate
	 # @return Bool - Always 1
	public method sfr_watches_search_validate {string} {
		# Check if searching is enabled
		if {!$search_ena} {return 1}

		# Adjust state of clear button (+ clear selection on the text widget)
		if {$string == {}} {
			$search_clear_but configure -state disabled
			$search_entry configure -style TEntry
			sfr_watches_select_line 1 0 hex
			return 1
		} else {
			$search_clear_but configure -state normal
		}

		set string [string toupper $string]

		# Perform case insensitive search for the given chunk of SFR name and address
		foreach arr {reg2idx haddr2idx} {
			foreach str [lsort -ascii -increasing [array names $arr]] {
				# Search successful
				if {![string first $string $str]} {
					$search_entry configure -style StringFound.TEntry
					sfr_watches_select_line 1 [expr {[subst -nocommands "\${${arr}(${str})}"] + 1}] hex
					return 1
				}
			}
		}

		# Search failed
		$search_entry configure -style StringNotFound.TEntry
		return 1
	}

	## Select line in the text widget
	 # @parm Bool search	- Invoked form search validator (do not clear search entry box)
	 # @parm Int line	- Target line
	 # @parm String type	- Entry box to select (hex or dec)
	 # @return void
	public method sfr_watches_select_line {search line type} {

		# Unselect the last selected line and determinate cursor position
		if {$last_selected_line} {
			$text_widget tag remove tag_curLine 0.0 end
			$this simulator_reg_label_set_highlighted $last_selected_line 0
			incr last_selected_line -1
			foreach tp {dec hex} {
				$text_widget.${tp}_entry_$last_selected_line selection clear
				$text_widget.${tp}_entry_$last_selected_line configure	\
					-bg {#FFFFFF} -disabledbackground {#FFFFFF}
			}
			set cursor [$text_widget.${type}_entry_$last_selected_line index insert]
		} else {
			set cursor 0
		}

		# Adjust last selected line (if 0 the return)
		set last_selected_line $line
		if {!$line} {
			return
		}


		# Highlight this line as selected in the text widget
		$text_widget tag add tag_curLine	\
			$last_selected_line.0		\
			$last_selected_line.0+1l
		$text_widget see $last_selected_line.0

		# Highlight SFR on this line in simulator control panel
		$this simulator_reg_label_set_highlighted $last_selected_line 1

		# Adjust background color for entry boxes at this line
		incr line -1
		$text_widget.dec_entry_$line configure			\
			-fg ${Simulator::normal_color}			\
			-bg ${::RightPanel::selection_color_dark}	\
			-disabledbackground ${::RightPanel::selection_color_dark}
		$text_widget.hex_entry_$line configure			\
			-fg ${Simulator::normal_color}			\
			-bg ${::RightPanel::selection_color_dark}	\
			-disabledbackground ${::RightPanel::selection_color_dark}

		# Clear search entry box and focus and entry box at this line
		if {!$search} {
			$text_widget.${type}_entry_$line icursor $cursor
			$text_widget.${type}_entry_$line selection range 0 end
			focus $text_widget.${type}_entry_$line
			set search_ena 0
			$search_entry delete 0 end
			set search_ena 1
		}
	}

	## Validator for SFR value entry boxes
	 # @parm String type	- Entry box type (hex or dec)
	 # @parm Int addr	- Register address
	 # @parm String value	- String to validate
	 # @return Bool - Validation result
	public method sfr_watches_validate {type addr value} {
		# Prevent recursion
		if {!$validation_ena} {return 1}
		set validation_ena 0

		# Validate value
		if {$value == {}} {
			set value 0
		}
		if {$type == {hex}} {
			if {![string is xdigit $value]} {
				set validation_ena 1
				return 0
			}
			set value [expr "0x$value"]
		} else {
			if {![string is digit $value]} {
				set validation_ena 1
				return 0
			}
		}
		if {$value > 255 || $value < 0} {
			set validation_ena 1
			return 0
		}

		# Synchronize with engine and simulator control panel
		$this setSfr $addr [format %X $value]
		$this SimGUI_disable_sync
		$this Simulator_GUI_sync S $addr
		$this SimGUI_enable_sync

		# Synchronize with the other one entry box
		if {$type == {hex}} {
			$text_widget.dec_entry_$addr2idx($addr) delete 0 end
			$text_widget.dec_entry_$addr2idx($addr) insert 0 $value
		} else {
			set value [format %X $value]
			if {[string length $value] == 1} {
				set value "0$value"
			}
			$text_widget.hex_entry_$addr2idx($addr) delete 0 end
			$text_widget.hex_entry_$addr2idx($addr) insert 0 $value
		}

		# Done
		set validation_ena 1
		return 1
	}

	## Remove all SFRs for the text widget and unregister them
	 # @return void
	private method clear_gui {} {
		if {!$sfrw_gui_initialized} {return}

		# Clear SFR name label highlight in simultor contol panel
		if {$last_selected_line} {
			$this simulator_reg_label_set_highlighted $last_selected_line 0
		}

		# Reset object variables
		array unset haddr2idx
		array unset addr2idx
		array unset reg2idx
		set last_selected_line 0
		set entry_count 0

		# Clear the text widget
		$text_widget delete 1.0 end
		foreach wdg [$text_widget window names] {
			destroy $wdg
		}
	}

	## Set new value of certain SFR in this panel
	 # @parm Int addr	- SFR address
	 # @parm Int new_val	- New SFR value
	 # @return void
	public method sfr_watches_sync {addr new_val} {
		if {!$sfrw_gui_initialized} {return}

		# Prevent recursion
		if {!$validation_ena} {return}
		set validation_ena 0

		# Check if this SFR is available here
		if {[lsearch [array names addr2idx] $addr] == -1} {
			set validation_ena 1
			return
		}

		# Determinate references of HEX and DEC entry boxes
		set hex_entry $text_widget.hex_entry_$addr2idx($addr)
		set dec_entry $text_widget.dec_entry_$addr2idx($addr)

		# Highlight entry boxes
		set org_val [$dec_entry get]
		if {$org_val != $new_val} {
			$hex_entry configure -fg ${::Simulator_GUI::hcolor}
			$dec_entry configure -fg ${::Simulator_GUI::hcolor}
		}

		# Set decimal value
		$dec_entry delete 0 end
		$dec_entry insert 0 $new_val

		# Set hexadecimal value
		set new_val [format %X $new_val]
		if {[string length $new_val] == 1} {
			set new_val "0$new_val"
		}
		$hex_entry delete 0 end
		$hex_entry insert 0 $new_val

		# Reenable entry box value validations
		set validation_ena 1
	}

	## Enable this panel
	 # @return vois
	public method sfr_watches_enable {} {
		if {!$sfrw_gui_initialized} {return}
		$menu entryconfigure [::mc "Set to 0x00"] -state normal
		$menu entryconfigure [::mc "Set to 0xFF"] -state normal
		for {set i 0} {$i < $entry_count} {incr i} {
			$text_widget.hex_entry_$i configure -state normal
			$text_widget.dec_entry_$i configure -state normal
		}
	}

	## Disable this panel
	 # @return vois
	public method sfr_watches_disable {} {
		if {!$sfrw_gui_initialized} {return}
		$menu entryconfigure [::mc "Set to 0x00"] -state disabled
		$menu entryconfigure [::mc "Set to 0xFF"] -state disabled
		for {set i 0} {$i < $entry_count} {incr i} {
			$text_widget.hex_entry_$i configure -state disabled
			$text_widget.dec_entry_$i configure -state disabled
		}
	}

	## This function shuld be call after processor was changed
	 # Reload available SFRs
	 # @return void
	public method sfr_watches_commit_new_sfr_set {} {
		if {!$sfrw_gui_initialized} {return}
		clear_gui
		fill_gui
	}

	## Move selected line up
	 # @parm String type	- Which entry box should be selected (hex or dec)
	 # @parm Int lines	- Number of lines to move by
	 # @return void
	public method sfr_watches_up {type lines} {
		set line $last_selected_line
		incr line -$lines
		if {$line <= 0} {
			set line $entry_count
		}

		sfr_watches_select_line 0 $line $type
	}

	## Move selected line down
	 # @parm String type	- Which entry box should be selected (hex or dec)
	 # @parm Int lines	- Number of lines to move by
	 # @return void
	public method sfr_watches_down {type lines} {
		set line $last_selected_line
		incr line $lines
		if {$line >= $entry_count} {
			set line 0
		}

		sfr_watches_select_line 0 $line $type
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

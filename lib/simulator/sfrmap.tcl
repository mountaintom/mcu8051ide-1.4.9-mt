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
if { ! [ info exists _SFRMAP_TCL ] } {
set _SFRMAP_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements window showing the map of available special function register
# --------------------------------------------------------------------------

class SFRMap {
	## COMMON
	public common sfrmap_count			0	;# Int: Counter of object instances

	## PRIVATE
	private variable dialog_opened		0	;# Bool: Dialog window opened
	private variable defined_sfr			;# List: Addresses of defined SFR in this dialog
	private variable win				;# Widget: Dialog window
	private variable enabled		0	;# Bool: True if simulator is engaged
	private variable validation_ena		0	;# Bool: Entry boxes validation enabled
	private variable main_frame			;# Widget: Frame containing registers
	private variable det_name			;# Widget: Entry box on bottom bar (Register name)
	private variable det_hex			;# Widget: Entry box on bottom bar (HEX)
	private variable det_dec			;# Widget: Entry box on bottom bar (DEC)
	private variable det_bin			;# Widget: Entry box on bottom bar (BIN)
	private variable det_oct			;# Widget: Entry box on bottom bar (OCT)
	private variable bottom_right_frame		;# Widget: Bottom right frame
	private variable selected_entry		-1	;# Int: Address of selected entry box in the map

	constructor {} {
		incr sfrmap_count
	}

	destructor {
		if {$dialog_opened} {
			destroy $win
		}
	}

	## Invoke dialog window
	 # @return void
	public method sfrmap_invoke_dialog {} {
		if {$dialog_opened} {return}
		set dialog_opened 1

		# Create dialog window
		set enabled [$this is_frozen]
		set win [toplevel .sfr_map${sfrmap_count} -bg {#FFFFFF} -class {SFR map} -bg ${::COMMON_BG_COLOR}]

		# Create other widgets
		create_win_gui

		# Configure the window
		wm iconphoto $win ::ICONS::16::kcmmemory_S
		wm title $win "[mc {Map of SFR area}] - [$this cget -P_option_mcu_type] - [$this cget -projectName] - MCU 8051 IDE"
		wm resizable $win 0 0
		wm protocol $win WM_DELETE_WINDOW "$this sfrmap_close_dialog"
		bindtags $win [list $win Toplevel all .]
	}

	## Create window widgets
	 # @return void
	private method create_win_gui {} {
		set main_frame [frame $win.main_frame -bg {#888888}]

		## Create headers for main frame
		 # Horizontal headers
		set header_idx 0
		for {set i 0; set j 8; set col 1} {$i < 8} {incr i; incr j; incr col} {
			set k [format %X $j]
			grid [label $main_frame.header_$header_idx		\
				-text "$i/$k" -bg {#FFFFFF} -fg {#555555}	\
			] -sticky nsew -column $col -row 0
			incr header_idx
			grid [label $main_frame.header_$header_idx		\
				-text "$i/$k" -bg {#FFFFFF} -fg {#555555}	\
			] -sticky nsew -column $col -row 17 -pady 1
			incr header_idx
		}
		 # Vertical headers
		set row 1
		foreach left	{F8h F0h E8h E0h D8h D0h C8h C0h B8h B0h A8h A0h 98h 90h 88h 80h} \
			right	{FFh F7h EFh E7h DFh D7h CFh C7h BFh B7h AFh A7h 9Fh 97h 8Fh 87h} \
		{
			grid [label $main_frame.header_$header_idx	\
				-text $left -bg {#FFFFFF} -fg {#555555}	\
			] -sticky nsew -column 0 -row $row
			incr header_idx
			grid [label $main_frame.header_$header_idx		\
				-text $right -bg {#FFFFFF} -fg {#555555}	\
			] -sticky nsew -column 9 -row $row -padx 1
			incr row
			incr header_idx
		}
		 # Corners
		foreach row {0 0 17 17} col {0 9 0 9} {
			grid [frame $main_frame.header_$header_idx -bg {#FFFFFF}]	\
				-row $row -column $col -sticky nsew
			incr header_idx
		}

		# Create separate frame for each cell
		set addr 128
		for {set row 16} {$row > 0} {incr row -1} {
			for {set col 1} {$col < 9} {incr col} {
				set frame [frame $main_frame.cell_$addr -bg {#DDDDDD} -padx 1]
				grid $frame					\
					-row $row	-column $col		\
					-sticky nsew 	-padx [expr {$col % 2}]	\
					-pady [expr {$row % 2}]
				incr addr
			}
		}

		# Insure than all cells have the same width and heigh
		for {set i 1} {$i < 9} {incr i} {
			grid columnconfigure $main_frame $i -uniform sfr_col
		}
		for {set i 1} {$i < 17} {incr i} {
			grid rowconfigure $main_frame $i -uniform sfr_row
		}

		# Create matrix of SFR
		set validation_ena 0
		set defined_sfr {}
		foreach reg [$this simulator_get_sfrs] {
			set addr [lindex $reg 0]
			set name [lindex $reg 1]
			set row 0

			if {$addr > 255} {
				continue
			}
			if {$name == {SBUFR} || $name == {SBUFT}} {
				set name {SBUF}
			}

			if {!($addr % 8)} {
				set fg {#00DDDD}
			} else {
				set fg {#0000DD}
			}
			$main_frame.cell_$addr configure -bg {#FFFFFF}
			pack [label $main_frame.lbl_${addr}		\
				-text $name -bg {#FFFFFF} -fg $fg	\
			] -in $main_frame.cell_$addr -side left

			grid columnconfigure $main_frame.cell_$addr 0 -weight 1
			if {$name == {SBUF}} {
				continue
			}
			lappend defined_sfr $addr

			set entry [ttk::entry $main_frame.ent_${addr}			\
				-validatecommand "$this sfrmap_validate $addr h %P m"	\
				-style Simulator_WhiteBg.TEntry				\
				-validate all						\
				-takefocus 0						\
				-width 3						\
				-font ${::Simulator_GUI::entry_font}			\
			]
			pack $entry -in $main_frame.cell_$addr -side right
			$entry insert end [$this getSfr $addr]
			if {!$enabled} {
				$entry configure -state disabled
			}

			bindtags $entry [list $entry TEntry $win all .]
			bind $entry <Motion>	{help_window_show %X %Y+30}
			bind $entry <Leave>	{help_window_hide}
			bind $entry <FocusIn>	"$this sfrmap_map_cell_focused $addr $name"
			set hex_addr [format %X $addr]
			if {[string length $hex_addr] == 1} {
				set hex_addr "0$hex_addr"
			}
			bind $entry <Enter>	"create_help_window $win \[$this getSfr $addr\] {$hex_addr SFR}"
		}
		set validation_ena 1

		## Create bottom frame
		set bottom_frame [frame $win.bottom_frame -bg {#FFFFFF}]
		 # Create label "Reserved"
		pack [label $bottom_frame.res_0 -text [mc "Reserved"] -bg {#FFFFFF}] -side left
		pack [label $bottom_frame.res_1 -width 6 -bg {#CCCCCC} -bd 1 -relief raised]	\
			-side left -pady 5
		pack [frame $bottom_frame.frame_foo -width 20] -side left
		 # Create label "Bit addressable"
		pack [label $bottom_frame.bit_0 -text [mc "Bit addressable"] -bg {#FFFFFF}] -side left
		pack [label $bottom_frame.bit_1 -width 6 -bg {#00DDDD} -bd 1 -relief raised]	\
			-side left -pady 5
		 # Create bottom right frame (additional entry boxes)
		set bottom_right_frame [frame $bottom_frame.bottom_right -bg {#FFFFFF}]
		set det_name [label $bottom_right_frame.name_lbl	\
			-bg {#FFFFFF} -fg {#0000DD}			\
		]
		set det_hex [ttk::entry $bottom_right_frame.hex_entry		\
			-validatecommand "$this sfrmap_validate {} h %P p"	\
			-style Simulator_WhiteBg.TEntry				\
			-validate all						\
			-width 3						\
		]
		set det_dec [ttk::entry $bottom_right_frame.dec_entry		\
			-validatecommand "$this sfrmap_validate {} d %P p"	\
			-style Simulator_WhiteBg.TEntry				\
			-validate all						\
			-width 3						\
		]
		set det_bin [ttk::entry $bottom_right_frame.bin_entry		\
			-validatecommand "$this sfrmap_validate {} b %P p"	\
			-style Simulator_WhiteBg.TEntry				\
			-validate all						\
			-width 8						\
		]
		set det_oct [ttk::entry $bottom_right_frame.oct_entry		\
			-validatecommand "$this sfrmap_validate {} o %P p"	\
			-style Simulator_WhiteBg.TEntry				\
			-validate all						\
			-width 3						\
		]
		foreach entry [list $det_hex $det_dec $det_bin $det_oct] {
			bind $entry <FocusIn> "$this sfrmap_panel_entrybox_focused"
			bindtags $entry [list $entry TEntry $win all .]
		}
		pack [ttk::separator $bottom_right_frame.sep -orient vertical] -side left -fill y -padx 3
		pack $det_name -side left

		pack [label $bottom_right_frame.lbl_hex		\
			-text [mc "HEX:"] -pady 0 -bg {#FFFFFF}	\
			-font ${::Simulator_GUI::smallfont}	\
			-fg ${::Simulator_GUI::small_color}	\
		] -side left
		pack $det_hex -side left
		pack [label $bottom_right_frame.lbl_dec		\
			-text [mc "DEC:"] -pady 0 -bg {#FFFFFF}	\
			-font ${::Simulator_GUI::smallfont}	\
			-fg ${::Simulator_GUI::small_color}	\
		] -side left
		pack $det_dec -side left
		pack [label $bottom_right_frame.lbl_bin		\
			-text [mc "BIN:"] -pady 0 -bg {#FFFFFF}	\
			-font ${::Simulator_GUI::smallfont}	\
			-fg ${::Simulator_GUI::small_color}	\
		] -side left
		pack $det_bin -side left
		pack [label $bottom_right_frame.lbl_oct		\
			-text [mc "OCT:"] -pady 0 -bg {#FFFFFF}	\
			-font ${::Simulator_GUI::smallfont}	\
			-fg ${::Simulator_GUI::small_color}	\
		] -side left
		pack $det_oct -side left

		# Pack main and bottom frame
		pack $main_frame -fill both
		pack $bottom_frame -side bottom -fill x
	}

	## Close the dialog window
	 # @return void
	public method sfrmap_close_dialog {} {
		if {!$dialog_opened} {return}
		set dialog_opened 0
		destroy $win
	}

	## Binding for event <FocusIn> on SFR entry box in the matrix
	 # @parm Int addr	- Register address
	 # @parm String name	- Register name
	 # @return void
	public method sfrmap_map_cell_focused {addr name} {
		set selected_entry $addr

		# Pack bottom right frame if it has not been packed yet
		if {![winfo viewable $bottom_right_frame]} {
			pack $bottom_right_frame -side right -padx 5
		}

		# Adjust entry boxes
		sfrmap_validate $addr h [$main_frame.ent_${addr} get] m
		$det_name configure -text "${name}:"

		# Restore normal color
		foreach entry [list $main_frame.ent_${addr} $det_hex $det_oct $det_bin $det_dec] {
			$entry configure -style Simulator_WhiteBg.TEntry
		}

		# Disable these entry boxes
		if {!$enabled} {
			foreach entry [list $det_hex $det_oct $det_bin $det_dec] {
				$entry configure -state disabled
			}
		}
	}

	## Binding for event <FocusIn> on SFR entry box in the bottom right panel
	 # Restore normal color for all enty boxes related to the selected SFR
	 # @return void
	public method sfrmap_panel_entrybox_focused {} {
		foreach entry [list $main_frame.ent_${selected_entry} $det_hex $det_oct $det_bin $det_dec] {
			$entry configure -style Simulator_WhiteBg.TEntry
		}
	}

	## Set value for certain register
	 # @parm Int addr	- Register address
	 # @parm Int value	- New register value
	 # @return void
	public method sfrmap_map_sync {addr val} {
		# Check if this call has some meaning
		if {!$dialog_opened || !$validation_ena} {return}
		if {[lsearch $defined_sfr $addr] == -1} {return}
		set original_val [$main_frame.ent_${addr} get]
		if {[expr "0x$original_val"] == $val} {
			return
		}

		# Adjust value
		set val [format %X $val]
		if {[string length $val] == 1} {
			set val "0$val"
		}

		# Set value
		$main_frame.ent_${addr} delete 0 end
		$main_frame.ent_${addr} insert 0 $val

		# Highlight entry boxes
		$main_frame.ent_${addr} configure -style Simulator_WhiteBg_HG.TEntry
		if {$selected_entry == $addr} {
			foreach entry [list $det_hex $det_oct $det_bin $det_dec] {
				$entry configure -style Simulator_WhiteBg_HG.TEntry
			}
		}
	}

	## Validate value in some entry box in the matrix
	 # @parm Int addr	- Register address
	 # @parm Char type	- h == HEX; o == OCT; b == BIN; d == DEC
	 # @parm String value	- Content to validate
	 # @parm Char from	- m == Matrix; p == Bottom panel
	 # @return Bool - Result
	public method sfrmap_validate {addr type value from} {
		# Prevent recursion
		if {!$validation_ena} {return 1}
		set validation_ena 0

		if {$from == {p}} {
			set addr $selected_entry
		}

		# Validate the value
		set value [string trimleft $value 0]
		if {$value == {}} {
			set value 0
		}
		switch -- $type {
			h {
				if {[string length $value] > 2 || ![string is xdigit $value]} {
					set validation_ena 1
					return 0
				}
				set value [expr "0x$value"]
			}
			d {
				if {[string length $value] > 3 || ![string is digit $value]} {
					set validation_ena 1
					return 0
				}
			}
			b {
				if {[string length $value] > 8 || ![regexp {^[01]*$} $value]} {
					set validation_ena 1
					return 0
				}
				set value [NumSystem::bin2dec $value]
			}
			o {
				if {[string length $value] > 3 || ![regexp {^[0-7]*$} $value]} {
					set validation_ena 1
					return 0
				}
				set value [expr "0$value"]
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

		# Synchronize the rest of entry boxes related to this SFR
		if {$selected_entry == $addr} {
			if {$type != {d}} {
				$det_dec delete 0 end
				$det_dec insert 0 $value
			}
			if {$type != {b}} {
				set txt [NumSystem::dec2bin $value]
				set len [string length $txt]
				if {$len != 8} {
					set txt "[string repeat 0 [expr {8 - $len}]]$txt"
				}
				$det_bin delete 0 end
				$det_bin insert 0 $txt
			}
			if {$type != {o}} {
				set txt [format %o $value]
				set len [string length $txt]
				if {$len != 3} {
					set txt "[string repeat 0 [expr {3 - $len}]]$txt"
				}
				$det_oct delete 0 end
				$det_oct insert 0 $txt
			}
		}
		set txt [format %X $value]
		if {[string length $txt] == 1} {
			set txt "0$txt"
		}
		if {$from == {p}} {
			$main_frame.ent_${addr} delete 0 end
			$main_frame.ent_${addr} insert 0 $txt
			if {$selected_entry == $addr && $type != {h}} {
				$det_hex delete 0 end
				$det_hex insert 0 $txt
			}
		} elseif {$selected_entry == $addr} {
			$det_hex delete 0 end
			$det_hex insert 0 $txt
		}

		# Done
		set validation_ena 1
		return 1
	}

	## Commint new set special function registers
	 # @return void
	public method sfrmap_commit_new_sfr_set {} {
		if {!$dialog_opened} {return}
		foreach wdg [pack slaves $win] {
			destroy $wdg
		}
		set validation_ena 0
		set selected_entry -1
		create_win_gui
	}

	## Set state of this panel
	 # @parm Bool bool - 0 == Disable; 1 == Enable
	 # @return void
	public method sfrmap_setEnabled {bool} {
		if {!$dialog_opened} {return}
		set enabled $bool
		if {$bool} {
			set bool {normal}
		} else {
			set bool {disabled}
		}
		foreach entry [list $det_hex $det_oct $det_bin $det_dec] {
			$entry configure -state $bool
		}
		foreach addr $defined_sfr {
			$main_frame.ent_${addr} configure -state $bool
		}
	}

	## Clear highlight of changed cells
	 # @return void
	public method sfrmap_clear_hg {} {
		if {!$dialog_opened} {return}

		foreach addr $defined_sfr {
			$main_frame.ent_${addr} configure -style Simulator_WhiteBg.TEntry
		}
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

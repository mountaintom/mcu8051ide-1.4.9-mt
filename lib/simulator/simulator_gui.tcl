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
if { ! [ info exists _SIMULATOR_GUI_TCL ] } {
set _SIMULATOR_GUI_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides graphical front-end for simulator engine (intended to be
# used at the bottom panel). This class is part of class Simulator.
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# This file was modified & fixed by Kostya V. Ivanov <kostya@istcom.spb.ru>
#
# Special thanks to Kostya V. Ivanov !
# --------------------------------------------------------------------------

class Simulator_GUI {
	## COMMON
	public common sim_gui_count	0		;# Counter of instances
	public common name_color	{#0000DD}	;# Color for register name labels (eg. 'SP')
	public common name_nr_color	{#8800DD}	;# Color for not-register name labels (eg. 'Clock')

	public common on_color		{#00CC00}	;# Foreground color for bits in state 1 (for bit maps)
	public common off_color	{#DD0000}	;# Foreground color for bits in state 0 (for bit maps)
	# Font for bit labels (eg. 'EA')
	public common bitfont		[font create					\
		-family {helvetica}						\
		-size [expr {int(-11 * $::font_size_factor)}]			\
		-weight [expr {$::MICROSOFT_WINDOWS ? "normal" : "bold"}]	\
	]
	# Same as $bitfont but underlined
	public common bitfont_under	[font create					\
		-family {helvetica}						\
		-size [expr {int(-11 * $::font_size_factor)}]			\
		-underline 1							\
		-weight [expr {$::MICROSOFT_WINDOWS ? "normal" : "bold"}]	\
	]

	# Color for small labels (eg. 'HEX')
	public common small_color	{#5599BB}
	# Font for small labels (eg. 'OCT')
	public common smallfont $::smallfont
	if {$::MICROSOFT_WINDOWS} {	;# On MS Windows we need some smaller font to fit in
		set smallfont	[font create				\
			-size [expr {int(-9 * $::font_size_factor)}]	\
			-family {helvetica}				\
			-weight normal					\
		]
	}

	public common hcolor		{#FFAA00}	;# Highlight foreground color for entry widgets
	public common hbcolor		{#CCCCCC}	;# Highlight background color for entry widgets

	# Font for other memory entries (eg. PCON)
	public common entry_font [font create						\
		-size [expr {int(-12 * $::font_size_factor)}]			\
		-family $::DEFAULT_FIXED_FONT					\
		-weight [expr {$::MICROSOFT_WINDOWS ? "normal" : "bold"}]	\
	]

	# Postfixes for entry text variables
	public common entry_variables {
		B_char	A_bin	IP	DPH	T0	T1	DPL	PCON	P1_bin
		P3_bin	TMOD	A_hex	PC_dec	B_oct	SCON	B_dec	A_char	TL0
		TL1	DATA	SP	P0	P1	B_bin	P2	P3	PC_hex
		P0_bin	P2_bin	CLOCK	TCON	A_oct	B_hex	SBUFR	SBUFT	R0
		R1	A_dec	R2	TH0	R3	TH1	R4	IE	TIME
		R5	R6	R7	PSW	AUXR1	WDTRST	AUXR	SPDR	WatchDog
		DP1H	DP1L	T2CON	T2MOD	RCAP2L	RCAP2H	TL2	TH2	WDTCON
		EECON	CLKREG	ACSR	IPH	SADDR	SADEN	SPCR	SPSR	WDTPRG
		CKCON	SFR
	}

	## PRIVATE
	private variable eeprom_operation_frame		{}	;# ID of the middle frame
	private variable bottom_right_spec_frame	{}	;# ID of special frame (Bottom -> Right -> Bottom)
	private variable eeprom_progressbar		{}	;# Prograssbar for special function "Writing to EEPROM"
	private variable middle_f			{}	;# ID of the middle frame
	private variable ctrl_f				{}	;# ID of frame with controlls (step, run, etc.)
	private variable right_f			{}	;# ID of the right frame
	private variable disable_sync			0	;# Bool: Disabled synchronization with outside enviromet
	private variable disable_validation		1	;# Bool: Disabled register entries validation
	private variable Rx_validation_ena		1	;# Bool: Enabled validation of entries R0..R7
	private variable bitmap_hex_validation_ena	1	;# Bool: Enabled validation of bitmap register (eg. 'IP')
	private variable sync_AB_in_progress		0	;# Bool: Synchronization of A or B entries in progress
	private variable sync_Px_in_progress		0	;# Bool: Synchronization of P0..03 entries in progress
	private variable sync_PC_in_progress		0	;# Bool: Synchronization of PC entries in progress
	private variable sync_Txx_in_progress		0	;# Bool: Synchronization of TL0/1 TH0/1 entries in progress
	private variable sim_enabled			1	;# Bool: Simulator engaged
	private variable entries			{}	;# List of entry widgets to enable/disable on (dis)engage
	private variable hexeditor			{}	;# Hexadecimal editor for low ram map
	private variable scrollable_frame		{}	;# Widget: Scrollable area (parent for all other widgets)
	private variable horizontal_scrollbar		{}	;# Widget: Horizontal scrollbar for scrollable area
	private variable vertical_scrollbar		{}	;# Widget: Vertical scrollbar for scrollable area
	private variable wtd_clear_button		{}	;# Widget: Watchdog clear button
	private variable watchdog_entry			{}	;# Widget: Watchdog timer entrybox
	private variable wdt_prescaler_entry		{}	;# Widget: Watchdog timer prescaler entrybox
	private variable watchdog_onoff_switch		{}	;# Widget: Label widget of Watchdog ON/OFF switch
	private variable bitmenu			{}	;# Widget: Bit popup menu for
	private variable bit_popup_menu_args		{}	;# Arguments from bit popup menu (see bit_popup_menu_setto)
	private variable sf_registers			{}	;# List of special function registers ({{addr_dec name} ... })
	private variable sf_register_labels		{}	;# List of labels for special function registers
	private variable set_pc_by_line_button		{}	;# Button: Set PC by line number

	# Variables related to object initialization
	private variable sim_gui_gui_initialized 0	;# Bool: GUI created
	private variable parent			;# Parent widget

	## PUBLIC
	public variable Simulator_panel_parent	;# ID of parent GUI component (some frame)
	public variable bit_in_particular_regs			;# Array of Lists: Bit in hexbitmaps, see below

	## PROTECTED
	protected variable obj_idx		;# Object index (for creating unique GUI component descriptors)


	## Object constructor
	constructor {} {
		incr sim_gui_count		;# Increment instances counter
		set obj_idx $sim_gui_count	;# Set object index
	}

	## Object destructor
	destructor {
		# Unallocate entry text variables
		if {$sim_gui_gui_initialized} {
			SimGUI_clean_up
		}
	}

	## Prepare object for creating its GUI
	 # @parm Widget _parent - parent container (some frame)
	 # @return void
	public method PrepareSimulator {_parent} {
		set parent $_parent
		set sim_gui_gui_initialized 0
	}

	## Inform simulator panel than it has became active
	 # @return void
	public method SimulatorTabRaised {} {
		update idletasks
		$scrollable_frame yview scroll 0 units
	}

	## Initialize simulator GUI
	 # @return void
	public method CreateSimulatorGUI {} {
		if {$sim_gui_gui_initialized} {return}
		set sim_gui_gui_initialized 1

		# Set object variables
		set disable_validation		1
		set Rx_validation_ena		1
		set bitmap_hex_validation_ena	1
		set entries			{}
		set sf_registers		{}
		set sf_register_labels		{}

		## Create scrollable area and scrollbars
		set vertical_scrollbar [ttk::scrollbar $parent.scrollbar	\
			-orient vertical					\
			-command "$parent.right.scrollable_frame yview"		\
		]
		pack $vertical_scrollbar -side left -fill y
		set parent [frame $parent.right]
		pack $parent -side right -fill both -expand 1

		set scrollable_frame [ScrollableFrame $parent.scrollable_frame	\
			-xscrollcommand "$this simulator_gui_scroll_set x"	\
			-yscrollcommand "$this simulator_gui_scroll_set y"	\
		]
		set horizontal_scrollbar [ttk::scrollbar	\
			$parent.horizontal_scrollbar		\
			-orient horizontal			\
			-command "$scrollable_frame xview"	\
		]
		pack $scrollable_frame -fill both -side bottom -expand 1
		$scrollable_frame yview scroll 0 units

		set Simulator_panel_parent	[$scrollable_frame getframe]
		set main_top_frame		[frame $Simulator_panel_parent.top]
		set main_bottom_frame		[frame $Simulator_panel_parent.middle]

		pack $main_top_frame -fill x -anchor w
		pack $main_bottom_frame -fill x -anchor w


		# Create bit popup menu
		set bitmenu $Simulator_panel_parent.bit_menu
		menuFactory {
			{command	{Set to 1} {}	7	"bit_popup_menu_setto 1"
				{up0}		"Set this bit to 1"}
			{command	{Set to 0} {}	7	"bit_popup_menu_setto 0"
				{button_cancel}	"Set this bit to 0"}
		} $bitmenu 0 "$this " 0 {} [namespace current]

		#
		# Create left part
		#

		for {set i 0} {$i < 32} {incr i} {
			set ::Simulator_GUI::ENV${obj_idx}_DATA($i) 0
		}
		set cap [lindex [$this cget -procData] 3]
		set hg [expr {$cap / 8}]
		if {[expr {$cap % 8}]} {
			incr hg
		}
		if {!$::MICROSOFT_WINDOWS} {
			set height_in_number_of_rows 9
		} else {
			set height_in_number_of_rows 11
		}
		set hexeditor [HexEditor hexeditor${obj_idx} $main_top_frame.left_frame 8 $hg 2 hex 0 1 $height_in_number_of_rows $cap]
		$hexeditor bindCellValueChanged "$this simulator_hexedit_value_changed"
		$hexeditor bindCellLeave {help_window_hide}
		$hexeditor bindCellEnter "$this create_help_window_ram"
		$hexeditor bindCellMotion {help_window_show}
		pack $main_top_frame.left_frame -side left -anchor nw -fill none -expand 0


		#
		# Create middle part
		#

		# Create frames of middle part
		set middle_f	[frame $main_top_frame.mid_frame]
		set ctrl_f	[frame $middle_f.ctrl_frame]
		set sim_gregs_f	[frame $middle_f.gregs_frame]

		# Pack frames of middle part
		pack $ctrl_f -fill x
		pack $sim_gregs_f
		pack $middle_f -side left -fill both -anchor w -padx 5

		# Create controls icon bar
		iconBarFactory $ctrl_f "X::" [string range $ctrl_f.controls_ 1 end] ::ICONS::16:: {
			{start_stop		"Start/Stop simulator"	{launch}	{__initiate_sim}
				"Load program into the simulator engine, or shutdown the MCU simulator."}
			{separator}
			{reset			"Reset"			{rebuild}	{__reset -}
				"Perform HW reset"}
			{separator}
			{stepback		"Step back"		{undo}		{__stepback}
				"Take MCU back to state before the last instruction"}
			{step			"Step program"		{goto}		{__step}
				"Step by 1 instruction"}
			{quick_step		"Step over"		{goto}		{__stepover}
				"Step by 1 line of code"}
			{animate		"Animate program"	{1rightarrow}	{__animate}
				"Run program and show results after each instruction"}
			{run			"Run program"		{2rightarrow}	{__run}
				"Run program and show results after some time"}
		} [namespace current]
		foreach slave [pack slaves $ctrl_f] {
			pack configure $slave -padx 0
		}

		# Create separator under controls icon bar
		pack [ttk::separator $sim_gregs_f.mid_sep	\
			-orient horizontal		\
		] -fill x -expand 1 -pady 2 -padx 5

		## Create registers: A B
		set sim_gregs_f_AB [frame $sim_gregs_f.gregs_f_AB]
		pack $sim_gregs_f_AB -pady 5

		# Create num. base headers
		set col 1
		foreach base {HEX DEC BIN OCT CHAR} {
			incr col
			grid [label $sim_gregs_f_AB._AB_${base}_l	\
				-text [mc $base]			\
				-font $smallfont			\
				-fg $small_color -pady 0		\
			] -row 0 -column $col
		}

		# registers entries
		set row 0	;# Grid row
		foreach reg {A B} addr {224 240}	\
			stip {{SFR 0xE0: Primary Accumulator} {SFR 0xF0: Secondary Accumulator}} {

			incr row	;# Increment grid row
			set col 1	;# Grid column

			# Register this SFR
			lappend sf_registers [list $addr $reg]
			lappend sf_register_labels $sim_gregs_f_AB._${reg}_l

			# Create register label
			set label [Label $sim_gregs_f_AB._${reg}_l			\
				-text "$reg:" -fg $name_color -pady 0			\
				-helptext [mc "Address: %s" "0x[format {%X} $addr]"]	\
				-font $bitfont						\
			]
			setStatusTip -widget $label -text [mc $stip]
			# Show the label
			grid $label -row $row -column $col

			# Create and show register bitmap
			foreach	base		{hex	dec	bin	oct	char	}	\
				init_val	{00	0	00000000 0	{}	}	\
				width		{2	3	8	3	2	}	\
				next_base	{dec	bin	oct	char	-	}	\
				prev_base	{-	hex	dec	bin	oct	}	\
			{
				incr col	;# Increment column index

				set ::Simulator_GUI::ENV${obj_idx}_${reg}_$base $init_val

				# Register entry
				set entry [ttk::entry $sim_gregs_f_AB._${reg}_$base			\
					-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}_$base	\
					-validatecommand "$this sim_eval_AB $reg $base %P"		\
					-style Simulator.TEntry						\
					-font $entry_font						\
					-width $width							\
					-validate key							\
				]

				setStatusTip -widget $entry -text [mc $stip]
				# Register register entry for disabling/enabling
				add_entry $entry
				# Register register entry for synchronizations
				$this add_sfr_entry $addr $entry
				# Show the entry
				grid $entry -row $row -column $col

				# Set entry bindings
				bind $entry <FocusIn> "$this unmark_entry $addr"
				if {$reg == {A}} {
					bind $entry <Key-Down> "
						$sim_gregs_f_AB._B_$base icursor \[$entry index insert\]
						focus $sim_gregs_f_AB._B_$base
					"
				} else {
					bind $entry <Key-Up> "
						$sim_gregs_f_AB._A_$base icursor \[$entry index insert\]
						focus $sim_gregs_f_AB._A_$base
					"
				}
				if {$next_base != {-}} {
					bind $entry <Key-Right> "Simulator_GUI::sim_entry_right $entry $sim_gregs_f_AB._${reg}_${next_base}"
				}
				if {$prev_base != {-}} {
					bind $entry <Key-Left> "Simulator_GUI::sim_entry_left $entry $sim_gregs_f_AB._${reg}_${prev_base}"
				}
			}
		}

		## Create register: PSW
		set sim_gregs_f_PSW [frame $sim_gregs_f.gregs_f_PSW]
		pack $sim_gregs_f_PSW -pady 2
		set ::Simulator_GUI::ENV${obj_idx}_PSW 0
		create_bitmap_register $sim_gregs_f_PSW 1 PSW {C AC F0 RS1 RS0 OV - P} 0 {
			{Bit address: 0xD7  --  Carry Flag}
			{Bit address: 0xD6  --  Auxiliary Carry Flag}
			{Bit address: 0xD5  --  Flag 0 available to the user for general purpose}
			{Bit address: 0xD4  --  Register Bank selector bit 1}
			{Bit address: 0xD3  --  Register Bank selector bit 0}
			{Bit address: 0xD2  --  Overflow Flag}
			{Bit address: 0xD1  --  Usable as a general purpose flag}
			{Bit address: 0xD0  --  Parity flag}
		} {SFR 0xD0: Program Status Word} {
			{Carry Flag}
			{Auxiliary Carry flag.\n(For BCD operations.)}
			{Flag 0\n(Available to the user for general purposes.)}
			{Register bank Select control bit 1. Set/cleared\nby software to determine working register bank.}
			{Register bank Select control bit 0. Set/cleared\nby software to determine working register bank.}
			{Overflow flag}
			{(reserved)}
			{Parity flag.\nSet/cleared by hardware each instruction cycle to\nindicate and odd/even number of “one” bits in the\naccumulator, i.e., even parity.}
		}
		# Register PSW SFR
		lappend sf_registers [list 208 {PSW}]
		lappend sf_register_labels $Simulator_panel_parent._PSW_l

		## Create registers: R0..R7 (of active bank)
		set sim_gregs_f_Rx [frame $sim_gregs_f.gregs_f_Rx]
		pack $sim_gregs_f_Rx -fill x

		for {set i 7; set col 2} {$i >= 0} {incr i -1; incr col} {
				set stip [mc "Register %s: Located in IDATA, address depends on bits RS0 and RS1 in PSW" $i]

			# Create entry label (register name)
			grid [label $sim_gregs_f_Rx._R${i}_l		\
				-text "R$i" -fg $name_color -pady 0	\
				-font $bitfont				\
			] -row 1 -column $col -sticky we
			setStatusTip -widget $sim_gregs_f_Rx._R${i}_l -text [mc $stip]

			# Create register hexadecimal entry
			set ::Simulator_GUI::ENV${obj_idx}_R$i {00}
			set entry [ttk::entry $sim_gregs_f_Rx._R${i}_e			\
				-style Simulator.TEntry					\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_R$i	\
				-validatecommand "$this entry_Rx_validate %P $i"	\
				-font $entry_font					\
				-validate key						\
				-width 2						\
			]

			# Show the entry
			grid $entry -row 2 -column $col
			# Register register entry for disabling/enabling
			add_entry $entry
			# Set entry default value
			set ::Simulator_GUI::ENV${obj_idx}_R$i {00}
			# Register register entry for synchronizations
			$this add_sfr_entry R$i $entry

			# Set entry bindings
			bind $entry <Motion>	{help_window_show %X %Y}
			bind $entry <Leave>	{help_window_hide}
			bind $entry <Enter>	"$this create_help_window_Rx $i; Sbar -freeze {$stip}"
			bind $entry <FocusIn>	"$this unmark_entry R$i"
			if {$i != 0} {
				bind $entry <Key-Right>	\
					"Simulator_GUI::sim_entry_right $entry $sim_gregs_f_Rx._R[expr {$i-1}]_e"
			}
			if {$i != {7}} {
				bind $entry <Key-Left>	\
					"Simulator_GUI::sim_entry_left $entry $sim_gregs_f_Rx._R[expr {$i+1}]_e"
			}

			grid columnconfigure $sim_gregs_f_Rx $col -weight 1
		}

		#
		# Create right part
		#

		# Create and pack frame
		set right_f [frame $main_top_frame.right_frame]
		pack $right_f -side left -fill both -anchor nw

		## FRAME 0 (timers + interrupt)
		set frame0 [frame $right_f.frame0]
		pack $frame0 -side left -anchor nw

		# Create timers frame (hexadecimal entries and bitmaps)
		set timers_frame [labelframe $frame0.timers_f	\
			-pady 2 -padx 2				\
			-labelwidget [label $frame0.timers_lbl -text [mc "TIMERS 0 & 1"] -font $smallfont -pady 0]]
		pack $timers_frame -anchor nw -fill x -padx 5

		# Create frame for hexadecimal entries: TH1 TL1 TH0 TL0
		set timers_values_f [frame $timers_frame.timers_values_f]
		pack $timers_values_f -anchor nw -fill x

		# Create hexadecimal entries for registers: TH1 TL1 TH0 TL0
		set col 0	;# Grid column
		foreach reg {TH1 TL1 TH0 TL0} addr {141 139 140 138}	\
			stip {
				{SFR 0x8D: 2nd part of 16-bit counting register for timer 1}
				{SFR 0x8B: 1st part of 16-bit counting register for timer 1}
				{SFR 0x8C: 2nd part of 16-bit counting register for timer 0}
				{SFR 0x8A: 1nd part of 16-bit counting register for timer 0}
		} {
			incr col	;# Increment grid column

			# Register this SFR
			lappend sf_registers [list $addr $reg]
			lappend sf_register_labels $timers_values_f._${reg}_l

			# Create register name label
			grid [label $timers_values_f._${reg}_l	\
				-text $reg -fg $small_color	\
				-font $smallfont -pady 0	\
			] -row 1 -column $col

			# Create register hexadecimal entry
			set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
			set entry [ttk::entry $timers_values_f._Txx${col}_e		\
				-style Simulator.TEntry					\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}	\
				-validatecommand "$this validate_Txx $reg %P"		\
				-font $entry_font					\
				-validate key						\
				-width 2						\
			]

			# Show and register created memory cell
			grid $entry -row 2 -column $col
			add_entry $entry
			$this add_sfr_entry $addr $entry

			# Set entry event bindings
			bind $entry <Motion>	{help_window_show %X %Y}
			bind $entry <Leave>	{help_window_hide; Sbar {}}
			bind $entry <FocusIn>	"$this unmark_entry $addr"
			bind $entry <Enter>	"$this create_help_window_ram $reg; Sbar -freeze {[mc $stip]}"
			bind $entry <Key-Right>	\
				"Simulator_GUI::sim_entry_right $entry $timers_values_f._Txx[expr {$col+1}]_e"
			if {$col != {1}} {
				bind $entry <Key-Left>	\
					"Simulator_GUI::sim_entry_left $entry $timers_values_f._Txx[expr {$col-1}]_e"
			}
		}

		# Create decimal entries for timers
		foreach reg {T1 T0} addresses {{141 139} {140 138}}	\
			stip {
				{SFR 0x8D..0x8B: 16-bit counting register for timer 1}
				{SFR 0x8C..0x8A: 16-bit counting register for timer 0}
		} {
			incr col	;# Increment grid column

			# Create register name label
			grid [label $timers_values_f._${reg}_l	\
				-text $reg -fg $small_color	\
				-font $smallfont -pady 0	\
			] -row 1 -column $col

			# Create register hexadecimal entry
			set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
			set entry [ttk::entry $timers_values_f._Txx${col}_e		\
				-style Simulator.TEntry					\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}	\
				-width 5						\
				-validate key						\
				-validatecommand "$this validate_Txx $reg %P"		\
				-font $entry_font					\
			]
			setStatusTip -widget $entry -text [mc $stip]

			# Show and register created memory cell
			grid $entry -row 2 -column $col
			add_entry $entry

			# Set entry event bindings
			bind $entry <Key-Right>	\
				"Simulator_GUI::sim_entry_right $entry $timers_values_f._Txx[expr {$col+1}]_e"
			bind $entry <Key-Left>	\
				"Simulator_GUI::sim_entry_left $entry $timers_values_f._Txx[expr {$col-1}]_e"
			foreach addr $addresses {
				$this add_sfr_entry $addr $entry
				bind $entry <FocusIn> "$this unmark_entry $addr"
			}
		}

		# Create frame for registers: TCON TMOD (bitmaps)
		set timers_frame_reg [frame $timers_frame.timers_reg_f]
		pack $timers_frame_reg -anchor nw
		# Create TCON and TMOD bitmaps
		create_bitmap_register $timers_frame_reg 1 TCON {TF1 TR1 TF0 TR0 IE1 IT1 IE0 IT0} 1 {
			{Bit address: 0x8F  --  Timer 1 overflow flag}
			{Bit address: 0x8E  --  Timer 1 run control bit}
			{Bit address: 0x8D  --  Timer 0 overflow flag}
			{Bit address: 0x8C  --  Timer 0 run control bit}
			{Bit address: 0x8B  --  External Interrupt 1 edge flag}
			{Bit address: 0x8A  --  Interrupt 1 type control bit}
			{Bit address: 0x89  --  External Interrupt 0 edge flag}
			{Bit address: 0x88  --  Interrupt 0 type control bit}
		} {SFR 0x88: Timer/Counter control register} {
			{Timer 1 Overflow Flag\nCleared by hardware when processor vectors to interrupt routine.\nSet by hardware on timer/counter overflow, when the timer 1 register overflows.}
			{Timer 1 Run Control Bit\nClear to turn off timer/counter 1.\nSet to turn on timer/counter 1.}
			{Timer 0 Overflow Flag\nCleared by hardware when processor vectors to interrupt routine.\nSet by hardware on timer/counter overflow, when the timer 0 register overflows.}
			{Timer 0 Run Control Bit\nClear to turn off timer/counter 0.\nSet to turn on timer/counter 0.}
			{Interrupt 1 Edge Flag\nCleared by hardware when interrupt is processed if edge-triggered (see IT1).\nSet by hardware when external interrupt is detected on INT1# pin.}
			{Interrupt 1 Type Control Bit\nClear to select low level active (level triggered) for external interrupt 1 (INT1#).\nSet to select falling edge active (edge triggered) for external interrupt 1.}
			{Interrupt 0 Edge Flag\nCleared by hardware when interrupt is processed if edge-triggered (see IT0).\nSet by hardware when external interrupt is detected on INT0# pin.}
			{Interrupt 0 Type Control Bit\nClear to select low level active (level triggered) for external interrupt 0 (INT0#).\nSet to select falling edge active (edge triggered) for external interrupt 0.}
		}
		create_bitmap_register $timers_frame_reg 2 TMOD {G1 CT1 M11 M01 G0 CT0 M10 M00} 1 {
			{Timer 1 Gating Control Bit}
			{Timer 1 Counter/Timer Select Bit}
			{Timer 1 Mode Select Bit}
			{Timer 1 Mode Select Bit}
			{Timer 0 Gating Control Bit}
			{Timer 0 Counter/Timer Select Bit}
			{Timer 0 Mode Select Bit}
			{Timer 0 Mode Select Bit}
		} {SFR 0x89: Timer/Counter mode control register} {
			{Timer 1 Gating Control Bit\nClear to enable timer 1 whenever the TR1 bit is set.\nSet to enable timer 1 only while the INT1# pin is high and TR1 bit is set.}
			{Timer 1 Counter/Timer Select Bit\nClear for timer operation: timer 1 counts the divided-down system clock.\nSet for Counter operation: timer 1 counts negative transitions on external pin T1.}
			{Timer 1 Mode Select Bits\nM11\tM01\tOperating mode\n 0\t 0\tMode 0: 8-bit timer/counter (TH1) with 5-bit prescaler (TL1).\n 0\t 1\tMode 1: 16-bit timer/counter.\n 1\t 0\tMode 2: 8-bit auto-reload timer/counter (TL1). Reloaded from TH1 at overflow.\n 1\t 1\tMode 3: timer 1 halted. Retains count.}
			{Timer 1 Mode Select Bits\nM11\tM01\tOperating mode\n 0\t 0\tMode 0: 8-bit timer/counter (TH1) with 5-bit prescaler (TL1).\n 0\t 1\tMode 1: 16-bit timer/counter.\n 1\t 0\tMode 2: 8-bit auto-reload timer/counter (TL1). Reloaded from TH1 at overflow.\n 1\t 1\tMode 3: timer 1 halted. Retains count.}
			{Timer 0 Gating Control Bit\nClear to enable timer 0 whenever the TR0 bit is set.\nSet to enable timer/counter 0 only while the INT0# pin is high and the TR0 bit is set.}
			{Timer 0 Counter/Timer Select Bit\nClear for timer operation: timer 0 counts the divided-down system clock.\nSet for counter operation: timer 0 counts negative transitions on external pin T0.}
			{Timer 0 Mode Select Bit\nM1\tM0\tOperating mode\n 0\t 0\tMode 0: 8-bit timer/counter (TH0) with 5-bit prescaler (TL0).\n 0\t 1\tMode 1: 16-bit timer/counter.\n 1\t 0\tMode 2: 8-bit auto-reload timer/counter (TL0). Reloaded from TH0 at overflow.\n 1\t 1\tMode 3: TL0 is an 8-bit timer/counter.\nTH0 is an 8-bit timer using timer 1’s TR0 and TF0 bits.}
			{Timer 0 Mode Select Bit\nM10\tM00\tOperating mode\n 0\t 0\tMode 0: 8-bit timer/counter (TH0) with 5-bit prescaler (TL0).\n 0\t 1\tMode 1: 16-bit timer/counter.\n 1\t 0\tMode 2: 8-bit auto-reload timer/counter (TL0). Reloaded from TH0 at overflow.\n 1\t 1\tMode 3: TL0 is an 8-bit timer/counter.\nTH0 is an 8-bit timer using timer 1’s TR0 and TF0 bits.}
		}

		# Create hexadecimal entries for registers: TCON TMOD
		foreach reg	{TCON TMOD}	\
			addr	{136 137}	\
			bits	{{TF1 TR1 TF0 TR0 IE1 IT1 IE0 IT0} {G1 CT1 M11 M01 G0 CT0 M10 M00}}	\
			stip	{
				{SFR 0x88: Timer/Counter control register}
				{SFR 0x89: Timer/Counter mode control register}
		} {
			incr col	;# Increment grid column

			# Register this SFR
			lappend sf_registers [list $addr $reg]
			lappend sf_register_labels $Simulator_panel_parent._${reg}_l

			# Create register name label
			grid [label $timers_values_f._${reg}_hex_l	\
				-text $reg -fg $small_color		\
				-font $smallfont -pady 0		\
			] -row 1 -column $col

			# Create register hexadecimal entry
			set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
			set entry [ttk::entry $timers_values_f._Txx${col}_e				\
				-style Simulator.TEntry							\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}			\
				-width 2								\
				-validate key								\
				-validatecommand "$this validate_hex_bitmap_reg %P $reg"		\
				-font $entry_font							\
			]
			set bit_in_particular_regs($reg) $bits

			# Show and register created memory cell
			grid $entry -row 2 -column $col
			$this add_sfr_entry $addr $entry
			add_entry $entry

			# Set entry event bindings
			bind $entry <Motion>	{help_window_show %X %Y}
			bind $entry <Leave>	{help_window_hide; Sbar {}}
			bind $entry <FocusIn>	"$this unmark_entry $addr"
			bind $entry <Enter>	"$this create_help_window_ram $reg; Sbar -freeze {[mc $stip]}"
			if {$reg != {TMOD}} {
				bind $entry <Key-Right>		\
					"Simulator_GUI::sim_entry_right $entry $timers_values_f._Txx[expr {$col+1}]_e"
			}
			bind $entry <Key-Left>	\
				"Simulator_GUI::sim_entry_left $entry $timers_values_f._Txx[expr {$col-1}]_e"
		}

		# Create frame for interrupt control registers (IE and IP)
		set interrupt_frame [labelframe $frame0.interrupt_f	\
			-pady 2 -padx 2					\
			-labelwidget [label $frame0.int_lbl -text [mc "INTERRUPTS"] -font $smallfont -pady 0]]
		pack $interrupt_frame -anchor nw -fill x -pady 5 -padx 5

		# Create IE, IP bitmaps
		if {[$this get_feature_available t2]} {
			set et2 {ET2}
			set pt2 {PT2}
			set et2_stip {Bit address: 0xAD  --  Enable or disable the Timer 2 overflow interrupt}
			set pt2_stip {Bit address: 0xBD  --  Defines the Timer 2 interrupt priority level}
			set et2_ttip {Timer 2 interrupt enable bit.}
			set pt2_ttip {Timer 2 interrupt priority bit}
		} else {
			set et2 {-}
			set pt2 {-}
			set et2_stip {Bit address: 0xAD  --  Not implemented}
			set pt2_stip {Bit address: 0xBD  --  Not implemented}
			set et2_ttip {Not implemented}
			set pt2_ttip {Not implemented}
		}
		if {[$this get_feature_available uart]} {
			set es {ES}
			set ps {PS}
			set es_stip {Bit address: 0xAC  --  Enable or disable the serial port interrupt}
			set ps_stip {Bit address: 0xBC  --  Defines the Serial Port interrupt priority level}
			set es_ttip {Serial Port interrupt enable bit}
			set ps_ttip {Serial Port interrupt priority bit}
		} else {
			set es {-}
			set ps {-}
			set es_stip {Bit address: 0xAD  --  Not implemented}
			set ps_stip {Bit address: 0xBC  --  Not implemented}
			set es_ttip {Not implemented}
			set ps_ttip {Not implemented}
		}
		if {[$this get_feature_available acomparator]} {
			set ec {EC}
			set pc {PC}
			set ec_stip {Bit address: 0xAE  --  Enable or disable the comparator interrupt}
			set pc_stip {Bit address: 0xBE  --  Defines the comparator interrupt priority level}
			set ec_ttip {EC Comparator Interrupt Enable bit}
			set pc_ttip {Comparator Interrupt Priority bit}
		} else {
			set ec {-}
			set pc {-}
			set ec_stip {Bit address: 0xAE  --  Not implemented}
			set pc_stip {Bit address: 0xBE  --  Not implemented}
			set ec_ttip {Not implemented}
			set pc_ttip {Not implemented}
		}
		create_bitmap_register $interrupt_frame 1 IE [list EA $ec $et2 $es ET1 EX1 ET0 EX0] 1 [list \
			{Bit address: 0xAF  --  Disables all interrupts}				\
			$ec_stip									\
			$et2_stip									\
			$es_stip									\
			{Bit address: 0xAB  --  Enable or disable the Timer 1 overflow interrupt}	\
			{Bit address: 0xAA  --  Enable or disable External Interrupt 1}			\
			{Bit address: 0xA9  --  Enable or disable the Timer 0 overflow interrupt}	\
			{Bit address: 0xA8  --  Enable or disable External Interrupt 0}			\
		] {SFR 0xA8: Interrupt enable register} [list \
			{Global disable bit. If EA = O, all Interrupts are disabled. If EA = 1, each interrupt can be\nindividually enabled or disabled by setting or clearing its enable bit.} \
			$ec_ttip \
			$et2_ttip \
			$es_ttip \
			{Timer 1 interrupt enable bit.} \
			{External interrupt 1 enable bit.} \
			{Timer 0 interrupt enable bit.} \
			{External interrupt O enable bit.} \
		]
		create_bitmap_register $interrupt_frame 2 IP [list - $pc $pt2 $ps PT1 PX1 PT0 PX0] 1 [list \
			{Bit address: 0xBF  --  Not implemented}					\
			$pc_stip									\
			$pt2_stip									\
			$ps_stip									\
			{Bit address: 0xBB  --  Defines the Timer 1 interrupt priority level}		\
			{Bit address: 0xBA  --  Defines External Interrupt 1 priority level}		\
			{Bit address: 0xB9  --  Defines the Timer 0 interrupt priority level}		\
			{Bit address: 0xB8  --  Defines the External Interrupt 0 priority level}	\
		] {SFR 0xB8: Interrupt priority register} [list \
			{Not implemented} \
			$pc_ttip \
			$pt2_ttip \
			$ps_ttip \
			{Timer 1 interrupt priority bit} \
			{External interrupt 1 priority bit} \
			{Timer 0 interrupt priority bit} \
			{External interrupt 0 priority bit} \
		]

		# Create BITMAP//HEX vertical separator
		grid [ttk::separator $interrupt_frame._IE_IP_sep	\
			-orient vertical				\
		]	\
			-row 1		\
			-column 11	\
			-rowspan 2	\
			-sticky ns	\
			-padx 5

		# Create IE, IP hexadecimal entries
		set row 0	;# Grid row
		foreach reg {IE IP}	\
			addr {168 184}	\
			bits [list						\
				[list EA $ec $et2 $es ET1 EX1 ET0 EX0]		\
				[list - $pc $pt2 $ps PT1 PX1 PT0 PX0]		\
			]	\
			stip {
				{SFR 0xA8: Interrupt enable register}
				{SFR 0xB8: Interrupt priority register}
		} {
			incr row	;# Increment grid row

			# Create register name label
			grid [label $interrupt_frame._${reg}_hex_l			\
				-padx 0 -text {HEX} -fg $small_color -font $smallfont	\
			] -row $row -column 12

			# Register this SFR
			lappend sf_registers [list $addr $reg]
			lappend sf_register_labels $Simulator_panel_parent._${reg}_l

			# Create register hexadecimal entry
			set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
			set entry [ttk::entry $interrupt_frame._${reg}_e				\
				-style Simulator.TEntry							\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}			\
				-width 2								\
				-validate key								\
				-validatecommand "$this validate_hex_bitmap_reg %P $reg"		\
				-font $entry_font							\
			]
			set bit_in_particular_regs($reg) $bits

			# Show and register created memory cell
			grid $entry -row $row -column 13 -padx 5
			add_entry $entry
			$this add_sfr_entry $addr $entry

			# Set entry event bindings
			bind $entry <Motion>	{help_window_show %X %Y}
			bind $entry <Leave>	{help_window_hide; Sbar {}}
			bind $entry <FocusIn>	"$this unmark_entry $addr"
			bind $entry <Enter>	"$this create_help_window_ram $reg; Sbar -freeze {[mc $stip]}"
		}

		# Finalize entry event bindings for IE and IP
		bind $interrupt_frame._IP_e <Key-Up> "
			focus $interrupt_frame._IE_e
			$interrupt_frame._IE_e icursor \[$interrupt_frame._IP_e index insert\]"
		bind $interrupt_frame._IE_e <Key-Down> "
			focus $interrupt_frame._IP_e
			$interrupt_frame._IP_e icursor \[$interrupt_frame._IE_e index insert\]"

		## FRAME 1
		set frame1 [frame $right_f.frame1]
		pack $frame1 -side left -anchor nw -padx 2

		# FRAME 1 - TOP
		set frame1_top [frame $frame1.frame1_top]
		pack $frame1_top -anchor nw

		# FRAME 1 - TOP - LEFT
		set frame1_top_left [frame $frame1_top.frame1_top_left]
		pack $frame1_top_left -anchor nw -side left

		# FRAME 1 - TOP - RIGHT
		set frame1_top_right [frame $frame1_top.frame1_top_right]
		pack $frame1_top_right -anchor nw -side right -padx 5

		# FRAME 1 - BOTTOM
		set frame1_bottom [frame $frame1.frame1_bottom]
		pack $frame1_bottom -anchor nw

		## Create entries for registers P0..P4
		# Create num. base headers
		set col 1
		foreach txt {BIN HEX} {
			incr col
			grid [label $frame1_top_left._${txt}_l	\
				-text $txt -fg $small_color	\
				-font $smallfont -pady 0	\
			] -row 0 -column $col
		}
		# Create register binary and hexadecimal entries (P0..P3)
		set row		0	;# Grid row
		set regs	{}	;# Port registers
		set addrs	{}	;# Register addresses
		set stips	{}	;# Status bar tips
		foreach reg {P0 P1 P2 P3 P4} addr {128 144 160 176 192} stip {0 1 2 3 4} {
			if {[$this get_feature_available [string tolower $reg]]} {
				lappend regs $reg
				lappend addrs $addr
				lappend stips [mc "SFR 0x%s: Latch of port %s" [symb_name_to_hex_addr $reg] $stip]
			}
		}
		foreach reg $regs addr $addrs stip $stips {
			incr row	;# Increment grid row

			# Register this SFR
			lappend sf_registers [list $addr $reg]
			lappend sf_register_labels $frame1_top_left._${reg}_l

			# Create register name labels
			grid [label $frame1_top_left._${reg}_l		\
				-text "$reg:" -fg $name_color -pady 0	\
				-font $bitfont				\
			] -row $row -column 1
			setStatusTip -widget $frame1_top_left._${reg}_l -text [mc $stip]

			# Create binary entry
			set ::Simulator_GUI::ENV${obj_idx}_${reg}_bin {11111111}
			set entry0 [ttk::entry $frame1_top_left._Pxx${row}_bin_e		\
				-style Simulator.TEntry						\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}_bin		\
				-width 8							\
				-validate key							\
				-validatecommand "$this sim_eval_Px $reg bin %P"		\
				-font $entry_font						\
			]

			# Show and register created memory cell
			grid $entry0 -row $row -column 2
			add_entry $entry0
			$this add_sfr_entry $addr $entry0

			# Set entry event bindings
			bind $entry0 <FocusIn> "$this unmark_entry $addr"
			setStatusTip -widget $entry0 -text [mc $stip]
			if {$row != 1} {
				bind $entry0 <Key-Up> "
					$frame1_top_left._Pxx[expr {$row-1}]_bin_e icursor \[$entry0 index insert\]
					focus $frame1_top_left._Pxx[expr {$row-1}]_bin_e"
			}
			if {$row != 4} {
				bind $entry0 <Key-Down> "
					$frame1_top_left._Pxx[expr {$row+1}]_bin_e icursor \[$entry0 index insert\]
					focus $frame1_top_left._Pxx[expr {$row+1}]_bin_e"
			}

			# Create hexadecimal entry
			set ::Simulator_GUI::ENV${obj_idx}_${reg} {FF}
			set entry1 [ttk::entry $frame1_top_left._Pxx${row}_hex_e	\
				-style Simulator.TEntry					\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}	\
				-width 2						\
				-validate key						\
				-validatecommand "$this sim_eval_Px $reg hex %P"	\
				-font $entry_font					\
			]

			# Show and register created memory cell
			grid $entry1 -row $row -column 3
			add_entry $entry1
			$this add_sfr_entry $addr $entry1

			# Set entry event bindings
			bind $entry1 <Motion>	{help_window_show %X %Y}
			bind $entry1 <Leave>	{Sbar {}; help_window_hide}
			bind $entry1 <FocusIn>	"$this unmark_entry $addr"
			bind $entry1 <Enter>	"$this create_help_window_ram $reg; Sbar -freeze {$stip}"
			if {$row != 1} {
				bind $entry1 <Key-Up> "
					$frame1_top_left._Pxx[expr {$row-1}]_hex_e icursor \[$entry1 index insert\]
					focus $frame1_top_left._Pxx[expr {$row-1}]_hex_e"
			}
			if {$row != 4} {
				bind $entry1 <Key-Down> "
					$frame1_top_left._Pxx[expr {$row+1}]_hex_e icursor \[$entry1 index insert\]
					focus $frame1_top_left._Pxx[expr {$row+1}]_hex_e"
			}
			bind $entry0 <Key-Right>	\
				"Simulator_GUI::sim_entry_right $entry0 $entry1"
			bind $entry1 <Key-Left>		\
				"Simulator_GUI::sim_entry_left $entry1 $entry0"
		}

		### Create bottom frame widgets (PCON SCON)
		## Create register bitmaps
		 # - PCON
		if {[$this get_feature_available pof]} {
			set POF {POF}
			set pof_statusTip {Power Off Flag}
			set pof_tooltip {Power-Off Flag\nCleared to recognize next reset type.\nSet by hardware when VCC rises from 0 to its nominal voltage. Can also be set by software.}
		} else {
			set POF {-}
			set pof_statusTip {Not implemented}
			set pof_tooltip {Not implemented}
		}
		if {[$this get_feature_available gf1]} {
			set GF1 {GF1}
			set gf1_statusTip {General purpose flag bit}
			set gf1_tooltip {General purpose Flag\nCleared by user for general purpose usage.\nSet by user for general purpose usage.}
		} else {
			set GF1 {-}
			set gf1_statusTip {Not implemented}
			set gf1_tooltip {Not implemented}
		}
		if {[$this get_feature_available gf0]} {
			set GF0 {GF0}
			set gf0_statusTip {General purpose flag bit}
			set gf0_tooltip {General purpose Flag\nCleared by user for general purpose usage.\nSet by user for general purpose usage.}
		} else {
			set GF0 {-}
			set gf0_statusTip {Not implemented}
			set gf0_tooltip {Not implemented}
		}
		if {[$this get_feature_available pd]} {
			set PD {PD}
			set pd_statusTip {Power down bit}
			set pd_tooltip {Power-Down mode bit\nCleared by hardware when reset occurs.\nSet to enter power-down mode.}
		} else {
			set PD {-}
			set pd_statusTip {Not implemented}
			set pd_tooltip {Not implemented}
		}
		if {[$this get_feature_available idl]} {
			set IDL {IDL}
			set idl_statusTip {Idle mode bit}
			set idl_tooltip {Idle mode bit\nCleared by hardware when interrupt or reset occurs.\nSet to enter idle mode.}
		} else {
			set IDL {-}
			set idl_statusTip {Not implemented}
			set idl_tooltip {Not implemented}
		}
		if {[$this get_feature_available uart]} {
			set SMOD1 {SMOD}
			set smod1_statusTip {Double baud rate bit}
			set smod1_tooltip {Serial port Mode bit 1 for UART\nSet to select double baud rate in mode 1, 2 or 3.}
			if {[$this get_feature_available smod0]} {
				append SMOD1 {1}
				set SMOD0 {SMOD0}
				set smod0_statusTip {Frame Error Select}
				set smod0_tooltip {Frame Error Select. When SMOD0 = 0, SCON.7 is SM0. When SMOD0 = 1, SCON.7 is FE.\nNote that FE will be set after a frame error\nregardless of the state of SMOD0.}
			} else {
				set SMOD0 {-}
				set smod0_statusTip {Not implemented}
				set smod0_tooltip {Not implemented}
			}
		} else {
			set SMOD1 {-}
			set smod1_statusTip {Not implemented}
			set smod1_tooltip {Not implemented}
			set SMOD0 {-}
			set smod0_statusTip {Not implemented}
			set smod0_tooltip {Not implemented}
		}
		if {[$this get_feature_available pwm]} {
			set PWMEN {PWMEN}
			set pwmen_stip {Pulse Width Modulation Enable}
			set pwmen_ttip {Pulse Width Modulation Enable. When PWMEN = 1, Timer 0 and Timer 1 are\nconfigured as an 8-bit PWM counter with 8-bit auto-reload prescaler.\nThe PWM outputs on T1 (P3.5).}
		} else {
			set PWMEN {-}
			set pwmen_stip {Not implemented}
			set pwmen_ttip {Not implemented}
		}
		create_bitmap_register $frame1_bottom 1 PCON [list $SMOD1 $SMOD0 $PWMEN $POF $GF1 $GF0 $PD $IDL] 1 [list	\
			$smod1_statusTip	\
			$smod0_statusTip	\
			$pwmen_stip		\
			$pof_statusTip		\
			$gf1_statusTip		\
			$gf0_statusTip		\
			$pd_statusTip		\
			$idl_statusTip		\
		] {SFR 0x87: Power control register} [list \
			$smod1_tooltip		\
			$smod0_tooltip		\
			$pwmen_ttip		\
			$pof_tooltip		\
			$gf1_tooltip		\
			$gf0_tooltip		\
			$pd_tooltip		\
			$idl_tooltip		\
		]
		 # - SCON
		if {[$this get_feature_available uart]} {
			create_bitmap_register $frame1_bottom 2 SCON {SM0 SM1 SM2 REN TB8 RB8 TI RI} 1 {
				{Bit address: 0x9F  --  Serial Port mode specifier}
				{Bit address: 0x9E  --  Serial Port mode specifier}
				{Bit address: 0x9D  --  Enables the multiprocessor communication feature}
				{Bit address: 0x9C  --  Enable/Disable reception}
				{Bit address: 0x9B  --  The 9th bit that will be transmitted in modes 2 and 3}
				{Bit address: 0x9A  --  Receiver Bit 8}
				{Bit address: 0x99  --  Transmit interrupt flag}
				{Bit address: 0x98  --  Receive interrupt flag}
			} {SFR 0x98: Serial port control register} {
				{Serial port Mode bit 0\nRefer to SM1 for serial port mode selection.\nSMOD0 must be cleared to enable access to the SM0 bit}
				{Serial port Mode bit 1\nSM0\tSM1\tMode\tDescription\t\tBaud Rate\n0\t0\t0\tShift Register\tFCPU PERIPH/6\n0\t1\t1\t8-bit UART\tVariable\n1\t0\t2\t9-bit UART\tFCPU PERIPH /32 or /16\n1\t1\t3\t9-bit UART\tVariable}
				{Serial port Mode 2 bit / Multiprocessor Communication Enable bit\nClear to disable multiprocessor communication feature.\nSet to enable multiprocessor communication feature in mode 2 and 3, and eventually mode 1. This bit should be\ncleared in mode 0}
				{Reception Enable bit\nClear to disable serial reception.\nSet to enable serial reception.}
				{Transmitter Bit 8 / Ninth bit to transmit in modes 2 and 3.\no transmit a logic 0 in the 9th bit.\nSet to transmit a logic 1 in the 9th bit.}
				{Receiver Bit 8 / Ninth bit received in modes 2 and 3\nCleared by hardware if 9th bit received is a logic 0.\nSet by hardware if 9th bit received is a logic 1.\nIn mode 1, if SM2 = 0, RB8 is the received stop bit. In mode 0 RB8 is not used.}
				{Transmit Interrupt flag\nClear to acknowledge interrupt.\nSet by hardware at the end of the 8th bit time in mode 0 or at the beginning of the stop bit in the other modes.}
				{Receive Interrupt flag\nClear to acknowledge interrupt.\nSet by hardware at the end of the 8th bit time in mode 0, see Figure 2-26. and Figure 2-27. in the other modes.}
			}

			# Create bit FE (Frame error)
			if {[$this get_feature_available smod0]} {
				set FE_frm [frame $frame1_bottom._SCON_SM0_FE_frm]

				grid forget $Simulator_panel_parent._SCON_SM0
				grid $FE_frm -row 2 -column 2

				$Simulator_panel_parent._SCON_SM0 configure -padx 0 -bd 0
				bind $Simulator_panel_parent._SCON_SM0 <Button-1> "$this sim_invert SM0 0 SCON 1"
				bind $Simulator_panel_parent._SCON_SM0 <ButtonRelease-3> "$this bit_popup_menu SM0 0 SCON 1 %X %Y"

				set label [label $Simulator_panel_parent._SCON_FE	\
					-text {FE} -fg $off_color -cursor hand2		\
					-bd 0 -font $bitfont -pady 0 -padx 0		\
				]
				pack $label -in $FE_frm -side left
				pack [label $Simulator_panel_parent._SCON_SM0_FE_slash_label	\
					-text {|} -font $bitfont -padx 0 -bd 0			\
				] -in $FE_frm -side left
				pack $Simulator_panel_parent._SCON_SM0 -in $FE_frm -side left


				setStatusTip -widget $label -text [mc "Bit address: 0x9F  --  Framing Error bit"]
				bind $label <Enter> {+%W configure -font $::Simulator_GUI::bitfont_under}
				bind $label <Leave> {+%W configure -font $::Simulator_GUI::bitfont}
				DynamicHelp::add $label -text [subst {Clear to reset the error state, not cleared by a valid stop bit.\nSet by hardware when an invalid stop bit is detected.\nSMOD0 must be set to enable access to the FE bit}]

				# Register bit label
				bind $label <Button-1> "$this sim_invert FE 0 SCON 1"
				bind $label <ButtonRelease-3> "$this bit_popup_menu FE 0 SCON 1 %X %Y"
				set ::Simulator_GUI::ENV${obj_idx}_SFR(FE) 0
			}
		}

		# Create BITMAP//HEX vertical separator
		grid [ttk::separator $frame1_bottom._PCON_SCON_sep	\
			-orient vertical				\
		]		\
			-row 1			\
			-column 11		\
			-rowspan 2		\
			-sticky ns

		# Create hexadecimal entries for registers: PCON SCON
		set row 0	;# Grid row
		foreach reg {PCON SCON}	\
			addr {135 152}	\
			bits [list [list $SMOD1 $SMOD0 $PWMEN $POF $GF1 $GF0 $PD $IDL] {- SM1 SM2 REN TB8 RB8 TI RI}] \
			stip {
				{SFR 0x87: Power control register}
				{SFR 0x98: Serial port control register}
		} {
			incr row	;# Increment grid row
			if {$reg == {SCON} && ![$this get_feature_available uart]} {
				continue
			}

			# Register this SFR
			lappend sf_registers [list $addr $reg]
			lappend sf_register_labels $Simulator_panel_parent._${reg}_l

			# Create register name labels
			grid [label $frame1_bottom._${reg}_hex_l		\
				-text {H:} -fg $small_color -font $smallfont	\
			] -row $row -column 12
			setStatusTip -widget $frame1_bottom._${reg}_hex_l -text [mc $stip]

			# Create register hexadecimal entry
			set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
			set entry [ttk::entry $frame1_bottom._${reg}_e					\
				-style Simulator.TEntry							\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}			\
				-width 2								\
				-validate key								\
				-validatecommand "$this validate_hex_bitmap_reg %P $reg"		\
				-font $entry_font							\
			]
			set bit_in_particular_regs($reg) $bits

			# Show and register created memory cell
			grid $entry -row $row -column 13
			add_entry $entry
			$this add_sfr_entry $addr $entry

			# Set entry event bindings
			bind $entry <Motion>	{help_window_show %X %Y}
			bind $entry <Leave>	{help_window_hide; Sbar {}}
			bind $entry <FocusIn>	"$this unmark_entry $addr"
			bind $entry <Enter>	"$this create_help_window_ram $reg; Sbar -freeze {[mc $stip]}"
		}

		# Finalize entry event bindings for SCON and PCON
		bind $frame1_bottom._SCON_e <Key-Up> "
			focus $frame1_bottom._PCON_e
			$frame1_bottom._PCON_e icursor \[$frame1_bottom._SCON_e index insert\]"
		bind $frame1_bottom._PCON_e <Key-Down> "
			focus $frame1_bottom._SCON_e
			$frame1_bottom._SCON_e icursor \[$frame1_bottom._PCON_e index insert\]"


		# FRAME 1 - TOP - RIGHT - 0 (DTPR SP // Clock | SBUF // PC)
		set frame1_top_right_0 [frame $frame1_top_right.frame1_top_right_0]
		pack $frame1_top_right_0 -anchor nw

		# Create label "DPTR:"
		if {
			[$this get_feature_available {ddp}]
				&&
			![$this get_feature_available {hddptr}]
		} then {
			set text {DPTR0:}
		} else {
			set text {DPTR:}
		}
		grid [label $frame1_top_right_0._DPTR_l		\
			-text $text -fg $name_color -pady 0	\
			-font $bitfont				\
		] -row 2 -column 0

		# Create label "Hex"
		grid [label $frame1_top_right_0._SP_SBUF_l	\
			-text {HEX} -fg $small_color		\
			-font $smallfont -pady 0		\
		] -row 1 -column 5

		# Create hexadecimal entries for registers: DP0H DP0L
		set col 0	;# Grid column
		foreach reg {DPH DPL} addr {131 130}	\
			stip {
				{SFR 0x83: Data pointer register}
				{SFR 0x82: Data pointer register}
		} {
			incr col	;# Increment grid column

			# Register this SFR
			lappend sf_registers [list $addr $reg]
			lappend sf_register_labels $frame1_top_right_0._DPTR_l

			# Create register name label
			grid [label $frame1_top_right_0._${reg}_l	\
				-text $reg -fg $small_color		\
				-font $smallfont -pady 0		\
			] -row 1 -column $col
			setStatusTip -widget $frame1_top_right_0._${reg}_l -text [mc $stip]

			# Create register hexadecimal entry
			set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
			set entry [ttk::entry $frame1_top_right_0._${reg}_e			\
				-style Simulator.TEntry						\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}		\
				-width 2							\
				-validate key							\
				-validatecommand "$this entry_2_hex_validate_and_sync %P $reg"	\
				-font $entry_font						\
			]

			# Show and register created memory cell
			grid $entry -row 2 -column $col
			add_entry $entry
			$this add_sfr_entry $addr $entry

			# Set entry event bindings
			bind $entry <Motion>	{help_window_show %X %Y}
			bind $entry <Leave>	{help_window_hide}
			bind $entry <FocusIn>	"$this unmark_entry $addr"
			bind $entry <Enter>	"$this create_help_window_ram $reg; Sbar -freeze {[mc $stip]}"
		}

		# Finalize entry event bindings for DPH and DPL
		bind $frame1_top_right_0._DPH_e <Key-Right>	\
			"Simulator_GUI::sim_entry_right $frame1_top_right_0._DPH_e $frame1_top_right_0._DPL_e"
		bind $frame1_top_right_0._DPL_e <Key-Left>	\
			"Simulator_GUI::sim_entry_left $frame1_top_right_0._DPL_e $frame1_top_right_0._DPH_e"
		if {[$this get_feature_available {ddp}]} {
			bind $frame1_top_right_0._DPH_e <Key-Down> "
				$frame1_top_right_0._DP1H_e icursor \[$frame1_top_right_0._DPH_e index insert\]
				focus $frame1_top_right_0._DP1H_e"
			bind $frame1_top_right_0._DPL_e <Key-Down>	"
				$frame1_top_right_0._DP1L_e icursor \[$frame1_top_right_0._DPL_e index insert\]
				focus $frame1_top_right_0._DP1L_e"
		}

		# Create vertical separator (DPTR + Clock)|(SP + SBUF)
		if {[$this get_feature_available {ddp}]} {set row 3} {set row 2}
		grid [ttk::separator $frame1_top_right_0._SP_sep	\
			-orient vertical				\
		]	\
			-row 2				\
			-column 3			\
			-rowspan $row			\
			-padx 1				\
			-sticky ns

		# Create label "SP:"
		grid [label $frame1_top_right_0._SP_l		\
			-text {SP:} -fg $name_color -pady 0	\
			-font $bitfont				\
		] -row 2 -column 4 -sticky w
		setStatusTip -widget $frame1_top_right_0._SP_l -text [mc "SFR 0x81: Stack pointer"]

		# Create hexadecimal entry for register: SP
		set ::Simulator_GUI::ENV${obj_idx}_SP {07}
		set entry [ttk::entry $frame1_top_right_0._SP_e				\
			-style Simulator.TEntry						\
			-textvariable ::Simulator_GUI::ENV${obj_idx}_SP			\
			-width 2							\
			-validate key							\
			-validatecommand "$this entry_2_hex_validate_and_sync %P SP"	\
			-font $entry_font						\
		]

		# Show and register created memory cell (SP)
		grid $entry -row 2 -column 5
		add_entry $entry
		$this add_sfr_entry 129 $entry

		# Register SP SFR
		lappend sf_registers [list 129 {SP}]
		lappend sf_register_labels $frame1_top_right_0._SP_l

		# Set entry event bindings (SP)
		bind $entry <Motion>	{help_window_show %X %Y}
		bind $entry <Leave>	{help_window_hide}
		bind $entry <FocusIn>	"$this unmark_entry 129"
		bind $entry <Enter>	"$this create_help_window_ram SP; Sbar -freeze {SFR 0x81: Stack pointer}"

		# Create DPTR1
		if {[$this get_feature_available {ddp}] && ![$this get_feature_available {hddptr}]} {

			# Create label "DPTR1:"
			grid [label $frame1_top_right_0._DPTR1_l	\
				-text {DPTR1:} -fg $name_color -pady 0	\
				-font $bitfont				\
			] -row 3 -column 0

			# Create hexadecimal entries for registers: DP1H DP1L
			set col 0	;# Grid column
			foreach reg {DP1H DP1L} addr {133 132}	\
				stip {
					{SFR 0x85: Data pointer register}
					{SFR 0x84: Data pointer register}
			} {
				incr col	;# Increment grid column

				# Register this SFR
				lappend sf_registers [list $addr $reg]
				lappend sf_register_labels $frame1_top_right_0._DPTR1_l

				# Create register hexadecimal entry
				set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
				set entry [ttk::entry $frame1_top_right_0._${reg}_e			\
					-style Simulator.TEntry						\
					-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}		\
					-width 2							\
					-validate key							\
					-validatecommand "$this entry_2_hex_validate_and_sync %P $reg"	\
					-font $entry_font						\
				]

				# Show and register created memory cell
				grid $entry -row 3 -column $col
				add_entry $entry
				$this add_sfr_entry $addr $entry

				# Set entry event bindings
				bind $entry <Motion>	{help_window_show %X %Y}
				bind $entry <Leave>	{help_window_hide; Sbar {}}
				bind $entry <FocusIn>	"$this unmark_entry $addr"
				bind $entry <Enter>	"$this create_help_window_ram $reg; Sbar -freeze {[mc $stip]}"
			}

			# Finalize entry event bindings for DPH and DPL
			bind $frame1_top_right_0._DP1H_e <Key-Right>	\
				"Simulator_GUI::sim_entry_right $frame1_top_right_0._DP1H_e $frame1_top_right_0._DP1L_e"
			bind $frame1_top_right_0._DP1L_e <Key-Left>	\
				"Simulator_GUI::sim_entry_left $frame1_top_right_0._DP1L_e $frame1_top_right_0._DP1H_e"
			bind $frame1_top_right_0._DP1H_e <Key-Up> "
				$frame1_top_right_0._DPH_e icursor \[$frame1_top_right_0._DP1H_e index insert\]
				focus $frame1_top_right_0._DPH_e"
			bind $frame1_top_right_0._DP1L_e <Key-Up>	"
				$frame1_top_right_0._DPL_e icursor \[$frame1_top_right_0._DP1L_e index insert\]
				focus $frame1_top_right_0._DPL_e"

			set row 4
		} else {
			set row 3
		}

		# Create label "Clock:"
		grid [label $frame1_top_right_0._CLOCK_l		\
			-text [mc "Clock:"] -fg $name_nr_color -pady 0	\
			-font $bitfont					\
		] -row $row -column 0 -sticky w
		setStatusTip -widget $frame1_top_right_0._CLOCK_l -text [mc "Processor clock in kHz"]

		# Create hexadecimal entry for created entry: Clock
		set ::Simulator_GUI::ENV${obj_idx}_CLOCK {}
		set entry [ttk::entry $frame1_top_right_0._CLOCK_e		\
			-style Simulator.TEntry					\
			-textvariable ::Simulator_GUI::ENV${obj_idx}_CLOCK	\
			-font $entry_font					\
			-width 7						\
			-validate all						\
			-validatecommand "$this clock_validate %P"		\
		]
		setStatusTip -widget $entry -text [mc "Processor clock in kHz"]

		# Show and register created entry (Clock)
		grid $entry -row $row -column 1 -columnspan 2
		add_entry $entry

		# Set default value for created entry (Clock)
		set ::Simulator_GUI::ENV${obj_idx}_CLOCK [$this cget -P_option_clock]
		clock_validate [$this cget -P_option_clock]

		## Create SBUF registers
		set row 2
		foreach reg	{SBUFR SBUFT}		\
			addr	{153 409}		\
			regname	{{SBUF R} {SBUF T}}	\
			stip	{
				{SFR 0x99: Serial Data Buffer - RECEIVE buffer}
				{SFR 0x99: Serial Data Buffer - TRANSMIT buffer}
			}	\
		{
			incr row

			# Create label "SBUF X:"
			if {[$this get_feature_available uart]} {
				set label [label $frame1_top_right_0._${reg}_l	\
					-text "${regname}:" -fg $name_color	\
					-font $bitfont -pady 0			\
				]
				grid $label -row $row -column 4
				setStatusTip -widget $label -text [mc $stip]


				# Create hexadecimal entry for memory cell: SBUF
				set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
				set entry [ttk::entry $frame1_top_right_0._${reg}_e				\
					-style Simulator.TEntry							\
					-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}			\
					-width 2								\
					-validate key								\
					-validatecommand "$this entry_2_hex_validate_and_sync %P ${reg}"	\
					-font $entry_font							\
				]

				# Show and register created memory cell (SBUF X)
				grid $entry -row $row -column 5
				add_entry $entry
				$this add_sfr_entry $addr $entry

				# Register this SFR
				lappend sf_registers [list $addr $reg]
				lappend sf_register_labels $frame1_top_right_0._${reg}_l

				# Set entry event bindings (SBUF X)
				bind $entry <Motion>	{help_window_show %X %Y}
				bind $entry <Leave>	{help_window_hide; Sbar {}}
				bind $entry <FocusIn>	"$this unmark_entry $addr"
				bind $entry <Enter>	"$this create_help_window_ram $reg; Sbar -freeze {[mc $stip]}"
			}
		}

		incr row
		# Create label "PC:" and button "Go to line"
		set stip [mc "Program counter"]
		set pc_lbl_but_frm [frame $frame1_top_right_0._PC_lbl_but]
		pack [label $pc_lbl_but_frm._PC_l	\
			-text {PC:} -fg $name_nr_color	\
			-font $bitfont			\
		] -side left
		setStatusTip -widget $pc_lbl_but_frm._PC_l -text [mc $stip]
		set set_pc_by_line_button [ttk::button $pc_lbl_but_frm._PC_but		\
			-image ::ICONS::16::2_rightarrow				\
			-command "::X::__simulator_set_PC_by_line"			\
			-style Flat.TButton		 				\
		]
		pack $set_pc_by_line_button -side right -after $pc_lbl_but_frm._PC_l
		DynamicHelp::add $set_pc_by_line_button	\
			-text [mc "Set PC (Program Counter) according to\nline number in source code"]
		add_entry $pc_lbl_but_frm._PC_but
		setStatusTip -widget $set_pc_by_line_button	\
			-text [mc "Set PC by line number"]
		grid $pc_lbl_but_frm -row $row -column 0 -sticky w

		# Create frame for PC-hex (label and entry)
		set frame1_top_right_0_0 [frame $frame1_top_right_0.frame1_top_right_0_0]
		grid $frame1_top_right_0_0  -row $row -column 1 -columnspan 2

		# Create small label "HEX"
		grid [label $frame1_top_right_0_0._PC_hex_l	\
			-text [mc "HEX"] -fg $small_color	\
			-font $smallfont			\
		] -row 1 -column 1

		# Create hexadecimal entry for PC-hex
		set ::Simulator_GUI::ENV${obj_idx}_PC_hex {00}
		set entry [ttk::entry $frame1_top_right_0_0._PC_hex_e		\
			-style Simulator.TEntry					\
			-textvariable ::Simulator_GUI::ENV${obj_idx}_PC_hex	\
			-width 4						\
			-validate key						\
			-validatecommand "$this sim_eval_PC hex %P"		\
			-font $entry_font					\
		]
		setStatusTip -widget $frame1_top_right_0_0._PC_hex_e -text [mc $stip]

		# Show and register created entry (PC - hex)
		grid $entry -row 1 -column 2
		add_entry $entry
		$this add_sfr_entry PC $entry

		# Set entry event bindings (PC - hex)
		bind $entry <FocusIn> "$this unmark_entry PC"

		# Create frame for PC-dec (label and entry)
		set frame1_top_right_0_1 [frame $frame1_top_right_0.frame1_top_right_0_1]
		grid $frame1_top_right_0_1 -row $row -column 4 -columnspan 2

		# Create small label "DEC"
		grid [label $frame1_top_right_0_1._PC_dec_l		\
			-text [mc "DEC"] -fg $small_color -font $smallfont	\
		] -row 1 -column 1

		# Create hexadecimal entry for PC-dec
		set ::Simulator_GUI::ENV${obj_idx}_PC_dec {0}
		set entry [ttk::entry $frame1_top_right_0_1._PC_dec_e		\
			-style Simulator.TEntry					\
			-textvariable ::Simulator_GUI::ENV${obj_idx}_PC_dec	\
			-width 5						\
			-validate key						\
			-validatecommand "$this sim_eval_PC dec %P"		\
			-font $entry_font					\
		]
		setStatusTip -widget $frame1_top_right_0_1._PC_dec_e -text [mc $stip]

		# Show and register created entry (PC - dec)
		grid $entry -row 1 -column 2
		add_entry $entry
		$this add_sfr_entry PC $entry

		# Set entry event bindings (PC - dec)
		bind $entry <FocusIn> "$this unmark_entry PC"


		# FRAME 1 - TOP - RIGHT - 1 (Time)
		set frame1_top_right_1 [frame $frame1_top_right.frame1_top_right_1]
		pack $frame1_top_right_1 -anchor nw

		# Create label "Time:"
		grid [label $frame1_top_right_1._TIME_l			\
			-text [mc "Time:"] -fg $name_nr_color -pady 0	\
			-font $bitfont					\
		] -row 1 -column 0 -sticky w
		setStatusTip -widget  $frame1_top_right_1._TIME_l -text [mc "Overall time"]

		# Create entry widget for "Time"
		set ::Simulator_GUI::ENV${obj_idx}_TIME {}
		set entry [ttk::entry $frame1_top_right_1._TIME_e		\
			-style TEntry						\
			-textvariable ::Simulator_GUI::ENV${obj_idx}_TIME	\
			-state readonly						\
			-justify right						\
			-font [font create -size [expr {int(-12 * $::font_size_factor)}] -family $::DEFAULT_FIXED_FONT]		\
		]
		setStatusTip -widget  $frame1_top_right_1._TIME_e -text [mc "Overall time"]

		# Show entry widget "Time"
		grid $entry -row 1 -column 1 -sticky we

		# Create left bottom frame (Timer 2, ...)
		set bottom_left_frame [frame $main_bottom_frame.bottom_left]
		pack $bottom_left_frame -side left -anchor nw

		# Create bottom left - top frame (above T2)
		set bottom_left_bottom_frame [frame $bottom_left_frame.bottom]
		pack $bottom_left_bottom_frame -anchor nw
		set bottom_left_bottom_row	0	;# Overall number of rows in this part of the panel
		set bottom_left_bottom_trow	0	;# Row in grid

		# Create controls related to Timer/Couter 2
		if {[$this get_feature_available t2]} {
			incr bottom_left_bottom_row 4
			set t2_frame [frame $bottom_left_frame.timers_f]
			pack $t2_frame

			# Create frame for hexadecimal entries: TH1 TL1 TH0 TL0
			set timers_values_f [frame $t2_frame.timers_values_f]
			pack $timers_values_f

			# Create hexadecimal entries for registers: TH1 TL1 TH0 TL0
			set col 0	;# Grid column
			foreach reg {TH2 TL2 RCAP2H RCAP2L} addr {205 204 203 202}	\
				stip {
					{SFR 0xCD: Part of 16-bit counting register for Timer/Counter 2}
					{SFR 0xCC: Part of 16-bit counting register for Timer/Counter 2}
					{SFR 0xCB: Part of 16-bit capture register for Timer/Counter 2}
					{SFR 0xCA: Part of 16-bit capture register for Timer/Counter 2}
			} {
				incr col	;# Increment grid column

				# Register this SFR
				lappend sf_registers [list $addr $reg ]
				lappend sf_register_labels $timers_values_f._${reg}_l

				# Create register name label
				grid [label $timers_values_f._${reg}_l	\
					-text $reg -fg $small_color	\
					-font $smallfont -pady 0	\
				] -row 1 -column $col
				setStatusTip -widget $timers_values_f._${reg}_l -text [mc $stip]

				# Create register hexadecimal entry
				set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
				set entry [ttk::entry $timers_values_f._Txx${col}_e		\
					-style Simulator.TEntry					\
					-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}	\
					-validatecommand "$this validate_Txx $reg %P"		\
					-font $entry_font					\
					-validate key						\
					-width 2						\
				]

				# Show and register created memory cell
				grid $entry -row 2 -column $col
				add_entry $entry
				$this add_sfr_entry $addr $entry

				# Set entry event bindings
				bind $entry <Motion>	{help_window_show %X %Y}
				bind $entry <Leave>	{help_window_hide; Sbar {}}
				bind $entry <FocusIn>	"$this unmark_entry $addr"
				bind $entry <Enter>	"$this create_help_window_ram $reg; Sbar -freeze {[mc $stip]}"
				bind $entry <Key-Right>	\
					"Simulator_GUI::sim_entry_right $entry $timers_values_f._Txx[expr {$col+1}]_e"
				if {$col != {1}} {
					bind $entry <Key-Left>	\
						"Simulator_GUI::sim_entry_left $entry $timers_values_f._Txx[expr {$col-1}]_e"
				}
			}

			# Create decimal entries for timers
			foreach reg {T2 RCAP2} addresses {{205 204} {203 202}}	\
				stip {
					{SFR 0xCC..0xCD: 16-bit counting register for Timer/Counter 2}
					{SFR 0xCA..0xCB: 16-bit capture register for Timer/Counter 2}
			} {
				incr col	;# Increment grid column

				# Create register name label
				grid [label $timers_values_f._${reg}_l	\
					-text $reg -fg $small_color	\
					-font $smallfont -pady 0	\
				] -row 1 -column $col
				setStatusTip -widget $timers_values_f._${reg}_l -text [mc $stip]

				# Create register hexadecimal entry
				set ::Simulator_GUI::ENV${obj_idx}_${reg} {0}
				set entry [ttk::entry $timers_values_f._Txx${col}_e		\
					-style Simulator.TEntry					\
					-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}	\
					-width 5						\
					-validate key						\
					-validatecommand "$this validate_Txx $reg %P"		\
					-font $entry_font					\
				]
				setStatusTip -widget $timers_values_f._Txx${col}_e -text [mc $stip]

				# Show and register created memory cell
				grid $entry -row 2 -column $col
				add_entry $entry

				# Set entry event bindings
				bind $entry <Key-Right>	\
					"Simulator_GUI::sim_entry_right $entry $timers_values_f._Txx[expr {$col+1}]_e"
				bind $entry <Key-Left>	\
					"Simulator_GUI::sim_entry_left $entry $timers_values_f._Txx[expr {$col-1}]_e"
				foreach addr $addresses {
					$this add_sfr_entry $addr $entry
					bind $entry <FocusIn> "$this unmark_entry $addr"
				}
			}

			# Create frame for registers: T2CON T2MOD (bitmaps)
			set timers_frame_reg [frame $t2_frame.timers_reg_f]
			pack $timers_frame_reg -anchor nw
			# Create T2CON and T2MOD bitmaps
			create_bitmap_register $timers_frame_reg 1 T2CON {TF2 EXF2 RCLK TCLK EXEN2 TR2 CT2 CPRL2} 1 {
				{Bit address: 0xCF  --  Timer 2 overflow flag}
				{Bit address: 0xCE  --  Timer 2 external flag}
				{Bit address: 0xCD  --  Receive clock enable}
				{Bit address: 0xCC  --  Transmit clock enable}
				{Bit address: 0xCB  --  Timer 2 external enable}
				{Bit address: 0xCA  --  Start/Stop control for Timer 2}
				{Bit address: 0xC9  --  Timer or counter select for Timer 2}
				{Bit address: 0xC8  --  Capture/Reload select}
			} {SFR 0xC8: Timer/Counter 2 control register} {
				{Timer 2 overflow Flag\nTF2 is not set if RCLK=1 or TCLK = 1.\nMust be cleared by software.\nSet by hardware on timer 2 overflow.}
				{Timer 2 External Flag\nSet when a capture or a reload is caused by a negative transition on T2EX pin if EXEN2=1.\nSet to cause the CPU to vector to timer 2 interrupt routine when timer 2 interrupt is enabled.\nMust be cleared by software.}
				{Receive Clock bit\nClear to use timer 1 overflow as receive clock for serial port in mode 1 or 3.\nSet to use timer 2 overflow as receive clock for serial port in mode 1 or 3.}
				{Transmit Clock bit\nClear to use timer 1 overflow as transmit clock for serial port in mode 1 or 3.\nSet to use timer 2 overflow as transmit clock for serial port in mode 1 or 3.}
				{Timer 2 External Enable bit\nClear to ignore events on T2EX pin for timer 2 operation.\nSet to cause a capture or reload when a negative transition on T2EX pin is\ndetected, if timer 2 is not used to clock the serial port.}
				{Timer 2 Run control bit\nClear to turn off timer 2.\nSet to turn on timer 2.}
				{Timer/Counter 2 select bit\nClear for timer operation (input from internal clock system: FOSC).\nSet for counter operation (input from T2 input pin).}
				{Timer 2 Capture/Reload bit\nIf RCLK=1 or TCLK=1, CP/RL2# is ignored and timer is forced to auto-reload on timer 2 overflow.\nClear to auto-reload on timer 2 overflows or negative transitions on T2EX pin if EXEN2=1.\nSet to capture on negative transitions on T2EX pin if EXEN2=1.}
			}

			if {[$this get_feature_available t2mod]} {
				create_bitmap_register $timers_frame_reg 2 T2MOD {- - - - - - T2OE DCEN} 1 {
					{Reserved}
					{Reserved}
					{Reserved}
					{Reserved}
					{Reserved}
					{Reserved}
					{Timer 2 Output Enable bit}
					{Down Counter Enable bit}
				} {SFR 0xC9: Timer/Counter 2 mode control register} {
					{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.}
					{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.}
					{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.}
					{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.}
					{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.}
					{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.}
					{Timer 2 Output Enable bit\nClear to program P1.0/T2 as clock input or I/O port.\nSet to program P1.0/T2 as clock output.}
					{Down Counter Enable bit\nClear to disable timer 2 as up/down counter.\nSet to enable timer 2 as up/down counter.}
				}
			}

			# Create hexadecimal entries for registers: TCON TMOD
			foreach reg	{T2CON T2MOD}	\
				addr	{200 201}	\
				bits	{{TF2 EXF2 RCLK TCLK EXEN2 TR2 CT2 CPRL2} {- - - - - - T2OE DCEN}}	\
				stip	{
					{SFR 0xC8: Timer/Counter 2 control register}
					{SFR 0xC9: Timer/Counter 2 mode control register}
			} {
				incr col	;# Increment grid column

				if {$reg == {T2MOD} && ![$this get_feature_available t2mod]} {
					continue
				}

				# Register this SFR
				lappend sf_registers [list $addr $reg]
				lappend sf_register_labels $Simulator_panel_parent._${reg}_l

				# Create register name label
				grid [label $timers_values_f._${reg}_hex_l	\
					-text $reg -fg $small_color		\
					-font $smallfont -pady 0		\
				] -row 1 -column $col
				setStatusTip -widget $timers_values_f._${reg}_hex_l -text [mc $stip]

				# Create register hexadecimal entry
				set ::Simulator_GUI::ENV${obj_idx}_${reg} {0}
				set entry [ttk::entry $timers_values_f._Txx${col}_e				\
					-style Simulator.TEntry							\
					-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}			\
					-width 2								\
					-validate key								\
					-validatecommand "$this validate_hex_bitmap_reg %P $reg"		\
					-font $entry_font							\
				]
				set bit_in_particular_regs($reg) $bits

				# Show and register created memory cell
				grid $entry -row 2 -column $col
				$this add_sfr_entry $addr $entry
				add_entry $entry

				# Set entry event bindings
				bind $entry <Motion>	{help_window_show %X %Y}
				bind $entry <Leave>	{help_window_hide; Sbar {}}
				bind $entry <FocusIn>	"$this unmark_entry $addr"
				bind $entry <Enter>	"$this create_help_window_ram $reg; Sbar -freeze {[mc $stip]}"
				if {$reg != {TMOD}} {
					bind $entry <Key-Right>		\
						"Simulator_GUI::sim_entry_right $entry $timers_values_f._Txx[expr {$col+1}]_e"
				}
				bind $entry <Key-Left>	\
					"Simulator_GUI::sim_entry_left $entry $timers_values_f._Txx[expr {$col-1}]_e"
			}
		}

		# Create middle bottom frame
		set bottom_middle_frame [frame $main_bottom_frame.bottom_middle_frame]
		pack $bottom_middle_frame -side left -anchor nw
		set bottom_middle_row		0	;# Row in grid

		# Registers: AUXR, AUXR1, ACSR, EECON, SPCR, SPSR, WDTCON. IPH, SPCR
		if {[$this get_feature_available t2]} {
			set pt2h {PT2H}
			set pt2h_stip {Defines the Timer 2 interrupt priority level}
			set pt2h_ttip {Timer 2 interrupt priority bit}
		} else {
			set pt2h {-}
			set pt2h_stip {Not implemented}
			set pt2h_ttip {Not implemented}
		}
		if {[$this get_feature_available uart]} {
			set psh {PSH}
			set psh_stip {Defines the Serial Port interrupt priority level}
			set psh_ttip {Serial Port interrupt priority bit}
		} else {
			set psh {-}
			set psh_stip {Not implemented}
			set psh_ttip {Not implemented}
		}
		if {[$this get_feature_available acomparator]} {
			set pch {PCH}
			set pch_stip {Defines the comparator interrupt priority level}
			set pch_ttip {Comparator Interrupt Priority bit}
		} else {
			set pch {-}
			set pch_stip {Not implemented}
			set pch_ttip {Not implemented}
		}
		if {[$this get_feature_available pwdex]} {
			set PWDEX {PWDEX}
			set pwdex_stip {Power-down Exit Mode}
			set pwdex_ttip {Power-down Exit Mode. When PWDEX = 1, wake up from Power-down is externally controlled.\nWhen PWDEX = 0, wake up from Power-down is internally timed.}
		} else {
			set PWDEX {-}
			set pwdex_stip {Not implemented}
			set pwdex_ttip {Not implemented}
		}
		if {[lindex [$this cget -procData] 8]} {
			set EXTRAM {EXTRAM}
			set extram_statustip {Internal/External RAM access using MOVX}
			set extram_tooltip {Internal/External RAM access using MOVX @ Ri/@DPTR\nEXTRAM\tOperating Mode\n0\tInternal ERAM (00H-FFH) access using MOVX @ Ri/@DPTR\n1\tExternal data memory access}
		} elseif {[$this get_feature_available intelpe]} {
			set EXTRAM {IPE}
			set extram_statustip {Intel_Pwd_Exit}
			set extram_tooltip {When set, this bit configures the interrupt driven exit from power-down\nto resume execution on the rising edge of the interrupt signal. When\nthis bit is cleared, the execution resumes after a self-timed interval\n(nominal 2 ms) referenced from the falling edge of the interrupt signal.}
		} else {
			set EXTRAM {-}
			set extram_statustip {Reserved for future expansion}
			set extram_tooltip {Reserved\nThe value read from this bit is indeterminate. Do not set this bit.}
		}
		if {
			[$this get_feature_available wdtcon]	||
			![$this get_feature_available wtd]	||
			![$this get_feature_available auxrdisrto]
		} then {
			set DISRTO {-}
			set disrto_stip {Reserved for future expansion}
			set disrto_ttip {Reserved\nThe value read from this bit is indeterminate. Do not set this bit.}
		} else {
			set DISRTO {DISRTO}
			set disrto_stip {Disable/Enable Reset out}
			set disrto_ttip {Disable/Enable Reset out\nDISRTO\tOperating Mode\n0\tReset pin is driven High after WDT times out\n1\tReset pin is input only}
		}
		if {
			[$this get_feature_available wdtcon]	||
			![$this get_feature_available wtd]	||
			![$this get_feature_available auxrwdidle]
		} then {
			set WDIDLE {-}
			set wdidle_stip {Reserved for future expansion}
			set wdidle_ttip {Reserved\nThe value read from this bit is indeterminate. Do not set this bit.}
		} else {
			set WDIDLE {WDIDLE}
			set wdidle_stip {Disable/Enable WDT in IDLE mode}
			set wdidle_ttip {Disable/Enable WDT in IDLE mode\nWDIDLE\tOperating Mode\n0\tWDT continues to count in IDLE mode\n1\tWDT halts counting in IDLE mode}
		}
		if {[$this get_feature_available ao]} {
			set DISALE {AO}
		} else {
			set DISALE {DISALE}
		}
		if {[$this get_feature_available auxr1gf3]} {
			set GF3 {GF3}
			set gf3_ttip {General purpose user flag}
			set gf3_stip {General purpose user flag}
		} else {
			set GF3 {-}
			set gf3_ttip {Reserved\nThe value read from this bit is indeterminate. Do not set this bit.}
			set gf3_stip {Reserved for future expansion}
		}
		set left__right	0	;# Packe left (1) or right (0)
		set row		0	;# Grid row
		foreach reg 	{AUXR	AUXR1	ACSR	EECON	SPCR	SPSR	WDTCON	WDTPRG	IPH	CLKREG	} \
			addr	{142	162	151	150	213	170	167	167	183	143	} \
			cg_left	{0	1	1	0	0	1	0	1	1	1	} \
			bits [list							\
				[list - - - $WDIDLE $DISRTO - $EXTRAM $DISALE]		\
				[list - - - - $GF3 - - DPS]				\
				[list - - - CF CEN CM2 CM1 CM0]				\
				[list - - EELD EEMWE EEMEN DPS RDYBSY WRTINH]		\
				[list SPIE SPE DORD MSTR CPOL CPHA SPR1 SPR0]		\
				[list SPIF WCOL LDEN - - - DISSO ENH]			\
				[list PS2 PS1 PS0 WDIDLE DISRTO HWDT WSWRST WDTEN]	\
				[list T4 T3 T2 T1 T0 S2 S1 S0]				\
				[list - $pch $pt2h $psh PT1H PX1H PT0H PX0H]	\
				[list - - - - - - $PWDEX X2]			\
			] stip {
				{SFR 0x8E: Auxiliary Register}
				{SFR 0xA2: Auxiliary Register 1}
				{SFR 0x97: Analog Comparator Control and Status Register}
				{SFR 0x96: Data EEPROM Control Register}
				{SFR 0xD5: SPI Control Register}
				{SFR 0xAA: SPI Status Register}
				{SFR 0xA7: Watchdog Control Register}
				{SFR 0xA7: Watchdog Prescaler Control Register}
				{SFR 0xB7: Interrupt Priority High Register}
				{SFR 0x8F: Clock Register}
		} {
			if {$cg_left && $bottom_middle_row > $bottom_left_bottom_row} {
				set left__right 1
				set target_frame $bottom_left_bottom_frame
 			} else {
 				set left__right 0
				set target_frame $bottom_middle_frame
			}

			switch -- $reg {
				{IPH} {
					if {![$this get_feature_available iph]} {
						continue
					}
					create_bitmap_register $target_frame $row $reg $bits 1 [list \
						{Not implemented} \
						$pch_stip \
						$pt2h_stip \
						$psh_stip \
						{Defines the Timer 1 interrupt priority level} \
						{Defines External Interrupt 1 priority level} \
						{Defines the Timer 0 interrupt priority level} \
						{Defines the External Interrupt 0 priority level} \
					] $stip [list \
						{Not implemented} \
						$pch_ttip \
						$pt2h_ttip \
						$psh_ttip \
						{Timer 1 interrupt priority bit} \
						{External interrupt 1 priority bit} \
						{Timer 0 interrupt priority bit} \
						{External interrupt 0 priority bit} \
					]
				}
				{CLKREG} {
					if {[$this get_feature_available clkreg]} {
						set reg {CLKREG}
					} elseif {[$this get_feature_available ckcon]} {
						set reg {CKCON}
					} else {
						continue
					}

					create_bitmap_register $target_frame $row $reg $bits 1 [list \
						{Not implemented} \
						{Not implemented} \
						{Not implemented} \
						{Not implemented} \
						{Not implemented} \
						{Not implemented} \
						$pwdex_stip \
						{X2 mode flag} \
					] $stip [list \
						{Not implemented} \
						{Not implemented} \
						{Not implemented} \
						{Not implemented} \
						{Not implemented} \
						{Not implemented} \
						$pwdex_ttip \
						{When X2 = 0, the frequency (at XTAL1 pin) is internally divided by 2 before it is used as the device system frequency.\nWhen X2 = 1, the divide by 2 is no longer used and the XTAL1 frequency becomes the device system frequency. This\nenables the user to use a 6 MHz crystal instead of a 12 MHz crystal in order to reduce EMI.} \
					]
				}
				{EECON} {
					if {![lindex [$this cget -procData] 32]} {
						continue
					}
					create_bitmap_register $target_frame $row $reg $bits 1 {
						{Not implemented}
						{Not implemented}
						{EEPROM data memory load enable bit}
						{EEPROM data memory write enable bit}
						{Internal EEPROM access enable}
						{Data pointer register select}
						{RDY/BSY (Ready/Busy) flag for the data EEPROM memory (read-only)}
						{Write Inhibit (read-only)}
					} $stip {
						{Not implemented}
						{Not implemented}
						{EEPROM data memory load enable bit. Used to implement Page Mode Write. A MOVX\ninstruction writing into the data EEPROM will not initiate the programming cycle\nif this bit is set, rather it will just load data into the volatile data buffer\nof the data EEPROM memory. Before the last MOVX, reset this bit and the data\nEEPROM will program all the bytes previously loaded on the same page of the\naddress given by the last MOVX instruction.}
						{EEPROM data memory write enable bit. Set this bit to 1 before initiating byte\nwrite to on-chip EEPROM with the MOVX instruction. User software should set\nthis bit to 0 after EEPROM write is completed.}
						{Internal EEPROM access enable. When EEMEN = 1, the MOVX instruction with DPTR\nwill access on-chip EEPROM instead of external data memory if the address used\nis less than 2K. When EEMEN = 0 or the address used is ≥ 2K,}
						{MOVX with DPTR accesses external data memory.\nData pointer register select. DPS = 0 selects the first bank of data pointer\nregister, DP0, and DPS = 1 selects the second bank, DP1.}
						{RDY/BSY (Ready/Busy) flag for the data EEPROM memory. This is a read-only bit\nwhich is cleared by hardware during the programming cycle of the on-chip EEPROM.\nIt is also set by hardware when the programming is completed. Note that RDY/BSY\nwill be cleared long after the completion of the MOVX instruction which has\ninitiated the programming cycle.}
						{WRTINH (Write Inhibit) is a READ-ONLY bit which is cleared by hardware when Vcc is\ntoo low for the programming cycle of the on-chip EEPROM to be executed. When this\nbit is cleared, an ongoing programming cycle will be aborted or a new programming\ncycle will not start.}
					}

					# Set read-only registers
					set bits [lreplace $bits 6 6 -]
					bind $Simulator_panel_parent._EECON_RDYBSY <Button-1> {break}
					bind $Simulator_panel_parent._EECON_RDYBSY <ButtonRelease-3> {break}
				}
				{WDTCON} {
					if {![$this get_feature_available wdtcon] || [$this get_feature_available wdtprg]} {
						continue
					}
					set psx_tooltip {Prescaler bits for the watchdog timer (WDT). When all three bits are cleared\nto 0, the watchdog timer has a nominal period of 16K machine cycles,\n(i.e. 16 ms at a XTAL frequency of 12 MHz in normal mode or 6 MHz in x2 mode).\nWhen all three bits are set to 1, the nominal period is 2048K machine cycles,\n(i.e. 2048 ms at 12 MHz clock frequency in normal mode or 6 MHz in x2 mode).}

					create_bitmap_register $target_frame $row $reg $bits 1 [list \
						{Prescaler bit for the watchdog timer} \
						{Prescaler bit for the watchdog timer} \
						{Prescaler bit for the watchdog timer} \
						{Enable/disable the Watchdog Timer in IDLE mode} \
						{Enable/disable the WDT-driven Reset Out} \
						{Hardware mode select for the WDT} \
						{Watchdog software reset bit} \
						{Watchdog software enable bit} \
					] $stip [list  \
						$psx_tooltip \
						$psx_tooltip \
						$psx_tooltip \
						{Enable/disable the Watchdog Timer in IDLE mode. When WDIDLE = 0, WDT\ncontinues to count in IDLE mode. When WDIDLE = 1, WDT freezes while\nthe device is in IDLE mode.} \
						{Enable/disable the WDT-driven Reset Out (WDT drives the RST pin). When\nDISRTO = 0, the RST pin is driven high after WDT times out and the entire\nboard is reset. When DISRTO = 1, the RST pin remains only as an input and the\nWDT resets only the microcontroller internally after WDT times out.} \
						{Hardware mode select for the WDT. When HWDT = 0, the WDT can be turned on/off\nby simply setting or clearing WDTEN in the same register (this is the software\nmode for WDT). When HWDT = 1, the WDT has to be set by writing the sequence\n1EH/E1H to the WDTRST register (with address 0A6H) and after being set in this\nway, WDT cannot be turned off except by reset, warm or cold (this is the hardware\nmode for WDT). To prevent the hardware WDT from resetting the entire device,\nthe same sequence 1EH/E1H must be written to the same WDTRST SFR before the\ntimeout interval.} \
						{Watchdog software reset bit. If HWDT = 0 (i.e. WDT is in software controlled mode),\nwhen set by software, this bit resets WDT. After being set by software, WSWRST is\nreset by hardware during the next machine cycle. If HWDT = 1, this bit has no effect,\nand if set by software, it will not be cleared by hardware.} \
						{Watchdog software enable bit. When HWDT = 0 (i.e. WDT is in software-controlled mode),\nthis bit enables WDT when set to 1 and disables WDT when cleared to 0 (it does not\nreset WDT in this case, but just freezes the existing counter state). If HWDT = 1, this\nbit is READ-ONLY and reflects the status of the WDT (whether it is running or not).} \
					]
				}
				{WDTPRG} {
					if {![$this get_feature_available wdtprg] || [$this get_feature_available wdtcon]} {
						continue
					}
					set t_stip {Reserved}
					set t_ttip {Do not try to set or clear this bit}
					set s_stip {WDT Time-out select bit}
					set s_ttip {Prescaler bits for the watchdog timer (WDT). When all three bits are cleared\nto 0, the watchdog timer has a nominal period of 16K machine cycles,\n(i.e. 16 ms at a XTAL frequency of 12 MHz in normal mode or 6 MHz in x2 mode).\nWhen all three bits are set to 1, the nominal period is 2048K machine cycles,\n(i.e. 2048 ms at 12 MHz clock frequency in normal mode or 6 MHz in x2 mode).}

					create_bitmap_register $target_frame $row $reg $bits 1 [list	\
						$t_stip $t_stip $t_stip $t_stip $t_stip $s_stip $s_stip $s_stip	\
					] $stip [list				\
						$t_ttip $t_ttip $t_ttip $t_ttip	\
						$t_ttip $s_ttip $s_ttip $s_ttip	\
					]

					# Set read-only registers
					set bits {- - - - - S2 S1 S0}
					foreach bit {T0 T1 T2 T3 T4} {
						bind $Simulator_panel_parent._${reg}_${bit} <Button-1> {break}
						bind $Simulator_panel_parent._${reg}_${bit} <ButtonRelease-3> {break}
					}
				}
				{SPSR} {
					if {![$this get_feature_available spi]} {
						continue
					}
					create_bitmap_register $target_frame $row $reg $bits 1 {
						{SPI interrupt flag}
						{Write collision flag}
						{Load enable}
						{Not implemented}
						{Not implemented}
						{Not implemented}
						{Disable slave output bit}
						{Enhanced SPI mode select bit}
					} $stip {
						{SPI interrupt flag. When a serial transfer is complete, the SPIF bit is set and an interrupt is generated if SPIE = 1 and ES\n= 1. The SPIF bit is cleared by reading the SPI status register followed by reading/writing the SPI data register.}
						{When ENH = 0: Write collision flag. The WCOL bit is set if the SPI data register is written during a data transfer. During\ndata transfer, the result of reading the SPDR register may be incorrect, and writing to it has no effect. The WCOL bit (and\nthe SPIF bit) are cleared by reading the SPI status register followed by reading/writing the SPI data register.\nWhen ENH = 1: WCOL works in Enhanced mode as Tx Buffer Full. Writing during WCOL = 1 in enhanced mode will\noverwrite the waiting data already present in the Tx Buffer. In this mode, WCOL is no longer reset by the SPIF reset but\nis reset when the write buffer has been unloaded into the serial shift register.}
						{Load enable for the Tx buffer in enhanced SPI mode.\nWhen ENH is set, it is safe to load the Tx Buffer while LDEN = 1 and WCOL = 0. LDEN is high during bits 0 - 3 and is low\nduring bits 4 - 7 of the SPI serial byte transmission time frame.}
						{Not implemented}
						{Not implemented}
						{Not implemented}
						{Disable slave output bit.\nWhen set, this bit causes the MISO pin to be tri-stated so more than one slave device can share the same interface with\na single master. Normally, the first byte in a transmission could be the slave address and only the selected slave should\nclear its DISSO bit.}
						{Enhanced SPI mode select bit. When ENH = 0, SPI is in normal mode, i.e. without write double buffering.\nWhen ENH = 1, SPI is in enhanced mode with write double buffering. The Tx buffer shares the same address with the\nSPDR register.}
					}
				}
				{SPCR} {
					if {![$this get_feature_available spi]} {
						continue
					}
					create_bitmap_register $target_frame $row $reg $bits 1 [list	\
						{SPI interrupt enable} \
						{SPI enable} \
						{Data order} \
						{Master/slave select} \
						{Clock polarity} \
						{Clock phase} \
						{SPI clock rate select} \
						{SPI clock rate select} \
					] $stip [list \
						{SPI interrupt enable.\nThis bit, in conjunction with the ES bit in the IE register,\nenables SPI interrupts: SPIE = 1 and ES = 1 enable SPI interrupts. SPIE = 0 disables SPI interrupts.} \
						{SPI enable. SPI = 1 enables the SPI channel and connects\nSS, MOSI, MISO and SCK to pins P1.4, P1.5, P1.6, and P1.7.\nSPI = 0 disables the SPI channel.} \
						{Data order. DORD = 1 selects LSB first data transmission.\nDORD = 0 selects MSB first data transmission.} \
						{Master/slave select. MSTR = 1 selects Master SPI mode.\nMSTR = 0 selects slave SPI mode.} \
						{Clock polarity. When CPOL = 1, SCK is high when idle. When CPOL = 0,\nSCK of the master device is low when not transmitting. Please refer to\nfigure on SPI clock phase and polarity control.} \
						{Clock phase. The CPHA bit together with the CPOL bit controls the\nclock and data relationship between master and slave. Please refer\nto figure on SPI clock phase and polarity control.} \
						{SPI clock rate select.\nThese two bits control the SCK rate of the device configured as master.\nSPR1 and SPR0 have no effect on the slave. The relationship between SCK and the\noscillator frequency, FOSC., is as follows:\n  SPR1\tSPR0\tSCK\n  0\t0\tf/4 (f/2 in x2mode)\n  0\t1\tf/16 (f/8 in x2 mode)\n  1\t0\tf/64 (f/32 in x2 mode)\n  1\t1\tf/128 (f/64 in x2 mode)} \
						{SPI clock rate select.\nThese two bits control the SCK rate of the device configured as master.\nSPR1 and SPR0 have no effect on the slave. The relationship between SCK and the\noscillator frequency, FOSC., is as follows:\n  SPR1\tSPR0\tSCK\n  0\t0\tf/4 (f/2 in x2mode)\n  0\t1\tf/16 (f/8 in x2 mode)\n  1\t0\tf/64 (f/32 in x2 mode)\n  1\t1\tf/128 (f/64 in x2 mode)} \
					]
				}
				{ACSR} {
					if {![$this get_feature_available acomparator]} {
						continue
					}
					set CMx_tooltip {Comparator Interrupt Mode\n 2   1   0\tInterrupt Mode\n--- --- ---\t---------------------------------------\n 0   0   0\tNegative (Low) level\n 0   0   1\tPositive edge\n 0   1   0\tToggle with debounce\n 0   1   1\tPositive edge with debounce\n 1   0   0\tNegative edge\n 1   0   1\tToggle\n 1   1   0\tNegative edge with debounce\n 1   1   1\tPositive (High) level}
					create_bitmap_register $target_frame $row $reg $bits 1 {
						{Not implemented}
						{Not implemented}
						{Not implemented}
						{Comparator Interrupt}
						{Comparator Enable}
						{Comparator Interrupt Mode}
						{Comparator Interrupt Mode}
						{Comparator Interrupt Mode}
					} $stip [list \
						{Not implemented} \
						{Not implemented} \
						{Not implemented} \
						{Comparator Interrupt Flag. Set when the comparator output meets the conditions specified by the CM \[2:0\] bits and CEN\nis set. The flag must be cleared by software. The interrupt may be enabled/disabled by setting/clearing bit 6 of IE.} \
						{Comparator Enable. Set this bit to enable the comparator. Clearing this bit will force the comparator output low and\nprevent further events from setting CF.} \
						$CMx_tooltip	$CMx_tooltip	$CMx_tooltip \
					]
				}
				{AUXR1} {
					if {
						(![$this get_feature_available ddp] || [$this get_feature_available wdtcon])
							&& ![$this get_feature_available auxr1gf3]
					} then {
						continue
					}
					create_bitmap_register $target_frame $row $reg $bits 1 [list \
						{Reserved for future expansion} \
						{Reserved for future expansion} \
						{Reserved for future expansion} \
						{Reserved for future expansion} \
						$gf3_stip \
						{Reserved for future expansion} \
						{Reserved for future expansion} \
						{Data Pointer Register Select} \
					] $stip [list  \
						{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.} \
						{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.} \
						{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.} \
						{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.} \
						$gf3_ttip \
						{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.} \
						{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.} \
						{DPS\tData Pointer Register Select\n0\tSelects DPTR Registers DP0L, DP0H\n1\tSelects DPTR Registers DP1L, DP1H\n} \
					]
				}
				{AUXR} {
					if {![$this get_feature_available auxr]} {
						continue
					}
					create_bitmap_register $target_frame $row $reg $bits 1 [list	\
						{Reserved for future expansion} \
						{Reserved for future expansion} \
						{Reserved for future expansion} \
						$wdidle_stip \
						$disrto_stip \
						{Reserved for future expansion} \
						$extram_statustip \
						{Disable/Enable ALE} \
					] $stip [list \
						{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.} \
						{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.} \
						{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.} \
						$wdidle_ttip \
						$disrto_ttip \
						{Reserved\nThe value read from this bit is indeterminate. Do not set this bit.} \
						$extram_tooltip \
						{Disable/Enable ALE\nDISALE\tOperating Mode\n0\tALE is emitted at a constant rate of 1/6 the oscillator frequency\n1\tALE is active only during a MOVX or MOVC instruction} \
					]
				}
			}

			# Register this SFR
			lappend sf_registers [list $addr $reg]
			lappend sf_register_labels $Simulator_panel_parent._${reg}_l

			# Create register name labels
			grid [label $target_frame._${reg}_hex_l	\
				-text {HEX} -fg $small_color		\
				-font $smallfont -pady 0		\
			] -row $row -column 12
			setStatusTip -widget $target_frame._${reg}_hex_l -text [mc $stip]

			# Create register hexadecimal entry
			set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
			set entry [ttk::entry $target_frame._${reg}_e					\
				-style Simulator.TEntry							\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}			\
				-width 2								\
				-validate key								\
				-validatecommand "$this validate_hex_bitmap_reg %P $reg"		\
				-font $entry_font							\
			]
			set bit_in_particular_regs($reg) $bits

			if {$reg != {EECON}} {
				set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
			} else {
				set ::Simulator_GUI::ENV${obj_idx}_${reg} {03}
			}

			# Show and register created memory cell
			grid $entry -row $row -column 13 -padx 5
			add_entry $entry
			$this add_sfr_entry $addr $entry

			# Set entry event bindings
			bind $entry <Motion>	{help_window_show %X %Y}
			bind $entry <Leave>	{help_window_hide; Sbar {}}
			bind $entry <FocusIn>	"$this unmark_entry $addr"
			bind $entry <Enter>	"$this create_help_window_ram $reg; Sbar -freeze {[mc $stip]}"

			# Incerement row pointer
			incr row
			if {$left__right} {
				incr bottom_left_bottom_row
				incr bottom_left_bottom_trow
 			} else {
				incr bottom_middle_row
			}
		}
		# Create vertical separator
		if {$bottom_middle_row} {
			if {$bottom_left_bottom_row} {
				pack [ttk::separator $main_bottom_frame._sep0 -orient vertical]	\
					-side left -fill y -padx 5 -before $bottom_middle_frame
			}
		}

		set bottom_right_frame [frame $main_bottom_frame.bottom_right_frame]
		pack $bottom_right_frame -side left -anchor nw
		set bottom_right_present 0

		# Create bottom right register frame
		set bottom_right_reg_frame [frame $bottom_right_frame.regs]
		pack $bottom_right_reg_frame -anchor nw

		# Create bottom right special function frame
		set bottom_right_spec_frame [frame $bottom_right_frame.spec]
		pack $bottom_right_spec_frame -anchor nw -fill both

		## Create watchdog timer controls
		if {[$this get_feature_available wtd]} {
			set bottom_right_present 1
			set watchdog_frame [frame $bottom_right_frame.watchdog_frame]
			pack $watchdog_frame -anchor nw -before $bottom_right_reg_frame

			pack [label $watchdog_frame._WatchDog_l			\
				-text [mc "Watchdog:"] -fg $name_nr_color	\
				-anchor w -pady 0 -font $bitfont		\
			] -side left
			setStatusTip -widget $watchdog_frame._WatchDog_l -text [mc "Watchdog timer"]

			# Create ON/OFF switch
			set watchdog_onoff_switch [label $watchdog_frame.on_off_switch	\
				-text [mc "OFF"] -fg $off_color -pady 0	\
				-bd 1 -cursor hand2 -font [font create	\
					-family $::DEFAULT_FIXED_FONT -size [expr {int(-12 * $::font_size_factor)}]	\
					-weight bold			\
				]					\
			]
			setStatusTip -widget $watchdog_onoff_switch -text [mc "Watchdog timer ON/OFF switch"]
			bind $watchdog_onoff_switch <Button-1> "$this simulator_invert_wtd_onoff_switch"
			pack $watchdog_onoff_switch -side left -padx 2

			# Create entryBox for watchdog prescaler
			if {[$this get_feature_available wdtcon] || [$this get_feature_available wdtprg]} {
				# Create hexadecimal entry for created entry: WatchDog
				set ::Simulator_GUI::ENV${obj_idx}_WatchDogP {00}
				set wdt_prescaler_entry [ttk::entry $watchdog_frame._WatchDogP_e\
					-style Simulator.TEntry					\
					-textvariable ::Simulator_GUI::ENV${obj_idx}_WatchDogP	\
					-font $entry_font					\
					-width 2						\
					-validate all						\
					-validatecommand "$this watchdog_prescaler_validate %P"	\
				]
				set ::Simulator_GUI::ENV${obj_idx}_WatchDogP {00}

				# Show and register created entry (WatchDog)
				pack $wdt_prescaler_entry -side left
				setStatusTip -widget $wdt_prescaler_entry -text [mc "Watchdog Prescaler (0-7 bits)"]
				add_entry $wdt_prescaler_entry
			}

			# Create hexadecimal entry for created entry: WatchDog
			set ::Simulator_GUI::ENV${obj_idx}_WatchDog {00}
			set watchdog_entry [ttk::entry $watchdog_frame._WatchDog_e	\
				-style Simulator_watchdogEntry_0.TEntry			\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_WatchDog	\
				-font $entry_font					\
				-width 4						\
				-validate all						\
				-validatecommand "$this watchdog_validate %P"		\
			]

			# Show and register created entry (WatchDog)
			pack $watchdog_entry -side left
			setStatusTip -widget $watchdog_entry -text [mc "Watchdog timer"]
			add_entry $watchdog_entry

			# Set default value for created entry (WatchDog)
			set ::Simulator_GUI::ENV${obj_idx}_WatchDog {0000}

			set wtd_clear_button [ttk::button $watchdog_frame.clear_button		\
				-image ::ICONS::16::clear_left					\
				-command "
					set ::Simulator_GUI::ENV${obj_idx}_WatchDog {0000}
					$this simulator_setWatchDogTimer 0
				" \
				-state disabled							\
				-style Flat.TButton						\
			]
			DynamicHelp::add $watchdog_frame.clear_button	\
				-text [mc "Reset Watchdog"]
			pack $wtd_clear_button -side left
			setStatusTip -widget $wtd_clear_button	\
				-text [mc "Reset watchdog timer"]
		}

		set row 0
		set col 0
		foreach	reg	{SADEN	SADDR	SPDR	WDTRST	} \
			addr	{185	169	134	166	} \
			feature	{euart	euart	spi	wtd	} \
			stip {
				{SFR 0xB9: Used to define which bits in the SADDR are to be used}
				{SFR 0xA9: Define the slave's address}
				{SFR 0x86: SPI Data Register}
				{SFR 0xA6: Watchdog reset}
		} {
			if {![$this get_feature_available $feature]} {
				continue
			}
			if {$col >= 4} {
				set col 0
				incr row
			}
			set bottom_right_present 1


			# Register this SFR
			lappend sf_registers [list $addr $reg]
			lappend sf_register_labels $bottom_right_reg_frame._${reg}_l

			# Create register label
			grid [label $bottom_right_reg_frame._${reg}_l		\
				-text "${reg}:" -fg $name_color			\
				-anchor w -pady 0 -font $bitfont		\
			] -column $col -row $row -sticky w
			incr col
			setStatusTip -widget $bottom_right_reg_frame._${reg}_l -text [mc $stip]

			# Create register hexadecimal entry
			set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}
			set entry [ttk::entry $bottom_right_reg_frame._${reg}_e			\
				-style Simulator.TEntry						\
				-textvariable ::Simulator_GUI::ENV${obj_idx}_${reg}		\
				-validatecommand "$this entry_2_hex_validate_and_sync %P ${reg}"\
				-font $entry_font						\
				-validate key							\
				-width 2							\
			]
			set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}

			# Show the entry
			grid $entry -column $col -row $row -sticky w
			incr col 2
			# Register register entry for disabling/enabling
			$this add_sfr_entry $addr $entry
			add_entry $entry
			# Set entry default value
			set ::Simulator_GUI::ENV${obj_idx}_${reg} {00}

			# Set entry bindings
			bind $entry <Motion>	{help_window_show %X %Y}
			bind $entry <Leave>	{help_window_hide; Sbar {}}
			bind $entry <Enter>	"$this create_help_window_ram ${reg}; Sbar -freeze {[mc $stip]}"
			bind $entry <FocusIn>	"$this unmark_entry $addr"
		}
		grid columnconfigure $bottom_right_reg_frame 2 -minsize 5

		set bottom_right_bottom_frame [frame $bottom_right_frame.bottom]
		pack $bottom_right_bottom_frame -anchor nw

		if {$bottom_middle_row && $bottom_right_present} {
			pack [ttk::separator $main_bottom_frame._sep1 -orient vertical]	\
				-side left -fill y -padx 5 -before $bottom_right_frame
		}

		# Create parts of special functions frame
		if {[lindex [$this cget -procData] 32]} {
			simulator_GUI_cancel_write_to_eeprom
		}

		## Finalize panel initialization
		set disable_validation 0	;# Enable entries validations
		 # Sort lists of SFRs
		set len [llength $sf_registers]
		for {set j 1} {$j < $len} {incr j} {
			for {set i 1; set k 0} {$i < $len} {incr i; incr k} {
				if {
					[string compare					\
						[lindex $sf_registers [list $i 1]]	\
						[lindex $sf_registers [list $k 1]]	\
					] < 0
				} then {
					set tmp [lindex $sf_registers $i]
					lset sf_registers $i [lindex $sf_registers $k]
					lset sf_registers $k $tmp

					set tmp [lindex $sf_register_labels $i]
					lset sf_register_labels $i [lindex $sf_register_labels $k]
					lset sf_register_labels $k $tmp
				}
			}
		}

		$this Simulator_first_sync
		sim_disable
	}

	## Show EEPROM write progress indicator
	 # @return void
	public method simulator_GUI_invoke_write_to_eeprom {} {
		if {!$sim_gui_gui_initialized} {return}

		# Create EEPROM indicator frame and horizonatl separator above it
		set eeprom_operation_frame [frame $bottom_right_spec_frame.frame]
		pack [ttk::separator $eeprom_operation_frame.sep] -fill x -pady 1

		## Create top frame
		set top [frame $eeprom_operation_frame.top]
		 # Create label "Writing to EEPROM"
		grid [label $top.lbl -text [mc "Writing to EEPROM"] -pady 0]	\
			-sticky we -row 0 -column 0
		 # Create button "Finalize"
		grid [ttk::button $top.but_finalize				\
			-style Flat.TButton					\
			-image ::ICONS::16::2rightarrow				\
			-command "$this simulator_finalize_write_to_eeprom" 	\
		] -sticky e -row 0 -column 1 -padx 2
		DynamicHelp::add $top.but_finalize	\
			-text [mc "Finalize data EEPROM write cycle"]
		setStatusTip -widget $top.but_finalize -text [mc "Finalize write cycle"]
		 # Create button "Cancel"
		grid [ttk::button $top.but_cancel				\
			-style Flat.TButton					\
			-image ::ICONS::16::button_cancel			\
			-command "$this simulator_cancel_write_to_eeprom" 	\
		] -sticky e -row 0 -column 2
		DynamicHelp::add $top.but_cancel	\
			-text [mc "Cancel data EEPROM write cycle"]
		setStatusTip -widget $top.but_cancel -text [mc "Cancel write cycle"]
		grid columnconfigure $top 0 -weight 1

		pack $top -fill x

		# Create progress bar
		set ::Simulator_GUI::ENV${obj_idx}_EEPROM_prg 0
		set eeprom_progressbar [ProgressBar		\
			$eeprom_operation_frame.progressbar	\
			-type normal				\
			-maximum 100				\
			-variable ::Simulator_GUI::ENV${obj_idx}_EEPROM_prg	\
		]
		setStatusTip -widget $eeprom_progressbar -text [mc "EEPROM write cycle progress"]
		pack $eeprom_progressbar -fill x

		# Pack indicator frame
		pack $eeprom_operation_frame -fill x -anchor nw -expand 1
	}

	## Hide EEPROM write progress indicator
	 # @return void
	public method simulator_GUI_cancel_write_to_eeprom {} {
		if {!$sim_gui_gui_initialized} {return}

		set ::Simulator_GUI::ENV${obj_idx}_EEPROM_prg 1
		if {[winfo exists $eeprom_operation_frame]} {
			destroy $eeprom_operation_frame
		}
	}

	## Set data EEPROM write progress value in %
	 # @parm Int value - New progress value in percents minus one (1..101)
	 # @return void
	public method simulator_WTE_prg_set {value} {
		if {!$sim_gui_gui_initialized} {return}

		if {$value < 1} {
			set value 1
		}
		set ::Simulator_GUI::ENV${obj_idx}_EEPROM_prg $value
		if {$value <= 20} {
			set clr {#FF0000}
		} elseif {$value <= 40} {
			set clr {#FF8800}
		} elseif {$value <= 60} {
			set clr {#FFFF00}
		} elseif {$value <= 80} {
			set clr {#88FF00}
		} elseif {$value <= 100} {
			set clr {#00FF00}
		} else {
			simulator_GUI_cancel_write_to_eeprom
			return
		}

		$eeprom_progressbar configure -fg $clr
	}

	## Adjust watchdog on/off switch according to current state
	 # @return void
	public method simulator_evaluate_wtd_onoff_switch {} {
		if {!$sim_gui_gui_initialized} {return}

		if {[$this simulator_isWatchDogTimerRuning]} {
			$watchdog_onoff_switch configure -text [mc "ON "] -fg $on_color
		} else {
			$watchdog_onoff_switch configure -text [mc "OFF"] -fg $off_color
		}
	}

	## Invert watchdog on/off flag
	 # @return void
	public method simulator_invert_wtd_onoff_switch {} {
		if {!$sim_gui_gui_initialized} {return}

		if {!$sim_enabled} {return}
		if {[$this simulator_isWatchDogTimerRuning]} {
			$this simulator_startStopWatchDogTimer 0
		} else {
			$this simulator_startStopWatchDogTimer 1
		}
		simulator_evaluate_wtd_onoff_switch
	}

	## Validate content of watchdog prescaler entry box
	 # @parm String content - String to validate
	 # @return Bool - result
	public method watchdog_prescaler_validate {content} {
		# Validate content
		if {![string is xdigit $content]} {
			return 0
		}
		if {$content == {}} {
			set content 0
		}
		set dec_value [expr "0x$content"]
		if {$dec_value >= [$this simulator_getWatchDogPrescalerSize]} {
			return 0
		}

		# Synchronize with engine
		$this simulator_setWatchDogPrescalerValue $dec_value
		return 1
	}

	## Validate content of watchdog entry
	 # @parm String content - String to validate
	 # @return Bool - result
	public method watchdog_validate {content} {
		# Validate content
		if {![string is xdigit $content]} {
			return 0
		}
		if {$content == {}} {
			set content 0
		}
		set dec_value [expr "0x$content"]
		if {$dec_value > 8191} {
			return 0
		}

		# Adjust clear button
		catch {
			if {!$dec_value || !$sim_enabled} {
				$wtd_clear_button configure -state disabled
			} else {
				$wtd_clear_button configure -state normal
			}
		}

		# Adjust entry background color
		if {$dec_value < 7000} {
			$watchdog_entry configure -style Simulator_watchdogEntry_0.TEntry
		} elseif {$dec_value < 7500} {
			$watchdog_entry configure -style Simulator_watchdogEntry_1.TEntry
		} else {
			$watchdog_entry configure -style Simulator_watchdogEntry_2.TEntry
		}

		# Synchronize with engine
		$this simulator_setWatchDogTimer $dec_value
		return 1
	}

	## Validate content of an entry widget related to timer registers (TH0 TL0 TH1 TL1 T0 T1)
	 # @parm String registerName	- ID of the validated entry (one of {TH0 TL0 TH1 TL1 T0 T1})
	 # @parm String content		- New content of the entry
	 # @return Bool - result
	public method validate_Txx {registerName content} {
		if {$disable_validation} {return 1}

		# This function cannot run multithreaded
		if {$sync_Txx_in_progress} {
			return 1
		} else {
			set sync_Txx_in_progress 1
		}

		# Determinate content length and normalize content (empty string == 0)
		set content_len [string length $content]
		if {$content_len == 0} {
			set content 0
		}

		# Validation of T0, T1, T2 or RCAP2
		if {[lsearch {T0 T1 T2 RCAP2} $registerName] != -1} {
			# Check for maximal length (5 characters)
			if {$content_len > 5} {
				set sync_Txx_in_progress 0
				return 0
			}

			# Check for allowed characters (decimal digits)
			if {![string is digit $content]} {
				set sync_Txx_in_progress 0
				return 0
			}

			# Check for maximal value
			if {$content > 0xFFFF} {
				set sync_Txx_in_progress 0
				return 0
			}

			# Determinate hexadecimal representation of the given value
			set hex [NumSystem::dec2hex $content]
			set hex_len [string length $hex]
			if {$hex_len < 4} {
				set hex "[string repeat {0} [expr {4 - $hex_len}]]$hex"
			}
			set hex_h [string range $hex 0 1]
			set hex_l [string range $hex 2 3]

			# Synchronize with TH0 and TL0 and engine
			switch -- $registerName {
				{T0} {
					set regHigh	{TH0}
					set regLow	{TL0}
				}
				{T1} {
					set regHigh	{TH1}
					set regLow	{TL1}
				}
				{T2} {
					set regHigh	{TH2}
					set regLow	{TL2}
				}
				{RCAP2} {
					set regHigh	{RCAP2H}
					set regLow	{RCAP2L}
				}
			}

			# Fill THx and TLx entries
			set ::Simulator_GUI::ENV${obj_idx}_${regHigh} $hex_h
			set ::Simulator_GUI::ENV${obj_idx}_${regLow} $hex_l

			# Synchronize with engine
			if {!$disable_sync} {
				# THx
				set addr [symb_name_to_hex_addr $regHigh]
				help_window_update [list $addr {SFR}] $content
				set addr [expr "0x$addr"]
				set dec_val [expr "0x$hex_h"]
				$this setSfr $addr $hex_h
				$this sfr_watches_sync $addr $dec_val
				$this sfrmap_map_sync $addr $dec_val
				$this cvarsview_sync I $addr

				# TLx
				set addr [symb_name_to_hex_addr $regLow]
				help_window_update [list $addr {SFR}] $content
				set addr [expr "0x$addr"]
				set dec_val [expr "0x$hex_l"]
				$this setSfr $addr $hex_l
				$this sfr_watches_sync $addr $dec_val
				$this sfrmap_map_sync $addr $dec_val
				$this cvarsview_sync I $addr
			}

		# Validation of THx, TLx or RCAPxL, RCAPxH
		} else {
			# Check for corrent value
			if {![entry_2_hex_validate $content]} {
				set sync_Txx_in_progress 0
				return 0
			}

			## Determinate vaiable of Tx entry and low-order and high-order bytes of Tx
			 # TH0 or TL0
			if {$registerName == {TH0} || $registerName == {TL0}} {
				set hex_h [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_TH0"]
				set hex_l [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_TL0"]
				set target_var "::Simulator_GUI::ENV${obj_idx}_T0"
			 # TH1 or TL1
			} elseif {$registerName == {TH1} || $registerName == {TL1}} {
				set hex_h [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_TH1"]
				set hex_l [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_TL1"]
				set target_var "::Simulator_GUI::ENV${obj_idx}_T1"
			 # TH2 or TL2
			} elseif {$registerName == {TH2} || $registerName == {TL2}} {
				set hex_h [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_TH2"]
				set hex_l [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_TL2"]
				set target_var "::Simulator_GUI::ENV${obj_idx}_T2"
			 # RCAP2H or RCAP2L
			} elseif {$registerName == {RCAP2H} || $registerName == {RCAP2L}} {
				set hex_h [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_RCAP2H"]
				set hex_l [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_RCAP2L"]
				set target_var "::Simulator_GUI::ENV${obj_idx}_RCAP2"
			}

			# Overwrite low/high byte with the new content
			switch -- $registerName {
				{TH0}	{set hex_h $content}
				{TH1}	{set hex_h $content}
				{TH2}	{set hex_h $content}
				RCAP2H	{set hex_h $content}
				{TL0}	{set hex_l $content}
				{TL1}	{set hex_l $content}
				{TL2}	{set hex_l $content}
				RCAP2L	{set hex_l $content}
			}

			# Synchronize with engine
			if {!$disable_sync} {
				set addr [symb_name_to_hex_addr $registerName]
				help_window_update [list $addr {SFR}] $content
				set addr [expr "0x$addr"]
				set dec_val [expr "0x$content"]
				$this setSfr $addr $content
				$this sfr_watches_sync $addr $dec_val
				$this sfrmap_map_sync $addr $dec_val
				$this cvarsview_sync I $addr
			}

			# Normalize low-order value
			if {[string length $hex_l] == 1} {
				set hex_l "0$hex_l"
			}

			# Set Tx
			set $target_var [expr "0x${hex_h}${hex_l}"]
		}

		# Validation complete
		set sync_Txx_in_progress 0
		return 1
	}

	## Force bitmap register validation enable
	 # @return void
	public method simulator_force_bitmap_hex_validation_ena {} {
		set bitmap_hex_validation_ena 1
	}

	## Informs simulator UI about change of SMOD0 bit
	 # This function will then adjust content of register SCON to fit
	 # possibly new value of bit SCON.7 (FE/SM0)
	 # @return void
	public method simulator_gui_SMOD0_changed {} {
		set scon [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_SCON"]
		if {$scon == {}} {
			set scon 0
		}
		set scon [expr {"0x$scon" & 0x7F}]
		if {[$this get_SMOD0]} {
			if {[subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_SFR(FE)"]} {
				set scon [expr {$scon | 0x80}]
			}
		} else {
			if {[subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_SFR(SM0)"]} {
				set scon [expr {$scon | 0x80}]
			}
		}
		set scon [format %X $scon]
		if {[string length $scon] == 1} {
			set scon "0$scon"
		}
		set ::Simulator_GUI::ENV${obj_idx}_SCON $scon
		validate_hex_bitmap_reg $scon SCON
	}

	## Validate hexadecimal regiter entry with interconnected with a bitmap
	 # @parm String value		- Hexadeciaml value to validate
	 # @parm String registerName	- Register ID
	 # @return Bool - result
	public method validate_hex_bitmap_reg {value registerName} {
		# This function cannot run multithreaded
		if {$bitmap_hex_validation_ena} {
			set bitmap_hex_validation_ena 0
		} else {
			return 1
		}

		# Check for allowed length and normalize value (empty string == 0)
		set valueLen [string length $value]
		if {$valueLen == 0} {
			set value 0
		} elseif {$valueLen > 2} {
			set bitmap_hex_validation_ena 1
			return 0
		}
		# Check for allowed characters
		if {![regexp {^[0-9A-Fa-f]*$} $value]} {
			set bitmap_hex_validation_ena 1
			return 0
		}


		set bitList $bit_in_particular_regs($registerName)

		# Determinate list 8 bits of binary represenatation of the new content
		set bin [NumSystem::hex2bin $value]
		set bin_len [string length $bin]
		if {$bin_len < 8} {
			set bin "[string repeat {0} [expr {8 - $bin_len}]]$bin"
		}
		set bits [split $bin {}]

		# Adjust bit list for special registers
		switch -- $registerName {
			SCON {
				if {[$this get_SMOD0]} {
					lset bitList 0 FE
				} else {
					lset bitList 0 SM0
				}
			}
		}

		# Synchronize with register bitmap
		set i -1	;# Bit number
		foreach bitName $bitList {
			incr i

			# Skip empty bits
			if {$bitName == {-}} {continue}

			# Determinate bit label color
			set bitVal [lindex $bits $i]
			if {$bitVal} {
				set color $on_color
			} else {
				set color $off_color
			}

			# Set bit value and label color
			set ::Simulator_GUI::ENV${obj_idx}_SFR($bitName) $bitVal
			$Simulator_panel_parent._${registerName}_$bitName configure -fg $color
		}

		# Synchronize with Right panel and engine
		if {!$disable_sync} {
			set addr [symb_name_to_hex_addr $registerName]
			help_window_update [list $addr {SFR}] $value
			set addr [expr "0x$addr"]
			set dec_val [expr "0x$value"]
			$this setSfr $addr $value
			$this sfr_watches_sync $addr $dec_val
			$this sfrmap_map_sync $addr $dec_val
			$this cvarsview_sync I $addr
		}

		# Success
		set bitmap_hex_validation_ena 1
		return 1
	}

	## Create register bitmap
	 # @parm Widget parent	- parent GUI component	(some frame)
	 # @parm Int row	- Row in grid		(for geometry manager)
	 # @parm String name	- Register name		(for label)
	 # @parm List bit_list	- List of bit names
	 # @parm String hex_reg	- Has hexadecimal entry	(for procedure sim_invert)
	 # @parm List s_tips	- List of status bar tips for bit lables
	 # @parm String stip	- Status tip for regster label
	 # @parm List tooltips	- List of tooltips for each bit
	 # @return void
	private method create_bitmap_register {parent row name bit_list hex_reg s_tips stip tooltips}  {
		# Create register label
		grid [label $Simulator_panel_parent._${name}_l		\
			-text "[mc $name]:" -fg $name_color		\
			-anchor w -pady 0 -font $bitfont		\
		] -row $row -column 1 -in $parent -sticky w
		setStatusTip -widget $Simulator_panel_parent._${name}_l -text [mc $stip]

		set col		1	;# Bit label column (2..9)
		set bitNum	-1	;# Bit number (0..7)
		set Idx		0	;# Bit index (1..8)
		# Create bit map
		foreach bit $bit_list sTip $s_tips tooltip $tooltips {
			incr col
			incr bitNum

			# Handle empty bits
			if {$bit == {-}} {
				set color {#000000}
				incr Idx
				set idx $Idx
				set cursor {left_ptr}
			} else {
				set color $off_color
				set cursor {hand2}
				set idx {}
			}

			# Create bit label
			set label [label $Simulator_panel_parent._${name}_${bit}${idx}	\
				-text $bit -fg $color -cursor $cursor			\
				-bd 1 -font $bitfont -pady 0				\
			]
			setStatusTip -widget $label -text [mc $sTip]
			if {$bit != {-}} {
 				bind $label <Enter> {+%W configure -font $::Simulator_GUI::bitfont_under}
 				bind $label <Leave> {+%W configure -font $::Simulator_GUI::bitfont}
			}
			DynamicHelp::add $label -text [mc [subst $tooltip]]
			grid $label -row $row -column $col -in $parent

			# Skip registration of empty bits
			if {$bit == {-}} {continue}

			# Register bit label
			bind $label <Button-1> "$this sim_invert $bit $bitNum $name $hex_reg"
			bind $label <ButtonRelease-3> "$this bit_popup_menu $bit $bitNum $name $hex_reg %X %Y"
			set ::Simulator_GUI::ENV${obj_idx}_SFR($bit) 0
		}
	}

	## Invokes bit popup menu
	 # @parm String bit	- Bit name
	 # @parm Int bitNum	- Bit number
	 # @parm String name	- Register name
	 # @parm String hex_reg	- Register name for procedure sim_invert
	 # @parm Int X		- Horizontal position of the mouse pointer
	 # @parm Int X		- Vertical position of the mouse pointer
	 # @return void
	public method bit_popup_menu {bit bitNum name hex_reg X Y} {
		set bit_popup_menu_args [list $bit $bitNum $name $hex_reg]
		tk_popup $bitmenu $X $Y
	}

	## Procedure for bit popup menu -- set bit to $bool
	 # @parm Bool bool - New bit value
	 # @parm void
	public method bit_popup_menu_setto {bool} {
		if {!$sim_enabled} {return}
		if {$bool != [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_SFR([lindex $bit_popup_menu_args 0])"]} {
			eval "sim_invert $bit_popup_menu_args"
		}
	}

	## Validate content of Program Counter (PC) entry
	 # @parm String num_base	- Numeric base of the entry (one of {hex dec})
	 # @parm String content		- String to validate
	 # @return Bool - result
	public method sim_eval_PC {num_base content} {

		# This function cannot run multithreaded
		if {$sync_PC_in_progress} {
			return 1
		} else {
			set sync_PC_in_progress 1
		}

		# Determinate content length and normalize content (empty string == 0)
		set content_len [string length $content]
		if {$content_len == 0} {
			set content 0
		}

		# Validate and synchronize
		switch -- $num_base {
			{hex} {	;# From hexadecimal

				# Check for allowed length
				if {$content_len > 4} {
					set sync_PC_in_progress 0
					return 0
				}
				# Check for allowed characters
				if {![regexp {^[0-9A-Fa-f]*$} $content]} {
					set sync_PC_in_progress 0
					return 0
				}

				# Synchronize with decimal entry
				set dec [expr "0x$content"]
				set ::Simulator_GUI::ENV${obj_idx}_PC_dec $dec
			}
			{dec} {	;# From decimal

				# Check for allowed length
				if {$content_len > 5} {
					set sync_PC_in_progress 0
					return 0
				}
				# Check for allowed characters
				if {![regexp {^[0-9]*$} $content]} {
					set sync_PC_in_progress 0
					return 0
				} elseif {$content > 65535} {
					set sync_PC_in_progress 0
					return 0
				}

				# Synchronize with hexadecimal entry
				set hex [NumSystem::dec2hex $content]
				set hex_len [string length $hex]
				if {$hex_len < 4} {
					set hex "[string repeat {0} [expr {4 - $hex_len}]]$hex"
				}
				set ::Simulator_GUI::ENV${obj_idx}_PC_hex $hex

				# Determinate decimal representation
				set dec $content
			}
		}

		# Synchronize with engine
		if {!$disable_sync} {
			$this setPC $dec
			set lineNum [$this simulator_getCurrentLine]
			if {$lineNum != {}} {
				$this move_simulator_line $lineNum
			} else {
				$this editor_procedure {} unset_simulator_line {}
			}
		}

		# Success
		set sync_PC_in_progress 0
		return 1
	}

	## Validate content of P0..P3 hexadecimal/binary entry
	 # @parm String register	- Register ID (eg. 'P2')
	 # @parm String num_base	- Numberic base of the entry (one of {hex bin})
	 # @parm String content		- String to validate
	 # @return Bool - result
	public method sim_eval_Px {register num_base content} {

		# This function cannot run multithreaded
		if {$sync_Px_in_progress} {
			return 1
		} else {
			set sync_Px_in_progress 1
		}

		# If content is an empty string -> abort
		set content_len [string length $content]
		if {$content_len == 0} {
			set sync_Px_in_progress 0
			return 1
		}

		# Synchronize with the other register
		switch -- $num_base {
			{hex} {	;# With bin
				# Check for allowed length
				if {$content_len > 2} {
					set sync_Px_in_progress 0
					return 0
				}
				# Check for allowed characters
				if {![regexp {^[0-9A-Fa-f]*$} $content]} {
					set sync_Px_in_progress 0
					return 0
				}

				# Determinate binary representation
				set bin [NumSystem::hex2bin $content]
				set bin_len [string length $bin]
				if {$bin_len < 8} {
					set bin "[string repeat {0} [expr {8 - $bin_len}]]$bin"
				}

				# Synchronize
				set ::Simulator_GUI::ENV${obj_idx}_${register}_bin $bin
				set hex $content
			}
			{bin} {	;# With hex
				# Check for allowed length
				if {$content_len > 8} {
					set sync_Px_in_progress 0
					return 0
				}
				# Check for allowed characters
				if {![regexp {^[01]*$} $content]} {
					set sync_Px_in_progress 0
					return 0
				}

				# Determinate hexadecimal representation
				set hex [NumSystem::bin2hex $content]
				if {[string length $hex] == 1} {
					set hex "0$hex"
				}

				# Synchronize
				set ::Simulator_GUI::ENV${obj_idx}_${register} $hex
			}
		}

		# Syncronize with right panel and engine
		if {!$disable_sync} {
			set addr [symb_name_to_hex_addr $register]
			help_window_update [list $addr {SFR}] $hex
			set addr [expr "0x$addr"]
			set dec_val [expr "0x$hex"]
			$this setSfr $addr $hex
			$this sfr_watches_sync $addr $dec_val
			$this sfrmap_map_sync $addr $dec_val
			$this cvarsview_sync I $addr
		}

		# Successfull
		set sync_Px_in_progress 0
		return 1
	}

	## Validate content of some entry widget of A or B register
	 # @parm String register	- Register ID ('A' or 'B')
	 # @parm String num_base	- Numberic base (one of {hex dec bin oct char})
	 # @parm String content		- String to validate
	 # @return Bool - result
	public method sim_eval_AB {register num_base content} {
		if {$disable_validation} {return 1}

		# This function cannot run multithreaded
		if {$sync_AB_in_progress} {
			return 1
		} else {
			set sync_AB_in_progress 1
		}

		# If empty string -> abort
		if {[string length $content] == 0} {
			set sync_AB_in_progress 0
			return 1
		}

		# Determinate maximum length according to numeric base
		switch -- $num_base {
			{hex}	{set max_len 2}
			{dec}	{set max_len 3}
			{bin}	{set max_len 8}
			{oct}	{set max_len 3}
			{char}	{set max_len 1}
			default	{
				set sync_AB_in_progress 0
				return 0
			}
		}

		#  Check for allowed length
		if {[string bytelength $content] > $max_len} {
			set sync_AB_in_progress 0
			return 0
		}

		# Check for allowed characters and determinate binary representation
		switch -- $num_base {
			{hex} {
				# Check for allowed characters
				set content [string toupper $content]
				if {![regexp {^[0-9A-Fa-f]*$} $content]} {
					set sync_AB_in_progress 0
					return 0
				}
				# Determinate binary representation
				set bin [NumSystem::hex2bin $content]
			}
			{dec} {
				# Check for allowed characters
				if {![regexp {^[0-9]*$} $content]} {
					set sync_AB_in_progress 0
					return 0
				}
				# Determinate binary representation
   				set bin [NumSystem::dec2bin $content]
			}
			{bin} {
				# Check for allowed characters
				if {![regexp {^[01]*$} $content]} {
					set sync_AB_in_progress 0
					return 0
				}
				set bin $content
			}
			{oct} {
				# Check for allowed characters
				if {![regexp {^[0-7]*$} $content]} {
					set sync_AB_in_progress 0
					return 0
				}
				# Determinate binary representation
				set bin [NumSystem::oct2bin $content]
			}
			{char} {
				# Determinate binary representation
				set bin [NumSystem::ascii2bin $content]
				if {$bin == {}} {
					set sync_AB_in_progress 0
					return 0
				}
			}
		}

		# Determinate other numerical representations
		set hex [NumSystem::bin2hex $bin]
		set dec [NumSystem::bin2dec $bin]
		set oct [NumSystem::bin2oct $bin]

		# Check for allowed range
		if {$dec > 255 || $dec < 0} {
			set sync_AB_in_progress 0
			return 0
		}

		# Normalize binary value
		set bin_len [string length $bin]
		if {$bin_len < 8} {
			set bin "[string repeat {0} [expr {8 - $bin_len}]]$bin"
		}
		# Determinate character representation
		if {$dec > 31 && $dec < 127} {
			set char [subst -nocommands "\\u00$hex"]
		} else {
			set char {}
		}

		# Synchronize with other entries
		foreach base {hex dec bin oct char} {
			if {$base == $num_base} {continue}
			set ::Simulator_GUI::ENV${obj_idx}_${register}_$base [subst -nocommands "\$$base"]
		}

		# Synchronize with Right panel and Engine
		if {!$disable_sync} {
			# Register A
			if {$register == {A}} {
				$this setSfr 224 $hex
				set dec_val [expr "0x$hex"]
				$this sfr_watches_sync 224 $dec_val
				$this sfrmap_map_sync 224 $dec_val
			# Register B
			} else {
				$this setSfr 240 $hex
				set dec_val [expr "0x$hex"]
				$this sfr_watches_sync 240 $dec_val
				$this sfrmap_map_sync 240 $dec_val
			}
		}

		# Successful ...
		set sync_AB_in_progress 0
		return 1
	}

	## Create help window for active bank registers (R0..R7)
	 # @parm Int R_index - number of the register (0..7)
	 # @return void
	public method create_help_window_Rx {R_index} {
		# Determinate true register address (decimal)
		set RS0 [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_SFR(RS0)"]
		set RS1 [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_SFR(RS1)"]
		if {$RS0} {incr R_index 8}
		if {$RS1} {incr R_index 16}

		# Create help window
		create_help_window_ram $R_index
	}

	## Set value for the given bit in the given register
	 # This function bypasses connection to register which the bit belongs to
	 # @parm Bool bool	- New bit value
	 # @parm String reg	- Bit register (register name not address)
	 # @parm String bit	- Bit name (not address)
	 # @return void
	public method sim_GUI_bit_set_clear {bool reg bit} {
		if {!$sim_gui_gui_initialized} {return}

		if {$bool} {
			$Simulator_panel_parent._${reg}_${bit} configure -fg $on_color
		} else {
			$Simulator_panel_parent._${reg}_${bit} configure -fg $off_color
		}
	}

	## Invert bit in register bitmap
	 # @parm String bitName		- Bit name	(eg. 'EA')
	 # @parm Int bitNumber		- Bit number	(eg. '7')
	 # @parm String registerName	- Register name	(eg. 'IE')
	 # @parm Bool hex_reg		- Bitmap is connected to hexadecimal entry
	 # @return void
	public method sim_invert {bitName bitNumber registerName hex_reg} {
		if {!$sim_gui_gui_initialized} {return}
		set decVal_increment 0

		# Simulator must be engaged
		if {!$sim_enabled} {return}

		# Determinate bit boolean value
		set bitBoolVal [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_SFR($bitName)"]

		# Determinate bit decimal and hexadecimal value
		set addr [symb_name_to_hex_addr $registerName]
		set addr [expr "0x$addr"]
		set decVal 0
		set bitDecVal 0
		set bitmap_hex_validation_ena 0
		if {$hex_reg} {
			set decVal [expr "0x[subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_${registerName}"]"]
		} else {
			set decVal [$this getSfrDEC $addr]
		}
		switch -- $bitNumber {
			7	{set bitDecVal 1}
			6	{set bitDecVal 2}
			5	{set bitDecVal 4}
			4	{set bitDecVal 8}
			3	{set bitDecVal 16}
			2	{set bitDecVal 32}
			1	{set bitDecVal 64}
			0	{set bitDecVal 128}
		}

		# Change label color and decimal value
		if {$bitBoolVal} {
			$Simulator_panel_parent._${registerName}_$bitName configure -fg $off_color
			set decVal_increment -$bitDecVal
		} else {
			$Simulator_panel_parent._${registerName}_$bitName configure -fg $on_color
			set decVal_increment $bitDecVal
		}

		# Handle very special bits
		switch -- $bitName {
			FE {
				if {![$this get_SMOD0]} {
					set decVal_increment 0
					$this sim_engine_set_FE [expr {!$bitBoolVal}]
				}
			}
			SM0 {
				if {[$this get_SMOD0]} {
					set decVal_increment 0
					$this sim_engine_set_SM0 [expr {!$bitBoolVal}]
				}
			}
		}
		incr decVal $decVal_increment

		# Set new bit value
		set ::Simulator_GUI::ENV${obj_idx}_SFR($bitName) [expr {!$bitBoolVal}]

		## Synchronize
		set hexVal [format %X $decVal]
		if {[string length $hexVal] == 1} {
			set hexVal "0$hexVal"
		}
		 #  With hexadecimal entry
		if {$hex_reg} {
			set ::Simulator_GUI::ENV${obj_idx}_${registerName} $hexVal
		}
		 #  With Right panel and Engine
		if {!$disable_sync} {
			$this setSfr $addr $hexVal
			$this Simulator_sync_sfr $addr
		}
		set bitmap_hex_validation_ena 1

		# If the bit is one of {RS0 RS1} -> change current register bank
		if {$bitName == {RS0} || $bitName == {RS1}} {
			sim_switch_bank
		}
	}

	## Translate register symbolic name to hexadecimal address
	 # @parm String regName - Register name (eg. 'PSW')
	 # @return String - hexadecimal address (eg. 'D0') or void
	public method symb_name_to_hex_addr {regName} {
		switch -- $regName {
			{A_hex}	{return E0}
			{B_hex}	{return F0}
			{A}	{return E0}
			{B}	{return F0}
			{P0}	{return 80}
			{P1}	{return 90}
			{P2}	{return A0}
			{P3}	{return B0}
			{P4}	{return C0}
			{DPH}	{return 83}
			{DPL}	{return 82}
			{DP1H}	{return 85}
			{DP1L}	{return 84}
			{SBUFR}	{return 99}
			{SBUFT}	{return 199}
			{SCON}	{return 98}
			{TH1}	{return 8D}
			{TL1}	{return 8B}
			{TH0}	{return 8C}
			{TL0}	{return 8A}
			{TCON}	{return 88}
			{TMOD}	{return 89}
			{PCON}	{return 87}
			{IE}	{return A8}
			{IP}	{return B8}
			{SP}	{return 81}
			{PSW}	{return D0}
			{Acc}	{return E0}
			{T2CON}	{return C8}
			{T2MOD}	{return C9}
			RCAP2L	{return CA}
			RCAP2H	{return CB}
			{TL2}	{return CC}
			{TH2}	{return CD}
			{AUXR1}	{return A2}
			WDTRST	{return A6}
			{AUXR}	{return 8E}
			CLKREG	{return 8F}
			CKCON	{return 8F}
			ACSR	{return 97}
			IPH	{return B7}
			SADDR	{return A9}
			SADEN	{return B9}
			SPCR	{return D5}
			SPSR	{return AA}
			SPDR	{return 86}
			WDTCON	{return A7}
			WDTPRG	{return A7}
			EECON	{return 96}
		}
	}

	## Translate hexadecimal address to register symbolic name
	 # @parm String regName - Register hexadecimal address (eg. '8C')
	 # @return String - Register name (eg. 'TH0') or void
	public method to_hex_addr_symb_name {hex} {
		switch -- $hex {
			{E0}	{return A_hex}
			{F0}	{return B_hex}
			{E0}	{return A}
			{F0}	{return B}
			{80}	{return P0}
			{90}	{return P1}
			{A0}	{return P2}
			{B0}	{return P3}
			{C0}	{return P4}
			{83}	{return DPH}
			{82}	{return DPL}
			{85}	{return DP1H}
			{84}	{return DP1L}
			{99}	{return SBUFR}
			{199}	{return SBUFT}
			{98}	{return SCON}
			{8D}	{return TH1}
			{8C}	{return TH0}
			{8B}	{return TL1}
			{8A}	{return TL0}
			{89}	{return TMOD}
			{88}	{return TCON}
			{87}	{return PCON}
			{A8}	{return IE}
			{B8}	{return IP}
			{81}	{return SP}
			{D0}	{return PSW}
			{E0}	{return Acc}
			{C8}	{return T2CON}
			{C9}	{return T2MOD}
			{CA}	{return RCAP2L}
			{CB}	{return RCAP2H}
			{CC}	{return TL2}
			{CD}	{return TH2}
			{A2}	{return AUXR1}
			{A6}	{return WDTRST}
			{8E}	{return AUXR}
			{97}	{return ACSR}
			{B7}	{return IPH}
			{A9}	{return SADDR}
			{B9}	{return SADEN}
			{D5}	{return SPCR}
			{AA}	{return SPSR}
			{86}	{return SPDR}
			{96}	{return EECON}
			{8F}	{
				if {[$this get_feature_available ckcon]} {
					return {CKCON}
				} else {
					return {CLKREG}
				}
			}
			{A7}	{
				if {[$this get_feature_available wdtcon]} {
					return {WDTCON}
				} else {
					return {WDTPRG}
				}
			}
		}
	}

	## Switch active register bank (Current bank number is based on bits SFR(RS0) SFR(RS1))
	 # @return void
	public method sim_switch_bank {} {
		if {!$sim_gui_gui_initialized} {return}

		# Determinate bank offset
		set bnk [$this getBank]
		set index [expr {$bnk * 8}]

		# Synchronize active bank register entries
		for {set i 0} {$i < 8} {incr i} {
			set value [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_DATA([expr {$index + $i}])"]
			set ::Simulator_GUI::ENV${obj_idx}_R$i $value
		}
	}

	## Validate content of R0..R7 entry
	 # @parm String number	- String to validate
	 # @parm Int idx	- Register index
	 # @return Bool - result
	public method entry_Rx_validate {number idx} {

		# Check for enabled validations
		if {$disable_validation} {return 1}

		# This function cannot run multithreaded
		if {!$Rx_validation_ena} {return 1}
		set Rx_validation_ena 0

		# Validate entry content
		set result [entry_2_hex_validate $number]
		# Synchronize
		if {$result} {
			# Determinate address
			if {$number == {}} {set number 0}
			set bnk [$this getBank]
			incr idx [expr {$bnk * 8}]

			# Synchronize with low RAM
			set ::Simulator_GUI::ENV${obj_idx}_DATA($idx) $number
			$hexeditor setValue $idx [expr "0x$number"]
			$this setData $idx $number

			# Update help window
			set hex_addr [format "%X" $idx]
			if {[string length $hex_addr] == 1} {
				set hex_addr "0$hex_addr"
			}
			$this rightPanel_watch_sync $hex_addr
			help_window_update $hex_addr $number
			$this cvarsview_sync E $idx
		}

		# Successul ...
		set Rx_validation_ena 1
		return $result
	}

	## Validate and synchronize SFR entry
	 # @parm String number	- String to validate
	 # @parm String reg	- Register name (eg. 'PSW')
	 # @return Bool - result
	public method entry_2_hex_validate_and_sync {number reg} {
		# Validate
		set result [entry_2_hex_validate $number]
		# Synchronize
		if {$result && [string length $number] && !$disable_sync} {
			set hex_addr [symb_name_to_hex_addr $reg]
			set dec_addr [expr "0x$hex_addr"]
			$this setSfr $dec_addr $number
			set dec_val [expr "0x$number"]
			$this sfr_watches_sync $dec_addr $dec_val
			$this sfrmap_map_sync $dec_addr $dec_val
			help_window_update [list $hex_addr {SFR}] $number
			$this cvarsview_sync I $dec_addr
		}
		# Done ...
		return $result
	}

	## Synchronize content low ram register entry 0..31 (first four banks)
	 # @parm Int addr	- Register address
	 # @parm String number	- String to validate
	 # @return Bool - result
	private method entry_bank_reg_sync {addr number} {
		# Check for enabled validations
		if {$disable_validation} {return 1}

		if {!$Rx_validation_ena} {
			if {!$disable_sync} {
				$this setData $addr $number
				$this rightPanel_watch_sync [format "%X" $addr]
			}
			return 1
		}
		set Rx_validation_ena 0

		# Synchronize with Rx
		if {$number == {}} {set number 0}
		set bnk [expr {$addr / 8}]
		set idx [expr {$addr % 8}]
		if {$bnk == [$this getBank]} {
			set ::Simulator_GUI::ENV${obj_idx}_R${idx} $number
		}

		# Synchronize with Right panel and Engine
		if {!$disable_sync} {
			$this setData $addr $number
			set hex_addr [format "%X" $addr]
			if {[string length $hex_addr] == 1} {
				set hex_addr "0$hex_addr"
			}
			$this rightPanel_watch_sync $hex_addr
			$this stack_monitor_sync $addr
			help_window_update $hex_addr $number
			$this cvarsview_sync E $addr
		}

		# Done
		set Rx_validation_ena 1
		return 1
	}

	## Synchronize content of entry in hex view of low RAM (addr: 0x20..0x7F)
	 # @parm Int addr	- Register adddress (32..127)
	 # @parm String number	- String to validate
	 # @return Bool - result
	public method entry_idata_reg_sync {addr number} {
		# Check for enabled validations
		if {$disable_validation} {return 1}

		# Synchronize with engine (and other)
		if {!$disable_sync} {
			# Synchronize with engine
			$this setData $addr $number
			# Determinate hexadecimal representation of the content
			set hex_addr [format "%X" $addr]
			if {[string length $hex_addr] == 1} {
				set hex_addr "0$hex_addr"
			}
			# Synchronize with the Right Panel
			$this Simulator_sync_reg $addr
		}

		return 1
	}

	## Validate content of general hexadecimal entry for 2 digits
	 # @parm String number - string to validate
	 # @return Bool - result
	proc entry_2_hex_validate {number} {
		if {[string length $number] > 2} {return 0}
		if {[regexp {^[0-9A-Fa-f]*$} $number]} {return 1}
		return 0
	}

	## Create RAM help window
	 # @parm String addr -
	 #	XXh (hexadecimal eg. A5h) -
	 #		4 digits == XDATA
	 #		3 digits == EDATA
	 #		2 digits == IDATA (not SFR)
	 #		Dot and 2 digits == Bit in IDATA or SFR
	 #	DD (decimal eg. 224)	- IDATA memory only
	 #	SSS (string eg. PSW)	- SFR only
	 # @return void
	public method create_help_window_ram args {
		set addr [lindex $args 0]	;# Register address

		catch {destroy ${::HELPWINDOW}}
		set ::HELPWINDOW {}

		## Hexadecimal address
		 # 4 digits == XDATA; 3 digits == EDATA; 2 digits == IDATA (not SFR)
		if {[regexp {^[A-Fa-f0-9]+h$} $addr]} {
			# Determinate address
			set addr [string range $addr 0 {end-1}]
			set addr_dec [expr "0x$addr"]
			# Determinate value
			set len [string length $addr]
			if {$len < 3} {
				if {![$this simulator_address_range I $addr_dec]} {return}
				set val [$this getData $addr_dec]
			} elseif {$len == 3} {
				if {![$this simulator_address_range E $addr_dec]} {return}
				set val [$this getEram $addr_dec]
			} else {
				if {![$this simulator_address_range X $addr_dec]} {return}
				set val [$this getXdata $addr_dec]
			}

		# Decimal address (IDATA memory only)
		} elseif {[string is digit $addr]} {
			# Determinate value
			set val [$this getData $addr]
			# Determinate address
			if {![$this simulator_address_range I $addr]} {return}
			set addr [format "%X" $addr]
			if {[string length $addr] == 1} {
				set addr "0$addr"
			}

		# Bit
		} elseif {[string index $addr 0] == {.}} {
			set addr [string replace $addr end end]
			set addr [string replace $addr 0 0]
			set val [$this getBit [expr {"0x$addr"}]]
			append addr { BIT}

		# Register name (SFR only)
		} else {
			set val [subst -nocommands "\$::Simulator_GUI::ENV${obj_idx}_$addr"]
			set addr [symb_name_to_hex_addr $addr]
			append addr { SFR}
		}

		# Create help window
		create_help_window . $val $addr
	}

	## Validate content of clock entry (frequency in kHz)
	 # @parm String number - string to validate
	 # @return Bool - result
	public method clock_validate {number} {
		# Check for allowed characters
		if {$number == {}} {
			set number 0
		} elseif {![regexp {^\d+(\.\d*)?$} $number]} {
			return 0
		}
		set number [string trimright $number {.}]

		# Check for allowed range
		if {$number > 99999} {
			return 0
		}

		# Synchronize
		$this configure -P_option_clock $number	;# Project variable
		$this setEngineClock $number		;# Set clock in simulator engine
		$this Simulator_sync_clock		;# Rewrite time entry

		# Done ...
		return 1
	}

	## Call haxeditor with the given arguments
	 # @parm String args - any arguments
	 # @return void
	public method simulator_hexeditor {args} {
		if {!$sim_gui_gui_initialized} {return}
		eval "$hexeditor $args"
	}

	## Binding for event CellValueChanged in hex editor
	 # @parm Int address	- Address of changed cell
	 # @parm Int value	- New cell value
	 # @return void
	public method simulator_hexedit_value_changed {address value} {
		# Convert value to hexadecimal representation
		set value [format %X $value]
		if {[string length $value] == 1} {
			set value "0$value"
		}

		# Synchronize
		if {$address < 32} {
			set ::Simulator_GUI::ENV${obj_idx}_DATA($address) $value
			entry_bank_reg_sync $address $value
		} else {
			entry_idata_reg_sync $address $value
		}
	}

	## Adjust scrollbar for scrollable area (simulator panel)
	 # @parm Char orient	- Scrollbar orientation (one of {x y})
	 # @parm Float frac0	- 1st fraction
	 # @parm Float frac0	- 2nd fraction
	 # @return void
	public method simulator_gui_scroll_set {orient frac0 frac1} {
		if {$orient == {x}} {
			set scrollbar	$horizontal_scrollbar
		} else {
			set scrollbar	$vertical_scrollbar
		}

		# Hide scrollbar
		if {$frac0 == 0 && $frac1 == 1} {
			if {[winfo ismapped $scrollbar]} {
				pack forget $scrollbar
				update
			}
		# Show scrollbar
		} else {
			if {![winfo ismapped $scrollbar]} {
				if {$orient == {x}} {
					pack $scrollbar -fill x -side top -before $scrollable_frame
				} else {
					pack $scrollbar -fill y -side left
				}
			}
			$scrollbar set $frac0 $frac1
			update
		}
	}

	## Unset NS variables
	 # @return void
	public method SimGUI_clean_up {} {
		foreach var $entry_variables {
			catch {
				unset ::Simulator_GUI::ENV${obj_idx}_${var}
			}
		}
		if {$sim_gui_gui_initialized} {
			menu_Sbar_remove $bitmenu
		}
	}

	## Disable synchronization with simulator engine
	 # @return void
	public method SimGUI_disable_sync {} {
		set disable_sync 1
	}

	## Enable synchronization with simulator engine
	 # @return void
	public method SimGUI_enable_sync {} {
		set disable_sync 0
	}

	## Change image on button "Step over" (from "Pause" to "Goto" or backwards)
	 # @return void
	public method invert_stepover_button {} {
		if {!$sim_gui_gui_initialized || !$sim_enabled} {return}

		# Determinate ID of the current image
		set image [$ctrl_f.controls_quick_step cget -image]
		# Change image
		if {$image == {::ICONS::16::goto2}} {
			$ctrl_f.controls_quick_step configure -image ::ICONS::16::player_pause
		} else {
			$ctrl_f.controls_quick_step configure -image ::ICONS::16::goto2
		}
	}

	## Change image on button "Animate" (from "Pause" to "Right arrow" or backwards)
	 # @return void
	public method invert_animate_button {} {
		if {!$sim_gui_gui_initialized || !$sim_enabled} {return}

		# Determinate ID of the current image
		set image [$ctrl_f.controls_animate cget -image]
		# Change image
		if {$image == {::ICONS::16::1rightarrow}} {
			$ctrl_f.controls_animate configure -image ::ICONS::16::player_pause
		} else {
			$ctrl_f.controls_animate configure -image ::ICONS::16::1rightarrow
		}
	}

	## Change image on button "Run" (from "Pause" to "Double right arrow" or backwards)
	 # @return void
	public method invert_run_button {} {
		if {!$sim_gui_gui_initialized || !$sim_enabled} {return}

		# Determinate ID of the current image
		set image [$ctrl_f.controls_run cget -image]
		# Change image
		if {$image == {::ICONS::16::2rightarrow}} {
			$ctrl_f.controls_run configure -image ::ICONS::16::player_pause
		} else {
			$ctrl_f.controls_run configure -image ::ICONS::16::2rightarrow
		}
	}

	## Set state of button "StepBack" on simulator control panel
	 # @return void
	public method stepback_button_set_ena {bool} {
		if {!$sim_gui_gui_initialized} {return}

		if {$bool} {
			set state {normal}
		} else {
			set state {disabled}
		}
		$ctrl_f.controls_stepback configure -state $state
	}

	## Disable simulator control panel (shoud be called after simulator engine disengagement)
	 # @return void
	public method sim_disable {} {
		if {!$sim_gui_gui_initialized} {return}

		set sim_enabled 0	;# Clear enabled flag

		# Set icon bar to default state
		$ctrl_f.controls_start_stop	configure -image ::ICONS::16::launch
		$ctrl_f.controls_run		configure -image ::ICONS::16::2rightarrow
		$ctrl_f.controls_animate	configure -image ::ICONS::16::1rightarrow
		$ctrl_f.controls_quick_step	configure -image ::ICONS::16::goto2
		$ctrl_f.controls_reset		configure -state disabled
		$ctrl_f.controls_stepback	configure -state disabled
		$ctrl_f.controls_step		configure -state disabled
		$ctrl_f.controls_quick_step	configure -state disabled
		$ctrl_f.controls_animate	configure -state disabled
		$ctrl_f.controls_run		configure -state disabled

		# Disable all register entries
		foreach wdg $entries {
			$wdg configure -state readonly
		}
		# Disable hex editor
		$hexeditor setDisabled 1

		# Disable wathdog clear button
		if {[winfo exists $wtd_clear_button]} {
			$wtd_clear_button configure -state disabled
		}

		$set_pc_by_line_button configure -state disabled

		# Disable bit popup menu
		$bitmenu entryconfigure [::mc "Set to 1"] -state disabled
		$bitmenu entryconfigure [::mc "Set to 0"] -state disabled
	}

	## Enable simulator control panel (shoud be called after simulator engine engagement)
	 # @return void
	public method sim_enable {} {
		if {!$sim_gui_gui_initialized} {CreateSimulatorGUI}

		set sim_enabled 1	;# Set enabled flag

		# Set icon bar to enabled state
		$ctrl_f.controls_start_stop	configure -image ::ICONS::16::exit
		$ctrl_f.controls_reset		configure -state normal
		$ctrl_f.controls_step		configure -state normal
		$ctrl_f.controls_quick_step	configure -state normal
		$ctrl_f.controls_animate	configure -state normal
		$ctrl_f.controls_run		configure -state normal

		# Enable all register entries
		foreach wdg $entries {
			$wdg configure -state normal
		}
		# Enable hex editor
		$hexeditor setDisabled 0
		$hexeditor focus_left_view

		$set_pc_by_line_button configure -state normal

		# Enable bit popup menu
		$bitmenu entryconfigure [::mc "Set to 1"] -state normal
		$bitmenu entryconfigure [::mc "Set to 0"] -state normal
	}

	## Add entry widget to list of entries which need to be disabled when simulator engine is down
	 # @parm Widget widget - entry to add
	 # @return void
	private method add_entry {widget} {
		lappend entries $widget
	}

	## Text output command for simulator engine
	 # @parm String text - text to display
	 # @return void
	public method sim_txt_output {txt} {
		tk_messageBox		\
			-parent .	\
			-icon info	\
			-type ok	\
			-message $txt	\
			-title [mc "Simulator"]
	}

	## Focus on the given target entry widget if the current insertion index is equivalent to the end index
	 # @parm Widget this_entry	- Current entry widget
	 # @parm Widget target_entry	- Target entry widget
	 # @return void
	proc sim_entry_right {this_entry target_entry} {
		# Evaluate cursor position
		if {[$this_entry index end] != [$this_entry index insert]} {
			return
		}
		# Focus on target
		$target_entry icursor 0
		focus $target_entry
	}

	## Focus on the given target entry widget if the current insertion index is equivalent to zero
	 # @parm Widget this_entry	- Current entry widget
	 # @parm Widget target_entry	- Target entry widget
	 # @return void
	proc sim_entry_left {this_entry target_entry} {
		# Evaluate cursor position
		if {[$this_entry index insert] != 0} {return}
		# Focus on target
		$target_entry icursor end
		focus $target_entry
	}

	## Get list of available SFRs
	 # @return List - {{dec_addr reg_name} ...}
	public method simulator_get_sfrs {} {
		if {!$sim_gui_gui_initialized} {CreateSimulatorGUI}
		return $sf_registers
	}

	## Highlight SFR label
	 # @parm Int index	- Index in $sf_registers and $sf_register_labels
	 # @parm Bool bool	- 1 == Highlight; 0 == Clear highlight
	 # @return void
	public method simulator_reg_label_set_highlighted {index bool} {
		# Determinate label widget
		incr index -1
		set widget [lindex $sf_register_labels $index]
		if {$widget == {}} {
			return
		}

		# Determinate new foreground and background color
		if {$bool} {
			if {[$widget cget -font] == $smallfont} {
				set bg $small_color
			} else {
				set bg $name_color
			}
			set fg {#FFFFFF}
		} else {
			set bg ${::COMMON_BG_COLOR}
			if {[$widget cget -font] == $smallfont} {
				set fg $small_color
			} else {
				set fg $name_color
			}
		}

		# Set new background and foreground color
		$widget configure -bg $bg -fg $fg
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

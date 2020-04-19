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
#    MERCHANTABILITY or FITNESS FOR A PARTMCULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program; if not, write to the                         #
#    Free Software Foundation, Inc.,                                       #
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################

# >>> File inclusion guard
if { ! [ info exists _SPECCALC_TCL ] } {
set _SPECCALC_TCL _
# <<< File inclusion guard


# --------------------------------------------------------------------------
# DESCRIPTION
# Special calculator for computaions related to 8051 microcontroller
# Functions:
#	* Timers preset (0, 1, 2)
#	* SPI
#	* Wait loops (code generation)
# --------------------------------------------------------------------------

class SpecCalc {
	## COMMON
	public common count		0	;# Int: Counter of class instances
	public common diagram_counter	0	;# Int: Counter of diagram dialogues instances
	 # List of pages descriptors for PagesManager
	public common page_list {
		loops timer01 timer2 spi
	}
	 # Configuration list
	public common config		$::CONFIG(SPEC_CALC)

	## PRIVATE
	private variable win			;# Widget: The dialog window
	private variable obj_idx		;# Int: Object index
	private variable pages_manager		;# Widget: PagesManager
	private variable pages			;# Array of Widget: Pages in the PagesManager
	private variable buttons		;# Array of Widget: Buttons to switch between pages
	private variable widgets		;# Array of Widget: Widgets present in separate pages
	private variable page_created		;# Array of Bool: Page GUI created

	private variable status_bar		;# Widget: Left status bar (main)
	private variable status_bar2		;# Widget: Right status bar (complementary)

	private variable calc_in_progress 0	;# Bool: Calculation in progress

	private variable active_page		;# String: ID of currently active page

	## Object constructor
	constructor {} {
		incr count
		set obj_idx $count

		# Configure ttk styles
		ttk::style configure SpecCalc_RedBg.TCombobox -fieldbackground {#FFCCCC}

		ttk::style configure SpecCalc_Flat.TButton -background {#FFFFFF} -padding 0 -borderwidth 1 -relief flat
		ttk::style map SpecCalc_Flat.TButton -relief [list active raised] -background [list disabled ${::COMMON_BG_COLOR} active {#EEEEFF}]

		ttk::style configure SpecCalc_Spec.TButton -background {#CCCCFF} -padding 0
		ttk::style map SpecCalc_Spec.TButton -background [list disabled ${::COMMON_BG_COLOR} active {#DDDDFF}]

		create_gui
	}

	## Object destructor
	destructor {
		# Hide dialog window
		wm withdraw $win
		update

		# Create configuration list
		set config [list						\
			[list	[$widgets(loops,time_ent) get]			\
				[$widgets(loops,time_cb) current]		\
				[$widgets(loops,clock_cb) get]			\
				[$widgets(loops,clock_type_cb) current]		\
				[$widgets(loops,reg_ent0) get]			\
				[$widgets(loops,reg_ent1) get]			\
				[$widgets(loops,reg_ent2) get]			\
				[$widgets(loops,reg_ent3) get]			\
				[$widgets(loops,reg_ent4) get]			\
				[$widgets(loops,reg_ent5) get]			\
				[$widgets(loops,reg_ent6) get]			\
				[$widgets(loops,reg_ent7) get]			\
			] [list							\
				[$widgets(timer01,time_ent) get]		\
				[$widgets(timer01,time_cb) current]		\
				[$widgets(timer01,clock_cb) get]		\
				[$widgets(timer01,clock_type_cb) current]	\
				[$widgets(timer01,mode_cb) current]		\
				[$widgets(timer01,psc_cb) current]		\
				[subst -nocommands "\${::SpecCalc::spec_chb_$obj_idx}"]	\
			] [list							\
				[$widgets(timer2,time_ent) get]			\
				[$widgets(timer2,time_cb) current]		\
				[$widgets(timer2,clock_cb) get]			\
				[$widgets(timer2,clock_type_cb) current]	\
				[$widgets(timer2,mode_cb) current]		\

			] [list							\
				[subst -nocommands "\$::SpecCalc::timer2_clk_fosc_$obj_idx"]	\
				[subst -nocommands "\$::SpecCalc::timer2_clk_freq_$obj_idx"]	\
				[subst -nocommands "\$::SpecCalc::timer2_clk_x2_$obj_idx"]	\
			] [list							\
				[wm geometry $win]				\
				$active_page					\
			] [list							\
				[subst -nocommands "\${::SpecCalc::double_chb_$obj_idx}"]	\
				[$widgets(spi,sck_ent00) get]			\
			]
		]

		# Destroy dialog window
		destroy $win
	}

	## Set status bar tip for certain widget
	 # @parm Widget widget	- Some button or label ...
	 # @parm String text	- Status tip
	 # @return void
	private method set_status_tip {widget text} {
		bind $widget <Enter> "$status_bar configure -fg black -text {$text}"
		bind $widget <Leave> "$status_bar configure -text {}"
	}

	## Show certain text on the right status bar for 10 seconds
	 # @parm String text - Text to display
	 # @return void
	public method status_tip {text} {
		$status_bar2 configure -text $text -fg red
		after 10000 "catch {$status_bar2 configure -text {} -fg black}"
	}

	## Create dialog GUI
	 # @return void
	private method create_gui {} {
		# Create dialog window and the main frame
		set win [toplevel .spec_calc$count -class [mc "Special Calculator - MCU 8051 IDE"] -bg ${::COMMON_BG_COLOR}]
		set main_frame [frame $win.main_frame]

		# Create status bar
		set sbar_frame [frame $win.sbar_frame]
		set status_bar [label $sbar_frame.status_bar	\
			-justify left -anchor w -padx 5		\
		]
		# Create status bar
		set status_bar2 [label $sbar_frame.status_bar2	\
			-justify right -anchor w -padx 5	\
		]

		# Create left frame
		set left_frame [frame $main_frame.left_frame -bg white]
		create_left_frame $left_frame
		pack $left_frame -side left -fill y

		# Create separator between left and right frame
		pack [ttk::separator $main_frame.sep	\
			-orient vertical		\
		] -side left -fill y

		# Create right frame
		set right_frame [frame $main_frame.right_frame]
		create_right_frame $right_frame
		pack $right_frame -side left -fill both -expand 1

		# Pack status bar on the bottom
		pack $sbar_frame -side bottom -fill x -anchor nw
		pack $status_bar2 -side right -anchor ne
		pack $status_bar -side left -fill x -anchor nw

		# Pack the main frame
		pack $main_frame -fill both -expand 1

		wm title $win [mc "Special Calculator - MCU 8051 IDE"]
		wm iconphoto $win ::ICONS::16::_blockdevice
		wm minsize $win 400 350
		wm protocol $win WM_DELETE_WINDOW "delete object $this"

		if {[llength $config]} {
			wm geometry $win [lindex $config {4 0}]
			switch_page [lindex $config {4 1}]
		} else {
			wm geometry $win 400x350
			switch_page loops
		}

		# Create all pages when system "calms down"
		after idle "catch {
			foreach page {$page_list} {
				update
				$this create_page \$page
			}
		}"
	}

	## Create left part of the GUI
	 # @parm Widget target_frame - Frame widget in which the GUI should be created
	 # @return void
	private method create_left_frame {target_frame} {
		foreach name {
				{Loops} {Timer 0/1} {Timer 2} {SPI}
			} icon {
				fsview history history2 _kcmdf
			} stip {
				{}
				{Calculate timer preset}
				{Calculate timer preset}
				{}
			} page $page_list \
		{
			set buttons($page) [ttk::button $target_frame.${page}_button	\
				-image ::ICONS::22::$icon				\
				-text [mc $name] -compound top				\
				-command "$this switch_page $page"			\
				-style Flat.TButton					\
			]
			pack $buttons($page) -anchor n
			set_status_tip $buttons($page) [mc $stip]
		}
	}

	## Create right part of the GUI
	 # @parm Widget target_frame - Frame widget in which the GUI should be created
	 # @return void
	private method create_right_frame {target_frame} {
		set pages_manager [PagesManager $target_frame.pages_manager -background ${::COMMON_BG_COLOR}]
		pack $pages_manager -fill both -expand 1

		foreach page $page_list {
			set pages($page) [$pages_manager add $page]
			set page_created($page) 0
		}
	}

	## Switch active page
	 # @parm String page - Page ID
	 # @return void
	public method switch_page {page} {
		if {!$page_created($page)} {
			create_page $page
		}
		$pages_manager raise $page
		foreach p $page_list {
			$buttons($p) configure -style SpecCalc_Flat.TButton
		}
		$buttons($page) configure -style SpecCalc_Spec.TButton

		set active_page $page
	}

	## Create page for computing wait loops
	 # @return void
	private method create_page_loops {} {
		# Create frames
		set page {loops}
		set top_frame [frame $pages($page).top_frame]
		set regs_frame [frame $pages($page).regs_frame]
		set bottom_frame [frame $pages($page).bottom_frame]

		# - Time
		grid [label $top_frame.time_lbl	\
			-text [mc "Time"]	\
		] -row 0 -column 0 -sticky w
		set widgets(loops,time_ent) [ttk::entry $top_frame.time_ent	\
			-validatecommand "$this calc loops time_ent %P"		\
			-validate key						\
			-width 9						\
		]
		grid $widgets(loops,time_ent) -row 0 -column 1 -sticky we
		set widgets(loops,time_cb) [ttk::combobox $top_frame.time_cb	\
			-values {ns us ms s}	\
			-state readonly		\
			-width 7		\
		]
		bind $widgets(loops,time_cb) <<ComboboxSelected>>	\
			"$this calc loops time_cb \[$top_frame.time_cb get\]"
		grid $widgets(loops,time_cb) -row 0 -column 2 -sticky w
		set_status_tip $widgets(loops,time_cb) [mc "Time unit"]

		# - Clock
		grid [label $top_frame.clock_lbl	\
			-text [mc "Clock \[kHz\]"]	\
		] -row 1 -column 0 -sticky w
		set widgets(loops,clock_cb) [ttk::combobox $top_frame.clock_cb	\
			-validate key						\
			-width 9						\
			-validatecommand "$this calc loops clock_cb %P" 	\
			-values {
				6000.0	11059.2	12000.0	14745.6
				16000.0	20000.0	24000.0	33000.0
			}							\
		]
		set_status_tip $widgets(loops,clock_cb) [mc "MCU clock"]
		grid $widgets(loops,clock_cb) -row 1 -column 1 -sticky we
		set widgets(loops,clock_type_cb) [ttk::combobox	\
			$top_frame.clock_type_cb		\
			-values {{12 / MC} {6 / MC} {1 / MC}}	\
			-width 7				\
			-state readonly				\
		]
		bind $widgets(loops,clock_type_cb) <<ComboboxSelected>>	\
			"$this calc loops clock_type_cb \[$top_frame.clock_type_cb get\]"
		DynamicHelp::add $widgets(loops,clock_type_cb)	\
			-text [mc "Clock cycles per machine cycle\n  12 - Common 8051\n   6 - Core 51X2\n   1 - Single cycle core"]
		set_status_tip $widgets(loops,clock_type_cb) [mc "Clock cycles per machine cycle"]
		grid $widgets(loops,clock_type_cb) -row 1 -column 2 -sticky w

		# - Registers to use
		grid [label $regs_frame.regs_lbl	\
			-text [mc "Registers to use"]	\
		] -row 0 -column 0 -columnspan 8 -sticky w
		set i 0
		foreach r {1 2} {
			foreach c {0 2 4 6} {
				grid [label $regs_frame.reg_lbl$i	\
					-text " $i:"	\
				] -row $r -column $c -sticky e
				incr c

				set widgets(loops,reg_ent$i) [ttk::entry $regs_frame.reg_ent$i	\
					-validatecommand "$this calc loops reg_ent$i %P"	\
					-validate key						\
					-width 1						\
				]
				grid $widgets(loops,reg_ent$i) -row $r -column $c -sticky we
				grid columnconfigure $regs_frame $c -weight 1

				incr i
			}
		}

		# - Source code
		set bottom_frame_t [frame $bottom_frame.top]
		set bottom_frame_b [frame $bottom_frame.bottom]
		pack [label $bottom_frame_t.label	\
			-text [mc "Source code:"]	\
		] -side left
		set widgets(loops,compute_but) [ttk::button $bottom_frame_t.comp_but	\
			-text [mc "Evaluate"]						\
			-compound left							\
			-image ::ICONS::16::exec					\
			-command "$this calc loops compute_but {}"			\
		]
		pack $widgets(loops,compute_but) -side right
		set widgets(loops,copy_but) [ttk::button $bottom_frame_t.copy_but	\
			-text [mc "Copy"]						\
			-compound left							\
			-state disabled							\
			-image ::ICONS::16::editcopy					\
			-command "$this calc loops copy_but {}"				\
		]
		pack $widgets(loops,copy_but) -side right
		set widgets(loops,results) [text $bottom_frame_b.text		\
			-state disabled -width 0 -height 0 -bg white		\
			-yscrollcommand "$bottom_frame_b.scrollbar set"		\
			-takefocus 1 -font [font create				\
				-family $::DEFAULT_FIXED_FONT			\
				-size [expr {int(-14 * $::font_size_factor)}]	\
			]							\
		]
		ASMsyntaxHighlight::create_tags $widgets(loops,results) 14 $::DEFAULT_FIXED_FONT
		bind $widgets(loops,results) <Button-1> "focus %W"
		pack $widgets(loops,results) -fill both -expand 1 -side left
		pack [ttk::scrollbar $bottom_frame_b.scrollbar		\
			-orient vertical				\
			-command "$widgets(loops,results) yview"	\
		] -fill y -side right -after $widgets(loops,results)

		pack $bottom_frame_t -fill x
		pack $bottom_frame_b -fill both -expand 1

		# Configure bindings
		foreach w {time_ent time_cb clock_cb clock_type_cb compute_but} {
			bind $widgets(loops,$w) <Return> "$this calc loops compute_but {}"
			bind $widgets(loops,$w) <KP_Enter> "$this calc loops compute_but {}"
		}
		for {set i 0} {$i < 8} {incr i} {
			bind $widgets(loops,reg_ent$i) <Return> "$this calc loops compute_but {}"
			bind $widgets(loops,reg_ent$i) <KP_Enter> "$this calc loops compute_but {}"
		}


		# Create page header
		pack [label $pages($page).header				\
			-text [mc "Create a wait loop"]				\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-17 * $::font_size_factor)}]	\
				-weight bold					\
			]							\
		] -pady 5
		pack $top_frame -anchor nw
		pack $regs_frame -anchor nw -fill x
		pack [ttk::separator $pages($page).sep	\
			-orient horizontal		\
		] -fill x -pady 5
		pack $bottom_frame -anchor nw -fill both -expand 1

		# Insert values from the last session
		if {[llength $config]} {
			$widgets(loops,time_ent)	insert 0 [lindex $config {0 0}]
			$widgets(loops,time_cb)		current [lindex $config {0 1}]
			$widgets(loops,clock_cb)	delete 0 end
			$widgets(loops,clock_cb)	insert 0 [lindex $config {0 2}]
			$widgets(loops,clock_type_cb)	current [lindex $config {0 3}]

			for {set i 0; set k 4} {$i < 8} {incr i; incr k} {
				$widgets(loops,reg_ent$i) insert 0 [lindex $config [list 0 $k]]
			}

		} else {
			$widgets(loops,time_cb)		current 1
			$widgets(loops,clock_cb)	current 2
			$widgets(loops,clock_type_cb)	current 0

			for {set i 0} {$i < 8} {incr i} {
				$widgets(loops,reg_ent$i) insert 0 "R$i"
			}
		}
	}

	## Create page for computing timer 0/1 preset values
	 # @return void
	private method create_page_timer01 {} {
		# Create page frames
		set page {timer01}
		set top_frame [frame $pages($page).top_frame]
		set bottom_frame [frame $pages($page).bottom_frame]

		# - Time
		grid [label $top_frame.time_lbl	\
			-text [mc "Time"]	\
		] -row 0 -column 0 -sticky w
		set widgets(timer01,time_ent) [ttk::entry $top_frame.time_ent	\
			-validatecommand "$this calc timer01 time_ent %P"	\
			-validate key 						\
			-width 9						\
		]
		grid $widgets(timer01,time_ent) -row 0 -column 1 -sticky we
		set widgets(timer01,time_cb) [ttk::combobox $top_frame.time_cb	\
			-values {ns us ms s}	\
			-state readonly		\
			-width 7		\
		]
		bind $widgets(timer01,time_cb) <<ComboboxSelected>>	\
			"$this calc timer01 time_cb \[$top_frame.time_cb get\]"
		grid $widgets(timer01,time_cb) -row 0 -column 2 -sticky w
		set_status_tip $widgets(timer01,time_cb) [mc "Time unit"]

		# - Clock
		grid [label $top_frame.clock_lbl	\
			-text [mc "Clock \[kHz\]"]	\
		] -row 1 -column 0 -sticky w
		set widgets(timer01,clock_cb) [ttk::combobox $top_frame.clock_cb\
			-validate key						\
			-width 9						\
			-validatecommand "$this calc timer01 clock_cb %P"	\
			-values {
				6000.0	11059.2	12000.0	14745.6
				16000.0	20000.0	24000.0	33000.0
			}							\
		]
		set_status_tip $widgets(timer01,clock_cb) [mc "MCU clock"]
		grid $widgets(timer01,clock_cb) -row 1 -column 1 -sticky we
		set widgets(timer01,clock_type_cb) [ttk::combobox	\
			$top_frame.clock_type_cb			\
			-values {{12 / MC} {6 / MC} {1 / MC}}		\
			-width 7					\
			-state readonly					\
		]
		bind $widgets(timer01,clock_type_cb) <<ComboboxSelected>>	\
			"$this calc timer01 clock_type_cb \[$top_frame.clock_type_cb get\]"
		DynamicHelp::add $widgets(timer01,clock_type_cb)		\
			-text [mc "Clock cycles per machine cycle\n  12 - Common 8051\n   6 - Core 51X2\n   1 - Single cycle core"]
		set_status_tip $widgets(timer01,clock_type_cb) [mc "Clock cycles per machine cycle"]
		grid $widgets(timer01,clock_type_cb) -row 1 -column 2 -sticky w

		# - Mode
		grid [label $top_frame.mode_lbl	\
			-text [mc "Mode"]	\
		] -row 2 -column 0 -sticky w
		set widgets(timer01,mode_cb) [ttk::combobox $top_frame.mode_cb	\
			-width 18						\
			-state readonly						\
			-values {
				{0 - 13 bit}
				{1 - 16 bit}
				{2 -  8 bit auto r.}
			}	\
		]
		bind $widgets(timer01,mode_cb) <<ComboboxSelected>>	\
			"$this calc timer01 mode_cb \[$top_frame.mode_cb get\]"
		set_status_tip $widgets(timer01,mode_cb) [mc "Timer mode"]
		grid $widgets(timer01,mode_cb) -row 2 -column 1 -sticky we -columnspan 2
		grid [ttk::button $top_frame.show_diagram_button	\
			-image ::ICONS::16::info			\
			-style Flat.TButton				\
			-command "$this show_diagram timer01 {}"	\
		] -row 2 -column 3 -sticky w
		set_status_tip $top_frame.show_diagram_button [mc "Show functional block diagram"]

		# - Enhanced timer/counter
		set widgets(timer01,spec_chb) [checkbutton $top_frame.spec_chb	\
			-text [mc "Enhanced timer/counter"] -onvalue 1 -offvalue 0	\
			-variable ::SpecCalc::spec_chb_$obj_idx			\
			-command "$this calc timer01 spec_chb \${::SpecCalc::spec_chb_$obj_idx}" \
		]
		set_status_tip $widgets(timer01,spec_chb) [mc "Calculate for enhanced timers"]
		grid $widgets(timer01,spec_chb) -row 3 -column 0 -sticky w -columnspan 3

		# - PSC
		set widgets(timer01,psc_lbl) [	\
			label $top_frame.psc_lbl	\
			-text "PSC"			\
		]
		set widgets(timer01,psc_cb) [ttk::combobox $top_frame.psc_cb	\
			-values {0 1 2 3 4 5 6 7}				\
			-width 1						\
		]
		bind $widgets(timer01,psc_cb) <<ComboboxSelected>>	\
			"$this calc timer01 psc_cb \[$top_frame.psc_cb get\]"
		set_status_tip $widgets(timer01,psc_cb) [mc "The number of active bits in TL1 minus 1"]

		## Results ...
		 # Labels
		grid [label $bottom_frame.res_lbl	\
			-text [mc "Results:"]		\
		] -row 0 -column 0 -columnspan 3 -sticky w
		grid [label $bottom_frame.th_l_lbl	\
			-text [mc "TH"]			\
		] -row 1 -column 1 -sticky e
		grid [label $bottom_frame.tl_l_lbl	\
			-text [mc "TL"]			\
		] -row 2 -column 1 -sticky e
		set widgets(timer01,rh_l) [label $bottom_frame.rh_l_lbl	\
			-text [mc "RH"]			\
		]
		set widgets(timer01,rl_l) [label $bottom_frame.rl_l_lbl	\
			-text [mc "RL"]			\
		]
		grid [label $bottom_frame.rep_l_lbl	\
			-text [mc "Repeats"]		\
		] -row 5 -column 1 -sticky e
		grid [label $bottom_frame.rest_l_lbl	\
			-text [mc "Rest"]		\
		] -row 6 -column 1 -sticky e
		 # ":="
		for {set i 1} {$i < 7} {incr i} {
			set widgets(timer01,eq$i)	\
				[label $bottom_frame.equal_s_l$i -text ":="]
			grid $widgets(timer01,eq$i) -row $i -column 2
		}
		grid forget $widgets(timer01,eq3)
		grid forget $widgets(timer01,eq4)
		 ## Entryboxes with results themselfs
		 # - TH
		set widgets(timer01,th) [				\
			entry $bottom_frame.th_r_lbl -state readonly	\
			-readonlybackground ${::COMMON_BG_COLOR}	\
			-disabledforeground {#000000}			\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}		\
			-relief flat -highlightthickness 0 -bd 0	\
			-textvariable ::SpecCalc::timer01_th_$obj_idx	\
		]
		set ::SpecCalc::timer01_th_$obj_idx [mc "Do not change"]
		grid $widgets(timer01,th) -row 1 -column 3 -sticky w
		 # - TL
		set widgets(timer01,tl) [				\
			entry $bottom_frame.tl_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}		\
			-readonlybackground ${::COMMON_BG_COLOR}	\
			-disabledforeground {#000000}			\
			-relief flat -highlightthickness 0 -bd 0	\
			-textvariable ::SpecCalc::timer01_tl_$obj_idx	\
		]
		set ::SpecCalc::timer01_tl_$obj_idx [mc "Do not change"]
		grid $widgets(timer01,tl) -row 2 -column 3 -sticky w
		 # - RH
		set widgets(timer01,rh) [				\
			entry $bottom_frame.rh_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}		\
			-readonlybackground ${::COMMON_BG_COLOR}	\
			-disabledforeground {#000000}			\
			-relief flat -highlightthickness 0 -bd 0	\
			-textvariable ::SpecCalc::timer01_rh_$obj_idx	\
		]
		set ::SpecCalc::timer01_rh_$obj_idx [mc "Do not change"]
		 # - RL
		set widgets(timer01,rl) [				\
			entry $bottom_frame.rl_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}		\
			-readonlybackground ${::COMMON_BG_COLOR}	\
			-disabledforeground {#000000}			\
			-relief flat -highlightthickness 0 -bd 0	\
			-textvariable ::SpecCalc::timer01_rl_$obj_idx	\
		]
		set ::SpecCalc::timer01_rl_$obj_idx [mc "Do not change"]
		 # - Repeats
		set widgets(timer01,repeats) [				\
			entry $bottom_frame.reps_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}		\
			-readonlybackground ${::COMMON_BG_COLOR}	\
			-disabledforeground {#000000}			\
			-relief flat -highlightthickness 0 -bd 0	\
			-textvariable ::SpecCalc::timer01_repeats_$obj_idx\
		]
		set ::SpecCalc::timer01_repeats_$obj_idx [mc "Zero"]
		grid $widgets(timer01,repeats) -row 5 -column 3 -sticky w
		 # - Rest
		set widgets(timer01,rest) [				\
			entry $bottom_frame.rest_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}		\
			-readonlybackground ${::COMMON_BG_COLOR}	\
			-disabledforeground {#000000}			\
			-relief flat -highlightthickness 0 -bd 0	\
			-textvariable ::SpecCalc::timer01_rest_$obj_idx	\
		]
		set ::SpecCalc::timer01_rest_$obj_idx [mc "none"]
		grid $widgets(timer01,rest) -row 6 -column 3 -sticky w

		# Configure grid layout
		grid columnconfigure $bottom_frame 0 -minsize 15


		# Create page header
		pack [label $pages($page).header				\
			-text [mc "Calculate timer 0/1 preset"]			\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-17 * $::font_size_factor)}]	\
				-weight bold					\
			]							\
		] -pady 5
		pack $top_frame -anchor nw
		pack [ttk::separator $pages($page).sep	\
			-orient horizontal		\
		] -fill x -pady 5
		pack $bottom_frame -anchor nw -padx 10

		# Restore values from the last session
		set load_failure 1
		catch {
			if {[llength $config]} {
				$widgets(timer01,time_ent)	insert 0 [lindex $config {1 0}]
				$widgets(timer01,time_cb)	current [lindex $config {1 1}]
				$widgets(timer01,clock_cb)	delete 0 end
				$widgets(timer01,clock_cb)	insert 0 [lindex $config {1 2}]
				$widgets(timer01,clock_type_cb)	current [lindex $config {1 3}]
				$widgets(timer01,mode_cb)	current [lindex $config {1 4}]
				$widgets(timer01,psc_cb)	current [lindex $config {1 5}]
				set ::SpecCalc::spec_chb_$obj_idx [lindex $config {1 6}]
				if {[lindex $config {1 6}]} {
					calc timer01 spec_chb 1
				}
				set load_failure 0
			}
		}
		if {$load_failure} {
			$widgets(timer01,time_cb)	current 1
			$widgets(timer01,clock_cb)	current 2
			$widgets(timer01,clock_type_cb)	current 0
			$widgets(timer01,mode_cb)	current 1
			$widgets(timer01,psc_cb)	current 4
		}
	}

	## Create page for computing timer 2 preset values
	 # @return void
	private method create_page_timer2 {} {
		# Create notebook
		set page {timer2}
		set nb [ModernNoteBook $pages($page).nb]
		 # - Page "Preset"
		set preset_frame [$nb insert end {Preset}	\
			-text [mc "Preset"] 			\
			-image ::ICONS::16::player_time		\
		]
		 # - Page "Clock"
		set clock_out_frame [$nb insert end {Clock}	\
			-text [mc "Clock out"]			\
			-image ::ICONS::16::kcmpci		\
		]


		#
		## Create "Preset" page
		#

		# Create frames
		set top_frame [frame $preset_frame.top_frame]
		set bottom_frame [frame $preset_frame.bottom_frame]

		# - Time
		grid [label $top_frame.time_lbl	\
			-text [mc "Time"]	\
		] -row 0 -column 0 -sticky w
		set widgets(timer2,time_ent) [ttk::entry $top_frame.time_ent	\
			-validatecommand "$this calc timer2 time_ent %P"	\
			-validate key						\
			-width 9						\
		]
		grid $widgets(timer2,time_ent) -row 0 -column 1 -sticky we
		set widgets(timer2,time_cb) [ttk::combobox $top_frame.time_cb	\
			-values {ns us ms s}	\
			-state readonly		\
			-width 7		\
		]
		bind $widgets(timer2,time_cb) <<ComboboxSelected>>	\
			"$this calc timer2 time_cb \[$top_frame.time_cb get\]"
		grid $widgets(timer2,time_cb) -row 0 -column 2 -sticky w
		set_status_tip $widgets(timer2,time_cb) [mc "Time unit"]

		# - Clock
		grid [label $top_frame.clock_lbl	\
			-text [mc "Clock \[kHz\]"]	\
		] -row 1 -column 0 -sticky w
		set widgets(timer2,clock_cb) [ttk::combobox $top_frame.clock_cb	\
			-validate key						\
			-width 9						\
			-validatecommand "$this calc timer2 clock_cb %P" 	\
			-values {
				6000.0	11059.2	12000.0	14745.6
				16000.0	20000.0	24000.0	33000.0
			}							\
		]
		set_status_tip $widgets(timer2,clock_cb) [mc "MCU clock"]
		grid $widgets(timer2,clock_cb) -row 1 -column 1 -sticky we
		set widgets(timer2,clock_type_cb) [ttk::combobox	\
			$top_frame.clock_type_cb			\
			-values {{12 / MC} {6 / MC} {1 / MC}}		\
			-width 7 -state readonly			\
			-state readonly					\
		]
		bind $widgets(timer2,clock_type_cb) <<ComboboxSelected>>	\
			"$this calc timer2 clock_type_cb \[$top_frame.clock_type_cb get\]"
		DynamicHelp::add $widgets(timer2,clock_type_cb)	\
			-text [mc "Clock cycles per machine cycle\n  12 - Common 8051\n   6 - Core 51X2\n   1 - Single cycle core"]
		set_status_tip $widgets(timer2,clock_type_cb) [mc "Clock cycles per machine cycle"]
		grid $widgets(timer2,clock_type_cb) -row 1 -column 2 -sticky w

		# - Mode
		grid [label $top_frame.mode_lbl	\
			-text [mc "Mode"]	\
		] -row 2 -column 0 -sticky w
		set widgets(timer2,mode_cb) [ttk::combobox $top_frame.mode_cb	\
			-state readonly						\
			-width 18						\
			-values {
				{UP counter (auto reload)}
				{DOWN counter (auto reload)}
			}	\
		]
		bind $widgets(timer2,mode_cb) <<ComboboxSelected>>	\
			"$this calc timer2 mode_cb \[$top_frame.mode_cb get\]"
		set_status_tip $widgets(timer2,mode_cb) [mc "Timer mode"]
		grid $widgets(timer2,mode_cb) -row 2 -column 1 -sticky we -columnspan 2
		grid [ttk::button $top_frame.show_diagram_button	\
			-image ::ICONS::16::info			\
			-command "$this show_diagram timer2 0"		\
			-style Flat.TButton				\
		] -row 2 -column 3 -sticky w
		set_status_tip $top_frame.show_diagram_button [mc "Show functional block diagram"]

		## Results ...
		 # Labels
		grid [label $bottom_frame.res_lbl	\
			-text [mc "Results:"]		\
		] -row 0 -column 0 -columnspan 3 -sticky w
		grid [label $bottom_frame.rcal2h_l_lbl	\
			-text [mc "RCAL2H"]		\
		] -row 1 -column 1 -sticky e
		grid [label $bottom_frame.rcal2l_l_lbl	\
			-text [mc "RCAL2L"]		\
		] -row 2 -column 1 -sticky e
		grid [label $bottom_frame.t2h_l_lbl	\
			-text [mc "T2H"]		\
		] -row 3 -column 1 -sticky e
		grid [label $bottom_frame.t2l_l_lbl	\
			-text [mc "T2L"]		\
		] -row 4 -column 1 -sticky e
		grid [label $bottom_frame.repeats_l_lbl	\
			-text [mc "Repeats"]		\
		] -row 5 -column 1 -sticky e
		grid [label $bottom_frame.rest_l_lbl	\
			-text [mc "Rest"]		\
		] -row 6 -column 1 -sticky e
		 # ":="
		for {set i 1} {$i < 7} {incr i} {
			grid [label $bottom_frame.equal_s_l$i -text ":="] -row $i -column 2
		}
		 ## Entryboxes with results themselfs
		 # - RCAL2H
		set widgets(timer2,rcal2h) [
			entry $bottom_frame.rcal2h_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}			\
			-relief flat -highlightthickness 0 -bd 0		\
			-textvariable ::SpecCalc::timer2_rcal2h_$obj_idx	\
			-readonlybackground ${::COMMON_BG_COLOR}		\
			-disabledforeground {#000000}				\
		]
		set ::SpecCalc::timer2_rcal2h_$obj_idx [mc "Do not change"]
		grid $widgets(timer2,rcal2h) -row 1 -column 3 -sticky w
		 # - RCAL2L
		set widgets(timer2,rcal2l) [
			entry $bottom_frame.rcal2l_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}			\
			-relief flat -highlightthickness 0 -bd 0		\
			-textvariable ::SpecCalc::timer2_rcal2l_$obj_idx	\
			-readonlybackground ${::COMMON_BG_COLOR}		\
			-disabledforeground {#000000}				\
		]
		set ::SpecCalc::timer2_rcal2l_$obj_idx [mc "Do not change"]
		grid $widgets(timer2,rcal2l) -row 2 -column 3 -sticky w
		 # - T2H
		set widgets(timer2,t2h) [
			entry $bottom_frame.t2h_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}		\
			-relief flat -highlightthickness 0 -bd 0	\
			-textvariable ::SpecCalc::timer2_t2h_$obj_idx	\
			-readonlybackground ${::COMMON_BG_COLOR}	\
			-disabledforeground {#000000}			\
		]
		set ::SpecCalc::timer2_t2h_$obj_idx [mc "Do not change"]
		grid $widgets(timer2,t2h) -row 3 -column 3 -sticky w
		 # - T2L
		set widgets(timer2,t2l) [
			entry $bottom_frame.t2l_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}		\
			-relief flat -highlightthickness 0 -bd 0	\
			-textvariable ::SpecCalc::timer2_t2l_$obj_idx	\
			-readonlybackground ${::COMMON_BG_COLOR}	\
			-disabledforeground {#000000}			\
		]
		set ::SpecCalc::timer2_t2l_$obj_idx [mc "Do not change"]
		grid $widgets(timer2,t2l) -row 4 -column 3 -sticky w
		 # - Repeats
		set widgets(timer2,repeats) [					\
			entry $bottom_frame.repeats_lbl -state readonly		\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}			\
			-relief flat -highlightthickness 0 -bd 0		\
			-readonlybackground ${::COMMON_BG_COLOR}		\
			-disabledforeground {#000000}				\
			-textvariable ::SpecCalc::timer2_repeats_$obj_idx	\
		]
		set ::SpecCalc::timer2_repeats_$obj_idx [mc "none"]
		grid $widgets(timer2,repeats) -row 5 -column 3 -sticky w
		 # - Rest
		set widgets(timer2,rest) [				\
			entry $bottom_frame.rest_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR}		\
			-relief flat -highlightthickness 0 -bd 0	\
			-readonlybackground ${::COMMON_BG_COLOR}	\
			-disabledforeground {#000000}			\
			-textvariable ::SpecCalc::timer2_rest_$obj_idx	\
		]
		set ::SpecCalc::timer2_rest_$obj_idx [mc "none"]
		grid $widgets(timer2,rest) -row 6 -column 3 -sticky w

		# Configure grid layout
		grid columnconfigure $bottom_frame 0 -minsize 15


		# Create page header
		pack [label $preset_frame.header				\
			-text [mc "Calculate timer 2 preset"]			\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-17 * $::font_size_factor)}]	\
				-weight bold					\
			]							\
		] -pady 5
		pack $top_frame -pady 5 -anchor nw
		pack [ttk::separator $preset_frame.sep	\
			-orient horizontal		\
		] -fill x -pady 10
		pack $bottom_frame -anchor nw -padx 10

		# Restore values from the last session
		if {[llength $config]} {
			$widgets(timer2,time_ent)	insert 0 [lindex $config {2 0}]
			$widgets(timer2,time_cb)	current [lindex $config {2 1}]
			$widgets(timer2,clock_cb)	delete 0 end
			$widgets(timer2,clock_cb)	insert 0 [lindex $config {1 2}]
			$widgets(timer2,clock_type_cb)	current [lindex $config {2 3}]
			$widgets(timer2,mode_cb)	current [lindex $config {2 4}]
		} else {
			$widgets(timer2,time_cb)	current 1
			$widgets(timer2,clock_cb)	current 2
			$widgets(timer2,clock_type_cb)	current 0
			$widgets(timer2,mode_cb)	current 0
		}
		set bottom_frame [frame $clock_out_frame.bottom_frame]


		#
		## Create "Clock" page
		#

		# Labes ...
		grid [label $bottom_frame.freq_l_lbl	\
			-text [mc "Frequency"]		\
		] -row 1 -column 1 -sticky e
		grid [label $bottom_frame.fosc_l_lbl	\
			-text [mc "F osc"]		\
		] -row 2 -column 1 -sticky e
		grid [label $bottom_frame.x2_l_lbl	\
			-text [mc "X2"]			\
		] -row 3 -column 1 -sticky e
		grid [label $bottom_frame.hex_lbl		\
			-text [mc "HEX"] -font $::smallfont	\
		] -row 5 -column 2
		grid [label $bottom_frame.dec_lbl		\
			-text [mc "DEC"] -font $::smallfont	\
		] -row 5 -column 3
		grid [label $bottom_frame.rcap2h_l_lbl	\
			-text [mc "RCAP2H"]		\
		] -row 6 -column 1 -sticky e
		grid [label $bottom_frame.rcap2l_l_lbl	\
			-text [mc "RCAP2L"]		\
		] -row 7 -column 1 -sticky e
		grid [label $bottom_frame.error_l_lbl	\
			-text [mc "Error"]		\
		] -row 8 -column 1 -sticky e

		# Separator
		grid [ttk::separator $bottom_frame.sep	\
			-orient horizontal		\
		] -row 4 -column 1 -sticky we -columnspan 3 -pady 5

		## EntryBoxes
		 # - Frequency
		set widgets(timer2,clk_freq) [ttk::entry			\
			 $bottom_frame.clk_freq_r_lbl				\
			-validate key						\
			-width 12						\
			-textvariable ::SpecCalc::timer2_clk_freq_$obj_idx	\
			-validatecommand "$this calc clk_timer2 clk_freq %P"	\
		]
		grid $widgets(timer2,clk_freq) -row 1 -column 2 -sticky w -columnspan 3
		set widgets(timer2,clk_fosc) [ttk::entry			\
			$bottom_frame.clk_fosc_r_lbl				\
			-validate key						\
			-width 12						\
			-textvariable ::SpecCalc::timer2_clk_fosc_$obj_idx	\
			-validatecommand "$this calc clk_timer2 clk_fosc %P"	\
		]
		grid $widgets(timer2,clk_fosc) -row 2 -column 2 -sticky w -columnspan 3
		 # - X2
		set widgets(timer2,clk_x2_cb) [ttk::combobox $bottom_frame.clock_type_cb	\
			-values {0 1}								\
			-width 1								\
			-state readonly								\
			-textvariable ::SpecCalc::timer2_clk_x2_$obj_idx			\
		]
		bind $widgets(timer2,clk_x2_cb) <<ComboboxSelected>>	\
			"$this calc clk_timer2 clk_x2_cb \[$bottom_frame.clock_type_cb get\]"
		set ::SpecCalc::timer2_clk_x2_$obj_idx {0}
		grid $widgets(timer2,clk_x2_cb) -row 3 -column 2 -sticky w -columnspan 3
		 # - RCAL2H
		set widgets(timer2,clk_rcal2h) [
			entry $bottom_frame.clk_rcal2h_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR} -validate key	\
			-relief flat -highlightthickness 0 -bd 0 -width 5	\
			-textvariable ::SpecCalc::timer2_clk_rcal2h_$obj_idx	\
			-readonlybackground ${::COMMON_BG_COLOR}		\
			-disabledforeground {#000000}				\
		]
		set ::SpecCalc::timer2_clk_rcal2h_$obj_idx "--"
		grid $widgets(timer2,clk_rcal2h) -row 6 -column 2 -sticky w
		 # - RCAL2L
		set widgets(timer2,clk_rcal2l) [
			entry $bottom_frame.clk_rcal2l_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR} -validate key	\
			-relief flat -highlightthickness 0 -bd 0 -width 5	\
			-textvariable ::SpecCalc::timer2_clk_rcal2l_$obj_idx	\
			-readonlybackground ${::COMMON_BG_COLOR}		\
			-disabledforeground {#000000}				\
		]
		set ::SpecCalc::timer2_clk_rcal2l_$obj_idx "--"
		grid $widgets(timer2,clk_rcal2l) -row 7 -column 2 -sticky w
		 # RCAL2H
		set widgets(timer2,clk_rcal2h_d) [
			entry $bottom_frame.clk_rcal2h_d_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR} -validate key	\
			-relief flat -highlightthickness 0 -bd 0 -width 5	\
			-textvariable ::SpecCalc::timer2_clk_rcal2h_d_$obj_idx	\
			-readonlybackground ${::COMMON_BG_COLOR}		\
			-disabledforeground {#000000}				\
		]
		set ::SpecCalc::timer2_clk_rcal2h_d_$obj_idx "--"
		grid $widgets(timer2,clk_rcal2h_d) -row 6 -column 3 -sticky w
		 # - RCAL2L
		set widgets(timer2,clk_rcal2l_d) [
			entry $bottom_frame.clk_rcal2l_d_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR} -validate key	\
			-relief flat -highlightthickness 0 -bd 0 -width 5	\
			-textvariable ::SpecCalc::timer2_clk_rcal2l_d_$obj_idx	\
			-readonlybackground ${::COMMON_BG_COLOR}		\
			-disabledforeground {#000000}				\
		]
		set ::SpecCalc::timer2_clk_rcal2l_d_$obj_idx "--"
		grid $widgets(timer2,clk_rcal2l_d) -row 7 -column 3 -sticky w
		 # - Error
		set widgets(timer2,clk_error) [
			entry $bottom_frame.clk_error_r_lbl -state readonly	\
			-fg {#888888} -bg ${::COMMON_BG_COLOR} -validate key	\
			-relief flat -highlightthickness 0 -bd 0 -width 12	\
			-textvariable ::SpecCalc::timer2_clk_error_$obj_idx	\
			-readonlybackground ${::COMMON_BG_COLOR}		\
			-disabledforeground {#000000}				\
		]
		set ::SpecCalc::timer2_clk_error_$obj_idx "--"
		grid $widgets(timer2,clk_error) -row 8 -column 2 -sticky w -columnspan 2

		# Clear entry boxes with results
		calculate_timer2_clk_clear_results

		# Load values from the last session
		if {[llength $config]} {
			set ::SpecCalc::timer2_clk_fosc_$obj_idx	[lindex $config {3 0}]
			set ::SpecCalc::timer2_clk_freq_$obj_idx	[lindex $config {3 1}]
			set ::SpecCalc::timer2_clk_x2_$obj_idx		[lindex $config {3 2}]
		} else {
			set ::SpecCalc::timer2_clk_fosc_$obj_idx	{}
			set ::SpecCalc::timer2_clk_freq_$obj_idx	{}
			set ::SpecCalc::timer2_clk_x2_$obj_idx		{0}
		}

		# Create page header
		pack [label $clock_out_frame.header				\
			-text [mc "Calculate clock output"]			\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-17 * $::font_size_factor)}]	\
				-weight bold					\
			]							\
		] -pady 5
		pack [label $clock_out_frame.math					\
			-image [image create photo					\
				-format png						\
				-file "${::ROOT_DIRNAME}/icons/other/math0.png"	\
			]								\
		] -pady 5
		pack $bottom_frame -anchor nw
		$nb raise {Preset}
		pack [$nb get_nb] -fill both -expand 1
	}

	## Create page for calculating SPI related values
	 # @return void
	private method create_page_spi {} {
		# Create page frames
		set page {spi}
		set top_frame [frame $pages($page).top_frame]
		set bottom_frame [frame $pages($page).bottom_frame]

		# - Mode X2 or single cycle core
		set widgets(spi,double_chb) [				\
			checkbutton $top_frame.double_chb		\
			-text [mc "Mode X2 or single cycle core"]	\
			-onvalue 1 -offvalue 2				\
			-variable ::SpecCalc::double_chb_$obj_idx	\
			-command "$this calc spi double_chb \${::SpecCalc::double_chb_$obj_idx}" \
		]
		grid $widgets(spi,double_chb) -row 0 -column 0 -columnspan 3 -sticky w

		# Labels ...
		grid [label $top_frame.spr1_lbl	\
			-text "SPR1"		\
		] -row 1 -column 0
		grid [label $top_frame.spr0_lbl	\
			-text "SPR0"		\
		] -row 1 -column 1
		grid [label $top_frame.sck_lbl		\
			-text [mc "SCK \[kHz\]"]	\
		] -row 1 -column 2

		grid [label $top_frame.spr1_0_lbl	\
			-text "0"			\
		] -row 2 -column 0
		grid [label $top_frame.spr0_0_lbl	\
			-text "0"			\
		] -row 2 -column 1
		set widgets(spi,sck_ent00) [ttk::entry $top_frame.sck_0_ent	\
			-width 9						\
			-validate key						\
			-validatecommand "$this calc spi sck_ent00 %P"		\
		]
		grid $widgets(spi,sck_ent00) -row 2 -column 2

		grid [label $top_frame.spr1_1_lbl	\
			-text "0"			\
		] -row 3 -column 0
		grid [label $top_frame.spr0_1_lbl	\
			-text "1"			\
		] -row 3 -column 1
		set widgets(spi,sck_ent01) [ttk::entry $top_frame.sck_1_ent	\
			-width 9						\
			-validate key						\
			-validatecommand "$this calc spi sck_ent01 %P"		\
		]
		grid $widgets(spi,sck_ent01) -row 3 -column 2

		grid [label $top_frame.spr1_2_lbl	\
			-text "1"			\
		] -row 4 -column 0
		grid [label $top_frame.spr0_2_lbl	\
			-text "0"			\
		] -row 4 -column 1
		set widgets(spi,sck_ent10) [ttk::entry $top_frame.sck_2_ent	\
			-width 9						\
			-validate key						\
			-validatecommand "$this calc spi sck_ent10 %P"		\
		]
		grid $widgets(spi,sck_ent10) -row 4 -column 2

		grid [label $top_frame.spr1_3_lbl	\
			-text "1"			\
		] -row 5 -column 0
		grid [label $top_frame.spr0_3_lbl	\
			-text "1"			\
		] -row 5 -column 1
		set widgets(spi,sck_ent11) [ttk::entry $top_frame.sck_3_ent	\
			-width 9						\
			-validate key						\
			-validatecommand "$this calc spi sck_ent11 %P"		\
		]
		grid $widgets(spi,sck_ent11) -row 5 -column 2


		pack [label $bottom_frame.res_lbl0		\
			-text [mc "Set MCU oscillator to "]	\
		] -side left
		set widgets(spi,result) [					\
			entry $bottom_frame.result_ent				\
			-readonlybackground ${::COMMON_BG_COLOR}		\
			-disabledforeground {#000000}				\
			-bg ${::COMMON_BG_COLOR} -width 0 -bd 1 -state readonly	\
			-relief flat -highlightthickness 0			\
			-textvariable ::SpecCalc::spi_result_$obj_idx		\
		]
		pack $widgets(spi,result) -side left
		pack [label $bottom_frame.res_lbl1	\
			-text [mc " kHz"]		\
		] -side left

		pack [label $pages($page).header				\
			-text [mc "Calculate oscillator frequency"]		\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-17 * $::font_size_factor)}]	\
				-weight bold					\
			]							\
		] -pady 5
		pack $top_frame -pady 5 -anchor nw
		pack [ttk::separator $pages($page).sep	\
			-orient horizontal		\
		] -fill x -pady 10
		pack $bottom_frame -anchor nw -padx 10

		set ::SpecCalc::spi_result_$obj_idx "--"

		if {[llength $config]} {
			set ::SpecCalc::double_chb_$obj_idx [lindex $config {5 0}]
			calc spi double_chb [lindex $config {5 0}]

			$widgets(spi,sck_ent00) delete 0 end
			$widgets(spi,sck_ent00) insert 0 [lindex $config {5 1}]
		}
	}

	## Create GUI for page specified by parameter
	 # @parm String page -Page ID
	 # @return void
	public method create_page {page} {
		if {$page_created($page)} {return}
		set page_created($page) 1

		switch -- $page {
			{loops} {	;# Wait loops
				create_page_loops
			}
			{timer01} {	;# Timer 0/1
				create_page_timer01
			}
			{timer2} {	;# Timer 2
				create_page_timer2
			}
			{spi} {		;# SPI (Serial Peripheral Interface)
				create_page_spi
			}
		}
	}

	## Auxiliary function for function "calculate_loops"
	 # @parm float time
	 # @parm float rest
	 # @parm Bool is_spec
	 # @return List
	private method calculate_loops_AUX {time rest is_spec} {
		array set res {0 {} 1 {} 2 {} 3 {} 4 {} 5 {} 6 {} 7 {}}
		set len 0
		set div_all 1
		for {set len 0} {$len < 9} {incr len} {
			if {$len == 8} {
				status_tip [mc "Unable to evaluate"]
				calculate_loops_clear_results
				return 0
			} elseif {$len} {
				set init 256
			} else {
				set init 257
			}

			set mod $init
			set div $init
			for {set i $init} {$i >= 2} {incr i -1} {
				if {($time % $i) < $mod} {
					set mod [expr {$time % $i}]
					set div $i
				}
			}

			set rest [expr {$rest + ($mod * $div_all)}]
			set div_all [expr {$div_all * $div}]
			set time [expr {$time / $div}]
			if {$res($len) == 256} {
				set res($len) 0
			} else {
				set res($len) $div
			}

			if {$time == 1} {
				break
			}
		}
		incr len
		if {$len > 1} {
			incr res(0) -2
		} else {
			incr res(0) -1
		}
		set correction 0
		if {$len == 1} {
			if {[lindex $is_spec 0]} {
				set correction -1
			}
		}
		for {set i 1} {$i < $len} {incr i} {
			set div $res($i)
			set div_all [expr {$div_all * $div}]

			if {$i == 1} {
				if {[lindex $is_spec $i]} {
					set correction 1
				} else {
					set correction 2
				}
			} else {
				if {[lindex $is_spec $i]} {
					set correction [expr {($correction * $res($i)) + ($res($i) * 2) + 1}]
				} else {
					set correction [expr {($correction * $res($i)) + ($res($i) * 3) + 2}]
				}
			}
		}

		set rest [expr {(2.0 * $rest) - $correction}]
		return [list $rest $len [array get res]]
	}

	private method calculate_loops_AUX2 {time clock is_spec} {
		set time_org $time
		set i 0
		set result [list]
		set lowest_rest {}
		set last_rest {}
		set result_c {}
		set result_fin_i 0
		for {set i 0} {$i < 8} {incr i} {
			set rest $time_org
			set time [expr {int($time)}]
			set rest [expr {$rest - $time}]

			if {!$i && $time_org < 2.0} {
				lappend result [list [expr {$time_org * 2.0  + 1.0}] 0 [list 0 {} 1 {} 2 {} 3 {} 4 {} 5 {} 6 {} 7 {}]]
				break
			}

			set result_c [calculate_loops_AUX $time $rest $is_spec]
			if {$result_c == {0}} {
				return {}
			}
			lappend result $result_c

			if {$lowest_rest == {}} {
				set lowest_rest [lindex $result_c 0]

			} elseif {$lowest_rest < 0} {
				if {
					( [lindex $result_c 0] >= 0 )
						||
					( abs($lowest_rest) > abs([lindex $result_c 0]) )
				} then {
					set result_fin_i $i
					set lowest_rest [lindex $result_c 0]
				}

			} elseif {
				( [lindex $result_c 0] >= 0 )
					&&
				( $lowest_rest > [lindex $result_c 0] )
			} then {
				set result_fin_i $i
				set lowest_rest [lindex $result_c 0]
			}

			if {$last_rest == [lindex $result_c 0] || ![lindex $result_c 0]} {
				break
			}
			set last_rest [lindex $result_c 0]
			set time [expr {$time_org + ($last_rest / 2.0)}]
		}

		return [lindex $result $result_fin_i]
	}

	private method calculate_loops_AUX3 {len is_spec res_list reg_list} {
		set e_no_of_spaces ${::Editor::number_of_spaces}
		if {$e_no_of_spaces == 1} {
			set e_no_of_spaces 5
		} elseif {$e_no_of_spaces <= 4} {
			set e_no_of_spaces 6
		}

		array set res $res_list
		array set reg $reg_list
		set last_branch 0
		set branch 0
		for {set i 0} {$i < $len} {incr i} {
			set branch $last_branch
			set val $res($i)

			set val [string range [format {%X} $res($i)] end-1 end]
			set val "[string repeat {0} [expr {3 - [string length $val]}]]$val"

			set cmp {}
			if {[lindex $is_spec $i]} {
				if {!$i} {
					if {${::Editor::spaces_no_tabs}} {
						set cmp "\n[string repeat { } ${::Editor::number_of_spaces}]NOP"
					} else {
						set cmp "\n\tNOP"
					}
					incr branch 1
				}
			} else {
				incr branch 2
			}
			incr branch 4

			set last_branch $branch
			if {!$i} {
				set branch 0
				incr last_branch -4
			}

			if {$branch == {0}} {
				set branch {}
			} else {
				set branch "-$branch"
			}

			if {${::Editor::spaces_no_tabs}} {
				set res($i) [list			\
					"[string repeat { } ${::Editor::number_of_spaces}]DJNZ[string repeat { } [expr {$e_no_of_spaces - 4}]]$reg($i), \$$branch"	\
					"[string repeat { } ${::Editor::number_of_spaces}]MOV[string repeat { } [expr {$e_no_of_spaces - 3}]]$reg($i), #${val}h$cmp"	\
				]
			} else {
				set res($i) [list			\
					"\tDJNZ\t$reg($i), \$$branch"	\
					"\tMOV\t$reg($i), #${val}h$cmp"	\
				]
			}
		}
		for {set i [expr {$len - 1}]} {$i >= 0} {incr i -1} {
			$widgets(loops,results) insert end "[lindex $res($i) 1]\n"
		}
		for {set i 0} {$i < $len} {incr i} {
			$widgets(loops,results) insert end "[lindex $res($i) 0]\n"
		}
	}

	## Generate wait loop acoring to specified criteria
	 # @return void
	private method calculate_loops {} {
		$widgets(loops,results) configure -state normal
		$widgets(loops,results) delete 0.0 end

		set note {}

		set is_spec [list]
		for {set i 0} {$i < 8} {incr i} {
			set reg($i) [$widgets(loops,reg_ent$i) get]

			if {[lsearch -ascii -exact {R0 R1 R2 R3 R4 R5 R6 R7 A} [string toupper $reg($i)]] != -1} {
				lappend is_spec 1
			} else {
				lappend is_spec 0
			}
		}

		set time [$widgets(loops,time_ent) get]
		if {$time == {}} {
			set time 1
			append note [mc "ERROR: Missing time\n"]
		} elseif {$time == 0} {
			append note [mc "ERROR: Time rate cannot be 0\n"]
		}

		set clock [$widgets(loops,clock_cb) get]
		if {$clock == {}} {
			set clock 1
			append note [mc "ERROR: Missing MCU clock rate\n"]
		} elseif {$clock == 0} {
			append note [mc "ERROR: MCU clock rate cannot be 0\n"]
		}

		if {[string length $note]} {
			$widgets(loops,results) insert end $note
			$widgets(loops,results) configure -state disabled
			return 0
		}

		set e_no_of_spaces ${::Editor::number_of_spaces}
		if {$e_no_of_spaces == 1} {
			set e_no_of_spaces 5
		} elseif {$e_no_of_spaces <= 4} {
			set e_no_of_spaces 6
		}

		set time [expr {$time * [lindex {1.0 1000.0 1000000.0 1000000000.0} [$widgets(loops,time_cb) current]] / 2.0}]
		set clock [expr {$clock / [lindex {12000000.0 6000000.0 1000000.0} [$widgets(loops,clock_type_cb) current]]}]
		set time [expr {$time * $clock}]

		if {$time <= 258.5} {
			set time [expr {$time - 0.5}]
		}

		set final_results [calculate_loops_AUX2 $time $clock $is_spec]
		if {$final_results == {}} {
			return 0
		}
		set rest [lindex $final_results 0]
		set len [lindex $final_results 1]
		array set res [lindex $final_results 2]

		for {set i 0} {$i < $len} {incr i} {
			set error 0
			if {![string length $reg($i)]} {
				set error 1
				$widgets(loops,results) insert end	\
					[mc "ERROR: Missing register name %s\n" $i]
			} elseif {[$widgets(loops,reg_ent$i) cget -style] == {StringNotFound.TEntry}} {
				set error 1
				$widgets(loops,results) insert end	\
					[mc "ERROR: Ambiguous register name %s\n" $i]
			}

			if {$error} {
				$widgets(loops,results) configure -state disabled
				return 0
			}
		}
		$widgets(loops,results) insert end [mc "; START: Wait loop, time: %s %s\n; Clock: %s kHz (%s)\n; Used registers: " [$widgets(loops,time_ent) get] [$widgets(loops,time_cb) get] [$widgets(loops,clock_cb) get] [$widgets(loops,clock_type_cb) get]]
		for {set i 0} {$i < $len} {incr i} {
			if {$i} {
				$widgets(loops,results) insert end ", "
			}
			$widgets(loops,results) insert end $reg($i)
		}
		$widgets(loops,results) insert end "\n"

		calculate_loops_AUX3 $len $is_spec [array get res] [array get reg]


		while {$rest > 514} {
			set final_results [calculate_loops_AUX2 [expr {$rest / 2.0}] $clock $is_spec]
			if {$final_results == {}} {
				return 0
			}
			set rest [lindex $final_results 0]
			calculate_loops_AUX3 [lindex $final_results 1] $is_spec [lindex $final_results 2] [array get reg]
		}

		if {$rest <= 4} {
			for {set i 0} {$i < 5} {incr i} {
				if {int(ceil($rest)) >= 0.5} {
					if {${::Editor::spaces_no_tabs}} {
						$widgets(loops,results) insert end "[string repeat { } ${::Editor::number_of_spaces}]NOP\n"
					} else {
						$widgets(loops,results) insert end "\tNOP\n"
					}
					set rest [expr {$rest - 1}]
				}
			}
		} else {
			if {[lindex $is_spec 0]} {
				set rest [expr {$rest - 1}]
			} else {
				set rest [expr {$rest - 2}]
			}
			set val [expr {int($rest / 2)}]
			set rest [expr {$rest - ($val * 2.0)}]
			if {$val == 256} {
				set val 0
			}

			set val [string range [format {%X} $val] end-1 end]
			set val "[string repeat {0} [expr {3 - [string length $val]}]]$val"

			if {${::Editor::spaces_no_tabs}} {
				$widgets(loops,results) insert end "[string repeat { } ${::Editor::number_of_spaces}]MOV[string repeat { } [expr {$e_no_of_spaces - 3}]]$reg(0), #${val}h\n"
				$widgets(loops,results) insert end "[string repeat { } ${::Editor::number_of_spaces}]DJNZ[string repeat { } [expr {$e_no_of_spaces - 4}]]$reg(0), \$\n"
				if {int(ceil($rest)) >= 0.5} {
					$widgets(loops,results) insert end "[string repeat { } ${::Editor::number_of_spaces}]NOP\n"
					set rest [expr {$rest - 1}]
				}
			} else {
				$widgets(loops,results) insert end "\tMOV\t$reg(0), #${val}h\n"
				$widgets(loops,results) insert end "\tDJNZ\t$reg(0), \$\n"
				if {int(ceil($rest)) >= 0.5} {
					$widgets(loops,results) insert end "\tNOP\n"
					set rest [expr {$rest - 1}]
				}
			}
		}
		set rest [expr {$rest * 1.0 / $clock}]
		$widgets(loops,results) insert end [mc "; Rest: %s\n" [adjust_rest $rest]]
		$widgets(loops,results) insert end [mc "; END: Wait loop"]

		set end [expr {int([$widgets(loops,results) index end])}]
		for {set i 1} {$i < $end} {incr i} {
			ASMsyntaxHighlight::highlight $widgets(loops,results) $i
		}
		$widgets(loops,results) configure -state disabled

		return 1
	}

	## Clear results of the last wait loop calculation
	 # @return void
	private method calculate_loops_clear_results {} {
		$widgets(loops,results) configure -state normal
		$widgets(loops,results) delete 0.0 end
		$widgets(loops,results) configure -state disabled

		calculate_loops_enable_copy 0
	}

	## Enable "Copy" button in page "Wait loops"
	 # @parm Bool enable - 1 == Enable; 0 == Disable
	 # @return void
	private method calculate_loops_enable_copy {enable} {
		if {$enable} {
			set enable {normal}
		} else {
			set enable {disabled}
		}
		$widgets(loops,copy_but) configure -state $enable
	}

	## Calulate time 0 or 1 preset values
	 # @return void
	public method calculate_timer01 {} {
		set time [$widgets(timer01,time_ent) get]
		if {$time == {} || $time == 0} {
			return 0
		}

		set clock [$widgets(timer01,clock_cb) get]
		if {$clock == {} || $clock == 0} {
			return 0
		}
		status_tip ""

		set ::SpecCalc::timer01_th_$obj_idx [mc "Do not change"]
		set ::SpecCalc::timer01_tl_$obj_idx [mc "Do not change"]
		set ::SpecCalc::timer01_rh_$obj_idx [mc "Do not change"]
		set ::SpecCalc::timer01_rl_$obj_idx [mc "Do not change"]
		set ::SpecCalc::timer01_repeats_$obj_idx [mc "Zero"]
		set ::SpecCalc::timer01_rest_$obj_idx [mc "none"]

		foreach w {th tl rh rl repeats rest} {
			$widgets(timer01,$w) configure -fg {#888888}
		}

		set time [expr {$time * [lindex {1.0 1000.0 1000000.0 1000000000.0} [$widgets(timer01,time_cb) current]]}]
		set clock [expr {$clock / [lindex {12000000.0 6000000.0 1000000.0} [$widgets(timer01,clock_type_cb) current]]}]
		set time [expr {$time * $clock}]
		set time_int [expr {int($time)}]

		set enhanced [subst -nocommands "\$::SpecCalc::spec_chb_$obj_idx"]
		set prescaler [$widgets(timer01,psc_cb) current]

		# Set default results
		set low		0
		set high	0
		set repeats	0
		set rest	0

		switch -- [$widgets(timer01,mode_cb) current] {
			{0} {	;# 9 -> 16 bit counter
				if {$enhanced} {
					set bits [expr {$prescaler + 9}]
				} else {
					set bits 13
				}
				set capacity [expr {1 << $bits}]
				set full_mask [expr {$capacity - 1}]
				set low_mask [expr {$full_mask >> 8}]

				# Determinate apparent number of repeats
				set repeats [expr {($time_int >> $bits) + 1}]
				# Calculate tempotary results
				if {[expr {!($time_int & $full_mask)}]} {
					incr repeats -1
					set stepsPerIter $full_mask
				} else {
					set stepsPerIter [expr {$time_int / $repeats}]
					set tmp [expr {$capacity - $stepsPerIter}]
					set low [expr {$tmp & $low_mask}]
					set high [expr {$tmp >> 5}]
					set rest [expr {$time_int - (($full_mask - $tmp) * $repeats)}]
				}

				# Perform correction
				if {$rest >= $stepsPerIter} {
					incr repeats [expr {$rest / $stepsPerIter}]
					set rest [expr {$rest % $stepsPerIter}]
				}

				set rest [expr {($rest + $time - $time_int) / $clock}]
				set rest [adjust_rest $rest]

				if {$repeats > 1} {
					return 0
				}

				set low [format {%X} $low]
				set low "[string repeat {0} [expr {3 - [string length $low]}]]${low}h"
				set high [format {%X} $high]
				set high "[string repeat {0} [expr {3 - [string length $high]}]]${high}h"

				set ::SpecCalc::timer01_tl_$obj_idx $low
				set ::SpecCalc::timer01_th_$obj_idx $high
				set ::SpecCalc::timer01_rest_$obj_idx $rest
				set ::SpecCalc::timer01_repeats_$obj_idx "One"

				foreach w {th tl rest} {
					$widgets(timer01,$w) configure -fg {#000000}
				}
			}
			{1} {	;# 16 bit (maybe auto-reload)

				# Determinate apparent number of repeats
				set repeats [expr {($time_int >> 16) + 1}]
				# Calculate tempotary results
				if {[expr {!($time_int & 0xFFFF)}]} {
					incr repeats -1
					set stepsPerIter 0xFFFF
					set tmp 0
				} else {
					set stepsPerIter [expr {$time_int / $repeats}]
					set tmp [expr {0x10000 - $stepsPerIter}]
					set low [expr {$tmp & 0xFF}]
					set high [expr {$tmp >> 8}]
					set rest [expr {$time_int - ((0xFFFF - $tmp) * $repeats)}]
				}

				# Perform correction
				if {$rest >= $stepsPerIter} {
					incr repeats [expr {$rest / $stepsPerIter}]
					set rest [expr {$rest % $stepsPerIter}]
				}

				incr tmp -$rest
				if {$tmp < 0} {
					set rest [expr {abs($tmp)}]
					set tmp 0
				} else {
					set rest 0
				}
				set tmp [expr {$tmp & 0x0FFFF}]
				set low_p [expr {$tmp & 0xFF}]
				set high_p [expr {$tmp >> 8}]

				set rest [expr {($rest + $time - $time_int) / $clock}]
				set rest [adjust_rest $rest]

				set low [format {%X} $low]
				set low "[string repeat {0} [expr {3 - [string length $low]}]]${low}h"
				set high [format {%X} $high]
				set high "[string repeat {0} [expr {3 - [string length $high]}]]${high}h"
				set low_p [format {%X} $low_p]
				set low_p "[string repeat {0} [expr {3 - [string length $low_p]}]]${low_p}h"
				set high_p [format {%X} $high_p]
				set high_p "[string repeat {0} [expr {3 - [string length $high_p]}]]${high_p}h"

				if {$enhanced} {
					set ::SpecCalc::timer01_tl_$obj_idx $low_p
					set ::SpecCalc::timer01_th_$obj_idx $high_p
					set ::SpecCalc::timer01_rl_$obj_idx $low
					set ::SpecCalc::timer01_rh_$obj_idx $high
					set ::SpecCalc::timer01_rest_$obj_idx $rest
					set ::SpecCalc::timer01_repeats_$obj_idx $repeats
					foreach w {rh rl tl th rest repeats} {
						$widgets(timer01,$w) configure -fg {#000000}
					}
				} else {
					if {$repeats > 1} {
						status_tip [mc "Value is too high"]
						return 0
					}
					set ::SpecCalc::timer01_tl_$obj_idx $low
					set ::SpecCalc::timer01_th_$obj_idx $high
					set ::SpecCalc::timer01_rest_$obj_idx $rest
					set ::SpecCalc::timer01_repeats_$obj_idx [mc "One"]
					foreach w {th tl rest} {
						$widgets(timer01,$w) configure -fg {#000000}
					}
				}
			}
			{2} {	;# 8 bit auto reload

				# Determinate apparent number of repeats
				set repeats [expr {($time_int >> 8) + 1}]
				# Calculate tempotary results
				if {[expr {!($time_int & 0xFF)}]} {
					incr repeats -1
					set stepsPerIter 0xFF
				} else {
					set stepsPerIter [expr {$time_int / $repeats}]
					set low [expr {0x100 - $stepsPerIter}]
					set high $low
					set rest [expr {$time_int - ((0xFF - $low) * $repeats)}]
				}

				# Perform correction
				if {$rest >= $stepsPerIter} {
					incr repeats [expr {$rest / $stepsPerIter}]
					set rest [expr {$rest % $stepsPerIter}]
				}

				incr low -$rest
				if {$low < 0} {
					set rest [expr {abs($low)}]
					set low 0
				} else {
					set rest 0
				}

				set rest [expr {($rest + $time - $time_int) / $clock}]
				set rest [adjust_rest $rest]

				set low [format {%X} $low]
				set low "[string repeat {0} [expr {3 - [string length $low]}]]${low}h"
				set high [format {%X} $high]
				set high "[string repeat {0} [expr {3 - [string length $high]}]]${high}h"

				set ::SpecCalc::timer01_tl_$obj_idx $low
				set ::SpecCalc::timer01_th_$obj_idx $high
				set ::SpecCalc::timer01_rest_$obj_idx $rest
				set ::SpecCalc::timer01_repeats_$obj_idx $repeats

				foreach w {th tl rest repeats} {
					$widgets(timer01,$w) configure -fg {#000000}
				}
			}
		}

		return 1
	}

	## Calulate time 2 preset values
	 # @return void
	public method calculate_timer2 {} {
		set time [$widgets(timer2,time_ent) get]
		if {$time == {} || $time == 0} {
			return 0
		}

		set clock [$widgets(timer2,clock_cb) get]
		if {$clock == {} || $clock == 0} {
			return 0
		}
		status_tip ""

		set ::SpecCalc::timer2_rcal2h_$obj_idx [mc "Do not change"]
		set ::SpecCalc::timer2_rcal2l_$obj_idx [mc "Do not change"]
		set ::SpecCalc::timer2_t2l_$obj_idx [mc "Do not change"]
		set ::SpecCalc::timer2_t2h_$obj_idx [mc "Do not change"]
		set ::SpecCalc::timer2_repeats_$obj_idx [mc "Zero"]
		set ::SpecCalc::timer2_rest_$obj_idx [mc "none"]

		foreach w {rcal2h rcal2l t2h t2l repeats rest} {
			$widgets(timer2,$w) configure -fg {#888888}
		}

		set time [expr {$time * [lindex {1.0 1000.0 1000000.0 1000000000.0} [$widgets(timer2,time_cb) current]]}]
		set clock [expr {$clock / [lindex {12000000.0 6000000.0 1000000.0} [$widgets(timer2,clock_type_cb) current]]}]
		set time [expr {$time * $clock}]
		set time_int [expr {int($time)}]
		set mode [$widgets(timer2,mode_cb) current]

		# Set default results
		set low		0
		set high	0
		set repeats	0
		set rest	0

		# Determinate apparent number of repeats
		set repeats [expr {($time_int >> 16) + 1}]

		if {$mode} {
			set tmp [expr {$time_int & 0xFFFF}]
			set low [expr {$tmp & 0xFF}]
			set high [expr {$tmp >> 8}]
			set rest [expr {$time - $time_int}]

			set low_p $low
			set high_p $high
		} else {
			# Calculate tempotary results
			if {[expr {!($time_int & 0xFFFF)}]} {
				incr repeats -1
				set stepsPerIter 0xFFFF
				set tmp 0
			} else {
				set stepsPerIter [expr {$time_int / $repeats}]
				set tmp [expr {0x10000 - $stepsPerIter}]
				set rest [expr {$time_int - ((0x10000 - $tmp) * $repeats)}]
				set low [expr {$tmp & 0xFF}]
				set high [expr {$tmp >> 8}]
			}

			# Perform correction
			if {$rest >= $stepsPerIter} {
				incr repeats [expr {$rest / $stepsPerIter}]
				set rest [expr {$rest % $stepsPerIter}]
			}

			incr tmp -$rest
			if {$tmp < 0} {
				set rest [expr {abs($tmp)}]
				set tmp 0
			} else {
				set rest 0
			}
			set tmp [expr {$tmp & 0x0FFFF}]
			set low_p [expr {$tmp & 0xFF}]
			set high_p [expr {$tmp >> 8}]

		}
		set rest [expr {($rest + $time - $time_int) / $clock}]
		set rest [adjust_rest $rest]

		set low [format {%X} $low]
		set low "[string repeat {0} [expr {3 - [string length $low]}]]${low}h"
		set high [format {%X} $high]
		set high "[string repeat {0} [expr {3 - [string length $high]}]]${high}h"
		set low_p [format {%X} $low_p]
		set low_p "[string repeat {0} [expr {3 - [string length $low_p]}]]${low_p}h"
		set high_p [format {%X} $high_p]
		set high_p "[string repeat {0} [expr {3 - [string length $high_p]}]]${high_p}h"

		if {!$mode} {
			set ::SpecCalc::timer2_rcal2l_$obj_idx $low
			set ::SpecCalc::timer2_rcal2h_$obj_idx $high
		}
		set ::SpecCalc::timer2_t2l_$obj_idx $low_p
		set ::SpecCalc::timer2_t2h_$obj_idx $high_p
		set ::SpecCalc::timer2_rest_$obj_idx $rest
		set ::SpecCalc::timer2_repeats_$obj_idx $repeats
		foreach w {rest repeats t2h t2l} {
			$widgets(timer2,$w) configure -fg {#000000}
		}
		if {!$mode} {
			foreach w {rcal2h rcal2l} {
				$widgets(timer2,$w) configure -fg {#000000}
			}
		}

		return 1
	}

	## Convert number of nano-seconds to something like this: "10 s"
	 # @parm Int rest_in_ns - Some amount of nano-seconds
	 # @return String - Human readable string
	private method adjust_rest {rest_in_ns} {
		set tmp $rest_in_ns

		if {$tmp == 0.0} {
			return "0"
		}

		set tmp [expr {ceil($tmp * 1000.0) / 1000.0}]

		set tmp_o $tmp
		set tmp [expr ($tmp / 1000.0)]
		if {$tmp != int($tmp)} {
			return "$tmp_o ns"
		}

		set tmp_o $tmp
		set tmp [expr ($tmp / 1000.0)]
		if {$tmp != int($tmp)} {
			return "$tmp_o us"
		}

		set tmp_o $tmp
		set tmp [expr ($tmp / 1000.0)]
		if {$tmp != int($tmp)} {
			return "$tmp_o ms"
		}

		return "$tmp s"
	}

	## Clear results from the last calculaton of timer 0/1 preset
	 # @return void
	private method calculate_timer01_clear_results {} {
		foreach w {rest rh rl th tl} {
			$widgets(timer01,$w) delete 0
		}
	}

	## Clear results from the last calculaton of timer 2 preset
	 # @return void
	private method calculate_timer2_clear_results {} {
		foreach w {rest rcal2l rcal2h} {
			$widgets(timer2,$w) delete 0
		}
	}

	## Clear results from the last calculaton of timer 2 clock output preset
	 # @return void
	private method calculate_timer2_clk_clear_results {} {
		set ::SpecCalc::timer2_clk_rcal2h_$obj_idx	{--}
		set ::SpecCalc::timer2_clk_rcal2l_$obj_idx	{--}
		set ::SpecCalc::timer2_clk_rcal2h_d_$obj_idx	{--}
		set ::SpecCalc::timer2_clk_rcal2l_d_$obj_idx	{--}
		set ::SpecCalc::timer2_clk_error_$obj_idx	{--}

		foreach w {rcal2h rcal2l rcal2h_d rcal2l_d error} {
			$widgets(timer2,clk_${w}) configure -fg {#888888}
		}
	}

	## Perform calculation intented for page "Timer 2 clock output"
	 # @return void
	public method calculate_timer2_clk {} {
		set o [subst -nocommands "\$::SpecCalc::timer2_clk_fosc_$obj_idx"]
		set f [subst -nocommands "\$::SpecCalc::timer2_clk_freq_$obj_idx"]
		set x [subst -nocommands "\$::SpecCalc::timer2_clk_x2_$obj_idx"]
		if {
			![string length $o] || ![string length $f] || ![string length $x] ||
			$f == 0 || $o == 0
		} then {
			calculate_timer2_clk_clear_results
			return 0
		}

		set hl [expr {int(0x10000 - ($o * 1.0 * pow(2,$x))/(2.0 * $f))}]
		set fr [expr {($o * 1.0 * pow(2,$x)) / (2.0 * (0x10000 - $hl))}]
		set e [expr {round(($fr - $f) * 100000.0 / $f) / 1000.0}]

		set h [expr {$hl >> 8}]
		set l [expr {$hl & 0x0FF}]

		set ::SpecCalc::timer2_clk_rcal2h_d_$obj_idx $h
		set ::SpecCalc::timer2_clk_rcal2l_d_$obj_idx $l
		set v [format {%X} $h]
		set v "[string repeat {0} [expr {3 - [string length $v]}]]${v}h"
		set ::SpecCalc::timer2_clk_rcal2h_$obj_idx $v
		set v [format {%X} $l]
		set v "[string repeat {0} [expr {3 - [string length $v]}]]${v}h"
		set ::SpecCalc::timer2_clk_rcal2l_$obj_idx $v
		set ::SpecCalc::timer2_clk_error_$obj_idx "$e %"


		foreach w {rcal2h rcal2l rcal2h_d rcal2l_d error} {
			$widgets(timer2,clk_${w}) configure -fg {#000000}
		}
	}

	## Perform calculation intented for page "SPI"
	 # @parm
	 # @parm
	 # @return void
	private method calculate_spi {type value} {
		set const [subst -nocommands "\$::SpecCalc::double_chb_$obj_idx"]

  		switch -- $type {
			{sck_ent00} {
				set freq [expr {$value * $const * 2}]
			}
			{sck_ent01} {
				set freq [expr {$value * $const * 8}]
			}
			{sck_ent10} {
				set freq [expr {$value * $const * 32}]
			}
			{sck_ent11} {
				set freq [expr {$value * $const * 64}]
			}
			{double_chb} {
				set const $value

				set freq [$widgets(spi,sck_ent00) get]
				if {![string length $freq]} {
					return 0
				}
				set freq [expr {$freq * ($const == 2 ? 1 : 2) * 2}]
			}
			default {
				return 0
			}
  		}

  		if {![string equal $type {sck_ent00}]} {
			$widgets(spi,sck_ent00) delete 0 end
			$widgets(spi,sck_ent00) insert end [expr {$freq / $const / 2.0}]
  		}
  		if {![string equal $type {sck_ent01}]} {
			$widgets(spi,sck_ent01) delete 0 end
			$widgets(spi,sck_ent01) insert end [expr {$freq / $const / 8.0}]
  		}
  		if {![string equal $type {sck_ent10}]} {
			$widgets(spi,sck_ent10) delete 0 end
			$widgets(spi,sck_ent10) insert end [expr {$freq / $const / 32.0}]
  		}
  		if {![string equal $type {sck_ent11}]} {
			$widgets(spi,sck_ent11) delete 0 end
			$widgets(spi,sck_ent11) insert end [expr {$freq / $const / 64.0}]
  		}

		set ::SpecCalc::spi_result_$obj_idx $freq
		return 1
	}

	## Perform certain calculation
	 # @parm String page	- Page ID
	 # @parm String type	- Orininator ID
	 # @parm String value	- Originator value
	 # @return void
	public method calc {page type value} {
		if {$calc_in_progress} {return 1}
		set calc_in_progress 1

		switch -- $page {
			{loops} {
				switch -glob -- $type {
					{time_ent} {
						if {![regexp {^[0-9]*(\.[0-9]*)?$} $value]} {
							set calc_in_progress 0
							return 0

						} elseif {![string length $value]} {
							$widgets(loops,time_ent) configure -style StringNotFound.TEntry

						} else {
							$widgets(loops,time_ent) configure -style TEntry
						}


						if {![string equal [$widgets(loops,$type) get] $value]} {
							calculate_loops_clear_results
						}
					}
					{time_cb} {
						calculate_loops_clear_results
					}
					{clock_cb} {
						if {![regexp {^[0-9]*(\.[0-9]*)?$} $value] || [string length $value] > 9} {
							set calc_in_progress 0
							return 0

						} elseif {![string length $value]} {
							$widgets(loops,clock_cb) configure -style SpecCalc_RedBg.TCombobox

						} else {
							$widgets(loops,clock_cb) configure -style TCombobox
						}

						calculate_loops_clear_results
					}
					{clock_type_cb} {
						calculate_loops_clear_results
					}
					{reg_ent?} {
						for {set i 0} {$i < 8} {incr i} {
							$widgets(loops,reg_ent$i) configure -style TEntry
						}

						for {set j 0} {$j < 8} {incr j} {
							for {set i 0} {$i < 8} {incr i} {
								if {[string equal "reg_ent$i" "reg_ent$j"]} {
									continue
								}

								if {[string equal $type "reg_ent$j"]} {
									set val $value
								} else {
									set val [$widgets(loops,reg_ent$j) get]
								}

								if {[string equal -nocase			\
										$val				\
										[$widgets(loops,reg_ent$i) get]	\
									]					\
								} then {
									$widgets(loops,reg_ent$i) configure -style StringNotFound.TEntry
									$widgets(loops,reg_ent$j) configure -style StringNotFound.TEntry
								}
							}
						}

						if {![string equal [$widgets(loops,$type) get] $value]} {
							calculate_loops_clear_results
						}

						set calc_in_progress 0
						return 1
					}
					{compute_but} {
						if {[calculate_loops]} {
							calculate_loops_enable_copy 1
						} else {
							calculate_loops_enable_copy 0
						}
					}
					{copy_but} {
						clipboard clear
						clipboard append [$widgets(loops,results) get 0.0 end]
					}
				}
			}
			{timer01} {
				switch -- $type {
					{time_ent} {
						if {![regexp {^[0-9]*(\.[0-9]*)?$} $value]} {
							set calc_in_progress 0
							return 0

						} elseif {![string length $value]} {
							$widgets(timer01,time_ent) configure -style StringNotFound.TEntry

						} else {
							$widgets(timer01,time_ent) configure -style TEntry
						}


						if {![string equal [$widgets(timer01,$type) get] $value]} {
							calculate_timer01_clear_results
						}
					}
					{time_cb} {
						if {![string equal [$widgets(timer01,$type) get] $value]} {
							calculate_timer01_clear_results
						}
					}
					{clock_cb} {
						if {![regexp {^[0-9]*(\.[0-9]*)?$} $value] || [string length $value] > 9} {
							set calc_in_progress 0
							return 0

						} elseif {![string length $value]} {
							$widgets(timer01,clock_cb) configure -style SpecCalc_RedBg.TCombobox
						} else {
							$widgets(timer01,clock_cb) configure -style TCombobox
						}

						if {![string equal [$widgets(timer01,$type) get] $value]} {
							calculate_timer01_clear_results
						}
					}
					{clock_type_cb} {
						if {![string equal [$widgets(timer01,$type) get] $value]} {
							calculate_timer01_clear_results
						}
					}
					{mode_cb} {
						if {![string equal [$widgets(timer01,$type) get] $value]} {
							calculate_timer01_clear_results
						}
					}
					{spec_chb} {
						if {$value} {
							grid $widgets(timer01,psc_lbl) -row 4 -column 0 -sticky w
							grid $widgets(timer01,psc_cb) -row 4 -column 1 -sticky w
							grid $widgets(timer01,rh_l) -row 3 -column 1 -sticky e
							grid $widgets(timer01,rl_l) -row 4 -column 1 -sticky e
							grid $widgets(timer01,rh) -row 3 -column 3 -sticky w
							grid $widgets(timer01,rl) -row 4 -column 3 -sticky w
							grid $widgets(timer01,eq3) -row 3 -column 2
							grid $widgets(timer01,eq4) -row 4 -column 2
						} else {
							grid forget $widgets(timer01,psc_lbl)
							grid forget $widgets(timer01,psc_cb)
							grid forget $widgets(timer01,rh_l)
							grid forget $widgets(timer01,rl_l)
							grid forget $widgets(timer01,rh)
							grid forget $widgets(timer01,rl)
							grid forget $widgets(timer01,eq3)
							grid forget $widgets(timer01,eq4)
						}
						calculate_timer01_clear_results
					}
					{psc_cb} {
						if {![regexp {^[[:digit:]]{0,3}$} $value]} {
							set calc_in_progress 0
							return 0

						} elseif {$value > 255} {
							set calc_in_progress 0
							return 0
						}


						if {![string equal [$widgets(timer01,$type) get] $value]} {
							calculate_timer01_clear_results
						}
					}
				}

				after idle "catch {$this calculate_timer01}"
				set calc_in_progress 0
				return 1
			}

			{timer2} {
				switch -- $type {
					{time_ent} {
						if {![regexp {^[0-9]*(\.[0-9]*)?$} $value]} {
							set calc_in_progress 0
							return 0

						} elseif {![string length $value]} {
							$widgets(timer2,time_ent) configure -style StringNotFound.TEntry

						} else {
							$widgets(timer2,time_ent) configure -style TEntry
						}


						if {![string equal [$widgets(timer2,$type) get] $value]} {
							calculate_timer2_clear_results
						}
					}
					{time_cb} {
						if {![string equal [$widgets(timer2,$type) get] $value]} {
							calculate_timer2_clear_results
						}
					}
					{clock_cb} {
						if {![regexp {^[0-9]*(\.[0-9]*)?$} $value] || [string length $value] > 9} {
							set calc_in_progress 0
							return 0

						} elseif {![string length $value]} {
							$widgets(timer2,clock_cb) configure -style SpecCalc_RedBg.TCombobox

						} else {
							$widgets(timer2,clock_cb) configure -style TCombobox
						}


						if {![string equal [$widgets(timer2,$type) get] $value]} {
							calculate_timer2_clear_results
						}
					}
					{clock_type_cb} {
						if {![string equal [$widgets(timer2,$type) get] $value]} {
							calculate_timer2_clear_results
						}
					}
					{mode_cb} {
						if {![string equal [$widgets(timer2,$type) get] $value]} {
							calculate_timer2_clear_results
						}
					}
				}

				after idle "catch {$this calculate_timer2}"
				set calc_in_progress 0
				return 1
			}
			{clk_timer2} {
				switch -- $type {
					{clk_freq} {
						if {![regexp {^[0-9]*(\.[0-9]*)?$} $value]} {
							set calc_in_progress 0
							return 0

						} elseif {![string length $value]} {
							$widgets(timer2,clk_freq) configure -style StringNotFound.TEntry

						} else {
							$widgets(timer2,clk_freq) configure -style TEntry
						}
					}
					{clk_fosc} {
						if {![regexp {^[0-9]*(\.[0-9]*)?$} $value]} {
							set calc_in_progress 0
							return 0

						} elseif {![string length $value]} {
							$widgets(timer2,clk_fosc) configure -style StringNotFound.TEntry

						} else {
							$widgets(timer2,clk_fosc) configure -style TEntry
						}
					}
					{clk_x2_cb} {
					}
				}

				after idle "catch {$this calculate_timer2_clk}"
				set calc_in_progress 0
				return 1
			}
			{spi} {
				switch -regexp $type -- {
					{double_chb} {
					}
					{(sck_ent00)|(sck_ent01)|(sck_ent10)|(sck_ent11)} {
						if {![regexp {^[0-9]*(\.[0-9]*)?$} $value]} {
							set calc_in_progress 0
							return 0

						} elseif {![string length $value]} {
							$widgets(spi,$type) configure -style StringNotFound.TEntry

						} else {
							$widgets(spi,$type) configure -style TEntry
						}
					}
				}

				if {[string length $value]} {
					$this calculate_spi $type $value
				}

				set calc_in_progress 0
				return 1
			}

		}

		set calc_in_progress 0
		return 1
	}

	## Show functional diagram of something
	 # @parm String section	- Section ID
	 # @parm String which	- More specific ID
	 # @return void
	public method show_diagram {section which} {
		switch -- $section {
			{timer01} {
				switch -- [$widgets(timer01,mode_cb) current] {
					0 {
						set title [mc "Timer 0/1 in mode 0"]
						if {[subst -nocommands "\${::SpecCalc::spec_chb_$obj_idx}"]} {
							set image {timer_01_0e}
						} else {
							set image {timer_01_0}
						}
					}
					1 {
						set title [mc "Timer 0/1 in mode 1"]
						if {[subst -nocommands "\${::SpecCalc::spec_chb_$obj_idx}"]} {
							set image {timer_01_1e}
						} else {
							set image {timer_01_1}
						}
					}
					2 {
						set title [mc "Timer 0/1 in mode 2"]
						if {[subst -nocommands "\${::SpecCalc::spec_chb_$obj_idx}"]} {
							set image {timer_01_2e}
						} else {
							set image {timer_01_2}
						}
					}
				}
			}
			{timer2} {
				set image {timer2_updown}
				set title [mc "Timer 2 as up/down counter"]
			}
			{uart} {
				switch -- $which {
					{0} {
						set image {timer_brg}
						set title [mc "Timer 1/2 as UART baud rate generator"]
					}
					{1} {
						set image {timer_brg}
						set title [mc "Timer 1/2 as UART baud rate generator"]
					}
					{2} {
						set image {ibrg_brg}
						set title [mc "Internal baud rate generator"]
					}
					default {
						return
					}
				}
			}
		}

		set dlg [toplevel .spec_calc_diagram_$diagram_counter -class [mc "Diagram or formula"] -bg ${::COMMON_BG_COLOR}]
		pack [label $dlg.image	\
			-image [image create photo -format png -file "${::ROOT_DIRNAME}/icons/other/$image.png"]
		] -fill both

		wm title $dlg $title
		wm iconphoto $dlg ::ICONS::16::info
		wm resizable $dlg 0 0

		incr diagram_counter
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

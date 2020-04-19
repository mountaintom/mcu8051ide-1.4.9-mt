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
if { ! [ info exists _SELECTMCU_TCL ] } {
set _SELECTMCU_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# This namespace implements "MCU selection" dialog.
#
# Usage:
#
#	Invocation of MCU selection dialog
#	==================================
#	SelectMCU::activate <parent> <initial_mcu_type xram_cap xcode_cap>
#		-> {mcu_type xdata xcode}
#
#
#	Other functions
#	==================================
#
#	SelectMCU::get_available_processors
#		-> List of available processors (e.g. {80C51 AT89C52 AT89C4051})
#
#	SelectMCU::get_processor_details processor_type
#		-> List of MCU definition (see proc. xml_data_parser1)
# --------------------------------------------------------------------------

namespace eval SelectMCU {
	# String: Path to MCUs definition file
	variable definition_file	"${::ROOT_DIRNAME}/data/mcus.xml"
	# List: available MCU vendors
	variable vendors		[list [mc "all"] "Atmel" "Intel"]
	variable selected_mcu		{}	;# List: Dialog return value {mcu_type xdata xcode}
	variable definition_data	{}	;# List: Values gained from $definition_file
	variable local_definition_data	{}	;# List: Basically the same as $definition_data but containing only the shown items
	variable mcu_names		{}	;# List: Available processors (and show in the list)
	variable maximum_xcode		0x10000	;# Int: Maximum external program memory (0x10000 - internal)
	variable vendor			[mc "all"]	;# String: Selected vendor

	## Variables related to GUI
	variable parent			;# Widget: Dialog parent (another window)
	variable win			;# Widget: Dialog window
	variable search_bar		;# Widget: Search bar entry box
	variable search_bar_clear	;# Widget: Search bar clear button
	variable listbox_widget		;# Widget: List box containing available MCUs
	variable value_lbl_uart		;# Widget: Label "UART:" - value
	variable value_lbl_voltage	;# Widget: Label "Operating voltage:" - value
	variable value_lbl_interrupts	;# Widget: Label "Interrupts:" - value
	variable value_lbl_timers	;# Widget: Label "Timers:" - value
	variable value_lbl_vendor	;# Widget: Label "Vendor" - value
	variable more_details_text	;# Widget: TextWidget "More details:"
	variable more_details_scrollbar	;# Widget: Scrollbar for $more_details_text
	variable details_xdata_aval	;# Widget: Frame containing scale and spinbox for XDATA memory
	variable details_xdata_note	;# Widget: Frame containing label "NOT available" for XDATA memory
	variable details_xcode_aval	;# Widget: Frame containing scale and spinbox for XCODE memory
	variable details_xcode_nota	;# Widget: Frame containing label "NOT available" for XCODE memory
	variable name_label		;# Widget: Label containing name of selected MCU
	variable image_label		;# Widget: Label with image for selected MCU
	variable xdata_scale		;# Widget: Scale for XDATA memory
	variable xdata_spinbox		;# Widget: SpinBox for XDATA memory
	variable xcode_scale		;# Widget: Scale for XCODE memory
	variable xcode_spinbox		;# Widget: SpinBox for XCODE memory

	## Variables related to XML parser
	variable current_element	;# String: Current XML element
	variable expected		;# String: Expected next XML element
	variable take_data		;# Bool: Take element data on next parsing cycle
	variable mcu_definition		;# List: Definition of MCU currently being parsed
	variable current_mcu		;# String: Name of MCU currently being parsed

	## Fonts used in the selection dialog
	if {$::GUI_AVAILABLE} {
		 # ListBox containing available fonts
		variable listbox_widget_font	[font create		\
			-family $::DEFAULT_FIXED_FONT			\
			-size [expr {int(-14 * $::font_size_factor)}]	\
			-weight bold					\
		]
		 # ListBox header -- label widget above the ListBox
		variable listbox_header_font	[font create		\
			-family $::DEFAULT_FIXED_FONT			\
			-size [expr {int(-14 * $::font_size_factor)}]	\
		]
		 # Label with the MCU name
		variable name_font		[font create	\
			-family {helvetica}				\
			-size [expr {int(-20 * $::font_size_factor)}]	\
			-weight bold					\
		]
		 # Labels like "Vendor:", "UART:", "Timers:", etc.
		variable normal_font		[font create		\
			-family {helvetica}				\
			-size [expr {int(-12 * $::font_size_factor)}]	\
		]
		 # Labels with values like for "Vendor:", "Timers:", etc.
		variable bold_font		[font create		\
			-family {helvetica}				\
			-size [expr {int(-12 * $::font_size_factor)}]	\
			-weight bold					\
		]
	}

	## Invoke MCU selection dialog
	 # @parm Widget Parent	- Dialog parent (some window)
	 # @parm String initial	- {Initial_MCU Initial_XDATA Initial_XCODE}
	 # @return List - {mcu_type xdata xcode} or {}
	proc activate {Parent initial} {
		variable parent		;# Widget: Dialog parent (another window)
		variable selected_mcu	;# List: Dialog return value {mcu_type xdata xcode}
		variable mcu_definition	;# List: Definition of MCU currently being parsed
		variable win		;# Widget: Dialog window
		variable search_bar	;# Widget: Search bar entry box

		# Initialize NS variables
		set parent		$Parent
		set selected_mcu	{}
		set mcu_definition	{}

		# Load MCU definition file
		if {![load_definition]} {return}
		set mcu_definition	{}

		create_gui	;# Create dialog GUI elements
		fill_gui	;# Initialize GUI elements

		# Finalize window creation
		wm iconphoto $win ::ICONS::16::kcmmemory
		wm title $win [mc "Choose MCU - MCU 8051 IDE"]
		if {$::font_size_factor > 1.0} {
			wm minsize $win 870 500
		} else {
			wm minsize $win 720 500
		}
		wm protocol $win WM_DELETE_WINDOW {
			::SelectMCU::cancel
		}
		wm transient $win $parent
		raise $win
		catch {
			grab $win
		}

		# Initialize search bar
		$search_bar insert end [lindex $initial 0]
		focus -force $search_bar
		$search_bar selection range 0 end

		set selected_mcu [lindex $initial 0]

		# Initialize XDATA & XCODE scales
		if {[lindex $initial 1]} {
			set ::SelectMCU::xdata_ena 1
			set ::SelectMCU::xdata_value [lindex $initial 1]
		} else {
			set ::SelectMCU::xdata_ena 0
			set ::SelectMCU::xdata_value 0
			xdata_disena
		}
		if {[lindex $initial 2]} {
			set ::SelectMCU::xcode_ena 1
			set ::SelectMCU::xcode_value [lindex $initial 2]
		} else {
			set ::SelectMCU::xcode_ena 0
			set ::SelectMCU::xcode_value 0
			xcode_disena
		}

		# Wait until the window is destroyed
		tkwait window $win

		# Create resulting string
		if {$selected_mcu == {}} {
			set result {}
		} else {
			if {${::SelectMCU::xdata_ena}} {
				set xdata ${::SelectMCU::xdata_value}
			} else {
				set xdata 0
			}
			if {${::SelectMCU::xcode_ena}} {
				set xcode ${::SelectMCU::xcode_value}
			} else {
				set xcode 0
			}

			if {$xdata == {}} {
				set xdata 0
			}
			if {$xcode == {}} {
				set xcode 0
			}
			set result [list $selected_mcu $xdata $xcode]
		}

		return $result
	}

	## Load MCU definitions into the ListBox
	 # @return void
	proc fill_gui {} {
		variable definition_data	;# List: Values gained from $definition_file
		variable local_definition_data	;# List: Basically the same as $definition_data but containing only the shown items
		variable listbox_widget		;# Widget: List box containing available MCUs
		variable listbox_widget_font	;# ListBox containing available fonts
		variable mcu_names		;# List: available processors
		variable vendor			;# String: Selected vendor

		set mcu_names {}
		set local_definition_data {}

		# Iterate over defined MCUs
		foreach mcu $definition_data {
			# Filter specific vendors
			if {$vendor != [mc "all"] && [lindex $mcu 11] != $vendor} {
				continue
			}

			lappend local_definition_data $mcu

			# MCU type
			set mcu_type [lindex $mcu 0]
			lappend mcu_names $mcu_type
			set text $mcu_type
			set len [string length $mcu_type]
			append text [string repeat { } [expr {24 - $len}]]

			# Size of program memory
			set str [lindex $mcu 3]
			append str { KB}
			set len [string length $str]
			append text [string repeat { } [expr {8 - $len}]] $str

			# Size of internal data memory
			set str [expr {[lindex $mcu 5] + [lindex $mcu 10]}]
			append str { B}
			set len [string length $str]
			append text [string repeat { } [expr {13 - $len}]] $str

			# Number of IO lines + processor frequency
			set str [lindex $mcu 6]
			set len [string length $str]
			append text [string repeat { } [expr {12 - $len}]] $str {     } [lindex $mcu 4]

			# Insert the text into the ListBox
			$listbox_widget insert end #auto	\
				-text $text -data $mcu_type	\
				-font $listbox_widget_font	\
				-image ::ICONS::16::kcmmemory
		}
	}

	## Create GUI elements of the selection dialog window
	 # @return void
	proc create_gui {} {
		variable win			;# Widget: Dialog window
		variable search_bar		;# Widget: Search bar entry box
		variable search_bar_clear	;# Widget: Search bar clear button
		variable listbox_widget		;# Widget: List box containing available MCUs
		variable value_lbl_uart		;# Widget: Label "UART:" - value
		variable value_lbl_voltage	;# Widget: Label "Operating voltage:" - value
		variable value_lbl_interrupts	;# Widget: Label "Interrupts:" - value
		variable value_lbl_timers	;# Widget: Label "Timers:" - value
		variable value_lbl_vendor	;# Widget: Label "Vendor" - value
		variable more_details_text	;# Widget: TextWidget "More details:"
		variable more_details_scrollbar	;# Widget: Scrollbar for $more_details_text
		variable details_xdata_aval	;# Widget: Frame containing scale and spinbox for XDATA memory
		variable details_xdata_note	;# Widget: Frame containing label "NOT available" for XDATA memory
		variable details_xcode_aval	;# Widget: Frame containing scale and spinbox for XCODE memory
		variable details_xcode_nota	;# Widget: Frame containing label "NOT available" for XCODE memory
		variable listbox_widget_font	;# ListBox containing available fonts
		variable listbox_header_font	;# ListBox header -- label widget above the ListBox
		variable bold_font		;# Labels with values like for "Vendor:", "Timers:", etc.
		variable normal_font		;# Labels like "Vendor:", "UART:", "Timers:", etc.
		variable name_font		;# Label with the MCU name
		variable name_label		;# Widget: Label containing name of selected MCU
		variable image_label		;# Widget: Label with image for selected MCU
		variable xdata_scale		;# Widget: Scale for XDATA memory
		variable xdata_spinbox		;# Widget: Scale for XDATA memory
		variable xcode_spinbox		;# Widget: SpinBox for XCODE memory
		variable xcode_scale		;# Widget: Scale for XCODE memory
		variable vendors		;# List: available MCU vendors

		# Create toplevel window
		set win [toplevel .selectmcu_dialog -class {Select MCU} -bg ${::COMMON_BG_COLOR}]

		# Create search bar widgets (but don't pack them)
		set search_bar_frame [frame $win.search_bar_frame]
		set search_bar_clear [ttk::button $search_bar_frame.clear_but	\
			-image ::ICONS::16::clear_left				\
			-command ::SelectMCU::clear_search_bar			\
			-state disabled						\
			-style Flat.TButton					\
		]
		DynamicHelp::add $search_bar_frame.clear_but	\
			-text [mc "Clear search bar"]
		set search_bar [ttk::entry $search_bar_frame.search_bar	\
			-validate all					\
			-validatecommand {::SelectMCU::search %P}	\
		]
		DynamicHelp::add $search_bar	\
			-text [mc "Search bar, enter something like \"C4051\""]

		# Create ListBox and its scrollbar
		set top_frame [frame $win.top_frame]
		set top_left_frame [frame $top_frame.left -bd 1 -relief sunken]
		set top_left_top_frame [frame $top_left_frame.top]
		set listbox_widget [ListBox $top_left_frame.listbox	\
			-selectfill 1 -bg {#FFFFFF} -bd 0 -height 0	\
			-selectbackground {#CCCCFF} -selectmode single	\
			-selectforeground {#0000AA}			\
			-highlightcolor {#BBBBFF}			\
			-highlightthickness 0 -padx 20 -deltay 20	\
			-yscrollcommand "$top_frame.scrollbar set"	\
		]
		if {[winfo exists $listbox_widget.c]} {
			bind $listbox_widget.c <Button-5>		{%W yview scroll +5 units; break}
			bind $listbox_widget.c <Button-4>		{%W yview scroll -5 units; break}
		}
		bind $listbox_widget		<<ListboxSelect>>	{::SelectMCU::select_item}
		$listbox_widget bindImage	<Double-1>		{::SelectMCU::close_window;#}
		$listbox_widget bindText	<Double-1>		{::SelectMCU::close_window;#}
		set tree_scrollbar [ttk::scrollbar $top_frame.scrollbar	\
			-orient vertical				\
			-command [list $listbox_widget yview]		\
		]
		# Create ListBox header
		pack [label $top_left_frame.header		\
			-font $listbox_header_font		\
			-bg {#DDDDDD} -bd 0 -padx 25		\
			-justify left  -anchor w		\
			-text [mc "Processor Type\t\tCODE/PMEM    IDATA/IRAM       GPIO    Frequency"]	\
		] -fill x

		# Create remaining parts of top frame and pack them
		pack [label $search_bar_frame.search_label	\
			-text [mc "Search:"]			\
		] -side left -padx 5
		pack $search_bar -fill x -expand 1 -side left
		pack $search_bar_clear -after $search_bar -side left
		pack [label $search_bar_frame.vendor_label	\
			-text [mc "  Vendor:"]			\
		] -side left -padx 5 -after $search_bar_clear
		pack [ttk::combobox $search_bar_frame.vendor_cb	\
			-state readonly				\
			-textvariable {::SelectMCU::vendor}	\
			-values $vendors			\
		] -side left -padx 5 -after $search_bar_frame.vendor_label
		bind $search_bar_frame.vendor_cb <<ComboboxSelected>> {::SelectMCU::change_vendor}
		pack $search_bar_frame -fill x -pady 10 -padx 5

		# Pack all frames except the bottom frame and the details frame
		pack $top_left_top_frame -fill x
		pack $listbox_widget -fill both -expand 1
		pack $top_left_frame -fill both -expand 1 -side left
		pack $tree_scrollbar -fill y -after $top_left_frame -side right
		pack $top_frame -fill both -expand 1 -padx 5

		# Create parts of details frame
		set details_frame	[frame $win.details_frame]
		set details_left	[frame $details_frame.left]
		set details_middle	[frame $details_frame.middle -width 300]
		set details_right	[frame $details_frame.right]
		set details_middle_top	[frame $details_middle.top]
		set details_middle_bottom [frame $details_middle.bottom]

		# Left side
		set name_label [label $details_left.name	\
			-text "" -font $name_font		\
		]
		set image_label [label $details_left.image	\
			-image [image create photo] -text { }	\
			-width 200 -height 200 -compound left	\
		]
		DynamicHelp::add $image_label -text [mc "One of available packages for selected microcontroller"]
		pack $name_label -fill x
		pack $image_label -padx 5

		# General features
		set i 0
		foreach text {{Vendor:} {UART:} {Operating voltage:} {Interrupt sources:} {Timers:}} {
			grid [label $details_middle_top.lbl_$i	\
				-text [mc $text]		\
				-justify left			\
				-font $normal_font		\
			] -row $i -column 0 -sticky w
			incr i
		}
		set value_lbl_vendor	[label $details_middle_top.value_lbl_vendor	\
			-justify left -anchor w -font $bold_font			\
		]
		set value_lbl_uart	[label $details_middle_top.value_lbl_uart	\
			-justify left -anchor w -font $bold_font			\
		]
		set value_lbl_voltage	[label $details_middle_top.value_lbl_voltage	\
			-justify left -anchor w -font $bold_font			\
		]
		set value_lbl_interrupts [label $details_middle_top.value_lbl_interr	\
			-justify left -anchor w -font $bold_font			\
		]
		set value_lbl_timers	[label $details_middle_top.value_lbl_timers	\
			-justify left -anchor w -font $bold_font			\
		]
		grid $value_lbl_vendor		-row 0 -column 1 -sticky we
		grid $value_lbl_uart		-row 1 -column 1 -sticky we
		grid $value_lbl_voltage		-row 2 -column 1 -sticky we
		grid $value_lbl_interrupts	-row 3 -column 1 -sticky we
		grid $value_lbl_timers		-row 4 -column 1 -sticky we
		grid columnconfigure $details_middle_top 0 -minsize 140
		grid columnconfigure $details_middle_top 1 -weight 1

		# Details
		set more_details_text [text $details_middle_bottom.text		\
			-yscrollcommand ::SelectMCU::details_scrollbar_set	\
			-width 0 -heigh 0 -bd 0 -relief flat -font $bold_font	\
			-highlightthickness 0 -state disabled -bg ${::COMMON_BG_COLOR}	\
			-cursor left_ptr -fg {#555555} -wrap word		\
		]
		set more_details_scrollbar [ttk::scrollbar	\
			$details_middle_bottom.scrollbar	\
			-command "$more_details_text yview"	\
			-orient vertical			\
		]
		pack $more_details_text -side left -fill both -expand 1

		# Pack general & details frames
		pack $details_middle_top -fill both -pady 10
		pack $details_middle_bottom -fill both -expand 1

		# Cretate XDATA and XCODE scales and such
		set details_right_top [ttk::labelframe $details_right.top	\
			-text [mc "External RAM (XDATA)"]				\
		]
		set details_right_bottom [ttk::labelframe $details_right.bottom	\
			-text [mc "External ROM/FLASH (XCODE)"]			\
		]

		set details_xdata_note [label $details_right_top.not_available	\
			-text [mc "NOT available"] -fg {#FF8888}		\
		]
		set details_xdata_aval [frame $details_right_top.available]
		pack [checkbutton $details_xdata_aval.checkbutton	\
			-variable ::SelectMCU::xdata_ena		\
			-text [mc "Enable"]				\
			-command ::SelectMCU::xdata_disena		\
		] -anchor w
		DynamicHelp::add $details_xdata_aval.checkbutton	\
			-text [mc "Connect external data memory"]
		set details_right_top_btm [frame $details_xdata_aval.btm]
		set xdata_scale [ttk::scale $details_right_top_btm.scale	\
			-orient horizontal					\
			-variable ::SelectMCU::xdata_value			\
			-from 0 -to 0x10000					\
			-command "
				set ::SelectMCU::xdata_value \[expr {int(\${::SelectMCU::xdata_value})}\]
				$details_right_top_btm.spinbox selection range 0 end
			#" \
		]
		DynamicHelp::add $details_right_top_btm.scale	\
			-text [mc "Amount of external data memory"]
		pack $xdata_scale -fill x -side left -expand 1 -padx 2
		set xdata_spinbox [ttk::spinbox $details_right_top_btm.spinbox	\
			-textvariable ::SelectMCU::xdata_value			\
			-width 5 -from 0 -to 0x10000				\
			-validate all						\
			-validatecommand {::SelectMCU::validate_xdata %P}	\
		]
		DynamicHelp::add $details_right_top_btm.spinbox	\
			-text [mc "Amount of external data memory"]
		pack $xdata_spinbox -side right -after $details_right_top_btm.scale
		pack $details_right_top_btm -fill both -expand 1

		set details_xcode_nota [label $details_right_bottom.not_available	\
			-text [mc "NOT available"] -fg {#FF8888}			\
		]
		set details_xcode_aval [frame $details_right_bottom.available]
		pack [checkbutton $details_xcode_aval.checkbutton	\
			-variable ::SelectMCU::xcode_ena		\
			-text [mc "Enable"]				\
			-command ::SelectMCU::xcode_disena		\
		] -anchor w
		DynamicHelp::add $details_xcode_aval.checkbutton	\
			-text [mc "Connect external program memory"]
		set details_right_bottom_btm [frame $details_xcode_aval.btm]
		set xcode_scale [ttk::scale $details_right_bottom_btm.scale	\
			-orient horizontal					\
			-variable ::SelectMCU::xcode_value			\
			-from 0 -to 0x10000					\
			-command "
				set ::SelectMCU::xcode_value \[expr {int(\${::SelectMCU::xcode_value})}\]
			#" \
		]
		DynamicHelp::add $details_right_bottom_btm.scale	\
			-text [mc "Amount of total program memory minus internal program memory"]
		pack $xcode_scale -fill x -side left -expand 1 -padx 2
		set xcode_spinbox [ttk::spinbox $details_right_bottom_btm.spinbox	\
			-textvariable ::SelectMCU::xcode_value				\
			-width 5 -from 0 -to 0x10000					\
			-validate all							\
			-validatecommand {::SelectMCU::validate_xcode %P}		\
		]
		DynamicHelp::add $details_right_bottom_btm.spinbox	\
			-text [mc "Amount of total program memory minus internal program memory"]
		pack $xcode_spinbox -side right -after $details_right_bottom_btm.scale
		pack $details_right_bottom_btm -fill both -expand 1

		grid $details_right_top		-row 0 -column 0 -sticky wens -padx 5 -pady 10
		grid $details_right_bottom	-row 1 -column 0 -sticky wens -padx 5 -pady 10
		grid rowconfigure $details_right 0 -minsize 100
		grid rowconfigure $details_right 1 -minsize 100
		grid columnconfigure $details_right 0 -weight 1 -minsize 180

		# Pack parts of details frame
		pack $details_left -side left
		pack $details_middle -side left -fill both -expand 1 -padx 15 -pady 10
		pack $details_right -side right -fill y -after $details_middle -padx 5
		pack $details_frame -fill x -padx 5 -pady 10

		# Create and pack 'OK' and 'CANCEL' buttons
		set buttonFrame [frame $win.buttonFrame]
		pack [ttk::button $buttonFrame.ok		\
			-text [mc "Ok"]				\
			-compound left				\
			-image ::ICONS::16::ok			\
			-command {::SelectMCU::close_window}	\
		] -side left -padx 2
		pack [ttk::button $buttonFrame.cancel		\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command {::SelectMCU::cancel} 		\
		] -side left -padx 2
		pack [ttk::separator $win.sep -orient horizontal] -fill x
		pack $buttonFrame -side bottom -after $details_frame -anchor e -padx 5 -pady 5
	}

	## Close MCU selection dialog and force its return value to an empty string
	 # @return void
	proc close_window {} {
		variable definition_data	;# List: Values gained from $definition_file
		variable mcu_names		;# List: available processors
		variable win			;# Widget: Dialog window

		set definition_data {}
		set mcu_names {}
		grab release $win
		destroy $win
	}

	## Load MCU database
	 # @return void
	proc load_definition {} {
		variable parent			;# Widget: Dialog parent (another window)
		variable definition_file	;# String: Path to MCUs definition file
		variable definition_data	;# List: Values gained from $definition_file
		variable mcu_definition		;# List: Definition of MCU currently being parsed
		variable expected		;# String: Expected next XML element
		variable take_data		;# Bool: Take element data on next parsing cycle

		# Initialize NS variables
		set definition_data	{}
		set mcu_definition	{}
		set expected		{mcus}
		set current_element	{}
		set take_data		0

		# Open definition file
		if {[catch {
			set file [open $definition_file {r}]
		}]} then {
			tk_messageBox		\
				-parent $parent	\
				-type ok	\
				-icon warning	\
				-title mcus.xml	\
				-message [mc "Unable to open file containing supported MCUs,\nplease check your installation"]
			return 0
		}

		# Create XML parser
		set parser [::xml::parser -final 1 -ignorewhitespace 1			\
			-elementstartcommand {::SelectMCU::xml_data_parser0_element}	\
			-characterdatacommand {::SelectMCU::xml_data_parser0_data}	\
		]

		# Start XML parser
		if {[catch {
			$parser parse [read $file]
			if {$mcu_definition != {}} {
				foreach val $mcu_definition {
					if {$val == {}} {
						error "Incomplete definition for [lindex $mcu_definition 0]"
					}
				}
				lappend definition_data $mcu_definition
			}
		} result]} then {
			set definition_data {}
			tk_messageBox		\
				-parent $parent	\
				-icon warning	\
				-type ok	\
				-title [mc "Error"]	\
				-message [mc "MCUs database file is corrupted (code:600),\nplease check your installation"]
			puts stderr $result
			close $file
			return 0
		}

		# Close file and free parser
		close $file
		$parser free
		return 1
	}

	## Get list of MCUs defined in the database
	 # @return List - Defined processors (e.g. {8051 AT89C2051 ...})
	proc get_available_processors {} {
		variable definition_data	;# List: Values gained from $definition_file
		variable definition_file	;# String: Path to MCUs definition file
		variable expected		;# String: Expected next XML element

		# Initialize NS variables
		set expected		{mcus}
		set definition_data	{}	;# <-- Result will be stored here

		# Open database file
		if {[catch {
			set file [open $definition_file {r}]
		}]} then {
			puts stderr "Unable to open file containing supported MCUs, please check your installation"
			return {}
		}

		# Create XML parser
		set parser [::xml::parser -final 1 -ignorewhitespace 1			\
			-elementstartcommand {::SelectMCU::xml_data_parser2_element}	\
		]

		# Start XML parser
		if {[catch {
			$parser parse [read $file]
		} result]} then {
			set definition_data {}
			puts stderr "MCUs database file is corrupted (code:641),\nplease check your installation"
			puts stderr $result
		}

		# Close file and free parser
		close $file
		$parser free
		return $definition_data
	}

	## Gain detail description for the given processor
	 # @parm String mcu_name - Processor type (e.g. AT89C51RC)
	 # @return List - (see proc. xml_data_parser1)
	proc get_processor_details {mcu_name} {
		variable definition_file	;# String: Path to MCUs definition file
		variable definition_data	;# List: Values gained from $definition_file
		variable expected		;# String: Expected next XML element
		variable take_data		;# Bool: Take element data on next parsing cycle
		variable mcu_definition		;# List: Definition of MCU currently being parsed
		variable current_mcu		;# String: Name of MCU currently being parsed

		# Initialize NS variables
		set mcu_definition	$mcu_name
		set expected		{mcus}
		set definition_data	{}	;# <-- Result will be stored here
		set take_data		0
		set current_mcu		{}

		# Open database file
		if {[catch {
			set file [open $definition_file {r}]
		}]} then {
			puts stderr "Unable to open file containing supported MCUs, please check your installation"
			return {}
		}

		# Create XML parser
		set parser [::xml::parser -final 1 -ignorewhitespace 1			\
			-elementstartcommand {::SelectMCU::xml_data_parser1_element}	\
			-characterdatacommand {::SelectMCU::xml_data_parser1_data}	\
		]

		# Start XML parser
		if {[catch {
			$parser parse [read $file]
		} result]} then {
			set definition_data {}
			puts stderr "MCUs database file is corrupted (code:688),\nplease check your installation"
			puts stderr $result
		}

		# Close file and free parser
		close $file
		$parser free
		return $definition_data
	}

	## XML parser handler for procedure get_available_processors -- Takes XML tags
	 # @parm String arg1	- name of the element
	 # @parm List attrs	- list of attributes '{attr0 val0 attr1 val1 ...}'
	 # @return void
	proc xml_data_parser2_element {arg1 attrs} {
		variable definition_data	;# List: Values gained from $definition_file
		variable expected		;# String: Expected next XML element

		# Check for consistent formatting
		if {$arg1 != $expected} {
			error "Bad element `$arg1'"
		}

		switch -- $arg1 {
			{mcus} {
				set expected {mcu}
			}
			{mcu} {
				set expected {timers}
				set len [llength $attrs]

				# Search for attribute "name"
				for {set i 0} {$i < $len} {incr i 2} {
					set val [lindex $attrs $i]
					if {$val == {name}} {
						# Append MCU name to result
						incr i
						lappend definition_data [lindex $attrs $i]
						break
					}
				}
			}
			{timers}	{set expected {more}}
			{more}		{set expected {bits}}
			{bits}		{set expected {writeonly}}
			{writeonly}	{set expected {sfr}}
			{sfr}		{set expected {mcu}}
		}
	}


	## XML parser handler for procedure get_processor_details -- Takes XML data
	 # @parm String arg1	- content of the element
	 # @return void
	proc xml_data_parser1_data {arg1} {
		variable definition_data	;# List: Values gained from $definition_file
		variable expected		;# String: Expected next XML element
		variable mcu_definition		;# List: Definition of MCU currently being parsed
		variable current_element	;# String: Current XML element
		variable take_data		;# Bool: Take element data on next parsing cycle

		# Take data only if they were expected
		if {!$take_data} {return}
		set take_data 0

		# Take data section only for 1 processor
		if {$mcu_definition == {} || ![llength $definition_data]} {
			return
		}

		# Adjust data string
		set arg1 [string trim $arg1]
		regsub {\s+} $arg1 { } arg1

		# Validate and store data
		switch -- $current_element {
			{bits} {	;# Incomplete registers
				if {![regexp {([0-9A-Fa-f]{4})?(\s+[0-9A-Fa-f]{4})*} $arg1]} {
					error "MCUs database file corrupted"
				}
				lset definition_data 18 $arg1
			}
			{writeonly} {	;# Write only registers
				if {![regexp {([0-9A-Fa-f]{2})?(\s+[0-9A-Fa-f]{2})*} $arg1]} {
					error "MCUs database file corrupted"
				}
				lset definition_data 19 $arg1
			}
			{sfr} {	;# available special function registers and bit addressable bits in SFR
				lset definition_data 43 $arg1

				set mcu_definition {}	;# This is the last tag
			}
		}
	}

	## XML parser handler for procedure get_processor_details -- Takes XML tags
	 # @parm String arg1	- name of the element
	 # @parm List attrs	- list of attributes '{attr0 val0 attr1 val1 ...}'
	 # @return void
	proc xml_data_parser1_element {arg1 attrs} {
		variable definition_data	;# List: Values gained from $definition_file
		variable expected		;# String: Expected next XML element
		variable mcu_definition		;# List: Definition of MCU currently being parsed
		variable current_mcu		;# String: Name of MCU currently being parsed
		variable current_element	;# String: Current XML element
		variable take_data		;# Bool: Take element data on next parsing cycle

		set take_data 0

		## Take tag attributes
		set current_element $arg1
		if {$arg1 != $expected} {
			error "Bad element `$arg1'"
		}
		switch -- $arg1 {
			{mcus} {
				set expected {mcu}
			}
			{mcu} {
				set expected {timers}
				set len [llength $attrs]

				for {set i 0} {$i < $len} {incr i 2} {
					set val [lindex $attrs $i]
					if {$val == {name}} {
						incr i
						set current_mcu [lindex $attrs $i]
						if {$mcu_definition != $current_mcu} {
							return
						}
					}
				}

				set definition_data [list		\
					{} {} {} {}	{} {} {} {}	\
					{} {} {} {}	{} {} {} {}	\
					{} {} {} {}	{} {} {} {}	\
					{} {} {} {}	{} {} {} {}	\
					{} {} {} {}	{} {} {} {}	\
					{} {} {} {}			\
				]

				for {set i 0} {$i < $len} {incr i} {
					switch -- [lindex $attrs $i] {
						{xdata} {
							incr i
							xml_dp1_attr_yes_no 0 [lindex $attrs $i]
						}
						{xcode} {
							incr i
							xml_dp1_attr_yes_no 1 [lindex $attrs $i]
						}
						{code} {
							incr i
							set val [lindex $attrs $i]
							if {![string is digit -strict $val] || $val < 0 || $val > 0x10000} {
								error "MCUs database file corrupted"
							}
							lset definition_data 2 $val
						}
						{ram} {
							incr i
							set val [lindex $attrs $i]
							if {![string is digit -strict $val] || $val < 0 || $val > 256} {
								error "MCUs database file corrupted"
							}
							lset definition_data 3 $val
						}
						{portbits} {
							incr i
							set val [lindex $attrs $i]
							if {![string is digit -strict $val] || $val < 0 || $val > 256} {
								error "MCUs database file corrupted"
							}
							lset definition_data 4 $val
						}
						{uart} {
							incr i
							xml_dp1_attr_yes_no 5 [lindex $attrs $i]
						}
						{timer2} {
							incr i
							xml_dp1_attr_yes_no 6 [lindex $attrs $i]
						}
						{watchdog} {
							incr i
							xml_dp1_attr_yes_no 7 [lindex $attrs $i]
						}
						{eram} {
							incr i
							set val [lindex $attrs $i]
							if {![string is digit -strict $val] || $val < 0 || $val > 0x10000} {
								error "MCUs database file corrupted"
							}
							lset definition_data 8 $val
						}
						{dualdtpr} {
							incr i
							xml_dp1_attr_yes_no 9 [lindex $attrs $i]
						}
						{auxr} {
							incr i
							xml_dp1_attr_yes_no 10 [lindex $attrs $i]
						}
						{t2mod} {
							incr i
							xml_dp1_attr_yes_no 11 [lindex $attrs $i]
						}
						{port0} {
							incr i
							set val [lindex $attrs $i]
							if {$val != {} && ![regexp {^[01]{8}$} $val]} {
								error "MCUs database file corrupted"
							}
							lset definition_data 12 $val
						}
						{port1} {
							incr i
							set val [lindex $attrs $i]
							if {$val != {} && ![regexp {^[01]{8}$} $val]} {
								error "MCUs database file corrupted"
							}
							lset definition_data 13 $val
						}
						{port2} {
							incr i
							set val [lindex $attrs $i]
							if {$val != {} && ![regexp {^[01]{8}$} $val]} {
								error "MCUs database file corrupted"
							}
							lset definition_data 14 $val
						}
						{port3} {
							incr i
							set val [lindex $attrs $i]
							if {$val != {} && ![regexp {^[01]{8}$} $val]} {
								error "MCUs database file corrupted"
							}
							lset definition_data 15 $val
						}
						{port4} {
							incr i
							set val [lindex $attrs $i]
							if {$val != {} && ![regexp {^[01]{8}$} $val]} {
								error "MCUs database file corrupted"
							}
							lset definition_data 16 $val
						}
						{pof} {
							incr i
							xml_dp1_attr_yes_no 17 [lindex $attrs $i]
						}
						{gf0} {
							incr i
							xml_dp1_attr_yes_no 20 [lindex $attrs $i]
						}
						{gf1} {
							incr i
							xml_dp1_attr_yes_no 21 [lindex $attrs $i]
						}
						{pd} {
							incr i
							xml_dp1_attr_yes_no 22 [lindex $attrs $i]
						}
						{idl} {
							incr i
							xml_dp1_attr_yes_no 23 [lindex $attrs $i]
						}
						{smod0} {
							incr i
							xml_dp1_attr_yes_no 24 [lindex $attrs $i]
						}
						{iph} {
							incr i
							xml_dp1_attr_yes_no 25 [lindex $attrs $i]
						}
						{acomparator} {
							incr i
							xml_dp1_attr_yes_no 26 [lindex $attrs $i]
						}
						{euart} {
							incr i
							xml_dp1_attr_yes_no 27 [lindex $attrs $i]
						}
						{clkreg} {
							incr i
							xml_dp1_attr_yes_no 28 [lindex $attrs $i]
						}
						{pwdex} {
							incr i
							xml_dp1_attr_yes_no 29 [lindex $attrs $i]
						}
						{spi} {
							incr i
							xml_dp1_attr_yes_no 30 [lindex $attrs $i]
						}
						{wdtcon} {
							incr i
							xml_dp1_attr_yes_no 31 [lindex $attrs $i]
						}
						{eeprom} {
							incr i
							set val [lindex $attrs $i]
							if {![string is digit -strict $val]} {
								error "MCUs database file corrupted"
							}
							lset definition_data 32 $val
						}
						{intelpe} {
							incr i
							xml_dp1_attr_yes_no 33 [lindex $attrs $i]
						}
						{pwm} {
							incr i
							xml_dp1_attr_yes_no 34 [lindex $attrs $i]
						}
						{x2reset} {
							incr i
							xml_dp1_attr_yes_no 35 [lindex $attrs $i]
						}
						{ckcon} {
							incr i
							xml_dp1_attr_yes_no 36 [lindex $attrs $i]
						}
						{auxr1gf3} {
							incr i
							xml_dp1_attr_yes_no 37 [lindex $attrs $i]
						}
						{ao} {
							incr i
							xml_dp1_attr_yes_no 38 [lindex $attrs $i]
						}
						{wdtprg} {
							incr i
							xml_dp1_attr_yes_no 39 [lindex $attrs $i]
						}
						{hddptr} {
							incr i
							xml_dp1_attr_yes_no 40 [lindex $attrs $i]
						}
						{auxrwdidle} {
							incr i
							xml_dp1_attr_yes_no 41 [lindex $attrs $i]
						}
						{auxrdisrto} {
							incr i
							xml_dp1_attr_yes_no 42 [lindex $attrs $i]
						}
						default {
							incr i
						}
					}
				}
			}
			{timers} {
				set expected {more}
			}
			{more} {
				set expected {bits}
			}
			{bits} {
				if {$mcu_definition == $current_mcu} {
					set take_data 1
				}
				set expected {writeonly}
			}
			{writeonly} {
				if {$mcu_definition == $current_mcu} {
					set take_data 1
				}
				set expected {sfr}
			}
			{sfr} {
				if {$mcu_definition == $current_mcu} {
					set take_data 1
				}
				set expected {mcu}
			}
		}
	}

	## Auxiliary procedure for xml_data_parser1
	 # Invoke error if the given value was neither "yes" nor "no"
	 # @parm Int index	- Index in list $definition_data
	 # @parm String value	- Value to set in $definition_data
	 # @return void
	proc xml_dp1_attr_yes_no {index value} {
		variable definition_data	;# List: Values gained from $definition_file

		if {$value != {yes} && $value != {no}} {
			error "MCUs database file corrupted"
		}
		lset definition_data $index $value
	}

	## XML parser handler for procedure load_definition -- takes XML tags
	 # @parm String arg1	- name of the element
	 # @parm List attrs	- list of attributes '{attr0 val0 attr1 val1 ...}'
	 # @return void
	proc xml_data_parser0_element {arg1 attrs} {
		variable definition_data	;# List: Values gained from $definition_file
		variable expected		;# String: Expected next XML element
		variable current_element	;# String: Current XML element
		variable take_data		;# Bool: Take element data on next parsing cycle
		variable mcu_definition		;# List: Definition of MCU currently being parsed
		variable vendors		;# List: available MCU vendors

		if {$arg1 != $expected} {
			error "Bad element `$arg1'"
		}
		set current_element $arg1
		switch -- $arg1 {
			{mcus} {
				set expected {mcu}
			}
			{mcu} {
				if {$mcu_definition != {}} {
					foreach val $mcu_definition {
						if {$val == {}} {
							error "Incomplete definition for [lindex $mcu_definition 0]"
						}
					}
					lappend definition_data $mcu_definition
				}
				set expected {timers}
				set mcu_definition [list {} {} {} {} {} {} {} {} {} {} {} {}]
				for {set i 0} {$i < [llength $attrs]} {incr i} {
					switch -- [lindex $attrs $i] {
						{name} {
							incr i
							set val [lindex $attrs $i]
							if {![string is alnum -strict $val]} {
								error "MCU name must match ^\[\w\d\]+$"
							}
							lset mcu_definition 0 $val
						}
						{xdata} {
							incr i
							set val [lindex $attrs $i]
							if {$val != {yes} && $val != {no}} {
								error "Attribute XDATA must have value \"yes\" or \"no\""
							}
							lset mcu_definition 1 $val
						}
						{xcode} {
							incr i
							set val [lindex $attrs $i]
							if {$val != {yes} && $val != {no}} {
								error "Attribute XCODE must have value \"yes\" or \"no\""
							}
							lset mcu_definition 2 $val
						}
						{code} {
							incr i
							set val [lindex $attrs $i]
							if {![string is digit -strict $val] || $val < 0 || $val > 65536} {
								error "CODE memory capacity must be an integer value \[0;65536\]"
							}
							lset mcu_definition 3 $val
						}
						{frequency} {
							incr i
							set val [lindex $attrs $i]
							if {[string length $val] > 16 || ![string is print $val]} {
								error "Attribute FREQUENCY must be printable string (max. 16 characters)"
							}
							lset mcu_definition 4 $val
						}
						{ram} {
							incr i
							set val [lindex $attrs $i]
							if {![string is digit -strict $val] || $val < 0 || $val > 256} {
								error "RAM capacity must be an integer value \[0;256\]"
							}
							lset mcu_definition 5 $val
						}
						{portbits} {
							incr i
							set val [lindex $attrs $i]
							if {![string is digit -strict $val] || $val < 0 || $val > 256} {
								error "Attribute PORTBITS must be an integer value \[0;256\]"
							}
							lset mcu_definition 6 $val
						}
						{uart} {
							incr i
							set val [lindex $attrs $i]
							if {$val != {yes} && $val != {no}} {
								error "Attribute UART must be either \"yes\" or \"no\""
							}
							lset mcu_definition 7 $val
						}
						{interrupts} {
							incr i
							set val [lindex $attrs $i]
							if {![string is digit -strict $val] || $val < 0 || $val > 99} {
								error "Attribute INTERRUPTS must be an integer value \[0;99\]"
							}
							lset mcu_definition 8 $val
						}
						{voltage} {
							incr i
							set val [lindex $attrs $i]
							if {[string length $val] > 11 || ![string is print $val]} {
								error "Attribute VOLTAGE must be printable string (max. 11 characters)"
							}
							lset mcu_definition 9 $val
						}
						{eram} {
							incr i
							set val [lindex $attrs $i]
							if {![string is digit -strict $val] || $val < 0 || $val > 65536} {
								error "ERAM capacity must be an integer value \[0;65536\]"
							}
							lset mcu_definition 10 $val
						}
						{vendor} {
							incr i
							set val [lindex $attrs $i]
							if {[lsearch $vendors $val] == -1} {
								error "Undefined vendor \"$val\""
							}
							lset mcu_definition 11 $val
						}
						default {
							incr i
						}
					}
				}
			}
			{timers} {
				set expected {more}
				set take_data 1
			}
			{more} {
				set expected {bits}
				set take_data 1
			}
			{bits} {
				set expected {writeonly}
				set take_data 0
			}
			{writeonly} {
				set expected {sfr}
				set take_data 0
			}
			{sfr} {
				set expected {mcu}
				set take_data 0
			}
		}
	}

	## XML parser handler for procedure load_definition -- takes data section
	 # @parm String arg1	- content of the element
	 # @return void
	proc xml_data_parser0_data {arg1} {
		variable definition_data	;# List: Values gained from $definition_file
		variable expected		;# String: Expected next XML element
		variable current_element	;# String: Current XML element
		variable take_data		;# Bool: Take element data on next parsing cycle
		variable mcu_definition		;# List: Definition of MCU currently being parsed
		variable vendors		;# List: available MCU vendors

		if {!$take_data} {
			return
		}

		set take_data 0

		regsub -all {^\s+} $arg1 {} arg1
		regsub -all {\s+$} $arg1 {} arg1
		regsub -all -line {^\t+} $arg1 {} arg1

		switch -- $current_element {
			{timers} {
				lappend mcu_definition $arg1
			}
			{more} {
				lappend mcu_definition $arg1
			}
		}
	}

	## Event handler for ListBox with list of processors
	 # Handles <<ListboxSelect>> -- Change contents of details frame
	 # @parm String - "noclear" == do not clear search EntryBox
	 # @return void
	proc select_item args {
		variable definition_data	;# List: Values gained from $definition_file
		variable local_definition_data	;# List: Basically the same as $definition_data but containing only the shown items
		variable selected_mcu		;# List: Dialog return value {mcu_type xdata xcode}
		variable listbox_widget		;# Widget: List box containing available MCUs
		variable value_lbl_uart		;# Widget: Label "UART:" - value
		variable value_lbl_voltage	;# Widget: Label "Operating voltage:" - value
		variable value_lbl_interrupts	;# Widget: Label "Interrupts:" - value
		variable value_lbl_timers	;# Widget: Label "Timers:" - value
		variable value_lbl_vendor	;# Widget: Label "Vendor" - value
		variable more_details_text	;# Widget: TextWidget "More details:"
		variable details_xdata_aval	;# Widget: Frame containing scale and spinbox for XDATA memory
		variable details_xdata_note	;# Widget: Frame containing label "NOT available" for XDATA memory
		variable details_xcode_aval	;# Widget: Frame containing scale and spinbox for XCODE memory
		variable details_xcode_nota	;# Widget: Frame containing label "NOT available" for XCODE memory
		variable name_label		;# Widget: Label containing name of selected MCU
		variable image_label		;# Widget: Label with image for selected MCU
		variable xcode_spinbox		;# Widget: SpinBox for XCODE memory
		variable xcode_scale		;# Widget: Scale for XCODE memory
		variable maximum_xcode		;# Int: Maximum external program memory (0x10000 - internal)

		# Get MCU definition for the selected processor
		set mcu [lindex $local_definition_data				\
			[$listbox_widget index [$listbox_widget selection get]]	\
		]
		set mcu_name [lindex $mcu 0]
		if {$selected_mcu == $mcu_name} {
			return
		}
		set selected_mcu $mcu_name
		set maximum_xcode [expr {0x10000 - ([lindex $mcu 3] * 1024)}]

		# Configure detail labels
		$name_label		configure -text $mcu_name
		$value_lbl_vendor	configure -text [lindex $mcu 11]
		$value_lbl_uart		configure -text [lindex $mcu 7]
		$value_lbl_voltage	configure -text [lindex $mcu 9]
		$value_lbl_interrupts	configure -text [lindex $mcu 8]
		$value_lbl_timers	configure -text [lindex $mcu 12]

		# Configure details text
		$more_details_text configure -state normal
		$more_details_text delete 1.0 end
		foreach line [split [lindex $mcu 13] "\n"] {
			$more_details_text image create end -image ::ICONS::16::bookmark -padx 2 -pady 2
			$more_details_text insert end $line
			$more_details_text insert end "\n"
		}
		$more_details_text configure -state disabled

		# Configure XDATA scale
		if {[lindex $mcu 1] != {yes}} {
			if {[winfo ismapped $details_xdata_aval]} {
				pack forget $details_xdata_aval
			}
			pack $details_xdata_note -fill both -expand 1
		} else {
			if {[winfo ismapped $details_xdata_note]} {
				pack forget $details_xdata_note
			}
			pack $details_xdata_aval -fill both -expand 1 -padx 2
		}
		# Configure XCODE scale
		if {[lindex $mcu 2] != {yes}} {
			if {[winfo ismapped $details_xcode_aval]} {
				pack forget $details_xcode_aval
			}
			pack $details_xcode_nota -fill both -expand 1
		} else {
			$xcode_spinbox	configure -to $maximum_xcode
			$xcode_scale	configure -to $maximum_xcode
			if {[winfo ismapped $details_xcode_nota]} {
				pack forget $details_xcode_nota
			}
			pack $details_xcode_aval -fill both -expand 1 -padx 2
		}

		# Clear search bar
		if {$args != {noclear}} {
			clear_search_bar
		}

		# Load image
		set image [$image_label cget -image]
		$image_label configure			\
			-fg {#888888}			\
			-text [mc "Loading image ..."]	\
			-image ::ICONS::16::exec
		if {$image != {} && $image != {::ICONS::16::no} && $image != {::ICONS::16::exec}} {
			image delete $image
		}
		update
		if {[winfo exists $image_label]} {
			if {[catch {
				$image_label configure -text { } -image [image create photo	\
					-format png -file "${::ROOT_DIRNAME}/icons/mcu/$mcu_name.png"
				]
			}]} then {
				$image_label configure			\
					-fg {#DD0000}			\
					-text [mc "  Image not found"]	\
					-image ::ICONS::16::no
			}
		}
	}

	## Set scrollbar for details text
	 # If frac0 == 0 && frac1 == 1 -> hide scrollbar
	 # @parm Float frac0 - Fraction of the topmost visible area
	 # @parm Float frac1 - Fraction of the bottommost visible area
	 # @return void
	proc details_scrollbar_set {frac0 frac1} {
		variable more_details_scrollbar	;# Widget: Scrollbar for $more_details_text
		variable more_details_text	;# Widget: TextWidget "More details:"

		# Hide scrollbar
		if {$frac0 == 0 && $frac1 == 1} {
			if {[winfo ismapped $more_details_scrollbar]} {
				pack forget $more_details_scrollbar
			}
		# Show scrollbar
		} else {
			if {![winfo ismapped $more_details_scrollbar]} {
				pack $more_details_scrollbar	\
					-side right -fill y	\
					-after $more_details_text
			}
			$more_details_scrollbar set $frac0 $frac1
		}
	}

	## Clear search entry box
	 # @return void
	proc clear_search_bar {} {
		variable search_bar		;# Widget: Search bar entry box
		$search_bar delete 0 end
	}

	## Search for the give string in the listbox of available processors
	 # Primary purpose is validator for search entry box, it also
	 #+ ajusts search entry box background color
	 # @parm String string - Part of MCU name
	 # @return Bool - allways 1
	proc search {string} {
		variable search_bar		;# Widget: Search bar entry box
		variable search_bar_clear	;# Widget: Search bar clear button
		variable listbox_widget		;# Widget: List box containing available MCUs
		variable mcu_names		;# List: Available processors (and show in the list)

		# Search for empty string -> abort
		if {![string length $string]} {
			$search_bar_clear configure -state disabled
			$search_bar configure -style TEntry
			return 1
		}

		$search_bar_clear configure -state normal

		# Do a case-insensitive search
		set string [string toupper $string]

		set i 0
		foreach mcu $mcu_names {
			if {[string first $string [string toupper $mcu]] != -1} {
				$search_bar configure -style StringFound.TEntry
				set item [$listbox_widget items $i]
				$listbox_widget selection set $item
				$listbox_widget see $item
				select_item noclear
				return 1
			}
			incr i
		}

		$search_bar configure -style StringNotFound.TEntry
		return 1
	}

	## Close MCU selection dialog and discart its result
	 # @return void
	proc cancel {} {
		variable selected_mcu		;# List: Dialog return value {mcu_type xdata xcode}
		set selected_mcu {}
		close_window
	}

	## Disable/Enable XDATA memory
	 # @return void
	proc xdata_disena {} {
		variable xdata_scale	;# Widget: Scale for XDATA memory
		variable xdata_spinbox		;# Widget: Scale for XDATA memory

		if {${::SelectMCU::xdata_ena}} {
			$xdata_scale	state !disabled
			$xdata_spinbox	configure -state normal
		} else {
			$xdata_scale	state disabled
			$xdata_spinbox	configure -state disabled
		}
	}

	## Disable/Enable XCODE memory
	 # @return void
	proc xcode_disena {} {
		variable xcode_spinbox		;# Widget: SpinBox for XCODE memory
		variable xcode_scale		;# Widget: Scale for XCODE memory

		if {${::SelectMCU::xcode_ena}} {
			$xcode_scale	state !disabled
			$xcode_spinbox	configure -state normal
		} else {
			$xcode_scale	state disabled
			$xcode_spinbox	configure -state disabled
		}
	}

	## Validate XDATA memory spinbox
	 # @parm String string - String to validate
	 # @return Bool - Validation result
	proc validate_xdata {string} {
		if {![string is digit $string]} {
			return 0
		}
		if {$string == {}} {
			return 1
		}
		if {$string < 0 || $string > 0x10000} {
			return 0
		}

		return 1
	}

	## Validate XCODE memory spinbox
	 # @parm String string - String to validate
	 # @return Bool - Validation result
	proc validate_xcode {string} {
		variable maximum_xcode	;# Int: Maximum external program memory (0x10000 - internal)

		if {![string is digit $string]} {
			return 0
		}
		if {$string == {}} {
			return 1
		}
		if {$string < 0 || $string > $maximum_xcode} {
			return 0
		}

		return 1
	}

	## This functionshould be changecmd for vendor comboBox
	 # @return void
	proc change_vendor {} {
		variable listbox_widget		;# Widget: List box containing available MCUs

		clear_search_bar
		$listbox_widget delete [$listbox_widget items]
		fill_gui
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

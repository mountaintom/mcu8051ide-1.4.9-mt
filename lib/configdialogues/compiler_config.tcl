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
if { ! [ info exists _COMPILER_CONFIG_TCL ] } {
set _COMPILER_CONFIG_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements compilers configuration dialog
# --------------------------------------------------------------------------

namespace eval compiler {

	variable win			;# ID of toplevel dialog window
	variable dialog_opened	0	;# Bool: True if this dialog is already opened
	variable conf_affected		;# Array of Bool: Affected parts of configuration

	# List of default settings
	variable defaults {
		{_symbols		0}
		{_print			0}
		{_object		0}

		{_nomod			0}
		{_paging		0}
		{_pagelength		0}
		{_pagewidth		0}
		{_title			0}
		{_date			0}
		{_list			0}

		{CREATE_SIM_FILE	1}
		{CREATE_BIN_FILE	1}
		{QUIET			0}
		{optim_ena		0}
	}

	# Option variables
	variable option__symbols	;# Table of symbols (in *.lst)
	variable option__print		;# Generate code listing
	variable option__object		;# Generate object code (ihex8)
	variable option__nomod		;# Ignore controls: $NOMOD
	variable option__paging		;# Ignore controls: $PAGING, $NOPAGING
	variable option__pagelength	;# Ignore controls: $PAGELENGTH
	variable option__pagewidth	;# Ignore controls: $PAGEWIDTH
	variable option__title		;# Ignore controls: $TITLE
	variable option__date		;# Ignore controls: $DATE
	variable option__list		;# Ignore controls: $LIST, $NOLIST, LIST, NOLIST
	variable option_CREATE_SIM_FILE	;# Generate code for simulator
	variable option_CREATE_BIN_FILE	;# Generate binary object code
	variable option_QUIET		;# Verbose
	variable opt_WARNING_LEVEL	;# Warning level
	variable option_optim_ena	;# Enable optimization
	variable max_ihex_rec_length	;# Int: Maximum length of IHEX-8 record

	variable primary_tab_asm	;# Widget: Tab "Assembly language"
	variable primary_tab_c		;# Widget: Tab "C language"
	variable primary_tab_make {}	;# Widget: Tab "MAIN/GNU make"
	variable assembler_tab_compiler	;# Widget: Tab "Compiler"
	variable assembler_tab_M8I	;# Widget: Tab "MCU8051IDE"
	variable assembler_tab_ASEM51	;# Widget: Tab "ASEM-51"
	variable assembler_tab_ASL	;# Widget: Tab "ASL"
	variable assembler_tab_AS31	;# Widget: Tab "AS31"
	variable tertialy_tab_General	;# Widget: Tab "MAIN/C language/General"
	variable tertialy_tab_Code	;# Widget: Tab "MAIN/C language/Code generation"
	variable tertialy_tab_Optim	;# Widget: Tab "MAIN/C language/Optimization"
	variable tertialy_tab_Linker	;# Widget: Tab "MAIN/C language/Linker"
	variable tertialy_tab_Custom	;# Widget: Tab "MAIN/C language/Custom"
	variable sdcc_custom_opts_text	;# Widget: Text widget "Custom options for SDCC"
	variable asm51_custom_opts_text	;# Widget: Text widget "Custom options for ASEM-51"
	variable asl_custom_opts_text	;# Widget: Text widget "Custom options for ASL"
	variable as31_custom_opts_text	;# Widget: Text widget "Custom options for AS31"

	# External assembler configuration
	variable selected_assembler	;# Int: Preferred assembler  (0==MCU8051IDE;1==ASEM-51;2==ASL;3==AS31)
	variable assembler_ASEM51_config;# Array: ASEM-51 configuration
	variable assembler_ASEM51_addcfg;# Array: ASEM-51 additional configuration
	variable assembler_ASL_config	;# Array: ASL configuration
	variable assembler_ASL_addcfg	;# Array: ASL additional configuration
	variable assembler_AS31_config	;# Array: AS31 configuration
	variable assembler_AS31_addcfg	;# Array: AS31 additional configuration

	# SDCC Configuration
	variable sdcc_bool_opt		;# Array: SDCC configuration
	variable sdcc_str_opt		;# Array: SDCC configuration
	variable sdcc_opt_str_opt	;# Array: SDCC configuration
	variable sdcc_scs_str_opt	;# Array: SDCC configuration

	# GNU Make utility configuration
	variable makeutil_config	;# Array: Make utility configuration

	## Create the dialog
	 # @return void
	proc mkDialog {} {
		variable win			;# ID of toplevel dialog window
		variable dialog_opened		;# Bool: True if this dialog is already opened
		variable conf_affected		;# Array of Bool: Affected parts of configuration

		variable primary_tab_asm	;# Widget: Tab "MAIN/Assembly language"
		variable primary_tab_c		;# Widget: Tab "MAIN/C language"
		variable primary_tab_make	;# Widget: Tab "MAIN/GNU make"
		variable assembler_tab_compiler	;# Widget: Tab "Assembly language/Compiler"
		variable assembler_tab_M8I	;# Widget: Tab "MCU8051IDE"
		variable assembler_tab_ASEM51	;# Widget: Tab "ASEM-51"
		variable assembler_tab_ASL	;# Widget: Tab "ASL"
		variable assembler_tab_AS31	;# Widget: Tab "AS31"

		variable sdcc_custom_opts_text	;# Widget: Text widget "Custom options for SDCC"
		variable asm51_custom_opts_text	;# Widget: Text widget "Custom options for ASEM-51"
		variable asl_custom_opts_text	;# Widget: Text widget "Custom options for ASL"
		variable as31_custom_opts_text	;# Widget: Text widget "Custom options for AS31"

		set sdcc_custom_opts_text	{}
		set asm51_custom_opts_text	{}
		set asl_custom_opts_text	{}
		set as31_custom_opts_text	{}


		# Destroy the dialog if it's already opened
		if {$dialog_opened} {
			destroy .compiler_config_dialog
		}
		set dialog_opened 1

		# Initialize array conf_affected
		foreach key {
			MCU8051IDE	ASEM51		ASL
			SDCC_Custom	SDCC_Linker	SDCC_Optimization
			SDCC_Code	SDCC_General	Compiler
			AS31
		} {
			set conf_affected($key) 0
		}

		# Get settings from Compiler NS
		getSettings

		# Create toplevel window
		set win [toplevel .compiler_config_dialog -class {Configuration dialog} -bg ${::COMMON_BG_COLOR}]

		# Create window header
		label $win.header_label				\
			-compound left				\
			-image ::ICONS::32::exec		\
			-text [mc "Compiler configuration"]	\
			-font [font create					\
				-size [expr {int(-20 * $::font_size_factor)}]	\
			]

		# Create primary notebook and its tabs
		set primaryNB [ModernNoteBook $win.nb_p]

		# Tab: Assembly language
		set primary_tab_asm [$primaryNB insert end primary_tab_asm	\
			-text [mc "Assembly language"]				\
			-image ::ICONS::16::asm					\
		]

		# Tab: C language -- SDCC
		set primary_tab_c [$primaryNB insert end primary_tab_c		\
			-text [mc "C language -- SDCC"]				\
			-image ::ICONS::16::source_c				\
			-createcmd {::configDialogues::compiler::create_C_tab}	\
		]

		if {!$::MICROSOFT_WINDOWS} {
			# Tab: GNU make utility
			set primary_tab_make [$primaryNB insert end primary_tab_make		\
				-text [mc "GNU make utility"]					\
				-image ::ICONS::16::text_x_makefile				\
				-createcmd {::configDialogues::compiler::create_make_tab}	\
			]
		}


		# Create notebook "Assembly language" and its pages
		set secondaryNB [ModernNoteBook $primary_tab_asm.secondaryNB]

		set assembler_tab_compiler [$secondaryNB insert end assembler_tab_compiler -text [mc "Assembler"] -createcmd {::configDialogues::compiler::create_compiler_tab}]
		set assembler_tab_M8I [$secondaryNB insert end assembler_tab_M8I -text "MCU8051IDE" -createcmd {::configDialogues::compiler::create_asm_tab}]
		set assembler_tab_ASEM51 [$secondaryNB insert end assembler_tab_ASEM51 -text "ASEM-51" -createcmd {::configDialogues::compiler::create_ASEM51_tab}]
		if {!$::MICROSOFT_WINDOWS} { ;# There is no support for these external assemblers on Microsoft Windows
			set assembler_tab_ASL [$secondaryNB insert end assembler_tab_ASL -text "ASL" -createcmd {::configDialogues::compiler::create_ASL_tab}]
			set assembler_tab_AS31 [$secondaryNB insert end assembler_tab_AS31 -text "AS31" -createcmd {::configDialogues::compiler::create_AS31_tab}]
		}
		pack [$secondaryNB get_nb] -fill both -expand 1

		# Raise pages in notebooks
		$primaryNB raise primary_tab_asm
		$secondaryNB raise assembler_tab_compiler

		## Button frame at the bottom
		set but_frame [frame $win.button_frame]
		 # Button "Reset"
		pack [ttk::button $but_frame.but_default		\
			-text [mc "Reset to defaults"]			\
			-command {::configDialogues::compiler::DEFAULTS}\

		] -side left
		DynamicHelp::add $but_frame.but_default	\
			-text [mc "Reset all settings to defaults"]
		 # Button "Ok"
		pack [ttk::button $but_frame.but_ok			\
			-text [mc "Ok"]					\
			-compound left					\
			-image ::ICONS::16::ok				\
			-command {::configDialogues::compiler::OK}	\
		] -side right -padx 2
		DynamicHelp::add $but_frame.but_ok	\
			-text [mc "Commit new settings"]
		 # Button "Cancel"
		pack [ttk::button $but_frame.but_cancel			\
			-text [mc "Cancel"]				\
			-compound left					\
			-image ::ICONS::16::button_cancel		\
			-command {::configDialogues::compiler::CANCEL}	\
		] -side right -padx 2
		DynamicHelp::add $but_frame.but_cancel	\
			-text [mc "Take changes back and close dialog"]

		# Pack frames and notebook
		pack $but_frame -side bottom -fill x -anchor s -padx 5 -pady 5
		pack $win.header_label -side top -pady 6
		pack [$primaryNB get_nb] -side top -fill both -padx 5 -expand 1

		# Set window attributes
		wm iconphoto $win ::ICONS::16::configure
		wm transient $win .
		wm title $win [mc "Configure compiler - %s" ${::APPNAME}]
		wm geometry $win 470x510
		wm resizable $win 0 0
		raise $win
		catch {grab $win}
		wm protocol $win WM_DELETE_WINDOW {
			::configDialogues::compiler::CANCEL
		}
		tkwait window $win
	}

	## Create tab "GNU make utility"
	 # @return void
	proc create_make_tab {} {
		variable primary_tab_make	;# Widget: Tab "MAIN/GNU make"

		if {!${::PROGRAM_AVAILABLE(make)}} {
			pack [label $primary_tab_make.warning_lbl	\
				-fg {#DD0000}				\
				-text [mc "Make utility is not available, please install GNU make and restart the IDE."] \
			] -pady 10
			return
		}

		set primary_tab_make [frame $primary_tab_make.f]
		pack $primary_tab_make -side top -anchor w -padx 5 -pady 10 -fill both -expand 1

		#
		## C compiler
		#
		grid [checkbutton $primary_tab_make.chb_c_ena					\
			-text [mc "Use this Makefile instead of calling C compiler directly:"]	\
			-onvalue 1 -offvalue 0							\
			-variable ::configDialogues::compiler::makeutil_config(c_ena)		\
			-command [list ::configDialogues::compiler::make_tab__chb_ena c]	\
		] -column 0 -row 0 -sticky w -padx 5 -columnspan 4

		grid [ttk::label $primary_tab_make.clng_make_label	\
			-text [mc "Makefile:"]
		] -column 0 -row 1 -padx 5 -pady 5 -sticky w
		grid [ttk::button							\
			$primary_tab_make.clng_clear_but				\
			-style Flat.TButton						\
			-takefocus 0							\
			-image ::ICONS::16::locationbar_erase				\
			-command [list ::configDialogues::compiler::make_tab__clr_but c]\
			-state disabled							\
		] -column 1 -row 1
		DynamicHelp::add $primary_tab_make.clng_clear_but -text [mc "Clear the entrybox"]
		grid [ttk::entry $primary_tab_make.clng_make_entry		\
			-width 0 -validate all				\
			-textvariable ::configDialogues::compiler::makeutil_config(c_file)	\
			-validatecommand [list ::configDialogues::compiler::make_tab__entry_validator c %P]	\
		] -column 2 -row 1 -sticky we
		grid [ttk::button $primary_tab_make.clng_flsel_but				\
			-style Flat.TButton							\
			-takefocus 0								\
			-image ::ICONS::16::fileopen						\
			-command [list ::configDialogues::compiler::make_tab__flsel_but c]	\
		] -row 1 -column 3 -sticky e
		DynamicHelp::add $primary_tab_make.clng_flsel_but -text [mc "Select Makefile"]

		grid [ttk::label $primary_tab_make.copt_make_label	\
			-text [mc "Options:"]
		] -column 0 -row 2 -padx 5 -pady 5 -sticky w
		grid [ttk::button							\
			$primary_tab_make.colng_clear_but				\
			-style Flat.TButton						\
			-takefocus 0							\
			-image ::ICONS::16::locationbar_erase				\
			-command [list ::configDialogues::compiler::make_tab__clr_but co]\
			-state disabled							\
		] -column 1 -row 2
		DynamicHelp::add $primary_tab_make.colng_clear_but -text [mc "Clear the entrybox"]
		grid [ttk::entry $primary_tab_make.copt_make_entry		\
			-width 0 -validate all					\
			-textvariable ::configDialogues::compiler::makeutil_config(co_file)	\
			-validatecommand [list ::configDialogues::compiler::make_tab__entry_validator co %P]	\
		] -column 2 -row 2 -sticky we

		grid [ttk::label $primary_tab_make.ctrg_make_label	\
			-text [mc "Targets:"]
		] -column 0 -row 3 -padx 5 -pady 5 -sticky w
		grid [ttk::button							\
			$primary_tab_make.ctlng_clear_but				\
			-style Flat.TButton						\
			-takefocus 0							\
			-image ::ICONS::16::locationbar_erase				\
			-command [list ::configDialogues::compiler::make_tab__clr_but ct]\
			-state disabled							\
		] -column 1 -row 3
		DynamicHelp::add $primary_tab_make.ctlng_clear_but -text [mc "Clear the entrybox"]
		grid [ttk::entry $primary_tab_make.ctrg_make_entry		\
			-width 0 -validate all					\
			-textvariable ::configDialogues::compiler::makeutil_config(ct_file)	\
			-validatecommand [list ::configDialogues::compiler::make_tab__entry_validator ct %P]	\
		] -column 2 -row 3 -sticky we

		grid columnconfigure $primary_tab_make 2 -weight 1

		# Adjust GUI to the current config
		make_tab__adjust_gui

		update idletasks
		focus $primary_tab_make.clng_make_entry
	}

	## Enable or disable widgets related to Makefile usage configuration
	 # according to content of certain configuration variables.
	 # @return void
	proc make_tab__adjust_gui {} {
		# Enable of disable (other) widgets for configuration related to makefiles
		make_tab__chb_ena c
	}

	## Enable or disable widgets for further configuration
	 #
	 # Enable them only if usage of Makefile instead of direct call of a
	 # compiler/assembler was enabled.
	 # @parm Char lang	-'c' == C language
	 # @return void
	proc make_tab__chb_ena {lang} {
		variable primary_tab_make	;# Widget: Tab "MAIN/GNU make"

		if {$::configDialogues::compiler::makeutil_config(${lang}_ena) && ${::PROGRAM_AVAILABLE(make)}} {
			make_tab__entry_validator $lang $::configDialogues::compiler::makeutil_config(${lang}_file)
			make_tab__entry_validator ${lang}o $::configDialogues::compiler::makeutil_config(${lang}o_file)
			make_tab__entry_validator ${lang}t $::configDialogues::compiler::makeutil_config(${lang}t_file)
			set state {normal}
		} else {
			set state {disabled}
		}

		if {[winfo exists $primary_tab_make.f]} {
                    $primary_tab_make.${lang}lng_make_entry	configure -state $state
                    $primary_tab_make.${lang}lng_flsel_but	configure -state $state
                    $primary_tab_make.${lang}opt_make_entry	configure -state $state
                    $primary_tab_make.${lang}trg_make_entry	configure -state $state
		}
	}

	## Invoke file selection dialog for the Makefile entrybox
	 # @parm Char lang	-'c' == C language
	 # @return void
	proc make_tab__flsel_but {lang} {
		variable primary_tab_make	;# Widget: Tab "MAIN/GNU make"

		catch {delete object ::fsd}
		KIFSD::FSD ::fsd										\
			-initialfile $::configDialogues::compiler::makeutil_config(${lang}_file)		\
			-directory [file dirname $::configDialogues::compiler::makeutil_config(${lang}_file)]	\
			-title [mc "Select Makefile - %s - MCU 8051 IDE" $::X::actualProject]			\
			-defaultmask 0 -multiple 0 -filetypes [list						\
				[list [mc "All files"]		{*}	]					\
			]
		::fsd setokcmd [subst {
			set uri \[::fsd get\]
			set ::configDialogues::compiler::makeutil_config(${lang}_file) \$uri
			::configDialogues::compiler::make_tab__entry_validator $lang \$uri
		}]
		fsd activate
	}

	## Clear the Makefile entrybox (action for the Clear button)
	 # @parm Char lang	-'c' == C language
	 # @return void
	proc make_tab__clr_but {lang} {
		variable primary_tab_make	;# Widget: Tab "MAIN/GNU make"

		set ::configDialogues::compiler::makeutil_config(${lang}_file) {}
		make_tab__entry_validator $lang {}
	}

	## Disable the clear button if the entrybox is empty, enable it otherwise
	 # @parm Char lang	-'c' == C language
	 # @parm String content	- Content of the entrybox
	 # @return void
	proc make_tab__entry_validator {lang content} {
		variable primary_tab_make	;# Widget: Tab "MAIN/GNU make"

		if {$content == {}} {
			set state disabled
		} else {
			set state normal
		}

		$primary_tab_make.${lang}lng_clear_but configure -state $state

		return 1
	}

	## Create tab "C language"
	 # @return void
	proc create_C_tab {} {
		variable primary_tab_c		;# Widget: Tab "MAIN/C language"
		variable tertialy_tab_General	;# Widget: Tab "MAIN/C language/General"
		variable tertialy_tab_Code	;# Widget: Tab "MAIN/C language/Code generation"
		variable tertialy_tab_Optim	;# Widget: Tab "MAIN/C language/Optimization"
		variable tertialy_tab_Linker	;# Widget: Tab "MAIN/C language/Linker"
		variable tertialy_tab_Custom	;# Widget: Tab "MAIN/C language/Custom"

		# Create notebook
		set tertialyNB [ModernNoteBook $primary_tab_c.nb_t]

		# Create notebook tabs
		foreach tab {
				General		Code
				Optimization	Linker
				Custom
			} var {
				General		Code
				Optim		Linker
				Custom
			} text {
				General		{Code generation}
				Optimization	Linker
				Custom
			} \
		{
			set frame [$tertialyNB insert end $tab						\
				-createcmd [list ::configDialogues::compiler::create_T_tab $tab]	\
				-text [mc $text]							\
			]
			set tertialy_tab_$var $frame
		}

		# Finalize
		$tertialyNB raise {General}
		pack [$tertialyNB get_nb] -fill both -expand 1
	}

	## Create certain tab in notebook "C language"
	 # @parm String tab - Tab name
	 # @return void
	proc create_T_tab {tab} {
		variable tertialy_tab_General	;# Widget: Tab "MAIN/C language/General"
		variable tertialy_tab_Code	;# Widget: Tab "MAIN/C language/Code generation"
		variable tertialy_tab_Optim	;# Widget: Tab "MAIN/C language/Optimization"
		variable tertialy_tab_Linker	;# Widget: Tab "MAIN/C language/Linker"
		variable tertialy_tab_Custom	;# Widget: Tab "MAIN/C language/Custom"
		variable sdcc_custom_opts_text	;# Widget: Text widget "Custom options for SDCC"
		variable conf_affected		;# Array of Bool: Affected parts of configuration
		variable sdcc_str_opt		;# Array: SDCC configuration

		set row 0
		switch -- $tab {
			{General} {
				set conf_affected(SDCC_General) 1
				set frame	$tertialy_tab_General
				set names	{
					--verbose		-V
					-S			--compile-only
					--preprocessonly	--c1mode
					--print-search-dirs	--use-stdout
					--nostdlib		--nostdinc
					--less-pedantic		--debug
					--cyclomatic		--fdollars-in-identifiers
					--funsigned-char
				}
				set helptexts	{
					{Trace calls to the preprocessor, assembler and linker}
					{Execute verbosely. Show sub commands as they are run}
					{Compile only; do not assemble or link}
					{Compile and assemble, but do not link}
					{Preprocess only, do not compile}
					{Act in c1 mode. The standard input is preprocessed code, the output is assembly code.}
					{Display the directories in the compiler's search path}
					{Send errors to stdout instead of stderr}
					{Do not include the standard library directory in the search path}
					{Do not include the standard include directory in the search path}
					{Disable some of the more pedantic warnings}
					{Enable debugging symbol output}
					{Display complexity of compiled functions}
					{Permit '$' as an identifier character}
					{Make "char" unsigned by default}
				}

				set local_frame [frame $frame.local_frame_0]
				pack $local_frame -side top -anchor w
				grid columnconfigure $local_frame 0 -minsize 25
				grid columnconfigure $local_frame 3 -minsize 20
				grid [label $local_frame.c_standard -text [mc "Standard:"]]	\
					-columnspan 6 -column 0 -row 0 -sticky w

				set local_row 1
				set col 1
				foreach name {
						{--std-c89}	{--std-sdcc89}
						{--std-c99}	{--std-sdcc99}
					} helptext {
						{Use C89 standard only}
						{Use C89 standard with SDCC extensions}
						{Use C99 standard only (incomplete)}
						{Use C99 standard with SDCC extensions (incomplete)}
					} \
				{
					grid [radiobutton $local_frame.chb_${local_row}_$col	\
						-value $name -text $name	\
						-variable ::configDialogues::compiler::sdcc_str_opt(standard)	\
					] -column $col -row $local_row -sticky w -padx 5
					DynamicHelp::add $local_frame.chb_${local_row}_$col -text [mc $helptext]
					incr col

					if {$col >= 3} {
						set col 1
						incr local_row
					}
				}

				pack [ttk::separator $frame.sep_0 -orient horizontal] -fill x -pady 5

				set local_row 0
				set local_frame [frame $frame.local_frame_1]
				pack $local_frame -side top -fill x

				grid [Label $local_frame.lbl_$local_row -anchor w		\
					-text [mc "Include path"]					\
					-helptext [mc "Add to the include path, as in -Ipath\nPaths are separated by semicolons (`;')"]	\
				] -column 0 -row $local_row -sticky w -padx 5
				grid [ttk::entry $local_frame.chb_$local_row				\
					-width 0							\
					-textvariable ::configDialogues::compiler::sdcc_scs_str_opt(-I)	\
				] -column 1 -row $local_row -sticky we -padx 5
				DynamicHelp::add $local_frame.chb_$local_row	\
					-text [mc "Add to the include path, as in -Ipath\nPaths are separated by semicolons (`;')"]
				incr local_row

				grid [Label $local_frame.lbl_$local_row -anchor w		\
					-text [mc "Disable warning"]				\
					-helptext [mc "Disable specific warning (--disable-warning)\nNumbers are separated by semicolons (`;')"]	\
				] -column 0 -row $local_row -sticky w -padx 5
				grid [ttk::entry $local_frame.chb_$local_row						\
					-width 0									\
					-textvariable ::configDialogues::compiler::sdcc_scs_str_opt(--disable-warning)	\
				] -column 1 -row $local_row -sticky we -padx 5
				DynamicHelp::add $local_frame.chb_$local_row -text [mc "Disable specific warning (--disable-warning)\nNumbers are separated by semicolons (`;')"]	\
				incr local_row

				grid columnconfigure $local_frame 1 -weight 1
				pack [ttk::separator $frame.sep_1 -orient horizontal] -fill x -pady 5
			}
			{Code} {
				set conf_affected(SDCC_Code) 1
				set frame	$tertialy_tab_Code
				set names	{
					--xstack		--int-long-reent
					--float-reent		--main-return
					--xram-movc		--profile
					--fommit-frame-pointer	--all-callee-saves
					--stack-probe		--parms-in-bank1
					--no-xinit-opt		--no-c-code-in-asm
					--no-peep-comments	--fverbose-asm
					--short-is-8bits	--stack-auto
				}
				set helptexts	{
					{Use external stack}
					{Use reenterant calls on the int and long support functions}
					{Use reenterant calls on the float support functions}
					{Issue a return after main()}
					{Use movc instead of movx to read xram (xdata)}
					{On supported ports, generate extra profiling information}
					{Leave out the frame pointer.}
					{Callee will always save registers used}
					{Insert call to function __stack_probe at each function prologue}
					{Use Bank1 for parameter passing}
					{Don't memcpy initialized xram from code}
					{Don't include c-code as comments in the asm file}
					{Don't include peephole optimizer comments}
					{Include code generator comments}
					{Make short 8 bits (for old times sake)}
					{Stack automatic variables}
				}

				set local_frame [frame $frame.local_frame_0]
				pack $local_frame -side top -anchor w
				grid columnconfigure $local_frame 0 -minsize 25
				grid columnconfigure $local_frame 3 -minsize 20
				grid [label $local_frame.c_standard -text [mc "Model:"]]	\
					-columnspan 6 -column 0 -row 0 -sticky w -padx 5

				set local_row 1
				set col 1
				foreach name {
						{--model-large}
						{--model-medium}
						{--model-small}
					} helptext {
						{External data space is used}
						{External paged data space is used}
						{Internal data space is used}
					} \
				{
					grid [radiobutton $local_frame.chb_${local_row}_$col	\
						-value $name -text $name	\
						-variable ::configDialogues::compiler::sdcc_str_opt(model)	\
					] -column $col -row $local_row -sticky w -padx 5
					DynamicHelp::add $local_frame.chb_${local_row}_$col -text [mc $helptext]
					incr col

					if {$col >= 3} {
						set col 1
						incr local_row
					}
				}

				pack [ttk::separator $frame.sep_0 -orient horizontal] -fill x -pady 5 -padx 5

				set local_row 0
				set local_frame [frame $frame.local_frame_1]
				pack $local_frame -side top -fill x

				grid [Label $local_frame.lbl_$local_row -anchor w		\
					-text {--codeseg}					\
					-helptext [mc "Use this name for the code segment"]	\
				] -column 0 -row $local_row -sticky w -padx 5
				grid [ttk::entry $local_frame.chb_$local_row					\
					-width 0								\
					-textvariable ::configDialogues::compiler::sdcc_opt_str_opt(--codeseg)	\
				] -column 1 -row $local_row -sticky we -padx 5
				DynamicHelp::add $local_frame.chb_$local_row	\
					-text [mc "Use this name for the code segment"]
				incr local_row

				grid [Label $local_frame.lbl_$local_row -anchor w		\
					-text {--constseg}					\
					-helptext [mc "Use this name for the const segment"]	\
				] -column 0 -row $local_row -sticky w -padx 5
				grid [ttk::entry $local_frame.chb_$local_row					\
					-width 0								\
					-textvariable ::configDialogues::compiler::sdcc_opt_str_opt(--constseg)	\
				] -column 1 -row $local_row -sticky we -padx 5
				DynamicHelp::add $local_frame.chb_$local_row -text [mc "Use this name for the const segment"]	\
				incr local_row

				grid columnconfigure $local_frame 1 -weight 1
				pack [ttk::separator $frame.sep_1 -orient horizontal] -fill x -pady 5 -padx 5
			}
			{Optimization} {
				set conf_affected(SDCC_Optimization) 1
				set frame	$tertialy_tab_Optim
				set names	{
					--nooverlay		--nogcse
					--nolabelopt		--noinvariant
					--noinduction		--nojtbound
					--noloopreverse		--no-peep
					--no-reg-params		--peep-asm
					--opt-code-speed	--opt-code-size
				}
				set helptexts	{
					{Disable overlaying leaf function auto variables}
					{Disable the GCSE optimisation}
					{Disable label optimisation}
					{Disable optimisation of invariants}
					{Disable loop variable induction}
					{Don't generate boundary check for jump tables}
					{Disable the loop reverse optimisation}
					{Disable the peephole assembly file optimisation}
					{On some ports, disable passing some parameters in registers}
					{Enable peephole optimization on inline assembly}
					{Optimize for code speed rather than size}
					{Optimize for code size rather than speed}
				}
			}
			{Linker} {
				set conf_affected(SDCC_Linker) 1
				set frame	$tertialy_tab_Linker
				set names	{
					--out-fmt-ihx	--out-fmt-s19
				}
				set helptexts	{
					{Output in Intel hex format}
					{Output in S19 hex format}
				}

				set local_row 0
				set local_frame [frame $frame.local_frame_1]
				pack $local_frame -side top -fill x
				grid columnconfigure $local_frame 1 -weight 1
				foreach name {
						-l		-L
					} helptext {
						{Include the given library in the link\nPaths are separated by semicolons (`;')}
						{Add the next field to the library search path\nPaths are separated by semicolons (`;')}
					} \
				{
					grid [Label $local_frame.lbl_$local_row -anchor w	\
						-text $name -helptext [mc [subst $helptext]]	\
					] -column 0 -row $local_row -sticky w -padx 5
					grid [ttk::entry $local_frame.chb_$local_row					\
						-width 0								\
						-textvariable ::configDialogues::compiler::sdcc_scs_str_opt($name)	\
					] -column 1 -row $local_row -sticky we -padx 5
					DynamicHelp::add $local_frame.chb_$local_row	\
						-text [mc [subst $helptext]]
					incr local_row
				}
				foreach name {
						--lib-path	--xram-loc
						--xstack-loc	--code-loc
						--stack-loc	--data-loc
						--stack-size
					} helptext {
						{Use this path to search for libraries}
						{External Ram start location}
						{External Stack start location}
						{Code Segment Location}
						{Stack pointer initial value}
						{Direct data start location}
						{Tells the linker to allocate this space for stack}
					} \
				{
					grid [Label $local_frame.lbl_$local_row -anchor w	\
						-text $name -helptext [mc $helptext]		\
					] -column 0 -row $local_row -sticky w -padx 5
					grid [ttk::entry $local_frame.chb_$local_row					\
						-width 0								\
						-textvariable ::configDialogues::compiler::sdcc_opt_str_opt($name)	\
					] -column 1 -row $local_row -sticky we -padx 5
					DynamicHelp::add $local_frame.chb_$local_row -text [mc $helptext]
					incr local_row
				}

				pack [ttk::separator $frame.sep_0 -orient horizontal] -fill x -pady 5 -padx 5
				set local_frame [frame $frame.local_frame_0]
				pack $local_frame -side top -anchor w
				grid columnconfigure $local_frame 0 -minsize 25
				pack [ttk::separator $frame.sep_1 -orient horizontal] -fill x -pady 5 -padx 5
				grid [label $local_frame.c_standard -text [mc "Stack:"]]	\
					-columnspan 3 -column 0 -row 0 -sticky w
			}
			{Custom} {
				set conf_affected(SDCC_Custom) 1
				set frame $tertialy_tab_Custom
			}
		}

		set main_frame [frame $frame.frame]
		if {$tab == {Custom}} {
			set sdcc_custom_opts_text [text $main_frame.text	\
				-bg white -width 0 -height 0 -wrap word		\
				-yscrollcommand "$main_frame.scrollbar set"	\
			]
			pack [ttk::scrollbar $main_frame.scrollbar	\
				-orient vertical			\
				-command "$main_frame.text yview"	\
			] -side right -fill y
			pack $sdcc_custom_opts_text -fill both -expand 1 -side left
			$sdcc_custom_opts_text insert end $sdcc_str_opt(custom)

			pack $main_frame -side top -fill both -expand 1
		} else {
			set col 0
			foreach name $names helptext $helptexts {
				grid [checkbutton $main_frame.chb_${row}_$col	\
					-text $name -onvalue 1 -offvalue 0	\
					-variable ::configDialogues::compiler::sdcc_bool_opt($name)	\
				] -column $col -row $row -sticky w -padx 5
				DynamicHelp::add $main_frame.chb_${row}_$col -text [mc $helptext]
				incr col

				if {$col >= 2} {
					set col 0
					incr row
				}
			}
			grid columnconfigure $main_frame 0 -weight 1
			pack $main_frame -side top -fill x
		}
	}

	## Create tab "Compiler"
	 # @return void
	proc create_compiler_tab {} {
		variable assembler_tab_compiler	;# Widget: Tab "Compiler"
		variable conf_affected		;# Array of Bool: Affected parts of configuration

		set conf_affected(Compiler) 1
		set main_frame [frame $assembler_tab_compiler.frame]
		# Preferred editor
		grid [label $main_frame.editor_lbl			\
			-text [mc "Preferred assembler:"] -anchor w	\
		] -row 0 -column 0 -sticky w -padx 10 -pady 10
		set row 1
		set i 0
		foreach text {
				{MCU 8051 IDE}
				{ASEM-51}
				{ASL}
				{AS31}
			} helptext {
				{MCU 8051 IDE native assembler - Sophisticated but slow}
				{Sophisticated and very fast assembler written by W.W. Heinz}
				{Multiplatform assembler written by Alfred Arnold}
				{Simple 8051 assembler}
			} {
				grid [radiobutton $main_frame.rabut_$i		\
					-variable ::configDialogues::compiler::selected_assembler \
					-value $i -text $text -state disabled	\
				] -column 0 -padx 25 -row $row -sticky w
				DynamicHelp::add $main_frame.rabut_$i -text [mc $helptext]
				incr i
				incr row
		}
		$main_frame.rabut_0 configure -state normal
		if {${::PROGRAM_AVAILABLE(asem)}} {
			$main_frame.rabut_1 configure -state normal
		}
		if {${::PROGRAM_AVAILABLE(asl)}} {
			$main_frame.rabut_2 configure -state normal
		}
		if {${::PROGRAM_AVAILABLE(as31)}} {
			$main_frame.rabut_3 configure -state normal
		}

		grid [ttk::separator $main_frame.sep -orient horizontal]	\
			-row $row -column 0 -sticky we -columnspan 2 -padx 10 -pady 10
		incr row

		grid [text $main_frame.notes					\
			-bg ${::COMMON_BG_COLOR} -bd 0 -highlightthickness 0 -wrap word	\
			-font [font create					\
				-family {helvetiva}				\
				-size [expr {int(-12 * $::font_size_factor)}]	\
			]							\
		] -row $row -column 0 -sticky we -columnspan 2 -padx 10

		$main_frame.notes insert end [mc "Notes to assemblers:\n"]
		$main_frame.notes insert end [mc "  a) MCU 8051 IDE has its own native assembler\n"]
		$main_frame.notes insert end [mc "  b) ASEM-51 is a great assembler written by W.W. Heinz.\n"]
		$main_frame.notes insert end [mc "     You can find it at http://plit.de/asem-51/home.htm\n"]
		$main_frame.notes insert end [mc "  c) ASL: http://linux.maruhn.com/sec/asl.html\n"]
		$main_frame.notes insert end [mc "  d) AS31: http://www.pjrc.com/tech/8051\n"]
		create_link_tag_in_text_widget $main_frame.notes
		convert_all_https_to_links $main_frame.notes

		$main_frame.notes configure -state disabled

		# Configure grid and pack main frame
		grid columnconfigure $main_frame 0 -minsize 200
		grid columnconfigure $main_frame 1 -weight 1
		pack $main_frame -side top -fill x
	}

	## Create tab "ASEM51"
	 # @return void
	proc create_ASEM51_tab {} {
		variable assembler_tab_ASEM51	;# Widget: Tab "ASX8051"
		variable asm51_custom_opts_text	;# Widget: Text widget "Custom options for ASEM-51"
		variable conf_affected		;# Array of Bool: Affected parts of configuration

		# Set flag "Configuration affected"
		set conf_affected(ASEM51) 1

		# Create main frame
		set main_frame [frame $assembler_tab_ASEM51.frame0]

		set i 0
		foreach name {
				--omf-51
				--columns
				--verbose
			} helptext {
				{Generate an object file in absolute OMF-51 format}
				{Output additional column numbers after the line numbers of program error messages}
				{Output additional product, version, and error summary information}
			} \
		{
			pack [checkbutton $main_frame.checkbutton_$i	\
				-text [mc $name] -onvalue 1 -offvalue 0	\
				-variable ::configDialogues::compiler::assembler_ASEM51_config($name)	\
			] -anchor nw -padx 5
			DynamicHelp::add $main_frame.checkbutton_$i -text [mc $helptext]
			incr i
		}
		pack $main_frame -fill x -padx 5

		# Additional options
		set main_frame [frame $assembler_tab_ASEM51.frame_a]
		set i 0
		foreach var {
				adf
			} text {
				{Generate MCU 8051 IDE debug file}
			} helptext {
				{Generate <file>.adb (MCU 8051 IDE Assembler Debug File) from <file>.lst}
			} \
		{
			set helptext [mc [subst $helptext]]
			pack [checkbutton $main_frame.chb_$i		\
				-text [mc $text] -onvalue 1 -offvalue 0	\
				-variable ::configDialogues::compiler::assembler_ASEM51_addcfg($var)	\
			] -anchor w -padx 5
			DynamicHelp::add $main_frame.chb_$i -text $helptext
			incr i
		}
		pack $main_frame -fill x -padx 5
		pack [ttk::separator $assembler_tab_ASEM51.sep_1 -orient horizontal] -fill x -pady 5

		# Create second frame (Include path and custom flags)
		set main_frame [frame $assembler_tab_ASEM51.frame1]
		# Include path
		grid [Label $main_frame.lbl_0 -anchor w		\
			-text [mc "Include paths:"]		\
			-helptext [mc "Option -i\nSeparate directories by colons (`:')"]	\
		] -column 0 -row 0 -sticky w -padx 5
		grid [ttk::entry $main_frame.entry						\
			-textvariable ::configDialogues::compiler::assembler_ASEM51_config(-i)	\
		] -column 1 -row 0 -sticky we -padx 5
		DynamicHelp::add $main_frame.entry	\
			-text [mc "Option -i\nSeparate directories by colons (`:')"]
		grid [Label $main_frame.lbl_1		\
			-anchor w			\
			-text [mc "Custom options:"]	\
		] -column 0 -row 1 -sticky w -padx 5

		# Configure grid and pack main frame 1
		grid columnconfigure $main_frame 1 -weight 1
		pack $main_frame -fill x -padx 5

		# Text widget "Custom options"
		set main_frame [frame $assembler_tab_ASEM51.frame2]
		set asm51_custom_opts_text [text $main_frame.text	\
			-bg white -width 0 -height 0			\
			-yscrollcommand "$main_frame.scrollbar set"	\
		]
		pack $asm51_custom_opts_text -side left -fill both -expand 1
		pack [ttk::scrollbar $main_frame.scrollbar		\
			-orient vertical				\
			-command "$asm51_custom_opts_text yview"	\
		] -side right -fill y
		$asm51_custom_opts_text insert end	\
			$::configDialogues::compiler::assembler_ASEM51_config(custom)
		pack $main_frame -fill both -expand 1 -pady 5
	}

	## Create tab "AS31"
	 # @return void
	proc create_AS31_tab {} {
		variable assembler_tab_AS31	;# Widget: Tab "AS31"
		variable as31_custom_opts_text	;# Widget: Text widget "Custom options for AS31"
		variable conf_affected		;# Array of Bool: Affected parts of configuration

		# Set flag "Configuration affected"
		set conf_affected(AS31) 1

		# Create main frame
		set main_frame [frame $assembler_tab_AS31.frame0]
		set i 0
		set row 0
		set col 0
		foreach name {
				-l
			} text {
				{Generate a listing file, option `-l'}
			} helptext {
				{This option tells the assembler to generate a listing file.\n\nTHIS OPTION IS REQUIRED BY THIS IDE TO GENERATE DEBUG FILE !}
			} \
		{
			set helptext [mc [subst $helptext]]
			grid [checkbutton $main_frame.checkbutton_$i	\
				-text [mc $text] -onvalue 1 -offvalue 0	\
				-variable ::configDialogues::compiler::assembler_AS31_config($name)	\
			] -sticky w -row $row -column $col -padx 5
			DynamicHelp::add $main_frame.checkbutton_$i -text $helptext

			incr i
			incr col
			if {$col > 3} {
				set col 0
				incr row
			}
		}
		for {set i 0} {$i < 4} {incr i} {
			grid columnconfigure $main_frame $i -weight 1
		}
		pack $main_frame -fill x -padx 5

		# Additional options
		set main_frame [frame $assembler_tab_AS31.frame_a]
		set i 0
		foreach var {
				adf
			} text {
				{Generate MCU 8051 IDE debug file}
			} helptext {
				{Generate <file>.adb (MCU 8051 IDE Assembler Debug File)\nfrom <file>.lst}
			} \
		{
			set helptext [mc [subst $helptext]]
			pack [checkbutton $main_frame.chb_$i						\
				-text [mc $text] -onvalue 1 -offvalue 0					\
				-variable ::configDialogues::compiler::assembler_AS31_addcfg($var)	\
			] -anchor w -padx 5
			DynamicHelp::add $main_frame.chb_$i -text $helptext
			incr i
		}
		pack $main_frame -fill x -padx 5
		pack [ttk::separator $assembler_tab_AS31.sep_1 -orient horizontal] -fill x

		# Create second frame (EntryBoxes and ComboBoxes)
		set main_frame [frame $assembler_tab_AS31.frame1]
		set row 0
		foreach name {
				-F
			} helptext {
				{This options specifies the output format that is to be used.\n\nSee AS31 manual page for more details ...}
			} values {
				{hex tdr byte od srec2 srec3 srec4}
			} \
		{
			set helptext [mc [subst $helptext]]
			grid [Label $main_frame.lbl_$row -anchor w		\
				-text $name -helptext [mc $helptext]		\
			] -column 0 -row $row -sticky w -padx 5
			grid [ttk::combobox $main_frame.entry_$row					\
				-state readonly								\
				-values $values								\
				-textvariable ::configDialogues::compiler::assembler_AS31_config($name)	\
			] -column 1 -row $row -sticky we -padx 5
			DynamicHelp::add $main_frame.entry_$row -text $helptext
			incr row
		}
		foreach name {
				-A
			} helptext {
				{This option specifies a format specific string which is\npassed to the format generator. Both format "tdr" and the\nsrecord formats use this option.}
			} \
		{
			set helptext [mc [subst $helptext]]
			grid [Label $main_frame.lbl_$row -anchor w	\
				-text $name -helptext $helptext	\
			] -column 0 -row $row -sticky w -padx 5
			grid [ttk::entry $main_frame.entry_$row						\
				-textvariable ::configDialogues::compiler::assembler_AS31_config($name)	\
			] -column 1 -row $row -sticky we -padx 5
			DynamicHelp::add $main_frame.entry_$row	\
				-text $helptext
			incr row
		}

		# Custom flags
		grid [Label $main_frame.lbl_$row -anchor w	\
			-text [mc "Custom options:"]		\
		] -column 0 -row $row -sticky w -padx 5

		# Configure grid and pack main frame 1
		grid columnconfigure $main_frame 1 -weight 1
		pack $main_frame -fill x -padx 5

		# Text widget "Custom options"
		set main_frame [frame $assembler_tab_AS31.frame2]
		set as31_custom_opts_text [text $main_frame.text		\
			-bg white -width 0 -height 0			\
			-yscrollcommand "$main_frame.scrollbar set"	\
		]
		pack $as31_custom_opts_text -side left -fill both -expand 1
		pack [ttk::scrollbar $main_frame.scrollbar	\
			-orient vertical			\
			-command "$as31_custom_opts_text yview"	\
		] -side right -fill y
		$as31_custom_opts_text insert end	\
			$::configDialogues::compiler::assembler_AS31_config(custom)
		pack $main_frame -fill both -expand 1
	}

	## Create tab "ASL"
	 # @return void
	proc create_ASL_tab {} {
		variable assembler_tab_ASL	;# Widget: Tab "ASL"
		variable asl_custom_opts_text	;# Widget: Text widget "Custom options for ASL"
		variable conf_affected		;# Array of Bool: Affected parts of configuration

		# Set flag "Configuration affected"
		set conf_affected(ASL) 1

		# Create main frame
		set main_frame [frame $assembler_tab_ASL.frame0]
		set i 0
		set row 0
		set col 0
		foreach name {
				-A -a -C -c -h -I -L -M -P -n -quiet -s -u -U -w -x
			} helptext {
				{Change the data structure that is internally used to store\nthe symbol table. By default, AS uses binary trees to store\nmacro and symbol definitions. Turning this option on will\nchange this to AVL-balanced trees. Depending on the ratio\nof symbol entries and lookups, this might speed up assembly.\nUsing AVL-balanced trees helps also reducing the stack usage,\nwhich is however irrelevant for the C version of AS.}
				{Instruct AS to write out the shared symbol definitions in\na format suitable for including into an AS assembler program.\nThe file's name is constructed by replacing the source file's\nextension with '.inc'. See the user manual for more\ninformation about symbol sharing.}
				{Add a cross reference table to the assembler listing. A cross\nreference table lists all symbols that have been referenced\nat least once during assembly, including the source line\nnumber(s) and count of every reference. This option only makes\nsense when the generation of an assembly listing has been\nturned on via the -L or -l parameters. }
				{Instruct AS to write out the shared symbol definitions in a\nformat suitable for including into a C program. The file's\nname is constructed by replacing the source file's extension\nwith '.h'. See the user manual for more information about\nsymbol sharing.}
				{Force AS to print all hexadecimal constants with lowercase\nletters, rather than with uppercase letters A..F which is\nthe default.}
				{Add an include file list to the assembly listing. An include\nfile list contains all files that have been included while\nassembling the source files, including multiple and nested\ninclusion. Nesting of inclusion is identified by different\nindention. This option only makes sense when the generation of\nan assembly listing has been turned on via the -L or -l parameters.}
				{Turn on generation of an assembly listing and send it to a\nfile whose name is constructed by replacing the source\nfile's extension with '.lst'.}
				{Turn on generation of a macro definition file. A macro\ndefinition file is a file that contains all macro definitions\nthat have been detected during assembly, in a format suitable\nfor an inclusion into another file. The macro definition file's\nname is constructed by replacing the source file's extension\nwith '.mac'.}
				{Turn on generation of a macro output file. A macro output\nfile contains the intermediate source code that remains after\nmacro expansion and conditional assembly. The macro output\nfile's name is constructed by replacing the source file's\nextension with '.i'.}
				{Force AS to extend all error and warning messages with their\ninternal error resp. warning number.}
				{Turn on silent assembly mode. In silent compilation mode, AS\nwill not do any console output except for warning and\nerror messages.}
				{Add a section list to the assembly listing. A section list\ncontains all sections that have been defined in the source\nfiles, marking their nesting level by different levels of\nindentation. This option only makes sense when the generation\nof an assembly listing has been turned on via the\n-L or -l parameters.}
				{Tell AS to do additional bookkeeping about which address\nranges have been used by the assembled program. This option\nenables the detection of overlapping memory usage. If an\nassembly listing has been turned on via the -L or -l parameters,\nit will also contain a list of all used memory areas.}
				{Force AS to operate in case-sensitive mode. By default,\nnames of symbols, macros, user-defined functions and sections\nare treated in a case-insensitive manner.}
				{Suppress output of warnings.}
				{Turn on extended error reporting. With extended error\nreporting, several error and warning messages will also\nprint the item that created the message, e.g. the name of\nan unknown instruction. When this option is given twice,\nthe erroneous source line is additinally printed.}
			} \
		{
			set helptext [mc [subst $helptext]]
			grid [checkbutton $main_frame.checkbutton_$i	\
				-text $name -onvalue 1 -offvalue 0	\
				-variable ::configDialogues::compiler::assembler_ASL_config($name)	\
			] -sticky w -row $row -column $col -padx 5
			DynamicHelp::add $main_frame.checkbutton_$i -text $helptext

			incr i
			incr col
			if {$col > 3} {
				set col 0
				incr row
			}
		}
		for {set i 0} {$i < 4} {incr i} {
			grid columnconfigure $main_frame $i -weight 1
		}
		pack $main_frame -fill x -padx 5
		pack [ttk::separator $assembler_tab_ASL.sep_0 -orient horizontal] -fill x

		# Additional options
		set main_frame [frame $assembler_tab_ASL.frame_a]
		set i 0
		foreach var {
				ihex	adf
			} text {
				{Generate IHEX file}
				{Generate MCU 8051 IDE debug file}
			} helptext {
				{Use program p2hex to convert <file>.p to <file>.hex}
				{Generate <file>.adb (MCU 8051 IDE Assembler Debug File)\nfrom <file>.hex and <file>.map}
			} \
		{
			set helptext [mc [subst $helptext]]
			pack [checkbutton $main_frame.chb_$i		\
				-text [mc $text] -onvalue 1 -offvalue 0	\
				-variable ::configDialogues::compiler::assembler_ASL_addcfg($var)	\
			] -anchor w
			DynamicHelp::add $main_frame.chb_$i -text $helptext
			incr i
		}
		pack $main_frame -fill x -padx 5
		pack [ttk::separator $assembler_tab_ASL.sep_1 -orient horizontal] -fill x

		# Create second frame (EntryBoxes and ComboBoxes)
		set main_frame [frame $assembler_tab_ASL.frame1]
		set row 0
		foreach name {
				-cpu -g
			} helptext {
				{Set the target processor to <name>.\nUse this option if the source file does\nnot contain a CPU statement.}
				{-g \[MAP|Atmel|NoICE\]\n\tInstruct AS to write an additional file containing\n\tdebug information. This information covers the symbol\n\ttable and the relation between source line numbers\n\tand machine addresses. The argument specifies whether\n\tdebug info shall be written in AS's own MAP format,\n\tthe object format for Atmel's AVR tools, or a command\n\tfile suitable for John Hartman's NoICE. If no argument\n\tis given, MAP will be chosen. The file's name is\n\tconstructed by replacing the source file's extension\n\twith '.map', '.obj', or '.noi' respectively.\n\nMCU 8051 IDE requires MAP to be selected\nhere to generate debug file}
			} values {
				{
					8021	8022	8039	80C39	8048	80C48	8041	8042
					87C750	8051	8052	80C320	80C501	80C502	80C504	80515
					80517	80C251
				} {
					{} MAP Atmel NoICE
				}
			} \
		{
			set helptext [mc [subst $helptext]]
			grid [Label $main_frame.lbl_$row -anchor w	\
				-text $name -helptext [mc $helptext]	\
			] -column 0 -row $row -sticky w -padx 5
			grid [ttk::combobox $main_frame.entry_$row					\
				-state readonly								\
				-values $values								\
				-textvariable ::configDialogues::compiler::assembler_ASL_config($name)	\
			] -column 1 -row $row -sticky we -padx 5
			DynamicHelp::add $main_frame.entry_$row -text $helptext
			incr row
		}
		foreach name {
				-r -i
			} helptext {
				{-r \[pass number\]\n\tTell AS to output warnings when a situation appears\n\tin a source file that forces another pass of assembly.\n\tSuch situations either take place when a symbol is\n\tundefined in the first pass or a symbol's value has\n\tchanged compared to the previous pass. This option\n\tis useful to track down sources of excessive\n\tmulti-passing, but be aware that it might yield a\n\tfairly large number of warnings, especially in the\n\tfirst pass. Optionally, a pass number may be added\n\tto this option to inhibit output until a certain\n\tpass is reached.}
				{-i <path\[:path...\]>\tAdd new entries to the list of paths that are\n\tsearched for include files. New entries are\n\tprepended to the current include path list,\n\tso if multiple paths are given with one\n\tcommand-line parameter, they will be entered\n\tinto the path list in reverse order.}
			} \
		{
			set helptext [mc [subst $helptext]]
			grid [Label $main_frame.lbl_$row -anchor w	\
				-text $name -helptext [mc $helptext]	\
			] -column 0 -row $row -sticky w -padx 5
			grid [ttk::entry $main_frame.entry_$row						\
				-textvariable ::configDialogues::compiler::assembler_ASL_config($name)	\
			] -column 1 -row $row -sticky we -padx 5
			DynamicHelp::add $main_frame.entry_$row -text $helptext
			incr row
		}

		# Custom flags
		grid [Label $main_frame.lbl_$row -anchor w	\
			-text [mc "Custom options:"]		\
		] -column 0 -row $row -sticky w -padx 5

		# Configure grid and pack main frame 1
		grid columnconfigure $main_frame 1 -weight 1
		pack $main_frame -fill x -padx 5

		# Text widget "Custom options"
		set main_frame [frame $assembler_tab_ASL.frame2]
		set asl_custom_opts_text [text $main_frame.text		\
			-bg white -width 0 -height 0			\
			-yscrollcommand "$main_frame.scrollbar set"	\
		]
		pack $asl_custom_opts_text -side left -fill both -expand 1
		pack [ttk::scrollbar $main_frame.scrollbar	\
			-orient vertical			\
			-command "$asl_custom_opts_text yview"	\
		] -side right -fill y
		$asl_custom_opts_text insert end	\
			$::configDialogues::compiler::assembler_ASL_config(custom)
		pack $main_frame -fill both -expand 1
	}

	## Create tab "MCU8051IDE"
	 # @return void
	proc create_asm_tab {} {
		variable conf_affected		;# Array of Bool: Affected parts of configuration
		variable assembler_tab_M8I	;# Widget: Tab "MCU8051IDE"

		# Set flag "Configuration affected"
		set conf_affected(MCU8051IDE) 1

		## Create notebook
		set nb0 [ModernNoteBook $assembler_tab_M8I.nb_m]

		 # Tab "Output"
		set ouput_tab [$nb0 insert end ouput_tab -text [mc "Output"]]
		 # Tab "Directives"
		set directives_tab [$nb0 insert end directives_tab -text [mc "Directives"]]

		#
		## Tab "Output"
		#

		# Header
		grid [Label $ouput_tab.source_label				\
			-text [mc "Source"]  -anchor c				\
			-helptext [mc "Use value defined in source code"]	\
		] -column 2 -row 0 -sticky we -padx 5
		grid [Label $ouput_tab.always_label		\
			-text [mc "Always"]  -anchor c		\
			-helptext [mc "Generate always"]	\
		] -column 3 -row 0 -sticky we -padx 5
		grid [Label $ouput_tab.never_label		\
			-text [mc "Never"] -anchor c		\
			-helptext [mc "Never generate"]		\
		] -column 4 -row 0 -sticky we -padx 5

		# Code listing
		grid [Label $ouput_tab.lst_label -anchor w			\
			-text [mc "Generate code listing"]			\
			-helptext [mc "Should compiler generate *.lst files"]	\
		] -column 1 -row 1 -sticky we -padx 5
		grid [radiobutton $ouput_tab.lst_radio0 -value 0		\
			-variable ::configDialogues::compiler::option__print	\
		] -column 2 -row 1 -padx 5
		grid [radiobutton $ouput_tab.lst_radio1 -value 1		\
			-variable ::configDialogues::compiler::option__print	\
		] -column 3 -row 1 -padx 5
		grid [radiobutton $ouput_tab.lst_radio2 -value 2		\
			-variable ::configDialogues::compiler::option__print	\
		] -column 4 -row 1 -padx 5

		# Table of symbols
		grid [Label $ouput_tab.sym_label -anchor w					\
			-text [mc "Table of symbols (in *.lst)"]				\
			-helptext [mc "Include table of used symbolic names to code listing"]	\
		] -column 1 -row 2 -sticky we -padx 5
		grid [radiobutton $ouput_tab.sym_radio0 -value 0		\
			-variable ::configDialogues::compiler::option__symbols	\
		] -column 2 -row 2 -padx 5
		grid [radiobutton $ouput_tab.sym_radio1 -value 1		\
			-variable ::configDialogues::compiler::option__symbols	\
		] -column 3 -row 2 -padx 5
		grid [radiobutton $ouput_tab.sym_radio2 -value 2		\
			-variable ::configDialogues::compiler::option__symbols	\
		] -column 4 -row 2 -padx 5

		# Hex object code
		grid [Label $ouput_tab.hex_label -anchor w	\
			-text [mc "Generate object code (ihex8)"]	\
			-helptext [mc "Generate object code in format Intel Hex 8 (*.hex)"]	\
		] -column 1 -row 3 -sticky we -padx 5
		grid [radiobutton $ouput_tab.hex_radio0 -value 0		\
			-variable ::configDialogues::compiler::option__object	\
		] -column 2 -row 3 -padx 5
		grid [radiobutton $ouput_tab.hex_radio1 -value 1		\
			-variable ::configDialogues::compiler::option__object	\
		] -column 3 -row 3 -padx 5
		grid [radiobutton $ouput_tab.hex_radio2 -value 2		\
			-variable ::configDialogues::compiler::option__object	\
		] -column 4 -row 3 -padx 5

		grid [ttk::separator $ouput_tab.sep0	\
			-orient horizontal		\
		] -column 0 -row 4 -columnspan 5 -sticky we -pady 5 -padx 5

		# Sim object code
		grid [Label $ouput_tab.sim_label -anchor w			\
			-text [mc "Generate code for simulator"]		\
			-helptext [mc "Generate *.sim file for simulator"]	\
		] -column 1 -row 5 -sticky we -padx 5
		grid [checkbutton $ouput_tab.sim_check					\
			-variable ::configDialogues::compiler::option_CREATE_SIM_FILE	\
		] -column 2 -row 5 -sticky w -columnspan 3 -padx 5

		# Bin object code
		grid [Label $ouput_tab.bin_label -anchor w			\
			-text [mc "Generate binary object code"]		\
			-helptext [mc "Generate binary object code (*.bin)"]	\
		] -column 1 -row 6 -sticky we -padx 5
		grid [checkbutton $ouput_tab.bin_check		\
			-variable ::configDialogues::compiler::option_CREATE_BIN_FILE	\
		] -column 2 -row 6 -sticky w -columnspan 3 -padx 5

		grid [ttk::separator $ouput_tab.sep1	\
			-orient horizontal		\
		] -column 0 -row 7 -columnspan 5 -sticky we -pady 5 -padx 5

		# Compier warning level
		grid [Label $ouput_tab.warning_label -anchor w	\
			-text [mc "Warning level"]	\
			-helptext [mc "What kind of messages should be included in compiler log output"]	\
		] -column 1 -row 8 -sticky we -padx 5
		grid [ttk::combobox $ouput_tab.warning_combo	\
			-textvariable ::configDialogues::compiler::opt_WARNING_LEVEL	\
			-values [list				\
				[mc "All"]			\
				[mc "Errors + Warnings"]	\
				[mc "Errros only"]		\
				[mc "Nothing"]			\
			]					\
			-state readonly -width 17	\
		] -column 2 -row 8 -sticky w -columnspan 3 -padx 5
		DynamicHelp::add $ouput_tab.warning_combo	\
			-text [mc "What kind of messages should be included in compiler log output"]

		# Verbose
		grid [Label $ouput_tab.verbose_label -anchor w	\
			-text [mc "Verbose"]	\
			-helptext [mc "Should compiler inform user about what it is doing"]	\
		] -column 1 -row 9 -sticky we -padx 5
		grid [checkbutton $ouput_tab.verbose_check		\
			-onvalue 0 -offvalue 1			\
			-variable ::configDialogues::compiler::option_QUIET	\
		] -column 2 -row 9 -sticky w -columnspan 3 -padx 5

		grid [ttk::separator $ouput_tab.sep2	\
			-orient horizontal		\
		] -column 0 -row 10 -columnspan 5 -sticky we -pady 5 -padx 5

		# Enable optimization
		grid [Label $ouput_tab.optim_label -anchor w		\
			-text [mc "Enable optimization"]		\
			-helptext [mc "Enable peephole optimization"]\
		] -column 1 -row 11 -sticky we -padx 5
		grid [checkbutton $ouput_tab.optim_check		\
			-onvalue 1 -offvalue 0				\
			-variable ::configDialogues::compiler::option_optim_ena	\
		] -column 2 -row 11 -sticky w -columnspan 3 -padx 5

		# Maximum length of IHEX-8 record
		grid [Label $ouput_tab.ih8_max_len_lbl -anchor w		\
			-text [mc "Maximum HEX record data length"]		\
			-helptext [mc "Maximum length of Intel HEX 8 record data field.\n\nGenerally it doesn't matter what is set here. But some (badly written)\nprogrammers may refuse to load files containing records which exceeds\ncertain length.\n\nHigher value also results in smaller .hex files\n\nValue equal to 0 will be treated as 1"]	\
		] -column 1 -row 12 -sticky we -padx 5
		grid [ttk::spinbox $ouput_tab.ih8_max_len_spbox						\
			-from 0 -to 255 -validate all -width 4						\
			-textvariable ::configDialogues::compiler::max_ihex_rec_length			\
			-validatecommand "::configDialogues::compiler::ih8_max_len_spbox_val %P"	\
		] -column 2 -row 12 -sticky w -columnspan 3 -padx 5


		#
		## Tab "Directives"
		#

		# Header
		grid [label $directives_tab.header				\
			-anchor w -text [mc "Ignore directives"]		\
			-font [font create					\
				-family {helvetica}				\
				-size [expr {int(-17 * $::font_size_factor)}]	\
				-weight bold					\
			]							\
		] -column 0 -row 0 -columnspan 3 -sticky we -pady 10 -padx 10
		grid [label $directives_tab.accept_label	\
			-text [mc "Accept"] -anchor w		\
		] -column 1 -row 1 -padx 5
		grid [label $directives_tab.ignore_label	\
			-text [mc "Ignore"] -anchor w		\
		] -column 2 -row 1 -padx 5

		# Create matrix of radio buttons
		set row 2
		foreach var {
				nomod		paging		pagelength
				pagewidth	title		date
				list
			} txt {
				$nomod		{$nopaging, $paging}	$pagelength
				$pagewidth	$title			$date
				{$list, $nolist, list, nolist}
			} helptext {
				{}
				{}
				{}
				{}
				{}
				{}
				{}
			} \
		{
			# Label
			grid [Label $directives_tab.${var}_label			\
				-text $txt -anchor w -highlightthickness 0 -bd 0	\
				-helptext $helptext	\
			] -column 0 -row $row -sticky we -padx 5
			# Accept
			grid [radiobutton $directives_tab.${var}_radio0 -value 0	\
				-variable ::configDialogues::compiler::option__${var}	\
			] -column 1 -row $row -padx 5
			# Ignore
			grid [radiobutton $directives_tab.${var}_radio1 -value 1	\
				-variable ::configDialogues::compiler::option__${var}	\
			] -column 2 -row $row -padx 5

			incr row
		}

		$nb0 raise ouput_tab
		pack [$nb0 get_nb] -side top -fill both -expand 1
	}

	## Validate content of spinbox "Max length of IHEX-8 record"
	 # @parm String string - String to validate
	 # @return Bool - Validation result
	proc ih8_max_len_spbox_val {string} {
		if {![string length $string]} {
			return 1
		}
		if {![string is digit -strict $string]} {
			return 0
		}
		if {$string > 255 || $string < 0} {
			return 0
		}
		return 1
	}

	## Retrieve settings from Compiler NS and X NS
	 # @return void
	proc getSettings {} {
		variable defaults		;# List of default settings
		variable opt_WARNING_LEVEL	;# Warning level
		variable max_ihex_rec_length	;# Int: Maximum length of IHEX-8 record

		variable selected_assembler	;# Int: Preferred assembler  (0==MCU8051IDE;1==ASEM-51;2==ASL)
		variable assembler_ASEM51_config;# Array: ASEM-51 configuration
		variable assembler_ASEM51_addcfg;# Array: ASEM-51 additional configuration
		variable assembler_ASL_config	;# Array: ASL configuration
		variable assembler_ASL_addcfg	;# Array: ASL additional configuration
		variable assembler_AS31_config	;# Array: AS31 configuration
		variable assembler_AS31_addcfg	;# Array: AS31 additional configuration

		variable sdcc_bool_opt		;# Array: SDCC configuration
		variable sdcc_str_opt		;# Array: SDCC configuration
		variable sdcc_opt_str_opt	;# Array: SDCC configuration
		variable sdcc_scs_str_opt	;# Array: SDCC configuration

		variable makeutil_config	;# Array: Make utility configuration


		## Assembler: MCU8051IDE
		 # Set local option variables
		foreach var $defaults {
			set var [lindex $var 0]
			set ::configDialogues::compiler::option_${var} [subst -nocommands "\$::Compiler::Settings::$var"]
		}
		set max_ihex_rec_length ${::Compiler::Settings::max_ihex_rec_length}

		 # Set warning level
		set tmp [mc "All"]
		switch -- ${::Compiler::Settings::WARNING_LEVEL} {
			0	{set tmp [mc "All"]}
			1	{set tmp [mc "Errors + Warnings"]}
			2	{set tmp [mc "Errros only"]}
			3	{set tmp [mc "Nothing"]}
			default	{puts stderr "Invalid WARNING_LEVEL value"}
		}
		set opt_WARNING_LEVEL $tmp

		## Preferred assembler
		set selected_assembler $::ExternalCompiler::selected_assembler
		## ASEM-51
		array set assembler_ASEM51_config	[array get ::ExternalCompiler::assembler_ASEM51_config]
		array set assembler_ASEM51_addcfg	[array get ::ExternalCompiler::assembler_ASEM51_addcfg]
		## ASL
		array set assembler_ASL_config		[array get ::ExternalCompiler::assembler_ASL_config]
		array set assembler_ASL_addcfg		[array get ::ExternalCompiler::assembler_ASL_addcfg]
		## AS31
		array set assembler_AS31_config		[array get ::ExternalCompiler::assembler_AS31_config]
		array set assembler_AS31_addcfg		[array get ::ExternalCompiler::assembler_AS31_addcfg]

		## SDCC
		 # Copy boolean options
		array set sdcc_bool_opt			[array get ::ExternalCompiler::sdcc_bool_options]
		 # Copy string options
		array set sdcc_str_opt			[array get ::ExternalCompiler::sdcc_string_options]
		 # Copy optional strings
		array set sdcc_opt_str_opt		[array get ::ExternalCompiler::sdcc_optional_string_options]
		 # Copy semicolon separated optional string options
		array set sdcc_scs_str_opt		[array get ::ExternalCompiler::sdcc_scs_string_options]

		## GNU Make utility configuration
		 # General options
		foreach key [array names ::ExternalCompiler::makeutil_config] {
			set makeutil_config($key) $::ExternalCompiler::makeutil_config($key)
		}
	}

	## Set compiler according to local settings
	 # @return void
	proc use_settings {} {
		variable defaults		;# List of default settings
		variable opt_WARNING_LEVEL	;# Warning level
		variable conf_affected		;# Array of Bool: Affected parts of configuration

		variable max_ihex_rec_length	;# Int: Maximum length of IHEX-8 record
		variable selected_assembler	;# Int: Preferred assembler  (0==MCU8051IDE;1==ASEM-51;2==ASL)
		variable assembler_ASEM51_config;# Array: ASEM-51 configuration
		variable assembler_ASEM51_addcfg;# Array: ASEM-51 additional configuration
		variable assembler_ASL_config	;# Array: ASL configuration
		variable assembler_ASL_addcfg	;# Array: ASL additional configuration
		variable assembler_AS31_config	;# Array: AS31 configuration
		variable assembler_AS31_addcfg	;# Array: AS31 additional configuration

		variable asm51_custom_opts_text	;# Widget: Text widget "Custom options for ASEM-51"
		variable asl_custom_opts_text	;# Widget: Text widget "Custom options for ASL"
		variable as31_custom_opts_text	;# Widget: Text widget "Custom options for AS31"
		variable sdcc_custom_opts_text	;# Widget: Text widget "Custom options for SDCC"

		variable sdcc_bool_opt		;# Array: SDCC configuration
		variable sdcc_str_opt		;# Array: SDCC configuration
		variable sdcc_opt_str_opt	;# Array: SDCC configuration
		variable sdcc_scs_str_opt	;# Array: SDCC configuration

		variable makeutil_config	;# Array: Make utility configuration

		## Assembler: MCU8051IDE
		if {$conf_affected(MCU8051IDE)} {
			# Set option variables
			foreach var $defaults {
				set var [lindex $var 0]
				set ::Compiler::Settings::$var [subst -nocommands "\$::configDialogues::compiler::option_${var}"]
			}
			if {![string length $max_ihex_rec_length]} {
				set max_ihex_rec_length 0
			}
			set Compiler::Settings::max_ihex_rec_length $max_ihex_rec_length

			# Set warning level
			set tmp ${::Compiler::Settings::WARNING_LEVEL}
			switch -- $opt_WARNING_LEVEL [subst {
				{[mc "All"]} {
					set tmp 0
				}
				[mc "Errors + Warnings"] {
					set tmp 1
				}
				{[mc "Errros only"]} {
					set tmp 2
				}
				{[mc "Nothing"]} {
					set tmp 3
				}
				default	{
					puts stderr "Invalid WARNING_LEVEL value"
				}
			}]
			set ::Compiler::Settings::WARNING_LEVEL $tmp
		}

		## Preferred assembler
		if {$conf_affected(Compiler)} {
			set ::ExternalCompiler::selected_assembler $selected_assembler
		}

		## Assembler: ASEM51
		if {$conf_affected(ASEM51)} {
			array set ::ExternalCompiler::assembler_ASEM51_addcfg	\
				[array get assembler_ASEM51_addcfg]
			array set ::ExternalCompiler::assembler_ASEM51_config	\
				[array get assembler_ASEM51_config]
			set ::ExternalCompiler::assembler_ASEM51_config(custom)	\
				[regsub {\n$} [$asm51_custom_opts_text get 1.0 end] {}]
		}

		## Assembler: ASL
		if {$conf_affected(ASL)} {
			array set ::ExternalCompiler::assembler_ASL_addcfg	\
				[array get assembler_ASL_addcfg]
			array set ::ExternalCompiler::assembler_ASL_config	\
				[array get assembler_ASL_config]
			set ::ExternalCompiler::assembler_ASL_config(custom)	\
				[regsub {\n$} [$asl_custom_opts_text get 1.0 end] {}]
		}

		## Assembler: AS31
		if {$conf_affected(AS31)} {
			array set ::ExternalCompiler::assembler_AS31_addcfg	\
				[array get assembler_AS31_addcfg]
			array set ::ExternalCompiler::assembler_AS31_config	\
				[array get assembler_AS31_config]
			set ::ExternalCompiler::assembler_AS31_config(custom)	\
				[regsub {\n$} [$as31_custom_opts_text get 1.0 end] {}]
		}

		## SDCC Custom options
		if {$conf_affected(SDCC_Custom)} {
			set sdcc_str_opt(custom) [regsub {\n$} [$sdcc_custom_opts_text get 1.0 end] {}]
			set ::ExternalCompiler::sdcc_string_options(custom) $sdcc_str_opt(custom)
		}

		## SDCC Configuration
		if {
			$conf_affected(SDCC_Linker) || $conf_affected(SDCC_Optimization) ||
			$conf_affected(SDCC_Code) || $conf_affected(SDCC_General)
		} then {
			# Copy boolean options
			array set ::ExternalCompiler::sdcc_bool_options [array get sdcc_bool_opt]
			# Copy string options
			array set ::ExternalCompiler::sdcc_string_options [array get sdcc_str_opt]
			# Copy optional strings
			array set ::ExternalCompiler::sdcc_optional_string_options [array get sdcc_opt_str_opt]
			# Copy semicolon separated optional string options
			array set ::ExternalCompiler::sdcc_scs_string_options [array get sdcc_scs_str_opt]
		}

		## GNU Make utility configuration
		 # General options
		foreach key [array names ::ExternalCompiler::makeutil_config] {
			set ::ExternalCompiler::makeutil_config($key) $makeutil_config($key)
		}

		${::X::actualProject} retrieve_compiler_settings
	}

	## Save settings to config file
	 # @return void
	proc save_config {} {
		variable max_ihex_rec_length	;# Int: Maximum length of IHEX-8 record
		variable defaults		;# List of default settings

		## Assembler: MCU8051IDE
		 # Save option variables
		foreach var $defaults {
			set var [lindex $var 0]
			::settings setValue	\
				"Compiler/$var"	\
				[subst -nocommands "\$::Compiler::Settings::${var}"]
		}
		::settings setValue "Compiler/max_ihex_rec_length"	\
			${::Compiler::Settings::max_ihex_rec_length}
		 # Save warning level
		::settings setValue "Compiler/WARNING_LEVEL"	\
			${::Compiler::Settings::WARNING_LEVEL}

		## Preferred assembler
		::settings setValue "Compiler/selected_assembler"	\
			$::ExternalCompiler::selected_assembler

		## Assembler: ASEM-51
		::settings setValue "Compiler/assembler_ASEM51_addcfg"	\
			[array get ::ExternalCompiler::assembler_ASEM51_addcfg]
		::settings setValue "Compiler/assembler_ASEM51_config"	\
			[array get ::ExternalCompiler::assembler_ASEM51_config]

		## Assembler: ASL
		::settings setValue "Compiler/assembler_ASL_addcfg"	\
			[array get ::ExternalCompiler::assembler_ASL_addcfg]
		::settings setValue "Compiler/assembler_ASL_config"	\
			[array get ::ExternalCompiler::assembler_ASL_config]

		## Assembler: AS31
		::settings setValue "Compiler/assembler_AS31_addcfg"	\
			[array get ::ExternalCompiler::assembler_AS31_addcfg]
		::settings setValue "Compiler/assembler_AS31_config"	\
			[array get ::ExternalCompiler::assembler_AS31_config]

		## SDCC
		foreach array {
			sdcc_bool_options		sdcc_string_options
			sdcc_optional_string_options	sdcc_scs_string_options
		} {
			::settings setValue "Compiler/$array"	\
				[array get ::ExternalCompiler::$array]
		}

		## GNU Make utility configuration
		 # General options
		foreach key [array names ::ExternalCompiler::makeutil_config] {
			::settings setValue "Compiler/make_${key}"	\
					$::ExternalCompiler::makeutil_config($key)
		}

		# Synchronize
		::settings saveConfig
	}

	## Load settings from config file
	 # @return void
	proc load_config {} {
		variable defaults		;# List of default settings
		variable max_ihex_rec_length	;# Int: Maximum length of IHEX-8 record

		## Assembler: MCU8051IDE
		 # Load normal options
		foreach item $defaults {
			set var [lindex $item 0]
			set val [lindex $item 1]
			set ::Compiler::Settings::${var}	\
				[::settings getValue "Compiler/$var" $val]
		}
		set ::Compiler::Settings::max_ihex_rec_length			\
			[ ::settings getValue					\
				"Compiler/max_ihex_rec_length"			\
				${::Compiler::Settings::max_ihex_rec_length}	\
			]
		if {
			![string is digit -strict ${::Compiler::Settings::max_ihex_rec_length}] ||
			${::Compiler::Settings::max_ihex_rec_length} < 0 ||
			${::Compiler::Settings::max_ihex_rec_length} > 255
		} then {
			set ::Compiler::Settings::max_ihex_rec_length 255
		}
		 # Load warning level
		set ::Compiler::Settings::WARNING_LEVEL			\
			[ ::settings getValue				\
				"Compiler/WARNING_LEVEL"		\
				${::Compiler::Settings::WARNING_LEVEL}	\
			]

		## Preferred assembler
		set ::ExternalCompiler::selected_assembler [::settings getValue	\
			"Compiler/selected_assembler"			\
			$::ExternalCompiler::selected_assembler_def	\
		]

		## Assembler: ASEM51
		 # Base config
		set conf [::settings getValue "Compiler/assembler_ASEM51_config"	\
			$::ExternalCompiler::assembler_ASEM51_config_def		\
		]
		set len [llength $conf]
		for {set i 0} {$i < $len} {incr i} {
			set key [lindex $conf $i]
			incr i
			set val [lindex $conf $i]

			if {[llength [array names ::ExternalCompiler::assembler_ASEM51_config -exact $key]]} {
				set ::ExternalCompiler::assembler_ASEM51_config($key) $val
			}
		}
		 # Additional config
		set conf [::settings getValue "Compiler/assembler_ASEM51_addcfg"	\
			$::ExternalCompiler::assembler_ASEM51_addcfg_def		\
		]
		set len [llength $conf]
		for {set i 0} {$i < $len} {incr i} {
			set key [lindex $conf $i]
			incr i
			set val [lindex $conf $i]

			if {[llength [array names ::ExternalCompiler::assembler_ASEM51_addcfg -exact $key]]} {
				set ::ExternalCompiler::assembler_ASEM51_addcfg($key) $val
			}
		}

		## Assembler: ASL
		 # Base config
		set conf [::settings getValue "Compiler/ASL"		\
			$::ExternalCompiler::assembler_ASL_config_def	\
		]
		set len [llength $conf]
		for {set i 0} {$i < $len} {incr i} {
			set key [lindex $conf $i]
			incr i
			set val [lindex $conf $i]

			if {[llength [array names ::ExternalCompiler::assembler_ASL_config -exact $key]]} {
				set ::ExternalCompiler::assembler_ASL_config($key) $val
			}
		}
		 # Additional config
		set conf [::settings getValue "Compiler/ASL"		\
			$::ExternalCompiler::assembler_ASL_addcfg_def	\
		]
		set len [llength $conf]
		for {set i 0} {$i < $len} {incr i} {
			set key [lindex $conf $i]
			incr i
			set val [lindex $conf $i]

			if {[llength [array names ::ExternalCompiler::assembler_ASL_addcfg -exact $key]]} {
				set ::ExternalCompiler::assembler_ASL_addcfg($key) $val
			}
		}

		## Assembler: AS31
		 # Base config
		set conf [::settings getValue "Compiler/AS31"		\
			$::ExternalCompiler::assembler_AS31_config_def	\
		]
		set len [llength $conf]
		for {set i 0} {$i < $len} {incr i} {
			set key [lindex $conf $i]
			incr i
			set val [lindex $conf $i]

			if {[llength [array names ::ExternalCompiler::assembler_AS31_config -exact $key]]} {
				set ::ExternalCompiler::assembler_AS31_config($key) $val
			}
		}
		 # Additional config
		set conf [::settings getValue "Compiler/AS31"		\
			$::ExternalCompiler::assembler_AS31_addcfg_def	\
		]
		set len [llength $conf]
		for {set i 0} {$i < $len} {incr i} {
			set key [lindex $conf $i]
			incr i
			set val [lindex $conf $i]

			if {[llength [array names ::ExternalCompiler::assembler_AS31_addcfg -exact $key]]} {
				set ::ExternalCompiler::assembler_AS31_addcfg($key) $val
			}
		}

		## SDCC
		foreach array {
			sdcc_bool_options		sdcc_string_options
			sdcc_optional_string_options	sdcc_scs_string_options
		} {
			set conf [::settings getValue				\
				"Compiler/$array" [subst -nocommands "\$::ExternalCompiler::${array}_def"]	\
			]
			set len [llength $conf]
			for {set i 0} {$i < $len} {incr i} {
				set key [lindex $conf $i]
				incr i
				set val [lindex $conf $i]

				if {[llength [array names ::ExternalCompiler::$array -exact $key]]} {
					set ::ExternalCompiler::${array}($key) $val
				}
			}
		}

		## GNU Make utility configuration
		 # General options
		foreach {key def_value} ${::ExternalCompiler::makeutil_config_def} {
			set conf [::settings getValue			\
				"Compiler/make_${key}" $def_value	\
			]
			set ::ExternalCompiler::makeutil_config($key) $conf
		}
	}

	## Destroy the dialog
	 # @return void
	proc CANCEL {} {
		variable win		;# ID of toplevel dialog window
		variable dialog_opened	;# Bool: True if this dialog is already opened

		# Destroy dialog window
		set dialog_opened 0
		grab release $win
		destroy $win
	}

	## Use settings and destroy the dialog
	 # @return void
	proc OK {} {
		variable win	;# ID of toplevel dialog window

		# Use and save settings
		use_settings
		save_config

		# Destroy dialog window
		CANCEL
	}

	## Restrore defaults
	 # @return void
	proc DEFAULTS {} {
		variable win			;# ID of toplevel dialog window
		variable defaults		;# List of default settings
		variable opt_WARNING_LEVEL	;# Warning level
		variable max_ihex_rec_length	;# Int: Maximum length of IHEX-8 record

		# Text widgets
		variable sdcc_custom_opts_text	;# Widget: Text widget "Custom options for SDCC"
		variable asm51_custom_opts_text	;# Widget: Text widget "Custom options for ASEM-51"
		variable asl_custom_opts_text	;# Widget: Text widget "Custom options for ASL"
		variable as31_custom_opts_text	;# Widget: Text widget "Custom options for AS31"

		# External assembler configuration
		variable selected_assembler	;# Int: Preferred assembler  (0==MCU8051IDE;1==ASEM-51;2==ASL)
		variable assembler_ASEM51_config;# Array: ASEM-51 configuration
		variable assembler_ASEM51_addcfg;# Array: ASEM-51 additional configuration
		variable assembler_ASL_config	;# Array: ASL configuration
		variable assembler_ASL_addcfg	;# Array: ASL additional configuration
		variable assembler_AS31_config	;# Array: AS31 configuration
		variable assembler_AS31_addcfg	;# Array: AS31 additional configuration

		# SDCC Configuration
		variable sdcc_bool_opt		;# Array: SDCC configuration
		variable sdcc_str_opt		;# Array: SDCC configuration
		variable sdcc_opt_str_opt	;# Array: SDCC configuration
		variable sdcc_scs_str_opt	;# Array: SDCC configuration

		# GNU Make utility configuration
		variable makeutil_config	;# Array: Make utility configuration

		# Confirmation dialog
		if {
			[tk_messageBox		\
				-parent $win	\
				-type yesno	\
				-icon question	\
				-title [mc "Restore defaults"]	\
				-message [mc "Are you sure that you want restore default settings ?"]	\
			] != {yes}
		} then {
			return
		}

		## Preferred assembler
		set selected_assembler $::ExternalCompiler::selected_assembler_def
		## Assembler MCU8051IDE
		 # Restore normal options
		foreach item $defaults {
			set var [lindex $item 0]
			set val [lindex $item 1]
			set ::configDialogues::compiler::option_${var} $val
		}
		set max_ihex_rec_length 16
		 # Warning level
		set opt_WARNING_LEVEL [mc "All"]
		## ASEM-51
		array set assembler_ASEM51_addcfg $::ExternalCompiler::assembler_ASEM51_addcfg_def
		array set assembler_ASEM51_config $::ExternalCompiler::assembler_ASEM51_config_def
		 # Custom options
		if {[winfo exists $asm51_custom_opts_text]} {
			$asm51_custom_opts_text delete 1.0 end
			$asm51_custom_opts_text insert end $assembler_ASEM51_config(custom)
		}
		## ASL
		array set assembler_ASL_addcfg $::ExternalCompiler::assembler_ASL_addcfg_def
		array set assembler_ASL_config $::ExternalCompiler::assembler_ASL_config_def
		 # Custom options
		if {[winfo exists $asl_custom_opts_text]} {
			$asl_custom_opts_text delete 1.0 end
			$asl_custom_opts_text insert end $assembler_ASL_config(custom)
		}
		## AS31
		array set assembler_AS31_addcfg $::ExternalCompiler::assembler_AS31_addcfg_def
		array set assembler_AS31_config $::ExternalCompiler::assembler_AS31_config_def
		 # Custom options
		if {[winfo exists $as31_custom_opts_text]} {
			$as31_custom_opts_text delete 1.0 end
			$as31_custom_opts_text insert end $assembler_AS31_config(custom)
		}

		## SDCC
		 # Copy boolean options
		array set sdcc_bool_opt		${::ExternalCompiler::sdcc_bool_options_def}
		 # Copy string options
		array set sdcc_str_opt		${::ExternalCompiler::sdcc_string_options_def}
		 # Copy optional strings
		array set sdcc_opt_str_opt	${::ExternalCompiler::sdcc_optional_string_options_def}
		 # Copy semicolon separated optional string options
		array set sdcc_scs_str_opt	${::ExternalCompiler::sdcc_scs_string_options_def}
		 # Custom options
		if {[winfo exists $sdcc_custom_opts_text]} {
			$sdcc_custom_opts_text delete 1.0 end
			$sdcc_custom_opts_text insert end $sdcc_str_opt(custom)
		}

		## GNU Make utility configuration
		 # General options
		foreach {key value} ${::ExternalCompiler::makeutil_config_def} {
			set makeutil_config($key) $value
		}
		 # Adjust GUI to the current config
		make_tab__adjust_gui
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

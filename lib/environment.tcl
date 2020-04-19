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
if { ! [ info exists _ENVIRONMENT_TCL ] } {
set _ENVIRONMENT_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# * Defines some settings and procedures
# * Defines basic GUI environment:
#	- Main menubar
#	- Main toolbar
#	- Status bar
# --------------------------------------------------------------------------


# PRE-INITIALIZATION
# ----------------------------------------

# Restore last session
set show_welcome_dialog 0
if {![X::restore_session]} {
	set show_welcome_dialog 1
}

# Restore spell checker configuration from the last session
if {${::PROGRAM_AVAILABLE(hunspell)}} {
	set ::Editor::spellchecker_enabled	${::CONFIG(SPELL_CHECK_ENABLED)}
	set ::Editor::spellchecker_dictionary	${::CONFIG(SPELL_CHECK_DICTIONARY)}
} else {
	set ::Editor::spellchecker_enabled	0
	set ::Editor::spellchecker_dictionary	{}
}

# Some key shortcuts for main window
bind . <Control-Key-1> {manipulate_panel {sim}		; break}
bind . <Control-Key-2> {manipulate_panel {graph}	; break}
bind . <Control-Key-3> {manipulate_panel {mess}		; break}
bind . <Control-Key-4> {manipulate_panel {todo}		; break}
bind . <Control-Key-5> {manipulate_panel {calc}		; break}

# bind . <Alt-Control-Key-1> {manipulate_panel {lsh}	; break}
# bind . <Alt-Control-Key-2> {manipulate_panel {open}	; break}
# bind . <Alt-Control-Key-3> {manipulate_panel {proj}	; break}
# bind . <Alt-Control-Key-4> {manipulate_panel {fsb}	; break}
# bind . <Alt-Control-Key-5> {manipulate_panel {sfr}	; break}

bind . <Control-Key-6> {manipulate_panel {book}		; break}
bind . <Control-Key-7> {manipulate_panel {brk}		; break}
bind . <Control-Key-8> {manipulate_panel {ins}		; break}
bind . <Control-Key-9> {manipulate_panel {wtch}		; break}
bind . <Control-Key-0> {manipulate_panel {sub}		; break}
# bind . <Alt-Key-5> {manipulate_panel {rsh}		; break}

# General widget bindings
bind Menu <Button>		{+catch {%W configure -cursor left_ptr}}
bind Text <ButtonPress-1>	{+focus %W}
bind Text <Control-d>		{}
bind Text <Control-b>		{}
bind Text <Control-a>		{}
bind Text <Control-o>		{}
bind Text <Control-i>		{}
bind Text <Control-f>		{}
bind Text <F3>			{}
bind Text <Insert>		{}
bind Text <KP_Enter>		"[bind Text <Return>]; break"
bind Text <Control-Key-z>	{catch {%W edit undo}; break}
bind Text <Control-Key-Z>	{catch {%W edit redo}; break}
bind Text <Control-Key-c>	{tk_textCopy %W; break}
bind Text <Control-Key-C>	{tk_textCopy %W; break}
bind Text <Control-Key-x>	{tk_textCut %W; break}
bind Text <Control-Key-v>	{
	catch {
		%W delete sel.first sel.last
	}
	tk_textPaste %W
}
bind Text <<Paste>>		{
	catch {
		%W delete sel.first sel.last
	}
	catch {
		%W insert insert [clipboard get]
	}
	break
}
bind Text <Control-Key-a>	{%W tag add sel 1.0 end; break}
bind Entry <<Paste>>		{
	catch {
		%W delete sel.first sel.last
	}
	catch {
		%W insert insert [clipboard get]
	}
	break
}
bind Entry <Control-Key-a>	{%W selection range 0 end; break}
bind TEntry <Control-Key-a>	{%W selection range 0 end; break}

# Dynamic help (Bwidget)
DynamicHelp::configure -font [font create -size [expr {int(-14 * $::font_size_factor)}] -family {helvetica}] -delay 500 -background {#FFFFDD}

# General purpose fonts
set smallfont_color {#5599DD}
set smallfont [font create -size [expr {int(-10 * $::font_size_factor)}] -family {helvetica} -weight normal]
set smallfont_bold [font create -size [expr {int(-10 * $::font_size_factor)}] -family {helvetica} -weight bold]

# LOAD PROGRAM ICONS
# -----------------------------
foreach directory {16x16 22x22 32x32 flag} ns {16 22 32 flag} {
	namespace eval ::ICONS::${ns} {}
	if {!$::MICROSOFT_WINDOWS} {
		# Use glob
		set list_of_icons [glob "${::ROOT_DIRNAME}/icons/${directory}/*.png"]
	} else {
		# Use ZIP Virtual File System (freeWrap)
		set list_of_icons [zvfs::list "${::ROOT_DIRNAME}/icons/${directory}/*.png"]
	}
	foreach filename $list_of_icons {
		set iconname [file tail $filename]
		regexp {^\w+} $iconname iconname
		if {[catch {
			image create photo ::ICONS::${ns}::${iconname} -format png -file $filename
		} result]} then {
			puts stderr {}
			puts -nonewline stderr $result
			image create photo ::ICONS::${ns}::${iconname}
		}
	}
}

# WM and Tk options
tk appname "mcu8051ide"
wm command . "mcu8051ide $argv"
wm client . [info hostname]
tk scaling 1.0
tk_setPalette						\
	activeBackground	${::COMMON_BG_COLOR}	\
	foreground		{#000000}		\
	selectColor		{#FFFFFF}		\
	activeForeground	{#0000DD}		\
	highlightBackground	${::COMMON_BG_COLOR}	\
	selectBackground	{#9999BB}		\
	background		${::COMMON_BG_COLOR}	\
	highlightColor		{#000000}		\
	selectForeground	{#FFFFFF}		\
	disabledForeground	{#888888}		\
	insertBackground	{#000000}		\
	troughColor		${::COMMON_BG_COLOR}

wm title . "MCU 8051 IDE"
wm state . normal
wm minsize . 640 480
wm geometry . $::CONFIG(WINDOW_GEOMETRY)
if {$::CONFIG(WINDOW_ZOOMED)} {
	if {!$::MICROSOFT_WINDOWS} {
		wm attributes . -zoomed $::CONFIG(WINDOW_ZOOMED)
	} else {
		wm state . zoomed

		# Without this help windows won't work properly on MS Windows
		after idle {
			update
			wm geometry . [wm geometry .]
		}
	}
}
wm protocol . WM_DELETE_WINDOW {::X::__exit}
wm iconphoto . ::ICONS::16::mcu8051ide
. configure -bg ${::COMMON_BG_COLOR}

# Dynamic Data Exchange on Microsoft Windows
if {$::MICROSOFT_WINDOWS} {
	dde servername -force -- [tk appname]
}

ttk::style theme use ${::GLOBAL_CONFIG(wstyle)}

# - ttk
set TTK_COMMON_BG {#E0E0E0}
ttk::style configure TFrame	\
	-background ${::COMMON_BG_COLOR}

ttk::style configure TNotebook	\
	-background ${::COMMON_BG_COLOR}	\
	-fieldbackground {red}
ttk::style map TNotebook		\
	-background [list		\
		active		red	\
		pressed		blue	\
		pressed		green	\
	]

font configure TkTextFont -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight {normal}
font configure TkDefaultFont -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight {normal}

ttk::style configure StringNotFound.TEntry	\
	-fieldbackground {#FFDDDD}
ttk::style configure StringFound.TEntry		\
	-fieldbackground {#DDFFDD}

ttk::style configure Simulator.TEntry
ttk::style map Simulator.TEntry				\
	-fieldbackground [list readonly {#F8F8F8}]	\
	-foreground [list readonly {#888888}]
ttk::style configure Simulator_HG.TEntry		\
	-foreground {#CC8800}
ttk::style configure Simulator_WhiteBg.TEntry		\
	-fieldbackground {#FFFFFF}			\
	-fielddisabledbackground {#FFFFFF}
ttk::style configure Simulator_WhiteBg_HG.TEntry	\
	-fieldbackground {#FFFFFF}			\
	-fielddisabledbackground {#FFFFFF}		\
	-foreground {#CC8800}
ttk::style configure Simulator_WhiteBg_Sel.TEntry	\
	-fieldbackground {#DDDDFF}			\
	-fielddisabledbackground {#DDDDFF}
ttk::style configure Simulator_WhiteBg_HG_Sel.TEntry	\
	-foreground {#CC8800}				\
	-fieldbackground {#DDDDFF}			\
	-fielddisabledbackground {#DDDDFF}

ttk::style configure Simulator_watchdogEntry_0.TEntry	\
	-fieldbackground {#88FF88}			\
	-fielddisabledbackground {#66DD66}
ttk::style map Simulator_watchdogEntry_0.TEntry		\
	-foreground [list readonly {#888888}]

ttk::style configure Simulator_watchdogEntry_1.TEntry	\
	-fieldbackground {#FFFF55}			\
	-fielddisabledbackground {#DDDD33}
ttk::style map Simulator_watchdogEntry_1.TEntry		\
	-foreground [list readonly {#888888}]

ttk::style configure Simulator_watchdogEntry_2.TEntry	\
	-fieldbackground {#FF5555}			\
	-fielddisabledbackground {#DD3333}
ttk::style map Simulator_watchdogEntry_2.TEntry		\
	-foreground [list readonly {#888888}]

ttk::style configure TLabelframe	\
	-background ${::COMMON_BG_COLOR}
ttk::style configure TLabel		\
	-background ${::COMMON_BG_COLOR}

ttk::style configure TButton		\
	-background $TTK_COMMON_BG	\
	-padding 0
ttk::style configure RedBg.TButton	\
	-padding 0				\
	-font [font create -family $::DEFAULT_FIXED_FONT -size -12 -weight {normal}]
ttk::style map RedBg.TButton			\
	-background [list			\
		active		{#FFBBBB}	\
		!active		{#FF8888}	\
	]					\
	-foreground [list			\
		active		{#FF0000}	\
		!active		{#000000}	\
	]
ttk::style configure GreenBg.TButton		\
	-padding 0				\
	-font [font create -family $::DEFAULT_FIXED_FONT -size -12 -weight {normal}]
ttk::style map GreenBg.TButton			\
	-background [list			\
		active		{#BBFFBB}	\
		!active		{#88FF88}	\
	]					\
	-foreground [list			\
		active		{#00FF00}	\
		!active		{#000000}	\
	]

ttk::style configure Flat.TButton		\
	-background ${::COMMON_BG_COLOR}	\
	-padding 0				\
	-borderwidth 1				\
	-relief flat
ttk::style map Flat.TButton			\
	-relief [list active raised]		\
	-background [list disabled ${::COMMON_BG_COLOR}]

ttk::style configure TMenubutton	\
	-padding 0			\
	-background $TTK_COMMON_BG
ttk::style configure Flat.TMenubutton	\
	-padding 0			\
	-background ${::COMMON_BG_COLOR}\
	-borderwidth 1			\
	-relief flat
ttk::style map Flat.TMenubutton		\
	-relief [list active raised]	\
	-background [list disabled ${::COMMON_BG_COLOR}]

ttk::style configure FlatWhite.TButton	\
	-padding 0			\
	-background {#FFFFFF}		\
	-borderwidth 1			\
	-relief flat
ttk::style map FlatWhite.TButton	\
	-relief [list active raised]	\
	-background [list disabled {#FFFFFF}]

ttk::style configure ToolButton.TButton	\
	-background ${::COMMON_BG_COLOR}\
	-padding 1			\
	-borderwidth 1			\
	-relief flat
ttk::style map ToolButton.TButton	\
	-relief [list active raised]	\
	-background [list disabled ${::COMMON_BG_COLOR}]

ttk::style configure TCombobox		\
	-background $TTK_COMMON_BG	\
	-fieldfont [font create -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight {normal}]
ttk::style map TCombobox					\
	-foreground [list disabled {#888888}]			\
	-fieldbackground [list					\
		readonly		$TTK_COMMON_BG		\
		disabled		${::COMMON_BG_COLOR}	\
		{!readonly !disabled}	{#FFFFFF}		\
	]

ttk::style configure TScrollbar		\
	-background $TTK_COMMON_BG	\
	-troughcolor {#F8F8F8}

ttk::style configure TScale		\
	-background $TTK_COMMON_BG
ttk::style map TScale				\
	-troughcolor [list			\
		disabled	$TTK_COMMON_BG	\
		!disabled	{#F8F8F8}	\
	]

ttk::style configure TProgressbar	\
	-background {#CCCCFF}		\
	-troughcolor $TTK_COMMON_BG

ttk::style configure GreenBg.TSpinbox -fieldbackground {#CCFFCC}
ttk::style configure RedBg.TSpinbox -fieldbackground {#FFCCCC}

update idletasks

## Widget styles
 # Load images for checkbuttons and radiobuttons
foreach i {raoff raon choff chon} {
	if {[catch {
		image create photo ::ICONS::$i -file "${::ROOT_DIRNAME}/icons/other/$i.png" -format png
	} result]} then {
		puts stderr {}
		puts -nonewline stderr $result
		image create photo ::ICONS::$i
	}
}
 # - Menu
if {!${::MICROSOFT_WINDOWS}} {
	option add *Menu.background		{#F8F8F8}	userDefault
	option add *Menu.relief			raised		userDefault
	option add *Menu.borderWidth		1		userDefault
} else {
	option add *Menu.background		{#FFFFFF}	userDefault
	option add *Menu.relief			flat		userDefault
	option add *Menu.borderWidth		0		userDefault
}
option add *Menu.activeBackground	{#8888DD}	userDefault
option add *Menu.activeForeground	{#FFFFFF}	userDefault
option add *Menu.font [font create -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight {normal}] userDefault
option add *Menu.activeBorderWidth	1		userDefault
option add *Menu.cursor			left_ptr	userDefault
option add *Menu.tearOff		0		userDefault
 # - Label
option add *Label.highlightThickness 	0		userDefault
 # - Entry
option add *Entry.highlightThickness 	0		userDefault
option add *Entry.BorderWidth		1		userDefault
option add *Entry.font [font create -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight {normal}] userDefault
 # - Text
option add *Text.Background		{#FFFFFF}	userDefault
option add *Text.highlightThickness	0		userDefault
option add *Text.BorderWidth		1		userDefault
option add *Text.Relief			sunken		userDefault
option add *Text.font [font create -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight {normal}] userDefault
 # - Spinbox
option add *Spinbox.Background		{#FFFFFF}	userDefault
option add *Spinbox.highlightThickness	0		userDefault
option add *Spinbox.ExportSelection	0		userDefault
 # - Scrollbar
option add *Scrollbar.activeBackground	{#8888FF}	userDefault
option add *Scrollbar.BorderWidth	1		userDefault
option add *Scrollbar.Background	${::COMMON_BG_COLOR}	userDefault
option add *Scrollbar.troughColor	${::COMMON_BG_COLOR}	userDefault
option add *Scrollbar.Relief		sunken		userDefault
option add *Scrollbar.activeRelief	raised		userDefault
option add *Scrollbar.elementBorderWidth	1	userDefault
 # - Button
option add *Button.activeForeground	{#0000DD}	interactive
option add *Button.font [font create -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight {normal}] userDefault
 # - Radiobutton
option add *Radiobutton.BorderWidth	0		userDefault
option add *Radiobutton.Image		::ICONS::raoff	userDefault
option add *Radiobutton.SelectImage	::ICONS::raon	userDefault
option add *Radiobutton.selectColor	${::COMMON_BG_COLOR}	userDefault
option add *Radiobutton.Compound	left		userDefault
option add *Radiobutton.IndicatorOn	0		userDefault
option add *Radiobutton.font [font create -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight {normal}] userDefault
 # - Checkbutton
option add *Checkbutton.BorderWidth	0		userDefault
option add *Checkbutton.Image		::ICONS::choff	userDefault
option add *Checkbutton.SelectImage	::ICONS::chon	userDefault
option add *Checkbutton.selectColor	${::COMMON_BG_COLOR}	userDefault
option add *Checkbutton.Compound	left		userDefault
option add *Checkbutton.IndicatorOn	0		userDefault
option add *Radiobutton.font [font create -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight {normal}] userDefault
 # - Scale
option add *Scale.activeBackground	{#8888FF}	userDefault
 # - NoteBook
option add *NoteBook.font [font create -family {helvetica} -size [expr {int(-12 * $::font_size_factor)}] -weight {normal}] userDefault
option add *NoteBook.Background		${::COMMON_BG_COLOR}	userDefault
option add *NoteBook.ActiveBackground	{#AAAADD}	userDefault
 # - TopLevel and Frame
option add *Toplevel.Background		${::COMMON_BG_COLOR}	userDefault
option add *Frame.Background		${::COMMON_BG_COLOR}	userDefault
option add *PagesManager.Background	${::COMMON_BG_COLOR}	userDefault
 # - Others ...
option add *Panedwindow.Background	${::COMMON_BG_COLOR}	userDefault
option add *Listbox.Background		${::COMMON_BG_COLOR}	userDefault
option add *Button.Background		${::COMMON_BG_COLOR}	userDefault
option add *Label.Background		${::COMMON_BG_COLOR}	userDefault
option add *Canvas.Background		${::COMMON_BG_COLOR}	userDefault
option add *ComboBox.ExportSelection	0			userDefault


# MEMORY CELL HELP WINDOW
# -------------------------------

set help_window_for_bit		 0	;# Bool: Current help window is representing a bit not byte
set help_window_variable_address 0	;# Bool: Help window with variable address (intended for register watches)
set HELPWINDOW {}			;# Widget: Help window
# Objects in canvas widget in the bit help window
array set help_window_bit {
	0 {} 1 {} 2 {} 3 {} 4 {} 5 {} 6 {} 7 {}
	R {} B {} A {}
}

## Create memory cell help window for future use
 # @parm Widget root	- parent GUI object (eg. '.')
 # @parm String val	- hexadecimal representation of cell value
 # @parm String addr	- hexadecimal representation of cell address
 # @return void
proc create_help_window {root val addr} {
	global help_window_variable_address
	global help_window_for_bit

	# Set parent and detroy previous help window
	set ::HELPWINDOW_ROOT $root
	catch {destroy ${::HELPWINDOW}}
	set ::HELPWINDOW {}

	# Normalize root name
	if {![regexp {\.$} $root]} {
		append root {.}
	}

	# Create logical frame structure
	set ::HELPWINDOW [frame ${root}help_window -bd 0 -bg {#BBBBFF} -padx 2 -pady 2]
	pack [frame ${::HELPWINDOW}.top -bg {#BBBBFF}] -fill x -expand 1
	pack [label ${::HELPWINDOW}.top.img -bg {#BBBBFF}] -side left
	pack [label ${::HELPWINDOW}.top.tit -bg {#BBBBFF}] -side left -fill x -expand 1
	pack [frame ${::HELPWINDOW}.msg -bg {#FFFFFF}] -fill both -expand 1

	# Create window header
	${::HELPWINDOW}.top.img configure -image ::ICONS::16::kcmmemory
	set haddr $addr
	if {[string length [lindex $haddr 0]] == 3} {
		set haddr [string replace $haddr 0 0]
	}
	${::HELPWINDOW}.top.tit configure -text "0x$haddr"

	if {[lindex $addr 1] == {BIT}} {
		set help_window_for_bit 1
		create_help_window_bit [lindex $addr 0]
	} else {
		set help_window_for_bit 0
		create_help_window_byte $val
	}

	set help_window_variable_address 0 ;# Bool: Help window with variable address
}

## Create memory cell help window for bit value -- auxiliary procedure for create_help_window
 # @parm String addr	- hexadecimal representation of the bit address
 # @return void
proc create_help_window_bit {addr} {
	global help_window_bit	;# Array: Canvas rectanges representing bits

	# Create and pack canvas widget where the bits will be shown
	set canvas [canvas ${::HELPWINDOW}.msg.c	\
		-width 150 -height 50 -bg white -bd 0	\
		-relief flat -highlightthickness 0	\
	]
	pack $canvas -pady 2 -padx 3

	# Determinate bit address and bit number in the register
	set bit_addr [expr {"0x$addr"}]
	set reg_addr [${::X::actualProject} getRegOfBit $bit_addr]
	set bit_number [expr {$bit_addr % 8}]
	set bit_addr [expr {$bit_addr - $bit_number + 8}]

	set x0 40

	set y0 0
	set y1 16

	# Create 8 bit rectangles in the canvas
	for {set i 7} {$i >= 0} {incr i -1} {
		incr bit_addr -1

		# Determinate rectangle color
		if {[${::X::actualProject} getBit $bit_addr]} {
			set fill $::BitMap::one_fill
			set outline $::BitMap::one_outline
		} else {
			set fill $::BitMap::zero_fill
			set outline $::BitMap::zero_outline
		}

		# Create label for the bit
		$canvas create text [expr {$x0 + 6}] $y0	\
			-text $i				\
			-anchor n				\
			-font $::Simulator_GUI::smallfont	\
			-fill $::Simulator_GUI::small_color

		# Create bit rectagle
		set help_window_bit($i) [$canvas create	\
			rectangle $x0 $y1		\
			[expr {$x0 + 12}]		\
			[expr {$y1 + 12}]		\
			-fill $fill -outline $outline	\
		]

		# Adjust X position for the next rectagle
		incr x0 12
		incr x0 2
	}

	# Create text with register address
	set help_window_bit(R) [$canvas create text 0 12	\
		-font ${::Simulator_GUI::entry_font}		\
		-anchor w -text "0x[format %X $reg_addr]"	\
	]

	# Create text with bit address
	set help_window_bit(B) [$canvas create text 0 45	\
		-font ${::Simulator_GUI::entry_font}		\
		-anchor w -text "0x$addr"			\
	]

	# Create arrow pointing to the bit
	set arr_pos [expr {47 + ((7 - $bit_number) * 14)}]
	set help_window_bit(A) [$canvas create line	\
		40 45	$arr_pos 45	$arr_pos 29	\
		-arrow last -fill black			\
	]
}

## Create memory cell help window for bit value -- auxiliary procedure for create_help_window
 # @parm String val	- hexadecimal representation of the bit value
 # @parm String addr	- hexadecimal representation of the bit address
 # @return void
proc create_help_window_byte {val} {
	# Normalize cell value
	set len [string length $val]
	if {$len == 0} {
		set val {00}
	} elseif {$len == 1} {
		set val "0$val"
	}

	## Conver hexadecimal cell value to other representations
	 # Octal
	set oct [NumSystem::hex2oct $val]
	 # Decimal
	set dec [NumSystem::hex2dec $val]
	 # Character
	if {$dec > 31 && $dec < 127} {
		set char [subst -nocommands "\\u00$val"]
	} else {
		set char {}
	}
	 # Binary
	set bin [NumSystem::hex2bin $val]
	set bin_len [string length $bin]
	if {$bin_len < 8} {
		set bin "[string repeat {0} [expr {8 - $bin_len}]]$bin"
	}

	## Create table of cell values (GUI)
	# Header "DEC"
	grid [label ${::HELPWINDOW}.msg.dec_l	\
		-text {DEC} 			\
		-font ${::smallfont}		\
		-fg ${::smallfont_color}	\
		-pady 0 -bg {#FFFFFF}		\
		-highlightthickness 0		\
	] -column 1 -row 1
	# Header "HEX"
	grid [label ${::HELPWINDOW}.msg.hex_l	\
		-text {HEX}			\
		-font ${::smallfont}		\
		-fg ${::smallfont_color}	\
		-pady 0 -bg {#FFFFFF}		\
		-highlightthickness 0		\
	] -column 2 -row 1
	# Header "OCT"
	grid [label ${::HELPWINDOW}.msg.oct_l	\
		-text {OCT}			\
		-font ${::smallfont}		\
		-fg ${::smallfont_color}	\
		-pady 0 -bg {#FFFFFF}		\
		-highlightthickness 0		\
	] -column 3 -row 1
	# Values
	grid [label ${::HELPWINDOW}.msg.dec_v -text $dec -pady 0 -bg {#FFFFFF}] -column 1 -row 2	;# Decimal
	grid [label ${::HELPWINDOW}.msg.hex_v -text $val -pady 0 -bg {#FFFFFF}] -column 2 -row 2	;# Hexadecimal
	grid [label ${::HELPWINDOW}.msg.oct_v -text $oct -pady 0 -bg {#FFFFFF}] -column 3 -row 2	;# Octal
	# Header "BIN"
	grid [label ${::HELPWINDOW}.msg.bin_l	\
		-text {BIN}			\
		-font ${::smallfont}		\
		-fg ${::smallfont_color}	\
		-pady 0 -bg {#FFFFFF}		\
		-highlightthickness 0		\
	] -column 1 -row 3
	# Header "CHAR"
	grid [label ${::HELPWINDOW}.msg.char_l	\
		-text {CHAR}			\
		-font ${::smallfont}		\
		-fg ${::smallfont_color}	\
		-pady 0 -bg {#FFFFFF}		\
		-highlightthickness 0		\
	] -column 3 -row 3
	# Values
	grid [label ${::HELPWINDOW}.msg.bin_v -text $bin -pady 0 -bg {#FFFFFF}] -column 1 -row 4 -columnspan 2	;# Binary
	grid [label ${::HELPWINDOW}.msg.char_c -text $char -pady 0 -bg {#FFFFFF}] -column 3 -row 4		;# Character
}

## Set the last created help window as window with variable address
 # That means you can use procedure 'help_window_update_addr'
 # @return void
proc help_window_variable_addr {} {
	global help_window_variable_address ;# Bool: Help window with variable address
	set help_window_variable_address 1
}

## Update address in the help window
 # @parm String old_addr	-  hexadecimal representation of old address
 # @parm String new_addr	-  hexadecimal representation of new address
 # @return Bool - result
proc help_window_update_addr {old_addr new_addr} {
	global help_window_variable_address	;# Bool: Help window with variable address

	# Translate bit address in format ".AA" to "AA BIT"
	if {[string index $old_addr 0] == {.}} {
		set old_addr [string replace $old_addr 0 0]
		append old_addr { BIT}
	}
	if {[string index $new_addr 0] == {.}} {
		set addr [string replace $new_addr 0 0]
		append addr { BIT}
	}

	# Check for address variability flag
	if {!$help_window_variable_address} {return}

	if {[catch {
		# Check for existence of the help window
		if {![winfo exists ${::HELPWINDOW}]} {
			return 0
		}

		# Is the current help window that which should be affected ?
		if {![string equal "0x$old_addr" [${::HELPWINDOW}.top.tit cget -text]]} {
			return 0
		}
	}]} then {
		return 0
	}

	# Change window title
	${::HELPWINDOW}.top.tit configure -text "0x$new_addr"
	return 1
}

## Update values in the help window
 # @parm String addr		- hexadecimal representation of register address
 # @parm String new_value	- hexadecimal representation of the new value
 # @return Bool - result
proc help_window_update {addr new_value} {
	global help_window_for_bit

	# Translate bit address in format ".AA" to "AA BIT"
	if {[string index $addr 0] == {.}} {
		set addr [string replace $addr 0 0]
		append addr { BIT}
	}

	# Handle empty input value
	if {![string is xdigit -strict $new_value]} {
		return 0
	}

	if {[catch {
		# Check for existence of the help window
		if {![winfo exists ${::HELPWINDOW}]} {
			return 0
		}

		# Is the current help window that which should be affected ?
		if {![string equal "0x$addr" [${::HELPWINDOW}.top.tit cget -text]]} {
			return 0
		}
	}]} then {
		return 0
	}

	if {$help_window_for_bit} {
		help_window_update_bit [lindex $addr 0] $new_value
	} else {
		help_window_update_byte $addr $new_value
	}
}

## Update values in the help window for bit -- auxiliary procedure for help_window_update
 # @parm String addr		- hexadecimal representation of bit address
 # @parm String new_value	- hexadecimal representation of the new value
 # @return Bool - result
proc help_window_update_bit {addr new_value} {
	global help_window_bit

	# Adjust bit address to point to the firts bit in the register
	set bit_addr [expr {"0x$addr"}]
	set bit_addr [expr {$bit_addr - ($bit_addr % 8)}]

	# Determinate value for each bit in the register
	for {set i 0} {$i < 8} {incr i} {
		# Determinate color
		if {[${::X::actualProject} getBit $bit_addr]} {
			set fill $::BitMap::one_fill
			set outline $::BitMap::one_outline
		} else {
			set fill $::BitMap::zero_fill
			set outline $::BitMap::zero_outline
		}

		# Set color
		${::HELPWINDOW}.msg.c itemconfigure	\
			$help_window_bit($i) -fill $fill -outline $outline

		# Shift to the next bit
		incr bit_addr
	}
}

## Update values in the help window for byte -- auxiliary procedure for help_window_update
 # @parm String addr		- hexadecimal representation of register address
 # @parm String new_value	- hexadecimal representation of the new value
 # @return Bool - result
proc help_window_update_byte {addr new_value} {
	## Conver hexadecimal cell value to other representations
	 # Octal
	set oct [NumSystem::hex2oct $new_value]
	 # Decimal
	set dec [NumSystem::hex2dec $new_value]
	 # Character
	if {$dec > 31 && $dec < 127} {
		set char [subst -nocommands "\\u00$new_value"]
	} else {
		set char {}
	}
	 # Binary
	set bin [NumSystem::hex2bin $new_value]
	set bin_len [string length $bin]
	if {$bin_len < 8} {
		set bin "[string repeat {0} [expr {8 - $bin_len}]]$bin"
	}

	# Change values in label widgets
	${::HELPWINDOW}.msg.dec_v configure -text $dec
	${::HELPWINDOW}.msg.hex_v configure -text $new_value
	${::HELPWINDOW}.msg.oct_v configure -text $oct
	${::HELPWINDOW}.msg.bin_v configure -text $bin
	${::HELPWINDOW}.msg.char_c configure -text $char

	# Done ...
	return 1
}

## Unmap memory cell help window
 # @return void
proc help_window_hide {} {
	catch {
		place forget ${::HELPWINDOW}
	}
}

## Show memory cell help window
 # @parm Int X - absolute X coordinate
 # @parm Int Y - absolute Y coordinate
 # @return void
proc help_window_show {X Y} {
	global help_window_for_bit

	if {${::HELPWINDOW} == {}} {
		return
	}
	set X [expr $X]
	set Y [expr $Y]

	# Determinate main window geometry
	set geometry [split [wm geometry ${::HELPWINDOW_ROOT}] {+}]
	set limits [split [lindex $geometry 0] {x}]

	# Adjust X and Y
	set x_lim [lindex $limits 0]
	set y_lim [lindex $limits 1]
	set x_coord [expr {$X + 5 - [lindex $geometry 1]}]
	set y_coord [expr {$Y + 5 - [lindex $geometry 2]}]

	# Ensure than help window wont exceed boundaries of the main window
	if {$help_window_for_bit} {
		if {$x_coord > ($x_lim - 160)} {incr x_coord -170}
	} else {
		if {$x_coord > ($x_lim - 100)} {incr x_coord -110}
	}
	if {$y_coord > ($y_lim - 100)} {incr y_coord -110}

	# Show the window
	catch {
		place ${::HELPWINDOW} -anchor w -x $x_coord -y $y_coord
		raise ${::HELPWINDOW}
	}
}


# GENERAL PURPOSE PROCEDURES
# -----------------------------

## Create a new toplevel window with a progress bar within
 # @parm Widget window_path	- Chosen path for the new window
 # @parm Widget transient	- Parent of the window
 # @parm String textvariable	- Variable contaning the message
 # @parm String text		- A string to display as the message in the window
 #				  (meaningful only when no textvariable was specified)
 # @parm Int maximum		- Maximum value for the progress bar
 # @parm String title		- Title on the window
 # @parm Image iconphoto	- Image to display in the window
 #				  (previously created with "image create" command)
 # @parm String abort_text	- Text to display in the abort button (default: "Abort")
 # @parm String abort_command	- Command to invoke when abort button is pressed
 #				  (empty string means do not display abort the button)
 # @return void
proc create_progress_bar {window_path transient textvariable text variable maximum title iconphoto {abort_text {}} {abort_command {}}} {
	# Create a new top level windows
	toplevel $window_path

	# Display the image
	pack [label $window_path.image				\
		-image ::ICONS::32::user_away			\
	] -side left -anchor n -padx 10 -pady 15

	# Create and show a frame where other widgets will be shown in
	pack [frame $window_path.f] -side right -fill both

	# Create widget containing the message
	if {$textvariable != {}} {
		pack [label $window_path.f.label		\
			-textvariable $textvariable		\
		] -anchor w -padx 5 -pady 5
	} else {
		pack [label $window_path.f.label		\
			-text $text				\
		] -anchor w -padx 5 -pady 5
	}

	# Create the progress bar widget
	pack [ttk::progressbar $window_path.f.progressbar	\
		-mode determinate				\
		-length 330					\
		-maximum $maximum				\
		-variable $variable				\
	] -fill x -padx 5 -pady 5

	# Create the abort button
	if {$abort_command != {}} {
		if {$abort_text == {}} {
			set abort_text [mc "Abort"]
		}
		pack [ttk::button $window_path.f.button		\
			-compound left				\
			-image ::ICONS::16::cancel		\
			-text $abort_text			\
			-command $abort_command			\
		] -padx 5 -pady 5 -anchor e
	}

	# Set window parameters
	wm title $window_path $title
	wm transient $window_path $transient
	wm iconphoto $window_path $iconphoto
	wm resizable $window_path 0 0
	update
	catch {
		raise $window_path
	}
}

## Translate encoding name to short description
 # @return String - Encoding description
proc enc2name {enc} {
	switch -- $enc {
		{utf-8}		{return {Unicode}}
		{iso8859-1}	{return {Western European}}
		{iso8859-2}	{return {Central European}}
		{iso8859-3}	{return {Central European}}
		{iso8859-4}	{return {Baltic}}
		{iso8859-5}	{return {Cyrillic}}
		{iso8859-6}	{return {Arabic}}
		{iso8859-7}	{return {Greek}}
		{iso8859-8}	{return {Hebrew}}
		{iso8859-9}	{return {Turkish}}
		{iso8859-10}	{return {Northern European}}
		{iso8859-13}	{return {Baltic}}
		{iso8859-14}	{return {Western European}}
		{iso8859-15}	{return {Western European}}
		{iso8859-16}	{return {South-Eastern Europe}}
		{cp1250}	{return {Central European}}
		{cp1251}	{return {Cyrillic}}
		{cp1252}	{return {Western European}}
		{cp1253}	{return {Greek}}
		{cp1254}	{return {Turkish}}
		{cp1255}	{return {Hebrew}}
		{cp1256}	{return {Arabic}}
		{cp1257}	{return {Baltic}}
		{cp1258}	{return {Vietnamese}}
	}
}

## Create hyperlink tag in the specifid text widget
 # @parm Widget widget - Target
 # @return void
set hyperlink_cur_orig {}
proc create_link_tag_in_text_widget {widget} {
	$widget tag configure hyperlink_normal	-foreground #0055FF -underline 1
	$widget tag configure hyperlink_over	-foreground #0055FF -underline 0

	$widget tag bind hyperlink_normal <Enter> {
		set range [%W tag nextrange hyperlink_normal {@%x,%y linestart}]
		if {$range != {}} {
			set ::hyperlink_cur_orig [%W cget -cursor]
			%W tag remove hyperlink_normal [lindex $range 0] [lindex $range 1]
			%W tag add hyperlink_over [lindex $range 0] [lindex $range 1]
			%W configure -cursor hand2
		}
	}
	$widget tag bind hyperlink_over <Leave> {
		set range [%W tag nextrange hyperlink_over {0.0}]
		if {$range != {}} {
			%W tag remove hyperlink_over [lindex $range 0] [lindex $range 1]
			%W tag add hyperlink_normal [lindex $range 0] [lindex $range 1]
			%W configure -cursor $::hyperlink_cur_orig
		}
	}
	$widget tag bind hyperlink_over <Button-1> {
		set range [%W tag nextrange hyperlink_over {0.0}]
		if {$range != {}} {
			set url [%W get [lindex $range 0] [lindex $range 1]]
			if {[regexp {[\w\.]+@[\w\.]+} $url]} {
				set url "mailto:$url"
			}
			::X::open_uri $url
		}
	}
}

## Automatically convert all strings beginning with "http://" to hypertext tags
 # @parm Widget widget - Target text widget
 # @return void
proc convert_all_https_to_links {widget} {
	foreach re [list {http://[^\s]+} {[\w\-\._]+@[\w\-\._]+}] {
		set idx {1.0}
		set end {1.0}
		set org {1.0}
		set s {}

		while {1} {
			set org $idx
			set idx [$widget search -forwards -regexp -nocase $re $end]

			if {$idx == {} || [$widget compare $org >= $idx]} {
				break
			}

			if {![regexp $re [$widget get $idx [list $idx lineend]] s]} {
				break
			}

			set s [string length $s]
			set end [$widget index [list $idx + $s c]]

			$widget tag add hyperlink_normal $idx $end
		}
	}
}

## Load global configuration
 # @return void
proc loadApplicationConfiguration {} {
	# Load configuration file
	if {$::CLI_OPTION(config_file) == {}} {
		Settings settings ${::CONFIG_DIR} "config.conf"
	} else {
		Settings settings	\
			[file dirname $::CLI_OPTION(config_file)]	\
			[file tail $::CLI_OPTION(config_file)]
	}

	# If configuration file is unavailable -> invoke error message
	if {![settings isReady]} {
		tk_messageBox				\
			-type ok			\
			-icon error			\
			-title [mc "Permission denied"]	\
			-message [mc "Unable to save configuration file"]
	}

	# Reset settings to defaults
	if {$::CLI_OPTION(reset_settings) || [settings isEmpty]} {
		puts [mc "      * Restoring default settings"]
		# Insure that the current configuration is empty
		settings clear

		# Editor configuration
		configDialogues::editor::getSettings
		configDialogues::editor::save_config
		# Right panel settings
		configDialogues::rightPanel::getSettings
		configDialogues::rightPanel::save_config
		# Compiler configuration
		configDialogues::compiler::getSettings
		configDialogues::compiler::save_config
		# Main tool bar
		set ::ICONBAR_CURRENT ${::ICONBAR_DEFAULT}
		configDialogues::toolbar::save_config
		# Custom commands
		configDialogues::custom_commands::save_config
		# Shortcuts
		configDialogues::shortcuts::load_config
		configDialogues::shortcuts::getSettings
		configDialogues::shortcuts::save_config
		# Simulator configuration
		configDialogues::simulator::getSettings
		configDialogues::simulator::save_config
		# Terminal emulator
		if {!$::MICROSOFT_WINDOWS} {	;# There is no terminal emulator on Windows
			configDialogues::terminal::getSettings
			configDialogues::terminal::save_config
		}

	# Load settings
	} else {
		configDialogues::editor::load_config		;# Editor configuration
		configDialogues::rightPanel::load_config		;# Right panel settings
		configDialogues::compiler::load_config		;# Compiler configuration
		configDialogues::toolbar::load_config		;# Main tool bar
		configDialogues::custom_commands::load_config	;# Custom commands
		configDialogues::shortcuts::load_config		;# Shortcuts
		configDialogues::simulator::load_config		;# Simulator
		if {!$::MICROSOFT_WINDOWS} {	;# There is no terminal emulator on Windows
			configDialogues::terminal::load_config	;# Terminal emulator
		}
	}
}

## Neutralize selection in text widgets
 # @parm Widget widget - target widget
 # @return void
proc false_selection {widget} {
	if {${::false_selection_dis}} {return}
	set ::false_selection_dis 1
	catch {$widget tag remove sel 1.0 end}
	set ::false_selection_dis 0
}
set false_selection_dis 0

## Show/Hide tab on some panel
 # @parm String what_to_do - ID of tab to activate
 # @return void
proc manipulate_panel {what_to_do} {
	if {![llength ${::X::openedProjects}] || ${::X::actualProject} == {}} {
		return
	}
	switch -- $what_to_do {
		{sim}	{	;# "Bottom / Simulator"
			${::X::actualProject} bottomNB_show_up Simulator
		}
		{graph}	{	;# "Bottom" / "Graph"
			${::X::actualProject} bottomNB_show_up Graph
		}
		{mess}	{	;# "Bottom / Messages"
			${::X::actualProject} bottomNB_show_up Messages
		}
		{todo}	{	;# "Bottom / Todo"
			${::X::actualProject} bottomNB_show_up Todo
		}
		{calc}	{	;# "Bottom / Calculator"
			${::X::actualProject} bottomNB_show_up Calculator
		}
		{bsh}	{	;# "Bottom / Show_Hide"
			${::X::actualProject} bottomNB_show_hide
		}

		{book}	{	;# "Right / Bookmarks"
			${::X::actualProject} rightPanel_show_up Bookmarks
		}
		{brk}	{	;# "Right / Breakpoints"
			${::X::actualProject} rightPanel_show_up Breakpoints
		}
		{wtch}	{	;# "Right / Watches"
			${::X::actualProject} rightPanel_show_up Watches
		}
		{ins}	{	;# "Right / Instruction details"
			${::X::actualProject} rightPanel_show_up Instruction
		}
		{sub}	{	;# "Right / Subprograms"
			${::X::actualProject} rightPanel_show_up Subprograms
		}
		{rsh}	{	;# "Right / Show_Hide"
			${::X::actualProject} right_panel_show_hide
		}

		{lsh}	{	;# "Left / Show_Hide"
			${::X::actualProject} filelist_show_hide
		}
		{open}	{	;# "Left / Opened files"
			${::X::actualProject} filelist_show_up opened_files
		}
		{proj}	{	;# "Left / Project files"
			${::X::actualProject} filelist_show_up project_files
		}
		{fsb}	{	;# "Left / File system browser"
			${::X::actualProject} filelist_show_up fs_browser
		}
		{sfr}	{	;# "Left / File system browser"
			${::X::actualProject} filelist_show_up sfr_watches
		}
	}
}

##
 # @parm List pattern	- menu definition {
 #	{separator}
 #	{command	label accelerator underline command image [statusTip]}
 #	{radiobutton	label accelerator variable value command underline [statusTip]}
 #	{checkbutton	label accelerator variable onvalue offvalue underline command [statusTip]}
 #	{cascade	label underline image submenuID tearoff shortcuts pattern_list}
 # }
 # @parm String path	- menu root
 # @parm Bool tearoff	- tearoff menu on/off (default: false)
 # @parm String trg_ns = "::"	- Target namespace (for i18n)
 # @return Bool	- return code
proc menuFactory {pattern path tearoff cmdPrefix shortcuts options {trg_ns {::}}} {

	# Create menu widget
	eval "menu $path -tearoff $tearoff $options"

	# Iterate over menu definition list
	foreach menuitem $pattern {
		# Create array of options
		for {set i 0} {$i < 9} {incr i} {
			set menu($i) [lindex $menuitem $i]
		}
		# Determinate kind of operation
		switch $menu(0) {
			{command} {
				# Item icon
				if {$menu(5) != {}} {
					set menu(5) "::ICONS::16::$menu(5)"
				}

				# Do i18n
				set menu(1) [namespace eval $trg_ns "mc {$menu(1)}"]
				set menu(6) [namespace eval $trg_ns "mc {$menu(6)}"]

				# Adjust accelerator value
				set menu(2) [adjust_menu_accelerator $menu(2)]

				# Create menu command
				$path add command			\
					-label $menu(1)			\
					-accelerator $menu(2)		\
					-underline $menu(3)		\
					-command "$cmdPrefix$menu(4)"	\
					-image $menu(5) -compound left

				# Status bar tip
				if {$menu(6) != {}} {
					set itemIndex [$path index end]
					menu_Sbar_add $path $itemIndex $menu(6)
					bind $path <<MenuSelect>> "menu_Sbar $path \[%W index active\]"
					bind $path <Leave> {Sbar {}}
				}
			}
			{separator} {$path add separator}
			{radiobutton} {
				# Adjust command
				if {$menu(5) != {}} {
					set menu(5) "${cmdPrefix}$menu(5)"
				}

				# Do i18n
				set menu(1) [namespace eval $trg_ns "mc {$menu(1)}"]
				set menu(7) [namespace eval $trg_ns "mc {$menu(7)}"]

				# Adjust accelerator value
				set menu(2) [adjust_menu_accelerator $menu(2)]

				# Create radio button item
				$path add radiobutton		\
					-label $menu(1)		\
					-accelerator $menu(2)	\
					-variable $menu(3)	\
					-value $menu(4)		\
					-command $menu(5)	\
					-underline $menu(6)	\
					-compound left		\
					-indicatoron 0		\
					-image ::ICONS::raoff	\
					-selectimage ::ICONS::raon	\
					-selectcolor ${::COMMON_BG_COLOR}

				# Status bar tip
				if {$menu(7) != {}} {
					set itemIndex [$path index end]
					menu_Sbar_add $path $itemIndex $menu(7)
					bind $path <<MenuSelect>> "menu_Sbar $path \[%W index active\]"
					bind $path <Leave> {Sbar {}}
				}
			}
			{checkbutton} {
				# Adjust command
				if {$menu(7) != {}} {
					set menu(7) "${cmdPrefix}$menu(7)"
				}

				# Do i18n
				set menu(1) [namespace eval $trg_ns "mc {$menu(1)}"]
				set menu(8) [namespace eval $trg_ns "mc {$menu(8)}"]

				# Adjust accelerator value
				set menu(2) [adjust_menu_accelerator $menu(2)]

				# Create checkbutton item
				$path add checkbutton		\
					-label $menu(1)		\
					-accelerator $menu(2)	\
					-variable $menu(3)	\
					-onvalue $menu(4)	\
					-offvalue $menu(5)	\
					-underline $menu(6)	\
					-command $menu(7)	\
					-compound left		\
					-image ::ICONS::choff	\
					-indicatoron 0		\
					-selectimage ::ICONS::chon	\
					-selectcolor ${::COMMON_BG_COLOR}
				# Status bar tip
				if {$menu(8) != {}} {
					set itemIndex [$path index end]
					menu_Sbar_add $path $itemIndex $menu(8)
					bind $path <<MenuSelect>> "menu_Sbar $path \[%W index active\]"
					bind $path <Leave> {Sbar {}}
				}
			}
			{cascade} {
				# Adjust menu name
				set menu(4) "$path$menu(4)"
				# Create new menu for cascade
				if {$menu(7) != {}} {
					menuFactory $menu(7) $menu(4) $menu(5) $cmdPrefix $menu(6) $options $trg_ns
				}
				# Do i18n
				set menu(1) [namespace eval $trg_ns "mc {$menu(1)}"]
				# Item icon
				if {$menu(3) != {}} {
					set menu(3) "::ICONS::16::$menu(3)"
				}
				# Add cascade to this menu
				$path add cascade -label $menu(1) -underline $menu(2) \
					-image $menu(3) -menu $menu(4) -compound left
			}
			{} {return}
			default {
				error "Menu creation failed -- unknown type: $menu(0)"
				return -code 1
			}
		}
	}
}

## Disable or enable particular buttons in main menu
 # @parm Bool EnaDis  - 1: enable; 0: disable
 # @parm List pattern - list of entries to affect, format:
 #	{
 #		{?path?
 #			{?Label_or_index? ...}
 #		}
 #	}
 # @parm void
proc ena_dis_menu_buttons {EnaDis pattern} {
	# Determinate state
	if {$EnaDis} {
		set state normal
	} else {
		set state disabled
	}
	# Set state
	foreach option $pattern {
		set path [lindex $option 0]
		foreach entry [lindex $option 1] {
			$path entryconfigure [::mc $entry] -state $state
		}
	}
}

## Enable or disable buttons on iconbar
 # @parm Bool EnaDis		- 1 == enable; 0 == disable
 # @parm Widget pathPrefix	- path prefix for buttons
 # @parm List buttonList	- list of buttons to affect
 # @return void
proc ena_dis_iconBar_buttons {EnaDis pathPrefix buttonList} {
	# Determinate state
	if {$EnaDis} {
		set state normal
	} else {
		set state disabled
	}
	# Set state
	foreach button $buttonList {
		catch {
			$pathPrefix$button configure -state $state
		}
	}
}

## Create icon bar
 # @parm String container	- target container (some frame)
 # @parm String pathPrefix	- path prefix for buttons
 # @parm String imageNS		- namespace where the images references are located (eg. ::img::large::)
 # @parm List pattern 		- icon bar pattern -- must look like this: {
 #	{?name? ?helptext? ?imageName? ?command? [?statusTip?]}
 #	{separator}
 # }
 # @parm String trg_ns = "::"	- Target namespace (for i18n)
 # @return void
set iconBarFactory_sep_index 0	;# Separator index
proc iconBarFactory {container cmdPrefix pathPrefix imageNS pattern {trg_ns {::}}} {
	global iconBarFactory_sep_index	;# Separator index

	# Parse pattern
	foreach button $pattern {
		# Create array of button parameters
		for {set i 0} {$i < 4} {incr i} {
			set parm($i) [lindex $button $i]
		}

		# Separator
		if {$parm(0) == {separator}} {
			pack [ttk::separator						\
				.${pathPrefix}iconBarSeparator$iconBarFactory_sep_index	\
				-orient vertical					\
			] -in $container -side left -padx 2 -fill y -expand 1
			incr iconBarFactory_sep_index

		# Button
		} else {
			# Create button
			set buttonWidget [ttk::button .$pathPrefix$parm(0)	\
				-command "$cmdPrefix$parm(3)"			\
				-image "$imageNS$parm(2)"			\
				-style ToolButton.TButton			\
			]
			::DynamicHelp::add $buttonWidget -text [namespace eval $trg_ns "mc {[lindex $button 1]}"]
			# Pack it
			pack $buttonWidget -in $container -side left -padx 2
			# Set status bar tip
			if {[llength $button] == 5} {
				setStatusTip -widget $buttonWidget -text [namespace eval $trg_ns "mc {[lindex $button 4]}"]
			}
		}
	}
}

## Show statusbar history
 # @return void
proc show_statusbar_history {} {
	global status_bar_history	;# Sbar history

	if {[winfo exists .status_bar_history_win]} {
		grab release .status_bar_history_win
		destroy .status_bar_history_win
		return
	}

	set win [frame .status_bar_history_win	\
		-background {#000000} 		\
	]
	set main_frame [frame $win.main_frame]

	pack [text $main_frame.text				\
		-yscrollcommand "$main_frame.scrollbar set"	\
		-bg white -cursor left_ptr			\
		-width 0 -height 0 -bd 0			\
	] -side left -fill both -expand 1
	pack [ttk::scrollbar $main_frame.scrollbar	\
		-command "$main_frame.text yview"	\
		-orient vertical			\
	] -side right -fill y -after $main_frame.text
	foreach line $status_bar_history {
		$main_frame.text insert end $line
		$main_frame.text insert end "\n"
	}
	$main_frame.text configure -state disabled

	pack $main_frame -fill both -expand 1 -padx 1 -pady 1
	place $win						\
		-x [winfo rootx .statusbarL]			\
		-y [expr {[winfo rooty .statusbarL] - 250}]	\
		-width [expr {[winfo width .statusbarL] - 20}]	\
		-height 200
	bind $win <Button> "
		grab release .status_bar_history_win
		destroy .status_bar_history_win
	"
	update
	grab -global $win
	focus $win
}

## Create status bar
 # @parm String txt - initial text
 # @return void
proc makeStatusbar {txt} {
	# Button "Set syntax validation level"
	pack [frame .statusbarF -height 30p] -fill x -expand 0 -side bottom
	pack [ttk::button .statusbarVB		\
		-style TButton			\
		-image ::ICONS::16::spellcheck	\
		-compound left			\
		-width 6			\
	] -in .statusbarF -side left
	DynamicHelp::add .statusbarVB -text [mc "Change level of syntax validation."]
	bind .statusbarVB <Button-3> {change_validation_level {down}; break}
	bind .statusbarVB <Button-1> {change_validation_level {up}; break}

	# This function was not yet ported to MS Windows
	if {!$::MICROSOFT_WINDOWS} {
		# Button "Configure spell checking"
		pack [ttk::menubutton .statusbarSB	\
			-style TButton			\
			-compound left			\
			-width 6			\
			-direction above		\
			-menu .spell_checker_conf_menu	\
			-image ::ICONS::flag::empty	\
			-text "none"			\
		] -in .statusbarF -side left
		if {${::PROGRAM_AVAILABLE(hunspell)}} {
			DynamicHelp::add .statusbarSB -text [mc "Configure spell checker"]
		} else {
			DynamicHelp::add .statusbarSB -text [mc "Spell checker (hunspell) is not available."]
			.statusbarSB configure -state disabled
		}
	}

	# Button "Show status bar history"
	pack [ArrowButton .statusbarF.arr_but			\
		-dir top -clean 2 -bd 0				\
		-helptext [mc "Show status bar history"]	\
		-command {show_statusbar_history}		\
		-height 14 -width 14 -bg ${::COMMON_BG_COLOR}	\
	] -side left -padx 7
	setStatusTip -widget .statusbarF.arr_but -text [mc "Show status bar history"]

	# Status bar
	pack [label .statusbarL -text $txt -anchor w -justify left] \
		-in .statusbarF -side left -fill x -expand 1
	# MCU currently in use
	pack [label .statusbarMCU -text "" -cursor hand2 -anchor e -justify right -fg {#000000}] \
		-in .statusbarF -side right -padx 5
	DynamicHelp::add .statusbarMCU -text [mc "MCU chosen for simulation"]
	bind .statusbarMCU <Enter> {%W configure -fg {#0000DD}}
	bind .statusbarMCU <Leave> {%W configure -fg {#000000}}
	bind .statusbarMCU <Button-1> {::X::__proj_edit 1}
}
set sbarAfterId {}		;# Sbar timer ID
set status_bar_history {}	;# Sbar history

## Change current validation lvel
 # @parm String arg - on of {up down 0 1 2}
 #	0 	: Validation disabled
 #	1 	: Basic validation enabled
 #	2 	: Basic and advanced validtions enabled
 #	up 	: Move to upper validation level (for instance form 0 to 1)
 #	down	: Move to lower validation level (for instance form 1 to 0)
 # @return void
proc change_validation_level {arg} {

	# Parse parameter
	if {$arg == {up}} {
		if {$::CONFIG(VALIDATION_LEVEL) == 2} {return}
		incr ::CONFIG(VALIDATION_LEVEL)

	} elseif {$arg == {down}} {
		if {!$::CONFIG(VALIDATION_LEVEL)} {return}
		incr ::CONFIG(VALIDATION_LEVEL) -1

	} elseif {$arg == 0 || $arg == 1 || $arg == 2} {
		set ::CONFIG(VALIDATION_LEVEL) $arg

	} else {
		puts stderr "Invalid call 'change_validation_level {$arg}'"
		return
	}

	## Change content of button "Validation level" and SH-NS variables validation_L0 and validation_L1
	if {!$::CONFIG(VALIDATION_LEVEL)} {
		.statusbarVB configure -text {OFF}
		.statusbarVB configure -style RedBg.TButton
		setStatusTip -widget .statusbarVB -text [mc "Syntax validation disabled"]
		if {$arg == {up} || $arg == {down}} {
			Sbar -freeze  [mc "Syntax validation disabled"]
		}

		set ::CsyntaxHighlight::validation_L0	0	;# Bool: Basic validation enabled
		set ::CsyntaxHighlight::validation_L1	0	;# Bool: Basic validation enabled
		set ::ASMsyntaxHighlight::validation_L0	0	;# Bool: Basic validation enabled
		set ::ASMsyntaxHighlight::validation_L1	0	;# Bool: Advancet validation enabled
	} else {
		.statusbarVB configure -text "   $::CONFIG(VALIDATION_LEVEL)"
		.statusbarVB configure -style TButton
		setStatusTip -widget .statusbarVB -text [mc "Current validation level: %s" $::CONFIG(VALIDATION_LEVEL)]
		if {$arg == {up} || $arg == {down}} {
			Sbar -freeze [mc "Current validation level: %s" $::CONFIG(VALIDATION_LEVEL)]
		}

		set ::CsyntaxHighlight::validation_L0	1	;# Bool: Basic validation enabled
		set ::ASMsyntaxHighlight::validation_L0	1	;# Bool: Basic validation enabled
		if {$::CONFIG(VALIDATION_LEVEL) == 2} {
			set ::ASMsyntaxHighlight::validation_L1	1	;# Bool: Advancet validation enabled
			set ::CsyntaxHighlight::validation_L1	1	;# Bool: Basic validation enabled
		} else {
			set ::ASMsyntaxHighlight::validation_L1	0	;# Bool: Advancet validation enabled
			set ::CsyntaxHighlight::validation_L1	0	;# Bool: Basic validation enabled
		}
	}
}

## Show message on status bar
 # @parm String arg0	- '-freeze' (OPTIONAL) - do not set timer to clear the message
 # @parm String arg1	- text of message to display
 # @return void
proc Sbar args {
	global sbarAfterId		;# ID of Sbar timer
	global status_bar_history	;# Sbar history

	# Local variables
	set freeze	0		;# Freeze timer
	set argsLength	[llength $args]	;# Number of arguments

	# Check for allowed number of arguments
	if {$argsLength > 2} {
		error "Too many arguments."

	} elseif {$argsLength == 0} {
		error "Too few arguments"

	}

	# Handle optional argument '-freeze'
	set idx [lsearch $args "-freeze"]
	if {$idx != -1} {
		if {$argsLength == 1} {
			error "Expected text"
		}
		set freeze 1
		set args [lreplace $args $idx $idx]

	} elseif {$argsLength == 2} {
		error "Invalid argument set"

	}

	# Show message text
	set text [string trim $args {\{\}}]
	.statusbarL configure -text $text
	# Cancel previous timer
	if {$sbarAfterId != {}} {
		after cancel $sbarAfterId
	}
	# Set new timer
	if {!$freeze} {
		set sbarAfterId [after 5000 {.statusbarL configure -text {}}]
		if {$text != {}} {
			lappend status_bar_history $text
			if {[llength $status_bar_history] > 25} {
				set status_bar_history [lrange $status_bar_history end-25 end]
			}
		}
	}
}

## Show message on status bar for simulator
 # @parm String txt	- Text of the message
 # @parm Int mode	- Message type
 #	0 - Normal message
 #	1 - Interrupt
 # @return void
proc simulator_Sbar {txt mode object} {
	catch {destroy .simulator_Sbar}
	if {![string length $txt]} {
		return
	}
	pack [label .simulator_Sbar -text $txt -fg {#DD8800} -cursor hand2] -in .statusbarF -side right
	if {$mode} {
		bind .simulator_Sbar <Enter> {%W configure -fg {#0000DD}}
		bind .simulator_Sbar <Leave> {%W configure -fg {#DD8800}}
	}
	set command {}
	switch -- $mode {
		0 { ;# Normal message
		}
		1 { ;# Interrupt
			set command "::X::__interrupt_monitor $object"
		}
	}
	bind .simulator_Sbar <Button-1> $command
}

# Variables related to status tips for notebook tabs
set notebookSbar_IDs		{}	;# List of registered NoteBooks (not widgets)
array set notebookSbar_texts	{}	;# Array of Lists of status tip texts ({tab_ID text tab_ID text ...})

## Register NoteBook for dynamic help on statusbar
 # @parm String notebook_ID	- Any string which identifies the NoteBook
 # @parm List status_tips	- List of helptexts (format: {tab_ID text tab_ID text ...})
 # @return void
proc notebook_Sbar_set {notebook_ID status_tips} {
	if {[lsearch $::notebookSbar_IDs $notebook_ID] != -1} {return}
	lappend ::notebookSbar_IDs $notebook_ID
	set ::notebookSbar_texts($notebook_ID) $status_tips
}

## Unregister NoteBook for dynamic help on statusbar
 # @parm String notebook_ID	- Any string which identifies the NoteBook
 #				  (must be the same as used in notebook_Sbar_set)
 # @return void
proc notebook_Sbar_unset {notebook_ID} {
	set idx [lsearch $::notebookSbar_IDs $notebook_ID]
	if {$idx == -1} {return}
	set ::notebookSbar_IDs [lreplace $::notebookSbar_IDs $idx $idx]
	unset ::notebookSbar_texts($notebook_ID)
}

## Display dinamic help for NoteBook tab
 # @parm String notebook_ID	- Any string which identifies the NoteBook
 #				  (must be the same as used in notebook_Sbar_set)
 # @parm String tab_ID		- Tab identifier (NB insert index tab_ID option ...)
 # @return void
proc notebook_Sbar {notebook_ID tab_ID} {
	# Check for notebook regisration
	set idx [lsearch $::notebookSbar_IDs $notebook_ID]
	if {$idx == -1} {
		Sbar {}
		return
	}

	# Check for tab registration
	set idx [lsearch $::notebookSbar_texts($notebook_ID) $tab_ID]
	if {$idx == -1} {
		Sbar {}
		return
	}

	# Display the text
	Sbar -freeze [lindex $::notebookSbar_texts($notebook_ID) [expr {$idx + 1}]]
}

# Variables realted to status bar tips for menus
set menuSbar_menus		{}	;# List of menus with registred status bar tips
array set menuSbar_items	{}	;# Registered menu items (menuSbar_items($menu_widget) == {item item ...})
array set menuSbar_texts	{}	;# Status tips (menuSbar_texts($menu_widget,$item) == text)

## Set status bar tip for menu item
 # @parm Widget menu	- ID of the menu
 # @parm Int item	- Index of the item
 # @parm String text	- Help text
 # @return void
proc menu_Sbar_add {menu item text} {
	# Register menu ID
	if {[lsearch ${::menuSbar_menus} $menu] == -1} {
		lappend ::menuSbar_menus $menu
		set ::menuSbar_items($menu) {}
	}
	# Register menu item index
	lappend ::menuSbar_items($menu) $item
	# Set help text
	set ::menuSbar_texts(${menu},${item}) $text
}

## Unset status bar tip for menu item
 # @parm Widget menu - ID of the menu
 # @return void
proc menu_Sbar_remove {menu} {
	if {$menu == {}} {
		return
	}
	# Determinate menu index
	set idx [lsearch ${::menuSbar_menus} $menu]
	if {$idx == -1} {
		puts stderr "Unable to remove menu $menu from help db, menu does not exist"
	}
	# Discart help
	set ::menuSbar_menus [lreplace ${::menuSbar_menus} $idx $idx]
	catch {
		foreach item $::menuSbar_items($menu) {
			unset ::menuSbar_texts(${menu},${item})
		}
	}
	catch {
		unset ::menuSbar_items($menu)
	}
}

## Show help text (on status bar) related to menu given item
 # @parm Widget		- Menu ID
 # @parm Int item	- Menu item index
 # @return void
proc menu_Sbar {menu item} {
	if {[lsearch ${::menuSbar_menus} $menu] == -1} {
		return
	}
	if {[lsearch $::menuSbar_items($menu) $item] != -1} {
		Sbar -freeze $::menuSbar_texts(${menu},${item})
	} else {
		Sbar {}
	}
}

# Advanced geometry management variables
set ::last_WIN_GEOMETRY_width	0	;# Last width of the main window
set ::last_WIN_GEOMETRY_height	0	;# Last height of the main window

## Refersh variables last_WIN_GEOMETRY_width and last_WIN_GEOMETRY_height
 # @return void
proc evaluate_new_window_geometry {} {
	set geometry [split [wm geometry .] {+}]
	set geometry [split [lindex $geometry 0] {x}]
	set ::WIN_GEOMETRY_width	[lindex $geometry 0]
	set ::WIN_GEOMETRY_height	[lindex $geometry 1]
}

# KEY SHORTCUTS
# -----------------------------

## Database of current key shortcuts
 # Usage: $SHORTCUTS_DB(category:item) == key_sequence
array set SHORTCUTS_DB {}

## Shortcuts definition list
 # Format: {
 #	{category_ID	category_name	hardcoded_shortcuts
 #		{item_ID}	{key_sequence	command		icon	item_name}
 #		...
 #	}
 #	...
 # }
set SHORTCUTS_LIST {
	{main		{Main}			{}
		{quit}		{Control-Key-q	::X::__exit			exit
			{Exit program}}
		{savesession}	{{}		::X::save_session		{}
			{Save session}}
		{statistics}	{{}		::X::__statistics		{}
			{File statistics}}
		{fullscreen}	{{Control-Key-XF86_Switch_VT_11} ::X::__toggle_fullscreen window_fullscreen
			{Toggle full screen mode}}
	} {project	{Project management}	{}
		{proj_new}	{{}		::X::__proj_new			filenew
			{New project}}
		{proj_open}	{{}		::X::__proj_open		project_open
			{Open project}}
		{proj_save}	{{}		::X::__proj_save		filesave
			{Save project}}
		{proj_edit}	{{}		::X::__proj_edit		configure
			{Edit project}}
		{proj_close}	{{}		::X::__proj_close		fileclose
			{Save and close project}}
		{proj_clsimm}	{{}		::X::__proj_close_imm		no
			{Close project}}
	} {sim		{Simulator}		{}
		{initiate_sim}	{{Key-F2}	::X::__initiate_sim		launch
			{Start simulator}}
		{initiate_sim0}	{{}		{::X::__initiate_sim 1}		launch_this
			{Debug this file only}}
		{sfrmap}	{{}		::X::__sfr_map			kcmmemory_S
			{Show SFR map}}
		{bitmap}	{{}		::X::__bitmap			kcmmemory_BA
			{Bit addressable array}}
		{show_code_mem}	{{}		::X::__show_code_mem		kcmmemory_C
			{Show Code memory}}
		{show_ext_mem}	{{}		::X::__show_ext_mem		kcmmemory_E
			{Show XDATA memory}}
		{show_exp_mem}	{{}		::X::__show_exp_mem		kcmmemory_E
			{Show ERAM }}
		{show_eeprom}	{{}		::X::__show_eeprom		kcmmemory_P
			{Show Data EEPROM}}
		{show_eem_wb}	{{}		::X::__show_eeprom_write_buffer	kcmmemory_B
			{Show EEPROM write buffer}}
		{stack_mon}	{{}		::X::__stack_monitor		kcmmemory_ST
			{Invoke MCU stack monitor}}
		{reset-}	{{Key-F4}	{::X::__reset -}		rebuild
			{Reset - Only SFR}}
		{reset0}	{{}		{::X::__reset 0}		rebuild
			{Reset - All zeros}}
		{reset1}	{{}		{::X::__reset 1}		rebuild
			{Reset - All ones}}
		{resetr}	{{}		{::X::__reset r}		rebuild
			{Reset - Random}}
		{step}		{{Key-F7}	::X::__step			goto
			{Simulator: Step}}
		{stepback}	{{Alt-Key-F7}	::X::__stepback			undo
			{Simulator: Step Back}}
		{stepover}	{{Key-F8}	::X::__stepover			goto
			{Simulator: Step over}}
		{animate}	{{Key-F6}	::X::__animate			1rightarrow
			{Simulator: Animate}}
		{run}		{{Key-F9}	::X::__run			2rightarrow
			{Simulator: Run}}
		{allow_BP}	{{}		::X::__invert_allow_breakpoints	{}
			{Allow/Deny breakpoints}}
		{clear_hg}	{{}		::X::__sim_clear_highlight	editclear
			{Clear highlight}}
		{find_cur}	{{Key-F3}	::X::__see_sim_cursor		forward
			{Find cursor}}
		{line2addr}	{{Control-g}	::X::__simulator_set_PC_by_line	2_rightarrow
			{Jump to line}}
		{hiberante}	{{}		::X::__hibernate		bar5
			{Simulator: Hibernate}}
		{resume}	{{}		::X::__resume			resume
			{Simulator: Resume}}
		{intrmon}	{{}		::X::__interrupt_monitor	kcmdf
			{Interrupt Monitor}}
		{uartmon}	{{}		::X::__uart_monitor		__blockdevice
			{UART Monitor}}
		{stopwatch}	{{}		::X::__stopwatch_timer		player_time
			{Stopwatch}}
	} {virtual_hw	{Virtual HW}		{}
		{ledpanel}	{{}		{::X::__vhw_LED_panel}		ledpanel
			{LED Panel}}
		{leddisplay}	{{}		{::X::__vhw_LED_display}	leddisplay
			{LED Display}}
		{ledmatrix}	{{}		{::X::__vhw_LED_matrix}		ledmatrix
			{LED Matrix}}
		{hd44780}	{{}		{::X::__vhw_HD44780}		hd44780
			{LCD display controlled by HD44780}}
		{mleddisplay}	{{}		{::X::__vhw_M_LED_display}	mleddisplay
			{Multiplexed LED display}}
		{simplekeypad}	{{}		{::X::__vhw_keys}		simplekeypad
			{Simple Keypad}}
		{matrixkeypad}	{{}		{::X::__vhw_matrix_keypad}	matrixkeypad
			{Matrix Keypad}}
		{ds1620}	{{}		{::X::__ds1620}			ds1620
			{DS1620 thermometer}}
		{fintr}	{{}			{::X::__vhw_file_interface}	compfile1
			{File Interface}}
		{vhw_open}	{{}		{::X::__open_VHW}		fileopen
			{Open}}
		{vhw_load}	{{}		{::X::__load_VHW}		fileimport
			{Load}}
		{vhw_save}	{{}		{::X::__save_VHW}		filesave
			{Save}}
		{vhw_saveas}	{{}		{::X::__save_as_VHW}		filesaveas
			{Save as}}
		{vhw_remove_all} {{}		{::X::__remove_all_VHW}		editdelete
			{Remove all}}
	} {tools	{Tools}			{}
		{assemble}	{{Key-F11}	{::X::__compile 0}		compfile
			{Compile}}
		{assemble0}	{{}		{::X::__compile 0 {} 1}		compfile_this
			{Compile this file only}}
		{disasm}	{{}		::X::__disasm			disasm
			{Disassemble}}
		{d52}	{{}			::X::__d52			d52
			{Disassemble with D52}}
		{auto_indent}	{{}		::X::__reformat_code		filter
			{Auto indent}}
		{change_case}	{{}		::X::__change_letter_case	change_case
			{Change letter case}}
		{cleanup}	{{}		::X::__cleanup			emptytrash
			{Cleanup dialog}}
		{toHTML}	{{}		::X::__toHTML			html
			{Export as XHTML}}
		{toLaTeX}	{{}		::X::__toLaTeX			tex
			{Export as LaTeX}}
		{doc_cur_f}	{{Control-e}	::X::__document_current_func	{}
			{Document current function}}
		{doxywizard}	{{}		::X::__run_doxywizard		{}
			{Run doxywizard}}
		{doxygen}	{{}		::X::__generate_documentation	{}
			{Build C API documentation}}
		{clr_doc}	{{}		::X::__clear_documentation	{}
			{Clear C API documentation}}
		{custom0}	{{}		{::X::__exec_custom_cmd 0}	gear0
			{Custom command 0}}
		{custom1}	{{}		{::X::__exec_custom_cmd 1}	gear1
			{Custom command 1}}
		{custom2}	{{}		{::X::__exec_custom_cmd 2}	gear2
			{Custom command 2}}
	} {utilities	{Utilities}		{}
		{hex2bin}	{{}		::X::__hex2bin			hb
			{Hex -> Bin}}
		{bin2hex}	{{}		::X::__bin2hex			bh
			{Bin -> Hex}}
		{sim2hex}	{{}		::X::__sim2hex			sh
			{Sim -> Hex}}
		{sim2bin}	{{}		::X::__sim2bin			sb
			{Sim -> Bin}}
		{normalize_hex}	{{}		::X::__normalize_hex		hh
			{Normalize IHEX8}}
		{hexeditor}	{{}		::X::__hexeditor		ascii
			{Hex Editor}}
		{symb_view}	{{}		::X::__symb_view		symbol
			{Symbol Table}}
		{8seg}	{{}			::X::__eightsegment		8seg
			{8-Segment Editor}}
		{ascii_c}	{{}		::X::__ascii_chart		math_matrix
			{ASCII Chart}}
		{toi}		{{}		::X::__table_of_instructions	fsview
			{8051 Instruction Table}}
		{notes}		{{}		::X::__notes			pencil
			{Scribble Notepad}}
		{bc}		{{}		::X::__base_converter		kaboodleloop
			{Base Converter}}
		{rs232}		{{}		::X::__rs232debugger		chardevice
			{UART/RS232 Debugger}}
	} {help		{Help}			{}
		{about}		{{}		::X::__about			mcu8051ide
			{About dialog}}
		{welcome}	{{}		::X::__welcome_dialog		info
			{Welcome Dialog}}
		{tips}		{{}		::X::__tip_of_the_day		help
			{Tip of the Day}}
		{hbook}		{{Key-F1}	::X::__handbook			contents
			{Handbook}}
	} {messages	{Messages text}		{Control-Key-c Control-Key-a}
		{clear_mess}	{{}		{$this clear_messages_text}	editdelete
			{Clear messages}}
		{mess_find}	{Control-Key-f	{$this messages_text_find_dialog} find
			{Find}}
		{mess_find_n}	{Key-F3		{$this messages_text_find_next}	down0
			{Find next}}
		{mess_find_p}	{XF86_Switch_VT_3 {$this messages_text_find_prev} up0
			{Find previous}}
	} {todo		{Notes}		{
			Control-Key-v Control-Key-x Control-Key-c
			Control-Key-a Control-Key-z Control-Key-Z
		}
		{bold}		{Control-Key-b	{$this TodoProc_bold}		text_bold
			{Bold text}}
		{italic}	{Control-Key-i	{$this TodoProc_italic}		text_italic
			{Italic text}}
		{strike}	{Control-Key-q	{$this TodoProc_strike}		text_strike
			{Strikethrough text}}
		{under}		{Control-Key-u	{$this TodoProc_under}		text_under
			{Underline text}}
		{edrase}	{Control-Key-e	{$this TodoProc_eraser}		eraser
			{Erase tags}}
		{insert}	{Control-Key-p	{$this TodoProc_bookmark}	ok
			{Insert OK image}}
		{todo_find}	{Control-Key-f	{$this TodoProc_find_dialog}	find
			{Find}}
		{todo_find_n}	{Key-F3		{$this TodoProc_find_next}	down0
			{Find next}}
		{todo_find_p}	{XF86_Switch_VT_3 {$this TodoProc_find_prev}	up0
			{Find previous}}
	} {watches	{Register watches}	{
			Control-Key-v Control-Key-x Control-Key-c Control-Key-a
		}
		{top}		{{}		{$this rightPanel_watch_move_top}	top
			{Move to top}}
		{up}		{{Alt-Key-Up}	{$this rightPanel_watch_move_up}	1uparrow
			{Move up}}
		{down}		{{Alt-Key-Down}	{$this rightPanel_watch_move_down}	1downarrow
			{Move down}}
		{bottom}	{{}		{$this rightPanel_watch_move_bottom}	bottom
			{Move to bottom}}
		{remove}	{{Control-Delete} {$this rightPanel_watch_remove}	button_cancel
			{Remove}}
		{remove_all}	{{}		{$this rightPanel_watch_clear}		editdelete
			{Remove all}}
	} {edit		{Editor}		{
			Control-Key-Next	Control-Key-Prior	Control-Shift-Key-Right
			Control-Key-Right	Control-Key-Left	Control-Shift-Key-Left
			Control-Key-Down	Control-Key-Up}
		{readonly}	{{}		::X::switch_editor_RO_MODE	{}
			{Read only mode}}
		{new}		{Control-Key-n	::X::__new			filenew
			{New}}
		{open}		{Control-Key-o	::X::__open			fileopen
			{Open}}
		{save}		{Control-Key-s	::X::__save			filesave
			{Save}}
		{save_as}	{Control-Key-S	::X::__save_as			filesaveas
			{Save as}}
		{save_all}	{Control-Key-l	::X::__save_all			save_all
			{Save all}}
		{close}		{Control-Key-w	::X::__close			fileclose
			{Close}}
		{close_all}	{{}		::X::__close_all		cancel
			{Close all}}
		{icon_border}	{{}		::X::__show_hine_IconB		view_choose
			{Show/Hide icon border}}
		{line_numbers}	{{}		::X::__show_hine_LineN		view_choose
			{Show/Hide line numbers}}
		{reload}	{Key-F5		::X::__reload			reload
			{Reload}}
		{next}		{Alt-Key-Right	::X::__next_editor		1rightarrow
			{Next editor}}
		{prev}		{Alt-Key-Left	::X::__prev_editor		1leftarrow
			{Previous editor}}
		{breakpoint}	{Control-Key-B	{$this Breakpoint}		flag
			{Breakpoint}}
		{bookmark}	{Control-Key-b	{$this Bookmark}		bookmark
			{Bookmark}}
		{undo}		{Control-Key-z	::X::__undo			undo
			{Undo}}
		{redo}		{Control-Key-Z	::X::__redo			redo
			{Redo}}
		{copy}		{Control-Key-c	::X::__copy			editcopy
			{Copy}}
		{cut}		{Control-Key-x	::X::__cut			editcut
			{Cut}}
		{paste}		{Control-Key-v	::X::__paste			editpaste
			{Paste}}
		{select_all}	{Control-Key-a	::X::__select_all		{}
			{Select all}}
		{find}		{Control-Key-f	::X::__find			find
			{Find}}
		{find_next}	{Key-F3		::X::__find_next		1downarrow
			{Find next}}
		{find_prev}	{XF86_Switch_VT_3 ::X::__find_prev		1uparrow
			{Find previous}}
		{replace}	{Control-Key-r	::X::__replace			{}
			{Replace}}
		{goto}		{Control-Key-g	::X::__goto			goto
			{Go to line}}
		{comment}	{Control-Key-d	::X::__comment			{}
			{Comment}}
		{uncomment}	{Control-Key-D	::X::__uncomment		{}
			{Uncomment}}
		{indent}	{Control-Key-i	::X::__indent			indent
			{Indent}}
		{unindent}	{Control-Key-I	::X::__unindent			unindent
			{Unindent}}
		{uppercase}	{Control-Key-u	{$this uppercase}		up0
			{Uppercase}}
		{lowercase}	{Control-Key-U	{$this lowercase}		down0
			{Lowercase}}
		{capitalize}	{Control-Alt-u	{$this capitalize}		{}
			{Capitalize}}
		{next_bookmark}	{Alt-Key-Next	{$this goto_next_bookmark}	{}
			{Go to next bookmark}}
		{prev_bookmark}	{Alt-Key-Prior	{$this goto_prev_bookmark}	{}
			{Go to previous bookmark}}
		{jmp}		{{}		{$this ljmp_this_line}		{exec}
			{Program jump}}
		{call}		{{}		{$this lcall_this_line}	{exec}
			{Call subprogram}}
		{cmd_line}	{Key-F10	{}				{}
			{Editor command line}}
		{split_v}	{Control-L	::X::__split_vertical		view_left_right
			{Split vertical}}
		{split_h}	{Control-T	::X::__split_horizontal		view_top_bottom
			{Split horizontal}}
		{close_cv}	{Control-R	::X::__close_current_view	view_remove
			{Close current view}}
		{block_sel}	{Control-Alt-b	::X::__block_selection_mode	{}
			{Block selection mode}}
	}
}
# Intentionally hidden functions, these haven't been fully implemented yet
# virtual_hw:	{vuterm}	{{}		{::X::__vhw_UART_terminal}	_chardevice
# 			{Virtual UART termnal}}

## Traslate menu accelerator string to human readable key sequence
 # @parm String value - string to translate (for instance: $main:quit)
 # @return String - resulting key sequence or empty string
proc adjust_menu_accelerator {value} {
	# Check if input value is variable
	if {[string index $value 0] != {$}} {
		return $value
	}

	# Adjust input value and search shortcuts database
	set value [string replace $value 0 0]
	if {![llength [array names ::SHORTCUTS_DB -exact $value]]} {
		return {}
	}

	# Get new value from shortcuts database
	set value $::SHORTCUTS_DB($value)
	if {$value == {}} {
		return {}
	}

	# Convert value to human readable string
	return [simplify_key_seq $value]
}

## Translate Tk key sequence string to something like human readable string
 # @parm String value - string to translate
 # @return String - result
proc simplify_key_seq {value} {
	if {$value == {}} {
		return {}
	}

	# Adjust the given string
	set lastchar [string index $value end]
	if {[string index $value end-1] == {-}} {
		if {[string is lower -strict $lastchar]} {
			set value [string replace $value	\
				end end [string toupper $lastchar]]
		} elseif {[string is upper -strict $lastchar]} {
			set value [string replace $value end end	\
				"Shift-[string toupper $lastchar]"]
		}
	}
	regsub {((Key)|(KeyPress)|(KeyRelease))\-} $value {} value
	regsub -all {\-} $value {+} value
	regsub  {Control} $value {Ctrl} value

	# Translate special strings
	regsub -all {XF86_Switch_VT_}	$value {Shift+F}	value
	regsub -all {ISO_Left_Tab$}	$value {Shift+Tab}	value

	# Return result
	return $value
}

## Shortcut configuration related to main window
 # Key shortcut categories related to this segment
set SHORTCUT_CATEGORIES	{main project sim tools help}
 # Unredefinable key sequences
set HARDCODED_SHORTCUTS {
	Control-Key-1 Control-Key-2 Control-Key-3 Control-Key-4 Control-Key-5
	Control-Key-6 Control-Key-7 Control-Key-8 Control-Key-9 Control-Key-0
}
 # Currently set bindigs
set SET_SHORTCUTS	{}

## Create bindings for defined key shortcuts
 # @return void
proc shortcuts_reevaluate {} {
	# Unset previous configuration
	foreach key ${::SET_SHORTCUTS} {
		bind . <$key> {}
	}
	set ::SET_SHORTCUTS {}

	# Iterate over shortcuts definition
	foreach block ${::SHORTCUTS_LIST} {
		# Determinate category
		set category	[lindex $block 0]
		if {[lsearch ${::SHORTCUT_CATEGORIES} $category] == -1} {continue}

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
			lappend ::SET_SHORTCUTS $key
			set cmd [lindex $block [list $j 1]]
			append cmd {;break}
			bind . <$key> $cmd
		}
	}
}


# CREATE MAIN MENU BAR
# -----------------------------

# Definition of main menu bar
set MAINMENU {
	{cascade	"File"		0	""	.file		false 1 {
		{command	"New"		"$edit:new"		0	{X::__new}
			"filenew"	"Create new file"}
		{separator}
		{command	"Open"		"$edit:open"		0	{X::__open}
			"fileopen"	"Open an existing file"}
		{cascade	"Open recent"	5	"fileopen"	.open_recent	false 1 {
		}}
		{separator}
		{command	"Save"		"$edit:save"		0	{X::__save}
			"filesave"	"Save the current file"}
		{command	"Save as"	"$edit:save_as"		1	{X::__save_as}
			"filesaveas"	"Save under a different name"}
		{command	"Save all"	"$edit:save_all"	2	{X::__save_all}
			"save_all"	"Save the current file under a different name"}
		{separator}
		{command	"Close"		"$edit:close"		0	{X::__close}
			"fileclose"	"Close the current file"}
		{command	"Close all"	"$edit:close_all"	1	{X::__close_all}
			"cancel"	"Close all opened files"}
		{separator}
		{command	"File statistics" "$main:statistics"	0	{X::__statistics}
			""		"Display file statistics"}
		{separator}
		{command	"Save session"	"$main:savesession"	3	{X::save_session}
			""		"Save current session. Session file contains list of opened project, sizes of panels, etc."}
		{separator}
		{command	"Quit"		"$main:quit"		0	{X::__exit}
			"exit"		"Exit program"}
	}}
	{cascade	"Edit"		0	""	.edit		false 0 {
		{command	"Undo"		"$edit:undo"	0	{X::__undo}		"undo"
			"Take back last operation"}
		{command	"Redo"		"$edit:redo"	2	{X::__redo}		"redo"
			"Take back last undo"}
		{separator}
		{command	"Cut"		"$edit:cut"	2	{X::__cut}		"editcut"
			"Move selected text into the clipboard"}
		{command	"Copy"		"$edit:copy"	0	{X::__copy}		"editcopy"
			"Copy selected text into the clipboard"}
		{command	"Paste"		"$edit:paste"	0	{X::__paste}		"editpaste"
			"Paste text from clipboard"}
		{separator}
		{command	"Select all"	"$edit:select_all" 7	{X::__select_all}	""
			"Select all text in the editor"}
		{separator}
		{command	"Find"		"$edit:find"	0	{X::__find}		"find"
			"Find a string in the text"}
		{command	"Find next"	"$edit:find_next" 5	{X::__find_next}	"1downarrow"
			"Find next occurrence of search string"}
		{command	"Find previous"	"$edit:find_prev" 10	{X::__find_prev}	"1uparrow"
			"Find previous occurrence of search string"}
		{separator}
		{command	"Replace"	"$edit:replace"	0	{X::__replace}		""
			"Replace some string with another"}
		{separator}
		{command	"Go to line"	"$edit:goto"	0	{X::__goto}		"goto"
			"Jump to line"}
		{separator}
		{command	"Comment"	"$edit:comment"	2	{X::__comment}		""
			"Comment selected text"}
		{command	"Uncomment"	"$edit:uncomment" 6	{X::__uncomment}	""
			"Uncomment selected text"}
		{separator}
		{command	"Indent"	"$edit:indent"	0	{X::__indent}		"indent"
			"Indent selected text"}
		{command	"Unindent"	"$edit:unindent" 6	{X::__unindent}		"unindent"
			"Unindent selected text"}
	}}
	{cascade	"View"		0	""	.display	false 1 {
		{checkbutton	"Read only mode"	"$sim:readonly"	{::editor_RO_MODE}	1 0 5
			{::X::switch_editor_RO_MODE}
			"Set current editor to read only/normal mode"}
		{command	"Switch to command line"	"$edit:cmd_line"	7	{X::__switch_to_cmd_line}
			""	"Switch to editor command line"}
		{separator}
		{command	"Show/Hide icon border"		"$edit:icon_border"	10	{X::__show_hine_IconB}
			"view_choose"	"Show/Hide editor's icon border (bookmark icons)"}
		{command	"Show/Hide line numbers"	"$edit:line_numbers"	10	{X::__show_hine_LineN}
			"view_choose"	"Show/Hide editor's line numbers"}
		{command	"Reload"			"$edit:reload"		0	{X::__reload}
			"reload"	"Reload current file"}
		{cascade	"Highlight"		0	""	.highlight	false 1 {
			{radiobutton	"None"			{}	::editor_SH		-1
				::X::highlight_pattern_changed	0
				""}
			{radiobutton	"Assembly language"	{}	::editor_SH		0
				::X::highlight_pattern_changed	0
				""}
			{radiobutton	"Assembler ASX8051"	{}	::editor_SH		3
				::X::highlight_pattern_changed	12
				"Reallocable assembler from SDCC project"}
			{radiobutton	"C language"		{}	::editor_SH		1
				::X::highlight_pattern_changed	0
				""}
			{radiobutton	"Code listing"		{}	::editor_SH		2
				::X::highlight_pattern_changed	5
				""}
		}}
		{separator}
		{command	"Full screen mode" 	"$main:fullscreen"	0	{X::__toggle_fullscreen}
			"window_fullscreen"	"Toggle full screen mode"}
		{separator}
		{command	"Clear messages panel" "$messages:clear_mess"	0	{X::__clear_messages_text}
			"editdelete"	"Clear messages panel"}
	}}
	{cascade	"Project"	0	""	.project	false 0 {
		{command	"New"			"$project:proj_new"	0	{X::__proj_new}
			"filenew"	"Create new project"}
		{separator}
		{command	"Open"			"$project:proj_open"	0	{X::__proj_open}
			"project_open"	"Open an existing project"}
		{cascade	"Open recent"	5	"project_open"	.open_recent	false 1 {
		}}
		{separator}
		{command	"Save"			"$project:proj_save"	0	{X::__proj_save}
			"filesave"	"Save the current project"}
		{separator}
		{command	"Edit project"		"$project:proj_edit"	0	{X::__proj_edit}
			"configure"	"Edit project details"}
		{separator}
		{command	"Save and close"	"$project:proj_close"	1	{X::__proj_close}
			"fileclose"	"Save the current project and close it"}
		{command	"Close without saving"	"$project:proj_clsimm"	0	{X::__proj_close_imm}
			"no"	"Close current project"}
	}}
	{cascade	"Simulator"	0	""	.simulator	false 1 {
		{command	"Start / Shutdown"	"$sim:initiate_sim"	0	{X::__initiate_sim}
			"launch"	"Start simulator engine"}
		{command	"Debug this file only"	"$sim:initiate_sim0"	6	{X::__initiate_sim 1}
			"launch_this"	"Start simulator engine and load current file only"}
		{separator}
		{command	"Step back"		"$sim:stepback"		5	{X::__stepback}
			"undo"		"Step program back by 1 instruction"}
		{command	"Step"			"$sim:step"		3	{X::__step}
			"goto"		"Step program by 1 instruction"}
		{command	"Step over"		"$sim:stepover"		5	{X::__stepover}
			"goto2"		"Step program by 1 line of code"}
		{command	"Animate"		"$sim:animate"		0	{X::__animate}
			"1rightarrow"	"Run program and show results after each change"}
		{command	"Run"			"$sim:run"		2	{X::__run}
			"2rightarrow"	"Run program and show results periodically in some interval"}
		{separator}
		{command	"Hiberante program"	"$sim:hiberante"	0	{X::__hibernate}
			"bar5"		"Save current state of simulator engine to a file for future resumption"}
		{command	"Resume hibernated program" "$sim:resume"	4	{X::__resume}
			"resume"	"Resume hibernated program"}
		{separator}
		{command	"Stopwatch"	 	"$sim:stopwatch"	4	{X::__stopwatch_timer}
			"player_time"	"Configurable stopwatch timer which can stop simulation on various conditions"}
		{separator}
		{command	"Find cursor"		"$sim:find_cur"		0	{X::__see_sim_cursor}
			"forward"	"Find simulator cursor in the editor"}
		{command	"Jump to line"		"$sim:line2addr"	0	{X::__simulator_set_PC_by_line}
			"2_rightarrow"	"Translate line number to address in program memory and set PC to that address"}
		{command	"Clear highlight"	"$sim:clear_hg"		7	{X::__sim_clear_highlight}
			"editclear"	"Clear highlight for changed values"}
		{checkbutton	"Allow breakpoints"	"$sim:allow_BP"	{::CONFIG(BREAKPOINTS_ALLOWED)}	1 0 1 {}
			"Enable simulator breakpoints (marks, where to stop program in animate or run mode)"}
	}}
	{cascade	"Virtual MCU"	8	""	.virtual_mcu	false 1 {
		{command	"Show SFR map"		"$sim:sfrmap"		5	{X::__sfr_map}
			"kcmmemory_S"	"Show map of special function registers area"}
		{command	"Show bit area"		"$sim:bitmap"		5	{X::__bitmap}
			"kcmmemory_BA"	"Show bit addressable area"}
		{command	"Show stack"		"$sim:stack"		5	{X::__stack_monitor}
			"kcmmemory_ST"	"Invoke MCU stack monitor"}
		{command	"Show Code memory"	"$sim:show_code_mem"	5	{X::__show_code_mem}
			"kcmmemory_C"	"Invoke hex editor with program code"}
		{command	"Show XDATA memory"	"$sim:show_ext_mem"	5	{X::__show_ext_mem}
			"kcmmemory_X"	"Invoke hex editor with external data memory"}
		{command	"Show ERAM"		"$sim:show_exp_mem"	5	{X::__show_exp_mem}
			"kcmmemory_E"	"Invoke hex editor with expanded RAM"}
		{command	"Show Data EEPROM"	"$sim:show_eeprom"	5	{X::__show_eeprom}
			"kcmmemory_P"	"Invoke hex editor with data EEPROM"}
		{command	"Show EEPROM write buffer" "$sim:show_eem_wb"	14	{X::__show_eeprom_write_buffer}
			"kcmmemory_B"	"Invoke hex editor editor with data EEPROM write buffer"}
		{separator}
		{cascade	"Reset"	0	"rebuild"	.virtual_mcu_reset	false 1 {
			{command	"Only SFR"	"$sim:reset-"	0	{X::__reset -}
				"rebuild"	"Reset Special Function Registers only"}
			{command	"All zeros"	"$sim:reset0"	0	{X::__reset 0}
				"rebuild"	"Reset all internal registers to zeroes"}
			{command	"All ones"	"$sim:reset1"	1	{X::__reset 1}
				"rebuild"	"Reset all internal registers to ones (0xFF)"}
			{command	"Random values"	"$sim:resete"	0	{X::__reset r}
				"rebuild"	"Reset all internal registers to random values"}
		}}
		{separator}
		{command	"Interrupt monitor" 	"$sim:intrmon"		6	{X::__interrupt_monitor}
			"kcmdf"		"Dialog in which you can control MCU interrupts"}
	}}
	{cascade	"Virtual HW"	8	""	.virtual_hw	false 1 {
		{command	"LED Panel"		"$virtual_hw:ledpanel"	2	{X::__vhw_LED_panel}
			"ledpanel"	""}
		{command	"LED Display"		"$virtual_hw:leddisplay" 10	{X::__vhw_LED_display}
			"leddisplay"	""}
		{command	"LED Matrix"		"$virtual_hw:ledmatrix"	4	{X::__vhw_LED_matrix}
			"ledmatrix"	""}
		{command	"Multiplexed LED Display" "$virtual_hw:mleddisplay" 1	{X::__vhw_M_LED_display}
			"mleddisplay"	""}
		{command	"Simple Keypad"		"$virtual_hw:simplekeypad" 1	{X::__vhw_keys}
			"simplekeypad"	""}
		{command	"Matrix Keypad"		"$virtual_hw:matrixkeypad" 7	{X::__vhw_matrix_keypad}
			"matrixkeypad"	""}
		{cascade	"LCD display (HD44780)"	13	"hd44780"	.hd44780	false 1 {
			{command	"1 × 8"		""			0	{X::__vhw_HD44780 {1 8}}
				"hd44780"	"LCD display controlled by HD44780"}
			{command	"2 × 8"		""			0	{X::__vhw_HD44780 {2 8}}
				"hd44780"	"LCD display controlled by HD44780"}
			{command	"2 × 16"	""			0	{X::__vhw_HD44780 {2 16}}
				"hd44780"	"LCD display controlled by HD44780"}
			{command	"2 × 20"	""			0	{X::__vhw_HD44780 {2 20}}
				"hd44780"	"LCD display controlled by HD44780"}
			{command	"2 × 40"	""			0	{X::__vhw_HD44780 {2 40}}
				"hd44780"	"LCD display controlled by HD44780"}
			{command	"Any"	""				0	{X::__vhw_HD44780}
				"hd44780"	"LCD display controlled by HD44780"}
		}}
		{command	"DS1620 temperature sensor"	"$virtual_hw:ds1620" 8	{X::__vhw_ds1620}
			"ds1620"	"Simulated DS1620 thermometer"}
		{command	"File Interface"	"$virtual_hw:fintr" 	1	{X::__vhw_file_interface}
			"compfile1"	"Read & Write GPIO states from/to a file"}
		{separator}
		{command	"Open"			"$virtual_hw:vhw_open"	0	{X::__open_VHW}
			"fileopen"	"Load VHW connections from a file"}
		{cascade	"Open recent"	1	"fileopen"	.open_recent	false 1 {
		}}
		{separator}
		{command	"Load"			"$virtual_hw:vhw_load"	0	{X::__load_VHW}
			"fileimport"	"Import VHW connections from a file"}
		{cascade	"Load recent"	9	"fileimport"	.load_recent	false 1 {
		}}
		{separator}
		{command	"Save"			"$virtual_hw:vhw_save"	0	{X::__save_VHW}
			"filesave"	"Save current VHW connections to a file"}
		{command	"Save as"		"$virtual_hw:vhw_saveas" 1	{X::__save_as_VHW}
			"filesaveas"	"Save current VHW connections under a different name"}
		{separator}
		{command	"Remove all"		"$virtual_hw:vhw_remove_all" 0	{X::__remove_all_VHW}
			"editdelete"	"Remove all VHW"}
	}}
	{cascade	"Tools"		0	""	.tools		false 1 {
		{command	"Compile"		"$tools:assemble"	0	{X::__compile 0}
			"compfile"	"Compile the source code"}
		{command	"Compile this file"	"$tools:assemble0"	10	{X::__compile 0 {} 1}
			"compfile_this"	"Compile current file only"}
		{command	"Disassemble"		"$tools:disasm"		0	{X::__disasm}
			"disasm"	"Disassemble object code and open new editor with the result"}
		{separator}
		{cascade	"Encoding"	1	""	.encoding	false 1 {
		}}
		{cascade	"End of line"	4	""	.eol		false 1 {
			{radiobutton	"Unix"		"LF"	{::editor_EOL} {lf}	{::X::change_EOL} 0}
			{radiobutton	"DOS"		"CRLF"	{::editor_EOL} {crlf}	{::X::change_EOL} 0}
			{radiobutton	"Macintosh"	"CR"	{::editor_EOL} {cr}	{::X::change_EOL} 0}
		}}
		{separator}
		{command	"Auto indent"		"$tools:auto_indent"	1	{X::__reformat_code}
			"filter"	"Reformat source code (Indention level etc.)"}
		{command	"Change letter case"	"$tools:change_case"	7	{X::__change_letter_case}
			"change_case"	"Change letter case in source code (with options)"}
		{separator}
		{command	"Export as XHTML"	"$tools:toHTML"		0	{X::__toHTML}
			"html"		"Export highlighted code as XHTML file"}
		{command	"Export as LaTeX"	"$tools:toLaTeX"	1	{X::__toLaTeX}
			"tex"		"Export highlighted code as LaTeX source, using package color"}
		{separator}
		{command	"Document current function"	"$tools:doc_cur_f" 4	{X::__document_current_func}
			""		"Create doxygen documentation for function on current line"}
		{command	"Run doxywizard"		"$tools:doxywizard" 7	{X::__run_doxywizard}
			""		"Run doxygen front-end"}
		{command	"Clear C API documentation"	"$tools:clr_doc" 8	{X::__clear_documentation}
			""		"Remove C API documentation created by doxygen"}
		{command	"Build C API documentation"	"$tools:doxygen" 9	{X::__generate_documentation}
			""		"Run doxygen to create C API documentation"}
		{separator}
		{command	"Clean up project folder" "$tools:cleanup"	17	{X::__cleanup}
			"emptytrash"	"Invoke dialog to remove needless files the project directory"}
		{separator}
		{command	"Custom command 0"	"$tools:custom0"	15	{X::__exec_custom_cmd 0}
			"gear0"		""}
		{command	"Custom command 1"	"$tools:custom1"	15	{X::__exec_custom_cmd 1}
			"gear1"		""}
		{command	"Custom command 2"	"$tools:custom2"	15	{X::__exec_custom_cmd 2}
			"gear2"		""}
	}}
	{cascade	"Utilities"	0	""	.utilities	false 0 {
		{command	"Hex -> Bin"		"$utilities:hex2bin"	0	{X::__hex2bin}
			"hb"		"Convert Intel HEX 8 file to binary file"}
		{command	"Bin -> Hex"		"$utilities:bin2hex"	0	{X::__bin2hex}
			"bh"		"Convert binary file to Intel HEX 8 file"}
		{command	"Sim -> Hex"		"$utilities:sim2hex"	0	{X::__sim2hex}
			"sh"		"Convert simulator file to Intel HEX 8 file"}
		{command	"Sim -> Bin"		"$utilities:sim2bin"	1	{X::__sim2bin}
			"sb"		"Convert simulator file to binary file"}
		{command	"Normalize Intel 8 hex file"		"$utilities:normalize_hex" 0	{X::__normalize_hex}
			"hh"		"Reformat the given IHEX8"}
		{separator}
		{command	"Hex Editor"		"$utilities:hexeditor"	1	{X::__hexeditor}
			"ascii"		"Invoke project independent hexadecimal editor with capacity of 64KB"}
		{command	"Symbol Table"		"$utilities:symb_view"	7	{X::__symb_view}
			"symbol"	"Assembly language symbol table viewer"}
		{command	"8-Segment Editor"	"$utilities:8seg"	4	{X::__eightsegment}
			"8seg"		"8-Segment LED Display Editor"}
		{command	"ASCII Chart"		"$utilities:ascii_c"	0	{X::__ascii_chart}
			"math_matrix"	"ASCII Chart"}
		{command	"8051 Instruction Table" "$utilities:toi"	0	{X::__table_of_instructions}
			"fsview"	"Interactive table of 8051 instructions"}
		{separator}
		{command	"Scribble Notepad"	"$utilities:notes"	10	{X::__notes}
			"pencil"	""}
		{command	"Base Converter"	"$utilities:bc"		5	{X::__base_converter}
			"kaboodleloop"	""}
		{command	"Special Calculator"	""			1	{X::__spec_calc}
			"xcalc"	""}
		{separator}
		{command	"UART/RS232 Debugger"	"$utilities:rs232"	2	{X::__rs232debugger}
			"chardevice"	""}
	}}
	{cascade	"Configure"	0	""	.configure	false 0 {
		{command	"Configure Editor"	""	0	{::configDialogues::editor::mkDialog}
			"configure"
			"Editor configuration (colors, fonts, highlighting, etc.)"}
		{command	"Configure Compiler"	""	1	{::configDialogues::compiler::mkDialog}
			"configure"
			"Various compilation options"}
		{command	"Configure Simulator"	""	12	{::configDialogues::simulator::mkDialog}
			"configure"
			"Opens simulator configuration dialog"}
		{command	"Configure Right Panel"	""	2	{::configDialogues::rightPanel::mkDialog}
			"configure"
			"Right panel configuration (instruction details colors)"}
		{command	"Configure Main Toolbar" ""	3	{::configDialogues::toolbar::mkDialog}
			"configure_toolbars"
			"Adjust content of the main toolbar (under main menu)"}
		{command	"Edit custom commands" ""	3	{::configDialogues::custom_commands::mkDialog}
			"configure"
			"Set or modify user defined commands"}
		{command	"Configure shortcuts" ""	10	{::configDialogues::shortcuts::mkDialog}
			"configure_shortcuts"
			"Set or modify key shortcuts"}
		{command	"Configure terminal emulator"	"" 12	{::configDialogues::terminal::mkDialog}
			"terminal"
			"Configure embedded terminal emulator -- RXVT-UNICODE"}
		{command	"Configure MCU 8051 IDE" ""	4	{::configDialogues::global::mkDialog}
			"mcu8051ide"
			"Invoke global configuration dialog"}
	}}
	{cascade	"Help"		0	""	.help		false 1 {
		{command	"About"			"$help:about"	0	{X::__about}
			"mcu8051ide"	"About MCU 8051 IDE"}
		{command	"Welcome Dialog" 	"$help:welcome"	0	{X::__welcome_dialog}
			"info"		"Invoke dialog which you have seen on the first start"}
		{command	"Tip of the Day" 	"$help:tips"	0	{X::__tip_of_the_day}
			"idea"		"Some tips about how to use this program more efficiently"}
		{separator}
		{command	"Project web page"	""		8	{::X::__web_page}
			"html"		""}
		{command	"Report a bug"	""			9	{::X::__bug_report}
			"bug"		""}
		{separator}
		{command	"ASEM-51 manual"	""		0	{::X::__asem51_manual}
			"asem51"	""}
		{command	"SDCC manual"		""		0	{::X::__sdcc_manual}
			"sdcc"	""}
		{separator}
		{command	"Handbook"		""		0	{::X::__handbook}
			"contents"	""}
	}}
}
# Intentionally hidden functions, these haven't been fully implemented yet
# This belongs to the "Virtual MCU":
# 		{separator}
# 		{cascade	"Functional diagrams" 0 "blockdevice" .virtual_mcu_fd	false 1 {
# 			{command	"Timer/Counter 0"	""	14	{X::__functional_diagram 0}
# 				"player_time"	""}
# 			{command	"Timer/Counter 1"	""	14	{X::__functional_diagram 1}
# 				"player_time"	""}
# 			{command	"Timer/Counter 2"	""	14	{X::__functional_diagram 2}
# 				"player_time2"	""}
# 			{command	"Baud rate generator"	""	0	{X::__functional_diagram b}
# 				"fsview"	""}
# 			{command	"UART"			""	0	{X::__functional_diagram u}
# 				"_blockdevice"	"Universal asynchronous receiver transmitter"}
# 			{command	"SPI"			""	0	{X::__functional_diagram s}
# 				"blockdevice"	"Serial peripheral interface"}
# 			{command	"PCA"			""	0	{X::__functional_diagram s}
# 				"kservices"	"Programable counter array"}
# 			{command	"Watchdog timer"	""	0	{X::__functional_diagram w}
# 				"flag"	""}
# 		}}
# 		{separator}
# 		{command	"Virtual SPI termnal"	""	9	{X::__virtual_terminal s}
# 			"chardevice"	""}
#
# Virtual MCU:	{command	"UART Monitor" 		"$sim:uartmon"		1	{X::__uart_monitor}
# 			"__blockdevice"		"Dialog in which you can control UART operations"}
#
# Virtual HW:	{command	"Virtual UART terminal"	"$virtual_hw:vuterm"	8	{X::__vhw_UART_terminal}
# 			"_chardevice"	"Simulated UART terminal connected to the MCU simulator"}
#
# Tools:		{command	"Disassemble with D52"	"$tools:d52"		15	{X::__d52}
# 			"d52"		""}
# 		{separator}
#

## (Re)Draw main menu
 # @return void
proc mainmenu_redraw {} {
	global editor_EOL
	global editor_encoding
	global MAINMENU

	# Destroy main menu
	if {[winfo exists .mainMenu]} {
		destroy .mainMenu
	}
	# Create main menu
	. configure -menu .mainMenu
	menuFactory $MAINMENU .mainMenu 0 {} 0 {} [namespace current]
	if {!${::MICROSOFT_WINDOWS}} {
		.mainMenu configure				\
			-activeborderwidth 1			\
			-bg ${::COMMON_BG_COLOR}		\
			-activeforeground {#6666FF}		\
			-activebackground ${::COMMON_BG_COLOR}	\
			-bd 0
	}

	# Restore lists of recent files
	for {set i 0} {$i < 3} {incr i} {
		::X::refresh_recent_files $i
	}

	## CREATE MENU "Encoding" and set default ENCODING and EOL
	set editor_EOL		{lf}	;# Current EOL
	set editor_encoding	{utf-8}	;# Current encoding

	# Major encodings
	foreach enc {
			utf-8			iso8859-1		iso8859-2
			iso8859-3		iso8859-4		iso8859-5
			iso8859-6		iso8859-7		iso8859-8
			iso8859-9		iso8859-10		iso8859-13
			iso8859-14		iso8859-15		iso8859-16
		} \
	{
		.mainMenu.tools.encoding add radiobutton	\
			-label [mc [enc2name $enc]]		\
			-value $enc				\
			-accelerator [string toupper $enc]	\
			-variable ::editor_encoding		\
			-command {::X::change_encoding}		\
			-indicatoron 0				\
			-compound left				\
			-image ::ICONS::raoff			\
			-selectimage ::ICONS::raon		\
			-selectcolor ${::COMMON_BG_COLOR}
	}
	.mainMenu.tools.encoding entryconfigure 0 -foreground {#0000FF} -underline 0

	# Shit encodings
	set menu [menu .mainMenu.tools.encoding.shit_encodings]
	.mainMenu.tools.encoding add cascade -label "CP125x" -menu $menu
	foreach enc {cp1250 cp1251 cp1252 cp1253 cp1254 cp1255 cp1256 cp1257 cp1258} {
		$menu add radiobutton				\
			-label $enc				\
			-value $enc				\
			-variable ::editor_encoding		\
			-command {::X::change_encoding}		\
			-indicatoron 0				\
			-compound left				\
			-image ::ICONS::raoff			\
			-selectimage ::ICONS::raon		\
			-selectcolor ${::COMMON_BG_COLOR}
	}

	# Window geometry correction
	wm geometry . $::CONFIG(WINDOW_GEOMETRY)
	update idletasks
	if {!$::MICROSOFT_WINDOWS && $::CONFIG(WINDOW_ZOOMED)} {
		wm attributes . -zoomed $::CONFIG(WINDOW_ZOOMED)
	}

	# Enable / Disable menu items
	if {${::X::project_menu_locked}} {
		::X::Lock_project_menu
	} else {
		::X::disena_simulator_menu ${::X::actualProject}
		if {![lindex ${::X::simulator_enabled} ${::X::actualProjectIdx}]} {
			::X::Lock_simulator_menu
		}
	}

	# Remove menu items which access features are not available on MS Windows
	if {$::MICROSOFT_WINDOWS} {
		.mainMenu.configure delete [::mc "Configure terminal emulator"]
		.mainMenu.configure delete [::mc "Edit custom commands"]
		.mainMenu.tools delete [::mc "Custom command 0"]
		.mainMenu.tools delete [::mc "Custom command 1"]
		.mainMenu.tools delete [::mc "Custom command 2"]
		.mainMenu.tools delete [::mc "Run doxywizard"]
		.mainMenu.tools delete [::mc "Clear C API documentation"]
	}

	# Disable menu items which are not available when external editor used
	::X::adjust_mm_and_tb_ext_editor
}

# MAIN ICON BAR
# ----------------------

# Create main toolbar frames
set TOOLBAR_FRAME [frame .mainToolbar]
pack $TOOLBAR_FRAME -side top -anchor nw -pady 5 -fill x
frame .mainIconBar

# Create toolbar popup menu
menuFactory {
	{command	"Hide Toolbar" 	""	0	{
			set ::CONFIG(TOOLBAR_VISIBLE) 0
			show_hide_main_toolbar
		}	"2uparrow"	"Hide main toolbar"}
	{command	"Configure Toolbar" 	""	0
		{::configDialogues::toolbar::mkDialog}
		"configure_toolbars"	"Configure main toolbar"}
} $TOOLBAR_FRAME.menu 0 {} 0 {} [namespace current]
bind .mainIconBar <ButtonRelease-3> "tk_popup $TOOLBAR_FRAME.menu %X %Y"

# Create popup menu for custom commands
menuFactory {
	{command	"Hide Toolbar" 			""	0
		{set ::CONFIG(TOOLBAR_VISIBLE) 0; show_hide_main_toolbar}
		"2uparrow"		"Hide main toolbar"}
	{command	"Configure Toolbar" 		""	0
		{::configDialogues::toolbar::mkDialog}
		"configure_toolbars"	"Configure main toolbar"}
	{separator}
	{command	"Configure custom commands"	""	1
		{::configDialogues::custom_commands::mkDialog ${::CUSTOM_CMD_MENU_CMD_INDEX}}
		"configure"		"Invoke custom commands configuration dialog"}
} $TOOLBAR_FRAME.custom_cmd_menu 0 {} 0 {} [namespace current]

# Create show button
Label $TOOLBAR_FRAME.show_label		\
	-bd 0 -highlightthickness 0	\
	-image ::ICONS::22::bar1	\
	-helptext [mc "Show toolbar"]
bind $TOOLBAR_FRAME.show_label <Button-1> {
	set ::CONFIG(TOOLBAR_VISIBLE) 1
	show_hide_main_toolbar
}

# Help variable for 'custom_cmd_menu' -- index of selected command
set CUSTOM_CMD_MENU_CMD_INDEX 0

## Definition of all possoble items for main icon bar
 # format: {
 #	{item_ID} {item_name icon_22x22 icon_16x16 command_postfix statusTip}
 #	....
 # }
 # note: command prefix is '::X::__' so if command_postfix == 'new' then the whole command is '::X::__new'
set ICONBAR_ICONS {
	{new}		{ "Create new file"		{filenew}	{filenew}
		{new}		{Create new file}}
	{open}		{ "Open file"			{fileopen}	{fileopen}
		{open}		{Open file}}
	{save}		{ "Save"			{filesave}	{filesave}
		{save}		{Save the current file}}
	{save_as}	{ "Save as"	{filesaveas}	{filesaveas}
		{save_as}	{Save the current file under a different name}}
	{save_all}	{ "Save all"			{save_all}	{save_all}
		{save_all}	{Save all opened files (in this project)}}
	{close}		{ "Close"			{fileclose}	{fileclose}
		{close}		{Close the current file}}
	{close_all}	{ "Close all"			{stop}		{cancel}
		{close_all}	{Close all opened files}}
	{exit}		{ "Exit"			{exit}		{exit}
		{exit}		{Exit application}}
	{undo}		{ "Undo"			{undo}		{undo}
		{undo}		{Take back last operation}}
	{redo}		{ "Redo"			{redo}		{redo}
		{redo}		{Take back last undo}}
	{cut}		{ "Cut"				{editcut}	{editcut}
		{cut}		{Move selected text into the clipboard}}
	{copy}		{ "Copy"			{editcopy}	{editcopy}
		{copy}		{Copy selected text into the clipboard}}
	{paste}		{ "Paste"			{editpaste}	{editpaste}
		{paste}		{Paste text from clipboard}}
	{find}		{ "Find a string in the text"	{find}		{find}
		{find}		{Find a string in the text}}
	{findnext}	{ "Find next"			{1downarrow}	{1downarrow}
		{find_next}		{Find next occurrence of search string}}
	{findprev}	{ "Find previous"		{1uparrow}	{1uparrow}
		{find_prev}	{Find previous occurrence of search string}}
	{replace}	{ "Replace"			{find}		{find}
		{replace}	"Replace some string with another"}
	{goto}		{ "Jump to line"		{goto}		{goto}
		{goto}		{Jump to line}}
	{reload}	{ "Reload"			{reload}	{reload}
		{reload}	"Reload the current file"}
	{clear}		{ "Clear messages panel"	{editdelete}	{editdelete}
		{clear_messages_text}	"Clear messages panel"}
	{project_new}	{ "Create new project"		{filenew}	{filenew}
		{proj_new}	{Create new project}}
	{project_open}	{ "Open project"		{project_open}	{project_open}
		{proj_open}	{Open an existing project}}
	{proj_save}	{ "Save project"		{filesave}	{filesave}
		{proj_save}	"Save the current project"}
	{proj_edit}	{ "Edit project"		{configure}	{configure}
		{proj_edit}	"Edit project details"}
	{proj_close}	{ "Save and close project"	{fileclose}	{fileclose}
		{proj_close}	"Save the current project and close it"}
	{proj_close_imm} { "Close project without saving" {stop}	{no}
		{proj_close_imm}	"Close current project"}
	{sfrmap}	{ "Show SFR map"		{memory_S}	{kcmmemory_S}
		{sfr_map}	"Show map of special function registers area"}
	{bitmap}	{ "Show bit area"		{memory_BA}	{kcmmemory_BA}
		{bitmap}	"Show bit addressable area"}
	{show_code_mem}	{ "Show CODE memory"		{memory_C}	{kcmmemory_C}
		{show_code_mem}	"Invoke hex editor with program code"}
	{show_ext_mem}	{ "Show XDATA memory"		{memory_X}	{kcmmemory_X}
		{show_ext_mem}	"Invoke hex editor with external data memory"}
	{show_exp_mem}	{ "Show ERAM"			{memory_E}	{kcmmemory_E}
		{show_exp_mem}	"Invoke hex editor with expanded RAM"}
	{show_eeprom}	{ "Show data EEPROM"		{memory_P}	{kcmmemory_P}
		{show_eeprom}	"Invoke hex editor with data EEPROM"}
	{show_eem_wr_b}	{ "Show EEPROM write buffer"	{memory_B}	{kcmmemory_B}
		{show_eeprom_write_buffer}	"Invoke hex editor editor with data EEPROM write buffer"}
	{stack} { 	"Show stack" 		{memory_ST}		{kcmmemory_ST}
		{stack_monitor}	"Invoke MCU stack monitor"}
	{start_sim}	{ "Start / Shutdown simulator"	{fork}		{launch}
		{initiate_sim}	{Load debug file into simulator engine}}
	{start_sim0}	{ "Debug this file only"	{fork_this}	{launch_this}
		{initiate_sim 1} {Start simulator engine and load current file only}}
	{reset}		{ "Reset"			{rebuild}	{rebuild}
		{reset -}	"Perform HW reset"}
	{step}		{ "Step program"		{goto}		{goto}
		{step}		"Step by 1 instruction"}
	{stepover}	{ "Step over"			{goto2}		{goto2}
		{stepover}	"Step by 1 line of code"}
	{animate}	{ "Animate program"		{1rightarrow}	{1rightarrow}
		{animate}	"Run program and show results after each instruction"}
	{run}		{ "Run program"			{2rightarrow}	{2rightarrow}
		{run}		"Run program in simulator"}
	{hibernate}	{ "Hibernate program"		{bar5}		{bar5}
		{hibernate}	"Hibernate running program to a file"}
	{resume}	{ "Resume program"		{resume}	{resume}
		{resume}	"Resume hibernated program"}
	{intrmon}	{ "Interrupt monitor"		{kcmdf}		{kcmdf}
		{interrupt_monitor}	"Dialog in which you can control MCU interrupts"}
	{stopwatch}	{ "Stopwatch"			{history}	{player_time}
		{stopwatch_timer}	"Configurable stopwatch timer which stop simulation on various conditions"}
	{clear_hg}	{ "Clear highlight"		{editclear}	{editclear}
		{sim_clear_highlight}	"Clear highlight for changed values"}
	{assemble}	{ "Compile source code"		{compfile}	{compfile}
		{compile 0}	{Compile source code}}
	{assemble0}	{ "Compile this file"		{compfile_this}	{compfile_this}
		{compile 0 {} 1}	{Compile current file only}}
	{disasm}	{ "Disassemble"			{disasm}	{disasm}
		{disasm}	"Disassemble object code and open new editor with the result"}
	{hexeditor}	{ "Hex Editor"			{binary}	{ascii}
		{hexeditor}	"Invoke project independent hexadecimal editor with capacity of 64KB"}
	{symbol_tbl}	{ "Symbol Table"		{symbol}	{symbol}
		{symb_view}	"Assembly language symbol table viewer"}
	{8seg}		{ "8-Segment Editor"		{8seg}		{8seg}
		{eightsegment}	"8-Segment LED display editor"}
	{ascii_c}	{ "ASCII Chart"			{math_matrix}	{math_matrix}
		{ascii_chart}	"ASCII Chart"}
	{toi}		{ "8051 Instruction Table"	{fsview}	{fsview}
		{table_of_instructions}	"Interactive table of 8051 instructions"}
	{reformat_code}	{ "Auto indent"			{filter}	{filter}
		{reformat_code}	"Reformat source code (Indention level ...)"}
	{change_case}	{ "Change letter case"		{change_case}	{change_case}
		{change_letter_case}	"Change letter case in source code (with options)"}
	{cleanup}	{ "Clean up project folder"	{emptytrash}	{emptytrash}
		{cleanup}	"Invoke dialog to remove needless files the project directory"}
	{toHTML}	{ "Export as XHTML"		{html}		{html}
		{toHTML}	"Export highlighted code as XHTML file"}
	{toLaTeX}	{ "Export as LaTeX"		{tex}		{tex}
		{toLaTeX}	"Export highlighted code as LaTeX source, using package color"}
	{custom0}	{ "Custom command 0"		{gear0}		{gear0}
		{exec_custom_cmd 0}	{}}
	{custom1}	{ "Custom command 1"		{gear1}		{gear1}
		{exec_custom_cmd 1}	{}}
	{custom2}	{ "Custom command 2"		{gear2}		{gear2}
		{exec_custom_cmd 2}	{}}
	{about}		{ "About"			{mcu8051ide}	{mcu8051ide}
		{about}		"About MCU 8051 IDE"}
	{hbook}		{ "Handbook"			contents	contents
		{handbook}	"Display the documentation for MCU 8051 IDE"}
	{forward}	{ "Forward"			{forward}	{1rightarrow}
		{next_editor}	"Switch to the next editor"}
	{back}		{ "Back"			{back}		{1leftarrow}
		{prev_editor}	"Switch to the previous editor"}
	{tip_otd}	{ "Tip of the day"		{help}		{help}
		{tip_of_the_day}	"Some tips about how to use this program more efficiently"}
	{find_sim_cur}	{ "Find cursor"			{forward}	{forward}
		{see_sim_cursor}	"Find simulator cursor in the editor"}
	{line2addr}	{ "Jump to line"		{goto}		{goto}
		{simulator_set_PC_by_line} "Translate line number to address in program memory and set PC to that address"}
	{stepback}	{ "Step back"			{undo}		{undo}
		{stepback}		"Step program back by 1 instruction"}
	{notes}		{ "Scribble Notepad"		{pencil}	{pencil}
		{notes}			"Scribble Notepad"}
	{ledpanel}	{ "LED Panel"			{ledpanel}		{ledpanel}
		{vhw_LED_panel}		"LED Panel"}
	{leddisplay}	{ "LED Display"			{leddisplay}		{leddisplay}
		{vhw_LED_display}	"LED Display"}
	{ledmatrix}	{ "LED Matrix"			{ledmatrix}		{ledmatrix}
		{vhw_LED_matrix}	"LED Matrix"}
	{mleddisplay}	{ "Multiplexed LED Display" 	{mleddisplay}		{mleddisplay}
		{vhw_M_LED_display}	"Multiplexed LED Display"}
	{simplekeypad}	{ "Simple Keypad"		{simplekeypad}		{simplekeypad}
		{vhw_keys}		"Simple Keypad"}
	{matrixkeypad}	{ "Matrix Keypad"		{matrixkeypad}		{matrixkeypad}
		{vhw_matrix_keypad}	"Matrix Keypad"}
	{hd44780}	{ "LCD display (HD44780)"	{hd44780}		{hd44780}
		{vhw_HD44780}	"LCD display controlled by HD44780"}
	{ds1620}	{ "DS1620 thermometer"		{ds1620}		{ds1620}
		{vhw_ds1620}	"Simulated DS1620 temperature sensor"}
	{fintr}		{ "File Interface"		{compfile1}		{compfile1}
		{vhw_file_interface}	"Read & Write GPIO states from/to a file"}
	{vhw_open}	{ "VHW Open"			{fileopen}		{fileopen}
		{open_VHW}		"Load VHW connections from a file"}
	{vhw_load}	{ "VHW Load"			{fileimport}		{fileimport}
		{load_VHW}		"Import VHW connections from a file"}
	{vhw_save}	{ "VHW Save"			{filesave}		{filesave}
		{save_VHW}		"Save current VHW connections to a file"}
	{vhw_saveas}	{ "VHW Save as"			{filesaveas}		{filesaveas}
		{save_as_VHW}		"Save current VHW connections under a different name"}
	{vhw_remove_all} { "VHW Remove all"		{editdelete}		{editdelete}
		{remove_all_VHW}	"Remove all VHW"}
	{bc} { 		"Base Converter"		{kaboodleloop}		{kaboodleloop}
		{base_converter}	"Base Converter"}
	{fullscreen} { 	"Toggle full screen mode"	{window_fullscreen}	{window_fullscreen}
		{toggle_fullscreen}	"Full screen mode"}
	{spec_calc} { 	"Special Calculator" 		{xcalc}			{xcalc}
		{spec_calc}	"Special Calculator"}
	{rs232} { 	"UART/RS232 Debugger" 		{_chardevice}		{chardevice}
		{rs232debugger}	"UART/RS232 Debugger"}
}
# Intentionally hidden functions, these haven't been fully implemented yet
# 	{uartmon}	{ "UART monitor"		{__blockdevice}	{__blockdevice}
# 		{uart_monitor}	"Dialog in which you can control UART operations"}
# 	{d52}		{ "Disassemble with D52"	{d52}		{d52}
# 		{d52}	"Disassemble object code using D52 disassembler"}
# 	{vuterm}	{ "Virtual UART terminal"	{chardevice}		{_chardevice}
# 		{vhw_UART_terminal}	"Simulated UART terminal connected to the MCU simulator"}

## Definition of default main icon bar
 # format: {
 #	item_ID item_ID ...
 # }
set ICONBAR_DEFAULT {
	new		open		| save		save_as		save_all
	| close		exit		| fullscreen	| project_new	project_open
	| find		goto		| hibernate	resume		| custom0
	custom1		| leddisplay	matrixkeypad	| notes		| assemble
	| start_sim	step		stepback
}

## Definition of icons current main icon bar
 # format: {
 #	item_ID item_ID ...
 # }
set ICONBAR_CURRENT {}

## (Re)draw icon bar according to $ICONBAR_CURRENT
 # @return void
proc iconbar_redraw {} {
	::toolbar::iconbar_redraw
}
namespace eval toolbar {
	proc iconbar_redraw {} {
		global ICONBAR_CURRENT	;# Definition of icons current main icon bar
		global ICONBAR_ICONS	;# Definition of all possoble items for main icon bar

		# Destroy current content of the icon bar
		foreach wdg [pack slaves .mainIconBar] {
			destroy $wdg
		}

		# Logo of our company: Moravia Microsystems, s.r.o.
		pack [ttk::button .mainIconBar.company_logo	\
			-image [image create photo	\
					-format png	\
					-file "${::ROOT_DIRNAME}/icons/other/Moravia_Microsystems.png"	\
				]	\
			-style ToolButton.TButton	\
			-command {::X::open_uri {http://www.moravia-microsystems.com/}}
		] -side right -padx 15
		DynamicHelp::add .mainIconBar.company_logo	\
			-text [mc "Visit webside of the Moravia Microsystems, s.r.o. company."]

		# Create hide button
		pack [Label .mainIconBar.hide_label	\
			-bd 0 -highlightthickness 0	\
			-image ::ICONS::22::bar0	\
			-helptext [mc "Hide toolbar"]	\
		] -side left -padx 4
		bind .mainIconBar.hide_label <Button-1> {
			set ::CONFIG(TOOLBAR_VISIBLE) 0
			show_hide_main_toolbar
		}

		set separator_idx 0	;# Separator index (to keep unique widget names)

		# Iterate over icon bar definition
		foreach key $ICONBAR_CURRENT {

			# Skip items which access features are not available on MS Windows
			if {$::MICROSOFT_WINDOWS} {
				if {[lsearch -ascii -exact {custom0 custom1 custom2} $key] != -1} {
					continue
				}
			}

			# Insert regular item
			if {$key != {|}} {
				# Find detail definition
				set idx [lsearch $ICONBAR_ICONS $key]
				if {$idx == -1} {
					puts stderr "iconbar_redraw: Invalid key in definition of Main Tool Bar '$key'"
					continue
				}
				set def [lindex $ICONBAR_ICONS [expr {$idx+1}]]

				# Create button
				set button [ttk::button .mainIconBar.$key	\
					-image ::ICONS::22::[lindex $def 1]	\
					-command X::__[lindex $def 3]		\
					-style ToolButton.TButton		\
				]
				DynamicHelp::add .mainIconBar.$key -text [mc [lindex $def 0]]
				pack $button -side left -padx 0

				## Set status tip
				# For custom commands
				if {[regexp {^custom\d+$} $key]} {
					regexp {\d+} $key num
					setStatusTip -widget $button -text [mc "Custom command %s: %s" $num $::X::custom_command_desc($num)]
					::DynamicHelp::add $button -text [mc "Custom command %s: %s" $num $::X::custom_command_desc($num)]
					bind $button <ButtonRelease-3> [subst {
						set CUSTOM_CMD_MENU_CMD_INDEX $num
						tk_popup $::TOOLBAR_FRAME.custom_cmd_menu %X %Y
					}]
				# For normal commands
				} else {
					setStatusTip -widget $button -text [mc [lindex $def 4]]
					bind $button <ButtonRelease-3> {tk_popup $::TOOLBAR_FRAME.menu %X %Y}
				}

			# Insert separator
			} else {
				# Create vertical separator widget
				pack [ttk::separator .mainIconBar.sep$separator_idx	\
					-orient vertical				\
				] -side left -padx 3 -fill y
				incr separator_idx
			}
		}

		# Disable some buttons if the toolbar is locked
		if {${::X::project_menu_locked}} {
			ena_dis_iconBar_buttons 0 .mainIconBar. ${::X::toolbar_project_dependent_buttons}
		}
	}
}

## Show/Hide main toolbar according to value of config variable TOOLBAR_VISIBLE
 # @return void
proc show_hide_main_toolbar {} {
	# Show the toolbar
	if {$::CONFIG(TOOLBAR_VISIBLE)} {
		catch {
			${::X::actualProject} bottomNB_move_pane_up 11
		}
		pack .mainIconBar -in $::TOOLBAR_FRAME -fill x
		catch {
			pack forget $::TOOLBAR_FRAME.show_label
		}
	# Hide the toolbar
	} else {
		catch {
			${::X::actualProject} bottomNB_move_pane_up -11
		}
		pack $::TOOLBAR_FRAME.show_label -side left -anchor w -padx 4
		catch {
			pack forget .mainIconBar
		}
	}

	# Restore position of bottom pane
	foreach project ${::X::openedProjects} {
		$project bottomNB_redraw_pane
		update
		$project editor_procedure {} Configure {}
	}
}


# GLOBAL POPUP MENUS (entry and text widgets)
# -------------------------------

# Set event bindings
bind Entry <ButtonPress-3>	{break}
bind Entry <ButtonRelease-3>	{GPM_entry_popup %X %Y %x %y %W; break}
bind Entry <Key-Menu>		{GPM_entry_key_menu %W; break}
bind TEntry <ButtonPress-3>	{break}
bind TEntry <ButtonRelease-3>	{GPM_entry_popup %X %Y %x %y %W; break}
bind TEntry <Key-Menu>		{GPM_entry_key_menu %W; break}
bind Text <ButtonRelease-3>	{GPM_text_popup %X %Y %x %y %W; break}
bind Text <Key-Menu>		{GPM_text_key_menu %W; break}

## Create popup menus
 # Menu for entry widgets
menuFactory {
	{command	{Cut}		{Ctrl+X}	2	"GPM_entry_cut"		{editcut}	{}}
	{command	{Copy}		{Ctrl+C}	0	"GPM_entry_copy"	{editcopy}	{}}
	{command	{Paste}		{Ctrl+V}	0	"GPM_entry_paste"	{editpaste}	{}}
	{command	{Clear}		{}		1	"GPM_entry_clear"	{editdelete}	{}}
	{separator}
	{command	{Select all}	{Ctrl+A}	0	"GPM_entry_selall"	{}		{}}
} .gpm_entry_menu 0 {} 0 {} [namespace current]
 # Menu for text widgets
menuFactory {
	{command	{Undo}		{Ctrl+Z}	0	"GPM_text_undo"		{undo}		{}}
	{command	{Redo}		{Ctrl+Shift+Z}	0	"GPM_text_redo"		{redo}		{}}
	{separator}
	{command	{Cut}		{Ctrl+X}	2	"GPM_text_cut"		{editcut}	{}}
	{command	{Copy}		{Ctrl+C}	0	"GPM_text_copy"		{editcopy}	{}}
	{command	{Paste}		{Ctrl+V}	0	"GPM_text_paste"	{editpaste}	{}}
	{command	{Clear}		{}		1	"GPM_text_clear"	{editdelete}	{}}
	{separator}
	{command	{Select all}	{Ctrl+A}	0	"GPM_text_selall"	{}		{}}
} .gpm_text_menu 0 {} 0 {} [namespace current]

# Widget identifiers
set GPM_entry_widget	{}	;# Entry widget
set GPM_text_widget	{}	;# Text widget

## Invoke entry widget popup menu -- event <ButtonRelease-3>
 # @parm Int X		- absolute X coordinate
 # @parm Int Y		- absolute Y coordinate
 # @parm Int x		- relative X coordinate
 # @parm Int y		- relative Y coordinate
 # @parm Widget Widget	- Entry widget
 # @return void
proc GPM_entry_popup {X Y x y Widget} {
	global GPM_entry_widget

	set GPM_entry_widget $Widget
	GPM_entry_menu_disena
	tk_popup .gpm_entry_menu $X $Y
}

## Invoke entry widget popup menu -- event <Key-Menu>
 # @parm Widget Widget	- Entry widget
 # @return void
proc GPM_entry_key_menu {Widget} {
	global GPM_entry_widget

	set GPM_entry_widget $Widget
	GPM_entry_menu_disena
	set bbox [$Widget bbox [$Widget index insert]]
	tk_popup .gpm_entry_menu	\
		[expr {[winfo rootx $Widget] + [lindex $bbox 0] + 10}]	\
		[expr {[winfo rooty $Widget] + [lindex $bbox 1] + 10}]
}

## Enable/Disable popup menu items according to state of the widget
 # For entry widgets. Auxiliary procedure for 'GPM_entry_popup' and 'GPM_entry_key_menu'
 # @return void
proc GPM_entry_menu_disena {} {
	global GPM_entry_widget

	set state [$GPM_entry_widget cget -state]
	if {$state != {normal}} {
		set state {disabled}
	}
	if {[$GPM_entry_widget selection present]} {
		if {$state != {disabled}} {
			.gpm_entry_menu entryconfigure [::mc "Cut"] -state normal
		}
		.gpm_entry_menu entryconfigure [::mc "Copy"] -state normal
	} else {
		.gpm_entry_menu entryconfigure [::mc "Cut"] -state disabled
		.gpm_entry_menu entryconfigure [::mc "Copy"] -state disabled
	}
	.gpm_entry_menu entryconfigure [::mc "Paste"] -state $state
	.gpm_entry_menu entryconfigure [::mc "Clear"] -state $state
}

## Invoke text widget popup menu -- event <ButtonRelease-3>
 # @parm Int X		- absolute X coordinate
 # @parm Int Y		- absolute Y coordinate
 # @parm Int x		- relative X coordinate
 # @parm Int y		- relative Y coordinate
 # @parm Widget Widget	- Text widget
 # @return void
proc GPM_text_popup {X Y x y Widget} {
	global GPM_text_widget

	set GPM_text_widget $Widget
	GPM_text_menu_disena
	tk_popup .gpm_text_menu $X $Y
}

## Invoke text widget popup menu -- event <Key-Menu>
 # @parm Widget Widget	- Text widget
 # @return void
proc GPM_text_key_menu {Widget} {
	global GPM_text_widget

	set GPM_text_widget $Widget
	GPM_text_menu_disena
	$Widget see insert
	set bbox [$Widget bbox [$Widget index insert]]
	tk_popup .gpm_text_menu	\
		[expr {[winfo rootx $Widget] + [lindex $bbox 0] + 10}]	\
		[expr {[winfo rooty $Widget] + [lindex $bbox 1] + 10}]
}

## Enable/Disable popup menu items according to state of the widget
 # For text widgets. Auxiliary procedure for 'GPM_text_popup' and 'GPM_text_key_menu'
 # @return void
proc GPM_text_menu_disena {} {
	global GPM_text_widget

	set state [$GPM_text_widget cget -state]
	if {[llength [$GPM_text_widget tag nextrange sel 1.0]]} {
		if {$state != {disabled}} {
			.gpm_text_menu entryconfigure [::mc "Cut"] -state normal
		}
		.gpm_text_menu entryconfigure [::mc "Copy"] -state normal
	} else {
		.gpm_text_menu entryconfigure [::mc "Cut"] -state disabled
		.gpm_text_menu entryconfigure [::mc "Copy"] -state disabled
	}
	foreach entry {Undo Redo Paste Clear} {
		.gpm_text_menu entryconfigure [::mc $entry] -state $state
	}
}
## Cut selected text -- entry widget
 # @return void
proc GPM_entry_cut {} {
	global GPM_entry_widget

	# Check for widget existence
	if {![winfo exists $GPM_entry_widget]} {return}
	# Check if there is selected text
	if {![$GPM_entry_widget selection present]} {return}

	# Copy selected text to clipboard
	set data [$GPM_entry_widget get]
	set data [string range $data				\
		[$GPM_entry_widget index sel.first]		\
		[expr {[$GPM_entry_widget index sel.last] - 1}]	\
	]
	clipboard clear
	clipboard append $data

	# Remove the selected text
	$GPM_entry_widget delete sel.first sel.last
}

## Copy selected text to clipboard -- entry widget
 # @return void
proc GPM_entry_copy {} {
	global GPM_entry_widget

	# Check for widget existence
	if {![winfo exists $GPM_entry_widget]} {return}
	# Check if there is selected text
	if {![$GPM_entry_widget selection present]} {return}

	# Copy selected text to clipboard
	set data [$GPM_entry_widget get]
	set data [string range $data				\
		[$GPM_entry_widget index sel.first]		\
		[expr {[$GPM_entry_widget index sel.last] - 1}]	\
	]
	clipboard clear
	clipboard append $data
}

## Paste text from clipboard -- entry widget
 # @return void
proc GPM_entry_paste {} {
	global GPM_entry_widget

	# Check for widget existence
	if {![winfo exists $GPM_entry_widget]} {return}
	# Check if clipboard is not empty
	set data [clipboard get]
	if {$data == {}} {return}

	# Paste text from clipboard
	catch {
		$GPM_entry_widget delete sel.first sel.last
	}
	$GPM_entry_widget insert insert $data
}

## Clear all text -- entry widget
 # @return void
proc GPM_entry_clear {} {
	if {![winfo exists $::GPM_entry_widget]} {return}
	$::GPM_entry_widget delete 0 end
}

## Select all text -- entry widget
 # @return void
proc GPM_entry_selall {} {
	if {![winfo exists $::GPM_entry_widget]} {return}
	$::GPM_entry_widget selection range 0 end
}

## Take back last operation -- text widget
 # @return void
proc GPM_text_undo {} {
	catch {
		$::GPM_text_widget edit undo
	}
}

## Take back last undo -- text widget
 # @return void
proc GPM_text_redo {} {
	catch {
		$::GPM_text_widget edit redo
	}
}

## Cut selected text -- text widget
 # @return void
proc GPM_text_cut {} {
	global GPM_text_widget

	# Check for widget existence
	if {![winfo exists $GPM_text_widget]} {return}
	# Check if there is selected text
	if {![llength [$GPM_text_widget tag nextrange sel 1.0]]} {return}

	# Copy selected text to clipboard
	clipboard clear
	clipboard append [$GPM_text_widget get sel.first sel.last]

	# Remove the selected text
	$GPM_text_widget delete sel.first sel.last
}

## Copy selected text to clipboard -- text widget
 # @return void
proc GPM_text_copy {} {
	global GPM_text_widget

	# Check for widget existence
	if {![winfo exists $GPM_text_widget]} {return}
	# Check if there is selected text
	if {![llength [$GPM_text_widget tag nextrange sel 1.0]]} {return}

	# Copy selected text to clipboard
	clipboard clear
	clipboard append [$GPM_text_widget get sel.first sel.last]
}

## Paste text from clipboard -- text widget
 # @return void
proc GPM_text_paste {} {
	global GPM_text_widget

	# Check for widget existence
	if {![winfo exists $GPM_text_widget]} {return}
	# Check if clipboard is not empty
	set data [clipboard get]
	if {$data == {}} {return}

	# Paste text from clipboard
	catch {
		$GPM_text_widget delete sel.first sel.last
	}
	$GPM_text_widget insert insert $data
}

## Clear all text -- text widget
 # @return void
proc GPM_text_clear {} {
	catch {
		$::GPM_text_widget delete 1.0 end
	}
}

## Select all text -- text widget
 # @return void
proc GPM_text_selall {} {
	catch {
		$::GPM_text_widget tag add sel 1.0 end
	}
}

# FINALIZE BASIC ENVIRONMENT INITIALIZATION
# -----------------------------------------
show_hide_main_toolbar					;# Show/Hide Main toolbar
pack [frame .mainFrame] -fill both -expand 1		;# Frame for central widget
::Editor::refresh_available_dictionaries		;# Refresh list of available spell checker dictionaries
makeStatusbar {}					;# Create status bar
::Editor::adjust_spell_checker_config_button		;# Adjust spell checker configuration button to current spell checker configuration
change_validation_level $::CONFIG(VALIDATION_LEVEL)	;# Restore previous validation level
::X::initialize						;# Initialize X NS
::KIFSD::FSD::load_config_array $::CONFIG(KIFSD_CONFIG)	;# Restore configuration of file selection dialog
::HexEditDlg::loadConfig $::CONFIG(HEXEDIT_CONFIG)	;# Restore hexaeditor configuration
::KIFSD::FSD::set_bookmark_change_command {::X::refresh_bookmarks_in_fs_browsers}

# SHOW TIP OF THE DAY
# -----------------------------------------
if {$show_welcome_dialog} {
	set X::critical_procedure_in_progress 0
	X::__welcome_dialog
	set X::critical_procedure_in_progress 1
} elseif {${::GLOBAL_CONFIG(tips)}} {
	X::__tip_of_the_day
}

# Create project notebook
# -----------------------------------------
set ::main_nb [ModernNoteBook .mainFrame.mainNB -autohide 1]

# Project details window
${::main_nb} bindtabs <Enter>		{::X::create_project_details}
${::main_nb} bindtabs <Motion>		{::X::project_details_move}
${::main_nb} bindtabs <Leave>		{::X::close_project_details}
${::main_nb} bindtabs <ButtonRelease-3>	{::X::invoke_project_menu %X %Y}

bind Menu <Map> ::X::remove_all_help_windows

# >>> File inclusion guard
}
# <<< File inclusion guard

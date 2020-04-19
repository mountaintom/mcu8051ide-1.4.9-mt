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
if { ! [ info exists _FSBROWSER_TCL ] } {
set _FSBROWSER_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements file system browser for the left panel
# --------------------------------------------------------------------------

class FSBrowser {

	# Definition of popup menu for file system browser, part: configure
	public common FSMENU_CONFIGURE {
		{cascade	"Sorting"		0	""	.sorting	false 1 {
			{radiobutton	"By Name"	""	{::KIFSD::FSD::config(sorting)}
				{name}	{filelist_fsb_reload} 3
				"Sort files by name"}
			{radiobutton	"By Date"	""	{::KIFSD::FSD::config(sorting)}
				{date}	{filelist_fsb_reload} 3
				"Sort files by date"}
			{radiobutton	"By Size"	""	{::KIFSD::FSD::config(sorting)}
				{size}	{filelist_fsb_reload} 3
				"Sort files by size"}
			{separator}
			{checkbutton	"Reverse"		""
				{::KIFSD::FSD::config(reverse_sorting)}		1 0 0
				{filelist_fsb_reload}	"Decremental sorting"}
			{checkbutton	"Case insensitive"	""
				{::KIFSD::FSD::config(case_insensitive)}	1 0 0
				{filelist_fsb_reload}	"Sorting mode ASCII / Dictionary"}
		}}
		{checkbutton	"Show hidden files"	""
			{::KIFSD::FSD::config(show_hidden_files)}		1 0 5
			{filelist_fsb_reload}		"Show / Ignore files starting with dot"}
	}

	# Definition of popup menu for file system browser, part: listbox
	public common FSMENU_LISTBOX {
		{command	{Up}		{} 0	"filelist_fsb_up"	{up}
			"Go to parent folder"}
		{command	{Back}		{} 0	"filelist_fsb_back"	{left}
			"Go back in history"}
		{command	{Forward}	{} 0	"filelist_fsb_forward"	{right}
			"Go forward in history"}
		{separator}
		{command	{Home}		{} 0	"filelist_fsb_gohome"	{gohome}
			"Go to your home folder"}
		{command	{Reload}	{} 1	"filelist_fsb_reload"	{reload}
			"Reload file list"}
		{separator}
		{command	{Rename}	{} 0	"filelist_fsb_rename"	{edit}
			"Rename file"}
		{command	{Delete}	{} 0	"filelist_fsb_delete"	{editdelete}
			"Delete file"}
		{command	{New folder}	{} 0	"filelist_fsb_new_folder"	{folder_new}
			"Create new directory"}
		{command	{Bookmark folder} {} 0	"filelist_fsb_bookmark_this"	{bookmark_add}
			"Bookmark the current directory"}
		{separator}
		{command	{Properties}	{} 0	"filelist_fsb_properties"	{}
			"Show file properties"}
	}

	# Definition of popup menu for file system browser, part: bookmarks
	public common FSMENU_BOOKMARKS {
		{command	{Add bookmark}		{} 0	"filelist_fsb_add_bookmark"
			{bookmark_add}	"Bookmark the current folder"}
		{command	{Edit bookmarks}	{} 0	"filelist_fsb_edit_bookmarks"
			{bookmark}	"Invoke bookmark editor"}
		{separator}
	}

	## PRIVATE
	private variable fs_browser_selected_item	{}	;# Item selected by popup menu for file system browser
	private variable fs_browser_selection_in_P	0	;# Procedure "filelist_fsb_select" in progress
	private variable fs_browser_listbox_top_frame		;# Top frame of file system browser
	private variable forward_history		{}	;# List of forward history (file system browser)
	private variable back_history			{}	;# List of backward history (file system browser)
	private variable fs_browser_current_dir			;# Current directory (file system browser)
	private variable fs_browser_conf_menu			;# ID of files ystem browser configuration menu
	private variable fs_browser_dir_ok			;# Button: Confirm location
	private variable fs_browser_listbox_menu		;# ID of popup menu for file system browser
	private variable fs_browser_bm_menu			;# ID of bookmarks popup menu (file system browser)
	private variable fs_browser_toolbar			;# ID of file system browser toolbar
	private variable fs_browser_dir				;# ComboBox: Current directory
	private variable fs_browser_listbox			;# ListBox: Files & Directories
	private variable fs_browser_listbox_v_scrollbar		;# Vertical scrollbar for file system browser
	private variable fs_browser_listbox_h_scrollbar		;# Horizontal scrollbar for file system browser
	private variable fs_browser_filter			;# ComboBox: Filter
	private variable item_menu_invoked		0	;# Bool: Item menu request
	 # Current GLOB filter for file system browser
	private variable fs_browser_current_mask	${::CONFIG(FS_BROWSER_MASK)}

	# Variables related to object initialization
	private variable parent
	private variable fsb_gui_initialized	0

	constructor {} {
		# Configure local ttk styles
		ttk::style configure FSBrowser_RedBg.TCombobox		\
			-fieldbackground {#FFDDDD}
		ttk::style map FSBrowser_RedBg.TCombobox		\
			-fieldbackground [list {readonly !readonly} {#FFDDDD}]
	}

	destructor {
	}

	## Prepare object for creating its GUI
	 # @parm Widget _parent	- GUI parent widget
	 # @return void
	public method PrepareFSBrowser {_parent} {
		set parent $_parent
		set fsb_gui_initialized 0
	}

	## Create GUI of tab "File system browser"
	 # @return void
	public method CreateFSBrowserGUI {} {
		if {$fsb_gui_initialized} {return}
		set fsb_gui_initialized 1

		set fs_browser_current_dir [$this cget -projectPath]

		# Toolbar
		set fs_browser_toolbar [frame $parent.toolbar]
		iconBarFactory $fs_browser_toolbar "$this "	\
			[string range $fs_browser_toolbar 1 end] ::ICONS::16:: {
			{up		"Up"			{up}		{filelist_fsb_up}
				"Go to parent folder"}
			{back		"Back"			{left}		{filelist_fsb_back}
				"Back in history"}
			{forward	"Forward"		{right}		{filelist_fsb_forward}
				"Forward in history"}
			{separator}
			{bookmark	"Bookmark"		{bookmark_toolbar} {filelist_fsb_popup_bm_menu}
				"Bookmark menu"}
			{current	"Current document folder" {next}	{filelist_fsb_current_doc_folder}
				"Go to directory containing the current document"}
			{configure	"Configure" 		{configure}	{filelist_fsb_popup_config_menu}
				"File system browser configuration menu"}
		} [namespace current]
		${fs_browser_toolbar}forward configure -state disabled
		${fs_browser_toolbar}back configure -state disabled

		# Directory location bar
		set fs_browser_dir_frame [frame $parent.dir_frame]
		set fs_browser_dir [ttk::combobox $fs_browser_dir_frame.dir		\
			-validatecommand [list $this filelist_fsb_validate_dir %P]	\
			-width 1							\
			-values {}							\
			-validate all							\
		]
		bind $fs_browser_dir <Return> [list $this filelist_fsb_dir_ok]
		bind $fs_browser_dir <KP_Enter> [list $this filelist_fsb_dir_ok]
		bind $fs_browser_dir <<ComboboxSelected>> "$this filelist_fsb_dir_ok"
		DynamicHelp::add $fs_browser_dir -text [mc "Current directory"]
		setStatusTip -widget $fs_browser_dir	\
			-text [mc "Directory location bar"]
		set fs_browser_dir_ok [ttk::button $fs_browser_dir_frame.ok	\
			-style Flat.TButton					\
			-image ::ICONS::16::key_enter				\
			-command [list $this filelist_fsb_dir_ok]		\
		]
		DynamicHelp::add $fs_browser_dir_frame.ok -text [mc "Confirm directory location"]
		setStatusTip -widget $fs_browser_dir_ok	\
			-text [mc "Confirm directory location"]
		pack $fs_browser_dir -fill x -expand 1 -side left
		pack $fs_browser_dir_ok -side right -after $fs_browser_dir

		# ListBox of files and directories
		set fs_browser_listbox_frame [frame $parent.lsbox_frame]
		set fs_browser_listbox_top_frame [frame $fs_browser_listbox_frame.tp_frame]
		set fs_browser_listbox [ListBox $fs_browser_listbox_top_frame.listbox	\
			-bg white -highlightthickness 0 -selectmode single -bd 1	\
			-selectfill 1 -width 0 -height 10 -highlightcolor {#BBBBFF}	\
			-selectbackground {#8888FF} -selectforeground black		\
			-yscrollcommand "$this filelist_fsb_vscroll"			\
			-xscrollcommand "$this filelist_fsb_hscroll"			\
		]
		if {[winfo exists $fs_browser_listbox.c]} {
			bind $fs_browser_listbox.c <Button-5>		{%W yview scroll +5 units; break}
			bind $fs_browser_listbox.c <Button-4>		{%W yview scroll -5 units; break}
			bind $fs_browser_listbox.c <ButtonRelease-3>	\
				[list $this filelist_fsb_popup_listbox_menu %X %Y]
		}
		bind $fs_browser_listbox <<ListboxSelect>> "catch {$this filelist_fsb_select}"
		$fs_browser_listbox bindText	<ButtonRelease-3>	\
			[list $this filelist_fsb_popup_listbox_item_menu %X %Y]
		$fs_browser_listbox bindImage	<ButtonRelease-3>	\
			[list $this filelist_fsb_popup_listbox_item_menu %X %Y]

		# Scrollbars
		set fs_browser_listbox_v_scrollbar [ttk::scrollbar		\
			$fs_browser_listbox_top_frame.scrollbar			\
			-orient vertical -command "$fs_browser_listbox yview"	\
		]
		set fs_browser_listbox_h_scrollbar [ttk::scrollbar		\
			$fs_browser_listbox_frame.scrollbar			\
			-orient horizontal -command "$fs_browser_listbox xview"	\
		]

 		pack $fs_browser_listbox -fill both -expand 1 -side left
		pack $fs_browser_listbox_top_frame -fill both -expand 1

		# GLOB Filter
		set fs_browser_bottom_frame [frame $parent.bottom_frame]
		set fs_browser_filter [ttk::combobox $fs_browser_bottom_frame.filter	\
			-state readonly							\
			-width 0							\
			-font ${::FileList::opened_file_font}				\
			-values {
				{*.asm  - Assembler}
				{*.inc  - INC files}
				{*.c    - C source}
				{*.h    - C header}
				{*.lst  - Code listing}
				{*      - All files}
			}	\
		]
		bind $fs_browser_filter <Return> [list $this filelist_fsb_filter_ok]
		bind $fs_browser_filter <KP_Enter> [list $this filelist_fsb_filter_ok]
		bind $fs_browser_filter <<ComboboxSelected>> [list $this filelist_fsb_filter_ok]
		DynamicHelp::add $fs_browser_filter -text [mc "Filter"]
		setStatusTip -widget $fs_browser_filter	\
			-text [mc "File filter"]
		set val [lsearch -exact -ascii {{*.asm} {*.inc} {*.c} {*.h} {*}} $fs_browser_current_mask]
		if {$val == -1} {
			set val 0
		}
		$fs_browser_filter current $val
		pack $fs_browser_filter -fill x -expand 1 -side left

		# Pack componets of file system browser
		pack $fs_browser_toolbar -anchor w
		pack $fs_browser_dir_frame -fill x -pady 3
		pack $fs_browser_listbox_frame -fill both -expand 1
		pack $fs_browser_bottom_frame -fill x -pady 3

		# Create popup menus
 		set fs_browser_conf_menu	$parent.conf_menu
		set fs_browser_listbox_menu	$parent.listbox_menu
		set fs_browser_bm_menu		$parent.bm_menu
		filelist_fsb_makePopupMenu

		# Initialize file system browser
		filelist_fsb_change_dir $fs_browser_current_dir
		filelist_fsb_refresh_bookmarks
	}

	## Popup bookmarks menu for file system browser
	 # @return void
	public method filelist_fsb_popup_bm_menu {} {
		set x [winfo rootx ${fs_browser_toolbar}bookmark]
		set y [winfo rooty ${fs_browser_toolbar}bookmark]
		incr y [winfo height ${fs_browser_toolbar}bookmark]

		tk_popup $fs_browser_bm_menu $x $y
	}

	## Popup configuration menu for file system browser
	 # @return void
	public method filelist_fsb_popup_config_menu {} {
		set x [winfo rootx ${fs_browser_toolbar}configure]
		set y [winfo rooty ${fs_browser_toolbar}configure]
		incr y [winfo height ${fs_browser_toolbar}configure]

		tk_popup $fs_browser_conf_menu $x $y
	}

	## Popup file system browser listbox menu
	 # @parm Int x - Relative horizontal position of mouse pointer
	 # @parm Int y - Relative vertical position of mouse pointer
	 # @return void
	public method filelist_fsb_popup_listbox_menu {x y} {
		# If item menu was invoked then abort
		if {$item_menu_invoked} {
			set item_menu_invoked 0
			return
		}

		# Configure and popup the menu
		set fs_browser_selected_item {}
		foreach entry {Rename Delete Properties} {
			$fs_browser_listbox_menu entryconfigure [::mc $entry] -state disabled
		}
		tk_popup $fs_browser_listbox_menu $x $y
	}

	## Popup file system browser listbox menu
	 # @parm Int x		- Relative horizontal position of mouse pointer
	 # @parm Int y		- Relative vertical position of mouse pointer
	 # @parm String item	- Selected item (file of directory)
	 # @return void
	public method filelist_fsb_popup_listbox_item_menu {x y item} {
		if {[$fs_browser_listbox itemcget $item -text] == {..}} {
			return
		}

		# Configure and popup the menu
		set item_menu_invoked 1
		foreach entry {Rename Delete Properties} {
			$fs_browser_listbox_menu entryconfigure [::mc $entry] -state normal
		}
		set fs_browser_selected_item $item
		tk_popup $fs_browser_listbox_menu $x $y
	}

	## Change current directory in file system browser
	 # @parm String dir - New directory location
	 # @return void
	public method filelist_fsb_change_dir {dir} {
		if {!$fsb_gui_initialized} {CreateFSBrowserGUI}

		if {$::MICROSOFT_WINDOWS} {
			# Transform for instance "C:" to "C:/"
			if {[regexp {^\w+:$} $dir]} {
				append dir {/}
			}
		}

		# Check if the given directory is valid
		if {![file exists $dir] || ![file isdirectory $dir]} {
			tk_messageBox
				-parent .			\
				-title [mc "Invalid directory"]	\
				-type ok			\
				-icon warning			\
				-message [mc "The specified directory does not exist:\n%s" $dir]
			return
		}

		# Normalize path and configure toolbar (history controll)
		set dir [file normalize $dir]
		if {$dir != $fs_browser_current_dir} {
			lappend back_history $fs_browser_current_dir
			set forward_history {}
			$fs_browser_listbox_menu entryconfigure [::mc "Forward"] -state disabled
			$fs_browser_listbox_menu entryconfigure [::mc "Back"] -state normal
			${fs_browser_toolbar}forward configure -state disabled
			${fs_browser_toolbar}back configure -state normal
		}
		set fs_browser_current_dir $dir

		# Reload contents of browser ListBox
		set tmp ${::KIFSD::FSD::config(detailed_view)}
		set ::KIFSD::FSD::config(detailed_view) 0
		$fs_browser_listbox delete [$fs_browser_listbox items]
		foreach file [::KIFSD::FSD::dir_file_cmd $dir $fs_browser_current_mask] {

			# Local variables
			set filename	{}			;# File name (if $file file)
			set folder	{}			;# Directory name (if $file is directory)
			set fullname	[lindex $file 0]	;# Full path
			set text	$fullname		;# Text to display

			# Determinate icon
			switch -- [lindex $file 1] {
				u	{ ;# Parent directory
					set image {up}
					set folder {..}
				}
				d	{ ;# Directory
					set image {fileopen}
					set folder $fullname
				}
				f	{ ;# File
					set image {ascii}
					set filename $fullname
				}
			}

			# Insert item into the listbox
			$fs_browser_listbox insert end #auto	\
				-text $text			\
				-image ::ICONS::16::$image	\
				-data [list $filename $folder]
		}
		set ::KIFSD::FSD::config(detailed_view) $tmp

		# Configure button "Up"
		if {$dir == [file separator]} {
			$fs_browser_listbox_menu entryconfigure [::mc "Up"] -state disabled
			${fs_browser_toolbar}up configure -state disabled
		} else {
			$fs_browser_listbox_menu entryconfigure [::mc "Up"] -state normal
			${fs_browser_toolbar}up configure -state normal
		}

		# Fill directory location combobox
		set values {}
		set folder $dir
		while {1} {
			lappend values $folder
			if {$folder == [file separator]} {break}
			if {$::MICROSOFT_WINDOWS} {
				if {[regexp {^\w+:[\\\/]?$} $folder]} {break}
			}
			set folder [file normalize [file join $folder {..}]]
		}
		foreach folder [::KIFSD::FSD::dir_cmd $dir 1] {
			if {$folder == {..}} {continue}
			lappend values [file join $dir $folder]
		}
		if {$::MICROSOFT_WINDOWS} { ;# Include drive letters on Microsoft Windows
			foreach drive_letter {A B C D E F G H I J K L M N O P Q R S T U V W X Y Z} {
				if {[file exists "${drive_letter}:/"]} {
					lappend values "${drive_letter}:/"
				}
			}
		}

		$fs_browser_dir configure -values $values
		$fs_browser_dir current 0
		$fs_browser_dir icursor end
		catch {
			$fs_browser_dir.e xview end
		}
	}

	## Select file/directory to open
	 # This method should be connected to <<Selection>> event on FS browser ListBox
	 # @return void
	public method filelist_fsb_select {} {
		if {[$this is_frozen]} {
			tk_messageBox		\
				-parent .	\
				-icon info	\
				-type ok	\
				-title [mc "Unable to comply"]	\
				-message [mc "Unable to open source file while simulator is engaged."]
			return
		}

		if {$fs_browser_selection_in_P} {return}
		set fs_browser_selection_in_P 1

		# Determinate name of file/directory to open
		set file [$fs_browser_listbox itemcget	\
			[$fs_browser_listbox selection get] -data]

		# Open file
		if {[lindex $file 0] != {}} {
			set simplename $file
			set file [file join $fs_browser_current_dir [lindex $file 0]]

			# Check if the file seems to be valid source code
			if {![regexp {\.(asm|inc|c|h|cpp|cc|cxx|lst)$} $file] || ([file size $file] > 1048576)} {
				set response [tk_messageBox	\
					-parent . -type yesno	\
					-icon warning		\
					-title [mc "Open file %s" $simplename]	\
					-message [mc "This file does not look like a source code.\nDo you really want to open it ?"] \
				]
				if {$response != {yes}} {
					set fs_browser_selection_in_P 0
					return
				}
			}

			# Perform opening procedure
			if {[$this openfile $file 1 . def def 0 0 {}] != {}} {
				$this switch_to_last
				update
				$this editor_procedure {} parseAll {}

				# Make LST read only
				if {[file extension $file] == {.lst}} {
					set ::editor_RO_MODE 1
					$this switch_editor_RO_MODE
				}

				::X::recent_files_add 1 $file
			}

		# Open directory
		} else {
			filelist_fsb_change_dir	\
				[file join $fs_browser_current_dir [lindex $file 1]]
		}
		set fs_browser_selection_in_P 0
		update
	}

	## Invoke dialog to edit FS browser bookmarks
	 # @return void
	public method filelist_fsb_edit_bookmarks {} {
		catch {delete object fsd}
		KIFSD::FSD fsd
		fsd edit_bookmarks
		delete object fsd
	}

	## Synchronize bookmarks in FS browser with KIFSD (KI File selection dialog)
	 # This method shoul be called after FSD close
	 # @return void
	public method filelist_fsb_refresh_bookmarks {} {
		if {!$fsb_gui_initialized} {CreateFSBrowserGUI}

		# Clear current bookmarks entries
		if {[$fs_browser_bm_menu index end] > 2} {
			$fs_browser_bm_menu delete 3 end
		}
		# Create new bookmark entries
		foreach dir ${::KIFSD::FSD::config(bookmarks)} {
			$fs_browser_bm_menu add command			\
				-label $dir -compound left		\
				-image ::ICONS::16::fileopen		\
				-command "$this filelist_fsb_change_dir {$dir}"
		}
	}

	## Bookmark current directory
	 # @return void
	public method filelist_fsb_add_bookmark {} {
		lappend ::KIFSD::FSD::config(bookmarks) $fs_browser_current_dir
		$fs_browser_bm_menu add command					\
			-label $fs_browser_current_dir -compound left		\
			-image ::ICONS::16::fileopen				\
			-command "$this filelist_fsb_change_dir {$fs_browser_current_dir}"
	}

	## Bookmark directory selected by popup menu
	 # @return void
	public method filelist_fsb_bookmark_this {} {
		# No item selected -> bookmark current directory
		if {$fs_browser_selected_item == {}} {
			filelist_fsb_add_bookmark
			return
		}

		# Directory selected -> bookmark it
		if {[lindex [$fs_browser_listbox itemcget $fs_browser_selected_item -data] 1] != {}} {
			set tmp $fs_browser_current_dir
			set fs_browser_current_dir [file join $fs_browser_current_dir	\
				[$fs_browser_listbox itemcget $fs_browser_selected_item -text]]
			filelist_fsb_add_bookmark
			set fs_browser_current_dir $tmp

		# File selected -> bookmark current directory
		} else {
			filelist_fsb_add_bookmark
		}
	}

	## Reload file system browser contents
	 # @return void
	public method filelist_fsb_reload {} {
		if {!$fsb_gui_initialized} {CreateFSBrowserGUI}
		filelist_fsb_change_dir $fs_browser_current_dir
	}

	## Go to parent directory (in FS browser)
	 # @return void
	public method filelist_fsb_up {} {
		filelist_fsb_change_dir [file join $fs_browser_current_dir {..}]
	}

	## Go back in history (in FS browser)
	 # @return void
	public method filelist_fsb_back {} {
		# Gain new directory location
		set folder [lindex $back_history end]
		if {$folder == {}} {return}

		# Adjust back and forward history
		set back_history [lreplace $back_history end end]
		lappend forward_history $fs_browser_current_dir

		# Make backup for history lists
		set tmp_forw_hist $forward_history
		set tmp_back_hist $back_history

		# Change current directory (go back in history)
		filelist_fsb_change_dir $folder

		# Restore history lists
		set forward_history $tmp_forw_hist
		set back_history $tmp_back_hist

		# Configure toolbar and popup menu
		if {![llength $back_history]} {
			${fs_browser_toolbar}back configure -state disabled
			$fs_browser_listbox_menu entryconfigure [::mc "Back"] -state disabled
		} else {
			${fs_browser_toolbar}back configure -state normal
			$fs_browser_listbox_menu entryconfigure [::mc "Back"] -state normal
		}
		$fs_browser_listbox_menu entryconfigure [::mc "Forward"] -state normal
		${fs_browser_toolbar}forward configure -state normal
	}

	## Go forward in history (in FS browser)
	 # @return void
	public method filelist_fsb_forward {} {
		# Gain new directory location
		set folder [lindex $forward_history end]
		if {$folder == {}} {return}

		# Adjust forward and back history
		set forward_history [lreplace $forward_history end end]
		lappend back_history $fs_browser_current_dir

		# Make backup for history lists
		set tmp_forw_hist $forward_history
		set tmp_back_hist $back_history

		# Change current directory (go forward in history)
		filelist_fsb_change_dir $folder

		# Restore history lists
		set forward_history $tmp_forw_hist
		set back_history $tmp_back_hist

		# Configure toolbar and popup menu
		if {![llength $forward_history]} {
			${fs_browser_toolbar}forward configure -state disabled
			$fs_browser_listbox_menu entryconfigure [::mc "Forward"] -state disabled
		} else {
			${fs_browser_toolbar}forward configure -state normal
			$fs_browser_listbox_menu entryconfigure [::mc "Forward"] -state normal
		}
		${fs_browser_toolbar}back configure -state normal
		$fs_browser_listbox_menu entryconfigure [::mc "Back"] -state normal
	}

	## Change current directory to the current document folder
	 # @return void
	public method filelist_fsb_current_doc_folder {} {
		# Determinate path to current document
		set file [$this editor_procedure {} getFileName {}]
		if {[lindex $file 0] != {}} {
			set dir [lindex $file 0]
		} else {
			set dir $projectPath
		}
		# Change current directory
		filelist_fsb_change_dir $dir
	}

	## Rename selected file
	 # @return void
	public method filelist_fsb_rename {} {
		# Determina original and new name
		set original [$fs_browser_listbox itemcget $fs_browser_selected_item -text]
		set newname [$fs_browser_listbox edit $fs_browser_selected_item	\
			[$fs_browser_listbox itemcget $fs_browser_selected_item -text]]
		if {$newname == {}} {
			return
		}

		# Normalize file names (original and new)
		set original [file join $fs_browser_current_dir $original]
		set newname [file join $fs_browser_current_dir $newname]

		# Rename file/directory
		if {[catch {file rename -force $original $newname}]} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Permission denied"]	\
				-message [mc "Unable to rename file:\n%s" $original]
		}

		# Refresh browser
		filelist_fsb_reload
	}

	## Delete selected file/directory
	 # @return void
	public method filelist_fsb_delete {} {
		set filename [$fs_browser_listbox itemcget $fs_browser_selected_item -text]

		if {[tk_messageBox		\
			-parent .		\
			-type yesno		\
			-icon question		\
			-title [mc "Delete file"]	\
			-message [mc "Do you really want to delete file:\n%s" $filename]]
				==
			{yes}
		} then {
			if {[catch {file delete -force -- [file join $fs_browser_current_dir $filename]}]} {
				tk_messageBox		\
					-parent .	\
					-type ok	\
					-icon warning	\
					-title [mc "Permission denied"]	\
					-message [mc "Unable to remove file:\n%s" $filename]
			}
		}
		filelist_fsb_reload
	}

	## Invoke dialog: "Create new directory" (FS browser)
	 # @return void
	public method filelist_fsb_new_folder {} {
		# Create dialog window
		set dialog [toplevel .new_dir_dialog -class {New folder} -bg ${::COMMON_BG_COLOR}]

		# Create header
		pack [label $dialog.header	\
			-justify left		\
			-text [mc "Create new folder in:\n%s" $fs_browser_current_dir]	\
		] -side top -anchor w -padx 15 -pady 5
		# Create EntryBox for name of new folder
		pack [ttk::entry $dialog.entry] -side top -fill x -expand 1 -padx 5 -pady 5

		# Create bottom button bar
		set button_frame [frame $dialog.bottom]
		# - Button: Clear
		pack [ttk::button $button_frame.clear	\
			-text [mc "Clear"]		\
			-compound left			\
			-image ::ICONS::16::clear_left	\
			-command "$dialog.entry delete 0 end"
		] -side left -expand 0
		# - Button: OK
		pack [ttk::button $button_frame.ok		\
			-text [mc "Ok"]				\
			-compound left				\
			-image ::ICONS::16::ok			\
			-command [list $this create_new_folder]	\
		] -side left -expand 0
		# - Button: Cancel
		pack [ttk::button $button_frame.cancel				\
			-text [mc "Cancel"]					\
			-compound left						\
			-image ::ICONS::16::button_cancel			\
			-command "grab release $dialog; destroy $dialog"	\
		] -side left -expand 0
		# Pack button frame
		pack $button_frame -side bottom -anchor e -expand 0 -padx 5 -pady 5

		# Configure dialog window
		wm iconphoto $dialog ::ICONS::16::folder_new
		wm title $dialog [mc "New folder"]
		wm resizable $dialog 1 0
		wm minsize $dialog 340 120
		wm geometry $dialog 340x120
		wm protocol $dialog WM_DELETE_WINDOW "
			grab release $dialog
			destroy $dialog
		"
		wm transient $dialog .
		grab $dialog
		raise $dialog
		focus -force $dialog.entry
		tkwait window $dialog
	}

	## Create new directory (in FS browser)
	 # @return void
	public method create_new_folder {} {
		# Local variables
		set dialog .new_dir_dialog	;# ID of dialog window
		set folder [$dialog.entry get]	;# Name of folder to create
		set error 0			;# Bool: error occurred

		# Check for folder name validity
		if {$folder == {}} {
			set error 1
		}

		# Create new folder
		if {$error || [catch {file mkdir [file join $fs_browser_current_dir $folder]}]} {
			tk_messageBox						\
				-parent $dialog					\
				-icon warning					\
				-type ok					\
				-title [mc "Unable to create folder"]		\
				-message [mc "Unable to create the specified folder"]
		} else {
			# Remove dialog and reload browser
			grab release $dialog
			destroy $dialog
			filelist_fsb_reload
		}
	}

	## Invoke dialog: "File/Directory properties" (in FS browser)
	 # @return void
	public method filelist_fsb_properties {} {
		## Determinate item properties
		 # - filename
		 # - full path
		 # - size
		 # - permissions
		 # - owner + group
		 # - modification time
		 # - access time
		set name [$fs_browser_listbox itemcget $fs_browser_selected_item -data]
		if {[lindex $name 0] == {}} {
			set name [lindex $name 1]
			set type [mc "Directory"]
		} else {
			set name [lindex $name 0]
			set type [mc "File"]
		}
		set fullname [file join $fs_browser_current_dir $name]
		if {![file exists $fullname]} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "Unknown Error"]	\
				-message [mc "This file apparently does not exist"]
			return
		}
		set size [file size $fullname]
		append size { B}
		set modified [clock format [file mtime $fullname] -format {%D %R}]
		set accessed [clock format [file atime $fullname] -format {%D %R}]
		if {!$::MICROSOFT_WINDOWS} { ;# Microsoft Windows has no file rights (compatible with posix rights)
			set perms [file attributes $fullname]
			set group [lindex $perms 1]
			set owner [lindex $perms 3]
			set perms [lindex $perms 5]
			set perms [string range $perms {end-3} end]
			foreach var	{ur	uw	ux	gr	gw	gx	or	ow	ox} \
				mask	{0400	0200	0100	040	020	010	04	02	01} \
			{
				set ::KIFSD::FSD::item_properties($var) [expr {($perms & $mask) > 0}]
			}
		}


		# Create dialog window componets
		set dialog		[toplevel .properties_dialog -class {File properties} -bg ${::COMMON_BG_COLOR}]	;# Toplevel window itself
		set nb			[ModernNoteBook $dialog.nb]	;# NoteBook
		set bottom_frame	[frame $dialog.bottom_frame]	;# Button frame

		# Create tabs in NoteBook
		$nb insert end general -text [mc "General"]
		if {!$::MICROSOFT_WINDOWS} { ;# Microsoft Windows has no file rights (compatible with posix rights)
			$nb insert end permission -text [mc "Permissions"]
		}
		$nb raise general

		#
		## Create componets of tab "GENERAL"
		#
		set frame [frame [$nb getframe general].frame]
		pack $frame -side top -anchor n -fill x -expand 1
		set row 0
		grid [label $frame.lbl_$row	\
			-text [mc "Name:"] -anchor w	\
		] -column 0 -row $row -sticky w -pady 3
		set ::KIFSD::FSD::item_properties(name) $name
		grid [ttk::entry $frame.val_lbl_$row						\
			-validate all								\
			-textvariable ::KIFSD::FSD::item_properties(name)			\
			-validatecommand "::KIFSD::FSD::not_empty_entry_validator %W %P"	\
		] -column 1 -row $row -sticky w -pady 3
		incr row
		foreach	lbl {Type Location Size Modified Accessed}	\
			value [list $type $fs_browser_current_dir $size $modified $accessed]	\
		{
			grid [label $frame.lbl_$row		\
				-text "$lbl:" -anchor w		\
			] -column 0 -row $row -sticky w -pady 3
			grid [label $frame.val_lbl_$row		\
				-text $value -anchor w		\
			] -column 1 -row $row -sticky w -pady 3
			incr row
		}
		grid columnconfigure $frame 0 -minsize 100

		#
		## Create componets of tab "PERMISSIONS"
		#
		if {!$::MICROSOFT_WINDOWS} { ;# Microsoft Windows has no file rights (compatible with posix rights)
			set frame [$nb getframe permission]
			set ap_frame [ttk::labelframe $frame.ap_frame	\
				-text [mc "Access permissions"]		\
			]
			set i 0
			foreach	text {Class Read Write Exec Owner Group Others}	\
				row {0 0 0 0 1 2 3}	\
				col {0 1 2 3 0 0 0}	\
			{
				grid [label $ap_frame.lbl_$i	\
					-text $text -justify center		\
				] -row $row -column $col -sticky w -padx 4 -pady 4
				incr i
			}
			foreach	var {ur uw ux gr gw gx or ow ox}	\
				row {1 1 1 2 2 2 3 3 3}	\
				col {1 2 3 1 2 3 1 2 3}	\
			{
				grid [checkbutton $ap_frame.check_$i	\
					-variable ::KIFSD::FSD::item_properties($var)
				] -row $row -column $col
				incr i
			}

			grid columnconfigure $ap_frame 0 -minsize 70
			grid columnconfigure $ap_frame 0 -weight 1
			pack $ap_frame -side top -fill x -expand 1 -padx 5 -pady 5 -anchor nw

			set own_frame [ttk::labelframe $frame.own_frame	\
				-text [mc "Ownership"]			\
			]
			grid [label $own_frame.owner_lbl	\
				-text [mc "Owner"]		\
			] -row 0 -column 0 -padx 10 -pady 3 -sticky w
			grid [label $own_frame.owner_val_lbl	\
				-text $owner -anchor w		\
			] -row 0 -column 1 -padx 10 -pady 3 -sticky we
			grid [label $own_frame.group_lbl	\
				-text [mc "Group"]		\
			] -row 1 -column 0 -padx 10 -pady 3 -sticky w
			grid [label $own_frame.group_val_lbl	\
				-text $group -anchor w		\
			] -row 1 -column 1 -padx 10 -pady 3 -sticky we
			grid columnconfigure $own_frame 0 -minsize 70
			grid columnconfigure $own_frame 1 -weight 1
			pack $own_frame -side top -fill x -expand 1 -padx 5 -pady 5
		}

		#
		## Create componets of bottom frame
		#
		pack [ttk::button $bottom_frame.ok				\
			-text [mc "Ok"]						\
			-compound left						\
			-image ::ICONS::16::ok					\
			-command "$this properties_ok $dialog $fullname"	\
		] -side left
		pack [ttk::button $bottom_frame.cancel		\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command "
				grab release $dialog
				destroy $dialog"		\
		]

		# Pack NoteBook and bottom frame
		pack [$nb get_nb] -fill both -expand 1 -padx 10 -pady 5
		pack $bottom_frame -anchor e -after [$nb get_nb] -padx 10 -pady 5

		# Configure dialog window
		wm title $dialog [mc "Item properties"]
		wm minsize $dialog 280 320
		wm protocol $dialog WM_DELETE_WINDOW "
			grab release $dialog
			destroy $dialog"
		wm transient $dialog .
		grab $dialog
		raise $dialog
		tkwait window $dialog
	}

	## Binding to OK button in item properties dialog
	 # @parm String dialog	- ID of dialog toplevel window
	 # @parm String file	- Name of file related to the dialog
	 # @return void
	public method properties_ok {dialog file} {
		set error 0

		# Determinate permissions (in decimal)
		if {!$::MICROSOFT_WINDOWS} { ;# Microsoft Windows has no file rights (compatible with posix rights)
			set perm 0
			foreach	var {ur uw ux gr gw gx or ow ox} \
				val {256 128 64 32 16 8 4 2 1} {
				if {$::KIFSD::FSD::item_properties($var)} {
					incr perm $val
				}
			}
			# Change permissions
			if {[catch {file attributes $file -permissions "0[format {%o} $perm]"}]} {
				set error 1
				tk_messageBox				\
					-type ok			\
					-icon warning			\
					-parent $dialog			\
					-title [mc "Permission denied"]	\
					-message [mc "Unable to change permissions for file:\n%s" [file tail $file]]
			}
		}
		set dir [file dirname $file]

		# Set new file name
		if {${::KIFSD::FSD::item_properties(name)} != [file tail $file]} {
			if {[catch {
				file rename -force --		\
					$file [file join $dir	\
						${::KIFSD::FSD::item_properties(name)}]}]
			} then {
				set error 1
				tk_messageBox				\
					-type ok			\
					-icon warning			\
					-parent $dialog			\
					-title [mc "Permission denied"]	\
					-message [mc "Unable to rename file:\n%s\n\t=>\n%s" [file tail $file] ${::KIFSD::FSD::item_properties(name)}]
			}
			filelist_fsb_reload
		}

		# If no error occurred, close dialog
		if {!$error} {
			grab release $dialog
			destroy $dialog
		}
	}

	## Go to home directory
	 # @return void
	public method filelist_fsb_gohome {} {
		filelist_fsb_change_dir {~}
	}

	## Confirm new filter settings
	 # @return void
	public method filelist_fsb_filter_ok {} {
		set fs_browser_current_mask [$fs_browser_filter current]
		switch -- $fs_browser_current_mask {
			0 {set fs_browser_current_mask {*.asm}}
			1 {set fs_browser_current_mask {*.inc}}
			2 {set fs_browser_current_mask {*.c}}
			3 {set fs_browser_current_mask {*.h}}
			4 {set fs_browser_current_mask {*.lst}}
			5 {set fs_browser_current_mask {*}}
		}
		filelist_fsb_reload
	}

	## Validate content of directory location ComboBox
	 # @parm String content - Directory to validate
	 # @return Bool - always true
	public method filelist_fsb_validate_dir {content} {
		if {[file exists $content] && [file isdirectory $content]} {
			$fs_browser_dir_ok configure -state normal
			$fs_browser_dir configure -style TCombobox

			# Fill directory location combobox
			set folder $content
			set values {}
			while {1} {
				lappend values $folder
				if {$folder == [file separator]} {break}
				if {$::MICROSOFT_WINDOWS} {
					if {[regexp {^\w+:[\\\/]?$} $folder]} {break}
				}
				set folder [file normalize [file join $folder {..}]]
			}
			foreach folder [::KIFSD::FSD::dir_cmd $content 1] {
				if {$folder == {..}} {continue}
				lappend values [file join $content $folder]
			}
			if {$::MICROSOFT_WINDOWS} { ;# Include drive letters on Microsoft Windows
				foreach drive_letter {A B C D E F G H I J K L M N O P Q R S T U V W X Y Z} {
					if {[file exists "${drive_letter}:/"]} {
						lappend values "${drive_letter}:/"
					}
				}
			}
			$fs_browser_dir configure -values $values
		} else {
			$fs_browser_dir_ok configure -state disabled
			$fs_browser_dir configure -style FSBrowser_RedBg.TCombobox
		}

		return 1
	}

	## Confirm directory location in ComboBox
	 # @return void
	public method filelist_fsb_dir_ok {} {
		filelist_fsb_change_dir [$fs_browser_dir get]
	}

	## Verticaly scroll File System browser ListBox
	 # @parm Float frac0 - Fraction of top visible area
	 # @parm Float frac1 - Fraction of bottom visible area
	 # @return void
	public method filelist_fsb_vscroll {frac0 frac1} {
		# All content is in visible area -> unmap scrollbar
		if {$frac0 == 0 && $frac1 == 1} {
			if {[winfo ismapped $fs_browser_listbox_v_scrollbar]} {
				pack forget $fs_browser_listbox_v_scrollbar
				update
			}

		# Otherwise -> create scrollbar
		} else {
			if {![winfo ismapped $fs_browser_listbox_v_scrollbar]} {
				pack $fs_browser_listbox_v_scrollbar	\
					-after $fs_browser_listbox	\
					-fill y -expand 1
				update
			}
			$fs_browser_listbox_v_scrollbar set $frac0 $frac1
		}
	}

	## Horizontaly scroll File System browser ListBox
	 # @parm Float frac0 - Fraction of top visible area
	 # @parm Float frac1 - Fraction of bottom visible area
	 # @return void
	public method filelist_fsb_hscroll {frac0 frac1} {
		# All content is in visible area -> unmap scrollbar
		if {$frac0 == 0 && $frac1 == 1} {
			if {[winfo ismapped $fs_browser_listbox_h_scrollbar]} {
				pack forget $fs_browser_listbox_h_scrollbar
				update
			}

		# Otherwise -> create scrollbar
		} else {
			if {![winfo ismapped $fs_browser_listbox_h_scrollbar]} {
				pack $fs_browser_listbox_h_scrollbar		\
					-after $fs_browser_listbox_top_frame	\
					-side bottom -fill x -expand 0
				update
			}
			$fs_browser_listbox_h_scrollbar set $frac0 $frac1
		}
	}

	## Recreate popup menus
	 # @return void
	public method filelist_fsb_makePopupMenu {} {
		if {!$fsb_gui_initialized} {return}
		if {[winfo exists $fs_browser_conf_menu]} {
			destroy $fs_browser_conf_menu
		}
		if {[winfo exists $fs_browser_listbox_menu]} {
			destroy $fs_browser_listbox_menu
		}
		if {[winfo exists $fs_browser_bm_menu]} {
			destroy $fs_browser_bm_menu
		}

		menuFactory $FSMENU_CONFIGURE	$fs_browser_conf_menu		0 "$this " 0 {} [namespace current]
		menuFactory $FSMENU_LISTBOX	$fs_browser_listbox_menu	0 "$this " 0 {} [namespace current]
		menuFactory $FSMENU_BOOKMARKS	$fs_browser_bm_menu		0 "$this " 0 {} [namespace current]

		if {![llength $back_history]} {
			$fs_browser_listbox_menu entryconfigure [::mc "Back"] -state disabled
		}
		if {![llength $forward_history]} {
			$fs_browser_listbox_menu entryconfigure [::mc "Forward"] -state disabled
		}
	}

	## Get current file mask
	 # @return String - Current mask
	public method fs_browser_get_current_mask {} {
		return $fs_browser_current_mask
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

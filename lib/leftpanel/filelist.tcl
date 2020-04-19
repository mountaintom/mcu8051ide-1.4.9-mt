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
if { ! [ info exists _FILELIST_TCL ] } {
set _FILELIST_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides:
#	- List of opened files
#	- List of project files
#	- File system browser
#	- Management of opened files, project files and code editors
# --------------------------------------------------------------------------

# Import nesesary sources
source "${::LIB_DIRNAME}/leftpanel/fsbrowser.tcl"	;# File system browser
source "${::LIB_DIRNAME}/leftpanel/sfrwatches.tcl"	;# SRF Watches

class FileList {
	# Inherit content of some other clases
	inherit RightPanel SFRWatches FSBrowser

	## COMMON
	 # String: Textvariable for dialog "Open with ..."
	public common open_with	${::CONFIG(OPEN_WITH_DLG)}
	public common open_with_cnfr	0	;# Bool: Confirm dialog "Open with ..."
	public common fl_lst_count	0	;# Instances counter
	public common file_indexes	{}	;# List of line indexes (auxiliary variable for opening multiple files)
	public common ac_index_in_fl		;# Index of actual editor filelist
	public common default_encoding	{utf-8}	;# Default encoding
	public common default_eol	{lf}	;# Default EOL
	public common bookmark		0	;# Auxiliary variable for popup menu for Icon Borders
	public common pmenu_cline	0	;# Auxiliary variable for popup menu for Icon Borders
	# Menu items to disable when entering simulator mode
	public common freezable_menu_items {
		{New} {Close} {Close All} {Open}
	}
	# Font for opened file in project files list
	public common opened_file_font	[font create	\
		-weight normal			\
		-slant roman			\
		-size -12			\
		-family $::DEFAULT_FIXED_FONT	\
	]
	# Font for closed file in project files list
	public common closed_file_font	[font create	\
		-weight normal			\
		-slant italic			\
		-size -12			\
		-family $::DEFAULT_FIXED_FONT	\
	]
	# Font for icon borders
	public common icon_border_font	[font create	\
		-weight normal			\
		-slant roman			\
 		-size -12			\
 		-family $::DEFAULT_FIXED_FONT	\
	]

	public common filelist			{}	;# List of files to open
	public common open_files_cur_file	{}	;# Name of file currently being opened
	public common open_files_progress	0	;# True if opening files in progress
	public common open_files_abort		0	;# Abort variable for open files ProgressDialog
	public common filedetails_visible	0	;# Bool: Is file details window visible
	public common filedetails_after_ID		;# ID of timeout for show window "file details"

	# Definition of popup menu for listbox of opened files
	public common OPENEDFILESMENU {
		{command	{Append to project} {}		0 "filelist_append_to_prj"	{add}
			"Append this file to the current project"}
		{separator}
		{command	{New}		{$edit:new}	0	"editor_new"		{filenew}
			"Create new file and open its editor"}
		{separator}
		{command	{Open}		{$edit:open}	0	"editor_open"		{fileopen}
			"Open an existing file"}
		{separator}
		{command	{Save}		{$edit:save}	0	"editor_save"		{filesave}
			"Save this file"}
		{command	{Save as}	{$edit:save_as}	5	"editor_save_as"	{filesaveas}
			"Save this file under different name"}
		{command	{Save all}	{$edit:save_all} 6	"editor_save_all"	{save_all}
			"Save all file in the list"}
		{separator}
		{command	{Close}		{$edit:close}	0	"editor_close 1 {}"	{fileclose}
			"Close this file"}
		{command	{Close All}	{$edit:close_all} 4	"editor_close_all 1 0"	{cancel}
			"Close all files in the list"}
		{separator}
		{command	{Bookmark}	{}		4	"filelist_o_bookmark"	{bookmark_add}
			"Add/Remove bookmark for this file"}
		{separator}
		{command	{Move up}	{}		5	"filelist_move_up"	{1uparrow}
			"Move this file up in the list"}
		{command	{Move down}	{}		5	"filelist_move_down"	{1downarrow}
			"Move this file down in the list"}
		{command	{Move to top}	{}		8	"filelist_move_top"	{top}
			"Move this file to the top of the list"}
		{command	{Move to bottom} {}		12	"filelist_move_bottom"	{bottom}
			"Move this file to the bottom of the list"}
		{separator}
		{cascade	"Sort items by"		11	"sort_incr"	.sort_by	false 1 {
			{command	{Document Name}		{} 9	"sort_file_list N 1"	{} {}}
			{command	{File URL}		{} 5	"sort_file_list U 1"	{} {}}
			{command	{File Size in B}	{} 5	"sort_file_list S 1"	{} {}}
		}}
		{cascade	"Open with"		6	"fileopen"	.open_with	false 1 {
			{command	{gvim}			{} 1	"filelist_open_with 1 gvim"	{gvim} {}}
			{command	{emacs}			{} 1	"filelist_open_with 1 emacs"	{emacs} {}}
			{command	{kwrite}		{} 0	"filelist_open_with 1 kwrite"	{kwrite} {}}
			{command	{gedit}			{} 0	"filelist_open_with 1 gedit"	{gedit} {}}
			{command	{other}			{} 0	"filelist_open_with 1 other"	{exec} {}}
		}}
		{separator}
		{command	{Hide the panel} {}	0	"filelist_show_hide"	{2leftarrow}
			"Hide this panel"}
	}

	# Definition of popup menu for notebook with opened files
	public common FILETABSPUMENU {
		{command	{Append to project} {}		0 "filelist_append_to_prj"	{add}
			"Append this file to the current project"}
		{separator}
		{command	{Save}		{$edit:save}	0	"editor_save"		{filesave}
			"Save this file"}
		{command	{Save as}	{$edit:save_as}	5	"editor_save_as"	{filesaveas}
			"Save this file under different name"}
		{command	{Save all}	{$edit:save_all} 6	"editor_save_all"	{save_all}
			"Save all file in the list"}
		{separator}
		{command	{Close}		{$edit:close}	0	"editor_close 1 {}"	{fileclose}
			"Close this file"}
		{command	{Close All}	{$edit:close_all} 4	"editor_close_all 1 0"	{cancel}
			"Close all files in the list"}
		{separator}
		{command	{Bookmark}	{}		4	"filelist_o_bookmark"	{bookmark_add}
			"Add/Remove bookmark for this file"}
		{separator}
		{cascade	"Open with"		6	""	.open_with	false 1 {
			{command	{gvim}			{} 1	"filelist_open_with 1 gvim"	{gvim} {}}
			{command	{emacs}			{} 1	"filelist_open_with 1 emacs"	{emacs} {}}
			{command	{kwrite}		{} 0	"filelist_open_with 1 kwrite"	{kwrite} {}}
			{command	{gedit}			{} 0	"filelist_open_with 1 gedit"	{gedit} {}}
			{command	{other}			{} 0	"filelist_open_with 1 other"	{exec} {}}
		}}
	}

	# Definition of popup menu for listbox of project files
	public common PROJECTFILESMENU {
		{command	{Remove file from the project} {} 0 "filelist_remove_file_from_project" {editdelete}
			"Remove this file from the project"}
		{command	{Close file}	{$edit:close} 0	"filelist_project_file_close"
			{fileclose}	"Close this file"}
		{command	{Open file}	{}	0	"filelist_project_file_open"	{fileopen}
			"Open this file"}
		{separator}
		{command	{Bookmark}	{}	4	"filelist_p_bookmark"		{bookmark_add}
			"Add/Remove bookmark for this file"}
		{separator}
		{command	{Move up}	{}	5	"filelist_prj_move_up"		{1uparrow}
			"Move this item up"}
		{command	{Move down}	{}	5	"filelist_prj_move_down"	{1downarrow}
			"Move this item down"}
		{command	{Move to top}	{}	8	"filelist_prj_move_top"		{top}
			"Move this item to the top of the list"}
		{command	{Move to bottom} {}	12	"filelist_prj_move_bottom"	{bottom}
			"Move this item to the bottom of the list"}
		{separator}
		{cascade	"Sort items by"		11	""	.sort_by	false 1 {
			{command	{Document Name}		{} 9	"sort_file_list N 0"	{} {}}
			{command	{File URL}		{} 5	"sort_file_list U 0"	{} {}}
			{command	{File Size in B}	{} 5	"sort_file_list S 0"	{} {}}
		}}
		{cascade	"Open with"		6	""	.open_with	false 1 {
			{command	{gvim}			{} 1	"filelist_open_with 0 gvim"	{gvim} {}}
			{command	{emacs}			{} 1	"filelist_open_with 0 emacs"	{emacs} {}}
			{command	{kwrite}		{} 0	"filelist_open_with 0 kwrite"	{kwrite} {}}
			{command	{gedit}			{} 0	"filelist_open_with 0 gedit"	{gedit} {}}
			{command	{other}			{} 0	"filelist_open_with 0 other"	{exec} {}}
		}}
		{separator}
		{command	{Hide the panel} {}	0	"filelist_show_hide"	{2leftarrow}
			"Hide this panel"}
	}

	# Definition of popup menu icon border for list of of opened files
	public common OPENEDFILESIBMENU {
		{checkbutton	"Bookmark"	""	{::FileList::bookmark}	1 0 0
			{opened_files_bookmark  ${::FileList::pmenu_cline}}}
	}
	# Definition of popup menu icon border for list of of project files
	public common PROJECTFILESIBMENU {
		{checkbutton	"Bookmark"	""	{::FileList::bookmark}	1 0 0
			{project_files_bookmark ${::FileList::pmenu_cline}}}
	}

	## PUBLIC
	public variable actualEditor	0	;# Object number of currently selected editor
	public variable actualEditor2	-2	;# Object number of currently selected editor in the second view
	public variable ProjectDir		;# Reference to directory of actual project
	public variable editors		{}	;# list of editor objects
	public variable iconBorder	$::CONFIG(ICON_BORDER)	;# Bool: display Icon border
	public variable lineNumbers	$::CONFIG(LINE_NUMBERS)	;# Bool: display Line numbers

	## PRIVATE
	# Bool: procedure switchfile will not forget its frame (cleared by procedure switchfile)
	private variable do_not_forget_editor	0
	private variable editor_close_in_progress 0	;# Bool: Indicates than procedure editor_close is in progress
	private variable pwin_orient		{}	;# String multiview orientaion (horizontal or vertical)
	private variable multiview_sash_pos	0	;# Int: position of panedwindow sash for multiview
	private variable selectedView		0	;# Int: 0 == left/top view; 1 == right/bottom view
	private variable splitted		0	;# Bool: Editor is splitted
	private variable main_frame			;# Widget: frame containing $multiview_paned_win or $pagesManager
	private variable untitled_num	-1		;# Number of untitled entries in file list
	private variable leftPanel			;# ID of the left panel
	private variable notebook			;# ID of left panel Notebook
	private variable parent				;# ID of parent container widget
	private variable button_bar			;# ID of show/hide button (for listbox of files)
	private variable lastItem			;# Descriptor of the last selected file
	private variable obj_idx			;# Index of This object
	private variable pagesManager			;# ID of frame for packing editors
	private variable pagesManager2			;# ID of frame for packing editors in second view
	private variable multiview_paned_win		;# ID of paned window for $pagesManager and $pagesManager2
	private variable listbox_opened_files		;# ID of ListBox of currently opened files
	private variable listbox_opened_files_bm	;# ID of icon border for opened files
	private variable opened_files_bookmarks {}	;# List: Bookmarks for opened files
	private variable IB_o_menu			;# ID of popup menu for 'listbox_opened_files_bm'
	private variable listbox_project_files		;# ID of ListBox of currently opened files
	private variable listbox_project_files_bm	;# ID of icon border for project files
	private variable project_files_bookmarks {}	;# List: Bookmarks for project files
	private variable IB_p_menu			;# ID of popup menu for 'listbox_project_files_bm'
	private variable last_sash			;# Last position of the paned window sash
	private variable next_editor_button		;# ID of button "Next editor" -- tab "Opened files"
	private variable prev_editor_button		;# ID of button "Prev editor" -- tab "Opened files"
	private variable opened_files_scrollbar		;# ID of scrollbar for opened files visible
	private variable o_scrollbar_visible	0	;# Bool: Scrollbar for opened files visible
	private variable project_files_scrollbar	;# ID of scrollbar for project files visible
	private variable p_scrollbar_visible	0	;# Bool: Scrollbar for project files visible
	private variable opened_files_menu		;# ID of the popup menu asociated with list of opened files
	private variable project_files_menu		;# ID of the popup menu asociated with list of project files
	private variable filetabs_pu_menu
	private variable frozen			0	;# Bool: Simulator mode flag
	private variable unsaved			;# List of editor objects with positive flag modified
	private variable listbox_opened_files_frame	;# Frame for list of opened files
	private variable listbox_project_files_frame	;# Frame for list of project files
	private variable fs_browser_frame		;# Frame for file system browser
	private variable sfr_watches_frame		;# Frame for SFR watches
	private variable opened_files_buttonBox		;# ID of buttonBox in list of opened files
	private variable project_files_buttonBox	;# ID of buttonBox in list of project files
	private variable listbox_opened_files_top_frame	;# Identifier of button frame above listbox of files

	private variable opened_search_entry			;# ID of search entry for opened files
	private variable opened_search_clear_button		;# ID of button "Clear" on search panel -- opened files
	private variable opened_files_highlighted_item	{}	;# ID of currently highlighted item in opened files
	private variable opened_files_hg_item_fg_clr	{}	;# Fg. color of currently highlighted item in opened files
	private variable project_search_entry			;# ID of search entry for project files
	private variable project_search_clear_button		;# ID of button "Clear" on search panel -- project files
	private variable project_files_highlighted_item	{}	;# ID of currently highlighted item in project files
	private variable project_files_hg_item_fg_clr	{}	;# Fg. color of currently highlighted item in project files
	private variable item_menu_invoked		0	;# Bool: Item menu request
	private variable editor_command_line_on		0	;# Bool: Editor command line visible

	private variable simulator_editor		0	;# Int: Current file number (for simulator)
	private variable file_switching_enabled		1	;# Bool: Automatic file switching enabled
	private variable simulator_editor_obj			;# Object: Code editor used by simulator

	private variable active_page	$::CONFIG(LEFT_PANEL_ACTIVE_PAGE)	;# Active page in the left panel
	private variable PanelVisible	$::CONFIG(LEFT_PANEL)			;# Bool: panel visible
	private variable PanelSize	$::CONFIG(LEFT_PANEL_SIZE)		;# Panel width (in pixels)

	private variable editor_to_freeze_obj		;# Object: Editor to freeze after simulator start-up
	private variable filetabs_frm			;# Widget: Frame contaning the tab bar
	private variable filetabs_nb			;# Widget: Tab bar's notebook widget
	private variable switchfile_in_progress	0	;# Bool: Method switchfile is in progress
	private variable last_selected_item	{}	;# String: ID of the last selected opened file

	## PROTECTED
	protected variable file_count		0	;# counter of opened files
	protected variable editor_wdgs		{}	;# list of editor widgets
	protected variable file_descriptors	{}	;# list of descriptors of opened files
	protected variable file_eol		{}	;# List of EOLs for opened editors
	protected variable file_encoding	{}	;# List of encodings for opened editors
	protected variable file_ro_mode		{}	;# List of read only flags for opened editors
	protected variable file_sh		{}	;# List of syntax highlight id's for opened editors

	## object constructor
	constructor {} {
		# increment instance counter
		incr fl_lst_count
		set obj_idx $fl_lst_count
	}

	## Object destructor
	destructor {
		# Destroy editors
		foreach editor $editors {
			delete object $editor
		}
		# Unregister status bar tips for popup menus
		menu_Sbar_remove $opened_files_menu
		menu_Sbar_remove $project_files_menu
		menu_Sbar_remove $filetabs_pu_menu
	}

	## Initialize GUI components
	 # @parm String parentPane	- Identifier of pane window in which it shoul be packed
	 # @parm String projectDir	- Directory of current project
	 # @parm List filelist		- List of files to open (full filenames including path)
	 # @parm Bool editor_sw_lock	- Enable aoutomatic file switching during simulation
	 # @return void
	public method initalize_FileList {parentPane projectDir FileList editor_sw_lock} {

		# Object variables
		set parent	$parentPane	;# ID of parent container widget
		set ProjectDir	$projectDir	;# Reference to directory of actual project
		set file_switching_enabled $editor_sw_lock

		# Class variables
		set filelist $FileList		;# List of files to open

		# Create notebook frame
		set leftPanel [frame $parentPane.frm_FileList_leftPanel]
		# Create notebook
		set notebook [ModernNoteBook $leftPanel.nb_FileList]
		# Create tab "Hide"
		$notebook insert end "button_SH" -image ::ICONS::16::2leftarrow	\
			-raisecmd [list $this filelist_show_hide]		\
			-helptext [mc "Hide this panel"]
		# Create tab for list of opened files
		set listbox_opened_files_frame	[$notebook insert end "opened_files"	\
			-image ::ICONS::16::fileopen					\
			-raisecmd [list $this Left_panel_set_active_page opened_files]	\
			-helptext [mc "Opened files"]					\
		]
		# Create tab for list of project files
		set listbox_project_files_frame	[$notebook insert end "project_files"	\
			-image ::ICONS::16::project_open				\
			-raisecmd [list $this Left_panel_set_active_page project_files]	\
			-helptext [mc "Files in the project"]				\
		]
		# Create tab for file system browser
		set fs_browser_frame	[$notebook insert end "fs_browser"		\
			-image ::ICONS::16::exec					\
			-raisecmd [list $this Left_panel_set_active_page fs_browser]	\
			-helptext [mc "File system browser"]				\
			-createcmd [list $this CreateFSBrowserGUI]			\
		]
		# Create tab for SFR watches
		set sfr_watches_frame	[$notebook insert end "sfr_watches"		\
			-image ::ICONS::16::kcmmemory					\
			-raisecmd [list $this Left_panel_set_active_page sfr_watches]	\
			-helptext [mc "List of SFR's"]					\
			-createcmd [list $this CreateSFRWatchesGUI]			\
		]

		# Prepare panel componenets but do not create GUI elements
		PrepareFSBrowser $fs_browser_frame
		PrepareSFRWatches $sfr_watches_frame


		# Register notebook status bar tips
		notebook_Sbar_set {filelist} [list				\
			button_SH	[mc "Hide the panel"]			\
			opened_files	[mc "Opened files"]			\
			project_files	[mc "Files of the current project"]	\
			fs_browser	[mc "File system browser"]		\
			sfr_watches	[mc "Special Function Registers"]	\
		]
		$notebook bindtabs <Enter> "notebook_Sbar filelist"
		$notebook bindtabs <Leave> "Sbar {} ;#"

		# Create listbox of opened files
		set lsbox_frame [frame $listbox_opened_files_frame.lsbox_frame]
		set listbox_opened_files_bm [text $lsbox_frame.icon_border	\
			-font $icon_border_font	\
			-width 2		\
			-bd 0			\
			-pady 1			\
			-highlightthickness 0	\
			-bg {#DDDDDD}		\
			-exportselection 0	\
			-takefocus 0		\
			-cursor hand2		\
		]
		$listbox_opened_files_bm tag configure center -justify center
		$listbox_opened_files_bm delete 1.0 end
		setStatusTip -widget $listbox_opened_files_bm	\
			-text [mc "Bookmarks for opened files"]
		set listbox_opened_files [ListBox $lsbox_frame.listbox_opened_files	\
			-selectmode single						\
			-selectfill 0							\
			-bg {#FFFFFF}							\
			-selectbackground {#FFFFFF}					\
			-highlightcolor {#BBBBFF}					\
			-selectforeground {#0000FF}					\
			-bd 1								\
			-highlightthickness 0						\
			-deltay 15							\
			-padx 14							\
			-yscrollcommand "$this filelist_o_scrollbar_set"		\
		]
		setStatusTip -widget $listbox_opened_files	\
			-text [mc "List of opened files"]
		set opened_files_scrollbar [ttk::scrollbar	\
			$lsbox_frame.scrollbar			\
			-orient vertical			\
			-command "$this filelist_o_scroll"	\
		]

		# Create popup menu for icon border
		set IB_o_menu $listbox_opened_files_bm.ib_o_menu
		menuFactory $OPENEDFILESIBMENU $IB_o_menu 0 "$this " 0 {} [namespace current]

		# Create bottom frame
		set listbox_opened_files_bottom_frame [frame $listbox_opened_files_frame.bottom_frame]
		set listbox_opened_files_bottom0_frame [frame $listbox_opened_files_bottom_frame.top]
		set listbox_opened_files_bottom1_frame [frame $listbox_opened_files_bottom_frame.bottom]
		# Create search panel
		set opened_search_entry [ttk::entry $listbox_opened_files_bottom0_frame.entry	\
			-validatecommand "$this filelist_opened_search %P"			\
			-validate all								\
			-width 0								\
		]
		DynamicHelp::add $opened_search_entry -text [mc "Search for file"]
		setStatusTip -widget $opened_search_entry	\
			-text [mc "Search for certain file name in list of opened files"]
		pack $opened_search_entry -side left -fill x -expand 1
		set opened_search_clear_button [ttk::button			\
			$listbox_opened_files_bottom0_frame.clear_button	\
			-command "$opened_search_entry delete 0 end"		\
			-image ::ICONS::16::clear_left				\
			-state disabled						\
			-style Flat.TButton					\
		]
		DynamicHelp::add $listbox_opened_files_bottom0_frame.clear_button -text [mc "Clear search entry box"]
		setStatusTip -widget $opened_search_clear_button	\
			-text [mc "Clear search entry box"]
		pack $opened_search_clear_button -side right -after $opened_search_entry
		# Create buttons "Previous" and "Next"
		set prev_editor_button [ttk::button			\
			$listbox_opened_files_bottom1_frame.prev	\
			-command {::X::__prev_editor}			\
			-image ::ICONS::16::1leftarrow			\
			-style Flat.TButton				\
		]
		DynamicHelp::add $listbox_opened_files_bottom1_frame.prev	\
			-text [mc "Previous editor"]
		pack $prev_editor_button -side left
		setStatusTip -widget $prev_editor_button	\
			-text [mc "Switch to the previous editor"]
		set next_editor_button [ttk::button			\
			$listbox_opened_files_bottom1_frame.next	\
			-command {::X::__next_editor}			\
			-image ::ICONS::16::1rightarrow			\
			-style Flat.TButton				\
		]
		DynamicHelp::add $listbox_opened_files_bottom1_frame.next	\
			-text [mc "Next editor"]
		pack $next_editor_button -side left
		setStatusTip -widget $next_editor_button	\
			-text [mc "Switch to the next editor"]

		# Frame for opened files
		set listbox_opened_files_top_frame [frame \
			$listbox_opened_files_frame.listbox_opened_files_top_frame]
		pack [label $listbox_opened_files_top_frame.listbox_opened_files_label  \
			-text [mc "Opened Files:"] -anchor w     			\
		] -fill x -side top -anchor w -pady 5
		# Button box for "Opened files"
		set opened_files_buttonBox [frame \
			$listbox_opened_files_top_frame.opened_files_buttonBox]
		# Pages managers for editor(s), etc.
		set main_frame [frame $parentPane.main_frame]

		# Create filetabs notebook
		set filetabs_frm [frame $main_frame.filetabs_frm]
		pack [ttk::button $filetabs_frm.add_button	\
			-image ::ICONS::16::filenew		\
			-command {::X::__new}			\
			-style Flat.TButton			\
		] -side left
		set filetabs_nb [ModernNoteBook $filetabs_frm.filetabs_nb -nomanager 1]
		pack [$filetabs_nb get_nb] -fill x -anchor sw -side left -expand 1
		$filetabs_nb bindtabs <Enter>		[list $this file_details_win_create_from_ftnb]
		$filetabs_nb bindtabs <Leave>		[list $this file_details_win_hide]
		$filetabs_nb bindtabs <Motion>		[list $this file_details_win_move]
		$filetabs_nb bindtabs <ButtonRelease-3>	[list $this filetabs_nb_popup_menu %X %Y]
		pack [ttk::button $filetabs_frm.close_button	\
			-image ::ICONS::16::fileclose 		\
			-command {::X::__close}			\
			-style Flat.TButton			\
		] -side right

		set multiview_paned_win [panedwindow	\
			$main_frame.multiview_paned_win	\
			-sashwidth 2			\
			-showhandle 0			\
			-opaqueresize 1			\
			-sashrelief flat		\
		]
		set pagesManager [frame $main_frame.pagesManager]
		set pagesManager2 [frame $main_frame.pagesManager2]

		# Create icon bar for "Opened files"
		iconBarFactory $opened_files_buttonBox "$this "	\
			[string range $opened_files_buttonBox 1 end] ::ICONS::16:: {
			{bookmark	"Bookmark"		{bookmark_add}	{filelist_o_bookmark}
				"Add/Remove bookmark"}
			{separator}
			{up		"Move file up"		{1uparrow}	{filelist_move_up}
				"Move selected file up in the list"}
			{down		"Move file down"	{1downarrow}	{filelist_move_down}
				"Move selected file down in the list"}
			{top		"Move item to top"	{top}		{filelist_move_top}
				"Move selected file to the top of the list"}
			{bottom		"Move item to bottom"	{bottom}	{filelist_move_bottom}
				"Move selected file to the bottom of the list"}
		} [namespace current]

		# Pack GUI components of tab "Opened files"
		pack $opened_files_buttonBox -side left
		pack $listbox_opened_files_top_frame -side top -anchor w
		pack $listbox_opened_files_bottom1_frame -side top
		pack $listbox_opened_files_bottom0_frame -side top -fill x
		pack $listbox_opened_files_bottom_frame -side bottom  -fill x -pady 3
		pack $lsbox_frame -side top -anchor nw -fill both -expand 1
		pack $listbox_opened_files -side right -fill both -expand 1
		pack $listbox_opened_files_bm -before $listbox_opened_files -fill y -side left

		# Create list of project files
		set ls_frame [frame $listbox_project_files_frame.ls_frame]
		set listbox_project_files_bm [text $ls_frame.icon_border	\
			-font $icon_border_font	\
			-width 2		\
			-bd 0			\
			-pady 1			\
			-highlightthickness 0	\
			-bg {#DDDDDD}		\
			-exportselection 0	\
			-takefocus 0		\
			-cursor hand2		\
		]
		$listbox_project_files_bm delete 1.0 end
		$listbox_project_files_bm tag configure center -justify center
		setStatusTip -widget $listbox_project_files_bm	\
			-text [mc "Bookmarks for project files"]
		set listbox_project_files [ListBox $ls_frame.listbox_project_files	\
			-selectmode single						\
			-highlightthickness 0						\
			-bd 1								\
			-padx 0								\
			-selectbackground {#FFFFFF}					\
			-bg {#FFFFFF}							\
			-deltay 15							\
			-selectforeground {#0000FF}					\
			-highlightcolor {#BBBBFF}					\
			-yscrollcommand "$this filelist_p_scrollbar_set"		\
		]
		setStatusTip -widget $listbox_project_files	\
			-text [mc "List of project files"]
		set project_files_scrollbar [ttk::scrollbar	\
			$ls_frame.scrollbar			\
			-orient vertical			\
			-command "$this filelist_p_scroll"	\
		]

		# Create popup menu for icon border
		set IB_p_menu $listbox_project_files.ib_o_menu
		menuFactory $PROJECTFILESIBMENU $IB_p_menu 0 "$this " 0 {} [namespace current]

		# Create search panel
		set search_panel [frame $listbox_project_files_frame.search_panel]
		set project_search_entry [ttk::entry $search_panel.entry	\
			-validatecommand "$this filelist_project_search %P"	\
			-validate all						\
			-width 0						\
		]
		DynamicHelp::add $project_search_entry -text [mc "Search for file"]
		setStatusTip -widget $project_search_entry	\
			-text [mc "Search for certain file name in list of project files"]
		pack $project_search_entry -side left -fill x -expand 1
		set project_search_clear_button [ttk::button		\
			$search_panel.clear_button			\
			-command "$project_search_entry delete 0 end"	\
			-image ::ICONS::16::clear_left			\
			-state disabled					\
			-style Flat.TButton				\
		]
		DynamicHelp::add $search_panel.clear_button	\
			-text [mc "Clear search entry box"]
		setStatusTip -widget $project_search_clear_button	\
			-text [mc "Clear search entry box"]
		pack $project_search_clear_button -side right -after $project_search_entry

		# Create header (label and icon bar) for tab "Project files"
		set topFrame [frame $listbox_project_files_frame.listbox_project_files_top_frame]
		pack [label $topFrame.listbox_project_files_label	\
			-text [mc "Project Files:"] -anchor w		\
		] -fill x -side top -anchor w -pady 5
		set project_files_buttonBox [frame $topFrame.listbox_project_files_buttonBox]
		pack $project_files_buttonBox -side bottom -anchor w -expand 0

		# Create icon bar for tab "Project files"
		iconBarFactory $project_files_buttonBox "$this "	\
			[string range $project_files_buttonBox 1 end] ::ICONS::16:: {
			{bookmark	"Bookmark"				{bookmark_add}
				{filelist_p_bookmark}
				"Add/Remove bookmark"}
			{separator}
			{open		"Open this file"			{fileopen}
				{filelist_project_file_open}
				"Open this file and create its own editor"}
			{close		"Close this file"			{fileclose}
				{filelist_project_file_close}
				"Close this file and close its editor"}
			{separator}
			{remove		"Remove this file from the project"	{editdelete}
				{filelist_remove_file_from_project}
				"Exclude this file from list of files of this project"}
		} [namespace current]

		# Evaluate icon bars button states (tab "Project files")
		FileList_project_disEna_buttons

		# Pack frames of tab "Projet files"
		pack $topFrame -fill x -side top -anchor w
		pack $listbox_project_files -fill both -expand 1 -side right
		pack $listbox_project_files_bm -before $listbox_project_files -fill y -side left
		pack $search_panel -side bottom -fill x
		pack $ls_frame -fill both -expand 1 -side top

		## Create button bar
		set button_bar [frame $leftPanel.button_bar]
		 # Button "Show"
		pack [ttk::button $button_bar.but_show		\
			-image ::ICONS::16::2rightarrow		\
			-command "$this filelist_show_hide"	\
			-style ToolButton.TButton		\
		]
		DynamicHelp::add $button_bar.but_show -text [mc "Show the panel"]
		setStatusTip -widget $button_bar.but_show	\
			-text [mc "Show the panel"]
		 # Separator
		pack [ttk::separator $button_bar.sep -orient horizontal] -fill x -pady 2

		 # Button "Instruction details"
		pack [ttk::button $button_bar.but_opened		\
			-image ::ICONS::16::fileopen			\
			-style ToolButton.TButton			\
			-command "$this filelist_show_up opened_files"	\
		]
		DynamicHelp::add $button_bar.but_opened -text [mc "Currently opened files"]
		setStatusTip -widget $button_bar.but_opened	\
			-text [mc "Currently opened files"]
		 # Button "opened files"
		pack [ttk::button $button_bar.but_proj_open		\
			-image ::ICONS::16::project_open		\
			-style ToolButton.TButton			\
			-command "$this filelist_show_up project_files"	\
		]
		DynamicHelp::add $button_bar.but_proj_open -text [mc "Files in the current project"]
		setStatusTip -widget $button_bar.but_proj_open	\
			-text [mc "Files of the current project"]
		 # Button "File system browser"
		pack [ttk::button $button_bar.but_fs_browser		\
			-image ::ICONS::16::exec			\
			-style ToolButton.TButton			\
			-command "$this filelist_show_up fs_browser"	\
		]
		DynamicHelp::add $button_bar.but_fs_browser -text [mc "File system browser"]
		setStatusTip -widget $button_bar.but_fs_browser	\
			-text [mc "File system browser"]
		 # Button "SFR watches"
		pack [ttk::button $button_bar.but_sfr_watches		\
			-image ::ICONS::16::kcmmemory			\
			-style ToolButton.TButton			\
			-command "$this filelist_show_up sfr_watches"	\
		]
		DynamicHelp::add $button_bar.but_sfr_watches -text [mc "SFR watches"]
		setStatusTip -widget $button_bar.but_sfr_watches	\
			-text [mc "SFR watches"]

		# Show the left panel
		if {$PanelVisible != 0} {
			pack [$notebook get_nb] -expand 1 -fill both -padx 5 -pady 5

			# Raise active page in the panel notebook
			catch {
				$notebook raise $active_page
			}
		} else {
			set last_sash $PanelSize
			pack $button_bar -side top -anchor nw
		}

		# Insert left panel and editor pages manager into parent pane window
		$parentPane add $leftPanel
		$parentPane add $main_frame

		# Set bindings for file lists
		$listbox_opened_files bindText <ButtonRelease-3>	"$this fileList_opened_filelist_item_popup %X %Y"
		$listbox_opened_files bindText <Enter>			"$this file_details_win_create O"
		$listbox_opened_files bindText <Leave>			"$this file_details_win_hide"
		$listbox_opened_files bindText <Motion>			"$this file_details_win_move"
		bind $listbox_opened_files <<ListboxSelect>>		"$this switchfile; break"
		if {[winfo exists $listbox_opened_files.c]} {
			bind $listbox_opened_files.c <Button-5>		{%W yview scroll +5 units; break}
			bind $listbox_opened_files.c <Button-4>		{%W yview scroll -5 units; break}
			bind $listbox_opened_files.c <ButtonRelease-3>	"$this fileList_opened_filelist_popup %X %Y"
		}

		bind $listbox_opened_files_bm <<Selection>>		"false_selection $listbox_opened_files_bm"
		bind $listbox_opened_files_bm <Button-1>		"$this filelist_opened_bookmark_xy %x %y"
		bind $listbox_opened_files_bm <ButtonRelease-3>		"$this filelist_opened_bm_popup_menu %X %Y %x %y"
		bindtags $listbox_opened_files_bm $listbox_opened_files_bm

		$listbox_project_files bindText <ButtonRelease-3>	"$this fileList_project_filelist_item_popup %X %Y"
		$listbox_project_files bindText <Double-Button-1>	"$this filelist_project_file_open"
		$listbox_project_files bindText <Enter>			"$this file_details_win_create P"
		$listbox_project_files bindText <Leave>			"$this file_details_win_hide"
		$listbox_project_files bindText <Motion>		"$this file_details_win_move"
		bind $listbox_project_files <<ListboxSelect>>		"$this project_files_listbox_select"
		if {[winfo exists $listbox_project_files.c]} {
			bind $listbox_project_files.c <Button-5>	{%W yview scroll +5 units; break}
			bind $listbox_project_files.c <Button-4>	{%W yview scroll -5 units; break}
			bind $listbox_project_files.c <ButtonRelease-3>	"$this fileList_project_filelist_popup %X %Y"
		}

		bind $listbox_project_files_bm <<Selection>>		"false_selection $listbox_project_files_bm"
		bind $listbox_project_files_bm <Button-1>		"$this filelist_project_bookmark_xy %x %y"
		bind $listbox_project_files_bm <ButtonRelease-3>	"$this filelist_project_bm_popup_menu %X %Y %x %y"
		bindtags $listbox_project_files_bm $listbox_project_files_bm

		# Create popup menus
		set opened_files_menu	$listbox_opened_files.opened_files_menu
 		set project_files_menu	$listbox_project_files.project_files_menu
 		set filetabs_pu_menu	[$filetabs_nb get_nb].filetabs_pu_menu
 		filelist_makePopupMenu

		# Create Editor object for each file in $filelist and insert it into ListBox of opened files
		open_files $filelist

		# Initialize list of opened files
		set actualEditor	[lindex $filelist {1 0}]
		set actualEditor2	[lindex $filelist {1 1}]
		set multiview_sash_pos	[lindex $filelist {1 2}]
		set pwin_orient		[lindex $filelist {1 3}]

		## Validate index of current editor(s)
		if {
			![string is digit -strict $actualEditor]
				||
			($actualEditor >= [llength $editors])
				||
			($actualEditor < 0)
		} then {
			set actualEditor $actualEditor2
			set splitted 0
		}
		if {
			![string is digit -strict $actualEditor2]
				||
			($actualEditor2 >= [llength $editors])
				||
			($actualEditor2 < 0)
				||
			($actualEditor2 == $actualEditor)
		} then {
			set actualEditor2 -1
			set splitted 0
		} else {
			set splitted 1
		}

		## Validate index of current editor in the first view
		if {
			[string is digit -strict $actualEditor]
				&&
			$actualEditor < [llength $editors]
				&&
			$actualEditor >= 0
		} then {	;# Valid value
			$listbox_opened_files selection set [lindex [$listbox_opened_files items] $actualEditor]
			set actualEditor -1
			switchfile

		} else {	;# Invalid value
			set actualEditor -1
			if {![llength $editors]} {
				editor_new
			} else {
				$listbox_opened_files selection set [lindex [$listbox_opened_files items] 0]
				switchfile
			}
		}

		# Validate selected view, sash orient and sash position
		set selectedView [lindex $filelist {1 4}]
		if {![string is bool -strict $selectedView]} {
			set selectedView 0
		}
		if {$pwin_orient != {horizontal} && $pwin_orient != {vertical}} {
			set pwin_orient {horizontal}
		}
		if {![string is digit -strict $multiview_sash_pos] || $multiview_sash_pos < 0} {
			set multiview_sash_pos 0
		}

		# Pack editor pages manager
		if {$splitted} {
			pack $multiview_paned_win -fill both -expand 1
			$multiview_paned_win configure -orient $pwin_orient
			$multiview_paned_win add $pagesManager
			$multiview_paned_win add $pagesManager2 -after $pagesManager

			if {$pwin_orient == {vertical}} {
				if {!$multiview_sash_pos} {
					set multiview_sash_pos [expr {[winfo height $pagesManager] / 2}]
				}
				set minsize 80
			} else {
				if {!$multiview_sash_pos} {
					set multiview_sash_pos [expr {[winfo width $pagesManager] / 2}]
				}
				set minsize 300
			}
			$multiview_paned_win paneconfigure $pagesManager -minsize $minsize
			$multiview_paned_win paneconfigure $pagesManager2 -minsize $minsize
			pack [[lindex $editors $actualEditor2] cget -ed_sc_frame]	\
				-in $pagesManager2 -fill both -expand 1
		} else {
			pack $pagesManager -fill both -expand 1
		}
		foreach editor $editors {
			$editor configure_statusbar_menu !$splitted $splitted {} {}
		}

		# Set panel width
		update idletasks
		if {$PanelVisible != 0} {
			$parent paneconfigure $leftPanel -minsize 155
			$parent configure -sashwidth 2
			$parent sash place 0 $PanelSize 0
		} else {
			$parent paneconfigure $leftPanel -minsize 0
			$parent configure -sashwidth 0
			$parent sash place 0 25 2
			bind $parent <Button> {break}
		}
		bind $parent <ButtonRelease-1> "$this left_panel_set_size"

		# Update multiview sash position
		if {$splitted} {
			update idletasks
			if {$pwin_orient == {vertical}} {
				$multiview_paned_win sash place 0 0 $multiview_sash_pos
			} else {
				$multiview_paned_win sash place 0 $multiview_sash_pos 0
			}
		}

		show_hide_tab_bar
	}

	## Prepare window file details
	 # @parm Char for	- '0' == ListBox of opened files; 'P' == ListBox of project files
	 # @parm String item	- Item ID
	 # @return void
	public method file_details_win_create {for item} {
		set filedetails_visible 0

		set note {}

		# Determinate full filename
		if {$for == {O}} {
			if {![$listbox_opened_files exists $item]} {
				return
			}
			set shortname	[$listbox_opened_files itemcget $item -text]
			set filename	[$listbox_opened_files itemcget $item -data]
			set index	[$listbox_opened_files index $item]
			set encoding	[lindex $file_encoding	$index]
			set eol		[lindex $file_eol	$index]
			set read_only	[lindex $file_ro_mode	$index]
			regexp -line -- {^.*$} [$this get_file_notes_data $index] note
		} else {
			if {![$listbox_project_files exists $item]} {
				return
			}
			set shortname	[$listbox_project_files itemcget $item -text]
			set data	[$listbox_project_files itemcget $item -data]
			if {[llength $data] < 5} {
				set filename	[lindex $data 0]
				set eol		[lindex $data 1]
				set encoding	[lindex $data 2]
				set read_only	[lindex $data 3]
			} else {
				set filename	"[lindex $data 5][lindex $data 0]"
				set eol		[lindex $data 8]
				set encoding	[lindex $data 9]
				set read_only	[lindex $data 2]
			}
		}

		# Skip untitled files
		if {$filename == {}} {return}

		# Destroy previous window
		catch {after cancel $filedetails_after_ID}
		catch {destroy ${::FILEDETAILSWIN}}

		# Create window
		set ::FILEDETAILSWIN [frame .file_details_win -bg {#AADDFF}]
		set file_details_win [frame ${::FILEDETAILSWIN}.frm -bg {#FFFFFF}]

		# Determinate file type and set appropriate icon
		set ext [string trimleft [file extension $filename] {.}]
		if {$ext == {h}} {
			set icon {source_h}
		} elseif {$ext == {c}} {
			set icon {source_c}
		} elseif {$ext == {cxx} || $ext == {cpp} || $ext == {cc}} {
			set icon {source_cpp}
		} elseif {$ext == {asm}} {
			set icon {asm}
		} else {
			set icon {ascii}
		}

		# Create header
		set header [frame $file_details_win.header -bg {#AADDFF}]
		pack [label $header.header		\
			-bg {#AADDFF} -text $shortname		\
			-justify left -pady 0 -padx 15		\
			-compound left -anchor w		\
			-image ::ICONS::16::$icon		\
		] -side left
		if {$read_only == 1} {
			pack [label $header.ro_text		\
				-bg {#AADDFF} -fg {#FF3333}	\
				-text [mc "(read only)"]	\
				-justify left -pady 0		\
			] -side left
		}
		pack $header -fill x

		# Show error message if the file dosn't exist
		if {![file exists $filename]} {
			pack [label $file_details_win.message_label	\
				-text [mc "File does not exist"]	\
				-fg {#FF0000}				\
			] -padx 80 -pady 40
			catch {after cancel $filedetails_after_ID}
			set filedetails_after_ID [after 750 "
				set ::FileList::filedetails_visible 1
				$this file_details_win_move"]
			return
		}

		# Determinate informations about the file
		set size	[file size $filename]		;# Size in B
		set mtime	[file mtime $filename]		;# Modification time
		if {!$::MICROSOFT_WINDOWS} { ;# Microsoft Windows has no file rights (compatible with posix rights)
			set perms	[file attributes $filename]	;# Owner - Group - Permissions
		}

		# Adjust the informations aboth the file
		set mtime [clock format $mtime -format {%D %R}]
		if {!$::MICROSOFT_WINDOWS} { ;# Microsoft Windows has no file rights (compatible with posix rights)
			set owner "[lindex $perms 1] - [lindex $perms 3]"
			set perms [lindex $perms 5]
			set perms [string range $perms {end-3} end]
		}
		if {[enc2name $encoding] != {}} {
			if {[string length $encoding] < 8} {
				append encoding "\t"
			}
			append encoding "\t(" [enc2name [string trimright $encoding]] {)}
		}
		if {$size < 1024} {
			append size { B}
		} else {
			set kB [expr {$size / 1024}]
			set B [expr {$size % 1024}]
			set MB [expr {$kB / 1024}]
			set kB [expr {$kB % 1024}]

			set original_size $size
			set size {}
			if {$MB} {
				append size $MB { MB  }
			}
			if {$kB} {
				append size $kB { kB  }
			}
			if {$B} {
				append size $B { B  }
			}
			append size {(} $original_size { B)}
		}
		switch -- $eol {
			{lf}	{set eol "Unix\t\t(LF)"}
			{crlf}	{set eol "DOS\t\t(CRLF)"}
			{cr}	{set eol "Macintosh\t(CR)"}
		}

		# Create main frame (containing everything except the header)
		set main_frame [frame $file_details_win.main_frame -bg {#FFFFFF}]

		# Path
		grid [label $main_frame.path_label	\
			-text [mc "Path:"]		\
			-fg {#0000AA}			\
			-anchor w -bg {#FFFFFF}		\
		] -row 0 -column 0 -sticky w -pady 0
		set path [file dirname $filename]
		if {$::MICROSOFT_WINDOWS} {
			regsub -all {/} $path "\\" path
		}
		grid [label $main_frame.path_value	\
			-text $path			\
			-anchor w -bg {#FFFFFF}		\
		] -row 0 -column 1 -sticky w -pady 0

		# Size
		grid [label $main_frame.size_label	\
			-text [mc "Size:"]		\
			-fg {#0000AA}			\
			-anchor w -pady 0 -bg {#FFFFFF}	\
		] -row 1 -column 0 -sticky w -pady 0
		grid [label $main_frame.size_value	\
			-text $size -anchor w -pady 0 -bg {#FFFFFF}	\
		] -row 1 -column 1 -sticky w -pady 0

		# Modified
		grid [label $main_frame.modified_label	\
			-text [mc "Modified:"]		\
			-fg {#0000AA}			\
			-anchor w -pady 0 -bg {#FFFFFF}	\
		] -row 2 -column 0 -sticky w -pady 0
		grid [label $main_frame.modified_value	\
			-text $mtime -anchor w -pady 0 -bg {#FFFFFF}	\
		] -row 2 -column 1 -sticky w -pady 0

		# Owner
		if {!$::MICROSOFT_WINDOWS} { ;# Microsoft Windows has no file rights (compatible with posix rights)
			grid [label $main_frame.owner_label	\
				-text [mc "Owner:"]		\
				-fg {#0000AA}			\
				-anchor w -pady 0 -bg {#FFFFFF}	\
			] -row 3 -column 0 -sticky w -pady 0
			grid [label $main_frame.owner_value	\
				-text $owner -anchor w -pady 0 -bg {#FFFFFF}	\
			] -row 3 -column 1 -sticky w -pady 0

			# Permissions
			grid [label $main_frame.perms_label	\
				-text [mc "Permissions:"]	\
				-fg {#0000AA} -bg {#FFFFFF}	\
				-anchor w -pady 0		\
			] -row 4 -column 0 -sticky w -pady 0
			grid [label $main_frame.perms_value	\
				-text $perms -anchor w -pady 0 -bg {#FFFFFF}	\
			] -row 4 -column 1 -sticky w -pady 0
		}

		if {!${::Editor::editor_to_use}} {
			# Separator
			grid [ttk::separator $main_frame.sep	\
				-orient horizontal		\
			] -row 5 -column 0 -columnspan 2 -sticky we -pady 0

			# Encoding
			grid [label $main_frame.enc_label	\
				-text [mc "Encoding:"]		\
				-fg {#880033}			\
				-anchor w -pady 0 -bg {#FFFFFF}	\
			] -row 6 -column 0 -sticky w -pady 0
			grid [label $main_frame.enc_value	\
				-text $encoding -anchor w	\
				-pady 0 -bg {#FFFFFF}		\
			] -row 6 -column 1 -sticky w -pady 0

			# EOL
			grid [label $main_frame.eol_label	\
				-text [mc "EOL:"] -fg {#880033}	\
				-anchor w -pady 0 -bg {#FFFFFF}	\
			] -row 7 -column 0 -sticky w -pady 0
			grid [label $main_frame.eol_value	\
				-text $eol -anchor w -pady 0 -bg {#FFFFFF}	\
			] -row 7 -column 1 -sticky w -pady 0
		}

		# User note
		if {$note != {} && $for == {O}} {
			set w_max 350
			set w [font measure ${::Todo::normal_font} $note]

			if {$w > $w_max} {
				set note [string range $note 0 [expr {int([string length $note] * $w_max/$w * 0.7)}]]
				append note {...}
			}

			# Separator
			grid [ttk::separator $main_frame.sep1	\
				-orient horizontal		\
			] -row 8 -column 0 -columnspan 2 -sticky we -pady 0
			grid [label $main_frame.notes_value			\
				-anchor w -pady 0 -bg {#FFFFFF}			\
				-text $note -font ${::Todo::normal_font}	\
				-justify left -anchor w -wraplength $w_max	\
			] -row 9 -column 0 -sticky w -pady 0 -columnspan 2
		}

		# Configure the window in a way that it will close when the user clicks on it
		foreach w [concat $file_details_win			\
				  $main_frame				\
				  [pack slaves $file_details_win]	\
				  [pack slaves $header]			\
				  [grid slaves $main_frame]		\
			  ]						\
		{
			bind $w <Button-1> [list $this file_details_win_hide]
		}

		# Pack main frame
		grid columnconfigure $main_frame 0 -minsize 90
		pack $main_frame -fill both -expand 1 -padx 8 -pady 3
		pack $file_details_win -fill both -expand 1 -padx 2 -pady 2

		# After 750 ms show the window
		catch {after cancel $filedetails_after_ID}
		set filedetails_after_ID [after 750 "
			set ::FileList::filedetails_visible 1
			$this file_details_win_move"]
	}

	## Move window "File details"
	 # @return void
	public method file_details_win_move args {
		# Abort if the window isn't visible
		if {!$filedetails_visible} {return}

		# Show the window
		catch {
			place ${::FILEDETAILSWIN} -anchor nw				\
				-x [expr {[winfo pointerx .] - [winfo rootx .] + 20}]	\
				-y [expr {[winfo pointery .] - [winfo rooty .] + 20}]
			update
			raise ${::FILEDETAILSWIN}
		}
	}

	## Hide window "File details"
	 # @return void
	public method file_details_win_hide args {
		set filedetails_visible 0	;# Bool: Is file details window visible

		# Hide window and cancel timeout
		catch {after cancel $filedetails_after_ID}
		catch {place forget ${::FILEDETAILSWIN}}
	}

	## Define popup menus
	 # @return void
	public method filelist_makePopupMenu {} {
		if {[winfo exists $opened_files_menu]} {
			destroy $opened_files_menu
		}
		if {[winfo exists $project_files_menu]} {
			destroy $project_files_menu
		}
		if {[winfo exists $filetabs_pu_menu]} {
			destroy $filetabs_pu_menu
		}

		menuFactory $PROJECTFILESMENU	$project_files_menu	0 "$this " 0 {} [namespace current]
		menuFactory $OPENEDFILESMENU	$opened_files_menu	0 "$this " 0 {} [namespace current]
		menuFactory $FILETABSPUMENU	$filetabs_pu_menu	0 "$this " 0 {} [namespace current]

		foreach program		{gvim	emacs	kwrite	gedit}	\
			program_name	{gvim	emacs	kwrite	gedit}	\
		{
			if {!$::PROGRAM_AVAILABLE($program)} {
				foreach menu [list $project_files_menu $opened_files_menu $filetabs_pu_menu] {
					${menu}.open_with entryconfigure [::mc $program_name] -state disabled
				}
			}
		}
		if {${::Editor::editor_to_use}} {
			$opened_files_menu entryconfigure [::mc "Save"]		-state disabled
			$opened_files_menu entryconfigure [::mc "Save as"]	-state disabled
			$opened_files_menu entryconfigure [::mc "Save all"]	-state disabled

			$filetabs_pu_menu entryconfigure [::mc "Save"]		-state disabled
			$filetabs_pu_menu entryconfigure [::mc "Save as"]	-state disabled
			$filetabs_pu_menu entryconfigure [::mc "Save all"]	-state disabled
		}
	}

	## Reload the current file
	 # @parm Object target_editor	- Editor object where the reload is supposed to take place
	 # @parm Bool force		- Don't ask whether the file should be saved first, in case it was modified
	 # @return Bool - result
	public method filelist_reload_file {{target_editor {}} {force 0}} {
		if {$target_editor == {}} {
			if {$splitted && $selectedView} {
				set editor_idx $actualEditor2
			} else {
				set editor_idx $actualEditor
			}
			set editor [lindex $editors $editor_idx]
		} else {
			set editor_idx [lsearch -ascii -exact $editors $target_editor]
			set editor $target_editor
		}

		# Local variables
		set fullFileName [$editor cget -fullFileName]	;# Full filename
		set filename [$editor cget -filename]		;# Simple filename

		if {
			![file exists $fullFileName]		||
			[file isdirectory $fullFileName]	||
			(!$::MICROSOFT_WINDOWS && ![file readable $fullFileName])
		} then {
			tk_messageBox	\
				-title [mc "File not found"]	\
				-icon error			\
				-type ok			\
				-parent .			\
				-message [mc "The file selected for reload does not exist any more or it is not readable !"]
			set fullFileName {}
		}

		if {$fullFileName != {}} {
			# Prompt user is the file was modified
			if {!$force && ([$editor cget -modified] != 0)} {
				set response [tk_messageBox	\
					-title [mc "Are you sure ?"]	\
					-icon question		\
					-type yesno		\
					-parent .		\
					-message [mc "Reload of the file will change contents of the current editor. Are you sure you want that ?"]	\
				]
				if {$response != {yes}} {
					Sbar [mc "Reload aborted"]
					return 0
				}
			}

			set enc [lindex $file_encoding	$editor_idx]
			set eol [lindex $file_eol	$editor_idx]
			set rom [lindex $file_ro_mode	$editor_idx]
			set sh  [lindex $file_sh	$editor_idx]

			# Get number of the current line
			set line [$editor get_current_line_number]
			# Clear content of the current editor
			if {[$editor cget -ro_mode]} {
				[$editor cget -editor] configure -state normal
			}
			$editor clear_autocompletion_list
			[$editor cget -editor] configure -autoseparators 0
			[$editor cget -editor] delete 1.0 end
			# Insert content of the file into the editor
			set file [open $fullFileName r]
			fconfigure $file -encoding $enc
			set data {}
			if {[regsub -all {[\u0000-\u0008\u000B-\u000C\u000E-\u001F\u007F-\u009F]} [read $file] {} data]} {
				tk_messageBox							\
					-parent .						\
					-type ok						\
					-icon warning						\
					-title [mc "Binary File Opened - MCU 8015 IDE"]		\
					-message [mc "The file %s is binary, saving it will result corrupted file." $fullFileName]
			}
			[$editor cget -editor] insert end [regsub -all {\r\n?} $data "\n"]
			if {[$editor cget -ro_mode]} {
				[$editor cget -editor] configure -state disabled
			}
			close $file
			$editor goto $line
			[$editor cget -editor] edit separator
			[$editor cget -editor] configure -autoseparators 1

			# Set EOL and Encoding in ListBox of project files
			foreach item [$listbox_project_files items] {
				if {[$listbox_project_files itemcget $item -text] != $filename} {
					continue
				}
				set data [$listbox_project_files itemcget $item -data]
				if {[llength $data] > 5} {continue}
				if {[lindex $data 0] != $fullFileName} {continue}
				lset data 1 $eol
				lset data 2 $enc
				lset data 3 $rom
				$listbox_project_files itemconfigure $item -data $data
			}
		}

		# Reset status modified
		[$editor cget -editor] edit modified 0
		$editor recalc_status_modified 0
		# Restore syntax highlight
		rightPanel_clear_all_bookmarks
		rightPanel_clear_all_breakpoints
		rightPanel_clear_symbol_list
		$editor parseAll

		# Successful
		return 1
	}

	## Highlight all loaded source codes, import breakpoints and bookmarks etc.
	 # This function finalizes project initialization
	 # @return void
	public method filelist_global_highlight {} {
		# Class variables
		set filelist [lreplace $filelist 0 1]	;# List of files to open (special format)

		# Skip empty/invalid filelist
		if {[lindex $filelist $actualEditor] == {}} {
			rightPanel_enable
			return
		}

		# Local variables
		set ac		$actualEditor	;# Number of actual editor
		# Number of current line in the current editor
		set ac_line	[lindex $filelist [list $ac_index_in_fl 6]]

		# Take care of the current editor
		rightPanel_switch_editor_vars $ac
		$this todo_switch_editor_vars $ac
		[lindex $editors $ac] import_line_markers_data		\
			[lindex $filelist [list $ac_index_in_fl 9]]	\
			[lindex $filelist [list $ac_index_in_fl 10]]
		[lindex $editors $ac] goto $ac_line

		# Import bookmarks and breakpoints into all editors except the current one
		set idx -1
		set lines {}
		foreach record $filelist {
			# Skip closed files
			if {[lindex $record 1] != {yes}} {continue}

			# Detrminate file index
			incr idx
			set i [lindex $file_indexes $idx]
			if {$i == {}} {
				continue
			}

			# Skip current editor
			if {$i == $ac} {
				incr i
				lappend lines $ac_line
				continue
			}
			# Local variables
			set editor	[lindex $editors $i]	;# Reference to target editor object
			set line	[lindex $record 6]	;# Current line

			# Adjust right panel
			set actualEditor $i
			rightPanel_switch_editor_vars $i
			$this todo_switch_editor_vars $i
			# Import bookmarks and breakpoints into editor
			$editor import_line_markers_data	\
				[lindex $record 9]		\
				[lindex $record 10]
			$editor goto $line
			lappend lines $line
		}

		# Finalize
		set filelist {}
		set actualEditor $ac

		# Adjust Right panel
		rightPanel_enable
		set i 0
		foreach line $lines {
			set editor [lindex $editors $i]
			rightPanel_switch_editor_vars $i
			$this todo_switch_editor_vars $i
			$editor rightPanel_adjust $line
			incr i
		}
		rightPanel_switch_editor $ac
		$this todo_switch_editor $ac
		if {${::ASMsyntaxHighlight::validation_L1}} {
			[lindex $editors $actualEditor] parse_current_line
		} else {
			[lindex $editors $actualEditor] adjust_instruction_details
		}

		set file_indexes {}
	}

	public method is_splitted {} {
		return $splitted
	}

	## Switch from Normal mode to Simulator mode
	 # @return void
	public method freeze {} {
		# Set mode flag
		set frozen 1
		set simulator_editor_obj {}
		set simulator_editor -1
		# Freeze editor
		if {$splitted && $selectedView} {
			set editor_to_freeze $actualEditor2
		} else {
			set editor_to_freeze $actualEditor
		}
		set idx 0
		foreach editor $editors {
			if {$idx == $editor_to_freeze} {
				$editor freeze
				set editor_to_freeze_obj $editor
			} else {
				$editor disable
			}
			incr idx
		}
		FileList_project_disEna_buttons
		# Disable some popupmenu items
		foreach entry $freezable_menu_items {
			$opened_files_menu entryconfigure [::mc $entry] -state disabled
		}
		$project_files_menu entryconfigure [::mc "Close file"] -state disabled
	}

	## This method should be called immediately after simulator start-up
	 #+ in order to inform editors about the change
	 # @return void
	public method now_frozen {} {
		$editor_to_freeze_obj now_frozen
	}

	## Switch from Simulator mode to Normal mode
	 # @return void
	public method thaw {} {
		# Set mode flag
		set frozen 0
		# Thaw editors
		foreach editor $editors {
			$editor thaw
		}
		# Enable switching files
		listBox_disEna_buttons				\
			[$listbox_opened_files selection get]	\
			[lindex $editors $actualEditor]
		if {$splitted} {
			listBox_disEna_buttons				\
				[$listbox_opened_files selection get]	\
				[lindex $editors $actualEditor]
		}
		# Enable some poupmenu items
		foreach entry $freezable_menu_items {
			$opened_files_menu entryconfigure [::mc $entry] -state normal
		}
		$project_files_menu entryconfigure [::mc "Close file"] -state normal

		if {$simulator_editor_obj != {}} {
			set idx [lsearch -ascii -exact $editors $simulator_editor_obj]
			if {$idx != -1} {
				$listbox_opened_files itemconfigure [lindex $file_descriptors $idx] -fg {#000000}
			} else {
				set simulator_editor_obj {}
			}
		}
		set simulator_editor_obj {}

		if {$splitted && $selectedView} {
			set editor_idx $actualEditor2
		} else {
			set editor_idx $actualEditor
		}
		focus -force [[lindex $editors $editor_idx] cget -editor]
	}

	## Set variable containing ID of active page
	 # @parm String pageName - active page
	 # @return void
	public method Left_panel_set_active_page {pageName} {
		set active_page $pageName
	}

	## Get mode flag
	 # @return Bool - current mode (1 == Simulation mode; 0 == Normal mode)
	public method is_frozen {} {return $frozen}

	## Get current panel width
	 # @return Int - the width
	public method getLeftPanelSize {} {
		if {$PanelVisible} {
			return $PanelSize
		} else {
			return $last_sash
		}
	}

	## Set panel width according to current sash position
	 # @return void
	public method left_panel_set_size {} {
		set PanelSize [lindex [$parent sash coord 0] 0]
	}

	## Get ID of active page
	 # @return String - the active page
	public method getLeftPanelActivePage {} {return $active_page}

	## Get value of panel visibility flag
	 # @return Bool - the flag (1 == Visible, 2 == Hidden)
	public method isLeftPanelVisible {} {return $PanelVisible}

	## Show/Hide the left panel
	 # @return Bool - 1 == now displayed; 0 == now hidden
	public method filelist_show_hide {} {
		# Hide the panel
		if {$PanelVisible} {
			$parent paneconfigure $leftPanel -minsize 0

			pack forget [$notebook get_nb]
			# Show button bar
			pack $button_bar -side top -anchor nw
			# Move the paned window sash and remember current position
			set last_sash [lindex [$parent sash coord 0] 0]
			update idletasks
			$parent sash place 0 25 2
			# Hide the sash
			bind $parent <Button> {break}
			$parent configure -sashwidth 0
			# done ...
			set PanelVisible 0
			return 0

		# Show the panel
		} else {
			$parent paneconfigure $leftPanel -minsize 155

			$notebook raise $active_page
			# Hide button bar
			pack forget $button_bar
			# Show the panel
			pack [$notebook get_nb] -expand 1 -fill both -padx 5 -pady 5
			# Restore the paned window sash position to the previous state
			update idletasks
			$parent sash place 0 $last_sash 0
			# Show the sash
			bind $parent <Button> {}
			$parent configure -sashwidth 2
			# done ...
			set PanelVisible 1
			return 1
		}
	}

	## Change panel active page
	 # @parm String page - ID of the page to show
	 # @return void
	public method filelist_show_up {page} {
		if {!$PanelVisible} filelist_show_hide
		$notebook raise $page
	}

	## Move up currently selected item -- Opened files
	 # @return void
	public method filelist_move_up {} {
		# Local variables
		set item [$listbox_opened_files selection get]	;# Item ID
		set index [$listbox_opened_files index $item]	;# Item index
		set target [expr {$index - 1}]			;# Target index

		# 1st item cannot be moved up
		if {$index == 0} {return}

		# Move item in listbox and the notebook
		$listbox_opened_files move $item $target
		$filetabs_nb move $item $target
		# Move item in list of bookmarks and icon border
		if {[lindex $opened_files_bookmarks $index] != [lindex $opened_files_bookmarks $target]} {
			# Determinate bookmark flag for source and target index
			set trg_bm [lindex $opened_files_bookmarks $target]
			set idx_bm [lindex $opened_files_bookmarks $index]
			# Move item in list of bookmarks
			lset opened_files_bookmarks $target [lindex $opened_files_bookmarks $index]
			lset opened_files_bookmarks $index $trg_bm
			# Move item in icon border
			incr target
			incr index
			$listbox_opened_files_bm delete $index.0 [list $index.0 lineend]
			$listbox_opened_files_bm delete $target.0 [list $target.0 lineend]
			if {$trg_bm} {
				$listbox_opened_files_bm image create $index.0	\
					-image ::ICONS::16::bookmark		\
					-align center
			}
			if {$idx_bm} {
				$listbox_opened_files_bm image create $target.0	\
					-image ::ICONS::16::bookmark		\
					-align center
			}
		}

		# Reevaluate button states on icon bar
		listBox_disEna_buttons $item [lindex $editors [lsearch $file_descriptors $item]]
	}

	## Move down currently selected item -- Opened files
	 # @return void
	public method filelist_move_down {} {
		# Local variables
		set item [$listbox_opened_files selection get]	;# Item ID
		set index [$listbox_opened_files index $item]	;# Item index
		set target [expr {$index + 1}]			;# Target index

		# Last item cannot be moved up
		if {[llength [$listbox_opened_files items]] == ($index + 1)} {return}

		# Move item in listbox
		$listbox_opened_files move $item $target
		$filetabs_nb move $item $target

		# Move item in list of bookmarks and icon border
		if {[lindex $opened_files_bookmarks $index] != [lindex $opened_files_bookmarks $target]} {
			# Determinate bookmark flag for source and target index
			set trg_bm [lindex $opened_files_bookmarks $target]
			set idx_bm [lindex $opened_files_bookmarks $index]
			# Move item in list of bookmarks
			lset opened_files_bookmarks $target [lindex $opened_files_bookmarks $index]
			lset opened_files_bookmarks $index $trg_bm
			# Move item in icon border
			incr target
			incr index
			$listbox_opened_files_bm delete $index.0 [list $index.0 lineend]
			$listbox_opened_files_bm delete $target.0 [list $target.0 lineend]
			if {$trg_bm} {
				$listbox_opened_files_bm image create $index.0	\
					-image ::ICONS::16::bookmark		\
					-align center
			}
			if {$idx_bm} {
				$listbox_opened_files_bm image create $target.0	\
					-image ::ICONS::16::bookmark		\
					-align center
			}
		}

		# Reevaluate button states on icon bar
		listBox_disEna_buttons $item [lindex $editors [lsearch $file_descriptors $item]]
	}

	## Move to top currently selected item -- Opened files
	 # @return void
	public method filelist_move_top {} {
		# Local variables
		set item [$listbox_opened_files selection get]	;# Item ID
		set index [$listbox_opened_files index $item]	;# Item index

		# Move item
		$listbox_opened_files move $item 0
		$filetabs_nb move $item 0
		# Move item in list of bookmarks
		set bm [lindex $opened_files_bookmarks $index]
		set opened_files_bookmarks [lreplace $opened_files_bookmarks $index $index]
		set opened_files_bookmarks [linsert $opened_files_bookmarks 0 $bm]
		# Move item in icon border
		incr index
		$listbox_opened_files_bm delete $index.0 $index.0+1l
		$listbox_opened_files_bm insert 1.0 "\n"
		if {$bm} {
			$listbox_opened_files_bm image create 1.0	\
				-image ::ICONS::16::bookmark	\
				-align center
		}

		# Reevaluate button states on icon bar
		listBox_disEna_buttons $item [lindex $editors [lsearch $file_descriptors $item]]
	}

	## Move to bottom currently selected item  -- Opened files
	 # @return void
	public method filelist_move_bottom {} {
		# Local variables
		set item [$listbox_opened_files selection get]	;# Item ID
		set index [$listbox_opened_files index $item]	;# Item index

		# Move item in listbox
		$listbox_opened_files move $item end
		$filetabs_nb move $item end
		# Move item in list of bookmarks
		set bm [lindex $opened_files_bookmarks $index]
		set opened_files_bookmarks [lreplace $opened_files_bookmarks $index $index]
		lappend opened_files_bookmarks $bm
		# Move item in icon border
		incr index
		set end [llength $opened_files_bookmarks]
		$listbox_opened_files_bm delete $index.0 $index.0+1l
		$listbox_opened_files_bm insert $end.0 "\n"
		if {$bm} {
			$listbox_opened_files_bm image create $end.0	\
				-image ::ICONS::16::bookmark	\
				-align center
		}

		# Reevaluate button states on icon bar
		listBox_disEna_buttons $item [lindex $editors [lsearch $file_descriptors $item]]
	}

	## Show up editor asociated with the currently selected item in the file list (opened files)
	 # @return void
	public method switchfile {} {
		if {$switchfile_in_progress} {
			return
		}
		set switchfile_in_progress 1

		# Ensure that autocompletion window is closed
		::Editor::close_completion_popup_window_NOW

		# Determinate ID of the selected item
		set item [$listbox_opened_files selection get]
		set editor_idx [lsearch $file_descriptors $item]

		# Adjust filetabs notebook
		set page [lindex [$filetabs_nb pages] [$listbox_opened_files index $item]]
		if {$page == {}} {
			set switchfile_in_progress 0
			return
		}
		$filetabs_nb raise $page
		$filetabs_nb see $page

		# Conditionaly switch selected view
		if {$splitted && $selectedView} {
			if {$editor_idx == $actualEditor} {
				set selectedView 0
			}
		} else {
			if {$editor_idx == $actualEditor2} {
				set selectedView 1
			}
		}

		# Show up the corresponding editor
		rightPanel_switch_editor_vars $editor_idx
		$this todo_switch_editor_vars $editor_idx
		# Right/Bottom view selected
		if {$splitted && $selectedView} {
			if {$editor_idx != $actualEditor2} {
				if {!$do_not_forget_editor && $actualEditor2 >= 0} {
					set editor [lindex $editors $actualEditor2]
					if {$editor != {}} {
						pack forget [$editor cget -ed_sc_frame]
					}
				}
				set actualEditor2 $editor_idx
				pack [[lindex $editors $actualEditor2] cget -ed_sc_frame]	\
					-in $pagesManager2 -fill both -expand 1
			}
			set editor [lindex $editors $actualEditor2]

		# Left/Top view selected
		} else {
			if {$editor_idx != $actualEditor} {
				if {!$do_not_forget_editor && $actualEditor >= 0} {
					set editor [lindex $editors $actualEditor]
					if {$editor != {}} {
						pack forget [$editor cget -ed_sc_frame]
					}
				}
				set actualEditor $editor_idx
				pack [[lindex $editors $actualEditor] cget -ed_sc_frame]	\
					-in $pagesManager -fill both -expand 1
			}
			set editor [lindex $editors $actualEditor]
		}

		set do_not_forget_editor 0
		$opened_search_entry delete 0 end
		update idletasks
		editor_procedure {} Configure {}
		editor_procedure {} scroll {scroll +0 lines}
		editor_procedure {} highlight_visible_area {}
		editor_procedure {} check_file_change_notif {}
		update
		rightPanel_switch_page $editor_idx
		$this todo_switch_editor $editor_idx
		# Set encoding and eol
		set ::editor_encoding	[lindex $file_encoding	$editor_idx]
		set ::editor_EOL	[lindex $file_eol	$editor_idx]
		set ::editor_RO_MODE	[lindex $file_ro_mode	$editor_idx]
		set ::editor_SH		[lindex $file_sh	$editor_idx]
		# Adjust command line status
		if {$editor_command_line_on} {
			$editor cmd_line_force_on
		} else {
			$editor cmd_line_force_off
		}
		# Adjust tab "Instruction details" on the right panel
		if {${::ASMsyntaxHighlight::validation_L1}} {
			$editor parse_current_line
		} else {
			$editor adjust_instruction_details
		}
		# move arrow image
		catch {$listbox_opened_files itemconfigure $lastItem -image {}}
		$listbox_opened_files itemconfigure $item -image ::ICONS::16::2_rightarrow
		set lastItem $item
		# Reevaluate button states on left panel icon bar, program title bar and main menu and main toolbar
		listBox_disEna_buttons $item $editor
		::X::adjust_title
		::X::adjust_mainmenu_and_toolbar_to_editor	\
			${::editor_RO_MODE} [expr {[$editor get_language] == 1}]
		# Focus on the editor
		focus -force [$editor cget -editor]
		update
		set switchfile_in_progress 0
	}

	## Switch to the next editor
	 # @return void
	public method next_editor {} {
		if {$frozen} {return}
		set index [$listbox_opened_files index [$listbox_opened_files selection get]]

		if {$index >= ([llength $file_descriptors] - 1)} {return}
		$listbox_opened_files selection set [$listbox_opened_files item [expr {$index + 1}]]
		switchfile
	}

	## Switch to the previous editor
	 # @return void
	public method prev_editor {} {
		if {$frozen} {return}
		set index [$listbox_opened_files index [$listbox_opened_files selection get]]
		if {$index} {
			$listbox_opened_files selection set	\
				[$listbox_opened_files item [expr {$index - 1}]]
			switchfile
		}
	}

	## Switch the last file in list of opened files
	 # @return void
	public method switch_to_last {} {
		if {$splitted} {
			set item [expr {([llength $file_descriptors] - 1)}]
			if {$item == $actualEditor || $item == $actualEditor2} {
				set item {end-1}
			}
		} else {
			set item {end}
		}
		$listbox_opened_files selection set [lindex $file_descriptors $item]
		switchfile
	}

	## Enable/Disable buttons in opened files icon bar and popup menu
	 # @parm String item	- ID of the current item
	 # @parm Object editor	- reference to current editor object
	 # @return void
	private method listBox_disEna_buttons {item editor} {

		# Is the file part of the project ?
		if {[getItemNameFromProjectList [$editor cget -fullFileName]] != {}} {
			set state disabled
		} else {
			set state normal
		}
		$opened_files_menu entryconfigure [::mc "Append to project"] -state $state
		$filetabs_pu_menu entryconfigure [::mc "Append to project"] -state $state

		# Items: "Move up" and "Move to top"
		set item_idx [$listbox_opened_files index $item]
		if {$item_idx == 0} {
			set state disabled
		} else {
			set state normal
		}
		$opened_files_menu entryconfigure [::mc "Move up"]		-state $state
		$opened_files_menu entryconfigure [::mc "Move to top"]		-state $state
		$prev_editor_button configure -state $state
		${opened_files_buttonBox}up configure -state $state
		${opened_files_buttonBox}top configure -state $state

		# Items: "Move down" and "Move to bottom"
		if {($item_idx + 1) >= [llength [$listbox_opened_files items]]} {
			set state disabled
		} else {
			set state normal
		}
		$opened_files_menu entryconfigure [::mc "Move down"]		-state $state
		$opened_files_menu entryconfigure [::mc "Move to bottom"]	-state $state
		$next_editor_button configure -state $state
		${opened_files_buttonBox}down configure -state $state
		${opened_files_buttonBox}bottom configure -state $state
	}

	## Invoke popup menu for "Opened files"
	 # @parm Int x	- absolute X coordinate
	 # @parm Int y	- absolute Y coordinate
	 # @return void
	public method fileList_opened_filelist_popup {x y} {
		if {$item_menu_invoked} {
			set item_menu_invoked 0
			return
		}

		if {!${::Editor::editor_to_use}} {
			$opened_files_menu entryconfigure [::mc "Save as"]	-state disabled
			$opened_files_menu entryconfigure [::mc "Save"]		-state disabled

			$filetabs_pu_menu entryconfigure [::mc "Save"]		-state disabled
			$filetabs_pu_menu entryconfigure [::mc "Save as"]	-state disabled
		}
		foreach entry {
			{Close}			{Bookmark}	{Move up}
			{Move down}		{Move to top}	{Move to bottom}
			{Open with}		{Append to project}
		} {
			$opened_files_menu entryconfigure [::mc $entry] -state disabled
		}

		tk_popup $opened_files_menu $x $y
	}

	## Invoke popup menu for "Opened files" -- for particular item
	 # note: This method should be associated with the 'bindtext' command
	 # @parm Int x		- absolute X coordinate
	 # @parm Int y		- absolute Y coordinate
	 # @parm String item	- ID of selected item
	 # @return void
	public method fileList_opened_filelist_item_popup {x y item} {
		set item_menu_invoked 1

		if {!${::Editor::editor_to_use}} {
			$opened_files_menu entryconfigure [::mc "Save as"]	-state normal
			$opened_files_menu entryconfigure [::mc "Save"]		-state normal

			$filetabs_pu_menu entryconfigure [::mc "Save"]		-state normal
			$filetabs_pu_menu entryconfigure [::mc "Save as"]	-state normal
		}
		foreach entry {
			{Close}		{Bookmark}	{Move up}
			{Move down}	{Move to top}	{Move to bottom}
			{Open with}
		} {
			$opened_files_menu entryconfigure [::mc $entry] -state normal
		}
		# It is not so easy to open the file with an external editor on Microsoft Windows as
		# it is on a POSIX system, that's why this feature is disabled here
		if {$::MICROSOFT_WINDOWS} {
			$opened_files_menu entryconfigure [::mc {Open with}] -state disabled
			$filetabs_pu_menu entryconfigure [::mc {Open with}] -state disabled
		}

		$listbox_opened_files selection set $item
		switchfile

		# Enable/Disable item "Append to project"
		set fullFileName [[lindex $editors [lsearch $file_descriptors $item]] cget -fullFileName]
		if {$fullFileName == {} || [getItemNameFromProjectList $fullFileName] != {}} {
			set state disabled
		} else {
			set state normal
		}
		$opened_files_menu entryconfigure [::mc  "Append to project"] -state $state

		tk_popup $opened_files_menu $x $y
	}

	# ---------------------------------------------------------------------
	# AUXILIARY DATA MANAGEMENT PROCEDURES
	# ---------------------------------------------------------------------

	## Open all files in the given list
	 # @parm List filelist - files to open (spec. format)
	 # @return void
	public method open_files {filelist} {
		# NS variables
		set file_indexes	{}	;# List of line indexes (auxiliary variable for opening multiple files)
		set ac_index_in_fl	-1	;# Index of actual editor filelist

		# Local variables
		set num_of_opened_files 0	;# Number of opened files
		set rfi			0	;# Record field index
		set open_files_progress	0	;# Value for progress dialog (progress)
		set open_files_abort	0	;# Abort variable
		set keep_order		1	;# Bool: Keep order of files
		set rec_i		-1	;# Record index (in $filelist)
		set file_indexes_fb	{}	;# Fallback file indexes
		set unopened_files	{}	;# List of files which were unable to open
		set changed_files	{}	;# List of files changed since last project save
		set project_path	[$this cget -projectPath]	;# Path to the project directory
		set filelist_length	[llength $filelist]		;# Length of the given filelist
		set ac			[lindex $filelist {1 0}]	;# Index of actual editor

		## Lists of files to open
		 # Ordered
		set files_to_open__path	[string repeat {{} } $filelist_length]	;# Path
		set files_to_open__enc	[string repeat {{} } $filelist_length]	;# Encoding
		set files_to_open__eol	[string repeat {{} } $filelist_length]	;# EOL
		set files_to_open__bm	[string repeat {{} } $filelist_length]	;# Bookmark flag
		set files_to_open__ro	[string repeat {{} } $filelist_length]	;# Read only flag
		set files_to_open__sh	[string repeat {{} } $filelist_length]	;# Syntax highlight
		set files_to_open__nt	[string repeat {{} } $filelist_length]	;# Notes for file
		 # Unordered
		set files_to_open_path	{}	;# Path
		set files_to_open_enc	{}	;# Encoding
		set files_to_open_eol	{}	;# EOL
		set files_to_open_bm	{}	;# Bookmark flag
		set files_to_open_ro	{}	;# Read only flag
		set files_to_open_sh	{}	;# Syntax highlight
		set files_to_open_nt	{}	;# Notes for file

		# Abort if the given filelist is empty
		if {!$filelist_length} {return}

		# Iterate over records in $filelist
		foreach record $filelist {
			incr rec_i			;# Record index

			# First 2 records have no meaning here
			if {$rec_i < 2 || $record == {}} {continue}

			# Parse record
			set rfi 0
			foreach var {
				file_name	active		o_bookmark	p_bookmark
				file_index	read_only	file_line	file_md5
				file_path	file_BMs	file_BPs	eol
				enc		sh		notes
			} {
				set $var [lindex $record $rfi]
				incr rfi
			}

			# Adjust file path
			if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
				if {[string index $file_path 0] != {/}} {
					set file_path "$project_path/$file_path"
				}
			} else {	;# Microsoft windows way
				if {![regexp {^\w:} $file_path]} {
					set file_path "$project_path/$file_path"
				}
			}
			# Determinate full file name
			set full_file_name "$file_path$file_name"

			# Check for file usebility
			if {
				![file exists $full_file_name]
					||
				[file isdirectory $full_file_name]
					||
				(!$::MICROSOFT_WINDOWS && ![file readable $full_file_name])
			} then {
				lappend file_indexes_fb {}
				lappend unopened_files $full_file_name
				continue
			}

			# Chech for valid EOL and Encoding
			if {$eol != {lf} && $eol != {cr} && $eol != {crlf}} {
				set eol $default_eol
				puts stderr "Invalid EOL -- using default ($eol)"
			}
			if {$enc != {def} && [lsearch [encoding names] $enc] == -1} {
				set enc $default_encoding
				puts stderr "Invalid encoding -- using default ($default_encoding)"
			}
			if {![string is boolean -strict $read_only]} {
				set read_only 0
				puts stderr "Read only flag -- using default (0)"
			}

			# Compare file MD5
			if {[catch {
				if {!$read_only && [md5::md5 -hex -file $file_path$file_name] != $file_md5} {
					lappend changed_files $file_path$file_name
				}
			}]} then {
				tk_messageBox				\
					-parent .			\
					-icon warning			\
					-type ok			\
					-title [mc "Unknown error"]	\
					-message [mc "Error raised during md5 checking file %s. Maybe md5 extension is not correctly loaded." $file_name]
			}

			# Insert bookmark to icon border for project files
			if {[llength $project_files_bookmarks]} {
				$listbox_project_files_bm insert end "\n"
			}
			if {$p_bookmark == 1} {
				lappend project_files_bookmarks 1
				$listbox_project_files_bm image create [list {end-1l} linestart]	\
					-image ::ICONS::16::bookmark -align center
			} else {
				lappend project_files_bookmarks 0
			}
			$listbox_project_files_bm tag add center 0.0 end

			# Register the file in the project
			if {$active == {no}} {
				if {[llength $record] < 5} {continue}
				$listbox_project_files insert end #auto		\
					-font $closed_file_font -fill {#888888}	\
					-text $file_name			\
					-data [list	$file_name	$active		\
							$read_only	$file_line	\
							$file_md5	$file_path	\
							$file_BMs	$file_BPs	\
							$eol		$enc		\
							$sh		$notes		\
					]
				continue
			} else {
				$listbox_project_files insert end #auto	\
					-font $opened_file_font -fill {#000000}	\
					-text $file_name -data [list $file_path$file_name $eol $enc $read_only]
				if {![string is digit -strict $file_index]} {
					set keep_order 0
				}
			}

			# Adjust lists of file indexes
			lappend file_indexes	$file_index
			lappend file_indexes_fb	$num_of_opened_files

			if { $file_index >= $filelist_length } {
				set enlargeBy [expr {$file_index - $filelist_length + 1}]
				append files_to_open__path	[string repeat { {}} $enlargeBy]
				append files_to_open__enc	[string repeat { {}} $enlargeBy]
				append files_to_open__eol	[string repeat { {}} $enlargeBy]
				append files_to_open__bm	[string repeat { {}} $enlargeBy]
				append files_to_open__ro	[string repeat { {}} $enlargeBy]
				append files_to_open__sh	[string repeat { {}} $enlargeBy]
				append files_to_open__nt	[string repeat { {}} $enlargeBy]
			}

			# Adjust list of files to open
			lset files_to_open__path	$file_index $file_path$file_name
			lset files_to_open__enc		$file_index $enc
			lset files_to_open__eol		$file_index $eol
			lset files_to_open__bm		$file_index $o_bookmark
			lset files_to_open__ro		$file_index $read_only
			lset files_to_open__sh		$file_index $sh
			lset files_to_open__nt		$file_index $notes
			lappend files_to_open_path	$file_path$file_name
			lappend files_to_open_enc	$enc
			lappend files_to_open_eol	$eol
			lappend files_to_open_bm	$o_bookmark
			lappend files_to_open_ro	$read_only
			lappend files_to_open_sh	$sh
			lappend files_to_open_nt	$notes

			# Determinate index in file list for actual editor
			if {$file_index == $ac} {
				set ac_index_in_fl $rec_i
				incr ac_index_in_fl -2
			}

			# Increment number of opened files
			incr num_of_opened_files
		}

		# Invoke progress dialog
		set max [llength $file_indexes_fb]
		if {!$max} {set max 1}
		.prgDl.f.progressbar configure -maximum $max

		# Adjust lists of files to open
		if {!$keep_order} {
			set files_to_open__path	$files_to_open_path
			set files_to_open__enc	$files_to_open_enc
			set files_to_open__eol	$files_to_open_eol
			set files_to_open__bm	$files_to_open_bm
			set files_to_open__ro	$files_to_open_ro
			set files_to_open__sh	$files_to_open_sh
			set files_to_open__nt	$files_to_open_nt
			set file_indexes	$file_indexes_fb
		}

		# Check for validity of list of file indexes
		if {$unopened_files != {}} {
			set file_indexes $file_indexes_fb
		} else {
			for {set i 0} {$i < $num_of_opened_files} {incr i} {
				if {[lsearch -ascii -exact $file_indexes $i] == -1} {
					set file_indexes $file_indexes_fb
					break
				}
			}
		}

		# Open files
		set i 0
		set pos 0
		foreach	path	$files_to_open__path	\
			enc	$files_to_open__enc	\
			eol	$files_to_open__eol	\
			bm	$files_to_open__bm	\
			ro	$files_to_open__ro	\
			sh	$files_to_open__sh	\
			notes	$files_to_open__nt	\
		{
			incr pos
			if {$path == {}} {
				continue
			}

			# Abort process on user request
			if {$open_files_abort} {
				$listbox_project_files delete [$listbox_project_files items $i end]
				if {$i} {
					incr i -1
					set file_indexes	[lrange $file_indexes		0 $i]
					set file_indexes_fb	[lrange $file_indexes_fb	0 $i]
				} else {
					set file_indexes	{}
					set file_indexes_fb	{}
				}

				set filelist [lrange $filelist 0 $pos]
				break
			}

			# Adjust progress dialog
			incr open_files_progress
			set open_files_cur_file [file tail $path]
			update

			# Open file
			if {[openfile $path 0 . $enc $eol $ro 0 $sh] != {}} {
				if {$bm == 1} {
					opened_files_bookmark $i
				}
				$this set_file_notes_data $notes
			}
			incr i
		}

		# Invoke dialog "File(s) not found"
		if {$unopened_files != {}} {
			# Create toplevel window
			set win [toplevel .file_not_found$obj_idx -class {Error dialog} -bg ${::COMMON_BG_COLOR}]

			# Create window header
			pack [frame $win.frame1] -side top -fill x -anchor nw
			pack [label $win.frame1.image	\
				-image ::ICONS::32::messagebox_critical	\
			] -anchor nw -expand 0 -side left -padx 10 -pady 5
			pack [label $win.frame1.header	\
				-text [mc "The following files could not be located:"]	\
			] -side left -fill x

			# Create text widget with scrollbar
			pack [frame $win.frame2] -side top -expand 1 -fill both -pady 10 -padx 5
			pack [text $win.frame2.text -height 5 -width 40	\
				-yscrollcommand "$win.frame2.scrollbar set"] -side left -fill both -expand 1
			pack [ttk::scrollbar $win.frame2.scrollbar	\
				-orient vertical 			\
				-command "$win.frame2.text yview"	\
			] -side right -fill y

			# Insert list of unopened files into the text widgets
			$win.frame2.text insert end [join $unopened_files "\n"]
			$win.frame2.text configure -state disabled

			bind $win.frame2.text <1> "focus $win.frame2.text"

			# Create button "Ok"
			pack [ttk::button $win.but_ok	\
				-text [mc "Ok"]		\
				-compound left		\
				-image ::ICONS::16::ok	\
				-command 	"
					grab release $win
					destroy $win
				"	\
			] -side bottom

			# Dialog event bindings
			bind $win <Return> "
				grab release $win
				destroy $win
			"
			bind $win <KP_Enter> "
				grab release $win
				destroy $win
			"
			bind $win <Escape> "
				grab release $win
				destroy $win
			"

			# Set window attributes
			wm iconphoto $win ::ICONS::16::status_unknown
			wm transient $win .
			wm title $win [mc "File(s) not found"]
			wm geometry $win 500x200
			wm protocol $win WM_DELETE_WINDOW [list destroy $win]
			update
			raise $win
		}

		# Invoke dialog "File(s) changed"
		if {$changed_files != {}} {
			# Create dialog toplevel window
			set win [toplevel .changed_files$obj_idx -class {File changed} -bg ${::COMMON_BG_COLOR}]

			# Create dialog header
			pack [frame $win.frame1] -side top -fill x -anchor nw
			pack [label $win.frame1.image -image ::ICONS::32::messagebox_info]	\
				-anchor nw -expand 0 -side left -padx 10 -pady 5
			pack [label $win.frame1.header	\
				-text [mc "The following files were modified since last save:"]	\
			] -side left -fill x

			# Create text widget and scrollbar
			pack [frame $win.frame2] -side top -expand 1 -fill both -pady 3 -padx 5
			pack [text $win.frame2.text -height 0 -width 0	\
				-yscrollcommand "$win.frame2.scrollbar set"] -side left -fill both -expand 1
			pack [ttk::scrollbar $win.frame2.scrollbar	\
				-orient vertical			\
				-command "$win.frame2.text yview"	\
			] -side right -fill y

			# Insert info about changed files
			foreach file $changed_files {
				if {[file exists $file_path$file_name]} {
					set time [clock format [file mtime $file_path$file_name] -format {%T %D}]
				} else {
					set time "  -----\t"
				}
				$win.frame2.text insert end "$time\t$file\n"
			}
			$win.frame2.text configure -state disabled

			bind $win.frame2.text <1> "focus $win.frame2.text"

			# Create button "Ok"
			pack [ttk::button $win.but_ok	\
				-text [mc "Ok"]		\
				-compound left		\
				-image ::ICONS::16::ok	\
				-command "
					grab release $win
					destroy $win
				"	\
			] -side bottom -pady 5

			# Set dialog event bindings
			bind $win <Return> "
				grab release $win
				destroy $win
			"
			bind $win <KP_Enter> "
				grab release $win
				destroy $win
			"
			bind $win <Escape> "
				grab release $win
				destroy $win
			"

			# Set window attributes
			wm minsize $win 200 100
			wm transient $win .
			wm iconphoto $win ::ICONS::16::info
			wm title $win [mc "File(s) changed"]
			wm geometry $win 500x200
			wm protocol $win WM_DELETE_WINDOW [list destroy $win]
			update
			raise $win
		}
	}

	## Open file at the given location and with some additional options
	 # Alogorithm:
	 #	* check if the file exists, if it doesn't then invoke an error message
	 #	* if the file exists then open it and read its content
	 #	* if the specified file path is an empty string then consider that file as a new one
	 #	* check if that file in not already opened and if it is then focus on it and return
	 #	* register that file in the class's internal variables
	 #	* create a new editor for that file and eventualy display content of the file
	 #	* focus on that newly created editor
	 #
	 # @parm String file_path	- full file name including path, {} means create a new one
	 # @parm Bool ask		- ask user about adding the file to the project
	 # @parm String parent		- path to the parent widget (eg. dialog which invoked this procedure)
	 # @parm String enc		- Character encoding
	 # @parm String eol		- End of Line character identifier (one of {lf crlf cr})
	 # @parm Bool read_only		- Read only flag
	 # @parm Bool fast		- Open the file as fast as possible (only for creating new files)
	 # sh
	 # @return String		- descriptor of the opened file
	public method openfile {file_path ask parent enc eol read_only fast sh} {
		set newfile 0	;# Bool: created new virtual file

		# Open an existing file
		if {$file_path != {}} {
			# Report error if the file does not exist
			if {
				!${::Editor::editor_to_use} && (
					![file exists $file_path]	||
					![file isfile $file_path]	||
					(!$::MICROSOFT_WINDOWS && ![file readable $file_path])
				)
			} then {
				tk_messageBox						\
					-parent .					\
					-type ok					\
					-title [mc "File not found - MCU 8051 IDE"]	\
					-message [mc "File %s not found !" $file_path]	\
					-icon error
				set newfile 1
			}

			# determine the filename
			regexp {[^\\\/]+$} $file_path file_name

		# Create a new file (untitled)
		} else {
			if {![regexp {untitled\d*} $file_descriptors]} {
				set untitled_num -1
			}
			if {$untitled_num == -1} {
				set file_name "untitled"
			} else {
				set file_name "untitled$untitled_num"
			}
			incr untitled_num
			set newfile 1
		}
		if {$file_name == {.#special:tmp}} {
			if {![regexp {untitled\d*} $file_descriptors]} {
				set untitled_num -1
			}
			if {$untitled_num == -1} {
				set file_name "untitled"
			} else {
				set file_name "untitled$untitled_num"
			}
			incr untitled_num
			set newfile 1
		}


		if {!$newfile} {
			# Check if the file isn't dangerously large
			set file_size [file size $file_path]
			if {$file_size > 10485760} {
				if {[tk_messageBox	\
					-parent .	\
					-type yesno	\
					-default no	\
					-icon warning	\
					-title [mc "Dangerously large file!"] \
					-message [mc "WARNING: The file you are about to open is larger than 10MB!\n\nOpening extremely big source code files might lead your system to run out of operating memory, then the MCU 8051 IDE might got killed by the operating system!\n\nARE YOU SURE you want to proceed?"] \
				] != {yes}} then {
					return {}
				}
			}

			# Check if the file isn't already opened
			set idx 0
			foreach editor $editors {
				if {[$editor cget -fullFileName] == $file_path} {
					set item [lindex $file_descriptors $idx]
					$listbox_opened_files selection set $item
					switchfile
					set lastItem $item
					Sbar [mc "File: %s is already opened." $file_path]
					return {}
				}
				incr idx
			}
		}

		# Adjust arguments 'eol' and 'enc'
		if {$eol == {def}} {
			set eol $default_eol
		}
		if {$enc == {def}} {
			set enc $default_encoding
		}

		# Determinate unique file descriptor
		set file_descriptor [regsub -all {_} $file_name {__}]
		set file_descriptor [regsub -all {\.} $file_descriptor {_}]
		set file_descriptor [regsub -all -- {-} $file_descriptor {--}]
		set file_descriptor [regsub -all -- {\s} $file_descriptor {-}]
		# Handle similar file descriptors of different files
		while {1} {
			if {[lsearch $file_descriptors $file_descriptor] != -1} {
				append file_descriptor {_}
			} else {
				break
			}
		}

		# Register the file descriptor
		lappend file_descriptors $file_descriptor
		# Insert filename into ListBox of opened files
		$listbox_opened_files insert end $file_descriptor	\
			-text $file_name -data $file_path -font $icon_border_font
		if {[llength $opened_files_bookmarks]} {
			$listbox_opened_files_bm insert end "\n"
		}
		lappend opened_files_bookmarks 0

		if {$ask} {
			# test if the file isn't already included in the project
			set item [getItemNameFromProjectList $file_path]
			if {$item != {}} {
				set ask 0
			}

			if {!$ask} {
				$listbox_project_files itemconfigure $item	\
					-font $opened_file_font			\
					-fg {#000000}				\
					-data [list $file_path $eol $enc $read_only]
			}
		}

		if {$ask && $::FileList::ask__append_file_to_project} {
			# Ask for append the file to the project
			set ::FileList::dialog_response 0
			set win [toplevel .append_to_the_project_dialog]

			set top_frame [frame $win.top]
			pack [label $top_frame.img -image ::ICONS::32::help] -side left -padx 5
			pack [label $top_frame.txt	\
				-justify left		\
				-text [mc "Do you want to add this file to the project ?\n%s" $file_name] \
			] -side left -padx 5
			set chb [checkbutton $win.chb					\
				-text [mc "Do not ask again"]				\
				-onvalue 0						\
				-offvalue 1						\
				-variable ::FileList::ask__append_file_to_project	\
			]
			set bottom_frame [frame $win.bottom]
			pack [ttk::button $bottom_frame.button_yes	\
				-text [mc "Yes"] -compound left		\
				-image ::ICONS::16::ok			\
				-command "
					set ::FileList::dialog_response 1
					grab release $win
					destroy $win" \
			] -side left -padx 2 -pady 5
			bind $bottom_frame.button_yes <Return> "
				set ::FileList::dialog_response 1
				grab release $win
				destroy $win"
			bind $bottom_frame.button_yes <KP_Enter> "
				set ::FileList::dialog_response 1
				grab release $win
				destroy $win"
			pack [ttk::button $bottom_frame.button_no		\
				-text [mc "No"] -compound left			\
				-image ::ICONS::16::button_cancel		\
				-command "grab release $win; destroy $win"	\
			] -side left -padx 2 -pady 5
			bind $bottom_frame.button_no <KP_Enter> "grab release $win; destroy $win"
			bind $bottom_frame.button_no <KP_Enter> "grab release $win; destroy $win"

			# Pack window frames
			pack $top_frame -fill x -padx 5 -pady 10
			pack $chb -anchor e -padx 5
			pack $bottom_frame -pady 10

			# Set window attributes
			wm iconphoto $win ::ICONS::16::help
			wm title $win [mc "Add file ?"]
			wm resizable $win 0 0
			wm transient $win .
			catch {grab $win}
			wm protocol $win WM_DELETE_WINDOW "
				grab release $win
				destroy $win
			"
			raise $win
			update
			focus -force $bottom_frame.button_yes
			tkwait window $win

			if {$::FileList::dialog_response } {
				if {[llength $project_files_bookmarks]} {
					$listbox_project_files_bm insert end "\n"
				}
				lappend project_files_bookmarks 0
				$listbox_project_files insert end #auto		\
					-font $opened_file_font -fill {#000000}	\
					-text $file_name -data [list $file_path $eol $enc $read_only]
			}
		}

		# Create editor object for the file
		if {$file_path != {}} {
			set data {}
			if {!${::Editor::editor_to_use}} {
				set file [open $file_path]
				fconfigure $file -encoding $enc
				if {[regsub -all {[\u0000-\u0008\u000B-\u000C\u000E-\u001F\u007F-\u009F]} [read $file] {} data]} {
					tk_messageBox		\
						-parent .	\
						-type ok	\
						-icon warning	\
						-title [mc "Binary File Opened - MCU 8015 IDE"]	\
						-message [mc "The file %s is binary, saving it will result corrupted file." $file_path]
				}
				close $file
			}

			set editor [Editor "::editor${file_count}_$obj_idx"				\
				[expr {!$fast}] $eol $enc $read_only $file_switching_enabled $this	\
				$file_name $file_path "$this editor_procedure {} "			\
				[regsub -all {\r\n?} $data "\n"] $sh					\
			]
		} else {
			set editor [Editor "::editor${file_count}_$obj_idx"				\
				[expr {!$fast}] $eol $enc $read_only $file_switching_enabled $this	\
				$file_name $file_path "$this editor_procedure {} " {} $sh		\
			]
		}

		# Determinate file type and set appropriate icon
		set ext [string trimleft [file extension $file_name] {.}]
		if {$ext == {h}} {
			set icon {source_h}
		} elseif {$ext == {c}} {
			set icon {source_c}
		} elseif {$ext == {cxx} || $ext == {cpp} || $ext == {cc}} {
			set icon {source_cpp}
		} elseif {$ext == {asm}} {
			set icon {asm}
		} else {
			set icon {ascii}
		}
		$filetabs_nb insert end $file_descriptor		\
			-text $file_name -image ::ICONS::16::$icon	\
			-raisecmd [list $this switch_file_from_filetabs $file_descriptor]
		$filetabs_nb see $file_descriptor

		# Conditionaly show Line Numbers and Icon Border
		if {$iconBorder == 0} {
			$editor hideLineNumbers
		}
		if {$lineNumbers == 0} {
			$editor hideIconBorder
		}

		if {$sh == {}} {
			set sh [$editor get_language]
		}

		# Editor text widget
		lappend editor_wdgs [$editor cget -editor]
		# Register Editor's object and widget and its frame
		lappend editors $editor
		lappend file_eol $eol
		lappend file_encoding $enc
		lappend file_ro_mode $read_only
		lappend file_sh $sh

		# Add editor to right panel
		rightPanel_add_Editor [expr {!$fast}]
		$this todo_add_Editor {}
		$this todo_change_filename end $file_name
		$editor goto 1

		# Increment counter of opened files
		incr file_count
		# Return descriptor of the file
		return $file_descriptor
	}

	## Switch file from filetabs notebook
	 # @parm String page - Page ID
	 # @return void
	public method switch_file_from_filetabs {page} {
		$listbox_opened_files selection set $page
		switchfile
	}

	## Show file details window from files tab (or something ...)
	 # $filetabs_nb bindtabs <Enter> "$this file_details_win_create_from_ftnb"
	 # @parm String page - Page ID
	 # @return void
	public method file_details_win_create_from_ftnb {page} {
		$this file_details_win_create O $page
	}

	## Invoke popup menu for specific file from files tab (or something ...)
	 # $filetabs_nb bindtabs <ButtonRelease-3> "$this filetabs_nb_popup_menu %X %Y"
	 # @parm Int X		- X coordinate
	 # @parm Int Y		- Y coordinate
	 # @parm String page	- Page ID
	 # @return void
	public method filetabs_nb_popup_menu {X Y page} {
		switch_file_from_filetabs $page

		tk_popup $filetabs_pu_menu $X $Y
	}

	## Save currently opened file under a given filename
	 # note: should be used only for saving untitled files !
	 # @parm String filename	- Full file name including path
	 # @parm Bool keep_extension	- Do not alter file extension by assuming that file with no extension should end with ".asm"
	 # @return Bool			- 1: (maybe) successful; 0: argument is empty
	public method save_as {filename {keep_extension 0}} {

		# Handle empty argument
		if {$filename == {}} {return 0}

		# Adjust filename
		if {!$::MICROSOFT_WINDOWS} {	;# POSIX way
			if {![regexp "^(~|/)" $filename]} {
				set filename "[$this cget -ProjectDir]/$filename"
			}
		} else {	;# Microsoft windows way
			if {![regexp {^\w:} $filename]} {
				set filename [file join [$this cget -ProjectDir] $filename]
			}
		}
		set filename [file normalize $filename]
		if {!$keep_extension} {
			if {[file extension $filename] == {}} {
				append filename {.asm}
			}
		}
		# Determinate file rootname
		set rootname [file tail $filename]

		# Ask user for overwrite existing file
		if {[file exists $filename] && [file isfile $filename]} {
			if {[tk_messageBox	\
				-type yesno	\
				-icon question	\
				-parent .	\
				-title [mc "Overwrite file"]	\
				-message [mc "A file name '%s' already exists. Are you sure you want to overwrite it ?" $rootname]
				] != {yes}
			} then {
				return 1
			}
		}

		# Change filename in the listbox of opened files
		set item [$listbox_opened_files selection get]
		$listbox_opened_files itemconfigure $item -text $rootname -data $filename
		$filetabs_nb itemconfigure $item -text $rootname

		# Determinate some additional informations
		if {$splitted && $selectedView} {
			set idx $actualEditor2
		} else {
			set idx $actualEditor
		}
		set editor [lindex $editors $idx]
		set fullFileName	[$editor cget -fullFileName]	;# Original full filename
		set original_rootname	[$editor cget -filename]	;# Original file rootname

		# Mark the file as opened (in listbox of project files)
		set already_in_project 0
		foreach item [$listbox_project_files items] {
			if {[$listbox_project_files itemcget $item -text] != $original_rootname} {
				continue
			}
			set data [$listbox_project_files itemcget $item -data]
			if {[llength $data] > 4} {continue}
			if {[lindex $data 0] != $fullFileName} {continue}
			lset data 0 $filename
			$listbox_project_files itemconfigure $item -data $data -text $rootname
			set already_in_project 1
		}

		# Set new file name
		$editor set_FileName $filename $rootname
		$editor save
		$this todo_change_filename $idx $rootname

		# Ask for appending the file to the project
		if {!$already_in_project} {
			set response [tk_messageBox		\
				-title [mc "Add file ?"]	\
				-icon question			\
				-type yesno			\
				-parent $parent			\
				-message [mc "Do you want to add this file to the project ?\n%s" $rootname]
			]
			if {$response == {yes}} {
				filelist_append_to_prj
			}
		}

		::X::recent_files_add 1 $filename

		# Done ...
		return 1
	}


	# ---------------------------------------------------------------------
	# EDITOR FUNCTIONS
	# ---------------------------------------------------------------------

	## Show/Hide line numbers
	 # @return void
	public method show_hide_lineNumbers {} {
		if {$lineNumbers} {
			set lineNumbers 0
			foreach editor $editors {$editor hideLineNumbers}
		} else {
			set lineNumbers 1
			foreach editor $editors {$editor showLineNumbers}
		}
	}

	## Show/Hide icon border
	 # @return void
	 public method show_hide_IconBorder {} {
		if {$iconBorder} {
			set iconBorder 0
			foreach editor $editors {$editor hideIconBorder}
		} else {
			set iconBorder 1
			foreach editor $editors {$editor showIconBorder}
		}
	}

	## Get number of lines in the current editor
	 # @return Int - result
	public method editor_linescount {} {
		if {$splitted && $selectedView} {
			set tmp $actualEditor2
		} else {
			set tmp $actualEditor
		}
		set tmp [expr {int([[[lindex $editors $tmp] cget -editor] index end])}]
		return [expr {$tmp-1}]
	}

	## Get number of line with the insertion cursor
	 # @return Int - result
	public method editor_actLineNumber {} {
		if {$splitted && $selectedView} {
			set idx $actualEditor2
		} else {
			set idx $actualEditor
		}
  		return [expr {int([[lindex $editor_wdgs $idx] index insert])}]
	}

	## Call any editor procedure
	 # @parm Int objectNumber	- Number of editor object to use, {} mean current editor
	 # @parm String procedure	- name of the procedure
	 # @parm String arguments	- list of arguments to pass that procedure
	 # @retrurn mixed - result of invoked procedure
	public method editor_procedure {objectNumber procedure arguments} {
		# Determinate editor number
		if {$objectNumber == {}} {
			if {$splitted && $selectedView} {
				set objectNumber $actualEditor2
			} else {
				set objectNumber $actualEditor
			}
		}
		# Call editor procedure
		set editor [lindex $editors $objectNumber]
		if {$editor == {}} {
			switch_to_last
			update
		}
		return [eval "$editor $procedure $arguments"]
	}

	## Compare two tag ranges (text widget tags)
	 # @parm TextIndex first	- 1st text tag range to compare {TextIndex Bool__Start_or_End}
	 # @parm TextIndex second	- 2nd text tag range to compare {TextIndex Bool__Start_or_End}
	 # @return Int - result (on of {-1 0 1})
	proc editor__sort_tag_ranges {first second} {

		# Local variables
		set idx0 [split [lindex $first 0] {.}]	;# Adjusted 1st text index -- list: {Row Column}
		set row0 [lindex $idx0 0]		;# Row		(1st index)
		set col0 [lindex $idx0 1]		;# Column	(1st index)
		set idx1 [split [lindex $second 0] {.}]	;# Adjusted 2nd text index -- list: {Row Column}
		set row1 [lindex $idx1 0]		;# Row		(2nd index)
		set col1 [lindex $idx1 1]		;# Column	(2nd index)
		set StartEnd0 [lindex $first 2]		;# Bool: Start_or_End (1st index)
		set StartEnd1 [lindex $second 2]	;# Bool: Start_or_End (2nd index)

		# Compare rows
		if {$row0 > $row1} {
			return -1
		} elseif {$row0 < $row1} {
			return 1
		}

		# Compare columns
		if {$col0 > $col1} {
			return -1
		} elseif {$col0 < $col1} {
			return 1
		}

		# Compare "Start_or_End" flags
		if {!$StartEnd0 && $StartEnd1} {
			return 1
		} elseif {$StartEnd0 && !$StartEnd1} {
			return -1
		} else {
			return 0
		}
	}

	## Get list of project files
	 # @return List - result
	public method get_project_files_list {} {
		## Local variables
		 # List header
		if {$splitted} {
			set _actualEditor2 $actualEditor2
		} else {
			set _actualEditor2 -1
		}
		if {$splitted} {
			if {$pwin_orient == {vertical}} {
				set idx 1
			} else {
				set idx 0
			}
			set multiview_sash_pos [lindex [$multiview_paned_win sash coord 0] $idx]
		}
		set file_list [list			\
			[llength $editors]		\
			[list				\
				$actualEditor		\
				$_actualEditor2		\
				$multiview_sash_pos	\
				$pwin_orient		\
				$selectedView		\
			]				\
		]
		 # Project directory
		set project_path [$this cget -projectPath]
		append project_path {/}
		 # Lenght of the project directory path string
		set project_path_length [string length $project_path]
		 # Opened files index
		set opened_i 0

		## Create list of full paths of opened files (in order of listbox of opened files)
		set opened_files {}
		foreach item [$listbox_opened_files items] {
			set file_path [$listbox_opened_files itemcget $item -data]
			if {$file_path == {}} {continue}
			lappend opened_files $file_path
		}

		# Iterate over items of ListBox of project files
		set i -1
		foreach item [$listbox_project_files items] {
			incr i

			# Determinate item data
			set data [$listbox_project_files itemcget $item -data]

			# Unopened file
			if {[llength $data] > 4} {
				# Set opened flag
				lset data 1 {no}
				# Set file path
				set path [lindex $data 5]
				if {$::MICROSOFT_WINDOWS} { ;# "\" --> "/"
					regsub -all "\\\\" $path {/} path
				}
				if {[string first $project_path $path] == 0} {
					lset data 5 [string range $path $project_path_length end]
				}

				# Append o-bookmark=0, p-bookmark=$bm and file index=0
				set data [linsert $data 2 0 [lindex $project_files_bookmarks $i] 0]

				# Append file record to the resulting list
				lappend file_list $data

			# Opened file
			} else {
				# Find the file in list of opened files
				foreach editor $editors {
					# Local variables
					set file_name [$editor cget -fullFileName]	;# Full file name

					if {$file_name != [lindex $data 0]} {continue}

					# Determinate true item data
					set data [getFileInfo $editor {yes}]

					# Set file path
					set path [lindex $data 5]
					if {$::MICROSOFT_WINDOWS} { ;# "\" --> "/"
						regsub -all "\\\\" $path {/} path
					}
					if {[string first $project_path $path] == 0} {
						lset data 5 [string range $path $project_path_length end]
					}

					# Determinate index in Listbox of opened files
					set index [lsearch $opened_files $file_name]

					# Append o-bookmark, p-bookmark and file index
					set data [linsert $data 2			\
						[lindex $opened_files_bookmarks $index]	\
						[lindex $project_files_bookmarks $i]	\
						$index]

					# Append encoding and EOL info
					lappend data					\
						[lindex $file_eol $opened_i]		\
						[lindex $file_encoding $opened_i]	\
						[lindex $file_sh $opened_i]		\
						[$this get_file_notes_data $i]

					incr opened_i

					# Append file record to the resulting list
					lappend file_list $data
				}
			}
		}

		# Return the file list
		return $file_list
	}

	## Get opened file item data to use in filelists
	 # @see get_project_files_list
	 # @see editor_close
	 # @parm Object editor	- Reference to editor object
	 # @parm String active	- Active flag
	 # @return List - resulting data or '{}'
	private method getFileInfo {editor active} {
		# Determinate full file name
		set file_name [$editor cget -fullFileName]
		if {$file_name == {}} {return {}}

		# Determinate file rootname, path and MD5 hex hash
		regexp {[^\\\/]*$} $file_name name
		regexp {^.*[\\\/]} $file_name path
		if {[catch {
			set md5_hash [md5::md5 -hex -hex -file $file_name]
		}]} then {
			set md5_hash {}
		}

		set actual_line		[$editor get_current_line_number]	;# Current line
		set line_markers	[$editor export_line_markers_data]	;# bookmarks and breakpoints
		set bookmarks		[lindex $line_markers 0]		;# Bookmarks
		set breakpoints		[lindex $line_markers 1]		;# Breakpoints

		# Return result
		return [list							\
			$name		$active		[$editor cget -ro_mode]	\
			$actual_line	$md5_hash	$path			\
			$bookmarks	$breakpoints				\
		]
	}

	## Invoke dialog "Open file" (require NS 'X')
	 # @return void
	public method editor_open {} {
		X::__open
	}

	## Save the current file
	 # @return void
	public method editor_save {} {
		if {$splitted && $selectedView} {
			[lindex $editors $actualEditor2] save
		} else {
			[lindex $editors $actualEditor] save
		}
	}

	## Save current file under a different name (reires NS 'X')
	 # @return void
	public method editor_save_as {} {
		X::__save_as
	}

	## Call procedure save for each editor object in the current project
	 # note: in other words save all opened files
	 # @return void
	public method editor_save_all {} {
		foreach editor $editors {
			$editor save
		}
	}

	## Create a new empty editor object inside the project and focus on it
	 # @return void
	public method editor_new {} {
		openfile {} 0 . def def 0 1 {}
		switch_to_last
		set editor [lindex $editors end]
		update
		$editor create_highlighting_tags
		update
		rightPanel_add_Editor__create_menu_and_tags
		$editor parseAll
		focus [$editor cget -editor]
	}

	## Open a new editor containing the given data
	 # @parm String data - Data to insert into the editor
	 # @return void
	public method background_open {data} {
		if {!${::Editor::editor_to_use}} {
			openfile {} 0 . def def 0 0 {}
			set editor [lindex $editors end]
			$editor insertData $data {}
			[$editor cget -editor] edit modified 0
			[$editor cget -editor] edit reset
		} else {
			set dir [${::X::actualProject} cget -ProjectDir]
			catch {
				file delete -force -- [file join $dir .#special:tmp]
			}

			set file [open [file join $dir .#special:tmp] w 0640]
			puts -nonewline $file $data
			close $file

			openfile [file join $dir .#special:tmp] 0 . def def 0 0 {}
		}
	}

	## Close the current editor and optionaly save its data to some file
	 # note: if this procedure was executed to destroy the last
	 #	 remainig editor then a new one would be created !!!
	 # @parm Bool ask	- Ask user for saving the file (if was modified)
	 # @parm Int editorIdx	- number of editor to close, {} mean currently active editor
	 # @return Bool		- Created a new editor ?
	public method editor_close {ask editorIdx} {
		if {$editor_close_in_progress} {return}
		set editor_close_in_progress 1

		# Determinate editor object reference
		if {$editorIdx == {}} {
			if {$splitted && $selectedView} {
				set editorIdx $actualEditor2
			} else {
				set editorIdx $actualEditor
			}
		} else {
			if {$editorIdx == $actualEditor} {
				set selectedView 0
			} elseif {$editorIdx == $actualEditor2} {
				set selectedView 1
			}
		}
		set editor [lindex $editors $editorIdx]

		# Ask user for saving the file (if was modified)
		if {$ask && [$editor cget -modified]} {
			set response [tk_messageBox				\
				-parent .					\
				-type yesnocancel				\
				-title [mc "Close document - MCU 8051 IDE"]	\
				-icon question					\
				-default yes					\
				-message [mc "The document %s has been modified.\nDo you want to save it ?" [file tail [[lindex $editors $editorIdx] cget -fullFileName]]]]

			if {$response == {yes}} {
				$editor save
			} elseif {$response == {cancel}} {
				set editor_close_in_progress 0
				return {}
			}
		}

		# Mark the file as unopened (in ListBox of project fies)
		set items		[$listbox_project_files items]	;# List of project files
		set fullFileName	[$editor cget -fullFileName]	;# Full filename of the current file
		set rootname		[$editor cget -filename]	;# Rootname of the current file
		foreach item $items {
			if {[$listbox_project_files itemcget $item -text] != $rootname} {
				continue
			}
			set data [$listbox_project_files itemcget $item -data]
			if {[llength $data] > 4} {continue}

			if {[lindex $data 0] == $fullFileName} {
				$listbox_project_files itemconfigure $item	\
					-fg {#888888}				\
					-font $closed_file_font			\
					-data [concat					\
						[getFileInfo $editor {no}]		\
						[lindex $file_eol $editorIdx]		\
						[lindex $file_encoding $editorIdx]	\
						[lindex $file_sh $editorIdx]		\
						[$this get_file_notes_data $editorIdx]	\
					]
			}
		}

		# Delete editor object and all its widgets
		set file_descriptor [lindex $file_descriptors $editorIdx]
		set item_index [$listbox_opened_files index $file_descriptor]
		$listbox_opened_files delete $file_descriptor
		$listbox_opened_files_bm delete [expr {$item_index + 1}].0 [expr {$item_index + 2}].0
		set opened_files_bookmarks [lreplace $opened_files_bookmarks $item_index $item_index]
		delete object $editor
		rightPanel_remove_Editor $editorIdx
		$this todo_remove_editor $editorIdx

		$filetabs_nb delete $file_descriptor

		# Adjust object variables
		foreach var {editors file_descriptors editor_wdgs file_eol file_encoding file_ro_mode file_sh} {
			set $var [lreplace [subst -nocommands "\$$var"] $editorIdx $editorIdx]
		}
		if {$actualEditor == $editorIdx} {
			set actualEditor {x}
		} elseif {$actualEditor > $editorIdx} {
			incr actualEditor -1
		}
		if {$actualEditor2 == $editorIdx} {
			set actualEditor2 {x}
		} elseif {$actualEditor2 > $editorIdx} {
			incr actualEditor2 -1
		}
		if {$actualEditor == {x} || $actualEditor2 == {x}} {
			set do_not_forget_editor 1
			if {$actualEditor == {x}} {
				set actualEditor -1
			}
			if {$actualEditor2 == {x}} {
				set actualEditor2 -1
			}

			# Conditionaly open a new editor
			if {$splitted} {
				set min 2
			} else {
				set min 1
			}
			if {[llength $file_descriptors] < $min} {
				if {$min == 1} {
					set file_count 0
				}
				Sbar [mc "Last editor window closed -> opening a new one ..."]
				editor_new
				set editor_close_in_progress 0
				return 1
			}
			# Switch to last editor in the list
			switch_to_last
		}

		set editor_close_in_progress 0
		return 1
	}

	## Close all editors in the list of opened files
	 # @parm Bool allowCancelButton	- Display button "Cancel" in dialog "Save multiple files"
	 # @parm Bool projectClose	- Should be 1 if closing project
	 # @return Bool - 1: all have been done smoothly; 0: user has been asked about modified files
	public method editor_close_all {allowCancelButton projectClose} {
		# Determinate number of editors to close
		set editorCount [llength $file_descriptors]

		# Create list of the modified ones
		set unsaved {}
		foreach editor $editors {
			if {[$editor cget -modified]} {
				lappend unsaved $editor
			}
		}

		# Ask user for file save
		if {$unsaved != {}} {
			save_multiple_files $allowCancelButton
			return 0
		} else {
			if {!$projectClose} {
				editor_force_close_all
			}
			return 1
		}
	}

	## Close all opened files without any warning
	 # @return void
	public method editor_force_close_all {} {
		# Determinate number of editors
		set editorMaxIdx [llength $file_descriptors]
		set editorMaxIdx [expr {$editorMaxIdx - 1}]

		# Close editors
		for {set i $editorMaxIdx} {$i >= 0} {incr i -1} {
			editor_close 0 $i
		}
	}

	## Create special dialog to ask user which files should be saved
	 # Intended for closing multiple files
	 # note: * Using class variable 'unsaved' instead of any argument !!!
	 #	 * Depend on methods:   save_multiple_files_DESTROY, save_multiple_files_CANCEL,
	 #				save_multiple_files_SAVEALL, save_multiple_files_SAVESELECTED
	 # @parm allowCancelButton bool - 1: show 'Cancel' button; 0: nothing
	 # @return void
	public method save_multiple_files {allowCancelButton} {

		# Create a new toplevel window for the dialog
		set dialog .save_multiple_files
		toplevel $dialog

		# Create the top part of dialog (Header and some icon)
		pack [frame $dialog.topframe] -fill x -expand 1
		pack [label $dialog.topframe.image -image ::ICONS::32::fileclose] -side left -padx 10
		pack [label $dialog.topframe.message \
			-text [mc "The following documents have been modified,\ndo you want to save them before closing ?"] \
		] -side right -fill x -expand 1

		# Create the middle part of the dialog (list of unsaved files)
		pack [ttk::labelframe $dialog.lf	\
			-text [mc "Unsaved files"]	\
		] -fill both -expand 1 -pady 10 -padx 10
		set i 0
		foreach editorObj $unsaved {
			pack [checkbutton $dialog.lf.chb$i		\
				-text [$editorObj cget -filename]	\
				-variable unsavedfile$i			\
				-image ::ICONS::16::kcmdf		\
				-compound left				\
			] -anchor w -padx 10
			incr i
		}

		# Create the bottom part of the dialog (buttons "Save selected", "Save all" etc.)
		pack [ttk::separator $dialog.separator -orient horizontal] -fill x -expand 1
		pack [frame $dialog.f]
		# SAVESELECTED
		pack [ttk::button $dialog.f.b_save_selected					\
			-text [mc "Save selected"]						\
			-compound left								\
			-image ::ICONS::16::filesave						\
			-command {${::X::actualProject} save_multiple_files_SAVESELECTED}	\
		] -side left
		# SAVEALL
		pack [ttk::button $dialog.f.b_save_all					\
			-text [mc "Save all"]						\
			-compound left							\
			-image ::ICONS::16::save_all					\
			-command {${::X::actualProject} save_multiple_files_SAVEALL}	\
		] -side left
		# DESTROY
		pack [ttk::button $dialog.f.b_discard					\
			-text [mc "Discard"]						\
			-compound left							\
			-image ::ICONS::16::editdelete					\
			-command {${::X::actualProject} save_multiple_files_DESTROY}	\
		] -side left
		# CANCEL
		if {$allowCancelButton} {
			pack [ttk::button $dialog.f.b_cancel					\
				-text [mc "Cancel"]						\
				-compound left							\
				-image ::ICONS::16::button_cancel				\
				-command {${::X::actualProject} save_multiple_files_CANCEL}	\
			] -side left
		}

		# Set dialog attributes (modal window)
		wm iconphoto $dialog ::ICONS::16::exit
		wm title $dialog [mc "Close files - MCU 8051 IDE"]
		wm state $dialog normal
		wm minsize $dialog 350 200
		wm transient $dialog .
		wm protocol $dialog WM_DELETE_WINDOW "
			grab release $dialog
			destroy $dialog
		"
		update
		catch {
			grab $dialog
		}
		raise $dialog
		focus $dialog
		tkwait window $dialog
	}

	## Auxiliary procedure for method 'save_multiple_files'
	 # It should be executed on pressing button 'Save selected' dialog 'Save multiple files'
	 # This function saves all files selected in dialog 'Save multiple files'
	 # @return void
	public method save_multiple_files_SAVESELECTED {} {
		set i 0
		foreach editor $unsaved {
			set cnd [subst -nocommands "\${::unsavedfile$i}"]
			if {$cnd} {$editor save}
			incr i
		}
		save_multiple_files_DESTROY
	}

	## Auxiliary procedure for method 'save_multiple_files'
	 # It should be executed on pressing button 'Save all' dialog 'Save multiple files'
	 # @return void
	public method save_multiple_files_SAVEALL {} {
		foreach editor $unsaved {
			$editor save
		}
		save_multiple_files_DESTROY
	}

	## Auxiliary procedure for method 'save_multiple_files'
	 # It should be executed on pressing button 'Discard' in 'Save multiple files' dialog
	 # @return void
	public method save_multiple_files_DESTROY {} {
		set editorMaxIdx [llength $file_descriptors]
		set editorMaxIdx [expr {$editorMaxIdx - 1}]
		editor_force_close_all
		save_multiple_files_CANCEL
	}

	## Auxiliary procedure for method 'save_multiple_files'
	 # It should be executed on pressing button 'Cancel' in 'Save multiple files' dialog
	 # @return void
	public method save_multiple_files_CANCEL {} {
		destroy .save_multiple_files
	}

	## Reevaluate state of buttons on icon bar in tab LProject files
	 # @return void
	public method FileList_project_disEna_buttons {} {

		# Determinate selected item
		set item [$listbox_project_files selection get]

		# Non empty selection
		if {$item != {}} {
			${project_files_buttonBox}remove	configure -state normal
			${project_files_buttonBox}bookmark	configure -state normal

			# Simulator engaged
			if {$frozen} {
				${project_files_buttonBox}close	configure -state disabled
				${project_files_buttonBox}open	configure -state disabled

			# Simulator disengaged
			} else {
				# Opened file
				if {[llength [$listbox_project_files itemcget $item -data]] < 5} {
					${project_files_buttonBox}close	configure -state normal
					${project_files_buttonBox}open	configure -state disabled

				# Unopened file
				} else {
					${project_files_buttonBox}close	configure -state disabled
					${project_files_buttonBox}open	configure -state normal
				}
			}

		# Nothing selected
		} else {
			${project_files_buttonBox}remove	configure -state disabled
			${project_files_buttonBox}open		configure -state disabled
			${project_files_buttonBox}close		configure -state disabled
			${project_files_buttonBox}bookmark	configure -state disabled
		}
	}

	## Invoke project files popup menu
	 # @parm Int X		- relative X coordinate
	 # @parm Int Y		- relative Y coordinate
	 # @return void
	public method fileList_project_filelist_popup {X Y} {
		if {$item_menu_invoked} {
			set item_menu_invoked 0
			return
		}

		foreach entry {
			{Remove file from the project}	{Close file}		{Open file}
			{Bookmark}			{Move up}		{Move down}
			{Move to top}			{Move to bottom}	{Open with}
		} {
			$project_files_menu entryconfigure [::mc $entry] -state disabled
		}

		tk_popup $project_files_menu $X $Y
	}

	## Invoke project files popup menu -- for particular item
	 # @parm Int X		- relative X coordinate
	 # @parm Int Y		- relative Y coordinate
	 # @parm String item	- ID of the current item
	 # @return void
	public method fileList_project_filelist_item_popup {X Y item} {
		set item_menu_invoked 1

		foreach entry {
			{Remove file from the project} {Bookmark}	{Open with}
		} {
			$project_files_menu entryconfigure [::mc $entry] -state normal
		}

		# It is not so easy to open the file with an external editor on Microsoft Windows as
		# it is on a POSIX system, that's why this feature is disabled here
		if {$::MICROSOFT_WINDOWS} {
			$project_files_menu entryconfigure [::mc {Open with}] -state disabled
		}

		# Adjust ListBox selection
		$listbox_project_files selection set $item

		# Opened file
		if {[llength [$listbox_project_files itemcget $item -data]] < 5} {
			if {!$frozen} {
				$project_files_menu entryconfigure [::mc "Close file"] -state normal
			}
			$project_files_menu entryconfigure [::mc "Open file"] -state disabled
		# Unopened file
		} else {
			if {!$frozen} {
				$project_files_menu entryconfigure [::mc "Close file"] -state disabled
			}
			$project_files_menu entryconfigure [::mc "Open file"] -state normal
		}

		# Movement commands
		if {[$listbox_project_files index $item] == 0} {
			set state disabled
		} else {
			set state normal
		}
		$project_files_menu entryconfigure [::mc "Move up"] -state $state
		$project_files_menu entryconfigure [::mc "Move to top"] -state $state

		if {[$listbox_project_files index $item] == ([llength [$listbox_project_files items]] - 1)} {
			set state disabled
		} else {
			set state normal
		}
		$project_files_menu entryconfigure [::mc "Move down"] -state $state
		$project_files_menu entryconfigure [::mc "Move to bottom"] -state $state

		# Invoke the menu
		tk_popup $project_files_menu $X $Y
	}

	## Move up current item in project filelist
	 # @return void
	public method filelist_prj_move_up {} {
		# Local variables
		set item [$listbox_project_files selection get]	;# Item ID
		set index [$listbox_project_files index $item]	;# Item index
		set target [expr {$index - 1}]			;# Target index

		# Check if the item can be moved
		if {$index == 0} {return}

		# Move item in listbox
		$listbox_project_files move $item $target
		# Move item in list of bookmarks and icon border
		if {[lindex $project_files_bookmarks $index] != [lindex $project_files_bookmarks $target]} {
			# Determinate bookmark flag for source and target index
			set trg_bm [lindex $project_files_bookmarks $target]
			set idx_bm [lindex $project_files_bookmarks $index]
			# Move item in list of bookmarks
			lset project_files_bookmarks $target [lindex $project_files_bookmarks $index]
			lset project_files_bookmarks $index $trg_bm
			# Move item in icon border
			incr target
			incr index
			$listbox_project_files_bm delete $index.0 [list $index.0 lineend]
			$listbox_project_files_bm delete $target.0 [list $target.0 lineend]
			if {$trg_bm} {
				$listbox_project_files_bm image create $index.0	\
					-image ::ICONS::16::bookmark		\
					-align center
			}
			if {$idx_bm} {
				$listbox_project_files_bm image create $target.0	\
					-image ::ICONS::16::bookmark		\
					-align center
			}
		}
	}

	## Move down current item in project filelist
	 # @return void
	public method filelist_prj_move_down {} {
		# Local variables
		set item [$listbox_project_files selection get]		;# Item ID
		set index [$listbox_project_files index $item]		;# Item index
		set items [llength [$listbox_project_files items]]	;# Number of items in listbox
		set target [expr {$index + 1}]				;# Target index

		# Check if the item can be moved
		if {$index == $items} {return}

		# Move item in listbox
		$listbox_project_files move $item $target
		# Move item in list of bookmarks and icon border
		if {[lindex $project_files_bookmarks $index] != [lindex $project_files_bookmarks $target]} {
			# Determinate bookmark flag for source and target index
			set trg_bm [lindex $project_files_bookmarks $target]
			set idx_bm [lindex $project_files_bookmarks $index]
			# Move item in list of bookmarks
			lset project_files_bookmarks $target [lindex $project_files_bookmarks $index]
			lset project_files_bookmarks $index $trg_bm
			# Move item in icon border
			incr target
			incr index
			$listbox_project_files_bm delete $index.0 [list $index.0 lineend]
			$listbox_project_files_bm delete $target.0 [list $target.0 lineend]
			if {$trg_bm} {
				$listbox_project_files_bm image create $index.0	\
					-image ::ICONS::16::bookmark		\
					-align center
			}
			if {$idx_bm} {
				$listbox_project_files_bm image create $target.0	\
					-image ::ICONS::16::bookmark		\
					-align center
			}
		}
	}

	## Move to top current item in project filelist
	 # @return void
	public method filelist_prj_move_top {} {
		# Determinate index of the current item
		set item [$listbox_project_files selection get]
		set index [$listbox_project_files index $item]

		# Check if the item can be moved
		if {$index == 0} {return}

		# Move item in listbox
		$listbox_project_files move $item 0
		# Move item in list of bookmarks
		set bm [lindex $project_files_bookmarks $index]
		set project_files_bookmarks [lreplace $project_files_bookmarks $index $index]
		set project_files_bookmarks [linsert $project_files_bookmarks 0 $bm]
		# Move item in icon border
		incr index
		$listbox_project_files_bm delete $index.0 $index.0+1l
		$listbox_project_files_bm insert 1.0 "\n"
		if {$bm} {
			$listbox_project_files_bm image create 1.0	\
				-image ::ICONS::16::bookmark	\
				-align center
		}
	}

	## Move to bottom current item in project filelist
	 # @return void
	public method filelist_prj_move_bottom {} {
		# Determinate index of the current item and end index
		set item [$listbox_project_files selection get]
		set index [$listbox_project_files index $item]
		set items [llength [$listbox_project_files items]]

		# Check if the item can be moved
		if {$index == $items} {return}

		# Move item in listbox
		$listbox_project_files move $item [expr {$items - 1}]
		# Move item in list of bookmarks
		set bm [lindex $project_files_bookmarks $index]
		set project_files_bookmarks [lreplace $project_files_bookmarks $index $index]
		lappend project_files_bookmarks $bm
		# Move item in icon border
		incr index
		set end [llength $project_files_bookmarks]
		$listbox_project_files_bm delete $index.0 $index.0+1l
		$listbox_project_files_bm insert $end.0 "\n"
		if {$bm} {
			$listbox_project_files_bm image create $end.0	\
				-image ::ICONS::16::bookmark	\
				-align center
		}
	}

	## Open file from ListBox of project files
	 # Takes any set of arguments and discards them
	 # @return void
	public method filelist_project_file_open args {
		if {$frozen} {return}

		# Local varibales
		set item [$listbox_project_files selection get]			;# Item ID
		set record [$listbox_project_files itemcget $item -data]	;# Item data

		# If the file is already opened -- abort
		if {[llength $record] == 4} {return}

		# Parse item data
		set ri 0
		foreach var {file_name active ro file_line file_md5 file_path file_BMs file_BPs eol enc sh notes} {
			set $var [lindex $record $ri]
			incr ri
		}

		# Check for file existence
		if {![file exists $file_path$file_name]} {
			tk_messageBox				\
				-title [mc "File not found"]	\
				-parent .			\
				-icon error			\
				-type ok			\
				-message [mc "File %s could not be located at the specified location." $file_name]
			return
		}

		# Verify file MD5 hash
		if {[catch {
			if {[md5::md5 -hex -file $file_path$file_name] != $file_md5} {
				tk_messageBox				\
					-icon warning			\
					-parent .			\
					-type ok			\
					-title [mc "File changed"]	\
					-message [mc "File \"%s\" was modified since last project save\nTime: %s" $file_name [clock format [file mtime $file_path$file_name] -format {%T %D}]]
			}
		}]} then {
			tk_messageBox				\
				-icon warning			\
				-parent .			\
				-type ok			\
				-title [mc "Unknown error"]	\
				-message [mc "Raised error during md5 checking file %s. Maybe md5 extension is not correctly loaded." $file_name]
		}

		# Open the file
		if {[openfile $file_path$file_name 0 . $enc $eol $ro 0 $sh] != {}} {
			set i [llength $editors]
			incr i -1
			set editor [lindex $editors $i]
			rightPanel_switch_editor $i
			$this todo_switch_editor $i
			$editor import_line_markers_data $file_BMs $file_BPs
			$editor goto $file_line
			switch_to_last
			incr i

			$this set_file_notes_data $notes
		}

		# Adjust listbox of opened files
		$listbox_project_files itemconfigure $item	\
			-font $opened_file_font -fg {#000000} -data [list $file_path$file_name $eol $enc $ro]

		# Reevaluate iconbar
		FileList_project_disEna_buttons
	}

	## Close file in ListBox of project files
	 # @return void
	public method filelist_project_file_close {} {
		# Determinate filename
		set item [$listbox_project_files selection get]
		set filename [$listbox_project_files itemcget $item -data]
		if {[llength $filename] > 4} {return}

		# Determinate editor index
		set filename [lindex $filename 0]
		set idx 0
		foreach editor $editors {
			if {[$editor cget -fullFileName] == $filename} {break}
			incr idx
		}

		# Close the editor
		editor_close 1 $idx
		FileList_project_disEna_buttons
	}

	## Remove file from the project ListBox
	 # @return void
	public method filelist_remove_file_from_project {} {
		# Determinate item ID
		set item [$listbox_project_files selection get]
		set index [$listbox_project_files index $item]
		# Remove item from the ListBox
		$listbox_project_files delete $item
		# Remove item from icon border and list of bookmarks
		$listbox_project_files_bm delete [expr {$index + 1}].0 [expr {$index + 2}].0
		set project_files_bookmarks [lreplace $project_files_bookmarks $index $index]
		# Select the next item
		set end [llength [$listbox_project_files items]]
		incr end -1
		if {$index > $end} {
			set index $end
		}
		if {$index != -1} {
			$listbox_project_files selection set	\
				[$listbox_project_files items $index]
		}
		# Reevaluate icon bar
		FileList_project_disEna_buttons
	}

	## Append the current file to the project
	 # @return void
	public method filelist_append_to_prj {} {
		# Index of the current file
		set idx [lsearch $file_descriptors [$listbox_opened_files selection get]]
		# Reference to editor object
		set editor [lindex $editors $idx]

		# Check if the file isn't already part of the project
		set fullFileName [$editor cget -fullFileName]
		if {$fullFileName == {} || [getItemNameFromProjectList $fullFileName] != {}} {
			return
		}

		# Adjust ListBox of project files
		$listbox_project_files insert end #auto	\
			-font $opened_file_font		\
			-fg {#000000}			\
			-text [$editor cget -filename]	\
			-data [list $fullFileName		\
				[lindex $file_eol $idx]		\
				[lindex $file_encoding $idx]	\
				[lindex $file_ro_mode $idx]	\
			]

		# Adjust icon border
		if {[llength $project_files_bookmarks]} {
			$listbox_project_files_bm insert end "\n"
		}
		lappend project_files_bookmarks 0

	}

	## Translate full filename to item ID (in project files ListBox)
	 # @parm String fullFileName - full file name
	 # @return String - item ID or '{}'
	private method getItemNameFromProjectList {fullFileName} {
		# Get list of project file items
		set items [$listbox_project_files items]

		# Search for the given filename
		foreach item $items {
			# Determinate item data
			set data [$listbox_project_files itemcget $item -data]

			# Opened file
			if {[llength $data] < 5} {
				if {[lindex $data 0] == $fullFileName} {
					return $item
				}

			# Unopened file
			} else {
				if { "[lindex $data 5][lindex $data 0]" == $fullFileName} {
					return $item
				}
			}
		}

		# Failed
		return {}
	}

	## Change encoding in the current editor
	 # @return void
	public method change_encoding {} {
		if {$splitted && $selectedView} {
			set idx $actualEditor2
		} else {
			set idx $actualEditor
		}
		if {[lindex $file_encoding $idx] == ${::editor_encoding}} {
			return
		}

		# Configure editor
		set original_encoding [lindex $file_encoding $idx]
		lset file_encoding $idx ${::editor_encoding}
		[lindex $editors $idx] configure -encoding ${::editor_encoding}
		if {![filelist_reload_file]} {
			set ::editor_encoding $original_encoding
			lset file_encoding $idx $original_encoding
			[lindex $editors $idx] configure -encoding $original_encoding
		} else {
			# Configure list of project files
			set filename [[lindex $editors $idx] cget -fullFileName]
			foreach item [$listbox_project_files items] {
				set data [$listbox_project_files itemcget $item -data]
				if {[lindex $data 0] == $filename} {
					lset data 2 ${::editor_encoding}
					$listbox_project_files itemconfigure $item -data $data
					break
				}
			}
		}
	}

	## Change EOL in the current editor
	 # @return void
	public method change_EOL {} {
		if {$splitted && $selectedView} {
			set idx $actualEditor2
		} else {
			set idx $actualEditor
		}
		if {[lindex $file_eol $idx] == ${::editor_EOL}} {
			return
		}

		# Configure editor
		lset file_eol $idx ${::editor_EOL}
		[lindex $editors $idx] configure -eol ${::editor_EOL}

		# Configure list of project files
		set filename [[lindex $editors $idx] cget -fullFileName]
		foreach item [$listbox_project_files items] {
			set data [$listbox_project_files itemcget $item -data]
			if {[lindex $data 0] == $filename} {
				lset data 1 ${::editor_EOL}
				$listbox_project_files itemconfigure $item -data $data
				break
			}
		}
	}

	## Change RO mode in the current editor
	 # @return Bool - true == ok; false == cannot comply!
	public method switch_editor_RO_MODE {} {
		if {$splitted && $selectedView} {
			set idx $actualEditor2
		} else {
			set idx $actualEditor
		}
		if {[lindex $file_ro_mode $idx] == ${::editor_RO_MODE}} {
			return
		}

		# Configure editor
		if {![[lindex $editors $idx] change_RO_MODE ${::editor_RO_MODE}]} {
			return 0
		}
		lset file_ro_mode $idx ${::editor_RO_MODE}

		# Configure list of project files
		set filename [[lindex $editors $idx] cget -fullFileName]
		foreach item [$listbox_project_files items] {
			set data [$listbox_project_files itemcget $item -data]

			if {[lindex $data 0] == $filename} {
				lset data 3 ${::editor_RO_MODE}
				$listbox_project_files itemconfigure $item -data $data
				break
			}
		}
		return 1
	}

	## Adjust scrollbar for listbox of opened files
	 # @parm Float frac0 - 1st fraction
	 # @parm Float frac0 - 2nd fraction
	 # @return void
	public method filelist_o_scrollbar_set {frac0 frac1} {
		# Hide scrollbar
		if {$frac0 == 0 && $frac1 == 1} {
			if {$o_scrollbar_visible} {
				pack forget $opened_files_scrollbar
				set o_scrollbar_visible 0
			}
		# Show scrollbar
		} else {
			if {!$o_scrollbar_visible} {
				pack $opened_files_scrollbar	\
					-side left		\
					-fill y			\
					-before $listbox_opened_files_bm
				set o_scrollbar_visible 1
			}
			# Adjust icon border
			$listbox_opened_files_bm yview moveto $frac0
			# Adjust scrollbar
			$opened_files_scrollbar set $frac0 $frac1
		}
	}

	## Scroll synchronously listbox of opened files and its icon border
	 # @parm List - arguments for subcommand yview
	 # @return void
	public method filelist_o_scroll args {
		eval "$listbox_opened_files yview $args"
		eval "$listbox_opened_files_bm yview $args"
	}

	## Adjust scrollbar for listbox of opened files
	 # @parm Float frac0 - 1st fraction
	 # @parm Float frac0 - 2nd fraction
	 # @return void
	public method filelist_p_scrollbar_set {frac0 frac1} {
		# Hide scrollbar
		if {$frac0 == 0 && $frac1 == 1} {
			if {$p_scrollbar_visible} {
				pack forget $project_files_scrollbar
				set p_scrollbar_visible 0
			}
		# Show scrollbar
		} else {
			if {!$p_scrollbar_visible} {
				pack $project_files_scrollbar	\
					-side left		\
					-fill y			\
					-before $listbox_project_files_bm
				set p_scrollbar_visible 1
			}
			# Adjust icon border
			$listbox_project_files_bm yview moveto $frac0
			# Adjust scrollbar
			$project_files_scrollbar set $frac0 $frac1
		}
	}

	## Scroll synchronously listbox of project files and its icon border
	 # @parm List - arguments for subcommand yview
	 # @return void
	public method filelist_p_scroll args {
		eval "$listbox_project_files yview $args"
		eval "$listbox_project_files_bm yview $args"
	}

	## Validator function for search entry in tab of opened files
	 # @parm String content - String which to search for (in listbox of opened files)
	 # @return Bool - always 1
	public method filelist_opened_search {content} {
		# Empty input string
		if {$content == {}} {
			$opened_search_clear_button configure -state disabled
			$opened_search_entry configure -style TEntry
			opened_files_unhighlight_item
			return 1
		}

		# Enable clear button
		$opened_search_clear_button configure -state normal

		# Search the listbox
		foreach item [$listbox_opened_files items] {
			if {![string first $content [$listbox_opened_files itemcget $item -text]]} {
				$opened_search_entry configure -style StringFound.TEntry
				opened_files_highlight_item $item
				return 1
			}
		}

		# Search failed
		$opened_search_entry configure -style StringNotFound.TEntry
		return 1
	}


	## Highlight item in listbox of opened files
	 # @parm String item - item ID
	 # @return void
	private method opened_files_highlight_item {item} {
		opened_files_unhighlight_item
		set opened_files_highlighted_item $item
		set opened_files_hg_item_fg_clr [$listbox_opened_files itemcget $item -fg]
		$listbox_opened_files itemconfigure $item -indent 10 -fg {#00DD00}
		$listbox_opened_files see $item
	}

	## Clear highlightion for currently highlighted item in listbox of opened files
	 # @return void
	private method opened_files_unhighlight_item {} {
		# If no item highlighted -> abort
		if {$opened_files_highlighted_item == {}} {
			return
		}

		# Unhighlight item
		$listbox_opened_files itemconfigure	\
			$opened_files_highlighted_item	\
			-indent 0 -fg $opened_files_hg_item_fg_clr
		set opened_files_hg_item_fg_clr {}
		set opened_files_highlighted_item {}
	}

	## Validator function for search entry in tab of project files
	 # @parm String content - String which to search for (in listbox of project files)
	 # @return Bool - always 1
	public method filelist_project_search {content} {
		# Empty input string
		if {$content == {}} {
			$project_search_clear_button configure -state disabled
			$project_search_entry configure -style TEntry
			project_files_unhighlight_item
			return 1
		}

		# Enable clear button
		$project_search_clear_button configure -state normal

		# Search the listbox
		foreach item [$listbox_project_files items] {
			if {![string first $content [$listbox_project_files itemcget $item -text]]} {
				$project_search_entry configure -style StringFound.TEntry
				project_files_highlight_item $item
				return 1
			}
		}

		# Search failed
		$project_search_entry configure -style StringNotFound.TEntry
		return 1
	}

	## Highlight item in listbox of project files
	 # @parm String item - item ID
	 # @return void
	private method project_files_highlight_item {item} {
		project_files_unhighlight_item
		set project_files_highlighted_item $item
		set project_files_hg_item_fg_clr [$listbox_project_files itemcget $item -fg]
		$listbox_project_files itemconfigure $item -indent 10 -fg {#00DD00}
		$listbox_project_files see $item
	}

	## Clear highlightion for currently highlighted item in listbox of project files
	 # @return void
	private method project_files_unhighlight_item {} {
		# If no item highlighted -> abort
		if {$project_files_highlighted_item == {}} {
			return
		}

		# Unhighlight item
		$listbox_project_files itemconfigure	\
			$project_files_highlighted_item	\
			-indent 0 -fg $project_files_hg_item_fg_clr
		set project_files_hg_item_fg_clr {}
		set project_files_highlighted_item {}
	}

	## Binding for virtual event '<<ListboxSelect>>' for listbox of project files
	 # Clear search entry and unhighlight currently highlighted item (if any)
	 # @return void
	public method project_files_listbox_select {} {
		$project_search_entry delete 0 end
		$this FileList_project_disEna_buttons
	}

	## Add/Remove bookmark to/from item in listbox of opened files
	 # @parm Int x - Relative position in icon border (X axis)
	 # @parm Int y - Relative position in icon border (Y axis)
	 # @return void
	public method filelist_opened_bookmark_xy {x y} {
		opened_files_bookmark [expr {int([$listbox_opened_files_bm index @$x,$y]) - 1}]
	}

	## Add/Remove bookmark to/from item in listbox of opened files
	 # Affects currently selected item
	 # @return void
	public method filelist_o_bookmark {} {
		opened_files_bookmark [$listbox_opened_files index	\
			[$listbox_opened_files selection get]]
	}

	## Add/Remove bookmark to/from item in listbox of opened files
	 # @parm Int line - Target line (begins from zero)
	 # @return void
	public method opened_files_bookmark {line} {
		# Check for allowed range
		if {$line >= [llength $opened_files_bookmarks]} {
			return
		}

		set page [lindex [$listbox_opened_files items] $line]

		# Remove bookmark
		if {[lindex $opened_files_bookmarks $line]} {
			lset opened_files_bookmarks $line 0
			incr line
			$listbox_opened_files_bm delete $line.0 [list $line.0 lineend]

			set ext [string trimleft [file extension [$listbox_opened_files itemcget $page -text]] {.}]
			if {$ext == {h}} {
				set icon {source_h}
			} elseif {$ext == {c}} {
				set icon {source_c}
			} elseif {$ext == {cxx} || $ext == {cpp} || $ext == {cc}} {
				set icon {source_cpp}
			} elseif {$ext == {asm}} {
				set icon {asm}
			} else {
				set icon {ascii}
			}
			$filetabs_nb itemconfigure $page -image ::ICONS::16::$icon

		# Add bookmark
		} else {
			lset opened_files_bookmarks $line 1
			incr line
			$listbox_opened_files_bm image create $line.0	\
				-image ::ICONS::16::bookmark		\
				-align center

			$filetabs_nb itemconfigure $page -image ::ICONS::16::bookmark
		}

		$listbox_opened_files_bm tag add center 0.0 end
	}

	## Invoke icon border popup menu -- list of opened files
	 # @parm Int x - Abolute position in icon border (X axis)
	 # @parm Int y - Abolute position in icon border (Y axis)
	 # @parm Int x - Relative position in icon border (X axis)
	 # @parm Int y - Relative position in icon border (Y axis)
	 # @return void
	public method filelist_opened_bm_popup_menu {X Y x y} {
		set pmenu_cline [expr {int([$listbox_opened_files_bm index @$x,$y]) - 1}]
		set bookmark [lindex $opened_files_bookmarks $pmenu_cline]
		tk_popup $IB_o_menu $X $Y
	}

	## Add/Remove bookmark to/from item in listbox of project files
	 # @parm Int x - Relative position in icon border (X axis)
	 # @parm Int y - Relative position in icon border (Y axis)
	 # @return void
	public method filelist_project_bookmark_xy {x y} {
		project_files_bookmark [expr {int([$listbox_project_files_bm index @$x,$y]) - 1}]
	}

	## Add/Remove bookmark to/from item in listbox of project files
	 # Affects currently selected item
	 # @return void
	public method filelist_p_bookmark {} {
		project_files_bookmark [$listbox_project_files index	\
			[$listbox_project_files selection get]]
	}

	## Add/Remove bookmark to/from item in listbox of project files
	 # @parm Int line - Target line (begins from zero)
	 # @return void
	public method project_files_bookmark {line} {
		# Check for allowed range
		if {($line < 0) || ($line >= [llength $project_files_bookmarks])} {
			return
		}

		# Remove bookmark
		if {[lindex $project_files_bookmarks $line]} {
			lset project_files_bookmarks $line 0
			incr line
			$listbox_project_files_bm delete $line.0 [list $line.0 lineend]
		# Add bookmark
		} else {
			lset project_files_bookmarks $line 1
			incr line
			$listbox_project_files_bm image create $line.0	\
				-image ::ICONS::16::bookmark		\
				-align center
		}

		$listbox_project_files_bm tag add center 0.0 end
	}

	## Invoke icon border popup menu -- list of project files
	 # @parm Int x - Abolute position in icon border (X axis)
	 # @parm Int y - Abolute position in icon border (Y axis)
	 # @parm Int x - Relative position in icon border (X axis)
	 # @parm Int y - Relative position in icon border (Y axis)
	 # @return void
	public method filelist_project_bm_popup_menu {X Y x y} {
		set pmenu_cline [expr {int([$listbox_project_files_bm index @$x,$y]) - 1}]
		set bookmark [lindex $project_files_bookmarks $pmenu_cline]
		tk_popup $IB_p_menu $X $Y
	}

	## Clear flag "command line on"
	 # @return void
	public method cmd_line_off {} {
		set editor_command_line_on 0
		if {$splitted} {
			[lindex $editors $actualEditor2] cmd_line_force_off
		}
		[lindex $editors $actualEditor] cmd_line_force_off
	}

	## Set flag "command line on"
	 # All editors in current project will focus on command line
	 # @return void
	public method cmd_line_on {} {
		set editor_command_line_on 1
		if {$splitted} {
			[lindex $editors $actualEditor2] cmd_line_force_on
		}
		[lindex $editors $actualEditor] cmd_line_force_on

		if {$splitted && $selectedView} {
			[lindex $editors $actualEditor2] cmd_line_focus 1
		} else {
			[lindex $editors $actualEditor] cmd_line_focus 1
		}
	}

	## Split editor vertical
	 # @return void
	public method split_vertical {} {
		split_editor 1
	}

	## Split editor horizontal
	 # @return void
	public method split_horizontal {} {
		split_editor 0
	}

	## Close current view (if editor is splitted)
	 # If editor is already splitted this procedure will do nothing
	 # @return void
	public method close_current_view {editor_object} {
		if {!$splitted} {return}

		# Save current sash position
		if {$pwin_orient == {vertical}} {
			set idx 1
		} else {
			set idx 0
		}
		set multiview_sash_pos [lindex [$multiview_paned_win sash coord 0] $idx]

		# Unmap paned window and the second pages manager and remap the first pages manager
		$multiview_paned_win forget $pagesManager2
		$multiview_paned_win forget $pagesManager
		pack forget $multiview_paned_win
		pack $pagesManager -fill both -expand 1

		# Configure all editor status bar popup menus
		foreach editor $editors {
			$editor configure_statusbar_menu 1 0 {} {}
		}

		# Determinate which editor will be visible now
		if {$editor_object != {}} {
			set editor_object [lsearch -ascii -exact $editors $editor_object]
			if {$editor_object == $actualEditor} {
				$listbox_opened_files selection set [lindex $file_descriptors $actualEditor2]
			} elseif {$editor_object == $actualEditor2} {
				$listbox_opened_files selection set [lindex $file_descriptors $actualEditor]
			}
		}

		set selectedView 0
		set splitted 0
		set actualEditor2 -1
		switchfile
	}

	## Syntax highlight changed from editor
	 # @parm Object editor_object	- New active editor object reference
	 # @parm Int lang		- -1 == unknown; 0 == Assembly language; 1 == C language
	 # @return void
	public method filelist_editor_sh_changed {editor_object lang} {
		lset file_sh [lsearch $editors $editor_object] $lang
	}

	## Change active view if editor is splitted
	 # If editor is already splitted this procedure will do nothing
	 # @parm Object editor_object - New active editor object reference
	 # @return void
	public method filelist_editor_selected {editor_object} {
		if {!$splitted} {return}

		# Search for the given object
		set idx [lsearch $editors $editor_object]
		if {$idx == $actualEditor} {
			set selectedView 0
		} elseif {$idx == $actualEditor2} {
			set selectedView 1
		}
		rightPanel_switch_editor_vars $idx
		$this todo_switch_editor_vars $idx

		# Adjust selection in list of opened files
		set item [lindex $file_descriptors $idx]
		$listbox_opened_files selection set $item
		catch {$listbox_opened_files itemconfigure $lastItem -image {}}
		$listbox_opened_files itemconfigure $item -image ::ICONS::16::2_rightarrow
		set lastItem $item

		update
		$filetabs_nb raise [lindex $file_descriptors $idx]
		$filetabs_nb see [lindex $file_descriptors $idx]
		rightPanel_switch_page $idx
		$this todo_switch_editor $idx
		listBox_disEna_buttons $item $editor_object
		::X::adjust_title
		::X::adjust_mainmenu_and_toolbar_to_editor	\
			${::editor_RO_MODE} [expr {[$editor_object get_language] == 1}]
	}

	## Split editor vertical or horizontal
	 # If editor is already splitted this procedure will do nothing
	 # @parm Bool vert_or_horz - 1 == Vertical; 0 == Horizontal
	 # @return void
	private method split_editor {vert_or_horz} {
		if {$splitted} {return}

		set pwin_orient_orig $pwin_orient

		# Determinate orientation
		if {$vert_or_horz} {
			set pwin_orient {horizontal}
		} else {
			set pwin_orient {vertical}
		}
		$multiview_paned_win configure -orient $pwin_orient

		if {$pwin_orient_orig != $pwin_orient} {
			set multiview_sash_pos 0
		}

		# Validate sash position
		if {$pwin_orient == {vertical}} {
			if {!$multiview_sash_pos} {
				set multiview_sash_pos [expr {[winfo height $pagesManager] / 2}]
			}
			set minsize 80
		} else {
			if {!$multiview_sash_pos} {
				set multiview_sash_pos [expr {[winfo width $pagesManager] / 2}]
			}
			set minsize 300
		}

		# Unmap current pages manager and remap it with the second one into paned window
		pack forget $pagesManager
		pack $multiview_paned_win -fill both -expand 1
		$multiview_paned_win add $pagesManager
		$multiview_paned_win add $pagesManager2 -after $pagesManager

		# Configure minimum size for panes
		$multiview_paned_win paneconfigure $pagesManager -minsize $minsize
		$multiview_paned_win paneconfigure $pagesManager2 -minsize $minsize

		# Move paned window sash
		update idletasks
		if {$pwin_orient == {vertical}} {
			$multiview_paned_win sash place 0 0 $multiview_sash_pos
		} else {
			$multiview_paned_win sash place 0 $multiview_sash_pos 0
		}

		# Configure status bar popup menu for all opened editors
		foreach editor $editors {
			$editor configure_statusbar_menu 0 1 {} {}
		}

		# Show up some editor in the second view
		set splitted 1
		set selectedView 0
		set len [llength $file_descriptors]
		if {$len > 1} {
			if {$actualEditor < ($len - 1)} {
				set actualEditor2 [expr {$actualEditor + 1}]
			} else {
				set actualEditor2 0
			}
		} else {
			set selectedView 1
			editor_new
			set selectedView 0
		}
		pack [[lindex $editors $actualEditor2] cget -ed_sc_frame]	\
			-in $pagesManager2 -fill both -expand 1
	}

	## Sort items in list of opened files or project files
	 # @parm Char by		- {S} == Size; {U} == URL; {N} == Name
	 # @parm Bool opened_project	- 1 == List of opened files; 0 == List of project files
	 # @return void
	public method sort_file_list {by opened_project} {
		if {$opened_project} {
			set listbox		$listbox_opened_files
			set bookmarks_text	$listbox_opened_files_bm
			set bookmarks_var	{opened_files_bookmarks}
		} else {
			set listbox		$listbox_project_files
			set bookmarks_text	$listbox_project_files_bm
			set bookmarks_var	{project_files_bookmarks}
		}

		# Determinate list of values (strings or integers) to sort
		set items		{}	;# List of values to sort
		set num_of_items	0	;# Length of items
		foreach item [$listbox items] {
			switch -- $by {
				{N} {	;# For sorting by name
					lappend items [$listbox itemcget $item -text]
				}
				{U} {	;# For sorting by URL
					set data [$listbox itemcget $item -data]
					if {!$opened_project} {
						# Unopened file
						if {[llength $data] > 4} {
							set data [lindex $data 5]

						# Opened file
						} else {
							set data [lindex $data 0]
						}
					}
					lappend items $data
				}
				{S} {	;# For sorting by size
					set path [$listbox itemcget $item -data]
					if {!$opened_project} {
						# Unopened file
						if {[llength $path] > 4} {
							set path [lindex $path 5]

						# Opened file
						} else {
							set path [lindex $path 0]
						}
					}
					set size 0
					catch {
						set size [file size $path]
					}
					lappend items $size
				}
			}
			incr num_of_items
		}

		# List of item indexes in new order (e.g. {0 2 1 3 4 5 7 6})
		set new_order {}
		for {set i 0} {$i < $num_of_items} {incr i} {
			lappend new_order $i
		}

		## Sort lists items and new_order using Bouble Sort
		 # By name of URL (string comparison)
		if {$by == {N} || $by == {U}} {
			for {set i 1} {$i < $num_of_items} {incr i} {
				for {set j 1; set k 0} {$j < $num_of_items} {incr j; incr k} {
					if {[string compare [lindex $items $k] [lindex $items $j]] < 0} {
						set tmp [lindex $items $k]
						lset items $k [lindex $items $j]
						lset items $j $tmp

						set tmp [lindex $new_order $k]
						lset new_order $k [lindex $new_order $j]
						lset new_order $j $tmp
					}
				}
			}
		 # By size (integer comparison)
		} else {
			for {set i 1} {$i < $num_of_items} {incr i} {
				for {set j 1; set k 0} {$j < $num_of_items} {incr j; incr k} {
					if {[lindex $items $k] > [lindex $items $j]} {
						set tmp [lindex $items $k]
						lset items $k [lindex $items $j]
						lset items $j $tmp

						set tmp [lindex $new_order $k]
						lset new_order $k [lindex $new_order $j]
						lset new_order $j $tmp
					}
				}
			}
		}

 		# Reorder list of bookmarks and
 		#+ determinate list of item descriptors in the new order.
 		#+ No GUI will be affected
		set new_items_order {}
		set bookmarks_new {}
		set bookmarks_org [subst -nocommands "\$$bookmarks_var"]
		for {set i 0} {$i < $num_of_items} {incr i} {
			set idx [lindex $new_order $i]
			lappend new_items_order	[$listbox items $idx]
			lappend bookmarks_new	[lindex $bookmarks_org $idx]
		}
		set $bookmarks_var $bookmarks_new

		# Adjust GUI to the new order
		$listbox reorder $new_items_order
		$bookmarks_text delete 1.0 end
		foreach bm $bookmarks_new {
			if {$bm} {
				$bookmarks_text image create insert	\
					-image ::ICONS::16::bookmark		\
					-align center
			}
			$bookmarks_text insert end "\n"
		}
	}

	## Open selected file with an external editor
	 # @parm Bool o_p	- 1 == opened file; 0 == project file
	 # @parm String command	- Command to execute the editor
	 # @return void
	public method filelist_open_with {o_p command} {
		# Determinate filename
		if {$o_p} {
			set item [$listbox_opened_files selection get]
			if {![$listbox_opened_files exists $item]} {
				return
			}
			set filename	[$listbox_opened_files itemcget $item -data]
		} else {
			set item [$listbox_project_files selection get]
			if {![$listbox_project_files exists $item]} {
				return
			}
			set data	[$listbox_project_files itemcget $item -data]
			if {[llength $data] < 5} {
				set filename	[lindex $data 0]
			} else {
				set filename	"[lindex $data 5][lindex $data 0]"
			}
		}

		# Adjust editor command
		if {$command == {other}} {
			set command [open_with_other]
		}
		if {$command == {}} {
			return
		}

		# Start external editor
		if {[catch {
			exec $command "$filename" &
		}]} then {
			tk_messageBox		\
				-parent .	\
				-icon error	\
				-type ok	\
				-title [mc "Program not found"]	\
				-message [mc "Unable to execute \"%s\"" $command]
		}
	}

	## Open dialog "Open with other editor" and return text entered by user
	 # @return String - Command which executes exernal editor
	private method open_with_other {} {
		set ::FileList::open_with_cnfr 0

		# Create toplevel window
		set win [toplevel .open_with_other_dlg  -class {Open with ...} -bg ${::COMMON_BG_COLOR}]

		# Create label, entryBox and horizontal separator
		pack [label $win.lbl -text [mc "Enter command to execute:"]] -fill x -anchor w -padx 5
		pack [ttk::entry $win.ent			\
			-textvariable ::FileList::open_with	\
			-width 0				\
		] -fill x -padx 10 -anchor w

		bind $win.ent <Return>		"grab release $win; destroy $win"
		bind $win.ent <KP_Enter>	"grab release $win; destroy $win"

		# Create button frame
		set buttonFrame [frame $win.buttonFrame]
		pack [ttk::button $buttonFrame.ok		\
			-text [mc "Ok"]				\
			-compound left				\
			-image ::ICONS::16::ok			\
			-command "
				set ::FileList::open_with_cnfr 1
				grab release $win
				destroy $win
			"	\
		] -side left -padx 2
		pack [ttk::button $buttonFrame.cancel		\
			-text [mc "Cancel"]			\
			-compound left				\
			-image ::ICONS::16::button_cancel	\
			-command "
				grab release $win
				destroy $win
			"	\
		] -side left -padx 2
		pack $buttonFrame -side bottom -padx 5 -pady 5 -anchor e

		# Set window attributes
		wm iconphoto $win ::ICONS::16::terminal
		wm title $win [mc "Open with other ..."]
		wm minsize $win 320 80
		wm transient $win .
		catch {grab $win}
		wm protocol $win WM_DELETE_WINDOW "
			grab release $win
			destroy $win
		"
		raise $win
		update
		$win.ent selection range 0 end
		focus $win.ent
		tkwait window $win

		# Return result
		if {${::FileList::open_with_cnfr}} {
			return ${::FileList::open_with}
		} else {
			return {}
		}
	}

	## Kill childern
	 # @return void
	public method filelist_kill_childern {} {
		foreach editor $editors {
			$editor kill_childern
		}
	}

	## Focus and conditionaly open editor with the specified filename
	 # @parm String filename	- Name of file
	 # @parm Bool suppress_error	- Suppress error messages
	 # @return Bool - 1 == Success; 0 == Fail
	public method fucus_specific_editor {filename suppress_error} {

		# Search list of opened files
		foreach item [$listbox_opened_files items] {
			if {$filename == [$listbox_opened_files itemcget $item -text]} {
				$listbox_opened_files selection set $item
				switchfile
				return 1
			}
		}
		# Search list of project files
		foreach item [$listbox_project_files items] {
			if {$filename == [$listbox_project_files itemcget $item -text]} {
				$listbox_project_files selection set $item
				filelist_project_file_open
				return 1
			}
		}

		# Display error message
		if {!$suppress_error} {
			tk_messageBox		\
				-parent .	\
				-type ok	\
				-icon warning	\
				-title [mc "File not found"]	\
				-message [mc "Unable to find \"%s\" in list of opened files or project files" $filename]
		}
		return 0
	}

	## Move simulator pointer in editor
	 # - Switch to specified editor and go to specified line
	 # @parm List line_info - Line information number {Line_number File_number}
	 # @retun void
	public method move_simulator_line {line_info} {
		set line_number [lindex $line_info 0]
		set file_number [lindex $line_info 1]

		if {$line_number == {}} {
			return
		}

		if {[$this cget -programming_language]} {
			$this cvarsview_load_local_variables [lindex $line_info 2] [lindex $line_info 3]
		}

		# Switch file
		if {$file_number != {} && $simulator_editor != $file_number} {
			# Gain target file name
			set file_name [$this simulator_get_filename $file_number]
			if {$::MICROSOFT_WINDOWS} { ;# "/" --> "\"
				regsub -all {/} $file_name "\\" file_name
			}

			# Search for the given file and try to switch to it
			if {$file_switching_enabled || $simulator_editor == -1} {
				foreach item [$listbox_opened_files items] {
					set item_data [$listbox_opened_files itemcget $item -data]
					if {$::MICROSOFT_WINDOWS} { ;# "/" --> "\"
						regsub -all {/} $item_data "\\" item_data
					}

					if {$file_name != $item_data} {
						continue
					}

					$listbox_opened_files selection set $item

					if {$simulator_editor_obj != {}} {
						$simulator_editor_obj disable
						$listbox_opened_files itemconfigure [lindex	\
							$file_descriptors [lsearch -ascii -exact\
								$editors $simulator_editor_obj	\
							]					\
						] -fg {#000000}
					}
					$listbox_opened_files itemconfigure $item -fg {#FF0000}
					set simulator_editor_obj [lindex $editors		\
						[lsearch -ascii -exact $file_descriptors $item]	\
					]
					$simulator_editor_obj freeze
					$simulator_editor_obj move_simulator_line $line_number

					switchfile
					set simulator_editor $file_number

					return
				}
			}

			Sbar [mc "Simulator: unable to switch to file: '%s'" $file_name]

		# Move simulator pointer directly
		} elseif {$simulator_editor_obj != {}} {
			$simulator_editor_obj move_simulator_line $line_number
		}
	}

	## Get editor object used by simulator
	 # @return Object - Editor object
	public method filelist_get_simulator_editor_obj {} {
		return $simulator_editor_obj
	}

	## Set "auto file switch" lock
	 # @parm Object from_obj	- Editor object from which this procedure is called
	 # @parm Bool new_state		- New state of the lock
	 # @return void
	public method set_editor_lock {from_obj new_state} {
		foreach editor $editors {
			if {$editor == $from_obj} {
				continue
			}
			$editor set_lock $new_state
		}
		set file_switching_enabled [expr {!$new_state}]
	}

	## Get value of "auto file switch lock"
	 # This lock disables automatic file switching during sumulation
	 # @return Bool - 1 == unlocked; 0 == locked
	public method get_file_switching_enabled {} {
		return $file_switching_enabled
	}

	## Redraw panel pane
	 # @return  void
	public method leftpanel_redraw_pane {} {
		update idletasks
		if {$PanelVisible != 0} {
			$parent sash place 0 $PanelSize 0
		}
	}

	## Get object reference for the current editor
	 # @return Object - Active editor
	public method get_current_editor_object {} {
		if {$splitted && $selectedView} {
			set editor_num $actualEditor2
		} else {
			set editor_num $actualEditor
		}
		return [lindex $editors $editor_num]
	}

	## Show or hide the tab bar
	 # @return void
	public method show_hide_tab_bar {} {
		# Show
		if {${::CONFIG(SHOW_EDITOR_TAB_BAR)}} {
			if {![winfo ismapped $filetabs_frm]} {
				if {$splitted} {
					set before $multiview_paned_win
				} else {
					set before $pagesManager
				}
				pack $filetabs_frm -fill x -before $before

				filelist_adjust_size_of_tabbar
			}
		# Hide
		} else {
			if {[winfo ismapped $filetabs_frm]} {
				pack forget $filetabs_frm
			}
		}
	}

	## Special purpose method (see the usage in the code)
	 # It should be used to ensure that the height of the tab bat is not too big
	 # @return void
	public method filelist_adjust_size_of_tabbar {} {
		$filetabs_nb see [lindex [$filetabs_nb pages] 0]
		update
		catch {
			$filetabs_nb.c configure -height [expr {int(20 * $::font_size_factor)}]
		}
		$filetabs_nb see [$filetabs_nb raise]

		# Keep editor nice after adjustment of filestab height
		if {!${::Editor::editor_to_use}} {
			[get_current_editor_object] scroll scroll +0 lines
		}
	}

	## Call method Configure in both editors
	 # @return void
	public method ensure_that_both_editors_are_properly_initialized {} {
		if {$splitted} {
			update
			[lindex $editors $actualEditor] Configure
			[lindex $editors $actualEditor2] Configure
		}
	}
}
set ::FileList::ask__append_file_to_project ${::CONFIG(ASK_ON_FILE_OPEN)}

# >>> File inclusion guard
}
# <<< File inclusion guard

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
if { ! [ info exists _HWMANAGER_TCL ] } {
set _HWMANAGER_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Provides panel for managing hardware plugins (e.g. Programmer, ICD, etc.)
# --------------------------------------------------------------------------

class HwManager {
	## COMMON
	public common PLUGIN_SEARCH_PATHS {
		/usr/share/mcu8051ide/hwplugins
		/usr/local/share/mcu8051ide/hwplugins
	}
	if {$::MICROSOFT_WINDOWS} {
		set PLUGIN_SEARCH_PATHS ${::INSTALLATION_DIR}/hwplugins
	}
	public common inst_plg_count			0	;# Int: Number of installed plugins

	## PRIVATE
	private variable parent				;# Widget: parent widget
	private variable hwman_gui_initialized	0	;# Bool: GUI initialized

	private variable main_frame			;# Widget: Main frame
	private variable pagesmanager			;# Widget: Pages manager for plugins GUI
	private variable plg_combobox			;# Widget: Plugin selection combobox
	private variable plg_refresh_but		;# Widget: Button "Refresh available plugins"
	private variable ins_plugin_namespaces	{}	;# List of Strings: Namespaces of installed (initialized) plugins
	private variable ins_plugin_names	{}	;# List of Strings: Names of installed (initialized) plugins
	private variable avl_plugin_files	{}	;# List of Strings: Full filenames of available plugins
	private variable avl_plugin_names	{}	;# List of Strings: Names of available plugins

	# List: Configuraion list of this panel (for session management)
	private variable local_config		[lindex $::CONFIG(HW_MANAGER_CONFIG) 0]
	# List: Names of plugins with saved configuration (for session management)
	private variable plugin_config_0	[lindex $::CONFIG(HW_MANAGER_CONFIG) 1]
	# List: Configuration lists for plugins with saved configuration (for session management)
	private variable plugin_config_1	[lindex $::CONFIG(HW_MANAGER_CONFIG) 2]


	constructor {} {
	}

	destructor {
		# Order all plugins to free their resources
		hw_man_kill_childern
	}

	## Kill all child processes
	 # @return void
	public method hw_man_kill_childern {} {
		foreach ns $ins_plugin_namespaces name $ins_plugin_names {

			if {[catch {
				${ns}::dispose
			}]} then {
				plugin_error $name $ns
			}
		}
	}

	## Prepare this panel for initialization of its GUI
	 # MUST BE called before "CreateHwManagerGUI"
	 # @parm Widget _parent - Frame where this panel would be created
	 # @return void
	public method PrepareHwManager {_parent} {
		set parent $_parent
		set hwman_gui_initialized 0
	}

	## Finalize initialization of this panel
	 # @return void
	public method CreateHwManagerGUI {} {
		if {$hwman_gui_initialized} {return}
		set hwman_gui_initialized 1

		# Create main GUI parts
		set main_frame [frame $parent.main_frame]
		set top_frame [frame $main_frame.top]
		set pagesmanager [PagesManager $main_frame.pagesmanager -background ${::COMMON_BG_COLOR}]

		## Create parts of top panel
		 # Label "HW"
		pack [label $top_frame.plg_label	\
			-text [mc "HW:"]		\
		] -side left
		 # Combobox of available/installed plugins
		set plg_combobox [ttk::combobox $top_frame.plg_cbbox	\
			-exportselection 1				\
			-width 0					\
			-state readonly					\
		]
		DynamicHelp::add $plg_combobox -text [mc "List available or installed HW plugins"]
		bind $plg_combobox <<ComboboxSelected>> "$this hw_manager_plg_cbs"
		pack $plg_combobox -fill x -expand 1 -side left
		setStatusTip -widget $plg_combobox -text [mc "available/installed plugins"]
		 # Button "Refresh"
		set plg_refresh_but [ttk::button $top_frame.plg_refresh_but	\
			-image ::ICONS::16::reload				\
			-command "$this hw_manager_refresh_plugins"		\
			-style Flat.TButton					\
		]
		DynamicHelp::add $top_frame.plg_refresh_but	\
			-text [mc "Refresh list available or installed HW plugins"]
		pack $plg_refresh_but -side left
		setStatusTip -widget $plg_refresh_but -text [mc "Refresh"]
		 # Fill in the combobox
		hw_manager_refresh_plugins

		# Show GUI of the plugin from the last session
		set idx [lsearch -ascii -exact [$plg_combobox cget -values] [lindex $local_config 0]]
		if {$idx != -1} {
			$plg_combobox current $idx
			hw_manager_plg_cbs
		}

		# Pack top frame, create separator and pack the pages manager
		pack $top_frame -fill x
		pack [ttk::separator $main_frame.sep	\
			-orient horizontal		\
		] -fill x -pady 5
		pack $pagesmanager -fill both -expand 1
		pack $main_frame -fill both -expand 1
	}

	## Refresh list available or installed HW plugins
	 # @return void
	public method hw_manager_refresh_plugins {} {
		if {!$hwman_gui_initialized} {CreateHwManagerGUI}
		if {${::CLI_OPTION(no-plugins)}} {return}

		set avl_plugin_files [list]
		set avl_plugin_names [list]

		# Search for available plugins
		foreach dir $PLUGIN_SEARCH_PATHS {
			set dir [file join ${::LIB_DIRNAME} $dir]
			catch {	;# For Microsoft Windows it has to be enclosed by catch
				foreach file [glob -directory $dir -nocomplain -types f *.tcl] {
					if {[lsearch -ascii -exact $avl_plugin_names [file tail [file rootname $file]]] != -1} {
						continue
					}

					lappend avl_plugin_files $file
					lappend avl_plugin_names [regsub -all {_} [file tail [file rootname $file]] { }]
				}
			}
		}

		# Adjust the combobox
		$plg_combobox configure -values $avl_plugin_names
	}

	## Switch plugin
	 # @parm String plugin_name - Plugin to switch to
	 # @return void
	public method hw_manager_switch_plugin {plugin_name} {
		if {!$hwman_gui_initialized} {CreateHwManagerGUI}
		if {${::CLI_OPTION(no-plugins)}} {return}

		# Install the plugin if it wasn't installed yet
		if {[lsearch -ascii -exact $ins_plugin_names $plugin_name] == -1} {
			# Check if the selected plugin is really available
			if {[lsearch -ascii -exact $avl_plugin_names $plugin_name] == -1} {
				return
			}

			# Install the plugin (means initialize)
			lappend ins_plugin_names $plugin_name
			lappend ins_plugin_namespaces [						\
				hw_manager_install_plugin $plugin_name [lindex			\
					$avl_plugin_files					\
					[lsearch -ascii -exact $avl_plugin_names $plugin_name]	\
				]
			]
		}

		# Adjust the combobox of available/installed plugins
		$pagesmanager raise [regsub -all {[\s\.]} $plugin_name {_}]
	}

	## "Change command" for the combobox of available/installed plugins
	 # Switches the selected plugin
	 # @return void
	public method hw_manager_plg_cbs {} {
		if {!$hwman_gui_initialized} {CreateHwManagerGUI}
		hw_manager_switch_plugin [$plg_combobox get]
	}

	## Install plugin (means initialize)
	 # @parm String plugin_name	- Plugin name
	 # @parm String file_path	- Full path to the plugin main file
	 # @return String - Plugin namespace
	public method hw_manager_install_plugin {plugin_name file_path} {
		if {!$hwman_gui_initialized} {CreateHwManagerGUI}
		if {${::CLI_OPTION(no-plugins)}} {return}
		set plg_ns {}

		if {[catch {
			set frame [$pagesmanager add [regsub -all {[\s\.]} $plugin_name {_}]]
			set plg_ns "::HwManager::plugin_ns::$inst_plg_count"
			incr inst_plg_count

			namespace eval $plg_ns "source {$file_path}"

			set min_ide_ver [subst -nocommands "\$${plg_ns}::MIN_IDE_VER"]
			if {[package vcompare $min_ide_ver $::VERSION] == 1} {
				tk_messageBox				\
					-parent .			\
					-title [mc "Too old version"]	\
					-type ok			\
					-icon warning			\
					-message [mc "Plugin %s requires MCU 8051 IDE version %s and above, please upgrade your MCU 8051 IDE" $plugin_name $min_ide_ver]
			}

			${plg_ns}::init $frame $this $plg_ns [file dirname $file_path]

			set idx [lsearch $plugin_config_0 $plugin_name]
			if {$idx != -1} {
				${plg_ns}::restore_session [lindex $plugin_config_1 $idx]
			}
		}]} then {
			plugin_error $plugin_name $plg_ns
		}

		return $plg_ns
	}

	## Handle plugin error and display error message
	 # @parm String plugin_name	- Name of the plugin
	 # @parm String plugin_ns	- Namespace of the plugin
	 # @return void
	private method plugin_error {plugin_name plugin_ns} {

		# Try to gain some informations about the crashed plugin
		set plugin_ver		{not defined}
		set plugin_author	{not defined}
		set authors_email	{not defined}
		set err_info		$::errorInfo
		catch {set plugin_ver		[subst -nocommands "\$${plugin_ns}::P_VERSION"]}
		catch {set plugin_author	[subst -nocommands "\$${plugin_ns}::AUTHOR"]}
		catch {set authors_email	[subst -nocommands "\$${plugin_ns}::EMAIL"]}

		# Print error message to stadrad error output
		puts stderr "\n\n"
		puts stderr [string repeat {=} 64]
		puts stderr "PLUGIN ERROR:"
		puts stderr [string repeat {-} 64]
		puts stderr "Plugin name:\t$plugin_name"
		puts stderr "Plugin version:\t$plugin_ver"
		puts stderr "Author:\t\t$plugin_author <$authors_email>"
		puts stderr [string repeat {-} 64]
		puts stderr $err_info
		puts stderr [string repeat {=} 64]
		puts stderr "\n\n"

		# Save log file
		if {![catch {set log_file [open [file join ${::X::defaultDirectory} mcu8051ide_plugin_errors.log] a]}]} {
			puts $log_file "\n\n"
			puts $log_file [string repeat {=} 64]
			puts $log_file "PLUGIN ERROR:"
			puts $log_file [string repeat {-} 64]
			puts $log_file "Plugin name:\t$plugin_name"
			puts $log_file "Plugin version:\t$plugin_ver"
			puts $log_file "Author:\t\t$plugin_author <$authors_email>"
			puts $log_file [string repeat {-} 64]
			puts $log_file $err_info
			puts $log_file [string repeat {=} 64]
			puts $log_file "\n\n"
			close $log_file
		}

		# Display GUI error message (only if the main window is still visible)
		if {[wm state .] != {withdrawn}} {
			set dialog [toplevel .plugin_error -bg ${::COMMON_BG_COLOR}]

			# Create window frames
			set main_dlg_frame [frame $dialog.main_frame]
			set top_frame [frame $main_dlg_frame.top_frame -bg {#EE0000}]
			set middle_frame [frame $main_dlg_frame.middle_frame]
			set bottom_frame [frame $main_dlg_frame.bottom_frame]

			# Create window header
			pack [label $top_frame.header_lbl				\
				-text [mc "PLUGIN ERROR"]				\
				-bg {#EE0000} -fg {#FFFFFF}				\
				-font [font create					\
					-family helvetica				\
					-size [expr {int(-24 * $::font_size_factor)}]	\
					-weight bold					\
				]	\
			] -side left -fill x -expand 1

			# Create error message text and scrollbar
			pack [text $middle_frame.text				\
				-bg {white} -bd 0				\
				-yscrollcommand "$middle_frame.scrollbar set"	\
				-width 0 -height 0 -relief flat -wrap word	\
			] -side left -fill both -expand 1 -padx 5 -pady 5
			bind $middle_frame.text <Button-1> {focus %W}
			pack [ttk::scrollbar $middle_frame.scrollbar	\
				-orient vertical			\
				-command "$middle_frame.text yview"	\
			] -fill y -side right

			# Create button "Close"
			pack [ttk::button $bottom_frame.ok	\
				-text [mc "Close"]		\
				-style GreenBg.TButton		\
				-command "
					grab release $dialog
					destroy $dialog
				"	\
			] -side right
			focus -force $bottom_frame.ok

			# Display error message
			$middle_frame.text insert insert [mc "Plugin name:\t%s\n" $plugin_name]
			$middle_frame.text insert insert [mc "Plugin version:\t%s\n" $plugin_ver]
			$middle_frame.text insert insert [mc "Author:\t\t%s <%s>\n" $plugin_author $authors_email]
			$middle_frame.text insert insert "\n"
			$middle_frame.text insert insert $err_info
			$middle_frame.text insert insert "\n"
			$middle_frame.text configure -state disabled

			# Pack window frames
			pack $top_frame -fill x -anchor n
			pack $middle_frame -fill both -expand 1
			pack $bottom_frame -fill x
			pack $main_dlg_frame -fill both -expand 1 -padx 5 -pady 5

			# Configure dialog window
			set x [expr {[winfo screenwidth $dialog] / 2 - 225}]
			set y [expr {[winfo screenheight $dialog] / 2 - 125}]
			wm iconphoto $dialog ::ICONS::16::bug
			wm title $dialog [mc "PLUGIN ERROR - MCU 8051 IDE"]
			wm minsize $dialog 450 250
			wm geometry $dialog =550x250+$x+$y
			wm protocol $dialog WM_DELETE_WINDOW "
				grab release $dialog
				destroy $dialog"
			update
			raise $dialog
			grab $dialog
			wm transient $dialog .
			tkwait window $dialog
		}
	}

	## Ask all plugins wheather they are ready for exit
	 # @return Bool - 1 == Exit allowed; 0 == Exit DENIED
	public method hw_manager_comfirm_exit {} {
		if {!$hwman_gui_initialized} {return 1}

		foreach plg_name $ins_plugin_names plg_ns $ins_plugin_namespaces {
			set busy_flag 0
			catch {
				set busy_flag [${plg_ns}::is_busy]
			}
			if {$busy_flag} {
				if {[tk_messageBox	\
					-parent .	\
					-type yesno	\
					-icon question	\
					-title [mc "Hardware is busy"]	\
					-message [mc "Plugin \"%s\" is busy.\nDo you really want to close the program ?" $plg_name]
				] != {yes}} {
					return 0
				}
			}
		}

		return 1
	}

	## Get configuration list for this panel (intented for sessions management)
	 # @return void
	public method hw_manager_get_cfg {} {
		if {!$hwman_gui_initialized} {
			return [list $local_config $plugin_config_0 $plugin_config_1]
		}

		set local_config	{}
		set plugin_config_0	{}
		set plugin_config_1	{}

		# Get panel configuration
		lappend local_config [$plg_combobox get]

		# Get plugins configuration
		foreach plg_name $ins_plugin_names plg_ns $ins_plugin_namespaces {
			set idx [lsearch -ascii -exact $plugin_config_0 $plg_name]

			set config [${plg_ns}::save_session]

			if {$idx == -1} {
				lappend plugin_config_0 $plg_name
				lappend plugin_config_1 $config
			} else {
				lset plugin_config_1 $idx $config
			}
		}

		return [list $local_config $plugin_config_0 $plugin_config_1]
	}

	# ---------------------------------------------------------------------
	# Functions mend to be accessed from HW control plug-ins
	# ---------------------------------------------------------------------

	## Check whether there is some project opened in the IDE
	 # @return Bool - 1 == Yes, there is; 0 == No there is not
	proc is_project_opened {} {
		return [expr {!${::X::project_menu_locked}}]
	}

	## Check whether MCU simulator is engaged
	 # @return Bool - 0 == 1 == Yes, it is; No it is not (or no project is opened)
	proc is_simulator_engaged {} {
		if {[lindex ${::X::simulator_enabled} ${::X::actualProjectIdx}] == 1} {
			return 1
		} else {
			return 0
		}
	}

	## Get full name of file which is currently displayed in the source code editor
	 # @return String - Full file name including path or empty string in case there is no project opened
	proc get_current_file {} {
		if {![is_project_opened]} {
			return {}
		} else {
			return [${::X::actualProject} editor_procedure {} getFileName {}]
		}
	}

	## Get full name of file which has been chosen as the project main file
	 # @return String - Full file name or empty string
	proc get_project_main_file {} {
		if {![is_project_opened]} {
			return {}
		} else {
			return [${::X::actualProject} cget -P_option_main_file]
		}
	}

	## Get path the directory of currently active project
	 # @return String - Directory path or empty string in case there is no project opened
	proc get_project_dir {} {
		if {![is_project_opened]} {
			return {}
		} else {
			return [${::X::actualProject} cget -projectPath]
		}
	}

	## Get name of the current project
	 # @return String - Name of the current project or empty string in case there is no project opened
	proc get_project_name {} {
		if {![is_project_opened]} {
			return {}
		} else {
			return [${::X::actualProject} cget -projectName]
		}
	}

	## Initiate compilation if at least one of the source files was modified
	 # @parm String success_callback - Any command to execute after successful compilation
	 # @parm String failure_callback - Any command to execute after unsuccessful compilation
	 # @return Bool - 1 == Process successfully started; 0 == Unable to comply (no project is opened)
	proc compile_if_nessesary_and_callback {success_callback failure_callback} {
		if {![is_project_opened]} {
			return 0
		}

		::X::compile_if_nessesary_and_callback $success_callback $failure_callback
		return 1
	}

	## Open the specified Intel® 8 hex file in hexadecimal editor
	 # @parm String filename - Name of file to open (including path)
	 # @return Bool - 1 == Success; 0 == Failure
	proc open_in_hexeditor {filename} {
		return [[::X::__hexeditor] open_file $filename hex]
	}

	## Start MCU simulator if possible
	 # @return Bool - 1 == Success; 0 == Unable to comply
	proc start_simulator {} {
		if {![is_project_opened]} {
			return 0
		}

		if {[is_simulator_engaged]} {
			return 0
		}

		::X::__initiate_sim
		return 1
	}

	## Shutdown MCU simulator if possible
	 # @return Bool - 1 == Success; 0 == Unable to comply
	proc shutdown_simulator {} {
		if {![is_project_opened]} {
			return 0
		}

		if {![is_simulator_engaged]} {
			return 0
		}

		::X::__initiate_sim
		return 1
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

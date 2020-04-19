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
if { ! [ info exists _SETTINGS_TCL ] } {
set _SETTINGS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements interface to program settings (which are stored in a file)
# --------------------------------------------------------------------------

class Settings {
	public common dir_sep	[file separator]	;# Directory separator (eg. '/')
	public common settings_count		0	;# Counter of instances

	private variable isEmpty	1	;# Is settings array empty
	private variable isReady	0	;# Is interface ready

	private variable directory		;# Path to directory with settings file
	private variable filename		;# Name of file with settings related to this instance
	private variable fileFullPath		;# Full name of settings file (including directory)
	private variable configArray	{}	;# Content of settings maneged by this interface

	## Object contructor
	 # @parm String configDir	- Path to directory with settings file
	 # @parm String configFileName	- Name of file with settings
	constructor {configDir configFileName} {
		incr settings_count	;# increment instance conter

		# Incalize object variables
		set configArray	"::Settings::S${settings_count}"	;# Array of settings
		set directory	[string trimright $configDir "/\/"]	;# Path to directory with settings file
		set filename	[string trimleft $configFileName "/\/"]	;# Name of file with settings
		set fileFullPath "${directory}${dir_sep}${filename}"	;# Full name of settings file

		# If specified file does not exist -> create it
		if {![file exists $fileFullPath]} {
			if {[catch {
				file mkdir $directory
				close [open $fileFullPath w 0640]
			}]} then {
				return
			} else {
				set isReady 1
			}

		# Else check if the file is readable and writable
		} else {
			if {$::MICROSOFT_WINDOWS || ([file readable $fileFullPath] && [file writable $fileFullPath])} {
				set isReady 1
			} else {
				return
			}
		}

		# Load settings from the file
		reLoadConfig
	}

	## Object destructor
	destructor {
	}

	## (Re)load settings from config file
	 # @return result
	public method reLoadConfig {} {

		# Check if file is readable
		if {!$::MICROSOFT_WINDOWS && ![file readable $fileFullPath]} {
			return 0
		}

		# Read content of config file and store it as list of lines into fileData
		set configFile [open $fileFullPath r]
		set fileData [read $configFile]
		set fileData [regsub -all {\r\n} $fileData "\n"]
		set fileData [regsub -all {\r} $fileData "\n"]
		set fileData [split $fileData "\n"]
		close $configFile

		# Parse content of the file
		set category {general}
		foreach line $fileData {
			# Local variables
			set line	[string trim $line]	;# Line of config file
			set key		{}	;# Key
			set value	{}	;# Value for the key

			# Skip empty lines
			if {$line == {}} {continue}

			# Handle category declaration
			if {[regexp {^\[\s*[\w \t]+\s*\]$} $line]} {
				set category [string trim $line "\[\] \t"]

			# Handle key and its value
			} elseif {[regexp {^\s*[\w \t:]+\s*\=\s*\".*\"\s*$} $line]} {
				# Determinate key
				regexp {^\s*[\w \t:]+\s*\=} $line key
				set key [string trim $key "=\t "]
				# Determinate value
				regexp {\s*\".*\"\s*$} $line value
				set value [string trim $value]
				regsub {^\"} $value {} value
				regsub {\"$} $value {} value
				regsub -all "\a" $value "\n" value
				# Set key and value to array
				set "$configArray\($category/$key\)" $value
			}
		}

		# Set variable isEmpty
		if {[array size $configArray] != 0} {
			set isEmpty 0
		} else {
			set isEmpty 1
		}

		# return result
		return 1
	}

	## Save current content of $configArray to config file
	 # @return result
	public method saveConfig {} {

		# Check if file is writable
		if {![file writable $fileFullPath]} {
			return 0
		}

		# Local variables
		set configFile	[open $fileFullPath w 0640]	;# ID of config file chanel
		set categories	{general}			;# Name of current category

		# Determinate list of categories
		foreach key [array names $configArray] {
			# Determinate category
			regexp {^.+/} $key category
			set category [string trimright $category {/}]
			# Append category to the list
			if {[lsearch $categories $category] == -1} {
				lappend categories $category
			}
		}

		# Iterate over categories and save them to the file
		foreach category $categories {
			# Get names of keys in current category
			set keys [array names $configArray -regexp "$category/"]
			# Save category declaration
			puts $configFile "\n\[$category\]"
			# Iterate over keys in current category
			foreach fullKey $keys {
				# Determinate key
				regsub {^[^/]*/} $fullKey {} key
				# Determinate value
				set value [subst -nocommands "\$$configArray\(\$fullKey\)"]
				regsub -all "\n" $value "\a" value
				# Save key and value
				puts $configFile "$key=\"$value\""
			}
		}

		# Done ...
		close $configFile
		return 1
	}

	## Return True if config array is empty
	 # @return Bool - result
	public method isEmpty {} {
		return $isEmpty
	}

	## Return True if interface is ready
	 # @return Bool - result
	public method isReady {} {
		return $isReady
	}

	## Clear all settings
	 # @return void
	public method clear {} {
		array unset $configArray
	}

	## Remove specified key from settings
	 # @parm String key - name of key to remove
	 # @return Bool - result
	public method remove {key} {
		regsub -all {_} $key {__} key
		regsub -all {\s} $key {_} key

		if {[i_contains $key]} {
			unset "$configArray\($key\)"
			return 1
		} else {
			return 0
		}
	}

	## Return True if the specified key is defined
	 # @parm String key - key to search for
	 # @return Bool - result
	public method contains {key} {
		regsub -all {_} $key {__} key
		regsub -all {\s} $key {_} key

		return [i_contains $key]
	}

	## Internal key search (Does not peform key name adjusment)
	 # @parm String key - name of key to search for
	 # @return Bool - result
	private method i_contains {key} {
		if {[array names $configArray -exact $key] == {}} {
			return 0
		} else {
			return 1
		}
	}

	## Get value for the given key
	 # @parm String key	- Key
	 # @parm Mixed default	- Default value
	 # @return Mixed - value for the given key
	public method getValue {key default} {

		# Adjust key name
		if {![regexp {^.+/} $key]} {
			set key "general/$key"
		}
		regsub -all {_} $key {__} key
		regsub -all {\s} $key {_} key

		# Check for valid key format
		if {![regexp {^[\w:]+/[\w:]+$} $key]} {
			return $default
		}

		# Check if the given key is defined
		if {[i_contains $key]} {
			return [subst -nocommands "\$$configArray\(\$key\)"]
		} else {
			return $default
		}
	}

	## Set value for the given key
	 # @parm String key	- Key
	 # @parm Mixed value	- Value
	 # @return Bool - result
	public method setValue {key value} {

		## Check for key validity
		if {[regexp {[\!\=\$\^\*\+\?\.\[\]\{\}\(\)]} $key]} {
			return 0
		}

		regsub -all {_} $key {__} key
		regsub -all {\s} $key {_} key

		if {![regexp {^.+/} $key]} {
			set key "general/$key"
		}

		if {![regexp {^[\w:]+/[\w:]+$} $key]} {
			return 0
		}

		## Set value
		set "$configArray\($key\)" $value
		return 1
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

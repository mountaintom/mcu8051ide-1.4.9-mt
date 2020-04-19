#!/usr/bin/tclsh

############################################################################
#    Copyright (C) 2011 by Martin Ošmera                                   #
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
if { ! [ info exists _FSNOTIFICATIONS_TCL ] } {
set _FSNOTIFICATIONS_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Mechanism for watching over a set of files for modifications made to them
# on the storage device where there are stored on. It periodically checks
# modification times of the specified files and generate notifications when
# some of these times changes.
# --------------------------------------------------------------------------

namespace eval FSnotifications {
	variable watch_interval	-1	;# Int: Interval for periodical mtime checks, in ms
	variable watch_timer	{}	;# Object: The watch timer

	# List: Watched files, format:
	# {
	#	{					# <-- Group of files
	#		{directory mtime callback}	# <-- Directory specification
	#		{				# <-- List of files
	#			{file mtime callback}	# <-- File specification
	#			...
	#		}
	#	} ...
	# }
	variable watched_files	{}


	# ----------------------------------------------------------------------
	# "PUBLIC" FUNCTIONS
	# ----------------------------------------------------------------------

	## Start watching
	 # @parm Int: interval=1500 - Interval for periodical mtime checks, in ms
	 # @return void
	proc init {{interval 1500}} {
		variable watch_timer		;# Int: Interval for periodical mtime checks, in ms
		variable watch_interval		;# Object: The watch timer

		set watch_interval $interval

		# Start the watch timer
		if {$watch_timer == {}} {
			set watch_timer [after $watch_interval [list FSnotifications::timeout]]
		}
	}

	## Stop watching
	 # @return void
	proc stop {} {
		variable watch_timer	;# Object: The watch timer

		if {$watch_timer != {}} {
			catch {
				after cancel $watch_timer
			}
		}
	}

	## Watch over the specified file
	 # @parm String: filename	- Name of the file, or directory, to watch including path
	 # @parm String: callback	- Change notification (some command string)
	 # @return Bool - true == File actually added; false == something went wrong
	proc watch {filename callback} {
		variable watched_files	;# List: Watched files

		# Check for existence of the specified file
		if {$filename == {} || ![file exists $filename]} {
			return 0
		}

		# Watch directory
		if {[file isdirectory $filename]} {
			# Attempt to find already existing group of files
			set group_index -1
			foreach group $watched_files {
				incr group_index

				# Local variables
				set directory [lindex $group 0]	;# List: Directory specification
				set files [lindex $group 1]	;# List: List of files

				# Group found
				if {[lindex $directory 0] == $filename} {
					# No callback specified -> do nothing
					if {$callback == {}} {
						return 0
					# Set new callback
					} else {
						lset watched_files [list $group_index 0 2] $callback
						return 1
					}
				}
			}

			# Group not found, create a new one
			lappend watched_files [list [list $filename [file mtime $filename] $callback] [list]]

		# Watch regular file
		} else {
			# Local variables
			set dirname [file dirname $filename]	;# Directory name
			set tailname [file tail $filename]	;# File name

			# Attempt to find already existing group of files
			set group_index -1
			foreach group $watched_files {
				incr group_index

				# Local variables
				set directory [lindex $group 0]	;# List: Directory specification
				set files [lindex $group 1]	;# List: List of files

				# Group found
				if {[lindex $directory 0] == $dirname} {
					set file_index -1
					foreach file_spec $files {
						incr file_index

						# Local variables
						set file_name [lindex $file_spec 0]	;# Name of file
						set file_mtime_rec [lindex $file_spec 1];# Time of the last modification
						set file_callback [lindex $file_spec 2]	;# Notification callback

						# Set new callback for the specified file
						if {$file_name == $tailname} {
							lset watched_files [list $group_index 1 $file_index 2] $callback
							return 1
						}
					}

					# File specification not found, create a new one
					lappend files [list $tailname [file mtime $filename] $callback]

					# Alter the corresponding group
					lset watched_files [list $group_index 1] $files
					return 1
				}
			}

			# Group not found, create a new one and create the file specification right away
			set dir_spec [list $dirname [file mtime $dirname] {}]
			set file_list [list [list $tailname [file mtime $filename] $callback]]
			lappend watched_files [list $dir_spec $file_list]
			return 1
		}
	}

	## Discontinue watching over the specified file
	 # @parm String: filename	- Name of the file, or directory, including path
	 # @parm Bool: entire_dir=0	-
	 #	If case the filename is directory, stop watching for the entire
	 #	directory including all files in it
	 # @return Bool - true == File actually added; false == something went wrong
	proc forget {filename {entire_dir 0}} {
		variable watched_files	;# List: Watched files

		# File or directory name has not to be empty
		if {$filename == {}} {
			return 0
		}

		set result 0
		set dirname [file dirname $filename]
		set tailname [file tail $filename]

		# Attempt to find the corresponding group of files
		set o_size [llength $watched_files]
		for {set group_index 0} {$group_index < $o_size} {incr group_index} {

			# Group directory name matches the filename parameter,
			#+ so we are about to forget about a directory
			if {[lindex $watched_files [list $group_index 0 0]] == $filename} {

				# Remove the entire group if the list of files is empty, that means
				#+ that we were watching only the directory itself, not any particular
				#+ files in it. Or in case that the removal of the entire directory
				#+ has been enforced by entire_dir parameter.
				if {![llength [lindex $watched_files [list $group_index 1]]] || $entire_dir} {
					set watched_files [lreplace $watched_files $group_index $group_index]
					set result 1

				# If the group is not empty, then remove just the notification
				#+ callback for the directory itself.
				} else {
					lset watched_files [list $group_index 0 2] {}
				}
			}

			# Group directory name matches the directory of the filename
			#+ parameter, so we about to forget about only a file from
			#+ that group
			if {[lindex $watched_files [list $group_index 0 0]] == $dirname} {
				# Attempt to find the file specification in the group's list of files
				set fl_size [llength [lindex $watched_files [list $group_index 1]]]
				for {set file_index 0} {$file_index < $fl_size} {incr file_index} {
					# File specification found
					if {[lindex $watched_files [list $group_index 1 $file_index 0]] == $tailname} {
						# Remove the designated file specification from the group
						set dir_spec [lindex $watched_files [list $group_index 0]]
						set file_list [lindex $watched_files [list $group_index 1]]
						set file_list [lreplace $file_list $file_index $file_index]
						set watched_files [lreplace $watched_files $group_index $group_index [list $dir_spec $file_list]]
						set result 1
					}
				}
			}
		}

		return $result
	}


	# ----------------------------------------------------------------------
	# INTERNAL FUNCTIONS
	# ----------------------------------------------------------------------

	## This function performs the watching itself, it supposed to be called
	 # by the watch timer.
	 # @return void
	proc timeout {} {
		variable watch_timer	;# Object: The watch timer
		variable watched_files	;# List: Watched files
		variable watch_interval	;# Int: Interval for periodical mtime checks, in ms

		set auto_remove [list]

		# Iterate over the groups
		set o_size [llength $watched_files]
		for {set group_index 0} {$group_index < $o_size} {incr group_index} {
			# Bool: the group is no longer valid, it's directory has 
			#+      been removed from the file system
			set dir_removed_from_FS 0
			# String: Directory of the group
			set dir_name [lindex $watched_files [list $group_index 0 0]]

			# The group directory must exists and must be a directory, otherwise, remove the group
			if {![file exists $dir_name] || ![file isdirectory $dir_name]} {
				set dir_removed_from_FS 1
				lappend auto_remove $dir_name
			}

			# If the group is no longer valid, we still have to send 
			#+ notifications for all the files in it
			if {$dir_removed_from_FS} {
				set dir_mtime_rec -1
				set dir_mtime_cur -2
			# Get the last known directory modification time and the current one
			} else {
				set dir_mtime_rec [lindex $watched_files [list $group_index 0 1]]
				set dir_mtime_cur [file mtime $dir_name]
			}

			# Compare the modification times (detect change in the directory itself)
			if {$dir_mtime_rec != $dir_mtime_cur} {
				# Update the recorded directory modification time
				lset watched_files [list $group_index 0 1] $dir_mtime_cur
				# Invoke notification callback
				set dir_callback [lindex $watched_files [list $group_index 0 2]]
				if {$dir_callback != {}} {
					uplevel #0 "$dir_callback {$dir_name}"
				}
			}

			# Iterate over files in the group
			set fl_size [llength [lindex $watched_files [list $group_index 1]]]
			for {set file_index 0} {$file_index < $fl_size} {incr file_index} {
				set file_removed_from_FS 0
				set file_name [lindex $watched_files [list $group_index 1 $file_index 0]]
				set file_name [file join $dir_name $file_name]

				# Check if the file spec. is still valid
				if {
					!$dir_removed_from_FS
						&&
					( ![file exists $file_name] || [file isdirectory $file_name] )
				} then {
					set file_removed_from_FS 1
					lappend auto_remove $file_name
				}

				# If the group is no longer valid, or the file has been removed from the
				#+ file system, we still have to send notifications for all the files in it
				if {$dir_removed_from_FS || $file_removed_from_FS} {
					set file_mtime_rec -1
					set file_mtime_cur -2
				} else {
					set file_mtime_rec [lindex $watched_files [list $group_index 1 $file_index 1]]
					set file_mtime_cur [file mtime $file_name]
				}

				# Compare the modification times (detect change in the file)
				if {$file_mtime_rec != $file_mtime_cur} {
					# Update the recorded file modification time
					lset watched_files [list $group_index 1 $file_index 1] $file_mtime_cur
					# Invoke notification callback
					set file_callback [lindex $watched_files [list $group_index 1 $file_index 2]]
					uplevel #0 "$file_callback {$file_name}"
				}
			}
		}

		# Forget files and directories removed from the file system
		foreach file_to_remove $auto_remove {
			forget $file_to_remove 1
		}

		# Again start the watch timer
		set watch_timer [after $watch_interval [list FSnotifications::timeout]]
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

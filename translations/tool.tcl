#! /usr/bin/tclsh
# Part of MCU 8051 IDE ( http://http://www.moravia-microsystems.com/mcu8051ide )

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

# --------------------------------------------------------------------------
# DESCRIPTION
#
# This is the translation manipulation tool written for the MCU 8051 IDE
# project, purpose of this tool is to simplify maintenance of the 
# translation files. Since the template.txt might get updated every now and 
# then, we need to keep the translation files updated.
# 
# This file is intended to be used as a stand-alone executable
#
# Command line options:
#   -t <file>
#       Update a translation template file (e.g. template.txt).
#   -m <file>
#       Update the given translation file (<file>) according to the
#       template.txt file located in the same directory as this script.
#   -h, --help, --usage
#       Print the help message.
# --------------------------------------------------------------------------

namespace eval TranslationManipulationTool {
	variable orig_dir	;# String: Directory from which the script was executed
	variable tmp_dir	;# String: Temporary directory, e.g. "/tmp"
	variable error_code	;# Int: Auxiliary variable indicating error

	## Initialize the tool, set some variables, etc.
	 # @return void
	proc init {} {
		variable orig_dir	;# String: Directory from which the script was executed
		variable tmp_dir	;# String: Temporary directory, e.g. "/tmp"
		variable error_code	;# Int: Auxiliary variable indicating error

		set error_code 0
		set orig_dir [pwd]
		set tmp_dir {/tmp}
		if {[string first {Windows} ${::tcl_platform(os)}] != -1} {
			set tmp_dir ${::env(TEMP)}
		}

		if {$tmp_dir == {}} {
			puts stderr "ERROR: Unable to determinate location of the temp directory."
			exit 1
		}

		cd [file dirname $::argv0]
	}

	## Update translation template file
	 #
	 # The update does these things:
	 #   - add IDs to translation strings which does not have any yet,
	 #   - remove duplicity translation strings,
	 #   - remove translation strings which clearly cannot be translated, e.g. "---  %s".
	 #
	 # @param String filename - Name of the subject for the update
	 # @return void
	proc update_template {filename} {
		variable orig_dir	;# String: Directory from which the script was executed
		variable tmp_dir	;# String: Temporary directory, e.g. "/tmp"
		variable error_code	;# Int: Auxiliary variable indicating error

		# Inform user about what we are doing
		puts ""
		puts " * Updating the template file: $filename"

		# Open the translation template file (for reading)
		if {[catch {
			set f [file join $orig_dir $filename]
			set template_file [open $f {r}]
		}]} then {
			puts stderr "ERROR: Unable to open $f file, exiting."
			exit 1
		}
		# Open a temporary file (for writing)
		if {[catch {
			set f [file join $tmp_dir "mcu8051ide_template_txt.tmp"]
			set template_file_tmp [open $f {w} 0644]
		}]} then {
			catch {
				close $template_file
			}
			puts stderr "ERROR: Unable to open mcu8051ide_template_txt.tmp file, exiting."
			exit 1
		}

		# Determinate the highest value of translation string ID
		set highest_id 0
		while {![eof $template_file]} {
			set line [gets $template_file]

			if {[regexp {^\s*##ID:\d{6}##\s*$} $line]} {
				regexp {\d{6}} $line id
				set id [string trimleft $id 0]
				if {![string length $id]} {
					set id 0
				}
				if {$id > $highest_id} {
					set highest_id $id
				}
			}
		}
		# Increment the highest ID by 10 in order to make less probable 
		#+ that we actually reuse an ID.
		if {$highest_id} {
			incr highest_id 10
		}

		# Update the template file, the file itself will remain unchanged,
		#+ we write results to the previously created/opened temporary file
		seek $template_file 0	   ;# Return at the beginning of the file
		set line		{} ;# String: Line read from the file
		set prev_line		{} ;# String: Line previously read from the file
		array set tr_str_in_ns	{} ;# Array of Lists: Translation strings in a namespace
		set current_namespace	{} ;# String: Current namespace
		set transl_count	0  ;# Int: Number of translation strings found in the template
		set rem_transl_count	0  ;# Int: Number of removed translation strings
		set add_ids_count	0  ;# Int: Number of added IDs
		while {![eof $template_file]} {
			set line_raw [gets $template_file]

			# Skip empty lines, or lines containing only white space
			if {[regexp {^\s*$} $line_raw]} {
				continue
			}

			set prev_line $line
			set line $line_raw

			# Detect white space
			if {[regexp {namespace\s+eval\s+[^\{]+} $line ns_name]} {
				regsub {namespace\s+eval\s+} $ns_name {} ns_name
				regsub {\s*$} $ns_name {} ns_name
				set current_namespace $ns_name
			}

			# Make the array with translation strings in a namespace aware of the current namespace
			if {[lsearch -ascii -exact [array names tr_str_in_ns] $current_namespace] == -1} {
				set tr_str_in_ns($current_namespace) [list]
			}

			# Attempt to extract the string for translation (original/source string)
			if {[regexp {^\s*mcset\s+\$l\s+} $line]} {
				set idx [string first {mcset} $line]
			} else {
				set idx -1
			}
			set trans_str $line
			regsub -all {^\s*mcset\s+\$l\s*} $trans_str {} trans_str ;# Remove "  mcset $l "
			regsub -all {\s*\\\s*$} $trans_str {} trans_str ;# Remove trailing backslash
			set trans_str_orig $trans_str
			regsub -all {\{} $trans_str "\\\{" trans_str
			regsub -all {\}} $trans_str "\\\}" trans_str
			regsub -all {\"} $trans_str "\\\"" trans_str
			if {$idx != -1} {
				# Check for possibly duplicity, this condition is not allowed and it has to fixed
				if {[lsearch -ascii -exact $tr_str_in_ns($current_namespace) $trans_str] != -1} {
					puts "Removing duplicity: $trans_str_orig from namespace $current_namespace"
					incr rem_transl_count
					# Remove the next line as well
					if {![eof $template_file]} {
						gets $template_file
					}
					continue
				}

				# Check for nonsense string for translation, e.g. "--- %s ---"
				if {![regexp {\w} $trans_str]} {
					puts "Removing nonsense: $trans_str_orig from namespace $current_namespace"
					incr rem_transl_count
					# Remove the next line as well
					if {![eof $template_file]} {
						gets $template_file
					}
					continue
				}

				# Remember this translation in order to be able to detect possible duplicities later
				lappend tr_str_in_ns($current_namespace) $trans_str
				incr transl_count

				# Generate and add a new ID if there is none yet
				if {![regexp {^\s*##ID:\d{6}##\s*$} $prev_line]} {
					incr add_ids_count
					puts $template_file_tmp [format "%s##ID:%06d##" [string repeat { } $idx] [incr highest_id]]
				} else {
					puts $template_file_tmp $prev_line
				}
			}

			# ID are handled separately, so we don't want them printed here
			if {![regexp {^\s*##ID:\d{6}##\s*$} $line]} {
				puts $template_file_tmp $line
			}
		}
		array unset tr_str_in_ns

		# Inform user about results
		puts ""
		puts "** Translation template updated"
		puts " * Current number of translation strings: $transl_count"
		puts " * Number of removed translation strings: $rem_transl_count"
		puts " * Number of added translation IDs: $add_ids_count"

		# Close all opened files
		if {[catch {
			close $template_file
		}]} then {
			puts stderr "ERROR: Unable to close the template file."
			set error_code 1
		}
		if {[catch {
			close $template_file_tmp
		}]} then {
			puts stderr "ERROR: Unable to close the template tmp file."
			set error_code 1
		}
		if {$error_code} {
			exit $error_code
		}

		# Move, copy, and/or remove files
		set s [file join $tmp_dir "mcu8051ide_template_txt.tmp"]
		set t "template.txt"
		catch {
			file rename -force $t "${t}~"
		}
		if {[catch {
			file copy -force $s $t
		}]} then {
			puts stderr "ERROR: Unable to copy $s --> $t."
			exit 1
		}
		catch {
			file delete -force $s
		}
	}

	## Update translation file (a .msg file)
	 #
	 # The update does these things:
	 #   -
	 #
	 # @param String filename - Name of the subject for the update
	 # @return void
	proc update_msg_file {filename} {
		variable orig_dir	;# String: Directory from which the script was executed
		variable tmp_dir	;# String: Temporary directory, e.g. "/tmp"
		variable error_code	;# Int: Auxiliary variable indicating error

		# Local variables, all of them are Int: number of -
		set missing_id_count	0 ;# - translation strings without ID
		set not_trans_count	0 ;# - not translated strings
		set trans_count		0 ;# - translated strings
		set updated_count	0 ;# - updated translation strings
		set found_in_src	0 ;# - translation strings found in the translation file
		set found_in_tmpl	0 ;# - translation strings found in the template file
		set added_count		0 ;# - translation strings copied from the translation file to the translation file
		set id_dupl_count	0 ;# - duplicities in translation string ID

		# Inform user about what we are doing
		puts ""
		puts "* Updating translation file: $filename"

		if {$filename == {}} {
			puts stderr "No file name given."
			return
		}
		if {[catch {
			set f [file join $orig_dir $filename]
			set source_file [open $f {r}]
		}]} then {
			puts stderr "ERROR: Unable to open $f file, exiting."
			exit 1
		}
		if {[catch {
			set f [file join . "template.txt"]
			set template_file [open $f {r}]
		}]} then {
			catch {
				close $source_file
			}
			puts stderr "ERROR: Unable to open $f file, exiting."
			exit 1
		}
		if {[catch {
			set f [file tail $filename]
			set f [file join $tmp_dir "${f}.tmp"]
			set target_file [open $f {w} 0644]
		}]} then {
			catch {
				close $source_file
			}
			catch {
				close $template_file
			}
			puts stderr "ERROR: Unable to open $f file, exiting."
			exit 1
		}

		array set trans_strs_by_id {}

		# Copy commets at the begining of the source file to the target file,
		#+ and load all translations into an array
		set header 1
		while {![eof $source_file]} {
			set line [gets $source_file]

			# Copy only continuous block of comments at the beginning of the file
			if {$header && [regexp {^\s*#} $line] && ![regexp {^\s*##ID:\d{6}##\s*$} $line]} {
				puts $target_file $line
				continue
			}
			if {$header} {
				set header 0
			}

			# Detect translation string ID
			if {[regexp {^\s*##ID:\d{6}##\s*$} $line]} {
				regexp {\d{6}} $line id

				# Get original string, the string for translation
				set trans_str_org [get_trans_str_org $source_file]
				if {$trans_str_org == {}} {
					break ;# We can still partially recover from here
				}
				set trans_str_org_raw [lindex $trans_str_org 1]
				set trans_str_org [lindex $trans_str_org 0]

				# Get translated string
				set trans_str_trn [get_trans_str_trn $source_file]
				if {$trans_str_trn == {}} {
					break ;# We can still partially recover from here
				}
				set update_flag [lindex $trans_str_trn 2]
				set trans_str_trn_raw [lindex $trans_str_trn 1]
				set trans_str_trn [lindex $trans_str_trn 0]

				# Check whether strings {} have the same length
				if {
					[string index [lindex $trans_str_org 0] 1] == "\{"
						&&
					[string length $trans_str_trn] != [string length $trans_str_org]
				} then {
					puts stderr "Warning: Translation probably violates the translation rules: ``$trans_str_org_raw'' --> ``$trans_str_trn_raw''"
				}

				# Detect, and remove, strings with duplicit IDs
				if {[lsearch -ascii -exact [array names trans_strs_by_id] $id] != -1} {
					puts stderr "Warning: Duplicit ID found: $id, ignoring!"
					incr id_dupl_count
				} else {
					set trans_strs_by_id($id) [list $trans_str_org $trans_str_trn $update_flag]
					incr found_in_src
				}
			}

			# The mcset command should have been already handled when ID was detected
			if {[regexp {^\s*mcset\s+\$l\s+} $line]} {
				set idx [string first {mcset} $line]
			} else {
				set idx -1
			}
			if {$idx != -1} {
				regsub -all {^\s*mcset\s+\$l\s*} $line {} line ;# Remove "  mcset $l "
				regsub -all {\s*\\\s*$} $line {} line ;# Remove trailing backslash
				puts stderr "Warning: Missing translation string ID: ``$line'', removing!"
			}
		}
		# We don't need the source file opened for reading any more
		catch {
			close $source_file
		}

		# Copy the rest (not commets at the begining of the file) from the
		#+ template file to the target file, and update it from the
		#+ trans_strs_by_id array which was extracted from the source file
		set header 1
		while {![eof $template_file]} {
			set line [gets $template_file]

			# Copy commets at the begining of the template file
			if {$header && [regexp {^\s*#} $line] && ![regexp {^\s*##ID:\d{6}##\s*$} $line]} {
				continue
			}
			if {$header} {
				set header 0
			}

			# Detect translation string ID
			if {[regexp {^\s*##ID:\d{6}##\s*$} $line]} {
				regexp {\d{6}} $line id

				# Get original string, the string for translation
				set trans_str_org [get_trans_str_org $template_file]
				if {$trans_str_org == {}} {
					exit 1 ;# It would make no sense to continue from here
				}
				set mcset_idx [lindex $trans_str_org 2]
				set trans_str_org_raw [lindex $trans_str_org 1]
				set trans_str_org [lindex $trans_str_org 0]

				# Get translated string
				set trans_str_trn [get_trans_str_trn $template_file]
				if {$trans_str_trn == {}} {
					exit 1 ;# It would make no sense to continue from here
				}
				set trans_str_trn_raw [lindex $trans_str_trn 1]
				set trans_str_trn [lindex $trans_str_trn 0]

				# Regenerate the mcset command along with the string for translation
				set original_string [string repeat { } $mcset_idx]
				append original_string {mcset $l } $trans_str_org " \\"
				regsub -all {\\\{} $original_string "\{" original_string
				regsub -all {\\\}} $original_string "\}" original_string
				regsub -all {\\\"} $original_string "\"" original_string

				# Regenerate new translated string
				set translation [string repeat { } [expr {$mcset_idx + 9}]]
				if {[lsearch -ascii -exact [array names trans_strs_by_id] $id] == -1} {
					# The string was not even found in the given translation file
					append translation $trans_str_trn
					regsub -all {\\\{} $translation "\{" translation
					regsub -all {\\\}} $translation "\}" translation
					regsub -all {\\\"} $translation "\"" translation
				} else {
					# The string was found in the translation file
					append translation [lindex $trans_strs_by_id($id) 1]
					regsub -all {\\\{} $translation "\{" translation
					regsub -all {\\\}} $translation "\}" translation
					regsub -all {\\\"} $translation "\"" translation

					# But, it has not been translated (yet)
					if {$trans_str_trn == [lindex $trans_strs_by_id($id) 1]} {
						append translation " ;# <-- NOT TRANSLATED YET"
						incr not_trans_count
					} else {
						incr trans_count
					}

					# If the source string (string for translation) in the template differs from
					# the same string in the given translation file then add " ;# <-- UPDATE?"
					# comment there.
					if {$trans_str_org != [lindex $trans_strs_by_id($id) 0]} {
						set foo [lindex $trans_strs_by_id($id) 0]
						regsub -all {\\\{} $foo "\{" foo
						regsub -all {\\\}} $foo "\}" foo
						regsub -all {\\\"} $foo "\"" foo
						puts "Source strings does not match, translation might need an update: ``$trans_str_org_raw'' --> ``$foo''"
						append translation " ;# <-- UPDATE?"
						incr updated_count
					} elseif {[lindex $trans_strs_by_id($id) 2]} {
						append translation " ;# <-- UPDATE?"
					}
				}

				# Write results to the temporary file
				puts $target_file $line			;# <-- #ID:dddddd##
				puts $target_file $original_string	;# <-- mcset $l "original string"
				puts $target_file $translation		;# <--          "translated string"

				incr found_in_tmpl
				continue
			}

			# Copy the rest
			puts $target_file $line
		}
		array unset trans_strs_by_id {}

		set added_count [expr {$found_in_tmpl - $found_in_src}]

		# Inform user about results
		puts ""
		puts "** File: $filename updated"
		puts " * Number of translations without ID: $missing_id_count"
		puts " * Number of ID duplicities: $id_dupl_count"
		puts " * Translated strings: $trans_count"
		puts " * Not translated strings: $not_trans_count"
		puts " * Number of translation which might need to be updated: $updated_count"
		puts " * Number of strings added for translations: $added_count"

		# Close all opened files
		if {[catch {
			close $template_file
		}]} then {
			puts stderr "ERROR: Unable to close the template file."
			set error_code 1
		}
		if {[catch {
			close $target_file
		}]} then {
			puts stderr "ERROR: Unable to close the target file."
			set error_code 1
		}
		if {$error_code} {
			exit $error_code
		}

		# Move, copy, and/or remove files
		set s [file tail $filename]
		set s [file join $tmp_dir "${s}.tmp"]
		set t [file join $orig_dir $filename]
		catch {
			file rename -force $t "${t}~"
		}
		if {[catch {
			file copy -force $s $t
		}]} then {
			puts stderr "ERROR: Unable to copy $s --> $t."
			exit 1
		}
		catch {
			file delete -force $s
		}
	}

	## Attempt to extract string for translation from the given file
	 # @param ChannelID source_file - File descriptor returned by "open"
	 # @return List:
	 #   - {escaped_string raw_string index_of_mcset}  <-- In case of success
	 #   - {}                                          <-- In case of failure
	proc get_trans_str_org {source_file} {
		if {[eof $source_file]} {
			puts stderr "Warning: Unexpected end of file."
			return {}
		}
		set trans_str_org [gets $source_file]
		if {[regexp {^\s*mcset\s+\$l\s+} $trans_str_org]} {
			set idx [string first {mcset} $trans_str_org]
		} else {
			set idx -1
		}
		if {$idx == -1} {
			puts stderr "ERROR: Expected ``mcset $l'' at the beginnig of the line!"
			return {}
		}
		regsub -all {^\s*mcset\s+\$l\s*} $trans_str_org {} trans_str_org ;# Remove "  mcset $l "
		regsub -all {\s*\\\s*$} $trans_str_org {} trans_str_org ;# Remove trailing backslash
		set trans_str_org_raw $trans_str_org
		regsub -all {\{} $trans_str_org "\\\{" trans_str_org
		regsub -all {\}} $trans_str_org "\\\}" trans_str_org
		regsub -all {\"} $trans_str_org "\\\"" trans_str_org

		return [list $trans_str_org $trans_str_org_raw $idx]
	}

	## Attempt to extract translated string from the given file
	 # @param ChannelID source_file - File descriptor returned by "open"
	 # @return List:
	 #   - {escaped_string raw_string update_flag}  <-- In case of success
	 #   - {}                                       <-- In case of failure
	 # @note
	 # update_flag == 1 means that there was ``;# <-- UPDATE?'' on the line,
	 # it's important because that comment should be preserved
	proc get_trans_str_trn {source_file} {
		if {[eof $source_file]} {
			puts stderr "Warning: Unexpected end of file."
			return {}
		}
		set trans_str_trn [gets $source_file]
		if {[regexp  ";# <-- UPDATE\?" $trans_str_trn]} {
			set update_flag 1
		} else {
			set update_flag 0
		}
		regsub -all ";#.*$" $trans_str_trn {} trans_str_trn ;# Remove commet
		regsub -all {\s*$} $trans_str_trn {} trans_str_trn ;# Remove trailing white space
		regsub -all {^\s*} $trans_str_trn {} trans_str_trn ;# Remove leading white space
		set trans_str_trn_raw $trans_str_trn
		regsub -all {\{} $trans_str_trn "\\\{" trans_str_trn
		regsub -all {\}} $trans_str_trn "\\\}" trans_str_trn
		regsub -all {\"} $trans_str_trn "\\\"" trans_str_trn

		return [list $trans_str_trn $trans_str_trn_raw $update_flag]
	}

	## Print some information about what this tool is, and what's the license, etc.
	 # @return void
	proc print_basic_info {} {
		puts "Translation manipulation tool written for MCU 8051 IDE."
		puts ""
		puts "This software is licensed under GNU GPLv2 and comes with no warranty, "
		puts "please report any bugs you encounter to the author of the script:"
		puts "<mailto:martin.osmera@gmail.com>."
		puts ""
	}

	## Print help message to inform the user how to use this tool
	 # @return void
	proc print_help {} {
		print_basic_info
		puts "Options:"
		puts "  -t <file>"
		puts "      Update a translation template file (e.g. template.txt)."
		puts ""
		puts "  -m <file>"
		puts "      Update the given translation file (<file>) according to the"
		puts "      template.txt file located in the same directory as this script."
		puts ""
		puts "  -h, --help, --usage"
		puts "      Print this message."
		puts ""
	}

	## Entry point to the tool functions
	 # @return void
	proc main {} {
		# If no CLI arguments were provided, print the help message
		if {!$::argc} {
			print_help
			return 1
		}

		# Initialize the tool
		TranslationManipulationTool::init

		# List: Operations to execute
		set command_list [list]

		# Iterate over provided CLI arguments list and process it
		for {set i 0} {$i < $::argc} {incr i} {
			set arg [lindex $::argv $i]
			switch -exact -- $arg {
				{-h} {	;# Print the help message
					print_help
					return 0
				}
				{--help} {	;# Print the help message
					print_help
					return 0
				}
				{--usage} {	;# Print the help message
					print_help
					return 0
				}
				{-t} {	;# Update template file
					set filename [lindex $::argv [incr i]]
					if {![string length $filename]} {
						puts stderr "Argument expected after the $arg option."
						exit 1
					}
					lappend command_list "update_template $filename"
				}
				{-m} {	;# Update translation file
					set filename [lindex $::argv [incr i]]
					if {![string length $filename]} {
						puts stderr "Argument expected after the $arg option."
						exit 1
					}
					lappend command_list "update_msg_file $filename"
				}
				default {	;# Nonsense argument --> error
					puts stderr "Unknown option ``$arg''."
					puts stderr "Please type \"${::argv0} --help\" for help."
					return 1
				}
			}
		}

		# Print some information about what this tool is, and what's the license, etc.
		print_basic_info

		# Execute required operations
		foreach cmd $command_list {
			eval $cmd
		}

		# Success
		return 0
	}
}

# Start the tool
exit [TranslationManipulationTool::main]

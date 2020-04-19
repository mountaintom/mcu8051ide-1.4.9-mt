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
if { ! [ info exists _PROJECT_TCL ] } {
set _PROJECT_TCL _
# <<< File inclusion guard

# --------------------------------------------------------------------------
# DESCRIPTION
# Implements project files management
# --------------------------------------------------------------------------

namespace eval Project {

	variable xml_data_tk_mcuide_project	{}	;# Attributes of <tk_mcuide_project>
	variable xml_data_authors		{}	;# Content of <authors>
	variable xml_data_copyright		{}	;# Content of <copyright>
	variable xml_data_license		{}	;# Content of <license>
	variable xml_data_processor		{}	;# Attributes of <processor>
	variable xml_data_options		{}	;# Attributes of <options>
	variable xml_data_graph			{}	;# Attributes of <graph>
	variable xml_data_description		{}	;# Content of <description>
	variable xml_data_todo			{}	;# Content of <todo>
	variable xml_data_calculator		{}	;# Attributes of <calculator>
	variable xml_data_other_options		{}	;# Content of <other_options>
	variable xml_data_compiler_options	{}	;# Content of <compiler_options>
	variable xml_data_files			{}	;# Contents of <file>
	variable xml_data_file_notes		{}	;# Contents of <notes>
	variable xml_data_files_count		{}	;# Number of files

	variable xml_data_file			{}	;# Auxiliary variable for xml_data_files
	variable xml_attlist				;# Auxiliary variable - List of current tag attributes
	variable xml_expect			{}	;# XML tag expected to be the next
	variable xml_curTag			{}	;# Currenly parsed XML tag
	variable xml_start			{}	;# Bool: True at start of parsing
	variable expect_data_part		1	;# Bool: True if on the next comes data
	variable xml_warning			0	;# Bool: True if an error occurred during parsing process

	## Create string which can be saved as a project definition file (format: XML)
	 # @parm List inputData - requested format: {
	 #	{version date creator_ver}			# tag: tk_mcuide_project
	 #	{authors copyright license}			# tag: authors copyright license
	 #	{type clock xdata xcode}			# tag: processor
	 #	{watches_file scheme main_file auto_sw_enabled}	# tag: options
	 #	{grid_mode magnification drawing_on
	 #		mark_flags_true_state mark_flags_latched
	 #		mark_flags_output active_page}		# tag: graph
	 #	{description todo}				# tag: descriptin todo
	 #	{radix angle_unit				# tag: calculator
	 #		display0 display1 display2
	 #		memory0 memory1 memory2
	 #		frequency time mode}
	 #	{other_options}					# tag: other_options
	 #	{compiler_options}
	 #	{files_count {current_file			# tag: files
	 #		current_file2 pwin_sash pwin_orient}
	 #		{					# tag: file actual_line md5_hash path bookmarks breakpoints
	 #			name		active		o_bookmark	p_bookmark
	 #			file_index	read_only	actual_line	md5_hash
	 #			path		bookmarks	breakpoints	eol
	 #			enc		highlight	notes
	 #		}
	 #		...
	 #	}
	 # }
	 # @return String - outpud data (formatted as XML)
	proc create_project_file_as_string {inputData} {

		# Initialize variables related to content of the file
		if {$inputData != {}} {

			# Definition of file structure (except of <files>)
			set dataPartStructure {
				{version date creator_ver}
				{authors copyright license}
				{mcu_type clock xdata xcode}
				{watches_file scheme main_file auto_sw_enabled}
				{graph_grid_mode graph_magnification graph_drawing_on graph_mark_flags_s graph_mark_flags_l graph_mark_flags_o active_page}
				{description todo}
				{calc_radix angle_unit display0 display1 display2 memory0 memory1 memory2 freq time mode}
				{other_options}
				{compiler_options}
			}

			# Parse part of input list
			set i 0
			foreach record $dataPartStructure {
				set data [lindex $inputData $i]
				incr i
				foreach value $data var $record {
					set $var $value
				}
			}

			# Parse remain of input list
			set files		[lindex $inputData 9]
			set files_count		[lindex $files 0]
			set current_file	[lindex $files {1 0}]
			set current_file2	[lindex $files {1 1}]
			set pwin_sash		[lindex $files {1 2}]
			set pwin_orient		[lindex $files {1 3}]
			set selected_view	[lindex $files {1 4}]
			set files		[lreplace $files 0 1]

		# Set all variables to defaults
		} else {
			foreach var {
				version		date		creator_ver	authors		copyright
				license		other_options	files_count	mcu_type	xdata
				watches_file	files		description	todo		calc_radix
				angle_unit	display0	display1	display2	memory0
				memory1		memory2		clock		freq		time
				mode		graph_grid_mode	graph_magnification		graph_drawing_on
				auto_sw_enabled	current_file2	graph_mark_flags_o		active_page
				xcode		scheme		graph_mark_flags		graph_mark_flags_l
				pwin_sash	main_file	compiler_options		graph_mark_flags_s
			} \
			{
				set $var {}
			}
		}

		# Discard input data
		unset inputData

		# Initialize resulting string
		set result {}

		## Create XML string
		append result "<?xml version='1.0' encoding='utf-8'?>\n"
		if {[file exists "${::ROOT_DIRNAME}/data/project.dtd"]} {
			if {[catch {
				set dtd	[open "${::ROOT_DIRNAME}/data/project.dtd" r]
			}]} then {
				puts stderr "Unable to open project DTD, please check your installation."
			} else {
				append result "<!DOCTYPE tk_mcuide_project \[\n\n"
				while {1} {
					if {[eof $dtd]} {
						close $dtd
						break
					}
					set line [gets $dtd]
					if {[string length $line]} {
						append result "\t" $line
					}
					append result "\n"
				}
				append result "\]>\n"
			}
		}
		append result "<tk_mcuide_project version=\"[adjust_to_xml $version]\""
		append result " date=\"[adjust_to_xml $date]\" creator_ver=\"${::VERSION}\">\n"
		append result "\t<general>\n"
		append result "\t\t<authors><!\[CDATA\[[adjust_to_xml $authors]\]\]></authors>\n"
		append result "\t\t<copyright><!\[CDATA\["
		append result "[adjust_to_xml $copyright]\]\]></copyright>\n"
		append result "\t\t<license><!\[CDATA\[[adjust_to_xml $license]\]\]></license>\n"
		append result "\t\t<processor type=\"[adjust_to_xml $mcu_type]\" clock=\"[adjust_to_xml $clock]\""
		append result " xdata=\"[adjust_to_xml $xdata]\" xcode=\"[adjust_to_xml $xcode]\"/>\n"
		append result "\t\t<options\n"
		append result "\t\t\twatches_file=\"[adjust_to_xml $watches_file]\"\n"
		append result "\t\t\tscheme=\"[adjust_to_xml $scheme]\"\n"
		append result "\t\t\tmain_file=\"[adjust_to_xml $main_file]\"\n"
		append result "\t\t\tauto_sw_enabled=\"[adjust_to_xml $auto_sw_enabled]\"\n"
		append result "\t\t\t/>\n"
		append result "\t\t<graph\n"
		append result "\t\t\tgrid=\"$graph_grid_mode\"\n"
		append result "\t\t\tmagnification=\"$graph_magnification\"\n"
		append result "\t\t\tenabled=\"$graph_drawing_on\"\n"
		append result "\t\t\tmarks_s=\"$graph_mark_flags_s\"\n"
		append result "\t\t\tmarks_l=\"$graph_mark_flags_l\"\n"
		append result "\t\t\tmarks_o=\"$graph_mark_flags_o\"\n"
		append result "\t\t\tactive_page=\"$active_page\"\n"
		append result "\t\t/>\n"
		append result "\t\t<description><!\[CDATA\[[adjust_to_xml $description]\]\]></description>\n"
		append result "\t\t<todo><!\[CDATA\[[unescape_curlies $todo]\]\]></todo>\n"
		append result "\t\t<calculator\n"
		append result "\t\t\tradix=\"[adjust_to_xml $calc_radix]\"\n"
		append result "\t\t\tangle_unit=\"[adjust_to_xml $angle_unit]\"\n"
		append result "\t\t\tdisplay0=\"[adjust_to_xml $display0]\"\n"
		append result "\t\t\tdisplay1=\"[adjust_to_xml $display1]\"\n"
		append result "\t\t\tdisplay2=\"[adjust_to_xml $display2]\"\n"
		append result "\t\t\tmemory0=\"[adjust_to_xml $memory0]\"\n"
		append result "\t\t\tmemory1=\"[adjust_to_xml $memory1]\"\n"
		append result "\t\t\tmemory2=\"[adjust_to_xml $memory2]\"\n"
		append result "\t\t\tfreq=\"[adjust_to_xml $freq]\"\n"
		append result "\t\t\ttime=\"[adjust_to_xml $time]\"\n"
		append result "\t\t\tmode=\"[adjust_to_xml $mode]\"\n"
		append result "\t\t/>\n"
		append result "\t</general>\n"
		append result "\t<other_options><!\[CDATA\[[adjust_to_xml $other_options]\]\]></other_options>\n"
		append result "\t<compiler_options><!\[CDATA\[[adjust_to_xml $compiler_options]\]\]></compiler_options>\n"
		append result "\t<files\n"
		append result "\t\tcount=\"[adjust_to_xml $files_count]\"\n"
		append result "\t\tcurrent_file=\"[adjust_to_xml $current_file]\"\n"
		append result "\t\tcurrent_file2=\"[adjust_to_xml $current_file2]\"\n"
		append result "\t\tpwin_sash=\"[adjust_to_xml $pwin_sash]\"\n"
		append result "\t\tselected_view=\"[adjust_to_xml $selected_view]\"\n"
		append result "\t\tpwin_orient=\"[adjust_to_xml $pwin_orient]\">\n\n"
		foreach file $files {
			foreach	value $file	\
				var {
					name		active		o_bookmark	p_bookmark
					file_index	read_only	actual_line	md5_hash
					path		bookmarks	breakpoints	eol
					enc		highlight	notes
				} \
			{
				set $var $value
			}
			append result "\t\t<file name=\"[adjust_to_xml $name]\" active=\"[adjust_to_xml $active]\" "
			append result "o_bookmark=\"$o_bookmark\" p_bookmark=\"$p_bookmark\" "
			append result "file_index=\"$file_index\" read_only=\"$read_only\" highlight=\"$highlight\">\n"
			append result "\t\t\t<actual_line value=\"[adjust_to_xml $actual_line]\"/>\n"
			append result "\t\t\t<md5_hash value=\"[adjust_to_xml $md5_hash]\"/>\n"
			append result "\t\t\t<path><!\[CDATA\[[adjust_to_xml $path]\]\]></path>\n"
			append result "\t\t\t<bookmarks>\n\t\t\t\t[adjust_to_xml $bookmarks]\n"
			append result "\t\t\t</bookmarks>\n"
			append result "\t\t\t<breakpoints>\n\t\t\t\t[adjust_to_xml $breakpoints]\n"
			append result "\t\t\t</breakpoints>\n"
			append result "\t\t\t<eol value=\"$eol\"/>\n"
			append result "\t\t\t<encoding value=\"$enc\"/>\n"
			append result "\t\t\t<notes><!\[CDATA\[[adjust_to_xml $notes]\]\]></notes>\n"
			append result "\t\t</file>\n\n"
		}
		append result "\t</files>\n"
		append result "</tk_mcuide_project>\n"

		# Return resulting XML String
		return $result
	}

	## Open project (open project file, parse it and Initialize new instance of MainTab class)
	 # @parm String filename
	 # @return Bool - result
	proc open_project_file {filename} {
		set filename [file normalize $filename]

		# Check for file existance
		if {![file exists $filename]} {return 0}

		# Retreive project data list from the file
		if {[catch {
			set projectFile [open $filename r]
			set dataList [create_list_from_project_string [read $projectFile]]
			close $projectFile
		}]} then {
			return 0
		}

		# Check for project data list validity
		if {$dataList == {}} {return 0}

		# Local variables
		regexp {^.*[\\\/]}	$filename		projectPath		;# Path to project file
		regsub {[\\\/]$}	$projectPath		{}	projectPath
		regexp {[^\\\/]*$}	$filename		projectFileName		;# Name of project definition file
		regexp {[^\\\/]+$}	$filename		project_new_name	;# Name of the project
		regsub {\.[^\.]+$}	$project_new_name	{}	project_new_name
		set projectDescriptor [regsub -all -- {\s} $project_new_name {-}]
		regsub -all {[\\\/\.\,`\!@#\$%\^&:\;\|\*\"\(\)\[\]\{\}]}	\
			$projectDescriptor {_} projectDescriptor

		# Take care of opening multiple instances of the same project
		if {[lsearch ${::X::openedProjects} $projectDescriptor] != -1} {
			append project_new_name "(0)"
			append projectDescriptor "_0"

			while {1} {
				if {[lsearch ${::X::openedProjects} $projectDescriptor] == -1} {break}

				regexp {\d+$} $projectDescriptor index
				regsub {_\d+$} $projectDescriptor {} projectDescriptor

				regexp {\d+\)$} $project_new_name index
				set index [string trimright $index {\)}]
				regsub {\(\d+\)$} $project_new_name {} project_new_name

				incr index
				append project_new_name "($index)"
				append projectDescriptor "_$index"
			}
		}

		# Show project notebook
		if {${::X::project_menu_locked}} {
			pack .mainFrame.mainNB -expand 1 -fill both
		}

		# Adjust project related variables in NS ::X::
		lappend ::X::openedProjects $projectDescriptor
		lappend ::X::simulator_enabled 0
		# Initialize project object
		MainTab ::$projectDescriptor $project_new_name $projectPath $projectFileName $dataList

		# Unlock all menu items
		if {${::X::project_menu_locked}} {
			::X::Unlock_project_menu
		}
		::X::disaena_menu_toolbar_for_current_project

		# Done ...
		return 1
	}

	## Parse given project definition (XML) and return resulting data-list
	 # @parm String inputData - content of the project file
	 # @return List - result or {}
	proc create_list_from_project_string {inputData} {
		variable xml_data_tk_mcuide_project	;# Attributes of <tk_mcuide_project>
		variable xml_data_authors		;# Content of <authors>
		variable xml_data_copyright		;# Content of <copyright>
		variable xml_data_license		;# Content of <license>
		variable xml_data_processor		;# Attributes of <processor>
		variable xml_data_options		;# Attributes of <options>
		variable xml_data_graph			;# Attributes of <graph>
		variable xml_data_description		;# Content of <description>
		variable xml_data_todo			;# Content of <todo>
		variable xml_data_calculator		;# Attributes of <calculator>
		variable xml_data_other_options		;# Content of <other_options>
		variable xml_data_compiler_options	;# Content of <compiler_options>
		variable xml_data_files			;# Contents of <file>
		variable xml_data_files_count		;# Number of files

		variable xml_expect			;# XML tag expected to be the next
		variable xml_curTag			;# Currenly parsed XML tag
		variable xml_data_file			;# Auxiliary variable for xml_data_files
		variable xml_warning			;# Bool: True if an error occurred during parsing process
		variable xml_start			;# Bool: True at start of parsing

		# Setup XML parser
		set parser [::xml::parser -final 1 -ignorewhitespace 1				\
			-elementstartcommand Project::project_xml_parser_handler_element	\
			-elementendcommand Project::project_xml_parser_handler_element_end	\
			-characterdatacommand Project::project_xml_parser_handler_data		\
		]


		set xml_warning 0	;# No error so far
		set xml_start 1		;# Parsing just begun

		# Start XML parser
		if {[catch {
			$parser parse $inputData
		} result]} then {
			puts stderr "XML parse error: $result"
			report_project_loading_error
			return {}
		}

		# Unload XML parser
		$parser free
		if {$xml_warning} {
			free_resources
			return {}
		}

		# Composite resulting string
		set result {}
		lappend result		[unescape_tags $xml_data_tk_mcuide_project]
		lappend result		[list				\
			[unescape_tags $xml_data_authors	]	\
			[unescape_tags $xml_data_copyright	]	\
			[unescape_tags $xml_data_license	]	\
		]
		lappend result		$xml_data_processor
		lappend result		[unescape_tags $xml_data_options]
		lappend result		$xml_data_graph
		lappend result		[list				\
			[unescape_tags $xml_data_description	]	\
			[unescape_tags $xml_data_todo		]	\
		]
		lappend result		[unescape_tags $xml_data_calculator	]
		lappend result		[unescape_tags $xml_data_other_options	]
		lappend result		[unescape_curlies [unescape_tags $xml_data_compiler_options]]

		lappend__xml_data_files__xml_data_file	;# Note that this is an important function
		lappend result		[concat		\
			$xml_data_files_count		\
			[unescape_tags $xml_data_files]	\
		]

		# Free used memory
		free_resources

		# Return resulting List
		return $result

	}

	## Free memory used during parsing
	 # @return void
	proc free_resources {} {
		variable xml_data_tk_mcuide_project	;# Attributes of <tk_mcuide_project>
		variable xml_data_authors		;# Content of <authors>
		variable xml_data_copyright		;# Content of <copyright>
		variable xml_data_license		;# Content of <license>
		variable xml_data_processor		;# Attributes of <processor>
		variable xml_data_options		;# Attributes of <options>
		variable xml_data_graph			;# Attributes of <graph>
		variable xml_data_description		;# Content of <description>
		variable xml_data_todo			;# Content of <todo>
		variable xml_data_calculator		;# Attributes of <calculator>
		variable xml_data_other_options		;# Content of <other_options>
		variable xml_data_compiler_options	;# Content of <compiler_options>
		variable xml_data_files			;# Contents of <file>
		variable xml_data_file_notes		;# Contents of <notes>
		variable xml_data_files_count		;# Number of files

		variable xml_expect			;# XML tag expected to be the next
		variable xml_curTag			;# Currenly parsed XML tag
		variable xml_data_file			;# Auxiliary variable for xml_data_files
		variable xml_start			;# Bool: True at start of parsing

		# Set all listed variables to empty string
       		foreach var {
				xml_data_tk_mcuide_project	xml_data_authors	xml_data_copyright
				xml_data_license		xml_curTag		xml_data_processor
				xml_data_options		xml_data_description	xml_data_todo
				xml_data_files			xml_data_calculator	xml_data_other_options
				xml_data_files_count		xml_data_current_file	xml_data_file
				xml_expect			xml_data_graph		xml_data_compiler_options
				xml_data_file_notes
			} \
		{
			set $var {}
		}
	}

	## Invoke dialog to report error occcured while parsing data
	 # @return void
	proc report_project_loading_error {} {
		variable xml_warning	;# Bool: True if an error occurred during parsing process

		# Ensure than there is only one error message dialog
		if {$xml_warning} {return}

		# Invoke dialog
		tk_messageBox					\
			-icon error				\
			-type ok				\
			-parent .				\
			-title [mc "Project loading error"]	\
			-message [mc "ERROR:\nThe project file cannot be loaded correctly due to a xml parsing error. The file is either corrupted or it is not a project file acceptable by this environment."]

		set xml_warning 1
	}

	## Escape curly brackets and convert '<' and '>' to HTML entities
	 # @parm String data - input
	 # @return String - output
	proc adjust_to_xml {data} {
		set data [unescape_curlies $data]
		return [escape_tags $data]
	}

	## Unescape curly brackets
	 # @parm String data - input
	 # @return String - output
	proc unescape_curlies {data} {
		regsub -all {\\\{} $data "{" data
		regsub -all {\\\}} $data "}" data
		return $data
	}

	## Escape curly brackets
	 # @parm String data - input
	 # @return String - output
	proc escape_curlies {data} {
		regsub -all {\{} $data "\\{" data
		regsub -all {\}} $data "\\}" data
		return $data
	}

	## Convert '&lt;' -> '<' and '&gt;' -> '>'
	 # @parm String data - input
	 # @return String - output
	proc unescape_tags {data} {
		regsub -all {&amp;} $data "\\&" data
		regsub -all {&lt;}  $data "<" data
		regsub -all {&gt;}  $data ">" data
		regsub -all {&quot;} $data "\"" data
		regsub -all {\\\"} $data "\"" data
		regsub -all {\\\\} $data "\\" data
		return $data
	}

	## Convert '<' -> '&lt;' and '>' -> '&gt;'
	 # @parm String data - input
	 # @return String - output
	proc escape_tags {data} {
		regsub -all {&} $data "\\&amp;" data
		regsub -all {<}  $data "\\&lt;" data
		regsub -all {>}  $data "\\&gt;" data
		regsub -all {\"} $data "\\&quot;" data
		regsub -all {\\\"} $data "\"" data
		return $data
	}

	## Parse attributes of current tab
	 # @parm String nextTag	- name of XML tag which is expected to be the next
	 # @parm List Attrlist	- list of attributes to process
	 # @return List - result
	proc project_xml_attr_parser {nextTag Attrlist} {
		variable xml_attlist	;# Auxiliary variable - List of attributes of current tag

		# Set expected tag
		project_xml_expect $nextTag

		# Create array of attributes
		for {set i 0} {$i <= [llength $xml_attlist]} {incr i} {
			set name	[lindex $xml_attlist $i]
			incr i
			set value	[lindex $xml_attlist $i]
			set attr($name) [escape_curlies $value]
		}

		# Parse attributes and composite result
		set result {}
		foreach attrName $Attrlist {
			if {![info exists attr($attrName)]} {set attr($attrName) {}}
			lappend result $attr($attrName)
		}

		# Return result
		return $result
	}

	## Set name of XML tag which must follow the cuurent one
	 # @parm String nextTag - XML tag
	 # @return Bool - result
	proc project_xml_expect {nextTag} {
		variable xml_expect	;# XML tag expected to be the next
		variable xml_curTag	;# Currenly parsed XML tag

		# Check if the current tag was expected
		if {$xml_expect != $xml_curTag && [lsearch $xml_expect $xml_curTag] == -1} {
			puts stderr "Expected XML tag was: \"$xml_expect\", but \"$xml_curTag\" was given"
			set xml_expect $nextTag
			report_project_loading_error
			return 0
		}

		# Set expected tag
		set xml_expect $nextTag
		return 1
	}

	## XML parser handler - Handles XML tag end
	 # @return void
	proc project_xml_parser_handler_element_end args {
		variable expect_data_part	;# Bool: True if on the next comes data

		set expect_data_part 0
	}

	## XML parser handler - handles XML data
	 # @parm String arg1	- content of the element
	 # @return void
	proc project_xml_parser_handler_data {data} {
		variable expect_data_part		;# Bool: True if on the next comes data
		variable xml_expect			;# XML tag expected to be the next
		variable xml_curTag			;# Currenly parsed XML tag
		variable xml_start			;# Bool: True at start of parsing
		variable xml_attlist			;# Auxiliary variable - List of current tag attributes
		variable xml_warning			;# Bool: True if an error occurred during parsing process

		variable xml_data_tk_mcuide_project	;# Attributes of <tk_mcuide_project>
		variable xml_data_authors		;# Content of <authors>
		variable xml_data_copyright		;# Content of <copyright>
		variable xml_data_license		;# Content of <license>
		variable xml_data_processor		;# Attributes of <processor>
		variable xml_data_options		;# Attributes of <options>
		variable xml_data_graph			;# Attributes of <graph>
		variable xml_data_description		;# Content of <description>
		variable xml_data_todo			;# Content of <todo>
		variable xml_data_calculator		;# Attributes of <calculator>
		variable xml_data_other_options		;# Content of <other_options>
		variable xml_data_compiler_options	;# Content of <compiler_options>
		variable xml_data_files			;# Contents of <file>
		variable xml_data_files_count		;# Number of files
		variable xml_data_file			;# Contents of <file>
		variable xml_data_file_notes		;# Contents of <notes>

		# Abort on error
		if {$xml_warning} {return}

		# Inicalize on parser start up
		if {$xml_start} {
			set xml_start 0
			set xml_expect "xml_data_tk_mcuide_project"
		}
		# Check if data part is expected
		if {!$expect_data_part} {
			return
		}

		# Adjust given data
		if {$xml_curTag != {todo}} {
			regsub -all {^\s+} $data {} data
		}
		regsub -all {\s+$} $data {} data
		set data [escape_curlies $data]

		# Parse given data
		switch -- $xml_curTag {
			{authors} {
				append xml_data_authors		$data "\n"
			}
			{copyright} {
				set xml_data_copyright		$data
			}
			{license} {
				set xml_data_license		$data
			}
			{description} {
				append xml_data_description	$data "\n"
			}
			{todo} {
				append xml_data_todo		$data "\n"
			}
			{other_options} {
				append xml_data_other_options	$data "\n"
			}
			{compiler_options} {
				append xml_data_compiler_options $data "\n"
			}
			{bookmarks} {
				# Append an empty file path if the path was empty
				if {[llength $xml_data_file] == 9} {
					lappend xml_data_file {}
				}
				regsub -all {[ \t\n\r]+} $data { } data
				regsub {^ } $data { } data
				regsub { $} $data { } data
				lappend xml_data_file		$data
			}
			{breakpoints} {
				regsub -all {[ \t\n\r]+} $data { } data
				regsub {^ } $data { } data
				regsub { $} $data { } data
				lappend xml_data_file		$data
			}
			{path} {
				lappend xml_data_file		$data
			}
			{notes} {
				append xml_data_file_notes	$data "\n"
			}
		}
	}

	## XML parser handler - handles XML tags
	 # @parm String arg1	- name of the element
	 # @parm List arg2	- list of attributes '{attr0 val0 attr1 val1 ...}'
	 # @return void
	proc project_xml_parser_handler_element args {
		variable expect_data_part		;# Bool: True if on the next comes data
		variable xml_expect			;# XML tag expected to be the next
		variable xml_curTag			;# Currenly parsed XML tag
		variable xml_start			;# Bool: True at start of parsing
		variable xml_attlist			;# Auxiliary variable - List of current tag attributes
		variable xml_warning			;# Bool: True if an error occurred during parsing process

		variable xml_data_tk_mcuide_project	;# Attributes of <tk_mcuide_project>
		variable xml_data_authors		;# Content of <authors>
		variable xml_data_copyright		;# Content of <copyright>
		variable xml_data_license		;# Content of <license>
		variable xml_data_processor		;# Attributes of <processor>
		variable xml_data_options		;# Attributes of <options>
		variable xml_data_graph			;# Attributes of <graph>
		variable xml_data_description		;# Content of <description>
		variable xml_data_todo			;# Content of <todo>
		variable xml_data_calculator		;# Attributes of <calculator>
		variable xml_data_other_options		;# Content of <other_options>
		variable xml_data_compiler_options	;# Content of <compiler_options>
		variable xml_data_files			;# Contents of <file>
		variable xml_data_files_count		;# Number of files
		variable xml_data_file			;# Contents of <file>
		variable xml_data_file_notes		;# Contents of <notes>

		# Abort on error
		if {$xml_warning} {return}

		# Inicalize on parser start up
		if {$xml_start} {
			set xml_start 0
			set xml_expect "xml_data_tk_mcuide_project"
		}

		# At next expect data part
		set expect_data_part 1

		# Local variables
		set tag		[lindex $args 0]	;# Element name
		set xml_attlist	[lindex $args 1]	;# List of attributes

		# Parse attributes
		switch $tag {
			{tk_mcuide_project} {
				set xml_curTag "xml_data_tk_mcuide_project"
				set xml_data_tk_mcuide_project [project_xml_attr_parser	\
					"general" {version date creator_ver}		\
				]
			}
			{general} {
				set xml_curTag "general"
				project_xml_expect "authors"
			}
			{authors} {
				set xml_curTag "authors"
				project_xml_expect "copyright"
			}
			{copyright} {
				set xml_curTag "copyright"
				project_xml_expect "licence license"
			}
			{license} {
				set xml_curTag "license"
				project_xml_expect "processor"
			}
			{licence} {
				set xml_curTag "license"
				project_xml_expect "processor"
			}
			{processor} {
				set xml_curTag "processor"
				set xml_data_processor [project_xml_attr_parser	\
					"options" {type clock xdata xcode}	\
				]
			}
			{options} {
				set xml_curTag "options"
				set xml_data_options [project_xml_attr_parser	\
					"graph description" {
						watches_file scheme main_file auto_sw_enabled
					}	\
				]
			}
			{graph} {
				set xml_curTag "graph"
				set xml_data_graph [project_xml_attr_parser			\
					"description" {grid magnification enabled marks_s marks_l marks_o active_page}	\
				]
			}
			{description} {
				set xml_curTag "description"
				project_xml_expect "todo"
			}
			{todo} {
				set xml_curTag "todo"
				project_xml_expect "calculator"
			}
			{calculator} {
				set xml_curTag "calculator"
				set xml_data_calculator [project_xml_attr_parser	\
					"other_options" {
						radix angle_unit display0 display1
						display2 memory0 memory1 memory2
						freq time mode
					} \
				]
			}
			{other_options} {
				set xml_curTag "other_options"
				project_xml_expect "compiler_options files"
			}
			{compiler_options} {
				set xml_curTag "compiler_options"
				project_xml_expect "files"
			}
			{files} {
				set xml_curTag "files"
				set files_attrs [project_xml_attr_parser			\
					"file" {count current_file current_file2 pwin_sash
						pwin_orient selected_view}			\
				]
				set xml_data_files_count [list		\
					[lindex $files_attrs 0]		\
					[lrange $files_attrs 1 end]	\
				]
			}
			{file} {
				lappend__xml_data_files__xml_data_file	;# Note that this is important function

				set xml_curTag "file"
				set xml_data_file [project_xml_attr_parser			\
					"actual_line" {name active o_bookmark p_bookmark
						file_index read_only highlight}			\
				]
			}
			{actual_line} {
				set xml_curTag "actual_line"
				lappend xml_data_file [project_xml_attr_parser	\
					"md5_hash" {value}			\
				]
			}
			{md5_hash} {
				set xml_curTag "md5_hash"
				lappend xml_data_file [project_xml_attr_parser	\
					"path" {value}				\
				]
			}
			{path} {
				set xml_curTag "path"
				project_xml_expect "bookmarks"
			}
			{bookmarks} {
				set xml_curTag "bookmarks"
				project_xml_expect "breakpoints"
			}
			{breakpoints} {
				set xml_curTag "breakpoints"
				project_xml_expect "eol file"
			}
			{eol} {
				set xml_curTag "eol"
				lappend xml_data_file [project_xml_attr_parser	\
					"encoding" {value}			\
				]
			}
			{encoding} {
				set xml_curTag "encoding"
				lappend xml_data_file [project_xml_attr_parser	\
					"file notes" {value}			\
				]
			}
			{notes} {
				set xml_curTag "notes"
				project_xml_expect "file"
			}
		}
	}

	## This procedure is a product of bad software design
	 # Variable xml_data_file must be modified by this function when xml_data_file is complete.
	 # It's because of some changes in the project file format in recent versions of the IDE
	 #
	 # THIS MUST BE ALWAYS CALLED INSTEAD OF DOING THIS: "lappend xml_data_files $xml_data_file" !
	proc lappend__xml_data_files__xml_data_file {} {
		variable xml_data_files			;# Contents of <files>
		variable xml_data_file			;# Contents of <file>
		variable xml_data_file_notes		;# Contents of <notes>

		if {$xml_data_file == {}} {
			return
		}

		if {[llength $xml_data_file] == 12} {
			puts stderr [mc "Converting old project file to new version"]

			#                     eol enc
			lappend xml_data_file {}  {}
		}

		# Move attribute "highlight" from index 6 to 13
		set xml_data_file [linsert $xml_data_file 14 [lindex $xml_data_file 6]]
		set xml_data_file [lreplace $xml_data_file 6 6]

		# Append file notes
		lappend xml_data_file [unescape_tags $xml_data_file_notes]
		set xml_data_file_notes {}


		lappend xml_data_files $xml_data_file
	}
}

# >>> File inclusion guard
}
# <<< File inclusion guard

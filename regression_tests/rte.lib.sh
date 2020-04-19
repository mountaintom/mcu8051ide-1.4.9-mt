#! /bin/bash

############################################################################
#    Copyright (C) 2010 by Martin Osmera                                   #
#    martin.osmera@gmail.com                                               #
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
# This file servers as a small simple library implementing regression testing
# environment. It should be included in a bash script which runs the test. There
# are a few Bash function which can be redefined in the client script to alter
# behavior of the test environment. They are: rte_before_test, rte_after_test,
# rte_modify_output_files, rte_check_result. Function rte_perform_test must be
# redefined and this funtion defines how are the tests performed.
#
# See the README file provided along with this Bash script for details.
#
# Software requirements:
#	- Bash
#	- Gawk (recommended)
# --------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# SPECIAL VARIABLES, WHICH CAN BE REDEFINED IN CLIENT SCRIPTS
# ------------------------------------------------------------------------------

# Name of the tested subject
declare    RTE_TEST_NAME=$'\b'
# With of the terminal window (number of text columns)
declare    RTE_LINE_WIDTH=
# Allow blinking texts to be printed
declare -i RTE_ALLOW_BINKING_TEXT=0

# ------------------------------------------------------------------------------
# TEST FUNCTIONS TO BE USED IN CLIENT SCRIPTS
# ------------------------------------------------------------------------------

## Do something which has to be done prior to the test itself
 # @note This function can be redefined in the client code
 # @parm String - Name of the test case currently being evaluated
 # @return 0 == Success; 1 == failure
function rte_before_test() {
	_implicit_rte_function
	return 0
}

## Perform the test
 # @warning This function MUST BE REDEFINED in the client code
 # @parm String - Name of the test case currently being evaluated
 # @return 0 == Success; 1 == failure
function rte_perform_test() {
	_implicit_rte_function

	_last_error="ERROR: Function rte_perform_test was not redefined!"

	printf "ERROR: Function rte_perform_test was not redefined!\n"
	printf "       Read the README file for more information.\n"

	return 1
}

## Do something which has to be done after the test case had been done
 # @note This function can be redefined in the client code
 # @parm String - Name of the test case currently being evaluated
 # @return 0 == Success; 1 == failure
function rte_after_test() {
	_implicit_rte_function
	return 0
}

## Do something which has to be done with the test case output files, for
 #+ instance remove certain line from certain files
 # @note This function can be redefined in the client code
 # @parm String - Name of the test case currently being evaluated
 # @return 0 == Success; 1 == failure
function rte_modify_output_files() {
	# Local variables
	local filetype

	# Mention that this is an implicit function in the log
	_implicit_rte_function

	# Ensure that we are in the directory with the temporary output files
	cd "${_TEST_DIR}/results"

	# Apply AWK scripts to all of the result files, which has to be compared
	#+ with .exp files (expected results)
	for exp_file in "../testcases/${1}."*.exp; do
		# Abort if there are no .exp files
		if [ "$exp_file" == "../testcases/${1}.*.exp" ]; then
			break
		fi

		# Determinate file extension of the output file to modify
		filetype="$(basename "$exp_file")"
		filetype="${filetype%.exp}"
		filetype="${filetype#*.}"

		# Apply common AWK script
		if [ -e "../modify_output_file.${filetype}.awk" ]; then
			# Make backup copy first (add extension `.original')
			cp -vf "${1}.${filetype}" "${1}.${filetype}.original"

			# Apply the script
			printf "gawk -f \"../modify_output_file.${filetype}.awk\" \"${1}.${filetype}.original\" > \"${1}.${filetype}\"\n"
			gawk -f "../modify_output_file.${filetype}.awk" "${1}.${filetype}.original" > "${1}.${filetype}"
		else
			printf "WARNING: File not found: modify_output_file.${filetype}.awk\n"
		fi

		# Apply file type specific AWK script
		if [ -e "../testcases/${1}.${filetype}.awk" ]; then
			# Make backup copy first (add extension `.modified')
			cp -vf "${1}.${filetype}" "${1}.${filetype}.modified"

			# Apply the script
			printf "gawk -f \"../testcases/${1}.${filetype}.awk\" \"${1}.${filetype}.modified\" > \"${1}.${filetype}\""
			gawk -f "../testcases/${1}.${filetype}.awk" "${1}.${filetype}.modified" > "${1}.${filetype}"
		fi
	done
}

## Compare output files with expected results in order to determinate whether it
 #+ was success or failure
 # @note This function can be redefined in the client code
 # @parm String - Name of the test case currently being evaluated
 # @return 0 == Success; 1 == failure
function rte_check_result() {
	# Local variables
	local exit_status=0	# Exit status from the `diff' tool

	# Mention that this is an implicit function in the log
	_implicit_rte_function

	# Ensure that we are in the directory with the temporary output files
	cd "${_TEST_DIR}/results"

	# Compare expected results with outputs from the test
	for exp_file in "../testcases/${1}."*.exp; do

		# Check if there are any .exp files
		if [ "$exp_file" == "../testcases/${1}.*.exp" ]; then
			_last_error="No expected outputs (.exp files) to compare"
			return 1
		fi

		# Determinate name of the output file
		out_file="$(basename "$exp_file")"
		out_file="${out_file%.exp}"

		# Use `diff' to perform the file comparison
		printf "\ndiff \"${out_file}\" \"../testcases/${out_file}.exp\"\n"
		diff "${out_file}" "../testcases/${out_file}.exp" || exit_status=$?

		# In case of error, specify the short description of it
		if (( $exit_status )); then
			_last_error="\"results/${out_file}\" differs from \"testcases/${out_file}.exp\""
		fi
	done

	return $exit_status
}


# ==============================================================================
# ===== EVERYTHING BEYOND THIS LINE IS INTERNAL IMPLEMENTATION OF THE RTE ======
# ==============================================================================


# ------------------------------------------------------------------------------
# INTERNAL RTE CONSTANTS
# ------------------------------------------------------------------------------

# Version of this regression testing environment
readonly _RTE_VERSION="0.1"
# Directory with the client script using this code (rte.lib.sh)
readonly _TEST_DIR="$(cd "$(dirname $0)";pwd)"

## Terminal color codes
declare _NORMAL_COLOR='\033[m'
declare _NUMBER_COLOR='\033[1;33m'
declare _SUCCESS_COLOR='\033[1;32m'
declare _FAILURE_COLOR='\033[1;31m'
declare _EMPHASIS_COLOR='\033[1;34m'
declare _BLINKING_TEXT='\033[5m'
declare _BOLD_FONT='\033[1m'

# ------------------------------------------------------------------------------
# INTERNAL RTE VARIABLES
# ------------------------------------------------------------------------------

# Number testcases to process
declare -i _NUMBER_OF_TESTCASES=0
# Name of one speicific testcase to run, empty string means run all the test cases
declare _run_specific_testcase=""
# Last called RTE function, this can be useful when tracing the last error
declare _last_rte_function_called=""
# Short description of the last known cause of a test case failure
declare _last_error=""
# True width of the terminal window
declare -i _terminal_width=0

# ------------------------------------------------------------------------------
# INTERNAL RTE FUNTIONS -- These function should not be called outside this file
# ------------------------------------------------------------------------------

## Determinate current width of the terminal window
 # @note Updates _terminal_width variable
 # @return always 0
function determinate_terminal_width() {
	_terminal_width=$(( $(tput cols) - 1 )) 2> /dev/null
	if (( $_terminal_width == -1 )); then
		_terminal_width=80
	fi
}

## Print message to inform used about usage of an implicit RTE function
 # @return always 0
function _implicit_rte_function() {
	printf "    Note: this is RTE function was not redefined"
}

## Wrapper for client test function
 # Purpose of this wrapper is to easily track what RTE function is being called
 # @parm String - Name of the test case
 # @return Exit status
function _wrapper_rte() {
	# Local variables
	local exit_status	# Return value of the wrapped function

	# Set some global variables
	_last_error=""			# Short description of last known error
	_last_rte_function_called="$2"	# Name of the wrapped RTE function

	# Print trace
	printf "\n>>> %s [ENTER]\n" "$_last_rte_function_called"
	printf "    PWD == \"%s\"\n" "$PWD"
	printf "    \$1 == \"%s\"\n" "$1"

	# Call the wrapped function
	$_last_rte_function_called "$1"
	exit_status=$?

	# Print final trace and return
	printf "<<< %s [LEAVE]\n\n" "$_last_rte_function_called"
	return $exit_status
}

## Wrapper for function rte_before_test
 # @parm String - Name of the test case
 # @return Exit status
function _wrapper_rte_before_test() {
	_wrapper_rte "$1" 'rte_before_test'
	return $?
}

## Wrapper for function rte_perform_test
 # @parm String - Name of the test case
 # @return Exit status
function _wrapper_rte_perform_test() {
	_wrapper_rte "$1" 'rte_perform_test'
	return $?
}

## Wrapper for function rte_after_test
 # @parm String - Name of the test case
 # @return Exit status
function _wrapper_rte_after_test() {
	_wrapper_rte "$1" 'rte_after_test'
	return $?
}

## Wrapper for function rte_modify_output_files
 # @parm String - Name of the test case
 # @return Exit status
function _wrapper_rte_modify_output_files() {
	_wrapper_rte "$1" 'rte_modify_output_files'
	return $?
}

## Wrapper for function rte_check_result
 # @parm String - Name of the test case
 # @return Exit status
function _wrapper_rte_check_result() {
	_wrapper_rte "$1" 'rte_check_result'
	return $?
}

## Count number of files in test cases directory, which names ends with `.in'
 # @note
 # This function will terminate the script with exit status 2 if some of the
 # input files is found to unreadable.
 # @return always 0
function _determinate_no_of_testcases() {

	# If one specific test case was chosen to perform the test on then
	#+ set number of found test cases to 1 and return
	if [ ! -z "$_run_specific_testcase" ]; then
		_NUMBER_OF_TESTCASES=1
		return
	fi

	# Go to directory containing input files
	cd "${_TEST_DIR}/testcases"

	# Determinate total number of all available test cases
	for i in *.in; do
		# Check whether the .in file is readable
		if [ ! -r "$i" ]; then
			# Check whether the .in file even exists
			if [ ! -e "$i" ]; then
				_NUMBER_OF_TESTCASES=0
				break
			fi

			# Display error message and exit if some of the .in files is not readble
			printf "\n${_FAILURE_COLOR}FATAL ERROR:${_NORMAL_COLOR} Unable to read file: %s\n\n" "$i"
			exit 2
		fi

		# Increment counter of testcases
		_NUMBER_OF_TESTCASES+=1
	done
}


## Write header for test case log file
 # The header will contain test case name and current date and time
 # @return always 0
function _create_log_file() {
	printf "Starting testcase \"%s\"\n" "${1}"
	printf "Current date and time: %s\n" "$(date '+%c')"
}

## Print line of characters
 # @parm Char - Character, which the line will be made of
 # @return always 0
function _print_line() {
	determinate_terminal_width
	for((i=0; i<${RTE_LINE_WIDTH:-$_terminal_width}; i++)); do
		printf "%s" "$1"
	done
	printf "\n"
}

## Make backups for all output files in the results directory
 # @note Names of backup files ends with `~' (tilda) character
 # @warning This function changes working directory to the `results' directory
 # @return always 0
function _make_backup_files() {

	# Go to directory with output files (these files are only temporary)
	cd "${_TEST_DIR}/results"

	# Make backup copies
	for result_file in *[^~]; do
		if [ ! -e "$result_file" ]; then
			continue
		fi
		cp -f "${result_file}" "${result_file}~" &> /dev/null
	done
}

## Run regression test(s)
 #
 # @warning
 # This function must be run as the last thing in the script, because it will end
 # the script with `exit' command. The exit status depends on actual results of
 # the test, status 0 means that all test cases passed and 1 means that at least
 # of them failed.
 #
 # @return always 0
function _runtest() {

	# Print PROLOG (some introductory information)
	_print_line '='
	printf "${_BOLD_FONT}Starting %s regression testing ... " "$RTE_TEST_NAME"
	printf "${_NUMBER_COLOR}%d${_NORMAL_COLOR} testcases to go\n" $_NUMBER_OF_TESTCASES
	_print_line '='

	# Abort, with exit status 2, if there are no testcases to perform
	if (( ! $_NUMBER_OF_TESTCASES )); then
		printf "\n${_FAILURE_COLOR}NO TESTCASES FOUND!${_NORMAL_COLOR}\n\n"
		exit 2
	fi

	# Make backups for all output files
	_make_backup_files

	# Move to the directory with input files
	cd "${_TEST_DIR}/testcases"

	# Decalare local variables
	declare -i failed_tescases=0		# Number of failed test cases
	declare -i successfull_tescases=0	# Number of successful test cases
	declare -i testcase_number=0		# Number of current test case (starts from 1)
	declare -i succussfull_so_far=1		# Status of the current test: 0 == Already failed; 1 == Ok so far

	# Iterate over available input files (.in) and run test for each of them,
	#+ unless there has been specified one particular test case to run
	for testcase in *.in; do
		# Set some local variables
		succussfull_so_far=1		# Status of the current test <-- Ok
		testcase="${testcase%.in}"	# Name of the current test case

		# In case the user want to run any one specific test case, skip
		#+ all others
		if [[ ! -z "$_run_specific_testcase" && "${_run_specific_testcase}" != "${testcase}" ]]; then
			continue
		fi

		# Increment test case counter
		testcase_number+=1

		# Print test case name
		printf "Testcase: \"${_EMPHASIS_COLOR}%s${_NORMAL_COLOR}\"" "$testcase"
		determinate_terminal_width
		for((i=11 + ${#testcase} + 16; i<${RTE_LINE_WIDTH:-$_terminal_width}; i++)); do
			printf " "
		done

		# Print text [IN PROGRESS] next to the test case name
		if (( $RTE_ALLOW_BINKING_TEXT )); then
			printf "  ${_BLINKING_TEXT}[IN PROGRESS]${_NORMAL_COLOR}"
		else
			printf "  ${_NUMBER_COLOR}[IN PROGRESS]${_NORMAL_COLOR}"
		fi

		# Go to directory with output files (these files are only temporary)
		cd "${_TEST_DIR}/results"

		# --------------------------------------------------------------
		# Run the test
		# --------------------------------------------------------------
		while true; do
			# Create header for the log file
			_create_log_file "$testcase" &> "${testcase}.log" || {
				succussfull_so_far=0
				break
			}

			# Run client testing function -- rte_before_test
			# Purpose: Do something which has to be done prior to
			#          the test itself.
			_wrapper_rte_before_test "$testcase" &>> "${testcase}.log" || {
				succussfull_so_far=0
				break
			}

			# Run client testing function -- rte_perform_test
			# Purpose: Perform the test
			_wrapper_rte_perform_test "$testcase" &>> "${testcase}.log" || {
				succussfull_so_far=0
				break
			}

			# Run client testing function -- rte_after_test
			# Purpose: Do something which has to be done after
			#          the testcase had been done
			_wrapper_rte_after_test "$testcase" &>> "${testcase}.log" || {
				succussfull_so_far=0
				break
			}

			# Run client testing function -- rte_modify_output_files
			# Purpose: Do something which has to be done with the test case
			#          output files, for instance remove certain line from
			#          certain files
			_wrapper_rte_modify_output_files "$testcase" &>> "${testcase}.log" || {
				succussfull_so_far=0
				break
			}

			# Run client testing function -- rte_check_result
			# Purpose: Compare output files with expected results in
			#          order to determinate whether it was success or
			#          failure
			_wrapper_rte_check_result "$testcase" &>> "${testcase}.log" || {
				succussfull_so_far=0
				break
			}

			# If we reached this line, that means that the test case was successful
			break
		done

		# Go back to directory with input files (these files are permanent)
		cd "${_TEST_DIR}/testcases"

		# Erase 15 characters from right, remove the text "[IN PROGRESS]"
		for((i=0; i<15; i++)); do
			printf "\b"
		done

		# Print test case status, that is "[OK]" or "[FAILED]"
		#+ and increment counter successful or failed test cases
		if (( $succussfull_so_far ))
		then
			# Testcase was successfull
			successfull_tescases+=1
			printf "${_SUCCESS_COLOR}           [OK]${_NORMAL_COLOR}\n"
		else
			# Testcase was unsuccessfull
			failed_tescases+=1
			printf "${_FAILURE_COLOR}       [FAILED]${_NORMAL_COLOR}\n"

			# Print some more information about the failure ...
			if [ ! -z "$_last_error" ]; then
				printf "\tLast known error: %s\n" "$_last_error"
			fi
			printf "\tTestcase failed during execution of: ${_BOLD_FONT}%s${_NORMAL_COLOR}\n" "$_last_rte_function_called"
			printf "\tLog saved in: ${_TEST_DIR}/results/${testcase}.log\n\n"
		fi
	done

	# Print EPILOG (some information at the end)
	_print_line '-'
	printf "Statistic:\n"
	printf "\tTOTAL:      ${_NUMBER_COLOR}%3d${_NORMAL_COLOR}\n" $testcase_number
	printf "\tSUCCESSFUL: ${_SUCCESS_COLOR}%3d${_NORMAL_COLOR}\n" $successfull_tescases
	printf "\tFAILED:     ${_FAILURE_COLOR}%3d${_NORMAL_COLOR}\n" $failed_tescases
	_print_line '='

	# Exit script accordingly to the results
	if (( $failed_tescases )); then
		exit 1
	else
		exit 0
	fi
}

## Print name of this environment
 # @return always 0
function _print_rte_name() {
	printf "Regression testing environment v%s\n" "$_RTE_VERSION"
}

## Print help message
 # @parm Bool - Disable color output
 # @return always 0
function _print_help() {
	if (( ! ${1:-0} )); then
		local tc_end="\033[m"
		local tc_bld="\033[1m"
		local tc_opt="\033[32m"
		local tc_arg="\033[33;1m"
		local tc_dot="\033[32;1m"
	fi

	printf "${tc_bld}"
	_print_rte_name
	printf "${tc_end}"

	printf "\n"
	printf "${tc_bld}Options:${tc_end}\n"
	printf "\t${tc_opt}-t${tc_end} ${tc_arg}testcase${tc_end}\tRun specific test case\n"
	printf "\t${tc_opt}-V${tc_end}\t\tPrint version information\n"
	printf "\t${tc_opt}-n${tc_end}\t\tDisable color output\n"
	printf "\t${tc_opt}-h${tc_end}\t\tShow this message\n"
	printf "\n"
	printf " ${tc_dot}*${tc_end} See README files in directories containing regression tests for more information.\n"
	printf " ${tc_dot}*${tc_end} When run without any options it will run all found test cases.\n"
	printf "\n"
}

## Parse command line options
 # @parm List - command line arguments ("$@")
 # @return always 0
function _parse_cmd_line_opts() {
	local -i print_help=0
	local -i no_color=0

	# Parse CLI options using `getopts' utility
	while getopts ":hVnt:" opt; do
		case $opt in
			n)	# Disable color output
				no_color=1
				unset _NORMAL_COLOR
				unset _NUMBER_COLOR
				unset _SUCCESS_COLOR
				unset _FAILURE_COLOR
				unset _EMPHASIS_COLOR
				unset _BLINKING_TEXT
				unset _BOLD_FONT
				;;
			t)	# Specify one test case to run
				_run_specific_testcase="$(basename "$OPTARG")"
				;;
			h)	# Help
				print_help=1
				;;

			V)	# Print version information
				_print_rte_name
				exit
				;;
			?)	# ERROR
				_print_rte_name
				printf "Unknown option. Try -h to get help.\n"
				exit 1
				;;
		esac
	done

	if (( print_help )); then
		_print_help $no_color
		exit
	fi
}

## Main loop
 # @parm List - command line arguments ("$@")
 # @return always 0
function _main() {

	# Display error message and exit of this script was run
	#+ alone and not included into some another file
	if [ "$(basename $0)" == "rte.lib.sh" ]; then
		printf "${_FAILURE_COLOR}ERROR:${_NORMAL_COLOR} This file serves merely as a library for regression testing.\n"
		printf "       It does not make sense to run it alone.\n"
		exit 2
	fi

	# Parse command line options
	_parse_cmd_line_opts "$@"

	# Determinate number of test cases to proceed (count .in files in test cases directory)
	_determinate_no_of_testcases

	# Run regression test(s)
	_runtest
}

## Run tests at the end of script execution
trap '_main "$@"' 0


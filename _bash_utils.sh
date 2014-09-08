#!/bin/bash


#
# Prints the given command, then executes it
#  Example: print_and_do_command echo 'hi'
#
function print_and_do_command {
	echo " -> $ $@"
	$@
}

#
# Print the given command, execute it
#	and exit if error happened
function print_and_do_command_exit_on_error {
	print_and_do_command $@
	if [ $? -ne 0 ]; then
		echo " [!] Failed!"
		exit 1
	fi
}

#
# Bitrise - Formatted Output

formatted_output_file_path="$BITRISE_STEP_FORMATTED_OUTPUT_FILE_PATH"

function echo_string_to_formatted_output {
  echo "$1" >> $formatted_output_file_path
}

function write_section_to_formatted_output {
  echo '' >> $formatted_output_file_path
  echo "$1" >> $formatted_output_file_path
  echo '' >> $formatted_output_file_path
}

##
## Check the last command's result code and if it's not zero
##	then print the given error message and exit with the command's exit code
##
#function fail_if_cmd_error {
#	local last_cmd_result=$?
#	local error_msg="$1"
#	if [ $last_cmd_result -ne 0 ]; then
#		echo " [!] ${error_msg}"
#		exit $last_cmd_result
#	fi
#}
#


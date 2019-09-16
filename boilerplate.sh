#!/usr/bin/env bash

#
# script inventory stuff
#

# shellcheck disable=SC2034
{
	declare -r script_version='0.0.0 b0'
	declare -r script_description='[placeholder]'
	declare -r script_usage=''
	declare -r script_name="${BASH_SOURCE[0]}"

	# must be empty in the release
	# must be placed BEFORE the sourcing library
	declare -r DEBUG=
}

# use library. must be placed at the very begining but after DEBUG.
for library_path in '.' "$( dirname "$script_name" )" '/home/user/bin'; do [[ -f "$library_path/functions.sh" ]] && { source "$library_path/functions.sh"; break; }; done
[[ -n "$script_author" ]] || { printf 'ERROR: Library functions.sh not found. Exiting...\n'; exit 1; }


#
# Functions
#

boilerplate() {
	#
	# Usage: 
	#
	arguments: $# none

	# args
	# consts
	# vars
	# code
}


#
# main()
#

# args
# consts
# vars
# code

print_script_version

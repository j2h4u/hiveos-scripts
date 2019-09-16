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
[[ -n "$script_author" ]] || { printf 'ERROR: Library not found. Exiting...\n'; exit 1; }


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

pad_by_nesting_level() {
	#
	# Usage: 
	#
	arguments: $# exactly 1

	local -r -i nesting_level="$1"
	local -r -i multiplicator=2
	local -r -i pad_count=$(( nesting_level * multiplicator ))

	(( nesting_level > 0 )) && printf '%*.*s' "$pad_count" "$pad_count" ' '
}

print_json_array() {
	#
	# Usage: 
	#
	arguments: $# range 1 3

	# args

	local -r array_name="$1"
	local -r key_path="${2-}"
	local -i nesting_level="${3-0}"

	# consts

	local -r -n array="$array_name"

	# vars

	local current_key=''
	local variable=''
	local key=''

	# code

	if is_variable_empty "$key_path"; then
		current_key=""
	else
		current_key="${key_path}"
	fi

	for variable in ${array[${current_key}.meta:variables]-}; do
		if (( nesting_level )); then
			pad_by_nesting_level "$nesting_level"
			printf "%b%s='%s'%b\n" "${CYAN}" "$variable" "${array[${current_key}:${variable}]}" "${NOCOLOR}"
		else
			printf "%b%s='%s'%b\n" "${CYAN}" "$variable" "${array[${current_key}${variable}]}" "${NOCOLOR}"
		fi
	done


	for key in ${array[${key_path}.meta:keys]-}; do
		pad_by_nesting_level "$nesting_level"
		printf '%s\n' "$key:"

		if is_variable_empty "$key_path"; then
			current_key="${key}"
		else
			current_key="${key_path}.${key}"
		fi

		if [[ -n "${array[${current_key}.meta:keys]-}" ]]; then
			print_json_array "$array_name" "$current_key" "$(( nesting_level + 1 ))"
		fi
	done 
}

#
# main()
#

# args
# consts
# vars

json_file="${1-oc_example.json}"
json_string="$( < "$json_file" )"
declare -A jsOn=()

# code

print_script_version
json::transform_json_to_hash "$json_string" 'jsOn'
#print_array 'jsOn'
print_json_array 'jsOn'

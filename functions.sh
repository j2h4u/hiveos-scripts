#!/usr/bin/env bash

#
# strict mode, no unbound variables
#

set -o nounset


#
# interactive console? yes colors yes
#

[ -t 1 ] && source colors


#
# common variables
#

# shellcheck disable=SC2155
declare -r script_basename="$(basename "$0")"
# shellcheck disable=SC2034
declare -r script_log="$0.log"
declare -r script_runtime_log="$0.runtime.log"
declare -r script_author='https://github.com/j2h4u'


#
# functions
#


#
# Error handling
#

log_stderr_to_file() {
	# log all stderr to file
	# shellcheck disable=SC2119
	exec 2> >( tee >(strip_ansi >> "$script_runtime_log") )
}

errcho() {
	echo "$@"
	#printf '%s\n' "$*"
} 1>&2

errprintf() {
	# shellcheck disable=SC2059
	printf "$@"
} 1>&2

__debug_message_factory() {
	#
	# A little message factory
	# Usage: _debug_message "severity" "message"..
	#
	local -r severity="${1-undefined}"
	local -r message="${2-undefined}"

	printf "${BRED-}%s:${NOCOLOR-} %s" "$severity" "$message"
	if [[ "$#" -gt 2 ]]; then
		# print all other arguments with quotes
		printf '\n       Arguments:'
		printf " '%s'" "${@:3}"
	fi
	echo
} 1>&2

_error_message() {
	local -i frame='0'

	__debug_message_factory 'ERROR' "$@"

	{
		echo -e -n "${DGRAY-}"
		while (echo -e -n "       "; caller "$frame"); do
			(( frame++ ));
		done
		echo -e -n "${NOCOLOR-}=== "
		date
		echo
	} 1>&2
}

#_err() {
#	# wrapper while deprecating old non-modular _err
#	_error_message "$@"
#}

_warning_message() {
	__debug_message_factory 'WARNING' "$@"
}

_info_message() {
	__debug_message_factory 'INFO' "$@"
}

_die() {
	_error_message "$@"
	sleep 1
	kill -s TERM "$TOP_PID"
	sleep 1
	_error_message "You shall not see that!"
}


#
# Arguments checking
#

is_number_in_range() {
	#
	# Usage: is_number_in_range 'number_to_check' 'lower_limit' 'upper_limit'
	#
	(( $# != 3 )) && _die "Expected 3 arguments, got $#."

	# args

	local -r -i number_to_check="$1"
	local -r -i lower_limit="$2"
	local -r -i upper_limit="$3"

	# code

	(( (number_to_check >= lower_limit) && (number_to_check <= upper_limit) ))
}

print_arguments() {
	local -r -i number_of_arguments="$#"
	local -r -a callee_array=( $(caller 1) )
	local -r callee_name="${callee_array[1]}"

	local -a arguments_array=()
	local -i iterator=''

	_info_message "$callee_name(), $number_of_arguments arguments" "$@"

	# this should be deprecated in favor of simple _info_message()
	case "$number_of_arguments" in
		0)
			:
			;;
		*)
			arguments_array=( "$@" )
			printf ':'
			for ((iterator=0; iterator < number_of_arguments; iterator++)) {
				printf " [%u]='%s'" "$((iterator+1))" "${arguments_array[$iterator]}"
			}
			printf '\n'
			;;
	esac
}

arguments:() {
	#
	# Usage: arguments: <arguments_count> <operator_or_condition> [<control_value> [<control_value>]]
	#
	# Arguments count checker
	#
	# stdin: none
	# stdout: none
	# exit code: none
	#
	is_number_in_range $# 2 4 || _die "Expected 2-4 arguments, got $#." # hard-coded because ain't no sense to call itself

	# args

	local -r -i arguments_count="$1"
	local -r operator_or_condition="$2"

	# consts

	local -r callee_name="${FUNCNAME[1]}"

	# vars

	local -i control_value=0
	local -i lower_limit=0
	local -i upper_limit=0

	# flags

	local -i arguments_count_ok="$boolean_c_true"

	# code

	case "$operator_or_condition" in
		'any')
			# 0 to infinity
			return
			;;
		'none')
			# 0
			arguments_count_ok=$(( arguments_count == 0 ))
			;;
		'exactly')
			control_value="$3"
			arguments_count_ok=$(( arguments_count == control_value ))
			;;
		'atleast')
			# x to infinity
			control_value="$3"
			arguments_count_ok=$(( arguments_count >= control_value ))
			;;
		'range')
			# from x to y
			lower_limit="$3"
			upper_limit="$4"
			arguments_count_ok=$(( (arguments_count >= lower_limit) && (arguments_count <= upper_limit) ))
			;;
		*)
			_die "Unknown operator." "$@"
#			# use test expr, deprecated
#			control_value="$3"
#			[ "$arguments_count" "$operator_or_condition" "$control_value" ] && arguments_count_ok="$boolean_c_true" || arguments_count_ok="$boolean_c_false"
			;;
	esac

	if ! (( arguments_count_ok )); then
		_die "Function $callee_name() expected '${*:2}' arguments, got $arguments_count."
	fi
}


#
# boolean:: constants + functions: bash2c, c2bash, string2c, c2string, grab_exit_code_to_c_boolean
#

# consts

declare -r -i boolean_c_true=1
declare -r -i boolean_c_false=0

declare -r -i boolean_bash_true=0
declare -r -i boolean_bash_false=1
#declare -r -i boolean_true=0 # deprecated
#declare -r -i boolean_false=1 # deprecated

declare -r boolean_string_true='true'
declare -r boolean_string_false='false'

# functions

boolean::bash2c() {
	#
	# Convert bash boolean (0=true !0=false) to С boolean (!0=true 0=false).
	#
	# Usage: boolean::bash2c 'bash_boolean' -> 'c_boolean'
	#
	arguments: $# exactly 1

	# consts

	local -r -i boolean_bash="$1"

	# vars

	local -i boolean_c

	# code

	# convert value to exit code
	if ( return "$boolean_bash" ); then
		boolean_c="$boolean_c_true"
	else
		boolean_c="$boolean_c_false"
	fi

	printf '%u\n' "$boolean_c"
}

boolean::c2bash() {
	#
	# Convert С boolean (!0=true 0=false) to bash boolean (0=true !0=false).
	#
	# Usage: boolean::c2bash 'c_boolean' -> 'bash_boolean'
	#
	arguments: $# exactly 1

	# consts

	local -r -i boolean_c="$1"

	# vars

	local -i boolean_bash

	# code

	if (( boolean_c )); then
		boolean_bash="$boolean_bash_true"
	else
		boolean_bash="$boolean_bash_false"
	fi

	printf '%u\n' "$boolean_bash"
}

### need to think out
# get_flag bash|math|string var_by_ref

boolean::string2c() {
	#
	# Convert String boolean ('true'=true 'false'=false) to C boolean (!0=true 0=false).
	#
	# Usage: boolean::string2c 'boolean_string' -> 'boolean_c'
	#
	arguments: $# exactly 1

	# consts

	local -r boolean_string="$1"

	# vars

	local -i boolean_c

	# code

	case "$boolean_string" in
		"$boolean_string_true")
			boolean_c="$boolean_c_true"
			;;
		"$boolean_string_false")
			boolean_c="$boolean_c_false"
			;;
		*)
			_die "Must be '$boolean_string_true' or '$boolean_string_false'." "$@"
			;;
	esac

	printf '%u\n' "$boolean_c"
}

boolean::c2string() {
	#
	# Convert String boolean ('true'=true 'false'=false) to C boolean (!0=true 0=false).
	#
	# Usage: boolean::string2c 'boolean_string' -> 'boolean_c'
	#
	arguments: $# exactly 1

	# consts

	local -r -i boolean_c="$1"

	# vars

	local boolean_string=''

	# code

	case "$boolean_c" in
		"$boolean_c_true")
			boolean_string="$boolean_string_true"
			;;
		"$boolean_c_false")
			boolean_string="$boolean_string_false"
			;;
		*)
			_die "Must be '$boolean_c_true' or '$boolean_c_false'." "$@"
			;;
	esac

	printf '%s\n' "$boolean_string"
}

grab_exit_code_to_c_boolean() { local -r -i exit_code="$?" # must be the first command in the function to appropriately catch the exit code
	#
	# Grab exit code of previous command to array passed by reference. [0] will be С boolean, [1] will be original exit code.
	#
	# Usage: grab_exit_code_to_c_boolean 'array_by_ref' -> array_by_ref[0]=c_boolean, array_by_ref[1]=exit_code
	#
	arguments: $# exactly 1

	# consts

	local -r -n variable_by_ref="$1"

	# code

	variable_by_ref="$( boolean::bash2c "$exit_code" )"
	variable_by_ref[1]="$exit_code" # hide original exit code to index 1

	return "$exit_code" # pass the exit code (let's be completely transparent in pipes)
}


#
# IS's and ISN'T's
#

is_function_exist() {
	#
	# Usage: is_function_exist 'function_name'
	#
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# exactly 1

	# consts

	local -r function_name="$1"

	# code

	declare -F -- "$function_name" >/dev/null
}

is_function_not_exist() {
	#
	# Usage: is_function_not_exist 'function_name'
	#
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# exactly 1

	# consts

	local -r function_name="$1"

	# code

	! is_function_exist "$function_name"
}

is_directory_exist() {
	#
	# directory_exist <an entity to check>
	#
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# exactly 1

	[ -d "$1" ]
}

is_directory_not_exist() {
	#
	# directory_not_exist <an entity to check>
	#
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# exactly 1

	! directory_exist "$1"
}

is_file_exist() { # 'file_name(s)'
	#
	# Usage: is_file_exist 'file_name(s)'
	# (tilde, wildcards, and double-quotes well handled)
	#
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# atleast 1

	local -r files="${*/#\~/$HOME}" # expand tilde, if that's a first char in the string

	compgen -G "$files" > /dev/null # nice solution from stackoverflow
}

is_file_exist_deprecated() {
	## !!! deprecated !!! use file_exist()
	[ -f "${1-}" ]
}

is_file_not_exist() { # 'file_name(s)'
	#
	# is_file_not_exist 'file_name'
	# (tilde, wildcards, and double-quotes well handled)
	#
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# atleast 1

	! is_file_exist "$@"
}

is_variable_set() { # 'variable_name_'
	# stdin: none
	# stdout: none
	# exit code: boolean
	arguments: $# exactly 1

	local -n variable_by_reference="$1"
	[[ "${variable_by_reference+is_set}" ]]
}

is_variable_empty() {
	#
	# Usage: is_variable_empty <an entity to check>
	#
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# exactly 1 ###-le 1

	[[ -z "${1-}" ]]
}

is_variable_not_empty() {
	#
	# is_variable_not_empty <an entity to check>
	#
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# exactly 1 ###-le 1

	[[ -n "${1-}" ]]
}


#
# Debugging related
#

is_debug() {
	#
	# is_debug
	#
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# none

	is_variable_not_empty "${DEBUG-}"
}

is_not_debug() {
	#
	# is_not_debug
	#
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# none

	! is_debug
}

if_debug:() {
	#
	# run code only if debug is set
	# and redirect its output to stderr
	#
	arguments: $# any

	if is_debug; then
		:
		"$@"
		:
	fi
} 1>&2

if_not_debug:() {
	#
	# run code only if debug is not set
	#
	arguments: $# any

	if is_not_debug; then
		:
		"$@"
		:
	fi
}


#
# Date & time
#

time::get_date_with_format() {
	#
	# Usage: time::get_date_with_format ['date_in_seconds' ['date_format']]
	#
	# See: 'man strftime' for format.
	# from https://github.com/dylanaraps/pure-bash-bible#get-the-current-date-using-strftime
	#
	arguments: $# range 0 2 ###-le 2

	# args

	local -r -i date_in_seconds_DEFAULT=-1 # default is current date/time
	local -r date_format_DEFAULT='%F %T' # '%c'

	local -r -i date_in_seconds="${1-${date_in_seconds_DEFAULT}}"
	local -r date_format="${2-${date_format_DEFAULT}}"

	# code

	printf "%($date_format)T\\n" "$date_in_seconds"
}

time::get_current_date_with_format() {
	#
	# Usage: time::get_current_date_with_format ['date_format']
	#
	# See: 'man strftime' for format.
	# from https://github.com/dylanaraps/pure-bash-bible#get-the-current-date-using-strftime
	#
	arguments: $# range 0 1 ###-le 1

	# args

	local -r date_format_DEFAULT='%c'
	local -r date_format="${1-${date_format_DEFAULT}}"

	# code

	time::get_date_with_format '-1' "$date_format"
}

time::seconds2dhms() {
	#
	# Usage: time::seconds2dhms 'time_in_seconds' ['delimiter']
	#
	# Renders time_in_seconds to 'XXd XXh XXm XXs' string
	# Default delimiter = ' '
	#
	arguments: $# range 1 2 ###-ge 1

	# args

	local -i -r time_in_seconds="${1#-}" # strip sign, get ABS
	local -r delimiter_DEFAULT=' '
	local -r delimiter="${2-${delimiter_DEFAULT}}"

	# consts

	local -i -r days="$(( time_in_seconds / 60 / 60 / 24 ))"
	local -i -r hours="$(( time_in_seconds / 60 / 60 % 24 ))"
	local -i -r minutes="$(( time_in_seconds / 60 % 60 ))"
	local -i -r seconds="$(( time_in_seconds % 60 ))"

	# code

	(( days > 0 )) && printf '%ud%s' "$days" "$delimiter"
	(( hours > 0 )) && printf '%uh%s' "$hours" "$delimiter"
	(( minutes > 0 )) && printf '%um%s' "$minutes" "$delimiter"

	printf '%us' "$seconds" # maybe no seconds if days > 0?
	printf '\n'
}

time::get_current_date_in_seconds() {
	#
	# Usage: time::get_current_date_in_seconds
	#

	# consts

	local -r date_format='%s'

	# code

	time::get_current_date_with_format "$date_format"
}

time::get_file_date_in_seconds() {
	#
	# Usage: time::get_file_date_in_seconds 'file_name'
	#
	arguments: $# exactly 1

	# args

	local -r file="$1"

	# consts

	local -r date_format='+%s' # '+%s%N': in nanoseconds

	# code

	date "$date_format" --reference "$file"
}

time::seconds2iso() {
	#
	# Usage: seconds2iso ['time_in_seconds']
	#
	# Default is current date/time
	#
	arguments: $# range 0 1 ###-le 1

	# args

	local -r -i time_in_seconds_DEFAULT=-1
	local -r -i time_in_seconds="${1-${time_in_seconds_DEFAULT}}"

	# consts

	local -r date_format='%Y%m%d-%H%M%S'

	# code

	time::get_date_with_format "$time_in_seconds" "$date_format"
}


#
# Strings
#
# strip_ansi()
# trim_string()
# trim_text()
# split_string_to_array_by_delimiter()
# get_field_from_string_by_delimiter()
# string::get_index_of_substring()
#

# shellcheck disable=SC2120
strip_ansi() {
	#
	# Strips ANSI codes from text
	# < or $1: The text
	# >: The ANSI stripped text
	#
	arguments: $# range 0 1 ###-le 1

	local -r input_text="${1:-$(</dev/stdin)}" # get from arg or stdin

	local line=''
	while IFS='' read -r line || [[ -n "$line" ]]; do
		(
			shopt -s extglob
			printf '%s\n' "${line//$'\e'[\[(]*([0-9;])[@-n]/}"
		)
	done <<< "$input_text"
}

trim_string() {
	#
	# Usage: trim_string "   example   string    "
	# https://github.com/dylanaraps/pure-bash-bible#trim-leading-and-trailing-white-space-from-string
	#
	arguments: $# exactly 1

	# The : built-in is used in place of a temporary variable.
	: "${1#"${1%%[![:space:]]*}"}"
	: "${_%"${_##*[![:space:]]}"}"
	printf '%s\n' "$_"
}

trim_text() {
	#
	# Trim leading and trailing whitespaces from text
	# stdin or $1: The text
	# stdout: The trimmed text
	#
	arguments: $# range 0 1 ###-le 1

	local line=''

	while IFS='' read -r line || [[ -n "$line" ]]; do
		trim_string "$line" # wow so good so simple
	done < "${1:-/dev/stdin}"
}

split_string_to_array_by_delimiter() {
	#
	# Usage: split_string_to_array_by_delimiter 'string_to_split' 'array_by_ref' ['delimiter_string']
	#
	# It's like JavaScript split()
	#
	# If delimiter_string is NOT SET, split by ' '
	# If delimiter_string is SET to '', split by every char
	#
	arguments: $# range 2 3

	# args

	local -r string_to_split="$1"
	local -r -n array_by_ref="$2"
	local -r delimiter_string_DEFAULT=' '
	local -r delimiter_string="${3-${delimiter_string_DEFAULT}}" # use default only if unset because null delimiter is the special situation to invoke splitting by every char

	# code

	# choose algo by delimiter length
	case "${#delimiter_string}" in
		0)
			# empty delimiter, split by every char
			array_by_ref=() # reset the array, just to be safe
			for (( position=0; position < ${#string_to_split}; position++ )); do
				array_by_ref+=( "${string_to_split:position:1}" )
			done
			;;
		1)
			# 1-character delimiter, FASTER splitting
			IFS="$delimiter_string"
				array_by_ref=( $string_to_split )
			unset IFS
			;;
		*)
			# string delimiter, SLOWER splitting
			IFS=$'\n' read -d '' -ra array_by_ref <<< "${string_to_split//$delimiter_string/$'\n'}"
			;;
	esac
}

get_field_from_string_by_delimiter() {
	#
	# Usage: get_field_from_string_by_delimiter 'field_number' 'string_to_split' ['delimiter_string']
	#
	# Splits a string on a delimiter and print n-th field (1-based).
	#
	# If 'field_number' = 0, default to print every field with a newline
	# If 'delimiter_string' omitted, default to use whitespace
	# If 'field_number' not found in the string_to_split (greater than fields_count), print '' and set exit code to 1
	#
	# based on https://github.com/dylanaraps/pure-bash-bible#split-a-string-on-a-delimiter
	#
	arguments: $# range 2 3 ###-ge 2

	# args

	local -r -i field_number_DEFAULT=0
	local -r -i field_number="${1:-${field_number_DEFAULT}}" # no sanity check like is_integer. leave it to bash.
	local -r string_to_split="$2"
	local -r delimiter_string_DEFAULT='[[:space:]]'
	local -r delimiter_string="${3:-${delimiter_string_DEFAULT}}" # null ':' or unset '-'

	# vars

	local -a string_splitted_to_array=()
	local -i fields_count=0
	local -i index=0

	# code

	IFS=$'\n' read -d '' -ra string_splitted_to_array <<< "${string_to_split//$delimiter_string/$'\n'}"
	fields_count="${#string_splitted_to_array[@]}"

	index=$(( field_number - 1 )) # indices are 0-based, fields are 1-based

	if (( field_number == 0 )); then
		printf '%s\n' "${string_splitted_to_array[@]}"
	elif (( field_number <= fields_count )); then
		printf '%s\n' "${string_splitted_to_array[$index]}"
	else
		# field not found
		printf '%s\n' ''
		return "$boolean_bash_false"
	fi
}

string::get_index_of_substring() {
	#
	# Usage: string::get_index_of_substring 'string_to_search' 'substring'
	#
	# Return 0-based index of the first substring in string or -1 if not found
	#
	arguments: $# exactly 2

	# args

	local -r string_to_inspect="$1"
	local -r substring="$2"

	# consts

	local -r -i index_DEFAULT=-1

	# vars

	local part_before_substring=''
	local -i index="$index_DEFAULT"

	# code

	part_before_substring="${string_to_inspect%%${substring}*}"

	if [[ "$part_before_substring" != "$string_to_inspect" ]]; then
		index="${#part_before_substring}"
	fi

	printf '%d\n' "$index"
}


#
# Arrays and lists
#

is_item_in_list() {
	#
	# Usage: is_item_in_list 'item_to_check' 'list_item' ['list_item'...]
	#
	arguments: $# atleast 2

	# code

	# yep we need literal match, literally:
	# shellcheck disable=SC2076
	[[ " ${@:2} " =~ " $1 " ]]
}

get_variable_type() {
	arguments: $# exactly 1

	# consts

	local -r declare_reference_RE='^declare -n [^=]+=\"([^\"]+)\"$'

	# vars

	local declare_output=''
	local variable_type=''
	#local read_only=''

	# code

	# $1 does exist?
	if declare_output="$( declare -p "$1" 2>/dev/null )"; then
		# yes.
		# try to dereference it down the very bottom
		while [[ $declare_output =~ $declare_reference_RE ]]; do
			declare_output="$( declare -p "${BASH_REMATCH[1]}" 2>/dev/null )"
		done

		variable_type="${declare_output:9:1}"
		#read_only="${declare_output:10:1}"
		#errcho "VARTYPE: [$variable_type], ${declare_output#declare -??}"
	fi

	case "$variable_type" in
		'')
			: "UNDEFINED"
			;;
		'-')
			: "STRING"
			;;
		'a')
			: "ARRAY"
			;;
		'A')
			: "HASH"
			;;
		'i')
			: "INTEGER"
			;;
		'x')
			: "EXPORT"
			;;
		'*')
			: "OTHER"
			;;
	esac

	printf '%s\n' "$_"
}

is_hash_array() {
	#
	# Usage: is_hash_array 'variable_name'
	#
	arguments: $# exactly 1

	local -r variable_name="$1"
	local -r variable_type="$( get_variable_type "$variable_name" )"

	[[ $variable_type == 'HASH' ]]
}

is_indexed_array() {
	#
	# Usage: is_indexed_array 'variable_name'
	#
	arguments: $# exactly 1

	local -r variable_name="$1"
	local -r variable_type="$( get_variable_type "$variable_name" )"

	[[ $variable_type == 'ARRAY' ]]
}

is_array() {
	#
	# Usage: is_array 'variable_name'
	#
	arguments: $# exactly 1

	local -r variable_name="$1"

	is_hash_array "$variable_name" || is_indexed_array "$variable_name"
}

print_array() {
	#
	# Usage: print_array 'array_by_ref' ['substituted_name']
	#
	# Pretty-print any array for future reuse with source. Associative arrays alpha-sorted by a key. Actually, does print strings and integers too.
	#
	arguments: $# range 1 2 ###some

	# consts

	local -r array_name="$1"
	local -r substituted_name="${2-${array_name}}"
	local -n array_by_ref="$array_name" # don't use -r[eadonly] with -n! ???
	local -r array_type="$( get_variable_type 'array_by_ref' )"

	# vars

	local sorted_keys=''
	local key=''
	local value=''

	# code

	printf "# Generated by script '%s', host '%s' at %(%F %T)T\n" "$script_basename" "$HOSTNAME" "-1"
	if [[ "$array_name" != "$substituted_name" ]]; then
		printf "# Former name '%s', saved as '%s'\n" "$array_name" "$substituted_name"
	fi
	printf '# Type: %s' "${array_type,,}"

	case "$array_type" in
		'HASH')
			printf ', indices: %u\n' "${#array_by_ref[@]}"
			printf '%s=(\n' "$substituted_name"
			sorted_keys=$( printf '%s\n' "${!array_by_ref[@]}" | sort --sort=version )
			while IFS= read -r key; do
				value="${array_by_ref[$key]}"
				printf "\t['%s']='%s'\n" "$key" "$value"
			done <<< "$sorted_keys"
			printf ')\n'
			;;
		'ARRAY')
			printf ', indices: %u\n' "${#array_by_ref[@]}"
			printf '%s=(' "$substituted_name"
			if (( ${#array_by_ref[@]} > 0 )); then
				printf '\n'
				printf "\t'%s'\n" "${array_by_ref[@]}"
			fi
			printf ')\n'
			;;
		'UNDEFINED')
			printf '\n'
			printf '#%s=\n' "$substituted_name"
			;;
		'INTEGER')
			printf '\n'
			printf '%s=%s\n' "$substituted_name" "$array_by_ref"
			;;
		*)
			printf '\n'
			printf "%s='%s'\n" "$substituted_name" "$array_by_ref"
			;;
	esac

	printf '\n'
}

flip_hash_array() {
	#
	# Usage: flip_hash_array 'source_anytype_array_by_ref' 'destination_hash_array_by_ref'
	#
	# Copy array and swap key/value (key=value to value=key)
	# All values in a source array must be unique, no such checking performed.
	#
	arguments: $# exactly 2
	if_debug: print_arguments "$@"

	local -n source_array="$1"
	local -n destination_array="$2"
	local key=''
	local value=''

	for key in "${!source_array[@]}"; do
		value="${source_array[$key]}"
		# check for duplicate (they are not allowed)
		if is_variable_empty "${destination_array[$value]-}"; then
			destination_array["$value"]="$key"
		else
			_die 'All values in a source array must be unique.' "$@"
		fi
	done
}

sort_indexed_array() {
	#
	# Usage: sort_indexed_array 'array_name' ['sort_option']
	#
	arguments: $# range 1 2 ###-ge 1

	# args

	local -r array_name="$1"
	local -r sort_option_DEFAULT=''
	local -r sort_option="${2-${sort_option_DEFAULT}}"

	# consts

	local -r -n array_by_ref="$array_name"
	[ -v 'array_by_ref' ] || return "$boolean_bash_false" # if array not set, return 1
	local -r -i array_indices="${#array_by_ref[@]}"

	# code

	if (( array_indices > 1 )); then
		IFS=$'\n' array_by_ref=( $( sort $sort_option -- <<< "${array_by_ref[*]}" ) )
		unset IFS
	else
		return "$boolean_bash_false"
	fi
}

are_two_arrays_identical() {
	#
	# Usage: are_two_arrays_identical 'array1_name' 'array2_name'
	#
	# Compares lengths and elements of two indexed arrays.
	# Optimized for speed (no index-to-index comparison), therefore not 100% perfect.
	#
	# stdin: none
	# stdout: none
	# stderr: none
	# exit code: boolean
	#
	arguments: $# exactly 2

	# args

	local -r array1_name="$1"
	local -r array2_name="$2"

	# consts

	local -n anti_collision_long_name_array1="$array1_name"
	local -n anti_collision_long_name_array2="$array2_name"

	# flags

	local -i is_identical="$boolean_c_false"

	# code

	# are two arrays equal in length?
	if [[ "${#anti_collision_long_name_array1[@]}" -eq "${#anti_collision_long_name_array2[@]}" ]]; then
		# are them flattened looks equal?
		if [[ "${anti_collision_long_name_array1[*]}" == "${anti_collision_long_name_array2[*]}" ]]; then
			is_identical="$boolean_c_true"
		fi
	fi

	(( is_identical ))
}

is_array_has_duplicates() {
	#
	# Usage: is_array_has_duplicates 'whitespace_delimited_array_in_string' | '(pure_array)'
	#
	# Checks array-in-string or pure array for duplicates
	#
	# stdin: none
	# stdout: none
	# stderr: if_debug
	# exit code: boolean
	#
	arguments: $# atleast 1 ###some

	if_debug: print_arguments "$@"

	local -a input_array=()
	local -A associative_array=()
	local iterator=''

	local -r -i has_duplicates='0'
	local -r -i has_not_duplicates='1'
	local -r -i no_arguments='2'

	case "$#" in
		0)
			if_debug: echo "INFO: [$FUNCNAME] No arguments. Therefore no duplicates."
			return "$no_arguments"
			;;
		1)
			if_debug: echo "INFO: [$FUNCNAME] One argument. Possibly, it's an array-in-string thingy. Trying to expand."
			input_array=($@) # note no backquotes. isn't prone to globs and spaces!
			if_debug: echo "INFO: [$FUNCNAME] Still one argument?"
			case "${#input_array[@]}" in
				0)
					if_debug: echo "INFO: [$FUNCNAME] Seven wonders, its ZERO now! And of course ZERO has no duplicates."
					return "$has_not_duplicates"
					;;
				1)
					if_debug: echo "INFO: [$FUNCNAME] YES, there's only one unexpandable element and of course it has no duplicates."
					return "$has_not_duplicates"
					;;
			esac
			if_debug: echo "INFO: [$FUNCNAME] No, ${#input_array[@]}. Ok then, string already expanded to array. Proceed to enumerating procedure."
			;;
		*)
			if_debug: echo "INFO: [$FUNCNAME] Multiple arguments. Stuff 'em into array and proceed to enumerating procedure."
			input_array=("$@")
			;;
	esac

	for iterator in "${input_array[@]}"; do
		associative_array["${iterator:-EmptyOrUnset}"]='1'
	done

	if [[ "${#input_array[@]}" -ne "${#associative_array[@]}" ]]; then
		return "$has_duplicates"
	else
		return "$has_not_duplicates"
	fi
}


#
# HASH arrays
#
#	get_hash()
#	set_hash()
#

# possible namings:
#
# get_hash 'dict.key'
# set_hash 'dict.key=value'
#
# get_hash 'dict' 'key'
# set_hash 'dict' 'key' 'value'
#
# dict:get 'dict' 'key'
# dict:set 'dict' 'key' 'value'

#is_hash_key_exist() // not required right now

get_hash() {
	#
	# Usage: get_hash 'hash_name' 'hash_key' [STRICT|PROD|ASIS]
	#
	# 'hash_key not found in the hash_name' handling:
	# in STRICT mode -- whole calling script will be terminated. Good for tests.
	# in PROD[UCTION] mode -- will return '0'. Good for the mission-critical production.
	# in ASIS mode -- mimics bash natural behavour, will return ''. Good for an extended error handling. Default mode tho.
	#
	arguments: $# range 2 3

	# consts

	local -r hash_name="$1"
	local -r hash_key="$2"
	local -r not_found_mode="${3-ASIS}"

	# code

	# check disabled due to speed concerns
	#is_hash_array "$hash_name" || _die "$hash_name is NOT a hash array."

	local -n hash_by_reference="$hash_name"

	# is a key set?
	if [[ "${hash_by_reference[$hash_key]+is_set}" ]]; then
		# key is set
		printf '%s\n' "${hash_by_reference[$hash_key]}"
		return 0
	else
		# key is NOT set
		case "$not_found_mode" in
			'STRICT')
				_die 'Hash key not found.' "$@"
				;;
			'PROD')
				printf '%u\n' 0
				;;
			'ASIS')
				printf '\n' # empty string
				;;
			*)
				# OMG
				_die 'Wrong mode.' "$@"
				;;
		esac
		return 1
	fi
}

set_hash() {
	#
	# Usage: set_hash 'hash_name' 'hash_key' 'hash_value'
	#
	arguments: $# exactly 3

	# consts

	local -r hash_name="$1"
	local -r hash_key="$2"
	local -r hash_value="$3"

	# code

	# check disabled due to speed concerns
	#is_hash_array "$hash_name" || _die "$hash_name is NOT a hash array."

	local -n hash_by_reference="$hash_name"
	hash_by_reference["$hash_key"]="$hash_value"
}


#
# JSON
#
#	print_brutally_cleansed_json_string()
#	transform_json_to_hash()
#

json::print_brutally_cleansed_json_string() {
	#
	# Usage: print_brutally_cleansed_json_string 'json_string'
	#
	# Strip unwanted chars and convert ':' to '='. Good enough for simple flat objects like collection of key:number pairs
	#
	arguments: $# exactly 1

	# args

	local -r json_string_to_cleanse="$1"

	# code

	: "$json_string_to_cleanse"
	: "${_//['{},\"']}" # remove {},"
	: "${_/$'\n'$'\n'/$'\n'}" # replace '\n\n' with '\n'
	: "${_%$'\n'}" # remove trailing '\n'
	: "${_#$'\n'}" # remove leading '\n'
	: "${_//:/=}" # replace ':' with '='

	printf '%s\n' "$_"
}

json::transform_json_to_hash() {
	#
	# Usage: transform_json_to_hash 'json_string_to_serialize' 'hash_name'
	#
	arguments: $# exactly 2

	# args

	local -r json_string_to_serialize="$1"
	local -r hash_name="$2"

	# funcs

	add_json_pair_to_hash() {
		#
		# Usage: add_json_pair_to_hash 'raw_json_string' ['key_path']
		#
		arguments: $# range 1 2

		# args

		local -r raw_json_string="$1"
		local -r key_path="${2-}"

		# consts

		local -r array_index_attribute_RE='^([0-9]{1,18})$'

		local -r path_delimiter='.'
		local -r variable_delimiter=':'
		local -r meta_list_delimiter=' ' # ' ' is vulnerable to spaces inside the entities

		local -r current_leaf_meta_attribute_path="${key_path}${path_delimiter}meta${variable_delimiter}"
		local -r current_leaf_meta_attribute_indices="${current_leaf_meta_attribute_path}indices"
		local -r current_leaf_meta_attribute_keys="${current_leaf_meta_attribute_path}keys"
		local -r current_leaf_meta_attribute_variables="${current_leaf_meta_attribute_path}variables"

		# vars

		local json_pairs=''
		local json_pair=''
		local pair_key=''
		local pair_value=''
		local current_key=''

		# code

		json_pairs="$( jq --compact-output --raw-output --exit-status 'to_entries | map("\(.key)=\(.value | tostring)") | .[]' <<< "$raw_json_string" )" || _die "'jq' error" #'#

		# for each pair
		while read -r json_pair; do

			if [ -z "$json_pair" ]; then
				break
			fi

			# split pair to separate vars
			IFS== read pair_key pair_value <<< "$json_pair"

			current_key="$pair_key"

			# does the current pair_value contain nested objects?
			if jq --exit-status '.[]' >/dev/null 2>&1 <<< "$pair_value"; then
				# yep. we need to going deeper

				# simpleton's check. do we need check for array by jq?
				# https://stackoverflow.com/questions/31912454/how-check-if-there-is-an-array-or-an-object-in-jq
				if [[ $pair_key =~ $array_index_attribute_RE ]]; then
					# save array index to leaf's meta attribute
					hash_from_json["$current_leaf_meta_attribute_indices"]+="${hash_from_json[$current_leaf_meta_attribute_indices]+${meta_list_delimiter}}$pair_key"
				fi

				# save leaf name to meta
				hash_from_json["$current_leaf_meta_attribute_keys"]+="${hash_from_json[$current_leaf_meta_attribute_keys]+${meta_list_delimiter}}$pair_key"

				if is_variable_not_empty "$key_path"; then
					current_key="${key_path}${path_delimiter}${pair_key}"
				fi
				add_json_pair_to_hash "$pair_value" "$current_key"

			else
				# no. end of the leaf. write to the hash.
				hash_from_json["$current_leaf_meta_attribute_variables"]+="${hash_from_json[$current_leaf_meta_attribute_variables]+${meta_list_delimiter}}$pair_key"

				if is_variable_not_empty "$key_path"; then
					current_key="${key_path}${variable_delimiter}${pair_key}"
				fi
				hash_from_json["$current_key"]="$pair_value"
			fi

		done <<< "$json_pairs"
	}

	# vars

	local -A hash_from_json=()

	# code

	add_json_pair_to_hash "$json_string_to_serialize"
	source <( print_array 'hash_from_json' "$hash_name" )
}


#
# Copyright & usage
#
#	print_script_version()
#	print_script_usage()
#

print_script_version() {
	arguments: $# none

	echo -e "${CYAN-}$script_description by $script_author, version $script_version${NOCOLOR-}"
	echo
}

print_script_usage() {
	arguments: $# none

	echo -e "Usage: $script_basename $script_usage"
	echo
}


#
# Math
#
#	is_integer()
#	is_not_integer()
#	math::round_floating_number_with_precision()
#	math::add_numbers()
#	math::count_numbers()
#	math::max_of_numbers()
#	math::min_of_numbers()
#	math::average_of_numbers()
#	math::max_of_two_integers()
#	math::min_of_two_integers()
#	math::integer_floor()
#	math::integer_frac()
#

is_integer() {
	#
	# Usage: is_integer 'string_to_check'
	#
	# Checks the first argument as an integer or fail
	#
	# $1: string to check
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# exactly 1

	# consts

	local -r integer_definition_RE='^([+-])?0*([0-9]{1,18})$' # "Integer: A sequence of an optional sign (+ or -) followed by no more than 18 (significant) decimal digits."

	# code

	[[ $1 =~ $integer_definition_RE ]]
}

is_not_integer() {
	#
	# Usage: is_not_integer 'string_to_check'
	#
	# Checks the first argument as not an integer or fail
	#
	# $1: string to check
	# stdin: none
	# stdout: none
	# exit code: boolean
	#
	arguments: $# exactly 1

	! is_integer "$1"
}

math::round_floating_number_with_precision() {
	#
	# Usage: math::round_floating_number_with_precision 'floating_number_to_round' 'precision'
	#
	arguments: $# range 1 2

	# args

	local -r floating_number_to_round="$1"
	local -r precision="${2:-2}"

	# code

	printf '%.*f\n' "$precision" "$floating_number_to_round"
}

math::add_numbers() {
	#
	# Usage: math::add_numbers 'first_number' 'second_number' [third_number..nth_number]
	#
	# jq-extended version, supports any number of whitespace-delimited floating and integer numbers.
	# Max float precision is 10 digits.
	#
	# Note: ${var[*]} is 20% faster than ${var[@]}
	#
	arguments: $# atleast 1

	# code

	jq --slurp add <<< "$*" || _die "'jq' error." "$@"
}

math::count_numbers() {
	#
	# Usage: math::count_of_numbers 'first_number' 'second_number' [third_number..nth_number]
	#
	# jq-extended version, supports any number of whitespace-delimited floating and integer numbers.
	# Max float precision is 10 digits.
	#
	# Note: ${var[*]} is 20% faster than ${var[@]}
	#
	arguments: $# atleast 1

	# code

	jq --slurp length <<< "$*" || _die "'jq' error." "$@"
}

math::max_of_numbers() {
	#
	# Usage: math::max_of_numbers 'first_number' 'second_number' ['third_number'..'nth_number']
	#
	# jq-extended version, supports any number of whitespace-delimited floating and integer numbers.
	# Max float precision is 10 digits.
	#
	# Note: ${var[*]} is 20% faster than ${var[@]}
	#
	arguments: $# atleast 1

	# code

	jq --slurp max  <<< "$*" || _die "'jq' error." "$@"
}

math::min_of_numbers() {
	#
	# Usage: math::min_of_numbers 'first_number' 'second_number' ['third_number'..'nth_number']
	#
	# jq-extended version, supports any number of whitespace-delimited floating and integer numbers.
	# Max float precision is 10 digits.
	#
	# Note: ${var[*]} is 20% faster than ${var[@]}
	#
	arguments: $# atleast 1

	# code

	jq --slurp min  <<< "$*" || _die "'jq' error." "$@"
}

math::average_of_numbers() {
	#
	# Usage: math::average_of_numbers 'first_number' 'second_number' ['third_number'..'nth_number']
	#
	# jq-extended version, supports any number of whitespace-delimited floating and integer numbers.
	# Max float precision is 10 digits.
	#
	# Note: ${var[*]} is 20% faster than ${var[@]}
	#
	arguments: $# atleast 1

	# code

	jq --slurp add/length  <<< "$*" || _die "'jq' error." "$@"
}

math::max_of_two_integers() {
	#
	# Usage: math::max_of_two_integers 'first_integer_number' 'second_integer_number'
	#
	# Returns MAX of numbers
	#
	arguments: $# exactly 2

	local -r -i first_integer_number="$1"
	local -r -i second_integer_number="$2"

	printf '%d\n' "$(( first_integer_number > second_integer_number ? first_integer_number : second_integer_number ))"
}

math::min_of_two_integers() {
	#
	# Usage: math::min_of_two_integers 'first_integer_number' 'second_integer_number'
	#
	# Returns MIN of numbers
	#
	arguments: $# exactly 2

	local -r -i first_integer_number="$1"
	local -r -i second_integer_number="$2"

	printf '%d\n' "$(( first_integer_number < second_integer_number ? first_integer_number : second_integer_number ))"
}

math::integer_floor() {
	#
	# Floor to nearest magnutude (f.e. math::integer_floor 123 100 echoes 100 )
	# $1: integer number
	# $2: integer magnitude
	# >: result
	#
	arguments: $# exactly 2

	local -i number="$1"
	local -i magnitude="$2"

	number=$(( magnitude*(number/magnitude) ))

	printf '%d\n' "$number"
}

math::integer_frac() {
	#
	# Fractional part with required magnutude (f.e. math::integer_frac 123 100 echoes 23 )
	# $1: integer number
	# $2: integer magnitude
	# >: result
	#
	arguments: $# exactly 2

	local -i number="$1"
	local -i magnitude="$2"

	number=$(( number % magnitude ))

	printf '%d\n' "$number"
}


#
# Screen
#

is_screen_already_running() {
	arguments: $# none

	grep --silent "$script_basename" <(screen -ls)
}

screen:start() {
	arguments: $# none

	# init & assign globals
	# init & assign locals
	local -i wait_counter='0'
	local init_message=''
	local success_message=''
	local fail_message=''
	local worthless_call_message=''

	init_message="Starting $script_basename..."
	success_message=" Started."
	fail_message="screen doesn't start in ages!"
	worthless_call_message="$script_basename already running."

	if ! is_screen_already_running; then
		echo -n "$init_message"
		screen -dm -S "$script_basename" -t " $script_description " "$0" run
		while ! is_screen_already_running; do
			wait_counter+=1
			echo -n -e "\r$init_message Try #$wait_counter... "
			# watch your infinite loops
			if [[ $wait_counter -gt 1000 ]]; then _die "$fail_message"; fi
		done
		echo "$success_message"
	else
		echo "$worthless_call_message"
	fi
}

screen:stop() {
	arguments: $# none

	# init & assign globals
	# init & assign locals
	local -i wait_counter='0'
	local init_message=''
	local success_message=''
	local fail_message=''
	local worthless_call_message=''

	init_message="Stopping $script_basename..."
	success_message=" Stopped."
	fail_message="screen doesn't stop in ages!"
	worthless_call_message="$script_basename not running."

	if is_screen_already_running; then
		echo -n "$init_message"
		screen -S "$script_basename" -X quit
		while is_screen_already_running; do
			wait_counter+=1
			echo -n -e "\r$init_message Try #$wait_counter... "
			# watch your infinite loops
			if [[ $wait_counter -gt 1000 ]]; then _die "$fail_message"; fi
		done
		echo "$success_message"
	else
		echo "$worthless_call_message"
	fi
}

screen:restart() {
	arguments: $# none

	screen:stop
	screen:start
}

screen:show() {
	arguments: $# none

	# init & assign globals
	# init & assign locals
	local -i error='0'
	local init_message=''

	init_message="Attaching to $script_basename screen session... "

	if ! is_screen_already_running; then
		echo "$script_basename not running."
		screen:start
	fi

	echo -n "$init_message"

	if is_screen_already_running; then
		screen -r "$script_basename"
		error="$?"
	else
		error="1"
	fi

	if [[ "$error" -ne 0 ]]; then
		echo "Error $error. Looks like $script_basename finished earlier than expected. Exiting..."
	fi
}

screen:run() {
	# placeholder. actual function must be re-defined in the callee script
	_die "screen:run() not defined"
}


#
# the last: function lister
#

__list_functions() {
	#
	# List all functions but started with '_'
	#
	arguments: $# none

	# consts

	local -r private_function_attribute_RE='^_'

	# vars

	local function_name=''
	local -a all_functions=''
	local -a private_functions=''
	local -a public_functions=''

	# code

	all_functions=( $(compgen -A function) )

	for function_name in "${all_functions[@]}"; do
		if [[ "${function_name}" =~ $private_function_attribute_RE ]]; then
			private_functions+=("$function_name")
		else
			public_functions+=("$function_name")
		fi
	done

	echo "${#private_functions[@]} private functions:"
	echo
	printf '%s\n' "${private_functions[@]}" | column -n
	echo
	echo "${#public_functions[@]} public functions:"
	echo
	printf '%s\n' "${public_functions[@]}" | column -n
	echo
}


#
# main()
#

# for _die() to terminate unconditionally even when we are deep down in the subshells
#trap "exit 1" TERM
export TOP_PID=$$

# log errors
#if_debug: log_stderr_to_file

# check if we're sourced
if (return 0 2>/dev/null); then

	# sourced
	:
	# do nothing

else

	# not sourced

	declare -r script_version='0.6.0'
	declare -r script_description='Oh my handy little functions'
	declare -r script_usage='function_name'

	case "$@" in
		"")
			print_script_version
			print_script_usage
			__list_functions
			;;
		*)
			if is_function_exist "$1"; then
				"$@" # potentially unsafe
			else
				_die "function '$1' is not defined"
			fi
			;;
	esac
fi

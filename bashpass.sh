#!/bin/bash
#
# Bashpass
#
# Copyright (C) 2017 Kevin Cotugno
# All rights reserved
#
# Distributed under the terms of the MIT software license. See the
# accompanying LICENSE file or http://www.opensource.org/licenses/MIT.
#
# Author: kcotugno
# Date: 2/12/2017
#

clip=""
os=`uname`
pass_file="$HOME/.bashpass.secure"
conf="$HOME/.bashpass.conf"

which gpg2 &> /dev/null
if (( ! $? )); then
	gpg="gpg2"
else
	gpg="gpg"
fi

which jq &> /dev/null
if (( ! $? )); then
	jq="jq --compact-output"
	jq_raw="--raw-output"
else
	echo "Missing required dependency 'jq'."
	echo "Please see https://stedolan.github.io/jq/"
	exit 1
fi

decrypt_pass_file () {
	$gpg -q --no-verbose --no-tty --batch -d $pass_file
}

encrypt_pass_file () {
	if [[ -z "$BASHPASS_KEY" ]]; then
		$gpg --yes -o $pass_file -e
	else
		$gpg -r "$BASHPASS_KEY" --yes -o $pass_file -e
	fi
}

test_decrypt () {
	decrypt_pass_file > /dev/null
	if [ "$?" -ne 0 ]; then
		echo "Error decrypting password file"
		exit 1
	fi
}

has_key () {
	local key=$1

	local has_key=`decrypt_pass_file | $jq ".passwd | has(\"$key\")"`

	if [[ "$has_key" == "true" ]]; then
		return 1
	else
		return 0
	fi
}

get_pass () {
	local key=$1

	has_key "$key"
	if (( $? )); then
		local pass=`decrypt_pass_file | $jq $jq_raw ".passwd.$key.password"`
		echo "$pass" | $clip
	else
		echo "Key '$key' does not exist"
		return 1
	fi

}

add_pass () {
	local key=$1

	has_key "$key"
	if (( $? )); then
		echo "Key '$key' already exists"
		return 1
	else
		new_pass
		decrypt_pass_file | $jq ".passwd.$key = {\"password\": \
			\"$password\"}" | encrypt_pass_file

	fi
}

delete_pass () {
	local key=$1

	has_key "$key"
	if (( $? )); then
		echo "Nothing to do"
		return
	else
		decrypt_pass_file | $jq "del(.passwd.$key)" | \
			encrypt_pass_file
	fi
}

list_pass () {
	decrypt_pass_file
}

check_pass () {
	key=$1
	if [ "$entry" != "" ]; then
		echo "Password for '$key' already exists"
		exit 1
	fi
}

new_pass () {
	ok=1
	while [ "$ok" -eq 1 ]; do
		echo -n "Please enter a password: "
		read -ser password && echo ""
		split=($password)
		if [ "$password" = "" ]; then
			echo "" && echo "The password cannot be blank"
		elif [ "${split[0]}" != "$password" ]; then
			echo "" && echo "The password may not contain spaces"
		else
			ok=0
		fi
	done
}

initialize () {
	init_dir
	load_conf
	init_secure
}

init_secure () {
	check_file "$pass_file"
	if (( ! $? )); then
		echo "{}" | encrypt_pass_file
		echo "Bashpass initialized. Your secure file is here: '$pass_file'"
	fi
}

init_dir () {
	if [ ! -e `dirname $pass_file` ]; then
		mkdir -p `dirname $pass_file`
	fi
}

check_file () {
	if [[ -e "$1" ]]; then
		return 1
	fi
	return 0
}

load_conf () {
	check_file "$conf"
	if (( $? )); then
		BASHPASS_KEY=`cat $conf | $jq $jq_raw '.BASHPASS_KEY'`
		BASHPASS_CLIP=`cat $conf | $jq $jq_raw '.BASHPASS_CLIP'`
	else
		echo "{}" > $conf
	fi
}

set_config () {
	value="$2"

	case $1 in
		key)
			key='BASHPASS_KEY'
			;;
		clip)
			key='BASHPASS_CLIP'
			;;
		*)
			echo "Invalid option"
			echo "Avalable options: {key} {clip}"
			return 1
	esac


	if [[ -z "$value" ]]; then
		cat "$conf" | $jq $jq_raw ".$key"
	else
		save_config_value "$key" "$value"
	fi
}

save_config_value () {
	local tmp=`cat $conf`
	echo $tmp | $jq ".$1 = \"$2\"" > $conf
}

sanitize_json () {
	$2=`echo "$1" | sed -E 's/"|\\/\\&/g'`
}

usage () {
	echo "Bashpass"
	echo "Copyright (c) 2017 Kevin Cotugno"
	echo "Distributed under the terms of the MIT software license. See the"
	echo "accompanying LICENSE file or http://www.opensource.org/licenses/MIT."
	echo ""
	echo "Usage: bashpass [OPTION] KEY"
	echo ""
	echo "	KEY		retrieves the password of the given key"
	echo "	-a KEY		add a new password with the given key"
	echo "	-d KEY		delete the password entry of the given key"
	echo "	-l		list all keys and passwords in the database"
	echo "	-c KEY VALUE	set configuration values"
	echo "				options:"
	echo "				key: This is a gpg key fingerprint which will be"
	echo "					used for encrypting so you won't be"
	echo "					prompted every time."
	echo "				clip: The clipboard command to which the password"
	echo "					will be piped into"
	echo ""
	echo "Bashpass repository at https://github.com/kcotugno/bashpass"
}

parse_options () {
	local __cmd=$1
	local __arg=$2

	while getopts ":a:ld:c" opt $3; do
		case $opt in
			a)
				eval $__cmd='add'
				eval $__arg="'$OPTARG'"
				;;
			l)
				eval $__cmd='list'
				;;
			d)
				eval $__cmd="'del'"
				eval $__arg="'$OPTARG'"
				;;
			c)
				eval $__cmd="'config'"
				;;
			\?)
				eval $__cmd="'$OPTARG'"
				return 1
				;;
			\:)
				eval $__cmd="'$OPTARG'"
				return 2
				;;
		esac
	done
}

# Set the command to pipe the password into.
if [[ os == "Darwin" ]]; then
	clip="pbcopy"
else
	clip="cat"
fi

initialize
test_decrypt
args=($@)
parse_options cmd arg "${args[*]}"
ret=$?
case $ret in
	1)
		echo "Command '-$cmd' is not valid."
		exit 1
		;;
	2)
		echo "Command '-$cmd' needs an arguement."
		exit 1
		;;
esac

case $cmd in
	add)
		add_pass $arg
		exit $?
		;;
	list)
		list_pass
		exit $?
		;;
	del)
		delete_pass $arg
		exit $?
		;;
	config)
		set_config "$2" "$3"
		exit $?
		;;
	"")
		if [ "${args[0]}" = "" ]; then
			usage
			exit 1
		else
			get_pass ${args[0]}
			exit $?
		fi
		;;
esac

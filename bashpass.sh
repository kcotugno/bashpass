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
pass_file="$HOME/.config/bashpass/bashpass.secure"
conf="$HOME/.config/bashpass/bashpass.conf"

which gpg2 &> /dev/null
if (( ! $? )); then
	gpg="gpg2"
else
	gpg="gpg"
fi

which jq &> /dev/null
if (( ! $? )); then
	jq="jq --compact-output"
else
	echo "Missing required dependency 'jq'."
	echo "Please see https://stedolan.github.io/jq/"
	exit 1
fi

decrypt_pass_file () {
	$gpg -q --no-verbose --no-tty --batch -d $pass_file
}

encrypt_pass_file () {
	if [ "$GPG_KEY" = "" ]; then
		$gpg --yes -o $pass_file -e
	else
		$gpg -r $GPG_KEY --yes -o $pass_file -e
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
	local __key=$1

	local __has_key=`decrypt_pass_file | $jq ".passwd | has(\"$key\")"`

	if [[ "$__has_key" == "true" ]]; then
		return 1
	else
		return 0
	fi
}

get_pass () {
	local __key=$1

	if (( `has_key $__key` )); then
		local __pass=`decrypt_pass_file | $jq "'.passwd.$key.password'"`
		echo "$__pass" | $clip
	else
		echo "Key '$__key' does not exist"
		return 1
	fi

}

add_pass () {
	local __key=$1

	if (( `has_key $__key` )); then
		echo "Key '$__key' already exists"
		return 1
	else
		new_pass
		decrypt_pass_file | $jq ".passwd.$__key = {\"password\": \
			\"$password\"}" | encrypt_pass_file

	fi
}

delete_pass () {
	local __key=$1

	if (( `has_key $__key` )); then
		echo "Nothing to do"
		return
	else
		decrypt_pass_file | $jq "del(.passwd.$__key)" | \
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
	check_secure_file
	secure_exists=$?

	if (( $secure_exists )); then
		echo "{}" | encrypt_pass_file
		echo "Bashpass initialized. Your secure file is here: '$pass_file'"
	fi
}

init_dir () {
	if [ ! -e `dirname $pass_file` ]; then
		mkdir -p `dirname $pass_file`
	fi
}

check_secure_file () {
	if [ -e "$pass_file" ]; then
		return 0
	fi
	return 1
}

load_conf () {
	if [ -e "$conf" ]; then
		source $conf
	else
		(echo "#"
		echo "# $conf"
		echo "#") > $conf
	fi
}

set_config () {
	key=$1
	value=$2
	if [[ "$value" = "" ]]; then
		echo "An option and value must be specified"
		echo "Configurable options: {key} {clip}"
		return 1
	else
		case $1 in
			key)
					GPG_KEY=$value
					key='GPG_KEY'
				;;
			clip)
				clipboard=$value
				key='clip'
				;;
			*)
				echo "Invalid option"
				echo "Avalable options: {key} {clip}"
				return 0
		esac

		save_config_value $key $value
	fi
}

save_config_value () {
	current=(`get_config_value $1`)
	if [ "$current" != "" ]; then
		delete_config_value ${current[0]}
	fi

	echo "$1=\"$2\"" >> $conf
}

get_config_value () {
	cat $conf | awk -v key=$1 '
	{ split($0, conf, "=");
		if (conf[1] == toupper(key)) {
			print NR, $0;
		}
	}'
}

delete_config_value () {
	local tmp=mktemp
	sed "${1}d" $conf > $tmp
	cat $tmp > $conf
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
if [ "Darwin" ]; then
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
		set_config ${args[1]} ${args[2]}
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

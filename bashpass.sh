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

GPG="gpg2"
GPG_KEY=""
CLIP=""
OS=`uname`
PASS_FILE="$HOME/.config/bashpass/pass.secure"
CONF="$HOME/.config/bashpass/bashpass.conf"

decrypt_pass_file () {
  $GPG -q --no-verbose --no-tty --batch -d $PASS_FILE
}

encrypt_pass_file () {
  if [ "$GPG_KEY" = "" ]; then
    $GPG --yes -o $PASS_FILE -e
  else
    $GPG -r $GPG_KEY --yes -o $PASS_FILE -e
  fi
}

test_decrypt () {
  decrypt_pass_file > /dev/null
  if [ "$?" -ne 0 ]; then
    echo "Error decrypting password file"
    exit 1
  fi
}

parse_decrypted () {
  awk -v key=$key '
  { if (tolower($1) == tolower(key)) {
    print NR, $0;
  } }
  '
}

get_pass () {
  test_decrypt
  key=$1
  entry=(`decrypt_pass_file | parse_decrypted`)

  if [ "$entry" = "" ]; then
    echo "No password for '$key'"
    return 1
  else
    echo "${entry[2]}" | $CLIP
  fi
}

add_pass () {
  test_decrypt
  key=$1
  if [ "$key" = "" ]; then
    echo "You must enter a key for your password"
    return 1
  fi
  entry=(`decrypt_pass_file | parse_decrypted`)
  check_pass $key
  new_pass
  (decrypt_pass_file && echo "$key $password") | encrypt_pass_file
}

delete_pass () {
  test_decrypt
  key=$1
  entry=(`decrypt_pass_file | parse_decrypted`)
  if [ "$entry" = "" ]; then
    echo "Nothing to delete"
    exit 0
  else
    decrypt_pass_file | sed "${entry[0]}d" | encrypt_pass_file
    echo "Password for $key deleted"
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

  if [ "$secure_exists" -eq 1 ]; then
    echo -n "" | encrypt_pass_file
    echo "Bashpass initialized. Your secure file is here: '$PASS_FILE'"
  fi
}

init_dir () {
  if [ ! -e `dirname $PASS_FILE` ]; then
    mkdir -p `dirname $PASS_FILE`
  fi
}

check_secure_file () {
  if [ -e "$PASS_FILE" ]; then
    return 0
  fi
  return 1
}

load_conf () {
  if [ -e "$CONF" ]; then
    source $CONF
  else
    (echo "#"
    echo "# $CONF"
    echo "#") > $CONF
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
        CLIPBOARD=$value
        key='CLIP'
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

  echo "$1=\"$2\"" >> $CONF
}

get_config_value () {
  cat $CONF | awk -v key=$1 '
  { split($0, conf, "=");
    if (conf[1] == toupper(key)) {
      print NR, $0;
    }
  }'
}

delete_config_value () {
  local tmp=mktemp
  sed "${1}d" $CONF > $tmp
  cat $tmp > $CONF
}

usage () {
  echo "Bashpass"
  echo "Copyright (c) 2017 Kevin Cotugno"
  echo "Distributed under the terms of the MIT software license. See the"
  echo "accompanying LICENSE file or http://www.opensource.org/licenses/MIT."
  echo ""
  echo "Usage: bashpass [OPTION] KEY"
  echo ""
  echo "  KEY             retrieves the password of the given key"
  echo "  -a KEY          add a new password with the given key"
  echo "  -d KEY         delete the password entry of the given key"
  echo "  -l              list all keys and passwords in the database"
  echo "  -c KEY VALUE    set configuration values"
  echo "                    options:"
  echo "                      key: This is a gpg key fingerprint which will be used"
  echo "                        for encrypting so you won't be prompted every time."
  echo "                      clip: The clipboard command to which the password will"
  echo "                        be piped into"
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
  CLIP="pbcopy"
else
  CLIP="cat"
fi

initialize
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

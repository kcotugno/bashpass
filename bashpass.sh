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
PASS_FILE="$HOME/.config/bashpass/pass.secure"
CONF_FILE="$HOME/.config/bashpass/bashpass.conf"
#-q --no-verbose --no-tty --batch
decrypt_pass_file () {
  $GPG  -d $PASS_FILE
}

encrypt_pass_file () {
  if [ "$GPG_KEY" = "" ]; then
    $GPG --yes -o $PASS_FILE -e
  else
    $GPG -r $GPG_KEY --yes -o $PASS_FILE -e
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
  key=$1
  entry=(`decrypt_pass_file | parse_decrypted`)

  if [ "$entry" = "" ]; then
    echo "No password for '$key'"
    return 1
  else
    echo `echo "${entry[2]}"`
  fi
}

add_pass () {
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
  if [ -e "$CONF_FILE" ]; then
    source $CONF_FILE
  else
    (echo "#"
    echo "# $CONF_FILE"
    echo "#") > $CONF_FILE
  fi
}

set_config () {
  key=$1
  value=$2
  if [[ "$key" = "" || "$value" = "" ]]; then
    echo "An option and value must be specified"
    echo "Configurable options: {key}"
    return 1
  else
    case $1 in
      key)
          GPG_KEY=$value}
          key='GPG_KEY'
        ;;
      *)
        echo "Configurable options: {key}"
        return 0
    esac

    save_config_value $key $value
  fi
}

save_config_value () {
  IFS=":"
  current=(`cat $CONF_FILE | grep "$key="`)
  if [ "$current" != "" ]; then
    delete_config_value $current
  fi
  unset IFS

  echo "$1=\"$2\"" >> $CONF_FILE
}

delete_config_value () {
  cat $CONF_FILE | sed "${1}d" > $CONF_FILE
}

usage () {
  echo "Bashpass"
  echo "Copyright (c) 2017 Kevin Cotugno"
  echo "Distributed under the terms of the MIT software license. See the"
  echo "accompanying LICENSE file or http://www.opensource.org/licenses/MIT."
  echo ""
  echo "Usage: bashpass [COMMAND] KEY"
  echo ""
  echo "  pass KEY          retrieves the password of the given key"
  echo "  add KEY           add a new password with the given key"
  echo "  rm  KEY           delete the password entry of the given key"
  echo "  list              list all keys and passwords in the database"
  echo "  config KEY VALUE  set configuration values"
  echo "                    options:"
  echo "                      key: This is a gpg key fingerprint which will be used"
  echo "                      for encrypting so you won't be prompted every time."
  echo ""
  echo "Bashpass repository at https://github.com/kcotugno/bashpass"
}

main () {
  args=($@)
  initialize
  while true; do
    if [ "${args[0]}" = "pass" ]; then
      get_pass ${args[1]}
      exit $?
    elif [ "${args[0]}" = "add" ]; then
      add_pass ${args[1]}
      exit $?
    elif [ "${args[0]}" = "rm" ]; then
      delete_pass ${args[1]}
      exit $?
    elif [ "${args[0]}" = "list" ]; then
      list_pass
      exit $?
    elif [ "${args[0]}" = "config" ]; then
      set_config ${args[1]} ${args[2]}
      exit $?
    else
      usage
      exit 1
    fi
  done
}

main $@

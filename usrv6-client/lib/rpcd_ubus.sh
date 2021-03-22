#!/bin/sh

# This script is for communicating with the gateway.

. /usr/share/libubox/jshn.sh

# Copied from:
# https://stackoverflow.com/questions/31457586/how-can-i-check-ip-version-4-or-6-in-shell-script
function isipv6 {
  local ip=$1
  # I do not like this bash behavior
  if [ "$ip" != "${1#*[0-9].[0-9]}" ]; then
    return 1
  elif [ "$ip" != "${1#*:[0-9a-fA-F]}" ]; then
    return 0
  fi
  return 1
}

function query_gw {
	local ip=$1
	local req=$2

  cacertdir=$(uci get usrv6c.@general[0].cacrt_dir)

	# first try https
	ret=$(curl https://$ip/ubus -d "$req") 2>/dev/null
	if [ $? -eq 0 ]; then
		echo $ret
		return 0
	fi

  # try with tofu https certificate
  ret=$(curl --cacert $cacertdir/$ip.pem --capath $cacertdir https://$ip/ubus -d "$req") 2>/dev/null
  if [ $? -eq 0 ]; then
  	echo $ret
  	return 0
  fi

	# try with --insecure
	if [ $(uci get usrv6c.@general[0].try_insecure) == '1' ]; then
		ret=$(curl --insecure https://$ip/ubus -d "$req") 2>/dev/null
		if [ $? -eq 0 ]; then
			echo $ret
			return 0
		fi
	fi

	# try with http
	if [ $(uci get usrv6c.@general[0].try_http) == '1' ]; then
		ret=$(curl http://$ip/ubus -d "$req") 2>/dev/null
		if [ $? -eq 0 ]; then
			echo $ret
			return 0
		fi
	fi

	return 1
}

function request_token {
  local ip=$1
  local user=$2
  local password=$3

  json_init
  json_add_string "jsonrpc" "2.0"
  json_add_int "id" "1"
  json_add_string "method" "call"
  json_add_array "params"
  json_add_string "" "00000000000000000000000000000000"
  json_add_string "" "session"
  json_add_string "" "login"
  json_add_object
  json_add_string "username" $user
  json_add_string "password" $password
  json_close_object
  json_close_array
  req=$(json_dump)

  ret=$(query_gw $ip "$req") 2>/dev/null
	if [ $? != 0 ]; then
		return 1
	fi

  json_load "$ret"
  json_get_vars result result
  json_select result
  json_select 2
  json_get_var ubus_rpc_session ubus_rpc_session
  echo $ubus_rpc_session
}

function install_route {
  # think about how to use --interface option in curl
  local token=$1
  local ip=$2
  local secret=$3
  local prefix=$4
  local interface=$5
  local path=$6

  json_init
  json_add_string "jsonrpc" "2.0"
  json_add_int "id" "1"
  json_add_string "method" "call"
  json_add_array "params"
  json_add_string "" $token
  json_add_string "" "usrv6s"
  json_add_string "" "install"
  json_add_object
  json_add_string "secret" $secret
  json_add_string "prefix" $prefix
  json_add_string "interface" $interface
  json_add_array "path"
  # loop through comma seperated path list
  for p in ${path//,/ } ; do
    json_add_string "" "$p"
  done
  json_close_array
  json_close_object
  json_close_array
  req=$(json_dump)

  ret=$(query_gw $ip "$req") 2>/dev/null
	if [ $? != 0 ]; then
		return 1
	fi
}

function delete_route {
  local token=$1
  local ip=$2
  local secret=$3
  local prefix=$4
  local interface=$5

  json_init
  json_add_string "jsonrpc" "2.0"
  json_add_int "id" "1"
  json_add_string "method" "call"
  json_add_array "params"
  json_add_string "" $token
  json_add_string "" "usrv6s"
  json_add_string "" "delete"
  json_add_object
  json_add_string "secret" $secret
  json_add_string "prefix" $prefix
  json_add_string "interface" $interface
  json_close_object
  json_close_array
  req=$(json_dump)

  ret=$(query_gw $ip "$req") 2>/dev/null
	if [ $? != 0 ]; then
		return 1
	fi
}

function list_prefixes {
  local token=$1
  local ip=$2
  local secret=$3

  json_init
  json_add_string "jsonrpc" "2.0"
  json_add_int "id" "1"
  json_add_string "method" "call"
  json_add_array "params"
  json_add_string "" $token
  json_add_string "" "usrv6s"
  json_add_string "" "list_prefixes"
  json_add_object
  json_add_string "secret" $secret
  json_close_object
  json_close_array
  req=$(json_dump)

  ret=$(query_gw $ip "$req") 2>/dev/null
	if [ $? != 0 ]; then
		return 1
	fi

  json_load "$ret"
  json_get_vars result result
  json_select result
  json_select 2
  json_get_values prefixes prefixes
  echo $prefixes
}

function get_free_prefix {
  local token=$1
  local ip=$2
  local secret=$3
  local random=$4

  json_init
  json_add_string "jsonrpc" "2.0"
  json_add_int "id" "1"
  json_add_string "method" "call"
  json_add_array "params"
  json_add_string "" $token
  json_add_string "" "usrv6s"
  json_add_string "" "get_free_prefix"
  json_add_object
  json_add_string "secret" $secret
  json_add_boolean "random" $random
  json_close_object
  json_close_array
  req=$(json_dump)

  ret=$(query_gw $ip "$req") 2>/dev/null
	if [ $? != 0 ]; then
		return 1
	fi

  json_load "$ret"

  # we introduced a new api to return more
  # {
  #	 "2001:xx:xxx:xx::/64": {
  #	 	 "prefix": "2001:xxx:xxx:xxx::/64",
  #	 	 "valid": 6075,
  #	 	 "preferred": 2475
  #	 }
  # }

  json_get_vars result result
  json_select result
  json_select 2

  json_get_keys keys
  for key in $keys; do
    json_get_var val "$key"
    json_select "$key"
    json_get_var prefix prefix
    json_get_var valid valid
    json_get_var preferred preferred
    echo $prefix $valid $preferred
    break
  done
}

#!/bin/sh

. /usr/share/libubox/jshn.sh

# This script is for manging the prefixes on the gateway!
# We can check

function prefix_in_otherprefixes {
	local secret=$1
	local prefix=$2

	# owipcalc seems a great tool for that!!!
	i=0
	while uci get usrv6prefixes.@user[$i] &> /dev/null ; do
		# skip own user
		if [ ! "$(uci show usrv6prefixes.@user[$i] | grep $secret)" ] ; then
				user_prefixes=$(uci get usrv6prefixes.@user[$i].prefix)
				if [ $? -ne  0 ] ; then
					continue
				fi
				for tmp_prefix in $user_prefixes ; do
					if owipcalc "$tmp_prefix" contains "$prefix" > /dev/null || owipcalc "$prefix" contains "$tmp_prefix" > /dev/null ; then
						echo 1 && return
					fi
				done
		fi
		i=$((i+1));
	done
	echo 0
}

function prefix_in_ownprefixes {
	local secret=$1
	local prefix=$2

	# https://stackoverflow.com/questions/8063228/how-do-i-check-if-a-variable-exists-in-a-list-in-bash
	own_prefixes=$(uci get usrv6prefixes.$secret.prefix) 2> /dev/nulll
	if [ $? -ne 0  ]; then
		echo 0 && return
	fi
	for tmp_prefix in $own_prefixes ; do
		if [ $tmp_prefix == $prefix ] ; then
			echo 1 && return
		fi
	done
	echo 0
}

# section name is the secret
function create_new_client {
	local secret=$1

	uci import usrv6prefixes < /etc/config/usrv6prefixes
	#uci show usrv6prefixes
	uci set usrv6prefixes.$secret=user
}

# here we add a prefix
function add_prefix {
	local secret=$1
	local prefix=$2

	if ! section=$(uci get usrv6prefixes."$secret") 2> /dev/null; then 
		create_new_client $secret $prefix
	fi
	uci add_list usrv6prefixes.$secret.prefix=$prefix
	uci commit
}

function list_prefix {
	local json_input=$1

	json_load $json_input
	json_get_var secret secret

	prefixes=$(uci get usrv6prefixes.$secret.prefix)
	json_init
	json_add_array "prefixes"
        for prefix in $prefixes; do
		json_add_string "" $prefix
	done
	json_close_array
	echo $(json_dump)
}

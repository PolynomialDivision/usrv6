#!/bin/sh

function announce_prefix {
	local prefix=$1

	# Redistribute Prefix in network
	uci add babeld filter
	uci set babeld.@filter[-1].type='redistribute'
	uci set babeld.@filter[-1].ip=$prefix
	uci commit
}

function do_not_announce_prefix {
	local prefix=$1

	uci add babeld filter
	uci set babeld.@filter[-1].type='redistribute'
	uci set babeld.@filter[-1].ip=$prefix
	uci set babeld.@filter[-1].local='true'
	uci set babeld.@filter[-1].action='deny'

	uci add babeld filter
	uci set babeld.@filter[-1].type='redistribute'
	uci set babeld.@filter[-1].ip=$prefix
	uci set babeld.@filter[-1].action='deny'

	uci commit
}

function get_gw_ids {
	gw_ids=$(echo "dump" | nc ::1 33123 | grep "prefix ::/0" | awk '{print $11}' | uniq)
	echo $gw_ids
}

function get_gw_ips {
	local gw_id=$1

	# ToDo: Make This Configurable
	# ToDo: Use ubus
	gw_ips=$(echo "dump" | nc ::1 33123 | grep $gw_id | awk '{print $7}')
	# try getting a 128 ip
	# for now just search for 128 ips
	for gw_ip in $gw_ips; do
		tmp=$(echo $gw_ip | tr "/" " ")
		ip=$(echo $tmp | awk '{print $1}')
		prefix=$(echo $tmp | awk '{print $2}')
		if [ $prefix == "128" ]; then
			echo $ip
			return 0
		fi
	done
}


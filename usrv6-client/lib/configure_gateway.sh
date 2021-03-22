#!/bin/sh

# This script initializes a gateway.
# We create secret that we use to manage the prefixes on the gateway.

# An example entry looks like this:
# Username and password are hardcoded for now

# config gateway '10_0_0_2'
#	option secret '67Yl2L7z6Ldi8fbhQsoC6cIcKapcf6dd'
#	option user 'usrv6'
#	option password 'usrv6'


TOKEN_LENGTH=32

function create_secret {
	# credits: https://gist.github.com/earthgecko/3089509
	cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $TOKEN_LENGTH | head -n 1
}

function create_new_section {
	local gw_ip=$1

	uci import usrv6c < /etc/config/usrv6c
	uci set usrv6c.$gw_ip=gateway
	uci set usrv6c.$gw_ip.secret="$(create_secret)"
	uci set usrv6c.$gw_ip.user="usrv6" # not sure what to do here?
	uci set usrv6c.$gw_ip.password="usrv6"
	uci commit
}

function process_gw_ip {
	local gw_ip=$1

	# ipv4 processing
	ip=$(echo $gw_ip | tr '.' '_')
	
	# ipv6 processing
	ip=$(echo $ip | tr ':' '_')
	ip=$(echo $ip | cut -d '[' -f 2)
	ip=$(echo $ip | cut -d ']' -f 1)

	echo $ip
}

function init_gateway {
	local gw_ip=$1

	ip=$(process_gw_ip $gw_ip)

	if ! section=$(uci get usrv6c."$ip") 2> /dev/null; then 
		create_new_section $ip
	fi

	init_crt $gw_ip

	echo $(uci get usrv6c."$ip".secret)
}

# here we implement TOFU
function init_crt {
	local gw_ip=$1

	cacertdir=$(uci get usrv6c.@general[0].cacrt_dir)
	openssl s_client -showcerts -connect $gw_ip:443 </dev/null 2>/dev/null|openssl x509 -outform PEM > $cacertdir/$gw_ip.pem
}

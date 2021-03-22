#!/bin/sh

. /usr/share/libubox/jshn.sh

. /usr/share/usrv6/delete_prefix.sh
. /usr/share/usrv6/install_prefix.sh
. /usr/share/usrv6/manage_prefixes.sh
. /usr/share/usrv6/babel_server.sh

case "$1" in
	list)
		cmd='{ "install": { "secret":"secret", "prefix": "2001::/64", "inteface":"eth0", "path":["2000::1",]},'
		cmd=$(echo $cmd ' "delete": {"secret":"secret", "prefix": "2001::/64"},')
		cmd=$(echo $cmd ' "list_prefixes": {"secret":"secret"},')
		cmd=$(echo $cmd ' "get_free_prefix": {"random":"true"} }')
		echo $cmd
	;;
	call)
		case "$2" in
			install)
				read input;
				logger -t "usrv6s" "call" "$2" "$input"
				install_prefix $input
			;;
			delete)
				read input;
				logger -t "usrv6s" "call" "$2" "$input"
				delete_prefix $input
			;;
			list_prefixes)
				read input;
				logger -t "usrv6s" "call" "$2" "$input"
				list_prefix $input
			;;
			get_free_prefix)
				read input;
				logger -t "usrv6s" "call" "$2" "$input"
				get_free_prefix_json $input
			;;
		esac
	;;
esac

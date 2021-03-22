#!/bin/sh

. /usr/share/usrv6/manage_prefixes.sh
. /usr/share/libubox/jshn.sh

# install route
function install_prefix {
    local json_input=$1

    logger -t "usrv6s" "installing" "route"
    json_load $json_input
    json_get_var secret secret
    json_get_var prefix prefix
    json_get_var interface interface
    json_get_values path path

    # check if prefix is already announced
    if [ ! "$(prefix_in_otherprefixes $secret $prefix)" -eq "0" ] ; then
        return 1
    fi

    # check own prefix
    if [ $(prefix_in_ownprefixes $secret $prefix) == "1" ] ; then
        return 1
        #elif [ "$(is_route_installed $prefix)" == "1" ] ; then
        # if it is not our prefix we are not allowed to install more specific routes
        #return 1
    fi

    # if not add the prefix
    add_prefix $secret $prefix

    # findout on which interface we have to send the package
    firsthop=$(echo $path | awk '{print $1}')

    # get interface manually by using "ip get"
    dev=$(ip route get $firsthop |awk -F'dev ' '{print $2}' | awk '{print $1}')

    # add segment routing rule
    logger -t "usrv6s" "ip -6 route add $prefix dev $dev encap seg6 mode inline segs ${path// /,}"

    ip -6 route add $prefix dev $dev encap seg6 mode encap segs ${path// /,}
}

#!/bin/sh

# This script is for deleting a prefix on the gateway.

. /usr/share/usrv6/manage_prefixes.sh

function delete_prefix {
    local json_input=$1

    json_load $json_input

    json_get_var secret secret
    json_get_var prefix prefix

    # check own prefix
    if [ $(prefix_in_ownprefixes $secret $prefix) != "1" ] ; then
        return 1
    fi

    uci del_list usrv6prefixes.$secret.prefix=$prefix

    ip -6 route del $prefix
}

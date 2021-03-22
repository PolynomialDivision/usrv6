. /usr/share/usrv6/babel.sh
. /usr/share/libubox/jshn.sh

# A short example how we can use the library with babeld
# /etc/config/babeld
# Do not announce global prefixes the config is like that:
#
# config filter
#        option type 'redistribute'
#        option ip '2000::/8'
#        option local 'true'
#        option action 'deny'
#
#config filter
#        option type 'redistribute'
#        option ip '2000::/8'
#        option action 'deny'

# Actually, we need the call to see which routes we announce
# and so we can use for the "public communication".
# ubus call babeld get_xroutes
# PR: https://github.com/openwrt-routing/packages/pull/630

function new_prefix {
    local priv_ip=$1

    # reqeust gw ids
    gw_ids=$(get_gw_ids)

    # search for the ips
    gw_ip=$(get_gw_ips $gw_ids)
    echo $gw_ip

    # get a free prefix
    prefix_call=$(usrv6c get_free_prefix --ip [$gw_ip] --user usrv6 --password usrv6 --random 1)
    json_load "$prefix_call"
    json_get_keys keys
    for key in $keys; do
        json_select "$key"
        json_get_var prefix prefix
        break
    done
    echo $prefix

    # ToDo: Instead of configuring odhcpd we can just do:
    # ip -6 a add 2042::1/64 valid_lft 400 preferred_lft 200 dev br-la
    # This becomes much easier!!!

    # first get the old prefix
    old_prefix=$(uci get dhcp.lan.prefix_filter)

    # now set the new prefix and remove the old one
    uci add_list network.lan.ip6prefix=''${prefix}'' # make 'lan' interface configurable
    uci del_list network.lan.ip6prefix=''${old_prefix}'' # make 'lan' interface configurable
    uci commit

    # now set the new prefix as prefix_filter
    uci set dhcp.lan.prefix_filter=''${prefix}''
    uci commit

    # do_not_announce_prefix $prefix
    # not needed if we install the babel rules correctly

    # install segmentrouting rule

    #echo usrv6c [$gw_ip] usrv6 usrv6 install 2001:16b8:c138:94b6::/64 fd77:5880:9632::1
    # eth0 is just a dummy value for now
    usrv6c install --ip [$gw_ip] --user usrv6 --password usrv6 --prefix $prefix --seginterface eth0 --segpath $priv_ip

    /etc/init.d/odhcpd reload # enable prefixfilter
    /etc/init.d/network reload # we have to check clients
}

# We added the preferred liftime option in odhcpd:
# https://git.openwrt.org/?p=project/odhcpd.git;a=commit;h=3bda90079ec5574ef469e2a7804808302f17769d
# With that we can now set the prefferedd liftime to a lower value then the valid_time
# We still need good values that we can use
function configure_odhcpd {
    uci set dhcp.lan.ra_useleasetime=1 # ToDo Make lan configurable
    uci set dhcp.lan.preferred_lifetime='3m' # ToDo Make configurable
    uci set dhcp.lan.leasetime='1h' # ToDo Make configurable

    # Apply settings
    uci commit
    /etc/init.d/odhcpd reload
}

INTERFACE_IP="fd77:5880:9632::1"
new_prefix $INTERFACE_IP

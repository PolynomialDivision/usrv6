#!/bin/sh

. /usr/share/libubox/jshn.sh

# server script

# get own maximal prefix len
function get_max_gw_prefix {
    get_own_gw=$(ip -6 r s default proto static | awk '{print $3}')
    min_prefix_len="129"
    max_ip=""
    for gw_ip in $get_own_gw; do
        tmp=$(echo $gw_ip | tr "/" " ")
        tmp_check=$(echo $tmp | wc -w)
	    # check if correct
        if [ ! "$tmp_check" -eq "2" ]; then
            continue
        fi
        prefix_len=$(echo $tmp | awk '{print $2}')
        if [ "$prefix_len" -lt "$min_prefix_len" ]; then
            min_prefix_len=$prefix_len
        max_ip=$gw_ip 
        fi
    done
    echo $max_ip
}

function get_free_prefix {
    local prefix=$1
    local prefix_size=$2

    max_num=$(owipcalc $prefix howmany $prefix_size)
    tmp_ip=$(owipcalc $prefix next $prefix_size)
    for i in `seq $max_num`; do
        tmp_ip=$(owipcalc $tmp_ip next $prefix_size)
        if [ "$(is_route_installed $tmp_ip)" == "1" ] && [ "$(prefix_in_otherprefixes 000 $tmp_ip)" == "0" ]; then
            echo $tmp_ip
	    return 0
        fi
    done
}

function get_free_random_prefix {
    local prefix=$1
    local prefix_size=$2

    max_num=$(owipcalc $prefix howmany $prefix_size)
    for i in `seq $max_num`; do # some abitary number of allowed cycles
        tmp_ip=$(get_random_prefix $prefix $prefix_size)
        if [ "$(is_route_installed $tmp_ip)" == "1" ] && [ "$(prefix_in_otherprefixes 000 $tmp_ip)" == "0" ]; then
            echo $tmp_ip
	    return 0
        fi
    done
}

function get_random_prefix {
    local prefix=$1
    local prefix_size=$2

    max_num=$(owipcalc $prefix howmany $prefix_size)
    # source: https://unix.stackexchange.com/questions/140750/generate-random-numbers-in-specific-range
    tmp_num=$(awk -v min=1 -v max=$max_num 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
    tmp_prefix=$(owipcalc $prefix next $prefix_size)
    for i in `seq $tmp_num`; do
	    tmp_prefix=$(owipcalc $tmp_prefix next $prefix_size)
    done
    echo $tmp_prefix
}

function is_route_installed {
    local ip=$1

    # ToDo: Find a better solution
    tmp=$(echo $ip | tr "/" " " | awk '{print $1}')
    ip -6 r g $tmp 2> /dev/null
    if [ $? -eq 2 ]; then
	    echo "1"
	    return 0
    fi
    echo "0"
}

function parse_netifd_prefix {
    ubuscall=$(ubus call network.interface.wan6 status)

    json_load "$ubuscall"
    json_get_values prefixes ipv6-prefix
    json_select ipv6-prefix
    json_select 1

    json_get_var address address
    json_get_var mask mask
    json_get_var valid valid
    json_get_var preferred preferred

    echo ${address}/${mask} $valid $preferred
}

function get_free_prefix_json {
    local json_input=$1

    json_load $json_input
    json_get_var random random

    netifdcall=$(parse_netifd_prefix)

    gw=$(echo $netifdcall | awk '{print $1}')
    valid=$(echo $netifdcall | awk '{print $2}')
	preferred=$(echo $netifdcall | awk '{print $3}')

    # hardcode /64 for now
    #gw=$(get_max_gw_prefix)
    prefix=""
    if [ ! $random -eq 0 ] ; then
        prefix=$(get_free_random_prefix $gw 64)
    else
        prefix=$(get_free_prefix $gw 64)
    fi

    # create json
    json_init
    json_add_object $prefix
    json_add_string "prefix" $prefix
    json_add_int "valid" $valid
    json_add_int "preferred" $preferred
    echo $(json_dump)
}

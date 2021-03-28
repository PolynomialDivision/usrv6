#!/bin/sh

. /usr/share/usrv6/babel.sh
. /usr/share/libubox/jshn.sh

function netem_add_mesh_delay {
    local delay=$1

	while uci get prefix-switcher.@general[$j] &> /dev/null ; do
        mesh_interface=$(uci get prefix-switcher.@general[$j].mesh_interface)
        tc qdisc add dev $mesh_interface root handle 1: prio
        tc qdisc add dev $mesh_interface parent 1:3 handle 30: netem delay $delay
        j=$((j+1))
	done
}

function netem_add_mesh_prefx {
    local prefix=$1

	while uci get prefix-switcher.@general[$j] &> /dev/null ; do
        mesh_interface=$(uci get prefix-switcher.@general[$j].mesh_interface)
        tc filter add dev $mesh_interface protocol ip parent 1:0 prio 3 u32 match ip6 src $prefix flowid 1:3
        j=$((j+1))
	done
}

function create_new_prefix_section {
    local p=$1
    local k=$2
    local gw=$3

	uci import prefix-switcher < /etc/config/prefix-switcher
	uci set prefix-switcher.$k=prefix
	uci set prefix-switcher.$k.prefix=$p
    uci set prefix-switcher.$k.gateway=$gw
	uci commit
}

function add_prefix {
    local p=$1
    local k=$2
    local gw=$3

    if ! section=$(uci get prefix-switcher.$k) 2> /dev/null; then
		create_new_prefix_section $p $k $gw
	fi

    uci set prefix-switcher.$k.prefix=$p
    uci set prefix-switcher.$k.gateway=$gw
    uci commit
}

function del_prefix {
    local k=$1

    if ! section=$(uci get prefix-switcher.$k) 2> /dev/null; then
        # empty
		return 0
	fi

    todeletegw=$(uci get prefix-switcher.$k.gateway)
    todeleteprefix=$(uci get prefix-switcher.$k.prefix)
    usrv6c delete --ip [$todeletegw] --user usrv6 --password usrv6 --prefix $todeleteprefix
}

function load_remover {
    local xdp=$1
    local xdp_prog=$2
    local j=0

	while uci get prefix-switcher.@general[$j] &> /dev/null ; do
        mesh_interface=$(uci get prefix-switcher.@general[$j].mesh_interface)
        ip link set dev $mesh_interface xdp off
        xdpload -d $mesh_interface -f $xdp -p $xdp_prog
        j=$((j+1))
	done
}

function apply_remover {
    local prefix=$1
    local key=$2
    local j=0

	while uci get prefix-switcher.@general[$j] &> /dev/null ; do
        mesh_interface=$(uci get prefix-switcher.@general[$j].mesh_interface)
        xdp-srv6-remover -d $mesh_interface -p $prefix -k $key
		j=$((j+1))
	done
}

function new_prefix {
    local key=$1
    local segpath=$2
    local valid_lft=$3
    local preferred_lft=$4
    local max_metric=$5

    # delete old prefix
    del_prefix $key

    gw_ip=$(babeld-utils --gateways ${max_metric} | awk '{print $4}' | cut -f1 -d"/")

    prefix_call=$(usrv6c get_free_prefix --ip [$gw_ip] --user usrv6 --password usrv6 --random 1)    

    prefix=$(echo $prefix_call | awk '{print $1}')
    valid=$(echo $prefix_call | awk '{print $2}')
    preferred=$(echo $prefix_call | awk '{print $3}')

    add_prefix $prefix $key $gw_ip

    echo "Prefix: ${prefix}"
    echo "Valid: ${valid}"
    echo "Preferred: ${preferred}"

    # eth0 is just a dummy value for now
    usrv6c install --ip [$gw_ip] --user usrv6 --password usrv6 --prefix $prefix --seginterface eth0 --segpath $segpath
    assignip=$(owipcalc $prefix add 1)

    # make configurable
    ip -6 a add $assignip dev br-lan valid_lft $valid_lft preferred_lft $preferred_lft

    apply_remover $prefix $key
    xdp-srv6-adder -d $CLIENT_INTERFACE -p $prefix -k $key

    netem_add_mesh_prefx $prefix

    /etc/init.d/odhcpd reload
    /etc/init.d/network reload
}

# make uci config
SLEEP=$(uci get prefix-switcher.@general[0].sleep)
SEGPATH_GW=$(uci get prefix-switcher.@general[0].segpath_gw)
SEGPATH_CLIENT=$(uci get prefix-switcher.@general[0].segpath_client)
VALID_LFT=$(uci get prefix-switcher.@general[0].valid_lft)
PREFERRED_LFT=$(uci get prefix-switcher.@general[0].preferred_lft)
MAX_METRIC=$(uci get prefix-switcher.@general[0].max_metric)
MAX_PREFIXES=$(uci get prefix-switcher.@general[0].max_prefixes)
CLIENT_INTERFACE=$(uci get prefix-switcher.@general[0].client_interface)
XDP_REMOVER=$(uci get prefix-switcher.@general[0].xdp_remover)
XDP_ADDER=$(uci get prefix-switcher.@general[0].xdp_adder)
XDP_PROG_REMOVER=$(uci get prefix-switcher.@general[0].xdp_prog_remover)
XDP_PROG_ADDER=$(uci get prefix-switcher.@general[0].xdp_prog_adder)
LAST_SEGMENT=$(uci get prefix-switcher.@general[0].last_segment)

echo "Running Prefix Switcher With:"
echo "-----------------------------"
echo "sleep: ${SLEEP}"
echo "segpath gateway: ${SEGPATH_GW}"
echo "segpath client: ${SEGPATH_CLIENT}"
echo "valid_lft: ${VALID_LFT}"
echo "preferred_lft: ${PREFERRED_LFT}"
echo "max_metric: ${MAX_METRIC}"
echo "max_prefixes: ${MAX_PREFIXES}"
echo "client_interface: ${CLIENT_INTERFACE}"
echo "xdp_remover: ${XDP_REMOVER}"
echo "xdp_adder: ${XDP_ADDER}"
echo "xdp_prog_remover: ${XDP_PROG_REMOVER}"
echo "xdp_prog_adder: ${XDP_PROG_ADDER}"
echo "last_segment: ${LAST_SEGMENT}"
echo "-----------------------------"

# load and initialze adder
ip link set dev $CLIENT_INTERFACE xdp off
xdpload -d $CLIENT_INTERFACE -f $XDP_ADDER -p $XDP_PROG_ADDER
xdp-srv6-adder -d $CLIENT_INTERFACE -s $SEGPATH_CLIENT -l $LAST_SEGMENT

# load and init remover
load_remover $XDP_REMOVER $XDP_PROG_REMOVER

netem_add_mesh_delay 10ms

i=0
while [ 1 ]
do
    new_prefix $i $SEGPATH_GW $VALID_LFT $PREFERRED_LFT $MAX_METRIC
    sleep $SLEEP
    i=$((i+1))
    if [ $i -ge $MAX_PREFIXES ]; then
        i=0
    fi
done

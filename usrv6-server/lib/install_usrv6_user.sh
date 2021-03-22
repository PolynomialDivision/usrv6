#!/bin/sh

# do not override already existing user!!!
[ "$(uci show rpcd | grep usrv6)" ] && exit 0

# install usrv6 user with standard credentials
# user: usrv6
# password: usrv6
uci add rpcd login 
uci set rpcd.@login[-1].username='usrv6'

password=$(uhttpd -m usrv6)
uci set rpcd.@login[-1].password=$password
uci add_list rpcd.@login[-1].read='usrv6'
uci add_list rpcd.@login[-1].write='usrv6'
uci commit rpcd

# restart rpcd
/etc/init.d/rpcd restart

# restart uhttpd
/etc/init.d/uhttpd restart

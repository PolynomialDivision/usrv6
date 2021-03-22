#!/bin/sh

. /usr/share/libubox/jshn.sh

# "ipv6-prefix": [
# 		{
# 			"address": "2001:xx:xx:xx::",
# 			"mask": 57,
# 			"preferred": 2510,
# 			"valid": 6110,
# 			"class": "wan6",
# 			"assigned": {
# 				"!excluded": {
# 					"address": "2001:xx:xx:xx::",
# 					"mask": 64
# 				},
# 				"mesh_one": {
# 					"address": "2001:xx:c144:xx::",
# 					"mask": 64
# 				}
# 			}
# 		}
# 	],

ubuscall=$(ubus call network.interface.wan6 status)
echo $ubuscall

json_load "$ubuscall"
json_get_values prefixes ipv6-prefix
json_select ipv6-prefix
json_select 1

json_get_var address address
json_get_var mask mask
json_get_var valid valid
json_get_var preferred preferred

echo $address
echo $mask
echo $valid
echo $preferred

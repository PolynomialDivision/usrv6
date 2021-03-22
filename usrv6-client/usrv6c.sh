#!/bin/sh

. /usr/share/usrv6/rpcd_ubus.sh
. /usr/share/usrv6/configure_gateway.sh

CMD=$1
shift

while true ; do
  case "$1" in
    -h|--help)
      echo "help"
      shift 1
      ;;
    -i|--ip)
      IP=$2
      shift 2
      ;;
    --user)
      USER=$2
      shift 2
      ;;
    --password)
      PASSWORD=$2
      shift 2
      ;;
    --prefix)
      PREFIX=$2
      shift 2
      ;;
    --segpath)
      SEGPATH=$2
      shift 2
      ;;
    --seginterface)
      SEGINT=$2
      shift 2
      ;;
    --random)
      RANDOM=$2
      shift 2
      ;;
    '')
      break
      ;;
    *)
      break
      ;;
  esac
done

# get secret
secret=$(init_gateway $IP)

# rpc login
token="$(request_token $IP $USER $PASSWORD)"
if [ $? != 0 ]; then
	echo "failed to register token"
	exit 1
fi

# now call procedure 
case $CMD in
  "install") install_route $token $IP $secret $PREFIX $SEGINT $SEGPATH ;;
  "delete") delete_route $token $IP $secret $PREFIX $SEGINT ;;
  "list_prefixes") list_prefixes $token $IP $secret ;;
  "get_free_prefix") get_free_prefix $token $IP $secret $RANDOM ;;
   *) echo "Usage: usrv6c [ip] [user] [password] [install/delete] [prefix] [interface] [path]" ;;
esac

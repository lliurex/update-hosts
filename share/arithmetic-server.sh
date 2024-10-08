#!/bin/sh

die(){
	echo "ERROR: $1" >&2
	exit 1
}

next_ip(){
	# code from: https://stackoverflow.com/questions/33056385/increment-ip-address-in-a-shell-script
	IP=$1
	IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
	NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
	NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
	echo "$NEXT_IP"
}

get_domain(){
	# get search domain from resolv.conf
	# remove "dot" at beginning of string 
	# this also discards a simple dot as search domain (as some providers do!)
	sed -ne "/^[[:blank:]]*search/{s%^.*[[:blank:]]%%;s%^\.%%;p}" /etc/resolv.conf
}

get_iface_cidr(){
	LANG=C ip addr show "$1" |sed -ne "/[[:blank:]]*inet[[:blank:]]/{s%^.*inet[[:blank:]]%%;s%[[:blank:]].*$%%;p}"
}

get_first_ip(){
	# get first available ip from CIDR
	LANG=C ipcalc "$1" |sed -ne "/^HostMin:/{s%HostMin:[[:blank:]]*%%;s%[[:blank:]].*$%%;p}"
}

increment_ip(){
	NEXT_IP="$1"
	INCREMENT="$2"
	# iterate until reaches increment
	for i in $(seq 1 $INCREMENT); do
    		NEXT_IP=$(next_ip $NEXT_IP)
	done
	echo "$NEXT_IP"
}

# vars
######
# Asume server uses second available IP in subnet, so
# relative increment from first available ip is +1
SRV_IP_INC=1
HOSTS_FILE="/etc/hosts.d/arithmetic-server.hosts"

# get default route iface
GW_IFACE="$(LANG=C ip -4 route list 0/0 | cut -d ' ' -f 5)"

# main
######
# check environment
[ "$GW_IFACE" ] || die "Unable to find network gateway iface"
[ "$IFACE" ] || die "Undefined '$IFACE' environment var. May be not running under networkd-dispatcher?"

# correct interface up?
[ "$GW_IFACE" = "$IFACE" ] || exit 0

# recopile necessary data

# get DNS search domain from resolv.conf (if any)
SEARCH_DOMAIN="$(get_domain)"

# get ip/mask in CIDR notation
CIDR="$(get_iface_cidr "$GW_IFACE")"
[ "$CIDR" ] || die "Unable to retrieve IP address from $GW_IFACE"

# get first available ip in subnet from CIDR
FIRST_IP="$(get_first_ip "$CIDR")"
[ "$FIRST_IP" ] || die "Unable to determine first IP in subnet from $CIDR"

# add the required increment
SRV_IP="$(increment_ip "$FIRST_IP" "$SRV_IP_INC")"


# generate .hosts file

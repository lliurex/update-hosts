#!/bin/sh

###############
# global vars #
###############

# Asume server uses 5th available IP in subnet
SRV_IP_NUMBER=5

# hosts file to write 
#HOSTS_FILE="/etc/hosts.d/arithmetic-server.hosts"
HOSTS_FILE="/tmp/arithmetic-server.hosts"

# List of servers aliases to write (comma separated)
SRV_ALIASES="server,srv,fs"

# get default route iface
GW_IFACE="$(LANG=C ip -4 route list 0/0 | cut -d ' ' -f 5)"

#############
# functions #
#############
main(){
	# main
	######
	# check environment
	[ "$GW_IFACE" ] || die "Unable to find network gateway iface"
	[ "$IFACE" ] || die "Undefined 'IFACE' environment var. May be not running under networkd-dispatcher?"

	# correct interface up?
	[ "$GW_IFACE" = "$IFACE" ] || exit 0

	# recopile necessary data

	# get DNS search domain from resolv.conf (if any)
	SEARCH_DOMAIN="$(get_domain)"
	[ -z "$SEARCH_DOMAIN" ] || SEARCH_DOMAIN=":${SEARCH_DOMAIN}"

	# get ip/mask in CIDR notation
	CIDR="$(get_iface_cidr "$GW_IFACE")"
	[ "$CIDR" ] || die "Unable to retrieve IP address from $GW_IFACE"

	# get SRV_IP_NUMBER available ip in subnet
	SRV_IP="$(get_srv_ip "$CIDR" "$SRV_IP_NUMBER")"

	# generate .hosts file
	echo "# BEGIN arithmetic-server IPs" > "$HOSTS_FILE"
	generate_hosts "${SRV_IP}:${SRV_ALIASES}${SEARCH_DOMAIN}" >> "$HOSTS_FILE"
	echo "# END arithmetic-server IPs" >> "$HOSTS_FILE"

	# update /etc/hosts
	# update-hosts
}

die(){
	echo "ERROR: $1" >&2
	exit 1
}

get_domain(){
	# get search domain from resolv.conf
	# remove "dot" at beginning of string 
	# this also discards a simple dot as search domain (as some providers do!)
	sed -ne "/^[[:blank:]]*search/{s%^.*[[:blank:]]%%;s%^\.%%;p}" /etc/resolv.conf
}

get_iface_cidr(){
	# prints IP/NETMASK from specified interface
	# parameters:
	IFACE_NAME="$1"

	LANG=C ip addr show "$IFACE_NAME" |sed -ne "/[[:blank:]]*inet[[:blank:]]/{s%^.*inet[[:blank:]]%%;s%[[:blank:]].*$%%;p}"
}

bin2byte(){
	# convert binary byte to decimal format
	# parameters:
	BBYTE="$1"
	printf "$(echo "obase=10;ibase=2;$BBYTE" |bc)"
}

byte2bin(){
	# convert decimal byte to binary and pad with 8 0's
	# parameters:
	DBYTE="$1"
	printf "%08d" "$(echo "obase=2;$DBYTE" |bc)"
}

get_firstbits(){
	# extract first n bits from a 32 bits binary number
	# parameters:
	BNUM="$1"	# -> 32 bits binary number
	n=$2		# -> number of bits

	N=$((32 - $n))
	echo "$BNUM" |sed -e "s%[[:digit:]]\{$N\}$%%"
}

get_lastbits(){
	# extract last n bits from a 32 bits binary number
	# parameters:
	BNUM="$1"	# -> 32 bits binary number
	n=$2		# -> number of bits

	N=$((32 - $n))
	echo "$BNUM" |sed -e "s%^[[:digit:]]\{$N\}%%"
}

get_byte(){
	# get nth byte of a 32 bits binary number (from left to right, 1 is the first byte)
	# parameters:
	BNUM="$1"	# -> 32 bits binary number
	n=$2		# -> byte number
	if [ $n -gt 1 ] ; then
		# remove first (n-1)*8 bits
		N=$(( ($n-1)*8))
		BNUM="$(echo "$BNUM" |sed -e "s%^[[:digit:]]\{$N\}%%")"
	fi
	if [ $n -lt 4 ] ; then
		# remove last (4-n)*8 bits
		N=$(( (4-$n)*8 ))
		BNUM="$(echo "$BNUM" |sed -e "s%[[:digit:]]\{$N\}$%%")"
	fi
	echo "$BNUM"
}

ip2bin(){
	# convert decimal dot separated IP address to 32 bits binary format
	# parameters:
	DOT_IP="$1"
	for b in $(echo "$DOT_IP" |tr "." " ") ; do
		byte2bin "$b"
	done
}

bin2ip(){
	# convert 32 bits binary IP to decimal dot separated form
	# parameters:
	BIN_IP="$1"
	DOT_IP=""
	n=1
	while [ $n -le 4 ] ; do
		BIN_BYTE="$(get_byte "$BIN_IP" $n)"
		DOT_IP="${DOT_IP}.$(bin2byte "$BIN_BYTE")"
		n=$(($n + 1))
	done
	echo "${DOT_IP#.}"
}


get_srv_ip(){
	# receives a CIDR ip/mask parameter of any host in subnet
	# and returns the nth ip in the related subnet
	# parameters:
	CIDR="$1" 	# IP/MASK
	IP_NUMBER="$2"  # -> subnet IP position
	
	# separate IP / MASK & calculate HOST_NUMBITS
	IP="${CIDR%/*}"
	MASK="${CIDR#*/}"
	HOST_NUMBITS=$((32 - $MASK))

	# verify subnet max number of hosts
	MAX_HOST="$(echo "2^${HOST_NUMBITS} - 1" |bc)"
	[ $IP_NUMBER -le $MAX_HOST ] || die "Insufficient number of hosts in subnet"

	# convert IP to binary
	BIN_IP="$(ip2bin "$IP")"

	# preserve subnet part in binary form
	BIN_NET="$(get_firstbits "$BIN_IP" $MASK)"

	# convert host number to binary and pad with required 0's 
	BIN_HOST_RAW="$(echo "obase=2;$IP_NUMBER" |bc)"
	BIN_HOST="$(printf "%0${HOST_NUMBITS}d" "$BIN_HOST_RAW")"

	# concatenate to get binary server IP and convert to dot separated format
	BIN_SRV_IP="${BIN_NET}${BIN_HOST}"
	bin2ip "$BIN_SRV_IP"
}

print_host(){
	# prints single line in etc/hosts format for an IP and hostname
	# parameters:
	IP="$1"
	HOST="$2"
	printf "${IP}\t${H}\n"
}

generate_hosts(){
	# prints list of pairs "IP hostname" in etc/hosts format
	# the function can receive many parameters in the form:
	# IP:alias_list_comma_separated[:optional_domain_name_list]
	while [ "$1" ] ; do
		# extract parameters
		DOMAIN_LIST=""
		IP="${1%%:*}"
		ALIAS_LIST="${1#*:}"
		if echo "$ALIAS" | grep -q ":" ; then
			DOMAIN_LIST="${ALIAS_LIST#*:}"
			ALIAS_LIST="${ALIAS_LIST%:*}"
		fi
		for H in $(echo "$ALIAS_LIST" | tr "," " ") ; do
			print_host "$IP" "$H"
			for D in $(echo "$DOMAIN_LIST" | tr "," " ") ; do
				print_host "$IP" "${H}.${D}"
			done
		done
		shift
	done
}

# main program
main
exit 0


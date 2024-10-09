#!/bin/sh

###############
# global vars #
###############

# Asume server uses 5th available IP in subnet
SRV_IP_NUMBER=5

# hosts file to write 
HOSTS_FILE="/etc/hosts.d/arithmetic-server.hosts"
# Testing .... HOSTS_FILE="/tmp/arithmetic-server.hosts"

# List of servers aliases to write (comma separated)
SRV_ALIASES="server,srv,fs"

# get default route iface
GW_IFACE="$(LANG=C ip -4 route list 0/0 | cut -d ' ' -f 5)"

# load common functions
. /usr/share/update-hosts/update-hosts-common


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
	update-hosts
}

################
# main program #
################
main
exit 0


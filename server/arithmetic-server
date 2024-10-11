#!/bin/sh

###############
# global vars #
###############

# Asume server uses 5th available IP in subnet
SRV_IP_NUMBER=5

# get default route iface
GW_IFACE="$(LANG=C ip -4 route list 0/0 | cut -d ' ' -f 5)"

# load common functions
. /usr/share/update-hosts/update-hosts-common

# name of virtual iface to assign when
# GW_IFACE brings up
SRV_VIRTUAL_IFACE=""


#############
# functions #
#############
main(){
	# main
	######
	# check environment
	[ "$SRV_VIRTUAL_IFACE" ] || die "Undefined SRV_VIRTUAL_IFACE variable"

	get_interface_list | grep -qFX "$SRV_VIRTUAL_IFACE" || die "Invalid variable SRV_VIRTUAL_IFACE=$SRV_VIRTUAL_IFACE"

	[ "$GW_IFACE" ] || die "Unable to find network gateway iface"
	[ "$IFACE" ] || die "Undefined 'IFACE' environment var. May be not running under networkd-dispatcher?"

	# correct interface up?
	[ "$GW_IFACE" = "$IFACE" ] || exit 0

	# recopile necessary data

	# get ip/mask in CIDR notation
	CIDR="$(get_iface_cidr "$GW_IFACE")"
	[ "$CIDR" ] || die "Unable to retrieve IP address from $GW_IFACE"

	# get SRV_IP_NUMBER available ip in subnet
	SRV_CIDR="$(get_srv_cidr "$CIDR" "$SRV_IP_NUMBER")"

	# assign SRV_IP to virtual interface
	# TODO: test this code !!!!!!!
	ip link set dev "$SRV_VIRTUAL_IFACE" down
	ip addr add "$SRV_CIDR" dev "$SRV_VIRTUAL_IFACE"
	ip link set dev "$SRV_VIRTUAL_IFACE" up
}

################
# main program #
################
main
exit 0


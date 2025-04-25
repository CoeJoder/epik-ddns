#!/bin/bash

# TODO Epik API access requires a whitelisted IP address, so this script should
# TODO be rewritten with a client-server architecture, with DDNS updates being
# TODO pushed from a static IP proxy server.

# epik-ddns.sh
#
# Simple DDNS script to update Epik DNS records.
#
# See: https://docs-userapi.epik.com/v2/#/Ddns/setDdns
# See: https://registrar.epik.com/account/api-settings/
#
# The following must be defined in `~/.epik-ddns/properties.sh`
#   EPIK_SIGNATURE - domain-specific API key
#   EPIK_HOSTNAME  - subdomain or root, e.g. @
#
# `wget` is required.
#
# Author: CoeJoder

# required to exist
EPIK_DDNS_PROPERTIES_SH="$HOME/.epik-ddns/properties.sh"

# OpenWRT network functions; optional to exist
# if not present, external service is used to determine WAN IP
OPENWRT_NETWORK_SH='/lib/functions/network.sh'
EXTERNAL_IP_SERVICE='https://ipinfo.io/ip'

# used to validate IPv4 addresses
# source: https://unix.stackexchange.com/a/111852
IP_OCTET='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
IP_REGEX="^$IP_OCTET\.$IP_OCTET\.$IP_OCTET\.$IP_OCTET\$"

# ensure `wget` is available
if ! type -P wget &>/dev/null; then
	echo 'wget not found' >&2
	exit 1
fi

# read & validate properties file
if [[ ! -f $EPIK_DDNS_PROPERTIES_SH ]]; then
	echo "file not found: ${EPIK_DDNS_PROPERTIES_SH}" >&2
	exit 1
fi
source "$EPIK_DDNS_PROPERTIES_SH"
if [[ -z $EPIK_SIGNATURE ]]; then
	echo "EPIK_SIGNATURE not set" >&2
	exit 1
fi
if [[ -z $EPIK_HOSTNAME ]]; then
	echo "EPIK_HOSTNAME not set" >&2
	exit 1
fi

# discover WAN IP address
if [[ -f $OPENWRT_NETWORK_SH ]]; then
	source "$OPENWRT_NETWORK_SH"
	network_get_ipaddr _WAN_IP wan
fi
if [[ -z $_WAN_IP ]]; then
	_WAN_IP="$(wget -qO- "$EXTERNAL_IP_SERVICE")"
fi
if [[ -z $_WAN_IP ]]; then
	echo 'WAN IP discovery failed' >&2
	exit 1
fi
if [[ ! $_WAN_IP =~ $IP_REGEX ]]; then
	echo "WAN IP invalid: $_WAN_IP" >&2
	exit 1
fi

# TODO compare current IP to previous and post update only if changed

wget -O- \
	--header='accept: application/json' \
	--header='Content-Type: application/json' \
	--post-data="{
	\"hostname\": \"$EPIK_HOSTNAME\",
	\"value\": \"$_WAN_IP\"
}" "https://usersapiv2.epik.com/v2/ddns/set-ddns?SIGNATURE=$EPIK_SIGNATURE"

# TODO check if update was successful

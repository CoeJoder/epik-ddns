#!/bin/bash

# epik-ddns.sh
# Author: CoeJoder [github.com]
#
# A simple DDNS script to update Epik DNS records.
#
# Requires: bash, curl, jq
#
# The following are required to be defined in ~/.epik-ddns/properties.sh:
#   EPIK_SIGNATURE - domain-specific API key
#   EPIK_HOSTNAME  - subdomain or root, e.g. @
#
# Exit Statuses:
#   0: successful invocation
#   1: fatal error
#   2: invocation skipped (e.g., due to caching)
#
# Epik API docs and portal:
# https://docs-userapi.epik.com/v2/#/Ddns/setDdns
#
# Epik API account settings:
# https://registrar.epik.com/account/api-settings/
#
# Thanks to Nazar78 [TeaNazaR.com] for his `godaddy-ddns` script,
# on which this script is roughly based.

# contains script vars; required to exist
EPIK_DDNS_PROPERTIES_SH="$HOME/.epik-ddns/properties.sh"

# OpenWRT network functions; optional to exist
# if not present, external service is used to determine WAN IP
OPENWRT_NETWORK_SH='/lib/functions/network.sh'
EXTERNAL_IP_SERVICE='https://ipinfo.io/ip'

# cache for last-known WAN IP and timestamp
EPIK_DDNS_CACHE="$HOME/.epik-ddns/last_update_cache.txt"

# used to validate IPv4 addresses
# source: https://unix.stackexchange.com/a/111852
IP_OCTET='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
IP_REGEX="^$IP_OCTET\.$IP_OCTET\.$IP_OCTET\.$IP_OCTET\$"

# used to validate timestamps
UINT_REGEX='^[[:digit:]]+$'
ONE_DAY_IN_SECONDS="$((24 * 60 * 60))"

# ensure availability of dependencies
for _command in curl jq; do
	if ! type -P "$_command" &>/dev/null; then
		echo "\`$_command\` not found" >&2
		exit 1
	fi
done

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
	network_get_ipaddr _wan_ip wan
fi
if [[ -z $_wan_ip ]]; then
	_wan_ip="$(curl -kLs "$EXTERNAL_IP_SERVICE")"
fi
if [[ -z $_wan_ip ]]; then
	echo 'WAN IP discovery failed' >&2
	exit 1
fi
if [[ ! $_wan_ip =~ $IP_REGEX ]]; then
	echo "WAN IP invalid: $_wan_ip" >&2
	exit 1
fi

_current_time="$(date +%s)"

function postUpdate() {
	local _response _response_errors
	_response="$(curl -kLsX 'POST' "https://usersapiv2.epik.com/v2/ddns/set-ddns?SIGNATURE=$EPIK_SIGNATURE" \
		-H 'Accept: application/json' \
		-H 'Content-Type: application/json' \
		-d "{
			\"hostname\": \"$EPIK_HOSTNAME\",
			\"value\": \"$_wan_ip\"
		}")"
	if [[ $? -ne 0 ]]; then
		echo "curl failure: $_response" >&2
		exit 1
	fi

	# update WAN IP cache if API call was successful
	_response_errors="$(jq -r '.errors[0] | .description' <<<"$_response")"
	if [[ $_response_errors != null ]]; then
		echo "$_response_errors" >&2
		exit 1
	fi
	if ! printf '%s %s' "$_wan_ip" "$_current_time" >"$EPIK_DDNS_CACHE"; then
		echo 'failed to write WAN IP cache' >&2
		exit 1
	fi
	exit 0
}

# POST the update iff:
#  - WAN IP cache is not found/readable, or
#  - current WAN IP doesn't match the cached one, or
#  - it's been more than 24-hours since last update
if [[ ! -r $EPIK_DDNS_CACHE ]]; then
	postUpdate
else
	read _wan_ip_cached _last_update_timestamp <"$EPIK_DDNS_CACHE"
	if [[ $_wan_ip != $_wan_ip_cached ]]; then
		postUpdate
	elif [[ $_last_update_timestamp =~ $UINT_REGEX ]]; then
		_time_since_last_update="$((_current_time - _last_update_timestamp))"
		if ((_time_since_last_update > $ONE_DAY_IN_SECONDS)); then
			postUpdate
		fi
	fi
fi
exit 2

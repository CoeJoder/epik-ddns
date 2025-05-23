# epik-ddns
A simple DDNS bash script to update [Epik](https://www.epik.com/) DNS records.

Suggested to be run periodically as a cron job, this script calls Epik's [`set-ddns`](https://docs-userapi.epik.com/v2/#/Ddns/setDdns) API method whenever a change to the host's external IP address is detected.  As Epik has no `read-ddns` method available sans IP-whitelisting, the call is always made on the first run, and at least once every 24-hours.

When run on [OpenWRT](https://openwrt.org/) router firmware, an internal library function is called which returns the device's WAN IP.  Otherwise, an external service is used to fetch the host's external IP: https://ipinfo.io/ip

## Requirements
`bash`, `curl`, `jq`

The following variables are required to be set in: `~/.epik-ddns/properties.sh`
```
EPIK_SIGNATURE - domain-specific API key
EPIK_HOSTNAME  - subdomain or root, e.g. @
```
A cache file is created by the script here: `~/.epik-ddns/last_update_cache.txt`

## Exit Statuses
```
0: call successful
1: fatal error
2: call skipped (e.g., due to caching)
```
## Resources

Epik API docs and portal<br/>
https://docs-userapi.epik.com/v2/#/Ddns/setDdns

Epik API account settings<br/>
https://registrar.epik.com/account/api-settings/

## Credits
Thanks to Nazar78 @ TeaNazaR.com for his `godaddy-ddns` script, on which this script is roughly based.

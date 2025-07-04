# epik-ddns
A simple DDNS bash script to update [Epik](https://www.epik.com/) DNS records.

Suggested to be run periodically as a cron job, this script calls Epik's [`set-ddns`](https://docs-userapi.epik.com/v2/#/Ddns/setDdns) API method whenever a change to the host's external IP address is detected.

### Discovering the external IP address
When run on [OpenWRT](https://openwrt.org/) router firmware, an internal library function is called which returns the device's WAN IP.  Otherwise, an external service is used: https://ipinfo.io/ip

## Requirements

### Dependencies
`bash`, `curl`, `jq`, `grep`

***Note**: `curl` must support `--fail-with-body` option (e.g., curl **v7.76.0+**)*

### Configs

The following variables are required to be set in: `~/.epik-ddns/properties.sh`
```
EPIK_SIGNATURE - domain-specific API key
EPIK_HOSTNAME  - subdomain or root, e.g. @
```
A cache file is generated by the script here: `~/.epik-ddns/last_update_cache.txt`

## Exit Status
```
0: call successful
1: fatal error
2: call skipped (e.g., due to caching)
```

## Deployment
*Example: Deploy to OpenWRT via SSH, setting the DDNS update script to run every 10 minutes.*
```bash
# create deployment folder
mkdir .epik-ddns/

# checkout project
git clone https://github.com/CoeJoder/epik-ddns.git

# prepare deployment
cp ./epik-ddns/epik-ddns.sh ./.epik-ddns/
cp ./epik-ddns/properties.template.sh ./.epik-ddns/properties.sh

# set the API variables
nano ./.epik-ddns/properties.sh
# save and quit nano by pressing: ctrl+s, ctrl+x

# deploy to OpenWRT
scp -rO ./.epik-ddns/ root@192.168.1.1:

# login to OpenWRT
ssh root@192.168.1.1

# install script dependencies
opkg update
opkg install bash curl jq grep

# edit the crontab
crontab -e

# add the following line:
*/10 * * * * /root/.epik-ddns/epik-ddns.sh
# save and quit the vi editor by pressing (minus quotes): ":wq" <Enter>

# apply changes
service cron restart

# logout
exit

# cleanup
rm -rf ./epik-ddns/
rm -rf ./.epik-ddns/
```

## Resources

Epik API docs and portal<br/>
https://docs-userapi.epik.com/v2/#/Ddns/setDdns

Epik API account settings<br/>
https://registrar.epik.com/account/api-settings/

## Credits
Thanks to Nazar78 @ TeaNazaR.com for his `godaddy-ddns` script, on which this script is roughly based.

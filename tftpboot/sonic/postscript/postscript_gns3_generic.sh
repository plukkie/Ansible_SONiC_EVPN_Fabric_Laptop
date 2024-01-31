#!/bin/bash

ZTD_SERVER_IP="10.10.10.201"
OOB_INT=eth0
ADDON_SCRIPTS_PATH=/tftpboot/sonic/postscript_addons/
DHCPCLIENTCONF=/etc/dhcp/dhclient.conf
SAVE_CONFIG_FILE=save_config.sh
ADMIN_HOME=/home/admin/
CGI=/cgi-bin/callback.sh
APP=http://
CRONLINE=${ADMIN_HOME}${SAVE_CONFIG_FILE}
CRONROOT=/var/spool/cron/crontabs/root
HASHALG=sha256sum
STOREDHASHFILE=/tmp/config_db.json.${HASHALG}
STAG=`sudo dmidecode -s system-serial-number`
USER_NAME="admin"
PASSWORDLIST=( "YourPaSsWoRd" "admin123" )

function change_password(){
  ## Set the password
  echo -e "admin123\nadmin123" | sudo passwd admin
}

function set_hostname(){

  if [[ -z "$STAG" ]] || [[ "${STAG,,}" == "not specified" ]]
    ## No STAG found, must be a GNS3 VM
    then
      NAME="STAG-000000"
    else
      NAME="STAG-$STAG"
  fi     

  ## set hostname via localhost REST call
  echo "Set system hostname to: ${NAME}..." && sleep 2
  for ITEM in ${PASSWORDLIST[@]}; do
    curl -s -k -X PATCH "https://localhost/restconf/data/openconfig-system:system/config/hostname" -H "accept: */*" -H "Content-Type: application/yang-data+json" -u ${USER_NAME}:${ITEM} -d "{\"openconfig-system:hostname\":\"$NAME\"}"
  done

  ## Add dhcp client identifier to set STAG
  ## This will be used in DHCP requests
  ## The DHCP Server can use this option to glue it in HOST declarations
  sed -i '/^send dhcp-client-identifier/ s/./#&/' $DHCPCLIENTCONF
  echo "send dhcp-client-identifier \"${NAME}\";" >> $DHCPCLIENTCONF
}


## Set hostname
set_hostname

## Create dummy hashfile. This ensures first save_config will upload to tftp
echo "123456789" > $STOREDHASHFILE

# Request callback script at http server (cgi-script)
# This creates a file with name <ip-address> amd hostname in it on the server end
#/usr/bin/curl -s ${APP}${ZTD_SERVER_IP}${CGI}

#sleep 2

# get save_config.sh addon script and add to crontab
echo "Get save_config script from server..." && sleep 2
sudo /usr/bin/curl --interface $OOB_INT -s ${APP}${ZTD_SERVER_IP}${ADDON_SCRIPTS_PATH}${SAVE_CONFIG_FILE} -o ${ADMIN_HOME}${SAVE_CONFIG_FILE}
sudo chmod 755 ${ADMIN_HOME}${SAVE_CONFIG_FILE}
sudo chown admin:admin ${ADMIN_HOME}${SAVE_CONFIG_FILE}

# Check if save_config script present in crontab
if [[ ! -f "${CRONROOT}" ]]; then touch ${CRONROOT}; fi

if ! grep -q "${CRONLINE}" "${CRONROOT}"; then
   echo "Add crontab for save_config script..." && sleep 2
   echo "* * * * * sudo $CRONLINE" >> ${CRONROOT}
fi

## Renew DHCP lease so that correct dhcp-client-identifier is send
echo "Renew DHCP lease..." && sleep 2
sudo dhclient -r && sudo dhclient $OOB_INT

# Save config permanent
echo "Save running config to startup config..." && sleep 2
sudo config save -y

# Change admin pwd
echo "Change password for user admin..." && sleep 2
change_password



#!/bin/bash

ZTD_SERVER_IP="192.168.1.1"
OOB_INT=eth0
ADDON_SCRIPTS_PATH=/tftpboot/sonic/postscript_addons/
SAVE_CONFIG_FILE=save_config.sh
ADMIN_HOME=/home/admin/
CGI=/cgi-bin/callback.sh
APP=http://
CRONLINE=${ADMIN_HOME}${SAVE_CONFIG_FILE}
CRONROOT=/var/spool/cron/crontabs/root
HASHALG=sha256sum
STOREDHASHFILE=/tmp/config_db.json.${HASHALG}

function change_password(){
  ## Set the password
  echo -e "admin123\nadmin123" | sudo passwd admin
}

## Create dummy hashfile. This ensures first save_config will upload to tftp
echo "123456789" > $STOREDHASHFILE

# Request callback script at http server (cgi-script)
# This creates a file with name <ip-address> amd hostname in it on the server end
#/usr/bin/curl -s ${APP}${ZTD_SERVER_IP}${CGI}

#sleep 2

# get save_config.sh addon script and add to crontab
echo "Get save_config script from server..." && sleep 2 
sudo /usr/bin/curl --interface $OOB_INT -s ${APP}${ZTD_SERVER_IP}${ADDON_SCRIPTS_PATH}${SAVE_CONFIG_FILE} -o ${ADMIN_HOME}${SAVE_CONFIG_FILE}
sudo chmod a+x ${ADMIN_HOME}${SAVE_CONFIG_FILE}

# Check if save_config script present in crontab
if [[ ! -f "${CRONROOT}" ]]; then touch ${CRONROOT}; fi

if ! grep -q "${CRONLINE}" "${CRONROOT}"; then
   echo "Add crontab for save_config script..." && sleep 2
   echo "* * * * * sudo $CRONLINE" >> ${CRONROOT}
fi

# Save config permanent
echo "Save running config to startup config..." && sleep 2
sudo config save -y

# Change admin pwd
echo "Change password for user admin..." && sleep 2
change_password


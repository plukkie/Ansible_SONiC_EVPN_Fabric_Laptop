#!/bin/bash

## SET HERE MANAGEMENT NET, MASK AND TFTP SERVER
MGTPREFIX="192.168.1."
MGTNET=0
MGTMASK="/24"
TFTPSERVER=${MGTPREFIX}1
STAGING_HOSTNAME="SONiC-ZTP-STAGED"
################################################

OOB_INT=eth0
LOCALCONFIGFILE=/etc/sonic/config_db.json
HASHALG=sha256sum
STOREDHASHFILE=/tmp/config_db.json.${HASHALG}
UPLOADPATH=/sonic/config/
HOSTNAME=`hostname`
FILESUFFIX="_config_gns3.json"
MGTINT=`netstat -rn | grep -i "${MGTPREFIX}" | awk '{print $NF}'`
MGTINTCOUNT=`echo ${MGTINT} | wc -l`

echo "MGTINT = " $MGTINT
echo "Interface count = " $MGTINTCOUNT

## Need to find the management interface that is used
if [ "${MGTINT}" == "" ] || [ "${MGTINTCOUNT}" -gt "1" ]
	then
	  echo "Searching through all VRFs..."
	  ## Mgt not found in default route table.
	  ## Seems a VRF is used
	  VRF_TABLE_IDS=`ip vrf show | egrep -i "vrf|mgmt" | awk '{print $2}'`
	  ## Loop through all Vrf route tables and find management subnet and interface
	  for VRF_ID in ${VRF_TABLE_IDS}; do
	    MGTINT=`ip route show table ${VRF_ID} ${MGTPREFIX}${MGTNET}${MGTMASK} | awk '{print $3}'`
	    if [ "${MGTINT}" != "" ] ## Management is found
	      then
		MGTIP=`ip route show table ${VRF_ID} ${MGTPREFIX}${MGTNET}${MGTMASK} | awk '{print $NF}'`
		break
	    fi
	  done
	else
          ## Mgt interface was found, find ip-address
	  MGTIP=`ip route show dev ${MGTINT} | awk '{print $NF}'`
	  echo "Management interface = ${MGTINT}"
          echo "Management IP = ${MGTIP}"
fi

MGMTMAC=`ip link show up ${MGTINT} | grep -i "link/ether" | awk {'print $2'}`

if [ "${HOSTNAME}" == "${STAGING_HOSTNAME}" ]
	## No custom hostname configured yet, extend name with mac address
	then
	  SAVEDCONFIGFILE=${HOSTNAME}"__${MGTIP}__${MGTINT}__${MGMTMAC}_"${FILESUFFIX}
	## Custom hostname is configured, do not use mac address in saved configfile
	else
	  SAVEDCONFIGFILE=${HOSTNAME}"__${MGTIP}__${MGTINT}_"${FILESUFFIX}
fi

if [ ! -f "${STOREDHASHFILE}" ]
   then
      sudo ${HASHALG} ${LOCALCONFIGFILE} | awk '{print $1'} > ${STOREDHASHFILE}
      uploadconfig=True
fi

OLDHASH=`cat ${STOREDHASHFILE}`
NEWHASH=`sudo ${HASHALG} ${LOCALCONFIGFILE} | awk '{print $1'}`

if [ "${NEWHASH}" != "${OLDHASH}" ] || [ "${uploadconfig}" == "True" ]
   then
      echo "Config has changed, need to upload new config to server."
      if curl --interface ${MGTINT} -T ${LOCALCONFIGFILE} tftp://${TFTPSERVER}${UPLOADPATH}${SAVEDCONFIGFILE}
	 then 
            echo ${NEWHASH} > ${STOREDHASHFILE}
	    echo "Succesfull upload"
	 else
            echo "Error uploading file"
      fi
   else
      echo "Config has not changed. Do nothing till next check."
fi


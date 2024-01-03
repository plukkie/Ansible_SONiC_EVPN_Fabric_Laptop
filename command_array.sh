#!/bin/bash

## Set all IPs that commands will be executed on
## Set all commands in array that need to be executed
## Set username/password
## Commands will be executed via utility 'sshpass'

username=admin
password=admin123

sshpassstring="sshpass -p $password"
sshstring="ssh -t -o StrictHostKeyChecking=no"

switch_ips=( "192.168.1.252"
	     "192.168.1.101" 
	     "192.168.1.102" 
	     "192.168.1.201" 
	     "192.168.1.202" 
	     "192.168.1.105" 
	     "192.168.1.106" 
	     "192.168.1.111" 
	     "192.168.1.112" 
	     "192.168.1.141" 
	     "192.168.1.142" 
	     "192.168.1.254" 
	     "192.168.1.11" 
	     "192.168.1.12" 
	     "192.168.1.253" 
	     "192.168.1.107" 
	     "192.168.1.108" 
	     "192.168.1.207" 
	     "192.168.1.208" 
	     "192.168.1.109" 
	     "192.168.1.110" 
	     "192.168.1.117" 
	     "192.168.1.118" 
	     "192.168.1.171" 
	     "192.168.1.17" 
	     "192.168.1.18" 
	     "192.168.1.251" )

commands=( "scp -o StrictHostKeyChecking=no /tftpboot/sonic/postscript_addons/save_config.sh" 
	   "sudo rm -f /tmp/config_db.json.sha256sum" )

for ip in "${switch_ips[@]}"
do
  echo "Test if host $ip is pingable..."
  ping -c 5 -i 0.5 -W 1 -q $ip; result=$?
  if [ $result -eq 0 ];
    ## Host IS reachable
    then
      echo -e "\nSUCCESS...\n"
      for cli_cmd in "${commands[@]}"
      do
        echo "execute cmd on ${ip} :"
        echo " - ${cli_cmd} ${username}@${ip}:"
        sleep 2
        if [[ $cli_cmd == *"scp"* ]];
          then
            `$sshpassstring ${cli_cmd} ${username}@${ip}:`
	  else
	    `$sshpassstring $sshstring ${username}@${ip} $cli_cmd`
        fi
      done
    else
      ## Host is NOT reachable
      echo "$ip is unreachable. Skipping..."
      sleep 2
  fi
  echo -e "\n========================================="
done


#!/bin/bash
# This scripts checks the status of the experiment machine,
# and reboots it if it has crashed. 
# The results are logged to a file.

crash_msg="Rebooting machine because it crashed"
uptime="0000:00:00"

NODE="$1"

if [ "$NODE" == "" ]; then
	echo "Usage: $0 NODE"
	exit 2
fi

while [ 1 ]; do
	stat=`./stat.sh $NODE`
       	status=`echo -n $stat | jq .machine_status`
	if [[ "$status" == *"Crashed"* ]]; then
		echo "[$(date)] $crash_msg, last uptime $uptime" >> reboot.log
	       ./reboot.sh
	fi	       
	uptime=`echo -n $stat | jq .uptime`
	sleep 5;
done

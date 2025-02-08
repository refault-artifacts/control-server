#!/bin/bash
# This performs a reboot of the experiment machine

NODE="$1"

if [ "$NODE" == "" ]; then
	echo "Usage: $0 NODE"
	exit 2
fi

curl -sS http://inj-ctrl-$NODE.localdomain/pwr_btn_long > /dev/null || exit -1 
sleep 6 # this depends on the node
curl -sS http://inj-ctrl-$NODE.localdomain/pwr_btn_short > /dev/null || exit -1
exit 0

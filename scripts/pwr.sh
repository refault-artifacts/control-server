#!/bin/bash
# This calls the /pwr_btn_short resource which executes
# a short power button press on the experiment machine.

NODE="$1"

if [ "$NODE" == "" ]; then
	echo "Usage: $0 NODE"
	exit 2
fi

curl -sS http://inj-ctrl-$NODE.localdomain/pwr_btn_short >> /dev/null

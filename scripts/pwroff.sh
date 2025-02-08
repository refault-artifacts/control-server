#!/bin/bash

NODE="$1"

if [ "$NODE" == "" ]; then
	echo "Usage: $0 NODE"
	exit 2
fi

curl -sS http://inj-ctrl-$NODE.localdomain/pwr_btn_long | jq >> /dev/null

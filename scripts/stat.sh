#!/bin/bash
# This calls the /status resource of the injection controller.

NODE="$1"

if [ "$NODE" == "" ]; then
	echo "Usage: $0 NODE"
	exit 2
fi
curl -sS http://inj-ctrl-$NODE.localdomain/status | jq

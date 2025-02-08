#!/bin/bash

DATAPATH=$1

if [ "$1" == "" ]; then
	echo "Usage: $0 DATAPATH"
	exit -1
fi

declare -A FLIPS
declare -A COUNTS

FILECOUNT=0
for FILE in $(ls $DATAPATH); do
	HC=$(grep -o "HAMMER_COUNT=[0-9]*" $DATAPATH/$FILE | cut -d= -f2)
	FLIP=$(grep -o "FOUND [1-9][0-9]*" $DATAPATH/$FILE | cut -d' ' -f2)
	if [ ! "$HC" == "" ]; then
		COUNTS["$HC"]=$((${COUNTS["$HC"]}+1))
		if [ ! "$FLIP" == "" ]; then
			FLIPS["$HC"]=$((${FLIPS["$HC"]}+$FLIP))
		fi
	fi
	FILECOUNT=$((FILECOUNT+1))
done

for HC in ${!FLIPS[@]}; do
	RESULTS+=$(echo "$HC\t${FLIPS["$HC"]}\t${COUNTS["$HC"]}\n")
done
echo -e "Hammer\tNo. of\tNo. of"
echo -e "count\tflips\truns"
echo    "---------------------------"
echo -e $RESULTS | sort -nr
echo "Processed $FILECOUNT files in $DATAPATH"

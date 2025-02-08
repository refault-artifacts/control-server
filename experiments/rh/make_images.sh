#!/bin/bash

NODE=$1
MEMTEST_ROOT=memtest-$NODE
OUTDIR=memtest_images/$NODE
LOGFILE=memtest_images/log.txt

function log {
	echo "[$(date -Iseconds)]" $1 | tee -a $LOGFILE
}

if [ "$NODE" == "" ]; then
	echo "Usage: $0 NODE"
	exit -1
fi

mkdir -p "$OUTDIR"
if [ ! -d "$MEMTEST_ROOT" ]; then
  echo "ERROR: $MEMTEST_ROOT does not exist! please clone the memtest repo there and rename it"
  exit -1
fi

CONFIG_FILE=$NODE.json
if [ -e "$CONFIG_FILE" ]; then
	NODE_NAME=$(cat $CONFIG_FILE | jq .name | sed 's/"//g')
	if [ "$NODE_NAME" = "$NODE" ]; then
		log "Using config file $CONFIG_FILE".
	else
		echo "Error parsing $CONFIG_FILE"
		exit -1
	fi
else
	echo "Error: Could not find $CONFIG_FILE"
	exit -1
fi

AGGR_A=$(cat $CONFIG_FILE | jq .rows.aggressors[0].idx | sed 's/"//g')
AGGR_B=$(cat $CONFIG_FILE | jq .rows.aggressors[1].idx | sed 's/"//g')
START_ROW=$(cat $CONFIG_FILE | jq .rows.start | sed 's/"//g')
STEP_ROW=$(cat $CONFIG_FILE | jq .rows.step | sed 's/"//g')
END_ROW=$(cat $CONFIG_FILE | jq .rows.end | sed 's/"//g')
START_HAMMER=$(cat $CONFIG_FILE | jq .hammer.start | sed 's/"//g')
STEP_HAMMER=$(cat $CONFIG_FILE | jq .hammer.step | sed 's/"//g')
END_HAMMER=$(cat $CONFIG_FILE | jq .hammer.end | sed 's/"//g')
ADDR_MODE=$(cat $CONFIG_FILE | jq .address_function.mode | sed 's/"//g')
MODULE_SIZE=$(cat $CONFIG_FILE | jq .address_function.module_size | sed 's/"//g')

if [ ! "$(ls $OUTDIR | grep .efi)" == "" ]; then
	dialog --yesno "Are you sure you want to delete all memtest images for $NODE?" 5 80
	STATUS=$?
	if [ "$STATUS" -ne "0" ]; then
		exit -1;
	else 
		for FILE in $(find $OUTDIR -name "*.efi"); do
			rm $FILE
		done
	fi
fi

ITER=0
for ROW in $(seq $START_ROW $STEP_ROW $END_ROW); do
for HAMMER_COUNT in $(seq $START_HAMMER -$STEP_HAMMER $END_HAMMER); do
	log "Compiling image for node $NODE, row $ROW, HC $HAMMER_COUNT: Image $ITER"
	make -C $MEMTEST_ROOT/build64 clean >> /dev/null
	make -C $MEMTEST_ROOT/build64 NODE=$NODE REBOOT=$(pwd)/reboot.sh DURATION=10000 \
	TITLE="AUTOMATED_$ROW-$HAMMER_COUNT" BURST_COUNT=1 INTER_FAULT_DELAY=0 ROW_IDX=$ROW \
	AGGR_A=$AGGR_A AGGR_B=$AGGR_B HAMMER_COUNT=$HAMMER_COUNT ADDR_MODE=$ADDR_MODE \
	MODULE_SIZE=$MODULE_SIZE >> /dev/null
	mv $MEMTEST_ROOT/build64/memtest.efi $OUTDIR/memtest_$ROW-$HAMMER_COUNT.efi
	ITER=$((ITER+1))
done
done

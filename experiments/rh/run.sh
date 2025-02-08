#!/bin/bash
#
# This is the main runner script of the Rowhammer experiment that contains the main
# control logic. It takes a compiled memtest image (created by make_images.sh) and
# copies it to the $PXE_DIR, where the TFTP server can pick it up to send to the
# experiment machine. Depending on whether bit flips occur, a different image is chosen
# by this script.
#

NODE=$1
# Where the log files with the data are stored
DATA_DIR=rh/data_zen_characterization/$NODE
LOGFILE=rh/rh-$NODE.log
# Optionally, get an e-mail when the first bitflip is found
FIRST_BITFLIP_NOTIFICATION=0
MAIL_RECIPIENT=john.smith@example.com
# Location of the compiled images
MEMTEST_IMAGES=memtest_images/$NODE
# Directory that is served through PXE/TFTP. The image is named "memtest_pxe"
PXE_DIR="/var/ftpd/$NODE"

function log {
	echo "[$NODE][$(date -Iseconds)] $1" | tee -a $LOGFILE
}

if [ "$NODE" == "" ]; then
	echo "Usage: $0 NODE"
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

./pwroff.sh $NODE
log "Clearing data buffer"
while [ true ]; do
	./data.sh "0" "$DATA_DIR" "$NODE" >> /dev/null
	STATUS=$?
	if [ "$STATUS" -eq "254" ]; then
		break
	fi
done

START_ROW=$(cat $CONFIG_FILE | jq .rows.start | sed 's/"//g')
STEP_ROW=$(cat $CONFIG_FILE | jq .rows.step | sed 's/"//g')
END_ROW=$(cat $CONFIG_FILE | jq .rows.end | sed 's/"//g')
START_HAMMER_COUNT=$(cat $CONFIG_FILE | jq .hammer.start | sed 's/"//g')
STEP_HAMMER_COUNT=$(cat $CONFIG_FILE | jq .hammer.step | sed 's/"//g')
END_HAMMER_COUNT=$(cat $CONFIG_FILE | jq .hammer.end | sed 's/"//g')
FIRST_BITFLIP=1

cp -f "$MEMTEST_IMAGES/memtest_$START_ROW-$START_HAMMER_COUNT.efi" "$PXE_DIR/memtest_pxe" || exit
chmod 777 "$PXE_DIR/memtest_pxe"

log "Using memtest image $START_ROW-$START_HAMMER_COUNT"
./reboot.sh $NODE
sleep 10

# waiting for DIMM info
log "Determining DIMM..."
# This hangs forever if the machine doesnt answer
while [ "$DIMM" == "" ]; do
	DIMM_DESC=$(./stat.sh $NODE | jq .dimm.description | sed 's/"//g' | sed 's/ //g')
	DIMM_MAN=$(./stat.sh $NODE | jq .dimm.manufacturer | sed 's/"//g' | sed 's/ //g')
	if [ ! "$DIMM_DESC" == "null" ]; then
	       if [ ! "$DIMM_MAN" == "null" ]; then	
			DIMM=$(echo -n $DIMM_MAN-$DIMM_DESC)
			if [ "$DIMM" = "-" ]; then
				DIMM=$(echo Unknown-$(date +%d%m%y%H%M%S))
			fi
	       fi
	fi
	sleep 2
done
DATA_DIR=$DATA_DIR/$DIMM
log "Starting experiment on node $NODE, saving output to $DATA_DIR"
mkdir -p $DATA_DIR
cp $CONFIG_FILE $DATA_DIR

TIMEOUT=0
KILL=0
BITFLIP_TRIES=4
ZERO_BITFLIPS=${BITFLIP_TRIES}

ROW=$START_ROW
HAMMER_COUNT=$START_HAMMER_COUNT

while [ "$ROW" -lt "$END_ROW" ]; do
	# Poll the injection controller for data
	./data.sh "$ROW-$HAMMER_COUNT" "$DATA_DIR" "$NODE" >> /dev/null
	STATUS=$?
	if [ "$STATUS" -eq "0" ]; then
		# Use the "FOUND" string as a proxy to determine if the data is complete
		grep -q "FOUND [1-9][0-9]*" $(ls --sort=t $DATA_DIR/*.log | grep -m 1 ".")
		INCOMPLETE=$?
		if [ "$INCOMPLETE" -eq "0" ]; then
			# Get the approximate number of bit flips (this may be inaccurate due to corrupted data)
			CNT=$(grep "FOUND [1-9][0-9]*" $(ls --sort=t $DATA_DIR/*.log | grep -m 1 ".") | grep -o [1-9][0-9]*)
			log "Found $CNT bit flips with image $ROW-$HAMMER_COUNT, rebooting"
			# Send an e-mail
			if [ "$FIRST_BITFLIP" == "1" ]; then
				FIRST_BITFLIP=0
				if [ "$FIRST_BITFLIP_NOTIFICATION" == "1" ]; then
					cat $(ls --sort=t $DATA_DIR/*.log | grep -m 1 ".") | mail -s "Found bit flips on $NODE with $DIMM, row $ROW with $HAMMER_COUNT" $MAIL_RECIPIENT
				fi
			fi
			# If we can, try with a lower hammer count
			if [ "$HAMMER_COUNT" -ge "$END_HAMMER_COUNT" ]; then
				HAMMER_COUNT=$(($HAMMER_COUNT - $STEP_HAMMER_COUNT))
			else
				# We reached the minimal hammer count and still got bit flips,
				# so just start again with the next row
				HAMMER_COUNT=$START_HAMMER_COUNT
				ROW=$(($ROW + $STEP_ROW))
			fi
			# Boot up the next image
			# If this fails, you probably forgot to run make_images.sh first.
			cp -f $MEMTEST_IMAGES/memtest_$ROW-$HAMMER_COUNT.efi "$PXE_DIR/memtest_pxe" || exit
			chmod 777 "$PXE_DIR/memtest_pxe"
			log "Using memtest image $ROW-$HAMMER_COUNT"
			ZERO_BITFLIPS=${BITFLIP_TRIES}
			./reboot.sh $NODE
		else
			# No bit flips
			grep -q "FOUND 0 BIT ERRORS" $(ls --sort=t $DATA_DIR/*.log | grep -m 1 ".")
			BITFLIPS=$?
			if [ "$BITFLIPS" -eq "0" ]; then
				ZERO_BITFLIPS=$((ZERO_BITFLIPS-1))
				if [ "$ZERO_BITFLIPS" -gt "1" ]; then
				log "No bit errors during run $ROW-$HAMMER_COUNT, trying again."
				./reboot.sh $NODE
				else
					log "No bit errors during run $ROW-$HAMMER_COUNT, giving up."
					log "Skipping other images with lower HC"
					ROW=$((ROW+$STEP_ROW))
					HAMMER_COUNT=$START_HAMMER_COUNT
					# If this fails, you probably forgot to run make_images.sh first.
					cp -f $MEMTEST_IMAGES/memtest_$ROW-$HAMMER_COUNT.efi "$PXE_DIR/memtest_pxe" || exit
					chmod 777 "$PXE_DIR/memtest_pxe"
					log "Using memtest image $ROW-$HAMMER_COUNT"
					ZERO_BITFLIPS=${BITFLIP_TRIES}
					./reboot.sh $NODE
				fi
			else
				# If we do not find the "FOUND X BIT ERRORS" string, the data is probably incomplete.
				# We just append it and wait for more.
				log "Fetched partial data during run $ROW-$HAMMER_COUNT"
				TOT_LINES=$(grep -o "got 0x[0-9,a-f]" $(ls --sort=t $DATA_DIR/*.log | grep -m 1 ".") | wc -l)
				# On Intel machines, there are thousands of lines of data if a corruption occurs.
				# So detect this here and abort. This is not needed on AMD Zen 4.
				if [ "$TOT_LINES" -gt "500" ]; then
					log "Detected data corruption during run $ROW-$HAMMER_COUNT, trying again."
					echo "=== RUN SCRIPT DETECTED CRASH ===" >> $(ls --sort=t $DATA_DIR/*.log | grep -m 1 ".") 
					touch $DATA_DIR/$(date +%d%m%y-%H%M%S)-$NODE-$ROW-$HAMMER_COUNT-1.log
					./reboot.sh $NODE
				fi
			fi
		fi
		TIMEOUT=0
		KILL=0
	fi
	# Network issue? Should not happen.
	if [ "$STATUS" -eq "255" ]; then
		log "Getting data failed"
		KILL=$((KILL+1))	
	fi
	sleep 2
	TIMEOUT=$((TIMEOUT+2))
	# Detect if we don't get a response after a long time. This may happen because the image is not booting,
	# e.g., failed POST, broken PXE, or because the injection controller can not connect to the
	# experiment machine (wrong USB port)
	if [ "$TIMEOUT" -gt "$(cat $CONFIG_FILE | jq .timeout | sed 's/"//g')" ]; then
		log "Timeout expired, rebooting"
		KILL=$((KILL+1))
		./reboot.sh $NODE
		./data.sh "0" "$DATA_DIR" "$NODE" >> /dev/null
		sleep 60
	fi
	if [ "$KILL" -gt "20" ]; then
		log "Giving up."
		cat $LOGFILE | mail -s "Experiment failed" $MAIL_RECIPIENT
		exit -1
	fi
	if [ "$KILL" -gt "3" ]; then
		log "Machine not responding, trying to shutdown."
		./pwroff.sh >> /dev/null
		sleep 10
		./pwr.sh >> /dev/null
		sleep 90
	fi
done
cat "$LOGFILE" | sed 's/"//g' | mail -s "Experiment completed" $MAIL_RECIPIENT
./pwroff.sh $NODE

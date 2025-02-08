#!/bin/bash
# Polls the injection controller for new data and dumps it into individual files

DATA_PATH="."
DATA_DIR="$2"	

NODE="$3"

if [ "$NODE" == "" ]; then
	echo "Usage: $0 LOG_SUFFIX OUTDIR NODE"
	exit 2
fi

HEX_DATA=$(curl -sS http://inj-ctrl-$NODE.localdomain/get_data | jq .general_purpose_data.data)
DATA_ACQ_FAILED=$?

if [ $DATA_ACQ_FAILED -ne 0 ]; then
	echo "Could not get data from injection controller."
	exit -1
fi

if [ ! -e "$DATA_PATH/$DATA_DIR" ]; then
	mkdir -p $DATA_PATH/$DATA_DIR
fi

RUN=1

if [ $HEX_DATA = "\"\"" ]; then
	#echo "Received no new data."
	exit -2
else 
	# clean hex data from header 0xBB12 (should be removed in firmware),
	# remove whitespace and convert to ascii
	ASCII_DATA=$(echo -n "$HEX_DATA" | tr -d '\0' | sed 's/BB12//g' | awk '{$1=$1;print}' | xxd -r -p | tr -d '\0')

	# Determine the number of runs/crashes by counting the init phrase
	RUNS=$(echo "$ASCII_DATA" | grep -o "EXPERIMENT STARTED" | wc -l)
	echo "Detected $RUNS runs."

	# If there is no complete run, append it to the newest file
	if [ "$RUNS" -eq "0" ]; then
		if [ -z "$(ls -A $DATA_PATH/$DATA_DIR)" ]; then
			touch $DATA_PATH/$DATA_DIR/$(date +%d%m%y-%H%M%S)-$NODE-$1-0.log
		fi
			
		APPEND_FILE=$(ls --sort=t $DATA_PATH/$DATA_DIR | grep -m 1 ".")
		APPEND_FILEPATH=$DATA_PATH/$DATA_DIR/$APPEND_FILE
		echo "Appending data to $APPEND_FILEPATH"
		echo -n "$ASCII_DATA" | tr -d '\0' | tee -a $APPEND_FILEPATH >> /dev/null
	else	
		# Otherwise, make a file for every run
		for RUN in $(seq 1 $RUNS); do
			echo "RUN $RUN"
			DATA_FILENAME=$(date +%d%m%y-%H%M%S)-$NODE-$1-$RUN.log
			DATA_FILEPATH=$DATA_PATH/$DATA_DIR/$DATA_FILENAME
			
			#Handle case where data does not start with @
			PREAMBLE=$(echo -n "$ASCII_DATA" | tr -d '\0' | cut -z -d@ -f1 | tr -d '\0')
			if [ -n "$PREAMBLE"]; then
				echo "Writing incomplete data to $DATA_FILEPATH"
				echo -n $PREAMBLE | tee -a $DATA_FILEPATH
			fi	

			echo "Writing data to $DATA_FILEPATH"
			#echo -n "$ASCII_DATA" | hexdump -C
			echo -n "$ASCII_DATA" | cut -z -d@ -f$((RUN+1)) | tr -d '\0' | tee -a $DATA_FILEPATH >> /dev/null
		done
	fi
fi
exit 0

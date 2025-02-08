#!/bin/bash
# This script automatically compiles memtest for each fault injection pin 
# individually and runs it on the experment machine.
# The goal is to verify whether all switches work, i.e. lead to a crash
# of the system


MEMTEST_ROOT=~/memtest
LOGFILE=~/pintest.log
TFTP_ROOT=/var/ftpd

NODE="$1"

if [ "$NODE" == "" ]; then
	echo "Usage: $0 NODE"
	exit 2
fi

FI_DELAY=1000 # Approximate duration of the fault injection in nanoseconds

# These are all the Teensy pins for the CAx_DISC signals in order, 
# except those which are not directly controllable by the Teensy;
# so CA0-8, CA10 and CS0
FI_PINS=(40 41 18 36 19 22 17 5 4 23 37)

print_results() {
	return 1
}

log() {
	echo "[$(date +%d.%m.%y,%H:%M:%S)] $1" >> $LOGFILE
	return 1 
}


for FI_STATE in LOW HIGH; do
	for l in $(seq 0 9); do
		log "Test started with FI time of $FI_DELAY, faulting to $FI_STATE"

		for i in $(seq 0 10); do

			# First, generate the memtest image which faults that pin
			cd $MEMTEST_ROOT/build64
			make -s clean
			make -s CEXTRA=-DFAULT_INJECTION_PIN=${FI_PINS[i]} CEXTRA+=-DDELAY_NANOSECONDS=$FI_DELAY CEXTRA+=-DFAULT_INJECTION_STATE=$FI_STATE || log "Could not generate memtest image for pin"

			log "Successfully created memtest image for pin ${FI_PINS[i]}"

			# Copy the image to the right location so it is served via TFTP 
			cp memtest.efi $TFTP_ROOT/memtest_pxe

			# Reboot machine
			cd ~
			./reboot.sh $NODE
			log "Rebooted machine to load new image"

			TIMECNT=0
			while [ true ]; do
				status=`./stat.sh | jq -r .machine_status`
				if [ "$status" == "Alive" ]; then
					log "Machine is alive."
					break;
				fi
				TIMECNT=$((TIMECNT+1))
				if [ $TIMECNT -gt 60 ]; then
					log "Machine did not boot correctly"
					./reboot.sh $NODE
					TIMECNT=0
				fi
				sleep 3
			done

			# The machine is now alive, but should crash any moment

			TIMECNT=0
			while [ true ]; do
				status=`./stat.sh | jq -r .machine_status`
				if [ "$status" == "Crashed" ]; then
					log "Machine crashed with pin ${FI_PINS[i]} faulting $FI_STATE"
					break;
				fi
				sleep 3
				TIMECNT=$((TIMECNT+1))
				if [ $TIMECNT -gt 30 ]; then
					log "Machine did not crash with pin ${FI_PINS[i]} faulting $FI_STATE"
					break;
				fi
			done
		done
	done
done
log "Terminating..."
date | mail -s "EXPERIMENT COMPLETE" john.smith@example.com

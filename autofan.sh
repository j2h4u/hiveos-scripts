#!/usr/bin/env bash

#Nicehash donate: 3JKA47P98c9JGCy3GN7qXFC2FzeuJmXuph
#Zec donate: t1fP9jWyqFEni2p4i9t3byqtimsMKv1y95T
#ETH donate: 0xe835a7d5605a370e4750279b28f9ce0926061ea2

export DISPLAY=:0
. colors

DELAY=120
TEMP_TARGET=60
TEMP_DELTA=1
FAN_STEP=1
FAN_MIN=20
FAN_MAX=100

CARDS_NUM=`nvidia-smi -L | wc -l`
printf "Found ${CYAN}${CARDS_NUM}${NOCOLOR} GPU(s)\n"

while true
do

	printf "$(date +"%d/%m/%y %T") "

	for ((i=0; i<$CARDS_NUM; i++))
	do
		GPU_TEMP=`nvidia-smi -i $i --query-gpu=temperature.gpu --format=csv,noheader`
		GPU_FAN=`nvidia-smi -i $i --query-gpu=fan.speed --format=csv,noheader,nounits`
		DIFF=$(( $GPU_TEMP - $TEMP_TARGET ))
		printf "${WHITE}${i}${NOCOLOR}: "

		if [ $DIFF -le -${TEMP_DELTA} ]
		then
			echo -n -e "${BBLUE}${GPU_TEMP}${NOCOLOR}°C ${GPU_FAN}%"
			FAN_SPEED=$(( $GPU_FAN - ${FAN_STEP}))
			if [ $FAN_SPEED -lt ${FAN_MIN} ]
			then
				FAN_SPEED=${FAN_MIN}
			else
				nvidia-settings -a [gpu:$i]/GPUFanControlState=1 > /dev/null
				nvidia-settings -a [fan:$i]/GPUTargetFanSpeed=$FAN_SPEED > /dev/null
				echo -n " -> ${FAN_SPEED}%"
			fi
		elif [ $DIFF -ge ${TEMP_DELTA} ]
		then
			echo -n -e "${BRED}${GPU_TEMP}${NOCOLOR}°C ${GPU_FAN}%"
			FAN_SPEED=$(( $GPU_FAN + ${FAN_STEP}))
			if [ $FAN_SPEED -gt ${FAN_MAX} ]
			then
				FAN_SPEED=${FAN_MAX}
			else
				nvidia-settings -a [gpu:$i]/GPUFanControlState=1 > /dev/null
				nvidia-settings -a [fan:$i]/GPUTargetFanSpeed=$FAN_SPEED > /dev/null
				echo -n " -> ${FAN_SPEED}%"
			fi
		else
			echo -n -e "${BGREEN}${GPU_TEMP}${NOCOLOR}°C ${GPU_FAN}%"
		fi
		printf ", "

	done

	echo "sleeping for ${DELAY}s..."
	sleep $DELAY
done

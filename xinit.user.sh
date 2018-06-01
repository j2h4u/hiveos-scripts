#!/usr/bin/env bash

# This script is run in terminal after X server start

# uncomment the following line if you want to see miner log after start
#tail -f /run/hive/miner.1
screen -dmS NVRM /home/user/nvrm.sh
screen -dmS autofan /home/user/autofan.sh

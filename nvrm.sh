#!/usr/bin/env bash

clear
echo NVRM shit:
tail -f /var/log/syslog | fgrep -i nvrm

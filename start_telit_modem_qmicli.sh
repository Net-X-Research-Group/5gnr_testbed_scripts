#!/bin/bash

sudo qmi-network /dev/cdc-wdm0 stop
sudo qmi-network /dev/cdc-wdm0 start
sleep 2

# Get IP lease
sudo udhcpc -q -f -x lease:86400 -i wwan0
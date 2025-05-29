#!/bin/bash
DEVICE=/dev/cdc-wdm0
INTERFACE=wwan0

sudo qmi-network $(DEVICE) start
sleep 2

# Get IP lease
sudo udhcpc -q -f -x lease:86400 -i $(INTERFACE)
sudo qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode="low-power"
sudo qmi-network /dev/cdc-wdm0 stop

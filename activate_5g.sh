#!/bin/bash
# Function to run the original script
run_script() {
    sudo qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode='low-power'
    sleep 1
    sudo qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode='online'
    sleep 1
    sudo ip link set wwan0 down
    sleep 1
    echo 'Y' | sudo tee /sys/class/net/wwan0/qmi/raw_ip
    sleep 2
    sudo ip link set wwan0 up
    sleep 1
    sudo qmicli -p -d /dev/cdc-wdm0 --device-open-net='net-raw-ip|net-no-qos-header' --wds-start-network="apn='oai',ip-type=4" --client-no-release-cid
    sleep 2
    sudo qmicli -p -d /dev/cdc-wdm0 --wds-get-packet-service-status
    sudo qmicli -p -d /dev/cdc-wdm0 --wds-get-current-settings
    sleep 2
    sudo udhcpc -q -f -x lease:86400 -i wwan0 -t 5 -n
}

# Run the main loop in the background
(
while true; do
    # Check if the ping to 8.8.8.8 succeeds
    if ! ping -c 1 -I wwan0 8.8.8.8 > /dev/null 2>&1; then
        echo "Ping failed. Rerunning script..." >> ~/cell_monitor.log
        run_script
    fi
    # Sleep for some time before checking again
    sleep 600
done
) &

# Output the background process PID so you can kill it later if needed
echo "Cell monitoring started with PID: $!"

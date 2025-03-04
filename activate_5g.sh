#!/bin/bash
# Function to run the original script
run_script() {
    sudo qmicli -p -d /dev/cdc-wdm0 --device-open-net='net-raw-ip|net-no-qos-header' --wds-start-network="apn='oai',ip-type=4" --client-no-release-cid
    sleep 1
    # Modified to run udhcpc with -n so it doesn't kill the parent on failure
    sudo udhcpc -n -q -f -i wwan0 -t 5 || true
}

# Run the main loop in the background
(
while true; do
    # Check if the ping to 8.8.8.8 succeeds
    if ! ping -c 1 -I wwan0 8.8.8.8 > /dev/null 2>&1; then
        echo "Ping failed. Rerunning script..." >> /var/log/cell_monitor.log
        run_script
    fi
    # Sleep for some time before checking again
    sleep 0.5
done
) &

# Output the background process PID so you can kill it later if needed
echo "Cell monitoring started with PID: $!"

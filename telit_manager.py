import os
import sys

telit_devices = [filename for filename in os.listdir('/dev/') if filename.startswith("cdc-wdm")]

if len(telit_devices) == 0:
    raise Exception("No Telit device found")

if len(telit_devices) > 1:
    print('Multiple Telit devices found. Please select one:')


# Connect the telit modems

# Verify with AMF that they are connected

# Collect ip addresses

# Setup iperf3 testing between modems and the core

# Collect iperf3 results
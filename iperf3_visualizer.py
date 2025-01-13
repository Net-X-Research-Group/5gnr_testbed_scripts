"""
Author: Robert J. Hayek
Date: Aug. 15, 2024
Affiliation: Northwestern University, Argonne National Laboratory

Function: Take JSON output from iperf3 and plot. Plot shows Tx/Rx transfer, bitrate,
interval, retries, and Congestion Window.
iPerf3 settings: 2G data transfer, bidirectional, format in Mbits.

Telit Modem is the server, and oai-ext-dn is the server.
UL is TX from the server, DL is RX to the server.
JSON dump from server side.

"""


import json
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import os


def import_log_files(file_path):
    logs_dict = {}
    for filename in os.listdir(file_path):
        with open(os.path.join(file_path, filename), 'r') as f:
            logs_dict[filename.removesuffix('.json')] = json.load(f)
    return logs_dict


def main():
    logs = import_log_files('/Users/roberthayek/Documents/git_repos/5gnr_testbed_scripts/iperf_measurements_090324/')
    downlink = {}
    uplink = {}

    for log in logs:
        print('Entering log:', log)
        if 'DL' in log:
            bitrate = []
            for interval in logs[log]['intervals']:
                bitrate.append(interval['sum']['bits_per_second'])
            downlink[log] = bitrate

        if 'UL' in log:
            uplink[log] = logs[log]
            bitrate = []
            for interval in logs[log]['intervals']:
                bitrate.append(interval['sum']['bits_per_second'])
            uplink[log] = bitrate

    #downlink = pd.DataFrame.from_dict(downlink)
    #uplink = pd.DataFrame.from_dict(uplink)

    plt.figure(0)
    for key in downlink:
        plt.plot(downlink[key][15:], label=key)
    #plt.boxplot(downlink)
    #plt.show()

    plt.figure(1)
    for key in uplink:
        plt.plot(uplink[key][15:], label=key)

    plt.legend()
    plt.title('Downlink Bitrate')
    plt.xlabel('Time (s)')
    plt.ylabel('Bitrate (Mbps)')
    plt.show()

    print('DONE!')




    '''json_file_path = 'waggle_72.json'
    with open(json_file_path) as json_file:
        raw_data = json.load(json_file)

    start = raw_data['start']
    end = raw_data['end']
    intervals = raw_data['intervals']

    # Extract the data
    bps = []
    rtt = []
    retransmits = []
    size = []
    rttvar = []
    for value in intervals:
        bps.append(value['sum']['bits_per_second'])
        #rtt.append(value['streams'][0]['rtt'])
        #retransmits.append(value['streams'][0]['retransmits'])
        #size.append(value['sum']['bits_per_second'])
        #rtt.append(value['streams'][0]['rttvar'])



    bps = np.array(bps)/1e6
    time = np.arange(0, len(bps))


    # Plot the data
    plt.figure(0)


    plt.scatter(time,bps)

    z = np.polyfit(time, bps, 10)
    p = np.poly1d(z)

    # add trendline to plot
    plt.plot(time, p(time), "r--", label='Trendline')
    plt.plot(time, bps, "b", label='Bitrate (Mbps)')
    plt.legend()
    plt.title('Bitrate vs. Time 100M DL Transfer')
    plt.ylabel('Bit Rate (Mbps)')
    plt.xlabel('Time (s)')

    plt.ylim(ymin=0)
    plt.xlim(xmin=0)

    plt.show()


    print('DONE!')
'''

if __name__ == "__main__":
    main()

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
import numpy as np

def main():
    json_file_path = 'server_2hr_UL.json'
    with open(json_file_path) as json_file:
        raw_data = json.load(json_file)

    start = raw_data['start']
    end = raw_data['end']
    intervals = raw_data['intervals']


    bps = list()
    rtt = list()
    for value in intervals:
        bps.append(value['streams'][0]['bits_per_second'])
        rtt.append(value['streams'][0]['bits_per_second'])


    plt.figure()
    plt.plot(bps)
    plt.show()
    plt.savefig('output.png')
    print('DONE!')


if __name__ == "__main__":
    main()

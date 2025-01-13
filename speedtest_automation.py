"""
Author: Robert J. Hayek
Date: Sept 18, 2024
Affiliation: Northwestern University, Argonne National Laboratory

Run Ookla Speedtest for n trials and generate JSON + figures

"""

import speedtest
import json
import socket
import fcntl
import struct
import pandas as pd
import argparse

def get_5g_ipaddr() -> str:
    interface = 'wwan0'
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as ssock:
        packed_iface = struct.pack('256s', interface.encode('utf_8'))
        packed_addr = fcntl.ioctl(ssock.fileno(), 0x8915, packed_iface)[20:24]
    return socket.inet_ntoa(packed_addr)


def run_test(interface_address: str) -> dict:
    instance = speedtest.Speedtest(source_address=interface_address, secure=True)
    #instance.get_servers()
    instance.get_best_server()
    
    instance.download()
    instance.upload(pre_allocate=False)

    return instance.results.dict()

def parse_data(result: dict):
    download = result['download']
    upload = result['upload']
    ping = result['ping']
    timestamp = result['timestamp']
    return {'Timestamp': timestamp, 'Ping': ping, 'Download': download, 'Upload': upload}

def main(trials: int, filename: str):
    ip_addr = get_5g_ipaddr()
    print('IP Address of wwan0 is:', ip_addr)
    
    df = pd.DataFrame(columns=['Timestamp', 'Ping', 'Download', 'Upload'])
    
    for i in range(trials):
        print('Running Trial ', i)
        raw_output = run_test(ip_addr)
        output = parse_data(raw_output)
        df.loc[len(df.index)] = output
    df.to_csv(f'{filename}.csv', index=False)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='A tool to automate Ookla Speedtests')

    parser.add_argument('-t', '--trials', type=int, help='The number of trials to run')
    parser.add_argument('-o', '--output', help='Output file name (default csv)')
    
    args = parser.parse_args()
            
    main(args.trials, args.output)

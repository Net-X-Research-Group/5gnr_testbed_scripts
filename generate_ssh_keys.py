import os
import paramiko
import subprocess

def generate_ssh_key(key_comment)
    key_path = os.path.expanduser('~/.ssh/github_ssh_key')
    private_key_file = key_path
    public_key_file = f'{key_path}.pub'
    if os.path.exists(private_key_file) or os.path.exists(public_key_file):
        print(f"Key files already exist at {private_key_file} and {public_key_file}.")
        return private_key_file, public_key_file
    return 0

def transfer_keys(devices: dict):
    key_path = os.path.expanduser('~/.ssh/id_ed25519')
    private_key_path = key_path
    public_key_path = f'{key_path}.pub'
    
    paramiko.load


    for device in devices:
        scp_command_public = [
            "sshpass", "-p", '5GController',
            'scp', public_key_file, f'{device[username]@device[ip_addr]:{~/.ssh/id25519.pub}}'
        ]
        scp_command_private = [
            "sshpass", "-p", '5GController',
            'scp', private_key_file, f'{device[username]@device[ip_addr]:{~/.ssh/id25519}}'
        ]


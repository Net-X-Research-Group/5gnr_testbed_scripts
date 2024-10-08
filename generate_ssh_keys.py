import os
import paramiko
import subprocess

def generate_ssh_key(key_path="~/.ssh.id_rsa", key_comment)

    key_path = os.path.expanduser(key_path)
    private_key_file = key_path
    
    return private_key, public_key

def transfer_keys(device_parameters: dict, private_key, public_key)

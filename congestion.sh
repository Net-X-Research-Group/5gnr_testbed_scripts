#!/bin/bash
STOP="$HOME/5gnr_testbed_scripts/stop_telit_modem_qmicli.sh"
START="$HOME/5gnr_testbed_scripts/start_telit_modem_qmicli.sh"
IPERF_PORT=5023
UDP_DISCOVERY_PORT=5024
TEST_DURATION=7200
MAX_START_FAILURES=3
START_FAILURES=0
DISCOVERY_BROADCAST_INTERVAL=15  # Seconds between broadcasting server IP
DISCOVERY_TIMEOUT=60             # How long to wait during initial discovery
SERVER_IP_FILE="/tmp/server_ip.txt"  # File to store the server IP

# Print usage information
usage() {
    echo "Usage: $0 --mode=[client|server] [--server-ip=IP_ADDRESS]"
    echo ""
    echo "Options:"
    echo "  --mode        Required. Specify whether this node runs as 'client' or 'server'"
    echo "  --server-ip   Optional for client mode. IP address of the iperf3 server."
    echo "                If not provided, client will use UDP discovery to find server."
    exit 1
}

# Parse command line arguments
MODE=""
SERVER_IP=""

for arg in "$@"; do
    case $arg in
        --mode=*)
            MODE="${arg#*=}"
            shift
            ;;
        --server-ip=*)
            SERVER_IP="${arg#*=}"
            shift
            ;;
        *)
            echo "Unknown argument: $arg"
            usage
            ;;
    esac
done

# Validate arguments
if [ -z "$MODE" ] || { [ "$MODE" != "client" ] && [ "$MODE" != "server" ]; }; then
    echo "Error: Mode must be specified as 'client' or 'server'"
    usage
fi

graceful_quit() {
    echo "Received termination signal. Cleaning up..."
    pkill -f iperf3
    # Kill any background discovery processes
    if [ -n "$DISCOVERY_PID" ]; then
        kill $DISCOVERY_PID 2>/dev/null
    fi
    if [ -n "$BROADCAST_PID" ]; then
        kill $BROADCAST_PID 2>/dev/null
    fi
    # Clean up temp file
    rm -f "$SERVER_IP_FILE"
    exit 0
}

check_connection() {
    local ping_output
    local packet_loss
    
    echo "Checking connection..."
    ping_output=$(ping 8.8.8.8 -I wwan0 -c 3)
    
    # Extract packet loss using regex
    if [[ $ping_output =~ ([0-9]+)%\ packet\ loss ]]; then
        packet_loss=${BASH_REMATCH[1]}
        echo "Packet loss: $packet_loss%"
        return $packet_loss
    else
        echo "Failed to check connection"
        return 100  # Return 100 to indicate error
    fi
}

restart_modem() {
    echo "Restarting modem..."
    
    $STOP
    sleep 3
    $START &
    START_PID=$!
    
    # Wait for up to 30 seconds for the start command to complete
    WAIT_TIME=0
    while [ $WAIT_TIME -lt 30 ]; do
        if ! kill -0 $START_PID 2>/dev/null; then
            # Process has completed
            echo "Start command completed successfully"
            START_FAILURES=0
            break
        fi
        sleep 3
        WAIT_TIME=$((WAIT_TIME + 3))
    done
    
    # Check if start command is still running after timeout
    if kill -0 $START_PID 2>/dev/null; then
        echo "Start command did not complete within 30 seconds. Terminating process."
        sudo pkill udhcpc
        START_FAILURES=$((START_FAILURES + 1))
        
        if [ $START_FAILURES -ge $MAX_START_FAILURES ]; then
            DATE=$(date '+%Y-%m-%d %H:%M:%S')
            echo "$DATE: Start command has failed $START_FAILURES times. gNB may be down. Exiting script."
            exit 1
        fi
    fi
    sleep 15  # Give time for modem to stabilize
}

# Get wwan0 IP address
get_wwan0_ip() {
    local wwan0_ip
    
    # echo "Getting wwan0 IP address..."
    
    wwan0_ip=$(ip addr show wwan0 | grep -oP 'inet \K[\d.]+' || ifconfig wwan0 | grep -oP 'inet addr:\K[\d.]+')
    
    if [[ -z "$wwan0_ip" ]]; then
        echo "Error: Could not determine wwan0 IP address" >&2
        return 1
    fi
    
    # echo "Found wwan0 IP: $wwan0_ip"
    echo "$wwan0_ip"
    return 0
}

# Check if iperf3 is running
check_iperf() {
    local is_running
    
    echo "Checking if iperf3 is running..."
    
    is_running=$(pgrep -c iperf3 2>/dev/null | tr -d ' \t\n\r' || echo "0")
    
    # # Debug the actual value
    # echo "DEBUG: Raw count value: '$is_running'"
    
    # First check if it's empty or exactly "0"
    if [ -z "$is_running" ] || [ "$is_running" = "0" ]; then
        echo "iperf3 is not running (case 1)"
        return 1
    # Then check if it contains a 0 (e.g., "0 0" case)
    elif echo "$is_running" | grep -q "^0"; then
        echo "iperf3 is not running (case 2)"
        return 1
    # If it's any other value, we assume it's a non-zero count
    else
        echo "iperf3 is running (processes: $is_running)"
        return 0
    fi
}

# Start iperf3 server binding to wwan0 interface
start_iperf_server() {
    local wwan0_ip=$(get_wwan0_ip)
    
    if [ $? -ne 0 ] || [ -z "$wwan0_ip" ]; then
        echo "Failed to get wwan0 IP, cannot start server"
        return 1  # Return error code to indicate failure
    else
        echo "Starting iperf3 server bound to $wwan0_ip"
        echo "iperf3 -u -s -p $IPERF_PORT -B $wwan0_ip &"
        iperf3 -u -s -p $IPERF_PORT -B $wwan0_ip &
        sleep 2
        return 0
    fi
}

# Get current server IP from shared file
get_server_ip() {
    if [ -f "$SERVER_IP_FILE" ]; then
        local ip=$(cat "$SERVER_IP_FILE" 2>/dev/null)
        if [ -n "$ip" ]; then
            SERVER_IP="$ip"
        fi
    fi
}

# Run iperf3 client test in background
run_iperf_client() {
    # First get the latest server IP
    get_server_ip

    echo "Running iperf3 client test to server $SERVER_IP..."
    
    local wwan0_ip=$(get_wwan0_ip)
    
    if [ $? -ne 0 ] || [ -z "$wwan0_ip" ]; then
        echo "Error: Could not determine wwan0 IP address"
        return 1
    fi
    
    # Only run test if we have a server IP
    if [ -z "$SERVER_IP" ]; then
        echo "No server IP available. Waiting for discovery..."
        return 1
    fi
    
    # Run iperf3 in the background with specific IP binding
    # Note: We need to run it continuously, so use a very long duration
    echo "iperf3 -u -c $SERVER_IP -B $wwan0_ip -p $IPERF_PORT -t 86400 &"
    iperf3 -u -c $SERVER_IP -B $wwan0_ip -p $IPERF_PORT -t 86400 &
    
    # Let it initialize
    sleep 5
    
    # Verify it's running
    if check_iperf; then
        echo "iperf3 client started successfully in the background"
        return 0
    else
        echo "Failed to start iperf3 client"
        return 1
    fi
}

# Server: Broadcast IP function
broadcast_server_ip() {
    # Get current wwan0 IP
    local wwan0_ip=$(get_wwan0_ip)
    
    if [ $? -ne 0 ] || [ -z "$wwan0_ip" ]; then
        echo "Cannot broadcast - no valid wwan0 IP address"
        return 1
    fi

    # Broadcast in background
    while true; do
        echo "Broadcasting server IP: $wwan0_ip on UDP port $UDP_DISCOVERY_PORT"
        echo "SERVER_IP=$wwan0_ip" | nc -u -b 129.105.6.21 $UDP_DISCOVERY_PORT #TODO make IP a variable
        sleep $DISCOVERY_BROADCAST_INTERVAL
    done
}

# Client: Discover server IP function
discover_server_ip() {
    echo "Starting server IP discovery on UDP port $UDP_DISCOVERY_PORT..."
    
    # Create a temporary file for storing messages
    local temp_file=$(mktemp)
    
    # Start listening for UDP broadcasts in background
    nc -u -l -p $UDP_DISCOVERY_PORT > $temp_file &
    local nc_pid=$!
    
    # Store the discovery process ID
    DISCOVERY_PID=$nc_pid
    
    # Periodically check for received broadcasts
    while true; do
        if [ -s "$temp_file" ]; then
            local new_ip=$(grep -oP 'SERVER_IP=\K[0-9.]+' $temp_file)
            if [ -n "$new_ip" ]; then
                local current_ip=""
                if [ -f "$SERVER_IP_FILE" ]; then
                    current_ip=$(cat "$SERVER_IP_FILE" 2>/dev/null)
                fi
                
                if [ "$new_ip" != "$current_ip" ]; then
                    echo "Discovered new server IP: $new_ip (was: $current_ip)"
                    # Save to shared file
                    echo "$new_ip" > "$SERVER_IP_FILE"
                    
                    # If iperf client is running, restart it with the new IP
                    if check_iperf; then
                        echo "Restarting iperf client with new server IP"
                        pkill -f iperf3
                    fi
                fi
                # Clear the file for next discovery
                : > $temp_file
            fi
        fi
        sleep 5
    done
}

# Beginning of sequential execution
pkill -f iperf3
trap 'graceful_quit' SIGINT SIGTERM

echo "Starting congestion test in $MODE mode"

# Ensure clean start
rm -f "$SERVER_IP_FILE"

# Mode-specific startup
if [ "$MODE" = "server" ]; then
    # Start broadcasting the server IP in the background
    broadcast_server_ip &
    BROADCAST_PID=$!
elif [ "$MODE" = "client" ]; then
    if [ -z "$SERVER_IP" ]; then
        echo "No server IP provided. Will discover dynamically."
        
        # Start discovery in background
        discover_server_ip &
        DISCOVERY_PID=$!
        
        # Wait for initial server discovery or timeout
        echo "Waiting for server discovery (timeout: ${DISCOVERY_TIMEOUT}s)..."
        discovery_wait=0
        discovery_complete=false
        
        while [ $discovery_wait -lt $DISCOVERY_TIMEOUT ] && [ "$discovery_complete" = "false" ]; do
            sleep 5
            discovery_wait=$((discovery_wait + 5))
            
            # Check if server IP has been discovered
            if [ -f "$SERVER_IP_FILE" ] && [ -s "$SERVER_IP_FILE" ]; then
                SERVER_IP=$(cat "$SERVER_IP_FILE")
                echo "Successfully discovered server IP: $SERVER_IP"
                discovery_complete=true
            else
                echo "Still waiting for server discovery... ($discovery_wait/${DISCOVERY_TIMEOUT}s)"
            fi
        done
        
        if [ "$discovery_complete" = "false" ]; then
            echo "Warning: Failed to discover server IP within timeout."
            echo "Will continue and try to discover later."
        fi
    else
        echo "Using provided server IP: $SERVER_IP"
        echo "$SERVER_IP" > "$SERVER_IP_FILE"
        
        # Still start discovery to update IP if server changes
        discover_server_ip &
        DISCOVERY_PID=$!
    fi
fi

# Main loop
while true; do
    # In client mode, check for updated server IP
    if [ "$MODE" = "client" ]; then
        get_server_ip
    fi

    check_connection
    loss=$?
    
    # Handle connection issues
    if [ $loss -lt 100 ]; then
        echo "Network has $loss% packet loss"
    else
        echo "Connection failed. Restarting modem..."
        restart_modem
        continue  # Skip to next iteration after modem restart
    fi
    
    # Update wwan0 IP if in server mode (in case it changed)
    if [ "$MODE" = "server" ]; then
        # Kill existing broadcast process if running
        if [ -n "$BROADCAST_PID" ]; then
            if kill -0 $BROADCAST_PID 2>/dev/null; then
                kill $BROADCAST_PID
            fi
        fi
        
        # Start a new broadcast with updated IP
        broadcast_server_ip &
        BROADCAST_PID=$!
        
        # Server mode: run iperf3 server
        if ! check_iperf; then
            echo "Starting iperf3 server..."
            start_iperf_server
            if [ $? -ne 0 ]; then
                echo "Failed to start iperf3 server due to wwan0 issues. Restarting modem..."
                restart_modem
                continue  # Skip to next iteration of the loop
            fi
        else
            echo "iperf3 server is already running"
        fi
    elif [ "$MODE" = "client" ]; then
        # Client mode: run iperf3 client if not already running
        if ! check_iperf; then
            get_server_ip  # Get latest server IP before checking
            if [ -n "$SERVER_IP" ]; then
                echo "Starting iperf3 client..."
                run_iperf_client
            else
                echo "Cannot start iperf3 client: No server IP discovered yet"
            fi
        else
            # Check if the server IP has changed
            local old_ip=""
            if [ -f "$SERVER_IP_FILE" ]; then
                old_ip=$(cat "$SERVER_IP_FILE" 2>/dev/null)
            fi
            
            # Get the latest server IP
            get_server_ip
            
            # If the IP changed, restart the client
            if [ "$old_ip" != "$SERVER_IP" ] && [ -n "$SERVER_IP" ]; then
                echo "Server IP changed from $old_ip to $SERVER_IP. Restarting iperf3 client..."
                pkill -f iperf3
                run_iperf_client
            else
                echo "iperf3 client is already running with server $SERVER_IP"
            fi
        fi
    fi
    
    echo "Waiting before next check cycle..."
    sleep 30
done
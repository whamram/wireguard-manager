#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [-i IP_ADDRESS] [-p PORT] [-r PORT] [-f] [-x] [-u] [-d] [-s]"
    echo "  -i IP_ADDRESS   Set the IP address for port forwarding."
    echo "  -p PORT         Initialize port forwarding for the specified port."
    echo "  -r PORT         Remove port forwarding for the specified port."
    echo "  -f              Enable forwarding of traffic out to the internet for the specified IP address."
    echo "  -x              Reset all port forwarding rules to default."
    echo "  -u              Start WireGuard."
    echo "  -d              Stop WireGuard."
    echo "  -s              Show current port forwarding rules and wireguard status."
    exit 1
}

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

IP_ADDRESS=""
while getopts "i:p:r:fxuds" opt; do
    case $opt in
        i)
            IP_ADDRESS=$OPTARG
            ;;
        p)
            if [[ -z $IP_ADDRESS ]]; then
                echo "Error: IP address must be set before initializing port forwarding."
                usage
            fi
            PORT=$OPTARG
            if [[ $PORT -eq 2222 ]]; then
                echo "Error: Port 2222 is not allowed."
                exit 1
            fi
            echo "Initializing port forwarding for port $PORT to IP $IP_ADDRESS..."
            iptables -t nat -A PREROUTING -p tcp -i eth0 --dport $PORT -j DNAT --to-destination $IP_ADDRESS:$PORT
            iptables -t nat -A POSTROUTING -p tcp -o wg0 -d $IP_ADDRESS --dport $PORT -j MASQUERADE
            iptables -A FORWARD -i eth0 -o wg0 -p tcp -d $IP_ADDRESS --dport $PORT -j ACCEPT
            echo "Port forwarding initialized."
            ;;
        r)
            PORT=$OPTARG
            if [[ $PORT -eq 2222 ]]; then
                echo "Error: Port 2222 is not allowed."
                exit 1
            fi
            iptables -t nat -D PREROUTING -p tcp -i eth0 --dport $PORT -j DNAT --to-destination $IP_ADDRESS:$PORT
            iptables -t nat -D POSTROUTING -p tcp -o wg0 -d $IP_ADDRESS --dport $PORT -j MASQUERADE
            iptables -D FORWARD -i eth0 -o wg0 -p tcp -d $IP_ADDRESS --dport $PORT -j ACCEPT
            echo "Port forwarding removed."
            ;;
        x)
            echo "Resetting all port forwarding rules to default..."
            iptables -t nat -F
            echo "All port forwarding rules reset."
            ;;
        u)
            echo "Starting WireGuard..."
            wg-quick up /etc/wireguard/wg0.conf
            echo "WireGuard Up."
          ;;
        f)
            if [[ -z $IP_ADDRESS ]]; then
                echo "Error: IP address must be set before initializing port forwarding."
                usage
            fi
            echo "Initializing forwarding from $IP_ADDRESS to the internet..."
            iptables -t nat -A POSTROUTING -s $IP_ADDRESS -o eth0 -j MASQUERADE
            iptables -A FORWARD -i wg0 -s $IP_ADDRESS -o eth0 -j ACCEPT
            echo "Port forwarding initialized."
            ;;
        d)
            echo "Stopping WireGuard..."
            wg-quick down /etc/wireguard/wg0.conf
            echo "WireGuard down."
            ;;
        s)
            wg show
            sudo iptables -t nat -L -n -v
            ;;
        *)
            usage
            ;;
    esac
done

if [[ $OPTIND -eq 1 ]]; then
    usage
fi
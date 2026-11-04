#!/bin/sh

clear

CPU_IDLE=$(top -bn1 | awk '/CPU:/ {print $8}' | tr -d '%')
CPU_USED=$((100 - CPU_IDLE))

echo "=============================="
echo " WHAT'S RUNNING?"
echo "=============================="
echo

echo "CPU Usage: ${CPU_USED}%"
echo

check_service() {
    NAME="$1"
    DESC="$2"

    PID=$(pgrep "$NAME" | head -n1)

    if [ -n "$PID" ]; then
        echo "[+] $NAME"
        echo "    $DESC"
        echo "    PID: $PID"
        echo
    fi
}

check_service pineapd "Wireless Recon"
check_service blue5 "Bluetooth Recon"
check_service hostapd "Access Point Service"
check_service dnsmasq "DHCP/DNS Service"

exit 0

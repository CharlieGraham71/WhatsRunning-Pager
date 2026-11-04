#!/bin/sh

. ./lib/services.sh
. ./lib/kill.sh
. ./lib/managed.sh

clear

CPU_LINE=$(top -bn1 | grep "^CPU:")

echo "=============================="
echo " WHAT'S RUNNING?"
echo "=============================="
echo

echo "$CPU_LINE"
echo
IDLE=$(echo "$CPU_LINE" | awk '{print $8}' | tr -d '%')

if [ "$IDLE" -gt 75 ]; then
    echo "Health: GOOD"
elif [ "$IDLE" -gt 50 ]; then
    echo "Health: MODERATE"
else
    echo "Health: HIGH LOAD"
fi

echo
if pgrep pineapd >/dev/null || pgrep blue5 >/dev/null
then
    if pgrep pineapd >/dev/null || pgrep blue5 >/dev/null
then
    STATUS="ACTIVE RECON"
    BATTERY="MODERATE"
else
    STATUS="IDLE"
    BATTERY="LOW"
fi

echo "Status: $STATUS"
echo "Battery Impact: $BATTERY"
else
    echo "Status: IDLE"
fi

echo



check_service pineapd "Wireless Recon"
managed_service pineapd
echo

check_service blue5 "Bluetooth Recon"
managed_service blue5
echo

check_service hostapd "Access Point Service"
check_service dnsmasq "DHCP/DNS Service"
echo "Top Process Activity"
echo "--------------------"

top -bn1 | sed -n '5,8p'

echo
echo
echo "Actions"
echo "-------"
echo "1) Stop Wireless Recon"
echo "2) Stop Bluetooth Recon"
echo "3) Exit"
echo

read -p "Select: " CHOICE

case "$CHOICE" in
    1)
        kill_service pineapd
        ;;
    2)
        kill_service blue5
        ;;
    *)
        ;;
esac
exit 0

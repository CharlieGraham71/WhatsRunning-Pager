#!/bin/sh

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
echo "Top Process Activity"
echo "--------------------"

top -bn1 | sed -n '5,8p'

echo
exit 0

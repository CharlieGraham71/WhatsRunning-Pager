#!/bin/sh

clear

echo "=============================="
echo " WHAT'S RUNNING?"
echo "=============================="
echo

for PROC in pineapd blue5 hostapd dnsmasq
do
    PID=$(pgrep "$PROC" | head -n1)

    if [ -n "$PID" ]; then
        echo "[+] $PROC"
        echo "    PID: $PID"
        echo
    fi
done

exit 0

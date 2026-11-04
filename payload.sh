#!/bin/bash

while true
do

CPU_LINE=$(top -bn1 | grep "^CPU:")
MEM_LINE=$(top -bn1 | grep "^Mem:")
USED_KB=$(echo "$MEM_LINE" | awk '{print $2}' | tr -d 'K')
FREE_KB=$(echo "$MEM_LINE" | awk '{print $4}' | tr -d 'K')

USED_MB=$((USED_KB/1024))
FREE_MB=$((FREE_KB/1024))

WIFI_DB=$(du -h /root/recon/recon.db 2>/dev/null | awk '{print $1}')
BT_DB=$(du -h /root/recon/blue5.db 2>/dev/null | awk '{print $1}')
PCAP_SIZE=$(du -sh /root/loot/pcap 2>/dev/null | awk '{print $1}')
HANDSHAKE_SIZE=$(du -sh /root/loot/handshakes 2>/dev/null | awk '{print $1}')
WIGLE_SIZE=$(du -sh /root/loot/wigle 2>/dev/null | awk '{print $1}')
RECON_SIZE=$(du -sh /root/recon 2>/dev/null | awk '{print $1}')
LOOT_MB=$(du -sm /root/loot 2>/dev/null | awk '{print $1}')
RECON_MB=$(du -sm /root/recon 2>/dev/null | awk '{print $1}')

TOTAL_STORAGE="$((LOOT_MB + RECON_MB))M"
BATTERY_LEVEL=$(cat /sys/devices/platform/10000000.palmbus/10000900.i2c/i2c-0/0-0055/power_supply/bq27546-0/capacity 2>/dev/null)
[ -z "$WIFI_DB" ] && WIFI_DB="Not Found"
[ -z "$BT_DB" ] && BT_DB="Not Found"

RECON_STATE=$(grep logrecon /etc/config/pineapd | grep -o "[01]")
BT_STATE=$(grep active /etc/config/blue5 | grep -o "[01]")

[ "$RECON_STATE" = "1" ] && RECON_STATUS="ENABLED"
[ "$RECON_STATE" = "0" ] && RECON_STATUS="DISABLED"

[ "$BT_STATE" = "1" ] && BT_MODE="ACTIVE"
[ "$BT_STATE" = "0" ] && BT_MODE="PASSIVE"

IDLE=$(echo "$CPU_LINE" | awk '{print $8}' | tr -d '%')
LOAD=$((100-IDLE))
if [ -n "$IDLE" ] && [ "$IDLE" -gt 75 ] 2>/dev/null; then
    HEALTH="GOOD"
elif [ -n "$IDLE" ] && [ "$IDLE" -gt 50 ] 2>/dev/null; then
    HEALTH="MODERATE"
else
    HEALTH="HIGH LOAD"
fi

CHOICE=$(LIST_PICKER \
"WhatsRunning" \
"System Health" \
"CPU Status" \
"Memory" \
"Battery" \
"RECON Status" \
"Bluetooth Status" \
"Running Services" \
"Storage" \
"Clear Data" \
"About" \
"Exit" \
"CPU Status")

case "$CHOICE" in
"System Health")
PROMPT "SYSTEM HEALTH

Battery:
${BATTERY_LEVEL}%

CPU:
$HEALTH

RECON:
$RECON_STATUS

PCAPs:
$PCAP_SIZE"
;;
"CPU Status")
PROMPT "CPU STATUS

Load:
${LOAD}%

Idle:
${IDLE}%

Health:
$HEALTH"
;;

"Memory")
PROMPT "MEMORY

Used:
${USED_MB} MB

Free:
${FREE_MB} MB"
;;

"Battery")
PROMPT "BATTERY

Level:
${BATTERY_LEVEL}%"
;;

"RECON Status")
PROMPT "RECON STATUS

RECON:
$RECON_STATUS

WiFi Data:
$WIFI_DB"
;;
"Bluetooth Status")
PROMPT "BLUETOOTH STATUS

Mode:
$BT_MODE

BT Data:
$BT_DB"
;;

"Running Services")
PROMPT "RUNNING SERVICES

PineAP
$(pgrep pineapple >/dev/null 2>&1 && echo ACTIVE || echo OFF)

RECON
$RECON_STATUS

Bluetooth
$BT_MODE

Access Point
$(pgrep hostapd >/dev/null 2>&1 && echo ACTIVE || echo OFF)"
;;
"Storage")
PROMPT "STORAGE

PCAPs:
$PCAP_SIZE

RECON:
$RECON_SIZE
=
Handshakes:
$HANDSHAKE_SIZE

Wigle:
$WIGLE_SIZE

Total:
$TOTAL_STORAGE"
;;

"Clear Data")

CLEAR_CHOICE=$(LIST_PICKER \
"Clear Data" \
"PCAP Files ($PCAP_SIZE)" \
"Handshakes ($HANDSHAKE_SIZE)" \
"RECON Data ($RECON_SIZE)" \
"Wigle Data ($WIGLE_SIZE)" \
"Back" \
"Back")

case "$CLEAR_CHOICE" in

"PCAP Files ($PCAP_SIZE)")

CONFIRM=$(LIST_PICKER \
"Delete ALL PCAP Files?" \
"NO" \
"YES" \
"NO")

if [ "$CONFIRM" = "YES" ]; then

    REMOVED="$PCAP_SIZE"

    rm -f /root/loot/pcap/*

    PROMPT "PCAP FILES

$REMOVED

DELETED"
fi

;;

"Handshakes ($HANDSHAKE_SIZE)")

CONFIRM=$(LIST_PICKER \
"Delete Handshakes ($HANDSHAKE_SIZE)?" \
"NO" \
"YES" \
"NO")

if [ "$CONFIRM" = "YES" ]; then

    REMOVED="$HANDSHAKE_SIZE"

    rm -f /root/loot/handshakes/*

    PROMPT "HANDSHAKES

$REMOVED

DELETED"
fi
;;


"RECON Data ($RECON_SIZE)")

CONFIRM=$(LIST_PICKER \
"Delete RECON Data ($RECON_SIZE)?" \
"NO" \
"YES" \
"NO")

if [ "$CONFIRM" = "YES" ]; then

    REMOVED="$RECON_SIZE"

    rm -f /root/recon/recon.db
    rm -f /root/recon/blue5.db

    /etc/init.d/pineapd restart
    /etc/init.d/blue5 restart

    PROMPT "RECON DATA

$REMOVED

DELETED"
fi
;;


"Wigle Data ($WIGLE_SIZE)")

CONFIRM=$(LIST_PICKER \
"Delete Wigle Data ($WIGLE_SIZE)?" \
"NO" \
"YES" \
"NO")

if [ "$CONFIRM" = "YES" ]; then

    REMOVED="$WIGLE_SIZE"

    rm -f /root/loot/wigle/*

    PROMPT "WIGLE DATA

$REMOVED

DELETED"
fi
;;

esac
;;
"About")
PROMPT "WHATSRUNNING

Version 2.0

Native Pager Utility

Created by Graham"
;;

"Exit")
exit 0
;;

esac

done

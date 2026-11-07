#!/bin/sh
#
# What's Running? - WiFi Pineapple Pager utility
# System monitoring, RECON visibility, storage management, safe capture cleanup.
#
# NOTE: busybox/ash compatible (no bashisms). If your pager runs payloads under
# bash specifically, this still works; /bin/sh keeps it portable on OpenWrt.

SCRIPT_DIR=$(dirname "$0")

# Shared helper: check_service() prints running services in a uniform format.
. "$SCRIPT_DIR/lib/services.sh"

# ── helpers ────────────────────────────────────────────────────────────────
# Metrics are computed lazily (only inside the menu branch that needs them) so
# the monitor itself doesn't thrash the CPU/SD card on every redraw.

# Read a 0/1 option from a UCI config file (first match wins).
config_flag() {
    # $1 = config file, $2 = option name
    grep -m1 "$2" "$1" 2>/dev/null | grep -o "[01]" | head -n1
}

# Human-readable size of a directory (0 if missing/empty).
dir_size() {
    s=$(du -sh "$1" 2>/dev/null | awk '{print $1}')
    echo "${s:-0}"
}

# Human-readable size of a single file ("Not Found" if absent).
file_size() {
    [ -f "$1" ] || { echo "Not Found"; return; }
    du -h "$1" 2>/dev/null | awk '{print $1}'
}

# Battery percentage (fuel gauge sysfs; "--" if unavailable).
battery_level() {
    lvl=$(cat /sys/devices/platform/10000000.palmbus/10000900.i2c/i2c-0/0-0055/power_supply/bq27546-0/capacity 2>/dev/null)
    echo "${lvl:-"--"}"
}

# CPU idle percentage from a single busybox `top` sample (0 if unreadable).
cpu_idle() {
    idle=$(top -bn1 | awk '/^CPU:/ {gsub(/%/,"",$8); print $8; exit}')
    echo "${idle:-0}"
}

health_from_idle() {
    idle=${1:-0}
    if [ "$idle" -gt 75 ] 2>/dev/null; then
        echo "GOOD"
    elif [ "$idle" -gt 50 ] 2>/dev/null; then
        echo "MODERATE"
    else
        echo "HIGH LOAD"
    fi
}

recon_status() {
    [ "$(config_flag /etc/config/pineapd logrecon)" = "1" ] && echo "ENABLED" || echo "DISABLED"
}

bt_mode() {
    [ "$(config_flag /etc/config/blue5 active)" = "1" ] && echo "ACTIVE" || echo "PASSIVE"
}

# ── main menu loop ──────────────────────────────────────────────────────────
while true
do

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
"System Health")

case "$CHOICE" in
"System Health")
IDLE=$(cpu_idle)
PROMPT "SYSTEM HEALTH

Battery:
$(battery_level)%

CPU:
$(health_from_idle "$IDLE")

RECON:
$(recon_status)

PCAPs:
$(dir_size /root/loot/pcap)"
;;

"CPU Status")
IDLE=$(cpu_idle)
LOAD=$((100 - IDLE))
PROMPT "CPU STATUS

Load:
${LOAD}%

Idle:
${IDLE}%

Health:
$(health_from_idle "$IDLE")"
;;

"Memory")
MEM_LINE=$(top -bn1 | grep "^Mem:")
USED_KB=$(echo "$MEM_LINE" | awk '{print $2}' | tr -d 'K')
FREE_KB=$(echo "$MEM_LINE" | awk '{print $4}' | tr -d 'K')
USED_KB=${USED_KB:-0}
FREE_KB=${FREE_KB:-0}
PROMPT "MEMORY

Used:
$((USED_KB / 1024)) MB

Free:
$((FREE_KB / 1024)) MB"
;;

"Battery")
PROMPT "BATTERY

Level:
$(battery_level)%"
;;

"RECON Status")
PROMPT "RECON STATUS

RECON:
$(recon_status)

WiFi Data:
$(file_size /root/recon/recon.db)"
;;

"Bluetooth Status")
PROMPT "BLUETOOTH STATUS

Mode:
$(bt_mode)

BT Data:
$(file_size /root/recon/blue5.db)"
;;

"Running Services")
SERVICES=$(
    check_service pineapd  "Wireless Recon"
    check_service hostapd  "Access Point"
    check_service blue5    "Bluetooth Recon"
    check_service dnsmasq  "DNS / DHCP"
)
[ -z "$SERVICES" ] && SERVICES="No monitored services running."
PROMPT "RUNNING SERVICES

$SERVICES"
;;

"Storage")
LOOT_MB=$(du -sm /root/loot 2>/dev/null | awk '{print $1}')
RECON_MB=$(du -sm /root/recon 2>/dev/null | awk '{print $1}')
LOOT_MB=${LOOT_MB:-0}
RECON_MB=${RECON_MB:-0}
PROMPT "STORAGE

PCAPs:
$(dir_size /root/loot/pcap)

RECON:
$(dir_size /root/recon)

Handshakes:
$(dir_size /root/loot/handshakes)

Wigle:
$(dir_size /root/loot/wigle)

Total:
$((LOOT_MB + RECON_MB))M"
;;

"Clear Data")

PCAP_SIZE=$(dir_size /root/loot/pcap)
HANDSHAKE_SIZE=$(dir_size /root/loot/handshakes)
RECON_SIZE=$(dir_size /root/recon)
WIGLE_SIZE=$(dir_size /root/loot/wigle)

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

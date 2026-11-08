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

# CPU idle percentage. busybox `top`'s first sample has no delta to measure
# against, so take two (1s apart) and read the second. Empty if unreadable, so
# a failed read doesn't masquerade as 100% load.
cpu_idle() {
    top -bn2 -d1 2>/dev/null | awk '/^CPU:/ {gsub(/%/,"",$8); v=$8} END {print v}'
}

# UNKNOWN (not HIGH LOAD) when idle isn't a number.
health_from_idle() {
    idle=$1
    case "$idle" in
        ''|*[!0-9]*) echo "UNKNOWN"; return ;;
    esac
    if [ "$idle" -gt 75 ]; then
        echo "GOOD"
    elif [ "$idle" -gt 50 ]; then
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

# Report a Clear Data result from what's actually left on disk, not what was
# there before the rm. Checks for leftover entries rather than size: an empty
# directory still measures 4.0K on the pager's storage.
# $1 = title, $2 = size before, $3 = directory that was cleared
clear_result() {
    if [ -z "$(ls -A "$3" 2>/dev/null)" ]; then
        PROMPT "$1

$2

DELETED"
    else
        PROMPT "$1

Remaining:
$(dir_size "$3")

PARTIAL"
    fi
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
case "$IDLE" in
    ''|*[!0-9]*) LOAD="--"; IDLE_DISP="--" ;;
    *)           LOAD=$((100 - IDLE)); IDLE_DISP="$IDLE" ;;
esac
PROMPT "CPU STATUS

Load:
${LOAD}%

Idle:
${IDLE_DISP}%

Health:
$(health_from_idle "$IDLE")"
;;

"Memory")
MEM_LINE=$(top -bn1 2>/dev/null | grep "^Mem:")
USED_KB=$(echo "$MEM_LINE" | awk '{print $2}' | tr -d 'K')
FREE_KB=$(echo "$MEM_LINE" | awk '{print $4}' | tr -d 'K')
case "$USED_KB" in ''|*[!0-9]*) USED_MB="--" ;; *) USED_MB=$((USED_KB / 1024)) ;; esac
case "$FREE_KB" in ''|*[!0-9]*) FREE_MB="--" ;; *) FREE_MB=$((FREE_KB / 1024)) ;; esac
PROMPT "MEMORY

Used:
${USED_MB} MB

Free:
${FREE_MB} MB"
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
# Same human-readable units as the per-category sizes below.
TOTAL=$(du -sch /root/loot /root/recon 2>/dev/null | awk '/total$/ {print $1}')
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
${TOTAL:-0}"
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
    rm -rf /root/loot/pcap/* 2>/dev/null
    clear_result "PCAP FILES" "$PCAP_SIZE" /root/loot/pcap
fi
;;

"Handshakes ($HANDSHAKE_SIZE)")
CONFIRM=$(LIST_PICKER \
"Delete Handshakes ($HANDSHAKE_SIZE)?" \
"NO" \
"YES" \
"NO")
if [ "$CONFIRM" = "YES" ]; then
    rm -rf /root/loot/handshakes/* 2>/dev/null
    clear_result "HANDSHAKES" "$HANDSHAKE_SIZE" /root/loot/handshakes
fi
;;

"RECON Data ($RECON_SIZE)")
CONFIRM=$(LIST_PICKER \
"Delete RECON Data ($RECON_SIZE)?" \
"NO" \
"YES" \
"NO")
if [ "$CONFIRM" = "YES" ]; then
    rm -f /root/recon/recon.db /root/recon/blue5.db
    # Check the files are gone before restarting: the services recreate them,
    # so a size check afterwards would always look like a partial delete.
    if [ ! -f /root/recon/recon.db ] && [ ! -f /root/recon/blue5.db ]; then
        /etc/init.d/pineapd restart
        /etc/init.d/blue5 restart
        PROMPT "RECON DATA

$RECON_SIZE

DELETED"
    else
        PROMPT "RECON DATA

Could not remove
(in use?)

FAILED"
    fi
fi
;;

"Wigle Data ($WIGLE_SIZE)")
CONFIRM=$(LIST_PICKER \
"Delete Wigle Data ($WIGLE_SIZE)?" \
"NO" \
"YES" \
"NO")
if [ "$CONFIRM" = "YES" ]; then
    rm -rf /root/loot/wigle/* 2>/dev/null
    clear_result "WIGLE DATA" "$WIGLE_SIZE" /root/loot/wigle
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

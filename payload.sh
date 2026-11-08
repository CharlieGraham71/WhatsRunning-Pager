#!/bin/sh
#
# What's Running? - WiFi Pineapple Pager utility
# System monitoring, RECON visibility, storage management, safe capture cleanup.
#
# NOTE: busybox/ash compatible (no bashisms). If your pager runs payloads under
# bash specifically, this still works; /bin/sh keeps it portable on OpenWrt.

# The Pager's payload launcher runs us with a trimmed PATH that omits
# /usr/bin, so tools like pgrep aren't found. Put the standard dirs back or
# detection (and uci/init calls) silently find nothing.
export PATH="/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

# Helpers are INLINED (not sourced from lib/) on purpose: the Pager's payload
# launcher copies only this file to /tmp and runs it there, so $0's directory
# has no lib/ and any `. lib/...` would silently fail. The lib/*.sh files in
# the repo mirror these for readability. Keep the two in sync.

# proc_updown NAME -> "UP" | "DOWN". pidof lives in /bin (always on PATH).
proc_updown() {
    pidof "$1" >/dev/null 2>&1 && echo "UP" || echo "DOWN"
}

# svc_state NAME -> "running" | "stopped" (an /etc/init.d service).
svc_state() {
    if /etc/init.d/"$1" status 2>/dev/null | grep -qi running; then
        echo "running"
    elif pidof "$1" >/dev/null 2>&1 || pgrep "$1" >/dev/null 2>&1; then
        echo "running"
    else
        echo "stopped"
    fi
}

# Bluetooth recon is the blue5 daemon's database scan. The blue5 process is
# respawned by the Pineapple supervisor if stopped, so don't stop the process
# — control the scan over its socket with blue5ctl (end = stop collecting,
# new = start). The "db" status field is the live on/off.
bt_recon_state() {
    case "$(blue5ctl status 2>/dev/null | awk '/^db /{print $2}')" in
        logging) echo "ON" ;;
        ended)   echo "OFF" ;;
        *)       echo "--" ;;
    esac
}
bt_recon_set() {
    case "$1" in
        off) blue5ctl end >/dev/null 2>&1 ;;
        on)  blue5ctl new >/dev/null 2>&1 ;;   # no name = keep current scan name
    esac
}

# PineAP: pineapd is respawned by the Pineapple supervisor, so toggle the
# pineap_disabled flag it reads (0 = on, 1 = off) and reload, don't stop it.
pineap_state() {
    [ "$(uci -q get pineapd.@hostapd[0].pineap_disabled)" = "1" ] && echo "OFF" || echo "ON"
}
pineap_set() {
    case "$1" in
        off) uci set pineapd.@hostapd[0].pineap_disabled='1' 2>/dev/null ;;
        on)  uci set pineapd.@hostapd[0].pineap_disabled='0' 2>/dev/null ;;
        *)   return ;;
    esac
    uci commit pineapd 2>/dev/null
    /etc/init.d/pineapd reload >/dev/null 2>&1
}

# recon logging: toggle logrecon without stopping PineAP. Applies now only if
# pineapd is up; otherwise it takes effect on the next start.
recon_logging_set() {
    uci set pineapd.@pineapd[0].logrecon="$1" 2>/dev/null
    uci commit pineapd 2>/dev/null
    if [ "$(svc_state pineapd)" = "running" ]; then
        /etc/init.d/pineapd reload >/dev/null 2>&1
    fi
}

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

# Load % (100 - idle), or "--" when idle isn't a number.
load_from_idle() {
    case "$1" in
        ''|*[!0-9]*) echo "--" ;;
        *) echo "$((100 - $1))%" ;;
    esac
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
"Service Control" \
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
"Service Control")

case "$CHOICE" in
"System Health")
IDLE=$(cpu_idle)
PROMPT "SYSTEM HEALTH

Battery:
$(battery_level)%

CPU:
$(load_from_idle "$IDLE") load

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
# pineapd and blue5 always run (the supervisor respawns them), so their process
# says nothing; show the feature state Service Control actually toggles.
PROMPT "RUNNING SERVICES

PineAP:
$(pineap_state)

Recon Log:
$(recon_status)

Bluetooth:
$(bt_recon_state)

Access Point:
$(proc_updown hostapd)

DNS / DHCP:
$(proc_updown dnsmasq)"
;;

"Service Control")

PINEAP_STATE=$(pineap_state)
BLUE_STATE=$(bt_recon_state)
RECON_STATE=$(recon_status)

SVC_CHOICE=$(LIST_PICKER \
"Service Control" \
"PineAP: $PINEAP_STATE" \
"Bluetooth: $BLUE_STATE" \
"Recon Log: $RECON_STATE" \
"Back" \
"Back")

case "$SVC_CHOICE" in

"PineAP: $PINEAP_STATE")
# pineapd is respawned by the Pineapple supervisor, so toggle the PineAP flag
# rather than stopping the process.
if [ "$PINEAP_STATE" = "ON" ]; then
    CONFIRM=$(LIST_PICKER "Turn PineAP OFF?" "NO" "YES" "NO")
    if [ "$CONFIRM" = "YES" ]; then
        pineap_set off
        PROMPT "PINEAP

$(pineap_state)"
    fi
else
    CONFIRM=$(LIST_PICKER "Turn PineAP ON?" "NO" "YES" "NO")
    if [ "$CONFIRM" = "YES" ]; then
        pineap_set on
        PROMPT "PINEAP

$(pineap_state)"
    fi
fi
;;

"Bluetooth: $BLUE_STATE")
if [ "$BLUE_STATE" = "ON" ]; then
    CONFIRM=$(LIST_PICKER "Stop Bluetooth Recon?" "NO" "YES" "NO")
    if [ "$CONFIRM" = "YES" ]; then
        bt_recon_set off
        PROMPT "BLUETOOTH RECON

$(bt_recon_state)"
    fi
else
    CONFIRM=$(LIST_PICKER "Start Bluetooth Recon?" "NO" "YES" "NO")
    if [ "$CONFIRM" = "YES" ]; then
        bt_recon_set on
        PROMPT "BLUETOOTH RECON

$(bt_recon_state)"
    fi
fi
;;

"Recon Log: $RECON_STATE")
# Recon is a pineapd mode, not a service: toggling it leaves PineAP running.
if [ "$RECON_STATE" = "ENABLED" ]; then
    CONFIRM=$(LIST_PICKER "Turn Recon Logging OFF?" "NO" "YES" "NO")
    [ "$CONFIRM" = "YES" ] && recon_logging_set 0
else
    CONFIRM=$(LIST_PICKER "Turn Recon Logging ON?" "NO" "YES" "NO")
    [ "$CONFIRM" = "YES" ] && recon_logging_set 1
fi
if [ "$CONFIRM" = "YES" ]; then
    PROMPT "RECON LOGGING

$(recon_status)

PineAP:
$(svc_state pineapd)"
fi
;;

esac
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

Version 2.2.4

Native Pager Utility

Created by Graham"
;;

"Exit")
exit 0
;;

esac

done

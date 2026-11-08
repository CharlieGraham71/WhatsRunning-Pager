# lib/kill.sh — service control for the "Service Control" screen.
# NOTE: payload.sh inlines these; this file is a readable mirror. Keep in sync.
#
# None of these services can be stopped by killing their process: pineapd and
# blue5 are supervised by the Pineapple master, which respawns them within a
# second. So each is controlled the way the firmware itself does it:
#
#   PineAP   -> pineap_disabled config flag + pineapd reload
#   Recon    -> logrecon config flag + pineapd reload
#   Bluetooth-> blue5ctl over the daemon's socket (end = stop, new = start)

# svc_state NAME -> "running" | "stopped"; used by recon_logging_set.
svc_state() {
    if /etc/init.d/"$1" status 2>/dev/null | grep -qi running; then
        echo "running"
    elif pidof "$1" >/dev/null 2>&1 || pgrep "$1" >/dev/null 2>&1; then
        echo "running"
    else
        echo "stopped"
    fi
}

# ── Bluetooth: control the scan over blue5's socket, not the process ─────────

# bt_recon_state -> "ON" | "OFF" | "--" from blue5ctl's db field.
bt_recon_state() {
    case "$(blue5ctl status 2>/dev/null | awk '/^db /{print $2}')" in
        logging) echo "ON" ;;
        ended)   echo "OFF" ;;
        *)       echo "--" ;;
    esac
}

# bt_recon_set on|off -> end/new the blue5 database scan (daemon stays up).
bt_recon_set() {
    case "$1" in
        off) blue5ctl end >/dev/null 2>&1 ;;
        on)  blue5ctl new >/dev/null 2>&1 ;;   # no name = keep current scan name
    esac
}

# ── PineAP: a config flag, not a process ─────────────────────────────────────

# pineap_state -> "ON" | "OFF" (pineap_disabled: 0 = on, 1 = off).
pineap_state() {
    [ "$(uci -q get pineapd.@hostapd[0].pineap_disabled)" = "1" ] && echo "OFF" || echo "ON"
}

# pineap_set on|off -> set the flag and reload pineapd so it takes effect.
# pineapd keeps running either way; only PineAP is enabled/disabled.
pineap_set() {
    case "$1" in
        off) uci set pineapd.@hostapd[0].pineap_disabled='1' 2>/dev/null ;;
        on)  uci set pineapd.@hostapd[0].pineap_disabled='0' 2>/dev/null ;;
        *)   return ;;
    esac
    uci commit pineapd 2>/dev/null
    /etc/init.d/pineapd reload >/dev/null 2>&1
}

# ── recon logging: a config flag on pineapd ──────────────────────────────────

# recon_logging_set 0|1 -> toggle recon logging without stopping PineAP.
# Applies immediately only if pineapd is up; otherwise it takes effect on the
# next start (we don't start pineapd here).
recon_logging_set() {
    uci set pineapd.@pineapd[0].logrecon="$1" 2>/dev/null
    uci commit pineapd 2>/dev/null
    if [ "$(svc_state pineapd)" = "running" ]; then
        /etc/init.d/pineapd reload >/dev/null 2>&1
    fi
}

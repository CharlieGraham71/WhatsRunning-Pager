# lib/kill.sh — service control for the "Service Control" screen.
#
# Three different mechanisms, because the services are managed differently:
#
#   Bluetooth (blue5) is a normal procd service -> stop/start via its init
#   script actually holds.
#
#   PineAP and recon are driven by pineapd, which is supervised by the
#   Pineapple master process. If you stop pineapd it is respawned within a
#   second, so you do NOT stop the process. Instead flip the config flags
#   pineapd reads and reload it: pineap_disabled for PineAP, logrecon for
#   recon logging.

# ── blue5: a real service ───────────────────────────────────────────────────

# svc_state NAME -> "running" | "stopped" (for an /etc/init.d service).
svc_state() {
    if /etc/init.d/"$1" status 2>/dev/null | grep -qi running; then
        echo "running"
    elif pgrep "$1" >/dev/null 2>&1; then
        echo "running"
    else
        echo "stopped"
    fi
}

# svc_stop NAME LABEL -> PROMPT body; confirms it actually stopped.
svc_stop() {
    /etc/init.d/"$1" stop >/dev/null 2>&1
    sleep 1
    if [ "$(svc_state "$1")" = "stopped" ]; then
        echo "$2

STOPPED"
    else
        echo "$2

STILL RUNNING
(respawned?)"
    fi
}

# svc_start NAME LABEL -> PROMPT body; confirms it came up.
svc_start() {
    /etc/init.d/"$1" start >/dev/null 2>&1
    sleep 1
    if [ "$(svc_state "$1")" = "running" ]; then
        echo "$2

STARTED"
    else
        echo "$2

FAILED TO START"
    fi
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

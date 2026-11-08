# lib/services.sh — mirror of the helper payload.sh inlines. Keep in sync.
# proc_updown NAME -> "UP" | "DOWN". pidof lives in /bin (always on PATH).
proc_updown() {
    pidof "$1" >/dev/null 2>&1 && echo "UP" || echo "DOWN"
}

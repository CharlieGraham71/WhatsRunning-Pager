# lib/services.sh — sourced by payload.sh.
# check_service NAME DESC: prints a uniform block if process NAME is running.
check_service() {
    NAME="$1"
    DESC="$2"

    # pidof lives in /bin (always on PATH); pgrep is only in /usr/bin, which
    # the Pager's payload launcher may drop. Use pidof and take the first pid
    # with pure shell so this needs no awk/head either.
    PID=$(pidof "$NAME" 2>/dev/null)
    PID=${PID%% *}

    if [ -n "$PID" ]; then
        echo "[+] $NAME"
        echo "    $DESC"
        echo "    PID: $PID"
        echo
    fi
}

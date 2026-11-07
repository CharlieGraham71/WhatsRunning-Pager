# lib/services.sh — sourced by payload.sh.
# check_service NAME DESC: prints a uniform block if process NAME is running.
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

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

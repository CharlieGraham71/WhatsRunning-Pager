# lib/kill.sh — staged helper for the planned "Process termination" feature.
# Only pineapd/blue5 are killable; everything else is reported as protected so
# the user can't stop a critical service by accident. Not yet sourced by
# payload.sh; wired in when that feature ships.
kill_service() {

    SERVICE="$1"

    case "$SERVICE" in
        pineapd)
            killall pineapd
            echo "[STOPPED] Wireless Recon"
            ;;
        blue5)
            killall blue5
            echo "[STOPPED] Bluetooth Recon"
            ;;
        *)
            echo "[PROTECTED SERVICE]"
            ;;
    esac

}

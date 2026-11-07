# lib/managed.sh — staged helper for the planned "Process termination" feature.
# Reports whether a service is managed/auto-restarted. Not yet sourced by
# payload.sh; wired in when that feature ships.
managed_service() {

    SERVICE="$1"

    case "$SERVICE" in
        pineapd|blue5)
            echo "    Managed: YES"
            echo "    Auto-Restart: YES"
            ;;
        *)
            echo "    Managed: Unknown"
            ;;
    esac

}

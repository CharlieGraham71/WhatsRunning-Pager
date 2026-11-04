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

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

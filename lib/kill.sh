kill_service() {

    case "$1" in
        pineapd)
            pkill pineapd
            ;;
        blue5)
            pkill blue5
            ;;
        *)
            echo "Protected service"
            ;;
    esac

}

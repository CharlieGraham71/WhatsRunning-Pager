show_recon_stats() {

    echo "Recon Data"
    echo "----------"

    if [ -f /root/recon/recon.db ]; then
        SIZE=$(du -h /root/recon/recon.db | awk '{print $1}')
        echo "Wireless DB: $SIZE"
        echo "Status: ACTIVE"
        echo
    fi

    if [ -f /root/recon/blue5.db ]; then
        SIZE=$(du -h /root/recon/blue5.db | awk '{print $1}')
        echo "Bluetooth DB: $SIZE"
        echo "Status: ACTIVE"
        echo
    fi

}

#!/bin/bash

DEVICE="Blossom"
ANDROID_VERSION="16"
START_TIME=$(date +%s)
MAINTAINER="fiyuu"

while true; do
    clear
    echo "=================================================="
    echo "           BUILDING AVIUM - BLOSSOM               "
    echo "=================================================="
    echo "1) Run Build (envsetup, lunch, m bacon)"
    echo "2) Run fix script"
    echo "3) Exit"
    echo "=================================================="
    read -p "Select an option [1-3]: " choice

    case $choice in
        1)
            echo "[*] Setting up environment and starting build..."
            . build/envsetup.sh
            export BUILD_USERNAME=fiyuu
            export BUILD_HOSTNAME=kiyuu
            export IGNORE_PATCH_ERRORS=true
            lunch lineage_blossom-bp4a-userdebug
            m bacon -j8
            break
            ;;
        2)
            echo "[*] Running fix script..."
            curl -sSL https://raw.githubusercontent.com/kitsunee02/rom-patches/refs/heads/main/avium16_2/fix_and_sign.sh | bash
            echo "[+] Running fix script done!"
            ;;
        3)
            echo "Exiting script."
            exit 0
            ;;
        *)
            echo "[-] Invalid choice. Please select 1, 2, or 3."
            ;;
    esac
    echo ""
done

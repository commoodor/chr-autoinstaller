#!/bin/bash
set -e

echo "============================================"
echo " MikroTik CHR Auto Installer"
echo " Supports Official & Mirror (GitHub patched)"
echo "============================================"

# --- get latest v6 & v7 from official ---
get_versions() {
    echo "[+] Fetching latest RouterOS versions..."
    PAGE=$(curl -s https://mikrotik.com/download)

    V6_VERSION=$(echo "$PAGE" | grep -oP 'RouterOS v6.*stable.*\K\d+\.\d+\.\d+' | head -n1)
    V7_VERSION=$(echo "$PAGE" | grep -oP 'RouterOS v7.*stable.*\K\d+\.\d+\.\d+' | head -n1)

    if [[ -z $V6_VERSION || -z $V7_VERSION ]]; then
        echo "[-] Failed to fetch versions, default fallback"
        V6_VERSION="6.49.19"
        V7_VERSION="7.15.3"
    fi

    echo "[+] Latest v6: $V6_VERSION"
    echo "[+] Latest v7: $V7_VERSION"
}

# --- select source ---
select_source() {
    echo "Select download source:"
    echo "1) Official (mikrotik.com)"
    echo "2) Mirror (GitHub patched)"
    echo "3) Exit"
    read -p "Enter choice (1-3): " SRC
    case $SRC in
        1) SOURCE="official" ;;
        2) SOURCE="mirror" ;;
        3) exit 0 ;;
        *) echo "Invalid"; select_source ;;
    esac
}

# --- select version ---
select_version() {
    echo "Select RouterOS version:"
    echo "1) RouterOS v6 ($V6_VERSION)"
    echo "2) RouterOS v7 ($V7_VERSION)"
    echo "3) Exit"
    read -p "Enter choice (1-3): " VER
    case $VER in
        1) SELECTED_VERSION="$V6_VERSION" ;;
        2) SELECTED_VERSION="$V7_VERSION" ;;
        3) exit 0 ;;
        *) echo "Invalid"; select_version ;;
    esac
    echo "[+] Selected RouterOS Version: $SELECTED_VERSION"
}

# --- select BIOS type ---
select_bios() {
    echo "Select BIOS type:"
    echo "1) UEFI"
    echo "2) Legacy BIOS"
    read -p "Enter choice (1-2): " BIOS
    case $BIOS in
        1) BIOS_TYPE="uefi" ;;
        2) BIOS_TYPE="bios" ;;
        *) echo "Invalid"; select_bios ;;
    esac
    echo "[+] Selected BIOS type: $BIOS_TYPE"
}

# --- build URL ---
build_url() {
    if [[ $SOURCE == "official" ]]; then
        if [[ $BIOS_TYPE == "bios" ]]; then
            URL="https://download.mikrotik.com/routeros/$SELECTED_VERSION/chr-$SELECTED_VERSION-legacy-bios.img.zip"
        else
            URL="https://download.mikrotik.com/routeros/$SELECTED_VERSION/chr-$SELECTED_VERSION.img.zip"
        fi
    else
        URL="https://github.com/elseif/MikroTikPatch/releases/download/$SELECTED_VERSION/chr-$SELECTED_VERSION.img.zip"
    fi
    echo "[+] Download URL: $URL"
}

# --- download image ---
download_image() {
    echo "[+] Downloading image..."
    curl -L --progress-bar "$URL" -o chr.img.zip
}

# --- extract image safely ---
extract_image() {
    echo "[+] Extracting image..."
    rm -f chr.img
    unzip -j chr.img.zip '*.img' -d . || { echo "[-] Failed to unzip"; exit 1; }
    mv -f ./*.img chr.img
}

# --- select target disk ---
select_disk() {
    echo "[+] Available disks:"
    lsblk -d -o NAME,SIZE,MODEL
    read -p "Enter target disk (example: sda): " DISK
    TARGET="/dev/$DISK"
    echo "[!] WARNING: All data on $TARGET will be erased!"
    read -p "Type YES to continue: " CONFIRM
    [[ $CONFIRM == "YES" ]] || { echo "[-] Aborted."; exit 1; }
}

# --- write image ---
write_image() {
    echo "[+] Flashing image to $TARGET ..."
    dd if=chr.img of=$TARGET bs=4M status=progress oflag=sync
    sync
}

# --- mount and add autorun script ---
configure_autorun() {
    echo "[+] Configuring autorun..."
    mkdir -p /mnt/chr
    mount -o loop,offset=512 chr.img /mnt/chr || { echo "[-] Mount failed"; return; }
    cat <<'EOF' > /mnt/chr/rw/autorun.scr
/user add name=admin password=admin123 group=full
/ip service enable ssh
EOF
    umount /mnt/chr
}

# --- cleanup ---
cleanup() {
    rm -f chr.img chr.img.zip
    echo "[+] Installation complete!"
    echo "Login: admin / admin123"
}

# =====================
# Main
# =====================
get_versions
select_source
select_version
select_bios
build_url
download_image
extract_image
select_disk
write_image
configure_autorun
cleanup

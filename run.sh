#!/bin/bash

# Must be root!
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Function to display a progress bar
progress_bar() {
    local PROGRESS=$1
    local TOTAL=$2
    local FILL=$((PROGRESS * 40 / TOTAL))
    local EMPTY=$((40 - FILL))

    # Display the progress bar
    printf "\r["
    printf "%0.s#" $(seq 1 $FILL)
    printf "%0.s-" $(seq 1 $EMPTY)
    printf "] $PROGRESS/$TOTAL"
}

# Function to fetch the latest stable version for RouterOS v6 and v7
get_latest_version() {
    # Get storage device (first disk found)
    STORAGE=$(lsblk -o NAME,TYPE | grep disk | awk '{print $1}' | head -n 1)
    echo "[+] STORAGE : $STORAGE"

    # Get Ethernet interface
    ETH=$(ip route show default | awk '{print $5}')
    echo "[+] INTERFACE : $ETH"

    # Get IP address for the Ethernet interface
    ADDRESS=$(ip addr show $ETH | grep global | awk '{print $2}' | head -n 1)
    echo "[+] IP ADDRESS : $ADDRESS"

    # Get Gateway address
    GATEWAY=$(ip route list | grep default | awk '{print $3}')
    echo "[+] GATEWAY : $GATEWAY"

    # Get the latest RouterOS versions
    echo "[+] Fetching latest Cloud Hosted Router ..."
	# URL of the MikroTik download page
    URL="https://mikrotik.com/download"
    HTML_CONTENT=$(curl -s "$URL")

    # Extract the latest versions for RouterOS v6 and v7 Cloud Hosted Router images
    # Look for the "Cloud Hosted Router" section and capture version numbers
    V6_VERSION=$(echo "$HTML_CONTENT" | grep -oP '(?<=<a href="https://download.mikrotik.com/routeros/)[^"]*6[.0-9]*[^"]*' | grep -oP '6[.0-9]*' | head -n 1)
    V7_VERSION=$(echo "$HTML_CONTENT" | grep -oP '(?<=<a href="https://download.mikrotik.com/routeros/)[^"]*7[.0-9]*[^"]*' | grep -oP '7[.0-9]*' | head -n 1)

}

# Function to select the version
select_version() {
    echo "1) RouterOS v6: $V6_VERSION"
    echo "2) RouterOS v7: $V7_VERSION"
    echo "3) Exit"

    read -p "Enter your choice (1, 2, or 3): " choice

    case $choice in
        1)
            SELECTED_VERSION="$V6_VERSION"
            ;;
        2)
            SELECTED_VERSION="$V7_VERSION"
            ;;
        3)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid selection. Please try again."
            select_version
            ;;
    esac

    echo "[+] Selected RouterOS Version: $SELECTED_VERSION"
}

# Main script logic
echo "[1] Preparation"
echo "Updating system packages..."
apt update -y -o Dpkg::Progress-Fancy="1" && apt upgrade -y -o Dpkg::Progress-Fancy="1"
apt install unzip wget -y
clear
sleep 3

echo "[2] Getting Information"
get_latest_version

echo "[3] Select RouterOS Version"
select_version

# Proceed with downloading and flashing the selected version
echo "[4] Proceeding with RouterOS Version: $SELECTED_VERSION"
sleep 3

# Download RouterOS image with progress
echo "[+] Downloading RouterOS image for version $SELECTED_VERSION..."
URL="https://download.mikrotik.com/routeros/$SELECTED_VERSION/chr-$SELECTED_VERSION.img.zip"
wget --progress=dot:giga "$URL" -O chr.img.zip || { echo "Download failed."; exit 1; }

# Unzip with progress bar
echo "[+] Unzipping RouterOS image..."
unzip -o chr.img.zip | while read line; do
    # Only display progress for lines starting with "inflating"
    if [[ $line == *"inflating"* ]]; then
        echo -n "."  # Print a dot for each file extracted
    fi
done
echo ""

# Mount image, configure, and unmount
echo "[+] Mounting image..."
MOUNT_POINT="/mnt"
mkdir -p $MOUNT_POINT
mount -o loop,offset=$((1 * 512)) chr.img $MOUNT_POINT || { echo "Mount failed."; exit 1; }

echo "[+] Configuring RouterOS settings..."
echo "/ip address add address=$ADDRESS interface=[/interface ethernet find where name=ether1]" > $MOUNT_POINT/rw/autorun.scr
echo "/ip route add gateway=$GATEWAY" >> $MOUNT_POINT/rw/autorun.scr
echo "/ip service disable telnet" >> $MOUNT_POINT/rw/autorun.scr
echo "/system ntp client set enabled=yes primary-ntp=0.id.pool.ntp.org secondary-ntp=1.id.pool.ntp.org" >> $MOUNT_POINT/rw/autorun.scr
echo "/ip dns set server=8.8.8.8,1.1.1.1" >> $MOUNT_POINT/rw/autorun.scr

umount $MOUNT_POINT || { echo "Unmount failed."; exit 1; }

# Flash the image onto the disk with progress bar
echo "[5] Flashing the image to disk..."
IMG_FILE="chr.img"
FLASH_TARGET="/dev/vda"
TOTAL_BLOCKS=$(stat --format=%s $IMG_FILE)
BLOCK_SIZE=1024
BLOCKS=$((TOTAL_BLOCKS / BLOCK_SIZE))

dd if=$IMG_FILE bs=$BLOCK_SIZE of=$FLASH_TARGET status=progress || { echo "dd failed."; exit 1; }

# Trigger a reboot
echo "[6] Complete. Rebooting now..."
sync
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger

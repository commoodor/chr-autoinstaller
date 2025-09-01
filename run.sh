#!/bin/bash

# Must be root!
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

# Function to select source
select_source() {
  echo "Select download source:"
  echo "1) Official (mikrotik.com)"
  echo "2) Mirror (GitHub patched via MikroTikPatch)"
  echo "3) Exit"
  read -p "Enter choice (1-3): " choice
  case $choice in
    1) SOURCE="official" ;;
    2) SOURCE="mirror" ;;
    3) exit 0 ;;
    *) echo "Invalid choice."; select_source ;;
  esac
}

# Fetch latest v6 & v7 from official site
get_latest_versions() {
  URL="https://mikrotik.com/download"
  HTML=$(curl -s "$URL")
  V6=$(echo "$HTML" | grep -oP '(?<=routeros/)[0-9.]+(?=/chr-[0-9.]+\.img\.zip)' | grep '^6' | sort -Vr | head -n1)
  V7=$(echo "$HTML" | grep -oP '(?<=routeros/)[0-9.]+(?=/chr-[0-9.]+\.img\.zip)' | grep '^7' | sort -Vr | head -n1)
}

# Function to select version
select_version() {
  echo "1) RouterOS v6: $V6"
  echo "2) RouterOS v7: $V7"
  echo "3) Exit"
  read -p "Enter your choice (1, 2, or 3): " choice
  case $choice in
    1) SELECTED_VERSION="$V6" ;;
    2) SELECTED_VERSION="$V7" ;;
    3) exit 0 ;;
    *) echo "Invalid selection."; select_version ;;
  esac
  echo "[+] Selected RouterOS Version: $SELECTED_VERSION"
}

# Detect UEFI vs BIOS
detect_boot_mode() {
  if [[ -d /sys/firmware/efi ]]; then
    BOOT_MODE="uefi"
  else
    BOOT_MODE="bios"
  fi
  echo "[+] Detected boot mode: $BOOT_MODE"
}

# Collect environment info
get_env_info() {
  STORAGE=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk"{print $1;exit}')
  ETH=$(ip route show default | awk '{print $5}' | head -n1)
  ADDRESS=$(ip addr show $ETH | grep global | awk '{print $2}' | head -n1)
  GATEWAY=$(ip route | grep '^default' | awk '{print $3}')
  echo "[+] STORAGE   : $STORAGE"
  echo "[+] INTERFACE : $ETH"
  echo "[+] IP ADDR   : $ADDRESS"
  echo "[+] GATEWAY   : $GATEWAY"
}

# --- Main ---
echo "[1] Preparation"
apt update -y -o Dpkg::Progress-Fancy="1" && apt upgrade -y -o Dpkg::Progress-Fancy="1"
apt install -y unzip wget curl
clear

echo "[2] Select Source"
select_source

echo "[3] Fetching latest versions..."
get_latest_versions

echo "[4] Select RouterOS Version"
select_version

echo "[5] Detecting boot mode..."
detect_boot_mode

echo "[6] Collecting system info..."
get_env_info

# Decide download URL
if [[ $SOURCE == "official" ]]; then
  URL="https://download.mikrotik.com/routeros/$SELECTED_VERSION/chr-$SELECTED_VERSION.img.zip"
else
  if [[ $BOOT_MODE == "bios" ]]; then
    URL="https://github.com/elseif/MikroTikPatch/releases/download/$SELECTED_VERSION/chr-$SELECTED_VERSION-legacy-bios.img.zip"
  else
    URL="https://github.com/elseif/MikroTikPatch/releases/download/$SELECTED_VERSION/chr-$SELECTED_VERSION.img.zip"
  fi
fi

echo "[+] Downloading from: $URL"
wget --progress=dot:giga "$URL" -O chr.img.zip || { echo "Download failed."; exit 1; }

echo "[+] Extracting image..."
unzip -o chr.img.zip >/dev/null || { echo "Unzip failed."; exit 1; }

# Mount and configure autorun
MOUNT_POINT="/mnt"
mkdir -p $MOUNT_POINT
mount -o loop,offset=$((1 * 512)) chr.img $MOUNT_POINT || { echo "Mount failed."; exit 1; }

echo "[+] Writing autorun configuration..."
cat > $MOUNT_POINT/rw/autorun.scr <<EOF
/ip address add address=$ADDRESS interface=[/interface ethernet find where name=ether1]
/ip route add gateway=$GATEWAY
/ip service disable telnet
/system ntp client set enabled=yes primary-ntp=0.id.pool.ntp.org secondary-ntp=1.id.pool.ntp.org
/ip dns set servers=8.8.8.8,1.1.1.1
EOF

umount $MOUNT_POINT

# Flash to disk
echo "[7] Flashing image to /dev/$STORAGE ..."
dd if=chr.img of=/dev/$STORAGE bs=1M status=progress || { echo "dd failed."; exit 1; }

sync
echo "[8] Installation complete. Rebooting..."
reboot

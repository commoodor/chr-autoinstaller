#!/bin/bash
set -e

# === Detect Boot Mode ===
echo "[+] Detecting system boot mode..."
if [ -d /sys/firmware/efi ]; then
    BOOT_MODE="UEFI"
else
    BOOT_MODE="BIOS"
fi
echo "[+] Detected: $BOOT_MODE"

# === Select Download Source ===
echo "Select download source:"
echo "1) Official (mikrotik.com)"
echo "2) Mirror (GitHub patched)"
echo "3) Exit"
read -rp "Enter choice [1-3]: " SRC_CHOICE

case $SRC_CHOICE in
  1) BASE_URL="https://download.mikrotik.com/routeros";;
  2) BASE_URL="https://github.com/elseif/MikroTikPatch/releases/download";;
  3) exit 0;;
  *) echo "Invalid choice"; exit 1;;
esac

# === Fetch Versions (v6 & v7 only) ===
echo "[+] Fetching available versions..."
VERSIONS=$(curl -s https://mikrotik.com/download/archive | grep -oP 'routeros/\K[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | uniq)

if [ -z "$VERSIONS" ]; then
    echo "[-] Failed to fetch version list!"
    exit 1
fi

echo "Available versions:"
select VERSION in $VERSIONS; do
  if [ -n "$VERSION" ]; then
    echo "[+] Selected version: $VERSION"
    break
  fi
done

# === Select image based on boot mode ===
if [ "$BOOT_MODE" = "BIOS" ]; then
    IMG_FILE="chr-$VERSION-legacy-bios.img.zip"
else
    IMG_FILE="chr-$VERSION.img.zip"
fi

URL="$BASE_URL/$VERSION/$IMG_FILE"
echo "[+] Downloading image: $URL"
curl -L -o chr.img.zip "$URL"

# === Ensure unzip installed ===
if ! command -v unzip >/dev/null 2>&1; then
    echo "[+] Installing unzip..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y unzip
    elif command -v yum >/dev/null 2>&1; then
        yum install -y unzip
    fi
fi

# === Extract image ===
echo "[+] Extracting image..."
rm -f chr.img
unzip -j chr.img.zip '*.img' -d .
mv -f ./*.img chr.img

# === Select target disk ===
TARGET_DISK="/dev/sda"
read -rp "Enter target disk (default: $TARGET_DISK): " DISK_INPUT
if [ -n "$DISK_INPUT" ]; then
  TARGET_DISK="$DISK_INPUT"
fi

echo "[!] WARNING: All data on $TARGET_DISK will be erased!"
read -rp "Type YES to continue: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
  echo "Aborted."
  exit 1
fi

# === Flash image ===
echo "[+] Writing image to $TARGET_DISK..."
dd if=chr.img of=$TARGET_DISK bs=4M status=progress oflag=sync
sync

echo "[+] Installation complete! Reboot now."

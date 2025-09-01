#!/bin/bash

# Must be root!
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

# Source selection
select_source() {
  echo "Select download source:"
  echo "1) Official (mikrotik.com)"
  echo "2) Mirror (GitHub patched via mikrotik.ltd equivalent)"
  echo "3) Exit"
  read -p "Enter choice (1-3): " choice
  case $choice in
    1) SOURCE="official" ;;
    2) SOURCE="mirror" ;;
    3) exit 0 ;;
    *) echo "Invalid choice."; select_source ;;
  esac
}

# Fetch latest version (only for official)
get_official_version() {
  URL="https://mikrotik.com/download"
  HTML=$(curl -s "$URL")
  V6=$(echo "$HTML" | grep -oP '(?<=routeros/)[0-9.]+(?=/chr-[0-9.]+\.img\.zip)' | grep '^6' | sort -Vr | head -n1)
  V7=$(echo "$HTML" | grep -oP '(?<=routeros/)[0-9.]+(?=/chr-[0-9.]+\.img\.zip)' | grep '^7' | sort -Vr | head -n1)
}

# Version selection
select_version() {
  if [[ $SOURCE == official ]]; then
    echo "1) RouterOS v6: $V6"
    echo "2) RouterOS v7: $V7"
    read -p "Choose (1 or 2): " c
    case $c in
      1) SELECTED="$V6" ;;
      2) SELECTED="$V7" ;;
      *) select_version ;;
    esac
  else
    read -p "Enter patch version (default 7.19.4): " INPUT
    SELECTED="${INPUT:-7.19.4}"
  fi
  echo "Selected version: $SELECTED"
}

# Detect architecture & prepare mirror URL (like chr.sh)
get_mirror_url() {
  ARCH=$(uname -m)
  if [[ "$ARCH" =~ ^(x86_64|i[3-6]86)$ ]]; then
    if [[ -d /sys/firmware/efi ]]; then
      IMG_URL="https://github.com/elseif/MikroTikPatch/releases/download/$SELECTED/chr-$SELECTED.img.zip"
    else
      IMG_URL="https://github.com/elseif/MikroTikPatch/releases/download/$SELECTED/chr-$SELECTED-legacy-bios.img.zip"
    fi
  elif [[ "$ARCH" == aarch64 ]]; then
    IMG_URL="https://github.com/elseif/MikroTikPatch/releases/download/${SELECTED}-arm64/chr-${SELECTED}-arm64.img.zip"
  else
    echo "Unsupported architecture: $ARCH"
    exit 1
  fi
}

# Gather environment info
get_env_info() {
  STORAGE=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk"{print $1;exit}')
  ETH=$(ip route show default | grep '^default' | sed -n 's/.* dev \([^\ ]*\) .*/\1/p')
  ADDRESS=$(ip addr show $ETH | grep global | awk '{print $2}' | head -n1)
  GATEWAY=$(ip route | grep '^default' | awk '{print $3}')
}

# Main
select_source
if [[ $SOURCE == official ]]; then
  get_official_version
  select_version
  URL="https://download.mikrotik.com/routeros/$SELECTED/chr-$SELECTED.img.zip"
else
  select_version
  get_mirror_url
  URL="$IMG_URL"
fi

get_env_info
echo "Using storage: $STORAGE, interface: $ETH, IP: $ADDRESS, gateway: $GATEWAY"
echo "Download URL: $URL"

# Download
cd /tmp
if command -v wget &>/dev/null; then
  wget --progress=dot:giga "$URL" -O chr.img.zip || { echo "Download failed."; exit 1; }
else
  curl -L "$URL" -o chr.img.zip || { echo "Download failed."; exit 1; }
fi

# Unzip, mount, configure, flash, reboot (as in your original script logic)...

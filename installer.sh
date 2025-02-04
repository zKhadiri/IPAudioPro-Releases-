#!/bin/bash

# ---------------------------
# IPAudioPro Setup Script
# ---------------------------
# Project: IPAudioPro
# Author: zKhadiri
# ---------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

IPK=""
ARCH=""
PY_VER=""
VERSION=1.5
FFMPEG_VERSION=""
BASE_URL="https://raw.githubusercontent.com/zKhadiri/IPAudioPro-Releases-/refs/heads/main"


SUPPORTED_FFMPEG_VERSIONS=(
    4
    6
    7
)


welcome_message() {
    echo -e "${CYAN}##########################################${RESET}"
    echo -e "${YELLOW}###    Welcome to IPAudioPro Setup!    ###${RESET}"
    echo -e "${CYAN}##########################################${RESET}"
}


detect_python_version() {
    if command -v python3 &>/dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        PYTHON_VERSION=$(echo "$PYTHON_VERSION" | cut -d'.' -f1-2)
        echo $PYTHON_VERSION
    elif command -v python &>/dev/null; then
        PYTHON_VERSION=$(python --version 2>&1 | awk '{print $2}')
        PYTHON_VERSION=$(echo "$PYTHON_VERSION" | cut -d'.' -f1-2)
        echo $PYTHON_VERSION
    else
        echo "Python is not installed. Please install Python."
        exit 1
    fi
}


detect_ffmpeg_version() {
    if opkg status ffmpeg &>/dev/null; then
        FFMPEG_VERSION=$(opkg status ffmpeg | grep -i '^Version:' | awk '{print $2}' | cut -d'-' -f1)
        MAJOR_VERSION=$(echo "$FFMPEG_VERSION" | cut -d'.' -f1)
        if (( MAJOR_VERSION > 4 )); then
            FFMPEG_VERSION=$(echo "$FFMPEG_VERSION" | cut -d'.' -f1,2)

        if [[ " ${SUPPORTED_FFMPEG_VERSIONS[@]} " =~ " $MAJOR_VERSION " ]]; then
            echo -e "${GREEN}FFmpeg major version $MAJOR_VERSION is supported.${RESET}"
        else
            echo -e "${YELLOW}FFmpeg major version $MAJOR_VERSION is not supported.${RESET}"
            echo -e "${CYAN}Supported versions are: ${SUPPORTED_FFMPEG_VERSIONS[*]}${RESET}"
            exit 1
        fi
    else
        echo -e "${YELLOW}FFmpeg is not installed. Installing FFmpeg...${RESET}"
        opkg update && opkg install ffmpeg
        if opkg status ffmpeg &>/dev/null; then
            detect_ffmpeg_version
        else
            echo -e "${RED}Failed to install FFmpeg. Please check opkg feed.${RESET}"
            exit 1
        fi
    fi
}



detect_cpu_arch() {
    echo "Checking Python version..."
    PY_VER=$(detect_python_version)
    echo "Python version: $PY_VER"

    echo "Checking FFmpeg version..."
    detect_ffmpeg_version

    echo "Detecting CPU architecture..."
    CPU_ARCH=$(uname -m)
    echo -e "CPU architecture: ${GREEN}${CPU_ARCH}${RESET}"

    if [[ "$CPU_ARCH" == *"arm"* ]]; then
        ARCH=$(detect_arm_arch)
        if [[ "$ARCH" != "unknown" ]]; then
            CPU_ARCH="arm"
            IPK="enigma2-plugin-extensions-ipaudiopro_${VERSION}_${ARCH}_py${PY_VER}_ff${FFMPEG_VERSION}.ipk"
            echo -e "Detected architecture: ${GREEN}${ARCH}${RESET}"
        else
            echo -e "${RED}Unsupported architecture: ${ARCH}${RESET}"
            exit 1
        fi
    elif [[ "$CPU_ARCH" == *"mips"* ]]; then
        ARCH="mips32el"
        IPK="enigma2-plugin-extensions-ipaudiopro_${VERSION}_${ARCH}_py${PY_VER}_ff${FFMPEG_VERSION}.ipk"
        echo "Detected architecture: mipsel"
    elif [[ "$CPU_ARCH" == *"aarch64"* ]]; then
        ARCH="aarch64"
        IPK="enigma2-plugin-extensions-ipaudiopro_${VERSION}_${ARCH}_py${PY_VER}_ff${FFMPEG_VERSION}.ipk"
        echo "Detected architecture: aarch64"
    else
        echo -e "${RED}Unsupported architecture: ${CPU_ARCH}${RESET}"
        exit 1
    fi
}


detect_arm_arch() {
    OPKG_DIR="/etc/opkg/"
    if [[ -d "$OPKG_DIR" ]]; then
        if ls "$OPKG_DIR" | grep -q "cortexa15hf-neon-vfpv4"; then
            echo "cortexa15hf-neon-vfpv4"
        elif ls "$OPKG_DIR" | grep -q "cortexa9hf-neon"; then
            echo "cortexa9hf-neon"
        elif ls "$OPKG_DIR" | grep -q "cortexa7hf-vfp"; then
            echo "cortexa7hf-vfp"
        elif ls "$OPKG_DIR" | grep -q "armv7ahf-neon"; then
            echo "armv7ahf-neon"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}


restart_box(){
    killall -9 enigma2
    exit 0
}


install_plugin() {
    welcome_message
    detect_cpu_arch
    
    echo "Checking if IPAudioPro is installed..."

    INSTALLED_VERSION=$(opkg status enigma2-plugin-extensions-ipaudiopro | grep -i 'Version:' | awk '{print $2}' | sed 's/+.*//')
    echo "Current version: $VERSION"
    
    if [[ -n "$INSTALLED_VERSION" ]]; then
        echo "Current installed version: $INSTALLED_VERSION"

        if [[ "$(echo -e "$INSTALLED_VERSION\n$VERSION" | sort -V | tail -n1)" == "$VERSION" ]]; then
            echo "Newer version found. Installing version $VERSION..."
            opkg remove enigma2-plugin-extensions-ipaudiopro
            IPK_URL="${BASE_URL}/v${VERSION}/python${PY_VER}/${CPU_ARCH}/${IPK}"
            wget -q "--no-check-certificate" -O "/tmp/${IPK}" "$IPK_URL"
            opkg install "/tmp/${IPK}"
            rm -f "/tmp/${IPK}"
            restart_box
        else
            echo "IPAudioPro is already up to date (version $INSTALLED_VERSION). No action needed."
        fi
    else
        echo "IPAudioPro is not installed. Installing..."
        IPK_URL="${BASE_URL}/v${VERSION}/python${PY_VER}/${CPU_ARCH}/${IPK}"
        wget -q "--no-check-certificate" -O "/tmp/${IPK}" "$IPK_URL"
        opkg install "/tmp/${IPK}"
        rm -f "/tmp/${IPK}"
        restart_box
    fi
    exit 0
}

install_plugin

#!/bin/bash

# Compile Script for Graveyard Kernel
# Copyright (C) 2024-2025 Christopher K. Irvine (MAdMiZ)

# <--- SETUP ENVIRONMENT --->
SECONDS=0
TZ=Asia/Kolkata
ZIPNAME="Graveyard-v1-air-$(date '+%Y%m%d-%H%M').zip"
AK3_DIR="$HOME/android/AnyKernel3"
DEFCONFIG="air_defconfig"
LLVM_VERSION=18

export TZ=Asia/Kolkata
export KBUILD_BUILD_USER=MAdMiZ
export KBUILD_BUILD_HOST=BlackArch
export PATH="/usr/lib/llvm-$LLVM_VERSION/bin:$PATH"
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

git config --global user.name "mizdrake7"
git config --global user.email "mizdrake7@gmail.com"

# <--- INSTALL REQUIRED PACKAGES --->
echo -e "\nInstalling required packages and toolchains...\n"

sudo apt-get update -y && sudo apt-get install -y \
    gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi binutils make lld llvm \
    python3 libssl-dev build-essential bc bison flex unzip \
    ca-certificates xz-utils mkbootimg cpio device-tree-compiler \
    git git-lfs curl wget libelf-dev jq || {
    echo -e "\nFailed to install required packages. Exiting...\n"; exit 1;
}

# Install LLVM if not present or outdated
if ! command -v clang &> /dev/null || [[ $(clang --version | grep -oP '\d+' | head -1) -lt $LLVM_VERSION ]]; then
    echo -e "\nInstalling LLVM $LLVM_VERSION...\n"
    sudo bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)" $LLVM_VERSION || {
        echo -e "\nFailed to install LLVM $LLVM_VERSION. Exiting...\n"; exit 1;
    }
else
    echo -e "\nLLVM $LLVM_VERSION is already installed.\n"
fi

# Update ZIP name with commit hash if in a Git repository
if git rev-parse --is-inside-work-tree &> /dev/null; then
    commit_hash=$(git rev-parse --short HEAD)
    ZIPNAME="${ZIPNAME%.zip}-$commit_hash.zip"
fi

# <--- COMPILATION OPTIONS --->
if [[ $1 == "-r" || $1 == "--regen" ]]; then
    make O=out ARCH=arm64 $DEFCONFIG savedefconfig
    cp out/defconfig arch/arm64/configs/$DEFCONFIG
    echo -e "\nRegenerated defconfig successfully. Exiting...\n"
    exit 0
fi

if [[ $1 == "-c" || $1 == "--clean" ]]; then
    echo -e "\nCleaning build directory...\n"
    rm -rf out
fi

# <--- START COMPILATION --->
mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG || {
    echo -e "\nFailed to set defconfig. Exiting...\n"; exit 1;
}

echo -e "\nStarting kernel compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 \
    CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as NM=llvm-nm \
    OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
    CROSS_COMPILE=$CROSS_COMPILE CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32 \
    CLANG_TRIPLE=aarch64-linux-gnu- LLVM=1 Image.gz-dtb 2>&1 | tee error.log

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
    echo -e "\nKernel compiled successfully! Preparing ZIP...\n"

    # Clone or use existing AnyKernel3 directory
    if [ -d "$AK3_DIR" ]; then
        cp -r "$AK3_DIR" AnyKernel3
    elif ! git clone -q https://github.com/mizdrake7/AnyKernel3; then
        echo -e "\nFailed to clone AnyKernel3 repository. Exiting...\n"; exit 1;
    fi

    # Prepare ZIP file
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
    rm -f *zip
    pushd AnyKernel3 > /dev/null
    git checkout master &> /dev/null
    zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder || {
        echo -e "\nFailed to create ZIP. Exiting...\n"; exit 1;
    }
    popd > /dev/null
    rm -rf AnyKernel3

    # Display completion details
    elapsed_time="$((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)"
    zip_size_mb=$(awk "BEGIN {print $(stat -c%s "$ZIPNAME") / 1048576}")
    echo -e "\nCompleted in $elapsed_time!\nZIP: $ZIPNAME\nSize: $zip_size_mb MB\n"

    # <--- UPLOAD OPTIONS --->
    read -p "Enter 1 to upload to Telegram, or press any key to upload to Oshi.at: " choice

    if [[ $choice == "1" ]]; then
        read -p "Enter the bot token: " bot_token
        echo -e "\nUploading to Telegram...\n"
        curl --progress-bar -F chat_id="-1001304524669" -F document=@"$ZIPNAME" \
            "https://api.telegram.org/bot$bot_token/sendDocument" || {
            echo -e "\nFailed to upload to Telegram. Exiting...\n"; exit 1;
        }
        echo -e "\nUploaded to Telegram successfully.\n"
    else
        echo -e "\nUploading to Oshi.at...\n"
        response=$(curl --progress-bar --upload-file "$ZIPNAME" "https://oshi.at/$ZIPNAME")
        if [ $? -ne 0 ]; then
            echo -e "\nFailed to upload to Oshi.at. Response: $response\n"; exit 1;
        fi
        echo -e "\nUploaded to Oshi.at: $response\n"
    fi
else
    echo -e "\nCompilation failed! Showing the last 20 lines of the error log:\n"
    tail -n 20 error.log
    exit 1
fi

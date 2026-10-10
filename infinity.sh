#!/bin/bash

DEVICE="blossom"
ANDROID_VERSION="16-qpr1"
START_TIME=$(date +%s)
MAINTAINER="fiyuu"

REPO_INIT_URL="https://github.com/ProjectInfinity-X/manifest"
REPO_INIT_BRANCH="16-QPR1"
LOCAL_MANIFEST_URL="https://github.com/kitsunee2/local_manifests.git"
LOCAL_MANIFEST_BRANCH="a16.2"
BUILD_TARGET="infinity_blossom-userdebug"
BUILD_COMMAND="m bacon -j$(nproc --all)"

export BUILD_USERNAME="fiyuu"
export BUILD_HOSTNAME="crave"
export IGNORE_PATCH_ERRORS=true

echo "Device: $DEVICE | Android: $ANDROID_VERSION"

sync_repositories() {
    echo "[repo init]"
    repo init --depth=1 --no-repo-verify --git-lfs -u $REPO_INIT_URL -b $REPO_INIT_BRANCH -g default,-mips,-darwin,-notdefault
    echo "[cloning local manifest]"
    rm -rf .repo/local_manifests/
    git clone --depth=1 -b "$LOCAL_MANIFEST_BRANCH" "$LOCAL_MANIFEST_URL" .repo/local_manifests
    echo "[resync]"
    /opt/crave/resync.sh
}

rom_fix() {
    echo "[fix] applying..."
    
    curl -sSfL -o "build/soong/ui/execution_metrics/execution_metrics.go" \
    "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/execution_metrics.go"

    curl -sSfL -o "hardware/interfaces/audio/common/all-versions/default/Android.bp" \
    "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/Android.bp"

    curl -sSfL -o "device/xiaomi/blossom/AndroidProducts.mk" \
    "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/infinity_AndroidProducts.mk"

    curl -sSfL -o "device/xiaomi/blossom/infinity_blossom" \
    "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/infinity_blossom.mk"

    curl -sSfL -o "device/xiaomi/blossom/system.prop" \
    "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/infinity_system.prop"

    echo "[fix] done"
}

sign_keys() {
    echo "[sign] cloning keys..."
    git clone --depth=1 https://github.com/kitsunee02/android_vendor_lineage-priv_keys vendor/lineage-priv/keys
    cd vendor/lineage-priv/keys
    python3 -m venv venv
    source venv/bin/activate
    pip install pyOpenSSL cryptography
    ./gen_keys.py
    cd -
    echo "[sign] done"
}   

compile_rom() {
    export TZ="Asia/Kolkata"

    set +eE
    source build/envsetup.sh
    lunch "$BUILD_TARGET"
    set -eE

    m installclean

    echo "[build] starting $BUILD_TARGET..."
    $BUILD_COMMAND

    END_TIME=$(date +%s)
    BUILD_MINUTES=$(((END_TIME - START_TIME) / 60))
    echo "[build] done in ${BUILD_MINUTES}m."
}

sync_repositories
rom_fix
sign_keys
compile_rom   

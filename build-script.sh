#!/bin/bash

set -E
trap 'echo "❌ FAILED at line $LINENO"' ERR

# Clean working tree parameters
rm -rf .repo/local_manifests

# Initialize ROM manifest
repo init -u https://github.com/AviumUI/android_manifests.git -b avium-16 --depth=1 --git-lfs

echo "=================="
echo "Repo init success"
echo "=================="

# Clone local manifests
git clone https://github.com/kitsunee02/local_manifests.git -b A16 .repo/local_manifests

echo "============================"
echo "Local manifest clone success"
echo "============================"

echo "============="
echo "Sync"
echo "============="

# Execute workspace sync pipeline once cleanly
/opt/crave/resync.sh

# Installing required packages
sudo apt-get update && sudo apt-get install patchelf coreutils -y 

echo "============="
echo "packages done"
echo "============="

# Environmental configurations
export BUILD_USERNAME=Fiyuu
export WITH_GMS=false
export TARGET_BUILD_GAPPS=false
export BUILD_HOSTNAME=crave
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export IGNORE_PATCH_ERRORS=true

#git am patches

git -C frameworks/av am --abort 2>/dev/null || true
git -C frameworks/base am --abort 2>/dev/null || true
git -C hardware/interfaces am --abort 2>/dev/null || true
git -C packages/modules/Bluetooth am --abort 2>/dev/null || true
git -C build/soong am --abort 2>/dev/null || true
git -C system/sepolicy am --abort 2>/dev/null || true


echo "======= Export Done ======"

AUDIO_BP="hardware/interfaces/audio/common/all-versions/default/Android.bp"
if [ -f "$AUDIO_BP" ]; then
  curl -sSf -o "$AUDIO_BP" "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/Android.bp" \
    && echo "✅ Audio Android.bp replaced with verified fix" \
    || echo "⚠️ Failed to download fix, keeping original"
fi


DEVICE_DIR="device/xiaomi/blossom"

# Create avium_common.mk
cat > "$DEVICE_DIR/avium_common.mk" <<'EOF'
AVIUM_MAINTAINER := Fiyuu
AVIUM_VERSION_APPEND_TIME_OF_DAY := false
WITH_GMS := false
AVIUM_BUILDTYPE := Unofficial
EOF

# Add include to device.mk
if ! grep -q 'avium_common.mk' "$DEVICE_DIR/device.mk"; then
    echo '$(call inherit-product, device/xiaomi/blossom/avium_common.mk)' >> "$DEVICE_DIR/device.mk"
fi   

    rm -f "$DEVICE_DIR/lineage.dependencies"
  
set -e 

# Set up build environment
source build/envsetup.sh


# Target profile configuration
lunch lineage_blossom-bp2a-userdebug

# Execute optimization build pipeline
m bacon -j$(nproc --all)

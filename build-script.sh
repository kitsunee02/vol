#!/bin/bash

set -Ee
trap 'echo "❌ FAILED at line $LINENO"' ERR

echo "===== Repo Init ====="

rm -rf .repo/local_manifests

repo init \
  -u https://github.com/AviumUI/android_manifests.git \
  -b avium-16 \
  --depth=1 \
  --git-lfs

echo "===== Repo init success ====="

echo "===== Local Manifest ====="

git clone \
  https://github.com/kitsunee02/local_manifests.git \
  -b a16-cvr \
  .repo/local_manifests

echo "===== Local manifest clone success ====="

echo "===== Repo Sync ====="

/opt/crave/resync.sh

echo "===== Installing packages ====="

sudo apt-get update
sudo apt-get install -y patchelf coreutils ccache

echo "===== Build Variables ====="

export BUILD_USERNAME=Fiyuu
export BUILD_HOSTNAME=crave
export WITH_GMS=false
export TARGET_BUILD_GAPPS=false
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export IGNORE_PATCH_ERRORS=true

echo "==== Applying Git am ==="
git -C frameworks/av am --abort 2>/dev/null || true
git -C frameworks/base am --abort 2>/dev/null || true
git -C hardware/interfaces am --abort 2>/dev/null || true
git -C packages/modules/Bluetooth am --abort 2>/dev/null || true
git -C build/soong am --abort 2>/dev/null || true
git -C system/sepolicy am --abort 2>/dev/null || true
git -C hardware/mediatek am --abort 2>/dev/null || true

echo "===== Applying Soong Fix ====="

SOONG_FILE="build/soong/ui/execution_metrics/execution_metrics.go"

if [ -f "$SOONG_FILE" ]; then
    curl -sSfL \
      -o "$SOONG_FILE" \
      "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/execution_metrics.go"
    echo "✅ Soong fix applied"
else
    echo "⚠️ Soong fix skipped"
fi

echo "===== Applying Audio Fix ====="

AUDIO_BP="hardware/interfaces/audio/common/all-versions/default/Android.bp"

if [ -f "$AUDIO_BP" ]; then
    curl -sSfL \
      -o "$AUDIO_BP" \
      "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/Android.bp"
    echo "✅ Audio fix applied"
else
    echo "⚠️ Audio fix skipped"
fi

echo "===== Removing Generic Conflicting Interfaces ====="

rm -rf hardware/interfaces/biometrics/fingerprint/2.1/default
rm -rf hardware/lineage/interfaces/sensors
rm -rf hardware/lineage/interfaces/biometrics/fingerprint


echo "===== Blossom Configuration ====="

DEVICE_DIR="device/xiaomi/blossom"

cat > "$DEVICE_DIR/avium_common.mk" <<'EOF'
AVIUM_MAINTAINER := Fiyuu
AVIUM_VERSION_APPEND_TIME_OF_DAY := false
WITH_GMS := false
AVIUM_BUILDTYPE := Unofficial
EOF

grep -q 'avium_common.mk' "$DEVICE_DIR/device.mk" || \
echo '$(call inherit-product, device/xiaomi/blossom/avium_common.mk)' \
>> "$DEVICE_DIR/device.mk"

rm -f "$DEVICE_DIR/lineage.dependencies"

echo "===== Cleaning Generated Build Files ====="

rm -rf out/soong
rm -rf out/target/product/blossom/obj

echo "===== Fingerprint HAL Check ====="

grep -RniE \
'android\.hardware\.biometrics\.fingerprint@2\.1-service|fingerprint@2\.1-service' \
device/xiaomi/blossom \
vendor/xiaomi/blossom \
hardware \
2>/dev/null || true

echo "===== Build Environment ====="

source build/envsetup.sh

echo "===== Lunch ====="

lunch lineage_blossom-bp2a-userdebug

echo "===== Starting Build ====="

m bacon -j"$(nproc --all)"

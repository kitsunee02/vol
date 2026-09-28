#!/bin/bash

set -E
trap 'echo "❌ FAILED at line $LINENO"' ERR

rm -rf .repo/local_manifests

repo init -u https://github.com/AviumUI/android_manifests.git -b avium-16 --depth=1 --git-lfs
echo "===== Repo init success ====="

git clone https://github.com/kitsunee02/local_manifests.git -b A16 .repo/local_manifests
echo "===== Local manifest clone success ====="

echo "===== Sync ====="
/opt/crave/resync.sh

sudo apt-get update && sudo apt-get install patchelf coreutils -y
echo "===== packages done ====="

export BUILD_USERNAME=Fiyuu
export BUILD_HOSTNAME=crave
export WITH_GMS=false
export TARGET_BUILD_GAPPS=false
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export IGNORE_PATCH_ERRORS=true
echo "===== Export Done ====="

# Verified fixes
SOONG_FILE="build/soong/ui/execution_metrics/execution_metrics.go"
[ -f "$SOONG_FILE" ] && curl -sSf -o "$SOONG_FILE" "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/execution_metrics.go" \
  && echo "✅ Soong fix applied" || echo "⚠️ Soong fix skipped"

AUDIO_BP="hardware/interfaces/audio/common/all-versions/default/Android.bp"
[ -f "$AUDIO_BP" ] && curl -sSf -o "$AUDIO_BP" "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/Android.bp" \
  && echo "✅ Audio fix applied" || echo "⚠️ Audio fix skipped"

# Remove ONLY the generic modules that collide with blossom's real HALs
rm -rf hardware/lineage/interfaces/sensors
rm -rf hardware/lineage/interfaces/biometrics/fingerprint

DEVICE_DIR="device/xiaomi/blossom"

cat > "$DEVICE_DIR/avium_common.mk" <<'EOF'
AVIUM_MAINTAINER := Fiyuu
AVIUM_VERSION_APPEND_TIME_OF_DAY := false
WITH_GMS := false
AVIUM_BUILDTYPE := Unofficial
EOF

grep -q 'avium_common.mk' "$DEVICE_DIR/device.mk" || \
  echo '$(call inherit-product, device/xiaomi/blossom/avium_common.mk)' >> "$DEVICE_DIR/device.mk"

rm -f "$DEVICE_DIR/lineage.dependencies"

echo "===== checking for more duplicate modules =====" #im tired of logs and build fail for every duplicate modules
grep -rhoE 'name: "[^"]+"' hardware/lineage/interfaces --include=Android.bp | sort -u > /tmp/a.txt
grep -rhoE 'name: "[^"]+"' device/xiaomi/blossom hardware/mediatek vendor/xiaomi/blossom --include=Android.bp | sort -u > /tmp/b.txt
comm -12 /tmp/a.txt /tmp/b.txt || true
echo "===== Check done ====="

set -e
source build/envsetup.sh
lunch lineage_blossom-bp2a-userdebug
m bacon -j$(nproc --all)

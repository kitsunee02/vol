#!/bin/bash

set -eE
trap 'echo "❌ FAILED at line $LINENO"' ERR

# Clean working tree parameters
rm -rf .repo/local_manifests

# Initialize ROM manifest
repo init -u https://github.com/AyakaUI/android_manifest.git -b sixteen --depth=1 --git-lfs

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
/opt/crave/resync.sh

# Installing required packages
sudo apt-get update && sudo apt-get install patchelf coreutils -y 

echo "============="
echo "packages done"
echo "============="

# Environmental configurations
export BUILD_USERNAME=Fiyuu
export TARGET_BUILD_GAPPS=false
export BUILD_HOSTNAME=crave
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export IGNORE_PATCH_ERRORS=true

echo "======= Export Done ======"

# --- Fix: Soong Go compat ---
SOONG_FILE="build/soong/ui/execution_metrics/execution_metrics.go"
if [ -f "$SOONG_FILE" ]; then
  curl -sSf -o "$SOONG_FILE" "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/execution_metrics.go" \
    && echo "✅ Soong file replaced" \
    || echo "⚠️ Failed to download execution_metrics.go fix, keeping original"
else
  echo "⚠️ $SOONG_FILE not found, skipping."
fi

# --- Fix: Audio HAL Android.bp ---
AUDIO_BP="hardware/interfaces/audio/common/all-versions/default/Android.bp"
if [ -f "$AUDIO_BP" ]; then
  curl -sSf -o "$AUDIO_BP" "https://raw.githubusercontent.com/kitsunee02/rom-patches/main/Android.bp" \
    && echo "✅ Audio file replaced" \
    || echo "⚠️ Failed to download Android.bp fix, keeping original"
else
  echo "⚠️ $AUDIO_BP not found, skipping."
fi
# Set up build environment
source build/envsetup.sh

echo "============="

# Target profile configuration
lunch lineage_blossom-bp2a-userdebug

# Execute optimization build pipeline
m bacon

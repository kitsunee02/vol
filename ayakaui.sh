#!/bin/bash

set -eE
trap 'echo "❌ FAILED at line $LINENO"' ERR

# Clean working tree parameters
rm -rf .repo/local_manifests
rm -rf .repo

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

# Go Compatibility Patch System
SOONG_FILE="build/soong/ui/execution_metrics/execution_metrics.go"

if [ -f "$SOONG_FILE" ]; then
    echo "🔧 Patching execution_metrics.go safely..."

    # Reset any previous temporary modifications cleanly
    git checkout -- "$SOONG_FILE" 2>/dev/null || true

    # Inject the classic "sort" package right after the import block starts
    sed -i '/^import (/a\	"sort"' "$SOONG_FILE"

    # Strip out the modern package imports causing toolchain panic errors
    sed -i '/"maps"/d; /"slices"/d' "$SOONG_FILE"

    # Replace the modern slices.Sorted line with a classic Go loop and string sort
    sed -i 's/keys := slices\.Sorted(maps\.Keys(fileCounts))/keys := func() []string { kList := make([]string, 0, len(fileCounts)); for k := range fileCounts { kList = append(kList, k) }; sort.Strings(kList); return kList }()/' "$SOONG_FILE"

    echo "✅ Go compilation code and imports patched successfully!"
else
    echo "⚠️ $SOONG_FILE not found, skipping Go patch."
fi

# Preparing target paths
mkdir -p device/xiaomi/blossom-kernel/modules

# Audio blueprint clean conditional statement
AUDIO_BP="hardware/interfaces/audio/common/all-versions/default/Android.bp"
if [ -f "$AUDIO_BP" ]; then
    echo "🔧 Fixing Audio select type condition..."
    sed -i 's/"true":/true:/g' "$AUDIO_BP"
    echo "✅ Audio Android.bp patched!"
else
    echo "⚠️ Audio Android.bp not found, skipping patch."
fi

# Set up build environment
source build/envsetup.sh

echo "============="

# Target profile configuration
lunch lineage_blossom-bp2a-userdebug

# Execute optimization build pipeline
m bacon

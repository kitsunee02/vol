#!/bin/bash

set -eE
trap 'echo "❌ FAILED at line $LINENO"' ERR

rm -rf .repo/local_manifests
rm -rf .repo

# repo init rom

repo init -u https://github.com/AyakaUI/android_manifest.git -b sixteen --depth=1 --git-lfs

echo "=================="
echo "Repo init success"
echo "=================="

# Local manifests

git clone https://github.com/kitsunee02/local_manifests.git -b A16 .repo/local_manifests

echo "============================"
echo "Local manifest clone success"
echo "============================"

# Build Sync
# curl -sf https://raw.githubusercontent.com/xc112lg/lg_releases/refs/heads/main/resync.sh | bash

echo "============="
echo "Sync"
echo "============="

/opt/crave/resync.sh

/opt/crave/resync.sh

# Installing packages 

sudo apt-get update && sudo apt-get install patchelf coreutils -y 

echo "============="
echo "packages done"
echo "============="

# Export

export BUILD_USERNAME=Fiyuu
export TARGET_BUILD_GAPPS=false
export BUILD_HOSTNAME=crave
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export IGNORE_PATCH_ERRORS=true

echo "======= Export Done ======"

#Go fix

SOONG_FILE="build/soong/ui/execution_metrics/execution_metrics.go"

if [ -f "$SOONG_FILE" ]; then
    echo "🔧 Re-patching execution_metrics.go safely..."

    # Reset any previous modifications to the file safely
    git checkout -- "$SOONG_FILE" 2>/dev/null || true

    # Safely inject the "sort" import if it doesn't already exist
    if ! grep -q '"sort"' "$SOONG_FILE"; then
        sed -i '/^import (/a\    "sort"' "$SOONG_FILE"
    fi

    # Remove modern Go maps/slices imports causing problems on older Go toolchains
    sed -i '/"maps"/d; /"slices"/d' "$SOONG_FILE"

    # Replace modern slices.Sorted syntax with backwards-compatible loop sorting
    sed -i 's/slices\.Sorted(maps\.Keys(\([^)]*\)))/func() []string { keys := make([]string, 0, len(\1)); for k := range \1 { keys = append(keys, k) }; sort.Strings(keys); return keys }()/' "$SOONG_FILE"

    echo "✅ Fixed and patched successfully!"
else
    echo "⚠️ $SOONG_FILE not found, skipping Go patch."
fi


#Making kernel modules dir

mkdir -p device/xiaomi/blossom-kernel/modules

#Fixing audio files

AUDIO_BP="hardware/interfaces/audio/common/all-versions/default/Android.bp"; [ -f "$AUDIO_BP" ] && (echo "🔧 Fixing Audio select type condition..."; sed -i 's/"true":/true:/g' "$AUDIO_BP"; echo "✅ Audio Android.bp patched!") || echo "⚠️ Audio Android.bp not found, skipping patch."

# Set up build environment

source build/envsetup.sh

echo "============="

# Lunch

lunch lineage_blossom-bp2a-userdebug

# Build

m bacon

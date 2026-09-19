#!/bin/bash

rm -rf .repo/local_manifests

# repo init rom
repo init -u https://github.com/AyakaUI/android_manifest.git -b sixteen --depth=1 --git-lfs
echo "=================="
echo "Repo init success"
echo "=================="

# Local manifests
git clone https://github.com/kitsunee02/local-manifests.git -b main .repo/local_manifests
echo "============================"
echo "Local manifest clone success"
echo "============================"

# Build Sync
curl -sf https://raw.githubusercontent.com/xc112lg/lg_releases/refs/heads/main/resync.sh | bash
echo "============="
echo "Sync success"
echo "============="

# Installing packages 
sudo apt-get update && sudo apt-get install patchelf coreutils protobuf-compiler libprotobuf-dev -y 
echo "============="
echo "packages done"
echo "============="

# Export
export BUILD_USERNAME=Fiyuu
export BUILD_HOSTNAME=crave
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export IGNORE_PATCH_ERRORS=true
echo "======= Export Done ======"

#Fixing patchs
set +e
git -C frameworks/av am --abort 2>/dev/null
git -C frameworks/base am --abort 2>/dev/null
git -C hardware/interfaces am --abort 2>/dev/null
git -C packages/modules/Bluetooth am --abort 2>/dev/null
git -C build/soong am --abort 2>/dev/null
git -C system/sepolicy am --abort 2>/dev/null
set -e

#Go fix
SOONG_FILE="build/soong/ui/execution_metrics/execution_metrics.go"; git checkout -- "$SOONG_FILE" 2>/dev/null; [ -f "$SOONG_FILE" ] && (echo "🔧 Re-patching execution_metrics.go safely..."; grep -q '"sort"' "$SOONG_FILE" || sed -i '/^import (/a\    "sort"' "$SOONG_FILE"; sed -i '/"maps"/d; /"slices"/d' "$SOONG_FILE"; sed -i 's/slices\.Sorted(maps\.Keys(\([^)]*\)))/func() []string { keys := make([]string, 0, len(\1)); for k := range \1 { keys = append(keys, k) }; sort.Strings(keys); return keys }()/' "$SOONG_FILE"; echo "✅ Fixed and patched successfully!") || echo "❌ Soong execution_metrics.go not found!"

#Making kernel modules dir
mkdir -p device/xiaomi/blossom-kernel/modules

#Fixing audio files
AUDIO_BP="hardware/interfaces/audio/common/all-versions/default/Android.bp"; [ -f "$AUDIO_BP" ] && (echo "🔧 Fixing Audio select type condition..."; sed -i 's/"true":/true:/g' "$AUDIO_BP"; echo "✅ Audio Android.bp patched!") || echo "⚠️ Audio Android.bp not found, skipping patch."

# Set up build environment
source build/envsetup.sh
echo "============="

# Lunch
lunch lineage_blossom-bp2a-userdebug;

# Build
m bacon

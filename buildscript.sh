#!/bin/bash

DEVICE="blossom"
ANDROID_VERSION="16-qpr2"
START_TIME=$(date +%s)
BUILD_USERNAME="fiyuu"
MAINTAINER="fiyuu"

REPO_INIT_URL="not defined"
REPO_INIT_BRANCH="not defined"
LOCAL_MANIFEST_URL="https://github.com/kitsunee2/local_manifests.git"
LOCAL_MANIFEST_BRANCH="a16-qpr2"
BUILD_TARGET="not defined"
BUILD_COMMAND="not defined"

echo "=========================================="
echo "✅ Device: $DEVICE | MAINTAINER: $ROM_NAME | Android: $ANDROID_VERSION"
echo "=========================================="

# ==========================================
# 🚀 Sync
# ==========================================
sync_repositories() {
    echo "=========================================="
    echo "🚀 Repo init"
    echo "=========================================="
    repo init -u "$REPO_INIT_URL" -b "$REPO_INIT_BRANCH" --git-lfs --depth=1

    echo "📄 Cloning local manifest..."
    rm -rf .repo/local_manifests/
    git clone --depth=1 -b "$LOCAL_MANIFEST_BRANCH" "$LOCAL_MANIFEST_URL" .repo/local_manifests

    echo "=========================================="
    echo "🚀 Repo sync (with retry + force-remove-dirty)"
    echo "=========================================="
    if [ -f /opt/crave/resync.sh ]; then
        /opt/crave/resync.sh
    fi

    for i in {1..3}; do
        repo sync -c -j16 --force-sync --force-remove-dirty --no-clone-bundle --no-tags && break || {
            if [ $i -eq 3 ]; then
                echo "❌ Repo sync failed after 3 attempts."
                handle_error $LINENO
            fi
            echo "⚠️ repo sync failed, retrying in 30 seconds... ($i/3)"
            sleep 30
        }
    done

    if [ -f /opt/crave/resync.sh ]; then
        /opt/crave/resync.sh
    fi

}


# ==========================================
# 🔨 Compile
# ==========================================
compile_rom() {
    export TZ="Asia/Kolkata"

    set +eE
    source build/envsetup.sh
    lunch "$BUILD_TARGET"
    set -eE

    echo "Cleaning output directory..."
    m installclean

    echo "=========================================="
    echo "🔨 Starting compilation for $ROM_NAME ($BUILD_TARGET)..."
    echo "=========================================="
    $BUILD_COMMAND

    END_TIME=$(date +%s)
    BUILD_MINUTES=$(((END_TIME - START_TIME) / 60))
    echo "⏱️ Build finished in ${BUILD_MINUTES}m."
}

sync_repositories
rom_fix
compile_rom



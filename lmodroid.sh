#!/bin/bash

DEVICE="blossom"
ANDROID_VERSION="16-qpr1"
START_TIME=$(date +%s)
MAINTAINER="fiyuu"

REPO_INIT_URL="https://github.com/ProjectInfinity-X/manifest"
REPO_INIT_BRANCH="16-QPR1"
BUILD_TARGET="lineage_blossom-userdebug"
BUILD_COMMAND="m bacon -j8"

export BUILD_USERNAME="fiyuu"
export BUILD_HOSTNAME="crave"
export IGNORE_PATCH_ERRORS=true


echo "Device: $DEVICE | Android: $ANDROID_VERSION"

sync_repositories() {
    echo "[repo init]"
    repo init --depth=1 --no-repo-verify --git-lfs -u $REPO_INIT_URL -b $REPO_INIT_BRANCH -g default,-mips,-darwin,-notdefault
    echo "[cloning local manifest]"
    rm -rf .repo/local_manifests/
LOCAL_MANIFEST=".repo/local_manifests/local_manifest.xml"
LOCAL_MANIFEST_URL="https://raw.githubusercontent.com/kitsunee02/rom-patches/refs/heads/main/luna16/local_manifest.xml"

mkdir -p ".repo/local_manifests" || {
    echo "ERROR: Failed to create local manifests directory"
    exit 1
}

if [ -n "$LOCAL_MANIFEST_URL" ]; then
    TEMP_MANIFEST="$(mktemp)" || {
        echo "ERROR: Failed to create temporary manifest file"
        exit 1
    }

    if curl -sSfL -o "$TEMP_MANIFEST" "$LOCAL_MANIFEST_URL" &&
       [ -s "$TEMP_MANIFEST" ]; then
        mv "$TEMP_MANIFEST" "$LOCAL_MANIFEST" || {
            rm -f "$TEMP_MANIFEST"
            echo "ERROR: Failed to install Lunaris local manifest"
            exit 1
        }
    else
        rm -f "$TEMP_MANIFEST"
        echo "ERROR: Failed to download Lunaris local manifest"
        exit 1
    fi
else
    echo "WARNING: Lunaris local manifest URL not set; skipping download"
fi
    echo "[resync]"
    /opt/crave/resync.sh
}

rom_fix() {
    echo "[fix] applying..."

SOONG_FILE="build/soong/ui/execution_metrics/execution_metrics.go"
SOONG_URL="https://raw.githubusercontent.com/kitsunee02/rom-patches/main/execution_metrics.go"

if [ -f "$SOONG_FILE" ]; then
    curl -sSfL -o "$SOONG_FILE" "$SOONG_URL" ||
        { echo "ERROR: Failed to download execution_metrics.go"; exit 1; }
fi

AUDIO_BP="hardware/interfaces/audio/common/all-versions/default/Android.bp"
AUDIO_BP_URL="https://raw.githubusercontent.com/kitsunee02/rom-patches/main/Android.bp"

if [ -f "$AUDIO_BP" ]; then
    curl -sSfL -o "$AUDIO_BP" "$AUDIO_BP_URL" ||
        { echo "ERROR: Failed to download audio Android.bp"; exit 1; }
fi

    LUNARIS_STRINGS="packages/apps/Settings/res/values/lunaris_strings.xml"
    LUNARIS_STRINGS_URL="https://raw.githubusercontent.com/kitsunee02/rom-patches/refs/heads/main/luna16/lunaris_strings.xml"

   if [ -f "$LUNARIS_STRINGS" ]; then
      curl -sSfL -o "$LUNARIS_STRINGS" "$LUNARIS_STRINGS_URL" ||
          { echo "ERROR: Failed to download Lunaris Settings strings"; exit 1; }
   fi

   SYSTEMUIGO_CONFIG="packages/apps/SystemUIGo/res/values/config.xml"
   SYSTEMUIGO_CONFIG_URL="https://raw.githubusercontent.com/kitsunee02/rom-patches/refs/heads/main/luna16/config.xml"
   if [ -f "$SYSTEMUIGO_CONFIG" ]; then
   if [ -n "$SYSTEMUIGO_CONFIG_URL" ]; then
        curl -sSfL -o "$SYSTEMUIGO_CONFIG" "$SYSTEMUIGO_CONFIG_URL" ||
            { echo "ERROR: Failed to download SystemUIGo config"; exit 1; }
    else
        echo "WARNING: SystemUIGo config URL not set; skipping fix"
        fi
    fi
    
    BLOSSOM_MK="device/xiaomi/blossom/lineage_blossom.mk"
    BLOSSOM_MK_URL="https://raw.githubusercontent.com/kitsunee02/rom-patches/refs/heads/main/luna16/lineage_blossom.mk"

    if [ -f "$BLOSSOM_MK" ]; then
       if [ -n "$BLOSSOM_MK_URL" ]; then
        curl -sSfL -o "$BLOSSOM_MK" "$BLOSSOM_MK_URL" ||
            { echo "ERROR: Failed to download blossom device makefile"; exit 1; }
    else
        echo "WARNING: blossom device makefile URL not set; skipping fix"
       fi
    fi

    BLOSSOM_SYSTEM_PROP="device/xiaomi/blossom/system.prop"
    BLOSSOM_SYSTEM_PROP_URL="https://raw.githubusercontent.com/kitsunee02/rom-patches/refs/heads/main/luna16/system.prop"

if [ -f "$BLOSSOM_SYSTEM_PROP" ]; then
    if [ -n "$BLOSSOM_SYSTEM_PROP_URL" ]; then
        curl -sSfL -o "$BLOSSOM_SYSTEM_PROP" "$BLOSSOM_SYSTEM_PROP_URL" ||
            { echo "ERROR: Failed to download blossom system.prop"; exit 1; }
    else
        echo "WARNING: blossom system.prop URL not set; skipping fix"
    fi
fi



EDIFY_GENERATOR="build/make/tools/releasetools/edify_generator.py"
EDIFY_GENERATOR_URL=""

if [ -f "$EDIFY_GENERATOR" ]; then
    if [ -n "$EDIFY_GENERATOR_URL" ]; then
        curl -sSfL -o "$EDIFY_GENERATOR" "$EDIFY_GENERATOR_URL" ||
            { echo "ERROR: Failed to download edify_generator.py"; exit 1; }
    else
        echo "WARNING: edify_generator.py URL not set; skipping fix"
    fi
fi

REMOVE_PATHS=(
    "hardware/qcom-caf/sm8480"
    "hardware/lineage/interfaces/sensors"
    "hardware/lineage/interfaces/biometrics/fingerprint"
    "hardware/interfaces/biometrics/fingerprint/2.1/default"
)

for REMOVE_PATH in "${REMOVE_PATHS[@]}"; do
    if [ -d "$REMOVE_PATH" ]; then
        echo "Removing: $REMOVE_PATH"
        rm -rf -- "$REMOVE_PATH" || {
            echo "ERROR: Failed to remove $REMOVE_PATH"
            exit 1
        }
    else
        echo "INFO: Directory not present, skipping: $REMOVE_PATH"
    fi
done

LUNARIS_MK="vendor/lineage/config/lunaris.mk"
LUNARIS_MK_URL=""

if [ -f "$LUNARIS_MK" ]; then
    if [ -n "$LUNARIS_MK_URL" ]; then
        curl -sSfL -o "$LUNARIS_MK" "$LUNARIS_MK_URL" ||
            { echo "ERROR: Failed to download lunaris.mk"; exit 1; }
    else
        echo "WARNING: lunaris.mk URL not set; skipping fix"
    fi
fi

# Fix 9: Add libutils-v30 proprietary library
LIBUTILS_SO="vendor/xiaomi/blossom/proprietary/vendor/lib/libutils-v30.so"
LIBUTILS_SO_URL="https://raw.githubusercontent.com/crdroidandroid/proprietary_vendor_xiaomi_blossom/16.0/proprietary/vendor/lib/libutils-v30.so"
VENDOR_ANDROID_BP="vendor/xiaomi/blossom/Android.bp"

if [ -f "$VENDOR_ANDROID_BP" ]; then
    mkdir -p "$(dirname "$LIBUTILS_SO")" || {
        echo "ERROR: Failed to create libutils-v30 directory"
        exit 1
    }

    TEMP_LIB="$(mktemp)" || {
        echo "ERROR: Failed to create temporary library file"
        exit 1
    }

    if curl -sSfL -o "$TEMP_LIB" "$LIBUTILS_SO_URL" &&
       [ -s "$TEMP_LIB" ]; then
        mv "$TEMP_LIB" "$LIBUTILS_SO" || {
            rm -f "$TEMP_LIB"
            echo "ERROR: Failed to install libutils-v30.so"
            exit 1
        }
    else
        rm -f "$TEMP_LIB"
        echo "ERROR: Failed to download libutils-v30.so"
        exit 1
    fi

    if ! grep -q 'name: "libutils-v30"' "$VENDOR_ANDROID_BP"; then
        cat >> "$VENDOR_ANDROID_BP" <<'EOF'

cc_prebuilt_library_shared {
    name: "libutils-v30",
    vendor: true,
    strip: {
        none: true,
    },
    target: {
        android: {
            srcs: ["proprietary/vendor/lib/libutils-v30.so"],
        },
    },
    compile_multilib: "both",
}
EOF
        echo "Added libutils-v30 module to Android.bp"
    else
        echo "INFO: libutils-v30 module already exists; skipping append"
    fi
else
    echo "WARNING: $VENDOR_ANDROID_BP not found; skipping Fix 9"
fi

GENFS_CONTEXTS_DIR="device/xiaomi/blossom/sepolicy/vendor"
GENFS_CONTEXTS="$GENFS_CONTEXTS_DIR/genfs_contexts"
GENFS_CONTEXTS_URL=""

mkdir -p "$GENFS_CONTEXTS_DIR" || {
    echo "ERROR: Failed to create genfs_contexts directory"
    exit 1
}

if [ -n "$GENFS_CONTEXTS_URL" ]; then
    TEMP_GENFS="$(mktemp)" || {
        echo "ERROR: Failed to create temporary genfs_contexts file"
        exit 1
    }

    if curl -sSfL -o "$TEMP_GENFS" "$GENFS_CONTEXTS_URL" &&
       [ -s "$TEMP_GENFS" ]; then
        mv "$TEMP_GENFS" "$GENFS_CONTEXTS" || {
            rm -f "$TEMP_GENFS"
            echo "ERROR: Failed to install genfs_contexts"
            exit 1
        }
    else
        rm -f "$TEMP_GENFS"
        echo "ERROR: Failed to download genfs_contexts"
        exit 1
    fi
else
    echo "WARNING: genfs_contexts URL not set; skipping Fix 10"
fi

SEAPP_CONTEXTS="device/mediatek/sepolicy_vndr/bsp/plat_private/seapp_contexts"
SEAPP_CONTEXTS_URL=""

if [ -f "$SEAPP_CONTEXTS" ]; then
    if [ -n "$SEAPP_CONTEXTS_URL" ]; then
        curl -sSfL -o "$SEAPP_CONTEXTS" "$SEAPP_CONTEXTS_URL" ||
            { echo "ERROR: Failed to download seapp_contexts"; exit 1; }
    else
        echo "WARNING: seapp_contexts URL not set; skipping Fix 11"
    fi
else
    echo "INFO: Destination not present, skipping Fix 11: $SEAPP_CONTEXTS"
fi


    rm -rf hardware/lineage/interfaces/sensors
    rm -rf hardware/lineage/interfaces/biometrics/fingerprint
    rm -rf hardware/interfaces/biometrics/fingerprint/2.1/default

    git -C frameworks/av am --abort 2>/dev/null || true
    git -C frameworks/base am --abort 2>/dev/null || true
    git -C hardware/interfaces am --abort 2>/dev/null || true
    git -C packages/modules/Bluetooth am --abort 2>/dev/null || true
    git -C build/soong am --abort 2>/dev/null || true
    git -C system/sepolicy am --abort 2>/dev/null || true
    git -C hardware/mediatek am --abort 2>/dev/null || true

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

ZIP=$(find out/target/product/blossom -maxdepth 1 -type f -name "*.zip" | head -n 1)

if [ -n "$ZIP" ]; then
    echo "Uploading $ZIP..."
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh
    ./upload.sh "$ZIP"
else
    echo "No ROM ZIP found!"
    exit 1
fi

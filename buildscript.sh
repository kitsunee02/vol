#!/bin/bash

# ==========================================
# ⚙️ Global Configuration — YAAP for blossom
# ==========================================
DEVICE="blossom"
ROM_NAME="YAAP 16"
ANDROID_VERSION="16"
START_TIME=$(date +%s)
LOG_FILE="build_${DEVICE}_$(date +%Y%m%d_%H%M).log"
rm -f "/tmp/build_failed.lock"

export BUILD_USERNAME="Abhinav"
if [ -d "/opt/crave" ]; then
    export BUILD_HOSTNAME="crave"
else
    export BUILD_HOSTNAME=$(hostname)
fi

REPO_INIT_URL="https://github.com/yaap/manifest.git"
REPO_INIT_BRANCH="sixteen"
LOCAL_MANIFEST_URL="https://github.com/Alromine95/Local-manifest.git"
LOCAL_MANIFEST_BRANCH="main"
BUILD_TARGET="yaap_blossom-bp2a-userdebug"
BUILD_COMMAND="m yaap"

# ==========================================
# 📝 Setup Full-Script Logging
# ==========================================
exec 3>&1 4>&2
exec 1> >(tee -a "$LOG_FILE") 2>&1

# ==========================================
# Strict Execution: Abort on any failure
# ==========================================
set -eE
set -o pipefail

# ==========================================
# 📨 Error Trap — this is the key upgrade:
# stops the script immediately on ANY failing
# command, prints the exact line number, and
# uploads the crash log automatically.
# ==========================================
handle_error() {
    trap - ERR
    set +eE
    set +o pipefail
    local FAILED_LINE="$1"

    exec 1>&3 2>&4
    sleep 1

    if [ -f "/tmp/build_failed.lock" ]; then
        exit 1
    fi
    touch "/tmp/build_failed.lock"

    echo "❌ CRITICAL: Build failed on line $FAILED_LINE!"

    local LOG_LINK=""
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        if command -v gzip &> /dev/null && [[ "$LOG_FILE" != *.gz ]]; then
            echo "🗜️ Compressing crash log..."
            gzip -9 "$LOG_FILE"
            LOG_FILE="${LOG_FILE}.gz"
        fi
        echo "☁️ Uploading crash log to GoFile..."
        if ! command -v jq &> /dev/null; then
            sudo apt-get install -y jq > /dev/null 2>&1 || true
        fi
        if command -v jq &> /dev/null; then
            local SERVER=$(curl -s --connect-timeout 5 https://api.gofile.io/servers | jq -r '.data.servers[0].name' 2>/dev/null || true)
            if [ -n "$SERVER" ] && [ "$SERVER" != "null" ]; then
                local UPLOAD_RES=$(curl -s -F "file=@${LOG_FILE}" "https://${SERVER}.gofile.io/contents/uploadfile")
                local STATUS=$(echo "$UPLOAD_RES" | jq -r '.status' 2>/dev/null || true)
                if [ "$STATUS" == "ok" ]; then
                    LOG_LINK=$(echo "$UPLOAD_RES" | jq -r '.data.downloadPage' 2>/dev/null || true)
                    echo "✅ Crash log uploaded: $LOG_LINK"
                fi
            fi
        fi
    fi

    local END_TIME=$(date +%s)
    local ELAPSED_MINUTES=$(((END_TIME - START_TIME) / 60))
    echo "⏱️ Failed after ${ELAPSED_MINUTES}m"
    if [ -n "$LOG_LINK" ]; then
        echo "🔗 Crash log: $LOG_LINK"
    fi

    exit 1
}

trap 'handle_error $LINENO' ERR

echo "=========================================="
echo "✅ Device: $DEVICE | ROM: $ROM_NAME | Android: $ANDROID_VERSION"
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

    # Known YAAP sepolicy conflict fix
    echo "🔧 Fixing genfscon /class/typec conflict for YAAP..."
    find device/qcom/sepolicy_vndr -name "genfs_contexts" -exec sed -i '/genfscon sysfs \/class\/typec/d' {} + 2>/dev/null || true

    # Go 1.23+ compat fix for build/soong (apply AFTER repo sync gives us
    # a properly repo-managed build/soong — do NOT manually re-clone it,
    # that caused "unsupported checkout state" corruption previously)
    echo "🔧 Patching Go compat issue in execution_metrics.go..."
    sed -i 's/"golang.org\/x\/exp\/maps"/& \n\t"sort"/' build/soong/ui/execution_metrics/execution_metrics.go
    sed -i 's/slices\.Sorted(maps\.Keys(\([^)]*\)))/func() []string { keys := make([]string, 0, len(\1)); for k := range \1 { keys = append(keys, k) }; sort.Strings(keys); return keys }()/' build/soong/ui/execution_metrics/execution_metrics.go
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

# ==========================================
# ☁️ Upload
# ==========================================
upload_artifacts() {
    echo "=========================================="
    echo "☁️ Preparing files for upload..."
    echo "=========================================="

    TARGET_DIR="out/target/product/${DEVICE}"
    ZIP=$(find "$TARGET_DIR" -maxdepth 1 -type f -name "*.zip" | head -n 1)

    if [ -z "$ZIP" ] || [ ! -f "$ZIP" ]; then
        echo "❌ No ROM ZIP found in ${TARGET_DIR}."
        handle_error $LINENO
    fi

    echo "✅ Found ROM: $(basename "$ZIP")"
    echo "Uploading $ZIP..."
    wget -q https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh
    ./upload.sh "$ZIP"
}

# ==========================================
# 🚀 MAIN EXECUTION PIPELINE
# ==========================================
sync_repositories
compile_rom
upload_artifacts

exec 1>&3 2>&4
sleep 1

if [ -f "$LOG_FILE" ] && command -v gzip &> /dev/null; then
    gzip -9 "$LOG_FILE"
fi

echo "🎉 Build pipeline complete!"

#!/usr/bin/env bash
# clone-source.sh — clone xiaomi SM8350 kernel source for vili
# env: SOURCE_TYPE, KSU_TYPE, KERNEL_SRC (output dir)
set -e

: "${SOURCE_TYPE:?}"
: "${KERNEL_SRC:=$WORK_DIR/kernel_src}"

mkdir -p "$KERNEL_SRC"

case "$SOURCE_TYPE" in

  vili)
    VILI_REPO="https://github.com/Santhanabalan/android_kernel_xiaomi_sm8350"
    VILI_BRANCH="main"
    if [ "${VILI_CACHE_HIT}" = "true" ] && [ -d "$KERNEL_SRC/.git" ]; then
      echo "[Vili] Cache hit — fetching delta only..."
      for attempt in 1 2 3; do
        git -C "$KERNEL_SRC" fetch origin --depth=1 "$VILI_BRANCH" && \
          git -C "$KERNEL_SRC" reset --hard FETCH_HEAD && break
        echo "⚠️ Fetch attempt $attempt failed, retrying in 30s..."
        sleep 30
      done
    else
      echo "[Vili] Cloning $VILI_BRANCH ..."
      for attempt in 1 2 3; do
        git clone --recursive --branch "$VILI_BRANCH" "$VILI_REPO" "$KERNEL_SRC" --depth=1 && break
        echo "⚠️ Attempt $attempt failed, retrying in 30s..."
        rm -rf "$KERNEL_SRC" && mkdir -p "$KERNEL_SRC"
        sleep 30
      done
    fi
    ;;

  *)
    echo "[ERROR] Unknown source type: $SOURCE_TYPE"
    exit 1
    ;;
esac

echo "[OK] Source cloned → $KERNEL_SRC"
echo "KERNEL_SRC=$KERNEL_SRC" >> "${GITHUB_ENV:-/dev/null}"

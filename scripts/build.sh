#!/usr/bin/env bash
# build.sh — xiaomi SM8350 kernel build for vili
# env: SOURCE_TYPE, KSU_TYPE, DEFCONFIG, VARIANT, KERNEL_SRC, WORK_DIR, CLANG_DIR
set -e

: "${SOURCE_TYPE:?}"
: "${KERNEL_SRC:?}"
: "${WORK_DIR:?}"
: "${DEFCONFIG:?}"
: "${CLANG_DIR:?}"

OUT_DIR="${WORK_DIR}/out"
START=$(date +%s)

export TARGET_PRODUCT=vili
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-superuseryu}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-github}"
export PATH="${CLANG_DIR}/bin:$PATH"

if command -v ccache &>/dev/null; then _CC="ccache clang"; else _CC="clang"; fi

MAKE_FLAGS=(
  -j$(nproc)
  O="${OUT_DIR}/dist"
  ARCH=arm64
  SUBARCH=arm64
  LLVM=1
  LLVM_IAS=1
  CC="$_CC"
  LD=ld.lld
  AR=llvm-ar
  NM=llvm-nm
  OBJCOPY=llvm-objcopy
  OBJDUMP=llvm-objdump
  STRIP=llvm-strip
  OBJSIZE=llvm-size
  READELF=llvm-readelf
  CROSS_COMPILE=aarch64-linux-gnu-
  CROSS_COMPILE_ARM32=arm-linux-gnueabi-
  CONFIG_DISPLAY_BUILD=y
  KBUILD_BUILD_USER="$KBUILD_BUILD_USER"
  KBUILD_BUILD_HOST="$KBUILD_BUILD_HOST"
  KCFLAGS="-pipe -fno-strict-aliasing -fno-common -Wno-error -Wno-unknown-warning-option -Wno-array-bounds -Wno-stringop-overflow -Wno-mismatched-function-types -Wno-unused-variable -Wno-misleading-indentation -Wno-incompatible-function-pointer-types"
  LLVM_PARALLEL_LINK_JOBS=2
)

set -o pipefail
mkdir -p "${OUT_DIR}/dist"
cd "$KERNEL_SRC"

LOG="/tmp/build_${SOURCE_TYPE}.log"

echo "[${SOURCE_TYPE^^}] Building defconfig: $DEFCONFIG"
make "${MAKE_FLAGS[@]}" "$DEFCONFIG"

echo "[${SOURCE_TYPE^^}] Switching to ThinLTO..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  -e LTO_CLANG \
  -d LTO_NONE \
  -e LTO_CLANG_THIN \
  -d LTO_CLANG_FULL \
  -e THINLTO
make "${MAKE_FLAGS[@]}" olddefconfig

_FRAG_MERGED=false

# Merge platform fragments — order matters:
#   lahaina_GKI.config  : platform-wide GKI additions (mostly =m vendor drivers)
#   lahaina_QGKI.config : QGKI-specific platform additions
# CLO_FRAGMENT is passed from workflow (vendor/lahaina_GKI.config)
if [ -n "${CLO_FRAGMENT:-}" ] && [ -f "arch/arm64/configs/${CLO_FRAGMENT}" ]; then
  echo "[${SOURCE_TYPE^^}] Merging platform GKI fragment: $CLO_FRAGMENT"
  KCONFIG_CONFIG="${OUT_DIR}/dist/.config" \
    scripts/kconfig/merge_config.sh -m \
    "${OUT_DIR}/dist/.config" \
    "arch/arm64/configs/${CLO_FRAGMENT}"
  make "${MAKE_FLAGS[@]}" olddefconfig
  _FRAG_MERGED=true
fi

# Merge device-specific fragments (LOS SM8350 lineage-23.2 tree)
for _EXTRA in \
  "arch/arm64/configs/vendor/lahaina_QGKI.config" \
  "arch/arm64/configs/vendor/vili_QGKI.config" \
  "arch/arm64/configs/vendor/xiaomi_QGKI.config" \
  "arch/arm64/configs/vendor/debugfs.config"; do
  if [ -f "$_EXTRA" ]; then
    echo "[${SOURCE_TYPE^^}] Merging fragment: $_EXTRA"
    KCONFIG_CONFIG="${OUT_DIR}/dist/.config" \
      scripts/kconfig/merge_config.sh -m \
      "${OUT_DIR}/dist/.config" "$_EXTRA"
    make "${MAKE_FLAGS[@]}" olddefconfig
    _FRAG_MERGED=true
  else
    echo "[${SOURCE_TYPE^^}] Fragment not found, skipping: $_EXTRA"
  fi
done

# Post-fragment fixups
if $_FRAG_MERGED; then
  # Force LZ4 ZRAM (fragments may revert it)
  echo "[VILI] Re-enforcing ZRAM_DEF_COMP=lz4 after fragment merge"
  ./scripts/config --file "${OUT_DIR}/dist/.config" \
    -d ZRAM_DEF_COMP_LZORLE \
    -d ZRAM_DEF_COMP_ZSTD \
    -e ZRAM_DEF_COMP_LZ4 \
    -d ZRAM_DEF_COMP_LZO \
    --set-str ZRAM_DEF_COMP "lz4"
    echo "[VILI] Re-enforcing TCP_CONG=westwood after fragment merge"
  ./scripts/config --file "${OUT_DIR}/dist/.config" \
    -d TCP_CONG_BBR \
    -e TCP_CONG_WESTWOOD \
    --set-str DEFAULT_TCP_CONG "westwood" \
    -d DEFAULT_BBR \
    -e DEFAULT_WESTWOOD
  # Promote platform drivers from =m to =y so built-in code can resolve their symbols.
  # lahaina_GKI.config downgrades critical QCOM drivers (RPMH, SCM, minidump, QTEE, etc.)
  # to =m for GKI module builds — we need them built-in for a traditional image.
  #
  # EXCLUDE CONFIG_TOUCHSCREEN_* from promotion: multiple FTS driver variants
  # (drivers/input/touchscreen/st/ and fts_spi/) share exported symbols.
  # Both becoming =y causes ld.lld duplicate symbol errors at link time.
  # Touchscreen drivers are fine as modules — Android loads them from vendor partition.
  sed -E -i '/^(CONFIG_TOUCHSCREEN_|CONFIG_ICNSS|CONFIG_CNSS|CONFIG_QTI_BATTERY|CONFIG_QCA_CLD_WLAN)/!s/=m/=y/g' "${OUT_DIR}/dist/.config"
    echo "[VILI] Dropping upstream drivers/gpu/drm/msm (dup of techpack/display + KGSL Adreno)"
  sed -i '/^obj-\$(CONFIG_DRM_MSM) += msm\/$/d' drivers/gpu/drm/Makefile
    echo "[VILI] Re-enforcing QTI,QPNP,MI,DRM after sed config."
  ./scripts/config --file "${OUT_DIR}/dist/.config" \
    -e QTI_BATTERY_CHARGER \
    -e QPNP_QG \
    -e QPNP_SMB5 \
    -e MI_HARDWARE_ID \
    -e DRM_MSM
  make "${MAKE_FLAGS[@]}" olddefconfig
fi

echo "[${SOURCE_TYPE^^}] Building Image..."
if ! make "${MAKE_FLAGS[@]}" Image 2>&1 | tee "$LOG"; then
  echo "[FAIL] ${SOURCE_TYPE^^} build failed:"
  tail -100 "$LOG"
  exit 1
fi

if [ -f "${OUT_DIR}/dist/arch/arm64/boot/Image" ]; then
  cp "${OUT_DIR}/dist/arch/arm64/boot/Image" "${OUT_DIR}/dist/Image"
  echo "[${SOURCE_TYPE^^}] Image copied to ${OUT_DIR}/dist/Image"
else
  echo "[FAIL] Image file not found in build directory!"
  exit 1
fi

DURATION=$(( $(date +%s) - START ))
echo "✅ Build done in $((DURATION/60))m $((DURATION%60))s"
echo "duration=$DURATION" >> "${GITHUB_OUTPUT:-/dev/null}"

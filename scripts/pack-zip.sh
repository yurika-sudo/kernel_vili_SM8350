#!/usr/bin/env bash
# pack-zip.sh — pack AnyKernel3 zip per variant
# env: SOURCE_TYPE, KSU_TYPE, BUILD_TYPE, WORK_DIR
set -e

: "${SOURCE_TYPE:?}"
: "${KSU_TYPE:?}"
: "${WORK_DIR:?}"
: "${BUILD_TYPE:-stable}"

AK3_REPO="https://github.com/superuseryu/AnyKernel3"
IMAGE="${WORK_DIR}/out/dist/Image"

[ -f "$IMAGE" ] || { echo "[ERROR] Image not found: $IMAGE"; exit 1; }

VERSION_FILE="${WORK_DIR}/out/dist/kernel_version.txt"
_raw=$([ -f "$VERSION_FILE" ] && tr -d '[:space:]' < "$VERSION_FILE" || echo "5.15.x")
KERNEL_VERSION=$(echo "$_raw" | grep -oP '^\d+\.\d+\.\d+' || echo "$_raw")

case "${SOURCE_TYPE}" in
  vili) SRC_LABEL="Vili" ;;
  *)    SRC_LABEL="${SOURCE_TYPE^^}" ;;
esac

case "${KSU_TYPE}" in
  ksun) KSU_LABEL="KSU-Next" ;;
  suki) KSU_LABEL="SukiSU"   ;;
  none) KSU_LABEL="NoKSU"    ;;
  *)    KSU_LABEL="${KSU_TYPE}" ;;
esac

[ "$BUILD_TYPE" = "testing" ] && SUFFIX="-testing" || SUFFIX=""
ZIP_NAME="AK3-${SRC_LABEL}-${KSU_LABEL}-${KERNEL_VERSION}-$(date +'%Y-%m')${SUFFIX}.zip"

case "$KSU_TYPE" in
  ksun) IMAGE_NAME="Image.vili.ksu"  ;;
  suki) IMAGE_NAME="Image.vili.suki" ;;
  none) IMAGE_NAME="Image.vili.noksu";;
  *)    IMAGE_NAME="Image"           ;;
esac

cd "$WORK_DIR"
git clone --depth=1 "$AK3_REPO" ak3_tmp

# Override with vili-specific anykernel.sh (replaces Sapphire AK3 script)
AK3_SCRIPT="${WORK_DIR}/scripts/anykernel.sh"
[ -f "$AK3_SCRIPT" ] && cp "$AK3_SCRIPT" ak3_tmp/anykernel.sh

cp "$IMAGE" "ak3_tmp/Image"

cd ak3_tmp
zip -r9 "../${ZIP_NAME}" * -x .git/*
cd ..
rm -rf ak3_tmp

SIZE_MB=$(echo "scale=2; $(stat -c%s "$ZIP_NAME") / 1024 / 1024" | bc | sed 's/^\./0./')
echo "✅ Packed: $ZIP_NAME ($SIZE_MB MB)"

echo "ZIP_NAME=$ZIP_NAME"         >> "${GITHUB_ENV:-/dev/null}"
echo "ZIP_SIZE_MB=$SIZE_MB"       >> "${GITHUB_ENV:-/dev/null}"
echo "DATE_TAG=$BUILD_DATE"       >> "${GITHUB_ENV:-/dev/null}"
echo "IMAGE_NAME=$IMAGE_NAME"     >> "${GITHUB_ENV:-/dev/null}"


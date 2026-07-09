#!/usr/bin/env bash
# setup-ksu.sh — integrate KSU variant + SUSFS into kernel source (QGKI 5.4 MSM)
# env: KSU_TYPE (ksun|suki|none), KERNEL_DIR, WORK_DIR
set -e

: "${KSU_TYPE:?}"
: "${KERNEL_DIR:?}"
: "${WORK_DIR:?}"

git config --global init.defaultBranch main
git config --global advice.addEmbeddedRepo false

cd "$KERNEL_DIR"

_link_ksu_driver() {
  local DIR="$1"
  [ ! -L "drivers/kernelsu" ] && [ ! -d "drivers/kernelsu" ] && \
    ln -sf "../${DIR}" drivers/kernelsu
  grep -q "obj-.*kernelsu" drivers/Makefile || \
    echo 'obj-$(CONFIG_KSU) += kernelsu/' >> drivers/Makefile
  grep -q "kernelsu/Kconfig" drivers/Kconfig || \
    echo 'source "drivers/kernelsu/Kconfig"' >> drivers/Kconfig
}

# KernelSU-Next
if [ "$KSU_TYPE" = "ksun" ]; then
  rm -rf ./KernelSU ./drivers/kernelsu ./KernelSU-Next
  
  KSUN_BRANCH="${KSUN_BRANCH:-legacy-susfs}"
  curl -LSs "https://raw.githubusercontent.com/omrxdev/KernelSU-Next/${KSUN_BRANCH}/kernel/setup.sh" | bash -s "$KSUN_BRANCH"
  [ -d "KernelSU-Next" ] || { echo "[ERROR] KernelSU-Next not found"; exit 1; }
  # seccomp_cache.o uses SECCOMP_ARCH_NATIVE_NR (5.10+), absent in 5.4
  find KernelSU-Next/kernel/ -name 'Kbuild' -exec sed -i '/seccomp_cache\.o/d' {} +
  # pkg_observer.o uses newer fsnotify hook (.handle_inode_event), absent in 5.4
  find KernelSU-Next/kernel/ -name 'Kbuild' -exec sed -i '/pkg_observer\.o/d' {} +
  find . -name sucompat.c -exec sed -i 's|<linux/pgtable.h>|<asm/pgtable.h>|g' {} +

  cd KernelSU-Next
  sed -i 's|<linux/pgtable.h>|<asm/pgtable.h>|g' kernel/feature/sucompat.c || true
  git fetch --tags 2>/dev/null || true
  KSUN_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")
  echo "KSUN_TAG=$KSUN_TAG" >> "${GITHUB_ENV:-/dev/null}"
  echo "$KSUN_TAG"           > "$WORK_DIR/ksun_tag.txt"
  _ksun_ver=$(grep -rh "^#define KSU_VERSION\b" kernel/ 2>/dev/null \
    | awk 'NR==1{print $NF}' | tr -d '[:space:]')
  echo "${_ksun_ver:-}" > "$WORK_DIR/ksun_version.txt"
  cd ..

  _link_ksu_driver "KernelSU-Next"

# SukiSU-Ultra
elif [ "$KSU_TYPE" = "suki" ]; then
  rm -rf ./KernelSU ./drivers/kernelsu

  SUKI_ARG="${SUKI_ARG:-builtin}"
  curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s "$SUKI_ARG"
  [ -d "KernelSU" ] || { echo "[ERROR] KernelSU dir not found"; exit 1; }
  # same seccomp_cache incompatibility as KernelSU-Next
  find KernelSU/kernel/ -name 'Kbuild' -exec sed -i '/seccomp_cache\.o/d' {} +

  cd KernelSU
  sed -i 's|<linux/pgtable.h>|<asm/pgtable.h>|g' kernel/feature/sucompat.c || true
  git fetch --tags 2>/dev/null || true
  SUKI_TAG=$(git describe --tags --abbrev=0 2>/dev/null || \
    curl -sf "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/releases/latest" \
    | jq -r '.tag_name' 2>/dev/null || echo "unknown")
  echo "SUKI_TAG=$SUKI_TAG" >> "${GITHUB_ENV:-/dev/null}"
  echo "$SUKI_TAG"           > "$WORK_DIR/suki_ksu_tag.txt"
  _suki_ver=$(grep -rh "^#define KSU_VERSION\b" kernel/ 2>/dev/null \
    | awk 'NR==1{print $NF}' | tr -d '[:space:]')
  echo "${_suki_ver:-}" > "$WORK_DIR/suki_version.txt"
  cd ..

  _link_ksu_driver "KernelSU"
fi

echo "[OK] KSU setup complete: $KSU_TYPE"

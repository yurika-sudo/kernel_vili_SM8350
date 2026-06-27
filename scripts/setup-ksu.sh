#!/usr/bin/env bash
# setup-ksu.sh — integrate KSU variant + SUSFS into kernel source (NonGKI 5.4 MSM)
# env: KSU_TYPE (ksun|suki|none), KERNEL_DIR, WORK_DIR
set -e

: "${KSU_TYPE:?}"
: "${KERNEL_DIR:?}"
: "${WORK_DIR:?}"

# NonGKI patch sources (JackA1ltman/NonGKI_Kernel_Build_2nd)
NONGKI_PATCHES_BASE="https://raw.githubusercontent.com/JackA1ltman/NonGKI_Kernel_Build_2nd/mainline/Patches"

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

_inject_susfs_init() {
  local KSU_C="$1"
  [ ! -f "$KSU_C" ] && return 0
  grep -q "susfs_init" "$KSU_C" && return 0

  grep -q "#include <linux/susfs.h>" "$KSU_C" || \
    sed -i '/#include <linux\/fs\.h>/a #include <linux\/susfs.h>/' "$KSU_C" || true
  grep -q "susfs_init()" "$KSU_C" || \
    sed -i '/ksu_core_init();/a \\tsusfs_init();' "$KSU_C" || \
    sed -i '/int __init ksu_init(/,/^}/{ /return 0;/i \\tsusfs_init(); }' "$KSU_C" || true
  echo "[OK] susfs_init injected into $KSU_C"
}

_patch_susfs_def_h() {
  # susfs_def.h may call current_uid() without <linux/cred.h> — breaks compile.
  local DEF_H="include/linux/susfs_def.h"
  [ -f "$DEF_H" ] || return 0
  grep -q "linux/cred.h" "$DEF_H" && return 0
  sed -i '1i #include <linux/cred.h>' "$DEF_H"
  echo "[OK] susfs_def.h: added linux/cred.h"
}

_apply_susfs_nongki() {
  # 1. Apply 5.4-specific SUSFS patch (from JackA1ltman/NonGKI_Kernel_Build_2nd).
  #    This patch already includes fs/susfs.c + include/linux/susfs*.h as new files —
  #    no separate susfs4ksu clone needed.
  local PATCH="susfs_patch_to_5.4.patch"
  curl -LSs "${NONGKI_PATCHES_BASE}/Patch/${PATCH}" -o "${PATCH}"
  patch -p1 --forward --fuzz=3 < "${PATCH}" || true
  rm -f "${PATCH}"
  _patch_susfs_def_h
  echo "[OK] susfs_patch_to_5.4.patch applied"

  # 2. Run NonGKI inline hook patches (required for SUSFS v2.1.0+)
  local HOOK_SCRIPT="susfs_inline_hook_patches.sh"
  curl -LSs "${NONGKI_PATCHES_BASE}/${HOOK_SCRIPT}" -o "${HOOK_SCRIPT}"
  chmod +x "${HOOK_SCRIPT}"
  bash "${HOOK_SCRIPT}"
  rm -f "${HOOK_SCRIPT}"
  echo "[OK] susfs_inline_hook_patches.sh applied"
}

# KernelSU-Next
if [ "$KSU_TYPE" = "ksun" ]; then
  rm -rf ./KernelSU ./drivers/kernelsu ./KernelSU-Next
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" \
    | bash -s dev-susfs
  [ -d "KernelSU-Next" ] || { echo "[ERROR] KernelSU-Next not found"; exit 1; }

  cd KernelSU-Next
  git fetch --tags 2>/dev/null || true
  KSUN_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")
  echo "KSUN_TAG=$KSUN_TAG"    >> "${GITHUB_ENV:-/dev/null}"
  echo "$KSUN_TAG"              > "$WORK_DIR/ksun_tag.txt"
  _ksun_ver=$(grep -rh "^#define KSU_VERSION\b" kernel/ 2>/dev/null \
    | awk 'NR==1{print $NF}' | tr -d '[:space:]')
  echo "${_ksun_ver:-}" > "$WORK_DIR/ksun_version.txt"
  cd ..

  _apply_susfs_nongki
  _inject_susfs_init "KernelSU-Next/kernel/ksu.c"
  _link_ksu_driver "KernelSU-Next"

  # __p4d_to_phys missing on ARM64 4-level pgtable kernels
  PATCH_MEM="KernelSU-Next/kernel/hook/arm64/patch_memory.c"
  if [ -f "$PATCH_MEM" ] && ! grep -q "__p4d_to_phys" "$PATCH_MEM"; then
    sed -i '/^#include "asm-generic\/fixmap.h"/a \\n#ifndef __p4d_to_phys\n#define __p4d_to_phys(p4d)\t(p4d_val(p4d) \& PHYS_MASK \& PAGE_MASK)\n#endif' "$PATCH_MEM"
    echo "[OK] __p4d_to_phys compat injected"
  fi

# SukiSU-Ultra
elif [ "$KSU_TYPE" = "suki" ]; then
  rm -rf ./KernelSU ./drivers/kernelsu
  curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" \
    | bash -s susfs-main
  [ -d "KernelSU" ] || { echo "[ERROR] KernelSU dir not found"; exit 1; }

  cd KernelSU
  git fetch --tags 2>/dev/null || true
  SUKI_TAG=$(git describe --tags --abbrev=0 2>/dev/null || \
    curl -sf "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/releases/latest" \
    | jq -r '.tag_name' 2>/dev/null || echo "unknown")
  echo "SUKI_TAG=$SUKI_TAG"    >> "${GITHUB_ENV:-/dev/null}"
  echo "$SUKI_TAG"              > "$WORK_DIR/suki_ksu_tag.txt"
  _suki_ver=$(grep -rh "^#define KSU_VERSION\b" kernel/ 2>/dev/null \
    | awk 'NR==1{print $NF}' | tr -d '[:space:]')
  echo "${_suki_ver:-}" > "$WORK_DIR/suki_version.txt"
  cd ..

  _apply_susfs_nongki
  _inject_susfs_init "KernelSU/kernel/ksu.c"
  _link_ksu_driver "KernelSU"

  # __p4d_to_phys missing on ARM64 4-level pgtable kernels
  PATCH_MEM="KernelSU/kernel/hook/arm64/patch_memory.c"
  if [ -f "$PATCH_MEM" ] && ! grep -q "__p4d_to_phys" "$PATCH_MEM"; then
    sed -i '/^#include "asm-generic\/fixmap.h"/a \\n#ifndef __p4d_to_phys\n#define __p4d_to_phys(p4d)\t(p4d_val(p4d) \& PHYS_MASK \& PAGE_MASK)\n#endif' "$PATCH_MEM"
    echo "[OK] __p4d_to_phys compat injected"
  fi

fi

echo "[OK] KSU setup complete: $KSU_TYPE"
